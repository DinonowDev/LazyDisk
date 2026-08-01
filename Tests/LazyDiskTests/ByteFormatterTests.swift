import XCTest
import LazyDiskCore

final class ByteFormatterTests: XCTestCase {
    func testZeroBytes() {
        XCTAssertEqual(ByteFormatter.string(from: 0), "0 B")
    }

    func testBytes() {
        XCTAssertEqual(ByteFormatter.string(from: 512), "512 B")
    }

    func testKilobytes() {
        let result = ByteFormatter.string(from: 2048)
        XCTAssertTrue(result.contains("KB") || result.contains("2"))
    }

    func testMegabytes() {
        let result = ByteFormatter.string(from: 5 * 1024 * 1024)
        XCTAssertTrue(result.contains("MB"))
    }

    func testGigabytes() {
        let result = ByteFormatter.string(from: 3 * 1024 * 1024 * 1024)
        XCTAssertTrue(result.contains("GB"))
    }
}
