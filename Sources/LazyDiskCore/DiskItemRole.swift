import Foundation

public enum DiskItemRole: String, Codable, Sendable, Hashable {
    case regular
    case purgeable
    case unscanned
    case cloudSummary
    case snapshotGroup
    case snapshot
}
