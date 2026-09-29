import 'dart:math' as math;
import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.114 Wheel of Fate — hold to charge the power meter, release inside
/// the GOLD zone to send the wheel onto x100 / CAR. Small prizes give you
/// another spin (with a wider gold zone); the red zone means BANKRUPT.

Paint _glow(Color c, double blur) => Paint()
  ..color = c
  ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur);

// slice kinds: 2/5/10 multipliers, 100 jackpot, -1 bankrupt, 0 car
const _slices = <int>[100, 2, 5, -1, 10, 2, 0, 5, 2, -1, 10, 5];
const _sliceCols = <int, Color>{
  2: Color(0xFF3FB8FF),
  5: Color(0xFF7ED957),
  10: Color(0xFFFF8A1F),
  100: Color(0xFFFFD23F),
  -1: Color(0xFF231A2E),
  0: Color(0xFFFF5FC8),
};

enum _St { ready, hold, spin, result, over }

class G114 extends MiniGame {
  static const _c = Offset(180, 322);
  static const _r = 138.0;
  static const _a = math.pi * 2 / 12;

  _St _st = _St.ready;
  double _t = 0, _stT = 0;
  double _theta = 0;
  double _from = 0, _to = 0, _dur = 2.7;
  double _hold = 0;
  double _power = 0;
  int _spins = 0;
  int _bank = 1000;
  double _bankDisp = 1000;
  double _flap = 0;
  int _lastPeg = 0;
  int _result = 2;
  Face _face = Face.happy;
  double _carT = -1;
  double _bulbT = 0;

  @override
  Color get backdrop => const Color(0xFF2A0616);

  List<double> get _gold => const [
        [.68, .87],
        [.62, .90],
        [.55, .93],
      ][math.min(2, _spins)];
  static const _red = .10;

  double _needle(double h) => .5 - .5 * math.cos(h * math.pi * 2 * .75 * (0.9 + .1 * host.speed));

  @override
  void update(double dt) {
    _t += dt;
    _stT += dt;
    _flap = M.approach(_flap, 0, 14, dt);
    _bankDisp = M.approach(_bankDisp, _bank.toDouble(), 4, dt);
    if ((_bankDisp - _bank).abs() < 1) _bankDisp = _bank.toDouble();
    if (_carT >= 0) _carT += dt;
    switch (_st) {
      case _St.hold:
        _hold += dt;
        final before = _power;
        _power = _needle(_hold);
        if ((before < .5) != (_power < .5)) host.sfx(Sfx.tick, volume: .4, rate: 1.5);
        if (_hold > 6) _release();
      case _St.spin:
        final u = M.clamp01(_stT / _dur);
        final e = 1 - math.pow(1 - u, 4).toDouble();
        _theta = _from + (_to - _from) * e;
        final peg = (_theta / _a).floor();
        if (peg != _lastPeg) {
          _lastPeg = peg;
          _flap = 1;
          final speed = (1 - u);
          host.sfx(Sfx.click, volume: .5 + .5 * (1 - speed), rate: .8 + speed * .8);
        }
        _face = u > .7 ? Face.shocked : Face.happy;
        _bulbT += dt * (1 + (1 - u) * 6);
        if (u >= 1) _land();
      case _St.result:
        if (_result > 0 && _result < 100 && _stT > .8) {
          _st = _St.ready;
          _stT = 0;
          _power = 0;
          _face = Face.happy;
        }
      case _St.over:
        if ((_result == 100 || _result == 0) && chance(.4)) {
          host.fx.coins(Offset(rand(20, 340), 660), count: 2, speed: 850);
        }
      default:
        _bulbT += dt;
    }
  }

  // ---------------------------------------------------------------- input --

  @override
  void onDown(Offset p) {
    if (_st != _St.ready) return;
    _st = _St.hold;
    _stT = 0;
    _hold = 0;
    host.sfx(Sfx.powerup, volume: .5);
  }

  @override
  void onUp(Offset p) {
    if (_st == _St.hold) _release();
  }

  @override
  void onKey(String key, bool down) {
    if (key != 'action' && key != 'up') return;
    if (down) {
      onDown(Offset.zero);
    } else {
      onUp(Offset.zero);
    }
  }

  void _release() {
    if (_hold < .22) {
      // too short: just a wiggle
      _st = _St.ready;
      _theta += .05;
      _flap = 1;
      host.sfx(Sfx.boing, volume: .5);
      host.fx.pop(host.tr('hold', 'HOLD!'), const Offset(180, 470), color: Pal.yellow, size: 26);
      return;
    }
    final p = _power;
    final g = _gold;
    int target;
    double off;
    if (p <= _red || p > g[1]) {
      // Both red zones (too weak / overshoot) are BANKRUPT, as drawn.
      target = chance(.5) ? 3 : 9;
      off = rand(-.3, .3);
    } else if (p >= g[0] && p <= g[1]) {
      target = chance(.5) ? 0 : 6;
      off = pick(const [-.36, .36, -.3, .3]); // agonisingly close to the edge
    } else {
      final small = <int>[1, 2, 4, 5, 7, 8, 10, 11];
      target = pick(small);
      // near miss: land beside a jackpot slice when possible
      off = rand(-.35, .35);
    }
    _spins++;
    _st = _St.spin;
    _stT = 0;
    _from = _theta;
    final base = _theta + math.pi * 2 * (3 + p * 2);
    final want = -(target + .5 + off) * _a;
    var extra = (want - base) % (math.pi * 2);
    if (extra < 0) extra += math.pi * 2;
    _to = base + extra;
    _dur = 2.2 + p * .4;
    _lastPeg = (_theta / _a).floor();
    host.sfx(Sfx.spin);
    host.sfx(Sfx.whoosh);
    host.shake(4);
    if (p >= g[0] && p <= g[1]) {
      host.sfx(Sfx.rarityUp);
      host.fx.pop(host.tr('perfect', 'PERFECT!'), const Offset(180, 470), color: Pal.yellow, size: 28);
    }
  }

  @override
  void onTimeUp() {
    // A spin already in the air still counts: snap it to where it lands.
    if (_st == _St.spin) _land();
    if (!host.finished) host.lose();
  }

  int get _under {
    final a = ((-_theta) % (math.pi * 2) + math.pi * 2) % (math.pi * 2);
    return (a / _a).floor() % 12;
  }

  void _land() {
    _theta = _to;
    final kind = _slices[_under];
    _result = kind;
    _st = _St.result;
    _stT = 0;
    host.sfx(Sfx.reelStop);
    const top = Offset(180, 176);
    if (kind == 100 || kind == 0) {
      _st = _St.over;
      _face = Face.love;
      if (kind == 100) {
        _bank *= 100;
      } else {
        _carT = 0;
        _bank += 3000000;
        host.sfx(Sfx.engine, volume: .7);
      }
      host.sfx(Sfx.ssr);
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.cash);
      host.flash(Pal.white, .3);
      host.shake(16, .6);
      host.hitStop(.12);
      host.punch(.08);
      host.fx.confetti(count: 120);
      host.fx.coins(_c, count: 40, speed: 800);
      host.fx.burst(top, Pal.yellow, count: 40, speed: 420, shape: PartShape.star, gravity: 200);
      host.win(stars: _spins == 1 ? 3 : (_spins == 2 ? 2 : 1));
    } else if (kind == -1) {
      _st = _St.over;
      _face = Face.dead;
      _bank = 0;
      host.sfx(Sfx.buzzer);
      host.sfx(Sfx.jingleLose);
      host.shake(12, .5);
      host.flash(const Color(0xAA000000), .3);
      host.fx.smoke(top, count: 10, color: const Color(0xCC333333), size: 24);
      host.fx.pop(host.tr('bankrupt', 'BANKRUPT'), const Offset(180, 470), color: Pal.red, size: 34, life: 1.4);
      host.lose();
    } else {
      _bank *= kind;
      _face = Face.happy;
      host.sfx(Sfx.coins, rate: 1 + kind * .03);
      host.shake(5);
      host.fx.coins(top, count: 6 + kind, speed: 450);
      host.fx.pop('x$kind!', top + const Offset(0, 70), color: Pal.yellow, size: 36);
      host.fx.pop(host.tr('again', 'AGAIN!'), const Offset(180, 470), color: Pal.white, size: 26, life: 1.1);
    }
  }

  // --------------------------------------------------------------- render --

  @override
  void render(Canvas c) {
    _stage(c);
    _bankHud(c);
    _wheel(c);
    _pointer(c);
    _meter(c);
    _hostGuy(c);
    if (_carT >= 0) _car(c);
    if (_st == _St.over && (_result == 100 || _result == 0)) {
      final k = M.easeOutBack(M.clamp01(_stT / .4));
      D.title(c, _result == 100 ? 'x100!!' : host.tr('jackpot', 'JACKPOT!'), const Offset(180, 322), size: 50,
          color: D.hsv(_t * 400, .6, 1), scale: k, rotate: -.08);
    }
  }

  void _stage(Canvas c) {
    D.gradientBg(c, const [Color(0xFF4A0A3A), Color(0xFF7A1238), Color(0xFF2A0616)]);
    D.rays(c, _c, 700, const Color(0x14FFE27A), count: 18, t: _t * .2);
    // spotlights
    for (final sx in [-1.0, 1.0]) {
      final base = Offset(180 + sx * 200, 30);
      c.drawPath(
          Path()
            ..moveTo(base.dx, base.dy)
            ..lineTo(_c.dx - sx * 40 - 110, 640)
            ..lineTo(_c.dx - sx * 40 + 110, 640)
            ..close(),
          D.fill(const Color(0x14FFF4C0)));
    }
    // floor
    c.drawRect(const Rect.fromLTWH(0, 540, 360, 100), Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 540), const Offset(0, 640), const [Color(0xFF3A0C2A), Color(0xFF1A0410)], const [0, 1]));
    for (var i = 0; i < 9; i++) {
      c.drawLine(Offset(i * 45.0, 540), Offset(i * 45.0 - 60 + i * 12, 640), D.stroke(const Color(0x22FFFFFF), 1.5));
    }
    // curtains
    for (final left in [true, false]) {
      final x0 = left ? 0.0 : 360.0;
      final dir = left ? 1.0 : -1.0;
      final p = Path()..moveTo(x0, 36);
      p.lineTo(x0 + dir * 44, 36);
      for (var i = 0; i <= 10; i++) {
        final y = 36 + i * 50.0;
        p.lineTo(x0 + dir * (30 + 10 * math.sin(i * 1.3 + _t * 1.5) + i * 1.5), y);
      }
      p
        ..lineTo(x0, 560)
        ..close();
      c.drawPath(p, Paint()
        ..shader = ui.Gradient.linear(Offset(x0, 0), Offset(x0 + dir * 50, 0), const [Color(0xFF8C0A1E), Color(0xFFD0203A), Color(0xFF7A0818)], const [0, .6, 1]));
      for (var i = 1; i < 4; i++) {
        c.drawLine(Offset(x0 + dir * i * 10, 40), Offset(x0 + dir * i * 10, 555), D.stroke(const Color(0x33000000), 3));
      }
    }
    // valance
    for (var i = 0; i < 9; i++) {
      c.drawArc(Rect.fromLTWH(i * 40.0, 22, 40, 34), 0, math.pi, true, D.fill(const Color(0xFFB0152E)));
    }
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 40), D.fill(const Color(0xFFB0152E)));
    for (var i = 0; i < 9; i++) {
      c.drawCircle(Offset(20 + i * 40.0, 54), 3, D.fill(Pal.gold));
    }
  }

  void _bankHud(Canvas c) {
    const r = Rect.fromLTWH(84, 66, 192, 40);
    D.rrect(c, r, 20, const Color(0xEE1A0612), border: Pal.gold, borderWidth: 3);
    D.coin(c, const Offset(106, 86), 12, spin: _t * .7);
    final v = _bankDisp.round();
    D.text(c, _fmt(v), const Offset(196, 86), size: 22, color: v == 0 ? Pal.red : Pal.yellow, stroke: Pal.ink, strokeWidth: 5, maxWidth: 150);
  }

  static String _fmt(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  void _wheel(Canvas c) {
    // stand
    final stand = Path()
      ..moveTo(_c.dx - 18, _c.dy)
      ..lineTo(_c.dx + 18, _c.dy)
      ..lineTo(_c.dx + 56, 560)
      ..lineTo(_c.dx - 56, 560)
      ..close();
    c.drawPath(stand, D.fill(const Color(0xFF8C5A00)));
    c.drawPath(stand, D.stroke(Pal.ink, 4));
    D.shadow(c, const Offset(180, 562), 180, 22, .5);
    // outer glow + rim
    c.drawCircle(_c, _r + 22, _glow(const Color(0x88FFD23F), 16));
    c.drawCircle(_c, _r + 16, Paint()
      ..shader = ui.Gradient.radial(_c, _r + 16, const [Color(0xFFFFF4B0), Color(0xFFFFC53D), Color(0xFFB07000)], const [.85, .93, 1]));
    c.drawCircle(_c, _r + 16, D.stroke(Pal.ink, 4));
    // bulbs chasing
    for (var i = 0; i < 24; i++) {
      final a = i / 24 * math.pi * 2;
      final p = _c + Offset(math.cos(a), math.sin(a)) * (_r + 8);
      final on = ((_bulbT * 10).floor() + i) % 3 == 0;
      if (on) c.drawCircle(p, 7, _glow(const Color(0xCCFFF4C0), 4));
      c.drawCircle(p, 3.6, D.fill(on ? Pal.white : const Color(0xFF8C5A00)));
    }
    c.save();
    c.translate(_c.dx, _c.dy);
    c.rotate(_theta);
    final rect = Rect.fromCircle(center: Offset.zero, radius: _r);
    for (var i = 0; i < 12; i++) {
      final kind = _slices[i];
      final start = -math.pi / 2 + i * _a;
      Paint p;
      if (kind == 100) {
        p = Paint()
          ..shader = ui.Gradient.sweep(Offset.zero, const [Color(0xFFFFF4A0), Color(0xFFFFC53D), Color(0xFFFFF4A0)], const [0, .5, 1], ui.TileMode.clamp, start, start + _a);
      } else {
        p = D.fill(_sliceCols[kind]!);
      }
      c.drawArc(rect, start, _a, true, p);
      // lighter inner stripe
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: _r * .98), start + .02, _a - .04, false, D.stroke(const Color(0x33FFFFFF), 6));
    }
    for (var i = 0; i < 12; i++) {
      final a = -math.pi / 2 + i * _a;
      c.drawLine(Offset.zero, Offset(math.cos(a), math.sin(a)) * _r, D.stroke(Pal.ink, 3));
      // pegs
      final pg = Offset(math.cos(a), math.sin(a)) * (_r - 4);
      c.drawCircle(pg, 5, D.fill(Pal.white));
      c.drawCircle(pg, 5, D.stroke(Pal.ink, 2));
    }
    // labels
    for (var i = 0; i < 12; i++) {
      final kind = _slices[i];
      final mid = -math.pi / 2 + (i + .5) * _a;
      c.save();
      c.rotate(mid);
      c.translate(_r * .66, 0);
      c.rotate(math.pi / 2);
      switch (kind) {
        case -1:
          _skull(c, Offset.zero, 15);
        case 0:
          c.rotate(-math.pi / 2);
          _carIcon(c, Offset.zero, 17);
        case 100:
          D.text(c, 'x100', Offset.zero, size: 21, color: const Color(0xFFD01A2A), stroke: Pal.white, strokeWidth: 4, italic: true);
        default:
          D.text(c, 'x$kind', Offset.zero, size: 22, color: Pal.white, stroke: Pal.ink, strokeWidth: 5);
      }
      c.restore();
    }
    c.restore();
    c.drawCircle(_c, _r, D.stroke(Pal.ink, 4));
    // hub
    c.drawCircle(_c, 32, Paint()..shader = ui.Gradient.radial(_c + const Offset(-8, -8), 40, const [Color(0xFFFFF4B0), Color(0xFFFFC53D), Color(0xFFB07000)], const [0, .5, 1]));
    c.drawCircle(_c, 32, D.stroke(Pal.ink, 4));
    c.save();
    c.translate(_c.dx, _c.dy);
    c.rotate(_theta);
    D.star(c, Offset.zero, 20, Pal.red, border: Pal.ink);
    c.restore();
  }

  void _skull(Canvas c, Offset o, double r) {
    c.drawCircle(o + Offset(0, -r * .15), r * .8, D.fill(Pal.white));
    D.rrect(c, Rect.fromCenter(center: o + Offset(0, r * .55), width: r * .9, height: r * .5), 3, Pal.white);
    for (final sx in [-1.0, 1.0]) {
      c.drawCircle(o + Offset(sx * r * .32, -r * .15), r * .22, D.fill(const Color(0xFF231A2E)));
    }
    c.drawPath(
        Path()
          ..moveTo(o.dx, o.dy + r * .12)
          ..lineTo(o.dx - r * .12, o.dy + r * .32)
          ..lineTo(o.dx + r * .12, o.dy + r * .32)
          ..close(),
        D.fill(const Color(0xFF231A2E)));
  }

  void _carIcon(Canvas c, Offset o, double s) {
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: o + Offset(0, s * .1), width: s * 2.2, height: s * .7), Radius.circular(s * .25));
    final cab = Path()
      ..moveTo(o.dx - s * .6, o.dy - s * .25)
      ..lineTo(o.dx - s * .3, o.dy - s * .7)
      ..lineTo(o.dx + s * .45, o.dy - s * .7)
      ..lineTo(o.dx + s * .75, o.dy - s * .25)
      ..close();
    c.drawPath(cab, D.fill(const Color(0xFFBFE8FF)));
    c.drawPath(cab, D.stroke(Pal.ink, 2));
    c.drawRRect(body, D.fill(Pal.red));
    c.drawRRect(body, D.stroke(Pal.ink, 2));
    for (final sx in [-.65, .65]) {
      c.drawCircle(o + Offset(sx * s, s * .45), s * .28, D.fill(Pal.ink));
      c.drawCircle(o + Offset(sx * s, s * .45), s * .12, D.fill(const Color(0xFFCCCCCC)));
    }
  }

  void _pointer(Canvas c) {
    const pivot = Offset(180, 160);
    c.save();
    c.translate(pivot.dx, pivot.dy);
    c.rotate(-_flap * .45);
    final p = Path()
      ..moveTo(-16, 0)
      ..lineTo(16, 0)
      ..lineTo(0, 40)
      ..close();
    c.drawPath(p, D.fill(const Color(0xFFFF2D3F)));
    c.drawPath(p, D.stroke(Pal.ink, 3.5));
    c.drawLine(const Offset(-6, 6), const Offset(-2, 24), D.stroke(const Color(0x88FFFFFF), 3));
    c.restore();
    c.drawCircle(pivot, 9, D.fill(Pal.gold));
    c.drawCircle(pivot, 9, D.stroke(Pal.ink, 3));
  }

  void _meter(Canvas c) {
    const r = Rect.fromLTWH(56, 494, 248, 26);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(13));
    c.drawRRect(rr.shift(const Offset(0, 4)), D.fill(const Color(0x88000000)));
    c.save();
    c.clipRRect(rr);
    c.drawRect(r, D.fill(const Color(0xFF3A3050)));
    c.drawRect(Rect.fromLTWH(r.left, r.top, r.width * _red, r.height), D.fill(const Color(0xFF231A2E)));
    c.drawRect(Rect.fromLTWH(r.left + r.width * _red, r.top, r.width * (_gold[0] - _red), r.height), Paint()
      ..shader = ui.Gradient.linear(r.centerLeft, r.centerRight, const [Color(0xFF3FB8FF), Color(0xFF7ED957), Color(0xFFFF8A1F)], const [0, .4, .7]));
    final gRect = Rect.fromLTWH(r.left + r.width * _gold[0], r.top, r.width * (_gold[1] - _gold[0]), r.height);
    c.drawRect(Rect.fromLTWH(r.left + r.width * _gold[1], r.top, r.width * (1 - _gold[1]), r.height), D.fill(const Color(0xFFD0203A)));
    c.drawRect(gRect, Paint()
      ..shader = ui.Gradient.linear(gRect.topCenter, gRect.bottomCenter, [Pal.white, Color.lerp(Pal.gold, Pal.white, .3 * M.wave(_t, 3))!, const Color(0xFFFFB020)], const [0, .4, 1]));
    c.drawRect(Rect.fromLTWH(r.left, r.top + 3, r.width, 6), D.fill(const Color(0x33FFFFFF)));
    c.restore();
    c.drawRRect(rr, D.stroke(Pal.ink, 3));
    c.drawRect(gRect.inflate(3), _glow(Pal.yellow.withValues(alpha: .5 + .4 * M.wave(_t, 3)), 5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);
    c.drawRect(gRect, D.stroke(Pal.ink, 2.5));
    _skull(c, Offset(r.left + r.width * _red / 2, r.center.dy), 8);
    _skull(c, Offset(r.left + r.width * (1 + _gold[1]) / 2, r.center.dy), 8);
    D.star(c, gRect.center, 9, Pal.white, border: Pal.ink);
    // needle
    final nx = r.left + r.width * (_st == _St.hold ? _power : (_st == _St.ready ? 0 : _power));
    final np = Path()
      ..moveTo(nx, r.top + 4)
      ..lineTo(nx - 9, r.top - 14)
      ..lineTo(nx + 9, r.top - 14)
      ..close();
    c.drawPath(np, D.fill(Pal.white));
    c.drawPath(np, D.stroke(Pal.ink, 2.5));
    c.drawLine(Offset(nx, r.top), Offset(nx, r.bottom), D.stroke(Pal.white, 3));
    // spin lamps
    for (var i = 0; i < 3; i++) {
      final o = Offset(r.right + 20, r.top + 2 + i * 10.0);
      c.drawCircle(o, 3.5, D.fill(i < _spins ? const Color(0xFF55445E) : Pal.lime));
    }
    if (_st == _St.ready && !host.finished) {
      final k = M.wave(_t, 2);
      D.hand(c, Offset(180, 560 + k * 4), _t);
      D.title(c, host.tr('hold', 'HOLD!'), const Offset(180, 470), size: 30, scale: 1 + .05 * k);
    } else if (_st == _St.hold) {
      D.title(c, host.tr('release', 'RELEASE!'), const Offset(180, 470), size: 26,
          color: _power >= _gold[0] && _power <= _gold[1] ? Pal.yellow : Pal.white, scale: 1 + .08 * math.sin(_t * 20));
    }
  }

  void _hostGuy(Canvas c) {
    final bounce = _face == Face.love ? math.sin(_t * 14).abs() * 10 : 0.0;
    final feet = Offset(46, 624 - bounce);
    D.person(c, feet, 92, const Color(0xFF2A2A40), face: _face, hair: const Color(0xFF3A2A20), armsUp: _face == Face.love ? 1 : (_st == _St.spin ? .6 : 0));
    // bow tie
    final bt = feet + const Offset(0, -92 * .66);
    for (final sx in [-1.0, 1.0]) {
      c.drawPath(
          Path()
            ..moveTo(bt.dx, bt.dy)
            ..lineTo(bt.dx + sx * 9, bt.dy - 5)
            ..lineTo(bt.dx + sx * 9, bt.dy + 5)
            ..close(),
          D.fill(Pal.red));
    }
    // microphone
    c.drawLine(feet + const Offset(16, -60), feet + const Offset(22, -76), D.stroke(Pal.ink, 4));
    c.drawCircle(feet + const Offset(23, -79), 5, D.fill(const Color(0xFF8E93A8)));
  }

  void _car(Canvas c) {
    final u = M.easeOutBack(M.clamp01(_carT / .7));
    final x = M.lerp(460, 262, u);
    final o = Offset(x, 596 + math.sin(_t * 30) * (u < 1 ? 1.5 : 0));
    D.shadow(c, o + const Offset(0, 26), 150, 16, .4);
    c.drawCircle(o, 70, _glow(const Color(0x66FF5FC8), 20));
    D.rays(c, o, 90, const Color(0x33FFFFFF), count: 10, t: _t * 2);
    _carIcon(c, o, 44);
  }
}
