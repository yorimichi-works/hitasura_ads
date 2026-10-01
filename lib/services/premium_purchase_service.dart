import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// One permanent upgrade shared by the iOS and Android storefronts.
class PremiumPurchaseService extends ChangeNotifier {
  PremiumPurchaseService({required this.onUnlocked});

  static const productId = 'ad_free_unlimited';

  final Future<void> Function() onUnlocked;
  InAppPurchase get _store => InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? product;
  String? error;
  bool busy = false;
  bool available = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _subscription ??= _store.purchaseStream.listen(_handlePurchases);
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

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;
      try {
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            await onUnlocked();
            break;
          case PurchaseStatus.error:
            error = purchase.error?.message ?? 'Purchase failed';
            break;
          case PurchaseStatus.canceled:
          case PurchaseStatus.pending:
            break;
        }
        if (purchase.pendingCompletePurchase) {
          await _store.completePurchase(purchase);
        }
      } catch (e) {
        error = '$e';
      }
    }
    busy = purchases.any(
      (purchase) =>
          purchase.productID == productId &&
          purchase.status == PurchaseStatus.pending,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }
}
