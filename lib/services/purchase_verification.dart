import 'dart:io';

import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// iOS trusts StoreKit's native .verified current entitlement, never a Dart
/// boolean decoded from an unsigned receipt or PurchaseStatus alone.
Future<bool> verifyCurrentPurchase(PurchaseDetails purchase) async {
  // Android verification is unchanged by this iOS readiness change.
  if (!Platform.isIOS) return true;
  if (purchase.purchaseID == null) return false;
  return await const MethodChannel('hitasura_ads/purchases').invokeMethod<bool>(
        'verifyCurrentEntitlement',
        {'productId': purchase.productID, 'transactionId': purchase.purchaseID},
      ) ==
      true;
}
