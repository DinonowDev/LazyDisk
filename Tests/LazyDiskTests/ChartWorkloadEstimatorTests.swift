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

    func testVolumeSplashSizingBandUsesMajorityOfBar() {
        let floor = VolumeSplashProgressPhases.sizingFromVolumeFraction(0, published: 0)
        XCTAssertEqual(floor, VolumeSplashProgressPhases.listingUpper, accuracy: 0.000_1)

        let earlyWalk = VolumeSplashProgressPhases.sizingFromVolumeFraction(
            ScanProgressMath.volumeSizingFraction(
                directoriesResolved: 0,
                directoryTotal: 12,
                filesScanned: 2_000
            ),
            published: VolumeSplashProgressPhases.listingUpper
        )
        XCTAssertGreaterThan(earlyWalk, VolumeSplashProgressPhases.listingUpper)
        XCTAssertLessThan(earlyWalk, VolumeSplashProgressPhases.sizingUpper)
    }

    func testVolumeSplashSizingBandCapsBeforeFinalizing() {
        let full = VolumeSplashProgressPhases.sizingFromVolumeFraction(
            ChartScanProgressMath.inFlightDisplayCap,
            published: 0
        )
        XCTAssertEqual(full, VolumeSplashProgressPhases.sizingUpper, accuracy: 0.000_1)
        XCTAssertLessThan(full, VolumeSplashProgressPhases.finalizingUpper)
    }

    func testVolumeSplashPhaseOrderIsMonotonic() {
        var published = 0.0
        published = VolumeSplashProgressPhases.preparing(fraction: 1, published: published)
        published = VolumeSplashProgressPhases.listed(published: published)
        published = VolumeSplashProgressPhases.sizing(normalizedSizingFraction: 0.5, published: published)
        published = VolumeSplashProgressPhases.finalizing(subPhase: 1, published: published)
        published = VolumeSplashProgressPhases.chartPrefetch(ratio: 1, published: published)
        XCTAssertEqual(published, VolumeSplashProgressPhases.prefetchUpper, accuracy: 0.000_1)
    }
}

final class VolumeSplashReadinessTests: XCTestCase {
    func testPresentableWhenAllRootDirectoriesSized() {
        let root = URL(fileURLWithPath: "/Volumes/Test", isDirectory: true)
        let listed = [
            DiskItem(url: root.appendingPathComponent("A", isDirectory: true), size: 0, isDirectory: true),
            DiskItem(url: root.appendingPathComponent("B", isDirectory: true), size: 0, isDirectory: true),
        ]
        let chart = ChartTreeBuilder.BuildResult(
            statsByPath: [
                "/Volumes/Test/A": .init(size: 10, isDirectory: true),
                "/Volumes/Test/B": .init(size: 20, isDirectory: true),
            ],
            totalSize: 30,
            filesScanned: 100,
            deferredByParent: [:]
        )
        XCTAssertTrue(
            VolumeSplashReadiness.isPresentable(
                listedEntries: listed,
                chartResult: chart,
                scanRoot: root,
                chartMaxDepth: 4
            )
        )
    }
}
