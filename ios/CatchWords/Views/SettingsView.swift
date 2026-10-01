import SwiftUI
import PhotosUI

/// settings.tsx: small grey section titles outside white cards; every choice is a row of pills with a
/// sliding blue capsule; language/level open a wheel card. Order matches the web app.
struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(PlanStore.self) private var plan
    @Environment(ProfileStore.self) private var profile
    @Environment(DexStore.self) private var dex
    @Environment(AppRouter.self) private var router

    @AppStorage("photos.sync") private var photoSync: Bool = true
    @AppStorage("haptics.enabled") private var haptics: Bool = true
    @AppStorage("sound.level") private var soundLevel: String = "subtle"
    @AppStorage("reading.pref") private var readingPref: String = "zhuyin"
    @AppStorage("ipa.pref") private var ipaPref: String = "us"
    @AppStorage("photo.pref") private var photoPref: String = "auto"
    @AppStorage("selfie.mode") private var selfieMode: Bool = true
    @AppStorage(CaptureViewModel.cutoutModeKey) private var cutoutMode: Bool = true
    @AppStorage(Scene3D.enabledKey) private var fx3D: Bool = true
    @AppStorage("theme.pref") private var themePref: String = "light"
    @AppStorage("motion.pref") private var motionPref: String = "full"
    @AppStorage(Wallpaper.key) private var wallRaw: String = Wallpaper.paper.rawValue
    @AppStorage(ReminderService.modeKey) private var reminderMode: String = "off"
    @AppStorage(ReminderService.timesKey) private var reminderTimes: String = ReminderService.defaultTime
    @AppStorage(ReminderService.placeKey) private var placeRemind: Bool = false

    @State private var avatarItem: PhotosPickerItem?
    @State private var nameDraft: String = ""
    @FocusState private var nameFocused: Bool
    @State private var wheel: WheelField?
    @State private var notifyDenied: Bool = false
    @State private var deleteOpen: Bool = false
    @State private var deleteText: String = ""
    @State private var isDeleting: Bool = false
    @State private var deleteError: String?
    @State private var confirmSignOut: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                profileSection
                languageSection
                studySection
                notifySection
                appearanceSection
                feelSection
                proSection
                accountButtons
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 130)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
        .overlay {
            if let wheel {
                WheelCard(field: wheel, profile: profile) { closeWheel() }
                    .transition(.opacity)
                    .zIndex(3)
            }
        }
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
        .confirmationDialog(L("サインアウトしますか？"), isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button(L("サインアウト"), role: .destructive) { auth.signOut() }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        SettingsCard(title: L("プロフィール")) {
            VStack(alignment: .leading, spacing: 12) {
                label(L("プロフィール写真"))
                HStack(spacing: 14) {
                    AvatarView(url: profile.avatarURL, size: 60)
                        .overlay { if profile.isSavingAvatar { ProgressView() } }
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        Text(profile.avatarURL == nil ? L("選ぶ") : L("変更"))
                            .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.foreground)
                            .padding(.horizontal, 18).frame(minHeight: 46)
                            .background(Color(hex: 0xF3F7FC), in: Capsule())
                            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    if profile.avatarURL != nil {
                        Button(L("外す")) { Task { await profile.clearAvatar() } }
                            .font(.system(size: 16)).foregroundStyle(Theme.muted)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                label(L("表示名")).padding(.top, 4)
                TextField(L("名前"), text: $nameDraft)
                    .font(.system(size: 17))
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .padding(.horizontal, 14).frame(minHeight: 48)
                    .background(Theme.card, in: .rect(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
                    .onSubmit(saveName)
                    .onChange(of: nameFocused) { _, f in if !f { saveName() } }
            }
        }
    }

    private var languageSection: some View {
        let isEnglish = profile.targetLanguage == "en"
        let levels = ProfileStore.levels(for: profile.targetLanguage)
        return SettingsCard(title: L("言語")) {
            VStack(alignment: .leading, spacing: 10) {
                label(L("母語"))
                wheelRow(ProfileStore.nativeOptions.first { $0.value == profile.nativeLanguage }?.label ?? L("日本語")) { openWheel(.native) }
                label(L("学習言語")).padding(.top, 6)
                wheelRow(ProfileStore.targetOptions.first { $0.value == profile.targetLanguage }?.label ?? L("繁體字（台灣）")) { openWheel(.target) }
                label(L("今のレベル")).padding(.top, 6)
                wheelRow(levels.first { $0.value == profile.currentLevel }?.label ?? profile.currentLevel) { openWheel(.current) }
                label(L("目標レベル")).padding(.top, 6)
                wheelRow(levels.first { $0.value == profile.levelGoal }?.label ?? profile.levelGoal) { openWheel(.goal) }
                label(L("発音表記")).padding(.top, 6)
                if isEnglish {
                    ChoicePills(options: [("us", L("IPA アメリカ")), ("uk", L("IPA イギリス"))], selection: $ipaPref)
                } else {
                    ChoicePills(options: [("zhuyin", L("ㄅㄆㄇ 注音")), ("pinyin", L("abc ピンイン"))], selection: $readingPref)
                }
                if let m = profile.message {
                    Text(m).font(.footnote).foregroundStyle(Theme.destructive)
                }
            }
        }
    }

    private var studySection: some View {
        SettingsCard(title: L("学習設定")) {
            VStack(alignment: .leading, spacing: 10) {
                label(L("表示するタイプ"))
                // Web photo-pref: which picture shows on home, dex and review when a word has no choice of its own.
                // iOS keeps 切り抜き (cut-out mode is iOS's own).
                ChoicePills(options: [("object", L("元の写真")), ("cutout", L("切り抜き")), ("selfie", L("自撮り"))], selection: $photoPref)
                label(L("1日の復習枚数")).padding(.top, 6)
                ChoicePills(
                    options: [("10", "10"), ("20", "20"), ("30", "30"), ("50", "50"), ("0", L("無制限"))],
                    selection: Binding(
                        get: { String(profile.reviewDailyLimit) },
                        set: { v in
                            let n = Int(v) ?? 20
                            profile.reviewDailyLimit = n
                            Task { await profile.update(["review_daily_limit": n]) }
                        }
                    )
                )
                Divider().overlay(Theme.border).padding(.top, 8)
                SettingsToggle(title: L("自撮りモード"), detail: L("単語を撮ったあと、続けてその場の自分を撮る画面に進みます"), isOn: $selfieMode)
                Divider().overlay(Theme.border)
                SettingsToggle(title: L("カメラロールに保存"), detail: L("撮った写真をスマホの写真アプリにも残します"), isOn: $photoSync)
                Divider().overlay(Theme.border)
                SettingsToggle(title: L("切り抜きモード"), detail: L("単語を選ぶと写っている物を切り抜いて、ステッカーにしてから図鑑に入れます。オフにすると写真のまま入れます"), isOn: $cutoutMode)
                Divider().overlay(Theme.border)
                SettingsToggle(title: L("3Dの演出"), detail: L("図鑑の本棚とアルバムを立体で見せます。「視差効果を減らす」がオンの時は出しません"), isOn: $fx3D)
            }
        }
    }

    private var notifySection: some View {
        SettingsCard(title: L("通知")) {
            VStack(alignment: .leading, spacing: 10) {
                label(L("復習の通知"))
                ChoicePills(
                    options: [("off", L("オフ")), ("ai", L("自動")), ("custom", L("時刻を指定"))],
                    selection: Binding(get: { reminderMode }, set: { setReminderMode($0) })
                )
                if reminderMode == "custom" { timesEditor.transition(.opacity.combined(with: .move(edge: .top))) }
                if notifyDenied {
                    notice(L("通知が許可されていません。iPhoneの「設定」→「CatchWords」→「通知」から許可してください。"))
                }
                Divider().overlay(Theme.border).padding(.top, 8)
                SettingsToggle(
                    title: L("場所でリマインド"),
                    detail: L("単語を撮った場所の近くに来ると、その単語を通知で思い出させます"),
                    isOn: Binding(get: { placeRemind }, set: { setPlaceRemind($0) })
                )
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: reminderMode)
        }
    }

    private var appearanceSection: some View {
        SettingsCard(title: L("外観")) {
            VStack(alignment: .leading, spacing: 10) {
                label(L("画面の明るさ"))
                ChoicePills(
                    options: [("light", L("ライト")), ("dark", L("ダーク")), ("system", L("システム"))],
                    selection: Binding(get: { themePref }, set: { v in
                        withAnimation(.easeInOut(duration: 0.35)) { themePref = v }
                    })
                )
                Text(L("ホームのアルバムは、紙の手触りのためいつも明るい色で表示します。"))
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                label(L("アニメーション")).padding(.top, 6)
                ChoicePills(options: [("system", L("自動")), ("full", L("見せる")), ("reduce", L("減らす"))], selection: $motionPref)
                label(L("ホームの壁紙")).padding(.top, 10)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                    ForEach(Wallpaper.allCases) { w in
                        WallpaperSwatch(kind: w, isSelected: wallRaw == w.rawValue) {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { wallRaw = w.rawValue }
                        }
                    }
                }
            }
        }
    }

    private var feelSection: some View {
        SettingsCard(title: L("音と手ざわり")) {
            VStack(alignment: .leading, spacing: 10) {
                label(L("効果音"))
                ChoicePills(
                    options: [("off", L("オフ")), ("subtle", L("控えめ")), ("full", L("しっかり"))],
                    selection: Binding(get: { soundLevel }, set: { v in
                        soundLevel = v
                        if v != "off" { SoundService.shared.play(.impact) }
                    })
                )
                SettingsToggle(title: L("振動"), detail: nil, isOn: Binding(get: { haptics }, set: { v in
                    haptics = v
                    if v { Haptics.impact(.medium) }
                }))
                .padding(.top, 6)
            }
        }
    }

    private var proSection: some View {
        SettingsCard(title: "CatchWords Pro") {
            VStack(alignment: .leading, spacing: 10) {
                if plan.isPro {
                    Text(L("Pro をご利用中です")).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.foreground)
                    Text(L("撮影は無制限です")).font(.system(size: 13)).foregroundStyle(Theme.muted)
                } else {
                    Text(PlanStore.catchLimitEnabled ? L("今日あと\(plan.remainingToday)回撮れます") : L("ベータ期間中は撮影回数の制限はありません"))
                        .font(.system(size: 15)).foregroundStyle(Theme.muted)
                    Button { router.showPaywall = true } label: {
                        Text(L("Proにアップグレード")).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(pillFill, in: Capsule())
                            .shadow(color: Theme.primary.opacity(0.35), radius: 10, y: 5)
                    }
                    .buttonStyle(PressableStyle())
                }
                HStack(spacing: 18) {
                    Button(L("購入を復元")) { Task { await plan.restore() } }
                    Link(L("利用規約"), destination: URL(string: "https://catchwords.lovable.app/terms")!)
                    Link(L("プライバシー"), destination: URL(string: "https://catchwords.lovable.app/privacy")!)
                }
                .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.primaryInk)
                .frame(minHeight: 44)
                if let msg = plan.message { Text(msg).font(.footnote).foregroundStyle(Theme.muted) }
            }
        }
    }

    private var accountButtons: some View {
        VStack(spacing: 20) {
            Button { confirmSignOut = true } label: {
                Label(L("サインアウト"), systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.foreground)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.card, in: Capsule())
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            }
            .buttonStyle(PressableStyle())

            deleteZone

            Text("CatchWords for iPhone 1.0")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
    }

    private var deleteZone: some View {
        let armed = ["削除", "DELETE", "刪除"].contains(  // l10n-ignore (accepted confirm words)
           deleteText.trimmingCharacters(in: .whitespaces).uppercased())
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { deleteOpen.toggle() }
            } label: {
                HStack {
                    Text(L("アカウントを削除")).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color(hex: 0xB42329))
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xB42329).opacity(0.7))
                        .rotationEffect(.degrees(deleteOpen ? 180 : 0))
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if deleteOpen {
                Text(L("撮った写真・図鑑・復習の記録がすべて消え、元に戻せません。Web版のデータも同じく消えます。"))
                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
                Text(L("確認のため「削除」と入力してください")).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.foreground)
                TextField(L10n.lang == "en" ? "DELETE" : L("削除"), text: $deleteText)  // the confirm word itself
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(.horizontal, 14).frame(minHeight: 46)
                    .background(Theme.card, in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                Button { Task { await deleteAccount() } } label: {
                    HStack(spacing: 8) {
                        if isDeleting { ProgressView().tint(.white) } else { Image(systemName: "trash") }
                        Text(isDeleting ? L("削除しています…") : L("完全に削除する"))
                    }
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.destructive.opacity(armed ? 1 : 0.4), in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .disabled(!armed || isDeleting)
                if let deleteError { Text(deleteError).font(.footnote).foregroundStyle(Theme.destructive) }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Theme.card, in: .rect(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.destructive.opacity(0.3), lineWidth: 1))
    }

    private var timesEditor: some View {
        let times = ReminderService.parseTimes(reminderTimes)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(times.enumerated()), id: \.offset) { i, t in
                HStack {
                    DatePicker(L("通知の時刻"), selection: Binding(
                        get: { Self.date(from: t) },
                        set: { d in
                            var list = times
                            list[i] = Self.hhmm(d)
                            saveTimes(list)
                        }
                    ), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    if times.count > 1 {
                        Button { var list = times; list.remove(at: i); saveTimes(list) } label: {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(L("この時刻を消す"))
                    }
                    Spacer()
                }
            }
            if times.count < 3 {
                Button { saveTimes(times + [ReminderService.defaultTime]) } label: {
                    Label(L("時刻を追加"), systemImage: "plus").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.primary)
                        .frame(minHeight: 44)
                }
            }
        }
    }

    // MARK: - Pieces

    private var pillFill: LinearGradient {
        LinearGradient(colors: [Theme.primaryBright, Theme.primaryDeep], startPoint: .top, endPoint: .bottom)
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.foreground)
    }

    private func notice(_ t: String) -> some View {
        Text(t).font(.system(size: 12)).foregroundStyle(Color(hex: 0x7A4B00))
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xFFF5DB), in: .rect(cornerRadius: 12))
    }

    private func wheelRow(_ value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(value).font(.system(size: 18)).foregroundStyle(Theme.foreground)
                Spacer()
                Image(systemName: "chevron.down").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 20).frame(minHeight: 56)
            .background(LinearGradient(colors: [Theme.card, Color(light: 0xEEF5FF, dark: 0x132032)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: .rect(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.primary.opacity(0.2), lineWidth: 1))
            .shadow(color: Theme.primary.opacity(0.06), radius: 6, y: 3)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    // MARK: - Actions

    private func openWheel(_ f: WheelField) {
        Haptics.selection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { wheel = f }
    }

    private func closeWheel() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { wheel = nil }
    }

    private func saveName() {
        let v = nameDraft.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty, v != profile.displayName else { return }
        profile.displayName = v
        Task { await profile.update(["display_name": v]) }
    }

    private func setReminderMode(_ mode: String) {
        Task {
            if mode != "off", reminderMode == "off" {
                guard await ReminderService.requestPermission() else {
                    withAnimation { notifyDenied = true }
                    return
                }
            }
            notifyDenied = false
            reminderMode = mode
            let times = ReminderService.parseTimes(reminderTimes)
            await ReminderService.applyReview(mode: mode, times: times, due: dex.upcomingDueTimes)
            await ReminderService.saveToAccount(mode: mode, times: times)
        }
    }

    private func saveTimes(_ list: [String]) {
        reminderTimes = list.joined(separator: ",")
        Task {
            await ReminderService.applyReview(mode: reminderMode, times: list, due: dex.upcomingDueTimes)
            await ReminderService.saveToAccount(mode: reminderMode, times: list)
        }
    }

    private func setPlaceRemind(_ on: Bool) {
        Task {
            if on, !(await ReminderService.requestPermission()) {
                withAnimation { notifyDenied = true }
                placeRemind = false
                return
            }
            placeRemind = on
            await ReminderService.applyPlaces(enabled: on, stickers: dex.stickers)
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        deleteError = nil
        do {
            try await profile.deleteAccount()
            isDeleting = false
            auth.signOut()
        } catch {
            isDeleting = false
            deleteError = L("削除できませんでした。通信を確かめて、もう一度お試しください。")
        }
    }

    private static func date(from hhmm: String) -> Date {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        return Calendar.current.date(bySettingHour: p.first ?? 20, minute: p.last ?? 0, second: 0, of: Date()) ?? Date()
    }

    private static func hhmm(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 20, c.minute ?? 0)
    }
}

// MARK: - Building blocks

/// Section title (small, grey, outside) + white rounded card.
struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted).padding(.leading, 6)
            content
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: .rect(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.border, lineWidth: 1))
        }
    }
}

/// ChoiceRow: equal-width pills; the selected one is a glowing blue capsule that slides between them.
struct ChoicePills: View {
    let options: [(value: String, label: String)]
    @Binding var selection: String
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.value) { o in
                let on = o.value == selection
                Button {
                    guard !on else { return }
                    Haptics.selection()
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.72)) { selection = o.value }
                } label: {
                    Text(o.label)
                        .font(.system(size: 16, weight: on ? .bold : .regular))
                        .foregroundStyle(on ? .white : Theme.foreground)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .padding(.horizontal, 4)
                        .background {
                            Capsule()
                                .fill(LinearGradient(colors: [Theme.card, Color(light: 0xF1F6FD, dark: 0x16202F)], startPoint: .top, endPoint: .bottom))
                                .overlay(Capsule().stroke(Color(hex: 0xC9DDF5), lineWidth: 1))
                            if on {
                                Capsule()
                                    .fill(LinearGradient(colors: [Theme.primaryBright, Theme.primaryDeep], startPoint: .top, endPoint: .bottom))
                                    .shadow(color: Theme.primary.opacity(0.4), radius: 10, y: 6)
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle(scale: 0.95))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// ToggleRow: title, optional grey one-liner, blue switch.
struct SettingsToggle: View {
    let title: String
    let detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: { v in Haptics.selection(); isOn = v })) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.foreground)
                if let detail {
                    Text(detail).font(.system(size: 13)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Theme.primary)
        .frame(minHeight: 48)
    }
}

enum WheelField: Identifiable {
    case native, target, current, goal
    var id: Self { self }
    var title: String {
        switch self {
        case .native: L("母語")
        case .target: L("学習言語")
        case .current: L("今のレベル")
        case .goal: L("目標レベル")
        }
    }
}

/// WheelPicker: dimmed backdrop, centred white card with title, ×, wheel and 「閉じる」.
struct WheelCard: View {
    let field: WheelField
    let profile: ProfileStore
    let onClose: () -> Void
    @Environment(DexStore.self) private var dex
    @State private var value: String = ""
    @State private var appeared: Bool = false

    private var options: [(value: String, label: String)] {
        switch field {
        case .native: ProfileStore.nativeOptions
        case .target: ProfileStore.targetOptions
        case .current, .goal: ProfileStore.levels(for: profile.targetLanguage)
        }
    }

    private var initial: String {
        switch field {
        case .native: profile.nativeLanguage
        case .target: profile.targetLanguage
        case .current: profile.currentLevel
        case .goal: profile.levelGoal
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(field.title).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.foreground)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.foreground)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L("閉じる"))
                }
                Picker(field.title, selection: $value) {
                    ForEach(options, id: \.value) { o in Text(o.label).tag(o.value) }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                .onChange(of: value) { _, v in commit(v) }
                Button(action: onClose) {
                    Text(L("閉じる")).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.primary, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .background(Theme.card, in: .rect(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 30, y: 12)
            .padding(.horizontal, 20)
            .scaleEffect(appeared ? 1 : 0.94)
        }
        .onAppear {
            value = initial
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { appeared = true }
        }
    }

    private func commit(_ v: String) {
        guard !v.isEmpty, v != initial else { return }
        Haptics.selection()
        switch field {
        case .native:
            profile.nativeLanguage = v
            ReaderLanguage.native = v
            withAnimation(.easeInOut(duration: 0.25)) { L10n.set(v) }   // the whole app switches now
            // The web derives native_language from ui_language and saves both (settings.tsx).
            Task { await profile.update(["native_language": v, "ui_language": v]) }
        case .target:
            profile.targetLanguage = v
            profile.currentLevel = ProfileStore.remap(profile.currentLevel, to: v)
            profile.levelGoal = ProfileStore.remap(profile.levelGoal, to: v)
            Task {
                // Language first, on its own (web: a rejected level column must not undo the language).
                await profile.update(["target_language": v])
                await profile.update(["current_level": profile.currentLevel, "level_goal": profile.levelGoal])
                // The dex, album and review show only the words of the language being learned.
                await dex.load()
            }
        case .current:
            profile.currentLevel = v
            Task { await profile.update(["current_level": v]) }
        case .goal:
            profile.levelGoal = v
            Task { await profile.update(["level_goal": v]) }
        }
    }
}
