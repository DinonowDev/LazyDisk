import Foundation

public enum PathUtils {
    public static func resolved(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }

    public static func isWithinVolume(_ path: URL, scanRoot: URL) -> Bool {
        let current = resolved(path).path
        let root = resolved(scanRoot).path
        return current == root || current.hasPrefix(root + "/")
    }

    /// Paths to try when matching native scan stats to a listed directory (firmlink vs data volume).
    public static func directorySizeLookupCandidates(itemURL: URL, scanRoot: URL) -> [String] {
        var seen = Set<String>()
        var candidates: [String] = []

        func append(_ path: String) {
            guard !path.isEmpty, seen.insert(path).inserted else { return }
            candidates.append(path)
        }

        append(resolved(itemURL).path)
        append(itemURL.standardizedFileURL.path)

        var root = resolved(scanRoot).path
        if root.count > 1, root.hasSuffix("/") {
            root.removeLast()
        }
        let name = itemURL.lastPathComponent
        if !name.isEmpty, name != ".", name != ".." {
            append((root as NSString).appendingPathComponent(name))
            if name != root {
                append("/" + name)
            }
        }
        return candidates
    }

    public static func directorySize(
        in statsByPath: [String: Int64],
        itemURL: URL,
        scanRoot: URL
    ) -> Int64? {
        for path in directorySizeLookupCandidates(itemURL: itemURL, scanRoot: scanRoot) {
            if let size = statsByPath[path], size > 0 {
                return size
            }
        }
        return nil
    }

    public static func relativeComponents(from path: URL, scanRoot: URL) -> [String] {
        let current = resolved(path).path
        let root = resolved(scanRoot).path

        guard current == root || current.hasPrefix(root + "/") else { return [] }

        var relative = String(current.dropFirst(root.count))
        if relative.hasPrefix("/") { relative = String(relative.dropFirst()) }
        if relative.isEmpty { return [] }

        return relative.split(separator: "/").map(String.init)
    }

    /// Longest shared directory prefix for incremental subtree rescans.
    public static func commonDirectoryAncestor(paths: [String], fallback: String) -> String {
        guard let first = paths.first else { return fallback }
        var prefix = first
        for path in paths.dropFirst() {
            prefix = commonPathPrefix(prefix, path)
            if prefix.isEmpty {
                return fallback
            }
        }
        if prefix.isEmpty || prefix == "/" {
            return fallback
        }
        if let slash = prefix.lastIndex(of: "/"), slash > prefix.startIndex {
            let trimmed = String(prefix[prefix.startIndex..<slash])
            return trimmed.isEmpty ? fallback : trimmed
        }
        return prefix
    }

    private static func commonPathPrefix(_ left: String, _ right: String) -> String {
        let minCount = min(left.count, right.count)
        var index = 0
        while index < minCount {
            let leftIndex = left.index(left.startIndex, offsetBy: index)
            let rightIndex = right.index(right.startIndex, offsetBy: index)
            if left[leftIndex] != right[rightIndex] {
                break
            }
            index += 1
        }
        return String(left.prefix(index))
    }
}
