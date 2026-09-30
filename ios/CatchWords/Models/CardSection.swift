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
}
