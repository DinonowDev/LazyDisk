import Foundation
import LazyDiskCore

struct ChartChildrenScanProgress: Equatable, Sendable {
    var completedFolders: Int
    var totalFolders: Int
    var currentFolderName: String
    var currentDepth: Int
    var maxDepth: Int
    var filesScanned: Int
    var inFlightContribution: Double
    var displayFraction: Double

    init(
        completedFolders: Int,
        totalFolders: Int,
        currentFolderName: String,
        currentDepth: Int = 1,
        maxDepth: Int = 1,
        filesScanned: Int = 0,
        inFlightContribution: Double = 0,
        displayFraction: Double? = nil
    ) {
        self.completedFolders = completedFolders
        self.totalFolders = totalFolders
        self.currentFolderName = currentFolderName
        self.currentDepth = max(1, currentDepth)
        self.maxDepth = max(1, maxDepth)
        self.filesScanned = max(0, filesScanned)
        self.inFlightContribution = max(0, inFlightContribution)

        let raw = ChartScanProgressMath.combinedFraction(
            completedFolders: completedFolders,
            totalFolders: totalFolders,
            inFlightContribution: inFlightContribution,
            currentDepth: self.currentDepth,
            maxDepth: self.maxDepth
        )
        self.displayFraction = displayFraction ?? raw
    }

    var fraction: Double { displayFraction }

    var remainingFolders: Int {
        max(0, totalFolders - completedFolders)
    }

    var percentComplete: Int {
        Int((min(max(fraction, 0), 1) * 100).rounded())
    }

    var percentLabel: String {
        String(format: "%.1f%%", min(max(fraction, 0), 1) * 100)
    }

    func advancing(to newer: ChartChildrenScanProgress) -> ChartChildrenScanProgress {
        ChartChildrenScanProgress(
            completedFolders: newer.completedFolders,
            totalFolders: newer.totalFolders,
            currentFolderName: newer.currentFolderName,
            currentDepth: newer.currentDepth,
            maxDepth: newer.maxDepth,
            filesScanned: newer.filesScanned,
            inFlightContribution: newer.inFlightContribution,
            displayFraction: max(displayFraction, newer.displayFraction)
        )
    }
}
