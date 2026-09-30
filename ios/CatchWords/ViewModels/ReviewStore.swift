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

    private let client = SupabaseClient.shared

    /// quiz-choices.ts fallback pool (4 so one collision still leaves 3).
    static let fallback: [QuizChoice] = [
        QuizChoice(headword: "蘋果", zhuyin: "ㄆㄧㄥˊ ㄍㄨㄛˇ"),
        QuizChoice(headword: "公車", zhuyin: "ㄍㄨㄥ ㄔㄜ"),
        QuizChoice(headword: "雨傘", zhuyin: "ㄩˇ ㄙㄢˇ"),
        QuizChoice(headword: "便當", zhuyin: "ㄅㄧㄢˋ ㄉㄤ"),
    ]

    var current: ReviewCard? { index < queue.count ? queue[index] : nil }
    var isFinished: Bool { hasLoaded && index >= queue.count }

    func load(dex: DexStore, limit: Int) async {
        guard client.session != nil else { return }
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
            loadError = (error as? LocalizedError)?.errorDescription ?? "復習を読み込めませんでした。"
        }
        await historyTask
    }

    private func loadHistory() async {
        guard let data = try? await client.rest("GET", "review_history?select=reviewed_at&order=reviewed_at.desc&limit=3000"),
              let rows = try? SupabaseDate.decoder.decode([ReviewHistoryRow].self, from: data) else { return }
        let days = Set(rows.map { SRS.taipeiDay($0.reviewedAt) })
        streak = SRS.streak(days: days)
        let today = SRS.taipeiDay(Date())
        doneToday = rows.filter { SRS.taipeiDay($0.reviewedAt) == today }.count
    }

    /// Distractors from the learner's own dex first (same category preferred), then the fallback pool.
    func choices(for card: ReviewCard, dex: DexStore) -> [QuizChoice] {
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

    /// gradeReview: correct=5 (−1 if slow >8s), wrong=1.
    func grade(_ card: ReviewCard, correct: Bool, responseMs: Int, dex: DexStore) async {
        var score = correct ? 5 : 1
        if correct && responseMs > 8000 { score -= 1 }
        if correct { correctCount += 1 }
        let r = card.review
        let elapsed = r.lastReviewedAt.map { Date().timeIntervalSince($0) / 86_400 }
        let next = SRS.next(.init(ease: r.ease, intervalDays: r.intervalDays, repetitions: r.repetitions ?? 0), score: score, elapsedDays: elapsed)
        let now = Date()
        let due = now.addingTimeInterval(Double(next.intervalDays) * 86_400)
        guard let rid = r.id else { return }
        _ = try? await client.rest("PATCH", "reviews?id=eq.\(rid)", body: [
            "ease": next.ease,
            "interval_days": next.intervalDays,
            "repetitions": next.repetitions,
            "last_score": score,
            "last_reviewed_at": SupabaseDate.string(now),
            "due_at": SupabaseDate.string(due),
        ])
        if let uid = client.userId {
            _ = try? await client.rest("POST", "review_history", body: [
                "user_id": uid,
                "review_id": rid,
                "sticker_id": r.stickerId,
                "score": score,
                "correct": correct,
                "blur_seen": false,
                "response_ms": responseMs,
                "interval_days_after": next.intervalDays,
                "ease_after": next.ease,
                "repetitions_after": next.repetitions,
            ])
        }
        doneToday += 1
        if streak == 0 || !Calendar.current.isDateInToday(now) { streak = max(streak, 1) }
        await dex.reloadReviews()
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
