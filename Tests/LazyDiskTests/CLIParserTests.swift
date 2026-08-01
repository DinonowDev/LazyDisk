import XCTest
import LazyDiskCore

final class CLIParserTests: XCTestCase {
    func testParseDefaults() {
        let options = CLIParser.parse(["LazyDisk", "--cli", "--path", "/tmp"])
        XCTAssertTrue(options.cli)
        XCTAssertEqual(options.path, "/tmp")
        XCTAssertEqual(options.top, 20)
        XCTAssertFalse(options.json)
    }

    func testParseDuplicatesJSON() {
        let options = CLIParser.parse([
            "LazyDisk", "--cli", "--duplicates", "--path", "/Users", "--json", "--top", "5",
        ])
        XCTAssertTrue(options.duplicates)
        XCTAssertTrue(options.json)
        XCTAssertEqual(options.top, 5)
    }

    func testParseHelp() {
        let options = CLIParser.parse(["LazyDisk", "--help"])
        XCTAssertTrue(options.help)
        XCTAssertTrue(options.cli)
    }

    func testParseDevMode() {
        let options = CLIParser.parse(["LazyDisk", "--cli", "--dev", "--json"])
        XCTAssertTrue(options.dev)
        XCTAssertTrue(options.json)
    }

    func testIntArgMissing() {
        XCTAssertNil(CLIParser.intArg(["--top"], flag: "--top"))
    }
}
