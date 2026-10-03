import { CHINESE_EXPLANATION_LANGUAGE } from "@/lib/target-lang";
import { siteUrlFor } from "@/lib/site-url";
import { createFileRoute, Link } from "@tanstack/react-router";
import { tStatic, useUiLang, useT } from "@/lib/i18n";
import { DataSourcesList } from "@/components/DataSourcesList";

export const Route = createFileRoute("/terms")({
  head: () => ({
    meta: [
      { title: tStatic("page.terms") },
      {
        name: "description",
        content:
          "CatchWordsの利用規約。アカウント、投稿コンテンツ、禁止事項、知的財産、免責などサービス利用に関する条件を定めています。",
      },
      { property: "og:title", content: "利用規約 — CatchWords" },
      {
        property: "og:description",
        content:
          "CatchWordsの利用規約。アカウント、投稿コンテンツ、禁止事項、知的財産、免責などサービス利用に関する条件を定めています。",
      },
      { property: "og:type", content: "article" },
      { property: "og:url", content: siteUrlFor("/terms") },
    ],
    links: [{ rel: "canonical", href: siteUrlFor("/terms") }],
  }),
  component: TermsPage,
});

/**
 * 利用規約。
 *
 * 法務文書は翻訳キーに刻まず、言語ごとに文書そのものを持つ。条文は単語の
 * 置き換えではなく文章として成り立っていないと意味がなく、細切れにすると
 * 後から条項を直したときに片方だけ古くなる。
 *
 * 準拠法・管轄は日本法のままで正しい(運営が日本のため)。英語版でも
 * そこは変えず、英語で同じ内容を述べている。
 */

function TermsJa() {
  return (
    <>
      <h1 className="mt-4 text-hero font-bold tracking-tight">利用規約</h1>
      <p className="mt-1 text-footnote text-muted-foreground">制定日: 2026年6月22日</p>
      <p className="mt-1 text-footnote text-muted-foreground">最終改定日: 【改定日】</p>
      <section className="prose prose-sm mt-6 max-w-none dark:prose-invert">
        <p>この利用規約（以下「本規約」）は、【運営者名】（以下「当社」）が提供する語学学習サービス「CatchWords」（iPhone アプリ、Web 版 <a href={siteUrlFor("/")}>{siteUrlFor("/")}</a> 、およびこれらに付随するサービスを含み、以下「本サービス」）の利用条件を定めるものです。</p>
        <h2>第1条（適用と同意）</h2>
        <ol>
          <li>本規約は、本サービスを利用するすべての方（以下「ユーザー」）と当社との間に適用されます。</li>
          <li>ユーザーは、本規約とプライバシーポリシー（<a href={siteUrlFor("/privacy")}>{siteUrlFor("/privacy")}</a> ）に同意したうえで本サービスを利用するものとします。アカウントを作成した時点、または本サービスを利用した時点で、本規約に同意したものとみなします。</li>
          <li>当社が本サービス上で示す個別の規定・注意書き（有料プランの説明、特定商取引法に基づく表記を含みます）は、本規約の一部を構成します。</li>
        </ol>
        <h2>第2条（アカウント）</h2>
        <ol>
          <li>ユーザーは、正確な情報でアカウントを作成し、ログインの情報を自分の責任で管理するものとします。</li>
          <li>13歳未満の方は本サービスを利用できません。18歳未満の方は、保護者（法定代理人）の同意を得てから本サービスを利用し、有料プランを購入するものとします。</li>
          <li>アカウントは本人だけが使えます。第三者への譲渡・貸与はできません。</li>
          <li>ログインの情報が第三者に使われたことにより生じた損害について、当社に故意または過失がある場合を除き、当社は責任を負いません。</li>
        </ol>
        <h2>第3条（本サービスの内容と AI の利用）</h2>
        <ol>
          <li>本サービスは、ユーザーが撮影した写真などから、AI（外部の事業者が提供する大規模言語モデルを含みます）を使って単語の候補・単語カード・解説・例文・添削などを作り、語学の学習を支援するサービスです。</li>
          <li>AI の機能を使うと、写真や文章がプライバシーポリシーに記載の外部の事業者に送られます。ユーザーは、初めて AI の機能を使う前に、その送信に同意するものとします。</li>
        </ol>
        <h2>第4条（AI が作る内容についての注意）</h2>
        <ol>
          <li>AI が作る内容（物の判定、単語の意味・読み方・発音・例文・文法の説明・添削・地名など）は、誤り・不正確な情報・不自然な表現を含むことがあります。当社は、その正確性・完全性・最新性を保証しません。</li>
          <li>ユーザーは、本サービスの内容を語学学習の参考として利用し、重要な場面（試験、仕事、契約、翻訳の提出など）では辞書や専門家などで確認するものとします。</li>
          <li>
            本サービスを、次のような安全や健康に関わる判断に使わないでください。
            <ul>
              <li>食べ物・植物・きのこ・薬・化学品などが食べられるか、安全かの判断</li>
              <li>医療・健康・アレルギーに関する判断</li>
              <li>標識・警告表示・取扱説明の意味の確認を前提とした危険な作業</li>
            </ul>
          </li>
          <li>AI が作る内容が、他者の権利を侵害する、または不快なものであることに気づいた場合は、アプリ内の「この語の誤りを報告」または第21条の窓口からお知らせください。</li>
        </ol>
        <h2>第5条（ユーザーのコンテンツ）</h2>
        <ol>
          <li>ユーザーが本サービスに登録した写真・自撮り写真・日記・メモ・キャプションなど（以下「ユーザーコンテンツ」）の著作権その他の権利は、ユーザー（またはその権利者）に帰属します。</li>
          <li>ユーザーは当社に対し、本サービスの提供・維持・改善（AI による処理、保存、表示、端末間の同期、バックアップ、不具合の調査を含みます）に必要な範囲で、ユーザーコンテンツを無償で利用する権利（当社の委託先に利用させる権利を含みます）を許諾します。この許諾は、ユーザーがユーザーコンテンツまたはアカウントを削除した時点で終了します（バックアップからの消去にかかる期間、および法令に基づく保存を除きます）。</li>
          <li>当社は、ユーザーコンテンツを本サービスの宣伝に使う場合は、事前にユーザーの同意を得ます。</li>
          <li>ユーザーは、ユーザーコンテンツについて必要な権利を持っていること、および第三者の権利（著作権・肖像権・プライバシーなど）を侵害しないことを保証します。人が写った写真を登録する場合は、その人の同意を得てください。</li>
          <li>単語の見出し語など、ユーザーが追加した辞書のデータは、他のユーザーの学習にも使われることがあります。アカウントを削除した後も、ユーザーとの結び付きを消したうえで残ることがあります。</li>
        </ol>
        <h2>第6条（禁止事項）</h2>
        <p>ユーザーは、次の行為をしてはなりません。</p>
        <ol>
          <li>法令または公序良俗に反する行為、犯罪に結び付く行為</li>
          <li>第三者の著作権・商標権・肖像権・プライバシーその他の権利を侵害する行為（他人を無断で撮影・登録することを含みます）</li>
          <li>位置情報を悪用したつきまといなど、他人に迷惑・不利益・危害を与える行為</li>
          <li>わいせつ・暴力的・差別的な内容、児童を性的に扱う内容を登録する行為</li>
          <li>本サービスのサーバやネットワークに過度の負担をかける行為、自動化した手段による大量の利用、利用回数の上限を回避する行為</li>
          <li>本サービスの不正アクセス、リバースエンジニアリング、解析、改ざん、本サービスの AI に指示を与えて意図しない動作をさせる行為</li>
          <li>本サービスや AI が作った内容を、当社の許可なく販売・再配布し、または他の AI サービスの開発に使う行為</li>
          <li>他人になりすます行為、虚偽の情報を登録する行為</li>
          <li>その他、当社が本サービスの運営上ふさわしくないと合理的に判断する行為</li>
        </ol>
        <h2>第7条（知的財産権）</h2>
        <p>本サービスのプログラム、ロゴ、デザイン、画面の構成、AI が作るカードのフォーマットなどの知的財産権は、当社または正当な権利者に帰属します。本規約は、本サービスを利用するための許諾を除き、これらの権利をユーザーに譲渡・許諾するものではありません。本サービスで使う辞書データなどの出典と利用条件は、本規約のページの末尾に記載します。</p>
        <h2>第8条（有料プラン）</h2>
        <ol>
          <li>当社は、本サービスの一部の機能を有料プラン（「CatchWords Pro」など、以下「有料プラン」）として提供することがあります。内容・価格・期間は、購入の画面と特定商取引法に基づく表記（<a href={siteUrlFor("/tokushoho")}>{siteUrlFor("/tokushoho")}</a> ）に示します。</li>
          <li>有料プランは、ユーザーが解約しない限り、同じ期間・同じ価格で自動的に更新される定期購入（サブスクリプション）です。</li>
          <li>無料体験がある場合、その期間と、終了後に請求される価格は購入の画面に示します。無料体験の終了までに解約しない場合、有料プランに自動的に切り替わり、料金が請求されます。</li>
          <li>価格を変更する場合は、事前にお知らせします。Apple のアプリ内課金の場合は、Apple の定める手続きに従います。</li>
        </ol>
        <h2>第9条（iPhone アプリでの購入：Apple のアプリ内課金）</h2>
        <ol>
          <li>iPhone アプリの有料プランは、Apple のアプリ内課金で購入します。お支払いは、購入を確定した時点で Apple ID のアカウントに請求されます。</li>
          <li>購読は、期間が終わる24時間前までに自動更新をオフにしない限り自動的に更新され、期間が終わる前の24時間以内に次の期間の料金が請求されます。</li>
          <li>解約（自動更新の停止）は、iPhone の「設定」→ 自分の名前 →「サブスクリプション」、または App Store のアカウント設定からいつでも行えます。アプリを削除したり、本サービスのアカウントを削除したりしても、購読は解約されません。</li>
          <li>返金は Apple の定める条件と手続き（<a href="https://reportaproblem.apple.com" target="_blank" rel="noopener noreferrer">https://reportaproblem.apple.com</a> など）によります。当社は Apple のアプリ内課金の返金を直接行うことはできません。</li>
          <li>Web 版で購入した有料プランは、iPhone アプリでは有効にならない場合があります。</li>
        </ol>
        <h2>第10条（Web 版での購入：Stripe）</h2>
        <ol>
          <li>Web 版の有料プランは、決済代行事業者 Stripe を通じて、クレジットカードなどで支払います。初回の料金は申し込み時に、以後は各更新日に請求されます。</li>
          <li>解約は、【Web 版の「設定」→「CatchWords Pro」→「プランを管理」から／または第21条の窓口へのメールで】いつでも行えます。解約すると、その時点の期間の終わりまで有料プランを利用でき、次の期間からは請求されません。</li>
          <li>デジタルサービスの性質上、申し込み後のお客様の都合による返金・日割りでの返金はいたしません。ただし、当社の責めに帰すべき事由により有料プランを利用できなかった場合、および法令（お住まいの国の消費者保護法を含みます）により返金が必要な場合は、この限りではありません。</li>
        </ol>
        <h2>第11条（本サービスの変更・中断・終了）</h2>
        <ol>
          <li>当社は、本サービスの内容を変更し、または新しい機能を追加・削除することがあります。有料プランの主要な内容をユーザーに不利に変更する場合は、事前にお知らせします。</li>
          <li>当社は、システムの保守、障害、外部の事業者（AI・クラウドなど）のサービスの停止、天災その他やむを得ない事由がある場合、本サービスの全部または一部を中断することがあります。</li>
          <li>当社は、本サービスを終了する場合、【30日】以上前にお知らせします。有料プランの期間が残っている場合の扱い（Stripe での日割りの返金など）は、その際にお知らせします。</li>
        </ol>
        <h2>第12条（利用の停止・アカウントの削除）</h2>
        <ol>
          <li>ユーザーが本規約に違反した場合、当社は、事前の通知なく、ユーザーコンテンツの削除、本サービスの利用の停止、アカウントの削除を行うことがあります。緊急の場合を除き、可能な範囲で事前にお知らせします。</li>
          <li>ユーザーは、アプリまたは Web 版の「設定」→「アカウントを削除」から、いつでもアカウントを削除して退会できます。アカウントを削除すると、データは元に戻せません。</li>
          <li>前項の場合でも、Apple のアプリ内課金の購読は自動では解約されません。第9条第3項の方法で解約してください。</li>
        </ol>
        <h2>第13条（保証の否認）</h2>
        <p>当社は、本サービスが、ユーザーの特定の目的に適合すること、期待する機能・正確性・有用性を持つこと、不具合や中断なく提供されることを保証しません。ただし、当社の故意または重大な過失による場合、および法令により保証を否認できない場合を除きます。</p>
        <h2>第14条（責任の制限）</h2>
        <ol>
          <li>当社は、本サービスに関してユーザーに生じた損害について、当社の故意または過失による場合に限り、責任を負います。</li>
          <li>当社の過失（重大な過失を除きます）による損害の賠償は、通常生じうる直接の損害に限り、その額は、損害が生じた月から遡って12か月間にユーザーが当社に支払った有料プランの料金の総額（支払いがない場合は【1万円】）を上限とします。</li>
          <li>前2項は、当社の故意または重大な過失による場合、人の生命・身体に対する損害の場合、その他法令（消費者契約法を含みます）により責任の制限が認められない場合には適用しません。</li>
        </ol>
        <h2>第15条（外部のサービス）</h2>
        <p>本サービスは、Apple、Google、Stripe、AI の事業者など、外部の事業者のサービスを利用します。ユーザーがそれらのサービス（Apple ID・Google アカウントでのログイン、App Store、Stripe の決済画面など）を使う場合は、それぞれの利用条件にも従うものとします。</p>
        <h2>第16条（個人情報）</h2>
        <p>当社は、ユーザーの個人情報をプライバシーポリシーに従って取り扱います。</p>
        <h2>第17条（輸出管理）</h2>
        <p>ユーザーは、日本、米国その他の国の輸出管理に関する法令に従って本サービスを利用するものとし、それらの法令で禁止された国・地域・者による利用、または禁止された目的での利用をしてはなりません。</p>
        <h2>第18条（App Store から入手した iPhone アプリに関する条項）</h2>
        <p>App Store から入手した iPhone アプリ（以下「本アプリ」）の利用については、本規約の他の条項に加えて、次の条項が適用されます。本条と他の条項が矛盾する場合は、本アプリについては本条が優先します。</p>
        <ol>
          <li>合意の当事者: 本規約は、ユーザーと当社との間の合意であり、Apple Inc.（以下「Apple」）との合意ではありません。本アプリとその内容について責任を負うのは当社であり、Apple ではありません。</li>
          <li>使用許諾の範囲: 当社はユーザーに対し、ユーザーが所有または管理する Apple ブランドの製品上で、Apple Media Services 利用規約に定める利用規則（ファミリー共有などで、購入者に関連付けられた他のアカウントによる利用を含みます）に従って本アプリを使用する、譲渡できない権利を許諾します。</li>
          <li>保守とサポート: 本アプリの保守とサポートは、本規約に定める範囲または法令の定める範囲で、当社だけが責任を負います。Apple は、本アプリの保守・サポートを提供する義務を一切負いません。</li>
          <li>保証: 本アプリが適用される保証（本規約で否認していないもの）に適合しない場合、ユーザーは Apple に通知することができ、Apple は本アプリの購入代金（ある場合）をユーザーに返金します。法令が許す最大の範囲で、Apple は本アプリに関してその他の保証責任を一切負わず、保証への不適合に起因するその他の請求・損失・責任・損害・費用は、当社の責任となります。</li>
          <li>製品に関する請求: 本アプリまたはユーザーによる本アプリの所持・使用に関するユーザーまたは第三者からの請求（製造物責任の請求、本アプリが法令・規制に適合しないとの請求、消費者保護・プライバシーその他これに類する法令に基づく請求を含みます）に対応する責任は、Apple ではなく当社が負います。</li>
          <li>知的財産権: 本アプリまたはユーザーによる本アプリの所持・使用が第三者の知的財産権を侵害するとの請求があった場合、その調査・防御・和解・解決の責任は、Apple ではなく当社が負います。</li>
          <li>法令の遵守: ユーザーは、(a) 米国政府の禁輸対象国、または米国政府により「テロ支援国家」に指定された国に所在しないこと、(b) 米国政府の禁止・制限対象者のリストに掲載されていないことを表明し、保証します。</li>
          <li>開発者の名称と連絡先: 本アプリに関するご質問・苦情・請求は、第21条の当社の窓口へご連絡ください。</li>
          <li>第三者の利用条件: ユーザーは、本アプリを使う際、該当する第三者の利用条件（通信事業者との契約など）に従うものとします。</li>
          <li>第三者受益者: Apple および Apple の子会社は、本規約の第三者受益者であり、ユーザーが本規約に同意した時点で、第三者受益者としてユーザーに対して本規約を執行する権利を持ち、その権利を承諾したものとみなされます。</li>
        </ol>
        <p>なお、本アプリには Apple の標準使用許諾契約（Licensed Application End User License Agreement、<a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/" target="_blank" rel="noopener noreferrer">https://www.apple.com/legal/internet-services/itunes/dev/stdeula/</a> ）も適用されます。本規約と Apple の標準使用許諾契約が矛盾する場合、本アプリの使用許諾については、Apple の標準使用許諾契約が優先します。</p>
        <h2>第19条（本規約の変更）</h2>
        <ol>
          <li>当社は、民法の定型約款の変更の規定に従い、本規約を変更することがあります。</li>
          <li>変更する場合は、変更後の内容と効力が生じる日を、効力が生じる日の【14日】前までに、アプリ内・Web 版でお知らせします。ユーザーに不利な重要な変更については、改めて同意をいただくことがあります。</li>
          <li>効力が生じた日以後にユーザーが本サービスを利用した場合、変更に同意したものとみなします。</li>
        </ol>
        <h2>第20条（準拠法・管轄・言語）</h2>
        <ol>
          <li>本規約は日本法に準拠します。ただし、ユーザーがお住まいの国の消費者保護に関する強行法規によって与えられる保護は、本条により妨げられません。</li>
          <li>本規約または本サービスに関する紛争については、【○○地方裁判所】を第一審の専属的合意管轄裁判所とします。ただし、消費者であるユーザーがお住まいの国の法令により、その国の裁判所で訴えを提起し、または訴えられる権利を持つ場合は、その権利は妨げられません。</li>
          <li>本規約は日本語・英語・繁体字中国語で提供します。内容に食い違いがある場合は、法令が許す範囲で、日本語版が優先します。</li>
        </ol>
        <h2>第21条（お問い合わせ）</h2>
        <p>本規約・本サービスに関するお問い合わせ、苦情、請求は、次の窓口へご連絡ください。</p>
        <ul>
          <li>事業者: 【運営者名】</li>
          <li>住所: 【住所】</li>
          <li>メール: 【お問い合わせメールアドレス】</li>
          <li>サポートページ: 【サポートページの URL】</li>
        </ul>
      </section>
    </>
  );
}

function TermsEn() {
  return (
    <>
      <h1 className="mt-4 text-hero font-bold tracking-tight">Terms of Use</h1>
      <p className="mt-1 text-footnote text-muted-foreground">Established: 22 June 2026</p>
      <p className="mt-1 text-footnote text-muted-foreground">Last revised: 【Revision date】</p>
      <section className="prose prose-sm mt-6 max-w-none dark:prose-invert">
        <p>These Terms of Use (the "Terms") set out the conditions for using the language-learning service "CatchWords" (including the iPhone app, the web app at <a href={siteUrlFor("/")}>{siteUrlFor("/")}</a> and related services; the "Service") provided by 【Operator name】 ("we", "us").</p>
        <h2>1. Scope and agreement</h2>
        <ol>
          <li>These Terms apply between us and everyone who uses the Service ("you").</li>
          <li>You must agree to these Terms and the Privacy Policy (<a href={siteUrlFor("/privacy")}>{siteUrlFor("/privacy")}</a>) to use the Service. You are deemed to have agreed to these Terms when you create an account or use the Service.</li>
          <li>Specific rules and notices we show in the Service (including descriptions of paid plans and the notice under Japan's Act on Specified Commercial Transactions) form part of these Terms.</li>
        </ol>
        <h2>2. Accounts</h2>
        <ol>
          <li>You must create your account with accurate information and keep your sign-in details secure at your own responsibility.</li>
          <li>Children under 13 may not use the Service. If you are under 18, you must have your parent's or guardian's consent to use the Service and to buy a paid plan.</li>
          <li>Your account is for you only. You may not transfer or lend it to anyone else.</li>
          <li>We are not responsible for damage caused by a third party using your sign-in details, unless we acted intentionally or negligently.</li>
        </ol>
        <h2>3. The Service and use of AI</h2>
        <ol>
          <li>The Service supports language learning by using AI (including large language models provided by outside companies) to create word suggestions, word cards, explanations, example sentences, corrections and so on from photos you take and other input.</li>
          <li>When you use AI features, photos and text are sent to the outside companies listed in the Privacy Policy. You agree to this before you first use an AI feature.</li>
        </ol>
        <h2>4. Notes on AI-generated content</h2>
        <ol>
          <li>AI-generated content (identification of objects, meanings, readings, pronunciation, example sentences, grammar explanations, corrections, place names and so on) may contain errors, inaccurate information or unnatural expressions. We do not warrant its accuracy, completeness or currency.</li>
          <li>Use the Service as a reference for language learning, and check with a dictionary or a qualified person in situations that matter (exams, work, contracts, translations you submit and so on).</li>
          <li>
            Do not use the Service for decisions that affect safety or health, such as:
            <ul>
              <li>whether a food, plant, mushroom, medicine or chemical is edible or safe;</li>
              <li>medical, health or allergy decisions; or</li>
              <li>dangerous work that relies on understanding signs, warnings or instructions.</li>
            </ul>
          </li>
          <li>If you notice AI-generated content that infringes someone's rights or is offensive, please tell us through "Report a mistake in this word" in the app or the contact point in section 21.</li>
        </ol>
        <h2>5. Your content</h2>
        <ol>
          <li>Copyright and other rights in the photos, selfies, journal entries, notes, captions and other content you add to the Service ("User Content") remain with you (or their owner).</li>
          <li>You grant us a free licence to use User Content (including the right to let our service providers use it) to the extent necessary to provide, maintain and improve the Service, including AI processing, storage, display, syncing between devices, backups and investigating bugs. This licence ends when you delete the User Content or your account (except for the time needed to erase it from backups and any retention required by law).</li>
          <li>We will ask for your consent before using User Content to promote the Service.</li>
          <li>You warrant that you have the necessary rights to your User Content and that it does not infringe anyone's rights (copyright, portrait rights, privacy and so on). If you add a photo of a person, get that person's consent.</li>
          <li>Dictionary data you add, such as headwords, may be used in other learners' study. It may remain after you delete your account, after its link to you is removed.</li>
        </ol>
        <h2>6. Prohibited conduct</h2>
        <p>You must not:</p>
        <ol>
          <li>act against the law or public order and morals, or in connection with a crime;</li>
          <li>infringe anyone's copyright, trademark, portrait rights, privacy or other rights (including photographing and adding other people without permission);</li>
          <li>bother, disadvantage or harm others, including stalking by misusing location data;</li>
          <li>add obscene, violent or discriminatory content, or content that sexualises children;</li>
          <li>place an excessive load on the Service's servers or network, use the Service in bulk by automated means, or circumvent usage limits;</li>
          <li>access the Service without authorisation, reverse engineer, analyse or tamper with it, or instruct its AI to make it behave in unintended ways;</li>
          <li>sell or redistribute the Service or AI-generated content without our permission, or use it to develop another AI service;</li>
          <li>impersonate others or register false information; or</li>
          <li>do anything else we reasonably judge inappropriate for operating the Service.</li>
        </ol>
        <h2>7. Intellectual property</h2>
        <p>Intellectual property in the Service — including its software, logo, design, screen layout and the format of AI-generated cards — belongs to us or the rightful owners. Except for the permission to use the Service, these Terms do not transfer or license those rights to you. Sources and terms of use of dictionary data and similar used in the Service are listed at the end of the Terms page.</p>
        <h2>8. Paid plans</h2>
        <ol>
          <li>We may offer some features of the Service as a paid plan (such as "CatchWords Pro"; a "Paid Plan"). Its content, price and period are shown on the purchase screen and in the notice under the Act on Specified Commercial Transactions (<a href={siteUrlFor("/tokushoho")}>{siteUrlFor("/tokushoho")}</a>).</li>
          <li>A Paid Plan is an auto-renewing subscription that renews for the same period at the same price unless you cancel.</li>
          <li>If there is a free trial, its length and the price charged after it ends are shown on the purchase screen. Unless you cancel before the trial ends, it automatically becomes a Paid Plan and you will be charged.</li>
          <li>We will give notice before changing prices. For Apple in-app purchases, Apple's procedures apply.</li>
        </ol>
        <h2>9. Purchases in the iPhone app (Apple in-app purchase)</h2>
        <ol>
          <li>Paid Plans in the iPhone app are bought through Apple's in-app purchase. Payment is charged to your Apple ID account when you confirm the purchase.</li>
          <li>The subscription renews automatically unless auto-renew is turned off at least 24 hours before the end of the current period, and your account is charged for the next period within the 24 hours before the current period ends.</li>
          <li>You can cancel (turn off auto-renew) at any time in iPhone Settings → your name → Subscriptions, or in your App Store account settings. Deleting the app or your Service account does not cancel the subscription.</li>
          <li>Refunds are subject to Apple's conditions and procedures (such as <a href="https://reportaproblem.apple.com" target="_blank" rel="noopener noreferrer">https://reportaproblem.apple.com</a>). We cannot directly issue refunds for Apple in-app purchases.</li>
          <li>A Paid Plan bought on the web may not be active in the iPhone app.</li>
        </ol>
        <h2>10. Purchases on the web (Stripe)</h2>
        <ol>
          <li>Paid Plans on the web are paid by credit card or other methods through the payment provider Stripe. The first charge is made when you subscribe, and subsequent charges on each renewal date.</li>
          <li>You can cancel at any time 【from Settings → "CatchWords Pro" → "Manage plan" on the web / or by email to the contact point in section 21】. After you cancel, you can use the Paid Plan until the end of the current period and will not be charged for the next period.</li>
          <li>Because of the nature of digital services, we do not give refunds, including pro-rata refunds, for changes of mind after you subscribe. This does not apply where you could not use the Paid Plan for reasons attributable to us, or where the law (including consumer protection law in your country) requires a refund.</li>
        </ol>
        <h2>11. Changes, interruption and termination of the Service</h2>
        <ol>
          <li>We may change the Service or add or remove features. We will give notice in advance before changing the main content of a Paid Plan to your disadvantage.</li>
          <li>We may interrupt all or part of the Service for system maintenance, failures, suspension of outside services (AI, cloud and so on), natural disasters or other unavoidable reasons.</li>
          <li>If we end the Service, we will give at least 【30 days'】 notice, together with how any remaining Paid Plan period will be handled (such as pro-rata refunds for Stripe).</li>
        </ol>
        <h2>12. Suspension and account deletion</h2>
        <ol>
          <li>If you breach these Terms, we may delete User Content, suspend your use of the Service or delete your account without prior notice. Except in emergencies, we will give notice in advance where possible.</li>
          <li>You may delete your account and leave at any time from Settings → "Delete account" in the app or on the web. Deleted data cannot be restored.</li>
          <li>Even then, Apple in-app purchase subscriptions are not cancelled automatically. Cancel them as described in section 9(3).</li>
        </ol>
        <h2>13. Disclaimer of warranties</h2>
        <p>We do not warrant that the Service will fit your particular purpose, have the functions, accuracy or usefulness you expect, or be provided without bugs or interruption. This does not apply where we acted intentionally or with gross negligence, or where the law does not allow warranties to be disclaimed.</p>
        <h2>14. Limitation of liability</h2>
        <ol>
          <li>We are liable for damage you suffer in connection with the Service only where it is caused by our intent or negligence.</li>
          <li>Our liability for damage caused by our negligence (other than gross negligence) is limited to direct damage that would normally arise, up to the total Paid Plan fees you paid us in the 12 months before the month in which the damage occurred (or 【JPY 10,000】 if you paid nothing).</li>
          <li>Paragraphs 1 and 2 do not apply to damage caused by our intent or gross negligence, to death or personal injury, or where the law (including Japan's Consumer Contract Act) does not allow liability to be limited.</li>
        </ol>
        <h2>15. Outside services</h2>
        <p>The Service uses services of outside companies such as Apple, Google, Stripe and AI companies. When you use those services (signing in with an Apple ID or Google account, the App Store, Stripe's checkout and so on), you must also follow their terms.</p>
        <h2>16. Personal information</h2>
        <p>We handle your personal information in accordance with the Privacy Policy.</p>
        <h2>17. Export control</h2>
        <p>You must use the Service in compliance with the export control laws of Japan, the United States and other countries, and must not use it in, or as, a country, region or person prohibited by those laws, or for a prohibited purpose.</p>
        <h2>18. Terms for the iPhone app obtained from the App Store</h2>
        <p>In addition to the other sections of these Terms, the following applies to your use of the iPhone app obtained from the App Store (the "App"). If this section conflicts with other sections, this section prevails for the App.</p>
        <ol>
          <li>Acknowledgement: these Terms are concluded between you and us only, and not with Apple Inc. ("Apple"). We, not Apple, are solely responsible for the App and its content.</li>
          <li>Scope of licence: we grant you a non-transferable licence to use the App on any Apple-branded products that you own or control, as permitted by the Usage Rules set out in the Apple Media Services Terms and Conditions, except that the App may be accessed and used by other accounts associated with the purchaser via Family Sharing or volume purchasing.</li>
          <li>Maintenance and support: we are solely responsible for providing maintenance and support for the App, as specified in these Terms or as required by law. Apple has no obligation whatsoever to furnish any maintenance and support services for the App.</li>
          <li>Warranty: if the App fails to conform to any applicable warranty not disclaimed in these Terms, you may notify Apple, and Apple will refund the purchase price (if any) of the App to you. To the maximum extent permitted by law, Apple has no other warranty obligation whatsoever with respect to the App, and any other claims, losses, liabilities, damages, costs or expenses attributable to any failure to conform to any warranty are our responsibility.</li>
          <li>Product claims: we, not Apple, are responsible for addressing any claims by you or any third party relating to the App or your possession and/or use of it, including product liability claims, claims that the App fails to conform to any applicable legal or regulatory requirement, and claims arising under consumer protection, privacy or similar legislation.</li>
          <li>Intellectual property rights: in the event of any third-party claim that the App or your possession and use of it infringes that third party's intellectual property rights, we, not Apple, are solely responsible for the investigation, defence, settlement and discharge of that claim.</li>
          <li>Legal compliance: you represent and warrant that (a) you are not located in a country that is subject to a U.S. Government embargo or that has been designated by the U.S. Government as a "terrorist supporting" country, and (b) you are not listed on any U.S. Government list of prohibited or restricted parties.</li>
          <li>Developer name and address: please direct any questions, complaints or claims about the App to our contact point in section 21.</li>
          <li>Third-party terms: you must comply with applicable third-party terms of agreement (such as your wireless data service agreement) when using the App.</li>
          <li>Third-party beneficiary: Apple and Apple's subsidiaries are third-party beneficiaries of these Terms, and upon your acceptance of these Terms, Apple will have the right (and will be deemed to have accepted the right) to enforce these Terms against you as a third-party beneficiary.</li>
        </ol>
        <p>Apple's Licensed Application End User License Agreement (<a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/" target="_blank" rel="noopener noreferrer">https://www.apple.com/legal/internet-services/itunes/dev/stdeula/</a>) also applies to the App. If these Terms conflict with it, Apple's standard agreement prevails as to the licence of the App.</p>
        <h2>19. Changes to these Terms</h2>
        <ol>
          <li>We may change these Terms in accordance with the provisions of Japan's Civil Code on changes to standard terms.</li>
          <li>We will announce the changed content and its effective date in the app and on the web at least 【14 days】 before it takes effect. For important changes to your disadvantage, we may ask for your consent again.</li>
          <li>If you use the Service on or after the effective date, you are deemed to have agreed to the changes.</li>
        </ol>
        <h2>20. Governing law, jurisdiction and language</h2>
        <ol>
          <li>These Terms are governed by the laws of Japan. This does not deprive you of the protection given by mandatory consumer protection laws of the country where you live.</li>
          <li>The 【________ District Court】 has exclusive jurisdiction as the court of first instance over any dispute relating to these Terms or the Service. This does not affect any right you have as a consumer under the laws of your country to bring or defend proceedings in the courts of that country.</li>
          <li>These Terms are provided in Japanese, English and Traditional Chinese. If there is any inconsistency, the Japanese version prevails to the extent permitted by law.</li>
        </ol>
        <h2>21. Contact</h2>
        <p>For questions, complaints or claims about these Terms or the Service, please contact:</p>
        <ul>
          <li>Operator: 【Operator name】</li>
          <li>Address: 【Address】</li>
          <li>Email: 【Contact email】</li>
          <li>Support page: 【Support page URL】</li>
        </ul>
      </section>
    </>
  );
}

function TermsZhTw() {
  return (
    <>
      <h1 className="mt-4 text-hero font-bold tracking-tight">使用條款</h1>
      <p className="mt-1 text-footnote text-muted-foreground">制定日期：2026年6月22日</p>
      <p className="mt-1 text-footnote text-muted-foreground">最後修訂日期：【修訂日期】</p>
      <section className="prose prose-sm mt-6 max-w-none dark:prose-invert">
        <p>本使用條款（以下稱「本條款」）訂定【營運者名稱】（以下稱「本公司」）所提供之語言學習服務「CatchWords」（包括 iPhone App、網頁版 <a href={siteUrlFor("/")}>{siteUrlFor("/")}</a> 及相關服務，以下稱「本服務」）的使用條件。</p>
        <h2>第1條（適用及同意）</h2>
        <ol>
          <li>本條款適用於使用本服務的所有人（以下稱「使用者」）與本公司之間。</li>
          <li>使用者應同意本條款及隱私權政策（<a href={siteUrlFor("/privacy")}>{siteUrlFor("/privacy")}</a> ）後使用本服務。使用者建立帳號或使用本服務時，視為已同意本條款。</li>
          <li>本公司於本服務中所示的個別規定及注意事項（包括付費方案的說明、依日本《特定商取引法》的標示），構成本條款的一部分。</li>
        </ol>
        <h2>第2條（帳號）</h2>
        <ol>
          <li>使用者應以正確資料建立帳號，並自行負責妥善管理登入資料。</li>
          <li>未滿13歲者不得使用本服務。未滿18歲者，應取得法定代理人（家長或監護人）同意後，始得使用本服務及購買付費方案。</li>
          <li>帳號僅限本人使用，不得轉讓或出借予第三方。</li>
          <li>因第三方使用登入資料所生之損害，除本公司有故意或過失外，本公司不負責任。</li>
        </ol>
        <h2>第3條（本服務的內容及 AI 的使用）</h2>
        <ol>
          <li>本服務是透過 AI（包括外部業者提供的大型語言模型），由使用者拍攝的照片等產生單字候選、單字卡、解說、例句、批改等，以協助語言學習的服務。</li>
          <li>使用 AI 功能時，照片及文字會傳送給隱私權政策所列的外部業者。使用者於首次使用 AI 功能前，應同意該傳送。</li>
        </ol>
        <h2>第4條（關於 AI 產生內容的注意事項）</h2>
        <ol>
          <li>AI 產生的內容（物品判斷、單字的意思・讀音・發音・例句・文法說明・批改・地名等）可能含有錯誤、不正確的資訊或不自然的表達。本公司不保證其正確性、完整性或即時性。</li>
          <li>使用者應將本服務的內容作為語言學習的參考，並於重要場合（考試、工作、契約、提交的翻譯等）以辭典或專業人士確認。</li>
          <li>
            請勿將本服務用於下列涉及安全或健康的判斷：
            <ul>
              <li>判斷食物、植物、菇類、藥品、化學品等是否可食用或安全</li>
              <li>醫療、健康、過敏相關的判斷</li>
              <li>以理解標誌、警告標示或使用說明為前提的危險作業</li>
            </ul>
          </li>
          <li>若發現 AI 產生的內容侵害他人權利或令人不快，請透過 App 內的「回報這個詞的錯誤」或第21條的窗口通知本公司。</li>
        </ol>
        <h2>第5條（使用者的內容）</h2>
        <ol>
          <li>使用者於本服務登錄的照片、自拍照、日記、筆記、圖說等（以下稱「使用者內容」）之著作權及其他權利，歸屬於使用者（或其權利人）。</li>
          <li>使用者同意在提供、維護及改善本服務（包括 AI 處理、儲存、顯示、裝置間同步、備份、調查問題）所需範圍內，無償授權本公司利用使用者內容（包括讓本公司的受託業者利用的權利）。此授權於使用者刪除該使用者內容或帳號時終止（但從備份中清除所需期間及依法令保存者除外）。</li>
          <li>本公司將使用者內容用於宣傳本服務前，將事先取得使用者同意。</li>
          <li>使用者保證其對使用者內容擁有必要的權利，且不侵害第三方的權利（著作權、肖像權、隱私權等）。登錄拍有他人的照片時，請取得該人的同意。</li>
          <li>使用者新增的單字詞條等辭典資料，可能也用於其他使用者的學習；刪除帳號後，可能在解除與使用者的連結後保留。</li>
        </ol>
        <h2>第6條（禁止事項）</h2>
        <p>使用者不得有下列行為：</p>
        <ol>
          <li>違反法令或公共秩序善良風俗的行為，或與犯罪相關的行為</li>
          <li>侵害第三方著作權、商標權、肖像權、隱私權或其他權利的行為（包括未經同意拍攝及登錄他人）</li>
          <li>濫用位置資訊進行跟蹤騷擾等，對他人造成困擾、不利益或危害的行為</li>
          <li>登錄猥褻、暴力、歧視性的內容，或將兒童性化的內容</li>
          <li>對本服務的伺服器或網路造成過度負擔、以自動化方式大量使用、規避使用次數上限的行為</li>
          <li>未經授權存取、還原工程、分析、竄改本服務，或對本服務的 AI 下達指令使其進行非預期動作的行為</li>
          <li>未經本公司許可販售或再散布本服務或 AI 產生的內容，或用於開發其他 AI 服務的行為</li>
          <li>冒充他人或登錄不實資料的行為</li>
          <li>其他本公司合理認為不適合本服務營運的行為</li>
        </ol>
        <h2>第7條（智慧財產權）</h2>
        <p>本服務的程式、標誌、設計、畫面構成、AI 產生之卡片格式等的智慧財產權，歸屬於本公司或正當權利人。除使用本服務之授權外，本條款並未將這些權利讓與或授權予使用者。本服務所使用之辭典資料等的出處及使用條件，記載於本條款頁面的末尾。</p>
        <h2>第8條（付費方案）</h2>
        <ol>
          <li>本公司可能將本服務的部分功能作為付費方案（「CatchWords Pro」等，以下稱「付費方案」）提供。其內容、價格及期間，記載於購買畫面及依《特定商取引法》的標示（<a href={siteUrlFor("/tokushoho")}>{siteUrlFor("/tokushoho")}</a> ）。</li>
          <li>付費方案為除非使用者取消，否則會以相同期間、相同價格自動續訂的定期購買（訂閱）。</li>
          <li>如有免費試用，其期間及結束後收取的價格將顯示於購買畫面。若未於免費試用結束前取消，將自動轉為付費方案並收取費用。</li>
          <li>變更價格時，本公司將事先通知。Apple 的 App 內購買則依 Apple 所定程序辦理。</li>
        </ol>
        <h2>第9條（於 iPhone App 購買：Apple 的 App 內購買）</h2>
        <ol>
          <li>iPhone App 的付費方案透過 Apple 的 App 內購買購買。款項於確認購買時向 Apple ID 帳號收取。</li>
          <li>除非在期間結束前至少24小時關閉自動續訂，否則訂閱將自動續訂，並於期間結束前24小時內收取下一期的費用。</li>
          <li>您可隨時在 iPhone 的「設定」→ 您的名稱 →「訂閱項目」，或 App Store 的帳號設定中取消（停止自動續訂）。刪除 App 或刪除本服務的帳號，均不會取消訂閱。</li>
          <li>退款依 Apple 所定的條件及程序（例如 <a href="https://reportaproblem.apple.com" target="_blank" rel="noopener noreferrer">https://reportaproblem.apple.com</a> ）辦理。本公司無法直接辦理 Apple App 內購買的退款。</li>
          <li>於網頁版購買的付費方案，可能無法在 iPhone App 中生效。</li>
        </ol>
        <h2>第10條（於網頁版購買：Stripe）</h2>
        <ol>
          <li>網頁版的付費方案透過付款代收業者 Stripe，以信用卡等方式付款。首期費用於申請時收取，之後於每個續訂日收取。</li>
          <li>您可隨時【於網頁版「設定」→「CatchWords Pro」→「管理方案」／或以電子郵件聯絡第21條的窗口】取消。取消後，您可使用付費方案至當期結束，下一期起不再收費。</li>
          <li>基於數位服務的性質，申請後因使用者個人因素所為之退款或按日計算之退款，恕不受理。但因可歸責於本公司之事由而無法使用付費方案，或依法令（包括您居住國的消費者保護法）須退款者，不在此限。</li>
        </ol>
        <h2>第11條（本服務的變更、中斷及終止）</h2>
        <ol>
          <li>本公司可能變更本服務的內容，或新增、刪除功能。若將付費方案的主要內容作不利於使用者的變更，將事先通知。</li>
          <li>因系統維護、故障、外部業者（AI、雲端等）服務停止、天災或其他不得已之事由，本公司可能中斷本服務的全部或一部。</li>
          <li>本公司終止本服務時，將於【30天】前通知，並一併告知付費方案剩餘期間的處理方式（如 Stripe 的按日退款等）。</li>
        </ol>
        <h2>第12條（停止使用及刪除帳號）</h2>
        <ol>
          <li>使用者違反本條款時，本公司得不經事先通知，刪除使用者內容、停止其使用本服務或刪除其帳號。除緊急情形外，將盡可能事先通知。</li>
          <li>使用者可隨時透過 App 或網頁版的「設定」→「刪除帳號」刪除帳號並退出。刪除後的資料無法復原。</li>
          <li>前項情形，Apple App 內購買的訂閱亦不會自動取消，請依第9條第3項的方式取消。</li>
        </ol>
        <h2>第13條（不為保證）</h2>
        <p>本公司不保證本服務符合使用者的特定目的、具有使用者期待的功能、正確性或有用性，或在無問題及無中斷的情況下提供。但因本公司故意或重大過失所致者，或依法令不得排除保證者，不在此限。</p>
        <h2>第14條（責任限制）</h2>
        <ol>
          <li>就使用者因本服務所受之損害，本公司僅於有故意或過失時負責。</li>
          <li>因本公司過失（重大過失除外）所生損害之賠償，以通常可能發生之直接損害為限，其金額以損害發生當月往前回溯12個月內使用者支付予本公司之付費方案費用總額（未付費者為【日幣1萬元】）為上限。</li>
          <li>前2項規定，於本公司故意或重大過失、對人之生命或身體之損害，或依法令（包括日本《消費者契約法》及臺灣《消費者保護法》）不得限制責任之情形，不適用之。</li>
        </ol>
        <h2>第15條（外部服務）</h2>
        <p>本服務使用 Apple、Google、Stripe、AI 業者等外部業者的服務。使用者使用這些服務（以 Apple ID・Google 帳號登入、App Store、Stripe 的付款畫面等）時，亦應遵守各該服務的使用條件。</p>
        <h2>第16條（個人資料）</h2>
        <p>本公司依隱私權政策處理使用者的個人資料。</p>
        <h2>第17條（出口管制）</h2>
        <p>使用者應遵守日本、美國及其他國家有關出口管制的法令使用本服務，不得由該等法令所禁止的國家、地區或人使用，或為所禁止的目的使用。</p>
        <h2>第18條（自 App Store 取得之 iPhone App 的條款）</h2>
        <p>使用自 App Store 取得的 iPhone App（以下稱「本 App」）時，除本條款其他條文外，另適用下列條款。本條與其他條文牴觸時，就本 App 以本條為優先。</p>
        <ol>
          <li>契約當事人：本條款係使用者與本公司之間的契約，而非與 Apple Inc.（以下稱「Apple」）的契約。對本 App 及其內容負責者為本公司，而非 Apple。</li>
          <li>授權範圍：本公司授予使用者不可轉讓的權利，得於使用者擁有或控制的 Apple 品牌產品上，依 Apple 媒體服務條款與約定所定之使用規則使用本 App（包括透過家人共享等由與購買者相關聯之其他帳號使用）。</li>
          <li>維護及支援：本 App 的維護及支援，僅由本公司依本條款所定範圍或法令所定範圍負責。Apple 無提供本 App 維護及支援服務的任何義務。</li>
          <li>保證：本 App 不符合適用之保證（本條款未排除者）時，使用者得通知 Apple，Apple 將退還本 App 的購買價款（如有）。在法令允許的最大範圍內，Apple 就本 App 不負其他任何保證責任，因不符合保證所生之其他請求、損失、責任、損害及費用，由本公司負責。</li>
          <li>產品相關請求：使用者或第三方就本 App 或使用者持有、使用本 App 所提出的請求（包括產品責任請求、本 App 不符合法令或規範之請求、依消費者保護、隱私或類似法令提出之請求），由本公司而非 Apple 負責處理。</li>
          <li>智慧財產權：若第三方主張本 App 或使用者持有、使用本 App 侵害其智慧財產權，該請求之調查、防禦、和解及解決，由本公司而非 Apple 負責。</li>
          <li>遵守法令：使用者聲明並保證：(a) 未位於受美國政府禁運之國家，或經美國政府指定為「支持恐怖主義」之國家；(b) 未列名於美國政府之禁止或限制對象名單。</li>
          <li>開發者名稱及聯絡方式：有關本 App 的問題、申訴或請求，請聯絡第21條所列本公司窗口。</li>
          <li>第三方條款：使用者使用本 App 時，應遵守適用之第三方契約條款（例如行動數據服務契約）。</li>
          <li>第三方受益人：Apple 及其子公司為本條款之第三方受益人；使用者同意本條款時，Apple 即享有（並視為已接受）以第三方受益人身分對使用者執行本條款之權利。</li>
        </ol>
        <p>本 App 另適用 Apple 的標準授權應用程式終端使用者授權協議（Licensed Application End User License Agreement，<a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/" target="_blank" rel="noopener noreferrer">https://www.apple.com/legal/internet-services/itunes/dev/stdeula/</a> ）。本條款與該協議牴觸時，就本 App 的授權以 Apple 的標準協議為優先。</p>
        <h2>第19條（本條款的變更）</h2>
        <ol>
          <li>本公司得依日本《民法》有關定型約款變更之規定變更本條款。</li>
          <li>變更時，本公司將於生效日【14天】前，在 App 內及網頁版公告變更後的內容及生效日期。對使用者不利的重大變更，本公司可能再次徵求同意。</li>
          <li>使用者於生效日後使用本服務者，視為同意該變更。</li>
        </ol>
        <h2>第20條（準據法、管轄及語言）</h2>
        <ol>
          <li>本條款以日本法為準據法。但使用者居住國有關消費者保護之強制規定所賦予的保護，不因本條而受影響。</li>
          <li>與本條款或本服務相關之爭議，以【○○地方法院（日本）】為第一審專屬合意管轄法院。但身為消費者的使用者依其居住國法令，享有於該國法院提起訴訟或應訴之權利者，該權利不受影響。</li>
          <li>本條款以日文、英文及繁體中文提供。內容如有不一致，在法令允許的範圍內以日文版為準。</li>
        </ol>
        <h2>第21條（聯絡方式）</h2>
        <p>有關本條款或本服務的問題、申訴或請求，請聯絡下列窗口：</p>
        <ul>
          <li>營運者：【營運者名稱】</li>
          <li>地址：【地址】</li>
          <li>電子郵件：【聯絡電子郵件】</li>
          <li>支援頁面：【支援頁面網址】</li>
        </ul>
      </section>
    </>
  );
}

function TermsPage() {
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
        <TermsJa />
      ) : lang === CHINESE_EXPLANATION_LANGUAGE ? (
        <TermsZhTw />
      ) : (
        <TermsEn />
      )}
      <p className="mt-8 flex flex-wrap gap-x-6 text-footnote text-muted-foreground">
        <Link to="/privacy" className="inline-block py-3 -my-3 underline">
          {t("auth.privacy")}
        </Link>
        {/* 特商法の表記は日本の法律の表示なので日本語だけ（名前も日本語のまま）。 */}
        <a href="/tokushoho" className="inline-block py-3 -my-3 underline">
          特定商取引法に基づく表記
        </a>
      </p>
      {/* 出典は**ここに置く**(オーナー指示「約款の中など全く目立たない所に、
          小さい字で」)。CEFR-J は出典明記が利用の条件なので**消せない**が、
          学習者が毎日開く設定の主な流れに置く理由も無い。 */}
      <DataSourcesList />
    </article>
  );
}
