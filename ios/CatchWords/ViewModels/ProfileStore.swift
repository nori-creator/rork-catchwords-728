import SwiftUI

/// The shared `profiles` row (same columns the web settings screen edits).
@Observable
final class ProfileStore {
    var displayName: String = ""
    var avatarURL: String?
    var nativeLanguage: String = "ja"
    var targetLanguage: String = "zh-TW" {
        didSet { NativeAPI.targetLanguage = ["en", "ja"].contains(targetLanguage) ? targetLanguage : "zh-TW" }
    }
    var currentLevel: String = "TOCFL-1"
    var levelGoal: String = "TOCFL-2"
    /// 0 = 無制限 (review-batch.ts).
    var reviewDailyLimit: Int = 20
    /// 無制限 = every due card (1000 is the most one REST read returns).
    var effectiveReviewLimit: Int { reviewDailyLimit == 0 ? 1000 : reviewDailyLimit }
    var isSavingAvatar: Bool = false
    /// `profiles.onboarded` — true once the first-run setup has been finished (on any device).
    var onboarded: Bool = false
    /// When the account was made (`profiles.created_at`) — day 1 for the milestone albums.
    var createdAt: Date?
    var isLoaded: Bool = false
    /// The profile could not be read (offline / server down): nothing is known about onboarding, so
    /// the welcome screens are not shown again; `load()` runs again when the app becomes active.
    var loadFailed: Bool = false
    var message: String?

    private let client = SupabaseClient.shared

    static let levelOptions: [(value: String, label: String)] = (1...6).map { ("TOCFL-\($0)", "TOCFL Level \($0)") }
    static let cefrOptions: [(value: String, label: String)] = ["A1", "A2", "B1", "B2", "C1", "C2"].map { ($0, "CEFR \($0)") }
    // Language names in their own language (an autonym never changes with the display language).
    static let nativeOptions: [(value: String, label: String)] = [("ja", "日本語"), ("en", "English"), ("zh-TW", "繁體中文")]  // l10n-ignore (autonyms)
    static let targetOptions: [(value: String, label: String)] = [("zh-TW", "台灣華語"), ("en", "English"), ("ja", "日本語")]  // l10n-ignore (autonyms)
    /// level-scale.ts JLPT_SCALE: six steps like TOCFL and CEFR; step 6 is "beyond N1".
    static let jlptOptions: [(value: String, label: String)] = ["N5", "N4", "N3", "N2", "N1", "N1+"].map { ("JLPT-\($0)", "JLPT \($0)") }

    /// TOCFL for 台湾華語, CEFR for English, JLPT for Japanese (level-scale.ts).
    static func levels(for target: String) -> [(value: String, label: String)] {
        switch target {
        case "en": cefrOptions
        case "ja": jlptOptions
        default: levelOptions
        }
    }

    /// Re-maps a stored level onto the other scale by step (TOCFL-4 ⇄ B2 ⇄ JLPT-N2).
    static func remap(_ value: String, to target: String) -> String {
        let all = levels(for: target)
        if all.contains(where: { $0.value == value }) { return value }
        let step = [levelOptions, cefrOptions, jlptOptions].lazy.compactMap { list in list.firstIndex { $0.value == value } }.first ?? 0
        return all[min(step, all.count - 1)].value
    }

    func load() async {
        guard let uid = client.userId else { isLoaded = true; return }
        defer { isLoaded = true }
        let full = "display_name,avatar_url,native_language,ui_language,target_language,level_goal,current_level,review_daily_limit,onboarded,created_at"
        var data = try? await client.rest("GET", "profiles?id=eq.\(uid)&select=\(full)")
        if data == nil {
            data = try? await client.rest("GET", "profiles?id=eq.\(uid)&select=display_name,avatar_url,native_language,target_language,level_goal")
        }
        guard let data, let row = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]])?.first else {
            loadFailed = true
            return
        }
        loadFailed = false
        displayName = row["display_name"] as? String ?? ""
        avatarURL = row["avatar_url"] as? String
        nativeLanguage = row["native_language"] as? String ?? "ja"
        ReaderLanguage.native = (row["native_language"] as? String).map { L10n.normalize($0) }
        // The display language follows the account (set on the web or another device too).
        if let ui = row["ui_language"] as? String, !ui.isEmpty {
            L10n.set(ui)
            nativeLanguage = L10n.lang
        }
        targetLanguage = row["target_language"] as? String ?? "zh-TW"
        if let v = row["current_level"] as? String, !v.isEmpty { currentLevel = v }
        if let v = row["level_goal"] as? String, !v.isEmpty { levelGoal = v }
        if let v = row["review_daily_limit"] as? Int, v >= 0 { reviewDailyLimit = v }
        onboarded = row["onboarded"] as? Bool ?? false
        if let s = row["created_at"] as? String { createdAt = SupabaseDate.parse(s) }
    }

    /// Signing out: the next account starts from a blank profile (its own is read on sign-in). The
    /// learning language is kept: it is only this device's first guess until the profile arrives.
    func reset() {
        displayName = ""
        avatarURL = nil
        currentLevel = "TOCFL-1"
        levelGoal = "TOCFL-2"
        reviewDailyLimit = 20
        onboarded = false
        createdAt = nil
        isLoaded = false
        loadFailed = false
        isSavingAvatar = false
        message = nil
    }

    func update(_ fields: [String: Any]) async {
        guard let uid = client.userId else { return }
        var body = fields
        body["updated_at"] = SupabaseDate.string(Date())
        do {
            _ = try await client.rest("PATCH", "profiles?id=eq.\(uid)", body: body)
            message = nil
        } catch {
            message = L("保存できませんでした。通信を確かめてください。")
        }
    }

    func uploadAvatar(_ image: UIImage) async {
        guard let uid = client.userId,
              let jpeg = ImageTools.jpegForUpload(ImageTools.resized(image, maxSide: 512), quality: 0.85) else { return }
        isSavingAvatar = true
        defer { isSavingAvatar = false }
        let path = "\(uid)/avatar-\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        do {
            try await client.upload(jpeg, path: path, bucket: "avatars")
            guard let url = client.publicURL(bucket: "avatars", path: path) else { return }
            await update(["avatar_url": url])
            avatarURL = url
        } catch {
            message = L("写真を保存できませんでした。")
        }
    }

    /// 退会: removes the user's photos and every personal row RLS lets the owner delete
    /// (stickers cascade encounters / reviews / review_history). Shared `words` stay.
    /// Deletes the whole account through the web's `deleteMyAccount`: photos, every row
    /// (children first), and the **login itself** (`auth.admin.deleteUser`, service role).
    /// Deleting only the rows left a live login behind (App Store Review Guideline 5.1.1(v)).
    /// The user has typed 「削除」 on the settings screen; that is the confirmation the server requires.
    func deleteAccount() async throws {
        _ = try await NativeAPI.call("deleteMyAccount", ["confirm": "削除"], timeout: 60)  // l10n-ignore (server keyword)
    }

    func clearAvatar() async {
        await update(["avatar_url": NSNull()])
        avatarURL = nil
    }
}

/// Round profile photo (falls back to a person glyph).
struct AvatarView: View {
    let url: String?
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(Theme.secondary)
            .frame(width: size, height: size)
            .overlay {
                if let url, let u = URL(string: url) {
                    AsyncImage(url: u) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .allowsHitTesting(false)
                } else {
                    Image(systemName: "person.fill").font(.system(size: size * 0.45)).foregroundStyle(Theme.muted)
                }
            }
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }
}
