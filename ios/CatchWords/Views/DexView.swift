import SwiftUI
import MapKit

enum DexMode: String, CaseIterable, Identifiable {
    case cover, map, grid, list
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cover: "スライド"
        case .map: "地図"
        case .grid: "棚"
        case .list: "リスト"
        }
    }
    var icon: String {
        switch self {
        case .cover: "rectangle.stack"
        case .map: "map"
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }
}

struct DexView: View {
    @Environment(DexStore.self) private var dex
    @Environment(AppRouter.self) private var router

    @State private var mode: DexMode = .grid
    @State private var categoryFilter: String?
    @State private var dayFilter: Date?
    @State private var query: String = ""
    @State private var showCalendar: Bool = false
    @State private var landedId: String?
    @State private var impactTick: Int = 0
    @Namespace private var modeBubble

    private var filtered: [Sticker] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return dex.stickers.filter { s in
            if let categoryFilter, s.categoryKey != categoryFilter { return false }
            if let dayFilter, !Calendar.current.isDate(s.takenAt, inSameDayAs: dayFilter) { return false }
            if !q.isEmpty {
                let w = s.word
                let hay = [w?.headword, w?.readingZhuyin, w?.pinyin, w?.meaningJa].compactMap { $0 }.joined(separator: " ")
                if !hay.localizedStandardContains(q) { return false }
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppBackground()
                content
                header
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCalendar) {
                NavigationStack {
                    ScrollView {
                        DexCalendarView(stickers: dex.stickers, selectedDay: $dayFilter) { s in
                            showCalendar = false
                            router.detailSticker = s
                        }
                        .padding(16)
                    }
                    .navigationTitle("日付")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        if dayFilter != nil {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("すべて") { dayFilter = nil; showCalendar = false }
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { showCalendar = false } }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.background)
            }
        }
    }

    // MARK: Header (toolbar + search)

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(DexMode.allCases) { m in
                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { mode = m }
                        } label: {
                            Image(systemName: m.icon)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(Theme.foreground.opacity(mode == m ? 1 : 0.7))
                                .frame(width: 44, height: 38)
                                .background {
                                    if mode == m {
                                        Capsule().fill(.white)
                                            .shadow(color: .black.opacity(0.1), radius: 4, y: 1)
                                            .matchedGeometryEffect(id: "mode", in: modeBubble)
                                    }
                                }
                        }
                        .buttonStyle(PressableStyle(scale: 0.92))
                        .accessibilityLabel(m.label)
                    }
                }
                .padding(3)
                .background(Theme.secondary, in: Capsule())

                Spacer(minLength: 0)

                Menu {
                    Button("すべて") { withAnimation(.snappy) { categoryFilter = nil } }
                    ForEach(Room.allCases) { room in
                        let keys = Category.orderedKeys.filter { Category.room(for: $0) == room && present.contains($0) }
                        if !keys.isEmpty {
                            Section(room.label) {
                                ForEach(keys, id: \.self) { k in
                                    Button("\(Category.emoji(for: k)) \(Category.label(for: k))") {
                                        withAnimation(.snappy) { categoryFilter = k }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    pill(categoryFilter.map { "\(Category.emoji(for: $0)) \(Category.label(for: $0))" } ?? "カテゴリー",
                         active: categoryFilter != nil)
                }
                Button { showCalendar = true } label: {
                    pill(dayFilter.map { JPDate.monthDay($0) } ?? "日付", active: dayFilter != nil)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("", text: $query, prompt: Text("単語・読み・意味で検索").foregroundStyle(Theme.muted))
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.foreground)
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                    }
                    .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background {
            Rectangle().fill(.regularMaterial)
                .mask(LinearGradient(colors: [.black, .black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea(edges: .top)
        }
    }

    private var present: Set<String> { Set(dex.stickers.map(\.categoryKey)) }

    private func pill(_ text: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Text(text).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(active ? .white : Theme.foreground)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(active ? AnyShapeStyle(Theme.primary) : AnyShapeStyle(Theme.secondary), in: Capsule())
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if let err = dex.loadError, dex.stickers.isEmpty {
            VStack(spacing: 12) {
                Label(err, systemImage: "wifi.exclamationmark").foregroundStyle(Theme.foreground)
                Button("もう一度読み込む") { Task { await dex.load() } }.foregroundStyle(Theme.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if dex.isLoading && !dex.hasLoaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if dex.hasLoaded && filtered.isEmpty {
            EmptyDexView(isFiltered: categoryFilter != nil || dayFilter != nil || !query.isEmpty) { router.tab = .camera }
                .padding(.top, 130)
        } else {
            switch mode {
            case .cover: DexCoverFlow(stickers: filtered) { router.detailSticker = $0 }.padding(.top, 118)
            case .map: DexMapView(stickers: filtered) { router.detailSticker = $0 }
            case .grid: shelves
            case .list: list
            }
        }
    }

    private var shelves: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    Color.clear.frame(height: 108)
                    ForEach(Category.orderedKeys, id: \.self) { key in
                        let items = filtered.filter { $0.categoryKey == key }
                        if !items.isEmpty {
                            CategoryShelf(key: key, stickers: items, landedId: landedId, impactTick: impactTick) { s in
                                router.detailSticker = s
                            }
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
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                Color.clear.frame(height: 104)
                ForEach(filtered) { s in
                    Button { router.detailSticker = s } label: { DexListRow(sticker: s) }
                        .buttonStyle(PressableStyle(scale: 0.98))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .refreshable { await dex.load() }
    }

    private func land(_ id: String, proxy: ScrollViewProxy) {
        categoryFilter = nil
        dayFilter = nil
        query = ""
        mode = .grid
        router.landingStickerId = nil
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { proxy.scrollTo(id, anchor: .center) }
            try? await Task.sleep(for: .milliseconds(200))
            landedId = id
            try? await Task.sleep(for: .milliseconds(420))
            SoundService.shared.play(.impact, volume: 0.5)
            Haptics.impact(.heavy)
            impactTick += 1
            try? await Task.sleep(for: .milliseconds(1400))
            landedId = nil
        }
    }
}

/// One category shelf: "🏠 家   6" then a 3-column grid of photo tiles.
struct CategoryShelf: View {
    let key: String
    let stickers: [Sticker]
    let landedId: String?
    let impactTick: Int
    let onTap: (Sticker) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(Category.emoji(for: key)).font(.system(size: 17))
                Text(Category.label(for: key)).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.foreground)
                Spacer()
                Text("\(stickers.count)").font(.system(size: 13)).monospacedDigit().foregroundStyle(Theme.muted)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(stickers.enumerated()), id: \.element.id) { idx, s in
                    let landedIndex = stickers.firstIndex { $0.id == landedId }
                    let distance = landedIndex.map { abs($0 - idx) } ?? 99
                    Button { onTap(s) } label: {
                        DexCell(sticker: s, isLanding: s.id == landedId, neighborDistance: distance, impactTick: impactTick)
                    }
                    .buttonStyle(PressableStyle(scale: 0.95))
                    .id(s.id)
                }
            }
        }
    }
}

/// Photo tile: rounded photo, memory badge top-right, headword on a soft dark fade at the bottom.
struct DexCell: View {
    @Environment(DexStore.self) private var dex
    let sticker: Sticker
    let isLanding: Bool
    let neighborDistance: Int
    let impactTick: Int

    @State private var dropOffset: CGFloat = 0
    @State private var squash: CGFloat = 1
    @State private var shake: CGFloat = 0
    @State private var glow: Bool = false

    var body: some View {
        let path = sticker.objectImageUrl ?? sticker.cutoutImageUrl
        Theme.secondary
            .aspectRatio(0.92, contentMode: .fit)
            .overlay {
                StickerImage(path: path, url: dex.url(for: path),
                             contentMode: sticker.objectImageUrl == nil ? .fit : .fill)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 46)
                    .overlay(alignment: .bottomLeading) {
                        Text(sticker.word?.headword ?? "—")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 9)
                            .padding(.bottom, 7)
                    }
            }
            .clipShape(.rect(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if let pct = dex.memoryPercent(for: sticker) {
                    MemoryBadge(percent: pct).padding(6)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(glow ? Theme.primary : .black.opacity(0.04), lineWidth: glow ? 2.5 : 1))
            .shadow(color: glow ? Theme.primary.opacity(0.5) : .black.opacity(0.08), radius: glow ? 14 : 5, y: glow ? 0 : 3)
            .scaleEffect(x: 2 - squash, y: squash, anchor: .bottom)
            .offset(x: shake, y: dropOffset)
            .onChange(of: isLanding) { _, landing in
                guard landing else { return }
                dropOffset = -220
                glow = true
                withAnimation(.easeIn(duration: 0.38)) { dropOffset = 0 }
                Task {
                    try? await Task.sleep(for: .milliseconds(380))
                    withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { squash = 0.84 }
                    try? await Task.sleep(for: .milliseconds(90))
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { squash = 1 }
                    try? await Task.sleep(for: .milliseconds(1100))
                    withAnimation(.easeOut(duration: 0.6)) { glow = false }
                }
            }
            .onChange(of: impactTick) { _, _ in
                let amp: CGFloat = neighborDistance == 1 ? 3.4 : (neighborDistance == 2 ? 1.2 : 0)
                guard amp > 0 else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(40 * neighborDistance))
                    withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) { shake = amp }
                    try? await Task.sleep(for: .milliseconds(70))
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.35)) { shake = 0 }
                }
            }
            .accessibilityLabel(sticker.word?.headword ?? "")
    }
}

/// DexCoverFlow: large white cards (photo + ruby headword + meaning + date) that snap and tilt,
/// a page dot row, and a thumbnail strip under them.
struct DexCoverFlow: View {
    @Environment(DexStore.self) private var dex
    let stickers: [Sticker]
    let onOpen: (Sticker) -> Void

    @State private var current: String?

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { geo in
                let w = geo.size.width * 0.62
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(stickers) { s in
                            Button { onOpen(s) } label: { card(s, width: w) }
                                .buttonStyle(PressableStyle(scale: 0.98))
                                .scrollTransition(axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1 : 0.88)
                                        .rotation3DEffect(.degrees(phase.value * -22), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                                        .opacity(phase.isIdentity ? 1 : 0.75)
                                }
                                .id(s.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, (geo.size.width - w) / 2, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $current)
                .onChange(of: current) { _, _ in Haptics.selection() }
            }
            .frame(height: 440)

            pageDots
            thumbnails
            Spacer(minLength: 0)
        }
        .onAppear { if current == nil { current = stickers.first?.id } }
    }

    private func card(_ s: Sticker, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            let path = s.objectImageUrl ?? s.cutoutImageUrl
            Theme.secondary
                .frame(width: width, height: width * 0.98)
                .overlay {
                    StickerImage(path: path, url: dex.url(for: path), contentMode: s.objectImageUrl == nil ? .fit : .fill)
                        .allowsHitTesting(false)
                }
                .clipped()
                .overlay(alignment: .topLeading) {
                    Text("\(Category.emoji(for: s.categoryKey)) \(Category.label(for: s.categoryKey))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.black.opacity(0.45), in: Capsule())
                        .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    if let p = dex.memoryPercent(for: s) { MemoryBadge(percent: p).padding(8) }
                }
            VStack(alignment: .leading, spacing: 6) {
                ZhuyinWordView(headword: s.word?.headword ?? "", zhuyin: s.word?.readingZhuyin, size: 24, weight: .semibold)
                Text(s.word?.meaningJa ?? "").font(.system(size: 14)).foregroundStyle(Theme.foreground.opacity(0.85)).lineLimit(1)
                Spacer(minLength: 4)
                Text(JPDate.monthDay(s.takenAt)).font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            .padding(14)
            .frame(width: width, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: width, height: 420)
        .background(Theme.card)
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }

    private var pageDots: some View {
        let idx = stickers.firstIndex { $0.id == current } ?? 0
        let count = min(stickers.count, 7)
        let start = max(0, min(idx - count / 2, stickers.count - count))
        return HStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(start + i == idx ? Theme.primary : Theme.border)
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.snappy, value: idx)
    }

    private var thumbnails: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(stickers) { s in
                        let path = s.objectImageUrl ?? s.cutoutImageUrl
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { current = s.id }
                        } label: {
                            Theme.secondary.frame(width: 50, height: 50)
                                .overlay { StickerImage(path: path, url: dex.url(for: path), contentMode: .fill).allowsHitTesting(false) }
                                .clipShape(.rect(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(current == s.id ? Theme.primary : .clear, lineWidth: 2.5))
                                .opacity(current == s.id ? 1 : 0.7)
                        }
                        .buttonStyle(PressableStyle(scale: 0.92))
                        .id(s.id)
                    }
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .frame(height: 56)
            .onChange(of: current) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}

struct DexListRow: View {
    @Environment(DexStore.self) private var dex
    let sticker: Sticker

    var body: some View {
        let path = sticker.objectImageUrl ?? sticker.cutoutImageUrl
        HStack(spacing: 12) {
            Theme.secondary.frame(width: 56, height: 56)
                .overlay { StickerImage(path: path, url: dex.url(for: path), contentMode: .fill).allowsHitTesting(false) }
                .clipShape(.rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                ZhuyinWordView(headword: sticker.word?.headword ?? "", zhuyin: sticker.word?.readingZhuyin, size: 19)
                Text(sticker.word?.meaningJa ?? "").font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if let p = dex.memoryPercent(for: sticker) { MemoryBadge(percent: p) }
                Text(JPDate.monthDay(sticker.takenAt)).font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
        }
        .padding(10)
        .background(Theme.card, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

/// Where each word was caught (only stickers that have a location).
struct DexMapView: View {
    @Environment(DexStore.self) private var dex
    let stickers: [Sticker]
    let onOpen: (Sticker) -> Void

    var body: some View {
        let located = stickers.filter { $0.lat != nil && $0.lng != nil }
        ZStack {
            Map {
                ForEach(located) { s in
                    Annotation(s.word?.headword ?? "", coordinate: CLLocationCoordinate2D(latitude: s.lat ?? 0, longitude: s.lng ?? 0)) {
                        Button { onOpen(s) } label: {
                            let path = s.objectImageUrl ?? s.cutoutImageUrl
                            Theme.secondary.frame(width: 44, height: 44)
                                .overlay { StickerImage(path: path, url: dex.url(for: path), contentMode: .fill).allowsHitTesting(false) }
                                .clipShape(.rect(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white, lineWidth: 2))
                                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .ignoresSafeArea(edges: .bottom)
            if located.isEmpty {
                Text("場所つきのキャッチはまだありません")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                    .padding(.horizontal, 16).frame(minHeight: 40)
                    .background(.regularMaterial, in: Capsule())
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
