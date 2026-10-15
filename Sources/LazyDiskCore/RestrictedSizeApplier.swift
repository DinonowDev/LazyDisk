import Foundation

public enum RestrictedSizeApplier {
    /// Applies privileged/FDA sizes to listed entries and the shared size index; returns paths that were sized.
    public static func apply(
        sizes: [String: Int64],
        scanRoot: URL?,
        entries: [DiskItem]
    ) async -> (entries: [DiskItem], resolvedPaths: [String]) {
        var updated = entries
        var resolvedPaths: [String] = []
        for (path, size) in sizes where size > 0 {
            let normalized = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
            await DirectorySizeIndex.shared.storeSize(size, for: normalized)

            if let index = bestMatchingEntryIndex(path: normalized, scanRoot: scanRoot, in: updated) {
                if updated[index].size < size {
                    updated[index].size = size
                    updated[index].isScanning = false
                }
            }
            resolvedPaths.append(normalized)
        }
        return (updated, resolvedPaths)
    }

    private static func bestMatchingEntryIndex(
        path: String,
        scanRoot: URL?,
        in entries: [DiskItem]
    ) -> Int? {
        if let exact = entries.firstIndex(where: { PathUtils.resolved($0.url).path == path }) {
            return exact
        }
        guard let scanRoot else { return nil }
        let rootPath = PathUtils.resolved(scanRoot).path
        guard path == rootPath || path.hasPrefix(rootPath + "/") else { return nil }

        var best: (index: Int, length: Int)?
        for (index, entry) in entries.enumerated() where !entry.isVirtual {
            let entryPath = PathUtils.resolved(entry.url).path
            if path == entryPath || path.hasPrefix(entryPath + "/") {
                let length = entryPath.count
                if best == nil || length > best!.length {
                    best = (index, length)
                }
            }
        }
        return best?.index
    }
}

public enum RestrictedScanRegistrar {
    public static func record(_ events: [RestrictedScanEvent]) async {
        guard !events.isEmpty else { return }
        await RestrictedScanCoordinator.shared.register(events)
    }

    public static func recordWalk(_ walk: DirectorySizeWalker.WalkResult) async {
        await record(walk.restrictedScanEvents)
    }
}
