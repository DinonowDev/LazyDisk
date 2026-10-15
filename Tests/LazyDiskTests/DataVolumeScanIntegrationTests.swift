import XCTest
@testable import LazyDiskCore

final class DataVolumeScanIntegrationTests: XCTestCase {
    func testFusedVolumeScanOnDataVolumeWhenEnabled() throws {
        if ProcessInfo.processInfo.environment["LDFS_DATA_VOLUME_SMOKE"] != "1" {
            throw XCTSkip("Set LDFS_DATA_VOLUME_SMOKE=1 to scan /System/Volumes/Data.")
        }

        let root = URL(fileURLWithPath: "/System/Volumes/Data", isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw XCTSkip("No APFS data volume on this runner")
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )
        let dirs = contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }
        let items = dirs.map {
            DiskItem(url: PathUtils.resolved($0), isDirectory: true, isScanning: true)
        }

        guard let fused = NativeDirectoryScanner.fusedVolumeScan(
            at: root,
            listedEntries: items,
            maxDepth: 2,
            skipHiddenFiles: false,
            parallelism: 4
        ) else {
            XCTFail("fusedVolumeScan returned nil")
            return
        }

        let sized = DirectorySizeWalker.applySizes(to: items, walkResult: fused.sizingWalk)
        let users = sized.first { $0.name == "Users" }
        XCTAssertGreaterThan(users?.size ?? 0, 1_000_000)
        XCTAssertGreaterThan(fused.chartResult.totalSize, 1_000_000)
    }
}
