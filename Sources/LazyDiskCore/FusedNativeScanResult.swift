import Foundation
import LazyDiskFS

/// Combined sizing walk + chart tree from a single native getattrlistbulk pass.
public struct FusedNativeScanResult: Sendable {
    public let sizingWalk: DirectorySizeWalker.WalkResult
    public let chartResult: ChartTreeBuilder.BuildResult
    /// Every directory path sized during a volume tree walk (unclipped chart depth).
    public let indexedPathSizes: [String: Int64]

    public init(
        sizingWalk: DirectorySizeWalker.WalkResult,
        chartResult: ChartTreeBuilder.BuildResult,
        indexedPathSizes: [String: Int64] = [:]
    ) {
        self.sizingWalk = sizingWalk
        self.chartResult = chartResult
        self.indexedPathSizes = indexedPathSizes
    }
}
