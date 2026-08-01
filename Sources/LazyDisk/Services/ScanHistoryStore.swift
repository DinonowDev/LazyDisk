import Foundation

actor ScanHistoryStore {
    static let shared = ScanHistoryStore()

    private let directory: URL
    private let maxSnapshotsPerVolume = 30
    private let maxEntriesPerSnapshot = 10_000

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = appSupport.appendingPathComponent("LazyDisk/ScanHistory", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func saveSnapshot(volumeID: String, totalUsed: Int64, entries: [DiskItem]) {
        let real = entries.filter { !$0.isVirtual }
        let snapshotEntries = real
            .sorted { $0.size > $1.size }
            .prefix(maxEntriesPerSnapshot)
            .map { SnapshotEntry(path: $0.url.path, size: $0.size, isDirectory: $0.isDirectory) }

        let snapshot = ScanSnapshot(
            volumeID: volumeID,
            totalUsed: totalUsed,
            totalFiles: real.count,
            entries: Array(snapshotEntries)
        )

        let file = directory.appendingPathComponent("\(volumeID)-\(snapshot.id.uuidString).json")
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: file)
        }

        prune(volumeID: volumeID)
    }

    func snapshots(for volumeID: String) -> [ScanSnapshot] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }

        return files
            .filter { $0.lastPathComponent.hasPrefix(volumeID) }
            .compactMap { url -> ScanSnapshot? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(ScanSnapshot.self, from: data)
            }
            .sorted { $0.scannedAt > $1.scannedAt }
    }

    func diff(current: [DiskItem], previous: ScanSnapshot) -> ScanDiff {
        ScanHistoryDiff.computeDiff(current: current, previous: previous)
    }

    private func prune(volumeID: String) {
        let all = snapshots(for: volumeID)
        guard all.count > maxSnapshotsPerVolume else { return }
        for snapshot in all.dropFirst(maxSnapshotsPerVolume) {
            let file = directory.appendingPathComponent("\(volumeID)-\(snapshot.id.uuidString).json")
            try? FileManager.default.removeItem(at: file)
        }
    }
}
