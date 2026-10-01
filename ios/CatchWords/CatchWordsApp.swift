import SwiftUI

@main
struct CatchWordsApp: App {
    @State private var auth = AuthStore()
    @State private var dex = DexStore()
    @State private var plan = PlanStore()
    @State private var profile = ProfileStore()
    @State private var diary = DiaryStore()
    @AppStorage("motion.pref") private var motionPref: String = "full"
    @AppStorage("theme.pref") private var themePref: String = "light"

    /// ライト / ダーク / システム (web settings theme).
    private var scheme: ColorScheme? {
        switch themePref {
        case "dark": .dark
        case "system": nil
        default: .light
        }
    }

    init() {
        // Settings values renamed to the web's: sound "soft" → "subtle".
        if UserDefaults.standard.string(forKey: "sound.level") == "soft" {
            UserDefaults.standard.set("subtle", forKey: "sound.level")
        }
        AppFont.registerAll()
        SoundService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let preview = UIPreview.requested {
                // "<scene>-dark" photographs the same scene in the dark appearance.
                UIPreviewRoot(name: preview.hasSuffix("-dark") ? String(preview.dropLast(5)) : preview)
                    .environment(dex)
                    .environment(diary)
                    .environment(auth)
                    .environment(plan)
                    .environment(profile)
                    .preferredColorScheme(preview.hasSuffix("-dark") ? .dark : .light)
            } else {
                app
            }
            #else
            app
            #endif
        }
    }

    private var app: some View {
            RootView()
                .environment(auth)
                .environment(dex)
                .environment(plan)
                .environment(profile)
                .environment(diary)
                .preferredColorScheme(scheme)
                .tint(Theme.primary)
                .transaction { t in if motionPref == "reduce" { t.disablesAnimations = true } }
    }
}
