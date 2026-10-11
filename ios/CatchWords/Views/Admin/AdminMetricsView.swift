import SwiftUI

/// 設定 › 開発者 › KPIダッシュボード (web `/admin/metrics`, `getAdminDashboard`): the funnel from sign-up to the second day,
/// and each of the last 14 days with data.
struct AdminMetricsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var answer: AdminAnalytics.Answer?

    var body: some View {
        List {
            AdminLoadable(answer: answer, retry: { Task { await load() } }) { d in
                content(d)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L("KPIダッシュボード"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button(L("閉じる")) { dismiss() } }
        }
        .refreshable { await load() }
        .task { if answer == nil { await load() } }
    }

    private func load() async {
        answer = await AdminAnalytics.dashboard()
    }

    @ViewBuilder
    private func content(_ d: JSONValue) -> some View {
        let f = d["funnel"] ?? .null
        let total = max(1, f.count("users_total"))
        Section {
            funnelRow(L("登録"), f.count("users_total"), of: total)
            funnelRow(L("オンボ完了"), f.count("users_onboarded"), of: total)
            funnelRow(L("初スキャン"), f.count("users_first_scan"), of: total)
            funnelRow(L("初キャッチ"), f.count("users_first_catch"), of: total)
            AdminRow(label: L("D1継続"), value: AdminFormat.percent(f.num("d1_retention_pct")))
        } header: {
            Text(L("ファネル(累計)"))
        } footer: {
            Text(L("目標(β): 初キャッチ到達 ≥80% / D1 ≥40%"))
        }
        let days = d.list("days")
        Section(L("日次(直近14日)")) {
            if days.isEmpty {
                Text(L("まだデータがありません")).scaledFont(size: 14).foregroundStyle(Theme.muted)
            } else {
                let ordered = days.reversed().map { $0 }
                AdminBarChart(title: L("アクティブ"), bars: ordered.map { bar($0, "active_users") })
                AdminBarChart(title: L("キャッチ"), bars: ordered.map { bar($0, "catches") }, color: Theme.ok)
                AdminBarChart(title: L("スキャン"), bars: ordered.map { bar($0, "scans") }, color: Theme.gold)
                Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 6) {
                    GridRow {
                        Text(L("日付")).gridColumnAlignment(.leading)
                        Text(L("アクティブ"))
                        Text(L("スキャン"))
                        Text(L("タップ"))
                        Text(L("キャッチ"))
                        Text(L("復習添削"))
                    }
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundStyle(Theme.muted)
                    ForEach(Array(days.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            Text(AdminFormat.day(row.text("day") ?? ""))
                            Text(AdminFormat.int(row.count("active_users")))
                            Text(AdminFormat.int(row.count("scans")))
                            Text(AdminFormat.int(row.count("taps")))
                            Text(AdminFormat.int(row.count("catches")))
                            Text(AdminFormat.int(row.count("reviews")))
                        }
                        .scaledFont(size: 12, monospacedDigit: true)
                    }
                }
            }
        }
    }

    private func bar(_ row: JSONValue, _ key: String) -> AdminBar {
        AdminBar(label: AdminFormat.day(row.text("day") ?? ""), value: row.num(key) ?? 0)
    }

    private func funnelRow(_ title: String, _ n: Int, of total: Int) -> some View {
        AdminRow(label: title, value: "\(AdminFormat.int(n)) · \(AdminFormat.percent(Double(n) * 100 / Double(total)))")
    }
}

/// 設定 › 開発者 › ベータの指標 (web `/admin/beta`, `getBetaMetrics`): the four waits that matter (p50 / p90 / p99), how
/// often the first candidate is right, retention by sign-up day, weekly use, and the estimated AI and voice cost.
struct AdminBetaView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var answer: AdminAnalytics.Answer?
    /// 直近7日 / 30日 (web `BETA_WINDOWS`).
    @State private var window = 7

    var body: some View {
        List {
            Section {
                Text(L("登録前のチュートリアルは、日ごとの段の数だけを数えます（写真・語・メール・IP は集めません）。人数・費用は匿名の口座と管理者を除いた数です。"))
                    .scaledFont(size: 12).foregroundStyle(Theme.muted)
                Picker(L("期間"), selection: $window) {
                    ForEach([7, 30], id: \.self) { n in Text(L("\(n)日")).tag(n) }
                }
                .pickerStyle(.segmented)
            }
            AdminLoadable(answer: answer, retry: { Task { await load() } }) { d in
                content(d)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L("ベータの指標"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button(L("閉じる")) { dismiss() } }
        }
        .refreshable { await load() }
        .task { if answer == nil { await load() } }
    }

    private func load() async {
        answer = await AdminAnalytics.beta()
    }

    @ViewBuilder
    private func content(_ d: JSONValue) -> some View {
        let w = String(window)
        if d["truncated"]?.bool == true {
            Section {
                Text(L("行が多すぎて一部を読み切れていません（数は少なめに出ています）。"))
                    .scaledFont(size: 12).foregroundStyle(Theme.destructive)
            }
        }
        Section {
            ForEach(Self.latencyEvents, id: \.0) { key, title in
                let stat = d["latency"]?[key]?[w] ?? .null
                AdminRow(label: title,
                         value: "\(AdminFormat.ms(stat.num("p50"))) / \(AdminFormat.ms(stat.num("p90"))) / \(AdminFormat.ms(stat.num("p99"))) · n=\(stat.count("n"))")
            }
        } header: {
            Text(L("待ち時間（p50 / p90 / p99）"))
        } footer: {
            Text(L("登録した人の実機の計測。平均ではなく順位で見ます。n が少ない間は p99 は最大値とほぼ同じです。"))
        }
        let acc = d["candidateAccuracy"]?[w] ?? .null
        Section(L("候補の当たり方（写真の候補）")) {
            AdminRow(label: "Top-1", value: AdminFormat.percent(acc.num("top1Pct")))
            AdminRow(label: "Top-3", value: AdminFormat.percent(acc.num("top3Pct")))
            AdminRow(label: L("母語で調べ直した"), value: AdminFormat.percent(acc.num("nativeSearchPct")))
            AdminRow(label: L("選んだ回"), value: AdminFormat.int(acc.count("n")))
        }
        signupSection(d.list("signup"), window: w)
        retentionSection(d["retention"] ?? .null)
        northStarSection(d["northStar"] ?? .null)
        engagementSection(d.list("engagement"))
        costSection(d["cost"] ?? .null)
    }

    private static var latencyEvents: [(String, String)] {
        [("candidates_shown", L("撮影 → 候補が並ぶ")), ("meaning_shown", L("候補を選ぶ → 意味が出る")),
         ("first_audio_played", L("発音を頼む → 最初の音")), ("catch_saved", L("図鑑に追加 → 保存完了"))]
    }

    private func signupSection(_ rows: [JSONValue], window w: String) -> some View {
        let first = max(1, rows.first?["users"]?.object[w]?.int ?? 1)
        return Section(L("登録 → 最初のキャッチ → 最初の復習")) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                let n = r["users"]?.object[w]?.int ?? 0
                AdminRow(label: Self.stageLabel(r.text("stage")),
                         value: "\(AdminFormat.int(n)) · \(AdminFormat.percent(Double(n) * 100 / Double(first)))")
            }
        }
    }

    private static func stageLabel(_ key: String?) -> String {
        switch key {
        case "signup": L("登録")
        case "first_catch": L("最初のキャッチ")
        case "first_review": L("最初の復習")
        default: key ?? "—"
        }
    }

    private func retentionSection(_ r: JSONValue) -> some View {
        let exact = r["exact"] ?? .null
        let after = r["onOrAfter"] ?? .null
        return Section {
            ForEach([("d1", "D1"), ("d7", "D7"), ("d30", "D30")], id: \.0) { key, title in
                let e = exact[key] ?? .null
                let a = after[key] ?? .null
                AdminRow(label: title,
                         value: L("\(AdminFormat.percent(e.num("pct")))（\(e.count("eligible"))人中） · 以降 \(AdminFormat.percent(a.num("pct")))"))
            }
        } header: {
            Text(L("継続（登録日ごと）"))
        } footer: {
            Text(L("D1/D7/D30 = ちょうどその日に使った人の割合。「以降」は、その日以降のどこかで戻った割合。"))
        }
    }

    private func northStarSection(_ n: JSONValue) -> some View {
        let weeks = n.list("weeks")
        return Section(L("North-star: 覚えている語 / 週")) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, wk in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(AdminFormat.day(wk.text("from") ?? "")) – \(AdminFormat.day(wk.text("to") ?? ""))")
                        .scaledFont(size: 12, weight: .semibold, monospacedDigit: true)
                    Text(L("使った人 \(wk.count("activeUsers")) · 覚えている語 \(wk.count("retainedWords")) · 1人あたり \(AdminFormat.number(wk.num("perActiveUser"))) · AI \(AdminFormat.usd(wk.num("aiUsdPerActiveUser"), digits: 3))/人"))
                        .scaledFont(size: 12, monospacedDigit: true).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func engagementSection(_ weeks: [JSONValue]) -> some View {
        Section(L("使い方（週ごと）")) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, wk in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(AdminFormat.day(wk.text("from") ?? "")) – \(AdminFormat.day(wk.text("to") ?? ""))")
                        .scaledFont(size: 12, weight: .semibold, monospacedDigit: true)
                    Text(L("使った人 \(wk.count("activeUsers")) · 撮影 / 人 \(AdminFormat.number(wk.num("catchesPerActive"))) · 復習 / 人 \(AdminFormat.number(wk.num("reviewsPerActive"))) · 復習1回 \(AdminFormat.number(wk.num("medianReviewSessionMin")))分"))
                        .scaledFont(size: 12, monospacedDigit: true).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func costSection(_ c: JSONValue) -> some View {
        let days = c.list("days").map { AdminBar(label: AdminFormat.day($0.text("day") ?? ""), value: $0.num("usd") ?? 0) }
        return Section {
            AdminTiles {
                AdminTile(title: L("アクティブ1人あたり / 月（推定）"), value: AdminFormat.usd(c.num("perActiveUserMonthUsd"), digits: 3))
                AdminTile(title: L("30日の推定費用"), value: AdminFormat.usd(c.num("totalUsd")))
                AdminTile(title: L("30日のアクティブ人数"), value: AdminFormat.int(c.count("activeUsers30")))
                AdminTile(title: L("うち登録前（チュートリアル）"), value: AdminFormat.usd(c.num("guestUsd")))
            }
            .padding(.vertical, 4)
            if !days.isEmpty { AdminBarChart(title: L("日ごとの推定費用（米ドル）"), bars: days, color: Color(hex: 0x7C5CFA), showTotal: false) }
            ForEach(Array(c.list("byKind").enumerated()), id: \.offset) { _, k in
                AdminRow(label: k.text("key") ?? "—",
                         value: AdminFormat.usd(k.num("usd"), digits: 3) + " · " + L("\(k.count("calls"))回"))
            }
            AdminRow(label: L("除外した管理者の分"), value: AdminFormat.usd(c.num("excludedUsd")))
        } header: {
            Text(L("AI・音声の費用（推定）"))
        } footer: {
            Text(L("推定です。呼び出し回数 × 仮の単価。正確な額は各サービスの請求で確かめてください。管理者の分は除いています。"))
        }
    }
}
