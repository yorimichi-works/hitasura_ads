import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/arcade/engine/audio.dart';
import 'package:hitasura_ads/arcade/engine/game_view.dart';
import 'package:hitasura_ads/arcade/registry.dart';

import '../tool/store_assets/capture_scene.dart';

void main() {
  GameSession create(int number) {
    final spec = allGames.firstWhere((game) => game.no == number);
    return GameSession(
      game: spec.create(),
      duration: spec.duration,
      verb: '',
      audio: SilentAudio(),
      seed: 1, // Determinism is confined to this test, never capture execution.
    );
  }

  test('observations identify actual game types without advancing them', () {
    for (final number in captureGameNumbers.values) {
      final current = create(number);
      final observation = captureGameObservation(current, current, 'show-id');
      expect(observation['game_no'], number);
      expect(observation['phase'], 'intro');
      expect(observation['same_game_session'], isTrue);
      expect(observation['game_view_mounted'], isTrue);
      expect(observation['scene_request_id'], 'show-id');
      expect(current.phase, SessionPhase.intro);
      expect(current.time, 0);
    }
  });

  test('play and ending observations follow the unchanged real session', () {
    final current = create(18);
    for (var i = 0; i < 70; i++) {
      current.tick(1 / 60);
    }
    final time = current.time;
    expect(captureGameObservation(current, current, 'id')['phase'], 'play');
    expect(current.time, time);
    current.lose(); // Exercise a real terminal transition in the unit test.
    expect(captureGameObservation(current, current, 'id')['phase'], 'ending');
    for (var i = 0; i < 100; i++) {
      current.tick(1 / 60);
    }
    expect(captureGameObservation(current, current, 'id')['phase'], 'done');
  });

  test('a second same-type session never inherits the prepared identity', () {
    final prepared = create(18);
    final current = create(18);
    final observation = captureGameObservation(current, prepared, 'show-id');
    expect(observation['game_no'], 18);
    expect(observation['same_game_session'], isFalse);
  });

  test('wrong game and absent GameView cannot report requested gameplay', () {
    final prepared = create(18);
    final wrong = captureGameObservation(create(1), prepared, 'show-id');
    expect(wrong['game_no'], 1);
    expect(wrong['same_game_session'], isFalse);
    final absent = captureGameObservation(null, prepared, 'show-id');
    expect(absent['game_view_mounted'], isFalse);
    expect(absent['same_game_session'], isFalse);
    expect(absent['phase'], 'absent');
    expect(absent['game_no'], isNull);
    expect(absent['game_time'], isNull);
  });
}
