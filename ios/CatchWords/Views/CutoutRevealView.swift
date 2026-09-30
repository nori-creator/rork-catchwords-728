import SwiftUI

/// Cut-out mode, the moment the subject comes off the photo (shown once, right after the cut
/// finishes, in the same frame as the peel sticker so nothing jumps):
/// 1. a band of light scans down the photo (0.5 s),
/// 2. the background blurs, loses its colour and fades while the subject stays exactly where it was
///    (the lift is uncropped, so it lines up with the photo),
/// 3. the subject gets a white sticker edge and a glow and lifts slightly — then the peel sticker takes over.
struct CutoutRevealView: View {
    let lift: CutoutService.Lift
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scan: CGFloat = -0.2
    @State private var scanOpacity: Double = 0
    @State private var backgroundGone: Bool = false
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
                            .saturation(backgroundGone ? 0 : 1)
                            .blur(radius: backgroundGone ? 14 : 0)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: radius, style: .continuous))
                    .opacity(backgroundGone ? 0 : 1)
                    .scaleEffect(backgroundGone ? 0.96 : 1)

                // The subject, aligned with the photo, gaining a white edge as it lifts off.
                Color.clear.frame(width: inner, height: inner)
                    .overlay {
                        subject
                            .scaledToFill()
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: backgroundGone ? 0 : radius, style: .continuous))
                    .scaleEffect(lifted ? 1.05 : 1)
                    .shadow(color: Theme.cyan.opacity(lifted ? 0.55 : 0), radius: lifted ? 22 : 0)
                    .shadow(color: .black.opacity(lifted ? 0.25 : 0), radius: 12, y: lifted ? 14 : 0)

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

    /// A white sticker edge: the subject's silhouette in white, slightly larger, behind it.
    private var subject: some View {
        Image(uiImage: lift.full).resizable()
            .background {
                Image(uiImage: lift.full).resizable()
                    .colorMultiply(.black).colorInvert()
                    .scaleEffect(lifted ? 1.03 : 1)
                    .blur(radius: 0.6)
                    .opacity(lifted ? 1 : 0)
            }
    }

    private func run() async {
        if reduceMotion {
            backgroundGone = true
            lifted = true
            try? await Task.sleep(for: .milliseconds(300))
            onDone()
            return
        }
        withAnimation(.easeOut(duration: 0.12)) { scanOpacity = 1 }
        withAnimation(.easeInOut(duration: 0.55)) { scan = 1.2 }
        SoundService.shared.play(.slide, volume: 0.5)
        try? await Task.sleep(for: .milliseconds(420))
        withAnimation(.easeOut(duration: 0.2)) { scanOpacity = 0 }
        withAnimation(.easeInOut(duration: 0.45)) { backgroundGone = true }
        try? await Task.sleep(for: .milliseconds(260))
        Haptics.impact(.soft)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { lifted = true }
        try? await Task.sleep(for: .milliseconds(520))
        onDone()
    }
}
