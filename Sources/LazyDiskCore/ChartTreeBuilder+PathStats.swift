import Foundation
import LazyDiskFS

extension ChartTreeBuilder {
    /// Builds chart metadata from a native volume tree export, clipped to `maxChartDepth`.
    public static func buildResult(
        scanRoot: URL,
        listedEntries: [DiskItem],
        pathStats: [String: NodeStats],
        totalSize: Int64,
        filesScanned: Int,
        maxChartDepth: Int,
        scanMetrics: NativeScanMetrics? = nil
    ) -> BuildResult {
        let rootPath = PathUtils.resolved(scanRoot).path
        var clipped: [String: NodeStats] = [:]

        for (path, stats) in pathStats where stats.size > 0 {
            guard path == rootPath || path.hasPrefix(rootPath + "/") else { continue }
            let depth = PathUtils.relativeComponents(from: URL(fileURLWithPath: path), scanRoot: scanRoot).count
            guard depth <= maxChartDepth else { continue }
            clipped[path] = stats
        }

        for entry in listedEntries where !entry.isVirtual {
            let path = PathUtils.resolved(entry.url).path
            if clipped[path] != nil { continue }
            if entry.isDirectory {
                let size = PathUtils.directorySize(
                    in: pathStats.mapValues(\.size),
                    itemURL: entry.url,
                    scanRoot: scanRoot
                ) ?? entry.size
                if size > 0 {
                    clipped[path] = NodeStats(size: size, isDirectory: true)
                }
            } else if entry.size > 0 {
                clipped[path] = NodeStats(size: entry.size, directFileCount: 1, isDirectory: false)
            }
        }

        return BuildResult(
            statsByPath: clipped,
            totalSize: totalSize,
            filesScanned: filesScanned,
            deferredByParent: [:],
            scanMetrics: scanMetrics
        )
    }

    public static func nodeStatsMap(from pathStats: UnsafePointer<ldfs_path_stat>, count: Int) -> [String: NodeStats] {
        var map: [String: NodeStats] = [:]
        guard count > 0 else { return map }
        for index in 0..<count {
            let entry = pathStats[index]
            guard let pathCString = entry.path else { continue }
            let path = String(cString: pathCString)
            guard entry.size > 0 else { continue }
            map[path] = NodeStats(
                size: entry.size,
                directFileCount: Int(entry.file_count),
                isDirectory: entry.is_directory != 0
            )
        }
        return map
    }
}
