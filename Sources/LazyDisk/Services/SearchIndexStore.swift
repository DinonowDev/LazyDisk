import Foundation

actor SearchIndexStore {
    static let shared = SearchIndexStore()

    private static let indexDirectory: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("LazyDisk/SearchIndex", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var memoryIndex: [String: [SearchIndexEntry]] = [:]
    private var buildTasks: [String: Task<Void, Never>] = [:]

    func hasIndex(for volumeID: String) -> Bool {
        memoryIndex[volumeID] != nil || FileManager.default.fileExists(atPath: indexFile(for: volumeID).path)
    }

    func entryCount(for volumeID: String) async -> Int {
        await load(volumeID: volumeID)?.entries.count ?? 0
    }

    func load(volumeID: String) async -> SearchIndexSnapshot? {
        if let cached = memoryIndex[volumeID] {
            return SearchIndexSnapshot(
                volumeID: volumeID,
                builtAt: Date(),
                entryCount: cached.count,
                entries: cached
            )
        }

        let fileURL = indexFile(for: volumeID)
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(SearchIndexSnapshot.self, from: data) else {
            return nil
        }

        memoryIndex[volumeID] = snapshot.entries
        return snapshot
    }

    func search(
        query: String,
        volumeID: String,
        filter: ContentFilter,
        includeHidden: Bool,
        limit: Int = 500
    ) async -> [SearchIndexEntry] {
        guard let snapshot = await load(volumeID: volumeID) else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        var scored: [(SearchIndexEntry, Int)] = []

        for entry in snapshot.entries {
            if !includeHidden && entry.isHidden { continue }
            let item = entry.diskItemProxy
            if filter != .all && !filter.matches(item) { continue }

            let match = entry.matches(query: trimmed)
            if match.matched {
                scored.append((entry, match.score))
            }
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending
            }
            .prefix(limit)
            .map(\.0)
    }

    func buildIndex(
        at root: URL,
        volumeID: String,
        includeHidden: Bool,
        onProgress: (@Sendable (SearchProgress) -> Void)? = nil
    ) async {
        buildTasks[volumeID]?.cancel()

        let task = Task {
            var entries: [SearchIndexEntry] = []
            var scannedDirs = 0
            let fm = FileManager.default
            let normalizedRoot = PathUtils.resolved(root)

            var queue: [URL] = [normalizedRoot]

            while !queue.isEmpty {
                guard !Task.isCancelled else { return }

                let dirURL = queue.removeFirst()
                scannedDirs += 1

                let children: [URL]
                do {
                    children = try fm.contentsOfDirectory(
                        at: dirURL,
                        includingPropertiesForKeys: [
                            .isDirectoryKey,
                            .fileSizeKey,
                            .totalFileAllocatedSizeKey,
                            .contentModificationDateKey,
                            .isHiddenKey
                        ],
                        options: [.skipsPackageDescendants]
                    )
                } catch {
                    continue
                }

                for child in children {
                    guard !Task.isCancelled else { return }

                    let values = try? child.resourceValues(forKeys: [
                        .isDirectoryKey,
                        .fileSizeKey,
                        .totalFileAllocatedSizeKey,
                        .contentModificationDateKey,
                        .isHiddenKey
                    ])

                    let isDir = values?.isDirectory ?? false
                    let isHidden = values?.isHidden ?? child.lastPathComponent.hasPrefix(".")
                    if !includeHidden && isHidden { continue }

                    let resolved = PathUtils.resolved(child)
                    let size = Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)

                    entries.append(SearchIndexEntry(
                        path: resolved.path,
                        name: resolved.lastPathComponent,
                        isDirectory: isDir,
                        size: isDir ? 0 : size,
                        modifiedDate: values?.contentModificationDate,
                        fileKind: FileKind.detect(url: resolved, isDirectory: isDir),
                        isHidden: isHidden
                    ))

                    if isDir {
                        queue.append(resolved)
                    }
                }

                if scannedDirs % 50 == 0 {
                    onProgress?(SearchProgress(
                        scannedDirectories: scannedDirs,
                        foundEntries: entries.count,
                        currentPath: dirURL.lastPathComponent
                    ))
                }
            }

            guard !Task.isCancelled else { return }

            let snapshot = SearchIndexSnapshot(
                volumeID: volumeID,
                builtAt: Date(),
                entryCount: entries.count,
                entries: entries
            )

            memoryIndex[volumeID] = entries
            await save(snapshot)
            onProgress?(SearchProgress(
                scannedDirectories: scannedDirs,
                foundEntries: entries.count,
                currentPath: "Done"
            ))
        }

        buildTasks[volumeID] = task
        await task.value
        buildTasks.removeValue(forKey: volumeID)
    }

    func cancelBuild(for volumeID: String) {
        buildTasks[volumeID]?.cancel()
        buildTasks.removeValue(forKey: volumeID)
    }

    func invalidate(volumeID: String) async {
        buildTasks[volumeID]?.cancel()
        buildTasks.removeValue(forKey: volumeID)
        memoryIndex.removeValue(forKey: volumeID)
        try? FileManager.default.removeItem(at: indexFile(for: volumeID))
    }

    private func save(_ snapshot: SearchIndexSnapshot) async {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: indexFile(for: snapshot.volumeID), options: .atomic)
    }

    private func indexFile(for volumeID: String) -> URL {
        let safe = volumeID
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "-")
        return Self.indexDirectory.appendingPathComponent("\(safe).json")
    }
}

private extension SearchIndexEntry {
    var diskItemProxy: DiskItem {
        DiskItem(
            url: url,
            name: name,
            size: size,
            isDirectory: isDirectory,
            isHidden: isHidden,
            modifiedDate: modifiedDate,
            fileKind: fileKind
        )
    }
}
