import Foundation

public struct CLIOptions: Sendable, Equatable {
    public var path: String?
    public var top: Int
    public var json: Bool
    public var duplicates: Bool
    public var cleanup: Bool
    public var dev: Bool
    public var minSize: Int64?
    public var help: Bool
    public var cli: Bool

    public init(
        path: String? = nil,
        top: Int = 20,
        json: Bool = false,
        duplicates: Bool = false,
        cleanup: Bool = false,
        dev: Bool = false,
        minSize: Int64? = nil,
        help: Bool = false,
        cli: Bool = false
    ) {
        self.path = path
        self.top = top
        self.json = json
        self.duplicates = duplicates
        self.cleanup = cleanup
        self.dev = dev
        self.minSize = minSize
        self.help = help
        self.cli = cli
    }
}

public enum CLIParser {
    public static func parse(_ args: [String]) -> CLIOptions {
        var options = CLIOptions()
        options.help = args.contains("--help") || args.contains("-h")
        options.cli = args.contains("--cli") || options.help
        options.json = args.contains("--json")
        options.duplicates = args.contains("--duplicates")
        options.cleanup = args.contains("--cleanup")
        options.dev = args.contains("--dev")
        options.path = stringArg(args, flag: "--path")
        options.top = intArg(args, flag: "--top") ?? 20
        if let min = intArg(args, flag: "--min-size") {
            options.minSize = Int64(min)
        }
        return options
    }

    public static func stringArg(_ args: [String], flag: String) -> String? {
        guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }

    public static func intArg(_ args: [String], flag: String) -> Int? {
        guard let value = stringArg(args, flag: flag) else { return nil }
        return Int(value)
    }
}
