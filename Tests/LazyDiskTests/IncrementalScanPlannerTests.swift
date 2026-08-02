import Foundation
import XCTest
@testable import LazyDiskCore

final class IncrementalScanPlannerTests: XCTestCase {
    func testFullRescanWhenNoCache() {
        let dir = URL(fileURLWithPath: "/tmp/projects", isDirectory: true)
        let listed = [
            DiskItem(url: dir, isDirectory: true, isScanning: true)
        ]

        let plan = IncrementalScanPlanner.plan(listed: listed, cached: nil)

        XCTAssertEqual(plan.directoriesToRescan.map(\.path), [dir.path])
        XCTAssertTrue(plan.pathsToInvalidate.isEmpty)
        XCTAssertTrue(plan.mergedEntries[0].isScanning)
    }

    func testPreservesUnchangedDirectorySizes() {
        let dir = URL(fileURLWithPath: "/tmp/stable", isDirectory: true)
        let unchangedDate = Date(timeIntervalSince1970: 1_700_000_000)

        let listed = [
            DiskItem(
                url: dir,
                isDirectory: true,
                isScanning: true,
                modifiedDate: unchangedDate
            )
        ]
        let cached = [
            DiskItem(
                url: dir,
                size: 42_000,
                isDirectory: true,
                isScanning: false,
                modifiedDate: unchangedDate
            )
        ]

        let plan = IncrementalScanPlanner.plan(listed: listed, cached: cached)

        XCTAssertTrue(plan.directoriesToRescan.isEmpty)
        XCTAssertEqual(plan.mergedEntries[0].size, 42_000)
        XCTAssertFalse(plan.mergedEntries[0].isScanning)
    }

    func testRescansChangedDirectoryAndInvalidatesRemovedPaths() {
        let kept = URL(fileURLWithPath: "/tmp/kept", isDirectory: true)
        let changed = URL(fileURLWithPath: "/tmp/changed", isDirectory: true)
        let removed = URL(fileURLWithPath: "/tmp/removed", isDirectory: true)
        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newDate = Date(timeIntervalSince1970: 1_800_000_000)

        let listed = [
            DiskItem(url: kept, isDirectory: true, modifiedDate: oldDate),
            DiskItem(url: changed, isDirectory: true, modifiedDate: newDate)
        ]
        let cached = [
            DiskItem(url: kept, size: 1_000, isDirectory: true, modifiedDate: oldDate),
            DiskItem(url: changed, size: 2_000, isDirectory: true, modifiedDate: oldDate),
            DiskItem(url: removed, size: 3_000, isDirectory: true, modifiedDate: oldDate)
        ]

        let plan = IncrementalScanPlanner.plan(listed: listed, cached: cached)

        XCTAssertEqual(plan.directoriesToRescan.map(\.path), [changed.path])
        XCTAssertTrue(plan.pathsToInvalidate.contains(removed.path))
        XCTAssertTrue(plan.pathsToInvalidate.contains(changed.path))
        XCTAssertEqual(plan.mergedEntries.first(where: { $0.url == kept })?.size, 1_000)
        XCTAssertTrue(plan.mergedEntries.first(where: { $0.url == changed })?.isScanning == true)
    }

    func testRescansNewDirectory() {
        let existing = URL(fileURLWithPath: "/tmp/existing", isDirectory: true)
        let added = URL(fileURLWithPath: "/tmp/added", isDirectory: true)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let listed = [
            DiskItem(url: existing, isDirectory: true, modifiedDate: date),
            DiskItem(url: added, isDirectory: true, modifiedDate: date)
        ]
        let cached = [
            DiskItem(url: existing, size: 500, isDirectory: true, modifiedDate: date)
        ]

        let plan = IncrementalScanPlanner.plan(listed: listed, cached: cached)

        XCTAssertEqual(plan.directoriesToRescan.map(\.path), [added.path])
        XCTAssertEqual(plan.mergedEntries.first(where: { $0.url == existing })?.size, 500)
    }

    func testRescansDirectoryWithZeroCachedSize() {
        let dir = URL(fileURLWithPath: "/tmp/unsized", isDirectory: true)
        let unchangedDate = Date(timeIntervalSince1970: 1_700_000_000)

        let listed = [
            DiskItem(
                url: dir,
                isDirectory: true,
                isScanning: true,
                modifiedDate: unchangedDate
            )
        ]
        let cached = [
            DiskItem(
                url: dir,
                size: 0,
                isDirectory: true,
                isScanning: false,
                modifiedDate: unchangedDate
            )
        ]

        let plan = IncrementalScanPlanner.plan(listed: listed, cached: cached)

        XCTAssertEqual(plan.directoriesToRescan.map(\.path), [dir.path])
        XCTAssertTrue(plan.mergedEntries[0].isScanning)
        XCTAssertEqual(plan.mergedEntries[0].size, 0)
    }
}
