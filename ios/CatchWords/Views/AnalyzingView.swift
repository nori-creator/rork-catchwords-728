import SwiftUI

/// Full-bleed photo, slightly dimmed, with one calm progress line at the bottom ("AIが分析中…") and
/// "やめる" top-right. Nothing moves over the photo (owner 2026-10-09: no brackets, no sweeping frames).
struct AnalyzingView: View {
    let photo: UIImage?
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Theme.navyDeep.ignoresSafeArea()
            if let photo {
                Color.clear
                    .overlay { Image(uiImage: photo).resizable().scaledToFill().allowsHitTesting(false) }
                    .clipped()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.28).ignoresSafeArea())
            } else {
                MachineBackground()
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Text(L("やめる"))
                            .scaledFont(size: 15, weight: .medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 44)
                            .background(.black.opacity(0.25), in: Capsule())
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text(L("AIが分析中…"))
                }
                .scaledFont(size: 16, weight: .semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(minHeight: 48)
                .background(.black.opacity(0.3), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .accessibilityElement(children: .combine)
                .padding(.bottom, 60)
            }
        }
    }
}
