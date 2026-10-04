# Home purchase entry (2026-10-04)

## Scope

Prepared as a separate next-version change from `5969bac`. This does not replace the submitted App Store Build 4, change its review state, modify AdMob configuration, or change the seven score-based games.

- Add the home-bottom “広告（本物）をなくす” entry (localized in all 20 UI languages).
- Open a focused upgrade page before any purchase action. Explain the existing one-time upgrade, unlimited tickets and sponsor-free unlocking; clarify that the ad-parody mini-games stay playable.
- Share purchase, restore and owned-state controls with Settings. Show the owned state at the home entry; prevent repeated taps from stacking purchase pages.
- Use a scrollable layout, wrapping button labels, platform font fallbacks and accessible button sizes. Preserve Back navigation.

## Store price

The previous implementation retained the first successful `ProductDetails` for the entire app session. Resume retried only if no product had been loaded, and opening Settings did not refresh it. This is a confirmed stale-price path, but it does not establish the exact cause of the TestFlight screenshot showing `$2.99` behind Apple's `¥300` purchase sheet.

The updated service re-queries on foreground resume and whenever the purchase panel opens. Concurrent catalogue reads coalesce. While refreshing, the previous price is cleared and Buy is disabled. Failure leaves the old price unavailable and exposes Retry. The displayed value remains the store-provided localized string; the app does not convert currencies or select a price from its UI language.

Apple documents that the storefront determines `displayPrice`'s locale and that storefront data can change:
- https://developer.apple.com/documentation/storekit/product/displayprice
- https://developer.apple.com/documentation/storekit/storefront

No changes were made to purchase verification, entitlement persistence, StoreKit sync/restore authorization, advertising consent or reward grants.

## Verification

- `flutter analyze --no-pub`
- `flutter test --no-pub`: includes purchase verification/reconciliation/startup, privacy, localization, the new catalogue/UI coverage and all 151 games' smoke coverage
- `python3 -m unittest discover -s tool/release/tests -v`: 46 passed
- Optional UI previews: `flutter test --no-pub test/premium_ui_test.dart --dart-define=CAPTURE_PREMIUM_UI=true`
  - Saved to `build/premium-previews/`
  - These are Flutter widget-test renders with a fake `¥300` catalogue, not native StoreKit transaction evidence
  - Linux previews use installed Noto font fallbacks when available; the app uses its normal platform fonts

Still required before shipping this version: a signed iOS build, device/TestFlight check of the current store price versus Apple's sheet, cancel/reopen, restore, and owned state. No purchase was executed during this work.
