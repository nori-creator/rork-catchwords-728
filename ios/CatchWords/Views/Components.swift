import SwiftUI

/// Sinks on touch-DOWN (not release) and springs back — apple-design §14 as used across the web app.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.impact(.light, intensity: 0.6) }
            }
    }
}

/// Primary CTA with the slow sheen every 3.4s (catch-cta-sheen).
struct PrimaryButton: View {
    let title: String
    var icon: String?
    var isLoading: Bool = false
    var sheen: Bool = false
    let action: () -> Void

    @State private var sheenPhase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let icon {
                    Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                }
                Text(title).font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Theme.brandGradient)
            .overlay {
                if sheen && !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(colors: [.clear, .white.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.35)
                            .rotationEffect(.degrees(18))
                            .offset(x: sheenPhase * geo.size.width * 1.4)
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: Theme.primary.opacity(0.45), radius: 16, y: 8)
        }
        .buttonStyle(PressableStyle())
        .disabled(isLoading)
        .task(id: sheen) {
            guard sheen, !reduceMotion else { return }
            while !Task.isCancelled {
                sheenPhase = -1
                withAnimation(.easeInOut(duration: 1.1)) { sheenPhase = 1 }
                try? await Task.sleep(for: .seconds(3.4))
            }
        }
    }
}

/// Atmosphere: deep navy with soft blue light pools (never a flat fill).
struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(colors: [Theme.primary.opacity(0.22), .clear], center: .topTrailing, startRadius: 10, endRadius: 420)
            RadialGradient(colors: [Theme.cyan.opacity(0.08), .clear], center: .bottomLeading, startRadius: 10, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

/// Loads a sticker photo by storage path through the signed-URL map + cache.
struct StickerImage: View {
    let path: String?
    let url: URL?
    var contentMode: ContentMode = .fit

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                Color.clear
            }
        }
        .task(id: path) {
            guard let path else { return }
            if let hit = ImageCache.shared.image(for: path) { image = hit; return }
            guard let url else { return }
            let loaded = await ImageCache.shared.load(url: url, key: path)
            withAnimation(.easeOut(duration: 0.25)) { image = loaded }
        }
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.muted)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

struct CardSurface<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(.rect(cornerRadius: Theme.radius + 4))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius + 4).stroke(Theme.border, lineWidth: 1))
    }
}

/// Glass fallback for iOS < 26.
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color = .clear

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }
}

extension View {
    func glassCard(_ radius: CGFloat, tint: Color = .clear) -> some View {
        modifier(GlassBackground(cornerRadius: radius, tint: tint))
    }
}
