import Foundation

/// Builds sunburst `chartChildMap` entries from prefetched `ScanCache` listings.
public enum CachedScanChartBuilder {
    public static func childMap(
        scanRoot: URL,
        rootEntries: [DiskItem],
        maxScanDepth: Int,
        maxChildrenPerNode: Int,
        cachedEntries: (URL) -> [DiskItem]?
    ) -> [String: [DiskItem]] {
        let rootPath = PathUtils.resolved(scanRoot).path
        var map: [String: [DiskItem]] = [:]

        let rootChildren = visibleChildren(from: rootEntries, maxChildrenPerNode: maxChildrenPerNode)
        if !rootChildren.isEmpty {
            map[rootPath] = rootChildren
        }

        guard maxScanDepth >= 1 else { return map }

        var queue: [(path: String, depth: Int)] = rootChildren
            .filter { $0.isDirectory && !$0.isVirtual }
            .map { (PathUtils.resolved($0.url).path, 1) }

        var seen = Set(queue.map(\.path))

        while !queue.isEmpty {
            let (parentPath, depth) = queue.removeFirst()
            guard depth <= maxScanDepth else { continue }

            let parentURL = URL(fileURLWithPath: parentPath, isDirectory: true)
            guard let entries = cachedEntries(parentURL) else { continue }

            let children = visibleChildren(from: entries, maxChildrenPerNode: maxChildrenPerNode)
            if !children.isEmpty {
                map[parentPath] = children
            }

            guard depth < maxScanDepth else { continue }

            for child in children where child.isDirectory && !child.isVirtual {
                let childPath = PathUtils.resolved(child.url).path
                if seen.insert(childPath).inserted {
                    queue.append((childPath, depth + 1))
                }
            }
        }

        return map
    }

    private static func visibleChildren(
        from entries: [DiskItem],
        maxChildrenPerNode: Int
    ) -> [DiskItem] {
        Array(
            entries
                .filter { !$0.isVirtual && ($0.size > 0 || $0.isDirectory) }
                .sorted { $0.size > $1.size }
                .prefix(maxChildrenPerNode)
        )
    }
}
