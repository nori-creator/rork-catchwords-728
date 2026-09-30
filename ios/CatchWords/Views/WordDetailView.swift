import SwiftUI

/// Word detail: sections are drawn only when they have content (no empty headers).
struct WordDetailView: View {
    @Environment(DexStore.self) private var dex
    @Environment(\.dismiss) private var dismiss
    let sticker: Sticker

    @State private var isCutting: Bool = false
    @State private var cutoutMessage: String?
    @State private var photoIndex: Int = 0
    @State private var confirmDelete: Bool = false

    private var current: Sticker { dex.stickers.first { $0.id == sticker.id } ?? sticker }
    private var word: Word? { current.word }
    private var extras: WordExtras? { word?.extras }

    private var photos: [String] {
        [current.cutoutImageUrl, current.objectImageUrl].compactMap { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                photoCarousel
                header
                if let e = extras, e.hasMeters { MetersPanel(extras: e) }
                if let weights = extras?.sceneWeights, !weights.isEmpty { sceneTags(weights) }
                if let chunks = extras?.usageChunks?.filter({ !$0.parts.isEmpty }), !chunks.isEmpty { chunkSection(chunks) }
                if let ex = word?.exampleSentence, !ex.isEmpty { exampleSection(ex, word?.exampleTranslation) }
                if let mw = extras?.measureWords?.filter({ !$0.word.isEmpty }), !mw.isEmpty { measureSection(mw) }
                if let ctx = extras?.usageContext, !ctx.isEmpty { textSection("使う場面", ctx) }
                if let mn = extras?.mnemonic, !mn.isEmpty { textSection("覚え方", mn) }
                memorySection
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("図鑑から削除", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .foregroundStyle(Theme.destructive.opacity(0.85))
            }
            .padding(20)
            .padding(.bottom, 30)
        }
        .confirmationDialog("この単語を図鑑から削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                Task {
                    try? await dex.delete(current)
                    dismiss()
                }
            }
        }
    }

    private var photoCarousel: some View {
        VStack(spacing: 10) {
            TabView(selection: $photoIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { idx, path in
                    let isCut = path == current.cutoutImageUrl
                    ZStack {
                        RadialGradient(colors: [current.room.accent.opacity(0.3), Theme.card], center: .center, startRadius: 10, endRadius: 220)
                        StickerImage(path: path, url: dex.url(for: path, preferThumb: false), contentMode: isCut ? .fit : .fill)
                            .padding(isCut ? 24 : 0)
                            .shadow(color: .black.opacity(isCut ? 0.45 : 0), radius: 16, y: 12)
                    }
                    .clipShape(.rect(cornerRadius: 24))
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .frame(height: 300)

            if current.cutoutImageUrl == nil, current.objectImageUrl != nil {
                Button { Task { await cutOut() } } label: {
                    HStack(spacing: 8) {
                        if isCutting { ProgressView().tint(.white) } else { Image(systemName: "scissors") }
                        Text(isCutting ? "切り抜いています" : "被写体を切り抜く")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .glassCard(22)
                }
                .buttonStyle(PressableStyle())
                .disabled(isCutting)
            }
            if let cutoutMessage {
                Text(cutoutMessage).font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
        }
        .padding(.top, 12)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let z = word?.readingZhuyin, !z.isEmpty {
                Text(z).font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            HStack(alignment: .center, spacing: 12) {
                Text(word?.headword ?? "")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Theme.foreground)
                Button { SoundService.shared.speak(word?.headword ?? "") } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(Theme.primary)
                        .frame(width: 44, height: 44)
                        .background(Theme.card, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("発音を聞く")
                Spacer()
                if let level = word?.level {
                    Text(level).font(AppFont.mono(11, weight: .bold)).foregroundStyle(Theme.primaryInk)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.accent, in: Capsule())
                }
            }
            if let p = word?.pinyin, !p.isEmpty {
                Text(p).font(AppFont.mono(14)).foregroundStyle(Theme.primaryInk)
            }
            HStack(spacing: 8) {
                if let pos = word?.partOfSpeech, !pos.isEmpty {
                    Text(pos).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.chunkO)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(Capsule().stroke(Theme.chunkO.opacity(0.5)))
                }
                Text(word?.meaningJa ?? "").font(.system(size: 19, weight: .semibold)).foregroundStyle(Theme.foreground)
            }
            HStack(spacing: 12) {
                Label(current.takenAt.formatted(.dateTime.year().month().day()), systemImage: "calendar")
                if let place = current.locationName { Label(place, systemImage: "mappin") }
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .padding(.top, 4)
            if let cap = current.caption, !cap.isEmpty {
                Text(cap).font(AppFont.hand(18)).foregroundStyle(Theme.foreground.opacity(0.9)).padding(.top, 4)
            }
        }
    }

    private func sceneTags(_ weights: [String: Double]) -> some View {
        let top = weights.compactMap { key, v -> (Room, Double)? in
            guard let r = Room(rawValue: key), v >= 0.12 else { return nil }
            return (r, v)
        }.sorted { $0.1 > $1.1 }.prefix(3)
        return Group {
            if !top.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "出会う場面")
                    HStack(spacing: 8) {
                        ForEach(Array(top), id: \.0) { room, v in
                            Label("\(room.label) \(Int(v * 100))%", systemImage: room.symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(room.accent)
                                .padding(.horizontal, 12).frame(minHeight: 32)
                                .background(room.accent.opacity(0.14), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    /// Compact 2-column rows: Taiwan Mandarin chunk (colored by role) left, short Japanese right.
    private func chunkSection(_ chunks: [UsageChunk]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "使い方チャンク")
            VStack(spacing: 0) {
                ForEach(Array(chunks.prefix(4).enumerated()), id: \.offset) { idx, chunk in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Button { SoundService.shared.speak(chunk.text) } label: {
                            HStack(spacing: 2) {
                                ForEach(Array(chunk.parts.enumerated()), id: \.offset) { _, part in
                                    Text(part.text)
                                        .font(.system(size: 19, weight: part.slot == true ? .regular : .semibold))
                                        .foregroundStyle(color(for: part))
                                        .underline(part.slot == true, pattern: .dot)
                                }
                                Image(systemName: "speaker.wave.1").font(.system(size: 11)).foregroundStyle(Theme.muted).padding(.leading, 4)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 8)
                        Text(chunk.ja)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.trailing)
                    }
                    .frame(minHeight: 44)
                    if idx < min(chunks.count, 4) - 1 { Divider().overlay(Theme.border) }
                }
            }
            .padding(.horizontal, 14)
            .background(Theme.card, in: .rect(cornerRadius: Theme.radius))
        }
    }

    private func color(for part: ChunkPart) -> Color {
        if part.slot == true { return Theme.muted }
        let p = part.pos.uppercased()
        if p.hasPrefix("V") { return Theme.chunkV }
        if p.hasPrefix("O") || p == "N" { return Theme.chunkO }
        return Theme.foreground
    }

    private func exampleSection(_ sentence: String, _ translation: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "例文")
            Button { SoundService.shared.speak(sentence) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Text(sentence).font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.foreground)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "play.circle.fill").font(.title3).foregroundStyle(Theme.primary)
                    }
                    if let t = translation, !t.isEmpty {
                        Text(t).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: .rect(cornerRadius: Theme.radius))
            }
            .buttonStyle(PressableStyle(scale: 0.98))
        }
    }

    private func measureSection(_ items: [MeasureWord]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "量詞")
            ForEach(items, id: \.word) { m in
                HStack(spacing: 10) {
                    Text(m.word).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.gold)
                    if let z = m.zhuyin { Text(z).font(.system(size: 12)).foregroundStyle(Theme.muted) }
                    Spacer()
                    if let n = m.note { Text(n).font(.system(size: 12)).foregroundStyle(Theme.muted).multilineTextAlignment(.trailing) }
                }
                .padding(.horizontal, 14).frame(minHeight: 48)
                .background(Theme.card, in: .rect(cornerRadius: Theme.radius))
            }
        }
    }

    private func textSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title)
            Text(body)
                .font(.system(size: 15))
                .foregroundStyle(Theme.foreground.opacity(0.9))
                .lineSpacing(4)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: .rect(cornerRadius: Theme.radius))
        }
    }

    private var memorySection: some View {
        let days = Calendar.current.dateComponents([.day], from: current.takenAt, to: Date()).day ?? 0
        return HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath").foregroundStyle(Theme.gold)
            Text(days == 0 ? "今日キャッチしました" : "\(days)日前にキャッチしました")
                .font(AppFont.hand(16))
                .foregroundStyle(Theme.foreground)
        }
    }

    private func cutOut() async {
        guard let path = current.objectImageUrl else { return }
        isCutting = true
        cutoutMessage = nil
        defer { isCutting = false }
        var image = ImageCache.shared.image(for: path)
        if image == nil, let url = dex.url(for: path, preferThumb: false) {
            image = await ImageCache.shared.load(url: url, key: path)
        }
        guard let image, let lifted = await CutoutService.liftSubject(from: image) else {
            cutoutMessage = "この写真では切り抜けませんでした。"
            Haptics.warning()
            return
        }
        do {
            try await dex.addCutout(to: current, image: lifted)
            photoIndex = 0
            Haptics.success()
        } catch {
            cutoutMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}
