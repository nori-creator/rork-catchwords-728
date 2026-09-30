import SwiftUI

/// capture.tsx PickWordPanel: small photo, "写っている物" list (WordCandidateRow), and "違う単語を入力".
struct CandidatePickerView: View {
    let vm: CaptureViewModel
    @State private var appeared: Bool = false
    @State private var typed: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    CollectHeader { vm.reset() }
                    if let photo = vm.photo {
                        Color.clear
                            .frame(width: 156, height: 156)
                            .overlay { Image(uiImage: photo).resizable().scaledToFill().allowsHitTesting(false) }
                            .clipShape(.rect(cornerRadius: 24, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
                            .frame(maxWidth: .infinity)
                            .scaleEffect(appeared ? 1 : 0.9)
                            .opacity(appeared ? 1 : 0)
                    }
                    Text("写っている物")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 6)
                    VStack(spacing: 0) {
                        ForEach(Array(vm.candidates.enumerated()), id: \.element.id) { idx, c in
                            row(c)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 14)
                                .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05 + Double(idx) * 0.05), value: appeared)
                            if idx < vm.candidates.count - 1 { Divider().overlay(Theme.border) }
                        }
                    }
                    .background(Theme.card, in: .rect(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))

                    manualInput.padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private func row(_ c: Candidate) -> some View {
        HStack(spacing: 10) {
            Button { vm.pick(c) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    ZhuyinWordView(headword: c.headword, zhuyin: c.zhuyin, size: 22)
                    Text(c.meaningJa)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle(scale: 0.98))
            if c.alternatives.isEmpty {
                PronounceCircle(text: c.headword)
            } else {
                Menu {
                    Section("ほかの言い方") {
                        Button(c.headword) { vm.pick(c) }
                        ForEach(c.alternatives, id: \.self) { alt in
                            Button(alt) { vm.search(text: alt, keepPhoto: true) }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text("ほかの言い方 \(c.alternatives.count)")
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .frame(minHeight: 44)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 68)
    }

    private var manualInput: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("違う単語を入力")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 8) {
                TextField("", text: $typed, prompt: Text("例: 椅子").foregroundStyle(Theme.muted.opacity(0.7)))
                    .font(.system(size: 16))
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
                        Text("検索")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 46)
                    .background(Theme.secondary, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(PressableStyle())
                .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLookingUp)
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
        vm.search(text: q, keepPhoto: vm.photo != nil)
    }
}

/// Page header used through the catch flow ("集める").
struct CollectHeader: View {
    var onClose: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            LogoMark(size: 30)
            Text("集める")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.muted)
            Spacer()
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("カメラに戻る")
            }
        }
        .padding(.top, 4)
    }
}

/// The vivid blue pronounce button (PronounceButton tone="hero").
struct PronounceCircle: View {
    let text: String
    var size: CGFloat = 42

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
        .accessibilityLabel("発音を聞く")
    }
}
