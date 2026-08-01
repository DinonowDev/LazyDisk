import Foundation

enum DeleteWarningSeverity: String, Sendable {
    case info
    case caution
    case danger
}

struct DeleteWarning: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String
    let severity: DeleteWarningSeverity
    let paths: [String]
}
