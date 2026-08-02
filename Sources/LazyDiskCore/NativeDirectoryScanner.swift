import Foundation
import LazyDiskFS

/// macOS-native directory sizing via getattrlistbulk (LazyDiskFS).
enum NativeDirectoryScanner {
    static var isAvailable: Bool { true }

    private final class ScanBridge: @unchecked Sendable {
        let childEntries: ContiguousArray<ldfs_child_entry>
        let childPaths: [String]
        private let prefixPointerArrays: [ContiguousArray<UnsafePointer<CChar>?>]
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
            prefixPointerArrays = pointerArrays
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

    private final class CancelBridge: @unchecked Sendable {
        let shouldCancel: (@Sendable () -> Bool)?

        init(shouldCancel: (@Sendable () -> Bool)?) {
            self.shouldCancel = shouldCancel
        }
    }

    static func immediateChildSizes(
        at root: URL,
        listedChildren: [URL],
        matcher: ChildPathMatcher,
        skipHiddenFiles: Bool,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (DirectorySizeWalker.WalkResult) -> Void)? = nil
    ) -> DirectorySizeWalker.WalkResult? {
        let rootPath = PathUtils.resolved(root).path
        guard !rootPath.isEmpty else { return nil }

        let bridge = ScanBridge(matcher: matcher)
        let childCount = bridge.childEntries.count
        guard childCount > 0 else { return nil }

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
                worker_count: 5,
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
}
