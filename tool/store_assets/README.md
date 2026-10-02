# Localized store media preparation

These tools do not change production app UI or upload anything to App Store Connect.

## Artifact classes

- `build/store_assets/original_pv`: exact original public Git LFS bytes from commit `c494502d9342de9320b93f9057c3584c21b45953`. `original_video_manifest.json` includes full probes and SHA-256 verification. Twenty files, 784,852,354 bytes total.
- `build/store_assets/video_encoding_candidates`: re-encoded existing promotional videos. Technical encoding candidates only. Original files are 886×1920, 29.6 seconds, 30 fps, H.264 High Level **4.2**, stereo AAC 48 kHz. Copies target High Level **4.0**, 11 Mbps / max 12 Mbps, AAC 256 kbps. Capture provenance remains **unverified**; do not upload on technical checks alone.
- `build/store_assets/flutter_previews/<locale>/<device>`: unchanged production widgets, rendered by `flutter_test` with seeded local progress and locale-specific text. **Not native iOS screenshots**. iPhone content is 1290×2796 (430×932 at 3×); iPad content is 2048×2732 (1024×1366 at 2×). Linux Noto fallback fonts are explicitly loaded. No device status bar or native safe-area evidence is implied.
- `build/store_assets/native_ios`: actual simulator screenshots and optional video from the separate debug-only capture target. Raw PNGs may contain alpha. Native videos are silent raw sources; further encoding/pixel review is required. Do not label these ready until the macOS run and visual review succeed.

## Native capture (macOS only)

The isolated reuse run `37045784008` produced a pixel-reviewed English iPhone
home frame at 1320×2868, with native request/controller/first-frame evidence.
The current validation workflow compiles the updated capture harness once, then
downloads the exact artifact into separate Japanese/Arabic phone and iPad jobs.
Each job uses one fresh app process per locale, five native UI scenes, and two
10-second G003/G008 source clips driven through the real Flutter pointer path.
The per-job work deadline is eight minutes, followed by one shared 90-second
cleanup reserve inside the ten-minute capture cap; every completed scene is
checkpointed with explicit remaining keys. At most two standard macos-15 jobs
run in parallel. The full 20-locale batch waits for this native validation.

See [NATIVE_CAPTURE_PROTOCOL.md](NATIVE_CAPTURE_PROTOCOL.md) for exact v1/v2
requests and state evidence. No Apple credentials, signing, App Store uploads,
release archive, or production game/UI changes occur. Native video sources are
silent; the preview encoder documents any use of the existing cute.mp3 music
bed as postproduction audio. The old single-scene `preview` runner recording
mode is legacy/unreviewed and is not used for the new G003/G008 previews.

```sh
flutter build ios --simulator --debug --no-codesign \
  -t tool/store_assets/native_capture_main.dart --dart-define=ADMOB_MODE=disabled
python3 tool/store_assets/capture_ios_simulator.py \
  --locales ja,ar --devices iphone_6_9 --session-loop --videos \
  --natural-status-bar --work-deadline-seconds 480
# Run the iPad chunk separately with --devices ipad_13.
```

The optional settings scene can be requested explicitly for truthful IAP review
evidence; it never fabricates prices or transactions. Initial media validation
omits it so it cannot consume time needed by the required screenshots/previews.

The capture manifest contains device/runtime, original dimensions, actual app locale/scene evidence, and hashes. `bundled_privacy_and_packages.json` exports the built app's vendor privacy manifest contents and resolved native package metadata without modifying them.

The fixture has 40 discovered games, 1234 coins, 900 XP, 5 tickets, and the ordinary UI. Notifications/audio/external rewarded ads are disabled for isolated capture. The local PLAYER/progress fixture is synthetic and disclosed; no paid entitlement, purchase price, transaction, or game result is fabricated. Existing Japanese marketing screenshots remain untouched. Approved Japanese/English title copy is rendered from the app locale tables; other locale names and UI artwork remain unchanged.

## Localized Flutter-content previews (Linux)

```sh
CI=true flutter --suppress-analytics test tool/store_assets/localized_ui_snap_test.dart \
  --no-pub --dart-define=CAPTURE_LOCALES=ja
CI=true python3 tool/store_assets/render_localized_previews.py --flutter /path/to/flutter
```

Use `CI=true` and disabled analytics in a cloud environment: upstream Flutter's bot detector otherwise probes cloud instance metadata. Do not access the metadata endpoint. Each locale runs in a fresh test process so the app's global thumbnail cache does not reuse another locale's thumbnails. The script records per-locale success/failure; failed previews must not be presented as verified.

## Policy and review limits

Apple permits app-preview captions/overlays, but requires actual app screen captures (review guideline 2.3.4). Original videos visually contain gameplay, promotional headings, montage and an end card; the repository does not preserve their source/capture script. Re-encoding cannot prove origin. The original English/Japanese frames are visibly localized, but linguistic/editorial sign-off across all 20 is not claimed.

All 20 in-app locales have 151 localized game entries. Eighteen non-English/Japanese UI tables initially lacked 21 later purchase/privacy/notification/license keys. The scoped 378-string additions in `localization_additions.draft.json` have now been reviewed for source semantics and applied to those 18 tables; native layout/locale QA remains pending. Existing app titles, prices and earlier translations are unchanged. Portuguese follows the existing Brazilian-style app wording (pt-BR metadata).

The current Apple list includes Bangla and Urdu but does not include Persian, so 20 app languages do not correspond to 20 separate supported App Store metadata locales. Regional choices for English/Spanish/French/Portuguese still need matching to the intended storefront.

References checked 2026-10-02:
- https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- https://developer.apple.com/app-store/review/guidelines/#accurate-metadata
- https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations

## Native startup recovery

The first macOS smoke build succeeded, but its initial capture could not find the late-written readiness file. It produced no valid screenshot or video. The recovery harness now writes startup stages before the simulator guard and controller initialization; controller creation still executes normal purchase initialization. It does not bypass or conceal StoreKit startup behavior.

The host obtains the real app data container from simctl, atomically writes a strict request with a unique launch ID to Documents/HitasuraCapture/request.json, and polls for a matching ready state for at most 90 seconds. The debug-only Dart target obtains the actual Documents path through a native channel compiled only for DEBUG simulator builds; it does not read capture environment variables. Startup errors are sticky. Captures retain the app console, state/event history, and failure screenshot/log/crash diagnostics. A timeout identifies the last observed stage without assuming the cause. The English one-home proof passed; current expansion validates Japanese/Arabic phone and iPad sessions before all 20 locales.

## Test-renderer glyph correction

Every production fallback font family must be explicitly loaded in Flutter tests. A missing family can resolve to the Ahem test font, turning supported accented Latin letters into squares. The renderer now loads all actual listed Noto fallback families once per process, including Noto Sans JP, and asserts coverage of the configured family list. The seven affected Latin-accent locales were regenerated and reviewed. This changes only the test harness, not production app styling.

The second smoke run reached its 20-minute limit before any locale output. Its artifact cannot identify which unlogged setup command stalled. The host now resolves the actual selected Xcode simulator SDK and requires an available matching iOS major/minor runtime before considering device names. It refuses to silently choose a newer, incompatible runtime.

Every host command persists an intent/result event and independent stdout/stderr files. Boot/bootstatus are bounded at 120 seconds, install at 60, launch/container/screenshot at 30, termination at 10, and shutdown at 30. Failure diagnostics have 10-second bounds each, including failures before an app container exists. Launch uses nonblocking `--stdout`/`--stderr`, records its PID, and detects an exited app during readiness polling; `--console` is intentionally avoided because it lasts for the app's lifetime. Native recording is limited to 20 seconds plus a bounded finalization/kill wait. No production startup code was bypassed.

## File-based capture transport proof

Run866c8d4 reached Dart startup, but all Platform.environment capture values were null. It failed at the harness's pre-runApp configuration guard, before production controller/StoreKit initialization. The replacement protocol reads a fixed app-owned request file after the `hitasura_ads/simulator_capture` / `documentsDirectory` channel attests a native debug simulator. Both the Dart debug/iOS guard and Swift `DEBUG && targetEnvironment(simulator)` guard remain required; release and real-device builds expose no capture channel. Request schema, UUID, locale, scene, UTC freshness, fixed paths, atomic writes and one-scene selection have focused tests. The one-home proof subsequently passed with app17321d1 and script2180a893; the v2 multi-scene validation now runs in isolated jobs.

### Isolated reuse proof

A readiness-branch push whose message includes `[capture-reuse]` selects bounded
capture jobs instead of the iOS compile job. The first reuse proof pinned artifact
`11243670913` from run `37042725105` (app source `17321d1`). Reuse requires the
reviewed ZIP digest and unexpired status, validates embedded simulator-only
provenance, and rejects changes to any compiled source. Each job grants only
`contents: read` and `actions: read` to its existing ephemeral GitHub token; it
creates no credential and performs no signing or App Store operation.

That original proof succeeded with an actual English iPhone home image. The
current retained-artifact descriptor pins the newer `dc10fbe` harness from run
`37051269307`, artifact `11247365869`. Its Japanese/Arabic phone chunk produced
ten native screenshots and four raw gameplay segments; pixel/encoding review is
separate from capture success. The first iPad chunk stopped before boot when a
cold CoreSimulator inventory read timed out. Read-only inventory timeouts now
allow at most three 30-second attempts, separated by bounded five-second waits;
explicit errors and malformed responses are not retried.

A `[capture-reuse]` push first captures genuine English iPad home/Settings using
the retained binary, including its actual purchase availability and price text.
It then runs the Japanese/Arabic iPad media recovery. No purchase, entitlement or
price is synthesized, and no new app compilation is requested by these jobs.
The Settings image still requires pixel review of the visible upgrade/restore
section before use as an IAP review attachment.

Natural system status bars are retained. Manifests distinguish app and capture
script revisions. Each capture chunk has an eight-minute work deadline, one
90-second cleanup reserve and a ten-minute step cap. After the pinned artifact
expires on 2026-10-09, a fresh compile is required. Ordinary unmarked pushes retain
the existing build workflow; Android checks are unchanged.
