import AppKit
import Foundation

enum DeleteWarningService {
    static func analyze(
        urls: [URL],
        volumePurgeableBytes: Int64? = nil,
        volumeTotalBytes: Int64? = nil
    ) -> [DeleteWarning] {
        var warnings: [DeleteWarning] = []

        let iosBackup = urls.filter { DeletePathAnalyzer.isIOSBackup($0) }
        if !iosBackup.isEmpty {
            warnings.append(DeleteWarning(
                title: L10n.warnIOSBackupTitle,
                message: L10n.warnIOSBackupMsg,
                severity: .danger,
                paths: iosBackup.map(\.path)
            ))
        }

        let timeMachine = urls.filter { DeletePathAnalyzer.isTimeMachineRelated($0) }
        if !timeMachine.isEmpty {
            warnings.append(DeleteWarning(
                title: L10n.warnTimeMachineTitle,
                message: L10n.warnTimeMachineMsg,
                severity: .caution,
                paths: timeMachine.map(\.path)
            ))
        }

        let systemPaths = urls.filter { DeletePathAnalyzer.isCriticalSystemPath($0) }
        if !systemPaths.isEmpty {
            warnings.append(DeleteWarning(
                title: L10n.warnSystemTitle,
                message: L10n.warnSystemMsg,
                severity: .danger,
                paths: systemPaths.map(\.path)
            ))
        }

        let runningApps = urls.filter { isRunningApplication($0) }
        if !runningApps.isEmpty {
            warnings.append(DeleteWarning(
                title: L10n.warnRunningAppTitle,
                message: L10n.warnRunningAppMsg,
                severity: .caution,
                paths: runningApps.map(\.path)
            ))
        }

        let librarySensitive = urls.filter { DeletePathAnalyzer.isSensitiveLibraryPath($0) }
        if !librarySensitive.isEmpty {
            warnings.append(DeleteWarning(
                title: L10n.warnLibraryTitle,
                message: L10n.warnLibraryMsg,
                severity: .caution,
                paths: librarySensitive.map(\.path)
            ))
        }

        if urls.count > 10 {
            warnings.append(DeleteWarning(
                title: L10n.warnBulkDeleteTitle,
                message: L10n.warnBulkDeleteMsg(urls.count),
                severity: .info,
                paths: []
            ))
        }

        let cloudItems = urls.filter { DeletePathAnalyzer.isCloudPlaceholder($0) }
        if !cloudItems.isEmpty {
            warnings.append(DeleteWarning(
                title: L10n.warnCloudPlaceholderTitle,
                message: L10n.warnCloudPlaceholderMsg,
                severity: .caution,
                paths: cloudItems.map(\.path)
            ))
        }

        if let purgeable = volumePurgeableBytes,
           let total = volumeTotalBytes,
           DeletePathAnalyzer.shouldWarnPurgeableVolume(purgeableBytes: purgeable, totalBytes: total) {
            warnings.append(DeleteWarning(
                title: L10n.warnPurgeableVolumeTitle,
                message: L10n.warnPurgeableVolumeMsg,
                severity: .info,
                paths: []
            ))
        }

        return warnings
    }

    static func summaryMessage(for warnings: [DeleteWarning], itemCount: Int, totalSize: Int64) -> String {
        let size = ByteFormatter.string(from: totalSize)
        var message = L10n.deleteSummary(count: itemCount, size: size)

        if !warnings.isEmpty {
            message += "\n\n"
            message += warnings.map(\.message).joined(separator: "\n\n")
        }

        return message
    }

    private static func isRunningApplication(_ url: URL) -> Bool {
        guard url.pathExtension == "app" else { return false }
        let bundleID = Bundle(url: url)?.bundleIdentifier
        guard let bundleID else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}
