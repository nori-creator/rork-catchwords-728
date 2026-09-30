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
    @State private var baseZoom: CGFloat = 1
    @State private var location: CLLocation?
    @State private var tapStart: Date?
    /// Web rankScanCandidates: the one most worth learning glows; names doubtful as Taiwan usage get "?".
    @State private var topId: String?
    @State private var doubtful: Set<String> = []
    @State private var touched = false

    enum Stage: Equatable {
        case idle, sensing, reading, matching
        var label: String {
            switch self {
            case .idle: ""
            case .sensing: "シーンを感知しています"
            case .reading: "対象を解析しています"
            case .matching: "辞書と照合しています"
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
                            ScanTag(item: item, owned: dex.owns(headword: item.headword),
                                    isTop: item.id == topId, isDoubtful: doubtful.contains(item.id)) {
                                touched = true
                                tapStart = Date()
                                Haptics.selection()
                                selected = item
                                SoundService.shared.speak(item.headword)
                                ScanLog.tapped(item, ms: tapStart.map { Int(Date().timeIntervalSince($0) * 1000) })
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
                Text("カメラの使用が許可されていません").foregroundStyle(.white)
                Button("設定を開く") {
                    if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                }
                .foregroundStyle(Theme.cyan).frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.navyCard)
        case .unavailable:
            Text("カメラが見つかりません").foregroundStyle(.white.opacity(0.8))
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
                .accessibilityLabel("閉じる")
                Spacer()
                Text("かざす").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text(String(format: "%.1f×", camera.zoom))
                    .font(AppFont.mono(13, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(.white.opacity(0.12), in: Circle())
                    .accessibilityLabel("ズーム \(String(format: "%.1f", camera.zoom))倍")
            }
            .padding(.horizontal, 16)
            Spacer()

            VStack(spacing: 14) {
                Group {
                    if speech.isListening {
                        Text(speech.transcript.isEmpty ? "話しかけてください" : speech.transcript)
                    } else if stage != .idle {
                        Text(stage.label)
                    } else if let message {
                        Text(message)
                    } else if !items.isEmpty {
                        Text("札を押すと意味と発音が出ます")
                    } else {
                        Text("看板や物にかざして、ボタンを押してください")
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: stage)

                HStack(alignment: .center) {
                    roundButton(icon: speech.isListening ? "waveform" : "mic.fill", label: "声で調べる", active: speech.isListening) { voice() }
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
                    .accessibilityLabel(items.isEmpty ? "スキャン" : "もう一度")
                    Spacer()
                    roundButton(icon: "arrow.triangle.2.circlepath.camera", label: "カメラ切替", active: false) {
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
        guard let shot = await camera.capture() else { message = "フレームを取得できませんでした"; return }
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
            message = (error as? LocalizedError)?.errorDescription ?? "検出に失敗しました"
        }
    }

    private func voice() {
        speech.toggle { text in
            Task { await lookupVoice(text) }
        }
        if speech.state == .denied { message = "マイクと音声認識の使用を設定で許可してください" }
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
            message = (error as? LocalizedError)?.errorDescription ?? "その言葉が見つかりませんでした。"
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
    var meaning: String { entry?.meaningJa ?? candidate.meaningJa }
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

/// The floating word tag with a pin dot.
struct ScanTag: View {
    let item: ScanItem
    let owned: Bool
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
                            .accessibilityLabel("台湾での言い方として不確か")
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
                Circle().fill(Theme.cyan).frame(width: 10, height: 10)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: Theme.cyan, radius: 6)
            }
            .offset(y: bob ? -3 : 3)
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .accessibilityLabel("\(item.headword)、\(item.meaning)\(owned ? "、取得済み" : "")")
        .scaleEffect(isTop ? 1.08 : 1)
        .zIndex(isTop ? 1 : 0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(Double.random(in: 0...0.6))) { bob = true }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { glow = true }
        }
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
                ZhuyinWordView(headword: item.headword, zhuyin: item.zhuyin, size: 36, weight: .heavy)
                Spacer()
                PronounceCircle(text: item.headword, size: 48)
            }
            if !item.pinyin.isEmpty {
                Text(item.pinyin).font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            Text(item.meaning).font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.foreground)
            HStack(spacing: 6) {
                if item.isVerified {
                    Label("検証済み", systemImage: "checkmark.seal").foregroundStyle(Theme.ok)
                } else {
                    Label("AIによる推定", systemImage: "sparkles").foregroundStyle(Theme.muted)
                }
                if dex.owns(headword: item.headword) {
                    Text("・取得済み").foregroundStyle(Theme.primaryInk)
                }
            }
            .font(.system(size: 12, weight: .medium))
            if let error { Text(error).font(.system(size: 13)).foregroundStyle(Theme.destructive) }
            Spacer(minLength: 0)
            PrimaryButton(title: "キャッチする", icon: "sparkles", isLoading: isSaving, sheen: true) { caught() }
        }
        .padding(20)
        .background(Theme.background)
    }

    private func caught() {
        guard plan.canCatch else { router.showPaywall = true; return }
        guard let frame else { error = "フレームを取得できませんでした"; return }
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
                self.error = (error as? LocalizedError)?.errorDescription ?? "保存に失敗しました。"
            }
        }
    }
}

