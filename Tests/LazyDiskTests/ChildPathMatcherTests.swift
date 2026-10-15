import XCTest
@testable import LazyDiskCore

final class ChildPathMatcherTests: XCTestCase {
    func testDataVolumePathMatchesFirmlinkListedChild() {
        let root = URL(fileURLWithPath: "/System/Volumes/Data", isDirectory: true)
        let applications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let matcher = ChildPathMatcher(root: root, children: [applications])

        let fileOnDataVolume = "/System/Volumes/Data/Applications/Xcode.app/Contents/Info.plist"
        XCTAssertEqual(
            matcher.immediateChildKey(for: fileOnDataVolume),
            PathUtils.resolved(applications).path
        )
    }

    func testDirectorySizeLookupCandidatesIncludeDataVolumeAlias() {
        let root = URL(fileURLWithPath: "/System/Volumes/Data", isDirectory: true)
        let applications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let candidates = PathUtils.directorySizeLookupCandidates(itemURL: applications, scanRoot: root)

        XCTAssertTrue(candidates.contains("/System/Volumes/Data/Applications"))
        XCTAssertTrue(candidates.contains("/Applications"))
    }

    func testDirectorySizeFindsStatsUnderDataVolumeKey() {
        let root = URL(fileURLWithPath: "/System/Volumes/Data", isDirectory: true)
        let applications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let stats: [String: Int64] = ["/System/Volumes/Data/Applications": 42]

        XCTAssertEqual(
            PathUtils.directorySize(in: stats, itemURL: applications, scanRoot: root),
            42
        )
    }
}
