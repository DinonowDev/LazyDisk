import LazyDiskCore
import XCTest

final class FullDiskAccessProbeTests: XCTestCase {
    func testRunsWithoutCrashing() {
        _ = FullDiskAccessProbe.isGranted()
    }

    func testDoesNotGrantFromWorldReadableVarAlone() {
        final class StubManager: FileManager, @unchecked Sendable {
            override func fileExists(atPath path: String) -> Bool {
                path == "/private/var"
            }

            override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
                if path.hasSuffix("Library/Safari") {
                    isDirectory?.pointee = false
                    return false
                }
                if path == "/private/var" {
                    isDirectory?.pointee = true
                    return true
                }
                return false
            }

            override var homeDirectoryForCurrentUser: URL {
                URL(fileURLWithPath: "/Users/tester", isDirectory: true)
            }

            override func isReadableFile(atPath path: String) -> Bool {
                path == "/private/var"
            }
        }

        XCTAssertFalse(FullDiskAccessProbe.isGranted(fileManager: StubManager()))
    }
}
