import SwiftUI

/// The photo capture flow from the owner-approved prototype ("card catch", docs/prototype/SPEC.md):
/// frozen photo → AI analysis with focus brackets → outlines → tags + 撮り直す → word sheet →
/// 光に変わる → d2 hologram card → tilt / fling up → the card becomes the star and leaves.
/// Layers are stacked in the prototype's z-order; prototype coordinates are mapped by `CCSpace`.
struct CardCatchView: View {
    let vm: CaptureViewModel
    /// The card has become the star: save the catch and go to the dex. False = it failed (the card returns).
    let onSend: () async -> Bool
    let onRetake: () -> Void

    @Environment(DexStore.self) private var dex
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = CardCatchModel()
    /// True while nothing on the stage moves: the timeline stops redrawing the whole screen every frame.
    @State private var framesPaused = false
    @AppStorage("reading.pref") private var readingPref: String = "zhuyin"

    let ink = Color(hex: 0x0B121A)

    var body: some View {
        GeometryReader { geo in
            // Per-frame redraws only while something moves (`CardCatchModel.needsFrames`). Reading it here as
            // well makes any observed change of the model (a transition set, the sheet, the card) re-run this
            // body and turn the frames back on at once; the stage then clears `framesPaused`.
            TimelineView(.animation(minimumInterval: nil, paused: framesPaused && !model.needsFrames(CCClock.now))) { _ in
                let now = CCClock.now
                let idle = !model.needsFrames(now)
                stage(now: now)
                    .onChange(of: idle, initial: true) { _, v in framesPaused = v }
            }
            .onAppear {
                model.space = CCSpace(size: geo.size)
                model.globalOrigin = geo.frame(in: .global).origin
                model.motion = CCMotion(calm: reduceMotion)
                model.vm = vm
                model.onSend = onSend
                model.nextNumber = { [dex] headword in
                    DexNumbering.preview(headword: headword, stickers: dex.stickers, lang: NativeAPI.targetLanguage,
                                         uid: SupabaseClient.shared.userId)
                }
                model.onHandoff = { [router] star in router.catchStar = star }
                model.onCardShown = { [router] in router.advanceTour(from: .pick, to: .detail) }
                model.begin()
            }
            .onChange(of: geo.size) { _, s in
                model.space = CCSpace(size: s)
                model.globalOrigin = geo.frame(in: .global).origin
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
        .environment(\.colorScheme, .light)
        .onChange(of: reduceMotion) { _, r in
            model.motion = CCMotion(calm: r)
            model.particles.calm = r
        }
        .onDisappear { model.end() }
    }

    // MARK: - Stage (prototype z-order)

    @ViewBuilder
    private func stage(now: Double) -> some View {
        let space = model.space
        let calm = model.motion.calm
        let _ = model.tilt.advance(to: now)
        ZStack {
            photoLayer(now: now, size: space.size)                                   // #photo
            marks(now: now).ccDesignLayer(space)                                    // .outline 22, .bracket 23
            if let c = model.category, model.catOn.value(now) > 0.001 {               // .catbg 27
                CCCategoryBackground(category: c, now: now, calm: calm).opacity(model.catOn.value(now))
            }
            Canvas { ctx, _ in model.bokeh.draw(&ctx, now: now) }                    // #bokeh 28
                .opacity(model.bokehOn.value(now))
                .ccDesignLayer(space)
                .allowsHitTesting(false)
            if model.haloOn.value(now) > 0.001 {                                    // .halo 29
                CCHalo(now: now, calm: calm).opacity(model.haloOn.value(now)).ccDesignLayer(space)
            }
            cardLayer(now: now).ccDesignLayer(space)                                // #stagec 30
            cardUI(now: now).ccDesignLayer(space)                                   // .cardui / .retake 41
            if model.aiGlow.value(now) > 0.001 {                                    // .aiglow 43
                CCAIGlow(now: now, calm: calm, k: space.k).opacity(model.aiGlow.value(now))
            }
            pickLayer(now: now).ccDesignLayer(space)                                // .hitbox 44, .pill 45, .tag 46
            sheet(now: now).ccDesignLayer(space)                                    // .sheet 50
            CCFlash(anim: model.flashAnim, now: now)                                // #flash 70
            fly(now: now).ccDesignLayer(space)                                      // #fly 76 (piece 77, star 80)
            Canvas { ctx, _ in                                                      // #fx 90
                model.particles.advance(to: now)
                model.particles.draw(&ctx)
            }
            .ccDesignLayer(space)
            .allowsHitTesting(false)
        }
        .frame(width: space.size.width, height: space.size.height)
    }

    // MARK: #photo

    @ViewBuilder
    private func photoLayer(now: Double, size: CGSize) -> some View {
        if let photo = vm.photo {
            let f = model.photoDim.value(now)
            // .dim: filter blur(18px) brightness(.42) saturate(1.3); transform scale(1.03 → 1.12)
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .scaleEffect(model.photoScale.value(now))
                .blur(radius: 18 * model.space.k * f)
                .colorMultiply(Color(white: 1 - 0.58 * f))
                .saturation(1 + 0.3 * f)
                .frame(width: size.width, height: size.height)
                .clipped()
                .allowsHitTesting(false)
        }
    }

    // MARK: .outline + .bracket

    private func marks(now: Double) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(model.objs.enumerated()), id: \.element.id) { i, o in
                if i < model.outlineOpacity.count {
                    let r = o.rect
                    Image(uiImage: o.outline)
                        .resizable()
                        .shadow(color: .rgba(140, 200, 255, 0.95), radius: 2.5)
                        .shadow(color: .rgba(40, 120, 255, 0.6), radius: 8)
                        .opacity(outlineOpacity(i, now: now))
                        .ccPlace(CGRect(x: r.minX - 12, y: r.minY - 12, width: r.width + 24, height: r.height + 24))
                }
            }
            if model.bracketOn, let v = model.bracketRect?.sample(now) {
                let o = model.bracketOpacity?.sample(now)?.first ?? 0
                let pulse = model.bracketPulse?.sample(now)?.first ?? 1
                CCBracket()
                    .scaleEffect(pulse)
                    .opacity(max(0, min(1, o)))
                    .ccPlace(CGRect(x: v[0], y: v[1], width: v[2], height: v[3]))
            }
        }
        .frame(width: CCSpace.w, height: CCSpace.h, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// The outline's opacity transition, with `.pulse` (opulse 2 s: down to .5 at 50%, ease-in-out).
    private func outlineOpacity(_ i: Int, now: Double) -> Double {
        let base = model.outlineOpacity[i].value(now)
        guard let ps = model.outlinePulseStart else { return base }
        let p = (now - ps).truncatingRemainder(dividingBy: 2) / 2
        if p < 0.5 { return base + (0.5 - base) * CCBezier.easeInOut(p / 0.5) }
        return 0.5 + (base - 0.5) * CCBezier.easeInOut((p - 0.5) / 0.5)
    }

    // MARK: .hitbox, .pill, .tag, .retake

    private func pickLayer(now: Double) -> some View {
        ZStack(alignment: .topLeading) {
            if model.pickUI {
                // Tapping the thing itself opens its words (the smallest box under the finger wins).
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { p in model.pickObject(at: p) }
                    .frame(width: CCSpace.w, height: CCSpace.h)
                    .accessibilityHidden(true)
            }
            pill(now: now)
                .frame(width: CCSpace.w, alignment: .center)
                .padding(.top, 112)
            if model.pickUI {
                ForEach(Array(model.objs.enumerated()), id: \.element.id) { i, o in
                    if i < model.tagScale.count, i < model.tagOpacity.count {
                        tag(o, now: now)
                            .onTapGesture { model.pickObject(i) }
                            .tourAnchor(.pick, if: i == 0 && model.phase == .pick)
                            .scaleEffect(0.5 + 0.5 * model.tagScale[i].value(now))
                            .opacity(model.tagOpacity[i].value(now))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                            .position(o.tagCenter)
                    }
                }
            }
        }
        .frame(width: CCSpace.w, height: CCSpace.h, alignment: .topLeading)
    }

    /// `.pill`: white 90% frosted capsule, the turning blue `.spark`, the title (and the sub line after).
    private func pill(now: Double) -> some View {
        HStack(spacing: 10) {
            CCSpark(now: now, calm: model.motion.calm)
            VStack(alignment: .leading, spacing: 0) {
                Text(model.pillTitle).font(.system(size: 14, weight: .bold)).foregroundStyle(ink)
                if let sub = model.pillSub {
                    Text(sub).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Color(hex: 0x5C646F))
                }
            }
            .lineLimit(1)
            .fixedSize()
        }
        .padding(.leading, 10)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.9), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.2), radius: 13, y: 8)
        .offset(y: -10 * (1 - model.pillShift.value(now)))
        .opacity(model.pillOpacity.value(now))
        .allowsHitTesting(false)
    }

    /// `.tag`: white capsule, the blue dot with its ring, the object's name (13 pt 800).
    private func tag(_ o: CardCatchModel.Obj, now: Double) -> some View {
        // @keyframes ring: box-shadow 0 0 0 0 → 0 0 0 10px, rgba(42,155,255,.55 → 0), 1.6 s ease-out
        let p = model.motion.calm ? 1 : CCBezier.easeOut(now.truncatingRemainder(dividingBy: 1.6) / 1.6)
        return HStack(spacing: 7) {
            Circle()
                .fill(Color(hex: 0x2A9BFF))
                .frame(width: 10, height: 10)
                .background(Circle().fill(Color.rgba(42, 155, 255, 0.55 * (1 - p))).frame(width: 10 + 20 * p, height: 10 + 20 * p))
            Text(o.name)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(ink)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.95), in: Capsule())
        .shadow(color: .rgba(0, 30, 80, 0.3), radius: 12, y: 8)
        .contentShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: .sheet (word choice)

    @ViewBuilder
    private func sheet(now: Double) -> some View {
        let t = model.sheetT.value(now)
        if let i = model.sheetObj, model.objs.indices.contains(i), t > -0.5 {
            let o = model.objs[i]
            let hidden = 1 - t
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(L("「\(o.name)」をどの言葉で集める？"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(ink)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Button { model.closeSheet() } label: {
                        CCSVGPath(d: CCIcons.cross)
                            .stroke(ink, style: StrokeStyle(lineWidth: 2.4 * 18 / 24, lineCap: .round))
                            .frame(width: 18, height: 18)
                            .frame(width: 32, height: 32)
                            .background(Color.rgba(237, 242, 248, 0.9), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("閉じる"))
                }
                .padding(.top, 2)
                .padding(.horizontal, 4)
                .padding(.bottom, 10)
                VStack(spacing: 0) {
                    ForEach(Array(o.source.words.enumerated()), id: \.offset) { k, w in
                        wordRow(w, index: k, now: now).padding(.top, 8)
                    }
                }
                .tourAnchor(.pick, if: model.phase == .word)
            }
            .padding(16)
            .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 28, style: .circular))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .circular))
            .shadow(color: .black.opacity(0.28), radius: 22, y: 14)
            .visualEffect { content, proxy in content.offset(y: (proxy.size.height + 60) * hidden) }
            .padding(.horizontal, 12)
            .padding(.bottom, 28)
            .frame(width: CCSpace.w, height: CCSpace.h, alignment: .bottom)
            .allowsHitTesting(model.phase == .word)
        }
    }

    /// `.wrow`: 32 pt word with zhuyin, the meaning (pinyin only when no zhuyin is drawn), the blue speaker.
    /// Rows rise in 90 ms apart (300 ms, delay 90 + n·90, cubic-bezier(.2,1,.3,1)).
    private func wordRow(_ w: Candidate, index k: Int, now: Double) -> some View {
        let enter: [Double] = {
            guard !model.motion.calm else { return [1, 0, 1] }
            let a = CCAnim([[0, 10, 0.97], [1, 0, 1]], duration: 0.3, delay: 0.09 + Double(k + 1) * 0.09,
                           easing: CCBezier(0.2, 1, 0.3, 1), fill: .backwards, start: model.sheetOpenedAt)
            return a.sample(now) ?? [1, 0, 1]
        }()
        let zyOn = CCZhuyinWord.zyOn(headword: w.headword, zhuyin: w.zhuyin, readingPref: readingPref)
        return Button { model.chooseWord(w) } label: {
            HStack(spacing: 12) {
                CCZhuyinWord(headword: w.headword, zhuyin: w.zhuyin, pinyin: w.pinyin, size: 32, weight: .medium, color: ink)
                VStack(alignment: .leading, spacing: 2) {
                    if !zyOn, CCZhuyinWord.isMandarin, !w.pinyin.isEmpty {
                        Text(w.pinyin).font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: 0x0053D4))
                    }
                    Text(ReaderLanguage.shown(w.meaningJa))
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: 0x5C646F))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Color.clear.frame(width: 40, height: 40)   // the speaker sits here (overlay below)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .circular))
            .background(RoundedRectangle(cornerRadius: 19.5, style: .circular).fill(Color(hex: 0xE3E9F0)).padding(-1.5))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .circular))
        }
        .buttonStyle(CCPressStyle())
        .overlay(alignment: .trailing) {
            // `.sp`: say(w.zh) without choosing the word
            Button { SoundService.shared.speak(w.headword) } label: {
                CCSpeakerIcon(waves: 2, color: .white)
                    .frame(width: 18, height: 18)
                    .frame(width: 40, height: 40)
                    .background(ccLinear(135, [.init(color: Color(hex: 0x2A9BFF), location: 0), .init(color: Color(hex: 0x0060E0), location: 1)],
                                         size: CGSize(width: 40, height: 40)), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .accessibilityLabel(L("発音を聞く"))
        }
        .opacity(enter[0])
        .offset(y: enter[1])
        .scaleEffect(enter[2])
    }

    // MARK: The card (#stagec)

    @ViewBuilder
    private func cardLayer(now: Double) -> some View {
        let c = CardCatchModel.cardRect
        ZStack(alignment: .topLeading) {
            if model.cardVisible, let e = model.entry {
                let pose = model.pose(now)
                let wrap = model.wrapAnim?.sample(now) ?? [1, 0, 1]
                let t = model.tilt
                let m: CGPoint = MotionService.shared.isLive ? MotionService.shared.tilt : .zero
                let fx: Double = max(-1, min(1, (t.mx - 50) / 50 + Double(m.x)))
                let fy: Double = max(-1, min(1, (t.my - 50) / 50 + Double(m.y)))
                let foil = CGPoint(x: fx, y: fy)
                let face = CCCardFace(entry: e, tilt: foil, mx: t.mx, my: t.my, shine: t.shine, now: now,
                                      starsOrigin: model.starsOrigin, sweepStart: model.sweepStart, calm: model.motion.calm)
                CCCardStack(entry: e, pose: pose, face: face)
                    .opacity(model.cardOpacity(now))
                    .scaleEffect(wrap[2])
                    .offset(y: wrap[1])
                    .opacity(wrap[0])
                    .ccPlace(c)
                    .allowsHitTesting(false)
                if model.phase == .card {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { g in model.dragChanged(start: g.startLocation, location: g.location) }
                            .onEnded { _ in model.dragEnded() })
                        .ccPlace(c)
                }
            }
            // The tour's "peel" step: the card and the button that sends it.
            Color.clear
                .frame(width: c.width, height: 494)
                .tourAnchor(.peel, if: model.uiShown)
                .allowsHitTesting(false)
                .offset(x: c.minX, y: c.minY)
        }
        .frame(width: CCSpace.w, height: CCSpace.h, alignment: .topLeading)
    }

    // MARK: .cardui + .retake

    private func cardUI(now: Double) -> some View {
        ZStack(alignment: .top) {
            if model.uiShown {
                let a = model.uiAnim?.sample(now) ?? [1, 0]
                VStack(spacing: 10) {
                    Text(L("カードを動かしてみよう・上にはじいて図鑑へ"))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                        .allowsHitTesting(false)
                    HStack(spacing: 12) {
                        Button { if let w = vm.picked { SoundService.shared.speak(w.headword) } } label: {
                            CCSpeakerIcon(waves: 1, color: Color(hex: 0x0060E0))
                                .frame(width: 20, height: 20)
                                .frame(width: 46, height: 46)
                                .background(Color.white.opacity(0.92), in: Circle())
                                .shadow(color: .black.opacity(0.25), radius: 8, y: 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("もう一度発音を聞く"))
                        .tourAnchor(.headword)
                        Button { model.send() } label: {
                            HStack(spacing: 8) {
                                CCSVGPath(d: CCIcons.arrowUp)
                                    .stroke(.white, style: StrokeStyle(lineWidth: 2.4 * 18 / 24, lineCap: .round, lineJoin: .round))
                                    .frame(width: 18, height: 18)
                                Text(L("図鑑に入れる"))
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundStyle(.white)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 28)
                            .background(ccLinear(135, [.init(color: Color(hex: 0x2A9BFF), location: 0), .init(color: Color(hex: 0x0060E0), location: 1)],
                                                 size: CGSize(width: 190, height: 50)), in: Capsule())
                            .shadow(color: .rgba(0, 96, 224, 0.45), radius: 13, y: 10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("card.catch")
                    }
                }
                .opacity(a[0])
                .offset(y: a[1])
                .padding(.top, 566)
            }
            if model.pickUI {
                Button(L("撮り直す"), action: onRetake)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ink)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 20)
                    .background(Color.white.opacity(0.92), in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 7, y: 4)
                    .buttonStyle(.plain)
                    .frame(width: CCSpace.w, height: CCSpace.h - 44, alignment: .bottom)
            }
        }
        .frame(width: CCSpace.w, height: CCSpace.h, alignment: .top)
    }

    // MARK: #fly (piece, star)

    private func fly(now: Double) -> some View {
        ZStack(alignment: .topLeading) {
            if let p = model.piece {
                let v = p.anim.sample(now) ?? [1, 1, 1]
                Image(uiImage: p.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .colorEffect(ShaderLibrary.ccBrightness(.float(Float(v[2]))))
                    .frame(width: p.rect.width, height: p.rect.height)
                    .scaleEffect(v[0])
                    .opacity(v[1])
                    .ccPlace(p.rect)
            }
            if let s = model.star {
                let ap = s.appear.sample(now)
                let fl = s.flight?.sample(now)
                // The flight replaces the appear animation's transform; opacity only comes from appear.
                let tx = fl?[0] ?? 0, ty = fl?[1] ?? 0
                let scale = fl?[2] ?? ap?[0] ?? 1
                let rot = fl?[3] ?? ap?[1] ?? 0
                CCStarlight(size: s.size, now: now, calm: model.motion.calm)
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rot))
                    .opacity(ap?[2] ?? 1)
                    .position(x: s.center.x + tx, y: s.center.y + ty)
            }
        }
        .frame(width: CCSpace.w, height: CCSpace.h, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// `.bracket`: four white 22 pt L corners (3 pt, outer radius 12, set 3 pt outside the box) with a cyan glow.
struct CCBracket: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            Path { p in
                // centre line of a 3 pt border whose outer edge is 3 pt outside the box
                let o: CGFloat = -1.5, len: CGFloat = 20.5, r: CGFloat = 10.5
                p.move(to: CGPoint(x: o, y: o + len)); p.addLine(to: CGPoint(x: o, y: o + r))
                p.addQuadCurve(to: CGPoint(x: o + r, y: o), control: CGPoint(x: o, y: o)); p.addLine(to: CGPoint(x: o + len, y: o))
                p.move(to: CGPoint(x: w - o - len, y: o)); p.addLine(to: CGPoint(x: w - o - r, y: o))
                p.addQuadCurve(to: CGPoint(x: w - o, y: o + r), control: CGPoint(x: w - o, y: o)); p.addLine(to: CGPoint(x: w - o, y: o + len))
                p.move(to: CGPoint(x: o, y: h - o - len)); p.addLine(to: CGPoint(x: o, y: h - o - r))
                p.addQuadCurve(to: CGPoint(x: o + r, y: h - o), control: CGPoint(x: o, y: h - o)); p.addLine(to: CGPoint(x: o + len, y: h - o))
                p.move(to: CGPoint(x: w - o - len, y: h - o)); p.addLine(to: CGPoint(x: w - o - r, y: h - o))
                p.addQuadCurve(to: CGPoint(x: w - o, y: h - o - r), control: CGPoint(x: w - o, y: h - o)); p.addLine(to: CGPoint(x: w - o, y: h - o - len))
            }
            .stroke(.white, lineWidth: 3)
            .shadow(color: .rgba(100, 224, 255, 0.9), radius: 3)
        }
    }
}

/// `.wrow:active { transform: scale(.98) }` (transition .15 s).
struct CCPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
