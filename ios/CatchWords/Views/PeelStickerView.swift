import SwiftUI

/// peel-geometry.ts: split a 320×320 box (with 20pt bleed) by a line perpendicular to the drag direction.
nonisolated struct PeelGeometry {
    let front: [CGPoint]
    let flap: [CGPoint]
    let lineA: CGPoint
    let normal: CGPoint

    init(p: Double, angle: Double, side: CGFloat) {
        let nx = cos(angle), ny = sin(angle)
        let lo: CGFloat = -20, hi: CGFloat = 340
        let corners = [CGPoint(x: lo, y: lo), CGPoint(x: hi, y: lo), CGPoint(x: hi, y: hi), CGPoint(x: lo, y: hi)]
        let proj = corners.map { nx * $0.x + ny * $0.y }
        let q = (proj.min() ?? 0) + p * ((proj.max() ?? 0) - (proj.min() ?? 0))

        func polygon(_ sign: Double) -> [CGPoint] {
            var out: [CGPoint] = []
            for i in 0..<4 {
                let a = corners[i], b = corners[(i + 1) % 4]
                let da = sign * (nx * a.x + ny * a.y - q), db = sign * (nx * b.x + ny * b.y - q)
                if da >= 0 { out.append(a) }
                if (da >= 0) != (db >= 0) {
                    let t = da / (da - db)
                    out.append(CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y)))
                }
            }
            return out
        }
        let s = side / 320
        let reflect: (CGPoint) -> CGPoint = { pt in
            let d = nx * pt.x + ny * pt.y - q
            return CGPoint(x: pt.x - 2 * d * nx, y: pt.y - 2 * d * ny)
        }
        front = polygon(1).map { CGPoint(x: $0.x * s, y: $0.y * s) }
        flap = polygon(-1).map(reflect).map { CGPoint(x: $0.x * s, y: $0.y * s) }
        lineA = CGPoint(x: q * nx * s, y: q * ny * s)
        normal = CGPoint(x: nx, y: ny)
    }
}

private struct PolygonShape: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        points.dropFirst().forEach { p.addLine(to: $0) }
        p.closeSubpath()
        return p
    }
}

/// PeelSticker.tsx: peel the sticker off in ANY direction to catch it (≥32% commits),
/// otherwise it springs back. The back of the flap is paper-white with a curl shade.
struct PeelStickerView: View {
    let image: UIImage
    let isCutout: Bool
    var disabled: Bool = false
    let onPeel: () -> Void
    var onTap: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0
    @State private var angle: Double = .pi / 4
    @State private var dragAngle: Double?
    @State private var committed: Bool = false
    @State private var held: Bool = false
    @State private var shine: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let g = PeelGeometry(p: progress, angle: angle, side: side)
            ZStack(alignment: .topLeading) {
                artwork(side: side)
                    .mask(PolygonShape(points: g.front))
                    .overlay {
                        LinearGradient(colors: [.clear, Color(hex: 0xB2FFE1).opacity(0.3), .white.opacity(0.75), Color(hex: 0xD9B6FF).opacity(0.4), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: side * 0.7)
                            .offset(x: shine * side * 1.4)
                            .blendMode(.plusLighter)
                            .mask(artwork(side: side).mask(PolygonShape(points: g.front)))
                            .allowsHitTesting(false)
                    }
                    .shadow(color: .black.opacity(held ? 0.32 : 0.22), radius: held ? 14 : 10, x: held ? -6 : 0, y: held ? 18 : 10)

                if progress > 0.005 {
                    PolygonShape(points: g.flap)
                        .fill(LinearGradient(colors: [Color(hex: 0x8A8892), Color(hex: 0xDEDDE2), .white, Color(hex: 0xF4F3F1)],
                                             startPoint: UnitPoint(x: 0.5 - g.normal.x * 0.5, y: 0.5 - g.normal.y * 0.5),
                                             endPoint: UnitPoint(x: 0.5 + g.normal.x * 0.5, y: 0.5 + g.normal.y * 0.5)))
                        .clipShape(RoundedRectangle(cornerRadius: 22 * side / 320, style: .continuous).inset(by: side * 20 / 320).offset(x: 0, y: 0))
                        .shadow(color: .black.opacity(0.28), radius: 8, x: -g.normal.x * 6, y: -g.normal.y * 6 + 4)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(drag(side: side))
            .simultaneousGesture(TapGesture().onEnded { onTap?() })
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("ステッカー")
        .accessibilityHint("はがして図鑑に追加")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { commit() }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                shine = -1
                withAnimation(.easeInOut(duration: 1.4)) { shine = 1 }
                try? await Task.sleep(for: .seconds(4))
            }
        }
        .onChange(of: disabled) { _, isDisabled in
            if !isDisabled && committed {
                Task {
                    try? await Task.sleep(for: .milliseconds(900))
                    committed = false
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { progress = 0 }
                }
            }
        }
    }

    @ViewBuilder
    private func artwork(side: CGFloat) -> some View {
        let inner = side * 280 / 320
        Group {
            if isCutout {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(width: inner, height: inner)
                    .shadow(color: .white, radius: 0.5)
                    .background {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(width: inner, height: inner)
                            .colorMultiply(.black).colorInvert()
                            .blur(radius: 0.5)
                            .scaleEffect(1.035)
                    }
            } else {
                Color.clear.frame(width: inner, height: inner)
                    .overlay { Image(uiImage: image).resizable().scaledToFill().allowsHitTesting(false) }
                    .clipShape(.rect(cornerRadius: 22 * side / 320, style: .continuous))
            }
        }
        .frame(width: side, height: side)
    }

    private func drag(side: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                guard !disabled, !committed else { return }
                if !held { held = true; Haptics.selection() }
                let dx = v.translation.width, dy = v.translation.height
                if dragAngle == nil, hypot(dx, dy) > 5 {
                    dragAngle = atan2(dy, dx)
                    angle = dragAngle ?? angle
                }
                let dir = dragAngle ?? angle
                let p = max(0, min(1, (dx * cos(dir) + dy * sin(dir)) / (side * 1.75)))
                progress = reduceMotion ? 0 : p
                if p >= 0.32 && progress > 0 { Haptics.impact(.light, intensity: 0.3) }
            }
            .onEnded { v in
                held = false
                let dir = dragAngle ?? angle
                let p = (v.translation.width * cos(dir) + v.translation.height * sin(dir)) / (side * 1.75)
                dragAngle = nil
                if p >= 0.32 { commit() } else {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.55)) { progress = 0 }
                }
            }
    }

    private func commit() {
        guard !disabled, !committed else { return }
        committed = true
        Haptics.impact(.medium)
        withAnimation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.8)) { progress = 1 }
        onPeel()
    }
}
