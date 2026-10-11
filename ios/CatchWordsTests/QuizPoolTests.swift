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

    // MARK: - Pinyin for the choices (Utilities/PinyinZhuyin.swift, a port of the web's pinyin-zhuyin.ts)
    // Owner 2026-10-11 「設定でピン音にしても復習で注音が表示される。」. Every expected value is the web converter's output.

    func testZhuyinToPinyinSpellsLikeTheWeb() {
        XCTAssertEqual(PinyinZhuyin.pinyin(fromZhuyin: "ㄇㄤˊ ㄍㄨㄛˇ", want: 2), "máng guǒ")
        // Neutral tone (˙ before the syllable): no mark.
        XCTAssertEqual(PinyinZhuyin.pinyin(fromZhuyin: "ㄐㄩㄝˊ ˙ㄉㄜ", want: 2), "jué de")
        // ü stays after l / n and is written u after j / q / x.
        XCTAssertEqual(PinyinZhuyin.pinyin(fromZhuyin: "ㄏㄨㄥˊ ㄌㄩˋ ㄉㄥ", want: 3), "hóng lǜ dēng")
        XCTAssertEqual(PinyinZhuyin.pinyin(fromZhuyin: "ㄒㄩㄝˊ ㄒㄧㄠˋ", want: 2), "xué xiào")
        // The mark goes on the o of ou, else on the last vowel; zh / ch / sh / r / z / c / s alone take i.
        XCTAssertEqual(PinyinZhuyin.pinyin(fromZhuyin: "ㄧㄡˊ ㄐㄩˊ", want: 2), "yóu jú")
        XCTAssertEqual(PinyinZhuyin.pinyin(fromZhuyin: "ㄋㄧㄡˊ ㄋㄞˇ", want: 2), "niú nǎi")
        XCTAssertEqual(PinyinZhuyin.pinyin(fromZhuyin: "ㄘㄢ ㄐㄧㄣ ㄓˇ", want: 3), "cān jīn zhǐ")
        XCTAssertEqual(PinyinZhuyin.pinyin(fromZhuyin: "ㄦˇ ㄐㄧ", want: 2), "ěr jī")
    }

    func testZhuyinToPinyinCutsRunTogetherSyllablesAndRefusesOtherText() {
        // Written without spaces: the expected syllable count picks the cut.
        XCTAssertEqual(PinyinZhuyin.pinyin(fromZhuyin: "ㄋㄚˊㄊㄧㄝˇ", want: 2), "ná tiě")
        XCTAssertEqual(PinyinZhuyin.pinyin(fromZhuyin: "ㄒㄧㄢ", want: 1), "xiān")
        XCTAssertEqual(PinyinZhuyin.pinyin(fromZhuyin: "ㄒㄧㄢ", want: 2), "xī ān")
        // Kana, IPA, a stray letter, two tones on one syllable, nothing: nil, so the word keeps its own reading.
        XCTAssertNil(PinyinZhuyin.pinyin(fromZhuyin: "かさ", want: 1))
        XCTAssertNil(PinyinZhuyin.pinyin(fromZhuyin: "ˈæpəl"))
        XCTAssertNil(PinyinZhuyin.pinyin(fromZhuyin: "ㄇㄤˊ x", want: 2))
        XCTAssertNil(PinyinZhuyin.pinyin(fromZhuyin: "˙ㄉㄜˊ"))
        XCTAssertNil(PinyinZhuyin.pinyin(fromZhuyin: "  "))
        XCTAssertNil(PinyinZhuyin.pinyin(fromZhuyin: nil))
    }

    /// The pool carries zhuyin only: each 台湾華語 word must spell into pinyin, one syllable per character, or with
    /// ピンイン chosen it would be the one choice still drawn in zhuyin.
    func testEveryMandarinPoolWordSpellsIntoPinyin() {
        for w in QuizPool.words(for: "zh-TW") {
            let han = w.headword.filter(ZhuyinLayout.isHan).count
            let pinyin = PinyinZhuyin.pinyin(fromZhuyin: w.reading, want: han)
            XCTAssertNotNil(pinyin, "\(w.headword): \(w.reading ?? "")")
            XCTAssertEqual(pinyin?.split(separator: " ").count, han, "\(w.headword): \(pinyin ?? "")")
        }
    }
}
