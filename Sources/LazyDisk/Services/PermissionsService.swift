import AppKit
import Foundation

enum PermissionKind: String, CaseIterable, Identifiable, Sendable {
    case fullDiskAccess
    case userFiles
    case removableVolumes
    case cleanupAccess

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullDiskAccess: return L10n.permFullDiskTitle
        case .userFiles: return L10n.permUserFilesTitle
        case .removableVolumes: return L10n.permRemovableTitle
        case .cleanupAccess: return L10n.permCleanupTitle
        }
    }

    var description: String {
        switch self {
        case .fullDiskAccess: return L10n.permFullDiskDesc
        case .userFiles: return L10n.permUserFilesDesc
        case .removableVolumes: return L10n.permRemovableDesc
        case .cleanupAccess: return L10n.permCleanupDesc
        }
    }

    var icon: String {
        switch self {
        case .fullDiskAccess: return "internaldrive.fill"
        case .userFiles: return "folder.fill"
        case .removableVolumes: return "externaldrive.fill"
        case .cleanupAccess: return "trash.fill"
        }
    }
}

struct PermissionItem: Identifiable, Equatable, Sendable {
    let kind: PermissionKind
    var isGranted: Bool

    var id: String { kind.id }
    var title: String { kind.title }
    var description: String { kind.description }
    var icon: String { kind.icon }
}

enum PermissionsService {
    static var isRunningAsAppBundle: Bool {
        Bundle.main.bundlePath.hasSuffix(".app")
    }

    static var hostAppName: String {
        if isRunningAsAppBundle {
            return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "LazyDisk"
        }
        return ProcessInfo.processInfo.processName
    }

    static func checkAll() -> [PermissionItem] {
        PermissionKind.allCases.map { kind in
            PermissionItem(kind: kind, isGranted: check(kind))
        }
    }

    static var allGranted: Bool {
        checkAll().allSatisfy(\.isGranted)
    }

    /// Probe protected paths (may trigger system prompts) then open Privacy settings once.
    static func requestAll() {
        probeProtectedPaths()
        openPrivacySettings()
    }

    static func openPrivacySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security"
        ]

        for urlString in urls {
            if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    static func openFullDiskAccessSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ]

        for urlString in urls {
            if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                return
            }
        }
        openPrivacySettings()
    }

    // MARK: - Private

    private static func check(_ kind: PermissionKind) -> Bool {
        switch kind {
        case .fullDiskAccess:
            return checkFullDiskAccess()
        case .userFiles:
            return checkUserFilesAccess()
        case .removableVolumes:
            return checkRemovableVolumesAccess()
        case .cleanupAccess:
            return checkCleanupAccess()
        }
    }

    private static func checkFullDiskAccess() -> Bool {
        // Require access to multiple protected locations — not just one passing path
        let protectedPaths = [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            "/private/var/db/SystemPolicy",
            "/private/var/root",
            "/Library/Caches/com.apple.amsengagementd"
        ]

        let readableCount = protectedPaths.filter {
            FileManager.default.isReadableFile(atPath: $0)
        }.count

        if readableCount >= 2 { return true }

        // Strong fallback: read Safari bookmarks (TCC-protected without FDA)
        let safariBookmarks = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari/Bookmarks.plist")
        guard FileManager.default.fileExists(atPath: safariBookmarks.path) else {
            // No Safari — if we can read /private/var, that's enough
            return FileManager.default.isReadableFile(atPath: "/private/var")
        }
        return (try? Data(contentsOf: safariBookmarks)) != nil
    }

    private static func checkUserFilesAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folders = ["Documents", "Desktop", "Downloads", "Library"]
        return folders.allSatisfy { folder in
            let url = home.appendingPathComponent(folder)
            return FileManager.default.isReadableFile(atPath: url.path)
        }
    }

    private static func checkRemovableVolumesAccess() -> Bool {
        let volumesURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return false }

        // No external volumes — treat as granted if we can list /Volumes
        let external = contents.filter { $0.lastPathComponent != "Macintosh HD" && $0.lastPathComponent != "Recovery" }
        if external.isEmpty { return true }

        return external.allSatisfy {
            FileManager.default.isReadableFile(atPath: $0.path)
        }
    }

    private static func checkCleanupAccess() -> Bool {
        let trashURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash")
        return FileManager.default.isWritableFile(atPath: trashURL.path)
            || checkFullDiskAccess()
    }

    private static func probeProtectedPaths() {
        let urls: [URL] = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches"),
            URL(fileURLWithPath: "/Library"),
            URL(fileURLWithPath: "/Library/Caches"),
            URL(fileURLWithPath: "/private/var"),
            URL(fileURLWithPath: "/private/var/folders"),
            URL(fileURLWithPath: "/System/Volumes/Data"),
            URL(fileURLWithPath: "/Volumes")
        ]

        for url in urls {
            _ = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            _ = FileManager.default.isReadableFile(atPath: url.path)
        }
    }
}
