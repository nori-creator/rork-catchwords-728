# App Store 提出前の法務・ポリシー チェックリスト（CatchWords）

作成: 2026-10-03（同日、Web 版 main 11ff3f0 の実際の状態に合わせて書き直し）／対象: iPhone アプリ `com.nori.catchwords` 1.0.0 と Web 版 https://catchwords.lovable.app

このリストは、法律の専門家ではないオーナーが、App Store に出す前に「何を・どこで・どの順に」やればよいかを並べたものです。

**大事な前提**
- **法務の頁は Web 版にもうあります**（`/privacy`・`/terms`・`/legal/tokushoho`、3言語）。前の版のこのリストは古い Web の写しを見て「頁を新しく作る」前提で書いていましたが、それは間違いでした。今やるのは、(1) 運営者の情報を **Lovable の Secrets（`LEGAL_*`）に入れる**、(2) iPhone アプリの扱いなどを足す**差分を当てる**（`web-patch.md`）、(3) 再公開する、の3つです。
- 文書は、アプリと Web のコードを実際に読み、Apple・個人情報保護委員会・消費者庁・台湾の法令の公式の情報と照らして作りました（9章に出典）。ただし、**これで法的に問題がないと保証するものではありません**。公開前に弁護士に見てもらうことを勧めます（2章）。
- 印の意味: **【済】** できている／**【オーナー】** オーナーが自分でやる作業／**【要コード】** アプリまたは Web のコードを直す必要がある（Claude に頼める）。
- 監査の指摘番号（F-01・B-01 など）は `docs/launch-audit/2026-10-03-0900-baseline.md` の物です。

## 0. やる順番（全体の流れ）

1. Lovable の Secrets に `LEGAL_*` を入れる（1章）→ 2. `legal.patch` を Web の main に当てる（`web-patch.md`）→ 3. Lovable で Publish → Update → 4. curl で確かめる（`web-patch.md` 5章）→ 5. 審査用アカウントを作る（3章）→ 6. App Store Connect に入力（4章）→ 7. TestFlight の版で実機の流れを通して記録（5章）→ 8. 審査に提出。弁護士の確認（2章）は 1 の前か、遅くとも 8 の前。

---

## 1. Lovable の Secrets に運営者の情報を入れる 【オーナー】（F-01 Blocker・F-02 Major）

今、公開中のプライバシーポリシー第12条・利用規約第12条には「運営者の連絡先は現在準備中です」、特商法の頁には「この表記は準備中です」と出ています。原因は Secrets が空なことだけです（`src/lib/legal-config.ts`）。**文書の本文に名前や住所を書き込む作業はありません。**

場所: Lovable でプロジェクトを開く → **Cloud → Secrets** →「追加」。チャットには貼らない。

| 名前 | 必須 | 入れる物 | 出る所 |
|---|---|---|---|
| `LEGAL_SELLER_NAME` | ✓ | 個人なら戸籍上の氏名（または登記した商号）、法人なら名称。`docs/self-managing-ios.md` 6-2 の著作権表示（「2026 Noriyuki Kondo」）や App Store の販売者名と食い違わないように | ポリシー・規約の「運営者」、特商法の販売事業者、サポートの頁 |
| `LEGAL_EMAIL` | ✓ | 問い合わせ・開示請求・苦情の窓口。**必ず読めるアドレス**（専用のアドレスを勧める） | 同上 |
| `LEGAL_ADDRESS` | ✓ | 住所。出したくなければ `ON_REQUEST`（「請求があれば遅滞なく開示します」と出る。実際に請求が来たら遅滞なく出す準備が要る） | 同上 |
| `LEGAL_PHONE` | ✓ | 電話番号。出したくなければ `ON_REQUEST` | 特商法、ポリシー・規約・サポートの運営者の欄 |
| `LEGAL_REPRESENTATIVE` | | 代表者または運営責任者の氏名（法人は入れる） | 同上 |
| `LEGAL_PRICE_NOTE` | | 例: `表示価格は税込です` | 特商法の販売価格 |
| `LEGAL_JURISDICTION_COURT` | | 例: `東京地方裁判所`（住所に近い地方裁判所にする人が多い） | 規約 第11条 |
| `STRIPE_TRIAL_DAYS` | | 無料体験の日数。**入れないと既定の 7 日**として規約・特商法に出る。付けないなら `0` | 規約 第6条、特商法の支払時期 |

入れた後に **Publish → Update**。必須の4つがそろうと、特商法の表が出て、本番の Stripe の購入口も開きます（`checkoutAllowedByLegal`）。

※ 個人情報保護法 32条は事業者の「氏名又は名称及び住所並びに法人にあっては代表者の氏名」を本人が知り得る状態に置くことを求めています（「本人の求めに応じて遅滞なく回答する」方法も認められています）。`LEGAL_ADDRESS=ON_REQUEST` のときのポリシーの書き方でよいかは弁護士に確かめてください。

**ほかにオーナーが確かめる事実**（文書の中で確かめられなかった物）

| 確かめる事 | 理由 | 文書 |
|---|---|---|
| Lovable Cloud（Supabase）のデータの保存地域 | ポリシー第5条は Supabase を「米国」の事業者として書いた。データが東京などにあるなら、そう書き足す方が正確 | ポリシー 第5条 |
| TypeSafe（Jev、`api.typesafe.ai`）の運営会社と所在国 | 単語・例文・復習の結果を送る先。所在国が分からないので第5条の一覧に入れず、「求めがあればお知らせ」とした | ポリシー 第4・5条 |
| MiniMax・Tripo3D の契約の相手（中国の会社か、シンガポールなどの国際版か） | 第5条は中国の事業者として書いた。使わないなら、それで足りる | ポリシー 第5条 |
| 実際に使う AI・読み上げの会社 | Web の開発者欄（`app_config`）で切り替えられる。台湾の利用者が中心なので、**中国の会社に写真や日記を送る設定は使わないことを強く勧める** | ポリシー 第4・5条 |
| Gemini を Google の API で直接使うなら有料の枠か | 無料枠では Google が入力をサービス改善に使うことがある。ポリシーは「運営者自身は学習に使わない」とだけ書いている | ポリシー 第4条 |

---

## 2. 弁護士に見てもらうべきか → **見てもらうことを強く勧めます** 【オーナー】

理由（このアプリ特有のもの）:
1. **外国の AI 会社に写真・日記を送る**。個人情報保護法の「外国にある第三者への提供」（28条）は、同意の取り方・情報の出し方が細かく決まっています。ポリシー第5条は国名・制度・措置を書き、iPhone アプリは送る前に同意画面を出しますが、委託先ごとの契約の確認は専門家の判断が要ります。
2. **消費者契約法**: 「一切責任を負いません」のような条項は無効です（8条）。規約第9条は消費者契約のときの上限を定める形ですが、金額の決め方は相談が要ります。
3. **台湾の利用者が中心**: 台湾の個人資料保護法・消費者保護法。繁體中文版は台湾の言葉が分かる人（できれば台湾の弁護士）に読んでもらうのが理想です。
4. **未成年**: 日本では18歳未満の契約は親の同意がないと取り消せます（民法5条）。米国の一部の州は、アプリにも年齢の確認を求めます（4-3）。
5. 個人で事業をする場合の**住所の出し方**（1章 ※）。

頼むときに渡すもの: `privacy-policy.*.md`、`terms.*.md`、`tokushoho.ja.md`、このリスト。

---

## 3. 審査用アカウント 【オーナー】（B-01 Blocker）

アプリはログインしないと使えません。審査用のアカウントを作り、写真と単語をいくつか入れ、**AI の同意画面で「同意して始める」まで済ませた状態**にしておきます。App Store Connect の App Review Information にメールとパスワードを入れ、`docs/self-managing-ios.md` 6-4 に「入力済み」と日付を書きます（パスワードは書かない）。

---

## 4. App Store Connect に入力すること

### 4-1. App 情報 【オーナー】

| 項目 | 入れる値 |
|---|---|
| プライバシーポリシー URL | `https://catchwords.lovable.app/privacy`（各言語の欄に同じ URL でよい） |
| サポート URL（B-02 Blocker） | `https://catchwords.lovable.app/support`。**`legal.patch` を当てて再公開し、`LEGAL_EMAIL` を入れた後に**連絡先が出る（審査ガイドライン 1.5）。今のトップページには連絡先が無い |
| 使用許諾契約 | 「Apple の標準 EULA」のまま（何も入れない）を勧めます。規約第12条に Apple の最低条件を入れてあるので、標準 EULA と並べても害はない |
| 著作権 | `LEGAL_SELLER_NAME` と食い違わない表記（例: `2026 ＜LEGAL_SELLER_NAME と同じ名前＞`） |
| 販売地域 | 1.0 は **日本・台湾（と英語圏で出したい国）に絞る**ことを勧める。**中国本土は外す**（ICP 届出や生成 AI の手続きが要る）。EU・英国を含める場合は 6-2 を先に |

### 4-2. App のプライバシー（「データの収集」の質問） 【オーナー】（B-04 Major）

Apple の定義では、**外部の AI 会社など「提携先」が受け取るデータも、アプリが集めたものとして答えます**。追跡（トラッキング）はすべて **いいえ**（iPhone アプリに広告も IDFA も無い）。

| データの種類 | 集める？ | ユーザーに関連付け | 目的 | 根拠（コード） |
|---|---|---|---|---|
| 連絡先情報 → メールアドレス | はい | はい | アプリの機能 | ログイン |
| 連絡先情報 → 名前 | はい | はい | アプリの機能 | 表示名 |
| ユーザーコンテンツ → 写真またはビデオ | はい | はい | アプリの機能 | 撮影・写真アプリの画像・自撮り・アバター。AI 会社にも送る |
| ユーザーコンテンツ → 音声データ | いいえ（下の ※） | — | — | 声で調べる（`SpeechService.swift`。端末で認識できるときは端末で）。音声は運営者に届かない |
| ユーザーコンテンツ → その他のユーザーコンテンツ | はい | はい | アプリの機能 | 日記・復習の答え・誤りの報告・声で調べた言葉の文字 |
| 位置情報 → 正確な位置情報 | はい | はい | アプリの機能 | 撮影地の緯度経度 |
| 識別子 → ユーザ ID | はい | はい | アプリの機能 | アカウントの ID |
| 使用状況データ → 製品の操作 | はい | はい | アプリの機能、分析 | 利用回数・画面（`usage_events`） |
| 検索履歴 | はい | はい | アプリの機能、分析 | スキャンで見つけた・押した単語（`scan_events`）。マニフェストは【済】 |
| 購入 → 購入履歴 | 1.0 は いいえ／**アプリ内課金を出す版から はい** | はい | アプリの機能 | `PlanStore.swift` |
| 診断・連絡先・健康・財務・ブラウザ履歴・機密情報・広告 ID | いいえ | — | — | 使っていない |

※ 音声（B-05）: 音声そのものは端末の中か Apple の音声認識にだけ渡り、運営者のサーバには文字だけが届きます（ポリシー第1条）。Apple の App Privacy Details は「端末の中だけで処理するデータ」「Apple が集めるデータ」を収集に含めないので、**「いいえ」にそろえた**（2026-10-03。`PrivacyInfo.xcprivacy`・`docs/self-managing-ios.md` 6-3 も同じ【済】）。文字にした結果は「検索履歴」「その他のユーザーコンテンツ」で答える。音声を運営者や他社の AI に送る機能を足すときは「はい」に戻し、ポリシーも直す。

回答を入れたら、その画面の写真を `docs/launch-audit/` に残す（B-04 の確かめ方）。

### 4-3. 年齢制限指定 【オーナー】

Apple の新しい質問（2025年〜）とソーシャルメディアの質問（2026年9月〜）の答えは、どれも「なし／いいえ」です（成人向けの内容・ギャンブル・制限のない Web・ユーザー生成コンテンツ・SNS・広告すべて無し。写真と日記は本人だけが見る）。計算上は 4+ になりますが、**規約は13歳未満の利用を認めていないので、App Store Connect で年齢区分を 13+ に上げる**ことを勧めます。「Kids カテゴリ」には入れない（外部 AI への送信と両立しない）。

米国のユタ州（2026-05-06〜）・ルイジアナ州（2026-07-01〜）は、新しいアカウントの年齢区分の確認（Apple の Declared Age Range API）などを求めます。米国で配信するなら弁護士に確認し、必要なら対応する（7章 A9）。

### 4-4. サブスクリプション（アプリ内課金を出す版から） 【オーナー】＋【要コード】

1.0 は無料だけ（`PlanStore.paywallEnabled = false`）。課金を出す版では:
- 課金画面の表示（名前・期間・請求額・復元・自動更新の説明・規約とポリシーと特商法へのリンク）は【済】。
- 利用規約・特商法に、`terms.*.md`・`tokushoho.ja.md` の**付録（未施行）**を入れて Web を再公開する（規約第6条第9項の置き換え）。
- サーバでの Apple の購入の確認（B-06、`docs/self-managing-ios.md` 7-2）【要コード】。
- App Store の説明文の最後に、利用規約・プライバシーポリシー・Apple 標準 EULA（https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ ）の3行。

### 4-5. 審査メモ（App Review Information） 【オーナー】

英語で書くのが確実です（B-07 のログインが要る理由も書く）。

```
Demo account: (email) / (password)

- Login is required because the app shares the same library with our web app and the server-side AI has
  per-account usage limits.
- Sign in with Apple / Google: done on our website (catchwords.lovable.app/native-auth) inside
  ASWebAuthenticationSession, then the app receives the session.
- AI: before the first AI feature, a consent screen explains that photos and text are sent through our server
  to third-party AI services (e.g. Google). Nothing is sent without consent; it can be withdrawn in
  Settings > Privacy. Details: Privacy Policy sections 4 and 5.
- Account deletion: Settings > Delete account. It deletes the server account and all data, including the avatar.
- Contact: Settings > Contact & Support (https://catchwords.lovable.app/support).
- No in-app purchases in this version.
- Location is optional and used only to record where a photo was taken and for place reminders.
```

### 4-6. 輸出コンプライアンス（暗号化） 【済】

`ITSAppUsesNonExemptEncryption = NO`。OS の HTTPS とキーチェーンだけなので免除の対象。

---

## 5. 実機で流れを通して記録する 【オーナー】（C-01 Major）

TestFlight の版（統合ブランチが main に入った後のビルド）で、`docs/self-managing-ios.md` 6-1 の表を全部やり、結果と日付・ビルド番号を残します。少なくとも: ログイン（規約の一文が見える）→ AI の同意画面 → 撮影 → AI 分析 → 選ぶ → カード → 図鑑、設定の「お問い合わせ・サポート」「特定商取引法に基づく表記」が開くこと（Web の再公開の後）、アカウント削除。

---

## 6. 地域ごとの追加の確認

### 6-1. 日本 【オーナー】
- 個人情報保護法 32条の公表事項 → 名称・住所・代表者（1章の Secrets）、利用目的（第2条）、開示等の手続と手数料なし（第8条）、安全管理措置（第11条）、苦情の窓口（第12条）。**Secrets を入れれば揃う。**
- 外国にある第三者への提供（28条）→ 第5条（国名・制度・措置）＋ iPhone アプリの同意画面（第4条）。Web 版には同意画面がまだ無い（7章 W1）。
- 特定商取引法 → `/legal/tokushoho`（Secrets でそろう）。最終確認画面 → アプリの課金画面はほぼ済、Web の購入ボタンの前の表示は要確認（7章 W4）。
- 電気通信事業法の外部送信規律（Web 版の Google Maps・AdSense など）→ 対象に当たるかを弁護士に確認。

### 6-2. EU・英国（配信する場合だけ） 【オーナー】
- ポリシー第14条に GDPR の法的根拠と権利を入れた。
- **EU 内の代理人（GDPR 27条）** が要る場合がある。1.0 は EU・英国を配信地域から外すのがいちばん簡単。
- EU の消費者のデジタルサービスの14日の撤回権（Stripe で売る場合）。

### 6-3. 台湾 【オーナー】
- 個人資料保護法 第8條の告知事項 → ポリシー第14条（名称・目的と分類・種類・期間・地域・対象・方式・権利・提供しない場合の影響）。
- 消費者保護法（オンライン販売の7日の解除権とデジタルの例外）→ Stripe で台湾の人に売る前に確認。

### 6-4. 米国・子ども
- COPPA: 子ども向けではなく、規約で13歳未満を禁止。年齢区分 13+（4-3）。
- カリフォルニア: ポリシー第14条。Web 版の AdSense のパーソナライズ広告は州法上の「共有」に当たりうると書いた。

---

## 7. コードの変更（ギャップの一覧）

### iPhone アプリ（このリポジトリ、統合ブランチ `ccr-89cbeb71-xcif1z`）

| # | 状態 | 内容 |
|---|---|---|
| A1 | 【済】 | AI に送る前の同意画面（審査ガイドライン 5.1.2(i)）と、AI の関数の関所（`AIConsentView.swift`、`AIConsent.swift`、`NativeAPI.call`）。設定 › プライバシーで確認・取り消し。サーバでの記録は W1 |
| A2 | 【済】 | ログイン画面の「続けると、利用規約とプライバシーポリシーに同意したことになります」 |
| A3 | 【済】 | 課金画面の自動更新の説明を 12pt に |
| A4 | 【済】 | 設定と課金画面に「特定商取引法に基づく表記」。リンク先を Web の本当の URL `/legal/tokushoho` に直した（前は 404 の `/tokushoho`） |
| A5 | 【済】 | 設定に「お問い合わせ・サポート」（`/support`。Web の頁は `legal.patch` で足す） |
| A6 | 【済】 | プライバシーマニフェストに検索履歴。購入履歴は課金を出す版で |
| A7 | 【済】 | 位置情報の説明に「場所でリマインド」 |
| A8 | 【済】 | アカウント削除の説明に「App Store のサブスクは自動では解約されない」 |
| A9 | 米国で配信する場合 | Declared Age Range API（4-3） |
| A10 | 課金時 | 無料体験を付ける場合、その期間と終了後の価格の表示 |
| A11 | 【済】 | 音声データの申告をポリシーとそろえた（「いいえ」。4-2 ※、B-05） |

これらは統合ブランチに入っていて、**main（TestFlight の版）にはまだ入っていない**。

### Web 版（`nori-creator/Lovable-catch-words-app`）

| # | 状態 | 内容 |
|---|---|---|
| W0 | **差分あり（当てる）** | iPhone アプリの扱い・外国の事業者・安全管理・地域ごとの追加・App Store の条項（`docs/legal/web/legal.patch`、`web-patch.md`） |
| W2 | 【済】 | アカウント削除でアバター（`avatars`）も消す（main の `deleteMyAccount`） |
| W3 | 【済】 | Web の有料プランの解約の入口（設定の「サブスクリプションを管理」＝ Stripe の Billing Portal） |
| W5 | **差分あり（当てる）** | サポートの頁 `/support`（連絡先は `LEGAL_EMAIL`）と `/tokushoho` からの転送 |
| W1 | 【要コード】 | AI の同意をサーバに記録し、同意していない人の AI の関数をサーバでも断る。Web の画面（ログインしない体験を含む）にも同じ同意の表示。Web 版の利用者には今、同意画面が無い |
| W6 | 【要コード】（B-03 Major） | Apple でサインインしたアカウントを消すとき、Apple のトークンを取り消す（`appleid.apple.com/auth/revoke`）。今の `deleteMyAccount` には無い。ポリシーには「取り消す」と書いていない（事実と合わせるため） |
| W4 | 要確認 | 本番の Stripe の前に、購入ボタンの前の最終確認の表示（価格・自動更新・請求の時期・解約・特商法と規約へのリンク。特商法 12条の6）がそろっているか |
| W9 | 課金時 | Apple の購入をサーバで確かめる仕組み（B-06） |
| W10 | 推奨 | AI の会社を選べる範囲を、ポリシーに書いた会社だけに制限する |

---

## 8. 主な法的リスク（大きい順）

1. **連絡先・事業者の情報が空のまま出す**（F-01）: Secrets を入れないと、公開中の頁に「準備中」が出たまま。個人情報保護法 32条、特商法、審査ガイドライン 1.5・2.1(a) のどれも満たせない。
2. **ポリシーと実際の動きの食い違い**: AI の会社を管理画面で切り替えられる作り。書いていない会社に切り替えると同意の範囲外になる。App Store Connect の回答は、マニフェストとポリシーに合わせて入れる（4-2）。
3. **Web 版の AI 同意が無い**（W1）: iPhone アプリは同意を取るが、Web 版は取らない。外国の AI 会社への提供の同意は、ポリシーへの同意だけに頼っている。
4. **Sign in with Apple のトークンを取り消していない**（W6）: Apple の公式の要件。審査で指摘されることがある。
5. **年齢**: 規約は13歳以上なのに年齢区分 4+ のまま出すと食い違う（4-3）。
6. **EU・英国・中国本土での配信**: GDPR の代理人、中国本土の手続き。1.0 は配信地域を絞るのが安全。
7. **AI の内容の誤り**: 規約第5条で注意と安全に関わる使い方の禁止を書いたが、責任をすべて免れるわけではない（消費者契約法）。

---

## 9. 確認した公式の情報（2026-10-03 時点）

Apple
- App Store 審査ガイドライン（1.5、2.1(a)、3.1.2、4.8、5.1.1(v)、5.1.2(i)）: https://developer.apple.com/app-store/review/guidelines/
- アカウント削除の要件: https://developer.apple.com/support/offering-account-deletion-in-your-app/
- Sign in with Apple のトークン取り消し（TN3194）: https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple
- 自動更新サブスクリプション: https://developer.apple.com/app-store/subscriptions/
- 年齢区分: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/
- 独自 EULA の最低条件: https://www.apple.com/legal/internet-services/itunes/dev/minterms/ ／標準 EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

日本
- 個人情報保護委員会 ガイドライン（通則編・外国にある第三者への提供編）: https://www.ppc.go.jp/personalinfo/legal/guidelines_tsusoku/ 、https://www.ppc.go.jp/personalinfo/legal/guidelines_offshore/
- 消費者庁 通信販売の最終確認画面のガイドライン: https://www.no-trouble.caa.go.jp/what/mailorder/guidelines.html ／通信販売広告 Q&A: https://www.no-trouble.caa.go.jp/qa/advertising.html
- 総務省 外部送信規律: https://www.soumu.go.jp/main_sosiki/joho_tsusin/d_syohi/gaibusoushin_kiritsu.html

台湾
- 個人資料保護法 第8條: https://law.moj.gov.tw/LawClass/LawSingle.aspx?flno=8&pcode=I0050021

---

## 付記: このフォルダのファイル

| ファイル | 内容 |
|---|---|
| `privacy-policy.ja.md` / `.en.md` / `.zh-TW.md` | プライバシーポリシーの全文（3言語）。Web の `privacy-*.tsx` に `legal.patch` を当てた後と同じ文言。〔 〕は Secrets から出る値 |
| `terms.ja.md` / `.en.md` / `.zh-TW.md` | 利用規約の全文（3言語）。末尾にアプリ内課金を始めるときの付録（未施行） |
| `tokushoho.ja.md` | Web の `/legal/tokushoho` が出す表の写しと、アプリ内課金の行の付録（未施行） |
| `web-patch.md` | Web への反映の手順・Lovable に貼る指示・Secrets・確かめ方・検証の結果 |
| `web/legal.patch` | Web の main 11ff3f0 に対する unified diff |
