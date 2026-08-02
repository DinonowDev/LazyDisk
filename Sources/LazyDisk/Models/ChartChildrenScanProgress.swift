import Foundation

struct ChartChildrenScanProgress: Equatable, Sendable {
    var completedFolders: Int
    var totalFolders: Int
    var currentFolderName: String
    var currentDepth: Int
    var maxDepth: Int
    var filesScanned: Int

    init(
        completedFolders: Int,
        totalFolders: Int,
        currentFolderName: String,
        currentDepth: Int = 1,
        maxDepth: Int = 1,
        filesScanned: Int = 0
    ) {
        self.completedFolders = completedFolders
        self.totalFolders = totalFolders
        self.currentFolderName = currentFolderName
        self.currentDepth = max(1, currentDepth)
        self.maxDepth = max(1, maxDepth)
        self.filesScanned = max(0, filesScanned)
    }

    var fraction: Double {
        guard totalFolders > 0 else { return 0 }
        return Double(completedFolders) / Double(totalFolders)
    }

    var remainingFolders: Int {
        max(0, totalFolders - completedFolders)
    }

    var percentComplete: Int {
        Int((fraction * 100).rounded())
    }
}
