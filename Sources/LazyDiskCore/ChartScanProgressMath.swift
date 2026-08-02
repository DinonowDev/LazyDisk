import Foundation

/// Fine-grained chart scan progress calculations (testable).
public enum ChartScanProgressMath {
    /// Cap shown progress during an in-flight walk — completion sets 100%.
    public static let inFlightDisplayCap = 0.88

    public static func folderListingFraction(entries: [DiskItem]) -> Double {
        let directories = entries.filter { $0.isDirectory && !$0.isVirtual }
        guard !directories.isEmpty else {
            return entries.isEmpty ? 0 : 1
        }

        let resolved = directories.filter { !$0.isScanning || $0.size > 0 }
        return Double(resolved.count) / Double(directories.count)
    }

    /// Log-scaled walk progress for large volumes (does not saturate after a few thousand files).
    public static func fileWalkFraction(filesScanned: Int) -> Double {
        guard filesScanned > 0 else { return 0 }
        // log10(1_000)≈3 → ~44%, log10(100_000)≈5 → ~73%, log10(1_000_000)≈6 → ~88%
        let normalized = log10(Double(filesScanned) + 1) / 6.0
        return min(inFlightDisplayCap, normalized * inFlightDisplayCap)
    }

    public static func inFlightFraction(filesScanned: Int, entries: [DiskItem]) -> Double {
        let listing = folderListingFraction(entries: entries)
        let walking = fileWalkFraction(filesScanned: filesScanned)
        return min(inFlightDisplayCap, listing * 0.25 + walking * 0.75)
    }

    public static func combinedFraction(
        completedFolders: Int,
        totalFolders: Int,
        inFlightContribution: Double,
        currentDepth: Int = 1,
        maxDepth: Int = 1
    ) -> Double {
        let total = max(totalFolders, 1)
        let inFlight = min(max(inFlightContribution, 0), inFlightDisplayCap)
        let progress = (Double(completedFolders) + inFlight) / Double(total)
        return min(inFlightDisplayCap, max(0, progress))
    }

    /// Single-pass metadata tree scan (one enumerator over the subtree).
    public static func metadataTreeFraction(filesScanned: Int) -> Double {
        fileWalkFraction(filesScanned: filesScanned)
    }
}
