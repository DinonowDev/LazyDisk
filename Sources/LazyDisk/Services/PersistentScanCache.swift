import Foundation

actor PersistentScanCache {
    static let shared = PersistentScanCache()

    private static let cacheDirectory: URL = {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = appSupport.appendingPathComponent("LazyDisk/ScanCache", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init() {}

    func load(_ url: URL) -> CachedDirectory? {
        let fileURL = cacheFile(for: url)
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode(StoredCachedDirectory.self, from: data) else {
            return nil
        }

        guard Date().timeIntervalSince(stored.scannedAt) < 60 * 60 * 24 * 7 else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        return stored.cachedDirectory
    }

    func save(_ cached: CachedDirectory) {
        let fileURL = cacheFile(for: cached.url)
        let stored = StoredCachedDirectory(cachedDirectory: cached)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func invalidate(_ url: URL) {
        let prefix = PathUtils.resolved(url).path
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: Self.cacheDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            if name == sanitized(prefix) || name.hasPrefix(sanitized(prefix) + "_") {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func clear() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: Self.cacheDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func cacheFile(for url: URL) -> URL {
        Self.cacheDirectory
            .appendingPathComponent(sanitized(PathUtils.resolved(url).path))
            .appendingPathExtension("json")
    }

    private func sanitized(_ path: String) -> String {
        path
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "-")
    }
}

private struct StoredCachedDirectory: Codable {
    let url: URL
    let entries: [DiskItem]
    let scannedAt: Date
    let isVolumeRoot: Bool
    let contentLevel: ScanContentLevel?

    init(cachedDirectory: CachedDirectory) {
        url = cachedDirectory.url
        entries = cachedDirectory.entries
        scannedAt = cachedDirectory.scannedAt
        isVolumeRoot = cachedDirectory.isVolumeRoot
        contentLevel = cachedDirectory.contentLevel
    }

    var cachedDirectory: CachedDirectory {
        CachedDirectory(
            url: url,
            entries: entries,
            scannedAt: scannedAt,
            isVolumeRoot: isVolumeRoot,
            contentLevel: contentLevel ?? .full
        )
    }
}
