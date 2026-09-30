import SwiftUI

/// Full-bleed photo with a bright scan line that sweeps up and down, dissolving the image into
/// glowing motes around it (web: scan-analyzing default). "やめる" top-right, "AIが分析中…" at the bottom.
struct AnalyzingView: View {
    let photo: UIImage?
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date = Date()

    var body: some View {
        ZStack {
            Theme.navyDeep.ignoresSafeArea()
            if let photo {
                Color.clear
                    .overlay { Image(uiImage: photo).resizable().scaledToFill().allowsHitTesting(false) }
                    .clipped()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.12).ignoresSafeArea())
            } else {
                MachineBackground()
            }

            TimelineView(.animation(paused: reduceMotion)) { tl in
                let t = reduceMotion ? 0.9 : tl.date.timeIntervalSince(start)
                Canvas { ctx, size in ScanField.draw(ctx: ctx, size: size, t: t) }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Text("やめる")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 44)
                            .background(.black.opacity(0.25), in: Capsule())
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").symbolEffect(.pulse, isActive: !reduceMotion)
                    Text("AIが分析中…")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 1)
                .padding(.bottom, 60)
            }
        }
        .onAppear { start = Date() }
    }
}

enum ScanField {
    private static func hash(_ n: Int, _ salt: Int) -> Double {
        var x = UInt64(truncatingIfNeeded: n &* 374761393 &+ salt &* 668265263)
        x = (x ^ (x >> 13)) &* 1274126177
        x ^= x >> 16
        return Double(x % 10_000) / 10_000
    }

    static func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let period = 3.2
        let phase = (t.truncatingRemainder(dividingBy: period)) / period
        let eased = 0.5 - 0.5 * cos(phase * 2 * .pi)
        let lineY = size.height * (0.12 + 0.72 * eased)
        let band = size.height * 0.22
        let goingDown = phase < 0.5

        for i in 0..<1100 {
            let bx = hash(i, 1) * size.width
            let by = hash(i, 2) * size.height
            let d = by - lineY
            // Motes trail behind the line (the side it has just passed).
            let behind = goingDown ? -d : d
            guard behind > -band * 0.12, behind < band else { continue }
            let k = 1 - max(0, behind) / band
            let a = pow(k, 1.6)
            let wobble = sin(t * 2.2 + Double(i)) * 2.4
            let lift = (goingDown ? -1.0 : 1.0) * (1 - k) * 10
            let r = 1.2 + hash(i, 3) * 2.4 * (0.5 + k)
            let rect = CGRect(x: bx + wobble - r, y: by + lift - r, width: r * 2, height: r * 2)
            let color = hash(i, 4) > 0.55 ? Color.white : Color(hex: 0xA8E4FF)
            ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(a * 0.95)))
        }

        var glow = ctx
        glow.addFilter(.blur(radius: 10))
        glow.fill(Path(CGRect(x: 0, y: lineY - 7, width: size.width, height: 14)), with: .color(Color(hex: 0x9FE3FF).opacity(0.8)))
        ctx.fill(Path(roundedRect: CGRect(x: 8, y: lineY - 1.5, width: size.width - 16, height: 3), cornerRadius: 1.5),
                 with: .color(.white))
    }
}
