import Foundation

enum ScanHistoryCompareMode: String, CaseIterable, Identifiable, Hashable {
    case currentState
    case previousSnapshot

    var id: String { rawValue }
}

enum ScanHistoryChangeFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case added
    case removed
    case changed

    var id: String { rawValue }
}
