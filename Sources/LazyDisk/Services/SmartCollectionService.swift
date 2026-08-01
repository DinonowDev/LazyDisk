import Foundation

enum SmartCollectionService {
    private static let largeFileThreshold: Int64 = 1_073_741_824 // 1 GB
    private static let oldFileAge: TimeInterval = 180 * 86_400
    private static let oldDownloadAge: TimeInterval = 30 * 86_400
    private static let minOldFileSize: Int64 = 10 * 1024 * 1024
    private static let maxResults = 300
    private static let minJunkSize: Int64 = 5 * 1024 * 1024

    static func scan(
        collection: SmartCollection,
        volumeRoot: URL,
        scanRoot: URL? = nil,
        onProgress: (@Sendable (SmartCollectionProgress) -> Void)? = nil
    ) async -> [DiskItem] {
        let root = scanRoot ?? volumeRoot
        switch collection {
        case .largeFiles:
            return await scanLargeFiles(root: root, onProgress: onProgress)
        case .oldFiles:
            return await scanOldFiles(root: root, onProgress: onProgress)
        case .xcode:
            return await scanXcodePaths(onProgress: onProgress)
        case .nodeModules:
            return await scanNamedFolders(
                root: root,
                names: Set(["node_modules"]),
                onProgress: onProgress
            )
        case .oldDownloads:
            return await scanOldDownloads(onProgress: onProgress)
        }
    }

    // MARK: - Large files

    private static func scanLargeFiles(
        root: URL,
        onProgress: (@Sendable (SmartCollectionProgress) -> Void)?
    ) async -> [DiskItem] {
        await walkFiles(root: root, onProgress: onProgress) { url, size, _, _ in
            size >= largeFileThreshold
        }
    }

    // MARK: - Old files

    private static func scanOldFiles(
        root: URL,
        onProgress: (@Sendable (SmartCollectionProgress) -> Void)?
    ) async -> [DiskItem] {
        let cutoff = Date().addingTimeInterval(-oldFileAge)
        return await walkFiles(root: root, onProgress: onProgress) { _, size, modified, isDir in
            !isDir && size >= minOldFileSize && (modified ?? .distantFuture) < cutoff
        }
    }

    // MARK: - Old downloads

    private static func scanOldDownloads(
        onProgress: (@Sendable (SmartCollectionProgress) -> Void)?
    ) async -> [DiskItem] {
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
        guard FileManager.default.fileExists(atPath: downloads.path) else { return [] }

        let cutoff = Date().addingTimeInterval(-oldDownloadAge)
        return await walkFiles(root: downloads, maxDepth: 2, onProgress: onProgress) { _, size, modified, isDir in
            !isDir && size > 0 && (modified ?? .distantFuture) < cutoff
        }
    }

    // MARK: - Xcode paths

    private static func scanXcodePaths(
        onProgress: (@Sendable (SmartCollectionProgress) -> Void)?
    ) async -> [DiskItem] {
        let targets = JunkPathCatalog.xcodeTargets
        var results: [DiskItem] = []
        let scanner = DiskScanner.shared

        for (index, target) in targets.enumerated() {
            if Task.isCancelled { break }
            let url = target.url
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let size = await scanner.calculateSize(for: url)
            guard size >= minJunkSize else { continue }
            results.append(DiskItem(
                url: url,
                name: target.name,
                size: size,
                isDirectory: true
            ))
            onProgress?(SmartCollectionProgress(
                scanned: index + 1,
                found: results.count,
                status: target.name,
                fraction: Double(index + 1) / Double(targets.count)
            ))
        }

        return results.sorted { $0.size > $1.size }
    }

    // MARK: - Named folders (node_modules, etc.)

    private static func scanNamedFolders(
        root: URL,
        names: Set<String>,
        onProgress: (@Sendable (SmartCollectionProgress) -> Void)?
    ) async -> [DiskItem] {
        let scanner = DiskScanner.shared
        var results: [DiskItem] = []
        var scanned = 0
        var queue: [URL] = [root]
        var visited = Set<String>()

        while !queue.isEmpty, results.count < maxResults {
            if Task.isCancelled { break }
            let current = queue.removeFirst()
            let path = current.path
            guard visited.insert(path).inserted else { continue }

            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: current,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for url in contents {
                if Task.isCancelled { break }
                scanned += 1
                let name = url.lastPathComponent
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                let isDir = values?.isDirectory ?? false

                if isDir && names.contains(name) {
                    let size = await scanner.calculateSize(for: url)
                    if size >= minJunkSize {
                        results.append(DiskItem(url: url, size: size, isDirectory: true))
                    }
                } else if isDir, scanned < 8_000 {
                    queue.append(url)
                }

                if scanned % 200 == 0 {
                    onProgress?(SmartCollectionProgress(
                        scanned: scanned,
                        found: results.count,
                        status: current.lastPathComponent,
                        fraction: min(Double(scanned) / 8000, 0.95)
                    ))
                }
            }
        }

        return results.sorted { $0.size > $1.size }
    }

    // MARK: - Generic file walk

    private static func walkFiles(
        root: URL,
        maxDepth: Int = 12,
        onProgress: (@Sendable (SmartCollectionProgress) -> Void)?,
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
                if results.count >= maxResults { break }
            }

            if scanned % 500 == 0 {
                onProgress?(SmartCollectionProgress(
                    scanned: scanned,
                    found: results.count,
                    status: url.deletingLastPathComponent().lastPathComponent,
                    fraction: min(Double(scanned) / 20_000, 0.95)
                ))
            }
        }

        return results.sorted { $0.size > $1.size }
    }
}
