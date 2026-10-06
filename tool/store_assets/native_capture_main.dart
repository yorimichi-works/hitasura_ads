// Debug-only iOS simulator capture entry point; never used by release main.dart.
// Displays unchanged production screens with a local, seeded progress fixture.
// Host writes a fixed app-owned request file; native debug channel attests simulator.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'capture_request.dart';
import 'capture_gameplay.dart';
import 'capture_scene.dart';

import 'package:hitasura_ads/app.dart';
import 'package:hitasura_ads/arcade/registry.dart';
import 'package:hitasura_ads/arcade/engine/game_view.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/l10n/l10n.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';
import 'package:hitasura_ads/state/app_controller.dart';
import 'package:hitasura_ads/ui/ad_player.dart';
import 'package:hitasura_ads/ui/collection.dart';
import 'package:hitasura_ads/ui/rush.dart';
import 'package:hitasura_ads/ui/settings.dart';

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
  String? path;
  CaptureRequest? request;
  CaptureCommand? command;
  bool nativeSimulatorAttested = false;
  String? get launchId => command?.sessionId ?? request?.launchId;
  bool failed = false;

  void stage(String value, [Map<String, Object?> details = const {}]) {
    if (failed && value != 'error') return;
    if (value == 'error') failed = true;
    final data = <String, Object?>{
      'stage': value,
      'launch_id': launchId,
      if (command != null) 'session_id': command!.sessionId,
      if (command != null) 'request_id': command!.requestId,
      if (command != null) 'action': command!.action,
      'locale': command?.locale ?? request?.locale,
      'requested_scene': command?.scene ?? request?.scene,
      'native_simulator_attested': nativeSimulatorAttested,
      'request_transport': command == null
          ? 'app_documents_json_v1'
          : 'app_documents_json_v2',
      'debug_mode': kDebugMode,
      'is_ios': Platform.isIOS,
      'at': DateTime.now().toUtc().toIso8601String(),
      'capture_target': 'tool/store_assets/native_capture_main.dart',
      ...details,
    };
    final json = jsonEncode(data);
    // Only validated capture fields are logged; no environment values are read.
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
  if (!kDebugMode || !Platform.isIOS) {
    throw StateError('Capture harness only runs on an iOS debug simulator.');
  }
  report.stage('native_transport_start');
  const bridge = MethodChannel('hitasura_ads/simulator_capture');
  final response = await bridge
      .invokeMethod<Object?>('documentsDirectory')
      .timeout(const Duration(seconds: 10));
  final documents = captureDocumentsPath(response);
  report.nativeSimulatorAttested = true;
  final captureDirectory = Directory('$documents/HitasuraCapture');
  report.path = '${captureDirectory.path}/state.json';
  report.stage('native_transport_ready');
  final requestFile = File('${captureDirectory.path}/request.json');
  if (requestFile.lengthSync() > 4096) {
    throw const FormatException('Capture request exceeds 4096 bytes');
  }
  var lastRequestBytes = requestFile.readAsStringSync();
  final initial = jsonDecode(lastRequestBytes);
  if (initial is Map && initial['schema_version'] == 2) {
    report.command = CaptureCommand.parse(initial);
  } else {
    report.request = CaptureRequest.parse(initial);
  }
  final firstCommand = report.command;
  final sessionGuard = firstCommand == null
      ? null
      : CaptureSessionGuard(firstCommand.sessionId, firstCommand.locale);
  if (firstCommand != null) sessionGuard!.accept(firstCommand);
  report.stage('request_loaded', {
    'created_at': (firstCommand?.createdAt ?? report.request!.createdAt)
        .toIso8601String(),
  });
  final code = firstCommand?.locale ?? report.request!.locale;
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

  GlobalKey? routeKey;
  Future<void> show(String target) async {
    final context = appKey.currentContext;
    if (context == null) throw StateError('App did not mount');
    findNavigator(context as Element);
    final nav = navigator;
    if (nav == null) throw StateError('App navigator missing');
    nav.popUntil((r) => r.isFirst);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    routeKey = null;
    if (target == 'home') return;
    routeKey = GlobalKey();
    final Widget screen = switch (target) {
      'collection' => CollectionScreen(key: routeKey, controller: controller),
      'rush' => RushScreen(key: routeKey, controller: controller),
      'settings' => SettingsScreen(
        key: routeKey,
        controller: controller,
        rewardedAdService: _NoAds(),
      ),
      _ => AdPlayerScreen(
        key: routeKey,
        controller: controller,
        first: allGames.firstWhere(
          (g) =>
              g.no ==
              switch (target) {
                'pin' => 1,
                'liquid' => 3,
                'fruit' => 8,
                _ => 18,
              },
        ),
        roulette: false,
        replayMode: true,
      ),
    };
    unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => screen)));
  }

  (GameView, Element) currentGame() {
    final root = routeKey?.currentContext;
    if (root == null ||
        ModalRoute.of(root)?.isCurrent != true ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      throw StateError('Game route is not current');
    }
    (GameView, Element)? found;
    void visit(Element element) {
      if (element.widget case final GameView view) found = (view, element);
      element.visitChildElements(visit);
    }

    visit(root as Element);
    if (found == null) throw StateError('GameView is not mounted');
    return found!;
  }

  GameSession? preparedGame;
  String? sceneRequestId;

  Future<void> showReady(String scene) async {
    report.stage('scene_start');
    preparedGame = null;
    sceneRequestId = null;
    final target = scene == 'preview' ? 'runner' : scene;
    await show(target);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final details = <String, Object?>{};
    if (captureGameNumbers.containsKey(target)) {
      final deadline = DateTime.now().add(const Duration(seconds: 12));
      while (DateTime.now().isBefore(deadline)) {
        GameSession? session;
        try {
          session = currentGame().$1.session;
        } on StateError {
          /* The production title card has not mounted a GameView yet. */
        }
        if (session != null && session.phase == SessionPhase.play) {
          // A pre-frame observation can age into an ending while awaiting paint.
          await WidgetsBinding.instance.endOfFrame.timeout(
            const Duration(seconds: 5),
          );
          final current = currentGame().$1.session;
          final observation = captureGameObservation(
            current,
            session,
            report.command?.requestId,
          );
          if (observation['same_game_session'] != true ||
              observation['game_no'] != captureGameNumbers[target]) {
            throw StateError('Prepared gameplay identity changed');
          }
          if (current.phase == SessionPhase.play) {
            preparedGame = current;
            sceneRequestId = report.command?.requestId;
            details.addAll(observation);
            break;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      if (preparedGame == null) {
        throw StateError('Actual gameplay did not become active');
      }
    } else {
      await WidgetsBinding.instance.endOfFrame.timeout(
        const Duration(seconds: 30),
      );
    }
    report.stage('ready', {
      'locale': L10n.code,
      'active_scene': target,
      'ready_at': DateTime.now().toUtc().toIso8601String(),
      ...details,
    });
  }

  Future<void> inspectGame(String scene) async {
    final prepared = preparedGame;
    if (prepared == null || sceneRequestId == null) {
      throw StateError('Inspection requires a prepared gameplay session');
    }
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 5),
    );
    GameSession? current;
    try {
      current = currentGame().$1.session;
    } on StateError {
      /* A real result page has no GameView: report absence, never stale play. */
    }
    report.stage('inspected', {
      'active_scene': current == null ? null : scene,
      ...captureGameObservation(current, prepared, sceneRequestId),
    });
  }

  Future<void> playRecorded(String scene) async {
    final (view, element) = currentGame();
    final session = view.session;
    final gameNo = scene == 'liquid' ? 3 : 8;
    if (session.phase != SessionPhase.play || session.timeLeft < 10.5) {
      throw StateError(
        'Recorder arrived too late for ten seconds of active gameplay',
      );
    }
    final startGameTime = session.time;
    final startedAt = DateTime.now().toUtc();
    final clock = Stopwatch()..start();
    final inputs = <Map<String, Object?>>[];
    final steps = captureInputPlan(gameNo);
    var next = 0;
    Offset? previous;
    report.stage('gameplay_started', {
      'active_scene': scene,
      'game_no': gameNo,
      'phase': session.phase.name,
      'game_time': startGameTime,
      'started_at': startedAt.toIso8601String(),
      'duration_seconds': 10,
      'input_method': 'flutter_gesture_binding_pointer_events',
      'random_seed': 'shipping_time_seed_unmodified',
    });
    while (clock.elapsedMicroseconds < 10000000) {
      if (report.failed || session.phase != SessionPhase.play) {
        throw StateError(
          'Gameplay ended or failed before the full native segment',
        );
      }
      final elapsed = clock.elapsedMicroseconds / 1e6;
      while (next < steps.length && steps[next].at <= elapsed) {
        final step = steps[next++];
        final box = element.findRenderObject();
        if (box is! RenderBox || !box.hasSize) {
          throw StateError('Actual GameView has no sized render box');
        }
        final global = captureGlobalPoint(box, step.point);
        dispatchCapturePointer(
          step,
          global,
          clock.elapsed,
          delta: step.kind == 'move' && previous != null
              ? global - previous
              : Offset.zero,
        );
        previous = global;
        final event = <String, Object?>{
          'kind': step.kind,
          'pointer': step.pointer,
          'virtual_xy': [step.point.dx, step.point.dy],
          'global_logical_xy': [global.dx, global.dy],
          'scheduled_seconds': step.at,
          'actual_elapsed_seconds': elapsed,
          'game_time': session.time,
        };
        inputs.add(event);
        report.stage('pointer_input', event);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (session.phase != SessionPhase.play ||
        session.time - startGameTime < 8) {
      throw StateError(
        'Native segment did not preserve sufficient active game time',
      );
    }
    report.stage('gameplay_complete', {
      'active_scene': scene,
      'game_no': gameNo,
      'phase': session.phase.name,
      'started_at': startedAt.toIso8601String(),
      'completed_at': DateTime.now().toUtc().toIso8601String(),
      'elapsed_seconds': clock.elapsedMicroseconds / 1e6,
      'game_time_start': startGameTime,
      'game_time_end': session.time,
      'score_observed': session.score,
      'input_events': inputs,
      'input_method': 'flutter_gesture_binding_pointer_events',
      'random_seed': 'shipping_time_seed_unmodified',
    });
  }

  await showReady(firstCommand?.scene ?? report.request!.scene);
  if (firstCommand == null) return;
  final deadline = DateTime.now().add(const Duration(minutes: 8));
  while (DateTime.now().isBefore(deadline) && !report.failed) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (requestFile.lengthSync() > 4096) {
      throw const FormatException('Capture request exceeds 4096 bytes');
    }
    final bytes = requestFile.readAsStringSync();
    if (bytes == lastRequestBytes) continue;
    final command = CaptureCommand.parse(jsonDecode(bytes));
    sessionGuard!.accept(command);
    lastRequestBytes = bytes;
    report.command = command;
    report.stage('command_loaded');
    if (command.action == 'stop') {
      report.stage('stopped');
      return;
    }
    if (command.action == 'show') {
      await showReady(command.scene);
    } else if (command.action == 'inspect') {
      await inspectGame(command.scene);
    } else {
      await playRecorded(command.scene);
    }
  }
  if (!report.failed) {
    throw StateError('Capture session exceeded eight minutes');
  }
}
