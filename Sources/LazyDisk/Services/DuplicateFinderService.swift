import Foundation
import CryptoKit

struct DuplicateScanProgress: Sendable {
    enum Phase: Sendable { case collecting, hashing, done }
    let phase: Phase
    let scannedFiles: Int
    let candidateFiles: Int
    let hashedFiles: Int
    let groupsFound: Int
    let fraction: Double
    let statusText: String
}

enum DuplicateFinderService {
    private static let minFileSize: Int64 = 4096
    private static let chunkSize = 1024 * 1024

    static func findDuplicates(
        in root: URL,
        onProgress: (@Sendable (DuplicateScanProgress) -> Void)? = nil
    ) async -> [DuplicateGroup] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isHiddenKey, .isPackageKey],
            options: [.skipsPackageDescendants]
        ) else { return [] }

        var sizeBuckets: [Int64: [URL]] = [:]
        var scanned = 0

        while let url = enumerator.nextObject() as? URL {
            if Task.isCancelled { return [] }

            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isHiddenKey, .isPackageKey])
            guard values?.isRegularFile == true, values?.isPackage != true else { continue }
            guard let size = values?.fileSize, Int64(size) >= minFileSize else { continue }
            if values?.isHidden == true && !AppPreferences.load().showHiddenFiles { continue }

            scanned += 1
            sizeBuckets[Int64(size), default: []].append(url)

            if scanned % 500 == 0 {
                onProgress?(DuplicateScanProgress(
                    phase: .collecting,
                    scannedFiles: scanned,
                    candidateFiles: 0,
                    hashedFiles: 0,
                    groupsFound: 0,
                    fraction: 0.1,
                    statusText: L10n.dupPhaseCollect
                ))
            }
        }

        let candidates = sizeBuckets.values.filter { $0.count > 1 }.flatMap { $0 }
        let totalCandidates = candidates.count
        var hashed = 0
        var groups: [DuplicateGroup] = []

        let bucketsWithDupes = sizeBuckets.filter { $0.value.count > 1 }

        for (_, urls) in bucketsWithDupes {
            if Task.isCancelled { return groups }
            var hashBuckets: [String: [DuplicateFile]] = [:]

            for url in urls {
                if Task.isCancelled { return groups }
                let size = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                guard let hash = fullFileHash(url) else { continue }
                hashBuckets[hash, default: []].append(DuplicateFile(url: url, size: size))
                hashed += 1

                if hashed % 50 == 0 {
                    let fraction = 0.2 + (Double(hashed) / Double(max(totalCandidates, 1))) * 0.75
                    onProgress?(DuplicateScanProgress(
                        phase: .hashing,
                        scannedFiles: scanned,
                        candidateFiles: totalCandidates,
                        hashedFiles: hashed,
                        groupsFound: groups.count,
                        fraction: min(fraction, 0.95),
                        statusText: L10n.dupPhaseHash
                    ))
                }
            }

            for (hash, files) in hashBuckets where files.count > 1 {
                groups.append(DuplicateGroup(hash: hash, files: files.sorted { $0.url.path < $1.url.path }))
            }
        }

        onProgress?(DuplicateScanProgress(
            phase: .done,
            scannedFiles: scanned,
            candidateFiles: totalCandidates,
            hashedFiles: hashed,
            groupsFound: groups.count,
            fraction: 1,
            statusText: ""
        ))

        return groups.sorted { $0.totalWasted > $1.totalWasted }
    }

    private static func fullFileHash(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            guard let data = try? handle.read(upToCount: chunkSize), !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
