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
    var streak: Int = 0
    var doneToday: Int = 0
    var correctCount: Int = 0
    /// Cards answered wrong in this round (offered again at the end, without recording).
    var missed: [ReviewCard] = []
    /// True while going over the missed cards again: nothing is graded or written.
    var isRetry: Bool = false
    /// More cards are due than the daily limit let into this round.
    var moreAvailable: Bool = false
    /// Every review_history row (overall retention line + streak).
    var allHistory: [ReviewHistoryRow] = []

    private let client = SupabaseClient.shared

    /// quiz-choices.ts quizFallbackHeadwords, per learning language (4 so one collision still leaves 3).
    /// A Mandarin fallback in an English quiz was a reported bug (R3 「4択が学習言語英語なのに台湾華語の単語が混ざってる」).
    static func fallback(for target: String) -> [QuizChoice] {
        switch target {
        case "en":
            return ["apple", "bus", "umbrella", "lunch box"].map { QuizChoice(headword: $0, zhuyin: nil) }  // l10n-ignore (target words)
        case "ja":
            return [("りんご", ""), ("バス", ""), ("傘", "かさ"), ("お弁当", "おべんとう")]  // l10n-ignore (target words)
                .map { QuizChoice(headword: $0.0, zhuyin: $0.1.isEmpty ? nil : $0.1) }
        default:
            return [QuizChoice(headword: "蘋果", zhuyin: "ㄆㄧㄥˊ ㄍㄨㄛˇ"),  // l10n-ignore (target word)
                    QuizChoice(headword: "公車", zhuyin: "ㄍㄨㄥ ㄔㄜ"),  // l10n-ignore (target word)
                    QuizChoice(headword: "雨傘", zhuyin: "ㄩˇ ㄙㄢˇ"),  // l10n-ignore (target word)
                    QuizChoice(headword: "便當", zhuyin: "ㄅㄧㄢˋ ㄉㄤ")]  // l10n-ignore (target word)
        }
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

    var current: ReviewCard? { index < queue.count ? queue[index] : nil }

    func load(dex: DexStore, limit: Int) async {
        guard client.session != nil else { return }
        choiceCache = [:]
        isLoading = true
        defer { isLoading = false }
        async let historyTask = loadHistory(dex: dex)
        do {
            let now = SupabaseDate.string(Date())
            let enc = DexStore.enc(now)
            let data = try await client.rest(
                "GET",
                "reviews?select=id,sticker_id,ease,interval_days,repetitions,last_reviewed_at,due_at&due_at=lte.\(enc)&order=due_at.asc&limit=5000"
            )
            let rows = try SupabaseDate.decoder.decode([ReviewState].self, from: data)
            if dex.stickers.isEmpty { await dex.load() }
            // Only this learning language's cards (the dex is already filtered), and the daily limit is
            // counted after that filter — not before (R1 「復習の記憶の状態が他の学習言語と混ざってる」).
            let cards = rows.compactMap { r -> ReviewCard? in
                guard let s = dex.sticker(id: r.stickerId), s.word != nil else { return nil }
                return ReviewCard(review: r, sticker: s)
            }
            await historyTask  // doneToday is now this language's count
            let room = max(1, limit - doneToday)
            queue = Array(cards.prefix(room))
            moreAvailable = cards.count > room
            missed = []
            isRetry = false
            loadedTarget = NativeAPI.targetLanguage
            index = 0
            correctCount = 0
            loadError = nil
            hasLoaded = true
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? L("復習を読み込めませんでした。")
            await historyTask
        }
    }

    private func loadHistory(dex: DexStore) async {
        guard let data = try? await client.rest("GET", "review_history?select=sticker_id,reviewed_at,interval_days_after,ease_after&order=reviewed_at.desc&limit=5000"),
              var rows = try? SupabaseDate.decoder.decode([ReviewHistoryRow].self, from: data) else { return }
        // Streak, today's count and the retention line: this learning language's words only.
        if dex.stickers.isEmpty { await dex.load() }
        let mine = Set(dex.stickers.map(\.id))
        if dex.hasLoaded { rows = rows.filter { $0.stickerId.map(mine.contains) ?? false } }
        allHistory = rows
        let days = Set(rows.map { SRS.taipeiDay($0.reviewedAt) })
        streak = SRS.streak(days: days)
        let today = SRS.taipeiDay(Date())
        doneToday = rows.filter { SRS.taipeiDay($0.reviewedAt) == today }.count
    }

    /// Distractors from the learner's own dex first (same category preferred), then the fallback pool.
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
        for c in same + rest + Self.fallback(for: NativeAPI.targetLanguage) where c.headword != correct.headword && !out.contains(c) {
            out.append(c)
            if out.count == 3 { break }
        }
        return ([correct] + out).shuffled()
    }

    /// Graded by the web's own `gradeReview` (reviews.functions.ts): the same scoring (correct=5,
    /// −1 when slow, wrong=1), the same interval engine (SM-2 with the Jev guardrails) and the same
    /// history rows as the web — so a word comes due on the same day on the iPhone and on the web.
    /// If the server cannot be reached, nothing is written locally (a half-graded card would drift).
    func grade(_ card: ReviewCard, correct: Bool, responseMs: Int, dex: DexStore) async {
        if correct { correctCount += 1 } else if !missed.contains(where: { $0.id == card.id }) { missed.append(card) }
        if isRetry { return }
        let r = card.review
        let now = Date()
        guard let rid = r.id else { return }
        struct Graded: Decodable {
            let score: Int?
            let intervalDays: Double?
            enum CodingKeys: String, CodingKey { case score, intervalDays = "interval_days" }
        }
        let graded = try? await NativeAPI.call("gradeReview", [
            "review_id": rid,
            "correct": correct,
            "blur_seen": false,
            "response_ms": max(0, responseMs),
        ], as: Graded.self, timeout: 20)
        let intervalAfter = graded?.intervalDays.map { Int($0.rounded()) } ?? r.intervalDays
        doneToday += 1
        if graded != nil,
           let row = ReviewHistoryRow(stickerId: r.stickerId, reviewedAt: now, intervalDaysAfter: intervalAfter, easeAfter: r.ease) {
            allHistory.insert(row, at: 0)
        }
        if streak == 0 || !Calendar.current.isDateInToday(now) { streak = max(streak, 1) }
        await dex.reloadReviews()
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
