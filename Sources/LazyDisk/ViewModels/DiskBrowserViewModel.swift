// DiskBrowserViewModel.swift — central app state, published properties, and derived values.
import AppKit
import Foundation
import SwiftUI

@MainActor
final class DiskBrowserViewModel: ObservableObject {
    @Published var appPhase: AppPhase = .welcome
    @Published var volumes: [VolumeInfo] = []
    @Published var selectedVolume: VolumeInfo?
    @Published var currentPath: URL?
    @Published var entries: [DiskItem] = []
    @Published var selectedIDs: Set<UUID> = []
    @Published var hoveredID: UUID?
    @Published var isLoading = false
    @Published var scanProgress: String = ""
    @Published var scanProgressFraction: Double = 0
    @Published var scanCurrentFolder: String = ""
    @Published var errorMessage: String?
    @Published var showDeleteConfirmation = false
    @Published var permissions: [PermissionItem] = []
    @Published var collectorItems: [DiskItem] = []
    @Published var searchText: String = ""
    @Published var sortOrder: SortOrder = AppPreferences.load().sortOrder
    @Published var contentFilter: ContentFilter = AppPreferences.load().contentFilter
    @Published var chartStyle: ChartStyle = AppPreferences.load().chartStyle
    @Published var showPreferences = false
    @Published var showDonation = false
    @Published var showAbout = false
    @Published var deleteWarnings: [DeleteWarning] = []
    @Published var pendingDeleteURLs: [URL] = []
    @Published var keyboardFocusedIndex: Int = 0
    @Published var navigationAnimationID = UUID()
    @Published var isCollectorExpanded = false
    @Published var isCollectorMinimized = false
    @Published var isSearchFieldFocused = false
    @Published var debouncedSearchText: String = ""
    @Published var loadedFromCache = false
    @Published var searchScope: SearchScope = AppPreferences.load().searchScope
    @Published var globalSearchResults: [GlobalSearchResult] = []
    @Published var isGlobalSearching = false
    @Published var globalSearchEngine: SearchEngine?
    @Published var isBuildingSearchIndex = false
    @Published var searchIndexStatus: String = ""
    @Published var searchIndexEntryCount: Int = 0
    @Published var activePanel: AppPanel = .browser
    @Published var languageRevision: Int = 0

    // Cleanup
    @Published var cleanupSuggestions: [CleanupSuggestion] = []
    @Published var isScanningCleanup = false
    @Published var cleanupProgress: CleanupScanProgress?

    // Duplicates
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var isScanningDuplicates = false
    @Published var duplicateProgress: DuplicateScanProgress?

    // History
    @Published var scanSnapshots: [ScanSnapshot] = []
    @Published var selectedSnapshotID: UUID?
    @Published var currentScanDiff: ScanDiff?
    @Published var historyCompareMode: ScanHistoryCompareMode = .currentState
    var historyLoadedVolumeID: String?

    // Dev mode
    @Published var devJunkItems: [DevJunkItem] = []
    @Published var isScanningDev = false
    @Published var devProgress: DevScanProgress?

    // Free space goal
    @Published var freeSpaceGoalGB: Double = AppPreferences.load().freeSpaceGoalGB
    @Published var goalSuggestions: [GoalSuggestion] = []
    @Published var isScanningGoal = false
    @Published var goalScanProgress: GoalScanProgress?

    // Navigation
    @Published var recentFolders: [URL] = NavigationHistoryService.recentFolders()
    @Published var bookmarks: [FolderBookmark] = NavigationHistoryService.bookmarks()

    @Published var exportMessage: String?
    @Published var chartChildMap: [String: [DiskItem]] = [:]

    // Smart collections
    @Published var activeSmartCollection: SmartCollection?
    @Published var smartCollectionResults: [DiskItem] = []
    @Published var isScanningSmartCollection = false
    @Published var smartCollectionProgress: SmartCollectionProgress?

    // Detail panel
    @Published var detailItem: DiskItem?
    @Published var isDetailPanelVisible = false
    @Published var browserSidebarWidth: CGFloat = AppPreferences.load().browserSidebarWidth

    var scanTask: Task<Void, Never>?
    var prefetchTask: Task<Void, Never>?
    var chartChildRefreshTask: Task<Void, Never>?
    var searchDebounceTask: Task<Void, Never>?
    var globalSearchTask: Task<Void, Never>?
    var indexBuildTask: Task<Void, Never>?
    var cleanupTask: Task<Void, Never>?
    var duplicateTask: Task<Void, Never>?
    var devTask: Task<Void, Never>?
    var smartCollectionTask: Task<Void, Never>?
    var goalTask: Task<Void, Never>?
    var navigationGeneration: UInt = 0
    var devJunkCache: [String: [DevJunkItem]] = [:]
    var lastSelectedIndex: Int?
    var scanProgressSortTask: Task<Void, Never>?
    var scanProgressNeedsSort = false
    var hoverPublishTask: Task<Void, Never>?
    var pendingScanUpdates: [Int: (size: Int64, isScanning: Bool)] = [:]
    var scanUIBatchTask: Task<Void, Never>?
    var filterCountsRevision: UInt = 0
    var chartCacheRevision: UInt = 0
    var cachedFilterCounts: (revision: UInt, value: [ContentFilter: Int])?
    var cachedChartItems: (revision: UInt, value: [DiskItem])?
    var cachedSunburstSegments: (revision: UInt, childMapKey: String, value: [SunburstSegment])?
    let scanner = DiskScanner.shared
    let cache = ScanCache.shared
    let globalSearch = GlobalSearchService.shared
    let historyStore = ScanHistoryStore.shared
    let fsMonitor = FilesystemChangeMonitor()
    var fsRefreshTask: Task<Void, Never>?
    var workspaceObservers: [NSObjectProtocol] = []
    private var externalOpenObserver: NSObjectProtocol?
    var pendingExternalAnalyzeURL: URL?
    static let chartOtherGroupID = UUID(uuidString: "A0000000-0000-4000-8000-000000000001")!
    let chartSmallItemThresholdPercent = 2.0

    init() {
        externalOpenObserver = NotificationCenter.default.addObserver(
            forName: .lazyDiskAnalyzeExternalURLs,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let urls = notification.object as? [URL] else { return }
            Task { @MainActor in
                self?.analyzeExternalURLs(urls)
            }
        }
    }

    deinit {
        if let externalOpenObserver {
            NotificationCenter.default.removeObserver(externalOpenObserver)
        }
    }

    var isAtVolumeRoot: Bool {
        guard let currentPath, let volume = selectedVolume else { return false }
        return PathUtils.resolved(currentPath).path == PathUtils.resolved(volume.scanRoot).path
    }

    var breadcrumbs: [URL] {
        guard let currentPath, let volume = selectedVolume else { return [] }

        let root = PathUtils.resolved(volume.scanRoot)
        let current = PathUtils.resolved(currentPath)

        var crumbs: [URL] = [volume.scanRoot]
        var built = root.path

        for component in PathUtils.relativeComponents(from: currentPath, scanRoot: volume.scanRoot) {
            built += "/\(component)"
            crumbs.append(URL(fileURLWithPath: built, isDirectory: true))
        }

        if PathUtils.resolved(crumbs.last ?? volume.scanRoot).path != current.path {
            crumbs.append(current)
        }

        return crumbs
    }

    var navigationBreadcrumbs: [URL] {
        var crumbs = breadcrumbs
        guard isDetailPanelVisible, let item = detailItem else { return crumbs }

        let itemPath = PathUtils.resolved(item.url).path
        let lastPath = PathUtils.resolved(crumbs.last ?? item.url).path
        if itemPath != lastPath {
            crumbs.append(item.url)
        }
        return crumbs
    }

    var isShowingGlobalSearch: Bool {
        searchScope == .entireVolume
            && !debouncedSearchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var filteredEntries: [DiskItem] {
        var result = entries

        let query = debouncedSearchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty && searchScope == .currentFolder {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }

        if contentFilter != .all {
            result = result.filter { contentFilter.matches($0) }
        }

        if !AppPreferences.load().showHiddenFiles {
            result = result.filter { !$0.isHidden }
        }

        return sortOrder.sort(result)
    }

    var browserListEntries: [DiskItem] {
        guard activeSmartCollection != nil else { return filteredEntries }

        var result = smartCollectionResults
        let query = debouncedSearchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        if contentFilter != .all {
            result = result.filter { contentFilter.matches($0) }
        }
        if !AppPreferences.load().showHiddenFiles {
            result = result.filter { !$0.isHidden }
        }
        return sortOrder.sort(result)
    }

    var filterCounts: [ContentFilter: Int] {
        if let cached = cachedFilterCounts, cached.revision == filterCountsRevision {
            return cached.value
        }
        let counts = computeFilterCounts()
        cachedFilterCounts = (filterCountsRevision, counts)
        return counts
    }

    var collectorFreePercent: Double {
        guard let volume = selectedVolume else { return 0 }
        return CollectorService.freePercent(size: collectorSize, of: volume.usedCapacity)
    }

    var projectedFreeSpace: Int64 {
        guard let volume = selectedVolume else { return 0 }
        return volume.availableCapacity + collectorSize
    }

    var displayTotalSize: Int64 {
        if activeSmartCollection != nil {
            return max(browserListEntries.reduce(0) { $0 + $1.size }, 1)
        }
        if isAtVolumeRoot, let volume = selectedVolume {
            return volume.usedCapacity
        }
        return max(filteredEntries.reduce(0) { $0 + $1.size }, 1)
    }

    var totalSize: Int64 {
        browserListEntries.reduce(0) { $0 + $1.size }
    }

    var chartItems: [DiskItem] {
        if let cached = cachedChartItems, cached.revision == chartCacheRevision {
            return cached.value
        }
        let items = computeChartItems()
        cachedChartItems = (chartCacheRevision, items)
        return items
    }

    var sunburstSegments: [SunburstSegment] {
        let key = "\(chartChildMap.count)"
        if let cached = cachedSunburstSegments,
           cached.revision == chartCacheRevision,
           cached.childMapKey == key {
            return cached.value
        }
        let segments = SunburstLayoutEngine.build(
            items: chartItems,
            totalSize: displayTotalSize,
            childrenByParentPath: chartChildMap
        )
        cachedSunburstSegments = (chartCacheRevision, key, segments)
        return segments
    }

    var selectedItems: [DiskItem] {
        browserListEntries.filter { selectedIDs.contains($0.id) }
    }

    var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var collectorSize: Int64 {
        collectorItems.reduce(0) { $0 + $1.size }
    }

    var allPermissionsGranted: Bool {
        permissions.allSatisfy(\.isGranted)
    }
}
