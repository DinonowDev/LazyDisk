import Foundation
import LazyDiskCore

extension DiskScanner {
    func applySinglePassSizes(parent: URL, items: [DiskItem]) async -> [DiskItem] {
        let walk = await childWalk(for: parent)
        var updated = DirectorySizeWalker.applySizes(to: items, walkResult: walk)

        for index in updated.indices where updated[index].isDirectory && !updated[index].isVirtual {
            let key = PathUtils.resolved(updated[index].url).path
            sizeCache[key] = updated[index].size
        }

        sizeCache[PathUtils.resolved(parent).path] = walk.totalSize
        return updated
    }

    func childWalk(for url: URL) async -> DirectorySizeWalker.WalkResult {
        let key = PathUtils.resolved(url).path

        if let existing = inflightChildWalks[key] {
            return await existing.value
        }

        let task = Task<DirectorySizeWalker.WalkResult, Never> {
            await Task.detached(priority: .utility) {
                DirectorySizeWalker.immediateChildSizes(at: URL(fileURLWithPath: key, isDirectory: true))
            }.value
        }
        inflightChildWalks[key] = task

        let result = await task.value
        inflightChildWalks.removeValue(forKey: key)
        sizeCache[key] = result.totalSize
        for (childPath, size) in result.childSizesByPath {
            sizeCache[childPath] = size
        }
        return result
    }

    func storeSize(_ size: Int64, forKey key: String) {
        sizeCache[key] = size
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
            var updated = items
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
                updated[index].size = size
                updated[index].isScanning = false
                onProgress?(ScanProgressUpdate(
                    completed: completed,
                    total: max(total, 1),
                    currentName: items[index].name,
                    itemIndex: index,
                    itemSize: size
                ))
                enqueueNext()
            }

            return updated
        }
    }
}
