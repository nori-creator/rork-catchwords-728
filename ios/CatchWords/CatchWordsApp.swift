import SwiftUI

@main
struct CatchWordsApp: App {
    @State private var auth = AuthStore()
    @State private var dex = DexStore()
    @State private var plan = PlanStore()
    @State private var profile = ProfileStore()

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
        }
    }
}
