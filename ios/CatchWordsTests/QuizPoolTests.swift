import XCTest
@testable import CatchWords

/// The review quiz's level-matched padding (Models/QuizPool.swift): the level reading must match the web's
/// level-scale.ts, every pool word must be drawable in its own learning language, and the ranking must put the
/// closest level first. Run on its own by .github/workflows/ios-check.yml.
final class QuizPoolTests: XCTestCase {
    func testLevelSteps() {
        let cases: [(String?, Int?)] = [
            ("TOCFL-1", 1), ("TOCFL-4", 4), ("TOCFL-6", 6), ("TOCFL-0", nil), ("TOCFL-7", nil),
            ("A1", 1), ("A2", 2), ("B1", 3), ("C2", 6), ("CEFR-0", nil),
            ("JLPT-N5", 1), ("JLPT-N3", 3), ("JLPT-N1", 5), ("JLPT-N1+", 6), ("JLPT-0", nil),
            ("級外", nil), ("", nil), (nil, nil),
        ]
        for (raw, want) in cases {
            XCTAssertEqual(QuizPool.step(raw), want, "level \(raw ?? "nil")")
        }
    }

    func testPoolShape() {
        for lang in ["zh-TW", "en", "ja"] {
            let words = QuizPool.words(for: lang)
            XCTAssertEqual(Set(words.map(\.headword)).count, words.count, "\(lang): duplicate headwords")
            for step in 1...4 {
                XCTAssertGreaterThanOrEqual(words.filter { $0.step == step }.count, 4, "\(lang): step \(step) is too thin")
            }
            for w in words {
                XCTAssertTrue((1...4).contains(w.step), "\(lang): \(w.headword) step \(w.step)")
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

    func testRankingPrefersTheClosestLevel() {
        let en = QuizPool.ranked(for: "en", level: "B2", categoryKey: "appliance")
        XCTAssertEqual(en.count, QuizPool.words(for: "en").count)
        XCTAssertTrue(en.prefix(3).allSatisfy { $0.step == 4 })
        XCTAssertEqual(en.first?.categoryKey, "appliance")
        // No readable level: the beginner words.
        let zh = QuizPool.ranked(for: "zh-TW", level: nil, categoryKey: "other")
        XCTAssertTrue(zh.prefix(3).allSatisfy { $0.step == 1 })
        // A step beyond the pool (N1) is padded with its highest step.
        let ja = QuizPool.ranked(for: "ja", level: "JLPT-N1", categoryKey: "fruit")
        XCTAssertTrue(ja.prefix(3).allSatisfy { $0.step == 4 })
    }
}
