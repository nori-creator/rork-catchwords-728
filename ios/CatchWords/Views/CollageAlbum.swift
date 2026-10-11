import SwiftUI

/// One day of the home album, laid out exactly like the web (`AlbumLayout.layoutDayAlbum`, a port of
/// album-day-layout.ts): photos placed by hand stay where they were put; the rest settle around them.
/// Positions are shared with the web through the same columns, so the page looks the same on both.
///
/// Each photo is the picture chosen in 設定 › ホームに表示する写真 (`AlbumPhoto`): the cut-out alone by default.
///
/// Rearranging (web DayCollage, owner 2026-10-11: 「ホームの画像を長押ししたら、WEB版のように画像が揺れ出して、大きさや
/// 配置を自由自在に変更できるように。並べ替えボタンはけして」): a long press (0.55 s) on any photo starts it — every
/// photo wiggles, the one under the finger is lifted and follows it at once. Then any photo can be dragged, pinched
/// to any size and twisted (two fingers anywhere on it), its ✕ takes it off the album, and 「完了」 (HomeView) saves.
/// Near level a photo snaps straight with a tick; the one you touch comes to the front.
struct CollageBoard: View {
    let items: [Sticker]
    let editable: Bool
    let onOpen: (Sticker) -> Void
    /// Lay every photo out automatically, ignoring positions placed by hand (the memorial album).
    var autoOnly: Bool = false
    /// Tells the screen to stop scrolling (and show 「完了」) while photos are being moved.
    var onEditingChange: ((Bool) -> Void)? = nil
    /// Goes up when 「完了」 is pressed: an editing board saves and stops.
    var finishRequest: Int = 0

    @Environment(DexStore.self) private var dex
    @Environment(\.appReduceMotion) private var reduceMotion
    @State private var boardW: CGFloat = 0
    @State private var editing = false
    @State private var saving = false
    /// Something moved since editing began (「完了」 without a change saves nothing).
    @State private var changed = false
    /// While editing: placements changed by the fingers (not saved yet) and the front-to-back order.
    @State private var live: [String: AlbumPlacement] = [:]
    @State private var front: [String] = []
    @State private var grabbed: String?
    @State private var grabBase: AlbumPlacement?
    @State private var snapped = false

    var body: some View {
        let layout = computeLayout()
        ZStack(alignment: .topLeading) {
            ForEach(layout.items.sorted { z($0) < z($1) }, id: \.id) { item in
                if let s = items.first(where: { $0.id == item.id }) {
                    piece(s, item: item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: max(1, layout.boardH * boardW))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { boardW = $0 }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82), value: editing)
        .onChange(of: editing) { _, on in onEditingChange?(on) }
        .onChange(of: finishRequest) { _, _ in if editing { finish() } }
        // Never leave the screen frozen if this board goes away mid-edit; what was moved is kept.
        .onDisappear {
            if editing {
                if changed { persist() }
                onEditingChange?(false)
            }
        }
    }

    // MARK: Layout

    private func computeLayout() -> (items: [DayLayoutItem], boardH: Double) {
        guard boardW > 0 else { return ([], 1.25) }
        let stickers: [DayLayoutSticker] = items.map { s in
            var d = (autoOnly ? nil : dex.albumPlacements[s.id]) ?? DayLayoutSticker(id: s.id)
            d.id = s.id
            d.caption = s.caption
            if let p = live[s.id] {
                d.albumX = p.x
                d.albumY = p.y
                d.albumScale = p.scale
                d.albumRot = p.rot
            }
            if let i = front.firstIndex(of: s.id) { d.albumOrder = i }
            return d
        }
        var ratios: [String: Double] = [:]
        for s in items {
            if let path = AlbumPhoto.path(for: s), let img = ImageCache.shared.image(for: path), img.size.width > 0 {
                ratios[s.id] = img.size.height / img.size.width
            }
        }
        let input = DayLayoutInput(
            stickers: stickers,
            hasHero: { id in items.first { $0.id == id }.flatMap { AlbumPhoto.path(for: $0) } != nil },
            photoRatio: ratios,
            boardW: Double(boardW)
        )
        return AlbumLayout.layoutDayAlbum(input)
    }

    private func z(_ item: DayLayoutItem) -> Int {
        if let i = front.firstIndex(of: item.id) { return 1000 + i }
        return item.z
    }

    // MARK: A photo on the page

    @ViewBuilder
    private func piece(_ s: Sticker, item: DayLayoutItem) -> some View {
        let p = item.place
        let size = AlbumLayout.sizePx(p, boardW: Double(boardW), ratio: item.ratio)
        let hasHero = AlbumPhoto.path(for: s) != nil
        let captionH = hasHero ? AlbumLayout.dayExtra(DayLayoutSticker(id: s.id, caption: s.caption), hasHero: true, boardW: Double(boardW)) * Double(boardW) : 0
        let isGrabbed = grabbed == s.id
        let wiggles = editing && !reduceMotion && !isGrabbed
        TimelineView(.animation(minimumInterval: nil, paused: !wiggles)) { ctx in
            let w = wiggles ? Self.wiggle(s.id, at: ctx.date) : (rot: 0.0, lift: 0.0)
            card(s, hasHero: hasHero, size: size, captionH: captionH, isGrabbed: isGrabbed)
                .overlay(alignment: .topLeading) {
                    if editing && !autoOnly { removeButton(s) }
                }
                .scaleEffect(isGrabbed ? 1.08 : 1)
                .rotationEffect(.degrees(p.rot + w.rot))
                .offset(y: w.lift)
        }
        // The photo's own area takes the touches — set before it is positioned, so a tap on 地瓜 can never open the
        // photo drawn above it (`.position` makes a view as big as the whole page; 2026-10-11).
        .contentShape(.rect)
        .onTapGesture { if !editing { onOpen(s) } }
        .gesture(grabToEdit(s.id, current: p), including: editable && !autoOnly && (!editing || isGrabbed) ? .all : .subviews)
        .simultaneousGesture(manipulate(s.id, current: p), including: editing ? .all : .subviews)
        .position(x: p.x * Double(boardW), y: p.y * Double(boardW) + captionH / 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(s.word?.headword ?? "")
        .accessibilityHint(editing ? L("ドラッグで移動、2本指で大きさと傾き") : L("単語をひらく"))
        .accessibilityAction(named: L("配置を変える")) { if editable && !autoOnly && !editing { startEditing() } }
    }

    @ViewBuilder
    private func card(_ s: Sticker, hasHero: Bool, size: (w: Double, h: Double), captionH: Double, isGrabbed: Bool) -> some View {
        VStack(spacing: 4) {
            if hasHero {
                AlbumPhoto(sticker: s, width: size.w, height: size.h, lifted: isGrabbed)
                VStack(spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(s.word?.headword ?? "").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: 0x241C14))
                        Text(JPDate.time(s.takenAt)).font(.system(size: 11)).foregroundStyle(Color(hex: 0x241C14).opacity(0.55))
                    }
                    if let c = s.caption, !c.isEmpty {
                        Text(c).font(AppFont.hand(15, fixed: true)).foregroundStyle(Color(hex: 0x33291F).opacity(0.85)).lineLimit(2)
                    }
                }
                .frame(width: max(size.w, Double(boardW) * 0.3), height: max(0, captionH - 4))
            } else {
                VStack(spacing: 2) {
                    Text(s.word?.headword ?? "").font(.system(size: 24, weight: .bold)).foregroundStyle(Color(hex: 0x33291F))
                    Text(JPDate.time(s.takenAt)).font(.system(size: 11)).foregroundStyle(Color(hex: 0x33291F).opacity(0.55))
                }
                .frame(width: size.w, height: max(size.h, 44))
            }
        }
    }

    /// The red ✕ while rearranging: the photo leaves the album (it stays in the dex; 「アルバムから外した写真」 has it).
    private func removeButton(_ s: Sticker) -> some View {
        Button {
            Haptics.impact(.light)
            Task {
                let ok = await dex.setAlbumHidden(s.id, hidden: true)
                if !ok { Haptics.warning() }
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color(hex: 0xE5484D), in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .offset(x: -16, y: -16)
        .accessibilityLabel(L("アルバムから外す"))
        .transition(.scale.combined(with: .opacity))
    }

    /// The web's jiggle (album-drag.ts JIGGLE): ±1.1° and ±0.9 pt, a 240–300 ms cycle that differs per photo and
    /// starts at a different point, so the page shivers instead of swaying in step.
    private static func wiggle(_ id: String, at date: Date) -> (rot: Double, lift: Double) {
        let h = AlbumLayout.idHash(id)
        let period = 0.24 + Double((h >> 8) % 60) / 1000
        let delay = Double(h % 240) / 1000
        let phase = (date.timeIntervalSinceReferenceDate + delay) / period * 2 * Double.pi
        let v = sin(phase)
        return (v * 1.1, v * 0.9)
    }

    // MARK: Rearranging

    /// Freezes the day's positions (automatic ones included) so moving one photo never shuffles the others.
    private func startEditing() {
        guard !editing else { return }
        Haptics.impact(.medium)
        let layout = computeLayout()
        var frozen: [String: AlbumPlacement] = [:]
        for i in layout.items { frozen[i.id] = i.place }
        live = frozen
        front = layout.items.sorted { $0.z < $1.z }.map(\.id)
        changed = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { editing = true }
    }

    private func bringToFront(_ id: String) {
        guard front.last != id else { return }
        Haptics.selection()
        changed = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            front.removeAll { $0 == id }
            front.append(id)
        }
    }

    /// The long press that starts rearranging; the same finger then carries the photo (web: grabbed at once).
    private func grabToEdit(_ id: String, current: AlbumPlacement) -> some Gesture {
        LongPressGesture(minimumDuration: 0.55, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if !editing { startEditing() }
                if grabbed != id { grab(id, current: current) }
                if let drag {
                    move(id, delta: AlbumDelta(dx: drag.translation.width, dy: drag.translation.height, scale: 1, rot: 0))
                }
            }
            .onEnded { _ in release(id) }
    }

    /// Drag + pinch + twist at the same time (web album-place.ts gestureDelta / applyDelta / settle).
    private func manipulate(_ id: String, current: AlbumPlacement) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .simultaneously(with: MagnifyGesture())
            .simultaneously(with: RotateGesture())
            .onChanged { v in
                if grabbed != id { grab(id, current: current) }
                let t = v.first?.first?.translation ?? .zero
                move(id, delta: AlbumDelta(dx: t.width, dy: t.height,
                                           scale: Double(v.first?.second?.magnification ?? 1),
                                           rot: v.second?.rotation.degrees ?? 0))
            }
            .onEnded { _ in release(id) }
    }

    private func grab(_ id: String, current: AlbumPlacement) {
        grabbed = id
        grabBase = live[id] ?? current
        bringToFront(id)
        Haptics.impact(.soft)
    }

    private func move(_ id: String, delta: AlbumDelta) {
        guard let base = grabBase else { return }
        let next = AlbumLayout.applyDelta(base, delta, boardW: Double(boardW), maxY: 8)
        let nearLevel = abs(AlbumLayout.normalizeDeg(next.rot)) <= AlbumLayout.ROT_SNAP_DEG
        if nearLevel != snapped {
            snapped = nearLevel
            if nearLevel && delta.rot != 0 { Haptics.selection() }
        }
        if live[id] != next { changed = true }
        live[id] = next
    }

    private func release(_ id: String) {
        if let p = live[id] {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.7)) { live[id] = AlbumLayout.settle(p) }
        }
        grabbed = nil
        grabBase = nil
        snapped = false
    }

    /// 「完了」: saves what moved and stops rearranging.
    private func finish() {
        guard editing, !saving else { return }
        if changed { persist() }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            editing = false
            grabbed = nil
        }
        if !changed {
            live = [:]
            front = []
        }
    }

    /// Saves every photo of the day (web `persistLayout`): its order, size, place, scale and tilt.
    private func persist() {
        let layout = computeLayout()
        let byId = Dictionary(uniqueKeysWithValues: layout.items.map { ($0.id, $0) })
        let entries: [(id: String, order: Int, size: AlbumSize, place: AlbumPlacement)] = front.enumerated().compactMap { i, id in
            guard let item = byId[id] else { return nil }
            let size = dex.albumPlacements[id]?.albumSize ?? AlbumLayout.AUTO_ALBUM_SIZE[i % AlbumLayout.AUTO_ALBUM_SIZE.count]
            return (id, i, size, live[id] ?? item.place)
        }
        saving = true
        Task {
            let ok = await dex.saveAlbumLayout(entries)
            saving = false
            if ok { Haptics.success() } else { Haptics.warning() }
            // The saved places are the dex's now: the fingers' copies can go (unless editing started again).
            if !editing {
                live = [:]
                front = []
            }
            changed = false
        }
    }
}

/// One photo in the album: the picture chosen in 設定 › ホームに表示する写真 (`Sticker.homePath`). A cut-out
/// (`stickers.cutout_image_url`, a transparent PNG) stands alone like a sticker, with only a soft shadow that follows
/// its outline — no white print, paper or frame behind it; a photo or a selfie is clipped round.
struct AlbumPhoto: View {
    let sticker: Sticker
    let width: CGFloat
    let height: CGFloat
    /// Picked up while rearranging: a deeper shadow.
    var lifted: Bool = false

    @Environment(DexStore.self) private var dex

    /// The picture the album shows for a catch (設定 › ホームに表示する写真).
    nonisolated static func path(for s: Sticker) -> String? { s.homePath }

    var body: some View {
        let path = sticker.homePath
        if let path, path == sticker.cutoutImageUrl {
            StickerImage(path: path, url: dex.url(for: path, preferThumb: false), contentMode: .fit)
                .allowsHitTesting(false)
                .frame(width: width, height: height)
                .shadow(color: Color(hex: 0x5A4630).opacity(lifted ? 0.34 : 0.25), radius: lifted ? 11 : 3, y: lifted ? 11 : 2)
        } else if let path {
            StickerImage(path: path, url: dex.url(for: path, preferThumb: false), contentMode: .fill)
                .allowsHitTesting(false)
                .frame(width: width, height: height)
                .clipShape(.rect(cornerRadius: min(width, height) * 0.18, style: .continuous))
                .shadow(color: Color(hex: 0x5A4630).opacity(lifted ? 0.34 : 0.18), radius: lifted ? 11 : 4, y: lifted ? 11 : 2)
        } else {
            Color.clear.frame(width: width, height: height)
        }
    }
}
