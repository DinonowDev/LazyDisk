import Foundation

/// Single-pass metadata tree for sunburst/treemap charts (sizes + child counts, no full listing).
public enum ChartTreeBuilder {
    public struct NodeStats: Sendable, Equatable {
        public var size: Int64
        public var directFileCount: Int
        public var isDirectory: Bool

        public init(size: Int64 = 0, directFileCount: Int = 0, isDirectory: Bool = true) {
            self.size = size
            self.directFileCount = directFileCount
            self.isDirectory = isDirectory
        }
    }

    public struct BuildResult: Sendable, Equatable {
        public let statsByPath: [String: NodeStats]
        public let totalSize: Int64
        public let filesScanned: Int

        public init(statsByPath: [String: NodeStats], totalSize: Int64, filesScanned: Int) {
            self.statsByPath = statsByPath
            self.totalSize = totalSize
            self.filesScanned = filesScanned
        }
    }

    public static let defaultMaxDepth = 4

    public static func build(
        at root: URL,
        listedChildren: [URL],
        maxDepth: Int = defaultMaxDepth,
        configuration: DirectorySizeWalker.Configuration = .chartPreview,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (BuildResult) -> Void)? = nil
    ) -> BuildResult {
        let normalizedRoot = PathUtils.resolved(root)
        let matcher = ChildPathMatcher(root: normalizedRoot, children: listedChildren)

        var stats: [String: NodeStats] = [:]
        var totalSize: Int64 = 0
        var filesScanned = 0

        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if configuration.skipHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }

        let sizeKeys: [URLResourceKey] = [
            .totalFileAllocatedSizeKey,
            .fileSizeKey,
            .isRegularFileKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: normalizedRoot,
            includingPropertiesForKeys: sizeKeys,
            options: options
        ) else {
            return BuildResult(statsByPath: [:], totalSize: 0, filesScanned: 0)
        }

        let partialInterval = configuration.partialUpdateInterval
        let tracksPartial = onPartial != nil

        func snapshot() -> BuildResult {
            BuildResult(statsByPath: stats, totalSize: totalSize, filesScanned: filesScanned)
        }

        if tracksPartial {
            onPartial?(snapshot())
        }

        for case let fileURL as URL in enumerator {
            if let shouldCancel, shouldCancel() { break }

            autoreleasepool {
                guard let values = try? fileURL.resourceValues(forKeys: Set(sizeKeys)) else { return }
                guard values.isRegularFile == true else { return }

                let allocated = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                guard allocated > 0 else { return }

                totalSize += allocated
                filesScanned += 1

                let filePath = fileURL.standardizedFileURL.path
                let resolvedPath = PathUtils.resolved(fileURL).path
                accumulate(
                    filePath: filePath,
                    resolvedPath: resolvedPath,
                    size: allocated,
                    matcher: matcher,
                    maxDepth: maxDepth,
                    stats: &stats
                )

                if tracksPartial, filesScanned % partialInterval == 0 {
                    onPartial?(snapshot())
                }
            }
        }

        let result = snapshot()
        if tracksPartial {
            onPartial?(result)
        }
        return result
    }

    public static func childMap(
        from result: BuildResult,
        root: URL,
        listedEntries: [DiskItem],
        maxChildrenPerNode: Int
    ) -> [String: [DiskItem]] {
        let rootPath = PathUtils.resolved(root).path
        var childPathsByParent: [String: Set<String>] = [:]

        for (path, nodeStats) in result.statsByPath where nodeStats.size > 0 {
            guard let parent = parentPath(of: path, rootPath: rootPath) else { continue }
            childPathsByParent[parent, default: []].insert(path)
        }

        for item in listedEntries where !item.isVirtual {
            let path = PathUtils.resolved(item.url).path
            if item.isDirectory || item.size > 0 {
                childPathsByParent[rootPath, default: []].insert(path)
            }
        }

        var map: [String: [DiskItem]] = [:]

        for (parent, paths) in childPathsByParent {
            let items = paths
                .map { path in
                    diskItem(for: path, stats: result.statsByPath[path], listedEntries: listedEntries)
                }
                .filter { $0.size > 0 || $0.isDirectory }
                .sorted { $0.size > $1.size }
                .prefix(maxChildrenPerNode)

            if !items.isEmpty {
                map[parent] = Array(items)
            }
        }

        return map
    }

    private static func accumulate(
        filePath: String,
        resolvedPath: String,
        size: Int64,
        matcher: ChildPathMatcher,
        maxDepth: Int,
        stats: inout [String: NodeStats]
    ) {
        guard let childKey = matcher.immediateChildKey(for: filePath) else { return }

        let components = matcher.relativeComponentsAfterChild(
            resolvedPath: resolvedPath,
            childKey: childKey
        )

        if components.isEmpty {
            if resolvedPath == childKey || filePath == childKey {
                return
            }
            stats[childKey, default: NodeStats()].size += size
            stats[childKey, default: NodeStats()].directFileCount += 1
            stats[childKey, default: NodeStats()].isDirectory = false
            return
        }

        stats[childKey, default: NodeStats()].size += size

        let directoryParts = components.dropLast()
        var currentPath = childKey

        for (index, part) in directoryParts.enumerated() {
            guard index < maxDepth else { break }
            currentPath += "/\(part)"
            stats[currentPath, default: NodeStats()].size += size
        }

        let parentPath = directoryParts.isEmpty
            ? childKey
            : childKey + "/" + directoryParts.joined(separator: "/")
        stats[parentPath, default: NodeStats()].directFileCount += 1
    }

    private static func parentPath(of path: String, rootPath: String) -> String? {
        if path == rootPath { return nil }
        let parent = (path as NSString).deletingLastPathComponent
        if parent.isEmpty || parent == "/" { return rootPath }
        if path.hasPrefix(rootPath + "/") || parent.hasPrefix(rootPath) {
            return parent
        }
        return parent
    }

    private static func diskItem(
        for path: String,
        stats: NodeStats?,
        listedEntries: [DiskItem]
    ) -> DiskItem {
        if let listed = listedEntries.first(where: { PathUtils.resolved($0.url).path == path }) {
            var item = listed
            if let stats {
                item.size = stats.size
                item.isScanning = false
            }
            return item
        }

        let nodeStats = stats ?? NodeStats()
        return DiskItem(
            url: URL(fileURLWithPath: path, isDirectory: nodeStats.isDirectory),
            size: nodeStats.size,
            isDirectory: nodeStats.isDirectory,
            isScanning: false
        )
    }
}
