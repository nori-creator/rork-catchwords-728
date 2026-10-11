import SwiftUI
import UIKit
import Observation

/// 「保存しました」 after a change in 設定 (web `SaveStatusPill` / `settingsSaveStatus`, owner 2026-10-11:
/// 「設定で変更したら、WEB版と同じように保存しましたと表示されるように」). A small pill at the top centre for 2 s;
/// each new save starts the 2 s again. Device settings say it at once; account settings once the server kept them.
@Observable
final class SaveStatus {
    static let shared = SaveStatus()

    /// True while the pill shows.
    private(set) var visible: Bool = false
    /// Goes up on every save: an older timer never hides a newer pill.
    @ObservationIgnored private var token = 0

    /// Web `SAVED_VISIBLE_MS`.
    static let visibleFor: Duration = .seconds(2)

    func saved() {
        token += 1
        let mine = token
        withAnimation(.easeOut(duration: 0.18)) { visible = true }
        Task {
            try? await Task.sleep(for: Self.visibleFor)
            guard token == mine else { return }
            withAnimation(.easeOut(duration: 0.2)) { visible = false }
        }
    }

    /// Leaving the screen: nothing lingers for the next visit.
    func clear() {
        token += 1
        visible = false
    }
}

/// The pill itself: a check and 「保存しました」, centred 8 pt below the status bar. Takes no room and no taps.
struct SaveStatusPill: View {
    @State private var status = SaveStatus.shared
    @Environment(\.appReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if status.visible {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.primary)
                    Text(L("保存しました"))
                        .scaledFont(size: 13, weight: .semibold)
                        .foregroundStyle(Theme.foreground)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.card.opacity(0.96), in: Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -4)))
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityIdentifier("settings.saved")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .allowsHitTesting(false)
        .onChange(of: status.visible) { _, on in
            if on { UIAccessibility.post(notification: .announcement, argument: L("保存しました")) }
        }
    }
}
