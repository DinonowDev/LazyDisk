import Foundation
import LazyDiskCore

extension DiskScanner {
    func applySinglePassSizes(
        parent: URL,
        items: [DiskItem],
        configuration: DirectorySizeWalker.Configuration = .default,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (DirectorySizeWalker.WalkResult) -> Void)? = nil
    ) async -> [DiskItem] {
        let effectiveConfiguration = onPartial == nil ? .fastSizing : configuration
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
}
