import Foundation

/// The language-mixing rules in one place (docs/language-rules.md, rules R1–R9).
///
/// This file has no dependencies on purpose: CI compiles it on its own with the case table
/// `ios/LanguageRules/cases.json` and fails the build if any rule gives a different answer
/// (`ios/LanguageRules/main.swift`). When a mixed-language bug is found, its text goes into that
/// table first, then this file is changed until every case passes — so the rules only get stricter.
nonisolated enum LanguageRules {
    // MARK: Scripts

    static func isKana(_ v: UInt32) -> Bool { (0x3041...0x309F).contains(v) || (0x30A0...0x30FF).contains(v) || (0x31F0...0x31FF).contains(v) || (0xFF66...0xFF9F).contains(v) }
    static func isHan(_ v: UInt32) -> Bool { (0x3400...0x4DBF).contains(v) || (0x4E00...0x9FFF).contains(v) || (0xF900...0xFAFF).contains(v) || v == 0x3005 }
    static func isHangul(_ v: UInt32) -> Bool { (0xAC00...0xD7AF).contains(v) || (0x1100...0x11FF).contains(v) }
    static func isLatin(_ v: UInt32) -> Bool { (0x41...0x5A).contains(v) || (0x61...0x7A).contains(v) || (0xC0...0x24F).contains(v) }

    struct Counts { var kana = 0, han = 0, hangul = 0, latin = 0; var cjk: Int { kana + han + hangul } }

    static func counts(_ s: String) -> Counts {
        var c = Counts()
        for u in s.unicodeScalars {
            let v = u.value
            if isKana(v) { c.kana += 1 } else if isHan(v) { c.han += 1 } else if isHangul(v) { c.hangul += 1 } else if isLatin(v) { c.latin += 1 }
        }
        return c
    }

    // MARK: R3–R6 — explanation text for a reader

    /// Whether a meaning, translation or note does NOT look written in `reader` (ja / en / zh-TW).
    /// - R3: a copy of the source sentence is wrong in every language.
    /// - R4 ja: a run of ≥5 Han with no kana is Chinese (unless `hanOnlyOk`, for short meanings such
    ///   as 鉄板焼 or 故宮博物院); a Latin-only sentence is English.
    /// - R5 zh-TW: kana that makes up a real part of the text is Japanese (one quoted kana word is fine);
    ///   a Latin-only sentence is English.
    /// - R6 en: more CJK than Latin is not English (a Chinese headword inside English is fine).
    /// Anything unclear is kept — a right translation is never dropped.
    static func looksWrong(_ text: String?, reader: String, source: String? = nil, hanOnlyOk: Bool = false) -> Bool {
        let s = (text ?? "").filter { !$0.isWhitespace }
        guard !s.isEmpty else { return false }
        let strip: (String) -> String = { $0.filter { !$0.isWhitespace && !"。．.,，、!！?？「」『』\"'“”‘’".contains($0) } }
        if let source, !strip(source).isEmpty, strip(source) == strip(s) { return true }
        // R9: words quoted in 「」『』"" are cited examples (often in the learning language), not the
        // language the note is written in — judge the rest. A text that is all quotes is judged whole.
        let body = unquoted(s)
        let judged = body.isEmpty ? s : body
        let c = counts(judged)
        let latinWords = (text ?? "").split(whereSeparator: { !($0.isASCII && $0.isLetter) }).filter { $0.count >= 2 }.count
        let mostlyLatin = c.latin >= 5 && c.latin > c.cjk * 3 && latinWords >= 2
        switch reader {
        case "ja":
            if !hanOnlyOk, judged.count >= 5, c.kana == 0, c.latin == 0, c.hangul == 0, c.han > 0 { return true }
            if c.han == 0, c.kana == 0, c.latin >= 5 { return true }
            if c.hangul > 0, c.hangul >= c.kana + c.han { return true }
            return mostlyLatin
        case "zh-TW":
            if c.kana >= 2, c.kana * 3 >= c.han { return true }
            if c.han == 0, c.latin >= 5 { return true }
            if c.hangul > 0, c.hangul >= c.han { return true }
            return mostlyLatin
        case "en":
            return c.cjk >= 2 && c.cjk > c.latin
        default:
            return false
        }
    }

    /// The text without its quoted parts (「…」, 『…』, “…”, "…").
    static func unquoted(_ s: String) -> String {
        var out = ""
        var closing: Character?
        let pairs: [Character: Character] = ["「": "」", "『": "』", "“": "”", "\"": "\""]
        for ch in s {
            if let c = closing {
                if ch == c { closing = nil }
            } else if let c = pairs[ch] {
                closing = c
            } else {
                out.append(ch)
            }
        }
        return out
    }

    // MARK: R7 — outside text (server errors, database messages)

    /// Whether outside text reads as the display language: ja has kana (or no letters at all);
    /// zh-TW has Han and no kana; en has no CJK, or is overwhelmingly Latin.
    static func readsAs(_ text: String, _ code: String) -> Bool {
        let c = counts(text)
        switch code {
        case "ja": return c.kana > 0 || (c.han == 0 && c.latin == 0)
        case "zh-TW": return c.kana == 0 && (c.han > 0 || c.latin == 0)
        default: return c.cjk == 0 || c.latin > c.cjk * 3
        }
    }

    // MARK: R8 — learning-language content

    /// Whether text is written in the learning language at all (an example sentence, a wordbook row):
    /// Han for Taiwan Mandarin, kana or kanji for Japanese, Latin letters for English.
    static func isIn(_ text: String, target: String) -> Bool {
        let c = counts(text)
        switch target {
        case "en": return c.latin > 0 && c.latin >= c.cjk
        case "ja": return c.kana + c.han > 0
        default: return c.han > 0 && c.kana * 3 < c.han
        }
    }
}
