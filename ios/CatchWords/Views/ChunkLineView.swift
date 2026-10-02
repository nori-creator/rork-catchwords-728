import SwiftUI

/// One usage chunk as a formula (docs/chunk-rules.md, web ChunkLine): blocks joined by ＋, the translation
/// under them, and a button that reads the whole chunk. The same view in word detail and the review answer.
///
/// - The word being learned is a fixed, bolder block (C2).
/// - A swappable block (dashed, ▾) opens a wheel of the words natives put there (C5/C6). Picking one
///   reads that word, swaps it into the chunk and its translation; the right button reads the new chunk.
/// - Any other block reads its own word.
struct ChunkLineView: View {
    @Environment(\.colorScheme) private var colorScheme
    enum Size { case large, compact }

    let chunk: UsageChunk
    let headword: String
    let target: String
    var size: Size = .large
    /// Previews only: the part whose wheel is open at first.
    var startOpen: Int? = nil

    @State private var open: Int?
    /// Part index → chosen text.
    @State private var pick: [Int: String] = [:]

    private var shown: [ChunkPart] {
        chunk.parts.enumerated().map { i, p in
            guard let t = pick[i], t != p.text else { return p }
            var q = p
            q.text = t
            return q
        }
    }

    private var translation: String {
        pick.isEmpty ? chunk.ja : ChunkRules.swappedTranslation(chunk.ja, original: chunk.parts, shown: shown, reader: L10n.lang)
    }

    var body: some View {
        HStack(alignment: .center, spacing: size == .large ? 10 : 8) {
            VStack(alignment: .leading, spacing: size == .large ? 8 : 5) {
                FlowRow(spacing: 4) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { i, part in
                        HStack(spacing: 4) {
                            if i > 0 {
                                Text("+")
                                    .font(.system(size: size == .large ? 15 : 12, weight: .bold))
                                    .foregroundStyle(Theme.muted.opacity(0.45))
                                    .accessibilityHidden(true)
                            }
                            block(i, part)
                        }
                    }
                }
                if !translation.isEmpty {
                    Text(translation)
                        .font(.system(size: size == .large ? 16 : 13))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(3)
                        .contentTransition(.opacity)
                        .animation(.easeOut(duration: 0.2), value: translation)
                }
                if let i = open, let part = chunk.parts[safe: i] {
                    wheel(i, part)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            Spacer(minLength: 0)
            PronounceCircle(text: ChunkRules.spoken(shown, target: target), size: size == .large ? 50 : 36)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: open)
        .onAppear { if let startOpen { open = startOpen } }
    }

    private func block(_ i: Int, _ part: ChunkPart) -> some View {
        let kind = ChunkKind(pos: part.pos)
        let original = chunk.parts[safe: i] ?? part
        let isHead = !headword.isEmpty && LanguageRules.mentionsHeadword(original.text, headword: headword, target: target)
        let swappable = !isHead && ChunkRules.isSwappable(original, headword: headword, target: target)
        let isOpen = open == i
        let big = size == .large
        return Button {
            SoundService.shared.speak(part.text)
            if swappable {
                Haptics.selection()
                open = isOpen ? nil : i
            }
        } label: {
            HStack(spacing: 3) {
                Text(part.text)
                    .font(.system(size: big ? 20 : 15, weight: .bold))
                    .contentTransition(.opacity)
                if swappable {
                    Image(systemName: "chevron.down")
                        .font(.system(size: big ? 11 : 9, weight: .bold))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
            }
            // Darker ink on the light page, lighter on the dark one (mixing with black vanished in dark mode).
            .foregroundStyle(kind.ink.mix(with: colorScheme == .dark ? .white : .black, by: big ? 0.3 : 0.25))
            .padding(.horizontal, big ? 12 : 10)
            .frame(minHeight: big ? 48 : 34)
            .background(kind.ink.opacity(isHead ? 0.15 : swappable ? 0.04 : 0.08), in: .rect(cornerRadius: big ? 12 : 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: big ? 12 : 10, style: .continuous)
                    .stroke(kind.ink.opacity(isHead ? 0.78 : swappable ? 0.6 : 0.35),
                            style: StrokeStyle(lineWidth: isHead ? (big ? 2.5 : 2) : 1.5, dash: swappable ? [4, 3] : []))
            }
            .shadow(color: kind.ink.opacity(isHead ? 0.18 : 0), radius: 6, y: 2)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .accessibilityLabel(part.text)
        .accessibilityHint(swappable ? L("ほかの語に入れ替えられます") : "")
        .accessibilityAddTraits(isHead ? .isHeader : [])
    }

    /// The words natives put in this part, the current one first; each with its meaning (C6).
    private func wheel(_ i: Int, _ part: ChunkPart) -> some View {
        let choices = ChunkRules.choices(part)
        let selection = Binding<String>(
            get: { pick[i] ?? part.text },
            set: { t in
                pick[i] = t == part.text ? nil : t
                Haptics.selection()
                SoundService.shared.speak(t)
            }
        )
        return HStack(spacing: 8) {
            Picker(L("ほかの語"), selection: selection) {
                ForEach(choices, id: \.text) { c in
                    HStack(spacing: 10) {
                        Text(c.text).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.foreground)
                        if !c.ja.isEmpty {
                            Text(c.ja).font(.system(size: 14)).foregroundStyle(Theme.muted)  // lang-ok: filtered in ReaderLanguage.resolve (alts) or ChunkRules.degreeGloss (reader's own)
                        }
                    }
                    .tag(c.text)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: size == .large ? 132 : 110)
            .clipped()
            Button {
                open = nil
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L("閉じる"))
        }
        .padding(.horizontal, 6)
        .background(Theme.secondary.opacity(0.8), in: .rect(cornerRadius: 14, style: .continuous))
    }
}
