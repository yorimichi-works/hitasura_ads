import '../engine/engine.dart';

/// No.115 Peg Drop — aim ten balls through a neon peg board into score pockets.
/// The moving bonus gate adds points and briefly boosts the score; no stake.
class G115 extends MiniGame {
  static const _target = 250;
  static const _binL = 18.0, _binW = 36.0, _binTop = 468.0, _binFloor = 522.0;
  static const _pocketPoints = <int>[30, 10, 20, 10, 80, 10, 20, 10, 30];
  static const _rowYs = <double>[150, 178, 206, 234, 302, 330, 358, 386, 414, 442];
  static const _tulipY = 268.0;

  final List<_Peg> _pegs = [];
  final List<_Ball> _balls = [];
  final List<double> _binFlash = List.filled(9, 0);
  int _ballsLeft = 10;
  int _points = 0;
  double _shownPoints = 0;
  double _t = 0;
  double _dropCd = 0;
  double _aimX = 180;
  double _boost = 0;
  double _boostFlash = 0;
  double _tickCd = 0;
  double _tulipX = 180;
  double _tulipOpen = 0;
  double _targetFlash = 0;
  double _slowmo = 0;
  int _centerHits = 0;
  bool _ended = false;

  @override
  void init() {
    for (var r = 0; r < _rowYs.length; r++) {
      final odd = r.isOdd;
      final n = odd ? 10 : 11;
      for (var i = 0; i < n; i++) {
        _pegs.add(_Peg(Offset((odd ? 45.0 : 30.0) + i * 30, _rowYs[r])));
      }
    }
  }

  bool get _boostOn => _boost > 0;

  static const _auto = bool.fromEnvironment('AUTOPLAY');

  @override
  void update(double dt) {
    _t += dt;
    if (_auto && !host.finished) _drop(180);
    // Target approach slow motion: a ball dropping right above the center target pocket.
    var tension = false;
    for (final b in _balls) {
      if (!b.inBin && b.p.dy > 380 && (b.p.dx - 180).abs() < 40 && b.v.dy > 0) tension = true;
    }
    _slowmo = M.approach(_slowmo, tension ? 1 : 0, 10, dt);
    final sdt = dt * (1 - _slowmo * .55);

    _dropCd -= dt;
    _tickCd -= dt;
    _boost = max(0, _boost - dt);
    _boostFlash = M.approach(_boostFlash, 0, 3, dt);
    _targetFlash = M.approach(_targetFlash, 0, 2.5, dt);
    _tulipOpen = M.approach(_tulipOpen, 0, 4, dt);
    _tulipX = 180 + sin(_t * 1.5 * host.speed) * 112;
    _shownPoints = M.approach(_shownPoints, _points.toDouble(), 7, dt);
    if ((_shownPoints - _points).abs() < 1) _shownPoints = _points.toDouble();
    for (var i = 0; i < 9; i++) {
      _binFlash[i] = M.approach(_binFlash[i], 0, 3, dt);
    }
    for (final pg in _pegs) {
      pg.flash = M.approach(pg.flash, 0, 6, dt);
    }
    if (host.pointerDown) _aimX = host.pointer.dx.clamp(30.0, 330.0);

    const sub = 4;
    final h = sdt / sub;
    for (var s = 0; s < sub; s++) {
      for (final b in _balls) {
        _stepBall(b, h);
      }
    }
    for (final b in _balls) {
      b.trail.insert(0, b.p);
      if (b.trail.length > 7) b.trail.removeLast();
    }
    _balls.removeWhere((b) => b.dead);

    if (!host.finished && !_ended && _ballsLeft == 0 && _balls.isEmpty && _points < _target) {
      _ended = true;
      host.sfx(Sfx.aww);
      host.fx.pop(host.tr('so_close', 'SO CLOSE!'), const Offset(180, 330), color: Pal.pink, size: 34, life: 1.4);
      host.lose();
    }
  }

  void _stepBall(_Ball b, double dt) {
    if (b.dead) return;
    b.v = Offset(b.v.dx, b.v.dy + 980 * dt);
    final sp = b.v.distance;
    if (sp > 620) b.v = b.v / sp * 620;
    b.p += b.v * dt;
    const r = _Ball.r;
    // walls
    if (b.p.dx < 14 + r) {
      b.p = Offset(14 + r, b.p.dy);
      b.v = Offset(b.v.dx.abs() * .5, b.v.dy);
    } else if (b.p.dx > 346 - r) {
      b.p = Offset(346 - r, b.p.dy);
      b.v = Offset(-b.v.dx.abs() * .5, b.v.dy);
    }
    // tulip capture
    if (!b.fromTulip && (b.p.dy - _tulipY).abs() < 9 && (b.p.dx - _tulipX).abs() < 14 && b.v.dy > 0) {
      b.fromTulip = true;
      b.p = Offset(_tulipX, _tulipY + 16);
      b.v = Offset(rand(-30, 30), 60);
      _triggerBoost();
    }
    if (b.inBin) {
      final l = _binL + b.bin * _binW + r + 2, rr = _binL + (b.bin + 1) * _binW - r - 2;
      if (b.p.dx < l) {
        b.p = Offset(l, b.p.dy);
        b.v = Offset(b.v.dx.abs() * .4, b.v.dy);
      } else if (b.p.dx > rr) {
        b.p = Offset(rr, b.p.dy);
        b.v = Offset(-b.v.dx.abs() * .4, b.v.dy);
      }
      if (b.p.dy > _binFloor - r) _score(b);
      return;
    }
    if (b.p.dy > _binTop) {
      b.inBin = true;
      b.bin = ((b.p.dx - _binL) / _binW).floor().clamp(0, 8);
      return;
    }
    // divider caps act like pegs
    for (final pg in _pegs) {
      final d = b.p - pg.p;
      if (d.dx.abs() > 12 || d.dy.abs() > 12) continue;
      final dist = d.distance;
      const minD = r + _Peg.r;
      if (dist < minD && dist > .001) {
        final n = d / dist;
        b.p = pg.p + n * minD;
        final vn = b.v.dx * n.dx + b.v.dy * n.dy;
        if (vn < 0) {
          b.v -= n * ((1 + .42) * vn);
          b.v += Offset(rand(-28, 28), 0);
          pg.flash = 1;
          if (_tickCd <= 0 && vn < -70) {
            _tickCd = .045;
            host.sfx(Sfx.tick, volume: .35, rate: 1.2 + pg.p.dy / 400 + rand(-.1, .1));
          }
        }
      }
    }
  }

  void _triggerBoost() {
    _boost = 5;
    _boostFlash = 1;
    _tulipOpen = 1;
    _points += 20;
    host.addScore(20);
    host.sfx(Sfx.ssr);
    host.sfx(Sfx.powerup, volume: .7);
    host.flash(Pal.pink, .25);
    host.shake(6);
    host.punch(.05);
    host.fx.ring(Offset(_tulipX, _tulipY), Pal.pink, size: 120);
    host.fx.burst(Offset(_tulipX, _tulipY), Pal.pink, count: 30, speed: 320, shape: PartShape.star, colors: Pal.candy);
    host.fx.pop(host.tr('bonus', 'BONUS!'), Offset(180, _tulipY - 30), color: Pal.pink, size: 40, life: 1.2);
    host.fx.pop('+20', Offset(_tulipX, _tulipY + 30), color: Pal.white, size: 26);
  }

  void _score(_Ball b) {
    b.dead = true;
    final gain = _pocketPoints[b.bin] * (_boostOn ? 2 : 1);
    _points += gain;
    host.addScore(gain);
    _binFlash[b.bin] = 1;
    final at = Offset(_binL + (b.bin + .5) * _binW, _binTop - 10);
    if (b.bin == 4) {
      _centerHits++;
      _targetFlash = 1;
      host.sfx(Sfx.fanfare, volume: 1);
      host.sfx(Sfx.sparkle);
      host.shake(10, .4);
      host.hitStop(.08);
      host.flash(Pal.yellow, .2);
      host.fx.burst(at, Pal.sky, count: 30, speed: 520, shape: PartShape.star);
      host.fx.ring(at, Pal.yellow, size: 150, life: .5);
      host.fx.pop(host.tr('perfect', 'PERFECT!'), const Offset(180, 400), color: Pal.yellow, size: 44, life: 1.2);
    } else if (_pocketPoints[b.bin] == 10) {
      host.sfx(Sfx.oops, volume: .7);
      host.fx.burst(at, Pal.gray, count: 8, speed: 120);
      if (b.bin == 3 || b.bin == 5) {
        host.fx.pop(host.tr('so_close', 'SO CLOSE!'), const Offset(180, 420), color: Pal.pink, size: 26);
      }
    } else {
      host.sfx(Sfx.ding, rate: 1 + gain * .004);
      host.fx.burst(at, Pal.sky, count: (gain ~/ 5).clamp(3, 14), speed: 320, shape: PartShape.star);
    }
    host.fx.pop('+$gain', at + const Offset(0, -18), color: gain >= 20 ? Pal.yellow : Pal.white, size: gain >= 80 ? 34 : 24, direction: TextDirection.ltr);
    if (!host.finished && _points >= _target) {
      final spare = _ballsLeft + _balls.where((b) => !b.dead).length;
      final stars = spare >= 5 || _centerHits >= 3 ? 3 : (spare >= 2 ? 2 : 1);
      host.fx.burst(const Offset(180, 300), Pal.sky, count: 40, speed: 600, shape: PartShape.star);
      host.win(stars: stars);
    }
  }

  void _drop(double x) {
    if (host.finished || _ballsLeft <= 0 || _dropCd > 0) return;
    _dropCd = .22;
    _ballsLeft--;
    _aimX = x.clamp(30.0, 330.0);
    final b = _Ball(Offset(_aimX + rand(-1.5, 1.5), 110), Offset(0, 60));
    _balls.add(b);
    host.sfx(Sfx.click, rate: 1.3);
    host.sfx(Sfx.pop, volume: .5);
    host.fx.burst(Offset(_aimX, 104), Pal.sky, count: 6, speed: 90, gravity: 0, life: .3);
  }

  @override
  void onDown(Offset p) => _drop(p.dx);

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'left') _aimX = (_aimX - 30).clamp(30.0, 330.0);
    if (key == 'right') _aimX = (_aimX + 30).clamp(30.0, 330.0);
    if (key == 'action' || key == 'down') _drop(_aimX);
  }

  @override
  void onTimeUp() {
    if (_points >= _target) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ------------------------------------------------------------ render ---

  Color _hueCol(double off, [double s = .85, double v = 1]) =>
      D.hsv(_boostOn ? (_t * 240 + off) : 280 + off * .15, s, v);

  @override
  void render(Canvas c) {
    // Background: deep neon night with a scrolling grid.
    D.gradientBg(c, [
      Color.lerp(const Color(0xFF1A0838), const Color(0xFF3A0A4A), _boostFlash)!,
      const Color(0xFF07031A),
      const Color(0xFF12052A),
    ]);
    final grid = Paint()
      ..color = _boostOn ? D.hsv(_t * 200, .8, 1, .13) : const Color(0x1A9A6BFF)
      ..strokeWidth = 1;
    final off = (_t * 20) % 24;
    for (var y = 40.0 + off; y < 640; y += 24) {
      c.drawLine(Offset(0, y), Offset(360, y), grid);
    }
    for (var x = 6.0; x < 360; x += 24) {
      c.drawLine(Offset(x, 40), Offset(x, 640), grid);
    }
    if (_boostOn || _targetFlash > .05) {
      D.rays(c, const Offset(180, 330), 520, D.hsv(_t * 90, .7, 1, .08 + _targetFlash * .1), count: 16, t: _t * .8);
    }

    // Cabinet frame with chasing bulbs.
    final frame = Rect.fromLTRB(8, 92, 352, 548);
    D.rrect(c, frame.inflate(4), 22, const Color(0xFF0B0620));
    c.drawRRect(RRect.fromRectAndRadius(frame.inflate(4), const Radius.circular(22)),
        D.stroke(_hueCol(0, .6, 1).withValues(alpha: .35), 12));
    c.drawRRect(RRect.fromRectAndRadius(frame.inflate(4), const Radius.circular(22)), D.stroke(_hueCol(0, .5, 1), 3));
    _bulbs(c, frame.inflate(4));

    // Launcher rail + aim.
    D.rrect(c, const Rect.fromLTWH(20, 96, 320, 20), 10, const Color(0xFF1C1240), border: const Color(0x669A6BFF), borderWidth: 2);
    final canDrop = _ballsLeft > 0 && !host.finished;
    if (canDrop) {
      for (var y = 122.0; y < 145; y += 8) {
        c.drawCircle(Offset(_aimX, y), 2, D.fill(const Color(0x88FFFFFF)));
      }
    }
    // launcher nozzle
    final nozzle = Path()
      ..moveTo(_aimX - 14, 96)
      ..lineTo(_aimX + 14, 96)
      ..lineTo(_aimX + 7, 118)
      ..lineTo(_aimX - 7, 118)
      ..close();
    c.drawPath(nozzle, D.fill(const Color(0xFF3FB8FF)));
    c.drawPath(nozzle, D.stroke(Pal.white, 2));
    if (canDrop) _chrome(c, Offset(_aimX, 103), _Ball.r, 1);

    // Pegs.
    for (final pg in _pegs) {
      final col = pg.flash > .05 ? _hueCol(pg.p.dx + pg.p.dy, .7, 1) : _hueCol(pg.p.dy * .6, .7, .95);
      c.drawCircle(pg.p, 7 + pg.flash * 6, D.fill(col.withValues(alpha: .18 + pg.flash * .3)));
      c.drawCircle(pg.p, _Peg.r, D.fill(Color.lerp(col, Pal.white, .55 + pg.flash * .45)!));
    }

    // Tulip (bonus pocket) in its lane.
    c.drawLine(const Offset(20, _tulipY + 14), const Offset(340, _tulipY + 14), D.stroke(const Color(0x33FF5FC8), 2));
    _tulip(c, Offset(_tulipX, _tulipY));

    // Bins.
    for (var i = 0; i < 9; i++) {
      final r = Rect.fromLTWH(_binL + i * _binW + 2, _binTop, _binW - 4, 76);
      final points = _pocketPoints[i];
      final base = i == 4
          ? Pal.gold
          : points >= 30
              ? Pal.pink
              : points >= 20
                  ? Pal.sky
                  : points >= 10
                      ? Pal.teal
                      : const Color(0xFF6A6A8A);
      final fl = _binFlash[i];
      final glow = i == 4 ? .35 + .25 * M.wave(_t, 3) : .15;
      D.rrect(c, r.inflate(3 + fl * 4), 8, base.withValues(alpha: glow + fl * .5));
      D.rrect(c, r, 7, Color.lerp(const Color(0xFF140A2E), base, .25 + fl * .6)!, border: base, borderWidth: 2.5);
      final disp = '+${points * (_boostOn ? 2 : 1)}';
      D.text(c, disp, r.center + const Offset(0, 14),
          size: i == 4 ? 15 : 13, color: Color.lerp(base, Pal.white, .5)!, stroke: Pal.ink, strokeWidth: 3, direction: TextDirection.ltr);
    }
    // dividers
    for (var i = 0; i <= 9; i++) {
      final x = _binL + i * _binW;
      c.drawLine(Offset(x, _binTop - 2), Offset(x, _binTop + 76), D.stroke(const Color(0xFFB7A6FF), 2.5));
      c.drawCircle(Offset(x, _binTop - 2), 3, D.fill(Pal.white));
    }
    // center target pocket sign
    final jp = Offset(180, _binTop + 18);
    D.star(c, jp, 9 + 2 * M.wave(_t, 2), Pal.yellow, border: Pal.ink);

    // Balls with neon trails.
    for (final b in _balls) {
      for (var i = 1; i < b.trail.length; i++) {
        c.drawCircle(b.trail[i], _Ball.r * (1 - i / 8), D.fill(_hueCol(i * 20.0, .6, 1).withValues(alpha: .35 * (1 - i / 8))));
      }
      _chrome(c, b.p, _Ball.r, 1);
    }

    // Tension vignette during slow motion.
    if (_slowmo > .05) {
      c.drawRect(
          const Rect.fromLTWH(0, 0, 360, 640),
          Paint()
            ..shader = const RadialGradient(colors: [Color(0x00000000), Color(0xAA000000)], stops: [.5, 1])
                .createShader(const Rect.fromLTWH(-60, 60, 480, 560))
            ..color = Color.fromRGBO(0, 0, 0, _slowmo));
      D.text(c, '!!', Offset(180 + sin(_t * 40) * 2, 450), size: 30 * _slowmo, color: Pal.yellow, stroke: Pal.ink);
    }

    _hud(c);

    if (host.time < 2.2 && _ballsLeft == 10) {
      D.hand(c, const Offset(180, 108), _t);
      D.text(c, host.tr('tap', 'TAP!'), const Offset(240, 150), size: 22, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _bulbs(Canvas c, Rect r) {
    const n = 34;
    final per = (r.width + r.height) * 2;
    for (var i = 0; i < n; i++) {
      var d = i / n * per;
      Offset p;
      if (d < r.width) {
        p = Offset(r.left + d, r.top);
      } else if ((d -= r.width) < r.height) {
        p = Offset(r.right, r.top + d);
      } else if ((d -= r.height) < r.width) {
        p = Offset(r.right - d, r.bottom);
      } else {
        d -= r.width;
        p = Offset(r.left, r.bottom - d);
      }
      final chase = ((i - _t * (_boostOn ? 30 : 10)) % 4 + 4) % 4 < 1.2;
      final col = D.hsv(_boostOn ? i * 30 + _t * 300 : (chase ? 50 : 300), .8, 1);
      c.drawCircle(p, chase ? 6 : 4, D.fill(col.withValues(alpha: chase ? .45 : .15)));
      c.drawCircle(p, 2.6, D.fill(chase ? Pal.white : col.withValues(alpha: .6)));
    }
  }

  void _tulip(Canvas c, Offset o) {
    final open = .35 + _tulipOpen * .65 + (_boostOn ? .2 : 0);
    final col = _boostOn ? D.hsv(_t * 300, .6, 1) : Pal.pink;
    c.drawCircle(o, 22, D.fill(col.withValues(alpha: .18)));
    for (final s in [-1.0, 1.0]) {
      c.save();
      c.translate(o.dx + s * 6, o.dy + 8);
      c.rotate(s * open * .9);
      final petal = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(s * 16, -6, s * 10, -22)
        ..quadraticBezierTo(s * 2, -14, 0, 0)
        ..close();
      c.drawPath(petal, D.fill(col));
      c.drawPath(petal, D.stroke(Pal.white, 1.5));
      c.restore();
    }
    D.rrect(c, Rect.fromCenter(center: o + const Offset(0, 10), width: 20, height: 10), 4, const Color(0xFF2B1650),
        border: col, borderWidth: 2);
    D.text(c, '+20', o + const Offset(0, -20), size: 11, color: Pal.white, stroke: Pal.ink, strokeWidth: 3);
  }

  void _chrome(Canvas c, Offset p, double r, double a) {
    c.drawCircle(p + const Offset(1, 2), r, D.fill(const Color(0x66000000)));
    c.drawCircle(p, r, D.fill(const Color(0xFFB9C2D6)));
    c.drawCircle(p + Offset(r * .15, r * .2), r * .75, D.fill(const Color(0xFF7E88A3)));
    c.drawCircle(p + Offset(-r * .1, -r * .1), r * .6, D.fill(const Color(0xFFE8EEFA)));
    c.drawCircle(p + Offset(-r * .35, -r * .38), r * .28, D.fill(Pal.white));
  }

  void _hud(Canvas c) {
    // score counter panel
    final panel = const Rect.fromLTWH(20, 40, 320, 48);
    D.rrect(c, panel, 14, const Color(0xCC0B0620), border: _hueCol(40, .6, 1), borderWidth: 2.5);
    D.star(c, const Offset(44, 60), 12, Pal.sky, border: Pal.ink);
    final pulse = _points >= _target ? 1.15 : 1.0;
    c.save();
    c.translate(118, 58);
    c.scale(pulse);
    D.text(c, _fmt(_shownPoints.round()), Offset.zero, size: 26, color: Pal.yellow, stroke: Pal.ink, strokeWidth: 5);
    c.restore();
    D.bar(c, const Rect.fromLTWH(62, 76, 130, 7), _shownPoints / _target, Pal.yellow, border: const Color(0x55FFFFFF));
    D.text(c, '/$_target', const Offset(206, 80), size: 11, color: const Color(0xCCFFFFFF), anchor: Alignment.centerLeft);
    // balls left
    for (var i = 0; i < min(_ballsLeft, 12); i++) {
      _chrome(c, Offset(326 - (i % 6) * 15, 55 + (i ~/ 6) * 15), 5.5, 1);
    }
    if (_boostOn) {
      final s = 1 + .08 * sin(_t * 18);
      D.title(c, host.tr('bonus', 'BONUS!'), const Offset(180, 582), size: 38, color: D.hsv(_t * 300, .6, 1), scale: s);
      D.bar(c, const Rect.fromLTWH(110, 610, 140, 8), _boost / 5, Pal.pink);
    } else {
      D.text(c, 'x2', const Offset(180, 588), size: 14, color: const Color(0x88FFFFFF));
      D.text(c, host.tr('bonus', 'BONUS!'), const Offset(180, 606), size: 14, color: const Color(0x88FF5FC8));
    }
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
}

class _Peg {
  _Peg(this.p);
  static const r = 4.0;
  final Offset p;
  double flash = 0;
}

class _Ball {
  _Ball(this.p, this.v);
  static const r = 6.5;
  Offset p;
  Offset v;
  bool inBin = false;
  int bin = 0;
  bool dead = false;
  bool fromTulip = false;
  final List<Offset> trail = [];
}
