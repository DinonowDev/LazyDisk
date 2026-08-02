import Foundation

/// Maps file paths to immediate child directories of a scan root, including macOS firmlink aliases.
public struct ChildPathMatcher: Sendable {
    public struct Entry: Sendable {
        public let canonical: String
        public let prefixes: [String]
    }

    public let rootPath: String
    public let entries: [Entry]

    public init(root: URL, children: [URL]) {
        rootPath = Self.normalizedDirectoryPath(PathUtils.resolved(root))
        entries = children.map { childURL in
            let canonical = PathUtils.resolved(childURL).path
            var prefixSet = Set<String>()
            prefixSet.insert(canonical + "/")

            let listed = childURL.standardizedFileURL.path
            if listed != canonical {
                prefixSet.insert(listed + "/")
            }

            let name = childURL.lastPathComponent
            if !name.isEmpty, name != ".", name != ".." {
                prefixSet.insert("/\(name)/")
            }

            return Entry(canonical: canonical, prefixes: Array(prefixSet))
        }
    }

    public func immediateChildKey(for filePath: String) -> String? {
        let standardized = URL(fileURLWithPath: filePath).standardizedFileURL.path
        let resolved = PathUtils.resolved(URL(fileURLWithPath: filePath)).path

        if let key = childKeyViaRootPrefix(standardized) { return key }
        if standardized != resolved, let key = childKeyViaRootPrefix(resolved) { return key }

        for entry in entries {
            for prefix in entry.prefixes {
                if standardized.hasPrefix(prefix) || resolved.hasPrefix(prefix) {
                    return entry.canonical
                }
            }
            if resolved == entry.canonical || standardized == entry.canonical {
                return entry.canonical
            }
        }

        return nil
    }

    public func relativeComponentsAfterChild(
        resolvedPath: String,
        childKey: String
    ) -> [String] {
        if resolvedPath.hasPrefix(childKey + "/") {
            let remainder = String(resolvedPath.dropFirst(childKey.count + 1))
            guard !remainder.isEmpty else { return [] }
            return remainder.split(separator: "/").map(String.init)
        }

        guard let entry = entries.first(where: { $0.canonical == childKey }) else { return [] }

        for prefix in entry.prefixes {
            let trimmed = prefix.hasSuffix("/") ? String(prefix.dropLast()) : prefix
            guard resolvedPath.hasPrefix(trimmed + "/") else { continue }
            let remainder = String(resolvedPath.dropFirst(trimmed.count + 1))
            guard !remainder.isEmpty else { return [] }
            return remainder.split(separator: "/").map(String.init)
        }

        return []
    }

    private func childKeyViaRootPrefix(_ path: String) -> String? {
        let rootPrefix = rootPath + "/"
        guard path.hasPrefix(rootPrefix) else { return nil }

        let relative = path[path.index(path.startIndex, offsetBy: rootPrefix.count)...]
        if let slash = relative.firstIndex(of: "/") {
            let rawChild = rootPath + "/" + relative[..<slash]
            return PathUtils.resolved(URL(fileURLWithPath: rawChild, isDirectory: true)).path
        }
        return path
    }

    private static func normalizedDirectoryPath(_ url: URL) -> String {
        var path = url.standardizedFileURL.path
        if path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }
}
