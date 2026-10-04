import SwiftUI

/// One day in a month's album book: the photos go on the left page, the diary on the right.
struct BookDay: Identifiable, Equatable {
    let day: Date
    let items: [Sticker]
    var id: Date { day }
}

/// A month as a real book (owner 2026-09-30): one page at a time on the phone.
/// - On the left page (the day's photos), swipe left → slide to the right page (that day's diary).
/// - On the right page, swipe left → the page turns over and the next day's left page is underneath.
/// - Swiping right goes back the same way (back to the left page, or the previous day's page turns back in).
/// The home shows this month's book open at today; past months live on the bookshelf.
struct MonthBookView: View {
    let days: [BookDay]
    /// Open at the last day (this month: today) or at the first (a past month from the shelf).
    var startAtEnd: Bool = true
    let onOpen: (Sticker) -> Void
    let onWrite: (Date) -> Void
    var onCamera: (() -> Void)? = nil
    /// DEBUG preview only: slides and turns by itself so the simulator frames show the motion.
    var autoplay: Bool = false
    /// DEBUG preview only: hold the right page part-way through its turn (0…1) to photograph it.
    var frozenTurn: CGFloat? = nil

    private enum Side { case left, right }

    @Environment(\.appReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var side: Side = .left
    /// Horizontal finger travel while sliding between the two pages of a day.
    @State private var slide: CGFloat = 0
    /// 0…1 while the right page turns forward (next day), or while the previous page turns back in.
    @State private var turn: CGFloat = 0
    @State private var turningBack = false
    @State private var dragging: DragMode = .none
    @State private var editingPhotos = false
    @State private var didStart = false

    private enum DragMode { case none, slide, forward, back, rubber }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                bookBack
                if days.indices.contains(index) {
                    pageArea(w: w - 18, h: h - 14)
                        .padding(.leading, 12)
                        .padding(.trailing, 6)
                        .padding(.vertical, 7)
                }
            }
        }
        .denseTypeSizeCap()  // two fixed paper pages
        .onAppear {
            guard !didStart else { return }
            didStart = true
            index = startAtEnd ? max(0, days.count - 1) : 0
            if let frozenTurn { side = .right; turn = frozenTurn }
        }
        .onChange(of: days.count) { old, new in
            // A new day appeared (first catch of the day): stay on the page you were reading,
            // unless you were at the end — then follow to the new end.
            if index >= old - 1 { index = max(0, new - 1) }
            index = min(index, max(0, new - 1))
        }
        .task(id: autoplay) { if autoplay { await runAutoplay() } }
    }

    // MARK: - The book body

    /// Leather cover edge and the stack of page edges under the open page.
    private var bookBack: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x7A4A2A), Color(hex: 0x5A331C)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
            // Stacked page edges on the open (right) side.
            HStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { i in
                        Rectangle().fill(Color(hex: i.isMultiple(of: 2) ? 0xF3EBDD : 0xE6DCCB))
                            .frame(width: 3)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.vertical, 9)
            .padding(.trailing, 3)
            // Spine with stitching.
            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: 0x3E2212), Color(hex: 0x6B3F22), Color(hex: 0x3E2212)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 12)
                .overlay {
                    Rectangle().stroke(Color(hex: 0xC9A15A).opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .padding(.vertical, 12).padding(.horizontal, 5)
                }
                .clipShape(.rect(topLeadingRadius: 10, bottomLeadingRadius: 10))
        }
    }

    private func pageArea(w: CGFloat, h: CGFloat) -> some View {
        let day = days[index]
        let next = days.indices.contains(index + 1) ? days[index + 1] : nil
        let prev = days.indices.contains(index - 1) ? days[index - 1] : nil
        return ZStack(alignment: .leading) {
            // Under the turning page: the next day's left page.
            if turn > 0, !turningBack, let next {
                leftPage(next, w: w, h: h)
                    .overlay(spineShadow(strength: 1 - turn))
            }
            // The two pages of today, side by side; only one fits the screen.
            HStack(spacing: 0) {
                leftPage(day, w: w, h: h)
                rightPage(day, w: w, h: h)
            }
            .frame(width: w, alignment: .leading)
            .offset(x: (side == .left ? 0 : -w) + slide)
            .frame(width: w, height: h, alignment: .leading)
            .clipped()
            // Turning forward: the current right page lifts off around the spine.
            .modifier(PageTurn(progress: turningBack ? 0 : turn, active: turn > 0 && !turningBack))
            // Turning back: the previous day's right page comes down over the left page.
            if turningBack, let prev {
                rightPage(prev, w: w, h: h)
                    .modifier(PageTurn(progress: 1 - turn, active: true))
            }
        }
        .frame(width: w, height: h)
        .contentShape(.rect)
        .simultaneousGesture(pageDrag(w: w), including: editingPhotos ? .subviews : .all)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: L("次のページ")) { step(forward: true, w: w) }
        .accessibilityAction(named: L("前のページ")) { step(forward: false, w: w) }
    }

    private func spineShadow(strength: CGFloat) -> some View {
        LinearGradient(colors: [.black.opacity(0.28 * strength), .clear], startPoint: .leading, endPoint: .init(x: 0.35, y: 0.5))
            .allowsHitTesting(false)
    }

    // MARK: - Pages

    private func leftPage(_ d: BookDay, w: CGFloat, h: CGFloat) -> some View {
        let isToday = Calendar.current.isDateInToday(d.day)
        return PaperPage(side: .left) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(JPDate.weekday(d.day))
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundStyle(Theme.primaryInk.opacity(0.85))
                        Text(JPDate.monthDay(d.day))
                            .scaledFont(size: 30, weight: .heavy)
                            .foregroundStyle(Color(hex: 0x33291F))
                            .monospacedDigit()
                    }
                    Spacer()
                    if !d.items.isEmpty {
                        Text(L("\(d.items.count)語"))
                            .font(AppFont.mono(12, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x33291F, opacity: 0.5))
                    }
                }
                if d.items.isEmpty {
                    VStack(spacing: 14) {
                        Text(isToday ? L("今日のページはまだ白紙です。") : L("この日は写真がありません。"))
                            .font(AppFont.hand(19))
                            .foregroundStyle(Color(hex: 0x33291F).opacity(0.65))
                        if isToday, let onCamera {
                            Button(action: onCamera) {
                                Label(L("今日の1枚を撮る"), systemImage: "camera.fill")
                                    .scaledFont(size: 15, weight: .semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .frame(minHeight: 46)
                                    .background(Theme.primary, in: Capsule())
                                    .shadow(color: Theme.primary.opacity(0.35), radius: 10, y: 5)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    PageScroll {
                        CollageBoard(items: d.items, editable: isToday, onOpen: onOpen, onEditingChange: { on in
                            editingPhotos = on
                        })
                        .padding(.bottom, 12)
                    }
                }
                pageFoot(text: L("→ 日記"), trailing: true)
            }
        }
        .frame(width: w, height: h)
    }

    private func rightPage(_ d: BookDay, w: CGFloat, h: CGFloat) -> some View {
        RightDiaryPage(day: d, onWrite: onWrite, onOpen: onOpen, foot: pageFoot(text: index < days.count - 1 ? L("めくる →") : "", trailing: true))
            .frame(width: w, height: h)
    }

    private func pageFoot(text: String, trailing: Bool) -> some View {
        HStack {
            Spacer()
            Text(text)
                .scaledFont(size: 11, weight: .medium)
                .foregroundStyle(Color(hex: 0x33291F, opacity: 0.4))
        }
    }

    // MARK: - Gestures

    private func pageDrag(w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { v in
                guard !editingPhotos else { return }
                let dx = v.translation.width
                if dragging == .none {
                    // Only horizontal swipes turn pages; vertical ones scroll the collage.
                    guard abs(dx) > abs(v.translation.height) * 1.2 else { return }
                    switch (side, dx < 0) {
                    case (.left, true), (.right, false): dragging = .slide
                    case (.right, true): dragging = index < days.count - 1 ? .forward : .rubber
                    case (.left, false): dragging = index > 0 ? .back : .rubber
                    }
                    if dragging == .back { turningBack = true }
                }
                switch dragging {
                case .slide:
                    slide = side == .left ? max(-w, min(0, dx)) : min(w, max(0, dx))
                case .forward:
                    turn = min(1, max(0, -dx / (w * 0.9)))
                case .back:
                    turn = min(1, max(0, dx / (w * 0.9)))
                case .rubber:
                    slide = dx * 0.18
                case .none: break
                }
            }
            .onEnded { v in
                let dx = v.predictedEndTranslation.width
                switch dragging {
                case .slide:
                    let go = abs(dx) > w * 0.35
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        if go { side = side == .left ? .right : .left }
                        slide = 0
                    }
                    if go { Haptics.selection() }
                case .forward:
                    finishTurn(commit: -dx > w * 0.45 || turn > 0.5)
                case .back:
                    finishTurn(commit: dx > w * 0.45 || turn > 0.5)
                case .rubber:
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { slide = 0 }
                case .none: break
                }
                dragging = .none
            }
    }

    private func finishTurn(commit: Bool) {
        let back = turningBack
        let anim: Animation = reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.9)
        withAnimation(anim) { turn = commit ? 1 : 0 } completion: {
            if commit {
                if back { index -= 1; side = .right } else { index += 1; side = .left }
            }
            turn = 0
            turningBack = false
        }
        if commit {
            SoundService.shared.play(.slide, volume: 0.45)
            Haptics.impact(.light)
        }
    }

    /// VoiceOver / autoplay: the same moves as the swipes.
    private func step(forward: Bool, w: CGFloat) {
        if forward {
            if side == .left {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { side = .right }
            } else if index < days.count - 1 {
                turningBack = false
                finishTurn(commit: true)
            }
        } else {
            if side == .right {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { side = .left }
            } else if index > 0 {
                turningBack = true
                finishTurn(commit: true)
            }
        }
    }

    private func runAutoplay() async {
        index = 0
        side = .left
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) { side = .right }
            try? await Task.sleep(for: .seconds(1.6))
            guard index < days.count - 1 else { index = 0; side = .left; continue }
            // Turn slowly so the frames catch the page mid-air.
            turningBack = false
            withAnimation(.easeInOut(duration: 1.6)) { turn = 1 } completion: {
                index += 1
                side = .left
                turn = 0
            }
            try? await Task.sleep(for: .seconds(2.2))
        }
    }
}

/// The page lifting off around the spine (its leading edge), with light falling across it.
private struct PageTurn: ViewModifier, Animatable {
    var progress: CGFloat
    let active: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let angle = -180 * Double(progress)
        content
            .overlay {
                // Darkens as it stands up; a bright crease line near the spine.
                LinearGradient(colors: [.black.opacity(0.25 * progress), .white.opacity(0.18 * sin(Double(progress) * Double.pi)), .black.opacity(0.1 * progress)],
                               startPoint: .leading, endPoint: .trailing)
                    .allowsHitTesting(false)
            }
            .rotation3DEffect(.degrees(active ? angle : 0), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.55)
            .opacity(active && progress > 0.5 ? 0 : 1)   // past upright its back faces away (the next page shows)
            .shadow(color: .black.opacity(active ? 0.3 * sin(Double(progress) * Double.pi) : 0), radius: 18, x: -8 * progress, y: 6)
    }
}

/// Cream paper with a soft gutter shadow on the spine side.
private struct PaperPage<Content: View>: View {
    enum Side { case left, right }
    let side: Side
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                ZStack {
                    Color(hex: 0xFBF6EC)
                    // Faint paper grain.
                    LinearGradient(colors: [Color(hex: 0xFFFDF8), Color(hex: 0xF4ECDD)], startPoint: .top, endPoint: .bottom).opacity(0.7)
                    LinearGradient(colors: [.black.opacity(0.14), .clear], startPoint: .leading, endPoint: .init(x: 0.08, y: 0.5))
                }
            }
            .clipShape(.rect(bottomTrailingRadius: 6, topTrailingRadius: 6))
    }
}

/// The right page: the day's diary on ruled paper, and the day's words as small stamps.
private struct RightDiaryPage<Foot: View>: View {
    let day: BookDay
    let onWrite: (Date) -> Void
    let onOpen: (Sticker) -> Void
    let foot: Foot
    @Environment(DiaryStore.self) private var diary

    var body: some View {
        let text = diary.text(for: day.day)
        let pending = diary.draft(for: day.day)
        PaperPage(side: .right) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L("日記"))
                        .scaledFont(size: 13, weight: .bold)
                        .foregroundStyle(Color(hex: 0x33291F, opacity: 0.6))
                    Spacer()
                    Button { onWrite(day.day) } label: {
                        Label(text.isEmpty ? L("書く") : L("書き直す"), systemImage: "pencil.line")
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundStyle(Theme.primaryInk)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(.white.opacity(0.8), in: Capsule())
                            .overlay(Capsule().stroke(Theme.primary.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }
                PageScroll {
                    Group {
                        if text.isEmpty {
                            Button { onWrite(day.day) } label: {
                                Text(pending ?? L("この日のことを、学んでいる言葉で書いてみよう"))
                                    .font(AppFont.hand(19))
                                    .foregroundStyle(Color(hex: 0x33291F, opacity: pending == nil ? 0.4 : 0.8))
                                    .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
                                    .multilineTextAlignment(.leading)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(text)
                                .font(AppFont.hand(20))
                                .foregroundStyle(Color(hex: 0x33291F))
                                .lineSpacing(9)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                    .background(alignment: .top) { RuledPaper().frame(minHeight: 320).opacity(0.9) }
                }
                if !day.items.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(day.items) { s in
                                Button { onOpen(s) } label: {
                                    Text(s.word?.headword ?? "")
                                        .scaledFont(size: 14, weight: .semibold)
                                        .foregroundStyle(Color(hex: 0x33291F))
                                        .padding(.horizontal, 10)
                                        .frame(minHeight: 32)
                                        .background(Color(hex: 0xF3E6C8), in: .rect(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: 0xC9A15A).opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
                foot
            }
        }
        .task(id: DiaryStore.key(day.day)) { await diary.loadMonth(of: day.day) }
    }
}

extension BookDay {
    /// The days of one month that have photos or a diary entry (plus today, in this month).
    static func days(in month: Date, stickers: [Sticker], diaryDays: [String]) -> [BookDay] {
        let cal = Calendar.current
        let inMonth = stickers.filter { cal.isDate($0.takenAt, equalTo: month, toGranularity: .month) }
        var byDay = Dictionary(grouping: inMonth) { cal.startOfDay(for: $0.takenAt) }
        for key in diaryDays {
            if let d = DiaryStore.date(from: key), cal.isDate(d, equalTo: month, toGranularity: .month), byDay[d] == nil {
                byDay[d] = []
            }
        }
        let today = cal.startOfDay(for: Date())
        if cal.isDate(today, equalTo: month, toGranularity: .month), byDay[today] == nil { byDay[today] = [] }
        return byDay.keys.sorted().map { d in
            BookDay(day: d, items: (byDay[d] ?? []).sorted { $0.takenAt < $1.takenAt })
        }
    }
}

/// A past month from the shelf, opened full screen at its first day.
struct MonthBookSheet: View {
    let month: Date
    let onOpen: (Sticker) -> Void
    @Environment(DexStore.self) private var dex
    @Environment(DiaryStore.self) private var diary
    @Environment(\.dismiss) private var dismiss
    @State private var writingDay: WritingDay?

    var body: some View {
        let days = BookDay.days(in: month, stickers: dex.albumStickers, diaryDays: diary.dayKeys)
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(String(Calendar.current.component(.year, from: month)))
                        .scaledFont(size: 12, weight: .semibold).foregroundStyle(Color(hex: 0x33291F, opacity: 0.55))
                    Text(L("\(JPDate.month(month))のアルバム"))
                        .scaledFont(size: 24, weight: .heavy).foregroundStyle(Color(hex: 0x33291F))
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color(hex: 0x33291F))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.7), in: Circle())
                }
                .accessibilityLabel(L("閉じる"))
            }
            .padding(.horizontal, 20)
            if days.isEmpty {
                Text(L("この月の本はまだ白紙です。"))
                    .font(AppFont.hand(20)).foregroundStyle(Color(hex: 0x33291F, opacity: 0.6))
                    .frame(maxHeight: .infinity)
            } else {
                MonthBookView(days: days, startAtEnd: false, onOpen: onOpen) { writingDay = WritingDay(date: $0) }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .padding(.top, 12)
        .background(HomeBackground().ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .task { await diary.loadMonth(of: month) }
        .sheet(item: $writingDay) { d in
            DiaryComposer(day: d.date).presentationDetents([.large])
        }
    }
}

/// A page's own vertical scroll that takes a vertical swipe only when what it holds is taller than the page
/// (R6-09). The book sits inside the home screen's scroll; an inner scroll that always took the swipe left
/// the home screen barely moving under a finger on the album. Horizontal swipes still turn the pages.
struct PageScroll<Content: View>: View {
    private let content: Content
    @State private var contentHeight: CGFloat = 0
    @State private var boxHeight: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { boxHeight = $0 }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollDisabled(contentHeight <= boxHeight + 1)
    }
}
