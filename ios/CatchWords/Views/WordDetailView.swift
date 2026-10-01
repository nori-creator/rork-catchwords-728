import SwiftUI
import PhotosUI

/// Word detail (WordCard.tsx): a hero card, then one white card per section that has content.
struct WordDetailView: View {
    @Environment(DexStore.self) private var dex
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppRouter.self) private var router
    let sticker: Sticker
    /// DEBUG preview: open scrolled to this section so the simulator frame shows it.
    var previewFocus: CardSection? = nil

    @State private var isCutting: Bool = false
    @State private var cutoutMessage: String?
    @State private var prefs: CardPrefsStore = .shared
    @State private var showSections: Bool = false
    @State private var editingHead: Bool = false
    @State private var headDraft: String = ""
    @State private var isSavingHead: Bool = false
    @State private var toast: String?
    @State private var confirmDelete: Bool = false
    @State private var showSelfie: Bool = false
    @State private var flipAngle: Double = 0
    @State private var showCutout: Bool = false
    @State private var pickingHero: Bool = false
    @State private var showCurve: Bool = false
    @State private var refreshing: Set<CardSection> = []
    @State private var curveStore = ReviewStore()
    @State private var editingCaption: Bool = false
    @State private var captionDraft: String = ""
    /// Sections being filled by the server right now (web AutoFillSections).
    @State private var filling: Set<CardSection> = []
    @State private var reporting: Bool = false
    @State private var reportNote: String = ""
    @State private var isFixing: Bool = false
    @State private var newPhoto: PhotosPickerItem?
    @State private var isReplacing: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if !photos.isEmpty { photoHero }
                    metaCard
                    if let v = current.voiceNotePath {
                        VoiceNoteRow(url: dex.url(for: v, preferThumb: false))
                    }
                    heroCard
                    if current.cutoutImageUrl == nil, current.objectImageUrl != nil { cutoutRow }
                    EncounterHistoryView(stickerId: current.id)
                    // Web WordCard: no frequency/register meters and no separate "使う場面" card
                    // (owner: メーターいらない). Register is a chip word in the header only.
                    ForEach(visibleSections.filter { hasContent($0) || isFilling($0) }) { section in
                        if hasContent(section) {
                            sectionView(section)
                                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
                        } else {
                            SectionSkeleton(title: section.title, icon: section.icon)
                                .transition(.opacity)
                        }
                    }
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
            .onAppear {
                if let f = previewFocus {
                    Task { try? await Task.sleep(for: .milliseconds(400)); proxy.scrollTo(f.id, anchor: .top) }
                }
            }
            }
        }
        .alert(L("ひと言"), isPresented: $editingCaption) {
            TextField(L("その場のメモ"), text: $captionDraft)
            Button(L("キャンセル"), role: .cancel) {}
            Button(L("保存")) {
                let text = captionDraft
                Task {
                    do { try await dex.updateCaption(current, caption: text); Haptics.success() }
                    catch { Haptics.warning() }
                }
            }
        }
        .task(id: current.wordId + "|" + L10n.lang) { await autoFill() }
        .onAppear { prefs.use(learningLang) }
        .onChange(of: learningLang) { _, l in prefs.use(l) }
        .onAppear { applyHeroRole(animated: false) }
        .sheet(isPresented: $pickingHero) {
            HeroPhotoPickerSheet(sticker: current) { role in
                try await dex.setHeroRole(current, role: role)
                applyHeroRole(animated: true)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
        }
        .alert(L("どこが違いましたか？"), isPresented: $reporting) {
            TextField(L("例: 読み方が違う（書かなくても大丈夫）"), text: $reportNote)
            Button(L("キャンセル"), role: .cancel) {}
            Button(L("直してもらう")) { reportAndFix() }
        } message: {
            Text(L("AIが間違っている項目を見つけ、辞書と照らして、その項目だけを直します。"))
        }
        .alert(L("単語を直す"), isPresented: $editingHead) {
            TextField(learningLang == "en" ? L("英語で入力") : learningLang == "ja" ? L("日本語で入力") : L("繁体字で入力"), text: $headDraft)
            Button(L("キャンセル"), role: .cancel) {}
            Button(L("直す")) { saveHeadword() }
        } message: {
            Text(L("この写真が指す単語だけを変えます。中身は新しく作ります。"))
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Theme.foreground.opacity(0.92), in: Capsule())
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .confirmationDialog(L("この単語を図鑑から削除しますか？"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L("削除"), role: .destructive) {
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
            Button {
                Haptics.selection()
                showSections = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                    .frame(width: 44, height: 44)
                    .background(Theme.card, in: Circle())
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .accessibilityLabel(L("表示する項目と順番"))
            .popover(isPresented: $showSections, arrowEdge: .top) {
                SectionsPanel(prefs: prefs)
                    .presentationCompactAdaptation(.popover)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                    .frame(width: 44, height: 44)
                    .background(Theme.card, in: Circle())
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .accessibilityLabel(L("閉じる"))
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
                ZhuyinWordView(headword: headword, zhuyin: word?.readingZhuyin, size: 38, weight: .heavy, pinyin: word?.pinyin, language: learningLang)
                    .opacity(isSavingHead ? 0.4 : 1)
                Button {
                    headDraft = headword
                    editingHead = true
                } label: {
                    Group {
                        if isSavingHead { ProgressView() } else { Image(systemName: "pencil") }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 44, height: 44)
                }
                .disabled(isSavingHead)
                .accessibilityLabel(L("単語を直す"))
                Spacer(minLength: 8)
                PronounceCircle(text: headword, size: 50)
            }
            FlowRow(spacing: 8) {
                if let pos = word?.partOfSpeech, !pos.isEmpty { chip(posLabel(pos)) }
                if let r = extras?.resolvedRegister { chip(registerLabel(r)) }
            }
            // The reading line only when the zhuyin ruby cannot be drawn (web hides it otherwise).
            if (word?.readingZhuyin ?? "").isEmpty, let p = word?.pinyin, !p.isEmpty {
                Text(p).font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            HStack {
                Spacer()
                Button {
                    reportNote = ""
                    reporting = true
                } label: {
                    HStack(spacing: 5) {
                        if isFixing { ProgressView().controlSize(.mini) } else { Image(systemName: "flag") }
                        Text(isFixing ? L("直しています…") : L("報告"))
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(isFixing)
                .accessibilityLabel(L("この語の誤りを報告"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(light: 0xEAF3FE, dark: 0x0F2442), Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 28, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    /// The learner's visible sections that exist for this word's language.
    private var visibleSections: [CardSection] {
        let all = CardSection.sections(for: learningLang)
        return prefs.visible.filter { all.contains($0) }
    }

    /// Being written right now: one section (auto-fill) or the reader's whole explanation.
    private func isFilling(_ s: CardSection) -> Bool {
        filling.contains(s) || (s != .realUsage && dex.generatingWords.contains(current.wordId))
    }

    private func posLabel(_ pos: String) -> String {
        let map: [String: String] = ["N": L("名詞"), "V": L("動詞"), "VS": L("状態動詞"), "ADV": L("副詞"), "M": L("量詞"), "PREP": L("前置詞")]
        if let ja = map[pos.uppercased()] { return "\(pos) · \(ja)" }
        // English and Japanese part-of-speech words are shown in the display language, never as stored.
        let en: [String: String] = ["noun": L("名詞"), "verb": L("動詞"), "adjective": L("形容詞"), "adverb": L("副詞"),
                                    "preposition": L("前置詞"), "phrase": L("フレーズ"), "pronoun": L("代名詞"),
                                    "conjunction": L("接続詞"), "interjection": L("感動詞")]
        if let t = en[pos.lowercased()] { return t }
        if let t = L10n.translation(pos) { return t }
        let japaneseOnOtherScreen = L10n.lang != "ja" && !pos.isIn(target: "en")
        return ReaderLanguage.looksWrong(pos, reader: L10n.lang) || japaneseOnOtherScreen ? "" : pos
    }

    // MARK: - Photo hero (flips to the selfie like a card)

    private var frontPath: String? {
        showCutout ? (current.cutoutImageUrl ?? current.objectImageUrl) : (current.objectImageUrl ?? current.cutoutImageUrl)
    }
    private var hasSelfie: Bool { current.selfieImageUrl != nil }

    private var photoHero: some View {
        let back = showSelfie
        let path = back ? current.selfieImageUrl : frontPath
        let isCut = !back && showCutout && path == current.cutoutImageUrl
        return Color(hex: 0xEEF3F9)
            .aspectRatio(0.8, contentMode: .fit)
            .overlay {
                StickerImage(path: path, url: dex.url(for: path, preferThumb: false), contentMode: isCut ? .fit : .fill)
                    .padding(isCut ? 24 : 0)
                    .shadow(color: .black.opacity(isCut ? 0.25 : 0), radius: 12, y: 8)
                    .allowsHitTesting(false)
                    .id(path)
            }
            .overlay(alignment: .bottomTrailing) {
                if hasSelfie {
                    Text(back ? L("タップで戻る") : L("タップで自撮りへ"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: 28, style: .continuous))
            .scaleEffect(x: back ? -1 : 1)
            .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
            .contentShape(.rect(cornerRadius: 28))
            .onTapGesture { flip() }
            // 長押し: この単語をどの絵で見せるか選ぶ（Web HeroPhotoPicker）。
            .onLongPressGesture(minimumDuration: 0.45) {
                Haptics.impact(.medium)
                pickingHero = true
            }
            .accessibilityAction(named: L("表示する写真を選ぶ")) { pickingHero = true }
            .overlay(alignment: .bottomLeading) {
                if !back, current.cutoutImageUrl != nil {
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy) { showCutout.toggle() }
                    } label: {
                        Image(systemName: showCutout ? "photo" : "scissors")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .buttonStyle(PressableStyle(scale: 0.9))
                    .accessibilityLabel(showCutout ? L("元の写真を見る") : L("切り抜きを見る"))
                    .padding(10)
                    .opacity(abs(flipAngle.truncatingRemainder(dividingBy: 180)) < 1 ? 1 : 0)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(back ? L("自撮り写真") : L("写真"))
    }

    /// Shows the side the learner chose (`hero_role`): the selfie is the card's back, the cut-out a toggle.
    private func applyHeroRole(animated: Bool) {
        let role = current.heroRole
        let wantSelfie = role == "selfie" && hasSelfie
        let change = {
            // nil (まだ選んでいない) keeps the page's own default.
            if role == "cutout" || role == "object" { showCutout = role == "cutout" && current.cutoutImageUrl != nil }
            if wantSelfie != showSelfie {
                showSelfie = wantSelfie
                flipAngle = wantSelfie ? 180 : 0
            }
        }
        if animated && !reduceMotion {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78), change)
        } else {
            change()
        }
    }

    /// Half-turn with the image swapped at 90° so the selfie reads as the card's back side.
    private func flip() {
        guard hasSelfie else { return }
        Haptics.impact(.light)
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { showSelfie.toggle() }
            return
        }
        let target: Double = showSelfie ? 0 : 180
        withAnimation(.easeIn(duration: 0.16)) { flipAngle = 90 } completion: {
            showSelfie.toggle()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { flipAngle = target }
        }
    }

    // MARK: - Meta (date, place, one-liner)

    /// 棚: move this word to another shelf (web setStickerCategory). The AI's own category is listed first.
    private var shelfPicker: some View {
        let aiKey = Category.key(for: word?.categoryKey)
        let used = Set(dex.stickers.map(\.categoryKey))
        let keys = Category.allOrderedKeys.filter { used.contains($0) || !Category.isBuiltin($0) || $0 == aiKey }
        return Menu {
            Button {
                Task { try? await dex.move(current, to: nil); Haptics.selection() }
            } label: {
                Label(L("\(Category.emoji(for: aiKey)) \(Category.label(for: aiKey))（AIのおすすめ）"),
                      systemImage: current.shelfKey == nil ? "checkmark" : "sparkles")
            }
            Section(L("ほかの棚")) {
                ForEach(keys.filter { $0 != aiKey }, id: \.self) { key in
                    Button {
                        Task { try? await dex.move(current, to: key); Haptics.selection() }
                    } label: {
                        if current.shelfKey == key {
                            Label("\(Category.emoji(for: key)) \(Category.label(for: key))", systemImage: "checkmark")
                        } else {
                            Text("\(Category.emoji(for: key)) \(Category.label(for: key))")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical").font(.system(size: 14))
                Text(L("棚")).font(.system(size: 14)).foregroundStyle(Theme.muted)
                Spacer()
                Text("\(Category.emoji(for: current.categoryKey)) \(Category.label(for: current.categoryKey))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.foreground.opacity(0.75))
            .frame(minHeight: 40)
            .contentShape(.rect)
        }
        .accessibilityLabel(L("棚を変える。いまは\(Category.label(for: current.categoryKey))"))
    }

    private var metaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock").font(.system(size: 14))
                Text(JPDate.full(current.takenAt)).font(.system(size: 14)).monospacedDigit()
                Spacer(minLength: 8)
                placeChip
            }
            .foregroundStyle(Theme.foreground.opacity(0.75))
            Button {
                captionDraft = current.caption ?? ""
                editingCaption = true
            } label: {
                HStack(alignment: .center) {
                    if let cap = current.caption, !cap.isEmpty {
                        Text(cap).font(AppFont.hand(18)).foregroundStyle(Theme.foreground.opacity(0.9))
                            .multilineTextAlignment(.leading)
                    } else {
                        Text(L("ひと言")).font(.system(size: 14)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: "pencil").font(.system(size: 16)).foregroundStyle(Theme.muted)
                        .frame(width: 44, height: 40, alignment: .trailing)
                }
                .contentShape(.rect)
            }
            .buttonStyle(PressableStyle(scale: 0.98))
            .accessibilityLabel(L("ひと言を編集"))
            Divider().overlay(Theme.border)
            shelfPicker
            if let pct = dex.memoryPercent(for: current) {
                Divider().overlay(Theme.border)
                memoryRow(pct)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Theme.card, in: .rect(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    /// 記憶の曲線 (web dex.$stickerId ForgettingCurveChart): how likely you remember it now.
    private func memoryRow(_ pct: Int) -> some View {
        let lv = MemoryBadge.level(pct)
        return Button {
            Haptics.selection()
            showCurve = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.memoryLevels[lv])
                Text(L("記憶の曲線"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.foreground.opacity(0.85))
                Spacer()
                Text("\(MemoryBadge.labels[lv]) · \(pct)%")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.memoryLevels[lv].mix(with: Theme.foreground, by: 0.3))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.memoryLevels[lv].opacity(0.14), in: Capsule())
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            .frame(minHeight: 40)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .sheet(isPresented: $showCurve) {
            ForgettingCurveSheet(sticker: current, store: curveStore, onReviewNow: {
                showCurve = false
                dismiss()
                router.tab = .review
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var placeChip: some View {
        let name = current.locationName.flatMap { $0.isEmpty ? nil : $0 } ?? L("撮影地")
        return Button {
            if let url = mapsURL { openURL(url) }
        } label: {
            Label(name, systemImage: "mappin.and.ellipse")
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(Theme.primaryInk)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Theme.primary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(PressableStyle(scale: 0.95))
        .disabled(mapsURL == nil)
    }

    private var mapsURL: URL? {
        let q = (current.locationName ?? headword).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let lat = current.lat, let lng = current.lng { return URL(string: "https://maps.apple.com/?ll=\(lat),\(lng)&q=\(q)") }
        if let name = current.locationName, !name.isEmpty { return URL(string: "https://maps.apple.com/?q=\(q)") }
        return nil
    }

    private var cutoutRow: some View {
        VStack(spacing: 6) {
            Button { Task { await cutOut() } } label: {
                HStack(spacing: 8) {
                    if isCutting { ProgressView().tint(Theme.primaryInk) } else { Image(systemName: "scissors") }
                    Text(isCutting ? L("切り抜いています") : L("被写体を切り抜く"))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.primaryInk)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(Theme.primary.opacity(0.1), in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .disabled(isCutting)
            if let cutoutMessage {
                Text(cutoutMessage).font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity)
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

    private func registerLabel(_ r: Int) -> String {
        switch r {
        case ...(-2): L("話し言葉")
        case -1: L("やや話し言葉")
        case 0: L("中立")
        case 1: L("やや書き言葉")
        default: L("書き言葉")
        }
    }

    // MARK: - Sections

    private var meaningCard: some View {
        SectionCard(title: CardSection.meaning.title, icon: CardSection.meaning.icon) {
            Text(word?.meaningJa ?? "")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Section routing (card-sections.ts: draw only what has content)

    /// The word's language, corrected from its headword when the stored one is wrong (I4: "lamp" saved
    /// as a Mandarin word showed measure words and a Taiwan note).
    private var learningLang: String { LanguageRules.resolveWordLanguage(stored: word?.language, headword: headword) }
    private var exampleOK: Bool { let e = word?.exampleSentence ?? ""; return !e.isEmpty && e.isIn(target: learningLang) }
    private var extraExamples: [ExampleExtra] { (extras?.examplesExtra ?? []).filter { !$0.zh.isEmpty && $0.zh.isIn(target: learningLang) } }
    private var chunks: [UsageChunk] { refinedChunks(extras?.usageChunks ?? []) }
    private var measures: [MeasureWord] { (extras?.measureWords ?? []).filter { !$0.word.isEmpty } }
    private var pronunciationText: String { nonEmpty([extras?.pronunciationTips, extras?.studyTips]) }
    /// Radicals only for Mandarin; English adds the words built from the same parts.
    private var etymologyText: String {
        switch learningLang {
        case "zh-TW": return nonEmpty([extras?.etymology, extras?.radicals.map { $0.isEmpty ? "" : L("部首: \($0)") }])
        case "en":
            let rel = (extras?.etymologyRelatives ?? []).filter { !$0.word.isEmpty }
                .map { $0.note.isEmpty ? $0.word : "\($0.word) — \($0.note)" }.joined(separator: "\n")
            return nonEmpty([extras?.etymology, rel])
        default: return nonEmpty([extras?.etymology])
        }
    }
    private var taiwanText: String { nonEmpty([extras?.taiwanNote, extras?.trivia, extras?.usageNote]) }
    private var forms: [(String, String)] {
        guard let f = extras?.forms else { return [] }
        return [(L("複数形"), f.plural), (L("過去形"), f.past), (L("過去分詞"), f.pastParticiple), (L("-ing 形"), f.ing),
                (L("三単現"), f.third), (L("比較級"), f.comparative), (L("最上級"), f.superlative)].filter { !$1.isEmpty }
    }
    private var kanjiParts: [KanjiPart] { (extras?.kanjiBreakdown ?? []).filter { !$0.kanji.trimmingCharacters(in: .whitespaces).isEmpty } }
    private var conjugations: [ConjugationRow] { (extras?.conjugation ?? []).filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty } }
    private var counterWords: [CounterWord] { (extras?.counters ?? []).filter { !$0.word.isEmpty } }
    private var phrasals: [PhrasalVerb] { (extras?.phrasalVerbs ?? []).filter { !$0.phrase.isEmpty } }

    private func nonEmpty(_ parts: [String?]) -> String {
        parts.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private func hasContent(_ s: CardSection) -> Bool {
        switch s {
        case .meaning: !(word?.meaningJa ?? "").isEmpty
        case .example: exampleOK
        case .examplesExtra: !extraExamples.isEmpty
        case .usageChunks: !chunks.isEmpty
        case .measureWords: !measures.isEmpty
        case .relatedWords: !(extras?.allRelated.isEmpty ?? true) || !(extras?.synonymDiff ?? "").isEmpty
        case .pronunciationTips: !pronunciationText.isEmpty
        case .etymology: !etymologyText.isEmpty
        case .mnemonic: !(extras?.mnemonic ?? "").isEmpty
        case .taiwanNote: learningLang == "zh-TW" && !taiwanText.isEmpty
        case .realUsage: !headword.isEmpty
        case .forms: !forms.isEmpty
        case .countability: extras?.countability != nil
        case .phrasalVerbs: !phrasals.isEmpty
        case .stress: !(extras?.stress?.syllables.isEmpty ?? true)
        case .cultureNote: !(extras?.cultureNote ?? "").isEmpty
        case .kanjiBreakdown: !kanjiParts.isEmpty
        case .conjugation: !conjugations.isEmpty
        case .politeness: !(extras?.politeness ?? "").isEmpty
        case .counters: !counterWords.isEmpty
        case .pitchAccent: !(extras?.pitchAccent ?? "").isEmpty
        case .wordOrigin: !(extras?.wordOrigin ?? "").isEmpty
        case .japanNote: !(extras?.japanNote ?? "").isEmpty
        }
    }

    @ViewBuilder
    private func sectionView(_ s: CardSection) -> some View {
        sectionBody(s)
            .environment(\.sectionRefresh, s == .realUsage ? nil : SectionRefresh(running: refreshing.contains(s)) {
                regenerate(s)
            })
    }

    /// Web 「作り直す」 (regenerateCardSection): this one item is written again at the learner's level.
    private func regenerate(_ s: CardSection) {
        guard !refreshing.contains(s) else { return }
        Haptics.impact(.light)
        let wordId = current.wordId
        withAnimation(.snappy) { _ = refreshing.insert(s) }
        Task {
            let ok = await dex.fillSection(wordId: wordId, section: s.rawValue, onlyIfEmpty: false)
            await dex.reload(stickerId: current.id)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { _ = refreshing.remove(s) }
            if ok { Haptics.success() } else { Haptics.warning(); showToast(L("作り直せませんでした。少し待ってからお試しください")) }
        }
    }

    @ViewBuilder
    private func sectionBody(_ s: CardSection) -> some View {
        switch s {
        case .meaning: meaningCard
        case .example: exampleCard(word?.exampleSentence ?? "", word?.exampleTranslation)
        case .examplesExtra: extraExamplesCard
        case .usageChunks: chunkCard(chunks)
        case .measureWords: measureCard(measures)
        case .relatedWords: relatedCard(extras?.allRelated ?? [])
        case .pronunciationTips: textCard(s.title, icon: s.icon, pronunciationText)
        case .etymology: textCard(s.title(for: learningLang), icon: s.icon, etymologyText)
        case .mnemonic: textCard(s.title, icon: s.icon, extras?.mnemonic ?? "")
        case .taiwanNote: textCard(s.title, icon: s.icon, taiwanText)
        case .realUsage: realUsageCard
        case .forms: formsCard
        case .countability: countabilityCard
        case .phrasalVerbs: phrasalCard
        case .stress: stressCard
        case .cultureNote: textCard(s.title, icon: s.icon, extras?.cultureNote ?? "")
        case .kanjiBreakdown: kanjiCard
        case .conjugation: conjugationCard
        case .politeness: textCard(s.title, icon: s.icon, extras?.politeness ?? "")
        case .counters: countersCard
        case .pitchAccent: textCard(s.title, icon: s.icon, extras?.pitchAccent ?? "")
        case .wordOrigin: textCard(s.title, icon: s.icon, extras?.wordOrigin ?? "")
        case .japanNote: textCard(s.title, icon: s.icon, extras?.japanNote ?? "")
        }
    }

    /// extras.ts MAX_CHUNK_CHARS (8) / MAX_CHUNK_WORDS_EN (4 words, 28 chars) / MAX_CHUNK_CHARS_JA (12).
    private func tooLong(_ c: UsageChunk) -> Bool {
        switch learningLang {
        case "en":
            let words = c.parts.map(\.text).joined(separator: " ").split(separator: " ")
            return words.count > 4 || words.joined(separator: " ").count > 28
        case "ja": return c.text.count > 12
        default: return c.text.count > 8
        }
    }

    /// refineUsageChunks (extras.ts): drop measure-word patterns, sentences, too-long chunks, headword-only, duplicates; keep 5.
    private func refinedChunks(_ raw: [UsageChunk]) -> [UsageChunk] {
        let mwords = Set(measures.map(\.word))
        var seen = Set<String>()
        var out: [UsageChunk] = []
        for c in raw where !c.parts.isEmpty {
            let text = c.text
            if tooLong(c) || text == headword { continue }
            if text.contains(where: { "。！？!?".contains($0) }) { continue }
            if c.parts.contains(where: { $0.pos.uppercased() == "M" || mwords.contains($0.text) }) { continue }
            if mwords.contains(where: { !$0.isEmpty && text.contains($0) }) { continue }
            if !seen.insert(text).inserted { continue }
            out.append(c)
            if out.count == 5 { break }
        }
        return out
    }

    private var extraExamplesCard: some View {
        SectionCard(title: CardSection.examplesExtra.title, icon: CardSection.examplesExtra.icon) {
            VStack(spacing: 10) {
                ForEach(extraExamples, id: \.zh) { ex in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            if !ex.scene.isEmpty {
                                Text(ex.scene)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.primaryInk)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Theme.primary.opacity(0.1), in: Capsule())
                            }
                            Text(highlighted(ex.zh)).font(.system(size: 18)).lineSpacing(7)
                            if !ex.ja.isEmpty {
                                Text(ex.ja).font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(5)
                            }
                        }
                        Spacer(minLength: 0)
                        PronounceCircle(text: ex.zh, size: 40)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.secondary, in: .rect(cornerRadius: 22, style: .continuous))
                }
            }
        }
    }

    // MARK: - Headword edit & report

    private func saveHeadword() {
        let next = headDraft
        isSavingHead = true
        Task {
            defer { isSavingHead = false }
            do {
                try await dex.setHeadword(current, to: next)
                Haptics.success()
                showToast(L("単語を直しました"))
            } catch {
                Haptics.warning()
                showToast((error as? LocalizedError)?.errorDescription ?? L("直せませんでした"))
            }
        }
    }

    /// Web AutoFillSections: visible sections that are still empty are written by the server in
    /// parallel (free, `only_if_empty`), then revealed together — never one by one popping in.
    private func autoFill() async {
        // First this reader's own explanation (written in their display language); while it is being
        // written, the empty sections show as filling instead of another language's notes.
        let target = word?.language ?? NativeAPI.targetLanguage
        await dex.loadExplanation(wordId: current.wordId, target: target)
        // A whole explanation is being written for this reader: its sections arrive together.
        guard !Task.isCancelled, !dex.generatingWords.contains(current.wordId) else { return }
        let missing = visibleSections.filter { $0 != .realUsage && !hasContent($0) }
        guard !missing.isEmpty else { return }
        let wordId = current.wordId
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.2)) { filling = Set(missing) }
        await withTaskGroup(of: Void.self) { group in
            for section in missing {
                group.addTask { @MainActor in
                    _ = await dex.fillSection(wordId: wordId, section: section.rawValue, onlyIfEmpty: true)
                }
            }
        }
        await dex.reload(stickerId: current.id)
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { filling = [] }
    }

    /// Web reportAndFixSection (item = auto): the AI finds the wrong item among what is on screen.
    private func reportAndFix() {
        let note = reportNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordId = current.wordId
        let candidates = ["pronunciation", "pos"] + visibleSections.filter { $0 != .realUsage && hasContent($0) }.map(\.rawValue)
        isFixing = true
        Task {
            defer { isFixing = false }
            do {
                let r = try await dex.reportAndFix(wordId: wordId, candidates: candidates, note: note)
                await dex.reload(stickerId: current.id)
                Haptics.success()
                if r.fixed {
                    showToast(L("「\(Self.itemTitle(r.item))」を直しました"))
                } else {
                    showToast(L("確かめました。間違いは見つかりませんでした"))
                }
            } catch {
                Haptics.warning()
                showToast((error as? LocalizedError)?.errorDescription ?? L("直せませんでした"))
            }
        }
    }

    private static func itemTitle(_ item: String?) -> String {
        switch item {
        case "pronunciation": L("発音・読み")
        case "pos": L("品詞")
        case let key?: CardSection(rawValue: key)?.title ?? key
        default: L("項目")
        }
    }

    private func sendReport(_ kind: String) {
        let head = headword
        Task {
            do {
                try await dex.report(headword: head, kind: kind, note: "")
                Haptics.success()
                showToast(L("報告を受け付けました。確かめてから直します"))
            } catch {
                Haptics.warning()
                showToast(L("報告に失敗しました"))
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            withAnimation(.easeOut(duration: 0.25)) { if toast == text { toast = nil } }
        }
    }

    private func exampleCard(_ sentence: String, _ translation: String?) -> some View {
        SectionCard(title: L("例文"), icon: "text.quote") {
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
        return SectionCard(title: L("使い方チャンク"), icon: "square.grid.2x2") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, chunk in
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            FlowRow(spacing: 4) {
                                ForEach(Array(chunk.parts.enumerated()), id: \.offset) { i, part in
                                    HStack(spacing: 4) {
                                        if i > 0 { Text("+").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.muted.opacity(0.45)) }
                                        chunkBlock(part)
                                    }
                                }
                            }
                            Text(chunk.ja).font(.system(size: 16)).foregroundStyle(Theme.muted).lineSpacing(3)
                        }
                        Spacer(minLength: 0)
                        PronounceCircle(text: chunk.text, size: 50)
                    }
                    .padding(.vertical, 14)
                    Divider().overlay(Theme.border)
                }
                HStack(spacing: 14) {
                    ForEach(ChunkKind.allCases.filter { kinds.contains($0) }, id: \.self) { k in
                        HStack(spacing: 5) {
                            Circle().fill(k.ink).frame(width: 8, height: 8)
                            Text(k.label(for: learningLang)).font(.system(size: 13)).foregroundStyle(Theme.muted)
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
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(kind.ink.mix(with: .black, by: 0.3))
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(kind.ink.opacity(isHead ? 0.14 : 0.08), in: .rect(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(kind.ink.opacity(isHead ? 0.75 : 0.35), lineWidth: isHead ? 2.5 : 1.5)
            )
            .shadow(color: kind.ink.opacity(isHead ? 0.18 : 0), radius: 6, y: 2)
    }

    private func measureCard(_ items: [MeasureWord]) -> some View {
        SectionCard(title: L("量詞"), icon: "number") {
            VStack(spacing: 10) {
                ForEach(items, id: \.word) { m in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            // Shown as it is said: 一 + the measure word (web: 「一份」).
                            let said = m.word.hasPrefix("一") ? m.word : "一" + m.word  // l10n-ignore (target word)
                            let reading = m.word.hasPrefix("一") ? m.zhuyin : m.zhuyin.map { "ㄧ " + $0 }  // l10n-ignore (target word)
                            ZhuyinWordView(headword: said, zhuyin: reading, size: 32, weight: .heavy, language: "zh-TW")
                            if let n = m.note, !n.isEmpty {
                                Text(n).font(.system(size: 15)).foregroundStyle(Theme.muted).lineSpacing(4)
                            }
                        }
                        Spacer(minLength: 0)
                        PronounceCircle(text: m.word.hasPrefix("一") ? m.word : "一" + m.word, size: 50)  // l10n-ignore (target word)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(Theme.secondary, in: .rect(cornerRadius: 26, style: .continuous))
                }
            }
        }
    }

    private func relatedCard(_ items: [RelatedWord]) -> some View {
        let groups: [(String, String)] = [("syn", L("類義語")), ("ant", L("反義語")), ("rel", L("関連語"))]
        return SectionCard(title: L("類義語・反義語・関連語"), icon: "point.3.connected.trianglepath.dotted") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(groups, id: \.0) { kind, label in
                    let rows = items.filter { $0.kind == kind }
                    if !rows.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(label).font(.system(size: 14)).foregroundStyle(Theme.muted)
                            ForEach(rows, id: \.word) { r in
                                HStack(alignment: .center, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        relatedPill(r, kind: kind)
                                        if !r.note.isEmpty {
                                            Text(r.note).font(.system(size: 15)).foregroundStyle(Theme.muted).lineSpacing(4)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    PronounceCircle(text: r.word, size: 50)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// A word pill with its zhuyin beside each character: plain for synonyms, violet for related words,
    /// rose for antonyms (web RelatedWords).
    private func relatedPill(_ r: RelatedWord, kind: String) -> some View {
        let tint: Color = switch kind {
        case "rel": Color(hex: 0x3B3FB6)
        case "ant": Color(hex: 0xC2410C)
        default: Theme.foreground
        }
        let fill: Color = switch kind {
        case "rel": Color(hex: 0xE4E6FB)
        case "ant": Color(hex: 0xFDE7DC)
        default: Theme.card
        }
        return ZhuyinWordView(headword: r.word, zhuyin: r.reading.isEmpty ? nil : r.reading, size: 30, weight: .bold,
                              color: tint, readingColor: tint.opacity(0.6), language: learningLang)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(fill, in: Capsule())
            .overlay(Capsule().stroke(kind == "syn" ? Theme.border : .clear, lineWidth: 1.2))
    }

    // MARK: - English sections

    private var formsCard: some View {
        SectionCard(title: CardSection.forms.title, icon: CardSection.forms.icon) {
            VStack(spacing: 0) {
                ForEach(Array(forms.enumerated()), id: \.offset) { i, row in
                    HStack(spacing: 12) {
                        Text(row.0).font(.system(size: 14)).foregroundStyle(Theme.muted)
                            .frame(width: 118, alignment: .leading)
                        Text(row.1).font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.foreground)
                        Spacer(minLength: 0)
                        PronounceCircle(text: row.1, size: 36)
                    }
                    .padding(.vertical, 10)
                    if i < forms.count - 1 { Divider().overlay(Theme.border) }
                }
            }
        }
    }

    private var countabilityCard: some View {
        let c = extras?.countability
        let kind: String = switch c?.kind ?? "" {
        case "uncountable": L("数えられない（不可算）")
        case "both": L("意味によって両方")
        default: L("数えられる（可算）")
        }
        return SectionCard(title: CardSection.countability.title, icon: CardSection.countability.icon) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(kind)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.primaryInk)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.primary.opacity(0.1), in: Capsule())
                    if let a = c?.article, !a.isEmpty {
                        Text("\(a) \(headword)").font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.foreground)
                    }
                }
                if let n = c?.note, !n.isEmpty {
                    Text(n).font(.system(size: 15)).foregroundStyle(Theme.muted).lineSpacing(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var phrasalCard: some View {
        SectionCard(title: CardSection.phrasalVerbs.title, icon: CardSection.phrasalVerbs.icon) {
            VStack(spacing: 10) {
                ForEach(phrasals, id: \.phrase) { p in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(p.phrase).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.foreground)
                            if !p.meaning.isEmpty { Text(p.meaning).font(.system(size: 15)).foregroundStyle(Theme.muted) }
                            if !p.example.isEmpty, p.example.isIn(target: "en") {
                                Text(p.example).font(.system(size: 15)).italic().foregroundStyle(Theme.foreground.opacity(0.85))
                            }
                        }
                        Spacer(minLength: 0)
                        PronounceCircle(text: p.example.isEmpty ? p.phrase : p.example, size: 40)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.secondary, in: .rect(cornerRadius: 22, style: .continuous))
                }
            }
        }
    }

    /// The syllables with the stressed one large and in colour (PREsent / preSENT).
    private var stressCard: some View {
        let st = extras?.stress
        let sy = st?.syllables ?? []
        return SectionCard(title: CardSection.stress.title, icon: CardSection.stress.icon) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    ForEach(Array(sy.enumerated()), id: \.offset) { i, part in
                        let primary = i == st?.primary
                        let secondary = i == st?.secondary
                        Text(primary ? part.uppercased() : part)
                            .font(.system(size: primary ? 30 : 22, weight: primary ? .heavy : (secondary ? .semibold : .regular)))
                            .foregroundStyle(primary ? Theme.primaryInk : Theme.foreground.opacity(secondary ? 0.85 : 0.6))
                        if i < sy.count - 1 { Text("·").font(.system(size: 20)).foregroundStyle(Theme.muted) }
                    }
                    Spacer(minLength: 0)
                    PronounceCircle(text: headword, size: 40)
                }
                if let n = st?.note, !n.isEmpty {
                    Text(n).font(.system(size: 15)).foregroundStyle(Theme.muted).lineSpacing(4)
                }
            }
        }
    }

    // MARK: - Japanese sections

    /// Each kanji large, with its meaning and on / kun readings (生活 = せい / 生まれる = う / 生ビール = なま).
    private var kanjiCard: some View {
        SectionCard(title: CardSection.kanjiBreakdown.title, icon: CardSection.kanjiBreakdown.icon) {
            VStack(spacing: 10) {
                ForEach(Array(kanjiParts.enumerated()), id: \.offset) { _, k in
                    HStack(alignment: .center, spacing: 16) {
                        Text(k.kanji)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(Theme.foreground)
                            .frame(width: 64, height: 64)
                            .background(Theme.card, in: .rect(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border))
                        VStack(alignment: .leading, spacing: 5) {
                            if !k.meaning.isEmpty {
                                Text(k.meaning).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.foreground)
                            }
                            if !k.on.isEmpty { readingRow(L("音読み"), k.on) }
                            if !k.kun.isEmpty { readingRow(L("訓読み"), k.kun) }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(Theme.secondary, in: .rect(cornerRadius: 22, style: .continuous))
                }
            }
        }
    }

    private func readingRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Theme.card, in: Capsule())
            Text(value).font(.system(size: 15)).foregroundStyle(Theme.foreground.opacity(0.85))
        }
    }

    private var conjugationCard: some View {
        SectionCard(title: CardSection.conjugation.title, icon: CardSection.conjugation.icon) {
            VStack(spacing: 0) {
                ForEach(Array(conjugations.enumerated()), id: \.offset) { i, row in
                    HStack(spacing: 12) {
                        Text(row.form).font(.system(size: 14)).foregroundStyle(Theme.muted)
                            .frame(width: 118, alignment: .leading)
                        Text(row.text).font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.foreground)
                        Spacer(minLength: 0)
                        PronounceCircle(text: row.text, size: 36)
                    }
                    .padding(.vertical, 10)
                    if i < conjugations.count - 1 { Divider().overlay(Theme.border) }
                }
            }
        }
    }

    private var countersCard: some View {
        SectionCard(title: CardSection.counters.title, icon: CardSection.counters.icon) {
            VStack(spacing: 10) {
                ForEach(counterWords, id: \.word) { c in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            ZhuyinWordView(headword: c.word, zhuyin: c.reading, size: 32, weight: .heavy, language: "ja")
                            if !c.note.isEmpty {
                                Text(c.note).font(.system(size: 15)).foregroundStyle(Theme.muted).lineSpacing(4)
                            }
                        }
                        Spacer(minLength: 0)
                        PronounceCircle(text: c.word, size: 50)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(Theme.secondary, in: .rect(cornerRadius: 26, style: .continuous))
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

    /// real-usage-links.ts: where native speakers of the learning language actually use the word.
    private var realUsageLinks: [(emoji: String, label: String, url: String)] {
        let q = headword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? headword
        let path = headword.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? headword
        switch word?.language ?? NativeAPI.targetLanguage {
        case "en":
            return [
                ("🎬", L("YouTubeで聞く"), "https://www.youtube.com/results?search_query=\(q)&sp=EgIQAQ%253D%253D&gl=US&hl=en"),
                ("🗣️", L("YouGlishで発音例"), "https://youglish.com/pronounce/\(path)/english/us"),
                ("💬", L("Redditで見る"), "https://www.reddit.com/search/?q=\(q)"),
                ("📷", L("Instagram で見る"), "https://www.instagram.com/explore/tags/\(path)/"),
                ("📰", L("英語のサイトで検索"), "https://www.google.com/search?q=\(q)&hl=en&gl=US&cr=countryUS&lr=lang_en"),
                ("📖", "Merriam-Webster", "https://www.merriam-webster.com/dictionary/\(path)"),  // l10n-ignore (name)
            ]
        case "ja":
            return [
                ("🎬", L("YouTubeで聞く"), "https://www.youtube.com/results?search_query=\(q)&sp=EgIQAQ%253D%253D&gl=JP&hl=ja"),
                ("🗣️", L("YouGlishで発音例"), "https://youglish.com/pronounce/\(path)/japanese"),
                ("💬", L("Xで見る"), "https://x.com/search?q=\(q)&lang=ja"),
                ("🙋", L("Yahoo!知恵袋で見る"), "https://chiebukuro.yahoo.co.jp/search?p=\(q)"),
                ("📰", L("日本のサイトで検索"), "https://www.google.com/search?q=\(q)&hl=ja&gl=JP&cr=countryJP&lr=lang_ja"),
                ("📖", L("Weblio辞書"), "https://www.weblio.jp/content/\(path)"),
                ("📚", L("コトバンク"), "https://kotobank.jp/search?q=\(q)"),
                ("🔎", "Jisho.org", "https://jisho.org/search/\(path)"),
            ]
        default:
            return [
                ("🎬", L("YouTubeで聞く"), "https://www.youtube.com/results?search_query=\(q)&sp=EgIQAQ%253D%253D&gl=TW&hl=zh-TW"),
                ("🗣️", L("YouGlishで発音例"), "https://youglish.com/pronounce/\(path)/chinese/tw"),
                ("💬", L("Dcardで見る"), "https://www.dcard.tw/search?query=\(q)"),
                ("🧵", L("Threads で見る"), "https://www.threads.com/search?q=\(q)"),
                ("📰", L("台湾のサイトで検索"), "https://www.google.com/search?q=\(q)&hl=zh-TW&gl=TW&cr=countryTW&lr=lang_zh-TW"),
                ("📖", L("教育部國語辭典簡編本"), "https://dict.concised.moe.edu.tw/search.jsp?word=\(q)"),
            ]
        }
    }

    private var realUsageCard: some View {
        SectionCard(title: L("実際の使われ方"), icon: "film") {
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
        return VStack(alignment: .leading, spacing: 12) {
            Label(days == 0 ? L("今日キャッチしました") : L("\(days)日前にキャッチしました"), systemImage: "clock.arrow.circlepath")
                .font(AppFont.hand(16))
                .foregroundStyle(Theme.muted)
            HStack {
            PhotosPicker(selection: $newPhoto, matching: .images) {
                Label(isReplacing ? L("替えています…") : L("写真を替える"), systemImage: "photo.badge.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primaryInk)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .background(Theme.primary.opacity(0.08), in: Capsule())
            }
            .disabled(isReplacing)
            .onChange(of: newPhoto) { _, item in
                guard let item else { return }
                newPhoto = nil
                Task { await replacePhoto(item) }
            }
            Spacer()
            Button { confirmDelete = true } label: {
                Label(L("削除"), systemImage: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.destructive)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 48)
                    .background(Theme.destructive.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(Theme.destructive.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(PressableStyle(scale: 0.95))
            }
        }
        .padding(.top, 6)
    }

    /// 写真を替える: upload + web replaceStickerPhoto; in cut-out mode the new photo is cut out too.
    private func replacePhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data)?.normalizedOrientation() else { return }
        isReplacing = true
        defer { isReplacing = false }
        do {
            try await dex.replacePhoto(current, with: img)
            Haptics.success()
            showToast(L("写真を替えました"))
            if CaptureViewModel.cutoutMode, let lifted = await CutoutService.liftSubject(from: img) {
                try? await dex.addCutout(to: current, image: lifted)
            }
        } catch {
            Haptics.warning()
            showToast((error as? LocalizedError)?.errorDescription ?? L("写真を替えられませんでした"))
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
            cutoutMessage = L("この写真では切り抜けませんでした。")
            Haptics.warning()
            return
        }
        do {
            try await dex.addCutout(to: current, image: lifted)
            withAnimation(.snappy) { showCutout = true }
            Haptics.success()
        } catch {
            cutoutMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}

/// The section's 「作り直す」 button (set by the word page; the links card has none).
struct SectionRefresh {
    var running: Bool
    var action: () -> Void
}

extension EnvironmentValues {
    @Entry var sectionRefresh: SectionRefresh? = nil
}

/// White section card with a blue round icon and title (card-sections + section-icon.ts).
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    @Environment(\.sectionRefresh) private var refresh

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.primary, in: Circle())
                Text(title).font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.foreground)
                Spacer()
                if let refresh {
                    Button(action: refresh.action) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Theme.muted.opacity(0.75))
                            .rotationEffect(.degrees(refresh.running ? 360 : 0))
                            .animation(refresh.running ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: refresh.running)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(refresh.running)
                    .accessibilityLabel(L("\(title)を作り直す"))
                }
            }
            content
                .opacity(refresh?.running == true ? 0.45 : 1)
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
    case noun, verb, stative, adverb, particle

    init(pos: String) {
        let p = pos.uppercased()
        if p.hasPrefix("ADV") || p == "D" { self = .adverb }
        // Japanese particles (を・に・が) and English prepositions / articles: the glue between the words.
        else if ["P", "PART", "PREP", "DET", "ART"].contains(p) || p.contains("助詞") || p.contains("前置") { self = .particle }  // l10n-ignore (matching server POS)
        else if p.hasPrefix("VS") || p == "A" || p == "C" || p.contains("形容") || p.contains("状態") { self = .stative }  // l10n-ignore (matching server POS)
        else if p.hasPrefix("V") || p.contains("動") { self = .verb }  // l10n-ignore (matching server POS)
        else { self = .noun }
    }

    var ink: Color {
        switch self {
        case .noun: Theme.primary
        case .verb: Color(hex: 0xE5484D)
        case .stative: Color(hex: 0x2FA84F)
        case .adverb: Color(hex: 0xA08A2E)
        case .particle: Color(hex: 0x7C8798)
        }
    }

    var label: String {
        switch self {
        case .noun: L("名詞")
        case .verb: L("動詞")
        case .stative: L("状態動詞(形容詞)")
        case .adverb: L("副詞")
        case .particle: L("助詞・前置詞")
        }
    }

    /// 「状態動詞」 is a Mandarin grammar term; English and Japanese call it an adjective.
    func label(for target: String) -> String {
        self == .stative && target != "zh-TW" ? L("形容詞") : label
    }
}

/// A section being written by the server: the card's frame with a soft moving sheen.
struct SectionSkeleton: View {
    let title: String
    let icon: String
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SectionCard(title: title, icon: icon) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach([0.92, 0.7, 0.8], id: \.self) { w in
                    RoundedRectangle(cornerRadius: 6).fill(Theme.secondary)
                        .frame(height: 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(x: w, y: 1, anchor: .leading)
                }
            }
            .overlay {
                GeometryReader { g in
                    LinearGradient(colors: [.clear, .white.opacity(0.75), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.45)
                        .offset(x: phase * g.size.width * 1.4)
                }
                .mask(VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: 6).frame(height: 14) }
                })
                .allowsHitTesting(false)
            }
        }
        .accessibilityLabel(L("\(title)を作っています"))
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                phase = -1
                withAnimation(.easeInOut(duration: 1.2)) { phase = 1 }
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }
}
