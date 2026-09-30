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
            case "analyzing": AnalyzingView(photo: PreviewFixtures.photo) {}
            case "album": AlbumPreview()
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
        let rect = CGRect(x: 240, y: 240, width: 420, height: 400)
        guard let cg = subject.cgImage?.cropping(to: rect) else { return subject }
        return UIImage(cgImage: cg)
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
#endif
