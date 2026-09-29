import '../engine/engine.dart';

/// No.069 Water It! — hold to pour. Stop inside the green zone. Too much and
/// the poor flower drowns.
class G069 extends MiniGame {
  double _t = 0;
  double _m = .12; // moisture 0..1 (1 = overflow)
  double _shown = .12;
  double _tilt = 0;
  bool _pouring = false;
  bool _keyHold = false;
  double _dropCd = 0;
  final List<_Drop> _drops = [];
  late final double _zl, _zh;
  int _state = 0; // 0 playing, 1 bloom, 2 drowned, 3 wilted
  double _endT = 0;
  double _splashCd = 0;
  double _bubbleCd = 0;
  late final Color _petal;

  static const _potC = Offset(180, 530);
  static const _soilY = 474.0;
  static const _canPivot = Offset(96, 200);

  @override
  void init() {
    final w = .2 / pow(host.speed, .4);
    _zl = rand(.5, .66);
    _zh = _zl + w;
    _petal = pick(const [Pal.pink, Pal.red, Pal.yellow, Pal.purple, Pal.orange]);
  }

  Offset get _spout {
    final a = -.2 + _tilt * .75;
    const local = Offset(92, -30);
    return _canPivot + Offset(local.dx * cos(a) - local.dy * sin(a), local.dx * sin(a) + local.dy * cos(a));
  }

  bool get _inZone => _m >= _zl && _m <= _zh;

  @override
  void update(double dt) {
    _t += dt;
    final holding = (host.pointerDown || _keyHold) && _state == 0 && !host.finished;
    _tilt = M.approach(_tilt, holding ? 1 : 0, 10, dt);
    final pour = _tilt > .55;
    if (pour != _pouring) {
      _pouring = pour;
      if (pour) host.sfx(Sfx.pour, volume: .7);
    }
    _dropCd -= dt;
    if (pour && _dropCd <= 0 && _state == 0) {
      _dropCd = 1 / 40;
      final s = _spout;
      _drops.add(_Drop(s + Offset(rand(-3, 3), rand(-3, 3)), Offset(rand(140, 190), rand(-30, 20))));
    }
    _splashCd -= dt;
    final perDrop = .0105 * pow(host.speed, .5);
    for (final d in _drops) {
      d.vel += Offset(0, 1100 * dt);
      d.pos += d.vel * dt;
      if (d.pos.dy >= _soilY && (d.pos.dx - _potC.dx).abs() < 80) {
        d.dead = true;
        if (_state == 0) _m += perDrop;
        if (_splashCd <= 0) {
          _splashCd = .08;
          host.fx.burst(Offset(d.pos.dx, _soilY), const Color(0xFF7FD3FF), count: 3, speed: 110, size: 4, gravity: 600);
        }
      } else if (d.pos.dy > 660) {
        d.dead = true;
      }
    }
    _drops.removeWhere((d) => d.dead);
    if (_state == 0) {
      _m = max(0, _m - .025 * dt); // evaporation
      if (_m >= 1) _drown();
    }
    _shown = M.approach(_shown, _m, 12, dt);
    if (_state != 0) _endT += dt;
    if (_state == 2) {
      _bubbleCd -= dt;
      if (_bubbleCd <= 0) {
        _bubbleCd = .15;
        host.fx.add(Particle(
            pos: _potC + Offset(rand(-60, 60), -60),
            vel: Offset(rand(-10, 10), rand(-80, -40)),
            life: .9,
            color: const Color(0xCCBFE8FF),
            size: rand(5, 10),
            shape: PartShape.ring));
      }
    }
  }

  void _drown() {
    _state = 2;
    _m = 1.05;
    host.sfx(Sfx.splash);
    host.sfx(Sfx.bubble, rate: .8);
    host.shake(6);
    host.fx.burst(_potC + const Offset(0, -60), const Color(0xFF7FD3FF), count: 20, speed: 260, gravity: 700);
    host.fx.pop(host.tr('too_much', 'TOO MUCH!'), const Offset(180, 300), color: Pal.sky, size: 36);
    host.lose();
  }

  @override
  void onKey(String key, bool down) {
    if (key == 'action' || key == 'down') _keyHold = down;
  }

  @override
  void onTimeUp() {
    if (_state != 0) return;
    if (_inZone) {
      _state = 1;
      host.sfx(Sfx.magic);
      host.sfx(Sfx.correct, volume: .8);
      host.punch(.06);
      host.shake(4);
      host.fx.sparkle(_potC + const Offset(0, -250), count: 20, radius: 70, color: Pal.yellow);
      host.fx.burst(_potC + const Offset(0, -250), _petal, count: 16, speed: 260, shape: PartShape.star);
      final mid = (_zl + _zh) / 2, half = (_zh - _zl) / 2;
      final k = (_m - mid).abs() / half;
      host.fx.pop(k < .4 ? host.tr('perfect', 'PERFECT!') : host.tr('bloom', 'BLOOM!'), const Offset(180, 150),
          color: Pal.lime, size: 38);
      host.win(stars: k < .4 ? 3 : (k < .75 ? 2 : 1));
    } else {
      _state = 3;
      host.sfx(Sfx.aww);
      host.fx.pop(_m > _zh ? host.tr('too_much', 'TOO MUCH!') : host.tr('more', 'MORE!'), const Offset(180, 200),
          color: Pal.red, size: 34);
      host.lose();
    }
  }

  @override
  void render(Canvas c) {
    // sunny window
    D.gradientBg(c, const [Color(0xFF7ED3FF), Color(0xFFBDEBFF), Color(0xFFFFF2B8)]);
    D.rays(c, const Offset(300, 110), 700, const Color(0x2EFFF3A0), count: 16, t: _t * .25);
    D.circle(c, const Offset(300, 110), 40, Pal.yellow, border: const Color(0xFFFFA928), borderWidth: 5);
    D.face(c, const Offset(300, 112), 30, _state == 1 ? Face.happy : (_state >= 2 ? Face.sad : Face.smug), blush: true);
    D.cloud(c, Offset(60 + sin(_t * .5) * 10, 90), 60);
    D.cloud(c, Offset(210 + sin(_t * .4 + 2) * 10, 60), 44);
    // table
    c.drawRect(const Rect.fromLTWH(0, 590, 360, 50), D.fill(const Color(0xFFB9784F)));
    D.line(c, const Offset(0, 590), const Offset(360, 590), Pal.ink, 4);
    c.drawRect(const Rect.fromLTWH(0, 598, 360, 6), D.fill(const Color(0x33000000)));

    _drawFlower(c);
    _drawPot(c);
    // water drops
    final dp = D.fill(const Color(0xFF4FB4FF));
    final dh = D.fill(const Color(0xCCFFFFFF));
    for (final d in _drops) {
      c.drawOval(Rect.fromCenter(center: d.pos, width: 8, height: 12), dp);
      c.drawCircle(d.pos + const Offset(-1.5, -2), 1.6, dh);
    }
    _drawCan(c);
    _drawGauge(c);

    if (host.time < 1.8 && _state == 0 && !host.pointerDown) {
      D.hand(c, const Offset(180, 380), _t);
      D.text(c, host.tr('hold', 'HOLD!'), const Offset(180, 350), size: 26, stroke: Pal.ink);
    }
  }

  void _drawPot(Canvas c) {
    const o = _potC;
    // soil (darkens with moisture)
    final soil = Color.lerp(const Color(0xFFB08050), const Color(0xFF3A2414), M.clamp01(_shown))!;
    final pot = Path()
      ..moveTo(o.dx - 76, o.dy - 60)
      ..lineTo(o.dx + 76, o.dy - 60)
      ..lineTo(o.dx + 56, o.dy + 60)
      ..lineTo(o.dx - 56, o.dy + 60)
      ..close();
    D.shadow(c, o + const Offset(0, 62), 150, 16, .2);
    c.drawPath(pot, D.fill(const Color(0xFFE0703A)));
    c.drawPath(pot, D.stroke(Pal.ink, 5));
    // face on the pot
    D.face(c, o + const Offset(0, 16), 34,
        _state == 1 ? Face.happy : (_state == 2 ? Face.shocked : (_state == 3 ? Face.cry : (_inZone ? Face.smug : Face.neutral))),
        blush: true);
    // rim
    final rim = Rect.fromCenter(center: o + const Offset(0, -62), width: 176, height: 30);
    D.rrect(c, rim, 10, const Color(0xFFF08A50), border: Pal.ink, borderWidth: 5);
    c.drawOval(Rect.fromCenter(center: o + const Offset(0, -66), width: 150, height: 14), D.fill(soil));
    if (_state == 2) {
      // overflow puddles
      final k = M.clamp01(_endT * 3);
      c.drawOval(Rect.fromCenter(center: o + const Offset(0, -66), width: 150, height: 14), D.fill(const Color(0xCC4FB4FF)));
      for (final s in [-1.0, 1.0]) {
        final path = Path()
          ..moveTo(o.dx + s * 80, o.dy - 66)
          ..quadraticBezierTo(o.dx + s * 90, o.dy, o.dx + s * 70, o.dy + 60 * k);
        c.drawPath(path, D.stroke(const Color(0xCC4FB4FF), 12));
      }
      c.drawOval(Rect.fromCenter(center: o + const Offset(0, 64), width: 240 * k, height: 18 * k), D.fill(const Color(0xAA4FB4FF)));
    }
  }

  void _drawFlower(Canvas c) {
    // straightness from moisture
    var straight = M.clamp01(_shown / _zl);
    if (_state == 3 && _m < _zl) straight = M.clamp01(straight - _endT);
    final droop = (1 - straight);
    final base = _potC + const Offset(0, -66);
    final grow = _state == 1 ? M.easeOutBack(M.clamp01(_endT * 2.5)) : 0.0;
    final height = 190.0 + grow * 20;
    final sway = sin(_t * 2) * 4 * straight;
    final head = base + Offset(droop * 70 + sway, -height * (1 - droop * .55));
    final ctrl = base + Offset(-droop * 10, -height * .75);
    final stem = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, head.dx, head.dy);
    c.drawPath(stem, D.stroke(Pal.ink, 13));
    c.drawPath(stem, D.stroke(const Color(0xFF3FB84A), 8));
    // leaves
    for (final s in [-1.0, 1.0]) {
      final lp = base + Offset(s * 6, -60 - (s > 0 ? 30 : 0));
      c.save();
      c.translate(lp.dx, lp.dy);
      c.rotate(s * (.9 + droop * .9));
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(18, -22, 0, -50)
        ..quadraticBezierTo(-18, -22, 0, 0);
      c.drawPath(leaf, D.fill(const Color(0xFF5ED35A)));
      c.drawPath(leaf, D.stroke(Pal.ink, 4));
      c.restore();
    }
    // head
    final tilt = droop * 1.9;
    final bloom = _state == 1 ? 1.0 : M.clamp01((_shown - _zl * .6) / (_zl * .5)) * .55;
    final drowned = _state == 2;
    c.save();
    c.translate(head.dx, head.dy);
    c.rotate(tilt);
    final pr = 22 + bloom * 26;
    final petalCol = drowned ? const Color(0xFF7A9AC8) : (droop > .6 ? Color.lerp(_petal, const Color(0xFF9A7A5A), .5)! : _petal);
    final n = 8;
    for (var i = 0; i < n; i++) {
      final a = i * pi * 2 / n + _t * (_state == 1 ? 1.5 : 0);
      final po = Offset(cos(a), sin(a)) * pr * .8;
      c.save();
      c.translate(po.dx, po.dy);
      c.rotate(a);
      final pw = 18 + bloom * 16;
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: pw * 1.4, height: pw), D.fill(petalCol));
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: pw * 1.4, height: pw), D.stroke(Pal.ink, 3.5));
      c.restore();
    }
    c.drawCircle(Offset.zero, 24, D.fill(const Color(0xFFFFC53D)));
    c.drawCircle(Offset.zero, 24, D.stroke(Pal.ink, 4));
    c.rotate(-tilt * .6);
    final f = _state == 1
        ? Face.love
        : drowned
            ? Face.dead
            : (droop > .5 ? Face.sleepy : (_inZone ? Face.happy : Face.neutral));
    D.face(c, Offset.zero, 22, f, blush: true);
    c.restore();
    if (droop > .6 && _state == 0) {
      // "sweat" of thirst
      c.drawCircle(head + Offset(30, -20 + (_t * 30) % 16), 4, D.fill(const Color(0xFF7FD3FF)));
    }
  }

  void _drawCan(Canvas c) {
    final a = -.2 + _tilt * .75 + (_pouring ? sin(_t * 30) * .01 : 0);
    c.save();
    c.translate(_canPivot.dx, _canPivot.dy);
    c.rotate(a);
    // spout
    final spout = Path()
      ..moveTo(20, 10)
      ..lineTo(86, -34)
      ..lineTo(94, -24)
      ..lineTo(34, 26)
      ..close();
    c.drawPath(spout, D.fill(const Color(0xFF3FB8FF)));
    c.drawPath(spout, D.stroke(Pal.ink, 4));
    D.rrect(c, const Rect.fromLTWH(82, -42, 18, 22), 5, const Color(0xFF2A8AD0), border: Pal.ink, borderWidth: 3.5);
    // body
    const body = Rect.fromLTWH(-50, -30, 80, 76);
    D.rrect(c, body, 14, const Color(0xFF3FB8FF), border: Pal.ink, borderWidth: 5);
    D.rrect(c, const Rect.fromLTWH(-44, -24, 16, 60), 8, const Color(0x55FFFFFF));
    // handle
    c.drawArc(const Rect.fromLTWH(-46, -64, 64, 60), pi, pi, false, D.stroke(Pal.ink, 13));
    c.drawArc(const Rect.fromLTWH(-46, -64, 64, 60), pi, pi, false, D.stroke(const Color(0xFF2A8AD0), 7));
    D.heart(c, const Offset(-10, 10), 22, Pal.white);
    c.restore();
  }

  void _drawGauge(Canvas c) {
    const r = Rect.fromLTWH(318, 150, 26, 300);
    D.rrect(c, r.inflate(4), 16, Pal.white, border: Pal.ink, borderWidth: 4);
    double yOf(double v) => r.bottom - v * r.height;
    // zones
    c.drawRect(Rect.fromLTRB(r.left, yOf(1), r.right, yOf(_zh)), D.fill(const Color(0x55FF3B5C)));
    c.drawRect(Rect.fromLTRB(r.left, yOf(_zh), r.right, yOf(_zl)),
        D.fill(Pal.green.withValues(alpha: .55 + .35 * M.wave(_t, 2))));
    // water level
    final lv = M.clamp01(_shown);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)));
    final top = yOf(lv);
    final wave = Path()..moveTo(r.left, top);
    for (var x = 0.0; x <= r.width; x += 4) {
      wave.lineTo(r.left + x, top + sin(_t * 8 + x * .4) * 2);
    }
    wave
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..close();
    c.drawPath(wave, D.fill(const Color(0xCC3F8CFF)));
    c.restore();
    for (final v in [_zl, _zh]) {
      D.line(c, Offset(r.left - 8, yOf(v)), Offset(r.right + 8, yOf(v)), Pal.ink, 3);
    }
    // droplet icon
    final dp = Path()
      ..moveTo(331, 108)
      ..quadraticBezierTo(346, 128, 331, 136)
      ..quadraticBezierTo(316, 128, 331, 108);
    c.drawPath(dp, D.fill(const Color(0xFF3F8CFF)));
    c.drawPath(dp, D.stroke(Pal.ink, 3));
    // pointer arrow
    final ay = yOf(lv);
    final ar = Path()
      ..moveTo(r.left - 6, ay)
      ..lineTo(r.left - 20, ay - 9)
      ..lineTo(r.left - 20, ay + 9)
      ..close();
    c.drawPath(ar, D.fill(_inZone ? Pal.lime : Pal.yellow));
    c.drawPath(ar, D.stroke(Pal.ink, 3));
  }
}

class _Drop {
  _Drop(this.pos, this.vel);
  Offset pos;
  Offset vel;
  bool dead = false;
}
