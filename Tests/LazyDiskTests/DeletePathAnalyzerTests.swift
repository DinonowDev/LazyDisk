import XCTest
import LazyDiskCore

final class DeletePathAnalyzerTests: XCTestCase {
    func testDetectsIOSBackup() {
        let url = URL(fileURLWithPath: "/Users/me/Library/Application Support/MobileSync/Backup/abc")
        XCTAssertTrue(DeletePathAnalyzer.isIOSBackup(url))
        XCTAssertTrue(DeletePathAnalyzer.warningKinds(for: url).contains(.iosBackup))
    }

    func testDetectsTimeMachine() {
        let url = URL(fileURLWithPath: "/Volumes/Backup/Backups.backupdb/Mac")
        XCTAssertTrue(DeletePathAnalyzer.isTimeMachineRelated(url))
    }

    func testDetectsSystemPath() {
        let url = URL(fileURLWithPath: "/System/Library")
        XCTAssertTrue(DeletePathAnalyzer.isCriticalSystemPath(url))
        XCTAssertFalse(DeletePathAnalyzer.isCriticalSystemPath(URL(fileURLWithPath: "/Users/me")))
    }

    func testDetectsSensitiveLibrary() {
        let url = URL(fileURLWithPath: "/Users/me/Library/Mail/V10")
        XCTAssertTrue(DeletePathAnalyzer.isSensitiveLibraryPath(url))
    }

    func testDetectsLibraryContainerPaths() {
        XCTAssertTrue(DeletePathAnalyzer.isLibraryContainerPath(
            URL(fileURLWithPath: "/Users/me/Library/Caches")
        ))
        XCTAssertTrue(DeletePathAnalyzer.isLibraryContainerPath(
            URL(fileURLWithPath: "/Users/me/Library/Logs")
        ))
        XCTAssertTrue(DeletePathAnalyzer.isLibraryContainerPath(
            URL(fileURLWithPath: "/Users/me/Library")
        ))
        XCTAssertTrue(DeletePathAnalyzer.isLibraryContainerPath(
            URL(fileURLWithPath: "/Library/Caches")
        ))
        XCTAssertFalse(DeletePathAnalyzer.isLibraryContainerPath(
            URL(fileURLWithPath: "/Users/me/Library/Caches/Homebrew")
        ))
        XCTAssertFalse(DeletePathAnalyzer.isLibraryContainerPath(
            URL(fileURLWithPath: "/Users/me/Library/Application Support")
        ))
    }
}
