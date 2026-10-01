import SwiftUI
import PhotosUI
import AVFoundation

struct CaptureView: View {
    @Environment(DexStore.self) private var dex
    @Environment(PlanStore.self) private var plan
    @Environment(AppRouter.self) private var router

    @State private var camera = CameraService()
    @State private var vm = CaptureViewModel()
    @State private var focusPoint: CGPoint?
    @State private var shutterFlash: Bool = false
    @State private var showTextSearch: Bool = false
    @State private var searchText: String = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPending: Bool = false
    @State private var showScan: Bool = false
    @State private var reward: RewardPayload?
    @State private var baseZoom: CGFloat = 1
    @State private var positionBeforeSelfie: AVCaptureDevice.Position = .back
    @Namespace private var modeBubble
    @AppStorage("selfie.mode") private var selfieMode: Bool = true

    private var isMachine: Bool {
        switch vm.step {
        case .camera, .selfie, .processing, .failed: true
        default: false
        }
    }

    var body: some View {
        ZStack {
            switch vm.step {
            case .camera, .selfie:
                cameraMachine.transition(.opacity)
            case .processing:
                AnalyzingView(photo: vm.photo) { vm.reset() }
                    .transition(.opacity)
            case .select:
                CandidatePickerView(vm: vm).transition(.move(edge: .bottom).combined(with: .opacity))
            case .card:
                CatchCardView(vm: vm, onCatch: startCatch).transition(.move(edge: .trailing).combined(with: .opacity))
            case .reencounter:
                ReencounterView(vm: vm, onSeeInDex: { id in
                    vm.reset()
                    router.landingStickerId = id
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { router.tab = .dex }
                })
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .failed(let reason, let retryable):
                ZStack {
                    MachineBackground()
                    FailedView(reason: reason, retryable: retryable, offline: vm.failedOffline,
                               onRetry: { vm.retry() },
                               onHome: {
                                   vm.keepPendingAndReset()
                                   withAnimation { router.tab = .home }
                               },
                               onAgain: { vm.keepPendingAndReset() })
                }
            }
            if let toast = vm.toast {
                VStack {
                    Text(toast)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.foreground.opacity(0.88), in: Capsule())
                        .padding(.top, 60)
                        .padding(.horizontal, 24)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
                .zIndex(20)
            }
            if shutterFlash {
                Color.white.ignoresSafeArea().allowsHitTesting(false)
            }
            if let reward {
                RewardOverlay(payload: reward) { finishReward() }
                    .ignoresSafeArea()
                    .zIndex(10)
            }
        }
        .task { await camera.start() }
        .onAppear {
            LocationService.shared.requestPermissionIfNeeded()
            syncChrome()
        }
        .onDisappear {
            camera.stop()
            router.cameraImmersive = true
            router.tabBarHidden = false
        }
        .onChange(of: vm.step) { old, step in
            syncChrome()
            if step == .select { router.advanceTour(from: .shoot, to: .pick) }
            if step == .card { router.advanceTour(from: .pick, to: .detail) }
            if step == .camera, router.tour.isCapture, router.tour != .shoot {
                withAnimation { router.tour = .shoot }
            }
            switch step {
            case .camera:
                if old == .selfie || camera.position != positionBeforeSelfie { camera.switchTo(positionBeforeSelfie) }
                Task { await camera.start() }
            case .selfie:
                positionBeforeSelfie = camera.position
                camera.switchTo(.front)
                Task { await camera.start() }
            default:
                camera.stop()
            }
        }
        .onChange(of: reward == nil) { _, _ in syncChrome() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    beginAnalyze(img.normalizedOrientation(), askSelfie: false)
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showScan, onDismiss: { Task { await camera.start() } }) {
            ScanView()
        }
        .sheet(isPresented: $showTextSearch) { textSearchSheet }
        .sheet(isPresented: $showPending) {
            PendingListView { item in
                showPending = false
                guard plan.canCatch else { router.showPaywall = true; return }
                vm.restore(item)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func syncChrome() {
        router.cameraImmersive = isMachine
        router.tabBarHidden = vm.step == .processing || reward != nil
    }

    // MARK: Camera machine

    private var cameraMachine: some View {
        ZStack {
            MachineBackground()
            VStack(spacing: 0) {
                topBar
                ZStack(alignment: .bottom) {
                    previewLayer
                    zoomPills.padding(.bottom, 12)
                }
                .clipShape(.rect(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 10)
                .padding(.top, 8)

                if vm.step == .selfie {
                    Color.clear.frame(height: 14)
                } else {
                    modeStrip.padding(.top, 10)
                }
                controls
                    .padding(.top, 12)
                    .padding(.bottom, 86)
            }
        }
    }

    private var topBar: some View {
        ZStack {
            Text("CatchWords")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            HStack {
                if plan.isPro || PlanStore.catchLimitEnabled { usagePill }
                Spacer()
                Button {
                    Haptics.selection()
                    camera.stop()
                    showScan = true
                } label: {
                    Label(L("かざす"), systemImage: "dot.viewfinder")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.cyan)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(.white.opacity(0.1), in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L("かざして調べる"))
                if !dex.pending.isEmpty {
                    Button { showPending = true } label: {
                        Label("\(dex.pending.count)", systemImage: "tray.and.arrow.up.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 30)
                            .background(.white.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(L("解析待ち \(dex.pending.count)件"))
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 36)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var previewLayer: some View {
        switch camera.state {
        case .running, .idle:
            CameraPreview(session: camera.session) { point, device in
                camera.focus(at: device)
                Haptics.impact(.light, intensity: 0.5)
                focusPoint = point
                Task {
                    try? await Task.sleep(for: .seconds(1.1))
                    withAnimation(.easeOut(duration: 0.25)) { focusPoint = nil }
                }
            }
            .scaleEffect(x: camera.position == .front ? -1 : 1, y: 1)
            .gesture(MagnifyGesture()
                .onChanged { v in camera.setZoom(baseZoom * v.magnification) }
                .onEnded { _ in baseZoom = camera.zoom })
            .overlay {
                if vm.step == .camera { ViewfinderBrackets().padding(36).allowsHitTesting(false) }
            }
            .overlay {
                if let focusPoint {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.gold, lineWidth: 1.5)
                        .frame(width: 74, height: 74)
                        .position(focusPoint)
                        .transition(.scale(scale: 1.4).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .top) {
                if vm.step == .selfie { selfiePrompt.padding(.top, 48) }
            }
            .background(Color.black)
        case .denied:
            CameraMessageView(icon: "camera.fill", title: L("カメラの使用が許可されていません"),
                              message: L("1. 下の「設定を開く」を押す\n2. 「カメラ」をオンにして、この画面に戻る"),
                              buttonTitle: L("設定を開く")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        case .unavailable:
            CameraMessageView(icon: "camera.metering.unknown", title: L("カメラを起動できませんでした"),
                              message: L("ほかのアプリがカメラを使っていたら閉じてから、もう一度試してください。写真アプリの画像や、文字で調べることもできます。"),
                              buttonTitle: L("もう一度試す")) {
                Task { await camera.start() }
            }
        }
    }

    private var selfiePrompt: some View {
        VStack(spacing: 18) {
            Text(L("ものと一緒に、もう一枚"))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 6, y: 1)
            Button { vm.finishSelfie(nil) } label: {
                Text(L("スキップ"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .frame(minHeight: 44)
                    .background(.black.opacity(0.35), in: Capsule())
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// 1× 2× 3× 5× (CameraZoomMeter): the lit stop follows pinch zoom too.
    private var zoomPills: some View {
        let stops: [CGFloat] = [1, 2, 3, 5]
        let nearest = stops.min { abs($0 - camera.zoom) < abs($1 - camera.zoom) } ?? 1
        return HStack(spacing: 4) {
            ForEach(stops, id: \.self) { z in
                let isOn = z == nearest
                Button {
                    Haptics.selection()
                    withAnimation(.snappy) { camera.setZoom(z) }
                    baseZoom = camera.zoom
                } label: {
                    Text(isOn && abs(camera.zoom - z) > 0.05 ? String(format: "%.1f×", camera.zoom) : "\(Int(z))×")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(isOn ? Theme.gold : .white.opacity(0.85))
                        .frame(width: 42, height: 32)
                        .background(isOn ? .white.opacity(0.16) : .clear, in: Capsule())
                }
                .buttonStyle(PressableStyle(scale: 0.9))
            }
        }
        .padding(4)
        .background(Theme.navyDeep.opacity(0.7), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
    }

    /// 検索 · 撮影 · スキャン with the same sliding bubble as the tab bar; swipe also switches.
    private var modeStrip: some View {
        HStack(spacing: 0) {
            ForEach(CameraMode.allCases) { m in
                let isOn = vm.mode == m
                Button { setMode(m) } label: {
                    Text(m.label)
                        .font(.system(size: 15, weight: isOn ? .semibold : .regular))
                        .foregroundStyle(.white.opacity(isOn ? 1 : 0.7))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if isOn {
                                Capsule()
                                    .fill(LinearGradient(colors: [Color(hex: 0x3B6FB8), Color(hex: 0x1F4E93)], startPoint: .top, endPoint: .bottom))
                                    .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                                    .matchedGeometryEffect(id: "mode", in: modeBubble)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(scale: 0.95))
            }
        }
        .padding(.horizontal, 24)
        .gesture(DragGesture(minimumDistance: 20).onEnded { v in
            let all = CameraMode.allCases
            guard let i = all.firstIndex(of: vm.mode) else { return }
            if v.translation.width < -44, i < all.count - 1 { setMode(all[i + 1]) }
            if v.translation.width > 44, i > 0 { setMode(all[i - 1]) }
        })
    }

    private func setMode(_ m: CameraMode) {
        guard vm.mode != m else { return }
        Haptics.selection()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { vm.mode = m }
    }

    private var controls: some View {
        HStack(alignment: .top) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                sideButton(icon: "photo.badge.plus", label: L("写真"))
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .opacity(vm.step == .selfie ? 0 : 1)
            .disabled(vm.step == .selfie)
            Spacer()
            ShutterButton(icon: vm.step == .selfie ? "camera" : vm.mode.shutterIcon,
                          enabled: vm.mode == .search || camera.state == .running) { shoot() }
                .tourAnchor(.shutter)
            Spacer()
            Button { camera.toggle() } label: {
                sideButton(icon: "arrow.triangle.2.circlepath.camera", label: L("切替"))
            }
            .buttonStyle(PressableStyle(scale: 0.9))
        }
        .padding(.horizontal, 44)
    }

    private var usagePill: some View {
        Group {
            if plan.isPro {
                Label("PRO", systemImage: "infinity").foregroundStyle(Theme.gold)
            } else {
                HStack(spacing: 4) {
                    ForEach(0..<PlanStore.freeCatchesPerDay, id: \.self) { i in
                        Circle()
                            .fill(i < plan.remainingToday ? Theme.primaryBright : .white.opacity(0.22))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .font(.system(size: 11, weight: .bold))
        .padding(.horizontal, 10)
        .frame(minHeight: 30)
        .background(.white.opacity(0.1), in: Capsule())
        .contentShape(Capsule())
        .onTapGesture { if !plan.isPro { router.showPaywall = true } }
        .accessibilityLabel(plan.isPro ? "Pro" : L("今日あと\(plan.remainingToday)回"))
    }

    private func sideButton(icon: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .regular))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.1), in: .rect(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
            Text(label).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.white)
        .frame(minWidth: 56)
    }

    private var textSearchSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("", text: $searchText, prompt: Text(L("例: マンゴー / 芒果")).foregroundStyle(Theme.muted))
                    .font(.system(size: 18))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 54)
                    .background(Theme.secondary, in: .rect(cornerRadius: 14))
                    .submitLabel(.search)
                    .onSubmit(runSearch)
                PrimaryButton(title: L("台湾華語で調べる"), icon: "magnifyingglass", action: runSearch)
                    .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(20)
            .navigationTitle(L("文字で調べる"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(260)])
        .presentationBackground(Theme.card)
    }

    // MARK: Actions

    private func shoot() {
        if vm.step == .selfie {
            flash()
            Task { vm.finishSelfie(await camera.capture()) }
            return
        }
        if vm.mode == .search { showTextSearch = true; return }
        guard plan.canCatch else { router.showPaywall = true; return }
        flash()
        Task {
            if let img = await camera.capture() { beginAnalyze(img, askSelfie: vm.mode == .photo && selfieMode) }
        }
    }

    private func flash() {
        Haptics.impact(.rigid)
        SoundService.shared.play(.snap, volume: 0.7)
        withAnimation(.easeOut(duration: 0.05)) { shutterFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeOut(duration: 0.3)) { shutterFlash = false }
        }
    }

    private func beginAnalyze(_ img: UIImage, askSelfie: Bool) {
        guard plan.canCatch else { router.showPaywall = true; return }
        vm.analyze(img, askSelfie: askSelfie)
        dex.refreshPending()
    }

    private func runSearch() {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        guard plan.canCatch else { showTextSearch = false; router.showPaywall = true; return }
        showTextSearch = false
        searchText = ""
        vm.search(text: q)
    }

    /// Animation starts immediately from the photo on screen; save runs in parallel behind the 1s hold gate.
    /// The card must be real before saving (never placeholder level/category): if it is still being
    /// generated we wait for it; if it failed, nothing is saved.
    private func startCatch() {
        guard reward == nil, vm.picked != nil else { return }
        Task {
            // Cut-out mode: the sticker is cut before it goes into the dex (never a half-done cut).
            await vm.awaitCutout()
            guard let d = await vm.awaitDetails(), let draft = vm.draft(details: d) else {
                vm.showToast(L("カード生成に失敗しました"))
                return
            }
            runCatch(draft)
        }
    }

    private func runCatch(_ draft: CatchDraft) {
        guard reward == nil else { return }
        let gate = SaveGate()
        let payload = RewardPayload(
            image: draft.cutout ?? draft.photo,
            isCutout: draft.cutout != nil,
            headword: draft.candidate.headword,
            reading: draft.candidate.zhuyin,
            pinyin: draft.candidate.pinyin,
            meaning: draft.candidate.meaningJa,
            // PRODUCT.md: no arbitrary rarity. Every catch gets the same lift.
            rarity: 0,
            gate: gate
        )
        withAnimation(nil) { reward = payload }
        Task {
            do {
                let outcome = try await dex.save(draft)
                plan.recordCatch()
                vm.releasePending()
                dex.refreshPending()
                gate.finish(.success(outcome))
            } catch {
                // The photo is still in "解析待ち" (queued at the shutter), and the card stays on
                // screen so the chosen word is not lost.
                gate.finish(.failure(error))
            }
        }
    }

    private func finishReward() {
        guard let payload = reward else { return }
        switch payload.gate.result {
        case .success(let outcome):
            router.landingStickerId = outcome.sticker.id
            if router.tour == .peel || router.tour == .detail {
                router.tourStickerId = outcome.sticker.id
                router.tour = .added
            }
            vm.reset()
            reward = nil
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { router.tab = .dex }
        case .failure(let error):
            // Web: toast 「保存に失敗しました」 and stay on the card (capture.tsx reportSaveFailure).
            reward = nil
            let reason = (error as? LocalizedError)?.errorDescription ?? ""
            vm.showToast(reason.isEmpty ? L("保存に失敗しました") : L("保存に失敗しました\n\(reason)"))
        case .none:
            reward = nil
            vm.reset()
        }
    }
}

/// The camera "machine": deep navy with a faint dot grid (never a flat fill).
struct MachineBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0C2346), Theme.navyDeep], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                let step: CGFloat = 7
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(0.05)))
                        x += step
                    }
                    y += step
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Four white corner brackets framing the subject.
struct ViewfinderBrackets: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, l: CGFloat = 26, r: CGFloat = 10
            Path { p in
                p.move(to: CGPoint(x: 0, y: l)); p.addLine(to: CGPoint(x: 0, y: r))
                p.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero); p.addLine(to: CGPoint(x: l, y: 0))
                p.move(to: CGPoint(x: w - l, y: 0)); p.addLine(to: CGPoint(x: w - r, y: 0))
                p.addQuadCurve(to: CGPoint(x: w, y: r), control: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: l))
                p.move(to: CGPoint(x: w, y: h - l)); p.addLine(to: CGPoint(x: w, y: h - r))
                p.addQuadCurve(to: CGPoint(x: w - r, y: h), control: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: w - l, y: h))
                p.move(to: CGPoint(x: l, y: h)); p.addLine(to: CGPoint(x: r, y: h))
                p.addQuadCurve(to: CGPoint(x: 0, y: h - r), control: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: 0, y: h - l))
            }
            .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}

/// Blue disc with a white ring; the glyph follows the mode (SHUTTER_ICON).
struct ShutterButton: View {
    var icon: String = "camera"
    var enabled: Bool
    let action: () -> Void
    @State private var pressed: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.primary.opacity(0.35)).frame(width: 84, height: 84).blur(radius: 10)
                Circle().stroke(.white, lineWidth: 3).frame(width: 74, height: 74)
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0x2A9BFF), Color(hex: 0x0070F0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 66, height: 66)
                    .overlay(Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace)))
                    .scaleEffect(pressed ? 0.88 : 1)
            }
            .frame(width: 88, height: 88)
            .contentShape(Circle())
        }
        .buttonStyle(ShutterStyle(pressed: $pressed))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(L("撮影"))
    }
}

private struct ShutterStyle: ButtonStyle {
    @Binding var pressed: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, p in
                withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) { pressed = p }
            }
    }
}

struct CameraMessageView: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String?
    let action: () -> Void

    var body: some View {
        ZStack {
            Theme.navyCard
            VStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 42)).foregroundStyle(Theme.primaryBright)
                Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                Text(message).font(.system(size: 14)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                if let buttonTitle {
                    PrimaryButton(title: buttonTitle, action: action).frame(maxWidth: 240).padding(.top, 8)
                }
            }
            .padding(32)
        }
    }
}

/// Web `OfflineSavedPanel` (capture.tsx): the photo was kept in "解析待ち" when analysis failed.
/// The reason is always shown — a 401 or a broken image must not look like "just try later".
struct FailedView: View {
    let reason: String
    let retryable: Bool
    let offline: Bool
    let onRetry: () -> Void
    let onHome: () -> Void
    let onAgain: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: offline ? "wifi.slash" : "sparkles")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.gold)
            Text(L("解析できなかったので写真を預かりました"))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(L("あとでホームの「解析待ち」から続きができます。撮った瞬間は逃していません。"))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Text(L("理由: \(reason)"))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                if retryable { PrimaryButton(title: L("いますぐもう一度試す"), icon: "arrow.clockwise", action: onRetry) }
                secondary(L("ホームへ"), action: onHome)
                secondary(L("もう一枚撮る"), action: onAgain)
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding(28)
        .padding(.bottom, 80)
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(.white.opacity(0.1), in: .rect(cornerRadius: 16))
            .buttonStyle(PressableStyle())
    }
}

struct PendingListView: View {
    @Environment(DexStore.self) private var dex
    let onRestore: (PendingCatch) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(dex.pending) { item in
                    Button { onRestore(item) } label: {
                        HStack(spacing: 12) {
                            if let img = PendingQueue.shared.image(for: item) {
                                Color.clear.frame(width: 56, height: 56)
                                    .overlay { Image(uiImage: img).resizable().scaledToFill().allowsHitTesting(false) }
                                    .clipShape(.rect(cornerRadius: 10))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.createdAt, format: .dateTime.month().day().hour().minute())
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.foreground)
                                Text(item.reason).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "arrow.clockwise.circle.fill").font(.title2).foregroundStyle(Theme.primary)
                        }
                    }
                    .swipeActions {
                        Button(L("削除"), role: .destructive) {
                            PendingQueue.shared.remove(id: item.id)
                            dex.refreshPending()
                        }
                    }
                }
            }
            .navigationTitle(L("解析待ちの写真"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
