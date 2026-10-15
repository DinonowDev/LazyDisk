import Foundation

/// Runtime tuning aligned with DaisyDisk-style getattrlistbulk scans (16 KiB bulk buffer, ~5 workers).
public enum NativeScanRuntime {
    public struct Settings: Sendable {
        public let workerCount: Int
        public let bufferSize: Int
        public let turbo: Bool
    }

    public static let daisyBulkBuffer = 0x4000
    public static let daisyTurboBuffer = 0x8000
    public static let daisyDefaultWorkers = 5

    public static func settings(parallelism: Int? = nil, bufferSizeOverride: Int? = nil) -> Settings {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let tuned = NativeScanTuningStore.load()
        let requested = parallelism ?? tuned?.workerCount ?? daisyDefaultWorkers
        let turbo = requested >= 8 || cores >= 10
        let workers = parallelism != nil
            ? min(12, max(1, requested))
            : min(12, max(daisyDefaultWorkers, requested, min(cores, 8)))
        let buffer = bufferSizeOverride ?? tuned?.bufferSize ?? (turbo ? daisyTurboBuffer : daisyBulkBuffer)
        let effectiveTurbo = turbo || buffer >= daisyTurboBuffer
        return Settings(workerCount: workers, bufferSize: buffer, turbo: effectiveTurbo)
    }
}
