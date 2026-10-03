# 単語帳の背表紙: 文字の読みやすさの案

> 単語帳は 2026-10-01 のオーナー判断で削除済み（`WordbookView.swift` はもう無い）。この案は不要。

対象: `ios/CatchWords/Views/WordbookView.swift` の `WordbookShelf.spine(_:)`（514〜611行）。
画像: `spine-options.png`（390pt 幅・2x）。元の HTML: `spine-options.html`。

## いまの描き方（現状）

- 本の色: パレット `[0x2F6FDB, 0x4C5FD5, 0x168F8C, 0xD9822B, 0xC2416A, 0x3E8E47, 0x7A5AC8]` から ID のハッシュで1色（554, 559行）。幅 54pt、高さ 150〜195pt（560, 600行）、角丸 6。
- 「覚えた量」の帯: `.white.opacity(0.22)` の角丸長方形が下から `(height-12)*learned` まで上がる。四辺 4pt 内側（565〜569行）。
- タイトル: `.system(size: 14, weight: .bold)`・`.white`・1行・90°回転、38pt から `height-24` までの枠の中央（583〜589行）。
- 上: 今日の数（白い丸 24pt に本の色の 12pt heavy の数字）または白 85% のチェック（571〜582行）。上下の線は白 35% の 2pt（594〜598行）。
- 問題: 帯がタイトルの下まで上がると、白文字の背景が「本の色＋白22%」になり明るくなる。CI のスクリーンショット（`ci-previews` の `runs/ccr-89cbeb71-xcif1z-uitest/ja_en_20_wordbooks.png`）でも「果物の単語」の終わりが帯にかかっている。

コントラスト比は WCAG 2.x の式で計算。14pt bold は「大きい文字」（14pt bold = 約18.7px）に届かないので、基準は 4.5:1。
パレット全7色の中で一番低い値を出している（画像の各本の下には、その本で一番低い値を書いている）。

| 案 | 内容（1行） | 帯の上 | 帯の外 | 全体の最小 |
|---|---|---|---|---|
| 現状 | 白文字が明るい帯（白22%）の上に乗る | 2.28（橙）〜3.50 | 2.93（橙）〜5.38 | **2.28:1** |
| 案1 | 帯の中の文字だけ本の色の濃い版にする | 4.96〜6.70 | 現状のまま 2.93（橙）〜5.38 | 帯の上 **4.96:1**／帯の外は 2.93 |
| 案2 | タイトルの後ろに黒38%のカプセルを敷く | 5.38〜7.48 | 6.56〜10.10 | **5.38:1** |
| 案3 | 水位を左端の細いゲージにして文字から外し、明るい3色を少し深く | （帯なし） | 4.63〜5.38 | **4.63:1** |

すすめ: 文字の読みやすさだけなら案2（全色で最も高い）。見た目を最も変えずにすむのは案1だが、橙・青緑・緑は帯がなくても白文字が 4.5 に届かない。帯の外の問題まで直すなら案3。

---

## 案1 帯の上だけ濃い文字（コントラスト: 帯の上 4.96:1 以上、帯の外は現状のまま最小 2.93:1）

水位より下に入った文字・チェックだけを `color.mix(with: .black, by: 0.75)` で描き直す（同じラベルを2回描き、2回目を帯の高さでマスク）。

`WordbookView.swift`

- 570〜592行: いまの `VStack(spacing: 6) { … }.padding(.top, 8)` を関数に出し、文字色を引数にする。
  - 580行 old `.foregroundStyle(.white.opacity(0.85))` → new `.foregroundStyle(ink.opacity(ink == .white ? 0.85 : 1))`
  - 585行 old `.foregroundStyle(.white)` → new `.foregroundStyle(ink)`
  ```swift
  private func labels(_ book: WordbookSummary, color: Color, height: CGFloat, ink: Color) -> some View {
      VStack(spacing: 6) { /* 571〜590行そのまま。上の2か所だけ ink に */ }
          .padding(.top, 8)
  }
  ```
- 570行の位置に、2回描く:
  ```swift
  labels(book, color: color, height: height, ink: .white)
  labels(book, color: color, height: height, ink: color.mix(with: .black, by: 0.75))
      .mask(alignment: .bottom) {
          Rectangle().frame(height: max(0, (height - 12) * learned) + 4)
      }
  ```
  （今日の数の白い丸は2回目も同じ見た目なので変わらない。）

## 案2 文字の後ろに濃いプレート（コントラスト: 5.38:1 以上、全色で 4.5 合格）

タイトルだけを、黒38%のカプセルの上に置く。帯・色・線は今のまま。

`WordbookView.swift`

- 586行 `.lineLimit(1)` の直後に追加:
  - new `.padding(.horizontal, 7).padding(.vertical, 3)`
  - new `.background(.black.opacity(0.38), in: Capsule())`
- （587行 `.frame(width: height - 62)` はそのまま。プレートの左右 7pt のぶん、長い題（例「10月 旅行フレーズ」）は少し早く「…」になる。気になるなら 587行 old `height - 62` → new `height - 48` で枠を広げる。）

## 案3 帯を文字から外す（コントラスト: 4.63:1 以上、全色で 4.5 合格）

「覚えた量」を本の左端の細いゲージに変え、タイトルには薄い影を付ける。帯が文字に重ならないので、文字の背景は本の色だけになる。白文字が 4.5 に届かない3色だけ、少し深い色にする。

`WordbookView.swift`

- 554行 old `[0x2F6FDB, 0x4C5FD5, 0x168F8C, 0xD9822B, 0xC2416A, 0x3E8E47, 0x7A5AC8]`
  → new `[0x2F6FDB, 0x4C5FD5, 0x127A77, 0xAD621B, 0xC2416A, 0x367C3E, 0x7A5AC8]`
  （0x168F8C→0x127A77: 3.93→5.15、0xD9822B→0xAD621B: 2.93→4.63、0x3E8E47→0x367C3E: 4.07→5.11。上の白い丸の中の数字も同じ色なので、そちらも 4.5 以上になる。）
- 565〜569行 old
  ```swift
  RoundedRectangle(cornerRadius: 6, style: .continuous)
      .fill(.white.opacity(0.22))
      .frame(height: max(0, (height - 12) * learned))
      .padding(4)
  ```
  → new
  ```swift
  ZStack(alignment: .bottom) {
      Capsule().fill(.white.opacity(0.18)).frame(width: 4, height: height - 12)
      Capsule().fill(.white.opacity(0.85)).frame(width: 4, height: max(0, (height - 12) * learned))
  }
  .padding(4)
  .frame(maxWidth: .infinity, alignment: .leading)
  ```
- 585行 `.foregroundStyle(.white)` の後に追加: new `.shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)`
- 608行の `accessibilityValue` は変えない（覚えた量は読み上げで伝わる）。

## メモ

- HTML のフォントは SF の代わりに IPA ゴシック。字の太さ・幅は実機と少し違う。
- 見本の題・数は架空（「9月の単語」「果物の単語」「8月の単語」「10月 旅行フレーズ」「7月の単語」）。「果物の単語」と赤い色・4語は CI のスクリーンショットに合わせた。
- ダークモードでも本の色は同じなので、値は変わらない（棚板の色だけ変わる）。
