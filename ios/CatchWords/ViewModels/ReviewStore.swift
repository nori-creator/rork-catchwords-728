import SwiftUI

/// One due card of today's review.
struct ReviewCard: Identifiable, Hashable {
    let review: ReviewState
    let sticker: Sticker
    var id: String { review.id ?? review.stickerId }
}

/// A 4-choice option (headword + reading).
struct QuizChoice: Identifiable, Hashable {
    let headword: String
    let zhuyin: String?
    var id: String { headword }
}

/// Today's review queue — reads `reviews` (due_at <= now), grades with srs.ts, writes `reviews` + `review_history`.
@Observable
final class ReviewStore {
    var queue: [ReviewCard] = []
    var index: Int = 0
    var isLoading: Bool = false
    var hasLoaded: Bool = false
    var loadError: String?
    /// Set when a grade could not be saved (the card stays on screen to answer again).
    var gradeError: String?
    var streak: Int = 0
    var doneToday: Int = 0
    var correctCount: Int = 0
    /// Cards answered wrong in this round (offered again at the end, without recording).
    var missed: [ReviewCard] = []
    /// True while going over the missed cards again: nothing is graded or written.
    var isRetry: Bool = false
    /// More cards are due than the daily limit let into this round.
    var moreAvailable: Bool = false
    /// Today's limit is used up while cards are still due (web review-batch.ts "capped").
    var capped: Bool = false
    /// Due cards left after this batch (web `dueRemaining`).
    var dueRemaining: Int = 0
    /// Every review_history row (overall retention line + streak).
    var allHistory: [ReviewHistoryRow] = []

    private let client = SupabaseClient.shared

    /// The padding after the learner's own dex: everyday words of the learning language from the bundled pool
    /// (Models/QuizPool.swift), the same category key first, then the same room. No exam levels (owner 2026-10-03:
    /// per-word levels are gone on iOS). It replaces quiz-choices.ts's four fixed words; the pool is far larger,
    /// so a collision with the correct word still leaves 3.
    /// A Mandarin fallback in an English quiz was a reported bug (R3 「4択が学習言語英語なのに台湾華語の単語が混ざってる」):
    /// the pool keeps one list per learning language.
    static func fallback(for target: String, categoryKey: String? = nil) -> [QuizChoice] {
        QuizPool.ranked(for: target, categoryKey: categoryKey)
            .map { QuizChoice(headword: $0.headword, zhuyin: $0.reading) }
    }

    /// The learning language the queue was built for (R5: a switched language must not keep the old cards).
    private(set) var loadedTarget: String = ""

    /// Forget the queue (the learning language changed).
    func reset() {
        queue = []
        index = 0
        hasLoaded = false
        choiceCache = [:]
        loadedTarget = ""
        doneToday = 0
        streak = 0
        allHistory = []
        missed = []
        isRetry = false
        moreAvailable = false
    }

    /// Go over this round's wrong answers once more. Practice only: the schedule was already updated
    /// when they were first answered, so a second answer today must not move it again.
    func startRetry() {
        guard !missed.isEmpty else { return }
        choiceCache = [:]
        queue = missed.shuffled()
        missed = []
        index = 0
        correctCount = 0
        isRetry = true
    }

    /// Keep going past the daily limit: the next batch of due cards.
    func loadMore(dex: DexStore) async {
        await load(dex: dex, limit: doneToday + 20)
    }

    /// 「いま復習する」 on a word's curve: that word becomes the next card — moved up when it is still
    /// waiting in today's queue, added when it is not there (not due yet, or already answered).
    func bringForward(_ sticker: Sticker, review: ReviewState?, currentAnswered: Bool) {
        let at = min(queue.count, currentAnswered ? index + 1 : index)
        if let i = queue.firstIndex(where: { $0.sticker.id == sticker.id }), i >= index {
            if i == index && !currentAnswered { return }
            if i > at { queue.move(fromOffsets: IndexSet(integer: i), toOffset: at) }
            return
        }
        // Without a review row there is nothing to grade (the answer would not be saved).
        guard sticker.word != nil, let r = review, r.id != nil else { return }
        queue.insert(ReviewCard(review: r, sticker: sticker), at: at)
    }

    var current: ReviewCard? { index < queue.count ? queue[index] : nil }

    func load(dex: DexStore, limit: Int) async {
        // Local guest (no account): nothing to review, but the screen must leave its spinner.
        guard client.session != nil else {
            queue = []
            moreAvailable = false
            loadError = nil
            hasLoaded = true
            return
        }
        choiceCache = [:]
        isLoading = true
        defer { isLoading = false }
        async let historyTask = loadHistory(dex: dex)
        do {
            let now = SupabaseDate.string(Date())
            let enc = DexStore.enc(now)
            // Paged: the server answers at most 1000 rows per request (a big account's due count was cut).
            let rows = try await client.restAll(
                "reviews?select=id,sticker_id,ease,interval_days,repetitions,last_reviewed_at,due_at&due_at=lte.\(enc)&order=due_at.asc,id.asc",
                as: ReviewState.self, decoder: SupabaseDate.decoder
            )
            if !dex.hasLoaded { await dex.load() }
            // Only this learning language's cards (the dex is already filtered), and the daily limit is
            // counted after that filter — not before (R1 「復習の記憶の状態が他の学習言語と混ざってる」).
            let cards = rows.compactMap { r -> ReviewCard? in
                guard let s = dex.sticker(id: r.stickerId), s.word != nil else { return nil }
                return ReviewCard(review: r, sticker: s)
            }
            await historyTask  // doneToday is now this language's count
            // The daily limit reached: nothing more today (web getDueReviews returns [] then), but say so.
            let room = max(0, limit - doneToday)
            queue = Array(cards.prefix(room))
            capped = room == 0 && !cards.isEmpty
            dueRemaining = cards.count - queue.count
            moreAvailable = dueRemaining > 0
            missed = []
            isRetry = false
            loadedTarget = NativeAPI.targetLanguage
            index = 0
            correctCount = 0
            loadError = nil
            hasLoaded = true
        } catch is CancellationError {
            await historyTask
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? L("復習を読み込めませんでした。")
            await historyTask
        }
    }

    private func loadHistory(dex: DexStore) async {
        // Paged (1000 rows per request at most): the streak and today's count need every row.
        guard var rows = try? await client.restAll(
            "review_history?select=sticker_id,reviewed_at,interval_days_after,ease_after&order=reviewed_at.desc,id.desc",
            as: ReviewHistoryRow.self, decoder: SupabaseDate.decoder, maxPages: 50
        ) else { return }
        // Streak, today's count and the retention line: this learning language's words only.
        if !dex.hasLoaded { await dex.load() }
        let mine = Set(dex.stickers.map(\.id))
        if dex.hasLoaded { rows = rows.filter { $0.stickerId.map(mine.contains) ?? false } }
        allHistory = rows
        let days = Set(rows.map { SRS.taipeiDay($0.reviewedAt) })
        streak = SRS.streak(days: days)
        let today = SRS.taipeiDay(Date())
        doneToday = rows.filter { SRS.taipeiDay($0.reviewedAt) == today }.count
    }

    /// Distractors from the learner's own dex first (same category preferred), then the bundled pool (same category, then same room).
    /// Choices are drawn once per card. Without this the four buttons reshuffled every time the
    /// screen redrew — including right after a tap, so the answer you pressed jumped to another slot.
    @ObservationIgnored private var choiceCache: [String: [QuizChoice]] = [:]

    func choices(for card: ReviewCard, dex: DexStore) -> [QuizChoice] {
        if let cached = choiceCache[card.sticker.id] { return cached }
        let made = makeChoices(for: card, dex: dex)
        choiceCache[card.sticker.id] = made
        return made
    }

    private func makeChoices(for card: ReviewCard, dex: DexStore) -> [QuizChoice] {
        let correct = QuizChoice(headword: card.sticker.word?.headword ?? "", zhuyin: card.sticker.word?.readingZhuyin)
        let others = dex.stickers.compactMap { s -> (QuizChoice, Bool)? in
            guard let w = s.word, w.headword != correct.headword else { return nil }
            return (QuizChoice(headword: w.headword, zhuyin: w.readingZhuyin), s.categoryKey == card.sticker.categoryKey)
        }
        let same = others.filter(\.1).map(\.0).shuffled()
        let rest = others.filter { !$0.1 }.map(\.0).shuffled()
        var out: [QuizChoice] = []
        let pool = Self.fallback(for: NativeAPI.targetLanguage, categoryKey: card.sticker.categoryKey)
        // Compared by headword: the same word from the dex and from the pool may carry different readings.
        for c in same + rest + pool where c.headword != correct.headword && !out.contains(where: { $0.headword == c.headword }) {
            out.append(c)
            if out.count == 3 { break }
        }
        return ([correct] + out).shuffled()
    }

    /// Graded by the web's own `gradeReview` (reviews.functions.ts): the same scoring (correct=5,
    /// −1 when slow, wrong=1), the same interval engine (SM-2 with the Jev guardrails) and the same
    /// history rows as the web — so a word comes due on the same day on the iPhone and on the web.
    /// If the server cannot be reached, nothing is written locally (a half-graded card would drift):
    /// returns false, `gradeError` says why, and the card is not counted as done.
    @discardableResult
    func grade(_ card: ReviewCard, correct: Bool, responseMs: Int, dex: DexStore) async -> Bool {
        gradeError = nil
        if isRetry {
            if correct { correctCount += 1 } else if !missed.contains(where: { $0.id == card.id }) { missed.append(card) }
            return true
        }
        let r = card.review
        let now = Date()
        guard let rid = r.id else { return true }
        struct Graded: Decodable {
            let score: Int?
            let intervalDays: Double?
            enum CodingKeys: String, CodingKey { case score, intervalDays = "interval_days" }
        }
        let graded: Graded
        do {
            graded = try await NativeAPI.call("gradeReview", [
                "review_id": rid,
                "correct": correct,
                "blur_seen": false,
                "response_ms": max(0, responseMs),
            ], as: Graded.self, timeout: 20)
        } catch {
            let reason = (error as? LocalizedError)?.errorDescription ?? ""
            gradeError = reason.isEmpty ? L("採点を保存できませんでした。もう一度答えてください。") : L("採点を保存できませんでした。もう一度答えてください。\n\(reason)")
            return false
        }
        if correct { correctCount += 1 } else if !missed.contains(where: { $0.id == card.id }) { missed.append(card) }
        let intervalAfter = graded.intervalDays.map { Int($0.rounded()) } ?? r.intervalDays
        doneToday += 1
        if let row = ReviewHistoryRow(stickerId: r.stickerId, reviewedAt: now, intervalDaysAfter: intervalAfter, easeAfter: r.ease) {
            allHistory.insert(row, at: 0)
        }
        if streak == 0 || !Calendar.current.isDateInToday(now) { streak = max(streak, 1) }
        await dex.reloadReviews()
        return true
    }

    /// 「全体の記憶率（前後2週間）」 for every sticker that has a review row.
    func retentionSeries(dex: DexStore) -> (series: [RetentionPoint], today: Int?) {
        let cards: [RetentionSeries.Card] = dex.stickers.compactMap { s in
            guard let r = dex.reviews[s.id] else { return nil }
            return .init(stickerId: s.id, takenAt: s.takenAt, ease: r.ease, intervalDays: r.intervalDays, lastReviewedAt: r.lastReviewedAt)
        }
        return RetentionSeries.build(cards: cards, history: allHistory)
    }

    func advance() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { index += 1 }
    }

    func history(stickerId: String) async -> [ReviewHistoryRow] {
        guard let data = try? await client.rest(
            "GET",
            "review_history?sticker_id=eq.\(stickerId)&select=reviewed_at,score,interval_days_after,ease_after&order=reviewed_at.asc&limit=200"
        ) else { return [] }
        return (try? SupabaseDate.decoder.decode([ReviewHistoryRow].self, from: data)) ?? []
    }
}
