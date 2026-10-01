import Foundation
import UIKit

/// Vision detection + card generation through the web app's server (`/api/native-ai`).
/// The server holds the AI keys, picks the model (same switch point as the web) and applies
/// the same daily caps; the app only sends the prompt, an optional photo and the signed-in
/// user's Supabase token. No AI key ships inside the app.
/// Prompts are ported verbatim in intent from `scan.functions.ts` (Taiwan Mandarin, nouns only, 0–1000 points).
final class AIService {
    static let shared = AIService()

    /// What the server should use the call for (model choice + daily cap). Mirrors `NATIVE_AI_FEATURES`.
    enum Feature: String {
        case scan, card, wordbook, text
    }

    // l10n-ignore (prompt) — the next line opens an AI prompt (always Japanese; the server reads it)
    private static let detectPrompt = """
    あなたは台湾華語(zh-TW / 繁体字 / 注音)の学習アプリの検出エンジンです。
    入力画像から、学習価値のある「モノ (kind=object)」と「写っている文字 (kind=text)」を検出してください。

    厳守ルール:
    - 出力は下記スキーマに厳密に従うJSONオブジェクトのみ。前置き・後書き・コードフェンス禁止。
    - 台湾教育部準拠の正式な繁体字を使用。大陸簡体字・大陸独自語彙は禁止(例: 出租车✗ → 計程車○)。
    - 学習価値の低いもの(壁・空・地面など)は返さない。
    - kind=text は看板・メニュー・商品ラベルなど「写っている文字そのもの」。推測で足したり書き換えたりしない。
    - point は画像を 0〜1000 に正規化した座標 [x, y]。必ずその物体の見えている塊の重心に置く(左上が[0,0]、x=横、y=縦)。
    - 画像の端に見切れている物は学習対象にしない。同じ物は1つに統合する。
    - confidence は 0〜1。語の同定と座標の両方に自信がある時だけ 0.9 以上。曖昧なら alternatives に紛らわしい候補を1〜2個。
    - items は最大 6 個。数より正確さ。大きく写っている・学習価値の高いものを優先。
    - 各項目に zhuyin(注音)・pinyin・meaning_ja(日本語訳)・pos(日本語)を必ず埋める。
    - 名詞だけを返す。動詞・形容詞・副詞・量詞は出さない。

    出力スキーマ:
    {"items":[{"kind":"object","headword":"芒果","zhuyin":"ㄇㄤˊ ㄍㄨㄛˇ","pinyin":"mángguǒ","meaning_ja":"マンゴー","pos":"名詞","point":[512,340],"confidence":0.93,"alternatives":[]}]}
    """

    func detect(image: UIImage, textOnly: Bool = false) async throws -> [Candidate] {
        guard let jpeg = ImageTools.jpegForUpload(image) else { throw APIError.message(L("写真を読み込めませんでした。")) }
        let prompt = textOnly
            ? Self.detectPrompt + "\n今回はスキャンです。kind=text(写っている文字そのもの)だけを返し、名詞以外の語も写っていれば返してよい。"  // l10n-ignore (prompt)
            : Self.detectPrompt
        let text = try await complete(.scan, prompt: prompt, jpeg: jpeg, timeout: 40)
        let items = try Self.parseItems(text)
        guard !items.isEmpty else { throw APIError.message(L("写真から言葉を見つけられませんでした。明るい所で、撮りたい物に近づいて撮り直してください。")) }
        return items
    }

    // MARK: - Web server functions (the Lovable-decided behaviour)

    private struct Suggestions: Decodable { let suggestions: [Candidate] }
    private struct WordCandidates: Decodable { let candidates: [Candidate] }

    /// Photo → candidates, exactly like the web capture (`suggestWords`, capture.tsx runAi):
    /// 768px / q0.8, one entry per object (`group`) plus its other names (`register`),
    /// in the server's order (most likely first, everyday name first). Never re-sorted here.
    func suggest(image: UIImage) async throws -> [Candidate] {
        guard let jpeg = ImageTools.jpegForUpload(image, maxSide: 768, quality: 0.8) else {
            throw APIError.message(L("写真を読み込めませんでした。"))
        }
        let res = try await NativeAPI.call("suggestWords", [
            "imageBase64": "data:image/jpeg;base64,\(jpeg.base64EncodedString())",
            "targetLanguage": NativeAPI.targetLanguage,
        ], as: Suggestions.self, timeout: 25)
        var out: [Candidate] = []
        for c in res.suggestions where !out.contains(where: { $0.headword == c.headword }) { out.append(c) }
        guard !out.isEmpty else { throw APIError.message(L("AIから候補が返りませんでした。もう一度お試しください。")) }
        return out
    }

    /// The scan screen (web `detectScan`): nouns only, the learner's level, dictionary learning and
    /// the scan_events funnel log — all on the server, same as the web.
    func detectScan(image: UIImage, lat: Double? = nil, lng: Double? = nil) async throws -> [Candidate] {
        struct Res: Decodable { let items: [Candidate] }
        guard let jpeg = ImageTools.jpegForUpload(image) else { throw APIError.message(L("写真を読み込めませんでした。")) }
        var data: [String: Any] = ["imageBase64": "data:image/jpeg;base64,\(jpeg.base64EncodedString())"]
        if let lat, let lng { data["lat"] = lat; data["lng"] = lng }
        let res = try await NativeAPI.call("detectScan", data, as: Res.self, timeout: 40)
        var out: [Candidate] = []
        for c in res.items where !out.contains(where: { $0.headword == c.headword }) { out.append(c) }
        guard !out.isEmpty else { throw APIError.message(L("写真から言葉を見つけられませんでした。明るい所で、撮りたい物に近づいて撮り直してください。")) }
        return out
    }

    /// Typed word (Japanese or Chinese) → 2–5 names, each with how it differs
    /// (`suggestWordCandidates`). One result goes straight to the card; several go to the picker.
    func candidates(for query: String, scene: String? = nil) async throws -> [Candidate] {
        var data: [String: Any] = ["query": String(query.prefix(60)), "targetLanguage": NativeAPI.targetLanguage]
        if let scene, !scene.isEmpty { data["scene"] = String(scene.prefix(200)) }
        let res = try await NativeAPI.call("suggestWordCandidates", data, as: WordCandidates.self, timeout: 30)
        return res.candidates
    }

    /// Text search ("文字で調べる"): turn a typed word (Japanese or Chinese) into a candidate.
    func lookup(text query: String) async throws -> Candidate {
        // l10n-ignore (prompt) — the next line opens an AI prompt (always Japanese; the server reads it)
        let prompt = """
        学習者が「\(query)」を台湾華語で知りたがっています。日本語なら台湾華語に訳し、中国語ならそのまま使ってください。
        出力はJSONのみ: {"items":[{"kind":"text","headword":"繁体字","zhuyin":"注音","pinyin":"拼音","meaning_ja":"日本語訳","pos":"名詞など","point":[500,500],"confidence":0.9,"alternatives":[]}]}
        """
        let text = try await complete(.scan, prompt: prompt, timeout: 30)
        guard let first = try Self.parseItems(text).first else { throw APIError.message(L("その言葉が見つかりませんでした。")) }
        return first
    }

    /// The web's card (`generateCard`): level resolved against the dictionary (級外 when unsure),
    /// the learner's level and explanation language, retries on bad shape, every extras section.
    func cardDetails(for candidate: Candidate) async throws -> CardDetails {
        var data: [String: Any] = ["headword": candidate.headword, "targetLanguage": NativeAPI.targetLanguage]
        if let hint = candidate.categoryKey, !hint.isEmpty { data["hintCategory"] = hint }
        return try await NativeAPI.call("generateCard", data, as: CardDetails.self, timeout: 60)
    }

    /// wordbook.functions.ts EXTRACT_PROMPT: read the words printed on a vocabulary page (not saved yet).
    func extractWordbook(image: UIImage) async throws -> WordbookDraft {
        guard let jpeg = ImageTools.jpegForUpload(image, maxSide: 2000, quality: 0.85) else { throw APIError.message(L("写真を読み込めませんでした。")) }
        // l10n-ignore (prompt) — the next line opens an AI prompt (always Japanese; the server reads it)
        let prompt = """
        あなたは台湾華語(zh-TW / 繁体字 / 注音)の学習アプリの、単語帳読み取りエンジンです。
        入力画像は単語帳・教科書の語彙ページ・自作の単語リストです。そこに並んでいる語を読み取ってください。

        厳守ルール:
        - 出力は下記の JSON オブジェクト1つだけ。前置き・後書き・コードフェンス禁止。
        - 写っている語だけを返す。足さない。関連語や思いついた語を混ぜない。
        - 台湾教育部準拠の繁体字で返す。簡体字で書かれていれば繁体字に直す。
        - 注音・拼音・意味がその頁に書かれていればそれを写す。書かれていなければ、その語の正しい読みと意味を補ってよい。
        - ページ番号・単元番号・記号だけの行、欧文だけの見出しは語ではないので返さない。
        - 語はページに並んでいる順で返す。
        - 多くても\(Wordbook.maxEntriesPerPhoto)語まで。

        {"title":"単元名や級(読めなければ空文字)","entries":[{"headword":"繁体字","reading_zhuyin":"注音","pinyin":"拼音","meaning_ja":"意味"}]}
        """
        let text = try await complete(.wordbook, prompt: prompt, jpeg: jpeg, timeout: 60)
        guard let draft = try? JSONDecoder().decode(WordbookDraft.self, from: Self.jsonData(from: text)) else {
            throw APIError.message(L("単語帳の形が読み取れませんでした。もう一度撮ってみてください。"))
        }
        let cleaned = Wordbook.clean(draft.entries)
        guard !cleaned.isEmpty else { throw APIError.message(L("このページから語を読み取れませんでした。語が並んでいる所を明るく撮ってください。")) }
        return WordbookDraft(title: draft.title, entries: cleaned)
    }

    /// Plain text completion (journal correction, scaffolds).
    func text(_ prompt: String, timeout: TimeInterval = 40) async throws -> String {
        try await complete(.text, prompt: prompt, timeout: timeout)
    }

    /// JSON completion decoded leniently.
    func json<T: Decodable>(_ type: T.Type, prompt: String, image: UIImage? = nil, timeout: TimeInterval = 40) async throws -> T {
        let jpeg = image.flatMap { ImageTools.jpegForUpload($0, maxSide: 1024, quality: 0.8) }
        let raw = try await complete(.text, prompt: prompt, jpeg: jpeg, timeout: timeout)
        return try JSONDecoder().decode(T.self, from: Self.jsonData(from: raw))
    }

    // MARK: - Transport

    private func complete(_ feature: Feature, prompt: String, jpeg: Data? = nil, timeout: TimeInterval) async throws -> String {
        let url = AppConfig.webBaseURL.appendingPathComponent("api/native-ai")
        // Guests are signed in anonymously, so there is always a session; refresh it if it is about to expire.
        try? await SupabaseClient.shared.refreshIfNeeded()
        guard let token = SupabaseClient.shared.session?.accessToken else { throw APIError.unauthorized }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = ["feature": feature.rawValue, "prompt": prompt]
        if let jpeg { body["imageBase64"] = "data:image/jpeg;base64,\(jpeg.base64EncodedString())" }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch let e as URLError {
            throw e.code == .timedOut ? APIError.timeout : APIError.offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        // The server's `error` is written for the learner, so show it as-is when present.
        let serverMessage = (json?["error"] as? String) ?? ""
        switch status {
        case 200: break
        case 401: throw APIError.unauthorized
        case 429: throw APIError.limit(serverMessage.isEmpty ? APIError.dailyCapMessage : serverMessage)
        default: throw APIError.server(status, serverMessage.isEmpty ? L("AIの解析に失敗しました（\(status)）") : serverMessage)
        }
        guard let text = json?["text"] as? String else { throw APIError.decoding }
        return text
    }

    // MARK: - Lenient parsing (scan-detect-parse.ts)

    nonisolated private static func jsonData(from text: String) throws -> Data {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fenceStart = t.range(of: "```") {
            t = String(t[fenceStart.upperBound...])
            if t.hasPrefix("json") { t = String(t.dropFirst(4)) }
            if let fenceEnd = t.range(of: "```") { t = String(t[..<fenceEnd.lowerBound]) }
        }
        if let s = t.firstIndex(of: "{"), let e = t.lastIndex(of: "}"), s < e { t = String(t[s...e]) }
        guard let data = t.data(using: .utf8) else { throw APIError.decoding }
        return data
    }

    nonisolated private static func parseItems(_ text: String) throws -> [Candidate] {
        let data = try jsonData(from: text)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = obj["items"] as? [Any] else { throw APIError.message(L("AIの返事を読み取れませんでした。もう一度試してください。写真は残っています。")) }
        var out: [Candidate] = []
        for item in raw.prefix(6) {
            guard let d = try? JSONSerialization.data(withJSONObject: item),
                  let raw = try? JSONDecoder().decode(Candidate.self, from: d) else { continue }
            // Headwords must be in the learning language: fix a trailing note once, otherwise drop it.
            guard let head = raw.headword.coercedZhHeadword else { continue }
            let c = Candidate(kind: raw.kind, headword: head, zhuyin: raw.zhuyin, pinyin: raw.pinyin, meaningJa: raw.meaningJa,
                              pos: raw.pos, point: raw.point, confidence: raw.confidence, alternatives: raw.alternatives)
            if !out.contains(where: { $0.headword == c.headword }) { out.append(c) }
        }
        return out
    }
}
