import SwiftUI

/// Word detail (WordCard.tsx): a hero card, then one white card per section that has content.
struct WordDetailView: View {
    @Environment(DexStore.self) private var dex
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let sticker: Sticker

    @State private var isCutting: Bool = false
    @State private var cutoutMessage: String?
    @State private var photoIndex: Int = 0
    @State private var confirmDelete: Bool = false

    private var current: Sticker { dex.stickers.first { $0.id == sticker.id } ?? sticker }
    private var word: Word? { current.word }
    private var extras: WordExtras? { word?.extras }
    private var headword: String { word?.headword ?? "" }

    private var photos: [String] {
        [current.cutoutImageUrl, current.objectImageUrl].compactMap { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    if !(word?.meaningJa ?? "").isEmpty { meaningCard }
                    if !photos.isEmpty { photoCard }
                    if let e = extras, e.hasMeters { MetersPanel(extras: e) }
                    if let ex = word?.exampleSentence, !ex.isEmpty { exampleCard(ex, word?.exampleTranslation) }
                    if let chunks = extras?.usageChunks?.filter({ !$0.parts.isEmpty }), !chunks.isEmpty { chunkCard(chunks) }
                    if let mw = extras?.measureWords?.filter({ !$0.word.isEmpty }), !mw.isEmpty { measureCard(mw) }
                    if let related = extras?.allRelated, !related.isEmpty { relatedCard(related) }
                    if let ctx = extras?.usageContext, !ctx.isEmpty { textCard("使う場面", icon: "mappin.and.ellipse", ctx) }
                    if let mn = extras?.mnemonic, !mn.isEmpty { textCard("覚え方", icon: "lightbulb", mn) }
                    if !headword.isEmpty { realUsageCard }
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient(colors: [Theme.background, Theme.backgroundDeep], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
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

    // MARK: - Top bar & hero

    private var topBar: some View {
        HStack {
            Text(headword)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.muted)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                    .frame(width: 44, height: 44)
                    .background(Theme.card, in: Circle())
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .accessibilityLabel("閉じる")
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 10)
        .background(Theme.background)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZhuyinWordView(headword: headword, zhuyin: word?.readingZhuyin, size: 38, weight: .heavy)
                Spacer(minLength: 8)
                PronounceCircle(text: headword, size: 50)
            }
            FlowRow(spacing: 8) {
                if let pos = word?.partOfSpeech, !pos.isEmpty { chip(pos) }
                if let level = word?.level, !level.isEmpty { chip(levelLabel(level)) }
                if let r = extras?.resolvedRegister { chip(registerLabel(r)) }
            }
            if let p = word?.pinyin, !p.isEmpty {
                Text(p).font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: 0xEAF3FE), .white], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 28, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.foreground.opacity(0.8))
            .padding(.horizontal, 12)
            .frame(minHeight: 30)
            .background(Theme.secondary, in: Capsule())
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
    }

    private func levelLabel(_ level: String) -> String {
        let digits = level.filter(\.isNumber)
        if level.uppercased().hasPrefix("TOCFL"), let n = Int(digits), (1...7).contains(n) { return "TOCFL \(n)級" }
        if level.uppercased().hasPrefix("TOCFL") { return "TOCFL 級外の語" }
        return level
    }

    private func registerLabel(_ r: Int) -> String {
        switch r {
        case ...(-2): "話し言葉"
        case -1: "やや口語"
        case 0: "中立"
        case 1: "やや書き言葉"
        default: "書き言葉"
        }
    }

    // MARK: - Sections

    private var meaningCard: some View {
        SectionCard(title: "意味", icon: "book") {
            Text(word?.meaningJa ?? "")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var photoCard: some View {
        SectionCard(title: "写真", icon: "photo.on.rectangle") {
            VStack(spacing: 10) {
                TabView(selection: $photoIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { idx, path in
                        let isCut = path == current.cutoutImageUrl
                        Color(hex: 0xEEF3F9)
                            .overlay {
                                StickerImage(path: path, url: dex.url(for: path, preferThumb: false), contentMode: isCut ? .fit : .fill)
                                    .padding(isCut ? 20 : 0)
                                    .shadow(color: .black.opacity(isCut ? 0.25 : 0), radius: 12, y: 8)
                                    .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadius: 20, style: .continuous))
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
                .frame(height: 260)

                HStack(spacing: 10) {
                    Label(JPDate.monthDay(current.takenAt), systemImage: "calendar")
                    if let place = current.locationName, !place.isEmpty { Label(place, systemImage: "mappin").lineLimit(1) }
                    Spacer()
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)

                if let cap = current.caption, !cap.isEmpty {
                    Text(cap).font(AppFont.hand(18)).foregroundStyle(Theme.foreground.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if current.cutoutImageUrl == nil, current.objectImageUrl != nil {
                    Button { Task { await cutOut() } } label: {
                        HStack(spacing: 8) {
                            if isCutting { ProgressView().tint(Theme.primaryInk) } else { Image(systemName: "scissors") }
                            Text(isCutting ? "切り抜いています" : "被写体を切り抜く")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primaryInk)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Theme.primary.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(isCutting)
                }
                if let cutoutMessage {
                    Text(cutoutMessage).font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func exampleCard(_ sentence: String, _ translation: String?) -> some View {
        SectionCard(title: "例文", icon: "text.quote") {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(highlighted(sentence))
                        .font(.system(size: 19))
                        .foregroundStyle(Theme.foreground)
                        .lineSpacing(8)
                    if let t = translation, !t.isEmpty {
                        Text(t).font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(6)
                    }
                }
                Spacer(minLength: 0)
                PronounceCircle(text: sentence, size: 40)
            }
            .padding(16)
            .background(Theme.secondary, in: .rect(cornerRadius: 22, style: .continuous))
        }
    }

    private func highlighted(_ sentence: String) -> AttributedString {
        var out = AttributedString(sentence)
        guard !headword.isEmpty else { return out }
        var searchStart = out.startIndex
        while let r = out[searchStart...].range(of: headword) {
            out[r].foregroundColor = Theme.primaryInk
            out[r].backgroundColor = Theme.primary.opacity(0.1)
            out[r].font = .system(size: 19, weight: .semibold)
            searchStart = r.upperBound
        }
        return out
    }

    private func chunkCard(_ chunks: [UsageChunk]) -> some View {
        let shown = Array(chunks.prefix(5))
        let kinds = Set(shown.flatMap { $0.parts.map { ChunkKind(pos: $0.pos) } })
        return SectionCard(title: "使い方チャンク", icon: "square.grid.2x2") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, chunk in
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            FlowRow(spacing: 4) {
                                ForEach(Array(chunk.parts.enumerated()), id: \.offset) { i, part in
                                    HStack(spacing: 4) {
                                        if i > 0 { Text("+").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.muted.opacity(0.5)) }
                                        chunkBlock(part)
                                    }
                                }
                            }
                            Text(chunk.ja).font(.system(size: 14)).foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                        PronounceCircle(text: chunk.text, size: 40)
                    }
                    .padding(.vertical, 12)
                    Divider().overlay(Theme.border)
                }
                HStack(spacing: 14) {
                    ForEach(ChunkKind.allCases.filter { kinds.contains($0) }, id: \.self) { k in
                        HStack(spacing: 5) {
                            Circle().fill(k.ink).frame(width: 8, height: 8)
                            Text(k.label).font(.system(size: 12)).foregroundStyle(Theme.muted)
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    private func chunkBlock(_ part: ChunkPart) -> some View {
        let kind = ChunkKind(pos: part.pos)
        let isHead = part.text == headword
        return Text(part.text)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(kind.ink.mix(with: .black, by: 0.25))
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .background(kind.ink.opacity(isHead ? 0.16 : 0.09), in: .rect(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(kind.ink.opacity(isHead ? 0.8 : 0.35), lineWidth: isHead ? 2 : 1.2)
            )
    }

    private func measureCard(_ items: [MeasureWord]) -> some View {
        SectionCard(title: "量詞", icon: "number") {
            VStack(spacing: 10) {
                ForEach(items, id: \.word) { m in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(m.word).font(.system(size: 21, weight: .bold)).foregroundStyle(Theme.foreground)
                                if let z = m.zhuyin, !z.isEmpty { Text(z).font(.system(size: 13)).foregroundStyle(Theme.muted) }
                            }
                            if let n = m.note, !n.isEmpty {
                                Text(n).font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(4)
                            }
                        }
                        Spacer(minLength: 0)
                        PronounceCircle(text: m.word, size: 40)
                    }
                    .padding(14)
                    .background(Theme.secondary, in: .rect(cornerRadius: 20, style: .continuous))
                }
            }
        }
    }

    private func relatedCard(_ items: [RelatedWord]) -> some View {
        let groups: [(String, String)] = [("syn", "類義語"), ("ant", "反義語"), ("rel", "関連語")]
        return SectionCard(title: "類義語・反義語・関連語", icon: "point.3.connected.trianglepath.dotted") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(groups, id: \.0) { kind, label in
                    let rows = items.filter { $0.kind == kind }
                    if !rows.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(label).font(.system(size: 13)).foregroundStyle(Theme.muted)
                            ForEach(rows, id: \.word) { r in
                                HStack(alignment: .center, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .center, spacing: 10) {
                                            Text(r.word)
                                                .font(.system(size: 19, weight: .bold))
                                                .foregroundStyle(Color(hex: 0x3B3FB6))
                                                .padding(.horizontal, 12)
                                                .frame(minHeight: 36)
                                                .background(Color(hex: 0xE4E6FB), in: Capsule())
                                            if !r.reading.isEmpty {
                                                Text(r.reading).font(.system(size: 13)).foregroundStyle(Theme.muted)
                                            }
                                        }
                                        if !r.note.isEmpty {
                                            Text(r.note).font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(3)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    PronounceCircle(text: r.word, size: 40)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func textCard(_ title: String, icon: String, _ body: String) -> some View {
        SectionCard(title: title, icon: icon) {
            Text(body)
                .font(.system(size: 15))
                .foregroundStyle(Theme.foreground.opacity(0.9))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// real-usage-links.ts (Taiwan Mandarin set).
    private var realUsageLinks: [(emoji: String, label: String, url: String)] {
        let q = headword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? headword
        let path = headword.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? headword
        return [
            ("🎬", "YouTubeで聞く", "https://www.youtube.com/results?search_query=\(q)&sp=EgIQAQ%253D%253D&gl=TW&hl=zh-TW"),
            ("🗣️", "YouGlishで発音例", "https://youglish.com/pronounce/\(path)/chinese/tw"),
            ("💬", "Dcardで見る", "https://www.dcard.tw/search?query=\(q)"),
            ("🧵", "Threads で見る", "https://www.threads.com/search?q=\(q)"),
            ("📰", "台湾のサイトで検索", "https://www.google.com/search?q=\(q)&hl=zh-TW&gl=TW&cr=countryTW&lr=lang_zh-TW"),
            ("📖", "教育部國語辭典簡編本", "https://dict.concised.moe.edu.tw/search.jsp?word=\(q)"),
        ]
    }

    private var realUsageCard: some View {
        SectionCard(title: "実際の使われ方", icon: "film") {
            VStack(spacing: 10) {
                ForEach(realUsageLinks, id: \.label) { link in
                    Button {
                        if let url = URL(string: link.url) { openURL(url) }
                    } label: {
                        HStack(spacing: 14) {
                            Text(link.emoji).font(.system(size: 20))
                            Text(link.label).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.foreground)
                            Spacer()
                            Image(systemName: "arrow.up.right.square").font(.system(size: 16)).foregroundStyle(Theme.muted)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 50)
                        .background(Theme.secondary, in: Capsule())
                        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle(scale: 0.98))
                }
            }
        }
    }

    private var footer: some View {
        let days = Calendar.current.dateComponents([.day], from: current.takenAt, to: Date()).day ?? 0
        return HStack {
            Label(days == 0 ? "今日キャッチしました" : "\(days)日前にキャッチしました", systemImage: "clock.arrow.circlepath")
                .font(AppFont.hand(16))
                .foregroundStyle(Theme.muted)
            Spacer()
            Button { confirmDelete = true } label: {
                Label("削除", systemImage: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.destructive)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 48)
                    .background(Theme.destructive.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(Theme.destructive.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(PressableStyle(scale: 0.95))
        }
        .padding(.top, 6)
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

/// White section card with a blue round icon and title (card-sections + section-icon.ts).
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Theme.primary, in: Circle())
                Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.foreground)
                Spacer()
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

/// Chunk colors by grammatical role: noun blue, verb red, stative green, adverb gold.
enum ChunkKind: CaseIterable, Hashable {
    case noun, verb, stative, adverb

    init(pos: String) {
        let p = pos.uppercased()
        if p.hasPrefix("ADV") || p == "D" { self = .adverb }
        else if p.hasPrefix("VS") || p == "A" || p == "C" || p.contains("形容") || p.contains("状態") { self = .stative }
        else if p.hasPrefix("V") || p.contains("動") { self = .verb }
        else { self = .noun }
    }

    var ink: Color {
        switch self {
        case .noun: Theme.primary
        case .verb: Color(hex: 0xE5484D)
        case .stative: Color(hex: 0x2FA84F)
        case .adverb: Color(hex: 0xA08A2E)
        }
    }

    var label: String {
        switch self {
        case .noun: "名詞"
        case .verb: "動詞"
        case .stative: "状態動詞(形容詞)"
        case .adverb: "副詞"
        }
    }
}
