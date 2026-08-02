import Foundation
import XCTest
@testable import LazyDiskCore

final class ChartPrefetchPlannerTests: XCTestCase {
    func testPrioritizesChartChildrenOverSiblings() {
        let chartChild = DiskItem(
            url: URL(fileURLWithPath: "/Users/amir/Projects", isDirectory: true),
            size: 500,
            isDirectory: true
        )
        let sibling = DiskItem(
            url: URL(fileURLWithPath: "/Users/amir/Downloads", isDirectory: true),
            size: 9_000,
            isDirectory: true
        )

        let plan = ChartPrefetchPlanner.plan(
            chartMap: ["/Users/amir": [chartChild]],
            chartParents: [],
            siblings: [sibling]
        )

        XCTAssertEqual(plan.first?.url.path, chartChild.url.path)
    }

    func testDeduplicatesPaths() {
        let item = DiskItem(
            url: URL(fileURLWithPath: "/tmp/shared", isDirectory: true),
            size: 100,
            isDirectory: true
        )

        let plan = ChartPrefetchPlanner.plan(
            chartMap: ["/tmp": [item]],
            chartParents: [item],
            siblings: [item]
        )

        XCTAssertEqual(plan.count, 1)
    }
}
