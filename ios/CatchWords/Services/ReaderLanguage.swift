import Foundation

/// Server-written text (meanings, translations, notes) shown only in the reader's language.
///
/// Words are one shared row per (language, headword), so the meaning and notes on that row are in the
/// language of whoever made the card first. The reader's own explanation lives in
/// `word_explanations (word_id, explain_lang, l1)`. This file ports the web's rules for choosing
/// between them (`word-explanation.ts`, `note-language.ts`, `reader-language.ts`), so a Japanese
/// meaning never shows on an English or Chinese screen — or the other way round.
nonisolated enum ReaderLanguage {
    /// The language explanations are written in (= display language).
    static var explainLang: String { L10n.lang }
    /// The learner's old native language (`profiles.native_language`), set when the profile loads.
    nonisolated(unsafe) static var native: String?

    /// web `readerL1`: the display language when it differs from the learning language, else the old
    /// native language, else the first allowed choice.
    static func l1(native: String?, target: String) -> String {
        let order = ["ja", "en", "zh-TW"]
        let choices = order.filter { $0 != target }
        if choices.contains(L10n.lang) { return L10n.lang }
        if let n = native, choices.contains(n) { return n }
        return choices.first ?? "ja"
    }

    // MARK: - looksWrongForReader (note-language.ts)

    private static func isKana(_ v: UInt32) -> Bool { (0x3041...0x309F).contains(v) || (0x30A0...0x30FF).contains(v) }
    private static func isHan(_ v: UInt32) -> Bool { (0x3400...0x4DBF).contains(v) || (0x4E00...0x9FFF).contains(v) || v == 0x3005 }
    private static func isHangul(_ v: UInt32) -> Bool { (0xAC00...0xD7AF).contains(v) }
    private static func isLatin(_ v: UInt32) -> Bool { (0x41...0x5A).contains(v) || (0x61...0x7A).contains(v) }

    /// Whether a translation or note does NOT look written in `reader` (copies of the source sentence
    /// count as wrong in every language). Unknown cases are kept — a right translation is never dropped.
    static func looksWrong(_ text: String?, reader: String, source: String? = nil, hanOnlyOk: Bool = false) -> Bool {
        let s = (text ?? "").filter { !$0.isWhitespace }
        guard !s.isEmpty else { return false }
        let strip: (String) -> String = { $0.filter { !$0.isWhitespace && !"。．.,，、!！?？「」『』\"'“”‘’".contains($0) } }
        if let source, !strip(source).isEmpty, strip(source) == strip(s) { return true }
        var kana = 0, han = 0, hangul = 0, latin = 0
        for u in s.unicodeScalars {
            let v = u.value
            if isKana(v) { kana += 1 } else if isHan(v) { han += 1 } else if isHangul(v) { hangul += 1 } else if isLatin(v) { latin += 1 }
        }
        let cjk = kana + han + hangul
        let latinWords = (text ?? "").split(whereSeparator: { !($0.isASCII && $0.isLetter) }).filter { $0.count >= 2 }.count
        let mostlyLatin = latin >= 5 && latin > cjk * 3 && latinWords >= 2
        switch reader {
        case "ja":
            // A run of Han only (≥5 chars, no kana, no Latin) is Chinese, unless han-only is allowed.
            if !hanOnlyOk, s.count >= 5, kana == 0, latin == 0, hangul == 0, han > 0 { return true }
            if han == 0, kana == 0, latin >= 5 { return true }
            return mostlyLatin
        case "zh-TW":
            // Japanese: kana makes up a real part of it (a Chinese note may quote one kana word).
            if kana >= 2, kana * 3 >= han { return true }
            if han == 0, latin >= 5 { return true }
            return mostlyLatin
        case "en":
            return cjk >= 2 && cjk > latin
        default:
            return false
        }
    }

    /// The first of `texts` written in the display language, or "" (never another language).
    static func shown(_ texts: String?..., source: String? = nil, hanOnlyOk: Bool = true) -> String {
        for t in texts {
            let v = (t ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty, !looksWrong(v, reader: L10n.lang, source: source, hanOnlyOk: hanOnlyOk) { return v }
        }
        return ""
    }

    // MARK: - Explanation rows (word_explanations)

    nonisolated struct Explanation: Decodable, Sendable, Hashable {
        let explainLang: String
        let l1: String
        let meaning: String
        let exampleTranslation: String?
        let extras: WordExtras?
        let source: String?

        enum CodingKeys: String, CodingKey {
            case l1, meaning, extras, source
            case explainLang = "explain_lang"
            case exampleTranslation = "example_translation"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            explainLang = (try? c.decode(String.self, forKey: .explainLang)) ?? ""
            l1 = (try? c.decode(String.self, forKey: .l1)) ?? ""
            meaning = (try? c.decode(String.self, forKey: .meaning)) ?? ""
            exampleTranslation = try? c.decodeIfPresent(String.self, forKey: .exampleTranslation)
            extras = try? c.decodeIfPresent(WordExtras.self, forKey: .extras)
            source = try? c.decodeIfPresent(String.self, forKey: .source)
        }

        /// web `hasExtrasContent`: anything beyond the language marks.
        var hasContent: Bool {
            guard let e = extras else { return false }
            return !(e.usageChunks ?? []).isEmpty || !(e.examplesExtra ?? []).isEmpty || !(e.measureWords ?? []).isEmpty
                || !(e.relatedWords ?? []).isEmpty || !(e.synonyms ?? []).isEmpty || !(e.antonyms ?? []).isEmpty
                || [e.mnemonic, e.taiwanNote, e.pronunciationTips, e.studyTips, e.etymology, e.radicals, e.trivia,
                    e.usageNote, e.synonymDiff, e.usageContext].contains { !($0 ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
        }
    }

    /// web `needsGeneration`: there is no explanation for exactly this reader yet (or it is empty).
    static func needsGeneration(_ picked: Explanation?, lang: String, l1: String) -> Bool {
        guard let p = picked else { return true }
        if p.explainLang != lang || p.l1 != l1 { return true }
        if p.meaning.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        return !p.hasContent
    }

    // MARK: - resolveDisplayWord (word-explanation.ts) + scrubForReader

    /// The word as this reader should see it: their explanation when there is one; the shared row
    /// only where it is written in their language; nothing (rather than another language) otherwise.
    static func resolve(_ shared: Word, explanation: Explanation?, readerMeaning: String?, reader: String) -> Word {
        var w = shared
        let meanings = [explanation?.meaning, readerMeaning, shared.meaningJa].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        w.meaningJa = meanings.first { !$0.isEmpty && !looksWrong($0, reader: reader, hanOnlyOk: true) } ?? ""
        let translations = [explanation?.exampleTranslation, shared.exampleTranslation].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        w.exampleTranslation = translations.first { !$0.isEmpty && !looksWrong($0, reader: reader, source: shared.exampleSentence) }
        // A row for this reader wins even when still empty (it is being filled in the background).
        var extras = explanation != nil ? explanation?.extras : shared.extras
        if let mark = extras?.explainLang?.trimmingCharacters(in: .whitespaces), !mark.isEmpty, mark != reader { extras = nil }
        w.extras = extras.map { scrub($0, reader: reader) }
        return w
    }

    /// Drop single translations and notes that came back in another language (web `scrubForReader`
    /// and `scrubForeignNotes`) — never rewritten, only emptied.
    static func scrub(_ e: WordExtras, reader: String) -> WordExtras {
        var e = e
        e.examplesExtra = e.examplesExtra?.map { x in
            var x = x
            if looksWrong(x.ja, reader: reader, source: x.zh) { x.ja = "" }
            if looksWrong(x.scene, reader: reader, hanOnlyOk: true) { x.scene = "" }
            return x
        }
        e.usageChunks = e.usageChunks?.map { c in
            var c = c
            if looksWrong(c.ja, reader: reader, hanOnlyOk: true) { c.ja = "" }
            return c
        }
        e.measureWords = e.measureWords?.map { m in
            var m = m
            if looksWrong(m.note, reader: reader, hanOnlyOk: true) { m.note = "" }
            return m
        }
        e.relatedWords = e.relatedWords?.map { r in
            var r = r
            if looksWrong(r.note, reader: reader, hanOnlyOk: true) { r.note = "" }
            return r
        }
        let notes: [WritableKeyPath<WordExtras, String?>] = [\.mnemonic, \.taiwanNote, \.pronunciationTips, \.studyTips,
                                                              \.etymology, \.trivia, \.usageNote, \.synonymDiff, \.usageContext, \.radicals]
        for kp in notes where looksWrong(e[keyPath: kp], reader: reader) {
            e[keyPath: kp] = nil
        }
        return e
    }
}
