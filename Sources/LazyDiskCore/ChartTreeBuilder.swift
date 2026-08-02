import Foundation

private final class ChartBuildAccumulator: @unchecked Sendable {
    var stats: [String: ChartTreeBuilder.NodeStats] = [:]
    var deferredByParent: [String: [URL]] = [:]
    var totalSize: Int64 = 0
    var filesScanned = 0

    func snapshot() -> ChartTreeBuilder.BuildResult {
        ChartTreeBuilder.BuildResult(
            statsByPath: stats,
            totalSize: totalSize,
            filesScanned: filesScanned,
            deferredByParent: deferredByParent
        )
    }
}

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
        public let deferredByParent: [String: [URL]]

        public init(
            statsByPath: [String: NodeStats],
            totalSize: Int64,
            filesScanned: Int,
            deferredByParent: [String: [URL]] = [:]
        ) {
            self.statsByPath = statsByPath
            self.totalSize = totalSize
            self.filesScanned = filesScanned
            self.deferredByParent = deferredByParent
        }
    }

    public struct BuildOptions: Sendable {
        public var maxDepth: Int
        public var skipHiddenFiles: Bool
        public var partialUpdateInterval: Int
        public var expandedParents: Set<String>
        public var fileSizeThreshold: Int64?
        public var parallelism: Int?

        public init(
            maxDepth: Int = defaultMaxDepth,
            skipHiddenFiles: Bool = true,
            partialUpdateInterval: Int = 40,
            expandedParents: Set<String> = [],
            fileSizeThreshold: Int64? = nil,
            parallelism: Int? = nil
        ) {
            self.maxDepth = max(0, maxDepth)
            self.skipHiddenFiles = skipHiddenFiles
            self.partialUpdateInterval = max(32, partialUpdateInterval)
            self.expandedParents = expandedParents
            self.fileSizeThreshold = fileSizeThreshold
            self.parallelism = parallelism
        }

        public static let chartPreview = BuildOptions()
    }

    public static let defaultMaxDepth = 3

    private static let sizeKeys: [URLResourceKey] = [
        .totalFileAllocatedSizeKey,
        .fileSizeKey,
        .isRegularFileKey
    ]

    public static func build(
        at root: URL,
        listedChildren: [URL],
        maxDepth: Int = defaultMaxDepth,
        configuration: DirectorySizeWalker.Configuration = .chartPreview,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (BuildResult) -> Void)? = nil
    ) -> BuildResult {
        build(
            at: root,
            listedEntries: listedChildren.map {
                DiskItem(url: $0, isDirectory: true, isScanning: false)
            },
            options: BuildOptions(
                maxDepth: maxDepth,
                skipHiddenFiles: configuration.skipHiddenFiles,
                partialUpdateInterval: configuration.partialUpdateInterval,
                expandedParents: Set([PathUtils.resolved(root).path])
            ),
            shouldCancel: shouldCancel,
            onPartial: onPartial
        )
    }

    public static func build(
        at root: URL,
        listedEntries: [DiskItem],
        options: BuildOptions = .chartPreview,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (BuildResult) -> Void)? = nil
    ) -> BuildResult {
        if options.fileSizeThreshold == 0 {
            if let native = buildWithNativeScanner(
                at: root,
                listedEntries: listedEntries,
                options: options,
                shouldCancel: shouldCancel,
                onPartial: onPartial
            ) {
                return native
            }
        }

        let normalizedRoot = PathUtils.resolved(root)
        let rootPath = normalizedRoot.path
        let entries = listedEntries.filter { !$0.isVirtual && ($0.size > 0 || $0.isDirectory) }
        let parentTotal = entries.reduce(Int64(0)) { $0 + $1.size }
        let threshold = options.fileSizeThreshold
            ?? ChartLazyScanPolicy.deepScanThreshold(parentTotalSize: max(parentTotal, 1))
        let isRootExpanded = options.expandedParents.contains(rootPath)
            || options.expandedParents.contains(root.path)
        let accumulator = ChartBuildAccumulator()
        let partialInterval = options.partialUpdateInterval
        let tracksPartial = onPartial != nil

        if tracksPartial {
            onPartial?(accumulator.snapshot())
        }

        var largeChildren: [DiskItem] = []
        var smallChildren: [DiskItem] = []

        for entry in entries {
            if isRootExpanded || ChartLazyScanPolicy.shouldDeepScanChild(size: entry.size, threshold: threshold) {
                largeChildren.append(entry)
            } else {
                smallChildren.append(entry)
            }
        }

        recordSmallChildren(
            smallChildren,
            rootPath: rootPath,
            accumulator: accumulator
        )

        for child in largeChildren {
            if let shouldCancel, shouldCancel() { break }
            scanLargeChild(
                child,
                threshold: threshold,
                options: options,
                partialInterval: partialInterval,
                tracksPartial: tracksPartial,
                accumulator: accumulator,
                shouldCancel: shouldCancel,
                onPartial: onPartial
            )
        }

        let result = accumulator.snapshot()
        if tracksPartial {
            onPartial?(result)
        }
        return result
    }

    public static func childMap(
        from result: BuildResult,
        root: URL,
        listedEntries: [DiskItem],
        maxChildrenPerNode: Int,
        otherItemName: String = "Other"
    ) -> [String: [DiskItem]] {
        let rootPath = PathUtils.resolved(root).path
        let deferredPathsByParent = deferredPathSets(from: result.deferredByParent)
        var childPathsByParent: [String: Set<String>] = [:]

        for (path, nodeStats) in result.statsByPath where nodeStats.size > 0 {
            guard !ChartSubtreeOther.isVirtualOther(path) else { continue }
            guard let parent = parentPath(of: path, rootPath: rootPath) else { continue }
            childPathsByParent[parent, default: []].insert(path)
        }

        for item in listedEntries where !item.isVirtual {
            let path = PathUtils.resolved(item.url).path
            if item.isDirectory || item.size > 0 {
                childPathsByParent[rootPath, default: []].insert(path)
            }
        }

        for (parentPath, deferredPaths) in deferredPathsByParent {
            childPathsByParent[parentPath] = childPathsByParent[parentPath, default: []]
                .filter { !deferredPaths.contains($0) }
            let otherPath = ChartSubtreeOther.virtualPath(under: parentPath)
            if result.statsByPath[otherPath]?.size ?? 0 > 0 {
                childPathsByParent[parentPath, default: []].insert(otherPath)
            }
        }

        for (path, nodeStats) in result.statsByPath where ChartSubtreeOther.isVirtualOther(path) && nodeStats.size > 0 {
            if let parent = ChartSubtreeOther.parentPath(ofVirtualOther: path) {
                childPathsByParent[parent, default: []].insert(path)
            }
        }

        var map: [String: [DiskItem]] = [:]

        for (parent, paths) in childPathsByParent {
            let deferredPaths = deferredPathsByParent[parent] ?? []
            let items = paths
                .map { path in
                    diskItem(
                        for: path,
                        stats: result.statsByPath[path],
                        listedEntries: listedEntries,
                        deferredCount: deferredPaths.count,
                        otherItemName: otherItemName
                    )
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

    // MARK: - Lazy scan

    private static func recordSmallChildren(
        _ smallChildren: [DiskItem],
        rootPath: String,
        accumulator: ChartBuildAccumulator
    ) {
        guard !smallChildren.isEmpty else { return }

        var otherSize: Int64 = 0
        for child in smallChildren {
            let childPath = PathUtils.resolved(child.url).path
            accumulator.stats[childPath] = NodeStats(
                size: child.size,
                directFileCount: 0,
                isDirectory: child.isDirectory
            )
            otherSize += child.size
            accumulator.totalSize += child.size
            accumulator.deferredByParent[rootPath, default: []].append(child.url)
        }

        let otherPath = ChartSubtreeOther.virtualPath(under: rootPath)
        accumulator.stats[otherPath] = NodeStats(
            size: otherSize,
            directFileCount: smallChildren.count,
            isDirectory: true
        )
    }

    private static func scanLargeChild(
        _ child: DiskItem,
        threshold: Int64,
        options: BuildOptions,
        partialInterval: Int,
        tracksPartial: Bool,
        accumulator: ChartBuildAccumulator,
        shouldCancel: (@Sendable () -> Bool)?,
        onPartial: (@Sendable (BuildResult) -> Void)?
    ) {
        let childURL = PathUtils.resolved(child.url)
        let childListed = discoverChildren(at: childURL, skipHiddenFiles: options.skipHiddenFiles)
        let matcher = ChildPathMatcher(root: childURL, children: childListed)

        var enumerationOptions: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if options.skipHiddenFiles {
            enumerationOptions.insert(.skipsHiddenFiles)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: childURL,
            includingPropertiesForKeys: sizeKeys,
            options: enumerationOptions
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            if let shouldCancel, shouldCancel() { break }

            autoreleasepool {
                guard let values = try? fileURL.resourceValues(forKeys: Set(sizeKeys)) else { return }
                guard values.isRegularFile == true else { return }

                let allocated = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                guard allocated > 0 else { return }

                accumulator.totalSize += allocated
                accumulator.filesScanned += 1

                accumulate(
                    filePath: fileURL.standardizedFileURL.path,
                    resolvedPath: PathUtils.resolved(fileURL).path,
                    size: allocated,
                    matcher: matcher,
                    maxDepth: options.maxDepth,
                    fileThreshold: threshold,
                    expandedParents: options.expandedParents,
                    accumulator: accumulator
                )

                if tracksPartial, accumulator.filesScanned % partialInterval == 0 {
                    onPartial?(accumulator.snapshot())
                }
            }
        }
    }

    private static func accumulate(
        filePath: String,
        resolvedPath: String,
        size: Int64,
        matcher: ChildPathMatcher,
        maxDepth: Int,
        fileThreshold: Int64,
        expandedParents: Set<String>,
        accumulator: ChartBuildAccumulator
    ) {
        guard let childKey = matcher.immediateChildKey(for: filePath) else { return }

        let components = matcher.relativeComponentsAfterChild(
            resolvedPath: resolvedPath,
            childKey: childKey
        )

        if components.isEmpty {
            if resolvedPath == childKey || filePath == childKey { return }
            accumulator.stats[childKey, default: NodeStats()].size += size
            accumulator.stats[childKey, default: NodeStats()].directFileCount += 1
            accumulator.stats[childKey, default: NodeStats()].isDirectory = false
            return
        }

        let directoryParts = components.dropLast()
        let parentPath = directoryParts.isEmpty
            ? childKey
            : childKey + "/" + directoryParts.joined(separator: "/")

        if size < fileThreshold, !expandedParents.contains(parentPath) {
            accumulator.stats[childKey, default: NodeStats()].size += size
            accumulator.stats[parentPath, default: NodeStats()].size += size
            let otherPath = ChartSubtreeOther.virtualPath(under: parentPath)
            accumulator.stats[otherPath, default: NodeStats(isDirectory: true)].size += size
            accumulator.stats[otherPath, default: NodeStats(isDirectory: true)].directFileCount += 1
            accumulator.deferredByParent[parentPath, default: []].append(URL(fileURLWithPath: resolvedPath))
            return
        }

        accumulator.stats[childKey, default: NodeStats()].size += size

        var currentPath = childKey
        for (index, part) in directoryParts.enumerated() {
            guard index < maxDepth else { break }
            currentPath += "/\(part)"
            accumulator.stats[currentPath, default: NodeStats()].size += size
        }

        accumulator.stats[parentPath, default: NodeStats()].directFileCount += 1
    }

    // MARK: - Helpers

    private static func deferredPathSets(from deferred: [String: [URL]]) -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for (parent, urls) in deferred {
            result[parent] = Set(urls.map { PathUtils.resolved($0).path })
        }
        return result
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
        listedEntries: [DiskItem],
        deferredCount: Int,
        otherItemName: String
    ) -> DiskItem {
        if ChartSubtreeOther.isVirtualOther(path),
           let parentPath = ChartSubtreeOther.parentPath(ofVirtualOther: path) {
            let nodeStats = stats ?? NodeStats()
            let name = deferredCount > 1
                ? "\(otherItemName) (\(deferredCount))"
                : otherItemName
            return DiskItem(
                id: ChartSubtreeOther.stableID(parentPath: parentPath),
                url: URL(fileURLWithPath: path, isDirectory: true),
                name: name,
                size: nodeStats.size,
                isDirectory: true,
                isVirtual: true
            )
        }

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

    private static func discoverChildren(at root: URL, skipHiddenFiles: Bool) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey]
        var listOptions: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if skipHiddenFiles {
            listOptions.insert(.skipsHiddenFiles)
        }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: keys,
            options: listOptions
        ) else {
            return []
        }

        return contents.filter { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            return values?.isDirectory == true
        }
    }
}
