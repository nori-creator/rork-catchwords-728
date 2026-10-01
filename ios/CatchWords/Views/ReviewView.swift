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
    @State private var showWordbooks: Bool = false
    @State private var practiceIndex: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppBackground()
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
                .padding(.bottom, answer == nil ? 120 : 420)
            }
            .refreshable { await store.load(dex: dex, limit: profile.effectiveReviewLimit) }
        }
        .overlay(alignment: .bottom) {
            if let answer, let card = router.tour.isReview ? practiceCards[safe: practiceIndex] : store.current {
                AnswerPanel(sticker: card.sticker, correct: answer) {
                    if !router.tour.isReview { router.detailSticker = card.sticker }
                } onNext: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { self.answer = nil }
                    if router.tour.isReview { nextPractice() } else { store.advance() }
                }
                .tourAnchor(.reviewNext, if: router.tour == .reviewNext)
                .padding(.bottom, 66)
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
                        if let i = store.queue.firstIndex(where: { $0.sticker.id == s.id }), i > store.index, answer == nil {
                            store.queue.move(fromOffsets: IndexSet(integer: i), toOffset: store.index)
                        }
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
            if !store.hasLoaded { await store.load(dex: dex, limit: profile.effectiveReviewLimit) }
        }
        .fullScreenCover(isPresented: $showWordbooks) {
            WordbookView()
        }
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
            Button {
                Haptics.selection()
                showWordbooks = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "books.vertical")
                    Text(L("単語帳で復習する"))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.primaryInk)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Theme.primary.opacity(0.08), in: .rect(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressableStyle(scale: 0.98))
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
                Task { await store.grade(card, correct: correct, responseMs: ms, dex: dex) }
            } onBadge: {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { curveSticker = card.sticker }
            }
            .id(card.id)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        } else {
            ReviewDone(total: store.queue.count, correct: store.correctCount, doneToday: store.doneToday) {
                router.tab = .camera
            }
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

    private var correctHead: String { card.sticker.word?.headword ?? "" }

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
                let path = card.sticker.objectImageUrl ?? card.sticker.cutoutImageUrl
                Theme.secondary
                    .frame(height: 220)
                    .overlay {
                        StickerImage(path: path, url: dex.url(for: path, preferThumb: false), contentMode: .fit)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 22, style: .continuous))
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }

            Text(L("「\(card.sticker.word?.meaningJa ?? "")」はどれ？"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.center)

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
    }

    private func choiceRow(_ c: QuizChoice) -> some View {
        let isCorrect = c.headword == correctHead
        let isPicked = picked == c.headword
        let revealed = picked != nil
        let stroke: Color = revealed && isCorrect ? Theme.ok : (isPicked ? Theme.destructive : Theme.primary.opacity(0.25))
        let fill: Color = revealed && isCorrect ? Theme.ok.opacity(0.08) : (isPicked ? Theme.destructive.opacity(0.07) : Color(hex: 0xF7FAFF))
        return ZStack {
            Button { answer(c) } label: {
                ZhuyinWordView(headword: c.headword, zhuyin: c.zhuyin, size: 34, weight: .bold)
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle(scale: 0.97))
            .disabled(revealed)
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
            SoundService.shared.play(.snap, volume: 0.5)
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

struct ReviewDone: View {
    let total: Int
    let correct: Int
    let doneToday: Int
    let onCamera: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: total == 0 ? "checkmark.seal" : "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.primary)
                .symbolEffect(.bounce, value: total)
            Text(total == 0 ? L("今日の復習はおしまいです") : L("\(total)問中 \(correct)問 正解"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.foreground)
            Text(total == 0 ? L("新しい単語を撮ると、ここに出てきます。") : L("今日は\(doneToday)回復習しました。"))
                .font(.system(size: 15)).foregroundStyle(Theme.muted)
            Button(action: onCamera) {
                Label(L("単語を撮りに行く"), systemImage: "camera.fill")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 24).frame(minHeight: 50)
                    .background(Theme.primary, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Theme.card, in: .rect(cornerRadius: 28))
    }
}
