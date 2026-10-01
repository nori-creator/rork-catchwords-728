import SwiftUI

/// "表示する項目と順番" — compact popover under the top-right button (SectionsPanel.tsx).
struct SectionsPanel: View {
    let prefs: CardPrefsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(L("表示する項目と順番"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Button(L("既定に戻す")) {
                    Haptics.selection()
                    withAnimation(.snappy) { prefs.reset() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.primaryInk)
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            List {
                ForEach(prefs.order) { section in
                    row(section)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
                }
                .onMove { from, to in
                    Haptics.selection()
                    prefs.move(from: from, to: to)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
        }
        .frame(width: 300, height: 460)
    }

    private func row(_ section: CardSection) -> some View {
        let on = prefs.isVisible(section)
        return Button {
            Haptics.selection()
            withAnimation(.snappy) { prefs.setVisible(section, !on) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(on ? Theme.primary : Theme.muted.opacity(0.4), in: Circle())
                Text(section.title(for: prefs.target))
                    .font(.system(size: 15, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Theme.foreground : Theme.muted)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: on ? "eye" : "eye.slash")
                    .font(.system(size: 14))
                    .foregroundStyle(on ? Theme.primaryInk : Theme.muted)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("\(section.title(for: prefs.target))、\(on ? L("表示中") : L("非表示"))"))
        .accessibilityHint(L("タップで切り替え。並べ替えは右の取っ手を使います"))
    }
}
