import SwiftUI

/// The waiting star of a catch, handed from the camera screen to the landing (global coordinates).
struct CatchStar: Equatable {
    var center: CGPoint
    var size: CGFloat
    /// The card-catch screen's scale (design points → points), for the prototype's fixed offsets.
    var k: CGFloat
}

/// The second half of the prototype's `sendToDex` (docs/prototype/cardcatch-src.html): after the save, the dex
/// opens in ギャラリー (forced, like `S.view = "grid"`), scrolled to the word's place. Owner 2026-10-11
/// (「古い単語を横切るアニメーションではなく、…事前にもとの古い番号が高い単語の位置を1つ右に移動し、新しい単語はその
/// 左に入るようにして」): once the page has risen the gallery makes room for the word first — the words numbered
/// after it move one square to the right, leaving its square at its place by No. (DexView, `DexBook.Hold`) —
/// and only then the star flies there on an arc (720 ms, cubic-bezier(.5,0,.25,1), ±90 / −120 at the middle, a
/// full turn, scale 1 → 1.15 → .85, a trail of sparkles), lands with `.landpop` + SFX.pop + the pon tap, and the
/// square fills with the cut-out in place (nothing else moves); 20 ms later `renderDex`'s focus burst, glints and
/// SFX.land there. A re-encounter (`alreadyCaught`, owner 2026-10-11: 「同じ単語でも図鑑に追加するアニメーションを
/// 追加して」) lands the same way on the word's own square, which is already there: no room to make.
@MainActor @Observable
final class CatchLandingController {
    enum Phase { case opening, flying, landed }

    /// The landing word. A catch lands at once on a provisional entry; when its background save
    /// finishes this becomes the saved sticker's id (DexView moves its hold and focus along).
    var stickerId: String
    /// A re-encounter: the word is in the dex already (its square is not held, no room is made).
    let alreadyCaught: Bool
    let star: CatchStar
    let motion: CCMotion
    /// The screen's size, for the prototype's fallback target when the slot is not on screen.
    let screen: CGSize

    var phase: Phase = .opening
    /// [translateX, translateY, scale, rotate°] from `star.center`.
    var flight: CCAnim?
    /// After landing: [scale, opacity] (`star.animate(scale .85 → 1.6, opacity 1 → 0, 260 ms)`).
    var fade: CCAnim?
    /// `.landpop` [scale, opacity] at `landAt`.
    var pop: CCAnim?
    var landAt: CGPoint = .zero
    /// When the slot filled (`.slot.fill` → fillIn .9 s).
    var fillStart: Double?

    /// The target slot's `.sart`, in global coordinates (reported by the gallery as it lays out). After the
    /// landing it is the word's slot in the caught group (the same square).
    @ObservationIgnored var target: CGRect?
    /// Set by the gallery once the word's square is there to land in: the room made for a new word (the words
    /// numbered after it moved one square to the right), or a re-encounter's square scrolled to.
    @ObservationIgnored var roomReady = false
    /// Set by the gallery once it has been redrawn after the landing and scrolled to the word's new slot.
    @ObservationIgnored var settled = false
    let particles = CCParticles()
    @ObservationIgnored private var trailing = false

    init(stickerId: String, alreadyCaught: Bool = false, star: CatchStar, motion: CCMotion, screen: CGSize) {
        self.stickerId = stickerId
        self.alreadyCaught = alreadyCaught
        self.star = star
        self.motion = motion
        self.screen = screen
        particles.calm = motion.calm
    }

    private func wait(_ seconds: Double) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(for: .seconds(seconds))
    }

    private func play(_ sfx: SFX) { SoundService.shared.playLayered(sfx) }

    /// The star's offset from its start at `now`.
    func offset(_ now: Double) -> CGPoint {
        guard let v = flight?.sample(now) else { return .zero }
        return CGPoint(x: v[0], y: v[1])
    }

    func run() async {
        // The dex page is open and scrolled to the word's place (DexView). The page rises in .55 s; the star leaves
        // as it settles, once the gallery has made the word's square (`roomReady`) — at most 1.2 s in all, so a
        // gallery that is not on screen never keeps the star waiting.
        await wait(motion.sleep(380))
        var beforeFlight = motion.sleep(380)
        while !roomReady && beforeFlight < 1.2 {
            await wait(0.016)
            beforeFlight += 0.016
        }
        let k = Double(star.k)
        let cx = Double(star.center.x), cy = Double(star.center.y)
        // `tr = tEl ? rect(.sart) : {x: W0/2 − 40, y: 560, w: 80, h: 80}`
        let tr = target ?? CGRect(x: screen.width / 2 - 40 * star.k, y: 560 * star.k, width: 80 * star.k, height: 80 * star.k)
        let tx = Double(tr.midX), ty = Double(tr.midY)
        phase = .flying
        // No flight sound of its own (owner 2026-10-04): the landing pop and land follow.
        trailing = true
        Task {
            // setInterval(() => trail(star centre), 16)
            while trailing {
                let o = offset(CCClock.now)
                particles.trail(cx + Double(o.x), cy + Double(o.y))
                await wait(0.016)
            }
        }
        flight = CCAnim([[0, 0, 1, 0],
                         [(tx - cx) * 0.5 + (tx < cx ? -90 : 90) * k, (ty - cy) * 0.5 - 120 * k, 1.15, 180],
                         [tx - cx, ty - cy, 0.85, 360]],
                        duration: motion.d(720), easing: CCBezier(0.5, 0, 0.25, 1), fill: .forwards)
        await wait(motion.d(720))
        trailing = false

        // pon! — it lands and the cut-out appears in the silhouette
        fade = CCAnim([[0.85, 1], [1.6, 0]], duration: motion.d(260), fill: .forwards)
        landAt = CGPoint(x: tx, y: ty)
        pop = CCAnim([[0.1, 1], [1.3, 0]], duration: motion.d(550), easing: CCBezier(0.2, 0.8, 0.3, 1), fill: .forwards)
        play(.ccPop)
        Haptics.pon(open: true)
        phase = .landed
        // addEntry + renderDex: the hold is let go (DexView) and the waiting square becomes the word in place — the room
        // was made before the flight, so nothing else moves; the slot fills (`fillIn`) and keeps reporting its frame
        // into `target`.
        fillStart = CCClock.now
        var waited = 0.0
        while !settled && waited < 0.5 {
            await wait(0.016)
            waited += 0.016
        }
        // renderDex focus (focusNow): 20 ms later the burst, glints and SFX.land on the new slot
        await wait(0.02)
        let fr = target ?? tr
        particles.burst(Double(fr.midX), Double(fr.midY), n: 44, speed: 6, up: 3)
        particles.glints(fr, n: 8)
        play(.ccLand)
        await wait(2.6)   // the sparkles die down, then the overlay goes
    }
}

/// The star, its sparkles and `.landpop`, above every screen while the dex opens (`#fly` / `#fx` / `.landpop`).
struct CatchLandingOverlay: View {
    let controller: CatchLandingController

    var body: some View {
        GeometryReader { geo in
            let o = geo.frame(in: .global).origin
            TimelineView(.animation) { _ in
                let now = CCClock.now
                let c = controller
                ZStack(alignment: .topLeading) {
                    if let p = c.pop, let v = p.sample(now), v[1] > 0.001 {
                        // radial-gradient(closest-side, rgba(255,255,255,.95), rgba(190,220,255,.5) 40%, transparent)
                        let s = 120 * c.star.k
                        Circle()
                            .fill(RadialGradient(stops: [.init(color: .rgba(255, 255, 255, 0.95), location: 0),
                                                         .init(color: .rgba(190, 220, 255, 0.5), location: 0.4),
                                                         .init(color: .rgba(255, 255, 255, 0), location: 1)],
                                                 center: .center, startRadius: 0, endRadius: s / 2))
                            .frame(width: s, height: s)
                            .scaleEffect(v[0])
                            .opacity(v[1])
                            .position(x: c.landAt.x - o.x, y: c.landAt.y - o.y)
                    }
                    star(now: now, origin: o)
                    Canvas { ctx, _ in
                        c.particles.advance(to: now)
                        ctx.translateBy(x: -o.x, y: -o.y)
                        c.particles.draw(&ctx)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func star(now: Double, origin o: CGPoint) -> some View {
        let c = controller
        let fl = c.flight?.sample(now)
        let fd = c.fade?.sample(now)
        let opacity = fd?[1] ?? 1
        if opacity > 0.001 {
            let tx = fl?[0] ?? 0, ty = fl?[1] ?? 0
            let scale = fd?[0] ?? fl?[2] ?? 1
            let rot = fd == nil ? (fl?[3] ?? 0) : 0
            CCStarlight(size: c.star.size, now: now, calm: c.motion.calm)
                .scaleEffect(scale)
                .rotationEffect(.degrees(rot))
                .opacity(opacity)
                .position(x: c.star.center.x + tx - o.x, y: c.star.center.y + ty - o.y)
        }
    }
}

enum CatchLanding {
    /// The catch is saved: open the dex gallery and fly the waiting star into the word's slot. `alreadyCaught`: a
    /// re-encounter's photo going into a word the dex already shows (no room to make, its own square lands).
    @MainActor
    static func land(stickerId: String, router: AppRouter, calm: Bool, alreadyCaught: Bool = false) {
        let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.size ?? CGSize(width: 390, height: 844)
        let star = router.catchStar ?? CatchStar(center: CGPoint(x: screen.width / 2, y: screen.height * 306 / 844),
                                                  size: 52, k: 1)
        router.catchStar = nil
        let c = CatchLandingController(stickerId: stickerId, alreadyCaught: alreadyCaught, star: star,
                                       motion: CCMotion(calm: calm), screen: screen)
        router.landing = c
        Task {
            // One frame first, so the camera screen knows it stays under the rising dex page.
            try? await Task.sleep(for: .milliseconds(16))
            // #dex: transform translateY(102%) → none, .55 s cubic-bezier(.2,1,.3,1) (.calm: no slide)
            withAnimation(calm ? nil : .timingCurve(0.2, 1, 0.3, 1, duration: 0.55)) { router.tab = .dex }
            await c.run()
            if router.landing === c { router.landing = nil }
        }
    }
}
