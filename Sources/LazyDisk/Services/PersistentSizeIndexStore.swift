import Foundation
import LazyDiskCore

actor PersistentSizeIndexStore {
    static let shared = PersistentSizeIndexStore()

    private static let indexDirectory: URL = {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = appSupport.appendingPathComponent("LazyDisk/SizeIndex", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let maxAge: TimeInterval = 60 * 60 * 24 * 14

    func load(volumeID: String) -> [String: Int64] {
        let fileURL = fileURL(for: volumeID)
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode(StoredSizeIndex.self, from: data) else {
            return [:]
        }

        guard Date().timeIntervalSince(stored.updatedAt) < Self.maxAge else {
            try? FileManager.default.removeItem(at: fileURL)
            return [:]
        }

        return stored.sizes
    }

    func save(volumeID: String, sizes: [String: Int64]) {
        guard !sizes.isEmpty else { return }

        let stored = StoredSizeIndex(
            volumeID: volumeID,
            updatedAt: Date(),
            sizes: sizes
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: fileURL(for: volumeID), options: .atomic)
    }

    func clear(volumeID: String) {
        try? FileManager.default.removeItem(at: fileURL(for: volumeID))
    }

    func clearAll() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: Self.indexDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func fileURL(for volumeID: String) -> URL {
        Self.indexDirectory
            .appendingPathComponent(sanitized(volumeID))
            .appendingPathExtension("json")
    }

    private func sanitized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "-")
    }
}

private struct StoredSizeIndex: Codable {
    let volumeID: String
    let updatedAt: Date
    let sizes: [String: Int64]
}
