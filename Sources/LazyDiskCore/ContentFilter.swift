import Foundation

public enum ContentFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case folders
    case images
    case videos
    case audio
    case documents
    case archives
    case applications
    case developer
    case other

    public var id: String { rawValue }

    public func matches(_ item: DiskItem) -> Bool {
        switch self {
        case .all: return true
        case .folders: return item.isDirectory && !item.isVirtual
        case .images: return item.fileKind == .image
        case .videos: return item.fileKind == .video
        case .audio: return item.fileKind == .audio
        case .documents: return item.fileKind == .document
        case .archives: return item.fileKind == .archive
        case .applications: return item.fileKind == .application
        case .developer: return item.fileKind == .developer
        case .other: return item.fileKind == .other && !item.isDirectory
        }
    }
}
