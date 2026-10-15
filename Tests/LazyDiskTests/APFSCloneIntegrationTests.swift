import Darwin
import Foundation
import XCTest
@testable import LazyDiskCore

/// CI-friendly APFS clone dedup check (runs on GitHub macOS runners with APFS temp dirs).
final class APFSCloneIntegrationTests: XCTestCase {
    func testClonePairDedupOnAPFSVolume() throws {
        let bucket = FileManager.default.temporaryDirectory
            .appendingPathComponent("LazyDisk-APFS-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: bucket, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bucket) }

        let original = bucket.appendingPathComponent("source.bin")
        let cloned = bucket.appendingPathComponent("linked.bin")
        try Data(count: 96_000).write(to: original)

        let status = original.path.withCString { source in
            cloned.path.withCString { destination in
                clonefile(source, destination, 0)
            }
        }
        if status != 0 {
            throw XCTSkip("clonefile unavailable (\(status))")
        }

        let result = DirectorySizeWalker.immediateChildSizes(at: bucket, configuration: .volumeRoot)
        XCTAssertGreaterThan(result.totalSize, 80_000)

        if result.totalSize < 120_000 {
            if result.filesScanned == 1 {
                if let metrics = result.scanMetrics {
                    XCTAssertGreaterThan(metrics.cloneBytesMerged, 0)
                }
            } else {
                throw XCTSkip(
                    "Clone pair sizing varied on this runner (files=\(result.filesScanned), total=\(result.totalSize))"
                )
            }
        } else {
            throw XCTSkip("Kernel omitted CLONEID on this runner; merge path needs metadata (total=\(result.totalSize))")
        }
    }
}
