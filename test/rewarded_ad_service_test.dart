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

  test('release builds default to disabled without an explicit ad mode', () {
    final service = GoogleRewardedAdService(
      platform: TargetPlatform.android,
      isWeb: false,
      releaseMode: true,
    );

    expect(service.adNetworkMode, AdNetworkMode.disabled);
    expect(service.isSupported, isFalse);
    expect(service.usesTestAds, isFalse);
    service.dispose();
  });

  test('friend testing can explicitly use official test ads', () {
    final service = GoogleRewardedAdService(
      platform: TargetPlatform.android,
      isWeb: false,
      releaseMode: true,
      adNetworkMode: AdNetworkMode.test,
    );

    expect(service.adNetworkMode, AdNetworkMode.test);
    expect(service.isSupported, isTrue);
    expect(service.usesTestAds, isTrue);
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
