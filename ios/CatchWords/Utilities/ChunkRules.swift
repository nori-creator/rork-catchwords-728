import Foundation

// The usage-chunk shapes and the rules that decide how a chunk is shown (docs/chunk-rules.md).
// Kept free of UI so the swiftc rules harness (ios/LanguageRules) can test every rule.

/// extras.usage_chunks entry (extras.ts UsageChunkSchema): a formula like 跟＋男朋友＋吵架 and its translation.
nonisolated struct UsageChunk: Codable, Sendable, Hashable {
    var parts: [ChunkPart]
    var ja: String

    init(parts: [ChunkPart], ja: String) {
        self.parts = parts
        self.ja = ja
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        parts = (try? c.decode([ChunkPart].self, forKey: .parts)) ?? []
        ja = (try? c.decode(String.self, forKey: .ja)) ?? ""
    }

    var text: String { parts.map(\.text).joined() }
}

/// Another word natives often put in a swappable part, with its meaning in the reader's language.
nonisolated struct ChunkAlt: Codable, Sendable, Hashable {
    var text: String
    var ja: String

    init(text: String, ja: String) {
        self.text = text
        self.ja = ja
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        ja = (try? c.decode(String.self, forKey: .ja)) ?? ""
    }
}

/// One block of a chunk (extras.ts ChunkPartSchema).
nonisolated struct ChunkPart: Codable, Sendable, Hashable {
    var text: String
    var pos: String
    /// A part natives swap (the 男朋友 of 跟＋男朋友＋吵架).
    var slot: Bool?
    /// This word's meaning, written as it appears in the chunk's translation (彼氏 in 「彼氏と喧嘩する」).
    var ja: String?
    /// Other words natives often put here, most frequent first.
    var alts: [ChunkAlt]?

    init(text: String, pos: String, slot: Bool? = nil, ja: String? = nil, alts: [ChunkAlt]? = nil) {
        self.text = text
        self.pos = pos
        self.slot = slot
        self.ja = ja
        self.alts = alts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        pos = (try? c.decode(String.self, forKey: .pos)) ?? ""
        slot = try? c.decodeIfPresent(Bool.self, forKey: .slot)
        ja = try? c.decodeIfPresent(String.self, forKey: .ja)
        alts = (try? c.decodeIfPresent([ChunkAlt].self, forKey: .alts))?.filter { !$0.text.isEmpty }
    }
}

nonisolated enum ChunkRules {
    // MARK: - Part kinds

    static func isNoun(_ p: ChunkPart) -> Bool {
        let u = p.pos.uppercased()
        // pos.ts: N…, and the old role marks S (subject) and O (object), which are noun phrases.
        return u.hasPrefix("N") || u == "S" || u == "O" || p.pos.contains("名詞")  // l10n-ignore (matching server POS)
    }

    static func isMeasure(_ p: ChunkPart) -> Bool {
        let u = p.pos.uppercased()
        return u.hasPrefix("M") || p.pos.contains("量詞")  // l10n-ignore (matching server POS)
    }

    static func isAdverb(_ p: ChunkPart) -> Bool {
        let u = p.pos.uppercased()
        return u.hasPrefix("ADV") || p.pos.contains("副詞")  // l10n-ignore (matching server POS)
    }

    /// A predicate adjective (Mandarin stative verb). Attributive-only Vs-attr and object-taking Vst are not.
    static func isPredicateStative(_ p: ChunkPart) -> Bool {
        let u = p.pos.uppercased()
        if u == "VS-ATTR" || u == "VST" { return false }
        return u.hasPrefix("VS")
    }

    // MARK: - C8 Degree words (很・有點・超…)

    /// Words that stand before a Mandarin adjective to say how much (chunk-grammar.ts DEGREE).
    static let degreeWords = ["很", "好", "超", "太", "真", "非常", "蠻", "滿", "挺", "比較", "更", "最", "有點", "有一點", "不", "沒", "還", "特別", "相當", "越來越", "這麼", "那麼", "多"]  // l10n-ignore (Mandarin words)

    /// The degree words offered in the wheel, most used first (C5): 很 → 超・非常・有點・蠻.
    /// Negations (不・不太) are left out: 「とても甘い」 cannot become 「甘くない」 by swapping one word.
    static let degreeChoices = ["很", "超", "非常", "有點", "蠻"]  // l10n-ignore (Mandarin words)

    /// What each degree word means, in the reader's language (as it would read in the chunk's translation).
    static func degreeGloss(_ word: String, reader: String) -> String {
        let table: [String: (ja: String, en: String)] = [  // l10n-ignore (glosses per reader language)
            "很": ("とても", "very"), "超": ("すごく", "super"), "非常": ("非常に", "extremely"),  // l10n-ignore
            "有點": ("ちょっと", "a little"), "蠻": ("わりと", "pretty"), "好": ("すごく", "so"),  // l10n-ignore
        ]
        guard let g = table[word] else { return "" }
        switch reader {
        case "en": return g.en
        case "ja": return g.ja
        default: return word
        }
    }

    static func isDegree(_ p: ChunkPart) -> Bool { degreeChoices.contains(p.text.trimmingCharacters(in: .whitespaces)) }

    // MARK: - Tidy (applied to every chunk before it is drawn)

    /// Puts a chunk into the shape it is shown in (docs/chunk-rules.md). Running it twice changes nothing.
    /// - C7: a word natives use as one word (芒果冰) is one block, never 芒果＋冰.
    /// - C8: a Mandarin noun + adjective gets its degree word (滷味＋很＋入味).
    /// - C5: a degree word can be swapped (很 → 超・非常・有點・蠻).
    static func tidy(_ parts: [ChunkPart], headword: String, target: String, reader: String) -> [ChunkPart] {
        var out = parts.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard target.hasPrefix("zh") else { return out }
        out = mergeCompounds(out, headword: headword)
        out = withDegree(out)
        return out.map { p -> ChunkPart in
            guard isDegree(p), !LanguageRules.mentionsHeadword(p.text, headword: headword, target: target) else { return p }
            var q = p
            q.slot = true
            if (q.ja ?? "").isEmpty { q.ja = degreeGloss(p.text, reader: reader) }
            if (q.alts ?? []).isEmpty {
                q.alts = degreeChoices.filter { $0 != p.text }.map { ChunkAlt(text: $0, ja: degreeGloss($0, reader: reader)) }
            }
            return q
        }
    }

    /// C7: nouns side by side with the headword make one word in Mandarin (芒果＋冰 → 芒果冰, 台灣＋芒果 → 台灣芒果).
    static func mergeCompounds(_ parts: [ChunkPart], headword: String) -> [ChunkPart] {
        let core = LanguageRules.headwordCore(headword)
        guard !core.isEmpty else { return parts }
        var out: [ChunkPart] = []
        for p in parts {
            if let last = out.last, isNoun(last), isNoun(p),
               last.text.contains(core) || p.text.contains(core),
               (last.text + p.text).count <= 6 {
                out[out.count - 1] = ChunkPart(text: last.text + p.text, pos: last.pos)
            } else {
                out.append(p)
            }
        }
        return out
    }

    /// C8 (chunk-grammar.ts withDegreeAdverb): 「滷味入味」 is not what natives say; they say 「滷味很入味」.
    static func withDegree(_ parts: [ChunkPart]) -> [ChunkPart] {
        guard parts.count >= 2, let last = parts.last else { return parts }
        let prev = parts[parts.count - 2]
        guard isPredicateStative(last), isNoun(prev),
              !degreeWords.contains(where: { last.text.hasPrefix($0) }),
              !parts.contains(where: isAdverb) else { return parts }
        return Array(parts.dropLast()) + [ChunkPart(text: "很", pos: "Adv"), last]  // l10n-ignore (Mandarin word)
    }

    // MARK: - What is shown

    /// C7: one block is a word, not a way of using it (芒果冰 belongs with the related words).
    static func isPattern(_ parts: [ChunkPart]) -> Bool { parts.count >= 2 }

    /// C2 / C5 / C6: a part opens the wheel only when it is not the word being learned, is a concrete noun,
    /// a measure word or a degree word, and has other words to offer.
    static func isSwappable(_ p: ChunkPart, headword: String, target: String) -> Bool {
        guard p.slot == true else { return false }
        let alts = (p.alts ?? []).filter { !$0.text.isEmpty && $0.text != p.text }
        guard !alts.isEmpty else { return false }
        if !headword.isEmpty, LanguageRules.mentionsHeadword(p.text, headword: headword, target: target) { return false }
        if p.pos.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        return isNoun(p) || isMeasure(p) || (target.hasPrefix("zh") && isDegree(p))
    }

    /// The choices of a swappable part: the word itself first, then the others.
    static func choices(_ p: ChunkPart) -> [ChunkAlt] {
        [ChunkAlt(text: p.text, ja: p.ja ?? "")] + (p.alts ?? []).filter { !$0.text.isEmpty && $0.text != p.text }
    }

    /// The chunk read aloud: English words are spaced, Mandarin and Japanese are not.
    static func spoken(_ parts: [ChunkPart], target: String) -> String {
        parts.map { $0.text.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: target == "en" ? " " : "")
    }

    /// C12 (chunk-grammar.ts swappedTranslation): the translation with the swapped word's meaning put in place of
    /// the original's. When the original cannot be found, the translation stays and says what was swapped.
    static func swappedTranslation(_ translation: String, original: [ChunkPart], shown: [ChunkPart], reader: String) -> String {
        var out = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        var notes: [String] = []
        for (i, part) in original.enumerated() where i < shown.count && shown[i].text != part.text {
            let alt = choices(part).first { $0.text == shown[i].text }
            let to = (alt?.ja.isEmpty == false ? alt!.ja : shown[i].text)
            if let from = [part.ja ?? "", part.text].first(where: { !$0.isEmpty && out.contains($0) }),
               let r = out.range(of: from) {
                out.replaceSubrange(r, with: to)
            } else {
                notes.append("\(part.text) → \(shown[i].text)" + ((alt?.ja ?? "").isEmpty ? "" : ": \(alt!.ja)"))
            }
        }
        guard !notes.isEmpty else { return out }
        return reader == "en" ? "\(out) (\(notes.joined(separator: ", ")))"
            : reader == "ja" ? "\(out)（\(notes.joined(separator: "、"))）" : "\(out)（\(notes.joined(separator: "，"))）"
    }
}
