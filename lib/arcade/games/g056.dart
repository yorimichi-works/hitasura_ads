import '../engine/engine.dart';

/// No.056 Shell Game — a slick street hustler hides a coin under one of 3
/// cups and shuffles them 8 times, faster and faster. Track the coin and tap
/// the right cup. The CPU crowd places (usually wrong) bets too.
class G056 extends MiniGame {
  static const _slotX = [84.0, 180.0, 276.0];
  static const _baseY = 448.0;
  static const _swaps = 8;

  final _cupSlot = [0, 1, 2]; // cup id -> slot
  final _cupPos = [Offset.zero, Offset.zero, Offset.zero];
  final _cupScale = [1.0, 1.0, 1.0];
  final _cupLift = [0.0, 0.0, 0.0];
  int _coinCup = 0;
  _Ph _ph = _Ph.show;
  double _pt = 0;
  double _t = 0;
  int _swapN = 0;
  int _swapA = 0, _swapB = 1; // cup ids being swapped
  double _swapDur = .5;
  double _swapK = 0;
  bool _swapAFront = true;
  int _picked = -1;
  bool _right = false;
  double _chooseAt = 0;
  final _bets = [-1, -1, -1]; // cpu 1..3 bet cup ids
  double _hustlerLaugh = 0;
  double _hustlerShock = 0;
  double _sweat = 0;
  final List<_Bill> _bills = [];

  @override
  void init() {
    _coinCup = randInt(3);
    for (var i = 0; i < 3; i++) {
      _cupPos[i] = Offset(_slotX[i], _baseY);
      _cupLift[i] = i == _coinCup ? 1 : 0;
    }
  }

  void _startSwap() {
    // pick two different slots; later swaps tend to involve the coin cup
    var a = randInt(3);
    if (_swapN >= 3 && chance(.55)) a = _coinCup;
    var b = randInt(3);
    while (b == a) {
      b = randInt(3);
    }
    _swapA = a;
    _swapB = b;
    _swapK = 0;
    _swapAFront = chance(.5);
    final k = _swapN / (_swaps - 1);
    _swapDur = M.lerp(.52, .24, k) / host.speed;
    host.sfx(Sfx.swipe, volume: .6, rate: .9 + k * .6);
  }

  @override
  void update(double dt) {
    _t += dt;
    _pt += dt;
    _hustlerLaugh = max(0, _hustlerLaugh - dt);
    _hustlerShock = max(0, _hustlerShock - dt * .5);
    _sweat += dt;
    for (final b in _bills) {
      b.pos += b.vel * dt;
      b.vel = Offset(b.vel.dx * .98 + sin(_t * 5 + b.phase) * 20 * dt, min(b.vel.dy + 300 * dt, 120));
      b.rot += b.spin * dt;
    }
    _bills.removeWhere((b) => b.pos.dy > 700);

    switch (_ph) {
      case _Ph.show:
        // coin visible under a lifted cup, then it drops
        if (_pt > 1.2) {
          _cupLift[_coinCup] = M.approach(_cupLift[_coinCup], 0, 16, dt);
          if (_pt > 1.5) {
            _cupLift[_coinCup] = 0;
            host.sfx(Sfx.thud);
            host.shake(3);
            _ph = _Ph.shuffle;
            _pt = 0;
            _startSwap();
          }
        }
      case _Ph.shuffle:
        _swapK += dt / _swapDur;
        final k = M.easeInOut(_swapK.clamp(0, 1));
        final sa = _cupSlot[_swapA], sb = _cupSlot[_swapB];
        final xa = M.lerp(_slotX[sa], _slotX[sb], k);
        final xb = M.lerp(_slotX[sb], _slotX[sa], k);
        final arc = sin(k * pi) * (28 + (sa - sb).abs() * 10);
        final fa = _swapAFront ? 1 : -1;
        _cupPos[_swapA] = Offset(xa, _baseY + arc * fa);
        _cupPos[_swapB] = Offset(xb, _baseY - arc * fa);
        _cupScale[_swapA] = 1 + sin(k * pi) * .1 * fa;
        _cupScale[_swapB] = 1 - sin(k * pi) * .1 * fa;
        if (_swapK >= 1) {
          _cupSlot[_swapA] = sb;
          _cupSlot[_swapB] = sa;
          _cupPos[_swapA] = Offset(_slotX[sb], _baseY);
          _cupPos[_swapB] = Offset(_slotX[sa], _baseY);
          _cupScale[_swapA] = _cupScale[_swapB] = 1;
          host.sfx(Sfx.clang, volume: .35, rate: 1.4 + _swapN * .05);
          _swapN++;
          if (_swapN >= _swaps) {
            _ph = _Ph.choose;
            _pt = 0;
            _chooseAt = host.time;
            host.sfx(Sfx.ding);
            // crowd bets (green is sharp, red is stubborn, yellow is asleep)
            _bets[0] = chance(.4) ? _coinCup : randInt(3);
            _bets[1] = chance(.6) ? _coinCup : randInt(3);
            _bets[2] = randInt(3);
          } else {
            _startSwap();
          }
        }
      case _Ph.choose:
        break;
      case _Ph.reveal:
        _cupLift[_picked] = M.approach(_cupLift[_picked], 1, 12, dt);
        if (!_right && _pt > .55) _cupLift[_coinCup] = M.approach(_cupLift[_coinCup], 1, 12, dt);
        if (_pt > .3 && !host.finished) {
          if (_right) {
            _hustlerShock = 2;
            host.sfx(Sfx.fanfare);
            host.sfx(Sfx.coins);
            host.sfx(Sfx.cheer, volume: .6);
            final at = _cupPos[_picked] + const Offset(0, -10);
            host.fx.coins(at, count: 30, speed: 520);
            host.fx.burst(at, Pal.yellow, count: 20, speed: 300, shape: PartShape.star, size: 8);
            host.fx.ring(at, Pal.yellow, size: 90);
            host.fx.pop(host.tr('jackpot', 'JACKPOT!'), const Offset(180, 330), color: Pal.yellow, size: 36, life: 1.2);
            host.flash(const Color(0x88FFF1A8));
            host.shake(7);
            for (var i = 0; i < 24; i++) {
              _bills.add(_Bill(Offset(rand(0, 360), rand(-200, -10)), Offset(rand(-40, 40), rand(40, 120)),
                  rand(0, 6), rand(-3, 3)));
            }
            final quick = host.time - _chooseAt < 2.2;
            host.win(stars: quick ? 3 : 2);
          } else {
            _hustlerLaugh = 3;
            host.sfx(Sfx.wrong);
            host.sfx(Sfx.oops, volume: .7);
            host.fx.pop(host.tr('haha', 'HA HA!'), const Offset(180, 150), color: Pal.pink, size: 30, life: 1.2);
            host.shake(4);
            host.lose();
          }
        }
    }
  }

  @override
  void onDown(Offset p) {
    if (_ph != _Ph.choose) return;
    var best = 0;
    var bd = 1e9;
    for (var i = 0; i < 3; i++) {
      final d = (p.dx - _cupPos[i].dx).abs() + max(0, (p.dy - _cupPos[i].dy).abs() - 60) * .5;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    _pick(best);
  }

  void _pick(int cup) {
    _picked = cup;
    _right = cup == _coinCup;
    _ph = _Ph.reveal;
    _pt = 0;
    host.sfx(Sfx.drumroll, volume: .6);
    host.sfx(Sfx.tap);
    host.punch(.03);
  }

  @override
  void onKey(String key, bool down) {
    if (!down || _ph != _Ph.choose) return;
    final slot = switch (key) { 'left' => 0, 'up' || 'action' => 1, 'right' => 2, _ => -1 };
    if (slot < 0) return;
    _pick(_cupSlot.indexOf(slot));
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    // alley backdrop: bricks + neon
    D.gradientBg(c, const [Color(0xFF2A0F3D), Color(0xFF571A4F), Color(0xFF7A2A3A)]);
    final brick = D.fill(const Color(0x22000000));
    for (var row = 0; row < 14; row++) {
      final off = row.isEven ? 0.0 : 22.0;
      for (var x = -22.0 + off; x < 380; x += 44) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, 40 + row * 20.0 + 2, 40, 16), const Radius.circular(3)),
            brick);
      }
    }
    // neon sign
    final neonOn = sin(_t * 13) > -.85;
    final neon = neonOn ? Pal.pink : const Color(0xFF6A2A5A);
    D.rrect(c, const Rect.fromLTWH(210, 52, 128, 50), 10, const Color(0x00000000), border: neon, borderWidth: 4);
    if (neonOn) {
      D.rrect(c, const Rect.fromLTWH(206, 48, 136, 58), 14, const Color(0x00000000),
          border: const Color(0x44FF5FC8), borderWidth: 8);
    }
    D.coin(c, const Offset(236, 77), 12, spin: _t * .5);
    D.text(c, 'x3', const Offset(286, 78), size: 28, color: neonOn ? Pal.yellow : const Color(0xFF7A6A3A));
    // lamp glow
    c.drawCircle(const Offset(40, 90), 70, D.fill(const Color(0x22FFE080)));
    D.rrect(c, const Rect.fromLTWH(34, 60, 12, 30), 4, const Color(0xFF3A2A3A));
    c.drawCircle(const Offset(40, 94), 10, D.fill(const Color(0xFFFFE9A0)));

    _drawHustler(c);

    // table
    final table = Path()
      ..moveTo(10, 350)
      ..lineTo(350, 350)
      ..lineTo(360, 540)
      ..lineTo(0, 540)
      ..close();
    c.drawPath(table.shift(const Offset(0, 10)), D.fill(const Color(0xFF3A1F12)));
    c.drawPath(table, D.fill(const Color(0xFF1E8A4C)));
    c.drawPath(
        table,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x33FFFFFF), Color(0x00000000)])
              .createShader(Rect.fromCircle(center: const Offset(180, 440), radius: 200)));
    c.drawPath(table, D.stroke(const Color(0xFF8A4A22), 10));
    c.drawPath(table, D.stroke(Pal.ink, 2));
    // felt pattern
    for (final x in _slotX) {
      c.drawOval(Rect.fromCenter(center: Offset(x, _baseY + 8), width: 86, height: 28), D.stroke(const Color(0x33FFFFFF), 2));
    }

    // coin under its cup (visible when cup lifted)
    final coinP = _cupPos[_coinCup] + const Offset(0, 4);
    if (_cupLift[_coinCup] > .1) {
      c.drawCircle(coinP, 28 * _cupLift[_coinCup], D.fill(const Color(0x33FFE680)));
      D.coin(c, coinP, 16, spin: _t * .8);
    }

    // cups sorted by y (front last)
    final order = [0, 1, 2]..sort((a, b) => _cupPos[a].dy.compareTo(_cupPos[b].dy));
    for (final i in order) {
      _drawCup(c, _cupPos[i], _cupScale[i], _cupLift[i], i == _picked);
    }

    // hustler gloves on moving cups
    if (_ph == _Ph.shuffle) {
      _glove(c, _cupPos[_swapA] + Offset(0, -62 * _cupScale[_swapA]), _t);
      _glove(c, _cupPos[_swapB] + Offset(0, -62 * _cupScale[_swapB]), _t + 1);
    } else {
      _glove(c, const Offset(30, 380), 0);
      _glove(c, const Offset(330, 380), 0);
    }

    // CPU bets (flags) during choose/reveal
    if (_ph == _Ph.choose || _ph == _Ph.reveal) {
      final k = M.clamp01((_ph == _Ph.choose ? _pt : 1) / .35);
      final counts = [0, 0, 0];
      for (var j = 0; j < 3; j++) {
        final cup = _bets[j];
        if (cup < 0) continue;
        final slotN = counts[cup]++;
        final o = _cupPos[cup] + Offset(-22 + slotN * 22.0, 52);
        _Cast.draw(c, j + 1, o + Offset(0, (1 - k) * 60), 9, face: _Cast.face[j + 1]);
      }
    }

    // audience row
    D.rrect(c, const Rect.fromLTWH(0, 548, 360, 92), 0, const Color(0xFF1B1530));
    for (var i = 0; i < 4; i++) {
      final x = 50 + i * 87.0;
      final bob = sin(_t * 6 + i) * 2;
      var face = _Cast.face[i];
      if (_ph == _Ph.shuffle) face = Face.shocked;
      if (host.finished) {
        final betRight = i == 0 ? _right : _bets[i - 1] == _coinCup;
        face = betRight ? Face.love : Face.cry;
      }
      // eyes follow the coin cup... mostly
      final look = Offset(((_cupPos[_coinCup].dx - x) / 120).clamp(-1, 1), -1);
      _Cast.draw(c, i, Offset(x, 594 + bob), i == 0 ? 24 : 20, face: face, look: look);
      if (i == 0) {
        D.text(c, host.tr('you', 'YOU'), Offset(x, 630), size: 12, color: Pal.white, stroke: Pal.blue, strokeWidth: 4);
      }
    }

    // swap counter
    if (_ph == _Ph.shuffle || _ph == _Ph.show) {
      for (var i = 0; i < _swaps; i++) {
        final o = Offset(180 - (_swaps - 1) * 11 + i * 22.0, 330);
        c.drawCircle(o, 7, D.fill(i < _swapN ? Pal.yellow : const Color(0x44FFFFFF)));
        c.drawCircle(o, 7, D.stroke(Pal.ink, 2));
      }
    }
    if (_ph == _Ph.show) {
      D.title(c, host.tr('watch', 'WATCH!'), const Offset(180, 300), size: 34, color: Pal.yellow);
      final p = _cupPos[_coinCup];
      D.arrow(c, p + const Offset(0, -110 + 0.0), const Offset(0, 1), 34, Pal.yellow, width: 9);
    }
    if (_ph == _Ph.choose) {
      D.title(c, host.tr('which', 'WHICH?'), const Offset(180, 310), size: 36 * (1 + .05 * sin(_t * 8)), color: Pal.white);
      if (_pt > .6 && host.time - _chooseAt < 4) D.hand(c, _cupPos[_cupSlot.indexOf(1)] + const Offset(0, -20), _t);
    }
    // money rain
    for (final b in _bills) {
      c.save();
      c.translate(b.pos.dx, b.pos.dy);
      c.rotate(b.rot);
      c.scale(cos(b.rot * 2).abs().clamp(.2, 1), 1);
      D.rrect(c, const Rect.fromLTWH(-16, -9, 32, 18), 3, const Color(0xFF7BD389), border: const Color(0xFF2E7D4A), borderWidth: 2);
      c.drawCircle(Offset.zero, 5, D.stroke(const Color(0xFF2E7D4A), 2));
      c.restore();
    }
  }

  void _drawCup(Canvas c, Offset base, double s, double lift, bool picked) {
    final o = base + Offset(0, -lift * 88);
    D.shadow(c, base + const Offset(0, 6), 78 * s * (1 - lift * .3), 18 * s, .35 - lift * .15);
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s);
    final body = Path()
      ..moveTo(-36, 0)
      ..lineTo(-24, -74)
      ..quadraticBezierTo(0, -80, 24, -74)
      ..lineTo(36, 0)
      ..quadraticBezierTo(0, 10, -36, 0)
      ..close();
    c.drawPath(
        body,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFFB0162E), Color(0xFFFF4B5C), Color(0xFFB0162E)])
              .createShader(const Rect.fromLTWH(-36, -80, 72, 90)));
    // bands
    for (final y in const [-16.0, -56.0]) {
      final w = 34 - (-y) * .16;
      c.drawPath(
          Path()
            ..moveTo(-w, y)
            ..quadraticBezierTo(0, y + 7, w, y)
            ..lineTo(w - 1, y - 7)
            ..quadraticBezierTo(0, y, -w + 1, y - 7)
            ..close(),
          D.fill(Pal.gold));
    }
    // top rim
    c.drawOval(Rect.fromCenter(center: const Offset(0, -75), width: 48, height: 10), D.fill(const Color(0xFFE0304A)));
    // highlight
    c.drawPath(
        Path()
          ..moveTo(-20, -64)
          ..lineTo(-26, -12)
          ..lineTo(-18, -12)
          ..lineTo(-13, -64)
          ..close(),
        D.fill(const Color(0x55FFFFFF)));
    c.drawPath(body, D.stroke(Pal.ink, 3));
    if (picked) c.drawPath(body, D.stroke(Pal.white, 2));
    c.restore();
  }

  void _glove(Canvas c, Offset o, double ph) {
    c.save();
    c.translate(o.dx, o.dy);
    D.rrect(c, const Rect.fromLTWH(-8, -26, 16, 18), 5, const Color(0xFF6A2D8A), border: Pal.ink, borderWidth: 2);
    c.drawOval(const Rect.fromLTWH(-15, -12, 30, 24), D.fill(Pal.white));
    c.drawOval(const Rect.fromLTWH(-15, -12, 30, 24), D.stroke(Pal.ink, 2.5));
    for (var f = 0; f < 3; f++) {
      D.line(c, Offset(-6 + f * 6.0, 4), Offset(-6 + f * 6.0, 10), Pal.ink, 1.5);
    }
    c.restore();
  }

  void _drawHustler(Canvas c) {
    const hc = Offset(180, 218);
    final laugh = _hustlerLaugh > 0;
    final shock = _hustlerShock > 0;
    final shakeX = laugh ? sin(_t * 40) * 3 : (shock ? sin(_t * 60) * 2 : 0.0);
    final lean = _ph == _Ph.shuffle ? sin(_t * 9) * .05 : 0.0;
    c.save();
    c.translate(hc.dx + shakeX, hc.dy);
    c.rotate(lean);
    // body: purple suit
    final suit = Path()
      ..moveTo(-90, 140)
      ..quadraticBezierTo(-86, 50, -40, 40)
      ..lineTo(40, 40)
      ..quadraticBezierTo(86, 50, 90, 140)
      ..close();
    c.drawPath(suit, D.fill(const Color(0xFF6A2D8A)));
    c.drawPath(suit, D.stroke(Pal.ink, 4));
    // shirt v + gold chain
    c.drawPath(
        Path()
          ..moveTo(-24, 40)
          ..lineTo(0, 100)
          ..lineTo(24, 40)
          ..close(),
        D.fill(const Color(0xFFFFE27A)));
    c.drawArc(const Rect.fromLTWH(-26, 30, 52, 60), .3, pi - .6, false, D.stroke(Pal.gold, 5));
    c.drawCircle(const Offset(0, 90), 7, D.fill(Pal.gold));
    c.drawCircle(const Offset(0, 90), 7, D.stroke(Pal.ink, 2));
    // head
    c.drawOval(const Rect.fromLTWH(-52, -58, 104, 104), D.fill(Pal.skin));
    c.drawOval(const Rect.fromLTWH(-52, -58, 104, 104), D.stroke(Pal.ink, 4));
    // fedora
    c.drawOval(const Rect.fromLTWH(-74, -52, 148, 26), D.fill(const Color(0xFF2A2440)));
    c.drawOval(const Rect.fromLTWH(-74, -52, 148, 26), D.stroke(Pal.ink, 3));
    D.rrect(c, const Rect.fromLTWH(-46, -96, 92, 56), 16, const Color(0xFF2A2440), border: Pal.ink, borderWidth: 3);
    c.drawRect(const Rect.fromLTWH(-45, -52, 90, 11), D.fill(Pal.pink));
    // sunglasses
    final glassY = shock ? -18.0 : -12.0;
    for (final s in [-1.0, 1.0]) {
      D.rrect(c, Rect.fromCenter(center: Offset(s * 22, glassY), width: 38, height: 22), 8, Pal.ink);
      c.drawLine(Offset(s * 22 - 10, glassY - 5), Offset(s * 22 - 2, glassY - 5), D.stroke(const Color(0x88FFFFFF), 3));
    }
    D.line(c, Offset(-4, glassY), Offset(4, glassY), Pal.ink, 4);
    if (shock) {
      // eyes popping under raised glasses
      for (final s in [-1.0, 1.0]) {
        c.drawCircle(Offset(s * 22, 2), 9, D.fill(Pal.white));
        c.drawCircle(Offset(s * 22, 2), 9, D.stroke(Pal.ink, 2));
        c.drawCircle(Offset(s * 22, 3), 3, D.fill(Pal.ink));
      }
    }
    // mustache
    final m = Path()
      ..moveTo(0, 14)
      ..quadraticBezierTo(-20, 6, -32, 18)
      ..quadraticBezierTo(-18, 14, 0, 20)
      ..quadraticBezierTo(18, 14, 32, 18)
      ..quadraticBezierTo(20, 6, 0, 14)
      ..close();
    // mouth
    if (laugh) {
      c.drawOval(const Rect.fromLTWH(-22, 18, 44, 28), D.fill(const Color(0xFF7A1F2B)));
      c.drawRect(const Rect.fromLTWH(-16, 18, 32, 7), D.fill(Pal.white));
      c.drawRect(const Rect.fromLTWH(4, 18, 8, 7), D.fill(Pal.gold));
    } else if (shock) {
      c.drawOval(const Rect.fromLTWH(-10, 22, 20, 22), D.fill(const Color(0xFF7A1F2B)));
    } else {
      c.drawArc(const Rect.fromLTWH(-20, 12, 40, 20), .2, pi - .4, false, D.stroke(Pal.ink, 4));
      c.drawRect(const Rect.fromLTWH(6, 26, 7, 6), D.fill(Pal.gold));
    }
    c.drawPath(m, D.fill(const Color(0xFF3A2418)));
    // sweat when shocked or during fast swaps
    if (shock || (_ph == _Ph.choose)) {
      final y = -20 + (_sweat * 40) % 30;
      c.drawOval(Rect.fromLTWH(46, y, 10, 15), D.fill(const Color(0xFF7FD3FF)));
    }
    c.restore();
  }
}

enum _Ph { show, shuffle, choose, reveal }

class _Bill {
  _Bill(this.pos, this.vel, this.phase, this.spin);
  Offset pos;
  Offset vel;
  final double phase;
  final double spin;
  double rot = 0;
}

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
