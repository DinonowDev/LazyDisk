import Foundation
import XCTest
@testable import LazyDiskCore

final class DirectorySizeIndexTests: XCTestCase {
    func testWalkDeduplicatesConcurrentRequests() async throws {
        await DirectorySizeIndex.shared.clear()

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LazyDiskIndex-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try Data(count: 8_192).write(to: tempRoot.appendingPathComponent("sample.bin"))

        async let first = DirectorySizeIndex.shared.walk(at: tempRoot)
        async let second = DirectorySizeIndex.shared.walk(at: tempRoot)

        let results = await [first, second]
        XCTAssertEqual(results[0].totalSize, results[1].totalSize)
        XCTAssertGreaterThan(results[0].totalSize, 0)
    }
}
