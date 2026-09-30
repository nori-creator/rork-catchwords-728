import Foundation

nonisolated struct AuthSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userId: String
    let email: String?
}

/// Row of the shared `words` table (same schema as the web app).
nonisolated struct Word: Codable, Sendable, Hashable {
    let id: String
    let headword: String
    let readingZhuyin: String?
    let pinyin: String?
    let meaningJa: String
    let partOfSpeech: String?
    let categoryKey: String?
    let level: String?
    let exampleSentence: String?
    let exampleTranslation: String?
    let extras: WordExtras?

    enum CodingKeys: String, CodingKey {
        case id, headword, pinyin, level, extras
        case readingZhuyin = "reading_zhuyin"
        case meaningJa = "meaning_ja"
        case partOfSpeech = "part_of_speech"
        case categoryKey = "category_key"
        case exampleSentence = "example_sentence"
        case exampleTranslation = "example_translation"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        headword = try c.decode(String.self, forKey: .headword)
        readingZhuyin = try? c.decodeIfPresent(String.self, forKey: .readingZhuyin)
        pinyin = try? c.decodeIfPresent(String.self, forKey: .pinyin)
        meaningJa = (try? c.decodeIfPresent(String.self, forKey: .meaningJa)) ?? ""
        partOfSpeech = try? c.decodeIfPresent(String.self, forKey: .partOfSpeech)
        categoryKey = try? c.decodeIfPresent(String.self, forKey: .categoryKey)
        level = try? c.decodeIfPresent(String.self, forKey: .level)
        exampleSentence = try? c.decodeIfPresent(String.self, forKey: .exampleSentence)
        exampleTranslation = try? c.decodeIfPresent(String.self, forKey: .exampleTranslation)
        extras = try? c.decodeIfPresent(WordExtras.self, forKey: .extras)
    }
}

/// Subset of `words.extras` the native card draws. Every field is optional/lenient,
/// mirroring the web's `ExtrasSchema` with `.catch()` defaults.
nonisolated struct WordExtras: Codable, Sendable, Hashable {
    var frequencyLevel: Int?
    var registerScale: Int?
    var registerTag: String?
    var sceneWeights: [String: Double]?
    var usageChunks: [UsageChunk]?
    var usageContext: String?
    var mnemonic: String?
    var measureWords: [MeasureWord]?
    var relatedWords: [RelatedWord]?
    var synonyms: [String]?
    var antonyms: [String]?
    var taiwanNote: String?
    var examplesExtra: [ExampleExtra]?
    var pronunciationTips: String?
    var studyTips: String?
    var etymology: String?
    var radicals: String?
    var trivia: String?
    var usageNote: String?
    var synonymDiff: String?

    enum CodingKeys: String, CodingKey {
        case mnemonic, synonyms, antonyms, etymology, radicals, trivia
        case taiwanNote = "taiwan_note"
        case examplesExtra = "examples_extra"
        case pronunciationTips = "pronunciation_tips"
        case studyTips = "study_tips"
        case usageNote = "usage_note"
        case synonymDiff = "synonym_diff"
        case relatedWords = "related_words"
        case frequencyLevel = "frequency_level"
        case registerScale = "register_scale"
        case registerTag = "register_tag"
        case sceneWeights = "scene_weights"
        case usageChunks = "usage_chunks"
        case usageContext = "usage_context"
        case measureWords = "measure_words"
    }

    init(frequencyLevel: Int? = nil, registerScale: Int? = nil, registerTag: String? = nil,
         sceneWeights: [String: Double]? = nil, usageChunks: [UsageChunk]? = nil,
         usageContext: String? = nil, mnemonic: String? = nil, measureWords: [MeasureWord]? = nil) {
        self.frequencyLevel = frequencyLevel
        self.registerScale = registerScale
        self.registerTag = registerTag
        self.sceneWeights = sceneWeights
        self.usageChunks = usageChunks
        self.usageContext = usageContext
        self.mnemonic = mnemonic
        self.measureWords = measureWords
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        frequencyLevel = (try? c.decodeIfPresent(Int.self, forKey: .frequencyLevel)).flatMap { $0 }
        registerScale = (try? c.decodeIfPresent(Int.self, forKey: .registerScale)).flatMap { $0 }
        registerTag = (try? c.decodeIfPresent(String.self, forKey: .registerTag)).flatMap { $0 }
        sceneWeights = (try? c.decodeIfPresent([String: Double].self, forKey: .sceneWeights)).flatMap { $0 }
        usageChunks = (try? c.decodeIfPresent([UsageChunk].self, forKey: .usageChunks)).flatMap { $0 }
        usageContext = (try? c.decodeIfPresent(String.self, forKey: .usageContext)).flatMap { $0 }
        mnemonic = (try? c.decodeIfPresent(String.self, forKey: .mnemonic)).flatMap { $0 }
        measureWords = (try? c.decodeIfPresent([MeasureWord].self, forKey: .measureWords)).flatMap { $0 }
        relatedWords = (try? c.decodeIfPresent([RelatedWord].self, forKey: .relatedWords)).flatMap { $0 }
        synonyms = (try? c.decodeIfPresent([String].self, forKey: .synonyms)).flatMap { $0 }
        antonyms = (try? c.decodeIfPresent([String].self, forKey: .antonyms)).flatMap { $0 }
        taiwanNote = (try? c.decodeIfPresent(String.self, forKey: .taiwanNote)).flatMap { $0 }
        examplesExtra = (try? c.decodeIfPresent([ExampleExtra].self, forKey: .examplesExtra)).flatMap { $0 }
        pronunciationTips = (try? c.decodeIfPresent(String.self, forKey: .pronunciationTips)).flatMap { $0 }
        studyTips = (try? c.decodeIfPresent(String.self, forKey: .studyTips)).flatMap { $0 }
        etymology = (try? c.decodeIfPresent(String.self, forKey: .etymology)).flatMap { $0 }
        radicals = (try? c.decodeIfPresent(String.self, forKey: .radicals)).flatMap { $0 }
        trivia = (try? c.decodeIfPresent(String.self, forKey: .trivia)).flatMap { $0 }
        usageNote = (try? c.decodeIfPresent(String.self, forKey: .usageNote)).flatMap { $0 }
        synonymDiff = (try? c.decodeIfPresent(String.self, forKey: .synonymDiff)).flatMap { $0 }
    }

    /// related_words, falling back to the legacy synonyms/antonyms string lists (card-sections.ts).
    var allRelated: [RelatedWord] {
        if let r = relatedWords?.filter({ !$0.word.isEmpty }), !r.isEmpty { return r }
        return (synonyms ?? []).map { RelatedWord(word: $0, kind: "syn") } + (antonyms ?? []).map { RelatedWord(word: $0, kind: "ant") }
    }

    /// "Draw only what exists" — the web app's rule: a section without content has no header.
    var hasMeters: Bool { frequencyLevel != nil || resolvedRegister != nil }

    /// `register_scale` first, else map the legacy free-text tag (register-scale.ts).
    var resolvedRegister: Int? {
        if let registerScale { return max(-2, min(2, registerScale)) }
        guard let tag = registerTag, !tag.isEmpty else { return nil }
        if tag.contains("口語") && tag.contains("書面") { return 0 }
        if tag.contains("口語") { return -1 }
        if tag.contains("書面") { return 1 }
        return nil
    }
}

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

nonisolated struct ChunkPart: Codable, Sendable, Hashable {
    var text: String
    var pos: String
    var slot: Bool?

    init(text: String, pos: String, slot: Bool? = nil) {
        self.text = text
        self.pos = pos
        self.slot = slot
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        pos = (try? c.decode(String.self, forKey: .pos)) ?? ""
        slot = try? c.decodeIfPresent(Bool.self, forKey: .slot)
    }
}

/// extras.related_words entry (RelatedWordSchema): kind is syn / ant / rel.
nonisolated struct RelatedWord: Codable, Sendable, Hashable {
    var word: String
    var kind: String
    var note: String
    var reading: String

    init(word: String, kind: String, note: String = "", reading: String = "") {
        self.word = word
        self.kind = kind
        self.note = note
        self.reading = reading
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        word = (try? c.decode(String.self, forKey: .word)) ?? ""
        let k = (try? c.decode(String.self, forKey: .kind)) ?? "rel"
        kind = ["syn", "ant", "rel"].contains(k) ? k : "rel"
        note = (try? c.decode(String.self, forKey: .note)) ?? ""
        reading = (try? c.decode(String.self, forKey: .reading)) ?? ""
    }
}

/// `examples_extra` item: sentence + translation + when you'd say it.
nonisolated struct ExampleExtra: Codable, Sendable, Hashable {
    var zh: String
    var ja: String
    var scene: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        zh = (try? c.decode(String.self, forKey: .zh)) ?? ""
        ja = (try? c.decode(String.self, forKey: .ja)) ?? ""
        scene = (try? c.decode(String.self, forKey: .scene)) ?? ""
    }
}

nonisolated struct MeasureWord: Codable, Sendable, Hashable {
    var word: String
    var zhuyin: String?
    var note: String?
}

/// Row of `stickers` with the joined word.
nonisolated struct Sticker: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let wordId: String
    let objectImageUrl: String?
    let cutoutImageUrl: String?
    let selfieImageUrl: String?
    let caption: String?
    let locationName: String?
    let takenAt: Date
    let captureType: String?
    var word: Word?
    var lat: Double? = nil
    var lng: Double? = nil

    enum CodingKeys: String, CodingKey {
        case id, caption, word, lat, lng
        case wordId = "word_id"
        case objectImageUrl = "object_image_url"
        case cutoutImageUrl = "cutout_image_url"
        case selfieImageUrl = "selfie_image_url"
        case locationName = "location_name"
        case takenAt = "taken_at"
        case captureType = "capture_type"
    }

    /// One place decides which photo represents a sticker (photo-surface.ts): cutout, then original.
    var heroPath: String? { cutoutImageUrl ?? objectImageUrl }
    var room: Room { Category.room(for: word?.categoryKey) }
    var categoryKey: String { Category.key(for: word?.categoryKey) }
}

/// Row of `reviews` (SM-2 state) — read only here; the web app owns the schedule.
nonisolated struct ReviewState: Codable, Sendable, Hashable {
    var id: String?
    let stickerId: String
    var ease: Double
    var intervalDays: Int
    var repetitions: Int?
    var lastReviewedAt: Date?
    var dueAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, ease, repetitions
        case stickerId = "sticker_id"
        case intervalDays = "interval_days"
        case lastReviewedAt = "last_reviewed_at"
        case dueAt = "due_at"
    }
}

/// Row of `review_history` (forgetting-curve chart + review streak).
nonisolated struct ReviewHistoryRow: Codable, Sendable, Hashable {
    let reviewedAt: Date
    let score: Int?
    let intervalDaysAfter: Int?
    let easeAfter: Double?
    let stickerId: String?

    enum CodingKeys: String, CodingKey {
        case score
        case stickerId = "sticker_id"
        case reviewedAt = "reviewed_at"
        case intervalDaysAfter = "interval_days_after"
        case easeAfter = "ease_after"
    }

    /// Local row appended right after grading (so the overall line moves without a refetch).
    init?(stickerId: String, reviewedAt: Date, intervalDaysAfter: Int, easeAfter: Double) {
        self.stickerId = stickerId
        self.reviewedAt = reviewedAt
        self.intervalDaysAfter = intervalDaysAfter
        self.easeAfter = easeAfter
        self.score = nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reviewedAt = try c.decode(Date.self, forKey: .reviewedAt)
        score = try? c.decodeIfPresent(Int.self, forKey: .score)
        stickerId = (try? c.decodeIfPresent(String.self, forKey: .stickerId)).flatMap { $0 }
        intervalDaysAfter = try? c.decodeIfPresent(Int.self, forKey: .intervalDaysAfter)
        if let d = try? c.decodeIfPresent(Double.self, forKey: .easeAfter) {
            easeAfter = d
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .easeAfter) {
            easeAfter = Double(s)
        } else {
            easeAfter = nil
        }
    }
}

/// A candidate returned by AI detection (scan.functions.ts DetectItemSchema).
nonisolated struct Candidate: Codable, Sendable, Identifiable, Hashable {
    var id: String { headword + "\(point.first ?? 0)" }
    let kind: String
    let headword: String
    let zhuyin: String
    let pinyin: String
    let meaningJa: String
    let pos: String
    let point: [Double]
    let confidence: Double
    let alternatives: [String]
    /// Web `suggestWords` / `suggestWordCandidates`: how this name differs from the others (≤15 chars).
    var distinction: String = ""
    /// common / casual / specific / proper — "ほかの言い方" chips (candidate-order.ts).
    var register: String?
    /// Which object in the photo; other names of the same object share it.
    var group: Int?
    /// Shelf hint passed to `generateCard` as `hintCategory`.
    var categoryKey: String?

    enum CodingKeys: String, CodingKey {
        case kind, headword, zhuyin, pinyin, pos, point, confidence, alternatives
        case distinction, register, group
        case meaningJa = "meaning_ja"
        case readingZhuyin = "reading_zhuyin"
        case categoryKey = "category_key"
    }

    init(kind: String, headword: String, zhuyin: String, pinyin: String, meaningJa: String,
         pos: String, point: [Double], confidence: Double, alternatives: [String],
         distinction: String = "", register: String? = nil, group: Int? = nil, categoryKey: String? = nil) {
        self.kind = kind
        self.headword = headword
        self.zhuyin = zhuyin
        self.pinyin = pinyin
        self.meaningJa = meaningJa
        self.pos = pos
        self.point = point
        self.confidence = confidence
        self.alternatives = alternatives
        self.distinction = distinction
        self.register = register
        self.group = group
        self.categoryKey = categoryKey
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encode(headword, forKey: .headword)
        try c.encode(zhuyin, forKey: .zhuyin)
        try c.encode(pinyin, forKey: .pinyin)
        try c.encode(meaningJa, forKey: .meaningJa)
        try c.encode(pos, forKey: .pos)
        try c.encode(point, forKey: .point)
        try c.encode(confidence, forKey: .confidence)
        try c.encode(alternatives, forKey: .alternatives)
        try c.encode(distinction, forKey: .distinction)
        try c.encodeIfPresent(register, forKey: .register)
        try c.encodeIfPresent(group, forKey: .group)
        try c.encodeIfPresent(categoryKey, forKey: .categoryKey)
    }

    /// Lenient decode (scan-detect-parse.ts): nulls, percentages, strings all accepted.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let head = ((try? c.decode(String.self, forKey: .headword)) ?? "").trimmingCharacters(in: .whitespaces)
        guard !head.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .headword, in: c, debugDescription: "empty")
        }
        headword = head
        kind = ((try? c.decode(String.self, forKey: .kind)) ?? "object").lowercased() == "text" ? "text" : "object"
        zhuyin = (try? c.decode(String.self, forKey: .zhuyin))
            ?? (try? c.decode(String.self, forKey: .readingZhuyin)) ?? ""
        pinyin = (try? c.decode(String.self, forKey: .pinyin)) ?? ""
        meaningJa = (try? c.decode(String.self, forKey: .meaningJa)) ?? ""
        pos = (try? c.decode(String.self, forKey: .pos)) ?? "名詞"
        var p = (try? c.decode([Double].self, forKey: .point)) ?? [500, 500]
        if p.count < 2 { p = [500, 500] }
        if p[0] <= 1 && p[1] <= 1 { p = [p[0] * 1000, p[1] * 1000] }
        point = [max(0, min(1000, p[0])), max(0, min(1000, p[1]))]
        var conf = (try? c.decode(Double.self, forKey: .confidence)) ?? 0.8
        if conf > 1 { conf /= 100 }
        confidence = max(0, min(1, conf))
        alternatives = (try? c.decode([String].self, forKey: .alternatives)) ?? []
        distinction = ((try? c.decode(String.self, forKey: .distinction)) ?? "").trimmingCharacters(in: .whitespaces)
        register = try? c.decode(String.self, forKey: .register)
        group = try? c.decode(Int.self, forKey: .group)
        categoryKey = try? c.decode(String.self, forKey: .categoryKey)
    }
}

/// AI-generated card content for a picked candidate.
nonisolated struct CardDetails: Codable, Sendable {
    var categoryKey: String
    var level: String
    var exampleSentence: String
    var exampleTranslation: String
    var extras: WordExtras
    /// The whole card exactly as `generateCard` returned it. Saving sends this back
    /// (word fields, every extras key, new_shelf), so nothing the web generated is lost.
    var raw: JSONValue?

    enum CodingKeys: String, CodingKey {
        case level, extras
        case categoryKey = "category_key"
        case exampleSentence = "example_sentence"
        case exampleTranslation = "example_translation"
    }

    init(categoryKey: String, level: String, exampleSentence: String, exampleTranslation: String, extras: WordExtras) {
        self.categoryKey = categoryKey
        self.level = level
        self.exampleSentence = exampleSentence
        self.exampleTranslation = exampleTranslation
        self.extras = extras
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categoryKey = (try? c.decode(String.self, forKey: .categoryKey)) ?? "other"
        level = (try? c.decode(String.self, forKey: .level)) ?? "TOCFL-2"
        exampleSentence = (try? c.decode(String.self, forKey: .exampleSentence)) ?? ""
        exampleTranslation = (try? c.decode(String.self, forKey: .exampleTranslation)) ?? ""
        extras = (try? c.decode(WordExtras.self, forKey: .extras)) ?? WordExtras()
        raw = try? JSONValue(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        if let raw {
            try raw.encode(to: encoder)
            return
        }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(categoryKey, forKey: .categoryKey)
        try c.encode(level, forKey: .level)
        try c.encode(exampleSentence, forKey: .exampleSentence)
        try c.encode(exampleTranslation, forKey: .exampleTranslation)
        try c.encode(extras, forKey: .extras)
    }
}

/// Web `checkOwnedWord` → `OwnedWord` (encounters.functions.ts). A word already in the dex:
/// catching it again is a re-encounter ("再会！"), never a duplicate sticker.
nonisolated struct OwnedWord: Codable, Sendable, Hashable {
    let stickerId: String
    let wordId: String
    let headword: String
    let meaningJa: String
    let readingZhuyin: String?
    let pinyin: String?
    let cutoutUrl: String?
    let encounterCount: Int
    let takenAt: String
    let locationName: String?

    enum CodingKeys: String, CodingKey {
        case headword, pinyin
        case stickerId = "sticker_id"
        case wordId = "word_id"
        case meaningJa = "meaning_ja"
        case readingZhuyin = "reading_zhuyin"
        case cutoutUrl = "cutout_url"
        case encounterCount = "encounter_count"
        case takenAt = "taken_at"
        case locationName = "location_name"
    }

    var takenDate: Date? { SupabaseDate.parse(takenAt) }
}
