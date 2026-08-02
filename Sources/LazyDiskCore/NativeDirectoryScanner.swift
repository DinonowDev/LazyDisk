import Foundation
import LazyDiskFS

/// macOS-native directory sizing via getattrlistbulk (LazyDiskFS).
public enum NativeDirectoryScanner {
    public static var isAvailable: Bool { true }

    private final class ScanBridge: @unchecked Sendable {
        let childEntries: ContiguousArray<ldfs_child_entry>
        let childPaths: [String]
        private let allocations: [UnsafeMutablePointer<CChar>]

        init(matcher: ChildPathMatcher) {
            var paths: [String] = []
            var pointerArrays: [ContiguousArray<UnsafePointer<CChar>?>] = []
            var canonicalPointers: [UnsafePointer<CChar>] = []
            var allocs: [UnsafeMutablePointer<CChar>] = []

            for entry in matcher.entries {
                var ptrs = ContiguousArray<UnsafePointer<CChar>?>()
                for prefix in entry.prefixes {
                    let copy = strdup(prefix)!
                    allocs.append(copy)
                    ptrs.append(copy)
                }
                pointerArrays.append(ptrs)

                let canonical = strdup(entry.canonical)!
                allocs.append(canonical)
                canonicalPointers.append(canonical)
                paths.append(entry.canonical)
            }

            var builtEntries: [ldfs_child_entry] = []
            for index in 0..<paths.count {
                let prefixArray = pointerArrays[index]
                let canonical = canonicalPointers[index]
                let built = prefixArray.withUnsafeBufferPointer { prefixBuffer -> ldfs_child_entry in
                    ldfs_child_entry(
                        prefixes: UnsafeMutablePointer(mutating: prefixBuffer.baseAddress),
                        prefix_count: prefixBuffer.count,
                        canonical_key: canonical
                    )
                }
                builtEntries.append(built)
            }

            childEntries = ContiguousArray(builtEntries)
            childPaths = paths
            allocations = allocs
        }

        deinit {
            for pointer in allocations {
                free(pointer)
            }
        }
    }

    private final class PartialContext: @unchecked Sendable {
        let bridge: ScanBridge
        var onPartial: (@Sendable (DirectorySizeWalker.WalkResult) -> Void)?

        init(bridge: ScanBridge, onPartial: (@Sendable (DirectorySizeWalker.WalkResult) -> Void)?) {
            self.bridge = bridge
            self.onPartial = onPartial
        }

        func snapshot(sizes: [Int64], total: Int64, files: Int64) -> DirectorySizeWalker.WalkResult {
            var map: [String: Int64] = [:]
            for (index, path) in bridge.childPaths.enumerated() where index < sizes.count && sizes[index] > 0 {
                map[path] = sizes[index]
            }
            return DirectorySizeWalker.WalkResult(
                childSizesByPath: map,
                totalSize: total,
                filesScanned: Int(files)
            )
        }
    }

    private final class ChartPartialContext: @unchecked Sendable {
        var onPartial: (@Sendable (ChartTreeBuilder.BuildResult) -> Void)?

        func snapshot(
            statsPtr: UnsafePointer<ldfs_path_stat>?,
            statsCount: Int,
            total: Int64,
            files: Int64
        ) -> ChartTreeBuilder.BuildResult {
            var statsByPath: [String: ChartTreeBuilder.NodeStats] = [:]
            if let statsPtr, statsCount > 0 {
                for index in 0..<statsCount {
                    let entry = statsPtr[index]
                    guard let pathCString = entry.path else { continue }
                    let path = String(cString: pathCString)
                    statsByPath[path] = ChartTreeBuilder.NodeStats(
                        size: entry.size,
                        directFileCount: Int(entry.file_count),
                        isDirectory: entry.is_directory != 0
                    )
                }
            }
            return ChartTreeBuilder.BuildResult(
                statsByPath: statsByPath,
                totalSize: total,
                filesScanned: Int(files),
                deferredByParent: [:]
            )
        }
    }

    private final class CancelBridge: @unchecked Sendable {
        let shouldCancel: (@Sendable () -> Bool)?

        init(shouldCancel: (@Sendable () -> Bool)?) {
            self.shouldCancel = shouldCancel
        }
    }

    private static func resolvedParallelism(_ parallelism: Int?) -> Int {
        parallelism ?? ProcessInfo.processInfo.activeProcessorCount
    }

    static func immediateChildSizes(
        at root: URL,
        listedChildren: [URL],
        matcher: ChildPathMatcher,
        skipHiddenFiles: Bool,
        parallelism: Int? = nil,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (DirectorySizeWalker.WalkResult) -> Void)? = nil
    ) -> DirectorySizeWalker.WalkResult? {
        let rootPath = PathUtils.resolved(root).path
        guard !rootPath.isEmpty else { return nil }

        let bridge = ScanBridge(matcher: matcher)
        let childCount = bridge.childEntries.count
        guard childCount > 0 else { return nil }

        let runtime = NativeScanRuntime.settings(parallelism: resolvedParallelism(parallelism))
        var childSizes = [Int64](repeating: 0, count: childCount)
        var totalSize: Int64 = 0
        var filesScanned: Int64 = 0

        let cancelBridge = CancelBridge(shouldCancel: shouldCancel)
        let cancelPtr = Unmanaged.passUnretained(cancelBridge).toOpaque()

        let cancelFn: ldfs_cancel_fn = { ctx in
            guard let ctx else { return false }
            let bridge = Unmanaged<CancelBridge>.fromOpaque(ctx).takeUnretainedValue()
            return bridge.shouldCancel?() ?? false
        }

        let partialContext = PartialContext(bridge: bridge, onPartial: onPartial)
        let partialPtr = Unmanaged.passUnretained(partialContext).toOpaque()

        let progressFn: ldfs_progress_fn = { ctx, sizesPtr, count, total, files in
            guard let ctx, let sizesPtr else { return }
            let context = Unmanaged<PartialContext>.fromOpaque(ctx).takeUnretainedValue()
            let sizes = Array(UnsafeBufferPointer(start: sizesPtr, count: count))
            let result = context.snapshot(sizes: sizes, total: total, files: files)
            context.onPartial?(result)
        }

        let status = rootPath.withCString { rootCString in
            var options = ldfs_scan_options(
                root_path: rootCString,
                children: bridge.childEntries.withUnsafeBufferPointer { $0.baseAddress },
                child_count: childCount,
                skip_hidden: skipHiddenFiles,
                worker_count: Int32(runtime.workerCount),
                buffer_size: runtime.bufferSize,
                turbo: runtime.turbo,
                should_cancel: cancelFn,
                cancel_ctx: cancelPtr
            )
            return ldfs_scan_immediate_children(
                &options,
                &childSizes,
                &totalSize,
                &filesScanned,
                onPartial == nil ? nil : progressFn,
                partialPtr
            )
        }

        guard status == 0 else { return nil }

        var childSizesByPath: [String: Int64] = [:]
        for (index, path) in bridge.childPaths.enumerated()
            where index < childSizes.count && childSizes[index] > 0 {
            childSizesByPath[path] = childSizes[index]
        }

        return DirectorySizeWalker.WalkResult(
            childSizesByPath: childSizesByPath,
            totalSize: totalSize,
            filesScanned: Int(filesScanned)
        )
    }

    static func buildChartTree(
        at root: URL,
        listedEntries: [DiskItem],
        maxDepth: Int,
        skipHiddenFiles: Bool,
        parallelism: Int? = nil,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (ChartTreeBuilder.BuildResult) -> Void)? = nil
    ) -> ChartTreeBuilder.BuildResult? {
        let normalizedRoot = PathUtils.resolved(root)
        let rootPath = normalizedRoot.path
        guard !rootPath.isEmpty else { return nil }

        let directoryChildren = listedEntries
            .filter { $0.isDirectory && !$0.isVirtual }
            .map(\.url)
        let matcher = ChildPathMatcher(root: normalizedRoot, children: directoryChildren)
        let bridge = ScanBridge(matcher: matcher)
        let childCount = bridge.childEntries.count

        let runtime = NativeScanRuntime.settings(parallelism: resolvedParallelism(parallelism))
        var childSizes = childCount > 0 ? [Int64](repeating: 0, count: childCount) : []
        var statsPtr: UnsafeMutablePointer<ldfs_path_stat>?
        var statsCount: Int = 0
        var totalSize: Int64 = 0
        var filesScanned: Int64 = 0

        let cancelBridge = CancelBridge(shouldCancel: shouldCancel)
        let cancelPtr = Unmanaged.passUnretained(cancelBridge).toOpaque()

        let cancelFn: ldfs_cancel_fn = { ctx in
            guard let ctx else { return false }
            let bridge = Unmanaged<CancelBridge>.fromOpaque(ctx).takeUnretainedValue()
            return bridge.shouldCancel?() ?? false
        }

        let partialContext = ChartPartialContext()
        partialContext.onPartial = onPartial
        let partialPtr = Unmanaged.passUnretained(partialContext).toOpaque()

        let status = rootPath.withCString { rootCString in
            var options = ldfs_tree_options(
                root_path: rootCString,
                max_depth: maxDepth,
                skip_hidden: skipHiddenFiles,
                worker_count: Int32(runtime.workerCount),
                buffer_size: runtime.bufferSize,
                turbo: runtime.turbo,
                children: bridge.childEntries.withUnsafeBufferPointer { $0.baseAddress },
                child_count: childCount,
                should_cancel: cancelFn,
                cancel_ctx: cancelPtr
            )

            let treeProgress: ldfs_tree_progress_fn? = onPartial == nil ? nil : { ctx, files, total, stats, count in
                guard let ctx else { return }
                let context = Unmanaged<ChartPartialContext>.fromOpaque(ctx).takeUnretainedValue()
                let result = context.snapshot(
                    statsPtr: stats,
                    statsCount: Int(count),
                    total: total,
                    files: files
                )
                context.onPartial?(result)
            }

            if childCount > 0 {
                return ldfs_scan_tree(
                    &options,
                    &childSizes,
                    &statsPtr,
                    &statsCount,
                    &totalSize,
                    &filesScanned,
                    treeProgress,
                    partialPtr
                )
            }
            return ldfs_scan_tree(
                &options,
                nil,
                &statsPtr,
                &statsCount,
                &totalSize,
                &filesScanned,
                treeProgress,
                partialPtr
            )
        }

        guard status == 0 else {
            if let statsPtr, statsCount > 0 {
                ldfs_free_path_stats(statsPtr, statsCount)
            }
            return nil
        }

        var statsByPath: [String: ChartTreeBuilder.NodeStats] = [:]
        if let statsPtr, statsCount > 0 {
            for index in 0..<statsCount {
                let entry = statsPtr[index]
                guard let pathCString = entry.path else { continue }
                let path = String(cString: pathCString)
                statsByPath[path] = ChartTreeBuilder.NodeStats(
                    size: entry.size,
                    directFileCount: Int(entry.file_count),
                    isDirectory: entry.is_directory != 0
                )
            }
            ldfs_free_path_stats(statsPtr, statsCount)
        }

        for entry in listedEntries where !entry.isVirtual {
            let path = PathUtils.resolved(entry.url).path
            if entry.isDirectory {
                let existing = statsByPath[path] ?? ChartTreeBuilder.NodeStats(isDirectory: true)
                if existing.size == 0 && entry.size > 0 {
                    statsByPath[path] = ChartTreeBuilder.NodeStats(
                        size: entry.size,
                        directFileCount: existing.directFileCount,
                        isDirectory: true
                    )
                } else if statsByPath[path] == nil {
                    statsByPath[path] = existing
                }
            } else if entry.size > 0 {
                statsByPath[path] = ChartTreeBuilder.NodeStats(
                    size: entry.size,
                    directFileCount: 1,
                    isDirectory: false
                )
            }
        }

        return ChartTreeBuilder.BuildResult(
            statsByPath: statsByPath,
            totalSize: totalSize,
            filesScanned: Int(filesScanned),
            deferredByParent: [:]
        )
    }

    public static func fusedVolumeScan(
        at root: URL,
        listedEntries: [DiskItem],
        maxDepth: Int,
        skipHiddenFiles: Bool,
        parallelism: Int? = nil,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (ChartTreeBuilder.BuildResult) -> Void)? = nil
    ) -> FusedNativeScanResult? {
        guard let chartResult = buildChartTree(
            at: root,
            listedEntries: listedEntries,
            maxDepth: maxDepth,
            skipHiddenFiles: skipHiddenFiles,
            parallelism: parallelism,
            shouldCancel: shouldCancel,
            onPartial: onPartial
        ) else {
            return nil
        }

        var childSizesByPath: [String: Int64] = [:]
        for entry in listedEntries where !entry.isVirtual {
            let path = PathUtils.resolved(entry.url).path
            if let nodeStats = chartResult.statsByPath[path], nodeStats.size > 0 {
                childSizesByPath[path] = nodeStats.size
            } else if entry.size > 0 {
                childSizesByPath[path] = entry.size
            }
        }

        let sizingWalk = DirectorySizeWalker.WalkResult(
            childSizesByPath: childSizesByPath,
            totalSize: chartResult.totalSize,
            filesScanned: chartResult.filesScanned
        )
        return FusedNativeScanResult(sizingWalk: sizingWalk, chartResult: chartResult)
    }
}
