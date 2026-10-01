import SwiftUI

/// review.tsx answer sheet: pinned above the tab bar after a 4-choice pick — verdict band,
/// the headword with zhuyin, a short scrollable explanation, then 図鑑で見る / 次へ.
struct AnswerPanel: View {
    let sticker: Sticker
    let correct: Bool
    let onDex: () -> Void
    let onNext: () -> Void

    @Environment(DexStore.self) private var dex
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Drives the entrance: the verdict colour spreads across the band, then the word and buttons rise in.
    @State private var spread: CGFloat = 0
    @State private var settled = false
    /// The live word (its meaning arrives in the reader's language after the card was made).
    private var word: Word? { dex.sticker(id: sticker.id)?.word ?? sticker.word }
    private var headword: String { word?.headword ?? "" }
    private var tint: Color { correct ? Theme.ok : Theme.destructive }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .symbolEffect(.bounce, value: settled)
                Text(correct ? L("正解！") : L("もう一度覚えよう"))
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(tint.mix(with: .black, by: 0.25))
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(alignment: .leading) {
                // The verdict colour spreads from the left edge, like ink soaking in.
                GeometryReader { geo in
                    tint.opacity(0.14)
                        .frame(width: geo.size.width * spread)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    ZhuyinWordView(headword: headword, zhuyin: word?.readingZhuyin, size: 26, weight: .bold, pinyin: word?.pinyin)
                    Spacer(minLength: 0)
                    PronounceCircle(text: headword, size: 46)
                }
                .padding(.top, 8)

                explain

                HStack(spacing: 10) {
                    Button(action: onDex) {
                        Label(L("図鑑で見る"), systemImage: "book")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.foreground)
                            .labelStyle(TintedIconLabel())
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.card, in: .rect(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle(scale: 0.98))
                    Button(action: onNext) {
                        Text(L("次へ"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.primary, in: .rect(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressableStyle(scale: 0.98))
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
            .opacity(settled ? 1 : 0)
            .offset(y: settled ? 0 : 10)
        }
        .onAppear {
            if reduceMotion {
                spread = 1
                settled = true
                return
            }
            withAnimation(.easeOut(duration: 0.32)) { spread = 1 }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.08)) { settled = true }
        }
        .background(Theme.card)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .stroke(tint.opacity(0.7), lineWidth: 1.5)
                .mask(alignment: .top) { Rectangle().frame(height: 30) }
        }
        .shadow(color: .black.opacity(0.14), radius: 18, y: -4)
    }

    // MARK: - Explanation (explainOf in reviews.functions.ts)

    private var chunks: [UsageChunk] {
        // R20: only chunks that actually contain the word being learned.
        let lang = learningLang
        return Array((word?.extras?.usageChunks ?? []).compactMap { raw -> UsageChunk? in
            // docs/chunk-rules.md C7/C8: the same shape as the word detail draws.
            let c = UsageChunk(parts: ChunkRules.tidy(raw.parts, headword: headword, target: lang, reader: L10n.lang), ja: raw.ja)
            guard ChunkRules.isPattern(original: raw.parts, tidied: c.parts),
                  LanguageRules.mentionsHeadword(c.parts.map(\.text).joined(separator: " "), headword: headword, target: lang) else { return nil }
            return c
        }.prefix(3))
    }
    private var learningLang: String { LanguageRules.resolveWordLanguage(stored: word?.language, headword: headword) }
    private var related: [RelatedWord] { Array((word?.extras?.allRelated ?? []).prefix(4)) }
    private var measures: [MeasureWord] {
        Array((word?.extras?.measureWords ?? []).filter { !$0.word.trimmingCharacters(in: .whitespaces).isEmpty }.prefix(2))
    }
    /// The Taiwan note is a Mandarin-only section (the detail shows it for zh-TW only); either note is shown
    /// only when it is written in the display language.
    private var note: String {
        let taiwan = learningLang == "zh-TW" ? word?.extras?.taiwanNote : nil
        return ReaderLanguage.shown(taiwan, word?.extras?.usageContext, source: headword)
    }

    @ViewBuilder
    private var explain: some View {
        let hasExplain = !chunks.isEmpty || !related.isEmpty || !measures.isEmpty || !note.isEmpty
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if hasExplain {
                    if !chunks.isEmpty { chunkSection }
                    if !related.isEmpty { relatedSection }
                    if !measures.isEmpty { measureSection }
                    if !note.isEmpty {
                        section(L("知っておくと得"), tone: Color(hex: 0x134E4A), bg: Color(hex: 0xF0FDFA)) {
                            Text(note).font(.system(size: 14)).foregroundStyle(Theme.foreground).lineSpacing(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    fallback
                }
            }
        }
        .frame(maxHeight: 250)
        .fixedSize(horizontal: false, vertical: true)
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.visible)
    }

    @ViewBuilder
    private var fallback: some View {
        if let m = word?.meaningJa, !m.isEmpty {
            section(L("意味"), tone: Theme.muted, bg: Theme.secondary.opacity(0.6)) {
                Text(m).font(.system(size: 15)).foregroundStyle(Theme.foreground)
            }
        }
        // An example is shown only when it is in the learning language (as on the detail), its translation
        // only when it is in the display language.
        if let ex = word?.exampleSentence, !ex.isEmpty, LanguageRules.isIn(ex, target: learningLang) {
            section(L("例文"), tone: Color(hex: 0x312E81), bg: Theme.secondary.opacity(0.6)) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ex).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.foreground)
                    let tr = ReaderLanguage.shown(word?.exampleTranslation, source: ex)
                    if !tr.isEmpty {
                        Text(tr).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                }
            }
        }
    }

    private var chunkSection: some View {
        let kinds = Set(chunks.flatMap { $0.parts.map { ChunkKind(pos: $0.pos) } })
        return section(L("よく使う形"), tone: Theme.muted, bg: Theme.secondary.opacity(0.6)) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(chunks.enumerated()), id: \.offset) { _, chunk in
                    ChunkLineView(chunk: chunk, headword: headword, target: learningLang, size: .compact)
                }
                HStack(spacing: 12) {
                    ForEach(ChunkKind.allCases.filter { kinds.contains($0) }, id: \.self) { k in
                        HStack(spacing: 4) {
                            Circle().fill(k.ink).frame(width: 7, height: 7)
                            Text(k.label(for: learningLang)).font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
        }
    }

    private var relatedSection: some View {
        section(L("一緒に覚える語"), tone: Color(hex: 0x312E81), bg: Color(hex: 0xEEF2FF)) {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(related, id: \.word) { r in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        kindTag(r.kind)
                        Text(r.word).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.foreground)
                        if !r.note.isEmpty {
                            Text(r.note).font(.system(size: 12)).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
        }
    }

    private func kindTag(_ kind: String) -> some View {
        let (label, bg, ink): (String, UInt32, UInt32) = switch kind {
        case "syn": (L("似"), 0xA7F3D0, 0x064E3B)
        case "ant": (L("反"), 0xFECDD3, 0x881337)
        default: (L("関"), 0xE2E8F0, 0x0F172A)
        }
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color(hex: ink))
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(Color(hex: bg), in: .rect(cornerRadius: 4))
    }

    private var measureSection: some View {
        section(L("量詞"), tone: Color(hex: 0x78350F), bg: Color(hex: 0xFFFBEB)) {
            FlowRow(spacing: 12) {
                ForEach(measures, id: \.word) { m in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(m.word).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.foreground)
                        if let n = m.note, !n.isEmpty {
                            Text(n).font(.system(size: 12)).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, tone: Color, bg: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(tone)
            content()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg, in: .rect(cornerRadius: 14, style: .continuous))
    }
}

/// Label with a primary-tinted icon and default-coloured title.
private struct TintedIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.foregroundStyle(Theme.primary)
            configuration.title
        }
    }
}
