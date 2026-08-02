import Foundation
import LazyDiskCore

actor DiskScanner {
    static let shared = DiskScanner()

    let fileManager = FileManager.default
    var sizeCache: [String: Int64] = [:]
    var inflightSizes: [String: Task<Int64, Never>] = [:]
    var inflightChildWalks: [String: Task<DirectorySizeWalker.WalkResult, Never>] = [:]

    func listDirectory(at url: URL) async -> [DiskItem] {
        await listDirectory(at: url, light: false)
    }

    func listDirectoryLight(at url: URL) async -> [DiskItem] {
        await listDirectory(at: url, light: true)
    }

    /// Lists immediate children and sizes every subdirectory in a single subtree walk.
    func scanFolderContents(
        at url: URL,
        light: Bool = false
    ) async -> [DiskItem] {
        let normalized = PathUtils.resolved(url)
        let listed = await listDirectory(at: normalized, light: light)
        return await applySinglePassSizes(parent: normalized, items: listed)
    }

    func calculateSize(for url: URL) async -> Int64 {
        let key = PathUtils.resolved(url).path
        if let cached = sizeCache[key] {
            return cached
        }

        if let existing = inflightSizes[key] {
            return await existing.value
        }

        let task = Task<Int64, Never> {
            let size = await self.childWalk(for: URL(fileURLWithPath: key, isDirectory: true)).totalSize
            self.storeSize(size, forKey: key)
            return size
        }
        inflightSizes[key] = task

        let size = await task.value
        inflightSizes.removeValue(forKey: key)
        return size
    }

    func scanDirectorySizes(
        items: [DiskItem],
        parent: URL? = nil,
        parallelism: Int = 6,
        onProgress: (@Sendable (ScanProgressUpdate) -> Void)? = nil
    ) async -> [DiskItem] {
        let resolvedParent = parent.map(PathUtils.resolved(_:))
        let directoryItems = items.filter { $0.isDirectory && !$0.isVirtual }

        if let resolvedParent, !directoryItems.isEmpty {
            let sized = await applySinglePassSizes(parent: resolvedParent, items: items)
            if let onProgress {
                var completed = 0
                for (index, item) in sized.enumerated() where item.isDirectory && !item.isVirtual {
                    completed += 1
                    onProgress(ScanProgressUpdate(
                        completed: completed,
                        total: max(directoryItems.count, 1),
                        currentName: item.name,
                        itemIndex: index,
                        itemSize: item.size
                    ))
                }
            }
            return sized
        }

        return await scanDirectorySizesParallel(
            items: items,
            parallelism: parallelism,
            onProgress: onProgress
        )
    }

    func reconcileWithVolumeUsage(
        items: [DiskItem],
        volume: VolumeInfo,
        atVolumeRoot: Bool
    ) -> [DiskItem] {
        guard atVolumeRoot else { return items }

        var result = items
        let scannedTotal = result.reduce(Int64(0)) { $0 + $1.size }
        let gap = volume.usedCapacity - scannedTotal

        if gap > 50_000_000 {
            result.append(DiskItem(
                url: URL(fileURLWithPath: "/"),
                name: L10n.snapshotsReserved,
                size: gap,
                isDirectory: false,
                isVirtual: true
            ))
        }

        if volume.purgeableCapacity > 10_000_000 {
            result.append(DiskItem(
                url: URL(fileURLWithPath: "/"),
                name: L10n.purgeableSpace,
                size: volume.purgeableCapacity,
                isDirectory: false,
                isVirtual: true,
                isPurgeable: true
            ))
        }

        let cloudTotal = result.filter(\.isCloudPlaceholder).reduce(Int64(0)) { $0 + $1.size }
        if cloudTotal > 1_000_000 {
            result.append(DiskItem(
                url: URL(fileURLWithPath: "/"),
                name: L10n.iCloudPlaceholder,
                size: cloudTotal,
                isDirectory: false,
                isVirtual: true,
                isCloudPlaceholder: true
            ))
        }

        return result.sorted { $0.size > $1.size }
    }

    func clearSizeCache() {
        for task in inflightSizes.values {
            task.cancel()
        }
        for task in inflightChildWalks.values {
            task.cancel()
        }
        sizeCache.removeAll()
        inflightSizes.removeAll()
        inflightChildWalks.removeAll()
    }
}
