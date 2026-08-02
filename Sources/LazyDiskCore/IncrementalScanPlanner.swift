import Foundation

/// Compares a fresh directory listing with cached entries to plan an incremental rescan.
public enum IncrementalScanPlanner {
    public struct Plan: Sendable, Equatable {
        public let mergedEntries: [DiskItem]
        public let directoriesToRescan: [URL]
        public let pathsToInvalidate: [String]

        public var needsRescan: Bool { !directoriesToRescan.isEmpty }
    }

    public static func plan(listed: [DiskItem], cached: [DiskItem]?) -> Plan {
        guard let cached, !cached.isEmpty else {
            let directories = listed
                .filter { $0.isDirectory && !$0.isVirtual }
                .map(\.url)
            return Plan(
                mergedEntries: listed,
                directoriesToRescan: directories,
                pathsToInvalidate: []
            )
        }

        let cachedByPath = Dictionary(
            uniqueKeysWithValues: cached.map { (PathUtils.resolved($0.url).path, $0) }
        )
        let listedPaths = Set(listed.map { PathUtils.resolved($0.url).path })

        var pathsToInvalidate: [String] = cachedByPath.keys
            .filter { !listedPaths.contains($0) }
            .sorted()

        var directoriesToRescan: [URL] = []
        var merged: [DiskItem] = []

        for item in listed {
            let path = PathUtils.resolved(item.url).path

            guard let previous = cachedByPath[path] else {
                merged.append(preparedListedItem(item))
                if item.isDirectory && !item.isVirtual {
                    directoriesToRescan.append(item.url)
                }
                continue
            }

            if entryUnchanged(listed: item, cached: previous) {
                merged.append(preserveCachedEntry(listed: item, cached: previous))
                continue
            }

            if item.isDirectory && !item.isVirtual {
                pathsToInvalidate.append(path)
                directoriesToRescan.append(item.url)
            }
            merged.append(preparedListedItem(item))
        }

        return Plan(
            mergedEntries: merged,
            directoriesToRescan: directoriesToRescan,
            pathsToInvalidate: pathsToInvalidate
        )
    }

    private static func entryUnchanged(listed: DiskItem, cached: DiskItem) -> Bool {
        if listed.isDirectory {
            // Directories with no cached size were never sized — must rescan.
            guard cached.size > 0, !cached.isScanning else { return false }
            return datesMatch(listed.modifiedDate, cached.modifiedDate)
        }

        if listed.size != cached.size { return false }
        return datesMatch(listed.modifiedDate, cached.modifiedDate)
    }

    private static func datesMatch(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case let (left?, right?):
            return left == right
        case (nil, nil):
            return true
        default:
            return false
        }
    }

    private static func preserveCachedEntry(listed: DiskItem, cached: DiskItem) -> DiskItem {
        var merged = listed
        if cached.size > 0 {
            merged.size = cached.size
        }
        merged.isScanning = cached.isScanning && cached.size == 0
        if merged.isScanning == false || cached.size > 0 {
            merged.isScanning = false
        }
        return merged
    }

    private static func preparedListedItem(_ item: DiskItem) -> DiskItem {
        var copy = item
        if copy.isDirectory && !copy.isVirtual {
            copy.isScanning = true
            copy.size = 0
        }
        return copy
    }
}
