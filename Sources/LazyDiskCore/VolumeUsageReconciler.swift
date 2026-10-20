import Foundation

public struct VolumeReconcileLabels: Sendable {
    public var purgeable: String
    public var unscanned: String
    public var cloud: String
    public var snapshots: String

    public init(purgeable: String, unscanned: String, cloud: String, snapshots: String) {
        self.purgeable = purgeable
        self.unscanned = unscanned
        self.cloud = cloud
        self.snapshots = snapshots
    }
}

public enum VolumeUsageReconciler {
    public static func reconcile(
        items: [DiskItem],
        volumePath: String,
        usedCapacity: Int64,
        purgeableCapacity: Int64,
        snapshots: [APFSSnapshot],
        atVolumeRoot: Bool,
        labels: VolumeReconcileLabels
    ) -> [DiskItem] {
        guard atVolumeRoot else { return items }

        var result = items.filter { !$0.isVirtual }
        let scannedTotal = result.reduce(Int64(0)) { $0 + $1.size }
        let purgeable = max(purgeableCapacity, 0)
        let group = APFSSnapshotGroupBuilder.make(snapshots: snapshots, purgeableCapacity: purgeable)

        var accounted = scannedTotal

        if !group.snapshots.isEmpty {
            result.append(snapshotGroupItem(volumePath: volumePath, group: group, title: labels.snapshots))
            accounted += group.totalBytes
        }

        let purgeableLeft: Int64
        if group.accountsForPurgeable {
            purgeableLeft = 0
        } else {
            purgeableLeft = max(0, purgeable - group.totalBytes)
        }
        if purgeableLeft > 10_000_000 {
            result.append(DiskItem(
                url: URL(fileURLWithPath: "/"),
                name: labels.purgeable,
                size: purgeableLeft,
                isDirectory: false,
                isVirtual: true,
                isPurgeable: true,
                role: .purgeable
            ))
            accounted += purgeableLeft
        }

        let residual = usedCapacity - accounted
        if residual > 50_000_000 {
            result.append(DiskItem(
                url: URL(fileURLWithPath: "/"),
                name: labels.unscanned,
                size: residual,
                isDirectory: false,
                isVirtual: true,
                role: .unscanned
            ))
        }

        let cloudTotal = result.filter(\.isCloudPlaceholder).reduce(Int64(0)) { $0 + $1.size }
        if cloudTotal > 1_000_000 {
            result.append(DiskItem(
                url: URL(fileURLWithPath: "/"),
                name: labels.cloud,
                size: cloudTotal,
                isDirectory: false,
                isVirtual: true,
                isCloudPlaceholder: true,
                role: .cloudSummary
            ))
        }

        return result.sorted { $0.size > $1.size }
    }

    public static func snapshotItems(
        volumePath: String,
        group: APFSSnapshotGroupPresentation
    ) -> [DiskItem] {
        group.snapshots.map { row in
            DiskItem(
                id: VirtualDiskPath.stableID(for: "snapshot:\(volumePath):\(row.snapshot.name)"),
                url: VirtualDiskPath.snapshot(volumePath: volumePath, name: row.snapshot.name),
                name: row.snapshot.displayName,
                size: row.displayBytes,
                isDirectory: false,
                isVirtual: true,
                modifiedDate: row.snapshot.created ?? APFSSnapshotName.date(from: row.snapshot.name),
                role: .snapshot,
                sizeIsEstimate: row.sizeIsEstimate
            )
        }
    }

    private static func snapshotGroupItem(
        volumePath: String,
        group: APFSSnapshotGroupPresentation,
        title: String
    ) -> DiskItem {
        DiskItem(
            id: VirtualDiskPath.stableID(for: "snapshot-group:\(volumePath)"),
            url: VirtualDiskPath.snapshotGroup(volumePath: volumePath),
            name: title,
            size: group.totalBytes,
            isDirectory: true,
            isVirtual: true,
            role: .snapshotGroup,
            sizeIsEstimate: group.sizeIsEstimate
        )
    }
}
