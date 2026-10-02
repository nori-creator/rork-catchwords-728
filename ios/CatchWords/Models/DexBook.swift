import Foundation

/// Dex numbers (owner decision 2026-10-02, #3): the base 100 are No.001–100 (DexCatalog). Every other word the
/// learner catches gets No.101, 102, … in capture order — per learner and learning language, kept on this
/// device so a number never moves or comes back once given (no server change). Words are told apart by their
/// normalized headword, so catching the same word again keeps its number.
enum DexNumbering {
    static func storeKey(uid: String?, lang: String) -> String { "dex.numbers.\(uid ?? "guest").\(lang)" }

    private static func load(_ key: String) -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    /// sticker id → its No. Stickers are numbered oldest first (`taken_at`, then id); new numbers are saved.
    static func assign(_ stickers: [Sticker], lang: String, uid: String?) -> [String: Int] {
        let key = storeKey(uid: uid, lang: lang)
        var saved = load(key)
        var next = max(100, saved.values.max() ?? 100) + 1
        var changed = false
        var out: [String: Int] = [:]
        let ordered = stickers.sorted { $0.takenAt != $1.takenAt ? $0.takenAt < $1.takenAt : $0.id < $1.id }
        for s in ordered {
            let headword = s.word?.headword ?? ""
            if let base = DexCatalog.item(headword: headword, lang: lang)?.baseNo {
                out[s.id] = base
                continue
            }
            let h = DexCatalog.norm(headword, lang: lang)
            let k = h.isEmpty ? "id:\(s.id)" : h
            if let n = saved[k] {
                out[s.id] = n
            } else {
                saved[k] = next
                out[s.id] = next
                next += 1
                changed = true
            }
        }
        if changed { UserDefaults.standard.set(saved, forKey: key) }
        return out
    }

    /// The No. a word gets when it is caught now (the card shows it before the save).
    static func preview(headword: String, stickers: [Sticker], lang: String, uid: String?) -> Int {
        if let base = DexCatalog.item(headword: headword, lang: lang)?.baseNo { return base }
        _ = assign(stickers, lang: lang, uid: uid)
        let saved = load(storeKey(uid: uid, lang: lang))
        let h = DexCatalog.norm(headword, lang: lang)
        if !h.isEmpty, let n = saved[h] { return n }
        return max(100, saved.values.max() ?? 100) + 1
    }
}

/// One square of the dex gallery (`slotHTML`).
struct DexSlot: Identifiable {
    enum Kind {
        /// A caught word: its cut-out or photo, No., name.
        case caught(Sticker)
        /// Not caught yet: the grey silhouette, No. (base items only) and the first-character label.
        case shadow(DexItem)
        /// The landing target of a word that is not a shadow, before the light reaches it: an empty square.
        case pending
    }

    let id: String
    let no: Int?
    let kind: Kind
}

/// One category card of the gallery (`.dcat`): caught words (by No.), then the current shadows.
struct DexSection: Identifiable {
    let category: DexCategory
    let slots: [DexSlot]
    let caughtCount: Int
    var id: Int { category.no }
}

/// The category-shadow gallery (prototype `renderDex` grid, with the owner's 20 categories and shadows).
enum DexBook {
    /// Shadows shown per category (owner: 3–5; the first 5 items not caught yet, in catalog order).
    static let shadowCount = 5

    /// Where a caught word sits: its catalog item's category, else its category key's (`Sticker.categoryKey`).
    static func category(of s: Sticker, lang: String) -> Int {
        if let it = DexCatalog.item(headword: s.word?.headword, lang: lang) { return it.category }
        return DexCatalog.category(forKey: s.categoryKey)
    }

    /// The landing word, while its light is on the way (`filled` false: drawn as its shadow / an empty square)
    /// and after it filled the slot (`filled` true: caught, in the same place until the gallery is redrawn).
    struct Hold: Equatable {
        let stickerId: String
        var filled: Bool
    }

    static func sections(stickers: [Sticker], numbers: [String: Int], lang: String, hold: Hold?) -> [DexSection] {
        // One square per word (the prototype's addEntry keeps one entry per word): the newest sticker wins.
        var seen = Set<String>()
        var words: [Sticker] = []
        for s in stickers.sorted(by: { $0.takenAt > $1.takenAt }) {
            let h = DexCatalog.norm(s.word?.headword ?? "", lang: lang)
            let k = h.isEmpty ? "id:\(s.id)" : h
            if seen.insert(k).inserted { words.append(s) }
        }
        let held = hold.flatMap { h in words.first { $0.id == h.stickerId } }
        if let held { words.removeAll { $0.id == held.id } }

        var byCategory: [Int: [Sticker]] = [:]
        var caughtItems = Set<String>()
        for s in words {
            byCategory[category(of: s, lang: lang), default: []].append(s)
            if let it = DexCatalog.item(headword: s.word?.headword, lang: lang) { caughtItems.insert(it.id) }
        }
        let heldCategory = held.map { category(of: $0, lang: lang) }
        let heldItem = held.flatMap { DexCatalog.item(headword: $0.word?.headword, lang: lang) }

        return DexCatalog.categories.map { c in
            let caught = (byCategory[c.no] ?? []).sorted {
                let a = numbers[$0.id] ?? Int.max, b = numbers[$1.id] ?? Int.max
                return a != b ? a < b : $0.takenAt < $1.takenAt
            }
            var slots = caught.map { DexSlot(id: $0.id, no: numbers[$0.id], kind: .caught($0)) }
            var shadows = c.items.filter { !caughtItems.contains($0.id) }.prefix(shadowCount).map {
                DexSlot(id: "i:\($0.id)", no: $0.baseNo, kind: .shadow($0))
            }
            var count = caught.count
            if let held, heldCategory == c.no, let hold {
                let kind: DexSlot.Kind
                if let it = heldItem, let i = shadows.firstIndex(where: { $0.id == "i:\(it.id)" }) {
                    kind = hold.filled ? .caught(held) : .shadow(it)
                    shadows[i] = DexSlot(id: held.id, no: numbers[held.id] ?? it.baseNo, kind: kind)
                } else {
                    kind = hold.filled ? .caught(held) : .pending
                    slots.append(DexSlot(id: held.id, no: numbers[held.id], kind: kind))
                }
                if hold.filled { count += 1 }
            }
            slots += shadows
            return DexSection(category: c, slots: slots, caughtCount: count)
        }
    }

    /// Base items caught (the header's 影 n / 100).
    static func baseCaught(_ stickers: [Sticker], lang: String) -> Int {
        Set(stickers.compactMap { s -> String? in
            guard let it = DexCatalog.item(headword: s.word?.headword, lang: lang), it.baseNo != nil else { return nil }
            return it.id
        }).count
    }

    /// The shadow's label (owner decision): the headword's first character, then ？ for each further one
    /// (咖？, 珍？？？). English keeps its spaces and uses "?" (a full-width ？ after Latin letters reads as broken).
    static func shadowLabel(_ headword: String, lang: String) -> String {
        guard let first = headword.first else { return "" }
        let mark: Character = lang == "en" ? "?" : "？"
        return String(first) + String(headword.dropFirst().map { $0 == " " ? " " : mark })
    }
}
