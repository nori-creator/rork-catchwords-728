# iOS 版を Rork なしで自分で管理する手順

対象: CatchWords の iOS 版（このリポジトリの `ios/`）。Mac がなくても、GitHub だけで組み立て・確認・App Store への提出ができるようにする手順です。

最終更新: 2026-09-30

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
- **iPhone・iPad の「Appleでサインイン」は、ログインの仕組み側にこのバンドル ID を登録するまで失敗する見込み**（ネイティブのアプリの Apple サインインは、アプリのバンドル ID を許可された相手として登録する必要がある）。Lovable Cloud でその登録ができるかは未確認。**それまではメールアドレスとパスワードでログインして確かめる**（Web 版を Google で登録した人は、ログイン画面の「パスワードを忘れた」でパスワードを作ってから入る）。

### 1-2. Web 版を先に公開する

iOS 版の AI・保存は、Web 版のサーバ（`/api/native-fn`）を通ります。iOS 版が呼ぶ関数が Web 版に全部あるかは、ワークフロー「iOS ↔ Web contract（約束の確認）」が毎日確かめます。

1. Web 版の PR（`nori-creator/Lovable-catch-words-app`）を main に取り込む。
2. Lovable の編集画面で右上の **Publish → Update** を押す。

これをしないと、iOS 版では候補が出ず、保存もできません。

### 1-3. Rork から App Store に出す

1. Rork の **Publish** を押す。
2. 自分の Apple ID でサインインする（2段階認証のコードを入れる）。
3. App Store Connect で、次の情報を埋めて審査に出します。
   - 説明文
   - スクリーンショット
   - プライバシーポリシーの URL: `https://catchwords.lovable.app/privacy`
   - 年齢区分
   - App のプライバシー（集めるデータの申告）

参考（Rork 公式）: https://docs.rork.com/store-guides/publish-app-store

> 注意: Apple は、アカウントを作れるアプリには「アプリの中でアカウントを削除できること」を求めています（審査ガイドライン 5.1.1(v)）。提出前に、設定画面の「アカウント削除」がログインごと消せる状態になっていることを確認してください。

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
