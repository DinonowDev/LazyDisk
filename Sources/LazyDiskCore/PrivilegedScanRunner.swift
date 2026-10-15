import Foundation

public struct PrivilegedScanProgressUpdate: Sendable {
    public let filesScanned: Int64
    public let totalSize: Int64

    public init(filesScanned: Int64, totalSize: Int64) {
        self.filesScanned = filesScanned
        self.totalSize = totalSize
    }
}

public enum PrivilegedScanRunner {
    public static func scanTotalSize(atPath path: String) -> Int64? {
        try? performScan(atPath: path).totalSize
    }

    public static func performScan(
        atPath path: String,
        configuration: PrivilegedScanConfiguration = PrivilegedScanConfiguration(),
        progress: (@Sendable (PrivilegedScanProgressUpdate) -> Void)? = nil,
        shouldCancel: (@Sendable () -> Bool)? = nil
    ) throws -> PrivilegedScanResult {
        let root = URL(fileURLWithPath: path, isDirectory: true)
        var walkConfig = DirectorySizeWalker.Configuration.volumeRoot
        walkConfig.parallelism = configuration.maxConcurrentTaskCount
        walkConfig.partialUpdateInterval = 32
        walkConfig.usePhysicalSize = configuration.supportsPhysicalSize

        let onPartial: (@Sendable (DirectorySizeWalker.WalkResult) -> Void)?
        if let progress {
            onPartial = { result in
                progress(
                    PrivilegedScanProgressUpdate(
                        filesScanned: Int64(result.filesScanned),
                        totalSize: result.totalSize
                    )
                )
            }
        } else {
            onPartial = nil
        }

        let walk = DirectorySizeWalker.immediateChildSizes(
            at: PathUtils.resolved(root),
            configuration: walkConfig,
            shouldCancel: shouldCancel,
            onPartial: onPartial
        )

        let metrics = walk.scanMetrics
        return PrivilegedScanResult(
            totalSize: walk.totalSize,
            filesScanned: Int64(walk.filesScanned),
            cloneDuplicateFiles: Int64(metrics?.cloneGroupsMerged ?? 0),
            scanMetrics: metrics
        )
    }
}

public enum PrivilegedScanRunnerError: Error {
    case scanFailed(Int32)
}
