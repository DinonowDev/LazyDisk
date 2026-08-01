import Foundation

actor DiskScanner {
    static let shared = DiskScanner()

    private let fileManager = FileManager.default
    private var sizeCache: [String: Int64] = [:]
    private var inflightSizes: [String: Task<Int64, Never>] = [:]

    func listVolumes() -> [VolumeInfo] {
        guard let urls = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeIsRemovableKey,
                .volumeIsEjectableKey,
                .volumeIsLocalKey,
                .volumeIsInternalKey,
                .volumeIsBrowsableKey
            ],
            options: [.skipHiddenVolumes]
        ) else { return [] }

        var volumes: [VolumeInfo] = []

        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeIsRemovableKey,
                .volumeIsEjectableKey,
                .volumeIsLocalKey,
                .volumeIsInternalKey,
                .volumeIsBrowsableKey
            ]) else { continue }

            if !VolumeFilter.isUserFacing(path: url.path, isBrowsable: values.volumeIsBrowsable) {
                continue
            }

            let isRemovable = values.volumeIsRemovable ?? false
            let isEjectable = values.volumeIsEjectable ?? false
            let isLocal = values.volumeIsLocal ?? true
            let isNetwork = !isLocal && !url.path.hasPrefix("/System/Volumes/Data")

            let name = values.volumeName ?? url.lastPathComponent
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = Int64(values.volumeAvailableCapacity ?? 0)
            let importantAvailable = Int64(values.volumeAvailableCapacityForImportantUsage ?? available)

            guard total > 0 else { continue }

            let purgeable = max(0, importantAvailable - available)
            let dataURL = resolveDataVolume(for: url)
            let displayName = displayVolumeName(name: name, url: url, isRemovable: isRemovable, isNetwork: isNetwork)

            volumes.append(VolumeInfo(
                id: url.path,
                url: url,
                name: displayName,
                totalCapacity: total,
                availableCapacity: available,
                dataVolumeURL: dataURL,
                purgeableCapacity: purgeable,
                isRemovable: isRemovable,
                isNetworkVolume: isNetwork,
                isEjectable: isEjectable
            ))
        }

        return volumes.sorted { lhs, rhs in
            if lhs.isRemovable != rhs.isRemovable { return !lhs.isRemovable }
            return lhs.url.path < rhs.url.path
        }
    }

    func listDirectory(at url: URL) async -> [DiskItem] {
        let normalized = PathUtils.resolved(url)
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: normalized,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .fileSizeKey,
                    .totalFileAllocatedSizeKey,
                    .isHiddenKey,
                    .isSymbolicLinkKey,
                    .contentModificationDateKey,
                    .isUbiquitousItemKey,
                    .ubiquitousItemDownloadingStatusKey
                ],
                options: [.skipsPackageDescendants]
            )
        } catch {
            return []
        }

        var items: [DiskItem] = []

        for childURL in contents {
            let values = try? childURL.resourceValues(forKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .totalFileAllocatedSizeKey,
                .isHiddenKey,
                .isSymbolicLinkKey,
                .contentModificationDateKey,
                .isUbiquitousItemKey,
                .ubiquitousItemDownloadingStatusKey
            ])

            let isSymlink = values?.isSymbolicLink ?? false
            let isDir = values?.isDirectory ?? false
            let isHidden = values?.isHidden ?? childURL.lastPathComponent.hasPrefix(".")
            let allocated = Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
            let modified = values?.contentModificationDate
            let isUbiquitous = values?.isUbiquitousItem ?? false
            let downloadStatus = values?.ubiquitousItemDownloadingStatus
            let isCloudPlaceholder = isUbiquitous && downloadStatus == .notDownloaded
            let isPurgeable = false

            if isSymlink && !isDir {
                continue
            }

            let resolved = PathUtils.resolved(childURL)

            if isDir {
                items.append(DiskItem(
                    url: resolved,
                    isDirectory: true,
                    isScanning: true,
                    isHidden: isHidden,
                    modifiedDate: modified,
                    isCloudPlaceholder: isCloudPlaceholder,
                    isPurgeable: isPurgeable
                ))
            } else {
                items.append(DiskItem(
                    url: resolved,
                    size: allocated,
                    isDirectory: false,
                    isHidden: isHidden,
                    modifiedDate: modified,
                    isCloudPlaceholder: isCloudPlaceholder,
                    isPurgeable: isPurgeable
                ))
            }
        }

        return items.sorted { lhs, rhs in
            if lhs.isHidden != rhs.isHidden { return !lhs.isHidden }
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func calculateSize(for url: URL) async -> Int64 {
        let key = PathUtils.resolved(url).path
        let resolvedURL = URL(fileURLWithPath: key, isDirectory: true)

        if let cached = sizeCache[key] {
            return cached
        }

        if let existing = inflightSizes[key] {
            return await existing.value
        }

        let task = Task<Int64, Never> {
            await Task.detached(priority: .utility) {
                Self.sizeOfDirectory(at: resolvedURL)
            }.value
        }
        inflightSizes[key] = task

        let size = await task.value
        sizeCache[key] = size
        inflightSizes.removeValue(forKey: key)
        return size
    }

    func scanDirectorySizes(
        items: [DiskItem],
        parallelism: Int = 6,
        onProgress: (@Sendable (ScanProgressUpdate) -> Void)? = nil
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
        sizeCache.removeAll()
        inflightSizes.removeAll()
    }

    // MARK: - Private

    private func displayVolumeName(name: String, url: URL, isRemovable: Bool, isNetwork: Bool) -> String {
        if isNetwork { return "\(name) (Network)" }
        if isRemovable && url.path.hasPrefix("/Volumes/") { return "\(name) (External)" }
        return name
    }

    private func resolveDataVolume(for volumeURL: URL) -> URL? {
        let dataPath = URL(fileURLWithPath: "/System/Volumes/Data", isDirectory: true)
        guard fileManager.fileExists(atPath: dataPath.path) else { return nil }

        if volumeURL.path == "/" || volumeURL.path == "/System/Volumes/Data" {
            return dataPath
        }

        if volumeURL.path.hasPrefix("/Volumes/") {
            return volumeURL
        }

        return nil
    }

    private nonisolated static func sizeOfDirectory(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var total: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [
                .fileSizeKey,
                .totalFileAllocatedSizeKey,
                .isDirectoryKey,
                .isRegularFileKey
            ],
            options: []
        ) else {
            return fileSize(of: url)
        }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [
                .isDirectoryKey,
                .totalFileAllocatedSizeKey,
                .fileSizeKey
            ]) else { continue }

            if values.isDirectory == true { continue }

            let allocated = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            total += allocated
        }

        return total
    }

    private nonisolated static func fileSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) else {
            return 0
        }
        return Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
    }
}
