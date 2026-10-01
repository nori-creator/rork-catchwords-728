import SwiftUI
import Vision

/// Full-bleed photo with a bright scan line that sweeps up and down, dissolving the image into
/// glowing motes around it (web: scan-analyzing default). "やめる" top-right, "AIが分析中…" at the bottom.
struct AnalyzingView: View {
    let photo: UIImage?
    /// Preview only: boxes to lock onto instead of asking Vision (which may not run on the simulator).
    var previewTargets: [CGRect]? = nil
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date = Date()
    /// On-device Vision (objectness saliency): where the things are, found in ~0.2 s while the
    /// server AI is still naming them. Normalized, top-left origin.
    @State private var targets: [CGRect] = []
    @State private var locked: Int = 0

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

            if let photo {
                GeometryReader { geo in
                    let frame = Self.fillRect(image: photo.size, in: geo.size)
                    ForEach(Array(targets.enumerated()), id: \.offset) { i, r in
                        FocusBrackets(active: i < locked)
                            .frame(width: r.width * frame.width, height: r.height * frame.height)
                            .position(x: frame.minX + r.midX * frame.width, y: frame.minY + r.midY * frame.height)
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
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
                        Text(L("やめる"))
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
                    Text(L("AIが分析中…"))
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 1)
                .padding(.bottom, 60)
            }
        }
        .onAppear { start = Date() }
        .task { await findTargets() }
    }

    /// Where a scaledToFill image sits inside `size`.
    static func fillRect(image: CGSize, in size: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0 else { return CGRect(origin: .zero, size: size) }
        let scale = max(size.width / image.width, size.height / image.height)
        let w = image.width * scale, h = image.height * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    private func findTargets() async {
        guard let photo, let cg = photo.normalizedOrientation().cgImage else { return }
        let found: [CGRect]
        if let previewTargets {
            found = previewTargets
        } else {
            found = await Task.detached(priority: .userInitiated) {
                let request = VNGenerateObjectnessBasedSaliencyImageRequest()
                try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([request])
                let objects = (request.results?.first?.salientObjects ?? [])
                    .sorted { $0.confidence > $1.confidence }
                    .prefix(3)
                // Vision is bottom-left origin; flip to top-left. Skip slivers.
                return objects.map { o in
                    let b = o.boundingBox
                    return CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height)
                }.filter { $0.width > 0.08 && $0.height > 0.08 }
            }.value
        }
        guard !found.isEmpty else { return }
        targets = found
        for i in found.indices {
            try? await Task.sleep(for: .milliseconds(i == 0 ? 250 : 380))
            if reduceMotion { locked = found.count; break }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) { locked = i + 1 }
            Haptics.selection()
        }
    }
}

/// Camera-style focus brackets: start wide and faint, snap in and brighten when they lock.
struct FocusBrackets: View {
    let active: Bool
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let arm = min(w, h) * 0.22
            Path { p in
                for (cx, cy, sx, sy) in [(0.0, 0.0, 1.0, 1.0), (w, 0.0, -1.0, 1.0), (0.0, h, 1.0, -1.0), (w, h, -1.0, -1.0)] {
                    p.move(to: CGPoint(x: cx, y: cy + sy * arm))
                    p.addLine(to: CGPoint(x: cx, y: cy))
                    p.addLine(to: CGPoint(x: cx + sx * arm, y: cy))
                }
            }
            .stroke(Color(hex: 0xBFEFFF), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .shadow(color: Theme.cyan.opacity(0.8), radius: 6)
        }
        .scaleEffect(active ? (breathe ? 1.02 : 1) : 1.25)
        .opacity(active ? 1 : 0)
        .onChange(of: active) { _, on in
            guard on, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { breathe = true }
        }
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
