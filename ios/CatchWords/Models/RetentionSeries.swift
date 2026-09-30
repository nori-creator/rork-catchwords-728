import Foundation

/// One day of the 「全体の記憶率（前後2週間）」 line. `value` is nil when no card existed yet.
nonisolated struct RetentionPoint: Identifiable, Sendable, Hashable {
    let dayOffset: Int
    let date: Date
    let value: Double?
    var id: Int { dayOffset }
}

/// Port of retention-series.ts: past days are rebuilt from review_history (the state that held on
/// that day), future days are projected from the latest state. Cards that didn't exist yet are skipped.
nonisolated enum RetentionSeries {
    struct Card: Sendable {
        let stickerId: String
        let takenAt: Date
        let ease: Double
        let intervalDays: Int
        let lastReviewedAt: Date?
    }

    private struct State { let anchor: Date?; let stability: Double }

    static func build(cards: [Card], history: [ReviewHistoryRow], now: Date = Date(), back: Int = 14, forward: Int = 14) -> (series: [RetentionPoint], today: Int?) {
        var byCard: [String: [ReviewHistoryRow]] = [:]
        for h in history {
            guard let id = h.stickerId else { continue }
            byCard[id, default: []].append(h)
        }
        for k in byCard.keys { byCard[k]?.sort { $0.reviewedAt < $1.reviewedAt } }

        func stateAt(_ card: Card, _ events: [ReviewHistoryRow], _ at: Date) -> State? {
            if at < card.takenAt { return nil }
            if let e = events.last(where: { $0.reviewedAt <= at }) {
                return State(anchor: e.reviewedAt, stability: MemoryMath.stability(intervalDays: e.intervalDaysAfter ?? 1, ease: e.easeAfter ?? 2.5))
            }
            if let last = card.lastReviewedAt, last <= at {
                return State(anchor: last, stability: MemoryMath.stability(intervalDays: card.intervalDays, ease: card.ease))
            }
            return State(anchor: card.takenAt, stability: MemoryMath.stability(intervalDays: 1, ease: 2.5))
        }

        func average(at: Date) -> (Double?, Int) {
            var sum = 0.0, n = 0
            for c in cards {
                guard let s = stateAt(c, byCard[c.stickerId] ?? [], at) else { continue }
                var r = 100.0
                if let a = s.anchor {
                    let dt = at.timeIntervalSince(a) / 86_400
                    if dt > 0 { r = max(0, min(100, 100 * exp(-dt / s.stability))) }
                }
                sum += r
                n += 1
            }
            return (n > 0 ? (sum / Double(n)).rounded() : nil, n)
        }

        var points: [(RetentionPoint, Int)] = []
        for d in -back...forward {
            let at = now.addingTimeInterval(Double(d) * 86_400)
            let (avg, n) = average(at: at)
            points.append((RetentionPoint(dayOffset: d, date: at, value: avg), n))
        }
        let trimmed = points.drop { $0.1 == 0 }.map(\.0)
        let today = average(at: now).0.map { Int($0) }
        return (Array(trimmed), today)
    }
}
