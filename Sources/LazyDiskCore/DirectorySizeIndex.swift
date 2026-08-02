import Foundation
import LazyDiskCore

/// Shared size cache and coordinated subtree walks (dedupes concurrent requests).
public actor DirectorySizeIndex {
    public static let shared = DirectorySizeIndex()

    private var sizesByPath: [String: Int64] = [:]
    private var inflightWalks: [String: Task<DirectorySizeWalker.WalkResult, Never>] = [:]

    public func size(for path: String) -> Int64? {
        sizesByPath[path]
    }

    public func sizesSnapshot() -> [String: Int64] {
        sizesByPath
    }

    public func importSizes(_ sizes: [String: Int64]) {
        for (path, size) in sizes where size > 0 {
            sizesByPath[path] = size
        }
    }

    public func walk(
        at url: URL,
        configuration: DirectorySizeWalker.Configuration = .default,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (DirectorySizeWalker.WalkResult) -> Void)? = nil
    ) async -> DirectorySizeWalker.WalkResult {
        let key = PathUtils.resolved(url).path

        if let existing = inflightWalks[key] {
            return await existing.value
        }

        let task = Task<DirectorySizeWalker.WalkResult, Never> {
            await Task.detached(priority: .utility) {
                DirectorySizeWalker.immediateChildSizes(
                    at: URL(fileURLWithPath: key, isDirectory: true),
                    configuration: configuration,
                    shouldCancel: shouldCancel,
                    onPartial: onPartial
                )
            }.value
        }
        inflightWalks[key] = task

        let result = await task.value
        inflightWalks.removeValue(forKey: key)
        store(result, forRoot: key)
        return result
    }

    public func store(_ result: DirectorySizeWalker.WalkResult, forRoot rootPath: String) {
        sizesByPath[rootPath] = result.totalSize
        for (childPath, size) in result.childSizesByPath {
            sizesByPath[childPath] = size
        }
    }

    public func storeSize(_ size: Int64, for path: String) {
        sizesByPath[path] = size
    }

    public func invalidate(prefix: String) {
        let normalized = prefix.hasSuffix("/") ? String(prefix.dropLast()) : prefix
        sizesByPath = sizesByPath.filter { key, _ in
            key != normalized && !key.hasPrefix(normalized + "/")
        }
    }

    public func clear() {
        for task in inflightWalks.values {
            task.cancel()
        }
        sizesByPath.removeAll()
        inflightWalks.removeAll()
    }
}
