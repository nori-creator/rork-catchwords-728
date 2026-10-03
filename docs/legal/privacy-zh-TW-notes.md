# 繁體中文（台湾）のプライバシーポリシー下書き — メモ

## 元の文
- Web のリポジトリ（`/home/user/Lovable-catch-words-app`、GitHub `nori-creator/Lovable-catch-words-app`、手元の最新コミット `e67b63a`）の `src/routes/privacy.tsx`。
- 日本語版は `PrivacyJa()`（40〜112行、最終更新 2026年9月28日、1〜9章）。英語版は `PrivacyEn()`（114〜200行）。
- 訳は日本語版から。条文は足しも削りもしていない。「個人情報」は「個人資料」、「アカウント」は「帳號」、題は「隱私權政策」にした。元の文に法律名は無いので「個人資料保護法」は本文に入れていない。

## Web で zh-TW 版を置く場所
- 同じファイル `src/routes/privacy.tsx` に `PrivacyZhTw()` を足す（`PrivacyJa` / `PrivacyEn` と同じ形の JSX。ファイル冒頭のコメントのとおり、法務文書は `t()` の翻訳キーにせず言語ごとに文書を持つ）。
- `PrivacyPage()`（202〜226行）の 218行 `{lang === "ja" ? <PrivacyJa /> : <PrivacyEn />}` を、`lang === CHINESE_EXPLANATION_LANGUAGE`（`"zh-TW"`、`src/lib/target-lang.ts` 140行）のとき `<PrivacyZhTw />` を出すように変える。
- 213〜215行の「この文書は日本語版と英語版のみです」の注意（`legal.onlyJaEn`、`src/lib/i18n.tsx` 2575行）と、216〜217行のコメント（「正式な訳はまだ無い・機械訳しない」）は、zh-TW 版を出すときに外す。
- 法務文書なので、出す前に台湾の言葉が分かる人（できれば法務）に読んでもらう。利用規約 `src/routes/terms.tsx` も同じ作りなら、同じ扱いが要る。

## 抜け（iOS が集めているのに、ポリシーに書いていないもの）
出典: iOS リポジトリ `docs/self-managing-ios.md` §6-3、`ios/CatchWords/PrivacyInfo.xcprivacy`、pbxproj の権限の説明文、コード。

1. 音声データ（マイク・Apple の音声認識。端末内モデルが無いと Apple のサーバへ送られる）が1章にも4章にも無い。
2. 日記・ひとことメモの本文が1章の「取得する情報」に無い（2章・6章では触れている）。
3. 写真ライブラリから選んだ画像（と写真アプリへの保存）が1章に無い（「撮影した写真」だけ）。
4. iOS の撮影地の地名は Apple（`CLGeocoder`）で取っているが、4章は Google Maps だけ。
5. Apple でサインイン・Google ログインが4章に無い。
6. 7章（Cookie等）がブラウザのローカルストレージだけ。iOS のキーチェーン（ログイン情報）・ウィジェット用の単語・予約した通知・解析待ちの写真の端末内保存が無い。
7. 復習リマインダーの通知（端末で予約）の記載が無い。
8. AI 利用回数（`usage_events`）を1日の上限に使う目的が2章に明記されていない（「不正利用の防止」に含めるかは判断が要る）。
9. 将来: アプリ内課金（StoreKit）を始めるとき、決済の記載が Stripe だけなので Apple を足す必要がある。

逆に、ポリシーにあって iOS 1.0 には無いもの: Stripe の決済、AdMob の広告（iOS の App Store 回答では「追跡なし」「購入なし」）。ポリシーは Web と共通なので、書いてあること自体は問題ではない。
