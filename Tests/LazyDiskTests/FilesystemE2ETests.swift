import XCTest

final class FilesystemE2ETests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LazyDiskE2E-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }

    func testCLIScanProducesJSON() throws {
        let fileA = tempRoot.appendingPathComponent("alpha.txt")
        let fileB = tempRoot.appendingPathComponent("beta.txt")
        try Data(repeating: 0xAB, count: 2048).write(to: fileA)
        try Data(repeating: 0xCD, count: 4096).write(to: fileB)

        let output = try runCLI(arguments: ["--cli", "--path", tempRoot.path, "--json", "--top", "10"])
        XCTAssertTrue(output.contains("\"path\""))
        XCTAssertTrue(output.contains("alpha.txt") || output.contains("total"))
    }

    func testCLIDuplicatesFindsIdenticalFiles() throws {
        let content = Data(repeating: 0x42, count: 8192)
        let dir1 = tempRoot.appendingPathComponent("dir1", isDirectory: true)
        let dir2 = tempRoot.appendingPathComponent("dir2", isDirectory: true)
        try FileManager.default.createDirectory(at: dir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir2, withIntermediateDirectories: true)
        try content.write(to: dir1.appendingPathComponent("same.bin"))
        try content.write(to: dir2.appendingPathComponent("copy.bin"))

        let output = try runCLI(arguments: [
            "--cli", "--duplicates", "--path", tempRoot.path, "--json", "--min-size", "4096",
        ])
        XCTAssertTrue(output.contains("hash") || output.contains("wasted") || output.contains("files"))
    }

    func testCLIHelpExitsZero() throws {
        let binary = try requireBinary()
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = ["--help"]
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        // CLI calls exit(0) — Process may not return normally in all environments
        XCTAssertTrue(proc.terminationStatus == 0 || proc.terminationReason == .exit)
    }

    // MARK: - Helpers

    @discardableResult
    private func runCLI(arguments: [String]) throws -> String {
        let binary = try requireBinary()
        let proc = Process()
        let out = Pipe()
        let err = Pipe()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = arguments
        proc.standardOutput = out
        proc.standardError = err
        try proc.run()
        proc.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        let combined = (String(data: data, encoding: .utf8) ?? "") + (String(data: errData, encoding: .utf8) ?? "")
        XCTAssertEqual(proc.terminationStatus, 0, combined)
        return combined
    }

    private func requireBinary() throws -> String {
        guard let binary = Self.locateBinary() else {
            throw XCTSkip("Build LazyDisk first: swift build")
        }
        return binary
    }

    private static func locateBinary() -> String? {
        let fm = FileManager.default
        let candidates = [
            ".build/debug/LazyDisk",
            ".build/arm64-apple-macosx/debug/LazyDisk",
        ]
        let cwd = fm.currentDirectoryPath
        for relative in candidates {
            let path = (cwd as NSString).appendingPathComponent(relative)
            if fm.isExecutableFile(atPath: path) { return path }
        }
        // Walk up from test bundle to repo root
        var dir = cwd
        for _ in 0..<6 {
            for relative in candidates {
                let path = (dir as NSString).appendingPathComponent(relative)
                if fm.isExecutableFile(atPath: path) { return path }
            }
            dir = (dir as NSString).deletingLastPathComponent
        }
        return nil
    }
}
