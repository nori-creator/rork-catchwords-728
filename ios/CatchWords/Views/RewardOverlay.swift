import SwiftUI

/// Save runs in parallel with the animation; the 1s hold waits here (catch-reward.md 幕3 "関所").
@Observable
final class SaveGate {
    var result: Result<SaveOutcome, Error>?
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func finish(_ r: Result<SaveOutcome, Error>) {
        result = r
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }

    func wait(timeout: Duration = .seconds(20)) async {
        if result != nil { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await withCheckedContinuation { cont in
                    if self.result != nil { cont.resume() } else { self.waiters.append(cont) }
                }
            }
            group.addTask { try? await Task.sleep(for: timeout) }
            await group.next()
            group.cancelAll()
        }
        if result == nil {
            waiters.forEach { $0.resume() }
            waiters.removeAll()
        }
    }

    var isReencounter: Bool {
        if case .success(.reencounter) = result { return true }
        return false
    }
}

struct RewardPayload {
    let image: UIImage
    let isCutout: Bool
    let headword: String
    let reading: String
    let pinyin: String
    let meaning: String
    /// 0...1 — rarer words get a slightly bigger lift and deeper dim (1.00–1.25×, never the bloom size).
    let rarity: Double
    let gate: SaveGate
}

/// Ported choreography (catch-choreography.ts / v5_physics):
/// 幕0 anticipation 110ms → 幕1 launch (y 0.30/0.72, x 0.44/0.92 → arc) → 幕2 bloom (0.46/0.86)
/// → word + voice + medium haptic at bloom → 幕3 exactly 1000ms breathing hold (also waits for save)
/// → 幕4 exit with initial velocity → 幕5 slam into the dex cell (handled by DexView).
struct RewardOverlay: View {
    let payload: RewardPayload
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dim: Double = 0
    @State private var scaleX: CGFloat = 1
    @State private var scaleY: CGFloat = 1
    @State private var scale: CGFloat = 0.62
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 60
    @State private var tilt: Double = 0
    @State private var shadowDrop: CGFloat = 8
    @State private var wordVisible: Bool = false
    @State private var wordBlur: CGFloat = 14
    @State private var readingGlow: Bool = false
    @State private var addedVisible: Bool = false
    @State private var ringProgress: CGFloat = 0
    @State private var ringOpacity: Double = 0
    @State private var shock: CGFloat = 0.2
    @State private var shockOpacity: Double = 0
    @State private var breathe: Bool = false
    @State private var sweep: CGFloat = -1
    @State private var particles: Bool = false
    @State private var exiting: Bool = false

    private var boost: CGFloat { 1 + CGFloat(payload.rarity) * 0.25 }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width * 0.82, 360)
            ZStack {
                Color.black.opacity(dim).ignoresSafeArea()
                RadialGradient(colors: [Theme.primary.opacity(0.45 * dim), .clear], center: .center, startRadius: 20, endRadius: geo.size.width)
                    .ignoresSafeArea()

                // Shockwave: a thin ring that passes once (no white flash).
                Circle()
                    .stroke(Theme.cyan.opacity(0.9), lineWidth: 2)
                    .frame(width: side, height: side)
                    .scaleEffect(shock)
                    .opacity(shockOpacity)
                    .offset(y: -geo.size.height * 0.06)

                // Converging light ring (charge) — not a gauge, no looping.
                Circle()
                    .trim(from: 0, to: 1 - ringProgress)
                    .stroke(LinearGradient(colors: [Theme.cyan, .white], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: side * 1.05, height: side * 1.05)
                    .rotationEffect(.degrees(-90 + Double(ringProgress) * 300))
                    .opacity(ringOpacity)
                    .offset(y: -geo.size.height * 0.06)

                ParticleBurst(active: particles)
                    .frame(width: side * 1.6, height: side * 1.6)
                    .offset(y: -geo.size.height * 0.06)

                VStack(spacing: 22) {
                    photo(side: side)
                    wordBlock
                }
                .offset(y: -geo.size.height * 0.02)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(true)
        .task { await run() }
    }

    private func photo(side: CGFloat) -> some View {
        ZStack {
            // Lagging shadow: stays low and blurs as the object climbs.
            Ellipse()
                .fill(.black.opacity(0.45))
                .frame(width: side * 0.6, height: side * 0.1)
                .blur(radius: shadowDrop * 0.8)
                .offset(y: side * 0.5 + shadowDrop)
                .scaleEffect(1 + shadowDrop / 120)

            Group {
                if payload.isCutout {
                    Image(uiImage: payload.image).resizable().scaledToFit()
                } else {
                    Color.clear
                        .overlay { Image(uiImage: payload.image).resizable().scaledToFill().allowsHitTesting(false) }
                        .clipShape(.rect(cornerRadius: 28))
                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.25), lineWidth: 1))
                }
            }
            .frame(width: side, height: side)
            .overlay {
                GeometryReader { g in
                    LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.3)
                        .rotationEffect(.degrees(20))
                        .offset(x: sweep * g.size.width * 1.3)
                        .blendMode(.plusLighter)
                }
                .mask {
                    if payload.isCutout {
                        Image(uiImage: payload.image).resizable().scaledToFit()
                    } else {
                        RoundedRectangle(cornerRadius: 28)
                    }
                }
                .allowsHitTesting(false)
            }
            .shadow(color: Theme.primary.opacity(0.55), radius: 30)
        }
        .scaleEffect(x: scale * scaleX * (breathe ? 1.005 : 0.995), y: scale * scaleY * (breathe ? 1.005 : 0.995))
        .rotationEffect(.degrees(tilt))
        .offset(x: offsetX, y: offsetY)
    }

    private var wordBlock: some View {
        VStack(spacing: 6) {
            Text(payload.reading)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(readingGlow ? Theme.cyan : .white.opacity(0.7))
                .shadow(color: Theme.cyan.opacity(readingGlow ? 0.9 : 0), radius: 8)
            Text(payload.headword)
                .font(.system(size: 54, weight: .heavy))
                .foregroundStyle(.white)
                .blur(radius: wordBlur)
                .shadow(color: Theme.primary.opacity(0.8), radius: 18)
            Text(payload.meaning)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Label(payload.gate.isReencounter ? "再会！写真を追加しました" : "図鑑に追加",
                  systemImage: payload.gate.isReencounter ? "arrow.triangle.2.circlepath" : "checkmark.seal.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(payload.gate.isReencounter ? Theme.gold : Theme.ok)
                .padding(.top, 6)
                .opacity(addedVisible ? 1 : 0)
                .scaleEffect(addedVisible ? 1 : 0.8)
        }
        .opacity(wordVisible ? 1 : 0)
        .offset(y: wordVisible ? 0 : 18)
        .opacity(exiting ? 0 : 1)
    }

    // MARK: Timeline

    private func run() async {
        if reduceMotion {
            // Reduced motion: no movement, but the word, reading and voice are all still shown.
            scale = 1; offsetY = 0; dim = 0.82
            wordVisible = true; wordBlur = 0; addedVisible = true
            SoundService.shared.speak(payload.headword)
            Haptics.success()
            await payload.gate.wait()
            try? await Task.sleep(for: .milliseconds(1200))
            onFinish()
            return
        }

        // 幕0 grip / anticipation — squash with volume preserved, light haptic, contact sound.
        Haptics.impact(.light)
        SoundService.shared.play(.slide, volume: 0.6)
        withAnimation(.easeOut(duration: 0.11)) {
            scaleY = 0.945; scaleX = 1.055; offsetY = 65
        }
        try? await Task.sleep(for: .milliseconds(100))

        // 幕1 launch — targets set BEFORE the squash settles; different responses per axis draw the arc.
        withAnimation(.spring(response: 0.30, dampingFraction: 0.72)) { offsetY = -40 * boost; scaleY = 1.06; scaleX = 0.95 }
        withAnimation(.spring(response: 0.44, dampingFraction: 0.92)) { offsetX = 14 }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) { scale = 0.72 * boost }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { tilt = -3.2 }
        withAnimation(.easeOut(duration: 0.44)) { shadowDrop = 40; dim = 0.55 * Double(boost) }
        try? await Task.sleep(for: .milliseconds(180))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { scaleX = 1; scaleY = 1; tilt = 0; offsetX = 0 }

        // Charge — ring converges, image compresses 2–3% like a spring.
        withAnimation(.easeIn(duration: 0.22)) { ringOpacity = 1 }
        withAnimation(.easeInOut(duration: 0.5)) { ringProgress = 1 }
        try? await Task.sleep(for: .milliseconds(380))
        withAnimation(.easeIn(duration: 0.14)) { scale *= 0.975 }
        try? await Task.sleep(for: .milliseconds(140))
        // 80–120ms full stop before the release.
        try? await Task.sleep(for: .milliseconds(95))

        // 幕2 break + bloom — one big release, single shockwave; heavy haptic lands ~30ms later.
        withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) { scale = 1; offsetY = -10 }
        withAnimation(.easeOut(duration: 0.2)) { ringOpacity = 0; dim = min(0.9, 0.82 * Double(boost)) }
        shockOpacity = 0.9
        withAnimation(.easeOut(duration: 0.7)) { shock = 2.6; shockOpacity = 0 }
        particles = true
        SoundService.shared.play(.impact)
        try? await Task.sleep(for: .milliseconds(30))
        Haptics.impact(.heavy)

        // At ~90% of bloom: voice + word + medium haptic + light sweep on the SAME frame.
        try? await Task.sleep(for: .milliseconds(190))
        SoundService.shared.speak(payload.headword)
        Haptics.impact(.medium)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { wordVisible = true }
        withAnimation(.easeOut(duration: 0.55)) { wordBlur = 0 }
        withAnimation(.easeInOut(duration: 0.8)) { sweep = 1.2 }
        SoundService.shared.play(.sting, volume: 0.55)

        // 幕3 hold — exactly 1000ms, never fully frozen (0.5% breath, 2.6s period). Also the save gate.
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { breathe = true }
        try? await Task.sleep(for: .milliseconds(420))
        withAnimation(.easeOut(duration: 0.5)) { readingGlow = true }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { addedVisible = payload.gate.result != nil }
        try? await Task.sleep(for: .milliseconds(580))
        await payload.gate.wait()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { addedVisible = true }
        if payload.gate.isReencounter { Haptics.success() }
        try? await Task.sleep(for: .milliseconds(250))

        // 幕4 exit — thrown upward at full speed from frame one (explicit initial velocity), no bounce.
        SoundService.shared.play(.bookOpen, volume: 0.8)
        withAnimation(.easeOut(duration: 0.15)) { exiting = true }
        withAnimation(.interpolatingSpring(mass: 1, stiffness: 340, damping: 37, initialVelocity: 8)) {
            offsetY = -900
            scale = 0.34
        }
        withAnimation(.easeIn(duration: 0.34)) { dim = 0 }
        try? await Task.sleep(for: .milliseconds(340))
        onFinish()
    }
}

/// Stars and motes that pop once at the break (burst-star / rewardParticle).
struct ParticleBurst: View {
    let active: Bool

    private struct Particle: Identifiable {
        let id: Int
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let color: Color
        let isStar: Bool
    }

    private let particles: [Particle] = (0..<22).map { i in
        Particle(
            id: i,
            angle: Double(i) / 22 * 360 + Double.random(in: -8...8),
            distance: CGFloat.random(in: 0.32...0.5),
            size: CGFloat.random(in: 5...12),
            color: [Theme.cyan, Theme.gold, .white, Theme.primary][i % 4],
            isStar: i % 3 == 0
        )
    }

    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(particles) { p in
                    Group {
                        if p.isStar {
                            Image(systemName: "sparkle").font(.system(size: p.size * 1.6, weight: .bold))
                        } else {
                            Circle().frame(width: p.size, height: p.size)
                        }
                    }
                    .foregroundStyle(p.color)
                    .offset(x: active ? cos(p.angle * .pi / 180) * r * p.distance : 0,
                            y: active ? sin(p.angle * .pi / 180) * r * p.distance : 0)
                    .scaleEffect(active ? 0.3 : 1)
                    .opacity(active ? 0 : 1)
                    .animation(.easeOut(duration: Double.random(in: 0.7...1.1)), value: active)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .opacity(active ? 1 : 0)
        }
        .allowsHitTesting(false)
    }
}
