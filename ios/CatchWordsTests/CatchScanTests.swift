import XCTest
@testable import CatchWords

/// The catch scan, v10 (owner 2026-10-11 「v10を承認する。アプリに実装して」). Pure logic: the outline tracer on
/// made-up masks, and the pen's clock against the approved film's own times (docs/design/catch-concepts/audio/
/// cues10.json, `O10f` and `O10z`; the film's shutter is at 0.72 s, its bracket comes up at 0.98 s).
/// Run on its own by .github/workflows/ios-check.yml.
@MainActor
final class CatchScanTests: XCTestCase {
    private func mask(_ w: Int, _ h: Int, _ fill: (Int, Int) -> UInt8) -> [UInt8] {
        var m = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w { m[y * w + x] = fill(x, y) } }
        return m
    }

    private func shoelace(_ pts: [CGPoint]) -> CGFloat {
        var s: CGFloat = 0
        for i in pts.indices {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            s += a.x * b.y - b.x * a.y
        }
        return s / 2
    }

    // MARK: The tracer

    func testRectangleIsWalkedClockwiseFromItsTopLeftCorner() throws {
        let m = mask(20, 16) { x, y in (5..<15).contains(x) && (3..<11).contains(y) ? 7 : 0 }
        let ring = try XCTUnwrap(CatchOutlineTracer.boundary(mask: m, width: 20, height: 16, label: 7))
        XCTAssertEqual(ring.corners, [CGPoint(x: 5, y: 3), CGPoint(x: 15, y: 3), CGPoint(x: 15, y: 11), CGPoint(x: 5, y: 11)])
        XCTAssertEqual(ring.pixels, 80)
        XCTAssertEqual(shoelace(ring.corners), 80, "clockwise on screen (y grows downward) is a positive area")
    }

    func testPixelsTouchingAtACornerAreOnePiece() throws {
        let m = mask(4, 4) { x, y in (x, y) == (1, 1) || (x, y) == (2, 2) ? 1 : 0 }
        let ring = try XCTUnwrap(CatchOutlineTracer.boundary(mask: m, width: 4, height: 4, label: 1))
        XCTAssertEqual(ring.pixels, 2)
        XCTAssertEqual(ring.corners.count, 8, "the walk goes round both pixels")
    }

    func testTheLargestPieceIsTraced() throws {
        let m = mask(30, 10) { x, y in
            ((1..<4).contains(x) && (1..<4).contains(y)) || ((10..<25).contains(x) && (2..<9).contains(y)) ? 2 : 0
        }
        let ring = try XCTUnwrap(CatchOutlineTracer.boundary(mask: m, width: 30, height: 10, label: 2))
        XCTAssertEqual(ring.pixels, 105)
        XCTAssertEqual(ring.corners.first, CGPoint(x: 10, y: 2))
    }

    func testAHoleDoesNotChangeTheOuterEdge() throws {
        let m = mask(12, 12) { x, y in
            (2..<10).contains(x) && (2..<10).contains(y) && !((4..<8).contains(x) && (4..<8).contains(y)) ? 3 : 0
        }
        let ring = try XCTUnwrap(CatchOutlineTracer.boundary(mask: m, width: 12, height: 12, label: 3))
        XCTAssertEqual(ring.corners, [CGPoint(x: 2, y: 2), CGPoint(x: 10, y: 2), CGPoint(x: 10, y: 10), CGPoint(x: 2, y: 10)])
    }

    func testOutlinesComeLargestFirstSmoothAndInsideThePhoto() {
        // Two discs: label 1 small (r 10), label 2 large (r 25), and a speck under the size limit.
        let m = mask(100, 80) { x, y in
            let a = (x - 25) * (x - 25) + (y - 40) * (y - 40), b = (x - 68) * (x - 68) + (y - 40) * (y - 40)
            if b <= 25 * 25 { return 2 }
            if a <= 10 * 10 { return 1 }
            return x == 2 && y == 2 ? 9 : 0
        }
        let lines = CatchOutlineTracer.outlines(mask: m, width: 100, height: 80)
        XCTAssertEqual(lines.map(\.label), [2, 1])
        for line in lines {
            XCTAssertGreaterThan(line.points.count, 40)
            XCTAssertGreaterThan(shoelace(line.points), 0, "clockwise on screen")
            XCTAssertTrue(line.points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        }
        // The big disc's outline stays close to its circle (centre 68, 40; radius 25 px → 0.25 of the width).
        let big = lines[0].points.map { CGPoint(x: $0.x * 100, y: $0.y * 80) }
        let radii = big.map { hypot($0.x - 68.5, $0.y - 40.5) }
        XCTAssertLessThan(abs(radii.reduce(0, +) / CGFloat(radii.count) - 25.5), 1.5)
    }

    // MARK: The pen's clock (o10_pen.js)

    /// The film `O10f`: three outlines (cup 1.0 s, scooter 0.9 s, sign 0.6 s), names at 3.12 s (2.4 s after the shutter).
    private func filmTimeline() -> CatchScanTimeline {
        CatchScanTimeline(durations: [1.0, 0.9, 0.6], ready: 0, bracketIn: 0.98)
    }

    func testTheBracketClicksAndThePenClosesAsInTheFilmBeforeTheNames() {
        let tl = filmTimeline()
        assertClose(tl.lock, [1.78, 3.04, 4.2], accuracy: 1e-9)
        XCTAssertEqual(tl.close(2), 4.8, accuracy: 1e-9)
        XCTAssertEqual(tl.tau(2.5), 2.5, "1× until the names arrive")
    }

    func testEarlyNamesMakeThePenCatchUpAsInTheFilm() {
        var tl = filmTimeline()
        tl.startCatchUp(at: 3.12)
        XCTAssertEqual(tl.k, 3.78, accuracy: 0.01)
        XCTAssertEqual(tl.real(tl.close(0)), 2.78, accuracy: 0.002, "closed before the names: unchanged")
        XCTAssertEqual(tl.real(tl.close(1)), 3.392, accuracy: 0.002)
        XCTAssertEqual(tl.real(tl.close(2)), 3.62, accuracy: 0.002)
        XCTAssertEqual(tl.real(tl.lock[2]), 3.461, accuracy: 0.002)
        // The tags (cup, scooter, the plant the pen does not draw, sign): the film's 3.26, 3.492, 3.52, 3.72.
        XCTAssertEqual(tl.found(names: 3.12), 3.12, accuracy: 1e-9)
        XCTAssertEqual(tl.tag(0, rank: 0, names: 3.12), 3.26, accuracy: 0.002)
        XCTAssertEqual(tl.tag(1, rank: 1, names: 3.12), 3.492, accuracy: 0.002)
        XCTAssertEqual(tl.tag(2, rank: nil, names: 3.12), 3.52, accuracy: 0.002)
        XCTAssertEqual(tl.tag(3, rank: 2, names: 3.12), 3.72, accuracy: 0.002)
    }

    func testLateNamesLeaveThePenAtItsPace() {
        var tl = filmTimeline()
        tl.startCatchUp(at: 8.72)
        XCTAssertEqual(tl.k, 1)
        XCTAssertEqual(tl.tau(9), 9)
        // The film `O10z`: 8.86, 8.99, 9.12, 9.25.
        assertClose((0..<4).map { tl.tag($0, rank: $0 < 3 ? $0 : nil, names: 8.72) }, [8.86, 8.99, 9.12, 9.25], accuracy: 1e-9)
    }

    func testTheSpeedNeverPassesFourTimes() {
        var tl = filmTimeline()
        tl.startCatchUp(at: 1.0)
        XCTAssertEqual(tl.k, 4)
        // Smooth: τ grows, and `real` undoes `tau`.
        var last = tl.tau(1.0)
        for i in 1...200 {
            let t = 1.0 + Double(i) * 0.01
            let x = tl.tau(t)
            XCTAssertGreaterThan(x, last)
            XCTAssertEqual(tl.real(x), t, accuracy: 1e-6)
            last = x
        }
    }

    func testPenTimeFollowsTheFilmsThreeOutlines() {
        // Length over the screen's diagonal → time: the film's sign, scooter and cup.
        XCTAssertEqual(CatchScanSpec.duration(lengthRatio: 0.331), 0.6, accuracy: 0.02)
        XCTAssertEqual(CatchScanSpec.duration(lengthRatio: 0.901), 0.9, accuracy: 0.02)
        XCTAssertEqual(CatchScanSpec.duration(lengthRatio: 1.186), 1.0, accuracy: 1e-9)
        XCTAssertEqual(CatchScanSpec.duration(lengthRatio: 0.05), 0.6, accuracy: 1e-9)
    }

    // MARK: A shape the pen draws

    func testThePenGoesRoundOnceFromTheTop() throws {
        let circle = (0..<200).map { i -> CGPoint in
            let a = Double(i) / 200 * 2 * .pi
            return CGPoint(x: 0.5 + 0.3 * cos(a), y: 0.5 + 0.3 * sin(a))
        }
        let outline = CatchOutline(label: 1, area: 0.28, points: circle)
        let stage = CGSize(width: 300, height: 300)
        let shape = try XCTUnwrap(CatchScanShape(outline: outline, fill: CGRect(origin: .zero, size: stage), stage: stage,
                                                 diagonal: hypot(300, 300)))
        XCTAssertEqual(shape.pts[0].y, shape.pts.map(\.y).min()!, accuracy: 1e-6, "it starts at the top")
        XCTAssertGreaterThan(shape.pts[1].x, shape.pts[0].x, "and goes right first: clockwise on screen")
        let gaps = shape.pts.indices.dropLast().map { hypot(shape.pts[$0 + 1].x - shape.pts[$0].x, shape.pts[$0 + 1].y - shape.pts[$0].y) }
        XCTAssertEqual(gaps.reduce(0, +) / CGFloat(gaps.count), CatchScanSpec.spacing, accuracy: 0.05)
        XCTAssertTrue(zip(shape.pace, shape.pace.dropFirst()).allSatisfy { $0 <= $1 })
        XCTAssertEqual(shape.pace.last ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(shape.head(lock: 1, tau: 1).h, 0)
        XCTAssertEqual(shape.head(lock: 1, tau: 1 + shape.duration).h, Double(shape.pts.count))
        let half = shape.head(lock: 1, tau: 1 + shape.duration / 2).h
        XCTAssertEqual(half / Double(shape.pts.count), 0.5, accuracy: 0.08, "a circle turns evenly: halfway at half time")
    }
}

private func assertClose(_ a: [Double], _ b: [Double], accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(a.count, b.count, file: file, line: line)
    for (x, y) in zip(a, b) { XCTAssertEqual(x, y, accuracy: accuracy, file: file, line: line) }
}
