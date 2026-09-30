import SwiftUI
import Charts

/// ForgettingCurveChart.tsx: past curve (solid, resets at each review), "if not reviewed" (dashed orange),
/// review points (hollow blue), today's dot, and a "now is the time" callout.
struct ForgettingCurveSheet: View {
    @Environment(DexStore.self) private var dex
    let sticker: Sticker
    let store: ReviewStore
    let onReviewNow: () -> Void

    @State private var history: [ReviewHistoryRow] = []
    @Environment(\.dismiss) private var dismiss

    private struct Pt: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let series: String
    }

    private var review: ReviewState? { dex.reviews[sticker.id] }

    var body: some View {
        let pct = dex.memoryPercent(for: sticker) ?? 100
        let lv = MemoryBadge.level(pct)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(sticker.word?.headword ?? "").font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.foreground)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.muted)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("閉じる")
                }
                HStack(spacing: 12) {
                    HStack(spacing: 5) {
                        Circle().fill(Theme.memoryLevels[lv]).frame(width: 8, height: 8)
                        Text("\(MemoryBadge.labels[lv]) · \(pct)%").font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Theme.memoryLevels[lv].mix(with: Theme.foreground, by: 0.3))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.memoryLevels[lv].opacity(0.14), in: Capsule())
                    Text("復習 **\(history.count)** 回").font(.system(size: 15)).foregroundStyle(Theme.muted)
                }
                Text("縦軸＝いま思い出せる確率（写真の右上の%と同じ）").font(.system(size: 13)).foregroundStyle(Theme.muted)
                HStack(spacing: 14) {
                    legend(color: Theme.ok, dashed: false, text: "これまで")
                    legend(color: Color(hex: 0xF59E0B), dashed: true, text: "復習しなかったら")
                    HStack(spacing: 5) {
                        Circle().stroke(Theme.primary, lineWidth: 2).frame(width: 10, height: 10)
                        Text("復習した日")
                    }
                }
                .font(.system(size: 13)).foregroundStyle(Theme.muted)

                chart.frame(height: 260)

                callout(pct: pct)
            }
            .padding(22)
        }
        .task { history = await store.history(stickerId: sticker.id) }
    }

    private func legend(color: Color, dashed: Bool, text: String) -> some View {
        HStack(spacing: 5) {
            Path { p in p.move(to: CGPoint(x: 0, y: 1.5)); p.addLine(to: CGPoint(x: 22, y: 1.5)) }
                .stroke(color, style: StrokeStyle(lineWidth: 3, dash: dashed ? [4, 3] : []))
                .frame(width: 22, height: 3)
            Text(text)
        }
    }

    private var curveData: (past: [Pt], future: [Pt], reviews: [Pt], today: Pt) {
        let now = Date()
        let origin = sticker.takenAt
        var past: [Pt] = []
        var marks: [Pt] = []
        var segStart = origin
        var ease = 2.5
        var interval = 0
        var segIndex = 0
        func sample(from a: Date, to b: Date, seg: Int) {
            let span = b.timeIntervalSince(a)
            let steps = max(2, Int(span / 86_400 * 2))
            for i in 0...steps {
                let t = a.addingTimeInterval(span * Double(i) / Double(steps))
                past.append(Pt(date: t, value: Double(MemoryMath.percent(intervalDays: interval, ease: ease, last: a, now: t)), series: "past\(seg)"))
            }
        }
        for h in history where h.reviewedAt <= now {
            sample(from: segStart, to: h.reviewedAt, seg: segIndex)
            segIndex += 1
            marks.append(Pt(date: h.reviewedAt, value: 100, series: "mark"))
            segStart = h.reviewedAt
            ease = h.easeAfter ?? ease
            interval = h.intervalDaysAfter ?? interval
        }
        if let r = review { ease = r.ease; interval = r.intervalDays; segStart = r.lastReviewedAt ?? segStart }
        sample(from: segStart, to: now, seg: segIndex)
        let todayVal = Double(MemoryMath.percent(intervalDays: interval, ease: ease, last: segStart, now: now))
        let horizon = max(7.0, now.timeIntervalSince(origin) / 86_400)
        var future: [Pt] = []
        for i in 0...24 {
            let t = now.addingTimeInterval(horizon * 86_400 * Double(i) / 24)
            future.append(Pt(date: t, value: Double(MemoryMath.percent(intervalDays: interval, ease: ease, last: segStart, now: t)), series: "future"))
        }
        return (past, future, marks, Pt(date: now, value: todayVal, series: "today"))
    }

    private var chart: some View {
        let d = curveData
        return Chart {
            ForEach(d.past) { p in
                AreaMark(x: .value("日", p.date), y: .value("%", p.value), series: .value("s", p.series))
                    .foregroundStyle(LinearGradient(colors: [Theme.primary.opacity(0.1), Theme.primary.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("日", p.date), y: .value("%", p.value), series: .value("s", p.series))
                    .foregroundStyle(Theme.ok)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            ForEach(d.future) { p in
                LineMark(x: .value("日", p.date), y: .value("%", p.value), series: .value("s", "future"))
                    .foregroundStyle(LinearGradient(colors: [Theme.ok, Color(hex: 0xF59E0B), Color(hex: 0xEA580C)], startPoint: .leading, endPoint: .trailing))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 5]))
            }
            ForEach(d.reviews) { p in
                PointMark(x: .value("日", p.date), y: .value("%", p.value))
                    .symbol { Circle().stroke(Theme.primary, lineWidth: 2.5).background(Circle().fill(.white)).frame(width: 13, height: 13) }
            }
            PointMark(x: .value("日", d.today.date), y: .value("%", d.today.value))
                .symbol { Circle().fill(Theme.memoryLevels[MemoryBadge.level(Int(d.today.value))]).overlay(Circle().stroke(.white, lineWidth: 2.5)).frame(width: 18, height: 18) }
                .annotation(position: .topTrailing, spacing: 2) {
                    Text("今日 \(Int(d.today.value))%").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.foreground)
                }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { v in
                AxisGridLine().foregroundStyle(Theme.border)
                AxisValueLabel { Text("\(v.as(Int.self) ?? 0)%").font(.system(size: 12)).foregroundStyle(Theme.muted) }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { v in
                AxisValueLabel {
                    if let date = v.as(Date.self) {
                        Text(Calendar.current.isDateInToday(date) ? "今日" : JPDate.slash(date)).font(.system(size: 12))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func callout(pct: Int) -> some View {
        let r = review
        let interval = r?.intervalDays ?? 0
        let ease = r?.ease ?? 2.5
        let last = r?.lastReviewedAt ?? sticker.takenAt
        // Day when retention falls under 70% (うろ覚え).
        let stability = max(0.5, Double(max(1, interval)) * max(1, ease) / (2.5 * log(1 / 0.9)))
        let dropDate = last.addingTimeInterval(stability * log(100.0 / 70.0) * 86_400)
        let daysLeft = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: dropDate)).day ?? 0)
        let isTime = pct < 95
        VStack(alignment: .leading, spacing: 10) {
            Text(isTime ? "今が復習どき" : "まだしっかり覚えています").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.foreground)
            if pct >= 70 {
                Text("復習しないと \(JPDate.slash(dropDate))（\(daysLeft)日後）に「うろ覚え」になります")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.foreground)
            }
            Text("いま思い出すと、次に忘れるまでの期間が伸びます。").font(.system(size: 14)).foregroundStyle(Theme.muted)
            if isTime {
                Button {
                    dismiss()
                    onReviewNow()
                } label: {
                    Text("いま復習する").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 26).frame(minHeight: 50)
                        .background(Theme.primary, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: isTime ? 0xFFEBDD : 0xE6F4EA), in: .rect(cornerRadius: 24))
    }
}
