import Foundation
import LazyDiskCore
import XCTest

final class NativeScanSmokeTests: XCTestCase {
    func testImmediateChildSizesWithSeveralChildren() throws {
        guard NativeDirectoryScanner.isAvailable else {
            throw XCTSkip("Native scanner unavailable")
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ldfs-smoke-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for index in 1...6 {
            let child = root.appendingPathComponent("child\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
            try Data("x".utf8).write(to: child.appendingPathComponent("f.txt"))
        }

        var config = DirectorySizeWalker.Configuration(
            skipHiddenFiles: true,
            partialUpdateInterval: 4096,
            parallelism: NativeScanRuntime.daisyDefaultWorkers,
            usePhysicalSize: true
        )
        let result = DirectorySizeWalker.immediateChildSizes(at: root, configuration: config)
        XCTAssertGreaterThan(result.totalSize, 0)
        XCTAssertGreaterThan(result.filesScanned, 0)
    }

    func testFusedVolumeScanOnTempTree() throws {
        guard NativeDirectoryScanner.isAvailable else {
            throw XCTSkip("Native scanner unavailable")
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ldfs-fused-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for index in 1...4 {
            let child = root.appendingPathComponent("child\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
            try Data(repeating: 0xAB, count: 4096).write(to: child.appendingPathComponent("blob.bin"))
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )
        let items = contents.compactMap { url -> DiskItem? in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            guard isDir else { return nil }
            return DiskItem(url: PathUtils.resolved(url), isDirectory: true, isScanning: true)
        }

        let immediate = DirectorySizeWalker.immediateChildSizes(
            at: root,
            listedChildren: items.map(\.url),
            configuration: .volumeRoot
        )
        XCTAssertGreaterThan(immediate.filesScanned, 0, "immediate baseline")

        guard let fused = NativeDirectoryScanner.fusedVolumeScan(
            at: root,
            listedEntries: items,
            maxDepth: 2,
            skipHiddenFiles: true,
            parallelism: 2
        ) else {
            XCTFail("fusedVolumeScan nil")
            return
        }

        XCTAssertGreaterThan(fused.chartResult.totalSize, 0, "files=\(fused.chartResult.filesScanned)")
        XCTAssertFalse(fused.sizingWalk.childSizesByPath.isEmpty)
    }

    func testVolumeTreeScanRecordsNestedDirectories() throws {
        guard NativeDirectoryScanner.isAvailable else {
            throw XCTSkip("Native scanner unavailable")
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ldfs-tree-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let child = root.appendingPathComponent("child", isDirectory: true)
        let nested = child.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 0xCD, count: 2048).write(to: nested.appendingPathComponent("inner.bin"))

        let items = [
            DiskItem(url: PathUtils.resolved(child), isDirectory: true, isScanning: true),
        ]

        let immediate = DirectorySizeWalker.immediateChildSizes(
            at: root,
            listedChildren: items.map(\.url),
            configuration: .default
        )
        XCTAssertGreaterThan(immediate.filesScanned, 0)

        guard let tree = NativeDirectoryScanner.volumeTreeScan(
            at: root,
            listedEntries: items,
            chartMaxDepth: 4,
            skipHiddenFiles: true,
            parallelism: 2
        ) else {
            XCTFail("volumeTreeScan nil")
            return
        }

        XCTAssertGreaterThan(tree.sizingWalk.filesScanned, 0)
        XCTAssertGreaterThan(tree.chartResult.totalSize, 0)
        let nestedPath = PathUtils.resolved(nested).path
        if let nestedSize = tree.indexedPathSizes[nestedPath]
            ?? tree.indexedPathSizes.first(where: { $0.key.hasSuffix("/nested") })?.value {
            XCTAssertGreaterThan(nestedSize, 0)
        }
        XCTAssertGreaterThanOrEqual(tree.chartResult.statsByPath.count, 2)
    }

    func testVolumeTreeScanExportsBreadthPathStats() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lazydisk-breadth-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var items: [DiskItem] = []
        for index in 0..<12 {
            let child = root.appendingPathComponent("branch\(index)", isDirectory: true)
            let nested = child.appendingPathComponent("leaf", isDirectory: true)
            try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
            try Data(repeating: UInt8(index), count: 1024).write(to: nested.appendingPathComponent("f.bin"))
            items.append(DiskItem(url: PathUtils.resolved(child), isDirectory: true, isScanning: true))
        }

        guard let tree = NativeDirectoryScanner.volumeTreeScan(
            at: root,
            listedEntries: items,
            chartMaxDepth: 4,
            skipHiddenFiles: true,
            parallelism: 2
        ) else {
            XCTFail("volumeTreeScan nil")
            return
        }

        XCTAssertGreaterThan(tree.chartResult.statsByPath.count, items.count)
    }

    func testDocumentsFolderNativeScan() throws {
        if ProcessInfo.processInfo.environment["LDFS_DOCUMENTS_SMOKE"] != "1" {
            throw XCTSkip("Set LDFS_DOCUMENTS_SMOKE=1 to scan ~/Documents.")
        }
        guard NativeDirectoryScanner.isAvailable else {
            throw XCTSkip("Native scanner unavailable")
        }

        let documents = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
        guard FileManager.default.fileExists(atPath: documents.path) else {
            throw XCTSkip("No Documents folder")
        }

        var config = DirectorySizeWalker.Configuration(
            skipHiddenFiles: true,
            partialUpdateInterval: 4096,
            parallelism: NativeScanRuntime.daisyDefaultWorkers,
            usePhysicalSize: true
        )
        let result = DirectorySizeWalker.immediateChildSizes(at: documents, configuration: config)
        XCTAssertGreaterThan(result.filesScanned, 0)
    }
}
