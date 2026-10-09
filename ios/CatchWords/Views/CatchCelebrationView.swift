import SwiftUI

/// The word was chosen (owner 2026-10-09, after Gotcha / Stickr): the object's cut-out as a white-edged
/// sticker over the blurred photo, the word with its reading and meaning, its voice played once by itself,
/// and 「図鑑に追加」. The catch then goes into the dex the same way as before (`CaptureView.addToDex`).
/// Never waits for the cut-out: the photo stands in and turns into the sticker when the cut is ready.
struct CatchCelebrationView: View {
    let vm: CaptureViewModel
    /// The save started from here is still running: no second tap, no going back.
    var saving: Bool = false
    /// Saves the catch and opens the dex. False = it did not start (a notice says why; the button works again).
    let onAdd: () async -> Bool
    /// The sticker's frame on screen (global), where the star that flies into the dex starts.
    var onStickerFrame: (CGRect) -> Void = { _ in }

    @Environment(\.appReduceMotion) private var reduceMotion
    @State private var shown: Bool = false
    @State private var adding: Bool = false
    @State private var confetti: Bool = false

    private var busy: Bool { adding || saving }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width * 0.72, 320)
            ZStack {
                backdrop
                LightRays(active: shown && !reduceMotion)
                    .opacity(0.55)
                    .ignoresSafeArea()
                Confetti(active: confetti)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 8)
                    sticker(side: side)
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .global)
                        } action: { frame in
                            onStickerFrame(frame)
                        }
                        .scaleEffect(shown ? 1 : 0.55)
                        .rotationEffect(.degrees(shown ? -3 : -10))
                        .opacity(shown ? 1 : 0)
                    Spacer(minLength: 8)
                    if let c = vm.picked {
                        wordCard(c)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 10)
                            .offset(y: shown ? 0 : 40)
                            .opacity(shown ? 1 : 0)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task { await celebrate() }
        // A notice (a card that failed, a save that did not start) gives the button back.
        .onChange(of: vm.toastCount) { _, _ in if !saving { adding = false } }
        .onChange(of: saving) { _, s in if !s { adding = false } }
    }

    /// The photo, blurred and darkened (the Stickr look): the sticker is the only sharp thing.
    private var backdrop: some View {
        ZStack {
            Theme.navyDeep
            if let photo = vm.photo {
                Color.clear
                    .overlay { Image(uiImage: photo).resizable().scaledToFill().allowsHitTesting(false) }
                    .clipped()
                    .blur(radius: 28)
                    .scaleEffect(1.1)
                Color.black.opacity(0.32)
            }
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button { vm.backToCandidates() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").scaledFont(size: 14, weight: .semibold)
                    Text(L("戻る"))
                }
                .scaledFont(size: 15, weight: .semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(.white.opacity(0.14), in: Capsule())
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(PressableStyle())
            .disabled(busy)
            .opacity(busy ? 0.4 : 1)
            .accessibilityIdentifier("celebrate.back")
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func sticker(side: CGFloat) -> some View {
        if let cut = vm.cutout {
            StickerCutout(image: cut)
                .frame(maxWidth: side, maxHeight: side)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        } else if let photo = vm.photo {
            Color.clear
                .frame(width: side * 0.86, height: side * 0.86)
                .overlay { Image(uiImage: photo).resizable().scaledToFill().allowsHitTesting(false) }
                .clipShape(.rect(cornerRadius: 24, style: .continuous))
                .padding(7)
                .background(Color.white, in: .rect(cornerRadius: 30, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
                .overlay(alignment: .bottom) {
                    if vm.isCutting {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini).tint(.white)
                            Text(L("切り抜いています"))
                        }
                        .scaledFont(size: 12, weight: .medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 28)
                        .background(Theme.toastInk.opacity(0.78), in: Capsule())
                        .padding(.bottom, 16)
                        .allowsHitTesting(false)
                    }
                }
                .transition(.opacity)
        }
    }

    private func wordCard(_ c: Candidate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("新しいことばをキャッチ！"))
                .scaledFont(size: 13, weight: .bold)
                .foregroundStyle(Theme.primaryInk)
            HStack(alignment: .center, spacing: 12) {
                ZhuyinWordView(headword: c.headword, zhuyin: c.zhuyin, size: 36, weight: .semibold, pinyin: c.pinyin)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PronounceCircle(text: c.headword, size: 48)
                    .tourAnchor(.headword)
            }
            Text(meaning(c))
                .scaledFont(size: 17, weight: .medium)
                .foregroundStyle(Theme.muted)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: add) {
                HStack(spacing: 8) {
                    if busy {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "checkmark").scaledFont(size: 15, weight: .semibold)
                    }
                    Text(L("図鑑に追加")).scaledFont(size: 17, weight: .bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Theme.primary, in: Capsule())
                .shadow(color: Theme.primary.opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(PressableStyle())
            .disabled(busy)
            .accessibilityIdentifier("card.catch")
            .tourAnchor(.peel)
        }
        .padding(18)
        .background(Theme.card, in: .rect(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
    }

    /// The card's meaning once it arrives (reader language, scrubbed), else the candidate's.
    private func meaning(_ c: Candidate) -> String {
        let m = vm.details?.raw?["meaning_ja"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ReaderLanguage.shown(m, c.meaningJa)
    }

    /// The sticker pops in, a short sting and confetti, then the word is spoken once (like the card used to).
    private func celebrate() async {
        Haptics.success()
        if reduceMotion {
            shown = true
        } else {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) { shown = true }
            confetti = true
        }
        SoundService.shared.play(.sting, volume: 0.55)
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 450))
        guard !Task.isCancelled, let w = vm.picked else { return }
        SoundService.shared.speak(w.headword)
    }

    private func add() {
        guard !busy else { return }
        adding = true
        Task {
            let started = await onAdd()
            if !started { adding = false }
        }
    }
}

/// A cut-out with a white sticker edge: its silhouette drawn white underneath, nudged round in a circle.
struct StickerCutout: View {
    let image: UIImage
    var edge: CGFloat = 7

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                let a = CGFloat(i) / 12 * 2 * .pi
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .offset(x: cos(a) * edge, y: sin(a) * edge)
            }
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
        .padding(edge)
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
        .accessibilityHidden(true)
    }
}

/// Slowly turning god-rays behind the sticker (reward stage).
struct LightRays: View {
    let active: Bool
    @Environment(\.appReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || !active)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height * 0.4)
                let r = max(size.width, size.height) * 1.2
                let spin = reduceMotion ? 0 : t * 0.06
                var g = ctx
                g.addFilter(.blur(radius: 18))
                for i in 0..<14 {
                    let a = Double(i) / 14 * 2 * .pi + spin
                    let w = 0.07 + 0.03 * sin(Double(i) * 1.7)
                    var p = Path()
                    p.move(to: c)
                    p.addLine(to: CGPoint(x: c.x + cos(a - w) * r, y: c.y + sin(a - w) * r))
                    p.addLine(to: CGPoint(x: c.x + cos(a + w) * r, y: c.y + sin(a + w) * r))
                    p.closeSubpath()
                    let color = i % 2 == 0 ? Color(hex: 0x7FD8FF) : Color(hex: 0x6FE3C8)
                    g.fill(p, with: .radialGradient(Gradient(colors: [color.opacity(0.0), color.opacity(0.28), color.opacity(0)]),
                                                    center: c, startRadius: 60, endRadius: r * 0.7))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Paper confetti that bursts once and flutters down.
struct Confetti: View {
    let active: Bool
    @State private var start: Date?

    private static let colors: [Color] = [Color(hex: 0xF4B93C), Color(hex: 0x64E0FF), Color(hex: 0xFF7EB6), Color(hex: 0xA78BFA), Color(hex: 0x4ADE80), .white]

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { tl in
            Canvas { ctx, size in
                guard let start else { return }
                let t = tl.date.timeIntervalSince(start)
                guard t < 3.2 else { return }
                for i in 0..<70 {
                    let seed = Double(i)
                    let ang = seed * 2.399
                    let speed = 180 + (seed * 37).truncatingRemainder(dividingBy: 220)
                    let x0 = size.width / 2, y0 = size.height * 0.42
                    let vx = cos(ang) * speed, vy = sin(ang) * speed - 160
                    let x = x0 + vx * t * 1.1 + sin(t * 3 + seed) * 12
                    let y = y0 + vy * t + 260 * t * t
                    let alpha = max(0, 1 - t / 3.2)
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(t * (4 + seed.truncatingRemainder(dividingBy: 5)) + seed))
                    let w = 5 + seed.truncatingRemainder(dividingBy: 4), h = 3 + seed.truncatingRemainder(dividingBy: 3)
                    c.fill(Path(CGRect(x: -w / 2, y: -h / 2, width: w, height: h * abs(cos(t * 6 + seed)) + 1)),
                           with: .color(Self.colors[i % Self.colors.count].opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: active) { _, on in if on { start = Date() } }
    }
}
