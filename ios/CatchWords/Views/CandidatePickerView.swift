import SwiftUI

/// One object in the photo: its everyday name, plus other names for the same object
/// (candidate-order.ts `groupCandidates`). Candidates without a group are one object each.
struct CandidateGroup: Identifiable {
    let main: Candidate
    let others: [Candidate]
    var id: String { main.id }

    /// ふだん → 砕けた → くわしい → 固有名詞. Same rank keeps the AI's order (likelihood).
    static func rank(_ register: String?) -> Int {
        switch register {
        case "casual": 1
        case "specific": 2
        case "proper": 3
        default: 0
        }
    }

    static func make(_ items: [Candidate]) -> [CandidateGroup] {
        var order: [String] = []
        var buckets: [String: [(Int, Candidate)]] = [:]
        for (i, c) in items.enumerated() {
            let key = c.group.map { "g\($0)" } ?? "solo\(i)"
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append((i, c))
        }
        return order.compactMap { key in
            let sorted = (buckets[key] ?? [])
                .sorted { (rank($0.1.register), $0.0) < (rank($1.1.register), $1.0) }
                .map(\.1)
            guard let main = sorted.first else { return nil }
            return CandidateGroup(main: main, others: Array(sorted.dropFirst()))
        }
    }
}

/// capture.tsx PickWordPanel + CandidatePicker (owner rules 2026-09-27/28):
/// - Stage 1: one row per object, **all the same size**, meaning only (2 lines max, never scrolls sideways).
/// - Tapping an object with no other names picks it at once; otherwise stage 2 opens:
///   the everyday name large with its usage note, "この語で図鑑に入れる", and the other names small
///   with 砕けた言い方 / くわしい名前 / 固有名詞 chips.
struct CandidatePickerView: View {
    let vm: CaptureViewModel
    @State private var appeared: Bool = false
    @State private var typed: String = ""
    @State private var openGroup: String?
    @FocusState private var inputFocused: Bool
    /// The tapped word travels from its row to the big word of stage 2 (and back).
    @Namespace private var hero

    private var groups: [CandidateGroup] { CandidateGroup.make(vm.candidates) }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    CollectHeader { vm.reset() }
                    if let photo = vm.photo {
                        Color.clear
                            .frame(width: 160, height: 160)
                            .overlay { Image(uiImage: photo).resizable().scaledToFill().allowsHitTesting(false) }
                            .clipShape(.rect(cornerRadius: 24, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
                            .frame(maxWidth: .infinity)
                            .scaleEffect(appeared ? 1 : 0.9)
                            .opacity(appeared ? 1 : 0)
                    }
                    if let g = groups.first(where: { $0.id == openGroup }) {
                        stageTwo(g).transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        stageOne.transition(.move(edge: .leading).combined(with: .opacity))
                        manualInput.padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.interactively)
            if vm.isCheckingOwned {
                Color.black.opacity(0.06).ignoresSafeArea()
                ProgressView().controlSize(.large)
            }
        }
        .allowsHitTesting(!vm.isCheckingOwned)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: openGroup)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

    // MARK: Stage 1 — one row per object

    private var stageOne: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("写っている物"))
                .scaledFont(size: 13, weight: .semibold)
                .foregroundStyle(Theme.muted)
                .padding(.top, 6)
            VStack(spacing: 0) {
                ForEach(Array(groups.enumerated()), id: \.element.id) { idx, g in
                    stageOneRow(g)
                        .accessibilityIdentifier("candidate.\(idx)")
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05 + Double(idx) * 0.05), value: appeared)
                    if idx < groups.count - 1 { Divider().overlay(Theme.border) }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
            .tourAnchor(.pick)
        }
    }

    private func stageOneRow(_ g: CandidateGroup) -> some View {
        HStack(spacing: 10) {
            Button {
                if g.others.isEmpty {
                    vm.pick(g.main)
                } else {
                    Haptics.selection()
                    openGroup = g.id
                }
            } label: {
                HStack(spacing: 8) {
                    wordLine(g.main, size: 24, note: false)
                        .matchedGeometryEffect(id: "word-\(g.id)", in: hero, properties: .position, anchor: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !g.others.isEmpty {
                        HStack(spacing: 2) {
                            Text(L("ほかの言い方 \(g.others.count)"))
                            Image(systemName: "chevron.right").scaledFont(size: 11, weight: .semibold)
                        }
                        .scaledFont(size: 12)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .layoutPriority(-1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle(scale: 0.98))
            PronounceCircle(text: g.main.headword)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 68)
    }

    // MARK: Stage 2 — the everyday name large, other names small

    private func stageTwo(_ g: CandidateGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                openGroup = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").scaledFont(size: 14, weight: .semibold)
                    Text(L("戻る"))
                }
                .scaledFont(size: 16)
                .foregroundStyle(Theme.muted)
                .frame(minHeight: 44)
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    wordLine(g.main, size: 40, note: true)
                        .matchedGeometryEffect(id: "word-\(g.id)", in: hero, properties: .position, anchor: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PronounceCircle(text: g.main.headword, size: 48)
                }
                Button { vm.pick(g.main) } label: {
                    Text(L("この語で図鑑に入れる"))
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Theme.primary, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("candidate.confirm")
            }
            .padding(16)
            .background(Theme.card, in: .rect(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)

            Text(L("ほかの言い方"))
                .scaledFont(size: 13, weight: .semibold)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(g.others.enumerated()), id: \.element.id) { idx, c in
                    HStack(spacing: 8) {
                        Button { vm.pick(c) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                if let chip = Self.registerLabel(c.register) {
                                    Text(chip)
                                        .scaledFont(size: 11)
                                        .foregroundStyle(Theme.muted)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Theme.secondary, in: Capsule())
                                }
                                wordLine(c, size: 20, note: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle(scale: 0.98))
                        PronounceCircle(text: c.headword, size: 36)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 56)
                    if idx < g.others.count - 1 { Divider().overlay(Theme.border) }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
        }
    }

    static func registerLabel(_ register: String?) -> String? {
        switch register {
        case "casual": L("砕けた言い方")
        case "specific": L("くわしい名前")
        case "proper": L("固有名詞")
        default: nil
        }
    }

    /// Zhuyin to the right of each character; meaning up to 2 lines (wraps, never scrolls sideways);
    /// the usage note only in stage 2.
    private func wordLine(_ c: Candidate, size: CGFloat, note: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ZhuyinWordView(headword: c.headword, zhuyin: c.zhuyin, size: size, pinyin: c.pinyin)
            Text(ReaderLanguage.shown(c.meaningJa))
                .scaledFont(size: size >= 34 ? 16 : 13)
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if note, !ReaderLanguage.shown(c.distinction, hanOnlyOk: false).isEmpty {
                Text(ReaderLanguage.shown(c.distinction, hanOnlyOk: false))
                    .scaledFont(size: size >= 34 ? 14 : 12)
                    .foregroundStyle(Theme.primaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: "違う単語を入力"

    private var manualInput: some View {
        VStack(alignment: .trailing, spacing: 8) {
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
                Button(action: submit) {
                    HStack(spacing: 6) {
                        if vm.isLookingUp { ProgressView().controlSize(.small) } else { Image(systemName: "magnifyingglass") }
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
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    private func submit() {
        let q = typed.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        inputFocused = false
        typed = ""
        openGroup = nil
        vm.search(text: q, keepPhoto: vm.photo != nil)
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
