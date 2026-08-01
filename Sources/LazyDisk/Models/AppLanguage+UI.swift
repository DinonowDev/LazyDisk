import Foundation

extension AppLanguage {
    var title: String {
        switch self {
        case .system: return L10n.langSystem
        case .english: return LocalizationCatalog.text(.english, language: .english)
        case .persian: return LocalizationCatalog.text(.persian, language: .persian)
        case .chinese: return LocalizationCatalog.text(.chinese, language: .chinese)
        case .french: return LocalizationCatalog.text(.french, language: .french)
        case .arabic: return LocalizationCatalog.text(.arabic, language: .arabic)
        case .turkish: return LocalizationCatalog.text(.turkish, language: .turkish)
        }
    }
}
