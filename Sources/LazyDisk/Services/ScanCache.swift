import Foundation
import LazyDiskCore

struct CachedDirectory: Sendable {
    let url: URL
    var entries: [DiskItem]
    let scannedAt: Date
    let isVolumeRoot: Bool
    var contentLevel: ScanContentLevel

    init(
        url: URL,
        entries: [DiskItem],
        scannedAt: Date,
        isVolumeRoot: Bool,
        contentLevel: ScanContentLevel = .full
    ) {
        self.url = url
        self.entries = entries
        self.scannedAt = scannedAt
        self.isVolumeRoot = isVolumeRoot
        self.contentLevel = contentLevel
    }
}

actor ScanCache {
    static let shared = ScanCache()

    private var store: [String: CachedDirectory] = [:]
    private let persistent = PersistentScanCache.shared

    func key(for url: URL) -> String {
        PathUtils.resolved(url).path
    }

    func get(_ url: URL, usePersistent: Bool = true) async -> CachedDirectory? {
        let cacheKey = key(for: url)
        if let memory = store[cacheKey] {
            return memory
        }

        guard usePersistent, AppPreferences.load().usePersistentCache,
              let disk = await persistent.load(url) else {
            return nil
        }

        store[cacheKey] = disk
        return disk
    }

    func set(
        _ url: URL,
        entries: [DiskItem],
        isVolumeRoot: Bool,
        contentLevel: ScanContentLevel = .full
    ) async {
        let cached = CachedDirectory(
            url: url,
            entries: entries,
            scannedAt: Date(),
            isVolumeRoot: isVolumeRoot,
            contentLevel: contentLevel
        )
        store[key(for: url)] = cached

        if AppPreferences.load().usePersistentCache {
            await persistent.save(cached)
        }
    }

    func invalidate(_ url: URL) async {
        let prefix = key(for: url)
        store = store.filter { entryKey, _ in
            entryKey != prefix && !entryKey.hasPrefix(prefix + "/")
        }
        await persistent.invalidate(url)
    }

    func clear() async {
        store.removeAll()
        await persistent.clear()
    }

    func has(_ url: URL) async -> Bool {
        let cacheKey = key(for: url)
        if store[cacheKey] != nil { return true }
        guard AppPreferences.load().usePersistentCache,
              await persistent.load(url) != nil else {
            return false
        }
        return true
    }

    func isComplete(_ cached: CachedDirectory) -> Bool {
        !cached.entries.contains(where: \.isScanning)
    }

    func needsFullMetadata(_ cached: CachedDirectory) -> Bool {
        cached.contentLevel == .light
    }
}
