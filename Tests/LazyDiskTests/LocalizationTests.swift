import XCTest
import LazyDiskCore

final class LocalizationTests: XCTestCase {
    func testEnglishStringsExist() {
        let text = LocalizationCatalog.text(.welcomeTitle, language: .english)
        XCTAssertEqual(text, "LazyDisk")
    }

    func testPersianStringsExist() {
        let text = LocalizationCatalog.text(.continueBtn, language: .persian)
        XCTAssertEqual(text, "ادامه")
    }

    func testChineseStringsExist() {
        let text = LocalizationCatalog.text(.panelCleanup, language: .chinese)
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "panelCleanup")
    }

    func testAllLanguagesHaveFilterOther() {
        for lang in [AppLanguage.english, .persian, .chinese, .french, .arabic, .turkish] {
            let text = LocalizationCatalog.text(.filterOther, language: lang)
            XCTAssertFalse(text.isEmpty, "Missing filterOther for \(lang)")
        }
    }

    func testFormatStringsWithArguments() {
        let text = LocalizationCatalog.text(.permGrantedCount, language: .english)
        let formatted = String(format: text, 2, 4)
        XCTAssertEqual(formatted, "2 of 4 granted")
    }
}
