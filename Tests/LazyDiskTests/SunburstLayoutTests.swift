import XCTest
import LazyDiskCore

final class SunburstLayoutTests: XCTestCase {
    func testBuildsNestedSegments() {
        let users = DiskItem(
            url: URL(fileURLWithPath: "/Users"),
            size: 100,
            isDirectory: true
        )
        let apps = DiskItem(
            url: URL(fileURLWithPath: "/Applications"),
            size: 50,
            isDirectory: true
        )
        let child = DiskItem(
            url: URL(fileURLWithPath: "/Users/me"),
            size: 40,
            isDirectory: true
        )

        let segments = SunburstLayoutEngine.build(
            items: [users, apps],
            totalSize: 150,
            childrenByParentID: [users.id: [child]]
        )

        XCTAssertFalse(segments.isEmpty)
        XCTAssertTrue(segments.contains { $0.depth == 0 && $0.item.id == users.id })
        XCTAssertTrue(segments.contains { $0.depth == 1 && $0.item.id == child.id })
        XCTAssertGreaterThan(SunburstLayoutEngine.maxDepth(in: segments), 0)
    }

    func testChildSegmentsStayWithinParentAngle() {
        let parent = DiskItem(
            url: URL(fileURLWithPath: "/A"),
            size: 100,
            isDirectory: true
        )
        let child = DiskItem(
            url: URL(fileURLWithPath: "/A/child"),
            size: 30,
            isDirectory: false
        )
        let segments = SunburstLayoutEngine.build(
            items: [parent],
            totalSize: 100,
            childrenByParentID: [parent.id: [child]]
        )
        guard let parentSeg = segments.first(where: { $0.depth == 0 }),
              let childSeg = segments.first(where: { $0.depth == 1 }) else {
            return XCTFail("Missing segments")
        }
        XCTAssertGreaterThanOrEqual(childSeg.startAngle, parentSeg.startAngle)
        XCTAssertLessThanOrEqual(childSeg.endAngle, parentSeg.endAngle)
    }
}
