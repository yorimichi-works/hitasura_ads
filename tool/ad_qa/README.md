# Isolated rewarded SDK smoke (Google demo ads only)

This opt-in Debug iOS simulator target exercises the unchanged
`GoogleRewardedAdService`, real UMP consent gate and real Google Mobile Ads SDK.
It is separate from the existing **no-ad** UMP QA target. It does not grant game
tickets, change purchase ownership, request ATT or use a publisher's ad unit.
Shipping source/configuration and App Store archives are not modified.

Google's official iOS rewarded demo unit is
`ca-app-pub-3940256099942544/1712485313`. The official documentation says its demo
units serve test creatives and iOS simulators are automatically test devices:
https://developers.google.com/admob/ios/test-ads
https://developers.google.com/admob/flutter/rewarded

## Hard requirements and limits

- Require Debug, iOS, the explicit `HITASURA_REWARDED_AD_QA=true` define,
  `ADMOB_MODE=test`, and native simulator attestation **before** consent or ads.
- Construct the real shipping service with `AdNetworkMode.test`; assert
  `usesTestAds` before loading and showing. A synthetic method-channel unit guard checks that the shipping service sends
  Google's exact demo unit to the SDK. No device registration or
  AdMob/account permission change is necessary.
- Use the real shipping privacy service with the same EEA test gateway used by
  UMP QA. Only a separate simulator bundle copy receives Hitasura's existing
  consent AppID, needed for its published form. Debug/Release xcconfigs, the
  original bundle and production ad units remain unchanged.
- XCTest chooses the already observed exact **Consent** button, then loads and
  presents one Google demo ad. Before any interaction with the ad, the driver
  requires a visible, hittable, exact SDK **Test mode** label and retains its
  screenshot/accessibility tree. The Flutter QA page never supplies that label.
- Watch the demo and use only a visible exact **Close / Close ad / Close Ad**
  button. Never tap the creative, Install, Learn More, links, arbitrary positions
  or unrecognized controls. A differing UI fails with evidence for inspection.
- Actual load, reward and dismissal callbacks are captured through the unchanged
  service's debug messages. `sdk_show_requested` means a call was requested;
  it is **not** an `onAdShowedFullScreenContent` callback. Actual presentation is
  established by native Test mode UI and retained pixels, which require review.
- No mocked SDK/consent implementation runs in the native target. Dart unit tests
  and Python verifier fixtures are explicitly synthetic checks, not native proof.

The run is bounded to one ad. A failed or incomplete SDK result is never converted
to success. The driver preserves `.xcresult`, screenshots, accessibility trees,
actual SDK JSON events and host logs, then terminates the disposable QA app.
The opt-in `[ad-qa]` readiness-branch workflow builds this target and runs one
bounded proof on separate standard macOS runners. Each run pins the exact source,
prepared app, UI driver and same-run artifact digest. Never run on a physical
device or a live ad unit. No larger/paid runner or runtime download is needed.

## Build and run on the existing standard macOS runner

These steps are prepared instructions, not an assertion that native ad QA ran.

1. Select the already installed Xcode/runtime, install locked Flutter dependencies,
   and build only the isolated entrypoint:

   ```sh
   flutter build ios --simulator --debug --no-codesign \
     -t tool/ad_qa/rewarded_ad_qa_main.dart \
     --dart-define=HITASURA_REWARDED_AD_QA=true --dart-define=ADMOB_MODE=test
   python3 tool/ad_qa/prepare_simulator_app.py --source-sha "$(git rev-parse HEAD)"
   xcodebuild build-for-testing \
     -project tool/ad_qa/RewardedQaUITests.xcodeproj -scheme RewardedQaUITests \
     -configuration Debug -sdk iphonesimulator \
     -destination 'generic/platform=iOS Simulator' \
     -derivedDataPath build/rewarded_qa_ui CODE_SIGNING_ALLOWED=NO
   ```

2. Retain the QA app, provenance, native UI-runner Products and generated
   `.xctestrun` with exact source SHA and transfer hashes. Use a separate standard
   run job when practical to avoid compile pressure on CoreSimulator.
3. On an actual available iPhone simulator with the previously verified iOS18.6
   runtime, run:

   ```sh
   python3 tool/ad_qa/run_native_qa.py \
     --source-sha <exact-built-commit> --xctestrun <generated-xctestrun> \
     --runtime-version 18.6
   ```

4. Review `build/rewarded_qa_evidence/RewardedQa.xcresult`, exported native images,
   the visible SDK Test mode indicator, and ordered real SDK callbacks. A successful
   driver marks image review pending; do not claim rewarded QA passed from local
   unit tests, a load-only result, or requested presentation alone.

## Local guard checks

```sh
python3 -m unittest discover -s tool/ad_qa -p 'test_*.py' -v
flutter test --no-pub tool/ad_qa/ad_qa_guard_test.dart
flutter analyze --no-pub
```
