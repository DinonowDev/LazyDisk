import Foundation

struct CleanupSuggestion: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let category: String
    let reason: String
    var size: Int64
    var score: Int = 0
}

struct CleanupScanProgress: Sendable {
    let currentTask: String
    let completed: Int
    let total: Int
    let fraction: Double
}

enum CleanupSuggestionService {
    private static let minSuggestionSize: Int64 = 5 * 1024 * 1024
    private static let oldFileDays: TimeInterval = 30 * 86_400

    static func scan(
        volumeRoot: URL,
        onProgress: (@Sendable (CleanupScanProgress) -> Void)? = nil
    ) async -> [CleanupSuggestion] {
        var results: [CleanupSuggestion] = []
        let scanner = DiskScanner.shared
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default

        // Xcode paths and old Downloads are handled by Smart Collections in the Browser panel.
        let knownTargets: [(String, String, URL)] = [
            ("Caches", "App cache files", home.appendingPathComponent("Library/Caches")),
            ("Logs", "Old log files", home.appendingPathComponent("Library/Logs")),
            ("Trash", "Trash contents", home.appendingPathComponent(".Trash")),
            ("npm cache", "Node package cache", home.appendingPathComponent(".npm")),
            ("yarn cache", "Yarn cache", home.appendingPathComponent("Library/Caches/Yarn")),
            ("pip cache", "Python package cache", home.appendingPathComponent("Library/Caches/pip")),
            ("Homebrew cache", "Homebrew downloads", home.appendingPathComponent("Library/Caches/Homebrew")),
            ("Safari cache", "Browser cache", home.appendingPathComponent("Library/Caches/com.apple.Safari")),
            ("Mail downloads", "Mail attachment cache", home.appendingPathComponent("Library/Mail Downloads")),
            ("Spotify cache", "Spotify offline cache", home.appendingPathComponent("Library/Caches/com.spotify.client")),
        ]

        var tasks: [(String, () async -> CleanupSuggestion?)] = []

        for (name, reason, url) in knownTargets {
            tasks.append((name, {
                guard fm.fileExists(atPath: url.path) else { return nil }
                let size = await scanner.calculateSize(for: url)
                guard size >= minSuggestionSize else { return nil }
                return CleanupSuggestion(url: url, name: name, category: reason, reason: reason, size: size, score: 80)
            }))
        }

        tasks.append(("Desktop", {
            await scanOldLargeFiles(in: home.appendingPathComponent("Desktop"), label: "Large desktop files", minAge: oldFileDays, minSize: 50 * 1024 * 1024)
        }))

        tasks.append(("Installers", {
            await scanInstallers(in: home.appendingPathComponent("Downloads"))
        }))

        tasks.append(("Cache subdirs", {
            await scanLargeCacheSubdirs(in: home.appendingPathComponent("Library/Caches"))
        }))

        if PathUtils.isWithinVolume(home, scanRoot: volumeRoot) || volumeRoot.path == "/" {
            // scan volume-level caches if accessible
            let systemCaches = URL(fileURLWithPath: "/Library/Caches", isDirectory: true)
            if fm.isReadableFile(atPath: systemCaches.path) {
                tasks.append(("System caches", {
                    await scanLargeCacheSubdirs(in: systemCaches)
                }))
            }
        }

        let total = tasks.count
        for (index, (label, task)) in tasks.enumerated() {
            if Task.isCancelled { break }
            onProgress?(CleanupScanProgress(currentTask: label, completed: index, total: total, fraction: Double(index) / Double(max(total, 1))))
            if let suggestion = await task() {
                results.append(suggestion)
            }
        }

        onProgress?(CleanupScanProgress(currentTask: "", completed: total, total: total, fraction: 1))

        return results
            .sorted { ($0.score, $0.size) > ($1.score, $1.size) }
    }

    private static func scanOldLargeFiles(in folder: URL, label: String, minAge: TimeInterval, minSize: Int64) async -> CleanupSuggestion? {
        guard FileManager.default.fileExists(atPath: folder.path) else { return nil }
        let cutoff = Date().addingTimeInterval(-minAge)
        var totalSize: Int64 = 0
        var oldCount = 0

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for url in contents {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            let mod = values?.contentModificationDate ?? .distantFuture
            let size = Int64(values?.fileSize ?? 0)
            if mod < cutoff && size > 0 {
                totalSize += size
                oldCount += 1
            }
        }

        guard totalSize >= minSize else { return nil }
        return CleanupSuggestion(
            url: folder,
            name: label,
            category: "Aging files",
            reason: "\(oldCount) files older than \(Int(minAge / 86_400)) days",
            size: totalSize,
            score: 70
        )
    }

    private static func scanInstallers(in folder: URL) async -> CleanupSuggestion? {
        guard FileManager.default.fileExists(atPath: folder.path) else { return nil }
        let extensions = Set(["dmg", "pkg", "iso", "zip"])
        var totalSize: Int64 = 0
        var count = 0

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for url in contents where extensions.contains(url.pathExtension.lowercased()) {
            let size = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            totalSize += size
            count += 1
        }

        guard totalSize >= minSuggestionSize else { return nil }
        return CleanupSuggestion(
            url: folder,
            name: "Installers",
            category: "Installers",
            reason: "\(count) DMG/PKG/ISO files in Downloads",
            size: totalSize,
            score: 75
        )
    }

    private static func scanLargeCacheSubdirs(in cachesRoot: URL) async -> CleanupSuggestion? {
        guard FileManager.default.fileExists(atPath: cachesRoot.path) else { return nil }
        let scanner = DiskScanner.shared

        guard let subdirs = try? FileManager.default.contentsOfDirectory(
            at: cachesRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var largest: (URL, Int64)?
        for dir in subdirs {
            let values = try? dir.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let size = await scanner.calculateSize(for: dir)
            if size >= minSuggestionSize, largest == nil || size > largest!.1 {
                largest = (dir, size)
            }
        }

        guard let largest else { return nil }
        return CleanupSuggestion(
            url: largest.0,
            name: largest.0.lastPathComponent,
            category: "Large cache",
            reason: "Cache folder over \(ByteFormatter.string(from: minSuggestionSize))",
            size: largest.1,
            score: 65
        )
    }
}
