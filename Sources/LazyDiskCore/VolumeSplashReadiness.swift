import Foundation

/// When the volume splash may show an initial chart (DaisyDisk-style) before the bulk walk finishes.
public enum VolumeSplashReadiness {
    public static func isPresentable(
        listedEntries: [DiskItem],
        chartResult: ChartTreeBuilder.BuildResult,
        scanRoot: URL,
        chartMaxDepth _: Int
    ) -> Bool {
        guard chartResult.filesScanned > 0 || chartResult.totalSize > 0 else { return false }

        let directories = listedEntries.filter { $0.isDirectory && !$0.isVirtual }
        if directories.isEmpty {
            return chartResult.totalSize > 0
        }

        let sizes = chartResult.statsByPath.mapValues(\.size)
        var sizedDirectories = 0
        for entry in directories {
            let path = PathUtils.resolved(entry.url).path
            let size = chartResult.statsByPath[path]?.size
                ?? PathUtils.directorySize(in: sizes, itemURL: entry.url, scanRoot: scanRoot)
                ?? 0
            if size > 0 {
                sizedDirectories += 1
            }
        }

        if sizedDirectories == directories.count {
            return true
        }

        let minimumFiles = min(8192, max(512, chartResult.filesScanned))
        guard chartResult.filesScanned >= minimumFiles else { return false }

        let required = max(1, Int((Double(directories.count) * 0.85).rounded(.up)))
        return sizedDirectories >= required
    }

    public static func buildChartResult(
        listedEntries: [DiskItem],
        partial: ChartTreeBuilder.BuildResult,
        scanRoot: URL,
        chartMaxDepth: Int
    ) -> ChartTreeBuilder.BuildResult {
        ChartTreeBuilder.buildResult(
            scanRoot: scanRoot,
            listedEntries: listedEntries,
            pathStats: partial.statsByPath,
            totalSize: partial.totalSize,
            filesScanned: partial.filesScanned,
            maxChartDepth: chartMaxDepth,
            scanMetrics: partial.scanMetrics
        )
    }
}
