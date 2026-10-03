import XCTest
@testable import CatchWords

/// The review quiz's padding (Models/QuizPool.swift): every pool word must be drawable in its own learning language,
/// and the ranking must put the same category key first, then the same room. No exam levels (owner 2026-10-03).
/// Run on its own by .github/workflows/ios-check.yml.
final class QuizPoolTests: XCTestCase {
    func testPoolShape() {
        for lang in ["zh-TW", "en", "ja"] {
            let words = QuizPool.words(for: lang)
            XCTAssertGreaterThanOrEqual(words.count, 16, "\(lang): pool is too thin")
            XCTAssertEqual(Set(words.map(\.headword)).count, words.count, "\(lang): duplicate headwords")
            for w in words {
                XCTAssertNotNil(Category.meta[w.categoryKey], "\(lang): \(w.headword) key \(w.categoryKey)")
                switch lang {
                case "en":
                    XCTAssertNil(w.reading, w.headword)
                    XCTAssertTrue(w.headword.unicodeScalars.allSatisfy { $0.isASCII }, w.headword)
                case "ja":
                    XCTAssertTrue(w.headword.isIn(target: "ja"), w.headword)
                    if let r = w.reading {
                        XCTAssertTrue(r.unicodeScalars.allSatisfy { (0x3041...0x3096).contains($0.value) }, "\(w.headword): \(r)")
                    }
                default:
                    XCTAssertTrue(w.headword.allSatisfy(ZhuyinLayout.isHan), w.headword)
                    XCTAssertNotNil(ZhuyinLayout.pair(w.headword, w.reading), "\(w.headword): \(w.reading ?? "")")
                }
            }
        }
    }

    func testRankingPrefersTheSameCategoryThenTheSameRoom() {
        for lang in ["zh-TW", "en", "ja"] {
            for key in ["appliance", "fruit", "vehicle"] {
                let ranked = QuizPool.ranked(for: lang, categoryKey: key)
                XCTAssertEqual(ranked.count, QuizPool.words(for: lang).count)
                let room = Category.room(for: key)
                let kin = ranked.map { $0.categoryKey == key ? 0 : (Category.room(for: $0.categoryKey) == room ? 1 : 2) }
                XCTAssertEqual(kin, kin.sorted(), "\(lang) \(key): same key, then same room, then the rest")
                XCTAssertEqual(ranked.first?.categoryKey, key, "\(lang) \(key)")
            }
        }
        // No category: every word still comes back.
        XCTAssertEqual(QuizPool.ranked(for: "zh-TW", categoryKey: nil).count, QuizPool.words(for: "zh-TW").count)
    }
}
