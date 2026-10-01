import SwiftUI

nonisolated enum AuthPhase: Equatable, Sendable {
    case checking
    case signedOut
    case signedIn
    case failed(String)
}

@Observable
final class AuthStore {
    var phase: AuthPhase = .checking
    var isBusy: Bool = false
    var errorMessage: String?
    var infoMessage: String?
    /// True after sign-up sent a confirmation email: the screen offers "I've confirmed — sign in".
    var awaitingConfirmation: Bool = false
    var email: String? { SupabaseClient.shared.session?.email }

    /// Development builds only: enter the app without logging in (anonymous guest).
    /// App Store builds are Release builds, so this is off there automatically.
    static let devSkipLogin: Bool = {
        #if DEBUG
        true
        #else
        false
        #endif
    }()
    /// True while inside the app without a real account (guest mode).
    var isGuest: Bool = false

    private let client = SupabaseClient.shared

    /// Session check with an 8s timeout — never an endless silent spinner (route.tsx lesson).
    func bootstrap() async {
        phase = .checking
        guard client.session != nil else {
            if Self.devSkipLogin { await enterAsGuest() } else { phase = .signedOut }
            return
        }
        let result = await withTaskGroup(of: Bool?.self) { group -> Bool? in
            group.addTask { [client] in
                do {
                    try await client.refreshIfNeeded()
                    return true
                } catch APIError.unauthorized {
                    return false
                } catch {
                    return true
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(8))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        switch result {
        case .some(true): phase = .signedIn
        case .some(false):
            client.signOut()
            phase = .signedOut
        case .none:
            phase = .failed(L("サーバーに接続できませんでした（8秒）。電波の良い場所でもう一度お試しください。"))
        }
    }

    func signIn(email: String, password: String) async {
        await run {
            try await self.client.signIn(email: email, password: password)
            self.phase = .signedIn
        }
    }

    func signUp(email: String, password: String) async {
        await run {
            let signedIn = try await self.client.signUp(email: email, password: password)
            if signedIn {
                self.phase = .signedIn
            } else {
                self.infoMessage = L("確認メールを送りました。メールのリンクを開いて登録を完了したら、このアプリに戻って「ログイン」してください。")
                self.awaitingConfirmation = true
            }
        }
    }

    func resetPassword(email: String) async {
        await run {
            try await self.client.sendPasswordReset(email: email)
            self.infoMessage = L("パスワード設定用のメールを送りました。")
        }
    }

    // MARK: - Google / Apple through the web's sign-in (`/native-auth`)

    /// Lovable Cloud's Google and Apple sign-in go through Lovable's own OAuth window, which an app cannot
    /// reach directly. The app opens the web's `/native-auth` in a secure browser sheet; the web signs in
    /// exactly as on the web (so it is the SAME account) and hands the session back to
    /// `catchwords://auth-callback#access_token=…&refresh_token=…&state=…` (web native-auth.ts).
    func browserSignInRequest(provider: String) -> (url: URL, state: String)? {
        let state = Self.randomState()
        guard var c = URLComponents(url: AppConfig.webBaseURL.appendingPathComponent("native-auth"), resolvingAgainstBaseURL: false) else { return nil }
        c.queryItems = [URLQueryItem(name: "provider", value: provider), URLQueryItem(name: "state", value: state)]
        guard let url = c.url else { return nil }
        return (url, state)
    }

    /// Accepts the handed-back session only when it carries the `state` this app made (anything else
    /// could have been injected from outside).
    func completeBrowserSignIn(_ callback: URL, state: String) async {
        let f = Self.fragmentFields(callback)
        guard f["state"] == state, let access = f["access_token"], !access.isEmpty,
              let refresh = f["refresh_token"], !refresh.isEmpty else {
            errorMessage = L("ログインに失敗しました。もう一度お試しください。")
            Haptics.warning()
            return
        }
        var expiresIn: Double? = f["expires_in"].flatMap { Double($0) }
        if expiresIn == nil, let at = f["expires_at"].flatMap({ Double($0) }) { expiresIn = at - Date().timeIntervalSince1970 }
        await run {
            try await self.client.adoptSession(accessToken: access, refreshToken: refresh, expiresIn: expiresIn)
            self.isGuest = false
            self.phase = .signedIn
        }
    }

    nonisolated static func fragmentFields(_ url: URL) -> [String: String] {
        guard let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment else { return [:] }
        var c = URLComponents()
        c.query = fragment
        var out: [String: String] = [:]
        for item in c.queryItems ?? [] {
            if let v = item.value { out[item.name] = v }
        }
        return out
    }

    /// Tries a Supabase anonymous session (so saving works); falls back to a local-only guest entry.
    func enterAsGuest() async {
        do {
            try await client.signInAnonymously()
            isGuest = false
        } catch {
            print("[Auth] anonymous sign-in unavailable, entering local guest mode")
            isGuest = true
        }
        errorMessage = nil
        phase = .signedIn
    }

    func signOut() {
        client.signOut()
        isGuest = false
        phase = .signedOut
    }

    private func run(_ work: @escaping () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        infoMessage = nil
        awaitingConfirmation = false
        defer { isBusy = false }
        do {
            try await work()
            Haptics.success()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? L("エラーが発生しました。")
            Haptics.warning()
        }
    }

    /// The web accepts 16–128 of [A-Za-z0-9_.-] (sanitizeNativeState).
    private static func randomState(length: Int = 40) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        return String((0..<length).map { _ in chars.randomElement() ?? "a" })
    }
}
