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

        return NativeDirectoryScanner.buildChartTree(
            at: root,
            listedEntries: listedEntries,
            maxDepth: options.maxDepth,
            skipHiddenFiles: options.skipHiddenFiles,
            parallelism: options.parallelism,
            shouldCancel: shouldCancel,
            onPartial: onPartial
        )
    }
}
