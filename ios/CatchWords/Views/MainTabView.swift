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
}

struct MainTabView: View {
    @State private var router = AppRouter()

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
        .environment(router)
        .sheet(item: $router.detailSticker) { sticker in
            WordDetailView(sticker: sticker)
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
        }
        .fullScreenCover(isPresented: $router.showPaywall) {
            PaywallView()
        }
    }
}

/// TabBar.tsx: floating capsule (87.6% width, ~55pt, full-capsule corners), a bubble exactly one
/// cell wide that slides between cells, and the camera as a raised blue disc in the centre.
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

    private func cell(_ tab: AppTab) -> some View {
        let isOn = selection == tab
        return Button { select(tab) } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 19, weight: .regular))
                    .frame(height: 21)
                Text(tab.title).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isOn ? Theme.primary : (onCamera ? .white.opacity(0.8) : Theme.foreground.opacity(0.75)))
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

    /// The camera cell: a raised disc on other tabs; on the camera itself it lies flat in the bar.
    private var cameraCell: some View {
        let isOn = selection == .camera
        return Button { select(.camera) } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isOn {
                        Image(systemName: "camera")
                            .font(.system(size: 19))
                            .foregroundStyle(Theme.primary)
                    } else {
                        Circle()
                            .fill(Theme.primary)
                            .frame(width: 50, height: 50)
                            .shadow(color: Theme.primary.opacity(0.45), radius: 10, y: 4)
                            .overlay(Image(systemName: "camera").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white))
                            .offset(y: -14)
                    }
                }
                .frame(height: 21)
                Text("カメラ").font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isOn ? Theme.primary : (onCamera ? .white.opacity(0.8) : Theme.foreground.opacity(0.75)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .accessibilityLabel("カメラ")
    }

    private func select(_ tab: AppTab) {
        guard selection != tab else { return }
        Haptics.selection()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { selection = tab }
    }
}
