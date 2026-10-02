import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/models/premium_entitlement.dart';
import 'package:hitasura_ads/services/premium_purchase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'premium_entitlement_test.dart' show owned, decision;

PurchaseDetails update(PurchaseStatus status, {String id = '123'}) =>
    PurchaseDetails(
      productID: PremiumPurchaseService.productId,
      purchaseID: id,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'app_store',
      ),
      transactionDate: '1',
      status: status,
    )..pendingCompletePurchase = true;

class Harness {
  PremiumEntitlement cached = owned;
  PremiumEntitlementDecision response =
      const PremiumEntitlementDecision.unknown();
  bool failRead = false;
  bool failSave = false;
  Completer<PremiumEntitlementDecision>? delayed;
  final calls = <String>[];
  late final service = PremiumPurchaseService(
    onUnlocked: () async => fail('iOS must use the verified decision'),
    cachedEntitlement: () => cached,
    readEntitlement: ({required cached, required userInitiatedSync}) async {
      calls.add(userInitiatedSync ? 'sync' : 'read');
      if (failRead) {
        throw StateError('Offline, cancelled or StoreKit unavailable');
      }
      return delayed == null ? response : await delayed!.future;
    },
    onEntitlement: (result) async {
      calls.add('persist');
      if (failSave) throw StateError('Disk full');
      cached = result.applyTo(cached) ?? cached;
    },
    completePurchase: (_) async => calls.add('finish'),
    restorePurchases: () async => calls.add('restore'),
  );
}

void main() {
  test(
    'background read restores a verified entitlement without product details',
    () async {
      final h = Harness()
        ..cached = const PremiumEntitlement.legacy(false)
        ..response = decision(PremiumEntitlementStatus.active);
      expect(h.service.product, isNull);
      expect(h.service.available, isFalse);
      await h.service.refreshEntitlement();
      expect(h.cached.active, isTrue);
      expect(h.calls, ['read', 'persist']);
      h.service.dispose();
    },
  );

  test(
    'offline, unverified and empty background reads preserve cached access',
    () async {
      for (final fails in [false, true]) {
        final h = Harness()..failRead = fails;
        await h.service.refreshEntitlement();
        expect(h.cached, owned);
        expect(h.calls, ['read']);
        h.service.dispose();
      }
    },
  );

  test(
    'background absence cannot impersonate successful explicit sync',
    () async {
      final h = Harness()
        ..response = const PremiumEntitlementDecision(
          status: PremiumEntitlementStatus.absentAfterSync,
        );
      await h.service.refreshEntitlement();
      expect(h.cached, owned);
      expect(h.calls, ['read']);
      h.service.dispose();
    },
  );

  test(
    'refund update revokes and persists before finishing transaction',
    () async {
      final h = Harness()
        ..response = decision(PremiumEntitlementStatus.revoked);
      await h.service.handlePurchaseUpdates([update(PurchaseStatus.purchased)]);
      expect(h.cached.active, isFalse);
      expect(h.calls, ['read', 'persist', 'finish']);
      h.service.dispose();
    },
  );

  test('unverified purchase never grants, revokes or finishes', () async {
    final h = Harness();
    await h.service.handlePurchaseUpdates([update(PurchaseStatus.purchased)]);
    expect(h.cached, owned);
    expect(h.calls, ['read']);
    expect(h.service.error, contains('could not be verified'));
    h.service.dispose();
  });

  test(
    'failed save leaves verified transaction unfinished and cache unchanged',
    () async {
      final h = Harness()
        ..response = decision(PremiumEntitlementStatus.revoked)
        ..failSave = true;
      await h.service.handlePurchaseUpdates([update(PurchaseStatus.purchased)]);
      expect(h.cached, owned);
      expect(h.calls, ['read', 'persist']);
      expect(h.service.error, isNotNull);
      h.service.dispose();
    },
  );

  test('pending, canceled and error events cannot revoke', () async {
    for (final status in [
      PurchaseStatus.pending,
      PurchaseStatus.canceled,
      PurchaseStatus.error,
    ]) {
      final h = Harness()
        ..response = decision(PremiumEntitlementStatus.revoked);
      await h.service.handlePurchaseUpdates([update(status)]);
      expect(h.cached, owned);
      expect(h.calls, isEmpty);
      h.service.dispose();
    }
  });

  test('explicit successful sync reconciles switched account even without catalogue', () async {
    final h = Harness()
      ..response = const PremiumEntitlementDecision(
        status: PremiumEntitlementStatus.absentAfterSync,
      );
    expect(h.service.canRestore, isTrue);
    await h.service.restore();
    expect(h.cached.active, isFalse);
    expect(h.calls, ['sync', 'persist', 'restore']);
    h.service.dispose();
  });

  test(
    'failed or cancelled user sync never revokes or starts a second restore',
    () async {
      final h = Harness()..failRead = true;
      await h.service.restore();
      expect(h.cached, owned);
      expect(h.calls, ['sync']);
      expect(h.service.error, isNotNull);
      expect(h.service.busy, isFalse);
      h.service.dispose();
    },
  );

  test(
    'uncertain user sync preserves cache and presents retry error',
    () async {
      final h = Harness();
      await h.service.restore();
      expect(h.cached, owned);
      expect(h.service.error, isNotNull);
      expect(h.calls, ['sync', 'restore']);
      h.service.dispose();
    },
  );

  test(
    'old refund cannot override replacement entitlement or finish another ID',
    () async {
      final h = Harness()
        ..response = decision(PremiumEntitlementStatus.active, id: '456');
      await h.service.handlePurchaseUpdates([update(PurchaseStatus.purchased)]);
      expect(h.cached.transactionId, '456');
      expect(h.calls, ['read', 'persist']);
      h.response = decision(PremiumEntitlementStatus.revoked);
      await h.service.refreshEntitlement();
      expect(h.cached.active, isTrue);
      expect(h.cached.transactionId, '456');
      h.service.dispose();
    },
  );

  test('concurrent background and purchase updates execute serially', () async {
    final gate = Completer<PremiumEntitlementDecision>();
    final h = Harness()..delayed = gate;
    final first = h.service.refreshEntitlement();
    final second = h.service.handlePurchaseUpdates([
      update(PurchaseStatus.restored),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(h.calls, ['read']);
    gate.complete(decision(PremiumEntitlementStatus.active));
    await Future.wait([first, second]);
    expect(h.calls, ['read', 'persist', 'read', 'persist', 'finish']);
    h.service.dispose();
  });

  test('disposing during native read does not persist or finish', () async {
    final gate = Completer<PremiumEntitlementDecision>();
    final h = Harness()..delayed = gate;
    final pending = h.service.handlePurchaseUpdates([
      update(PurchaseStatus.purchased),
    ]);
    await Future<void>.delayed(Duration.zero);
    h.service.dispose();
    gate.complete(decision(PremiumEntitlementStatus.active));
    await pending;
    expect(h.calls, ['read']);
  });
}
