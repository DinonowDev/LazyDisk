import Foundation

/// Heuristic Full Disk Access detection using TCC-protected paths (no private API).
public enum FullDiskAccessProbe {
    public static func isGranted(fileManager: FileManager = .default) -> Bool {
        if canReadBytes(at: "/Library/Application Support/com.apple.TCC/TCC.db", fileManager: fileManager) {
            return true
        }

        let home = fileManager.homeDirectoryForCurrentUser

        if probeProtectedDirectory(
            home.appendingPathComponent("Library/Safari").path,
            fileManager: fileManager
        ) {
            return true
        }

        if probeProtectedDirectory(
            home.appendingPathComponent("Library/Messages").path,
            fileManager: fileManager
        ) {
            return true
        }

        if probeProtectedDirectory(
            home.appendingPathComponent("Library/Mail").path,
            fileManager: fileManager
        ) {
            return true
        }

        let userProtectedFiles = [
            home.appendingPathComponent("Library/Safari/Bookmarks.plist").path,
            home.appendingPathComponent("Library/Messages/chat.db").path
        ]
        if userProtectedFiles.contains(where: { canReadBytes(at: $0, fileManager: fileManager) }) {
            return true
        }

        let systemPaths = [
            "/private/var/db/SystemPolicy",
            "/private/var/db/SystemPolicy-configuration",
            "/private/var/root",
            "/Library/Caches/com.apple.amsengagementd"
        ]
        if systemPaths.contains(where: { canReadBytes(at: $0, fileManager: fileManager) }) {
            return true
        }

        return false
    }

    /// If the folder exists, FDA is granted only when we can list it (TCC blocks listing without FDA).
    private static func probeProtectedDirectory(_ path: String, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }
        return canListDirectory(at: path, fileManager: fileManager)
    }

    private static func canReadBytes(at path: String, fileManager: FileManager) -> Bool {
        guard fileManager.fileExists(atPath: path) else { return false }
        if let handle = FileHandle(forReadingAtPath: path) {
            try? handle.close()
            return true
        }
        let url = URL(fileURLWithPath: path)
        return (try? Data(contentsOf: url, options: [.mappedIfSafe])) != nil
    }

    private static func canListDirectory(at path: String, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }
        return (try? fileManager.contentsOfDirectory(atPath: path)) != nil
    }
}
