import Foundation
import XCTest
@testable import LazyDiskCore

final class ChartScanProgressMathTests: XCTestCase {
    func testFileWalkFractionIncreasesSmoothly() {
        let early = ChartScanProgressMath.fileWalkFraction(filesScanned: 24)
        let mid = ChartScanProgressMath.fileWalkFraction(filesScanned: 200)
        let late = ChartScanProgressMath.fileWalkFraction(filesScanned: 800)

        XCTAssertGreaterThan(mid, early)
        XCTAssertGreaterThan(late, mid)
        XCTAssertLessThan(late, 1)
    }

    func testCombinedFractionUsesInFlightContribution() {
        let base = ChartScanProgressMath.combinedFraction(
            completedFolders: 1,
            totalFolders: 2,
            inFlightContribution: 0,
            currentDepth: 1,
            maxDepth: 4
        )
        let withInflight = ChartScanProgressMath.combinedFraction(
            completedFolders: 1,
            totalFolders: 2,
            inFlightContribution: 0.6,
            currentDepth: 1,
            maxDepth: 4
        )

        XCTAssertEqual(base, 0.5, accuracy: 0.001)
        XCTAssertGreaterThan(withInflight, base)
        XCTAssertEqual(withInflight, 0.8, accuracy: 0.001)
    }

    func testCombinedFractionDoesNotDropBelowCompletedFolders() {
        let completedOnly = ChartScanProgressMath.combinedFraction(
            completedFolders: 1,
            totalFolders: 2,
            inFlightContribution: 0,
            currentDepth: 1,
            maxDepth: 4
        )
        let withInflight = ChartScanProgressMath.combinedFraction(
            completedFolders: 1,
            totalFolders: 2,
            inFlightContribution: 0.9,
            currentDepth: 1,
            maxDepth: 4
        )

        XCTAssertGreaterThanOrEqual(withInflight, completedOnly)
    }

    func testFolderListingFractionTracksResolvedDirectories() {
        let dirA = DiskItem(url: URL(fileURLWithPath: "/tmp/a"), size: 10, isDirectory: true, isScanning: false)
        var dirB = DiskItem(
            url: URL(fileURLWithPath: "/tmp/b", isDirectory: true),
            isDirectory: true,
            isScanning: true
        )
        dirB.size = 0

        let fraction = ChartScanProgressMath.folderListingFraction(entries: [dirA, dirB])
        XCTAssertEqual(fraction, 0.5, accuracy: 0.001)
    }
}
