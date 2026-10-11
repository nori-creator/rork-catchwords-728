import UIKit

/// Every picture is cut out (owner 2026-10-11: 「切り抜きモードは消して。すべての画像切抜く」). A word whose own photo
/// has no cut-out yet — caught on the web (cut-outs were dropped there on 2026-10-01), on an older version of the
/// app, or one whose cut-out failed at the time — gets one made on this phone with the same lift as at the shutter
/// (Vision, on device, free) and attached to the word (`attachStickerCutout`), one at a time behind the screens.
/// A photo in which Vision finds no subject is remembered for this account and not tried again.
final class CutoutBackfill {
    static let shared = CutoutBackfill()

    private var task: Task<Void, Never>?
    /// Words being cut out right now (the word page asks too when it opens one without a cut-out).
    private var running: Set<String> = []

    enum Outcome { case made, noSubject, failed }

    /// Words tried in one run at most (the rest wait for the next launch).
    private static let perRun = 40

    private static func triedKey(_ uid: String) -> String { "cutout.tried.\(uid)" }

    /// A photo of the learner's own, still without a cut-out (a typed word's text card is never cut out).
    static func needsCutout(_ s: Sticker) -> Bool {
        s.cutoutImageUrl == nil && s.objectImageUrl != nil && !DexStore.isProvisional(s.id) && s.captureType != "text"
    }

    /// Starts working through the words without a cut-out (after a dex read). Does nothing while a run is going.
    func start(dex: DexStore) {
        guard task == nil, let uid = SupabaseClient.shared.userId else { return }
        let tried = Set(UserDefaults.standard.stringArray(forKey: Self.triedKey(uid)) ?? [])
        let todo = dex.stickers.filter { Self.needsCutout($0) && !tried.contains($0.id) }.prefix(Self.perRun).map(\.id)
        guard !todo.isEmpty else { return }
        task = Task(priority: .utility) { [weak self] in
            var noSubject = tried
            for id in todo {
                guard let self, !Task.isCancelled, SupabaseClient.shared.userId == uid else { break }
                // The word may have changed meanwhile (a cut-out attached elsewhere, the word deleted).
                guard let current = dex.sticker(id: id), Self.needsCutout(current) else { continue }
                if await self.make(for: current, dex: dex) == .noSubject {
                    noSubject.insert(id)
                    UserDefaults.standard.set(Array(noSubject), forKey: Self.triedKey(uid))
                }
                try? await Task.sleep(for: .milliseconds(300))
            }
            self?.task = nil
        }
    }

    /// Signing out: the run stops (it belongs to the account that left).
    func stop() {
        task?.cancel()
        task = nil
        running = []
    }

    /// Cuts this word's photo out now and attaches the cut-out. The photo comes from the cache when it is kept,
    /// else from its link.
    @discardableResult
    func make(for sticker: Sticker, dex: DexStore) async -> Outcome {
        guard Self.needsCutout(sticker), let path = sticker.objectImageUrl, !running.contains(sticker.id) else { return .failed }
        running.insert(sticker.id)
        defer { running.remove(sticker.id) }
        var image = await ImageCache.shared.cached(for: path)
        if image == nil {
            // Signed (when needed) and put on disk, then read from there.
            await dex.prefetchPictures([path])
            if let url = dex.url(for: path, preferThumb: false) {
                image = await ImageCache.shared.load(url: url, key: path)
            }
        }
        guard let image else { return .failed }
        guard let lifted = await CutoutService.liftSubject(from: image) else { return .noSubject }
        do {
            try await dex.addCutout(to: sticker, image: lifted)
            return .made
        } catch {
            return .failed
        }
    }
}
