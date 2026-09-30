import SwiftUI

@main
struct CatchWordsApp: App {
    @State private var auth = AuthStore()
    @State private var dex = DexStore()
    @State private var plan = PlanStore()
    @State private var profile = ProfileStore()
    @AppStorage("motion.pref") private var motionPref: String = "system"

    init() {
        AppFont.registerAll()
        SoundService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(dex)
                .environment(plan)
                .environment(profile)
                .preferredColorScheme(.light)
                .tint(Theme.primary)
                .transaction { t in if motionPref == "reduce" { t.disablesAnimations = true } }
        }
    }
}
