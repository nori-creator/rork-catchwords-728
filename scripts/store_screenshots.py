#!/usr/bin/env python3
"""iPhone で撮ったスクリーンショットを、App Store Connect が受け付ける大きさにそろえる。

App Store Connect（2026-10 の Screenshot specifications）が iPhone 専用アプリに求める大きさ:
  - 6.1/6.3 インチ（Dynamic Island の中くらいの画面）: 1206 x 2622（または 1179 x 2556）  … 必須
  - 6.9 インチ（Dynamic Island の大きい画面）: 1320 x 2868（または 1290 x 2796 / 1260 x 2736）
    … これが無いと 6.5 インチ（1284 x 2778 / 1242 x 2688）が必須になる
  - 透明（アルファ）の無い PNG か JPEG。1 つの大きさにつき 1〜10 枚。

どの iPhone で撮っても縦横比はほぼ同じ（約 0.46）なので、短い辺に合わせて拡大・縮小し、はみ出した
数ピクセルだけ上下（または左右）を同じだけ切る。文字や画面の中身は変えない。

使い方（Pillow が要る: pip install pillow）:
  store_screenshots.py 入力フォルダ 出力フォルダ
  → 出力フォルダ/6.3/01.png …、出力フォルダ/6.9/01.png … を作る（ファイル名の順に番号を振る）
"""
import os
import sys

from PIL import Image

SIZES = {"6.3": (1206, 2622), "6.9": (1320, 2868)}
EXT = (".png", ".jpg", ".jpeg")


def fit(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    w, h = size
    scale = max(w / img.width, h / img.height)
    resized = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    left = (resized.width - w) // 2
    top = (resized.height - h) // 2
    return resized.crop((left, top, left + w, top + h))


def main():
    src, dst = sys.argv[1], sys.argv[2]
    files = sorted(f for f in os.listdir(src) if f.lower().endswith(EXT))
    if not files:
        print(f"{src} に画像がありません（{', '.join(EXT)}）")
        return 1
    for label, size in SIZES.items():
        os.makedirs(os.path.join(dst, label), exist_ok=True)
    for i, name in enumerate(files, 1):
        img = Image.open(os.path.join(src, name))
        ratio = img.width / img.height
        if img.width > img.height:
            print(f"- {name}: 横向きなので飛ばします（縦の画面だけ）")
            continue
        img = img.convert("RGB")  # no alpha channel (App Store Connect refuses transparency)
        for label, size in SIZES.items():
            out = fit(img, size)
            path = os.path.join(dst, label, f"{i:02d}.png")
            out.save(path, "PNG", optimize=True)
        crop = abs(ratio - SIZES["6.9"][0] / SIZES["6.9"][1]) / ratio
        print(f"- {name}: {img.width}x{img.height} → 6.3 / 6.9（切った量 {crop * 100:.1f}%）")
    print(f"できました: {dst}/6.3 と {dst}/6.9")
    return 0


if __name__ == "__main__":
    sys.exit(main())
