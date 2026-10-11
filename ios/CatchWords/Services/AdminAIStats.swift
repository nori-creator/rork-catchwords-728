import Foundation

// MARK: - The developer "speed and accuracy by model" answers (web src/lib/ai-model-stats.ts,
// docs/admin-ai-api.md › adminGetAiStats / adminGetAiTestPhotos / adminTestPhotoCandidates).
// Every field is optional on the wire: a missing or odd value reads as empty, never as a failed decode.

/// `adminGetAiStats` → `result`. Counts only — never whose rows, never a photo or a word.
nonisolated struct AdminAiStats: Decodable, Sendable {
    var isAdmin: Bool
    var truncated: Bool
    var days: Int
    var tasks: [AdminAiTaskStats]
    var tests: [AdminAiTestStat]

    enum CodingKeys: String, CodingKey { case isAdmin, truncated, days, tasks, tests }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isAdmin = c.statBool(.isAdmin)
        truncated = c.statBool(.truncated)
        days = Int(c.statNum(.days) ?? 7)
        tasks = c.statList(AdminAiTaskStats.self, .tasks)
        tests = c.statList(AdminAiTestStat.self, .tests)
    }
}

/// One use of the AI (`photo_candidates`, `card`, …) inside a feature (`scan`, `card`, …).
nonisolated struct AdminAiTaskStats: Decodable, Sendable {
    var task: String
    var feature: String?
    var models: [AdminAiModelStat]

    enum CodingKeys: String, CodingKey { case task, feature, models }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        task = c.statStr(.task)
        feature = c.statOptStr(.feature)
        models = c.statList(AdminAiModelStat.self, .models)
    }
}

/// One model's numbers for one task. Times are milliseconds; `nil` where nothing was measured.
nonisolated struct AdminAiModelStat: Decodable, Sendable {
    var model: String
    var calls: Int
    var timeouts: Int
    var failed: Int
    var cancelled: Int
    var okPct: Double?
    var p50: Double?
    var p90: Double?
    var avgIn: Double?
    var avgOut: Double?
    var costUsd: Double?
    var unusable: AdminAiRate?
    var picks: AdminAiPicks?

    enum CodingKeys: String, CodingKey {
        case model, calls, timeouts, failed, cancelled, okPct, p50, p90, avgIn, avgOut, costUsd, unusable, picks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        model = c.statStr(.model)
        calls = Int(c.statNum(.calls) ?? 0)
        timeouts = Int(c.statNum(.timeouts) ?? 0)
        failed = Int(c.statNum(.failed) ?? 0)
        cancelled = Int(c.statNum(.cancelled) ?? 0)
        okPct = c.statNum(.okPct)
        p50 = c.statNum(.p50)
        p90 = c.statNum(.p90)
        avgIn = c.statNum(.avgIn)
        avgOut = c.statNum(.avgOut)
        costUsd = c.statNum(.costUsd)
        unusable = (try? c.decodeIfPresent(AdminAiRate.self, forKey: .unusable)) ?? nil
        picks = (try? c.decodeIfPresent(AdminAiPicks.self, forKey: .picks)) ?? nil
    }
}

/// Replies that came back in a shape the app could not use (`n` of `of`).
nonisolated struct AdminAiRate: Decodable, Sendable {
    var n: Int
    var of: Int
    var pct: Double?

    enum CodingKeys: String, CodingKey { case n, of, pct }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        n = Int(c.statNum(.n) ?? 0)
        of = Int(c.statNum(.of) ?? 0)
        pct = c.statNum(.pct)
    }
}

/// Which candidate people picked after this model answered (Top-1 / Top-3, as on /admin/beta).
nonisolated struct AdminAiPicks: Decodable, Sendable {
    var n: Int
    var top1Pct: Double?
    var top3Pct: Double?

    enum CodingKeys: String, CodingKey { case n, top1Pct, top3Pct }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        n = Int(c.statNum(.n) ?? 0)
        top1Pct = c.statNum(.top1Pct)
        top3Pct = c.statNum(.top3Pct)
    }
}

/// One model's fixed-photo test results (all its runs in the period).
nonisolated struct AdminAiTestStat: Decodable, Sendable {
    var task: String
    var model: String
    /// `thinking-off`: measured with Claude told not to think (nil: the live way of calling).
    var variant: String?
    /// The learning language the photos were tested in (`zh-TW` / `en` / `ja`; each its own row). nil = older rows.
    var lang: String?
    var n: Int
    /// Photos that got no answer (timeouts, the provider's errors): misses in the rates, left out of the times.
    var failed: Int
    var top1Pct: Double?
    var top3Pct: Double?
    /// The times of the photos that got an answer.
    var p50: Double?
    var p90: Double?
    var costUsd: Double?

    enum CodingKeys: String, CodingKey { case task, model, variant, lang, n, failed, top1Pct, top3Pct, p50, p90, costUsd }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        task = c.statStr(.task)
        model = c.statStr(.model)
        variant = c.statOptStr(.variant)
        lang = c.statOptStr(.lang)
        n = Int(c.statNum(.n) ?? 0)
        failed = Int(c.statNum(.failed) ?? 0)
        top1Pct = c.statNum(.top1Pct)
        top3Pct = c.statNum(.top3Pct)
        p50 = c.statNum(.p50)
        p90 = c.statNum(.p90)
        costUsd = c.statNum(.costUsd)
    }
}

/// `adminGetAiTestPhotos` → `result`: the labelled photos (the answers stay on the server).
nonisolated struct AdminAiTestPhotos: Decodable, Sendable {
    var isAdmin: Bool
    var languages: [String]
    var photos: [AdminAiTestPhoto]

    enum CodingKeys: String, CodingKey { case isAdmin, languages, photos }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isAdmin = c.statBool(.isAdmin)
        languages = ((try? c.decodeIfPresent([String].self, forKey: .languages)) ?? nil) ?? []
        photos = c.statList(AdminAiTestPhoto.self, .photos)
    }
}

nonisolated struct AdminAiTestPhoto: Decodable, Sendable {
    var id: String
    /// Under the web app's address (`/ai-test/photos/cafe.jpg`).
    var path: String

    enum CodingKeys: String, CodingKey { case id, path }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.statStr(.id)
        path = c.statStr(.path)
    }
}

/// `adminTestPhotoCandidates` → `result`: where the right answer ranked for one photo.
nonisolated struct AdminAiTestResult: Decodable, Sendable {
    var ok: Bool
    var ms: Double
    var model: String
    var rank: Int?
    var heads: [String]
    var want: String
    var code: String?

    enum CodingKeys: String, CodingKey { case ok, ms, model, rank, heads, want, code }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.statBool(.ok)
        ms = c.statNum(.ms) ?? 0
        model = c.statStr(.model)
        rank = c.statNum(.rank).map { Int($0) }
        heads = ((try? c.decodeIfPresent([String].self, forKey: .heads)) ?? nil) ?? []
        want = c.statStr(.want)
        code = c.statOptStr(.code)
    }
}

enum AdminAiTest {
    /// One labelled photo through the chosen model (`value`: "auto" or "provider:model"). The live setting is
    /// not changed; the server keeps the result for the stats.
    /// `thinkingOff`: Claude is told not to think (ignored for other providers) — Claude 5 thinks before it answers
    /// unless told otherwise, which is how the live app calls it now.
    static func run(photo: AdminAiTestPhoto, value: String, language: String,
                    thinkingOff: Bool) async throws -> AdminAiTestResult {
        let path = photo.path.hasPrefix("/") ? String(photo.path.dropFirst()) : photo.path
        let url = AppConfig.webBaseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else {
            throw APIError.message(L("写真を読み込めませんでした。"))
        }
        return try await NativeAPI.call("adminTestPhotoCandidates", [
            "value": value,
            "photo": photo.id,
            "targetLanguage": language,
            "thinking": thinkingOff ? "off" : "default",
            "imageBase64": "data:image/jpeg;base64,\(data.base64EncodedString())",
        ], as: AdminAiTestResult.self, timeout: 60)
    }

    /// The name of each use of the AI, as on the web (`aiStats.task.*`).
    static func taskName(_ id: String) -> String {
        switch id {
        case "photo_candidates": return L("撮った写真の候補")
        case "tutorial_candidates": return L("チュートリアルの写真の候補")
        case "word_candidates": return L("母語で調べた語の候補")
        case "scan_detect": return L("スキャンの物・文字の検出")
        case "scan_parts": return L("「+細かく」の部分の検出")
        case "image_sense": return L("語の絵の意味を決める")
        case "image_verify": return L("語の絵を確かめる")
        case "wordbook": return L("単語帳の読み取り")
        case "card": return L("単語カード（解説）")
        case "tutorial_card": return L("チュートリアルのカード")
        case "tutorial_lesson": return L("チュートリアルのレッスン")
        case "phrase_card": return L("フレーズカード")
        case "section_regen": return L("項目の作り直し")
        case "reader_meaning": return L("読む人の言語での意味")
        case "distractors": return L("4択の誤答の作り置き")
        case "journal_correct": return L("日記の添削")
        case "journal_prompts": return L("日記の書き出しの質問")
        case "report_locate": return L("報告された項目の特定")
        case "reading_check_1": return L("読みの突き合わせ（1人目）")
        case "correction_judge": return L("作り直しの判定")
        case "reading_check_2": return L("読みの突き合わせ（2人目）")
        case "lexicon_audit": return L("辞書の点検")
        case "lexicon_corpus": return L("生きた例文の生成")
        case "report_triage": return L("利用者の報告の検証")
        case "category_backfill": return L("棚の分類の付け直し")
        case "native_ai": return L("iOS の自由文の窓口")
        default: return id
        }
    }
}

/// Lenient fields (the same rule as AdminAI.swift).
private extension KeyedDecodingContainer {
    nonisolated func statStr(_ k: Key) -> String { ((try? decodeIfPresent(String.self, forKey: k)) ?? nil) ?? "" }
    nonisolated func statOptStr(_ k: Key) -> String? {
        let s = ((try? decodeIfPresent(String.self, forKey: k)) ?? nil) ?? ""
        return s.isEmpty ? nil : s
    }
    nonisolated func statBool(_ k: Key) -> Bool { ((try? decodeIfPresent(Bool.self, forKey: k)) ?? nil) ?? false }
    nonisolated func statNum(_ k: Key) -> Double? {
        let v = (try? decodeIfPresent(Double.self, forKey: k)) ?? nil
        guard let v, v.isFinite else { return nil }
        return v
    }
    nonisolated func statList<T: Decodable>(_ type: T.Type, _ k: Key) -> [T] {
        ((try? decodeIfPresent([T].self, forKey: k)) ?? nil) ?? []
    }
}
