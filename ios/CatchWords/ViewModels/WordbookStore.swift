import SwiftUI

/// wordbook.functions.ts — shelf, import, SRS review. Never mixed into the dex (`stickers`).
@Observable
final class WordbookStore {
    var books: [WordbookSummary] = []
    var isLoading: Bool = false
    var hasLoaded: Bool = false
    var loadError: String?

    private let client = SupabaseClient.shared

    func load() async {
        guard client.session != nil else { hasLoaded = true; return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let booksData = client.rest("GET", "wordbooks?select=id,title,created_at&order=created_at.desc")
            // Paged: the server answers at most 1000 rows per request (the shelf's counts were cut).
            async let rowsList = client.restAll("wordbook_entries?select=id,wordbook_id,headword,due_at,repetitions&order=id.asc",
                                                as: WordbookEntry.self, decoder: SupabaseDate.decoder)
            let (b, rows) = try await (booksData, rowsList)
            let rawBooks = (try JSONSerialization.jsonObject(with: b) as? [[String: Any]]) ?? []
            let byBook = Dictionary(grouping: rows, by: \.wordbookId)
            books = rawBooks.compactMap { d in
                guard let id = d["id"] as? String else { return nil }
                let list = byBook[id] ?? []
                return WordbookSummary(
                    id: id,
                    title: (d["title"] as? String) ?? L("単語帳"),
                    createdAt: (d["created_at"] as? String).flatMap(SupabaseDate.parse) ?? Date(),
                    total: list.count,
                    due: list.filter(\.isDue).count,
                    learned: list.filter { $0.repetitions >= 3 }.count
                )
            }
            loadError = nil
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? L("単語帳の一覧を読み込めませんでした。")
        }
        hasLoaded = true
    }

    /// createWordbook: one book + its entries.
    @discardableResult
    func create(title: String, entries: [WordbookEntryDraft]) async throws -> Int {
        guard let uid = client.userId else { throw APIError.unauthorized }
        let cleaned = Wordbook.clean(entries)
        guard !cleaned.isEmpty else { throw APIError.message(L("入れる語がありません")) }
        let today = SRS.taipeiDay(Date())
        let data = try await client.rest(
            "POST", "wordbooks?select=id",
            body: ["user_id": uid, "title": Wordbook.title(title, fallback: today)],
            prefer: "return=representation"
        )
        guard let id = ((try JSONSerialization.jsonObject(with: data) as? [[String: Any]])?.first?["id"]) as? String else {
            throw APIError.message(L("単語帳を作れませんでした"))
        }
        let rows: [[String: Any]] = cleaned.map { e in
            [
                "wordbook_id": id,
                "user_id": uid,
                "headword": e.headword,
                "reading_zhuyin": e.readingZhuyin ?? NSNull(),
                "pinyin": e.pinyin ?? NSNull(),
                "meaning_ja": e.meaningJa ?? NSNull(),
            ]
        }
        do {
            _ = try await client.rest("POST", "wordbook_entries", body: rows)
        } catch {
            // The words did not go in: take the empty book back out, so trying again does not leave
            // an empty duplicate on the shelf.
            _ = try? await client.rest("DELETE", "wordbooks?id=eq.\(id)")
            throw error
        }
        await load()
        return cleaned.count
    }

    func delete(_ book: WordbookSummary) async throws {
        _ = try await client.rest("DELETE", "wordbooks?id=eq.\(book.id)")
        withAnimation(.snappy) { books.removeAll { $0.id == book.id } }
    }

    /// getWordbookDue: every row of the book (for choices) + the due ones (limit 20).
    func due(bookId: String, limit: Int = 20) async throws -> (due: [WordbookEntry], pool: [String]) {
        let data = try await client.rest(
            "GET",
            "wordbook_entries?wordbook_id=eq.\(bookId)&select=id,wordbook_id,headword,reading_zhuyin,pinyin,meaning_ja,ease,interval_days,repetitions,due_at,last_reviewed_at&order=due_at.asc&limit=200"
        )
        let all = try SupabaseDate.decoder.decode([WordbookEntry].self, from: data)
        // Not in the order the page was read (owner): overdue cards first by how overdue they are,
        // new cards in random order, and the session itself shuffled.
        let due = all.filter(\.isDue)
        let reviewed = due.filter { $0.lastReviewedAt != nil }
        let fresh = due.filter { $0.lastReviewedAt == nil }.shuffled()
        let batch = Array((reviewed + fresh).prefix(limit)).shuffled()
        return (batch, all.map(\.headword))
    }

    /// gradeWordbookEntry: same SRS as the dex (correct=5, wrong=2).
    func grade(_ entry: WordbookEntry, correct: Bool) async throws {
        let elapsed = entry.lastReviewedAt.map { Date().timeIntervalSince($0) / 86_400 }
        let next = SRS.next(.init(ease: entry.ease, intervalDays: entry.intervalDays, repetitions: entry.repetitions), score: correct ? 5 : 2, elapsedDays: elapsed)
        let now = Date()
        _ = try await client.rest("PATCH", "wordbook_entries?id=eq.\(entry.id)", body: [
            "ease": next.ease,
            "interval_days": next.intervalDays,
            "repetitions": next.repetitions,
            "due_at": SupabaseDate.string(now.addingTimeInterval(Double(next.intervalDays) * 86_400)),
            "last_reviewed_at": SupabaseDate.string(now),
        ])
    }
}
