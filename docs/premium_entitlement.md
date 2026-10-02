# iOS premium entitlement reconciliation

The non-consumable product is `ad_free_unlimited`. Access is reconciled at startup,
on app resume, on matching StoreKit purchase updates, and after the user selects
Restore Purchases. Product-catalog availability is not required for reconciliation.

Startup installs the purchase listener and starts reconciliation/catalogue reads
in the background, so unavailable StoreKit accounts cannot hold the app on its
launch screen. Background verification and catalogue queries are bounded to eight
seconds. Explicit Restore synchronization permits two minutes for Apple sign-in;
its subsequent plugin enumeration uses the shorter bound. A timeout is unknown,
retains the cache, releases the serial purchase queue and discards that operation's
late result. Repeated foreground refreshes coalesce while one is pending.
An unavailable catalogue is retried on foreground refresh so recovering the
connection or signing into the store does not require restarting the app.

## Evidence and cache rules

- Only native StoreKit `.verified` transactions can grant iOS premium access.
- A verified current non-consumable entitlement wins over historical refunds.
- A refund/revocation found in `Transaction.latest(for:)` can revoke the cached
  purchase only when its transaction/original ID matches. Older signed evidence
  cannot overwrite newer evidence for the same identity.
- A missing background entitlement, unverified transaction, network/store error,
  or cancelled authentication leaves the last cached entitlement unchanged.
- Only the explicit Restore Purchases action invokes `AppStore.sync()`. After
  successful sync, an empty current entitlement and no conflicting/unverified
  history can clear access from a previous App Store account.
- Legacy `premium_no_ads=true` is preserved offline. A verified current purchase
  migrates it to an identified entitlement. Unrelated history cannot revoke it;
  successful explicit sync can clear a cache when the current account owns none.
- A single versioned preference stores access plus transaction/original IDs and
  the StoreKit signed date. It takes precedence over the legacy boolean. No JWS,
  Apple account identifier, credentials, or purchase data is sent to a server.
- Entitlement operations and controller writes are serialized. Purchase updates
  are completed only after entitlement persistence, and only when native evidence
  identifies that update's transaction. Save failure leaves it unfinished.
- Revocation never deletes discoveries, stars, coins, or other earned progress.

Immediate account-switch detection while offline is deliberately not promised:
there is no trustworthy negative evidence then. The owner can use Restore
Purchases after switching accounts. The cached access remains until a matching
verified revocation or a successful explicit synchronization resolves ownership.

## Verification

`premium_entitlement_test.dart` and `premium_reconciliation_test.dart` cover
legacy migration, refunds/rebuy, stale/unrelated evidence, offline/unverified/error
responses, explicit sync, serialized updates, storage failure and disposal. The
existing purchase, search-energy and Settings tests cover adjacent behavior.

Linux Flutter tests do **not** compile the Swift StoreKit bridge. Before final
review, compile the updated iOS source and test on a signed device/Sandbox:

1. Buy, terminate, relaunch offline; premium remains available.
2. Refund/revoke, then foreground/relaunch; access is removed without losing play
   progress. Repurchase grants access again.
3. Restore with the owning account and after reinstall; access returns.
4. Switch to a non-owning App Store account and explicitly restore; access clears
   after successful sync. Cancel sign-in or disconnect the network; cache remains.
5. Retry after an interrupted purchase or simulated storage failure; entitlement
   is delivered and persisted before the transaction is finished.

Apple references:

- https://developer.apple.com/documentation/storekit/transaction/currententitlements
- https://developer.apple.com/documentation/storekit/transaction/latest(for:)
- https://developer.apple.com/documentation/storekit/transaction/updates
- https://developer.apple.com/documentation/storekit/appstore/sync()
