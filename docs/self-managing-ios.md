# iOS 版を Rork なしで自分で管理する手順

対象: CatchWords の iOS 版（このリポジトリの `ios/`）。Mac がなくても、GitHub だけで組み立て・確認・App Store への提出ができるようにする手順です。

最終更新: 2026-10-01

---

## 0. 言葉の意味（最初に読む）

| 言葉 | 意味 |
|---|---|
| **GitHub** | コードの保管庫。変更の履歴がすべて残る。Rork をやめても消えない。 |
| **リポジトリ** | GitHub 上の1つのプロジェクトの箱。iOS 版は `nori-creator/rork-catchwords-728`。 |
| **PR（プルリクエスト）** | 「この変更を入れてよいか」の提案書。中身を見てから本体（main）に取り込む。 |
| **GitHub Actions** | GitHub が貸してくれる Mac で、決まった作業を自動でやる仕組み。「ワークフロー」はその作業手順書。 |
| **Secrets** | GitHub に預ける秘密の値（鍵など）。コードには書かず、画面からも読めない。 |
| **App Store Connect** | Apple のアプリ管理画面（https://appstoreconnect.apple.com）。審査への提出・TestFlight・売上などを扱う。 |
| **TestFlight** | 公開前のアプリを iPhone に入れて試せる Apple の仕組み。 |
| **バンドル ID** | アプリの世界で1つだけの名前（例 `com.example.catchwords`）。**一度 App Store Connect に送ると変えられない。** |
| **API キー（.p8）** | GitHub の Mac が、あなたの代わりに Apple へアプリを送るための鍵。 |
| **ビルド番号 / バージョン** | ビルド番号は送るたびに増える通し番号。バージョン（1.0.0 など）は利用者に見える版。 |

---

## 1. Rork を契約している間にやること

### 1-1. バンドル ID を決める（最初の提出の前に1回だけ）

- バンドル ID は **`com.nori.catchwords`**（2026-10-01 に Rork の自動の名前 `app.rork.v075or6kicdigi0jhlze3` から変更。まだ一度も提出していなかったため変えられた）。
- 一度 App Store Connect に提出すると変えられません（Apple の決まり）。
- **データベースとログインは Lovable Cloud（Lovable が管理する Supabase）にある。** 自分の Supabase アカウントには入っていないので、Supabase の管理画面は使わない。
- **Google / Apple のログインは Web 版の `/native-auth` を通る**（2026-10-01）。アプリはシステムの安全なログイン画面で Web 版のページを開き、Web 版と同じ仕組みでログインしてからアプリに戻る。Web 版と同じアカウントになる。Lovable Cloud や Apple Developer 側に追加の設定は要らないが、**Web 版の `/native-auth` が Publish されていないとアプリの Google / Apple ログインは失敗する**（1-2 を先に）。
- 端末内で完結する Apple サインイン（`AppConfig.nativeAppleSignIn`）はオフにしてある。ログインの仕組み側にバンドル ID を登録できないのと、Web 版と別のアカウントになってしまうため。

### 1-2. Web 版を先に公開する

iOS 版の AI・保存は、Web 版のサーバ（`/api/native-fn`）を通ります。iOS 版が呼ぶ関数が Web 版に全部あるかは、ワークフロー「iOS ↔ Web contract（約束の確認）」が毎日確かめます。

1. Web 版の PR（`nori-creator/Lovable-catch-words-app`）を main に取り込む。
2. Lovable の編集画面で右上の **Publish → Update** を押す。

これをしないと、iOS 版では候補が出ず、保存もできません。

### 1-3. App Store に出す（GitHub Actions から）

1. GitHub → **Actions** → **iOS release（App Store Connect へ送る）** → **Run workflow**（手順 2-5 と同じ）。
2. App Store Connect → アプリ → **TestFlight** にビルドが出たら、iPad に TestFlight で入れて「6. 提出前の確認」を一通り試す。
3. App Store Connect の **App Store** タブで「6. 提出チェックリスト」の情報を埋め、そのビルドを選んで**審査へ提出**。

> 注意: Apple は、アカウントを作れるアプリには「アプリの中でアカウントを削除できること」を求めています（審査ガイドライン 5.1.1(v)）。設定画面の「アカウント削除」はログインごと消します（サーバの `deleteMyAccount`）。

---

## 2. Rork をやめる前に必ずやること（順番どおりに）

### 2-1. コードが GitHub にそろっているか確かめる

- GitHub の `nori-creator/rork-catchwords-728` を開き、最新の変更が main に入っていることを見る。
- Rork の GitHub 連携は有料プランの機能です。解約前に、最後の同期が終わっていることを確かめてください。

### 2-2. App Store Connect API キーを作る

1. https://appstoreconnect.apple.com → **ユーザとアクセス** → **統合（Integrations）** タブ → **App Store Connect API** → **チームキー**。
2. **「＋」（API キーを生成）** を押す。
   - 名前: `GitHub Actions`
   - アクセス: **Admin**（クラウド署名に必要なため。App Manager で動かないことがあります）
3. 表示される **キー ID** と、画面上部の **Issuer ID** をメモする。
4. **API キーをダウンロード**（`AuthKey_XXXXXXXXXX.p8`）。**ダウンロードは1回しかできません。** なくしたら作り直しです。

参考（Apple 公式）: https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api

### 2-3. チーム ID を調べる

- https://developer.apple.com/account → **メンバーシップの詳細** → **チーム ID**（10桁の英数字）。

### 2-4. GitHub に 4 つの Secrets を入れる

GitHub のリポジトリ → **Settings** → **Secrets and variables** → **Actions** → **New repository secret** で、次の4つを1つずつ追加します。

| 名前 | 入れる値 |
|---|---|
| `APPLE_TEAM_ID` | 2-3 のチーム ID |
| `ASC_KEY_ID` | 2-2 のキー ID |
| `ASC_ISSUER_ID` | 2-2 の Issuer ID |
| `ASC_KEY_P8` | .p8 ファイルをメモ帳などで開いた中身を**そのまま全部**（`-----BEGIN PRIVATE KEY-----` から `-----END PRIVATE KEY-----` まで） |

（以前の `ASC_KEY_P8_BASE64`（base64 にした文字列）を入れてある場合は、それでも動きます。）

**.p8 の中身はチャットや Issue に貼らないでください。** 入れる場所は GitHub の Secrets だけです。

### 2-4b. 端末を1台登録する（最初の1回だけ）

自動の署名は、送る前に一度「開発用」で署名するため、Apple Developer に iPhone か iPad が1台以上登録されている必要があります（無いと「Your team has no devices」で止まる）。

1. iPad の「UDID」（端末ごとの40桁ほどの番号）を調べる
   - **Mac**: iPad をケーブルでつなぐ → Finder の左に出る iPad を押す → 名前の下の灰色の文字（機種名・シリアル番号）を何回か押すと「UDID」に変わる → 右クリックで「UDID をコピー」
   - **Windows**: Microsoft Store の「Apple デバイス」アプリを入れる → iPad をケーブルでつなぐ → iPad を選ぶ → シリアル番号を押すと UDID に変わる → コピー
2. https://developer.apple.com/account → Certificates, IDs & Profiles → **Devices** → 「＋」
3. Platform: iOS／Device Name: `iPad`／Device ID (UDID): 1 でコピーした番号 → Continue → Register

### 2-5. Rork なしで1回送ってみる（解約の前に）

1. GitHub → **Actions** → **iOS release（App Store Connect へ送る）** → **Run workflow**。
2. 20分ほどで終わる。緑のチェックが付けば成功です。
3. App Store Connect → アプリ → **TestFlight** に、新しいビルドが出ることを確かめる（処理に10〜30分かかります）。

**ここまで成功したら、Rork を解約して大丈夫です。** 失敗したら、赤くなった手順の記録（Artifacts の `ios-release-logs`）を Claude に見せてください。

---

## 3. Rork をやめた後の、ふだんの回し方

```
やりたいことを Claude に頼む
   ↓
Claude が変更を作り、PR を出す
   ↓
「iOS check」が自動で動き、シミュレーターの画面写真・動画ができる（iPhone がなくても見られる）
   ↓
写真・動画を見て OK なら、PR を main に取り込む
   ↓
Actions の「iOS release」を Run workflow → TestFlight に届く
   ↓
App Store Connect で「審査へ提出」
```

### 画面の確認のしかた（iPhone がなくても）

1. PR の画面 → **Checks** → **iOS check（iOS 版の確認）** → **Summary**。
2. 下の **Artifacts** から `ios-check-report` をダウンロードして開く。
3. `screen-*.png`（写真）と `launch.mp4`（動画）で見た目を確認する。

シミュレーター（画面上で動く仮想の iPhone）では、カメラと「切り抜き（Vision）」は動きません。これらは TestFlight を入れた本物の iPhone で確認します。

### 新しいバージョンを出すとき

- 利用者に見える版（例 1.0.0 → 1.1.0）は、Claude に「バージョンを 1.1.0 にして」と頼む。
- ビルド番号は、ワークフローが自動で増やします（`1000 + 実行回数`）。

---

## 4. お金のこと（2026-09 時点）

| 項目 | 金額 | 備考 |
|---|---|---|
| Apple Developer Program | 年 99 ドル | App Store に出すのに必須 |
| GitHub Actions（Mac） | 非公開リポジトリは無料枠を超えると 1 分 0.062 ドル | 1回の release で約 20 分、iOS check で約 15 分。公開リポジトリなら無料 |
| Rork Max | 月 200 ドル | 手順 2 が終われば不要 |

参考: https://docs.github.com/en/billing/reference/actions-runner-pricing

> Mac の分数が無料枠をどの割合で使うかは、GitHub の現在の説明に明記がありません（以前は10倍で数えていました）。GitHub の Settings → Billing で実際の使用量を確認してください。

---

## 5. 困ったとき

| 症状 | 見る所・やること |
|---|---|
| iOS check が赤い | その PR で Claude に「CI を直して」と頼む |
| iOS release が「Secrets が足りません」 | 手順 2-4 をやり直す |
| iOS release が署名で失敗 | API キーのアクセスが Admin か確かめる（手順 2-2） |
| TestFlight に出てこない | App Store Connect の「アクティビティ」で処理中か確かめる。Apple からのメールも確認 |
| アプリで候補が出ない・保存できない | Web 版が Publish されているか確かめる（手順 1-2） |

---

## 6. App Store 提出チェックリスト（初版 1.0.0・無料のみ・iPhone 専用）

### 6-1. 提出前にアプリで確かめること（TestFlight）

| 確かめること | 期待する動き |
|---|---|
| Google で続ける | Safari の小さな画面が開き、Google でログイン → 自動でアプリに戻り、ホームが出る |
| Apple でサインイン | 同じく Apple でログイン → アプリに戻る |
| ログイン画面を閉じる | 何も出ない（エラーにならない） |
| メールでログイン・新規登録・パスワードを忘れた | それぞれ動く |
| 機内モードで起動 | ログインしたまま。「ようこそ」画面が再び出ない |
| Web 版の設定で「すべての端末からログアウト」→ アプリを操作 | ログイン画面に戻り「ログインの有効期限が切れました」と出る |
| 撮影 → 単語を選ぶ → 保存 | 図鑑に着地する。機内モードなら「保存に失敗しました」と出て写真は「解析待ち」に残る |
| 復習で答える（機内モード） | 「採点を保存できませんでした」と出て、もう一度答えられる |
| 設定 | 「Pro にアップグレード」「購入を復元」が出ない。末尾に `1.0.0 (ビルド番号)` が出る |
| 設定 → アカウント削除 | 削除後にログイン画面に戻り、同じメールで再ログインできない |
| 図鑑（棚） | 上に本棚が出ない。スライド表示でカードが輪になって回り、音が鳴る |

### 6-2. App Store Connect に入れる情報

| 項目 | 値・下書き |
|---|---|
| 名前 | CatchWords |
| サブタイトル（30字） | 街で見つけた物が、学ぶ言葉になる |
| カテゴリ | 教育（サブ: 辞書/辞典 など任意） |
| 価格 | 無料 |
| 年齢 | 4+（ユーザー生成コンテンツは本人だけが見るため。暴力・性的表現なし） |
| プライバシーポリシー URL | https://catchwords.lovable.app/privacy |
| サポート URL | https://catchwords.lovable.app（問い合わせ先のページがあればそちら） |
| 著作権 | 2026 Noriyuki Kondo |
| スクリーンショット | iPhone 6.9 インチ（必須）と 6.5 インチ。実機の画面（ホーム・撮影・図鑑のスライド・単語の詳細・復習）。CI の見本画像は仮の写真なので使わない |
| iPad | 不要（iPhone 専用） |

説明文（日本語の下書き。英語・繁体字は App Store Connect で言語を追加して訳す）:

```
街で見つけた物を撮るだけで、学んでいる言葉（台湾華語・英語・日本語）の単語カードになります。

・写真から単語の候補を出し、読み方と意味を付けて図鑑に集める
・切り抜きのステッカー、撮った場所と日付、ひとことメモ
・覚え具合に合わせて出題される復習（4択）
・看板にかざして調べる「スキャン」、声で調べる
・Web 版（catchwords.lovable.app）と同じアカウントで、集めた単語はどこでも同じ
```

キーワード（100字）: `台湾華語,中国語,英語,単語,語学,学習,図鑑,写真,ステッカー,復習,台湾`

### 6-3. App のプライバシー（質問への答え）

「データを収集しますか」→ **はい**。追跡（トラッキング）→ **いいえ**。すべて「ユーザーに関連付けられる」「アプリの機能のため」。

| 種類 | 収集する | 用途 |
|---|---|---|
| 連絡先情報 → メールアドレス | はい | アカウント |
| ユーザー ID | はい | アカウント |
| 位置情報 → 正確な位置情報 | はい | 撮った場所の地名を残す（許可した時だけ） |
| ユーザーコンテンツ → 写真またはビデオ | はい | 単語の写真・ステッカー |
| ユーザーコンテンツ → 音声データ | はい | 声で調べる（端末の音声認識。保存しない） |
| ユーザーコンテンツ → その他 | はい | メモ・日記・学習記録 |
| 購入、診断、使用状況データ | いいえ | 集めていない |

アプリ内の `PrivacyInfo.xcprivacy` も同じ内容。変えるときは両方そろえる。

### 6-4. 審査メモ（App Review Information）に書くこと

```
テスト用アカウント: （メール）／（パスワード）  ← 審査用に専用アカウントを作って書く

- Google / Apple のサインインは、アプリ内の安全な Safari 画面（ASWebAuthenticationSession）で
  当社の Web サイト catchwords.lovable.app のログインを行い、アプリに戻ります。
- アカウント削除は 設定 → アカウント削除 から行え、サーバのアカウントごと消えます。
- 写真の候補・単語カードの生成は当社サーバ（catchwords.lovable.app）で行います。
- この版は無料のみで、アプリ内課金はありません。
```

### 6-5. 提出後によく返ってくる指摘と対応

| 指摘 | 対応 |
|---|---|
| Guideline 2.1（起動時に落ちる・ログインできない） | テスト用アカウントが有効か、Web 版が Publish 済みか確かめる |
| Guideline 5.1.1（権限の説明が足りない） | カメラ・マイク・位置・写真の説明文（pbxproj の `INFOPLIST_KEY_*UsageDescription`）を直す |
| Guideline 4.8（Sign in with Apple） | Google と並べて Apple も出している。指摘があれば Claude に見せる |
| Guideline 5.1.1(v)（アカウント削除） | 設定 → アカウント削除 の場所を審査メモに書く |
