import SwiftUI

/// home.tsx: bookshelf of months → today's date → today's album page → past pages.
struct HomeView: View {
    @Environment(DexStore.self) private var dex
    @Environment(ProfileStore.self) private var profile
    @Environment(AppRouter.self) private var router

    private var days: [(day: Date, items: [Sticker])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: dex.stickers) { cal.startOfDay(for: $0.takenAt) }
        return grouped.keys.sorted(by: >).map { d in (d, grouped[d]?.sorted { $0.takenAt > $1.takenAt } ?? []) }
    }

    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let todayItems = days.first { $0.day == today }?.items ?? []
        let past = days.filter { $0.day != today }.prefix(45)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 64)
                    Bookshelf(stickers: dex.stickers) { month in
                        let cal = Calendar.current
                        if let target = past.first(where: { cal.isDate($0.day, equalTo: month, toGranularity: .month) }) {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                                proxy.scrollTo(target.day, anchor: .top)
                            }
                        } else {
                            withAnimation { proxy.scrollTo("today", anchor: .top) }
                        }
                    }
                    .padding(.bottom, 28)

                    VStack(spacing: 2) {
                        Text(JPDate.weekday(today))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.primaryInk)
                        Text(JPDate.monthDay(today))
                            .font(.system(size: 50, weight: .heavy))
                            .foregroundStyle(Color(hex: 0x33291F))
                            .monospacedDigit()
                    }
                    .padding(.bottom, 18)
                    .id("today")

                    AlbumPage(items: todayItems, isToday: true) { router.detailSticker = $0 } onCamera: {
                        router.tab = .camera
                    }
                    .padding(.horizontal, 16)

                    if !past.isEmpty {
                        HStack(spacing: 12) {
                            Rectangle().fill(Color(hex: 0x33291F, opacity: 0.12)).frame(height: 1)
                            Text("これまでのページ").font(.system(size: 13)).foregroundStyle(Color(hex: 0x33291F, opacity: 0.55)).fixedSize()
                            Rectangle().fill(Color(hex: 0x33291F, opacity: 0.12)).frame(height: 1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 40)
                        .padding(.bottom, 20)

                        LazyVStack(spacing: 28) {
                            ForEach(Array(past), id: \.day) { entry in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(JPDate.monthDayWeek(entry.day))
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(Color(hex: 0x33291F))
                                        .padding(.leading, 6)
                                    AlbumPage(items: entry.items, isToday: false) { router.detailSticker = $0 } onCamera: {}
                                }
                                .id(entry.day)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    Color.clear.frame(height: 120)
                }
            }
            .refreshable { await dex.load() }
        }
        .background(HomeBackground())
        .overlay(alignment: .top) { header }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { router.tab = .settings } label: { AvatarView(url: profile.avatarURL, size: 38) }
                .buttonStyle(PressableStyle(scale: 0.92))
                .accessibilityLabel("設定")
            Text("CatchWords")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.muted)
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background {
            Rectangle().fill(.ultraThinMaterial)
                .mask(LinearGradient(colors: [.black, .black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea(edges: .top)
        }
    }
}

struct HomeBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xF7F9FC), Color(hex: 0xEFE6D8)], startPoint: .top, endPoint: .init(x: 0.5, y: 0.35))
            RadialGradient(colors: [Color(hex: 0xFFFFFF, opacity: 0.5), .clear], center: .center, startRadius: 20, endRadius: 500)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Bookshelf

/// Bookshelf.tsx: a wooden box with one spine per month (2026 / MONTH / count), a globe and the latest photo in a frame.
struct Bookshelf: View {
    @Environment(DexStore.self) private var dex
    let stickers: [Sticker]
    let onMonth: (Date) -> Void

    private static let spineColors: [UInt32] = [0xD9663F, 0x8E4FB0, 0x74A84C, 0x4F6FA6, 0xC9A23A, 0x3F8F8A]

    private var months: [(month: Date, count: Int)] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: stickers) { cal.date(from: cal.dateComponents([.year, .month], from: $0.takenAt)) ?? $0.takenAt }
        return grouped.keys.sorted().suffix(5).map { ($0, grouped[$0]?.count ?? 0) }
    }

    var body: some View {
        let latest = stickers.first
        ZStack {
            // Outer wood frame
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Color(hex: 0xC08A58), Color(hex: 0x9A6A3E)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.28), radius: 14, x: 8, y: 14)
            // Back panel
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(hex: 0x5A3A22), Color(hex: 0x7A5233)], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom).frame(height: 30)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(LinearGradient(colors: [Color(hex: 0xB07E4E), Color(hex: 0x8C603A)], startPoint: .top, endPoint: .bottom))
                        .frame(height: 16)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            HStack(alignment: .bottom, spacing: 2) {
                if months.isEmpty {
                    Text("最初の1冊はまだ白紙です")
                        .font(AppFont.hand(15))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(Array(months.enumerated()), id: \.element.month) { i, m in
                        Button {
                            Haptics.selection()
                            SoundService.shared.play(.bookOpen, volume: 0.35)
                            onMonth(m.month)
                        } label: {
                            BookSpine(month: m.month, count: m.count, color: Color(hex: Self.spineColors[i % Self.spineColors.count]))
                        }
                        .buttonStyle(PressableStyle(scale: 0.95))
                    }
                    Rectangle().fill(Color(hex: 0x3E2A18)).frame(width: 6, height: 82).padding(.leading, 2)
                    Spacer(minLength: 8)
                    Globe().padding(.bottom, 2)
                    Spacer(minLength: 8)
                }
                if let latest {
                    let path = latest.objectImageUrl ?? latest.cutoutImageUrl
                    Color.white
                        .frame(width: 54, height: 66)
                        .overlay {
                            Theme.secondary.padding(5)
                                .overlay { StickerImage(path: path, url: dex.url(for: path), contentMode: .fill).allowsHitTesting(false).padding(5) }
                                .clipped()
                        }
                        .overlay(Rectangle().stroke(Color(hex: 0xA57A4E), lineWidth: 4))
                        .shadow(color: .black.opacity(0.35), radius: 3, x: 2, y: 2)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 28)
            .padding(.top, 24)
        }
        .frame(height: 190)
        .overlay(alignment: .topLeading) {
            VStack(spacing: -4) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: i.isMultiple(of: 2) ? 0x3E8E41 : 0x5AAE4F))
                        .rotationEffect(.degrees(i.isMultiple(of: 2) ? -35 : 25))
                        .offset(x: i.isMultiple(of: 2) ? 0 : 6)
                }
            }
            .offset(x: -6, y: -4)
        }
        .padding(.horizontal, 14)
    }
}

struct BookSpine: View {
    let month: Date
    let count: Int
    let color: Color

    var body: some View {
        let year = Calendar.current.component(.year, from: month)
        VStack(spacing: 6) {
            Rectangle().fill(Color(hex: 0xE8C66A).opacity(0.8)).frame(height: 1.5)
            Text(String(year)).font(.system(size: 7, weight: .bold, design: .serif)).foregroundStyle(Color(hex: 0xF3D98A))
            Text(JPDate.monthName(month))
                .font(.system(size: 9, weight: .bold, design: .serif))
                .foregroundStyle(Color(hex: 0xF3D98A))
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 14, height: 56)
            Spacer(minLength: 0)
            Text("\(count)")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(Color(hex: 0xF3D98A))
                .frame(width: 15, height: 15)
                .overlay(Circle().stroke(Color(hex: 0xE8C66A), lineWidth: 1))
            Rectangle().fill(Color(hex: 0xE8C66A).opacity(0.8)).frame(height: 1.5)
        }
        .padding(.vertical, 6)
        .frame(width: 30, height: 120)
        .background(
            LinearGradient(colors: [color.mix(with: .black, by: 0.2), color, color.mix(with: .white, by: 0.12), color.mix(with: .black, by: 0.25)],
                           startPoint: .leading, endPoint: .trailing),
            in: .rect(cornerRadius: 3)
        )
        .shadow(color: .black.opacity(0.35), radius: 2, x: 2)
        .accessibilityLabel("\(JPDate.monthName(month)) \(count)語")
    }
}

private struct Globe: View {
    @State private var spin: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xA8DDF5), Color(hex: 0x3D8FC4)], center: .init(x: 0.35, y: 0.3), startRadius: 2, endRadius: 36))
                .overlay {
                    Image(systemName: "globe.asia.australia.fill")
                        .resizable().scaledToFit()
                        .foregroundStyle(Color(hex: 0xF0E3B0).opacity(0.85))
                        .padding(4)
                        .rotation3DEffect(.degrees(spin ? 360 : 0), axis: (x: 0, y: 1, z: 0))
                }
                .clipShape(Circle())
                .frame(width: 46, height: 46)
            Rectangle().fill(Color(hex: 0xC9A24A)).frame(width: 3, height: 10)
            Ellipse().fill(Color(hex: 0xA0522D)).frame(width: 28, height: 7)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) { spin = true }
        }
    }
}

// MARK: - Album page

/// A day's page: photo prints (white border + corners / tape) — words without a photo sit on the paper as text only.
struct AlbumPage: View {
    let items: [Sticker]
    let isToday: Bool
    let onOpen: (Sticker) -> Void
    let onCamera: () -> Void
    @AppStorage(Wallpaper.key) private var wallRaw: String = Wallpaper.paper.rawValue

    var body: some View {
        let wall = Wallpaper(rawValue: wallRaw) ?? .paper
        VStack(spacing: 0) {
            if items.isEmpty {
                VStack(spacing: 16) {
                    Text("今日のページはまだ白紙です。")
                        .font(AppFont.hand(20))
                        .foregroundStyle(Color(hex: 0x33291F).opacity(0.7))
                    if isToday {
                        Button(action: onCamera) {
                            Label("今日の1枚を撮る", systemImage: "camera.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 22)
                                .frame(minHeight: 48)
                                .background(Theme.primary, in: Capsule())
                                .shadow(color: Theme.primary.opacity(0.35), radius: 10, y: 5)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                layout
            }
        }
        .padding(14 + wall.inset)
        .background {
            WallpaperSurface(kind: wall)
                .shadow(color: Color(hex: 0x5A4630, opacity: wall == .frame ? 0.35 : 0.18), radius: 16, y: 8)
        }
    }

    @ViewBuilder
    private var layout: some View {
        let first = items[0]
        let side = Array(items.dropFirst().prefix(2))
        let rest = Array(items.dropFirst(3))
        GeometryReader { geo in
            let w = geo.size.width
            HStack(alignment: .top, spacing: 10) {
                AlbumPrint(sticker: first, style: .tape, width: w * 0.58, onOpen: onOpen)
                    .rotationEffect(.degrees(-1))
                VStack(spacing: 14) {
                    ForEach(side) { s in
                        AlbumPrint(sticker: s, style: .corners, width: w * 0.38, onOpen: onOpen)
                            .rotationEffect(.degrees(tilt(s)))
                    }
                }
                .padding(.top, 20)
            }
        }
        .frame(height: topHeight(sideCount: side.count))

        if !rest.isEmpty {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                ForEach(rest) { s in
                    GeometryReader { geo in
                        AlbumPrint(sticker: s, style: s.id.hashValue.isMultiple(of: 2) ? .corners : .tape, width: geo.size.width, onOpen: onOpen)
                            .rotationEffect(.degrees(tilt(s)))
                    }
                    .aspectRatio(0.8, contentMode: .fit)
                }
            }
            .padding(.top, 16)
        }
    }

    private func topHeight(sideCount: Int) -> CGFloat {
        let screen = UIScreen.main.bounds.width - 60
        let big = screen * 0.58 * 1.2 + 20
        let small = CGFloat(sideCount) * (screen * 0.38 * 1.32 + 14) + 20
        return max(big, small)
    }

    private func tilt(_ s: Sticker) -> Double {
        let h = abs(s.id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        return Double(h % 5) - 2
    }
}

enum PrintStyle { case tape, corners }

struct AlbumPrint: View {
    @Environment(DexStore.self) private var dex
    let sticker: Sticker
    let style: PrintStyle
    let width: CGFloat
    let onOpen: (Sticker) -> Void

    var body: some View {
        let path = sticker.objectImageUrl ?? sticker.cutoutImageUrl
        Button { onOpen(sticker) } label: {
            if path == nil {
                // No photo: the word written straight on the paper — no print, no rule.
                VStack(spacing: 4) {
                    Text(sticker.word?.headword ?? "").font(.system(size: 26, weight: .bold)).foregroundStyle(Color(hex: 0x33291F))
                    Text(JPDate.time(sticker.takenAt)).font(.system(size: 12)).foregroundStyle(Color(hex: 0x33291F).opacity(0.55))
                }
                .frame(width: width, height: width * 0.8)
            } else {
                VStack(spacing: 6) {
                    Theme.secondary
                        .frame(width: width - 14, height: (width - 14) * 1.08)
                        .overlay {
                            StickerImage(path: path, url: dex.url(for: path), contentMode: sticker.objectImageUrl == nil ? .fit : .fill)
                                .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 3))
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(sticker.word?.headword ?? "")
                            .font(.system(size: width > 160 ? 21 : 16, weight: .bold))
                            .foregroundStyle(Color(hex: 0x241C14))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(JPDate.time(sticker.takenAt))
                            .font(.system(size: width > 160 ? 13 : 11))
                            .foregroundStyle(Color(hex: 0x241C14).opacity(0.6))
                    }
                    .padding(.bottom, 4)
                }
                .padding(7)
                .background(Color(hex: 0xFFFEFB))
                .overlay { LinearGradient(colors: [.white.opacity(0.25), .clear, .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing).allowsHitTesting(false) }
                .shadow(color: .black.opacity(0.16), radius: 5, x: 1, y: 3)
                .overlay(alignment: .top) {
                    if style == .tape {
                        Rectangle()
                            .fill(Color(hex: 0xC9D6EE, opacity: 0.85))
                            .overlay(
                                HStack(spacing: 3) { ForEach(0..<14, id: \.self) { _ in Rectangle().fill(.white.opacity(0.35)).frame(width: 1.5) } }
                            )
                            .frame(width: min(90, width * 0.4), height: 18)
                            .rotationEffect(.degrees(-2))
                            .offset(y: -9)
                    }
                }
                .overlay {
                    if style == .corners { PhotoCorners() }
                }
            }
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .accessibilityLabel(sticker.word?.headword ?? "写真")
    }
}

/// Four dark triangular photo corners.
private struct PhotoCorners: View {
    var body: some View {
        GeometryReader { geo in
            let s: CGFloat = 22
            let color = Color(hex: 0x4A3C30)
            ForEach(0..<4, id: \.self) { i in
                Path { p in
                    p.move(to: .zero)
                    p.addLine(to: CGPoint(x: s, y: 0))
                    p.addLine(to: CGPoint(x: 0, y: s))
                    p.closeSubpath()
                }
                .fill(color)
                .frame(width: s, height: s)
                .rotationEffect(.degrees(Double(i) * 90))
                .position(
                    x: (i == 0 || i == 3) ? s / 2 - 5 : geo.size.width - s / 2 + 5,
                    y: (i == 0 || i == 1) ? s / 2 - 5 : geo.size.height - s / 2 + 5
                )
            }
        }
        .allowsHitTesting(false)
    }
}
