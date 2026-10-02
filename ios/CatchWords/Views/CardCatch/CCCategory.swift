import SwiftUI

/// The prototype's five card categories and their studio colours (docs/prototype/cats.js `CATS`).
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

    /// `CATS[cat].label` (the card's "category · pos" line).
    var label: String {
        switch self {
        case .food: L("飲み物・食べ物")
        case .plant: L("植物")
        case .animal: L("動物")
        case .city: L("街")
        case .thing: L("身の回り")
        }
    }

    /// PROVISIONAL — pending the owner's confirmation (the prototype's AI chose one of its five categories
    /// directly; the app's cards carry one of the 54 category keys instead):
    /// room 食べる → food; "animal" → animal; "plant" / "flower" / "nature" → plant; room 街 → city;
    /// everything else → thing.
    static func from(categoryKey key: String?) -> CCCategory {
        guard let key, !key.isEmpty else { return .thing }
        if Category.room(for: key) == .eat { return .food }
        if key == "animal" { return .animal }
        if key == "plant" || key == "flower" || key == "nature" { return .plant }
        if Category.room(for: key) == .town { return .city }
        return .thing
    }
}
