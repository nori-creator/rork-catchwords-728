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
    nonisolated(unsafe) private static var table: [String: [String: String]] = {
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

    /// Whether `text` reads as the given display language (same rules as the web's
    /// `looksWrongForReader`, inverted): ja has kana; en has no CJK; zh-TW has Han and no kana.
    static func looksLike(_ text: String, _ code: String) -> Bool {
        var kana = 0, han = 0, latin = 0
        for u in text.unicodeScalars {
            switch u.value {
            case 0x3041...0x309F, 0x30A0...0x30FA: kana += 1
            case 0x3400...0x4DBF, 0x4E00...0x9FFF: han += 1
            case 0x41...0x5A, 0x61...0x7A: latin += 1
            default: break
            }
        }
        switch code {
        case "ja": return kana > 0 || (han == 0 && latin == 0)
        case "zh-TW": return kana == 0 && (han > 0 || latin == 0)
        default: return kana + han == 0 || latin > (kana + han) * 3
        }
    }

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

    struct Interpolation: StringInterpolationProtocol {
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
nonisolated func L(_ k: LKey) -> String {
    var out = L10n.text(k.key)
    for (i, a) in k.args.enumerated() {
        out = out.replacingOccurrences(of: "{\(i + 1)}", with: a)
    }
    return out
}

/// The same, in a given language (e.g. a notification written before the app opens).
nonisolated func L(_ k: LKey, in code: String) -> String {
    var out = L10n.text(k.key, in: code)
    for (i, a) in k.args.enumerated() {
        out = out.replacingOccurrences(of: "{\(i + 1)}", with: a)
    }
    return out
}
