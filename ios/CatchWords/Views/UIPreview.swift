import SwiftUI

/// Screens the GitHub "iOS check" opens directly (launch argument `-uiPreview <name>`), so changes to
/// animation and design can be photographed on the simulator without an iPhone, a login, or the network.
/// Development (DEBUG) builds only — App Store builds never read the argument.
enum UIPreview {
    static var requested: String? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "uiPreview")
        #else
        return nil
        #endif
    }

    /// The requested scene, parsed once (it sets the display language, so never during a redraw).
    static let parsed: (scene: String, dark: Bool)? = requested.map(parse)

    /// "settings-en-dark" → scene "settings", English, dark. Sets the display language as a side effect.
    static func parse(_ raw: String) -> (scene: String, dark: Bool) {
        var parts = raw.split(separator: "-").map(String.init)
        var dark = false
        var lang = "ja"
        while let last = parts.last, parts.count > 1, ["dark", "en", "zh", "ja"].contains(last) {
            if last == "dark" { dark = true } else { lang = last == "zh" ? "zh-TW" : last }
            parts.removeLast()
        }
        L10n.lang = lang
        return (parts.joined(separator: "-"), dark)
    }
}

/// CI photographs screens from outside the app (`xcrun simctl io screenshot`, .github/workflows/ios-check.yml),
/// where XCUITest's `waitForExistence` is not available. Instead the app leaves a file in
/// Caches/ui-ready/<name> once a known element of the screen is on screen, and the workflow waits for that
/// file before the first picture — so a slow launch or an entrance transition is never captured as a blank
/// frame. DEBUG builds launched with `-uiPreview` / `-uiDemo` only; nothing is written otherwise.
enum UIReady {
    static func mark(_ name: String) {
        #if DEBUG
        guard UIPreview.requested != nil || DemoBackend.isOn else { return }
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ui-ready", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? Data().write(to: dir.appendingPathComponent(name))
        #endif
    }
}

extension View {
    /// Marks the screen ready for CI's screenshots once this element has appeared (plus a short settle, so
    /// the first frame has been drawn). No effect in App Store builds.
    func uiReady(_ name: String) -> some View {
        #if DEBUG
        onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                UIReady.mark(name)
            }
        }
        #else
        self
        #endif
    }
}

#if DEBUG
struct UIPreviewRoot: View {
    let name: String
    @State private var router = AppRouter()

    var body: some View {
        Group {
            switch name {
            case "cutout": CutoutPreview()
            case "picker": PickerPreview()
            case "japicker": PickerPreview(learning: "ja")
            case "enpicker": PickerPreview(learning: "en")
            case "tabbar": TabBarPreview()
            case "reward": RewardPreview()
            case "analyzing":
                AnalyzingView(photo: PreviewFixtures.photo,
                              previewTargets: [CGRect(x: 0.27, y: 0.27, width: 0.46, height: 0.45),
                                               CGRect(x: 0.45, y: 0.27, width: 0.16, height: 0.12)]) {}
                    .uiReady("preview")
            case "hero": HeroPickerPreview()
            case "journal": JournalPreview()
            case "memorial": MemorialPreview()
            case "book": BookPreview()
            case "carousel": CarouselPreview()
            case "bookturn": BookPreview(frozenTurn: 0.38)
            case "detail": DetailPreview()
            case "webimg": WebImagesPreview()
            case "chunks": ChunkWheelPreview()
            case "jadetail": LanguageCardPreview(kind: .ja)
            case "quiz": ReviewPreview(learning: "zh-TW", answered: false)
            case "answer": ReviewPreview(learning: "zh-TW", answered: true)
            case "jaquiz": ReviewPreview(learning: "ja", answered: false)
            case "enanswer": ReviewPreview(learning: "en", answered: true)
            case "endetail": LanguageCardPreview(kind: .en)
            case "settings": SettingsView()
            case "auth": AuthView()
            case "onboarding": OnboardingView {}
            case "aiconsent": AIConsentView()
            case "paywall": PaywallView()
            case "dex": DexView()
            case "done": DonePreview()
            case "homeload": VStack(spacing: 20) {
                AlbumSkeleton().frame(height: 440)
                AlbumLoadFailed(message: L("通信できませんでした。電波のよい場所でもう一度お試しください。")) {}.frame(height: 300)
            }.padding(16).background(HomeBackground())
            default: Text("unknown preview: \(name)")
            }
        }
        // Scenes that mark a known element of their own (the quiz card, the analysis view, the web-images
        // section) are ready only when that element is up; every other scene when its root appears.
        .uiReady(Self.marksOwnElement.contains(name) ? "root-\(name)" : "preview")
        .environment(router)
    }

    private static let marksOwnElement: Set<String> = ["analyzing", "quiz", "answer", "jaquiz", "enanswer", "webimg"]
}

/// A made-up photo (sky + ground + a round "mango") and its lifted subject, the same size,
/// because the Vision cut-out does not run on the simulator.
enum PreviewFixtures {
    static let size = CGSize(width: 900, height: 900)

    static let photo: UIImage = UIGraphicsImageRenderer(size: size).image { ctx in
        let c = ctx.cgContext
        let colors = [UIColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1).cgColor,
                      UIColor(red: 0.93, green: 0.88, blue: 0.78, alpha: 1).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
        UIColor(red: 0.62, green: 0.48, blue: 0.36, alpha: 1).setFill()
        c.fill(CGRect(x: 0, y: size.height * 0.68, width: size.width, height: size.height * 0.32))
        drawSubject(in: c)
    }

    static let subject: UIImage = {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in drawSubject(in: ctx.cgContext) }
    }()

    private static func drawSubject(in c: CGContext) {
        UIColor(red: 1, green: 0.72, blue: 0.16, alpha: 1).setFill()
        c.fillEllipse(in: CGRect(x: 250, y: 300, width: 400, height: 330))
        UIColor(red: 0.95, green: 0.45, blue: 0.2, alpha: 1).setFill()
        c.fillEllipse(in: CGRect(x: 470, y: 330, width: 150, height: 120))
        UIColor(red: 0.2, green: 0.55, blue: 0.25, alpha: 1).setFill()
        c.fillEllipse(in: CGRect(x: 420, y: 250, width: 110, height: 70))
    }

    static let lift = CutoutService.Lift(cropped: subjectCropped, full: subject, photo: photo)

    /// The subject cropped to its bounds, like the saved sticker.
    static let subjectCropped: UIImage = {
        // cgImage is in pixels (the renderer draws at screen scale), so scale the point rect.
        let s = subject.scale
        let rect = CGRect(x: 240 * s, y: 240 * s, width: 420 * s, height: 400 * s)
        guard let cg = subject.cgImage?.cropping(to: rect) else { return subject }
        return UIImage(cgImage: cg, scale: s, orientation: .up)
    }()
}

/// The cut-out animation, replayed every 3 seconds.
private struct CutoutPreview: View {
    @State private var round = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("切り抜きアニメーション").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.foreground)
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [.white, Theme.secondary], startPoint: .top, endPoint: .bottom))
                CutoutRevealView(lift: PreviewFixtures.lift) {}
                    .padding(8)
                    .id(round)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 16)
            Spacer()
        }
        .padding(.top, 60)
        .background(AppBackground())
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                round += 1
            }
        }
    }
}

/// The candidate picker with made-up suggestions (two objects; the first has other names).
private struct PickerPreview: View {
    var learning: String = "zh-TW"
    @State private var vm = CaptureViewModel()

    /// headword, reading, meaning in ja / en / zh-TW, distinction in ja / en / zh-TW, register, group
    private typealias Row = (String, String, [String], [String], String?, Int)

    private var rows: [Row] {
        switch learning {
        case "ja":
            return [("マンゴー", "", ["マンゴー", "mango", "芒果"], ["ふだんの言い方", "the everyday word", "日常說法"], "common", 0),
                    ("アップルマンゴー", "", ["アップルマンゴー", "apple mango", "蘋果芒果"], ["品種の名前", "a variety", "品種名稱"], "specific", 0),
                    ("皿", "さら", ["皿", "plate", "盤子"], ["", "", ""], nil, 1)]
        case "en":
            return [("mango", "", ["マンゴー", "mango", "芒果"], ["ふだんの言い方", "the everyday word", "日常說法"], "common", 0),
                    ("Irwin mango", "", ["アーウィンマンゴー", "Irwin mango", "愛文芒果"], ["品種の名前", "a variety", "品種名稱"], "specific", 0),
                    ("plate", "", ["お皿", "plate", "盤子"], ["", "", ""], nil, 1)]
        default:
            return [("芒果", "ㄇㄤˊ ㄍㄨㄛˇ", ["マンゴー", "mango", "芒果"], ["ふだんの言い方", "the everyday word", "日常說法"], "common", 0),
                    ("愛文芒果", "ㄞˋ ㄨㄣˊ ㄇㄤˊ ㄍㄨㄛˇ", ["アーウィンマンゴー", "Irwin mango", "愛文芒果"], ["品種の名前", "a variety", "品種名稱"], "specific", 0),
                    ("檨仔", "ㄙㄨㄟˋ ㄚˇ", ["マンゴー（台湾語由来）", "mango (from Taiwanese)", "芒果（台語）"], ["年配の人の言い方", "older people's word", "長輩的說法"], "casual", 0),
                    ("盤子", "ㄆㄢˊ ㄗ˙", ["お皿", "plate", "盤子"], ["", "", ""], nil, 1)]
        }
    }

    var body: some View {
        CandidatePickerView(vm: vm)
            .onAppear {
                NativeAPI.targetLanguage = learning
                let i = L10n.lang == "en" ? 1 : L10n.lang == "zh-TW" ? 2 : 0
                vm.photo = PreviewFixtures.photo
                vm.candidates = rows.map { r in
                    Candidate(kind: "object", headword: r.0, zhuyin: r.1, pinyin: "", meaningJa: r.2[i], pos: NativeAPI.defaultPos,
                              point: [500, 500], confidence: 0.9, alternatives: [], distinction: r.3[i], register: r.4, group: r.5)
                }
                vm.step = .select
            }
    }
}

/// The full catch celebration with the cut-out sticker, replayed every 7 seconds.
/// The save never "finishes" here, so the 1 s hold shows its breathing state.
private struct RewardPreview: View {
    @State private var round = 0

    var body: some View {
        ZStack {
            AppBackground()
            RewardOverlay(payload: RewardPayload(
                image: PreviewFixtures.subjectCropped, isCutout: true, headword: "芒果",
                reading: "ㄇㄤˊ ㄍㄨㄛˇ", pinyin: "mángguǒ", meaning: "マンゴー", rarity: 0, gate: SaveGate()
            )) {}
            .id(round)
        }
        .ignoresSafeArea()
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7))
                round += 1
            }
        }
    }
}

/// The tab bar on a light page and on the dark camera.
private struct TabBarPreview: View {
    @State private var home: AppTab = .home
    @State private var camera: AppTab = .camera

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            CapsuleTabBar(selection: $home, onCamera: false)
            ZStack {
                Theme.navyDeep.frame(height: 140)
                CapsuleTabBar(selection: $camera, onCamera: true)
            }
            Spacer()
        }
        .background(AppBackground())
    }
}
/// 「表示する写真」: the sheet's grid with original, cut-out and selfie, the cut-out chosen.
private struct HeroPickerPreview: View {
    private static let sticker: Sticker = {
        ImageCache.shared.set(PreviewFixtures.photo, for: "preview/hero-object.jpg")
        ImageCache.shared.set(PreviewFixtures.subject, for: "preview/hero-cutout.png")
        let selfie = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600)).image { ctx in
            UIColor(red: 0.98, green: 0.86, blue: 0.78, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
            UIColor(red: 0.45, green: 0.32, blue: 0.25, alpha: 1).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 190, y: 120, width: 220, height: 260))
        }
        ImageCache.shared.set(selfie, for: "preview/hero-selfie.jpg")
        var s = Sticker(id: "hero", wordId: "w", objectImageUrl: "preview/hero-object.jpg",
                        cutoutImageUrl: "preview/hero-cutout.png", selfieImageUrl: "preview/hero-selfie.jpg",
                        caption: nil, locationName: nil, takenAt: Date(), captureType: "photo", word: nil)
        s.heroRole = "cutout"
        return s
    }()

    var body: some View {
        HeroPhotoPickerSheet(sticker: Self.sticker) { _ in }
            .padding(.top, 60)
    }
}
/// The diary's AI correction result (corrected text, pattern notes, native phrases).
private struct JournalPreview: View {
    private static let entry: JournalEntry = {
        let json = #"""
        {"id":"j","entry_date":"2026-09-30","body_zh":null,"body_ja":null,
         "user_draft":"今天我去咖啡店，我喝咖啡很好喝。",
         "correction":"今天我去了咖啡店，喝的咖啡很好喝。",
         "feedback_ja":"・「去了」で、もう行ったことを表します。\n・「我喝咖啡很好喝」は主語が2つに見えるので「喝的咖啡很好喝」にまとめます。",
         "native_phrases":[{"zh":"這杯咖啡超好喝的！","ja":"このコーヒー、めっちゃおいしい！","note":"友だちに感動を伝えるとき"},
                           {"zh":"我今天去咖啡廳坐了一下","ja":"今日はカフェでちょっと過ごした","note":"「坐一下」はくつろぐニュアンス"}]}
        """#
        return try! JSONDecoder().decode(JournalEntry.self, from: Data(json.utf8))
    }()

    var body: some View {
        ScrollView {
            CorrectionBlock(entry: Self.entry, highlight: true)
                .padding(16)
                .padding(.top, 50)
        }
        .background(Theme.background)
    }
}
/// The milestone celebration (day count, confetti, photos fanning out).
private struct MemorialPreview: View {
    private static let photos: [String] = (0..<7).map { i in
        let path = "preview/memorial-\(i).jpg"
        let img = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 380)).image { ctx in
            let h = CGFloat(i) / 7
            UIColor(hue: h, saturation: 0.35, brightness: 0.95, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 380))
            UIColor(hue: h, saturation: 0.7, brightness: 0.75, alpha: 1).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 70, y: 90, width: 160, height: 150))
        }
        ImageCache.shared.set(img, for: path)
        return path
    }

    var body: some View {
        MemorialReveal(n: 30, words: 48, photos: Self.photos) {}
    }
}
/// The dex slide view (white cards on a ring in the pale blue room), opened on the second card.
private struct CarouselPreview: View {
    private static let stickers: [Sticker] = {
        let words = [("芒果", "マンゴー"), ("咖啡", "コーヒー"), ("雨傘", "傘"), ("盤子", "お皿"), ("花", "花"), ("麵包", "パン")]
        return words.enumerated().compactMap { i, w -> Sticker? in
            let json = #"{"id":"cw\#(i)","headword":"\#(w.0)","meaning_ja":"\#(w.1)"}"#
            guard let word = try? JSONDecoder().decode(Word.self, from: Data(json.utf8)) else { return nil }
            let path = "preview/carousel-\(i).jpg"
            let img = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600)).image { ctx in
                let hue = CGFloat(i) / 6
                UIColor(hue: hue, saturation: 0.4, brightness: 0.93, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
                UIColor(hue: hue, saturation: 0.7, brightness: 0.72, alpha: 1).setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: 150, y: 150, width: 300, height: 300))
            }
            ImageCache.shared.set(img, for: path)
            return Sticker(id: "c\(i)", wordId: "w", objectImageUrl: path, cutoutImageUrl: nil, selfieImageUrl: nil,
                           caption: nil, locationName: i == 1 ? "台北" : nil,
                           takenAt: Date().addingTimeInterval(Double(-i) * 86400), captureType: "photo", word: word)
        }
    }()

    var body: some View {
        ZStack(alignment: .top) {
            DexGalleryBackdrop()
            DexCoverFlow(stickers: Self.stickers, onOpen: { _ in }, initialIndex: 1)
                .padding(.top, 118)
        }
    }
}

/// The month book: slides to the diary page, then turns the page to the next day (autoplay).
private struct BookPreview: View {
    var frozenTurn: CGFloat? = nil
    private static let days: [BookDay] = {
        let cal = Calendar.current
        let words = [("芒果", "マンゴー"), ("盤子", "お皿"), ("咖啡", "コーヒー"), ("雨傘", "傘"), ("花", "花")]
        var out: [BookDay] = []
        for d in 0..<3 {
            let day = cal.date(byAdding: .day, value: d - 2, to: cal.startOfDay(for: Date()))!
            var items: [Sticker] = []
            for j in 0..<(d == 1 ? 1 : 2) {
                let i = (d * 2 + j) % words.count
                let json = #"{"id":"bw\#(i)","headword":"\#(words[i].0)","meaning_ja":"\#(words[i].1)"}"#
                guard let word = try? JSONDecoder().decode(Word.self, from: Data(json.utf8)) else { continue }
                let path = "preview/book-\(d)-\(j).jpg"
                let img = UIGraphicsImageRenderer(size: CGSize(width: 600, height: j == 0 ? 760 : 520)).image { ctx in
                    let hue = CGFloat(i) / 5
                    UIColor(hue: hue, saturation: 0.4, brightness: 0.93, alpha: 1).setFill()
                    ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 760))
                    UIColor(hue: hue, saturation: 0.7, brightness: 0.72, alpha: 1).setFill()
                    ctx.cgContext.fillEllipse(in: CGRect(x: 150, y: 140, width: 300, height: 260))
                }
                ImageCache.shared.set(img, for: path)
                items.append(Sticker(id: "b\(d)\(j)", wordId: "w", objectImageUrl: path, cutoutImageUrl: nil, selfieImageUrl: nil,
                                     caption: j == 0 && d == 0 ? "駅前のカフェで" : nil, locationName: nil,
                                     takenAt: day.addingTimeInterval(Double(9 + j) * 3600), captureType: "photo", word: word))
            }
            out.append(BookDay(day: day, items: items))
        }
        return out
    }()

    var body: some View {
        VStack {
            MonthBookView(days: Self.days, startAtEnd: false, onOpen: { _ in }, onWrite: { _ in },
                          autoplay: frozenTurn == nil, frozenTurn: frozenTurn)
                .frame(height: 600)
                .padding(.horizontal, 12)
        }
        .frame(maxHeight: .infinity)
        .background(HomeBackground().ignoresSafeArea())
    }
}
/// The word page's chunk / measure-word / related-word cards (web WordCard look), scrolled to the chunks.
private struct DetailPreview: View {
    /// The same word as each display language's reader would get it (notes written in their language).
    private static var notes: (meaning: String, translation: String, chunks: [String], measure: String, related: [String]) {
        switch L10n.lang {
        case "en":
            return ("teppan noodles", "I want teppan noodles for breakfast.",
                    ["teppan noodles with mushroom sauce", "teppan noodles with black pepper sauce", "order teppan noodles"],
                    "one serving (the most common measure word for dishes)",
                    ["Ordinary stir-fried noodles. 鐵板麵 is served sizzling on an iron plate with sauce poured over.",
                     "Pasta. 鐵板麵 is cheaper — a light meal sold at breakfast shops."])
        case "zh-TW":
            return ("鐵板上淋醬的麵", "",
                    ["蘑菇醬的鐵板麵", "黑胡椒醬的鐵板麵", "點一份鐵板麵"],
                    "一盤的量（數餐點最常用的量詞）",
                    ["一般的炒麵。鐵板麵是放在熱鐵板上再淋醬。", "比義大利麵便宜，是早餐店的輕食。"])
        default:
            return ("鉄板焼きそば", "朝ごはんに鉄板焼きそばが食べたい。",
                    ["マッシュルームソースの鉄板焼きそば", "黒胡椒ソースの鉄板焼きそば", "鉄板焼きそばを注文する"],
                    "一皿分（料理を数える際の最も一般的な量詞）",
                    ["一般的な炒め麺。鐵板麵は鉄板の上でソースをかけて調理する点が異なる。",
                     "パスタ。鐵板麵はパスタより安価で、朝食店で提供される軽食という位置づけ。"])
        }
    }

    private static var sticker: Sticker {
        let n = notes
        let obj: [String: Any] = [
            "id": "w-teppan", "headword": "鐵板麵", "language": "zh-TW", "reading_zhuyin": "ㄊㄧㄝˇ ㄅㄢˇ ㄇㄧㄢˋ", "meaning_ja": n.meaning,
            "part_of_speech": "名詞", "example_sentence": "早餐我想吃鐵板麵。", "example_translation": n.translation,
            "extras": [
                "explain_lang": L10n.lang,
                "usage_chunks": [
                    ["parts": [["text": "蘑菇", "pos": "N"], ["text": "鐵板麵", "pos": "N"]], "ja": n.chunks[0]],
                    ["parts": [["text": "黑胡椒", "pos": "N"], ["text": "鐵板麵", "pos": "N"]], "ja": n.chunks[1]],
                    ["parts": [["text": "點", "pos": "V"], ["text": "鐵板麵", "pos": "N"]], "ja": n.chunks[2]],
                ],
                "measure_words": [["word": "份", "zhuyin": "ㄈㄣˋ", "note": n.measure]],
                "related_words": [
                    ["word": "炒麵", "kind": "syn", "reading": "ㄔㄠˇ ㄇㄧㄢˋ", "note": n.related[0]],
                    ["word": "義大利麵", "kind": "rel", "reading": "ㄧˋ ㄉㄚˋ ㄌㄧˋ ㄇㄧㄢˋ", "note": n.related[1]],
                ],
            ] as [String: Any],
        ]
        let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data()
        // Through the same reader-language filter as real cards.
        let word = (try? JSONDecoder().decode(Word.self, from: data))
            .map { ReaderLanguage.resolve($0, explanation: nil, readerMeaning: nil, reader: L10n.lang) }
        return Sticker(id: "detail", wordId: "w-teppan", objectImageUrl: nil, cutoutImageUrl: nil, selfieImageUrl: nil,
                       caption: nil, locationName: nil, takenAt: Date(), captureType: "photo", word: word)
    }

    var focus: CardSection = .usageChunks

    var body: some View {
        WordDetailView(sticker: Self.sticker, previewFocus: focus)
    }

    static var previewSticker: Sticker { sticker }
}

/// ネットの画像 with three stand-in pictures (no network in CI): the section shows once pictures arrive.
private struct WebImagesPreview: View {
    init() {
        CardPrefsStore.shared.use("zh-TW")
        CardPrefsStore.shared.setVisible(.webImages, true)
        let word = DetailPreview.previewSticker.word
        let looks: [(String, UInt32, UInt32, String)] = [
            ("fork.knife", 0xF4A261, 0xE76F51, "Mei Lin"), ("flame.fill", 0x2A9D8F, 0x264653, "Kenji Ito"),
            ("frying.pan.fill", 0xE9C46A, 0xF4A261, "Ana Ruiz"),
        ]
        let candidates: [WebImageCandidate] = looks.compactMap { symbol, top, bottom, name in
            let size = CGSize(width: 360, height: 360)
            let img = UIGraphicsImageRenderer(size: size).image { ctx in
                let colors = [UIColor(Color(hex: top)).cgColor, UIColor(Color(hex: bottom)).cgColor] as CFArray
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                    ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
                }
                let cfg = UIImage.SymbolConfiguration(pointSize: 120, weight: .semibold)
                if let sym = UIImage(systemName: symbol, withConfiguration: cfg)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                    sym.draw(at: CGPoint(x: (size.width - sym.size.width) / 2, y: (size.height - sym.size.height) / 2))
                }
            }
            guard let jpeg = img.jpegData(compressionQuality: 0.8) else { return nil }
            return WebImageCandidate(url: "data:image/jpeg;base64,\(jpeg.base64EncodedString())", thumb: nil, source: "unsplash",
                                     credit: .init(name: name, link: nil))
        }
        WebImages.seed(headword: word?.headword ?? "", meaning: word?.meaningJa, candidates: candidates)
    }

    var body: some View {
        DetailPreview(focus: .webImages)
    }
}
/// A Japanese word (傘) and an English word (umbrella) as an English / Chinese / Japanese reader sees them —
/// to check each language's own sections and that every note is in the reader's language.
private struct LanguageCardPreview: View {
    enum Kind { case ja, en }
    let kind: Kind

    private var sticker: Sticker {
        let zh = L10n.lang == "zh-TW"
        let obj: [String: Any]
        switch kind {
        case .ja:
            obj = [
                "id": "w-kasa", "headword": "傘", "reading_zhuyin": "かさ", "pinyin": "kasa", "language": "ja",
                "meaning_ja": zh ? "雨傘" : "umbrella", "part_of_speech": "名詞",
                "example_sentence": "雨が降ってきたので、傘をさしました。",
                "example_translation": zh ? "因為開始下雨了，所以撐了傘。" : "It started to rain, so I put up my umbrella.",
                "extras": [
                    "explain_lang": L10n.lang,
                    "usage_chunks": [
                        ["parts": [["text": "傘", "pos": "N"], ["text": "を", "pos": "P"], ["text": "さす", "pos": "V"]], "ja": zh ? "撐傘" : "put up an umbrella"],
                        ["parts": [["text": "傘", "pos": "N"], ["text": "を", "pos": "P"], ["text": "たたむ", "pos": "V"]], "ja": zh ? "把傘收起來" : "fold an umbrella"],
                    ],
                    "kanji_breakdown": [["kanji": "傘", "meaning": zh ? "傘" : "umbrella", "on": "サン", "kun": "かさ"]],
                    "counters": [["word": "一本", "reading": "いっぽん",
                                  "note": zh ? "細長的東西用「本」來數，傘也是。" : "Long, thin things — umbrellas too — are counted with 本."]],
                    "related_words": [["word": "日傘", "kind": "rel", "reading": "ひがさ", "note": zh ? "遮陽用的傘" : "a parasol for the sun"]],
                ] as [String: Any],
            ]
        case .en:
            obj = [
                "id": "w-umbrella", "headword": "umbrella", "language": "en",
                "meaning_ja": zh ? "雨傘" : "傘", "part_of_speech": "noun",
                "example_sentence": "Don't forget your umbrella — it's going to rain.",
                "example_translation": zh ? "別忘了帶傘，快要下雨了。" : "傘を忘れないで。雨が降りそうだよ。",
                "extras": [
                    "explain_lang": L10n.lang,
                    "usage_chunks": [
                        ["parts": [["text": "open", "pos": "V"], ["text": "an umbrella", "pos": "N"]], "ja": zh ? "打開傘" : "傘を開く"],
                        ["parts": [["text": "share", "pos": "V"], ["text": "an umbrella", "pos": "N"]], "ja": zh ? "一起撐一把傘" : "相合い傘をする"],
                    ],
                    "forms": ["plural": "umbrellas"],
                    "countability": ["kind": "countable", "article": "an",
                                     "note": zh ? "可數名詞，前面用 an（母音開頭）。" : "数えられる名詞。母音で始まるので an を付ける。"],
                    "stress": ["syllables": ["um", "brel", "la"], "primary": 1],
                ] as [String: Any],
            ]
        }
        let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data()
        let word = (try? JSONDecoder().decode(Word.self, from: data))
            .map { ReaderLanguage.resolve($0, explanation: nil, readerMeaning: nil, reader: L10n.lang) }
        return Sticker(id: "lang-\(kind)", wordId: kind == .ja ? "w-kasa" : "w-umbrella", objectImageUrl: nil, cutoutImageUrl: nil,
                       selfieImageUrl: nil, caption: nil, locationName: nil, takenAt: Date(), captureType: "photo", word: word)
    }

    var body: some View {
        WordDetailView(sticker: sticker, previewFocus: .usageChunks)
    }
}
/// The review 4-choice card and its answer panel, for a Mandarin, Japanese or English word — to check
/// the quiz prompt, the choices (learning language only) and the notes (display language only).
private struct ReviewPreview: View {
    let learning: String
    let answered: Bool

    private var card: ReviewCard {
        ImageCache.shared.set(PreviewFixtures.photo, for: "preview/review.jpg")
        let zh = L10n.lang == "zh-TW", en = L10n.lang == "en"
        let w: [String: Any]
        switch learning {
        case "ja":
            w = ["id": "rq", "headword": "傘", "reading_zhuyin": "かさ", "language": "ja",
                 "meaning_ja": zh ? "雨傘" : "umbrella", "example_sentence": "傘をさしました。",
                 "example_translation": zh ? "撐了傘。" : "I put up my umbrella."]
        case "en":
            w = ["id": "rq", "headword": "mango", "language": "en", "meaning_ja": zh ? "芒果" : "マンゴー",
                 "example_sentence": "This mango is really sweet.", "example_translation": zh ? "這顆芒果很甜。" : "このマンゴーはとても甘い。",
                 "extras": ["explain_lang": L10n.lang,
                            "usage_chunks": [["parts": [["text": "a ripe", "pos": "A"], ["text": "mango", "pos": "N"]], "ja": zh ? "熟透的芒果" : "熟したマンゴー"]]] as [String: Any]]
        default:
            w = ["id": "rq", "headword": "芒果", "reading_zhuyin": "ㄇㄤˊ ㄍㄨㄛˇ", "language": "zh-TW",
                 "meaning_ja": en ? "mango" : "マンゴー", "example_sentence": "這顆芒果很甜。",
                 "example_translation": en ? "This mango is very sweet." : "このマンゴーはとても甘い。",
                 "extras": ["explain_lang": L10n.lang,
                            "usage_chunks": [["parts": [["text": "芒果", "pos": "N"], ["text": "很", "pos": "ADV"], ["text": "甜", "pos": "VS"]], "ja": en ? "Mangoes are very sweet" : "マンゴーはとても甘い"],
                                             ["parts": [["text": "切", "pos": "V"], ["text": "芒果", "pos": "N"]], "ja": en ? "cut a mango" : "マンゴーを切る"]],
                            "measure_words": [["word": "顆", "zhuyin": "ㄎㄜ", "note": en ? "for round fruit" : "丸い果物に"]]] as [String: Any]]
        }
        let data = (try? JSONSerialization.data(withJSONObject: w)) ?? Data()
        let word = (try? JSONDecoder().decode(Word.self, from: data))
            .map { ReaderLanguage.resolve($0, explanation: nil, readerMeaning: nil, reader: L10n.lang) }
        let s = Sticker(id: "review", wordId: "rq", objectImageUrl: "preview/review.jpg", cutoutImageUrl: nil, selfieImageUrl: nil,
                        caption: nil, locationName: nil, takenAt: Date(), captureType: "photo", word: word)
        return ReviewCard(review: ReviewState(id: "r1", stickerId: "review", ease: 2.5, intervalDays: 1), sticker: s)
    }

    var body: some View {
        // The learning language first, so the choices and readings are drawn for it (DEBUG preview only).
        let _ = { NativeAPI.targetLanguage = learning }()
        let c = card
        let choices = [QuizChoice(headword: c.sticker.word?.headword ?? "", zhuyin: c.sticker.word?.readingZhuyin)]
            + ReviewStore.fallback(for: learning, categoryKey: c.sticker.categoryKey).filter { $0.headword != c.sticker.word?.headword }.prefix(3)
        ZStack(alignment: .bottom) {
            AppBackground()
            ScrollView {
                QuizCard(card: c, choices: choices, percent: 62, isAnswered: answered, onAnswer: { _, _ in }, onBadge: {})
                    .padding(.top, 40)
                    .uiReady("preview")
            }
            if answered {
                AnswerPanel(sticker: c.sticker, correct: true, onDex: {}, onNext: {})
            }
        }
    }
}
#endif

/// The end of a review round: score ring, missed words to try again, and "review more".
private struct DonePreview: View {
    var body: some View {
        ZStack {
            AppBackground()
            ReviewDone(total: 12, correct: 9, doneToday: 12, missed: 3, isRetry: false, canLoadMore: true) {}
                .padding(16)
        }
    }
}

/// Swappable chunk parts with the wheel open (docs/chunk-rules.md C5/C6): 跟＋男朋友＋吵架 and 芒果＋很＋甜.
private struct ChunkWheelPreview: View {
    private var reader: String { L10n.lang }

    private func gloss(_ ja: String, _ en: String, _ zh: String) -> String { reader == "en" ? en : reader == "zh-TW" ? zh : ja }

    private var quarrel: UsageChunk {
        let alts = [("女朋友", "彼女", "girlfriend", "女朋友"), ("朋友", "友達", "a friend", "朋友"), ("同事", "同僚", "a coworker", "同事"),
                    ("爸媽", "両親", "my parents", "爸媽"), ("室友", "ルームメイト", "a roommate", "室友")]  // l10n-ignore (preview data)
        return UsageChunk(parts: [
            ChunkPart(text: "跟", pos: "Prep"),  // l10n-ignore (target word)
            ChunkPart(text: "男朋友", pos: "N", slot: true, ja: gloss("彼氏", "my boyfriend", "男朋友"),  // l10n-ignore (preview data)
                      alts: alts.map { ChunkAlt(text: $0.0, ja: gloss($0.1, $0.2, $0.3)) }),
            ChunkPart(text: "吵架", pos: "V"),  // l10n-ignore (target word)
        ], ja: gloss("彼氏と喧嘩する", "argue with my boyfriend", "跟男朋友吵架"))  // l10n-ignore (preview data)
    }

    private var mango: UsageChunk {
        let raw = [ChunkPart(text: "芒果", pos: "N"), ChunkPart(text: "甜", pos: "Vs")]  // l10n-ignore (target word)
        return UsageChunk(parts: ChunkRules.tidy(raw, headword: "芒果", target: "zh-TW", reader: reader),  // l10n-ignore (target word)
                          ja: gloss("マンゴーはとても甘い", "Mangoes are very sweet", "芒果很甜"))  // l10n-ignore (preview data)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ChunkLineView(chunk: quarrel, headword: "吵架", target: "zh-TW", startOpen: 1)  // l10n-ignore (target word)
                Divider()
                ChunkLineView(chunk: mango, headword: "芒果", target: "zh-TW", startOpen: 1)  // l10n-ignore (target word)
            }
            .padding(20)
            .background(.white, in: .rect(cornerRadius: 24))
            .padding(16)
        }
        .background(Theme.background)
    }
}
