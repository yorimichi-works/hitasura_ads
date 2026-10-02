import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// Unit-level codec check only. Native smoke evidence never uses this test.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:hitasura_ads/services/ads_privacy_service.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';

import '../../test/ads_privacy_service_test.dart' show FakeConsent;
import 'ad_qa_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all runtime flags and explicit test ad mode are required', () {
    for (var bits = 0; bits < 16; bits++) {
      for (final mode in ['test', 'production', 'disabled', '']) {
        void check() => requireRewardedQaEnvironment(
          debug: bits & 1 != 0,
          ios: bits & 2 != 0,
          explicitlyEnabled: bits & 4 != 0,
          nativeSimulator: bits & 8 != 0,
          adMode: mode,
        );
        expect(
          check,
          bits == 15 && mode == 'test' ? returnsNormally : throwsStateError,
        );
      }
    }
  });

  test('show request is never mislabeled as a shown callback', () {
    expect(sdkStageForLog('[RewardedAd] showing'), 'sdk_show_requested');
    expect(sdkStageForLog('[RewardedAd] loaded'), 'sdk_load_callback');
    expect(sdkStageForLog('[RewardedAd] reward earned'), 'sdk_reward_callback');
    expect(sdkStageForLog('[RewardedAd] dismissed'), 'sdk_dismiss_callback');
    expect(sdkStageForLog('[RewardedAd] DEBUG pseudo reward earned'), isNull);
  });

  test(
    'shipping test mode requests the exact official iOS rewarded demo unit',
    () async {
      const name = 'plugins.flutter.io/google_mobile_ads';
      instanceManager = AdInstanceManager(name);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final loaded = Completer<int>();
      final gateway = FakeConsent();
      String? requestedUnit;
      messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
        if (call.method == 'MobileAds#initialize') {
          return InitializationStatus({});
        }
        if (call.method == 'loadRewardedAd') {
          requestedUnit = call.arguments['adUnitId'] as String;
          loaded.complete(call.arguments['adId'] as int);
        }
        return null;
      });
      final service = GoogleRewardedAdService(
        platform: TargetPlatform.iOS,
        isWeb: false,
        adNetworkMode: AdNetworkMode.test,
        privacyService: AdsPrivacyService(gateway: gateway),
      );
      try {
        final initialization = service.initialize();
        final id = await loaded.future;
        expect(requestedUnit, iosRewardedDemoUnit);
        expect(gateway.calls, contains('collect'));
        expect(service.usesTestAds, isTrue);
        await messenger.handlePlatformMessage(
          name,
          instanceManager.channel.codec.encodeMethodCall(
            MethodCall('onAdEvent', {'adId': id, 'eventName': 'onAdLoaded'}),
          ),
          (_) {},
        );
        await initialization;
        expect(service.status, RewardedAdStatus.ready);
      } finally {
        service.dispose();
        messenger.setMockMethodCallHandler(instanceManager.channel, null);
      }
    },
  );
}
