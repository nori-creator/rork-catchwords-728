import SwiftUI

enum DexMode: String, CaseIterable, Identifiable {
    case shelf, calendar
    var id: String { rawValue }
    var label: String { self == .shelf ? "棚" : "カレンダー" }
    var icon: String { self == .shelf ? "square.grid.3x3" : "calendar" }
}

struct DexView: View {
    @Environment(DexStore.self) private var dex
    @Environment(AppRouter.self) private var router

    @State private var mode: DexMode = .shelf
    @State private var roomFilter: Room?
    @State private var dayFilter: Date?
    @State private var landedId: String?
    @State private var impactTick: Int = 0

    private var filtered: [Sticker] {
        dex.stickers.filter { s in
            if let roomFilter, s.room != roomFilter { return false }
            if let dayFilter, !Calendar.current.isDate(s.takenAt, inSameDayAs: dayFilter) { return false }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            header
                            filterBar
                            if mode == .shelf {
                                shelves
                            } else {
                                DexCalendarView(stickers: dex.stickers, selectedDay: $dayFilter) { s in
                                    router.detailSticker = s
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120)
                    }
                    .refreshable { await dex.load() }
                    .onChange(of: router.landingStickerId) { _, id in
                        guard let id else { return }
                        land(id, proxy: proxy)
                    }
                    .onAppear {
                        if let id = router.landingStickerId { land(id, proxy: proxy) }
                    }
                }
                if dex.isLoading && !dex.hasLoaded {
                    ProgressView().tint(Theme.muted)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("図鑑")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.foreground)
                Text("\(dex.stickers.count)語 集めました")
                    .font(AppFont.hand(15))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(DexMode.allCases) { m in
                    Button {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { mode = m }
                    } label: {
                        Image(systemName: m.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(mode == m ? .white : Theme.muted)
                            .frame(width: 44, height: 36)
                            .background(mode == m ? Theme.primary : .clear, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(m.label)
                }
            }
            .padding(3)
            .background(Theme.card, in: Capsule())
        }
        .padding(.top, 12)
    }

    /// Filters live behind ONE button (owner note: never let chips eat 3 rows of the dex).
    private var filterBar: some View {
        HStack(spacing: 8) {
            Menu {
                Button("すべての部屋") { withAnimation(.snappy) { roomFilter = nil } }
                ForEach(Room.allCases) { r in
                    Button { withAnimation(.snappy) { roomFilter = r } } label: {
                        Label(r.label, systemImage: r.symbol)
                    }
                }
            } label: {
                filterChip(icon: roomFilter?.symbol ?? "line.3.horizontal.decrease", text: roomFilter?.label ?? "カテゴリー", active: roomFilter != nil)
            }
            if let dayFilter {
                Button { withAnimation(.snappy) { self.dayFilter = nil } } label: {
                    filterChip(icon: "xmark", text: dayFilter.formatted(.dateTime.month().day()), active: true)
                }
            }
            Spacer()
            if !dex.pending.isEmpty {
                Label("\(dex.pending.count)", systemImage: "tray.full")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.gold)
            }
        }
    }

    private func filterChip(icon: String, text: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(active ? .white : Theme.foreground)
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .background(active ? Theme.primary.opacity(0.85) : Theme.card, in: Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
    }

    @ViewBuilder
    private var shelves: some View {
        if let err = dex.loadError, dex.stickers.isEmpty {
            CardSurface {
                VStack(alignment: .leading, spacing: 10) {
                    Label(err, systemImage: "wifi.exclamationmark").foregroundStyle(Theme.foreground)
                    Button("もう一度読み込む") { Task { await dex.load() } }.foregroundStyle(Theme.primary)
                }
            }
        } else if dex.hasLoaded && filtered.isEmpty {
            EmptyDexView(isFiltered: roomFilter != nil || dayFilter != nil) { router.tab = .camera }
        } else {
            ForEach(Room.allCases) { room in
                let items = filtered.filter { $0.room == room }
                if !items.isEmpty {
                    RoomShelf(room: room, stickers: items, landedId: landedId, impactTick: impactTick) { s in
                        router.detailSticker = s
                    }
                }
            }
        }
    }

    private func land(_ id: String, proxy: ScrollViewProxy) {
        // Override any filter that would hide the destination.
        roomFilter = nil
        dayFilter = nil
        mode = .shelf
        router.landingStickerId = nil
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { proxy.scrollTo(id, anchor: .center) }
            try? await Task.sleep(for: .milliseconds(200))
            landedId = id
            try? await Task.sleep(for: .milliseconds(420))
            // Touchdown: "コッ" + heavy haptic, neighbours react.
            SoundService.shared.play(.impact, volume: 0.5)
            Haptics.impact(.heavy)
            impactTick += 1
            try? await Task.sleep(for: .milliseconds(1400))
            landedId = nil
        }
    }
}

struct RoomShelf: View {
    let room: Room
    let stickers: [Sticker]
    let landedId: String?
    let impactTick: Int
    let onTap: (Sticker) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(room.accent).frame(width: 8, height: 8)
                Text(room.label).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.foreground)
                Text("\(stickers.count)").font(AppFont.mono(13)).foregroundStyle(Theme.muted)
            }
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(stickers.enumerated()), id: \.element.id) { idx, s in
                    let landedIndex = stickers.firstIndex { $0.id == landedId }
                    let distance = landedIndex.map { abs($0 - idx) } ?? 99
                    Button { onTap(s) } label: {
                        DexCell(sticker: s, accent: room.accent, isLanding: s.id == landedId,
                                neighborDistance: distance, impactTick: impactTick)
                    }
                    .buttonStyle(PressableStyle(scale: 0.94))
                    .id(s.id)
                }
            }
            // Wooden-ish shelf lip under the grid.
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [room.accent.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 3)
        }
        .padding(14)
        .background(Theme.card.opacity(0.7), in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.border, lineWidth: 1))
    }
}

struct DexCell: View {
    @Environment(DexStore.self) private var dex
    let sticker: Sticker
    let accent: Color
    let isLanding: Bool
    let neighborDistance: Int
    let impactTick: Int

    @State private var dropOffset: CGFloat = 0
    @State private var squash: CGFloat = 1
    @State private var shake: CGFloat = 0
    @State private var glow: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(RadialGradient(colors: [accent.opacity(0.22), Theme.surface2.opacity(0.4)], center: .center, startRadius: 4, endRadius: 70))
                StickerImage(path: sticker.heroPath, url: dex.url(for: sticker.heroPath),
                             contentMode: sticker.cutoutImageUrl != nil ? .fit : .fill)
                    .padding(sticker.cutoutImageUrl != nil ? 8 : 0)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(glow ? Theme.cyan : .white.opacity(0.06), lineWidth: glow ? 2 : 1))
            .shadow(color: glow ? Theme.cyan.opacity(0.6) : .clear, radius: 14)

            Text(sticker.word?.headword ?? "—")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.foreground)
                .lineLimit(1)
            Text(sticker.word?.meaningJa ?? "")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
        .scaleEffect(x: 2 - squash, y: squash, anchor: .bottom)
        .offset(x: shake, y: dropOffset)
        .onChange(of: isLanding) { _, landing in
            guard landing else { return }
            // Slam-in: fall → squash on contact → rebound twice → settle.
            dropOffset = -220
            glow = true
            withAnimation(.easeIn(duration: 0.38)) { dropOffset = 0 }
            Task {
                try? await Task.sleep(for: .milliseconds(380))
                withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { squash = 0.82 }
                try? await Task.sleep(for: .milliseconds(90))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { squash = 1 }
                try? await Task.sleep(for: .milliseconds(1100))
                withAnimation(.easeOut(duration: 0.6)) { glow = false }
            }
        }
        .onChange(of: impactTick) { _, _ in
            // Neighbours feel the impact: 3.4pt next door, 1.2pt two cells away, delayed by distance.
            let amp: CGFloat = neighborDistance == 1 ? 3.4 : (neighborDistance == 2 ? 1.2 : 0)
            guard amp > 0 else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(40 * neighborDistance))
                withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) { shake = amp }
                try? await Task.sleep(for: .milliseconds(70))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.35)) { shake = 0 }
            }
        }
    }
}

struct EmptyDexView: View {
    let isFiltered: Bool
    let onCamera: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: isFiltered ? "line.3.horizontal.decrease.circle" : "camera.viewfinder")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.primary)
            Text(isFiltered ? "この条件の単語はまだありません" : "今日のページはまだ白紙です。")
                .font(AppFont.hand(20))
                .foregroundStyle(Theme.foreground)
            if !isFiltered {
                PrimaryButton(title: "最初の1枚を撮る", icon: "camera.fill", sheen: true, action: onCamera)
                    .frame(maxWidth: 260)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
