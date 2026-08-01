import Foundation

enum GoalSuggestionCategory: String, Sendable, CaseIterable {
    case cache
    case logs
    case trash
    case installers
    case oldDownloads
    case largeDownloads
    case oldFiles
    case devJunk
    case other

    var icon: String {
        switch self {
        case .cache: return "memorychip.fill"
        case .logs: return "doc.text.fill"
        case .trash: return "trash.fill"
        case .installers: return "shippingbox.fill"
        case .oldDownloads: return "clock.arrow.circlepath"
        case .largeDownloads: return "arrow.down.circle.fill"
        case .oldFiles: return "calendar.badge.clock"
        case .devJunk: return "chevron.left.forwardslash.chevron.right"
        case .other: return "folder.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .cache: return 0
        case .logs: return 1
        case .trash: return 2
        case .installers: return 3
        case .oldDownloads: return 4
        case .largeDownloads: return 5
        case .devJunk: return 6
        case .oldFiles: return 7
        case .other: return 9
        }
    }
}

struct GoalSuggestion: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let category: GoalSuggestionCategory
    let reason: String
    var size: Int64
    let score: Int
    let modifiedDate: Date?

    var daysSinceModified: Int? {
        guard let modifiedDate else { return nil }
        return max(0, Int(Date().timeIntervalSince(modifiedDate) / 86_400))
    }
}

struct GoalScanProgress: Sendable {
    let currentTask: String
    let completed: Int
    let total: Int
    let fraction: Double
}

enum GoalSuggestionService {
    private static let minSuggestionSize: Int64 = 5 * 1024 * 1024
    private static let oldDownloadAge: TimeInterval = 30 * 86_400
    private static let oldFileAge: TimeInterval = 180 * 86_400
    private static let largeDownloadThreshold: Int64 = 100 * 1024 * 1024
    private static let minOldFileSize: Int64 = 10 * 1024 * 1024
    private static let maxResults = 80

    static func scan(
        volumeRoot: URL,
        neededBytes: Int64,
        excludePaths: Set<String> = [],
        onProgress: (@Sendable (GoalScanProgress) -> Void)? = nil
    ) async -> [GoalSuggestion] {
        var results: [GoalSuggestion] = []
        let home = FileManager.default.homeDirectoryForCurrentUser

        let phases: [(String, () async -> [GoalSuggestion])] = [
            ("Caches & junk", {
                await scanCleanupTargets(volumeRoot: volumeRoot)
            }),
            ("Old Downloads", {
                await scanOldDownloads(home: home)
            }),
            ("Large Downloads", {
                await scanLargeDownloads(home: home)
            }),
            ("Unused files", {
                await scanOldFiles(home: home, volumeRoot: volumeRoot)
            }),
            ("Developer junk", {
                await scanDevPaths()
            }),
        ]

        let total = phases.count
        for (index, (label, phase)) in phases.enumerated() {
            if Task.isCancelled { break }
            onProgress?(GoalScanProgress(
                currentTask: label,
                completed: index,
                total: total,
                fraction: Double(index) / Double(max(total, 1))
            ))
            let batch = await phase()
            results.append(contentsOf: batch)
        }

        onProgress?(GoalScanProgress(currentTask: "", completed: total, total: total, fraction: 1))

        var seen = Set<String>()
        var deduped: [GoalSuggestion] = []
        for suggestion in results {
            let key = PathUtils.resolved(suggestion.url).path
            guard !excludePaths.contains(key), seen.insert(key).inserted else { continue }
            guard CleanupService.canDelete(url: suggestion.url) else { continue }
            deduped.append(suggestion)
        }

        deduped.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.category.sortOrder != rhs.category.sortOrder {
                return lhs.category.sortOrder < rhs.category.sortOrder
            }
            return lhs.size > rhs.size
        }

        var accumulated: Int64 = 0
        var selected: [GoalSuggestion] = []
        for suggestion in deduped {
            selected.append(suggestion)
            accumulated += suggestion.size
            if accumulated >= neededBytes, selected.count >= 5 { break }
            if selected.count >= maxResults { break }
        }

        if accumulated < neededBytes {
            let selectedPaths = Set(selected.map { PathUtils.resolved($0.url).path })
            for suggestion in deduped {
                let key = PathUtils.resolved(suggestion.url).path
                guard !selectedPaths.contains(key) else { continue }
                selected.append(suggestion)
                accumulated += suggestion.size
                if selected.count >= maxResults { break }
            }
        }

        return selected
    }

    // MARK: - Cleanup targets

    private static func scanCleanupTargets(volumeRoot: URL) async -> [GoalSuggestion] {
        let cleanup = await CleanupSuggestionService.scan(volumeRoot: volumeRoot)
        return cleanup.map { suggestion in
            let category = categoryForCleanup(suggestion)
            return GoalSuggestion(
                url: suggestion.url,
                name: suggestion.name,
                category: category,
                reason: suggestion.reason,
                size: suggestion.size,
                score: suggestion.score,
                modifiedDate: nil
            )
        }
    }

    private static func categoryForCleanup(_ suggestion: CleanupSuggestion) -> GoalSuggestionCategory {
        let lower = suggestion.category.lowercased()
        let name = suggestion.name.lowercased()
        if lower.contains("cache") || name.contains("cache") { return .cache }
        if lower.contains("log") || name.contains("log") { return .logs }
        if lower.contains("trash") || name.contains("trash") { return .trash }
        if lower.contains("install") || name.contains("install") { return .installers }
        if lower.contains("aging") || lower.contains("desktop") { return .oldFiles }
        return .other
    }

    // MARK: - Downloads

    private static func scanOldDownloads(home: URL) async -> [GoalSuggestion] {
        let downloads = home.appendingPathComponent("Downloads", isDirectory: true)
        guard FileManager.default.fileExists(atPath: downloads.path) else { return [] }

        let cutoff = Date().addingTimeInterval(-oldDownloadAge)
        let files = await walkFiles(root: downloads, maxDepth: 2) { _, size, modified, isDir in
            !isDir && size > 0 && (modified ?? .distantFuture) < cutoff
        }

        return files.prefix(40).map { item in
            let days = item.modifiedDate.map { max(0, Int(Date().timeIntervalSince($0) / 86_400)) } ?? 0
            return GoalSuggestion(
                url: item.url,
                name: item.name,
                category: .oldDownloads,
                reason: days > 0 ? "Not modified in \(days) days" : "Old download",
                size: item.size,
                score: 78,
                modifiedDate: item.modifiedDate
            )
        }
    }

    private static func scanLargeDownloads(home: URL) async -> [GoalSuggestion] {
        let downloads = home.appendingPathComponent("Downloads", isDirectory: true)
        guard FileManager.default.fileExists(atPath: downloads.path) else { return [] }

        let files = await walkFiles(root: downloads, maxDepth: 2) { _, size, _, isDir in
            !isDir && size >= largeDownloadThreshold
        }

        return files.prefix(30).map { item in
            GoalSuggestion(
                url: item.url,
                name: item.name,
                category: .largeDownloads,
                reason: "Large file in Downloads (\(ByteFormatter.string(from: item.size)))",
                size: item.size,
                score: 74,
                modifiedDate: item.modifiedDate
            )
        }
    }

    // MARK: - Old unused files

    private static func scanOldFiles(home: URL, volumeRoot: URL) async -> [GoalSuggestion] {
        let cutoff = Date().addingTimeInterval(-oldFileAge)
        var results: [GoalSuggestion] = []

        let folders: [(String, URL)] = [
            ("Desktop", home.appendingPathComponent("Desktop")),
            ("Documents", home.appendingPathComponent("Documents")),
        ]

        for (label, folder) in folders {
            guard FileManager.default.fileExists(atPath: folder.path) else { continue }
            guard PathUtils.isWithinVolume(folder, scanRoot: volumeRoot) || volumeRoot.path == "/" else { continue }

            let files = await walkFiles(root: folder, maxDepth: 3) { _, size, modified, isDir in
                !isDir && size >= minOldFileSize && (modified ?? .distantFuture) < cutoff
            }

            for item in files.prefix(15) {
                let days = item.modifiedDate.map { max(0, Int(Date().timeIntervalSince($0) / 86_400)) } ?? 0
                results.append(GoalSuggestion(
                    url: item.url,
                    name: item.name,
                    category: .oldFiles,
                    reason: "\(label) · unused for \(days) days",
                    size: item.size,
                    score: 68,
                    modifiedDate: item.modifiedDate
                ))
            }
        }

        return results
    }

    // MARK: - Dev junk

    private static func scanDevPaths() async -> [GoalSuggestion] {
        let targets = JunkPathCatalog.xcodeTargets
        let scanner = DiskScanner.shared
        var results: [GoalSuggestion] = []

        for target in targets {
            guard FileManager.default.fileExists(atPath: target.url.path) else { continue }
            let size = await scanner.calculateSize(for: target.url)
            guard size >= minSuggestionSize else { continue }
            results.append(GoalSuggestion(
                url: target.url,
                name: target.name,
                category: .devJunk,
                reason: "Xcode build cache — safe to rebuild",
                size: size,
                score: 72,
                modifiedDate: nil
            ))
        }

        return results
    }

    // MARK: - File walk

    private static func walkFiles(
        root: URL,
        maxDepth: Int = 12,
        include: @escaping (URL, Int64, Date?, Bool) -> Bool
    ) async -> [DiskItem] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [
                .isRegularFileKey, .fileSizeKey, .contentModificationDateKey,
                .isDirectoryKey, .isHiddenKey,
            ],
            options: [.skipsPackageDescendants]
        ) else { return [] }

        var results: [DiskItem] = []
        var scanned = 0
        let rootDepth = root.pathComponents.count

        while let url = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            let depth = url.pathComponents.count - rootDepth
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            scanned += 1
            let values = try? url.resourceValues(forKeys: [
                .isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .isHiddenKey
            ])
            let isDir = values?.isDirectory ?? false
            let isFile = values?.isRegularFile ?? false
            guard isFile || isDir else { continue }
            if values?.isHidden == true && !AppPreferences.load().showHiddenFiles { continue }

            let size = Int64(values?.fileSize ?? 0)
            let modified = values?.contentModificationDate

            if isFile && include(url, size, modified, false) {
                results.append(DiskItem(
                    url: url,
                    size: size,
                    isDirectory: false,
                    modifiedDate: modified
                ))
            }

            if scanned > 25_000 { break }
        }

        return results.sorted { $0.size > $1.size }
    }
}
