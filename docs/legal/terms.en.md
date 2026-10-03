<!--
  オーナー向けメモ（Web 版の頁には出ない）
  - 本文は、Web 版 main（3fd364f）の src/components/legal/terms-{ja,en,zh-tw}.tsx に
    docs/web-changes/ のパッチ（0001 が前の legal.patch。規約は他のパッチでは変わらない）を当てた後の文言と同じです（TSX から機械的に書き出した）。
    公開されるのは Web 版の頁（https://catchwords.lovable.app/terms）。直すときは TSX と同じ日に、3言語とも直す。
  - 〔 〕の所は、Web 版が表示するときに設定（LEGAL_* と STRIPE_TRIAL_DAYS。src/lib/legal-config.ts）から
    差し込む値・出し分けです。本文に手で書き込まないでください。
  - 第12条（App Store の条項）は、Apple が独自の使用許諾契約に求める最低限の条項。App Store Connect では
    Apple の標準 EULA のままでよい（その場合も残して害はない）。
  - 末尾の「付録」は、iPhone アプリでアプリ内課金を始めるときに足す文案。今は公開しない。
-->

# Terms of Service

Last updated: 3 October 2026

## 1. Scope

These terms set out the conditions for using CatchWords (the iPhone app and the web version; “the Service”), provided by 〔Operator name = LEGAL_SELLER_NAME〕(“the operator”). By using the Service you are deemed to have agreed to these terms. This is a translation; if it differs from the Japanese version, the Japanese version prevails.

## 2. Accounts

You are responsible for creating your account with accurate information and for keeping your credentials secure. The Service is not available to anyone under 13 years of age. If you are under 18, get your parent's or guardian's consent before using the Service or buying the paid plan. You can delete your account and leave at any time from “Delete account” in Settings.

## 3. Your content

You retain copyright in the photos, text and other content you add. You grant the operator the right to use that content to the extent necessary to provide and improve the Service.

## 4. Prohibited conduct

- Infringing others' rights (portrait rights, copyright and so on), including photographing or adding people without their permission
- Adding obscene, violent or discriminatory content, or content sexualising children
- Misusing location data, including stalking
- Interfering with the operation of the Service, including unauthorised access and automated mass use
- Getting around usage limits, instructing the AI to behave in unintended ways, or selling, redistributing or using the Service or its AI-generated content to develop other AI services without permission
- Impersonating others
- Fraudulent use of payments
- Anything illegal or contrary to public order and morals

If you break these terms, the operator may remove your content, suspend your use of the Service or delete your account. Except in an emergency, the operator will tell you in advance where possible.

## 5. AI-generated content

The Service uses AI to create meanings, readings, example sentences, explanations, quizzes, pronunciation audio, images and similar content. AI-generated content may contain errors, and the operator does not warrant its accuracy or completeness. Use it as a study aid, and check anything important against a dictionary or a qualified person. If you find an error, you can report it with “Report an error in this entry” on that word.

Do not rely on the Service to decide whether food, plants, mushrooms, medicines and the like are safe, or for medical, health or allergy decisions.

When you use AI features, photos and text are sent to the external providers listed in the Privacy Policy. The iPhone app asks for your consent to this before you first use an AI feature. If you do not consent, AI features are unavailable, but the rest of the Service still works.

## 6. Paid plan (subscription)

1. The Service offers a paid subscription plan (“the paid plan”). The features included in the paid plan are shown on the purchase screen.
2. The price, currency and billing period (monthly or yearly) are shown on the purchase screen and the checkout page before you subscribe. Payments are processed by Stripe.
3. The paid plan renews automatically for the same period unless you cancel, and the payment method you registered is charged on each renewal date.
4. You can cancel at any time from “CatchWords Pro” → “Manage subscription” in [Settings](https://catchwords.lovable.app/settings). After you cancel you will not be charged from the next renewal date, and you can use the paid plan until the end of the period you have already paid for. Deleting your account does not cancel the paid plan automatically.
5. Except where required by law, fees already paid are not refunded (including pro-rata refunds when you cancel part-way through a period).
6. If a payment cannot be confirmed at renewal, the paid plan's features may be suspended.
7. The operator may change the price or contents of the paid plan. Before changing the price, the operator will give reasonable advance notice in the Service or by email to your registered address, and the new price applies from the first renewal after the notice. If you do not agree, you can cancel before the next renewal date.
8. 〔shown only when STRIPE_TRIAL_DAYS is 1 or more〕 A free trial of 〔STRIPE_TRIAL_DAYS (7 if not set)〕 days is included when you subscribe. If you do not cancel before the trial ends, the paid plan starts automatically when it ends and you are charged.
9. The paid plan cannot be purchased inside the iPhone or Android app. Before purchases in the iPhone app (Apple in-app purchase) start, this section and the Legal notice will be revised and announced in the Service.
10. For the full conditions of sale, see the [Legal notice (Specified Commercial Transactions Act)](https://catchwords.lovable.app/legal/tokushoho).

## 7. Intellectual property

Intellectual property in the Service — including its logo, design and the format of AI-generated cards — belongs to the operator or the rightful owners.

## 8. Changes and suspension

The operator may change or stop providing the Service. If the Service is to be discontinued while the paid plan is offered, the operator will give reasonable advance notice.

## 9. Disclaimer and limitation of liability

1. The operator does not warrant that the Service (including AI-generated content) is free of factual or legal defects.
2. The operator is not liable for damage you suffer from using the Service, except where caused by the operator's intent or gross negligence.
3. Notwithstanding the previous paragraph, if the contract between the operator and you is a consumer contract under Japan's Consumer Contract Act, the previous paragraph does not apply. In that case, for damage caused to you by the operator's negligence (other than gross negligence) through breach of contract or tort, the operator is liable only for damage that would ordinarily arise, up to the amount you paid the operator for the Service in the month in which the damage occurred.

## 10. Changes to these terms

The operator may change these terms in accordance with the Civil Code of Japan. The operator will announce the changes and the date they take effect in the Service in advance.

## 11. Governing law and jurisdiction

These terms are governed by the laws of Japan. 〔if LEGAL_JURISDICTION_COURT is set〕 Any dispute relating to the Service shall be subject to the exclusive jurisdiction of the 〔LEGAL_JURISDICTION_COURT〕 as the court of first instance. 〔if not set〕 Any dispute relating to the Service shall be brought before the court that has jurisdiction under Japan's Code of Civil Procedure. This does not take away the protection that mandatory consumer protection laws of your country of residence give you as a consumer.

## 12. The iPhone app obtained from the App Store

For the iPhone app obtained from the App Store (“the App”), the following applies in addition to the rest of these terms. If they conflict, this section prevails for the App.

1. These terms are an agreement between you and the operator, not with Apple Inc. (“Apple”). The operator, not Apple, is responsible for the App and its content.
2. The operator grants you a non-transferable right to use the App on Apple-branded products that you own or control, as permitted by the Usage Rules in the Apple Media Services Terms and Conditions.
3. The operator alone is responsible for maintenance and support of the App; Apple has no obligation to provide any.
4. If the App fails to conform to any applicable warranty, you may notify Apple, and Apple will refund the purchase price of the App (if any). To the maximum extent permitted by law, Apple has no other warranty obligation with respect to the App.
5. The operator, not Apple, is responsible for addressing any claims relating to the App (including product liability, failure to conform to legal or regulatory requirements, and claims under consumer protection, privacy or similar laws) and any claim that the App infringes a third party's intellectual property rights.
6. You represent and warrant that you are not located in a country subject to a U.S. Government embargo or designated as a “terrorist supporting” country, and that you are not listed on any U.S. Government list of prohibited or restricted parties.
7. You must comply with applicable third-party terms (such as your mobile carrier's) when using the App.
8. Apple and its subsidiaries are third-party beneficiaries of these terms, and upon your acceptance Apple has the right to enforce them against you.
9. Send questions, complaints or claims about the App to the contact in section 13.

## 13. Contact

- **Operator**: 〔LEGAL_SELLER_NAME〕
- **Representative**: 〔LEGAL_REPRESENTATIVE, shown only if set〕
- **Address**: 〔LEGAL_ADDRESS; with ON_REQUEST: “Disclosed without delay upon request (please request it at the email address below)”〕
- **Phone**: 〔LEGAL_PHONE; with ON_REQUEST: as above〕
- **Email**: 〔LEGAL_EMAIL〕

(While LEGAL_EMAIL is not set, the page shows “The operator's contact details are being prepared. …” instead of the table.)

---

## Appendix (not in force): items to add to section 6 when in-app purchases start in the iPhone app

<!-- オーナー: iOS の PlanStore.paywallEnabled を true にする前に、第6条第9項をこれに置き換え、特商法の表記と同じ日に公開する。 -->

1. The paid plan in the iPhone app is purchased with Apple in-app purchase. Payment is charged to your Apple ID account when you confirm the purchase.
2. The subscription renews automatically unless auto-renew is turned off at least 24 hours before the end of the current period, and the next period is charged within the 24 hours before the current period ends.
3. You can cancel (turn off auto-renew) at any time in the iPhone Settings app → your name → Subscriptions. Deleting the app or your account does not cancel the subscription.
4. Refunds follow Apple's conditions and procedures (https://reportaproblem.apple.com). The operator cannot refund in-app purchases directly.
5. A paid plan bought on the web and one bought in the iPhone app are each managed where they were bought.
