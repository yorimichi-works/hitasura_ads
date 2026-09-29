import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.027 Mars Colony Crisis — neon survival balancing act.
/// Keep O2 / POWER / FOOD up with the module buttons (each boost costs another
/// resource) and laser incoming meteors. Finish with 60+ colonists.
class G027 extends MiniGame {
  static const _cols = [Color(0xFF3DF2FF), Color(0xFFFFE040), Color(0xFF7CFF4F)];
  static const _pink = Color(0xFFFF3DCB);
  static const _domes = [Offset(66, 392), Offset(180, 392), Offset(294, 392)];
  static const _domeR = [42.0, 56.0, 42.0];
  static const _turret = Offset(180, 330);
  static const _goal = 60;

  final List<double> _res = [.78, .74, .76];
  final List<double> _press = [0, 0, 0];
  final List<double> _cost = [0, 0, 0];
  final List<double> _cool = [0, 0, 0];
  final List<double> _phase = [0, 0, 0];
  final List<_Meteor> _meteors = [];
  final List<int> _cracks = [0, 0, 0];
  final List<double> _domeHit = [0, 0, 0];
  final List<Offset> _stars = [];
  double _colonists = 100;
  double _shownCol = 100;
  double _t = 0;
  double _spawnT = 2.2;
  double _laserT = 0;
  Offset _laserTo = Offset.zero;
  int _boosts = 0;
  int _kills = 0;
  double _alarm = 0;
  double _storm = 0;
  bool _stormDone = false;
  bool _dead = false;

  final Paint _glow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
  final Paint _core = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;
  final Paint _fillGlow = Paint()..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);

  static Rect _btn(int i) => Rect.fromLTWH(14 + i * 114.0, 574, 104, 48);
  static Offset _dial(int i) => Offset(66 + i * 114.0, 522);

  @override
  void init() {
    for (var i = 0; i < 70; i++) {
      _stars.add(Offset(rand(0, 360), rand(40, 380)));
    }
    for (var i = 0; i < 3; i++) {
      _phase[i] = rand(0, 6);
    }
  }

  void _neon(Canvas c, Path p, Color col, double w) {
    _glow
      ..color = col.withValues(alpha: .75)
      ..strokeWidth = w * 3;
    c.drawPath(p, _glow);
    _core
      ..color = Color.lerp(col, Pal.white, .55)!
      ..strokeWidth = w;
    c.drawPath(p, _core);
  }

  void _neonLine(Canvas c, Offset a, Offset b, Color col, double w) {
    _glow
      ..color = col.withValues(alpha: .75)
      ..strokeWidth = w * 3;
    c.drawLine(a, b, _glow);
    _core
      ..color = Color.lerp(col, Pal.white, .55)!
      ..strokeWidth = w;
    c.drawLine(a, b, _core);
  }

  @override
  void update(double dt) {
    _t += dt;
    for (var i = 0; i < 3; i++) {
      _press[i] = max(0, _press[i] - dt * 4);
      _cost[i] = max(0, _cost[i] - dt * 2);
      _cool[i] = max(0, _cool[i] - dt);
      _domeHit[i] = max(0, _domeHit[i] - dt * 2.5);
    }
    _laserT = max(0, _laserT - dt);
    _shownCol = M.approach(_shownCol, _colonists, 8, dt);
    if (_dead) return;

    // dust storm event: power drains faster for a while
    if (!_stormDone && host.time > 9) {
      _stormDone = true;
      _storm = 4;
      host.sfx(Sfx.wind);
      host.sfx(Sfx.glitch, volume: .6);
      host.flash(const Color(0x44FF3DCB));
    }
    _storm = max(0, _storm - dt);

    // resources drain at wobbling rates
    const base = [.05, .045, .04];
    var loss = 0.0;
    for (var i = 0; i < 3; i++) {
      var d = base[i] * (1 + .6 * sin(_t * (.7 + i * .23) + _phase[i])) * host.speed;
      if (i == 1 && _storm > 0) d *= 2.2;
      _res[i] = max(0, _res[i] - d * dt);
      if (_res[i] <= 0) {
        loss += 6;
      } else if (_res[i] < .2) {
        loss += 1.8;
      }
    }
    _alarm = loss > 0 ? _alarm + dt : 0;
    if (loss > 0) {
      _hurt(loss * dt);
      if ((_t * 2).floor() != ((_t - dt) * 2).floor()) host.sfx(Sfx.beep, volume: .45, rate: 1.4);
    }

    // meteors
    _spawnT -= dt * host.speed;
    if (_spawnT <= 0) {
      _spawnT = max(.8, 1.5 - host.time * .03) * rand(.8, 1.2);
      final target = randInt(3);
      final start = Offset(rand(20, 340), 30);
      final end = _domes[target] + Offset(rand(-20, 20), -_domeR[target] * .7);
      final dir = end - start;
      _meteors.add(_Meteor(start, dir / dir.distance * rand(85, 120), target, rand(9, 14)));
    }
    for (final m in _meteors) {
      m.pos += m.vel * dt * host.speed;
      m.spin += dt * 5;
      final dome = _domes[m.target];
      if ((m.pos - dome).distance < _domeR[m.target] + m.r * .4 && m.pos.dy > dome.dy - _domeR[m.target] - 4) {
        m.dead = true;
        _impact(m);
      }
    }
    _meteors.removeWhere((m) => m.dead);
  }

  void _hurt(double n) {
    if (_dead) return;
    _colonists = max(0, _colonists - n);
    if (_colonists < _goal) {
      _dead = true;
      host.sfx(Sfx.explode);
      host.sfx(Sfx.jingleLose);
      host.shake(12);
      host.flash(const Color(0x88FF2040), .4);
      for (var i = 0; i < 3; i++) {
        _domeHit[i] = 1;
        host.fx.burst(_domes[i], _pink, count: 20, speed: 260);
      }
      host.lose();
    }
  }

  void _impact(_Meteor m) {
    final i = m.target;
    _cracks[i] = min(4, _cracks[i] + 1);
    _domeHit[i] = 1;
    host.sfx(Sfx.explode);
    host.sfx(Sfx.glass, volume: .6);
    host.shake(9);
    host.hitStop(.05);
    host.flash(const Color(0x55FF6A00));
    host.fx.burst(m.pos, const Color(0xFFFF8A1F), count: 26, speed: 280, size: 7, colors: const [Color(0xFFFF8A1F), Pal.yellow, _pink]);
    host.fx.ring(m.pos, const Color(0xFFFF8A1F), size: 80);
    host.fx.pop('-7', m.pos + const Offset(0, -30), color: Pal.red, size: 28);
    _hurt(7);
  }

  void _boost(int i) {
    if (_cool[i] > 0 || _dead) return;
    _cool[i] = .22;
    _boosts++;
    final j = (i + 1) % 3;
    _res[i] = min(1, _res[i] + .22);
    _res[j] = max(0, _res[j] - .07);
    _press[i] = 1;
    _cost[j] = 1;
    host.sfx(Sfx.powerup, rate: .9 + _res[i] * .5, volume: .8);
    host.fx.burst(_dial(i), _cols[i], count: 10, speed: 170, size: 5, gravity: 0);
    host.fx.ring(_dial(i), _cols[i], size: 44, life: .3);
    host.punch(.012);
  }

  @override
  void onDown(Offset p) {
    if (_dead) return;
    // meteors first (generous hitbox)
    _Meteor? best;
    var bd = 40.0;
    for (final m in _meteors) {
      final d = (m.pos - p).distance;
      if (d < bd) {
        bd = d;
        best = m;
      }
    }
    if (best != null) {
      best.dead = true;
      _kills++;
      _laserT = .16;
      _laserTo = best.pos;
      host.sfx(Sfx.laser, rate: 1 + min(_kills, 10) * .04);
      host.sfx(Sfx.explodeSmall, volume: .7);
      host.fx.burst(best.pos, _cols[0], count: 18, speed: 240, size: 6, gravity: 0, colors: [_cols[0], Pal.white, _pink]);
      host.fx.ring(best.pos, _pink, size: 50, life: .3);
      host.addScore(100, best.pos + const Offset(0, -20));
      if (_kills % 5 == 0) host.fx.pop('${host.tr('combo', 'COMBO')} $_kills', best.pos + const Offset(0, -50), color: _pink);
      return;
    }
    for (var i = 0; i < 3; i++) {
      final hit = _btn(i).inflate(6).contains(p) || (p - _dial(i)).distance < 44;
      if (hit) {
        _boost(i);
        return;
      }
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'left') _boost(0);
    if (key == 'up' || key == 'action') _boost(1);
    if (key == 'right') _boost(2);
  }

  @override
  void onTimeUp() {
    if (_colonists >= _goal) {
      host.fx.confetti();
      host.sfx(Sfx.fanfare);
      host.win(stars: _colonists >= 90 ? 3 : (_colonists >= 75 ? 2 : 1));
    } else {
      host.lose();
    }
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF05021A), Color(0xFF16063A), Color(0xFF3A0A48)]);
    // stars
    final sp = Paint();
    for (var i = 0; i < _stars.length; i++) {
      final tw = .3 + .7 * M.wave(_t + i * .37, .5 + (i % 5) * .2);
      sp.color = Color.fromRGBO(255, 255, 255, tw * .8);
      c.drawCircle(_stars[i], i % 7 == 0 ? 1.8 : 1, sp);
    }
    // neon moon (Phobos) with ring
    _fillGlow.color = const Color(0x55FF3DCB);
    c.drawCircle(const Offset(290, 150), 34, _fillGlow);
    c.drawCircle(const Offset(290, 150), 30, D.fill(const Color(0xFF2A0A40)));
    _neon(c, Path()..addOval(Rect.fromCircle(center: const Offset(290, 150), radius: 30)), _pink, 2);
    _neon(c, Path()..addOval(Rect.fromCenter(center: const Offset(290, 150), width: 96, height: 20)), const Color(0xFFB36BFF), 1.5);
    c.drawCircle(const Offset(290, 150), 30, D.fill(const Color(0xFF2A0A40)));
    _neon(c, Path()..addArc(Rect.fromCircle(center: const Offset(290, 150), radius: 30), pi, pi), _pink, 2);

    // mountains outline
    final mtn = Path()..moveTo(0, 370);
    const pts = [(40.0, 330.0), (80.0, 356.0), (130.0, 316.0), (170.0, 350.0), (230.0, 322.0), (280.0, 352.0), (320.0, 334.0), (360.0, 360.0)];
    for (final p in pts) {
      mtn.lineTo(p.$1, p.$2);
    }
    final mfill = Path.from(mtn)
      ..lineTo(360, 392)
      ..lineTo(0, 392)
      ..close();
    c.drawPath(mfill, D.fill(const Color(0xFF1C0730)));
    _neon(c, mtn, const Color(0xFFB36BFF), 1.5);

    // terrain grid (synthwave)
    c.drawRect(const Rect.fromLTWH(0, 392, 360, 100), D.fill(const Color(0xFF200418)));
    const vp = Offset(180, 340);
    final gp = Paint()
      ..color = const Color(0x99FF3D7A)
      ..strokeWidth = 1.2;
    for (var i = -8; i <= 8; i++) {
      final bx = 180 + i * 50.0;
      final a = Offset.lerp(vp, Offset(bx, 500), (392 - vp.dy) / (500 - vp.dy))!;
      c.drawLine(a, Offset(bx, 500), gp);
    }
    for (var k = 0; k < 7; k++) {
      final f = ((k + (_t * .8) % 1) / 7);
      final y = 392 + pow(f, 2) * 110;
      c.drawLine(Offset(0, y.toDouble()), Offset(360, y.toDouble()), gp);
    }
    _neonLine(c, const Offset(0, 392), const Offset(360, 392), const Color(0xFFFF3D7A), 2);

    // domes
    for (var i = 0; i < 3; i++) {
      _drawDome(c, i);
    }
    // turret
    final aim = _meteors.isNotEmpty ? _meteors.first.pos : const Offset(180, 100);
    final ad = aim - _turret;
    final dir = ad / max(ad.distance, 1);
    _neonLine(c, _turret, _turret + dir * 22, _cols[0], 4);
    c.drawCircle(_turret, 8, D.fill(const Color(0xFF0B1A2A)));
    _neon(c, Path()..addOval(Rect.fromCircle(center: _turret, radius: 8)), _cols[0], 2);

    // meteors
    for (final m in _meteors) {
      final back = m.pos - m.vel / m.vel.distance * (m.r * 4.5);
      _glow
        ..color = const Color(0xAAFF8A1F)
        ..strokeWidth = m.r * 2.2;
      c.drawLine(back, m.pos, _glow);
      _core
        ..color = const Color(0xFFFFE0A0)
        ..strokeWidth = m.r * .7;
      c.drawLine(Offset.lerp(back, m.pos, .4)!, m.pos, _core);
      _fillGlow.color = const Color(0xCCFF6A1F);
      c.drawCircle(m.pos, m.r * 1.3, _fillGlow);
      c.drawCircle(m.pos, m.r, D.fill(const Color(0xFF3A1A10)));
      _neon(c, Path()..addOval(Rect.fromCircle(center: m.pos, radius: m.r)), const Color(0xFFFF8A1F), 2);
      c.drawCircle(m.pos + Offset(cos(m.spin), sin(m.spin)) * m.r * .4, m.r * .25, D.fill(const Color(0xFFFF8A1F)));
      // danger reticle
      final rr = m.r + 8 + 3 * sin(_t * 10);
      _core
        ..color = const Color(0x88FF3DCB)
        ..strokeWidth = 1.5;
      c.drawCircle(m.pos, rr, _core);
    }

    // laser
    if (_laserT > 0) {
      final k = _laserT / .16;
      _glow
        ..color = _pink.withValues(alpha: k)
        ..strokeWidth = 14 * k;
      c.drawLine(_turret, _laserTo, _glow);
      _core
        ..color = Color.fromRGBO(255, 255, 255, k)
        ..strokeWidth = 3;
      c.drawLine(_turret, _laserTo, _core);
    }

    // panel
    D.rrect(c, const Rect.fromLTWH(0, 470, 360, 170), 0, const Color(0xE0080418));
    _neonLine(c, const Offset(0, 470), const Offset(360, 470), _cols[0], 1.5);
    for (var i = 0; i < 3; i++) {
      _drawDial(c, i);
    }

    _drawHud(c);

    // storm overlay
    if (_storm > 0) {
      final a = min(1.0, _storm) * .25;
      final p = Paint()..color = Color.fromRGBO(255, 120, 60, a);
      for (var i = 0; i < 30; i++) {
        final x = (i * 53 + _t * 420) % 400 - 20;
        final y = 60.0 + (i * 97) % 400;
        c.drawLine(Offset(x, y), Offset(x - 26, y + 4), p..strokeWidth = 2);
      }
      D.text(c, host.tr('danger', 'DANGER!'), Offset(180, 452 + sin(_t * 12) * 2), size: 18, color: Pal.white, stroke: _pink);
    }

    if (_alarm > 0 && (_t * 4).floor().isEven) {
      c.drawRect(const Rect.fromLTWH(0, 36, 360, 604), D.stroke(const Color(0xAAFF2040), 10));
    }

    // tutorials
    if (_boosts == 0 && host.time < 4.5) {
      final lowest = _res.indexOf(_res.reduce(min));
      D.hand(c, _btn(lowest).center, _t);
    }
    if (_kills == 0 && _meteors.isNotEmpty && host.time < 8) {
      final m = _meteors.first;
      D.text(c, host.tr('tap', 'TAP!'), m.pos + const Offset(0, -34), size: 20, color: Pal.white, stroke: _pink);
    }
  }

  void _drawDome(Canvas c, int i) {
    final o = _domes[i];
    final r = _domeR[i];
    final hit = _domeHit[i];
    final col = Color.lerp(_cols[0], const Color(0xFFFF4060), hit)!;
    final rect = Rect.fromCircle(center: o, radius: r);
    // interior glow
    c.drawArc(rect, pi, pi, true,
        Paint()
          ..shader = ui.Gradient.radial(o, r, [col.withValues(alpha: .28), col.withValues(alpha: .05)]));
    // buildings inside
    final bp = D.fill(const Color(0xFF0E2A3A));
    for (var k = 0; k < 4; k++) {
      final bx = o.dx - r * .6 + k * r * .34;
      final bh = r * (.25 + ((k * 7 + i * 3) % 5) * .08);
      c.drawRect(Rect.fromLTWH(bx, o.dy - bh, r * .24, bh), bp);
      for (var w = 0; w < 2; w++) {
        final on = ((_t * 1.5 + k + w + i).floor() % 3) != 0 && !_dead;
        c.drawRect(Rect.fromLTWH(bx + 3, o.dy - bh + 4 + w * 8, 4, 3),
            D.fill(on ? const Color(0xFFFFE040) : const Color(0xFF223344)));
      }
    }
    // shell
    _neon(c, Path()..addArc(rect, pi, pi), col, 2.5);
    _neon(c, Path()..addArc(rect.deflate(r * .35), pi * 1.1, pi * .3), const Color(0x88FFFFFF), 1);
    // lattice
    _core
      ..color = col.withValues(alpha: .35)
      ..strokeWidth = 1;
    for (var k = 1; k < 4; k++) {
      final a = pi + k * pi / 4;
      c.drawLine(o, o + Offset(cos(a), sin(a)) * r, _core);
    }
    // cracks
    for (var k = 0; k < _cracks[i]; k++) {
      final a = pi + (k * 1.3 + .6) % pi;
      final p0 = o + Offset(cos(a), sin(a)) * r;
      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..relativeLineTo(8 - k * 3.0, 9)
        ..relativeLineTo(-6, 7)
        ..relativeLineTo(5, 8);
      _neon(c, path, const Color(0xFFFF4060), 1.5);
    }
  }

  void _drawDial(Canvas c, int i) {
    final o = _dial(i);
    final v = _res[i];
    final low = v < .2;
    final col = low && (_t * 6).floor().isEven ? const Color(0xFFFF4060) : _cols[i];
    const start = pi * .8, sweep = pi * 1.4;
    final rect = Rect.fromCircle(center: o, radius: 36);
    _core
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 8;
    c.drawArc(rect, start, sweep, false, _core);
    if (v > 0) {
      _glow
        ..color = col.withValues(alpha: .7)
        ..strokeWidth = 16;
      c.drawArc(rect, start, sweep * v, false, _glow);
      _core
        ..color = Color.lerp(col, Pal.white, .3)!
        ..strokeWidth = 8;
      c.drawArc(rect, start, sweep * v, false, _core);
    }
    // danger zone tick
    _core
      ..color = const Color(0xAAFF4060)
      ..strokeWidth = 3;
    c.drawArc(rect.inflate(7), start, sweep * .2, false, _core);
    // needle
    final a = start + sweep * v;
    _neonLine(c, o, o + Offset(cos(a), sin(a)) * 26, Pal.white, 2);
    c.drawCircle(o, 4, D.fill(Pal.white));
    // label + value
    final label = [('O2'), host.tr('power', 'Power'), host.tr('food', 'Food')][i];
    D.text(c, label, o + const Offset(0, 16), size: 13, color: col, maxWidth: 70);
    D.text(c, '${(v * 100).round()}', o + const Offset(0, -12), size: 16, color: Pal.white, stroke: const Color(0xFF080418), strokeWidth: 3);
    if (_cost[i] > 0) {
      D.text(c, '-', o + Offset(30, -36 - (1 - _cost[i]) * 12), size: 26, color: const Color(0xFFFF4060), stroke: Pal.ink);
    }
    // button
    final b = _btn(i);
    final pr = _press[i];
    final br = b.deflate(pr * 3);
    c.drawRRect(RRect.fromRectAndRadius(br, const Radius.circular(14)), D.fill(_cols[i].withValues(alpha: .14 + pr * .4)));
    _neon(c, Path()..addRRect(RRect.fromRectAndRadius(br, const Radius.circular(14))), _cols[i], 2);
    _drawModuleIcon(c, i, br.center + const Offset(-18, 0));
    D.text(c, '+', br.center + const Offset(20, -1), size: 30, color: Pal.white, stroke: _cols[i], strokeWidth: 3);
  }

  void _drawModuleIcon(Canvas c, int i, Offset o) {
    final col = _cols[i];
    switch (i) {
      case 0: // O2 bubbles
        _neon(c, Path()..addOval(Rect.fromCircle(center: o + const Offset(-4, 3), radius: 8)), col, 1.8);
        _neon(c, Path()..addOval(Rect.fromCircle(center: o + const Offset(7, -6), radius: 5)), col, 1.8);
      case 1: // bolt
        final p = Path()
          ..moveTo(o.dx + 3, o.dy - 13)
          ..lineTo(o.dx - 7, o.dy + 2)
          ..lineTo(o.dx + 1, o.dy + 2)
          ..lineTo(o.dx - 3, o.dy + 13)
          ..lineTo(o.dx + 8, o.dy - 3)
          ..lineTo(o.dx, o.dy - 3)
          ..close();
        _neon(c, p, col, 1.8);
      default: // sprout
        _neonLine(c, o + const Offset(0, 12), o + const Offset(0, -4), col, 1.8);
        _neon(c, Path()..addOval(Rect.fromCenter(center: o + const Offset(-6, -6), width: 12, height: 7)), col, 1.8);
        _neon(c, Path()..addOval(Rect.fromCenter(center: o + const Offset(6, -9), width: 12, height: 7)), col, 1.8);
    }
  }

  void _drawHud(Canvas c) {
    final n = _shownCol.round();
    final col = n >= 80 ? _cols[0] : (n >= 68 ? _cols[1] : const Color(0xFFFF4060));
    // person icon
    const po = Offset(110, 72);
    _neon(c, Path()..addOval(Rect.fromCircle(center: po + const Offset(0, -10), radius: 6)), col, 2);
    _neon(c, Path()..addArc(Rect.fromCenter(center: po + const Offset(0, 12), width: 24, height: 26), pi, pi), col, 2);
    D.text(c, '$n', const Offset(170, 70), size: 44, color: Pal.white, stroke: col, strokeWidth: 4);
    // threshold bar
    const bar = Rect.fromLTWH(210, 62, 120, 12);
    c.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(6)), D.fill(const Color(0x33FFFFFF)));
    final f = (_shownCol / 100).clamp(0.0, 1.0);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bar.left, bar.top, bar.width * f, bar.height), const Radius.circular(6)),
        D.fill(col));
    final gx = bar.left + bar.width * _goal / 100;
    _neonLine(c, Offset(gx, bar.top - 6), Offset(gx, bar.bottom + 6), _pink, 2);
    D.text(c, '$_goal', Offset(gx, bar.bottom + 14), size: 11, color: _pink);
  }
}

class _Meteor {
  _Meteor(this.pos, this.vel, this.target, this.r);
  Offset pos;
  final Offset vel;
  final int target;
  final double r;
  double spin = 0;
  bool dead = false;
}
