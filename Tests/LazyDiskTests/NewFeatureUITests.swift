import XCTest
import LazyDiskCore

/// Regression tests for Treemap, Smart Collections, Detail Panel, and panel-integration contracts.
final class NewFeatureUITests: XCTestCase {
    // MARK: - Treemap

    func testTreemapLayoutNestedChildren() {
        let parent = DiskItem(url: URL(fileURLWithPath: "/A"), size: 100, isDirectory: true)
        let child = DiskItem(url: URL(fileURLWithPath: "/A/child"), size: 40, isDirectory: true)
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)

        let rects = TreemapLayoutEngine.layoutHierarchical(
            items: [parent],
            childrenByParentPath: [PathUtils.resolved(parent.url).path: [child]],
            in: bounds
        )

        XCTAssertFalse(rects.isEmpty)
        XCTAssertTrue(rects.contains { $0.item.id == parent.id })
        XCTAssertTrue(rects.contains { $0.item.id == child.id && $0.depth > 0 })
    }

    func testTreemapLargerItemGetsMoreArea() {
        let large = DiskItem(url: URL(fileURLWithPath: "/big"), size: 900, isDirectory: true)
        let small = DiskItem(url: URL(fileURLWithPath: "/small"), size: 100, isDirectory: true)
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        let rects = TreemapLayoutEngine.layout(items: [large, small], in: bounds, padding: 0)

        guard let largeRect = rects.first(where: { $0.item.id == large.id }),
              let smallRect = rects.first(where: { $0.item.id == small.id }) else {
            return XCTFail("Missing treemap rects")
        }

        let largeArea = largeRect.rect.width * largeRect.rect.height
        let smallArea = smallRect.rect.width * smallRect.rect.height
        XCTAssertGreaterThan(largeArea, smallArea)
    }

    // MARK: - Detail panel data

    func testDiskItemStoresCreatedMetadataFields() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let item = DiskItem(
            url: URL(fileURLWithPath: "/f"),
            size: 1,
            isDirectory: false,
            modifiedDate: date
        )
        XCTAssertEqual(item.modifiedDate, date)
        XCTAssertEqual(item.formattedSize, ByteFormatter.string(from: 1))
    }

    // MARK: - Smart collection / panel integration (localization contract)

    func testSmartCollectionLocalizationKeysExist() {
        let keys: [StringKey] = [
            .collectionTitle, .collectionLargeFiles, .collectionOldFiles, .collectionXcode,
            .collectionNodeModules, .collectionOldDownloads, .collectionScanning,
        ]
        assertKeysExistInAllLanguages(keys)
    }

    func testDetailPanelLocalizationKeysExist() {
        let keys: [StringKey] = [
            .detailTitle, .detailPath, .detailCreated, .detailItemCount,
            .detailOpenFolder, .detailShowLargeFiles, .detailShowDetails,
        ]
        assertKeysExistInAllLanguages(keys)
    }

    func testChartStyleLocalizationIncludesTreemap() {
        let keys: [StringKey] = [.chartStyleRose, .chartStyleSunburst, .chartStyleTreemap]
        assertKeysExistInAllLanguages(keys)
    }

    func testPanelIntegrationAndFinderLocalization() {
        let keys: [StringKey] = [
            .cleanupCollectionsHint, .devCollectionsHint,
            .finderAnalyzeVolumeNotFound, .finderAnalyzeHelp,
        ]
        assertKeysExistInAllLanguages(keys)
    }

    func testExternalOpenRoundTripWithAnalyzeTarget() {
        let volumeRoot = URL(fileURLWithPath: "/Volumes/ExampleDisk", isDirectory: true)
        let original = volumeRoot.appendingPathComponent("Projects/MyApp", isDirectory: true)
        let target = ExternalOpenResolver.analyzeTarget(for: original)
        let volumes = [ExternalOpenResolver.VolumeRoot(id: "disk", scanRoot: volumeRoot)]
        XCTAssertNotNil(ExternalOpenResolver.containingVolumeID(for: target, volumes: volumes))
    }

    // MARK: - Helpers

    private func assertKeysExistInAllLanguages(_ keys: [StringKey], file: StaticString = #filePath, line: UInt = #line) {
        let languages: [AppLanguage] = [.english, .persian, .chinese, .french, .arabic, .turkish]
        for key in keys {
            for lang in languages {
                let text = LocalizationCatalog.text(key, language: lang)
                XCTAssertFalse(text.isEmpty, "Empty \(key) for \(lang)", file: file, line: line)
                XCTAssertNotEqual(text, key.rawValue, "Missing \(key) for \(lang)", file: file, line: line)
            }
        }
    }
}
