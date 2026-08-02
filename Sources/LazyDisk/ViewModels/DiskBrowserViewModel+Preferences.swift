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
        prefs.interfaceMode = interfaceMode
        prefs.searchScope = searchScope
        prefs.browserSidebarWidth = Double(browserSidebarWidth)
        prefs.save()
    }

    func setInterfaceMode(_ mode: InterfaceMode) {
        interfaceMode = mode
        if mode == .simple && chartStyle == .treemap {
            chartStyle = .rose
        }
        savePreferences()
        refreshChartChildren()
    }

    func saveSidebarWidth(_ width: CGFloat) {
        guard !isSidebarWidthTrackingPaused else { return }

        let clamped = min(480, max(280, width))
        guard abs(clamped - browserSidebarWidth) > 1 else { return }

        browserSidebarWidth = clamped

        sidebarWidthSaveTask?.cancel()
        sidebarWidthSaveTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            var prefs = AppPreferences.load()
            prefs.browserSidebarWidth = Double(browserSidebarWidth)
            prefs.save()
        }
    }

    func pauseSidebarWidthTracking() {
        isSidebarWidthTrackingPaused = true
        sidebarWidthTrackingResumeTask?.cancel()
        sidebarWidthTrackingResumeTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            isSidebarWidthTrackingPaused = false
        }
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
        let needsChildren = chartStyle == .sunburst || chartStyle == .treemap
        guard needsChildren else {
            clearChartChildMap()
            isChartChildrenLoading = false
            chartChildrenScanProgress = nil
            return
        }

        chartChildRefreshTask?.cancel()
        let parents = chartItems.filter { $0.isDirectory && !$0.isVirtual }
        guard !parents.isEmpty else {
            clearChartChildMap()
            isChartChildrenLoading = false
            chartChildrenScanProgress = nil
            return
        }
        let maxDepth = interfaceMode == .simple
            ? SunburstLayoutEngine.Config.daisyDisk.maxDepth
            : SunburstLayoutEngine.Config.standard.maxDepth

        isChartChildrenLoading = true
        chartChildrenScanProgress = ChartChildrenScanProgress(
            completedFolders: 0,
            totalFolders: parents.count,
            currentFolderName: ""
        )

        chartChildRefreshTask = Task.detached(priority: .utility) { [weak viewModel = self] in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }

            var newMap: [String: [DiskItem]] = [:]
            let parallelism = AppPreferences.load().scanParallelism
            var queue: [(DiskItem, Int)] = parents.map { ($0, 0) }
            var queuedPaths = Set<String>()
            var totalFolders = queue.count
            var completedFolders = 0

            for item in parents {
                queuedPaths.insert(PathUtils.resolved(item.url).path)
            }

            while !queue.isEmpty {
                guard !Task.isCancelled else { return }

                let (item, depth) = queue.removeFirst()
                let parentPath = PathUtils.resolved(item.url).path
                let folderName = item.displayName

                await MainActor.run {
                    viewModel?.chartChildrenScanProgress = ChartChildrenScanProgress(
                        completedFolders: completedFolders,
                        totalFolders: totalFolders,
                        currentFolderName: folderName
                    )
                }

                await Self.fetchChildren(
                    for: item,
                    into: &newMap,
                    parallelism: parallelism,
                    viewModel: viewModel
                )

                completedFolders += 1

                if depth < maxDepth, let children = newMap[parentPath] {
                    for child in children where child.isDirectory && !child.isVirtual {
                        let childPath = PathUtils.resolved(child.url).path
                        guard queuedPaths.insert(childPath).inserted else { continue }
                        queue.append((child, depth + 1))
                        totalFolders += 1
                    }
                }

                let snapshot = newMap
                let allowPreview = await MainActor.run { viewModel?.isAtVolumeRoot == false }
                await MainActor.run {
                    viewModel?.chartChildrenScanProgress = ChartChildrenScanProgress(
                        completedFolders: completedFolders,
                        totalFolders: totalFolders,
                        currentFolderName: folderName
                    )
                    if allowPreview {
                        viewModel?.publishChartChildMap(snapshot)
                    }
                }
            }

            guard !Task.isCancelled else { return }
            let finalMap = newMap
            await MainActor.run {
                viewModel?.isChartChildrenLoading = false
                viewModel?.chartChildrenScanProgress = nil
                viewModel?.publishChartChildMap(finalMap)
            }
        }
    }

    private static func fetchChildren(
        for item: DiskItem,
        into map: inout [String: [DiskItem]],
        parallelism: Int,
        viewModel: DiskBrowserViewModel?
    ) async {
        let folderURL = PathUtils.resolved(item.url)
        let parentPath = folderURL.path
        guard map[parentPath] == nil else { return }

        let entries: [DiskItem]
        if let cached = await ScanCache.shared.get(folderURL) {
            entries = cached.entries
        } else {
            let listed = await DiskScanner.shared.listDirectory(at: folderURL)
            let scanned = await DiskScanner.shared.scanDirectorySizes(
                items: listed,
                parallelism: parallelism
            )
            let sorted = scanned.sorted { $0.size > $1.size }
            let cachedDirectory = CachedDirectory(
                url: folderURL,
                entries: sorted,
                scannedAt: Date(),
                isVolumeRoot: false
            )
            guard await ScanCache.shared.isComplete(cachedDirectory) else { return }

            await ScanCache.shared.set(folderURL, entries: sorted, isVolumeRoot: false)
            entries = sorted
        }

        let children = await MainActor.run {
            viewModel?.chartChildren(from: entries) ?? []
        }
        if !children.isEmpty {
            map[parentPath] = children
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
            invalidateChartCaches()

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
