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

    func testImmediateChildSizesUsesResolvedPathsForSymlinkedChildren() throws {
        let dataVolume = tempRoot.appendingPathComponent("data-volume", isDirectory: true)
        let users = dataVolume.appendingPathComponent("Users", isDirectory: true)
        let usersLink = tempRoot.appendingPathComponent("Users", isDirectory: true)
        try FileManager.default.createDirectory(at: users, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: usersLink, withDestinationURL: users)
        try Data(count: 18_000).write(to: users.appendingPathComponent("profile.db"))

        let listedChild = PathUtils.resolved(usersLink)
        let items = [DiskItem(url: listedChild, isDirectory: true, isScanning: true)]

        let walk = DirectorySizeWalker.immediateChildSizes(at: dataVolume)
        let updated = DirectorySizeWalker.applySizes(to: items, walkResult: walk)

        XCTAssertGreaterThan(walk.childSizesByPath[listedChild.path] ?? 0, 10_000)
        XCTAssertEqual(updated[0].size, walk.childSizesByPath[listedChild.path])
        XCTAssertFalse(updated[0].isScanning)
    }

    func testVolumeRootConfigurationIncludesHiddenDirectories() throws {
        let hidden = tempRoot.appendingPathComponent(".private", isDirectory: true)
        let visible = tempRoot.appendingPathComponent("Library", isDirectory: true)
        try FileManager.default.createDirectory(at: hidden, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: visible, withIntermediateDirectories: true)
        try Data(count: 30_000).write(to: hidden.appendingPathComponent("secret.bin"))
        try Data(count: 10_000).write(to: visible.appendingPathComponent("prefs.plist"))

        let defaultWalk = DirectorySizeWalker.immediateChildSizes(
            at: tempRoot,
            configuration: .default
        )
        let volumeWalk = DirectorySizeWalker.immediateChildSizes(
            at: tempRoot,
            configuration: .volumeRoot
        )

        XCTAssertEqual(defaultWalk.childSizesByPath[hidden.path] ?? 0, 0)
        XCTAssertGreaterThan(volumeWalk.childSizesByPath[hidden.path] ?? 0, 20_000)
        XCTAssertGreaterThan(volumeWalk.childSizesByPath[visible.path] ?? 0, 5_000)
    }

    func testPackageDirectoryIsSizedAsUnit() throws {
        let apps = tempRoot.appendingPathComponent("Applications", isDirectory: true)
        let bundle = apps.appendingPathComponent("LazyDisk.app", isDirectory: true)
        let contents = bundle.appendingPathComponent("Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try Data(count: 40_000).write(to: contents.appendingPathComponent("LazyDisk"))
        try Data(count: 8_000).write(to: bundle.appendingPathComponent("Contents/Info.plist"))

        let result = DirectorySizeWalker.immediateChildSizes(at: tempRoot, configuration: .volumeRoot)

        XCTAssertGreaterThan(result.childSizesByPath[apps.path] ?? 0, 40_000)
    }

    func testNativeScannerIsAvailableAndProducesSizes() throws {
        XCTAssertTrue(NativeDirectoryScanner.isAvailable)

        let apps = tempRoot.appendingPathComponent("Applications", isDirectory: true)
        let users = tempRoot.appendingPathComponent("Users", isDirectory: true)
        try FileManager.default.createDirectory(at: apps, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: users, withIntermediateDirectories: true)
        try Data(count: 15_000).write(to: users.appendingPathComponent("data.bin"))
        try Data(count: 9_000).write(to: apps.appendingPathComponent("app.bin"))

        let result = DirectorySizeWalker.immediateChildSizes(
            at: tempRoot,
            configuration: .volumeRoot
        )

        XCTAssertGreaterThan(result.totalSize, 20_000)
        XCTAssertGreaterThan(result.childSizesByPath[users.path] ?? 0, 10_000)
        XCTAssertGreaterThan(result.childSizesByPath[apps.path] ?? 0, 5_000)
    }

    func testVolumeUsageResidualMathSubtractsPurgeable() {
        let used: Int64 = 200_000_000_000
        let scanned: Int64 = 110_000_000_000
        let purgeable: Int64 = 80_000_000_000
        let residual = used - scanned - purgeable
        XCTAssertEqual(residual, 10_000_000_000)
    }
}
