import Foundation

/// Single-pass directory sizing for chart preview and folder scans.
public enum DirectorySizeWalker {
    public struct WalkResult: Sendable, Equatable {
        /// Full path of each immediate child → total subtree size (files only).
        public let childSizesByPath: [String: Int64]
        /// Total size of all file content under `root`.
        public let totalSize: Int64

        public init(childSizesByPath: [String: Int64], totalSize: Int64) {
            self.childSizesByPath = childSizesByPath
            self.totalSize = totalSize
        }
    }

    private static let sizeKeys: [URLResourceKey] = [
        .fileSizeKey,
        .totalFileAllocatedSizeKey,
        .isDirectoryKey,
        .isRegularFileKey
    ]

    /// Sizes every immediate child of `root` with one enumerator pass over the subtree.
    public static func immediateChildSizes(at root: URL) -> WalkResult {
        let normalizedRoot = PathUtils.resolved(root)
        let rootPath = directoryPath(normalizedRoot)
        let prefix = rootPath + "/"

        var childSizes: [String: Int64] = [:]
        var total: Int64 = 0

        guard let enumerator = FileManager.default.enumerator(
            at: normalizedRoot,
            includingPropertiesForKeys: sizeKeys,
            options: [.skipsPackageDescendants]
        ) else {
            let direct = directFileSize(at: normalizedRoot)
            return WalkResult(childSizesByPath: [:], totalSize: direct)
        }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(sizeKeys)) else { continue }
            if values.isDirectory == true { continue }

            let allocated = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            guard allocated > 0 else { continue }

            total += allocated

            let filePath = fileURL.standardizedFileURL.path
            guard filePath.hasPrefix(prefix) else { continue }

            let relative = String(filePath.dropFirst(prefix.count))
            guard !relative.isEmpty else { continue }

            if relative.contains("/") {
                let firstComponent = relative.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
                    .first
                    .map(String.init) ?? relative
                let childPath = prefix + firstComponent
                childSizes[childPath, default: 0] += allocated
            } else {
                childSizes[filePath, default: 0] += allocated
            }
        }

        return WalkResult(childSizesByPath: childSizes, totalSize: total)
    }

    /// Total recursive file size for a single directory path.
    public static func totalSize(of directory: URL) -> Int64 {
        immediateChildSizes(at: directory).totalSize
    }

    public static func applySizes(
        to items: [DiskItem],
        walkResult: WalkResult
    ) -> [DiskItem] {
        items.map { item in
            guard item.isDirectory, !item.isVirtual else {
                if item.isDirectory { return item }
                return item
            }

            var updated = item
            let key = PathUtils.resolved(item.url).path
            updated.size = walkResult.childSizesByPath[key] ?? 0
            updated.isScanning = false
            return updated
        }
    }

    private static func directoryPath(_ url: URL) -> String {
        var path = url.standardizedFileURL.path
        if path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    private static func directFileSize(at url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) else {
            return 0
        }
        return Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
    }
}
