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

    static func room(for key: String?) -> Room {
        guard let key, let m = meta[key] else { return .marks }
        return m.room
    }

    static func emoji(for key: String?) -> String {
        guard let key, let m = meta[key] else { return "✨" }
        return m.emoji
    }
}
