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
    @Environment(\.colorScheme) private var colorScheme
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
                    // Google and Apple go through the web app's sign-in (same account as the web).
                    Button {
                        Task { await auth.signInWithWeb(provider: "google") }
                    } label: {
                        HStack(spacing: 10) {
                            GoogleMark(size: 20)
                            Text(L("Googleで続ける")).scaledFont(size: 17, weight: .semibold)
                        }
                        .foregroundStyle(Color(hex: 0x1F1F1F))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(.white, in: .rect(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0x747775), lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(auth.isBusy)
                    .accessibilityIdentifier("auth.google")

                    if AppConfig.nativeAppleSignIn {
                        SignInWithAppleButton(.signIn) { req in
                            auth.prepareApple(req)
                        } onCompletion: { result in
                            Task { await auth.completeApple(result) }
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)  // HIG: white on a dark screen
                        .frame(height: 54)
                        .clipShape(.rect(cornerRadius: 16))
                    } else {
                        Button {
                            Task { await auth.signInWithWeb(provider: "apple") }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "apple.logo").scaledFont(size: 20, weight: .medium)
                                Text(L("Appleでサインイン")).scaledFont(size: 19, weight: .medium)
                            }
                            .foregroundStyle(colorScheme == .dark ? .black : .white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(colorScheme == .dark ? Color.white : Color.black, in: .rect(cornerRadius: 16))
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(auth.isBusy)
                        .accessibilityIdentifier("auth.apple")
                    }

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showMail.toggle() }
                        if showMail {
                            Task { try? await Task.sleep(for: .milliseconds(350)); focused = .email }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                            Text(L("メールアドレスで続ける")).scaledFont(size: 17, weight: .semibold)
                        }
                        .foregroundStyle(Theme.foreground)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .glassCard(16)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("auth.mail")

                    if showMail { mailForm.offset(x: shake).transition(.opacity.combined(with: .move(edge: .top))) }

                    if let msg = auth.errorMessage {
                        Label(msg, systemImage: "exclamationmark.circle.fill")
                            .scaledFont(size: 13)
                            .foregroundStyle(Theme.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if let msg = auth.infoMessage {
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .scaledFont(size: 13)
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

                Text(L("Web版（catchwords.lovable.app）と同じアカウントで、集めた単語と写真がそのまま使えます。"))
                    .scaledFont(size: 12)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)

                // Consent to the terms and the privacy policy is given by continuing (both pages are links).
                Text(LegalLinks.signInAgreement())
                    .scaledFont(size: 12)
                    .foregroundStyle(Theme.muted)
                    .tint(Theme.primaryInk)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("auth.agreement")

                HStack(spacing: 16) {
                    Link(L("利用規約"), destination: AppConfig.termsURL)
                    Link(L("プライバシー"), destination: AppConfig.privacyURL)
                }
                .scaledFont(size: 12, weight: .medium)
                .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .statusBarScrim()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.05)) { appeared = true }
        }
    }

    private var hero: some View {
        VStack(spacing: 18) {
            LogoMark(size: 96)
            VStack(spacing: 6) {
                Text("CatchWords")
                    .scaledFont(size: 34, weight: .bold, design: .rounded)
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
                .accessibilityIdentifier("auth.email")
            SecureField("", text: $password, prompt: Text(L("パスワード")).foregroundStyle(Theme.muted))
                .textContentType(isSignUp ? .newPassword : .password)
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)
                .fieldStyle()
                .accessibilityIdentifier("auth.password")
            PrimaryButton(title: isSignUp ? L("新規登録") : L("ログイン"), isLoading: auth.isBusy, action: submit)
                .disabled(trimmedEmail.isEmpty || password.isEmpty)
                .accessibilityIdentifier("auth.submit")
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
                        Task { await auth.resetPassword(email: trimmedEmail) }
                    }
                    .buttonStyle(PressableStyle(scale: 0.97))
                    .disabled(trimmedEmail.isEmpty)
                    .transition(.opacity)
                }
            }
            .scaledFont(size: 13, weight: .medium)
            .foregroundStyle(Theme.primary)
            .frame(minHeight: 44)
            if AuthStore.devSkipLogin {
                Button {
                    Task { await auth.enterAsGuest() }
                } label: {
                    Label(L("ログインせずに入る（開発用）"), systemImage: "arrow.right.circle")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    /// AutoFill and the keyboard's suggestion bar can leave a space at either end of the address.
    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func submit() {
        // The keyboard's Go key works even while the button is greyed out.
        guard !trimmedEmail.isEmpty, !password.isEmpty, !auth.isBusy else { return }
        focused = nil
        let mail = trimmedEmail
        Task {
            if isSignUp {
                await auth.signUp(email: mail, password: password)
            } else {
                await auth.signIn(email: mail, password: password)
            }
        }
    }
}

/// Google's four-colour "G", drawn so no image asset is needed (Google sign-in branding).
private struct GoogleMark: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            arc(from: 45, to: 135, color: Color(hex: 0x34A853))   // green (bottom)
            arc(from: 135, to: 215, color: Color(hex: 0xFBBC05))  // yellow (left)
            arc(from: 215, to: 315, color: Color(hex: 0xEA4335))  // red (top)
            arc(from: 315, to: 360, color: Color(hex: 0x4285F4))  // blue (right, upper)
            Rectangle()
                .fill(Color(hex: 0x4285F4))
                .frame(width: size * 0.5, height: size * 0.2)
                .offset(x: size * 0.22, y: 0)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func arc(from a: Double, to b: Double, color: Color) -> some View {
        Circle()
            .trim(from: a / 360, to: b / 360)
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.2, lineCap: .butt))
            .frame(width: size * 0.8, height: size * 0.8)
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .scaledFont(size: 16)
            .foregroundStyle(Theme.foreground)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Theme.secondary, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}
