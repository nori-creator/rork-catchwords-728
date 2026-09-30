import SwiftUI
import Charts

/// review.tsx MemoryOverviewPanel + MiniRetentionGraph: every reviewed word from weakest to
/// strongest (tap → forgetting curve), then 「全体の記憶率（前後2週間）」.
struct MemoryOverviewPanel: View {
    @Environment(DexStore.self) private var dex
    let store: ReviewStore
    let onOpenWord: (Sticker) -> Void

    private var rows: [(Sticker, Int)] {
        dex.stickers.compactMap { s in dex.memoryPercent(for: s).map { (s, $0) } }
            .sorted { $0.1 == $1.1 ? ($0.0.word?.headword ?? "") < ($1.0.word?.headword ?? "") : $0.1 < $1.1 }
    }

    var body: some View {
        let list = rows
        VStack(alignment: .leading, spacing: 0) {
            if !list.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(list, id: \.0.id) { s, pct in row(s, pct) }
                    }
                    .padding(.vertical, 6)
                }
                .frame(height: min(CGFloat(list.count) * 50 + 12, 330))
                .scrollIndicators(.visible)

                Text("タップで単語ごとの忘却曲線と「いつ忘れるか」の予測が見られます")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    .padding(.top, 8)
            }
            Divider().overlay(Theme.border).padding(.vertical, 12)
            Text("全体の記憶率（前後2週間）")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
            RetentionMiniChart(data: store.retentionSeries(dex: dex))
                .frame(height: 150)
                .padding(.top, 6)
        }
        .padding(14)
        .background(.white, in: .rect(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private func row(_ s: Sticker, _ pct: Int) -> some View {
        let lv = MemoryBadge.level(pct)
        let c = Theme.memoryLevels[lv]
        let ink = c.mix(with: Theme.foreground, by: 0.35)
        return Button { Haptics.selection(); onOpenWord(s) } label: {
            HStack(spacing: 10) {
                Text(s.word?.headword ?? "")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.foreground)
                    .lineLimit(1).truncationMode(.tail)
                    .frame(width: 58, alignment: .leading)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.secondary)
                        Capsule().fill(c).frame(width: g.size.width * CGFloat(pct) / 100)
                    }
                }
                .frame(height: 8)
                Text("\(pct)%").font(.system(size: 12, weight: .semibold)).monospacedDigit().foregroundStyle(ink)
                    .frame(width: 36, alignment: .trailing)
                Text(MemoryBadge.labels[lv])
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(width: 60).padding(.vertical, 4)
                    .background(c.opacity(0.14), in: Capsule())
            }
            .padding(.horizontal, 6)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .accessibilityLabel("\(s.word?.headword ?? "") \(MemoryBadge.labels[lv]) \(pct)%")
    }
}

/// Solid past line (blue→green), today's dot with 「今日 n%」, dashed green projection.
struct RetentionMiniChart: View {
    let data: (series: [RetentionPoint], today: Int?)

    var body: some View {
        let past = data.series.filter { $0.dayOffset <= 0 && $0.value != nil }
        let future = data.series.filter { $0.dayOffset >= 0 && $0.value != nil }
        let first = data.series.first?.date ?? Date()
        let last = data.series.last?.date ?? Date()
        if data.series.isEmpty {
            Text("復習を始めると、ここに記憶率の推移が出ます")
                .font(.system(size: 13)).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                ForEach(past) { p in
                    LineMark(x: .value("日", p.date), y: .value("%", p.value ?? 0), series: .value("s", "past"))
                        .foregroundStyle(LinearGradient(colors: [Theme.primary, Theme.memoryLevels[4]], startPoint: .leading, endPoint: .trailing))
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                ForEach(future) { p in
                    LineMark(x: .value("日", p.date), y: .value("%", p.value ?? 0), series: .value("s", "future"))
                        .foregroundStyle(Theme.memoryLevels[3])
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 5]))
                }
                if let t = data.today {
                    PointMark(x: .value("日", Date()), y: .value("%", Double(t)))
                        .symbol { Circle().fill(Theme.primary).overlay(Circle().stroke(.white, lineWidth: 2)).frame(width: 13, height: 13) }
                        .annotation(position: .top, spacing: 4) {
                            Text("今日 \(t)%").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.foreground)
                        }
                }
            }
            .chartYScale(domain: 0...108)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { v in
                    AxisGridLine().foregroundStyle(Theme.border)
                    AxisValueLabel { Text("\(v.as(Int.self) ?? 0)%").font(.system(size: 11)).foregroundStyle(Theme.muted) }
                }
            }
            .chartXAxis {
                AxisMarks(values: [first, Date(), last]) { v in
                    AxisValueLabel(anchor: .top) {
                        if let d = v.as(Date.self) {
                            Text(abs(d.timeIntervalSinceNow) < 3600 ? "今日" : JPDate.slash(d))
                                .font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
        }
    }
}
