// DiskBrowserViewModel+FolderScan.swift — Per-folder scan, lazy content, and smart prefetch.
import AppKit
import Foundation
import LazyDiskCore
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Scan

    func performScan(
        at url: URL,
        volume: VolumeInfo?,
        isVolumeRoot: Bool,
        trackDetailedProgress: Bool,
        generation: UInt? = nil,
        shouldCancel: (@Sendable () -> Bool)? = nil
    ) async {
        let normalized = PathUtils.resolved(url)

        guard generation == nil || generation == navigationGeneration else { return }

        let cancelCheck = shouldCancel ?? activeScanCancelHandler()

        if isVolumeRoot {
            await RestrictedScanCoordinator.shared.clear()
            restrictedScanEvents = []
        }

        currentPath = normalized

        if !isVolumeRoot,
           let volume,
           await scanner.canUseVolumeTreeListing(
               volumeID: volume.id,
               folder: normalized,
               scanRoot: volume.scanRoot
           ) {
            let treeListed = await scanner.folderListingFromVolumeTree(
                at: normalized,
                scanRoot: volume.scanRoot
            )
            guard generation == nil || generation == navigationGeneration else { return }
            let sorted = sortOrder.sort(treeListed)
            entries = sorted
            invalidateAllDerivedCaches()
            refreshChartChildrenIfNeeded()
            await cache.set(
                normalized,
                entries: sorted,
                isVolumeRoot: isVolumeRoot,
                contentLevel: .full
            )
            scheduleSizeIndexPersist()
            return
        }

        if trackDetailedProgress {
            if isGatedSplashVolumeScan {
                scanProgressFraction = VolumeSplashProgressPhases.preparing(
                    fraction: 1,
                    published: scanProgressFraction
                )
            } else {
                scanProgressFraction = max(scanProgressFraction, 0.05)
            }
            scanProgress = L10n.scanReadingList
            scanCurrentFolder = url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent
        }

        let listed = trackDetailedProgress
            ? await scanner.listDirectory(at: normalized)
            : await scanner.listDirectoryLight(at: normalized)
        guard !Task.isCancelled, generation == nil || generation == navigationGeneration else { return }

        entries = await scanner.itemsWithIndexedSizes(listed)
        invalidateAllDerivedCaches()
        if !isVolumeRoot || !trackDetailedProgress {
            refreshChartChildrenIfNeeded()
        }

        if trackDetailedProgress {
            if isGatedSplashVolumeScan {
                scanProgressFraction = VolumeSplashProgressPhases.listed(published: scanProgressFraction)
            } else {
                scanProgressFraction = 0.1
            }
            scanProgress = L10n.scanFoundItems(listed.count)
        }

        let prefs = AppPreferences.load()
        let sizingConfiguration = prefs.sizingConfiguration()
        let parallelism = isVolumeRoot && trackDetailedProgress
            ? max(prefs.scanParallelism, NativeScanRuntime.daisyDefaultWorkers)
            : prefs.scanParallelism
        let useFusedVolumeScan = isVolumeRoot && trackDetailedProgress && NativeDirectoryScanner.isAvailable

        let scanned: [DiskItem]
        var fusedChartResult: ChartTreeBuilder.BuildResult?

        if useFusedVolumeScan {
            let chartDepth = interfaceMode == .simple
                ? SunburstLayoutEngine.Config.daisyDisk.maxDepth
                : SunburstLayoutEngine.Config.standard.maxDepth
            let splashReadyHandler = makeVolumeSplashReadyHandler(
                volume: volume,
                listedEntries: listed
            )
            let fused = await scanner.fusedVolumeRootScan(
                parent: normalized,
                items: listed,
                chartMaxDepth: chartDepth,
                skipHiddenFiles: !prefs.showHiddenFiles,
                parallelism: parallelism,
                configuration: sizingConfiguration,
                shouldCancel: cancelCheck,
                onProgress: { [weak self] update in
                    DispatchQueue.main.async {
                        self?.publishScanProgress(
                            update,
                            trackDetailedProgress: trackDetailedProgress,
                            responsiveUI: !trackDetailedProgress,
                            generation: generation
                        )
                    }
                },
                onSplashReady: splashReadyHandler
            )
            scanned = fused.items
            fusedChartResult = fused.chartResult
            await RestrictedScanRegistrar.recordWalk(fused.sizingWalk)
        } else {
            scanned = await scanner.scanDirectorySizes(
                items: listed,
                parent: normalized,
                configuration: sizingConfiguration,
                parallelism: parallelism,
                shouldCancel: cancelCheck
            ) { [weak self] update in
                DispatchQueue.main.async {
                    self?.publishScanProgress(
                        update,
                        trackDetailedProgress: trackDetailedProgress,
                        responsiveUI: !trackDetailedProgress,
                        generation: generation
                    )
                }
            }
        }
        guard !Task.isCancelled, generation == nil || generation == navigationGeneration else { return }

        flushDeferredScanSort()
        var sorted = sortOrder.sort(scanned)

        if trackDetailedProgress {
            if isGatedSplashVolumeScan {
                scanProgressFraction = VolumeSplashProgressPhases.finalizing(
                    subPhase: 0.35,
                    published: scanProgressFraction
                )
            } else {
                scanProgressFraction = 0.88
            }
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
        invalidateAllDerivedCaches()
        if let fusedChartResult {
            applyFusedChartFromVolumeScan(fusedChartResult, root: normalized, listedEntries: sorted)
        } else if isVolumeRoot && trackDetailedProgress {
            refreshChartChildrenIfNeeded()
        }

        if isVolumeRoot, trackDetailedProgress, fusedChartResult != nil {
            await refreshChartFromScanCache(maxScanDepth: SunburstLayoutEngine.Config.daisyDisk.maxDepth)
        }
        await cache.set(
            normalized,
            entries: sorted,
            isVolumeRoot: isVolumeRoot,
            contentLevel: .full
        )
        scheduleSizeIndexPersist()

        if let fusedChartResult {
            lastScanMetrics = fusedChartResult.scanMetrics
        } else {
            await refreshScanMetricsForCurrentFolder()
        }

        if isVolumeRoot {
            await reconcileRestrictedPathsAfterScan()
            let restrictedRemaining = await RestrictedScanCoordinator.shared.allEvents()
            if restrictedRemaining.isEmpty, let volume, fusedChartResult != nil {
                await VolumeTreeScanCoordinator.shared.markComplete(
                    volumeID: volume.id,
                    scanRoot: volume.scanRoot
                )
            } else if !restrictedRemaining.isEmpty, let volume {
                await VolumeTreeScanCoordinator.shared.clear(volumeID: volume.id)
            }
        }

        if trackDetailedProgress {
            if isGatedSplashVolumeScan {
                scanProgressFraction = VolumeSplashProgressPhases.finalizing(
                    subPhase: 1,
                    published: scanProgressFraction
                )
            } else {
                scanProgressFraction = 0.92
            }
            scanProgress = L10n.scanCaching
        }
    }

    func upgradeContentMetadata(
        at url: URL,
        volume: VolumeInfo?,
        isVolumeRoot: Bool,
        generation: UInt
    ) async {
        guard generation == navigationGeneration else { return }

        let upgraded = await scanner.upgradeToFullContent(at: url, existing: entries)
        guard generation == navigationGeneration else { return }

        var sorted = sortOrder.sort(upgraded)
        if isVolumeRoot, let volume {
            sorted = await scanner.reconcileWithVolumeUsage(
                items: sorted,
                volume: volume,
                atVolumeRoot: true
            )
        }

        entries = sorted
        invalidateAllDerivedCaches()
        await cache.set(
            url,
            entries: sorted,
            isVolumeRoot: isVolumeRoot,
            contentLevel: .full
        )
        scheduleSizeIndexPersist()
    }

    func scheduleSizeIndexPersist() {
        let volumeID = selectedVolume?.id
        Task {
            await SizeIndexCoordinator.shared.schedulePersist(for: volumeID)
        }
    }

    func warmSizeIndexForSelectedVolume() {
        guard let volume = selectedVolume else { return }
        Task {
            await SizeIndexCoordinator.shared.warm(for: volume)
        }
    }

    // MARK: - Prefetch

    func startSmartPrefetch(chartMap: [String: [DiskItem]]? = nil) {
        let map = chartMap ?? chartChildMap
        let parents = chartItems.filter { $0.isDirectory && !$0.isVirtual }
        let plan = ChartPrefetchPlanner.plan(
            chartMap: map,
            chartParents: parents,
            siblings: entries
        )
        startPrefetching(directories: plan)
    }

    func startPrefetching(from items: [DiskItem]) {
        let directories = items
            .filter { $0.isDirectory && !$0.isVirtual }
            .sorted { $0.size > $1.size }
        startPrefetching(directories: directories)
    }

    private func startPrefetching(directories: [DiskItem]) {
        prefetchTask?.cancel()
        guard !directories.isEmpty else { return }

        let volumeID = selectedVolume?.id

        prefetchTask = Task.detached(priority: .utility) { [weak self] in
            let total = directories.count
            for (index, item) in directories.enumerated() {
                guard !Task.isCancelled else { return }

                await self?.prefetchDirectoryIfNeeded(item.url, volumeID: volumeID)

                let folderName = item.name
                let prefetchIndex = index
                await MainActor.run { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    if self.appPhase == .scanning {
                        let prefetchFraction = 0.92 + (Double(prefetchIndex) + 0.4) / Double(max(total, 1)) * 0.08
                        self.scanProgressFraction = max(self.scanProgressFraction, prefetchFraction)
                        self.scanCurrentFolder = folderName
                        self.scanProgress = L10n.scanCachingFolders(prefetchIndex + 1, total)
                    }
                }
            }
        }
    }
}
