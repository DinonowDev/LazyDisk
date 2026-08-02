import Foundation
import LazyDiskCore

struct ScanProgressUpdate: Sendable {
    let completed: Int
    let total: Int
    let currentName: String
    let itemIndex: Int?
    let itemSize: Int64?
    let filesScanned: Int?
    let directoriesResolved: Int?
    let partialEntries: [DiskItem]?

    init(
        completed: Int,
        total: Int,
        currentName: String,
        itemIndex: Int? = nil,
        itemSize: Int64? = nil,
        filesScanned: Int? = nil,
        directoriesResolved: Int? = nil,
        partialEntries: [DiskItem]? = nil
    ) {
        self.completed = completed
        self.total = total
        self.currentName = currentName
        self.itemIndex = itemIndex
        self.itemSize = itemSize
        self.filesScanned = filesScanned
        self.directoriesResolved = directoriesResolved
        self.partialEntries = partialEntries
    }

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var sizingFraction: Double {
        ScanProgressMath.volumeSizingFraction(
            directoriesResolved: directoriesResolved ?? completed,
            directoryTotal: total,
            filesScanned: filesScanned ?? 0,
            entries: partialEntries ?? []
        )
    }
}
