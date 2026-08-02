import Foundation

/// Single-pass directory sizing for chart preview and folder scans.
public enum DirectorySizeWalker {
    public struct WalkResult: Sendable, Equatable {
        public let childSizesByPath: [String: Int64]
        public let totalSize: Int64
        public let filesScanned: Int

        public init(childSizesByPath: [String: Int64], totalSize: Int64, filesScanned: Int = 0) {
            self.childSizesByPath = childSizesByPath
            self.totalSize = totalSize
            self.filesScanned = filesScanned
        }
    }

    public struct Configuration: Sendable {
        public var skipHiddenFiles: Bool
        public var partialUpdateInterval: Int

        public static let `default` = Configuration(skipHiddenFiles: true, partialUpdateInterval: 320)
        public static let chartPreview = Configuration(skipHiddenFiles: true, partialUpdateInterval: 40)
        public static let fastSizing = Configuration(skipHiddenFiles: true, partialUpdateInterval: 512)

        public init(skipHiddenFiles: Bool, partialUpdateInterval: Int) {
            self.skipHiddenFiles = skipHiddenFiles
            self.partialUpdateInterval = max(32, partialUpdateInterval)
        }
    }

    private static let sizeKeys: [URLResourceKey] = [
        .totalFileAllocatedSizeKey,
        .fileSizeKey,
        .isRegularFileKey
    ]

    public static func immediateChildSizes(
        at root: URL,
        configuration: Configuration = .default,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (WalkResult) -> Void)? = nil
    ) -> WalkResult {
        let normalizedRoot = PathUtils.resolved(root)
        let rootPath = directoryPath(normalizedRoot)
        let prefix = rootPath + "/"
        let prefixLength = prefix.count

        var childSizes: [String: Int64] = [:]
        var total: Int64 = 0
        var filesScanned = 0

        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if configuration.skipHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: normalizedRoot,
            includingPropertiesForKeys: sizeKeys,
            options: options
        ) else {
            let direct = directFileSize(at: normalizedRoot)
            return WalkResult(childSizesByPath: [:], totalSize: direct)
        }

        let partialInterval = configuration.partialUpdateInterval
        let tracksPartial = onPartial != nil

        func snapshot() -> WalkResult {
            WalkResult(childSizesByPath: childSizes, totalSize: total, filesScanned: filesScanned)
        }

        for case let fileURL as URL in enumerator {
            if let shouldCancel, shouldCancel() { break }

            autoreleasepool {
                guard let values = try? fileURL.resourceValues(forKeys: Set(sizeKeys)) else { return }
                guard values.isRegularFile == true else { return }

                let allocated = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                guard allocated > 0 else { return }

                total += allocated
                filesScanned += 1

                let filePath = fileURL.standardizedFileURL.path
                guard filePath.hasPrefix(prefix) else { return }

                let relativeStart = filePath.index(filePath.startIndex, offsetBy: prefixLength)
                guard relativeStart < filePath.endIndex else { return }

                let relative = filePath[relativeStart...]
                if let slash = relative.firstIndex(of: "/") {
                    let childPath = prefix + relative[..<slash]
                    childSizes[childPath, default: 0] += allocated
                } else {
                    childSizes[filePath, default: 0] += allocated
                }

                if tracksPartial, filesScanned % partialInterval == 0 {
                    onPartial?(snapshot())
                }
            }
        }

        let result = snapshot()
        if tracksPartial {
            onPartial?(result)
        }
        return result
    }

    public static func totalSize(of directory: URL) -> Int64 {
        immediateChildSizes(at: directory, configuration: .fastSizing).totalSize
    }

    public static func applySizes(
        to items: [DiskItem],
        walkResult: WalkResult
    ) -> [DiskItem] {
        items.map { item in
            guard item.isDirectory, !item.isVirtual else { return item }

            var updated = item
            let key = PathUtils.resolved(item.url).path
            if let size = walkResult.childSizesByPath[key] {
                updated.size = size
                updated.isScanning = false
            }
            return updated
        }
    }

    public static func applyPartialSizes(
        to items: [DiskItem],
        walkResult: WalkResult
    ) -> [DiskItem] {
        items.map { item in
            guard item.isDirectory, !item.isVirtual, item.isScanning else { return item }

            var updated = item
            let key = PathUtils.resolved(item.url).path
            if let size = walkResult.childSizesByPath[key], size > 0 {
                updated.size = size
                updated.isScanning = false
            }
            return updated
        }
    }

    private static func directoryPath(_ url: URL) -> String {
        var path = url.standardizedFileURL.path
        if path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    private static func directFileSize(at url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) else {
            return 0
        }
        return Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
    }
}
