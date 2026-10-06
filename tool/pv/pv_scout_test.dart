// Finds bot/seed combos that WIN each game (for PV clip selection).
//   flutter test tool/pv/pv_scout_test.dart [--dart-define=GAMES=1,2]
// → build/pv/scout.json
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/arcade/engine/game_view.dart';
import 'package:hitasura_ads/arcade/registry.dart';

import 'pv_bots.dart';

const _games = String.fromEnvironment('GAMES');
const _seeds = int.fromEnvironment('SEEDS', defaultValue: 4);

void main() {
  test('scout', () {
    final want = _games.isEmpty ? null : _games.split(',').map(int.parse).toSet();
    final out = <String, Object>{};
    for (final g in allGames) {
      if (want != null && !want.contains(g.no)) continue;
      final runs = <Map<String, Object>>[];
      for (var kind = 0; kind < Bot.kinds; kind++) {
        for (var seed = 0; seed < _seeds; seed++) {
          try {
            final audio = RecordingAudio();
            final s = GameSession(
                game: g.create(), duration: g.duration, verb: 'GO', hook: 'x', seed: 1000 + seed, audio: audio);
            final bot = Bot(kind, seed * 7 + g.no);
            const dt = 1 / 30;
            var t = 0.0;
            double? endAt;
            while (s.phase != SessionPhase.done && t < g.duration + 5) {
              if (s.acceptsInput) bot.step(s, t, dt);
              audio.now = t;
              s.tick(dt);
              t += dt;
              if (endAt == null && s.finished) endAt = t;
            }
            runs.add({
              'kind': kind,
              'seed': seed,
              'won': s.won,
              'stars': s.stars,
              'end': double.parse((endAt ?? -1).toStringAsFixed(2)),
              'sfx': audio.events.length,
            });
          } catch (e) {
            runs.add({'kind': kind, 'seed': seed, 'error': '$e'});
          }
        }
      }
      final wins = runs.where((r) => r['won'] == true).length;
      // ignore: avoid_print
      print('No.${g.no} wins $wins/${runs.length}');
      out['${g.no}'] = runs;
    }
    File('build/pv/scout.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  }, timeout: const Timeout(Duration(minutes: 60)));
}
