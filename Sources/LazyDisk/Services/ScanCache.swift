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
        // Virtual reconcile items (System/Unscanned, purgeable, etc.) are display-only.
        let persistable = entries.filter { !$0.isVirtual }
        let cached = CachedDirectory(
            url: url,
            entries: persistable,
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
        guard !cached.entries.contains(where: \.isScanning) else { return false }
        guard !cached.entries.contains(where: \.isVirtual) else { return false }

        if cached.isVolumeRoot {
            let directories = cached.entries.filter { $0.isDirectory && !$0.isVirtual }
            guard !directories.isEmpty else { return false }
            guard directories.contains(where: { $0.size > 0 }) else { return false }
        }

        return true
    }

    func needsFullMetadata(_ cached: CachedDirectory) -> Bool {
        cached.contentLevel == .light
    }

    func hasRestorableVolumeRoot(_ scanRoot: URL) async -> Bool {
        guard AppPreferences.load().usePersistentCache,
              let cached = await get(scanRoot, usePersistent: true),
              isComplete(cached),
              !cached.entries.isEmpty else {
            return false
        }
        return true
    }
}
