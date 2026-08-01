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

    public static func relativeComponents(from path: URL, scanRoot: URL) -> [String] {
        let current = resolved(path).path
        let root = resolved(scanRoot).path

        guard current == root || current.hasPrefix(root + "/") else { return [] }

        var relative = String(current.dropFirst(root.count))
        if relative.hasPrefix("/") { relative = String(relative.dropFirst()) }
        if relative.isEmpty { return [] }

        return relative.split(separator: "/").map(String.init)
    }
}
