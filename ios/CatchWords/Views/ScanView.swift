import SwiftUI
import AVFoundation
import CoreLocation

/// scan.tsx — hold the camera up, words float where they are. Tap one → meaning + pronunciation only.
/// Dictionary first (~50ms), AI only when the dictionary has nothing. Real zoom, real front camera, real voice.
struct ScanView: View {
    @Environment(DexStore.self) private var dex
    @Environment(PlanStore.self) private var plan
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var camera = CameraService()
    @State private var speech = SpeechService()
    @State private var stage: Stage = .idle
    @State private var frame: UIImage?
    @State private var items: [ScanItem] = []
    @State private var selected: ScanItem?
    @State private var message: String?
    /// Mic / speech recognition refused: the message gets a "open Settings" button.
    @State private var micDenied: Bool = false
    @State private var baseZoom: CGFloat = 1
    @State private var location: CLLocation?
    @State private var tapStart: Date?
    /// Web rankScanCandidates: the one most worth learning glows; names doubtful as Taiwan usage get "?".
    @State private var topId: String?
    @State private var doubtful: Set<String> = []
    @State private var touched = false
    /// Which of the scanned words you already have or have looked at before (web `getScanContext`).
    @State private var scanContext: ScanContext?

    enum Stage: Equatable {
        case idle, sensing, reading, matching
        var label: String {
            switch self {
            case .idle: ""
            case .sensing: L("シーンを感知しています")
            case .reading: L("対象を解析しています")
            case .matching: L("辞書と照合しています")
            }
        }
    }

    var body: some View {
        ZStack {
            Theme.navyDeep.ignoresSafeArea()
            GeometryReader { geo in
                ZStack {
                    preview
                    if let frame, !items.isEmpty {
                        ForEach(items) { item in
                            ScanTag(item: item, state: dotState(item.headword),
                                    isTop: item.id == topId, isDoubtful: doubtful.contains(item.id)) {
                                touched = true
                                tapStart = Date()
                                Haptics.selection()
                                selected = item
                                SoundService.shared.speak(item.headword)
                                ScanLog.tapped(item, ms: tapStart.map { Int(Date().timeIntervalSince($0) * 1000) })
                                scanContext?.tapped.insert(ScanContext.key(item.headword))
                            }
                            .position(Self.place(item.point, image: frame.size, in: geo.size))
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
                        }
                    }
                    if stage != .idle { ScanSweep(stage: stage).allowsHitTesting(false) }
                }
                .clipShape(.rect(cornerRadius: 24, style: .continuous))
                .gesture(MagnifyGesture()
                    .onChanged { v in camera.setZoom(baseZoom * v.magnification) }
                    .onEnded { _ in baseZoom = camera.zoom })
            }
            .padding(.horizontal, 10)
            .padding(.top, 56)
            .padding(.bottom, 170)

            chrome
        }
        .task {
            await camera.start()
            location = await LocationService.shared.current()
        }
        .task { scanContext = await ScanContext.load() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            camera.stop()
            speech.stop(deliver: false)
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(item: $selected) { item in
            ScanCatchSheet(item: item, frame: frame, location: location) {
                selected = nil
                dismiss()
            }
            .presentationDetents([.height(330)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var preview: some View {
        switch camera.state {
        case .denied:
            VStack(spacing: 12) {
                Image(systemName: "camera.fill").font(.system(size: 30)).foregroundStyle(.white.opacity(0.6))
                Text(L("カメラの使用が許可されていません")).foregroundStyle(.white)
                Button(L("設定を開く")) {
                    if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                }
                .foregroundStyle(Theme.cyan).frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.navyCard)
        case .unavailable:
            Text(L("カメラが見つかりません")).foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.navyCard)
        default:
            if let frame, !items.isEmpty {
                Color.black.overlay {
                    Image(uiImage: frame).resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                }
            } else {
                CameraPreview(session: camera.session) { _, dp in camera.focus(at: dp) }
            }
        }
    }

    /// 0–1000 image point → view point under aspect-fill.
    static func place(_ p: [Double], image: CGSize, in view: CGSize) -> CGPoint {
        guard p.count >= 2, image.width > 0, image.height > 0 else { return CGPoint(x: view.width / 2, y: view.height / 2) }
        let s = max(view.width / image.width, view.height / image.height)
        let ox = (view.width - image.width * s) / 2
        let oy = (view.height - image.height * s) / 2
        let x = p[0] / 1000 * image.width * s + ox
        let y = p[1] / 1000 * image.height * s + oy
        return CGPoint(x: min(max(x, 60), view.width - 60), y: min(max(y, 30), view.height - 30))
    }

    // MARK: - Chrome

    private var chrome: some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44).background(.white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel(L("閉じる"))
                Spacer()
                Text(L("かざす")).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text(String(format: "%.1f×", camera.zoom))
                    .font(AppFont.mono(13, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(.white.opacity(0.12), in: Circle())
                    .accessibilityLabel(L("ズーム \(String(format: "%.1f", camera.zoom))倍"))
            }
            .padding(.horizontal, 16)
            Spacer()

            VStack(spacing: 14) {
                Group {
                    if speech.isListening {
                        Text(speech.transcript.isEmpty ? L("話しかけてください") : speech.transcript)
                    } else if stage != .idle {
                        Text(stage.label)
                    } else if let message {
                        Text(message)
                    } else if !items.isEmpty {
                        Text(L("札を押すと意味と発音が出ます"))
                    } else {
                        Text(L("看板や物にかざして、ボタンを押してください"))
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: stage)
                if micDenied, !speech.isListening, stage == .idle {
                    Button(L("設定を開く")) {
                        if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.cyan).frame(minHeight: 44)
                }

                HStack(alignment: .center) {
                    roundButton(icon: speech.isListening ? "waveform" : "mic.fill", label: L("声で調べる"), active: speech.isListening) { voice() }
                    Spacer()
                    Button { scanOrReset() } label: {
                        ZStack {
                            Circle().fill(Theme.primary).frame(width: 74, height: 74)
                                .shadow(color: Theme.primary.opacity(0.6), radius: 16)
                            Circle().stroke(.white.opacity(0.9), lineWidth: 3).frame(width: 84, height: 84)
                            if stage != .idle {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: items.isEmpty ? "viewfinder" : "arrow.counterclockwise")
                                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(PressableStyle(scale: 0.9))
                    .disabled(stage != .idle || camera.state != .running)
                    .accessibilityLabel(items.isEmpty ? L("スキャン") : L("もう一度"))
                    Spacer()
                    roundButton(icon: "arrow.triangle.2.circlepath.camera", label: L("カメラ切替"), active: false) {
                        camera.toggle()
                        baseZoom = 1
                    }
                }
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)
        }
    }

    private func roundButton(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(active ? Theme.navyDeep : .white)
                .symbolEffect(.variableColor.iterative, isActive: active && !reduceMotion)
                .frame(width: 54, height: 54)
                .background(active ? Theme.cyan : .white.opacity(0.14), in: Circle())
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .accessibilityLabel(label)
    }

    // MARK: - Actions

    /// The 4 discovery states (web `dotStateFor`). Without the server context, the dex on this phone decides.
    private func dotState(_ headword: String) -> ScanDotState {
        let key = ScanContext.key(headword)
        if let ctx = scanContext {
            if let entry = ctx.owned[key] { return entry.hasPhoto ? .owned : .reunion }
            return ctx.tapped.contains(key) ? .seen : .new
        }
        guard let s = dex.stickers.first(where: { ScanContext.key($0.word?.headword ?? "") == key }) else { return .new }
        return (s.objectImageUrl ?? s.cutoutImageUrl) != nil ? .owned : .reunion
    }

    /// Asked after the tags are already up, so scanning never waits for it; silently skipped on failure.
    private func rank(_ list: [ScanItem]) async {
        guard list.count >= 2 else { return }
        struct Ranked: Decodable { let order: [Int]?; let doubtful: [Int]? }
        let payload: [[String: Any]] = list.prefix(24).map { it in
            ["headword": String(it.headword.prefix(40)), "meaning": String(it.meaning.prefix(80)),
             "kind": String(it.candidate.kind.prefix(12)), "confidence": min(1, max(0, it.candidate.confidence)),
             "owned": dex.owns(headword: it.headword)]
        }
        guard let r = try? await NativeAPI.call("rankScanCandidates", ["items": payload], as: Ranked.self, timeout: 8),
              items.map(\.id) == list.map(\.id) else { return }
        let doubt = Set((r.doubtful ?? []).compactMap { $0 < list.count ? list[$0].id : nil })
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            doubtful = doubt
            if !touched, let first = r.order?.first(where: { $0 < list.count && !doubt.contains(list[$0].id) }) {
                topId = list[first].id
            }
        }
        if topId != nil, !touched { Haptics.selection() }
    }

    private func scanOrReset() {
        if !items.isEmpty {
            topId = nil; doubtful = []; touched = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { items = []; frame = nil; message = nil }
            return
        }
        Task { await scan() }
    }

    private func scan() async {
        guard let shot = await camera.capture() else { message = L("フレームを取得できませんでした"); return }
        Haptics.impact(.medium)
        message = nil
        stage = .sensing
        let stageTimer = Task {
            try? await Task.sleep(for: .milliseconds(700))
            if !Task.isCancelled, stage == .sensing { stage = .reading }
        }
        do {
            let found = try await AIService.shared.detectScan(image: shot, lat: location?.coordinate.latitude,
                                                              lng: location?.coordinate.longitude)
            stageTimer.cancel()
            stage = .matching
            let dict = await Dictionary.lookup(found.map(\.headword))
            let merged = found.map { c in ScanItem(candidate: c, entry: dict[c.headword]) }
            frame = shot
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { items = merged }
            stage = .idle
            Haptics.success()
            Task { await rank(merged) }
        } catch {
            stageTimer.cancel()
            stage = .idle
            Haptics.warning()
            message = (error as? LocalizedError)?.errorDescription ?? L("検出に失敗しました")
        }
    }

    private func voice() {
        if speech.isListening {
            speech.stop(deliver: true)
            return
        }
        Task {
            // Permission is asked inside `start`; only after it do we know whether it was refused.
            await speech.start { text in
                Task { await lookupVoice(text) }
            }
            switch speech.state {
            case .denied:
                micDenied = true
                message = L("マイクと音声認識の使用を設定で許可してください")
            case .unavailable:
                micDenied = false
                message = L("この言語の音声認識はこの端末では使えません")
            default:
                micDenied = false
            }
        }
    }

    private func lookupVoice(_ text: String) async {
        stage = .matching
        defer { stage = .idle }
        do {
            let c = try await AIService.shared.lookup(text: text)
            let dict = await Dictionary.lookup([c.headword])
            let item = ScanItem(candidate: c, entry: dict[c.headword])
            if frame == nil { frame = await camera.capture() }
            selected = item
            SoundService.shared.speak(item.headword)
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? L("その言葉が見つかりませんでした。")
        }
    }

    // MARK: - Dictionary (dictionary_entries, verified first)

    enum Dictionary {
        static func lookup(_ heads: [String]) async -> [String: DictEntry] {
            let unique = Array(Set(heads.filter { !$0.isEmpty }))
            guard !unique.isEmpty else { return [:] }
            let list = unique.map { "\"\($0)\"" }.joined(separator: ",")
            let q = "dictionary_entries?select=headword,zhuyin,pinyin,meaning_ja,pos,tocfl_level,source&language=eq.\(NativeAPI.targetLanguage)&headword=in.(\(list))"
            guard let path = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let data = try? await SupabaseClient.shared.rest("GET", path, timeout: 4),
                  let rows = try? JSONDecoder().decode([DictEntry].self, from: data) else { return [:] }
            var out: [String: DictEntry] = [:]
            for r in rows where out[r.headword] == nil || r.source == "verified" { out[r.headword] = r }
            return out
        }
    }
}

nonisolated struct DictEntry: Decodable, Sendable, Hashable {
    let headword: String
    let zhuyin: String?
    let pinyin: String?
    let meaningJa: String
    let pos: String?
    let tocflLevel: Int?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case headword, zhuyin, pinyin, pos, source
        case meaningJa = "meaning_ja"
        case tocflLevel = "tocfl_level"
    }
}

/// A floating tag: AI position + dictionary-verified reading/meaning when available.
struct ScanItem: Identifiable, Hashable {
    let candidate: Candidate
    let entry: DictEntry?
    var id: String { candidate.id }
    var headword: String { candidate.headword }
    var point: [Double] { candidate.point }
    var zhuyin: String { entry?.zhuyin ?? candidate.zhuyin }
    var pinyin: String { entry?.pinyin ?? candidate.pinyin }
    var meaning: String { ReaderLanguage.shown(entry?.meaningJa, candidate.meaningJa) }
    var isVerified: Bool { entry?.source == "verified" }

    /// Candidate with dictionary values so the saved card reads the same as the tag.
    var resolved: Candidate {
        Candidate(kind: candidate.kind, headword: headword, zhuyin: zhuyin, pinyin: pinyin, meaningJa: meaning,
                  pos: entry?.pos ?? candidate.pos, point: candidate.point, confidence: candidate.confidence, alternatives: candidate.alternatives)
    }
}

/// Silent scan funnel log, never blocks the UI. Detection rows are written by the web's `detectScan`
/// itself; taps and catches mark those same rows (web `markScanTap` / `markScanCaught`), so nothing is
/// counted twice.
enum ScanLog {
    static func tapped(_ item: ScanItem, ms: Int?) {
        var d: [String: Any] = ["headword": item.headword]
        if let ms { d["tap_to_audio_ms"] = max(0, ms) }
        Task { _ = try? await NativeAPI.call("markScanTap", d, timeout: 10) }
    }

    static func caught(_ item: ScanItem) {
        Task { _ = try? await NativeAPI.call("markScanCaught", ["headword": item.headword], timeout: 10) }
    }
}

/// What the learner already knows about a scanned word.
enum ScanDotState {
    /// Never caught, never tapped: a white light that pings.
    case new
    /// Tapped in an earlier scan but not caught: a white light, quiet.
    case seen
    /// Caught with a photo: green with a check.
    case owned
    /// Caught by text or voice only (no photo yet): amber, softly pulsing — "meet it again".
    case reunion

    var color: Color {
        switch self {
        case .new, .seen: .white
        case .owned: Color(hex: 0x34D399)
        case .reunion: Color(hex: 0xFBBF24)
        }
    }

    var spoken: String {
        switch self {
        case .new: L("はじめて見る語")
        case .seen: L("前に見た語")
        case .owned: L("取得済み")
        case .reunion: L("再会")
        }
    }
}

/// The learner's own words and earlier taps, read once per scan (web `getScanContext`) and matched here.
struct ScanContext {
    struct Entry { let stickerId: String; let hasPhoto: Bool; let foundAt: String }
    var owned: [String: Entry]
    var tapped: Set<String>

    /// Same normalisation as the server: NFC and trimmed, so variants of one character match.
    static func key(_ headword: String) -> String {
        headword.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func load() async -> ScanContext? {
        struct Raw: Decodable {
            struct E: Decodable {
                let stickerId: String; let hasPhoto: Bool; let foundAt: String
                enum CodingKeys: String, CodingKey { case stickerId = "sticker_id", hasPhoto = "has_photo", foundAt = "found_at" }
            }
            let owned: [String: E]
            let tapped: [String]
        }
        guard let r = try? await NativeAPI.call("getScanContext", [:], as: Raw.self, timeout: 10) else { return nil }
        var owned: [String: Entry] = [:]
        for (k, e) in r.owned { owned[key(k)] = Entry(stickerId: e.stickerId, hasPhoto: e.hasPhoto, foundAt: e.foundAt) }
        return ScanContext(owned: owned, tapped: Set(r.tapped.map(key)))
    }
}

/// The floating word tag with a pin dot.
struct ScanTag: View {
    let item: ScanItem
    let state: ScanDotState
    private var owned: Bool { state == .owned }
    var isTop: Bool = false
    var isDoubtful: Bool = false
    let onTap: () -> Void
    @State private var bob: Bool = false
    @State private var glow: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    // Fixed ink: the tag is always a white label on the camera, in light and dark.
                    Text(item.headword).font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: 0x0B121A))
                    if isDoubtful {
                        Text("?").font(.system(size: 13, weight: .heavy)).foregroundStyle(Color(hex: 0xB45309))
                            .accessibilityLabel(L("台湾での言い方として不確か"))
                    }
                    if owned {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundStyle(Theme.ok)
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(isTop ? Theme.gold : Theme.primary.opacity(0.5), lineWidth: isTop ? 2.5 : 1.5))
                .shadow(color: isTop ? Theme.gold.opacity(glow ? 0.8 : 0.3) : .black.opacity(0.3), radius: isTop ? 14 : 8, y: 4)
                .opacity(isDoubtful ? 0.78 : 1)
                pin
            }
            .offset(y: bob ? -3 : 3)
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .accessibilityLabel(L("\(item.headword)、\(item.meaning)") + L10n.comma + state.spoken)  // lang-ok: ScanItem.meaning is ReaderLanguage.shown
        .scaleEffect(isTop ? 1.08 : 1)
        .zIndex(isTop ? 1 : 0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(Double.random(in: 0...0.6))) { bob = true }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    /// The light under the tag: its colour says new / seen / caught / meet-again.
    private var pin: some View {
        ZStack {
            if !reduceMotion && (state == .new || state == .reunion) {
                // new pings outward; a reunion breathes in amber
                Circle().fill(state.color.opacity(state == .new ? 0.35 : 0.45))
                    .frame(width: state == .new ? 24 : 28, height: state == .new ? 24 : 28)
                    .scaleEffect(glow ? 1.15 : 0.6)
                    .opacity(glow ? 0 : 1)
                    .blur(radius: state == .reunion ? 3 : 0)
            }
            Circle().fill(state.color).frame(width: 14, height: 14)
                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))
                .shadow(color: state.color.opacity(0.7), radius: 6)
            if state == .owned {
                Image(systemName: "checkmark").font(.system(size: 7, weight: .black)).foregroundStyle(.white)
            }
        }
        .frame(width: 28, height: 28)
    }
}

/// Stage-aware sweep line (sensing → reading → matching).
struct ScanSweep: View {
    let stage: ScanView.Stage
    @State private var y: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Theme.navyDeep.opacity(stage == .matching ? 0.35 : 0.18)
                LinearGradient(colors: [.clear, Theme.cyan.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 90)
                    .offset(y: y * (geo.size.height - 90))
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { y = 1 }
            }
        }
    }
}

/// ScanCatchSheet: meaning + pronunciation only (owner rule), then "キャッチする".
struct ScanCatchSheet: View {
    let item: ScanItem
    let frame: UIImage?
    let location: CLLocation?
    let onCaught: () -> Void

    @Environment(DexStore.self) private var dex
    @Environment(PlanStore.self) private var plan
    @Environment(AppRouter.self) private var router
    @State private var isSaving: Bool = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZhuyinWordView(headword: item.headword, zhuyin: item.zhuyin, size: 36, weight: .heavy, pinyin: item.pinyin)
                Spacer()
                PronounceCircle(text: item.headword, size: 48)
            }
            Text(item.meaning).font(.system(size: 20, weight: .semibold))  // lang-ok: ScanItem.meaning is ReaderLanguage.shown
                    .foregroundStyle(Theme.foreground)
            HStack(spacing: 6) {
                if item.isVerified {
                    Label(L("検証済み"), systemImage: "checkmark.seal").foregroundStyle(Theme.ok)
                } else {
                    Label(L("AIによる推定"), systemImage: "sparkles").foregroundStyle(Theme.muted)
                }
                if dex.owns(headword: item.headword) {
                    Text(L("・取得済み")).foregroundStyle(Theme.primaryInk)
                }
            }
            .font(.system(size: 12, weight: .medium))
            if let error { Text(error).font(.system(size: 13)).foregroundStyle(Theme.destructive) }
            Spacer(minLength: 0)
            PrimaryButton(title: L("キャッチする"), icon: "sparkles", isLoading: isSaving, sheen: true) { caught() }
        }
        .padding(20)
        .background(Theme.background)
    }

    private func caught() {
        guard plan.canCatch else { router.showPaywall = true; return }
        guard let frame else { error = L("フレームを取得できませんでした"); return }
        isSaving = true
        Task {
            defer { isSaving = false }
            let c = item.resolved
            let details = try? await AIService.shared.cardDetails(for: c)
            var placeName: String?
            if let l = location { placeName = await LocationService.shared.placeName(for: l) }
            let cut = await CutoutService.liftSubject(from: frame, near: CGPoint(x: (c.point.first ?? 500) / 1000, y: (c.point.last ?? 500) / 1000))
            let draft = CatchDraft(candidate: c, details: details, photo: frame, cutout: cut, selfie: nil, caption: "",
                                   location: location, placeName: placeName, captureType: "scan")
            do {
                let outcome = try await dex.save(draft)
                plan.recordCatch()
                ScanLog.caught(item)
                Haptics.success()
                SoundService.shared.play(.sting)
                router.landingStickerId = outcome.sticker.id
                onCaught()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { router.tab = .dex }
            } catch {
                Haptics.warning()
                self.error = (error as? LocalizedError)?.errorDescription ?? L("保存に失敗しました。")
            }
        }
    }
}

