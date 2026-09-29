// Smoke + snapshot harness for the 151 mini-games.
//
//   flutter test test/arcade/game_snap_test.dart --dart-define=GAMES=12,13
//
// For every listed game (all when GAMES is empty) it:
//  * runs the full game with scripted pseudo-random input (taps, holds,
//    drags, swipes) and fails on any exception,
//  * writes PNG snapshots to build/snaps/gNNN_<n>.png (only when SNAPS=1 or
//    GAMES is set) so a human/agent can look at the art,
//  * prints win/lose outcomes of several autoplay runs.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/arcade/engine/audio.dart';
import 'package:hitasura_ads/arcade/engine/game_view.dart';
import 'package:hitasura_ads/arcade/engine/game.dart';

Future<void> _loadFonts() async {
  final bytes = File('assets/fonts/KosugiMaru-Regular.ttf').readAsBytesSync();
  final loader = FontLoader('KosugiMaru')..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

/// Minimal description of a game to test.
class SnapGame {
  const SnapGame(this.no, this.duration, this.create);
  final int no;
  final double duration;
  final MiniGame Function() create;
}

/// Scripted "monkey" player: mixes taps, long holds, drags and swipes.
class _Monkey {
  _Monkey(int seed) : r = math.Random(seed);
  final math.Random r;
  double _next = 0;
  double _holdEnd = -1;
  ui.Offset _pos = const ui.Offset(180, 400);
  ui.Offset _vel = ui.Offset.zero;

  void step(GameSession s, double t, double dt) {
    if (_holdEnd > 0) {
      _pos += _vel * dt;
      _pos = ui.Offset(_pos.dx.clamp(5, 355), _pos.dy.clamp(40, 635));
      s.move(_pos);
      if (t >= _holdEnd) {
        s.up(_pos);
        _holdEnd = -1;
        _next = t + r.nextDouble() * .25;
      }
      return;
    }
    if (t < _next) return;
    _pos = ui.Offset(20 + r.nextDouble() * 320, 80 + r.nextDouble() * 540);
    s.down(_pos);
    final kind = r.nextInt(10);
    if (kind < 5) {
      _holdEnd = t + .05; // tap
      _vel = ui.Offset.zero;
    } else if (kind < 7) {
      _holdEnd = t + .3 + r.nextDouble() * .9; // hold / slow drag
      _vel = ui.Offset((r.nextDouble() - .5) * 300, (r.nextDouble() - .5) * 300);
    } else {
      _holdEnd = t + .12; // swipe
      _vel = ui.Offset((r.nextDouble() - .5) * 2400, (r.nextDouble() - .5) * 2400);
    }
    if (r.nextInt(6) == 0) {
      const keys = ['left', 'right', 'up', 'down', 'action'];
      final k = keys[r.nextInt(keys.length)];
      s.key(k, true);
      s.key(k, false);
    }
  }
}

Future<void> _snap(GameSession s, String path) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  s.render(c);
  final pic = rec.endRecording();
  final img = await pic.toImage(360, 640);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void runSnapTests(List<SnapGame> games, {bool writeSnaps = true}) {

  testWidgets('arcade games run without errors', (tester) async {
    await tester.runAsync(() async {
      await _loadFonts();
      final failures = <String>[];
      for (final spec in games) {
        final outcomes = <String>[];
        for (var run = 0; run < 3; run++) {
          GameSession? session;
          try {
            session = GameSession(
              game: spec.create(),
              duration: spec.duration,
              verb: 'GO!',
              hook: 'Hook text for snapshot',
              seed: 100 + run,
              audio: SilentAudio(),
            );
            final monkey = _Monkey(spec.no * 31 + run);
            const dt = 1 / 60;
            var t = 0.0;
            final shots = <double>[1.5, 3.2, spec.duration * .5 + 1.1, spec.duration * .85 + 1.1];
            var shot = 0;
            while (session.phase != SessionPhase.done && t < spec.duration + 6) {
              if (session.acceptsInput) monkey.step(session, t, dt);
              session.tick(dt);
              t += dt;
              if (writeSnaps && run == 0 && shot < shots.length && t >= shots[shot]) {
                await _snap(session, 'build/snaps/g${spec.no.toString().padLeft(3, '0')}_$shot.png');
                shot++;
              }
              // Rendering every few frames catches paint-time exceptions.
              if ((t * 60).round() % 7 == 0) {
                final rec = ui.PictureRecorder();
                session.render(ui.Canvas(rec));
                rec.endRecording().dispose();
              }
            }
            if (writeSnaps && run == 0) {
              await _snap(session, 'build/snaps/g${spec.no.toString().padLeft(3, '0')}_end.png');
            }
            outcomes.add(session.phase == SessionPhase.done
                ? (session.won ? 'WIN(${session.stars})' : 'lose')
                : 'NOT-FINISHED');
            if (session.phase != SessionPhase.done) {
              failures.add('No.${spec.no}: did not finish');
            }
          } catch (e, st) {
            failures.add('No.${spec.no}: $e\n${st.toString().split('\n').take(8).join('\n')}');
            outcomes.add('ERROR');
            break;
          }
        }
        // ignore: avoid_print
        print('No.${spec.no.toString().padLeft(3, '0')} ${outcomes.join(' ')}');
      }
      if (failures.isNotEmpty) fail(failures.join('\n\n'));
    });
  }, timeout: const Timeout(Duration(minutes: 30)));
}
