import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case home, dex, camera, review, settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: "ホーム"
        case .dex: "図鑑"
        case .camera: "カメラ"
        case .review: "復習"
        case .settings: "設定"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .dex: "book"
        case .camera: "camera"
        case .review: "sparkles"
        case .settings: "gearshape"
        }
    }
}

/// Shared navigation state so the reward flight can open the dex and target the new cell.
@Observable
final class AppRouter {
    var tab: AppTab = .home
    var landingStickerId: String?
    var detailSticker: Sticker?
    var showPaywall: Bool = false
    /// True while the camera "machine" (live preview / selfie / analyzing) fills the screen.
    var cameraImmersive: Bool = true
    /// Analyzing and the reward stage take the whole screen (no tab bar).
    var tabBarHidden: Bool = false
    /// First-run tour over the real screens (FirstCatchFlow's experience steps).
    var tour: TourStep = .off
    /// The word caught during the tour (used by the Dex / word / review steps).
    var tourStickerId: String?

    func advanceTour(from step: TourStep, to next: TourStep) {
        guard tour == step else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { tour = next }
    }
}

struct MainTabView: View {
    @State private var router = AppRouter()
    @Environment(DexStore.self) private var dex
    @AppStorage(TourStep.pendingKey) private var tourPending: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch router.tab {
                case .home: HomeView()
                case .dex: DexView()
                case .camera: CaptureView()
                case .review: ReviewView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !router.tabBarHidden {
                CapsuleTabBar(selection: $router.tab, onCamera: router.tab == .camera && router.cameraImmersive)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: router.tabBarHidden)
        .overlayPreferenceValue(TourAnchorKey.self) { anchors in
            if router.tour != .off, router.tour != .word, router.tour != .complete, !router.tabBarHidden {
                TourLayer(step: router.tour, anchors: anchors, onNext: tourNext, onSkip: endTour)
                    .transition(.opacity)
            }
        }
        .overlay {
            if router.tour == .complete {
                TourCompleteView(sticker: router.tourStickerId.flatMap { dex.sticker(id: $0) }) { endTour() }
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(3)
            }
        }
        .environment(router)
        .sheet(item: $router.detailSticker, onDismiss: {
            // 「ことば」を見終えたら復習へ（Web: StickerSheet の onClose → review）。
            if router.tour == .word { startTourReview() }
        }) { sticker in
            WordDetailView(sticker: sticker)
                .environment(router)
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
                .overlay(alignment: .bottom) {
                    if router.tour == .word {
                        TourCoachCard(step: .word, onNext: { router.detailSticker = nil }, onSkip: endTour)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }
        }
        .onAppear { beginTourIfPending() }
        .onChange(of: tourPending) { _, _ in beginTourIfPending() }
        .onChange(of: router.tab) { _, tab in
            if tab == .camera { router.advanceTour(from: .tapCamera, to: .shoot) }
        }
        .onChange(of: router.detailSticker) { _, s in
            if s != nil { router.advanceTour(from: .dexOpen, to: .word) }
        }
        .fullScreenCover(isPresented: $router.showPaywall) {
            PaywallView()
        }
    }

    private func beginTourIfPending() {
        guard tourPending, router.tour == .off else { return }
        router.tab = .home
        withAnimation(.easeOut(duration: 0.3)) { router.tour = .home }
    }

    private func tourNext() {
        switch router.tour {
        case .home: router.advanceTour(from: .home, to: .tapCamera)
        case .detail: router.advanceTour(from: .detail, to: .peel)
        case .added: router.advanceTour(from: .added, to: .dexTypes)
        case .dexOpen:
            if let id = router.tourStickerId, let s = dex.sticker(id: id) { router.detailSticker = s } else { startTourReview() }
        case .review: router.advanceTour(from: .review, to: .reviewPick)
        default: break
        }
    }

    private func startTourReview() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
            router.tour = .review
            router.tab = .review
        }
    }

    private func endTour() {
        tourPending = false
        router.detailSticker = nil
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
            router.tour = .off
            router.tab = .home
        }
    }
}

/// TabBar.tsx: floating capsule (87.6% width, ~55pt, full-capsule corners), a bubble exactly one
/// cell wide that slides between cells. The camera sits in the same row, same size (blue icon).
/// On the camera it becomes dark glass instead of a paper-like white strip.
struct CapsuleTabBar: View {
    @Binding var selection: AppTab
    var onCamera: Bool

    @Namespace private var bubble

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.92, 400)
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    if tab == .camera {
                        cameraCell
                    } else {
                        cell(tab)
                    }
                }
            }
            .frame(width: width, height: 58)
            .background {
                if onCamera {
                    Capsule().fill(Theme.navyDeep.opacity(0.55)).background(.ultraThinMaterial, in: Capsule())
                } else {
                    Capsule().fill(.white.opacity(0.9)).background(.regularMaterial, in: Capsule())
                }
            }
            .overlay(Capsule().stroke(onCamera ? .white.opacity(0.12) : Theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(onCamera ? 0.35 : 0.1), radius: 16, y: 6)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 58)
        .animation(.easeInOut(duration: 0.25), value: onCamera)
    }

    private func cell(_ tab: AppTab, iconColor: Color? = nil) -> some View {
        let isOn = selection == tab
        let tint = isOn ? Theme.primary : (onCamera ? .white.opacity(0.8) : Theme.foreground.opacity(0.75))
        return Button { select(tab) } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 19, weight: .regular))
                    .frame(height: 21)
                    .foregroundStyle(isOn ? Theme.primary : (iconColor ?? tint))
                Text(tab.title).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isOn {
                    Capsule()
                        .fill(Theme.primary.opacity(onCamera ? 0.22 : 0.14))
                        .matchedGeometryEffect(id: "bubble", in: bubble)
                        .padding(4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .accessibilityLabel(tab.title)
    }

    /// The camera cell: the same size and height as every other tab, in one row
    /// (owner request 2026-09-30: no raised disc). The icon stays blue so it is still easy to find.
    private var cameraCell: some View {
        cell(.camera, iconColor: Theme.primary)
            .tourAnchor(.cameraTab)
    }

    private func select(_ tab: AppTab) {
        guard selection != tab else { return }
        Haptics.selection()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { selection = tab }
    }
}
