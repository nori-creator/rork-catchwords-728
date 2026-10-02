import SwiftUI

/// The prototype's five card colours (docs/prototype/cats.js `CATS`), used over the 20 dex categories (`forDex`).
enum CCCategory: String {
    case food, plant, animal, city, thing

    var b1: UInt32 {
        switch self {
        case .food: 0xFFE6A0
        case .plant: 0xD4F59A
        case .animal: 0xFFD3B8
        case .city: 0xCBE6FF
        case .thing: 0xE6DCFF
        }
    }

    var b2: UInt32 {
        switch self {
        case .food: 0xF2A93B
        case .plant: 0x7CC242
        case .animal: 0xE98352
        case .city: 0x5B9BE8
        case .thing: 0x9C86EA
        }
    }

    /// The card's studio colour for one of the 20 dex categories (DexCatalog).
    /// provisional, owner to choose A/B: (A) the prototype's 5 colours grouped over the 20 categories (this) or
    /// (B) 20 new colours. A: 1–5 → food, 15 → animal, 16–17 → plant, 12–14 → city, everything else → thing.
    static func forDex(_ no: Int) -> CCCategory {
        switch no {
        case 1...5: .food
        case 15: .animal
        case 16, 17: .plant
        case 12...14: .city
        default: .thing
        }
    }

    /// The colour for a word: its catalog item's category when the headword is in the catalog, else its
    /// category key's (DexCatalog.keyToCategory).
    static func from(headword: String?, categoryKey key: String?) -> CCCategory {
        forDex(DexCatalog.category(headword: headword, key: key, lang: NativeAPI.targetLanguage))
    }
}
