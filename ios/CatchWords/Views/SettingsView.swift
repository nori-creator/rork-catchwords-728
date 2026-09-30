import SwiftUI

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(PlanStore.self) private var plan
    @Environment(AppRouter.self) private var router

    @AppStorage("photos.sync") private var photoSync: Bool = true
    @AppStorage("haptics.enabled") private var haptics: Bool = true
    @AppStorage("sound.level") private var soundLevel: String = "full"
    @State private var confirmSignOut: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { router.showPaywall = !plan.isPro } label: {
                        HStack(spacing: 14) {
                            Image(systemName: plan.isPro ? "crown.fill" : "sparkles")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(plan.isPro ? AnyShapeStyle(Theme.gold) : AnyShapeStyle(Theme.brandGradient), in: .rect(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.isPro ? "CatchWords Pro" : "Proにアップグレード")
                                    .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.foreground)
                                Text(plan.isPro ? "撮影は無制限です" : "今日あと\(plan.remainingToday)回 · 無制限にする")
                                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            if !plan.isPro { Image(systemName: "chevron.right").foregroundStyle(Theme.muted) }
                        }
                    }
                }

                Section("撮影") {
                    Toggle("スマホの写真アプリと同期", isOn: $photoSync)
                }

                Section("音と触感") {
                    Picker("効果音", selection: $soundLevel) {
                        Text("オフ").tag("off")
                        Text("控えめ").tag("soft")
                        Text("しっかり").tag("full")
                    }
                    Toggle("触覚フィードバック", isOn: $haptics)
                    Button("音を試す") {
                        SoundService.shared.play(.impact)
                        Haptics.impact(.heavy)
                    }
                }

                Section("アカウント") {
                    if let email = auth.email {
                        LabeledContent("ログイン中", value: email)
                    }
                    Button("購入を復元") { Task { await plan.restore() } }
                    if let msg = plan.message { Text(msg).font(.footnote).foregroundStyle(Theme.muted) }
                    Link("Web版を開く", destination: URL(string: "https://catchwords.lovable.app")!)
                    Button("ログアウト", role: .destructive) { confirmSignOut = true }
                }

                Section {
                    Link("利用規約", destination: URL(string: "https://catchwords.lovable.app/terms")!)
                    Link("プライバシーポリシー", destination: URL(string: "https://catchwords.lovable.app/privacy")!)
                } footer: {
                    Text("CatchWords for iPhone 1.0").frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 90)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("設定")
            .confirmationDialog("ログアウトしますか？", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("ログアウト", role: .destructive) { auth.signOut() }
            }
        }
    }
}
