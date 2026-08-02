import Foundation

enum ChartStyle: String, CaseIterable, Identifiable, Sendable {
    case rose
    case sunburst
    case treemap // temporarily disabled — not offered in `selectableCases`

    /// Chart styles shown in pickers and menus (treemap excluded until re-enabled).
    static var selectableCases: [ChartStyle] { [.rose, .sunburst] }

    /// Maps a stored preference to an active style (falls back when treemap is disabled).
    static func resolved(_ style: ChartStyle) -> ChartStyle {
        style == .treemap ? .rose : style
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rose: return L10n.chartStyleRose
        case .sunburst: return L10n.chartStyleSunburst
        case .treemap: return L10n.chartStyleTreemap
        }
    }

    var icon: String {
        switch self {
        case .rose: return "chart.pie.fill"
        case .sunburst: return "circle.circle"
        case .treemap: return "rectangle.split.3x3"
        }
    }
}
