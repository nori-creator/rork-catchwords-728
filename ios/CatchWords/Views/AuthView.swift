import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(AuthStore.self) private var auth

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSignUp: Bool = false
    @State private var showMail: Bool = false
    @State private var appeared: Bool = false
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
                    SignInWithAppleButton(.signIn) { req in
                        auth.prepareApple(req)
                    } onCompletion: { result in
                        Task { await auth.completeApple(result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .clipShape(.rect(cornerRadius: 16))

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showMail.toggle() }
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

                    if showMail { mailForm.transition(.opacity.combined(with: .move(edge: .top))) }

                    if let msg = auth.errorMessage {
                        Label(msg, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let msg = auth.infoMessage {
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ok)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                    withAnimation(.snappy) { isSignUp.toggle() }
                }
                Spacer()
                if !isSignUp {
                    Button(L("パスワードを忘れた")) {
                        Task { await auth.resetPassword(email: email) }
                    }
                    .disabled(email.isEmpty)
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
