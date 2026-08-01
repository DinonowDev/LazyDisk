import SwiftUI

enum FileAgeHeatmap {
    /// Returns a tint color based on how old a file is (green = recent, red = old).
    static func color(for modifiedDate: Date?) -> Color {
        guard let modifiedDate else { return .clear }
        let days = Date().timeIntervalSince(modifiedDate) / 86_400
        switch days {
        case ..<7: return Color.green.opacity(0.15)
        case ..<30: return Color.yellow.opacity(0.12)
        case ..<180: return Color.orange.opacity(0.10)
        default: return Color.red.opacity(0.08)
        }
    }
}
