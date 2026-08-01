import Foundation

enum SmartCollection: String, CaseIterable, Identifiable, Sendable {
    case largeFiles
    case oldFiles
    case xcode
    case nodeModules
    case oldDownloads

    var id: String { rawValue }

    var title: String {
        switch self {
        case .largeFiles: return L10n.collectionLargeFiles
        case .oldFiles: return L10n.collectionOldFiles
        case .xcode: return L10n.collectionXcode
        case .nodeModules: return L10n.collectionNodeModules
        case .oldDownloads: return L10n.collectionOldDownloads
        }
    }

    var subtitle: String {
        switch self {
        case .largeFiles: return L10n.collectionLargeFilesDesc
        case .oldFiles: return L10n.collectionOldFilesDesc
        case .xcode: return L10n.collectionXcodeDesc
        case .nodeModules: return L10n.collectionNodeModulesDesc
        case .oldDownloads: return L10n.collectionOldDownloadsDesc
        }
    }

    var icon: String {
        switch self {
        case .largeFiles: return "doc.fill.badge.ellipsis"
        case .oldFiles: return "clock.badge.exclamationmark"
        case .xcode: return "hammer.fill"
        case .nodeModules: return "shippingbox.fill"
        case .oldDownloads: return "arrow.down.circle"
        }
    }
}

struct SmartCollectionProgress: Sendable {
    let scanned: Int
    let found: Int
    let status: String
    let fraction: Double
}
