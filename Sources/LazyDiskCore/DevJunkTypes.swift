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

public enum DevJunkSortOrder: String, CaseIterable, Sendable, Identifiable {
    case sizeDescending
    case sizeAscending
    case nameAscending
    case nameDescending
    case dateDescending
    case dateAscending
    case projectAscending
    case projectDescending
    case ecosystemAscending
    case purposeAscending

    public var id: String { rawValue }

    public func sort(_ items: [DevJunkItem]) -> [DevJunkItem] {
        switch self {
        case .sizeDescending:
            return items.sorted { $0.size > $1.size }
        case .sizeAscending:
            return items.sorted { $0.size < $1.size }
        case .nameAscending:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .dateDescending:
            return items.sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
        case .dateAscending:
            return items.sorted { ($0.modifiedAt ?? .distantPast) < ($1.modifiedAt ?? .distantPast) }
        case .projectAscending:
            return items.sorted {
                let l = $0.projectName ?? $0.name
                let r = $1.projectName ?? $1.name
                let cmp = l.localizedCaseInsensitiveCompare(r)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return $0.size > $1.size
            }
        case .projectDescending:
            return items.sorted {
                let l = $0.projectName ?? $0.name
                let r = $1.projectName ?? $1.name
                let cmp = l.localizedCaseInsensitiveCompare(r)
                if cmp != .orderedSame { return cmp == .orderedDescending }
                return $0.size > $1.size
            }
        case .ecosystemAscending:
            return items.sorted {
                if $0.ecosystem != $1.ecosystem { return $0.ecosystem.rawValue < $1.ecosystem.rawValue }
                return $0.size > $1.size
            }
        case .purposeAscending:
            return items.sorted {
                if $0.purpose != $1.purpose { return $0.purpose.rawValue < $1.purpose.rawValue }
                return $0.size > $1.size
            }
        }
    }

    public func sortProjectGroups(_ groups: [(key: String, items: [DevJunkItem])]) -> [(key: String, items: [DevJunkItem])] {
        groups
            .map { (key: $0.key, items: sort($0.items)) }
            .sorted { lhs, rhs in
                switch self {
                case .sizeDescending:
                    return lhs.items.reduce(0) { $0 + $1.size } > rhs.items.reduce(0) { $0 + $1.size }
                case .sizeAscending:
                    return lhs.items.reduce(0) { $0 + $1.size } < rhs.items.reduce(0) { $0 + $1.size }
                case .nameAscending, .projectAscending:
                    return groupLabel(lhs).localizedCaseInsensitiveCompare(groupLabel(rhs)) == .orderedAscending
                case .nameDescending, .projectDescending:
                    return groupLabel(lhs).localizedCaseInsensitiveCompare(groupLabel(rhs)) == .orderedDescending
                case .dateDescending:
                    return maxDate(lhs) > maxDate(rhs)
                case .dateAscending:
                    return maxDate(lhs) < maxDate(rhs)
                case .ecosystemAscending:
                    return (lhs.items.first?.ecosystem.rawValue ?? "") < (rhs.items.first?.ecosystem.rawValue ?? "")
                case .purposeAscending:
                    return (lhs.items.first?.purpose.rawValue ?? "") < (rhs.items.first?.purpose.rawValue ?? "")
                }
            }
    }

    public func sortPurposeGroups(_ groups: [(purpose: DevJunkPurpose, items: [DevJunkItem])]) -> [(purpose: DevJunkPurpose, items: [DevJunkItem])] {
        groups
            .map { (purpose: $0.purpose, items: sort($0.items)) }
            .sorted { lhs, rhs in
                switch self {
                case .sizeDescending:
                    return lhs.items.reduce(0) { $0 + $1.size } > rhs.items.reduce(0) { $0 + $1.size }
                case .sizeAscending:
                    return lhs.items.reduce(0) { $0 + $1.size } < rhs.items.reduce(0) { $0 + $1.size }
                case .purposeAscending:
                    return lhs.purpose.rawValue < rhs.purpose.rawValue
                case .ecosystemAscending:
                    return (lhs.items.first?.ecosystem.rawValue ?? "") < (rhs.items.first?.ecosystem.rawValue ?? "")
                case .nameAscending, .projectAscending:
                    return lhs.purpose.rawValue < rhs.purpose.rawValue
                case .nameDescending, .projectDescending:
                    return lhs.purpose.rawValue > rhs.purpose.rawValue
                case .dateDescending:
                    return maxDate(lhs.items) > maxDate(rhs.items)
                case .dateAscending:
                    return maxDate(lhs.items) < maxDate(rhs.items)
                }
            }
    }

    private func groupLabel(_ group: (key: String, items: [DevJunkItem])) -> String {
        if group.key == "__global__" { return "zzz_global" }
        return group.items.first?.projectName ?? group.key.components(separatedBy: "/").last ?? group.key
    }

    private func maxDate(_ group: (key: String, items: [DevJunkItem])) -> Date {
        maxDate(group.items)
    }

    private func maxDate(_ items: [DevJunkItem]) -> Date {
        items.compactMap(\.modifiedAt).max() ?? .distantPast
    }
}
