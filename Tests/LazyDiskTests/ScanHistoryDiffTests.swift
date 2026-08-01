import XCTest
import LazyDiskCore

final class ScanHistoryDiffTests: XCTestCase {
    func testComputeDiffDetectsAddedRemovedChanged() {
        let previous = ScanSnapshot(
            volumeID: "disk1",
            totalUsed: 1000,
            totalFiles: 3,
            entries: [
                SnapshotEntry(path: "/a", size: 100, isDirectory: true),
                SnapshotEntry(path: "/b", size: 200, isDirectory: true),
                SnapshotEntry(path: "/c", size: 300, isDirectory: false),
            ]
        )

        let current: [DiskItem] = [
            DiskItem(url: URL(fileURLWithPath: "/a"), size: 150, isDirectory: true),
            DiskItem(url: URL(fileURLWithPath: "/d"), size: 400, isDirectory: true),
        ]

        let diff = ScanHistoryDiff.computeDiff(current: current, previous: previous)

        XCTAssertEqual(diff.addedBytes, 400)
        XCTAssertEqual(diff.removedBytes, 500) // b=200 + c=300
        XCTAssertEqual(diff.changedPaths.count, 1)
        XCTAssertEqual(diff.changedPaths.first?.path, "/a")
        XCTAssertEqual(diff.changedPaths.first?.delta, 50)
        XCTAssertEqual(diff.addedPaths.count, 1)
        XCTAssertEqual(diff.removedPaths.count, 2)
    }

    func testComputeDiffEmptyCurrent() {
        let previous = ScanSnapshot(
            volumeID: "disk1",
            totalUsed: 500,
            totalFiles: 1,
            entries: [SnapshotEntry(path: "/only", size: 500, isDirectory: true)]
        )
        let diff = ScanHistoryDiff.computeDiff(current: [], previous: previous)
        XCTAssertEqual(diff.removedBytes, 500)
        XCTAssertEqual(diff.addedBytes, 0)
    }
}
