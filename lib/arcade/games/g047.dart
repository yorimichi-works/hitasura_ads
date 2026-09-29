import '../engine/engine.dart';

/// No.047 Stop at 10.00 — blind stopwatch showdown vs the party.
class G047 extends MiniGame {
  static const _target = 10.0;
  static const _hideAt = 3.0;
  final _stopT = List<double>.filled(4, -1); // stopped clock value (-1 = running)
  final _cpuPlan = List<double>.filled(4, 0);
  final _press = List<double>.filled(4, 0);
  double _t = 0;
  double _clock = 0;
  int _lastSec = 0;
  double _beatT = 1.2;
  // reveal
  bool _revealing = false;
  double _revT = 0;
  int _shown = 0;
  bool _resolved = false;
  bool _won = false;
  List<int> _rank = const [0, 1, 2, 3];
  double _crown = 0;

  @override
  void init() {
    // CPU personalities: Red is late & greedy, Green is cocky-good, Yellow is chaotic.
    _cpuPlan[1] = _target + (chance(.7) ? rand(.12, .45) : -rand(.15, .4));
    _cpuPlan[2] = _target + (chance(.5) ? 1 : -1) * rand(.07, .28);
    _cpuPlan[3] = _target + (chance(.5) ? 1 : -1) * rand(.2, .65);
  }

  bool get _allStopped => !_stopT.contains(-1);

  void _stop(int i) {
    if (_stopT[i] >= 0) return;
    _stopT[i] = _clock;
    _press[i] = 1;
    if (i == 0) {
      host.sfx(Sfx.click);
      host.sfx(Sfx.stamp, volume: .7);
      host.shake(4);
      host.punch(.03);
      host.fx.ring(const Offset(180, 250), Pal.white, size: 110);
      host.fx.burst(_btnCenter(0), _Cast.col[0], count: 14, speed: 200, shape: PartShape.star);
    } else {
      host.sfx(Sfx.click, volume: .6, rate: 1.1 + i * .1);
      host.fx.pop('!', _charPos(i) + const Offset(0, -70), color: _Cast.col[i], size: 26);
    }
  }

  @override
  void onDown(Offset p) {
    if (_revealing || _stopT[0] >= 0) return;
    _stop(0);
  }

  @override
  void onKey(String key, bool down) {
    if (down) onDown(Offset.zero);
  }

  Offset _charPos(int i) => Offset(52 + i * 85.0, 505);
  Offset _btnCenter(int i) => Offset(52 + i * 85.0, 536);

  @override
  void update(double dt) {
    _t += dt;
    for (var i = 0; i < 4; i++) {
      _press[i] = M.approach(_press[i], 0, 5, dt);
    }
    _crown = M.approach(_crown, _resolved ? 1 : 0, 6, dt);
    if (!_revealing) {
      _clock = _t;
      final sec = _clock.floor();
      if (sec != _lastSec) {
        _lastSec = sec;
        if (_clock < _hideAt) host.sfx(Sfx.tick, volume: .7);
      }
      if (_clock > _hideAt) {
        _beatT -= dt;
        if (_beatT <= 0) {
          _beatT = 1.37;
          host.sfx(Sfx.heartbeat, volume: .35);
        }
      }
      for (var i = 1; i < 4; i++) {
        if (_stopT[i] < 0 && _clock >= _cpuPlan[i]) _stop(i);
      }
      if (_stopT[0] < 0 && _clock > 12.3) {
        _stop(0); // fell asleep
        host.sfx(Sfx.oops);
      }
      if (_allStopped && _stopT[0] >= 0) {
        _revealing = true;
        host.sfx(Sfx.drumroll);
      }
    } else {
      _revT += dt;
      const drum = 1.1, gap = .28;
      final want = ((_revT - drum) / gap).floor() + 1;
      while (_shown < min(4, want)) {
        final i = _revealOrder[_shown];
        _shown++;
        host.sfx(Sfx.flip, rate: .9 + _shown * .1);
        host.fx.burst(_charPos(i) + const Offset(0, -110), _Cast.col[i], count: 10, speed: 150);
      }
      if (!_resolved && _revT > drum + gap * 4 + .15) _resolve();
    }
  }

  // reveal order: CPUs first, you last (drama!)
  static const _revealOrder = [1, 2, 3, 0];

  double _err(int i) => (_stopT[i] - _target).abs();

  void _resolve() {
    _resolved = true;
    _rank = [0, 1, 2, 3]..sort((a, b) => _err(a).compareTo(_err(b)));
    final e = _err(0);
    _won = _rank.first == 0 || e <= .15;
    if (_won) {
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.cheer, volume: .8);
      host.fx.confetti(count: 90);
      host.flash(Pal.yellow, .15);
      if (e < .005) host.fx.pop('10.00!!', const Offset(180, 180), color: Pal.gold, size: 40);
      host.win(stars: e <= .03 ? 3 : (e <= .1 ? 2 : 1));
    } else {
      host.sfx(Sfx.buzzer);
      host.sfx(Sfx.aww, volume: .7);
      host.shake(6);
      host.lose();
    }
  }

  @override
  void onTimeUp() {
    if (!_resolved) {
      if (_stopT[0] < 0) _stopT[0] = _clock;
      for (var i = 1; i < 4; i++) {
        if (_stopT[i] < 0) _stopT[i] = _cpuPlan[i];
      }
      _shown = 4;
      _revealing = true;
      _resolve();
    }
  }

  String _fmt(double v) => v.toStringAsFixed(2);

  @override
  void render(Canvas c) {
    // game-show stage background
    D.gradientBg(c, const [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)]);
    D.rays(c, const Offset(180, 250), 520, const Color(0x18FFFFFF), count: 16, t: _t * .25);
    // marquee bulbs
    for (var i = 0; i < 18; i++) {
      final on = ((_t * 6).floor() + i) % 3 == 0;
      D.circle(c, Offset(10 + i * 20.0, 44), 4, on ? Pal.yellow : const Color(0x66FFE9A0));
    }
    // target plate
    D.rrect(c, const Rect.fromLTWH(110, 54, 140, 40), 12, Pal.ink, border: Pal.gold, borderWidth: 3);
    D.text(c, '10.00', const Offset(180, 75), size: 30, color: Pal.gold, stroke: Pal.ink);
    // spotlights
    final sweep = _revealing && !_resolved ? sin(_revT * 7) * 120 : 0.0;
    for (final s in [-1.0, 1.0]) {
      final tgt = Offset(180 + sweep * s, 520);
      final p = Path()
        ..moveTo(180 + s * 170, 36)
        ..lineTo(tgt.dx - 60, tgt.dy)
        ..lineTo(tgt.dx + 60, tgt.dy)
        ..close();
      c.drawPath(p, D.fill(const Color(0x14FFFFFF)));
    }
    _renderWatch(c);
    _renderStage(c);
    if (!_revealing && _stopT[0] < 0 && _t < 2.5) {
      D.hand(c, _btnCenter(0) + const Offset(0, 6), _t);
    }
  }

  void _renderWatch(Canvas c) {
    const o = Offset(180, 250);
    const r = 112.0;
    final pr = _press[0];
    // crown + buttons
    D.rrect(c, Rect.fromCenter(center: Offset(180, o.dy - r - 14 + pr * 8), width: 40, height: 22), 6, const Color(0xFFD0D6E2),
        border: Pal.ink, borderWidth: 3);
    D.rrect(c, Rect.fromCenter(center: Offset(180, o.dy - r - 2), width: 22, height: 16), 4, const Color(0xFFB0B8C8),
        border: Pal.ink, borderWidth: 3);
    for (final s in [-1.0, 1.0]) {
      c.save();
      c.translate(o.dx + s * r * .74, o.dy - r * .74);
      c.rotate(s * pi / 4);
      D.rrect(c, const Rect.fromLTWH(-9, -14, 18, 16), 4, const Color(0xFFD0D6E2), border: Pal.ink, borderWidth: 3);
      c.restore();
    }
    D.shadow(c, o + const Offset(6, 12), r * 2.1, r * 2.0, .25);
    c.drawCircle(
        o,
        r + 10,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0xFFFFFFFF), Color(0xFFB7C0D4), Color(0xFF7D869E)])
              .createShader(Rect.fromCircle(center: o + const Offset(-30, -30), radius: r * 1.6)));
    c.drawCircle(o, r + 10, D.stroke(Pal.ink, 4));
    c.drawCircle(o, r - 2, D.fill(const Color(0xFFFFFDF5)));
    c.drawCircle(o, r - 2, D.stroke(Pal.ink, 3));
    for (var i = 0; i < 60; i++) {
      final a = i / 60 * pi * 2 - pi / 2;
      final big = i % 5 == 0;
      final d = Offset(cos(a), sin(a));
      D.line(c, o + d * (r - 8), o + d * (r - (big ? 22 : 14)), big ? Pal.ink : Pal.gray, big ? 3.5 : 2);
    }
    final hideK = M.clamp01((_clock - _hideAt) / .6);
    final shownFinal = _resolved;
    // sweep hand (one lap per 10s so 10.00 = top)
    if (hideK < 1 || shownFinal) {
      final v = shownFinal ? _stopT[0] : _clock;
      final a = v / 10 * pi * 2 - pi / 2;
      final alpha = shownFinal ? 1.0 : 1 - hideK;
      D.line(c, o, o + Offset(cos(a), sin(a)) * (r - 26), Color.fromRGBO(255, 59, 92, alpha), 5);
      D.circle(c, o, 9, Color.fromRGBO(27, 21, 48, alpha));
    }
    // digital readout
    final disp = shownFinal ? _stopT[0] : (_stopT[0] >= 0 && hideK <= 0 ? _stopT[0] : _clock);
    if (hideK < 1 || shownFinal) {
      final a = shownFinal ? 1.0 : 1 - hideK;
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
      final col = shownFinal ? (_won ? const Color(0xFF16A34A) : Pal.red) : Pal.ink;
      D.rrect(c, Rect.fromCenter(center: o + const Offset(0, 40), width: 150, height: 58), 12, const Color(0xFFE8F4E8),
          border: Pal.ink, borderWidth: 3);
      D.text(c, _fmt(disp), o + const Offset(0, 41), size: 44, color: col, family: null);
      c.restore();
    }
    if (hideK > 0 && !shownFinal) {
      // cover sticker with a question mark
      final wob = sin(_t * 3) * .05;
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(wob);
      c.scale(.6 + .4 * M.easeOutBack(hideK));
      final sticker = D.starPath(Offset.zero, r - 6, r - 22, points: 18, rotation: _t * .2);
      c.drawPath(sticker, D.fill(Pal.yellow));
      c.drawPath(sticker, D.stroke(Pal.ink, 4));
      D.title(c, '?', const Offset(0, -6), size: 96, color: Pal.white, scale: 1 + sin(_t * 5) * .04);
      c.restore();
      if (_stopT[0] >= 0) {
        D.text(c, host.tr('stop', 'STOP!'), o + const Offset(70, 80), size: 26, color: Pal.red, stroke: Pal.ink);
      }
    }
  }

  void _renderStage(Canvas c) {
    // stage floor
    c.drawRect(const Rect.fromLTWH(0, 520, 360, 120), D.fill(const Color(0xFF2B1B4A)));
    for (var i = 0; i < 9; i++) {
      c.drawRect(Rect.fromLTWH(i * 40.0, 520, 20, 120), D.fill(const Color(0x14FFFFFF)));
    }
    c.drawRect(const Rect.fromLTWH(0, 516, 360, 8), D.fill(Pal.gold));
    for (var i = 0; i < 4; i++) {
      final cp = _charPos(i);
      final stopped = _stopT[i] >= 0;
      final rank = _resolved ? _rank.indexOf(i) : -1;
      Face face;
      if (_resolved) {
        face = rank == 0 ? Face.love : (rank == 3 ? Face.cry : Face.sad);
        if (i == 0 && _won) face = Face.love;
      } else if (_revealing) {
        face = Face.shocked;
      } else if (stopped) {
        face = i == 0 ? Face.smug : Face.happy;
      } else {
        face = _clock > 8 ? Face.shocked : _Cast.mood[i];
      }
      final jump = _resolved && (rank == 0 || (i == 0 && _won)) ? -sin(_t * 11).abs() * 16 : 0.0;
      final lean = !stopped && _clock > 7 ? sin(_t * 30) * .03 : 0.0;
      _Cast.draw(c, i, cp + Offset(0, jump), i == 0 ? 25 : 22, face: face, squash: 1 - _press[i] * .2, tilt: lean);
      // sweat when close to 10 and still running
      if (!stopped && _clock > 8.2 && !_revealing) {
        D.circle(c, cp + Offset(20, -44 + (_t * 40) % 16), 3.5, const Color(0xDD7FD3FF));
      }
      // podium button
      final b = _btnCenter(i);
      final down = stopped ? 4.0 : 0.0;
      D.rrect(c, Rect.fromCenter(center: b + const Offset(0, 22), width: 66, height: 40), 8, const Color(0xFF4A3470),
          border: Pal.ink, borderWidth: 3);
      c.drawOval(Rect.fromCenter(center: b + const Offset(0, 8), width: 50, height: 18), D.fill(Color.lerp(_Cast.col[i], Pal.ink, .5)!));
      c.drawOval(Rect.fromCenter(center: b + Offset(0, 2 + down), width: 46, height: 16), D.fill(stopped ? _Cast.dark[i] : _Cast.col[i]));
      c.drawOval(Rect.fromCenter(center: b + Offset(0, 2 + down), width: 46, height: 16), D.stroke(Pal.ink, 2.5));
      final label = i == 0 ? host.tr('you', 'YOU') : '${host.tr('cpu', 'CPU')}$i';
      D.text(c, label, b + const Offset(0, 28), size: 13, color: i == 0 ? Pal.yellow : Pal.white, stroke: Pal.ink);
      // result card
      final shownIdx = _revealOrder.indexOf(i);
      if (_revealing && shownIdx < _shown && _stopT[i] >= 0) {
        final e = _stopT[i] - _target;
        final card = Rect.fromCenter(center: cp + const Offset(0, -110), width: 78, height: 48);
        final best = _resolved && rank == 0;
        D.rrect(c, card, 10, best ? Pal.gold : Pal.white, border: _Cast.col[i], borderWidth: 4);
        D.text(c, _fmt(_stopT[i]), card.center + const Offset(0, -8), size: 18, color: Pal.ink);
        D.text(c, '${e >= 0 ? '+' : ''}${e.toStringAsFixed(2)}', card.center + const Offset(0, 12), size: 12,
            color: e.abs() <= .15 ? const Color(0xFF16A34A) : Pal.red);
        if (_resolved) {
          D.text(c, '#${rank + 1}', card.topLeft + const Offset(4, -4), size: 16, color: Pal.yellow, stroke: Pal.ink);
        }
        if (best && _crown > .05) {
          D.star(c, card.topCenter + Offset(0, -16 - sin(_t * 8) * 3), 13 * _crown, Pal.gold, border: Pal.ink);
        }
      } else if (stopped && !_revealing) {
        D.bubble(c, Rect.fromCenter(center: cp + const Offset(0, -86), width: 52, height: 28), tail: cp + const Offset(0, -62));
        D.text(c, '?.??', cp + const Offset(0, -86), size: 14, color: Pal.ink);
      }
    }
    if (_revealing && !_resolved) {
      D.title(c, '...', Offset(180, 420 + sin(_t * 10) * 4), size: 40, color: Pal.white);
    }
  }
}

/// Party cast shared by No.046–053: you (blue hero) vs Red, Green, Yellow.
abstract final class _Cast {
  static const col = [Color(0xFF3D8BFF), Color(0xFFFF4B5C), Color(0xFF37D67A), Color(0xFFFFCF33)];
  static const dark = [Color(0xFF1F4FB8), Color(0xFFB8243A), Color(0xFF1C8F4E), Color(0xFFC79A10)];
  static const mood = [Face.happy, Face.angry, Face.smug, Face.happy];

  /// Draws party member [i] standing with feet at [feet]. [run] animates feet.
  static void draw(Canvas c, int i, Offset feet, double r,
      {Face? face, double squash = 1, double tilt = 0, double? run, Offset look = Offset.zero, bool soot = false}) {
    c.save();
    c.translate(feet.dx, feet.dy);
    if (tilt != 0) c.rotate(tilt);
    if (squash != 1) c.scale(1 / sqrt(squash), squash);
    final body = soot ? const Color(0xFF3A3340) : col[i];
    final dk = soot ? const Color(0xFF221D28) : dark[i];
    // feet
    final ph = run ?? 0;
    for (final s in [-1.0, 1.0]) {
      final sw = run == null ? 0.0 : sin(ph * pi + (s > 0 ? 0 : pi));
      final lift = run == null ? 0.0 : max(0.0, sw) * r * .35;
      c.drawOval(Rect.fromCenter(center: Offset(s * r * .42 + sw * r * .38, -r * .08 - lift), width: r * .62, height: r * .36),
          D.fill(dk));
    }
    // accessories behind the body
    if (i == 1) {
      for (final s in [-1.0, 1.0]) {
        final p = Path()
          ..moveTo(s * r * .72, -r * 1.45)
          ..lineTo(s * r * .78, -r * 2.2)
          ..lineTo(s * r * .3, -r * 1.7)
          ..close();
        c.drawPath(p, D.fill(soot ? dk : const Color(0xFFFFF4DC)));
        c.drawPath(p, D.stroke(Pal.ink, max(1.5, r * .08)));
      }
    }
    D.blob(c, Offset(0, -r * .95), r, body, face: face ?? mood[i], look: look);
    final sw = max(1.5, r * .08);
    switch (i) {
      case 0: // hero cowlick + headband
        final p = Path()
          ..moveTo(-r * .2, -r * 1.82)
          ..quadraticBezierTo(-r * .15, -r * 2.5, r * .45, -r * 2.35)
          ..quadraticBezierTo(r * .05, -r * 2.2, r * .2, -r * 1.84)
          ..close();
        c.drawPath(p, D.fill(body));
        c.drawPath(p, D.stroke(Pal.ink, sw));
        c.drawRect(Rect.fromLTWH(-r * .92, -r * 1.52, r * 1.84, r * .2), D.fill(soot ? dk : Pal.white));
        final tail = Path()
          ..moveTo(r * .85, -r * 1.45)
          ..lineTo(r * 1.35, -r * 1.7 + sin(ph * 2) * r * .1)
          ..lineTo(r * 1.3, -r * 1.3)
          ..close();
        c.drawPath(tail, D.fill(soot ? dk : Pal.white));
        c.drawPath(tail, D.stroke(Pal.ink, sw * .7));
      case 2: // sprout
        c.drawLine(Offset(0, -r * 1.85), Offset(0, -r * 2.3), D.stroke(Pal.ink, sw));
        for (final s in [-1.0, 1.0]) {
          c.save();
          c.translate(s * r * .22, -r * 2.3);
          c.rotate(s * .6);
          final leaf = Rect.fromCenter(center: Offset.zero, width: r * .5, height: r * .26);
          c.drawOval(leaf, D.fill(soot ? dk : const Color(0xFF9BE22D)));
          c.drawOval(leaf, D.stroke(Pal.ink, sw * .8));
          c.restore();
        }
      case 3: // bow
        final o = Offset(r * .45, -r * 1.72);
        for (final s in [-1.0, 1.0]) {
          final p = Path()
            ..moveTo(o.dx, o.dy)
            ..lineTo(o.dx + s * r * .42, o.dy - r * .24)
            ..lineTo(o.dx + s * r * .42, o.dy + r * .24)
            ..close();
          c.drawPath(p, D.fill(soot ? dk : Pal.pink));
          c.drawPath(p, D.stroke(Pal.ink, sw * .8));
        }
        c.drawCircle(o, r * .12, D.fill(soot ? dk : Pal.pink));
        c.drawCircle(o, r * .12, D.stroke(Pal.ink, sw * .8));
    }
    c.restore();
  }
}
