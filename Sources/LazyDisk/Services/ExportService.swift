import Foundation
import AppKit
import LazyDiskCore

enum ExportService {
    static func exportCSV(entries: [DiskItem], to url: URL) throws {
        var lines = ["Name,Path,Size,Kind,Modified"]
        let formatter = ISO8601DateFormatter()

        for item in entries where !item.isVirtual {
            let name = csvEscape(item.name)
            let path = csvEscape(item.url.path)
            let size = "\(item.size)"
            let kind = csvEscape(item.fileKind.rawValue)
            let modified = item.modifiedDate.map { formatter.string(from: $0) } ?? ""
            lines.append("\(name),\(path),\(size),\(kind),\(modified)")
        }

        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    static func exportJSON(
        entries: [DiskItem],
        to url: URL,
        scanMetrics: NativeScanMetrics? = nil,
        folderPath: String? = nil
    ) throws {
        struct ExportRow: Codable {
            let name: String
            let path: String
            let size: Int64
            let kind: String
            let modified: Date?
        }

        struct ScanMetricsExport: Codable {
            let cloneBytesMerged: Int64
            let cloneGroupsMerged: Int32
            let hardlinkFilesSkipped: Int64
        }

        struct ExportDocument: Codable {
            let folderPath: String?
            let scanMetrics: ScanMetricsExport?
            let entries: [ExportRow]
        }

        let rows = entries.filter { !$0.isVirtual }.map {
            ExportRow(name: $0.name, path: $0.url.path, size: $0.size, kind: $0.fileKind.rawValue, modified: $0.modifiedDate)
        }

        let metricsPayload = scanMetrics.map {
            ScanMetricsExport(
                cloneBytesMerged: $0.cloneBytesMerged,
                cloneGroupsMerged: $0.cloneGroupsMerged,
                hardlinkFilesSkipped: $0.hardlinkFilesSkipped
            )
        }

        let document = ExportDocument(folderPath: folderPath, scanMetrics: metricsPayload, entries: rows)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        try data.write(to: url)
    }

    static func savePanel(format: String, defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = []
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
