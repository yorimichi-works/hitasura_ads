// Read-only observations for the debug capture harness, never shipping state.
import 'package:hitasura_ads/arcade/engine/game_view.dart';
import 'package:hitasura_ads/arcade/games/g001.dart';
import 'package:hitasura_ads/arcade/games/g003.dart';
import 'package:hitasura_ads/arcade/games/g008.dart';
import 'package:hitasura_ads/arcade/games/g018.dart';

const captureGameNumbers = {'pin': 1, 'runner': 18, 'liquid': 3, 'fruit': 8};

Map<String, Object?> captureGameObservation(
  GameSession? current,
  GameSession prepared,
  String? sceneRequestId,
) => {
  'scene_request_id': sceneRequestId,
  'game_view_mounted': current != null,
  'same_game_session': identical(current, prepared),
  'game_no': switch (current?.game) {
    G001() => 1,
    G003() => 3,
    G008() => 8,
    G018() => 18,
    _ => null,
  },
  'phase': current?.phase.name ?? 'absent',
  'game_time': current?.time,
  'time_left': current?.timeLeft,
};
