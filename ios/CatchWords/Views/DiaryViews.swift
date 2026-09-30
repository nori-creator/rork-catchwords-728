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
                    Label(text.isEmpty ? "日記を書く" : "日記を書き直す", systemImage: "pencil.line")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primaryInk)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(.white.opacity(0.85), in: Capsule())
                        .overlay(Capsule().stroke(Theme.primary.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                if pending != nil {
                    Label("未送信の下書き", systemImage: "icloud.slash")
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
/// if the save never reaches the server.
struct DiaryComposer: View {
    let day: Date
    @Environment(DiaryStore.self) private var diary
    @Environment(DexStore.self) private var dex
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var focused: Bool

    private var todaysWords: [String] {
        let cal = Calendar.current
        return dex.stickers.filter { cal.isDate($0.takenAt, inSameDayAs: day) }.compactMap { $0.word?.headword }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if !todaysWords.isEmpty {
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
                                .accessibilityHint("本文に入れる")
                            }
                        }
                    }
                    .contentMargins(.horizontal, 16)
                    Text("今日キャッチした語を押すと本文に入ります")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted)
                        .padding(.horizontal, 16)
                }
                TextEditor(text: $text)
                    .font(AppFont.hand(21))
                    .foregroundStyle(Color(hex: 0x33291F))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(RuledPaper().clipShape(.rect(cornerRadius: 14)))
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("今日のことを、学んでいる言葉で書いてみよう")
                                .font(AppFont.hand(19))
                                .foregroundStyle(Theme.muted.opacity(0.7))
                                .padding(.horizontal, 18).padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }
                    .focused($focused)
                    .padding(.horizontal, 16)
                if let m = diary.message {
                    Text(m).font(.system(size: 13)).foregroundStyle(Theme.destructive).padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .background(Theme.background)
            .navigationTitle("\(JPDate.monthDay(day))の日記")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
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
                        if diary.isSaving { ProgressView() } else { Text("保存").bold() }
                    }
                    .disabled(diary.isSaving)
                }
            }
        }
        .onAppear {
            text = diary.draft(for: day) ?? diary.text(for: day)
            focused = true
        }
        .onChange(of: text) { _, v in diary.keepDraft(v, for: day) }
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
                        Text("\(JPDate.monthDay(first.date))の日記が保存されていません")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.foreground)
                        Text(first.text).lineLimit(1).font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                .padding(14)
                .background(.white, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
            }
            .buttonStyle(PressableStyle())
        }
    }
}
