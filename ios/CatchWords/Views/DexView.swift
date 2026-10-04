import SwiftUI
import MapKit

enum DexMode: String, CaseIterable, Identifiable {
    /// The prototype's #dxSeg: カード (slide) / 地図 / ギャラリー (category shadows) / リスト.
    case cover, map, grid, list
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cover: L("カード")
        case .map: L("地図")
        case .grid: L("ギャラリー")
        case .list: L("リスト")
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
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(icon == nil ? Theme.primary : Theme.muted)
                    .opacity(isSelected || icon != nil ? 1 : 0)
                    .frame(width: 18)
                Text(title)
                    .scaledFont(size: 15, weight: isSelected ? .semibold : .regular, monospacedDigit: true)
                    .foregroundStyle(Theme.foreground)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let count {
                    Text("\(count)").scaledFont(size: 13, monospacedDigit: true).foregroundStyle(Theme.muted)
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
    /// One of the dex's 20 categories (DexCatalog), or nil for all.
    @State private var categoryFilter: Int?
    @State private var dayFilter: Date?
    @State private var query: String = ""
    @State private var showCalendar: Bool = false
    @State private var openMenu: DexFilterMenu?
    /// The header's height (the content starts under it).
    @State private var headerHeight: CGFloat = 120
    /// The landing word while its light is on the way (drawn as its shadow / an empty square). Cleared the
    /// moment it lands, so the gallery is redrawn with the word in the caught group (prototype `renderDex`).
    @State private var galleryHold: DexBook.Hold?
    /// The gallery slot being landed on / pointed at (frame reporting, fillIn, blue ring).
    @State private var focus: DexGalleryFocus?
    @Environment(\.appReduceMotion) private var reduceMotion

    private var lang: String { NativeAPI.targetLanguage }

    private var categoryCounts: [(no: Int, count: Int)] {
        var counts: [Int: Int] = [:]
        for s in dex.stickers { counts[DexBook.category(of: s, lang: lang), default: 0] += 1 }
        return counts.map { ($0.key, $0.value) }.sorted {
            $0.count != $1.count ? $0.count > $1.count : $0.no < $1.no
        }
    }

    /// A dex category's emoji and name, for the filter pill and its menu.
    private func categoryTitle(_ no: Int) -> String {
        let emoji = DexCatalog.categories.first { $0.no == no }?.emoji ?? "✨"
        return "\(emoji) \(DexCatalog.label(no))"
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
            if let categoryFilter, DexBook.category(of: s, lang: lang) != categoryFilter { return false }
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
                if mode == .cover { DexGalleryBackdrop() } else { AppBackground() }
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
                    .navigationTitle(L("日付"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        if dayFilter != nil {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(L("すべて")) { dayFilter = nil; showCalendar = false }
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) { Button(L("閉じる")) { showCalendar = false } }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.background)
            }
        }
        // A landing (card catch, re-encounter, a catch from elsewhere) always opens the gallery.
        .onAppear { if router.landing != nil || router.landingStickerId != nil { showGallery() } }
        .onChange(of: router.landing?.stickerId) { _, id in if id != nil { showGallery() } }
        .onChange(of: router.landingStickerId) { _, id in if id != nil { showGallery() } }
        .onChange(of: mode) { _, _ in
            // Switching views redraws the gallery (`renderDex`): the `.slot.fill` ring goes.
            guard router.landing == nil else { return }
            focus = nil
        }
    }

    /// `S.view = "grid"`: the gallery, unfiltered.
    private func showGallery() {
        categoryFilter = nil
        dayFilter = nil
        query = ""
        openMenu = nil
        mode = .grid
    }

    // MARK: Header (the prototype's `.dex-head`: 図鑑, progress, #dxSeg)

    private var header: some View {
        VStack(spacing: 10) {
            // .dex-head: h2 24 pt 900 + .dex-prog 12 pt 600 #5C646F; the round buttons on the right
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L("図鑑"))
                        .scaledFont(size: 24, weight: .black)
                        .foregroundStyle(Theme.foreground)
                    // N枚 counts words (one per headword, like the prototype's S.dex), not stickers.
                    Text(L("\(DexBook.words(dex.stickers, lang: lang).count)枚・影 \(DexBook.baseCaught(dex.stickers, lang: lang)) / 100"))
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundStyle(Theme.muted)
                        // Large text on a small iPhone: wrap instead of cutting the counts off.
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
                DexModeSegment(mode: $mode) { m in
                    Haptics.selection()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { mode = m }
                    router.advanceTour(from: .dexTypes, to: .dexOpen)
                }
                .tourAnchor(.dexModes)
            }
            .padding(.horizontal, 2)
            // The app's own search and filters (not in the prototype) stay for カード / 地図 / リスト, in one row.
            if mode != .grid {
                HStack(spacing: 8) {
                    searchField
                    filterPills
                }
                .zIndex(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background {
            // Solid behind the title and progress line, fading out only in a strip below the header — scrolled
            // category cards must not show through 「図鑑」 (the prototype's head sits outside the scroll).
            Rectangle().fill(.regularMaterial)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.86),
                                             .init(color: .black.opacity(0), location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .padding(.bottom, -18)
                .ignoresSafeArea(edges: .top)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { h in
            headerHeight = h
        }
    }

    private var filterPills: some View {
        HStack(spacing: 8) {
            Button { toggleMenu(.category) } label: {
                pill(categoryFilter.map { categoryTitle($0) } ?? L("カテゴリー"),
                     active: categoryFilter != nil, open: openMenu == .category)
            }
            .buttonStyle(PressableStyle(scale: 0.95))
            .overlay(alignment: .topTrailing) {
                if openMenu == .category { categoryMenu.offset(x: 30, y: 52) }
            }
            .zIndex(openMenu == .category ? 2 : 0)
            Button { toggleMenu(.day) } label: {
                pill(dayFilter.map { JPDate.mmdd($0) } ?? L("日付"), active: dayFilter != nil, open: openMenu == .day)
            }
            .buttonStyle(PressableStyle(scale: 0.95))
            .overlay(alignment: .topTrailing) {
                if openMenu == .day { dayMenu.offset(y: 52) }
            }
            .zIndex(openMenu == .day ? 2 : 0)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
            TextField("", text: $query, prompt: Text(L("単語・読み・意味で検索")).foregroundStyle(Theme.muted))
                .scaledFont(size: 16)
                .foregroundStyle(Theme.foreground)
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                        .frame(width: 44, height: 44)  // HIG: 44pt to tap
                        .contentShape(Rectangle())
                }
                .padding(.horizontal, -6)  // same look as the old 32pt frame; only the hit area grows
                .accessibilityLabel(L("検索を消す"))
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
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
            DexDropdownRow(title: L("すべて"), count: nil, isSelected: categoryFilter == nil) {
                pick { categoryFilter = nil }
            }
            ForEach(categoryCounts, id: \.no) { item in
                DexDropdownRow(title: categoryTitle(item.no), count: item.count, isSelected: categoryFilter == item.no) {
                    pick { categoryFilter = item.no }
                }
            }
        }
    }

    private var dayMenu: some View {
        DexDropdown(width: 200) {
            DexDropdownRow(title: L("すべての日"), count: nil, isSelected: dayFilter == nil) {
                pick { dayFilter = nil }
            }
            ForEach(dayCounts, id: \.day) { item in
                let selected = dayFilter.map { Calendar.current.isDate($0, inSameDayAs: item.day) } ?? false
                DexDropdownRow(title: JPDate.mmdd(item.day), count: item.count, isSelected: selected, monospaced: true) {
                    pick { dayFilter = item.day }
                }
            }
            Divider().padding(.vertical, 4)
            DexDropdownRow(title: L("カレンダーで選ぶ"), count: nil, isSelected: false, icon: "calendar") {
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
            Image(systemName: "chevron.down").scaledFont(size: 10, weight: .semibold)
                .rotationEffect(.degrees(open ? 180 : 0))
        }
        .scaledFont(size: 14, weight: .medium)
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
                Button(L("もう一度読み込む")) { Task { await dex.load() } }.foregroundStyle(Theme.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if dex.isLoading && !dex.hasLoaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if mode == .grid {
            // The gallery always shows its shadows, even before the first catch (prototype renderDex grid).
            gallery
        } else if dex.hasLoaded && filtered.isEmpty {
            EmptyDexView(isFiltered: categoryFilter != nil || dayFilter != nil || !query.isEmpty,
                         onCamera: { router.tab = .camera },
                         onClearFilters: {
                             withAnimation(.snappy) {
                                 categoryFilter = nil
                                 dayFilter = nil
                                 query = ""
                             }
                         })
                .padding(.top, headerHeight + 12)
        } else {
            switch mode {
            case .cover: DexCoverFlow(stickers: filtered) { router.detailSticker = $0 }.padding(.top, headerHeight)
            case .map: DexMapView(stickers: filtered) { router.detailSticker = $0 }
            case .grid: gallery
            case .list: list
            }
        }
    }

    // MARK: ギャラリー (category shadows)

    private var gallery: some View {
        let numbers = DexNumbering.assign(dex.stickers, lang: lang, uid: SupabaseClient.shared.userId)
        let sections = DexBook.sections(stickers: dex.stickers, numbers: numbers, lang: lang, hold: galleryHold)
        return ScrollViewReader { proxy in
            ScrollView {
                // .dex-body: padding 4 18 40 (each .dcat adds its 12 pt margin on top)
                DexGallery(sections: sections, focus: focus, calm: reduceMotion,
                           onTargetFrame: { frame in router.landing?.target = frame },
                           onOpen: { router.openDetail($0, zoom: true) })
                    .padding(.top, max(0, headerHeight - 8))
                    .padding(.horizontal, 18)
                    .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .refreshable { await dex.load() }
            .onAppear { takeLanding(proxy) }
            .onChange(of: router.landing?.stickerId) { _, _ in takeLanding(proxy) }
            .onChange(of: router.landingStickerId) { _, _ in takeLanding(proxy) }
            .onChange(of: router.landing?.fillStart) { _, start in
                // pon! — addEntry + renderDex: the gallery is redrawn at once (the word joins the caught group by
                // No., a new shadow refills to 5), and its new slot fills (`.slot.fill`) and is scrolled to.
                guard let start, let l = router.landing else { return }
                galleryHold = nil
                focus = DexGalleryFocus(id: l.stickerId, fillStart: start)
                Task {
                    await scroll(to: l.stickerId, proxy: proxy)
                    // one more frame so the slot reports its new frame before the burst
                    try? await Task.sleep(for: .milliseconds(16))
                    l.settled = true
                }
            }
        }
    }

    /// A card-catch landing: hold the word as its shadow (or an empty square) and centre its slot (the
    /// prototype sets `scrollTop` at once); CatchLandingController flies the star there. Any other landing
    /// (re-encounter, a catch from search or scan): centre the word and light its slot.
    private func takeLanding(_ proxy: ScrollViewProxy) {
        if let l = router.landing, l.fillStart == nil, galleryHold?.stickerId != l.stickerId {
            galleryHold = DexBook.Hold(stickerId: l.stickerId)
            focus = DexGalleryFocus(id: l.stickerId, fillStart: nil)
            Task { await scroll(to: l.stickerId, proxy: proxy) }
        } else if router.landing == nil, let id = router.landingStickerId {
            router.landingStickerId = nil
            galleryHold = nil
            focus = nil
            Task {
                await scroll(to: id, proxy: proxy)
                try? await Task.sleep(for: .milliseconds(200))
                focus = DexGalleryFocus(id: id, fillStart: CCClock.now)
                SoundService.shared.play(.landBounce)
                HapticPatterns.shared.land()
            }
        }
    }

    /// Centre a word's slot: first its category card (the gallery is lazy), then the slot itself.
    private func scroll(to id: String, proxy: ScrollViewProxy) async {
        await Task.yield()
        if let s = dex.sticker(id: id) {
            proxy.scrollTo("dexcat-\(DexBook.category(of: s, lang: lang))", anchor: .center)
            try? await Task.sleep(for: .milliseconds(30))
        }
        proxy.scrollTo(id, anchor: .center)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                Color.clear.frame(height: max(0, headerHeight - 14))
                // Grouped by the dex's 20 categories, in their order.
                ForEach(DexCatalog.categories) { cat in
                    let items = filtered.filter { DexBook.category(of: $0, lang: lang) == cat.no }
                    if !items.isEmpty {
                        HStack(spacing: 6) {
                            Text(cat.emoji).scaledFont(size: 17)
                            Text(cat.label).scaledFont(size: 16, weight: .semibold).foregroundStyle(Theme.foreground)
                            Spacer()
                            Text("\(items.count)").scaledFont(size: 13, monospacedDigit: true).foregroundStyle(Theme.muted)
                        }
                        .padding(.top, 6)
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { i, s in
                                if i > 0 { Divider().padding(.leading, 12) }
                                DexListRow(sticker: s) { router.openDetail(s, zoom: true) }
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
}

struct DexListRow: View {
    @Environment(DexStore.self) private var dex
    let sticker: Sticker
    let onOpen: () -> Void

    var body: some View {
        let path = sticker.heroPath
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    Theme.secondary.frame(width: 60, height: 60)
                        .overlay { StickerImage(path: path, url: dex.url(for: path), contentMode: .fill).allowsHitTesting(false) }
                        .clipShape(.rect(cornerRadius: 16, style: .continuous))
                        .detailZoomSource(sticker.id)
                    VStack(alignment: .leading, spacing: 4) {
                        ZhuyinWordView(headword: sticker.word?.headword ?? "", zhuyin: sticker.word?.readingZhuyin, size: 22, weight: .bold, pinyin: sticker.word?.pinyin)
                        Text(sticker.word?.meaningJa ?? "").scaledFont(size: 14).foregroundStyle(Theme.muted).lineLimit(1)
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
                    Text(L("この日は場所の記録がありません"))
                        .scaledFont(size: 14, weight: .medium).foregroundStyle(Theme.foreground)
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
        // A search or filter can leave the shown day with no words: move to the newest day that has some.
        .onChange(of: days) { _, list in
            if let d = day, list.contains(d) { return }
            day = list.first
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
                            .accessibilityLabel(L("閉じる"))
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
        let path = s.heroPath
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
                                .scaledFont(size: 12, weight: .bold, monospacedDigit: true).foregroundStyle(.white)
                                .frame(minWidth: 22, minHeight: 22)
                                .background(Theme.primary, in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .offset(x: 6, y: -6)
                        }
                    }
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
                if isOn {
                    Text(JPDate.time(v.start))
                        .scaledFont(size: 13, weight: .bold, monospacedDigit: true).foregroundStyle(.white)
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
                                        .scaledFont(size: 17, weight: .bold, monospacedDigit: true)
                                        .foregroundStyle(groupOn ? Theme.primaryInk : Theme.foreground)
                                    if v.coordinate != nil || v.placeName != nil {
                                        Label {
                                            LocalizedPlaceText(lat: v.coordinate?.latitude, lng: v.coordinate?.longitude, saved: v.placeName)
                                        } icon: {
                                            Image(systemName: "mappin")
                                        }
                                        .scaledFont(size: 12).foregroundStyle(Theme.muted).lineLimit(1)
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
            .background(Theme.card.opacity(0.94), in: .rect(cornerRadius: 26, style: .continuous))
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
        let path = s.heroPath
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
                                            Text(s.word?.headword ?? "").scaledFont(size: 17, weight: .medium).foregroundStyle(Theme.foreground)
                                            if let cap = s.caption, !cap.isEmpty {
                                                Text(cap).font(AppFont.hand(15)).foregroundStyle(Theme.muted).lineLimit(1)
                                            } else {
                                                Text(s.word?.meaningJa ?? "").scaledFont(size: 15).foregroundStyle(Theme.muted).lineLimit(1)
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
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.background)  // not white: the disc is light in dark mode
                    .rotationEffect(.degrees(panelOpen ? 0 : 180))
                    .frame(width: 48, height: 48)
                    .background(Theme.foreground, in: Circle())
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .accessibilityLabel(panelOpen ? L("一覧を閉じる") : L("一覧を開く"))
            Text(day.map { JPDate.monthDayWeek($0) } ?? "—")
                .scaledFont(size: 19, weight: .bold).foregroundStyle(Theme.foreground)
            Spacer()
            circleButton("calendar") { showDatePicker = true }.accessibilityLabel(L("日付を選ぶ"))
            circleButton("chevron.left") {
                if let idx, idx + 1 < days.count { day = days[idx + 1] }
            }
            .disabled(idx == nil || (idx ?? 0) + 1 >= days.count)
            .accessibilityLabel(L("前の日"))
            circleButton("chevron.right") {
                if let idx, idx > 0 { day = days[idx - 1] }
            }
            .disabled(idx == nil || idx == 0)
            .accessibilityLabel(L("次の日"))
        }
        .padding(6)
        .background(Theme.card.opacity(0.95), in: Capsule())
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
    var id: String { items.first?.id ?? "visit-empty" }
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
    /// Filtered to nothing: one tap back to every word.
    var onClearFilters: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: isFiltered ? "line.3.horizontal.decrease.circle" : "camera.viewfinder")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.primary)
            Text(isFiltered ? L("この条件の単語はまだありません") : L("今日のページはまだ白紙です。"))
                .font(AppFont.hand(20))
                .foregroundStyle(Theme.foreground)
            if !isFiltered {
                PrimaryButton(title: L("最初の1枚を撮る"), icon: "camera.fill", sheen: true, action: onCamera)
                    .frame(maxWidth: 260)
            } else if let onClearFilters {
                Button(L("条件を外す"), action: onClearFilters)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundStyle(Theme.primaryInk)
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
