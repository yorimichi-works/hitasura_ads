import '../engine/engine.dart';

/// No.010 Fill to the Line — hold to pour soda, release to stop EXACTLY at
/// the line. Three glasses with different shapes (the level speeds up in
/// narrow parts!), the stream in the air keeps landing after release.
class G010 extends MiniGame {
  static const _nozzleY = 172.0;
  static const _bottomY = 556.0;
  static const _fallSpeed = 1500.0;
  static const _drinks = [Color(0xFF6B2D12), Color(0xFFFF8A1F), Color(0xFF7BD63A)];
  static const _drinkHi = [Color(0xFFA0522D), Color(0xFFFFC04D), Color(0xFFC6F57A)];

  double _t = 0;
  int _round = 0;
  int _state = 0; // 0 enter, 1 ready/pouring, 2 settling, 3 result, 4 done
  double _stateT = 0;
  final List<double> _errors = [];
  final List<int> _grades = []; // 0 perfect,1 great,2 good,3 miss
  bool _overflowed = false;

  // current glass
  late _Glass _glass;
  double _vol = 0; // 0..1 normalized
  double _level = 0; // 0..1 of glass height
  double _line = .75;
  double _foam = 0; // px
  double _wobble = 0;
  double _glassX = -200;

  // valve / stream
  bool _open = false;
  double _streamHead = _nozzleY; // bottom end of the falling column
  double _streamTail = _nozzleY; // top end (nozzle while open)
  double _pourSfxT = 0;
  double _press = 0;

  final List<_Bubble> _bubbles = [];
  double _reactT = 0;
  int _reactGrade = -1;

  @override
  void init() => _newGlass();

  void _newGlass() {
    _glass = _Glass.make(_round);
    _vol = 0;
    _level = 0;
    _foam = 0;
    _overflowed = false;
    _line = rand(.62, .82);
    _state = 0;
    _stateT = 0;
    _glassX = -180;
    _bubbles.clear();
    _streamHead = _nozzleY;
    _streamTail = _nozzleY;
    _open = false;
  }

  double get _surfaceY => _bottomY - _level * _glass.h;
  bool get _inflow => _streamHead >= _surfaceY - 1 && _streamTail < _surfaceY;

  @override
  void update(double dt) {
    _t += dt;
    _stateT += dt;
    _press = M.approach(_press, _open ? 1 : 0, 18, dt);
    _reactT = max(0, _reactT - dt);
    final rate = .72 * host.speed;

    if (_state == 0) {
      _glassX = M.lerp(-180, 180, M.easeOutBack(M.clamp01(_stateT / .35)));
      if (_stateT >= .35) {
        _glassX = 180;
        _state = 1;
        _stateT = 0;
        if (host.pointerDown) _setOpen(true);
      }
    }

    // stream physics
    final surf = _surfaceY;
    if (_open) {
      _streamTail = _nozzleY;
      _streamHead = min(surf, _streamHead + _fallSpeed * dt);
    } else {
      if (_streamTail < surf) _streamTail += _fallSpeed * dt;
      _streamHead = min(surf, _streamHead + _fallSpeed * dt);
      if (_streamTail >= surf) {
        _streamTail = _nozzleY;
        _streamHead = _nozzleY;
      }
    }
    final pouring = _state >= 1 && _state <= 2 && _inflow;
    if (pouring) {
      _vol += rate * dt;
      _foam = min(_glass.foamMax, _foam + 70 * dt);
      _wobble = min(1, _wobble + dt * 4);
      _pourSfxT -= dt;
      if (_pourSfxT <= 0) {
        _pourSfxT = .22;
        host.sfx(Sfx.pour, volume: .55, rate: .9 + _level * .5);
      }
      if (chance(dt * 30)) {
        _bubbles.add(_Bubble(rand(-1, 1), _surfaceY + rand(4, 30), rand(2, 5), rand(40, 110)));
      }
      if (chance(dt * 20)) {
        host.fx.add(Particle(
            pos: Offset(180 + rand(-6, 6), _surfaceY - 2), vel: Offset(rand(-90, 90), rand(-160, -60)), life: .4,
            color: _drinkHi[_round.clamp(0, 2)], size: 4, gravity: 700));
      }
    } else {
      _foam = max(0, _foam - 16 * dt);
      _wobble = M.approach(_wobble, 0, 3, dt);
    }
    _level = _glass.levelFor(_vol);

    // overflow
    if (_level >= 1 && !_overflowed && _state <= 2) {
      _overflowed = true;
      _vol = _glass.volTop;
      _setOpen(false);
      host.sfx(Sfx.splash);
      host.sfx(Sfx.oops, volume: .7);
      host.shake(6);
      for (final s in [-1.0, 1.0]) {
        host.fx.burst(Offset(180 + s * _glass.hw(1), _bottomY - _glass.h), _drinks[_round.clamp(0, 2)],
            count: 14, speed: 200, gravity: 900);
      }
    }
    if (_overflowed) {
      _vol = min(_vol, _glass.volTop);
      if (chance(dt * 25)) {
        final s = chance(.5) ? -1.0 : 1.0;
        host.fx.add(Particle(
            pos: Offset(180 + s * (_glass.hw(1) + 2), _bottomY - _glass.h + 4),
            vel: Offset(s * rand(10, 40), rand(20, 80)), life: .7, color: _drinks[_round.clamp(0, 2)], size: 6,
            gravity: 900));
      }
    }

    // bubbles
    for (final b in _bubbles) {
      b.y -= b.v * dt;
      b.x += sin(_t * 6 + b.v) * dt * .2;
    }
    _bubbles.removeWhere((b) => b.y < _surfaceY + 2);
    if (_level > .05 && _bubbles.length < 24 && chance(dt * 6)) {
      _bubbles.add(_Bubble(rand(-1, 1), _bottomY - 6, rand(1.5, 3.5), rand(30, 70)));
    }

    // state transitions
    if (_state == 2) {
      if (!_open && !_inflow && _stateT > .45) _judge();
    }
    if (_state == 3) {
      if (_stateT > .55) {
        _glassX = M.lerp(180, 560, M.easeInOut(M.clamp01((_stateT - .55) / .3)));
      }
      if (_stateT > .85) {
        _round++;
        if (_round >= 3) {
          _state = 4;
          _finish();
        } else {
          _newGlass();
        }
      }
    }
  }

  void _setOpen(bool v) {
    if (v == _open) return;
    if (v) {
      if (_state != 1 && _state != 2) return;
      _open = true;
      _state = 1;
      _stateT = 0;
      _streamHead = _nozzleY;
      host.sfx(Sfx.click, volume: .6);
    } else {
      _open = false;
      if (_state == 1) {
        _state = 2;
        _stateT = 0;
        host.sfx(Sfx.drip, rate: 1.2);
      }
    }
  }

  void _judge() {
    final err = _overflowed ? 60.0 : ((_level - _line).abs() * _glass.h);
    _errors.add(err);
    final g = _overflowed ? 3 : (err <= 4 ? 0 : (err <= 10 ? 1 : (err <= 20 ? 2 : 3)));
    _grades.add(g);
    _state = 3;
    _stateT = 0;
    _reactT = 1.0;
    _reactGrade = g;
    final at = Offset(180, _surfaceY - 60);
    switch (g) {
      case 0:
        host.sfx(Sfx.perfect);
        host.fx.pop(host.tr('perfect', 'PERFECT!'), at, color: Pal.yellow, size: 38, life: 1);
        host.fx.confetti(at: Offset(180, _surfaceY), count: 40);
        host.fx.ring(Offset(180, _surfaceY), Pal.white, size: 110);
        host.punch(.04);
        host.addScore(100, at + const Offset(0, 40));
      case 1:
        host.sfx(Sfx.correct);
        host.fx.pop(host.tr('great', 'GREAT!'), at, color: Pal.lime, size: 34);
        host.fx.sparkle(Offset(180, _surfaceY), count: 12, radius: 50, color: Pal.yellow);
        host.addScore(60, at + const Offset(0, 40));
      case 2:
        host.sfx(Sfx.ding);
        host.fx.pop(host.tr('good', 'GOOD'), at, color: Pal.sky, size: 30);
        host.addScore(30, at + const Offset(0, 40));
      default:
        host.sfx(Sfx.buzzer);
        host.fx.pop(_overflowed ? host.tr('oops', 'OOPS!') : host.tr('miss', 'MISS'), at, color: Pal.red, size: 34);
        host.shake(5);
    }
  }

  double get _avg => _errors.isEmpty ? 99 : _errors.reduce((a, b) => a + b) / _errors.length;

  void _finish() {
    final a = _avg;
    if (a <= 15) {
      host.sfx(Sfx.jingleWin);
      host.fx.confetti(count: 90);
      host.win(stars: a <= 5 ? 3 : (a <= 10 ? 2 : 1));
    } else {
      host.sfx(Sfx.jingleLose);
      host.lose();
    }
  }

  @override
  void onTimeUp() {
    if (_state == 1 || _state == 2) {
      if (_vol > .05) {
        _open = false;
        _judge();
      }
    }
    if (_errors.length >= 2 && _avg <= 15) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  @override
  void onDown(Offset p) => _setOpen(true);
  @override
  void onUp(Offset p) => _setOpen(false);
  @override
  void onKey(String key, bool down) {
    if (key == 'action') _setOpen(down);
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    // diner wall
    D.gradientBg(c, const [Color(0xFF3A1F5C), Color(0xFF8C3C7A), Color(0xFFFF9A6B)]);
    final tile = Paint()..color = const Color(0x14FFFFFF);
    for (var y = 0; y < 12; y++) {
      for (var x = 0; x < 8; x++) {
        if ((x + y).isEven) c.drawRect(Rect.fromLTWH(x * 48.0, 200 + y * 36.0, 48, 36), tile);
      }
    }
    // neon ring & glow in the back
    final neon = .6 + .4 * M.wave(_t, 1.3);
    c.drawCircle(const Offset(300, 250), 36, D.stroke(Color.fromRGBO(255, 95, 200, .25 * neon), 16));
    c.drawCircle(const Offset(300, 250), 36, D.stroke(Color.fromRGBO(255, 150, 230, neon), 4));
    c.drawCircle(const Offset(300, 372), 22, D.stroke(Color.fromRGBO(60, 220, 255, .25 * neon), 12));
    c.drawCircle(const Offset(300, 372), 22, D.stroke(Color.fromRGBO(140, 240, 255, neon), 3));
    D.rays(c, const Offset(180, 380), 500, const Color(0x0DFFFFFF), count: 14, t: _t * .15);

    // counter
    D.rrect(c, const Rect.fromLTWH(-10, 556, 380, 100), 0, const Color(0xFF6B3A1E),
        gradient: const LinearGradient(colors: [Color(0xFFB9743F), Color(0xFF5A2E16)], begin: Alignment.topCenter, end: Alignment.bottomCenter));
    D.rrect(c, const Rect.fromLTWH(-10, 552, 380, 10), 0, const Color(0xFFE2A56A));
    for (var i = 0; i < 6; i++) {
      c.drawLine(Offset(i * 70.0 + 10, 575), Offset(i * 70.0 + 50, 575), D.stroke(const Color(0x33FFFFFF), 2));
    }

    _renderDispenser(c);
    _renderGlass(c);
    _renderStream(c);
    _renderHud(c);
    _renderCustomer(c);

    if (host.time < 2.2 && _round == 0 && _vol == 0) {
      D.hand(c, const Offset(250, 470), _t);
      D.text(c, host.tr('hold', 'HOLD'), const Offset(262, 530), size: 22, stroke: Pal.ink);
    }
  }

  void _renderDispenser(Canvas c) {
    // body
    D.rrect(c, const Rect.fromLTWH(110, 36, 140, 104), 18, const Color(0xFFB0B8C8),
        border: Pal.ink, borderWidth: 3,
        gradient: const LinearGradient(colors: [Color(0xFFE8EEF6), Color(0xFF8C95A8)]));
    D.rrect(c, const Rect.fromLTWH(126, 52, 108, 50), 10, _drinks[_round.clamp(0, 2)], border: Pal.ink, borderWidth: 2.5);
    // label bubbles
    for (var i = 0; i < 5; i++) {
      final y = 96 - ((_t * 20 + i * 11) % 44);
      c.drawCircle(Offset(140 + i * 20.0, y), 3 + (i % 2) * 1.5, D.fill(const Color(0x88FFFFFF)));
    }
    D.rrect(c, const Rect.fromLTWH(132, 56, 30, 10), 5, const Color(0x55FFFFFF));
    // nozzle
    D.rrect(c, const Rect.fromLTWH(164, 138, 32, 22), 6, const Color(0xFF6E7890), border: Pal.ink, borderWidth: 3);
    D.rrect(c, const Rect.fromLTWH(170, 156, 20, 18), 5, const Color(0xFF4A5268), border: Pal.ink, borderWidth: 3);
    // lever
    c.save();
    c.translate(236, 118);
    c.rotate(-.5 + _press * .9);
    D.rrect(c, const Rect.fromLTWH(-5, -4, 58, 12), 6, Pal.red, border: Pal.ink, borderWidth: 2.5);
    c.drawCircle(const Offset(54, 2), 9, D.fill(Pal.red));
    c.drawCircle(const Offset(54, 2), 9, D.stroke(Pal.ink, 2.5));
    c.restore();
    c.drawCircle(const Offset(236, 120), 6, D.fill(Pal.ink));
  }

  Path _glassPath(double upTo, double wave) {
    final g = _glass;
    final path = Path();
    const n = 22;
    for (var i = 0; i <= n; i++) {
      final u = upTo * i / n;
      final p = Offset(_glassX - g.hw(u), _bottomY - u * g.h);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    // top edge (wavy liquid surface when wave > 0)
    final topY = _bottomY - upTo * g.h;
    final hw = g.hw(upTo);
    for (var i = 1; i < 12; i++) {
      final k = i / 12;
      final x = _glassX - hw + 2 * hw * k;
      path.lineTo(x, topY + sin(k * pi * 3 + _t * 14) * wave);
    }
    for (var i = n; i >= 0; i--) {
      final u = upTo * i / n;
      path.lineTo(_glassX + g.hw(u), _bottomY - u * g.h);
    }
    return path..close();
  }

  void _renderGlass(Canvas c) {
    final g = _glass;
    final drink = _drinks[_round.clamp(0, 2)];
    final hi = _drinkHi[_round.clamp(0, 2)];
    D.shadow(c, Offset(_glassX, _bottomY + 4), g.hw(0) * 2.6, 14, .35);
    final outer = _glassPath(1, 0);
    c.drawPath(outer, D.fill(const Color(0x33DDF4FF)));
    // liquid
    if (_level > .002) {
      c.save();
      c.clipPath(outer);
      final wave = 2 + _wobble * 3;
      final liquid = _glassPath(min(1, _level), wave);
      c.drawPath(
          liquid,
          Paint()
            ..shader = LinearGradient(colors: [hi, drink], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                .createShader(Rect.fromLTWH(0, _surfaceY, 360, _level * g.h + 1)));
      // bubbles
      for (final b in _bubbles) {
        final u = ((_bottomY - b.y) / g.h).clamp(0.0, 1.0);
        c.drawCircle(Offset(_glassX + b.x * g.hw(u) * .8, b.y), b.r, D.stroke(const Color(0xAAFFFFFF), 1.3));
      }
      // foam
      if (_foam > .5) {
        final fy = _surfaceY;
        final hw = g.hw(min(1, _level));
        for (var i = 0; i < 9; i++) {
          final k = i / 8;
          c.drawCircle(Offset(_glassX - hw + 2 * hw * k, fy - _foam * .45 + sin(_t * 5 + i) * 1.5),
              _foam * .55 + 3, D.fill(const Color(0xDDFFF6E0)));
        }
        // the true liquid line stays visible through the foam
        c.drawLine(Offset(_glassX - hw, fy), Offset(_glassX + hw, fy), D.stroke(Color.lerp(drink, Pal.white, .3)!, 2));
      }
      c.restore();
    }
    // glass outline + shine
    c.drawPath(outer, D.stroke(Pal.ink, 4));
    c.drawPath(outer, D.stroke(const Color(0xCCFFFFFF), 1.5));
    final shine = Path();
    for (var i = 0; i <= 10; i++) {
      final u = .12 + .75 * i / 10;
      final p = Offset(_glassX - g.hw(u) * .72, _bottomY - u * g.h);
      i == 0 ? shine.moveTo(p.dx, p.dy) : shine.lineTo(p.dx, p.dy);
    }
    c.drawPath(shine, D.stroke(const Color(0x88FFFFFF), 5));
    // thick base
    D.rrect(c, Rect.fromCenter(center: Offset(_glassX, _bottomY - 3), width: g.hw(0) * 2 + 8, height: 10), 5,
        const Color(0x66E0F4FF), border: Pal.ink, borderWidth: 2.5);

    // target line
    final ly = _bottomY - _line * g.h;
    final lhw = g.hw(_line) + 18;
    final pulse = M.wave(_t, 2.5);
    final lineCol = _state == 3 ? (_reactGrade <= 1 ? Pal.lime : Pal.red) : Color.lerp(Pal.yellow, Pal.white, pulse * .5)!;
    final dash = D.stroke(Pal.ink, 6);
    final dashC = D.stroke(lineCol, 3.5);
    for (var x = _glassX - lhw; x < _glassX + lhw; x += 14) {
      c.drawLine(Offset(x, ly), Offset(min(x + 8, _glassX + lhw), ly), dash);
      c.drawLine(Offset(x, ly), Offset(min(x + 8, _glassX + lhw), ly), dashC);
    }
    for (final s in [-1.0, 1.0]) {
      final tip = Offset(_glassX + s * (lhw + 2 + pulse * 5), ly);
      final tri = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + s * 18, tip.dy - 11)
        ..lineTo(tip.dx + s * 18, tip.dy + 11)
        ..close();
      c.drawPath(tri, D.fill(lineCol));
      c.drawPath(tri, D.stroke(Pal.ink, 2.5));
    }
    // result: error bracket
    if (_state == 3 && !_overflowed) {
      final sy = _surfaceY;
      c.drawLine(Offset(_glassX + lhw + 26, ly), Offset(_glassX + lhw + 26, sy), D.stroke(Pal.white, 3));
      final err = (_level - _line).abs() * g.h;
      D.text(c, err < .5 ? '0' : '${err.toStringAsFixed(0)}px', Offset(_glassX + lhw + 30, (ly + sy) / 2),
          size: 16, stroke: Pal.ink, anchor: Alignment.centerLeft);
    }
  }

  void _renderStream(Canvas c) {
    if (_streamHead <= _streamTail + 1) return;
    final drink = _drinks[_round.clamp(0, 2)];
    final w = 9 + sin(_t * 40) * 1.2;
    final r = Rect.fromLTRB(180 - w / 2, _streamTail, 180 + w / 2, _streamHead);
    D.rrect(c, r, w / 2, drink);
    D.rrect(c, Rect.fromLTRB(r.left + 2, r.top, r.left + 4, r.bottom), 1, const Color(0x66FFFFFF));
    if (_streamHead >= _surfaceY - 2 && _state <= 2) {
      c.drawOval(Rect.fromCenter(center: Offset(180, _surfaceY), width: 30, height: 8), D.fill(const Color(0xAAFFFFFF)));
    }
  }

  void _renderHud(Canvas c) {
    // 3 round badges
    for (var i = 0; i < 3; i++) {
      final o = Offset(40.0, 190 + i * 46.0);
      final done = i < _grades.length;
      final cur = i == _round && _state < 4;
      final col = !done ? (cur ? Pal.white : const Color(0x55FFFFFF)) : [Pal.yellow, Pal.lime, Pal.sky, Pal.red][_grades[i]];
      final s = cur ? 1 + .08 * sin(_t * 8) : 1.0;
      c.drawCircle(o + const Offset(0, 3), 17 * s, D.fill(const Color(0x55000000)));
      c.drawCircle(o, 17 * s, D.fill(col));
      c.drawCircle(o, 17 * s, D.stroke(Pal.ink, 3));
      if (done) {
        final g = _grades[i];
        if (g == 0) {
          D.star(c, o, 11, Pal.white, border: Pal.ink);
        } else if (g == 3) {
          D.line(c, o + const Offset(-7, -7), o + const Offset(7, 7), Pal.ink, 4);
          D.line(c, o + const Offset(7, -7), o + const Offset(-7, 7), Pal.ink, 4);
        } else {
          D.line(c, o + const Offset(-7, 0), o + const Offset(-2, 6), Pal.ink, 4);
          D.line(c, o + const Offset(-2, 6), o + const Offset(8, -6), Pal.ink, 4);
        }
      } else {
        D.text(c, '${i + 1}', o, size: 16, color: Pal.ink);
      }
    }
  }

  void _renderCustomer(Canvas c) {
    // a thirsty customer peeking from the right edge
    final face = _reactT > 0
        ? (_reactGrade == 0 ? Face.love : (_reactGrade <= 2 ? Face.happy : Face.angry))
        : (_inflow ? Face.shocked : Face.neutral);
    final bob = sin(_t * 3) * 3 + (_reactT > 0 && _reactGrade <= 1 ? -sin(_reactT * 20).abs() * 10 : 0);
    final o = Offset(318, 500 + bob);
    D.blob(c, o, 34, Pal.sky, face: face, look: const Offset(-1, 0));
    // hands on the counter
    c.drawCircle(const Offset(292, 552), 9, D.fill(Pal.sky));
    c.drawCircle(const Offset(292, 552), 9, D.stroke(Pal.ink, 2.5));
    if (_reactT > 0 && _reactGrade == 3) {
      D.bubble(c, const Rect.fromLTWH(270, 420, 60, 34), tail: const Offset(305, 466));
      D.text(c, '!?', const Offset(300, 437), size: 20, color: Pal.red);
    }
  }
}

class _Bubble {
  _Bubble(this.x, this.y, this.r, this.v);
  double x, y;
  final double r, v;
}

class _Glass {
  _Glass(this.h, this.hw, this.foamMax) {
    var acc = 0.0;
    _cum.add(0);
    for (var i = 1; i <= _n; i++) {
      final u = (i - .5) / _n;
      final w = hw(u);
      acc += w * w;
      _cum.add(acc);
    }
    for (var i = 0; i <= _n; i++) {
      _cum[i] /= acc;
    }
  }

  factory _Glass.make(int round) {
    switch (round) {
      case 0: // tall highball
        return _Glass(290, (u) => 34 + 10 * u, 16);
      case 1: // wide bowl — fast at the bottom, slow at the top
        return _Glass(190, (u) => 26 + 78 * sqrt(u), 12);
      default: // curvy hourglass — speeds up in the waist!
        return _Glass(270, (u) => 56 - 32 * sin(pi * u), 20);
    }
  }

  static const _n = 200;
  final double h;
  final double Function(double u) hw;
  final double foamMax;
  final List<double> _cum = [];

  double get volTop => 1.0;

  double levelFor(double vol) {
    if (vol <= 0) return 0;
    if (vol >= 1) return 1;
    var lo = 0, hi = _n;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_cum[mid] < vol) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final k = (vol - _cum[lo]) / max(1e-9, _cum[hi] - _cum[lo]);
    return (lo + k) / _n;
  }
}
