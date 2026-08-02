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
            var latestPartial = items
            let sized = await applySinglePassSizes(
                parent: resolvedParent,
                items: items,
                configuration: onProgress == nil ? .fastSizing : .default,
                onPartial: { walk in
                    latestPartial = DirectorySizeWalker.applyPartialSizes(to: items, walkResult: walk)
                    guard let onProgress else { return }

                    let directoriesResolved = latestPartial.filter {
                        $0.isDirectory && !$0.isVirtual && !$0.isScanning
                    }.count

                    let currentName = latestPartial
                        .filter { $0.isDirectory && !$0.isVirtual && !$0.isScanning }
                        .max(by: { $0.size < $1.size })?
                        .name ?? resolvedParent.lastPathComponent

                    onProgress(ScanProgressUpdate(
                        completed: directoriesResolved,
                        total: max(directoryItems.count, 1),
                        currentName: currentName,
                        filesScanned: walk.filesScanned,
                        directoriesResolved: directoriesResolved
                    ))

                    for (index, item) in latestPartial.enumerated()
                        where item.isDirectory && !item.isVirtual && !item.isScanning {
                        onProgress(ScanProgressUpdate(
                            completed: directoriesResolved,
                            total: max(directoryItems.count, 1),
                            currentName: item.name,
                            itemIndex: index,
                            itemSize: item.size,
                            filesScanned: walk.filesScanned,
                            directoriesResolved: directoriesResolved
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
