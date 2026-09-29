import '../engine/engine.dart';

/// No.127 Potion Brewer — match the recipe color.
///
/// Tap the RED / YELLOW / BLUE flasks to drip color into the cauldron
/// (paint-style RYB mixing), stir with circular drags to blend, then hit BREW.
/// Close enough = potion! Way off (or 7+ drops) = KABOOM. Brew 3 to win.
class G127 extends MiniGame {
  double _t = 0;
  final List<int> _drops = [0, 0, 0]; // r, y, b
  double _mix = 1;
  Color _before = const Color(0xFF3B7A6A);
  Color _shown = const Color(0xFF3B7A6A);
  final List<_Swirl> _swirls = [];
  final List<_Drip> _drips = [];
  final List<_Bubble> _bubbles = [];
  final List<double> _tilt = [0, 0, 0];

  // stirring
  bool _stirring = false;
  double _lastAng = 0;
  double _stirVel = 0;
  Offset _ladle = const Offset(250, 330);

  // recipes
  late final List<List<int>> _recipes;
  int _done = 0;
  int _fails = 0;
  bool _showHint = true;
  final List<Color> _shelf = [];

  // animations
  double _brewT = -1; // success: potion rises
  Color _brewColor = Pal.white;
  double _boomT = -1; // explosion
  double _soot = 0;
  double _catHappy = 0;
  double _press = 0;
  String _grade = '';

  static const _pot = Offset(180, 362); // liquid surface center
  static const _potRx = 108.0, _potRy = 26.0;
  static const _bottleX = [52.0, 132.0, 212.0];
  static const _bottleY = 560.0;
  static const _brewBtn = Offset(304, 556);
  static const _dropCols = [Color(0xFFFF3B3B), Color(0xFFFFD83A), Color(0xFF2F6BFF)];

  @override
  void init() {
    const t1 = [
      [1, 0, 1],
      [0, 1, 1],
      [1, 1, 0],
    ];
    const t2 = [
      [2, 1, 0],
      [0, 2, 1],
      [1, 0, 2],
      [2, 0, 1],
      [1, 2, 0],
      [0, 1, 2],
    ];
    const t3 = [
      [1, 1, 1],
      [2, 1, 1],
      [1, 2, 1],
    ];
    _recipes = [pick(t1), pick(t2), pick(t3)];
    for (var i = 0; i < 9; i++) {
      _bubbles.add(_Bubble(rand(-90, 90), rand(0, 1), rand(3, 7)));
    }
  }

  // ------------------------------------------------------------ color math
  /// Paint-like RYB -> RGB (trilinear interpolation of the RYB cube).
  static Color ryb(double r, double y, double b) {
    final m = max(r, max(y, b));
    if (m <= 0) return const Color(0xFF3B7A6A);
    r /= m;
    y /= m;
    b /= m;
    const c = [
      [1.0, 1.0, 1.0], // 000 white
      [1.0, 0.0, 0.0], // 100 red
      [1.0, 1.0, 0.0], // 010 yellow
      [1.0, 0.5, 0.0], // 110 orange
      [0.163, 0.373, 0.8], // 001 blue
      [0.55, 0.0, 0.6], // 101 purple
      [0.0, 0.66, 0.2], // 011 green
      [0.25, 0.12, 0.05], // 111 brown-black
    ];
    double ch(int k) {
      final c00 = c[0][k] * (1 - r) + c[1][k] * r;
      final c10 = c[2][k] * (1 - r) + c[3][k] * r;
      final c01 = c[4][k] * (1 - r) + c[5][k] * r;
      final c11 = c[6][k] * (1 - r) + c[7][k] * r;
      final c0 = c00 * (1 - y) + c10 * y;
      final c1 = c01 * (1 - y) + c11 * y;
      return c0 * (1 - b) + c1 * b;
    }

    return Color.fromARGB(255, (ch(0) * 255).round(), (ch(1) * 255).round(), (ch(2) * 255).round());
  }

  Color _colorOf(List<int> d) => ryb(d[0].toDouble(), d[1].toDouble(), d[2].toDouble());

  int get _total => _drops[0] + _drops[1] + _drops[2];

  List<int> get _target => _recipes[min(_done, 2)];

  /// 0..1 similarity of the drop ratios.
  double get _match {
    final tot = _total;
    if (tot == 0) return 0;
    final tt = _target[0] + _target[1] + _target[2];
    var l1 = 0.0;
    for (var i = 0; i < 3; i++) {
      l1 += (_drops[i] / tot - _target[i] / tt).abs();
    }
    return M.clamp01(1 - l1 * 1.15);
  }

  double get _quality => _match * (.55 + .45 * _mix);

  bool get _busy => _brewT >= 0 || _boomT >= 0;

  // ---------------------------------------------------------------- update
  @override
  void update(double dt) {
    _t += dt;
    _press = max(0, _press - dt * 4);
    _catHappy = max(0, _catHappy - dt);
    _soot = max(0, _soot - dt * .35);
    for (var i = 0; i < 3; i++) {
      _tilt[i] = M.approach(_tilt[i], 0, 6, dt);
    }
    // natural slow mixing + stirring
    _stirVel = M.approach(_stirVel, 0, 3, dt);
    if (_total > 0) _mix = min(1, _mix + dt * (.22 + _stirVel * .5));
    final mixed = _colorOf(_drops);
    _shown = Color.lerp(_before, mixed, M.easeOut(_mix))!;
    for (final s in _swirls) {
      s.ang += dt * (1.2 + _stirVel * 3);
      s.life = min(s.life, 1 - _mix);
    }
    _swirls.removeWhere((s) => s.life <= 0);
    for (final b in _bubbles) {
      b.t += dt * (0.7 + _stirVel * .8 + (_boomT >= 0 ? 3 : 0));
      if (b.t > 1) {
        b.t -= 1;
        b.x = rand(-90, 90);
      }
    }
    // drips in flight
    for (final d in _drips) {
      d.t += dt / .38;
      if (d.t >= 1 && !d.landed) {
        d.landed = true;
        _land(d.col);
      }
    }
    _drips.removeWhere((d) => d.landed);

    if (_brewT >= 0) {
      _brewT += dt;
      if (_brewT > 1.15) {
        _brewT = -1;
        _shelf.add(_brewColor);
        _done++;
        _reset(clearColor: true);
        if (_done >= 3 && !host.finished) {
          host.fx.confetti();
          host.sfx(Sfx.fanfare);
          host.win(stars: _fails == 0 ? 3 : (_fails == 1 ? 2 : 1));
        } else {
          host.sfx(Sfx.notify);
          _showHint = false;
        }
      }
    }
    if (_boomT >= 0) {
      _boomT += dt;
      if (_boomT > .9) _boomT = -1;
    }
  }

  void _reset({bool clearColor = false}) {
    _drops.setAll(0, [0, 0, 0]);
    _mix = 1;
    _swirls.clear();
    if (clearColor) {
      _before = const Color(0xFF3B7A6A);
    }
  }

  void _land(int col) {
    if (_busy) return;
    _before = _shown;
    _drops[col]++;
    _mix = 0;
    _swirls.add(_Swirl(col, rand(0, pi * 2), rand(20, 70)));
    host.sfx(Sfx.drip, rate: .9 + _total * .06);
    host.sfx(Sfx.splash, volume: .4, rate: 1.3);
    host.fx.burst(_pot + Offset(rand(-20, 20), 0), _dropCols[col], count: 8, speed: 150, gravity: 500, size: 5);
    if (_total > 6) {
      _explode(overflow: true);
    }
  }

  void _addDrop(int col) {
    if (_busy || host.finished) return;
    _tilt[col] = 1;
    _drips.add(_Drip(col, Offset(_bottleX[col] + 12, _bottleY - 62), _pot + Offset(rand(-40, 40), 0)));
    host.sfx(Sfx.pour, volume: .5, rate: 1.4);
  }

  void _brew() {
    if (_busy || host.finished) return;
    _press = 1;
    if (_total == 0) {
      host.sfx(Sfx.wrong, volume: .5);
      return;
    }
    final q = _quality;
    if (q >= .74) {
      _brewT = 0;
      _brewColor = _shown;
      _catHappy = 1.5;
      _grade = q >= .95
          ? host.tr('perfect', 'PERFECT!')
          : q >= .86
              ? host.tr('great', 'GREAT!')
              : host.tr('good', 'GOOD');
      host.sfx(Sfx.magic);
      host.sfx(q >= .95 ? Sfx.perfect : Sfx.correct, volume: .8);
      host.fx.pop(_grade, const Offset(180, 250), color: q >= .95 ? Pal.yellow : Pal.lime, size: 34);
      host.fx.sparkle(_pot, count: 16, radius: 90, color: Pal.yellow);
      host.fx.ring(_pot, _shown, size: 150);
      host.addScore((q * 100).round(), _pot + const Offset(0, -80));
      host.punch(.04);
    } else {
      _explode();
    }
  }

  void _explode({bool overflow = false}) {
    _boomT = 0;
    _fails++;
    _soot = 1;
    _showHint = true;
    host.sfx(Sfx.explode);
    host.sfx(Sfx.oops, volume: .7);
    host.shake(14, .5);
    host.flash(const Color(0xAAFFFFFF), .2);
    host.hitStop(.08);
    host.fx.smoke(_pot + const Offset(0, -30), count: 18, color: const Color(0xDD4A4458), size: 32);
    host.fx.burst(_pot, _shown, count: 30, speed: 420, gravity: 600, size: 8);
    host.fx.burst(_pot, Pal.orange, count: 14, speed: 300, shape: PartShape.spark, gravity: 0);
    host.fx.pop(overflow ? host.tr('overflow', 'OVERFLOW!') : host.tr('kaboom', 'KABOOM!'), const Offset(180, 240),
        color: Pal.orange, size: 38);
    _reset();
    _before = const Color(0xFF3A3A3A);
    _mix = 0;
  }

  // ----------------------------------------------------------------- input
  bool _inPot(Offset p) {
    final dx = (p.dx - _pot.dx) / (_potRx * 1.25), dy = (p.dy - _pot.dy - 10) / (_potRy * 2.8);
    return dx * dx + dy * dy < 1;
  }

  double _angle(Offset p) => atan2((p.dy - _pot.dy) / _potRy, (p.dx - _pot.dx) / _potRx);

  @override
  void onDown(Offset p) {
    for (var i = 0; i < 3; i++) {
      if ((p - Offset(_bottleX[i], _bottleY - 20)).distance < 42) {
        _addDrop(i);
        return;
      }
    }
    if ((p - _brewBtn).distance < 46) {
      _brew();
      return;
    }
    if (_inPot(p)) {
      _stirring = true;
      _lastAng = _angle(p);
      _ladle = p;
    }
  }

  @override
  void onMove(Offset p) {
    if (!_stirring) return;
    _ladle = Offset(p.dx.clamp(_pot.dx - _potRx + 10, _pot.dx + _potRx - 10), p.dy.clamp(_pot.dy - _potRy * 2, _pot.dy + _potRy * 2));
    final a = _angle(p);
    var d = a - _lastAng;
    if (d > pi) d -= pi * 2;
    if (d < -pi) d += pi * 2;
    _lastAng = a;
    if (_busy) return;
    final turn = d.abs() / (pi * 2);
    _stirVel = min(3, _stirVel + turn * 6);
    if (_total > 0 && _mix < 1) {
      _mix = min(1, _mix + turn * .9);
      if (_mix >= 1) {
        host.sfx(Sfx.sparkle, volume: .6);
        host.fx.sparkle(_pot, count: 8, radius: 70);
      }
    }
    if (chance(turn * 3)) host.sfx(Sfx.bubble, volume: .4, rate: rand(.8, 1.4));
  }

  @override
  void onUp(Offset p) => _stirring = false;

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    switch (key) {
      case 'left':
        _addDrop(0);
      case 'up':
        _addDrop(1);
      case 'right':
        _addDrop(2);
      case 'down':
        _stirVel = min(3, _stirVel + 1.5);
        if (_total > 0) _mix = min(1, _mix + .3);
      case 'action':
        _brew();
    }
  }

  // ---------------------------------------------------------------- render
  @override
  void render(Canvas c) {
    _renderRoom(c);
    _renderCat(c);
    _renderCauldron(c);
    _renderRecipe(c);
    _renderShelf(c);
    for (final d in _drips) {
      final p = Offset.lerp(d.from, d.to, d.t)! + Offset(0, -sin(d.t * pi) * 40);
      c.drawPath(_dropPath(p, 9), D.fill(_dropCols[d.col]));
      c.drawPath(_dropPath(p, 9), D.stroke(Pal.ink, 2));
    }
    _renderBottles(c);
    if (host.time < 2.2 && _total == 0 && _done == 0) {
      final idx = _target.indexWhere((v) => v > 0);
      D.hand(c, Offset(_bottleX[idx], _bottleY - 10), _t);
    } else if (_total > 0 && _mix < .6 && host.time < 7 && _done == 0) {
      final a = _t * 5;
      D.hand(c, _pot + Offset(cos(a) * 60, sin(a) * 18), _t, size: 40);
      D.text(c, host.tr('stir', 'STIR!'), _pot + const Offset(0, -70), size: 22, color: Pal.white, stroke: Pal.ink);
    }
  }

  Path _dropPath(Offset p, double r) => Path()
    ..moveTo(p.dx, p.dy - r * 1.6)
    ..quadraticBezierTo(p.dx + r, p.dy - r * .2, p.dx + r * .8, p.dy + r * .3)
    ..arcToPoint(Offset(p.dx - r * .8, p.dy + r * .3), radius: Radius.circular(r * .85))
    ..quadraticBezierTo(p.dx - r, p.dy - r * .2, p.dx, p.dy - r * 1.6)
    ..close();

  void _renderRoom(Canvas c) {
    D.gradientBg(c, const [Color(0xFF2A1A45), Color(0xFF140C24)]);
    // bricks
    final mortar = D.stroke(const Color(0x22000000), 2);
    for (var row = 0; row < 20; row++) {
      final y = 40.0 + row * 30;
      c.drawLine(Offset(0, y), Offset(360, y), mortar);
      for (var x = (row.isEven ? 0.0 : 30.0); x < 360; x += 60) {
        c.drawLine(Offset(x, y), Offset(x, y + 30), mortar);
      }
    }
    for (var i = 0; i < 8; i++) {
      final x = (i * 83.0) % 340 + 10, y = 60 + (i * 71.0) % 400;
      c.drawRect(Rect.fromLTWH(x, y, 26, 12), D.fill(const Color(0x14FFFFFF)));
    }
    // arched window with moon
    final win = RRect.fromRectAndCorners(const Rect.fromLTWH(262, 170, 76, 100), topLeft: const Radius.circular(38), topRight: const Radius.circular(38));
    c.drawRRect(win, D.fill(const Color(0xFF1C2C5C)));
    c.drawCircle(const Offset(300, 205), 18, D.fill(const Color(0xFFFFF2B0)));
    c.drawCircle(const Offset(308, 199), 16, D.fill(const Color(0xFF1C2C5C)));
    for (var i = 0; i < 4; i++) {
      c.drawCircle(Offset(275 + i * 17.0, 240 + (i % 2) * 12.0), 1.5, D.fill(Pal.white));
    }
    c.drawRRect(win, D.stroke(const Color(0xFF5A4A3A), 6));
    D.line(c, const Offset(300, 170), const Offset(300, 270), const Color(0xFF5A4A3A), 4);
    D.line(c, const Offset(262, 225), const Offset(338, 225), const Color(0xFF5A4A3A), 4);
    // hanging bat
    final by = 176 + sin(_t * 2) * 3;
    D.line(c, const Offset(40, 160), Offset(40, by - 6), const Color(0x66FFFFFF), 1);
    c.drawCircle(Offset(40, by), 7, D.fill(Pal.ink));
    c.drawPath(
        Path()
          ..moveTo(33, by)
          ..lineTo(20, by + 6 - sin(_t * 3) * 3)
          ..lineTo(34, by + 10)
          ..moveTo(47, by)
          ..lineTo(60, by + 6 - sin(_t * 3) * 3)
          ..lineTo(46, by + 10),
        D.fill(Pal.ink));
    c.drawCircle(Offset(37, by + 2), 1.5, D.fill(Pal.red));
    c.drawCircle(Offset(43, by + 2), 1.5, D.fill(Pal.red));
    // candles
    for (final x in const [24.0, 336.0]) {
      D.rrect(c, Rect.fromLTWH(x - 7, 440, 14, 40), 3, const Color(0xFFF4E8D0));
      c.drawCircle(Offset(x, 430), 26, D.fill(const Color(0x22FFB84D)));
      D.flame(c, Offset(x, 440), 18, _t + x);
    }
    // floor
    c.drawRect(const Rect.fromLTWH(0, 480, 360, 160), D.fill(const Color(0xFF1E1430)));
    D.line(c, const Offset(0, 480), const Offset(360, 480), const Color(0xFF3A2A5A), 3);
  }

  void _renderCat(Canvas c) {
    // black cat familiar sits on the left, reacting
    const o = Offset(40, 330);
    final sootK = _soot;
    final body = Color.lerp(const Color(0xFF2B2440), const Color(0xFF111111), sootK)!;
    c.drawOval(Rect.fromCenter(center: o + const Offset(0, 30), width: 46, height: 50), D.fill(body));
    // tail
    c.drawPath(
        Path()
          ..moveTo(o.dx + 18, o.dy + 46)
          ..quadraticBezierTo(o.dx + 44, o.dy + 40, o.dx + 34 + sin(_t * 3) * 6, o.dy + 10),
        D.stroke(body, 7));
    c.drawCircle(o, 22, D.fill(body));
    for (final s in [-1.0, 1.0]) {
      c.drawPath(
          Path()
            ..moveTo(o.dx + s * 18, o.dy - 8)
            ..lineTo(o.dx + s * 16, o.dy - 30)
            ..lineTo(o.dx + s * 4, o.dy - 18)
            ..close(),
          D.fill(body));
    }
    if (sootK > .3) {
      // frazzled fur spikes + dazed eyes
      for (var i = 0; i < 7; i++) {
        final a = -pi + i * pi / 6;
        D.line(c, o + Offset(cos(a) * 20, sin(a) * 20), o + Offset(cos(a) * 30, sin(a) * 30), body, 4);
      }
      D.face(c, o + const Offset(0, 2), 18, Face.dead, ink: Pal.white, blush: false);
    } else if (_catHappy > 0) {
      D.face(c, o + const Offset(0, 2), 18, Face.happy, ink: const Color(0xFFFFE070), blush: true);
    } else {
      final look = Offset(((_ladle.dx - o.dx) / 200).clamp(-1, 1), .3);
      for (final s in [-1.0, 1.0]) {
        c.drawOval(Rect.fromCenter(center: o + Offset(s * 8, -2), width: 11, height: 12), D.fill(const Color(0xFFB8FF5A)));
        c.drawOval(Rect.fromCenter(center: o + Offset(s * 8 + look.dx * 2, -2), width: 3, height: 9), D.fill(Pal.ink));
      }
      c.drawCircle(o + const Offset(0, 6), 2, D.fill(Pal.pink));
    }
  }

  void _renderCauldron(Canvas c) {
    // green fire
    for (var i = 0; i < 5; i++) {
      final x = 110 + i * 35.0;
      c.save();
      c.translate(x, 470);
      c.scale(1, 1);
      final h = 44 + sin(_t * 9 + i * 2) * 8 + (_boomT >= 0 ? 20 : 0);
      for (var k = 0; k < 3; k++) {
        final kk = 1 - k * .3;
        final wob = sin(_t * 16 + i + k) * 4;
        c.drawPath(
            Path()
              ..moveTo(-16 * kk, 0)
              ..quadraticBezierTo(-18 * kk, -h * .5 * kk, wob, -h * kk)
              ..quadraticBezierTo(18 * kk, -h * .5 * kk, 16 * kk, 0)
              ..close(),
            D.fill(const [Color(0xFF1FAF5A), Color(0xFF6BFF6B), Color(0xFFE0FFB0)][k]));
      }
      c.restore();
    }
    c.drawOval(const Rect.fromLTWH(70, 440, 220, 50), D.fill(const Color(0x33B8FF5A)));
    // logs
    D.rrect(c, const Rect.fromLTWH(86, 466, 188, 18), 9, const Color(0xFF5A3A22), border: Pal.ink, borderWidth: 2);
    // pot body
    final potBody = Path()
      ..moveTo(_pot.dx - _potRx - 8, _pot.dy)
      ..cubicTo(_pot.dx - _potRx - 36, _pot.dy + 80, _pot.dx - 70, _pot.dy + 118, _pot.dx, _pot.dy + 118)
      ..cubicTo(_pot.dx + 70, _pot.dy + 118, _pot.dx + _potRx + 36, _pot.dy + 80, _pot.dx + _potRx + 8, _pot.dy)
      ..close();
    c.drawPath(
        potBody,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFF3A3450), Color(0xFF15121F), Color(0xFF08070C)], stops: [0, .5, 1])
              .createShader(Rect.fromLTWH(_pot.dx - 140, _pot.dy, 280, 120)));
    c.drawPath(potBody, D.stroke(Pal.ink, 4));
    c.drawOval(Rect.fromCenter(center: _pot + const Offset(-55, 50), width: 26, height: 50), D.fill(const Color(0x22FFFFFF)));
    // drop pips on the pot front
    var k = 0;
    for (var col = 0; col < 3; col++) {
      for (var n = 0; n < _drops[col]; n++) {
        final p = Offset(_pot.dx - (_total - 1) * 10 + k * 20, _pot.dy + 78);
        c.drawPath(_dropPath(p, 7), D.fill(_dropCols[col]));
        c.drawPath(_dropPath(p, 7), D.stroke(Pal.ink, 1.5));
        k++;
      }
    }
    // legs
    for (final s in [-1.0, 1.0]) {
      c.drawRect(Rect.fromCenter(center: _pot + Offset(s * 70, 118), width: 14, height: 18), D.fill(const Color(0xFF15121F)));
    }
    // liquid surface
    final surf = Rect.fromCenter(center: _pot, width: _potRx * 2, height: _potRy * 2);
    final liq = _shown;
    c.drawOval(surf, D.fill(liq));
    c.save();
    c.clipPath(Path()..addOval(surf));
    c.drawOval(surf.shift(const Offset(0, 8)), D.fill(Color.lerp(liq, Pal.ink, .25)!));
    c.drawOval(Rect.fromCenter(center: _pot + const Offset(-10, -4), width: _potRx * 1.6, height: _potRy * 1.2), D.fill(Color.lerp(liq, Pal.white, .2)!));
    // unmixed swirls
    for (final s in _swirls) {
      final a = s.life;
      final path = Path();
      for (var i = 0; i <= 14; i++) {
        final ang = s.ang + i * .35;
        final rr = s.r * (1 - i / 22);
        final p = _pot + Offset(cos(ang) * rr * 1.2, sin(ang) * rr * .3);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      c.drawPath(path, D.stroke(_dropCols[s.col].withValues(alpha: a * .9), 9 * a + 2));
    }
    // bubbles
    for (final b in _bubbles) {
      final p = _pot + Offset(b.x, sin(b.t * pi * 2 + b.x) * 8);
      final r = b.r * sin(b.t * pi);
      c.drawCircle(p, r, D.fill(Color.lerp(liq, Pal.white, .35)!));
      c.drawCircle(p, r, D.stroke(Color.lerp(liq, Pal.ink, .4)!, 1.5));
    }
    c.restore();
    // steam
    for (var i = 0; i < 4; i++) {
      final t = (_t * .5 + i * .25) % 1.0;
      c.drawCircle(_pot + Offset(sin(t * 6 + i) * 30 + (i - 1.5) * 40, -20 - t * 100), 10 + t * 16,
          D.fill(Color.lerp(liq, Pal.white, .6)!.withValues(alpha: .25 * (1 - t))));
    }
    // rim
    c.drawOval(surf.inflate(10), D.stroke(const Color(0xFF4A4460), 14));
    c.drawOval(surf.inflate(10), D.stroke(Pal.ink, 2));
    c.drawArc(surf.inflate(10), pi * 1.1, pi * .5, false, D.stroke(const Color(0x55FFFFFF), 4));
    // ladle
    final lp = _ladle;
    final handle = lp + const Offset(40, -150);
    D.line(c, lp, handle, const Color(0xFF7A4A22), 10);
    D.line(c, lp, handle, const Color(0xFF9E6A3A), 5);
    c.drawOval(Rect.fromCenter(center: lp, width: 26, height: 12), D.fill(const Color(0xFF6A3A1A)));
    // mix meter
    if (_total > 0 && !_busy) {
      final r = Rect.fromCenter(center: _pot + const Offset(0, 140), width: 140, height: 12);
      D.bar(c, r, _mix, _mix >= 1 ? Pal.lime : Pal.sky, border: Pal.ink);
      if (_mix >= 1) D.star(c, r.centerRight + const Offset(10, 0), 9, Pal.yellow, border: Pal.ink);
    }
    // brewed potion rising
    if (_brewT >= 0) {
      final k = M.clamp01(_brewT / .5);
      final fly = M.clamp01((_brewT - .6) / .5);
      final start = _pot + Offset(0, -20 - M.easeOutBack(k) * 90);
      final end = _shelfSlot(_done);
      final p = Offset.lerp(start, end, M.easeInOut(fly))!;
      D.rays(c, p, 90 * (1 - fly), const Color(0x44FFF2A0), count: 12, t: _t * 2);
      _potion(c, p, 1.3 - fly * .6, _brewColor);
    }
  }

  Offset _shelfSlot(int i) => Offset(236 + i * 44.0, 122);

  void _potion(Canvas c, Offset o, double s, Color col) {
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s);
    final flask = Path()
      ..moveTo(-6, -24)
      ..lineTo(-6, -10)
      ..quadraticBezierTo(-20, -4, -20, 8)
      ..quadraticBezierTo(-20, 22, 0, 22)
      ..quadraticBezierTo(20, 22, 20, 8)
      ..quadraticBezierTo(20, -4, 6, -10)
      ..lineTo(6, -24)
      ..close();
    c.drawPath(flask, D.fill(const Color(0x55FFFFFF)));
    c.save();
    c.clipPath(flask);
    c.drawRect(const Rect.fromLTWH(-22, -4, 44, 30), D.fill(col));
    c.drawOval(const Rect.fromLTWH(-20, -8, 40, 8), D.fill(Color.lerp(col, Pal.white, .3)!));
    c.restore();
    c.drawPath(flask, D.stroke(Pal.ink, 2.5));
    D.rrect(c, const Rect.fromLTWH(-7, -30, 14, 8), 2, const Color(0xFFB07A4A), border: Pal.ink, borderWidth: 2);
    c.drawOval(const Rect.fromLTWH(-14, 0, 6, 12), D.fill(const Color(0x88FFFFFF)));
    c.restore();
  }

  void _renderRecipe(Canvas c) {
    // parchment card
    const r = Rect.fromLTWH(14, 44, 190, 104);
    c.save();
    c.translate(r.center.dx, r.center.dy);
    c.rotate(-.03);
    final rr = Rect.fromCenter(center: Offset.zero, width: r.width, height: r.height);
    D.rrect(c, rr, 8, const Color(0xFFF3E2B8), border: const Color(0xFF6A4A2A), borderWidth: 3);
    D.text(c, '${host.tr('recipe', 'RECIPE')} ${min(_done + 1, 3)}/3', Offset(rr.left + 60, rr.top + 16), size: 13, color: const Color(0xFF6A4A2A));
    final tc = _colorOf(_target);
    c.drawCircle(Offset(rr.left + 60, rr.top + 60), 30, D.fill(tc.withValues(alpha: .35)));
    _potion(c, Offset(rr.left + 60, rr.top + 64), 1.05, tc);
    // match meter
    final m = _total == 0 ? 0.0 : _quality;
    final mc = m >= .74 ? Pal.lime : (m >= .5 ? Pal.orange : Pal.red);
    D.text(c, '${(m * 100).round()}%', Offset(rr.left + 146, rr.top + 40), size: 24, color: mc, stroke: Pal.ink, strokeWidth: 4);
    D.bar(c, Rect.fromLTWH(rr.left + 110, rr.top + 60, 70, 10), m, mc, border: Pal.ink);
    // hint pips (first recipe, or after a kaboom)
    if (_showHint) {
      var k = 0;
      final n = _target[0] + _target[1] + _target[2];
      for (var col = 0; col < 3; col++) {
        for (var i = 0; i < _target[col]; i++) {
          final p = Offset(rr.left + 145 - (n - 1) * 8 + k * 16, rr.top + 88);
          c.drawPath(_dropPath(p, 6), D.fill(_dropCols[col]));
          c.drawPath(_dropPath(p, 6), D.stroke(Pal.ink, 1.5));
          k++;
        }
      }
    }
    c.restore();
  }

  void _renderShelf(Canvas c) {
    D.rrect(c, const Rect.fromLTWH(212, 142, 136, 10), 3, const Color(0xFF6A4A2A), border: Pal.ink, borderWidth: 2);
    for (var i = 0; i < 3; i++) {
      final p = _shelfSlot(i);
      if (i < _shelf.length) {
        _potion(c, p, .72, _shelf[i]);
      } else {
        c.drawCircle(p + const Offset(0, 4), 13, D.stroke(const Color(0x44FFFFFF), 2));
        D.text(c, '?', p + const Offset(0, 4), size: 14, color: const Color(0x44FFFFFF));
      }
    }
  }

  void _renderBottles(Canvas c) {
    for (var i = 0; i < 3; i++) {
      final base = Offset(_bottleX[i], _bottleY);
      c.drawOval(Rect.fromCenter(center: base + const Offset(0, 30), width: 60, height: 14), D.fill(const Color(0x44000000)));
      c.save();
      c.translate(base.dx, base.dy + 28);
      c.rotate(_tilt[i] * .9);
      c.translate(0, -28);
      final col = _dropCols[i];
      final flask = Path()
        ..moveTo(-9, -52)
        ..lineTo(-9, -26)
        ..quadraticBezierTo(-30, -16, -30, 4)
        ..quadraticBezierTo(-30, 28, 0, 28)
        ..quadraticBezierTo(30, 28, 30, 4)
        ..quadraticBezierTo(30, -16, 9, -26)
        ..lineTo(9, -52)
        ..close();
      c.drawPath(flask, D.fill(const Color(0x44FFFFFF)));
      c.save();
      c.clipPath(flask);
      c.drawRect(const Rect.fromLTWH(-32, -14, 64, 44), D.fill(col));
      c.drawOval(const Rect.fromLTWH(-30, -18, 60, 10), D.fill(Color.lerp(col, Pal.white, .35)!));
      for (var k = 0; k < 3; k++) {
        final bt = (_t * .6 + k * .33 + i * .2) % 1.0;
        c.drawCircle(Offset(-12 + k * 12.0, 24 - bt * 36), 2.5, D.fill(const Color(0x88FFFFFF)));
      }
      c.restore();
      c.drawPath(flask, D.stroke(Pal.ink, 3));
      c.drawOval(const Rect.fromLTWH(-24, -8, 8, 22), D.fill(const Color(0x88FFFFFF)));
      D.rrect(c, const Rect.fromLTWH(-11, -62, 22, 12), 3, const Color(0xFFB07A4A), border: Pal.ink, borderWidth: 2);
      // label: a drop icon
      c.drawCircle(const Offset(0, 8), 11, D.fill(const Color(0xFFF3E2B8)));
      c.drawPath(_dropPath(const Offset(0, 10), 6), D.fill(col));
      c.drawPath(_dropPath(const Offset(0, 10), 6), D.stroke(Pal.ink, 1.5));
      c.restore();
    }
    // BREW button
    final pulse = !_busy && _total > 0 && _quality >= .74 ? 1 + sin(_t * 10) * .06 : 1.0;
    c.save();
    c.translate(_brewBtn.dx, _brewBtn.dy);
    c.scale(pulse * (1 - _press * .1));
    final ready = _total > 0 && _quality >= .74;
    final col = ready ? const Color(0xFFB04DFF) : const Color(0xFF6A6480);
    c.drawCircle(const Offset(0, 5), 40, D.fill(Color.lerp(col, Pal.ink, .5)!));
    c.drawCircle(Offset.zero, 40, D.fill(col));
    c.drawCircle(Offset.zero, 40, D.stroke(Pal.ink, 3));
    c.drawOval(const Rect.fromLTWH(-26, -32, 52, 22), D.fill(const Color(0x44FFFFFF)));
    D.star(c, const Offset(0, -12), 12, ready ? Pal.yellow : const Color(0xFFBBB5CC), border: Pal.ink);
    D.text(c, host.tr('brew', 'BREW!'), const Offset(0, 16), size: 17, color: Pal.white, stroke: Pal.ink, strokeWidth: 4, maxWidth: 76);
    c.restore();
  }
}

class _Swirl {
  _Swirl(this.col, this.ang, this.r);
  final int col;
  double ang;
  final double r;
  double life = 1;
}

class _Drip {
  _Drip(this.col, this.from, this.to);
  final int col;
  final Offset from, to;
  double t = 0;
  bool landed = false;
}

class _Bubble {
  _Bubble(this.x, this.t, this.r);
  double x, t;
  final double r;
}
