import SwiftUI
import CoreLocation
import Photos

/// Everything needed to save one catch.
struct CatchDraft {
    let candidate: Candidate
    let details: CardDetails?
    let photo: UIImage
    let cutout: UIImage?
    let selfie: UIImage?
    let caption: String
    let location: CLLocation?
    let placeName: String?
    let captureType: String
}

enum SaveOutcome {
    case created(Sticker)
    case reencounter(Sticker)

    var sticker: Sticker {
        switch self {
        case .created(let s), .reencounter(let s): s
        }
    }
}

/// The user's dex, read from and written to the SAME Supabase project as the web app.
@Observable
final class DexStore {
    var stickers: [Sticker] = []
    var isLoading: Bool = false
    var hasLoaded: Bool = false
    var loadError: String?
    var signed: [String: URL] = [:]
    var pending: [PendingCatch] = []
    /// sticker id → review state (memory badges). Stickers without a review get no badge.
    var reviews: [String: ReviewState] = [:]

    private let client = SupabaseClient.shared
    private let language = "zh-TW"
    private static let selectColumns =
        "id,word_id,object_image_url,cutout_image_url,selfie_image_url,caption,location_name,taken_at,capture_type,word:words(*)"

    func load() async {
        pending = PendingQueue.shared.all()
        guard client.session != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await client.rest("GET", "stickers?select=\(Self.selectColumns)&order=taken_at.desc&limit=500")
            let rows = try SupabaseDate.decoder.decode([Sticker].self, from: data)
            stickers = rows
            loadError = nil
            hasLoaded = true
            await loadReviews()
            await signPaths(for: rows)
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? "図鑑を読み込めませんでした。"
        }
    }

    func reloadReviews() async { await loadReviews() }

    func sticker(id: String) -> Sticker? { stickers.first { $0.id == id } }

    /// True when this headword is already in the dex (scan "取得済み").
    func owns(headword: String) -> Bool { stickers.contains { $0.word?.headword == headword } }

    /// Level index (0–5) for every sticker that has a review — feeds the memory bar.
    var memoryLevelCounts: [Int] {
        var out = Array(repeating: 0, count: 6)
        for s in stickers {
            if let p = memoryPercent(for: s) { out[MemoryBadge.level(p)] += 1 }
        }
        return out
    }

    private func loadReviews() async {
        guard let data = try? await client.rest("GET", "reviews?select=id,sticker_id,ease,interval_days,repetitions,last_reviewed_at,due_at&limit=3000"),
              let rows = try? SupabaseDate.decoder.decode([ReviewState].self, from: data) else { return }
        reviews = Dictionary(rows.map { ($0.stickerId, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Same number the review screen shows (srs.ts retentionNow; origin = last review, else the catch).
    func memoryPercent(for sticker: Sticker) -> Int? {
        guard let r = reviews[sticker.id] else { return nil }
        return MemoryMath.percent(intervalDays: r.intervalDays, ease: r.ease, last: r.lastReviewedAt ?? sticker.takenAt)
    }

    func url(for path: String?, preferThumb: Bool = true) -> URL? {
        guard let path else { return nil }
        if preferThumb, let t = signed[path + ".thumb.webp"] { return t }
        return signed[path]
    }

    private func signPaths(for rows: [Sticker]) async {
        var paths: [String] = []
        for s in rows {
            for p in [s.objectImageUrl, s.cutoutImageUrl, s.selfieImageUrl].compactMap({ $0 }) where signed[p] == nil {
                paths.append(p)
                paths.append(p + ".thumb.webp")
            }
        }
        guard !paths.isEmpty else { return }
        for chunk in stride(from: 0, to: paths.count, by: 200).map({ Array(paths[$0..<min($0 + 200, paths.count)]) }) {
            if let map = try? await client.signedURLs(for: chunk) {
                signed.merge(map) { _, new in new }
            }
        }
    }

    // MARK: - Save a catch

    func save(_ draft: CatchDraft) async throws -> SaveOutcome {
        guard let uid = client.userId else { throw APIError.unauthorized }
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let head = draft.candidate.headword

        var ownedMatch: Sticker?
        if let existing = try await findWord(headword: head) {
            if let local = stickers.first(where: { $0.wordId == existing.id }) {
                ownedMatch = local
            } else {
                ownedMatch = try await ownedSticker(wordId: existing.id)
            }
        }
        if let owned = ownedMatch {
            // Reencounter: never create a duplicate sticker, but never throw the photo away either.
            if let jpeg = ImageTools.jpegForUpload(draft.photo) {
                try? await client.upload(jpeg, path: "\(uid)/\(ts)-encounter.jpg")
            }
            _ = try? await client.rest("PATCH", "stickers?id=eq.\(owned.id)", body: ["taken_at": SupabaseDate.string(Date())])
            return .reencounter(owned)
        }

        async let objectPath: String? = uploadJPEG(draft.photo, uid: uid, ts: ts, kind: "object")
        async let cutoutPath: String? = uploadPNG(draft.cutout, uid: uid, ts: ts, kind: "cutout")
        async let selfiePath: String? = try? uploadJPEG(draft.selfie, uid: uid, ts: ts, kind: "selfie")
        async let wordId: String = ensureWord(draft)

        let (obj, cut, wid) = try await (objectPath, cutoutPath, wordId)
        let selfieRef = await selfiePath

        var row: [String: Any] = [
            "user_id": uid,
            "word_id": wid,
            "language": language,
            "capture_type": draft.captureType,
            "taken_at": SupabaseDate.string(Date()),
        ]
        if let obj { row["object_image_url"] = obj }
        if let cut { row["cutout_image_url"] = cut }
        if let s = selfieRef ?? nil { row["selfie_image_url"] = s }
        let caption = draft.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        if !caption.isEmpty { row["caption"] = caption }
        if let name = draft.placeName { row["location_name"] = name }
        if let loc = draft.location {
            row["lat"] = loc.coordinate.latitude
            row["lng"] = loc.coordinate.longitude
        }
        let data = try await client.rest(
            "POST",
            "stickers?select=\(Self.selectColumns)",
            body: row,
            prefer: "return=representation"
        )
        guard let sticker = try SupabaseDate.decoder.decode([Sticker].self, from: data).first else { throw APIError.decoding }

        cacheLocal(path: obj, image: draft.photo)
        cacheLocal(path: cut, image: draft.cutout)
        cacheLocal(path: selfieRef ?? nil, image: draft.selfie)
        stickers.insert(sticker, at: 0)
        await signPaths(for: [sticker])
        saveToPhotosIfEnabled(draft.photo)
        return .created(sticker)
    }

    private func findWord(headword: String) async throws -> Word? {
        let data = try await client.rest("GET", "words?language=eq.\(language)&headword=eq.\(Self.enc(headword))&select=*&limit=1")
        return try JSONDecoder().decode([Word].self, from: data).first
    }

    private func ownedSticker(wordId: String) async throws -> Sticker? {
        let data = try await client.rest("GET", "stickers?word_id=eq.\(wordId)&select=\(Self.selectColumns)&limit=1")
        return try SupabaseDate.decoder.decode([Sticker].self, from: data).first
    }

    private func ensureWord(_ draft: CatchDraft) async throws -> String {
        try await ensureWord(candidate: draft.candidate, details: draft.details)
    }

    private func ensureWord(candidate c: Candidate, details d: CardDetails?) async throws -> String {
        if let w = try await findWord(headword: c.headword) { return w.id }
        var extras: Any = [String: Any]()
        if let e = d?.extras, let data = try? JSONEncoder().encode(e), let obj = try? JSONSerialization.jsonObject(with: data) {
            extras = obj
        }
        var row: [String: Any] = [
            "language": language,
            "headword": c.headword,
            "meaning_ja": c.meaningJa.isEmpty ? c.headword : c.meaningJa,
            "part_of_speech": c.pos.isEmpty ? "名詞" : c.pos,
            "level": d?.level ?? "TOCFL-2",
            "category_key": d?.categoryKey ?? "other",
            "extras": extras,
            "source": "ai",
            "entry_type": "word",
        ]
        if let uid = client.userId { row["created_by"] = uid }
        if !c.zhuyin.isEmpty { row["reading_zhuyin"] = c.zhuyin }
        if !c.pinyin.isEmpty { row["pinyin"] = c.pinyin }
        if let ex = d?.exampleSentence, !ex.isEmpty { row["example_sentence"] = ex }
        if let tr = d?.exampleTranslation, !tr.isEmpty { row["example_translation"] = tr }

        do {
            return try await insertWord(row)
        } catch APIError.server(let code, _) where code == 409 || code == 400 || code == 23503 {
            if let w = try await findWord(headword: c.headword) { return w.id }
            row["category_key"] = "other"
            return try await insertWord(row)
        }
    }

    private func insertWord(_ row: [String: Any]) async throws -> String {
        let data = try await client.rest("POST", "words?select=id", body: row, prefer: "return=representation")
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let id = arr.first?["id"] as? String else { throw APIError.decoding }
        return id
    }

    private func uploadJPEG(_ image: UIImage?, uid: String, ts: Int, kind: String) async throws -> String? {
        guard let image, let jpeg = ImageTools.jpegForUpload(image) else { return nil }
        let path = "\(uid)/\(ts)-\(kind).jpg"
        try await client.upload(jpeg, path: path)
        return path
    }

    /// Cutout failures never block the catch.
    private func uploadPNG(_ image: UIImage?, uid: String, ts: Int, kind: String) async -> String? {
        guard let image, let png = ImageTools.resized(image, maxSide: 1200).pngData() else { return nil }
        let path = "\(uid)/\(ts)-\(kind).png"
        do {
            try await client.upload(png, path: path, contentType: "image/png")
            return path
        } catch {
            return nil
        }
    }

    private func cacheLocal(path: String?, image: UIImage?) {
        guard let path, let image else { return }
        ImageCache.shared.set(image, for: path)
    }

    private func saveToPhotosIfEnabled(_ image: UIImage) {
        let enabled = UserDefaults.standard.object(forKey: "photos.sync") as? Bool ?? true
        guard enabled else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }
    }

    // MARK: - Edit

    func addCutout(to sticker: Sticker, image: UIImage) async throws {
        guard let uid = client.userId else { throw APIError.unauthorized }
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        guard let path = await uploadPNG(image, uid: uid, ts: ts, kind: "cutout") else {
            throw APIError.message("切り抜きの保存に失敗しました。")
        }
        _ = try await client.rest("PATCH", "stickers?id=eq.\(sticker.id)", body: ["cutout_image_url": path])
        ImageCache.shared.set(image, for: path)
        replace(sticker.id) { old in
            Sticker(
                id: old.id, wordId: old.wordId, objectImageUrl: old.objectImageUrl, cutoutImageUrl: path,
                selfieImageUrl: old.selfieImageUrl, caption: old.caption, locationName: old.locationName,
                takenAt: old.takenAt, captureType: old.captureType, word: old.word, lat: old.lat, lng: old.lng
            )
        }
    }

    /// Saves the sticker's one-line note (ひと言). Empty clears it.
    func updateCaption(_ sticker: Sticker, caption: String) async throws {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let value: Any = trimmed.isEmpty ? NSNull() : trimmed
        _ = try await client.rest("PATCH", "stickers?id=eq.\(sticker.id)", body: ["caption": value])
        replace(sticker.id) { old in
            Sticker(
                id: old.id, wordId: old.wordId, objectImageUrl: old.objectImageUrl, cutoutImageUrl: old.cutoutImageUrl,
                selfieImageUrl: old.selfieImageUrl, caption: trimmed.isEmpty ? nil : trimmed, locationName: old.locationName,
                takenAt: old.takenAt, captureType: old.captureType, word: old.word, lat: old.lat, lng: old.lng
            )
        }
    }

    /// Points this sticker at another headword (setStickerHeadword). The shared `words` row is never rewritten.
    func setHeadword(_ sticker: Sticker, to raw: String) async throws {
        let head = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !head.isEmpty, head.count <= 60 else { throw APIError.message("単語を入れてください。") }
        guard head.hasHan else { throw APIError.message("学習している言語の単語を入れてください") }
        if sticker.word?.headword == head { return }

        let wordId: String
        if let existing = try await findWord(headword: head) {
            wordId = existing.id
        } else {
            let looked = try? await AIService.shared.lookup(text: head)
            let candidate = Candidate(
                kind: "text", headword: head, zhuyin: looked?.zhuyin ?? "", pinyin: looked?.pinyin ?? "",
                meaningJa: looked?.meaningJa ?? "", pos: looked?.pos ?? "", point: [500, 500], confidence: 1, alternatives: []
            )
            let details = try? await AIService.shared.cardDetails(for: candidate)
            wordId = try await ensureWord(candidate: candidate, details: details)
        }
        let data = try await client.rest(
            "PATCH", "stickers?id=eq.\(sticker.id)&select=\(Self.selectColumns)",
            body: ["word_id": wordId], prefer: "return=representation"
        )
        guard let updated = try SupabaseDate.decoder.decode([Sticker].self, from: data).first else { throw APIError.decoding }
        replace(sticker.id) { old in
            var s = updated
            s.lat = old.lat
            s.lng = old.lng
            return s
        }
    }

    /// Dictionary error report → `entry_reports` (reports.functions.ts). Lands in the admin review queue.
    func report(headword: String, kind: String, note: String) async throws {
        guard let uid = client.userId else { throw APIError.unauthorized }
        _ = try await client.rest("POST", "entry_reports", body: [
            "user_id": uid,
            "headword": String(headword.prefix(80)),
            "kind": kind,
            "note": String(note.prefix(500)),
        ])
    }

    private func replace(_ id: String, _ transform: (Sticker) -> Sticker) {
        guard let i = stickers.firstIndex(where: { $0.id == id }) else { return }
        stickers[i] = transform(stickers[i])
    }

    func delete(_ sticker: Sticker) async throws {
        _ = try await client.rest("DELETE", "stickers?id=eq.\(sticker.id)")
        stickers.removeAll { $0.id == sticker.id }
    }

    func refreshPending() {
        pending = PendingQueue.shared.all()
    }

    func reset() {
        stickers = []
        signed = [:]
        hasLoaded = false
    }

    nonisolated static func enc(_ s: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+,()")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
}
