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

    /// Splash scan phase 1 maps normal volume progress (0.10…0.88) into 0.10…0.47 before tree indexing.
    @available(*, deprecated, message: "Use VolumeSplashProgressPhases.sizingFromVolumeFraction")
    public static func gatedSplashVolumeScanFraction(
        sizingFraction: Double,
        published: Double,
        phaseBase: Double = 0.1,
        normalPhaseCap: Double = 0.88,
        splashPhaseCap: Double = 0.47
    ) -> Double {
        let raw = volumeScanDisplayFraction(
            phaseBase: phaseBase,
            sizingFraction: sizingFraction,
            published: published
        )
        let span = normalPhaseCap - phaseBase
        guard span > 0.000_1 else { return max(published, min(splashPhaseCap, raw)) }
        let normalized = min(max((raw - phaseBase) / span, 0), 1)
        let mapped = phaseBase + normalized * (splashPhaseCap - phaseBase)
        return max(published, min(splashPhaseCap, mapped))
    }
}

/// Weighted splash-scan phases (time-shaped bands with sub-task progress inside each band).
public enum VolumeSplashProgressPhases {
    public static let preparingUpper = 0.05
    public static let listingUpper = 0.08
    /// Folder sizing / native walk — largest band (~60% of the bar).
    public static let sizingUpper = 0.68
    public static let finalizingUpper = 0.82
    public static let prefetchUpper = 0.99

    public static func clampMonotonic(published: Double, proposed: Double) -> Double {
        max(published, min(proposed, prefetchUpper))
    }

    public static func preparing(fraction: Double = 1, published: Double) -> Double {
        let t = min(max(fraction, 0), 1)
        return clampMonotonic(published: published, proposed: preparingUpper * t)
    }

    public static func listed(published: Double) -> Double {
        clampMonotonic(published: published, proposed: listingUpper)
    }

    public static func sizing(normalizedSizingFraction: Double, published: Double) -> Double {
        let t = min(max(normalizedSizingFraction, 0), 1)
        let proposed = listingUpper + t * (sizingUpper - listingUpper)
        return clampMonotonic(published: published, proposed: proposed)
    }

    public static func sizingFromVolumeFraction(_ sizingFraction: Double, published: Double) -> Double {
        let cap = ChartScanProgressMath.inFlightDisplayCap
        let normalized = min(max(sizingFraction / cap, 0), 1)
        return sizing(normalizedSizingFraction: normalized, published: published)
    }

    public static func finalizing(subPhase: Double, published: Double) -> Double {
        let t = min(max(subPhase, 0), 1)
        let proposed = sizingUpper + t * (finalizingUpper - sizingUpper)
        return clampMonotonic(published: published, proposed: proposed)
    }

    public static func chartPrefetch(ratio: Double, published: Double) -> Double {
        let t = min(max(ratio, 0), 1)
        let proposed = finalizingUpper + t * (prefetchUpper - finalizingUpper)
        return clampMonotonic(published: published, proposed: proposed)
    }

    public static func complete() -> Double { 1 }
}
