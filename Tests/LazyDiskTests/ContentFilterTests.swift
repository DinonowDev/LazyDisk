import XCTest
import LazyDiskCore

final class ContentFilterTests: XCTestCase {
    func testAllMatchesEverything() {
        let image = DiskItem(url: URL(fileURLWithPath: "/a.png"), isDirectory: false)
        let folder = DiskItem(url: URL(fileURLWithPath: "/folder"), isDirectory: true)
        XCTAssertTrue(ContentFilter.all.matches(image))
        XCTAssertTrue(ContentFilter.all.matches(folder))
    }

    func testFoldersOnlyDirectories() {
        let folder = DiskItem(url: URL(fileURLWithPath: "/folder"), isDirectory: true)
        let file = DiskItem(url: URL(fileURLWithPath: "/a.txt"), isDirectory: false)
        XCTAssertTrue(ContentFilter.folders.matches(folder))
        XCTAssertFalse(ContentFilter.folders.matches(file))
    }

    func testDeveloperFilter() {
        let swift = DiskItem(url: URL(fileURLWithPath: "/code.swift"), isDirectory: false)
        let txt = DiskItem(url: URL(fileURLWithPath: "/readme.txt"), isDirectory: false)
        XCTAssertTrue(ContentFilter.developer.matches(swift))
        XCTAssertFalse(ContentFilter.developer.matches(txt))
    }

    func testOtherFilter() {
        let unknown = DiskItem(url: URL(fileURLWithPath: "/file.xyz"), isDirectory: false)
        let folder = DiskItem(url: URL(fileURLWithPath: "/folder"), isDirectory: true)
        XCTAssertTrue(ContentFilter.other.matches(unknown))
        XCTAssertFalse(ContentFilter.other.matches(folder))
    }

    func testImagesFilter() {
        let png = DiskItem(url: URL(fileURLWithPath: "/photo.png"), isDirectory: false)
        let mp3 = DiskItem(url: URL(fileURLWithPath: "/song.mp3"), isDirectory: false)
        XCTAssertTrue(ContentFilter.images.matches(png))
        XCTAssertFalse(ContentFilter.images.matches(mp3))
    }

    func testAllCasesIncludeDeveloperAndOther() {
        XCTAssertTrue(ContentFilter.allCases.contains(.developer))
        XCTAssertTrue(ContentFilter.allCases.contains(.other))
    }
}
