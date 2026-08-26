# Debug Unlock and Profile QA

## Debug unlock overlay

`AppController.debugUnlockAll` is an in-memory, debug-only flag. The catalog
uses `isAdVisibleAsDiscovered` for display and replay access while the persisted
`discoveredIds` set remains unchanged. Turning the flag off therefore restores
the exact original count. No.151 is visible for QA while the flag is on, but
normal selection and rewarded-unlock rules remain unchanged.

The developer menu is available only through a `kDebugMode` callback. Release
Web builds, including GitHub Pages, do not expose that callback or the Web
pseudo-reward service.

## Initial profile

- Default nickname: `広告大好き` (editable; blank submission falls back to it)
- Age: integer dropdown, 1 through 100, default 29
- Gender: segmented `男` / `女`, stored as `男性` / `女性`

The edit screen uses the same age range and gender values. Existing saved names
are loaded unchanged. Existing age and gender values are mapped into the new
controls, and saves continue through the existing `AppStore` keys.

`AdSelectionService` evaluates `男性`, `女性`, `N歳以上`, and `N歳未満`
conditions from catalog tags and unlock-condition text. No.151 still requires
all 150 regular ad IDs regardless of profile eligibility.

## Automated checks

- Debug overlay: actual 1/151 -> visual 151/151 -> actual 1/151
- Persisted discovery set unchanged across overlay ON/OFF
- No.151 normal selection rule remains based on all No.1-150
- Male/female matching
- 19/20 boundary for a 20+ condition
- Initial nickname, age, and gender defaults
- Profile data persistence uses existing snapshot/store model
