import Foundation

public enum FileKind: String, Codable, CaseIterable, Sendable {
    case folder
    case image
    case video
    case audio
    case document
    case archive
    case application
    case developer
    case other

    public static func detect(url: URL, isDirectory: Bool) -> FileKind {
        if isDirectory { return .folder }

        let ext = url.pathExtension.lowercased()
        let path = url.path.lowercased()

        if url.pathExtension == "app" || path.hasSuffix(".app") { return .application }

        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "bmp", "tiff", "svg", "raw":
            return .image
        case "mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm":
            return .video
        case "mp3", "wav", "aac", "flac", "m4a", "ogg", "aiff":
            return .audio
        case "pdf", "doc", "docx", "txt", "rtf", "pages", "md", "csv", "xls", "xlsx", "ppt", "pptx", "key":
            return .document
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso":
            return .archive
        case "swift", "m", "h", "c", "cpp", "js", "ts", "py", "rb", "go", "rs", "java", "kt":
            return .developer
        default:
            return .other
        }
    }
}
