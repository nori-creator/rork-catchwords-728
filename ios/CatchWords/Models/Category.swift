import SwiftUI

/// The dex's 8 rooms (category.ts ROOM_KEYS) — shared keys with `scene_weights`.
nonisolated enum Room: String, CaseIterable, Identifiable, Sendable {
    case eat, town, house, wear, play, nature, people, marks

    var id: String { rawValue }

    var label: String {
        switch self {
        case .eat: L("食べる")
        case .town: L("街")
        case .house: L("家")
        case .wear: L("身につける")
        case .play: L("学び・遊び")
        case .nature: L("自然")
        case .people: L("人・体")
        case .marks: L("しるし")
        }
    }

    var accentHex: UInt32 {
        switch self {
        case .eat: 0xFF9F43
        case .town: 0x4EA8FF
        case .house: 0xD9B38C
        case .wear: 0xFF7EB6
        case .play: 0xA78BFA
        case .nature: 0x4ADE80
        case .people: 0xFBBF24
        case .marks: 0x94A3B8
        }
    }

    var symbol: String {
        switch self {
        case .eat: "fork.knife"
        case .town: "building.2"
        case .house: "house"
        case .wear: "tshirt"
        case .play: "book"
        case .nature: "leaf"
        case .people: "person"
        case .marks: "character.textbox"
        }
    }
}

extension Room {
    var accent: Color { Color(hex: accentHex) }
}

nonisolated enum Category {
    /// category.ts CATEGORY_META (54 keys → room + emoji).
    static let meta: [String: (room: Room, emoji: String)] = [
        "fruit": (.eat, "🍎"), "vegetable": (.eat, "🥬"), "drink": (.eat, "🥤"), "food": (.eat, "🍜"), "dessert": (.eat, "🍰"),
        "vehicle": (.town, "🚗"), "transport": (.town, "🚆"), "building": (.town, "🏢"), "street": (.town, "🛣️"),
        "sign": (.town, "🪧"), "shop": (.town, "🏪"),
        "home": (.house, "🏠"), "furniture": (.house, "🛋️"), "appliance": (.house, "🔌"),
        "kitchenware": (.house, "🍳"), "tool": (.house, "🔧"),
        "clothes": (.wear, "👕"), "accessory": (.wear, "🧢"), "shoes": (.wear, "👟"), "bag": (.wear, "👜"),
        "jewelry": (.wear, "💍"), "clothing_part": (.wear, "👔"),
        "stationery": (.play, "✏️"), "book": (.play, "📚"), "tech": (.play, "💻"), "gadget": (.play, "🖱️"),
        "toy": (.play, "🧸"), "game": (.play, "🎮"), "sport": (.play, "⚽"), "instrument": (.play, "🎸"),
        "art": (.play, "🎨"), "decoration": (.play, "🎊"),
        "animal": (.nature, "🐾"), "plant": (.nature, "🌿"), "flower": (.nature, "🌸"), "nature": (.nature, "🍃"),
        "weather": (.nature, "🌦️"), "sky": (.nature, "☀️"), "water": (.nature, "💧"), "mountain": (.nature, "⛰️"),
        "body": (.people, "🖐️"), "face": (.people, "😊"), "hand": (.people, "✋"), "person": (.people, "🧑"),
        "family": (.people, "👨‍👩‍👧"), "job": (.people, "💼"),
        "character": (.marks, "🔤"), "symbol": (.marks, "🔣"), "color": (.marks, "🎨"), "shape": (.marks, "🔷"),
        "money": (.marks, "💰"), "document": (.marks, "📄"), "medicine": (.marks, "💊"), "other": (.marks, "✨"),
    ]

    /// CATEGORY_META definition order (shelves are grouped by room in this order).
    static let orderedKeys: [String] = [
        "fruit", "vegetable", "drink", "food", "dessert",
        "vehicle", "transport", "building", "street", "sign", "shop",
        "home", "furniture", "appliance", "kitchenware", "tool",
        "clothes", "accessory", "shoes", "bag", "jewelry", "clothing_part",
        "stationery", "book", "tech", "gadget", "toy", "game", "sport", "instrument", "art", "decoration",
        "animal", "plant", "flower", "nature", "weather", "sky", "water", "mountain",
        "body", "face", "hand", "person", "family", "job",
        "character", "symbol", "color", "shape", "money", "document", "medicine", "other",
    ]

    /// i18n `cat.*` (ja).
    static var labels: [String: String] { [
        "fruit": L("果物"), "vegetable": L("野菜"), "drink": L("飲み物"), "food": L("食べ物"), "dessert": L("スイーツ"),
        "vehicle": L("乗り物"), "transport": L("交通"), "animal": L("動物"), "plant": L("植物"), "flower": L("花"),
        "building": L("建物"), "street": L("街並み"), "sign": L("看板"), "shop": L("お店"), "home": L("家"),
        "furniture": L("家具"), "appliance": L("家電"), "kitchenware": L("調理器具"), "tool": L("道具"), "clothes": L("服"),
        "accessory": L("アクセ"), "shoes": L("靴"), "bag": L("バッグ"), "jewelry": L("ジュエリー"), "stationery": L("文房具"),
        "book": L("本"), "tech": L("テック"), "gadget": L("ガジェット"), "toy": L("おもちゃ"), "game": L("ゲーム"),
        "sport": L("スポーツ"), "instrument": L("楽器"), "nature": L("自然"), "weather": L("天気"), "sky": L("空"),
        "water": L("水"), "mountain": L("山"), "body": L("体の部位"), "face": L("顔"), "hand": L("手"),
        "clothing_part": L("服の部分"), "person": L("人"), "family": L("家族"), "job": L("仕事"), "art": L("アート"),
        "decoration": L("装飾"), "character": L("文字"), "symbol": L("記号"), "color": L("色"), "shape": L("形"),
        "money": L("お金"), "document": L("書類"), "medicine": L("薬"), "other": L("その他"),
    ] }

    /// The learner's own shelves and renamed built-in shelves (`user_shelves`), set by DexStore.
    /// Built-in keys keep their room; new shelves live in the "mine" room.
    nonisolated(unsafe) static var custom: [String: UserShelf] = [:]

    static func key(for raw: String?) -> String {
        guard let raw, meta[raw] != nil || custom[raw] != nil else { return "other" }
        return raw
    }

    static func label(for key: String?) -> String {
        let k = Category.key(for: key)
        return custom[k]?.label ?? labels[k] ?? L("その他")
    }

    static func room(for key: String?) -> Room {
        guard let key, let m = meta[key] else { return .marks }
        return m.room
    }

    static func emoji(for key: String?) -> String {
        if let key, let c = custom[key], !c.emoji.isEmpty { return c.emoji }
        guard let key, let m = meta[key] else { return "✨" }
        return m.emoji
    }

    static func isBuiltin(_ key: String) -> Bool { meta[key] != nil }

    /// Built-in order, then the learner's own shelves (oldest first as loaded).
    static var allOrderedKeys: [String] {
        orderedKeys + custom.keys.filter { meta[$0] == nil }.sorted()
    }
}
