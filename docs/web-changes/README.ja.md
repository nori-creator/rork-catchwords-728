# CatchWords Web 版の変更パッチ（2026-10-03）

このフォルダには、Web 版（Lovable のプロジェクト）に当てる変更が入っています。
まだ本番には何も入っていません。下の手順で当ててください。

---

## 1. 何が変わるか（5つ）

| 順 | 中身 | 利用者から見えること |
|---|---|---|
| 1 | **法務の文書の更新**（先に用意してあった `legal.patch`） | プライバシーポリシー・利用規約・特商法の頁・サポートの頁 |
| 2 | **MiniMax と Tripo3D を完全に削除**（2026-10-03 のオーナー決定） | 単語の詳細の「3Dにする」ボタンが無くなる（開発者にしか出ていなかった）。読み上げの会社の選択肢から MiniMax が消える。プライバシーポリシーから2社の名前が消える |
| 3 | **外部 AI へのデータ送信の同意**（App Store 5.1.2(i) と同じ扱い・個人情報保護法 28 条） | ログインした人には、アプリに入った所で1回だけ「AIへのデータ送信について」の確認が出る（iPhone 版と同じ文面・3言語）。チュートリアルでは、写真を AI に送る前に出る。設定に「AIへのデータ送信」の欄（同意の状態・取り消し）。同意しないと AI を使う機能はサーバで止まる |
| 4 | **退会のときに「Apple でサインイン」の許可を取り消す**（Apple の決まり・TN3194） | 見た目は変わらない。Apple でサインインした人が退会すると、Apple 側の許可も取り消される |
| 5 | **特商法 12 条の6 の「最終確認画面」** | 設定の「CatchWords Pro」で「月ごと／年ごとで始める」を押すと、申込み内容の確認（値段・無料期間と初回の請求日・支払い時期と方法・自動更新・解約の方法・返金など）が出て、「規約に同意して購入する（定期購入）」を押した時だけ Stripe の支払い画面へ進む |

すべて、型の検査・lint・翻訳の検査・自動テスト（3,100 件）・本番ビルド・確認用ページ（UI ハーネス）のビルドが通ることを確かめてあります。

---

## 2. どのファイルを使うか

作業中に GitHub の `main` が進みました（`11ff3f0` → `3fd364f`）。このフォルダの物は **`3fd364f` を土台に作り直した版** です。

| ファイル（このリポジトリの `docs/web-changes/` の中） | 中身 |
|---|---|
| **`series/0001〜0005`**（コミットごと） | **これを使ってください。** `3fd364f` に `git am` でそのまま当たることを確かめてあります |
| `web-changes-onto-3fd364f.patch`（1つにまとめた物） | 上の5つを1つにした物（中身は同じ）。Lovable に添付する時に使います |

**注意（2026-10-03 時点）:** Web の `main` はその後さらに `3bf12d2` まで進み、そのままの `git am` は
`FirstCatchFlow.tsx` の1か所で止まります。**`git am -3`（3-way）なら衝突なく当たる** ことを確かめてあります。
これより先に `main` が進んで当たらない所が出たら、Claude に「このパッチを今の main に合わせて作り直して」と頼んでください。

---

## 3. 当て方

### いちばん確実: GitHub に入れる（Lovable は GitHub と同期しているので、そのまま Lovable にも入ります）

パソコンにリポジトリがある場合（ターミナルで）:

```bash
cd Lovable-catch-words-app
git checkout main && git pull
git checkout -b legal-and-compliance-2026-10-03
git am -3 path/to/rork-catchwords-728/docs/web-changes/series/*.patch
git push -u origin legal-and-compliance-2026-10-03
```

その後 GitHub でプルリクエストを作り、Netlify の Deploy Preview（確認用ページ）で見てから `main` にマージします。
（Claude にこのリポジトリへの書き込みを許可してもらえれば、Claude がこの作業をします。）

### Lovable のチャットで頼む場合

パッチは約 400KB あるので、チャットに貼るより **ファイルとして添付** してください。添付できない時は、
上の GitHub の方法を使ってください（Lovable が手で書き直すと、細かい所がずれます）。

**注意:** 今の Web の `main`（`3bf12d2`）には、このパッチは `FirstCatchFlow.tsx` の1か所でそのままでは当たりません
（3-way なら当たります）。Lovable は 3-way で当てられないので、Lovable の道を選ぶ前に Claude に
「docs/web-changes を今の main に合わせて作り直して」と頼むか、上の GitHub の `git am -3` の道を使ってください。

**Lovable に貼る文（そのまま使えます）:**

> 添付の `web-changes-onto-3fd364f.patch` は、このプロジェクトの main（3fd364f を土台）に対する unified diff です。
> **内容を変えずに、そのまま全部当ててください。** ファイルの削除（Object3DHero.tsx・object3d*.ts・
> api.object3d-model.ts など）も含みます。勝手な書き直し・整形・追加の改善はしないでください。
> 当てた後、`src/routeTree.gen.ts` は自動生成のままにし、次の2つの Supabase の移行を実行してください:
> `supabase/migrations/20261003140000_ai_consents.sql` と
> `supabase/migrations/20261003150000_apple_tokens.sql`。
> 最後に `npx tsc --noEmit` と `npx vitest run` が通ることを確かめて、結果を教えてください。

---

## 4. Supabase の移行（DB の変更）— 2つ

| ファイル | 中身 |
|---|---|
| `supabase/migrations/20261003140000_ai_consents.sql` | 新しい表 `ai_consents`（AI への送信の同意の記録: 誰が・どの版に・いつ同意し・いつ取り消したか）。本人は自分の行を読めるだけ。書くのはサーバだけ。退会で消える |
| `supabase/migrations/20261003150000_apple_tokens.sql` | 新しい表 `apple_tokens`（Apple の token。退会のときの取り消し用）。**ブラウザからは一切読めない・書けない**（サーバの鍵だけ）。退会で消える |

- どちらも何度流しても同じ結果になります。既存のデータは消しません。
- GitHub 経由で入れた場合、Lovable が自動で流さないことがあります。Lovable のチャットで
  「supabase/migrations/20261003140000_ai_consents.sql と 20261003150000_apple_tokens.sql を実行して」と頼むか、
  Lovable Cloud の SQL の画面にファイルの中身を貼って実行してください。
- **移行を流す前に公開しても壊れません**: 同意の表が無い間は、サーバは同意を確かめずに AI を通します（記録に警告を残す）。
  Apple の表が無い間は、取り消しを飛ばして退会は続きます。ただし**移行を流すまで同意の仕組みは効いていない**ので、早めに流してください。
- 3D 機能のための DB の表・列はありませんでした（3D の形は端末のブラウザの保存領域に置いていた）。
  過去の利用記録（`usage_events` の `kind = 'object3d'` の行）は残りますが、使われません。消す必要はありません。

---

## 5. 設定する秘密の値（Lovable の Secrets / 環境変数）

### Apple の取り消しに必要（4つ）

| 名前 | 入れる値 | Apple Developer のどこで取るか |
|---|---|---|
| `APPLE_TEAM_ID` | 10 文字のチーム ID（例 `ABCDE12345`） | developer.apple.com → Account → **Membership details** の「Team ID」 |
| `APPLE_KEY_ID` | 10 文字の鍵の ID | Certificates, Identifiers & Profiles → **Keys** → 下で作った鍵の「Key ID」 |
| `APPLE_PRIVATE_KEY` | `.p8` ファイルの中身を全部（`-----BEGIN PRIVATE KEY-----` から `-----END PRIVATE KEY-----` まで、改行ごと） | Keys → 「+」→ 名前を付け **Sign in with Apple** にチェック → Configure で主の App ID（iPhone アプリの ID）を選ぶ → Register → **Download**（**1回しかダウンロードできません**。なくしたら作り直し） |
| `APPLE_SERVICES_ID` | Services ID（例 `app.catchwords.web`） | Identifiers → 右上の絞り込みで **Services IDs** → Web の Apple ログインに使っているもの。**Lovable Cloud の Apple ログインの設定に入れてある Services ID と同じ物** |

**とても大事:** Lovable Cloud の Apple ログインが「Lovable が用意した共用の設定（managed）」のままだと、Apple の token は
Lovable の Services ID 向けに発行されるので、**こちらの鍵では取り消せません**。Lovable Cloud の
認証の設定（Users / Authentication → Apple）で **自分の Services ID・Team ID・Key ID・秘密鍵** を使う設定にしてください。
すでに Lovable Cloud に自分の鍵を入れてある場合は、その同じ値をここにも入れます（同じ鍵を使い回して構いません）。

### AI の同意（任意・あとで）

| 名前 | 値 | いつ |
|---|---|---|
| `AI_CONSENT_ENFORCE_NATIVE` | `true` | **今は入れないでください。** iPhone 版が同意をサーバに送るように更新され、全員がその版になった後に入れます。入れると、古い iPhone 版でも AI の関数はサーバの同意の記録が無いと断られます |

### 特商法の確認画面（既にある設定の確認）

- `STRIPE_TRIAL_DAYS`（無料体験の日数。未設定なら 7 日、`0` で無し）。確認画面にはその人が実際に受けられる日数（前に定期購入した人は 0）が出ます。
- **Stripe の Price を「税込（inclusive）」にしてください**（Stripe の管理画面 → 商品 → 価格 → 税の扱い）。
  未設定・税別だと、確認画面は「（税込）」と書けません（税別の時は「合計は次の画面」と添えます）。日本の消費者向けは税込表示が原則です。
- **Stripe の Customer portal（カスタマーポータル）で「サブスクリプションのキャンセル」を有効にして保存**してください
  （Stripe の管理画面 → 設定 → Billing → Customer portal）。設定の「サブスクリプションを管理」はここを開きます。

---

## 6. 公開した後に確かめること

### MiniMax / Tripo3D の削除
- 単語の詳細の写真の左上に「3Dにする」が出ないこと（開発者のアカウントで）。
- 設定 → 開発者 → 読み上げの声の会社に MiniMax が無いこと。前に MiniMax を選んでいても、既定の声で鳴ること。
- プライバシーポリシー（3言語）に MiniMax・Tripo3D の名前が無いこと。
- 不要になった秘密の値（`MINIMAX_API_KEY`・`MINIMAX_GROUP_ID`・`MINIMAX_API_HOST`・`TRIPO_API_KEY`（とその別名）・`OBJECT3D_API_KEY`・`OBJECT3D_ENDPOINT`・`OBJECT3D_PROVIDER` など、入れてあれば）は Lovable の Secrets から消して構いません。

### AI の同意
1. 新しいテスト用アカウントでログイン → 「AIへのデータ送信について」が出る。「同意しない」を選ぶ → カメラで撮ると「AIを使う機能は、AIへのデータ送信に同意すると使えます。」と出て、同意の画面がまた開く。
2. 設定 → 「AIへのデータ送信」→「内容を確認して同意する」→ 同意 → カメラで候補が出る。
3. Lovable Cloud の SQL で `select user_id, version, agreed_at, revoked_at, source from ai_consents order by agreed_at desc limit 5;` に行がある。
4. 設定で「同意を取り消す」→ `revoked_at` に時刻が入り、AI の機能が止まる（同じサーバではすぐ、遅くとも 1 分以内）。
5. ログアウトして `/welcome` のチュートリアル → 写真を撮って送る前に同意の画面が出る。登録した後、アプリに入った所でもう一度出る（登録前の同意は端末だけの記録なので）。

### Apple の取り消し
1. テスト用の Apple ID で「Apple でサインイン」→ SQL で `select user_id, token_type, updated_at from apple_tokens;` に行ができているか。
   - **行ができない時**: Lovable の OAuth の窓口が Apple の `provider_refresh_token` をアプリに渡していない、ということです（下の「限界」参照）。Claude に相談してください。
2. そのアカウントで 設定 → 退会。Lovable Cloud のログで `[apple-revoke] Apple の許可を取り消した` が出る。
   `設定が足りない` → 秘密の値が足りない／`invalid_client` → Services ID・鍵が Lovable Cloud の Apple ログインの物と違う。
3. iPhone の 設定 → Apple ID → サインインとセキュリティ → 「Apple でサインイン」の一覧から CatchWords が消えている。

### 最終確認画面
1. 設定 → CatchWords Pro →「月ごとで始める」→ 確認の画面に、値段（税込）・支払い時期・自動更新・解約の方法・返金・規約／特商法／プライバシーのリンクが出る。無料体験がある時は初回の請求日が出る。
2. 「規約に同意して購入する（定期購入）」で Stripe の画面が開き、申込みボタンの上に「有料の定期購入です…解約は…」の注意書きが出る（言語も画面に合う）。
3. 購入後、設定に「サブスクリプションを管理」が出て、Stripe の管理画面で解約できる。
4. 確認用ページ（Netlify の Deploy Preview）の `?scene=pro-plan` で、確認画面の見た目（月ごと・年ごと＋無料体験）を見られます。

---

## 7. iPhone 版でやること（別の作業）

`docs/ios-spec/23-ai-consent.md` に正確な仕様があります。要点:

- すべての `/api/native-fn` の呼び出しに見出し `AI-Consent-Version: 1` を付ける。
- 同意・取り消しのたびに `{"fn":"recordAiConsent","data":{"version":1,"agreed":true}}`（または `false`）を送る。
- ログインの後に `{"fn":"getAiConsent","data":{}}` で状態を読み、端末とサーバの記録をそろえる（この更新より前に iPhone で同意した人は、その同意を送る）。
- AI の関数が 403 `AI_CONSENT_REQUIRED` を返したら同意の画面を出す。
- 全員がその版になったら、オーナーが `AI_CONSENT_ENFORCE_NATIVE=true` を入れる。

Apple の取り消しは、iPhone 版も同じ Web のログイン（`/native-auth`）を使うので、iPhone 側の変更は要りません
（iPhone の `/native-auth` は、token をサーバに預け終わるのを最大 3 秒待ってからアプリに戻ります）。

---

## 8. 限界・注意

- **Apple の token が拾えるかは、公開してから確かめる必要があります。** ログインは Lovable の OAuth の窓口（`/~oauth/initiate`）を
  通っていて、窓口がアプリに渡す物は公開されていません（窓口の部品のコードは Supabase のログインの token 2つしか扱っていません）。
  Supabase 自体は Apple のサインインの直後に `provider_refresh_token` を1回だけ渡しますが、窓口がそれを戻り先の URL に
  載せなければ拾えません。拾えない場合でも退会は必ず終わり（取り消しは飛ばして記録に残す）、
  Apple の案内（TN3194）どおり、利用者は iPhone の設定から自分で外せます。拾えない時の別の道は、
  Apple のログインを Lovable の窓口を通さない Supabase の直のログイン（`supabase.auth.signInWithOAuth`）に変えるか、
  iPhone の純正の Apple ログインで得た authorization code をサーバで交換する方法です（どちらも追加の作業）。
- **この変更より前に Apple で登録した人は token が無い**ので、その人の退会では取り消しを飛ばします（記録に残す）。
  次にその人が Apple でサインインした時に token が預けられます。
- Apple の token は**サーバの鍵でしか触れない表**に平文で置いています（暗号化はしていません）。依頼の「少なくとも service-role だけ」を満たす形です。
- AI の同意: iPhone（`/api/native-fn`）は、移行期間中は見出しも環境変数も無ければ確かめません（古い iPhone 版を壊さないため。
  古い iPhone 版も端末の中で同意を確かめてから送っています）。この間、わざと見出しを外して直接呼べば同意なしで通せます。
- 登録前（チュートリアル）の同意はサーバに記録する相手がいないので、画面が送る「同意した版」を確かめるだけです（登録後に聞き直して記録します）。
- 同意の「あり」はサーバで 60 秒覚えます。取り消しは同じサーバではすぐ、他のサーバでも 1 分以内に効きます。
- 消費者庁のガイドラインの本文（caa.go.jp）は、この作業環境のネットワークの制限で開けませんでした。検索結果に出た
  ガイドラインの要約（分量・価格（定期購入は 2回目以降も）・支払の時期と方法・提供時期・申込期間・撤回と解除、
  「次へ」「送信」だけのボタンは不可）に合わせて作っています。公開前に、本文で一度確かめることをおすすめします。
- 実際に「申込みが確定する」ボタンは Stripe の支払い画面の物です。こちらの確認画面で全部を見せ、Stripe の画面にも
  注意書きを出していますが、Stripe の画面の項目（商品名・値段の書き方）は Stripe の管理画面の設定で決まります。
  商品名を「CatchWords Pro（月ごと）」のように分かる名前にしておいてください。
- 「支払いに失敗して一時的に Pro でなくなった人」（Stripe の past_due）には「サブスクリプションを管理」が出ません（前からの動き）。
  その人は Stripe からのメールのリンクで管理できます。
