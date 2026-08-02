// DiskBrowserViewModel+ChartScan.swift — Fast parallel chart child discovery for sunburst/treemap.
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
        let maxChildrenPerNode = interfaceMode == .simple ? 12 : 8
        let seededMap = seededChartChildEntries(for: parents)
        let parallelism = AppPreferences.load().scanParallelism
        let volumeID = selectedVolume?.id

        let estimatedTotal = ChartWorkloadEstimator.estimateTotalFolders(
            rootFolderCount: parents.count,
            maxDepth: maxDepth,
            maxChildrenPerNode: maxChildrenPerNode
        )

        isChartChildrenLoading = true

        chartChildRefreshTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }

            var restoredFraction: Double = 0
            if let volumeID {
                let restored = await PersistentChartScanProgressStore.shared.load(volumeID: volumeID)
                restoredFraction = restored?.displayFraction ?? 0
            }

            await MainActor.run { [weak self] in
                self?.chartChildrenScanProgress = ChartChildrenScanProgress(
                    completedFolders: seededMap.count,
                    totalFolders: max(estimatedTotal, seededMap.count),
                    currentFolderName: "",
                    currentDepth: 1,
                    maxDepth: maxDepth + 1,
                    displayFraction: restoredFraction
                )
                if !seededMap.isEmpty {
                    self?.publishChartChildMap(seededMap)
                }
            }

            let request = ChartScanEngine.Request(
                parents: parents,
                maxDepth: maxDepth,
                parallelism: parallelism,
                maxChildrenPerNode: maxChildrenPerNode,
                seededEntriesByParentPath: seededMap,
                restoredDisplayFraction: restoredFraction
            )

            let partialPublishGate = PartialPublishGate()

            let finalMap = await ChartScanEngine.buildChildMap(
                request: request,
                isCancelled: { Task.isCancelled },
                onProgress: { progress in
                    if let volumeID {
                        Task {
                            await PersistentChartScanProgressStore.shared.scheduleSave(
                                volumeID: volumeID,
                                displayFraction: progress.displayFraction,
                                completedFolders: progress.completedFolders,
                                estimatedTotalFolders: progress.totalFolders
                            )
                        }
                    }

                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let current = self.chartChildrenScanProgress {
                            self.chartChildrenScanProgress = current.advancing(to: progress)
                        } else {
                            self.chartChildrenScanProgress = progress
                        }
                    }
                },
                onPartial: { snapshot in
                    guard partialPublishGate.shouldPublish() else { return }
                    Task { @MainActor [weak self] in
                        self?.publishChartChildMap(snapshot)
                    }
                },
                chartChildren: { entries in
                    await MainActor.run { [weak self] in
                        self?.chartChildren(from: entries) ?? []
                    }
                }
            )

            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isChartChildrenLoading = false
                self.chartChildrenScanProgress = nil
                self.publishChartChildMap(finalMap)
                self.startSmartPrefetch(chartMap: finalMap)
            }
        }
    }

    private func seededChartChildEntries(for parents: [DiskItem]) -> [String: [DiskItem]] {
        guard let currentPath, !entries.isEmpty else { return [:] }

        let currentFolderPath = PathUtils.resolved(currentPath).path
        let currentChildren = chartChildren(from: entries)
        guard !currentChildren.isEmpty else { return [:] }

        var seeded: [String: [DiskItem]] = [:]

        for parent in parents {
            let parentPath = PathUtils.resolved(parent.url).path
            guard parentPath == currentFolderPath else { continue }
            seeded[parentPath] = currentChildren
        }

        if seeded[currentFolderPath] == nil {
            seeded[currentFolderPath] = currentChildren
        }

        return seeded
    }
}
