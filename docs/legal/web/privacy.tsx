import { CHINESE_EXPLANATION_LANGUAGE } from "@/lib/target-lang";
import { siteUrlFor } from "@/lib/site-url";
import { createFileRoute, Link } from "@tanstack/react-router";
import { tStatic, useUiLang, useT } from "@/lib/i18n";

/**
 * プライバシーポリシー。
 *
 * 法務文書は翻訳キーに刻むのではなく、言語ごとに文書そのものを持つ。
 * 条文は単語の置き換えではなく文章として成り立っていないと意味がなく、
 * `t()` で細切れにすると、後から条項を直したときに片方だけ古くなる。
 *
 * 正本は iOS リポジトリの docs/legal/privacy-policy.{ja,en,zh-TW}.md。
 * 3言語は同じ章立て・同じ番号。直すときは3つとも直す。
 *
 * 共有用メタ文(og:description)は日本語のまま。あれは表示言語ではなく
 * 「どの市場に向けた紹介文か」の話。
 */

export const Route = createFileRoute("/privacy")({
  head: () => ({
    meta: [
      { title: tStatic("page.privacy") },
      {
        name: "description",
        content:
          "CatchWordsのプライバシーポリシー。取得する情報、利用目的、AIの利用、外国の委託先、位置情報・写真の取り扱い、保存期間、データ削除と開示請求の手続きについて説明します。",
      },
      { property: "og:title", content: "プライバシーポリシー — CatchWords" },
      {
        property: "og:description",
        content:
          "CatchWordsのプライバシーポリシー。取得する情報、利用目的、AIの利用、外国の委託先、位置情報・写真の取り扱い、保存期間、データ削除と開示請求の手続きについて説明します。",
      },
      { property: "og:type", content: "article" },
      { property: "og:url", content: siteUrlFor("/privacy") },
    ],
    links: [{ rel: "canonical", href: siteUrlFor("/privacy") }],
  }),
  component: PrivacyPage,
});

function PrivacyJa() {
  return (
    <>
      <h1 className="mt-4 text-hero font-bold tracking-tight">プライバシーポリシー</h1>
      <p className="mt-1 text-footnote text-muted-foreground">
        制定日: 【制定日（例: 2026年10月○日）】
      </p>
      <p className="mt-1 text-footnote text-muted-foreground">最終更新: 【最終更新日】</p>
      <section className="prose prose-sm mt-6 max-w-none dark:prose-invert">
        <p>
          【運営者名】（以下「当社」）は、語学学習サービス「CatchWords」（iPhone アプリ、Web 版{" "}
          <a href={siteUrlFor("/")}>{siteUrlFor("/")}</a>{" "}
          、およびこれらに付随するサービスを含み、以下「本サービス」）における利用者の情報の取り扱いを、次のとおり定めます。当社は、日本の個人情報の保護に関する法律（以下「個人情報保護法」）その他の法令を守ります。台湾・欧州連合（EU）・英国など、日本以外にお住まいの方には、お住まいの地域の法令が定める権利も保障します（第13章）。
        </p>
        <h2>1. 運営者</h2>
        <ul>
          <li>事業者の名称: 【運営者名】</li>
          <li>住所: 【住所】</li>
          <li>代表者: 【代表者氏名（法人の場合）／個人の場合は「同上」】</li>
          <li>
            個人情報の取り扱いに関する責任者・お問い合わせ窓口:
            【お問い合わせメールアドレス】（第15章）
          </li>
        </ul>
        <h2>2. 取得する情報と取得の方法</h2>
        <h3>2-1. 利用者が入力・提供する情報</h3>
        <ul>
          <li>
            アカウント情報:
            メールアドレス、パスワード（暗号化して保存され、当社が読むことはできません）、表示名、アバター画像
          </li>
          <li>
            Apple または Google でログインした場合: その事業者から受け取るメールアドレス（Apple
            の「メールを非公開」を選んだ場合は Apple が発行する転送用アドレス）と、利用者を識別する
            ID。Apple・Google のパスワードを当社が受け取ることはありません
          </li>
          <li>
            学習の設定:
            学ぶ言語、表示言語、レベル、学習の目的・興味・1日の学習時間など、はじめの設定で答えた内容
          </li>
          <li>
            撮影した写真・自撮り写真、写真アプリから選んだ画像（単語帳のページなど）、それらから作った切り抜き（ステッカー）
          </li>
          <li>日記・ひとことメモ・キャプションなど、利用者が書いた文章</li>
          <li>復習で答えた内容（入力した文字や、話して答えた内容を文字にしたもの）</li>
          <li>単語の誤りの報告など、利用者が送った内容</li>
          <li>お問い合わせの内容と連絡先</li>
        </ul>
        <h3>2-2. 本サービスの利用にともなって取得する情報</h3>
        <ul>
          <li>
            位置情報:
            撮影したときの位置（緯度・経度）と、そこから求めた地名。端末の設定で利用者が許可した場合だけ取得し、許可しなくても他の機能は使えます
          </li>
          <li>学習の記録: 集めた単語、復習の結果・スコア、連続学習日数、出会った回数など</li>
          <li>
            スキャンの記録:
            カメラをかざして見つかった単語、その単語を押したか・保存したか、（位置情報を許可している場合）その位置
          </li>
          <li>
            利用状況:
            本サービスを開いた日時、使った画面、撮影・スキャン・復習などの回数とかかった時間、AI
            機能の利用回数
          </li>
          <li>
            技術的な情報: 通信のために必要な IP アドレス、端末・ブラウザの種類、エラーの記録（Web
            版の不具合の調査のため）
          </li>
          <li>
            有料プランの情報（第8章）:
            プランの種類、購入日・有効期限、決済事業者が発行する取引の識別子
          </li>
        </ul>
        <h3>2-3. 音声（マイク・音声認識）</h3>
        <p>
          iPhone アプリの「声で調べる」では、マイクと Apple の音声認識を使います。音声は Apple
          の音声認識で文字にされ、端末内に認識の仕組みがない言語では Apple
          のサーバに送られて処理されます（Apple
          のプライバシーポリシーが適用されます）。当社が音声そのものを受け取ったり保存したりすることはなく、当社のサーバに送られるのは文字にした結果だけです。マイクと音声認識は、利用者が端末の設定で許可した場合だけ使います。
        </p>
        <h3>2-4. 端末の中だけに保存する情報</h3>
        <p>
          次の情報は利用者の端末の中に保存し、当社のサーバには送りません（ただし、書いた日記を保存したときや、通信が戻って写真を送ったときは、その時点で第2-1の情報として当社に届きます）。
        </p>
        <ul>
          <li>
            ログインを続けるための情報（iPhone ではキーチェーン、Web
            版ではブラウザのローカルストレージに保存）
          </li>
          <li>表示や音などの設定</li>
          <li>
            ホーム画面のウィジェットに表示する単語・写真の縮小画像・復習の数（アプリとウィジェットの共有領域に保存）
          </li>
          <li>
            予約した通知（復習のリマインダー、「場所でリマインド」）。「場所でリマインド」は、単語を撮った場所の近くに来たときに端末が通知を出す機能で、その場所の判定は端末の中で行われ、当社に現在地を送ることはありません
          </li>
          <li>通信できなかったときに送るのを待っている写真（「解析待ち」）、書きかけの日記</li>
          <li>表示を速くするための画像や音声の一時的な保存</li>
        </ul>
        <p>
          これらは、アプリを削除すると端末から消えます。アカウントを削除したときは、アプリがこれらも端末から消します。
        </p>
        <h3>2-5. ログインしないでの体験（Web 版）</h3>
        <p>
          Web 版では、ログインする前に1回、写真から単語を作る体験ができます。このとき写真は AI
          で処理するために送られますが、当社のサーバには保存しません。使いすぎを防ぐため、IP
          アドレスをそのまま保存せず、日ごとに変わる方法で元に戻せない形（ハッシュ値）に変えたものを、その日の回数を数えるためだけに使います。
        </p>
        <h2>3. 利用目的</h2>
        <p>当社は、取得した情報を次の目的で利用します。</p>
        <ol>
          <li>
            本サービスの提供・運営（アカウントの作成と認証、データの保存と端末間の同期、通知の送信を含む）
          </li>
          <li>
            AI
            による単語の候補の提示、単語カード・解説・例文・クイズの作成、日記や答えの添削、発音の読み上げ
          </li>
          <li>地図・図鑑・アルバム・カレンダーなど、撮影した場所や日付を使う機能の提供</li>
          <li>1日あたりの AI 利用回数の上限の管理、不正利用・迷惑行為の防止、セキュリティの確保</li>
          <li>
            不具合の調査とサービスの改善。このために、運営者が利用者ごとの利用状況の数値（撮影や復習の回数、利用した日、画面ごとの利用など）を閲覧・分析することがあります。このとき、メールアドレス、正確な位置（緯度・経度）、写真、日記やひとことの本文は閲覧の対象に含めません
          </li>
          <li>
            利用者全体の統計（利用者数・継続して使う人の割合など）の作成。統計は個人を特定できない形で扱います
          </li>
          <li>有料プランの提供、お支払いの確認と管理</li>
          <li>お問い合わせへの対応、重要なお知らせ（規約・本ポリシーの変更など）の連絡</li>
          <li>法令や利用規約への違反への対応、法令に基づく対応</li>
        </ol>
        <p>
          当社は、利用者の情報を販売しません。行動を追跡して広告を表示すること（ターゲティング広告）にも使いません。当社自身が、利用者の写真や日記を
          AI モデルの学習に使うこともありません。
        </p>
        <h2>4. AI の利用について</h2>
        <p>
          本サービスは、写真に写っている物の判定や、単語カード・解説・添削の作成に、外部の事業者が提供する
          AI（大規模言語モデル）を使います。AI の機能を使うと、次の情報がその事業者に送られます。
        </p>
        <ul>
          <li>写真（撮影した写真、写真アプリから選んだ画像、単語帳のページ）</li>
          <li>単語・文章（調べた単語、日記・ひとことの本文、復習の答え、誤りの報告の内容）</li>
          <li>学ぶ言語・表示言語・レベルなど、回答を作るのに必要な設定</li>
        </ul>
        <p>
          AI
          に送る情報には、メールアドレスや名前を含めません。送り先の事業者と国は第6章のとおりです。当社は、送った情報を
          AI の事業者が自らの AI の学習に利用しない条件の契約・設定で利用するよう努めます。AI
          が作った内容は誤りを含むことがあります（利用規約をご覧ください）。
        </p>
        <p>
          本サービスは、初めて AI の機能を使う前に、上記の情報を AI
          の事業者へ送ることについて利用者の同意をいただきます。同意しない場合、写真から単語を作る機能など
          AI
          を使う機能は利用できませんが、それ以外の機能（集めた単語の閲覧・復習の一部など）は利用できます。
        </p>
        <h2>5. 第三者への提供</h2>
        <p>
          当社は、次の場合を除き、あらかじめ利用者の同意を得ないで個人情報（個人データ）を第三者に提供しません。
        </p>
        <ul>
          <li>法令に基づく場合</li>
          <li>人の生命・身体・財産の保護のために必要で、本人の同意を得ることが難しい場合</li>
          <li>国の機関などの法令の定める事務に協力する必要がある場合</li>
          <li>
            事業の承継（合併・事業譲渡など）にともなう場合。この場合も、本ポリシーと同じ水準で取り扱われるようにします
          </li>
        </ul>
        <p>第6章の事業者への送信は、本サービスを提供するための業務の委託として行います。</p>
        <h2>6. 業務の委託先と、外国にある第三者への提供</h2>
        <p>
          当社は、本サービスの提供に必要な範囲で、次の事業者に情報の取り扱いを委託しています。これらの事業者の多くは日本の外にあり、情報は日本の外で保存・処理されます。当社は、各事業者が利用規約・データ処理契約などで、個人情報保護法の定める措置に相当する措置（安全管理、目的外利用の禁止など）を講じていることを確認したうえで利用し、本ポリシーと同等の保護が保たれるよう努めます。
        </p>
        <h3>6-1. 主な委託先</h3>
        <table>
          <thead>
            <tr>
              <th>事業者</th>
              <th>所在国</th>
              <th>渡る情報</th>
              <th>目的</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Supabase, Inc.（Lovable Cloud を通じて利用）</td>
              <td>
                米国（データの保存場所: 【Supabase のデータ保存地域（例:
                米国／シンガポール／東京）】）
              </td>
              <td>
                アカウント情報、写真、日記、学習の記録、位置情報、利用状況など、本サービスのデータ全般
              </td>
              <td>データベース・認証・ファイルの保存</td>
            </tr>
            <tr>
              <td>Lovable Labs Sweden AB および Lovable Labs Incorporated</td>
              <td>スウェーデン、米国</td>
              <td>
                本サービスのサーバを通る通信の内容、AI への依頼の中継（第4章の情報）、Apple・Google
                でのログインの中継、Web 版のエラーの記録
              </td>
              <td>Web 版とサーバの運用、AI への中継、ログインの中継</td>
            </tr>
            <tr>
              <td>Google LLC</td>
              <td>米国</td>
              <td>
                写真・文章（Gemini による AI 処理）、読み上げる文字（音声合成）、緯度・経度（Web
                版の地名の取得と地図の表示）、Google でログインした場合の認証情報
              </td>
              <td>AI 処理、音声合成、地図・地名、ログイン</td>
            </tr>
            <tr>
              <td>Apple Inc.</td>
              <td>米国</td>
              <td>
                Apple
                でログインした場合の認証情報、音声（端末内で認識できない場合）、緯度・経度（iPhone
                アプリの地名の取得）、アプリ内課金の購入情報
              </td>
              <td>ログイン、音声認識、地名、アプリ内課金</td>
            </tr>
            <tr>
              <td>Stripe, Inc.（日本では Stripe Japan 株式会社を通じて利用）</td>
              <td>米国</td>
              <td>
                メールアドレス、利用者 ID、お支払いの情報（カード番号は Stripe
                だけが扱い、当社は受け取りません）
              </td>
              <td>Web 版の有料プランの決済</td>
            </tr>
          </tbody>
        </table>
        <h3>6-2. 任意の提供先（当社が AI や読み上げの提供元を切り替えた場合だけ使う）</h3>
        <table>
          <thead>
            <tr>
              <th>事業者</th>
              <th>所在国</th>
              <th>渡る情報</th>
              <th>目的</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>OpenAI, L.L.C.</td>
              <td>米国</td>
              <td>第4章の情報</td>
              <td>AI 処理</td>
            </tr>
            <tr>
              <td>Anthropic, PBC</td>
              <td>米国</td>
              <td>第4章の情報</td>
              <td>AI 処理</td>
            </tr>
            <tr>
              <td>OpenRouter, Inc.</td>
              <td>米国（依頼の内容は、選んだ AI モデルの提供元の国に送られます）</td>
              <td>第4章の情報</td>
              <td>AI 処理の中継</td>
            </tr>
            <tr>
              <td>Microsoft Corporation（Azure AI Speech）</td>
              <td>米国（処理地域: 【Azure のリージョン】）</td>
              <td>読み上げる文字</td>
              <td>音声合成</td>
            </tr>
            <tr>
              <td>ElevenLabs, Inc.</td>
              <td>米国</td>
              <td>読み上げる文字</td>
              <td>音声合成</td>
            </tr>
            <tr>
              <td>【3D 生成の事業者名（例: Tripo3D の運営会社）】</td>
              <td>【所在国】</td>
              <td>写真（Pro の 3D 機能を使った場合）</td>
              <td>写真からの 3D モデルの作成</td>
            </tr>
          </tbody>
        </table>
        <h3>6-3. 個人情報を含まない外部サービス</h3>
        <p>
          画像の検索・生成、候補の並べ替えなどのために、Unsplash、Wikimedia
          Commons、Higgsfield、【typesafe（JEV）の運営会社】などに単語の文字列を送ることがあります。これらには、写真・日記・メールアドレスなど利用者を特定できる情報は送りません。
        </p>
        <h3>6-4. 外国の個人情報保護の制度</h3>
        <ul>
          <li>
            米国:
            連邦レベルの包括的な個人情報保護法はなく、分野ごとの連邦法と、カリフォルニア州消費者プライバシー法（CCPA）などの州法があります。
          </li>
          <li>
            スウェーデン（EU）: EU 一般データ保護規則（GDPR）が適用されます。EU
            は、個人情報保護委員会が日本と同等の水準にあると認めた国・地域です。
          </li>
          <li>
            各国の制度の詳細は、個人情報保護委員会が公表している外国の制度の調査結果（米国:{" "}
            <a
              href="https://www.ppc.go.jp/enforcement/infoprovision/laws/offshore_report_america/"
              target="_blank"
              rel="noopener noreferrer"
            >
              https://www.ppc.go.jp/enforcement/infoprovision/laws/offshore_report_america/
            </a>{" "}
            ）をご覧ください。
          </li>
        </ul>
        <p>
          委託先が講じている措置について詳しい情報をご希望の場合は、第15章の窓口へご請求ください。遅滞なくお知らせします。
        </p>
        <h2>7. 位置情報と写真の扱い</h2>
        <ul>
          <li>
            位置情報は、撮影した場所の記録と、地図・アルバム・「場所でリマインド」の表示のためだけに使います。位置情報を他の利用者に公開する機能は、現在ありません。
          </li>
          <li>
            地名は、iPhone アプリでは Apple、Web 版では Google
            のサービスに緯度・経度を送って求めます。
          </li>
          <li>
            写真は、利用者本人の図鑑・アルバムに表示するために保存します。他の利用者に公開する機能は、現在ありません。
          </li>
          <li>
            「写真アプリにも保存」を有効にした場合、撮った写真を端末の写真アプリに保存します。写真アプリからの読み込みは、利用者が選んだ画像だけを対象にします。
          </li>
          <li>
            位置情報の利用は、端末の設定からいつでもやめられます。過去に記録した位置は、単語ごとに削除するか、アカウントを削除することで消せます。
          </li>
        </ul>
        <h2>8. 有料プランとお支払い</h2>
        <ul>
          <li>
            iPhone アプリの有料プラン（提供を開始した場合）は、Apple
            のアプリ内課金で購入します。お支払いは Apple
            が処理し、当社はカード番号などのお支払い方法の情報を受け取りません。当社は、購入が有効かを確かめるため、Apple
            から購入の記録（商品・期間・取引の識別子など）を受け取り、アカウントと結び付けます。
          </li>
          <li>
            Web 版の有料プランは、Stripe で決済します。カード番号は Stripe
            だけが扱い、当社は受け取りません。当社は、プランの状態を管理するため、Stripe の顧客
            ID・購読の状態を受け取ります。
          </li>
        </ul>
        <h2>9. 保存期間と削除</h2>
        <table>
          <thead>
            <tr>
              <th>情報</th>
              <th>保存期間</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>アカウント情報、写真、日記、学習の記録、位置情報、利用状況</td>
              <td>アカウントを削除するまで</td>
            </tr>
            <tr>
              <td>写真から作った解析の記録・AI 利用回数の記録</td>
              <td>アカウントを削除するまで</td>
            </tr>
            <tr>
              <td>お問い合わせの内容</td>
              <td>対応が終わってから【3年】</td>
            </tr>
            <tr>
              <td>有料プランの取引の記録</td>
              <td>法令で保存が義務づけられた期間（日本の税法では原則7年）</td>
            </tr>
            <tr>
              <td>ログインしない体験の回数の記録（ハッシュ値）</td>
              <td>その日の回数の制限のためにのみ使用</td>
            </tr>
            <tr>
              <td>システムのバックアップに残った複製</td>
              <td>削除から【30日】以内に消去</td>
            </tr>
          </tbody>
        </table>
        <p>
          アカウントの削除: iPhone アプリ・Web
          版の「設定」→「アカウントを削除」から、いつでもアカウントと関連データ（写真・単語カード・学習の記録・日記・アバター画像など）を削除できます。削除は取り消せません。利用者が登録した単語の見出し語などで、他の利用者と共有している辞書のデータは、利用者との結び付きを消したうえで残ることがあります。読み上げの音声は、個人と結び付かない形で共有の一時保存領域に残ることがあります。アプリ内課金の購読は、アカウントを削除しても自動では止まりません。先に
          Apple ID の設定から解約してください。
        </p>
        <h2>10. 安全管理のために講じている措置</h2>
        <p>当社は、個人情報の漏えい・滅失・毀損を防ぐため、次の措置を講じています。</p>
        <ul>
          <li>
            基本方針の策定: 本ポリシーを定め、関係法令・ガイドラインを守ることを定めています。
          </li>
          <li>
            取り扱いの規律:
            取得・利用・保存・提供・削除の各段階で、取り扱い方法・責任者を定めています。
          </li>
          <li>
            組織的な措置:
            責任者を置き、法令や本ポリシーに反する取り扱いや漏えいの兆候を知ったときの報告・対応の手順を定めています。
          </li>
          <li>
            人的な措置: 個人情報を取り扱う者に、秘密の保持と適切な取り扱いを徹底させています。
          </li>
          <li>
            物理的な措置:
            個人情報を扱う端末の盗難・紛失を防ぎ、画面のロック・保存の暗号化を行っています。
          </li>
          <li>
            技術的な措置:
            通信は暗号化（HTTPS）し、データベースは利用者が本人のデータだけを読み書きできるように行ごとのアクセス制御をかけています。秘密の鍵はサーバだけで管理し、アプリには含めていません。運営者が利用状況を見る画面では、メールアドレス・正確な位置・写真・日記の本文を表示しません。
          </li>
          <li>
            外的環境の把握:
            第6章の外国の事業者を利用するにあたり、その国の個人情報保護の制度を把握したうえで、安全管理のための措置を講じています。
          </li>
        </ul>
        <h2>11. 開示・訂正・利用停止などのご請求</h2>
        <p>
          利用者は、当社が保有する自分の個人情報（保有個人データ）について、利用目的の通知、開示（第三者に提供した記録の開示を含む）、内容の訂正・追加・削除、利用の停止・消去、第三者への提供の停止を請求できます。
        </p>
        <ul>
          <li>多くの情報は、アプリの中で自分で確認・修正・削除できます。</li>
          <li>
            それ以外のご請求は、第15章の窓口へメールでご連絡ください。ご本人（または代理人）であることを確認したうえで、法令に従い遅滞なく対応します。
          </li>
          <li>手数料はいただきません。</li>
          <li>法令により応じられない場合は、その理由をお知らせします。</li>
        </ul>
        <h2>12. 未成年の方の利用</h2>
        <p>
          本サービスは13歳以上の方を対象としています。13歳未満の方は利用できません。18歳未満の方は、保護者の同意を得てから利用してください。有料プランの購入も、保護者の同意を得て行ってください。13歳未満の方の情報を取得したことがわかった場合は、速やかに削除します。
        </p>
        <h2>13. お住まいの地域ごとの追加事項</h2>
        <h3>13-1. 台湾にお住まいの方</h3>
        <p>台湾の個人資料保護法に基づき、次のとおりお知らせします。</p>
        <ul>
          <li>収集する者: 第1章の当社</li>
          <li>
            収集の目的:
            第3章のとおり（台湾の法令上の分類では、主に「契約関係の履行」「消費者・顧客の管理とサービス」「教育・学習サービス」「情報（通信）サービス」「電子商取引サービス」に当たります）
          </li>
          <li>個人データの種類: 第2章のとおり</li>
          <li>
            利用の期間: 第9章のとおり／地域: 日本、第6章に記載の国／対象: 当社と第6章の委託先／方法:
            電子的な方法による保存・処理・送信
          </li>
          <li>
            権利:
            照会・閲覧、写しの交付、補充・訂正、収集・処理・利用の停止、削除を請求できます（第11章の窓口）
          </li>
          <li>
            提供しない場合の影響:
            メールアドレスなどの必須の情報を提供しない場合はアカウントを作れません。写真や位置情報を提供しない場合は、その機能を使えません
          </li>
        </ul>
        <h3>13-2. EU・英国などにお住まいの方</h3>
        <p>
          EU の一般データ保護規則（GDPR）または英国の GDPR
          が適用される場合、当社は次の法的根拠に基づいて個人データを取り扱います。
        </p>
        <ul>
          <li>契約の履行（本サービスの提供、アカウント、有料プラン）</li>
          <li>
            同意（位置情報、マイク、写真へのアクセス、AI
            事業者への送信）。同意はいつでも撤回できます
          </li>
          <li>正当な利益（不正利用の防止、セキュリティ、サービスの改善、統計）</li>
          <li>法的義務（取引記録の保存など）</li>
        </ul>
        <p>
          利用者は、アクセス、訂正、消去、処理の制限、データポータビリティ、異議を述べる権利を持ち、お住まいの国の監督機関に苦情を申し立てることができます。EU・英国の外（米国など）への移転は、欧州委員会の標準契約条項など、適切な保護措置に基づいて行います。
        </p>
        <h3>13-3. 米国カリフォルニア州にお住まいの方</h3>
        <p>当社は、個人情報を販売せず、行動を追跡する広告のために共有もしません。</p>
        <h2>14. 本ポリシーの変更</h2>
        <p>
          本ポリシーを変更する場合は、変更の内容と効力が生じる日を、効力が生じる前にアプリ内・Web
          版でお知らせします。利用目的の追加や、新たな第三者（AI
          の事業者を含む）への提供など、利用者の同意が必要な変更は、改めて同意をいただきます。
        </p>
        <h2>15. お問い合わせ・苦情の窓口</h2>
        <p>
          本ポリシー、個人情報の取り扱い、開示などのご請求、苦情は、次の窓口までご連絡ください。
        </p>
        <ul>
          <li>窓口: 【運営者名】 個人情報お問い合わせ窓口</li>
          <li>メール: 【お問い合わせメールアドレス】</li>
          <li>住所: 【住所】</li>
        </ul>
        <h2>16. 言語</h2>
        <p>
          本ポリシーは日本語・英語・繁体字中国語で提供します。内容に食い違いがある場合は、お住まいの国の法令が許す範囲で、日本語版が優先します。
        </p>
      </section>
    </>
  );
}

function PrivacyEn() {
  return (
    <>
      <h1 className="mt-4 text-hero font-bold tracking-tight">Privacy Policy</h1>
      <p className="mt-1 text-footnote text-muted-foreground">Established: 【Date established】</p>
      <p className="mt-1 text-footnote text-muted-foreground">Last updated: 【Last updated】</p>
      <section className="prose prose-sm mt-6 max-w-none dark:prose-invert">
        <p>
          【Operator name】 ("we", "us") sets out below how we handle information about users of the
          language-learning service "CatchWords" (including the iPhone app, the web app at{" "}
          <a href={siteUrlFor("/")}>{siteUrlFor("/")}</a> and related services; the "Service"). We
          comply with Japan's Act on the Protection of Personal Information (the "APPI") and other
          applicable laws. Users outside Japan, including in Taiwan, the European Union (EU) and the
          United Kingdom, also have the rights given by the laws where they live (section 13).
        </p>
        <h2>1. Operator</h2>
        <ul>
          <li>Name: 【Operator name】</li>
          <li>Address: 【Address】</li>
          <li>
            Representative: 【Representative's name (for a company) / for an individual: same as
            above】
          </li>
          <li>
            Person responsible for personal information and contact point: 【Contact email】
            (section 15)
          </li>
        </ul>
        <h2>2. Information we collect and how</h2>
        <h3>2-1. Information you enter or provide</h3>
        <ul>
          <li>
            Account information: email address, password (stored in hashed form; we cannot read it),
            display name and avatar image
          </li>
          <li>
            If you sign in with Apple or Google: the email address you receive from that provider
            (if you choose Apple's "Hide My Email", the relay address issued by Apple) and an
            identifier for you. We never receive your Apple or Google password
          </li>
          <li>
            Learning settings: the language you study, the display language, your level, and your
            answers in the first-run questions, such as your goals, interests and daily study time
          </li>
          <li>
            Photos and selfies you take, images you pick from your photo library (such as pages of a
            word book), and the cut-outs (stickers) made from them
          </li>
          <li>Text you write, such as journal entries, short notes and captions</li>
          <li>Your answers in reviews (typed text, or spoken answers converted into text)</li>
          <li>What you send us, such as reports of mistakes in a word card</li>
          <li>The content and contact details of your inquiries</li>
        </ul>
        <h3>2-2. Information collected when you use the Service</h3>
        <ul>
          <li>
            Location: the location (latitude and longitude) where you take a photo and the place
            name derived from it — only if you allow it in your device settings. Other features work
            without it
          </li>
          <li>
            Study records: the words you collect, review results and scores, streaks, the number of
            times you met a word and so on
          </li>
          <li>
            Scan records: the words found when you point the camera at things, whether you tapped or
            saved them, and (if you allow location) where
          </li>
          <li>
            Usage: when you open the Service, which screens you use, how many captures, scans and
            reviews you do and how long they take, and how many times you use AI features
          </li>
          <li>
            Technical information: the IP address needed for communication, device and browser type,
            and error logs (to investigate bugs in the web app)
          </li>
          <li>
            Paid plan information (section 8): plan type, purchase and expiry dates, and transaction
            identifiers issued by the payment provider
          </li>
        </ul>
        <h3>2-3. Voice (microphone and speech recognition)</h3>
        <p>
          "Search by voice" in the iPhone app uses the microphone and Apple's speech recognition.
          Your voice is converted into text by Apple's speech recognition; for languages whose
          recognizer is not on the device, the audio is sent to and processed on Apple's servers
          (Apple's privacy policy applies). We never receive or store the audio itself; only the
          resulting text is sent to our server. The microphone and speech recognition are used only
          if you allow them in your device settings.
        </p>
        <h3>2-4. Information kept only on your device</h3>
        <p>
          The following is stored on your device and not sent to our server (when you save a journal
          entry, or when a waiting photo is sent once you are back online, it reaches us at that
          point as information under 2-1):
        </p>
        <ul>
          <li>
            Information that keeps you signed in (in the Keychain on iPhone, and in the browser's
            local storage on the web)
          </li>
          <li>Display, sound and other settings</li>
          <li>
            The words, photo thumbnails and review counts shown in Home Screen widgets (stored in an
            area shared by the app and its widgets)
          </li>
          <li>
            Scheduled notifications (review reminders and "remind me at this place"). "Remind me at
            this place" lets your device notify you when you come near where you photographed a
            word; your device decides this locally and does not send your current location to us
          </li>
          <li>
            Photos waiting to be sent when you were offline ("waiting for analysis") and unfinished
            journal entries
          </li>
          <li>Temporary copies of images and audio that make the app faster</li>
        </ul>
        <p>
          These are removed from your device when you delete the app. When you delete your account,
          the app also removes them from your device.
        </p>
        <h3>2-5. Trying the Service without signing in (web)</h3>
        <p>
          On the web, you can try making a word from a photo once before signing in. The photo is
          sent for AI processing but is not stored on our server. To prevent abuse, we do not store
          your IP address as such; we use a value that cannot be reversed (a hash that changes every
          day) only to count that day's uses.
        </p>
        <h2>3. How we use information</h2>
        <p>We use the information we collect to:</p>
        <ol>
          <li>
            Provide and operate the Service (including creating and authenticating accounts, storing
            your data and syncing it between devices, and sending notifications)
          </li>
          <li>
            Suggest words with AI, create word cards, explanations, example sentences and quizzes,
            correct your journal and answers, and read words aloud
          </li>
          <li>
            Provide features that use where and when you took a photo, such as the map, the dex, the
            album and the calendar
          </li>
          <li>
            Manage daily limits on AI use, prevent fraud and abuse, and keep the Service secure
          </li>
          <li>
            Investigate bugs and improve the Service. For this, the operator may view and analyse
            per-user usage figures (such as the number of captures and reviews, active days and
            screen usage). Your email address, exact location (coordinates), photos and the text of
            your journal entries and notes are not included
          </li>
          <li>
            Produce overall statistics (such as the number of users and how many keep using the
            app), handled in a form that does not identify individuals
          </li>
          <li>Provide paid plans and confirm and manage payments</li>
          <li>
            Respond to inquiries and send important notices (such as changes to the Terms or this
            policy)
          </li>
          <li>Respond to violations of law or of the Terms of Use, and act as required by law</li>
        </ol>
        <p>
          We do not sell your information. We do not use it to track you or show you targeted
          advertising. We do not ourselves use your photos or journal entries to train AI models.
        </p>
        <h2>4. Use of AI</h2>
        <p>
          The Service uses AI (large language models) provided by outside companies to identify
          objects in photos and to create word cards, explanations and corrections. When you use an
          AI feature, the following is sent to that company:
        </p>
        <ul>
          <li>
            Photos (photos you take, images you pick from your photo library, pages of a word book)
          </li>
          <li>
            Words and text (words you look up, the text of journal entries and notes, review
            answers, the content of mistake reports)
          </li>
          <li>
            Settings needed to produce the answer, such as the language you study, the display
            language and your level
          </li>
        </ul>
        <p>
          We do not include your email address or name in what we send to AI. The companies and
          their countries are listed in section 6. We endeavour to use them under contracts and
          settings in which they do not use what we send to train their own AI. AI output may
          contain mistakes (see the Terms of Use).
        </p>
        <p>
          Before you first use an AI feature, the Service asks for your consent to send the above
          information to AI companies. If you do not consent, you cannot use features that rely on
          AI, such as making words from photos, but you can still use other features (such as
          browsing your collected words and some reviews).
        </p>
        <h2>5. Sharing with third parties</h2>
        <p>
          We do not provide your personal information (personal data) to third parties without your
          prior consent, except:
        </p>
        <ul>
          <li>where required by law;</li>
          <li>
            where necessary to protect a person's life, body or property and it is difficult to
            obtain your consent;
          </li>
          <li>
            where necessary to cooperate with a government body carrying out duties prescribed by
            law; or
          </li>
          <li>
            in connection with a business succession (such as a merger or business transfer), in
            which case we will ensure it continues to be handled at the level set out in this
            policy.
          </li>
        </ul>
        <p>
          Sending information to the companies in section 6 is done as outsourcing of work needed to
          provide the Service.
        </p>
        <h2>6. Service providers and transfers to third parties in foreign countries</h2>
        <p>
          We entrust the handling of information to the following companies to the extent needed to
          provide the Service. Most are located outside Japan, and information is stored and
          processed outside Japan. We use each company after confirming that, through its terms of
          service, data processing agreement or similar, it takes measures equivalent to those
          required by the APPI (such as security measures and a ban on use for other purposes), and
          we endeavour to ensure protection equal to this policy.
        </p>
        <h3>6-1. Main service providers</h3>
        <table>
          <thead>
            <tr>
              <th>Company</th>
              <th>Country</th>
              <th>Information</th>
              <th>Purpose</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Supabase, Inc. (used through Lovable Cloud)</td>
              <td>
                United States (data location: 【Supabase data region (e.g. US / Singapore /
                Tokyo)】)
              </td>
              <td>
                All Service data, including account information, photos, journal entries, study
                records, location and usage
              </td>
              <td>Database, authentication and file storage</td>
            </tr>
            <tr>
              <td>Lovable Labs Sweden AB and Lovable Labs Incorporated</td>
              <td>Sweden, United States</td>
              <td>
                Content of communications passing through the Service's server, relaying AI requests
                (the information in section 4), relaying Apple and Google sign-in, web error logs
              </td>
              <td>Running the web app and server, relaying AI requests and sign-in</td>
            </tr>
            <tr>
              <td>Google LLC</td>
              <td>United States</td>
              <td>
                Photos and text (AI processing by Gemini), text to be read aloud (speech synthesis),
                latitude and longitude (place names and map display on the web), sign-in data if you
                sign in with Google
              </td>
              <td>AI processing, speech synthesis, maps and place names, sign-in</td>
            </tr>
            <tr>
              <td>Apple Inc.</td>
              <td>United States</td>
              <td>
                Sign-in data if you sign in with Apple, audio (when it cannot be recognized on the
                device), latitude and longitude (place names in the iPhone app), in-app purchase
                records
              </td>
              <td>Sign-in, speech recognition, place names, in-app purchases</td>
            </tr>
            <tr>
              <td>Stripe, Inc. (in Japan, through Stripe Japan K.K.)</td>
              <td>United States</td>
              <td>
                Email address, user ID, payment information (only Stripe handles card numbers; we do
                not receive them)
              </td>
              <td>Payments for paid plans on the web</td>
            </tr>
          </tbody>
        </table>
        <h3>6-2. Optional providers (used only if we switch the AI or speech provider)</h3>
        <table>
          <thead>
            <tr>
              <th>Company</th>
              <th>Country</th>
              <th>Information</th>
              <th>Purpose</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>OpenAI, L.L.C.</td>
              <td>United States</td>
              <td>The information in section 4</td>
              <td>AI processing</td>
            </tr>
            <tr>
              <td>Anthropic, PBC</td>
              <td>United States</td>
              <td>The information in section 4</td>
              <td>AI processing</td>
            </tr>
            <tr>
              <td>OpenRouter, Inc.</td>
              <td>
                United States (requests are sent on to the country of the selected AI model's
                provider)
              </td>
              <td>The information in section 4</td>
              <td>Relaying AI requests</td>
            </tr>
            <tr>
              <td>Microsoft Corporation (Azure AI Speech)</td>
              <td>United States (processing region: 【Azure region】)</td>
              <td>Text to be read aloud</td>
              <td>Speech synthesis</td>
            </tr>
            <tr>
              <td>ElevenLabs, Inc.</td>
              <td>United States</td>
              <td>Text to be read aloud</td>
              <td>Speech synthesis</td>
            </tr>
            <tr>
              <td>【3D generation provider (e.g. the operator of Tripo3D)】</td>
              <td>【Country】</td>
              <td>Photos (when you use the Pro 3D feature)</td>
              <td>Creating 3D models from photos</td>
            </tr>
          </tbody>
        </table>
        <h3>6-3. Outside services that receive no personal information</h3>
        <p>
          To search for or generate images and to rank suggestions, we may send word strings to
          services such as Unsplash, Wikimedia Commons, Higgsfield and 【operator of typesafe
          (JEV)】. We do not send them photos, journal entries, email addresses or anything else
          that identifies you.
        </p>
        <h3>6-4. Personal information protection systems in foreign countries</h3>
        <ul>
          <li>
            United States: there is no comprehensive federal privacy law; there are sector-specific
            federal laws and state laws such as the California Consumer Privacy Act (CCPA).
          </li>
          <li>
            Sweden (EU): the EU General Data Protection Regulation (GDPR) applies. Japan's Personal
            Information Protection Commission recognises the EU as having a level of protection
            equivalent to Japan.
          </li>
          <li>
            For details, see the Commission's survey of foreign systems (United States:{" "}
            <a
              href="https://www.ppc.go.jp/enforcement/infoprovision/laws/offshore_report_america/"
              target="_blank"
              rel="noopener noreferrer"
            >
              https://www.ppc.go.jp/enforcement/infoprovision/laws/offshore_report_america/
            </a>{" "}
            ).
          </li>
        </ul>
        <p>
          If you would like more information about the measures taken by our service providers,
          please contact us (section 15). We will respond without delay.
        </p>
        <h2>7. Location and photos</h2>
        <ul>
          <li>
            Location is used only to record where a photo was taken and to show it in the map, the
            album and "remind me at this place". There is currently no feature that shows your
            location to other users.
          </li>
          <li>
            Place names are obtained by sending latitude and longitude to Apple (iPhone app) or
            Google (web).
          </li>
          <li>
            Photos are stored to show them in your own dex and album. There is currently no feature
            that shows them to other users.
          </li>
          <li>
            If you turn on "Also save to Photos", the photos you take are saved to your device's
            Photos app. Only the images you select are read from your photo library.
          </li>
          <li>
            You can stop location access at any time in your device settings. Locations already
            recorded can be removed by deleting the word or by deleting your account.
          </li>
        </ul>
        <h2>8. Paid plans and payments</h2>
        <ul>
          <li>
            Paid plans in the iPhone app (once offered) are purchased through Apple's in-app
            purchase. Apple processes the payment; we do not receive your card number or other
            payment method details. To check that a purchase is valid, we receive purchase records
            from Apple (product, period, transaction identifiers and so on) and link them to your
            account.
          </li>
          <li>
            Paid plans on the web are paid through Stripe. Only Stripe handles card numbers; we do
            not receive them. We receive the Stripe customer ID and subscription status to manage
            your plan.
          </li>
        </ul>
        <h2>9. Retention and deletion</h2>
        <table>
          <thead>
            <tr>
              <th>Information</th>
              <th>Retention</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>
                Account information, photos, journal entries, study records, location and usage
              </td>
              <td>Until you delete your account</td>
            </tr>
            <tr>
              <td>Records of photo analysis and of AI use counts</td>
              <td>Until you delete your account</td>
            </tr>
            <tr>
              <td>Inquiries</td>
              <td>【3 years】 after we finish handling them</td>
            </tr>
            <tr>
              <td>Records of paid-plan transactions</td>
              <td>The period required by law (in principle 7 years under Japanese tax law)</td>
            </tr>
            <tr>
              <td>Counts for trying the Service without signing in (hashed values)</td>
              <td>Used only to apply that day's limit</td>
            </tr>
            <tr>
              <td>Copies remaining in system backups</td>
              <td>Erased within 【30 days】 of deletion</td>
            </tr>
          </tbody>
        </table>
        <p>
          Deleting your account: you can delete your account and related data (photos, word cards,
          study records, journal entries, avatar image and so on) at any time from Settings →
          "Delete account" in the iPhone app or on the web. Deletion cannot be undone. Shared
          dictionary data, such as headwords you added that other learners also use, may remain
          after its link to you is removed. Audio of text read aloud may remain in a shared
          temporary store in a form not linked to any individual. Deleting your account does not
          automatically cancel an in-app purchase subscription; please cancel it first in your Apple
          ID settings.
        </p>
        <h2>10. Security measures</h2>
        <p>
          We take the following measures to prevent leakage, loss or damage of personal information:
        </p>
        <ul>
          <li>
            Basic policy: we have established this policy and committed to complying with applicable
            laws and guidelines.
          </li>
          <li>
            Handling rules: we have set how information is handled and who is responsible at each
            stage — collection, use, storage, provision and deletion.
          </li>
          <li>
            Organisational measures: we have appointed a responsible person and set procedures for
            reporting and responding to handling that breaches the law or this policy, or to signs
            of a leak.
          </li>
          <li>
            Personnel measures: everyone who handles personal information is required to keep it
            confidential and handle it properly.
          </li>
          <li>
            Physical measures: we prevent theft or loss of devices that handle personal information,
            and use screen locks and storage encryption.
          </li>
          <li>
            Technical measures: communications are encrypted (HTTPS); the database uses row-level
            access control so that users can read and write only their own data; secret keys are
            kept only on the server and are never included in the apps; the operator's usage screens
            do not show email addresses, exact locations, photos or journal text.
          </li>
          <li>
            Understanding the external environment: before using the foreign companies in section 6,
            we have checked the personal information protection systems of their countries and taken
            security measures accordingly.
          </li>
        </ul>
        <h2>11. Requests for disclosure, correction, suspension of use and so on</h2>
        <p>
          You may ask us to notify you of the purposes of use of, disclose (including records of
          provision to third parties), correct, add to or delete, stop using or erase, or stop
          providing to third parties, the personal information about you that we hold (retained
          personal data).
        </p>
        <ul>
          <li>You can view, edit and delete much of your information yourself in the app.</li>
          <li>
            For other requests, please email the contact point in section 15. After confirming that
            you are the person concerned (or their agent), we will respond without delay in
            accordance with the law.
          </li>
          <li>We charge no fee.</li>
          <li>If the law does not allow us to comply, we will tell you why.</li>
        </ul>
        <h2>12. Minors</h2>
        <p>
          The Service is intended for people aged 13 and over. Children under 13 may not use it. If
          you are under 18, please get your parent's or guardian's consent before using the Service,
          including before buying a paid plan. If we learn that we have collected information from a
          child under 13, we will delete it promptly.
        </p>
        <h2>13. Additional information by region</h2>
        <h3>13-1. Users in Taiwan</h3>
        <p>Under Taiwan's Personal Data Protection Act, we inform you as follows:</p>
        <ul>
          <li>Collector: us, as set out in section 1</li>
          <li>
            Purposes: as in section 3 (under Taiwan's classification, mainly performance of
            contractual relationships, consumer and customer management and service, education and
            learning services, information and communication services, and e-commerce services)
          </li>
          <li>Categories of personal data: as in section 2</li>
          <li>
            Period of use: as in section 9; area: Japan and the countries in section 6; recipients:
            us and the providers in section 6; method: storage, processing and transmission by
            electronic means
          </li>
          <li>
            Your rights: you may request inquiry or review, copies, supplementation or correction,
            cessation of collection, processing or use, and deletion (contact point in section 11)
          </li>
          <li>
            Effect of not providing data: without required information such as an email address you
            cannot create an account; without photos or location you cannot use those features
          </li>
        </ul>
        <h3>13-2. Users in the EU, the UK and similar regions</h3>
        <p>
          Where the EU General Data Protection Regulation (GDPR) or the UK GDPR applies, we process
          personal data on the following legal bases:
        </p>
        <ul>
          <li>performance of a contract (providing the Service, your account, paid plans);</li>
          <li>
            consent (location, microphone, photo library access, sending data to AI companies) — you
            can withdraw consent at any time;
          </li>
          <li>
            legitimate interests (preventing abuse, security, improving the Service, statistics);
            and
          </li>
          <li>legal obligations (such as keeping transaction records).</li>
        </ul>
        <p>
          You have the rights of access, rectification, erasure, restriction of processing, data
          portability and objection, and you may lodge a complaint with the supervisory authority in
          your country. Transfers outside the EU/UK (such as to the United States) are made on the
          basis of appropriate safeguards such as the European Commission's Standard Contractual
          Clauses.
        </p>
        <h3>13-3. Users in California, United States</h3>
        <p>
          We do not sell personal information, and we do not share it for cross-context behavioural
          advertising.
        </p>
        <h2>14. Changes to this policy</h2>
        <p>
          When we change this policy, we will announce the changes and the date they take effect, in
          the app and on the web, before they take effect. For changes that require your consent,
          such as adding purposes of use or providing information to a new third party (including an
          AI company), we will ask for your consent again.
        </p>
        <h2>15. Contact and complaints</h2>
        <p>
          For questions about this policy or how we handle personal information, requests for
          disclosure and so on, and complaints, please contact:
        </p>
        <ul>
          <li>Contact point: 【Operator name】 Personal Information Desk</li>
          <li>Email: 【Contact email】</li>
          <li>Address: 【Address】</li>
        </ul>
        <h2>16. Language</h2>
        <p>
          This policy is provided in Japanese, English and Traditional Chinese. If there is any
          inconsistency, the Japanese version prevails, to the extent permitted by the laws of the
          country where you live.
        </p>
      </section>
    </>
  );
}

function PrivacyZhTw() {
  return (
    <>
      <h1 className="mt-4 text-hero font-bold tracking-tight">隱私權政策</h1>
      <p className="mt-1 text-footnote text-muted-foreground">制定日期：【制定日期】</p>
      <p className="mt-1 text-footnote text-muted-foreground">最後更新：【最後更新日期】</p>
      <section className="prose prose-sm mt-6 max-w-none dark:prose-invert">
        <p>
          【營運者名稱】（以下稱「本公司」）就語言學習服務「CatchWords」（包括 iPhone App、網頁版{" "}
          <a href={siteUrlFor("/")}>{siteUrlFor("/")}</a>{" "}
          及相關服務，以下稱「本服務」）中使用者資料的處理方式，訂定本政策如下。本公司遵守日本《個人資訊保護法》及其他相關法令；對於居住在臺灣、歐盟（EU）、英國等日本以外地區的使用者，亦保障其居住地法令所賦予的權利（第13條）。
        </p>
        <h2>1. 營運者</h2>
        <ul>
          <li>名稱：【營運者名稱】</li>
          <li>地址：【地址】</li>
          <li>代表人：【代表人姓名（法人時）／個人時同上】</li>
          <li>個人資料處理負責人及聯絡窗口：【聯絡電子郵件】（第15條）</li>
        </ul>
        <h2>2. 蒐集的資料及蒐集方式</h2>
        <h3>2-1. 使用者輸入或提供的資料</h3>
        <ul>
          <li>
            帳號資料：電子郵件地址、密碼（以雜湊方式儲存，本公司無法讀取）、顯示名稱、大頭貼圖片
          </li>
          <li>
            以 Apple 或 Google 登入時：自該業者取得的電子郵件地址（若選擇 Apple
            的「隱藏我的電子郵件」，則為 Apple 核發的轉寄地址）及識別使用者的 ID。本公司不會取得您的
            Apple 或 Google 密碼
          </li>
          <li>
            學習設定：學習的語言、顯示語言、程度，以及初次設定時回答的學習目的、興趣、每日學習時間等
          </li>
          <li>
            拍攝的照片及自拍照、從照片 App
            選取的圖片（例如單字書的頁面），以及由此製作的去背圖（貼紙）
          </li>
          <li>日記、隨手筆記、圖說等使用者撰寫的文字</li>
          <li>複習時的作答內容（輸入的文字，或將口說作答轉成的文字）</li>
          <li>單字錯誤回報等使用者傳送的內容</li>
          <li>洽詢的內容及聯絡方式</li>
        </ul>
        <h3>2-2. 使用本服務時蒐集的資料</h3>
        <ul>
          <li>
            位置資訊：拍攝時的位置（經緯度）及由此取得的地名。僅在您於裝置設定中允許時蒐集，不允許也可使用其他功能
          </li>
          <li>學習紀錄：收集的單字、複習結果與分數、連續學習天數、遇見次數等</li>
          <li>
            掃描紀錄：將相機對準物品時找到的單字、是否點選或儲存該單字，以及（若允許位置資訊）其位置
          </li>
          <li>
            使用情形：開啟本服務的日期與時間、使用的畫面、拍攝・掃描・複習等的次數及所花時間、AI
            功能的使用次數
          </li>
          <li>技術資訊：通訊所需的 IP 位址、裝置及瀏覽器類型、錯誤紀錄（用於調查網頁版的問題）</li>
          <li>付費方案資料（第8條）：方案類型、購買日期與到期日、付款業者核發的交易識別碼</li>
        </ul>
        <h3>2-3. 語音（麥克風・語音辨識）</h3>
        <p>
          iPhone App 的「用聲音查詢」會使用麥克風及 Apple 的語音辨識。語音由 Apple
          的語音辨識轉成文字；裝置內沒有辨識模型的語言，語音會傳送至 Apple 的伺服器處理（適用 Apple
          的隱私權政策）。本公司不會取得或儲存語音本身，傳送至本公司伺服器的只有轉成的文字。麥克風及語音辨識僅在您於裝置設定中允許時使用。
        </p>
        <h3>2-4. 僅儲存在裝置內的資料</h3>
        <p>
          下列資料儲存在您的裝置內，不會傳送至本公司伺服器（但當您儲存日記，或恢復連線後傳送等待中的照片時，該資料即依第2-1條送達本公司）：
        </p>
        <ul>
          <li>維持登入狀態的資料（iPhone 存於鑰匙圈，網頁版存於瀏覽器的本機儲存空間）</li>
          <li>顯示、音效等設定</li>
          <li>主畫面小工具顯示的單字、照片縮圖、待複習數量（存於 App 與小工具共用的區域）</li>
          <li>
            已排定的通知（複習提醒、「在這個地點提醒我」）。「在這個地點提醒我」是當您接近拍攝單字的地點時由裝置發出通知的功能，地點判斷在裝置內進行，不會將您目前的位置傳送給本公司
          </li>
          <li>離線時等待傳送的照片（「等待解析」）及尚未完成的日記</li>
          <li>為加快顯示而暫存的圖片與音訊</li>
        </ul>
        <p>刪除 App 後，這些資料會從裝置中消失。刪除帳號時，App 也會從裝置中刪除這些資料。</p>
        <h3>2-5. 未登入時的體驗（網頁版）</h3>
        <p>
          網頁版可在登入前體驗一次用照片製作單字。此時照片會傳送給 AI
          處理，但不會儲存在本公司伺服器。為防止濫用，本公司不會直接儲存 IP
          位址，而是轉換成每天變化、無法還原的雜湊值，僅用於計算當天的使用次數。
        </p>
        <h2>3. 利用目的</h2>
        <p>本公司將蒐集的資料用於下列目的：</p>
        <ol>
          <li>提供及營運本服務（包括建立及驗證帳號、儲存資料及在裝置間同步、傳送通知）</li>
          <li>透過 AI 提示單字候選、製作單字卡・解說・例句・測驗、批改日記及作答、朗讀發音</li>
          <li>提供地圖、圖鑑、相簿、行事曆等使用拍攝地點及日期的功能</li>
          <li>管理每日 AI 使用次數上限、防止不當使用及騷擾行為、確保安全</li>
          <li>
            調查問題及改善服務。為此，營運者可能查閱及分析每位使用者的使用情形數據（拍攝及複習次數、使用日期、各畫面使用情形等）。此時，電子郵件地址、精確位置（經緯度）、照片，以及日記和隨手筆記的內文，均不在查閱範圍內
          </li>
          <li>
            製作全體使用者的統計資料（使用者人數、持續使用者的比例等）。統計資料以無法識別特定個人的形式處理
          </li>
          <li>提供付費方案、確認及管理付款</li>
          <li>回覆洽詢、通知重要事項（條款或本政策的變更等）</li>
          <li>處理違反法令或使用條款的行為，以及依法令辦理的事項</li>
        </ol>
        <p>
          本公司不會出售使用者的資料，也不會用於追蹤行為以投放廣告（目標式廣告）。本公司本身亦不會將使用者的照片或日記用於訓練
          AI 模型。
        </p>
        <h2>4. 關於 AI 的使用</h2>
        <p>
          本服務使用外部業者提供的
          AI（大型語言模型）來判斷照片中的物品，以及製作單字卡、解說和批改。使用 AI
          功能時，下列資料會傳送給該業者：
        </p>
        <ul>
          <li>照片（拍攝的照片、從照片 App 選取的圖片、單字書的頁面）</li>
          <li>單字・文字（查詢的單字、日記・隨手筆記的內文、複習的作答、錯誤回報的內容）</li>
          <li>產生回覆所需的設定，例如學習的語言、顯示語言、程度</li>
        </ul>
        <p>
          傳送給 AI
          的資料不包含您的電子郵件地址或姓名。傳送對象的業者及其所在國家如第6條所示。本公司努力在 AI
          業者不將所傳送資料用於訓練其自身 AI 的契約及設定下使用。AI
          產生的內容可能有誤（請參閱使用條款）。
        </p>
        <p>
          本服務會在您首次使用 AI 功能前，就將上述資料傳送給 AI
          業者一事取得您的同意。若您不同意，將無法使用以照片製作單字等使用 AI
          的功能，但仍可使用其他功能（瀏覽已收集的單字、部分複習等）。
        </p>
        <h2>5. 提供予第三方</h2>
        <p>除下列情形外，本公司不會未經您事先同意而將個人資料提供予第三方：</p>
        <ul>
          <li>依法令規定者</li>
          <li>為保護人的生命、身體或財產所必要，且難以取得本人同意者</li>
          <li>為協助國家機關等執行法令所定事務所必要者</li>
          <li>因事業承繼（合併、營業讓與等）而提供者；此時亦將確保以與本政策相同的水準處理</li>
        </ul>
        <p>傳送給第6條所列業者，係為提供本服務而進行的業務委託。</p>
        <h2>6. 受託業者及提供予位於外國的第三方</h2>
        <p>
          本公司在提供本服務所需的範圍內，委託下列業者處理資料。這些業者多數位於日本境外，資料會在日本境外儲存及處理。本公司在確認各業者已透過其服務條款、資料處理協議等，採取相當於日本《個人資訊保護法》所要求之措置（安全管理、禁止目的外利用等）後才使用，並努力確保與本政策同等的保護。
        </p>
        <h3>6-1. 主要受託業者</h3>
        <table>
          <thead>
            <tr>
              <th>業者</th>
              <th>所在國家</th>
              <th>提供的資料</th>
              <th>目的</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Supabase, Inc.（透過 Lovable Cloud 使用）</td>
              <td>美國（資料儲存地點：【Supabase 資料儲存區域（例：美國／新加坡／東京）】）</td>
              <td>帳號資料、照片、日記、學習紀錄、位置資訊、使用情形等本服務的全部資料</td>
              <td>資料庫・身分驗證・檔案儲存</td>
            </tr>
            <tr>
              <td>Lovable Labs Sweden AB 及 Lovable Labs Incorporated</td>
              <td>瑞典、美國</td>
              <td>
                經過本服務伺服器的通訊內容、轉送 AI 請求（第4條的資料）、轉送 Apple・Google
                登入、網頁版錯誤紀錄
              </td>
              <td>營運網頁版及伺服器、轉送 AI 請求及登入</td>
            </tr>
            <tr>
              <td>Google LLC</td>
              <td>美國</td>
              <td>
                照片・文字（由 Gemini 進行 AI
                處理）、要朗讀的文字（語音合成）、經緯度（網頁版取得地名及顯示地圖）、以 Google
                登入時的驗證資料
              </td>
              <td>AI 處理、語音合成、地圖・地名、登入</td>
            </tr>
            <tr>
              <td>Apple Inc.</td>
              <td>美國</td>
              <td>
                以 Apple 登入時的驗證資料、語音（裝置內無法辨識時）、經緯度（iPhone App
                取得地名）、App 內購買的購買資料
              </td>
              <td>登入、語音辨識、地名、App 內購買</td>
            </tr>
            <tr>
              <td>Stripe, Inc.（在日本透過 Stripe Japan 株式會社使用）</td>
              <td>美國</td>
              <td>
                電子郵件地址、使用者 ID、付款資料（信用卡號碼僅由 Stripe 處理，本公司不會取得）
              </td>
              <td>網頁版付費方案的付款</td>
            </tr>
          </tbody>
        </table>
        <h3>6-2. 選用的提供對象（僅在本公司切換 AI 或語音提供者時使用）</h3>
        <table>
          <thead>
            <tr>
              <th>業者</th>
              <th>所在國家</th>
              <th>提供的資料</th>
              <th>目的</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>OpenAI, L.L.C.</td>
              <td>美國</td>
              <td>第4條的資料</td>
              <td>AI 處理</td>
            </tr>
            <tr>
              <td>Anthropic, PBC</td>
              <td>美國</td>
              <td>第4條的資料</td>
              <td>AI 處理</td>
            </tr>
            <tr>
              <td>OpenRouter, Inc.</td>
              <td>美國（請求內容會傳送至所選 AI 模型提供者的所在國家）</td>
              <td>第4條的資料</td>
              <td>轉送 AI 請求</td>
            </tr>
            <tr>
              <td>Microsoft Corporation（Azure AI Speech）</td>
              <td>美國（處理區域：【Azure 區域】）</td>
              <td>要朗讀的文字</td>
              <td>語音合成</td>
            </tr>
            <tr>
              <td>ElevenLabs, Inc.</td>
              <td>美國</td>
              <td>要朗讀的文字</td>
              <td>語音合成</td>
            </tr>
            <tr>
              <td>【3D 生成業者名稱（例：Tripo3D 的營運公司）】</td>
              <td>【所在國家】</td>
              <td>照片（使用 Pro 的 3D 功能時）</td>
              <td>由照片製作 3D 模型</td>
            </tr>
          </tbody>
        </table>
        <h3>6-3. 不含個人資料的外部服務</h3>
        <p>
          為搜尋或產生圖片、排序候選等，本公司可能將單字字串傳送給 Unsplash、Wikimedia
          Commons、Higgsfield、【typesafe（JEV）的營運公司】等服務。不會傳送照片、日記、電子郵件地址等可識別使用者的資料。
        </p>
        <h3>6-4. 外國的個人資料保護制度</h3>
        <ul>
          <li>
            美國：沒有聯邦層級的綜合性個人資料保護法，而是有各領域的聯邦法及《加州消費者隱私法》（CCPA）等州法。
          </li>
          <li>
            瑞典（歐盟）：適用歐盟《一般資料保護規則》（GDPR）。歐盟是日本個人資訊保護委員會認定與日本具同等保護水準的國家・地區。
          </li>
          <li>
            詳情請參閱日本個人資訊保護委員會公布的外國制度調查結果（美國：
            <a
              href="https://www.ppc.go.jp/enforcement/infoprovision/laws/offshore_report_america/"
              target="_blank"
              rel="noopener noreferrer"
            >
              https://www.ppc.go.jp/enforcement/infoprovision/laws/offshore_report_america/
            </a>{" "}
            ）。
          </li>
        </ul>
        <p>若您希望進一步了解受託業者所採取的措施，請向第15條的窗口提出，本公司將儘速告知。</p>
        <h2>7. 位置資訊及照片的處理</h2>
        <ul>
          <li>
            位置資訊僅用於記錄拍攝地點，以及在地圖、相簿、「在這個地點提醒我」中顯示。目前沒有向其他使用者公開位置資訊的功能。
          </li>
          <li>地名的取得方式：iPhone App 將經緯度傳送給 Apple，網頁版則傳送給 Google。</li>
          <li>
            照片儲存的目的是在使用者本人的圖鑑及相簿中顯示。目前沒有向其他使用者公開照片的功能。
          </li>
          <li>
            若開啟「同時儲存到照片」，拍攝的照片會儲存到裝置的照片 App。從照片 App
            讀取時，僅限您選取的圖片。
          </li>
          <li>
            您可隨時在裝置設定中停止使用位置資訊。已記錄的位置，可透過刪除該單字或刪除帳號來清除。
          </li>
        </ul>
        <h2>8. 付費方案及付款</h2>
        <ul>
          <li>
            iPhone App 的付費方案（開始提供時）透過 Apple 的 App 內購買購買。付款由 Apple
            處理，本公司不會取得信用卡號碼等付款方式資料。為確認購買是否有效，本公司會自 Apple
            取得購買紀錄（商品、期間、交易識別碼等），並與帳號連結。
          </li>
          <li>
            網頁版的付費方案透過 Stripe 付款。信用卡號碼僅由 Stripe
            處理，本公司不會取得。為管理方案狀態，本公司會取得 Stripe 的顧客 ID 及訂閱狀態。
          </li>
        </ul>
        <h2>9. 保存期間及刪除</h2>
        <table>
          <thead>
            <tr>
              <th>資料</th>
              <th>保存期間</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>帳號資料、照片、日記、學習紀錄、位置資訊、使用情形</td>
              <td>至刪除帳號為止</td>
            </tr>
            <tr>
              <td>照片解析紀錄・AI 使用次數紀錄</td>
              <td>至刪除帳號為止</td>
            </tr>
            <tr>
              <td>洽詢內容</td>
              <td>處理完畢後【3年】</td>
            </tr>
            <tr>
              <td>付費方案的交易紀錄</td>
              <td>法令規定的保存期間（依日本稅法原則上為7年）</td>
            </tr>
            <tr>
              <td>未登入體驗的次數紀錄（雜湊值）</td>
              <td>僅用於當天的次數限制</td>
            </tr>
            <tr>
              <td>系統備份中留存的副本</td>
              <td>刪除後【30天】內清除</td>
            </tr>
          </tbody>
        </table>
        <p>
          刪除帳號：您可隨時透過 iPhone App
          或網頁版的「設定」→「刪除帳號」，刪除帳號及相關資料（照片、單字卡、學習紀錄、日記、大頭貼圖片等）。刪除後無法復原。您登錄的單字詞條等與其他使用者共用的辭典資料，可能在解除與您的連結後保留。朗讀的音訊可能以無法連結到個人的形式保留在共用的暫存區域。刪除帳號不會自動取消
          App 內購買的訂閱，請先在 Apple ID 設定中取消訂閱。
        </p>
        <h2>10. 安全管理措施</h2>
        <p>為防止個人資料外洩、滅失或毀損，本公司採取下列措施：</p>
        <ul>
          <li>訂定基本方針：訂定本政策，並明定遵守相關法令及指引。</li>
          <li>處理規範：就蒐集、利用、保存、提供、刪除各階段，訂定處理方式及負責人。</li>
          <li>
            組織性措施：設置負責人，並訂定得知違反法令或本政策的處理或外洩徵兆時的通報及因應程序。
          </li>
          <li>人員措施：要求處理個人資料者保守秘密並妥善處理。</li>
          <li>實體措施：防止處理個人資料的裝置遭竊或遺失，並使用螢幕鎖定及儲存加密。</li>
          <li>
            技術性措施：通訊加密（HTTPS）；資料庫設有逐列存取控制，使使用者只能讀寫本人的資料；秘密金鑰僅在伺服器管理，不包含在
            App 中；營運者查看使用情形的畫面不顯示電子郵件地址、精確位置、照片及日記內文。
          </li>
          <li>
            掌握外部環境：使用第6條所列外國業者時，已掌握該國的個人資料保護制度，並據以採取安全管理措施。
          </li>
        </ul>
        <h2>11. 查詢、更正、停止利用等請求</h2>
        <p>
          您可就本公司保有的您的個人資料，請求通知利用目的、查詢或請求閱覽（包括提供予第三方的紀錄）、製給複製本、補充或更正、刪除、停止蒐集・處理或利用，以及停止提供予第三方。
        </p>
        <ul>
          <li>大部分資料可在 App 內自行確認、修改及刪除。</li>
          <li>
            其他請求，請以電子郵件聯絡第15條的窗口。本公司確認為本人（或代理人）後，將依法令儘速處理。
          </li>
          <li>不收取費用。</li>
          <li>依法令無法辦理時，將告知理由。</li>
        </ul>
        <h2>12. 未成年人的使用</h2>
        <p>
          本服務以13歲以上者為對象，未滿13歲者不得使用。未滿18歲者，請取得法定代理人（家長或監護人）的同意後再使用；購買付費方案亦須取得法定代理人同意。若得知蒐集了未滿13歲者的資料，本公司將儘速刪除。
        </p>
        <h2>13. 依居住地區的補充事項</h2>
        <h3>13-1. 居住在臺灣的使用者</h3>
        <p>依臺灣《個人資料保護法》第8條，告知如下：</p>
        <ul>
          <li>蒐集者：第1條所列之本公司</li>
          <li>
            蒐集之目的：如第3條所示（依臺灣法令之特定目的分類，主要為「契約、類似契約或其他法律關係事務」、「消費者、客戶管理與服務」、「教育或訓練行政」、「資（通）訊服務」、「電子商務服務」）
          </li>
          <li>個人資料之類別：如第2條所示</li>
          <li>
            利用之期間：如第9條所示；地區：日本及第6條所列國家；對象：本公司及第6條所列受託業者；方式：以電子方式儲存、處理及傳輸
          </li>
          <li>
            當事人權利：您可依同法第3條，請求查詢或閱覽、製給複製本、補充或更正、停止蒐集・處理或利用、刪除（窗口見第11條）
          </li>
          <li>
            不提供之影響：若不提供電子郵件地址等必要資料，將無法建立帳號；若不提供照片或位置資訊，將無法使用相關功能
          </li>
        </ul>
        <h3>13-2. 居住在歐盟、英國等地區的使用者</h3>
        <p>
          適用歐盟《一般資料保護規則》（GDPR）或英國 GDPR 時，本公司依下列法律依據處理個人資料：
        </p>
        <ul>
          <li>履行契約（提供本服務、帳號、付費方案）</li>
          <li>同意（位置資訊、麥克風、照片存取、傳送給 AI 業者）——您可隨時撤回同意</li>
          <li>正當利益（防止不當使用、安全、改善服務、統計）</li>
          <li>法律義務（保存交易紀錄等）</li>
        </ul>
        <p>
          您享有查閱、更正、刪除、限制處理、資料可攜及拒絕處理的權利，並可向居住國的監管機關提出申訴。移轉至歐盟・英國以外地區（如美國）時，以歐盟執委會標準契約條款等適當保護措施為依據。
        </p>
        <h3>13-3. 居住在美國加州的使用者</h3>
        <p>本公司不出售個人資料，也不為跨情境行為廣告而分享個人資料。</p>
        <h2>14. 本政策的變更</h2>
        <p>
          變更本政策時，本公司將於生效前在 App
          內及網頁版公告變更內容及生效日期。若為新增利用目的、提供予新的第三方（包括 AI
          業者）等需取得您同意的變更，將再次徵求您的同意。
        </p>
        <h2>15. 聯絡及申訴窗口</h2>
        <p>關於本政策、個人資料的處理、查詢等請求及申訴，請聯絡下列窗口：</p>
        <ul>
          <li>窗口：【營運者名稱】個人資料洽詢窗口</li>
          <li>電子郵件：【聯絡電子郵件】</li>
          <li>地址：【地址】</li>
        </ul>
        <h2>16. 語言</h2>
        <p>
          本政策以日文、英文及繁體中文提供。內容如有不一致，在您居住國法令允許的範圍內，以日文版為準。
        </p>
      </section>
    </>
  );
}

function PrivacyPage() {
  const t = useT();
  const lang = useUiLang();
  return (
    <article className="mx-auto max-w-2xl px-4 py-10">
      <Link
        to="/"
        className="inline-block py-3 -my-3 text-body text-muted-foreground hover:text-foreground"
      >
        ← {t("common.back")}
      </Link>
      {lang === "ja" ? (
        <PrivacyJa />
      ) : lang === CHINESE_EXPLANATION_LANGUAGE ? (
        <PrivacyZhTw />
      ) : (
        <PrivacyEn />
      )}
      <p className="mt-8 text-footnote text-muted-foreground">
        <Link to="/terms" className="inline-block py-3 -my-3 underline">
          {t("auth.terms")}
        </Link>
      </p>
    </article>
  );
}
