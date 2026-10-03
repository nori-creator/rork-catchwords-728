import SwiftUI

/// review.tsx (4-choice mode): header + progress + memory bar, then one quiz card at a time.
struct ReviewView: View {
    @Environment(DexStore.self) private var dex
    @Environment(ProfileStore.self) private var profile
    @Environment(AppRouter.self) private var router
    @State private var store = ReviewStore()
    @State private var legendOpen: Bool = false
    @State private var curveSticker: Sticker?
    /// Verdict for the current card (nil until a choice is picked).
    @State private var answer: Bool?
    @State private var practiceIndex: Int = 0
    /// How far the answer sheet has been dragged sideways (swipe left = next card, like the web's SwipeCard).
    @State private var swipeX: CGFloat = 0
    /// The answer sheet's real height (it grows with the explanation): the question scrolls clear of it.
    @State private var panelHeight: CGFloat = 420
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppBackground()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        MemoryBar(counts: dex.memoryLevelCounts, isOpen: $legendOpen)
                        if legendOpen {
                            MemoryOverviewPanel(store: store) { s in
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { curveSticker = s }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    // Room under the last choice for the whole sheet, however tall its explanation is.
                    .padding(.bottom, answer == nil ? 120 : panelHeight + 16)
                }
                .refreshable { await store.load(dex: dex, limit: profile.effectiveReviewLimit) }
                .statusBarScrim()
                // A long question (English meanings especially) sat under the sheet that slides up: once
                // answered, bring the question to the top so all of it stays readable above the sheet.
                .onChange(of: answer != nil) { _, answered in
                    guard answered else { return }
                    withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.9)) {
                        proxy.scrollTo(QuizCard.questionID, anchor: .top)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let answer, let card = router.tour.isReview ? practiceCards[safe: practiceIndex] : store.current {
                AnswerPanel(sticker: card.sticker, correct: answer) {
                    if !router.tour.isReview { router.detailSticker = card.sticker }
                } onNext: {
                    goNext()
                }
                .offset(x: swipeX)
                .rotationEffect(.degrees(Double(swipeX) / 40), anchor: .bottom)
                .gesture(
                    DragGesture(minimumDistance: 24)
                        .onChanged { v in
                            // Only sideways drags move the sheet; the explanation inside still scrolls up and down.
                            guard abs(v.translation.width) > abs(v.translation.height) else { return }
                            swipeX = min(40, v.translation.width)
                        }
                        .onEnded { v in
                            if v.translation.width < -90 || v.predictedEndTranslation.width < -220 {
                                Haptics.selection()
                                withAnimation(.easeIn(duration: 0.18)) { swipeX = -520 }
                                Task {
                                    try? await Task.sleep(for: .milliseconds(170))
                                    goNext()
                                    swipeX = 0
                                }
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { swipeX = 0 }
                            }
                        }
                )
                .accessibilityAction(named: L("次へ")) { goNext() }
                .tourAnchor(.reviewNext, if: router.tour == .reviewNext)
                .padding(.bottom, 66)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { panelHeight = $0 }
                .background(alignment: .bottom) { Theme.card.frame(height: 80) }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(card.id)
            }
        }
        .overlay {
            if let s = curveSticker {
                ZStack {
                    Color.black.opacity(0.32).ignoresSafeArea()
                        .onTapGesture { closeCurve() }
                    ForgettingCurveSheet(sticker: s, store: store, onReviewNow: {
                        guard !router.tour.isReview else { return }
                        let answered = answer != nil
                        store.bringForward(s, review: dex.reviews[s.id], currentAnswered: answered)
                        if answered { goNext() }
                    }, onClose: { closeCurve() })
                    .frame(maxHeight: 640)
                    .background(Theme.card, in: .rect(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 30, y: 12)
                    .padding(.horizontal, 16)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
                }
                .zIndex(2)
            }
        }
        .task {
            if store.hasLoaded, store.loadedTarget != NativeAPI.targetLanguage { store.reset() }
            if !store.hasLoaded { await store.load(dex: dex, limit: profile.effectiveReviewLimit) }
        }
        // R5 「学習言語台湾華語なのに英語の4択が表示されてる」: a switched learning language starts a fresh queue.
        .onChange(of: profile.targetLanguage) { _, _ in
            store.reset()
            // The dex is re-read for the new language first, so no old-language card slips in.
            Task {
                await dex.load()
                await store.load(dex: dex, limit: profile.effectiveReviewLimit)
            }
        }
        .reviewLiveActivity(store: store, dex: dex, answered: answer != nil, enabled: !router.tour.isReview)
    }

    /// FirstCatchPractice: 撮った1枚（と図鑑にあればもう1枚）で、4択を記録せずに試す。
    private var practiceCards: [ReviewCard] {
        let own = router.tourStickerId.flatMap { dex.sticker(id: $0) }
        let other = dex.stickers.first { $0.id != own?.id && $0.word != nil }
        return [own, other].compactMap { s in
            guard let s, s.word != nil else { return nil }
            return ReviewCard(review: ReviewState(stickerId: s.id, ease: 2.5, intervalDays: 0, repetitions: 0), sticker: s)
        }
    }

    private func goNext() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { answer = nil }
        if router.tour.isReview { nextPractice() } else { store.advance() }
    }

    private func nextPractice() {
        if practiceIndex + 1 < practiceCards.count {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { practiceIndex += 1 }
            router.advanceTour(from: .reviewNext, to: .reviewPick)
        } else {
            practiceIndex = 0
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { router.tour = .complete }
        }
    }

    private func closeCurve() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { curveSticker = nil }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("きょうの復習")).font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.foreground)
                    Text(store.streak > 0 ? L("復習が\(store.streak)日続いています") : L("今日から復習を始めましょう"))
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
                Spacer()
                if !store.queue.isEmpty {
                    Text("\(min(store.index + 1, store.queue.count)) / \(store.queue.count)")
                        .font(.system(size: 15)).monospacedDigit().foregroundStyle(Theme.muted)
                }
            }
            GeometryReader { geo in
                let p = store.queue.isEmpty ? 0 : CGFloat(store.index) / CGFloat(store.queue.count)
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.secondary)
                    Capsule().fill(Theme.primary).frame(width: max(40, geo.size.width * p))
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: store.index)
                }
            }
            .frame(height: 6)
        }
    }

    @ViewBuilder
    private var content: some View {
        if router.tour.isReview, let card = practiceCards[safe: practiceIndex] {
            QuizCard(card: card, choices: store.choices(for: card, dex: dex), percent: nil, isAnswered: answer != nil) { correct, _ in
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { answer = correct }
                router.advanceTour(from: .reviewPick, to: .reviewNext)
            } onBadge: {}
            .tourAnchor(.quiz)
            .id("practice-\(card.id)")
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        } else if let err = store.loadError, store.queue.isEmpty {
            VStack(spacing: 12) {
                Label(err, systemImage: "wifi.exclamationmark").foregroundStyle(Theme.foreground)
                Button(L("もう一度読み込む")) { Task { await store.load(dex: dex, limit: profile.effectiveReviewLimit) } }
                    .foregroundStyle(Theme.primary)
            }
            .frame(maxWidth: .infinity).padding(.top, 60)
        } else if !store.hasLoaded {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
        } else if let card = store.current {
            QuizCard(card: card, choices: store.choices(for: card, dex: dex), percent: dex.memoryPercent(for: card.sticker), isAnswered: answer != nil) { correct, ms in
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { answer = correct }
                Task {
                    // Not saved (offline, server down): the card comes back to be answered again.
                    if !(await store.grade(card, correct: correct, responseMs: ms, dex: dex)) {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { answer = nil }
                        Haptics.warning()
                    }
                }
            } onBadge: {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { curveSticker = card.sticker }
            }
            .id(card.id)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            .overlay(alignment: .bottom) {
                if let err = store.gradeError {
                    Label(err, systemImage: "wifi.exclamationmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Theme.destructive.opacity(0.92), in: .rect(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.gradeError)
        } else {
            ReviewDone(total: store.queue.count, correct: store.correctCount, doneToday: store.doneToday,
                       missed: store.missed.count, isRetry: store.isRetry, canLoadMore: store.moreAvailable && !store.isRetry,
                       capped: store.capped || (store.moreAvailable && store.doneToday >= profile.effectiveReviewLimit),
                       dueRemaining: store.dueRemaining,
                       onSettings: { router.tab = .settings },
                       onRetry: {
                           withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { store.startRetry() }
                       },
                       onMore: {
                           Task { await store.loadMore(dex: dex) }
                       },
                       onCamera: { router.tab = .camera })
            .id("done-\(store.isRetry)-\(store.queue.count)")
        }
    }
}

/// Stacked memory bar (6 levels) + expandable legend.
struct MemoryBar: View {
    let counts: [Int]
    @Binding var isOpen: Bool

    var body: some View {
        let total = max(1, counts.reduce(0, +))
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 10) {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            ForEach(0..<6, id: \.self) { i in
                                if counts[i] > 0 {
                                    Rectangle().fill(Theme.memoryLevels[i])
                                        .frame(width: geo.size.width * CGFloat(counts[i]) / CGFloat(total))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.secondary)
                        .clipShape(Capsule())
                    }
                    .frame(height: 12)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .frame(minHeight: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("記憶の内訳"))

            if isOpen {
                FlowRow {
                    ForEach(0..<6, id: \.self) { i in
                        if counts[i] > 0 {
                            HStack(spacing: 5) {
                                Circle().fill(Theme.memoryLevels[i]).frame(width: 9, height: 9)
                                Text(MemoryBadge.labels[i]).foregroundStyle(Theme.memoryLevels[i].mix(with: Theme.foreground, by: 0.35))
                                Text("\(counts[i])").fontWeight(.bold).foregroundStyle(Theme.memoryLevels[i].mix(with: Theme.foreground, by: 0.35))
                            }
                            .font(.system(size: 14))
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Simple wrapping row.
struct FlowRow: Layout {
    var spacing: CGFloat = 14
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + 8; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: maxW == .infinity ? x : maxW, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + 8; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

/// 4択クイズ: photo → 「meaning」はどれ？ → 4 headwords with zhuyin + pronounce buttons.
struct QuizCard: View {
    @Environment(DexStore.self) private var dex
    let card: ReviewCard
    let choices: [QuizChoice]
    let percent: Int?
    let isAnswered: Bool
    let onAnswer: (Bool, Int) -> Void
    let onBadge: () -> Void

    @State private var picked: String?
    @State private var started: Date = Date()
    @State private var shake: CGFloat = 0

    /// The question line, scrolled to the top after an answer (ReviewView) so the sheet never hides it.
    static let questionID = "quiz.question"

    private var correctHead: String { card.sticker.word?.headword ?? "" }
    /// The meaning as it is now (read in the reader's language after the card was made).
    private var liveMeaning: String { (dex.sticker(id: card.sticker.id) ?? card.sticker).word?.meaningJa ?? "" }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Theme.primary, in: Circle())
                    Text(L("4択クイズ")).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.foreground)
                }
                .padding(.leading, 4).padding(.trailing, 12).padding(.vertical, 4)
                .background(Theme.secondary, in: Capsule())
                Spacer()
                if let percent {
                    Button(action: onBadge) {
                        let lv = MemoryBadge.level(percent)
                        HStack(spacing: 5) {
                            Circle().fill(Theme.memoryLevels[lv]).frame(width: 7, height: 7)
                            Text("\(percent)%").font(.system(size: 14, weight: .semibold)).monospacedDigit()
                                .foregroundStyle(Theme.memoryLevels[lv].mix(with: Theme.foreground, by: 0.35))
                        }
                        .padding(.horizontal, 10).frame(minHeight: 30)
                        .background(Theme.memoryLevels[lv].opacity(0.14), in: Capsule())
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(PressableStyle(scale: 0.92))
                    .accessibilityLabel(L("忘却曲線を見る"))
                }
            }

            if !isAnswered {
                let path = card.sticker.heroPath
                Theme.secondary
                    .frame(height: 220)
                    .overlay {
                        StickerImage(path: path, url: dex.url(for: path, preferThumb: false), contentMode: .fit)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 22, style: .continuous))
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }

            Text(liveMeaning.isEmpty ? L("この写真の物はどれ？") : L("「\(liveMeaning)」はどれ？"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)   // every line of a long meaning, never "…"
                .id(Self.questionID)

            VStack(spacing: 10) {
                ForEach(choices) { c in choiceRow(c) }
            }
            .offset(x: shake)
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        .onAppear { started = Date() }
        // A grade that could not be saved hands the card back (isAnswered → false): answer it again.
        .onChange(of: isAnswered) { _, answered in
            if !answered {
                picked = nil
                started = Date()
            }
        }
    }

    private func choiceRow(_ c: QuizChoice) -> some View {
        let isCorrect = c.headword == correctHead
        let isPicked = picked == c.headword
        let revealed = picked != nil
        let stroke: Color = revealed && isCorrect ? Theme.ok : (isPicked ? Theme.destructive : Theme.primary.opacity(0.25))
        let fill: Color = revealed && isCorrect ? Theme.ok.opacity(0.08) : (isPicked ? Theme.destructive.opacity(0.07) : Color(light: 0xF7FAFF, dark: 0x132032))
        return ZStack {
            Button { answer(c) } label: {
                ZhuyinWordView(headword: c.headword, zhuyin: c.zhuyin, size: 34, weight: .bold)
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle(scale: 0.97))
            .disabled(revealed)
            .accessibilityIdentifier(isCorrect ? "quiz.choice.correct" : "quiz.choice")
            HStack {
                if revealed && (isCorrect || isPicked) {
                    Image(systemName: isCorrect ? "checkmark" : "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isCorrect ? Theme.ok : Theme.destructive)
                        .padding(.leading, 18)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                PronounceCircle(text: c.headword, size: 40).padding(.trailing, 10)
            }
        }
        .background(fill, in: .rect(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(stroke, lineWidth: revealed && (isCorrect || isPicked) ? 2 : 1.2))
        .animation(.easeOut(duration: 0.2), value: picked)
    }

    private func answer(_ c: QuizChoice) {
        guard picked == nil else { return }
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        let ok = c.headword == correctHead
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { picked = c.headword }
        if ok {
            Haptics.success()
            SoundService.shared.speak(correctHead)
        } else {
            Haptics.warning()
            Task {
                for x in [10.0, -8, 6, -3, 0] {
                    withAnimation(.spring(response: 0.08, dampingFraction: 0.4)) { shake = x }
                    try? await Task.sleep(for: .milliseconds(60))
                }
            }
        }
        onAnswer(ok, ms)
    }
}

/// The end of a round: the score counts up inside a ring that draws itself, then what to do next —
/// go over the missed words again (practice, not recorded), keep going past the daily limit, or catch more.
struct ReviewDone: View {
    let total: Int
    let correct: Int
    let doneToday: Int
    var missed: Int = 0
    var isRetry: Bool = false
    var canLoadMore: Bool = false
    var capped: Bool = false
    var dueRemaining: Int = 0
    var onSettings: () -> Void = {}
    var onRetry: () -> Void = {}
    var onMore: () -> Void = {}
    let onCamera: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownCorrect = 0
    @State private var ring: CGFloat = 0
    @State private var appeared = false

    private var rate: CGFloat { total == 0 ? 1 : CGFloat(correct) / CGFloat(total) }
    private var ringColor: Color { rate >= 0.8 ? Theme.ok : rate >= 0.5 ? Theme.gold : Theme.primary }

    var body: some View {
        VStack(spacing: 18) {
            if total == 0 {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(Theme.primary)
                    .symbolEffect(.bounce, value: appeared)
            } else {
                ZStack {
                    Circle().stroke(Theme.secondary, lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: ring)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(shownCorrect)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(shownCorrect)))
                            .foregroundStyle(Theme.foreground)
                        Text("/ \(total)")
                            .font(.system(size: 15, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 140, height: 140)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L("\(total)問中 \(correct)問 正解"))
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.foreground)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.system(size: 15)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                if missed > 0 {
                    Button(action: onRetry) {
                        Label(L("まちがえた\(missed)語をもう一度"), systemImage: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.primaryInk)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.primary.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    Text(L("練習なので、記憶の記録は変わりません。"))
                        .font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                if capped {
                    Button(action: onSettings) {
                        Label(L("設定で枚数を変える"), systemImage: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.primaryInk)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.primary.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
                if canLoadMore {
                    Button(action: onMore) {
                        Label(capped ? L("もっと復習する") : L("続ける"), systemImage: "plus.circle")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.primaryInk)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.card, in: Capsule())
                            .overlay(Capsule().stroke(Theme.primary.opacity(0.35), lineWidth: 1.2))
                    }
                    .buttonStyle(PressableStyle())
                }
                Button(action: onCamera) {
                    Label(L("単語を撮りに行く"), systemImage: "camera.fill")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Theme.primary, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 8)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
        .background(Theme.card, in: .rect(cornerRadius: 28, style: .continuous))
        .task { await play() }
    }

    private var title: String {
        if total == 0 { return capped ? L("今日の分は終わりです") : L("今日復習する単語はありません。") }
        if isRetry { return missed == 0 ? L("ぜんぶ覚え直せました") : L("あと\(missed)語、もう少し") }
        return L("\(total)問中 \(correct)問 正解")
    }

    /// web DoneState / EmptyState: more due → keep going; limit used up; or all done until tomorrow.
    private var subtitle: String {
        if total == 0 && !capped { return L("新しい単語をキャッチすると、10分後に最初の復習が出ます。") }
        if isRetry || total == 0 { return L("今日は\(doneToday)回復習しました。") }
        if capped { return L("今日の分は終わりです（\(doneToday)回復習しました）。") }
        if dueRemaining > 0 { return L("あと \(dueRemaining) 語、期限が来ています。続けられます。") }
        return L("また明日の復習で会いましょう。")
    }

    private func play() async {
        if reduceMotion || total == 0 {
            shownCorrect = correct
            ring = rate
            appeared = true
            return
        }
        withAnimation(.easeOut(duration: 0.9)) { ring = rate }
        // Count up one by one, faster for big rounds, a light tick each step.
        let steps = max(1, correct)
        let pause = max(25, min(90, 900 / steps))
        for n in stride(from: 0, through: correct, by: 1) {
            withAnimation(.snappy(duration: 0.2)) { shownCorrect = n }
            if n > 0 { Haptics.selection() }
            try? await Task.sleep(for: .milliseconds(pause))
        }
        if rate >= 0.8 { Haptics.success() }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { appeared = true }
    }
}
