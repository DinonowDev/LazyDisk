import Foundation

struct DevJunkItem: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let category: String
    var size: Int64
}

struct DevScanProgress: Sendable {
    let scannedDirs: Int
    let found: Int
    let currentPath: String
    let fraction: Double
}

enum DevModeService {
    private static let junkFolderNames: Set<String> = [
        "node_modules", ".build", "DerivedData", "__pycache__", ".venv", "venv",
        ".next", ".turbo", "Pods", "Carthage", ".gradle", "target", "dist",
        "build", ".pytest_cache", ".mypy_cache", ".tox", ".cargo", "vendor",
        "bower_components", ".parcel-cache", ".nuxt", ".output", "cmake-build-debug",
        "cmake-build-release", ".swiftpm", "Package.resolved"
    ]

    private static let minSize: Int64 = 5 * 1024 * 1024

    private static func homePaths(_ components: String...) -> URL {
        components.reduce(FileManager.default.homeDirectoryForCurrentUser) { $0.appendingPathComponent($1) }
    }

    static func scan(
        roots: [URL]? = nil,
        onProgress: (@Sendable (DevScanProgress) -> Void)? = nil
    ) async -> [DevJunkItem] {
        let scanner = DiskScanner.shared
        var results: [DevJunkItem] = []
        var seen = Set<String>()
        let searchRoots = roots ?? defaultRoots()

        // Fixed Xcode paths are scanned via Smart Collections (.xcode) in the Browser panel.
        let specific: [(String, String, URL)] = [
            (".gradle", "Android/Java", homePaths(".gradle")),
            ("Cargo registry", "Rust", homePaths(".cargo/registry")),
            ("Go pkg mod", "Go", homePaths("go/pkg/mod")),
            ("Homebrew cache", "Homebrew", homePaths("Library/Caches/Homebrew")),
            ("Docker", "Docker", homePaths("Library/Containers/com.docker.docker")),
        ]

        for (name, category, url) in specific {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let path = url.path
            guard !seen.contains(path) else { continue }
            let size = await scanner.calculateSize(for: url)
            if size >= minSize {
                seen.insert(path)
                results.append(DevJunkItem(url: url, name: name, category: category, size: size))
            }
        }

        var scannedDirs = 0
        let fm = FileManager.default

        for root in searchRoots {
            var queue: [URL] = [root]
            var visited = Set<String>()

            while !queue.isEmpty {
                if Task.isCancelled { return results.sorted { $0.size > $1.size } }
                let current = queue.removeFirst()
                let path = current.path
                guard visited.insert(path).inserted else { continue }

                guard let contents = try? fm.contentsOfDirectory(
                    at: current,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                scannedDirs += 1
                if scannedDirs % 100 == 0 {
                    onProgress?(DevScanProgress(
                        scannedDirs: scannedDirs,
                        found: results.count,
                        currentPath: current.lastPathComponent,
                        fraction: min(0.95, Double(scannedDirs) / 50_000)
                    ))
                }

                for url in contents {
                    let name = url.lastPathComponent
                    if junkFolderNames.contains(name) {
                        let fullPath = url.path
                        guard !seen.contains(fullPath) else { continue }
                        let size = await scanner.calculateSize(for: url)
                        if size >= minSize {
                            seen.insert(fullPath)
                            results.append(DevJunkItem(
                                url: url,
                                name: name,
                                category: url.deletingLastPathComponent().lastPathComponent,
                                size: size
                            ))
                        }
                        continue
                    }

                    let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                    if values?.isDirectory == true {
                        // Skip known huge system dirs
                        if name == ".git" || name == "Library" && current.path == fm.homeDirectoryForCurrentUser.path {
                            continue
                        }
                        queue.append(url)
                    }
                }
            }
        }

        onProgress?(DevScanProgress(scannedDirs: scannedDirs, found: results.count, currentPath: "", fraction: 1))
        return results.sorted { $0.size > $1.size }
    }

    private static func defaultRoots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Projects"),
            home.appendingPathComponent("Developer"),
            home.appendingPathComponent("dev"),
            home.appendingPathComponent("code"),
            home,
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
    }
}
