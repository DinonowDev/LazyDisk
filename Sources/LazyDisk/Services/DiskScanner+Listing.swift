import Foundation
import LazyDiskCore

extension DiskScanner {
    static let fullListingKeys: [URLResourceKey] = [
        .isDirectoryKey,
        .fileSizeKey,
        .totalFileAllocatedSizeKey,
        .isHiddenKey,
        .isSymbolicLinkKey,
        .contentModificationDateKey,
        .isUbiquitousItemKey,
        .ubiquitousItemDownloadingStatusKey
    ]

    static let lightListingKeys: [URLResourceKey] = [
        .isDirectoryKey,
        .fileSizeKey,
        .totalFileAllocatedSizeKey,
        .isHiddenKey,
        .isSymbolicLinkKey
    ]

    func listDirectory(at url: URL, light: Bool) async -> [DiskItem] {
        let normalized = PathUtils.resolved(url)
        let keys = light ? Self.lightListingKeys : Self.fullListingKeys
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: normalized,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants]
            )
        } catch {
            return []
        }

        var items: [DiskItem] = []

        for childURL in contents {
            let values = try? childURL.resourceValues(forKeys: Set(keys))
            let isSymlink = values?.isSymbolicLink ?? false
            let isDir = values?.isDirectory ?? false
            let isHidden = values?.isHidden ?? childURL.lastPathComponent.hasPrefix(".")
            let allocated = Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
            let modified = light ? nil : values?.contentModificationDate
            let isUbiquitous = light ? false : (values?.isUbiquitousItem ?? false)
            let downloadStatus = light ? nil : values?.ubiquitousItemDownloadingStatus
            let isCloudPlaceholder = isUbiquitous && downloadStatus == .notDownloaded

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
                    isCloudPlaceholder: isCloudPlaceholder
                ))
            } else {
                items.append(DiskItem(
                    url: resolved,
                    size: allocated,
                    isDirectory: false,
                    isHidden: isHidden,
                    modifiedDate: modified,
                    isCloudPlaceholder: isCloudPlaceholder
                ))
            }
        }

        return items.sorted { lhs, rhs in
            if lhs.isHidden != rhs.isHidden { return !lhs.isHidden }
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
