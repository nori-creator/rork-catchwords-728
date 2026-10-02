#if DEBUG
import Foundation
import CoreGraphics
import CoreText
import ImageIO

/// Made-up pictures for the demo backend: a soft colour from the path's hash with a large emoji and the
/// headword, so every photo looks different in screenshots. Drawn with Core Graphics / Core Text (safe off
/// the main thread) and cached.
nonisolated enum DemoImages {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: Data] = [:]

    static func png(seed: String, emoji: String, text: String, transparent: Bool, size: Int = 512) -> Data {
        let key = "\(seed)|\(emoji)|\(text)|\(transparent)|\(size)"
        lock.lock()
        let hit = cache[key]
        lock.unlock()
        if let hit { return hit }
        let data = draw(seed: seed, emoji: emoji, text: text, transparent: transparent, size: size)
        lock.lock()
        cache[key] = data
        lock.unlock()
        return data
    }

    private static func draw(seed: String, emoji: String, text: String, transparent: Bool, size: Int) -> Data {
        let side = CGFloat(size)
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return Data() }
        let hue = Double(hash(seed) % 360) / 360.0
        if !transparent {
            let bg = rgb(hue: hue, saturation: 0.32, brightness: 0.96)
            ctx.setFillColor(CGColor(red: bg.0, green: bg.1, blue: bg.2, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let disc = rgb(hue: hue, saturation: 0.18, brightness: 1.0)
            ctx.setFillColor(CGColor(red: disc.0, green: disc.1, blue: disc.2, alpha: 1))
            let d = side * 0.66
            ctx.fillEllipse(in: CGRect(x: (side - d) / 2, y: (side - d) / 2 + side * 0.04, width: d, height: d))
        }
        let mark = emoji.isEmpty ? "📷" : emoji
        let emojiCenterY = transparent ? side / 2 : side * 0.56
        drawText(mark, in: ctx, fontSize: side * (transparent ? 0.56 : 0.40), center: CGPoint(x: side / 2, y: emojiCenterY),
                 color: CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        if !transparent && !text.isEmpty {
            let ink = rgb(hue: hue, saturation: 0.55, brightness: 0.35)
            let fontSize = text.count > 8 ? side * 0.07 : side * 0.10
            drawText(text, in: ctx, fontSize: fontSize, center: CGPoint(x: side / 2, y: side * 0.13),
                     color: CGColor(red: ink.0, green: ink.1, blue: ink.2, alpha: 1))
        }
        guard let image = ctx.makeImage() else { return Data() }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out as CFMutableData, "public.png" as CFString, 1, nil) else { return Data() }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return Data() }
        return out as Data
    }

    /// One centred line of text (Core Text falls back to the emoji / CJK fonts by itself).
    private static func drawText(_ string: String, in ctx: CGContext, fontSize: CGFloat, center: CGPoint, color: CGColor) {
        let font: CTFont = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font,
            NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): color,
        ]
        let attributed = NSAttributedString(string: string, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: center.x - bounds.width / 2 - bounds.minX, y: center.y - bounds.height / 2 - bounds.minY)
        CTLineDraw(line, ctx)
    }

    /// djb2 over the scalars: the same path always gets the same colour.
    private static func hash(_ s: String) -> Int {
        var h: UInt64 = 5381
        for u in s.unicodeScalars {
            h = (h &* 33) &+ UInt64(u.value)
        }
        return Int(h % 100_000)
    }

    private static func rgb(hue: Double, saturation: Double, brightness: Double) -> (CGFloat, CGFloat, CGFloat) {
        let h = (hue - floor(hue)) * 6
        let i = Int(h) % 6
        let f = h - floor(h)
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * f)
        let t = brightness * (1 - saturation * (1 - f))
        let r: Double
        let g: Double
        let b: Double
        switch i {
        case 0: r = brightness; g = t; b = p
        case 1: r = q; g = brightness; b = p
        case 2: r = p; g = brightness; b = t
        case 3: r = p; g = q; b = brightness
        case 4: r = t; g = p; b = brightness
        default: r = brightness; g = p; b = q
        }
        return (CGFloat(r), CGFloat(g), CGFloat(b))
    }
}
#endif
