import Foundation

struct FolderBookmark: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let addedAt: Date

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        self.addedAt = Date()
    }
}

enum NavigationHistoryService {
    private static let recentKey = "LazyDisk.recentFolders"
    private static let bookmarksKey = "LazyDisk.bookmarks"
    private static let maxRecent = 15

    static func recentFolders() -> [URL] {
        guard let data = UserDefaults.standard.data(forKey: recentKey),
              let paths = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return paths.map { URL(fileURLWithPath: $0, isDirectory: true) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func recordVisit(_ url: URL) {
        var paths = recentFolders().map(\.path)
        let path = PathUtils.resolved(url).path
        paths.removeAll { $0 == path }
        paths.insert(path, at: 0)
        paths = Array(paths.prefix(maxRecent))
        if let data = try? JSONEncoder().encode(paths) {
            UserDefaults.standard.set(data, forKey: recentKey)
        }
    }

    static func bookmarks() -> [FolderBookmark] {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey),
              let decoded = try? JSONDecoder().decode([FolderBookmark].self, from: data) else { return [] }
        return decoded.filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    static func addBookmark(_ url: URL) {
        var items = bookmarks()
        let resolved = PathUtils.resolved(url)
        guard !items.contains(where: { $0.url.path == resolved.path }) else { return }
        items.insert(FolderBookmark(url: resolved), at: 0)
        saveBookmarks(items)
    }

    static func removeBookmark(_ bookmark: FolderBookmark) {
        var items = bookmarks()
        items.removeAll { $0.id == bookmark.id }
        saveBookmarks(items)
    }

    static func isBookmarked(_ url: URL) -> Bool {
        let path = PathUtils.resolved(url).path
        return bookmarks().contains { $0.url.path == path }
    }

    private static func saveBookmarks(_ items: [FolderBookmark]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }
}
