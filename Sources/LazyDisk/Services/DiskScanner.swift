import Foundation
import LazyDiskCore

actor DiskScanner {
    static let shared = DiskScanner()

    let fileManager = FileManager.default

    func listDirectory(at url: URL) async -> [DiskItem] {
        await listDirectory(at: url, light: false)
    }

    func listDirectoryLight(at url: URL) async -> [DiskItem] {
        await listDirectory(at: url, light: true)
    }

    func scanFolderContents(
        at url: URL,
        light: Bool = false,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable ([DiskItem], Int) -> Void)? = nil
    ) async -> [DiskItem] {
        let normalized = PathUtils.resolved(url)
        let listed = await listDirectory(at: normalized, light: light)
        let configuration: DirectorySizeWalker.Configuration = light ? .chartPreview : .default

        return await applySinglePassSizes(
            parent: normalized,
            items: listed,
            configuration: configuration,
            shouldCancel: shouldCancel,
            onPartial: { walk in
                guard let onPartial else { return }
                let partial = DirectorySizeWalker.applyPartialSizes(to: listed, walkResult: walk)
                onPartial(partial, walk.filesScanned)
            }
        )
    }

    func calculateSize(for url: URL) async -> Int64 {
        let key = PathUtils.resolved(url).path
        if let cached = await DirectorySizeIndex.shared.size(for: key) {
            return cached
        }
        return await childWalk(for: url).totalSize
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
            var working = items
            let sized = await applySinglePassSizes(
                parent: resolvedParent,
                items: working,
                onPartial: { walk in
                    guard let onProgress else { return }
                    working = DirectorySizeWalker.applyPartialSizes(to: working, walkResult: walk)
                    for (index, item) in working.enumerated() where item.isDirectory && !item.isVirtual {
                        guard !item.isScanning else { continue }
                        onProgress(ScanProgressUpdate(
                            completed: 0,
                            total: max(directoryItems.count, 1),
                            currentName: item.name,
                            itemIndex: index,
                            itemSize: item.size
                        ))
                    }
                }
            )

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

    func clearSizeCache() async {
        await DirectorySizeIndex.shared.clear()
    }
}
