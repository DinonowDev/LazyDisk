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
    private var historyLoadedVolumeID: String?

    // Dev mode
    @Published var devJunkItems: [DevJunkItem] = []
    @Published var isScanningDev = false
    @Published var devProgress: DevScanProgress?

    // Free space goal
    @Published var freeSpaceGoalGB: Double = AppPreferences.load().freeSpaceGoalGB
    @Published var goalSuggestions: [DiskItem] = []

    // Navigation
    @Published var recentFolders: [URL] = NavigationHistoryService.recentFolders()
    @Published var bookmarks: [FolderBookmark] = NavigationHistoryService.bookmarks()

    @Published var exportMessage: String?
    @Published var sunburstChildMap: [UUID: [DiskItem]] = [:]

    // Smart collections
    @Published var activeSmartCollection: SmartCollection?
    @Published var smartCollectionResults: [DiskItem] = []
    @Published var isScanningSmartCollection = false
    @Published var smartCollectionProgress: SmartCollectionProgress?

    // Detail panel
    @Published var detailItem: DiskItem?
    @Published var isDetailPanelVisible = false

    private var scanTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var searchDebounceTask: Task<Void, Never>?
    private var globalSearchTask: Task<Void, Never>?
    private var indexBuildTask: Task<Void, Never>?
    private var cleanupTask: Task<Void, Never>?
    private var duplicateTask: Task<Void, Never>?
    private var devTask: Task<Void, Never>?
    private var smartCollectionTask: Task<Void, Never>?
    private var navigationGeneration: UInt = 0
    private var lastSelectedIndex: Int?
    private let scanner = DiskScanner.shared
    private let cache = ScanCache.shared
    private let globalSearch = GlobalSearchService.shared
    private let historyStore = ScanHistoryStore.shared
    private let fsMonitor = FilesystemChangeMonitor()
    private var fsRefreshTask: Task<Void, Never>?
    private var workspaceObservers: [NSObjectProtocol] = []
    private static let chartOtherGroupID = UUID(uuidString: "A0000000-0000-4000-8000-000000000001")!
    private let chartSmallItemThresholdPercent = 2.0

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
        var counts: [ContentFilter: Int] = [:]
        for filter in ContentFilter.allCases {
            if filter == .all {
                counts[filter] = entries.count
            } else {
                counts[filter] = entries.filter { filter.matches($0) }.count
            }
        }
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
        let total = displayTotalSize
        let sorted = browserListEntries
            .filter { $0.size > 0 || $0.isScanning }
            .sorted { $0.size > $1.size }

        var visible: [DiskItem] = []
        var otherSize: Int64 = 0
        var otherCount = 0

        for item in sorted {
            if item.isScanning {
                visible.append(item)
                continue
            }

            let percent = item.percentage(of: total)
            if percent < chartSmallItemThresholdPercent {
                otherSize += item.size
                otherCount += 1
            } else {
                visible.append(item)
            }
        }

        if otherCount > 0 {
            let otherName = otherCount == 1
                ? L10n.filterOther
                : "\(L10n.filterOther) (\(otherCount))"
            visible.append(DiskItem(
                id: Self.chartOtherGroupID,
                url: URL(fileURLWithPath: "/"),
                name: otherName,
                size: otherSize,
                isDirectory: false,
                isVirtual: true
            ))
        }

        return visible.sorted { $0.size > $1.size }
    }

    var sunburstSegments: [SunburstSegment] {
        SunburstLayoutEngine.build(
            items: chartItems,
            totalSize: displayTotalSize,
            childrenByParentID: sunburstChildMap
        )
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
        if style == .sunburst {
            refreshSunburstChildren()
        }
    }

    func refreshSunburstChildren() {
        guard chartStyle == .sunburst else {
            sunburstChildMap = [:]
            return
        }
        let parents = chartItems.filter { $0.isDirectory && !$0.isVirtual }
        Task {
            var map: [UUID: [DiskItem]] = [:]
            for item in parents {
                if let cached = await cache.get(item.url) {
                    let children = cached.entries
                        .filter { !$0.isVirtual && ($0.size > 0 || $0.isDirectory) }
                        .sorted { $0.size > $1.size }
                        .prefix(8)
                    if !children.isEmpty {
                        map[item.id] = Array(children)
                    }
                }
            }
            sunburstChildMap = map
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

    // MARK: - Global Search

    func performGlobalSearch() {
        guard let volume = selectedVolume else { return }
        let query = debouncedSearchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            globalSearchResults = []
            isGlobalSearching = false
            return
        }

        globalSearchTask?.cancel()
        isGlobalSearching = true
        globalSearchResults = []

        globalSearchTask = Task {
            let includeHidden = AppPreferences.load().showHiddenFiles
            let (results, engine) = await globalSearch.search(
                query: query,
                volume: volume,
                filter: contentFilter,
                includeHidden: includeHidden
            )

            guard !Task.isCancelled else { return }
            globalSearchResults = results
            globalSearchEngine = engine
            isGlobalSearching = false
        }
    }

    func startSearchIndexBuild() {
        guard let volume = selectedVolume else { return }
        indexBuildTask?.cancel()

        indexBuildTask = Task {
            let hasIndex = await globalSearch.hasIndex(for: volume)
            if hasIndex {
                searchIndexEntryCount = await globalSearch.indexEntryCount(for: volume)
                searchIndexStatus = L10n.searchIndexReady
                return
            }

            isBuildingSearchIndex = true
            searchIndexStatus = L10n.searchIndexing

            await globalSearch.buildIndex(for: volume, includeHidden: AppPreferences.load().showHiddenFiles) { progress in
                Task { @MainActor in
                    self.searchIndexEntryCount = progress.foundEntries
                    self.searchIndexStatus = "\(progress.foundEntries) files · \(progress.currentPath)"
                }
            }

            guard !Task.isCancelled else { return }
            isBuildingSearchIndex = false
            searchIndexEntryCount = await globalSearch.indexEntryCount(for: volume)
            searchIndexStatus = L10n.searchIndexCount(searchIndexEntryCount)
        }
    }

    func rebuildSearchIndex() {
        guard let volume = selectedVolume else { return }
        indexBuildTask?.cancel()
        Task {
            await globalSearch.invalidateIndex(for: volume)
            searchIndexEntryCount = 0
            startSearchIndexBuild()
        }
    }

    func navigateToSearchResult(_ result: GlobalSearchResult) {
        let parent = URL(fileURLWithPath: result.parentPath, isDirectory: true)
        navigate(to: parent)
    }

    func openSearchResult(_ result: GlobalSearchResult) {
        if result.isDirectory {
            navigate(to: result.url)
        } else {
            NSWorkspace.shared.open(result.url)
        }
    }

    func setSortOrder(_ order: SortOrder) {
        sortOrder = order
        entries = order.sort(entries)
        savePreferences()
    }

    func toggleSort(for column: SortColumn) {
        setSortOrder(sortOrder.toggled(for: column))
    }

    // MARK: - Permissions

    func refreshPermissions() {
        permissions = PermissionsService.checkAll()
    }

    func requestAllPermissions() {
        guard !allPermissionsGranted else {
            PermissionsService.openPrivacySettings()
            return
        }
        PermissionsService.requestAll()
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            refreshPermissions()
        }
    }

    func showPermissions() {
        refreshPermissions()
        appPhase = .permissions
    }

    // MARK: - Welcome & Initial Scan

    func prepareWelcome() {
        startWorkspaceObserversIfNeeded()
        Task {
            let vols = await scanner.listVolumes()
            volumes = vols
            if selectedVolume == nil {
                selectedVolume = vols.first(where: { $0.url.path == "/" }) ?? vols.first
            }
            restartFilesystemMonitoring()
        }
    }

    func startInitialScan() {
        guard let volume = selectedVolume else { return }

        scanTask?.cancel()
        prefetchTask?.cancel()
        appPhase = .scanning
        scanProgressFraction = 0
        scanCurrentFolder = ""
        scanProgress = L10n.scanPreparing
        entries = []
        selectedIDs.removeAll()
        hoveredID = nil

        scanTask = Task {
            await cache.clear()
            await scanner.clearSizeCache()
            if let volume = selectedVolume {
                await globalSearch.invalidateIndex(for: volume)
            }
            await performScan(
                at: volume.scanRoot,
                volume: volume,
                isVolumeRoot: true,
                trackDetailedProgress: true
            )

            guard !Task.isCancelled else { return }

            startPrefetching(from: entries)
            startSearchIndexBuild()
            saveScanSnapshot(volume: volume)

            withAnimation(.easeInOut(duration: 0.35)) {
                appPhase = .ready
            }
            isLoading = false
            scanProgress = ""
            scanProgressFraction = 1
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        prefetchTask?.cancel()
        scanTask = nil
        isLoading = false
        scanProgress = ""
        scanProgressFraction = 0
        scanCurrentFolder = ""
        appPhase = .welcome
    }

    func rescanVolume() {
        guard let volume = selectedVolume else { return }
        appPhase = .scanning
        scanTask?.cancel()
        prefetchTask?.cancel()
        scanTask = Task {
            await cache.clear()
            await scanner.clearSizeCache()
            if let volume = selectedVolume {
                await globalSearch.invalidateIndex(for: volume)
            }
            await performScan(
                at: volume.scanRoot,
                volume: volume,
                isVolumeRoot: true,
                trackDetailedProgress: true
            )
            guard !Task.isCancelled else { return }
            startPrefetching(from: entries)
            startSearchIndexBuild()
            saveScanSnapshot(volume: volume)
            appPhase = .ready
            isLoading = false
        }
    }

    // MARK: - Navigation

    func selectVolume(_ volume: VolumeInfo) {
        if selectedVolume?.id != volume.id {
            historyLoadedVolumeID = nil
            scanSnapshots = []
            selectedSnapshotID = nil
            currentScanDiff = nil
        }
        selectedVolume = volume
        restartFilesystemMonitoring()
        if appPhase == .ready {
            navigate(to: volume.scanRoot)
        }
    }

    func pickVolume(_ volume: VolumeInfo?) {
        selectedVolume = volume
        restartFilesystemMonitoring()
    }

    func navigate(to url: URL) {
        guard appPhase == .ready else { return }

        clearSmartCollection()
        let normalized = PathUtils.resolved(url)

        prefetchTask?.cancel()
        scanTask?.cancel()
        navigationGeneration += 1
        let generation = navigationGeneration

        withAnimation(.easeInOut(duration: 0.25)) {
            navigationAnimationID = UUID()
        }

        currentPath = normalized
        selectedIDs.removeAll()
        hoveredID = nil
        detailItem = nil
        isDetailPanelVisible = false
        lastSelectedIndex = nil
        keyboardFocusedIndex = 0
        NavigationHistoryService.recordVisit(normalized)
        recentFolders = NavigationHistoryService.recentFolders()

        scanTask = Task {
            if let cached = await cache.get(normalized), await cache.isComplete(cached) {
                guard generation == navigationGeneration else { return }
                entries = cached.entries
                currentPath = normalized
                isLoading = false
                loadedFromCache = true
                scanProgress = L10n.scanFromCache
                return
            }

            loadedFromCache = false
            isLoading = true
            scanProgress = L10n.scanFolderNamed(normalized.lastPathComponent)

            await performScan(
                at: normalized,
                volume: selectedVolume,
                isVolumeRoot: normalized.path == PathUtils.resolved(selectedVolume?.scanRoot ?? normalized).path,
                trackDetailedProgress: false,
                generation: generation
            )
            guard !Task.isCancelled, generation == navigationGeneration else { return }
            isLoading = false
            scanProgress = ""

            startPrefetching(from: entries)
        }
    }

    func refreshCurrentFolder() {
        guard let path = currentPath else { return }
        prefetchTask?.cancel()
        Task {
            await cache.invalidate(path)
            navigate(to: path)
        }
    }

    func navigateUp() {
        guard let currentPath, let volume = selectedVolume else { return }
        let parent = PathUtils.resolved(currentPath).deletingLastPathComponent()

        if parent.path == PathUtils.resolved(currentPath).path { return }

        if !PathUtils.isWithinVolume(parent, scanRoot: volume.scanRoot) {
            navigate(to: volume.scanRoot)
        } else {
            navigate(to: parent)
        }
    }

    func openItem(_ item: DiskItem) {
        guard !item.isVirtual else { return }

        if item.isDirectory {
            navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func handleItemClick(_ item: DiskItem, at index: Int, commandHeld: Bool, shiftHeld: Bool) {
        if shiftHeld {
            let anchor = lastSelectedIndex ?? keyboardFocusedIndex
            selectRange(from: anchor, to: index)
            lastSelectedIndex = index
            keyboardFocusedIndex = index
            if selectedIDs.count == 1, let id = selectedIDs.first,
               let selected = browserListEntries.first(where: { $0.id == id }) {
                detailItem = selected
                isDetailPanelVisible = true
            }
            return
        }

        if commandHeld {
            toggleSelection(item, at: index)
            return
        }

        selectItemForDetail(item, at: index)
    }

    func handleItemDoubleClick(_ item: DiskItem) {
        openItem(item)
    }

    func selectItemForDetail(_ item: DiskItem, at index: Int? = nil) {
        guard !item.isVirtual else { return }
        selectedIDs = [item.id]
        detailItem = item
        isDetailPanelVisible = true
        if let index {
            lastSelectedIndex = index
            keyboardFocusedIndex = index
        }
    }

    func showLargeFilesInFolder(_ item: DiskItem) {
        guard item.isDirectory, !item.isVirtual else { return }
        navigate(to: item.url)
        runSmartCollection(.largeFiles, root: item.url)
    }

    // MARK: - Smart Collections

    func runSmartCollection(_ collection: SmartCollection, root: URL? = nil) {
        guard let volume = selectedVolume else { return }
        smartCollectionTask?.cancel()
        activeSmartCollection = collection
        smartCollectionResults = []
        isScanningSmartCollection = true
        smartCollectionProgress = nil
        selectedIDs.removeAll()
        detailItem = nil
        isDetailPanelVisible = false
        keyboardFocusedIndex = 0

        let scanRoot = root ?? volume.scanRoot
        smartCollectionTask = Task {
            let results = await SmartCollectionService.scan(
                collection: collection,
                volumeRoot: volume.scanRoot,
                scanRoot: scanRoot
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.smartCollectionProgress = progress
                }
            }
            guard !Task.isCancelled else { return }
            smartCollectionResults = results
            isScanningSmartCollection = false
            scanProgress = collection.title
        }
    }

    func clearSmartCollection() {
        smartCollectionTask?.cancel()
        activeSmartCollection = nil
        smartCollectionResults = []
        isScanningSmartCollection = false
        smartCollectionProgress = nil
    }

    func openSmartCollectionInBrowser(_ collection: SmartCollection) {
        activePanel = .browser
        runSmartCollection(collection)
    }

    func toggleSelection(_ item: DiskItem, at index: Int? = nil) {
        guard !item.isVirtual else { return }

        if let index {
            lastSelectedIndex = index
        }

        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    func selectAll() {
        selectedIDs = Set(browserListEntries.filter { !$0.isVirtual }.map(\.id))
    }

    func selectRange(from start: Int, to end: Int) {
        let lower = min(start, end)
        let upper = max(start, end)
        let items = browserListEntries
        guard lower < items.count else { return }

        for index in lower...min(upper, items.count - 1) {
            let item = items[index]
            if !item.isVirtual {
                selectedIDs.insert(item.id)
            }
        }
    }

    // MARK: - Collector

    func addToCollector(_ item: DiskItem) {
        guard !item.isVirtual else { return }
        guard !CollectorService.contains(collectorItems, url: item.url) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            collectorItems = CollectorService.merge(collectorItems, adding: item)
            isCollectorMinimized = false
            isCollectorExpanded = true
        }
    }

    func addToCollector(url: URL) {
        let resolved = PathUtils.resolved(url)
        if let item = entries.first(where: { PathUtils.resolved($0.url).path == resolved.path }) {
            addToCollector(item)
            return
        }

        let provisional = DiskItem(url: resolved, isDirectory: resolved.hasDirectoryPath, isScanning: true)
        addToCollector(provisional)

        Task {
            let size = await scanner.calculateSize(for: resolved)
            guard let index = collectorItems.firstIndex(where: {
                PathUtils.resolved($0.url).path == resolved.path
            }) else { return }
            collectorItems[index].size = size
            collectorItems[index].isScanning = false
        }
    }

    func removeFromCollector(_ item: DiskItem) {
        withAnimation(.easeOut(duration: 0.2)) {
            collectorItems.removeAll { $0.id == item.id }
        }
    }

    func clearCollector() {
        withAnimation(.easeOut(duration: 0.2)) {
            collectorItems.removeAll()
        }
    }

    func requestCollectorDelete() {
        guard !collectorItems.isEmpty else { return }
        pendingDeleteURLs = collectorItems.map(\.url)
        deleteWarnings = DeleteWarningService.analyze(urls: pendingDeleteURLs)
        showDeleteConfirmation = true
    }

    // MARK: - Delete

    func requestDelete() {
        let targets = selectedItems.isEmpty ? collectorItems : selectedItems
        let deletable = targets.filter {
            !$0.isVirtual && CleanupService.canDelete(url: $0.url)
        }
        guard !deletable.isEmpty else {
            errorMessage = L10n.errorCannotDelete
            return
        }
        pendingDeleteURLs = deletable.map(\.url)
        deleteWarnings = DeleteWarningService.analyze(urls: pendingDeleteURLs)
        showDeleteConfirmation = true
    }

    func confirmDelete() {
        let urls = pendingDeleteURLs.filter { CleanupService.canDelete(url: $0) }
        guard !urls.isEmpty else { return }

        do {
            _ = try CleanupService.moveToTrash(urls: urls)
            selectedIDs.removeAll()
            collectorItems.removeAll { item in urls.contains(item.url) }
            pendingDeleteURLs.removeAll()
            deleteWarnings.removeAll()

            if let currentPath {
                Task {
                    await cache.invalidate(currentPath)
                    navigate(to: currentPath)
                }
            }
        } catch {
            errorMessage = L10n.errorDeleteFailed(error.localizedDescription)
        }
    }

    var deleteConfirmationMessage: String {
        let count = pendingDeleteURLs.count
        let totalSize = pendingDeleteURLs.isEmpty ? selectedSize : collectorSize
        return DeleteWarningService.summaryMessage(
            for: deleteWarnings,
            itemCount: count,
            totalSize: totalSize
        )
    }

    // MARK: - Quick Look & Keyboard

    func quickLookSelection() {
        let urls: [URL]
        if !selectedItems.isEmpty {
            urls = selectedItems.map(\.url)
        } else if keyboardFocusedIndex < browserListEntries.count {
            urls = [browserListEntries[keyboardFocusedIndex].url]
        } else {
            return
        }
        QuickLookService.preview(urls: urls.filter { !$0.path.isEmpty })
    }

    func handleEnterKey() {
        guard keyboardFocusedIndex < browserListEntries.count else { return }
        let item = browserListEntries[keyboardFocusedIndex]
        if item.isDirectory {
            openItem(item)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func moveKeyboardFocus(delta: Int) {
        guard !browserListEntries.isEmpty else { return }
        keyboardFocusedIndex = max(0, min(browserListEntries.count - 1, keyboardFocusedIndex + delta))
        hoveredID = browserListEntries[keyboardFocusedIndex].id
    }

    func revealInFinder(_ item: DiskItem) {
        guard !item.isVirtual else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    // MARK: - Feature Panels

    func scanCleanupSuggestions() {
        guard let volume = selectedVolume else { return }
        cleanupTask?.cancel()
        isScanningCleanup = true
        cleanupProgress = nil
        cleanupTask = Task {
            cleanupSuggestions = await CleanupSuggestionService.scan(volumeRoot: volume.scanRoot) { [weak self] progress in
                Task { @MainActor in self?.cleanupProgress = progress }
            }
            guard !Task.isCancelled else { return }
            isScanningCleanup = false
            cleanupProgress = nil
            cleanupTask = nil
        }
    }

    func cancelCleanupScan() {
        cleanupTask?.cancel()
        cleanupTask = nil
        isScanningCleanup = false
        cleanupProgress = nil
    }

    func addCleanupSuggestion(_ suggestion: CleanupSuggestion) {
        addToCollector(url: suggestion.url)
    }

    func addAllCleanupSuggestions() {
        for suggestion in cleanupSuggestions {
            addToCollector(url: suggestion.url)
        }
    }

    func scanDuplicates() {
        guard let volume = selectedVolume else { return }
        duplicateTask?.cancel()
        isScanningDuplicates = true
        duplicateGroups = []
        duplicateProgress = nil
        duplicateTask = Task {
            duplicateGroups = await DuplicateFinderService.findDuplicates(in: volume.scanRoot) { [weak self] progress in
                Task { @MainActor in self?.duplicateProgress = progress }
            }
            guard !Task.isCancelled else { return }
            isScanningDuplicates = false
            duplicateProgress = nil
            duplicateTask = nil
        }
    }

    func cancelDuplicateScan() {
        duplicateTask?.cancel()
        duplicateTask = nil
        isScanningDuplicates = false
        duplicateProgress = nil
    }

    func addDuplicateCopiesToCollector() {
        for group in duplicateGroups {
            for file in group.files.dropFirst() {
                addToCollector(url: file.url)
            }
        }
    }

    func loadScanHistory(force: Bool = false) {
        guard let volume = selectedVolume else { return }
        if !force && historyLoadedVolumeID == volume.id { return }
        historyLoadedVolumeID = volume.id
        Task {
            let snapshots = await historyStore.snapshots(for: volume.id)
            scanSnapshots = snapshots
            if let first = snapshots.first {
                selectedSnapshotID = first.id
                updateScanDiff(with: first)
            }
        }
    }

    func updateScanDiff(with snapshot: ScanSnapshot) {
        currentScanDiff = ScanHistoryDiff.computeDiff(current: entries, previous: snapshot)
    }

    private func saveScanSnapshot(volume: VolumeInfo) {
        Task {
            await historyStore.saveSnapshot(
                volumeID: volume.id,
                totalUsed: volume.usedCapacity,
                entries: entries
            )
            loadScanHistory(force: true)
        }
    }

    func scanDevJunk() {
        devTask?.cancel()
        isScanningDev = true
        devProgress = nil
        let roots = selectedVolume.map { [$0.scanRoot] }
        devTask = Task {
            devJunkItems = await DevModeService.scan(roots: roots) { [weak self] progress in
                Task { @MainActor in self?.devProgress = progress }
            }
            guard !Task.isCancelled else { return }
            isScanningDev = false
            devProgress = nil
            devTask = nil
        }
    }

    func cancelDevScan() {
        devTask?.cancel()
        devTask = nil
        isScanningDev = false
        devProgress = nil
    }

    func addDevJunk(_ item: DevJunkItem) {
        addToCollector(url: item.url)
    }

    func addAllDevJunk() {
        for item in devJunkItems {
            addToCollector(url: item.url)
        }
    }

    func saveFreeSpaceGoal() {
        var prefs = AppPreferences.load()
        prefs.freeSpaceGoalGB = freeSpaceGoalGB
        prefs.save()
    }

    func suggestItemsForGoal() {
        guard let volume = selectedVolume else { return }
        let targetBytes = Int64(freeSpaceGoalGB * 1_073_741_824)
        let needed = max(0, targetBytes - volume.availableCapacity)
        guard needed > 0 else {
            goalSuggestions = []
            return
        }

        var collected: [DiskItem] = []
        var accumulated: Int64 = 0
        let sorted = entries.filter { !$0.isVirtual && CleanupService.canDelete(url: $0.url) }
            .sorted { $0.size > $1.size }

        for item in sorted {
            collected.append(item)
            accumulated += item.size
            if accumulated >= needed { break }
        }
        goalSuggestions = collected
    }

    func toggleBookmark() {
        guard let path = currentPath else { return }
        if NavigationHistoryService.isBookmarked(path) {
            if let bm = bookmarks.first(where: { $0.url.path == PathUtils.resolved(path).path }) {
                NavigationHistoryService.removeBookmark(bm)
            }
        } else {
            NavigationHistoryService.addBookmark(path)
        }
        bookmarks = NavigationHistoryService.bookmarks()
    }

    func exportCurrentFolderCSV() {
        guard let url = ExportService.savePanel(format: "csv", defaultName: "lazydisk-export.csv") else { return }
        do {
            try ExportService.exportCSV(entries: browserListEntries, to: url)
            exportMessage = L10n.exportDone
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportCurrentFolderJSON() {
        guard let url = ExportService.savePanel(format: "json", defaultName: "lazydisk-export.json") else { return }
        do {
            try ExportService.exportJSON(entries: browserListEntries, to: url)
            exportMessage = L10n.exportDone
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshLanguage() {
        languageRevision += 1
    }

    // MARK: - Live Filesystem Monitoring

    private func startWorkspaceObserversIfNeeded() {
        guard workspaceObservers.isEmpty else { return }

        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            center.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleVolumeListChange() }
            },
            center.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleVolumeListChange() }
            },
        ]
    }

    private func handleVolumeListChange() {
        Task {
            let vols = await scanner.listVolumes()
            volumes = vols
            if let current = selectedVolume,
               let updated = vols.first(where: { $0.id == current.id }) {
                selectedVolume = updated
            } else if selectedVolume != nil, !vols.contains(where: { $0.id == selectedVolume?.id }) {
                selectedVolume = vols.first(where: { $0.url.path == "/" }) ?? vols.first
                restartFilesystemMonitoring()
            }
        }
    }

    private func restartFilesystemMonitoring() {
        fsMonitor.stop()
        guard let volume = selectedVolume else { return }

        let watchPath = PathUtils.resolved(volume.scanRoot).path
        fsMonitor.start(watchPaths: [watchPath], latency: 0.3) { [weak self] changedPaths in
            Task { @MainActor in
                self?.handleFilesystemChange(changedPaths: changedPaths)
            }
        }
    }

    private func handleFilesystemChange(changedPaths: [String]) {
        fsRefreshTask?.cancel()
        fsRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await refreshVolumeStatsAndAffectedEntries(changedPaths: changedPaths)
        }
    }

    private func refreshVolumeStatsAndAffectedEntries(changedPaths: [String]) async {
        let vols = await scanner.listVolumes()
        volumes = vols
        if let current = selectedVolume,
           let updated = vols.first(where: { $0.id == current.id }) {
            selectedVolume = updated
        }

        guard appPhase == .ready, let currentPath, !isLoading else { return }

        let current = PathUtils.resolved(currentPath).path
        let affectsCurrentView = changedPaths.contains { path in
            path == current
                || path.hasPrefix(current + "/")
                || current.hasPrefix(path + "/")
                || current.hasPrefix(path)
        }
        guard affectsCurrentView else { return }

        await applyLightweightFolderRefresh(changedPaths: changedPaths)
    }

    private func applyLightweightFolderRefresh(changedPaths: [String]) async {
        guard let currentPath, let volume = selectedVolume else { return }
        let normalized = PathUtils.resolved(currentPath)

        let listed = await scanner.listDirectory(at: normalized)
        let existingByPath = Dictionary(
            uniqueKeysWithValues: entries.map { (PathUtils.resolved($0.url).path, $0) }
        )

        var merged: [DiskItem] = listed.map { item in
            let path = PathUtils.resolved(item.url).path
            if item.isDirectory,
               let existing = existingByPath[path],
               existing.size > 0,
               !existing.isScanning {
                var copy = item
                copy.size = existing.size
                copy.isScanning = false
                return copy
            }
            return item
        }

        merged = sortOrder.sort(merged)

        if isAtVolumeRoot {
            merged = await scanner.reconcileWithVolumeUsage(
                items: merged,
                volume: volume,
                atVolumeRoot: true
            )
        }

        entries = merged
        await cache.set(normalized, entries: merged, isVolumeRoot: isAtVolumeRoot)

        let indicesToRecalc = merged.enumerated().compactMap { index, item -> Int? in
            guard item.isDirectory, !item.isVirtual else { return nil }
            let dirPath = PathUtils.resolved(item.url).path
            let affected = changedPaths.contains { changedPath in
                changedPath == dirPath || changedPath.hasPrefix(dirPath + "/")
            }
            return affected ? index : nil
        }

        for index in indicesToRecalc {
            guard index < entries.count else { continue }
            let url = entries[index].url
            entries[index].isScanning = true
            let size = await scanner.calculateSize(for: url)
            guard let idx = entries.firstIndex(where: { $0.url == url }) else { continue }
            entries[idx].size = size
            entries[idx].isScanning = false
            entries = sortOrder.sort(entries)
            if isAtVolumeRoot {
                entries = await scanner.reconcileWithVolumeUsage(
                    items: entries,
                    volume: volume,
                    atVolumeRoot: true
                )
            }
        }
    }

    // MARK: - Private

    private func performScan(
        at url: URL,
        volume: VolumeInfo?,
        isVolumeRoot: Bool,
        trackDetailedProgress: Bool,
        generation: UInt? = nil
    ) async {
        let normalized = PathUtils.resolved(url)

        guard generation == nil || generation == navigationGeneration else { return }

        currentPath = normalized
        isLoading = true

        if trackDetailedProgress {
            scanProgressFraction = 0.05
            scanProgress = L10n.scanReadingList
            scanCurrentFolder = url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent
        }

        let listed = await scanner.listDirectory(at: normalized)
        guard !Task.isCancelled, generation == nil || generation == navigationGeneration else { return }

        entries = listed

        if trackDetailedProgress {
            scanProgressFraction = 0.1
            scanProgress = L10n.scanFoundItems(listed.count)
        }

        let scanned = await scanner.scanDirectorySizes(
            items: listed,
            parallelism: AppPreferences.load().scanParallelism
        ) { [self] update in
            Task { @MainActor in
                guard generation == nil || generation == self.navigationGeneration else { return }

                if trackDetailedProgress {
                    self.scanProgressFraction = 0.1 + update.fraction * 0.75
                    self.scanCurrentFolder = update.currentName
                    self.scanProgress = L10n.scanFoldersProgress(update.completed, update.total)
                }

                if let index = update.itemIndex, index < self.entries.count {
                    self.entries[index].size = update.itemSize ?? self.entries[index].size
                    self.entries[index].isScanning = false
                    self.entries = self.sortOrder.sort(self.entries)
                }
            }
        }
        guard !Task.isCancelled, generation == nil || generation == navigationGeneration else { return }

        var sorted = sortOrder.sort(scanned)

        if trackDetailedProgress {
            scanProgressFraction = 0.88
            scanProgress = L10n.scanFinalizing
        }

        if isVolumeRoot, let volume {
            sorted = await scanner.reconcileWithVolumeUsage(
                items: sorted,
                volume: volume,
                atVolumeRoot: true
            )
        }

        guard !Task.isCancelled, generation == nil || generation == navigationGeneration else { return }

        entries = sorted
        await cache.set(normalized, entries: sorted, isVolumeRoot: isVolumeRoot)

        if trackDetailedProgress {
            scanProgressFraction = 0.92
            scanProgress = L10n.scanCaching
        }
    }

    private func startPrefetching(from items: [DiskItem]) {
        prefetchTask?.cancel()
        let directories = items.filter { $0.isDirectory && !$0.isVirtual }

        prefetchTask = Task {
            let total = directories.count
            for (index, item) in directories.enumerated() {
                guard !Task.isCancelled else { return }

                let folderURL = PathUtils.resolved(item.url)
                if await cache.has(folderURL) { continue }

                let listed = await scanner.listDirectory(at: folderURL)
                guard !Task.isCancelled else { return }

                let scanned = await scanner.scanDirectorySizes(
                    items: listed,
                    parallelism: AppPreferences.load().scanParallelism
                )
                guard !Task.isCancelled else { return }

                let sorted = scanned.sorted { $0.size > $1.size }
                let cached = CachedDirectory(
                    url: folderURL,
                    entries: sorted,
                    scannedAt: Date(),
                    isVolumeRoot: false
                )
                guard await cache.isComplete(cached) else { continue }

                await cache.set(folderURL, entries: sorted, isVolumeRoot: false)

                if appPhase == .scanning {
                    await MainActor.run {
                        scanProgressFraction = 0.92 + (Double(index + 1) / Double(max(total, 1))) * 0.08
                        scanCurrentFolder = item.name
                        scanProgress = L10n.scanCachingFolders(index + 1, total)
                    }
                }
            }
        }
    }
}
