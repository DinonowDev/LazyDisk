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
        let prefs = AppPreferences.load()
        let configuration = prefs.sizingConfiguration(
            partialUpdateInterval: light ? 40 : 96,
            fast: light
        )

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
        let configuration = AppPreferences.load().sizingConfiguration(fast: true)
        return await childWalk(for: url, configuration: configuration).totalSize
    }

    func scanDirectorySizes(
        items: [DiskItem],
        parent: URL? = nil,
        configuration: DirectorySizeWalker.Configuration? = nil,
        parallelism: Int = 6,
        onProgress: (@Sendable (ScanProgressUpdate) -> Void)? = nil
    ) async -> [DiskItem] {
        let resolvedParent = parent.map(PathUtils.resolved(_:))
        let directoryItems = items.filter { $0.isDirectory && !$0.isVirtual }
        var sizingConfiguration = configuration
            ?? AppPreferences.load().sizingConfiguration(fast: onProgress == nil)
        if onProgress == nil {
            sizingConfiguration.partialUpdateInterval = DirectorySizeWalker.Configuration.fastSizing.partialUpdateInterval
        }
        sizingConfiguration.parallelism = parallelism

        if let resolvedParent, !directoryItems.isEmpty {
            final class PartialHolder: @unchecked Sendable {
                var items: [DiskItem]
                init(_ items: [DiskItem]) { self.items = items }
            }
            let partialHolder = PartialHolder(items)
            let sized = await applySinglePassSizes(
                parent: resolvedParent,
                items: items,
                configuration: sizingConfiguration,
                onPartial: { walk in
                    partialHolder.items = DirectorySizeWalker.applyPartialSizes(to: items, walkResult: walk)
                    let latestPartial = partialHolder.items
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
                        directoriesResolved: directoriesResolved,
                        partialEntries: latestPartial
                    ))
                }
            )

            if let onProgress {
                onProgress(ScanProgressUpdate(
                    completed: directoryItems.count,
                    total: max(directoryItems.count, 1),
                    currentName: resolvedParent.lastPathComponent,
                    partialEntries: sized
                ))
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
        let purgeable = max(volume.purgeableCapacity, 0)
        let residual = volume.usedCapacity - scannedTotal - purgeable

        if residual > 50_000_000 {
            result.append(DiskItem(
                url: URL(fileURLWithPath: "/"),
                name: L10n.systemUnscanned,
                size: residual,
                isDirectory: false,
                isVirtual: true
            ))
        }

        if purgeable > 10_000_000 {
            result.append(DiskItem(
                url: URL(fileURLWithPath: "/"),
                name: L10n.purgeableSpace,
                size: purgeable,
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
