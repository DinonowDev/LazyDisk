import XCTest
import LazyDiskCore

final class ExternalOpenResolverTests: XCTestCase {
    func testAnalyzeTargetUsesDirectoryAsIs() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("lazydisk-test-dir", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let target = ExternalOpenResolver.analyzeTarget(for: dir)
        XCTAssertEqual(PathUtils.resolved(target).path, PathUtils.resolved(dir).path)
    }

    func testAnalyzeTargetUsesParentForFile() {
        let file = URL(fileURLWithPath: "/Users/me/Projects/app.zip")
        let target = ExternalOpenResolver.analyzeTarget(for: file)
        XCTAssertEqual(target.path, "/Users/me/Projects")
    }

    func testContainingVolumeID() {
        let volumes = [
            ExternalOpenResolver.VolumeRoot(id: "root", scanRoot: URL(fileURLWithPath: "/", isDirectory: true)),
            ExternalOpenResolver.VolumeRoot(
                id: "data",
                scanRoot: URL(fileURLWithPath: "/Volumes/Data", isDirectory: true)
            ),
        ]
        let target = URL(fileURLWithPath: "/Volumes/Data/Users/foo", isDirectory: true)
        XCTAssertEqual(ExternalOpenResolver.containingVolumeID(for: target, volumes: volumes), "data")
    }

    func testCustomSchemeOpenQuery() {
        let url = URL(string: "lazydisk://open?path=/Users/me/Downloads")!
        let urls = ExternalOpenResolver.urls(from: url)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls[0].path, "/Users/me/Downloads")
    }

    func testCustomSchemeAnalyzePath() {
        let url = URL(string: "lazydisk://analyze/Users/me/Desktop")!
        let urls = ExternalOpenResolver.urls(from: url)
        XCTAssertEqual(urls.first?.path, "/Users/me/Desktop")
    }
}
