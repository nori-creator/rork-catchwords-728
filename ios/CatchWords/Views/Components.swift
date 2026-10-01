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

/// Atmosphere: near-white paper with a faint blue light pool (never a flat fill).
struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(colors: [Theme.primary.opacity(0.07), .clear], center: .topTrailing, startRadius: 10, endRadius: 460)
            RadialGradient(colors: [Theme.accent.opacity(0.5), .clear], center: .bottomLeading, startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

/// memory-badge.ts: colour + number only (the level name lives in the accessibility label).
struct MemoryBadge: View {
    let percent: Int

    static func level(_ p: Int) -> Int {
        if p < 30 { return 0 }
        if p < 50 { return 1 }
        if p < 70 { return 2 }
        if p < 85 { return 3 }
        if p < 95 { return 4 }
        return 5
    }

    static var labels: [String] { [L("忘れかけ"), L("あやうい"), L("うろ覚え"), L("薄れぎみ"), L("覚えている"), L("はっきり")] }

    var body: some View {
        let lv = Self.level(percent)
        let c = Theme.memoryLevels[lv]
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 6, height: 6)
            Text("\(percent)%")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(c.mix(with: Theme.foreground, by: 0.4))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Theme.card.opacity(0.94), in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.labels[lv]) \(percent)%")
    }
}

/// Pure memory math from srs.ts (retentionNow / stabilityOf).
nonisolated enum MemoryMath {
    private static let k: Double = 1 / (2.5 * log(1 / 0.9))

    static func stability(intervalDays: Int, ease: Double) -> Double {
        max(0.5, Double(max(1, intervalDays)) * max(1, ease) * k)
    }

    static func percent(intervalDays: Int, ease: Double, last: Date?, now: Date = Date()) -> Int {
        guard let last else { return 100 }
        let dt = now.timeIntervalSince(last) / 86_400
        guard dt > 0 else { return 100 }
        let stability = max(0.5, Double(max(1, intervalDays)) * max(1, ease) * k)
        return Int((max(0, min(100, 100 * exp(-dt / stability)))).rounded())
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

/// A saved place in the current display language (the name saved at capture time can be in another one).
struct LocalizedPlaceText: View {
    let lat: Double?
    let lng: Double?
    let saved: String?
    var fallback: String = ""
    @State private var name: String?

    private var savedName: String? { saved.flatMap { $0.isEmpty ? nil : $0 } }

    var body: some View {
        // With coordinates the saved name (maybe another language) is never shown; the lookup replaces it.
        Text(name ?? (lat == nil ? savedName : nil) ?? fallback)
            .task(id: "\(lat ?? 0),\(lng ?? 0),\(L10n.lang)") {
                name = await LocationService.shared.localizedName(lat: lat, lng: lng, saved: savedName)
            }
    }
}
