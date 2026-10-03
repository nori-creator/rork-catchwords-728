import SwiftUI

/// One row of `journal_entries` as the web returns it (journal.functions.ts `JournalEntry`).
nonisolated struct JournalEntry: Decodable, Identifiable, Hashable, Sendable {
    struct Phrase: Decodable, Hashable, Sendable {
        let zh: String
        let ja: String
        let note: String?
    }
    let id: String
    let entryDate: String
    let bodyZh: String?
    let bodyJa: String?
    let userDraft: String?
    let correction: String?
    let feedbackJa: String?
    let nativePhrases: [Phrase]?

    enum CodingKeys: String, CodingKey {
        case id
        case entryDate = "entry_date"
        case bodyZh = "body_zh"
        case bodyJa = "body_ja"
        case userDraft = "user_draft"
        case correction
        case feedbackJa = "feedback_ja"
        case nativePhrases = "native_phrases"
    }
}

/// Writing help made from today's catches (journal.functions.ts `getJournalPrompts`).
nonisolated struct JournalScaffold: Decodable, Hashable, Sendable {
    struct Prompt: Decodable, Hashable, Sendable {
        let stickerId: String?
        let questionZh: String
        let questionJa: String
        enum CodingKeys: String, CodingKey {
            case stickerId = "sticker_id"
            case questionZh = "question_zh"
            case questionJa = "question_ja"
        }
    }
    struct Pattern: Decodable, Hashable, Sendable {
        let zh: String
        let ja: String
    }
    struct Capture: Decodable, Hashable, Sendable {
        let id: String
        let headword: String
    }
    let prompts: [Prompt]
    let patterns: [Pattern]
    let captures: [Capture]
}

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
    /// The last 30 entries with their corrections (web `listJournal`), newest first.
    private(set) var journal: [JournalEntry] = []
    private(set) var journalLoaded = false
    private(set) var journalFailed = false
    var isCorrecting = false
    /// Today's writing help; nil until loaded, and stays nil on days without catches.
    private(set) var scaffold: JournalScaffold?
    private var scaffoldDay: String?

    private let client = SupabaseClient.shared
    /// Drafts written before they were kept per account (device-wide keys).
    private static let legacyDraftPrefix = "diary-draft-"
    /// Device drafts belong to the account that wrote them: another account on this device never sees them.
    private var draftPrefix: String { "diary-draft-\(client.userId ?? "guest")-" }

    /// Signing out: nothing of this account's diary stays on screen for the next one.
    func reset() {
        entries = [:]
        loadedMonths = []
        journal = []
        journalLoaded = false
        journalFailed = false
        scaffold = nil
        scaffoldDay = nil
        message = nil
    }

    /// The account was deleted: its unsent diary drafts are removed from this device too.
    static func removeDrafts(userId: String) {
        let defaults = UserDefaults.standard
        let prefix = "diary-draft-\(userId)-"
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Moves drafts saved under the old device-wide keys to the signed-in account (once).
    private func adoptLegacyDrafts() {
        guard client.userId != nil else { return }
        let defaults = UserDefaults.standard
        for (key, value) in defaults.dictionaryRepresentation() {
            guard key.hasPrefix(Self.legacyDraftPrefix), let text = value as? String else { continue }
            let rest = String(key.dropFirst(Self.legacyDraftPrefix.count))
            // Only bare dates (YYYY-MM-DD); keys that already carry an account are left alone.
            guard rest.count == 10, Self.date(from: rest) != nil else { continue }
            if defaults.string(forKey: draftPrefix + rest) == nil { defaults.set(text, forKey: draftPrefix + rest) }
            defaults.removeObject(forKey: key)
        }
    }

    static func key(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func text(for day: Date) -> String { entries[Self.key(day)] ?? "" }

    /// Days (YYYY-MM-DD) that have a diary entry — they get a page in the month's book even without photos.
    var dayKeys: [String] { entries.filter { !$0.value.isEmpty }.map(\.key) }

    func loadMonth(of day: Date) async {
        let dayKey = Self.key(day)
        let month = String(dayKey.prefix(7))
        guard !loadedMonths.contains(month), client.userId != nil else { return }
        adoptLegacyDrafts()
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

    // MARK: - Journal (AI correction, prompts, past entries)

    func entry(for day: Date) -> JournalEntry? { journal.first { $0.entryDate == Self.key(day) } }

    func loadJournal() async {
        do {
            journal = try await NativeAPI.call("listJournal", [:], as: [JournalEntry].self)
            journalFailed = false
        } catch {
            journalFailed = true
        }
        journalLoaded = true
    }

    /// Questions and sentence patterns from today's catches — only once a day (it uses the AI).
    func loadScaffold() async {
        // Once a day per learning language (the prompts are written in it).
        let today = Self.key(Date()) + "|" + NativeAPI.targetLanguage
        guard scaffoldDay != today else { return }
        scaffoldDay = today
        scaffold = try? await NativeAPI.call("getJournalPrompts", [:], as: JournalScaffold?.self, timeout: 45)
    }

    /// Web `correctMyJournal`: a corrected version, notes on the patterns used, and how a native
    /// speaker would say it. The text is also saved as the day's own draft by the server.
    @discardableResult
    func correct(_ text: String, for day: Date) async -> Bool {
        let draft = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard draft.count >= 2 else { return false }
        isCorrecting = true
        defer { isCorrecting = false }
        keepDraft(text, for: day)
        do {
            let e = try await NativeAPI.call("correctMyJournal", ["draft": String(draft.prefix(2000))], as: JournalEntry.self, timeout: 90)
            journal.removeAll { $0.entryDate == e.entryDate }
            journal.insert(e, at: 0)
            entries[e.entryDate] = e.userDraft ?? draft
            keepDraft("", for: day)
            message = nil
            return true
        } catch let APIError.limit(m) {
            message = L10n.readerSafe(m, fallback: APIError.dailyCapMessage)
            return false
        } catch {
            message = (error as? LocalizedError)?.errorDescription.map { L("添削失敗: \($0)") } ?? L("添削失敗")
            return false
        }
    }

    // MARK: - Device drafts

    func draft(for day: Date) -> String? { UserDefaults.standard.string(forKey: draftPrefix + Self.key(day)) }

    func keepDraft(_ text: String, for day: Date) {
        let k = draftPrefix + Self.key(day)
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.removeObject(forKey: k)
        } else {
            UserDefaults.standard.set(text, forKey: k)
        }
    }

    /// Unsent drafts from days before today (today's key is the one being written — left alone).
    var strandedDrafts: [(date: Date, text: String)] {
        let today = Self.key(Date())
        let prefix = draftPrefix
        return UserDefaults.standard.dictionaryRepresentation().compactMap { key, value in
            guard key.hasPrefix(prefix), let text = value as? String else { return nil }
            let dayKey = String(key.dropFirst(prefix.count))
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
            message = L("ログインすると日記を保存できます。書いた文章はこの端末に残っています。")
            return false
        }
        let dayKey = Self.key(day)
        guard dayKey <= Self.key(Date()) else { message = L("未来の日の日記は書けません"); return false }
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
            message = L("日記を保存できませんでした。書いた文章はこの端末に残っています。")
            return false
        }
    }
}
