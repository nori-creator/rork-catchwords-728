import SwiftUI

/// home.tsx: bookshelf of months → today's date → today's album page → past pages.
struct HomeView: View {
    @Environment(DexStore.self) private var dex
    @Environment(ProfileStore.self) private var profile
    @Environment(DiaryStore.self) private var diary
    @Environment(AppRouter.self) private var router
    @State private var writingDay: WritingDay?
    @State private var showJournal = false
    @State private var showStats = false
    @State private var memorialOpen: Int?
    @State private var memorialHidden = false
    @State private var openMonth: MonthOpen?
    private struct MonthOpen: Identifiable {
        let month: Date
        var id: Date { month }
    }

    private struct MemorialDay: Identifiable {
        let n: Int
        var id: Int { n }
    }

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        ScrollView {
            VStack(spacing: 0) {
                Color.clear.frame(height: 64)
                // Past months stand on the shelf; this month's book lies open below.
                Bookshelf(stickers: dex.stickers.filter { !cal.isDate($0.takenAt, equalTo: today, toGranularity: .month) }) { month in
                    openMonth = MonthOpen(month: month)
                }
                .padding(.bottom, 22)

                if let n = profile.createdAt.flatMap({ Milestone.today(start: $0) }),
                   !memorialHidden, !Milestone.wasDismissed(n) {
                    MemorialBanner(n: n, words: dex.stickers.count, photos: Milestone.highlights(dex.stickers).count) {
                        Haptics.impact(.medium)
                        memorialOpen = n
                    } onDismiss: {
                        Milestone.dismiss(n)
                        withAnimation(.snappy) { memorialHidden = true }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Photos kept at the shutter whose analysis has not finished (web Home pending banner).
                if !dex.pending.isEmpty {
                    Button {
                        router.openPending = true
                        router.tab = .camera
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "hourglass").font(.system(size: 15, weight: .semibold))
                            Text(L("解析待ちの写真が\(dex.pending.count)枚あります"))
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: 0x33291F))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        .background(Color(hex: 0xF3D98A, opacity: 0.45), in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(L("\(JPDate.month(today))のアルバム"))
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Color(hex: 0x33291F))
                    Spacer()
                    Text(L("横にスワイプでページをめくる"))
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: 0x33291F, opacity: 0.5))
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 8)

                Group {
                    if let err = dex.loadError, dex.stickers.isEmpty {
                        // Nothing to show yet and the dex could not be read: say so, offer a retry.
                        AlbumLoadFailed(message: err) { Task { await dex.load() } }
                    } else if !dex.hasLoaded, dex.stickers.isEmpty {
                        AlbumSkeleton()
                    } else {
                        MonthBookView(
                            days: BookDay.days(in: today, stickers: dex.albumStickers, diaryDays: diary.dayKeys),
                            startAtEnd: true,
                            onOpen: { router.detailSticker = $0 },
                            onWrite: { writingDay = WritingDay(date: $0) },
                            onCamera: { router.tab = .camera }
                        )
                        .transition(.opacity)
                    }
                }
                .frame(height: max(520, UIScreen.main.bounds.height * 0.66))
                .padding(.horizontal, 12)
                .animation(.easeOut(duration: 0.3), value: dex.hasLoaded)
                .tourAnchor(.album)

                Button { showJournal = true } label: {
                    Label(L("過去の日記と添削"), systemImage: "books.vertical")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x33291F, opacity: 0.7))
                        .frame(minHeight: 44)
                }
                .buttonStyle(PressableStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 8)

                StrandedDiaryBanner { writingDay = WritingDay(date: $0) }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                AlbumHiddenTray()
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Color.clear.frame(height: 120)
            }
        }
        .refreshable { await dex.load() }
        .background(HomeBackground())
        .overlay(alignment: .top) { header }
        .sheet(item: $writingDay) { d in
            DiaryComposer(day: d.date)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showJournal) {
            JournalHistoryView()
        }
        .fullScreenCover(item: $openMonth) { m in
            MonthBookSheet(month: m.month) { s in
                openMonth = nil
                router.detailSticker = s
            }
        }
        .fullScreenCover(item: Binding(get: { memorialOpen.map(MemorialDay.init) }, set: { memorialOpen = $0?.n })) { m in
            MemorialAlbumView(n: m.n, words: dex.stickers.count, picks: Milestone.highlights(dex.stickers)) { s in
                memorialOpen = nil
                router.detailSticker = s
            } onClose: {
                memorialOpen = nil
            }
        }
        .task(id: profile.createdAt) {
            if let start = profile.createdAt { await Milestone.scheduleNotification(start: start) }
        }
        .sheet(isPresented: $showStats) {
            UserStatsPanel(
                onSettings: { showStats = false; router.tab = .settings },
                onReview: { showStats = false; router.tab = .review }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { Haptics.selection(); showStats = true } label: { AvatarView(url: profile.avatarURL, size: 38) }
                .buttonStyle(PressableStyle(scale: 0.92))
                .accessibilityLabel(L("あなたの記録"))
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


struct WritingDay: Identifiable {
    let date: Date
    var id: String { DiaryStore.key(date) }
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
                    Text(L("先月までの本がここに並びます"))
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
            spineMonth
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
        .accessibilityLabel(L("\(JPDate.month(month)) \(count)語"))
    }

    /// The month on the spine in the display language: English runs along the spine, Japanese and
    /// Chinese stand upright one character under another (縦書き).
    @ViewBuilder private var spineMonth: some View {
        if L10n.lang == "en" {
            Text(JPDate.monthName(month))
                .font(.system(size: 9, weight: .bold, design: .serif))
                .foregroundStyle(Color(hex: 0xF3D98A))
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 14, height: 56)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(JPDate.month(month).enumerated()), id: \.offset) { _, ch in
                    Text(String(ch))
                }
            }
            .font(.system(size: 10, weight: .bold, design: .serif))
            .foregroundStyle(Color(hex: 0xF3D98A))
            .frame(width: 14, height: 56)
        }
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

// MARK: - Album

/// Web `album-hidden-tray`: photos taken off the album, each with 「戻す」. Collapsed by default.
struct AlbumHiddenTray: View {
    @Environment(DexStore.self) private var dex
    @State private var open = false
    @State private var failed = false

    private var hidden: [Sticker] { dex.stickers.filter { dex.albumHidden.contains($0.id) } }

    var body: some View {
        if !hidden.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { open.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "eye.slash")
                        Text(L("アルバムから外した写真 \(hidden.count)"))
                        Spacer()
                        Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0))
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: 0x33291F).opacity(0.7))
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if open {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(hidden) { s in
                                VStack(spacing: 6) {
                                    let path = s.heroPath
                                    Theme.secondary.frame(width: 84, height: 84)
                                        .overlay { StickerImage(path: path, url: dex.url(for: path), contentMode: .fill).allowsHitTesting(false) }
                                        .clipShape(.rect(cornerRadius: 12))
                                    Text(s.word?.headword ?? "").font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                    Button(L("戻す")) {
                                        Haptics.selection()
                                        Task {
                                            let ok = await dex.setAlbumHidden(s.id, hidden: false)
                                            withAnimation(.easeOut(duration: 0.2)) { failed = !ok }
                                        }
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(minWidth: 44, minHeight: 32)
                                }
                                .frame(width: 84)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    if failed {
                        Text(L("保存できませんでした。通信を確かめてください。"))
                            .font(.system(size: 12)).foregroundStyle(Color(hex: 0xB91C1C))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(hex: 0xFFFBF2).opacity(0.8), in: .rect(cornerRadius: 16, style: .continuous))
        }
    }
}

/// The album's shape while the dex is still loading: a blank page with soft photo frames that shimmer,
/// so the home screen is never an empty white sheet.
struct AlbumSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        let paper = Color(hex: 0xFFFDF8)
        let frame = Color(hex: 0x33291F, opacity: 0.07)
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(paper)
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 18) {
                    RoundedRectangle(cornerRadius: 6).fill(frame).frame(width: 120, height: 16)
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 14).fill(frame).frame(width: 130, height: 130).rotationEffect(.degrees(-4))
                        RoundedRectangle(cornerRadius: 14).fill(frame).frame(width: 118, height: 118).rotationEffect(.degrees(3))
                    }
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 14).fill(frame).frame(width: 112, height: 112).rotationEffect(.degrees(2))
                        RoundedRectangle(cornerRadius: 14).fill(frame).frame(width: 126, height: 126).rotationEffect(.degrees(-3))
                    }
                    RoundedRectangle(cornerRadius: 6).fill(frame).frame(width: 200, height: 12)
                    RoundedRectangle(cornerRadius: 6).fill(frame).frame(width: 150, height: 12)
                }
                .padding(24)
            }
            .overlay {
                // A soft band of light that sweeps across while waiting.
                GeometryReader { geo in
                    // Soft and narrow, so the frames underneath stay visible while it passes.
                    LinearGradient(colors: [.clear, .white.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.3)
                        .offset(x: geo.size.width * phase)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .allowsHitTesting(false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("読み込み中"))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1.5 }
            }
    }
}

/// The album could not be loaded (offline, server down): a calm message and a retry button.
struct AlbumLoadFailed: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color(hex: 0xFFFDF8))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .overlay {
                VStack(spacing: 14) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Color(hex: 0x33291F, opacity: 0.45))
                    Text(L("アルバムを読み込めませんでした"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: 0x33291F))
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: 0x33291F, opacity: 0.6))
                        .multilineTextAlignment(.center)
                    Button(action: onRetry) {
                        Label(L("もう一度読み込む"), systemImage: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 22).frame(minHeight: 48)
                            .background(Theme.primary, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(28)
            }
    }
}
