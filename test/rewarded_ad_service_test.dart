import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';

void main() {
  test('unsupported host never invokes the mobile ads SDK', () async {
    final service = GoogleRewardedAdService(
      platform: TargetPlatform.windows,
      isWeb: false,
    );

    expect(service.isSupported, isFalse);
    expect(service.status, RewardedAdStatus.unsupported);
    expect(await service.show(), RewardedAdResult.unavailable);

    service.dispose();
  });

  test(
    'debug pseudo reward rejects a concurrent show and becomes ready again',
    () async {
      final service = DebugRewardedAdService();

      await service.initialize();
      final first = service.show();
      expect(service.status, RewardedAdStatus.showing);
      expect(await service.show(), RewardedAdResult.loadFailed);
      expect(await first, RewardedAdResult.rewarded);
      expect(service.status, RewardedAdStatus.ready);

      service.dispose();
    },
  );
}
