import SwiftUI

/// Where a caught card goes after the card catch's `sendToDex` first half (the card lifted, became the
/// star and shrank away).
///
/// TODO(CatchLanding, next phase): the prototype's second half of `sendToDex` — open the dex gallery of
/// category silhouettes, scroll to the word's slot, fly the star there on an arc (720 ms, 600 ms after the
/// page opens), land with `.landpop` + SFX.pop + the pon haptic, and fill the slot with the cut-out
/// (`.slot.fill`, from 1.7×). For now this hands the saved sticker to the dex tab's existing landing
/// animation (`router.landingStickerId` → DexView.land).
enum CatchLanding {
    @MainActor
    static func land(stickerId: String, router: AppRouter) {
        router.landingStickerId = stickerId
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { router.tab = .dex }
    }
}
