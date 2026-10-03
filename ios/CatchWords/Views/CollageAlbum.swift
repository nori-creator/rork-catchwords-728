import SwiftUI

/// One day of the home album, laid out exactly like the web (`AlbumLayout.layoutDayAlbum`, a port of
/// album-day-layout.ts): photos placed by hand stay where they were put; the rest settle around them.
/// Positions are shared with the web through the same columns, so the page looks the same on both.
///
/// Today's page can be rearranged (「並べ替え」): drag, pinch and twist a photo all at once, like a real
/// print on paper. Near level it snaps straight with a haptic tick; the photo you touch comes to the front.
struct CollageBoard: View {
    let items: [Sticker]
    let editable: Bool
    let onOpen: (Sticker) -> Void
    /// Lay every photo out automatically, ignoring positions placed by hand (the memorial album).
    var autoOnly: Bool = false
    /// Tells the book to stop turning pages while photos are being moved.
    var onEditingChange: ((Bool) -> Void)? = nil

    @Environment(DexStore.self) private var dex
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var boardW: CGFloat = 0
    @State private var editing = false
    @State private var saving = false
    /// While editing: placements changed by the fingers (not saved yet) and the front-to-back order.
    @State private var live: [String: AlbumPlacement] = [:]
    @State private var front: [String] = []
    @State private var grabbed: String?
    @State private var grabBase: AlbumPlacement?
    @State private var snapped = false

    var body: some View {
        let layout = computeLayout()
        VStack(alignment: .trailing, spacing: 8) {
            if editable && items.count > 1 {
                Button {
                    if editing { save(layout) } else { startEditing(layout) }
                } label: {
                    HStack(spacing: 6) {
                        if saving { ProgressView().controlSize(.mini) }
                        Image(systemName: editing ? "checkmark" : "hand.draw")
                        Text(editing ? L("完了") : L("並べ替え"))
                    }
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(editing ? .white : Color(hex: 0x33291F).opacity(0.75))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(editing ? AnyShapeStyle(Theme.primary) : AnyShapeStyle(Color(hex: 0x33291F).opacity(0.07)), in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .disabled(saving)
            }
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
        }
        .onChange(of: editing) { _, on in onEditingChange?(on) }
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
            if let path = s.heroPath, let img = ImageCache.shared.image(for: path), img.size.width > 0 {
                ratios[s.id] = img.size.height / img.size.width
            }
        }
        let input = DayLayoutInput(
            stickers: stickers,
            hasHero: { id in items.first { $0.id == id }?.heroPath != nil },
            photoRatio: ratios,
            boardW: Double(boardW)
        )
        return AlbumLayout.layoutDayAlbum(input)
    }

    private func z(_ item: DayLayoutItem) -> Int {
        if let i = front.firstIndex(of: item.id) { return 1000 + i }
        return item.z
    }

    // MARK: A print on the paper

    @ViewBuilder
    private func piece(_ s: Sticker, item: DayLayoutItem) -> some View {
        let p = item.place
        let size = AlbumLayout.sizePx(p, boardW: Double(boardW), ratio: item.ratio)
        let hasHero = s.heroPath != nil
        let captionH = hasHero ? AlbumLayout.dayExtra(DayLayoutSticker(id: s.id, caption: s.caption), hasHero: true, boardW: Double(boardW)) * Double(boardW) : 0
        let isGrabbed = grabbed == s.id
        VStack(spacing: 4) {
            if let path = s.heroPath {
                Theme.secondary
                    .frame(width: size.w, height: size.h)
                    .overlay { StickerImage(path: path, url: dex.url(for: path), contentMode: path == s.cutoutImageUrl ? .fit : .fill).allowsHitTesting(false) }
                    .clipShape(.rect(cornerRadius: 3))
                    .padding(5)
                    .background(Color(hex: 0xFFFEFB))
                    .shadow(color: Color(hex: 0x5A4630).opacity(isGrabbed ? 0.35 : 0.18), radius: isGrabbed ? 16 : 5, y: isGrabbed ? 12 : 3)
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
        .scaleEffect(isGrabbed ? 1.04 : 1)
        .rotationEffect(.degrees(p.rot))
        .position(x: p.x * Double(boardW), y: p.y * Double(boardW) + captionH / 2)
        .contentShape(.rect)
        .onTapGesture {
            if editing { bringToFront(s.id) } else { onOpen(s) }
        }
        .gesture(manipulate(s.id, current: p), including: editing ? .all : .subviews)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(s.word?.headword ?? "")
        .accessibilityHint(editing ? L("ドラッグで移動、2本指で大きさと傾き") : L("単語をひらく"))
    }

    // MARK: Editing

    private func startEditing(_ layout: (items: [DayLayoutItem], boardH: Double)) {
        Haptics.impact(.light)
        // Freeze today's positions (auto ones included) so moving one photo never shuffles the others.
        var frozen: [String: AlbumPlacement] = [:]
        for i in layout.items { frozen[i.id] = i.place }
        live = frozen
        front = layout.items.sorted { $0.z < $1.z }.map(\.id)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { editing = true }
    }

    private func bringToFront(_ id: String) {
        guard front.last != id else { return }
        Haptics.selection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            front.removeAll { $0 == id }
            front.append(id)
        }
    }

    /// Drag + pinch + twist at the same time (web album-place.ts gestureDelta / applyDelta / settle).
    private func manipulate(_ id: String, current: AlbumPlacement) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .simultaneously(with: MagnifyGesture())
            .simultaneously(with: RotateGesture())
            .onChanged { v in
                if grabbed != id {
                    grabbed = id
                    grabBase = live[id] ?? current
                    bringToFront(id)
                    Haptics.impact(.soft)
                }
                guard let base = grabBase else { return }
                let t = v.first?.first?.translation ?? .zero
                let delta = AlbumDelta(dx: t.width, dy: t.height,
                                       scale: Double(v.first?.second?.magnification ?? 1),
                                       rot: v.second?.rotation.degrees ?? 0)
                let next = AlbumLayout.applyDelta(base, delta, boardW: Double(boardW), maxY: 8)
                let nearLevel = abs(AlbumLayout.normalizeDeg(next.rot)) <= AlbumLayout.ROT_SNAP_DEG
                if nearLevel != snapped {
                    snapped = nearLevel
                    if nearLevel { Haptics.selection() }
                }
                live[id] = next
            }
            .onEnded { _ in
                if let p = live[id] {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { live[id] = AlbumLayout.settle(p) }
                }
                grabbed = nil
                grabBase = nil
                snapped = false
            }
    }

    private func save(_ layout: (items: [DayLayoutItem], boardH: Double)) {
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                editing = false
                live = [:]
                front = []
            }
        }
    }
}
