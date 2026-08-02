import Foundation
import XCTest
@testable import LazyDiskCore

final class ScanDepthPlannerTests: XCTestCase {
    func testDepthRelativeToScanRoot() {
        let root = URL(fileURLWithPath: "/Volumes/Data", isDirectory: true)
        let users = URL(fileURLWithPath: "/Volumes/Data/Users", isDirectory: true)
        let home = URL(fileURLWithPath: "/Volumes/Data/Users/amir", isDirectory: true)

        XCTAssertEqual(ScanDepthPlanner.depth(of: root, scanRoot: root), 0)
        XCTAssertEqual(ScanDepthPlanner.depth(of: users, scanRoot: root), 1)
        XCTAssertEqual(ScanDepthPlanner.depth(of: home, scanRoot: root), 2)
        XCTAssertNil(ScanDepthPlanner.depth(of: URL(fileURLWithPath: "/other"), scanRoot: root))
    }

    func testDirectoriesAtDepthOne() {
        let root = URL(fileURLWithPath: "/Volumes/Data", isDirectory: true)
        let users = DiskItem(
            url: URL(fileURLWithPath: "/Volumes/Data/Users", isDirectory: true),
            size: 1_000,
            isDirectory: true
        )
        let file = DiskItem(
            url: URL(fileURLWithPath: "/Volumes/Data/file.txt"),
            size: 10,
            isDirectory: false
        )

        let depthOne = ScanDepthPlanner.directories(
            atDepth: 1,
            scanRoot: root,
            rootEntries: [users, file],
            childEntries: { _ in nil }
        )

        XCTAssertEqual(depthOne.map(\.url.path), [users.url.path])
    }

    func testDirectoriesAtDepthTwoUsesChildEntries() {
        let root = URL(fileURLWithPath: "/Volumes/Data", isDirectory: true)
        let users = DiskItem(
            url: URL(fileURLWithPath: "/Volumes/Data/Users", isDirectory: true),
            size: 1_000,
            isDirectory: true
        )
        let home = DiskItem(
            url: URL(fileURLWithPath: "/Volumes/Data/Users/amir", isDirectory: true),
            size: 500,
            isDirectory: true
        )

        let depthTwo = ScanDepthPlanner.directories(
            atDepth: 2,
            scanRoot: root,
            rootEntries: [users],
            childEntries: { url in
                url.path == users.url.path ? [home] : nil
            }
        )

        XCTAssertEqual(depthTwo.map(\.url.path), [home.url.path])
    }
}
