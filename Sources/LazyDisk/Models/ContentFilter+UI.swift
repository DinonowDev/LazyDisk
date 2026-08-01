import Foundation

extension ContentFilter {
    var title: String {
        switch self {
        case .all: return L10n.filterAll
        case .folders: return L10n.filterFolders
        case .images: return L10n.filterImages
        case .videos: return L10n.filterVideos
        case .audio: return L10n.filterAudio
        case .documents: return L10n.filterDocuments
        case .archives: return L10n.filterArchives
        case .applications: return L10n.filterApps
        case .developer: return L10n.filterDeveloper
        case .other: return L10n.filterOther
        }
    }
}
