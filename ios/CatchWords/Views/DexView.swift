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
        case .cover: "rectangle.split.3x1"
        case .map: "map"
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }
}

enum DexFilterMenu { case category, day }

/// White rounded dropdown panel that drops under a filter pill (dex.tsx popover).
struct DexDropdown<Content: View>: View {
    var width: CGFloat = 250
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 2) { content }
                .padding(8)
        }
        .scrollIndicators(.visible)
        .frame(width: width)
        .frame(maxHeight: 340)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.card, in: .rect(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.14), radius: 22, y: 10)
        .transition(.scale(scale: 0.92, anchor: .top).combined(with: .opacity))
    }
}

struct DexDropdownRow: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    var monospaced: Bool = false
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon ?? "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(icon == nil ? Theme.primary : Theme.muted)
                    .opacity(isSelected || icon != nil ? 1 : 0)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(Theme.foreground)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let count {
                    Text("\(count)").font(.system(size: 13)).monospacedDigit().foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(isSelected ? Theme.secondary : .clear, in: .rect(cornerRadius: 14, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
    @State private var openMenu: DexFilterMenu?
    @Namespace private var modeBubble
    @AppStorage(Scene3D.enabledKey) private var fx3D: Bool = true
    @State private var shelfEdit: ShelfEdit?
    @State private var deleteShelfKey: String?

    /// Create (key nil) or rename a shelf.
    struct ShelfEdit: Identifiable {
        let key: String?
        var label: String
        var emoji: String
        var id: String { key ?? "new" }
    }

    private func editShelf(_ key: String) {
        shelfEdit = ShelfEdit(key: key, label: Category.label(for: key), emoji: Category.emoji(for: key))
    }

    private func saveShelfEdit() {
        guard let e = shelfEdit else { return }
        let label = e.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        let emoji = e.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await dex.saveShelf(key: e.key, label: String(label.prefix(24)), emoji: emoji.isEmpty ? "📦" : String(emoji.prefix(8)))
                Haptics.success()
            } catch {
                Haptics.warning()
            }
        }
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var categoryCounts: [(key: String, count: Int)] {
        var counts: [String: Int] = [:]
        for s in dex.stickers { counts[s.categoryKey, default: 0] += 1 }
        let order = Category.orderedKeys
        return counts.map { ($0.key, $0.value) }.sorted {
            $0.count != $1.count ? $0.count > $1.count
                : (order.firstIndex(of: $0.key) ?? 99) < (order.firstIndex(of: $1.key) ?? 99)
        }
    }

    private var dayCounts: [(day: Date, count: Int)] {
        let cal = Calendar.current
        var counts: [Date: Int] = [:]
        for s in dex.stickers { counts[cal.startOfDay(for: s.takenAt), default: 0] += 1 }
        return counts.map { ($0.key, $0.value) }.sorted { $0.day > $1.day }
    }

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
                if openMenu != nil {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture { closeMenu() }
                }
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
                            router.advanceTour(from: .dexTypes, to: .dexOpen)
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
                .tourAnchor(.dexModes)

                Spacer(minLength: 0)

                Button { toggleMenu(.category) } label: {
                    pill(categoryFilter.map { "\(Category.emoji(for: $0)) \(Category.label(for: $0))" } ?? "カテゴリー",
                         active: categoryFilter != nil, open: openMenu == .category)
                }
                .buttonStyle(PressableStyle(scale: 0.95))
                .overlay(alignment: .topLeading) {
                    if openMenu == .category { categoryMenu.offset(x: -30, y: 52) }
                }
                .zIndex(openMenu == .category ? 2 : 0)
                Button { toggleMenu(.day) } label: {
                    pill(dayFilter.map { JPDate.mmdd($0) } ?? "日付", active: dayFilter != nil, open: openMenu == .day)
                }
                .buttonStyle(PressableStyle(scale: 0.95))
                .overlay(alignment: .topTrailing) {
                    if openMenu == .day { dayMenu.offset(y: 52) }
                }
                .zIndex(openMenu == .day ? 2 : 0)
            }
            .zIndex(1)
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

    // MARK: Filter dropdowns

    private func toggleMenu(_ menu: DexFilterMenu) {
        Haptics.selection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { openMenu = openMenu == menu ? nil : menu }
    }

    private func closeMenu() {
        withAnimation(.easeOut(duration: 0.18)) { openMenu = nil }
    }

    private var categoryMenu: some View {
        DexDropdown {
            DexDropdownRow(title: "すべて", count: nil, isSelected: categoryFilter == nil) {
                pick { categoryFilter = nil }
            }
            ForEach(categoryCounts, id: \.key) { item in
                DexDropdownRow(title: "\(Category.emoji(for: item.key)) \(Category.label(for: item.key))",
                               count: item.count, isSelected: categoryFilter == item.key) {
                    pick { categoryFilter = item.key }
                }
            }
        }
    }

    private var dayMenu: some View {
        DexDropdown(width: 200) {
            DexDropdownRow(title: "すべての日", count: nil, isSelected: dayFilter == nil) {
                pick { dayFilter = nil }
            }
            ForEach(dayCounts, id: \.day) { item in
                let selected = dayFilter.map { Calendar.current.isDate($0, inSameDayAs: item.day) } ?? false
                DexDropdownRow(title: JPDate.mmdd(item.day), count: item.count, isSelected: selected, monospaced: true) {
                    pick { dayFilter = item.day }
                }
            }
            Divider().padding(.vertical, 4)
            DexDropdownRow(title: "カレンダーで選ぶ", count: nil, isSelected: false, icon: "calendar") {
                closeMenu()
                showCalendar = true
            }
        }
    }

    private func pick(_ change: () -> Void) {
        Haptics.selection()
        withAnimation(.snappy) {
            change()
            openMenu = nil
        }
    }

    private func pill(_ text: String, active: Bool, open: Bool) -> some View {
        HStack(spacing: 4) {
            Text(text).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                .rotationEffect(.degrees(open ? 180 : 0))
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
                    if fx3D && !reduceMotion && categoryCounts.count > 1 {
                        // 図鑑の本棚: one Blender book per category (most words first). Tap = filter.
                        Bookshelf3DView(
                            books: categoryCounts.prefix(6).map { ShelfBook(key: $0.key, count: $0.count) },
                            selected: categoryFilter
                        ) { key in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { categoryFilter = key }
                        }
                        .background(
                            LinearGradient(colors: [Color(hex: 0xFFF7EC), Color(hex: 0xF3E6D2)], startPoint: .top, endPoint: .bottom),
                            in: .rect(cornerRadius: 24, style: .continuous)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.border, lineWidth: 1))
                    }
                    ForEach(Category.allOrderedKeys, id: \.self) { key in
                        let items = filtered.filter { $0.categoryKey == key }
                        if !items.isEmpty {
                            CategoryShelf(key: key, stickers: items, landedId: landedId, impactTick: impactTick,
                                          onEdit: { editShelf(key) }, onDelete: Category.isBuiltin(key) ? nil : { deleteShelfKey = key }) { s in
                                router.detailSticker = s
                            }
                        }
                    }
                    Button {
                        shelfEdit = ShelfEdit(key: nil, label: "", emoji: "📦")
                    } label: {
                        Label("自分の棚を作る", systemImage: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.primaryInk)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.primary.opacity(0.07), in: .rect(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Theme.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                    }
                    .buttonStyle(PressableStyle())
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
        .alert(shelfEdit?.key == nil ? "自分の棚を作る" : "棚の名前と絵文字",
               isPresented: Binding(get: { shelfEdit != nil }, set: { if !$0 { shelfEdit = nil } })) {
            TextField("棚の名前（24文字まで）", text: Binding(get: { shelfEdit?.label ?? "" }, set: { shelfEdit?.label = $0 }))
            TextField("絵文字", text: Binding(get: { shelfEdit?.emoji ?? "" }, set: { shelfEdit?.emoji = $0 }))
            Button("キャンセル", role: .cancel) { shelfEdit = nil }
            Button("保存") { saveShelfEdit(); shelfEdit = nil }
        } message: {
            Text(shelfEdit?.key == nil ? "単語の詳細の「棚」から、語をこの棚に移せます。" : "この棚の名前は、あなたの図鑑だけで変わります。")
        }
        .confirmationDialog("この棚を消しますか？", isPresented: Binding(get: { deleteShelfKey != nil }, set: { if !$0 { deleteShelfKey = nil } }),
                            titleVisibility: .visible) {
            Button("消す（語は元の棚に戻ります）", role: .destructive) {
                guard let key = deleteShelfKey else { return }
                deleteShelfKey = nil
                Task { try? await dex.deleteShelf(key: key) }
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                Color.clear.frame(height: 104)
                ForEach(Category.allOrderedKeys, id: \.self) { key in
                    let items = filtered.filter { $0.categoryKey == key }
                    if !items.isEmpty {
                        HStack(spacing: 6) {
                            Text(Category.emoji(for: key)).font(.system(size: 17))
                            Text(Category.label(for: key)).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.foreground)
                            Spacer()
                            Text("\(items.count)").font(.system(size: 13)).monospacedDigit().foregroundStyle(Theme.muted)
                        }
                        .padding(.top, 6)
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { i, s in
                                if i > 0 { Divider().padding(.leading, 12) }
                                DexListRow(sticker: s) { router.detailSticker = s }
                            }
                        }
                        .background(Theme.card, in: .rect(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.border, lineWidth: 1))
                    }
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
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    let onTap: (Sticker) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(Category.emoji(for: key)).font(.system(size: 17))
                Text(Category.label(for: key)).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.foreground)
                Spacer()
                Text("\(stickers.count)").font(.system(size: 13)).monospacedDigit().foregroundStyle(Theme.muted)
                if onEdit != nil || onDelete != nil {
                    Menu {
                        if let onEdit { Button("名前と絵文字を変える", systemImage: "pencil", action: onEdit) }
                        if let onDelete { Button("この棚を消す", systemImage: "trash", role: .destructive, action: onDelete) }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("\(Category.label(for: key))の棚を編集")
                }
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
                            VStack(spacing: 6) {
                                Button { onOpen(s) } label: { card(s, width: w) }
                                    .buttonStyle(PressableStyle(scale: 0.98))
                                reflection(s, width: w)
                            }
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
            .frame(height: 480)

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
                HStack(spacing: 8) {
                    Text(JPDate.monthDay(s.takenAt))
                    if let place = s.locationName, !place.isEmpty {
                        Label(place, systemImage: "mappin").lineLimit(1)
                    }
                }
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            .padding(14)
            .frame(width: width, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: width, height: 400)
        .background(Theme.card)
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }

    /// Mirrored, fading copy of the card's bottom edge (the "floor" reflection in DexCoverFlow).
    private func reflection(_ s: Sticker, width: CGFloat) -> some View {
        card(s, width: width)
            .scaleEffect(x: 1, y: -1)
            .frame(width: width, height: 64, alignment: .top)
            .clipped()
            .mask(LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
    let onOpen: () -> Void

    var body: some View {
        let path = sticker.objectImageUrl ?? sticker.cutoutImageUrl
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    Theme.secondary.frame(width: 60, height: 60)
                        .overlay { StickerImage(path: path, url: dex.url(for: path), contentMode: .fill).allowsHitTesting(false) }
                        .clipShape(.rect(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        ZhuyinWordView(headword: sticker.word?.headword ?? "", zhuyin: sticker.word?.readingZhuyin, size: 22, weight: .bold)
                        Text(sticker.word?.meaningJa ?? "").font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle(scale: 0.98))
            PronounceCircle(text: sticker.word?.headword ?? "", size: 46, prefetch: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

/// DexDayMap.tsx: one day at a time — round photo pins, a timeline panel, and a day bar (calendar / ‹ ›).
struct DexMapView: View {
    @Environment(DexStore.self) private var dex
    let stickers: [Sticker]
    let onOpen: (Sticker) -> Void

    @State private var day: Date?
    @State private var selectedId: String?
    @State private var panelOpen: Bool = true
    @State private var position: MapCameraPosition = .automatic
    @State private var showDatePicker: Bool = false
    @State private var visibleRegion: MKCoordinateRegion?

    private var days: [Date] {
        let cal = Calendar.current
        return Array(Set(stickers.map { cal.startOfDay(for: $0.takenAt) })).sorted(by: >)
    }

    private var dayItems: [Sticker] {
        guard let day else { return [] }
        return stickers.filter { Calendar.current.isDate($0.takenAt, inSameDayAs: day) }.sorted { $0.takenAt < $1.takenAt }
    }

    /// day-map.ts groupStops: within 80 m and 40 min of the previous catch = the same stop.
    /// A catch without a location joins the previous stop when it is close in time.
    private var groups: [MapVisit] {
        var out: [MapVisit] = []
        for s in dayItems {
            if var last = out.last, let prev = last.items.last,
               s.takenAt.timeIntervalSince(prev.takenAt) <= 40 * 60, MapVisit.isNear(last, s) {
                last.items.append(s)
                out[out.count - 1] = last
            } else {
                out.append(MapVisit(items: [s]))
            }
        }
        return out
    }

    var body: some View {
        let visits = groups
        let located = visits.filter { $0.coordinate != nil }
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                ForEach(located) { v in
                    Annotation("", coordinate: v.coordinate ?? CLLocationCoordinate2D()) {
                        pin(v)
                    }
                }
            }
            // Owner 2026-09-24: keep the map's own colours and shop/station marks — no grey styling.
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .all))
            .onMapCameraChange(frequency: .onEnd) { ctx in visibleRegion = ctx.region }
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 10) {
                if located.isEmpty && !dayItems.isEmpty {
                    Text("この日は場所の記録がありません")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.foreground)
                        .padding(.horizontal, 16).frame(minHeight: 40)
                        .background(.regularMaterial, in: Capsule())
                }
                if panelOpen && !dayItems.isEmpty { timeline(visits).transition(.move(edge: .bottom).combined(with: .opacity)) }
                dayBar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 84)
        }
        .onAppear {
            if day == nil { day = days.first }
            focus()
        }
        .onChange(of: day) { _, _ in
            selectedId = dayItems.first?.id
            focus()
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                ScrollView {
                    DexCalendarView(stickers: stickers, selectedDay: $day, onOpen: onOpen) { picked in
                        day = picked
                        panelOpen = true
                        showDatePicker = false
                    }
                    .padding(.horizontal, 16)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showDatePicker = false } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("閉じる")
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
        }
    }

    /// DexDayMap frame(): fit only the stops within 3 km of the anchor, so a Taipei-morning /
    /// Tamsui-evening day stays a close-up map; farther stops are reached through the timeline.
    private func focus(anchor: Sticker? = nil) {
        let located = dayItems.compactMap { s -> CLLocationCoordinate2D? in
            guard let la = s.lat, let lo = s.lng else { return nil }
            return CLLocationCoordinate2D(latitude: la, longitude: lo)
        }
        let a: CLLocationCoordinate2D? = anchor.flatMap { s in
            guard let la = s.lat, let lo = s.lng else { return nil }
            return CLLocationCoordinate2D(latitude: la, longitude: lo)
        } ?? located.first
        guard let a else { return }
        let origin = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let pts = located.filter { origin.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) <= 3000 }
        guard let first = pts.first else { return }
        let lats = pts.map(\.latitude), lngs = pts.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: ((lats.min() ?? 0) + (lats.max() ?? 0)) / 2 - 0.002,
                                            longitude: ((lngs.min() ?? 0) + (lngs.max() ?? 0)) / 2)
        let span = pts.count == 1
            ? MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007)
            : MKCoordinateSpan(latitudeDelta: max(0.005, ((lats.max() ?? 0) - (lats.min() ?? 0)) * 2.4),
                               longitudeDelta: max(0.005, ((lngs.max() ?? 0) - (lngs.min() ?? 0)) * 2.4))
        withAnimation(.easeInOut(duration: 0.6)) {
            position = .region(MKCoordinateRegion(center: pts.count == 1 ? CLLocationCoordinate2D(latitude: first.latitude - 0.002, longitude: first.longitude) : center, span: span))
        }
    }

    /// Already on screen (clear of the top filters and bottom panel) → don't move; otherwise re-frame near it.
    private func focusOn(_ s: Sticker) {
        guard let la = s.lat, let lo = s.lng else { return }
        if let r = visibleRegion {
            let top = r.center.latitude + r.span.latitudeDelta * 0.32
            let bottom = r.center.latitude - r.span.latitudeDelta * 0.05
            let half = r.span.longitudeDelta * 0.4
            if la <= top, la >= bottom, abs(lo - r.center.longitude) <= half { return }
        }
        focus(anchor: s)
    }

    private func pin(_ v: MapVisit) -> some View {
        let selected = v.items.first { $0.id == selectedId }
        let isOn = selected != nil
        let s = selected ?? v.items[0]
        let path = s.objectImageUrl ?? s.cutoutImageUrl
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selectedId = s.id; panelOpen = true }
            focusOn(s)
        } label: {
            VStack(spacing: 4) {
                Theme.secondary.frame(width: isOn ? 64 : 48, height: isOn ? 64 : 48)
                    .overlay { StickerImage(path: path, url: dex.url(for: path), contentMode: .fill).allowsHitTesting(false) }
                    .clipShape(Circle())
                    .overlay(Circle().stroke(isOn ? Theme.primary : .white, lineWidth: isOn ? 4 : 3))
                    .overlay(alignment: .topTrailing) {
                        if v.items.count > 1 {
                            Text("\(v.items.count)")
                                .font(.system(size: 12, weight: .bold)).monospacedDigit().foregroundStyle(.white)
                                .frame(minWidth: 22, minHeight: 22)
                                .background(Theme.primary, in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .offset(x: 6, y: -6)
                        }
                    }
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
                if isOn {
                    Text(JPDate.time(v.start))
                        .font(.system(size: 13, weight: .bold)).monospacedDigit().foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Theme.primary, in: Capsule())
                }
            }
        }
        .buttonStyle(.plain)
        .zIndex(isOn ? 1 : 0)
    }

    private func timeline(_ visits: [MapVisit]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(visits) { v in
                        let groupOn = v.items.contains { $0.id == selectedId }
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 0) {
                                Circle().fill(groupOn ? Theme.primary : Theme.muted.opacity(0.5)).frame(width: groupOn ? 14 : 11, height: groupOn ? 14 : 11).padding(.top, 5)
                                Rectangle().fill(Theme.border).frame(width: 2)
                            }
                            .frame(width: 16)
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Text(v.timeLabel)
                                        .font(.system(size: 17, weight: .bold)).monospacedDigit()
                                        .foregroundStyle(groupOn ? Theme.primaryInk : Theme.foreground)
                                    if let place = v.placeName {
                                        Label(place, systemImage: "mappin")
                                            .font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                                    }
                                }
                                ForEach(v.items) { s in
                                    row(s)
                                }
                            }
                            .padding(.bottom, 16)
                        }
                        .id(v.id)
                    }
                }
                .padding(18)
            }
            .frame(maxHeight: 250)
            .background(.white.opacity(0.94), in: .rect(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
            .onChange(of: selectedId) { _, id in
                guard let id, let v = visits.first(where: { $0.items.contains { $0.id == id } }) else { return }
                withAnimation { proxy.scrollTo(v.id, anchor: .top) }
            }
        }
    }

    private func row(_ s: Sticker) -> some View {
        let isOn = s.id == selectedId
        let path = s.objectImageUrl ?? s.cutoutImageUrl
        return Button {
                                    if isOn { onOpen(s) } else {
                                        Haptics.selection()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedId = s.id }
                                        focusOn(s)
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        Theme.secondary.frame(width: 64, height: 64)
                                            .overlay { StickerImage(path: path, url: dex.url(for: path), contentMode: .fill).allowsHitTesting(false) }
                                            .clipShape(.rect(cornerRadius: 16, style: .continuous))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(s.word?.headword ?? "").font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.foreground)
                                            if let cap = s.caption, !cap.isEmpty {
                                                Text(cap).font(AppFont.hand(15)).foregroundStyle(Theme.muted).lineLimit(1)
                                            } else {
                                                Text(s.word?.meaningJa ?? "").font(.system(size: 15)).foregroundStyle(Theme.muted).lineLimit(1)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(isOn ? 8 : 0)
                                    .background(isOn ? Theme.primary.opacity(0.1) : .clear, in: .rect(cornerRadius: 20, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(isOn ? Theme.primary.opacity(0.35) : .clear, lineWidth: 1))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PressableStyle(scale: 0.98))
    }

    private var dayBar: some View {
        let idx = day.flatMap { d in days.firstIndex(of: d) }
        return HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { panelOpen.toggle() }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .rotationEffect(.degrees(panelOpen ? 0 : 180))
                    .frame(width: 48, height: 48)
                    .background(Theme.foreground, in: Circle())
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .accessibilityLabel(panelOpen ? "一覧を閉じる" : "一覧を開く")
            Text(day.map { JPDate.monthDayWeek($0) } ?? "—")
                .font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.foreground)
            Spacer()
            circleButton("calendar") { showDatePicker = true }.accessibilityLabel("日付を選ぶ")
            circleButton("chevron.left") {
                if let idx, idx + 1 < days.count { day = days[idx + 1] }
            }
            .disabled(idx == nil || (idx ?? 0) + 1 >= days.count)
            .accessibilityLabel("前の日")
            circleButton("chevron.right") {
                if let idx, idx > 0 { day = days[idx - 1] }
            }
            .disabled(idx == nil || idx == 0)
            .accessibilityLabel("次の日")
        }
        .padding(6)
        .background(.white.opacity(0.95), in: Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.foreground)
                .frame(width: 46, height: 46)
                .background(Theme.secondary, in: Circle())
        }
        .buttonStyle(PressableStyle(scale: 0.9))
    }
}

/// One stop on the day map: catches taken close together in time and place.
struct MapVisit: Identifiable {
    var items: [Sticker]
    var id: String { items.first?.id ?? UUID().uuidString }
    var start: Date { items.first?.takenAt ?? Date() }
    var end: Date { items.last?.takenAt ?? Date() }

    var coordinate: CLLocationCoordinate2D? {
        let pts = items.compactMap { s -> (Double, Double)? in
            guard let la = s.lat, let lo = s.lng else { return nil }
            return (la, lo)
        }
        guard !pts.isEmpty else { return nil }
        let n = Double(pts.count)
        return CLLocationCoordinate2D(latitude: pts.map(\.0).reduce(0, +) / n, longitude: pts.map(\.1).reduce(0, +) / n)
    }

    var placeName: String? { items.compactMap(\.locationName).first { !$0.isEmpty } }

    var timeLabel: String {
        let a = JPDate.time(start), b = JPDate.time(end)
        return a == b ? a : "\(a)–\(b)"
    }

    static func isNear(_ visit: MapVisit, _ b: Sticker) -> Bool {
        guard let c = visit.coordinate, let lb = b.lat, let lob = b.lng else { return true }
        let d = CLLocation(latitude: c.latitude, longitude: c.longitude).distance(from: CLLocation(latitude: lb, longitude: lob))
        return d <= 80
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
