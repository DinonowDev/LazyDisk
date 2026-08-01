import Foundation

enum SearchScope: String, CaseIterable, Identifiable, Sendable {
    case currentFolder
    case entireVolume

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currentFolder: return L10n.searchScopeFolder
        case .entireVolume: return L10n.searchScopeVolume
        }
    }

    var icon: String {
        switch self {
        case .currentFolder: return "folder"
        case .entireVolume: return "internaldrive"
        }
    }
}

enum SearchEngine: String, Sendable {
    case index
    case spotlight
    case filesystem
}

struct GlobalSearchResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let name: String
    let parentPath: String
    var size: Int64
    let isDirectory: Bool
    let fileKind: FileKind
    let modifiedDate: Date?
    let isHidden: Bool
    let matchScore: Int

    init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        parentPath: String,
        size: Int64 = 0,
        isDirectory: Bool = false,
        fileKind: FileKind? = nil,
        modifiedDate: Date? = nil,
        isHidden: Bool = false,
        matchScore: Int = 0
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.parentPath = parentPath
        self.size = size
        self.isDirectory = isDirectory
        self.fileKind = fileKind ?? FileKind.detect(url: url, isDirectory: isDirectory)
        self.modifiedDate = modifiedDate
        self.isHidden = isHidden
        self.matchScore = matchScore
    }

    var diskItem: DiskItem {
        DiskItem(
            url: url,
            name: name,
            size: size,
            isDirectory: isDirectory,
            isHidden: isHidden,
            modifiedDate: modifiedDate,
            fileKind: fileKind
        )
    }

    var formattedPath: String {
        let components = parentPath.split(separator: "/").suffix(3).map(String.init)
        guard !components.isEmpty else { return parentPath }
        return components.joined(separator: " › ")
    }
}

struct SearchIndexEntry: Codable, Sendable, Hashable {
    let path: String
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modifiedDate: Date?
    let fileKind: FileKind
    let isHidden: Bool

    var url: URL { URL(fileURLWithPath: path) }

    func matches(query: String) -> (matched: Bool, score: Int) {
        let q = query.lowercased()
        let nameLower = name.lowercased()

        if nameLower == q { return (true, 100) }
        if nameLower.hasPrefix(q) { return (true, 80) }
        if nameLower.contains(q) { return (true, 60) }
        if path.lowercased().contains(q) { return (true, 40) }
        return (false, 0)
    }
}

struct SearchIndexSnapshot: Codable, Sendable {
    let volumeID: String
    let builtAt: Date
    let entryCount: Int
    let entries: [SearchIndexEntry]
}

struct SearchProgress: Sendable {
    let scannedDirectories: Int
    let foundEntries: Int
    let currentPath: String
}
