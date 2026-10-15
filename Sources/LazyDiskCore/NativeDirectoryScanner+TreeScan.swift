import Foundation
import LazyDiskFS

extension NativeDirectoryScanner {
    struct TreeScanNativeResult {
        let walk: DirectorySizeWalker.WalkResult
        let pathStats: [String: ChartTreeBuilder.NodeStats]
    }

    /// Single getattrlistbulk walk: root child sizes + path stats up to `indexMaxDepth`.
    static func scanVolumeTree(
        at root: URL,
        listedChildren: [URL],
        splashListedEntries: [DiskItem],
        matcher: ChildPathMatcher,
        indexMaxDepth: Int,
        skipHiddenFiles: Bool,
        usePhysicalSize: Bool = true,
        firmLinks: Bool = true,
        parallelism: Int? = nil,
        nativeBufferSize: Int? = nil,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (ChartTreeBuilder.BuildResult) -> Void)? = nil,
        onSplashReady: (@Sendable (ChartTreeBuilder.BuildResult) -> Void)? = nil
    ) -> TreeScanNativeResult? {
        let rootPath = PathUtils.resolved(root).path
        guard !rootPath.isEmpty, indexMaxDepth > 0 else { return nil }

        let bridge = ScanBridge(matcher: matcher)
        let childCount = bridge.childEntries.count

        let runtime = NativeScanRuntime.settings(
            parallelism: resolvedParallelism(parallelism),
            bufferSizeOverride: nativeBufferSize
        )
        var childSizes = [Int64](repeating: 0, count: max(childCount, 0))
        var totalSize: Int64 = 0
        var filesScanned: Int64 = 0
        var statsPtr: UnsafeMutablePointer<ldfs_path_stat>?
        var statsCount: size_t = 0

        let cancelBridge = CancelBridge(shouldCancel: shouldCancel)
        let cancelPtr = Unmanaged.passUnretained(cancelBridge).toOpaque()

        let cancelFn: ldfs_cancel_fn = { ctx in
            guard let ctx else { return false }
            let bridge = Unmanaged<CancelBridge>.fromOpaque(ctx).takeUnretainedValue()
            return bridge.shouldCancel?() ?? false
        }

        let restrictedCollector = RestrictedPathCollector()
        let restrictedPtr = Unmanaged.passUnretained(restrictedCollector).toOpaque()
        let restrictedFn: ldfs_restricted_fn = { ctx, path, code in
            guard let ctx, let path else { return }
            let collector = Unmanaged<RestrictedPathCollector>.fromOpaque(ctx).takeUnretainedValue()
            collector.record(path: String(cString: path), code: code)
        }

        let chartPartial = ChartPartialContext()
        chartPartial.onPartial = onPartial
        chartPartial.onSplashReady = onSplashReady
        chartPartial.splashListedEntries = splashListedEntries
        chartPartial.splashScanRoot = root
        chartPartial.splashChartMaxDepth = max(1, indexMaxDepth - 1)
        let chartPartialPtr = Unmanaged.passUnretained(chartPartial).toOpaque()

        let treeProgressFn: ldfs_tree_progress_fn = { ctx, files, total, stats, count in
            guard let ctx else { return }
            Unmanaged<ChartPartialContext>.fromOpaque(ctx)
                .takeUnretainedValue()
                .publishPartial(statsPtr: stats, statsCount: Int(count), total: total, files: files)
        }

        var metrics = ldfs_scan_metrics()
        let depth = size_t(indexMaxDepth)
        let status = withExtendedLifetime((cancelBridge, chartPartial, restrictedCollector, bridge)) {
            bridge.childEntries.withUnsafeBufferPointer { childEntriesBuffer in
                withUnsafeMutablePointer(to: &metrics) { metricsPtr in
                    rootPath.withCString { rootCString in
                        var options = ldfs_tree_options(
                            root_path: rootCString,
                            max_depth: depth,
                            skip_hidden: skipHiddenFiles,
                            firm_links: firmLinks,
                            use_physical_size: usePhysicalSize,
                            worker_count: Int32(runtime.workerCount),
                            buffer_size: runtime.bufferSize,
                            turbo: runtime.turbo,
                            children: childEntriesBuffer.baseAddress,
                            child_count: childCount,
                            should_cancel: cancelFn,
                            cancel_ctx: cancelPtr,
                            on_restricted_path: restrictedFn,
                            restricted_ctx: restrictedPtr,
                            metrics_out: metricsPtr
                        )
                        return childSizes.withUnsafeMutableBufferPointer { sizesBuffer in
                            withUnsafeMutablePointer(to: &statsPtr) { statsOut in
                                withUnsafeMutablePointer(to: &statsCount) { countOut in
                                    ldfs_scan_tree(
                                        &options,
                                        childCount > 0 ? sizesBuffer.baseAddress : nil,
                                        statsOut,
                                        countOut,
                                        &totalSize,
                                        &filesScanned,
                                        (onPartial == nil && onSplashReady == nil) ? nil : treeProgressFn,
                                        chartPartialPtr
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        defer {
            if let statsPtr, statsCount > 0 {
                ldfs_free_path_stats(statsPtr, statsCount)
            }
        }

        guard status == 0 else { return nil }

        let exported = statsPtr.map {
            ChartTreeBuilder.nodeStatsMap(from: $0, count: Int(statsCount))
        } ?? [:]
        let pathStats = chartPartial.merged(with: exported)
        chartPartial.finalizeSplash(
            pathStats: pathStats,
            total: totalSize,
            files: Int(filesScanned)
        )
        let restrictedEvents = restrictedCollector.snapshot()

        var childSizesByPath: [String: Int64] = [:]
        for (index, path) in bridge.childPaths.enumerated()
            where index < childSizes.count && childSizes[index] > 0 {
            childSizesByPath[path] = childSizes[index]
        }

        let walk = DirectorySizeWalker.WalkResult(
            childSizesByPath: childSizesByPath,
            totalSize: totalSize,
            filesScanned: Int(filesScanned),
            scanMetrics: NativeScanMetrics(
                cloneBytesMerged: metrics.clone_bytes_merged,
                cloneGroupsMerged: metrics.clone_groups_merged,
                hardlinkFilesSkipped: metrics.hardlink_files_skipped
            ),
            restrictedScanEvents: restrictedEvents
        )

        return TreeScanNativeResult(walk: walk, pathStats: pathStats)
    }
}
