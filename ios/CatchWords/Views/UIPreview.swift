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

#if DEBUG
struct UIPreviewRoot: View {
    let name: String
    @State private var router = AppRouter()

    var body: some View {
        Group {
            switch name {
            case "3d": Preview3DView()
            case "cutout": CutoutPreview()
            case "picker": PickerPreview()
            case "tabbar": TabBarPreview()
            case "reward": RewardPreview()
            case "analyzing":
                AnalyzingView(photo: PreviewFixtures.photo,
                              previewTargets: [CGRect(x: 0.27, y: 0.27, width: 0.46, height: 0.45),
                                               CGRect(x: 0.45, y: 0.27, width: 0.16, height: 0.12)]) {}
            case "album": AlbumPreview()
            case "hero": HeroPickerPreview()
            case "journal": JournalPreview()
            case "memorial": MemorialPreview()
            case "book": BookPreview()
            case "bookturn": BookPreview(frozenTurn: 0.38)
            case "detail": DetailPreview()
            case "settings": SettingsView()
            default: Text("unknown preview: \(name)")
            }
        }
        .environment(router)
    }
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
    @State private var vm: CaptureViewModel = {
        let vm = CaptureViewModel()
        vm.photo = PreviewFixtures.photo
        func c(_ h: String, _ z: String, _ m: String, _ d: String = "", _ r: String? = nil, _ g: Int) -> Candidate {
            Candidate(kind: "object", headword: h, zhuyin: z, pinyin: "", meaningJa: m, pos: "名詞",
                      point: [500, 500], confidence: 0.9, alternatives: [], distinction: d, register: r, group: g)
        }
        vm.candidates = [
            c("芒果", "ㄇㄤˊ ㄍㄨㄛˇ", "マンゴー", "ふだんの言い方", "common", 0),
            c("愛文芒果", "ㄞˋ ㄨㄣˊ ㄇㄤˊ ㄍㄨㄛˇ", "アーウィンマンゴー", "品種の名前", "specific", 0),
            c("檨仔", "ㄙㄨㄟˋ ㄚˇ", "マンゴー（台湾語由来）", "年配の人の言い方", "casual", 0),
            c("盤子", "ㄆㄢˊ ㄗ˙", "お皿", "", nil, 1),
        ]
        vm.step = .select
        return vm
    }()

    var body: some View { CandidatePickerView(vm: vm) }
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

/// Today's album page (web collage layout) with four made-up catches whose photos sit in the image cache.
private struct AlbumPreview: View {
    private static let words = [("芒果", "マンゴー"), ("盤子", "お皿"), ("咖啡", "コーヒー"), ("雨傘", "傘")]

    private static let stickers: [Sticker] = words.enumerated().compactMap { i, w in
        let json = #"{"id":"w\#(i)","headword":"\#(w.0)","meaning_ja":"\#(w.1)"}"#
        guard let word = try? JSONDecoder().decode(Word.self, from: Data(json.utf8)) else { return nil }
        let path = "preview/\(i).jpg"
        let img = UIGraphicsImageRenderer(size: CGSize(width: 600, height: i % 2 == 0 ? 760 : 480)).image { ctx in
            let hues: [CGFloat] = [0.12, 0.55, 0.08, 0.62]
            UIColor(hue: hues[i], saturation: 0.45, brightness: 0.92, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 760))
            UIColor(hue: hues[i], saturation: 0.7, brightness: 0.7, alpha: 1).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 150, y: 150, width: 300, height: 260))
        }
        ImageCache.shared.set(img, for: path)
        return Sticker(id: "s\(i)", wordId: "w\(i)", objectImageUrl: path, cutoutImageUrl: nil, selfieImageUrl: nil,
                       caption: i == 2 ? "駅前のカフェで" : nil, locationName: nil,
                       takenAt: Date().addingTimeInterval(Double(-i) * 1800), captureType: "photo", word: word)
    }

    var body: some View {
        ScrollView {
            AlbumPage(items: Self.stickers, isToday: true, onOpen: { _ in }, onCamera: {})
                .padding(16)
                .padding(.top, 50)
        }
        .background(AppBackground())
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
            "id": "w-teppan", "headword": "鐵板麵", "reading_zhuyin": "ㄊㄧㄝˇ ㄅㄢˇ ㄇㄧㄢˋ", "meaning_ja": n.meaning,
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

    var body: some View {
        WordDetailView(sticker: Self.sticker, previewFocus: .usageChunks)
    }
}
#endif
