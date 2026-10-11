import UIKit

/// One thing's outline for the catch scan (v10, owner 2026-10-11 「v10を承認する。アプリに実装して」): a Vision
/// foreground instance (`InstanceMasks.outlines`), traced along its pixel edges and smoothed the way the concept
/// films smoothed theirs (docs/design/catch-concepts/film/js/scan7.js `outlineOf`: Chaikin ×3, then an 11-point
/// moving average twice). Points are 0–1 of the photo, top-left origin, clockwise on screen; the last point joins
/// the first.
nonisolated struct CatchOutline: Sendable, Equatable {
    /// Vision's instance label (`CatchObject.instance` carries the same number).
    let label: Int
    /// Share of the photo the instance covers (0–1).
    let area: Double
    let points: [CGPoint]
}

/// Pure (no Vision): a label mask in, outlines out — so it is tested on made-up masks (CatchScanTests) and the
/// simulator previews draw real traced outlines.
nonisolated enum CatchOutlineTracer {
    /// The outlines of the `limit` largest instances (most pixels first), skipping instances under `minArea` of
    /// the photo. `mask`: one byte per pixel, row after row (`width` bytes each), 0 = background.
    static func outlines(mask: [UInt8], width: Int, height: Int, limit: Int = 4,
                         minArea: Double = 0.012) -> [CatchOutline] {
        guard width > 0, height > 0, mask.count >= width * height else { return [] }
        var counts = [Int](repeating: 0, count: 256)
        for i in 0..<(width * height) where mask[i] != 0 { counts[Int(mask[i])] += 1 }
        let total = Double(width * height)
        let order = (1..<256).filter { counts[$0] > 0 }
            .sorted { counts[$0] != counts[$1] ? counts[$0] > counts[$1] : $0 < $1 }
        var out: [CatchOutline] = []
        for label in order {
            if out.count >= limit { break }
            let share = Double(counts[label]) / total
            guard share >= minArea,
                  let ring = boundary(mask: mask, width: width, height: height, label: UInt8(label)) else { continue }
            var pts = simplify(ring.corners, epsilon: 0.75)
            guard pts.count >= 3 else { continue }
            pts = chaikin(pts, iterations: 3)
            pts = movingAverage(pts, radius: 5, passes: 2)
            let w = CGFloat(width), h = CGFloat(height)
            out.append(CatchOutline(label: label, area: share, points: pts.map { CGPoint(x: $0.x / w, y: $0.y / h) }))
        }
        return out
    }

    /// The largest 8-connected piece of `label` and its outer edge, walked along the pixel edges with the piece on
    /// the right (clockwise on screen) from the top-left corner of the piece's first pixel. `corners`: where the
    /// edge turns, in mask pixels (corner coordinates 0…width, 0…height). Holes inside the piece are ignored.
    static func boundary(mask: [UInt8], width w: Int, height h: Int, label: UInt8) -> (corners: [CGPoint], pixels: Int)? {
        guard w > 0, h > 0, mask.count >= w * h else { return nil }
        // 1. The pieces (8-connected); the largest is kept, with its first pixel in reading order.
        var piece = [Int32](repeating: 0, count: w * h)
        var stack: [Int] = []
        var bestStart = -1, bestSize = 0
        var bestID: Int32 = 0
        var id: Int32 = 0
        for i in 0..<(w * h) where mask[i] == label && piece[i] == 0 {
            id += 1
            piece[i] = id
            stack.append(i)
            var size = 0
            while let j = stack.popLast() {
                size += 1
                let jx = j % w, jy = j / w
                for dy in -1...1 {
                    let ny = jy + dy
                    guard ny >= 0, ny < h else { continue }
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = jx + dx
                        guard nx >= 0, nx < w else { continue }
                        let k = ny * w + nx
                        if mask[k] == label, piece[k] == 0 {
                            piece[k] = id
                            stack.append(k)
                        }
                    }
                }
            }
            if size > bestSize {
                bestSize = size
                bestStart = i
                bestID = id
            }
        }
        guard bestStart >= 0 else { return nil }
        let sx = bestStart % w, sy = bestStart / w
        func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && x < w && y >= 0 && y < h && piece[y * w + x] == bestID }
        // 2. Walk round it. Directions: east, south, west, north (clockwise on screen, y grows downward).
        let stepX = [1, 0, -1, 0], stepY = [0, 1, 0, -1]
        /// The pixels on the right and on the left of the edge that leaves corner (x, y) heading `d`.
        func sides(_ x: Int, _ y: Int, _ d: Int) -> (right: Bool, left: Bool) {
            switch d {
            case 0: return (inside(x, y), inside(x, y - 1))
            case 1: return (inside(x - 1, y), inside(x, y))
            case 2: return (inside(x - 1, y - 1), inside(x - 1, y))
            default: return (inside(x, y - 1), inside(x - 1, y - 1))
            }
        }
        var x = sx, y = sy, d = 0
        var corners = [CGPoint(x: sx, y: sy)]
        for _ in 0..<(4 * (w + 1) * (h + 1)) {
            x += stepX[d]
            y += stepY[d]
            // Only one way on keeps the piece on the right — except where two of its pixels touch at a corner:
            // there, turning left first walks round both (8-connected, as the pieces were found).
            var next = -1
            for turn in [3, 0, 1] {
                let o = (d + turn) % 4
                let s = sides(x, y, o)
                if s.right && !s.left {
                    next = o
                    break
                }
            }
            guard next >= 0 else { return nil }
            if x == sx, y == sy, next == 0 { return (corners, bestSize) }
            if next != d { corners.append(CGPoint(x: x, y: y)) }
            d = next
        }
        return nil
    }

    /// Douglas–Peucker on a closed ring (split at the point farthest from the first).
    static func simplify(_ pts: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard pts.count > 3 else { return pts }
        var far = 0
        var farD: CGFloat = -1
        for (i, p) in pts.enumerated() {
            let d = (p.x - pts[0].x) * (p.x - pts[0].x) + (p.y - pts[0].y) * (p.y - pts[0].y)
            if d > farD {
                farD = d
                far = i
            }
        }
        let a = douglasPeucker(Array(pts[0...far]), epsilon)
        let b = douglasPeucker(Array(pts[far...]) + [pts[0]], epsilon)
        return Array(a.dropLast()) + Array(b.dropLast())
    }

    private static func douglasPeucker(_ pts: [CGPoint], _ eps: CGFloat) -> [CGPoint] {
        guard pts.count > 2 else { return pts }
        var keep = [Bool](repeating: false, count: pts.count)
        keep[0] = true
        keep[pts.count - 1] = true
        var stack: [(Int, Int)] = [(0, pts.count - 1)]
        while let span = stack.popLast() {
            let (i, j) = span
            guard j > i + 1 else { continue }
            var bestD: CGFloat = -1
            var bestK = -1
            for k in (i + 1)..<j {
                let d = distance(pts[k], from: pts[i], to: pts[j])
                if d > bestD {
                    bestD = d
                    bestK = k
                }
            }
            if bestD > eps, bestK >= 0 {
                keep[bestK] = true
                stack.append((i, bestK))
                stack.append((bestK, j))
            }
        }
        return pts.indices.filter { keep[$0] }.map { pts[$0] }
    }

    private static func distance(_ p: CGPoint, from a: CGPoint, to b: CGPoint) -> CGFloat {
        let vx = b.x - a.x, vy = b.y - a.y
        let len = (vx * vx + vy * vy).squareRoot()
        guard len > 1e-9 else { return hypot(p.x - a.x, p.y - a.y) }
        return abs(vy * p.x - vx * p.y + b.x * a.y - b.y * a.x) / len
    }

    /// Chaikin corner cutting on a closed ring (each pass doubles the points and rounds the corners).
    static func chaikin(_ pts: [CGPoint], iterations: Int) -> [CGPoint] {
        var cur = pts
        for _ in 0..<iterations {
            let n = cur.count
            guard n > 2 else { return cur }
            var out: [CGPoint] = []
            out.reserveCapacity(2 * n)
            for i in 0..<n {
                let p = cur[i], q = cur[(i + 1) % n]
                out.append(CGPoint(x: 0.75 * p.x + 0.25 * q.x, y: 0.75 * p.y + 0.25 * q.y))
                out.append(CGPoint(x: 0.25 * p.x + 0.75 * q.x, y: 0.25 * p.y + 0.75 * q.y))
            }
            cur = out
        }
        return cur
    }

    /// The mean of each point and its `radius` neighbours on both sides, round a closed ring, `passes` times.
    static func movingAverage(_ pts: [CGPoint], radius: Int, passes: Int) -> [CGPoint] {
        let n = pts.count
        guard n > 2 * radius + 1 else { return pts }
        var cur = pts
        let span = CGFloat(2 * radius + 1)
        for _ in 0..<passes {
            var out = cur
            for i in 0..<n {
                var sx: CGFloat = 0, sy: CGFloat = 0
                for d in -radius...radius {
                    let p = cur[(i + d + n) % n]
                    sx += p.x
                    sy += p.y
                }
                out[i] = CGPoint(x: sx / span, y: sy / span)
            }
            cur = out
        }
        return cur
    }
}
