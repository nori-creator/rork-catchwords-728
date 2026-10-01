import Foundation
import Observation
import SwiftUI

/// Sections of the word card (target-profile.ts `sections`, minus web_images). Which ones exist
/// depends on the learning language — measure words only in Mandarin, articles only in English,
/// kanji and keigo only in Japanese — so a card never shows a heading that is wrong for its language.
nonisolated enum CardSection: String, CaseIterable, Codable, Identifiable, Sendable {
    case meaning
    case example
    case examplesExtra = "examples_extra"
    case usageChunks = "usage_chunks"
    case measureWords = "measure_words"
    // English
    case forms
    case countability
    case phrasalVerbs = "phrasal_verbs"
    // Japanese
    case kanjiBreakdown = "kanji_breakdown"
    case conjugation
    case politeness
    case counters
    case relatedWords = "related_words"
    case stress
    case pitchAccent = "pitch_accent"
    case pronunciationTips = "pronunciation_tips"
    case wordOrigin = "word_origin"
    case etymology
    case mnemonic
    case taiwanNote = "taiwan_note"
    case cultureNote = "culture_note"
    case japanNote = "japan_note"
    case realUsage = "real_usage"

    var id: String { rawValue }

    /// The sections a card in `target` can have, in the web's order (target-profile.ts).
    static func sections(for target: String) -> [CardSection] {
        switch target {
        case "en":
            [.meaning, .example, .examplesExtra, .usageChunks, .forms, .countability, .phrasalVerbs, .relatedWords,
             .stress, .pronunciationTips, .etymology, .mnemonic, .cultureNote, .realUsage]
        case "ja":
            [.meaning, .example, .examplesExtra, .usageChunks, .kanjiBreakdown, .conjugation, .politeness, .counters,
             .relatedWords, .pitchAccent, .pronunciationTips, .wordOrigin, .etymology, .mnemonic, .japanNote, .realUsage]
        default:
            [.meaning, .example, .examplesExtra, .usageChunks, .measureWords, .relatedWords, .pronunciationTips,
             .etymology, .mnemonic, .taiwanNote, .realUsage]
        }
    }

    /// card-sections.ts sectionTitleKey: 「語源・部首」 only where the language has radicals.
    func title(for target: String) -> String {
        if self == .etymology, target != "zh-TW" { return L("語源") }
        return title
    }

    var title: String {
        switch self {
        case .meaning: L("意味")
        case .example: L("例文")
        case .examplesExtra: L("追加の例文")
        case .usageChunks: L("使い方チャンク")
        case .measureWords: L("量詞")
        case .forms: L("活用")
        case .countability: L("数え方と冠詞")
        case .phrasalVerbs: L("句動詞")
        case .kanjiBreakdown: L("漢字の内訳")
        case .conjugation: L("活用（動詞・形容詞）")
        case .politeness: L("丁寧さ・敬語")
        case .counters: L("助数詞")
        case .relatedWords: L("類義語・反義語・関連語")
        case .stress: L("強く読む所")
        case .pitchAccent: L("高低アクセント")
        case .pronunciationTips: L("発音のコツ")
        case .wordOrigin: L("語種")
        case .etymology: L("語源・部首")
        case .mnemonic: L("覚え方")
        case .taiwanNote: L("台湾メモ")
        case .cultureNote: L("文化の一言")
        case .japanNote: L("日本メモ")
        case .realUsage: L("実際の使われ方")
        }
    }

    /// section-icon.ts, one distinct glyph per section.
    var icon: String {
        switch self {
        case .meaning: "book"
        case .example: "text.quote"
        case .examplesExtra: "text.badge.plus"
        case .usageChunks: "square.grid.2x2"
        case .measureWords: "number"
        case .forms: "arrow.triangle.branch"
        case .countability: "a.circle"
        case .phrasalVerbs: "arrow.up.right"
        case .kanjiBreakdown: "character.ja"
        case .conjugation: "arrow.triangle.branch"
        case .politeness: "hands.sparkles"
        case .counters: "number"
        case .relatedWords: "point.3.connected.trianglepath.dotted"
        case .stress: "speaker.wave.3"
        case .pitchAccent: "waveform.path"
        case .pronunciationTips: "waveform"
        case .wordOrigin: "tag"
        case .etymology: "building.columns"
        case .mnemonic: "lightbulb"
        case .taiwanNote, .cultureNote, .japanNote: "mappin"
        case .realUsage: "film"
        }
    }

    /// card-prefs.ts DEFAULT_VISIBLE (2026-09-23), within the language's sections.
    static let defaultVisibleAll: [CardSection] = [.meaning, .example, .usageChunks, .measureWords, .relatedWords, .realUsage]

    static func defaultVisible(for target: String) -> [CardSection] {
        let all = sections(for: target)
        return defaultVisibleAll.filter { all.contains($0) }
    }

    static func defaultOrder(for target: String) -> [CardSection] {
        let shown = defaultVisible(for: target)
        return shown + sections(for: target).filter { !shown.contains($0) }
    }
}

/// Per-device order + hidden set for the word card (card-prefs.ts), kept per learning language so a
/// Mandarin card's choices never hide or show sections on an English or Japanese card.
@Observable
final class CardPrefsStore {
    static let shared = CardPrefsStore()

    private(set) var order: [CardSection] = []
    private(set) var hidden: Set<CardSection> = []
    private(set) var target: String = ""

    private nonisolated struct Stored: Codable {
        var order: [String]
        var hidden: [String]
    }

    /// v6 for Taiwan Mandarin (what the app always used), its own key for the other languages.
    private var key: String { target == "zh-TW" ? "wordcard-prefs-v6" : "wordcard-prefs-v6-\(target)" }

    init() { use(NativeAPI.targetLanguage) }

    /// Switches to the sections of `target` (called whenever the card's language is known).
    func use(_ target: String) {
        guard target != self.target else { return }
        self.target = target
        let all = CardSection.sections(for: target)
        order = CardSection.defaultOrder(for: target)
        hidden = Set(all.filter { !CardSection.defaultVisible(for: target).contains($0) })
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        let known = s.order.compactMap(CardSection.init(rawValue:)).filter { all.contains($0) }
        order = known + CardSection.defaultOrder(for: target).filter { !known.contains($0) }
        hidden = Set(s.hidden.compactMap(CardSection.init(rawValue:)).filter { all.contains($0) })
    }

    var visible: [CardSection] { order.filter { !hidden.contains($0) } }

    func isVisible(_ s: CardSection) -> Bool { !hidden.contains(s) }

    func setVisible(_ s: CardSection, _ on: Bool) {
        if on { hidden.remove(s) } else { hidden.insert(s) }
        save()
    }

    func move(from: IndexSet, to: Int) {
        order.move(fromOffsets: from, toOffset: to)
        save()
    }

    func reset() {
        order = CardSection.defaultOrder(for: target)
        hidden = Set(CardSection.sections(for: target).filter { !CardSection.defaultVisible(for: target).contains($0) })
        save()
    }

    private func save() {
        let s = Stored(order: order.map(\.rawValue), hidden: hidden.map(\.rawValue))
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key) }
    }
}

extension String {
    /// Contains at least one Han character — the "is this Chinese" gate (looksLikeTargetLanguage / isTargetHeadword).
    nonisolated var hasHan: Bool {
        unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value) || (0xF900...0xFAFF).contains($0.value) }
    }

    /// Written in the learning language at all (an example sentence, a wordbook headword): Han for
    /// Taiwan Mandarin, kana or kanji for Japanese, Latin letters for English.
    nonisolated func isIn(target: String) -> Bool { LanguageRules.isIn(self, target: target) }

    /// headwordCore: bracketed notes and surrounding punctuation don't count toward the judgement.
    nonisolated private var headwordCore: String {
        replacingOccurrences(of: "[（(【〔\\[][^）)】〕\\]]*[）)】〕\\]]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    /// target-language.ts isZhHeadword: Han only — kana, Latin, Hangul or Cyrillic anywhere drops it (「シャーペン」, 「pencil」).
    nonisolated var isZhHeadword: Bool {
        let core = headwordCore
        guard core.hasHan else { return false }
        return !core.unicodeScalars.contains { s in
            let v = s.value
            return (0x3040...0x30FF).contains(v) || (0x31F0...0x31FF).contains(v) || (0xFF66...0xFF9F).contains(v)
                || (0x41...0x5A).contains(v) || (0x61...0x7A).contains(v) || (0xC0...0x24F).contains(v)
                || (0xFF21...0xFF3A).contains(v) || (0xFF41...0xFF5A).contains(v)
                || (0xAC00...0xD7AF).contains(v) || (0x1100...0x11FF).contains(v) || (0x0400...0x04FF).contains(v)
        }
    }

    /// coerceTargetHeadword: fix once before discarding — keep the longest leading part that passes
    /// (「烤肉 (BBQ)」→「烤肉」). Returns nil when nothing passes; never lets the native language through.
    nonisolated var coercedZhHeadword: String? {
        let text = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.isZhHeadword { return text }
        var best: String?
        var prefix = ""
        for ch in text {
            prefix.append(ch)
            let head = prefix.trimmingCharacters(in: .whitespaces)
            if !head.isEmpty, head.isZhHeadword { best = head }
        }
        guard let best else { return nil }
        let trimmed = best.replacingOccurrences(of: "[\\s，、。．・…！？!?,.:;：；「」『』（）()【】〔〕\\[\\]{}\"'’”—–~〜-]+$", with: "", options: .regularExpression)
        return !trimmed.isEmpty && trimmed.isZhHeadword ? trimmed : best
    }
}
