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
        "id,word_id,object_image_url,cutout_image_url,selfie_image_url,caption,location_name,taken_at,capture_type,shelf_key,word:words(*)"

    func load() async {
        pending = PendingQueue.shared.all()
        guard client.session != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await client.rest("GET", "stickers?select=\(Self.selectColumns)&order=taken_at.desc&limit=500")
            let rows = try SupabaseDate.decoder.decode([Sticker].self, from: data)
            await loadShelves()
            await loadAlbumHidden()
            await loadAlbumPlacements()
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

    /// Saves a new catch through the web's own `saveSticker` (stickers.functions.ts): the same
    /// word upsert, extras merge (service role), new-shelf proposal, first-catch event and
    /// duplicate guard as the web. Photos are uploaded first, in parallel; a failed cutout or
    /// selfie never blocks the catch.
    func save(_ draft: CatchDraft) async throws -> SaveOutcome {
        guard let uid = client.userId else { throw APIError.unauthorized }
        guard let card = draft.details else { throw APIError.message("カード生成に失敗しました") }
        let ts = Int(Date().timeIntervalSince1970 * 1000)

        async let objectPath: String? = uploadJPEG(draft.photo, uid: uid, ts: ts, kind: "object")
        async let cutoutPath: String? = uploadPNG(draft.cutout, uid: uid, ts: ts, kind: "cutout")
        async let selfiePath: String? = try? uploadJPEG(draft.selfie, uid: uid, ts: ts, kind: "selfie")
        let obj = try await objectPath
        let cut = await cutoutPath
        let selfieRef: String? = await selfiePath

        let c = draft.candidate
        let raw = card.raw
        func text(_ key: String, _ fallback: String) -> String {
            let v = raw?[key]?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return v.isEmpty ? fallback : v
        }
        var word: [String: Any] = [
            // The picked name is the headword (capture.tsx `selectedHead`), not the card's own guess.
            "headword": c.headword,
            "reading_zhuyin": text("reading_zhuyin", c.zhuyin),
            "pinyin": text("pinyin", c.pinyin),
            "meaning_ja": text("meaning_ja", c.meaningJa.isEmpty ? c.headword : c.meaningJa),
            "part_of_speech": text("part_of_speech", c.pos.isEmpty ? "名詞" : c.pos),
            "level": text("level", card.level),
            "category_key": text("category_key", card.categoryKey),
            "example_sentence": text("example_sentence", card.exampleSentence),
            "example_translation": text("example_translation", card.exampleTranslation),
        ]
        if let extras = raw?["extras"], case .object = extras { word["extras"] = extras.foundation }
        let caption = draft.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let data: [String: Any] = [
            "word": word,
            "new_shelf": orNull(raw?["new_shelf"]?.foundation),
            "language": NativeAPI.targetLanguage,
            "object_path": orNull(obj),
            "cutout_path": orNull(cut),
            "selfie_path": orNull(selfieRef),
            "caption": orNull(caption.isEmpty ? nil : caption),
            "location_name": orNull(draft.placeName),
            "lat": orNull(draft.location?.coordinate.latitude),
            "lng": orNull(draft.location?.coordinate.longitude),
        ]
        struct Saved: Decodable { let id: String }
        let saved = try await NativeAPI.call("saveSticker", data, as: Saved.self, timeout: 45)

        cacheLocal(path: obj, image: draft.photo)
        cacheLocal(path: cut, image: draft.cutout)
        cacheLocal(path: selfieRef, image: draft.selfie)
        let sticker = try await fetchSticker(id: saved.id)
        stickers.removeAll { $0.id == sticker.id }
        stickers.insert(sticker, at: 0)
        await signPaths(for: [sticker])
        saveToPhotosIfEnabled(draft.photo)
        return .created(sticker)
    }

    private func fetchSticker(id: String) async throws -> Sticker {
        let data = try await client.rest("GET", "stickers?id=eq.\(id)&select=\(Self.selectColumns)&limit=1")
        guard let s = try SupabaseDate.decoder.decode([Sticker].self, from: data).first else { throw APIError.decoding }
        return s
    }

    /// Re-encounter (web `recordReencounter`): this photo is added to the word you already own,
    /// with where you met it again. No quiz, and the review interval is not moved (`recalled: null`).
    /// If the photo upload fails the encounter itself is still recorded.
    func recordEncounter(owned: OwnedWord, photo: UIImage?, cutout: UIImage?,
                         location: CLLocation?, placeName: String?) async throws -> (count: Int, photoSaved: Bool) {
        guard let uid = client.userId else { throw APIError.unauthorized }
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        async let imagePath: String? = uploadJPEG(photo, uid: uid, ts: ts, kind: "encounter")
        async let cutoutPath: String? = uploadPNG(cutout, uid: uid, ts: ts, kind: "encounter-cutout")
        let image = try await imagePath
        let cut = await cutoutPath
        if photo != nil && image == nil { throw APIError.message("記録に失敗しました") }
        struct Recorded: Decodable {
            let encounterCount: Int?
            enum CodingKeys: String, CodingKey { case encounterCount = "encounter_count" }
        }
        let res = try await NativeAPI.call("recordEncounter", [
            "sticker_id": owned.stickerId,
            "recalled": NSNull(),
            "lat": orNull(location?.coordinate.latitude),
            "lng": orNull(location?.coordinate.longitude),
            "location_name": orNull(placeName),
            "image_path": orNull(image),
            "cutout_path": orNull(cut),
        ], as: Recorded.self, timeout: 30)
        cacheLocal(path: image, image: photo)
        if let fresh = try? await fetchSticker(id: owned.stickerId) {
            replace(owned.stickerId) { _ in fresh }
        }
        return (res.encounterCount ?? owned.encounterCount + 1, image != nil || cut != nil)
    }

    private func findWord(headword: String) async throws -> Word? {
        let data = try await client.rest("GET", "words?language=eq.\(language)&headword=eq.\(Self.enc(headword))&select=*&limit=1")
        return try JSONDecoder().decode([Word].self, from: data).first
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
                takenAt: old.takenAt, captureType: old.captureType, word: old.word, lat: old.lat, lng: old.lng, shelfKey: old.shelfKey
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
                takenAt: old.takenAt, captureType: old.captureType, word: old.word, lat: old.lat, lng: old.lng, shelfKey: old.shelfKey
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
    // MARK: - Home album (web album-hidden.functions.ts)

    /// Photos taken off the home album. They stay in the dex; only the album page skips them.
    var albumHidden: Set<String> = []

    func loadAlbumHidden() async {
        struct Res: Decodable { let ids: [String] }
        guard let r = try? await NativeAPI.call("listAlbumHidden", [:], as: Res.self) else { return }
        albumHidden = Set(r.ids)
    }

    func setAlbumHidden(_ id: String, hidden: Bool) async {
        // Update the page at once; roll back if the server refused.
        if hidden { albumHidden.insert(id) } else { albumHidden.remove(id) }
        struct Res: Decodable { let saved: Bool }
        let ok = (try? await NativeAPI.call("setAlbumHidden", ["sticker_id": id, "hidden": hidden], as: Res.self))?.saved ?? false
        if !ok {
            if hidden { albumHidden.remove(id) } else { albumHidden.insert(id) }
        }
    }

    /// Where the learner placed each photo on the album page (web album_x / album_y / album_scale /
    /// album_rot / album_order / album_size). Read on its own so a database without these columns
    /// never breaks the dex (web listMyStickers keeps the same fallback).
    var albumPlacements: [String: DayLayoutSticker] = [:]

    func loadAlbumPlacements() async {
        struct Row: Decodable {
            let id: String
            let album_order: Int?
            let album_size: String?
            let album_x: Double?
            let album_y: Double?
            let album_scale: Double?
            let album_rot: Double?
        }
        guard let data = try? await client.rest("GET", "stickers?select=id,album_order,album_size,album_x,album_y,album_scale,album_rot&limit=3000"),
              let rows = try? JSONDecoder().decode([Row].self, from: data) else { return }
        var out: [String: DayLayoutSticker] = [:]
        for r in rows {
            out[r.id] = DayLayoutSticker(id: r.id, albumOrder: r.album_order, albumSize: r.album_size.flatMap(AlbumSize.init(rawValue:)),
                                         albumX: r.album_x, albumY: r.album_y, albumScale: r.album_scale, albumRot: r.album_rot)
        }
        albumPlacements = out
    }

    /// Saves one day's arrangement (web `saveAlbumLayout`). Returns false if nothing was saved.
    func saveAlbumLayout(_ items: [(id: String, order: Int, size: AlbumSize, place: AlbumPlacement)]) async -> Bool {
        let payload: [[String: Any]] = items.map { i in
            ["sticker_id": i.id, "order": i.order, "size": i.size.rawValue,
             "x": AlbumLayout.clamp(i.place.x, 0, 1), "y": AlbumLayout.clamp(i.place.y, 0, 8),
             "scale": AlbumLayout.clamp(i.place.scale, 0.45, 2.6), "rot": AlbumLayout.clamp(i.place.rot, -180, 180)]
        }
        guard (try? await NativeAPI.call("saveAlbumLayout", ["items": payload], timeout: 30)) != nil else { return false }
        for i in items {
            var d = albumPlacements[i.id] ?? DayLayoutSticker(id: i.id)
            d.albumOrder = i.order
            d.albumSize = i.size
            d.albumX = i.place.x
            d.albumY = i.place.y
            d.albumScale = i.place.scale
            d.albumRot = i.place.rot
            albumPlacements[i.id] = d
        }
        return true
    }

    // MARK: - Shelves (web categories.functions.ts)

    /// The learner's shelves (`user_shelves`, own rows via RLS). Feeds `Category.custom`.
    var shelves: [UserShelf] = []

    func loadShelves() async {
        guard let data = try? await client.rest("GET", "user_shelves?select=key,label,emoji,room_key,room_label&order=created_at.asc"),
              let rows = try? JSONDecoder().decode([UserShelf].self, from: data) else { return }
        shelves = rows
        Category.custom = Dictionary(rows.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Moves one word to another shelf (`setStickerCategory`). nil = back to the AI's category.
    func move(_ sticker: Sticker, to key: String?) async throws {
        _ = try await NativeAPI.call("setStickerCategory", ["sticker_id": sticker.id, "key": key.map { $0 as Any } ?? NSNull()])
        replace(sticker.id) { old in
            var s = old
            s.shelfKey = key
            return s
        }
    }

    /// Creates a shelf (key nil) or renames one, built-in or the learner's own (`saveMyCategory`).
    @discardableResult
    func saveShelf(key: String?, label: String, emoji: String) async throws -> String {
        struct Saved: Decodable { let key: String }
        var data: [String: Any] = [
            "label": label, "emoji": emoji, "room_label": label,
            "existing": Array(Set(Category.allOrderedKeys)),
        ]
        if let key { data["key"] = key }
        let saved = try await NativeAPI.call("saveMyCategory", data, as: Saved.self)
        await loadShelves()
        return saved.key
    }

    /// Deletes the learner's shelf; its words go back to their AI category (`deleteMyCategory`).
    /// For a built-in shelf this only removes the rename.
    func deleteShelf(key: String) async throws {
        _ = try await NativeAPI.call("deleteMyCategory", ["key": key])
        if !Category.isBuiltin(key) {
            for s in stickers where s.shelfKey == key {
                replace(s.id) { old in
                    var n = old
                    n.shelfKey = nil
                    return n
                }
            }
        }
        await loadShelves()
    }

    /// Re-reads one sticker (and its word) after the server changed it.
    func reload(stickerId: String) async {
        guard let fresh = try? await fetchSticker(id: stickerId) else { return }
        replace(stickerId) { old in
            var s = fresh
            s.lat = old.lat
            s.lng = old.lng
            return s
        }
    }

    /// Web `regenerateCardSection`. `onlyIfEmpty` = first fill of a missing section (free, like the web's
    /// AutoFillSections); otherwise a full rewrite of the section (Pro on the web).
    func fillSection(wordId: String, section: String, onlyIfEmpty: Bool) async -> Bool {
        struct Res: Decodable { let ok: Bool?; let filled: Bool? }
        let r = try? await NativeAPI.call("regenerateCardSection", [
            "word_id": wordId, "section": section, "only_if_empty": onlyIfEmpty,
        ], as: Res.self, timeout: 60)
        return r?.ok == true || r?.filled == true
    }

    /// Web `reportAndFixSection`: the AI finds which item is wrong (from the one-line note and what is
    /// on screen), checks it against the dictionary, and fixes only that item.
    struct ReportFix: Decodable {
        let fixed: Bool
        let item: String?
        let by: String?
    }

    func reportAndFix(wordId: String, candidates: [String], note: String) async throws -> ReportFix {
        try await NativeAPI.call("reportAndFixSection", [
            "word_id": wordId, "item": "auto", "candidates": Array(candidates.prefix(24)), "note": String(note.prefix(500)),
        ], as: ReportFix.self, timeout: 90)
    }

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

/// JSON `null` for a missing value (`JSONSerialization` bodies).
private func orNull(_ value: Any?) -> Any { value ?? NSNull() }
