import Foundation
import XCTest
@testable import LazyDiskCore

final class NativeScanBenchmarkTests: XCTestCase {
    func testBenchmarkDefaultVsTurboBuffer() throws {
        if ProcessInfo.processInfo.environment["LDFS_BENCHMARK"] != "1" {
            throw XCTSkip("Set LDFS_BENCHMARK=1 to run native scan benchmark (scans ~/Library).")
        }
        guard NativeDirectoryScanner.isAvailable else {
            throw XCTSkip("Native scanner unavailable")
        }

        let target = ProcessInfo.processInfo.environment["LDFS_BENCHMARK_PATH"]
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library").path
        guard FileManager.default.fileExists(atPath: target) else {
            throw XCTSkip("Benchmark path missing: \(target)")
        }

        let url = URL(fileURLWithPath: target, isDirectory: true)
        let runs = max(1, Int(ProcessInfo.processInfo.environment["BENCHMARK_RUNS"] ?? "2") ?? 2)

        func medianTime(configuration: DirectorySizeWalker.Configuration) -> TimeInterval {
            var samples: [TimeInterval] = []
            for _ in 0..<runs {
                let start = CFAbsoluteTimeGetCurrent()
                _ = DirectorySizeWalker.immediateChildSizes(at: url, configuration: configuration)
                samples.append(CFAbsoluteTimeGetCurrent() - start)
            }
            samples.sort()
            return samples[samples.count / 2]
        }

        let defaultConfig = DirectorySizeWalker.Configuration(
            skipHiddenFiles: true,
            partialUpdateInterval: 4096,
            parallelism: NativeScanRuntime.daisyDefaultWorkers,
            usePhysicalSize: true
        )
        var turboConfig = defaultConfig
        turboConfig.parallelism = 12

        let defaultTime = medianTime(configuration: defaultConfig)
        let turboTime = medianTime(configuration: turboConfig)

        print("benchmark path=\(target)")
        print("  default workers/buffer: \(String(format: "%.3fs", defaultTime))")
        print("  turbo workers:          \(String(format: "%.3fs", turboTime))")

        if let tuning = NativeScanTuningStore.calibrate(
            at: url,
            parallelism: NativeScanRuntime.daisyDefaultWorkers
        ) {
            print("  saved tuning: workers=\(tuning.workerCount) buffer=0x\(String(tuning.bufferSize, radix: 16))")
        }

        XCTAssertGreaterThan(defaultTime, 0)
        XCTAssertGreaterThan(turboTime, 0)
    }
}
