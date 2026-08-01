import Foundation

struct ScanProgressUpdate: Sendable {
    let completed: Int
    let total: Int
    let currentName: String
    let itemIndex: Int?
    let itemSize: Int64?

    init(
        completed: Int,
        total: Int,
        currentName: String,
        itemIndex: Int? = nil,
        itemSize: Int64? = nil
    ) {
        self.completed = completed
        self.total = total
        self.currentName = currentName
        self.itemIndex = itemIndex
        self.itemSize = itemSize
    }

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}
