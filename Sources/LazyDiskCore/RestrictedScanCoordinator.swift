import Foundation

public struct RestrictedScanEvent: Sendable, Hashable {
    public let path: String
    public let errorCode: Int

    public init(path: String, errorCode: Int) {
        self.path = path
        self.errorCode = errorCode
    }
}

/// Collects paths the native scanner could not enter (permission / TCC).
public actor RestrictedScanCoordinator {
    public static let shared = RestrictedScanCoordinator()

    private var eventsByPath: [String: RestrictedScanEvent] = [:]

    public func register(_ events: [RestrictedScanEvent]) {
        for event in events {
            eventsByPath[event.path] = event
        }
    }

    public func allEvents() -> [RestrictedScanEvent] {
        Array(eventsByPath.values).sorted { $0.path < $1.path }
    }

    public func clear() {
        eventsByPath.removeAll()
    }

    public func remove(paths: [String]) {
        for path in paths {
            eventsByPath.removeValue(forKey: path)
        }
    }

    public func registerAndReturnMerged(_ events: [RestrictedScanEvent]) -> [RestrictedScanEvent] {
        register(events)
        return allEvents()
    }
}

/// Retries restricted paths via privileged helper (SMJobBless) or Full Disk Access fallback.
public enum AdminScanGateway {
    public static func retrySizing(
        for events: [RestrictedScanEvent],
        skipHiddenFiles: Bool,
        listedChildren: @Sendable (URL) -> [URL],
        onPrivilegedProgress: (@Sendable (String, PrivilegedScanProgress) -> Void)? = nil
    ) async -> [String: Int64] {
        var sizes: [String: Int64] = [:]
        let privileged = PrivilegedScanClient.shared.isHelperReachable()
        let helperConfig = PrivilegedScanConfiguration(
            firmLinks: true,
            maxConcurrentTaskCount: NativeScanRuntime.daisyDefaultWorkers,
            supportsPhysicalSize: true
        )
        let config = DirectorySizeWalker.Configuration(
            skipHiddenFiles: skipHiddenFiles,
            partialUpdateInterval: 512,
            parallelism: 2,
            usePhysicalSize: true
        )
        let helperWalkConfig = skipHiddenFiles
            ? DirectorySizeWalker.Configuration.default
            : DirectorySizeWalker.Configuration.volumeRoot
        for event in events {
            if privileged {
                do {
                    var privilegedConfig = helperConfig
                    privilegedConfig.supportsPhysicalSize = helperWalkConfig.usePhysicalSize
                    let total = try await PrivilegedScanClient.shared.scanPathWithLiveProgress(
                        atPath: event.path,
                        configuration: privilegedConfig,
                        onProgress: { progress in
                            onPrivilegedProgress?(event.path, progress)
                        }
                    )
                    if total > 0 {
                        sizes[event.path] = total
                        continue
                    }
                } catch {
                    // Fall through to FDA path walk.
                }
            }
            let url = URL(fileURLWithPath: event.path, isDirectory: true)
            guard FileManager.default.isReadableFile(atPath: event.path) else { continue }
            let children = listedChildren(url)
            let result = DirectorySizeWalker.immediateChildSizes(
                at: url,
                listedChildren: children,
                configuration: config
            )
            if result.totalSize > 0 || result.filesScanned > 0 {
                sizes[event.path] = result.totalSize
            }
        }
        return sizes
    }
}
