import Foundation

actor GlobalSearchService {
    static let shared = GlobalSearchService()

    private var activeSearchID: UInt = 0
    private let indexStore = SearchIndexStore.shared

    func search(
        query: String,
        volume: VolumeInfo,
        filter: ContentFilter,
        includeHidden: Bool,
        preferSpotlight: Bool = true
    ) async -> (results: [GlobalSearchResult], engine: SearchEngine) {
        activeSearchID += 1
        let searchID = activeSearchID
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ([], .index) }

        if preferSpotlight {
            let spotlight = await SpotlightSearchService.search(
                query: trimmed,
                in: volume.scanRoot,
                limit: 400
            )
            guard searchID == activeSearchID else { return ([], .spotlight) }

            if !spotlight.isEmpty {
                let filtered = applyFilter(spotlight, filter: filter, includeHidden: includeHidden)
                return (filtered, .spotlight)
            }
        }

        if await indexStore.hasIndex(for: volume.id) {
            let indexHits = await indexStore.search(
                query: trimmed,
                volumeID: volume.id,
                filter: filter,
                includeHidden: includeHidden
            )
            guard searchID == activeSearchID else { return ([], .index) }

            if !indexHits.isEmpty {
                return (indexHits.map(toGlobalResult), .index)
            }
        }

        let live = await filesystemSearch(
            query: trimmed,
            root: volume.scanRoot,
            filter: filter,
            includeHidden: includeHidden,
            searchID: searchID
        )
        guard searchID == activeSearchID else { return ([], .filesystem) }
        return (live, .filesystem)
    }

    func cancelSearch() {
        activeSearchID += 1
    }

    func buildIndex(
        for volume: VolumeInfo,
        includeHidden: Bool,
        onProgress: (@Sendable (SearchProgress) -> Void)? = nil
    ) async {
        await indexStore.buildIndex(
            at: volume.scanRoot,
            volumeID: volume.id,
            includeHidden: includeHidden,
            onProgress: onProgress
        )
    }

    func indexEntryCount(for volume: VolumeInfo) async -> Int {
        await indexStore.entryCount(for: volume.id)
    }

    func hasIndex(for volume: VolumeInfo) async -> Bool {
        await indexStore.hasIndex(for: volume.id)
    }

    func invalidateIndex(for volume: VolumeInfo) async {
        await indexStore.invalidate(volumeID: volume.id)
    }

    // MARK: - Private

    private func filesystemSearch(
        query: String,
        root: URL,
        filter: ContentFilter,
        includeHidden: Bool,
        searchID: UInt
    ) async -> [GlobalSearchResult] {
        await Task.detached(priority: .utility) {
            var results: [GlobalSearchResult] = []
            let fm = FileManager.default
            let normalizedRoot = PathUtils.resolved(root)
            let q = query.lowercased()

            guard let enumerator = fm.enumerator(
                at: normalizedRoot,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .fileSizeKey,
                    .totalFileAllocatedSizeKey,
                    .contentModificationDateKey,
                    .isHiddenKey
                ],
                options: [.skipsPackageDescendants]
            ) else { return [] }

            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }
                if results.count >= 500 { break }

                let name = fileURL.lastPathComponent
                let nameLower = name.lowercased()

                let matched: Int?
                if nameLower == q { matched = 100 }
                else if nameLower.hasPrefix(q) { matched = 80 }
                else if nameLower.contains(q) { matched = 60 }
                else if fileURL.path.lowercased().contains(q) { matched = 40 }
                else { matched = nil }

                guard let score = matched else { continue }

                let values = try? fileURL.resourceValues(forKeys: [
                    .isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey,
                    .contentModificationDateKey, .isHiddenKey
                ])
                let isDir = values?.isDirectory ?? false
                let isHidden = values?.isHidden ?? name.hasPrefix(".")
                if !includeHidden && isHidden { continue }

                let item = DiskItem(
                    url: PathUtils.resolved(fileURL),
                    size: Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0),
                    isDirectory: isDir,
                    isHidden: isHidden,
                    modifiedDate: values?.contentModificationDate
                )
                if filter != .all && !filter.matches(item) { continue }

                results.append(GlobalSearchResult(
                    url: item.url,
                    name: item.name,
                    parentPath: item.url.deletingLastPathComponent().path,
                    size: item.size,
                    isDirectory: isDir,
                    fileKind: item.fileKind,
                    modifiedDate: item.modifiedDate,
                    isHidden: isHidden,
                    matchScore: score
                ))
            }

            return results.sorted { $0.matchScore > $1.matchScore }
        }.value
    }

    private func applyFilter(
        _ results: [GlobalSearchResult],
        filter: ContentFilter,
        includeHidden: Bool
    ) -> [GlobalSearchResult] {
        results.filter { result in
            if !includeHidden && result.isHidden { return false }
            if filter == .all { return true }
            return filter.matches(result.diskItem)
        }
    }

    private func toGlobalResult(_ entry: SearchIndexEntry) -> GlobalSearchResult {
        GlobalSearchResult(
            url: entry.url,
            name: entry.name,
            parentPath: entry.url.deletingLastPathComponent().path,
            size: entry.size,
            isDirectory: entry.isDirectory,
            fileKind: entry.fileKind,
            modifiedDate: entry.modifiedDate,
            isHidden: entry.isHidden,
            matchScore: 70
        )
    }
}
