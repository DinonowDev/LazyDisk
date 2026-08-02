import Foundation

/// Upfront workload estimate for chart BFS (upper bound using branching factor).
public enum ChartWorkloadEstimator {
    public static func estimateTotalFolders(
        rootFolderCount: Int,
        maxDepth: Int,
        maxChildrenPerNode: Int
    ) -> Int {
        let roots = max(rootFolderCount, 0)
        let depth = max(maxDepth, 0)
        let branching = max(maxChildrenPerNode, 1)

        guard roots > 0 else { return 1 }
        guard depth > 0 else { return roots }

        if branching == 1 {
            return roots * (depth + 1)
        }

        let levels = depth + 1
        let numerator = roots * (Int(pow(Double(branching), Double(levels))) - 1)
        let estimate = numerator / (branching - 1)
        return max(roots, estimate)
    }
}
