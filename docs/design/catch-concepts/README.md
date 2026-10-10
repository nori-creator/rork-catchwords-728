# キャッチ演出 4案（コンセプト動画の素材と作り方）

撮った物を単語として図鑑に入れるまでの演出を、4案のコンセプト動画にしたときの素材一式です。
アプリのコードはまだ変えていません。採用する案が決まったら、ここの効果音・振動・Lottie を使って SwiftUI で実装します。

| 案 | 名前 | タップから図鑑に入るまで | 操作 |
|---|---|---|---|
| A | 浮かび上がる（Lift） | 約2.1秒 | タップ1回 |
| B | はがす（Peel） | 約3.0秒 | タップ＋はがす |
| C | その場で即追加（Instant） | 約0.7秒 | タップ1回 |
| D | 図鑑に収まる（Index） | 約2.5秒 | タップ＋確認 |

動画と比較表・音の設計書は Artifact のページにあります（オーナーの claude.ai アカウントで閲覧）。

## フォルダ

- `audio/kit/caf/` … アプリにそのまま入れられる効果音 30 種（48 kHz・CAF）。音量は役割ごとにそろえてあります。
  - UI音 -26 LUFS
  - 動きの音 -24 LUFS
  - フォーリー（実際の物の音） -22 LUFS
  - 合図の音 -21 LUFS
  - 図鑑到着の音 -19 LUFS
- `audio/kit/index.json` … 各音の役割・長さ・用途。
- `audio/kit/haptics/*.ahap` … Core Haptics の振動パターン。動画の音と同じタイミングです（0 秒＝タグをタップした瞬間）。
- `audio/tools/` … 音を作るプログラム。
  - `sfxlib.py`：合成音（ガラスのベル、マリンバ、風切り音、低音）、リバーブ、リミッター
  - `mix.py`：4案のミックス
  - `kit.py`：効果音キットと振動パターンの書き出し
  - `analyze.py` / `music_analyze.py`：聴かずに確かめるための測定
- `audio/raw/` … ElevenLabs で生成した元の音。効果音、音楽 8 テイク（採用は A2・B1・C1・D1）、台湾華語の発音「珍珠奶茶」が入っています。
- `audio/*_cues.json` … 各案で、どの音を何秒に置いたかの一覧。
- `film/` … 動画を描くページ（`film.html`）と、60 fps で書き出すスクリプト（`render.js`）。
  - `film/assets/`：写真と切り抜き
  - `film/lottie/`：Lottie 3 種と、それを作る `gen.py`
  - `film/fonts/`：Noto Sans TC/JP（必要な文字だけ）と Inter。どちらも OFL ライセンスです。

## 音の設計の要点

- すべての音程をニ長調（A=440 Hz）にそろえる。音楽 4 曲もニ長調で、測定でずれは 3 セント以内でした。
- キャッチ音はレ・ファ#・ラの上昇です。図鑑に入る音はラ→レで、主音に戻って「完了」を表します。
- 物が見つかるたびに、レ→ミ→ファ#→ラと音程が上がります。進んでいることが耳で分かる合図です。
- シャッターの瞬間に街の音をこもらせて、意識を写真に向けます（主観の音）。
- 発音が鳴る間は、音楽を約 12 dB、効果音を約 6 dB 下げます（ダッキング）。
- 仕上げは -16 LUFS、ピークは -1 dBTP 以下です。
- アプリ本番では、音楽は流さずに効果音と振動だけを使うことを勧めます。消音モードのときは振動だけにします。
- 日本の iPhone では、OS 標準のシャッター音が必ず鳴ります。

## 作り直し方

前提として、Python 3.11 と numpy、scipy、pyloudnorm、Node.js、Playwright（Chromium）、ffmpeg が必要です。

```sh
cd docs/design/catch-concepts
# 1. 音（4 案のミックスと効果音キット）
python3 audio/tools/mix.py A audio/A.wav   # B / C / D も同様
python3 audio/tools/kit.py
# 2. 映像（film/ をローカルサーバーで配信し、1 コマずつ描いて書き出す）
cd film && npm install lottie-web@5.12.2
python3 -m http.server 8765 --bind 127.0.0.1 &
node render.js A A.mp4 ../audio/A.wav
```

## 生成に使ったもの

ElevenLabs で生成したものは次のとおりです。

- 写真：Seedream 5 Pro で生成し、切り抜きは rembg（isnet）で作りました。
- 効果音：Sound Effects v2
- 音楽：Music v2.5
- 発音：Multilingual v2、ボイスは「Door Chow」（台湾華語）。文字起こしで「珍珠奶茶」と正しく認識されることを確かめました。

使用したクレジットは約 3,200 です。
