import SwiftUI

/// After the shot: the photo with each word the AI found as a tag ON its object (the AI's point; Vision's
/// instance when it found one), and "違う単語を入力" underneath for a word that is not among them.
/// A tap on a tag goes straight to the celebration (owner 2026-10-09: shoot → words → tap → done).
/// - Each object's everyday name is the bold tag; its other names (砕けた / くわしい / 固有名詞) sit just
///   above or below it, lighter. Tags never cover each other (`CCPickLayout`).
/// - Without a position (the AI gave none) the words gather at the photo's centre, still one per line.
/// - From the shutter on (`.processing`) the same screen runs the catch scan over the photo (v10, owner 2026-10-11:
///   bracket, light pen, `CatchScan.swift`), and each tag comes up where it is tapped, when the scan brings it up.
///   Typing a word waits until the names are in.
struct CandidatePickerView: View {
    let vm: CaptureViewModel
    /// The names are not in yet (`.processing`): the scan is running and nothing can be typed. Handed in by the camera
    /// screen, which switches on `vm.step`: this view must never read `vm.step` itself. When it did, the camera screen
    /// missed the change to `.celebrate` made right after the tap (it was redrawn during that change and kept the old
    /// step), so the words stayed on screen and the celebration never opened (the UI tour's 5 of 6, trace 2026-10-11).
    let scanning: Bool
    @State private var appeared: Bool = false
    @State private var typed: String = ""
    @FocusState private var inputFocused: Bool
    @Environment(\.appReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    private let ink = Color(hex: 0x0B121A)

    /// One word's tag over the photo.
    private struct Tag: Identifiable {
        let id: String
        let object: CatchObject
        let word: Candidate
        /// The object's everyday name; the others are its other names, drawn lighter.
        let main: Bool
        /// Order among the everyday names (`candidate.<n>`); nil for other names.
        let mainIndex: Int?
    }

    /// A tag with its size and its bottom centre in the photo stage.
    private struct Placed: Identifiable {
        let tag: Tag
        let size: CGSize
        let spot: CGPoint
        var id: String { tag.id }
    }

    /// The photo's objects. Built here from the words alone when the analysis did not build them
    /// (no masks: each object gets the box around its own point).
    private var objects: [CatchObject] {
        if !vm.objects.isEmpty { return vm.objects }
        guard let photo = vm.photo, !vm.candidates.isEmpty else { return [] }
        return CatchObject.build(candidates: vm.candidates, masks: nil, photoSize: photo.size)
    }

    var body: some View {
        ZStack {
            MachineBackground()
            VStack(spacing: 12) {
                topBar
                photoStage
                    .clipShape(.rect(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 10)
                bottomPanel
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    .disabled(scanning)
                    .opacity(scanning ? 0.5 : 1)
                    .animation(.easeOut(duration: 0.25), value: scanning)
            }
            if vm.isCheckingOwned {
                Color.black.opacity(0.25).ignoresSafeArea()
                ProgressView().controlSize(.large).tint(.white)
            }
        }
        .allowsHitTesting(!vm.isCheckingOwned)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
            }
        }
        .task(id: vm.scan.map { ObjectIdentifier($0) }) { await runScan() }
    }

    /// Steps this photo's scan about 60 times a second (its sounds, its tags) until everything is up.
    private func runScan() async {
        guard let scan = vm.scan else { return }
        scan.begin(now: Date())
        while !Task.isCancelled, !scan.settled {
            scan.step(now: Date(), reduceMotion: reduceMotion)
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    /// The line at the top right: what the scan is doing, then what to do.
    private var topHint: String {
        switch vm.scan?.phase {
        case .scanning?: return L("写真をスキャンしています")
        case .naming?: return L("名前を調べています")
        default: return L("覚えたいことばをタップ")
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { vm.reset() } label: {
                Label(L("撮り直す"), systemImage: "arrow.counterclockwise")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(.white.opacity(0.12), in: Capsule())
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("picker.retake")
            Spacer(minLength: 8)
            Text(topHint)
                .scaledFont(size: 14, weight: .semibold)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: topHint)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: The photo and its tags

    private var photoStage: some View {
        GeometryReader { geo in
            let size = geo.size
            let placedTags = placed(in: size)
            let _ = UITestTrace.log(traceStage(size, placedTags))
            ZStack(alignment: .topLeading) {
                if let photo = vm.photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .allowsHitTesting(false)
                }
                if let scan = vm.scan, let photo = vm.photo {
                    CatchScanOverlay(scan: scan, photo: photo.size, reduceMotion: reduceMotion)
                        .frame(width: size.width, height: size.height)
                }
                ForEach(placedTags) { p in
                    tagButton(p)
                        .position(x: p.spot.x, y: p.spot.y - p.size.height / 2)
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(.rect)
            .onTapGesture {
                UITestTrace.log("stage.tap")
                inputFocused = false
            }
            .onChange(of: size, initial: true) { _, s in layoutScan(s) }
            .onChange(of: vm.scan.map { ObjectIdentifier($0) }) { _, _ in layoutScan(size) }
        }
    }

    /// The UI tests' trace of a render of the stage (`UITestTrace`, DEBUG + `-uiDemo` only): what it shows and can take.
    private func traceStage(_ size: CGSize, _ placedTags: [Placed]) -> String {
        let shown = placedTags.filter { vm.scan?.revealed.contains($0.tag.object.id) ?? true }.map(\.id)
        let state = "scanning=\(scanning) checking=\(vm.isCheckingOwned) enabled=\(isEnabled)"
        return "picker.stage \(Int(size.width))x\(Int(size.height)) \(state) shown=\(shown)"
    }

    /// Tells the scan where the photo sits on the stage (it draws in the stage's points).
    private func layoutScan(_ size: CGSize) {
        guard let scan = vm.scan, let photo = vm.photo else { return }
        scan.layout(stage: size, fill: Self.fillRect(image: photo.size, in: size))
    }

    /// Everyday names first (each keeps its own place on its object), then the other names, which move just
    /// above or below the tags they would cover.
    private func tags(_ objects: [CatchObject]) -> [Tag] {
        var mains: [Tag] = []
        var others: [Tag] = []
        for o in objects {
            // ふだん → 砕けた → くわしい → 固有名詞. Same rank keeps the AI's order (likelihood).
            let order = o.words.indices.sorted { a, b in
                let ra = Self.rank(o.words[a].register), rb = Self.rank(o.words[b].register)
                return ra != rb ? ra < rb : a < b
            }
            for (k, i) in order.enumerated() {
                let id = "\(o.id)-\(i)"
                if k == 0 {
                    mains.append(Tag(id: id, object: o, word: o.words[i], main: true, mainIndex: mains.count))
                } else {
                    others.append(Tag(id: id, object: o, word: o.words[i], main: false, mainIndex: nil))
                }
            }
        }
        return mains + others
    }

    private func placed(in size: CGSize) -> [Placed] {
        guard let photo = vm.photo, size.width > 0, size.height > 0 else { return [] }
        let list = tags(objects)
        guard !list.isEmpty else { return [] }
        let fill = Self.fillRect(image: photo.size, in: size)
        let sizes = list.map { CCPickLayout.tagSize(name: $0.word.headword) }
        let tallest = sizes.map(\.height).max() ?? 30
        let area = CCPickLayout.Area(width: size.width, minBottom: tallest + 6,
                                     maxBottom: max(tallest + 6, size.height - 6), sideClamp: 0)
        var anchors: [CGPoint] = []
        for (i, t) in list.enumerated() {
            let p = CGPoint(x: fill.minX + t.object.point.x * fill.width, y: fill.minY + t.object.point.y * fill.height)
            anchors.append(CCPickLayout.anchor(at: p, size: sizes[i], in: area))
        }
        let spots = CCPickLayout.layout(anchors: anchors, sizes: sizes, in: area)
        return list.indices.map { Placed(tag: list[$0], size: sizes[$0], spot: spots[$0]) }
    }

    /// White capsule with a blue dot and the word (the other names: a grey dot, a little see-through).
    /// With a scan, a tag comes up when the scan brings its object up (the film's rise: a little low, small and soft,
    /// then up into place); the object's other names follow its everyday name by 0.06 s.
    private func tagButton(_ p: Placed) -> some View {
        let t = p.tag
        let delay = 0.08 + Double(t.mainIndex ?? 4) * 0.06
        let scanned = vm.scan != nil
        let shown = vm.scan.map { $0.revealed.contains(t.object.id) } ?? appeared
        let rise = scanned && !reduceMotion && !shown
        let motion: Animation? = scanned
            ? (reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.68).delay(t.main ? 0 : 0.06))
            : (reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7).delay(delay))
        return Button {
            UITestTrace.log("tag.action \(t.id) shown=\(shown) checking=\(vm.isCheckingOwned)")
            vm.choose(t.word, object: t.object)
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(t.main ? Color(hex: 0x2A9BFF) : Color(hex: 0x9AA6B5))
                    .frame(width: 10, height: 10)
                Text(t.word.headword)
                    .font(.system(size: CCPickLayout.tagFontSize, weight: .heavy))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(t.main ? 0.96 : 0.8), in: Capsule())
            .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
            .contentShape(Capsule().inset(by: -6))
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .accessibilityHint(ReaderLanguage.gloss(ReaderLanguage.shown(t.word.meaningJa)))
        .accessibilityIdentifier(t.mainIndex.map { "candidate.\($0)" } ?? "candidate.other")
        .tourAnchor(.pick, if: t.mainIndex == 0)
        .scaleEffect(shown ? 1 : (scanned ? 0.86 : 0.6))
        .offset(y: rise ? 6 : 0)
        .blur(radius: rise ? 3 : 0)
        .opacity(shown ? 1 : 0)
        .allowsHitTesting(shown)
        .accessibilityHidden(!shown)
        .animation(motion, value: shown)
    }

    /// ふだん → 砕けた → くわしい → 固有名詞 (candidate-order.ts).
    private static func rank(_ register: String?) -> Int {
        switch register {
        case "casual": 1
        case "specific": 2
        case "proper": 3
        default: 0
        }
    }

    /// Where a scaledToFill image sits inside `size`.
    static func fillRect(image: CGSize, in size: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0 else { return CGRect(origin: .zero, size: size) }
        let scale = max(size.width / image.width, size.height / image.height)
        let w = image.width * scale, h = image.height * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    // MARK: "違う単語を入力"

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !vm.typedCandidates.isEmpty { typedList }
            manualInput
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 22, style: .continuous))
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: vm.typedCandidates.count)
    }

    /// Several words for what was typed: one row each (never scrolls sideways).
    private var typedList: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.typedCandidates.enumerated()), id: \.offset) { idx, c in
                Button { vm.choose(c, object: nil) } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            ZhuyinWordView(headword: c.headword, zhuyin: c.zhuyin, size: 20, pinyin: c.pinyin)
                            Text(ReaderLanguage.gloss(ReaderLanguage.shown(c.meaningJa)))
                                .scaledFont(size: 12)
                                .foregroundStyle(Theme.muted)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 8)
                    .frame(minHeight: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(scale: 0.98))
                .accessibilityIdentifier("typed.\(idx)")
                if idx < vm.typedCandidates.count - 1 { Divider().overlay(Theme.border) }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var manualInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("違う単語を入力"))
                .scaledFont(size: 13, weight: .medium)
                .foregroundStyle(Theme.muted)
            HStack(spacing: 8) {
                TextField("", text: $typed, prompt: Text(L("例: \(NativeAPI.sample(.word))")).foregroundStyle(Theme.muted.opacity(0.7)))
                    .scaledFont(size: 16)
                    .foregroundStyle(Theme.foreground)
                    .focused($inputFocused)
                    .submitLabel(.search)
                    .onSubmit(submit)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 46)
                    .background(Theme.background, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.primary.opacity(inputFocused ? 0.6 : 0.25), lineWidth: 1))
                    .accessibilityIdentifier("picker.field")
                Button(action: submit) {
                    HStack(spacing: 6) {
                        if vm.isLookingUp {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(L("検索"))
                    }
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundStyle(Theme.foreground)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 46)
                    .background(Theme.secondary, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(PressableStyle())
                .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLookingUp)
                .accessibilityIdentifier("picker.submit")
            }
            if let err = vm.searchError {
                Text(err)
                    .scaledFont(size: 13)
                    .foregroundStyle(Theme.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
    }

    private func submit() {
        let q = typed.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !vm.isLookingUp else { return }
        inputFocused = false
        typed = ""
        vm.search(text: q)
    }
}

/// Page header used through the catch flow ("集める").
struct CollectHeader: View {
    var onClose: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            LogoMark(size: 30)
            Text(L("集める"))
                .scaledFont(size: 15, weight: .medium)
                .foregroundStyle(Theme.muted)
            Spacer()
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L("カメラに戻る"))
            }
        }
        .padding(.top, 4)
    }
}

/// The vivid blue pronounce button (PronounceButton tone="hero").
struct PronounceCircle: View {
    let text: String
    var size: CGFloat = 42
    /// Off in long lists (the dex list), where warming every row would synthesize words nobody plays.
    var prefetch: Bool = true

    var body: some View {
        Button { SoundService.shared.speak(text) } label: {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Theme.primary, in: Circle())
                .shadow(color: Theme.primary.opacity(0.35), radius: 6, y: 3)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .accessibilityLabel(L("発音を聞く"))
        // Web `pronounce.prefetch`: fetch the server voice when the button appears, so the tap is instant.
        .task(id: text) { if prefetch { SoundService.shared.prefetch(text) } }
    }
}
