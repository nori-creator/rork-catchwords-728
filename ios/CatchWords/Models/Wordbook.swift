import Foundation

/// One word read off a wordbook page (not saved yet).
nonisolated struct WordbookEntryDraft: Codable, Sendable, Hashable, Identifiable {
    var headword: String
    var readingZhuyin: String?
    var pinyin: String?
    var meaningJa: String?

    var id: String { headword }

    enum CodingKeys: String, CodingKey {
        case headword, pinyin
        case readingZhuyin = "reading_zhuyin"
        case meaningJa = "meaning_ja"
    }

    init(headword: String, readingZhuyin: String?, pinyin: String?, meaningJa: String?) {
        self.headword = headword
        self.readingZhuyin = readingZhuyin
        self.pinyin = pinyin
        self.meaningJa = meaningJa
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        headword = (try? c.decode(String.self, forKey: .headword)) ?? ""
        readingZhuyin = (try? c.decodeIfPresent(String.self, forKey: .readingZhuyin)).flatMap { $0 }
        pinyin = (try? c.decodeIfPresent(String.self, forKey: .pinyin)).flatMap { $0 }
        meaningJa = (try? c.decodeIfPresent(String.self, forKey: .meaningJa)).flatMap { $0 }
    }
}

nonisolated struct WordbookDraft: Codable, Sendable {
    var title: String
    var entries: [WordbookEntryDraft]

    init(title: String, entries: [WordbookEntryDraft]) {
        self.title = title
        self.entries = entries
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        entries = (try? c.decode([WordbookEntryDraft].self, forKey: .entries)) ?? []
    }
}

/// `wordbooks` row + progress (wordbookProgress).
nonisolated struct WordbookSummary: Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let createdAt: Date
    let total: Int
    let due: Int
    let learned: Int
}

/// `wordbook_entries` row.
nonisolated struct WordbookEntry: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let wordbookId: String
    let headword: String
    let readingZhuyin: String?
    let pinyin: String?
    let meaningJa: String?
    let ease: Double
    let intervalDays: Int
    let repetitions: Int
    let dueAt: Date?
    let lastReviewedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, headword, pinyin, ease, repetitions
        case wordbookId = "wordbook_id"
        case readingZhuyin = "reading_zhuyin"
        case meaningJa = "meaning_ja"
        case intervalDays = "interval_days"
        case dueAt = "due_at"
        case lastReviewedAt = "last_reviewed_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        wordbookId = (try? c.decode(String.self, forKey: .wordbookId)) ?? ""
        headword = (try? c.decode(String.self, forKey: .headword)) ?? ""
        readingZhuyin = (try? c.decodeIfPresent(String.self, forKey: .readingZhuyin)).flatMap { $0 }
        pinyin = (try? c.decodeIfPresent(String.self, forKey: .pinyin)).flatMap { $0 }
        meaningJa = (try? c.decodeIfPresent(String.self, forKey: .meaningJa)).flatMap { $0 }
        if let d = try? c.decode(Double.self, forKey: .ease) { ease = d }
        else if let s = try? c.decode(String.self, forKey: .ease), let d = Double(s) { ease = d }
        else { ease = 2.5 }
        intervalDays = (try? c.decode(Int.self, forKey: .intervalDays)) ?? 0
        repetitions = (try? c.decode(Int.self, forKey: .repetitions)) ?? 0
        dueAt = (try? c.decodeIfPresent(Date.self, forKey: .dueAt)).flatMap { $0 }
        lastReviewedAt = (try? c.decodeIfPresent(Date.self, forKey: .lastReviewedAt)).flatMap { $0 }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(headword, forKey: .headword)
    }

    var isDue: Bool { (dueAt ?? .distantPast) <= Date() }
}

/// wordbook.ts pure helpers.
nonisolated enum Wordbook {
    static let maxEntriesPerPhoto = 60
    static let maxTitleChars = 40

    private static func squash(_ s: String?) -> String {
        (s ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func clean(_ s: String?) -> String? {
        let v = squash(s)
        return v.isEmpty ? nil : v
    }

    /// cleanWordbookEntries: drop non-Han rows, merge duplicates filling blanks, cap.
    static func clean(_ raw: [WordbookEntryDraft], max: Int = maxEntriesPerPhoto) -> [WordbookEntryDraft] {
        var order: [String] = []
        var byHead: [String: WordbookEntryDraft] = [:]
        for r in raw {
            let head = squash(r.headword)
            guard !head.isEmpty, head.hasHan else { continue }
            if var existing = byHead[head] {
                existing.readingZhuyin = existing.readingZhuyin ?? clean(r.readingZhuyin)
                existing.pinyin = existing.pinyin ?? clean(r.pinyin)
                existing.meaningJa = existing.meaningJa ?? clean(r.meaningJa)
                byHead[head] = existing
                continue
            }
            if order.count >= max { continue }
            order.append(head)
            byHead[head] = WordbookEntryDraft(headword: head, readingZhuyin: clean(r.readingZhuyin), pinyin: clean(r.pinyin), meaningJa: clean(r.meaningJa))
        }
        return order.compactMap { byHead[$0] }
    }

    /// wordbookTitle: suggested → today's date → "単語帳", capped.
    static func title(_ suggested: String?, fallback: String) -> String {
        let s = squash(suggested)
        let base = !s.isEmpty ? s : (!squash(fallback).isEmpty ? squash(fallback) : L("単語帳"))
        return String(base.prefix(maxTitleChars))
    }
}
