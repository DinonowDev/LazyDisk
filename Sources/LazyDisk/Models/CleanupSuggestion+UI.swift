import Foundation
import SwiftUI

extension CleanupSuggestion {
    var displayCategory: GoalSuggestionCategory {
        let lower = category.lowercased()
        let nameLower = name.lowercased()
        if lower.contains("cache") || nameLower.contains("cache") { return .cache }
        if lower.contains("log") || nameLower.contains("log") { return .logs }
        if lower.contains("trash") || nameLower.contains("trash") { return .trash }
        if lower.contains("install") || nameLower.contains("install") { return .installers }
        if lower.contains("aging") || lower.contains("desktop") { return .oldFiles }
        return .other
    }
}

enum CleanupSortOrder: String, CaseIterable, Identifiable {
    case scoreDescending
    case sizeDescending
    case sizeAscending
    case nameAscending

    var id: String { rawValue }

    func sort(_ items: [CleanupSuggestion]) -> [CleanupSuggestion] {
        switch self {
        case .scoreDescending:
            return items.sorted { ($0.score, $0.size) > ($1.score, $1.size) }
        case .sizeDescending:
            return items.sorted { $0.size > $1.size }
        case .sizeAscending:
            return items.sorted { $0.size < $1.size }
        case .nameAscending:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var title: String {
        switch self {
        case .scoreDescending: return L10n.cleanupSortScore
        case .sizeDescending: return L10n.sortSizeDesc
        case .sizeAscending: return L10n.sortSizeAsc
        case .nameAscending: return L10n.sortNameAsc
        }
    }
}

func cleanupCategoryColor(_ category: GoalSuggestionCategory) -> Color {
    switch category {
    case .cache: return DiskColors.color(for: 4)
    case .logs: return DiskColors.color(for: 3)
    case .trash: return .red
    case .installers: return DiskColors.color(for: 5)
    case .oldDownloads: return .orange
    case .largeDownloads: return DiskColors.color(for: 0)
    case .oldFiles: return DiskColors.color(for: 7)
    case .devJunk: return DiskColors.color(for: 1)
    case .other: return .secondary
    }
}
