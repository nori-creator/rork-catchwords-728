import Foundation
import UIKit

/// Vision detection + card generation through the Rork Toolkit (OpenAI-compatible gateway).
/// Prompts are ported verbatim in intent from `scan.functions.ts` (Taiwan Mandarin, nouns only, 0–1000 points).
final class AIService {
    static let shared = AIService()

    private let model = "google/gemini-3.8-flash"
    private let fallbackModel = "openai/gpt-6-luna-fast"

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

    private static func cardPrompt(headword: String, meaning: String) -> String {
        let keys = Category.allKeys.joined(separator: ", ")
        return """
        台湾華語の学習カードを作ってください。語: 「\(headword)」(意味: \(meaning))。
        台湾で実際に使われる語彙・繁体字のみ。解説は日本語。
        出力はJSONオブジェクトのみ(前置き・コードフェンス禁止):
        {
          "category_key": "次から1つ: \(keys)",
          "level": "TOCFL-1〜TOCFL-6 のどれか",
          "example_sentence": "台湾で自然な短い例文(繁体字)",
          "example_translation": "例文の日本語訳",
          "extras": {
            "frequency_level": 1〜5の整数(5=毎日耳にする),
            "register_scale": -2〜2の整数(-2=完全に口語, 0=どちらでも, 2=完全に書面),
            "register_tag": "口語 / 書面 / 口語・書面",
            "scene_weights": {"eat":0.0,"town":0.0,"house":0.0,"wear":0.0,"play":0.0,"nature":0.0,"people":0.0,"marks":0.0} (合計およそ1),
            "usage_chunks": [ {"parts":[{"text":"買","pos":"V"},{"text":"\(headword)","pos":"O"}],"ja":"短い日本語訳"} ] (ネイティブ頻出の型を3つ。量詞は含めない。入れ替え可能な所は "slot": true),
            "usage_context": "どこで見て使うか・口語/書面・頻度を2文以内で",
            "measure_words": [{"word":"個","zhuyin":"ㄍㄜˋ","note":"使い分け(名詞のみ、無ければ空配列)"}],
            "mnemonic": "覚え方を1文"
          }
        }
        """
    }

    func detect(image: UIImage, textOnly: Bool = false) async throws -> [Candidate] {
        guard let jpeg = ImageTools.jpegForUpload(image) else { throw APIError.message("写真を読み込めませんでした。") }
        let dataURL = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        let prompt = textOnly
            ? Self.detectPrompt + "\n今回はスキャンです。kind=text(写っている文字そのもの)だけを返し、名詞以外の語も写っていれば返してよい。"
            : Self.detectPrompt
        let content: [[String: Any]] = [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": ["url": dataURL]],
        ]
        let text: String
        do {
            text = try await complete(model: model, content: content, timeout: 40)
        } catch {
            text = try await complete(model: fallbackModel, content: content, timeout: 40)
        }
        let items = try Self.parseItems(text)
        guard !items.isEmpty else { throw APIError.message("写真から言葉を見つけられませんでした。明るい所で、撮りたい物に近づいて撮り直してください。") }
        return items
    }

    /// Text search ("文字で調べる"): turn a typed word (Japanese or Chinese) into a candidate.
    func lookup(text query: String) async throws -> Candidate {
        let prompt = """
        学習者が「\(query)」を台湾華語で知りたがっています。日本語なら台湾華語に訳し、中国語ならそのまま使ってください。
        出力はJSONのみ: {"items":[{"kind":"text","headword":"繁体字","zhuyin":"注音","pinyin":"拼音","meaning_ja":"日本語訳","pos":"名詞など","point":[500,500],"confidence":0.9,"alternatives":[]}]}
        """
        let text = try await complete(model: model, content: [["type": "text", "text": prompt]], timeout: 30)
        guard let first = try Self.parseItems(text).first else { throw APIError.message("その言葉が見つかりませんでした。") }
        return first
    }

    func cardDetails(for candidate: Candidate) async throws -> CardDetails {
        let prompt = Self.cardPrompt(headword: candidate.headword, meaning: candidate.meaningJa)
        let text = try await complete(model: model, content: [["type": "text", "text": prompt]], timeout: 40)
        let data = try Self.jsonData(from: text)
        return try JSONDecoder().decode(CardDetails.self, from: data)
    }

    /// wordbook.functions.ts EXTRACT_PROMPT: read the words printed on a vocabulary page (not saved yet).
    func extractWordbook(image: UIImage) async throws -> WordbookDraft {
        guard let jpeg = ImageTools.jpegForUpload(image, maxSide: 2000, quality: 0.85) else { throw APIError.message("写真を読み込めませんでした。") }
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
        let content: [[String: Any]] = [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())"]],
        ]
        let text: String
        do {
            text = try await complete(model: model, content: content, timeout: 60)
        } catch {
            text = try await complete(model: fallbackModel, content: content, timeout: 60)
        }
        guard let draft = try? JSONDecoder().decode(WordbookDraft.self, from: Self.jsonData(from: text)) else {
            throw APIError.message("単語帳の形が読み取れませんでした。もう一度撮ってみてください。")
        }
        let cleaned = Wordbook.clean(draft.entries)
        guard !cleaned.isEmpty else { throw APIError.message("このページから語を読み取れませんでした。語が並んでいる所を明るく撮ってください。") }
        return WordbookDraft(title: draft.title, entries: cleaned)
    }

    /// Plain text completion (journal correction, scaffolds).
    func text(_ prompt: String, timeout: TimeInterval = 40) async throws -> String {
        do {
            return try await complete(model: model, content: [["type": "text", "text": prompt]], timeout: timeout)
        } catch {
            return try await complete(model: fallbackModel, content: [["type": "text", "text": prompt]], timeout: timeout)
        }
    }

    /// JSON completion decoded leniently.
    func json<T: Decodable>(_ type: T.Type, prompt: String, image: UIImage? = nil, timeout: TimeInterval = 40) async throws -> T {
        var content: [[String: Any]] = [["type": "text", "text": prompt]]
        if let image, let jpeg = ImageTools.jpegForUpload(image, maxSide: 1024, quality: 0.8) {
            content.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())"]])
        }
        let raw = try await complete(model: model, content: content, timeout: timeout)
        return try JSONDecoder().decode(T.self, from: Self.jsonData(from: raw))
    }

    // MARK: - Transport

    private func complete(model: String, content: [[String: Any]], timeout: TimeInterval) async throws -> String {
        let base = Config.EXPO_PUBLIC_TOOLKIT_URL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, let url = URL(string: "\(base)/v2/vercel/v1/chat/completions") else { throw APIError.notConfigured }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": content]],
            "temperature": 0.2,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch let e as URLError {
            throw e.code == .timedOut ? APIError.timeout : APIError.offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: break
        case 401: throw APIError.message("AI機能が一時的に使えません。アプリを再起動してください。")
        case 402: throw APIError.message("AI機能が一時的に使えません。しばらくしてからお試しください。")
        case 429: throw APIError.server(429, "混み合っています。少し待ってからもう一度お試しください。")
        default: throw APIError.server(status, "AIの解析に失敗しました（\(status)）")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else { throw APIError.decoding }
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
              let raw = obj["items"] as? [Any] else { throw APIError.message("AIの返事を読み取れませんでした。もう一度試してください。写真は残っています。") }
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
