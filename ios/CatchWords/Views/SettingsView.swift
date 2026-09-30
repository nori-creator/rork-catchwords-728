import SwiftUI
import PhotosUI

/// settings.tsx: grouped white cards on the light background (プロフィール / 言語 / 撮影 / 音と触感 / アカウント).
struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(PlanStore.self) private var plan
    @Environment(ProfileStore.self) private var profile
    @Environment(AppRouter.self) private var router

    @AppStorage("photos.sync") private var photoSync: Bool = true
    @AppStorage("haptics.enabled") private var haptics: Bool = true
    @AppStorage("sound.level") private var soundLevel: String = "full"
    @AppStorage("reading.pref") private var readingPref: String = "zhuyin"
    @State private var confirmSignOut: Bool = false
    @State private var avatarItem: PhotosPickerItem?
    @State private var nameDraft: String = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        @Bindable var profile = profile
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                proCard.padding(.bottom, 16)

                sectionTitle("プロフィール")
                card {
                    VStack(alignment: .leading, spacing: 12) {
                        fieldLabel("プロフィール写真")
                        HStack(spacing: 14) {
                            AvatarView(url: profile.avatarURL, size: 60)
                                .overlay { if profile.isSavingAvatar { ProgressView() } }
                            PhotosPicker(selection: $avatarItem, matching: .images) {
                                Text(profile.avatarURL == nil ? "選ぶ" : "変更")
                                    .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.foreground)
                                    .padding(.horizontal, 20).frame(minHeight: 46)
                                    .background(Color(hex: 0xF3F7FC), in: Capsule())
                                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                            }
                            if profile.avatarURL != nil {
                                Button("外す") { Task { await profile.clearAvatar() } }
                                    .font(.system(size: 16)).foregroundStyle(Theme.muted)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                        }
                        fieldLabel("表示名").padding(.top, 6)
                        TextField("名前", text: $nameDraft)
                            .font(.system(size: 17))
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .padding(.horizontal, 16).frame(minHeight: 50)
                            .background(.white, in: .rect(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                            .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
                            .onSubmit(saveName)
                            .onChange(of: nameFocused) { _, f in if !f { saveName() } }
                    }
                }

                sectionTitle("言語").padding(.top, 20)
                card {
                    VStack(alignment: .leading, spacing: 10) {
                        fieldLabel("母語")
                        menuRow(value: profile.nativeLanguage, options: ProfileStore.nativeOptions) { v in
                            profile.nativeLanguage = v
                            Task { await profile.update(["native_language": v]) }
                        }
                        fieldLabel("学習言語").padding(.top, 6)
                        menuRow(value: profile.targetLanguage, options: [("zh-TW", "繁體字（台灣）")]) { _ in }
                        fieldLabel("今のレベル").padding(.top, 6)
                        menuRow(value: profile.currentLevel, options: ProfileStore.levelOptions) { v in
                            profile.currentLevel = v
                            Task { await profile.update(["current_level": v]) }
                        }
                        fieldLabel("目標レベル").padding(.top, 6)
                        menuRow(value: profile.levelGoal, options: ProfileStore.levelOptions) { v in
                            profile.levelGoal = v
                            Task { await profile.update(["level_goal": v]) }
                        }
                        fieldLabel("発音表記").padding(.top, 6)
                        Picker("発音表記", selection: $readingPref) {
                            Text("注音").tag("zhuyin")
                            Text("拼音").tag("pinyin")
                        }
                        .pickerStyle(.segmented)
                        .frame(minHeight: 40)
                        if let m = profile.message {
                            Text(m).font(.footnote).foregroundStyle(Theme.destructive)
                        }
                    }
                }

                sectionTitle("撮影").padding(.top, 20)
                card {
                    Toggle("スマホの写真アプリと同期", isOn: $photoSync).font(.system(size: 16)).frame(minHeight: 44)
                }

                sectionTitle("音と触感").padding(.top, 20)
                card {
                    VStack(alignment: .leading, spacing: 12) {
                        fieldLabel("効果音")
                        Picker("効果音", selection: $soundLevel) {
                            Text("オフ").tag("off")
                            Text("控えめ").tag("soft")
                            Text("しっかり").tag("full")
                        }
                        .pickerStyle(.segmented)
                        Toggle("触覚フィードバック", isOn: $haptics).font(.system(size: 16)).frame(minHeight: 44)
                        Button("音を試す") {
                            SoundService.shared.play(.impact)
                            Haptics.impact(.heavy)
                        }
                        .font(.system(size: 16, weight: .medium)).frame(minHeight: 44)
                    }
                }

                sectionTitle("アカウント").padding(.top, 20)
                card {
                    VStack(alignment: .leading, spacing: 0) {
                        if let email = auth.email {
                            row { Text("ログイン中"); Spacer(); Text(email).foregroundStyle(Theme.muted).lineLimit(1) }
                            Divider()
                        }
                        Button { Task { await plan.restore() } } label: { row { Text("購入を復元"); Spacer() } }
                        if let msg = plan.message { Text(msg).font(.footnote).foregroundStyle(Theme.muted).padding(.bottom, 6) }
                        Divider()
                        Link(destination: URL(string: "https://catchwords.lovable.app")!) { row { Text("Web版を開く"); Spacer(); Image(systemName: "arrow.up.right") } }
                        Divider()
                        Link(destination: URL(string: "https://catchwords.lovable.app/terms")!) { row { Text("利用規約"); Spacer(); Image(systemName: "chevron.right") } }
                        Divider()
                        Link(destination: URL(string: "https://catchwords.lovable.app/privacy")!) { row { Text("プライバシーポリシー"); Spacer(); Image(systemName: "chevron.right") } }
                        Divider()
                        Button(role: .destructive) { confirmSignOut = true } label: { row { Text("ログアウト").foregroundStyle(Theme.destructive); Spacer() } }
                    }
                    .foregroundStyle(Theme.foreground)
                }

                Text("CatchWords for iPhone 1.0")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).padding(.top, 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
        .onAppear { nameDraft = profile.displayName }
        .onChange(of: profile.displayName) { _, v in if !nameFocused { nameDraft = v } }
        .onChange(of: avatarItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    await profile.uploadAvatar(img)
                }
                avatarItem = nil
            }
        }
        .confirmationDialog("ログアウトしますか？", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("ログアウト", role: .destructive) { auth.signOut() }
        }
    }

    private func saveName() {
        let v = nameDraft.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty, v != profile.displayName else { return }
        profile.displayName = v
        Task { await profile.update(["display_name": v]) }
    }

    private var proCard: some View {
        Button { router.showPaywall = !plan.isPro } label: {
            HStack(spacing: 14) {
                Image(systemName: plan.isPro ? "crown.fill" : "sparkles")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(plan.isPro ? AnyShapeStyle(Theme.gold) : AnyShapeStyle(Theme.brandGradient), in: .rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.isPro ? "CatchWords Pro" : "Proにアップグレード").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.foreground)
                    Text(plan.isPro ? "撮影は無制限です" : "今日あと\(plan.remainingToday)回 · 無制限にする").font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                if !plan.isPro { Image(systemName: "chevron.right").foregroundStyle(Theme.muted) }
            }
            .padding(16)
            .background(.white, in: .rect(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted).padding(.leading, 6)
    }

    private func fieldLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.foreground)
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: .rect(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    private func row<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack { content() }.font(.system(size: 16)).frame(minHeight: 48).contentShape(Rectangle())
    }

    private func menuRow(value: String, options: [(value: String, label: String)], onPick: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(options, id: \.value) { o in
                Button { Haptics.selection(); onPick(o.value) } label: {
                    if o.value == value { Label(o.label, systemImage: "checkmark") } else { Text(o.label) }
                }
            }
        } label: {
            HStack {
                Text(options.first { $0.value == value }?.label ?? value).font(.system(size: 18)).foregroundStyle(Theme.foreground)
                Spacer()
                Image(systemName: "chevron.down").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 20).frame(minHeight: 58)
            .background(Color(hex: 0xF5F9FF), in: .rect(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.primary.opacity(0.2), lineWidth: 1))
        }
    }
}
