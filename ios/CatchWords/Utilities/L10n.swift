import Foundation
import Observation

/// Observed by every view that calls `L(...)`, so switching the display language redraws exactly
/// those views — in place, without losing the current tab or screen.
@Observable
nonisolated final class LanguageState: @unchecked Sendable {
    static let shared = LanguageState()
    var lang: String = {
        if let saved = UserDefaults.standard.string(forKey: L10n.storageKey), L10n.supported.contains(saved) { return saved }
        return L10n.deviceDefault
    }()
}

/// The app's display language (web `ui_language`): 日本語 / English / 繁體中文.
///
/// Every piece of text the app itself writes goes through `L(...)`. The key is the Japanese source
/// text; English and Traditional Chinese come from `Resources/Localization/strings.json`. The CI
/// check (`scripts/check_l10n.py`) fails the build if any Japanese text in the code is not passed
/// through `L` or has no translation — so a screen can never show two languages at once.
nonisolated enum L10n {
    static let supported = ["ja", "en", "zh-TW"]
    static let storageKey = "ui.lang"

    /// The current display language. Set from the profile (`ui_language`) and kept on the device so
    /// the sign-in screens already use it.
    static var lang: String {
        get { LanguageState.shared.lang }
        set { LanguageState.shared.lang = newValue }
    }

    /// First launch: the device's language when we support it, else English for non-Japanese devices.
    static var deviceDefault: String {
        for id in Locale.preferredLanguages {
            let l = id.lowercased()
            if l.hasPrefix("ja") { return "ja" }
            if l.hasPrefix("zh-hant") || l.hasPrefix("zh-tw") || l.hasPrefix("zh-hk") || l.hasPrefix("zh-mo") { return "zh-TW" }
            if l.hasPrefix("en") { return "en" }
        }
        return "ja"
    }

    static func set(_ code: String) {
        let c = normalize(code)
        lang = c
        UserDefaults.standard.set(c, forKey: storageKey)
    }

    static func normalize(_ code: String?) -> String {
        let c = (code ?? "").trimmingCharacters(in: .whitespaces)
        if supported.contains(c) { return c }
        if c.lowercased().hasPrefix("zh") { return "zh-TW" }
        if c.lowercased().hasPrefix("en") { return "en" }
        return "ja"
    }

    /// For dates and numbers in the display language.
    static var locale: Locale {
        switch lang {
        case "en": Locale(identifier: "en_US")
        case "zh-TW": Locale(identifier: "zh_Hant_TW")
        default: Locale(identifier: "ja_JP")
        }
    }

    /// key (Japanese) → [language code: text]
    private static let table: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "strings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]] else { return [:] }
        return obj
    }()

    /// A translation from the table, or nil when there is none (ja returns the key itself).
    static func translation(_ key: String, in code: String? = nil) -> String? {
        let c = code ?? lang
        if c == "ja" { return key }
        if let t = table[key]?[c], !t.isEmpty { return t }
        return nil
    }

    /// Text that came from outside the app (a server error, a database message). Shown only when it
    /// is written in the display language — a known server sentence is translated, anything else in
    /// another language is replaced by `fallback`, so a message never mixes languages on screen.
    static func readerSafe(_ text: String, fallback: String) -> String {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return fallback }
        if let t = translation(s), lang != "ja" { return t }
        return looksLike(s, lang) ? s : fallback
    }

    /// Whether `text` reads as the given display language (LanguageRules R7).
    static func looksLike(_ text: String, _ code: String) -> Bool { LanguageRules.readsAs(text, code) }

    static func text(_ key: String, in code: String? = nil) -> String {
        let c = code ?? lang
        if c == "ja" { return key }
        if let t = table[key]?[c], !t.isEmpty { return t }
        #if DEBUG
        print("⚠️ L10n missing [\(c)]: \(key)")
        #endif
        // Never mix languages on screen: English is the neutral fallback for a missing translation.
        return table[key]?["en"] ?? key
    }
}

/// A Japanese source string with its interpolated values (`L("\(n)日")`). The table key replaces each
/// interpolation with `{1}`, `{2}` … in order, so translations can move them around.
nonisolated struct LKey: ExpressibleByStringInterpolation, Sendable {
    var key: String
    var args: [String]

    init(stringLiteral value: String) {
        key = value
        args = []
    }

    init(stringInterpolation s: Interpolation) {
        key = s.key
        args = s.args
    }

    nonisolated struct Interpolation: StringInterpolationProtocol {
        var key = ""
        var args: [String] = []

        init(literalCapacity: Int, interpolationCount: Int) {}

        mutating func appendLiteral(_ literal: String) { key += literal }

        mutating func appendInterpolation<T>(_ value: T) {
            args.append("\(value)")
            key += "{\(args.count)}"
        }
    }
}

/// Text in the display language (see `L10n`).
nonisolated func L(_ k: LKey) -> String { L10n.fill(L10n.text(k.key), k.args, lang: L10n.lang) }

/// The same, in a given language (e.g. a notification written before the app opens).
nonisolated func L(_ k: LKey, in code: String) -> String { L10n.fill(L10n.text(k.key, in: code), k.args, lang: code) }

extension L10n {
    /// English counted nouns that follow a number ("{1} words"); "1 words" becomes "1 word".
    nonisolated private static let plurals = ["words": "word", "days": "day", "photos": "photo", "times": "time", "cards": "card",
                                  "stickers": "sticker", "items": "item", "reviews": "review", "books": "book",
                                  "minutes": "minute", "hours": "hour", "pages": "page", "entries": "entry"]

    /// Puts the values into `{1}`, `{2}` … (and, in English, makes "1 words" singular).
    nonisolated static func fill(_ template: String, _ args: [String], lang: String) -> String {
        var out = template
        for (i, a) in args.enumerated() {
            let slot = "{\(i + 1)}"
            if lang == "en", a == "1" {
                for (many, one) in plurals {
                    out = out.replacingOccurrences(of: slot + " " + many, with: slot + " " + one)
                }
            }
            out = out.replacingOccurrences(of: slot, with: a)
        }
        return out
    }
}
