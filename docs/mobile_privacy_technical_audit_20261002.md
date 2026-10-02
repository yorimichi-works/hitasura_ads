# Mobile privacy implementation audit — 2026-10-02

This is a technical source/SDK audit for preparing the mobile policy and App
Privacy answers. It is not a legal opinion, a published policy, or an attestation
that the final production network behavior has been tested. Runtime source
reviewed: `f3c192cf988eed3ee8d1dffb8d479c5c8799d8fb`.

## Current behavior

- First launch asks for nickname and language. A generated local player ID,
  nickname, game progress/rewards, sound/notification preferences and premium
  entitlement are stored in device preferences. The current app has no login,
  cloud-sync backend, Firebase dependency or separate publisher analytics SDK.
  Older optional profile fields may remain in migrated local storage; the
  current first-launch screen does not collect age, gender or location.
- `AppController.create()` queries Apple/Google purchase availability and the
  non-consumable product. On iOS, purchase/restore delivery is checked against
  StoreKit2 verified current entitlements. No publisher receipt-validation
  server receives the transaction. Apple handles payment/account information;
  the app does not receive payment-card details.
- Home startup calls UMP to refresh consent information, including for premium
  users. This can communicate with Google before a sponsor ad is requested.
  Actual Mobile Ads initialization and rewarded-ad loading happen only after
  an ad request, successful UMP collection and `canRequestAds()`. Thus neither
  “no network until an ad” nor “premium users send no data” is supported.
- Ads are optional sponsor videos for ticket recovery/catalog unlocking.
  `AdRequest()` contains no app-supplied nickname, user ID, content URL,
  custom-data/SSV identifier, keyword targeting or non-personalized override.
  Source contains no third-party mediation adapters. Account-side demand and
  publisher-data settings must still be reviewed separately.
- Reminders are locally scheduled notifications. The app does not implement a
  remote push-token/server flow. Sound, language and notifications are user
  settings. No precise-location, camera, microphone or contacts permission is
  requested by this source.
- The required UMP privacy-options action is exposed in Settings when the SDK
  says it is required. Do not promise that the action appears in every region.

## ATT conclusion and material choice

The app does not request ATT and has no `NSUserTrackingUsageDescription`.
Because its minimum iOS version is 15, IDFA is unavailable without authorization.
Google explicitly supports ad requests after ATT denial, without transmitting
IDFA. Therefore an ATT prompt is **not inherently required to serve these
rewarded ads**. [Google Flutter IDFA guidance](https://developers.google.com/admob/flutter/privacy/idfa)

The current default publisher first-party ID can support personalization within
the publisher's apps. Google says it cannot link that activity to third-party
apps. First-party personalization is not automatically Apple's cross-company
tracking. The account can also control first-party-ID sharing and optional
features; those settings are not proven by source alone.
[Google first-party identifiers](https://support.google.com/admob/answer/14199649)

Apple requires ATT for actual cross-company tracking or IDFA access, including
tracking performed by an embedded SDK. Merely omitting the prompt cannot make
such tracking permissible. UMP consent is not a substitute for ATT.
[Apple privacy and data use](https://developer.apple.com/app-store/user-privacy-and-data-use/)

Recommended source-preserving path: retain the existing no-IDFA behavior and
optional sponsor monetization, configure Hitasura's applicable UMP messages,
and verify account settings and device behavior. Do not silently force NPA,
disable first-party IDs, remove ads or change rewards. If the owner chooses
IDFA/cross-company personalized targeting, add UMP's IDFA/ATT flow, an accurate
usage description and framework configuration before ad loading, with matching
policy/App Privacy answers; denial must still permit normal gameplay and
eligible ads. That is a material data-use/product choice.

## SDK data disclosure evidence

Flutter dependency `google_mobile_ads` is locked at 9.1.0. Its iOS Swift package
requires Google Mobile Ads from 13.7.0; the final resolved native version must be
recorded from the release archive, rather than assumed to equal that minimum.

The official Google Mobile Ads 13.7.0 distribution was inspected read-only and
its SHA-256 matched its Swift package checksum:
`e89ba382a6244f5c8d92941015b12d98678689ebe14960eaa4c1d5951784a9c2`.
Both device/simulator manifests declare:

- Device ID: linked, tracking-capable
- Coarse location, advertising data, product interaction: linked, nontracking
- Crash, performance and other diagnostic data: unlinked, nontracking
- Purposes include advertising and analytics; crash data lists analytics

This generic SDK declaration is evidence of SDK capabilities/data categories,
not proof that IDFA is transmitted in this app's unapproved-ATT state. Do not
change the vendor manifest to hide it. Review the actual archive's combined
privacy report and selected data-use mode before App Privacy submission.
[Official package and checksum](https://github.com/googleads/swift-package-manager-google-mobile-ads/blob/13.7.0/Package.swift)

Google's disclosure guidance describes potential collection of IP address
(including approximate location), device/app identifiers, ads viewed, product
interactions and diagnostic/performance information. The mobile policy should
name Google AdMob/UMP and explain this separately from the locally stored game
profile. Avoid “no data collected,” “all information stays on device,” “all ads
are non-personalized,” or “no tracking guaranteed.”
[Google iOS disclosure guidance](https://developers.google.com/admob/ios/privacy/data-disclosure)

## Account and release prerequisites

The registration operator confirmed Hitasura's iOS AdMob app ID
`ca-app-pub-3186852093801241~9948289508` and reward units ending `4511295842` and
`6036789642`. At audit time, published GDPR/US messages were for Cirno, not
Hitasura. Configure messages for Hitasura only after its approved mobile policy
URL is live. Do not substitute another app's consent message.

Importantly, UMP has returned `canRequestAds=true` when no privacy messages are
configured since version 2.5.0. This code's fail-closed error handling cannot
identify that account-side omission. Published applicable messages and device
checks are mandatory release prerequisites, even if the SDK reports success.
[UMP release notes](https://developers.google.com/admob/ios/privacy/download)

Before uploading a production build, establish the final mobile-policy/support
URLs, applicable EEA/UK/Swiss and regulated-US flows, consent changes and error
paths, selected ATT/no-IDFA mode, intended audience/age treatment, actual native
SDK versions/privacy report, and Sandbox purchase/restore behavior. The current
source does not enforce an age gate or explicitly tag child/under-consent-age
ad requests; do not invent a children-policy promise.

`SKAdNetworkItems` is currently absent. Google's recommended SKAdNetwork setup
can support privacy-preserving attribution without IDFA; consider this separately
from ATT rather than treating it as cross-app identity tracking.
[Google iOS privacy strategies](https://developers.google.com/admob/ios/privacy/strategies)

The source/design is unchanged by this audit. Upload-only Codemagic publishing
is prepared locally with integration authentication, both submission flags
false and manual release; it remains unpushed until the release operator
provides the live URLs and approves the next source update.
