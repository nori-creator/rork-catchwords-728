import SwiftUI

/// The first screen before signing in: the web app's welcome screen (`FirstCatchIntro`,
/// catchwords.lovable.app/welcome) drawn natively.
///
/// A bright sky (drifting clouds, a blurred sea, glints) behind the app icon, 「CatchWords」 and the tagline
/// 「日常のすべてが学びになる」; a hand holding up the sea photo (its word handwritten below, 「海邊」 /
/// "seaside") with four blurred photos around it; then 「はじめる」 and 「アカウントをお持ちの方はこちらから ログイン」.
/// The photo layout is the web's "stage" in its own units (612 × 770), scaled to fit the space left.
///
/// Motion as on the web: the clouds drift, the photos around float in and bob, the held photo rises and
/// sways, a shine crosses it once and small stars twinkle twice. With reduced motion only the still picture.
struct WelcomeView: View {
    let onStart: () -> Void
    let onSignIn: () -> Void

    @Environment(\.appReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false

    /// The words under the photos are in the learning language: English for English learners, otherwise
    /// Taiwanese Mandarin (web `FirstCatchIntro`).
    private var english: Bool { NativeAPI.targetLanguage == "en" }

    var body: some View {
        GeometryReader { geo in
            let logo = min(max(60, geo.size.height * 0.115), 104)
            let titleSize = min(max(30, min(geo.size.width * 0.086, geo.size.height * 0.046)), 40)
            VStack(spacing: 0) {
                header(logo: logo, titleSize: titleSize)
                WelcomeStage(english: english, appeared: appeared, animate: !reduceMotion)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 8)
                    .padding(.horizontal, -24)
                footer
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background {
            WelcomeSky(animate: !reduceMotion)
                .ignoresSafeArea()
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.7)) { appeared = true }
            }
        }
    }

    private func header(logo: CGFloat, titleSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            WelcomeLogo(size: logo)
                .padding(.bottom, 10)
            Text(verbatim: "CatchWords")
                .font(.system(size: titleSize, weight: .heavy))
                .tracking(-0.03 * titleSize)
                .foregroundStyle(Theme.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(L("日常のすべてが学びになる"))
                .tracking(0.3)
                .scaledFont(size: 15, weight: .semibold)
                .foregroundStyle(Theme.foreground.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(.top, 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Button(action: onStart) {
                HStack(spacing: 8) {
                    Text(L("はじめる"))
                    Image(systemName: "arrow.right")
                        .accessibilityHidden(true)
                }
                .scaledFont(size: 17, weight: .semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Theme.primary, in: .capsule)
                .shadow(color: Theme.primary.opacity(0.14), radius: 15, y: 5)
                .padding(4)
                // The web button's ring (`tour-pulse`).
                .overlay(Capsule().stroke(Theme.primary.opacity(0.85), lineWidth: 2))
            }
            .buttonStyle(PressableStyle(scale: 0.985))
            .accessibilityIdentifier("welcome.start")

            // Registered people go straight to signing in.
            Button(action: onSignIn) {
                HStack(spacing: 6) {
                    Text(L("アカウントをお持ちの方はこちらから"))
                        .foregroundStyle(Theme.muted)
                    Text(L("ログイン"))
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.primaryInk)
                }
                .scaledFont(size: 14)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(PressableStyle(scale: 0.97))
            .accessibilityIdentifier("welcome.signin")
        }
    }
}

/// The app icon itself (the web shows `icon-192.png`); the native mark if the picture is missing.
struct WelcomeLogo: View {
    let size: CGFloat

    var body: some View {
        if let img = WelcomeImage.load("welcome_logo", type: "png") {
            Image(uiImage: img)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(.rect(cornerRadius: size * 0.22, style: .continuous))
                .shadow(color: Theme.primary.opacity(0.45), radius: 12, y: 10)
                .accessibilityHidden(true)
        } else {
            LogoMark(size: size)
                .accessibilityHidden(true)
        }
    }
}

/// Pictures of the welcome screen (bundled next to the onboarding photos).
enum WelcomeImage {
    private static var cache: [String: UIImage] = [:]

    static func load(_ name: String, type: String = "webp") -> UIImage? {
        let key = name + "." + type
        if let c = cache[key] { return c }
        guard let path = Bundle.main.path(forResource: name, ofType: type),
              let img = UIImage(contentsOfFile: path) else { return nil }
        cache[key] = img
        return img
    }
}

// MARK: - Sky

/// The summer-noon sky (web `.first-sky`): blue at the top fading to the page colour, light from the top
/// right, a blurred sea and its glints, and clouds drifting slowly. A dawn sky in the dark theme.
private struct WelcomeSky: View {
    let animate: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var drift: Bool = false

    private static let deep = Color(light: 0x89CAF6, dark: 0x023569)
    private static let mid = Color(light: 0xB5DEF9, dark: 0x022449)
    private static let pale = Color(light: 0xDCEFFC, dark: 0x03152C)
    private static let sun = Color(light: 0xFFFDF2, dark: 0x262C36)
    private static let cloudWhite = Color(light: 0xFFFFFF, dark: 0x545962)
    private static let cloudShade = Color(light: 0xCCE6FF, dark: 0x022D57)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let vmin = min(w, h)
            // Cloud widths (web: 78 / 58 / 50 / 46 vmin, at most 440 / 400 pt).
            let c1: CGFloat = min(vmin * 0.78, 440)
            let c2: CGFloat = min(vmin * 0.58, 400)
            let c3: CGFloat = min(vmin * 0.50, 400)
            let c4: CGFloat = min(vmin * 0.46, 400)
            let dark = colorScheme == .dark
            ZStack(alignment: .topLeading) {
                LinearGradient(stops: [
                    .init(color: Self.deep, location: 0),
                    .init(color: Self.mid, location: 0.30),
                    .init(color: Self.pale, location: 0.52),
                    .init(color: Self.pale, location: 0.62),
                    .init(color: Theme.background, location: 1),
                ], startPoint: .top, endPoint: .bottom)

                sea(width: w, height: h, dark: dark)

                ForEach(0..<Self.glints.count, id: \.self) { i in
                    let g = Self.glints[i]
                    Circle()
                        .fill(RadialGradient(colors: [Theme.card, Theme.card.opacity(0.6), Theme.card.opacity(0)],
                                             center: .center, startRadius: 0, endRadius: g.size * 0.7))
                        .frame(width: g.size, height: g.size)
                        .opacity(dark ? 0.35 : 0.85)
                        .offset(x: w * g.x, y: h * g.y)
                }

                cloud(width: c1, x: w * 1.24 - c1, y: h * 0.07, opacity: 1, dark: dark, reverse: false)
                cloud(width: c2, x: -w * 0.30, y: h * 0.20, opacity: 1, dark: dark, reverse: true)
                cloud(width: c3, x: -w * 0.34, y: h * 0.36, opacity: 0.8, dark: dark, reverse: false)
                cloud(width: c4, x: w * 1.30 - c4, y: h * 0.30, opacity: 0.75, dark: dark, reverse: true)

                // Sunlight from the top right, and a bright haze around the photos.
                Rectangle()
                    .fill(EllipticalGradient(colors: [Self.sun, Self.sun.opacity(0)], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.35))
                    .frame(width: w * 0.92, height: h * 0.52)
                    .offset(x: w * 0.50, y: -h * 0.30)
                Rectangle()
                    .fill(EllipticalGradient(colors: [Self.sun.opacity(0.7), Self.sun.opacity(0)], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.36))
                    .frame(width: w * 1.24, height: h * 0.60)
                    .offset(x: -w * 0.12, y: h * 0.20)

                // White air around 「はじめる」.
                LinearGradient(stops: [
                    .init(color: Theme.background.opacity(0), location: 0.74),
                    .init(color: Theme.background.opacity(0.82), location: 0.88),
                    .init(color: Theme.background, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
            .frame(width: w, height: h, alignment: .topLeading)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard animate else { return }
            withAnimation(.easeInOut(duration: 46).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    /// Glints on the water: position as a fraction of the screen, size in points.
    private static let glints: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.12, 0.70, 14), (0.64, 0.64, 10), (0.84, 0.76, 18), (0.36, 0.80, 9), (0.06, 0.60, 11),
    ]

    @ViewBuilder
    private func sea(width w: CGFloat, height h: CGFloat, dark: Bool) -> some View {
        if let img = WelcomeImage.load("first_catch_welcome_sea") {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: w * 1.08, height: h * 0.46)
                .clipped()
                .mask {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.22),
                        .init(color: .black, location: 0.70),
                        .init(color: .clear, location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                }
                .opacity(dark ? 0.2 : 0.9)
                .offset(x: -w * 0.04, y: h * 0.46)
        }
    }

    private func cloud(width: CGFloat, x: CGFloat, y: CGFloat, opacity: Double, dark: Bool, reverse: Bool) -> some View {
        let shift: CGFloat = drift ? 26 : -14
        return WelcomeCloud(color: Self.cloudWhite, shade: Self.cloudShade)
            .frame(width: width, height: width / 2.2)
            .opacity(opacity * (dark ? 0.4 : 1))
            .offset(x: x + (reverse ? -shift : shift), y: y + (drift ? -4 : 0))
    }
}

/// A cloud: a sunlit white top over a slightly shaded underside, soft at the edges (web `.first-sky-cloud`).
private struct WelcomeCloud: View {
    let color: Color
    let shade: Color

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack {
                WelcomePuffs(color: shade)
                    .offset(y: h * 0.08)
                    .blur(radius: 3)
                WelcomePuffs(color: color)
                    .scaleEffect(x: 0.96, y: 0.88)
                    .offset(y: -h * 0.04)
            }
            .frame(width: geo.size.width, height: h)
        }
        .blur(radius: 2)
    }
}

/// The cloud's round puffs and flat-ish bottom (the web's six radial gradients).
private struct WelcomePuffs: View {
    let color: Color

    /// background-position (x, y) and background-size (w, h), as fractions of the cloud's box.
    private static let puffs: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = [
        (0.10, 0.72, 0.32, 0.46), (0.28, 0.46, 0.38, 0.70), (0.50, 0.26, 0.44, 0.92),
        (0.71, 0.40, 0.38, 0.74), (0.89, 0.66, 0.28, 0.48), (0.50, 0.80, 0.92, 0.40),
    ]

    var body: some View {
        Canvas { context, size in
            for p in Self.puffs {
                let boxW = size.width * p.w
                let boxH = size.height * p.h
                let left = (size.width - boxW) * p.x
                let top = (size.height - boxH) * p.y
                let rect = CGRect(x: left + boxW * 0.09, y: top + boxH * 0.09, width: boxW * 0.82, height: boxH * 0.82)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
}

// MARK: - The photos

/// The web's photo "stage" (owner's sample A, in its own units 612 × 770): four blurred photos around the
/// sea photo held up by a hand. Scaled to fit both the width and the height and centred; the photos around
/// move outwards when the box is wider than the stage.
private struct WelcomeStage: View {
    let english: Bool
    let appeared: Bool
    let animate: Bool

    @State private var bob: Bool = false
    @State private var sway: Bool = false
    @State private var shine: CGFloat = -1

    private struct Around {
        let photo: String
        let ratio: CGFloat
        let en: String
        let zh: String
        let x: CGFloat
        let y: CGFloat
        let w: CGFloat
        let r: Double
        let side: CGFloat
    }

    // The words are learning-language samples, never translated.
    private static let around: [Around] = [
        Around(photo: "first_catch_welcome_blur_flower", ratio: 1, en: "flower", zh: "花", x: -30, y: -6, w: 172, r: -9, side: -1),  // l10n-ignore (target words)
        Around(photo: "first_catch_welcome_blur_cat", ratio: 1, en: "cat", zh: "貓", x: 456, y: 28, w: 176, r: 9, side: 1),  // l10n-ignore (target words)
        Around(photo: "first_catch_welcome_blur_coffee", ratio: 1.5, en: "coffee", zh: "咖啡", x: -36, y: 262, w: 150, r: -6, side: -1),  // l10n-ignore (target words)
        Around(photo: "first_catch_welcome_blur_lake", ratio: 1, en: "lake", zh: "湖", x: 400, y: 430, w: 220, r: 8, side: 1),  // l10n-ignore (target words)
    ]

    var body: some View {
        GeometryReader { geo in
            let m = min(geo.size.width / 612, geo.size.height / 770)
            let ox = (geo.size.width - 612 * m) / 2
            let oy = (geo.size.height - 770 * m) / 2
            ZStack(alignment: .topLeading) {
                ForEach(0..<Self.around.count, id: \.self) { i in
                    aroundPrint(Self.around[i], index: i, m: m, ox: ox, oy: oy)
                }
                held(m: m, ox: ox, oy: oy)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .frame(minHeight: 210)
        .accessibilityHidden(true)
        .onAppear {
            guard animate else { return }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { bob = true }
            withAnimation(.easeInOut(duration: 6.5).delay(1.3).repeatForever(autoreverses: true)) { sway = true }
            withAnimation(.easeInOut(duration: 1.2).delay(1.15)) { shine = 1 }
        }
    }

    private func motion(_ animation: Animation) -> Animation? {
        animate ? animation : nil
    }

    private func aroundPrint(_ a: Around, index: Int, m: CGFloat, ox: CGFloat, oy: CGFloat) -> some View {
        let width = a.w * m
        let height = width * (0.26 + 0.88 * a.ratio)
        let left = ox + a.x * m + a.side * ox * 0.5
        let top = oy + a.y * m
        let bobDepth: CGFloat = index % 2 == 0 ? 8 : 5.6
        let bobShift: CGFloat = bob ? -bobDepth * m : 0
        let x: CGFloat = appeared ? left : left + a.side * m * 60
        let y: CGFloat = appeared ? top : top + m * 40
        return WelcomePaper(photo: a.photo, ratio: a.ratio, word: english ? a.en : a.zh, english: english,
                            width: width, m: m, main: false, shinePhase: nil)
            .frame(width: width, height: height)
            .offset(y: bobShift)
            .rotationEffect(.degrees(appeared ? a.r : -a.r))
            .scaleEffect(appeared ? 1 : 0.82)
            .opacity(appeared ? 0.9 : 0)
            .offset(x: x, y: y)
            .animation(motion(.timingCurve(0.22, 1, 0.36, 1, duration: 1).delay(0.12 + 0.1 * Double(index))), value: appeared)
    }

    private func held(m: CGFloat, ox: CGFloat, oy: CGFloat) -> some View {
        let w = 375.5 * m
        let h = 439.5 * m
        let swayAngle: Double = animate ? (sway ? 1.1 : -0.8) : 0
        let handW = 269 * m
        let swayLift: CGFloat = animate && sway ? -7 * m : 0
        let x: CGFloat = appeared ? ox + 114.75 * m : ox + 84.75 * m
        let y: CGFloat = appeared ? oy + 85.25 * m : oy + 225.25 * m
        return ZStack(alignment: .topLeading) {
            WelcomePaper(photo: "first_catch_ready", ratio: 1, word: english ? "seaside" : "海邊", english: english,  // l10n-ignore (target word)
                         width: w, m: m, main: true, shinePhase: animate ? shine : nil)
                .frame(width: w, height: h)
                .rotationEffect(.degrees(-13.55))
            if let hand = WelcomeImage.load("first_catch_hand") {
                Image(uiImage: hand)
                    .resizable()
                    .frame(width: handW, height: handW * hand.size.height / max(hand.size.width, 1))
                    .offset(x: -113.75 * m, y: 387.75 * m)
            }
            ForEach(0..<Self.sparks.count, id: \.self) { i in
                let s = Self.sparks[i]
                WelcomeSpark(size: s.size * m, delay: s.delay, animate: animate)
                    .offset(x: w * s.x, y: h * s.y)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .rotationEffect(.degrees(swayAngle), anchor: UnitPoint(x: 0.08, y: 1.2))
        .offset(y: swayLift)
        .rotationEffect(.degrees(appeared ? 0 : 7))
        .opacity(appeared ? 1 : 0)
        .offset(x: x, y: y)
        .animation(motion(.timingCurve(0.22, 1, 0.36, 1, duration: 1.1).delay(0.2)), value: appeared)
    }

    /// Stars around the held photo: position as a fraction of its box, size in stage units, start delay.
    private static let sparks: [(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double)] = [
        (0.92, -0.10, 30, 1.2), (-0.06, 0.04, 20, 1.45), (1.04, 0.46, 22, 1.7), (0.60, -0.16, 16, 1.9), (0.84, 0.98, 18, 1.55),
    ]
}

/// A print: white paper, the photo, and one word handwritten in the margin below (navy pen ink).
/// The photos around are blurred (their pictures are pre-blurred, the word is blurred here).
private struct WelcomePaper: View {
    let photo: String
    let ratio: CGFloat
    let word: String
    let english: Bool
    let width: CGFloat
    let m: CGFloat
    let main: Bool
    /// The shine crossing the held photo once (-1 → 1); nil for none.
    let shinePhase: CGFloat?

    private static let ink = Color(hex: 0x1E2A40)

    var body: some View {
        let pad = width * (main ? 0.032 : 0.06)
        let photoW = width - pad * 2
        let fontSize = main ? 50 * m : width * 0.1
        VStack(spacing: 0) {
            Color(hex: 0xEEE8DC)
                .overlay {
                    if let img = WelcomeImage.load(photo) {
                        Image(uiImage: img).resizable().scaledToFill()
                    }
                }
                .overlay {
                    if let shinePhase {
                        LinearGradient(stops: [
                            .init(color: .white.opacity(0), location: 0.38),
                            .init(color: .white.opacity(0.55), location: 0.5),
                            .init(color: .white.opacity(0), location: 0.62),
                        ], startPoint: .leading, endPoint: .trailing)
                            .frame(width: photoW * 2.2, height: photoW * 1.2)
                            .rotationEffect(.degrees(15))
                            .offset(x: shinePhase * photoW * 2.2)
                    }
                }
                .frame(width: photoW, height: photoW * ratio)
                .clipShape(.rect(cornerRadius: 4 * m))
            caption(fontSize: fontSize)
                .frame(width: photoW, height: width * 0.2)
        }
        .padding(.horizontal, pad)
        .padding(.top, pad)
        .background(Color(hex: 0xFEFDF9), in: .rect(cornerRadius: 8 * m))
        .shadow(color: .black.opacity(0.14), radius: 1, y: 1)
        .shadow(color: .black.opacity(main ? 0.26 : 0.2), radius: (main ? 30 : 20) * m, y: (main ? 30 : 18) * m)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func caption(fontSize: CGFloat) -> some View {
        let text = Text(verbatim: word)
            .font(english ? AppFont.caveat(fontSize) : AppFont.welcomePen(fontSize))
            .tracking(fontSize * 0.1)
        if main {
            text
                .foregroundStyle(Self.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .rotationEffect(.degrees(-3))
        } else {
            text
                .foregroundStyle(Self.ink.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .rotationEffect(.degrees(-3))
                .blur(radius: 1.5 * m)
        }
    }
}

/// A small four-pointed star that twinkles twice when the held photo arrives.
private struct WelcomeSpark: View {
    let size: CGFloat
    let delay: Double
    let animate: Bool

    @State private var lit: Bool = false
    @State private var turn: Double = 0

    var body: some View {
        WelcomeStar()
            .fill(Color(light: 0xF2F8FF, dark: 0xCFE5FF))
            .frame(width: size, height: size)
            .shadow(color: .white.opacity(0.8), radius: size * 0.2)
            .scaleEffect(lit ? 1 : 0.25)
            .rotationEffect(.degrees(turn))
            .opacity(lit ? 1 : 0)
            .task {
                guard animate else { return }
                try? await Task.sleep(for: .seconds(delay))
                for _ in 0..<2 {
                    withAnimation(.easeOut(duration: 0.58)) {
                        lit = true
                        turn += 45
                    }
                    try? await Task.sleep(for: .milliseconds(580))
                    withAnimation(.easeIn(duration: 0.72)) {
                        lit = false
                        turn += 45
                    }
                    try? await Task.sleep(for: .milliseconds(720))
                }
            }
    }
}

/// The web spark's clip-path: polygon(50% 0, 61% 39%, 100% 50%, 61% 61%, 50% 100%, 39% 61%, 0 50%, 39% 39%).
private struct WelcomeStar: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [(CGFloat, CGFloat)] = [
            (0.5, 0), (0.61, 0.39), (1, 0.5), (0.61, 0.61), (0.5, 1), (0.39, 0.61), (0, 0.5), (0.39, 0.39),
        ]
        var path = Path()
        for (i, p) in points.enumerated() {
            let pt = CGPoint(x: rect.minX + rect.width * p.0, y: rect.minY + rect.height * p.1)
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        return path
    }
}
