import SwiftUI

/// The card-catch flow's state and choreography — a line-by-line port of the owner-approved prototype
/// (docs/prototype/cardcatch-src.html): analyze + anaFocus → showPick → pickObject → chooseWord →
/// formLight → the card + cardui + tilt → sendToDex (first half). All positions are prototype design
/// points (390×844); `CardCatchView` maps them onto the real screen.
@MainActor @Observable
final class CardCatchModel {
    enum Phase { case analyze, pick, word, card, sending }

    /// One object as shown: its design-space rect (`toScreen(img, o.bbox)`) and its outline image.
    struct Obj: Identifiable {
        let id: Int
        let source: CatchObject
        let rect: CGRect
        let outline: UIImage
        let name: String
        /// formLight's piece when there is no cut-out (`cropFrom`), drawn off the main thread from the start.
        let piece: Task<UIImage, Never>?
    }

    struct Piece {
        let image: UIImage
        let rect: CGRect
        let anim: CCAnim      // [scale, opacity, brightness]
    }

    struct Star {
        let center: CGPoint
        let size: CGFloat
        let appear: CCAnim    // [scale, rotate°, opacity]
        var flight: CCAnim?   // [translateX, translateY, scale, rotate°]
    }

    // MARK: Setup

    @ObservationIgnored weak var vm: CaptureViewModel?
    @ObservationIgnored var onSend: (() async -> Bool)?
    @ObservationIgnored var onCardShown: (() -> Void)?
    /// The card's No. for a headword (DexNumbering: base 001–100, else the next number from 101).
    @ObservationIgnored var nextNumber: (String) -> Int = { _ in 1 }
    /// The star is about to leave this screen (the save is starting): where it is, for the dex landing.
    @ObservationIgnored var onHandoff: ((CatchStar) -> Void)?
    /// This view's origin in global coordinates (the star's hand-off point is given in global coordinates).
    @ObservationIgnored var globalOrigin: CGPoint = .zero
    var space = CCSpace(size: .zero)
    var motion = CCMotion(calm: false)
    @ObservationIgnored private var runId = 0
    @ObservationIgnored private var started = false
    @ObservationIgnored private var holdsMotion = false

    // Per-frame state (never observed: stepped while drawing).
    let tilt = CCTilt()
    let particles = CCParticles()
    let bokeh = CCBokeh()

    var phase: Phase = .analyze

    // #photo: .frozen → .dim (filter .9 s, transform 1.4 s, cubic-bezier(.2,.8,.2,1))
    var photoDim = CCTransition(0)
    var photoScale = CCTransition(1.03)

    // .pill / .aiglow
    var pillOpacity = CCTransition(0)
    var pillShift = CCTransition(0)
    var pillTitle = ""
    var pillSub: String?
    var aiGlow = CCTransition(0)

    // objects, .outline, .bracket
    var objs: [Obj] = []
    var outlineOpacity: [CCTransition] = []
    var outlinePulseStart: Double?
    var bracketOn = false
    var bracketRect: CCAnim?
    var bracketOpacity: CCAnim?
    var bracketPulse: CCAnim?

    // showPick: .tag / .hitbox / .retake
    var pickUI = false
    var tagScale: [CCTransition] = []
    var tagOpacity: [CCTransition] = []
    /// Each tag's bottom centre (design points), laid out once per `showPick` so no two tags overlap.
    var tagSpots: [CGPoint] = []

    // .sheet
    var sheetT = CCTransition(0)
    var sheetObj: Int?
    var sheetOpenedAt: Double = 0

    // reveal
    var category: CCCategory?
    var catOn = CCTransition(0)
    var haloOn = CCTransition(0)
    var bokehOn = CCTransition(0)
    var piece: Piece?
    var star: Star?
    var flashAnim: CCAnim?

    // the card
    var entry: CCCardEntry?
    var cardVisible = false
    var cardSpin: CCAnim?     // [rotateY°, scale, opacity]
    var cardLift: CCAnim?     // [translateY, rotateX°, rotateY°, scale]
    var wrapAnim: CCAnim?     // [opacity, translateY, scale]
    var starsOrigin: Double = 0
    var sweepStart: Double?
    var uiShown = false
    var uiAnim: CCAnim?       // [opacity, translateY]

    @ObservationIgnored private var chosen: (obj: Obj, word: Candidate)?
    @ObservationIgnored private var trailToken = 0

    /// `CL, CT` — the card's place on the reveal screen; its centre is (195, 346).
    static let cardRect = CGRect(x: 55, y: 150, width: 280, height: 392)

    // MARK: Lifecycle

    func begin() {
        guard !started else { return }
        started = true
        particles.calm = motion.calm
        runId += 1
        let my = runId
        Task { await runAnalysis(my) }
    }

    /// The view went away (re-encounter, failure, retake, the dex): stop every running sequence.
    func end() {
        runId += 1
        tilt.stop()
        bokeh.stop()
        releaseMotion()
    }

    /// Whether anything on the stage changes with time at `now`; false lets the view pause its per-frame
    /// redraws (any observed change wakes it again). Always true from the light onwards: the card follows the
    /// device's tilt (motion updates are not observed), and particles, bokeh and the halo move on their own.
    /// Before that, the endless loops (outline pulse, tag rings, the pill's spark, the AI glow, the category
    /// colour turning) count only without Reduce Motion, and every transition counts until it has settled.
    func needsFrames(_ now: Double) -> Bool {
        if phase == .card || phase == .sending || cardVisible || star != nil || piece != nil || !particles.isEmpty {
            return true
        }
        if !motion.calm, outlinePulseStart != nil || pickUI || pillOpacity.to > 0 || aiGlow.to > 0 || catOn.to > 0
            || haloOn.to > 0 || bokehOn.to > 0 {
            return true
        }
        let transitions = [photoDim, photoScale, pillOpacity, pillShift, aiGlow, sheetT, catOn, haloOn, bokehOn]
            + outlineOpacity + tagScale + tagOpacity
        if transitions.contains(where: { now < $0.start + $0.duration }) { return true }
        let anims = [bracketRect, bracketOpacity, bracketPulse, flashAnim, cardSpin, cardLift, wrapAnim, uiAnim]
        if anims.contains(where: { $0.map { !$0.finished(at: now) } ?? false }) { return true }
        // The word rows rise in one by one after the sheet opens (up to ~0.8 s).
        return sheetObj != nil && now < sheetOpenedAt + 1
    }

    private func wait(_ seconds: Double) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(for: .seconds(seconds))
    }

    private func play(_ sfx: SFX) { SoundService.shared.playLayered(sfx) }

    private func acquireMotion() {
        guard !holdsMotion else { return }
        holdsMotion = true
        MotionService.shared.acquire()
    }

    private func releaseMotion() {
        guard holdsMotion else { return }
        holdsMotion = false
        MotionService.shared.release()
    }

    // MARK: 2. Analysis (`analyze` + `anaFocus`)

    private var objectsReady: Bool {
        guard let vm else { return false }
        return vm.step == .select && !vm.objects.isEmpty
    }

    private func runAnalysis(_ my: Int) async {
        // shoot(): the photo freezes; the analysis starts 260 ms after the shutter.
        let elapsed = vm?.shotAt.map { CCClock.now - $0 } ?? 0
        await wait(motion.sleep(max(0, 260 - elapsed * 1000)))
        guard my == runId else { return }
        // The answer is not known yet (the prototype's camera-roll path): the brackets keep looking.
        while my == runId, vm != nil, !objectsReady {
            // useRollPhoto: no objects → the pill and the glow go, a toast, 600 ms, back to the camera.
            if let vm, vm.step == .select, vm.objects.isEmpty {
                await nothingFound(my)
                return
            }
            await analyze(my, objects: [], waiting: true)
        }
        guard my == runId, vm != nil else { return }
        await buildObjects()
        guard my == runId else { return }
        await analyze(my, objects: objs, waiting: false)
        guard my == runId else { return }
        showPick()
    }

    private func nothingFound(_ my: Int) async {
        setPill(false)
        aiGlow.set(0, duration: motion.transition(600))
        vm?.showToast(L("写っている物を見つけられませんでした。別の写真で試してください。"))
        await wait(motion.sleep(600))
        guard my == runId else { return }
        vm?.reset()
    }

    private func buildObjects() async {
        guard let vm, let photo = vm.photo else { return }
        let size = space.size
        let pw = max(1, photo.size.width), ph = max(1, photo.size.height)
        // coverMap(): the photo fills the screen (object-fit: cover)
        let s = max(size.width / pw, size.height / ph)
        let ox = (size.width - pw * s) / 2, oy = (size.height - ph * s) / 2
        let list = vm.objects
        let rects = list.map { o -> CGRect in
            let real = CGRect(x: ox + o.box.minX * pw * s, y: oy + o.box.minY * ph * s,
                              width: o.box.width * pw * s, height: o.box.height * ph * s)
            return space.toDesign(real)
        }
        // outlineEl: rendered off the main thread (each one composites the cut-out 21 times).
        let jobs = zip(list, rects).map { ($0.cut, $1.size) }
        let outlines = await Task.detached(priority: .userInitiated) {
            jobs.map { CCImages.outline(cut: $0.0, size: $0.1) }
        }.value
        // formLight's piece without a cut-out redraws the photo: started off the main thread now, long before
        // a word is chosen, so it is ready when the light forms (not awaited here: the timing stays the same).
        let pieces: [Task<UIImage, Never>?] = list.map { o in
            guard o.cut == nil else { return nil }
            let box = o.box
            return Task.detached(priority: .userInitiated) { CCImages.cropFrom(photo: photo, box: box) }
        }
        objs = list.indices.map { i -> Obj in
            let o = list[i]
            let shown = ReaderLanguage.shown(o.words[0].meaningJa)
            return Obj(id: o.id, source: o, rect: rects[i], outline: outlines[i],
                       name: shown.isEmpty ? o.words[0].headword : shown, piece: pieces[i])
        }
    }

    private func analyze(_ my: Int, objects list: [Obj], waiting: Bool) async {
        setPill(true)
        pillTitle = L("AIが分析中…")
        pillSub = nil
        aiGlow.set(1, duration: motion.transition(600))
        // marks.innerHTML = "" — new outlines (hidden until the brackets reach them)
        outlineOpacity = list.map { _ in CCTransition(0) }
        outlinePulseStart = nil
        bracketOn = false
        play(.ccScanStart)
        await focus(my, list)
        if !waiting {
            aiGlow.set(0, duration: motion.transition(600))
            pillTitle = list.isEmpty ? L("見つかりませんでした") : L("\(list.count)つ見つかりました")
            pillSub = L("タップして選んでください")
            if !list.isEmpty { play(.ccFound) }
        }
    }

    private func setPill(_ on: Bool) {
        pillOpacity.set(on ? 1 : 0, duration: motion.transition(350))
        pillShift.set(on ? 1 : 0, duration: motion.transition(450), easing: CCBezier(0.2, 1.2, 0.3, 1))
    }

    /// anaFocus: the four white corners frame the whole view, then hop to each object (+14 pt) on a spring.
    private func focus(_ my: Int, _ list: [Obj]) async {
        let base: [Double] = [26, 120, 338, 520]
        bracketRect = CCAnim([base], duration: 0.000_001, fill: .forwards)
        bracketOpacity = CCAnim([[0]], duration: 0.000_001, fill: .forwards)
        bracketPulse = nil
        bracketOn = true
        await setBracket(base, ms: 260)
        if list.isEmpty {
            for h in [[60.0, 220, 150, 150], [190.0, 420, 140, 140]] {
                await setBracket(h, ms: 440)
                await wait(motion.sleep(160))
            }
        }
        for (i, o) in list.enumerated() {
            guard my == runId else { return }
            let r = o.rect
            await setBracket([Double(r.minX - 14), Double(r.minY - 14), Double(r.width + 28), Double(r.height + 28)], ms: 540)
            play(.ccTick)
            if i < outlineOpacity.count { outlineOpacity[i].set(1, duration: motion.transition(500)) }
            bracketPulse = CCAnim([[1], [0.94], [1]], duration: motion.d(260))
            await wait(motion.sleep(400))
        }
        bracketOpacity = CCAnim([[1], [0]], duration: motion.d(300), fill: .forwards)
        await wait(motion.d(300))
        bracketOn = false
    }

    private func setBracket(_ r: [Double], ms: Double) async {
        let now = CCClock.now
        let fromR = bracketRect?.sample(now) ?? r
        let fromO = bracketOpacity?.sample(now)?.first ?? 0
        let e = CCBezier(0.3, 1.3, 0.5, 1)
        bracketRect = CCAnim([fromR, r], duration: motion.d(ms), easing: e, fill: .forwards, start: now)
        bracketOpacity = CCAnim([[fromO], [1]], duration: motion.d(ms), easing: e, fill: .forwards, start: now)
        await wait(motion.d(ms))
    }

    // MARK: 3. Pick (`showPick`, `pickObject`)

    private func showPick() {
        phase = .pick
        for i in outlineOpacity.indices { outlineOpacity[i].set(1, duration: motion.transition(500)) }
        outlinePulseStart = motion.calm ? nil : CCClock.now
        tagScale = objs.map { _ in CCTransition(0) }
        tagOpacity = objs.map { _ in CCTransition(0) }
        tagSpots = CCPickLayout.layout(rects: objs.map(\.rect), sizes: objs.map { CCPickLayout.tagSize(name: $0.name) })
        pickUI = true
        for i in objs.indices {
            let delay = motion.calm ? 0 : 0.14 + Double(i) * 0.13
            Task {
                await wait(delay)
                guard i < tagScale.count, i < tagOpacity.count else { return }
                tagScale[i].set(1, duration: motion.transition(500), easing: CCBezier(0.3, 1.5, 0.5, 1))
                tagOpacity[i].set(1, duration: motion.transition(300))
                play(.ccPop)
                Haptics.pon(open: true)
            }
        }
    }

    /// A tap on the photo (design points): the object it means, even where boxes overlap (`CCPickLayout.object`).
    func pickObject(at p: CGPoint) {
        guard let i = CCPickLayout.object(at: p, rects: objs.map(\.rect)) else { return }
        pickObject(i)
    }

    func pickObject(_ i: Int) {
        guard phase == .pick, objs.indices.contains(i) else { return }
        play(.ccTick)
        sheetObj = i
        phase = .word
        sheetOpenedAt = CCClock.now
        sheetT.set(1, duration: motion.transition(500), easing: CCBezier(0.2, 1.1, 0.3, 1))
        let n = objs[i].source.words.count
        Task {
            await wait(motion.calm ? 0 : 0.16)
            playCands(n)
        }
    }

    /// SFX.cands(n): one pop per candidate (1–3), 90 ms apart like the rows, with the light tap (`haptic(8)`).
    /// Owner decision 2026-10-04: no sound of its own — the same pop as the object tags just before.
    private func playCands(_ n: Int) {
        Haptics.pon(open: false)
        for i in 0..<max(1, min(3, n)) {
            let dl = motion.d(Double(i) * 90)
            Task {
                await wait(dl)
                play(.ccPop)
            }
        }
    }

    func closeSheet() {
        sheetT.set(0, duration: motion.transition(500), easing: CCBezier(0.2, 1.1, 0.3, 1))
        phase = .pick
    }

    // MARK: 4. Light → card (`chooseWord`, `formLight`)

    func chooseWord(_ w: Candidate) {
        guard phase == .word, let i = sheetObj, objs.indices.contains(i), let vm else { return }
        runId += 1
        let my = runId
        phase = .card
        play(.ccTick)
        sheetT.set(0, duration: motion.transition(500), easing: CCBezier(0.2, 1.1, 0.3, 1))
        pickUI = false
        setPill(false)
        outlinePulseStart = nil
        for k in outlineOpacity.indices { outlineOpacity[k].set(0, duration: motion.transition(500)) }
        let o = objs[i]
        chosen = (o, w)
        starsOrigin = CCClock.now
        vm.choose(o.source, word: w)
        // .catbg: the category colour (the candidate's category hint; the card's own category once it arrives)
        let lang = NativeAPI.targetLanguage
        if !(w.categoryKey ?? "").isEmpty || DexCatalog.item(headword: w.headword, lang: lang) != nil {
            showCategory(CCCategory.from(headword: w.headword, categoryKey: w.categoryKey))
        }
        Task { await formLight(my, o, w) }
    }

    private func showCategory(_ c: CCCategory) {
        category = c
        catOn.set(1, duration: motion.transition(350))
    }

    private func starOffset(_ now: Double) -> CGPoint {
        guard let s = star, let v = s.flight?.sample(now) else { return .zero }
        return CGPoint(x: v[0], y: v[1])
    }

    private func formLight(_ my: Int, _ o: Obj, _ w: Candidate) async {
        guard let vm, let photo = vm.photo else { return }
        // The card's photo window (`cropAt`, up to 9 draws of the whole photo) is drawn off the main thread
        // while the light flies (at least 1.3 s), and picked up when the card is made.
        let box = o.source.box
        let photoArt: Task<UIImage, Never>? = o.source.cut != nil && CaptureViewModel.cutoutMode ? nil
            : Task.detached(priority: .userInitiated) { CCImages.cropAt(photo: photo, box: box) }
        var pieceImage = o.source.cut
        if pieceImage == nil { pieceImage = await o.piece?.value }
        guard my == runId else { return }
        let src = o.rect
        let img = pieceImage ?? CCImages.cropFrom(photo: photo, box: box)
        piece = Piece(image: img, rect: src,
                      anim: CCAnim([[1, 1, 1], [0.08, 0, 3]], duration: motion.d(700), easing: CCBezier(0.6, 0, 0.4, 1), fill: .forwards))
        photoDim.set(1, duration: motion.transition(900), easing: CCBezier(0.2, 0.8, 0.2, 1))
        photoScale.set(1.12, duration: motion.transition(1400), easing: CCBezier(0.2, 0.8, 0.2, 1))
        // Owner decision 2026-10-04: the light uses the sounds around it, nothing new — the sparkle that the
        // card makes right after, and no sound of its own for the flight (the reveal follows it).
        play(.ccTwinkle)
        let c = CGPoint(x: src.midX, y: src.midY)
        let cx = Double(src.midX), cy = Double(src.midY), sw = Double(src.width), sh = Double(src.height)
        star = Star(center: c, size: 50,
                    appear: CCAnim([[0, -90, 0], [1.25, 10, 1], [1, 0, 1]], offsets: [0, 0.7, 1], duration: motion.d(520),
                                   delay: motion.d(260), easing: CCBezier(0.2, 1, 0.3, 1), fill: .backwards),
                    flight: nil)
        for i in 0..<14 {
            let dl = motion.d(Double(i) * 40)
            Task {
                await wait(dl)
                particles.trail(cx + (Double.random(in: 0..<1) - 0.5) * sw * 0.8,
                                cy + (Double.random(in: 0..<1) - 0.5) * sh * 0.8)
            }
        }
        await wait(motion.d(700))
        piece = nil
        guard my == runId else { return }

        let tx = 195.0, ty = 346.0
        star?.flight = CCAnim([[0, 0, 1, 0], [(tx - cx) * 0.5, (ty - cy) * 0.5 - 70, 1.2, 180], [tx - cx, ty - cy, 0.9, 360]],
                              duration: motion.d(600), easing: CCBezier(0.5, 0, 0.3, 1), fill: .forwards)
        // setInterval(trail at the star, 16)
        trailToken += 1
        let tok = trailToken
        Task {
            while trailToken == tok, my == runId {
                let off = starOffset(CCClock.now)
                particles.trail(cx + Double(off.x), cy + Double(off.y))
                await wait(0.016)
            }
        }
        await wait(motion.d(600))
        trailToken += 1
        guard my == runId else { return }

        // iOS: the card needs its details (example, category…). Until they arrive the star waits at the
        // card's centre, twinkling; a failed card goes back to the objects.
        while my == runId, vm.details == nil {
            let failed = vm.picked != w || (vm.step == .select && !vm.isCheckingOwned && !vm.isLoadingDetails)
            if failed { returnToPick(); return }
            await wait(0.05)
        }
        guard my == runId, let details = vm.details else { return }
        let cropped = await photoArt?.value
        guard my == runId else { return }
        let e = makeEntry(o, w, details, cropped: cropped)
        entry = e
        if category != e.category || catOn.to == 0 { showCategory(e.category) }

        star = nil
        flashAnim = CCAnim([[0], [0.5], [0]], offsets: [0, 0.2, 1], duration: motion.d(460))
        play(.ccReveal)
        particles.burst(tx, ty, n: 70, speed: 10, up: 0, g: 0.04)
        cardVisible = true
        cardSpin = CCAnim([[720, 0.2, 0], [360, 1.08, 1], [0, 1, 1]], offsets: [0, 0.7, 1], duration: motion.d(1000),
                          easing: CCBezier(0.2, 0.8, 0.2, 1))
        await wait(motion.d(1000))
        await wait(motion.sleep(200))
        guard my == runId else { return }

        // chooseWord, after formLight: say(w.zh) — silent when the sound is off (`if (S.sfx !== "on") return`)
        if !SoundService.shared.isMuted { SoundService.shared.speak(w.headword) }
        sweepStart = CCClock.now
        particles.burst(195, 346, n: 90, speed: 8, up: 3)
        particles.glints(Self.cardRect, n: 18)
        Task {
            await wait(0.3)   // setTimeout(SFX.twinkle, 300)
            play(.ccTwinkle)
        }
        haloOn.set(1, duration: motion.transition(700))
        bokehOn.set(1, duration: motion.transition(800))
        bokeh.start(calm: motion.calm)
        showCardUI()
        tilt.start()
        acquireMotion()
        onCardShown?()
    }

    private func showCardUI() {
        uiShown = true
        uiAnim = CCAnim([[0, 16], [1, 0]], duration: motion.d(500), easing: CCBezier(0.2, 1, 0.3, 1))
    }

    /// The card could not be made (generateCard failed): back to the objects.
    private func returnToPick() {
        runId += 1
        star = nil
        piece = nil
        cardVisible = false
        cardSpin = nil
        entry = nil
        chosen = nil
        sheetObj = nil
        catOn.set(0, duration: motion.transition(350))
        photoDim.set(0, duration: motion.transition(900), easing: CCBezier(0.2, 0.8, 0.2, 1))
        photoScale.set(1.03, duration: motion.transition(1400), easing: CCBezier(0.2, 0.8, 0.2, 1))
        showPick()
    }

    /// `cropped`: the photo window already drawn off the main thread (`formLight`); nil = draw it here.
    private func makeEntry(_ o: Obj, _ w: Candidate, _ d: CardDetails, cropped: UIImage? = nil) -> CCCardEntry {
        func raw(_ key: String) -> String? {
            let v = d.raw?[key]?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return v.isEmpty ? nil : v
        }
        let dexNo = DexCatalog.category(headword: w.headword, key: raw("category_key") ?? d.categoryKey,
                                        lang: NativeAPI.targetLanguage)
        let cat = CCCategory.forDex(dexNo)
        let catLabel = DexCatalog.label(dexNo)
        let pos = CCText.posLabel(raw("part_of_speech") ?? w.pos)
        let sep = L10n.lang == "ja" ? "・" : " · "
        let date = Date().formatted(.dateTime.month().day().locale(L10n.locale))
        let place = vm?.placeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let art: CCCardEntry.Art
        if let cut = o.source.cut, CaptureViewModel.cutoutMode {
            let pop = CCImages.bigPop(cut, zhLen: w.headword.unicodeScalars.count)
                ?? CCImages.fallbackPop(objectPixels: o.source.box.width * (vm?.photo?.size.width ?? 1),
                                        o.source.box.height * (vm?.photo?.size.height ?? 1))
            art = .cut(cut, pop: pop)
        } else if let photo = vm?.photo {
            art = .orig(cropped ?? CCImages.cropAt(photo: photo, box: o.source.box))
        } else {
            art = .orig(CaptureViewModel.textCard(for: w.headword))
        }
        return CCCardEntry(
            headword: w.headword,
            zhuyin: raw("reading_zhuyin") ?? w.zhuyin,
            pinyin: raw("pinyin") ?? w.pinyin,
            meaning: ReaderLanguage.shown(raw("meaning_ja"), w.meaningJa),
            example: raw("example_sentence") ?? d.exampleSentence,
            exampleTranslation: ReaderLanguage.shown(raw("example_translation"), d.exampleTranslation),
            categoryLine: pos.isEmpty ? catLabel : catLabel + sep + pos,
            placeDate: place.isEmpty ? date : "\(place) · \(date)",
            no: nextNumber(w.headword),
            category: cat,
            art: art
        )
    }

    // MARK: Card pose

    func pose(_ now: Double) -> CCCardPose {
        if let s = cardSpin, let v = s.sample(now) { return CCCardPose(ty: 0, rx: 0, ry: v[0], scale: v[1]) }
        if let l = cardLift, let v = l.sample(now) { return CCCardPose(ty: v[0], rx: v[1], ry: v[2], scale: v[3]) }
        return CCCardPose(ty: tilt.ty, rx: tilt.rx, ry: tilt.ry, scale: 1)
    }

    func cardOpacity(_ now: Double) -> Double {
        if let s = cardSpin, let v = s.sample(now) { return v[2] }
        return 1
    }

    // MARK: Tilt gesture

    func dragChanged(start: CGPoint, location: CGPoint) {
        let now = CCClock.now
        let c = Self.cardRect
        let p = CGPoint(x: c.minX + location.x, y: c.minY + location.y)   // the wrap's local point → design
        if location == start {
            tilt.down(p, now: now)
        } else {
            if !tiltDragging {
                tilt.down(CGPoint(x: c.minX + start.x, y: c.minY + start.y), now: now)
            }
            tilt.move(p, card: c, now: now)
        }
        tiltDragging = true
    }

    @ObservationIgnored private var tiltDragging = false

    func dragEnded() {
        tiltDragging = false
        if tilt.up(), phase == .card { send() }
    }

    // MARK: 7. Into the dex (`sendToDex`, first half)

    func send() {
        guard phase == .card else { return }
        phase = .sending
        let my = runId
        uiShown = false
        let now = CCClock.now
        let from = pose(now)
        tilt.stop()
        let c = Self.cardRect
        let cx = Double(c.midX), cy = Double(c.midY) - 40
        play(.ccTwinkle)
        Task {
            cardLift = CCAnim([[from.ty, from.rx, from.ry, 1], [-40, 0, 0, 1.04]], duration: motion.d(260),
                              easing: CCBezier(0.2, 0.9, 0.3, 1), fill: .forwards)
            await wait(motion.d(260))
            guard my == runId else { return }
            star = Star(center: CGPoint(x: cx, y: cy), size: 52,
                        appear: CCAnim([[0, 0, 0], [1.25, 0, 1], [1, 0, 1]], offsets: [0, 0.7, 1], duration: motion.d(420),
                                       delay: motion.d(180), fill: .backwards),
                        flight: nil)
            wrapAnim = CCAnim([[1, 0, 1], [0, -40, 0.08]], duration: motion.d(420), easing: CCBezier(0.6, 0, 0.4, 1), fill: .forwards)
            for i in 0..<14 {
                let dl = motion.d(Double(i) * 25)
                Task {
                    await wait(dl)
                    particles.trail(cx + (Double.random(in: 0..<1) - 0.5) * 200, cy + (Double.random(in: 0..<1) - 0.5) * 280)
                }
            }
            await wait(motion.sleep(460))
            guard my == runId else { return }
            cardVisible = false
            haloOn.set(0, duration: motion.transition(700))
            catOn.set(0, duration: motion.transition(350))
            bokehOn.set(0, duration: motion.transition(800))
            bokeh.stop()
            releaseMotion()
            // Hand-off: the catch is saved by the app's own path while the star waits here; then the dex
            // opens and CatchLanding flies this star into the word's slot.
            onHandoff?(CatchStar(center: CGPoint(x: globalOrigin.x + space.toReal(CGPoint(x: cx, y: cy)).x,
                                                 y: globalOrigin.y + space.toReal(CGPoint(x: cx, y: cy)).y),
                                 size: 52 * space.k, k: space.k))
            let ok = await onSend?() ?? false
            guard my == runId else { return }
            if ok {
                star = nil   // CatchLanding drew it at the same place, above every screen
                return
            }
            restoreAfterFailedSend()
        }
    }

    /// The save failed (the toast says why): the card comes back so the word is not lost.
    private func restoreAfterFailedSend() {
        star = nil
        cardLift = nil
        wrapAnim = nil
        cardVisible = true
        if let c = category { showCategory(c) }
        haloOn.set(1, duration: motion.transition(700))
        bokehOn.set(1, duration: motion.transition(800))
        bokeh.start(calm: motion.calm)
        phase = .card
        showCardUI()
        tilt.start()
        acquireMotion()
    }
}

/// Text helpers for the card.
enum CCText {
    /// The part of speech in the display language (as the word page shows it), or "".
    static func posLabel(_ pos: String) -> String {
        let p = pos.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return "" }
        let codes: [String: String] = ["N": L("名詞"), "V": L("動詞"), "VS": L("状態動詞"), "ADV": L("副詞"), "M": L("量詞"), "PREP": L("前置詞")]
        if let t = codes[p.uppercased()] { return t }
        let en: [String: String] = ["noun": L("名詞"), "verb": L("動詞"), "adjective": L("形容詞"), "adverb": L("副詞"),
                                    "preposition": L("前置詞"), "phrase": L("フレーズ"), "pronoun": L("代名詞"),
                                    "conjunction": L("接続詞"), "interjection": L("感動詞")]
        if let t = en[p.lowercased()] { return t }
        if let t = L10n.translation(p) { return t }
        return ReaderLanguage.looksWrong(p, reader: L10n.lang) ? "" : p
    }
}
