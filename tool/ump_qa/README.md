# Actual Hitasura UMP integration QA

This separate Debug iOS simulator target calls the real UMP SDK through the
shipping `AdsPrivacyService`. It never creates an ad service, initializes Mobile
Ads, loads an ad, requests ATT, edits IAB/TCF preferences, or changes account
settings. Local tests cover the test harness only; they are not live UMP proof.

The target requires `kDebugMode`, iOS, `HITASURA_UMP_QA=true`, and the existing
native simulator-only bridge before it can reset or request consent. Release
`main.dart` does not import it. The independent XCTest UI project supports only
the simulator Debug configuration and cannot archive; the shipping iOS project
is unchanged.

## Build once on an installed supported Xcode/macOS runner

1. Build the separate target:
   `flutter build ios --simulator --debug --no-codesign -t tool/ump_qa/ump_qa_main.dart --dart-define=HITASURA_UMP_QA=true --dart-define=ADMOB_MODE=disabled`
2. Run `python3 tool/ump_qa/prepare_simulator_app.py`. It verifies the native
   simulator guard, Debug kernel target and bundle identity, then copies the
   unsigned simulator app to `build/ump_qa_app/Runner.app`. Only that copy gets
   Hitasura's real `GADApplicationIdentifier`, needed to retrieve its published
   message. Debug/Release xcconfigs and the original bundle stay unchanged.
3. Build the isolated UI runner:
   `xcodebuild build-for-testing -project tool/ump_qa/UmpQaUITests.xcodeproj -scheme UmpQaUITests -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ump_qa_ui CODE_SIGNING_ALLOWED=NO`
4. Retain the QA app plus UI runner Products and its `.xctestrun` with exact
   source SHA and hashes. Use an isolated runner for the actual test when
   practical, avoiding compile pressure on CoreSimulator.
5. Run `python3 tool/ump_qa/run_native_qa.py --xctestrun <the generated file> --source-sha <exact built commit SHA>`.
   Inventory, setup, test execution and cleanup are bounded. The test runner
   launches only the installed QA app by its known bundle identifier.

The existing iOS workflow routes an explicitly tagged `[ump-qa]` readiness
commit to these two isolated standard-runner jobs. Other media jobs are skipped
for that tag. The run job verifies the builder's exact archive digest and source
descriptor before extraction; there are no release/signing/publishing actions.

## Evidence required before calling this verified

The native tests use exact visible English buttons, retain screenshots and
accessibility trees, and fail rather than guessing coordinates if a form differs.
They reset consent in this disposable simulator, test **Consent** and **Do not
consent** separately, then reopen required privacy options and confirm choices.
`UmpQa.xcresult`, app-owned SDK event JSON, final native PNG and host command logs
are retained. Inspect the actual message/policy, both decisions, reopened form,
SDK errors and final status. A completed SDK callback without a visible form is
not sufficient proof. A refusal may still allow contextual/limited ads; neither
`canRequestAds=true` nor the generic `obtained` status proves personalization.

The published Hitasura EEA message may take time to propagate. SDK networking,
form availability and macOS/XCTest compilation have not been proven by Linux
unit tests. No per-user device identifier is collected: Google documents iOS
simulators as test devices. EEA debug geography and `reset()` stay test-only.

Sources:
- [Google Flutter UMP integration and test APIs](https://developers.google.com/admob/flutter/privacy)
- [Google iOS simulator test-device behavior](https://developers.google.com/admob/ios/privacy#testing)
- [Apple native application UI-test proxy](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/init(bundleidentifier:))

## Bounded infrastructure recovery

Run `37055844526` compiled both QA targets and verified archive transfer, but
iOS 26.2 simulator installation timed out after a 117-second boot. No app launch
or UMP request occurred. Its retained inventory explicitly lists available
iOS 18.6 and iPhone 16 Pro Max. A tagged `[ump-reuse]` diagnostic uses that
existing compatible runtime, retaining SDK 26.2 build provenance and the actual
device/runtime label. It does not replace newest-OS release QA.

`retained_build.json` pins that exact source/run/artifact and both ZIP/tar hashes.
Reuse verifies expiry, the UMP Dart/native-test sources, shipping consent service,
SDK locks and iOS configuration. Only the reviewed purchase-bridge-only native
revision is additionally permitted; the simulator attestation block must remain
identical and the QA target does not call the purchase bridge. Unknown native
revisions require a fresh build. No runtime download, signing or larger runner
is used, and repeated installation is not attempted after an uncertain timeout.
