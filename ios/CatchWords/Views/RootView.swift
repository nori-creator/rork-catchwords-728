import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(DexStore.self) private var dex
    @Environment(PlanStore.self) private var plan
    @Environment(ProfileStore.self) private var profile
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(OnboardingState.doneKey) private var onboardingDone: Bool = false

    private var needsOnboarding: Bool {
        !onboardingDone && profile.isLoaded && !profile.loadFailed && !profile.onboarded && dex.stickers.isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground()
            switch auth.phase {
            case .checking:
                SplashView()
                    .transition(.opacity)
            case .signedOut:
                AuthView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .signedIn:
                ZStack {
                    MainTabView()
                    if needsOnboarding {
                        OnboardingView { withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { onboardingDone = true } }
                            .environment(\.colorScheme, .light)
                            .transition(.opacity.combined(with: .scale(scale: 1.02)))
                            .zIndex(1)
                    }
                }
                    .transition(.opacity)
                    .task {
                        async let p: Void = profile.load()
                        await dex.load()
                        await p
                        await plan.bootstrap()
                        await ReminderService.loadFromAccount()
                        await ReminderService.refresh(due: dex.upcomingDueTimes)
                    }
            case .failed(let reason):
                ConnectionFailedView(reason: reason) {
                    Task { await auth.bootstrap() }
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.9), value: auth.phase)
        .task { await auth.bootstrap() }
        .onChange(of: auth.phase) { _, phase in
            if phase == .signedOut { dex.reset() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in auth.sessionExpired() }
        // Meanings and notes follow the display language too (read again in the new one).
        .onChange(of: LanguageState.shared.lang) { _, _ in
            dex.readerLanguageChanged()
            // Scheduled reminders were written in the old language: write them again (N1).
            Task { await ReminderService.refresh(due: dex.upcomingDueTimes) }
        }
        .onChange(of: scenePhase) { _, phase in
            // おまかせ reminders follow yesterday's first open and the cards coming due.
            guard phase == .active, auth.phase == .signedIn else { return }
            if profile.loadFailed { Task { await profile.load() } }
            ReminderService.recordAppOpen()
            Task { await ReminderService.refresh(due: dex.upcomingDueTimes) }
        }
    }
}

struct SplashView: View {
    @State private var breathe: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            LogoMark(size: 88)
                .scaleEffect(breathe ? 1.04 : 0.98)
            ProgressView().tint(Theme.muted)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

struct ConnectionFailedView: View {
    let reason: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.muted)
            Text(reason)
                .font(.system(size: 15))
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.center)
            PrimaryButton(title: L("もう一度試す"), icon: "arrow.clockwise", action: retry)
                .frame(maxWidth: 260)
        }
        .padding(32)
    }
}

/// The app's interlocking-loop mark, drawn natively (matches the icon).
struct LogoMark: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Theme.brandGradient)
            HStack(spacing: -size * 0.16) {
                Circle().stroke(.white, lineWidth: size * 0.07).frame(width: size * 0.4)
                Circle().stroke(.white, lineWidth: size * 0.07).frame(width: size * 0.4)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.primary.opacity(0.5), radius: size * 0.25, y: size * 0.08)
    }
}
