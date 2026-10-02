import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/services/ads_privacy_service.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';

class FakeConsent implements AdsConsentGateway {
  final calls = <String>[];
  bool allowed = true;
  bool required = true;
  String? failAt;
  Completer<void>? form;

  Future<void> call(String name) async {
    calls.add(name);
    if (failAt == name) throw StateError('Simulated consent failure');
  }

  @override
  Future<void> update() => call('update');
  @override
  Future<void> collectIfRequired() async {
    await call('collect');
    await form?.future;
  }

  @override
  Future<bool> canRequestAds() async {
    await call('permission');
    return allowed;
  }

  @override
  Future<bool> privacyOptionsRequired() async {
    await call('required');
    return required;
  }

  @override
  Future<void> showPrivacyOptions() => call('options');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'launch refresh discovers privacy entry without consent form or ads',
    () async {
      final gateway = FakeConsent();
      final service = AdsPrivacyService(gateway: gateway);
      expect(await service.prepare(), isTrue);
      expect(gateway.calls, ['update', 'required']);
      expect(service.canRequestAds, isFalse);
      expect(service.privacyOptionsRequired, isTrue);
      service.dispose();
    },
  );

  test(
    'consent form finishes before permission; concurrent calls share it',
    () async {
      final gateway = FakeConsent()..form = Completer<void>();
      final service = AdsPrivacyService(gateway: gateway);
      final first = service.ensureConsent();
      final second = service.ensureConsent();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.calls, ['update', 'required', 'collect']);
      expect(service.canRequestAds, isFalse);
      gateway.form!.complete();
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(gateway.calls.where((call) => call == 'update'), hasLength(1));
      expect(await service.ensureConsent(), isTrue);
      expect(gateway.calls.where((call) => call == 'collect'), hasLength(1));
      service.dispose();
    },
  );

  for (final failure in ['update', 'required', 'collect', 'permission']) {
    test(
      '$failure failure blocks every ad path, including placement changes',
      () async {
        final gateway = FakeConsent()..failAt = failure;
        final privacy = AdsPrivacyService(gateway: gateway);
        final service = GoogleRewardedAdService(
          platform: TargetPlatform.iOS,
          isWeb: false,
          adNetworkMode: AdNetworkMode.production,
          privacyService: privacy,
        );
        var nativeCalls = 0;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMessageHandler(
          'plugins.flutter.io/google_mobile_ads',
          (_) async {
            nativeCalls++;
            return null;
          },
        );
        await service.initialize();
        expect(
          await service.show(placementName: 'unlock_catalog'),
          RewardedAdResult.unavailable,
        );
        expect(privacy.canRequestAds, isFalse);
        expect(privacy.hasError, isTrue);
        expect(
          nativeCalls,
          0,
          reason: 'Neither SDK init nor ad load may bypass UMP',
        );
        service.dispose();
        messenger.setMockMessageHandler(
          'plugins.flutter.io/google_mobile_ads',
          null,
        );
      },
    );
  }

  test('false permission never requests a production ad', () async {
    final privacy = AdsPrivacyService(gateway: FakeConsent()..allowed = false);
    final service = GoogleRewardedAdService(
      platform: TargetPlatform.iOS,
      isWeb: false,
      adNetworkMode: AdNetworkMode.production,
      privacyService: privacy,
    );
    await service.initialize();
    expect(service.status, RewardedAdStatus.failed);
    expect(await service.show(), RewardedAdResult.unavailable);
    service.dispose();
  });

  test(
    'privacy changes invalidate permission first and recheck afterward',
    () async {
      final gateway = FakeConsent();
      final service = AdsPrivacyService(gateway: gateway);
      await service.ensureConsent();
      final changes = <bool>[];
      service.addListener(() => changes.add(service.canRequestAds));
      gateway.allowed = false;
      await service.showPrivacyOptions();
      expect(changes.first, isFalse);
      expect(service.canRequestAds, isFalse);
      expect(gateway.calls, contains('options'));
      service.dispose();
    },
  );

  test('privacy form failure remains blocked and can be retried', () async {
    final gateway = FakeConsent();
    final service = AdsPrivacyService(gateway: gateway);
    await service.ensureConsent();
    gateway.failAt = 'options';
    await service.showPrivacyOptions();
    expect(service.canRequestAds, isFalse);
    expect(service.hasError, isTrue);
    gateway.failAt = null;
    expect(await service.ensureConsent(), isTrue);
    expect(gateway.calls.where((call) => call == 'update'), hasLength(2));
    service.dispose();
  });

  test('late consent completion after disposal cannot authorize ads', () async {
    final gateway = FakeConsent()..form = Completer<void>();
    final service = AdsPrivacyService(gateway: gateway);
    final pending = service.ensureConsent();
    await Future<void>.delayed(Duration.zero);
    service.dispose();
    gateway.form!.complete();
    expect(await pending, isFalse);
  });
}
