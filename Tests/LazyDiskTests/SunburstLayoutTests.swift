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
            childrenByParentPath: [PathUtils.resolved(users.url).path: [child]]
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
            childrenByParentPath: [PathUtils.resolved(parent.url).path: [child]]
        )
        guard let parentSeg = segments.first(where: { $0.depth == 0 }),
              let childSeg = segments.first(where: { $0.depth == 1 }) else {
            return XCTFail("Missing segments")
        }
        XCTAssertGreaterThanOrEqual(childSeg.startAngle, parentSeg.startAngle)
        XCTAssertLessThanOrEqual(childSeg.endAngle, parentSeg.endAngle)
    }

    func testLargerSiblingHasGreaterRadialExtent() {
        let large = DiskItem(url: URL(fileURLWithPath: "/Large"), size: 80, isDirectory: true)
        let small = DiskItem(url: URL(fileURLWithPath: "/Small"), size: 20, isDirectory: true)
        let segments = SunburstLayoutEngine.build(
            items: [large, small],
            totalSize: 100,
            childrenByParentPath: [:]
        )
        guard let largeSeg = segments.first(where: { $0.item.id == large.id }),
              let smallSeg = segments.first(where: { $0.item.id == small.id }) else {
            return XCTFail("Missing segments")
        }
        XCTAssertGreaterThan(largeSeg.outerRadiusRatio, smallSeg.outerRadiusRatio)
        XCTAssertGreaterThan(largeSeg.spanAngle, smallSeg.spanAngle)
    }

    func testChildStartsAtParentOuterRadius() {
        let parent = DiskItem(url: URL(fileURLWithPath: "/A"), size: 100, isDirectory: true)
        let child = DiskItem(url: URL(fileURLWithPath: "/A/child"), size: 40, isDirectory: false)
        let segments = SunburstLayoutEngine.build(
            items: [parent],
            totalSize: 100,
            childrenByParentPath: [PathUtils.resolved(parent.url).path: [child]]
        )
        guard let parentSeg = segments.first(where: { $0.depth == 0 }),
              let childSeg = segments.first(where: { $0.depth == 1 }) else {
            return XCTFail("Missing segments")
        }
        XCTAssertGreaterThan(childSeg.innerRadiusRatio, parentSeg.outerRadiusRatio)
    }

    func testChildrenInheritParentHue() {
        let parent = DiskItem(url: URL(fileURLWithPath: "/A"), size: 100, isDirectory: true)
        let childA = DiskItem(url: URL(fileURLWithPath: "/A/a"), size: 30, isDirectory: false)
        let childB = DiskItem(url: URL(fileURLWithPath: "/A/b"), size: 20, isDirectory: false)
        let segments = SunburstLayoutEngine.build(
            items: [parent],
            totalSize: 100,
            childrenByParentPath: [PathUtils.resolved(parent.url).path: [childA, childB]]
        )
        guard let parentSeg = segments.first(where: { $0.depth == 0 }) else {
            return XCTFail("Missing parent segment")
        }
        let children = segments.filter { $0.depth == 1 }
        guard children.count == 2 else {
            return XCTFail("Expected 2 child segments, got \(children.count)")
        }
        XCTAssertEqual(parentSeg.hue, children[0].hue, accuracy: 0.001)
        XCTAssertEqual(parentSeg.hue, children[1].hue, accuracy: 0.001)
    }

    func testDeeperBranchesAreLighter() {
        let parent = DiskItem(url: URL(fileURLWithPath: "/A"), size: 100, isDirectory: true)
        let child = DiskItem(url: URL(fileURLWithPath: "/A/child"), size: 40, isDirectory: true)
        let grandchild = DiskItem(url: URL(fileURLWithPath: "/A/child/x"), size: 10, isDirectory: false)
        let parentPath = PathUtils.resolved(parent.url).path
        let childPath = PathUtils.resolved(child.url).path
        let segments = SunburstLayoutEngine.build(
            items: [parent],
            totalSize: 100,
            childrenByParentPath: [
                parentPath: [child],
                childPath: [grandchild]
            ]
        )
        guard let parentSeg = segments.first(where: { $0.depth == 0 }),
              let childSeg = segments.first(where: { $0.depth == 1 }),
              let grandchildSeg = segments.first(where: { $0.depth == 2 }) else {
            return XCTFail("Missing segments")
        }
        XCTAssertGreaterThan(childSeg.brightness, parentSeg.brightness)
        XCTAssertGreaterThan(grandchildSeg.brightness, childSeg.brightness)
        XCTAssertLessThan(childSeg.saturation, parentSeg.saturation)
    }
}
