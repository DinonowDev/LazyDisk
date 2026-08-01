import XCTest
import LazyDiskCore

final class LocalizationCompletenessTests: XCTestCase {
    func testNewUIKeysExistInAllLanguages() {
        let keys: [StringKey] = [
            .chartNoData, .itemsCount, .dupGroupsCount, .devFoldersCount, .removeFromCollector,
            .overviewVolume, .overviewUsed, .overviewAvailable, .overviewCurrentFolder, .overviewOfSize,
            .warnIOSBackupTitle, .warnIOSBackupMsg, .deleteSummaryOne, .deleteSummaryMany,
            .chartStyleTreemap, .collectionTitle, .collectionLargeFiles, .detailTitle, .detailPath,
            .detailCreated, .detailShowDetails, .chartHintSelect,
            .cleanupCollectionsHint, .devCollectionsHint,
            .cleanupEmptyDesc, .cleanupBreakdown, .cleanupCategoryCount, .cleanupSummarySubtitle, .cleanupSortScore,
            .devEmptyDesc, .devReclaimable, .devSummarySubtitle, .devGroupByProject,
            .devPurposeDependencies, .devSafetySafe, .devDescNodeModules,
            .finderAnalyzeVolumeNotFound, .finderAnalyzeHelp,
        ]
        let languages: [AppLanguage] = [.english, .persian, .chinese, .french, .arabic, .turkish]

        for key in keys {
            for lang in languages {
                let text = LocalizationCatalog.text(key, language: lang)
                XCTAssertFalse(text.isEmpty)
                XCTAssertNotEqual(text, key.rawValue, "Missing \(key) for \(lang)")
            }
        }
    }

    func testDeleteSummaryFormats() {
        let one = String(format: LocalizationCatalog.text(.deleteSummaryOne, language: .english), "1 MB")
        XCTAssertTrue(one.contains("1 MB"))

        let many = String(format: LocalizationCatalog.text(.deleteSummaryMany, language: .english), 3, "5 MB")
        XCTAssertTrue(many.contains("3"))
        XCTAssertTrue(many.contains("5 MB"))
    }
}
