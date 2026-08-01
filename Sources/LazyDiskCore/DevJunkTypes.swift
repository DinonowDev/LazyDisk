import Foundation

public enum DevJunkEcosystem: String, CaseIterable, Sendable, Hashable {
    case javascript, typescript, python, rust, go, swift, java, kotlin, ruby, php, dart
    case docker, homebrew, ios, android, web, csharp, general

    public var icon: String {
        switch self {
        case .javascript: return "js.square.fill"
        case .typescript: return "t.square.fill"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .rust: return "gearshape.2.fill"
        case .go: return "g.circle.fill"
        case .swift: return "swift"
        case .java: return "cup.and.saucer.fill"
        case .kotlin: return "k.circle.fill"
        case .ruby: return "diamond.fill"
        case .php: return "p.circle.fill"
        case .dart: return "d.circle.fill"
        case .docker: return "shippingbox.fill"
        case .homebrew: return "mug.fill"
        case .ios: return "iphone"
        case .android: return "a.circle.fill"
        case .web: return "globe"
        case .csharp: return "c.circle.fill"
        case .general: return "folder.fill"
        }
    }
}

public enum DevJunkPurpose: String, CaseIterable, Sendable, Hashable {
    case dependencies
    case buildOutput
    case buildCache
    case devServerCache
    case testCache
    case languageCache
    case packageManager
    case runtimeData
    case tooling

    public var icon: String {
        switch self {
        case .dependencies: return "shippingbox.fill"
        case .buildOutput: return "hammer.fill"
        case .buildCache: return "archivebox.fill"
        case .devServerCache: return "bolt.fill"
        case .testCache: return "checkmark.seal.fill"
        case .languageCache: return "memorychip.fill"
        case .packageManager: return "arrow.down.circle.fill"
        case .runtimeData: return "externaldrive.fill"
        case .tooling: return "wrench.and.screwdriver.fill"
        }
    }
}

public enum DevJunkSafety: Sendable, Hashable {
    case safe
    case rebuild
    case caution

    public var icon: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .rebuild: return "arrow.clockwise.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        }
    }
}

public enum DevJunkFolderKind: String, Sendable, Equatable {
    case nodeModules, swiftBuild, pycache, venv, next, turbo, pods, carthage, gradle
    case rustTarget, dist, build, pytestCache, mypyCache, tox, cargoRegistry, vendor
    case bowerComponents, parcelCache, nuxt, output, cmakeDebug, cmakeRelease, swiftpm
    case packageResolved, goPkgMod, homebrewCache, dockerData, gradleGlobal, cargoDir
    case generic
}

public struct DevJunkItem: Identifiable, Sendable {
    public let id = UUID()
    public let url: URL
    public let name: String
    public let size: Int64
    public let folderKind: DevJunkFolderKind
    public let ecosystem: DevJunkEcosystem
    public let purpose: DevJunkPurpose
    public let safety: DevJunkSafety
    public let projectName: String?
    public let projectPath: URL?
    public let modifiedAt: Date?

    public init(
        url: URL,
        name: String,
        size: Int64,
        folderKind: DevJunkFolderKind,
        ecosystem: DevJunkEcosystem,
        purpose: DevJunkPurpose,
        safety: DevJunkSafety,
        projectName: String?,
        projectPath: URL?,
        modifiedAt: Date?
    ) {
        self.url = url
        self.name = name
        self.size = size
        self.folderKind = folderKind
        self.ecosystem = ecosystem
        self.purpose = purpose
        self.safety = safety
        self.projectName = projectName
        self.projectPath = projectPath
        self.modifiedAt = modifiedAt
    }

    public var isGlobal: Bool { projectPath == nil }

    public var groupKey: String {
        if let path = projectPath { return path.path }
        return "__global__"
    }
}

public struct DevJunkSummary: Sendable {
    public let totalSize: Int64
    public let itemCount: Int
    public let projectCount: Int
    public let globalCount: Int
    public let byEcosystem: [DevJunkEcosystem: Int64]
    public let byPurpose: [DevJunkPurpose: Int64]
}
