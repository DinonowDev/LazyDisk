import Foundation

public enum DeletePathAnalyzer {
    public enum WarningKind: String, CaseIterable, Sendable {
        case iosBackup
        case timeMachine
        case systemPath
        case runningApplication
        case sensitiveLibrary
        case cloudPlaceholder
        case purgeableVolume
    }

    public static func warningKinds(for url: URL) -> [WarningKind] {
        var kinds: [WarningKind] = []
        if isIOSBackup(url) { kinds.append(.iosBackup) }
        if isTimeMachineRelated(url) { kinds.append(.timeMachine) }
        if isCriticalSystemPath(url) { kinds.append(.systemPath) }
        if isSensitiveLibraryPath(url) { kinds.append(.sensitiveLibrary) }
        if isCloudPlaceholder(url) { kinds.append(.cloudPlaceholder) }
        return kinds
    }

    public static func isIOSBackup(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        return path.contains("/mobilesync/backup")
            || path.contains("/application support/mobilesync/backup")
    }

    public static func isTimeMachineRelated(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        return path.contains(".timemachine")
            || path.contains("backups.backupdb")
            || path.contains("com.apple.timemachine")
    }

    public static func isCriticalSystemPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let critical = ["/System", "/usr", "/bin", "/sbin", "/private/var/db"]
        return critical.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    public static func isSensitiveLibraryPath(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        let sensitive = [
            "/library/keychains",
            "/library/mail",
            "/library/messages",
            "/library/safari",
            "/library/application support/addressbook",
        ]
        return sensitive.contains { path.contains($0) }
    }

    /// Standard macOS Library folders that must not be moved to Trash as a whole.
    /// Delete individual items inside them (e.g. `~/Library/Caches/Homebrew`) instead.
    public static func isCloudPlaceholder(_ url: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return false }
        guard values.isUbiquitousItem == true else { return false }
        return values.ubiquitousItemDownloadingStatus == .notDownloaded
    }

    /// Warn when the boot volume reports large purgeable space (deletes may not free disk immediately).
    public static func shouldWarnPurgeableVolume(purgeableBytes: Int64, totalBytes: Int64) -> Bool {
        guard totalBytes > 0, purgeableBytes > 500_000_000 else { return false }
        return Double(purgeableBytes) / Double(totalBytes) > 0.08
    }

    public static func isLibraryContainerPath(_ url: URL) -> Bool {
        let path = PathUtils.resolved(url).path
        let homeLibrary = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .standardizedFileURL.path
        if path == homeLibrary { return true }
        guard path.hasPrefix(homeLibrary + "/") else { return false }
        let tail = String(path.dropFirst(homeLibrary.count + 1))
        let blockedRoots = [
            "Caches",
            "Logs",
            "Application Support",
            "Containers",
            "Preferences"
        ]
        return blockedRoots.contains { tail == $0 }
    }
}
