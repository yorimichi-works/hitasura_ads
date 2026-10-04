import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/services/premium_purchase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

ProductDetails catalogueProduct(String price, String currency) =>
    ProductDetails(
      id: PremiumPurchaseService.productId,
      title: 'Premium',
      description: '',
      price: price,
      rawPrice: 300,
      currencyCode: currency,
    );

ProductDetailsResponse catalogue(ProductDetails product) =>
    ProductDetailsResponse(productDetails: [product], notFoundIDs: []);

void main() {
  testWidgets(
    'resume replaces an already loaded price using current store data',
    (tester) async {
      var queries = 0;
      final service = PremiumPurchaseService(
        onUnlocked: () async {},
        supportedPlatform: true,
        purchaseUpdates: const Stream.empty(),
        isStoreAvailable: () async => true,
        queryProducts: (_) async => catalogue(
          ++queries == 1
              ? catalogueProduct(r'$2.99', 'USD')
              : catalogueProduct('¥300', 'JPY'),
        ),
      );
      await service.initialize();
      await tester.pump();
      expect(service.product!.price, r'$2.99');
      expect(service.canBuy, isTrue);
      await service.refreshEntitlement();
      await tester.pump();
      expect(queries, 2);
      expect(service.product!.price, '¥300');
      expect(service.product!.currencyCode, 'JPY');
      expect(service.canBuy, isTrue);
      service.dispose();
    },
  );

  testWidgets(
    'refresh clears stale price, disables buy, and coalesces duplicate requests',
    (tester) async {
      final next = Completer<ProductDetailsResponse>();
      var queries = 0;
      final service = PremiumPurchaseService(
        onUnlocked: () async {},
        supportedPlatform: true,
        purchaseUpdates: const Stream.empty(),
        isStoreAvailable: () async => true,
        queryProducts: (_) async => ++queries == 1
            ? catalogue(catalogueProduct(r'$2.99', 'USD'))
            : next.future,
      );
      await service.initialize();
      await tester.pump();
      final first = service.refreshCatalogue();
      final repeated = service.refreshCatalogue();
      expect(identical(first, repeated), isTrue);
      expect(service.product, isNull);
      expect(service.catalogueLoading, isTrue);
      expect(service.canBuy, isFalse);
      await tester.pump();
      expect(queries, 2);
      next.complete(catalogue(catalogueProduct('¥300', 'JPY')));
      await first;
      expect(service.catalogueLoading, isFalse);
      expect(service.product!.price, '¥300');
      expect(service.canBuy, isTrue);
      service.dispose();
    },
  );

  testWidgets('failed refresh never restores old price and can be retried', (
    tester,
  ) async {
    var queries = 0;
    final service = PremiumPurchaseService(
      onUnlocked: () async {},
      supportedPlatform: true,
      purchaseUpdates: const Stream.empty(),
      isStoreAvailable: () async => true,
      queryProducts: (_) async {
        queries++;
        if (queries == 2) throw StateError('offline');
        return catalogue(
          catalogueProduct(
            queries == 1 ? r'$2.99' : '2,99 €',
            queries == 1 ? 'USD' : 'EUR',
          ),
        );
      },
    );
    await service.initialize();
    await tester.pump();
    await service.refreshCatalogue();
    expect(service.product, isNull);
    expect(service.canBuy, isFalse);
    expect(service.error, isNotNull);
    await service.refreshCatalogue();
    expect(service.product!.price, '2,99 €');
    expect(service.error, isNull);
    expect(service.canBuy, isTrue);
    service.dispose();
  });
  testWidgets('catalogue refresh preserves a purchase operation error', (
    tester,
  ) async {
    final service = PremiumPurchaseService(
      onUnlocked: () async {},
      supportedPlatform: true,
      purchaseUpdates: const Stream.empty(),
      isStoreAvailable: () async => true,
      queryProducts: (_) async => catalogue(catalogueProduct('¥300', 'JPY')),
    );
    await service.initialize();
    await tester.pump();
    await service.handlePurchaseUpdates([
      PurchaseDetails(
        productID: PremiumPurchaseService.productId,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'test',
        ),
        transactionDate: null,
        status: PurchaseStatus.error,
      ),
    ]);
    expect(service.error, 'Purchase failed');
    await service.refreshCatalogue();
    expect(service.product!.price, '¥300');
    expect(service.error, 'Purchase failed');
    service.dispose();
  });
}
