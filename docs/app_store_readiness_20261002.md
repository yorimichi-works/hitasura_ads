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
  submission flags disabled. Manual public release is controlled separately in
  App Store Connect; the upload-only YAML omits `release_type`. No Git trigger, beta
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
- iOS premium access is reconciled at startup, app resume, matching purchase
  updates and explicit Restore. Only StoreKit2 **verified** current ownership
  grants access; a matching signed refund can revoke it. Unknown/offline results
  preserve the last cache. A successful user-triggered `AppStore.sync()` is
  required before absence can clear an account's cached access. Durable local
  save precedes transaction completion. No server receipt validation is claimed.
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

The versioned entitlement cache now also records transaction/original identity
and signed date. Older evidence cannot undo a newer decision for the same
purchase; valid replacement ownership wins over old refunds. Legacy access is
preserved during ambiguous/offline reads and migrated when verified ownership
arrives. Immediate offline account-switch detection is not promised. Android
verification is unchanged. See [evidence rules and the signed Sandbox checklist](premium_entitlement.md).

## Remaining release checks and decisions

1. **Mobile privacy policy and support page.** The approved mobile pages are
   `https://yorimichi-works.jp/apps/hitasura-ads/privacy` and
   `https://yorimichi-works.jp/apps/hitasura-ads/support`, with English links.
   They were separately published and anonymously checked on 2026-10-02. The old
   browser/Firebase/AdSense policy must not replace these mobile pages. This
   branch does not deploy or alter the website.
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
5. **Signing/build.** Version 1.0.0(1), source `50e039b6e66630873b85e91259ba81b0bd0ece39`,
   was separately signed, exported and uploaded on 2026-10-02. Later source
   changes require a new build number and archive. Apple processing/export
   compliance, owner TestFlight QA and App Review remain separate checks.
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

### Existing icon, ad-content filter, and bounded capture follow-up

- The native iOS template icon was replaced using the existing TV/AD web brand
  artwork from commit `2c18926afebf0edf02aac454d48b25a248506ffc`. All 15 PNG
  exports are opaque RGB and match the existing 19 catalog entries. The 1024px
  marketing export is a 2x resample of the available 512px original, not a new
  higher-resolution master. Provenance and pixel-review limitations are in
  `tool/store_assets/ios_icon_export_manifest.json`; no game artwork changed.
- After successful UMP consent, the app awaits an AdMob maximum content rating
  of `T` before SDK initialization, and rechecks consent before proceeding. This
  filters MA creatives but does not guarantee every ad is appropriate. No child,
  under-consent, or age-treatment assertion is set; account-wide AdMob settings
  are unchanged. Configuration failure prevents initialization and requests.
- Native run `37032299479` compiled both targets with Xcode 26.3 and passed tests,
  but the simulator container lookup timed out before app launch. The next retry
  repeats only that timed-out read, at most three 30-second attempts with two
  5-second gaps. Explicit errors stop immediately. CPU/memory diagnostics each
  have a 5-second bound and do not collect environment variables or arguments.
- The capture harness is now retained as a permission-preserving tar archive with
  source/mode metadata for seven days. It remains an ads-disabled simulator-only
  diagnostic target, not an App Store archive. No workflow token permission,
  signing resource, automatic upload/review/release behavior was added.

Google configuration ordering/content-filter guidance:
https://developers.google.com/admob/flutter/targeting

### Capture transport proof

Run `37036555775` resolved the app container on its second bounded attempt and
launched the capture app. Dart stdout then showed all requested environment
fields absent, so the debug harness rejected its missing configuration before
`runApp`. No production startup or StoreKit defect was established. The capture
harness now reads a strict host-written JSON request from its own Documents
directory, located through a `DEBUG && targetEnvironment(simulator)` native
channel. Release/device builds contain no such channel, and no environment
values or new dependencies are exposed. The next capture is deliberately one
English iPhone home screen with a 10-minute step cap; broader capture awaits
actual pixel and state evidence from that proof.

The first file-transport proof (`37039897176`) exposed a native build-condition
issue: the Runner Debug target did not define Swift `DEBUG` (only RunnerTests
did), so the simulator-only channel was absent from the actual native dylib.
The next patch sets `$(inherited) DEBUG` on Runner Debug only, leaves Release and
Profile unchanged, and verifies the channel marker in native Mach-O images
before boot. The guard rejects the actual failed artifact and cannot be fooled
by the same channel name in a Dart kernel asset. Runtime proof remains pending.

The `17321d1` run passed native bridge verification, then stopped on a cosmetic
status-bar command timeout before app installation. The next isolated probe
reuses that exact verified harness with a pinned artifact digest, expiry check,
embedded provenance and compiled-source equality check. Only its job gains
read-only Actions access on the existing ephemeral GitHub token. No build or
signing occurs in that probe; ordinary iOS builds and Android checks remain
available. Natural status-bar pixels are retained and source revisions remain
explicit. Host snapshots show heavy Apple background activity and memory
compression, but do not establish an out-of-memory event or prove that the prior
compile caused the simulator latency.

### Native media expansion

The isolated exact-artifact proof `37045784008` succeeded: real English iPhone
1320x2868 pixels, native simulator attestation, controller readiness and a real
first frame were verified. The v2 target now uses one process per locale to
avoid cross-language thumbnail-cache reuse, and real pointer inputs for ten
seconds each of G003/G008. The next validation builds that target once and runs
Japanese/Arabic phone and iPad chunks in separate standard macOS jobs. Raw clips
require native evidence, encoder validation and pixel review; postproduction
music is explicitly distinguished from native captured audio. No shipping game
logic/art changed. Full20-locale capture and actual UMP accept/refuse/options QA
remain separate gates; neither mock tests nor this media harness prove UMP.
