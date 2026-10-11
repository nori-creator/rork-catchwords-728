#!/usr/bin/env python3
"""App Store Connect の今の状態を読むだけ（何も書き換えない・審査にも出さない）。

読むもの: アプリの記録（名前・主言語）、App 情報の各言語（名前・サブタイトル・プライバシーポリシーの URL）、
カテゴリ、年齢区分の答え、バージョン（状態・付いているビルド・審査メモの有無）、説明文の各言語（長さ・キーワード・
URL）、スクリーンショットの枚数（画面の大きさごと）、最近のビルド、審査への提出の状態、アプリ内課金の商品。

このリポジトリは公開なので、出力（標準出力と JSON）に個人の情報や秘密は出さない:
審査用アカウントのメール・パスワード、連絡先の名前・電話・メール、審査メモの本文は「入っているか」と長さだけ。

使い方（環境変数 ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH が必要）:
  asc_store_status.py BUNDLE_ID OUT_JSON  > status.md

項目ごとに失敗しても、その旨を書いて先へ進む（0 で終わる）。
"""
import json
import sys
import urllib.error
import urllib.parse

from asc_dev_certs import API, request

API_V2 = API.replace("/v1", "/v2")


def get(url: str):
    return request("GET", url)


def get_all(url: str, cap: int = 400):
    out = []
    while url and len(out) < cap:
        data = get(url)
        out += data.get("data", [])
        url = data.get("links", {}).get("next")
    return out


def attempt(report: dict, key: str, fn):
    """One section; a failure is written down instead of stopping the report."""
    try:
        report[key] = fn()
    except urllib.error.HTTPError as e:
        body = ""
        try:
            body = json.loads(e.read().decode()).get("errors", [{}])[0].get("detail", "")
        except Exception:
            pass
        report[key] = {"error": f"HTTP {e.code}", "detail": body[:300]}
    except Exception as e:  # network, key, shape
        report[key] = {"error": f"{type(e).__name__}: {e}"[:300]}


def filled(v) -> bool:
    return isinstance(v, str) and v.strip() != ""


def main():
    bundle_id, out_json = sys.argv[1], sys.argv[2]
    r: dict = {"bundleId": bundle_id}
    apps = get(f"{API}/apps?filter[bundleId]={urllib.parse.quote(bundle_id)}&limit=1").get("data", [])
    if not apps:
        print(f"# App Store Connect\n\nアプリ `{bundle_id}` が見つかりません（API キーの権限か、バンドル ID を確かめる）。")
        json.dump(r, open(out_json, "w"), ensure_ascii=False, indent=1)
        return 0
    app = apps[0]
    app_id = app["id"]
    a = app["attributes"]
    r["app"] = {k: a.get(k) for k in ("name", "bundleId", "primaryLocale", "contentRightsDeclaration",
                                       "isOrEverWasMadeForKids", "subscriptionStatusUrl")}
    r["app"]["id"] = app_id

    def app_infos():
        infos = []
        for info in get_all(f"{API}/apps/{app_id}/appInfos"):
            ia = info["attributes"]
            item = {"id": info["id"], "state": ia.get("state") or ia.get("appStoreState"),
                    "ageRating": ia.get("appStoreAgeRating"), "kidsAgeBand": ia.get("kidsAgeBand")}
            try:
                item["localizations"] = [
                    {"locale": l["attributes"].get("locale"), "name": l["attributes"].get("name"),
                     "subtitle": l["attributes"].get("subtitle"),
                     "privacyPolicyUrl": l["attributes"].get("privacyPolicyUrl")}
                    for l in get_all(f"{API}/appInfos/{info['id']}/appInfoLocalizations")]
            except Exception as e:
                item["localizations"] = {"error": str(e)[:200]}
            for rel in ("primaryCategory", "secondaryCategory"):
                try:
                    d = get(f"{API}/appInfos/{info['id']}/{rel}").get("data")
                    item[rel] = d["id"] if d else None
                except Exception as e:
                    item[rel] = {"error": str(e)[:120]}
            try:
                d = get(f"{API}/appInfos/{info['id']}/ageRatingDeclaration").get("data")
                item["ageRatingDeclaration"] = d["attributes"] if d else None
            except Exception as e:
                item["ageRatingDeclaration"] = {"error": str(e)[:200]}
            infos.append(item)
        return infos

    attempt(r, "appInfos", app_infos)

    def versions():
        out = []
        for v in get_all(f"{API}/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=10"):
            va = v["attributes"]
            item = {"id": v["id"], "version": va.get("versionString"),
                    "state": va.get("appVersionState") or va.get("appStoreState"),
                    "appStoreState": va.get("appStoreState"), "releaseType": va.get("releaseType"),
                    "copyright": va.get("copyright"), "createdDate": va.get("createdDate")}
            try:
                b = get(f"{API}/appStoreVersions/{v['id']}/build").get("data")
                item["build"] = ({"version": b["attributes"].get("version"),
                                  "processingState": b["attributes"].get("processingState"),
                                  "uploadedDate": b["attributes"].get("uploadedDate"),
                                  "expired": b["attributes"].get("expired")} if b else None)
            except Exception as e:
                item["build"] = {"error": str(e)[:120]}
            try:
                d = get(f"{API}/appStoreVersions/{v['id']}/appStoreReviewDetail").get("data")
                if d:
                    da = d["attributes"]
                    # Never the values themselves: the repository is public.
                    item["reviewDetail"] = {
                        "contactName": filled(da.get("contactFirstName")) and filled(da.get("contactLastName")),
                        "contactPhone": filled(da.get("contactPhone")),
                        "contactEmail": filled(da.get("contactEmail")),
                        "demoAccountRequired": da.get("demoAccountRequired"),
                        "demoAccountName": filled(da.get("demoAccountName")),
                        "demoAccountPassword": filled(da.get("demoAccountPassword")),
                        "notesLength": len(da.get("notes") or ""),
                    }
                else:
                    item["reviewDetail"] = None
            except Exception as e:
                item["reviewDetail"] = {"error": str(e)[:120]}
            locs = []
            try:
                for l in get_all(f"{API}/appStoreVersions/{v['id']}/appStoreVersionLocalizations"):
                    la = l["attributes"]
                    loc = {"locale": la.get("locale"), "descriptionLength": len(la.get("description") or ""),
                           "descriptionStart": (la.get("description") or "")[:80],
                           "keywords": la.get("keywords"), "promotionalText": la.get("promotionalText"),
                           "supportUrl": la.get("supportUrl"), "marketingUrl": la.get("marketingUrl"),
                           "whatsNew": la.get("whatsNew")}
                    shots = []
                    try:
                        for s in get_all(f"{API}/appStoreVersionLocalizations/{l['id']}/appScreenshotSets"):
                            n = len(get_all(f"{API}/appScreenshotSets/{s['id']}/appScreenshots"))
                            shots.append({"displayType": s["attributes"].get("screenshotDisplayType"), "count": n})
                    except Exception as e:
                        shots = {"error": str(e)[:120]}
                    loc["screenshots"] = shots
                    locs.append(loc)
            except Exception as e:
                locs = {"error": str(e)[:200]}
            item["localizations"] = locs
            out.append(item)
        return out

    attempt(r, "versions", versions)

    def builds():
        data = get(f"{API}/builds?filter[app]={app_id}&sort=-uploadedDate&limit=8&include=preReleaseVersion")
        pre = {i["id"]: i["attributes"].get("version") for i in data.get("included", [])
               if i.get("type") == "preReleaseVersions"}
        out = []
        for b in data.get("data", []):
            ba = b["attributes"]
            rel = (b.get("relationships", {}).get("preReleaseVersion", {}).get("data") or {}).get("id")
            out.append({"build": ba.get("version"), "version": pre.get(rel), "processingState": ba.get("processingState"),
                        "uploadedDate": ba.get("uploadedDate"), "expired": ba.get("expired"),
                        "minOsVersion": ba.get("minOsVersion")})
        return out

    attempt(r, "builds", builds)

    def submissions():
        out = []
        for s in get_all(f"{API}/reviewSubmissions?filter[app]={app_id}&filter[platform]=IOS&limit=10", cap=10):
            sa = s["attributes"]
            out.append({"state": sa.get("state"), "submittedDate": sa.get("submittedDate"),
                        "platform": sa.get("platform")})
        return out

    attempt(r, "reviewSubmissions", submissions)

    def purchases():
        out = {"inAppPurchases": [], "subscriptionGroups": []}
        try:
            for p in get_all(f"{API}/apps/{app_id}/inAppPurchasesV2?limit=50"):
                pa = p["attributes"]
                out["inAppPurchases"].append({"productId": pa.get("productId"), "state": pa.get("state"),
                                              "type": pa.get("inAppPurchaseType")})
        except Exception as e:
            out["inAppPurchases"] = {"error": str(e)[:120]}
        try:
            for g in get_all(f"{API}/apps/{app_id}/subscriptionGroups?limit=20"):
                subs = [{"productId": s["attributes"].get("productId"), "state": s["attributes"].get("state")}
                        for s in get_all(f"{API}/subscriptionGroups/{g['id']}/subscriptions?limit=50")]
                out["subscriptionGroups"].append({"name": g["attributes"].get("referenceName"), "subscriptions": subs})
        except Exception as e:
            out["subscriptionGroups"] = {"error": str(e)[:120]}
        return out

    attempt(r, "purchases", purchases)

    def availability():
        d = get(f"{API}/apps/{app_id}/appAvailabilityV2").get("data")
        if not d:
            return None
        terr = get_all(f"{API_V2}/appAvailabilities/{d['id']}/territoryAvailabilities?limit=200&include=territory")
        avail = sorted(t["relationships"]["territory"]["data"]["id"] for t in terr
                       if t["attributes"].get("available"))
        return {"availableInNewTerritories": d["attributes"].get("availableInNewTerritories"),
                "territories": avail, "count": len(avail)}

    attempt(r, "availability", availability)

    json.dump(r, open(out_json, "w"), ensure_ascii=False, indent=1)
    print(markdown(r))
    return 0


def markdown(r: dict) -> str:
    L = ["# App Store Connect の今の状態（読むだけ）", ""]
    app = r.get("app", {})
    L.append(f"- アプリ: {app.get('name')}（`{app.get('bundleId')}`、主言語 {app.get('primaryLocale')}、ID {app.get('id')}）")
    L.append(f"- 他社の素材の宣言（contentRightsDeclaration）: {app.get('contentRightsDeclaration')}")
    infos = r.get("appInfos")
    L += ["", "## App 情報"]
    if isinstance(infos, list):
        for i in infos:
            L.append(f"- 状態 {i.get('state')}、年齢区分 {i.get('ageRating')}、カテゴリ {i.get('primaryCategory')}"
                     f" / {i.get('secondaryCategory')}")
            for l in i.get("localizations") or []:
                if isinstance(l, dict):
                    L.append(f"  - {l.get('locale')}: 名前「{l.get('name')}」 サブタイトル「{l.get('subtitle')}」"
                             f" プライバシーポリシー {l.get('privacyPolicyUrl')}")
            ard = i.get("ageRatingDeclaration")
            if isinstance(ard, dict) and "error" not in ard:
                answers = ", ".join(f"{k}={v}" for k, v in sorted(ard.items()) if v not in (None, "NONE", False))
                L.append(f"  - 年齢区分の答え（NONE / いいえ 以外）: {answers or '（すべて NONE / いいえ）'}")
                unanswered = [k for k, v in sorted(ard.items()) if v is None]
                if unanswered:
                    L.append(f"  - 年齢区分の未回答: {', '.join(unanswered)}")
            elif ard:
                L.append(f"  - 年齢区分の答え: {ard}")
    else:
        L.append(f"- {infos}")
    L += ["", "## バージョン"]
    vs = r.get("versions")
    if isinstance(vs, list):
        for v in vs:
            L.append(f"- {v.get('version')}: 状態 **{v.get('state')}**（{v.get('appStoreState')}）、"
                     f"ビルド {(v.get('build') or {}).get('version') if isinstance(v.get('build'), dict) else v.get('build')}")
            rd = v.get("reviewDetail")
            if isinstance(rd, dict):
                L.append(f"  - 審査の情報: 連絡先の名前 {rd.get('contactName')}・電話 {rd.get('contactPhone')}・"
                         f"メール {rd.get('contactEmail')}、デモアカウント必要 {rd.get('demoAccountRequired')}・"
                         f"ID {rd.get('demoAccountName')}・パスワード {rd.get('demoAccountPassword')}、メモ {rd.get('notesLength')} 字")
            for l in v.get("localizations") or []:
                if isinstance(l, dict):
                    shots = l.get("screenshots")
                    shot_txt = (", ".join(f"{s['displayType']}×{s['count']}" for s in shots)
                                if isinstance(shots, list) else str(shots))
                    L.append(f"  - {l.get('locale')}: 説明 {l.get('descriptionLength')} 字（「{l.get('descriptionStart')}…」）、"
                             f"キーワード「{l.get('keywords')}」、サポート {l.get('supportUrl')}、"
                             f"スクリーンショット {shot_txt or 'なし'}")
    else:
        L.append(f"- {vs}")
    L += ["", "## 最近のビルド"]
    bs = r.get("builds")
    if isinstance(bs, list):
        for b in bs:
            L.append(f"- {b.get('version')} ({b.get('build')}): {b.get('processingState')}、"
                     f"送った日 {b.get('uploadedDate')}、期限切れ {b.get('expired')}、最低 iOS {b.get('minOsVersion')}")
    else:
        L.append(f"- {bs}")
    L += ["", "## 審査への提出"]
    ss = r.get("reviewSubmissions")
    if isinstance(ss, list):
        for s in ss:
            L.append(f"- {s.get('state')}（提出 {s.get('submittedDate')}）")
        if not ss:
            L.append("- なし")
    else:
        L.append(f"- {ss}")
    L += ["", "## アプリ内課金"]
    L.append(f"- {json.dumps(r.get('purchases'), ensure_ascii=False)}")
    L += ["", "## 配信する国・地域"]
    av = r.get("availability")
    if isinstance(av, dict) and "territories" in av:
        L.append(f"- {av['count']} の国・地域: {', '.join(av['territories'])}（新しい国にも自動で: {av.get('availableInNewTerritories')}）")
    else:
        L.append(f"- {av}")
    return "\n".join(L) + "\n"


if __name__ == "__main__":
    sys.exit(main())
