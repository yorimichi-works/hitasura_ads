import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/ad_catalog.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/search_energy_service.dart';
import 'package:hitasura_ads/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('consumes one energy and recovers one every 20 minutes', () {
    var now = DateTime.utc(2026, 8, 26, 12);
    final service = SearchEnergyService(clock: () => now);
    var state = SearchEnergyState(remaining: 5, recoveryAnchor: now);

    state = service.consume(state)!;
    expect(state.remaining, 4);

    now = now.add(const Duration(minutes: 19, seconds: 59));
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

  test('offline recovery keeps partial intervals and never exceeds five', () {
    var now = DateTime.utc(2026, 8, 26, 12);
    final service = SearchEnergyService(clock: () => now);
    var state = SearchEnergyState(remaining: 0, recoveryAnchor: now);

    now = now.add(const Duration(minutes: 65));
    state = service.synchronize(state);
    expect(state.remaining, 3);
    expect(service.untilNextRecovery(state), const Duration(minutes: 15));

    now = now.add(const Duration(days: 2));
    state = service.synchronize(state);
    expect(state.remaining, 5);
  });

  test(
    'controller persists consumption and restores elapsed recovery',
    () async {
      final catalog = await AdCatalog.load();
      var now = DateTime.utc(2026, 8, 26, 12);
      final store = MemoryAppStore(
        AppSnapshot(searchEnergy: 2, searchEnergyRecoveryAnchor: now),
      );
      var controller = await AppController.create(
        store: store,
        catalog: catalog,
        clock: () => now,
      );

      expect(await controller.consumeSearchEnergy(), isTrue);
      expect(controller.searchEnergy, 1);
      expect(store.snapshot.searchEnergy, 1);

      now = now.add(const Duration(minutes: 41));
      controller = await AppController.create(
        store: store,
        catalog: catalog,
        clock: () => now,
      );
      expect(controller.searchEnergy, 3);

      await controller.refillSearchEnergy();
      expect(controller.searchEnergy, 5);
      expect(store.snapshot.searchEnergy, 5);
    },
  );
}
