import SwiftUI

/// Two independent instruments on one dashboard (単語詳細のメーター plan):
/// a 5-segment frequency gauge and a written⇄spoken axis gauge with a needle.
struct MetersPanel: View {
    let extras: WordExtras
    @State private var animate: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let f = extras.frequencyLevel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("よく使う度").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(1...5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(i <= f && animate ? Theme.primary : Theme.border)
                                .frame(height: 8 + CGFloat(i) * 5)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(i) * 0.06), value: animate)
                        }
                    }
                    .frame(height: 34)
                    Text(frequencyLabel(f)).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.foreground)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: .rect(cornerRadius: Theme.radius))
            }
            if let r = extras.resolvedRegister {
                VStack(alignment: .leading, spacing: 10) {
                    Text("書き言葉 ⇄ 話し言葉").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
                    GeometryReader { geo in
                        let pos = animate ? CGFloat(2 - r) / 4 : 0.5
                        ZStack(alignment: .leading) {
                            Capsule().fill(LinearGradient(colors: [Theme.chunkO.opacity(0.4), Theme.chunkV.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                                .frame(height: 6)
                            HStack(spacing: 0) {
                                ForEach(0..<5, id: \.self) { i in
                                    Rectangle().fill(Theme.muted.opacity(0.35)).frame(width: 1, height: 12)
                                    if i < 4 { Spacer() }
                                }
                            }
                            Capsule()
                                .fill(Theme.foreground)
                                .frame(width: 4, height: 26)
                                .shadow(color: Theme.primary, radius: 5)
                                .offset(x: pos * (geo.size.width - 4))
                                .animation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.62), value: animate)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(height: 34)
                    Text(registerLabel(r)).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.foreground)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: .rect(cornerRadius: Theme.radius))
            }
        }
        .onAppear { animate = true }
    }

    private func frequencyLabel(_ f: Int) -> String {
        switch f {
        case 5: "毎日のように"
        case 4: "よく出会う"
        case 3: "ときどき"
        case 2: "たまに"
        default: "まれ"
        }
    }

    private func registerLabel(_ r: Int) -> String {
        switch r {
        case -2: "話し言葉"
        case -1: "やや話し言葉"
        case 0: "どちらでも"
        case 1: "やや書き言葉"
        default: "書き言葉"
        }
    }
}
