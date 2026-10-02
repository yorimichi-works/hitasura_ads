import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/premium_entitlement.dart';
import 'purchase_verification.dart';

/// One permanent upgrade shared by the iOS and Android storefronts.
class PremiumPurchaseService extends ChangeNotifier {
  PremiumPurchaseService({
    required this.onUnlocked,
    Future<bool> Function(PurchaseDetails)? verifyPurchase,
    this.completePurchase,
    this.cachedEntitlement,
    this.onEntitlement,
    ReadPremiumEntitlement? readEntitlement,
    this.restorePurchases,
  }) : _verifyPurchase = verifyPurchase ?? verifyCurrentPurchase,
       _readEntitlement =
           readEntitlement ?? (Platform.isIOS ? readPremiumEntitlement : null);

  static const productId = 'ad_free_unlimited';

  final Future<void> Function() onUnlocked;
  final Future<bool> Function(PurchaseDetails) _verifyPurchase;
  final Future<void> Function(PurchaseDetails)? completePurchase;
  final PremiumEntitlement Function()? cachedEntitlement;
  final Future<void> Function(PremiumEntitlementDecision)? onEntitlement;
  final ReadPremiumEntitlement? _readEntitlement;
  final Future<void> Function()? restorePurchases;
  Future<void> _purchaseQueue = Future<void>.value();
  bool _disposed = false;
  InAppPurchase get _store => InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? product;
  String? error;
  bool busy = false;
  bool available = false;
  bool get _reconcilesEntitlements =>
      _readEntitlement != null &&
      cachedEntitlement != null &&
      onEntitlement != null;
  bool get canRestore => !busy && (_reconcilesEntitlements || available);

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _purchaseQueue.then((_) async {
      if (!_disposed) await operation();
    });
    // One failure must not poison all later store updates or retries.
    _purchaseQueue = next.catchError((Object _) {});
    return next;
  }

  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _subscription ??= _store.purchaseStream.listen(
      (purchases) {
        unawaited(handlePurchaseUpdates(purchases));
      },
      onError: (Object failure) {
        if (_disposed) return;
        error = '$failure';
        busy = false;
        notifyListeners();
      },
    );
    // Entitlements do not depend on the product catalogue being available.
    await refreshEntitlement();
    try {
      available = await _store.isAvailable();
      if (available) {
        final response = await _store.queryProductDetails({productId});
        product = response.productDetails
            .where((p) => p.id == productId)
            .firstOrNull;
        error = response.error?.message;
      }
    } catch (e) {
      error = '$e';
    }
    if (!_disposed) notifyListeners();
  }

  /// Startup/resume reads preserve the cache on an empty or uncertain response.
  /// This never invokes AppStore.sync or asks the user to authenticate.
  Future<void> refreshEntitlement() => _enqueue(() async {
    if (!_reconcilesEntitlements) return;
    try {
      await _reconcile(userInitiatedSync: false);
    } catch (_) {
      // Offline, StoreKit and persistence errors cannot revoke cached access.
    }
  });

  Future<PremiumEntitlementDecision> _reconcile({
    required bool userInitiatedSync,
  }) async {
    final decision = await _readEntitlement!(
      cached: cachedEntitlement!(),
      userInitiatedSync: userInitiatedSync,
    );
    if (_disposed ||
        decision.status == PremiumEntitlementStatus.unknown ||
        (!userInitiatedSync &&
            decision.status == PremiumEntitlementStatus.absentAfterSync)) {
      return const PremiumEntitlementDecision.unknown();
    }
    await onEntitlement!(decision);
    return decision;
  }

  Future<void> buy() async {
    final selected = product;
    if (busy || selected == null) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: selected),
      );
      if (!started) {
        busy = false;
        error = 'Purchase could not start';
        notifyListeners();
      }
    } catch (e) {
      busy = false;
      error = '$e';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (!canRestore) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (_reconcilesEntitlements) {
        // AppStore.sync is deliberately limited to this explicit user action.
        await _enqueue(() async {
          final decision = await _reconcile(userInitiatedSync: true);
          if (decision.status == PremiumEntitlementStatus.unknown) {
            error = 'Purchases could not be verified. Please try again.';
          }
        });
      }
      if (!_disposed) await (restorePurchases ?? _store.restorePurchases)();
    } catch (e) {
      error = '$e';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @visibleForTesting
  Future<void> handlePurchaseUpdates(List<PurchaseDetails> purchases) =>
      _enqueue(() => _handlePurchaseUpdates(purchases));

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    var hasMatchingPurchase = false;
    for (final purchase in purchases) {
      if (_disposed || purchase.productID != productId) continue;
      hasMatchingPurchase = true;
      try {
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            if (_reconcilesEntitlements) {
              final decision = await _reconcile(userInitiatedSync: false);
              if (_disposed) return;
              if (decision.status == PremiumEntitlementStatus.unknown) {
                error = 'Purchase could not be verified. Please try restoring purchases.';
                continue;
              }
              // A StoreKit update can be a refund. Reconcile access first,
              // then finish only the specific transaction verified natively.
              if (purchase.pendingCompletePurchase &&
                  decision.transactionId == purchase.purchaseID) {
                await (completePurchase ?? _store.completePurchase)(purchase);
              }
              error = null;
              break;
            }
            if (!await _verifyPurchase(purchase)) {
              error = 'Purchase could not be verified. Please try restoring purchases.';
              continue;
            }
            if (_disposed) return;
            await onUnlocked();
            // Complete only after verified entitlement has been saved.
            if (purchase.pendingCompletePurchase) {
              await (completePurchase ?? _store.completePurchase)(purchase);
            }
            error = null;
            break;
          case PurchaseStatus.error:
            error = purchase.error?.message ?? 'Purchase failed';
            break;
          case PurchaseStatus.canceled:
          case PurchaseStatus.pending:
            break;
        }
      } catch (e) {
        error = '$e';
      }
    }
    if (!hasMatchingPurchase || _disposed) return;
    busy = purchases.any(
      (purchase) =>
          purchase.productID == productId &&
          purchase.status == PurchaseStatus.pending,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }
}
