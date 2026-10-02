# iOS App Store readiness — 2026-10-02

Scope: latest `codex/ios-purchase-build` commit
`c494502d9342de9320b93f9057c3584c21b45953`, prepared separately on
`codex/app-store-readiness-20261002`. Main and the source branch are unchanged.
This document is an engineering checklist, not a submitted privacy declaration
or a statement that App Review has approved the app.

## Prepared in code

- Latest owner-approved Japanese App Store title (2026-10-02):
  `ひたすら広告　151のドパガキ向けミニゲーム集`. This supersedes earlier store-title proposals.
  The Japanese in-app title uses the same approved wording. The short installed
  name `Hitasura Ads`, other locale names, game art and layouts remain unchanged. This title does not establish a Kids-category
  audience or replace truthful age-rating/content answers.
- Latest owner-approved English App Store and in-app title (2026-10-02):
  `Nothing But Ads: 151 Games`, selected after the shorter App Store name was
  unavailable. Other locale names, game art and layouts remain unchanged.
- Production iOS bundle `com.syamo.hitasuraads`, team `3W8HVJ3U8W`, marketing
  version `1.0.0`. The source build number remains `1`; each uploaded build must
  have a new number checked against App Store Connect app `6818519730`.
- Manual signed-IPA workflow using `xcode: latest`, existing integration
  `codemagic`, existing certificate `cirno-app-store`, and approved profile
  `hitasura-app-store-profile`. After a separately authorized manual start, the
  workflow builds and uploads the IPA to App Store Connect with both review
  submission flags disabled and `release_type: MANUAL`. No Git trigger, beta
  group, cancellation, expiry action, or signing-resource creation is configured.
  This local code change starts no paid build and performs no upload or review
  submission. See [release workflow instructions](../tool/release/README.md).
- UMP consent-info refresh per app/service session, required privacy-options
  entry in Settings, and a consent form only when an ad is actually requested.
  No Mobile Ads initialization or ad load happens until UMP completes and
  `canRequestAds()` returns true. Update/form/status failures block ads. Cached
  ads are discarded before privacy choices change; every new load and show
  rechecks permission. Ads are loaded on demand rather than for premium users
  at Home startup. Unavailable ads do not grant a reward or prevent ordinary
  ticket recovery/free replay.
- Settings now provides privacy-policy/support links from explicit HTTPS
  `PRIVACY_POLICY_URL` and `SUPPORT_URL` Dart defines. The signed workflow rejects
  missing, local or placeholder URLs. The unsigned simulator workflow remains
  usable without those production values. The release operator must also open
  the actual pages and confirm their contents; URL syntax alone is insufficient.
- The non-consumable product remains exactly `ad_free_unlimited`. The latest
  owner-approved Japan price is JPY 300 one-time (2026-10-02), superseding the
  earlier JPY 200 planning note; overseas prices use Apple's Japan-base automatic
  equivalents. The app download is free. Buy and Restore remain available, and
  runtime price display comes from StoreKit; no currency/price is hardcoded.
- New iOS purchase/restore events must match a current StoreKit2 **verified**
  entitlement with the exact transaction and product, no revocation, and no
  expiration/upgraded state. Durable local save must succeed before completing
  the transaction. Failed verification or storage leaves an error and does not
  complete delivery. No server receipt validation is claimed.
- Credits now distinguish fictional in-game parodies from real optional sponsor
  videos. Gameplay/art was not redesigned by this readiness change.

- The complete bundled Kosugi Maru Apache 2.0 license and copyright/designer
  attribution are packaged as assets and accessible under Settings → Credits →
  Licenses, alongside standard Flutter/plugin acknowledgements. Font/game art
  is unchanged.

## Why the extra StoreKit check exists

The locked `in_app_purchase_storekit` version is `0.4.13`. It uses StoreKit2 by
default; restored/current-entitlement and transaction-update paths filter
unverified transactions. However, its immediate `product.purchase` success path
forwards `verification.unsafePayloadValue` as `PurchaseStatus.purchased` for both
verified and unverified results. Therefore `PurchaseStatus.purchased` alone is
insufficient for this exact dependency version. The added native method checks
StoreKit's `Transaction.currentEntitlements` and `.verified` result directly;
it never accepts a locally decoded unsigned receipt as proof.

This correction covers new delivery events. Android verification is unchanged.
The existing cached premium entitlement is not periodically reconciled after a
later refund/account change; exercise that lifecycle and decide the intended
reconciliation/offline policy before commercial release. A separate backend is
not inherently mandatory for an iOS non-consumable if StoreKit verification is
correctly used.

## Remaining release checks and decisions

1. **Mobile privacy policy and support page.** Source-backed web pages exist at
   `https://hitasura.yorimichi-works.jp/privacy.html` and `/contact.html`, but the
   historical policy describes the old browser/Firebase/AdSense product. It must
   not be reused unchanged as the mobile AdMob/IAP policy. Confirm approved
   mobile wording, publisher/contact information, and an authorized hosting
   destination. This branch does not publish a policy or alter main/Vercel.
2. **AdMob account configuration.** Configure and publish applicable UMP privacy
   messages for the exact iOS AdMob application ID. Verify consent required/not
   required, refusal, update/form failure, retry, and later privacy changes on
   actual devices. UMP code does not establish the account-side setup.
3. **Tracking decision.** ATT is conditional on whether the app/SDK configuration
   actually performs tracking under Apple's definition. No ATT prompt or
   tracking-purpose description was invented. Inspect production SDK data
   flows, account settings and the planned audience, then align any required
   ATT flow, App Privacy disclosures and the policy. AdMob and UMP are not by
   themselves proof that every request requires ATT.
4. **StoreKit Sandbox.** Test purchase, cancellation, pending/Ask to Buy,
   verification failure, restored purchase after reinstall, persistence failure
   and retry, and revoked/refunded entitlement on iPhone/iPad. Confirm the
   store-side product metadata and price separately. Native compilation and
   real transactions cannot be established by Linux unit tests.
5. **Signing/build.** An account operator confirmed the approved profile was
   fetched into Codemagic on 2026-10-02 with the matching existing certificate
   (profile expires 2027-09-28). Actual distribution signing, IPA export,
   upload and Apple processing still require a separately started macOS build.
6. **Screenshots.** Existing Japanese iPhone screenshots are 1290×2796. The app
   still supports iPad, so accurate iPad screenshots must be captured on an iPad
   simulator/device; do not stretch or crop iPhone shots to impersonate iPad.
7. **Content review.** Existing game g081 and screenshot04 include recognizable
   platform-game visual motifs and a title/tagline referring to that genre.
   The owner should review rights and App Review suitability. This is a review
   flag, not a legal conclusion; screenshot04 was excluded by the registration
   operator. No rights attestation or content redesign is made by this branch.
8. **Metadata.** Final age rating, content rights, privacy disclosures, export
   compliance, availability, policy URLs and review notes require truthful
   owner-approved inputs. Do not infer those answers from this checklist.

## References

- [Google UMP Flutter integration](https://developers.google.com/admob/flutter/privacy)
- [Apple current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)
- [Apple verification result](https://developer.apple.com/documentation/storekit/verificationresult)
- [Apple user privacy and data use](https://developer.apple.com/app-store/user-privacy-and-data-use/)
- [Codemagic named signing identities](https://docs.codemagic.io/yaml-code-signing/signing-ios/)
- [Codemagic App Store Connect upload and submission controls](https://docs.codemagic.io/yaml-publishing/app-store-connect/)

### Native capture retry evidence (2026-10-02)

- Commit `6f3d751` passed analyzer, tests, ordinary simulator compilation,
  capture-target compilation and Android CI. Native capture run `37026549389`
  timed out before its first app launch/capture; the uploaded evidence contains
  zero images. Do not treat a successful compile as runtime or screenshot QA.
- The runner selected its default Xcode 16.4 while the device selector preferred
  an iOS 26 iPhone. The next bounded retry selects Xcode 26.3, the latest stable
  installation listed for that macOS 15 runner image, and matches the simulator
  runtime to its SDK. Setup commands now need individual timeouts and durable
  stage logs so simulator setup cannot consume the whole capture budget silently.
- Runner tool inventory: https://github.com/actions/runner-images/blob/macos-15-arm64/20260907.0337/images/macos/macos-15-arm64-Readme.md

### Native language declaration

The iOS bundle now declares the same 20 languages actually provided by the Dart
UI tables via `CFBundleLocalizations` (Chinese variants use `zh-Hans` and
`zh-Hant`). No empty UIKit translations or new SDK features are introduced. A
source-level test keeps the native list aligned with the Flutter language list;
the processed App Store build's Languages field still needs readback. In-app
language selection does not promise to override StoreKit/UMP system UI language.

- Apple guidance for manually localized resources and the App Store Languages field:
  https://developer.apple.com/library/archive/qa/qa1828/_index.html
- Flutter iOS bundle localization guidance:
  https://docs.flutter.dev/ui/internationalization#localizing-for-ios-updating-the-ios-app-bundle
