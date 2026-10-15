import Foundation

/// Tracks DaisyDisk-style full-volume tree scans whose sizes live in `DirectorySizeIndex`.
public actor VolumeTreeScanCoordinator {
    public static let shared = VolumeTreeScanCoordinator()

    private var completedVolumeIDs: Set<String> = []
    private var scanRootsByVolumeID: [String: String] = [:]
    private var chartChildMapsByVolumeID: [String: [String: [DiskItem]]] = [:]

    public func markComplete(volumeID: String, scanRoot: URL) {
        completedVolumeIDs.insert(volumeID)
        scanRootsByVolumeID[volumeID] = PathUtils.resolved(scanRoot).path
    }

    public func storeChartChildMap(volumeID: String, map: [String: [DiskItem]]) {
        chartChildMapsByVolumeID[volumeID] = map
    }

    public func chartChildMap(for volumeID: String) -> [String: [DiskItem]]? {
        chartChildMapsByVolumeID[volumeID]
    }

    public func clear(volumeID: String?) {
        if let volumeID {
            completedVolumeIDs.remove(volumeID)
            scanRootsByVolumeID.removeValue(forKey: volumeID)
            chartChildMapsByVolumeID.removeValue(forKey: volumeID)
        } else {
            completedVolumeIDs.removeAll()
            scanRootsByVolumeID.removeAll()
            chartChildMapsByVolumeID.removeAll()
        }
    }

    public func hasCompleteTreeScan(volumeID: String?) -> Bool {
        guard let volumeID else { return false }
        return completedVolumeIDs.contains(volumeID)
    }

    public func scanRootPath(for volumeID: String) -> String? {
        scanRootsByVolumeID[volumeID]
    }
}
