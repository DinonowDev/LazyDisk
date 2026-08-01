import XCTest
import LazyDiskCore

final class DuplicateGroupTests: XCTestCase {
    func testTotalWastedExcludesOneCopy() {
        let group = DuplicateGroup(
            hash: "abc",
            files: [
                DuplicateFile(url: URL(fileURLWithPath: "/a"), size: 100),
                DuplicateFile(url: URL(fileURLWithPath: "/b"), size: 100),
                DuplicateFile(url: URL(fileURLWithPath: "/c"), size: 100),
            ]
        )
        XCTAssertEqual(group.totalWasted, 200)
    }

    func testSingleFileNoWaste() {
        let group = DuplicateGroup(
            hash: "abc",
            files: [DuplicateFile(url: URL(fileURLWithPath: "/a"), size: 100)]
        )
        XCTAssertEqual(group.totalWasted, 0)
    }
}
