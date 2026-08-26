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
}
