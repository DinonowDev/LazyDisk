import Foundation

public enum APFSSnapshotName {
    public static func isDeletable(_ raw: String) -> Bool {
        guard !raw.isEmpty, !raw.contains("/") else { return false }
        if raw.hasPrefix("com.apple.os.update-") { return false }
        if raw.hasPrefix("com.apple.os.install") { return false }
        if raw.hasPrefix("com.apple.bless") { return false }
        return true
    }

    public static func date(from raw: String) -> Date? {
        guard let match = raw.range(of: #"\d{4}-\d{2}-\d{2}-\d{6}"#, options: .regularExpression) else {
            return nil
        }
        let stamp = String(raw[match])
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone.current
        parser.dateFormat = "yyyy-MM-dd-HHmmss"
        return parser.date(from: stamp)
    }

    public static func displayName(raw: String, created: Date?) -> String {
        let moment = created ?? date(from: raw)
        if let moment {
            return displayFormatter.string(from: moment)
        }
        return raw
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
