import Foundation

public enum DevJunkMetadata {
    public struct FolderSpec: Sendable {
        public let kind: DevJunkFolderKind
        public let ecosystem: DevJunkEcosystem
        public let purpose: DevJunkPurpose
        public let safety: DevJunkSafety
    }

    private static let folderSpecs: [String: FolderSpec] = [
        "node_modules": FolderSpec(kind: .nodeModules, ecosystem: .javascript, purpose: .dependencies, safety: .safe),
        ".build": FolderSpec(kind: .swiftBuild, ecosystem: .swift, purpose: .buildOutput, safety: .rebuild),
        "__pycache__": FolderSpec(kind: .pycache, ecosystem: .python, purpose: .languageCache, safety: .safe),
        ".venv": FolderSpec(kind: .venv, ecosystem: .python, purpose: .dependencies, safety: .safe),
        "venv": FolderSpec(kind: .venv, ecosystem: .python, purpose: .dependencies, safety: .safe),
        ".next": FolderSpec(kind: .next, ecosystem: .web, purpose: .devServerCache, safety: .rebuild),
        ".turbo": FolderSpec(kind: .turbo, ecosystem: .web, purpose: .devServerCache, safety: .safe),
        "Pods": FolderSpec(kind: .pods, ecosystem: .ios, purpose: .dependencies, safety: .rebuild),
        "Carthage": FolderSpec(kind: .carthage, ecosystem: .ios, purpose: .tooling, safety: .rebuild),
        ".gradle": FolderSpec(kind: .gradle, ecosystem: .android, purpose: .buildCache, safety: .safe),
        "target": FolderSpec(kind: .rustTarget, ecosystem: .rust, purpose: .buildOutput, safety: .rebuild),
        "dist": FolderSpec(kind: .dist, ecosystem: .javascript, purpose: .buildOutput, safety: .rebuild),
        "build": FolderSpec(kind: .build, ecosystem: .general, purpose: .buildOutput, safety: .rebuild),
        ".pytest_cache": FolderSpec(kind: .pytestCache, ecosystem: .python, purpose: .testCache, safety: .safe),
        ".mypy_cache": FolderSpec(kind: .mypyCache, ecosystem: .python, purpose: .languageCache, safety: .safe),
        ".tox": FolderSpec(kind: .tox, ecosystem: .python, purpose: .testCache, safety: .safe),
        ".cargo": FolderSpec(kind: .cargoDir, ecosystem: .rust, purpose: .packageManager, safety: .caution),
        "vendor": FolderSpec(kind: .vendor, ecosystem: .php, purpose: .dependencies, safety: .rebuild),
        "bower_components": FolderSpec(kind: .bowerComponents, ecosystem: .javascript, purpose: .dependencies, safety: .safe),
        ".parcel-cache": FolderSpec(kind: .parcelCache, ecosystem: .web, purpose: .devServerCache, safety: .safe),
        ".nuxt": FolderSpec(kind: .nuxt, ecosystem: .web, purpose: .devServerCache, safety: .rebuild),
        ".output": FolderSpec(kind: .output, ecosystem: .web, purpose: .buildOutput, safety: .rebuild),
        "cmake-build-debug": FolderSpec(kind: .cmakeDebug, ecosystem: .general, purpose: .buildOutput, safety: .rebuild),
        "cmake-build-release": FolderSpec(kind: .cmakeRelease, ecosystem: .general, purpose: .buildOutput, safety: .rebuild),
        ".swiftpm": FolderSpec(kind: .swiftpm, ecosystem: .swift, purpose: .buildCache, safety: .safe),
        "Package.resolved": FolderSpec(kind: .packageResolved, ecosystem: .swift, purpose: .tooling, safety: .caution),
    ]

    private static let globalTargets: [(name: String, kind: DevJunkFolderKind, ecosystem: DevJunkEcosystem, purpose: DevJunkPurpose, safety: DevJunkSafety, pathComponents: [String])] = [
        (".gradle", .gradleGlobal, .android, .buildCache, .safe, [".gradle"]),
        ("Cargo registry", .cargoRegistry, .rust, .packageManager, .caution, [".cargo", "registry"]),
        ("Go pkg mod", .goPkgMod, .go, .packageManager, .caution, ["go", "pkg", "mod"]),
        ("Homebrew cache", .homebrewCache, .homebrew, .packageManager, .safe, ["Library", "Caches", "Homebrew"]),
        ("Docker", .dockerData, .docker, .runtimeData, .caution, ["Library", "Containers", "com.docker.docker"]),
    ]

    public static var scannableFolderNames: Set<String> { Set(folderSpecs.keys) }

    public static func globalScanTargets() -> [(name: String, url: URL)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return globalTargets.map { target in
            let url = target.pathComponents.reduce(home) { $0.appendingPathComponent($1) }
            return (target.name, url)
        }
    }

    public static func spec(forFolderName name: String) -> FolderSpec {
        folderSpecs[name] ?? FolderSpec(kind: .generic, ecosystem: .general, purpose: .buildCache, safety: .caution)
    }

    public static func spec(forGlobal name: String) -> FolderSpec? {
        guard let target = globalTargets.first(where: { $0.name == name }) else { return nil }
        return FolderSpec(kind: target.kind, ecosystem: target.ecosystem, purpose: target.purpose, safety: target.safety)
    }

    // MARK: - Project detection

    private struct Marker {
        let file: String
        let ecosystem: DevJunkEcosystem
    }

    private static let markers: [Marker] = [
        Marker(file: "package.json", ecosystem: .javascript),
        Marker(file: "pnpm-lock.yaml", ecosystem: .javascript),
        Marker(file: "yarn.lock", ecosystem: .javascript),
        Marker(file: "bun.lockb", ecosystem: .javascript),
        Marker(file: "tsconfig.json", ecosystem: .typescript),
        Marker(file: "Cargo.toml", ecosystem: .rust),
        Marker(file: "go.mod", ecosystem: .go),
        Marker(file: "pyproject.toml", ecosystem: .python),
        Marker(file: "setup.py", ecosystem: .python),
        Marker(file: "requirements.txt", ecosystem: .python),
        Marker(file: "Pipfile", ecosystem: .python),
        Marker(file: "Package.swift", ecosystem: .swift),
        Marker(file: "pubspec.yaml", ecosystem: .dart),
        Marker(file: "Gemfile", ecosystem: .ruby),
        Marker(file: "composer.json", ecosystem: .php),
        Marker(file: "build.gradle", ecosystem: .android),
        Marker(file: "build.gradle.kts", ecosystem: .kotlin),
        Marker(file: "settings.gradle", ecosystem: .android),
        Marker(file: "pom.xml", ecosystem: .java),
        Marker(file: "*.csproj", ecosystem: .csharp),
    ]

    public static func detectProject(near url: URL, hintEcosystem: DevJunkEcosystem) -> (name: String, path: URL, ecosystem: DevJunkEcosystem)? {
        let fm = FileManager.default
        var current = url.deletingLastPathComponent()

        for _ in 0..<25 {
            if let project = projectAt(current, fm: fm) {
                let eco = project.ecosystem == .general ? hintEcosystem : project.ecosystem
                return (project.name, project.path, eco)
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        return nil
    }

    private static func projectAt(_ dir: URL, fm: FileManager) -> (name: String, path: URL, ecosystem: DevJunkEcosystem)? {
        for marker in markers {
            if marker.file.hasPrefix("*.") {
                let ext = String(marker.file.dropFirst(2))
                if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                    if contents.contains(where: { $0.pathExtension == ext }) {
                        return (dir.lastPathComponent, dir, marker.ecosystem)
                    }
                }
                continue
            }
            let markerURL = dir.appendingPathComponent(marker.file)
            if fm.fileExists(atPath: markerURL.path) {
                return (dir.lastPathComponent, dir, marker.ecosystem)
            }
        }

        if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            if contents.contains(where: { ["xcodeproj", "xcworkspace"].contains($0.pathExtension) }) {
                return (dir.lastPathComponent, dir, .ios)
            }
        }
        return nil
    }

    public static func makeItem(
        url: URL,
        name: String,
        size: Int64,
        isGlobal: Bool = false,
        globalName: String? = nil
    ) -> DevJunkItem {
        let folderSpec: FolderSpec
        if isGlobal, let globalName, let globalSpec = spec(forGlobal: globalName) {
            folderSpec = globalSpec
        } else {
            folderSpec = spec(forFolderName: name)
        }

        var projectName: String?
        var projectPath: URL?
        var ecosystem = folderSpec.ecosystem

        if !isGlobal, let project = detectProject(near: url, hintEcosystem: folderSpec.ecosystem) {
            projectName = project.name
            projectPath = project.path
            if folderSpec.ecosystem == .general || folderSpec.ecosystem == .web {
                ecosystem = project.ecosystem
            }
        }

        let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

        return DevJunkItem(
            url: url,
            name: name,
            size: size,
            folderKind: folderSpec.kind,
            ecosystem: ecosystem,
            purpose: folderSpec.purpose,
            safety: folderSpec.safety,
            projectName: projectName,
            projectPath: projectPath,
            modifiedAt: modifiedAt
        )
    }

    public static func summarize(_ items: [DevJunkItem]) -> DevJunkSummary {
        var byEco: [DevJunkEcosystem: Int64] = [:]
        var byPurpose: [DevJunkPurpose: Int64] = [:]
        var projects = Set<String>()

        for item in items {
            byEco[item.ecosystem, default: 0] += item.size
            byPurpose[item.purpose, default: 0] += item.size
            if let path = item.projectPath?.path {
                projects.insert(path)
            }
        }

        return DevJunkSummary(
            totalSize: items.reduce(0) { $0 + $1.size },
            itemCount: items.count,
            projectCount: projects.count,
            globalCount: items.filter(\.isGlobal).count,
            byEcosystem: byEco,
            byPurpose: byPurpose
        )
    }
}
