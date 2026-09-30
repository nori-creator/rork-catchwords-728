import SwiftUI

/// Home album wallpaper (wallpaper.ts): paper / notebook / wall / frame / cork. Stored per device.
enum Wallpaper: String, CaseIterable, Identifiable {
    case paper, notebook, wall, frame, cork
    static let key = "album.bg"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .paper: "紙"
        case .notebook: "ノート"
        case .wall: "壁"
        case .frame: "額縁"
        case .cork: "コルクと画鋲"
        }
    }

    /// Extra inner padding so prints sit inside the frame's wood + mat.
    var inset: CGFloat { self == .frame ? 26 : 0 }
}

/// The wall itself, drawn at any size (album page or settings swatch).
struct WallpaperSurface: View {
    let kind: Wallpaper
    var cornerRadius: CGFloat = 30
    /// 1 on the album page, smaller on swatches so ruled lines / frame scale down.
    var scale: CGFloat = 1

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: kind == .frame ? 4 : cornerRadius, style: .continuous)
        shape.fill(.clear)
            .background {
                switch kind {
                case .paper:
                    RadialGradient(colors: [Color(hex: 0xFFFDF8), Color(hex: 0xFBF8F1), Color(hex: 0xF3EEE3)],
                                   center: UnitPoint(x: 0.18, y: 0.08), startRadius: 0, endRadius: 520 * scale)
                case .notebook:
                    Canvas { ctx, size in
                        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xFDFBF3)))
                        let step = 28 * scale
                        var y = step
                        while y < size.height {
                            ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Color(hex: 0xDBE7F1)))
                            y += step
                        }
                        let x = kind == .notebook && scale < 1 ? size.width * 0.5 : 56
                        ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(Color(hex: 0xF3C6C6)))
                    }
                case .wall:
                    LinearGradient(colors: [Color(hex: 0xF6F3EE), Color(hex: 0xE9E4DB)], startPoint: .top, endPoint: .bottom)
                case .frame:
                    ZStack {
                        Color(hex: 0x6B4423)
                        Rectangle().fill(Color(hex: 0xC9A45C)).padding(12 * scale)
                        Rectangle().fill(Color(hex: 0x5A381C)).padding(14 * scale)
                        Rectangle().fill(Color(hex: 0xFBF8F1)).padding(16 * scale)
                            .shadow(color: .black.opacity(0.18), radius: 8 * scale, y: 3 * scale)
                    }
                case .cork:
                    Canvas { ctx, size in
                        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xD8B184)))
                        let specs: [(CGFloat, CGFloat, CGFloat, Color)] = [
                            (18, 0.1, 0.2, .black.opacity(0.18)), (22, 0.8, 0.6, .white.opacity(0.2)), (26, 0.4, 0.8, .black.opacity(0.12)),
                        ]
                        for (cell, fx, fy, color) in specs {
                            let c = cell * max(scale, 0.7)
                            var y: CGFloat = 0
                            while y < size.height {
                                var x: CGFloat = 0
                                while x < size.width {
                                    ctx.fill(Path(ellipseIn: CGRect(x: x + c * fx, y: y + c * fy, width: 2, height: 2)), with: .color(color))
                                    x += c
                                }
                                y += c
                            }
                        }
                    }
                }
            }
            .clipShape(shape)
    }
}

/// Settings swatch: the wall with one sample print pinned the way that wall pins things.
struct WallpaperSwatch: View {
    let kind: Wallpaper
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                WallpaperSurface(kind: kind, cornerRadius: 16, scale: 0.45)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .overlay {
                        GeometryReader { g in
                            samplePrint(width: g.size.width * 0.58)
                                .position(x: g.size.width / 2, y: g.size.height * 0.45)
                        }
                    }
                    .shadow(color: kind == .frame ? .black.opacity(0.3) : .clear, radius: 8, y: 5)
                    .overlay {
                        RoundedRectangle(cornerRadius: kind == .frame ? 4 : 16, style: .continuous)
                            .stroke(isSelected ? Theme.primary : Theme.border, lineWidth: isSelected ? 2.5 : 1)
                            .padding(isSelected ? -3 : 0)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Theme.primary, in: Circle())
                                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                                .padding(6)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                Text(kind.label).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.foreground)
            }
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .accessibilityLabel(kind.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func samplePrint(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(hex: 0x9FB8C8))
            .padding(4)
            .frame(width: width, height: width * 0.8)
            .background(Color(hex: 0xFFFEFB))
            .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
            .overlay(alignment: .top) {
                switch kind {
                case .cork:
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0x6FA8FF), Color(hex: 0x1E4FB8)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 7))
                        .frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1.5)
                        .offset(y: -4)
                case .frame:
                    EmptyView()
                default:
                    HStack {
                        tape(Color(hex: 0xB9B7E8)).rotationEffect(.degrees(-28)).offset(x: -8)
                        Spacer()
                        tape(Color(hex: 0xC5D9B8)).rotationEffect(.degrees(24)).offset(x: 8)
                    }
                    .offset(y: -2)
                }
            }
            .rotationEffect(.degrees(-3))
    }

    private func tape(_ c: Color) -> some View {
        Rectangle().fill(c.opacity(0.85))
            .overlay(HStack(spacing: 2) { ForEach(0..<6, id: \.self) { _ in Rectangle().fill(.white.opacity(0.35)).frame(width: 1) } })
            .frame(width: 30, height: 9)
    }
}
