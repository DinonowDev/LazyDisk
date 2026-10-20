import Foundation

public enum VirtualDiskPath {
    public static let prefix = "/.lazydisk-virtual"

    public static func snapshotGroup(volumePath: String) -> URL {
        URL(fileURLWithPath: "\(prefix)/snapshots/\(token(volumePath))", isDirectory: true)
    }

    public static func snapshot(volumePath: String, name: String) -> URL {
        snapshotGroup(volumePath: volumePath).appendingPathComponent(name, isDirectory: false)
    }

    public static func isSnapshotGroup(_ url: URL) -> Bool {
        let parts = url.path.split(separator: "/").map(String.init)
        return parts.count == 3 && parts[0] == ".lazydisk-virtual" && parts[1] == "snapshots"
    }

    public static func isVirtual(_ url: URL) -> Bool {
        url.path == prefix || url.path.hasPrefix(prefix + "/")
    }

    public static func stableID(for key: String) -> UUID {
        let h1 = fnv1a64(key)
        let h2 = fnv1a64(key + ":lazydisk")
        var bytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: h1.bigEndian) { buffer in
            for (index, byte) in buffer.enumerated() {
                bytes[index] = byte
            }
        }
        withUnsafeBytes(of: h2.bigEndian) { buffer in
            for (index, byte) in buffer.enumerated() {
                bytes[index + 8] = byte
            }
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func token(_ volumePath: String) -> String {
        if volumePath == "/" { return "root" }
        return volumePath
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .replacingOccurrences(of: "/", with: "_")
    }

    private static func fnv1a64(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
