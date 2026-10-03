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
    /// This account's photos waiting in 「解析待ち」 (kept up to date by the queue itself).
    var pending: [PendingCatch] { PendingQueue.shared.items }
    /// sticker id → review state (memory badges). Stickers without a review get no badge.
    var reviews: [String: ReviewState] = [:]

    private let client = SupabaseClient.shared
    private var language: String { NativeAPI.targetLanguage }

    // MARK: Reader language (word_explanations)
    /// word id → the shared `words` row as stored, before choosing what this reader sees.
    private var sharedWords: [String: Word] = [:]
    /// word id → this reader's explanation (for `readerKey`).
    private var explanations: [String: ReaderLanguage.Explanation] = [:]
    /// word id → the meaning written in the reader's language (`getReaderMeanings`).
    private var readerMeanings: [String: String] = [:]
    /// The display language the two tables above were read for.
    private var readerKey = ""

    private static let baseColumns =
        "id,word_id,object_image_url,cutout_image_url,selfie_image_url,caption,location_name,lat,lng,taken_at,capture_type,shelf_key"
    /// Columns that came with later migrations (the web reads them the same way, in stages). If the
    /// server doesn't have one yet the dex still loads without it.
    nonisolated(unsafe) private static var optionalColumns = ["hero_role", "placeholder_image_url", "placeholder_credit"]
    private static var selectColumns: String {
        ([baseColumns] + optionalColumns + ["word:words(*)"]).joined(separator: ",")
    }

    /// Runs a stickers query; drops an optional column the server says it doesn't have and tries again.
    private func selectStickers(_ query: (String) -> String) async throws -> Data {
        while true {
            do {
                return try await client.rest("GET", query(Self.selectColumns))
            } catch {
                let text = "\(error)"
                guard let missing = Self.optionalColumns.first(where: { text.contains($0) }) else { throw error }
                Self.optionalColumns.removeAll { $0 == missing }
            }
        }
    }

    func load() async {
        PendingQueue.shared.reload()
        // Local guest (no account): an empty dex, not a skeleton that never ends.
        guard client.session != nil else {
            loadError = nil
            hasLoaded = true
            return
        }
        let uid = client.userId
        isLoading = true
        defer { isLoading = false }
        do {
            // Every page, like the web's listMyStickers (one capped read silently dropped the oldest
            // words of a big dex — and the cap counted other languages' words too).
            var rows: [Sticker] = []
            for page in 0..<Self.maxPages {
                let offset = page * Self.pageSize
                let data = try await selectStickers {
                    "stickers?select=\($0)&order=taken_at.desc,id.desc&limit=\(Self.pageSize)&offset=\(offset)"
                }
                let chunk = try SupabaseDate.decoder.decode([Sticker].self, from: data)
                rows += chunk
                if chunk.count < Self.pageSize { break }
            }
            // Signed out (or another account signed in) while this was loading: drop the result.
            guard client.userId == uid else { return }
            await loadAlbumHidden()
            await loadAlbumPlacements()
            guard client.userId == uid else { return }
            // Only the words of the language being learned (web listMyStickers → matchesTargetLanguage).
            stickers = present(rows.filter { $0.word?.matches(language) ?? true })
            loadError = nil
            hasLoaded = true
            await loadReviews()
            await signPaths(for: rows)
        } catch {
            guard client.userId == uid else { return }
            loadError = (error as? LocalizedError)?.errorDescription ?? L("図鑑を読み込めませんでした。")
        }
    }

    private static let pageSize = 500
    private static let maxPages = 40

    func reloadReviews() async { await loadReviews() }

    func sticker(id: String) -> Sticker? { stickers.first { $0.id == id } }

    /// When reviews come due (for おまかせ reminders).
    /// This learning language's cards only (R1).
    var upcomingDueTimes: [Date] {
        let mine = Set(stickers.map(\.id))
        return reviews.filter { mine.contains($0.key) }.values.compactMap(\.dueAt)
    }

    /// The photos the home album shows (the ones taken off the album stay in the dex only).
    var albumStickers: [Sticker] { stickers.filter { !albumHidden.contains($0.id) } }

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
        let uid = client.userId
        guard let data = try? await client.rest("GET", "reviews?select=id,sticker_id,ease,interval_days,repetitions,last_reviewed_at,due_at&limit=3000"),
              let rows = try? SupabaseDate.decoder.decode([ReviewState].self, from: data),
              client.userId == uid else { return }
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
            for p in [s.objectImageUrl, s.cutoutImageUrl, s.selfieImageUrl, s.placeholderImageUrl].compactMap({ $0 }) where signed[p] == nil {
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
    /// word upsert, extras merge (service role), first-catch event and
    /// duplicate guard as the web. Photos are uploaded first, in parallel; a failed cutout or
    /// selfie never blocks the catch.
    func save(_ draft: CatchDraft) async throws -> SaveOutcome {
        guard let uid = client.userId else { throw APIError.unauthorized }
        guard let card = draft.details else { throw APIError.message(L("カード生成に失敗しました")) }
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
            "part_of_speech": text("part_of_speech", c.pos.isEmpty ? NativeAPI.defaultPos : c.pos),
            "level": text("level", card.level),
            "category_key": text("category_key", card.categoryKey),
            "example_sentence": text("example_sentence", card.exampleSentence),
            "example_translation": text("example_translation", card.exampleTranslation),
        ]
        if let extras = raw?["extras"], case .object = extras { word["extras"] = extras.foundation }
        let caption = draft.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let data: [String: Any] = [
            "word": word,
            // Custom shelves are gone from the app (owner 2026-10-02): never ask the server to make one.
            "new_shelf": NSNull(),
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
        let data = try await selectStickers { "stickers?id=eq.\(id)&select=\($0)&limit=1" }
        guard let s = try SupabaseDate.decoder.decode([Sticker].self, from: data).first else { throw APIError.decoding }
        return present([s])[0]
    }

    // MARK: - Reader language

    /// Remembers the shared words and returns the stickers as this reader should see them.
    private func present(_ rows: [Sticker]) -> [Sticker] {
        for s in rows { if let w = s.word { sharedWords[s.wordId] = w } }
        if readerKey != L10n.lang {
            readerKey = L10n.lang
            explanations = [:]
            readerMeanings = [:]
        }
        let out = rows.map(applyReader)
        let missing = Set(rows.map(\.wordId)).subtracting(readerMeanings.keys)
        if !missing.isEmpty { Task { await loadReaderMeanings(Array(missing)) } }
        return out
    }

    private func applyReader(_ s: Sticker) -> Sticker {
        guard let shared = sharedWords[s.wordId] ?? s.word else { return s }
        var s = s
        s.word = ReaderLanguage.resolve(shared, explanation: explanations[s.wordId],
                                        readerMeaning: readerMeanings[s.wordId], reader: L10n.lang)
        return s
    }

    /// The display language changed: drop what was read for the old one and read again.
    func readerLanguageChanged() {
        guard readerKey != L10n.lang else { return }
        readerKey = L10n.lang
        explanations = [:]
        readerMeanings = [:]
        stickers = stickers.map(applyReader)
        let ids = Array(Set(stickers.map(\.wordId)))
        Task { await loadReaderMeanings(ids) }
    }

    /// web `getReaderMeanings`: the meanings written in the reader's language, 200 words at a time.
    private func loadReaderMeanings(_ ids: [String]) async {
        let lang = L10n.lang
        var i = 0
        while i < ids.count {
            let chunk = Array(ids[i..<min(i + 200, ids.count)])
            i += 200
            guard let got = try? await NativeAPI.call("getReaderMeanings", ["word_ids": chunk, "explain_lang": lang],
                                                      as: [String: String?].self, timeout: 30),
                  lang == L10n.lang else { continue }
            for id in chunk { readerMeanings[id] = (got[id] ?? nil) ?? "" }
        }
        guard lang == L10n.lang else { return }
        stickers = stickers.map(applyReader)
    }

    /// Words whose explanation is being written for this reader right now (the detail page shows
    /// those sections as filling). Owned by the store, so leaving the page does not cancel it.
    private(set) var generatingWords: Set<String> = []

    /// web StickerSheet: read this reader's explanation of the word; when there is none for exactly
    /// this reader, write one (`generateCard` → `updateWordExtras`, which files it under the reader's
    /// key on the server) in the background.
    func loadExplanation(wordId: String, target: String) async {
        struct Res: Decodable { let picked: ReaderLanguage.Explanation?; let unavailable: Bool? }
        let lang = L10n.lang
        let l1 = ReaderLanguage.l1(native: ReaderLanguage.native, target: target)
        guard let r = try? await NativeAPI.call("getWordExplanation", ["word_id": wordId, "explain_lang": lang, "l1": l1],
                                                as: Res.self, timeout: 20),
              lang == L10n.lang else { return }
        if let p = r.picked { explanations[wordId] = p } else { explanations.removeValue(forKey: wordId) }
        stickers = stickers.map { $0.wordId == wordId ? applyReader($0) : $0 }
        if r.unavailable == true { return }
        guard ReaderLanguage.needsGeneration(r.picked, lang: lang, l1: l1),
              let shared = sharedWords[wordId], !generatingWords.contains(wordId) else { return }
        generatingWords.insert(wordId)
        Task {
            defer { generatingWords.remove(wordId) }
            await generateExplanation(word: shared, shown: r.picked, lang: lang, l1: l1)
            guard lang == L10n.lang,
                  let again = try? await NativeAPI.call("getWordExplanation", ["word_id": wordId, "explain_lang": lang, "l1": l1],
                                                        as: Res.self, timeout: 20),
                  let p = again.picked else { return }
            explanations[wordId] = p
            stickers = stickers.map { $0.wordId == wordId ? applyReader($0) : $0 }
        }
    }

    private func generateExplanation(word: Word, shown: ReaderLanguage.Explanation?, lang: String, l1: String) async {
        guard let raw = try? await NativeAPI.call("generateCard", ["headword": word.headword, "targetLanguage": word.language ?? language], timeout: 60),
              let card = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              var fresh = card["extras"] as? [String: Any] else { return }
        // Keep what is already on screen and only fill what was empty (web keepShownFields), so the
        // chunks the learner is reading do not swap into different ones when the new notes arrive.
        if let shownRaw = await shownExtras(wordId: word.id, shown: shown, lang: lang, l1: l1) {
            let filled: (Any) -> Bool = { v in
                if let a = v as? [Any] { return !a.isEmpty }
                if let s = v as? String { return !s.trimmingCharacters(in: .whitespaces).isEmpty }
                return !(v is NSNull)
            }
            for (k, v) in shownRaw where filled(v) && k != "explain_lang" && k != "explain_l1" { fresh[k] = v }
        }
        var data: [String: Any] = ["word_id": word.id, "extras": fresh]
        // Shared columns are written only when they are really missing (web shouldWriteSharedColumns).
        let missing = [word.meaningJa, word.readingZhuyin ?? word.pinyin ?? "", word.exampleSentence ?? ""]
            .contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        if missing {
            var patch: [String: Any] = [:]
            for k in ["reading_zhuyin", "pinyin", "part_of_speech", "level", "example_sentence", "example_translation", "meaning_ja"] {
                if let v = card[k] as? String, !v.isEmpty { patch[k] = v }
            }
            if !patch.isEmpty { data["patch"] = patch }
        }
        _ = try? await NativeAPI.call("updateWordExtras", data, timeout: 30)
    }

    /// The extras the learner is looking at right now, raw (only when they are this reader's own or the
    /// shared ones written in the reader's language).
    private func shownExtras(wordId: String, shown: ReaderLanguage.Explanation?, lang: String, l1: String) async -> [String: Any]? {
        if shown != nil { return nil }
        guard let data = try? await client.rest("GET", "words?id=eq.\(wordId)&select=extras&limit=1"),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let ex = rows.first?["extras"] as? [String: Any] else { return nil }
        let mark = (ex["explain_lang"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        return mark == lang ? ex : nil
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
        if photo != nil && image == nil { throw APIError.message(L("記録に失敗しました")) }
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
        StickerPhoto.invalidate(owned.stickerId)
        if let fresh = try? await fetchSticker(id: owned.stickerId) {
            replace(owned.stickerId) { _ in fresh }
        }
        return (res.encounterCount ?? owned.encounterCount + 1, image != nil || cut != nil)
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

    /// Replaces the word's photo (web `replaceStickerPhoto`): the date and place you met it are kept;
    /// the old cut-out is dropped so a new one can be made from the new photo.
    func replacePhoto(_ sticker: Sticker, with image: UIImage) async throws {
        guard let uid = client.userId else { throw APIError.unauthorized }
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        guard let path = try await uploadJPEG(image, uid: uid, ts: ts, kind: "object") else {
            throw APIError.message(L("写真を読み込めませんでした。"))
        }
        _ = try await NativeAPI.call("replaceStickerPhoto", ["sticker_id": sticker.id, "object_path": path])
        ImageCache.shared.set(image, for: path)
        StickerPhoto.invalidate(sticker.id)
        await reload(stickerId: sticker.id)
        if let fresh = self.sticker(id: sticker.id) { await signPaths(for: [fresh]) }
    }

    /// Words already given an internet picture this launch (use-auto-hero.ts triedRef). A failed try is
    /// forgotten, so a word that only met a bad connection is not left without a picture for good.
    private var heroTried: Set<String> = []

    /// A word with no picture of its own gets one from the internet as its stand-in (web useAutoHero:
    /// 「単語の詳細の見出しの画像はネットからその単語を表す画像を添付して」). A word with a photo, a
    /// selfie or a stand-in already is never touched.
    func autoHero(_ sticker: Sticker) async {
        guard !sticker.hasOwnPhoto, sticker.placeholderImageUrl == nil, !heroTried.contains(sticker.id),
              let word = sticker.word else { return }
        heroTried.insert(sticker.id)
        do {
            guard let first = try await WebImages.search(headword: word.headword, meaning: word.meaningJa).first else { return }
            try await setPlaceholder(sticker, to: first)
        } catch {
            heroTried.remove(sticker.id)
        }
    }

    /// Makes an internet picture the word's stand-in (web setStickerPlaceholder). It is not the
    /// learner's photo, so a photo taken later still comes first.
    func setPlaceholder(_ sticker: Sticker, to candidate: WebImageCandidate) async throws {
        guard let uid = client.userId else { throw APIError.unauthorized }
        let image = try await WebImages.image(for: candidate)
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        guard let path = try await uploadJPEG(ImageTools.resized(image, maxSide: 1024), uid: uid, ts: ts, kind: "placeholder") else {
            throw APIError.decoding
        }
        _ = try await NativeAPI.call("setStickerPlaceholder", [
            "sticker_id": sticker.id, "placeholder_path": path, "placeholder_credit": candidate.creditPayload,
        ])
        ImageCache.shared.set(image, for: path)
        await reload(stickerId: sticker.id)
        if let fresh = self.sticker(id: sticker.id) { await signPaths(for: [fresh]) }
    }

    func addCutout(to sticker: Sticker, image: UIImage) async throws {
        guard let uid = client.userId else { throw APIError.unauthorized }
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        guard let path = await uploadPNG(image, uid: uid, ts: ts, kind: "cutout") else {
            throw APIError.message(L("切り抜きの保存に失敗しました。"))
        }
        _ = try await NativeAPI.call("attachStickerCutout", ["sticker_id": sticker.id, "cutout_path": path])
        ImageCache.shared.set(image, for: path)
        replace(sticker.id) { old in
            var s = old
            s.cutoutImageUrl = path
            return s
        }
    }

    /// A selfie taken later for a word that has none (web PhotoAddButtons → `attachStickerSelfie`).
    func addSelfie(to sticker: Sticker, image: UIImage) async throws {
        guard let uid = client.userId else { throw APIError.unauthorized }
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        guard let path = try await uploadJPEG(image, uid: uid, ts: ts, kind: "selfie") else {
            throw APIError.message(L("写真の保存に失敗しました。"))
        }
        _ = try await NativeAPI.call("attachStickerSelfie", ["sticker_id": sticker.id, "selfie_path": path])
        ImageCache.shared.set(image, for: path)
        replace(sticker.id) { old in
            var s = old
            s.selfieImageUrl = path
            return s
        }
    }

    /// Saves the sticker's one-line note (ひと言). Empty clears it.
    func updateCaption(_ sticker: Sticker, caption: String) async throws {
        // The server keeps 500 characters (stickers.functions.ts CAPTION_MAX).
        let trimmed = String(caption.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        _ = try await NativeAPI.call("updateStickerCaption", ["sticker_id": sticker.id, "caption": trimmed])
        // Change only the caption: rebuilding the sticker field by field dropped the chosen picture,
        // the stand-in image and its credit until the next reload.
        replace(sticker.id) { old in
            var s = old
            s.caption = trimmed.isEmpty ? nil : trimmed
            return s
        }
    }

    /// Points this sticker at another headword (setStickerHeadword). The shared `words` row is never rewritten.
    func setHeadword(_ sticker: Sticker, to raw: String) async throws {
        let head = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !head.isEmpty, head.count <= 60 else { throw APIError.message(L("単語を入れてください。")) }
        if sticker.word?.headword == head { return }
        do {
            // The server checks the language, reuses or creates the word row (its contents are
            // filled in afterwards by the detail page's auto-fill, as on the web).
            _ = try await NativeAPI.call("setStickerHeadword", ["sticker_id": sticker.id, "headword": head])
        } catch let APIError.server(_, message) where message.contains("NOT_TARGET_LANGUAGE") {
            throw APIError.message(NativeAPI.targetLanguage == "en" ? L("英語の単語を入れてください。")
                : NativeAPI.targetLanguage == "ja" ? L("日本語の単語を入れてください。") : L("繁体字（台湾華語）の単語を入れてください。"))
        }
        await reload(stickerId: sticker.id)
    }

    /// Dictionary error report → `entry_reports` (reports.functions.ts). Lands in the admin review queue.
    // MARK: - Home album (web album-hidden.functions.ts)

    /// Photos taken off the home album. They stay in the dex; only the album page skips them.
    var albumHidden: Set<String> = []

    func loadAlbumHidden() async {
        struct Res: Decodable { let ids: [String] }
        let uid = client.userId
        guard let r = try? await NativeAPI.call("listAlbumHidden", [:], as: Res.self), client.userId == uid else { return }
        albumHidden = Set(r.ids)
    }

    @discardableResult
    func setAlbumHidden(_ id: String, hidden: Bool) async -> Bool {
        // Update the page at once; roll back if the server refused.
        if hidden { albumHidden.insert(id) } else { albumHidden.remove(id) }
        struct Res: Decodable { let saved: Bool }
        let ok = (try? await NativeAPI.call("setAlbumHidden", ["sticker_id": id, "hidden": hidden], as: Res.self))?.saved ?? false
        if !ok {
            if hidden { albumHidden.remove(id) } else { albumHidden.insert(id) }
        }
        return ok
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
        let uid = client.userId
        guard let data = try? await client.rest("GET", "stickers?select=id,album_order,album_size,album_x,album_y,album_scale,album_rot&limit=3000"),
              let rows = try? JSONDecoder().decode([Row].self, from: data), client.userId == uid else { return }
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

    /// Which picture shows this word on its detail page (web setStickerHeroRole; nil = default order).
    func setHeroRole(_ sticker: Sticker, role: String?) async throws {
        struct Saved: Decodable { let saved: Bool }
        let res: Saved = try await NativeAPI.call("setStickerHeroRole", [
            "sticker_id": sticker.id, "hero_role": role.map { $0 as Any } ?? NSNull(),
        ], as: Saved.self)
        guard res.saved else { throw APIError.message(L("まだ保存できません。サーバの更新を待ってください。")) }
        replace(sticker.id) { old in
            var s = old
            s.heroRole = role
            return s
        }
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

    func reportAndFix(wordId: String, item: String = "auto", candidates: [String], note: String) async throws -> ReportFix {
        try await NativeAPI.call("reportAndFixSection", [
            "word_id": wordId, "item": item, "candidates": Array(candidates.prefix(24)), "note": String(note.prefix(500)),
        ], as: ReportFix.self, timeout: 90)
    }

    private func replace(_ id: String, _ transform: (Sticker) -> Sticker) {
        guard let i = stickers.firstIndex(where: { $0.id == id }) else { return }
        stickers[i] = transform(stickers[i])
    }

    /// Web `deleteSticker`: the row and its photo files (and thumbnails) go together.
    func delete(_ sticker: Sticker) async throws {
        _ = try await NativeAPI.call("deleteSticker", ["sticker_id": sticker.id])
        stickers.removeAll { $0.id == sticker.id }
    }

    func refreshPending() {
        PendingQueue.shared.reload()
    }

    /// Signing out / switching accounts: nothing of this account stays in memory for the next one.
    func reset() {
        stickers = []
        sharedWords = [:]
        explanations = [:]
        readerMeanings = [:]
        signed = [:]
        reviews = [:]
        albumHidden = []
        albumPlacements = [:]
        heroTried = []
        loadError = nil
        hasLoaded = false
        PendingQueue.shared.reload()
    }

    nonisolated static func enc(_ s: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+,()")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
}

/// JSON `null` for a missing value (`JSONSerialization` bodies).
private func orNull(_ value: Any?) -> Any { value ?? NSNull() }
