import SwiftUI

/// Candidates pinned onto the photo at their AI coordinates, plus a list in the thumb zone.
struct CandidatePickerView: View {
    let vm: CaptureViewModel
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { vm.reset() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .glassCard(22)
                }
                .buttonStyle(PressableStyle())
                Spacer()
                Text("どれを捕まえる？")
                    .font(AppFont.hand(20))
                    .foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if let photo = vm.photo {
                GeometryReader { geo in
                    let fit = fittedRect(image: photo.size, in: geo.size)
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(width: fit.width, height: fit.height)
                            .clipShape(.rect(cornerRadius: 22))
                            .position(x: fit.midX, y: fit.midY)
                        ForEach(Array(vm.candidates.enumerated()), id: \.element.id) { idx, c in
                            Button { vm.pick(c) } label: {
                                PinLabel(text: c.headword)
                            }
                            .buttonStyle(PressableStyle(scale: 0.9))
                            .position(x: fit.minX + fit.width * c.point[0] / 1000,
                                      y: fit.minY + fit.height * c.point[1] / 1000)
                            .scaleEffect(appeared ? 1 : 0.2)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.45, dampingFraction: 0.62).delay(Double(idx) * 0.06), value: appeared)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                Spacer()
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(vm.candidates.enumerated()), id: \.element.id) { idx, c in
                        Button { vm.pick(c) } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.zhuyin).font(.system(size: 11)).foregroundStyle(Theme.muted)
                                    Text(c.headword).font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.meaningJa).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                                    Text(c.pinyin).font(AppFont.mono(12)).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.primary)
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 64)
                            .glassCard(18)
                        }
                        .buttonStyle(PressableStyle())
                        .offset(y: appeared ? 0 : 30)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1 + Double(idx) * 0.05), value: appeared)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .frame(maxHeight: 290)
        }
        .onAppear { appeared = true }
    }

    private func fittedRect(image: CGSize, in box: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0 else { return CGRect(origin: .zero, size: box) }
        let s = min(box.width / image.width, box.height / image.height)
        let w = image.width * s
        let h = image.height * s
        return CGRect(x: (box.width - w) / 2, y: (box.height - h) / 2, width: w, height: h)
    }
}

struct PinLabel: View {
    let text: String
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(text)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(Theme.primary, in: Capsule())
                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            Circle()
                .fill(.white)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(Theme.primary, lineWidth: 2).scaleEffect(pulse ? 2.4 : 1).opacity(pulse ? 0 : 1))
        }
        .frame(minWidth: 44, minHeight: 44)
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}
