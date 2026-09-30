import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case dex, camera, settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .dex: "図鑑"
        case .camera: "カメラ"
        case .settings: "設定"
        }
    }

    var icon: String {
        switch self {
        case .dex: "book.closed"
        case .camera: "camera"
        case .settings: "gearshape"
        }
    }
}

/// Shared navigation state so the reward flight can open the dex and target the new cell.
@Observable
final class AppRouter {
    var tab: AppTab = .camera
    var landingStickerId: String?
    var detailSticker: Sticker?
    var showPaywall: Bool = false
}

struct MainTabView: View {
    @State private var router = AppRouter()

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch router.tab {
                case .dex: DexView()
                case .camera: CaptureView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CapsuleTabBar(selection: $router.tab, onCamera: router.tab == .camera)
                .padding(.bottom, 6)
        }
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

/// Floating capsule measured from the App Store tab bar (TabBar.tsx): 87.6% width, 55pt tall,
/// full-capsule corners, a bubble exactly one cell wide that slides between cells.
/// On the camera it becomes dark glass instead of a paper-like white strip.
struct CapsuleTabBar: View {
    @Binding var selection: AppTab
    var onCamera: Bool

    @Namespace private var bubble

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.876, 380)
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        guard selection != tab else { return }
                        Haptics.selection()
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { selection = tab }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: selection == tab ? tab.icon + ".fill" : tab.icon)
                                .font(.system(size: 19, weight: .semibold))
                                .frame(height: 21)
                            Text(tab.title).font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(selection == tab ? Theme.primary : (onCamera ? .white.opacity(0.75) : Theme.muted))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            if selection == tab {
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
            }
            .frame(width: width, height: 58)
            .background {
                if onCamera {
                    Capsule().fill(.black.opacity(0.45)).background(.ultraThinMaterial, in: Capsule())
                } else {
                    Capsule().fill(Theme.card.opacity(0.92))
                }
            }
            .overlay(Capsule().stroke(.white.opacity(onCamera ? 0.14 : 0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 58)
    }
}
