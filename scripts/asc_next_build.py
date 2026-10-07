#!/usr/bin/env python3
"""App Store Connect に送るビルド番号を決める（iOS release で使う）。

ビルド番号（CFBundleVersion）は、それまでに送ったどのビルドよりも大きくないと受け付けられない
（「The bundle version must be higher than the previously uploaded version」）。Rork など別の道具から
送ったビルドもあるので、App Store Connect にあるいちばん大きい番号を API で読み、それより 1 大きい数と
「下駄＋実行番号」（MIN）の大きい方を出す。

使い方（環境変数 ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH が必要）:
  asc_next_build.py BUNDLE_ID MIN

どんな失敗でも警告を出し、MIN を出して 0 で終わる（配信そのものは止めない）。標準出力には番号だけを出す。
"""
import sys
import urllib.parse

from asc_dev_certs import API, request


def highest_build(bundle_id: str) -> int:
    apps = request("GET", f"{API}/apps?filter[bundleId]={urllib.parse.quote(bundle_id)}&limit=1").get("data", [])
    if not apps:
        return 0
    best = 0
    url = f"{API}/builds?filter[app]={apps[0]['id']}&fields[builds]=version&limit=200"
    while url:
        data = request("GET", url)
        for b in data.get("data", []):
            first = (b["attributes"].get("version") or "").split(".")[0]
            if first.isdigit():
                best = max(best, int(first))
        url = data.get("links", {}).get("next")
    return best


def main():
    bundle_id, minimum = sys.argv[1], int(sys.argv[2])
    try:
        top = highest_build(bundle_id)
        print(f"App Store Connect のいちばん大きいビルド番号: {top}", file=sys.stderr)
    except Exception as e:  # 権限・通信・鍵の不足など
        print(f"::warning::App Store Connect のビルド番号を読めませんでした（{type(e).__name__}: {e}）", file=sys.stderr)
        top = 0
    print(max(minimum, top + 1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
