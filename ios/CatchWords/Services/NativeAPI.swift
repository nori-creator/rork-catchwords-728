import Foundation

/// Calls the web app's own server functions (`POST /api/native-fn`).
///
/// Candidate naming, card generation, saving, re-encounters, speech and review grading are
/// decided in the Lovable web app. Re-implementing them in Swift made the two apps drift
/// (levels, dictionary checks, usage notes, extras merging, daily caps). Calling the same
/// functions with the same input keeps iOS in step: fix it on the web and iOS is fixed too.
enum NativeAPI {
    /// The learning language (`profiles.target_language`: "zh-TW" or "en"). `ProfileStore` keeps it
    /// in step; the web profile decides the rest (level, explanation language).
    /// Starts from the last one this device saw, so the first album read after launch (before the
    /// profile arrives) already filters by the right language.
    nonisolated(unsafe) static var targetLanguage = UserDefaults.standard.string(forKey: "last.targetLanguage") ?? "zh-TW" {
        didSet { UserDefaults.standard.set(targetLanguage, forKey: "last.targetLanguage") }
    }
    /// The learning language's name in the display language (台湾華語 / English / 日本語 …).
    static var targetName: String {
        switch targetLanguage {
        case "en": L("英語")
        case "ja": L("日本語")
        default: L("台湾華語")
        }
    }
    /// A sample word / sentence in the learning language for input placeholders (never in the wrong language).
    static func sample(_ kind: SampleKind) -> String {
        switch (kind, targetLanguage) {
        case (.word, "en"): "chair"  // l10n-ignore (learning-language sample)
        case (.word, "ja"): "椅子"  // l10n-ignore (learning-language sample)
        case (.word, _): "椅子"  // l10n-ignore (learning-language sample)
        case (.search, "en"): "mango"  // l10n-ignore (learning-language sample)
        case (.search, "ja"): "マンゴー"  // l10n-ignore (learning-language sample)
        case (.search, _): "芒果"  // l10n-ignore (learning-language sample)
        case (.diary, "en"): "This morning I went to a café…"  // l10n-ignore (learning-language sample)
        case (.diary, "ja"): "今朝、カフェに行きました…"  // l10n-ignore (learning-language sample)
        case (.diary, _): "今天早上我去咖啡店…"  // l10n-ignore (learning-language sample)
        }
    }
    enum SampleKind { case word, search, diary }

    /// target-profile.ts defaultPos: the placeholder part of speech saved before the card arrives, in the
    /// same system the card uses (I9: 「名詞」 was saved on English cards).
    static var defaultPos: String {
        switch targetLanguage {
        case "en": "noun"  // l10n-ignore (data)
        case "ja": "名詞"  // l10n-ignore (data)
        default: "N"
        }
    }

    /// BCP-47 for speaking and listening in the learning language (web `speechLangOf` / `sttLangOf`).
    static var speechLanguage: String {
        switch targetLanguage {
        case "en": "en-US"
        case "ja": "ja-JP"
        default: "zh-TW"
        }
    }

    /// Returns the function's `result` as raw JSON bytes.
    static func call(_ fn: String, _ data: [String: Any], timeout: TimeInterval = 40) async throws -> Data {
        // Photos, words and text go on to a third-party AI only after this account agreed (Guideline 5.1.2(i)).
        // Refused here, before anything leaves the phone; the screens turn the error into the consent screen.
        if AIConsent.aiFunctions.contains(fn), !AIConsent.shared.allowsSending() {
            throw APIError.aiConsentRequired
        }
        do {
            return try await post(fn, data, timeout: timeout)
        } catch APIError.aiConsentRequired where !AIConsent.recordFunctions.contains(fn) {
            // The server's record has no agreement for this account (web patch, docs/ios-spec/23-ai-consent.md).
            // An agreement made on this device that had not reached it yet is sent now and the call tried once
            // more; otherwise the consent screen asks again.
            guard await AIConsent.shared.serverRefused() else { throw APIError.aiConsentRequired }
            return try await post(fn, data, timeout: timeout)
        }
    }

    private static func post(_ fn: String, _ data: [String: Any], timeout: TimeInterval) async throws -> Data {
        let url = AppConfig.webBaseURL.appendingPathComponent("api/native-fn")
        let client = SupabaseClient.shared
        // An expiring token is refreshed first; a dead login throws `.unauthorized` (the app shows the
        // login screen), a network hiccup during the refresh is not an error here.
        try await client.refreshForRequest()
        let payload = try JSONSerialization.data(withJSONObject: ["fn": fn, "data": data])
        let consentVersion = String(AIConsent.currentVersion)
        // A 401 gets one forced refresh and a retry; a second 401 ends the login.
        let (body, http) = try await client.withTokenRetry { token in
            var req = URLRequest(url: url, timeoutInterval: timeout)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            // On every call (spec: the server checks its consent record only for callers that send this, so
            // builds without the record keep working until the owner sets AI_CONSENT_ENFORCE_NATIVE). A server
            // without the web patch ignores it.
            req.setValue(consentVersion, forHTTPHeaderField: "AI-Consent-Version")
            req.httpBody = payload
            do {
                let (d, r) = try await URLSession.shared.data(for: req)
                guard let h = r as? HTTPURLResponse else { throw APIError.decoding }
                return (d, h)
            } catch let e as URLError {
                throw APIError.from(e)
            }
        }
        let status = http.statusCode
        let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        let message = (json?["error"] as? String) ?? ""
        switch status {
        case 200:
            guard let json, let result = json["result"] else { throw APIError.decoding }
            if result is NSNull { return Data("null".utf8) }
            return try JSONSerialization.data(withJSONObject: result, options: [.fragmentsAllowed])
        case 401: throw APIError.unauthorized
        // An AI function refused by the server for want of a recorded consent (nothing was sent on to AI).
        case 403 where message.hasPrefix("AI_CONSENT_REQUIRED"): throw APIError.aiConsentRequired
        case 429: throw APIError.limit(message.isEmpty ? APIError.dailyCapMessage : message)
        default: throw APIError.server(status, message)
        }
    }

    static func call<T: Decodable>(_ fn: String, _ data: [String: Any], as type: T.Type,
                                   timeout: TimeInterval = 40) async throws -> T {
        let raw = try await call(fn, data, timeout: timeout)
        do {
            return try JSONDecoder().decode(T.self, from: raw)
        } catch {
            throw APIError.decoding
        }
    }
}
