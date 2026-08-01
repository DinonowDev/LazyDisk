import Foundation

extension FileKind {
    var title: String {
        switch self {
        case .folder: return L10n.filterFolders
        case .image: return L10n.filterImages
        case .video: return L10n.filterVideos
        case .audio: return L10n.filterAudio
        case .document: return L10n.filterDocuments
        case .archive: return L10n.filterArchives
        case .application: return L10n.filterApps
        case .developer: return L10n.filterDeveloper
        case .other: return L10n.filterOther
        }
    }

    var icon: String {
        switch self {
        case .folder: return "folder.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .audio: return "music.note"
        case .document: return "doc.fill"
        case .archive: return "doc.zipper.fill"
        case .application: return "app.fill"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .other: return "doc.fill"
        }
    }
}
