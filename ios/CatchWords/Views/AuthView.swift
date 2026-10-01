import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(AuthStore.self) private var auth

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSignUp: Bool = false
    @State private var showMail: Bool = false
    @State private var appeared: Bool = false
    /// Nudges the form sideways when sign-in fails, like a head shake.
    @State private var shake: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.webAuthenticationSession) private var webAuth
    @FocusState private var focused: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 60)
                hero
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)

                VStack(spacing: 12) {
                    providerButton(provider: "apple")
                    providerButton(provider: "google")

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showMail.toggle() }
                        if showMail {
                            Task { try? await Task.sleep(for: .milliseconds(350)); focused = .email }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                            Text(L("メールアドレスで続ける")).font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(Theme.foreground)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .glassCard(16)
                    }
                    .buttonStyle(PressableStyle())

                    if showMail { mailForm.offset(x: shake).transition(.opacity.combined(with: .move(edge: .top))) }

                    if let msg = auth.errorMessage {
                        Label(msg, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if let msg = auth.infoMessage {
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ok)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        if auth.awaitingConfirmation {
                            PrimaryButton(title: L("確認が終わったので、ログインする"), icon: "arrow.right") {
                                withAnimation(.snappy) {
                                    isSignUp = false
                                    showMail = true
                                    auth.awaitingConfirmation = false
                                    auth.infoMessage = nil
                                }
                                focused = .password
                            }
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: auth.errorMessage)
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: auth.infoMessage)
                .onChange(of: auth.errorMessage) { _, msg in
                    guard msg != nil, !reduceMotion else { return }
                    Task {
                        for x in [12.0, -10, 7, -4, 0] {
                            withAnimation(.spring(response: 0.08, dampingFraction: 0.4)) { shake = x }
                            try? await Task.sleep(for: .milliseconds(60))
                        }
                    }
                }

                Text(L("Web版（catchwords.lovable.app）と同じアカウントで、集めた単語と写真がそのまま使えます。\nGoogleで登録した方は、ログイン画面の「パスワードを忘れた」から同じアカウントにパスワードを設定できます。"))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Link(L("利用規約"), destination: URL(string: "https://catchwords.lovable.app/terms")!)
                    Link(L("プライバシー"), destination: URL(string: "https://catchwords.lovable.app/privacy")!)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.05)) { appeared = true }
        }
    }

    /// Apple / Google: the web's own sign-in in a secure browser sheet (see AuthStore.browserSignInRequest).
    /// Apple's look for its button (black, Apple logo); Google's white button with its "G".
    private func providerButton(provider: String) -> some View {
        let isApple = provider == "apple"
        return Button {
            signInWithBrowser(provider)
        } label: {
            HStack(spacing: 8) {
                if isApple {
                    Image(systemName: "apple.logo").font(.system(size: 19, weight: .semibold))
                } else {
                    Text("G").font(.system(size: 20, weight: .bold, design: .rounded))  // l10n-ignore (Google's mark)
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0x4285F4), Color(hex: 0x34A853), Color(hex: 0xFBBC05), Color(hex: 0xEA4335)],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                Text(isApple ? L("Appleでサインイン") : L("Googleで続ける")).font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(isApple ? Color.white : Color.black.opacity(0.85))
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(isApple ? Color.black : Color.white, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(isApple ? 0 : 0.15), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .disabled(auth.isBusy)
        .accessibilityIdentifier("auth.\(provider)")
    }

    private func signInWithBrowser(_ provider: String) {
        guard let start = auth.browserSignInRequest(provider: provider) else { return }
        auth.errorMessage = nil
        Task {
            do {
                // An ephemeral sheet: never silently reuses whichever account Safari is signed in with.
                let callback = try await webAuth.authenticate(using: start.url, callbackURLScheme: "catchwords",
                                                             preferredBrowserSession: .ephemeral)
                await auth.completeBrowserSignIn(callback, state: start.state)
            } catch let e as ASWebAuthenticationSessionError where e.code == .canceledLogin {
                // The learner closed the sheet: nothing to report.
            } catch {
                auth.errorMessage = L("ログインに失敗しました。もう一度お試しください。")
                Haptics.warning()
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 18) {
            LogoMark(size: 96)
            VStack(spacing: 6) {
                Text("CatchWords")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.foreground)
                Text(L("街で見つけた物が、学びたい言葉になる。"))
                    .font(AppFont.hand(18))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var mailForm: some View {
        VStack(spacing: 10) {
            TextField("", text: $email, prompt: Text(L("メールアドレス")).foregroundStyle(Theme.muted))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused, equals: .email)
                .submitLabel(.next)
                .onSubmit { focused = .password }
                .fieldStyle()
            SecureField("", text: $password, prompt: Text(L("パスワード")).foregroundStyle(Theme.muted))
                .textContentType(isSignUp ? .newPassword : .password)
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)
                .fieldStyle()
            PrimaryButton(title: isSignUp ? L("新規登録") : L("ログイン"), isLoading: auth.isBusy, action: submit)
            HStack {
                Button(isSignUp ? L("ログインに切り替え") : L("新規登録はこちら")) {
                    Haptics.selection()
                    withAnimation(.snappy) { isSignUp.toggle() }
                }
                .buttonStyle(PressableStyle(scale: 0.97))
                .contentTransition(.opacity)
                Spacer()
                if !isSignUp {
                    Button(L("パスワードを忘れた")) {
                        Task { await auth.resetPassword(email: email) }
                    }
                    .buttonStyle(PressableStyle(scale: 0.97))
                    .disabled(email.isEmpty)
                    .transition(.opacity)
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.primary)
            .frame(minHeight: 44)
            if AuthStore.devSkipLogin {
                Button {
                    Task { await auth.enterAsGuest() }
                } label: {
                    Label(L("ログインせずに入る（開発用）"), systemImage: "arrow.right.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func submit() {
        focused = nil
        Task {
            if isSignUp {
                await auth.signUp(email: email, password: password)
            } else {
                await auth.signIn(email: email, password: password)
            }
        }
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .font(.system(size: 16))
            .foregroundStyle(Theme.foreground)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Theme.secondary, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}
