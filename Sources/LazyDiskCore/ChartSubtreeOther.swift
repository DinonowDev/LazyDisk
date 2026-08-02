import Foundation

/// Virtual "Other" bucket in chart child maps — aggregates deferred small subtrees.
public enum ChartSubtreeOther {
  public static let pathSuffix = "/@lazydisk-chart-other"

  public static func virtualPath(under parentPath: String) -> String {
    parentPath + pathSuffix
  }

  public static func isVirtualOther(_ path: String) -> Bool {
    path.hasSuffix(pathSuffix)
  }

  public static func parentPath(ofVirtualOther path: String) -> String? {
    guard isVirtualOther(path) else { return nil }
    return String(path.dropLast(pathSuffix.count))
  }

  public static func stableID(parentPath: String) -> UUID {
    let h1 = fnv1a64(parentPath)
    let h2 = fnv1a64(parentPath + ":chart-other")
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

  private static func fnv1a64(_ string: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in string.utf8 {
      hash ^= UInt64(byte)
      hash = hash &* 0x100000001b3
    }
    return hash
  }
}
