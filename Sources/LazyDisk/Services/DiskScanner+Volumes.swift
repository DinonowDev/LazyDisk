import Foundation
import LazyDiskCore

extension DiskScanner {
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
}
