import Foundation
import LazyDiskCore

extension DiskScanner {
    /// Upgrades a light cached listing to full sidebar metadata, preserving known sizes.
    func upgradeToFullContent(at url: URL, existing: [DiskItem]) async -> [DiskItem] {
        let normalized = PathUtils.resolved(url)
        let fullListing = await listDirectory(at: normalized)
        let sizeIndex = await DirectorySizeIndex.shared.sizesSnapshot()
        var merged = DirectoryEntryMerger.merge(
            fullListing: fullListing,
            sizedEntries: existing,
            sizeIndex: sizeIndex
        )

        let needsSizing = merged.contains {
            $0.isDirectory && !$0.isVirtual && ($0.isScanning || $0.size == 0)
        }

        if needsSizing {
            merged = await scanDirectorySizes(items: merged, parent: normalized)
        }

        return merged
    }
}
