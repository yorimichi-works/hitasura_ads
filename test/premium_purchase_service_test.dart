import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/premium_purchase_service.dart';
import 'package:hitasura_ads/state/app_controller.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

PurchaseDetails purchase(PurchaseStatus status, {String? product}) =>
    PurchaseDetails(
      productID: product ?? PremiumPurchaseService.productId,
      purchaseID: '123',
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'app_store',
      ),
      transactionDate: '1',
      status: status,
    )..pendingCompletePurchase = true;

class FailingStore extends MemoryAppStore {
  FailingStore() : super(const AppSnapshot());
  bool fail = false;
  @override
  Future<void> save(AppSnapshot snapshot) async {
    if (fail) throw StateError('Storage failure');
    return super.save(snapshot);
  }
}

void main() {
  for (final status in [PurchaseStatus.purchased, PurchaseStatus.restored]) {
    test('verified $status persists before completing', () async {
      final calls = <String>[];
      final service = PremiumPurchaseService(
        verifyPurchase: (_) async {
          calls.add('verify');
          return true;
        },
        onUnlocked: () async {
          calls.add('persist');
        },
        completePurchase: (_) async {
          calls.add('complete');
        },
      );
      await service.handlePurchaseUpdates([purchase(status)]);
      expect(calls, ['verify', 'persist', 'complete']);
      expect(service.error, isNull);
      service.dispose();
    });

    test(
      'unverified, missing or revoked $status cannot unlock or complete',
      () async {
        final service = PremiumPurchaseService(
          verifyPurchase: (_) async => false,
          onUnlocked: () async => fail('Must not unlock'),
          completePurchase: (_) async => fail('Must not complete'),
        );
        await service.handlePurchaseUpdates([purchase(status)]);
        expect(service.error, contains('could not be verified'));
        expect(service.busy, isFalse);
        service.dispose();
      },
    );
  }

  for (final status in [
    PurchaseStatus.pending,
    PurchaseStatus.canceled,
    PurchaseStatus.error,
  ]) {
    test('$status cannot verify, unlock or complete', () async {
      final service = PremiumPurchaseService(
        verifyPurchase: (_) async {
          fail('Must not verify');
        },
        onUnlocked: () async => fail('Must not unlock'),
        completePurchase: (_) async => fail('Must not complete'),
      );
      await service.handlePurchaseUpdates([purchase(status)]);
      expect(service.busy, status == PurchaseStatus.pending);
      service.dispose();
    });
  }

  test('unrelated product cannot unlock or clear a pending purchase', () async {
    final service = PremiumPurchaseService(
      verifyPurchase: (_) async {
        fail('Must not verify');
      },
      onUnlocked: () async => fail('Must not unlock'),
    )..busy = true;
    await service.handlePurchaseUpdates([
      purchase(PurchaseStatus.purchased, product: 'wrong'),
    ]);
    expect(service.busy, isTrue);
    service.dispose();
  });

  test('verification exception and persistence failure leave transaction unfinished', () async {
    for (final failVerification in [true, false]) {
      final service = PremiumPurchaseService(
        verifyPurchase: (_) async {
          if (failVerification) throw StateError('Native verification failed');
          return true;
        },
        onUnlocked: () async => throw StateError('Disk full'),
        completePurchase: (_) async => fail('Must not complete'),
      );
      await service.handlePurchaseUpdates([purchase(PurchaseStatus.purchased)]);
      expect(service.error, isNotNull);
      service.dispose();
    }
  });

  test('failed persistence does not leave premium active in memory', () async {
    final store = FailingStore();
    final controller = await AppController.create(store: store);
    store.fail = true;
    await expectLater(controller.grantPremium(), throwsStateError);
    expect(controller.premiumNoAds, isFalse);
    controller.dispose();
  });
}
