import Foundation
import XCTest
@testable import LazyDiskCore

final class ChartWorkloadEstimatorTests: XCTestCase {
    func testEstimateGrowsWithDepthAndBranching() {
        let shallow = ChartWorkloadEstimator.estimateTotalFolders(
            rootFolderCount: 4,
            maxDepth: 1,
            maxChildrenPerNode: 8
        )
        let deep = ChartWorkloadEstimator.estimateTotalFolders(
            rootFolderCount: 4,
            maxDepth: 3,
            maxChildrenPerNode: 8
        )

        XCTAssertGreaterThan(deep, shallow)
        XCTAssertGreaterThanOrEqual(shallow, 4)
    }
}

final class ScanProgressMathTests: XCTestCase {
    func testVolumeSizingUsesFileWalkContribution() {
        let early = ScanProgressMath.volumeSizingFraction(
            directoriesResolved: 1,
            directoryTotal: 8,
            filesScanned: 50
        )
        let later = ScanProgressMath.volumeSizingFraction(
            directoriesResolved: 1,
            directoryTotal: 8,
            filesScanned: 600
        )

        XCTAssertGreaterThan(later, early)
    }

    func testVolumeScanDisplayFractionIsMonotonic() {
        let first = ScanProgressMath.volumeScanDisplayFraction(
            phaseBase: 0.1,
            sizingFraction: 0.2,
            published: 0.1
        )
        let second = ScanProgressMath.volumeScanDisplayFraction(
            phaseBase: 0.1,
            sizingFraction: 0.15,
            published: first
        )

        XCTAssertGreaterThanOrEqual(second, first)
    }
}
