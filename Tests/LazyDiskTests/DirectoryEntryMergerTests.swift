import Foundation
import XCTest
@testable import LazyDiskCore

final class DirectoryEntryMergerTests: XCTestCase {
    func testMergePreservesSizesFromLightEntries() {
        let dir = URL(fileURLWithPath: "/tmp/projects", isDirectory: true)
        let file = URL(fileURLWithPath: "/tmp/projects/readme.txt")

        let fullListing = [
            DiskItem(url: dir, isDirectory: true, isScanning: true),
            DiskItem(url: file, size: 0, isDirectory: false, modifiedDate: Date(timeIntervalSince1970: 1_700_000_000))
        ]

        let sized = [
            DiskItem(url: dir, size: 9_000, isDirectory: true, isScanning: false),
            DiskItem(url: file, size: 200, isDirectory: false)
        ]

        let merged = DirectoryEntryMerger.merge(fullListing: fullListing, sizedEntries: sized)

        XCTAssertEqual(merged[0].size, 9_000)
        XCTAssertFalse(merged[0].isScanning)
        XCTAssertEqual(merged[1].size, 200)
        XCTAssertNotNil(merged[1].modifiedDate)
    }

    func testMergeUsesSizeIndexFallback() {
        let dir = URL(fileURLWithPath: "/tmp/archive", isDirectory: true)
        let fullListing = [DiskItem(url: dir, isDirectory: true, isScanning: true)]

        let merged = DirectoryEntryMerger.merge(
            fullListing: fullListing,
            sizedEntries: [],
            sizeIndex: [dir.path: 4_500]
        )

        XCTAssertEqual(merged[0].size, 4_500)
        XCTAssertFalse(merged[0].isScanning)
    }
}
