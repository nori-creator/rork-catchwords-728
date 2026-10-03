import { siteUrlFor } from "@/lib/site-url";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useT } from "@/lib/i18n";

/**
 * 特定商取引法に基づく表記。
 *
 * 日本の法律が求める表示なので、表示言語に関係なく日本語だけで出す。
 * 正本は iOS リポジトリの docs/legal/tokushoho.ja.md。
 */
export const Route = createFileRoute("/tokushoho")({
  head: () => ({
    meta: [
      { title: "特定商取引法に基づく表記 — CatchWords" },
      {
        name: "description",
        content:
          "CatchWords Pro(有料プラン)の特定商取引法に基づく表記。販売事業者、価格、支払時期、提供時期、解約・返金、動作環境について記載しています。",
      },
      { property: "og:url", content: siteUrlFor("/tokushoho") },
    ],
    links: [{ rel: "canonical", href: siteUrlFor("/tokushoho") }],
  }),
  component: TokushohoPage,
});

function TokushohoJa() {
  return (
    <>
      <h1 className="mt-4 text-hero font-bold tracking-tight">特定商取引法に基づく表記</h1>
      <section className="prose prose-sm mt-6 max-w-none dark:prose-invert">
        <table>
          <thead>
            <tr>
              <th>項目</th>
              <th>内容</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>販売事業者</td>
              <td>【運営者名（法人名、または個人の氏名）】</td>
            </tr>
            <tr>
              <td>運営統括責任者</td>
              <td>【代表者または責任者の氏名】</td>
            </tr>
            <tr>
              <td>所在地</td>
              <td>【住所】（個人で省略する場合: 「請求があった場合には、遅滞なく電子メールにて開示いたします。」）</td>
            </tr>
            <tr>
              <td>電話番号</td>
              <td>【電話番号】（省略する場合: 「請求があった場合には、遅滞なく電子メールにて開示いたします。」）／受付時間: 【例: 平日10:00〜17:00】</td>
            </tr>
            <tr>
              <td>メールアドレス</td>
              <td>【お問い合わせメールアドレス】</td>
            </tr>
            <tr>
              <td>サービスの名称</td>
              <td>CatchWords Pro（語学学習サービス「CatchWords」の有料プラン）</td>
            </tr>
            <tr>
              <td>販売価格</td>
              <td>Web 版（Stripe）: 月額プラン 【980】円（税込）／年額プラン 【7,800】円（税込）<br />iPhone アプリ（App Store）: アプリ内の購入画面に表示される価格（税込）。国・地域によって表示される価格と通貨は異なります</td>
            </tr>
            <tr>
              <td>商品代金以外の必要料金</td>
              <td>インターネットに接続するための通信料はお客様のご負担となります</td>
            </tr>
            <tr>
              <td>支払方法</td>
              <td>Web 版: クレジットカード等、Stripe が提供する決済方法<br />iPhone アプリ: Apple ID に登録されたお支払い方法（App Store のアプリ内課金）</td>
            </tr>
            <tr>
              <td>支払時期</td>
              <td>Web 版: 初回はお申し込み時（無料体験がある場合は無料体験の終了時）、以後は契約期間（1か月または1年）ごとの更新日に自動で請求されます<br />iPhone アプリ: 購入の確定時に Apple ID のアカウントに請求され、以後は期間が終わる前の24時間以内に次の期間の料金が自動で請求されます</td>
            </tr>
            <tr>
              <td>サービスの提供時期</td>
              <td>決済の完了後、直ちにご利用いただけます</td>
            </tr>
            <tr>
              <td>契約期間・自動更新</td>
              <td>1か月または1年。お客様が解約しない限り、同じ期間・同じ価格で自動的に更新されます</td>
            </tr>
            <tr>
              <td>無料体験</td>
              <td>【無料体験を設ける場合: 期間○日。期間内に解約しない場合、終了日に上記の価格で有料プランが開始されます／設けない場合はこの行を削除】</td>
            </tr>
            <tr>
              <td>解約の方法</td>
              <td>Web 版: 【「設定」→「CatchWords Pro」→「プランを管理」から、またはメール（上記アドレス）で】いつでも解約できます。解約後も、支払い済みの期間の終わりまでご利用いただけます<br />iPhone アプリ: iPhone の「設定」→ ご自分の名前 →「サブスクリプション」から、期間が終わる24時間前までに自動更新をオフにしてください。アプリやアカウントを削除しても解約にはなりません</td>
            </tr>
            <tr>
              <td>返品・返金</td>
              <td>デジタルサービスの性質上、購入後のお客様のご都合による返品・返金（日割りでの返金を含みます）はお受けしておりません。ただし、当社の責めに帰すべき事由によりサービスを利用できなかった場合および法令により必要な場合は、この限りではありません<br />iPhone アプリでの購入の返金は、Apple の定める条件と手続き（<a href="https://reportaproblem.apple.com" target="_blank" rel="noopener noreferrer">https://reportaproblem.apple.com</a> ）によります</td>
            </tr>
            <tr>
              <td>申込みの撤回</td>
              <td>通信販売のため、クーリング・オフの制度はありません</td>
            </tr>
            <tr>
              <td>動作環境</td>
              <td>iPhone アプリ: iOS 18.0 以降を搭載した iPhone<br />Web 版: 最新版の Safari、Google Chrome、Microsoft Edge、Firefox（JavaScript と Cookie・ローカルストレージを有効にしてください）<br />いずれもインターネット接続が必要です</td>
            </tr>
            <tr>
              <td>特別な販売条件</td>
              <td>18歳未満の方は、保護者の同意を得てからお申し込みください</td>
            </tr>
            <tr>
              <td>表現・商品に関する注意書き</td>
              <td>本サービスの AI が作る内容は誤りを含むことがあり、学習の成果を保証するものではありません</td>
            </tr>
          </tbody>
        </table>
      </section>
    </>
  );
}

function TokushohoPage() {
  const t = useT();
  return (
    <article className="mx-auto max-w-2xl px-4 py-10">
      <Link
        to="/"
        className="inline-block py-3 -my-3 text-body text-muted-foreground hover:text-foreground"
      >
        ← {t("common.back")}
      </Link>
      <TokushohoJa />
      <p className="mt-8 flex flex-wrap gap-x-6 text-footnote text-muted-foreground">
        <Link to="/terms" className="inline-block py-3 -my-3 underline">
          {t("auth.terms")}
        </Link>
        <Link to="/privacy" className="inline-block py-3 -my-3 underline">
          {t("auth.privacy")}
        </Link>
      </p>
    </article>
  );
}
