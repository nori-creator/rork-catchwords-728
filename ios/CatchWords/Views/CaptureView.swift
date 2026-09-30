import SwiftUI
import PhotosUI

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
    @State private var reward: RewardPayload?
    @State private var baseZoom: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            cameraLayer
            switch vm.step {
            case .camera:
                cameraChrome.transition(.opacity)
            case .processing:
                AnalyzingView(photo: vm.photo).transition(.opacity)
            case .select:
                CandidatePickerView(vm: vm).transition(.move(edge: .bottom).combined(with: .opacity))
            case .card:
                CatchCardView(vm: vm, onCatch: startCatch).transition(.move(edge: .bottom).combined(with: .opacity))
            case .failed(let reason, let retryable):
                FailedView(reason: reason, retryable: retryable, onRetry: {
                    if let p = vm.photo { vm.analyze(p) }
                }, onClose: { vm.reset() })
            }
            if shutterFlash {
                Color.white.ignoresSafeArea().allowsHitTesting(false)
            }
            if let reward {
                RewardOverlay(payload: reward) {
                    finishReward()
                }
                .ignoresSafeArea()
                .zIndex(10)
            }
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: vm.step) { _, step in
            if step == .camera { Task { await camera.start() } } else { camera.stop() }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    beginAnalyze(img.normalizedOrientation())
                }
                pickerItem = nil
            }
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
        .onAppear { LocationService.shared.requestPermissionIfNeeded() }
    }

    // MARK: Camera

    @ViewBuilder
    private var cameraLayer: some View {
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
            .gesture(MagnifyGesture()
                .onChanged { v in camera.setZoom(baseZoom * v.magnification) }
                .onEnded { _ in baseZoom = camera.zoom })
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
            .ignoresSafeArea()
            .blur(radius: vm.step == .camera ? 0 : 20)
            .opacity(vm.step == .camera ? 1 : 0.35)
        case .denied:
            CameraMessageView(icon: "camera.fill", title: "カメラへのアクセスが必要です",
                              message: "設定アプリでカメラを許可すると、身の回りの物を撮って単語にできます。",
                              buttonTitle: "設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        case .unavailable:
            CameraMessageView(icon: "camera.metering.unknown", title: "カメラが見つかりません",
                              message: "写真アプリの画像や、文字で調べることもできます。", buttonTitle: nil, action: {})
        }
    }

    private var cameraChrome: some View {
        VStack(spacing: 0) {
            HStack {
                usagePill
                Spacer()
                if !dex.pending.isEmpty {
                    Button { showPending = true } label: {
                        Label("\(dex.pending.count)件 解析待ち", systemImage: "tray.and.arrow.up.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .glassCard(18, tint: Theme.gold.opacity(0.25))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            if camera.state == .running && camera.zoom > 1.05 {
                Text(String(format: "%.1fx", camera.zoom))
                    .font(AppFont.mono(13, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.bottom, 14)
            }

            // Thumb zone: shoot (primary) is visually separated from text search and library.
            HStack(alignment: .center) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    sideButton(icon: "photo.on.rectangle", label: "写真")
                }
                .buttonStyle(PressableStyle(scale: 0.9))
                Spacer()
                ShutterButton(enabled: camera.state == .running) { shoot() }
                Spacer()
                Button { showTextSearch = true } label: {
                    sideButton(icon: "character.cursor.ibeam", label: "文字で")
                }
                .buttonStyle(PressableStyle(scale: 0.9))
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 92)
        }
    }

    private var usagePill: some View {
        Group {
            if plan.isPro {
                Label("PRO", systemImage: "infinity")
                    .foregroundStyle(Theme.gold)
            } else {
                HStack(spacing: 6) {
                    ForEach(0..<PlanStore.freeCatchesPerDay, id: \.self) { i in
                        Circle()
                            .fill(i < plan.remainingToday ? Theme.primary : .white.opacity(0.22))
                            .frame(width: 7, height: 7)
                    }
                    Text("今日あと\(plan.remainingToday)回")
                }
                .foregroundStyle(.white)
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .padding(.horizontal, 12)
        .frame(minHeight: 32)
        .glassCard(16)
        .onTapGesture { if !plan.isPro { router.showPaywall = true } }
    }

    private func sideButton(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 54, height: 54)
                .glassCard(27)
            Text(label).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
    }

    private var textSearchSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("", text: $searchText, prompt: Text("例: マンゴー / 芒果").foregroundStyle(Theme.muted))
                    .font(.system(size: 18))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 54)
                    .background(Theme.secondary, in: .rect(cornerRadius: 14))
                    .submitLabel(.search)
                    .onSubmit(runSearch)
                PrimaryButton(title: "台湾華語で調べる", icon: "magnifyingglass", action: runSearch)
                    .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(20)
            .navigationTitle("文字で調べる")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(260)])
        .presentationBackground(Theme.card)
    }

    // MARK: Actions

    private func shoot() {
        guard plan.canCatch else { router.showPaywall = true; return }
        Haptics.impact(.rigid)
        SoundService.shared.play(.snap, volume: 0.7)
        withAnimation(.easeOut(duration: 0.05)) { shutterFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeOut(duration: 0.3)) { shutterFlash = false }
            if let img = await camera.capture() { beginAnalyze(img) }
        }
    }

    private func beginAnalyze(_ img: UIImage) {
        guard plan.canCatch else { router.showPaywall = true; return }
        vm.analyze(img)
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
    private func startCatch() {
        guard let draft = vm.draft() else { return }
        let gate = SaveGate()
        let payload = RewardPayload(
            image: draft.cutout ?? draft.photo,
            isCutout: draft.cutout != nil,
            headword: draft.candidate.headword,
            reading: draft.candidate.zhuyin,
            pinyin: draft.candidate.pinyin,
            meaning: draft.candidate.meaningJa,
            rarity: Double(6 - (draft.details?.extras.frequencyLevel ?? 3)) / 5,
            gate: gate
        )
        withAnimation(nil) { reward = payload }
        Task {
            do {
                let outcome = try await dex.save(draft)
                plan.recordCatch()
                gate.finish(.success(outcome))
            } catch {
                PendingQueue.shared.add(image: draft.photo, reason: (error as? LocalizedError)?.errorDescription ?? "保存に失敗しました。",
                                        lat: draft.location?.coordinate.latitude, lng: draft.location?.coordinate.longitude)
                dex.refreshPending()
                gate.finish(.failure(error))
            }
        }
    }

    private func finishReward() {
        guard let payload = reward else { return }
        switch payload.gate.result {
        case .success(let outcome):
            router.landingStickerId = outcome.sticker.id
            vm.reset()
            reward = nil
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { router.tab = .dex }
        case .failure(let error):
            reward = nil
            vm.reset()
            let reason = (error as? LocalizedError)?.errorDescription ?? "保存に失敗しました。"
            vm.step = .failed("写真は預かりました。\n\(reason)", retryable: false)
        case .none:
            reward = nil
            vm.reset()
        }
    }
}

struct ShutterButton: View {
    var enabled: Bool
    let action: () -> Void
    @State private var pressed: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(.white, lineWidth: 4).frame(width: 82, height: 82)
                Circle().fill(.white).frame(width: 66, height: 66)
                    .scaleEffect(pressed ? 0.86 : 1)
            }
            .frame(width: 88, height: 88)
            .contentShape(Circle())
        }
        .buttonStyle(ShutterStyle(pressed: $pressed))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel("撮影")
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
            AppBackground()
            VStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 42)).foregroundStyle(Theme.primary)
                Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.foreground)
                Text(message).font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                if let buttonTitle {
                    PrimaryButton(title: buttonTitle, action: action).frame(maxWidth: 240).padding(.top, 8)
                }
            }
            .padding(32)
            .padding(.bottom, 120)
        }
    }
}

struct FailedView: View {
    let reason: String
    let retryable: Bool
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.gold)
            Text("写真は預かりました")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text(reason)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Text(retryable ? "電波が戻ったら「解析待ち」から続きができます。" : "この理由は、時間をおいても直らない可能性があります。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                if retryable { PrimaryButton(title: "もう一度解析する", icon: "arrow.clockwise", action: onRetry) }
                Button("カメラに戻る", action: onClose)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .glassCard(16)
                    .buttonStyle(PressableStyle())
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding(28)
        .padding(.bottom, 80)
        .background(.black.opacity(0.55))
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
                                Text(item.reason).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "arrow.clockwise.circle.fill").font(.title2).foregroundStyle(Theme.primary)
                        }
                    }
                    .swipeActions {
                        Button("削除", role: .destructive) {
                            PendingQueue.shared.remove(id: item.id)
                            dex.refreshPending()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("解析待ちの写真")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
