# Manual iOS release build

`ios-app-store-ipa` in `codemagic.yaml` builds a signed production IPA only when
started manually, then uploads the IPA to App Store Connect through the existing
`codemagic` integration. It has no Git triggers, TestFlight review submission or
tester-group assignment, App Review submission, or automatic release. Its
maximum duration is 60 minutes. Preparing this workflow locally does **not**
start or authorize a paid build or perform an upload.

## Prerequisites before starting

- Production bundle ID: `com.syamo.hitasuraads`
- Apple team: `3W8HVJ3U8W`; App Store Connect app ID: `6818519730`
- Existing Codemagic App Store Connect integration: `codemagic`
- Existing distribution certificate reference: `cirno-app-store`
- Approved profile reference: `hitasura-app-store-profile` (Apple name
  `Hitasura Ads App Store`, `app_store`, expires 2027-09-28), created and fetched
  into Codemagic on 2026-10-02. The account operator confirmed the matching
  existing certificate in Codemagic. Verify it remains unexpired and matches
  this bundle ID, team, and certificate before each release. The workflow references these aliases
  only; it never requests new credentials, creates profiles, or calls
  `fetch-signing-files`.
- Open and review the public privacy-policy and support pages. The workflow's
  required `privacy_policy_url` and `support_url` inputs become the environment
  variables `PRIVACY_POLICY_URL` and `SUPPORT_URL` and then runtime Dart defines.
  There are no default URLs. The offline preflight rejects empty, local,
  placeholder, non-HTTPS, and credential-bearing URLs; it does not establish
  that the pages are live or legally sufficient.

The manual build-number input defaults to `1`, matching the source build suffix
in `pubspec.yaml` version `1.0.1+1`. The marketing version is read from pubspec.
For this update, explicitly supply a positive integer greater than every uploaded
build as `build_number` (`IOS_BUILD_NUMBER` in the environment); the live preflight
rejects a reused number. The source version is never rewritten by the workflow.

## Version 1.0.1 media update

This release branch starts at the shipping Build 4 source commit
`5969bac7aab8589fb3a7ad92990c92cc059c05fe`. Its only changes are the marketing
version above, the corresponding preflight test expectations, and this release
note. Runtime code, game content, purchase and advertising behavior, bundled
assets, dependency locks, native projects, and signing/upload configuration are
unchanged. Later diagnostic builds and feature changes are not included.

Run `ios-app-store-ipa` manually on this branch with the existing production URLs:

- `privacy_policy_url`: `https://yorimichi-works.jp/apps/hitasura-ads/privacy`
- `support_url`: `https://yorimichi-works.jp/apps/hitasura-ads/support`
- `build_number`: the next unused positive integer, checked against both App Store
  Connect and any in-flight CI upload immediately before launch

After the IPA is uploaded and Apple finishes processing, select the new build for
the 1.0.1 App Store version and update its screenshots separately. Keep public
release manual; this workflow does not submit for review or release the app.

## Guards and execution

1. Run Python preflight unit tests.
2. Validate production IDs, `ADMOB_MODE=production`, URL inputs, native AdMob
   configuration, and the intended version.
3. Perform a read-only
   `app-store-connect get-latest-build-number 6818519730 --platform IOS --all-versions --json --no-color --log-stream stderr`
   lookup through the existing integration. This requires Codemagic CLI tools
   0.67.0 or newer. Compare numerically across **all** App Store and TestFlight
   versions, including expired builds. The selected number must be strictly
   greater. Missing/outdated CLI, authentication/network errors, timeout,
   unexpected JSON, zero, and unexplained empty output all fail the workflow.
4. Permit a first build only when the lookup exits successfully with its
   recognized no-build message and empty output, and `--allow-initial-build` is
   explicitly enabled. That flag never overrides a failed lookup or a reused
   build number.
5. Locally inspect the supplied provisioning profile's expiry, exact bundle ID,
   team, App Store entitlements, and certificate presence. No profile contents
   or private signing material are printed or saved as artifacts.
6. Run `flutter pub get`, `flutter analyze --no-pub`, and `flutter test --no-pub`.
7. Apply only the named profile and build the signed production IPA, with
   automatic build-number management disabled in the export options.
8. Retain the IPA, dSYMs, Xcode logs, and a non-secret preflight report as build
   artifacts. The publisher uploads the IPA using `auth: integration`, with
   `submit_to_testflight: false` and `submit_to_app_store: false`.
   `release_type` is omitted because Codemagic requires review submission for
   that field; manual public release is controlled separately in App Store
   Connect. No beta groups, cancellation, or build-expiry actions
   are configured. Apple processing must then be checked; upload alone is not
   App Review submission, distribution, or approval. Those later actions remain
   separate, authorized steps.

Run the standard-library tests locally without Apple credentials or macOS:

```sh
python3 -m unittest discover -s tool/release/tests -v
```

An offline configuration check is also available once the real URLs are present
in the environment:

```sh
APP_STORE_APPLE_ID=6818519730 ADMOB_MODE=production python3 tool/release/preflight.py
```

Offline success is not a signed-build, live-App-Store, URL-availability, purchase,
advertising, or physical-device verification. A preflight lookup is a point-in-time
check, not a reservation; do not run concurrent release builds with the same
number. If uploading an artifact later outside this workflow, recheck its build
number immediately before that upload.

## Official references (checked 2026-10-02)

- [Codemagic named signing references](https://docs.codemagic.io/yaml-code-signing/signing-ios/)
- [Codemagic App Store Connect upload and submission controls](https://docs.codemagic.io/yaml-publishing/app-store-connect/)
- [Codemagic build inputs](https://docs.codemagic.io/knowledge-codemagic/build-inputs/)
- [Build-number CLI options](https://github.com/codemagic-ci-cd/cli-tools/blob/master/docs/app-store-connect/get-latest-build-number.md)
- [CLI no-build output and all-version lookup implementation](https://github.com/codemagic-ci-cd/cli-tools/blob/master/src/codemagic/tools/app_store_connect/actions/latest_build_number_actions.py)
- [Profile application/export options](https://github.com/codemagic-ci-cd/cli-tools/blob/master/docs/xcode-project/use-profiles.md)
