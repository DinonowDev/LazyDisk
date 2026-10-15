import Foundation

/// Package / bundle aware deletion (`.app`, `.photoslibrary`, `.bundle`, …).
public enum PackageDeleteSupport {
    private static let packageExtensions: Set<String> = [
        "app", "bundle", "framework", "plugin", "kext", "photoslibrary", "xcodeproj", "xcworkspace"
    ]

    public static func isPackage(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if packageExtensions.contains(ext) { return true }
        if let values = try? url.resourceValues(forKeys: [.isPackageKey]), values.isPackage == true {
            return true
        }
        return false
    }

    /// Trash/delete the package as a single unit (no manual “deserialize” of internals).
    public static func deletionTarget(for url: URL) -> URL {
        url.standardizedFileURL
    }
}
