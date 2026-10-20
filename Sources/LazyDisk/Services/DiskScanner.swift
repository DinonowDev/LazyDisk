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

    /// Applies cached subtree sizes so the folder list can render before a full walk finishes.
    func itemsWithIndexedSizes(_ items: [DiskItem], scanRoot: URL? = nil) async -> [DiskItem] {
        let snapshot = await DirectorySizeIndex.shared.sizesSnapshot()
        return items.map { item in
            var copy = item
            let resolvedSize: Int64?
            if let scanRoot {
                resolvedSize = PathUtils.directorySize(in: snapshot, itemURL: item.url, scanRoot: scanRoot)
            } else {
                let path = PathUtils.resolved(item.url).path
                resolvedSize = snapshot[path]
            }
            if let size = resolvedSize, size > 0 {
                copy.size = size
                if copy.isDirectory {
                    copy.isScanning = false
                }
            }
            return copy
        }
    }

    func instantFolderListing(at url: URL, scanRoot: URL? = nil) async -> [DiskItem] {
        let listed = await listDirectoryLight(at: url)
        return await itemsWithIndexedSizes(listed, scanRoot: scanRoot)
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
        shouldCancel: (@Sendable () -> Bool)? = nil,
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
                shouldCancel: shouldCancel,
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
        let snapshots = atVolumeRoot
            ? APFSSnapshotStore.list(volumePath: volume.scanRoot.path).filter { APFSSnapshotName.isDeletable($0.name) }
            : []
        return VolumeUsageReconciler.reconcile(
            items: items,
            volumePath: volume.scanRoot.path,
            usedCapacity: volume.usedCapacity,
            purgeableCapacity: volume.purgeableCapacity,
            snapshots: snapshots,
            atVolumeRoot: atVolumeRoot,
            labels: VolumeReconcileLabels(
                purgeable: L10n.purgeableSpace,
                unscanned: L10n.systemUnscanned,
                cloud: L10n.iCloudPlaceholder,
                snapshots: L10n.localSnapshots
            )
        )
    }

    func clearSizeCache() async {
        await DirectorySizeIndex.shared.clear()
        await VolumeTreeScanCoordinator.shared.clear(volumeID: nil)
    }
}
