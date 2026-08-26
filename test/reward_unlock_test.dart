import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/ad_catalog.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/models/reward_purpose.dart';
import 'package:hitasura_ads/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reward unlock accepts No.1-150 once and always rejects No.151',
    () async {
      final catalog = await AdCatalog.load();
      final store = MemoryAppStore();
      final controller = await AppController.create(
        store: store,
        catalog: catalog,
      );
      final initialEnergy = controller.searchEnergy;

      expect(await controller.unlockAdWithReward('AD_001'), isTrue);
      expect(await controller.unlockAdWithReward('AD_150'), isTrue);
      expect(await controller.unlockAdWithReward('AD_001'), isFalse);
      expect(await controller.unlockAdWithReward('AD_151'), isFalse);
      expect(await controller.unlockAdWithReward('AD_UNKNOWN'), isFalse);

      expect(controller.discoveredIds, containsAll(['AD_001', 'AD_150']));
      expect(controller.discoveredIds, isNot(contains('AD_151')));
      expect(store.snapshot.discoveredIds, hasLength(2));
      expect(controller.searchEnergy, initialEnergy);
    },
  );

  test('reward purposes keep energy and catalog rewards distinct', () {
    const energy = RewardPurpose.restoreSearchEnergy();
    const unlock = RewardPurpose.unlockAd('AD_042');

    expect(energy.type, RewardPurposeType.restoreSearchEnergy);
    expect(energy.adId, isNull);
    expect(unlock.type, RewardPurposeType.unlockAd);
    expect(unlock.adId, 'AD_042');
  });
}
