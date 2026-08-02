import Foundation

/// Shared fine-grained progress math for chart and folder scans.
public enum ScanProgressMath {
    public static func folderListingFraction(entries: [DiskItem]) -> Double {
        ChartScanProgressMath.folderListingFraction(entries: entries)
    }

    public static func fileWalkFraction(filesScanned: Int) -> Double {
        ChartScanProgressMath.fileWalkFraction(filesScanned: filesScanned)
    }

    public static func inFlightFraction(filesScanned: Int, entries: [DiskItem]) -> Double {
        ChartScanProgressMath.inFlightFraction(filesScanned: filesScanned, entries: entries)
    }

    public static func combinedFraction(
        completedFolders: Int,
        totalFolders: Int,
        inFlightContribution: Double,
        currentDepth: Int = 1,
        maxDepth: Int = 1
    ) -> Double {
        ChartScanProgressMath.combinedFraction(
            completedFolders: completedFolders,
            totalFolders: totalFolders,
            inFlightContribution: inFlightContribution,
            currentDepth: currentDepth,
            maxDepth: maxDepth
        )
    }

    /// Maps folder-sizing progress into the 0.10…0.85 band used by volume scan UI.
    public static func volumeSizingFraction(
        directoriesResolved: Int,
        directoryTotal: Int,
        filesScanned: Int,
        entries: [DiskItem] = []
    ) -> Double {
        let inFlight = entries.isEmpty
            ? fileWalkFraction(filesScanned: filesScanned)
            : inFlightFraction(filesScanned: filesScanned, entries: entries)

        return combinedFraction(
            completedFolders: directoriesResolved,
            totalFolders: directoryTotal,
            inFlightContribution: inFlight
        )
    }

    public static func volumeScanDisplayFraction(
        phaseBase: Double,
        sizingFraction: Double,
        published: Double
    ) -> Double {
        let raw = phaseBase + sizingFraction * 0.75
        return max(published, min(0.88, raw))
    }
}
