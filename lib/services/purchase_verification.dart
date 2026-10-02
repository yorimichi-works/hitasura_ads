import 'dart:io';

import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/premium_entitlement.dart';

typedef ReadPremiumEntitlement = Future<PremiumEntitlementDecision> Function({
  required PremiumEntitlement cached,
  required bool userInitiatedSync,
});

/// Background reads never force a network refresh or show a sign-in prompt.
/// Only the explicit Restore Purchases action may request AppStore.sync().
Future<PremiumEntitlementDecision> readPremiumEntitlement({
  required PremiumEntitlement cached,
  required bool userInitiatedSync,
}) async {
  if (!Platform.isIOS) return const PremiumEntitlementDecision.unknown();
  final result = await const MethodChannel('hitasura_ads/purchases')
      .invokeMapMethod<String, dynamic>('readPremiumEntitlement', {
        'productId': 'ad_free_unlimited',
        'cachedTransactionId': cached.transactionId,
        'cachedOriginalTransactionId': cached.originalTransactionId,
        'userInitiatedSync': userInitiatedSync,
      });
  final decision = PremiumEntitlementDecision.fromMap(result);
  // An absent entitlement is only authoritative after a successful user sync.
  if (!userInitiatedSync &&
      decision.status == PremiumEntitlementStatus.absentAfterSync) {
    return const PremiumEntitlementDecision.unknown();
  }
  return decision;
}

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
