#!/usr/bin/env python3
"""Apple の「開発用」証明書を App Store Connect API で数え・消す（iOS release の後片付け）。

自動署名のアーカイブは、毎回まっさらな GitHub の Mac で「開発用」証明書を 1 枚新しく作る
（秘密鍵が前の実行から残らないため）。消さないと Apple の上限に達し、
「Your account has reached the maximum number of certificates」でアーカイブが止まる。
配布用（Apple Distribution）の証明書には触らない。

消すのは、API キーで作られた開発用証明書（名前に「Created via API」が入るもの。Xcode を API キーで
動かした時にできる）だけ。Mac の Xcode で人が作った証明書には触らない。

使い方（環境変数 ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH が必要）:
  asc_dev_certs.py list                  開発用証明書の一覧を出す
  asc_dev_certs.py snapshot FILE         今ある開発用証明書の ID を FILE に書く
  asc_dev_certs.py delete-ci             API キーで作られた開発用証明書をすべて消す（前の実行の残り）
  asc_dev_certs.py delete-new FILE       FILE に無い（この実行で増えた）、API キーで作られた開発用証明書を消す
  asc_dev_certs.py delete-all            開発用証明書をすべて消す（人が作ったものも。オーナーが選んだ時だけ）

どんな失敗でも警告を出して 0 で終わる（配信そのものは止めない）。

外部のライブラリは使わない（署名は openssl コマンド）。
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"
DEV_TYPES = "DEVELOPMENT,IOS_DEVELOPMENT"
CI_MARK = "Created via API"


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(sig: bytes) -> bytes:
    # ECDSA の DER（30 len 02 len r 02 len s）を JWT の r||s（各 32 バイト）にする
    def read_int(buf, i):
        assert buf[i] == 0x02
        n = buf[i + 1]
        v = buf[i + 2:i + 2 + n]
        return v.lstrip(b"\x00").rjust(32, b"\x00"), i + 2 + n

    i = 2 if sig[1] < 0x80 else 3
    r, i = read_int(sig, i)
    s, _ = read_int(sig, i)
    return r + s


def token() -> str:
    header = {"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"}
    signing_input = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(payload).encode())}"
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", os.environ["ASC_KEY_PATH"]],
        input=signing_input.encode(), capture_output=True, check=True,
    ).stdout
    return f"{signing_input}.{b64url(der_to_raw(der))}"


def request(method: str, url: str):
    req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {token()}"})
    with urllib.request.urlopen(req, timeout=60) as res:
        body = res.read()
        return json.loads(body) if body else None


def dev_certs():
    url = f"{API}/certificates?filter[certificateType]={DEV_TYPES}&limit=200"
    certs = []
    while url:
        data = request("GET", url)
        certs += data.get("data", [])
        url = data.get("links", {}).get("next")
    return certs


def show(c):
    a = c["attributes"]
    return f"{c['id']}  {a.get('certificateType')}  {a.get('displayName') or a.get('name')}  期限 {a.get('expirationDate', '')[:10]}"


def made_by_ci(c):
    a = c["attributes"]
    return CI_MARK in (a.get("displayName") or "") or CI_MARK in (a.get("name") or "")


def delete(certs):
    failed = 0
    for c in certs:
        try:
            request("DELETE", f"{API}/certificates/{c['id']}")
            print(f"消しました: {show(c)}")
        except urllib.error.HTTPError as e:
            failed += 1
            print(f"::warning::開発用証明書を消せませんでした（{e.code}）: {show(c)}")
    return failed


def run(cmd):
    certs = dev_certs()
    print(f"開発用証明書: {len(certs)} 枚（うち API キーで作られたもの {sum(map(made_by_ci, certs))} 枚）")
    for c in certs:
        print("  " + show(c) + ("  [API]" if made_by_ci(c) else ""))
    if cmd == "snapshot":
        with open(sys.argv[2], "w") as f:
            f.write("\n".join(c["id"] for c in certs))
    elif cmd == "delete-ci":
        delete([c for c in certs if made_by_ci(c)])
    elif cmd == "delete-new":
        try:
            with open(sys.argv[2]) as f:
                before = set(f.read().split())
        except FileNotFoundError:
            print("::warning::実行前の一覧が無いので、後片付けをしません")
            return
        new = [c for c in certs if c["id"] not in before]
        for c in new:
            if not made_by_ci(c):
                print(f"人が作ったとみられるので残します: {show(c)}")
        delete([c for c in new if made_by_ci(c)])
    elif cmd == "delete-all":
        delete(certs)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    try:
        run(cmd)
    except urllib.error.HTTPError as e:
        # 権限が足りない API キー（Admin 以外）など。
        print(f"::warning::開発用証明書を扱えませんでした（{e.code}）。API キーの役割が Admin か確かめてください")
    except Exception as e:  # 通信切れ・時間切れ・openssl の失敗・環境変数の不足など。配信そのものは止めない。
        print(f"::warning::開発用証明書を扱えませんでした（{type(e).__name__}: {e}）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
