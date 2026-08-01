import Foundation

enum CLICommandRunner {
    static func runIfNeeded() -> Bool {
        let args = CommandLine.arguments
        guard args.contains("--cli") || args.contains("--help") || args.contains("-h") else { return false }

        if args.contains("--help") || args.contains("-h") {
            printHelp()
            exit(0)
        }

        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                try await execute(args: args)
            } catch {
                fputs("Error: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
            semaphore.signal()
        }
        semaphore.wait()
        exit(0)
    }

    private static func printHelp() {
        print("""
        LazyDisk CLI

        Usage:
          LazyDisk --cli --path <directory> [options]
          LazyDisk --cli --duplicates --path <directory> [options]
          LazyDisk --cli --cleanup --path <directory> [options]
          LazyDisk --cli --dev [options]

        Options:
          --path <dir>       Directory or volume root to scan
          --top <n>          Show top N items (default: 20)
          --json             Output as JSON
          --min-size <bytes> Minimum file size for duplicates (default: 4096)
          --help, -h         Show this help
        """)
    }

    private static func execute(args: [String]) async throws {
        let json = args.contains("--json")
        let top = intArg(args, flag: "--top") ?? 20

        if args.contains("--duplicates") {
            let path = requirePath(args)
            let url = URL(fileURLWithPath: path, isDirectory: true)
            let groups = await DuplicateFinderService.findDuplicates(in: url) { progress in
                if !json {
                    fputs("\r\(progress.statusText) \(progress.scannedFiles) files…", stderr)
                }
            }
            if json {
                let payload = groups.map { g in
                    ["hash": g.hash, "wasted": g.totalWasted, "files": g.files.map { $0.url.path }] as [String: Any]
                }
                print(jsonString(payload) ?? "[]")
            } else {
                print("Duplicates in \(path): \(groups.count) groups")
                for group in groups.prefix(top) {
                    print("  Waste: \(ByteFormatter.string(from: group.totalWasted)) (\(group.files.count) files)")
                    for file in group.files.prefix(5) {
                        print("    \(file.url.path)")
                    }
                }
            }
            return
        }

        if args.contains("--cleanup") {
            let path = requirePath(args)
            let url = URL(fileURLWithPath: path, isDirectory: true)
            let suggestions = await CleanupSuggestionService.scan(volumeRoot: url)
            if json {
                let payload = suggestions.map { ["name": $0.name, "path": $0.url.path, "size": $0.size, "reason": $0.reason] }
                print(jsonString(payload) ?? "[]")
            } else {
                print("Cleanup suggestions for \(path):")
                for s in suggestions.prefix(top) {
                    print("  \(ByteFormatter.string(from: s.size))\t\(s.name) — \(s.reason)")
                }
            }
            return
        }

        if args.contains("--dev") {
            let items = await DevModeService.scan()
            if json {
                let payload = items.map { ["name": $0.name, "path": $0.url.path, "size": $0.size, "category": $0.category] }
                print(jsonString(payload) ?? "[]")
            } else {
                print("Developer junk:")
                for item in items.prefix(top) {
                    print("  \(ByteFormatter.string(from: item.size))\t\(item.name) [\(item.category)]")
                }
            }
            return
        }

        // Default: directory scan
        let path = requirePath(args)
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let scanner = DiskScanner.shared
        let items = await scanner.listDirectory(at: url)
        let scanned = await scanner.scanDirectorySizes(items: items, parallelism: 6)
        let total = scanned.reduce(Int64(0)) { $0 + $1.size }

        if json {
            let payload: [String: Any] = [
                "path": path,
                "total": total,
                "count": scanned.count,
                "items": scanned.sorted { $0.size > $1.size }.prefix(top).map {
                    ["name": $0.name, "path": $0.url.path, "size": $0.size] as [String: Any]
                }
            ]
            print(jsonString(payload) ?? "{}")
        } else {
            print("Path: \(path)")
            print("Total: \(ByteFormatter.string(from: total))")
            print("Items: \(scanned.count)")
            for item in scanned.sorted(by: { $0.size > $1.size }).prefix(top) {
                print("  \(ByteFormatter.string(from: item.size))\t\(item.name)")
            }
        }
    }

    private static func requirePath(_ args: [String]) -> String {
        guard let path = CLIParser.stringArg(args, flag: "--path") else {
            fputs("Missing --path <directory>\n", stderr)
            exit(1)
        }
        return path
    }

    private static func intArg(_ args: [String], flag: String) -> Int? {
        CLIParser.intArg(args, flag: flag)
    }

    private static func jsonString(_ object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
