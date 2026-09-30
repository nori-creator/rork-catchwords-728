import SwiftUI

/// The shared `profiles` row (same columns the web settings screen edits).
@Observable
final class ProfileStore {
    var displayName: String = ""
    var avatarURL: String?
    var nativeLanguage: String = "ja"
    var targetLanguage: String = "zh-TW"
    var currentLevel: String = "TOCFL-1"
    var levelGoal: String = "TOCFL-2"
    var reviewDailyLimit: Int = 10
    var isSavingAvatar: Bool = false
    var message: String?

    private let client = SupabaseClient.shared

    static let levelOptions: [(value: String, label: String)] = (1...6).map { ("TOCFL-\($0)", "TOCFL Level \($0)") }
    static let nativeOptions: [(value: String, label: String)] = [("ja", "日本語"), ("en", "English"), ("zh-TW", "繁體中文")]

    func load() async {
        guard let uid = client.userId else { return }
        let full = "display_name,avatar_url,native_language,target_language,level_goal,current_level,review_daily_limit"
        var data = try? await client.rest("GET", "profiles?id=eq.\(uid)&select=\(full)")
        if data == nil {
            data = try? await client.rest("GET", "profiles?id=eq.\(uid)&select=display_name,avatar_url,native_language,target_language,level_goal")
        }
        guard let data, let row = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]])?.first else { return }
        displayName = row["display_name"] as? String ?? ""
        avatarURL = row["avatar_url"] as? String
        nativeLanguage = row["native_language"] as? String ?? "ja"
        targetLanguage = row["target_language"] as? String ?? "zh-TW"
        if let v = row["current_level"] as? String, !v.isEmpty { currentLevel = v }
        if let v = row["level_goal"] as? String, !v.isEmpty { levelGoal = v }
        if let v = row["review_daily_limit"] as? Int, v > 0 { reviewDailyLimit = v }
    }

    func update(_ fields: [String: Any]) async {
        guard let uid = client.userId else { return }
        var body = fields
        body["updated_at"] = SupabaseDate.string(Date())
        do {
            _ = try await client.rest("PATCH", "profiles?id=eq.\(uid)", body: body)
            message = nil
        } catch {
            message = "保存できませんでした。通信を確かめてください。"
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
            message = "写真を保存できませんでした。"
        }
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
