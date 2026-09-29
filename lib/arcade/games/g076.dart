import '../engine/engine.dart';

/// No.076 Find the Odd One! — 6x6 identical icons, one is subtly different.
/// "Only 1 in 100 can see it". Tap the odd one.
class G076 extends MiniGame {
  static const _n = 6;
  static const _cell = 54.0;
  static const _gx = 18.0;
  static const _gy = 176.0;
  double _t = 0;
  late int _theme; // 0 cat, 1 chick, 2 ghost, 3 onigiri
  late int _odd; // index of the odd tile
  late int _diff; // 0 color, 1 feature A, 2 feature B
  late double _hueShift;
  int _lives = 3;
  double _foundT = -1;
  double _loseT = -1;
  final _wrong = <int, double>{}; // tile -> time of wrong tap
  double _hurt = 0;

  @override
  void init() {
    _theme = randInt(4);
    _odd = randInt(_n * _n);
    _diff = randInt(3);
    _hueShift = (host.speed > 1.4 ? 20.0 : 32.0) * (chance(.5) ? 1 : -1);
  }

  Offset _tileCenter(int i) => Offset(_gx + _cell * (i % _n + .5), _gy + _cell * (i ~/ _n + .5));

  @override
  void update(double dt) {
    _t += dt;
    if (_foundT >= 0) _foundT += dt;
    if (_loseT >= 0) _loseT += dt;
    _hurt = M.approach(_hurt, 0, 6, dt);
  }

  @override
  void onDown(Offset p) {
    if (_foundT >= 0 || host.finished) return;
    final cx = ((p.dx - _gx) / _cell).floor();
    final cy = ((p.dy - _gy) / _cell).floor();
    if (cx < 0 || cy < 0 || cx >= _n || cy >= _n) return;
    final i = cy * _n + cx;
    final o = _tileCenter(i);
    if (i == _odd) {
      _foundT = 0;
      host.sfx(Sfx.correct);
      host.sfx(Sfx.ding, rate: 1.2);
      host.shake(5);
      host.hitStop(.08);
      host.flash(const Color(0x88FFFFFF));
      host.fx.ring(o, Pal.yellow, size: 90, life: .5);
      host.fx.burst(o, Pal.yellow, count: 20, speed: 300, shape: PartShape.star, size: 8, gravity: 200);
      host.fx.pop(host.tr('wow', 'WOW!'), o + const Offset(0, -46), color: Pal.lime, size: 36);
      final tm = host.time;
      host.win(stars: tm < 2 ? 3 : (tm < 3.4 && _lives == 3 ? 2 : (_lives >= 2 ? 2 : 1)));
    } else if (!_wrong.containsKey(i)) {
      _wrong[i] = _t;
      _lives--;
      _hurt = 1;
      host.sfx(Sfx.wrong);
      host.shake(6);
      host.fx.pop(host.tr('miss', 'MISS'), o, color: Pal.red, size: 24);
      if (_lives <= 0) _fail();
    }
  }

  void _fail() {
    _loseT = 0;
    host.sfx(Sfx.buzzer);
    host.flash(Pal.red, .12);
    host.lose();
  }

  @override
  void onTimeUp() => _fail();

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF9B6BFF), Color(0xFFFF6FB5)]);
    D.rays(c, const Offset(180, 340), 700, const Color(0x22FFFFFF), count: 20, t: _t * .3);

    // "Only 1 in 100" banner
    final b = Rect.fromCenter(center: const Offset(150, 98), width: 220, height: 70);
    D.rrect(c, b.shift(const Offset(0, 6)), 20, const Color(0x55000000));
    D.rrect(c, b, 20, Pal.yellow, border: Pal.ink, borderWidth: 4);
    D.text(c, '1/100', b.center + const Offset(24, 0), size: 36, color: Pal.red, stroke: Pal.ink, strokeWidth: 7);
    _magnifier(c, b.centerLeft + const Offset(40, 0), 22);
    // lives
    for (var i = 0; i < 3; i++) {
      final o = Offset(292 + (i % 2) * 28.0 + (i == 2 ? 14 : 0), 82 + (i == 2 ? 30 : 0));
      D.heart(c, o, 26, i < _lives ? Pal.red : const Color(0x55000000), border: Pal.ink);
    }

    // card
    final card = Rect.fromLTWH(_gx - 8, _gy - 8, _cell * _n + 16, _cell * _n + 16);
    final sx = _hurt > 0 ? sin(_t * 70) * 6 * _hurt : 0.0;
    c.save();
    c.translate(sx, 0);
    D.rrect(c, card.shift(const Offset(6, 8)), 22, const Color(0x55000000));
    D.rrect(c, card, 22, Pal.cream, border: Pal.ink, borderWidth: 5);
    for (var i = 0; i < _n * _n; i++) {
      final o = _tileCenter(i);
      if ((i % _n + i ~/ _n).isEven) {
        D.rrect(c, Rect.fromCenter(center: o, width: _cell - 4, height: _cell - 4), 12, const Color(0x14000000));
      }
      final wave = sin(_t * 4 - (i % _n + i ~/ _n) * .6) * 2.5;
      var scale = 1.0;
      if (_foundT >= 0 && i == _odd) scale = 1 + M.easeOutElastic(M.clamp01(_foundT * 1.5)) * .9;
      if (_foundT >= 0 && i != _odd) scale = 1 - M.clamp01(_foundT * 2) * .15;
      final wt = _wrong[i];
      c.save();
      c.translate(o.dx, o.dy + wave);
      if (wt != null && _t - wt < .4) c.rotate(sin((_t - wt) * 50) * .25);
      c.scale(scale * 1.12);
      if (!(_foundT >= 0 && i == _odd)) _icon(c, i == _odd, _foundT >= 0 ? (i == _odd ? 2 : 1) : 0);
      c.restore();
      if (wt != null) {
        D.line(c, o + const Offset(-16, -16), o + const Offset(16, 16), const Color(0xCCFF3B5C), 7);
        D.line(c, o + const Offset(16, -16), o + const Offset(-16, 16), const Color(0xCCFF3B5C), 7);
      }
    }
    // draw found icon on top
    if (_foundT >= 0) {
      final o = _tileCenter(_odd);
      D.rays(c, o, 90, const Color(0x88FFD23F), count: 12, t: _t * 2);
      c.save();
      c.translate(o.dx, o.dy);
      c.scale(1 + M.easeOutElastic(M.clamp01(_foundT * 1.5)) * .9);
      _icon(c, true, 2);
      c.restore();
    }
    // reveal after failure
    if (_loseT >= 0) {
      final o = _tileCenter(_odd);
      final k = M.easeOutBack(M.clamp01(_loseT * 3));
      c.drawCircle(o, 34 * k, D.stroke(Pal.red, 6));
      D.arrow(c, o + Offset(0, -62 - sin(_t * 8) * 5), const Offset(0, 1), 40, Pal.red, width: 12);
    }
    c.restore();

    // smug quiz host at bottom
    final hostFace = _foundT >= 0 ? Face.shocked : (_loseT >= 0 ? Face.smug : (_hurt > .2 ? Face.happy : Face.smug));
    D.blob(c, const Offset(70, 580), 44, Pal.orange, face: hostFace);
    // glasses
    for (final s in [-1.0, 1.0]) {
      c.drawCircle(Offset(70 + s * 16, 576), 12, D.stroke(Pal.ink, 3.5));
    }
    D.bubble(c, const Rect.fromLTWH(128, 540, 200, 56), tail: const Offset(118, 590));
    D.text(c, _foundT >= 0 ? '!!!' : '?', const Offset(228, 568), size: 32, color: _foundT >= 0 ? Pal.red : Pal.purple,
        stroke: Pal.ink, strokeWidth: 5);
  }

  void _magnifier(Canvas c, Offset o, double r) {
    D.line(c, o + Offset(r * .6, r * .6), o + Offset(r * 1.3, r * 1.3), Pal.ink, 8);
    c.drawCircle(o, r, D.fill(const Color(0xAAE8F6FF)));
    c.drawCircle(o, r, D.stroke(Pal.ink, 5));
    c.drawCircle(o + Offset(-r * .35, -r * .35), r * .25, D.fill(Pal.white));
  }

  /// Draws the theme icon centered at the origin (~44px). [react]: 0 idle,
  /// 1 others (shocked), 2 the found one (happy).
  void _icon(Canvas c, bool odd, int react) {
    final colDiff = odd && _diff == 0;
    final fA = odd && _diff == 1;
    final fB = odd && _diff == 2;
    Color tint(double h, double sat, double v) => D.hsv(colDiff ? h + _hueShift : h, sat, v);
    final ink = D.fill(Pal.ink);
    final line = D.stroke(Pal.ink, 2.5);
    final face = react == 2 ? Face.love : (react == 1 ? Face.shocked : null);
    switch (_theme) {
      case 0: // cat
        final col = tint(30, .7, 1);
        for (final s in [-1.0, 1.0]) {
          final folded = fA && s < 0;
          final ear = Path()
            ..moveTo(s * 18, -6)
            ..lineTo(s * (folded ? 20 : 15), folded ? -14 : -22)
            ..lineTo(s * 4, -14)
            ..close();
          c.drawPath(ear, D.fill(col));
          c.drawPath(ear, line);
        }
        c.drawOval(const Rect.fromLTWH(-19, -16, 38, 32), D.fill(col));
        c.drawOval(const Rect.fromLTWH(-19, -16, 38, 32), line);
        if (face != null) {
          D.face(c, const Offset(0, 0), 15, face, blush: false);
        } else {
          for (final s in [-1.0, 1.0]) {
            if (fB && s > 0) {
              c.drawArc(Rect.fromCenter(center: Offset(s * 7, -3), width: 7, height: 6), pi, pi, false, line);
            } else {
              c.drawCircle(Offset(s * 7, -3), 3, ink);
            }
            D.line(c, Offset(s * 12, 4), Offset(s * 24, 2), Pal.ink, 1.5);
            D.line(c, Offset(s * 12, 7), Offset(s * 24, 9), Pal.ink, 1.5);
          }
          c.drawCircle(const Offset(0, 3), 2, D.fill(Pal.pink));
          c.drawArc(const Rect.fromLTWH(-5, 3, 5, 5), 0, pi, false, line);
          c.drawArc(const Rect.fromLTWH(0, 3, 5, 5), 0, pi, false, line);
        }
      case 1: // chick
        final col = tint(46, .75, 1);
        // tuft
        if (!fA) {
          D.line(c, const Offset(0, -18), const Offset(-4, -26), Pal.ink, 3);
          D.line(c, const Offset(0, -18), const Offset(5, -25), Pal.ink, 3);
        }
        c.drawCircle(const Offset(0, 2), 19, D.fill(col));
        c.drawCircle(const Offset(0, 2), 19, line);
        // wing
        c.drawOval(const Rect.fromLTWH(8, 2, 12, 9), D.fill(Color.lerp(col, Pal.orange, .3)!));
        if (face != null) {
          D.face(c, const Offset(0, 0), 14, face, blush: false);
        } else {
          c.drawCircle(const Offset(-7, -3), 3, ink);
          c.drawCircle(const Offset(7, -3), 3, ink);
          final beak = Path();
          if (fB) {
            beak
              ..moveTo(-5, 3)
              ..lineTo(5, 3)
              ..lineTo(0, 12)
              ..close();
          } else {
            beak
              ..moveTo(-5, 3)
              ..lineTo(5, 3)
              ..lineTo(0, 8)
              ..close();
          }
          c.drawPath(beak, D.fill(Pal.orange));
          c.drawPath(beak, D.stroke(Pal.ink, 1.5));
          if (fB) D.line(c, const Offset(-4, 6), const Offset(4, 6), Pal.ink, 1.5);
        }
      case 2: // ghost
        final col = tint(200, .28, 1);
        final body = Path()
          ..moveTo(-17, 18)
          ..lineTo(-17, -4)
          ..arcToPoint(const Offset(17, -4), radius: const Radius.circular(17))
          ..lineTo(17, 18)
          ..lineTo(11, 13)
          ..lineTo(6, 18)
          ..lineTo(0, 13)
          ..lineTo(-6, 18)
          ..lineTo(-11, 13)
          ..close();
        c.drawPath(body, D.fill(col));
        c.drawPath(body, line);
        if (face != null) {
          D.face(c, const Offset(0, -2), 14, face, blush: false);
        } else {
          final look = fA ? -2.0 : 2.0;
          for (final s in [-1.0, 1.0]) {
            c.drawOval(Rect.fromCenter(center: Offset(s * 6, -5), width: 8, height: 10), D.fill(Pal.white));
            c.drawCircle(Offset(s * 6 + look, -4), 2.6, ink);
          }
          c.drawOval(const Rect.fromLTWH(-3, 3, 6, 5), ink);
          if (fB) {
            c.drawOval(const Rect.fromLTWH(-3, 6, 6, 7), D.fill(Pal.pink));
          }
        }
      default: // onigiri
        final tri = Path()
          ..moveTo(0, -21)
          ..quadraticBezierTo(4, -21, 20, 12)
          ..quadraticBezierTo(22, 18, 14, 18)
          ..lineTo(-14, 18)
          ..quadraticBezierTo(-22, 18, -20, 12)
          ..quadraticBezierTo(-4, -21, 0, -21)
          ..close();
        c.drawPath(tri, D.fill(colDiff ? const Color(0xFFFFE2EA) : Pal.white));
        c.drawPath(tri, line);
        final noriW = fA ? 16.0 : 22.0;
        D.rrect(c, Rect.fromCenter(center: const Offset(0, 11), width: noriW, height: 14), 2,
            colDiff ? const Color(0xFF3A5A2A) : const Color(0xFF1E2A26));
        if (face != null) {
          D.face(c, const Offset(0, -3), 11, face, blush: false);
        } else {
          c.drawCircle(const Offset(-6, -4), 2.4, ink);
          c.drawCircle(const Offset(6, -4), 2.4, ink);
          if (fB) {
            c.drawArc(const Rect.fromLTWH(-4, -2, 8, 5), pi, pi, false, D.stroke(Pal.ink, 1.8));
          } else {
            c.drawArc(const Rect.fromLTWH(-4, -3, 8, 5), 0, pi, false, D.stroke(Pal.ink, 1.8));
          }
          c.drawOval(const Rect.fromLTWH(-13, 0, 6, 3), D.fill(const Color(0x66FF5F7A)));
          c.drawOval(const Rect.fromLTWH(7, 0, 6, 3), D.fill(const Color(0x66FF5F7A)));
        }
    }
  }
}
