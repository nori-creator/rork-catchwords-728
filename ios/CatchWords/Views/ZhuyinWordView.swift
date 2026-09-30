import SwiftUI

nonisolated struct ZhuyinUnit: Hashable, Sendable {
    let char: String
    let body: [String]
    let tone: String
    let neutral: Bool
    var hasReading: Bool { !body.isEmpty }
}

/// zhuyin-layout.ts `pairZhuyin`: one syllable per Han character, or nil (then the reading goes below).
nonisolated enum ZhuyinLayout {
    static func isHan(_ c: Character) -> Bool {
        c.unicodeScalars.contains { s in
            (0x3400...0x4DBF).contains(s.value) || (0x4E00...0x9FFF).contains(s.value) || s.value == 0x3005 || s.value == 0x3007
        }
    }

    private static let allowed: CharacterSet = {
        var set = CharacterSet(charactersIn: "ˊˇˋ˙")
        if let a = Unicode.Scalar(0x3105), let b = Unicode.Scalar(0x312F) {
            set.formUnion(CharacterSet(charactersIn: a...b))
        }
        return set
    }()

    static func pair(_ headword: String, _ zhuyin: String?) -> [ZhuyinUnit]? {
        let word = headword.trimmingCharacters(in: .whitespaces)
        guard let reading = zhuyin?.trimmingCharacters(in: .whitespaces), !word.isEmpty, !reading.isEmpty else { return nil }
        let syllables = reading.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let chars = Array(word)
        let hanCount = chars.filter(isHan).count
        guard hanCount > 0, hanCount == syllables.count else { return nil }
        guard syllables.allSatisfy({ $0.unicodeScalars.allSatisfy { allowed.contains($0) } }) else { return nil }
        var i = 0
        var out: [ZhuyinUnit] = []
        for ch in chars {
            guard isHan(ch) else {
                out.append(ZhuyinUnit(char: String(ch), body: [], tone: "", neutral: false))
                continue
            }
            let s = syllables[i]
            i += 1
            var body: [String] = []
            var tone = ""
            var neutral = false
            for c in s {
                if "ˊˇˋ".contains(c) { tone = String(c) } else if c == "˙" { neutral = true } else { body.append(String(c)) }
            }
            out.append(ZhuyinUnit(char: String(ch), body: body, tone: tone, neutral: neutral))
        }
        return out
    }
}

/// ZhuyinWord.tsx: zhuyin stacked vertically to the RIGHT of each character (Taiwan textbook style),
/// tone marks in their own column at the last symbol's height, the neutral dot on top.
struct ZhuyinWordView: View {
    let headword: String
    let zhuyin: String?
    var size: CGFloat = 22
    var weight: Font.Weight = .medium
    var color: Color = Theme.foreground
    var readingColor: Color = Theme.muted

    var body: some View {
        if let units = ZhuyinLayout.pair(headword, zhuyin) {
            HStack(alignment: .center, spacing: size * 0.06) {
                ForEach(Array(units.enumerated()), id: \.offset) { _, u in
                    HStack(alignment: .center, spacing: size * 0.03) {
                        Text(u.char)
                            .font(.system(size: size, weight: weight))
                            .foregroundStyle(color)
                        if u.hasReading { column(u) }
                    }
                }
            }
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(headword)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(headword)
                    .font(.system(size: size, weight: weight))
                    .foregroundStyle(color)
                if let z = zhuyin, !z.isEmpty {
                    Text(z).font(.system(size: max(11, size * 0.42))).foregroundStyle(readingColor)
                }
            }
        }
    }

    private func column(_ u: ZhuyinUnit) -> some View {
        let s = max(7, size * 0.3)
        return HStack(alignment: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if u.neutral {
                    Text("˙").font(.system(size: s)).frame(height: s * 1.02)
                }
                ForEach(Array(u.body.enumerated()), id: \.offset) { _, sym in
                    Text(sym).font(.system(size: s)).frame(height: s * 1.02)
                }
            }
            Text(u.tone.isEmpty ? " " : u.tone)
                .font(.system(size: s))
                .frame(width: s * 0.55, height: s * 1.02)
        }
        .foregroundStyle(readingColor)
    }
}
