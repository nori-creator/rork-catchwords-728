import SwiftUI

/// The card shown right after picking a word. It never waits for the cutout.
struct CatchCardView: View {
    @Bindable var vm: CaptureViewModel
    let onCatch: () -> Void

    @State private var floatUp: Bool = false
    @FocusState private var captionFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { vm.step = .select } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .glassCard(22)
                }
                .buttonStyle(PressableStyle())
                .opacity(vm.captureType == "photo" ? 1 : 0)
                Spacer()
                Button { vm.reset() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .glassCard(22)
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 18) {
                    heroImage
                    if let c = vm.picked { wordBlock(c) }
                    cutoutControls
                    if let d = vm.details, d.extras.hasMeters {
                        MetersPanel(extras: d.extras).transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if vm.isLoadingDetails {
                        HStack(spacing: 8) {
                            ProgressView().tint(Theme.muted)
                            Text("頻度と使い方を調べています").font(.system(size: 12)).foregroundStyle(Theme.muted)
                        }
                    }
                    captionField
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            PrimaryButton(title: "図鑑に追加", icon: "sparkles", sheen: true) {
                captionFocused = false
                onCatch()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 88)
        }
        .background(
            LinearGradient(colors: [.black.opacity(0.2), Theme.background.opacity(0.96)], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }

    private var heroImage: some View {
        ZStack {
            RadialGradient(colors: [Theme.primary.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 170)
                .frame(height: 280)
            Group {
                if let cut = vm.cutout {
                    Image(uiImage: cut)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .shadow(color: .black.opacity(0.5), radius: 18, y: floatUp ? 22 : 14)
                        .offset(y: floatUp ? -6 : 0)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                } else if let photo = vm.photo {
                    Color.clear
                        .frame(width: 230, height: 260)
                        .overlay { Image(uiImage: photo).resizable().scaledToFill().allowsHitTesting(false) }
                        .clipShape(.rect(cornerRadius: 22))
                        .overlay {
                            if vm.isCutting {
                                RoundedRectangle(cornerRadius: 22).fill(.black.opacity(0.25))
                                    .overlay(ProgressView().tint(.white))
                            }
                        }
                        .shadow(color: .black.opacity(0.4), radius: 14, y: 10)
                } else if let c = vm.picked {
                    Image(uiImage: CaptureViewModel.textCard(for: c.headword))
                        .resizable().scaledToFit().frame(height: 220)
                        .clipShape(.rect(cornerRadius: 22))
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { floatUp = true }
        }
    }

    private func wordBlock(_ c: Candidate) -> some View {
        VStack(spacing: 6) {
            Text(c.zhuyin)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                Text(c.headword)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                Button { SoundService.shared.speak(c.headword) } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 44, height: 44)
                        .glassCard(22)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("発音を聞く")
            }
            Text(c.pinyin).font(AppFont.mono(14)).foregroundStyle(Theme.cyan.opacity(0.85))
            Text(c.meaningJa).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
        }
    }

    @ViewBuilder
    private var cutoutControls: some View {
        if vm.photo != nil {
            HStack(spacing: 10) {
                if vm.cutout != nil {
                    Label("切り抜き済み", systemImage: "scissors").foregroundStyle(Theme.ok)
                    Button("元の写真にする") { vm.useOriginal() }.foregroundStyle(Theme.muted)
                } else if vm.isCutting {
                    Label("被写体を切り抜いています", systemImage: "wand.and.stars").foregroundStyle(Theme.muted)
                } else {
                    Button {
                        vm.startCutout(for: vm.picked)
                    } label: {
                        Label(vm.cutoutFailed ? "もう一度切り抜く" : "切り抜く", systemImage: "scissors")
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .glassCard(20)
                    }
                    .buttonStyle(PressableStyle())
                    .foregroundStyle(.white)
                    if vm.cutoutFailed {
                        Text("この写真では切り抜けませんでした").foregroundStyle(Theme.muted)
                    }
                }
            }
            .font(.system(size: 13, weight: .semibold))
        }
    }

    private var captionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "ひとこと")
            TextField("", text: $vm.caption, prompt: Text("今の気持ちや場所をメモ…").foregroundStyle(Theme.muted), axis: .vertical)
                .font(AppFont.hand(18))
                .foregroundStyle(.white)
                .focused($captionFocused)
                .lineLimit(1...3)
                .padding(14)
                .background(Theme.card.opacity(0.8), in: .rect(cornerRadius: 14))
            if let place = vm.placeName {
                Label(place, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}
