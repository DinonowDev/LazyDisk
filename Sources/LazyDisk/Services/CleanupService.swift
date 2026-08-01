import Foundation
import LazyDiskCore

enum CleanupService {
    static func deleteItems(urls: [URL]) throws {
        var lastError: Error?
        var anySucceeded = false

        for url in urls {
            do {
                try deleteItem(at: url)
                anySucceeded = true
            } catch {
                lastError = error
            }
        }

        if !anySucceeded, let lastError {
            throw lastError
        }
    }

    static func canDelete(url: URL) -> Bool {
        if DeletePathAnalyzer.isLibraryContainerPath(url) { return false }

        let protectedPaths = [
            "/",
            "/System",
            "/usr",
            "/bin",
            "/sbin",
            "/var",
            "/private",
            "/Library",
            "/Applications"
        ]

        let path = url.standardizedFileURL.path
        return !protectedPaths.contains(path)
    }

    // MARK: - Private

    private static func deleteItem(at url: URL) throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            guard directoryExists(at: url) else { throw error }
            try deleteDirectoryContents(at: url)
        }
    }

    private static func deleteDirectoryContents(at url: URL) throws {
        let children = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var deletedCount = 0
        var childErrors: [Error] = []

        for child in children {
            do {
                try deleteItem(at: child)
                deletedCount += 1
            } catch {
                childErrors.append(error)
            }
        }

        guard deletedCount > 0 else {
            throw childErrors.first ?? CleanupError.nothingDeletable(url)
        }
    }

    private static func directoryExists(at url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}

enum CleanupError: LocalizedError {
    case nothingDeletable(URL)

    var errorDescription: String? {
        switch self {
        case .nothingDeletable(let url):
            return "“\(url.lastPathComponent)” couldn’t be deleted because you don’t have permission to access it."
        }
    }
}
