import Foundation
import LazyDiskCore

private final class MaxIntCounter: @unchecked Sendable {
    private var value = 0
    private let lock = NSLock()

    func update(_ newValue: Int) {
        lock.lock()
        defer { lock.unlock() }
        value = max(value, newValue)
    }

    var current: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

/// Parallel breadth-first chart child discovery with streaming sizes and priority scheduling.
enum ChartScanEngine {
    struct Request: Sendable {
        let parents: [DiskItem]
        let maxDepth: Int
        let parallelism: Int
        let maxChildrenPerNode: Int
        let seededEntriesByParentPath: [String: [DiskItem]]
        let restoredDisplayFraction: Double
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

        func snapshot() -> [String: [DiskItem]] {
            map
        }
    }

    private actor ProgressTracker {
        private let maxDepth: Int
        private var completedFolders: Int
        private var totalFolders: Int
        private var currentDepth: Int
        private var filesScanned: Int
        private var inFlightByPath: [String: Double] = [:]
        private var publishedFraction: Double = 0
        private var lastFolderName = ""

        init(
            seedCount: Int,
            estimatedTotal: Int,
            maxDepth: Int,
            restoredDisplayFraction: Double = 0
        ) {
            completedFolders = seedCount
            totalFolders = max(estimatedTotal, 1)
            self.maxDepth = maxDepth
            currentDepth = 1
            filesScanned = 0
            publishedFraction = max(0, min(restoredDisplayFraction, 0.99))
        }

        func setDepth(_ depth: Int) {
            currentDepth = depth + 1
        }

        func registerUpcomingFolders(_ count: Int) {
            guard count > 0 else { return }
            let dynamicFloor = completedFolders + inFlightByPath.count + count
            totalFolders = max(totalFolders, dynamicFloor)
        }

        func updateInFlight(
            path: String,
            filesScanned: Int,
            entries: [DiskItem],
            folderName: String
        ) -> ChartChildrenScanProgress {
            let fraction = ChartScanProgressMath.inFlightFraction(
                filesScanned: filesScanned,
                entries: entries
            )
            inFlightByPath[path] = fraction
            self.filesScanned = max(self.filesScanned, filesScanned)
            lastFolderName = folderName
            return snapshot()
        }

        func completeFolder(path: String, scannedFiles: Int, folderName: String) -> ChartChildrenScanProgress {
            inFlightByPath.removeValue(forKey: path)
            completedFolders += 1
            filesScanned += scannedFiles
            lastFolderName = folderName
            return snapshot()
        }

        func snapshot() -> ChartChildrenScanProgress {
            let inFlightValues = Array(inFlightByPath.values)
            let inFlight = inFlightValues.isEmpty
                ? 0
                : inFlightValues.reduce(0, +) / Double(inFlightValues.count)
            let raw = ChartScanProgressMath.combinedFraction(
                completedFolders: completedFolders,
                totalFolders: totalFolders,
                inFlightContribution: inFlight,
                currentDepth: currentDepth,
                maxDepth: maxDepth + 1
            )
            publishedFraction = max(publishedFraction, raw)

            return ChartChildrenScanProgress(
                completedFolders: completedFolders,
                totalFolders: totalFolders,
                currentFolderName: lastFolderName,
                currentDepth: currentDepth,
                maxDepth: maxDepth + 1,
                filesScanned: filesScanned,
                inFlightContribution: inFlight,
                displayFraction: publishedFraction
            )
        }

        func monotonicFraction(for progress: ChartChildrenScanProgress) -> ChartChildrenScanProgress {
            publishedFraction = max(publishedFraction, progress.displayFraction)
            return ChartChildrenScanProgress(
                completedFolders: progress.completedFolders,
                totalFolders: progress.totalFolders,
                currentFolderName: progress.currentFolderName,
                currentDepth: progress.currentDepth,
                maxDepth: progress.maxDepth,
                filesScanned: progress.filesScanned,
                inFlightContribution: progress.inFlightContribution,
                displayFraction: publishedFraction
            )
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
        let parentCount = request.parents.filter { $0.isDirectory && !$0.isVirtual }.count
        let estimatedTotal = ChartWorkloadEstimator.estimateTotalFolders(
            rootFolderCount: parentCount,
            maxDepth: request.maxDepth,
            maxChildrenPerNode: request.maxChildrenPerNode
        )
        let tracker = ProgressTracker(
            seedCount: request.seededEntriesByParentPath.count,
            estimatedTotal: estimatedTotal,
            maxDepth: request.maxDepth,
            restoredDisplayFraction: request.restoredDisplayFraction
        )

        var depth = 0
        var currentLevel = request.parents.filter { $0.isDirectory && !$0.isVirtual }

        @Sendable func publish(_ progress: ChartChildrenScanProgress) async {
            let monotonic = await tracker.monotonicFraction(for: progress)
            onProgress(monotonic)
        }

        await publish(await tracker.snapshot())
        let initial = await state.snapshot()
        if !initial.isEmpty {
            onPartial(initial)
        }

        while !currentLevel.isEmpty, depth <= request.maxDepth {
            guard !isCancelled() else { return await state.snapshot() }

            await tracker.setDepth(depth)

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
                                let folderName = item.displayName
                                let (children, scanned) = await loadChildren(
                                    for: item,
                                    isCancelled: isCancelled,
                                    chartChildren: chartChildren,
                                    onStreaming: { partialEntries, partialFiles in
                                        Task {
                                            let progress = await tracker.updateInFlight(
                                                path: parentPath,
                                                filesScanned: partialFiles,
                                                entries: partialEntries,
                                                folderName: folderName
                                            )
                                            await publish(progress)

                                            let partialChildren = await chartChildren(partialEntries)
                                            guard !partialChildren.isEmpty else { return }
                                            let snapshot = await state.merge(
                                                path: parentPath,
                                                children: partialChildren
                                            )
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
                        let folderName = parentPath.split(separator: "/").last.map(String.init) ?? parentPath
                        let progress = await tracker.completeFolder(
                            path: parentPath,
                            scannedFiles: scanned,
                            folderName: folderName
                        )
                        await publish(progress)

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
            var upcoming = 0

            for item in currentLevel {
                let path = PathUtils.resolved(item.url).path
                guard let children = levelMap[path] else { continue }

                for child in children where child.isDirectory && !child.isVirtual {
                    let childPath = PathUtils.resolved(child.url).path
                    guard seen.insert(childPath).inserted else { continue }
                    nextLevel.append(child)
                    if levelMap[childPath] == nil {
                        upcoming += 1
                    }
                }
            }

            await tracker.registerUpcomingFolders(upcoming)
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

        let filesScannedCounter = MaxIntCounter()
        let scanned = await DiskScanner.shared.scanFolderContents(
            at: folderURL,
            light: true,
            shouldCancel: isCancelled,
            onPartial: { partial, filesScanned in
                filesScannedCounter.update(filesScanned)
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
            return ([], filesScannedCounter.current)
        }

        await ScanCache.shared.set(
            folderURL,
            entries: sorted,
            isVolumeRoot: false,
            contentLevel: .light
        )
        let children = await chartChildren(sorted)
        return (children, filesScannedCounter.current)
    }
}
