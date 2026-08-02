// DiskBrowserViewModel+ChartScan.swift — Single-pass metadata tree for sunburst/treemap.
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
        guard chartStyle == .sunburst || chartStyle == .treemap else { return }
        refreshChartChildren()
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

        guard let root = currentPath ?? selectedVolume?.scanRoot else {
            clearChartChildMap()
            isChartChildrenLoading = false
            chartChildrenScanProgress = nil
            return
        }

        let maxDepth = chartTreeMaxDepth
        let maxChildrenPerNode = interfaceMode == .simple ? 12 : 8
        let volumeID = selectedVolume?.id

        isChartChildrenLoading = true

        chartChildRefreshTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }

            let context = await MainActor.run { () -> (listedChildren: [URL], listedEntries: [DiskItem])? in
                guard let self else { return nil }
                let children = self.entries
                    .filter { !$0.isVirtual }
                    .map(\.url)
                return (children, self.entries)
            }
            guard let context else { return }

            var restoredFraction: Double = 0
            if let volumeID {
                let restored = await PersistentChartScanProgressStore.shared.load(volumeID: volumeID)
                restoredFraction = restored?.displayFraction ?? 0
            }

            await MainActor.run { [weak self] in
                self?.chartChildrenScanProgress = ChartChildrenScanProgress(
                    completedFolders: 0,
                    totalFolders: 1,
                    currentFolderName: root.lastPathComponent,
                    currentDepth: 1,
                    maxDepth: maxDepth + 1,
                    displayFraction: restoredFraction
                )
            }

            let partialPublishGate = PartialPublishGate()

            let buildResult = ChartTreeBuilder.build(
                at: root,
                listedChildren: context.listedChildren,
                maxDepth: maxDepth,
                configuration: .chartPreview,
                shouldCancel: { Task.isCancelled },
                onPartial: { partial in
                    let fraction = min(
                        0.99,
                        Double(partial.filesScanned) / Double(max(partial.filesScanned + 500, 1))
                    )

                    if let volumeID {
                        Task {
                            await PersistentChartScanProgressStore.shared.scheduleSave(
                                volumeID: volumeID,
                                displayFraction: max(restoredFraction, fraction),
                                completedFolders: 0,
                                estimatedTotalFolders: 1
                            )
                        }
                    }

                    guard partialPublishGate.shouldPublish() else { return }

                    let snapshot = ChartTreeBuilder.childMap(
                        from: partial,
                        root: root,
                        listedEntries: context.listedEntries,
                        maxChildrenPerNode: maxChildrenPerNode
                    )

                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.chartChildrenScanProgress = ChartChildrenScanProgress(
                            completedFolders: 0,
                            totalFolders: 1,
                            currentFolderName: root.lastPathComponent,
                            currentDepth: 1,
                            maxDepth: maxDepth + 1,
                            filesScanned: partial.filesScanned,
                            displayFraction: max(
                                self.chartChildrenScanProgress?.displayFraction ?? 0,
                                fraction
                            )
                        )
                        self.publishChartChildMap(snapshot)
                    }
                }
            )

            guard !Task.isCancelled else { return }

            let finalMap = ChartTreeBuilder.childMap(
                from: buildResult,
                root: root,
                listedEntries: context.listedEntries,
                maxChildrenPerNode: maxChildrenPerNode
            )

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isChartChildrenLoading = false
                self.chartChildrenScanProgress = nil
                self.publishChartChildMap(finalMap)
                self.startSmartPrefetch(chartMap: finalMap)
            }
        }
    }

    private var chartTreeMaxDepth: Int {
        interfaceMode == .simple
            ? SunburstLayoutEngine.Config.daisyDisk.maxDepth
            : SunburstLayoutEngine.Config.standard.maxDepth
    }
}
