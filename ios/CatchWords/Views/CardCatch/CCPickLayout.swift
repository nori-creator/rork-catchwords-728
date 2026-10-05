import UIKit

/// Card catch `showPick`: where each object's `.tag` sits, and which object a tap on the photo means.
/// The prototype puts every tag at its object's top centre; with several objects close together (or two of
/// the same thing) the tags covered each other and some objects could not be chosen. The look stays the
/// prototype's: a tag only moves (up or down) when it would overlap another one.
enum CCPickLayout {
    /// The tags' bottom edge stays between these (design points): below the pill, above 撮り直す.
    static let minBottom: CGFloat = 170
    static let maxBottom: CGFloat = CCSpace.h - 110
    /// The prototype's horizontal clamp of the tag's centre.
    static let sideClamp: CGFloat = 60
    /// Space kept between two tags.
    static let gap: CGFloat = 6

    /// `.tag`'s size for a name: 8 + dot 10 + 7 + text + 12 wide, 7 + line + 7 high (CardCatchView.tag).
    static func tagSize(name: String) -> CGSize {
        let font = UIFont.systemFont(ofSize: 13, weight: .heavy)
        let w = (name as NSString).size(withAttributes: [.font: font]).width
        return CGSize(width: ceil(w) + 37, height: ceil(max(10, font.lineHeight)) + 14)
    }

    /// The tag's own place (its bottom centre), as the prototype puts it: the object's top centre.
    static func anchor(for rect: CGRect, size: CGSize) -> CGPoint {
        let side = max(sideClamp, size.width / 2 + 8)
        let x = side * 2 > CCSpace.w ? CCSpace.w / 2 : max(side, min(CCSpace.w - side, rect.midX))
        return CGPoint(x: x, y: max(minBottom, rect.minY + 6))
    }

    /// The rect a tag covers when its bottom centre is at `p`.
    static func frame(bottomCenter p: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: p.x - size.width / 2, y: p.y - size.height, width: size.width, height: size.height)
    }

    /// Every tag's bottom centre. Tags are placed in the objects' order (the first keeps its own place); a tag
    /// that would overlap one already placed moves to the nearest free place just above or below the tags it
    /// meets, inside `minBottom…maxBottom`. When nothing is free it stays where the prototype puts it.
    static func layout(rects: [CGRect], sizes: [CGSize]) -> [CGPoint] {
        var placed: [CGRect] = []
        var out: [CGPoint] = []
        for (i, r) in rects.enumerated() {
            let size = i < sizes.count ? sizes[i] : CGSize(width: 80, height: 30)
            let a = anchor(for: r, size: size)
            func free(_ y: CGFloat) -> Bool {
                let f = frame(bottomCenter: CGPoint(x: a.x, y: y), size: size).insetBy(dx: -gap / 2, dy: -gap / 2)
                return !placed.contains { $0.insetBy(dx: -gap / 2, dy: -gap / 2).intersects(f) }
            }
            var y = a.y
            if !free(y) {
                var options: [CGFloat] = []
                for p in placed {
                    options.append(p.maxY + gap + 1 + size.height)   // just below that tag
                    options.append(p.minY - gap - 1)                 // just above it
                }
                let low = minBottom, high = max(maxBottom, a.y)
                let best = options
                    .filter { $0 >= low && $0 <= high && free($0) }
                    .min { abs($0 - a.y) < abs($1 - a.y) }
                if let best { y = best }
            }
            let p = CGPoint(x: a.x, y: y)
            out.append(p)
            placed.append(frame(bottomCenter: p, size: size))
        }
        return out
    }

    /// The object a tap at `p` (design points) means: of the objects whose box holds the point, the smallest
    /// (a small thing in front of a big one stays reachable); between boxes of about the same size, the one
    /// whose centre is nearest. nil = the tap is on no object.
    static func object(at p: CGPoint, rects: [CGRect]) -> Int? {
        let hits = rects.indices.filter { rects[$0].contains(p) }
        return hits.min { a, b in
            let ra = rects[a], rb = rects[b]
            let areaA = ra.width * ra.height, areaB = rb.width * rb.height
            if abs(areaA - areaB) > 0.1 * max(areaA, areaB) { return areaA < areaB }
            return distance(p, ra) < distance(p, rb)
        }
    }

    private static func distance(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        let dx = p.x - r.midX, dy = p.y - r.midY
        return dx * dx + dy * dy
    }
}
