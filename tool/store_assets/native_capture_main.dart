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

class _CaptureReporter {
  final String? path = Platform.environment['HITASURA_CAPTURE_STATE_PATH'];
  final String? launchId = Platform.environment['HITASURA_CAPTURE_ID'];
  bool failed = false;

  void stage(String value, [Map<String, Object?> details = const {}]) {
    if (failed && value != 'error') return;
    if (value == 'error') failed = true;
    final data = <String, Object?>{
      'stage': value,
      'launch_id': launchId,
      'locale': Platform.environment['HITASURA_CAPTURE_LOCALE'],
      'requested_scene': Platform.environment['HITASURA_CAPTURE_SCENE'],
      'simulator': Platform.environment['SIMULATOR_DEVICE_NAME'],
      'debug_mode': kDebugMode,
      'is_ios': Platform.isIOS,
      'at': DateTime.now().toUtc().toIso8601String(),
      'capture_target': 'tool/store_assets/native_capture_main.dart',
      ...details,
    };
    final json = jsonEncode(data);
    // Only capture-specific environment values are logged, never all env vars.
    stdout.writeln('HITASURA_CAPTURE $json');
    if (path != null) {
      final file = File(path!);
      file.parent.createSync(recursive: true);
      final pending = File('$path.pending');
      pending.writeAsStringSync(json, flush: true);
      pending.renameSync(path!);
      File('$path.events.jsonl')
          .writeAsStringSync('$json\n', mode: FileMode.append, flush: true);
    }
  }
}

Future<void> main() async {
  final report = _CaptureReporter();
  report.stage('dart_started');
  FlutterError.onError = (details) {
    report.stage('error', {'error': details.exceptionAsString()});
    FlutterError.dumpErrorToConsole(details);
  };
  try {
    await _capture(report);
  } catch (error, stack) {
    report.stage('error', {'error': '$error', 'stack': '$stack'});
    rethrow;
  }
}

Future<void> _capture(_CaptureReporter report) async {
  WidgetsFlutterBinding.ensureInitialized();
  report.stage('binding_initialized');
  if (report.path == null || report.launchId == null) {
    throw StateError('Missing capture state path or launch ID environment');
  }
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
  report.stage('controller_start');
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
  report.stage('controller_ready');
  final appKey = GlobalKey();
  runApp(
    HitasuraAdsApp(
      key: appKey,
      controller: controller,
      rewardedAdService: _NoAds(),
    ),
  );
  report.stage('run_app_requested');
  await WidgetsBinding.instance.endOfFrame.timeout(const Duration(seconds: 30));
  report.stage('first_frame');
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

  report.stage('scene_start');
  if (scene == 'preview') {
    // Continuous native runner recording, beginning about 3s after launch.
    // Production timing, game loop, HUD, and result screen remain unchanged.
    await show('runner');
  } else {
    await show(scene);
  }
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await WidgetsBinding.instance.endOfFrame.timeout(const Duration(seconds: 30));
  report.stage('ready', {
    'locale': L10n.code,
    'active_scene': scene == 'preview' ? 'runner' : scene,
    'ready_at': DateTime.now().toUtc().toIso8601String(),
  });
}
