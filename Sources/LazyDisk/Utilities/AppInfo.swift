import Foundation

enum AppInfo {
    static let name = "LazyDisk"
    static let developer = "Amirhossein Rezaei"
    static let githubURL = "https://github.com/DinonowDev/LazyDisk"
    static let copyrightYear = "2026"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var versionString: String {
        "\(version) (\(build))"
    }
}
