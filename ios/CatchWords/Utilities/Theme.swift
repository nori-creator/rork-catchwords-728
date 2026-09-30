import SwiftUI
import UIKit
import CoreText

/// Design tokens ported from the web app's `styles.css` (dark theme, oklch → sRGB).
enum Theme {
    static let background = Color(hex: 0x060D1A)
    static let backgroundDeep = Color(hex: 0x02060F)
    static let card = Color(hex: 0x0D1726)
    static let surface2 = Color(hex: 0x16223A)
    static let secondary = Color(hex: 0x132032)
    static let accent = Color(hex: 0x112D55)
    static let primary = Color(hex: 0x378EFF)
    static let primaryBright = Color(hex: 0x0A84FF)
    static let primaryDeep = Color(hex: 0x0040D0)
    static let foreground = Color(hex: 0xF2F6F8)
    static let muted = Color(hex: 0x99A6B8)
    static let border = Color.white.opacity(0.10)
    static let gold = Color(hex: 0xF4B93C)
    static let cyan = Color(hex: 0x64E0FF)
    static let destructive = Color(hex: 0xFF5E63)
    static let ok = Color(hex: 0x2FC183)
    static let chunkV = Color(hex: 0xFF8C7A)
    static let chunkO = Color(hex: 0x7EB8F0)
    static let radius: CGFloat = 14

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
