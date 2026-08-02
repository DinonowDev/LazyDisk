import Foundation
import XCTest
@testable import LazyDiskCore

final class CachedScanChartBuilderTests: XCTestCase {
    func testBuildsRootAndCachedChildren() {
        let root = URL(fileURLWithPath: "/Volumes/Data", isDirectory: true)
        let users = DiskItem(
            url: URL(fileURLWithPath: "/Volumes/Data/Users", isDirectory: true),
            size: 1_000,
            isDirectory: true
        )
        let home = DiskItem(
            url: URL(fileURLWithPath: "/Volumes/Data/Users/amir", isDirectory: true),
            size: 500,
            isDirectory: true
        )
        let documents = DiskItem(
            url: URL(fileURLWithPath: "/Volumes/Data/Users/amir/Documents", isDirectory: true),
            size: 200,
            isDirectory: true
        )

        let cache: [String: [DiskItem]] = [
            users.url.path: [home],
            home.url.path: [documents]
        ]

        let map = CachedScanChartBuilder.childMap(
            scanRoot: root,
            rootEntries: [users],
            maxScanDepth: 2,
            maxChildrenPerNode: 32,
            cachedEntries: { url in cache[PathUtils.resolved(url).path] }
        )

        XCTAssertEqual(map[root.path]?.map(\.url.path), [users.url.path])
        XCTAssertEqual(map[users.url.path]?.map(\.url.path), [home.url.path])
        XCTAssertEqual(map[home.url.path]?.map(\.url.path), [documents.url.path])
    }

    func testStopsAtMaxScanDepth() {
        let root = URL(fileURLWithPath: "/Volumes/Data", isDirectory: true)
        let users = DiskItem(
            url: URL(fileURLWithPath: "/Volumes/Data/Users", isDirectory: true),
            size: 1_000,
            isDirectory: true
        )
        let home = DiskItem(
            url: URL(fileURLWithPath: "/Volumes/Data/Users/amir", isDirectory: true),
            size: 500,
            isDirectory: true
        )

        let map = CachedScanChartBuilder.childMap(
            scanRoot: root,
            rootEntries: [users],
            maxScanDepth: 1,
            maxChildrenPerNode: 32,
            cachedEntries: { _ in [home] }
        )

        XCTAssertNotNil(map[root.path])
        XCTAssertNotNil(map[users.url.path])
        XCTAssertNil(map[home.url.path])
    }
}
