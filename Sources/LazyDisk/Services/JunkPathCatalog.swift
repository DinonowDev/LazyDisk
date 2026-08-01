import Foundation

/// Shared junk-path definitions so Browse (Smart Collections), Cleanup, and Dev panels
/// do not scan the same targets twice.
enum JunkPathCatalog {
    struct Target: Sendable {
        let name: String
        let url: URL
    }

    // MARK: - Xcode (owned by Smart Collections → .xcode)

    static var xcodeTargets: [Target] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            Target(name: "DerivedData", url: home.appendingPathComponent("Library/Developer/Xcode/DerivedData")),
            Target(name: "Archives", url: home.appendingPathComponent("Library/Developer/Xcode/Archives")),
            Target(name: "DeviceSupport", url: home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport")),
            Target(name: "CoreSimulator", url: home.appendingPathComponent("Library/Developer/CoreSimulator")),
        ]
    }

    // MARK: - Panel ownership

    /// Collections that replace overlapping Cleanup / Dev scans.
    static let browseOwnedCollections: [SmartCollection] = [.xcode, .nodeModules, .oldDownloads]

    static func collections(for panel: AppPanel) -> [SmartCollection] {
        switch panel {
        case .cleanup: return [.oldDownloads]
        case .dev: return [.xcode, .nodeModules]
        default: return []
        }
    }
}
