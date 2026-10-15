import LazyDiskCore
import XCTest

final class ScanCancellationFlagTests: XCTestCase {
    func testCancelFlagVisibleFromAnotherThread() {
        let flag = ScanCancellationFlag()
        let handler = flag.shouldCancelHandler()
        XCTAssertFalse(handler())

        DispatchQueue.global().async {
            flag.cancel()
        }
        var sawCancelled = false
        for _ in 0..<50 where !sawCancelled {
            sawCancelled = handler()
            if !sawCancelled {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        XCTAssertTrue(sawCancelled)
    }
}
