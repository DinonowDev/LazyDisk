import XCTest
import LazyDiskCore

final class PathUtilsTests: XCTestCase {
    func testResolvedStandardizesPath() {
        let url = URL(fileURLWithPath: "/tmp/../tmp", isDirectory: true)
        let resolved = PathUtils.resolved(url)
        XCTAssertTrue(resolved.path.hasSuffix("/tmp") || resolved.path == "/tmp")
    }

    func testIsWithinVolume() {
        let root = URL(fileURLWithPath: "/Users/test", isDirectory: true)
        let child = URL(fileURLWithPath: "/Users/test/Documents", isDirectory: true)
        let outside = URL(fileURLWithPath: "/Volumes/Other", isDirectory: true)

        XCTAssertTrue(PathUtils.isWithinVolume(child, scanRoot: root))
        XCTAssertTrue(PathUtils.isWithinVolume(root, scanRoot: root))
        XCTAssertFalse(PathUtils.isWithinVolume(outside, scanRoot: root))
    }

    func testRelativeComponents() {
        let root = URL(fileURLWithPath: "/Users/me", isDirectory: true)
        let path = URL(fileURLWithPath: "/Users/me/Documents/Work", isDirectory: true)
        XCTAssertEqual(PathUtils.relativeComponents(from: path, scanRoot: root), ["Documents", "Work"])
    }

    func testRelativeComponentsAtRoot() {
        let root = URL(fileURLWithPath: "/Users/me", isDirectory: true)
        XCTAssertEqual(PathUtils.relativeComponents(from: root, scanRoot: root), [])
    }
}
