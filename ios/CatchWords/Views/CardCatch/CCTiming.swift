import SwiftUI
import QuartzCore

// Timing for the card-catch flow, written to behave like the prototype's Web Animations / CSS
// (docs/prototype/cardcatch-src.html): an `easing` given to `el.animate()` applies to the WHOLE
// iteration (keyframes are linear in between, and an overshooting curve extrapolates past the last
// keyframe), CSS @keyframes apply their timing function per segment, CSS transitions start from the
// current value. Every value is sampled from `CACurrentMediaTime()` inside a `TimelineView(.animation)`.

nonisolated enum CCClock {
    static var now: Double { CACurrentMediaTime() }
}

/// CSS `cubic-bezier(x1, y1, x2, y2)`.
nonisolated struct CCBezier: Sendable {
    let x1: Double, y1: Double, x2: Double, y2: Double

    init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        self.x1 = x1; self.y1 = y1; self.x2 = x2; self.y2 = y2
    }

    static let linear = CCBezier(0, 0, 1, 1)
    static let ease = CCBezier(0.25, 0.1, 0.25, 1)
    static let easeIn = CCBezier(0.42, 0, 1, 1)
    static let easeOut = CCBezier(0, 0, 0.58, 1)
    static let easeInOut = CCBezier(0.42, 0, 0.58, 1)

    private func bx(_ t: Double) -> Double { let u = 1 - t; return 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t }
    private func by(_ t: Double) -> Double { let u = 1 - t; return 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t }
    private func dbx(_ t: Double) -> Double { let u = 1 - t; return 3 * u * u * x1 + 6 * u * t * (x2 - x1) + 3 * t * t * (1 - x2) }

    func callAsFunction(_ x: Double) -> Double {
        if x1 == 0, y1 == 0, x2 == 1, y2 == 1 { return x }
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        var t = x
        for _ in 0..<8 {
            let err = bx(t) - x
            if abs(err) < 1e-6 { return by(t) }
            let d = dbx(t)
            if abs(d) < 1e-6 { break }
            t -= err / d
        }
        var lo = 0.0, hi = 1.0
        t = x
        for _ in 0..<40 {
            let v = bx(t)
            if abs(v - x) < 1e-6 { break }
            if v < x { lo = t } else { hi = t }
            t = (lo + hi) / 2
        }
        return by(t)
    }
}

/// One `el.animate(keyframes, {duration, delay, easing, fill})` on a vector of numbers.
nonisolated struct CCAnim: Sendable {
    enum Fill: Sendable { case none, forwards, backwards, both }

    var start: Double
    var delay: Double
    var duration: Double
    var easing: CCBezier
    var offsets: [Double]
    var values: [[Double]]
    var fill: Fill

    /// `offsets` nil = evenly spaced (as WAAPI does for keyframes without `offset`). Times in seconds.
    init(_ values: [[Double]], offsets: [Double]? = nil, duration: Double, delay: Double = 0,
         easing: CCBezier = .linear, fill: Fill = .none, start: Double = CCClock.now) {
        self.values = values
        let n = max(1, values.count - 1)
        self.offsets = offsets ?? values.indices.map { Double($0) / Double(n) }
        self.duration = max(duration, 0.000_001)
        self.delay = delay
        self.easing = easing
        self.fill = fill
        self.start = start
    }

    var end: Double { start + delay + duration }
    func finished(at now: Double) -> Bool { now >= end }

    /// The animated value at `now`, or nil when the animation has no effect (outside its active time
    /// without the matching fill).
    func sample(_ now: Double) -> [Double]? {
        let local = now - start - delay
        if local < 0 { return (fill == .backwards || fill == .both) ? interp(easing(0)) : nil }
        if local >= duration { return (fill == .forwards || fill == .both) ? interp(easing(1)) : nil }
        return interp(easing(local / duration))
    }

    func interp(_ p: Double) -> [Double] {
        guard values.count > 1 else { return values.first ?? [] }
        var i = 0
        if p >= 1 {
            i = values.count - 2
        } else if p > 0 {
            while i < values.count - 2, p > offsets[i + 1] { i += 1 }
        }
        let a = offsets[i], b = offsets[i + 1]
        let f = b > a ? (p - a) / (b - a) : 0
        return zip(values[i], values[i + 1]).map { $0 + ($1 - $0) * f }
    }
}

/// A CSS `transition` on one number: a new target starts from wherever the value is now.
nonisolated struct CCTransition: Sendable {
    var from: Double
    var to: Double
    var start: Double = 0
    var duration: Double = 0.000_001
    var easing: CCBezier = .ease

    init(_ value: Double) {
        from = value
        to = value
    }

    func value(_ now: Double) -> Double {
        let t = (now - start) / duration
        if t >= 1 { return to }
        if t <= 0 { return from }
        return from + (to - from) * easing(t)
    }

    mutating func set(_ target: Double, duration: Double, easing: CCBezier = .ease, now: Double = CCClock.now) {
        guard target != to else { return }
        from = value(now)
        to = target
        start = now
        self.duration = max(duration, 0.000_001)
        self.easing = easing
    }
}

/// The prototype's `CALM()` / `D(ms)` / `sleep(ms)` / `.calm` rules, from Reduce Motion.
nonisolated struct CCMotion: Sendable {
    var calm: Bool
    /// `D(ms)` in seconds: 1 ms when calm.
    func d(_ ms: Double) -> Double { calm ? 0.001 : ms / 1000 }
    /// `sleep(ms)` in seconds: at most 60 ms when calm.
    func sleep(_ ms: Double) -> Double { (calm ? min(ms, 60) : ms) / 1000 }
    /// `.calm *{transition-duration:.001s}`.
    func transition(_ ms: Double) -> Double { calm ? 0.000_001 : ms / 1000 }
}

/// The 390×844 pt prototype screen mapped onto the real screen: one uniform scale `k`, centred.
nonisolated struct CCSpace: Sendable, Equatable {
    static let w: CGFloat = 390
    static let h: CGFloat = 844
    var size: CGSize

    var k: CGFloat { max(0.0001, min(size.width / Self.w, size.height / Self.h)) }
    var origin: CGPoint { CGPoint(x: (size.width - Self.w * k) / 2, y: (size.height - Self.h * k) / 2) }

    func toDesign(_ r: CGRect) -> CGRect {
        CGRect(x: (r.minX - origin.x) / k, y: (r.minY - origin.y) / k, width: r.width / k, height: r.height / k)
    }
    func toReal(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * k, y: origin.y + p.y * k) }
}

extension View {
    /// Lays `content` out on the 390×844 prototype screen and scales it onto the real one.
    func ccDesignLayer(_ space: CCSpace) -> some View {
        frame(width: CCSpace.w, height: CCSpace.h, alignment: .topLeading)
            .scaleEffect(space.k, anchor: .center)
            .frame(width: space.size.width, height: space.size.height)
    }

    /// `position:absolute; left; top; width; height` in the design space.
    func ccPlace(_ r: CGRect) -> some View {
        frame(width: max(0, r.width), height: max(0, r.height)).position(x: r.midX, y: r.midY)
    }
}

// MARK: - Colour helpers

extension Color {
    /// CSS `hsla()`.
    static func hsla(_ h: Double, _ s: Double, _ l: Double, _ a: Double) -> Color {
        // CSS Color 4: f(n) = l − s·min(l, 1−l)·max(−1, min(k−3, 9−k, 1)), k = (n + h/30) mod 12
        let hd = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        func ch(_ n: Double) -> Double {
            let k = (n + hd / 30).truncatingRemainder(dividingBy: 12)
            return l - s * min(l, 1 - l) * max(-1, min(k - 3, 9 - k, 1))
        }
        return Color(.sRGB, red: ch(0), green: ch(8), blue: ch(4), opacity: a)
    }

    /// `rgba(r,g,b,a)` with 0–255 channels.
    static func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }
}

/// `color-mix(in srgb, <hex> p%, #000)`.
func ccMixBlack(_ hex: UInt32, _ p: Double) -> Color {
    let r = Double((hex >> 16) & 0xFF) / 255, g = Double((hex >> 8) & 0xFF) / 255, b = Double(hex & 0xFF) / 255
    return Color(.sRGB, red: r * p, green: g * p, blue: b * p, opacity: 1)
}

/// A CSS `linear-gradient(<angle>deg, …)` laid on a box of `size` (the gradient line's length follows
/// the CSS rule |w·sinθ| + |h·cosθ|, so the angle stays right on non-square boxes).
func ccLinear(_ angle: Double, _ stops: [Gradient.Stop], size: CGSize) -> LinearGradient {
    let th = angle * .pi / 180
    let dx = sin(th), dy = -cos(th)
    let w = max(Double(size.width), 0.0001), h = max(Double(size.height), 0.0001)
    let len = abs(w * dx) + abs(h * dy)
    let cx = w / 2, cy = h / 2
    let sx = cx - dx * len / 2, sy = cy - dy * len / 2
    let ex = cx + dx * len / 2, ey = cy + dy * len / 2
    return LinearGradient(stops: stops, startPoint: UnitPoint(x: sx / w, y: sy / h), endPoint: UnitPoint(x: ex / w, y: ey / h))
}

/// A CSS `radial-gradient(circle at x% y%, …)` (size farthest-corner) on a box of `size`.
func ccRadial(at u: UnitPoint, _ stops: [Gradient.Stop], size: CGSize) -> RadialGradient {
    let px = u.x * size.width, py = u.y * size.height
    let fx = max(px, size.width - px), fy = max(py, size.height - py)
    return RadialGradient(stops: stops, center: u, startRadius: 0, endRadius: (fx * fx + fy * fy).squareRoot())
}

// MARK: - The prototype's SVG icons

/// A tiny SVG path reader for the prototype's inline icons (M L H V C Z and circular A, absolute and relative).
struct CCSVGPath: Shape {
    let d: String
    var viewBox: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        var p = CCSVGPath.parse(d)
        let s = min(rect.width, rect.height) / viewBox
        p = p.applying(CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: s, y: s))
        return p
    }

    static func parse(_ d: String) -> Path {
        var tokens: [String] = []
        var cur = ""
        func flush() { if !cur.isEmpty { tokens.append(cur); cur = "" } }
        for ch in d {
            if ch.isLetter && ch != "e" {
                flush(); tokens.append(String(ch))
            } else if ch == "," || ch == " " || ch == "\n" {
                flush()
            } else if ch == "-" {
                if let last = cur.last, last == "e" { cur.append(ch) } else { flush(); cur.append(ch) }
            } else if ch == "." {
                if cur.contains(".") && !cur.contains("e") { flush() }
                cur.append(ch)
            } else {
                cur.append(ch)
            }
        }
        flush()

        var path = Path()
        var i = 0
        var cmd: Character = "M"
        var pt = CGPoint.zero
        var startPt = CGPoint.zero
        func num() -> CGFloat {
            guard i < tokens.count, let v = Double(tokens[i]) else { i += 1; return 0 }
            i += 1
            return CGFloat(v)
        }
        func isNum(_ t: String) -> Bool { Double(t) != nil }
        while i < tokens.count {
            if let c = tokens[i].first, tokens[i].count == 1, c.isLetter {
                cmd = c
                i += 1
            }
            let rel = cmd.isLowercase
            switch cmd {
            case "M", "m":
                var p = CGPoint(x: num(), y: num())
                if rel { p.x += pt.x; p.y += pt.y }
                path.move(to: p)
                pt = p; startPt = p
                cmd = rel ? "l" : "L"
            case "L", "l":
                var p = CGPoint(x: num(), y: num())
                if rel { p.x += pt.x; p.y += pt.y }
                path.addLine(to: p); pt = p
            case "H", "h":
                var x = num(); if rel { x += pt.x }
                pt = CGPoint(x: x, y: pt.y); path.addLine(to: pt)
            case "V", "v":
                var y = num(); if rel { y += pt.y }
                pt = CGPoint(x: pt.x, y: y); path.addLine(to: pt)
            case "C", "c":
                var c1 = CGPoint(x: num(), y: num())
                var c2 = CGPoint(x: num(), y: num())
                var p = CGPoint(x: num(), y: num())
                if rel {
                    c1.x += pt.x; c1.y += pt.y; c2.x += pt.x; c2.y += pt.y; p.x += pt.x; p.y += pt.y
                }
                path.addCurve(to: p, control1: c1, control2: c2); pt = p
            case "A", "a":
                let rx = num(); _ = num(); _ = num()
                let large = num() != 0, sweep = num() != 0
                var p = CGPoint(x: num(), y: num())
                if rel { p.x += pt.x; p.y += pt.y }
                addArc(&path, from: pt, to: p, r: rx, large: large, sweep: sweep)
                pt = p
            case "Z", "z":
                path.closeSubpath(); pt = startPt
                // a bare Z is followed by a command letter
                if i < tokens.count, isNum(tokens[i]) { i += 1 }
            default:
                i += 1
            }
        }
        return path
    }

    /// SVG endpoint arc (circular, no rotation) → centre arc.
    private static func addArc(_ path: inout Path, from a: CGPoint, to b: CGPoint, r rIn: CGFloat, large: Bool, sweep: Bool) {
        let dx = (a.x - b.x) / 2, dy = (a.y - b.y) / 2
        var r = abs(rIn)
        let d2 = dx * dx + dy * dy
        if r * r < d2 { r = d2.squareRoot() }
        let sign: CGFloat = (large == sweep) ? -1 : 1
        let k = sign * max(0, (r * r - d2) / max(d2, 0.000_001)).squareRoot()
        let cx = k * (dy) + (a.x + b.x) / 2
        let cy = k * (-dx) + (a.y + b.y) / 2
        let a0 = atan2(a.y - cy, a.x - cx), a1 = atan2(b.y - cy, b.x - cx)
        // SVG sweep=1 is clockwise on screen (y down) = increasing angle.
        path.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: .radians(Double(a0)),
                    endAngle: .radians(Double(a1)), clockwise: !sweep)
    }
}

/// The prototype's icons (paths copied from cardcatch-src.html).
nonisolated enum CCIcons {
    /// `.spark` (pill): two sparkles, filled.
    static let sparkle = ["M12 2l1.8 5.6L19.5 9l-5.7 1.6L12 16l-1.8-5.4L4.5 9l5.7-1.4z", "M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"]
    /// `STAR`: the four-point star of `.starlight`.
    static let star = "M12 0C12.6 7.2 16.8 11.4 24 12 16.8 12.6 12.6 16.8 12 24 11.4 16.8 7.2 12.6 0 12 7.2 11.4 11.4 7.2 12 0z"
    /// Speaker body (filled) and its waves (stroked, width 2, round caps).
    static let speakerBody = "M4 9h4l5-4v14l-5-4H4z"
    static let speakerWave1 = "M16 8a5 5 0 0 1 0 8"
    static let speakerWave2 = "M18.5 5.5a8.5 8.5 0 0 1 0 13"
    /// `.gobtn` arrow (stroked 2.4, round).
    static let arrowUp = "M12 19V5M5 12l7-7 7 7"
    /// `.xbtn` cross (stroked 2.4, round).
    static let cross = "M6 6l12 12M18 6L6 18"
}

/// The prototype's speaker icon: filled body + stroked waves (`waves` 1 for `.sayb`, 2 for `.wrow .sp`).
struct CCSpeakerIcon: View {
    var waves: Int = 2
    var color: Color

    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height) / 24
            ZStack {
                CCSVGPath(d: CCIcons.speakerBody).fill(color)
                CCSVGPath(d: CCIcons.speakerWave1).stroke(color, style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
                if waves > 1 {
                    CCSVGPath(d: CCIcons.speakerWave2).stroke(color, style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
                }
            }
        }
    }
}
