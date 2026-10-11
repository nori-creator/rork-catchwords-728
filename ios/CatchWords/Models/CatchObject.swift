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
    /// Vision's instance under this object (nil = none, `fallbackBox`). The catch scan waits for that instance's
    /// outline (`CatchOutline.label`) before this object's tag comes up.
    var instance: Int? = nil

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
    /// Each object gets its OWN Vision instance (`assignInstances`): two objects whose points fall nearest the
    /// same instance used to get the same cut-out and box, so their outlines, hitboxes and tags sat on top of
    /// each other and only the top one could be tapped. The one left without an instance gets the box
    /// around its own point.
    static func build(candidates: [Candidate], masks: InstanceMasks?, photoSize: CGSize) -> [CatchObject] {
        let list = groups(candidates)
        let points = list.map { words -> CGPoint in
            let raw = words[0].point
            return CGPoint(x: min(1, max(0, (raw.first ?? 500) / 1000)),
                           y: min(1, max(0, (raw.count > 1 ? raw[1] : 500) / 1000)))
        }
        let labels: [Int?]
        if let masks {
            labels = assignInstances(points.map { masks.instances(near: $0) })
        } else {
            labels = Array(repeating: nil, count: points.count)
        }
        return list.enumerated().map { (i, words) -> CatchObject in
            let p = points[i]
            if let masks, let label = labels[i], let cut = masks.cut(instance: label) {
                return CatchObject(id: i, words: words, point: p, box: cut.box, cut: cut.image, instance: label)
            }
            return CatchObject(id: i, words: words, point: p, box: fallbackBox(at: p, photoSize: photoSize), cut: nil,
                               instance: labels[i])
        }
    }

    /// One Vision instance near an object's point, and how far it is (squared mask pixels; 0 = under the point).
    nonisolated struct InstanceHit: Equatable, Sendable {
        let label: Int
        let distance: Int
    }

    /// `ranked[i]`: the instances near object i, nearest first. Returns each object's instance, never the same
    /// one twice: the closest (object, instance) pairs are taken first (an object whose point lies ON an
    /// instance wins it over one that is merely near it; ties go to the earlier object, the server's order).
    /// nil = no free instance near that object (it gets `fallbackBox`).
    static func assignInstances(_ ranked: [[InstanceHit]]) -> [Int?] {
        var pairs: [(object: Int, hit: InstanceHit)] = []
        for (i, hits) in ranked.enumerated() {
            for h in hits { pairs.append((i, h)) }
        }
        pairs.sort { a, b in
            if a.hit.distance != b.hit.distance { return a.hit.distance < b.hit.distance }
            return a.object < b.object
        }
        var out = [Int?](repeating: nil, count: ranked.count)
        var taken = Set<Int>()
        for p in pairs where out[p.object] == nil && !taken.contains(p.hit.label) {
            out[p.object] = p.hit.label
            taken.insert(p.hit.label)
        }
        return out
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
