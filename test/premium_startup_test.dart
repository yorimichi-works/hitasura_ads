import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/models/premium_entitlement.dart';
import 'package:hitasura_ads/services/premium_purchase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'premium_entitlement_test.dart' show owned, decision;
import 'premium_reconciliation_test.dart' show update;

final noProducts = ProductDetailsResponse(productDetails: [], notFoundIDs: []);

void main() {
  testWidgets('startup returns with listener installed while StoreKit waits', (
    tester,
  ) async {
    final calls = <String>[];
    final syncFlags = <bool>[];
    final updates = StreamController<List<PurchaseDetails>>(
      onListen: () => calls.add('listen'),
    );
    final native = Completer<PremiumEntitlementDecision>();
    final catalogue = Completer<bool>();
    var cached = owned;
    final service = PremiumPurchaseService(
      onUnlocked: () async => fail('Native verification required'),
      supportedPlatform: true,
      purchaseUpdates: updates.stream,
      isStoreAvailable: () {
        calls.add('catalogue');
        return catalogue.future;
      },
      queryProducts: (_) async => noProducts,
      cachedEntitlement: () => cached,
      readEntitlement: ({required cached, required userInitiatedSync}) {
        syncFlags.add(userInitiatedSync);
        calls.add('read');
        return native.future;
      },
      onEntitlement: (result) async {
        cached = result.applyTo(cached) ?? cached;
      },
    );
    var ready = false;
    unawaited(service.initialize().then((_) => ready = true));
    await tester.pump();
    expect(ready, isTrue);
    expect(calls.first, 'listen');
    expect(syncFlags, [false]);
    expect(cached, owned);
    expect(service.product, isNull);
    await service.initialize();
    expect(calls.where((value) => value == 'listen').length, 1);
    expect(calls.where((value) => value == 'catalogue').length, 1);
    await tester.pump(const Duration(seconds: 9));
    expect(cached, owned);
    expect(service.error, contains('TimeoutException'));
    service.dispose();
    unawaited(updates.close());
    await tester.pump();
  });

  testWidgets('timed out read frees purchase queue and ignores late evidence', (
    tester,
  ) async {
    final firstRead = Completer<PremiumEntitlementDecision>();
    var reads = 0;
    var cached = const PremiumEntitlement.legacy(false);
    final calls = <String>[];
    final service = PremiumPurchaseService(
      onUnlocked: () async => fail('Native verification required'),
      cachedEntitlement: () => cached,
      readEntitlement: ({required cached, required userInitiatedSync}) async {
        reads++;
        return reads == 1
            ? await firstRead.future
            : decision(PremiumEntitlementStatus.active);
      },
      onEntitlement: (result) async {
        calls.add('persist');
        cached = result.applyTo(cached) ?? cached;
      },
      completePurchase: (_) async => calls.add('finish'),
    );
    final startup = service.refreshEntitlement();
    final purchase = service.handlePurchaseUpdates([
      update(PurchaseStatus.purchased),
    ]);
    await tester.pump();
    expect(reads, 1);
    await tester.pump(const Duration(seconds: 9));
    await Future.wait([startup, purchase]);
    expect(reads, 2);
    expect(cached.transactionId, '123');
    expect(calls, ['persist', 'finish']);
    firstRead.complete(decision(PremiumEntitlementStatus.active, id: '777'));
    await tester.pump();
    expect(cached.transactionId, '123');
    expect(calls, ['persist', 'finish']);
    service.dispose();
  });

  testWidgets(
    'repeated resumes coalesce and retry after an uncertain timeout',
    (tester) async {
      var reads = 0;
      final never = Completer<PremiumEntitlementDecision>();
      final service = PremiumPurchaseService(
        onUnlocked: () async {},
        cachedEntitlement: () => owned,
        onEntitlement: (_) async {},
        readEntitlement: ({required cached, required userInitiatedSync}) {
          reads++;
          return never.future;
        },
      );
      final first = service.refreshEntitlement();
      final second = service.refreshEntitlement();
      expect(identical(first, second), isTrue);
      await tester.pump();
      expect(reads, 1);
      await tester.pump(const Duration(seconds: 9));
      await first;
      final retry = service.refreshEntitlement();
      await tester.pump();
      expect(reads, 2);
      await tester.pump(const Duration(seconds: 9));
      await retry;
      service.dispose();
    },
  );

  testWidgets('late catalogue success cannot overwrite a timed out response', (
    tester,
  ) async {
    final products = Completer<ProductDetailsResponse>();
    final updates = StreamController<List<PurchaseDetails>>();
    final service = PremiumPurchaseService(
      onUnlocked: () async {},
      supportedPlatform: true,
      purchaseUpdates: updates.stream,
      isStoreAvailable: () async => true,
      queryProducts: (_) => products.future,
    );
    await service.initialize();
    await tester.pump(const Duration(seconds: 9));
    expect(service.available, isFalse);
    expect(service.error, contains('TimeoutException'));
    products.complete(
      ProductDetailsResponse(
        productDetails: [
          ProductDetails(
            id: PremiumPurchaseService.productId,
            title: 'Premium',
            description: '',
            price: 'test',
            rawPrice: 1,
            currencyCode: 'JPY',
          ),
        ],
        notFoundIDs: [],
      ),
    );
    await tester.pump();
    expect(service.available, isFalse);
    expect(service.product, isNull);
    expect(service.error, contains('TimeoutException'));
    service.dispose();
    unawaited(updates.close());
    await tester.pump();
  });

  testWidgets('explicit Restore allows time for user authentication', (
    tester,
  ) async {
    final sync = Completer<PremiumEntitlementDecision>();
    final syncFlags = <bool>[];
    var cached = owned;
    final service = PremiumPurchaseService(
      onUnlocked: () async {},
      storeTimeout: const Duration(seconds: 1),
      userSyncTimeout: const Duration(seconds: 10),
      cachedEntitlement: () => cached,
      readEntitlement: ({required cached, required userInitiatedSync}) {
        syncFlags.add(userInitiatedSync);
        return sync.future;
      },
      onEntitlement: (result) async =>
          cached = result.applyTo(cached) ?? cached,
      restorePurchases: () async {},
    );
    final restoring = service.restore();
    await tester.pump(const Duration(seconds: 2));
    expect(syncFlags, [true]);
    expect(service.busy, isTrue, reason: service.error);
    expect(service.error, isNull);
    sync.complete(decision(PremiumEntitlementStatus.active));
    await tester.pump();
    await restoring;
    expect(cached.active, isTrue);
    expect(service.error, isNull);
    expect(service.busy, isFalse);
    service.dispose();
  });

  testWidgets(
    'timed out explicit sync preserves cache and discards late absence',
    (tester) async {
      final sync = Completer<PremiumEntitlementDecision>();
      var cached = owned;
      final service = PremiumPurchaseService(
        onUnlocked: () async {},
        userSyncTimeout: const Duration(seconds: 10),
        cachedEntitlement: () => cached,
        readEntitlement: ({required cached, required userInitiatedSync}) =>
            sync.future,
        onEntitlement: (result) async =>
            cached = result.applyTo(cached) ?? cached,
        restorePurchases: () async {},
      );
      final restoring = service.restore();
      await tester.pump();
      await tester.pump(const Duration(seconds: 11));
      await restoring;
      expect(cached, owned);
      expect(service.error, isNotNull);
      sync.complete(
        const PremiumEntitlementDecision(
          status: PremiumEntitlementStatus.absentAfterSync,
        ),
      );
      await tester.pump();
      expect(cached, owned);
      service.dispose();
    },
  );

  testWidgets('catalogue completion after disposal never notifies', (
    tester,
  ) async {
    final products = Completer<ProductDetailsResponse>();
    final updates = StreamController<List<PurchaseDetails>>();
    var notifications = 0;
    final service = PremiumPurchaseService(
      onUnlocked: () async {},
      supportedPlatform: true,
      purchaseUpdates: updates.stream,
      isStoreAvailable: () async => true,
      queryProducts: (_) => products.future,
    )..addListener(() => notifications++);
    await service.initialize();
    await tester.pump();
    service.dispose();
    products.complete(noProducts);
    await tester.pump();
    expect(notifications, 0);
    unawaited(updates.close());
    await tester.pump();
  });

  testWidgets('foreground refresh retries catalogue after startup timeout', (
    tester,
  ) async {
    final first = Completer<ProductDetailsResponse>();
    final updates = StreamController<List<PurchaseDetails>>();
    var queries = 0;
    final premium = ProductDetails(
      id: PremiumPurchaseService.productId,
      title: 'Premium',
      description: '',
      price: 'test',
      rawPrice: 1,
      currencyCode: 'JPY',
    );
    final service = PremiumPurchaseService(
      onUnlocked: () async {},
      supportedPlatform: true,
      purchaseUpdates: updates.stream,
      isStoreAvailable: () async => true,
      queryProducts: (_) async {
        queries++;
        return queries == 1
            ? await first.future
            : ProductDetailsResponse(
                productDetails: [premium],
                notFoundIDs: [],
              );
      },
    );
    await service.initialize();
    await tester.pump(const Duration(seconds: 9));
    expect(service.product, isNull);
    await service.refreshEntitlement();
    await tester.pump();
    expect(queries, 2);
    expect(service.product, premium);
    expect(service.available, isTrue);
    expect(service.error, isNull);
    first.complete(noProducts);
    await tester.pump();
    expect(service.product, premium);
    service.dispose();
    unawaited(updates.close());
    await tester.pump();
  });
}
