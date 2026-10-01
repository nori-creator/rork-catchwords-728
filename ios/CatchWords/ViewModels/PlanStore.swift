import SwiftUI
import StoreKit

/// Freemium: free users get 3 catches per day (Tokyo-day boundary like the server's `startOfTokyoDay`).
/// Pro = StoreKit subscription OR `profiles.plan == "pro"` (so web Stripe subscribers stay Pro on iPhone).
@Observable
final class PlanStore {
    static let freeCatchesPerDay = 3
    /// PRODUCT.md: "Initial public testing is a free beta. Do not prematurely hard-code a restrictive
    /// daily Catch limit without observing behavior." Off until real usage decides Free/Pro.
    static let catchLimitEnabled = false
    static let productIDs = ["catchwords.pro.yearly", "catchwords.pro.monthly"]

    var products: [Product] = []
    var isStorePro: Bool = false
    var isServerPro: Bool = false
    var usedToday: Int = 0
    var isPurchasing: Bool = false
    var message: String?

    var isPro: Bool { isStorePro || isServerPro }
    var remainingToday: Int { max(0, Self.freeCatchesPerDay - usedToday) }
    var canCatch: Bool { !Self.catchLimitEnabled || isPro || remainingToday > 0 }

    private var updatesTask: Task<Void, Never>?

    init() {
        loadUsage()
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let t) = update { await t.finish() }
                await self?.refreshEntitlements()
            }
        }
    }

    func bootstrap() async {
        loadUsage()
        await refreshEntitlements()
        await loadProducts()
        await refreshServerPlan()
    }

    /// True while the App Store prices are being fetched; false with no products = they could not be read.
    var isLoadingProducts: Bool = false

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        let loaded = (try? await Product.products(for: Self.productIDs)) ?? []
        products = loaded.sorted { ($0.subscription?.subscriptionPeriod.unit == .year ? 0 : 1) < ($1.subscription?.subscriptionPeriod.unit == .year ? 0 : 1) }
    }

    func refreshEntitlements() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Self.productIDs.contains(t.productID), t.revocationDate == nil { pro = true }
        }
        isStorePro = pro
    }

    func refreshServerPlan() async {
        guard let uid = SupabaseClient.shared.userId,
              let data = try? await SupabaseClient.shared.rest("GET", "profiles?id=eq.\(uid)&select=plan"),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        let plan = (rows.first?["plan"] as? String) ?? "free"
        isServerPro = plan == "pro" || plan == "premium"
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let t) = verification {
                    await t.finish()
                    await refreshEntitlements()
                    Haptics.success()
                }
            case .pending:
                message = L("購入の承認待ちです。")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = L("購入を完了できませんでした。")
        }
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        try? await AppStore.sync()
        await refreshEntitlements()
        await refreshServerPlan()
        message = isPro ? L("Proを復元しました。") : L("復元できる購入が見つかりませんでした。")
    }

    func recordCatch() {
        loadUsage()
        usedToday += 1
        UserDefaults.standard.set(usedToday, forKey: "plan.used")
        UserDefaults.standard.set(Self.dayKey(), forKey: "plan.day")
    }

    private func loadUsage() {
        let day = UserDefaults.standard.string(forKey: "plan.day")
        usedToday = day == Self.dayKey() ? UserDefaults.standard.integer(forKey: "plan.used") : 0
    }

    /// The app's "today" is one calendar everywhere: Taiwan midnight, like the web (`SRS.taipeiDay`).
    private static func dayKey() -> String { SRS.taipeiDay(Date()) }
}
