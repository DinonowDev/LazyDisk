import Foundation

public enum ByteFormatter {
    private static let units = ["B", "KB", "MB", "GB", "TB", "PB"]

    public static func string(from bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }

        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(bytes) B"
        }

        let format = value >= 100 ? "%.0f %@" : value >= 10 ? "%.1f %@" : "%.2f %@"
        return String(format: format, value, units[unitIndex])
    }
}
