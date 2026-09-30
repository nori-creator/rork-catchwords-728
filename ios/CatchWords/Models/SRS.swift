import Foundation

/// srs.ts ported 1:1 (SM-2 variant: 2nd interval 3 days, late-recall credit, ease floor 1.3, lapses keep ease).
nonisolated enum SRS {
    static let lapseScore = 3
    static let minEase = 1.3

    struct State: Sendable {
        var ease: Double
        var intervalDays: Int
        var repetitions: Int
    }

    static func next(_ prev: State, score: Int, elapsedDays: Double?) -> State {
        var s = prev
        if score < lapseScore {
            s.repetitions = 0
            s.intervalDays = 1
            return s
        }
        s.repetitions += 1
        if s.repetitions == 1 {
            s.intervalDays = 1
        } else if s.repetitions == 2 {
            s.intervalDays = 3
        } else {
            let late = max(0, (elapsedDays ?? 0) - Double(s.intervalDays))
            let credit: Double = score >= 5 ? 1 : (score == 4 ? 0.5 : 0)
            let base: Double = Double(s.intervalDays) + late * credit
            let scaled: Double = base * s.ease
            s.intervalDays = Int(scaled.rounded(.toNearestOrAwayFromZero))
        }
        let q = Double(5 - score)
        s.ease = max(minEase, s.ease + (0.1 - q * (0.08 + q * 0.02)))
        return s
    }

    /// Asia/Taipei calendar-day key (streak.ts rule: convert to local day first, then count).
    static func taipeiDay(_ d: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Taipei") ?? .current
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// countStreak: if today is empty, start from yesterday (don't zero out morning users).
    static func streak(days: Set<String>, now: Date = Date()) -> Int {
        guard !days.isEmpty else { return 0 }
        var cursor = now
        if !days.contains(taipeiDay(cursor)) { cursor = cursor.addingTimeInterval(-86_400) }
        var n = 0
        while days.contains(taipeiDay(cursor)) && n < 366 {
            n += 1
            cursor = cursor.addingTimeInterval(-86_400)
        }
        return n
    }
}

