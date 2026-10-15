import LazyDiskCore
import XCTest

final class RestrictedScanCoordinatorTests: XCTestCase {
    func testClearAndRegister() async {
        let coordinator = RestrictedScanCoordinator.shared
        await coordinator.clear()
        await coordinator.register([
            RestrictedScanEvent(path: "/tmp/a", errorCode: 13)
        ])
        let events = await coordinator.allEvents()
        XCTAssertEqual(events.count, 1)
        await coordinator.remove(paths: ["/tmp/a"])
        let remaining = await coordinator.allEvents()
        XCTAssertTrue(remaining.isEmpty)
    }
}
