import SwiftUI

/// Holographic trading-card look (owner: "gyroscope tilt hologram"): a Metal foil (`holoFoil` in
/// `Effects.metal`) whose rainbow bands, sheen and glitter move with the light, a soft glare, and — for
/// `holoCard` — the card itself turning a few degrees as the phone tilts (`MotionService`), or as a finger
/// drags it where there is no motion sensor (the simulator).
extension View {
    /// The foil and glare alone, for a given tilt (-1...1 on both axes). Drawn over the view and clipped to
    /// `cornerRadius`; the view underneath should be opaque (the dodge layer blends with what is below it).
    /// `intensity` 0 draws nothing.
    func holographic(tilt: CGPoint, intensity: Double = 1, cornerRadius: CGFloat = 0) -> some View {
        modifier(HolographicFoil(tilt: tilt, intensity: intensity, cornerRadius: cornerRadius))
    }

    /// A holo card: the foil plus a gentle 3D turn (up to `maxAngle` degrees) driven by the phone's tilt.
    /// Only an `isActive` card reads the sensor and draws the foil, so a row of cards can keep one modifier
    /// each (same view structure, no reloads) while only one of them shines.
    /// - extraTilt: added to the tilt (e.g. the carousel's slide, so the foil moves while you swipe).
    /// - allowsDragTilt: finger-drag tilt when the sensor isn't delivering; turn off where the card sits
    ///   in another drag (a carousel, a swipeable pager).
    func holoCard(isActive: Bool = true, cornerRadius: CGFloat, intensity: Double = 1, maxAngle: Double = 10,
                  allowsDragTilt: Bool = true, extraTilt: CGPoint = .zero) -> some View {
        modifier(HoloCardModifier(isActive: isActive, cornerRadius: cornerRadius, intensity: intensity,
                                  maxAngle: maxAngle, allowsDragTilt: allowsDragTilt, extraTilt: extraTilt))
    }
}

/// A card container with the holo treatment — the same as `.holoCard(...)` on the content.
struct HoloCard<Content: View>: View {
    var isActive: Bool
    var cornerRadius: CGFloat
    var intensity: Double
    var maxAngle: Double
    var allowsDragTilt: Bool
    let content: Content

    init(isActive: Bool = true, cornerRadius: CGFloat = 16, intensity: Double = 1, maxAngle: Double = 10,
         allowsDragTilt: Bool = true, @ViewBuilder content: () -> Content) {
        self.isActive = isActive
        self.cornerRadius = cornerRadius
        self.intensity = intensity
        self.maxAngle = maxAngle
        self.allowsDragTilt = allowsDragTilt
        self.content = content()
    }

    var body: some View {
        content.holoCard(isActive: isActive, cornerRadius: cornerRadius, intensity: intensity,
                         maxAngle: maxAngle, allowsDragTilt: allowsDragTilt)
    }
}

/// Three layers over the content: the rainbow in colour-dodge (brightens the picture, leaves white paper
/// white), a glare where the light falls, and a faint pastel wash with the glitter so white parts shimmer too.
struct HolographicFoil: ViewModifier {
    let tilt: CGPoint
    let intensity: Double
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let on = intensity > 0.001
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .overlay {
                if on {
                    foil(pass: 0).clipShape(shape).blendMode(.colorDodge)
                }
            }
            .overlay {
                if on {
                    // The glare sits on the same "light line" the shader brightens.
                    EllipticalGradient(colors: [.white.opacity(0.26 * min(1, intensity)), .white.opacity(0)],
                                       center: UnitPoint(x: 0.5 + tilt.x * 0.5, y: 0.5 + tilt.y * 0.5),
                                       startRadiusFraction: 0, endRadiusFraction: 0.75)
                        .clipShape(shape)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                if on {
                    foil(pass: 1).clipShape(shape)
                }
            }
    }

    private func foil(pass: Double) -> some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.white)
                .colorEffect(ShaderLibrary.holoFoil(.float2(proxy.size.width, proxy.size.height),
                                                    .float2(tilt.x, tilt.y),
                                                    .float(intensity),
                                                    .float(pass)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Reads the shared motion only while active, so the 60 Hz tilt redraws just this modifier — never the card
/// content inside it, and never the inactive cards.
struct HoloCardModifier: ViewModifier {
    let isActive: Bool
    let cornerRadius: CGFloat
    let intensity: Double
    let maxAngle: Double
    let allowsDragTilt: Bool
    let extraTilt: CGPoint

    @Environment(\.appReduceMotion) private var reduceMotion
    @State private var acquired = false
    @State private var drag: CGPoint = .zero

    private var motion: MotionService { MotionService.shared }

    func body(content: Content) -> some View {
        let t = currentTilt
        let mag = min(1, (t.x * t.x + t.y * t.y).squareRoot())
        // Turn about the axis at right angles to the tilt; a still card keeps a valid axis (a zero axis would
        // make the transform NaN and the card vanish).
        let axis: (x: CGFloat, y: CGFloat, z: CGFloat) = mag > 0.0001
            ? (x: -t.y / mag, y: t.x / mag, z: 0)
            : (x: 0, y: 1, z: 0)
        return content
            .holographic(tilt: t, intensity: isActive ? intensity : 0, cornerRadius: cornerRadius)
            .rotation3DEffect(.degrees(Double(mag) * maxAngle), axis: axis, perspective: 0.7)
            .simultaneousGesture(dragTilt, including: dragEnabled ? .all : .subviews)
            .onAppear { syncMotion() }
            .onDisappear { releaseMotion() }
            .onChange(of: isActive) { _, _ in syncMotion() }
            .onChange(of: reduceMotion) { _, _ in syncMotion() }
    }

    /// Sensor tilt (when live) + finger tilt + the caller's extra, clamped to -1...1.
    private var currentTilt: CGPoint {
        guard isActive, !reduceMotion else { return .zero }
        let m = motion.isLive ? motion.tilt : .zero
        return CGPoint(x: Self.clamp(m.x + drag.x + extraTilt.x), y: Self.clamp(m.y + drag.y + extraTilt.y))
    }

    private var dragEnabled: Bool {
        isActive && allowsDragTilt && !reduceMotion && !motion.isLive
    }

    private var dragTilt: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { g in
                drag = CGPoint(x: Self.clamp(g.translation.width / 120), y: Self.clamp(g.translation.height / 120))
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { drag = .zero }
            }
    }

    private func syncMotion() {
        let want = isActive && !reduceMotion
        if want && !acquired {
            acquired = true
            motion.acquire()
        } else if !want {
            releaseMotion()
        }
    }

    private func releaseMotion() {
        guard acquired else { return }
        acquired = false
        motion.release()
        drag = .zero
    }

    private static func clamp(_ v: CGFloat) -> CGFloat { max(-1, min(1, v)) }
}
