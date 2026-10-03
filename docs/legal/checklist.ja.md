# App Store 提出前の法務・ポリシー チェックリスト（CatchWords）

作成: 2026-10-03／対象: iPhone アプリ `com.nori.catchwords` 1.0.0 と Web 版 https://catchwords.lovable.app

このリストは、法律の専門家ではないオーナーが、App Store に出す前に「何を・どこで・どの順に」やればよいかを並べたものです。

**大事な前提**
- この一式（プライバシーポリシー・利用規約・特定商取引法に基づく表記・このリスト）は、アプリと Web 版のコードを実際に読んで、Apple・個人情報保護委員会・消費者庁・台湾の法令の公式の情報と照らして作りました（10章に出典）。ただし、**これで法的に問題がないと保証するものではありません**。公開前に弁護士に見てもらうことを勧めます（2章）。
- 印の意味: **【済】** アプリ側でもうできている／**【オーナー】** オーナーが自分でやる作業／**【要アプリ変更】** アプリまたは Web 版のコードを直す必要がある（Claude や Lovable に頼める）。

## 0. やる順番（全体の流れ）

1. 事実を埋める（1章）→ 2. 弁護士に見てもらう（2章、推奨）→ 3. コードの必須の変更をする（8章の「必須」）→ 4. Web 版を更新して Publish（`web-patch.md`）→ 5. App Store Connect に入力（3〜7章）→ 6. TestFlight で確認 → 7. 審査に提出。

---

## 1. 事実を埋める 【オーナー】

文書の中の【 】は、オーナーだけが知っている事実です。**作り話で埋めないでください。** 同じ事実は全部の文書で同じ書き方にします（エディタで `【` を検索）。

| 埋める所 | 何を書くか | 出てくる文書 |
|---|---|---|
| 【運営者名】 | 法人ならその名前。個人なら本名（または屋号＋本名）。`docs/self-managing-ios.md` 6-2 の著作権表示は「2026 Noriyuki Kondo」になっているので、それと食い違わないように | 全部 |
| 【代表者氏名】 | 法人の場合の代表者。個人なら「同上」でよい | プライバシー 1章、特商法 |
| 【住所】 | 事業者の住所。個人で自宅を出したくない場合: プライバシーポリシーでは個人情報保護法上の「住所」が必要（※1）。特商法では「請求があれば遅滞なく開示します」と書けば省略できる | プライバシー 1・15章、規約 21条、特商法 |
| 【電話番号】 | 特商法。省略する場合は上と同じ書き方 | 特商法 |
| 【お問い合わせメールアドレス】 | 問い合わせ・開示請求の窓口。**必ず読めるアドレス**（例: support@独自ドメイン）。Gmail でも違法ではないが、専用のアドレスを勧める | 全部 |
| 【サポートページの URL】 | App Store Connect の「サポート URL」にも使う（4章） | 規約 21条 |
| 【制定日】【最終更新日】【改定日】 | 公開する日 | 全部 |
| 【Supabase のデータ保存地域】 | Lovable Cloud（Supabase）のデータがどの国にあるか。Lovable の Cloud の設定画面か Lovable のサポートで確認する。分からないまま「米国」と書かない | プライバシー 6-1 |
| 6-2 の表（任意の提供先） | 実際に使っている AI・読み上げの会社だけを残す。Web 版の設定の開発者欄（「使うAIを切り替える」・読み上げの会社）と Lovable の Secrets に入っている鍵から確かめる（5章の表） | プライバシー 6-2 |
| 【Azure のリージョン】【3D 生成の事業者名・所在国】【typesafe（JEV）の運営会社】 | 使う場合だけ。使わないなら行ごと消す | プライバシー 6-2・6-3 |
| 【3年】【30日】（保存期間） | 問い合わせの保存期間、バックアップが消えるまでの日数。**30日は前のポリシーにあった数字で、Lovable Cloud の実際のバックアップ期間を確かめていない**（Lovable に確認） | プライバシー 9章 |
| 【○○地方裁判所】 | 紛争のときの裁判所。今の Web 版の規約は「東京地方裁判所」。自分の住所に近い地方裁判所にする人が多い | 規約 20条 |
| 【1万円】（無料ユーザーへの賠償の上限） | 弁護士と相談して決める | 規約 14条 |
| 【14日】【30日】 | 規約の変更・サービス終了の予告の日数 | 規約 11・19条 |
| 【980】円【7,800】円 | Web 版（Stripe）の本番の価格（税込）。`docs/monetization.md` の値は「仮の値段」 | 特商法 |
| 無料体験の行 | 無料体験を付けるなら期間、付けないなら行を消す | 特商法、規約 8条 |
| 解約の方法（Web 版） | Stripe の「プランを管理」を作るなら画面の場所、作らないなら「メールで」（8章 W3） | 規約 10条、特商法 |

※1 個人情報保護法 32条は「氏名又は名称及び住所並びに法人にあっては代表者の氏名」を本人が知り得る状態に置くことを求めています（「本人の求めに応じて遅滞なく回答する」方法も認められています）。個人の場合の住所の出し方は弁護士に相談してください。

---

## 2. 弁護士に見てもらうべきか → **見てもらうことを強く勧めます** 【オーナー】

理由（このアプリ特有のもの）:
1. **外国の AI 会社に写真・日記を送る**。個人情報保護法の「外国にある第三者への提供」（28条）は、同意の取り方・情報の出し方が細かく決まっています。このポリシーは「同意をもらう＋国名・制度を示す＋委託先の措置を確認」という慎重な形にしましたが、委託先ごとの契約の確認は専門家の判断が要ります。
2. **消費者契約法**: 「当社は一切責任を負いません」のような条項は無効です（8条）。2023年からは「法令に反しない限り」のようなあいまいな書き方も問題になりえます（8条の3）。規約 13・14条はそれを避けた形にしましたが、金額などの決め方は相談が要ります。
3. **台湾の利用者が中心**: 台湾の個人資料保護法・消費者保護法（オンラインで売るデジタルサービスの解約・返金の決まり）が関わります。繁体字版は台湾の言葉が分かる人（できれば台湾の弁護士）に読んでもらうのが理想です。
4. **未成年**: 日本では18歳未満の契約は親の同意がないと取り消せます（民法5条）。米国の一部の州（ユタ州・ルイジアナ州など）は2026年から、アプリの側にも年齢の確認を求める法律があります（4-3）。
5. 個人で事業をする場合の**住所の出し方**（1章 ※1、特商法）。

頼むときに渡すもの: このフォルダの全ファイル（`privacy-policy.*.md`、`terms.*.md`、`tokushoho.ja.md`、このリスト）。「IT・個人情報に強い弁護士」を探すとよいです。

---

## 3. 文書を公開する場所 【オーナー】

| 文書 | 公開する URL | どこから見えるようにするか | 状態 |
|---|---|---|---|
| プライバシーポリシー（3言語） | https://catchwords.lovable.app/privacy | App Store Connect の「プライバシーポリシー URL」、アプリの ログイン画面・設定・課金画面、Web 版 | 文書は今回作成。Web 版への反映は【オーナー】（`web-patch.md`）。アプリのリンクは【済】（`AuthView.swift:138`、`SettingsView.swift:247`・`274`、`PaywallView.swift:107`） |
| 利用規約（3言語） | https://catchwords.lovable.app/terms | App Store の説明文の最後（4-4）、アプリの ログイン画面・設定・課金画面 | 同上。アプリのリンクは【済】（`AuthView.swift:137`、`SettingsView.swift:246`・`273`、`PaywallView.swift:106`） |
| 特定商取引法に基づく表記 | https://catchwords.lovable.app/tokushoho（新しく作る） | 利用規約のページの末尾（`web-patch.md` で追加）、Web 版の購入画面、アプリの課金画面・設定（8章 A4） | 有料プランを本番で売り始める前に必須。無料だけの 1.0 では急がないが、出しておいて害はない |
| サポートページ | 【サポートページの URL】 | App Store Connect の「サポート URL」 | **まだ無い**（8章 W5）。メールアドレスが載ったページが要る |

---

## 4. App Store Connect に入力すること

### 4-1. App 情報 【オーナー】

| 項目 | 入れる値 |
|---|---|
| プライバシーポリシー URL | `https://catchwords.lovable.app/privacy`（各言語の欄に同じ URL でよい） |
| サポート URL | 【サポートページの URL】（Apple はここに**連絡先**があることを求めます。トップページだけでは連絡先が分からず差し戻されることがある） |
| 使用許諾契約（License Agreement） | **初心者には「Apple の標準 EULA」のまま（何も入れない）を勧めます**。そのうえで説明文の最後に利用規約と標準 EULA のリンクを書く（4-4）。独自の EULA を入れたい場合は `terms.*.md` を入れられますが、その場合は第18条の最後の段落（「なお、本アプリには Apple の標準…」）を消す |
| 著作権 | 【運営者名】と食い違わない表記（例: `2026 【運営者名】`） |
| 販売地域 | 1.0 は **日本・台湾（と、英語圏で出したい国）に絞る**ことを勧める。特に **中国本土は外す**（中国本土の App Store は ICP 届出や生成 AI の手続きが要る）。EU・英国を含める場合は 7-2 を先に。米国を含める場合は 4-3 の年齢の件を確認 |

### 4-2. App のプライバシー（「データの収集」の質問） 【オーナー】

Apple の定義では、**外部の AI 会社など「提携先」が受け取るデータも、アプリが集めたものとして答えます**。追跡（トラッキング）はすべて **いいえ**（他社のデータと結び付けた広告・データブローカーへの提供をしていないため）。

| データの種類（App Store Connect の名前） | 集める？ | ユーザーに関連付け | 目的 | 根拠（コード） |
|---|---|---|---|---|
| 連絡先情報 → メールアドレス | はい | はい | アプリの機能 | ログイン（`SupabaseClient.swift`） |
| 連絡先情報 → 名前 | はい | はい | アプリの機能 | 表示名（プロフィール） |
| ユーザーコンテンツ → 写真またはビデオ | はい | はい | アプリの機能 | 撮影・写真アプリの画像・自撮り。AI 会社にも送る |
| ユーザーコンテンツ → 音声データ | はい（※2） | はい | アプリの機能 | 声で調べる（`SpeechService.swift:46-50`） |
| ユーザーコンテンツ → その他のユーザーコンテンツ | はい | はい | アプリの機能 | 日記・ひとこと・キャプション・復習の答え・誤りの報告・はじめの設定の答え |
| 位置情報 → 正確な位置情報 | はい | はい | アプリの機能 | 撮影地・スキャンの記録の緯度経度（`LocationService.swift`、Web の `scan_events.lat/lng`） |
| 識別子 → ユーザ ID | はい | はい | アプリの機能 | アカウントの ID |
| 使用状況データ → 製品の操作 | はい | はい | アプリの機能、分析 | 利用回数・画面・`usage_events`（運営者の利用者画面でも見る） |
| 検索履歴 | **はい（追加を推奨）** | はい | アプリの機能、分析 | スキャンで見つけた・押した単語が `scan_events` に残る。今の回答（`docs/self-managing-ios.md` 6-3）と `PrivacyInfo.xcprivacy` には無い（8章 A6） |
| 購入 → 購入履歴 | 1.0 は いいえ／**アプリ内課金を出す版から はい** | はい | アプリの機能 | StoreKit（`PlanStore.swift`） |
| 診断 | いいえ | — | — | iPhone アプリに不具合報告の部品は入っていない（Web 版のエラー記録は iPhone アプリの回答には含めない） |
| 連絡先・健康・財務情報・ブラウザ履歴・機密情報・その他の識別子（広告 ID など） | いいえ | — | — | 使っていない |

※2 音声そのものは Apple の音声認識にだけ渡り、当社のサーバには文字だけが届きます。Apple 自身への送信は「提携先」に当たらないと考えて「いいえ」にする判断もありえますが、今のアプリの回答・`PrivacyInfo.xcprivacy` は「はい」なので、**控えめな（多めに答える）側の「はい」のままを勧めます**。

アプリの中の `ios/CatchWords/PrivacyInfo.xcprivacy` も、上の表と同じ内容にそろえます（検索履歴・購入履歴を足すときは両方）。ウィジェットの `ios/CatchWordsWidgets/PrivacyInfo.xcprivacy` は何も集めないので今のままでよい【済】。

### 4-3. 年齢制限指定（2025〜2026年の新しい質問） 【オーナー】

Apple は 2025年に年齢区分を 4+ / 9+ / 13+ / 16+ / 18+ に変え、新しい質問（アプリ内の管理機能、機能、医療・ウェルネス、暴力的なテーマ）を必須にしました。2026年9月からは「ソーシャルメディア」の質問も必須です。このアプリの答え:

| 質問 | 答え | 理由 |
|---|---|---|
| 下品な言葉・ホラー・アルコール等・性的な内容・暴力・武器（すべての頻度の質問） | なし | 学習アプリ。AI が作る例文も一般的な内容 |
| 医療・治療の情報／健康・ウェルネスの話題 | なし | |
| ギャンブル・疑似ギャンブル・コンテスト・ルートボックス | なし | |
| ペアレンタルコントロール | いいえ | |
| 年齢の確認（Age Assurance） | いいえ | |
| 制限のない Web アクセス | いいえ | アプリ内ブラウザで自由にサイトを見る機能はない（Google 画像検索などのリンクは Safari で開く） |
| ユーザー生成コンテンツ | いいえ | 写真・日記は本人だけが見る。みんなの投稿の機能は 2026-10-01 にコードごと削除済み（Web の `src/lib/features.ts`）。**投稿機能を復活させたら「はい」にし、通報・ブロック・フィルタの仕組みが必要（審査ガイドライン 1.2）** |
| ソーシャルメディア／メッセージとチャット | いいえ | |
| 広告 | いいえ | iPhone アプリ 1.0 に広告の部品はない（AdMob は未導入） |

→ 計算上は **4+** になります。ただし利用規約は「13歳未満は利用不可」なので、**App Store Connect で年齢区分を自分で 13+ に上げる**ことを勧めます（Apple は、アプリの方針がより高い年齢を求める場合に引き上げを認めています）。4+ のままにするなら、規約の年齢の決まりとの食い違いを弁護士と相談してください。「Kids カテゴリ」には**入れない**（子ども向けの厳しい決まりがあり、外部 AI への送信と両立しない）。

米国のユタ州（2026-05-06〜）・ルイジアナ州（2026-07-01〜）では、新しいアカウントについて Apple の Declared Age Range API で年齢区分を受け取ることなどが求められます。米国でも配信する場合は弁護士に確認し、必要なら対応する（8章 A9）。

### 4-4. サブスクリプション（アプリ内課金を出す版から） 【オーナー】＋【要アプリ変更】

1.0 は無料だけ（`PlanStore.paywallEnabled = false`、`PlanStore.swift:16`）なので、次は**課金を始める版**で必要です。

**アプリの課金画面に必要なもの（Apple の「サブスクリプション」ページ・審査ガイドライン 3.1.2）**

| 必要なもの | 状態 |
|---|---|
| サブスクリプションの名前と期間、その間に何が使えるか | 【済】「年額プラン／月額プラン」「1年ごと／1か月ごとに自動更新」（`PaywallView.swift:171`・`181`）、特典の一覧（`PaywallView.swift:18-28`）。App Store Connect の商品の表示名と同じ言葉にそろえる【オーナー】 |
| 更新時の価格（実際に請求される額）がいちばん目立つこと | 【済】請求額が 17pt 太字（`PaywallView.swift:190`）、月あたりの額は 12pt の小さい字（`PaywallView.swift:184`） |
| 購入の復元 | 【済】（`PaywallView.swift:104`） |
| 自動更新・請求の時期・解約の方法の説明 | 【済】（`PaywallView.swift:111`）。ただし 10pt で薄い色（`PaywallView.swift:112-113`）。読みにくいと差し戻されることがあるので 12pt 以上を勧める（8章 A3） |
| 利用規約・プライバシーポリシーへのリンク | 【済】（`PaywallView.swift:106-107`） |
| 無料体験を付ける場合: 期間と、終わった後の価格 | 【要アプリ変更】今の画面は無料体験を表示しない（`PaywallView.swift:157-191`）。体験を付けるなら表示を足す |
| 特定商取引法の「最終確認画面」の表示（分量・価格・支払の時期と方法・提供時期・解約の方法） | ほぼ【済】（上の各項目）。特商法の表記へのリンクを足すのを推奨（8章 A4） |

**App Store の説明文（各言語）の最後に入れる文（例）**

```
利用規約: https://catchwords.lovable.app/terms
プライバシーポリシー: https://catchwords.lovable.app/privacy
Apple 標準使用許諾契約（EULA）: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

（英語・繁体字の説明文にも同じ3行を、その言語の見出しで入れる。独自の EULA を App Store Connect に入れた場合は 3行目は不要。）

その他、課金を始める前にやること（`docs/self-managing-ios.md` 7章とも重なる）: 有料アプリ契約・税・口座【オーナー】、サブスクリプションの商品と審査用スクリーンショット【オーナー】、サーバでの Apple の購入の確認（7-2）【要アプリ変更】、特商法の表記の公開【オーナー】。

### 4-5. 審査メモ（App Review Information） 【オーナー】

`docs/self-managing-ios.md` 6-4 の文に、次を足して英語で書くのが確実です。

```
Demo account: (email) / (password)   ← 審査専用のアカウントを作り、写真がいくつか入った状態にしておく

- Sign in with Apple / Google: done on our website (catchwords.lovable.app/native-auth) inside
  ASWebAuthenticationSession, then the app receives the session.
- Account deletion: Settings > Delete account (type "DELETE"). It deletes the server account and all data.
- AI: photos and text are sent to third-party AI (Google Gemini via our server) only after the user agrees
  on the consent screen shown before the first AI feature. Details: Privacy Policy section 4 and 6.
- No in-app purchases in this version. / (課金を出す版では) Subscriptions: ...
- Location is optional and used only to record where a photo was taken and for place reminders.
```

「AI の同意画面」の行は、8章 A1 を入れてから書く（入れる前に書くと事実と違う）。

### 4-6. 輸出コンプライアンス（暗号化） 【済】

`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`（`ios/CatchWords.xcodeproj/project.pbxproj:515`・`557`）。アプリが使う暗号は OS の HTTPS とキーチェーンだけで、Apple の説明では免除の対象なので「いいえ」で正しい。提出のたびに暗号の質問は出ない。独自の暗号の仕組みを入れたら見直す。

---

## 5. 外部に送っているデータの一覧（コードから確認した事実）

Web 版のサーバ（iPhone アプリの AI・保存も `/api/native-fn` で同じサーバを通る）と iPhone アプリのコードを読んで確認しました。**AI と読み上げの会社は、Web 版の設定の開発者欄（`app_config` の `ai_models` / `tts_voice`）や環境変数で、再デプロイなしに切り替えられる**作りです（`src/lib/ai-provider.server.ts:38-60`・`109-143`、`src/lib/tts-providers.ts`）。ポリシーに書いていない会社に切り替えると、ポリシーと事実が食い違います。

| 会社 | 国 | 受け取るもの | 使う所（コード） | 今使っているか |
|---|---|---|---|---|
| Supabase（Lovable Cloud） | 米国（保存地域は要確認） | すべてのデータ | `AppConfig.swift:25`、Web 全体 | 使っている |
| Lovable（Lovable Labs Sweden AB／Lovable Labs Inc.） | スウェーデン／米国 | サーバを通る通信、AI の中継、ログインの中継、Web のエラー記録 | `ai-provider.server.ts:22`（AI Gateway）、`@lovable.dev/cloud-auth-js`、`lovable-error-reporting.ts` | 使っている |
| Google（Gemini） | 米国 | 写真・文章 | 既定のモデル `google/gemini-3-flash-preview`（`ai-provider.server.ts:25`） | 既定で使う |
| Google（Cloud Text-to-Speech） | 米国 | 読み上げる文字（最大400字） | `tts.functions.ts:67` | 鍵があれば使う |
| Google（Maps） | 米国 | 緯度経度（Web 版） | `geocode.functions.ts:35`、`DexDayMap.tsx:602` | Web 版で使う |
| Google（ログイン） | 米国 | 認証 | `AuthView.swift:31` | 使っている |
| Apple | 米国 | Apple でログイン、音声認識、地名（`CLGeocoder`）、アプリ内課金 | `AuthView.swift:56`、`SpeechService.swift:50`、`LocationService.swift:44`、`PlanStore.swift` | 使っている（課金は未公開） |
| Stripe | 米国 | メール、ユーザー ID、決済 | `billing.functions.ts:89` | テスト用のみ（本番の鍵はまだ） |
| OpenAI / Anthropic / OpenRouter | 米国 | 写真・文章 | `ai-provider.server.ts:115-142` | 切り替え候補 |
| DeepSeek | **中国** | 写真・文章 | `ai-provider.server.ts:123-127` | 切り替え候補 |
| Kimi（Moonshot AI） | **中国** | 写真・文章 | `ai-provider.server.ts:128-132` | 切り替え候補 |
| Azure / ElevenLabs | 米国 | 読み上げる文字 | `tts-providers.ts` | 切り替え候補 |
| MiniMax | **中国**（国際版の運営会社は要確認） | 読み上げる文字 | `tts-providers.ts:87` | 切り替え候補 |
| Tripo3D（VAST） | 要確認（中国の会社とされる） | 写真（Pro の 3D、試作） | `object3d.ts:108` | 試作・鍵があれば |
| Higgsfield / Unsplash / Wikimedia / typesafe（JEV） | 米国など | 単語の文字列だけ | `image-provider.ts`、`images.functions.ts:53`、`jev.functions.ts` | 鍵があれば（個人情報は送らない） |
| Google AdMob | 米国 | — | `ad-policy.ts`（決まりだけで、部品は未導入） | 使っていない → **ポリシーから外した** |

**オーナーへのお願い**: 実際に使う会社を決め、それ以外は `app_config` で選べないようにするか、少なくとも使わない。**台湾の利用者が中心なので、中国本土の会社（DeepSeek・Moonshot・MiniMax・中国の 3D 生成など）に写真や日記を送る設定は使わないことを強く勧めます**（台湾の利用者の信頼、日本の個人情報保護法上の外国の制度の説明、どちらでも大きな負担になる）。使う場合は、ポリシー 6-2・6-4 に足し、利用者の同意を取り直します。

Gemini を Google の API で直接使う場合（`AI_PROVIDER=google`）、**無料枠では Google が入力をサービス改善に使うことがある**ので、有料の枠で使う【オーナー】（Google の Gemini API の利用規約で確認）。ポリシー 4章は「学習に利用しない条件の契約・設定で利用するよう努めます」と書いています。

---

## 6. アカウント削除・Apple でサインイン

| 項目 | 状態 |
|---|---|
| アプリの中でアカウントを削除できる（審査ガイドライン 5.1.1(v)） | 【済】設定 → アカウントを削除（`SettingsView.swift:303-346`）→ サーバの `deleteMyAccount`（Web `src/lib/profile.functions.ts:286`）。写真・行のデータ・ログインのアカウントを消し、端末の写真待ち・通知・ウィジェット・日記の下書きも消す（`AccountCleanup.swift:24-50`） |
| アバター画像も消えるか | **【要アプリ変更】消えていない**。`deleteMyAccount` は `stickers` の写真だけを消し（`profile.functions.ts:294-305`）、公開バケット `avatars` の `${userId}/avatar-…`（`profile.functions.ts:221`）が残り、URL を知っていれば見られる（8章 W2、`web-patch.md` 7章にコード） |
| 削除の前に「サブスクは Apple で続く」と知らせる | 1.0 は課金がないので不要。**課金を出す版で【要アプリ変更】**（`SettingsView.swift:321` の説明文に足し、解約画面へのリンクを置く。Apple の「アカウント削除」ページの要件） |
| Apple でサインイン（審査ガイドライン 4.8） | 【済】Google と並べて「Appleでサインイン」がある（`AuthView.swift:46-69`）。Web の `/native-auth` を `ASWebAuthenticationSession` で通る方式（`AppConfig.swift:23` で端末内の方式はオフ） |
| Apple でサインインしたアカウントを消すとき、Apple のトークンを取り消す | **【要確認／要アプリ変更】** Apple は「Sign in with Apple を使うアプリは、削除のときに REST API でトークンを取り消すべき」としている（TN3194）。今のサーバは取り消していない。Lovable Cloud（Supabase）の Apple ログインで取り消しができるかを Lovable に確認し、できなければ弁護士・開発者と相談（8章 W6）。審査で必ず指摘される項目ではないが、Apple の公式の推奨 |
| Apple ボタンの見た目 | 自作のボタン（`AuthView.swift:56-68`、黒地に白の Apple マーク）。Apple のガイドライン（Human Interface Guidelines の Sign in with Apple）の形・文言に合っているか、差し戻されたら `SignInWithAppleButton` の見た目にする |

---

## 7. 地域ごとの追加の確認

### 7-1. 日本 【オーナー】
- 個人情報保護法 32条の公表事項（名称・住所・代表者・利用目的・開示等の手続・安全管理措置・苦情の窓口）→ ポリシー 1・3・10・11・15章に入れた。【 】を埋めれば揃う。
- 外国にある第三者への提供（28条）→ ポリシー 6章（国名・制度・措置）＋ AI の同意（4章、8章 A1）。
- 特定商取引法 → `tokushoho.ja.md`。最終確認画面 → アプリの課金画面はほぼ済、**Web 版の購入ボタンの前の表示が無い**（8章 W4）。
- 電気通信事業法の「外部送信規律」: Web 版は Google Maps の部品や Lovable のエラー記録の仕組みで、利用者の端末から外部に情報が送られます。対象の事業に当たるか、当たる場合はポリシー 6章で足りるかを弁護士に確認。
- 未成年: 規約 2条（13歳未満不可、18歳未満は親の同意）。

### 7-2. EU・英国（配信する場合だけ） 【オーナー】
- ポリシー 13-2 に GDPR の法的根拠・権利を入れた。
- **EU 内の代理人（GDPR 27条）**: EU に拠点がなく EU の人に継続的にサービスを提供する場合、原則として置く必要がある（例外あり）。1.0 は EU・英国を配信地域から外すのがいちばん簡単。
- EU の消費者には、デジタルサービスの14日の撤回権がある（Stripe で売る場合）。売る前に確認。

### 7-3. 台湾 【オーナー】
- 個人資料保護法 8条の告知事項 → ポリシー 13-1（名称・目的・種類・期間・地域・対象・方式・権利・提供しない場合の影響）。
- 消費者保護法（オンラインで売る場合の7日の解除権と、デジタルの例外）→ Stripe で台湾の人に売る前に確認。Apple のアプリ内課金は Apple の返金の決まりによる。

### 7-4. 米国・子ども
- COPPA（13歳未満の子どもの情報）: 子ども向けではなく、規約で13歳未満を禁止。年齢区分 13+ を推奨（4-3）。
- ユタ州・ルイジアナ州の年齢確認の法律（4-3）。

---

## 8. アプリ側・Web 側の変更が必要な項目（ギャップの一覧）

「必須」= 1.0 の審査・法律の上で入れておくべきもの。「課金時」= アプリ内課金を出す版で必須。「推奨」= 入れた方が安全。

### iPhone アプリ（このリポジトリ）

| # | 重要度 | 内容 | 場所 |
|---|---|---|---|
| A1 | **必須** | **外部 AI に送る前の同意の画面が無い**。審査ガイドライン 5.1.2(i) は「第三者の AI を含め、個人データを第三者と共有する場所をはっきり示し、共有の前に明示的な許可を得る」ことを求めている（2025年に追加された文言）。初めて AI の機能（撮影の候補・スキャン・日記の添削・単語帳の読み取りなど）を使う前に、「写真と文章を Google（Gemini）などに送ります」と示して「同意して続ける」を押してもらう。同意の状態はサーバに保存して Web と共有する（W1）。同意しない人は AI の機能を使えない形にする | AI を呼ぶ入口 `ios/CatchWords/Services/NativeAPI.swift:61`（`suggestWordCandidates`・`generateCard`・`correctMyJournal` など）。はじめの設定の段階 `Views/OnboardingView.swift:14`（`intro, questions, notifications, ready` の間に同意の段階を足すのが分かりやすい） |
| A2 | **必須** | ログイン画面に、利用規約とプライバシーポリシーへの**同意の一文が無い**（リンクだけ）。「続けると、利用規約とプライバシーポリシーに同意したことになります」をボタンの近くに | `Views/AuthView.swift:131-139` |
| A3 | 推奨（課金時は強く推奨） | 自動更新の説明が 10pt・薄い色で読みにくい | `Views/PaywallView.swift:111-113` |
| A4 | 課金時 | 課金画面・設定に「特定商取引法に基づく表記」へのリンクが無い（`https://catchwords.lovable.app/tokushoho`） | `Views/PaywallView.swift:103-108`、`Views/SettingsView.swift:271-275` |
| A5 | **必須** | 設定に**お問い合わせ（サポート）への入口が無い**。ポリシー・規約は「アプリ内サポート」と書いていたが、そのような機能は無い（今回の文書はメールを窓口にした）。設定の「このアプリについて」に「お問い合わせ」（`mailto:` かサポートページ）を足す | `Views/SettingsView.swift:243-252`（`legalSection`）、課金版は `proSection` `SettingsView.swift:254-281` |
| A6 | 推奨 | プライバシーマニフェストに「検索履歴」（`NSPrivacyCollectedDataTypeSearchHistory`）を足す（4-2）。課金を出す版で「購入履歴」（`NSPrivacyCollectedDataTypePurchaseHistory`）も | `ios/CatchWords/PrivacyInfo.xcprivacy:12` の配列 |
| A7 | 推奨 | 位置情報の説明文が「撮った場所の地名を記録」だけで、「場所でリマインド」（撮った場所の近くで通知、`ReminderService.swift:185-192`）に触れていない。審査ガイドライン 5.1.1 は用途をはっきり書くことを求める | `ios/CatchWords.xcodeproj/project.pbxproj:520`・`562`、`ios/CatchWords/Resources/{ja,en,zh-Hant}.lproj/InfoPlist.strings:5` |
| A8 | 課金時 | アカウント削除の説明に「Apple のサブスクは続くので先に解約を」と、解約画面へのリンク（`showManageSubscriptions` または `https://apps.apple.com/account/subscriptions`）を足す | `Views/SettingsView.swift:321` |
| A9 | 米国で配信する場合 | ユタ州・ルイジアナ州向けの Declared Age Range API の対応（4-3） | 新規 |
| A10 | 課金時 | 無料体験を付ける場合、その期間と終了後の価格の表示 | `Views/PaywallView.swift:157-191` |

### Web 版（Lovable。このリポジトリからは直せない）

| # | 重要度 | 内容 | 場所 |
|---|---|---|---|
| W0 | **必須** | 法務ページを新しい文書に置き換える（`web-patch.md`）。今の Web 版のポリシーは、音声・Apple・日記の取得・キーチェーン・ウィジェット・通知・利用回数・保存期間・開示請求・安全管理措置・外国の国名が抜けていて、もう無い「公開投稿」と、入っていない AdMob が書いてある | `src/routes/privacy.tsx`、`src/routes/terms.tsx`、新規 `src/routes/tokushoho.tsx` |
| W1 | **必須** | AI の同意の記録（A1 のサーバ側）。同意した日時とポリシーの版を保存し、同意していない人の AI の関数をサーバで断る。Web の画面にも同じ同意画面（ログインしない体験 `first-catch` でも、写真を送る前に同意の表示） | `src/lib/ai.functions.ts`、`src/lib/first-catch-guest.server.ts`、`src/routes/auth.tsx` |
| W2 | **必須** | アカウント削除でアバター画像（公開バケット `avatars`）を消していない | `src/lib/profile.functions.ts:286-305`（コードは `web-patch.md` 7章） |
| W3 | 本番の Stripe の前に必須 | Web の有料プランの**解約の入口が無い**（Stripe のカスタマーポータルなど）。特商法・規約 10条の「解約の方法」と合わせる | `src/routes/_authenticated/settings.tsx:1743`（`ProPlanCard`）、`src/lib/billing.functions.ts` |
| W4 | 本番の Stripe の前に必須 | 購入ボタンの前に、価格・自動更新・請求の時期・解約の方法・特商法と規約へのリンクが無い（特商法 12条の6 の最終確認画面）。今はボタンの「月ごとで始める」「年ごとで始める」だけ | `src/routes/_authenticated/settings.tsx:1764-1791`、文言は `src/lib/i18n.tsx:3152-3170` |
| W5 | **必須** | サポートページ（連絡先のメールアドレスが分かるページ）。App Store Connect のサポート URL に使う | 新規（例 `src/routes/support.tsx`） |
| W6 | 推奨 | Apple でサインインのトークンの取り消し（6章） | `src/lib/profile.functions.ts:286` |
| W7 | 推奨 | ログインしない体験の回数を数える行（`app_config` の `first-catch-budget:日付:ip:ハッシュ`）が消されずに溜まる。ポリシーは「その日の制限のためにのみ使用」と書いたので、古い日付の行を定期的に消す | `src/lib/first-catch-guest.server.ts:13-30`・`72-77` |
| W8 | 推奨 | `scan_events`・`usage_events` に保存期間がない（アカウント削除まで残る）。ポリシーはそのとおり書いたが、例えば「2年で消す」にすると安全 | Supabase の定期処理 |
| W9 | 課金時 | Apple の購入をサーバで確かめる仕組み（`docs/self-managing-ios.md` 7-2）。ポリシー 8章の「Apple から購入の記録を受け取り、アカウントと結び付けます」はこれを前提にしている | 新規 |
| W10 | 推奨 | AI の会社を `app_config` で選べる範囲を、ポリシーに書いた会社だけに制限する（5章） | `src/lib/ai-provider.server.ts:109-143`、`src/lib/tts-providers.ts` |

---

## 9. 主な法的リスク（大きい順）

1. **AI への送信の同意が無いまま出す**（A1・W1）: Apple の審査ガイドライン 5.1.2(i) に反して差し戻される可能性が高い。日本の個人情報保護法でも、外国の AI 会社への提供の扱いが問題になりうる。
2. **ポリシーと実際の動きの食い違い**: AI の会社を管理画面で切り替えられる作り（5章）。書いていない会社（特に中国の会社）に切り替えると、ポリシー違反・同意の範囲外になる。アバターが削除後も残る（W2）のも「削除します」と食い違う。
3. **連絡先・事業者の情報が空**: 個人情報保護法 32条の公表事項、特商法の表示、Apple のサポート URL のどれも、【 】を埋めないと満たせない。「アプリ内サポート」は存在しなかった。
4. **Web の有料プラン**（W3・W4）: 解約の入口と最終確認画面の表示がないまま本番の Stripe にすると、特商法 12条の6（違反には行政処分・罰則がある）・消費者トラブルの原因になる。
5. **年齢**: 規約は13歳以上なのに年齢区分 4+・年齢の確認なし。米国の州法（ユタ・ルイジアナ）。日本では未成年の契約の取り消し。
6. **EU・英国・中国本土での配信**: GDPR の代理人、中国本土の ICP・生成 AI の手続き。1.0 は配信地域を絞るのが安全。
7. **AI の内容の誤り**: 規約 4条で注意と安全に関わる使い方の禁止を書いたが、責任をすべて免れるわけではない（消費者契約法）。

---

## 10. 確認した公式の情報（2026-10-03 時点）

Apple
- App Store 審査ガイドライン（1.2、1.3、3.1.1、3.1.2、4.8、5.1.1(i)(ii)(v)、5.1.2）: https://developer.apple.com/app-store/review/guidelines/ （5.1.2(i) の「第三者の AI を含め…明示的な許可」の文言を確認）
- アカウント削除の要件（サブスクの案内、Sign in with Apple のトークン取り消し）: https://developer.apple.com/support/offering-account-deletion-in-your-app/
- Sign in with Apple のトークン取り消し（TN3194）: https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple
- 自動更新サブスクリプション（課金画面に必要な表示、説明文の利用規約・プライバシーのリンク）: https://developer.apple.com/app-store/subscriptions/
- 年齢区分の新しい質問と値: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/ 、https://developer.apple.com/news/?id=ks775ehf
- ソーシャルメディアの質問（2026年9月から必須）: https://developer.apple.com/news/?id=tlur8uvi
- ブラジル・オーストラリア・シンガポール・ユタ州・ルイジアナ州の年齢の要件: https://developer.apple.com/news/?id=f5zj08ey
- 独自 EULA の最低条件（Minimum Terms）: https://www.apple.com/legal/internet-services/itunes/dev/minterms/ （このページは作業環境から直接開けなかったため、検索結果の要約と既知の条文で照合。第18条は弁護士に原文と照らしてもらう）
- Apple 標準 EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- 暗号化の輸出規制: https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations

日本
- 個人情報保護委員会 ガイドライン（通則編）: https://www.ppc.go.jp/personalinfo/legal/guidelines_tsusoku/
- 同（外国にある第三者への提供編）: https://www.ppc.go.jp/personalinfo/legal/guidelines_offshore/
- 同意に基づく外国第三者提供の留意点（Q&A）: https://www.ppc.go.jp/all_faq_index/faq2-q5-8/
- 外国制度の調査（米国）: https://www.ppc.go.jp/enforcement/infoprovision/laws/offshore_report_america/ （中国: https://www.ppc.go.jp/enforcement/infoprovision/laws/offshore_report_china/ ）
- 消費者庁 通信販売の申込み段階における表示についてのガイドライン（最終確認画面）: https://www.no-trouble.caa.go.jp/what/mailorder/guidelines.html
- 消費者庁 通信販売広告 Q&A（住所・電話番号の省略）: https://www.no-trouble.caa.go.jp/qa/advertising.html
- 総務省 外部送信規律: https://www.soumu.go.jp/main_sosiki/joho_tsusin/d_syohi/gaibusoushin_kiritsu.html
（個人情報保護委員会のサイトは作業環境から直接開けなかったため、検索結果の要約で照合しました。）

台湾
- 個人資料保護法 第8條（告知事項）: https://law.moj.gov.tw/LawClass/LawSingle.aspx?flno=8&pcode=I0050021 、全文: https://law.moj.gov.tw/LawClass/LawAll.aspx?PCode=I0050021

その他
- Lovable のプライバシーポリシー・データ処理契約（Lovable Labs Sweden AB がスウェーデンの事業者）: https://lovable.dev/privacy 、https://lovable.dev/data-processing-agreement

---

## 付記: このフォルダのファイル

| ファイル | 内容 |
|---|---|
| `privacy-policy.ja.md` / `.en.md` / `.zh-TW.md` | 新しいプライバシーポリシー（3言語、同じ章立て）。前の `privacy-zh-TW-draft.md` / `privacy-zh-TW-notes.md` はこれに置き換えた（ノートの9つの抜けはすべて反映） |
| `terms.ja.md` / `.en.md` / `.zh-TW.md` | 新しい利用規約（Apple の独自 EULA の最低条件を第18条に含む） |
| `tokushoho.ja.md` | 特定商取引法に基づく表記 |
| `web-patch.md` | Web 版への反映の手順と全コード |
| `web/privacy.tsx` `web/terms.tsx` `web/tokushoho.tsx` | Web 版にそのまま置ける完成ファイル（`web-patch.md` の付録と同じ内容） |
