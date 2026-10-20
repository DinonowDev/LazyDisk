import Foundation
import LazyDiskFS

public enum FileReclaimProbe {
    public static func cloneReferenceCount(atPath path: String) -> UInt32 {
        var count: UInt32 = 0
        let rc = path.withCString { ldfs_clone_reference_count($0, &count) }
        return rc == 0 ? count : 0
    }
}

private struct SnapshotJSON: Decodable {
    let name: String
    let created: Int64
    let bytes: Int64
}

public enum APFSSnapshotStore {
    public static func list(volumePath: String) -> [APFSSnapshot] {
        var jsonPointer: UnsafeMutablePointer<CChar>?
        let rc = volumePath.withCString { ldfs_list_snapshots_json($0, &jsonPointer) }
        guard rc == 0, let jsonPointer else { return [] }
        defer { free(jsonPointer) }
        let json = String(cString: jsonPointer)
        guard let data = json.data(using: .utf8),
              let rows = try? JSONDecoder().decode([SnapshotJSON].self, from: data) else {
            return []
        }
        return rows.compactMap { row in
            guard !row.name.isEmpty, !row.name.contains("/") else { return nil }
            let created = row.created > 0 ? Date(timeIntervalSince1970: TimeInterval(row.created)) : nil
            let bytes: Int64? = row.bytes >= 0 ? row.bytes : nil
            return APFSSnapshot(name: row.name, created: created, byteCount: bytes)
        }
    }

    public static func delete(name: String, volumePath: String) throws {
        let rc = name.withCString { namePointer in
            volumePath.withCString { pathPointer in
                ldfs_delete_snapshot(pathPointer, namePointer)
            }
        }
        guard rc == 0 else {
            throw NSError(
                domain: "LazyDisk.Snapshots",
                code: Int(-rc),
                userInfo: [NSLocalizedDescriptionKey: "Could not delete snapshot \(name)."]
            )
        }
    }
}
