import SwiftUI
import UIKit
import CoreText

/// Design tokens ported from the web app's `styles.css` (light `:root` and dark `.dark`
/// "Deep Ocean", oklch → sRGB). Surface and text tokens follow the light/dark setting; the
/// camera keeps its deep-navy "machine" look and the home album stays paper in both.
enum Theme {
    static let background = Color(light: 0xF9FCFF, dark: 0x030915)
    static let backgroundDeep = Color(light: 0xEEF3F9, dark: 0x010510)
    static let card = Color(light: 0xFFFFFF, dark: 0x0A1423)
    static let surface2 = Color(light: 0xEDF2F8, dark: 0x16202F)
    static let secondary = Color(light: 0xEDF2F8, dark: 0x132032)
    static let accent = Color(light: 0xD8EEFF, dark: 0x112D55)
    static let primary = Color(hex: 0x0083FF)
    /// Blue used as text: brighter on dark surfaces so it doesn't sink (web: 暗い面では青を暗くしない).
    static let primaryInk = Color(light: 0x0053D4, dark: 0x6FB0FF)
    static let primaryBright = Color(hex: 0x2A9BFF)
    static let primaryDeep = Color(hex: 0x0060E0)
    static let foreground = Color(light: 0x0B121A, dark: 0xF2F6F8)
    static let muted = Color(light: 0x5C646F, dark: 0x99A6B8)
    static let border = Color(light: 0xE0E5EB, dark: 0x1D2635)
    static let gold = Color(hex: 0xF4B93C)
    static let cyan = Color(hex: 0x64E0FF)
    static let destructive = Color(light: 0xE62B34, dark: 0xFF5E63)
    static let ok = Color(hex: 0x00A95C)
    static let chunkV = Color(hex: 0xF9343C)
    static let chunkO = Color(hex: 0x0083FF)
    static let radius: CGFloat = 14

    /// Camera chrome / reward stage.
    static let navy = Color(hex: 0x0A1328)
    static let navyDeep = Color(hex: 0x060D1C)
    static let navyCard = Color(hex: 0x131E37)

    /// memory.ts 6 levels (<30, <50, <70, <85, <95, else).
    static let memoryLevels: [Color] = [
        Color(hex: 0xF9262A), Color(hex: 0xF87300), Color(hex: 0xE5A500),
        Color(hex: 0x46BC24), Color(hex: 0x00B777), Color(hex: 0x0083FF),
    ]

    static let brandGradient = LinearGradient(
        colors: [primaryBright, primaryDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    /// A colour that follows the light/dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }

    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Dates in the display language (L10n): 9月28日 / Sep 28 / 9月28日.
enum JPDate {
    nonisolated(unsafe) private static var cache: [String: DateFormatter] = [:]

    /// A formatter from a template (CLDR picks the right order and words for each language).
    private static func fmt(_ template: String, fixed: Bool = false) -> DateFormatter {
        let key = L10n.lang + "|" + template
        if let f = cache[key] { return f }
        let f = DateFormatter()
        f.locale = L10n.locale
        if fixed { f.dateFormat = template } else { f.setLocalizedDateFormatFromTemplate(template) }
        cache[key] = f
        return f
    }

    /// 9月28日 · Sep 28
    static func monthDay(_ date: Date) -> String { fmt("MMMd").string(from: date) }
    /// 2026年9月28日 18:17 · Sep 28, 2026, 18:17
    static func full(_ d: Date) -> String { fmt("yMMMdHHmm").string(from: d) }
    /// 09/28
    static func mmdd(_ d: Date) -> String { fmt("MM/dd", fixed: true).string(from: d) }
    /// 水曜日 · Wednesday
    static func weekday(_ d: Date) -> String { fmt("EEEE").string(from: d) }
    /// 9月28日(月) · Mon, Sep 28
    static func monthDayWeek(_ d: Date) -> String { fmt("MMMdE").string(from: d) }
    /// 9/28
    static func slash(_ d: Date) -> String { fmt("M/d", fixed: true).string(from: d) }
    /// 15:36
    static func time(_ d: Date) -> String { fmt("HH:mm", fixed: true).string(from: d) }
    /// 2026年9月 · September 2026
    static func yearMonth(_ d: Date) -> String { fmt("yMMMM").string(from: d) }
    /// SEPTEMBER (the book spine's decorative month name, always English)
    static func monthName(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM"
        return f.string(from: d).uppercased()
    }
    /// 日 月 火 … · S M T … in the display language, Sunday first.
    static var veryShortWeekdays: [String] { fmt("EEEEE").veryShortWeekdaySymbols ?? [] }
}

/// Bundled fonts: Zen Kurenaido (handwritten Japanese captions) and Caveat (handwritten Latin).
enum AppFont {
    static func registerAll() {
        for name in ["ZenKurenaido-Regular", "Caveat"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func hand(_ size: CGFloat) -> Font {
        resolve(["ZenKurenaido-Regular", "Zen Kurenaido"], size) ?? .system(size: size, design: .rounded)
    }

    static func script(_ size: CGFloat) -> Font {
        resolve(["Caveat-Regular", "CaveatRoman-Regular", "Caveat"], size) ?? .system(size: size, design: .serif).italic()
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    private static func resolve(_ names: [String], _ size: CGFloat) -> Font? {
        for name in names where UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return nil
    }
}
