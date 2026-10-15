import Foundation
import XCTest
@testable import LazyDiskCore

final class PrivilegedScanProgressTests: XCTestCase {
    func testPerformScanInvokesProgressHandler() throws {
        guard NativeDirectoryScanner.isAvailable else {
            throw XCTSkip("Native scanner unavailable")
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LazyDisk-Progress-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sub = root.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(count: 12_000).write(to: sub.appendingPathComponent("a.bin"))
        try Data(count: 8_000).write(to: root.appendingPathComponent("b.bin"))

        final class Counter: @unchecked Sendable {
            var progressCalls = 0
            var lastFiles: Int64 = 0
        }
        let counter = Counter()

        let result = try PrivilegedScanRunner.performScan(
            atPath: root.path,
            progress: { update in
                counter.progressCalls += 1
                counter.lastFiles = update.filesScanned
            }
        )

        let calls = counter.progressCalls
        let lastFiles = counter.lastFiles

        XCTAssertGreaterThan(result.totalSize, 15_000)
        XCTAssertGreaterThan(calls, 0, "onPartial should fire during privileged walk")
        XCTAssertGreaterThanOrEqual(lastFiles, 1)
    }

    func testAdminSessionLaunchUpdatesProgress() async throws {
        guard NativeDirectoryScanner.isAvailable else {
            throw XCTSkip("Native scanner unavailable")
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LazyDisk-Session-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(count: 20_000).write(to: root.appendingPathComponent("blob.bin"))

        let requestID = "test-\(UUID().uuidString)"
        let store = AdminScanSessionStore.shared
        await store.launch(requestID: requestID, path: root.path)

        var sawProgress = false
        for _ in 0..<120 {
            let items = await store.progress(for: [requestID])
            if let item = items.first, item.filesScanned > 0 || item.totalSize > 0 {
                sawProgress = true
            }
            if items.first?.finished == true { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        let result = try await store.waitForResult(requestID: requestID, path: root.path)
        XCTAssertGreaterThan(result.totalSize, 10_000)
        XCTAssertTrue(sawProgress || result.filesScanned > 0)
    }
}
