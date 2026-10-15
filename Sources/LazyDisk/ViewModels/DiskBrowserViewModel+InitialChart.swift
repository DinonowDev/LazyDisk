// DiskBrowserViewModel+InitialChart.swift — Chart prep before first screen (DaisyDisk-style depth).
import Foundation
import LazyDiskCore

extension DiskBrowserViewModel {
    var initialChartPrefetchMaxDepth: Int {
        interfaceMode == .simple
            ? SunburstLayoutEngine.Config.daisyDisk.maxDepth
            : SunburstLayoutEngine.Config.standard.maxDepth
    }

    /// Publishes the chart from the fused scan, then prefetches display depth (in background when requested).
    func prepareInitialChartPresentation(
        volume: VolumeInfo,
        deferDisplayDepthPrefetch: Bool = false
    ) async {
        isInitialChartReady = false
        let targetDepth = initialChartPrefetchMaxDepth
        let scanRoot = volume.scanRoot

        if let pending = pendingFusedVolumeChart {
            chartDeferredByParent = pending.buildResult.deferredByParent
            let scanRoot = PathUtils.resolved(volume.scanRoot)
            await storeVolumeChartChildMap(
                volumeID: volume.id,
                buildResult: pending.buildResult,
                root: scanRoot,
                listedEntries: entries
            )
            pendingFusedVolumeChart = nil
            if chartStyle == .sunburst {
                await ensureVolumeChartMapPublished(volumeID: volume.id)
            }
        } else if chartStyle == .sunburst, isAtVolumeRoot {
            await ensureVolumeChartMapPublished(volumeID: volume.id)
        } else if chartStyle != .sunburst {
            clearChartChildMap()
        }

        isInitialChartReady = true

        if deferDisplayDepthPrefetch {
            startDeferredInitialChartPrefetch(volume: volume, targetDepth: targetDepth, scanRoot: scanRoot)
            return
        }

        if chartStyle == .sunburst {
            isChartChildrenLoading = true
            chartChildrenScanProgress = ChartChildrenScanProgress(
                completedFolders: 0,
                totalFolders: 0,
                currentFolderName: scanRoot.lastPathComponent,
                currentDepth: 1,
                maxDepth: targetDepth + 1,
                filesScanned: 0,
                displayFraction: 0
            )
        }

        await prefetchDepthRangeForSplash(
            1...targetDepth,
            scanRoot: scanRoot,
            volumeID: volume.id
        )

        isChartChildrenLoading = false
        chartChildrenScanProgress = nil
    }

    func startDeferredInitialChartPrefetch(
        volume: VolumeInfo,
        targetDepth: Int,
        scanRoot: URL
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.chartStyle == .sunburst {
                self.isChartChildrenLoading = true
                self.chartChildrenScanProgress = ChartChildrenScanProgress(
                    completedFolders: 0,
                    totalFolders: 0,
                    currentFolderName: scanRoot.lastPathComponent,
                    currentDepth: 1,
                    maxDepth: targetDepth + 1,
                    filesScanned: 0,
                    displayFraction: 0
                )
            }
            await self.prefetchDepthRangeForSplash(
                1...targetDepth,
                scanRoot: scanRoot,
                volumeID: volume.id
            )
            self.isChartChildrenLoading = false
            self.chartChildrenScanProgress = nil
            if self.chartStyle == .sunburst, self.isAtVolumeRoot {
                await self.ensureVolumeChartMapPublished(volumeID: volume.id)
            }
        }
    }

    private func prefetchDepthRangeForSplash(
        _ range: ClosedRange<Int>,
        scanRoot: URL,
        volumeID: String?
    ) async {
        var completed = 0
        var total = 0
        for depth in range {
            total += await directoriesAtDepth(depth, scanRoot: scanRoot, rootEntries: entries).count
        }

        for depth in range {
            guard !Task.isCancelled else { return }

            let directories = await directoriesAtDepth(depth, scanRoot: scanRoot, rootEntries: entries)
            for item in directories {
                guard !Task.isCancelled else { return }

                await prefetchDirectoryIfNeeded(item.url, volumeID: volumeID)
                completed += 1

                if isGatedSplashVolumeScan {
                    let ratio = Double(completed) / Double(max(total, 1))
                    scanProgressFraction = VolumeSplashProgressPhases.chartPrefetch(
                        ratio: ratio,
                        published: scanProgressFraction
                    )
                    scanCurrentFolder = item.name
                    scanProgress = L10n.scanCachingFolders(completed, total)

                    if chartStyle == .sunburst {
                        chartChildrenScanProgress = ChartChildrenScanProgress(
                            completedFolders: completed,
                            totalFolders: max(total, 1),
                            currentFolderName: item.name,
                            currentDepth: depth,
                            maxDepth: initialChartPrefetchMaxDepth + 1,
                            filesScanned: 0,
                            displayFraction: ratio
                        )
                    }
                }
            }
        }
    }
}
