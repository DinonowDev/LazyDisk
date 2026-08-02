import Foundation

enum InterfaceMode: String, CaseIterable, Identifiable, Sendable {
    case simple
    case professional

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simple: return L10n.modeSimple
        case .professional: return L10n.modeProfessional
        }
    }

    var subtitle: String {
        switch self {
        case .simple: return L10n.modeSimpleDesc
        case .professional: return L10n.modeProfessionalDesc
        }
    }

    var icon: String {
        switch self {
        case .simple: return "circle.circle"
        case .professional: return "sidebar.left"
        }
    }
}
