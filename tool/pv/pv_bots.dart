// Scripted players + audio recorder shared by the PV scout and renderer.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:hitasura_ads/arcade/engine/audio.dart';
import 'package:hitasura_ads/arcade/engine/game_view.dart';

/// One recorded sound effect (time in seconds of the session's real clock).
class SfxEvent {
  SfxEvent(this.t, this.name, this.volume, this.rate);
  final double t;
  final String name;
  final double volume;
  final double rate;
}

/// Records sfx calls instead of playing them.
class RecordingAudio implements ArcadeAudio {
  double now = 0;
  final events = <SfxEvent>[];
  @override
  bool muted = false;
  @override
  void preload(Iterable<String> sfxNames) {}
  @override
  void sfx(String name, {double volume = 1, double rate = 1}) => events.add(SfxEvent(now, name, volume, rate));
  @override
  void bgm(String name) {}
  @override
  void stopBgm({double fade = .4}) {}
  @override
  void setBgmVolume(double v) {}
}

/// Input strategies. Kinds: 0 monkey mix, 1 tap spam, 2 hold + wander,
/// 3 lane swiper, 4 slow precise taps, 5 hold-release rhythm.
class Bot {
  Bot(this.kind, int seed) : r = math.Random(seed);
  final int kind;
  final math.Random r;
  double _next = 0;
  double _holdEnd = -1;
  ui.Offset _pos = const ui.Offset(180, 400);
  ui.Offset _vel = ui.Offset.zero;

  /// Last pointer position and whether it is held (for the touch overlay).
  ui.Offset get pos => _pos;
  bool get holding => _holdEnd > 0;

  /// Time of the most recent press (for tap ripples).
  double lastPress = -10;

  static const kinds = 6;

  void step(GameSession s, double t, double dt) {
    if (_holdEnd > 0) {
      _pos += _vel * dt;
      if (kind == 2) {
        _vel = ui.Offset(_vel.dx + (r.nextDouble() - .5) * 1600 * dt, _vel.dy + (r.nextDouble() - .5) * 800 * dt);
      }
      _pos = ui.Offset(_pos.dx.clamp(10, 350), _pos.dy.clamp(60, 630));
      s.move(_pos);
      if (t >= _holdEnd) {
        s.up(_pos);
        _holdEnd = -1;
        _next = t + _gap();
      }
      return;
    }
    if (t < _next) return;
    switch (kind) {
      case 1:
        _pos = ui.Offset(60 + r.nextDouble() * 240, 160 + r.nextDouble() * 400);
        _press(s, t, .04, ui.Offset.zero);
      case 2:
        _pos = ui.Offset(180 + (r.nextDouble() - .5) * 120, 480 + (r.nextDouble() - .5) * 120);
        _press(s, t, 1.5 + r.nextDouble() * 2.5, ui.Offset((r.nextDouble() - .5) * 200, (r.nextDouble() - .5) * 60));
      case 3:
        _pos = ui.Offset(180, 450 + (r.nextDouble() - .5) * 120);
        final dir = r.nextInt(4);
        const v = 1800.0;
        _press(s, t, .1,
            [const ui.Offset(-v, 0), const ui.Offset(v, 0), const ui.Offset(0, -v), const ui.Offset(0, v)][dir]);
        if (r.nextInt(3) == 0) {
          final k = ['left', 'right', 'up', 'down', 'action'][dir == 0 ? 0 : dir == 1 ? 1 : dir == 2 ? 2 : 4];
          s.key(k, true);
          s.key(k, false);
        }
      case 4:
        _pos = ui.Offset(30 + r.nextDouble() * 300, 90 + r.nextDouble() * 520);
        _press(s, t, .06, ui.Offset.zero);
      case 5:
        _pos = ui.Offset(180 + (r.nextDouble() - .5) * 60, 420 + (r.nextDouble() - .5) * 60);
        _press(s, t, .25 + r.nextDouble() * .8, ui.Offset.zero);
      default:
        _pos = ui.Offset(20 + r.nextDouble() * 320, 80 + r.nextDouble() * 540);
        final k = r.nextInt(10);
        if (k < 5) {
          _press(s, t, .05, ui.Offset.zero);
        } else if (k < 7) {
          _press(s, t, .3 + r.nextDouble() * .9, ui.Offset((r.nextDouble() - .5) * 300, (r.nextDouble() - .5) * 300));
        } else {
          _press(s, t, .12, ui.Offset((r.nextDouble() - .5) * 2400, (r.nextDouble() - .5) * 2400));
        }
        if (r.nextInt(6) == 0) {
          const keys = ['left', 'right', 'up', 'down', 'action'];
          final kk = keys[r.nextInt(keys.length)];
          s.key(kk, true);
          s.key(kk, false);
        }
    }
  }

  void _press(GameSession s, double t, double hold, ui.Offset vel) {
    s.down(_pos);
    lastPress = t;
    _holdEnd = t + hold;
    _vel = vel;
  }

  double _gap() => switch (kind) {
        1 => .08 + r.nextDouble() * .08,
        2 => .1 + r.nextDouble() * .2,
        3 => .25 + r.nextDouble() * .35,
        4 => .5 + r.nextDouble() * .7,
        5 => .2 + r.nextDouble() * .5,
        _ => r.nextDouble() * .25,
      };
}
