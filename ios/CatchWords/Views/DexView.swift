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
    /// The landing word while its light is on the way: first the gallery as before the catch, then the room made
    /// for it (its waiting square at its place by No.). Cleared the moment it lands: the square becomes the word.
    @State private var galleryHold: DexBook.Hold?
    /// The gallery slot being landed on / pointed at (frame reporting, fillIn). Gone again once the landing is over.
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
            // Switching views redraws the gallery (`renderDex`): the landing's focus goes.
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
            .onChange(of: router.landing?.stickerId) { old, new in
                // The landing's provisional entry was saved and got its real id: the hold (and the room made in
                // it) and the focused slot follow it (the slot is redrawn at the same place, its fill animation
                // keeps its start time).
                if let old, let new, old != new {
                    if let h = galleryHold, h.stickerId == old {
                        galleryHold = DexBook.Hold(stickerId: new, room: h.room)
                    }
                    if var f = focus, f.id == old {
                        f.id = new
                        focus = f
                    }
                }
                takeLanding(proxy)
            }
            .onChange(of: router.landingStickerId) { _, _ in takeLanding(proxy) }
            .onChange(of: router.landing?.fillStart) { _, start in
                // pon! — addEntry + renderDex: the hold goes and the word's waiting square (the room made before the
                // flight) becomes the word in place — nothing else moves — and fills, centred.
                guard let start, let l = router.landing else { return }
                galleryHold = nil
                let id = landingSlot(l)
                focus = DexGalleryFocus(id: id, fillStart: start)
                Task {
                    await scroll(to: id, proxy: proxy)
                    // one more frame so the slot reports its new frame before the burst
                    try? await Task.sleep(for: .milliseconds(16))
                    l.settled = true
                    // The fill-in (.9 s) has played: the square is an ordinary one again (owner 2026-10-11:
                    // 「単語をキャッチしたてのとき、青表示しないで、普通に切り抜きの画像だけでいい」).
                    try? await Task.sleep(for: .seconds(1))
                    if focus?.fillStart == start { focus = nil }
                }
            }
        }
    }

    /// A card-catch landing: hold the word back (the gallery as before the catch), centre the page on its place by
    /// No. (the prototype sets `scrollTop` at once), then make room for it (`makeRoom`); CatchLandingController flies
    /// the star there once the room is made. A re-encounter's landing: centre the word's own square, no hold.
    /// Without a landing controller (`landingStickerId`): centre the word and pop its slot.
    private func takeLanding(_ proxy: ScrollViewProxy) {
        if let l = router.landing, l.fillStart == nil {
            let id = landingSlot(l)
            if l.alreadyCaught {
                guard focus?.id != id else { return }
                focus = DexGalleryFocus(id: id, fillStart: nil)
                Task {
                    await scroll(to: id, proxy: proxy)
                    // one more frame so the square reports where it is before the star leaves
                    try? await Task.sleep(for: .milliseconds(32))
                    l.roomReady = true
                }
            } else if galleryHold?.stickerId != id {
                // Reduce Motion (or a gallery drawn again mid-flight): the room is there from the start.
                let room = l.roomReady || reduceMotion
                galleryHold = DexBook.Hold(stickerId: id, room: room)
                focus = DexGalleryFocus(id: id, fillStart: nil)
                let anchor = room ? id : roomAnchor(for: id)
                Task {
                    await scroll(to: anchor, proxy: proxy, word: id)
                    if room {
                        try? await Task.sleep(for: .milliseconds(32))
                        l.roomReady = true
                    } else {
                        await makeRoom(for: l)
                    }
                }
            }
        } else if router.landing == nil, let id = router.landingStickerId {
            router.landingStickerId = nil
            galleryHold = nil
            focus = nil
            Task {
                await scroll(to: id, proxy: proxy)
                try? await Task.sleep(for: .milliseconds(200))
                let start = CCClock.now
                focus = DexGalleryFocus(id: id, fillStart: start)
                SoundService.shared.play(.landBounce)
                HapticPatterns.shared.land()
                // Only for the pop: no mark left on the square afterwards (owner 2026-10-11).
                try? await Task.sleep(for: .seconds(1))
                if focus?.fillStart == start { focus = nil }
            }
        }
    }

    /// Owner 2026-10-11 (「事前にもとの古い番号が高い単語の位置を1つ右に移動し、新しい単語はその左に入るようにして」):
    /// as the page comes to rest, the words numbered after the new one move one square to the right (its shadow
    /// fades, the next one comes in) and its square opens at its place; the star leaves when that is done.
    private func makeRoom(for l: CatchLandingController) async {
        try? await Task.sleep(for: .milliseconds(300))
        guard router.landing === l, l.fillStart == nil,
              let hold = galleryHold, hold.stickerId == l.stickerId, !hold.room else {
            l.roomReady = true
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            galleryHold = DexBook.Hold(stickerId: hold.stickerId, room: true)
        } completion: {
            l.roomReady = true
        }
    }

    /// The square a landing goes to. A re-encounter's sticker may not be the one its word's square stands for (one
    /// square per word: the newest catch of it), so it lands on its word's square.
    private func landingSlot(_ l: CatchLandingController) -> String {
        guard l.alreadyCaught, let s = dex.sticker(id: l.stickerId) else { return l.stickerId }
        let key = DexCatalog.norm(s.word?.headword ?? "", lang: lang)
        guard !key.isEmpty else { return s.id }
        let square = DexBook.words(dex.stickers, lang: lang).first { DexCatalog.norm($0.word?.headword ?? "", lang: lang) == key }
        return square?.id ?? s.id
    }

    /// The square standing at a held word's place by No. before the room is made (the first word numbered after it,
    /// else the first shadow): the page is centred there while it rises, so the room opens mid-screen.
    private func roomAnchor(for id: String) -> String {
        guard let s = dex.sticker(id: id) else { return id }
        let numbers = DexNumbering.assign(dex.stickers, lang: lang, uid: SupabaseClient.shared.userId)
        let held = DexBook.sections(stickers: dex.stickers, numbers: numbers, lang: lang,
                                    hold: DexBook.Hold(stickerId: id))
        let category = DexBook.category(of: s, lang: lang)
        guard let slots = held.first(where: { $0.category.no == category })?.slots, let last = slots.last else {
            return id
        }
        let no = numbers[id] ?? Int.max
        let at = slots.firstIndex { slot in
            guard case .caught(_) = slot.kind else { return true }
            return (slot.no ?? Int.max) > no
        }
        return at.map { slots[$0].id } ?? last.id
    }

    /// Centre a word's slot: first its category card (the gallery is lazy), then the slot itself. `word`: the
    /// sticker whose category card comes first when `id` is another square of it (a held word's place).
    private func scroll(to id: String, proxy: ScrollViewProxy, word: String? = nil) async {
        await Task.yield()
        if let s = dex.sticker(id: word ?? id) {
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

extension Sticker {
    /// The picture every dex view shows (owner 2026-10-09): the background-removed cut-out wherever the word has
    /// one, else the photo, else the stand-in picture. The word page's tap still opens the original photo.
    nonisolated var dexImagePath: String? { cutoutImageUrl ?? objectImageUrl ?? placeholderImageUrl }
    /// True when `dexImagePath` is the cut-out (drawn whole, with a little air, instead of filling the frame).
    nonisolated var dexShowsCutout: Bool { cutoutImageUrl != nil }
}

/// A dex picture: the cut-out whole (fit, `inset` of air around it, on nothing) or the photo filling its square,
/// rounded by `cornerRadius` (no tile or frame behind either, owner 2026-10-11).
struct DexThumb: View {
    @Environment(DexStore.self) private var dex
    let sticker: Sticker
    var inset: CGFloat = 4
    var preferThumb: Bool = true
    var cornerRadius: CGFloat = 0

    var body: some View {
        let path = sticker.dexImagePath
        if sticker.dexShowsCutout {
            StickerImage(path: path, url: dex.url(for: path, preferThumb: preferThumb), contentMode: .fit)
                .padding(inset)
        } else {
            Color.clear
                .overlay { StickerImage(path: path, url: dex.url(for: path, preferThumb: preferThumb), contentMode: .fill) }
                .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

/// A word drawn on one line at its natural size and scaled down (to `minScale`) to fit the width it is given,
/// so a long word (冷氣遙控器) never runs over its neighbour. For plain text `lineLimit(1)` +
/// `minimumScaleFactor` does this; a ruby (zhuyin beside each character) can't shrink that way, so it is
/// measured and scaled as a whole. Past `minScale` the rest is clipped.
struct DexFitWidth<Content: View>: View {
    var minScale: CGFloat
    var alignment: HorizontalAlignment
    let content: Content

    @State private var natural: CGSize = .zero
    @State private var available: CGFloat = 0

    init(minScale: CGFloat = 0.45, alignment: HorizontalAlignment = .leading, @ViewBuilder content: () -> Content) {
        self.minScale = minScale
        self.alignment = alignment
        self.content = content()
    }

    private var scale: CGFloat {
        guard natural.width > 0, available > 0 else { return 1 }
        return max(minScale, min(1, available / natural.width))
    }

    var body: some View {
        let s = scale
        let measured = natural.width > 0
        let boxWidth: CGFloat? = measured ? natural.width * s : nil
        let boxHeight: CGFloat? = measured ? natural.height * s : nil
        content
            .lineLimit(1)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                natural = size
            }
            .scaleEffect(s)
            // The scaled word's own box (the frame centres the full-size word, and the scale is about its centre).
            .frame(width: boxWidth, height: boxHeight)
            // minWidth 0: always exactly the width offered, never the word's own (which would overflow).
            .frame(minWidth: 0, maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { w in
                available = w
            }
            .clipped()
    }
}

struct DexListRow: View {
    @Environment(DexStore.self) private var dex
    let sticker: Sticker
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    DexThumb(sticker: sticker, inset: 2, cornerRadius: 14)
                        .frame(width: 60, height: 60)
                        .shadow(color: .black.opacity(sticker.dexShowsCutout ? 0.16 : 0.08), radius: 3, y: 2)
                        .allowsHitTesting(false)
                        .detailZoomSource(sticker.id)
                    VStack(alignment: .leading, spacing: 4) {
                        DexFitWidth {
                            ZhuyinWordView(headword: sticker.word?.headword ?? "", zhuyin: sticker.word?.readingZhuyin, size: 22, weight: .bold, pinyin: sticker.word?.pinyin)
                        }
                        Text(sticker.word?.meaningJa ?? "").scaledFont(size: 14).foregroundStyle(Theme.muted)
                            .lineLimit(1).minimumScaleFactor(0.8)
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
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selectedId = s.id; panelOpen = true }
            focusOn(s)
        } label: {
            VStack(spacing: 4) {
                Theme.secondary.frame(width: isOn ? 64 : 48, height: isOn ? 64 : 48)
                    .overlay { DexThumb(sticker: s, inset: isOn ? 7 : 5).allowsHitTesting(false) }
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
        return Button {
                                    if isOn { onOpen(s) } else {
                                        Haptics.selection()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedId = s.id }
                                        focusOn(s)
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        DexThumb(sticker: s, inset: 2, cornerRadius: 14)
                                            .frame(width: 64, height: 64)
                                            .allowsHitTesting(false)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(s.word?.headword ?? "").scaledFont(size: 17, weight: .medium).foregroundStyle(Theme.foreground)
                                                .lineLimit(1).minimumScaleFactor(0.45)
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
