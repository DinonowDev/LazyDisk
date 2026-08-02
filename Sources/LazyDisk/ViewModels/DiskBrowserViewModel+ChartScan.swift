// DiskBrowserViewModel+ChartScan.swift — Lazy metadata tree for sunburst/treemap.
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
        let rootName = root.lastPathComponent.isEmpty ? "Data" : root.lastPathComponent
        let expandedParents = chartExpandedOtherParents
        let otherName = L10n.filterOther

        isChartChildrenLoading = true

        chartChildRefreshTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }

            let listedEntries = await MainActor.run { () -> [DiskItem]? in
                guard let self else { return nil }
                return self.entries
            }
            guard let listedEntries else { return }

            await MainActor.run { [weak self] in
                self?.chartChildrenScanProgress = ChartChildrenScanProgress(
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

            let buildResult = ChartTreeBuilder.build(
                at: root,
                listedEntries: listedEntries,
                options: ChartTreeBuilder.BuildOptions(
                    maxDepth: maxDepth,
                    skipHiddenFiles: true,
                    partialUpdateInterval: 40,
                    expandedParents: expandedParents
                ),
                shouldCancel: { Task.isCancelled },
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

                    let snapshot = ChartTreeBuilder.childMap(
                        from: partial,
                        root: root,
                        listedEntries: listedEntries,
                        maxChildrenPerNode: maxChildrenPerNode,
                        otherItemName: otherName
                    )

                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.chartChildrenScanProgress = ChartChildrenScanProgress(
                            completedFolders: 0,
                            totalFolders: 0,
                            currentFolderName: rootName,
                            currentDepth: 1,
                            maxDepth: maxDepth + 1,
                            filesScanned: partial.filesScanned,
                            displayFraction: max(
                                self.chartChildrenScanProgress?.displayFraction ?? 0,
                                fraction
                            )
                        )
                        self.chartDeferredByParent = partial.deferredByParent
                        self.publishChartChildMap(snapshot)
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

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isChartChildrenLoading = false
                self.chartChildrenScanProgress = nil
                self.chartDeferredByParent = buildResult.deferredByParent
                self.publishChartChildMap(finalMap)
                self.startSmartPrefetch(chartMap: finalMap)
            }
        }
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
}
