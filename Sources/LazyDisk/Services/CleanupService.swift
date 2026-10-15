import Foundation
import LazyDiskCore

struct CleanupDeleteResult {
    let succeeded: [URL]
    let failed: [(URL, Error)]
    let trashedItemURLs: [URL]

    var hadFailures: Bool { !failed.isEmpty }
}

enum CleanupService {
    /// Prefer Trash (recoverable) like DaisyDisk; does not fall back to permanent delete when Trash refuses.
    static func deleteItems(urls: [URL], useTrash: Bool = true) throws -> CleanupDeleteResult {
        var succeeded: [URL] = []
        var failed: [(URL, Error)] = []
        var trashed: [URL] = []

        for url in urls {
            do {
                let trashedURL = try deleteItem(at: url, useTrash: useTrash)
                succeeded.append(url)
                if let trashedURL {
                    trashed.append(trashedURL)
                }
            } catch {
                failed.append((url, error))
            }
        }

        let result = CleanupDeleteResult(succeeded: succeeded, failed: failed, trashedItemURLs: trashed)
        if succeeded.isEmpty, let first = failed.first?.1 {
            throw first
        }
        if result.hadFailures {
            throw CleanupError.partialFailure(result)
        }
        return result
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

        let path = PathUtils.resolved(url).path
        if protectedPaths.contains(path) { return false }
        return !protectedPaths.contains { protected in
            path.hasPrefix(protected + "/") && protected != "/"
        }
    }

    // MARK: - Private

    @discardableResult
    private static func deleteItem(at url: URL, useTrash: Bool) throws -> URL? {
        let target = PackageDeleteSupport.deletionTarget(for: url)
        if useTrash {
            if let trashed = tryMoveToTrash(target) {
                return trashed
            }
            throw CleanupError.trashRefused(target)
        }
        try FileManager.default.removeItem(at: target)
        return nil
    }

    private static func tryMoveToTrash(_ url: URL) -> URL? {
        var trashedURL: NSURL?
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
            return trashedURL as URL?
        } catch {
            return nil
        }
    }
}

enum CleanupError: LocalizedError {
    case nothingDeletable(URL)
    case trashRefused(URL)
    case partialFailure(CleanupDeleteResult)

    var errorDescription: String? {
        switch self {
        case .nothingDeletable(let url):
            return "“\(url.lastPathComponent)” couldn’t be deleted because you don’t have permission to access it."
        case .trashRefused(let url):
            return "“\(url.lastPathComponent)” couldn’t be moved to the Trash. Nothing was permanently deleted."
        case .partialFailure(let result):
            let names = result.failed.map { $0.0.lastPathComponent }.joined(separator: ", ")
            return "Some items could not be deleted: \(names). \(result.succeeded.count) item(s) were removed."
        }
    }
}
