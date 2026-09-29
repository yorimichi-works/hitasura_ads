import '../engine/engine.dart';

/// No.049 Hot Potato Bomb — pass the sizzling bomb with the right arrow.
class G049 extends MiniGame {
  static const _pos = [Offset(180, 478), Offset(66, 350), Offset(180, 232), Offset(294, 350)];
  // direction (from your seat) of each rival: left = Red, up = Green, right = Yellow
  static const _dirs = [Offset(-1, 0), Offset(0, -1), Offset(1, 0)];
  static const _btnX = [70.0, 180.0, 290.0];
  static const _btnY = 586.0;

  double _t = 0;
  double _fuse = 10; // seconds until boom
  double _fuseMax = 10;
  int _holder = 0; // -1 while flying
  int _from = 0, _to = 0;
  double _fly = 1; // 0..1 flight progress
  double _holdT = 0;
  double _cpuDelay = 1;
  final _prompt = <int>[]; // required rival indices (0..2 => cast 1..3)
  double _fumble = 0;
  final _squash = List<double>.filled(4, 1);
  bool _boom = false;
  double _boomT = 0;
  int _victim = -1;
  double _tickT = 0;
  final _holdTimes = <double>[];
  final _press = List<double>.filled(3, 0);
  bool _hintDone = false;

  @override
  void init() {
    _fuseMax = rand(8.6, 10.8);
    _fuse = _fuseMax;
    _newPrompt();
  }

  double get _frac => (_fuse / _fuseMax).clamp(0.0, 1.0);

  void _newPrompt() {
    _prompt.clear();
    _prompt.add(randInt(3));
    if (_frac < .45) _prompt.add(randInt(3)); // late game: double arrows
  }

  void _pass(int from, int to) {
    _from = from;
    _to = to;
    _holder = -1;
    _fly = 0;
    _squash[from] = .7;
    host.sfx(Sfx.throwIt, rate: 1 + (1 - _frac) * .4);
  }

  void _press3(int b) {
    if (_boom || host.finished) return;
    _press[b] = 1;
    if (_holder != 0 || _fumble > 0) {
      host.sfx(Sfx.tap, volume: .4);
      return;
    }
    if (_prompt.first == b) {
      _prompt.removeAt(0);
      if (_prompt.isEmpty) {
        _hintDone = true;
        _holdTimes.add(_holdT);
        final quick = _holdT < .45;
        host.fx.pop(quick ? host.tr('great', 'GREAT!') : host.tr('good', 'GOOD'), _pos[0] + const Offset(0, -80),
            color: quick ? Pal.yellow : Pal.white, size: 24);
        host.sfx(Sfx.correct, volume: .6, rate: quick ? 1.2 : 1);
        _pass(0, b + 1);
      } else {
        host.sfx(Sfx.select, rate: 1.3);
        host.fx.ring(const Offset(180, 300), Pal.yellow, size: 50);
      }
    } else {
      _fumble = .4;
      host.sfx(Sfx.oops);
      host.sfx(Sfx.boing, volume: .6);
      host.shake(5);
      host.fx.pop(host.tr('oops', 'OOPS!'), _pos[0] + const Offset(0, -80), color: Pal.red, size: 26);
    }
  }

  @override
  void onDown(Offset p) {
    for (var b = 0; b < 3; b++) {
      if ((p - Offset(_btnX[b], _btnY)).distance < 52) {
        _press3(b);
        return;
      }
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    switch (key) {
      case 'left':
        _press3(0);
      case 'up':
        _press3(1);
      case 'right':
        _press3(2);
    }
  }

  Offset get _bombPos {
    if (_holder >= 0) {
      return _pos[_holder] + Offset(0, -86 + sin(_t * 30) * (_holder == 0 && _fumble > 0 ? 6 : 1.5));
    }
    final a = _pos[_from] + const Offset(0, -86);
    final b = _pos[_to] + const Offset(0, -86);
    final k = M.easeInOut(_fly);
    return Offset.lerp(a, b, k)! + Offset(0, -sin(_fly * pi) * 70);
  }

  @override
  void update(double dt) {
    _t += dt;
    for (var i = 0; i < 4; i++) {
      _squash[i] = M.approach(_squash[i], 1, 12, dt);
    }
    for (var b = 0; b < 3; b++) {
      _press[b] = M.approach(_press[b], 0, 10, dt);
    }
    if (_boom) {
      final before = (_boomT / .15).floor();
      _boomT += dt;
      if ((_boomT / .15).floor() != before) {
        host.fx.smoke(_pos[_victim] + const Offset(0, -64), count: 1, color: const Color(0x99555555), size: 14);
      }
      return;
    }
    _fuse -= dt * (1 + (host.speed - 1) * .5);
    _fumble = max(0, _fumble - dt);
    // ticking accelerates
    _tickT -= dt;
    if (_tickT <= 0) {
      _tickT = .12 + .5 * _frac;
      host.sfx(_frac < .3 ? Sfx.beep : Sfx.tick, volume: .5, rate: 1 + (1 - _frac) * .6);
    }
    // fuse sparks
    if (chance(.6)) {
      host.fx.add(Particle(
        pos: _sparkPos,
        vel: Offset(rand(-90, 90), rand(-140, -30)),
        life: rand(.15, .35),
        color: pick(const [Pal.yellow, Pal.orange, Pal.white]),
        size: rand(3, 6),
        shape: PartShape.spark,
        gravity: 300,
      ));
    }
    if (_holder == -1) {
      _fly += dt / .3;
      if (_fly >= 1) {
        _fly = 1;
        _holder = _to;
        _holdT = 0;
        _squash[_to] = .75;
        host.sfx(Sfx.pop, rate: .9 + _to * .1);
        if (_to == 0) {
          _newPrompt();
          host.sfx(Sfx.notify, volume: .5);
        } else {
          _cpuDelay = rand(.5, 1.0) * (.55 + .45 * _frac) / host.speed;
        }
      }
    } else {
      _holdT += dt;
      if (_holder != 0 && _holdT >= _cpuDelay) {
        final to = chance(.55) ? 0 : ([1, 2, 3]..remove(_holder))[randInt(2)];
        _pass(_holder, to);
      }
    }
    if (_fuse <= 0) _explode();
  }

  void _explode() {
    _boom = true;
    _victim = _holder >= 0 ? _holder : _to;
    _holder = _victim;
    final at = _pos[_victim] + const Offset(0, -60);
    host.sfx(Sfx.explode);
    host.flash(Pal.white, .3);
    host.shake(16, .5);
    host.hitStop(.1);
    host.fx.burst(at, Pal.orange, count: 40, speed: 420, size: 10, colors: const [Pal.orange, Pal.yellow, Pal.red, Pal.white]);
    host.fx.smoke(at, count: 16, color: const Color(0xCC333333), size: 30);
    host.fx.ring(at, Pal.yellow, size: 140, life: .5);
    if (_victim == 0) {
      host.sfx(Sfx.aww, volume: .7);
      host.lose();
    } else {
      host.sfx(Sfx.cheer);
      host.fx.confetti(count: 70);
      final avg = _holdTimes.isEmpty ? 1.0 : _holdTimes.reduce((a, b) => a + b) / _holdTimes.length;
      host.win(stars: avg < .55 ? 3 : (avg < .9 ? 2 : 1));
    }
  }

  @override
  void onTimeUp() {
    if (!_boom) _explode();
  }

  Offset get _sparkPos {
    final b = _bombPos;
    final f = _frac;
    // fuse curls from the cap up to the right; spark sits at the burning end
    return b + Offset(10 + 16 * f, -22 - 20 * f + sin(f * 6) * 4);
  }

  @override
  void render(Canvas c) {
    // party room
    D.gradientBg(c, const [Color(0xFF2D1B69), Color(0xFF7B2F9E), Color(0xFFE0569B)]);
    D.rays(c, const Offset(180, 350), 500, Color.fromRGBO(255, 255, 255, .05 + (1 - _frac) * .06), count: 20, t: _t * .5);
    // bunting
    for (var row = 0; row < 1; row++) {
      final y0 = 44.0 + row * 28;
      final path = Path()..moveTo(-10, y0);
      path.quadraticBezierTo(180, y0 + 30, 370, y0);
      c.drawPath(path, D.stroke(const Color(0x88FFFFFF), 2));
      for (var i = 0; i < 12; i++) {
        final x = -4 + i * 32.0 + row * 16;
        final tt = x / 360;
        final y = y0 + 4 * tt * (1 - tt) * 30;
        final f = Path()
          ..moveTo(x - 10, y)
          ..lineTo(x + 10, y)
          ..lineTo(x, y + 18 + sin(_t * 4 + i) * 2)
          ..close();
        c.drawPath(f, D.fill(Pal.candy[(i + row * 3) % 8]));
      }
    }
    // rug
    c.drawOval(Rect.fromCenter(center: const Offset(180, 380), width: 330, height: 230), D.fill(const Color(0x33000000)));
    c.drawOval(Rect.fromCenter(center: const Offset(180, 372), width: 316, height: 216), D.fill(const Color(0xFFFFB347)));
    c.drawOval(Rect.fromCenter(center: const Offset(180, 372), width: 270, height: 180), D.fill(const Color(0xFFFF7A59)));
    c.drawOval(Rect.fromCenter(center: const Offset(180, 372), width: 210, height: 136), D.fill(const Color(0xFFFFD166)));
    c.drawOval(Rect.fromCenter(center: const Offset(180, 372), width: 150, height: 92), D.fill(const Color(0xFFFF7A59)));
    // danger glow
    if (_frac < .35 && !_boom) {
      final a = (.35 - _frac) / .35 * (.5 + .5 * sin(_t * 20));
      c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), D.fill(Color.fromRGBO(255, 0, 40, a * .18)));
    }

    // characters (top to bottom)
    for (final i in [2, 1, 3, 0]) {
      _renderChar(c, i);
    }
    if (!(_boom && _boomT > .05)) _renderBomb(c);
    _renderPrompt(c);
    _renderButtons(c);
    // fuse meter
    final f = _frac;
    D.rrect(c, const Rect.fromLTWH(60, 100, 240, 16), 8, const Color(0x66000000));
    D.bar(c, const Rect.fromLTWH(62, 102, 236, 12), f, Color.lerp(Pal.red, Pal.yellow, f)!, back: const Color(0x00000000));
    D.flame(c, Offset(62 + 236 * f, 110), 16, _t);

    if (_boom) {
      final k = M.easeOutBack(M.clamp01(_boomT / .35));
      final txt = _victim == 0 ? host.tr('ko', 'K.O.') : host.tr('safe', 'SAFE!');
      D.title(c, txt, const Offset(180, 160), size: 56 * k + 1, color: _victim == 0 ? Pal.red : Pal.yellow, rotate: -.08);
      if (_boomT < .25) {
        D.title(c, 'BOOM', _pos[_victim] + const Offset(0, -120), size: 50, color: Pal.orange, scale: 1 + _boomT * 2);
      }
    }
  }

  void _renderChar(Canvas c, int i) {
    final p = _pos[i];
    final holding = _holder == i && !_boom;
    final victim = _boom && _victim == i;
    final bp = _bombPos;
    final look = Offset(((bp.dx - p.dx) / 90).clamp(-1.0, 1.0), ((bp.dy - p.dy + 50) / 90).clamp(-1.0, 1.0));
    Face face;
    if (victim) {
      face = Face.dead;
    } else if (_boom) {
      face = _victim == 0 && i != 0 ? Face.smug : Face.happy;
    } else if (holding) {
      face = i == 0 && _fumble > 0 ? Face.cry : Face.shocked;
    } else {
      face = i == 0 ? Face.neutral : _Cast.mood[i];
      if (_holder == -1 && _to == i) face = Face.shocked;
    }
    final shake = holding ? sin(_t * 50) * (1.5 + (1 - _frac) * 3) : 0.0;
    final hop = _boom && !victim ? -sin(_boomT * 12 + i).abs() * 16 : 0.0;
    D.shadow(c, p + const Offset(0, 3), 64, 14, .3);
    final r = i == 0 ? 32.0 : 29.0;
    _Cast.draw(c, i, p + Offset(shake, hop), r, face: face, squash: _squash[i], look: look, soot: victim);
    if (victim) {
      // afro of soot
      for (var k = 0; k < 7; k++) {
        final a = -pi + k * pi / 6;
        c.drawCircle(p + Offset(cos(a) * r * .9, -r * 1.9 + sin(a) * r * .5), r * .42, D.fill(const Color(0xFF221D28)));
      }
    }
    // arms raised when holding
    if (holding) {
      for (final s in [-1.0, 1.0]) {
        D.line(c, p + Offset(s * r * .85 + shake, -r * 1.1), p + Offset(s * r * .6 + shake, -r * 2.3), Pal.ink, 7);
        D.line(c, p + Offset(s * r * .85 + shake, -r * 1.1), p + Offset(s * r * .6 + shake, -r * 2.3), _Cast.col[i], 4);
      }
      // sweat
      D.circle(c, p + Offset(r + 4, -r * 1.6 + (_t * 50) % 14), 4, const Color(0xDD7FD3FF));
    }
    // name tag
    final label = i == 0 ? host.tr('you', 'YOU') : '${host.tr('cpu', 'CPU')}$i';
    final tagY = i == 0 ? p.dy + 16 : p.dy + 14;
    D.rrect(c, Rect.fromCenter(center: Offset(p.dx, tagY), width: 54, height: 18), 9, _Cast.dark[i], border: Pal.ink, borderWidth: 2);
    D.text(c, label, Offset(p.dx, tagY), size: 12, color: Pal.white);
  }

  void _renderBomb(Canvas c) {
    final b = _bombPos;
    final pulse = 1 + (1 - _frac) * .12 * (.5 + .5 * sin(_t * (8 + (1 - _frac) * 30)));
    const r = 22.0;
    c.save();
    c.translate(b.dx, b.dy);
    c.scale(pulse);
    c.rotate(_holder == -1 ? _fly * pi * 2 : sin(_t * 9) * .1);
    // fuse
    final f = _frac;
    final fuse = Path()
      ..moveTo(6, -r + 2)
      ..quadraticBezierTo(10 + 10 * f, -r - 16 * f, 10 + 16 * f, -r - 20 * f + sin(f * 6) * 4);
    c.drawPath(fuse, D.stroke(const Color(0xFFD9B98A), 4));
    c.drawCircle(Offset.zero, r, D.fill(const Color(0xFF26203A)));
    final red = _frac < .3 && sin(_t * 26) > 0;
    if (red) c.drawCircle(Offset.zero, r, D.fill(const Color(0x99FF2040)));
    c.drawCircle(Offset.zero, r, D.stroke(Pal.ink, 3));
    c.drawCircle(const Offset(-8, -8), 6, D.fill(const Color(0x88FFFFFF)));
    D.rrect(c, Rect.fromCenter(center: const Offset(4, -r + 1), width: 14, height: 9), 3, const Color(0xFF6B6480),
        border: Pal.ink, borderWidth: 2);
    c.restore();
    D.circle(c, _sparkPos, 5 + sin(_t * 40) * 2, Pal.yellow);
    D.circle(c, _sparkPos, 2.5, Pal.white);
  }

  void _renderPrompt(Canvas c) {
    if (_holder != 0 || _boom || _prompt.isEmpty) return;
    const o = Offset(180, 300);
    final k = M.easeOutBack(M.clamp01(_holdT / .15));
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(k);
    D.circle(c, Offset.zero, 44, _fumble > 0 ? Pal.red : Pal.white, border: Pal.ink, borderWidth: 4);
    final d = _dirs[_prompt.first];
    D.arrow(c, Offset.zero, d, 64, _Cast.col[_prompt.first + 1], width: 18);
    if (_prompt.length > 1) {
      D.circle(c, const Offset(42, 40), 18, Pal.yellow, border: Pal.ink, borderWidth: 3);
      D.arrow(c, const Offset(42, 40), _dirs[_prompt[1]], 22, Pal.ink, width: 6);
    }
    c.restore();
  }

  void _renderButtons(Canvas c) {
    for (var b = 0; b < 3; b++) {
      final pr = _press[b];
      final center = Offset(_btnX[b], _btnY + pr * 4);
      final col = _Cast.col[b + 1];
      D.rrect(c, Rect.fromCenter(center: Offset(_btnX[b], _btnY + 7), width: 92, height: 70), 20, Color.lerp(col, Pal.ink, .5)!);
      D.rrect(c, Rect.fromCenter(center: center, width: 92, height: 70), 20, col, border: Pal.ink, borderWidth: 3.5);
      D.rrect(c, Rect.fromCenter(center: center + const Offset(0, -20), width: 74, height: 16), 8, const Color(0x44FFFFFF));
      D.arrow(c, center, _dirs[b], 44, Pal.white, width: 13);
    }
    if (!_hintDone && _holder == 0 && _prompt.isNotEmpty && _t < 4) {
      D.hand(c, Offset(_btnX[_prompt.first], _btnY + 8), _t, size: 40);
    }
  }
}

/// Party cast shared by No.046–053: you (blue hero) vs Red, Green, Yellow.
abstract final class _Cast {
  static const col = [Color(0xFF3D8BFF), Color(0xFFFF4B5C), Color(0xFF37D67A), Color(0xFFFFCF33)];
  static const dark = [Color(0xFF1F4FB8), Color(0xFFB8243A), Color(0xFF1C8F4E), Color(0xFFC79A10)];
  static const mood = [Face.happy, Face.angry, Face.smug, Face.happy];

  /// Draws party member [i] standing with feet at [feet]. [run] animates feet.
  static void draw(Canvas c, int i, Offset feet, double r,
      {Face? face, double squash = 1, double tilt = 0, double? run, Offset look = Offset.zero, bool soot = false}) {
    c.save();
    c.translate(feet.dx, feet.dy);
    if (tilt != 0) c.rotate(tilt);
    if (squash != 1) c.scale(1 / sqrt(squash), squash);
    final body = soot ? const Color(0xFF3A3340) : col[i];
    final dk = soot ? const Color(0xFF221D28) : dark[i];
    // feet
    final ph = run ?? 0;
    for (final s in [-1.0, 1.0]) {
      final sw = run == null ? 0.0 : sin(ph * pi + (s > 0 ? 0 : pi));
      final lift = run == null ? 0.0 : max(0.0, sw) * r * .35;
      c.drawOval(Rect.fromCenter(center: Offset(s * r * .42 + sw * r * .38, -r * .08 - lift), width: r * .62, height: r * .36),
          D.fill(dk));
    }
    // accessories behind the body
    if (i == 1) {
      for (final s in [-1.0, 1.0]) {
        final p = Path()
          ..moveTo(s * r * .72, -r * 1.45)
          ..lineTo(s * r * .78, -r * 2.2)
          ..lineTo(s * r * .3, -r * 1.7)
          ..close();
        c.drawPath(p, D.fill(soot ? dk : const Color(0xFFFFF4DC)));
        c.drawPath(p, D.stroke(Pal.ink, max(1.5, r * .08)));
      }
    }
    D.blob(c, Offset(0, -r * .95), r, body, face: face ?? mood[i], look: look);
    final sw = max(1.5, r * .08);
    switch (i) {
      case 0: // hero cowlick + headband
        final p = Path()
          ..moveTo(-r * .2, -r * 1.82)
          ..quadraticBezierTo(-r * .15, -r * 2.5, r * .45, -r * 2.35)
          ..quadraticBezierTo(r * .05, -r * 2.2, r * .2, -r * 1.84)
          ..close();
        c.drawPath(p, D.fill(body));
        c.drawPath(p, D.stroke(Pal.ink, sw));
        c.drawRect(Rect.fromLTWH(-r * .92, -r * 1.52, r * 1.84, r * .2), D.fill(soot ? dk : Pal.white));
        final tail = Path()
          ..moveTo(r * .85, -r * 1.45)
          ..lineTo(r * 1.35, -r * 1.7 + sin(ph * 2) * r * .1)
          ..lineTo(r * 1.3, -r * 1.3)
          ..close();
        c.drawPath(tail, D.fill(soot ? dk : Pal.white));
        c.drawPath(tail, D.stroke(Pal.ink, sw * .7));
      case 2: // sprout
        c.drawLine(Offset(0, -r * 1.85), Offset(0, -r * 2.3), D.stroke(Pal.ink, sw));
        for (final s in [-1.0, 1.0]) {
          c.save();
          c.translate(s * r * .22, -r * 2.3);
          c.rotate(s * .6);
          final leaf = Rect.fromCenter(center: Offset.zero, width: r * .5, height: r * .26);
          c.drawOval(leaf, D.fill(soot ? dk : const Color(0xFF9BE22D)));
          c.drawOval(leaf, D.stroke(Pal.ink, sw * .8));
          c.restore();
        }
      case 3: // bow
        final o = Offset(r * .45, -r * 1.72);
        for (final s in [-1.0, 1.0]) {
          final p = Path()
            ..moveTo(o.dx, o.dy)
            ..lineTo(o.dx + s * r * .42, o.dy - r * .24)
            ..lineTo(o.dx + s * r * .42, o.dy + r * .24)
            ..close();
          c.drawPath(p, D.fill(soot ? dk : Pal.pink));
          c.drawPath(p, D.stroke(Pal.ink, sw * .8));
        }
        c.drawCircle(o, r * .12, D.fill(soot ? dk : Pal.pink));
        c.drawCircle(o, r * .12, D.stroke(Pal.ink, sw * .8));
    }
    c.restore();
  }
}
