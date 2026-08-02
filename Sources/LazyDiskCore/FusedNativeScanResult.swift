import Foundation
import LazyDiskFS

/// Combined sizing walk + chart tree from a single native getattrlistbulk pass.
public struct FusedNativeScanResult: Sendable {
    public let sizingWalk: DirectorySizeWalker.WalkResult
    public let chartResult: ChartTreeBuilder.BuildResult

    public init(sizingWalk: DirectorySizeWalker.WalkResult, chartResult: ChartTreeBuilder.BuildResult) {
        self.sizingWalk = sizingWalk
        self.chartResult = chartResult
    }
}
