// DiskBrowserViewModel+ChartScan.swift — Fast parallel chart child discovery for sunburst/treemap.
import Foundation

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
        let seededMap = seededChartChildEntries(for: parents)
        let parallelism = AppPreferences.load().scanParallelism

        isChartChildrenLoading = true
        chartChildrenScanProgress = ChartChildrenScanProgress(
            completedFolders: seededMap.count,
            totalFolders: max(parents.count, seededMap.count),
            currentFolderName: "",
            currentDepth: 1,
            maxDepth: maxDepth + 1
        )

        if !seededMap.isEmpty {
            publishChartChildMap(seededMap)
        }

        chartChildRefreshTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }

            let request = ChartScanEngine.Request(
                parents: parents,
                maxDepth: maxDepth,
                parallelism: parallelism,
                seededEntriesByParentPath: seededMap
            )

            let partialPublishGate = PartialPublishGate()

            let finalMap = await ChartScanEngine.buildChildMap(
                request: request,
                isCancelled: { Task.isCancelled },
                onProgress: { progress in
                    Task { @MainActor [weak self] in
                        self?.chartChildrenScanProgress = progress
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
