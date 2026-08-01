import CoreServices
import Foundation

enum SpotlightSearchService {
    static func search(
        query: String,
        in root: URL,
        limit: Int = 300
    ) async -> [GlobalSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        return await withCheckedContinuation { continuation in
            let session = QuerySession(
                query: trimmed,
                root: root,
                limit: limit,
                continuation: continuation
            )
            session.start()
        }
    }
}

private final class QuerySession: @unchecked Sendable {
    private let metadataQuery = NSMetadataQuery()
    private let query: String
    private let limit: Int
    private let continuation: CheckedContinuation<[GlobalSearchResult], Never>
    private var observer: NSObjectProtocol?
    private var didFinish = false

    init(
        query: String,
        root: URL,
        limit: Int,
        continuation: CheckedContinuation<[GlobalSearchResult], Never>
    ) {
        self.query = query
        self.limit = limit
        self.continuation = continuation

        metadataQuery.searchScopes = [root]
        let escaped = query.replacingOccurrences(of: "'", with: "\\'")
        metadataQuery.predicate = NSPredicate(
            format: "kMDItemDisplayName LIKE[c] %@ OR kMDItemFSName LIKE[c] %@",
            "*\(escaped)*",
            "*\(escaped)*"
        )
    }

    func start() {
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery,
            queue: .main
        ) { [self] _ in
            self.handleFinish()
        }

        metadataQuery.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [self] in
            self.finish(with: self.collectResults())
        }
    }

    private func handleFinish() {
        metadataQuery.disableUpdates()
        metadataQuery.stop()
        metadataQuery.enableUpdates()
        finish(with: collectResults())
    }

    private func finish(with results: [GlobalSearchResult]) {
        guard !didFinish else { return }
        didFinish = true

        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }

        metadataQuery.stop()
        continuation.resume(returning: results.sorted { $0.matchScore > $1.matchScore })
    }

    private func collectResults() -> [GlobalSearchResult] {
        var collected: [GlobalSearchResult] = []
        let count = min(metadataQuery.resultCount, limit)

        for index in 0..<count {
            guard let item = metadataQuery.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: kMDItemPath as String) as? String else {
                continue
            }

            let url = URL(fileURLWithPath: path)
            let name = url.lastPathComponent
            let parent = url.deletingLastPathComponent().path
            let size = (item.value(forAttribute: kMDItemFSSize as String) as? NSNumber)?.int64Value ?? 0
            let isDir = (item.value(forAttribute: kMDItemContentTypeTree as String) as? [String])?
                .contains("public.folder") ?? url.hasDirectoryPath
            let modified = item.value(forAttribute: kMDItemFSContentChangeDate as String) as? Date

            let nameLower = name.lowercased()
            let qLower = query.lowercased()
            let score: Int
            if nameLower == qLower { score = 100 }
            else if nameLower.hasPrefix(qLower) { score = 80 }
            else { score = 60 }

            collected.append(GlobalSearchResult(
                url: PathUtils.resolved(url),
                name: name,
                parentPath: parent,
                size: size,
                isDirectory: isDir,
                modifiedDate: modified,
                matchScore: score
            ))
        }

        return collected
    }
}
