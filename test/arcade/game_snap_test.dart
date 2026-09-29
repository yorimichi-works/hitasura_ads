// Full-registry smoke test (all games, or GAMES=1,2,5-9).
//   flutter test test/arcade/game_snap_test.dart --dart-define=GAMES=12
// Agents: prefer `python tool/arcade/snap.py 12,13` which compiles only the
// listed games (robust while other games are mid-edit).
import 'package:hitasura_ads/arcade/registry.dart';

import 'snap_harness.dart';

const _games = String.fromEnvironment('GAMES');
const _snaps = bool.fromEnvironment('SNAPS');

void main() {
  final nums = <int>{};
  for (final part in _games.split(',')) {
    final p = part.trim();
    if (p.isEmpty) continue;
    if (p.contains('-')) {
      final ab = p.split('-').map(int.parse).toList();
      for (var i = ab[0]; i <= ab[1]; i++) {
        nums.add(i);
      }
    } else {
      nums.add(int.parse(p));
    }
  }
  final games = [
    for (final g in allGames)
      if (nums.isEmpty || nums.contains(g.no)) SnapGame(g.no, g.duration, g.create),
  ];
  runSnapTests(games, writeSnaps: _snaps || nums.isNotEmpty);
}
