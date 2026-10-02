import SwiftUI

/// 「ここで撮った思い出」 over the live camera preview: words caught within ~60 m float as small
/// polaroids / cut-outs in the direction of the spot where they were photographed — x from the compass
/// (bearing − heading across the camera's field of view), y from the phone's tilt (the horizon line),
/// bigger when closer. Memories outside the view collapse to edge chips (‹ 2 / 2 ›). Tapping a card
/// opens that word (`onOpen`).
///
/// It is an approximation, not ARKit tracking (the capture session owns the camera, and two camera
/// sessions can't run at once): GPS ±5–20 m and compass ±10–20° mean a card lands near the right
/// direction, not pixel-exactly on the object. See `MemoryLensService`.
struct MemoryLensOverlay: View {
    /// Displayed camera zoom (1× = the wide lens): zooming in narrows the angle the cards spread over.
    var zoom: CGFloat = 1
    let onOpen: (Sticker) -> Void

    @Environment(DexStore.self) private var dex
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lens = MemoryLensService()
    /// The learner's choice on the chip for this camera visit; nil = default (on when there are memories).
    @State private var userOn: Bool?

    /// Horizontal field of view of the 1× back camera as the portrait preview shows it (degrees). The
    /// wide lens is ~70° across its long side; in portrait the short side runs across the screen
    /// (~55–60°) and aspect-fill cropping narrows it a little more. Next to the compass error this
    /// approximation does not matter.
    static let horizontalFOV: Double = 60
    /// Card sizes (pt) for a memory right here and one at the edge of the radius.
    static let nearSize: CGFloat = 138
    static let farSize: CGFloat = 70

    private typealias Memory = MemoryLensService.Memory

    private struct Placed: Identifiable {
        let memory: Memory
        let point: CGPoint
        let size: CGFloat
        var id: String { memory.id }
    }

    private struct Layout {
        var cards: [Placed] = []
        var left = 0
        var right = 0
    }

    var body: some View {
        let memories = lens.nearby
        let isOn = userOn ?? true
        GeometryReader { geo in
            if isOn, !memories.isEmpty {
                let placed = layout(memories, in: geo.size)
                ZStack {
                    // Far cards first, so nearer ones sit on top.
                    ForEach(Array(placed.cards.reversed())) { p in
                        MemoryLensCard(memory: p.memory, size: p.size, bobbing: !reduceMotion) { onOpen(p.memory.sticker) }
                            .position(p.point)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                // Keeps the horizon level when the phone is tilted sideways.
                .rotationEffect(.radians(lens.heading == nil ? 0 : -lens.roll))
                .overlay(alignment: .leading) {
                    if placed.left > 0 { edgeChip(count: placed.left, leading: true) }
                }
                .overlay(alignment: .trailing) {
                    if placed.right > 0 { edgeChip(count: placed.right, leading: false) }
                }
                .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if !memories.isEmpty {
                toggleChip(count: memories.count, isOn: isOn)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isOn)
        .animation(.easeInOut(duration: 0.35), value: memories.map(\.id))
        .onAppear {
            lens.setStickers(dex.stickers)
            lens.start()
        }
        .onDisappear { lens.stop() }
        .onChange(of: dex.stickers) { _, list in lens.setStickers(list) }
    }

    // MARK: Placement

    private func layout(_ memories: [Memory], in size: CGSize) -> Layout {
        var out = Layout()
        let w = size.width, h = size.height
        guard w > 0, h > 0 else { return out }
        let halfH = (Self.horizontalFOV / 2) * .pi / 180
        // Zoom narrows the view: tan(half angle) shrinks by the zoom factor.
        let tanHalfH = tan(halfH) / max(1, Double(zoom))
        let tanHalfV = tanHalfH * Double(h / w)
        // Camera tilted up → the horizon moves down the screen.
        let pitch = max(-1.4, min(1.4, lens.pitch))
        let horizonY = h / 2 + (h / 2) * CGFloat(tan(pitch) / tanHalfV)
        let radius = max(1, lens.radius)

        for (i, m) in memories.enumerated() {
            let t = CGFloat(min(1, max(0, m.distance / radius)))
            let s = Self.nearSize + (Self.farSize - Self.nearSize) * t
            // Kept clear of the top chip and the zoom pills, so a card never hides under them.
            let minY = s / 2 + 52, maxY = max(minY, h - s / 2 - 60)
            let y = min(maxY, max(minY, horizonY + s * 0.1))

            guard let heading = lens.heading else {
                // No compass yet (or none on this device): a row along the horizon, closest in the middle.
                let n = memories.count
                let slot = n == 1 ? 0.5 : 0.12 + 0.76 * Double(i) / Double(n - 1)
                out.cards.append(Placed(memory: m, point: CGPoint(x: w * CGFloat(slot), y: y), size: s * 0.8))
                continue
            }
            let rel = MemoryLensService.relativeAngle(m.bearing, heading)
            // Behind or far to the side: only an edge chip.
            guard abs(rel) < 80 else {
                if rel < 0 { out.left += 1 } else { out.right += 1 }
                continue
            }
            let x = w / 2 + (w / 2) * CGFloat(tan(rel * .pi / 180) / tanHalfH)
            // Fully outside the view (with the card's own width), so a card slides off the edge
            // smoothly before it turns into a chip — no flicker at the boundary.
            if x + s / 2 < 0 { out.left += 1; continue }
            if x - s / 2 > w { out.right += 1; continue }
            // Several memories in the same direction: fan the later (farther) ones up and to the side.
            let stacked = out.cards.filter { abs($0.point.x - x) < s * 0.5 }.count
            let point = CGPoint(x: x + CGFloat(stacked) * 14, y: max(s / 2 + 40, y - CGFloat(stacked) * s * 0.3))
            out.cards.append(Placed(memory: m, point: point, size: s))
        }
        return out
    }

    // MARK: Chips

    private func toggleChip(count: Int, isOn: Bool) -> some View {
        Button {
            Haptics.selection()
            userOn = !isOn
        } label: {
            Label(L("ここで撮った思い出 \(count)"), systemImage: isOn ? "photo.stack.fill" : "photo.stack")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn ? Theme.gold : .white.opacity(0.85))
                .padding(.horizontal, 12)
                .frame(minHeight: 30)
                .background(.black.opacity(0.35), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .accessibilityValue(isOn ? L("表示中") : L("非表示"))
    }

    private func edgeChip(count: Int, leading: Bool) -> some View {
        HStack(spacing: 3) {
            if leading { Image(systemName: "chevron.left") }
            Text("\(count)").monospacedDigit()
            if !leading { Image(systemName: "chevron.right") }
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(minHeight: 30)
        .background(.black.opacity(0.4), in: Capsule())
        .overlay(Capsule().stroke(Theme.gold.opacity(0.6), lineWidth: 1))
        .padding(.horizontal, 8)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(leading ? L("左に思い出 \(count)") : L("右に思い出 \(count)"))
    }
}

/// One memory: the cut-out on its own (it already has a shape), or the photo as a small polaroid,
/// with the word and the day it was caught.
private struct MemoryLensCard: View {
    let memory: MemoryLensService.Memory
    let size: CGFloat
    let bobbing: Bool
    let onTap: () -> Void

    @Environment(DexStore.self) private var dex
    @State private var up = false

    private var sticker: Sticker { memory.sticker }
    /// Stable per sticker (unlike `hashValue`), for each card's own tilt and bobbing rhythm.
    private var seed: Int { sticker.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } }
    private var dateText: String {
        sticker.takenAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                picture
                VStack(spacing: 0) {
                    Text(sticker.word?.headword ?? "")
                        .font(.system(size: max(11, size * 0.11), weight: .bold))
                        .lineLimit(1)
                    Text(dateText)
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.8)
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.black.opacity(0.45), in: .rect(cornerRadius: 8, style: .continuous))
                .fixedSize()
            }
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .offset(y: bobbing && up ? -5 : 0)
        .onAppear {
            guard bobbing else { return }
            // Each card on its own rhythm, so they drift instead of pulsing together.
            let phase = Double(seed % 100) / 100
            withAnimation(.easeInOut(duration: 2.2 + phase).repeatForever(autoreverses: true).delay(phase)) { up = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("\(sticker.word?.headword ?? "")、\(dateText)に撮影、約\(Int(memory.distance.rounded()))m"))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var picture: some View {
        if let cut = sticker.cutoutImageUrl {
            StickerImage(path: cut, url: dex.url(for: cut), contentMode: .fit)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
        } else {
            let path = sticker.objectImageUrl
            let inner = size * 0.86
            Color.white.opacity(0.12)
                .frame(width: inner, height: inner)
                .overlay { StickerImage(path: path, url: dex.url(for: path), contentMode: .fill).allowsHitTesting(false) }
                .clipShape(.rect)
                .padding(size * 0.05)
                .padding(.bottom, size * 0.08)
                .background(.white, in: .rect(cornerRadius: 3))
                .rotationEffect(.degrees(Double(seed % 7) - 3))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        }
    }
}
