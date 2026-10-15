import Foundation
import XCTest
@testable import LazyDiskCore

final class VolumeScanBenchmarkTests: XCTestCase {
    func testNavigationHarnessOnTempTree() async {
        let root = makeDeepTempTree(depth: 5)
        defer { try? FileManager.default.removeItem(at: root) }

        let report = await VolumeScanBenchmark.run(options: VolumeScanBenchmark.Options(
            scanRoot: root,
            skipHiddenFiles: true,
            parallelism: 2,
            chartMaxDepth: 5,
            prefetchDisplayDepth: 2,
            navigationSteps: 20,
            fullVolumeIndex: true
        ))
        XCTAssertNotNil(report)
        XCTAssertGreaterThan(report?.navigationSteps ?? 0, 0)
        XCTAssertGreaterThan(report?.gatedReadySeconds ?? 0, 0)
    }

    func testVolumeScanBenchmarkReport() async throws {
        if ProcessInfo.processInfo.environment["LAZYDISK_BENCHMARK"] != "1" {
            throw XCTSkip("Set LAZYDISK_BENCHMARK=1 to run full volume benchmark.")
        }

        let path = ProcessInfo.processInfo.environment["LAZYDISK_BENCHMARK_ROOT"]
            ?? "/System/Volumes/Data"
        let root = URL(fileURLWithPath: path, isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw XCTSkip("Benchmark root missing: \(path)")
        }

        let steps = Int(ProcessInfo.processInfo.environment["LAZYDISK_BENCHMARK_NAV_STEPS"] ?? "20") ?? 20
        let report = await VolumeScanBenchmark.run(options: VolumeScanBenchmark.Options(
            scanRoot: root,
            skipHiddenFiles: false,
            navigationSteps: max(1, steps)
        ))
        XCTAssertNotNil(report)

        guard let report else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(report)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        print("BENCHMARK_JSON=\(json)")

        print("benchmark summary scanRoot=\(report.scanRoot)")
        print("  gated_ready:        \(String(format: "%.3fs", report.gatedReadySeconds))")
        print("  volume_tree_scan:   \(phaseSeconds(report, name: "volume_tree_scan"))")
        print("  prefetch_display:   \(phaseSeconds(report, name: "prefetch_display_depth"))")
        print("  nav_\(report.navigationSteps)_total:  \(String(format: "%.3fs", report.navigationTotalSeconds))")
        print("  nav_median:         \(String(format: "%.3fs", report.navigationMedianSeconds))")
        print("  nav_p95:            \(String(format: "%.3fs", report.navigationP95Seconds))")
        print("  indexed_paths:      \(report.indexedPathCount)")
        print("  files_scanned:      \(report.volumeTreeFilesScanned)")

        XCTAssertGreaterThan(report.gatedReadySeconds, 0)
        XCTAssertGreaterThan(report.navigationSteps, 0)
    }

    private func phaseSeconds(_ report: VolumeScanBenchmark.Report, name: String) -> String {
        let value = report.phases.first { $0.name == name }?.seconds ?? 0
        return String(format: "%.3fs", value)
    }

    private func makeDeepTempTree(depth: Int) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lazydisk-bench-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var current = root
        for level in 0..<depth {
            let child = current.appendingPathComponent("level\(level)", isDirectory: true)
            try? FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
            let file = child.appendingPathComponent("blob.bin")
            try? Data(repeating: UInt8(level), count: 4_096).write(to: file)
            current = child
        }
        return root
    }
}
