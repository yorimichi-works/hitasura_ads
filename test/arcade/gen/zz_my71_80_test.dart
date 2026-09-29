// TEMP test by agent for games 71-80 (deleted after use).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/arcade/engine/audio.dart';
import 'package:hitasura_ads/arcade/engine/game_view.dart';
import 'package:hitasura_ads/arcade/engine/game.dart';
import 'package:hitasura_ads/arcade/games/g071.dart';
import 'package:hitasura_ads/arcade/games/g072.dart';
import 'package:hitasura_ads/arcade/games/g073.dart';
import 'package:hitasura_ads/arcade/games/g074.dart';
import 'package:hitasura_ads/arcade/games/g075.dart';
import 'package:hitasura_ads/arcade/games/g076.dart';
import 'package:hitasura_ads/arcade/games/g077.dart';
import 'package:hitasura_ads/arcade/games/g078.dart';
import 'package:hitasura_ads/arcade/games/g079.dart';
import 'package:hitasura_ads/arcade/games/g080.dart';

typedef Bot = void Function(GameSession s, double t, int frame);

Future<void> _snap(GameSession s, String path) async {
  final rec = ui.PictureRecorder();
  s.render(ui.Canvas(rec));
  final img = await rec.endRecording().toImage(360, 640);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

Future<String> run(String name, MiniGame g, double dur, Bot bot, List<double> shots, {double speed = 1, int seed = 100}) async {
  final s = GameSession(game: g, duration: dur, verb: 'GO!', hook: 'x', seed: seed, audio: SilentAudio(), speed: speed);
  const dt = 1 / 60;
  var t = 0.0;
  var f = 0;
  var shot = 0;
  while (s.phase != SessionPhase.done && t < dur + 6) {
    if (s.acceptsInput) bot(s, s.time, f);
    s.tick(dt);
    t += dt;
    f++;
    if (shot < shots.length && t >= shots[shot]) {
      await _snap(s, 'build/snaps/zz_$name\_$shot.png');
      shot++;
    }
  }
  return s.won ? 'WIN(${s.stars})' : 'lose';
}

void idle(GameSession s, double t, int f) {}

void main() {
  testWidgets('mine', (tester) async {
    await tester.runAsync(() async {
      final bytes = File('assets/fonts/KosugiMaru-Regular.ttf').readAsBytesSync();
      final loader = FontLoader('KosugiMaru')..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      final out = <String>[];
      final idles = <String, MiniGame Function()>{
        '071': G071.new, '072': G072.new, '073': G073.new, '074': G074.new, '075': G075.new,
        '076': G076.new, '077': G077.new, '078': G078.new, '079': G079.new, '080': G080.new,
      };
      for (final e in idles.entries) {
        out.add('${e.key} idle ${await run('${e.key}i', e.value(), 6, idle, [2.2, 3.4])}');
      }
      // 074: swipe each row
      void wrap(GameSession s, double t, int f) {
        final row = (f ~/ 12);
        final k = f % 12;
        final y = 170.0 + (row % 7) * 64;
        if (k == 0) s.down(ui.Offset(10, y));
        if (k > 0 && k < 10) s.move(ui.Offset(10 + k * 38.0, y));
        if (k == 10) s.up(ui.Offset(350, y));
      }
      out.add('074 bot ${await run('074b', G074(), 6, wrap, [2.4, 4.0])}');
      // 077: scrub back and forth across both rows
      void scrub(GameSession s, double t, int f) {
        final y = (f ~/ 60).isEven ? 232.0 : 440.0;
        final x = 180 + 140 * ui.lerpDouble(-1, 1, ((f % 20) / 20 - .5).abs() * 2)!;
        if (f == 0) s.down(ui.Offset(x, y));
        s.move(ui.Offset(x, y + (f % 7) * 4 - 12));
      }
      out.add('077 bot ${await run('077b', G077(), 5, scrub, [2.4, 3.6])}');
      // 079: mash 7/s, swipe near suitcase
      void train(GameSession s, double t, int f) {
        if (f % 9 == 0) s.down(const ui.Offset(180, 500));
        if (f % 9 == 2) s.up(const ui.Offset(180, 500));
        if (f == 60) {
          s.down(const ui.Offset(180, 500));
          s.move(const ui.Offset(180, 440));
          s.up(const ui.Offset(180, 440));
        }
      }
      for (var f0 = 40; f0 <= 90; f0 += 10) {
        void trainAt(GameSession s, double t, int f) {
          if (f % 9 == 0) s.down(const ui.Offset(180, 500));
          if (f % 9 == 2) s.up(const ui.Offset(180, 500));
          if (f == f0) {
            s.down(const ui.Offset(180, 500));
            s.move(const ui.Offset(180, 440));
            s.up(const ui.Offset(180, 440));
          }
        }
        out.add('079 jump@$f0 ${await run('079j', G079(), 6, trainAt, [])}');
      }
      out.add('079 bot ${await run('079b', G079(), 6, train, [2.0, 3.0])}');
      // print
      // ignore: avoid_print
      print(out.join('\n'));
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
