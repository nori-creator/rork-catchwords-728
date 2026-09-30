import SwiftUI

/// Cut-out mode, the moment the subject comes off the photo. Shown once, right after the cut
/// finishes, in the same frame as the peel sticker so nothing jumps.
///
/// 1. A band of light scans down the photo.
/// 2. A glowing line traces round the subject's outline, like scissors (Metal shader `outline`),
///    with a fine Core Haptics buzz that follows it.
/// 3. The background breaks into light dust from the top down (Metal shader `dissolve`) while the
///    subject stays exactly where it was — the lift is uncropped, so it lines up with the photo.
/// 4. The trace becomes a solid white sticker edge; the sticker tilts up off the page with a
///    soft-then-round haptic, and the peel sticker takes over.
struct CutoutRevealView: View {
    let lift: CutoutService.Lift
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scan: CGFloat = -0.2
    @State private var scanOpacity: Double = 0
    @State private var trace: Double = 0
    @State private var dissolve: Double = 0
    @State private var solid: Double = 0
    @State private var edge: Double = 2.5
    @State private var lifted: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let inner = side * 280 / 320
            let radius = 22 * side / 320
            ZStack {
                // The photo (background). Same fill/clip as PeelStickerView so the first frame matches.
                Color.clear.frame(width: inner, height: inner)
                    .overlay {
                        Image(uiImage: lift.photo).resizable().scaledToFill()
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: radius, style: .continuous))
                    .modifier(DissolveEffect(progress: dissolve))

                // The subject, aligned with the photo, with its outline traced then made solid.
                Color.clear.frame(width: inner, height: inner)
                    .overlay {
                        Image(uiImage: lift.full).resizable().scaledToFill()
                            .allowsHitTesting(false)
                            .modifier(OutlineEffect(progress: trace, width: edge, solid: solid))
                    }
                    .clipped()
                    .shadow(color: Theme.cyan.opacity(lifted ? 0.45 : 0), radius: lifted ? 20 : 0)
                    .shadow(color: .black.opacity(lifted ? 0.28 : 0), radius: 14, y: lifted ? 16 : 0)
                    .scaleEffect(lifted ? 1.06 : 1)
                    .rotation3DEffect(.degrees(lifted ? 7 : 0), axis: (x: 1, y: -0.4, z: 0), perspective: 0.6)

                // Scan band.
                LinearGradient(colors: [.clear, Theme.cyan.opacity(0.35), .white.opacity(0.9), Theme.cyan.opacity(0.35), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: inner, height: inner * 0.22)
                    .offset(y: (scan - 0.5) * inner)
                    .blendMode(.plusLighter)
                    .opacity(scanOpacity)
                    .frame(width: inner, height: inner)
                    .clipShape(.rect(cornerRadius: radius, style: .continuous))
                    .allowsHitTesting(false)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("切り抜いています")
        .task { await run() }
    }

    private func run() async {
        if reduceMotion {
            trace = 1; solid = 1; edge = 6; dissolve = 1; lifted = true
            try? await Task.sleep(for: .milliseconds(300))
            onDone()
            return
        }
        // 1. scan
        withAnimation(.easeOut(duration: 0.12)) { scanOpacity = 1 }
        withAnimation(.easeInOut(duration: 0.55)) { scan = 1.2 }
        SoundService.shared.play(.slide, volume: 0.45)
        try? await Task.sleep(for: .milliseconds(200))
        // 2. scissors round the outline
        HapticPatterns.shared.trace(duration: 0.8)
        withAnimation(.easeInOut(duration: 0.8)) { trace = 1 }
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.easeOut(duration: 0.25)) { scanOpacity = 0 }
        try? await Task.sleep(for: .milliseconds(450))
        // 3. the background breaks into light
        withAnimation(.easeIn(duration: 0.55)) { dissolve = 1 }
        try? await Task.sleep(for: .milliseconds(350))
        // 4. solid white edge, lift off the page
        HapticPatterns.shared.lift()
        Haptics.impact(.soft)
        withAnimation(.easeOut(duration: 0.25)) { solid = 1; edge = 6 }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { lifted = true }
        try? await Task.sleep(for: .milliseconds(420))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { lifted = false }
        try? await Task.sleep(for: .milliseconds(260))
        onDone()
    }
}

/// `dissolve` shader, animatable (SwiftUI interpolates `progress` frame by frame).
struct DissolveEffect: ViewModifier, Animatable {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let p = Float(progress)
        return content.visualEffect { view, proxy in
            view.colorEffect(ShaderLibrary.dissolve(.float2(proxy.size.width, proxy.size.height), .float(p)),
                             isEnabled: p > 0)
        }
    }
}

/// `outline` shader, animatable: traces (progress), then becomes a solid sticker edge (solid → 1).
struct OutlineEffect: ViewModifier, Animatable {
    var progress: Double
    var width: Double
    var solid: Double
    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { .init(progress, .init(width, solid)) }
        set {
            progress = newValue.first
            width = newValue.second.first
            solid = newValue.second.second
        }
    }

    func body(content: Content) -> some View {
        let p = Float(progress), w = Float(width), s = Float(solid)
        return content.visualEffect { view, proxy in
            view.layerEffect(
                ShaderLibrary.outline(.float2(proxy.size.width, proxy.size.height), .float(p), .float(w), .float(s)),
                maxSampleOffset: CGSize(width: CGFloat(w) + 1, height: CGFloat(w) + 1),
                isEnabled: p > 0
            )
        }
    }
}
