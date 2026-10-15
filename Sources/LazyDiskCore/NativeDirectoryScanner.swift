import Foundation
import LazyDiskFS

/// macOS-native directory sizing via getattrlistbulk (LazyDiskFS).
public enum NativeDirectoryScanner {
    public static var isAvailable: Bool { true }

    final class ScanBridge: @unchecked Sendable {
        let childEntries: ContiguousArray<ldfs_child_entry>
        let childPaths: [String]
        private let allocations: [UnsafeMutablePointer<CChar>]
        /// Stable `const char **` blocks referenced by `ldfs_child_entry.prefixes`.
        private let prefixPointerBlocks: [UnsafeMutablePointer<UnsafePointer<CChar>?>]

        init(matcher: ChildPathMatcher) {
            var paths: [String] = []
            var canonicalPointers: [UnsafePointer<CChar>] = []
            var allocs: [UnsafeMutablePointer<CChar>] = []
            var prefixBlocks: [UnsafeMutablePointer<UnsafePointer<CChar>?>] = []
            var builtEntries: [ldfs_child_entry] = []

            for entry in matcher.entries {
                let canonical = strdup(entry.canonical)!
                allocs.append(canonical)
                canonicalPointers.append(canonical)
                paths.append(entry.canonical)

                let prefixCount = entry.prefixes.count
                if prefixCount == 0 {
                    builtEntries.append(
                        ldfs_child_entry(
                            prefixes: nil,
                            prefix_count: 0,
                            canonical_key: canonical
                        )
                    )
                    continue
                }

                let block = UnsafeMutablePointer<UnsafePointer<CChar>?>.allocate(capacity: prefixCount)
                prefixBlocks.append(block)
                for index in 0..<prefixCount {
                    let copy = strdup(entry.prefixes[index])!
                    allocs.append(copy)
                    block[index] = UnsafePointer(copy)
                }
                builtEntries.append(
                    ldfs_child_entry(
                        prefixes: UnsafeMutablePointer(mutating: block),
                        prefix_count: prefixCount,
                        canonical_key: canonical
                    )
                )
            }

            childEntries = ContiguousArray(builtEntries)
            childPaths = paths
            allocations = allocs
            prefixPointerBlocks = prefixBlocks
        }

        deinit {
            for block in prefixPointerBlocks {
                block.deallocate()
            }
            for pointer in allocations {
                free(pointer)
            }
        }
    }

    final class PartialContext: @unchecked Sendable {
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

    final class ChartPartialContext: @unchecked Sendable {
        var onPartial: (@Sendable (ChartTreeBuilder.BuildResult) -> Void)?
        var onSplashReady: (@Sendable (ChartTreeBuilder.BuildResult) -> Void)?
        var splashListedEntries: [DiskItem] = []
        var splashScanRoot: URL?
        var splashChartMaxDepth: Int = 0

        private let lock = NSLock()
        private var accumulated: [String: ChartTreeBuilder.NodeStats] = [:]
        private var didSignalSplash = false

        func ingest(statsPtr: UnsafePointer<ldfs_path_stat>?, statsCount: Int) {
            guard let statsPtr, statsCount > 0 else { return }
            lock.lock()
            for index in 0..<statsCount {
                let entry = statsPtr[index]
                guard let pathCString = entry.path, entry.size > 0 else { continue }
                let path = String(cString: pathCString)
                accumulated[path] = ChartTreeBuilder.NodeStats(
                    size: entry.size,
                    directFileCount: Int(entry.file_count),
                    isDirectory: entry.is_directory != 0
                )
            }
            lock.unlock()
        }

        func merged(with exported: [String: ChartTreeBuilder.NodeStats]) -> [String: ChartTreeBuilder.NodeStats] {
            lock.lock()
            var merged = accumulated
            lock.unlock()
            for (path, stats) in exported where stats.size > 0 {
                merged[path] = stats
            }
            return merged
        }

        func snapshot(
            statsPtr: UnsafePointer<ldfs_path_stat>?,
            statsCount: Int,
            total: Int64,
            files: Int64
        ) -> ChartTreeBuilder.BuildResult {
            ingest(statsPtr: statsPtr, statsCount: statsCount)
            let statsByPath = merged(with: [:])
            return ChartTreeBuilder.BuildResult(
                statsByPath: statsByPath,
                totalSize: total,
                filesScanned: Int(files),
                deferredByParent: [:]
            )
        }

        func publishPartial(
            statsPtr: UnsafePointer<ldfs_path_stat>?,
            statsCount: Int,
            total: Int64,
            files: Int64
        ) {
            let partial = snapshot(statsPtr: statsPtr, statsCount: statsCount, total: total, files: files)
            onPartial?(partial)
            maybeSignalSplash(partial: partial)
        }

        func finalizeSplash(pathStats: [String: ChartTreeBuilder.NodeStats], total: Int64, files: Int) {
            let partial = ChartTreeBuilder.BuildResult(
                statsByPath: pathStats,
                totalSize: total,
                filesScanned: files,
                deferredByParent: [:]
            )
            maybeSignalSplash(partial: partial)

            lock.lock()
            let shouldForce = !didSignalSplash
            if shouldForce {
                didSignalSplash = true
            }
            let handler = onSplashReady
            let entries = splashListedEntries
            let scanRoot = splashScanRoot
            let chartDepth = splashChartMaxDepth
            lock.unlock()

            guard shouldForce, let handler, let scanRoot else { return }
            let chart = VolumeSplashReadiness.buildChartResult(
                listedEntries: entries,
                partial: partial,
                scanRoot: scanRoot,
                chartMaxDepth: chartDepth
            )
            handler(chart)
        }

        private func maybeSignalSplash(partial: ChartTreeBuilder.BuildResult) {
            guard let onSplashReady, let scanRoot = splashScanRoot, !splashListedEntries.isEmpty else { return }
            let chart = VolumeSplashReadiness.buildChartResult(
                listedEntries: splashListedEntries,
                partial: partial,
                scanRoot: scanRoot,
                chartMaxDepth: splashChartMaxDepth
            )
            guard VolumeSplashReadiness.isPresentable(
                listedEntries: splashListedEntries,
                chartResult: chart,
                scanRoot: scanRoot,
                chartMaxDepth: splashChartMaxDepth
            ) else { return }

            lock.lock()
            let shouldSignal = !didSignalSplash
            if shouldSignal {
                didSignalSplash = true
            }
            lock.unlock()
            if shouldSignal {
                onSplashReady(chart)
            }
        }
    }

    final class CancelBridge: @unchecked Sendable {
        let shouldCancel: (@Sendable () -> Bool)?

        init(shouldCancel: (@Sendable () -> Bool)?) {
            self.shouldCancel = shouldCancel
        }
    }

    final class RestrictedPathCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var events: [RestrictedScanEvent] = []

        func record(path: String, code: Int32) {
            lock.lock()
            events.append(RestrictedScanEvent(path: path, errorCode: Int(code)))
            lock.unlock()
        }

        func snapshot() -> [RestrictedScanEvent] {
            lock.lock()
            let copy = events
            lock.unlock()
            return copy
        }
    }

    static func resolvedParallelism(_ parallelism: Int?) -> Int {
        parallelism ?? ProcessInfo.processInfo.activeProcessorCount
    }

    static func immediateChildSizes(
        at root: URL,
        listedChildren: [URL],
        matcher: ChildPathMatcher,
        skipHiddenFiles: Bool,
        usePhysicalSize: Bool = true,
        firmLinks: Bool = true,
        parallelism: Int? = nil,
        nativeBufferSize: Int? = nil,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (DirectorySizeWalker.WalkResult) -> Void)? = nil
    ) -> DirectorySizeWalker.WalkResult? {
        let rootPath = PathUtils.resolved(root).path
        guard !rootPath.isEmpty else { return nil }

        let bridge = ScanBridge(matcher: matcher)
        let childCount = bridge.childEntries.count

        let runtime = NativeScanRuntime.settings(
            parallelism: resolvedParallelism(parallelism),
            bufferSizeOverride: nativeBufferSize
        )
        var childSizes = [Int64](repeating: 0, count: max(childCount, 0))
        var totalSize: Int64 = 0
        var filesScanned: Int64 = 0

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

        let partialContext = PartialContext(bridge: bridge, onPartial: onPartial)
        let partialPtr = Unmanaged.passUnretained(partialContext).toOpaque()

        let progressFn: ldfs_progress_fn = { ctx, sizesPtr, count, total, files in
            guard let ctx, let sizesPtr else { return }
            let context = Unmanaged<PartialContext>.fromOpaque(ctx).takeUnretainedValue()
            let sizes = Array(UnsafeBufferPointer(start: sizesPtr, count: count))
            let result = context.snapshot(sizes: sizes, total: total, files: files)
            context.onPartial?(result)
        }

        var metrics = ldfs_scan_metrics()
        let status = withExtendedLifetime((cancelBridge, partialContext, restrictedCollector, bridge)) {
            bridge.childEntries.withUnsafeBufferPointer { childEntriesBuffer in
                withUnsafeMutablePointer(to: &metrics) { metricsPtr in
                    rootPath.withCString { rootCString in
                        var options = ldfs_scan_options(
                            root_path: rootCString,
                            children: childEntriesBuffer.baseAddress,
                            child_count: childCount,
                            skip_hidden: skipHiddenFiles,
                            firm_links: firmLinks,
                            use_physical_size: usePhysicalSize,
                            worker_count: Int32(runtime.workerCount),
                            buffer_size: runtime.bufferSize,
                            turbo: runtime.turbo,
                            should_cancel: cancelFn,
                            cancel_ctx: cancelPtr,
                            on_restricted_path: restrictedFn,
                            restricted_ctx: restrictedPtr,
                            metrics_out: metricsPtr
                        )
                        return childSizes.withUnsafeMutableBufferPointer { sizesBuffer in
                            ldfs_scan_immediate_children(
                                &options,
                                childCount > 0 ? sizesBuffer.baseAddress : nil,
                                &totalSize,
                                &filesScanned,
                                onPartial == nil ? nil : progressFn,
                                partialPtr
                            )
                        }
                    }
                }
            }
        }

        guard status == 0 else { return nil }

        let restrictedEvents = restrictedCollector.snapshot()

        var childSizesByPath: [String: Int64] = [:]
        for (index, path) in bridge.childPaths.enumerated()
            where index < childSizes.count && childSizes[index] > 0 {
            childSizesByPath[path] = childSizes[index]
        }

        return DirectorySizeWalker.WalkResult(
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
    }

    static func buildChartTree(
        at root: URL,
        listedEntries: [DiskItem],
        maxDepth: Int,
        skipHiddenFiles: Bool,
        usePhysicalSize: Bool = true,
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
        _ = maxDepth

        let configuration = DirectorySizeWalker.Configuration(
            skipHiddenFiles: skipHiddenFiles,
            partialUpdateInterval: 96,
            parallelism: parallelism,
            usePhysicalSize: usePhysicalSize
        )

        let walk: DirectorySizeWalker.WalkResult
        if let onPartial {
            walk = DirectorySizeWalker.immediateChildSizes(
                at: normalizedRoot,
                listedChildren: directoryChildren,
                configuration: configuration,
                shouldCancel: shouldCancel,
                onPartial: { partial in
                    let chart = Self.chartBuildResult(
                        walk: partial,
                        listedEntries: listedEntries,
                        scanRoot: normalizedRoot
                    )
                    onPartial(chart)
                }
            )
        } else {
            walk = DirectorySizeWalker.immediateChildSizes(
                at: normalizedRoot,
                listedChildren: directoryChildren,
                configuration: configuration,
                shouldCancel: shouldCancel,
                onPartial: nil
            )
        }

        guard walk.totalSize > 0 || walk.filesScanned > 0 else { return nil }

        return Self.chartBuildResult(
            walk: walk,
            listedEntries: listedEntries,
            scanRoot: normalizedRoot
        )
    }

    private static func chartBuildResult(
        walk: DirectorySizeWalker.WalkResult,
        listedEntries: [DiskItem],
        scanRoot: URL
    ) -> ChartTreeBuilder.BuildResult {
        var statsByPath: [String: ChartTreeBuilder.NodeStats] = [:]
        for entry in listedEntries where !entry.isVirtual {
            let path = PathUtils.resolved(entry.url).path
            if entry.isDirectory {
                let size = PathUtils.directorySize(
                    in: walk.childSizesByPath,
                    itemURL: entry.url,
                    scanRoot: scanRoot
                ) ?? walk.childSizesByPath[path] ?? 0
                statsByPath[path] = ChartTreeBuilder.NodeStats(
                    size: size,
                    isDirectory: true
                )
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
            totalSize: walk.totalSize,
            filesScanned: walk.filesScanned,
            deferredByParent: [:],
            scanMetrics: walk.scanMetrics
        )
    }

    static func shallowPathStats(
        walk: DirectorySizeWalker.WalkResult,
        listedEntries: [DiskItem],
        scanRoot: URL
    ) -> [String: ChartTreeBuilder.NodeStats] {
        let rootPath = PathUtils.resolved(scanRoot).path
        var map: [String: ChartTreeBuilder.NodeStats] = [:]
        if walk.totalSize > 0 {
            map[rootPath] = ChartTreeBuilder.NodeStats(size: walk.totalSize, isDirectory: true)
        }
        for entry in listedEntries where !entry.isVirtual {
            let path = PathUtils.resolved(entry.url).path
            let size = walk.childSizesByPath[path] ?? (entry.isDirectory ? 0 : entry.size)
            guard size > 0 else { continue }
            map[path] = ChartTreeBuilder.NodeStats(
                size: size,
                directFileCount: entry.isDirectory ? 0 : 1,
                isDirectory: entry.isDirectory
            )
        }
        return map
    }

    /// Index depth for path stats during a volume walk (`ldfs_scan_tree`).
    public static func volumeTreeIndexDepth(chartMaxDepth: Int, fullVolumeIndex: Bool = false) -> Int {
        if fullVolumeIndex {
            return 32
        }
        return max(1, chartMaxDepth + 1)
    }

    /// DaisyDisk-style volume scan: one native bulk walk for sizing + shallow path stats for chart/navigation.
    public static func volumeTreeScan(
        at root: URL,
        listedEntries: [DiskItem],
        chartMaxDepth: Int,
        skipHiddenFiles: Bool,
        usePhysicalSize: Bool = true,
        parallelism: Int? = nil,
        fullVolumeIndex: Bool = false,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (ChartTreeBuilder.BuildResult) -> Void)? = nil,
        onSplashReady: (@Sendable (ChartTreeBuilder.BuildResult) -> Void)? = nil
    ) -> FusedNativeScanResult? {
        let rootPath = PathUtils.resolved(root).path
        guard !rootPath.isEmpty else { return nil }

        let directoryChildren = listedEntries
            .filter { $0.isDirectory && !$0.isVirtual }
            .map(\.url)

        let matcher = ChildPathMatcher(root: root, children: directoryChildren)
        let indexDepth = volumeTreeIndexDepth(
            chartMaxDepth: chartMaxDepth,
            fullVolumeIndex: fullVolumeIndex
        )

        let scanned: TreeScanNativeResult
        if let tree = scanVolumeTree(
            at: root,
            listedChildren: directoryChildren,
            splashListedEntries: listedEntries,
            matcher: matcher,
            indexMaxDepth: indexDepth,
            skipHiddenFiles: skipHiddenFiles,
            usePhysicalSize: usePhysicalSize,
            parallelism: parallelism,
            shouldCancel: shouldCancel,
            onPartial: onPartial,
            onSplashReady: onSplashReady
        ), tree.walk.filesScanned > 0 || tree.walk.totalSize > 0 {
            scanned = tree
        } else {
            let sizingConfiguration = DirectorySizeWalker.Configuration(
                skipHiddenFiles: skipHiddenFiles,
                partialUpdateInterval: 96,
                parallelism: parallelism,
                usePhysicalSize: usePhysicalSize
            )
            let sizing = DirectorySizeWalker.immediateChildSizes(
                at: root,
                listedChildren: directoryChildren,
                configuration: sizingConfiguration,
                shouldCancel: shouldCancel,
                onPartial: nil
            )
            guard sizing.totalSize > 0 || sizing.filesScanned > 0 else {
                return nil
            }
            scanned = TreeScanNativeResult(
                walk: sizing,
                pathStats: shallowPathStats(
                    walk: sizing,
                    listedEntries: listedEntries,
                    scanRoot: root
                )
            )
        }

        guard scanned.walk.totalSize > 0 || scanned.walk.filesScanned > 0 else {
            return nil
        }

        var childSizesByPath = scanned.walk.childSizesByPath
        for entry in listedEntries where !entry.isVirtual {
            let path = PathUtils.resolved(entry.url).path
            if childSizesByPath[path] != nil { continue }
            if let size = PathUtils.directorySize(
                in: scanned.pathStats.mapValues(\.size),
                itemURL: entry.url,
                scanRoot: root
            ) {
                childSizesByPath[path] = size
            } else if entry.size > 0 {
                childSizesByPath[path] = entry.size
            }
        }

        let sizingWalk = DirectorySizeWalker.WalkResult(
            childSizesByPath: childSizesByPath,
            totalSize: scanned.walk.totalSize,
            filesScanned: scanned.walk.filesScanned,
            scanMetrics: scanned.walk.scanMetrics,
            restrictedScanEvents: scanned.walk.restrictedScanEvents
        )

        var indexedPathSizes = scanned.pathStats.mapValues(\.size)
        indexedPathSizes[rootPath] = scanned.walk.totalSize
        for (path, size) in childSizesByPath where size > 0 {
            indexedPathSizes[path] = size
        }

        let chartResult = ChartTreeBuilder.buildResult(
            scanRoot: root,
            listedEntries: listedEntries,
            pathStats: scanned.pathStats,
            totalSize: scanned.walk.totalSize,
            filesScanned: scanned.walk.filesScanned,
            maxChartDepth: chartMaxDepth,
            scanMetrics: scanned.walk.scanMetrics
        )

        return FusedNativeScanResult(
            sizingWalk: sizingWalk,
            chartResult: chartResult,
            indexedPathSizes: indexedPathSizes
        )
    }

    public static func fusedVolumeScan(
        at root: URL,
        listedEntries: [DiskItem],
        maxDepth: Int,
        skipHiddenFiles: Bool,
        usePhysicalSize: Bool = true,
        parallelism: Int? = nil,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (ChartTreeBuilder.BuildResult) -> Void)? = nil,
        onSplashReady: (@Sendable (ChartTreeBuilder.BuildResult) -> Void)? = nil
    ) -> FusedNativeScanResult? {
        if let tree = volumeTreeScan(
            at: root,
            listedEntries: listedEntries,
            chartMaxDepth: maxDepth,
            skipHiddenFiles: skipHiddenFiles,
            usePhysicalSize: usePhysicalSize,
            parallelism: parallelism,
            shouldCancel: shouldCancel,
            onPartial: onPartial,
            onSplashReady: onSplashReady
        ), tree.sizingWalk.filesScanned > 0 || tree.sizingWalk.totalSize > 0 {
            return tree
        }

        guard let chartResult = buildChartTree(
            at: root,
            listedEntries: listedEntries,
            maxDepth: maxDepth,
            skipHiddenFiles: skipHiddenFiles,
            usePhysicalSize: usePhysicalSize,
            parallelism: parallelism,
            shouldCancel: shouldCancel,
            onPartial: onPartial
        ) else {
            return nil
        }

        let statsSizes = chartResult.statsByPath.mapValues(\.size)
        var childSizesByPath: [String: Int64] = [:]
        for entry in listedEntries where !entry.isVirtual {
            let path = PathUtils.resolved(entry.url).path
            if let size = PathUtils.directorySize(in: statsSizes, itemURL: entry.url, scanRoot: root) {
                childSizesByPath[path] = size
            } else if entry.size > 0 {
                childSizesByPath[path] = entry.size
            }
        }

        let sizingWalk = DirectorySizeWalker.WalkResult(
            childSizesByPath: childSizesByPath,
            totalSize: chartResult.totalSize,
            filesScanned: chartResult.filesScanned,
            scanMetrics: chartResult.scanMetrics
        )
        return FusedNativeScanResult(
            sizingWalk: sizingWalk,
            chartResult: chartResult,
            indexedPathSizes: statsSizes
        )
    }
}
