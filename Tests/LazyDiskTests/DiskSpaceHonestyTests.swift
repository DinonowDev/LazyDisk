import XCTest
import LazyDiskCore

final class DiskSpaceHonestyTests: XCTestCase {
    func testCloudPlaceholderFreesNothing() {
        let item = DiskItem(
            url: URL(fileURLWithPath: "/Users/me/file.dat"),
            size: 5_000_000_000,
            isCloudPlaceholder: true
        )
        XCTAssertEqual(item.reclaimableSize, 0)
    }

    func testSharedCloneFreesNothing() {
        let item = DiskItem(
            url: URL(fileURLWithPath: "/Users/me/clone.dat"),
            size: 8_000_000,
            cloneReferenceCount: 3
        )
        XCTAssertEqual(item.reclaimableSize, 0)
    }

    func testHardLinkFreesNothing() {
        let item = DiskItem(
            url: URL(fileURLWithPath: "/Users/me/link.dat"),
            size: 4_000,
            linkCount: 2
        )
        XCTAssertEqual(item.reclaimableSize, 0)
    }

    func testDirectoryKeepsAllocatedSize() {
        let item = DiskItem(
            url: URL(fileURLWithPath: "/Users/me/Projects"),
            size: 12_000,
            isDirectory: true,
            linkCount: 4
        )
        XCTAssertEqual(item.reclaimableSize, 12_000)
    }

    func testOrdinaryFileFreesItsAllocatedSize() {
        let item = DiskItem(url: URL(fileURLWithPath: "/Users/me/notes.txt"), size: 2_048)
        XCTAssertEqual(item.reclaimableSize, 2_048)
    }

    func testTimeMachineNameParsesDate() {
        let date = APFSSnapshotName.date(from: "com.apple.TimeMachine.2026-10-20-163045.local")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date!)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 10)
        XCTAssertEqual(parts.day, 20)
        XCTAssertEqual(parts.hour, 16)
        XCTAssertEqual(parts.minute, 30)
        XCTAssertEqual(parts.second, 45)
    }

    func testEstimatedSnapshotsSharePurgeableSpace() {
        let snapshots = [
            APFSSnapshot(name: "a", created: nil, byteCount: nil),
            APFSSnapshot(name: "b", created: nil, byteCount: nil)
        ]
        let group = APFSSnapshotGroupBuilder.make(snapshots: snapshots, purgeableCapacity: 100)
        XCTAssertTrue(group.sizeIsEstimate)
        XCTAssertTrue(group.accountsForPurgeable)
        XCTAssertEqual(group.totalBytes, 100)
        XCTAssertEqual(group.snapshots.reduce(0) { $0 + $1.displayBytes }, 100)
    }

    func testKnownSnapshotSizesAreNotTreatedAsPurgeable() {
        let snapshots = [
            APFSSnapshot(name: "a", created: nil, byteCount: 40),
            APFSSnapshot(name: "b", created: nil, byteCount: 60)
        ]
        let group = APFSSnapshotGroupBuilder.make(snapshots: snapshots, purgeableCapacity: 500)
        XCTAssertFalse(group.sizeIsEstimate)
        XCTAssertFalse(group.accountsForPurgeable)
        XCTAssertEqual(group.totalBytes, 100)
    }

    func testReconcileUsesSnapshotGroupInsteadOfASecondPurgeableSlice() {
        let folder = DiskItem(url: URL(fileURLWithPath: "/Users"), size: 700_000_000, isDirectory: true)
        let snapshots = [APFSSnapshot(name: "com.apple.TimeMachine.2026-10-20-120000.local", created: nil, byteCount: nil)]
        let labels = VolumeReconcileLabels(
            purgeable: "Purgeable",
            unscanned: "Unscanned",
            cloud: "iCloud",
            snapshots: "Local Snapshots"
        )
        let items = VolumeUsageReconciler.reconcile(
            items: [folder],
            volumePath: "/System/Volumes/Data",
            usedCapacity: 1_000_000_000,
            purgeableCapacity: 200_000_000,
            snapshots: snapshots,
            atVolumeRoot: true,
            labels: labels
        )
        XCTAssertEqual(items.filter { $0.role == .snapshotGroup }.count, 1)
        XCTAssertEqual(items.first { $0.role == .snapshotGroup }?.size, 200_000_000)
        XCTAssertTrue(items.filter { $0.role == .purgeable }.isEmpty)
        XCTAssertEqual(items.first { $0.role == .unscanned }?.size, 100_000_000)
    }

    func testLegacyDiskItemJSONStillDecodes() throws {
        let json = """
        {"id":"11111111-1111-4111-8111-111111111111","url":"file:///tmp/a","name":"a","size":9,"isDirectory":false,"children":[],"isScanning":false,"isHidden":false,"isVirtual":false,"fileKind":"other","isCloudPlaceholder":false,"isPurgeable":false}
        """.data(using: .utf8)!
        let item = try JSONDecoder().decode(DiskItem.self, from: json)
        XCTAssertEqual(item.size, 9)
        XCTAssertEqual(item.role, .regular)
        XCTAssertEqual(item.reclaimableSize, 9)
        XCTAssertEqual(item.cloneReferenceCount, 0)
    }

    func testBootVolumeSnapshotNamesAreReadable() {
        let snapshots = APFSSnapshotStore.list(volumePath: "/")
        XCTAssertFalse(snapshots.isEmpty, "The boot volume's sealed snapshot should be readable")
        for snapshot in snapshots {
            XCTAssertTrue(snapshot.name.hasPrefix("com.apple."))
            XCTAssertNotNil(snapshot.created)
            XCTAssertFalse(APFSSnapshotName.isDeletable(snapshot.name) && snapshot.name.hasPrefix("com.apple.os.update-"))
        }
        XCTAssertTrue(snapshots.contains { !APFSSnapshotName.isDeletable($0.name) })
    }

    func testSnapshotListDoesNotCrashOnDataVolume() {
        let path = "/System/Volumes/Data"
        guard FileManager.default.fileExists(atPath: path) else { return }
        let snapshots = APFSSnapshotStore.list(volumePath: path)
        for snapshot in snapshots {
            XCTAssertFalse(snapshot.name.isEmpty)
            XCTAssertFalse(snapshot.name.contains("/"))
            XCTAssertNil(snapshot.name.first { $0.asciiValue ?? 32 < 32 })
        }
    }

    func testCloneProbeOnRegularFileDoesNotCrash() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lazydisk-reclaim-\(UUID().uuidString)")
        try Data("hello".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let count = FileReclaimProbe.cloneReferenceCount(atPath: url.path)
        XCTAssertLessThan(count, 10)
    }
}
