# Localized store media preparation

These tools do not change production app UI or upload anything to App Store Connect.

## Artifact classes

- `build/store_assets/original_pv`: exact original public Git LFS bytes from commit `c494502d9342de9320b93f9057c3584c21b45953`. `original_video_manifest.json` includes full probes and SHA-256 verification. Twenty files, 784,852,354 bytes total.
- `build/store_assets/video_encoding_candidates`: re-encoded existing promotional videos. Technical encoding candidates only. Original files are 886×1920, 29.6 seconds, 30 fps, H.264 High Level **4.2**, stereo AAC 48 kHz. Copies target High Level **4.0**, 11 Mbps / max 12 Mbps, AAC 256 kbps. Capture provenance remains **unverified**; do not upload on technical checks alone.
- `build/store_assets/flutter_previews/<locale>/<device>`: unchanged production widgets, rendered by `flutter_test` with seeded local progress and locale-specific text. **Not native iOS screenshots**. iPhone content is 1290×2796 (430×932 at 3×); iPad content is 2048×2732 (1024×1366 at 2×). Linux Noto fallback fonts are explicitly loaded. No device status bar or native safe-area evidence is implied.
- `build/store_assets/native_ios`: actual simulator screenshots and optional video from the separate debug-only capture target. Raw PNGs may contain alpha. Native videos are silent raw sources; further encoding/pixel review is required. Do not label these ready until the macOS run and visual review succeed.

## Native capture (macOS only)

The existing `ios-check.yml` readiness-branch job builds the normal simulator app first, uploads it, then builds the separate capture target. It captures English, Japanese, and Arabic on an eligible high-resolution iPhone and iPad, including 20-second continuous native runner source videos. The harness records requested and applied locale/scene in its sandbox; the host verifies these values. No Apple credentials, signing, uploads, release archive, or store metadata mutations occur. The capture target refuses release/device execution.

```sh
flutter build ios --simulator --debug --no-codesign \
  -t tool/store_assets/native_capture_main.dart --dart-define=ADMOB_MODE=disabled
python3 tool/store_assets/capture_ios_simulator.py --locales en,ja,ar --videos
# After smoke review, request all 20 with --locales en,ja,zh,zh_TW,ko,es,fr,de,pt,ru,it,hi,bn,ar,ur,fa,id,tr,vi,th
```

The capture manifest contains device/runtime, original dimensions, actual app locale/scene evidence, and hashes. `bundled_privacy_and_packages.json` exports the built app's vendor privacy manifest contents and resolved native package metadata without modifying them.

The fixture has 40 discovered games, 1234 coins, 900 XP, 5 tickets, and the ordinary UI. Notifications/audio/external rewarded ads are disabled for isolated capture. No fake paid entitlement, user data, or game result is inserted. Existing Japanese marketing screenshots remain untouched. New proposed store title is not baked into app captures.

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

The host obtains the real app data container from simctl, passes an explicit app-owned Documents state path and unique launch ID, and polls for a matching ready state for at most 90 seconds. Startup errors are sticky. Captures retain the app console, state/event history, and failure screenshot/log/crash diagnostics. A timeout identifies the last observed stage without assuming the cause. The workflow remains the English/Japanese/Arabic smoke until real pixel review passes.

## Test-renderer glyph correction

Every production fallback font family must be explicitly loaded in Flutter tests. A missing family can resolve to the Ahem test font, turning supported accented Latin letters into squares. The renderer now loads all actual listed Noto fallback families once per process, including Noto Sans JP, and asserts coverage of the configured family list. The seven affected Latin-accent locales were regenerated and reviewed. This changes only the test harness, not production app styling.
