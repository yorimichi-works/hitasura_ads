import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'purchase_verification.dart';

/// One permanent upgrade shared by the iOS and Android storefronts.
class PremiumPurchaseService extends ChangeNotifier {
  PremiumPurchaseService({
    required this.onUnlocked,
    Future<bool> Function(PurchaseDetails)? verifyPurchase,
    this.completePurchase,
  }) : _verifyPurchase = verifyPurchase ?? verifyCurrentPurchase;

  static const productId = 'ad_free_unlimited';

  final Future<void> Function() onUnlocked;
  final Future<bool> Function(PurchaseDetails) _verifyPurchase;
  final Future<void> Function(PurchaseDetails)? completePurchase;
  Future<void> _purchaseQueue = Future<void>.value();
  bool _disposed = false;
  InAppPurchase get _store => InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? product;
  String? error;
  bool busy = false;
  bool available = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _subscription ??= _store.purchaseStream.listen((purchases) {
      _purchaseQueue = _purchaseQueue.then(
        (_) => handlePurchaseUpdates(purchases),
      );
    });
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
    notifyListeners();
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
    if (busy || !available) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _store.restorePurchases();
    } catch (e) {
      error = '$e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  Future<void> handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    var hasMatchingPurchase = false;
    for (final purchase in purchases) {
      if (_disposed || purchase.productID != productId) continue;
      hasMatchingPurchase = true;
      try {
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
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
