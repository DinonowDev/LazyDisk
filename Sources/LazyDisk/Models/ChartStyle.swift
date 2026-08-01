import Foundation

enum ChartStyle: String, CaseIterable, Identifiable, Sendable {
    case rose
    case sunburst
    case treemap

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
