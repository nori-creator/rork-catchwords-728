# 図鑑の影（dexsil-*）の作り方

SF Symbols に合う記号が無い項目の影は、Google の **Noto Color Emoji**（オープンソース。画像は Apache License 2.0、
フォントは SIL Open Font License 1.1）の絵文字の形を白黒のシルエットにして作っている。Apple の絵文字は使っていない。

- 対応表: `emoji_map.py`（項目 id → 絵文字）。合う絵文字が無い「橋」「電線桿」だけは手で描いた形。
- 出力: `ios/CatchWords/Assets.xcassets/DexSilhouettes/dexsil-<id>.imageset`（160×160 の透明 PNG、テンプレート画像。
  アプリ側で影の色に塗る）。
- 作り直す時は Noto Color Emoji のフォントで各絵文字を 109px で描き、アルファ（不透明な部分）だけを取り出して
  144px に収め、しきい値 100 で白黒にする。
