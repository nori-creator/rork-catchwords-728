import SwiftUI
import CoreLocation

/// Web `ReencounterPanel` (capture.tsx): the word is already in the dex. No quiz — this photo
/// is added to that word with where you met it again, and the review interval is not moved.
struct ReencounterView: View {
    @Bindable var vm: CaptureViewModel
    /// 「図鑑で見る」: the word's sticker id, and the photo's frame on screen (global) the star leaves from.
    let onSeeInDex: (String, CGRect?) -> Void

    @Environment(DexStore.self) private var dex
    @Environment(AppRouter.self) private var router
    /// The photo on screen (global): the star that flies into the dex starts there.
    @State private var photoFrame: CGRect?
    /// 「図鑑で見る」 was tapped: this screen stays under the rising dex page for a moment, one landing only.
    @State private var leaving = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    CollectHeader { vm.reset() }
                    if let owned = vm.owned { card(owned) }
                    Button { vm.reset() } label: {
                        Label(L("別のものを撮る"), systemImage: "camera")
                            .scaledFont(size: 16, weight: .semibold)
                            .foregroundStyle(Theme.foreground)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.card, in: Capsule())
                            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
        }
        .task { record() }
    }

    private func card(_ owned: OwnedWord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                if let photo = vm.cutout ?? vm.photo {
                    Color.clear
                        .aspectRatio(4 / 3, contentMode: .fit)
                        .overlay { Image(uiImage: photo).resizable().scaledToFill().allowsHitTesting(false) }
                        .clipShape(.rect(cornerRadius: 24, style: .continuous))
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .global)
                        } action: { frame in
                            photoFrame = frame
                        }
                }
                Text(L("再会！"))
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(Theme.primaryInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.card.opacity(0.95), in: Capsule())
                    .padding(12)
            }
            HStack {
                ZhuyinWordView(headword: owned.headword, zhuyin: owned.readingZhuyin, size: 34, weight: .bold, pinyin: owned.pinyin)
                Spacer()
                PronounceCircle(text: owned.headword, size: 44)
            }
            Text(ReaderLanguage.gloss(ReaderLanguage.shown(owned.meaningJa)))
                .scaledFont(size: 20, weight: .medium)
                .foregroundStyle(Theme.foreground)
            Text(metLine(owned))
                .scaledFont(size: 13)
                .foregroundStyle(Theme.muted)
            status(owned)
            // At once: the photo is already in the dex (its upload and record finish behind the screens).
            PrimaryButton(title: L("図鑑で見る"), icon: "books.vertical") {
                guard !leaving else { return }
                leaving = true
                onSeeInDex(owned.stickerId, photoFrame)
            }
            .accessibilityIdentifier("reencounter.dex")
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .shadow(color: Theme.primary.opacity(0.08), radius: 22, y: 12)
    }

    private func status(_ owned: OwnedWord) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
            Text(L("再会\(vm.reencCount ?? owned.encounterCount + 1)回目"))
        }
        .scaledFont(size: 13, weight: .medium)
        .foregroundStyle(Theme.primaryInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.primary.opacity(0.06), in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// cap.reencBefore + reencAt/reencOn + reencAfter: 「この言葉、{date}に{place}でゲットしています。」
    private func metLine(_ owned: OwnedWord) -> String {
        let date = owned.takenDate.map { $0.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(L10n.locale)) } ?? ""
        if let place = owned.locationName, !place.isEmpty {
            return L("この言葉、\(date)に\(place)でゲットしています。")
        }
        return L("この言葉、\(date)にゲットしています。")
    }

    /// Owner 2026-10-11 (「同じ単語の画像を撮ったときに、追加するまでに時間が無駄にかかる」): nothing waits for the network
    /// any more. The count and 「図鑑で見る」 show at once, the dex shows the photo at once (`DexStore.recordEncounter`),
    /// and the upload and the record finish behind the screens — owned by this task, not by the screen, so leaving it
    /// never stops them. As for a new word (`CaptureView.finishSave`): the photo is handed from the camera to the save
    /// (hidden in 「解析待ち」 meanwhile), goes when it is recorded, and only a failure is told (a notice over every
    /// tab; the photo is back in 「解析待ち」 to try again).
    private func record() {
        guard let owned = vm.owned, vm.reencCount == nil else { return }
        vm.reencCount = owned.encounterCount + 1
        Haptics.success()
        let pendingId = vm.detachPendingForSave()
        let photo = vm.photo, cutout = vm.cutout, location = vm.location, placeName = vm.placeName
        let store = dex, nav = router
        Task {
            await Self.finishRecord(owned: owned, photo: photo, cutout: cutout, location: location, placeName: placeName,
                                    pendingId: pendingId, dex: store, router: nav)
        }
    }

    private static func finishRecord(owned: OwnedWord, photo: UIImage?, cutout: UIImage?, location: CLLocation?,
                                     placeName: String?, pendingId: String?, dex: DexStore, router: AppRouter) async {
        do {
            _ = try await dex.recordEncounter(owned: owned, photo: photo, cutout: cutout,
                                              location: location, placeName: placeName)
            if let pid = pendingId {
                PendingQueue.shared.remove(id: pid)
                PendingRetry.shared.forget(pid)
            }
            dex.refreshPending()
        } catch let error where DexStore.isAccountChanged(error) {
            // Signed out (or into another account) meanwhile: the photo stays with the account that took it.
            if let pid = pendingId { PendingQueue.shared.setSaving(pid, false) }
        } catch {
            let failed = L("記録に失敗しました")
            let reason = (error as? LocalizedError)?.errorDescription ?? ""
            if let pid = pendingId {
                PendingQueue.shared.updateReason(id: pid, reason: failed)
                PendingQueue.shared.setSaving(pid, false)
            }
            dex.refreshPending()
            Haptics.warning()
            router.showNotice(reason.isEmpty || reason == failed ? failed : L("記録に失敗しました\n\(reason)"))
        }
    }
}
