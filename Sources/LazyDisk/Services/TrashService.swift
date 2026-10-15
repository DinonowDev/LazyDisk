import Foundation

enum TrashService {
    /// Removes only the given trash URLs (from a recent `trashItem` call), not the entire Trash folder.
    static func removeTrashedItems(at urls: [URL]) throws {
        var lastError: Error?
        var removedAny = false
        for item in urls {
            guard FileManager.default.fileExists(atPath: item.path) else { continue }
            do {
                try FileManager.default.removeItem(at: item)
                removedAny = true
            } catch {
                lastError = error
            }
        }
        if !removedAny, let lastError {
            throw lastError
        }
    }
}
