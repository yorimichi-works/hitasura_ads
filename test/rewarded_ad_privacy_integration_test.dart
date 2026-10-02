import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The locked SDK's codec lets tests simulate native callbacks without real ads.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:hitasura_ads/services/ads_privacy_service.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';

import 'ads_privacy_service_test.dart' show FakeConsent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channelName = 'plugins.flutter.io/google_mobile_ads';
  late List<String> calls;
  late Completer<int> loadRequested;
  late Completer<void> configurationRequested;
  Completer<void>? configurationGate;
  bool configurationFails = false;
  late FakeConsent gateway;
  late GoogleRewardedAdService service;

  Future<void> loaded(int id) async {
    await messenger.handlePlatformMessage(
      channelName,
      instanceManager.channel.codec.encodeMethodCall(
        MethodCall('onAdEvent', {'adId': id, 'eventName': 'onAdLoaded'}),
      ),
      (_) {},
    );
  }

  setUp(() {
    calls = [];
    loadRequested = Completer<int>();
    configurationRequested = Completer<void>();
    configurationGate = null;
    configurationFails = false;
    gateway = FakeConsent();
    instanceManager = AdInstanceManager(channelName);
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      // One-time Dart/native channel bootstrap, not MobileAds initialization.
      if (call.method == '_init') return null;
      calls.add(call.method);
      if (call.method == 'MobileAds#updateRequestConfiguration') {
        expect(gateway.calls, contains('collect'));
        expect(gateway.calls.last, 'permission');
        expect(call.arguments['maxAdContentRating'], MaxAdContentRating.t);
        expect(call.arguments['tagForChildDirectedTreatment'], isNull);
        expect(call.arguments['tagForUnderAgeOfConsent'], isNull);
        expect(call.arguments['ageRestrictedTreatment'], isNull);
        configurationRequested.complete();
        if (configurationFails) {
          throw PlatformException(code: 'configuration_failed');
        }
        await configurationGate?.future;
      }
      if (call.method == 'MobileAds#initialize') {
        expect(gateway.calls.last, 'permission');
        return InitializationStatus({});
      }
      if (call.method == 'loadRewardedAd') {
        expect(gateway.calls.last, 'permission');
        loadRequested.complete(call.arguments['adId'] as int);
      }
      return null;
    });
    service = GoogleRewardedAdService(
      platform: TargetPlatform.iOS,
      isWeb: false,
      adNetworkMode: AdNetworkMode.production,
      privacyService: AdsPrivacyService(gateway: gateway),
    );
  });

  tearDown(() {
    service.dispose();
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
  });

  test(
    'SDK and load wait for consent and use one concurrent initialization',
    () async {
      gateway.form = Completer<void>();
      final initialize = service.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
      await service.initialize();
      gateway.form!.complete();
      final id = await loadRequested.future;
      await loaded(id);
      await initialize;
      expect(service.status, RewardedAdStatus.ready);
      expect(
        calls.where((call) => call == 'MobileAds#initialize'),
        hasLength(1),
      );
      expect(calls.where((call) => call == 'loadRewardedAd'), hasLength(1));
      expect(calls.take(3), [
        'MobileAds#updateRequestConfiguration',
        'MobileAds#initialize',
        'loadRewardedAd',
      ]);
    },
  );

  test('SDK initialization awaits the T rating configuration', () async {
    configurationGate = Completer<void>();
    final initialize = service.initialize();
    await configurationRequested.future;
    expect(calls, ['MobileAds#updateRequestConfiguration']);
    configurationGate!.complete();
    final id = await loadRequested.future;
    await loaded(id);
    await initialize;
    expect(service.status, RewardedAdStatus.ready);
  });

  test(
    'configuration failure prevents SDK initialization and ad load',
    () async {
      configurationFails = true;
      await service.initialize();
      expect(calls, ['MobileAds#updateRequestConfiguration']);
      expect(service.status, RewardedAdStatus.failed);
    },
  );

  test(
    'consent denial prevents configuration, initialization and ad load',
    () async {
      gateway.allowed = false;
      await service.initialize();
      expect(calls, isEmpty);
      expect(service.status, RewardedAdStatus.failed);
    },
  );

  test(
    'consent revoked during configuration prevents SDK initialization',
    () async {
      configurationGate = Completer<void>();
      final initialize = service.initialize();
      await configurationRequested.future;
      gateway.allowed = false;
      configurationGate!.complete();
      await initialize;
      expect(calls, ['MobileAds#updateRequestConfiguration']);
      expect(service.status, RewardedAdStatus.failed);
    },
  );

  test('disposal during configuration prevents SDK initialization', () async {
    configurationGate = Completer<void>();
    final initialize = service.initialize();
    await configurationRequested.future;
    service.dispose();
    configurationGate!.complete();
    await initialize;
    expect(calls, ['MobileAds#updateRequestConfiguration']);
    service = GoogleRewardedAdService(platform: TargetPlatform.linux);
  });

  test(
    'revoked permission disposes a cached ad and never presents it',
    () async {
      final initialize = service.initialize();
      final id = await loadRequested.future;
      await loaded(id);
      await initialize;
      gateway.allowed = false;
      expect(
        await service.show(placementName: 'restore_search_energy'),
        RewardedAdResult.unavailable,
      );
      expect(calls, contains('disposeAd'));
      expect(calls, isNot(contains('showAdWithoutView')));
      expect(service.status, isNot(RewardedAdStatus.ready));
    },
  );

  test('late load is discarded after privacy choices change', () async {
    final initialize = service.initialize();
    final id = await loadRequested.future;
    gateway.allowed = false;
    await service.showPrivacyOptions();
    await loaded(id);
    await initialize;
    expect(service.status, isNot(RewardedAdStatus.ready));
    expect(calls, contains('disposeAd'));
    expect(calls, isNot(contains('showAdWithoutView')));
  });

  test(
    'late load after disposal is discarded without notifying disposed state',
    () async {
      final initialize = service.initialize();
      final id = await loadRequested.future;
      service.dispose();
      await loaded(id);
      await initialize;
      expect(calls, contains('disposeAd'));
      // Dispose is tested above, so leave a fresh idle service for tearDown.
      service = GoogleRewardedAdService(platform: TargetPlatform.linux);
    },
  );
}
