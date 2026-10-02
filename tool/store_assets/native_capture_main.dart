// Debug-only iOS simulator capture entry point; never used by release main.dart.
// Displays unchanged production screens with a local, seeded progress fixture.
// simctl launch passes locale/scene through SIMCTL_CHILD_HITASURA_CAPTURE_*.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hitasura_ads/app.dart';
import 'package:hitasura_ads/arcade/registry.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/l10n/l10n.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';
import 'package:hitasura_ads/state/app_controller.dart';
import 'package:hitasura_ads/ui/ad_player.dart';
import 'package:hitasura_ads/ui/collection.dart';
import 'package:hitasura_ads/ui/rush.dart';

class _NoAds extends RewardedAdService {
  @override
  RewardedAdStatus get status => RewardedAdStatus.unsupported;
  @override
  bool get isSupported => false;
  @override
  bool get usesTestAds => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<RewardedAdResult> show({String placementName = 'reward'}) async =>
      RewardedAdResult.unavailable;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode ||
      !Platform.isIOS ||
      !Platform.environment.containsKey('SIMULATOR_DEVICE_NAME')) {
    throw StateError('Capture harness only runs on an iOS debug simulator.');
  }
  final code = Platform.environment['HITASURA_CAPTURE_LOCALE'];
  if (code == null) {
    throw StateError('Missing capture locale launch environment');
  }
  final scene = Platform.environment['HITASURA_CAPTURE_SCENE'] ?? 'home';
  if (!languages.any((l) => l.code == code)) {
    throw ArgumentError.value(code, 'locale');
  }
  const scenes = {'home', 'collection', 'pin', 'runner', 'rush', 'preview'};
  if (!scenes.contains(scene)) throw ArgumentError.value(scene, 'scene');
  L10n.code = code;
  final now = DateTime.now();
  final controller = await AppController.create(
    store: MemoryAppStore(
      AppSnapshot(
        user: UserProfile(
          id: 'simulator-capture',
          nickname: 'PLAYER',
          age: 0,
          createdAt: now,
        ),
        discoveredIds: {for (final g in allGames.take(40)) g.id},
        soundEffectsEnabled: false,
        notificationsEnabled: false,
        searchEnergy: 5,
        searchEnergyRecoveryAnchor: now,
        arcade: ArcadeState(
          language: code,
          coins: 1234,
          xp: 900,
          stars: {'AD_001': 3, 'AD_004': 2},
        ),
      ),
    ),
  );
  final appKey = GlobalKey();
  runApp(
    HitasuraAdsApp(
      key: appKey,
      controller: controller,
      rewardedAdService: _NoAds(),
    ),
  );
  NavigatorState? navigator;
  void findNavigator(Element e) {
    if (e is StatefulElement && e.state is NavigatorState) {
      navigator = e.state as NavigatorState;
      return;
    }
    e.visitChildElements(findNavigator);
  }

  Future<void> show(String target) async {
    final context = appKey.currentContext;
    if (context == null) throw StateError('App did not mount');
    findNavigator(context as Element);
    final nav = navigator;
    if (nav == null) throw StateError('App navigator missing');
    nav.popUntil((r) => r.isFirst);
    if (target == 'home') return;
    final Widget screen = switch (target) {
      'collection' => CollectionScreen(controller: controller),
      'rush' => RushScreen(controller: controller),
      _ => AdPlayerScreen(
        controller: controller,
        first: allGames.firstWhere((g) => g.no == (target == 'pin' ? 1 : 18)),
        roulette: false,
        replayMode: true,
      ),
    };
    unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => screen)));
  }

  await Future<void>.delayed(const Duration(seconds: 2));
  if (scene == 'preview') {
    // Continuous native runner recording, beginning about 3s after launch.
    // Production timing, game loop, HUD, and result screen remain unchanged.
    await show('runner');
  } else {
    await show(scene);
  }
  await File('${Directory.systemTemp.path}/hitasura_capture_state.json')
      .writeAsString(
        jsonEncode({
          'locale': L10n.code,
          'requested_scene': scene,
          'active_scene': scene == 'preview' ? 'runner' : scene,
          'simulator': Platform.environment['SIMULATOR_DEVICE_NAME'],
          'ready_at': DateTime.now().toUtc().toIso8601String(),
          'capture_target': 'tool/store_assets/native_capture_main.dart',
        }),
      );
}
