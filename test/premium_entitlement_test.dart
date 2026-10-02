import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/models/premium_entitlement.dart';
import 'package:hitasura_ads/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const owned = PremiumEntitlement(
  active: true,
  source: 'active',
  transactionId: '123',
  originalTransactionId: '123',
  signedDateMs: 100,
);

PremiumEntitlementDecision decision(
  PremiumEntitlementStatus status, {
  String id = '123',
  int signed = 200,
}) => PremiumEntitlementDecision(
  status: status,
  transactionId: id,
  originalTransactionId: id,
  signedDateMs: signed,
);

class FailingEntitlementStore extends MemoryAppStore {
  FailingEntitlementStore(super.snapshot);
  bool fail = false;

  @override
  Future<void> save(AppSnapshot snapshot) async {
    if (fail) throw StateError('Disk full');
    return super.save(snapshot);
  }
}

class DelayedEntitlementStore extends MemoryAppStore {
  DelayedEntitlementStore(super.snapshot);
  Completer<void>? gate;

  @override
  Future<void> save(AppSnapshot snapshot) async {
    if (gate != null) await gate!.future;
    return super.save(snapshot);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cache round-trips access with transaction identity atomically', () {
    final decoded = PremiumEntitlement.decode(owned.encode())!;
    expect(decoded.active, isTrue);
    expect(decoded.transactionId, '123');
    expect(decoded.originalTransactionId, '123');
    expect(decoded.signedDateMs, 100);
  });

  test('malformed native decisions are unknown', () {
    for (final data in <Map<String, Object?>?>[
      null,
      {'status': 'false'},
      {'status': 'active'},
      {'status': 'revoked', 'transactionId': '123'},
      {
        'status': 'active',
        'transactionId': 123,
        'originalTransactionId': '123',
        'signedDateMs': 1,
      },
    ]) {
      expect(
        PremiumEntitlementDecision.fromMap(data).status,
        PremiumEntitlementStatus.unknown,
      );
    }
  });

  test('unknown, unrelated and stale refunds never revoke cached access', () {
    expect(const PremiumEntitlementDecision.unknown().applyTo(owned), isNull);
    expect(
      decision(PremiumEntitlementStatus.revoked, id: 'old').applyTo(owned),
      isNull,
    );
    expect(
      decision(PremiumEntitlementStatus.revoked, signed: 99).applyTo(owned),
      isNull,
    );
    expect(
      decision(PremiumEntitlementStatus.revoked)
          .applyTo(const PremiumEntitlement.legacy(true)),
      isNull,
    );
  });

  test('matching verified refund revokes, replacement purchase restores', () {
    final revoked = decision(PremiumEntitlementStatus.revoked).applyTo(owned)!;
    expect(revoked.active, isFalse);
    final replacement = decision(
      PremiumEntitlementStatus.active,
      id: '456',
    ).applyTo(revoked)!;
    expect(replacement.active, isTrue);
    expect(replacement.transactionId, '456');
  });

  test('stale active evidence cannot undo a newer revocation', () {
    final revoked = decision(PremiumEntitlementStatus.revoked).applyTo(owned)!;
    for (final signed in [199, 200]) {
      expect(
        decision(
          PremiumEntitlementStatus.active,
          signed: signed,
        ).applyTo(revoked),
        isNull,
      );
    }
    expect(
      decision(
        PremiumEntitlementStatus.active,
        id: '456',
        signed: 1,
      ).applyTo(revoked)!.active,
      isTrue,
    );
  });

  test(
    'legacy bool migrates without dropping legitimate offline access',
    () async {
      SharedPreferences.setMockInitialValues({'premium_no_ads': true});
      final store = PreferencesAppStore();
      final snapshot = await store.load();
      expect(snapshot.premiumNoAds, isTrue);
      expect(snapshot.premiumEntitlement!.source, 'legacy');
      await store.save(snapshot);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('premium_entitlement_v1'), isNotNull);
      expect((await store.load()).premiumNoAds, isTrue);
    },
  );

  test('versioned revocation wins over a stale legacy true flag', () async {
    SharedPreferences.setMockInitialValues({
      'premium_no_ads': true,
      'premium_entitlement_v1': decision(PremiumEntitlementStatus.revoked)
          .applyTo(owned)!
          .encode(),
    });
    expect((await PreferencesAppStore().load()).premiumNoAds, isFalse);
  });

  test(
    'controller persists refund without erasing earned game progress',
    () async {
      final store = MemoryAppStore(
        const AppSnapshot(
          premiumNoAds: true,
          premiumEntitlement: owned,
          discoveredIds: {'g001'},
          arcade: ArcadeState(coins: 321, stars: {'g001': 3}),
        ),
      );
      final controller = await AppController.create(store: store);
      await controller.applyPremiumEntitlement(
        decision(PremiumEntitlementStatus.revoked),
      );
      expect(controller.premiumNoAds, isFalse);
      expect(store.snapshot.premiumNoAds, isFalse);
      expect(store.snapshot.premiumEntitlement!.source, 'revoked');
      expect(store.snapshot.discoveredIds, {'g001'});
      expect(store.snapshot.arcade.coins, 321);
      expect(store.snapshot.arcade.stars, {'g001': 3});
      controller.dispose();
      final restarted = await AppController.create(store: store);
      expect(restarted.premiumNoAds, isFalse);
      restarted.dispose();
    },
  );

  test(
    'failed revocation persistence restores cached access and evidence',
    () async {
      final store = FailingEntitlementStore(
        const AppSnapshot(premiumNoAds: true, premiumEntitlement: owned),
      );
      final controller = await AppController.create(store: store);
      store.fail = true;
      await expectLater(
        controller.applyPremiumEntitlement(
          decision(PremiumEntitlementStatus.revoked),
        ),
        throwsStateError,
      );
      expect(controller.premiumNoAds, isTrue);
      expect(controller.premiumEntitlement.transactionId, '123');
      store.fail = false;
      await controller.applyPremiumEntitlement(
        decision(PremiumEntitlementStatus.revoked),
      );
      expect(controller.premiumNoAds, isFalse);
      controller.dispose();
    },
  );

  test('successful explicit sync can clear a legacy account cache', () async {
    final controller = await AppController.create(
      store: MemoryAppStore(const AppSnapshot(premiumNoAds: true)),
    );
    await controller.applyPremiumEntitlement(
      const PremiumEntitlementDecision(
        status: PremiumEntitlementStatus.absentAfterSync,
      ),
    );
    expect(controller.premiumNoAds, isFalse);
    controller.dispose();
  });

  test(
    'disposal during save never notifies, including persistence failure',
    () async {
      for (final fails in [false, true]) {
        final store = DelayedEntitlementStore(
          const AppSnapshot(premiumNoAds: true, premiumEntitlement: owned),
        );
        final controller = await AppController.create(store: store);
        var notifications = 0;
        controller.addListener(() => notifications++);
        store.gate = Completer<void>();
        final saving = controller.applyPremiumEntitlement(
          decision(PremiumEntitlementStatus.revoked),
        );
        // Attach the error expectation before completing the failed future.
        final check = fails ? expectLater(saving, throwsStateError) : saving;
        await Future<void>.delayed(Duration.zero);
        controller.dispose();
        if (fails) {
          store.gate!.completeError(StateError('Disk full'));
        } else {
          store.gate!.complete();
        }
        await check;
        expect(notifications, 0);
        expect(controller.premiumNoAds, fails);
      }
    },
  );
}
