import Foundation
import Observation
import SwiftUI

/// Sections of the word card for Taiwan Mandarin (target-profile.ts `sections`, minus web_images).
nonisolated enum CardSection: String, CaseIterable, Codable, Identifiable, Sendable {
    case meaning
    case example
    case examplesExtra = "examples_extra"
    case usageChunks = "usage_chunks"
    case measureWords = "measure_words"
    case relatedWords = "related_words"
    case pronunciationTips = "pronunciation_tips"
    case etymology
    case mnemonic
    case taiwanNote = "taiwan_note"
    case realUsage = "real_usage"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meaning: "意味"
        case .example: "例文"
        case .examplesExtra: "追加の例文"
        case .usageChunks: "使い方チャンク"
        case .measureWords: "量詞"
        case .relatedWords: "類義語・反義語・関連語"
        case .pronunciationTips: "発音のコツ"
        case .etymology: "語源・部首"
        case .mnemonic: "覚え方"
        case .taiwanNote: "台湾メモ"
        case .realUsage: "実際の使われ方"
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
        case .relatedWords: "point.3.connected.trianglepath.dotted"
        case .pronunciationTips: "waveform"
        case .etymology: "building.columns"
        case .mnemonic: "lightbulb"
        case .taiwanNote: "mappin"
        case .realUsage: "film"
        }
    }

    /// card-prefs.ts DEFAULT_VISIBLE (2026-09-23).
    static let defaultVisible: [CardSection] = [.meaning, .example, .usageChunks, .measureWords, .relatedWords, .realUsage]

    static var defaultOrder: [CardSection] {
        defaultVisible + allCases.filter { !defaultVisible.contains($0) }
    }
}

/// Per-device order + hidden set for the word card (card-prefs.ts).
@Observable
final class CardPrefsStore {
    static let shared = CardPrefsStore()

    private(set) var order: [CardSection]
    private(set) var hidden: Set<CardSection>
    private let key = "wordcard-prefs-v6"

    private nonisolated struct Stored: Codable {
        var order: [String]
        var hidden: [String]
    }

    init() {
        order = CardSection.defaultOrder
        hidden = Set(CardSection.allCases.filter { !CardSection.defaultVisible.contains($0) })
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        let known = s.order.compactMap(CardSection.init(rawValue:))
        order = known + CardSection.defaultOrder.filter { !known.contains($0) }
        hidden = Set(s.hidden.compactMap(CardSection.init(rawValue:)))
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
        order = CardSection.defaultOrder
        hidden = Set(CardSection.allCases.filter { !CardSection.defaultVisible.contains($0) })
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
