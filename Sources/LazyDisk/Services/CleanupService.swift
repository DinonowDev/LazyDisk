import Foundation

enum CleanupService {
    static func moveToTrash(urls: [URL]) throws -> [URL] {
        var trashedURLs: [URL] = []

        for url in urls {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
            if let resultingURL {
                trashedURLs.append(resultingURL as URL)
            }
        }

        return trashedURLs
    }

    static func canDelete(url: URL) -> Bool {
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
}
