import SwiftUI
import AuthenticationServices
import CryptoKit

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

    /// Development only: enter the app without logging in. Set to false before App Store release.
    static let devSkipLogin: Bool = true
    /// True while inside the app without a real account (guest mode).
    var isGuest: Bool = false

    private let client = SupabaseClient.shared
    private var currentNonce: String?

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
            phase = .failed("サーバーに接続できませんでした（8秒）。電波の良い場所でもう一度お試しください。")
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
                self.infoMessage = "確認メールを送りました。メールのリンクを開いて登録を完了したら、このアプリに戻って「ログイン」してください。"
                self.awaitingConfirmation = true
            }
        }
    }

    func resetPassword(email: String) async {
        await run {
            try await self.client.sendPasswordReset(email: email)
            self.infoMessage = "パスワード設定用のメールを送りました。"
        }
    }

    func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.email, .fullName]
        request.nonce = Self.sha256(nonce)
    }

    func completeApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "Appleでのログインに失敗しました。"
            }
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Appleでのログインに失敗しました。"
                return
            }
            await run {
                try await self.client.signInWithApple(idToken: token, nonce: nonce)
                self.phase = .signedIn
            }
        }
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
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "エラーが発生しました。"
            Haptics.warning()
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in chars.randomElement() ?? "a" })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
