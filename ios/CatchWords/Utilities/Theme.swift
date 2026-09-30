import SwiftUI
import UIKit
import CoreText

/// Design tokens ported from the web app's `styles.css` (light theme `:root`, oklch → sRGB).
/// The camera keeps the deep-navy "machine" look (`.dark` / camera chrome).
enum Theme {
    static let background = Color(hex: 0xF9FCFF)
    static let backgroundDeep = Color(hex: 0xEEF3F9)
    static let card = Color.white
    static let surface2 = Color(hex: 0xEDF2F8)
    static let secondary = Color(hex: 0xEDF2F8)
    static let accent = Color(hex: 0xD8EEFF)
    static let primary = Color(hex: 0x0083FF)
    static let primaryInk = Color(hex: 0x0053D4)
    static let primaryBright = Color(hex: 0x2A9BFF)
    static let primaryDeep = Color(hex: 0x0060E0)
    static let foreground = Color(hex: 0x0B121A)
    static let muted = Color(hex: 0x5C646F)
    static let border = Color(hex: 0xE0E5EB)
    static let gold = Color(hex: 0xF4B93C)
    static let cyan = Color(hex: 0x64E0FF)
    static let destructive = Color(hex: 0xE62B34)
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

enum JPDate {
    private static let md: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日"
        return f
    }()

    static func monthDay(_ date: Date) -> String { md.string(from: date) }

    private static func make(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = format
        return f
    }

    private static let weekdayF = make("EEEE")
    private static let mdwF = make("M月d日(E)")
    private static let slashF = make("M/d")
    private static let timeF = make("HH:mm")
    private static let monthEN: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM"
        return f
    }()

    /// 水曜日
    static func weekday(_ d: Date) -> String { weekdayF.string(from: d) }
    /// 9月28日(月)
    static func monthDayWeek(_ d: Date) -> String { mdwF.string(from: d) }
    /// 9/28
    static func slash(_ d: Date) -> String { slashF.string(from: d) }
    /// 15:36
    static func time(_ d: Date) -> String { timeF.string(from: d) }
    /// SEPTEMBER
    static func monthName(_ d: Date) -> String { monthEN.string(from: d).uppercased() }
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
