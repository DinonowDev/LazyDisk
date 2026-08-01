import XCTest
import LazyDiskCore

/// Integration-style tests combining multiple core modules.
final class IntegrationTests: XCTestCase {
    func testFileKindDetectionDrivesContentFilter() {
        let samples: [(String, ContentFilter)] = [
            ("/photo.heic", .images),
            ("/movie.mov", .videos),
            ("/song.flac", .audio),
            ("/report.pdf", .documents),
            ("/backup.zip", .archives),
            ("/App.app", .applications),
            ("/main.swift", .developer),
            ("/unknown.xyz", .other),
        ]

        for (path, expectedFilter) in samples {
            let item = DiskItem(url: URL(fileURLWithPath: path), isDirectory: false)
            XCTAssertTrue(expectedFilter.matches(item), "Expected \(path) to match \(expectedFilter)")
            XCTAssertFalse(ContentFilter.folders.matches(item))
        }
    }

    func testScanDiffRoundTripWithDiskItems() {
        let folder = DiskItem(url: URL(fileURLWithPath: "/Projects"), size: 1_000, isDirectory: true)
        let doc = DiskItem(url: URL(fileURLWithPath: "/Projects/readme.md"), size: 200, isDirectory: false)

        let snapshot = ScanSnapshot(
            volumeID: "test-vol",
            totalUsed: 1_000,
            totalFiles: 1,
            entries: [SnapshotEntry(path: folder.url.path, size: 800, isDirectory: true)]
        )

        let diff = ScanHistoryDiff.computeDiff(current: [folder, doc], previous: snapshot)
        XCTAssertEqual(diff.addedPaths.count, 1)
        XCTAssertEqual(diff.changedPaths.first?.path, folder.url.path)
        XCTAssertEqual(diff.changedPaths.first?.delta, 200)
    }

    func testLocalizationCatalogCoversAllFiltersInSixLanguages() {
        let filters: [StringKey] = [
            .filterAll, .filterFolders, .filterImages, .filterVideos, .filterAudio,
            .filterDocuments, .filterArchives, .filterApps, .filterDeveloper, .filterOther,
        ]
        let languages: [AppLanguage] = [.english, .persian, .chinese, .french, .arabic, .turkish]

        for key in filters {
            for lang in languages {
                let text = LocalizationCatalog.text(key, language: lang)
                XCTAssertFalse(text.isEmpty)
                XCTAssertNotEqual(text, key.rawValue, "Missing translation for \(key) in \(lang)")
            }
        }
    }
}
