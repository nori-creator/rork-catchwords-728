import SwiftUI
import StoreKit

/// Monthly vs yearly (yearly highlighted, shown per-month) per docs/monetization.md.
struct PaywallView: View {
    @Environment(PlanStore.self) private var plan
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID: String = PlanStore.productIDs[0]
    @State private var appeared: Bool = false
    @State private var float: Bool = false

    private let benefits: [(String, String, String)] = [
        ("infinity", "撮影・キャッチが無制限", "1日3回の上限がなくなります"),
        ("scissors", "被写体の切り抜きも無制限", "iPhoneの写真と同じ切り抜きで図鑑が美しく"),
        ("wand.and.stars", "解説の作り直し", "気になるカードをいつでも作り直せます"),
        ("heart.fill", "開発を応援", "新しい機能が毎月届きます"),
    ]

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 26) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.muted)
                                .frame(width: 44, height: 44)
                                .background(Theme.card, in: Circle())
                        }
                        .accessibilityLabel("閉じる")
                    }
                    ZStack {
                        Circle().fill(Theme.primary.opacity(0.25)).frame(width: 180).blur(radius: 40)
                        LogoMark(size: 104)
                            .offset(y: float ? -6 : 4)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Theme.gold)
                            .shadow(color: Theme.gold.opacity(0.7), radius: 10)
                            .offset(x: 48, y: -54 + (float ? -6 : 4))
                    }
                    .frame(height: 150)
                    VStack(spacing: 8) {
                        Text("街じゅうを、図鑑にしよう。")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Theme.foreground)
                        Text(plan.remainingToday == 0 ? "今日の無料キャッチ（3回）を使い切りました。" : "Proなら、見つけた瞬間に何度でも。")
                            .font(AppFont.hand(17))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: 12) {
                        ForEach(Array(benefits.enumerated()), id: \.offset) { idx, b in
                            HStack(spacing: 14) {
                                Image(systemName: b.0).font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Theme.primary)
                                    .frame(width: 40, height: 40)
                                    .background(Theme.accent, in: .rect(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.1).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.foreground)
                                    Text(b.2).font(.system(size: 12)).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                            }
                            .opacity(appeared ? 1 : 0)
                            .offset(x: appeared ? 0 : -20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1 + Double(idx) * 0.06), value: appeared)
                        }
                    }
                    plans
                    PrimaryButton(title: plan.products.isEmpty ? "読み込み中…" : "Proをはじめる", icon: "sparkles",
                                  isLoading: plan.isPurchasing, sheen: true) {
                        guard let product = plan.products.first(where: { $0.id == selectedID }) ?? plan.products.first else { return }
                        Task {
                            await plan.purchase(product)
                            if plan.isPro { dismiss() }
                        }
                    }
                    .disabled(plan.products.isEmpty)
                    if let msg = plan.message {
                        Text(msg).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                    HStack(spacing: 18) {
                        Button("購入を復元") { Task { await plan.restore(); if plan.isPro { dismiss() } } }
                        Link("利用規約", destination: URL(string: "https://catchwords.lovable.app/terms")!)
                        Link("プライバシー", destination: URL(string: "https://catchwords.lovable.app/privacy")!)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    Text("サブスクリプションは期間終了の24時間前までに解約しない限り自動更新されます。解約はApp Storeのアカウント設定からいつでも行えます。")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.muted.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
        }
        .task { await plan.loadProducts() }
        .onAppear {
            appeared = true
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { float = true }
        }
    }

    @ViewBuilder
    private var plans: some View {
        if plan.products.isEmpty {
            VStack(spacing: 6) {
                ProgressView().tint(Theme.muted)
                Text("年額 ¥7,800 / 月額 ¥980（予定）").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            .frame(minHeight: 80)
        } else {
            VStack(spacing: 10) {
                ForEach(plan.products, id: \.id) { product in
                    let isYearly = product.subscription?.subscriptionPeriod.unit == .year
                    let selected = selectedID == product.id
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy) { selectedID = product.id }
                    } label: {
                        HStack {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected ? Theme.primary : Theme.muted)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(isYearly ? "年額プラン" : "月額プラン").font(.system(size: 16, weight: .bold))
                                    if isYearly {
                                        Text("いちばん選ばれています")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Theme.gold, in: Capsule())
                                    }
                                }
                                if isYearly {
                                    Text("月あたり \((product.price / 12).formatted(product.priceFormatStyle))")
                                        .font(.system(size: 12)).foregroundStyle(Theme.muted)
                                }
                            }
                            .foregroundStyle(Theme.foreground)
                            Spacer()
                            Text(product.displayPrice).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.foreground)
                        }
                        .padding(16)
                        .background(Theme.card, in: .rect(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Theme.primary : Theme.border, lineWidth: selected ? 2 : 1))
                    }
                    .buttonStyle(PressableStyle(scale: 0.98))
                }
            }
        }
    }
}
