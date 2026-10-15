import Foundation
import LazyDiskCore

extension DiskScanner {
    /// Lists a folder using sizes from a completed volume tree scan (no subtree walk).
    func folderListingFromVolumeTree(at url: URL, scanRoot: URL) async -> [DiskItem] {
        let normalized = PathUtils.resolved(url)
        let listed = await listDirectoryLight(at: normalized)
        let sized = await itemsWithIndexedSizes(listed, scanRoot: scanRoot)
        return sized.map { item in
            var copy = item
            if copy.isDirectory {
                copy.isScanning = false
            }
            return copy
        }
    }

    func canUseVolumeTreeListing(volumeID: String?, folder: URL, scanRoot: URL) async -> Bool {
        guard await VolumeTreeScanCoordinator.shared.hasCompleteTreeScan(volumeID: volumeID) else {
            return false
        }
        return PathUtils.isWithinVolume(folder, scanRoot: scanRoot)
    }
}
