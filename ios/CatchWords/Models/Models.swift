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

    enum CodingKeys: String, CodingKey {
        case mnemonic
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

    enum CodingKeys: String, CodingKey {
        case id, caption, word
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

    enum CodingKeys: String, CodingKey {
        case kind, headword, zhuyin, pinyin, pos, point, confidence, alternatives
        case meaningJa = "meaning_ja"
    }

    init(kind: String, headword: String, zhuyin: String, pinyin: String, meaningJa: String,
         pos: String, point: [Double], confidence: Double, alternatives: [String]) {
        self.kind = kind
        self.headword = headword
        self.zhuyin = zhuyin
        self.pinyin = pinyin
        self.meaningJa = meaningJa
        self.pos = pos
        self.point = point
        self.confidence = confidence
        self.alternatives = alternatives
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
        zhuyin = (try? c.decode(String.self, forKey: .zhuyin)) ?? ""
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
    }
}

/// AI-generated card content for a picked candidate.
nonisolated struct CardDetails: Codable, Sendable {
    var categoryKey: String
    var level: String
    var exampleSentence: String
    var exampleTranslation: String
    var extras: WordExtras

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
    }
}
