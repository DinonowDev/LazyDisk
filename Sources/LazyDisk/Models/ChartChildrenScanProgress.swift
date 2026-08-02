import Foundation

struct ChartChildrenScanProgress: Equatable, Sendable {
    var completedFolders: Int
    var totalFolders: Int
    var currentFolderName: String

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
