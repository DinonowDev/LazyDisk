import Foundation

/// Fine-grained chart scan progress calculations (testable).
public enum ChartScanProgressMath {
    public static func folderListingFraction(entries: [DiskItem]) -> Double {
        let directories = entries.filter { $0.isDirectory && !$0.isVirtual }
        guard !directories.isEmpty else {
            return entries.isEmpty ? 0 : 1
        }

        let resolved = directories.filter { !$0.isScanning || $0.size > 0 }
        return Double(resolved.count) / Double(directories.count)
    }

    public static func fileWalkFraction(filesScanned: Int) -> Double {
        guard filesScanned > 0 else { return 0 }
        // Smooth asymptote — keeps moving on large trees without needing total file count.
        return 1 - exp(-Double(filesScanned) / 280)
    }

    public static func inFlightFraction(filesScanned: Int, entries: [DiskItem]) -> Double {
        let listing = folderListingFraction(entries: entries)
        let walking = fileWalkFraction(filesScanned: filesScanned)
        return min(0.97, listing * 0.35 + walking * 0.65)
    }

    public static func combinedFraction(
        completedFolders: Int,
        totalFolders: Int,
        inFlightContribution: Double,
        currentDepth: Int = 1,
        maxDepth: Int = 1
    ) -> Double {
        let total = max(totalFolders, 1)
        let inFlight = min(max(inFlightContribution, 0), 0.98)
        let progress = (Double(completedFolders) + inFlight) / Double(total)
        return min(0.995, max(0, progress))
    }
}
