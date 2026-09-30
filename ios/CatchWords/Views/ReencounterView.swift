import SwiftUI

/// Web `ReencounterPanel` (capture.tsx): the word is already in the dex. No quiz — this photo
/// is added to that word with where you met it again, and the review interval is not moved.
struct ReencounterView: View {
    @Bindable var vm: CaptureViewModel
    let onSeeInDex: (String) -> Void

    @Environment(DexStore.self) private var dex
    @State private var isSaving: Bool = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    CollectHeader { vm.reset() }
                    if let owned = vm.owned { card(owned) }
                    Button { vm.reset() } label: {
                        Label("別のものを撮る", systemImage: "camera")
                            .font(.system(size: 16, weight: .semibold))
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
        .task { await record() }
    }

    private func card(_ owned: OwnedWord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                if let photo = vm.cutout ?? vm.photo {
                    Color.clear
                        .aspectRatio(4 / 3, contentMode: .fit)
                        .overlay { Image(uiImage: photo).resizable().scaledToFill().allowsHitTesting(false) }
                        .clipShape(.rect(cornerRadius: 24, style: .continuous))
                }
                Text("再会！")
                    .font(.system(size: 13, weight: .semibold))
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
            Text(owned.meaningJa)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.foreground)
            Text(metLine(owned))
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            status
            if vm.reencFailed {
                PrimaryButton(title: "写真の追加を再試行", icon: "arrow.clockwise", isLoading: isSaving) {
                    Task { await record() }
                }
            } else if vm.reencCount != nil {
                PrimaryButton(title: "図鑑で見る", icon: "books.vertical") { onSeeInDex(owned.stickerId) }
            }
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .shadow(color: Theme.primary.opacity(0.08), radius: 22, y: 12)
    }

    private var status: some View {
        HStack(spacing: 8) {
            if vm.reencFailed {
                Image(systemName: "arrow.counterclockwise")
            } else if vm.reencCount != nil {
                Image(systemName: "checkmark")
            } else {
                ProgressView().controlSize(.small)
            }
            Text(statusText)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Theme.primaryInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.primary.opacity(0.06), in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        if vm.reencFailed { return "記録に失敗しました" }
        if vm.reencPhotoSaved { return "この写真を単語に追加しました" }
        if let n = vm.reencCount { return "再会\(n)回目" }
        return "この1枚を図鑑に足しています…"
    }

    /// cap.reencBefore + reencAt/reencOn + reencAfter: 「この言葉、{date}に{place}でゲットしています。」
    private func metLine(_ owned: OwnedWord) -> String {
        let date = owned.takenDate.map { $0.formatted(.dateTime.year().month().day()) } ?? ""
        if let place = owned.locationName, !place.isEmpty {
            return "この言葉、\(date)に\(place)でゲットしています。"
        }
        return "この言葉、\(date)にゲットしています。"
    }

    private func record() async {
        guard let owned = vm.owned, !isSaving, vm.reencCount == nil else { return }
        isSaving = true
        vm.reencFailed = false
        defer { isSaving = false }
        do {
            let res = try await dex.recordEncounter(owned: owned, photo: vm.photo, cutout: vm.cutout,
                                                    location: vm.location, placeName: vm.placeName)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                vm.reencCount = res.count
                vm.reencPhotoSaved = res.photoSaved
            }
            vm.releasePending()
            dex.refreshPending()
            Haptics.success()
        } catch {
            vm.reencFailed = true
            vm.showToast("記録に失敗しました")
            Haptics.warning()
        }
    }
}
