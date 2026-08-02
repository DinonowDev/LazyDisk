import Foundation
import LazyDiskCore

/// Parallel breadth-first chart child discovery with single-pass folder sizing.
enum ChartScanEngine {
    struct Request: Sendable {
        let parents: [DiskItem]
        let maxDepth: Int
        let parallelism: Int
        let seededEntriesByParentPath: [String: [DiskItem]]
    }

    static func buildChildMap(
        request: Request,
        isCancelled: @escaping @Sendable () -> Bool,
        onProgress: @escaping @Sendable (ChartChildrenScanProgress) -> Void,
        onPartial: @escaping @Sendable ([String: [DiskItem]]) -> Void,
        chartChildren: @escaping @Sendable ([DiskItem]) async -> [DiskItem]
    ) async -> [String: [DiskItem]] {
        var map = request.seededEntriesByParentPath
        var depth = 0
        var currentLevel = request.parents.filter { $0.isDirectory && !$0.isVirtual }

        var totalFolders = currentLevel.filter {
            map[PathUtils.resolved($0.url).path] == nil
        }.count
        var completedFolders = map.count

        func publishProgress(name: String) {
            onProgress(ChartChildrenScanProgress(
                completedFolders: completedFolders,
                totalFolders: max(totalFolders, 1),
                currentFolderName: name
            ))
        }

        publishProgress(name: "")
        if !map.isEmpty {
            onPartial(map)
        }

        while !currentLevel.isEmpty, depth <= request.maxDepth {
            guard !isCancelled() else { return map }

            let toFetch = currentLevel.filter {
                map[PathUtils.resolved($0.url).path] == nil
            }

            if !toFetch.isEmpty {
                await withTaskGroup(of: (String, [DiskItem]?).self) { group in
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
                                    return (item.url.path, nil)
                                }
                                let parentPath = PathUtils.resolved(item.url).path
                                let children = await loadChildren(
                                    for: item,
                                    chartChildren: chartChildren
                                )
                                return (parentPath, children.isEmpty ? nil : children)
                            }
                        }
                    }

                    enqueueNext()

                    for await (parentPath, children) in group {
                        inFlight -= 1
                        completedFolders += 1
                        publishProgress(
                            name: parentPath.split(separator: "/").last.map(String.init) ?? parentPath
                        )

                        if let children {
                            map[parentPath] = children
                            onPartial(map)
                        }

                        enqueueNext()
                    }
                }
            }

            guard depth < request.maxDepth else { break }

            var nextLevel: [DiskItem] = []
            var seen = Set<String>()

            for item in currentLevel {
                let path = PathUtils.resolved(item.url).path
                guard let children = map[path] else { continue }

                for child in children where child.isDirectory && !child.isVirtual {
                    let childPath = PathUtils.resolved(child.url).path
                    guard seen.insert(childPath).inserted else { continue }
                    nextLevel.append(child)
                    if map[childPath] == nil {
                        totalFolders += 1
                    }
                }
            }

            currentLevel = nextLevel
            depth += 1
        }

        return map
    }

    private static func loadChildren(
        for item: DiskItem,
        chartChildren: @escaping @Sendable ([DiskItem]) async -> [DiskItem]
    ) async -> [DiskItem] {
        let folderURL = PathUtils.resolved(item.url)

        let entries: [DiskItem]
        if let cached = await ScanCache.shared.get(folderURL) {
            entries = cached.entries
        } else {
            let scanned = await DiskScanner.shared.scanFolderContents(at: folderURL, light: true)
            let sorted = scanned.sorted { $0.size > $1.size }
            let cachedDirectory = CachedDirectory(
                url: folderURL,
                entries: sorted,
                scannedAt: Date(),
                isVolumeRoot: false
            )
            guard await ScanCache.shared.isComplete(cachedDirectory) else { return [] }

            await ScanCache.shared.set(folderURL, entries: sorted, isVolumeRoot: false)
            entries = sorted
        }

        return await chartChildren(entries)
    }
}
