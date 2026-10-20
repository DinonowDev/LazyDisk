import Foundation

public struct APFSSnapshot: Sendable, Equatable, Codable {
    public let name: String
    public let created: Date?
    public let byteCount: Int64?

    public init(name: String, created: Date?, byteCount: Int64?) {
        self.name = name
        self.created = created
        self.byteCount = byteCount
    }

    public var displayName: String {
        APFSSnapshotName.displayName(raw: name, created: created)
    }
}

public struct APFSSnapshotPresentation: Sendable, Equatable {
    public let snapshot: APFSSnapshot
    public let displayBytes: Int64
    public let sizeIsEstimate: Bool

    public init(snapshot: APFSSnapshot, displayBytes: Int64, sizeIsEstimate: Bool) {
        self.snapshot = snapshot
        self.displayBytes = displayBytes
        self.sizeIsEstimate = sizeIsEstimate
    }
}

public struct APFSSnapshotGroupPresentation: Sendable, Equatable {
    public let snapshots: [APFSSnapshotPresentation]
    public let totalBytes: Int64
    public let sizeIsEstimate: Bool
    /// The group total already stands in for the volume's purgeable capacity.
    public let accountsForPurgeable: Bool

    public init(
        snapshots: [APFSSnapshotPresentation],
        totalBytes: Int64,
        sizeIsEstimate: Bool,
        accountsForPurgeable: Bool
    ) {
        self.snapshots = snapshots
        self.totalBytes = totalBytes
        self.sizeIsEstimate = sizeIsEstimate
        self.accountsForPurgeable = accountsForPurgeable
    }
}

public enum APFSSnapshotGroupBuilder {
    public static func make(
        snapshots: [APFSSnapshot],
        purgeableCapacity: Int64
    ) -> APFSSnapshotGroupPresentation {
        guard !snapshots.isEmpty else {
            return APFSSnapshotGroupPresentation(
                snapshots: [],
                totalBytes: 0,
                sizeIsEstimate: false,
                accountsForPurgeable: false
            )
        }

        let known = snapshots.allSatisfy { ($0.byteCount ?? 0) > 0 }
        if known {
            let rows = snapshots.map {
                APFSSnapshotPresentation(
                    snapshot: $0,
                    displayBytes: $0.byteCount ?? 0,
                    sizeIsEstimate: false
                )
            }
            let total = rows.reduce(Int64(0)) { $0 + $1.displayBytes }
            return APFSSnapshotGroupPresentation(
                snapshots: rows,
                totalBytes: total,
                sizeIsEstimate: false,
                accountsForPurgeable: false
            )
        }

        let purgeable = max(purgeableCapacity, 0)
        guard purgeable > 0 else {
            let rows = snapshots.map {
                APFSSnapshotPresentation(snapshot: $0, displayBytes: 0, sizeIsEstimate: false)
            }
            return APFSSnapshotGroupPresentation(
                snapshots: rows,
                totalBytes: 0,
                sizeIsEstimate: false,
                accountsForPurgeable: false
            )
        }

        let count = Int64(snapshots.count)
        let share = purgeable / count
        var remainder = purgeable - share * count
        let rows = snapshots.map { snapshot -> APFSSnapshotPresentation in
            let extra: Int64 = remainder > 0 ? 1 : 0
            if remainder > 0 { remainder -= 1 }
            return APFSSnapshotPresentation(
                snapshot: snapshot,
                displayBytes: share + extra,
                sizeIsEstimate: true
            )
        }
        return APFSSnapshotGroupPresentation(
            snapshots: rows,
            totalBytes: purgeable,
            sizeIsEstimate: true,
            accountsForPurgeable: true
        )
    }
}
