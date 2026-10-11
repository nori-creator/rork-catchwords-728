import XCTest
@testable import CatchWords

/// Card catch, choosing an object (owner report 2026-10-04: with several things in the photo the name tags
/// covered each other and some objects could not be chosen). Pure logic: Vision instance assignment, the tag
/// layout and the tap → object rule. Run on its own by .github/workflows/ios-check.yml.
@MainActor
final class CardCatchPickTests: XCTestCase {
    private func cand(_ head: String, group: Int?, point: [Double]) -> Candidate {
        Candidate(kind: "object", headword: head, zhuyin: "", pinyin: "", meaningJa: head, pos: "",
                  point: point, confidence: 0.9, alternatives: [], group: group)
    }

    // MARK: Instances

    func testTwoObjectsNeverShareAnInstance() {
        // Both points are nearest instance 1; object 1 lies ON it, object 0 only near it.
        let ranked: [[CatchObject.InstanceHit]] = [
            [.init(label: 1, distance: 40), .init(label: 2, distance: 90)],
            [.init(label: 1, distance: 0)],
        ]
        let got = CatchObject.assignInstances(ranked)
        XCTAssertEqual(got[1], 1)
        XCTAssertEqual(got[0], 2)
    }

    func testNoFreeInstanceFallsBack() {
        let ranked: [[CatchObject.InstanceHit]] = [[.init(label: 3, distance: 0)], [.init(label: 3, distance: 0)], []]
        let got = CatchObject.assignInstances(ranked)
        XCTAssertEqual(got[0], 3, "a tie goes to the server's first object")
        XCTAssertNil(got[1])
        XCTAssertNil(got[2])
        XCTAssertEqual(Set(got.compactMap { $0 }).count, got.compactMap { $0 }.count)
    }

    func testBuildWithoutMasksGivesSeparateBoxes() {
        let objs = CatchObject.build(candidates: [cand("杯子", group: 0, point: [300, 500]),
                                                  cand("杯子", group: 1, point: [700, 500])],
                                     masks: nil, photoSize: CGSize(width: 1000, height: 1000))
        XCTAssertEqual(objs.count, 2)
        XCTAssertNotEqual(objs[0].box, objs[1].box)
    }

    // MARK: Where a tag sits (owner 2026-10-11: 「しっかりもののうえに名前タグをおいて」)

    private func mask(_ w: Int, _ h: Int, _ fill: (Int, Int) -> UInt8) -> [UInt8] {
        var m = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w { m[y * w + x] = fill(x, y) } }
        return m
    }

    func testWithoutAVisionInstanceTheTagSitsOnTheAIsPoint() {
        let objs = CatchObject.build(candidates: [cand("杯子", group: 0, point: [300, 600])], masks: nil,
                                     photoSize: CGSize(width: 1000, height: 1000))
        XCTAssertEqual(objs[0].anchor, CGPoint(x: 0.3, y: 0.6))
        XCTAssertEqual(objs[0].anchor, objs[0].point)
    }

    func testATagSitsInTheMiddleOfAPlainThing() throws {
        let m = mask(40, 30) { x, y in (10..<30).contains(x) && (5..<25).contains(y) ? 5 : 0 }
        let all = CatchAnchor.anchors(mask: m, width: 40, height: 30)
        XCTAssertEqual(Set(all.keys), [5])
        let p = try XCTUnwrap(all[5])
        XCTAssertEqual(p.x, 0.5, accuracy: 1.0 / 40)
        XCTAssertEqual(p.y, 0.5, accuracy: 1.0 / 30)
    }

    func testACupsTagSitsOnItsBodyNotByItsHandle() throws {
        // The body is 24 × 40 px; the handle is a ring on its right.
        let m = mask(60, 60) { x, y in
            if (10..<34).contains(x) && (10..<50).contains(y) { return 3 }
            let r2 = (x - 40) * (x - 40) + (y - 30) * (y - 30)
            return x >= 34 && (36...100).contains(r2) ? 3 : 0
        }
        let p = try XCTUnwrap(CatchAnchor.anchors(mask: m, width: 60, height: 60)[3])
        let x = Int(p.x * 60), y = Int(p.y * 60)
        XCTAssertTrue((16..<28).contains(x), "on the body, well clear of its sides: x \(x)")
        XCTAssertTrue((22..<38).contains(y), "about half way down: y \(y)")
    }

    func testAPlateBehindAMangoGetsItsTagOnThePlate() throws {
        // The middle of the plate's box is on the mango in front of it — where its tag used to go.
        let m = mask(60, 40) { x, y in
            if (x - 30) * (x - 30) + (y - 16) * (y - 16) <= 121 { return 1 }
            let dx = Double(x - 30) / 27, dy = Double(y - 26) / 11
            return dx * dx + dy * dy <= 1 ? 2 : 0
        }
        XCTAssertEqual(m[26 * 60 + 30], 1)
        let all = CatchAnchor.anchors(mask: m, width: 60, height: 40)
        XCTAssertEqual(Set(all.keys), [1, 2])
        for (label, p) in all {
            let x = Int(p.x * 60), y = Int(p.y * 40)
            XCTAssertEqual(m[y * 60 + x], UInt8(label), "thing \(label)'s tag is on that thing")
        }
    }

    func testAThingCutByThePhotosEdgeGetsItsTagInsideThePicture() throws {
        let m = mask(40, 20) { x, y in x < 16 && (2..<18).contains(y) ? 4 : 0 }
        let p = try XCTUnwrap(CatchAnchor.anchors(mask: m, width: 40, height: 20)[4])
        XCTAssertEqual(p.x, 8.0 / 40, accuracy: 1.5 / 40, "the middle of what shows, not the photo's edge")
        XCTAssertEqual(p.y, 0.5, accuracy: 1.0 / 20)
    }

    func testAThingSplitInTwoGetsItsTagOnThePieceTheScanOutlines() throws {
        // One instance in two pieces: a C open to the right (the larger piece, the one `CatchOutlineTracer` outlines)
        // and a block in its hollow, nearer the middle of the whole — where the tag would go if every piece counted.
        let m = mask(40, 30) { x, y in
            let square = x < 30 && y < 30
            let hollow = (8..<22).contains(x) && (8..<22).contains(y)
            let mouth = x >= 22 && (8..<22).contains(y)
            let block = (12..<20).contains(x) && (11..<19).contains(y)
            return (square && !hollow && !mouth) || block ? 6 : 0
        }
        let p = try XCTUnwrap(CatchAnchor.anchors(mask: m, width: 40, height: 30)[6])
        let x = Int(p.x * 40), y = Int(p.y * 30)
        XCTAssertEqual(m[y * 40 + x], 6)
        XCTAssertFalse((12..<20).contains(x) && (11..<19).contains(y), "on the C, not on the block: \(x), \(y)")
    }

    // MARK: Same name, two objects

    func testSameNameInTwoGroupsStaysTwoObjects() {
        let a = cand("杯子", group: 0, point: [300, 500])
        let b = cand("杯子", group: 1, point: [700, 500])
        XCTAssertFalse(AIService.sameSuggestion(a, b))
        XCTAssertEqual(CatchObject.groups([a, b]).count, 2)
        // The same name twice for one object is still one entry.
        XCTAssertTrue(AIService.sameSuggestion(a, cand("杯子", group: 0, point: [310, 500])))
        XCTAssertTrue(AIService.sameSuggestion(cand("杯子", group: nil, point: [1, 2]), cand("杯子", group: nil, point: [1, 2])))
        XCTAssertFalse(AIService.sameSuggestion(cand("杯子", group: nil, point: [1, 2]), cand("杯子", group: nil, point: [600, 2])))
    }

    // MARK: Tags

    func testOverlappingTagsAreMovedApart() {
        // Two objects with the same box (the old bug) and a third close by.
        let r = CGRect(x: 100, y: 300, width: 180, height: 160)
        let rects = [r, r, CGRect(x: 120, y: 290, width: 150, height: 150)]
        let sizes = rects.map { _ in CCPickLayout.tagSize(name: "コップ") }
        let spots = CCPickLayout.layout(rects: rects, sizes: sizes)
        XCTAssertEqual(spots.count, 3)
        XCTAssertEqual(spots[0], CCPickLayout.anchor(for: r, size: sizes[0]), "the first tag keeps its own place")
        let frames = zip(spots, sizes).map { CCPickLayout.frame(bottomCenter: $0, size: $1) }
        for i in frames.indices {
            for j in frames.indices where j > i {
                XCTAssertFalse(frames[i].intersects(frames[j]), "tags \(i) and \(j) overlap")
            }
            XCTAssertGreaterThanOrEqual(spots[i].y, CCPickLayout.minBottom)
            XCTAssertGreaterThanOrEqual(frames[i].minX, 0)
            XCTAssertLessThanOrEqual(frames[i].maxX, CCSpace.w)
        }
    }

    func testSeparateTagsStayWhereThePrototypePutsThem() {
        let rects = [CGRect(x: 20, y: 300, width: 120, height: 120), CGRect(x: 250, y: 300, width: 120, height: 120)]
        let sizes = rects.map { _ in CCPickLayout.tagSize(name: "cup") }
        let spots = CCPickLayout.layout(rects: rects, sizes: sizes)
        XCTAssertEqual(spots[0], CCPickLayout.anchor(for: rects[0], size: sizes[0]))
        XCTAssertEqual(spots[1], CCPickLayout.anchor(for: rects[1], size: sizes[1]))
    }

    // MARK: Taps

    func testTapPrefersTheSmallerBox() {
        let big = CGRect(x: 0, y: 0, width: 300, height: 300)
        let small = CGRect(x: 100, y: 100, width: 60, height: 60)
        XCTAssertEqual(CCPickLayout.object(at: CGPoint(x: 120, y: 120), rects: [small, big]), 0)
        XCTAssertEqual(CCPickLayout.object(at: CGPoint(x: 120, y: 120), rects: [big, small]), 1)
        XCTAssertEqual(CCPickLayout.object(at: CGPoint(x: 20, y: 20), rects: [big, small]), 0)
        XCTAssertNil(CCPickLayout.object(at: CGPoint(x: 400, y: 400), rects: [big, small]))
    }

    func testTapOnSameSizeBoxesTakesTheNearestCentre() {
        let a = CGRect(x: 0, y: 0, width: 200, height: 200)
        let b = CGRect(x: 100, y: 0, width: 200, height: 200)
        XCTAssertEqual(CCPickLayout.object(at: CGPoint(x: 120, y: 100), rects: [a, b]), 0)
        XCTAssertEqual(CCPickLayout.object(at: CGPoint(x: 180, y: 100), rects: [a, b]), 1)
    }
}
