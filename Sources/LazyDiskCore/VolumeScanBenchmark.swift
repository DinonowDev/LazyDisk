import Foundation

/// Headless performance benchmark aligned with in-app "scan → ready → drill-down" (DaisyDisk-style).
public enum VolumeScanBenchmark {
    public struct NavigationStep: Sendable, Codable, Equatable {
        public let index: Int
        public let path: String
        public let name: String
        public let seconds: Double
        public let childCount: Int
    }

    public struct Phase: Sendable, Codable, Equatable {
        public let name: String
        public let seconds: Double
        public let detail: String?
    }

    public struct Report: Sendable, Codable, Equatable {
        public let scanRoot: String
        public let recordedAt: String
        public let phases: [Phase]
        /// List + single bulk walk + chart map (DaisyDisk-style splash; excludes display-depth prefetch).
        public let daisyParityReadySeconds: Double
        /// Same as `daisyParityReadySeconds` for compare scripts; prefetch is reported separately in `phases`.
        public let gatedReadySeconds: Double
        public let volumeTreeFilesScanned: Int
        public let indexedPathCount: Int
        public let navigationSteps: Int
        public let navigationTotalSeconds: Double
        public let navigationMedianSeconds: Double
        public let navigationP95Seconds: Double
        public let navigation: [NavigationStep]
        public let notes: [String]
    }

    public struct Options: Sendable {
        public var scanRoot: URL
        public var skipHiddenFiles: Bool
        public var parallelism: Int
        public var chartMaxDepth: Int
        public var prefetchDisplayDepth: Int
        public var navigationSteps: Int
        public var fullVolumeIndex: Bool

        public init(
            scanRoot: URL,
            skipHiddenFiles: Bool = false,
            parallelism: Int = NativeScanRuntime.daisyDefaultWorkers,
            chartMaxDepth: Int = SunburstLayoutEngine.Config.daisyDisk.maxDepth,
            prefetchDisplayDepth: Int = SunburstLayoutEngine.Config.daisyDisk.maxDepth,
            navigationSteps: Int = 20,
            fullVolumeIndex: Bool = false
        ) {
            self.scanRoot = scanRoot
            self.skipHiddenFiles = skipHiddenFiles
            self.parallelism = parallelism
            self.chartMaxDepth = chartMaxDepth
            self.prefetchDisplayDepth = prefetchDisplayDepth
            self.navigationSteps = navigationSteps
            self.fullVolumeIndex = fullVolumeIndex
        }
    }

    public static func run(options: Options) async -> Report? {
        let scanRoot = PathUtils.resolved(options.scanRoot)
        guard FileManager.default.fileExists(atPath: scanRoot.path) else { return nil }

        var phases: [Phase] = []
        var notes: [String] = []

        let listStart = CFAbsoluteTimeGetCurrent()
        let rootListed = listDirectoryLight(at: scanRoot, skipHidden: options.skipHiddenFiles)
        phases.append(Phase(
            name: "list_volume_root",
            seconds: CFAbsoluteTimeGetCurrent() - listStart,
            detail: "\(rootListed.count) entries"
        ))

        let splashGate = VolumeSplashGate()
        let treeStart = CFAbsoluteTimeGetCurrent()
        let treeTask = Task {
            NativeDirectoryScanner.volumeTreeScan(
                at: scanRoot,
                listedEntries: rootListed,
                chartMaxDepth: options.chartMaxDepth,
                skipHiddenFiles: options.skipHiddenFiles,
                parallelism: options.parallelism,
                fullVolumeIndex: options.fullVolumeIndex,
                onPartial: nil,
                onSplashReady: { _ in
                    let elapsed = CFAbsoluteTimeGetCurrent() - treeStart
                    Task { await splashGate.signal(elapsed: elapsed) }
                }
            )
        }

        await splashGate.wait()
        let splashPhase = await splashGate.elapsedSeconds()
            ?? (CFAbsoluteTimeGetCurrent() - treeStart)
        phases.append(Phase(
            name: "volume_splash_ready",
            seconds: splashPhase,
            detail: nil
        ))

        guard let tree = await treeTask.value else {
            notes.append("volumeTreeScan returned nil")
            let ready = phases.reduce(0) { $0 + $1.seconds }
            return Report(
                scanRoot: scanRoot.path,
                recordedAt: isoTimestamp(),
                phases: phases,
                daisyParityReadySeconds: ready,
                gatedReadySeconds: ready,
                volumeTreeFilesScanned: 0,
                indexedPathCount: 0,
                navigationSteps: 0,
                navigationTotalSeconds: 0,
                navigationMedianSeconds: 0,
                navigationP95Seconds: 0,
                navigation: [],
                notes: notes
            )
        }
        let treeSeconds = CFAbsoluteTimeGetCurrent() - treeStart
        phases.append(Phase(
            name: "volume_tree_scan",
            seconds: treeSeconds,
            detail: "\(tree.sizingWalk.filesScanned) files"
        ))

        await DirectorySizeIndex.shared.importSizes(tree.indexedPathSizes)
        let snapshot = await DirectorySizeIndex.shared.sizesSnapshot()

        let mapStart = CFAbsoluteTimeGetCurrent()
        _ = ChartTreeBuilder.childMap(
            from: tree.chartResult,
            root: scanRoot,
            listedEntries: rootListed,
            maxChildrenPerNode: SunburstLayoutEngine.Config.daisyDisk.maxChildrenPerNode,
            otherItemName: "Other"
        )
        phases.append(Phase(
            name: "chart_child_map",
            seconds: CFAbsoluteTimeGetCurrent() - mapStart,
            detail: nil
        ))

        let prefetchStart = CFAbsoluteTimeGetCurrent()
        let prefetched = await prefetchDisplayDepths(
            scanRoot: scanRoot,
            rootEntries: rootListed,
            maxDepth: options.prefetchDisplayDepth,
            skipHidden: options.skipHiddenFiles,
            sizes: snapshot
        )
        phases.append(Phase(
            name: "prefetch_display_depth",
            seconds: CFAbsoluteTimeGetCurrent() - prefetchStart,
            detail: "\(prefetched) folders"
        ))

        let daisyParityReady = phases
            .filter {
                $0.name != "prefetch_display_depth"
                    && $0.name != "volume_tree_scan"
            }
            .reduce(0) { $0 + $1.seconds }

        let navigation = simulateNavigation(
            scanRoot: scanRoot,
            sizes: snapshot,
            skipHidden: options.skipHiddenFiles,
            steps: options.navigationSteps
        )
        let navTimes = navigation.map(\.seconds).sorted()
        let navTotal = navTimes.reduce(0, +)
        let navMedian = navTimes.isEmpty ? 0 : navTimes[navTimes.count / 2]
        let navP95 = navTimes.isEmpty ? 0 : navTimes[Int(Double(navTimes.count - 1) * 0.95)]

        return Report(
            scanRoot: scanRoot.path,
            recordedAt: isoTimestamp(),
            phases: phases,
            daisyParityReadySeconds: daisyParityReady,
            gatedReadySeconds: daisyParityReady,
            volumeTreeFilesScanned: tree.sizingWalk.filesScanned,
            indexedPathCount: snapshot.count,
            navigationSteps: navigation.count,
            navigationTotalSeconds: navTotal,
            navigationMedianSeconds: navMedian,
            navigationP95Seconds: navP95,
            navigation: navigation,
            notes: notes
        )
    }

    // MARK: - Navigation (folder listing + indexed sizes, no subtree walk)

    public static func simulateNavigation(
        scanRoot: URL,
        sizes: [String: Int64],
        skipHidden: Bool,
        steps: Int
    ) -> [NavigationStep] {
        var results: [NavigationStep] = []
        var current = PathUtils.resolved(scanRoot)
        var visited = Set<String>()

        for index in 0..<steps {
            let start = CFAbsoluteTimeGetCurrent()
            let listed = listDirectoryLight(at: current, skipHidden: skipHidden)
            let sized = applyIndexedSizes(listed, scanRoot: scanRoot, sizes: sizes)
            let directories = sized
                .filter { $0.isDirectory && !$0.isVirtual && $0.size > 0 }
                .sorted { $0.size > $1.size }

            let elapsed = CFAbsoluteTimeGetCurrent() - start
            results.append(NavigationStep(
                index: index + 1,
                path: current.path,
                name: current.lastPathComponent.isEmpty ? current.path : current.lastPathComponent,
                seconds: elapsed,
                childCount: sized.count
            ))

            guard let next = directories.first(where: { item in
                let path = PathUtils.resolved(item.url).path
                return visited.insert(path).inserted
            }) else {
                if let parent = parentDirectory(of: current, within: scanRoot) {
                    current = parent
                    continue
                }
                break
            }
            current = PathUtils.resolved(next.url)
        }

        return results
    }

    // MARK: - Helpers

    private static func prefetchDisplayDepths(
        scanRoot: URL,
        rootEntries: [DiskItem],
        maxDepth: Int,
        skipHidden: Bool,
        sizes: [String: Int64]
    ) async -> Int {
        var count = 0
        var frontier: [URL] = rootEntries
            .filter { $0.isDirectory && !$0.isVirtual }
            .map(\.url)

        for depth in 1...max(1, maxDepth) {
            guard !frontier.isEmpty else { break }
            var nextFrontier: [URL] = []
            for folder in frontier {
                let normalized = PathUtils.resolved(folder)
                let listed = listDirectoryLight(at: normalized, skipHidden: skipHidden)
                _ = applyIndexedSizes(listed, scanRoot: scanRoot, sizes: sizes)
                count += 1
                if depth < maxDepth {
                    for item in listed where item.isDirectory && !item.isVirtual {
                        nextFrontier.append(item.url)
                    }
                }
            }
            frontier = nextFrontier
        }
        return count
    }

    private static func listDirectoryLight(at url: URL, skipHidden: Bool) -> [DiskItem] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isHiddenKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .contentModificationDateKey,
        ]
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if skipHidden { options.insert(.skipsHiddenFiles) }

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: options
        ) else {
            return []
        }

        return contents.map { fileURL in
            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            let isDirectory = values?.isDirectory ?? false
            let isHidden = values?.isHidden ?? false
            let size = Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
            return DiskItem(
                url: PathUtils.resolved(fileURL),
                size: isDirectory ? 0 : size,
                isDirectory: isDirectory,
                isScanning: isDirectory,
                isHidden: isHidden
            )
        }
    }

    private static func applyIndexedSizes(
        _ items: [DiskItem],
        scanRoot: URL,
        sizes: [String: Int64]
    ) -> [DiskItem] {
        items.map { item in
            var copy = item
            if let size = PathUtils.directorySize(in: sizes, itemURL: item.url, scanRoot: scanRoot), size > 0 {
                copy.size = size
                if copy.isDirectory { copy.isScanning = false }
            }
            return copy
        }
    }

    private static func parentDirectory(of url: URL, within scanRoot: URL) -> URL? {
        let current = PathUtils.resolved(url)
        let root = PathUtils.resolved(scanRoot)
        let parent = PathUtils.resolved(current.deletingLastPathComponent())
        if parent.path == current.path { return nil }
        guard PathUtils.isWithinVolume(parent, scanRoot: root) else { return nil }
        return parent
    }

    private static func isoTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}
