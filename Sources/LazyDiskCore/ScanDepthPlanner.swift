import Foundation

public enum ScanDepthPlanner {
    /// Path depth relative to `scanRoot` (root = 0, its children = 1, …).
    public static func depth(of url: URL, scanRoot: URL) -> Int? {
        let rootPath = PathUtils.resolved(scanRoot).path
        let targetPath = PathUtils.resolved(url).path
        if targetPath == rootPath { return 0 }
        guard targetPath.hasPrefix(rootPath + "/") else { return nil }
        return PathUtils.relativeComponents(from: url, scanRoot: scanRoot).count
    }

    /// Directories exactly `depth` levels below `scanRoot`, discovered via cached parent listings.
    public static func directories(
        atDepth depth: Int,
        scanRoot: URL,
        rootEntries: [DiskItem],
        childEntries: (URL) -> [DiskItem]?
    ) -> [DiskItem] {
        guard depth >= 1 else { return [] }

        if depth == 1 {
            return rootEntries
                .filter { $0.isDirectory && !$0.isVirtual }
                .sorted { $0.size > $1.size }
        }

        let parents = directories(
            atDepth: depth - 1,
            scanRoot: scanRoot,
            rootEntries: rootEntries,
            childEntries: childEntries
        )

        var seen = Set<String>()
        var result: [DiskItem] = []

        for parent in parents {
            guard let children = childEntries(parent.url) else { continue }
            for child in children where child.isDirectory && !child.isVirtual {
                let path = PathUtils.resolved(child.url).path
                if seen.insert(path).inserted {
                    result.append(child)
                }
            }
        }

        return result.sorted { $0.size > $1.size }
    }
}
