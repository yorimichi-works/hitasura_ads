import '../engine/engine.dart';

/// No.146 Soap Cutting — swipe DOWN to shave thin slices off a layered pastel
/// soap block. Straight, fast swipes curl into perfect sheets; sloppy ones
/// crumble into cubes. The cross-section pattern changes as you go deeper.
class G146 extends MiniGame {
  static const _target = 12;
  static const _thick = 14.0;
  static const _left = 58.0;
  static const _top = 300.0;
  static const _bottom = 440.0;
  static const _dx = 26.0, _dy = -30.0; // 3/4 depth offset
  static const _bands = [Color(0xFFFFB3CF), Color(0xFFB8F0D8), Color(0xFFFFF0A8), Color(0xFFD6C2FF), Color(0xFFA8DDFF)];
  static const _bandDark = [Color(0xFFE88AAE), Color(0xFF86D4B4), Color(0xFFE8D270), Color(0xFFAE94EE), Color(0xFF78BFEE)];

  double _right = 292;
  double _t = 0;
  int _cuts = 0;
  int _perfects = 0;
  int _combo = 0;
  Offset? _start;
  double _startT = 0;
  double _minX = 0, _maxX = 0;
  bool _cutThisStroke = false;
  double _knifeAnim = 0;
  double _blockSquash = 0;
  final _slices = <_Slice>[];
  final _crumbs = <_Crumb>[];
  double _winT = -1;

  @override
  Color get backdrop => const Color(0xFF3A2A4A);

  double get _guideX => _right - _thick;

  double _bandY(int i, double x) {
    // band boundary i (0..5) at x in the front face
    if (i == 0) return _top;
    if (i == 5) return _bottom;
    return _top + i * 28 + sin(x * .045 + i * 1.7) * 5;
  }

  @override
  void update(double dt) {
    _t += dt;
    if (_winT >= 0) _winT += dt;
    _knifeAnim = max(0, _knifeAnim - dt * 5);
    _blockSquash = M.approach(_blockSquash, 0, 10, dt);
    for (final s in _slices) {
      s.t += dt;
      if (!s.landed && s.t > .55) {
        s.landed = true;
        _shatter(s);
      }
    }
    _slices.removeWhere((s) => s.landed);
    for (final cr in _crumbs) {
      if (cr.rest) continue;
      cr.vy += 1400 * dt;
      cr.pos += Offset(cr.vx, cr.vy) * dt;
      cr.rot += cr.spin * dt;
      final floor = 478 - cr.stack;
      if (cr.pos.dy > floor) {
        cr.pos = Offset(cr.pos.dx, floor);
        if (cr.vy > 200) {
          cr.vy = -cr.vy * .3;
          cr.vx *= .5;
        } else {
          cr.rest = true;
        }
      }
    }
  }

  void _shatter(_Slice s) {
    final n = s.perfect ? 6 : 10;
    for (var i = 0; i < n; i++) {
      if (_crumbs.length > 110) _crumbs.removeAt(0);
      final band = randInt(5);
      _crumbs.add(_Crumb(
        Offset(s.x + _thick + 30 + rand(-6, 30), rand(360, 440)),
        rand(-60, 160),
        rand(-200, 0),
        s.perfect ? rand(9, 14) : rand(6, 11),
        band,
        rand(0, pi),
        rand(-8, 8),
        rand(0, 16),
      ));
    }
    host.sfx(Sfx.crack, volume: .5, rate: rand(1.2, 1.6));
    host.fx.burst(Offset(s.x + 50, 460), _bands[randInt(5)], count: 8, speed: 140, shape: PartShape.square, size: 5, gravity: 600,
        colors: _bands);
  }

  void _cut(double straight, double dur) {
    if (host.finished || _right - _thick < _left + 20) return;
    final perfect = straight < .18 && dur < .35;
    _cuts++;
    _slices.add(_Slice(_guideX, perfect, List<double>.generate(6, (i) => _bandY(i, _guideX))));
    _right -= _thick;
    _knifeAnim = 1;
    _blockSquash = 1;
    if (perfect) {
      _perfects++;
      _combo++;
      host.sfx(Sfx.chop, rate: 1 + _combo * .05);
      host.sfx(Sfx.slash, volume: .6, rate: 1.3);
      host.fx.pop(_combo >= 3 ? '${host.tr('perfect', 'PERFECT!')} x$_combo' : host.tr('perfect', 'PERFECT!'),
          Offset(_right + 10, 240), color: Pal.pink, size: 24);
      host.addScore(100 + _combo * 20);
      host.punch(.015);
    } else {
      _combo = 0;
      host.sfx(Sfx.chop, rate: rand(.8, 1));
      host.sfx(Sfx.crack, volume: .6, rate: rand(.9, 1.2));
      host.fx.pop(host.tr('nice', 'NICE!'), Offset(_right + 10, 240), color: Pal.sky, size: 20);
      host.addScore(50);
    }
    // crunchy shavings off the blade
    for (var i = 0; i < 12; i++) {
      host.fx.add(Particle(
          pos: Offset(_right + rand(-4, 8), rand(_top, _bottom)),
          vel: Offset(rand(20, 200), rand(-200, 20)),
          life: rand(.3, .6),
          color: _bands[randInt(5)],
          size: rand(2, 5),
          gravity: 900,
          shape: PartShape.square,
          spin: rand(-10, 10)));
    }
    host.shake(perfect ? 2 : 4);
    if (_cuts >= _target) {
      _winT = 0;
      host.sfx(Sfx.fanfare, volume: .8);
      host.sfx(Sfx.sparkle);
      host.fx.sparkle(Offset((_left + _right) / 2, 360), count: 24, radius: 80);
      host.win(stars: _perfects >= 8 ? 3 : (_perfects >= 4 ? 2 : 1));
    }
  }

  @override
  void onDown(Offset p) {
    _start = p;
    _startT = _t;
    _minX = p.dx;
    _maxX = p.dx;
    _cutThisStroke = false;
  }

  @override
  void onMove(Offset p) {
    final s = _start;
    if (s == null || _cutThisStroke) return;
    _minX = min(_minX, p.dx);
    _maxX = max(_maxX, p.dx);
    final dy = p.dy - s.dy;
    if (dy > 90) {
      _cutThisStroke = true;
      _cut((_maxX - _minX) / dy, _t - _startT);
    }
  }

  @override
  void onUp(Offset p) {
    _start = null;
  }

  @override
  void onKey(String key, bool down) {
    if (down && (key == 'down' || key == 'action')) _cut(0, .1);
  }

  @override
  void onTimeUp() {
    if (_cuts >= 10) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFFE8DDFF), Color(0xFFFFD6E6), Color(0xFFFFE9D6)]);
    for (var i = 0; i < 10; i++) {
      final p = Offset((i * 83 + _t * 8 * (i % 3 + 1)) % 400 - 20, 80 + (i * 57) % 200 + sin(_t + i) * 10);
      c.drawCircle(p, 14 + (i % 4) * 8.0, D.fill(const Color(0x33FFFFFF)));
    }
    // table
    c.drawRect(const Rect.fromLTWH(0, 440, 360, 200), D.fill(const Color(0xFFF7EDE3)));
    for (var y = 460.0; y < 640; y += 36) {
      c.drawRect(Rect.fromLTWH(0, y, 360, 2), D.fill(const Color(0x14000000)));
    }
    // cutting board
    final board = Path()
      ..moveTo(24, 480)
      ..lineTo(60, 420)
      ..lineTo(352, 420)
      ..lineTo(336, 480)
      ..close();
    c.drawPath(board.shift(const Offset(0, 8)), D.fill(const Color(0xFFB58454)));
    c.drawPath(board, D.fill(const Color(0xFFE2B887)));
    c.drawPath(board, D.stroke(const Color(0xFF9A6A3A), 3));
    for (var i = 0; i < 4; i++) {
      D.line(c, Offset(60 + i * 70.0, 440 + i * 6.0), Offset(140 + i * 70.0, 438 + i * 6.0), const Color(0x33885530), 2);
    }

    _renderBlock(c);
    for (final s in _slices) {
      _renderSlice(c, s);
    }
    for (final cr in _crumbs) {
      c.save();
      c.translate(cr.pos.dx, cr.pos.dy);
      c.rotate(cr.rest ? cr.rot * .2 : cr.rot);
      final r = Rect.fromCenter(center: Offset.zero, width: cr.size, height: cr.size);
      c.drawRect(r, D.fill(_bands[cr.band]));
      c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, r.height * .35), D.fill(const Color(0x55FFFFFF)));
      c.drawRect(r, D.stroke(_bandDark[cr.band], 1.5));
      c.restore();
    }
    _renderKnife(c);
    _renderHud(c);
    if (host.time < 2.2 && _cuts == 0) {
      final k = (_t * 1.4) % 1;
      D.hand(c, Offset(_guideX + 10, 250 + k * 170), _t);
      D.arrow(c, Offset(_guideX - 36, 360), const Offset(0, 1), 90, Pal.pink, width: 14);
      D.text(c, host.tr('swipe', 'SWIPE!'), const Offset(180, 540), size: 28, color: Pal.pink, stroke: Pal.ink);
    }
  }

  void _renderBlock(Canvas c) {
    final l = _left, r = _right;
    final sq = 1 + _blockSquash * .03;
    c.save();
    c.translate(0, _bottom);
    c.scale(1, 2 - sq);
    c.translate(0, -_bottom);
    D.shadow(c, Offset((l + r) / 2 + 16, _bottom + 4), r - l + 50, 18, .18);
    // front face bands
    for (var i = 0; i < 5; i++) {
      final path = Path()..moveTo(l, _bandY(i, l));
      for (var x = l; x <= r; x += 6) {
        path.lineTo(x, _bandY(i, x));
      }
      path.lineTo(r, _bandY(i, r));
      path.lineTo(r, _bandY(i + 1, r));
      for (var x = r; x >= l; x -= 6) {
        path.lineTo(x, _bandY(i + 1, x));
      }
      path.lineTo(l, _bandY(i + 1, l));
      path.close();
      c.drawPath(path, D.fill(_bands[i]));
    }
    // embedded confetti chips on the front face
    for (var k = 0; k < 14; k++) {
      final x = l + 10 + (k * 37) % 220.0;
      if (x > r - 6) continue;
      final y = _top + 14 + (k * 53) % 120.0;
      c.drawRect(Rect.fromCenter(center: Offset(x, y), width: 6, height: 3), D.fill(_bandDark[(k + 2) % 5]));
    }
    c.drawRect(Rect.fromLTRB(l, _top, l + 18, _bottom), D.fill(const Color(0x22FFFFFF)));
    // top face
    final top = Path()
      ..moveTo(l, _top)
      ..lineTo(l + _dx, _top + _dy)
      ..lineTo(r + _dx, _top + _dy)
      ..lineTo(r, _top)
      ..close();
    c.drawPath(top, D.fill(const Color(0xFFFFD2E2)));
    for (var k = 0; k < 12; k++) {
      final x = l + 14 + (k * 29) % 230.0;
      if (x > r - 4) continue;
      final f = (k * 7 % 10) / 10;
      c.drawCircle(Offset(x + _dx * f, _top + _dy * f), 2, D.fill(const Color(0xAAFFFFFF)));
    }
    // cross-section (right face): bands + a depth-varying heart
    for (var i = 0; i < 5; i++) {
      final y0 = _bandY(i, r), y1 = _bandY(i + 1, r);
      c.drawPath(
          Path()
            ..moveTo(r, y0)
            ..lineTo(r + _dx, y0 + _dy)
            ..lineTo(r + _dx, y1 + _dy)
            ..lineTo(r, y1)
            ..close(),
          D.fill(Color.lerp(_bands[i], Pal.white, .25)!));
    }
    final hs = 20 + sin(r * .06) * 8;
    D.heart(c, Offset(r + _dx / 2, (_top + _bottom) / 2 + _dy / 2 + 4), hs, const Color(0xFFFF7FAE), border: const Color(0xFFE05A8A));
    D.star(c, Offset(r + _dx / 2, _top + 22 + _dy / 2 + (r % 30)), 6, Pal.white);
    // fresh-cut sheen
    c.drawPath(
        Path()
          ..moveTo(r + 2, _top + 6)
          ..lineTo(r + _dx - 4, _top + _dy + 10)
          ..lineTo(r + _dx - 4, _top + _dy + 24)
          ..lineTo(r + 2, _top + 20)
          ..close(),
        D.fill(const Color(0x66FFFFFF)));
    // outline
    final outline = Path()
      ..moveTo(l, _bottom)
      ..lineTo(l, _top)
      ..lineTo(l + _dx, _top + _dy)
      ..lineTo(r + _dx, _top + _dy)
      ..lineTo(r + _dx, _bottom + _dy)
      ..lineTo(r, _bottom)
      ..close();
    c.drawPath(outline, D.stroke(const Color(0xFF9A7AB8), 3));
    D.line(c, Offset(r, _top), Offset(r, _bottom), const Color(0xFF9A7AB8), 2);
    D.line(c, Offset(r, _top), Offset(r + _dx, _top + _dy), const Color(0xFF9A7AB8), 2);
    // dashed cut guide
    if (!host.finished) {
      final gx = _guideX;
      final a = .5 + .5 * M.wave(_t, 2);
      final p = D.stroke(Color.fromRGBO(255, 255, 255, a), 3);
      for (var y = _top + 4; y < _bottom; y += 14) {
        c.drawLine(Offset(gx, y), Offset(gx, min(y + 7, _bottom)), p);
      }
      c.drawLine(Offset(gx, _top), Offset(gx + _dx, _top + _dy), p);
    }
    c.restore();
  }

  void _renderSlice(Canvas c, _Slice s) {
    // sheet peels outward around its bottom edge, then drops
    final k = (s.t / .45).clamp(0.0, 1.0);
    final ang = M.easeOut(k) * (s.perfect ? 1.35 : 1.1);
    final pivot = Offset(s.x + _thick, _bottom);
    final fall = max(0.0, s.t - .3) * 200;
    c.save();
    c.translate(pivot.dx + fall * .6, pivot.dy - fall * .1);
    c.rotate(ang);
    final curl = s.perfect ? k * 30 : 0.0;
    for (var i = 0; i < 5; i++) {
      final y0 = s.ys[i] - _bottom, y1 = s.ys[i + 1] - _bottom;
      final bend0 = curl * pow((-y0) / 140, 2), bend1 = curl * pow((-y1) / 140, 2);
      final path = Path()
        ..moveTo(-_thick + bend0, y0)
        ..lineTo(bend0, y0)
        ..lineTo(bend1, y1)
        ..lineTo(-_thick + bend1, y1)
        ..close();
      c.drawPath(path, D.fill(_bands[i]));
      if (!s.perfect && i.isOdd) {
        c.drawLine(Offset(-_thick + bend0, y0 + 6), Offset(bend0 - 3, y0 + 12), D.stroke(_bandDark[i], 1.5));
      }
    }
    final b = curl;
    c.drawPath(
        Path()
          ..moveTo(-_thick, 0)
          ..lineTo(0, 0)
          ..lineTo(b, -140)
          ..lineTo(-_thick + b, -140)
          ..close(),
        D.stroke(const Color(0xAA9A7AB8), 2));
    c.restore();
  }

  void _renderKnife(Canvas c) {
    if (host.finished && _winT > .3) return;
    final gx = _guideX + _thick;
    final k = _knifeAnim;
    final by = k > 0 ? _top - 70 + sin((1 - k) * pi) * 150 : _top - 76 + sin(_t * 3) * 4;
    final x = (k > 0 ? gx + _thick : _guideX) - 2;
    c.save();
    c.translate(x, by);
    // handle
    D.rrect(c, const Rect.fromLTWH(-9, -86, 18, 50), 8, const Color(0xFF8C5AD8), border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < 3; i++) {
      D.circle(c, Offset(0, -76 + i * 14.0), 2.5, const Color(0xFFE6D6FF));
    }
    // blade
    final blade = Path()
      ..moveTo(-8, -36)
      ..lineTo(8, -36)
      ..lineTo(8, 40)
      ..lineTo(-8, 56)
      ..close();
    c.drawPath(blade, D.fill(const Color(0xFFE6ECF4)));
    c.drawPath(
        Path()
          ..moveTo(2, -36)
          ..lineTo(8, -36)
          ..lineTo(8, 40)
          ..lineTo(2, 46)
          ..close(),
        D.fill(const Color(0xFFB8C4D4)));
    c.drawPath(blade, D.stroke(Pal.ink, 3));
    D.line(c, const Offset(-4, -26), const Offset(-4, 20), const Color(0xAAFFFFFF), 2);
    c.restore();
  }

  void _renderHud(Canvas c) {
    // slice counter pills
    for (var i = 0; i < _target; i++) {
      final x = 40 + i * 25.0;
      final on = i < _cuts;
      D.rrect(c, Rect.fromLTWH(x - 9, 50, 18, 26), 6, on ? _bands[i % 5] : const Color(0x55FFFFFF),
          border: on ? Pal.ink : const Color(0x559A7AB8), borderWidth: 2);
    }
    D.text(c, '$_cuts / $_target', const Offset(180, 100), size: 24, color: Pal.white, stroke: const Color(0xFF9A7AB8));
    if (_combo >= 2) {
      D.text(c, '${host.tr('combo', 'COMBO')} x$_combo', const Offset(180, 132), size: 18, color: Pal.pink, stroke: Pal.white,
          strokeWidth: 4);
    }
  }
}

class _Slice {
  _Slice(this.x, this.perfect, this.ys);
  final double x;
  final bool perfect;
  final List<double> ys;
  double t = 0;
  bool landed = false;
}

class _Crumb {
  _Crumb(this.pos, this.vx, this.vy, this.size, this.band, this.rot, this.spin, this.stack);
  Offset pos;
  double vx, vy;
  final double size;
  final int band;
  double rot;
  final double spin;
  final double stack;
  bool rest = false;
}
