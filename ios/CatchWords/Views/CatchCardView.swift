import SwiftUI

/// capture.tsx card step: peel the sticker (or tap 図鑑に追加), retake, word + meaning + memo.
/// Never waits for the cutout — it upgrades the sticker in place when ready.
/// Web `WordCard minimal`: at catch time only the headword (zhuyin to the right), pronunciation and
/// the meaning. Example, pinyin line and meters belong to the word's detail page, not here
/// (owner rule: 訳と発音だけ / メーターいらない). The full card keeps generating in the background.
struct CatchCardView: View {
    @Bindable var vm: CaptureViewModel
    let onCatch: () -> Void

    @State private var showSelfie: Bool = false
    @State private var isCatching: Bool = false
    /// The cut-out animation has played for the current lift.
    @State private var revealDone: Bool = false
    @FocusState private var captionFocused: Bool

    private var stickerImage: UIImage? {
        if showSelfie, let s = vm.selfie { return s }
        return vm.cutout ?? vm.photo ?? vm.picked.map { CaptureViewModel.textCard(for: $0.headword) }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 14) {
                    CollectHeader { vm.reset() }
                    stickerStage.tourAnchor(.peel)
                    actions
                    if vm.selfie != nil {
                        Text(L("画像をタップで自撮りにフリップ"))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                    if let c = vm.picked { headwordCard(c).tourAnchor(.headword) }
                    if let c = vm.picked { meaningCard(c) }
                    captionField
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        // A failed save or card shows a notice and keeps this card: let the user try again.
        .onChange(of: vm.toastCount) { _, _ in isCatching = false }
        .onChange(of: vm.cutoutLift == nil) { _, none in if none { revealDone = false } }
    }

    private var stickerStage: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Theme.card, Theme.secondary], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
            if let lift = vm.cutoutLift, !revealDone, !showSelfie {
                CutoutRevealView(lift: lift) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { revealDone = true }
                }
                .padding(8)
                .transition(.opacity)
            } else if let img = stickerImage {
                PeelStickerView(image: img, isCutout: vm.cutout != nil && !showSelfie, disabled: isCatching,
                                onPeel: catchNow,
                                onTap: {
                                    guard vm.selfie != nil else { return }
                                    Haptics.selection()
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showSelfie.toggle() }
                                })
                    .padding(8)
                    .id(showSelfie ? "selfie" : (vm.cutout != nil ? "cut" : "photo"))
                    .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))
            }
            HStack(spacing: 6) {
                if vm.isCutting { ProgressView().controlSize(.mini).tint(.white) }
                Text(vm.isCutting || (vm.cutoutLift != nil && !revealDone) ? L("切り抜いています") : L("好きな方向にはがしてキャッチ"))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
            .background(Theme.foreground.opacity(0.78), in: Capsule())
            .padding(.bottom, 14)
            .allowsHitTesting(false)
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: vm.cutout != nil)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                vm.reset()
            } label: {
                Text(L("やり直す"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.card, in: Capsule())
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            Button(action: catchNow) {
                HStack(spacing: 8) {
                    if isCatching && vm.details == nil {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold))
                    }
                    Text(L("図鑑に追加")).font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Theme.primary, in: Capsule())
                .shadow(color: Theme.primary.opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(PressableStyle())
            .disabled(isCatching)
            .accessibilityIdentifier("card.catch")
        }
    }

    private func headwordCard(_ c: Candidate) -> some View {
        HStack {
            ZhuyinWordView(headword: c.headword, zhuyin: c.zhuyin, size: 30, weight: .semibold, pinyin: c.pinyin)
            Spacer()
            PronounceCircle(text: c.headword, size: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.card, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    private func meaningCard(_ c: Candidate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "book")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Theme.primary, in: Circle())
                Text(L("意味")).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.foreground)
            }
            Text(meaning(c)).font(.system(size: 22, weight: .medium)).foregroundStyle(Theme.foreground)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    /// The card's meaning once it arrives (reader language, scrubbed), else the candidate's.
    private func meaning(_ c: Candidate) -> String {
        let m = vm.details?.raw?["meaning_ja"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ReaderLanguage.shown(m, c.meaningJa)
    }

    private var captionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("一言メモ（任意）")).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
            TextField("", text: $vm.caption, prompt: Text(L("今の気持ちや場所をメモ…")).foregroundStyle(Theme.muted.opacity(0.7)), axis: .vertical)
                .font(AppFont.hand(18))
                .foregroundStyle(Theme.foreground)
                .focused($captionFocused)
                .lineLimit(1...3)
                .padding(14)
                .background(Theme.card, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            if let place = vm.placeName {
                Label(place, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func catchNow() {
        guard !isCatching else { return }
        isCatching = true
        captionFocused = false
        showSelfie = false
        onCatch()
    }
}
