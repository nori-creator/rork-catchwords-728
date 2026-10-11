# 審査への返信（2026-10-06 の Guideline 2.1 - Information Needed への答え）

最終更新: 2026-10-11（アプリの中身の変更を反映: 本棚・日記・スキャン・声で調べるを外した版、学ぶ言語は台湾華語、撮影の流れ v10。ログインの入口とボタンの名前は、不具合修正の PR #23 の新しいウェルカム画面に合わせた）

## これは何か

2026-10-06 に Apple から「Guideline 2.1 - Information Needed」（追加の情報がほしい）という連絡が来た。アプリの欠陥で落ちたのではなく、審査の履歴が少ない新しい開発者アカウントに来る**情報の依頼**。次の 6 つを、App Store Connect の返信欄と「App Review Information」の **Notes** 欄の両方に書くよう求められている。

1. 実機（最新の iOS）で撮った画面録画。起動から始め、アカウント登録・ログイン・アカウント削除を含める
2. アプリの目的と、誰向けか
3. 使い方と、ログイン情報
4. 使っている外部サービスの一覧（AI・ログイン・決済など）
5. 地域による違いの有無
6. 許認可が要る業種か、他社の保護された素材を使っているか

- **返信欄**には下の「返信の本文（英語）」をそのまま貼り、画面録画を添付する。
- **Notes 欄**は 4000 バイトまでなので、短くまとめた `review-notes.en.txt` を貼る（`App Store metadata` ワークフローで入れることもできる）。
- **審査用アカウントのメールとパスワードは、ここにも Notes にも書かない。** App Store Connect の「サインイン情報」の欄（すでに入っている）にだけ置く（このリポジトリは公開）。

`[ ]` の所は、送る前に埋める。

---

## 返信の本文（英語・このまま貼る）

```
Thank you for your review. Please find the requested information below. A screen recording captured on a physical iPhone running the latest iOS is attached. The build for review is 1.0.0 ([BUILD NUMBER]).

1. Screen recording
Attached. It starts by launching the app and shows: creating a new account with email, the first-run setup and the consent screen for sending data to AI, the main flow (photograph an object, word tags appear on the objects, tap a word, its sticker, word and pronunciation appear and it is added to the collection), the collection and a word's details with pronunciation, a review question, signing out and signing in again, and deleting the account in the app (Settings > Delete account).
The app has no content shared between users (no social features, no messaging) and no paid content: this version is free with no in-app purchases.

2. Purpose and target audience
CatchWords is a vocabulary app for people learning Taiwanese Mandarin (Traditional Chinese as used in Taiwan), mainly Japanese- and English-speaking teenagers and adults. The learner photographs things around them; the app finds the objects in the photo and shows the Taiwanese Mandarin word on each one, including the different ways people actually say it (for example 面紙 / 衛生紙 for "tissue"), each with a short note on when it is used. The learner taps the word they want; it is saved to their personal collection as a sticker cut out of their own photo, with zhuyin, pinyin, meaning, pronunciation audio and example sentences. Saved words come back in short spaced-repetition review questions that show the learner's own photos.
The problem it solves: words memorized from lists are quickly forgotten, and textbooks often teach words that differ from what people in Taiwan actually say. Words linked to real objects from the learner's own day, in the variant they choose, are easier to remember and to use.

3. How to access the main features
The demo account is entered in the App Review Information "Sign-in information" fields. It has finished the first-run setup and the AI consent and already has saved words.
- Launch the app > on the first screen tap "Sign in with email" > enter the demo account's email and password > "Sign in". The demo account shows the app in English (Settings > Language > Your language switches between English and Japanese).
- Camera tab: photograph any everyday object (a cup, a bottle, a chair), or pick a photo with the Photos button. Word tags appear on the objects after a few seconds. Tap a word: its sticker, the word and its pronunciation appear and the word is added to the collection. A word that is not shown can be looked up with "Type a different word".
- Collection tab: tap a word to see its details; tap the speaker button to hear it.
- Review tab: answer a few 4-choice questions.
- Settings: languages and level, sounds, notifications, Legal (Terms of Use, Privacy Policy, consent to send data to AI), Sign out, and Delete account at the bottom.
No sample files are needed. Camera, photo library, location and notification permissions are optional and are asked for only when the related feature is used.
Some diagnostic screens in Settings are shown only to the developer's own account; they do not appear for other users or the demo account and do not change the app's features.

4. External services used
- Our own server (catchwords.lovable.app, hosted on Lovable Cloud with Supabase and Cloudflare): sign-in, database and private photo storage. The app talks only to this server for its data.
- Sign in with Apple and Google Sign-In: optional sign-in methods (email and password is also available).
- AI: Google Gemini finds the objects in a photo and writes the word explanations and example sentences. It is called from our server, and only after the user agrees on the in-app consent screen "Sending data to AI". If Google does not answer within a few seconds, the same photo request is also sent to Lovable AI Gateway, which relays it to Google's Gemini models. The operator may switch an individual AI feature to another provider named in our privacy policy (for example Anthropic Claude); any provider receives the data only after the same consent.
- Microsoft Azure AI Speech: pronunciation audio for Taiwanese Mandarin (only the text of the word or sentence is sent). Apple's on-device speech is used when the server voice is not available.
- Unsplash and Wikimedia Commons: optional replacement photos for a word, chosen by the user (only the search word is sent; the photographer is credited). Higgsfield: may draw an illustration for a word that has no photo.
- Apple on the device: Vision (cutting out objects and outlining them), place names for the photo location (only if location access is allowed), local notifications for optional reminders, and Home Screen widgets.
There is no payment processor, and no advertising or analytics SDK in the app.

5. Regional differences
The app works the same in every territory where it is offered; there are no region-specific features or content. Every account learns Taiwanese Mandarin. The interface is in English or Japanese, chosen in the first-run setup and changeable in Settings; the sign-in screens follow the device language. [We removed China mainland from the territories.]

6. Regulated industry / third-party material
The app is not in a regulated industry and does not include protected third-party material. Word explanations and example sentences are generated by AI for each user; optional photos from Unsplash (Unsplash License) and Wikimedia Commons (free licenses) are shown with credit; all other photos are taken by the user.
```

---

## 日本語の訳（オーナーが内容を確かめるため。送るのは上の英語）

1. **画面録画**: 添付。アプリの起動から、メールでの新規登録、最初の設定と AI への送信の同意画面、撮影の流れ（物を撮る → 物の上に単語のタグが出る → 単語をタップ → ステッカーと単語と発音が出て図鑑に入る）、図鑑と単語の詳細（発音）、復習の1問、ログアウトと再ログイン、アプリ内でのアカウント削除（設定 → アカウントを削除）まで。利用者どうしで共有する内容（SNS・メッセージ）は無く、有料の内容も無い（無料・アプリ内課金なし）。
2. **目的と対象**: 台湾華語（台湾で使う繁体字の中国語）を学ぶ人、主に日本語・英語を話す 10 代以上向けの単語アプリ。身の回りの物を撮ると、物を見つけて台湾華語の単語を物の上に出す。同じ物の言い方が複数ある場合（ティッシュ＝面紙／衛生紙）は、使い分けの短い説明つきで並べる。選んだ単語は、自分の写真から切り抜いたステッカーとして、注音・ピンイン・意味・発音・例文と一緒に図鑑に入る。間隔をあけた復習で、自分の写真を使って出題する。解決すること: 単語表で覚えた語は忘れやすく、教科書の語は台湾で実際に使う語と違うことが多い。自分の一日の中の本物の物と、自分で選んだ言い方で覚えると、覚えやすく使いやすい。
3. **使い方**: 審査用アカウントは「サインイン情報」の欄に入れてある（最初の設定と AI の同意は済み、単語も入っている）。起動して最初の画面の「メールでログイン」→ メールとパスワード →「ログイン」。審査用アカウントは英語の表示にしてある（設定 → 言語 → 母語 で英語と日本語を切り替えられる）。カメラのタブで物を撮る（写真アプリの写真も可）→ 数秒で物の上にタグが出る → タップすると図鑑に入る。無い言葉は「違う単語を入力」。図鑑のタブで単語を開き、スピーカーで発音。復習のタブで4択に答える。設定: 言語とレベル、音、通知、規約と表記（利用規約・プライバシーポリシー・AI への送信の同意）、ログアウト、一番下にアカウントを削除。サンプルのファイルは不要。カメラ・写真・位置・通知の許可は任意で、その機能を使う時だけ聞く。設定の中の診断用の画面は開発者本人のアカウントにだけ出て、ほかの利用者や審査用アカウントには出ない。
4. **外部サービス**: 当社のサーバ（catchwords.lovable.app。Lovable Cloud・Supabase・Cloudflare の上）: ログイン・データベース・写真の保存。Apple でサインイン・Google でログイン（メールとパスワードでも可）。AI: Google Gemini（写真の物の判定、説明と例文の作成）。当社のサーバから呼び、アプリ内の同意画面で同意した後だけ。Google が数秒で答えない時は、同じ写真の依頼を Lovable AI Gateway（Google の Gemini へ中継する）にも送る。運営者は機能ごとに、プライバシーポリシーに書いた他の AI（Anthropic Claude など）に切り替えることがあり、どの AI にも同じ同意の後だけ送る。Microsoft Azure AI Speech: 台湾華語の発音（単語・例文の文字だけを送る）。サーバの声が使えない時は iPhone 本体の声。Unsplash・Wikimedia Commons: 利用者が選ぶ差し替え用の写真（検索の言葉だけを送り、撮影者を表示）。Higgsfield: 写真の無い単語に絵を描くことがある。iPhone の中の Apple の機能: Vision（切り抜きと輪郭）、写真の場所の地名（位置の許可がある時だけ）、通知、ウィジェット。決済サービス・広告や分析の SDK は入っていない。
5. **地域の違い**: どの国でも同じ。どのアカウントも台湾華語を学ぶ。表示は英語か日本語（最初の設定で選び、設定で変えられる）。ログインの画面は端末の言語に合わせる。［配信国から中国本土を外した］
6. **規制業種・他社の素材**: 規制業種ではなく、他社の保護された素材も使っていない。説明と例文は利用者ごとに AI が作る。Unsplash（Unsplash ライセンス）と Wikimedia Commons（自由なライセンス）の写真は撮影者を表示して使う。ほかの写真は利用者が撮ったもの。

---

## 送る前に確かめること

- [ ] **不具合修正の PR #23 がビルドに入っていること**: 返信・Notes・録画の手順のボタンの名前（「Sign in with email」「New here? Sign up」など）は、PR #23 の新しいウェルカム画面に合わせてある。PR #23 がまだ変わる場合は、マージ後の画面で名前を見直す。
- [ ] **審査に出すビルドを決める**: 不具合を直している別の作業が終わってから、`iOS release` でビルドを送り、TestFlight の実機で一通り動かす。返信の 1 行目の `[BUILD NUMBER]` をそのビルドの番号にする（2026-10-11 時点の最新は 1022）。
- [ ] **画面録画は、そのビルドで撮る**（手順は `screen-recording.ja.md`）。録画の中の画面と、上の文章（ボタンの名前など）が合っていること。1 に書いた場面（登録・同意・撮影・図鑑・復習の1問・ログアウトと再ログイン・削除）が全部録画に入っていること。入っていない場面があれば、1 の文からその場面を消す。
- [ ] **配信国を決めてから 5 を確定する**: 中国本土を外したら `[We removed China mainland from the territories.]` を残し、外さなければその文を消す（`README.md` の「決めること」）。
- [ ] **審査用アカウント**（「サインイン情報」に入っているもの）でログインでき、学ぶ言語が台湾華語、最初の設定と AI の同意が済み、単語が 10 語ほど入っていること（10/11 にデータベースで確かめた: 学ぶ言語・同意・単語 13 語は済み。**「初回設定済み」の印 `profiles.onboarded` が false** なので true にする。印が無いと、新しい端末でログインした直後に最初の案内が一瞬出ることがある）。
- [ ] **審査用アカウントの表示を英語にする**: そのアカウントでログイン → 設定 → 言語 →「母語」を English。ログインすると、アカウントに保存された表示の言語にアプリが切り替わるため、日本語のままだと審査の担当者が日本語の画面を見ることになる（返信の 3 と Notes に「英語の表示」と書いてある）。
- [ ] 外部サービスの一覧（4）は 2026-10-11 のコードと Secrets の確認（10-09）に基づく。Lovable の開発者の設定で AI の切り替えを変えた場合は、4 を合わせる。
