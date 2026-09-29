import '../engine/engine.dart';

/// No.060 Cream Pie Roulette — 8 buttons, 2 of them are loaded with PIE.
/// Players take turns pressing one. Get pied = you're out.
/// Skill: loaded buttons twitch now and then (watch closely!), and if the
/// pie arm fires at YOU, tap when the ring hits the target to DODGE.
/// Stay clean until the end (or be the last clean face) to win.
class G060 extends MiniGame {
  static const _seatX = [54.0, 138.0, 222.0, 306.0];
  static const _faceY = 214.0;
  static const _pies = 2;

  final _out = [false, false, false, false];
  final _cream = [0.0, 0.0, 0.0, 0.0];
  final _relief = [0.0, 0.0, 0.0, 0.0];
  final _pressed = List.filled(8, false);
  final _loaded = List.filled(8, false);
  final _twitch = List.filled(8, 0.0);
  final _btnPush = List.filled(8, 0.0);
  final _twitchNext = List.filled(8, 0.0);
  int _turn = 0;
  _Ph _ph = _Ph.think;
  double _pt = 0;
  double _t = 0;
  int _choice = -1;
  double _cpuDelay = .6;
  Offset _cpuHand = const Offset(180, 660);
  int _cpuTarget = 0;
  double _armK = 0; // 0 rest .. 1 in face
  int _armWho = -1;
  bool _dodged = false;
  double _ring = 0; // dodge ring time 0..1
  bool _dodgeTried = false;
  double _dodgeLean = 0;
  double _screenSplat = 0;
  int _pied = 0;

  @override
  void init() {
    _arm();
    _startTurn();
  }

  void _arm() {
    for (var i = 0; i < 8; i++) {
      _pressed[i] = false;
      _loaded[i] = false;
      _twitchNext[i] = rand(.3, 1.6);
    }
    var n = 0;
    while (n < _pies) {
      final i = randInt(8);
      if (!_loaded[i]) {
        _loaded[i] = true;
        n++;
      }
    }
  }

  void _startTurn() {
    _ph = _Ph.think;
    _pt = 0;
    _choice = -1;
    if (_turn != 0) {
      _cpuDelay = rand(.45, .8) / sqrt(host.speed);
      final free = [for (var i = 0; i < 8; i++) if (!_pressed[i]) i];
      // green (smart) sometimes spots the twitch; red/yellow pick at random
      var pickI = pick(free);
      if (_turn == 2 && chance(.5)) {
        final safe = free.where((i) => !_loaded[i]).toList();
        if (safe.isNotEmpty) pickI = pick(safe);
      }
      _cpuTarget = pickI;
      _cpuHand = Offset(_seatX[_turn], 380);
    }
  }

  Offset _btnPos(int i) => Offset(52 + (i % 4) * 85.0, 452 + (i ~/ 4) * 84.0);

  void _press(int i) {
    _choice = i;
    _pressed[i] = true;
    _btnPush[i] = 1;
    _ph = _Ph.suspense;
    _pt = 0;
    host.sfx(Sfx.click);
    host.sfx(Sfx.drumroll, volume: .6);
    host.fx.ring(_btnPos(i), Pal.white, size: 40);
  }

  @override
  void update(double dt) {
    _t += dt;
    _pt += dt;
    _screenSplat = max(0, _screenSplat - dt * .7);
    for (var i = 0; i < 8; i++) {
      _btnPush[i] = M.approach(_btnPush[i], 0, 6, dt);
      _twitch[i] = max(0, _twitch[i] - dt);
      _twitchNext[i] -= dt;
      if (_twitchNext[i] <= 0) {
        _twitchNext[i] = rand(.9, 1.8);
        if (_loaded[i] && !_pressed[i]) _twitch[i] = .22;
      }
    }
    for (var i = 0; i < 4; i++) {
      _relief[i] = max(0, _relief[i] - dt);
    }
    _dodgeLean = M.approach(_dodgeLean, _dodged && _ph == _Ph.fire ? 1 : 0, 14, dt);
    if (host.finished) {
      if (_armWho >= 0) _armK = M.approach(_armK, _dodged ? 0 : 1, 10, dt);
      return;
    }

    switch (_ph) {
      case _Ph.think:
        if (_turn != 0) {
          final goal = _btnPos(_cpuTarget) + const Offset(0, -6);
          // wobble "hmm..." before committing
          final wob = _pt < _cpuDelay * .7 ? Offset(sin(_t * 9) * 40, 0) : Offset.zero;
          _cpuHand = M.approachO(_cpuHand, goal + wob, 7, dt);
          if (_pt > _cpuDelay) _press(_cpuTarget);
        } else if (_pt > 6) {
          // idle too long: the host presses for you
          final free = [for (var i = 0; i < 8; i++) if (!_pressed[i]) i];
          _press(pick(free));
        }
      case _Ph.suspense:
        if (_pt > .55) {
          if (_loaded[_choice]) {
            _ph = _Ph.fire;
            _pt = 0;
            _armWho = _turn;
            _armK = 0;
            _dodged = false;
            _dodgeTried = false;
            _ring = 0;
            host.sfx(Sfx.boing, rate: .8);
            host.sfx(Sfx.heartbeat, volume: .6);
            host.shake(3);
          } else {
            _relief[_turn] = .6;
            host.sfx(Sfx.ding, rate: 1.1);
            host.fx.pop(host.tr('safe', 'SAFE!'), Offset(_seatX[_turn], _faceY - 50), color: Pal.lime, size: 22);
            host.fx.sparkle(Offset(_seatX[_turn], _faceY), count: 6, radius: 20, color: Pal.lime);
            if (_turn == 0) host.addScore(10, Offset(_seatX[0], _faceY - 70));
            _ph = _Ph.after;
            _pt = 0;
          }
        }
      case _Ph.fire:
        // arm winds up slowly, then SLAMS
        final windup = (_turn == 0 ? .95 : .45) / sqrt(host.speed);
        if (_pt < windup) {
          _armK = .2 * (_pt / windup) + sin(_t * 30) * .02;
          _ring = _pt / windup;
          if (_turn != 0) break;
        } else {
          _armK = M.approach(_armK, 1, 18, dt);
          if (_pt > windup + .12 && _cream[_turn] == 0 && !_dodged) _splat(_turn);
          if (_dodged && _pt > windup + .1 && _screenSplat == 0) {
            _screenSplat = 1;
            host.sfx(Sfx.splat);
            host.shake(8);
            host.fx.pop(host.tr('dodge', 'DODGE!'), Offset(_seatX[0], _faceY - 60), color: Pal.lime, size: 30);
          }
          if (_pt > windup + .8) _afterPie();
        }
      case _Ph.after:
        if (_pt > .35) _nextTurn();
    }
  }

  void _splat(int who) {
    _cream[who] = 1;
    host.sfx(Sfx.splat);
    host.sfx(Sfx.squish, volume: .7);
    host.shake(who == 0 ? 10 : 6);
    host.hitStop(.07);
    host.fx.burst(Offset(_seatX[who], _faceY), Pal.white,
        count: 26, speed: 280, size: 9, colors: const [Pal.white, Pal.cream, Color(0xFFFFB3C7)]);
    host.fx.ring(Offset(_seatX[who], _faceY), Pal.white, size: 60);
    if (who == 0) {
      host.flash(const Color(0xCCFFFFFF), .3);
      host.sfx(Sfx.aww);
      _out[0] = true;
      host.lose();
    } else {
      _out[who] = true;
      _pied++;
      host.sfx(Sfx.cheer, volume: .5);
      host.fx.pop(host.tr('out', 'OUT!'), Offset(_seatX[who], _faceY - 60), color: Pal.red, size: 26);
    }
  }

  void _afterPie() {
    _armK = 0;
    _armWho = -1;
    if (_out.skip(1).every((o) => o)) {
      host.fx.confetti(count: 90);
      host.sfx(Sfx.fanfare);
      host.win(stars: 3);
      return;
    }
    // reload!
    _arm();
    host.sfx(Sfx.powerup, volume: .5);
    _ph = _Ph.after;
    _pt = 0;
  }

  void _nextTurn() {
    for (var k = 0; k < 4; k++) {
      _turn = (_turn + 1) % 4;
      if (!_out[_turn]) break;
    }
    _startTurn();
  }

  @override
  void onTimeUp() {
    if (_out[0]) {
      host.lose();
      return;
    }
    host.fx.confetti(count: 60);
    host.win(stars: _pied >= 2 ? 3 : (_pied == 1 ? 2 : 1));
  }

  @override
  void onDown(Offset p) {
    if (_turn != 0) return;
    if (_ph == _Ph.think) {
      for (var i = 0; i < 8; i++) {
        if (_pressed[i]) continue;
        if ((p - _btnPos(i)).distance < 40) {
          _press(i);
          return;
        }
      }
    } else if (_ph == _Ph.fire && !_dodgeTried && _cream[0] == 0) {
      _dodgeTried = true;
      // ring shrinks from big to 0; target is when it matches the face (~.72)
      final ok = (_ring - .74).abs() < .17;
      if (ok) {
        _dodged = true;
        host.sfx(Sfx.whoosh, rate: 1.3);
        host.sfx(Sfx.perfect);
        host.fx.pop(host.tr('perfect', 'PERFECT!'), Offset(_seatX[0] + 40, _faceY - 90), color: Pal.yellow, size: 24);
        host.hitStop(.05);
      } else {
        host.sfx(Sfx.wrong, volume: .6);
        host.fx.pop(host.tr('miss', 'MISS'), Offset(_seatX[0] + 30, _faceY - 80), color: Pal.red, size: 22);
      }
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'action' && _ph == _Ph.fire) onDown(Offset.zero);
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    // TV studio
    D.gradientBg(c, const [Color(0xFF12305E), Color(0xFF2B5FA8), Color(0xFF1B3570)], rect: const Rect.fromLTWH(0, 0, 360, 360));
    D.rays(c, const Offset(180, 380), 500, const Color(0x14FFFFFF), count: 16, t: _t * .2);
    // marquee lights
    for (var i = 0; i < 18; i++) {
      final on = ((i + (_t * 6).floor()) % 3) == 0;
      c.drawCircle(Offset(10 + i * 20.0, 48), 5, D.fill(on ? Pal.yellow : const Color(0xFF6B5A2A)));
    }
    // pie counter sign
    D.rrect(c, const Rect.fromLTWH(118, 60, 124, 40), 12, const Color(0xFFFF5FC8), border: Pal.white, borderWidth: 3);
    for (var i = 0; i < _pies; i++) {
      _pie(c, Offset(152 + i * 30.0, 82), 10);
    }
    D.text(c, 'x$_pies', const Offset(218, 81), size: 18, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);

    // contestants + podiums
    for (var i = 0; i < 4; i++) {
      _drawSeat(c, i);
    }
    for (var i = 0; i < 4; i++) {
      _drawArm(c, i);
    }

    // control desk
    D.gradientBg(c, const [Color(0xFF5A3A8A), Color(0xFF2A1A4A)], rect: const Rect.fromLTWH(0, 360, 360, 280));
    c.drawRect(const Rect.fromLTWH(0, 356, 360, 12), D.fill(const Color(0xFFFFD23F)));
    c.drawRect(const Rect.fromLTWH(0, 366, 360, 4), D.fill(Pal.ink));
    D.rrect(c, const Rect.fromLTWH(12, 396, 336, 216), 22, const Color(0xFF1E1236), border: const Color(0xFF8C6BD6), borderWidth: 3);
    for (var i = 0; i < 8; i++) {
      _drawButton(c, i);
    }

    // turn indicator / hints
    if (!host.finished) {
      if (_turn == 0 && _ph == _Ph.think) {
        D.text(c, host.tr('your_turn', 'YOUR TURN'), const Offset(180, 384), size: 18, color: Pal.yellow, stroke: Pal.ink);
        if (host.time < 3) D.hand(c, _btnPos(5), _t);
      }
      if (_turn != 0 && (_ph == _Ph.think || _ph == _Ph.suspense)) {
        _drawCpuHand(c);
      }
      if (_ph == _Ph.fire && _armWho == 0 && _cream[0] == 0 && !_dodged) {
        final o = Offset(_seatX[0], _faceY);
        final r = 90 * (1 - _ring) + 8;
        c.drawCircle(o, 30, D.stroke(Pal.lime, 4));
        c.drawCircle(o, r, D.stroke(Pal.white, 5));
        D.title(c, host.tr('tap', 'TAP!'), const Offset(180, 330), size: 34, color: Pal.lime);
      }
    }

    // pie in the camera
    if (_screenSplat > 0) {
      final a = _screenSplat.clamp(0.0, 1.0);
      final p = D.fill(Color.fromRGBO(255, 250, 240, a * .92));
      for (var i = 0; i < 9; i++) {
        final ang = i * .7;
        c.drawCircle(Offset(180 + cos(ang) * 70, 330 + sin(ang * 1.3) * 60), 70 + (i % 3) * 16, p);
      }
      for (var i = 0; i < 6; i++) {
        final x = 60 + i * 48.0;
        final len = 60 + (i * 37) % 80 + (1 - a) * 200;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 330, 22, len), const Radius.circular(11)), p);
      }
    }
  }

  void _pie(Canvas c, Offset o, double r) {
    c.drawOval(Rect.fromCenter(center: o + Offset(0, r * .3), width: r * 2.4, height: r * .9), D.fill(const Color(0xFFD9954B)));
    c.drawOval(Rect.fromCenter(center: o, width: r * 2.2, height: r * 1.2), D.fill(Pal.white));
    c.drawCircle(o + Offset(0, -r * .5), r * .5, D.fill(Pal.white));
    c.drawCircle(o + Offset(0, -r * .9), r * .25, D.fill(Pal.red));
  }

  void _drawSeat(Canvas c, int i) {
    final x = _seatX[i];
    final active = i == _turn && !host.finished;
    // spotlight
    if (active) {
      c.drawPath(
          Path()
            ..moveTo(x - 10, 36)
            ..lineTo(x + 10, 36)
            ..lineTo(x + 46, 330)
            ..lineTo(x - 46, 330)
            ..close(),
          D.fill(const Color(0x33FFF3A0)));
    }
    // podium
    D.rrect(c, Rect.fromLTWH(x - 38, 262, 76, 96), 8, _Cast.col[i], border: Pal.ink, borderWidth: 3,
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(_Cast.col[i], Pal.white, .3)!, Color.lerp(_Cast.col[i], Pal.ink, .3)!]));
    D.rrect(c, Rect.fromLTWH(x - 30, 284, 60, 26), 6, const Color(0x55000000));
    D.text(c, i == 0 ? host.tr('you', 'YOU') : 'CPU$i', Offset(x, 297), size: 13, color: Pal.white, stroke: Pal.ink, strokeWidth: 3);
    // contestant
    final lean = i == 0 ? _dodgeLean * -26 : 0.0;
    var face = _Cast.face[i];
    if (_out[i]) {
      face = Face.dead;
    } else if (_relief[i] > 0) {
      face = Face.happy;
    } else if (_ph == _Ph.suspense && i == _turn) {
      face = Face.shocked;
    } else if (_ph == _Ph.fire && i == _turn) {
      face = _dodged ? Face.smug : Face.cry;
    } else if (_ph == _Ph.fire && i != _turn) {
      face = Face.happy;
    }
    final shake = (_ph == _Ph.suspense && i == _turn) ? sin(_t * 50) * 2 : 0.0;
    final hp = Offset(x + lean + shake, _faceY + 8);
    _Cast.draw(c, i, hp, 30, face: face);
    if (_ph == _Ph.suspense && i == _turn) {
      c.drawOval(Rect.fromLTWH(hp.dx + 22, hp.dy - 30 + (_t * 50) % 12, 8, 12), D.fill(const Color(0xFF7FD3FF)));
    }
    // cream!
    if (_cream[i] > 0) {
      final cp = D.fill(const Color(0xFFFFFBF2));
      c.drawOval(Rect.fromCenter(center: hp + const Offset(0, 2), width: 58, height: 44), cp);
      for (var k = 0; k < 5; k++) {
        c.drawCircle(hp + Offset(-22 + k * 11.0, -16 + (k % 2) * 5), 9, cp);
      }
      for (var k = 0; k < 3; k++) {
        c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(hp.dx - 18 + k * 14, hp.dy + 14, 7, 12 + k * 5.0), const Radius.circular(4)),
            cp);
      }
      c.drawCircle(hp + const Offset(4, -22), 5, D.fill(Pal.red));
      // blinking eyes through the cream
      if ((_t * 2).floor().isEven) {
        c.drawCircle(hp + const Offset(-9, 0), 3, D.fill(Pal.ink));
        c.drawCircle(hp + const Offset(9, 0), 3, D.fill(Pal.ink));
      }
    }
  }

  void _drawArm(Canvas c, int i) {
    final x = _seatX[i];
    if (_out[i] && _armWho != i) return;
    final k = _armWho == i ? _armK : 0.0;
    final pivot = Offset(x + 24, 266);
    final ang = M.lerp(pi - .15, -2.05, k); // rest: pie on the desk; fired: up into the face
    final tip = pivot + Offset(cos(ang), sin(ang)) * 40;
    D.line(c, pivot, tip, Pal.ink, 9);
    D.line(c, pivot, tip, const Color(0xFFC9D2E3), 5);
    c.drawCircle(pivot, 7, D.fill(const Color(0xFF55607A)));
    c.drawCircle(pivot, 7, D.stroke(Pal.ink, 2));
    if (!(_cream[i] > 0)) _pie(c, tip + const Offset(0, -6), 13);
  }

  void _drawButton(Canvas c, int i) {
    final o = _btnPos(i);
    final pressed = _pressed[i];
    final tw = _twitch[i] > 0 ? sin(_t * 70) * 2.2 : 0.0;
    final col = Pal.candy[i % Pal.candy.length];
    final depth = pressed ? 2.0 : 9.0 - _btnPush[i] * 6;
    // base
    c.drawOval(Rect.fromCenter(center: o + const Offset(0, 10), width: 74, height: 40), D.fill(const Color(0xFF0E0820)));
    c.drawOval(Rect.fromCenter(center: o + const Offset(0, 6), width: 70, height: 36), D.fill(const Color(0xFF3A2A5A)));
    final top = o + Offset(tw, -depth + 6);
    final dark = Color.lerp(col, Pal.ink, pressed ? .7 : .4)!;
    c.drawRect(Rect.fromLTRB(top.dx - 26, top.dy, top.dx + 26, o.dy + 6), D.fill(dark));
    c.drawOval(Rect.fromCenter(center: Offset(top.dx, o.dy + 6), width: 52, height: 26), D.fill(dark));
    c.drawOval(Rect.fromCenter(center: top, width: 52, height: 26),
        D.fill(pressed ? Color.lerp(col, Pal.ink, .55)! : col));
    if (!pressed) {
      c.drawOval(Rect.fromCenter(center: top + const Offset(-8, -4), width: 20, height: 8), D.fill(const Color(0x88FFFFFF)));
    }
    c.drawOval(Rect.fromCenter(center: top, width: 52, height: 26), D.stroke(Pal.ink, 2.5));
    D.text(c, '${i + 1}', Offset(o.dx, o.dy + 30), size: 12, color: const Color(0x99FFFFFF));
    if (pressed && _choice == i && _ph == _Ph.fire) {
      _pie(c, top + const Offset(0, -6), 9);
    }
  }

  void _drawCpuHand(Canvas c) {
    final o = _cpuHand;
    final col = _Cast.col[_turn];
    c.save();
    c.translate(o.dx, o.dy);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -2, 14, 30), const Radius.circular(7)), D.fill(col));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -2, 14, 30), const Radius.circular(7)), D.stroke(Pal.ink, 2.5));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, 18, 30, 26), const Radius.circular(10)), D.fill(col));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, 18, 30, 26), const Radius.circular(10)), D.stroke(Pal.ink, 2.5));
    c.restore();
    if (_ph == _Ph.think) {
      D.text(c, '?', Offset(_seatX[_turn] + 30, _faceY - 40 + sin(_t * 6) * 3), size: 26, color: Pal.white, stroke: Pal.ink);
    }
  }
}

enum _Ph { think, suspense, fire, after }

/// The party cast: YOU (blue hero) and 3 CPU rivals.
abstract final class _Cast {
  static const col = [Color(0xFF3D6BFF), Color(0xFFFF3B5C), Color(0xFF2ECC71), Color(0xFFFFC21F)];
  static const face = [Face.happy, Face.angry, Face.smug, Face.sleepy];

  static void draw(Canvas c, int who, Offset o, double r,
      {Face? face, double squash = 1, Offset look = Offset.zero}) {
    final sq = squash;
    final topY = o.dy + r * (sq - 1) * .5 - r * .95 / sq;
    if (who == 0) {
      D.line(c, Offset(o.dx, topY + 2), Offset(o.dx + r * .15, topY - r * .45), Pal.ink, max(1.5, r * .1));
      D.star(c, Offset(o.dx + r * .15, topY - r * .55), r * .32, Pal.yellow, border: Pal.ink);
    } else if (who == 1) {
      final tuft = Path();
      for (var k = -1; k <= 1; k++) {
        final bx = o.dx + k * r * .38;
        tuft
          ..moveTo(bx - r * .22, topY + r * .2)
          ..lineTo(bx + k * r * .12, topY - r * .42)
          ..lineTo(bx + r * .22, topY + r * .2)
          ..close();
      }
      c.drawPath(tuft, D.fill(const Color(0xFFB8173A)));
      c.drawPath(tuft, D.stroke(Pal.ink, max(1.2, r * .07)));
    }
    D.blob(c, o, r, col[who], face: face ?? _Cast.face[who], look: look, squash: sq);
    final fy = o.dy + r * (sq - 1) * .5;
    if (who == 2) {
      final g = D.stroke(Pal.ink, max(1.2, r * .08));
      final sx = 1 / sqrt(sq);
      for (final s in [-1.0, 1.0]) {
        c.drawCircle(Offset(o.dx + s * r * .34 * sx, fy - r * .06 / sq), r * .26, g);
      }
      D.line(c, Offset(o.dx - r * .1 * sx, fy - r * .08 / sq), Offset(o.dx + r * .1 * sx, fy - r * .08 / sq), Pal.ink,
          max(1.2, r * .07));
    } else if (who == 3) {
      final b = Offset(o.dx + r * .55, topY + r * .28);
      final bow = Path()
        ..moveTo(b.dx, b.dy)
        ..lineTo(b.dx - r * .42, b.dy - r * .25)
        ..lineTo(b.dx - r * .42, b.dy + r * .25)
        ..close()
        ..moveTo(b.dx, b.dy)
        ..lineTo(b.dx + r * .42, b.dy - r * .25)
        ..lineTo(b.dx + r * .42, b.dy + r * .25)
        ..close();
      c.drawPath(bow, D.fill(Pal.pink));
      c.drawPath(bow, D.stroke(Pal.ink, max(1.2, r * .07)));
      c.drawCircle(b, r * .12, D.fill(Pal.pink));
    }
  }
}
