import SwiftUI

@main
struct CatchWordsApp: App {
    @State private var auth = AuthStore()
    @State private var dex = DexStore()
    @State private var plan = PlanStore()

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
                .preferredColorScheme(.light)
                .tint(Theme.primary)
        }
    }
}
