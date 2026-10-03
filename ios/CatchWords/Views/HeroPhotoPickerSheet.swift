import SwiftUI

/// 「この単語は、どの絵で見せるか」(web HeroPhotoPicker.tsx, 要望 #17).
///
/// Only pictures that exist are offered — a choice that does nothing is never shown. A cut-out
/// that is the same file as the original is not offered either (the web compares the two).
/// The choice is saved on the server (`hero_role`), so it follows the learner to the web app.
struct HeroPhotoPickerSheet: View {
    let sticker: Sticker
    let onPick: (String) async throws -> Void

    @Environment(DexStore.self) private var dex
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var saving: String?
    @State private var chosen: String?
    @State private var failure: String?

    private struct Option: Identifiable {
        let id: String
        let label: String
        let path: String
        let isCutout: Bool
    }

    private var options: [Option] {
        var out: [Option] = []
        if let p = sticker.objectImageUrl { out.append(Option(id: "object", label: L("元の写真"), path: p, isCutout: false)) }
        if let p = sticker.cutoutImageUrl, p != sticker.objectImageUrl {
            out.append(Option(id: "cutout", label: L("切り抜き"), path: p, isCutout: true))
        }
        if let p = sticker.selfieImageUrl { out.append(Option(id: "selfie", label: L("自撮り"), path: p, isCutout: false)) }
        return out
    }

    /// What the page shows now: the saved choice, else the default order (cut-out, then original).
    private var current: String {
        if let chosen { return chosen }
        if let r = sticker.heroRole, options.contains(where: { $0.id == r }) { return r }
        return options.first { $0.id == "cutout" }?.id ?? "object"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("表示する写真"))
                    .scaledFont(size: 22, weight: .bold)
                    .foregroundStyle(Theme.foreground)
                Text(L("単語の詳細で、この写真を表紙にします。"))
                    .scaledFont(size: 13)
                    .foregroundStyle(Theme.muted)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(options) { option in
                    tile(option)
                }
            }
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle.fill")
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundStyle(Theme.primary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: chosen)
    }

    private func tile(_ option: Option) -> some View {
        let on = current == option.id
        return Button {
            pick(option.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    (option.isCutout ? Color(hex: 0xEEF3F9) : Theme.secondary)
                    StickerImage(path: option.path, url: dex.url(for: option.path, preferThumb: false),
                                 contentMode: option.isCutout ? .fit : .fill)
                        .padding(option.isCutout ? 14 : 0)
                        .shadow(color: .black.opacity(option.isCutout ? 0.22 : 0), radius: 8, y: 5)
                        .allowsHitTesting(false)
                    if saving == option.id {
                        Color.black.opacity(0.25)
                        ProgressView().tint(.white)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(on ? Theme.primary : Color.black.opacity(0.06), lineWidth: on ? 3 : 1)
                }
                .overlay(alignment: .topTrailing) {
                    if on {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Theme.primary, in: Circle())
                            .shadow(color: Theme.primary.opacity(0.4), radius: 6, y: 2)
                            .padding(8)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                .scaleEffect(on ? 1 : 0.97)
                .shadow(color: .black.opacity(on ? 0.14 : 0.05), radius: on ? 14 : 4, y: on ? 8 : 2)
                Text(option.label)
                    .scaledFont(size: 14, weight: on ? .bold : .medium)
                    .foregroundStyle(on ? Theme.foreground : Theme.muted)
                    .padding(.leading, 4)
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(saving != nil)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func pick(_ role: String) {
        guard saving == nil, role != current || sticker.heroRole != role else { return }
        let before = chosen
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.72)) {
            chosen = role
            failure = nil
        }
        saving = role
        Task {
            do {
                try await onPick(role)
                saving = nil
                try? await Task.sleep(for: .milliseconds(280))
                dismiss()
            } catch {
                saving = nil
                Haptics.warning()
                withAnimation(.snappy) {
                    chosen = before
                    failure = (error as? LocalizedError)?.errorDescription ?? L("保存できませんでした。通信を確かめてください。")
                }
            }
        }
    }
}
