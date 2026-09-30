import SwiftUI

/// Calm analyzing state: the photo breathes under a sweeping scan line and converging light ring.
struct AnalyzingView: View {
    let photo: UIImage?

    @State private var sweep: CGFloat = -1
    @State private var ring: Bool = false
    @State private var dots: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                if let photo {
                    Color.clear
                        .frame(width: 260, height: 320)
                        .overlay { Image(uiImage: photo).resizable().scaledToFill().allowsHitTesting(false) }
                        .clipShape(.rect(cornerRadius: 26))
                        .overlay {
                            GeometryReader { geo in
                                LinearGradient(colors: [.clear, Theme.cyan.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                                    .frame(height: 90)
                                    .offset(y: sweep * geo.size.height)
                                    .blendMode(.screen)
                            }
                            .clipShape(.rect(cornerRadius: 26))
                            .allowsHitTesting(false)
                        }
                        .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.18), lineWidth: 1))
                        .shadow(color: Theme.primary.opacity(0.4), radius: 30, y: 12)
                } else {
                    Image(systemName: "character.magnify")
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(Theme.cyan)
                        .frame(width: 200, height: 200)
                }
                Circle()
                    .trim(from: 0, to: 0.22)
                    .stroke(AngularGradient(colors: [.clear, Theme.cyan], center: .center), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 360, height: 360)
                    .rotationEffect(.degrees(ring ? 360 : 0))
                    .opacity(0.8)
            }
            VStack(spacing: 6) {
                Text("見つけています" + String(repeating: "・", count: dots))
                    .font(AppFont.hand(20))
                    .foregroundStyle(.white)
                Text("写真の中の物を台湾華語にしています")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Spacer()
        }
        .task {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { sweep = 1 }
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) { ring = true }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(420))
                dots = (dots + 1) % 4
            }
        }
    }
}
