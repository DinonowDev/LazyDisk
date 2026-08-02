import Foundation
import XCTest
@testable import LazyDiskCore

final class DirectorySizeWalkerTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LazyDiskWalker-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }

    func testImmediateChildSizesBucketsNestedFiles() throws {
        let apps = tempRoot.appendingPathComponent("Applications", isDirectory: true)
        let users = tempRoot.appendingPathComponent("Users", isDirectory: true)
        let nested = users.appendingPathComponent("amir/Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: apps, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        try Data(count: 12_000).write(to: apps.appendingPathComponent("App.pkg"))
        try Data(count: 24_000).write(to: nested.appendingPathComponent("notes.txt"))
        try Data(count: 6_000).write(to: tempRoot.appendingPathComponent("readme.txt"))

        let result = DirectorySizeWalker.immediateChildSizes(at: tempRoot)

        XCTAssertGreaterThan(result.childSizesByPath[apps.path] ?? 0, 10_000)
        XCTAssertGreaterThan(result.childSizesByPath[users.path] ?? 0, 20_000)
        XCTAssertGreaterThan(result.childSizesByPath[tempRoot.appendingPathComponent("readme.txt").path] ?? 0, 5_000)
        XCTAssertGreaterThan(result.totalSize, 40_000)
        XCTAssertGreaterThan(
            result.childSizesByPath[users.path] ?? 0,
            result.childSizesByPath[apps.path] ?? 0
        )
    }

    func testApplySizesUpdatesDirectoriesOnly() {
        let root = URL(fileURLWithPath: "/tmp/root", isDirectory: true)
        let child = URL(fileURLWithPath: "/tmp/root/child", isDirectory: true)
        let file = URL(fileURLWithPath: "/tmp/root/readme.txt")

        let items = [
            DiskItem(url: child, isDirectory: true, isScanning: true),
            DiskItem(url: file, size: 42, isDirectory: false)
        ]

        let walk = DirectorySizeWalker.WalkResult(
            childSizesByPath: [child.path: 999],
            totalSize: 1041
        )

        let updated = DirectorySizeWalker.applySizes(to: items, walkResult: walk)

        XCTAssertEqual(updated[0].size, 999)
        XCTAssertFalse(updated[0].isScanning)
        XCTAssertEqual(updated[1].size, 42)
    }
}
