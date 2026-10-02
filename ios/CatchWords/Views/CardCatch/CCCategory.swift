import SwiftUI

/// The card's studio colour, one per dex category (owner 2026-10-02: "each category gets its own colour, 20
/// different colours"). b1 = the light centre tone, b2 = the deep edge tone, used exactly like the prototype's
/// `CATS` b1/b2 (docs/prototype/cats.js). Swatches: docs/prototype/palette20.png.
struct CCCategory: Equatable {
    /// DexCatalog category number, 1…20.
    let no: Int

    /// No. → (b1, b2). Categories 2, 9, 13, 15 and 16 keep the prototype's own food / thing / city /
    /// animal / plant colours.
    private static let palette: [Int: (UInt32, UInt32)] = [
        1: (0xF6E3CF, 0xC58B55),   // 飲み物
        2: (0xFFE6A0, 0xF2A93B),   // 料理
        3: (0xFFD5CC, 0xE9553F),   // 果物・野菜
        4: (0xFFE0EC, 0xE97AA8),   // パン・お菓子
        5: (0xD5F2EE, 0x3FAE9F),   // 食器・台所
        6: (0xEEE3D6, 0xA57E58),   // 家具・部屋
        7: (0xDCE1EC, 0x6A7896),   // 家電・電子機器
        8: (0xFFF3B8, 0xE2B81F),   // 文房具・本
        9: (0xE6DCFF, 0x9C86EA),   // 服
        10: (0xF8DDF4, 0xC462B6),  // 身につける物
        11: (0xEEF6CC, 0xA6BE3A),  // 日用品
        12: (0xDDE0FF, 0x5E6BE0),  // 乗り物
        13: (0xCBE6FF, 0x5B9BE8),  // 建物・お店
        14: (0xE2E5E9, 0x7F8893),  // 街の物
        15: (0xFFD3B8, 0xE98352),  // 動物
        16: (0xD4F59A, 0x7CC242),  // 植物・花
        17: (0xCDEFF5, 0x2FA3B8),  // 自然・空
        18: (0xFFDDE2, 0xE0607A),  // 人・体
        19: (0xDDF5E6, 0x41B36B),  // 遊び・趣味
        20: (0xEBDDF0, 0x8E5BA6),  // その他
    ]

    var b1: UInt32 { (Self.palette[no] ?? Self.palette[20]!).0 }
    var b2: UInt32 { (Self.palette[no] ?? Self.palette[20]!).1 }

    /// The card's studio colour for one of the 20 dex categories (DexCatalog).
    static func forDex(_ no: Int) -> CCCategory { CCCategory(no: no) }

    /// The colour for a word: its catalog item's category when the headword is in the catalog, else its
    /// category key's (DexCatalog.keyToCategory).
    static func from(headword: String?, categoryKey key: String?) -> CCCategory {
        forDex(DexCatalog.category(headword: headword, key: key, lang: NativeAPI.targetLanguage))
    }
}
