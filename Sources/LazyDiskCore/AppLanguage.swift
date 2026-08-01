import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable, Codable {
    case system
    case english
    case persian
    case chinese
    case french
    case arabic
    case turkish

    public var id: String { rawValue }

    public static func fromSystemLocale() -> AppLanguage {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        switch code {
        case "fa": return .persian
        case "zh", "zh-Hans", "zh-Hant": return .chinese
        case "fr": return .french
        case "ar": return .arabic
        case "tr": return .turkish
        default: return .english
        }
    }
}
