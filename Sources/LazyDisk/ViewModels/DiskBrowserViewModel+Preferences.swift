// DiskBrowserViewModel+Preferences.swift — Preferences, chart style, and sort order.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Preferences

    func savePreferences() {
        var prefs = AppPreferences.load()
        prefs.sortOrder = sortOrder
        prefs.contentFilter = contentFilter
        prefs.chartStyle = chartStyle
        prefs.searchScope = searchScope
        prefs.save()
    }

    func setChartStyle(_ style: ChartStyle) {
        chartStyle = style
        savePreferences()
        if style == .sunburst || style == .treemap {
            refreshChartChildren()
        } else if !chartChildMap.isEmpty {
            clearChartChildMap()
        }
    }

    func refreshChartChildren() {
        guard chartStyle == .sunburst || chartStyle == .treemap else {
            clearChartChildMap()
            return
        }

        chartChildRefreshTask?.cancel()
        let parents = chartItems.filter { $0.isDirectory && !$0.isVirtual }

        chartChildRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }

            var newMap: [String: [DiskItem]] = [:]

            for item in parents {
                guard !Task.isCancelled else { return }

                let folderURL = PathUtils.resolved(item.url)
                let parentPath = folderURL.path
                let entries: [DiskItem]

                if let cached = await cache.get(folderURL) {
                    entries = cached.entries
                } else {
                    let listed = await scanner.listDirectory(at: folderURL)
                    guard !Task.isCancelled else { return }

                    let scanned = await scanner.scanDirectorySizes(
                        items: listed,
                        parallelism: AppPreferences.load().scanParallelism
                    )
                    guard !Task.isCancelled else { return }

                    let sorted = scanned.sorted { $0.size > $1.size }
                    let cachedDirectory = CachedDirectory(
                        url: folderURL,
                        entries: sorted,
                        scannedAt: Date(),
                        isVolumeRoot: false
                    )
                    guard await cache.isComplete(cachedDirectory) else { continue }

                    await cache.set(folderURL, entries: sorted, isVolumeRoot: false)
                    entries = sorted
                }

                let children = chartChildren(from: entries)
                if !children.isEmpty {
                    newMap[parentPath] = children
                }
            }

            guard !Task.isCancelled else { return }
            publishChartChildMap(newMap)
        }
    }

    func setHoveredID(_ id: UUID?) {
        guard hoveredID != id else { return }
        hoverPublishTask?.cancel()
        hoverPublishTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled, let self else { return }
            guard self.hoveredID != id else { return }
            self.hoveredID = id
        }
    }

    func setHoveredID(_ id: UUID?, keyboardIndex: Int) {
        guard hoveredID != id || keyboardFocusedIndex != keyboardIndex else { return }
        hoverPublishTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) {
            hoveredID = id
            keyboardFocusedIndex = keyboardIndex
        }
    }

    func setSearchFieldFocused(_ focused: Bool) {
        guard isSearchFieldFocused != focused else { return }
        publishAfterCurrentUpdate { [weak self] in
            self?.isSearchFieldFocused = focused
        }
    }

    func refreshPermissionsDeferred() {
        publishAfterCurrentUpdate { [weak self] in
            self?.refreshPermissions()
        }
    }

    func bindSearchDebounce() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            debouncedSearchText = searchText
            keyboardFocusedIndex = 0

            if searchScope == .entireVolume {
                performGlobalSearch()
            } else {
                globalSearchResults = []
                isGlobalSearching = false
            }
        }
    }

    func setSearchScope(_ scope: SearchScope) {
        searchScope = scope
        savePreferences()
        if !searchText.isEmpty {
            debouncedSearchText = searchText
            if scope == .entireVolume {
                performGlobalSearch()
            } else {
                globalSearchResults = []
                isGlobalSearching = false
            }
        }
    }

}
