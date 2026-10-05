import XCTest
@testable import CatchWords

/// `ReaderLanguage.gloss`: a sentence-long meaning is shown as a short gloss in the quiz question, on the card
/// and on the tags (owner report 2026-10-04). Run on its own by .github/workflows/ios-check.yml.
final class MeaningGlossTests: XCTestCase {
    func testShortMeaningsStayAsTheyAre() {
        XCTAssertEqual(ReaderLanguage.gloss("マンゴー"), "マンゴー")
        XCTAssertEqual(ReaderLanguage.gloss("  scooter "), "scooter")
        XCTAssertEqual(ReaderLanguage.gloss("a small, round fruit"), "a small, round fruit")
        XCTAssertEqual(ReaderLanguage.gloss(""), "")
    }

    func testLongMeaningsAreCutAtTheirFirstClause() {
        XCTAssertEqual(ReaderLanguage.gloss("傘。雨や日差しを防ぐために頭の上にさして使う道具のこと"), "傘")
        XCTAssertEqual(ReaderLanguage.gloss("芒果，一種產於熱帶地區、果肉多汁香甜的水果"), "芒果")
        XCTAssertEqual(ReaderLanguage.gloss("umbrella; a device for protection against the rain or the sun"), "umbrella")
    }

    func testLongMeaningsWithoutAClauseAreShortened() {
        let ja = ReaderLanguage.gloss("雨や日差しを防ぐために頭の上にさして使う折りたたみ式の道具")
        XCTAssertTrue(ja.hasSuffix("…"))
        XCTAssertLessThanOrEqual(ja.count, 20)
        let en = ReaderLanguage.gloss("a device that people hold over their heads to keep off the rain or the sun")
        XCTAssertTrue(en.hasSuffix("…"))
        XCTAssertLessThanOrEqual(en.count, 40)
        XCTAssertFalse(en.contains("  "))
    }
}
