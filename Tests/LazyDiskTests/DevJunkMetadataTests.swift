import XCTest
import LazyDiskCore

final class DevJunkMetadataTests: XCTestCase {
    func testFolderSpecForKnownNames() {
        let spec = DevJunkMetadata.spec(forFolderName: "node_modules")
        XCTAssertEqual(spec.kind, .nodeModules)
        XCTAssertEqual(spec.ecosystem, .javascript)
        XCTAssertEqual(spec.purpose, .dependencies)
        XCTAssertEqual(spec.safety, .safe)
    }

    func testFolderSpecFallback() {
        let spec = DevJunkMetadata.spec(forFolderName: "unknown_folder")
        XCTAssertEqual(spec.kind, .generic)
        XCTAssertEqual(spec.ecosystem, .general)
    }

    func testScannableFolderNamesIncludesCore() {
        let names = DevJunkMetadata.scannableFolderNames
        XCTAssertTrue(names.contains("node_modules"))
        XCTAssertTrue(names.contains(".next"))
        XCTAssertTrue(names.contains("target"))
        XCTAssertTrue(names.contains("__pycache__"))
    }

    func testSummarize() {
        let items = [
            DevJunkItem(
                url: URL(fileURLWithPath: "/tmp/p1/node_modules"),
                name: "node_modules",
                size: 100,
                folderKind: .nodeModules,
                ecosystem: .javascript,
                purpose: .dependencies,
                safety: .safe,
                projectName: "p1",
                projectPath: URL(fileURLWithPath: "/tmp/p1"),
                modifiedAt: nil
            ),
            DevJunkItem(
                url: URL(fileURLWithPath: "/tmp/.cargo/registry"),
                name: "Cargo registry",
                size: 200,
                folderKind: .cargoRegistry,
                ecosystem: .rust,
                purpose: .packageManager,
                safety: .caution,
                projectName: nil,
                projectPath: nil,
                modifiedAt: nil
            ),
        ]
        let summary = DevJunkMetadata.summarize(items)
        XCTAssertEqual(summary.totalSize, 300)
        XCTAssertEqual(summary.itemCount, 2)
        XCTAssertEqual(summary.projectCount, 1)
        XCTAssertEqual(summary.globalCount, 1)
        XCTAssertEqual(summary.byEcosystem[.javascript], 100)
        XCTAssertEqual(summary.byEcosystem[.rust], 200)
    }

    func testMakeItemDetectsProjectName() {
        let tmp = FileManager.default.temporaryDirectory
        let project = tmp.appendingPathComponent("testproj-\(UUID().uuidString)")
        let junk = project.appendingPathComponent("node_modules")
        defer {
            try? FileManager.default.removeItem(at: project)
        }
        try? FileManager.default.createDirectory(at: junk, withIntermediateDirectories: true)
        try? "{}".write(to: project.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

        let item = DevJunkMetadata.makeItem(url: junk, name: "node_modules", size: 1024)
        XCTAssertEqual(item.projectName, project.lastPathComponent)
        XCTAssertEqual(item.projectPath?.path, project.path)
        XCTAssertEqual(item.ecosystem, .javascript)
    }
}
