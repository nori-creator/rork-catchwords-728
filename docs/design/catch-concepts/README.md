# キャッチ演出 v5（スキャンと待ち時間の動画の素材と作り方）

撮影後のスキャン演出と、名前・解説が届くまでの待ち時間の演出を、動画にしたときの素材一式です。
アプリのコードはまだ変えていません。採用する案が決まったら、ここの寸法・タイミング・効果音を使って SwiftUI で実装します。

動画と設計の説明は Artifact のページにあります（オーナーの claude.ai アカウントで閲覧）。

| 動画 | 内容 |
| --- | --- |
| P1 被写体リフト | Apple 純正風のスキャン。物の本当の輪郭を光が一周し、物がわずかに浮き、表面を光沢が走る |
| P2 深度スキャン | 写真の奥行きに沿って、光の波が手前から奥へ進み、等高線が残る |
| P3 輪郭解析 | 写真の本当のエッジが波になって光り、物のエッジと特徴点だけが残る |
| S1 影あわせ | 名前を待つ間、タグは図鑑の未発見マス（影・No.???）。届くと図鑑と同じ動きで埋まる |
| S2 パタパタ | 発車標のように文字がめくれ、届くと左から順に止まる |
| S3 粒子 | 点がタグに溜まり、届くと左から文字に再集合する（E と同じ表現） |
| A 浮かび上がる | タップ後。輪郭が光って浮き、言い方を選ぶと図鑑の枠へ |
| D 図鑑に収まる | タップ後。アプリと同じ白と青の選択画面から図鑑の枠へ |
| E 単語の詳細 | 解説を書く間は点の雲。届くと左から文字になる（参照動画の再現） |

## v5 で変えたこと

- **しずく案（v4）は取り下げ**：オーナーの判断で却下されたため、全案から外しました。
- **スキャンを AI の分析から切り離した**：
  - 単語の分析（AI・通信あり）は裏で進めます。
  - スキャン演出は、撮った写真を端末の中で解析した結果だけで動きます。通信を待たないので、シャッターの約0.3秒後に始まります。
  - 物ごとに、その物の本当の輪郭・奥行き・エッジに沿って動きます。前のように、どの写真でも同じアニメーションが流れるのではありません。
- **名前のタグを出すルール**：その物のスキャンが終わり、かつその物の名前が届いた時に出します（`max(スキャン完了, 名前の到着)`）。
  - AI が速い時は、スキャンを最後まで見せてから出します。
  - AI が遅い時は、スキャンを終えて静かに待ちます。
  - 候補を1件ずつ受け取る仕組み（ストリーミング）にすれば、届いた物から順に出せます。
- **本物に合わせた**：ぼけた背景の植え込みは、実際の端末内処理でも切り抜けないことが多いので、スキャンせず「AI の答えだけで名前が出る物」として描いています。
- **D の選択画面**：肌色をやめ、アプリの色（背景 #F9FCFF、カード #FFFFFF、枠線 #E0E5EB、選択と NEW #0083FF）にしました。
- **E（単語の詳細）**：参照動画の、点に崩れて雲になり左から文字に戻る動きを再現しました。待ちが数秒あるので、雲はゆっくり流れ続け、時間とともに行の位置へ寄っていきます。
- **フォント**：映像用のフォントが一部の文字しか持っておらず、「スキャン」などが別のフォントで描かれていました。全文字を含む形で作り直しています。

## アプリで使う端末内の機能（Apple 公式ドキュメントで確認）

| 案 | 機能 | 対応 OS |
| --- | --- | --- |
| P1 | Vision `VNGenerateForegroundInstanceMaskRequest`（目立つ物を背景から分ける切り抜き）。今のアプリの `CutoutService.instanceMasks`（`Services/ImageTools.swift`）と同じもので、`CaptureViewModel` の `masksTask` が AI と並行して計算している | iOS 17 以降 |
| P2 | Core ML の Depth Anything V2（Apple の公式モデル集。`DepthAnythingV2SmallF16` 49.8MB／`F16P6` 19MB）、または撮影時の深度データ | モデルによる |
| P3 | Vision `VNDetectContoursRequest`（画像のエッジの輪郭を検出） | iOS 14 以降 |
| 参考 | VisionKit `ImageAnalysisInteraction.subjects`（写真の中の被写体の一覧） | iOS 16 以降 |

アプリの最小対応は iOS 18 なので、上の機能はすべて使えます。

注意点もあります。`VNGenerateForegroundInstanceMaskRequest` は目立つ物が対象なので、背景の物は切り抜けないことがあります。その物は名前だけ出します。物が1つも見つからない写真では、スキャンを省いて状態の表示だけで待ちます。P2 は奥行きだけで動くので、どの写真でも動かせます。

## フォルダ

- `film/`：動画を描くページと書き出しスクリプト
  - ページ：`film.html` + `js/`
    - `core.js`：計算、文字と注音、iOS の部品、写真
    - `tags.js`：アプリと同じ形のタグ（白いカプセル・青い点・ことば・意味）
    - `scan.js`：スキャン各案の共通部分（切り抜きの読み込み、タイミング、状態の表示、NEW）
    - `p1_lift.js` / `p2_depth.js` / `p3_edges.js`：スキャン3案
    - `s1_shadow.js` / `s2_flap.js` / `s3_dots.js`：名前の待ち方3案
    - `picker.js`：言い方の選択
    - `dex.js`：図鑑と着地の演出
    - `concepts.js`：A と D（タップ後）
    - `detail.js`：E（単語の詳細）
  - `masks/`：写真の中の物の切り抜き、輪郭（`outlines.json`）、奥行き（`depth.png`）、エッジ（`edges.png`）、特徴点
    - `masks/tools/`：これらを作ったスクリプト（`seg.py` は OpenCV の GrabCut、`depth.py` は Depth Anything の ONNX 版、`edges.py` は OpenCV）
  - `fonts/`：Noto Sans JP / TC（必要な文字だけにした版）と Inter
  - `cards/`：まとめ動画の見出しカード
  - 書き出し：`render.js`（60fps）、`preview.js`（複数時刻の一覧画像）、`crop.js`（1コマの拡大）、`cues.js`（音のためのタイミング書き出し）
  - `assets/`：写真、カップの切り抜き、図鑑の物の切り抜きと影
- `audio/`：音
  - `audio/tools/mix5.py`：9本のミックス。すべてニ長調で、鳴った場所の左右に置き、-16 LUFS・ピーク -1 dBTP にそろえています。
  - `audio/cues5.json`：動画から書き出した各イベントの時刻
  - `audio/*_cues_v5.json`：各動画の音のイベント一覧（振動の指定つき）
  - `audio/kit3/`：アプリ用の効果音37種と振動パターン8種（v3 のまま使えます）
  - `audio/raw/`：元の音（ElevenLabs で生成した発音・質感など）
- `LATENCY.md`：待ち時間を短くする設計（v3 から変わらず）

## 作り直し方

必要なもの：Python 3.11（numpy、scipy、pyloudnorm、opencv、onnxruntime、fonttools）、Node.js と Playwright（Chromium）、ffmpeg。

```sh
cd docs/design/catch-concepts/film
npm install lottie-web@5.12.2 playwright
# 1. 切り抜き・奥行き・エッジ（作成済み。作り直す場合だけ）
python3 masks/tools/seg.py
python3 masks/tools/depth.py depth_anything_vits14.onnx   # github.com/fabio-sim/Depth-Anything-ONNX の配布物
python3 masks/tools/edges.py
# 2. タイミングを書き出して、音を作る
python3 -m http.server 8765 --bind 127.0.0.1 &
node cues.js
cd ../audio && mkdir -p mixes5 && python3 tools/mix5.py P1 mixes5/P1.wav   # P2 P3 S1 S2 S3 A D E も同様
# 3. 映像（60fps で1コマずつ描いて書き出す）
cd ../film && node render.js P1 P1.mp4 ../audio/mixes5/P1.wav
```

`render.js` などは Chromium の場所を `/opt/pw-browsers/...` に決め打ちしています。別の環境では書き換えてください。

## 使えなかったツール

- **Mobbin**：この作業環境からは接続が拒否されました。参考にしたのは iPhone の写真アプリの「被写体を背景から持ち上げる」動き（iOS 16 以降）です。
- **Rive**：編集画面に入れないため使っていません。
- しずく案で使った Blender のガラスの検証は、案ごと取り下げました。
