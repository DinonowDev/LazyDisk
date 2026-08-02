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

    func handleHiddenFilesPreferenceChanged() {
        invalidateAllDerivedCaches()
        Task {
            await scanner.clearSizeCache()
            if let path = currentPath {
                await cache.invalidate(path)
            }
            refreshCurrentFolder()
        }
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

        let clamped = BrowserSidebarMetrics.clamp(width, mode: interfaceMode)
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
        let resolved = ChartStyle.resolved(style)
        chartStyle = resolved
        savePreferences()
        if resolved == .sunburst {
            refreshChartChildren()
        } else if !chartChildMap.isEmpty {
            clearChartChildMap()
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
