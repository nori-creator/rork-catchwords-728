import SwiftUI
import Charts

// Building blocks of the developer screens (設定 › 開発者): number tiles, small bar charts, label–value rows, and the
// loading / failure states. Plain and dense — these screens are for reading numbers, not for show.

/// A number with its title and a small line under it (web `KpiTile`).
struct AdminTile: View {
    let title: String
    let value: String
    var sub: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).scaledFont(size: 12, weight: .semibold).foregroundStyle(Theme.muted).lineLimit(2)
            Text(value).scaledFont(size: 24, weight: .heavy, monospacedDigit: true).foregroundStyle(Theme.foreground)
                .lineLimit(1).minimumScaleFactor(0.6)
            if let sub {
                Text(sub).scaledFont(size: 11).foregroundStyle(Theme.muted).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.secondary.opacity(0.6), in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Tiles two to a row.
struct AdminTiles<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            content
        }
    }
}

/// One bar of a small chart.
struct AdminBar: Identifiable {
    let label: String
    let value: Double
    /// A second, stacked part (e.g. wrong answers on top of right ones).
    var extra: Double = 0
    var id: String { label }
}

/// A small bar chart with its title and total (web `ColumnChart`). Labels are thinned to a few ticks.
struct AdminBarChart: View {
    let title: String
    let bars: [AdminBar]
    var color: Color = Theme.primary
    var extraColor: Color = Theme.destructive.opacity(0.7)
    var height: CGFloat = 120
    /// The total under the title ("合計 12"); nil hides it.
    var showTotal: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).scaledFont(size: 13, weight: .semibold).foregroundStyle(Theme.foreground)
                Spacer()
                if showTotal {
                    let total = bars.reduce(0) { $0 + $1.value + $1.extra }
                    Text(L("合計 \(AdminFormat.number(total, digits: 0))"))
                        .scaledFont(size: 11, monospacedDigit: true).foregroundStyle(Theme.muted)
                }
            }
            Chart {
                ForEach(bars) { b in
                    BarMark(x: .value("x", b.label), y: .value("y", b.value))
                        .foregroundStyle(color)
                    if b.extra > 0 {
                        BarMark(x: .value("x", b.label), y: .value("y", b.extra))
                            .foregroundStyle(extraColor)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: Self.ticks(bars.map(\.label))) { _ in
                    AxisValueLabel().font(.system(size: 9))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel().font(.system(size: 9))
                }
            }
            .frame(height: height)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    /// About five evenly spread labels (web `evenTicks`).
    static func ticks(_ xs: [String], n: Int = 5) -> [String] {
        guard xs.count > n, n > 1 else { return xs }
        let step = Double(xs.count - 1) / Double(n - 1)
        return (0..<n).map { xs[min(xs.count - 1, Int((Double($0) * step).rounded()))] }
    }
}

/// A label and its value on one line.
struct AdminRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).scaledFont(size: 14).foregroundStyle(Theme.muted)
            Spacer(minLength: 8)
            Text(value).scaledFont(size: 14, weight: .semibold, monospacedDigit: true).foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Horizontal bars for a short ranked list (learning languages, plans, places…).
struct AdminRankList: View {
    let rows: [(String, Int)]

    var body: some View {
        let top = max(1, rows.map(\.1).max() ?? 1)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    Text(row.0).scaledFont(size: 13).foregroundStyle(Theme.foreground).lineLimit(1)
                        .frame(width: 110, alignment: .leading)
                    GeometryReader { g in
                        Capsule().fill(Theme.primary.opacity(0.75))
                            .frame(width: max(4, g.size.width * CGFloat(row.1) / CGFloat(top)))
                    }
                    .frame(height: 8)
                    Text(AdminFormat.int(row.1)).scaledFont(size: 12, monospacedDigit: true).foregroundStyle(Theme.muted)
                        .frame(minWidth: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Loading, a failure with 「もう一度」, or the content.
struct AdminLoadable<Content: View>: View {
    let answer: AdminAnalytics.Answer?
    let retry: () -> Void
    @ViewBuilder let content: (JSONValue) -> Content

    var body: some View {
        switch answer {
        case nil:
            HStack(spacing: 10) {
                ProgressView()
                Text(L("読み込み中")).scaledFont(size: 14).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        case .failure(let f)?:
            VStack(alignment: .leading, spacing: 10) {
                Label(AdminAnalytics.message(f), systemImage: "exclamationmark.triangle")
                    .scaledFont(size: 14).foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L("もう一度読み込む"), action: retry)
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(Theme.primaryInk)
                    .frame(minHeight: 44)
            }
        case .success(let v)?:
            content(v)
        }
    }
}
