import Foundation

public struct NativeScanTuning: Codable, Sendable, Equatable {
    public var workerCount: Int
    public var bufferSize: Int
    public var calibratedAt: Date

    public init(workerCount: Int, bufferSize: Int, calibratedAt: Date = Date()) {
        self.workerCount = workerCount
        self.bufferSize = bufferSize
        self.calibratedAt = calibratedAt
    }
}

/// Persists A/B scan tuning (16 KiB vs 32 KiB buffer, worker sweep) from benchmark or first-run calibration.
public enum NativeScanTuningStore {
    private static let fileName = "scan-tuning.json"

    public static func load() -> NativeScanTuning? {
        guard let url = storageURL(),
              let data = try? Data(contentsOf: url),
              let tuning = try? JSONDecoder().decode(NativeScanTuning.self, from: data) else {
            return nil
        }
        return tuning
    }

    public static func save(_ tuning: NativeScanTuning) {
        guard let url = storageURL() else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(tuning) {
            try? data.write(to: url, options: .atomic)
        }
    }

    @discardableResult
    public static func calibrate(at directory: URL, parallelism: Int? = nil) -> NativeScanTuning? {
        guard NativeDirectoryScanner.isAvailable else { return nil }
        let workers = min(12, max(daisyDefaultWorkers, parallelism ?? daisyDefaultWorkers))

        func medianSeconds(bufferSize: Int, runs: Int = 2) -> TimeInterval {
            var samples: [TimeInterval] = []
            for _ in 0..<runs {
                let start = CFAbsoluteTimeGetCurrent()
                _ = benchmarkWalk(at: directory, workers: workers, bufferSize: bufferSize)
                samples.append(CFAbsoluteTimeGetCurrent() - start)
            }
            samples.sort()
            return samples[samples.count / 2]
        }

        let smallBufferTime = medianSeconds(bufferSize: NativeScanRuntime.daisyBulkBuffer)
        let largeBufferTime = medianSeconds(bufferSize: NativeScanRuntime.daisyTurboBuffer)
        let buffer = largeBufferTime < smallBufferTime * 0.97
            ? NativeScanRuntime.daisyTurboBuffer
            : NativeScanRuntime.daisyBulkBuffer

        let tuning = NativeScanTuning(workerCount: workers, bufferSize: buffer)
        save(tuning)
        return tuning
    }

    private static let daisyDefaultWorkers = NativeScanRuntime.daisyDefaultWorkers

    private static func benchmarkWalk(at directory: URL, workers: Int, bufferSize: Int) -> DirectorySizeWalker.WalkResult {
        var config = DirectorySizeWalker.Configuration.volumeRoot
        config.parallelism = workers
        config.partialUpdateInterval = 4096
        config.nativeBufferSize = bufferSize
        return DirectorySizeWalker.immediateChildSizes(at: directory, configuration: config)
    }

    private static func storageURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("LazyDisk", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
