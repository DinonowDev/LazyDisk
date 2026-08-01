import Foundation

enum SortOrder: String, CaseIterable, Identifiable, Sendable {
    case sizeDescending
    case sizeAscending
    case nameAscending
    case nameDescending
    case dateDescending
    case dateAscending
    case kindAscending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sizeDescending: return L10n.sortSizeDesc
        case .sizeAscending: return L10n.sortSizeAsc
        case .nameAscending: return L10n.sortNameAsc
        case .nameDescending: return L10n.sortNameDesc
        case .dateDescending: return L10n.sortDateDesc
        case .dateAscending: return L10n.sortDateAsc
        case .kindAscending: return L10n.sortKind
        }
    }

    func sort(_ items: [DiskItem]) -> [DiskItem] {
        switch self {
        case .sizeDescending:
            return items.sorted { $0.size > $1.size }
        case .sizeAscending:
            return items.sorted { $0.size < $1.size }
        case .nameAscending:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .dateDescending:
            return items.sorted { ($0.modifiedDate ?? .distantPast) > ($1.modifiedDate ?? .distantPast) }
        case .dateAscending:
            return items.sorted { ($0.modifiedDate ?? .distantPast) < ($1.modifiedDate ?? .distantPast) }
        case .kindAscending:
            return items.sorted {
                if $0.fileKind != $1.fileKind { return $0.fileKind.rawValue < $1.fileKind.rawValue }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    func isActive(for column: SortColumn) -> Bool {
        switch column {
        case .name: self == .nameAscending || self == .nameDescending
        case .size: self == .sizeAscending || self == .sizeDescending
        case .date: self == .dateAscending || self == .dateDescending
        }
    }

    func isAscending(for column: SortColumn) -> Bool {
        switch column {
        case .name: self == .nameAscending
        case .size: self == .sizeAscending
        case .date: self == .dateAscending
        }
    }

    func toggled(for column: SortColumn) -> SortOrder {
        switch column {
        case .name:
            switch self {
            case .nameAscending: return .nameDescending
            case .nameDescending: return .nameAscending
            default: return .nameAscending
            }
        case .size:
            switch self {
            case .sizeDescending: return .sizeAscending
            case .sizeAscending: return .sizeDescending
            default: return .sizeDescending
            }
        case .date:
            switch self {
            case .dateDescending: return .dateAscending
            case .dateAscending: return .dateDescending
            default: return .dateDescending
            }
        }
    }
}

enum SortColumn: Sendable {
    case name, size, date
}

struct AppPreferences: Sendable {
    var sortOrder: SortOrder = .sizeDescending
    var contentFilter: ContentFilter = .all
    var chartStyle: ChartStyle = .rose
    var usePersistentCache: Bool = true
    var showHiddenFiles: Bool = true
    var language: AppLanguage = .system
    var scanParallelism: Int = 6
    var searchScope: SearchScope = .entireVolume
    var freeSpaceGoalGB: Double = 10
    var browserSidebarWidth: Double = 320

    static let userDefaultsKey = "LazyDisk.preferences"

    static func load() -> AppPreferences {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(StoredPreferences.self, from: data) else {
            return AppPreferences()
        }
        return decoded.appPreferences
    }

    func save() {
        let stored = StoredPreferences(appPreferences: self)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
}

private struct StoredPreferences: Codable {
    var sortOrder: String
    var contentFilter: String
    var chartStyle: String
    var usePersistentCache: Bool
    var showHiddenFiles: Bool
    var language: String
    var scanParallelism: Int
    var searchScope: String
    var freeSpaceGoalGB: Double?
    var browserSidebarWidth: Double?

    init(appPreferences: AppPreferences) {
        sortOrder = appPreferences.sortOrder.rawValue
        contentFilter = appPreferences.contentFilter.rawValue
        chartStyle = appPreferences.chartStyle.rawValue
        usePersistentCache = appPreferences.usePersistentCache
        showHiddenFiles = appPreferences.showHiddenFiles
        language = appPreferences.language.rawValue
        scanParallelism = appPreferences.scanParallelism
        searchScope = appPreferences.searchScope.rawValue
        freeSpaceGoalGB = appPreferences.freeSpaceGoalGB
        browserSidebarWidth = appPreferences.browserSidebarWidth
    }

    var appPreferences: AppPreferences {
        AppPreferences(
            sortOrder: SortOrder(rawValue: sortOrder) ?? .sizeDescending,
            contentFilter: ContentFilter(rawValue: contentFilter) ?? .all,
            chartStyle: ChartStyle(rawValue: chartStyle) ?? .rose,
            usePersistentCache: usePersistentCache,
            showHiddenFiles: showHiddenFiles,
            language: AppLanguage(rawValue: language) ?? .system,
            scanParallelism: max(1, min(scanParallelism, 16)),
            searchScope: SearchScope(rawValue: searchScope) ?? .entireVolume,
            freeSpaceGoalGB: freeSpaceGoalGB ?? 10,
            browserSidebarWidth: browserSidebarWidth ?? 320
        )
    }
}
