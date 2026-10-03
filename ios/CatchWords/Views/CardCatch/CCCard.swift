import SwiftUI
import UIKit
import QuartzCore

// The d2 "full art" hologram card (cardHTML d2 + `.d2 *` + artLayers/popHTML/bigPop), 280×392 design pt.

/// Everything the card shows.
struct CCCardEntry {
    enum Art {
        /// `artm:"cut"`: category studio + the cut-out on top (`pop`).
        case cut(UIImage, pop: CCPop)
        /// No cut-out (`mode:"orig"`): the photo window from `cropAt`.
        case orig(UIImage)
    }

    let headword: String
    let zhuyin: String
    let pinyin: String
    let meaning: String
    let example: String
    let exampleTranslation: String
    let categoryLine: String
    let placeDate: String
    let no: Int
    let category: CCCategory
    let art: Art
}

/// `.pop` placement on the card (left/top/width/height, the bottom clip and `--ps`).
struct CCPop {
    var rect: CGRect
    var clipB: CGFloat
    var ps: CGFloat = 1
}

// MARK: - Images (bigPop, cropAt, cropFrom, outlineEl)

enum CCImages {
    /// `CENTER.d2`.
    nonisolated static let center = CGPoint(x: 140, y: 174)
    nonisolated static let fit = CGSize(width: 248, height: 240)
    nonisolated static let clipY: CGFloat = 294

    /// `bigPop(cut, zhLen)`: the largest size (height 287 down to 120, step 3, bottom at y=293, centred at
    /// x=140) whose opaque pixels (alpha > 110 on a 72-px-wide sample) stay inside x 7–273, y ≥ 7 and 4 pt
    /// clear of the name, the No. and the bottom text.
    static func bigPop(_ cut: UIImage, zhLen: Int) -> CCPop? {
        guard let cg = cut.cgImage, cg.width > 0, cg.height > 0 else { return nil }
        let natW = CGFloat(cg.width), natH = CGFloat(cg.height)
        let mw = 72
        let mh = max(8, Int((CGFloat(mw) * natH / natW).rounded()))
        var bytes = [UInt8](repeating: 0, count: mw * mh * 4)
        let ok: Bool = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(data: raw.baseAddress, width: mw, height: mh, bitsPerComponent: 8, bytesPerRow: mw * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .high
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: mw, height: mh))
            return true
        }
        guard ok else { return nil }
        var pts: [(CGFloat, CGFloat)] = []
        for y in 0..<mh {
            for x in 0..<mw where bytes[(y * mw + x) * 4 + 3] > 110 {
                pts.append(((CGFloat(x) + 0.5) / CGFloat(mw), (CGFloat(y) + 0.5) / CGFloat(mh)))
            }
        }
        let m: CGFloat = 4
        let z = CGFloat(zhLen)
        let text: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (26 - m, 18 - m, 26 + z * 40 + m, 58 + m),
            (198 - m, 24 - m, 258 + m, 52 + m),
            (24 - m, 298 - m, 256 + m, 384),
        ]
        let ar = natW / natH
        for hi in stride(from: 287, through: 120, by: -3) {
            let h = CGFloat(hi)
            let w = h * ar, x0 = 140 - w / 2, y0 = 293 - h
            if y0 < 6 { continue }
            var fits = true
            for (u, v) in pts {
                let px = x0 + u * w, py = y0 + v * h
                if px < 7 || px > 273 || py < 7 { fits = false; break }
                if text.contains(where: { px > $0.0 && px < $0.2 && py > $0.1 && py < $0.3 }) { fits = false; break }
            }
            if fits { return CCPop(rect: CGRect(x: x0, y: y0, width: w, height: h), clipB: 0, ps: 1) }
        }
        return nil
    }

    /// makeEntry's d2 pop when bigPop finds no size: the object fitted into 248×240, centred on (140,174),
    /// clipped at y=294 (`ps` is 1 for d2).
    static func fallbackPop(objectPixels pw: CGFloat, _ ph: CGFloat) -> CCPop {
        let k = min(fit.width / max(pw, 1), fit.height / max(ph, 1))
        let w = pw * k, h = ph * k
        let r = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        return CCPop(rect: r, clipB: max(0, r.maxY - clipY), ps: 1)
    }

    /// `cropAt(img, bb, ART.d2, CENTER.d2.c, k, extend:false)` for the photo card: the photo window that puts
    /// the object's centre on (140,174) at 95% of the fit, clamped inside the photo, mirrored tiles beyond it.
    /// Heavy (up to 9 draws of the whole photo): called off the main thread (`CardCatchModel.formLight`).
    nonisolated static func cropAt(photo: UIImage, box bb: CGRect) -> UIImage {
        let wn = photo.size.width, hn = photo.size.height
        let pw = bb.width * wn, ph = bb.height * hn
        let fb = CGSize(width: fit.width * 0.95, height: fit.height * 0.95)
        let k = min(fb.width / max(pw, 1), fb.height / max(ph, 1))
        let r = CGSize(width: 280, height: 392)
        let w = r.width / k, h = r.height / k
        let ocx = bb.midX * wn, ocy = bb.midY * hn
        var x0 = ocx - center.x / k, y0 = ocy - center.y / k
        x0 = w >= wn ? (wn - w) / 2 : min(max(0, x0), wn - w)
        y0 = h >= hn ? (hn - h) / 2 : min(max(0, y0), hn - h)
        let outW: CGFloat = 760
        let out = CGSize(width: outW, height: (outW * r.height / r.width).rounded())
        let s = outW / w
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: out, format: fmt).image { ctx in
            let g = ctx.cgContext
            g.concatenate(CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: -x0 * s, ty: -y0 * s))
            // Only the tiles the window can see (each draw resamples the whole photo; the result is the same).
            let window = CGRect(x: x0, y: y0, width: w, height: h)
            for i in [-1, 0, 1] {
                for j in [-1, 0, 1] {
                    let tile = CGRect(x: CGFloat(i) * wn, y: CGFloat(j) * hn, width: wn, height: hn)
                    guard tile.intersects(window) else { continue }
                    g.saveGState()
                    g.translateBy(x: i > 0 ? 2 * wn : 0, y: j > 0 ? 2 * hn : 0)
                    g.scaleBy(x: i != 0 ? -1 : 1, y: j != 0 ? -1 : 1)
                    photo.draw(in: CGRect(x: 0, y: 0, width: wn, height: hn))
                    g.restoreGState()
                }
            }
        }
    }

    /// `cropFrom(img, bbox, aspect-of-bbox, 1, 500)`: the bbox itself (formLight's piece without a cut-out).
    /// Redraws the whole photo: called off the main thread (`CardCatchModel.buildObjects`).
    nonisolated static func cropFrom(photo: UIImage, box bb: CGRect) -> UIImage {
        let wn = photo.size.width, hn = photo.size.height
        let cw = max(1, bb.width * wn), ch = max(1, bb.height * hn)
        let x = min(max(0, bb.midX * wn - cw / 2), wn - cw), y = min(max(0, bb.midY * hn - ch / 2), hn - ch)
        let outW: CGFloat = 500
        let out = CGSize(width: outW, height: max(1, (outW * ch / cw).rounded()))
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: out, format: fmt).image { _ in
            let s = outW / cw
            photo.draw(in: CGRect(x: -x * s, y: -y * s, width: wn * s, height: hn * s))
        }
    }

    /// `outlineEl`: a canvas 12 pt larger on each side at 2 px/pt. With a cut-out: its shape tinted with the
    /// #BFE8FF → #9CC8FF → #CFE3FF diagonal, drawn at 20 offsets of 3.5 canvas px, the shape itself cut away.
    /// Without: a #CFF6FF rounded rect (radius 22, width 5 canvas px).
    /// Heavy (21 composites of the cut-out): called off the main thread (`CardCatchModel.buildObjects`).
    nonisolated static func outline(cut: UIImage?, size r: CGSize) -> UIImage {
        let pad: CGFloat = 12, sc: CGFloat = 2
        let size = CGSize(width: max(1, ((r.width + pad * 2) * sc).rounded()), height: max(1, ((r.height + pad * 2) * sc).rounded()))
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: fmt)
        guard let cut else {
            return renderer.image { ctx in
                let g = ctx.cgContext
                g.setStrokeColor(CGColor(red: 0xCF / 255, green: 0xF6 / 255, blue: 1, alpha: 1))
                g.setLineWidth(5)
                // canvas roundRect(…, 22): circular corners, clamped to the box like the canvas does
                let box = CGRect(x: pad * sc, y: pad * sc, width: max(0, r.width * sc), height: max(0, r.height * sc))
                let rad = max(0, min(22, box.width / 2, box.height / 2))
                g.addPath(CGPath(roundedRect: box, cornerWidth: rad, cornerHeight: rad, transform: nil))
                g.strokePath()
            }
        }
        let tinted = renderer.image { ctx in
            cut.draw(in: CGRect(x: pad * sc, y: pad * sc, width: r.width * sc, height: r.height * sc))
            let g = ctx.cgContext
            g.setBlendMode(.sourceIn)
            let colors = [CGColor(red: 0xBF / 255, green: 0xE8 / 255, blue: 1, alpha: 1),
                          CGColor(red: 0x9C / 255, green: 0xC8 / 255, blue: 1, alpha: 1),
                          CGColor(red: 0xCF / 255, green: 0xE3 / 255, blue: 1, alpha: 1)] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) {
                g.drawLinearGradient(grad, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
        }
        return renderer.image { _ in
            var a = 0.0
            while a < Double.pi * 2 {
                tinted.draw(at: CGPoint(x: cos(a) * 3.5, y: sin(a) * 3.5))
                a += Double.pi / 10
            }
            tinted.draw(at: .zero, blendMode: .destinationOut, alpha: 1)
        }
    }
}

// MARK: - tilt()

/// The prototype's `tilt(wrap, card, {lift:true, onFling})`: a spring toward a target tilt that idles in a
/// slow wobble and follows the finger; flinging up sends the card. Stepped at 60 steps/s like rAF.
final class CCTilt {
    var rx = 0.0, ry = 0.0, ty = 0.0
    private var vx = 0.0, vy = 0.0, trx = 0.0, tryy = 0.0, t = 0.0, vty = 0.0, tty = 0.0
    private(set) var alive = false
    private var last: Double?
    private var acc = 0.0

    struct Drag { var x: Double; var y: Double; var ly: Double; var lt: Double; var vy: Double }
    private var drag: Drag?

    var mx: Double { 50 + ry * 2.4 }
    var my: Double { 50 - rx * 2.4 }
    var shine: Double { min(1, 0.4 + (rx * rx + ry * ry).squareRoot() / 22) }

    func start() { alive = true; last = nil; acc = 0 }
    /// `stopTilt()`: the card keeps its last transform.
    func stop() { alive = false; drag = nil }

    func advance(to now: Double) {
        guard alive else { return }
        guard let l = last else { last = now; return }
        acc += min(0.25, now - l)
        last = now
        while acc >= 1.0 / 60 {
            acc -= 1.0 / 60
            step()
        }
    }

    private func step() {
        t += 1.0 / 60
        if drag == nil {
            trx = sin(t * 0.9) * 5
            tryy = cos(t * 0.7) * 8
            tty = 0
        }
        vx += (trx - rx) * 0.09; vy += (tryy - ry) * 0.09
        vx *= 0.82; vy *= 0.82
        rx += vx; ry += vy
        vty += (tty - ty) * 0.15; vty *= 0.75; ty += vty
    }

    /// pointerdown at `p` (design pt).
    func down(_ p: CGPoint, now: Double) {
        guard alive else { return }
        drag = Drag(x: Double(p.x), y: Double(p.y), ly: Double(p.y), lt: now * 1000, vy: 0)
    }

    /// pointermove while dragging; `c` = the card wrap's rect (design pt).
    func move(_ p: CGPoint, card c: CGRect, now: Double) {
        guard alive, var d = drag else { return }
        let ms = now * 1000
        let px = Double(p.x), py = Double(p.y)
        let cx = Double(c.midX), cy = Double(c.midY), cw = Double(c.width), ch = Double(c.height)
        d.vy = (py - d.ly) / max(1, ms - d.lt)
        d.ly = py
        d.lt = ms
        drag = d
        trx = max(-28, min(28, -(py - cy) / ch * 42))
        tryy = max(-32, min(32, (px - cx) / cw * 46))
        tty = min(0, (py - d.y) * 0.6)
    }

    /// pointerup: true when it was a fling up (`drag.vy < -.7 && drag.ly - drag.y < -50`).
    func up() -> Bool {
        defer { drag = nil }
        guard alive, let d = drag else { return false }
        return d.vy < -0.7 && d.ly - d.y < -50
    }
}

// MARK: - 3D (perspective 900 on .cwrap, preserve-3d layers in .tc)

/// The card's own transform (`.tc`), in CSS terms.
struct CCCardPose {
    var ty: Double = 0
    var rx: Double = 0
    var ry: Double = 0
    var scale: Double = 1
}

enum CCProject {
    static let size = CGSize(width: 280, height: 392)

    /// CSS column-vector matrices, written as Core Animation row-vector transforms (p' = p · M).
    private static func rotY(_ deg: Double) -> CATransform3D {
        let a = deg * .pi / 180
        var m = CATransform3DIdentity
        m.m11 = CGFloat(cos(a)); m.m13 = CGFloat(-sin(a)); m.m31 = CGFloat(sin(a)); m.m33 = CGFloat(cos(a))
        return m
    }

    private static func rotX(_ deg: Double) -> CATransform3D {
        let a = deg * .pi / 180
        var m = CATransform3DIdentity
        m.m22 = CGFloat(cos(a)); m.m23 = CGFloat(sin(a)); m.m32 = CGFloat(-sin(a)); m.m33 = CGFloat(cos(a))
        return m
    }

    /// `transform: translateY(ty) rotateX(rx) rotateY(ry) scale(s)` (applied right to left) about the centre,
    /// a layer's `translateZ(z)` first, then `perspective: 900px` about the centre.
    static func matrix(_ pose: CCCardPose, z: Double) -> CATransform3D {
        let c = CATransform3DMakeTranslation(size.width / 2, size.height / 2, 0)
        let cInv = CATransform3DMakeTranslation(-size.width / 2, -size.height / 2, 0)
        var persp = CATransform3DIdentity
        persp.m34 = -1.0 / 900
        var m = cInv
        m = CATransform3DConcat(m, CATransform3DMakeTranslation(0, 0, CGFloat(z)))
        m = CATransform3DConcat(m, CATransform3DMakeScale(CGFloat(pose.scale), CGFloat(pose.scale), 1))
        m = CATransform3DConcat(m, rotY(pose.ry))
        m = CATransform3DConcat(m, rotX(pose.rx))
        m = CATransform3DConcat(m, CATransform3DMakeTranslation(0, CGFloat(pose.ty), 0))
        m = CATransform3DConcat(m, persp)
        m = CATransform3DConcat(m, c)
        return m
    }

    /// Depth of a layer's centre after the card transform (for preserve-3d painter's order).
    static func depth(_ pose: CCCardPose, z: Double) -> Double {
        let a = pose.ry * .pi / 180, b = pose.rx * .pi / 180
        // centre (0,0,z): rotateY → (z·sin a, 0, z·cos a); rotateX → z' = z·cos a·cos b
        return z * cos(a) * cos(b)
    }
}

// MARK: - Card views

/// The face of the d2 card (everything inside `.face`), 280×392.
struct CCCardFace: View {
    let entry: CCCardEntry
    let tilt: CGPoint      // foil light, -1…1
    let mx: Double
    let my: Double
    let shine: Double
    let now: Double
    let starsOrigin: Double
    let sweepStart: Double?
    let calm: Bool

    let ink = Color(hex: 0x0B0B0B)

    var body: some View {
        ZStack(alignment: .topLeading) {
            art
            stars
            topBar
            bottomPanel
            rim
            glare
            sweep
        }
        .frame(width: 280, height: 392)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .circular))
    }

    // `.art` (left 0, top 0, 280×392): studio or photo, then foil + glitter (the app's holoFoil).
    @ViewBuilder private var art: some View {
        Group {
            switch entry.art {
            case .cut:
                studio
            case .orig(let img):
                Image(uiImage: img).resizable().frame(width: 280, height: 392)
            }
        }
        .frame(width: 280, height: 392)
        .holographic(tilt: tilt, intensity: shine, cornerRadius: 0)
    }

    /// artLayers' `.studio`: radial white glow, b1 corner glow, a soft highlight, over linear-gradient(165deg, b1, b2).
    private var studio: some View {
        let s = CGSize(width: 280, height: 392)
        let b1 = Color(hex: entry.category.b1), b2 = Color(hex: entry.category.b2)
        return ZStack {
            Rectangle().fill(ccLinear(165, [.init(color: b1, location: 0), .init(color: b2, location: 1)], size: s))
            Rectangle().fill(ccRadial(at: UnitPoint(x: 0.85, y: 0.20),
                                      [.init(color: .white.opacity(0.6), location: 0), .init(color: .white.opacity(0), location: 0.40)], size: s))
            Rectangle().fill(ccRadial(at: UnitPoint(x: 0.18, y: 0.85),
                                      [.init(color: b1, location: 0), .init(color: b1.opacity(0), location: 0.55)], size: s))
            Rectangle().fill(ccRadial(at: UnitPoint(x: 0.5, y: 0.38),
                                      [.init(color: .white.opacity(0.95), location: 0), .init(color: .white.opacity(0), location: 0.52)], size: s))
        }
    }

    /// `starsHTML(w.zh+"2", 14, {x:6,y:8,w:88,h:66})` with the `tw` keyframes (ease-in-out per segment).
    @ViewBuilder private var stars: some View {
        if !calm {
            let list = CCStars.make(seed: entry.headword + "2", n: 14, area: CGRect(x: 6, y: 8, width: 88, height: 66))
            ZStack(alignment: .topLeading) {
                ForEach(Array(list.enumerated()), id: \.offset) { _, s in
                    let f = CCStars.frame(s, now: now, origin: starsOrigin, shine: shine)
                    CCSVGPath(d: CCIcons.star)
                        .fill(.white)
                        .frame(width: s.size, height: s.size)
                        .shadow(color: .rgba(255, 250, 215, 1), radius: 1.5)
                        .shadow(color: .rgba(255, 215, 140, 0.8), radius: 4)
                        .scaleEffect(f.scale)
                        .rotationEffect(.degrees(f.rotation))
                        .opacity(f.opacity)
                        .position(x: s.x / 100 * 280, y: s.y / 100 * 392)
                }
            }
            .frame(width: 280, height: 392)
            .allowsHitTesting(false)
        }
    }

    /// `.d2 .top`: left/right/top 14, height 48, radius 12, white 88%, name (28 pt 700 + zhuyin) and No.
    private var topBar: some View {
        HStack(spacing: 8) {
            CCZhuyinWord(headword: entry.headword, zhuyin: entry.zhuyin, pinyin: entry.pinyin, size: 28, weight: .bold, color: ink)
            Spacer(minLength: 0)
            Text(verbatim: "No." + String(format: "%03d", entry.no))
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(ink)
        }
        .padding(.horizontal, 12)
        .frame(width: 252, height: 48)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .circular))
        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
        .offset(x: 14, y: 14)
    }

    /// `.d2 .bot`: left/right/bottom 14, radius 12, padding 10 12, white 90%.
    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.meaning)   // lang-ok: filtered with ReaderLanguage.shown in CardCatchModel.makeEntry
                .font(.system(size: 16, weight: .black))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.example)
                    .font(.system(size: 11))
                    .lineSpacing(11 * 0.4 - 2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.exampleTranslation)   // lang-ok: filtered with ReaderLanguage.shown in CardCatchModel.makeEntry
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color(hex: 0x333333))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 3)
            HStack(alignment: .firstTextBaseline) {
                Text(entry.categoryLine)
                Spacer(minLength: 4)
                Text(entry.placeDate)
            }
            .font(.system(size: 9))
            .foregroundStyle(Color(hex: 0x333333))
            .padding(.top, 6)
        }
        .foregroundStyle(ink)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(width: 252, alignment: .leading)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .circular))
        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
        .frame(width: 280, height: 392 - 14, alignment: .bottom)
    }

    /// `.d2 .rim`: a 6 pt ring, linear-gradient(118deg, pastel rainbow) 260% large, positioned at mx% my%.
    private var rim: some View {
        let big = CGSize(width: 280 * 2.6, height: 392 * 2.6)
        let stops: [Gradient.Stop] = [
            .init(color: Color(hex: 0xFFE0F5), location: 0), .init(color: Color(hex: 0xFFF4B0), location: 0.15),
            .init(color: Color(hex: 0xC7FFE0), location: 0.30), .init(color: Color(hex: 0xB0ECFF), location: 0.45),
            .init(color: Color(hex: 0xDDC6FF), location: 0.60), .init(color: Color(hex: 0xFFE0F5), location: 0.75),
            .init(color: Color(hex: 0xFFF4B0), location: 0.90),
        ]
        return Rectangle()
            .fill(ccLinear(118, stops, size: big))
            .frame(width: big.width, height: big.height)
            .offset(x: -(big.width - 280) * CGFloat(mx / 100), y: -(big.height - 392) * CGFloat(my / 100))
            .frame(width: 280, height: 392, alignment: .topLeading)
            .clipped()
            .mask { RoundedRectangle(cornerRadius: 16, style: .circular).strokeBorder(lineWidth: 6) }
            .allowsHitTesting(false)
    }

    /// `.glare`: radial light at mx% my% in overlay, opacity .3 + shine·.55.
    private var glare: some View {
        Rectangle()
            .fill(ccRadial(at: UnitPoint(x: mx / 100, y: my / 100), [
                .init(color: .white.opacity(0.8), location: 0.08),
                .init(color: .white.opacity(0.25), location: 0.26),
                .init(color: .black.opacity(0.18), location: 0.92),
            ], size: CGSize(width: 280, height: 392)))
            .blendMode(.overlay)
            .opacity(0.3 + shine * 0.55)
            .allowsHitTesting(false)
    }

    /// `.sweep.go`: the light band (300% wide) moves from background-position 130% to -40% in 1.2 s.
    @ViewBuilder private var sweep: some View {
        if let s = sweepStart, !calm {
            let t = (now - s) / 1.2
            if t >= 0, t < 1 {
                let p = 1.3 + (-0.4 - 1.3) * CCBezier(0.4, 0, 0.2, 1)(t)
                let big = CGSize(width: 280 * 3, height: 392)
                Rectangle()
                    .fill(ccLinear(105, [
                        .init(color: .white.opacity(0), location: 0.32),
                        .init(color: .white.opacity(0.95), location: 0.46),
                        .init(color: .rgba(255, 250, 220, 0.6), location: 0.50),
                        .init(color: .white.opacity(0), location: 0.62),
                    ], size: big))
                    .frame(width: big.width, height: big.height)
                    .offset(x: (280 - big.width) * CGFloat(p))
                    .frame(width: 280, height: 392, alignment: .topLeading)
                    .clipped()
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// `starsHTML`: the prototype's seeded positions (mulberry32 over an FNV-1a hash of the seed).
enum CCStars {
    struct Star { let x: Double; let y: Double; let size: Double; let dur: Double; let delay: Double }
    struct Frame { let opacity: Double; let scale: Double; let rotation: Double }

    private static func hash(_ s: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for u in s.unicodeScalars {
            h ^= u.value
            h = h &* 16_777_619
        }
        return h
    }

    /// mulberry32, bit for bit as `mulberry(a)` in the prototype.
    private struct Mulberry {
        var a: UInt32
        mutating func next() -> Double {
            a = a &+ 0x6D2B_79F5
            var t = (a ^ (a >> 15)) &* (1 | a)
            t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
            return Double(t ^ (t >> 14)) / 4_294_967_296
        }
    }

    static func make(seed: String, n: Int, area: CGRect) -> [Star] {
        var r = Mulberry(a: hash(seed))
        var out: [Star] = []
        for _ in 0..<n {
            let x = area.minX + r.next() * area.width
            let y = area.minY + r.next() * area.height
            let s = 7 + r.next() * 13
            let d = 2.4 + r.next() * 3
            let dl = -r.next() * 6
            out.append(Star(x: x, y: y, size: s, dur: d, delay: dl))
        }
        return out
    }

    /// `@keyframes tw` (0/100%: 0, .15, 0°; 45%: shine, 1, 40°; 60%: .8·shine, .75, 55°), ease-in-out per segment.
    static func frame(_ s: Star, now: Double, origin: Double, shine: Double) -> Frame {
        let local = now - origin - s.delay
        let p = (local.truncatingRemainder(dividingBy: s.dur) + s.dur).truncatingRemainder(dividingBy: s.dur) / s.dur
        let keys: [(Double, Double, Double, Double)] = [
            (0, 0, 0.15, 0), (0.45, shine, 1, 40), (0.60, shine * 0.8, 0.75, 55), (1, 0, 0.15, 0),
        ]
        var i = 0
        while i < keys.count - 2, p > keys[i + 1].0 { i += 1 }
        let a = keys[i], b = keys[i + 1]
        let f = CCBezier.easeInOut((p - a.0) / (b.0 - a.0))
        return Frame(opacity: a.1 + (b.1 - a.1) * f, scale: a.2 + (b.2 - a.2) * f, rotation: a.3 + (b.3 - a.3) * f)
    }
}

/// `.tc`: shadow, three edges, the face and the pop, each at its own depth under the card transform and the
/// wrap's perspective, painted far-to-near like preserve-3d (the edges cover the face when it turns away,
/// so the spin never shows mirrored text).
struct CCCardStack: View {
    let entry: CCCardEntry
    let pose: CCCardPose
    let face: CCCardFace

    var body: some View {
        ZStack(alignment: .topLeading) {
            layer(z: -30) {
                RoundedRectangle(cornerRadius: 18, style: .circular)
                    .fill(Color.rgba(0, 10, 30, 0.55))
                    .frame(width: 268, height: 388)
                    .blur(radius: 18)
                    .offset(x: 6, y: 10)
            }
            layer(z: -3.6) { RoundedRectangle(cornerRadius: 16, style: .circular).fill(Color(hex: 0x7D8A9C)) }
            layer(z: -2.4) { edge }
            layer(z: -1.2) { edge }
            layer(z: 0) { face }
            if case .cut(let img, let pop) = entry.art {
                layer(z: 0.5) { popView(img, pop) }
            }
        }
        .frame(width: 280, height: 392)
    }

    private var edge: some View {
        RoundedRectangle(cornerRadius: 16, style: .circular)
            .fill(ccLinear(135, [.init(color: Color(hex: 0xE8EEF6), location: 0), .init(color: Color(hex: 0x9AA8BA), location: 0.5),
                                 .init(color: Color(hex: 0xE8EEF6), location: 1)], size: CCProject.size))
    }

    /// `.tc .pop`: transform-origin bottom centre, `scale(--ps)`, clipped `clipB` from its bottom,
    /// `drop-shadow(0 3px 4px rgba(0,20,50,.22))`.
    private func popView(_ img: UIImage, _ pop: CCPop) -> some View {
        Image(uiImage: img)
            .resizable()
            .frame(width: pop.rect.width, height: pop.rect.height)
            .mask(alignment: .top) {
                Rectangle().frame(height: max(0, pop.rect.height - pop.clipB) + pop.rect.height * 0.6)
                    .offset(y: -pop.rect.height * 0.6)
            }
            .shadow(color: .rgba(0, 20, 50, 0.22), radius: 2, x: 0, y: 3)
            .scaleEffect(pop.ps, anchor: .bottom)
            .offset(x: pop.rect.minX, y: pop.rect.minY)
            .allowsHitTesting(false)
    }

    private func layer<V: View>(z: Double, @ViewBuilder _ content: () -> V) -> some View {
        content()
            .frame(width: 280, height: 392, alignment: .topLeading)
            .projectionEffect(ProjectionTransform(CCProject.matrix(pose, z: z)))
            .zIndex(CCProject.depth(pose, z: z))
    }
}
