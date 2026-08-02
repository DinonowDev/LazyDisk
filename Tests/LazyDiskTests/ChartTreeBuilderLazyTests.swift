import Foundation
import XCTest
@testable import LazyDiskCore

final class ChartLazyScanPolicyTests: XCTestCase {
    func testThresholdUsesFloorForSmallParents() {
        let threshold = ChartLazyScanPolicy.deepScanThreshold(parentTotalSize: 1_000_000)
        XCTAssertEqual(threshold, ChartLazyScanPolicy.minimumThresholdBytes)
    }

    func testThresholdUsesRelativeValueForLargeParents() {
        let parentSize: Int64 = 100 * 1024 * 1024 * 1024
        let threshold = ChartLazyScanPolicy.deepScanThreshold(parentTotalSize: parentSize)
        XCTAssertGreaterThan(threshold, ChartLazyScanPolicy.minimumThresholdBytes)
        XCTAssertLessThanOrEqual(threshold, ChartLazyScanPolicy.maximumThresholdBytes)
    }

    func testThresholdCapsAtMaximum() {
        let parentSize: Int64 = 10 * 1024 * 1024 * 1024 * 1024
        let threshold = ChartLazyScanPolicy.deepScanThreshold(parentTotalSize: parentSize)
        XCTAssertEqual(threshold, ChartLazyScanPolicy.maximumThresholdBytes)
    }
}

final class ChartSubtreeOtherTests: XCTestCase {
    func testVirtualPathRoundTrip() {
        let parent = "/Volumes/Data/Projects"
        let virtual = ChartSubtreeOther.virtualPath(under: parent)
        XCTAssertTrue(ChartSubtreeOther.isVirtualOther(virtual))
        XCTAssertEqual(ChartSubtreeOther.parentPath(ofVirtualOther: virtual), parent)
    }

    func testStableIDIsDeterministic() {
        let parent = "/Volumes/Data/Projects"
        XCTAssertEqual(
            ChartSubtreeOther.stableID(parentPath: parent),
            ChartSubtreeOther.stableID(parentPath: parent)
        )
        XCTAssertNotEqual(
            ChartSubtreeOther.stableID(parentPath: parent),
            ChartSubtreeOther.stableID(parentPath: "/Volumes/Data/Other")
        )
    }
}

final class ChartTreeBuilderLazyTests: XCTestCase {
    func testSkipsEnumeratingSmallRootChildren() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let largeDir = root.appendingPathComponent("Large", isDirectory: true)
        let smallDir = root.appendingPathComponent("Small", isDirectory: true)
        try FileManager.default.createDirectory(at: largeDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: smallDir, withIntermediateDirectories: true)

        let largeFile = largeDir.appendingPathComponent("big.bin")
        let smallFile = smallDir.appendingPathComponent("tiny.bin")
        try Data(count: 512).write(to: largeFile)
        try Data(count: 64).write(to: smallFile)

        let largeSize = Int64(512)
        let smallSize = Int64(64)
        let entries = [
            DiskItem(url: largeDir, size: largeSize, isDirectory: true),
            DiskItem(url: smallDir, size: smallSize, isDirectory: true)
        ]

        let threshold = smallSize + 1
        let result = ChartTreeBuilder.build(
            at: root,
            listedEntries: entries,
            options: ChartTreeBuilder.BuildOptions(
                maxDepth: 2,
                fileSizeThreshold: threshold
            )
        )

        XCTAssertEqual(result.filesScanned, 1)
        XCTAssertGreaterThanOrEqual(result.totalSize, largeSize + smallSize)

        let otherPath = ChartSubtreeOther.virtualPath(under: root.path)
        XCTAssertEqual(result.statsByPath[otherPath]?.size, smallSize)

        let map = ChartTreeBuilder.childMap(
            from: result,
            root: root,
            listedEntries: entries,
            maxChildrenPerNode: 8
        )
        let rootChildren = map[root.path] ?? []
        XCTAssertTrue(rootChildren.contains(where: { ChartSubtreeOther.isVirtualOther($0.url.path) }))
        XCTAssertFalse(rootChildren.contains(where: { $0.url.lastPathComponent == "Small" }))
    }

    func testExpandedRootEnumeratesDeferredChildren() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let smallDir = root.appendingPathComponent("Small", isDirectory: true)
        try FileManager.default.createDirectory(at: smallDir, withIntermediateDirectories: true)
        let smallFile = smallDir.appendingPathComponent("tiny.bin")
        try Data(count: 128).write(to: smallFile)

        let smallSize = Int64(128)
        let entries = [
            DiskItem(url: smallDir, size: smallSize, isDirectory: true)
        ]

        let threshold = smallSize + 1
        let result = ChartTreeBuilder.build(
            at: root,
            listedEntries: entries,
            options: ChartTreeBuilder.BuildOptions(
                maxDepth: 2,
                expandedParents: [root.path],
                fileSizeThreshold: threshold
            )
        )

        XCTAssertEqual(result.filesScanned, 1)
        XCTAssertTrue(result.deferredByParent[root.path, default: []].isEmpty)
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lazydisk-chart-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
