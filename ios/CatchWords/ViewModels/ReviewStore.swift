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
    /// Every review_history row (overall retention line + streak).
    var allHistory: [ReviewHistoryRow] = []

    private let client = SupabaseClient.shared

    /// quiz-choices.ts fallback pool (4 so one collision still leaves 3).
    static let fallback: [QuizChoice] = [
        QuizChoice(headword: "蘋果",  // l10n-ignore (target word)
                   zhuyin: "ㄆㄧㄥˊ ㄍㄨㄛˇ"),
        QuizChoice(headword: "公車",  // l10n-ignore (target word)
                   zhuyin: "ㄍㄨㄥ ㄔㄜ"),
        QuizChoice(headword: "雨傘",  // l10n-ignore (target word)
                   zhuyin: "ㄩˇ ㄙㄢˇ"),
        QuizChoice(headword: "便當",  // l10n-ignore (target word)
                   zhuyin: "ㄅㄧㄢˋ ㄉㄤ"),
    ]

    var current: ReviewCard? { index < queue.count ? queue[index] : nil }
    var isFinished: Bool { hasLoaded && index >= queue.count }

    func load(dex: DexStore, limit: Int) async {
        guard client.session != nil else { return }
        choiceCache = [:]
        isLoading = true
        defer { isLoading = false }
        async let historyTask = loadHistory()
        do {
            let now = SupabaseDate.string(Date())
            let enc = DexStore.enc(now)
            let data = try await client.rest(
                "GET",
                "reviews?select=id,sticker_id,ease,interval_days,repetitions,last_reviewed_at,due_at&due_at=lte.\(enc)&order=due_at.asc&limit=\(max(1, limit - doneToday))"
            )
            let rows = try SupabaseDate.decoder.decode([ReviewState].self, from: data)
            if dex.stickers.isEmpty { await dex.load() }
            queue = rows.compactMap { r in
                guard let s = dex.sticker(id: r.stickerId), s.word != nil else { return nil }
                return ReviewCard(review: r, sticker: s)
            }
            index = 0
            correctCount = 0
            loadError = nil
            hasLoaded = true
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? L("復習を読み込めませんでした。")
        }
        await historyTask
    }

    private func loadHistory() async {
        guard let data = try? await client.rest("GET", "review_history?select=sticker_id,reviewed_at,interval_days_after,ease_after&order=reviewed_at.desc&limit=5000"),
              let rows = try? SupabaseDate.decoder.decode([ReviewHistoryRow].self, from: data) else { return }
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
        for c in same + rest + Self.fallback where c.headword != correct.headword && !out.contains(c) {
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
        if correct { correctCount += 1 }
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
