import SwiftUI

/// Home diary (HomeShelf "日記を書く" + journal.functions.ts `saveMyDiary` / `listMyDiaryMonth`).
/// The device copy is keyed by date: until the server confirms, it is the only place the text lives,
/// so drafts from earlier days are picked back up instead of disappearing at midnight.
@Observable
final class DiaryStore {
    /// entry_date (YYYY-MM-DD) → text shown on the page (user_draft ?? correction ?? body_zh).
    private(set) var entries: [String: String] = [:]
    private(set) var loadedMonths: Set<String> = []
    var isSaving: Bool = false
    var message: String?

    private let client = SupabaseClient.shared
    private static let draftPrefix = "diary-draft-"

    static func key(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func text(for day: Date) -> String { entries[Self.key(day)] ?? "" }

    func loadMonth(of day: Date) async {
        let dayKey = Self.key(day)
        let month = String(dayKey.prefix(7))
        guard !loadedMonths.contains(month), client.userId != nil else { return }
        let parts = month.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let next = parts[1] == 12 ? String(format: "%04d-01", parts[0] + 1) : String(format: "%04d-%02d", parts[0], parts[1] + 1)
        let path = "journal_entries?select=entry_date,user_draft,correction,body_zh&entry_date=gte.\(month)-01&entry_date=lt.\(next)-01&order=entry_date.asc&limit=31"
        guard let data = try? await client.rest("GET", path),
              let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return }
        loadedMonths.insert(month)
        for r in rows {
            guard let date = r["entry_date"] as? String else { continue }
            let text = (r["user_draft"] as? String) ?? (r["correction"] as? String) ?? (r["body_zh"] as? String) ?? ""
            entries[date] = text
        }
    }

    // MARK: - Device drafts

    func draft(for day: Date) -> String? { UserDefaults.standard.string(forKey: Self.draftPrefix + Self.key(day)) }

    func keepDraft(_ text: String, for day: Date) {
        let k = Self.draftPrefix + Self.key(day)
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.removeObject(forKey: k)
        } else {
            UserDefaults.standard.set(text, forKey: k)
        }
    }

    /// Unsent drafts from days before today (today's key is the one being written — left alone).
    var strandedDrafts: [(date: Date, text: String)] {
        let today = Self.key(Date())
        return UserDefaults.standard.dictionaryRepresentation().compactMap { key, value in
            guard key.hasPrefix(Self.draftPrefix), let text = value as? String else { return nil }
            let dayKey = String(key.dropFirst(Self.draftPrefix.count))
            guard dayKey < today, let d = Self.date(from: dayKey) else { return nil }
            return (d, text)
        }
        .sorted { $0.date > $1.date }
    }

    static func date(from key: String) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    // MARK: - Save (upsert only user_draft — correction columns stay untouched)

    @discardableResult
    func save(_ text: String, for day: Date) async -> Bool {
        guard let uid = client.userId else {
            message = "ログインすると日記を保存できます。書いた文章はこの端末に残っています。"
            return false
        }
        let dayKey = Self.key(day)
        guard dayKey <= Self.key(Date()) else { message = "未来の日の日記は書けません"; return false }
        isSaving = true
        defer { isSaving = false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: Any] = ["user_id": uid, "entry_date": dayKey, "user_draft": trimmed.isEmpty ? NSNull() : trimmed]
        do {
            _ = try await client.rest("POST", "journal_entries?on_conflict=user_id,entry_date", body: body,
                                      prefer: "resolution=merge-duplicates,return=minimal")
            entries[dayKey] = trimmed
            keepDraft("", for: day)
            message = nil
            return true
        } catch {
            keepDraft(text, for: day)
            message = "日記を保存できませんでした。書いた文章はこの端末に残っています。"
            return false
        }
    }
}
