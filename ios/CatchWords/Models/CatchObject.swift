import UIKit

/// Card catch: one object in the photo = the candidates that share `group` (the server's per-object
/// grouping; a candidate without a group is an object of its own), up to 3 words in the server's order.
/// Its tap point is the first word's `point`; its cut-out and box come from Vision's foreground instance
/// under that point (one mask request per photo, `InstanceMasks`).
nonisolated struct CatchObject: Identifiable, @unchecked Sendable {
    let id: Int
    let words: [Candidate]
    /// 0–1 of the photo, top-left origin.
    let point: CGPoint
    /// 0–1 of the photo: the cut-out's alpha bounding box, or `fallbackBox` when Vision found no instance.
    let box: CGRect
    /// The subject on transparency, cropped exactly to `box`; nil = the prototype's "no cutImg" path.
    let cut: UIImage?

    /// The prototype asks the AI for at most 4 objects (`askAI` → `.slice(0,4)`), 3 words each.
    static let maxObjects = 4
    static let maxWords = 3

    /// Candidates grouped per object, in order of first appearance.
    static func groups(_ items: [Candidate]) -> [[Candidate]] {
        var order: [String] = []
        var buckets: [String: [Candidate]] = [:]
        for (i, c) in items.enumerated() {
            let key = c.group.map { "g\($0)" } ?? "solo\(i)"
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(c)
        }
        return order.prefix(maxObjects).compactMap { key -> [Candidate]? in
            guard let list = buckets[key], !list.isEmpty else { return nil }
            return Array(list.prefix(maxWords))
        }
    }

    /// Heavy (renders masks): call off the main thread.
    static func build(candidates: [Candidate], masks: InstanceMasks?, photoSize: CGSize) -> [CatchObject] {
        groups(candidates).enumerated().map { (i, words) -> CatchObject in
            let raw = words[0].point
            let p = CGPoint(x: min(1, max(0, (raw.first ?? 500) / 1000)),
                            y: min(1, max(0, (raw.count > 1 ? raw[1] : 500) / 1000)))
            if let masks, let label = masks.instance(near: p), let cut = masks.cut(instance: label) {
                return CatchObject(id: i, words: words, point: p, box: cut.box, cut: cut.image)
            }
            return CatchObject(id: i, words: words, point: p, box: fallbackBox(at: p, photoSize: photoSize), cut: nil)
        }
    }

    /// No Vision instance under the point: a square box around it, 36% of the photo's shorter side,
    /// kept inside the photo (outlined as the prototype's rounded rect, `outlineEl` without cutImg).
    static func fallbackBox(at p: CGPoint, photoSize s: CGSize) -> CGRect {
        let side = 0.36 * min(s.width, s.height)
        let w = min(1, side / max(s.width, 1)), h = min(1, side / max(s.height, 1))
        let x = min(max(0, p.x - w / 2), 1 - w), y = min(max(0, p.y - h / 2), 1 - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
