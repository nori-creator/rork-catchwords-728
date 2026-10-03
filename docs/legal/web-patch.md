# Web 版の法務の頁への反映（オーナー向け手順）

作成: 2026-10-03／対象: Web リポジトリ `nori-creator/Lovable-catch-words-app` の **main 11ff3f0**／公開先 https://catchwords.lovable.app

> 前の版のこのファイルは、古い Web の写し（e67b63a）を見て「法務の頁が無い」前提で、新しい頁を丸ごと作る手順になっていました。**それは間違いでした。** 今の main には頁がもうあります。前の版の `docs/legal/web/privacy.tsx`・`terms.tsx`・`tokushoho.tsx`（別の頁を作る物）は消し、今の頁に足すだけの差分 `docs/legal/web/legal.patch` に置き換えました。

## 1. Web 版にもうある物（11ff3f0）

| 頁・仕組み | 場所 | 状態 |
|---|---|---|
| プライバシーポリシー（日本語が正文・英語・繁體中文） | `/privacy` ← `src/components/legal/privacy-{ja,en,zh-tw}.tsx` | 公開中。外部の事業者・広告・保存期間と削除（プロフィール写真も消える）・13歳未満・Cookie は書いてある |
| 利用規約（3言語） | `/terms` ← `src/components/legal/terms-{ja,en,zh-tw}.tsx` | 公開中。有料プラン・解約・無料体験・消費者契約法に沿った免責は書いてある |
| 特定商取引法に基づく表記（3言語） | `/legal/tokushoho` ← `src/components/legal/TokushohoDocument.tsx` | **「準備中」と出ている**（運営者の設定が無いため） |
| 運営者の値 | `src/lib/legal-config.ts`（計算）、`src/lib/legal.functions.ts`（サーバで `process.env` を読む）、`src/components/legal/operator.tsx`（表示） | 設定が無いので、プライバシー第12条・規約第12条に「運営者の連絡先は現在準備中です」と出ている |

足りなかった物: iPhone アプリの扱い（声で調べる・写真アプリ・Apple の地名検索・端末の中の保存・AI への送信の同意）、外国の事業者の国と制度、安全管理の措置（個人情報保護法32条）、台湾 個資法8条・GDPR・CCPA、App Store の条項、**サポートの頁（`/support`。iPhone アプリの設定と App Store Connect のサポート URL が開く。今は 404）**、**`/tokushoho`（iPhone アプリの初期のビルドが開く。今は 404）**。

## 2. 差分 `docs/legal/web/legal.patch` の中身

main 11ff3f0 に対する unified diff（`git apply` / `patch -p1` で当たる）。新しい頁を別に作らず、今の部品を直す。

| ファイル | 変更 |
|---|---|
| `src/components/legal/privacy-{ja,en,zh-tw}.tsx` | 第1・2・3・4・5・6・7・8・9・10・11・12条に iPhone アプリの扱いなどを書き足し、第14条「お住まいの地域ごとの追加事項」（台湾・EEA/英国/スイス・カリフォルニア）を足す。運営者は今までどおり `OperatorDetails`（設定から） |
| `src/components/legal/terms-{ja,en,zh-tw}.tsx` | 第1・2・4・5・6・11条に書き足し、第12条「App Store から入手した iPhone アプリについて」を足して、お問い合わせを第13条へ |
| `src/components/legal/SupportDocument.tsx`（新） `src/routes/support.tsx`（新） | `/support`。連絡先は `OperatorDetails`（`LEGAL_EMAIL` など）。単語の誤り・アカウントの削除・解約・AI の同意・個人情報の請求の案内（3言語） |
| `src/routes/tokushoho.tsx`（新） | `/tokushoho` → `/legal/tokushoho` へ 301 で転送 |
| `src/components/legal/LegalShell.tsx` | 法務のリンクの列（設定・ログイン・法務の頁の下）に「お問い合わせ・サポート」を足す |
| `src/lib/i18n.tsx` | `page.support`・`legal.support`（3言語） |
| `src/routes/sitemap[.]xml.ts` | `/support` を足す |
| `src/lib/legal-docs.test.ts` | 3言語に音声認識・IDFA・GDPR・CCPA・第14条、規約に App Store と第13条、サポートの頁と転送があることを確かめる |
| `src/lib/hardcoded-japanese.test.ts` `src/lib/i18n.test.ts` | 日本語版の行数と辞書の数を新しい値に |
| `src/routeTree.gen.ts` | `vite build` が作り直した物（Lovable でも自動で作られる） |

`legal-config.ts` と `TokushohoDocument.tsx` は変えていない（設定の仕組みと特商法の表はそのままで足りる）。

## 3. 当て方（どちらか）

### A. GitHub で当てる（おすすめ。文言がずれない）

Web リポジトリで新しいブランチを作り、`git apply docs/legal/web/legal.patch`（このファイルを Web リポジトリへ写してから）→ `npm run check` → PR → main へマージ。Lovable は GitHub の main を取り込むので、そのあと Lovable で **Publish → Update** する。Claude に頼む場合は「iOS リポジトリの docs/legal/web/legal.patch を Web の main に当てて PR にして」で通じる。

### B. Lovable のチャットに貼る（短い指示）

Lovable は差分をそのまま当てられないことがあるので、A ができないときだけ使う。下を貼り、**添付として legal.patch の中身も貼る**:

```
添付の unified diff（main 11ff3f0 向け）を、そのとおりに当ててください。文言は一字も変えないでください。
- 変えるのは src/components/legal/privacy-*.tsx・terms-*.tsx・LegalShell.tsx、src/lib/i18n.tsx、src/routes/sitemap[.]xml.ts と3つのテスト。
- 新しく作るのは src/components/legal/SupportDocument.tsx、src/routes/support.tsx（/support）、src/routes/tokushoho.tsx（/legal/tokushoho への 301 転送）。
- 別のプライバシーポリシーや特商法の頁を新しく作らないでください（今の頁を直すだけ）。
- 運営者の名前・住所・電話・メールを本文に直接書かないでください（src/lib/legal-config.ts の LEGAL_* から出す今の仕組みのまま）。
- 終わったら npm run check が通ることを確かめてください。
```

## 4. オーナーが入れる Secrets（これが無いと「準備中」のまま）

場所: Lovable でプロジェクトを開く → **Cloud → Secrets** →「追加」（Web リポジトリの `docs/ai-keys-guide.md` と同じ場所）。コードはサーバの `process.env` から読む（`src/lib/legal.functions.ts` の `getLegalInfo`）。**チャットには貼らず、Secrets の欄にだけ入れる。**

| 名前 | 必須 | 入れる物 |
|---|---|---|
| `LEGAL_SELLER_NAME` | ✓ | 販売事業者の名前。個人なら戸籍上の氏名（または登記した商号）、法人なら名称 |
| `LEGAL_EMAIL` | ✓ | 連絡先のメール（開示の請求・苦情・サポートもここ）。必ず読めるアドレス |
| `LEGAL_ADDRESS` | ✓ | 住所。出したくない場合は `ON_REQUEST`（「請求があれば遅滞なく開示します」と出る） |
| `LEGAL_PHONE` | ✓ | 電話番号。出したくない場合は `ON_REQUEST` |
| `LEGAL_REPRESENTATIVE` | | 代表者または運営責任者の氏名（法人は入れる） |
| `LEGAL_PRICE_NOTE` | | 価格の注記（例: `表示価格は税込です`） |
| `LEGAL_JURISDICTION_COURT` | | 第一審の専属的合意管轄の裁判所（例: `東京地方裁判所`）。無ければ「民事訴訟法の定めによる裁判所」と出る |
| `STRIPE_TRIAL_DAYS` | | 無料体験の日数。**未設定だと既定の 7 日**として規約・特商法に出る。体験を付けないなら `0` |

必須の4つ（メールは形が正しいこと）がそろうと、`/legal/tokushoho` に表が出て、本番の Stripe の購入口も開く（`checkoutAllowedByLegal`）。

**入れた後に、Lovable で Publish → Update を押して再公開する。** 差分を当てたときも同じ。

注意（個人情報保護法32条）: プライバシーポリシーには事業者の「住所」も要る。`LEGAL_ADDRESS=ON_REQUEST` のとき、プライバシー第12条は「請求があれば遅滞なく開示します」と出る（「本人の求めに応じて遅滞なく回答する」形）。個人で住所を出さない場合のこの書き方でよいかは、弁護士に確かめる（checklist.ja.md 2章）。

## 5. 公開できたかの確かめ方

```
curl -s https://catchwords.lovable.app/privacy | grep -c '準備中'          # 0 になること
curl -s https://catchwords.lovable.app/legal/tokushoho | grep -c '準備中'  # 0 になること
curl -s https://catchwords.lovable.app/privacy | grep -o 'IDFA\|GDPR' | sort -u  # 差分が入ったこと
curl -s -o /dev/null -w '%{http_code}\n' https://catchwords.lovable.app/support      # 200
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' https://catchwords.lovable.app/tokushoho  # 301 → /legal/tokushoho
```

（2026-10-03 の時点では /privacy・/terms・/legal/tokushoho は 200、/tokushoho と /support は 404。）

## 6. この差分を確かめた結果（2026-10-03）

Web の main（11ff3f0）を `git archive` で作業用の場所に出し、差分を当てて次を走らせた。

| 確かめた事 | 結果 |
|---|---|
| `patch -p1` で 11ff3f0 にそのまま当たる | 当たった |
| `npm ci` | 21 秒で入った |
| `tsc --noEmit` | 通った |
| `npm run i18n:check` | 通った |
| `eslint src --ext .ts,.tsx --quiet` | 通った |
| `vitest run` | 204 ファイル・3028 件すべて通った（足したテストを含む） |
| `vite build` | 通った（`routeTree.gen.ts` はこのとき作り直した物） |
| `vite dev` に仮の `LEGAL_*` を入れて SSR を取る | `/support`・`/privacy`・`/terms` が 200 で運営者名とメールが出た。`/tokushoho` は 301 で `/legal/tokushoho` へ |

Lovable の本番（Cloudflare）では動かしていない。再公開の後に 5章で確かめる。

## 7. iOS 側との対応

- iPhone アプリの特商法のリンクは `/legal/tokushoho` に直した（`ios/CatchWords/AppConfig.swift`）。初期のビルドの `/tokushoho` は、この差分の転送で開く。
- iPhone アプリの「お問い合わせ・サポート」は `/support` を開く。App Store Connect のサポート URL にも `https://catchwords.lovable.app/support` を入れる（`LEGAL_EMAIL` を入れた後なら連絡先が出る）。
- AI の同意画面の「プライバシーポリシー（第4条・第5条）」は、この差分の章立て（第4条 外部の事業者・第5条 外国にある事業者）に合わせてある。
- 文書の全文（3言語）は `docs/legal/privacy-policy.*.md`・`terms.*.md`・`tokushoho.ja.md`。この差分の TSX と同じ文言。
