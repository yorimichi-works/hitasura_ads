import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/arcade/registry.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/search_energy_service.dart';
import 'package:hitasura_ads/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('consumes one energy and recovers one every 3 minutes', () {
    var now = DateTime.utc(2026, 8, 26, 12);
    final service = SearchEnergyService(clock: () => now);
    var state = SearchEnergyState(remaining: 5, recoveryAnchor: now);

    state = service.consume(state)!;
    expect(state.remaining, 4);

    now = now.add(const Duration(minutes: 2, seconds: 59));
    state = service.synchronize(state);
    expect(state.remaining, 4);
    expect(service.untilNextRecovery(state), const Duration(seconds: 1));

    now = now.add(const Duration(seconds: 1));
    state = service.synchronize(state);
    expect(state.remaining, 5);
  });

  test('five searches reach zero and a sixth search is rejected', () {
    final now = DateTime.utc(2026, 8, 26, 12);
    final service = SearchEnergyService(clock: () => now);
    var state = SearchEnergyState(remaining: 5, recoveryAnchor: now);

    for (var count = 4; count >= 0; count--) {
      state = service.consume(state)!;
      expect(state.remaining, count);
    }
    expect(service.consume(state), isNull);
  });

  test('full recovery time follows the original partial recovery anchor', () {
    var now = DateTime.utc(2026, 8, 26, 12);
    final service = SearchEnergyService(clock: () => now);
    var state = SearchEnergyState(remaining: 2, recoveryAnchor: now);
    expect(service.fullRecoveryAt(state), now.add(const Duration(minutes: 9)));

    now = now.add(const Duration(minutes: 4));
    state = service.synchronize(state);
    expect(state.remaining, 3);
    expect(service.fullRecoveryAt(state), DateTime.utc(2026, 8, 26, 12, 9));

    now = now.add(const Duration(minutes: 5));
    state = service.synchronize(state);
    expect(service.fullRecoveryAt(state), isNull);
  });

  test('offline recovery keeps partial intervals and never exceeds five', () {
    var now = DateTime.utc(2026, 8, 26, 12);
    final service = SearchEnergyService(clock: () => now);
    var state = SearchEnergyState(remaining: 0, recoveryAnchor: now);

    now = now.add(const Duration(minutes: 10));
    state = service.synchronize(state);
    expect(state.remaining, 3);
    expect(service.untilNextRecovery(state), const Duration(minutes: 2));

    now = now.add(const Duration(days: 2));
    state = service.synchronize(state);
    expect(state.remaining, 5);
  });

  test(
    'controller persists consumption and restores elapsed recovery',
    () async {
      var now = DateTime.utc(2026, 8, 26, 12);
      final store = MemoryAppStore(
        AppSnapshot(searchEnergy: 2, searchEnergyRecoveryAnchor: now),
      );
      var controller = await AppController.create(
        store: store,
        clock: () => now,
      );

      expect(await controller.consumeSearchEnergy(), isTrue);
      expect(controller.searchEnergy, 1);
      expect(store.snapshot.searchEnergy, 1);

      now = now.add(const Duration(minutes: 7));
      controller = await AppController.create(store: store, clock: () => now);
      expect(controller.searchEnergy, 3);

      await controller.refillSearchEnergy();
      expect(controller.searchEnergy, 5);
      expect(store.snapshot.searchEnergy, 5);
    },
  );

  test(
    'premium purchase gives unlimited searches without spending tickets',
    () async {
      final now = DateTime.utc(2026, 8, 26, 12);
      final store = MemoryAppStore(
        AppSnapshot(searchEnergy: 0, searchEnergyRecoveryAnchor: now),
      );
      final controller = await AppController.create(
        store: store,
        clock: () => now,
      );

      expect(controller.canSearch, isFalse);
      await controller.grantPremium();
      expect(controller.canSearch, isTrue);
      expect(controller.searchEnergyFullAt, isNull);
      expect(await controller.consumeSearchEnergy(), isTrue);
      expect(controller.searchEnergy, 0);
      expect(store.snapshot.premiumNoAds, isTrue);
    },
  );

  test('premium can unlock a chosen secret ad without a sponsor', () async {
    final controller = await AppController.create(store: MemoryAppStore());
    final secret = allGames.firstWhere((game) => game.isSecret);
    expect(await controller.unlockWithReward(secret.id), isFalse);
    await controller.grantPremium();
    expect(await controller.unlockWithReward(secret.id), isTrue);
    expect(controller.isDiscovered(secret), isTrue);
  });
}
