import Foundation
import ServiceManagement

public enum PrivilegedHelperInstaller {
    public static let helperLabel = PrivilegedScanMachService.bundleIdentifier

    private static let daemonPlistName = "\(helperLabel).plist"

    private static var daemonService: SMAppService {
        SMAppService.daemon(plistName: daemonPlistName)
    }

    public enum InstallError: LocalizedError {
        case notAppBundle
        case blessFailed(String)
        case helperMissingFromBundle

        public var errorDescription: String? {
            switch self {
            case .notAppBundle:
                return "Admin helper can only be installed from LazyDisk.app."
            case .blessFailed(let message):
                return message
            case .helperMissingFromBundle:
                return "Privileged helper binary is missing from the app bundle."
            }
        }
    }

    public static func isHelperJobRegistered() -> Bool {
        daemonService.status == .enabled
    }

    public static func bundledHelperURL() -> URL? {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return nil }
        return Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchServices/\(helperLabel)")
    }

    public static func install() throws {
        guard Bundle.main.bundlePath.hasSuffix(".app") else {
            throw InstallError.notAppBundle
        }
        guard let helperURL = bundledHelperURL(), FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            throw InstallError.helperMissingFromBundle
        }

        do {
            try daemonService.register()
        } catch {
            throw InstallError.blessFailed(error.localizedDescription)
        }
    }
}
