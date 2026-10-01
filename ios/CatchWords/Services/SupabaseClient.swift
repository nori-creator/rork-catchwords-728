import Foundation

nonisolated enum APIError: LocalizedError {
    case notConfigured
    case unauthorized
    case timeout
    case offline
    case server(Int, String)
    case decoding
    case message(String)
    /// The server's rolling-24h cap (`assertWithinDailyCap`). Waiting a few minutes does not help.
    case limit(String)

    /// err.dailyCap (web i18n).
    static var dailyCapMessage: String { L("1日の利用上限に達しました。24時間以内に自動で回復します。") }

    var errorDescription: String? {
        switch self {
        case .notConfigured: L("サーバーの設定が見つかりません。")
        case .unauthorized: L("ログインの有効期限が切れました。もう一度ログインしてください。")
        case .timeout: L("通信が時間切れになりました。電波の良い場所でもう一度お試しください。")
        case .offline: L("インターネットに接続できません。")
        case .server(let code, let msg): L10n.readerSafe(msg, fallback: L("サーバーエラー（\(code)）"))
        case .decoding: L("データの読み込みに失敗しました。")
        case .message(let m): L10n.readerSafe(m, fallback: L("うまくいきませんでした。もう一度お試しください。"))
        case .limit(let m): L10n.readerSafe(m, fallback: Self.dailyCapMessage)
        }
    }

    /// Whether retrying later may succeed (the web app shows the reason instead of a blanket "later").
    var isRetryable: Bool {
        switch self {
        case .timeout, .offline: true
        case .server(let code, _): code >= 500 || code == 429
        case .limit: false
        default: false
        }
    }
}

/// Minimal Supabase REST client talking to the SAME project as the Lovable web app.
/// RLS (`auth.uid() = user_id`) protects every row, so the app talks to it directly.
final class SupabaseClient {
    static let shared = SupabaseClient()

    private let baseURL: URL?
    private let anonKey: String
    private let sessionAccount = "supabase.session"
    private(set) var session: AuthSession?
    private let urlSession: URLSession

    init() {
        let raw = AppConfig.supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        baseURL = raw.isEmpty ? nil : URL(string: raw)
        anonKey = AppConfig.supabasePublishableKey
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        urlSession = URLSession(configuration: cfg)
        if let data = KeychainStore.load(account: sessionAccount) {
            session = try? JSONDecoder().decode(AuthSession.self, from: data)
        }
    }

    var userId: String? { session?.userId }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        let json = try await authRequest(path: "token?grant_type=password", body: ["email": email, "password": password])
        try storeSession(json)
    }

    /// Returns true when a session was created immediately (email confirmation disabled).
    func signUp(email: String, password: String) async throws -> Bool {
        let json = try await authRequest(path: "signup", body: ["email": email, "password": password])
        if json["access_token"] != nil {
            try storeSession(json)
            return true
        }
        return false
    }

    /// Supabase anonymous sign-in (only works when anonymous sign-ins are enabled on the project).
    func signInAnonymously() async throws {
        let json = try await authRequest(path: "signup", body: [:])
        try storeSession(json)
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        let json = try await authRequest(
            path: "token?grant_type=id_token",
            body: ["provider": "apple", "id_token": idToken, "nonce": nonce]
        )
        try storeSession(json)
    }

    /// Sends the password (re)set email. Also lets Google/Apple users add a password to the SAME account (UUID).
    func sendPasswordReset(email: String) async throws {
        _ = try await authRequest(
            path: "recover?redirect_to=https://catchwords.lovable.app/reset-password",
            body: ["email": email]
        )
    }

    /// Merges keys into auth `user_metadata` (the web keeps learning_preferences / notification_preferences there).
    func updateUserMetadata(_ data: [String: Any]) async throws {
        try await refreshIfNeeded()
        guard let baseURL, let token = session?.accessToken,
              let url = URL(string: "auth/v1/user", relativeTo: baseURL) else { throw APIError.notConfigured }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "PUT"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["data": data])
        let (_, response) = try await perform(req)
        guard (200..<300).contains(response.statusCode) else { throw APIError.server(response.statusCode, "") }
    }

    /// The signed-in user's `user_metadata` (notification_preferences, learning_preferences…).
    func userMetadata() async throws -> [String: Any] {
        try await refreshIfNeeded()
        guard let baseURL, let token = session?.accessToken,
              let url = URL(string: "auth/v1/user", relativeTo: baseURL) else { throw APIError.notConfigured }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(req)
        guard (200..<300).contains(response.statusCode),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { throw APIError.server(response.statusCode, "") }
        return json["user_metadata"] as? [String: Any] ?? [:]
    }

    func refreshIfNeeded() async throws {
        guard let current = session else { throw APIError.unauthorized }
        guard current.expiresAt.timeIntervalSinceNow < 120 else { return }
        let json = try await authRequest(path: "token?grant_type=refresh_token", body: ["refresh_token": current.refreshToken])
        try storeSession(json)
    }

    func signOut() {
        session = nil
        KeychainStore.delete(account: sessionAccount)
    }

    private func authRequest(path: String, body: [String: String]) async throws -> [String: Any] {
        guard let baseURL, let url = URL(string: "auth/v1/\(path)", relativeTo: baseURL) else { throw APIError.notConfigured }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await perform(req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(response.statusCode) else {
            let msg = (json["error_description"] as? String) ?? (json["msg"] as? String) ?? (json["message"] as? String) ?? ""
            throw APIError.message(Self.localizeAuthError(msg, code: response.statusCode))
        }
        return json
    }

    private func storeSession(_ json: [String: Any]) throws {
        guard let access = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String,
              let user = json["user"] as? [String: Any],
              let uid = user["id"] as? String else { throw APIError.decoding }
        let expiresIn = (json["expires_in"] as? Double) ?? 3600
        let s = AuthSession(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(expiresIn),
            userId: uid,
            email: user["email"] as? String
        )
        session = s
        if let data = try? JSONEncoder().encode(s) { KeychainStore.save(data, account: sessionAccount) }
    }

    private static func localizeAuthError(_ msg: String, code: Int) -> String {
        let m = msg.lowercased()
        if m.contains("invalid login") { return L("メールアドレスかパスワードが違います。") }
        if m.contains("already registered") { return L("このメールアドレスは登録済みです。ログインしてください。") }
        if m.contains("password should be") { return L("パスワードは6文字以上にしてください。") }
        if m.contains("email not confirmed") { return L("確認メールのリンクを開いてからログインしてください。") }
        if m.contains("rate limit") { return L("しばらく時間をおいてからお試しください。") }
        return msg.isEmpty ? L("ログインに失敗しました（\(code)）") : msg
    }

    // MARK: - REST

    func rest(
        _ method: String,
        _ path: String,
        body: Any? = nil,
        prefer: String? = nil,
        timeout: TimeInterval = 20
    ) async throws -> Data {
        try await refreshIfNeeded()
        guard let baseURL, let token = session?.accessToken,
              let url = URL(string: "rest/v1/\(path)", relativeTo: baseURL) else { throw APIError.notConfigured }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await perform(req)
        if response.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(response.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw APIError.server(response.statusCode, (json?["message"] as? String) ?? "")
        }
        return data
    }

    // MARK: - Storage (private bucket "stickers": {uuid}/{ts}-{kind}.jpg)

    func upload(_ data: Data, path: String, contentType: String = "image/jpeg", bucket: String = "stickers", upsert: Bool = false) async throws {
        try await refreshIfNeeded()
        guard let baseURL, let token = session?.accessToken,
              let url = URL(string: "storage/v1/object/\(bucket)/\(path)", relativeTo: baseURL) else { throw APIError.notConfigured }
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.setValue(upsert ? "true" : "false", forHTTPHeaderField: "x-upsert")
        req.httpBody = data
        let (body, response) = try await perform(req)
        guard (200..<300).contains(response.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
            throw APIError.server(response.statusCode, (json?["message"] as? String) ?? L("写真の保存に失敗しました。"))
        }
    }

    /// Bulk delete in one bucket (account deletion).
    func removeObjects(_ paths: [String], bucket: String = "stickers") async throws {
        guard !paths.isEmpty else { return }
        try await refreshIfNeeded()
        guard let baseURL, let token = session?.accessToken,
              let url = URL(string: "storage/v1/object/\(bucket)", relativeTo: baseURL) else { throw APIError.notConfigured }
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "DELETE"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["prefixes": paths])
        _ = try await perform(req)
    }

    /// Public bucket URL (avatars).
    func publicURL(bucket: String, path: String) -> String? {
        guard let baseURL, let url = URL(string: "storage/v1/object/public/\(bucket)/\(path)", relativeTo: baseURL) else { return nil }
        return url.absoluteString
    }

    func signedURLs(for paths: [String], expiresIn: Int = 60 * 60 * 6) async throws -> [String: URL] {
        guard !paths.isEmpty else { return [:] }
        try await refreshIfNeeded()
        guard let baseURL, let token = session?.accessToken,
              let url = URL(string: "storage/v1/object/sign/stickers", relativeTo: baseURL) else { throw APIError.notConfigured }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["expiresIn": expiresIn, "paths": paths])
        let (data, response) = try await perform(req)
        guard (200..<300).contains(response.statusCode),
              let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return [:] }
        var out: [String: URL] = [:]
        for item in arr {
            guard let path = item["path"] as? String,
                  let signed = (item["signedURL"] as? String) ?? (item["signedUrl"] as? String),
                  let full = URL(string: "storage/v1\(signed)", relativeTo: baseURL) else { continue }
            out[path] = full.absoluteURL
        }
        return out
    }

    private func perform(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await urlSession.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw APIError.decoding }
            return (data, http)
        } catch let error as URLError {
            switch error.code {
            case .timedOut: throw APIError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost: throw APIError.offline
            default: throw APIError.message(error.localizedDescription)
            }
        }
    }
}

nonisolated enum SupabaseDate {
    /// Postgres timestamps come with 0–6 fractional digits; normalize before parsing.
    static func parse(_ raw: String) -> Date? {
        var s = raw.replacingOccurrences(of: " ", with: "T")
        if let dot = s.firstIndex(of: ".") {
            let rest = s[s.index(after: dot)...]
            let tzStart = rest.firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) ?? rest.endIndex
            s.removeSubrange(dot..<tzStart)
        }
        if !(s.hasSuffix("Z") || s.contains("+") || s.dropFirst(10).contains("-")) { s += "Z" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    static func string(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let raw = try c.decode(String.self)
            guard let date = parse(raw) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "bad date \(raw)")
            }
            return date
        }
        return d
    }
}
