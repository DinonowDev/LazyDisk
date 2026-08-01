import Foundation

public struct DuplicateGroup: Identifiable, Sendable {
    public let id = UUID()
    public let hash: String
    public var files: [DuplicateFile]

    public init(hash: String, files: [DuplicateFile]) {
        self.hash = hash
        self.files = files
    }

    public var totalWasted: Int64 {
        guard files.count > 1 else { return 0 }
        let keep = files.map(\.size).max() ?? 0
        return files.reduce(0) { $0 + $1.size } - keep
    }
}

public struct DuplicateFile: Identifiable, Sendable {
    public let id = UUID()
    public let url: URL
    public let size: Int64

    public init(url: URL, size: Int64) {
        self.url = url
        self.size = size
    }
}
