import SwiftUI
import PhotosUI

/// wordbooks.tsx — shelf of wordbooks, shoot a page → confirm → import, and a per-book review.
/// Kept apart from the dex on purpose: these words have no photo and no place.
struct WordbookView: View {
    @State private var store = WordbookStore()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera: Bool = false
    @State private var isReading: Bool = false
    @State private var draft: WordbookDraft?
    @State private var reviewing: WordbookSummary?
    @State private var pendingDelete: WordbookSummary?
    @State private var toast: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        shootCard
                        shelf
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .refreshable { await store.load() }
            }
            .navigationTitle("単語帳")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .navigationDestination(item: $reviewing) { book in
                WordbookReviewView(book: book, store: store)
            }
        }
        .task { if !store.hasLoaded { await store.load() } }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    await read(img)
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            PageCameraView { img in
                showCamera = false
                if let img { Task { await read(img) } }
            }
        }
        .sheet(item: Binding(get: { draft.map { DraftBox(draft: $0) } }, set: { if $0 == nil { draft = nil } })) { box in
            WordbookConfirmView(draft: box.draft, store: store) { added in
                draft = nil
                showToast("\(added)語を取り込みました")
            }
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "「\(pendingDelete?.title ?? "")」を語ごと消します。戻せません。",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("消す", role: .destructive) {
                guard let b = pendingDelete else { return }
                Task {
                    do { try await store.delete(b); Haptics.success() } catch { showToast("消せませんでした") }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Theme.foreground.opacity(0.92), in: Capsule())
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private struct DraftBox: Identifiable {
        let draft: WordbookDraft
        var id: String { draft.entries.map(\.headword).joined() }
    }

    private var shootCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button { showCamera = true } label: {
                    HStack(spacing: 8) {
                        if isReading { ProgressView().tint(.white) } else { Image(systemName: "camera.fill") }
                        Text(isReading ? "読み取っています…" : "単語帳を撮る")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.brandGradient, in: .rect(cornerRadius: 16, style: .continuous))
                    .shadow(color: Theme.primary.opacity(0.35), radius: 12, y: 6)
                }
                .buttonStyle(PressableStyle())
                .disabled(isReading)

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.primaryInk)
                        .frame(width: 52, height: 52)
                        .background(Theme.card, in: .rect(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border))
                }
                .disabled(isReading)
                .accessibilityLabel("写真から選ぶ")
            }
            Text("単語が並んだページを、まっすぐ明るい所で撮ってください。並んでいる語をまとめて取り込みます。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var shelf: some View {
        if let err = store.loadError, store.books.isEmpty {
            VStack(spacing: 10) {
                Label(err, systemImage: "wifi.exclamationmark")
                Button("もう一度読み込む") { Task { await store.load() } }.foregroundStyle(Theme.primary)
            }
            .frame(maxWidth: .infinity).padding(.top, 40)
        } else if !store.hasLoaded {
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 20).fill(Theme.secondary).frame(height: 84)
                }
            }
            .redacted(reason: .placeholder)
        } else if store.books.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "book.closed")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 72, height: 72)
                    .background(Theme.accent, in: Circle())
                Text("まだ単語帳がありません").font(.system(size: 17, weight: .semibold))
                Text("教科書や自作のリストを撮ると、そこに並ぶ語をまとめて取り込んで、図鑑とは別に復習できます。")
                    .font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.top, 40).padding(.horizontal, 20)
        } else {
            VStack(spacing: 10) {
                ForEach(store.books) { book in bookRow(book) }
            }
        }
    }

    private func bookRow(_ book: WordbookSummary) -> some View {
        let p = book.total == 0 ? 0 : Double(book.learned) / Double(book.total)
        return Button {
            Haptics.selection()
            reviewing = book
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.brandGradient)
                    .frame(width: 38, height: 54)
                    .overlay(alignment: .leading) { Rectangle().fill(.white.opacity(0.35)).frame(width: 3).padding(.leading, 5) }
                    .shadow(color: Theme.primary.opacity(0.3), radius: 4, y: 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.foreground).lineLimit(1)
                    HStack(spacing: 8) {
                        Text(book.due > 0 ? "今日 \(book.due)語" : "今日はおしまい")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(book.due > 0 ? Theme.primaryInk : Theme.muted)
                        Text("覚えた \(book.learned)／\(book.total)").font(.system(size: 12)).foregroundStyle(Theme.muted).monospacedDigit()
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.secondary)
                            Capsule().fill(Theme.ok).frame(width: max(4, g.size.width * p))
                        }
                    }
                    .frame(height: 4)
                }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.card, in: .rect(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .contextMenu {
            Button(role: .destructive) { pendingDelete = book } label: { Label("「\(book.title)」を消す", systemImage: "trash") }
        }
        .accessibilityHint("この単語帳を復習する")
    }

    private func read(_ image: UIImage) async {
        isReading = true
        defer { isReading = false }
        do {
            draft = try await AIService.shared.extractWordbook(image: image)
            Haptics.success()
        } catch {
            Haptics.warning()
            showToast((error as? LocalizedError)?.errorDescription ?? "読み取れませんでした")
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation(.easeOut(duration: 0.25)) { if toast == text { toast = nil } }
        }
    }
}

/// "この語で合っていますか" — drop misreads before anything is saved.
struct WordbookConfirmView: View {
    let store: WordbookStore
    let onSaved: (Int) -> Void
    @State private var title: String
    @State private var entries: [WordbookEntryDraft]
    @State private var isSaving: Bool = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(draft: WordbookDraft, store: WordbookStore, onSaved: @escaping (Int) -> Void) {
        self.store = store
        self.onSaved = onSaved
        _title = State(initialValue: draft.title)
        _entries = State(initialValue: draft.entries)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("この語で合っていますか").font(.system(size: 22, weight: .bold))
                    Text("違う語が混ざっていたら、右の×で外してください。外した語は入りません。")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("単語帳の名前").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                        TextField("例: TOCFL 2級 第3課", text: $title)
                            .padding(.horizontal, 14).frame(minHeight: 48)
                            .background(Theme.secondary, in: .rect(cornerRadius: 14))
                    }
                    VStack(spacing: 8) {
                        ForEach(entries) { e in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(e.headword).font(.system(size: 20, weight: .bold))
                                        if let z = e.readingZhuyin { Text(z).font(.system(size: 12)).foregroundStyle(Theme.muted) }
                                    }
                                    Text(e.meaningJa ?? "（意味が読み取れていません）")
                                        .font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(2)
                                }
                                Spacer()
                                Button {
                                    Haptics.selection()
                                    withAnimation(.snappy) { entries.removeAll { $0.id == e.id } }
                                } label: {
                                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Theme.muted).frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("「\(e.headword)」を外す")
                            }
                            .padding(.leading, 14)
                            .background(Theme.card, in: .rect(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border))
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                    if let error { Text(error).font(.system(size: 13)).foregroundStyle(Theme.destructive) }
                }
                .padding(20)
            }
            VStack(spacing: 8) {
                PrimaryButton(title: "\(entries.count)語を取り込む", icon: "tray.and.arrow.down", isLoading: isSaving) { save() }
                    .disabled(entries.isEmpty)
                Button("キャンセル") { dismiss() }.foregroundStyle(Theme.muted).frame(minHeight: 44)
            }
            .padding(.horizontal, 20).padding(.bottom, 8)
        }
        .background(Theme.background)
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let n = try await store.create(title: title, entries: entries)
                Haptics.success()
                onSaved(n)
            } catch {
                Haptics.warning()
                self.error = (error as? LocalizedError)?.errorDescription ?? "取り込めませんでした"
            }
        }
    }
}

/// Per-book 4-choice review: meaning → pick the word (choices from the same book, no AI).
struct WordbookReviewView: View {
    let book: WordbookSummary
    let store: WordbookStore
    @State private var cards: [WordbookEntry] = []
    @State private var pool: [String] = []
    @State private var choices: [String] = []
    @State private var index: Int = 0
    @State private var correct: Int = 0
    @State private var picked: String?
    @State private var isLoading: Bool = true
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private var current: WordbookEntry? { index < cards.count ? cards[index] : nil }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 18) {
                if isLoading {
                    ProgressView().frame(maxHeight: .infinity)
                } else if let error {
                    VStack(spacing: 10) {
                        Text(error)
                        Button("もう一度読み込む") { Task { await load() } }.foregroundStyle(Theme.primary)
                    }.frame(maxHeight: .infinity)
                } else if cards.isEmpty {
                    empty("checkmark.circle", "今日出す語はありません", "この本の語は、次に出る日まで休みます。ほかの本を選ぶか、新しく取り込んでください。")
                } else if let card = current {
                    quiz(card)
                } else {
                    finished
                }
            }
            .padding(16)
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let r = try await store.due(bookId: book.id)
            cards = r.due
            pool = r.pool
            index = 0
            correct = 0
            error = nil
            makeChoices()
        } catch {
            self.error = "今日の出題を読み込めませんでした。"
        }
    }

    private func makeChoices() {
        guard let c = current else { return }
        let others = pool.filter { $0 != c.headword }.shuffled().prefix(3)
        choices = ([c.headword] + others).shuffled()
        picked = nil
    }

    private func quiz(_ card: WordbookEntry) -> some View {
        VStack(spacing: 18) {
            HStack {
                Text("この意味の語はどれ").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
                Spacer()
                Text("\(index + 1)／\(cards.count)").font(.system(size: 14)).monospacedDigit().foregroundStyle(Theme.muted)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.secondary)
                    Capsule().fill(Theme.primary).frame(width: max(8, g.size.width * CGFloat(index) / CGFloat(max(1, cards.count))))
                }
            }
            .frame(height: 6)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: index)

            Text(card.meaningJa ?? "（意味が読み取れていません）")
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 160)
                .padding(20)
                .background(Theme.card, in: .rect(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 16, y: 8)

            VStack(spacing: 10) {
                ForEach(choices, id: \.self) { c in choiceButton(c, card: card) }
            }
            Spacer(minLength: 0)
            if picked != nil {
                PrimaryButton(title: index + 1 < cards.count ? "次へ" : "結果を見る", icon: "arrow.right") {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { index += 1 }
                    makeChoices()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .id(card.id)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
    }

    private func choiceButton(_ c: String, card: WordbookEntry) -> some View {
        let isAnswer = c == card.headword
        let state: Int = picked == nil ? 0 : (isAnswer ? 1 : (picked == c ? 2 : 3))
        return Button {
            guard picked == nil else { return }
            let ok = isAnswer
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { picked = c }
            if ok { correct += 1; Haptics.success() } else { Haptics.warning() }
            SoundService.shared.speak(card.headword)
            Task {
                do { try await store.grade(card, correct: ok) } catch { }
            }
        } label: {
            HStack {
                Text(c).font(.system(size: 22, weight: .semibold))
                if state == 1, let z = card.readingZhuyin { Text(z).font(.system(size: 12)).foregroundStyle(Theme.muted) }
                Spacer()
                if state == 1 { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.ok) }
                if state == 2 { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.destructive) }
            }
            .foregroundStyle(Theme.foreground)
            .padding(.horizontal, 18)
            .frame(minHeight: 58)
            .background(
                state == 1 ? Theme.ok.opacity(0.12) : (state == 2 ? Theme.destructive.opacity(0.1) : Theme.card),
                in: .rect(cornerRadius: 18, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(state == 1 ? Theme.ok : (state == 2 ? Theme.destructive : Theme.border), lineWidth: state == 0 || state == 3 ? 1 : 2))
            .opacity(state == 3 ? 0.5 : 1)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .disabled(picked != nil)
    }

    private var finished: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles").font(.system(size: 40)).foregroundStyle(Theme.gold)
            Text("この本の今日ぶんは終わりです").font(.system(size: 20, weight: .bold))
            Text("\(correct)／\(cards.count) 正解").font(.system(size: 16)).monospacedDigit().foregroundStyle(Theme.muted)
            PrimaryButton(title: "単語帳の一覧へ", icon: "books.vertical") {
                Task { await store.load() }
                dismiss()
            }
            .padding(.top, 8)
        }
        .frame(maxHeight: .infinity)
    }

    private func empty(_ icon: String, _ title: String, _ body: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 36)).foregroundStyle(Theme.ok)
            Text(title).font(.system(size: 18, weight: .bold))
            Text(body).font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 20)
    }
}

/// Minimal full-screen camera for photographing a page.
struct PageCameraView: View {
    let onDone: (UIImage?) -> Void
    @State private var camera = CameraService()
    @State private var isShooting: Bool = false

    var body: some View {
        ZStack {
            Theme.navyDeep.ignoresSafeArea()
            if camera.state == .running {
                CameraPreview(session: camera.session) { _, dp in camera.focus(at: dp) }
                    .ignoresSafeArea()
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                    .padding(28).padding(.vertical, 90)
                    .allowsHitTesting(false)
            } else if camera.state == .denied {
                VStack(spacing: 12) {
                    Text("カメラの使用が許可されていません").foregroundStyle(.white)
                    Button("設定を開く") {
                        if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                    }.foregroundStyle(Theme.cyan)
                }
            } else if camera.state == .unavailable {
                Text("カメラが見つかりません").foregroundStyle(.white.opacity(0.8))
            }
            VStack {
                HStack {
                    Button { onDone(nil) } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 44, height: 44).background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                Spacer()
                Text("ページ全体が枠に入るように").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.85))
                Button {
                    isShooting = true
                    Haptics.impact(.medium)
                    SoundService.shared.play(.snap)
                    Task {
                        let img = await camera.capture()
                        isShooting = false
                        onDone(img)
                    }
                } label: {
                    Circle().fill(.white).frame(width: 70, height: 70)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 4).padding(-7))
                }
                .buttonStyle(PressableStyle(scale: 0.9))
                .disabled(isShooting || camera.state != .running)
                .padding(.bottom, 30)
                .accessibilityLabel("撮影")
            }
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }
}
