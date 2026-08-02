import Foundation

struct StoredChartScanProgress: Codable, Sendable {
    let volumeID: String
    let displayFraction: Double
    let completedFolders: Int
    let estimatedTotalFolders: Int
    let updatedAt: Date
}

actor PersistentChartScanProgressStore {
    static let shared = PersistentChartScanProgressStore()

    private static let storeDirectory: URL = {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = appSupport.appendingPathComponent("LazyDisk/ChartProgress", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let maxAge: TimeInterval = 60 * 60 * 24 * 3
    private var pendingSave: Task<Void, Never>?

    func load(volumeID: String) -> StoredChartScanProgress? {
        let fileURL = fileURL(for: volumeID)
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode(StoredChartScanProgress.self, from: data) else {
            return nil
        }

        guard Date().timeIntervalSince(stored.updatedAt) < Self.maxAge else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        return stored
    }

    func scheduleSave(
        volumeID: String,
        displayFraction: Double,
        completedFolders: Int,
        estimatedTotalFolders: Int
    ) {
        guard AppPreferences.load().usePersistentCache else { return }

        pendingSave?.cancel()
        pendingSave = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }

            let stored = StoredChartScanProgress(
                volumeID: volumeID,
                displayFraction: displayFraction,
                completedFolders: completedFolders,
                estimatedTotalFolders: estimatedTotalFolders,
                updatedAt: Date()
            )
            guard let data = try? JSONEncoder().encode(stored) else { return }
            try? data.write(to: fileURL(for: volumeID), options: .atomic)
        }
    }

    func clear(volumeID: String) {
        pendingSave?.cancel()
        try? FileManager.default.removeItem(at: fileURL(for: volumeID))
    }

    func clearAll() {
        pendingSave?.cancel()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: Self.storeDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func fileURL(for volumeID: String) -> URL {
        Self.storeDirectory
            .appendingPathComponent(sanitized(volumeID))
            .appendingPathExtension("json")
    }

    private func sanitized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "-")
    }
}
