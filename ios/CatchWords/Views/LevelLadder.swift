import SwiftUI

/// The word's exam level as six steps in three bands (web TocflLadder + level-scale.ts): TOCFL for
/// 台湾華語, CEFR for English, JLPT for Japanese. Folded it is one chip the size of the part-of-speech
/// chip (「3級（Band B）」); a tap opens the steps.
struct LevelLadder: View {
    let level: String?
    /// The word's learning language (decides the scale).
    let language: String
    @State private var open: Bool = false

    private struct Scale {
        let id: String
        let labels: [String]
    }

    private var scale: Scale {
        switch language {
        case "en": Scale(id: "CEFR", labels: ["A1", "A2", "B1", "B2", "C1", "C2"])
        case "ja": Scale(id: "JLPT", labels: ["N5", "N4", "N3", "N2", "N1", "N1+"])
        default: Scale(id: "TOCFL", labels: ["1", "2", "3", "4", "5", "6"])
        }
    }

    /// 1…6, 0 = outside the lists, nil = no level (parseLevelStep).
    static func step(_ raw: String?) -> Int? {
        let s = (raw ?? "").trimmingCharacters(in: .whitespaces).uppercased()
        guard !s.isEmpty else { return nil }
        if let r = s.range(of: #"(^|[^A-Z])N([1-5])(\+?)(?![0-9])"#, options: .regularExpression) {
            let m = String(s[r])
            let digit = m.first { $0.isNumber }.flatMap { Int(String($0)) } ?? 5
            return digit == 1 && m.hasSuffix("+") ? 6 : 6 - digit
        }
        if let r = s.range(of: #"\b[ABC][12]\b"#, options: .regularExpression) {
            let m = Array(s[r])
            let band = ["A", "B", "C"].firstIndex(of: String(m[0])) ?? 0
            return band * 2 + (Int(String(m[1])) ?? 1)
        }
        guard let r = s.range(of: #"\d+"#, options: .regularExpression), let n = Int(s[r]) else { return nil }
        return (1...6).contains(n) ? n : 0
    }

    private static func band(_ step: Int) -> String { step <= 2 ? "A" : step <= 4 ? "B" : "C" }

    private static let colors: [Color] = [
        Color(hex: 0x6FD3DB), Color(hex: 0x5CB4E8), Color(hex: 0x6C95EE),
        Color(hex: 0x8077E6), Color(hex: 0x9461D6), Color(hex: 0xA14DBF),
    ]

    private func label(_ step: Int) -> String {
        let n = scale.labels[step - 1]
        let b = Self.band(step)
        // TOCFL counts in 級; CEFR and JLPT steps are names of their own (web cefr.levelInBand).
        return scale.id == "TOCFL" ? L("\(n)級（Band \(b)）") : L("\(n)（Band \(b)）")
    }

    private var outLabel: String {
        switch scale.id {
        case "CEFR": L("CEFR の外の語")
        case "JLPT": L("JLPT の外の語")
        default: L("級外の語")
        }
    }

    /// TOEFL / IELTS rough equivalents of a CEFR step (CEFR_EXAM_MAP).
    private func exams(_ step: Int) -> String {
        guard scale.id == "CEFR" else { return "" }
        let map: [(String?, String?)] = [(nil, nil), (nil, "3.0–3.5"), ("42–71", "4.0–5.0"), ("72–94", "5.5–6.5"), ("95–120", "7.0–8.0"), (nil, "8.5–9.0")]
        let e = map[step - 1]
        return [e.0.map { "TOEFL \($0)" }, e.1.map { "IELTS \($0)" }].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        if let step = Self.step(level) {
            if step == 0 {
                chip(Text(outLabel), expandable: false)
            } else if open {
                ladder(step)
            } else {
                chip(Text(label(step)), expandable: true)
            }
        }
    }

    private func chip(_ text: Text, expandable: Bool) -> some View {
        Button {
            guard expandable else { return }
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { open = true }
        } label: {
            HStack(spacing: 4) {
                Text(scale.id).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
                text.font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.foreground)
                if expandable {
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Theme.secondary, in: Capsule())
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .disabled(!expandable)
        .accessibilityLabel("\(scale.id) \(stepText(level))")
        .accessibilityHint(expandable ? L("段階を見る") : "")
    }

    private func stepText(_ raw: String?) -> String {
        guard let s = Self.step(raw) else { return "" }
        return s == 0 ? outLabel : label(s)
    }

    private func ladder(_ active: Int) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { open = false }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom, spacing: 8) {
                    Text(scale.id).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
                        .padding(.bottom, 16)
                    ForEach(["A", "B", "C"], id: \.self) { b in
                        VStack(spacing: 2) {
                            HStack(alignment: .bottom, spacing: 4) {
                                ForEach((1...6).filter { Self.band($0) == b }, id: \.self) { s in
                                    VStack(spacing: 3) {
                                        UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                                            .fill(Self.colors[s - 1])
                                            .frame(width: scale.id == "TOCFL" ? 16 : 22,
                                                   height: CGFloat(10 + (0.35 + 0.65 * Double(s - 1) / 5) * 18))
                                            .opacity(s == active ? 1 : 0.25)
                                            .overlay(
                                                UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                                                    .stroke(Theme.foreground, lineWidth: s == active ? 2 : 0)
                                                    .padding(-1.5)
                                            )
                                        Text(scale.labels[s - 1])
                                            .font(.system(size: 10, weight: s == active ? .bold : .regular))
                                            .foregroundStyle(s == active ? Theme.foreground : Theme.muted)
                                    }
                                }
                            }
                            Text(b).font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.muted)
                        }
                    }
                    Image(systemName: "chevron.up").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.muted)
                        .padding(.bottom, 16)
                }
                Text(label(active)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.foreground)
                let e = exams(active)
                if !e.isEmpty {
                    Text(e).font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
            }
            .padding(10)
            .background(Theme.secondary.opacity(0.6), in: .rect(cornerRadius: 14))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(scale.id) \(label(active))")
        .accessibilityHint(L("段階を閉じる"))
    }
}

/// Exams a word outside the level lists appears in (web exam-tags.ts), at most 4.
enum ExamTags {
    static func labels(_ tags: [String]?) -> [String] {
        let have = Set((tags ?? []).map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
        let known: [(String, String)] = [
            ("toefl", "TOEFL"), ("ielts", "IELTS"), ("gre", "GRE"), ("cet4", "CET-4"), ("cet6", "CET-6"),
            ("zk", L("中学")), ("gk", L("高校")), ("ky", L("大学院")),
        ]
        return Array(known.filter { have.contains($0.0) }.map(\.1).prefix(4))
    }
}
