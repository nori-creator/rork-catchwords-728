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
    /// The first App Store version is free only: no "Upgrade to Pro", no purchase / restore buttons
    /// (the products are not set up in App Store Connect and the server does not check Apple purchases
    /// yet). Flip together with `catchLimitEnabled` when Pro launches; the StoreKit code stays as is.
    static let paywallEnabled = false
    /// The web server verifies App Store purchases and writes `profiles.plan` for them (needed for the
    /// server-decided Pro features such as 「作り直す」). Not built yet: see docs/self-managing-ios.md §7.
    /// Until then the paywall does not promise those features.
    static let serverVerifiesAppStore = false
    static let productIDs = ["catchwords.pro.yearly", "catchwords.pro.monthly"]

    var products: [Product] = []
    var isStorePro: Bool = false
    var isServerPro: Bool = false
    var usedToday: Int = 0
    var isPurchasing: Bool = false
    var message: String?

    /// Pro for what the APP gates on the device (catch limit, paywall): an active App Store subscription is
    /// trusted locally, so a paying user is never locked out while the server does not know the purchase yet.
    var isPro: Bool { isStorePro || isServerPro }
    /// Pro for features the SERVER decides (`isProUser`: `profiles.plan == "pro"` or admin), e.g. section
    /// 「作り直す」. The server does not verify App Store purchases yet (only web Stripe writes
    /// `profiles.plan`), so a StoreKit-only Pro does NOT count here — offering those buttons would only fail.
    var serverGrantsPro: Bool { isServerPro }
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
        if Self.paywallEnabled { await loadProducts() }
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
        guard let uid = SupabaseClient.shared.userId else { isServerPro = false; return }
        guard let data = try? await SupabaseClient.shared.rest("GET", "profiles?id=eq.\(uid)&select=plan"),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        let plan = (rows.first?["plan"] as? String) ?? "free"
        isServerPro = plan == "pro" || plan == "premium"
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }
        do {
            // The account's id travels with the purchase (`appAccountToken`): Apple puts it in the signed
            // transaction and in App Store Server Notifications, so the server can tell whose Pro it is
            // without trusting anything the app says. Supabase user ids are UUIDs.
            var options: Set<Product.PurchaseOption> = []
            if let uid = SupabaseClient.shared.userId, let token = UUID(uuidString: uid) {
                options.insert(.appAccountToken(token))
            }
            let result = try await product.purchase(options: options)
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let t):
                    await t.finish()
                    await refreshEntitlements()
                    Haptics.success()
                case .unverified:
                    message = L("購入を確認できませんでした。しばらくしてから「購入を復元」をお試しください。")
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

    /// Signing out / account deleted: the next account starts from its own plan, never the previous one's
    /// web Pro (StoreKit entitlements belong to the Apple ID and are read again).
    func reset() {
        isServerPro = false
        message = nil
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
