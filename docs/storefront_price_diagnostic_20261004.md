# Hitasura price diagnostic preparation

Owner-only diagnostic follow-up to TestFlight 1.0.0 (5). The owner still sees `$2.99`
after the purchase page performs a fresh StoreKit query. No currency is fixed in
the production UI: it displays `Product.displayPrice` through Flutter's pinned
`in_app_purchase_storekit` 0.4.13 plugin.

## Scope

The owner-only panel starts an independent native `Product.products(for:)` read
for `ad_free_unlimited` and a fresh Flutter query in the same manual observation.
It also records the price currently displayed when the button was tapped.
These queries are concurrent but not atomic. The native storefront is read both
before and after the native product query. Both raw `countryCode` and `id` are
retained without region inference, alongside raw price, currency code,
`displayPrice`, price locale, app version/build, OS version and bundle match.

The panel does not overwrite the purchase catalogue. It neither purchases nor
restores, reads receipts or entitlements, changes an account/region, or uploads
diagnostics. Error output is limited to code/domain. Requests are coalesced;
native completion times out after 15 seconds and Dart reads after 18 seconds.
Late native callbacks are ignored. A failed diagnostic cannot grant access.

## Disabled defaults and future owner-only build

A separate manual `ios-owner-price-diagnostic` workflow enables both gates and
verifies the archived native flag before upload. Existing production workflows
and checked-in build numbers remain unchanged. The UI is hidden unless
`--dart-define=IAP_PRICE_DIAGNOSTICS=true` is explicitly supplied. The native
handler separately requires `HitasuraPriceDiagnostics=true` in the build's
Info.plist; the checked-in value is false. Both switches are enabled only in
the approved owner diagnostic workflow. The currently reviewed Build 4
and distributed Build 5 remain unchanged. Do not submit this diagnostic to App
Review without a separate explicit request.

## Interpretation

- Same USD values natively and through Flutter: the UI is faithfully showing
  the returned Apple product data; changing UI language is not a valid fix.
- Native JPY versus fresh Flutter USD: investigate the plugin/query timing.
- Displayed USD versus both fresh queries JPY: investigate app catalogue timing.
- A storefront change during the native query makes the sample inconclusive.
- `countryCode=USA` and `id=143462` must be reported verbatim. 143462 is Japan;
  one field alone is not proof of the account's actual storefront.

Apple Developer forum thread 844269 describes the same pair with USD products,
not an empty result. It is a developer report, not an Apple-confirmed cause of
Hyakumono's empty catalogue: https://developer.apple.com/forums/thread/844269

The diagnostic itself is not a fix. Native compilation and real-device output
remain unverified until an approved macOS signed build and owner test run.
