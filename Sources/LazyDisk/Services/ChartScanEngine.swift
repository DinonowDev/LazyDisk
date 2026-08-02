import Foundation
import LazyDiskCore

/// Parallel breadth-first chart child discovery with streaming sizes and priority scheduling.
enum ChartScanEngine {
    struct Request: Sendable {
        let parents: [DiskItem]
        let maxDepth: Int
        let parallelism: Int
        let seededEntriesByParentPath: [String: [DiskItem]]
    }

    private actor MapState {
        private(set) var map: [String: [DiskItem]]

        init(seed: [String: [DiskItem]]) {
            map = seed
        }

        func merge(path: String, children: [DiskItem]) -> [String: [DiskItem]] {
            guard !children.isEmpty else { return map }
            map[path] = children
            return map
        }

        func apply(_ children: [String: [DiskItem]]) -> [String: [DiskItem]] {
            for (path, items) in children where !items.isEmpty {
                map[path] = items
            }
            return map
        }

        func snapshot() -> [String: [DiskItem]] {
            map
        }
    }

    static func buildChildMap(
        request: Request,
        isCancelled: @escaping @Sendable () -> Bool,
        onProgress: @escaping @Sendable (ChartChildrenScanProgress) -> Void,
        onPartial: @escaping @Sendable ([String: [DiskItem]]) -> Void,
        chartChildren: @escaping @Sendable ([DiskItem]) async -> [DiskItem]
    ) async -> [String: [DiskItem]] {
        let state = MapState(seed: request.seededEntriesByParentPath)
        var depth = 0
        var currentLevel = request.parents.filter { $0.isDirectory && !$0.isVirtual }

        var totalFolders = currentLevel.filter {
            request.seededEntriesByParentPath[PathUtils.resolved($0.url).path] == nil
        }.count
        var completedFolders = request.seededEntriesByParentPath.count
        var filesScanned = 0

        func publishProgress(name: String) async {
            onProgress(ChartChildrenScanProgress(
                completedFolders: completedFolders,
                totalFolders: max(totalFolders, 1),
                currentFolderName: name,
                currentDepth: depth + 1,
                maxDepth: request.maxDepth + 1,
                filesScanned: filesScanned
            ))
        }

        await publishProgress(name: "")
        let initial = await state.snapshot()
        if !initial.isEmpty {
            onPartial(initial)
        }

        while !currentLevel.isEmpty, depth <= request.maxDepth {
            guard !isCancelled() else { return await state.snapshot() }

            let currentMap = await state.snapshot()
            let toFetch = currentLevel
                .filter { currentMap[PathUtils.resolved($0.url).path] == nil }
                .sorted { $0.size > $1.size }

            if !toFetch.isEmpty {
                await withTaskGroup(of: (String, [DiskItem]?, Int).self) { group in
                    var nextIndex = 0
                    let limit = max(1, min(request.parallelism, 16))
                    var inFlight = 0

                    func enqueueNext() {
                        while inFlight < limit, nextIndex < toFetch.count {
                            let item = toFetch[nextIndex]
                            nextIndex += 1
                            inFlight += 1
                            group.addTask {
                                guard !isCancelled() else {
                                    return (item.url.path, nil, 0)
                                }
                                let parentPath = PathUtils.resolved(item.url).path
                                let (children, scanned) = await loadChildren(
                                    for: item,
                                    isCancelled: isCancelled,
                                    chartChildren: chartChildren,
                                    onStreaming: { partialEntries, _ in
                                        Task {
                                            let partialChildren = await chartChildren(partialEntries)
                                            guard !partialChildren.isEmpty else { return }
                                            let snapshot = await state.merge(path: parentPath, children: partialChildren)
                                            onPartial(snapshot)
                                        }
                                    }
                                )
                                return (parentPath, children.isEmpty ? nil : children, scanned)
                            }
                        }
                    }

                    enqueueNext()

                    for await (parentPath, children, scanned) in group {
                        inFlight -= 1
                        completedFolders += 1
                        filesScanned += scanned
                        await publishProgress(
                            name: parentPath.split(separator: "/").last.map(String.init) ?? parentPath
                        )

                        if let children {
                            let snapshot = await state.merge(path: parentPath, children: children)
                            onPartial(snapshot)
                        }

                        enqueueNext()
                    }
                }
            }

            guard depth < request.maxDepth else { break }

            let levelMap = await state.snapshot()
            var nextLevel: [DiskItem] = []
            var seen = Set<String>()

            for item in currentLevel {
                let path = PathUtils.resolved(item.url).path
                guard let children = levelMap[path] else { continue }

                for child in children where child.isDirectory && !child.isVirtual {
                    let childPath = PathUtils.resolved(child.url).path
                    guard seen.insert(childPath).inserted else { continue }
                    nextLevel.append(child)
                    if levelMap[childPath] == nil {
                        totalFolders += 1
                    }
                }
            }

            nextLevel.sort { $0.size > $1.size }
            currentLevel = nextLevel
            depth += 1
        }

        return await state.snapshot()
    }

    private static func loadChildren(
        for item: DiskItem,
        isCancelled: @escaping @Sendable () -> Bool,
        chartChildren: @escaping @Sendable ([DiskItem]) async -> [DiskItem],
        onStreaming: @escaping @Sendable ([DiskItem], Int) -> Void
    ) async -> ([DiskItem], Int) {
        let folderURL = PathUtils.resolved(item.url)

        if let cached = await ScanCache.shared.get(folderURL) {
            let children = await chartChildren(cached.entries)
            return (children, 0)
        }

        var latestFilesScanned = 0
        let scanned = await DiskScanner.shared.scanFolderContents(
            at: folderURL,
            light: true,
            shouldCancel: isCancelled,
            onPartial: { partial, filesScanned in
                latestFilesScanned = max(latestFilesScanned, filesScanned)
                onStreaming(partial, filesScanned)
            }
        )

        let sorted = scanned.sorted { $0.size > $1.size }
        let cachedDirectory = CachedDirectory(
            url: folderURL,
            entries: sorted,
            scannedAt: Date(),
            isVolumeRoot: false
        )
        guard await ScanCache.shared.isComplete(cachedDirectory) else {
            return ([], latestFilesScanned)
        }

        await ScanCache.shared.set(folderURL, entries: sorted, isVolumeRoot: false)
        let children = await chartChildren(sorted)
        return (children, latestFilesScanned)
    }
}
