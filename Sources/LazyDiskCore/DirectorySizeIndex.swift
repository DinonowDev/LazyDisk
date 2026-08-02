import Foundation

/// Shared size cache and coordinated subtree walks (dedupes concurrent requests).
public actor DirectorySizeIndex {
    public static let shared = DirectorySizeIndex()

    private var sizesByPath: [String: Int64] = [:]
    private var inflightWalks: [String: Task<DirectorySizeWalker.WalkResult, Never>] = [:]
    private var partialObservers: [String: [@Sendable (DirectorySizeWalker.WalkResult) -> Void]] = [:]

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
        listedChildren: [URL]? = nil,
        configuration: DirectorySizeWalker.Configuration = .default,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (DirectorySizeWalker.WalkResult) -> Void)? = nil
    ) async -> DirectorySizeWalker.WalkResult {
        let key = PathUtils.resolved(url).path

        if let listedChildren, !listedChildren.isEmpty, inflightWalks[key] == nil {
            let childPaths = listedChildren.map { PathUtils.resolved($0).path }
            if let rootSize = sizesByPath[key], rootSize > 0,
               childPaths.allSatisfy({ sizesByPath[$0] != nil }) {
                var childSizes: [String: Int64] = [:]
                for path in childPaths {
                    childSizes[path] = sizesByPath[path] ?? 0
                }
                let cached = DirectorySizeWalker.WalkResult(
                    childSizesByPath: childSizes,
                    totalSize: rootSize
                )
                if let onPartial {
                    onPartial(cached)
                }
                return cached
            }
        }

        if let onPartial {
            partialObservers[key, default: []].append(onPartial)
        }

        if let existing = inflightWalks[key] {
            return await existing.value
        }

        let keyCopy = key
        let partialHandler: @Sendable (DirectorySizeWalker.WalkResult) -> Void = { result in
            Task {
                await DirectorySizeIndex.shared.notifyPartialObservers(for: keyCopy, result: result)
            }
        }

        let task = Task<DirectorySizeWalker.WalkResult, Never> {
            await Task.detached(priority: .utility) {
                DirectorySizeWalker.immediateChildSizes(
                    at: URL(fileURLWithPath: key, isDirectory: true),
                    listedChildren: listedChildren,
                    configuration: configuration,
                    shouldCancel: shouldCancel,
                    onPartial: partialHandler
                )
            }.value
        }
        inflightWalks[key] = task

        let result = await task.value
        inflightWalks.removeValue(forKey: key)
        partialObservers.removeValue(forKey: key)
        store(result, forRoot: key)
        return result
    }

    private func notifyPartialObservers(
        for key: String,
        result: DirectorySizeWalker.WalkResult
    ) {
        for observer in partialObservers[key, default: []] {
            observer(result)
        }
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

    /// Invalidate and rerun a single native walk for one directory level.
    public func rescanSubtree(
        at url: URL,
        listedChildren: [URL]? = nil,
        configuration: DirectorySizeWalker.Configuration = .default,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (DirectorySizeWalker.WalkResult) -> Void)? = nil
    ) async -> DirectorySizeWalker.WalkResult {
        let key = PathUtils.resolved(url).path
        invalidate(prefix: key)
        return await walk(
            at: url,
            listedChildren: listedChildren,
            configuration: configuration,
            shouldCancel: shouldCancel,
            onPartial: onPartial
        )
    }

    public func clear() {
        for task in inflightWalks.values {
            task.cancel()
        }
        sizesByPath.removeAll()
        inflightWalks.removeAll()
        partialObservers.removeAll()
    }
}
