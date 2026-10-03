import SwiftUI

// Particles, bokeh and the full-screen light layers of the card-catch flow (prototype: burst / glints /
// trail / fxLoop, bokeh / bkLoop, .starlight, .catbg, .halo, .aiglow, .spark, #flash).

/// `#fx`: confetti and star sparks in design points, stepped once per 1/60 s like the prototype's rAF loop.
final class CCParticles {
    private struct P {
        var star: Bool
        var x: Double, y: Double, vx: Double, vy: Double
        var r: Double, vr: Double, w: Double, h: Double
        var color: Color
        var life: Double, decay: Double, g: Double
        var delay: Int
    }

    private static let colors: [Color] = [Color(hex: 0x8FD8FF), Color(hex: 0xB9A4FF), Color(hex: 0xFFD27A),
                                          Color(hex: 0xFF9ED2), Color(hex: 0x9FF0C0), Color(hex: 0xFFFFFF)]
    private var parts: [P] = []
    private var last: Double?
    private var acc = 0.0
    var calm = false

    var isEmpty: Bool { parts.isEmpty }

    /// `burst(x, y, {n, speed, up, g, stars})`.
    func burst(_ x: Double, _ y: Double, n: Int = 70, speed: Double = 7, up: Double = 3, g: Double = 0.16, stars: Double = 0.45) {
        guard !calm else { return }
        for i in 0..<n {
            let a = Double.random(in: 0..<1) * .pi * 2
            let v = speed * (0.3 + Double.random(in: 0..<1) * 0.9)
            let isStar = Double.random(in: 0..<1) < stars
            parts.append(P(star: isStar, x: x, y: y, vx: cos(a) * v, vy: sin(a) * v - up,
                           r: Double.random(in: 0..<1) * 6, vr: (Double.random(in: 0..<1) - 0.5) * 0.35,
                           w: isStar ? 5 + Double.random(in: 0..<1) * 9 : 4 + Double.random(in: 0..<1) * 5,
                           h: 2.5 + Double.random(in: 0..<1) * 3, color: Self.colors[i % Self.colors.count],
                           life: 1, decay: 0.006 + Double.random(in: 0..<1) * 0.008, g: g, delay: 0))
        }
    }

    /// `glints(rect, n)`.
    func glints(_ rect: CGRect, n: Int = 12) {
        guard !calm else { return }
        for _ in 0..<n {
            parts.append(P(star: true, x: rect.minX + Double.random(in: 0..<1) * rect.width,
                           y: rect.minY + Double.random(in: 0..<1) * rect.height, vx: 0, vy: -0.12, r: 0, vr: 0,
                           w: 6 + Double.random(in: 0..<1) * 9, h: 0, color: .white, life: 1,
                           decay: 0.013 + Double.random(in: 0..<1) * 0.018, g: 0, delay: Int(Double.random(in: 0..<1) * 40)))
        }
    }

    /// `trail(x, y)`: two small sparks.
    func trail(_ x: Double, _ y: Double) {
        guard !calm else { return }
        for _ in 0..<2 {
            parts.append(P(star: true, x: x + (Double.random(in: 0..<1) - 0.5) * 20, y: y + (Double.random(in: 0..<1) - 0.5) * 20,
                           vx: (Double.random(in: 0..<1) - 0.5) * 0.8, vy: (Double.random(in: 0..<1) - 0.5) * 0.8, r: 0, vr: 0,
                           w: 4 + Double.random(in: 0..<1) * 7, h: 0,
                           color: Double.random(in: 0..<1) < 0.5 ? .white : Color(hex: 0xFFE7A3),
                           life: 1, decay: 0.035, g: 0, delay: 0))
        }
    }

    func advance(to now: Double) {
        guard let l = last else { last = now; return }
        acc += min(0.25, now - l)
        last = now
        while acc >= 1.0 / 60 {
            acc -= 1.0 / 60
            step()
        }
    }

    private func step() {
        parts.removeAll { $0.life <= 0 }
        for i in parts.indices {
            if parts[i].delay > 0 { parts[i].delay -= 1; continue }
            parts[i].life -= parts[i].decay
            parts[i].vy += parts[i].g
            parts[i].vx *= 0.982; parts[i].vy *= 0.982
            parts[i].x += parts[i].vx; parts[i].y += parts[i].vy
            parts[i].r += parts[i].vr
        }
    }

    /// `star(g, x, y, s)`: an 8-point polygon, inner radius .22.
    private static func starPath(_ x: Double, _ y: Double, _ s: Double) -> Path {
        var p = Path()
        for i in 0..<8 {
            let a = Double(i) * .pi / 4, r = i % 2 == 1 ? s * 0.22 : s
            let pt = CGPoint(x: x + cos(a) * r, y: y + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    func draw(_ ctx: inout GraphicsContext) {
        for p in parts where p.delay <= 0 && !p.star && p.life > 0 {
            var c = ctx
            c.opacity = max(0, min(1, p.life * 1.4))
            c.translateBy(x: p.x, y: p.y)
            c.rotate(by: .radians(p.r))
            c.scaleBy(x: 1, y: cos(p.r * 2.3))
            c.fill(Path(CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h)), with: .color(p.color))
        }
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: .rgba(255, 245, 200, 0.95), radius: 5))
            for p in parts where p.delay <= 0 && p.star && p.life > 0 {
                var c = layer
                c.opacity = max(0, min(1, p.life * 1.4))
                c.fill(Self.starPath(p.x, p.y, p.w * (0.35 + 0.65 * sin(p.life * .pi))), with: .color(p.color))
            }
        }
    }
}

/// `#bokeh`: 26 soft coloured discs drifting up (none when calm).
final class CCBokeh {
    private struct B { var x: Double; var y: Double; let r: Double; let v: Double; let h: Double; let a: Double; let p: Double }
    private var items: [B] = []
    private var last: Double?
    private var acc = 0.0

    func start(calm: Bool) {
        guard items.isEmpty, !calm else { return }
        let hues: [Double] = [200, 260, 320, 45, 170]
        items = (0..<26).map { _ in
            B(x: Double.random(in: 0..<1) * 390, y: Double.random(in: 0..<1) * 844, r: 6 + Double.random(in: 0..<1) * 26,
              v: 0.1 + Double.random(in: 0..<1) * 0.35, h: hues[Int(Double.random(in: 0..<1) * 5)],
              a: 0.08 + Double.random(in: 0..<1) * 0.16, p: Double.random(in: 0..<1) * 6)
        }
        last = nil
    }

    func stop() { items = [] }

    func draw(_ ctx: inout GraphicsContext, now: Double) {
        if let l = last {
            acc += min(0.25, now - l)
            while acc >= 1.0 / 60 {
                acc -= 1.0 / 60
                for i in items.indices {
                    items[i].y -= items[i].v
                    if items[i].y < -40 { items[i].y = 844 + 40; items[i].x = Double.random(in: 0..<1) * 390 }
                }
            }
        }
        last = now
        let t = now * 1000
        for b in items {
            let a = b.a * (0.6 + 0.4 * sin(t / 900 + b.p))
            let g = Gradient(stops: [.init(color: .hsla(b.h, 1, 0.85, a), location: 0),
                                     .init(color: .hsla(b.h, 1, 0.75, a * 0.5), location: 0.7),
                                     .init(color: .hsla(b.h, 1, 0.70, 0), location: 1)])
            ctx.fill(Path(ellipseIn: CGRect(x: b.x - b.r, y: b.y - b.r, width: b.r * 2, height: b.r * 2)),
                     with: .radialGradient(g, center: CGPoint(x: b.x, y: b.y), startRadius: 0, endRadius: b.r))
        }
    }
}

/// `.starlight` (mkStar): a white four-point star with a warm glow, twinkling (`twk` .45 s alternate), and
/// a second smaller star turned 45° behind it.
struct CCStarlight: View {
    var size: CGFloat = 50
    let now: Double
    let calm: Bool

    var body: some View {
        // twk: scale .85 ↔ 1.12, ease-in-out, alternate
        let tw: Double = {
            guard !calm else { return 1 }
            let cyc = now.truncatingRemainder(dividingBy: 0.9) / 0.45
            let f = cyc < 1 ? cyc : 2 - cyc
            return 0.85 + (1.12 - 0.85) * CCBezier.easeInOut(f)
        }()
        ZStack {
            glow(CCSVGPath(d: CCIcons.star).fill(.white))
                .frame(width: size, height: size)
                .scaleEffect(tw)
            glow(CCSVGPath(d: CCIcons.star).fill(.white))
                .frame(width: size * 0.56, height: size * 0.56)
                .rotationEffect(.degrees(45))
                .opacity(0.85)
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }

    /// drop-shadow(0 0 3px #fff) drop-shadow(0 0 9px #FFE7A3) drop-shadow(0 0 16px rgba(160,200,255,.9))
    private func glow<V: View>(_ v: V) -> some View {
        v.shadow(color: .white, radius: 1.5)
            .shadow(color: Color(hex: 0xFFE7A3), radius: 4.5)
            .shadow(color: .rgba(160, 200, 255, 0.9), radius: 8)
    }
}

/// A `repeating-conic-gradient(from ang at c, color 0 on°, transparent on° period°)` drawn as wedges.
private func ccRays(_ ctx: inout GraphicsContext, center c: CGPoint, radius: Double, from ang: Double, on: Double, period: Double, color: Color) {
    var p = Path()
    var a = 0.0
    while a < 360 {
        // CSS conic angles start at 12 o'clock and run clockwise.
        let s = (ang + a - 90) * .pi / 180, e = (ang + a + on - 90) * .pi / 180
        p.move(to: c)
        p.addArc(center: c, radius: radius, startAngle: .radians(s), endAngle: .radians(e), clockwise: false)
        p.closeSubpath()
        a += period
    }
    ctx.fill(p, with: .color(color))
}

/// `.catbg`: the category colour behind the card (radial white → b1 → b2 → darker b2) with slow white rays.
struct CCCategoryBackground: View {
    let category: CCCategory
    let now: Double
    let calm: Bool

    var body: some View {
        GeometryReader { g in
            let s = g.size
            let b1 = Color(hex: category.b1), b2 = Color(hex: category.b2)
            ZStack {
                Rectangle().fill(ccRadial(at: UnitPoint(x: 0.5, y: 0.41), [
                    .init(color: .white, location: 0), .init(color: b1, location: 0.30),
                    .init(color: b2, location: 0.76), .init(color: ccMixBlack(category.b2, 0.55), location: 1),
                ], size: s))
                // ::after — inset -30%, rays from the box's (50%, 45%), masked radial #000 10% → transparent 60%, spin 40 s
                let box = CGSize(width: s.width * 1.6, height: s.height * 1.6)
                let c = CGPoint(x: box.width * 0.5, y: box.height * 0.45)
                let ang = calm ? 0 : (now.truncatingRemainder(dividingBy: 40) / 40) * 360
                Canvas { ctx, _ in
                    ccRays(&ctx, center: c, radius: Double(box.width + box.height), from: ang, on: 5, period: 15, color: .white.opacity(0.26))
                }
                .frame(width: box.width, height: box.height)
                .mask {
                    Rectangle().fill(ccRadial(at: UnitPoint(x: 0.5, y: 0.45), [
                        .init(color: .black, location: 0.10), .init(color: .black.opacity(0), location: 0.60),
                    ], size: box))
                }
                .position(x: s.width / 2, y: s.height / 2)
            }
        }
        .allowsHitTesting(false)
    }
}

/// `.halo` (design space): a 620 pt soft light at (195, 346) with faint rays (spin 24 s).
struct CCHalo: View {
    let now: Double
    let calm: Bool

    var body: some View {
        let s = CGSize(width: 620, height: 620)
        let box = CGSize(width: 868, height: 868)
        let ang = calm ? 0 : (now.truncatingRemainder(dividingBy: 24) / 24) * 360
        ZStack {
            Rectangle().fill(ccRadial(at: .center, [
                .init(color: .rgba(255, 248, 225, 0.55), location: 0),
                .init(color: .rgba(160, 200, 255, 0.22), location: 0.35),
                .init(color: .rgba(160, 200, 255, 0), location: 0.65),
            ], size: s))
            .frame(width: s.width, height: s.height)
            Canvas { ctx, _ in
                ccRays(&ctx, center: CGPoint(x: box.width / 2, y: box.height / 2), radius: 900, from: ang, on: 4, period: 15,
                       color: .white.opacity(0.16))
            }
            .frame(width: box.width, height: box.height)
            .mask {
                Rectangle().fill(ccRadial(at: .center, [.init(color: .black, location: 0), .init(color: .black.opacity(0), location: 0.60)], size: box))
            }
            .blur(radius: 2)
        }
        .frame(width: s.width, height: s.height)
        .position(x: 195, y: 346)
        .allowsHitTesting(false)
    }
}

/// `.aiglow`: a blue-only conic ring along the screen edge (7 pt) plus its blurred twin (22 pt, blur 18, .85).
struct CCAIGlow: View {
    let now: Double
    let calm: Bool
    let k: CGFloat

    var body: some View {
        let ang = calm ? 0 : (now.truncatingRemainder(dividingBy: 4) / 4) * 360
        let g = AngularGradient(colors: [Color(hex: 0x6FD3FF), Color(hex: 0x1F6BFF), Color(hex: 0x8FBAFF), Color(hex: 0x2A9BFF),
                                         Color(hex: 0x0A4FD8), Color(hex: 0x6FD3FF)],
                                center: .center, angle: .degrees(ang - 90))
        let r = 52 * k
        ZStack {
            Rectangle().fill(g).mask { RoundedRectangle(cornerRadius: r, style: .continuous).strokeBorder(lineWidth: 7 * k) }
            Rectangle().fill(g).mask { RoundedRectangle(cornerRadius: r, style: .continuous).strokeBorder(lineWidth: 22 * k) }
                .blur(radius: 18 * k)
                .opacity(0.85)
        }
        .allowsHitTesting(false)
    }
}

/// `.spark`: the pill's rounded square with a turning blue conic gradient (3 s) and the sparkle icon.
struct CCSpark: View {
    let now: Double
    let calm: Bool

    var body: some View {
        let ang = calm ? 0 : (now.truncatingRemainder(dividingBy: 3) / 3) * 360
        RoundedRectangle(cornerRadius: 10, style: .circular)
            .fill(AngularGradient(colors: [Color(hex: 0x5CC8FF), Color(hex: 0x1F6BFF), Color(hex: 0x7FB2FF), Color(hex: 0x2A9BFF),
                                           Color(hex: 0x5CC8FF)], center: .center, angle: .degrees(ang - 90)))
            .frame(width: 30, height: 30)
            .overlay {
                ZStack {
                    ForEach(CCIcons.sparkle, id: \.self) { d in CCSVGPath(d: d).fill(.white) }
                }
                .frame(width: 17, height: 17)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
            }
    }
}

/// `#flash`: a white sheet driven by a WAAPI animation sample (opacity).
struct CCFlash: View {
    let anim: CCAnim?
    let now: Double

    var body: some View {
        let o = anim?.sample(now)?.first ?? 0
        Color.white.opacity(max(0, min(1, o))).allowsHitTesting(false)
    }
}

/// Shutter flash for the capture screen: `#flash.animate([0, 1 @12%, 0], {480 ms, ease-out})` (1 ms when calm).
struct CCShutterFlash: View {
    let start: Double?
    let calm: Bool

    var body: some View {
        if let start {
            TimelineView(.animation) { _ in
                let now = CCClock.now
                let anim = CCAnim([[0], [1], [0]], offsets: [0, 0.12, 1], duration: calm ? 0.001 : 0.48,
                                  easing: .easeOut, start: start)
                CCFlash(anim: anim, now: now)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
