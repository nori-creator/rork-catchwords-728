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
        if isOwnText(s) { return s }  // the app's own sentence, already in this language
        if let t = translation(s), lang != "ja" { return t }
        if lang != "ja", let t = knownServerSentence(s) { return t }
        return looksLike(s, lang) ? s : fallback
    }

    /// The server's Japanese sentences that vary in detail (counts, names) — by what they say (web errors.ts).
    private static func knownServerSentence(_ s: String) -> String? {
        if s.contains("利用上限") { return L("1日の利用上限に達しました。24時間以内に自動で回復します。") }  // l10n-ignore (matching the server text)
        if s.contains("Pro 限定") || s.contains("Pro限定") { return L("この機能は Pro 限定です。") }  // l10n-ignore (matching the server text)
        if s.contains("権限がありません") { return L("この操作の権限がありません。") }  // l10n-ignore (matching the server text)
        if s.contains("見つかりません") { return L("見つかりませんでした。") }  // l10n-ignore (matching the server text)
        if s.contains("もう一度") { return L("うまくいきませんでした。もう一度お試しください。") }  // l10n-ignore (matching the server text)
        return nil
    }

    /// Whether `s` is one of the app's own sentences in the display language (a table value, with any
    /// `{n}` filled in) — e.g. an error the app wrote with `L(...)` and passed through `APIError`.
    /// Never true for text in another script than the screen's (so server text can't pass as ours).
    static func isOwnText(_ s: String) -> Bool {
        let c = lang
        let n = LanguageRules.counts(s)
        if c == "en", n.cjk > 0 { return false }
        if c == "zh-TW", n.kana > 0 { return false }
        guard let own = ownText[c] else { return false }
        if own.values.contains(s) { return true }
        let range = NSRange(s.startIndex..., in: s)
        return own.patterns.contains { $0.firstMatch(in: s, range: range) != nil }
    }

    /// Per language: every table value, and every template with `{n}` as an anchored pattern (a filled
    /// value is 1–40 characters on one line). English templates also match their singular form ("1 word").
    /// Built once (a `static let` is initialised thread-safely).
    private static let ownText: [String: (values: Set<String>, patterns: [NSRegularExpression])] = {
        var out: [String: (values: Set<String>, patterns: [NSRegularExpression])] = [:]
        for c in supported {
            let templates = c == "ja" ? Array(table.keys) : table.values.compactMap { $0[c] }
            var forms = templates
            if c == "en" {
                for t in templates {
                    var one = t
                    for (many, single) in plurals { one = one.replacingOccurrences(of: "} " + many, with: "} " + single) }
                    if one != t { forms.append(one) }
                }
            }
            let patterns: [NSRegularExpression] = forms.filter {
                // Only templates with enough fixed text to identify them ("{1}、{2}" would match anything).
                $0.contains("{1}") && $0.replacingOccurrences(of: "\\{[0-9]\\}", with: "", options: .regularExpression).count >= 4
            }.compactMap { t in
                // Placeholders become a marker first, so escaping can't touch them.
                let marked = t.replacingOccurrences(of: "\\{[0-9]\\}", with: "\u{1}", options: .regularExpression)
                let pattern = NSRegularExpression.escapedPattern(for: marked).replacingOccurrences(of: "\u{1}", with: "[^\\n]{1,40}")
                return try? NSRegularExpression(pattern: "^" + pattern + "$")
            }
            out[c] = (Set(templates), patterns)
        }
        return out
    }()

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
