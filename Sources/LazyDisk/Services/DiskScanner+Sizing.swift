import Foundation
import LazyDiskCore

extension DiskScanner {
    func applySinglePassSizes(
        parent: URL,
        items: [DiskItem],
        configuration: DirectorySizeWalker.Configuration? = nil,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (DirectorySizeWalker.WalkResult) -> Void)? = nil
    ) async -> [DiskItem] {
        var effectiveConfiguration = configuration
            ?? AppPreferences.load().sizingConfiguration(fast: onPartial == nil)
        if onPartial == nil {
            effectiveConfiguration.partialUpdateInterval =
                DirectorySizeWalker.Configuration.fastSizing.partialUpdateInterval
        }
        let childURLs = items
            .filter { $0.isDirectory && !$0.isVirtual }
            .map(\.url)
        let walk = await childWalk(
            for: parent,
            listedChildren: childURLs,
            configuration: effectiveConfiguration,
            shouldCancel: shouldCancel,
            onPartial: onPartial
        )
        return DirectorySizeWalker.applySizes(to: items, walkResult: walk)
    }

    func childWalk(
        for url: URL,
        listedChildren: [URL]? = nil,
        configuration: DirectorySizeWalker.Configuration = .default,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (DirectorySizeWalker.WalkResult) -> Void)? = nil
    ) async -> DirectorySizeWalker.WalkResult {
        await DirectorySizeIndex.shared.walk(
            at: url,
            listedChildren: listedChildren,
            configuration: configuration,
            shouldCancel: shouldCancel,
            onPartial: onPartial
        )
    }

    func scanDirectorySizesParallel(
        items: [DiskItem],
        parallelism: Int,
        onProgress: (@Sendable (ScanProgressUpdate) -> Void)?
    ) async -> [DiskItem] {
        let dirIndices = items.enumerated().compactMap { index, item -> Int? in
            item.isDirectory && !item.isVirtual ? index : nil
        }
        let total = dirIndices.count
        let limit = max(1, min(parallelism, 16))

        return await withTaskGroup(of: (Int, Int64).self) { group in
            var nextDirIndex = 0
            var inFlight = 0
            var sizesByIndex: [Int: Int64] = [:]
            var completed = 0

            func enqueueNext() {
                while inFlight < limit, nextDirIndex < dirIndices.count {
                    let index = dirIndices[nextDirIndex]
                    nextDirIndex += 1
                    inFlight += 1
                    group.addTask {
                        let size = await self.calculateSize(for: items[index].url)
                        return (index, size)
                    }
                }
            }

            enqueueNext()

            for await (index, size) in group {
                inFlight -= 1
                completed += 1
                sizesByIndex[index] = size
                onProgress?(ScanProgressUpdate(
                    completed: completed,
                    total: max(total, 1),
                    currentName: items[index].name,
                    itemPath: PathUtils.resolved(items[index].url).path,
                    itemSize: size
                ))
                enqueueNext()
            }

            return items.enumerated().map { index, item in
                guard let size = sizesByIndex[index] else { return item }
                var updated = item
                updated.size = size
                updated.isScanning = false
                return updated
            }
        }
    }

    struct FusedVolumeRootScanResult: Sendable {
        let items: [DiskItem]
        let chartResult: ChartTreeBuilder.BuildResult?
    }

    func fusedVolumeRootScan(
        parent: URL,
        items: [DiskItem],
        chartMaxDepth: Int,
        skipHiddenFiles: Bool,
        parallelism: Int,
        configuration: DirectorySizeWalker.Configuration,
        onProgress: (@Sendable (ScanProgressUpdate) -> Void)? = nil
    ) async -> FusedVolumeRootScanResult {
        let normalized = PathUtils.resolved(parent)
        let directoryItems = items.filter { $0.isDirectory && !$0.isVirtual }

        guard NativeDirectoryScanner.isAvailable,
              let fused = NativeDirectoryScanner.fusedVolumeScan(
                  at: normalized,
                  listedEntries: items,
                  maxDepth: chartMaxDepth,
                  skipHiddenFiles: skipHiddenFiles,
                  parallelism: parallelism,
                  onPartial: { partial in
                      guard let onProgress else { return }
                      let walk = Self.sizingWalk(from: partial, items: items)
                      let partialItems = DirectorySizeWalker.applyPartialSizes(to: items, walkResult: walk)
                      let directoriesResolved = partialItems.filter {
                          $0.isDirectory && !$0.isVirtual && !$0.isScanning
                      }.count
                      let currentName = partialItems
                          .filter { $0.isDirectory && !$0.isVirtual && !$0.isScanning }
                          .max(by: { $0.size < $1.size })?
                          .name ?? normalized.lastPathComponent
                      onProgress(ScanProgressUpdate(
                          completed: directoriesResolved,
                          total: max(directoryItems.count, 1),
                          currentName: currentName,
                          filesScanned: partial.filesScanned,
                          directoriesResolved: directoriesResolved,
                          partialEntries: partialItems
                      ))
                  }
              ) else {
            let sized = await scanDirectorySizes(
                items: items,
                parent: normalized,
                configuration: configuration,
                parallelism: parallelism,
                onProgress: onProgress
            )
            return FusedVolumeRootScanResult(items: sized, chartResult: nil)
        }

        await DirectorySizeIndex.shared.store(fused.sizingWalk, forRoot: normalized.path)
        let sized = DirectorySizeWalker.applySizes(to: items, walkResult: fused.sizingWalk)

        if let onProgress {
            onProgress(ScanProgressUpdate(
                completed: directoryItems.count,
                total: max(directoryItems.count, 1),
                currentName: normalized.lastPathComponent,
                partialEntries: sized
            ))
        }

        return FusedVolumeRootScanResult(items: sized, chartResult: fused.chartResult)
    }

    private static func sizingWalk(
        from chartPartial: ChartTreeBuilder.BuildResult,
        items: [DiskItem]
    ) -> DirectorySizeWalker.WalkResult {
        var childSizesByPath: [String: Int64] = [:]
        for entry in items where !entry.isVirtual {
            let path = PathUtils.resolved(entry.url).path
            if let size = chartPartial.statsByPath[path]?.size, size > 0 {
                childSizesByPath[path] = size
            } else if entry.size > 0 {
                childSizesByPath[path] = entry.size
            }
        }
        return DirectorySizeWalker.WalkResult(
            childSizesByPath: childSizesByPath,
            totalSize: chartPartial.totalSize,
            filesScanned: chartPartial.filesScanned
        )
    }
}
