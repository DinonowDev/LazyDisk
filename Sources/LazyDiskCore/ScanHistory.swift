import Foundation

public struct ScanSnapshot: Identifiable, Codable, Sendable {
    public let id: UUID
    public let volumeID: String
    public let scannedAt: Date
    public let totalUsed: Int64
    public let totalFiles: Int
    public let entries: [SnapshotEntry]

    public init(volumeID: String, totalUsed: Int64, totalFiles: Int, entries: [SnapshotEntry]) {
        self.id = UUID()
        self.volumeID = volumeID
        self.scannedAt = Date()
        self.totalUsed = totalUsed
        self.totalFiles = totalFiles
        self.entries = entries
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        volumeID = try c.decode(String.self, forKey: .volumeID)
        scannedAt = try c.decode(Date.self, forKey: .scannedAt)
        totalUsed = try c.decode(Int64.self, forKey: .totalUsed)
        entries = try c.decode([SnapshotEntry].self, forKey: .entries)
        totalFiles = try c.decodeIfPresent(Int.self, forKey: .totalFiles) ?? entries.count
    }
}

public struct SnapshotEntry: Codable, Sendable, Hashable {
    public let path: String
    public let size: Int64
    public let isDirectory: Bool

    public init(path: String, size: Int64, isDirectory: Bool) {
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        path = try c.decode(String.self, forKey: .path)
        size = try c.decode(Int64.self, forKey: .size)
        isDirectory = try c.decodeIfPresent(Bool.self, forKey: .isDirectory) ?? true
    }
}

public struct PathChange: Sendable, Identifiable {
    public let id: String
    public let path: String
    public let delta: Int64
    public let newSize: Int64?

    public init(id: String, path: String, delta: Int64, newSize: Int64?) {
        self.id = id
        self.path = path
        self.delta = delta
        self.newSize = newSize
    }
}

public struct ScanDiff: Sendable {
    public let addedBytes: Int64
    public let removedBytes: Int64
    public let netDelta: Int64
    public let addedCount: Int
    public let removedCount: Int
    public let changedCount: Int
    public let addedPaths: [PathChange]
    public let removedPaths: [PathChange]
    public let changedPaths: [PathChange]

    public var totalChangeCount: Int { addedCount + removedCount + changedCount }
    public var isEmpty: Bool { totalChangeCount == 0 }
}

public struct SnapshotAnalytics: Sendable {
    public let trackedBytes: Int64
    public let topEntries: [SnapshotEntry]

    public static func analyze(_ snapshot: ScanSnapshot, topN: Int = 8) -> SnapshotAnalytics {
        let tracked = snapshot.entries.reduce(Int64(0)) { $0 + $1.size }
        let top = snapshot.entries.sorted { $0.size > $1.size }.prefix(topN)
        return SnapshotAnalytics(trackedBytes: tracked, topEntries: Array(top))
    }
}

public enum ScanHistoryPaths {
    /// Safe single path-component prefix for a volume mount path (e.g. "/" → "root").
    public static func filenamePrefix(for volumeID: String) -> String {
        if volumeID == "/" { return "root" }
        return String(volumeID.drop(while: { $0 == "/" }))
            .replacingOccurrences(of: "/", with: "--")
    }

    public static func snapshotFilename(volumeID: String, snapshotID: UUID) -> String {
        "\(filenamePrefix(for: volumeID))-\(snapshotID.uuidString).json"
    }
}

public enum ScanHistoryDiff {
    public static func computeDiff(current: [DiskItem], previous: ScanSnapshot) -> ScanDiff {
        let currentItems = current.filter { !$0.isVirtual }
        let currentMap = Dictionary(uniqueKeysWithValues: currentItems.map { ($0.url.path, $0.size) })
        let prevMap = Dictionary(uniqueKeysWithValues: previous.entries.map { ($0.path, $0.size) })
        return buildDiff(currentMap: currentMap, previousMap: prevMap)
    }

    public static func computeDiff(baseline: ScanSnapshot, target: ScanSnapshot) -> ScanDiff {
        let baselineMap = Dictionary(uniqueKeysWithValues: baseline.entries.map { ($0.path, $0.size) })
        let targetMap = Dictionary(uniqueKeysWithValues: target.entries.map { ($0.path, $0.size) })
        return buildDiff(currentMap: targetMap, previousMap: baselineMap)
    }

    public static func usageDelta(from older: ScanSnapshot, to newer: ScanSnapshot) -> Int64 {
        newer.totalUsed - older.totalUsed
    }

    private static func buildDiff(
        currentMap: [String: Int64],
        previousMap: [String: Int64]
    ) -> ScanDiff {
        var addedBytes: Int64 = 0
        var removedBytes: Int64 = 0
        var added: [PathChange] = []
        var removed: [PathChange] = []
        var changed: [PathChange] = []

        for (path, size) in currentMap {
            if let prev = previousMap[path] {
                let delta = size - prev
                if delta != 0 {
                    changed.append(PathChange(id: path, path: path, delta: delta, newSize: size))
                }
            } else {
                addedBytes += size
                added.append(PathChange(id: path, path: path, delta: size, newSize: size))
            }
        }

        for (path, size) in previousMap where currentMap[path] == nil {
            removedBytes += size
            removed.append(PathChange(id: path, path: path, delta: -size, newSize: nil))
        }

        added.sort { $0.delta > $1.delta }
        removed.sort { abs($0.delta) > abs($1.delta) }
        changed.sort { abs($0.delta) > abs($1.delta) }

        return ScanDiff(
            addedBytes: addedBytes,
            removedBytes: removedBytes,
            netDelta: addedBytes - removedBytes,
            addedCount: added.count,
            removedCount: removed.count,
            changedCount: changed.count,
            addedPaths: Array(added.prefix(100)),
            removedPaths: Array(removed.prefix(100)),
            changedPaths: Array(changed.prefix(200))
        )
    }
}
