import Foundation

public enum DeletePathAnalyzer {
    public enum WarningKind: String, CaseIterable, Sendable {
        case iosBackup
        case timeMachine
        case systemPath
        case runningApplication
        case sensitiveLibrary
    }

    public static func warningKinds(for url: URL) -> [WarningKind] {
        var kinds: [WarningKind] = []
        if isIOSBackup(url) { kinds.append(.iosBackup) }
        if isTimeMachineRelated(url) { kinds.append(.timeMachine) }
        if isCriticalSystemPath(url) { kinds.append(.systemPath) }
        if isSensitiveLibraryPath(url) { kinds.append(.sensitiveLibrary) }
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
    public static func isLibraryContainerPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        if path.hasSuffix("/Library") { return true }
        guard let range = path.range(of: "/Library/", options: .backwards) else { return false }
        let tail = String(path[range.upperBound...])
        return tail == "Caches" || tail == "Logs"
    }
}
