import Foundation

enum AppPanel: String, CaseIterable, Identifiable, Sendable {
    case browser
    case cleanup
    case duplicates
    case history
    case dev
    case goal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browser: return L10n.panelBrowser
        case .cleanup: return L10n.panelCleanup
        case .duplicates: return L10n.panelDuplicates
        case .history: return L10n.panelHistory
        case .dev: return L10n.panelDev
        case .goal: return L10n.panelGoal
        }
    }

    var icon: String {
        switch self {
        case .browser: return "folder.fill"
        case .cleanup: return "sparkles"
        case .duplicates: return "doc.on.doc.fill"
        case .history: return "clock.arrow.circlepath"
        case .dev: return "chevron.left.forwardslash.chevron.right"
        case .goal: return "target"
        }
    }
}
