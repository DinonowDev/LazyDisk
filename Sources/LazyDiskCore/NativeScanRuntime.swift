import Foundation

/// Runtime tuning for native getattrlistbulk scans (CPU + I/O bound; no GPU path).
enum NativeScanRuntime {
    struct Settings: Sendable {
        let workerCount: Int
        let bufferSize: Int
        let turbo: Bool
    }

    static func settings(parallelism: Int) -> Settings {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let turbo = parallelism >= 6 || cores >= 8
        let base = turbo ? 8 : 5
        let workers = min(12, max(base, parallelism, cores - 1))
        let buffer = turbo ? 256 * 1024 : 128 * 1024
        return Settings(workerCount: workers, bufferSize: buffer, turbo: turbo)
    }
}
