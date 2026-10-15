// DiskBrowserViewModel+ChartScan.swift — Lazy metadata tree for sunburst (treemap disabled).
import Foundation
import LazyDiskCore

private final class PartialPublishGate: @unchecked Sendable {
    private var lastPublishNanos: UInt64 = 0
    private let lock = NSLock()

    func shouldPublish() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = DispatchTime.now().uptimeNanoseconds
        guard now &- lastPublishNanos >= 72_000_000 else { return false }
        lastPublishNanos = now
        return true
    }
}

extension DiskBrowserViewModel {
    func refreshChartChildrenIfNeeded() {
        guard isInitialChartReady, !isGatedSplashVolumeScan else { return }
        guard chartStyle == .sunburst else { return }
        if let volume = selectedVolume {
            Task {
                if await VolumeTreeScanCoordinator.shared.hasCompleteTreeScan(volumeID: volume.id) {
                    await ensureVolumeChartMapPublished(volumeID: volume.id)
                    return
                }
                if isAtVolumeRoot {
                    await refreshVolumeRootChartFromCache()
                    return
                }
                await MainActor.run { refreshChartChildren() }
            }
            return
        }
        refreshChartChildren()
    }

    /// Publishes the prebuilt volume chart map (instant navigation, DaisyDisk-style).
    func ensureVolumeChartMapPublished(volumeID: String) async {
        guard chartStyle == .sunburst else { return }

        if let stored = await VolumeTreeScanCoordinator.shared.chartChildMap(for: volumeID),
           !stored.isEmpty {
            isChartChildrenLoading = false
            chartChildrenScanProgress = nil
            if chartChildMap != stored {
                publishChartChildMap(stored)
            }
            return
        }

        if isAtVolumeRoot {
            await refreshVolumeRootChartFromCache()
        } else {
            await publishChartFromCurrentEntries()
        }
    }

    func storeVolumeChartChildMap(
        volumeID: String,
        buildResult: ChartTreeBuilder.BuildResult,
        root: URL,
        listedEntries: [DiskItem]
    ) async {
        let map = ChartTreeBuilder.childMap(
            from: buildResult,
            root: root,
            listedEntries: listedEntries,
            maxChildrenPerNode: chartMaxChildrenPerNode,
            otherItemName: L10n.filterOther
        )
        await VolumeTreeScanCoordinator.shared.storeChartChildMap(volumeID: volumeID, map: map)
    }

    /// Sunburst ring for the current folder using listed entries (no subtree file walk).
    func publishChartFromCurrentEntries() async {
        guard chartStyle == .sunburst, let root = currentPath else {
            clearChartChildMap()
            isChartChildrenLoading = false
            chartChildrenScanProgress = nil
            return
        }

        chartChildRefreshTask?.cancel()
        let parentPath = PathUtils.resolved(root).path
        let listed = entries
        let maxChildren = chartMaxChildrenPerNode
        let items = listed
            .filter { !$0.isVirtual && ($0.size > 0 || $0.isDirectory) }
            .sorted { $0.size > $1.size }
            .prefix(maxChildren)

        isChartChildrenLoading = false
        chartChildrenScanProgress = nil
        if items.isEmpty {
            clearChartChildMap()
        } else {
            publishChartChildMap([parentPath: Array(items)])
        }
    }

    func refreshVolumeRootChartFromCache() async {
        guard chartStyle == .sunburst,
              isAtVolumeRoot,
              let volume = selectedVolume else { return }

        if let stored = await VolumeTreeScanCoordinator.shared.chartChildMap(for: volume.id),
           !stored.isEmpty {
            isChartChildrenLoading = false
            chartChildrenScanProgress = nil
            publishChartChildMap(stored)
            return
        }

        let scanRoot = volume.scanRoot
        let maxDepth = await highestFullyCachedScanDepth(scanRoot: scanRoot)
        guard maxDepth >= 1 else {
            refreshChartChildren()
            return
        }
        await refreshChartFromScanCache(maxScanDepth: maxDepth)
    }

    func refreshChartFromScanCache(maxScanDepth: Int) async {
        guard chartStyle == .sunburst,
              isAtVolumeRoot,
              let scanRoot = selectedVolume?.scanRoot else { return }

        chartChildRefreshTask?.cancel()

        let rootEntries = entries
        let snapshot = await loadChartCacheSnapshot(
            scanRoot: scanRoot,
            rootEntries: rootEntries,
            maxScanDepth: maxScanDepth
        )

        let map = CachedScanChartBuilder.childMap(
            scanRoot: scanRoot,
            rootEntries: rootEntries,
            maxScanDepth: maxScanDepth,
            maxChildrenPerNode: chartMaxChildrenPerNode,
            cachedEntries: { url in snapshot[PathUtils.resolved(url).path] }
        )

        isChartChildrenLoading = false
        chartChildrenScanProgress = nil
        publishChartChildMap(map)
    }

    private func loadChartCacheSnapshot(
        scanRoot: URL,
        rootEntries: [DiskItem],
        maxScanDepth: Int
    ) async -> [String: [DiskItem]] {
        var snapshot: [String: [DiskItem]] = [:]
        let rootChildren = rootEntries.filter { $0.isDirectory && !$0.isVirtual }

        var queue: [(url: URL, depth: Int)] = rootChildren.map { ($0.url, 1) }
        var seen = Set<String>()

        while !queue.isEmpty {
            let (url, depth) = queue.removeFirst()
            let path = PathUtils.resolved(url).path
            guard seen.insert(path).inserted else { continue }
            guard depth <= maxScanDepth else { continue }

            if let cached = await cache.get(url), await cache.isComplete(cached) {
                snapshot[path] = cached.entries
            }

            guard depth < maxScanDepth, let entries = snapshot[path] else { continue }

            for child in entries where child.isDirectory && !child.isVirtual {
                queue.append((child.url, depth + 1))
            }
        }

        return snapshot
    }

    func highestFullyCachedScanDepth(scanRoot: URL) async -> Int {
        let limit = initialChartPrefetchMaxDepth
        for depth in (1...limit).reversed() {
            if await isScanDepthFullyCached(depth, scanRoot: scanRoot) {
                return depth
            }
        }
        return 0
    }

    func isScanDepthFullyCached(_ depth: Int, scanRoot: URL) async -> Bool {
        let directories = await directoriesAtDepth(depth, scanRoot: scanRoot, rootEntries: entries)
        if directories.isEmpty { return depth > 1 }

        for directory in directories {
            guard await cache.has(directory.url) else { return false }
            guard let cached = await cache.get(directory.url),
                  await cache.isComplete(cached) else { return false }
        }
        return true
    }

    func refreshChartChildren() {
        let needsChildren = chartStyle == .sunburst
        guard needsChildren else {
            clearChartChildMap()
            isChartChildrenLoading = false
            chartChildrenScanProgress = nil
            return
        }

        if let volume = selectedVolume {
            Task {
                if await VolumeTreeScanCoordinator.shared.hasCompleteTreeScan(volumeID: volume.id) {
                    await publishChartFromCurrentEntries()
                    return
                }
                await MainActor.run { beginChartChildrenFileWalk() }
            }
            return
        }

        beginChartChildrenFileWalk()
    }

    private func beginChartChildrenFileWalk() {
        chartChildRefreshTask?.cancel()

        guard let root = currentPath ?? selectedVolume?.scanRoot else {
            clearChartChildMap()
            isChartChildrenLoading = false
            chartChildrenScanProgress = nil
            return
        }

        let maxDepth = chartTreeMaxDepth
        let maxChildrenPerNode = chartMaxChildrenPerNode
        let volumeID = selectedVolume?.id
        let rootName = root.lastPathComponent.isEmpty ? "Data" : root.lastPathComponent
        let expandedParents = chartExpandedOtherParents
        let otherName = L10n.filterOther

        isChartChildrenLoading = true

        chartChildRefreshTask = Task.detached(priority: .utility) { [weak capturedViewModel = self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }
            guard let viewModel = capturedViewModel else { return }

            let listedEntries = await MainActor.run { viewModel.entries }

            let topLevelDirs = Set(
                listedEntries
                    .filter { $0.isDirectory && !$0.isVirtual }
                    .map { PathUtils.resolved($0.url).path }
            )
            let expandedParents = expandedParents.union(topLevelDirs)

            await MainActor.run {
                viewModel.chartChildrenScanProgress = ChartChildrenScanProgress(
                    completedFolders: 0,
                    totalFolders: 0,
                    currentFolderName: rootName,
                    currentDepth: 1,
                    maxDepth: maxDepth + 1,
                    filesScanned: 0,
                    displayFraction: 0
                )
            }

            let partialPublishGate = PartialPublishGate()

            let prefs = await MainActor.run { AppPreferences.load() }
            let cancelCheck = await MainActor.run { viewModel.activeScanCancelHandler() }

            let buildResult = ChartTreeBuilder.build(
                at: root,
                listedEntries: listedEntries,
                options: ChartTreeBuilder.BuildOptions(
                    maxDepth: maxDepth,
                    skipHiddenFiles: !prefs.showHiddenFiles,
                    partialUpdateInterval: 40,
                    expandedParents: expandedParents,
                    fileSizeThreshold: 0,
                    parallelism: prefs.scanParallelism
                ),
                shouldCancel: cancelCheck,
                onPartial: { partial in
                    let fraction = ChartScanProgressMath.metadataTreeFraction(filesScanned: partial.filesScanned)

                    if let volumeID {
                        Task {
                            await PersistentChartScanProgressStore.shared.scheduleSave(
                                volumeID: volumeID,
                                displayFraction: fraction,
                                completedFolders: 0,
                                estimatedTotalFolders: 0
                            )
                        }
                    }

                    guard partialPublishGate.shouldPublish() else { return }

                    Task { @MainActor [viewModel] in
                        viewModel.chartChildrenScanProgress = ChartChildrenScanProgress(
                            completedFolders: 0,
                            totalFolders: 0,
                            currentFolderName: rootName,
                            currentDepth: 1,
                            maxDepth: maxDepth + 1,
                            filesScanned: partial.filesScanned,
                            displayFraction: max(
                                viewModel.chartChildrenScanProgress?.displayFraction ?? 0,
                                fraction
                            )
                        )
                    }
                }
            )

            guard !Task.isCancelled else { return }

            let finalMap = ChartTreeBuilder.childMap(
                from: buildResult,
                root: root,
                listedEntries: listedEntries,
                maxChildrenPerNode: maxChildrenPerNode,
                otherItemName: otherName
            )

            await MainActor.run {
                viewModel.isChartChildrenLoading = false
                viewModel.chartChildrenScanProgress = nil
                viewModel.chartDeferredByParent = buildResult.deferredByParent
                viewModel.publishChartChildMap(finalMap)
                viewModel.startSmartPrefetch(chartMap: finalMap)
            }
        }
    }

    func applyFusedChartFromVolumeScan(
        _ buildResult: ChartTreeBuilder.BuildResult,
        root: URL,
        listedEntries: [DiskItem]
    ) {
        if isGatedSplashVolumeScan {
            pendingFusedVolumeChart = (buildResult, root, listedEntries)
            chartDeferredByParent = buildResult.deferredByParent
            return
        }
        chartDeferredByParent = buildResult.deferredByParent
        if let volumeID = selectedVolume?.id {
            Task { await storeVolumeChartChildMap(
                volumeID: volumeID,
                buildResult: buildResult,
                root: root,
                listedEntries: listedEntries
            ) }
        }
        let map = ChartTreeBuilder.childMap(
            from: buildResult,
            root: root,
            listedEntries: listedEntries,
            maxChildrenPerNode: chartMaxChildrenPerNode,
            otherItemName: L10n.filterOther
        )
        isChartChildrenLoading = false
        chartChildrenScanProgress = nil
        publishChartChildMap(map)
    }

    func expandChartSubtreeOther(at parentPath: String) {
        guard chartExpandedOtherParents.insert(parentPath).inserted else { return }
        refreshChartChildren()
    }

    func handleChartItemSelection(_ item: DiskItem) {
        let path = PathUtils.resolved(item.url).path
        if ChartSubtreeOther.isVirtualOther(path),
           let parentPath = ChartSubtreeOther.parentPath(ofVirtualOther: path) {
            expandChartSubtreeOther(at: parentPath)
            return
        }

        guard !item.isVirtual else { return }
        selectedIDs = [item.id]
        hoveredID = item.id
        if item.isDirectory {
            openItem(item)
        } else {
            selectItemForDetail(item)
        }
    }

    func resetChartLazyScanState() {
        chartExpandedOtherParents.removeAll()
        chartDeferredByParent.removeAll()
    }

    private var chartTreeMaxDepth: Int {
        interfaceMode == .simple
            ? SunburstLayoutEngine.Config.daisyDisk.maxDepth
            : SunburstLayoutEngine.Config.standard.maxDepth
    }

    private var chartMaxChildrenPerNode: Int {
        SunburstLayoutEngine.Config.daisyDisk.maxChildrenPerNode
    }
}
