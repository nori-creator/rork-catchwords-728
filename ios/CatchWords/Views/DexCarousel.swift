import QuartzCore
import SwiftUI

/// The dex "slide" view — the web's `DexCoverFlow` with `theme="gallery"` (R15): white cards turn on a ring
/// in a pale blue room, like choosing a card pack. The middle card faces you up front; the cards on either
/// side swing back along the ring (outer edge toward you) and the next ones peek, smaller, behind them.
/// The floor reflects each card, a light streak crosses a card's face as it passes the middle, and small
/// sparks blink in the air.
///
/// Position and pose are worked out from one number every frame (`CarouselSpring.value`, in cards), so the
/// ring follows the finger 1:1 and never lags a frame behind. On release it glides to the nearest card on a
/// spring that keeps the finger's speed (Apple's `.smooth`, or `.snappy` after a fast flick).
struct DexCoverFlow: View {
    @Environment(DexStore.self) private var dex
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stickers: [Sticker]
    let onOpen: (Sticker) -> Void
    /// The card first put in the middle (the simulator preview opens part-way along).
    var initialIndex = 0

    @State private var spring = CarouselSpring()
    @State private var dragFrom: Double?
    @State private var lastSlideSound: CFTimeInterval = 0
    @State private var muteSlideSound = false

    private var center: Int {
        guard !stickers.isEmpty else { return 0 }
        return max(0, min(stickers.count - 1, Int(spring.value.rounded())))
    }

    var body: some View {
        GeometryReader { geo in
            // Card width: big and up front, but the card, its reflection, the dots and the photo row
            // must stay clear of the tab bar (web: `--cf-w` for the gallery theme).
            let w = min(geo.size.width * 0.72, 310,
                        max(128, (geo.size.height - 16 - 24 - 64 - 120) / (1.48 * 1.18)))
            VStack(spacing: 0) {
                stage(width: geo.size.width, cardWidth: w)
                    .frame(height: 16 + w * 1.48 * 1.18)
                dots
                thumbnails
                Spacer(minLength: 0)
            }
        }
        .onChange(of: stickers.map(\.id)) { _, _ in
            // Filtered down to other cards: start again from the first, without the slide sound.
            muteSlideSound = true
            spring.set(0)
        }
        .onChange(of: center) { _, _ in
            if muteSlideSound { muteSlideSound = false; return }
            // A card reached the middle: the recorded "suh" (web: `el-gallery-slide`, gain 0.8), never closer
            // than 70ms so a fast flick past many cards doesn't jam.
            let now = CACurrentMediaTime()
            guard now - lastSlideSound >= 0.07 else { return }
            lastSlideSound = now
            SoundService.shared.play(.slide, volume: 0.8)
            Haptics.selection()
        }
        .onAppear {
            muteSlideSound = initialIndex > 0
            spring.set(Double(max(0, min(stickers.count - 1, initialIndex))))
        }
        .onDisappear { spring.stop() }
    }

    // MARK: Stage

    private func stage(width: CGFloat, cardWidth w: CGFloat) -> some View {
        let ch = w * 1.48
        let stageH = 16 + ch * 1.18
        let step = w * CarouselPose.step
        let pos = spring.value
        let range = visibleRange(around: pos)
        return ZStack(alignment: .topLeading) {
            // The white light pooled at the middle card's feet (no pedestal — R15).
            EllipticalGradient(colors: [.white.opacity(0.95), .white.opacity(0)], center: .center)
                .frame(width: w * 2.2, height: w * 0.5)
                .position(x: width / 2, y: 16 + ch - w * 0.12 + w * 0.25)
                .allowsHitTesting(false)
            ForEach(range, id: \.self) { i in
                // `stickers` can shrink (a delete) between computing the range and drawing it.
                if stickers.indices.contains(i) {
                    slot(i, pos: pos, stageWidth: width, stageHeight: stageH, cardWidth: w)
                }
            }
        }
        .frame(width: width, height: stageH, alignment: .topLeading)
        .contentShape(Rectangle())
        .clipped()
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { g in
                    if dragFrom == nil {
                        spring.stop()
                        dragFrom = spring.value
                    }
                    let maxPos = Double(max(0, stickers.count - 1))
                    var x = (dragFrom ?? 0) - g.translation.width / step
                    // Resistance past the ends instead of a hard stop.
                    if x < 0 { x = -Self.rubberband(-x, 2) } else if x > maxPos { x = maxPos + Self.rubberband(x - maxPos, 2) }
                    spring.set(x)
                }
                .onEnded { g in
                    dragFrom = nil
                    let pxPerSecond = -g.velocity.width
                    let v = pxPerSecond / step
                    let projected = spring.value + Self.projectMomentum(v)
                    let target = Double(max(0, min(stickers.count - 1, Int(projected.rounded()))))
                    if reduceMotion {
                        spring.set(target)
                    } else {
                        // Only a quick flick gets the slight overshoot (Apple's snappy).
                        spring.to(target, response: 0.5, damping: abs(pxPerSecond) > 600 ? 0.85 : 1, velocity: v)
                    }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: bring(center + 1)
            case .decrement: bring(center - 1)
            @unknown default: break
            }
        }
    }

    private func visibleRange(around pos: Double) -> [Int] {
        guard !stickers.isEmpty else { return [] }
        let lo = max(0, Int((pos - CarouselPose.reach).rounded(.down)))
        let hi = min(stickers.count - 1, Int((pos + CarouselPose.reach).rounded(.up)))
        return lo <= hi ? Array(lo...hi) : []
    }

    /// One card on the ring, projected like the web's `perspective: 1000px` (origin 50% / 45%).
    private func slot(_ i: Int, pos: Double, stageWidth: CGFloat, stageHeight: CGFloat, cardWidth w: CGFloat) -> some View {
        let s = stickers[i]
        let rel = Double(i) - pos
        let p = CarouselPose.pose(rel, reduced: reduceMotion)
        let ch = w * 1.48
        let perspective: CGFloat = 1000
        let z = p.z * w
        let scale = perspective / (perspective - z)
        let originY = stageHeight * 0.45
        let cardCenterY = 16 + ch / 2
        let isCenter = i == center
        // The streak sits off the right edge while the card rests in the middle and sweeps across its face
        // (right → left) only while it passes the middle — like foil catching the light.
        let sweep = 45 - min(1.2, abs(rel)) * 75
        return CarouselCard(sticker: s, width: w, sweep: sweep, mirror: abs(rel) <= 3)
            .contentShape(Rectangle())
            .onTapGesture {
                if isCenter { onOpen(s) } else { bring(i) }
            }
            .rotation3DEffect(.degrees(p.rotateY), axis: (x: 0, y: 1, z: 0), perspective: ch / perspective)
            .scaleEffect(scale)
            .position(x: stageWidth / 2 + p.x * w * scale, y: originY + (cardCenterY - originY) * scale)
            .opacity(p.opacity)
            .zIndex(p.zIndex)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(s.word?.headword ?? "") \(s.word?.meaningJa ?? "")")
            .accessibilityAddTraits(isCenter ? [.isButton, .isSelected] : .isButton)
    }

    private func bring(_ i: Int) {
        guard !stickers.isEmpty else { return }
        let j = Double(max(0, min(stickers.count - 1, i)))
        if reduceMotion { spring.set(j) } else { spring.to(j, response: 0.5, damping: 1) }
    }

    // MARK: Dots and photo row

    /// The blue dot shows how far along you are (web `progressDots`): first card → left end, last → right end.
    private var dots: some View {
        HStack(spacing: 2) {
            ForEach(Self.progressDots(count: stickers.count, index: center)) { d in
                Button { bring(d.i) } label: {
                    Circle()
                        .fill(d.active ? Theme.primary : Color.black.opacity(0.18))
                        .frame(width: 8, height: 8)
                        .scaleEffect(d.active ? 1.35 : 1)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.snappy(duration: 0.2), value: center)
        .padding(.top, 4)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var thumbnails: some View {
        if stickers.count >= 2 {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(Array(stickers.enumerated()), id: \.element.id) { i, s in
                            let path = s.objectImageUrl ?? s.cutoutImageUrl
                            Button { bring(i) } label: {
                                Color.black.opacity(0.05).frame(width: 48, height: 48)
                                    .overlay { StickerImage(path: path, url: dex.url(for: path), contentMode: .fill).allowsHitTesting(false) }
                                    .clipShape(.rect(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(i == center ? Theme.primary : .clear, lineWidth: 2))
                                    .opacity(i == center ? 1 : 0.6)
                                    .animation(.easeOut(duration: 0.2), value: center)
                            }
                            .buttonStyle(PressableStyle(scale: 0.92))
                            .accessibilityLabel(s.word?.headword ?? "")
                            .id(s.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .frame(height: 64)
                .onChange(of: center) { _, c in
                    guard stickers.indices.contains(c) else { return }
                    withAnimation(reduceMotion ? nil : .smooth) { proxy.scrollTo(stickers[c].id, anchor: .center) }
                }
            }
        }
    }

    // MARK: Math shared with the web (`lib/spring.ts`, `lib/cover-flow.ts`)

    /// Where a flick would coast to (Apple's deceleration, rate 0.998).
    static func projectMomentum(_ velocity: Double, rate: Double = 0.998) -> Double {
        velocity / 1000 * (rate / (1 - rate))
    }

    static func rubberband(_ overshoot: Double, _ dimension: Double, constant: Double = 0.55) -> Double {
        let d = max(dimension, 0.0001)
        return overshoot * d * constant / (d + constant * abs(overshoot))
    }

    struct Dot: Identifiable {
        let i: Int
        let active: Bool
        var id: Int { i }
    }

    static func progressDots(count: Int, index: Int, limit: Int = 7) -> [Dot] {
        guard count > 0 else { return [] }
        let cur = max(0, min(count - 1, index))
        if count <= limit { return (0..<count).map { Dot(i: $0, active: $0 == cur) } }
        let on = Int((Double(cur) / Double(count - 1) * Double(limit - 1)).rounded())
        return (0..<limit).map { k in
            Dot(i: Int((Double(k) / Double(limit - 1) * Double(count - 1)).rounded()), active: k == on)
        }
    }
}

/// Web `carouselPose`: the cards stand on an ellipse `RING_R` wide and `RING_DEPTH` deep (in card widths),
/// `RING_STEP` radians apart; the middle card is at the front (z = 0).
enum CarouselPose {
    static let radius = 1.0
    static let depth = 1.6
    static let angle = 0.78
    /// How far the middle card moves per card, so it sticks to the finger 1:1 (card widths).
    static let step = radius * angle
    /// Cards further round than this are behind the middle one and aren't drawn.
    static let reach = 3.4

    static func pose(_ offset: Double, reduced: Bool) -> (x: Double, z: Double, rotateY: Double, zIndex: Double, opacity: Double) {
        let o = max(-reach, min(reach, offset))
        let a = abs(o)
        let phi = o * angle
        return (
            x: radius * sin(phi),
            z: -depth * (1 - cos(phi)),
            // Turned slightly inward so the outer edge comes toward you; flat with reduced motion.
            rotateY: reduced ? 0 : -phi * 0.3 * 180 / .pi,
            // Nearer is on top; past 4 cards the order stops changing so it never flips.
            zIndex: 100 - (min(4, a) * 10).rounded(),
            // The far side of the ring (past 2 cards) slowly fades out.
            opacity: max(0, min(1, 1 - (a - 2.2) * 0.8))
        )
    }
}

/// A white card (photo, word with its reading, meaning, date and place), the light streak, and its
/// reflection on the floor.
private struct CarouselCard: View {
    @Environment(DexStore.self) private var dex
    let sticker: Sticker
    let width: CGFloat
    let sweep: Double
    let mirror: Bool

    private static let ink = Color(hex: 0x1D1D1F)
    private static let muted = Color(hex: 0x5F6B7D)

    var body: some View {
        face
            .overlay { gloss }
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(red: 40 / 255, green: 80 / 255, blue: 140 / 255).opacity(0.1), lineWidth: 1))
            .shadow(color: Color(red: 40 / 255, green: 70 / 255, blue: 120 / 255).opacity(0.08), radius: 3, y: 2)
            .shadow(color: Color(red: 40 / 255, green: 70 / 255, blue: 120 / 255).opacity(0.3), radius: 16, y: 18)
            .background(alignment: .top) {
                if mirror { reflection }
            }
    }

    private var face: some View {
        let s = sticker
        let path = s.objectImageUrl ?? s.cutoutImageUrl
        let h = width * 1.48
        return VStack(alignment: .leading, spacing: 0) {
            Color.black.opacity(0.05)
                .frame(width: width, height: h * 0.64)
                .overlay {
                    StickerImage(path: path, url: dex.url(for: path), contentMode: s.objectImageUrl == nil ? .fit : .fill)
                        .allowsHitTesting(false)
                }
                .clipped()
                .overlay(alignment: .topLeading) {
                    Text("\(Category.emoji(for: s.categoryKey)) \(Category.label(for: s.categoryKey))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    if let p = dex.memoryPercent(for: s) { MemoryBadge(percent: p).padding(8) }
                }
            VStack(alignment: .leading, spacing: 4) {
                ZhuyinWordView(headword: s.word?.headword ?? "", zhuyin: s.word?.readingZhuyin, size: 22, weight: .bold,
                               color: Self.ink, readingColor: Self.muted, pinyin: s.word?.pinyin)
                Text(s.word?.meaningJa ?? "").font(.system(size: 15)).foregroundStyle(Self.ink.opacity(0.9)).lineLimit(1)
                Spacer(minLength: 4)
                HStack(spacing: 6) {
                    Text(JPDate.monthDay(s.takenAt)).monospacedDigit()
                    if s.lat != nil || !(s.locationName ?? "").isEmpty {
                        Label {
                            LocalizedPlaceText(lat: s.lat, lng: s.lng, saved: s.locationName)
                        } icon: {
                            Image(systemName: "mappin")
                        }
                        .lineLimit(1)
                    }
                }
                .font(.system(size: 12)).foregroundStyle(Self.muted)
            }
            .padding(14)
            .frame(width: width, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: width, height: h)
        .background(.white)
    }

    /// The streak of light (web `.dex-cf__gloss`: 105°, white 55% → 14%, 2.2 card widths wide).
    private var gloss: some View {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0), location: 0.38),
                .init(color: .white.opacity(0.55), location: 0.47),
                .init(color: .white.opacity(0.14), location: 0.53),
                .init(color: .white.opacity(0), location: 0.62),
            ],
            startPoint: UnitPoint(x: 0, y: 0.37), endPoint: UnitPoint(x: 1, y: 0.63)
        )
        .frame(width: width * 2.2, height: width * 1.48 * 1.2)
        .offset(x: width * 2.2 * sweep / 100)
        .allowsHitTesting(false)
    }

    /// The card upside down under itself, faint at its feet and gone within a quarter of its height.
    private var reflection: some View {
        face
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
            .scaleEffect(x: 1, y: -1)
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .clear, location: 0.24)],
                                 startPoint: .top, endPoint: .bottom))
            .opacity(0.22)
            .offset(y: width * 1.48 + 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The pale blue room behind the slide view (web `.dex-cf[data-theme="gallery"] .dex-cf__backdrop` and its sparks).
struct DexGalleryBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// [left %, top %, delay s] — fixed places, never reshuffled.
    private static let sparks: [(Double, Double, Double)] = [
        (8, 14, 0), (22, 30, 1.6), (37, 9, 0.8), (52, 22, 2.4), (66, 12, 1.1), (81, 27, 0.3),
        (92, 8, 1.9), (14, 44, 2.8), (88, 46, 0.6), (30, 56, 2.1), (72, 58, 1.4), (46, 40, 3.1),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0xD6E3F5), location: 0),
                        .init(color: Color(hex: 0xE6EEFA), location: 0.34),
                        .init(color: Color(hex: 0xF4F8FD), location: 0.58),
                        .init(color: .white, location: 0.64),
                        .init(color: Color(hex: 0xE8F0FB), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                // radial-gradient(70% 22% at 50% 62%, white 95% → clear at 70%): the bright floor.
                Ellipse()
                    .fill(EllipticalGradient(colors: [.white.opacity(0.95), .white.opacity(0)], center: .center))
                    .frame(width: geo.size.width * 0.98, height: geo.size.height * 0.308)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.62)
                if reduceMotion {
                    ForEach(Self.sparks.indices, id: \.self) { k in
                        let sp = Self.sparks[k]
                        Spark(alpha: 0.6, dy: 0)
                            .position(x: geo.size.width * sp.0 / 100, y: geo.size.height * sp.1 / 100)
                    }
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        ZStack {
                            ForEach(Self.sparks.indices, id: \.self) { k in
                                let sp = Self.sparks[k]
                                let phase = Self.twinkle(((t - sp.2) / 4.2).truncatingRemainder(dividingBy: 1))
                                Spark(alpha: 0.95 * phase, dy: 4 - 7 * phase)
                                    .position(x: geo.size.width * sp.0 / 100, y: geo.size.height * sp.1 / 100)
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 0 → 1 at 45% of the 4.2s cycle → 0 (ease-in-out), like the web's `dex-cf-spark` keyframes.
    private static func twinkle(_ x: Double) -> Double {
        let f = x < 0 ? x + 1 : x
        let u = f < 0.45 ? f / 0.45 : (1 - f) / 0.55
        return u * u * (3 - 2 * u)
    }

    private struct Spark: View {
        let alpha: Double
        let dy: Double

        var body: some View {
            Circle()
                .fill(.white)
                .frame(width: 3, height: 3)
                .shadow(color: .white.opacity(0.9), radius: 4)
                .shadow(color: Color(red: 120 / 255, green: 170 / 255, blue: 1).opacity(0.35), radius: 8)
                .offset(y: dy)
                .opacity(alpha)
        }
    }
}

/// A spring driven every frame (web `createSpring`): Apple's response / damping, the speed carried over
/// from the finger, and retargetable mid-flight without a jump.
@MainActor @Observable
final class CarouselSpring: NSObject {
    /// Where the ring is, in cards (0 = the first card in the middle).
    var value: Double = 0

    @ObservationIgnored private var velocity: Double = 0
    @ObservationIgnored private var target: Double = 0
    @ObservationIgnored private var stiffness: Double = 0
    @ObservationIgnored private var friction: Double = 0
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var lastTime: CFTimeInterval = 0

    /// Put it there at once (following the finger, or with reduced motion).
    func set(_ v: Double) {
        stop()
        value = v
        velocity = 0
        target = v
    }

    func to(_ t: Double, response: Double, damping: Double, velocity v: Double? = nil) {
        target = t
        if let v { velocity = v }
        let omega = 2 * Double.pi / max(0.05, response)
        stiffness = omega * omega
        friction = 2 * damping * omega
        guard link == nil else { return }
        lastTime = CACurrentMediaTime()
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stop() {
        link?.invalidate()
        link = nil
        velocity = 0
    }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        var dt = min(1.0 / 20, max(0, now - lastTime))
        lastTime = now
        var x = value
        var v = velocity
        // Small fixed steps keep the spring stable at any frame rate.
        while dt > 0 {
            let h = min(dt, 1.0 / 240)
            let a = -stiffness * (x - target) - friction * v
            v += a * h
            x += v * h
            dt -= h
        }
        if abs(x - target) < 0.0005, abs(v) < 0.005 {
            value = target
            stop()
            return
        }
        velocity = v
        value = x
    }
}
