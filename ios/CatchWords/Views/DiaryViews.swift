import SwiftUI

/// The diary line under an album page (HomeShelf `onWrite`): shows the day's text in the hand font,
/// or a "日記を書く" pill. Tapping opens the writing sheet in place.
struct DiaryLine: View {
    let day: Date
    let onWrite: (Date) -> Void
    @Environment(DiaryStore.self) private var diary

    var body: some View {
        let text = diary.text(for: day)
        let pending = diary.draft(for: day)
        VStack(alignment: .leading, spacing: 10) {
            if !text.isEmpty {
                Text(text)
                    .font(AppFont.hand(19))
                    .foregroundStyle(Color(hex: 0x33291F))
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background {
                        RuledPaper().clipShape(.rect(cornerRadius: 10))
                    }
            }
            HStack(spacing: 8) {
                Button { onWrite(day) } label: {
                    Label(text.isEmpty ? L("日記を書く") : L("日記を書き直す"), systemImage: "pencil.line")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primaryInk)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(.white.opacity(0.85), in: Capsule())
                        .overlay(Capsule().stroke(Theme.primary.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                if pending != nil {
                    Label(L("未送信の下書き"), systemImage: "icloud.slash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .task(id: DiaryStore.key(day)) { await diary.loadMonth(of: day) }
    }
}

/// Faint ruled lines behind the diary text (paper, no blue rule on the prose itself).
struct RuledPaper: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 38
            while y < size.height {
                var p = Path()
                p.move(to: CGPoint(x: 12, y: y))
                p.addLine(to: CGPoint(x: size.width - 12, y: y))
                ctx.stroke(p, with: .color(Color(hex: 0x33291F, opacity: 0.08)), lineWidth: 1)
                y += 32
            }
        }
        .background(Color(hex: 0xFFFDF7))
    }
}

/// Writing sheet: keeps the device copy on every keystroke (date-keyed) so nothing is lost
/// if the save never reaches the server. On today's page it also offers the web JournalComposer's
/// help: questions made from today's catches, sentence patterns, and the AI correction.
struct DiaryComposer: View {
    let day: Date
    @Environment(DiaryStore.self) private var diary
    @Environment(DexStore.self) private var dex
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var text: String = ""
    @State private var justCorrected = false
    @FocusState private var focused: Bool

    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var entry: JournalEntry? { diary.entry(for: day) }

    private var todaysWords: [String] {
        let cal = Calendar.current
        return dex.stickers.filter { cal.isDate($0.takenAt, inSameDayAs: day) }.compactMap { $0.word?.headword }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !todaysWords.isEmpty { wordChips }
                        if isToday, entry?.correction == nil, let sc = diary.scaffold {
                            ScaffoldCard(scaffold: sc) { insert($0) }
                                .padding(.horizontal, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        editor
                        if let m = diary.message {
                            Text(m).font(.system(size: 13)).foregroundStyle(Theme.destructive).padding(.horizontal, 16)
                        }
                        if isToday { correctButton }
                        if let e = entry, e.correction != nil || !(e.nativePhrases ?? []).isEmpty {
                            CorrectionBlock(entry: e, highlight: justCorrected)
                                .padding(.horizontal, 16)
                                .id("result")
                                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                        }
                        Color.clear.frame(height: 24)
                    }
                    .padding(.top, 8)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.86), value: entry)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.86), value: diary.scaffold)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: justCorrected) { _, v in
                    if v { withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) { proxy.scrollTo("result", anchor: .top) } }
                }
            }
            .background(Theme.background)
            .navigationTitle(L("\(JPDate.monthDay(day))の日記"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("閉じる")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await diary.save(text, for: day) {
                                Haptics.success()
                                SoundService.shared.play(.bookOpen)
                                dismiss()
                            } else {
                                Haptics.warning()
                            }
                        }
                    } label: {
                        if diary.isSaving { ProgressView() } else { Text(L("保存")).bold() }
                    }
                    .disabled(diary.isSaving || diary.isCorrecting)
                }
            }
        }
        .onAppear {
            text = diary.draft(for: day) ?? diary.text(for: day)
            focused = text.isEmpty
        }
        .task {
            if !diary.journalLoaded { await diary.loadJournal() }
            if isToday { await diary.loadScaffold() }
        }
        .onChange(of: text) { _, v in diary.keepDraft(v, for: day) }
    }

    private var wordChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(Set(todaysWords)).sorted(), id: \.self) { w in
                        Button {
                            Haptics.selection()
                            text += w
                        } label: {
                            Text(w)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.primaryInk)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .background(Theme.accent, in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityHint(L("本文に入れる"))
                    }
                }
            }
            .contentMargins(.horizontal, 16)
            Text(L("今日キャッチした語を押すと本文に入ります"))
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
                .padding(.horizontal, 16)
        }
    }

    private var editor: some View {
        TextEditor(text: $text)
            .font(AppFont.hand(21))
            .foregroundStyle(Color(hex: 0x33291F))
            .scrollContentBackground(.hidden)
            .frame(minHeight: 220)
            .padding(12)
            .background(RuledPaper().clipShape(.rect(cornerRadius: 14)))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(isToday ? L("例: 今天早上我去咖啡店…") : L("この日のことを、学んでいる言葉で書いてみよう"))
                        .font(AppFont.hand(19))
                        .foregroundStyle(Theme.muted.opacity(0.7))
                        .padding(.horizontal, 18).padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            .focused($focused)
            .padding(.horizontal, 16)
    }

    private var correctButton: some View {
        let ready = text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                focused = false
                Task {
                    justCorrected = false
                    if await diary.correct(text, for: day) {
                        Haptics.success()
                        SoundService.shared.play(.bookOpen)
                        justCorrected = true
                    } else {
                        Haptics.warning()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if diary.isCorrecting {
                        ProgressView().tint(.white).controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .symbolEffect(.bounce, value: justCorrected)
                    }
                    Text(diary.isCorrecting ? L("添削中…") : L("AIに添削してもらう"))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ready ? .white : Theme.muted)
                .padding(.horizontal, 20)
                .frame(minHeight: 46)
                .background {
                    if ready {
                        Capsule().fill(Theme.brandGradient).shadow(color: Theme.primary.opacity(0.3), radius: 10, y: 4)
                    } else {
                        Capsule().fill(Theme.secondary)
                    }
                }
            }
            .buttonStyle(PressableStyle())
            .disabled(!ready || diary.isCorrecting)
            Text(L("書いたものはこの端末に控えてあります。添削が通らなくても消えません。"))
                .font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
    }

    /// Adds a pattern at the end — never over what is already written.
    private func insert(_ zh: String) {
        Haptics.selection()
        let trimmed = text.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        text = trimmed.isEmpty ? zh : trimmed + "\n" + zh
    }
}

/// 「今日撮ったものから」: questions tied to today's catches, and patterns that insert on tap.
private struct ScaffoldCard: View {
    let scaffold: JournalScaffold
    let onUsePattern: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L("今日撮ったものから"), systemImage: "sparkles")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.primaryInk)
            ForEach(Array(scaffold.prompts.enumerated()), id: \.offset) { _, p in
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.questionZh)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.foreground)
                        Text(p.questionJa)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                        if let id = p.stickerId, let head = scaffold.captures.first(where: { $0.id == id })?.headword {
                            Text(L("「\(head)」のこと"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.primaryInk.opacity(0.8))
                        }
                    }
                    Spacer(minLength: 0)
                    PronounceCircle(text: p.questionZh, size: 36)
                }
                .padding(10)
                .background(Theme.secondary.opacity(0.7), in: .rect(cornerRadius: 12, style: .continuous))
            }
            if !scaffold.patterns.isEmpty {
                Divider().padding(.vertical, 2)
                Text(L("この型が使えます"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.muted)
                FlowRow(spacing: 6) {
                    ForEach(Array(scaffold.patterns.enumerated()), id: \.offset) { _, pt in
                        Button { onUsePattern(pt.zh) } label: {
                            Text(pt.zh)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.primaryInk)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .background(Theme.primary.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityHint(pt.ja)
                    }
                }
                Text(L("押すと下に入ります")).font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.border))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

/// The corrected text, the notes on patterns, and 「ネイティブならこう言う」 (web EntryBlock + NativePhrases).
struct CorrectionBlock: View {
    let entry: JournalEntry
    var highlight: Bool = false
    var compact: Bool = false

    /// Notes from the server, only when written in the display language (an entry corrected while
    /// the app was in another language keeps its sentences but hides the old-language notes).
    private func readable(_ text: String?, source: String? = nil) -> String? {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty,
              !ReaderLanguage.looksWrong(t, reader: L10n.lang, source: source) else { return nil }
        return t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let c = entry.correction ?? entry.bodyZh, !c.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if !compact {
                        Text(L("✦ 添削後")).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.primaryInk)
                    }
                    HStack(alignment: .top) {
                        Text(c)
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.foreground)
                            .lineSpacing(5)
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                        if !compact { PronounceCircle(text: c, size: 36) }
                    }
                    if let f = readable(entry.feedbackJa) {
                        Text(L("型と解説")).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted).padding(.top, 4)
                        Text(f).font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(3)
                    }
                    if entry.correction == nil, let ja = readable(entry.bodyJa, source: c) {
                        Text(ja).font(.system(size: 14)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(compact ? 0 : 16)
                .background {
                    if !compact {
                        RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card)
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(highlight ? Theme.primary.opacity(0.45) : Theme.border, lineWidth: highlight ? 1.5 : 1))
                            .shadow(color: Theme.primary.opacity(highlight ? 0.15 : 0.03), radius: highlight ? 16 : 6, y: 4)
                    }
                }
            }
            if let phrases = entry.nativePhrases, !phrases.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(L("ネイティブならこう言う"), systemImage: "quote.opening")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.primaryInk)
                    ForEach(Array(phrases.enumerated()), id: \.offset) { _, p in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.zh).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.foreground)
                                if let ja = readable(p.ja, source: p.zh) {
                                    Text(ja).font(.system(size: 13)).foregroundStyle(Theme.muted)
                                }
                                if let n = readable(p.note) {
                                    Text(n).font(.system(size: 12)).foregroundStyle(Theme.muted.opacity(0.9))
                                }
                            }
                            Spacer(minLength: 0)
                            PronounceCircle(text: p.zh, size: 32)
                        }
                        .padding(12)
                        .background(Theme.card, in: .rect(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border.opacity(0.7)))
                    }
                }
                .padding(compact ? 0 : 14)
                .background(compact ? Color.clear : Theme.primary.opacity(0.05), in: .rect(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

/// 「過去の日記」: the last 30 days with their corrections (web /journal).
struct JournalHistoryView: View {
    @Environment(DiaryStore.self) private var diary
    @Environment(\.dismiss) private var dismiss

    private var past: [JournalEntry] {
        let today = DiaryStore.key(Date())
        return diary.journal.filter { $0.entryDate != today && ($0.correction ?? $0.userDraft ?? $0.bodyZh) != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if !diary.journalLoaded {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 18).fill(Theme.secondary).frame(height: 110)
                        }
                        .redacted(reason: .placeholder)
                    } else if diary.journalFailed {
                        VStack(spacing: 10) {
                            Text(L("日記を読み込めませんでした。")).foregroundStyle(Theme.muted)
                            Button(L("もう一度")) { Task { await diary.loadJournal() } }
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                    } else if past.isEmpty {
                        ContentUnavailableView(L("まだ過去の日記はありません"), systemImage: "book.closed",
                                               description: Text(L("書いた日記と添削はここに並びます。")))
                            .padding(.top, 40)
                    } else {
                        ForEach(past) { e in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(DiaryStore.date(from: e.entryDate).map { JPDate.monthDay($0) } ?? e.entryDate)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.muted)
                                if let draft = e.userDraft, !draft.isEmpty {
                                    Text(draft)
                                        .font(AppFont.hand(19))
                                        .foregroundStyle(Color(hex: 0x33291F))
                                        .lineSpacing(5)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(14)
                                        .background(RuledPaper().clipShape(.rect(cornerRadius: 12)))
                                }
                                if e.correction != nil || e.bodyZh != nil || !(e.nativePhrases ?? []).isEmpty {
                                    CorrectionBlock(entry: e, compact: true)
                                }
                            }
                            .padding(16)
                            .background(Theme.card, in: .rect(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border))
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle(L("過去の日記"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("閉じる")) { dismiss() } }
            }
            .refreshable { await diary.loadJournal() }
            .task { await diary.loadJournal() }
        }
    }
}

/// Banner for drafts that never reached the server and crossed midnight (journal-drafts.ts).
struct StrandedDiaryBanner: View {
    let onOpen: (Date) -> Void
    @Environment(DiaryStore.self) private var diary

    var body: some View {
        if let first = diary.strandedDrafts.first {
            Button { onOpen(first.date) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text").foregroundStyle(Theme.primaryInk)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("\(JPDate.monthDay(first.date))の日記が保存されていません"))
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.foreground)
                        Text(first.text).lineLimit(1).font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                .padding(14)
                .background(Theme.card, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
            }
            .buttonStyle(PressableStyle())
        }
    }
}
