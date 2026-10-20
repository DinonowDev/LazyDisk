import Foundation

extension L10n {
    static var localSnapshots: String { text(.localSnapshots) }
    static var snapshotDelete: String { text(.snapshotDelete) }
    static var snapshotDeleteTitle: String { text(.snapshotDeleteTitle) }
    static func snapshotDeleteMessage(_ name: String) -> String {
        String(format: text(.snapshotDeleteMessage), name)
    }
    static var snapshotDeleteNeedsHelper: String { text(.snapshotDeleteNeedsHelper) }
    static var snapshotSizeEstimate: String { text(.snapshotSizeEstimate) }
    static var detailFrees: String { text(.detailFrees) }
    static var detailApparent: String { text(.detailApparent) }
    static var reclaimCloudNote: String { text(.reclaimCloudNote) }
    static var reclaimCloneNote: String { text(.reclaimCloneNote) }
    static var reclaimLinkNote: String { text(.reclaimLinkNote) }
    static var reclaimEstimateNote: String { text(.reclaimEstimateNote) }
    static var collectorApparent: String { text(.collectorApparent) }
}
