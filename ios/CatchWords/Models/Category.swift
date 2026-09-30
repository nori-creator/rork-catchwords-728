import SwiftUI

/// The dex's 8 rooms (category.ts ROOM_KEYS) — shared keys with `scene_weights`.
nonisolated enum Room: String, CaseIterable, Identifiable, Sendable {
    case eat, town, house, wear, play, nature, people, marks

    var id: String { rawValue }

    var label: String {
        switch self {
        case .eat: "食べる"
        case .town: "街"
        case .house: "家"
        case .wear: "身につける"
        case .play: "学び・遊び"
        case .nature: "自然"
        case .people: "人・体"
        case .marks: "しるし"
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

    static var allKeys: [String] { meta.keys.sorted() }

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
    static let labels: [String: String] = [
        "fruit": "果物", "vegetable": "野菜", "drink": "飲み物", "food": "食べ物", "dessert": "スイーツ",
        "vehicle": "乗り物", "transport": "交通", "animal": "動物", "plant": "植物", "flower": "花",
        "building": "建物", "street": "街並み", "sign": "看板", "shop": "お店", "home": "家",
        "furniture": "家具", "appliance": "家電", "kitchenware": "調理器具", "tool": "道具", "clothes": "服",
        "accessory": "アクセ", "shoes": "靴", "bag": "バッグ", "jewelry": "ジュエリー", "stationery": "文房具",
        "book": "本", "tech": "テック", "gadget": "ガジェット", "toy": "おもちゃ", "game": "ゲーム",
        "sport": "スポーツ", "instrument": "楽器", "nature": "自然", "weather": "天気", "sky": "空",
        "water": "水", "mountain": "山", "body": "体の部位", "face": "顔", "hand": "手",
        "clothing_part": "服の部分", "person": "人", "family": "家族", "job": "仕事", "art": "アート",
        "decoration": "装飾", "character": "文字", "symbol": "記号", "color": "色", "shape": "形",
        "money": "お金", "document": "書類", "medicine": "薬", "other": "その他",
    ]

    static func key(for raw: String?) -> String {
        guard let raw, meta[raw] != nil else { return "other" }
        return raw
    }

    static func label(for key: String?) -> String { labels[Category.key(for: key)] ?? "その他" }

    static func room(for key: String?) -> Room {
        guard let key, let m = meta[key] else { return .marks }
        return m.room
    }

    static func emoji(for key: String?) -> String {
        guard let key, let m = meta[key] else { return "✨" }
        return m.emoji
    }
}
