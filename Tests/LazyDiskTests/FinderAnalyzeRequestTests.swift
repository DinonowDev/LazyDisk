import XCTest
import LazyDiskCore

final class FinderAnalyzeRequestTests: XCTestCase {
    func testUrlsFromFilenamesExpandsTilde() {
        let urls = FinderAnalyzeRequest.urls(fromFilenames: ["~/Downloads"])
        XCTAssertEqual(urls.count, 1)
        XCTAssertTrue(urls[0].path.contains("Downloads"))
    }

    func testUrlsFromPropertyListStringArray() {
        let urls = FinderAnalyzeRequest.urls(fromPropertyList: ["/tmp/a", "/tmp/b"])
        XCTAssertEqual(urls.map(\.path), ["/tmp/a", "/tmp/b"])
    }

    func testUrlsFromPropertyListSingleString() {
        let urls = FinderAnalyzeRequest.urls(fromPropertyList: "/tmp/single")
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls[0].path, "/tmp/single")
    }

    func testEmptyInputReturnsNoURLs() {
        XCTAssertTrue(FinderAnalyzeRequest.urls(fromFilenames: []).isEmpty)
        XCTAssertTrue(FinderAnalyzeRequest.urls(fromPropertyList: nil).isEmpty)
    }
}
