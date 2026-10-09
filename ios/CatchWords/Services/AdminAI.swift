import Foundation
import Observation

/// Whether the signed-in account is an admin (web `has_role(admin)`), for the developer section of 設定.
///
/// Asked once per account with `adminGetAiSettings` (web docs/admin-ai-api.md): an admin gets the whole
/// settings, anyone else `{ "isAdmin": false }`. Any failure — a server without the function yet, offline,
/// the demo backend's empty answer — counts as "not an admin", so for everyone else (and the App Review
/// demo account) the app is exactly what it was. Forgotten on sign-out (`AccountCleanup.signedOut`) and
/// whenever another account is signed in.
@Observable
final class AdminAccess {
    static let shared = AdminAccess()

    /// True only after the server said so for the account signed in now.
    private(set) var isAdmin: Bool = false
    /// The account the answer above belongs to (nil: not asked yet).
    private var checkedUser: String?
    /// The account being asked right now (one request at a time).
    private var checkingUser: String?

    /// Asks the server unless this account already has an answer. Never throws, never waits in front of a screen.
    func refresh() async {
        guard let uid = SupabaseClient.shared.userId else {
            clear()
            return
        }
        if checkedUser != uid {
            // Another account: the previous answer is not this one's.
            isAdmin = false
        }
        guard checkedUser != uid, checkingUser != uid else { return }
        checkingUser = uid
        defer { if checkingUser == uid { checkingUser = nil } }
        do {
            let answer = try await NativeAPI.call("adminGetAiSettings", [:], as: AdminAiSettings.self,
                                                  timeout: 30, asUser: uid)
            guard SupabaseClient.shared.userId == uid else { return }
            isAdmin = answer.isAdmin
            checkedUser = uid
        } catch {
            guard SupabaseClient.shared.userId == uid else { return }
            isAdmin = false
            // A dropped connection may succeed on the next visit to 設定; any other failure (no such
            // function on this server, a refusal, an answer that does not read) stays "no" for this account.
            switch error as? APIError {
            case .offline?, .timeout?: break
            default: checkedUser = uid
            }
        }
    }

    /// The developer screen read the settings itself: keep the answer for this account.
    func update(isAdmin: Bool) {
        guard let uid = SupabaseClient.shared.userId else { return }
        self.isAdmin = isAdmin
        checkedUser = uid
    }

    /// Sign-out or account switch: nothing of the previous account's role stays.
    func clear() {
        isAdmin = false
        checkedUser = nil
        checkingUser = nil
    }
}

// MARK: - The answers (web src/lib/admin-ai.server.ts). Every field is optional on the wire.

/// `adminGetAiSettings` → `result`.
nonisolated struct AdminAiSettings: Decodable, Sendable {
    var isAdmin: Bool
    var status: AdminAiStatus
    var features: [AdminAiFeature]
    var providers: [AdminAiProvider]
    var image: AdminAiImage?
    var tts: AdminAiTts?

    enum CodingKeys: String, CodingKey { case isAdmin, status, features, providers, image, tts }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isAdmin = c.adminBool(.isAdmin)
        status = ((try? c.decodeIfPresent(AdminAiStatus.self, forKey: .status)) ?? nil) ?? AdminAiStatus()
        features = c.adminList(AdminAiFeature.self, .features)
        providers = c.adminList(AdminAiProvider.self, .providers)
        image = (try? c.decodeIfPresent(AdminAiImage.self, forKey: .image)) ?? nil
        tts = (try? c.decodeIfPresent(AdminAiTts.self, forKey: .tts)) ?? nil
    }
}

nonisolated struct AdminAiStatus: Decodable, Sendable {
    var ok: Bool = false
    var provider: String?
    var error: String?

    enum CodingKeys: String, CodingKey { case ok, provider, error }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.adminBool(.ok)
        provider = c.adminOptStr(.provider)
        error = c.adminOptStr(.error)
    }
}

/// One AI feature (`scan`, `card`, `review`, …).
nonisolated struct AdminAiFeature: Decodable, Sendable {
    var id: String
    /// `flash-lite` | `flash` | `pro`.
    var tier: String
    var needsVision: Bool
    /// The name and description in each display language (`ja` / `en` / `zh-TW`).
    var label: [String: String]
    var description: [String: String]
    /// The saved value: `"auto"` or `"provider:model"`.
    var value: String
    var provider: String?
    var model: String?
    var resolved: String?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case id, tier, needsVision, label, description, value, provider, model, resolved, error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.adminStr(.id)
        tier = c.adminStr(.tier)
        needsVision = c.adminBool(.needsVision)
        label = c.adminDict(.label)
        description = c.adminDict(.description)
        let v = c.adminStr(.value)
        value = v.isEmpty ? "auto" : v
        provider = c.adminOptStr(.provider)
        model = c.adminOptStr(.model)
        resolved = c.adminOptStr(.resolved)
        error = c.adminOptStr(.error)
    }
}

/// An AI provider (`google`, `openai`, `openrouter`, …). Never the key itself, only whether there is one.
nonisolated struct AdminAiProvider: Decodable, Sendable {
    var id: String
    var name: String
    var hasKey: Bool
    var models: [String]
    var visionModels: [String]
    var error: String?

    enum CodingKeys: String, CodingKey { case id, name, hasKey, models, visionModels, error }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.adminStr(.id)
        let n = c.adminStr(.name)
        name = n.isEmpty ? id : n
        hasKey = c.adminBool(.hasKey)
        models = c.adminStrings(.models)
        visionModels = c.adminStrings(.visionModels)
        error = c.adminOptStr(.error)
    }
}

/// The AI images of the text search (`image_generation`).
nonisolated struct AdminAiImage: Decodable, Sendable {
    var provider: String
    var model: String
    /// What a developer saved (nil: the server's environment defaults are in use).
    var saved: AdminAiImageChoice?
    var providers: [AdminAiImageProvider]

    enum CodingKeys: String, CodingKey { case provider, model, saved, providers }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = c.adminStr(.provider)
        model = c.adminStr(.model)
        saved = (try? c.decodeIfPresent(AdminAiImageChoice.self, forKey: .saved)) ?? nil
        providers = c.adminList(AdminAiImageProvider.self, .providers)
    }
}

/// `image.saved`, and the answer of `adminSetImageConfig` (`{ ok, provider, model }`).
nonisolated struct AdminAiImageChoice: Decodable, Sendable {
    var provider: String
    var model: String

    enum CodingKeys: String, CodingKey { case provider, model }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = c.adminStr(.provider)
        model = c.adminStr(.model)
    }
}

nonisolated struct AdminAiImageProvider: Decodable, Sendable {
    var id: String
    var name: String
    var hasKey: Bool
    var defaultModel: String

    enum CodingKeys: String, CodingKey { case id, name, hasKey, defaultModel }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.adminStr(.id)
        let n = c.adminStr(.name)
        name = n.isEmpty ? id : n
        hasKey = c.adminBool(.hasKey)
        defaultModel = c.adminStr(.defaultModel)
    }
}

/// `adminTestImage` → `result`. `image` is a `data:image/…;base64,…` URI or an https URL.
nonisolated struct AdminAiImageTest: Decodable, Sendable {
    var provider: String
    var model: String
    var credentialName: String?
    var ok: Bool
    var image: String?
    var error: String?
    var ms: Double

    enum CodingKeys: String, CodingKey { case provider, model, credentialName, ok, image, error, ms }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = c.adminStr(.provider)
        model = c.adminStr(.model)
        credentialName = c.adminOptStr(.credentialName)
        ok = c.adminBool(.ok)
        image = c.adminOptStr(.image)
        error = c.adminOptStr(.error)
        ms = ((try? c.decodeIfPresent(Double.self, forKey: .ms)) ?? nil) ?? 0
    }
}

/// The pronunciation voices (`tts_voice`).
nonisolated struct AdminAiTts: Decodable, Sendable {
    var defaultEngine: String
    /// `zh-TW` / `en` / `ja` → the voice in use.
    var languages: [String: AdminAiTtsRow]
    var providers: [AdminAiTtsProvider]

    enum CodingKeys: String, CodingKey { case defaultEngine, languages, providers }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaultEngine = c.adminStr(.defaultEngine)
        languages = ((try? c.decodeIfPresent([String: AdminAiTtsRow].self, forKey: .languages)) ?? nil) ?? [:]
        providers = c.adminList(AdminAiTtsProvider.self, .providers)
    }
}

nonisolated struct AdminAiTtsRow: Decodable, Sendable {
    /// `default` | `azure` | `gemini` | `elevenlabs`.
    var provider: String
    var voice: String
    var model: String?
    /// `female` | `male` (台湾華語 with Azure / Gemini only).
    var gender: String?
    var incomplete: Bool

    enum CodingKeys: String, CodingKey { case provider, voice, model, gender, incomplete }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let p = c.adminStr(.provider)
        provider = p.isEmpty ? "default" : p
        voice = c.adminStr(.voice)
        model = c.adminOptStr(.model)
        gender = c.adminOptStr(.gender)
        incomplete = c.adminBool(.incomplete)
    }
}

nonisolated struct AdminAiTtsProvider: Decodable, Sendable {
    var id: String
    var name: String
    var hasKey: Bool
    var models: [String]
    /// Language → voice ids (may be empty: the voice id is typed in then).
    var voices: [String: [String]]

    enum CodingKeys: String, CodingKey { case id, name, hasKey, models, voices }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.adminStr(.id)
        let n = c.adminStr(.name)
        name = n.isEmpty ? id : n
        hasKey = c.adminBool(.hasKey)
        models = c.adminStrings(.models)
        voices = ((try? c.decodeIfPresent([String: [String]].self, forKey: .voices)) ?? nil) ?? [:]
    }
}

/// Lenient fields: missing, null or of another type → the empty value, never a failed decode.
private extension KeyedDecodingContainer {
    nonisolated func adminStr(_ k: Key) -> String { ((try? decodeIfPresent(String.self, forKey: k)) ?? nil) ?? "" }
    nonisolated func adminOptStr(_ k: Key) -> String? {
        let s = ((try? decodeIfPresent(String.self, forKey: k)) ?? nil) ?? ""
        return s.isEmpty ? nil : s
    }
    nonisolated func adminBool(_ k: Key) -> Bool { ((try? decodeIfPresent(Bool.self, forKey: k)) ?? nil) ?? false }
    nonisolated func adminStrings(_ k: Key) -> [String] {
        ((try? decodeIfPresent([String].self, forKey: k)) ?? nil) ?? []
    }
    nonisolated func adminDict(_ k: Key) -> [String: String] {
        ((try? decodeIfPresent([String: String].self, forKey: k)) ?? nil) ?? [:]
    }
    nonisolated func adminList<T: Decodable>(_ type: T.Type, _ k: Key) -> [T] {
        ((try? decodeIfPresent([T].self, forKey: k)) ?? nil) ?? []
    }
}
