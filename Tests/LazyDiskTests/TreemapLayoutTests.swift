// Treemap layout tests temporarily disabled while the chart style is commented out.
// Re-enable when TreemapChartView is wired back into ContentView.

/*
import XCTest
import CoreGraphics
import LazyDiskCore

final class TreemapLayoutTests: XCTestCase {
    func testLayoutProducesRectPerItem() {
        let items = [
            DiskItem(url: URL(fileURLWithPath: "/A"), size: 60, isDirectory: true),
            DiskItem(url: URL(fileURLWithPath: "/B"), size: 30, isDirectory: true),
            DiskItem(url: URL(fileURLWithPath: "/C"), size: 10, isDirectory: false),
        ]
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let rects = TreemapLayoutEngine.layout(items: items, in: bounds, padding: 2)

        XCTAssertEqual(rects.count, 3)
        for tile in rects {
            XCTAssertGreaterThan(tile.rect.width, 0)
            XCTAssertGreaterThan(tile.rect.height, 0)
            XCTAssertTrue(bounds.contains(tile.rect) || bounds.intersects(tile.rect))
        }
    }

    func testLayoutHandlesEmptyInput() {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
        XCTAssertTrue(TreemapLayoutEngine.layout(items: [], in: bounds).isEmpty)
    }

    func testLargerItemsGetLargerArea() {
        let large = DiskItem(url: URL(fileURLWithPath: "/big"), size: 900, isDirectory: true)
        let small = DiskItem(url: URL(fileURLWithPath: "/small"), size: 100, isDirectory: true)
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        let rects = TreemapLayoutEngine.layout(items: [large, small], in: bounds, padding: 0)

        guard let largeRect = rects.first(where: { $0.item.id == large.id && $0.depth == 0 }),
              let smallRect = rects.first(where: { $0.item.id == small.id && $0.depth == 0 }) else {
            return XCTFail("Missing rects")
        }

        let largeArea = largeRect.rect.width * largeRect.rect.height
        let smallArea = smallRect.rect.width * smallRect.rect.height
        XCTAssertGreaterThan(largeArea, smallArea)
    }

    func testHierarchicalLayoutAddsChildRects() {
        let parent = DiskItem(url: URL(fileURLWithPath: "/Users"), size: 100, isDirectory: true)
        let child = DiskItem(url: URL(fileURLWithPath: "/Users/me"), size: 60, isDirectory: true)
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)

        let rects = TreemapLayoutEngine.layoutHierarchical(
            items: [parent],
            childrenByParentPath: [PathUtils.resolved(parent.url).path: [child]],
            in: bounds,
            padding: 2
        )

        XCTAssertTrue(rects.contains { $0.item.id == parent.id && $0.depth == 0 })
        XCTAssertTrue(rects.contains { $0.item.id == child.id && $0.depth == 1 })
    }
}
*/
