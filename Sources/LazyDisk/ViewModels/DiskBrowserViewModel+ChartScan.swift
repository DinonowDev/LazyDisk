// DiskBrowserViewModel+ChartScan.swift — Fast parallel chart child discovery for sunburst/treemap.
import Foundation

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
            currentFolderName: ""
        )

        if !seededMap.isEmpty {
            publishChartChildMap(seededMap)
        }

        chartChildRefreshTask = Task.detached(priority: .utility) { [weak viewModel = self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }

            let request = ChartScanEngine.Request(
                parents: parents,
                maxDepth: maxDepth,
                parallelism: parallelism,
                seededEntriesByParentPath: seededMap
            )

            let finalMap = await ChartScanEngine.buildChildMap(
                request: request,
                isCancelled: { Task.isCancelled },
                onProgress: { progress in
                    Task { @MainActor in
                        viewModel?.chartChildrenScanProgress = progress
                    }
                },
                onPartial: { snapshot in
                    Task { @MainActor in
                        viewModel?.publishChartChildMap(snapshot)
                    }
                },
                chartChildren: { entries in
                    await MainActor.run {
                        viewModel?.chartChildren(from: entries) ?? []
                    }
                }
            )

            guard !Task.isCancelled else { return }
            await MainActor.run {
                viewModel?.isChartChildrenLoading = false
                viewModel?.chartChildrenScanProgress = nil
                viewModel?.publishChartChildMap(finalMap)
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
