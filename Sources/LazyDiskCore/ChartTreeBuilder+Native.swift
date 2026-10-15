import Foundation

extension ChartTreeBuilder {
    static func buildWithNativeScanner(
        at root: URL,
        listedEntries: [DiskItem],
        options: BuildOptions,
        shouldCancel: (@Sendable () -> Bool)? = nil,
        onPartial: (@Sendable (BuildResult) -> Void)? = nil
    ) -> BuildResult? {
        guard NativeDirectoryScanner.isAvailable else { return nil }

        guard let native = NativeDirectoryScanner.buildChartTree(
            at: root,
            listedEntries: listedEntries,
            maxDepth: options.maxDepth,
            skipHiddenFiles: options.skipHiddenFiles,
            usePhysicalSize: true,
            parallelism: options.parallelism,
            shouldCancel: shouldCancel,
            onPartial: onPartial
        ), native.totalSize > 0 || native.filesScanned > 0 else {
            return nil
        }
        return native
    }
}
