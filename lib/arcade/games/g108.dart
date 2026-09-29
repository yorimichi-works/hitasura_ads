import '../engine/engine.dart';

/// No.108 Mini Golf 3D — pull back from the ball to aim, release to putt.
/// Time the windmill, ride the slope, let the cup's funnel do the rest.
/// Sink it in 3 strokes or fewer.
class G108 extends MiniGame {
  static const _hw = 2.6; // half width of the fairway
  static const _len = 15.0;
  static const _ballR = .18;
  static const _hole = V3(1.2, 0, 13.3);
  static const _holeR = .3;
  static const _millZ0 = 7.0, _millZ1 = 8.2, _millHalf = 1.5, _gap = .55;
  static const _maxStrokes = 3;

  final scene = Scene3();
  late final Mesh _course, _lawn, _rails, _house, _roof, _blade, _hub, _ball, _pole, _trees;

  double _bx = 0, _bz = 1.2, _vx = 0, _vz = 0;
  double _by = 0;
  bool _aiming = false;
  Offset _aimFrom = Offset.zero, _aimNow = Offset.zero;
  int _strokes = 0;
  bool _moving = false;
  bool _sunk = false;
  double _sinkT = 0;
  double _t = 0;
  double _mill = 0;
  double _bonkCd = 0;
  bool _lost = false;
  double _celebrate = 0;
  double _roll = 0;

  static double _h(double x, double z) {
    var h = 0.0;
    // side slope before the windmill: high on the left, drains right
    if (z > 2.6 && z < 5.8) {
      final s = sin((z - 2.6) / 3.2 * pi);
      h += .32 * s * (1 - (x + _hw) / (2 * _hw));
    }
    // funnel around the cup
    final d = sqrt((x - _hole.x) * (x - _hole.x) + (z - _hole.z) * (z - _hole.z));
    if (d < 1.5) h -= .16 * (1 - d / 1.5) * (1 - d / 1.5);
    return h;
  }

  @override
  void init() {
    scene.ambient = .58;
    scene.diffuse = .55;
    scene.light = const V3(-.5, 1, -.4).normalized;
    _course = _buildCourse();
    _lawn = Mesh.grid(26, 34, 8, 10, (i, j) => (i + j).isEven ? const Color(0xFF5BAF6A) : const Color(0xFF55A864));
    const wood = Color(0xFFB9784F), woodTop = Color(0xFFE0A36C);
    final parts = <(Mesh, V3)>[];
    Mesh seg(double w, double d) => Mesh.box(w, .35, d, wood, colors: const [woodTop, wood, wood, wood, wood, wood]);
    for (var i = 0; i < 10; i++) {
      final z = -.4 + i * 1.6 + .8;
      parts.add((seg(.3, 1.6), V3(-_hw - .15, .1, z)));
      parts.add((seg(.3, 1.6), V3(_hw + .15, .1, z)));
    }
    for (var i = 0; i < 4; i++) {
      final x = -_hw - .3 + i * (2 * _hw + .6) / 4 + (2 * _hw + .6) / 8;
      parts.add((seg((2 * _hw + .6) / 4, .3), V3(x, .1, -.55)));
      parts.add((seg((2 * _hw + .6) / 4, .3), V3(x, .1, _len + .15)));
    }
    _rails = Mesh.merge(parts);
    const wall = Color(0xFFFFF1DE), wallSide = Color(0xFFF0D6B8), door = Color(0xFF6A3A2A);
    final hd = _millZ1 - _millZ0;
    _house = Mesh.merge([
      (Mesh.box(_millHalf - _gap, 2.6, hd, wall, colors: const [wall, wall, wall, wall, wallSide, wallSide]),
          V3(-(_millHalf + _gap) / 2, 1.3, (_millZ0 + _millZ1) / 2)),
      (Mesh.box(_millHalf - _gap, 2.6, hd, wall, colors: const [wall, wall, wall, wall, wallSide, wallSide]),
          V3((_millHalf + _gap) / 2, 1.3, (_millZ0 + _millZ1) / 2)),
      (Mesh.box(_gap * 2, 1.8, hd, wall), V3(0, 1.7, (_millZ0 + _millZ1) / 2)),
      (Mesh.box(_gap * 2 + .1, .1, hd + .02, door), V3(0, .8, (_millZ0 + _millZ1) / 2)),
    ]);
    _roof = Mesh.cone(2.2, 1.0, const Color(0xFFE8506A), seg: 4);
    _blade = Mesh.merge([
      (Mesh.box(.12, 2.0, .06, const Color(0xFF7A4A30)), const V3(0, 1.05, 0)),
      (Mesh.box(.55, 1.5, .04, const Color(0xFFFFFFFF)), const V3(.3, 1.25, 0)),
    ]);
    _hub = Mesh.cylinder(.22, .2, const Color(0xFFFFC53D), seg: 8);
    _ball = Mesh.sphere(_ballR, Pal.white, lat: 4, lon: 7);
    _pole = Mesh.cylinder(.04, 1.8, Pal.white, seg: 5);
    _trees = Mesh.merge([
      for (final (x, z) in const [(-4.6, 2.0), (4.8, 4.5), (-4.9, 9.5), (4.6, 12.0), (-4.2, 15.5), (5.4, 16.5)])
        (Models.roundTree(leaf: const Color(0xFF3E9E5A)), V3(x, 0, z)),
    ]);
  }

  Mesh _buildCourse() {
    const nx = 10, nz = 30;
    final v = <V3>[];
    for (var j = 0; j <= nz; j++) {
      for (var i = 0; i <= nx; i++) {
        final x = -_hw + 2 * _hw * i / nx, z = -.4 + (_len + .4) * j / nz;
        v.add(V3(x, _h(x, z), z));
      }
    }
    final f = <Face3>[];
    for (var j = 0; j < nz; j++) {
      for (var i = 0; i < nx; i++) {
        final a = j * (nx + 1) + i;
        final z = -.4 + (_len + .4) * (j + .5) / nz;
        final stripe = (j ~/ 2).isEven;
        var col = stripe ? const Color(0xFF7DDB6A) : const Color(0xFF6CCC5C);
        if (z > 2.6 && z < 5.8) col = stripe ? const Color(0xFF8CD8A0) : const Color(0xFF7ECB92);
        f.add(Face3([a, a + nx + 1, a + nx + 2, a + 1], col));
      }
    }
    return Mesh(v, f, doubleSided: true);
  }

  // --------------------------------------------------------------- input ---

  bool get _canShoot => !_moving && !_sunk && !_lost && _strokes < _maxStrokes;

  @override
  void onDown(Offset p) {
    if (!_canShoot) return;
    _aiming = true;
    _aimFrom = p;
    _aimNow = p;
  }

  @override
  void onMove(Offset p) {
    if (_aiming) _aimNow = p;
  }

  (double, double, double)? _shot() {
    final a = scene.cam.screenToGround(_aimFrom), b = scene.cam.screenToGround(_aimNow);
    if (a == null || b == null) return null;
    final dx = a.x - b.x, dz = a.z - b.z;
    final d = sqrt(dx * dx + dz * dz);
    if (d < .15) return null;
    final power = min(d * 4.2, 11.0);
    return (dx / d, dz / d, power);
  }

  @override
  void onUp(Offset p) {
    if (!_aiming) return;
    _aiming = false;
    _aimNow = p;
    final s = _shot();
    if (s == null) return;
    _vx = s.$1 * s.$3;
    _vz = s.$2 * s.$3;
    _moving = true;
    _strokes++;
    host.sfx(Sfx.hit, volume: .5 + s.$3 / 22, rate: 1.4);
    host.sfx(Sfx.swing, volume: .4);
    final sp = scene.cam.project(V3(_bx, _by, _bz));
    if (sp != null) host.fx.burst(sp, Pal.white, count: 8, speed: 140, size: 4, gravity: 0, life: .3);
    if (s.$3 > 9.5) host.shake(3);
  }

  @override
  void onKey(String key, bool down) {
    if (key == 'action' && down && _canShoot) {
      // keyboard: straight putt at the tunnel
      final dx = 0 - _bx, dz = _millZ0 - _bz;
      final d = sqrt(dx * dx + dz * dz);
      _vx = dx / d * 8.5;
      _vz = dz / d * 8.5;
      _moving = true;
      _strokes++;
      host.sfx(Sfx.hit, rate: 1.4);
    }
  }

  // -------------------------------------------------------------- update ---

  bool get _doorBlocked {
    for (var k = 0; k < 4; k++) {
      final a = (_mill + k * pi / 2) % (pi * 2);
      if ((a - pi).abs() < .36) return true;
    }
    return false;
  }

  @override
  void update(double dt) {
    _t += dt;
    _mill += dt * 1.25 * host.speed;
    _bonkCd -= dt;
    _celebrate = max(0, _celebrate - dt);
    if (_sunk) {
      _sinkT += dt;
      _by = max(-.4, -_sinkT * 1.6);
      return;
    }
    if (!_moving) {
      _by = _h(_bx, _bz);
      return;
    }
    // sub-steps for stable collisions
    const steps = 4;
    final h = dt / steps;
    for (var s = 0; s < steps; s++) {
      _step(h);
      if (_sunk) return;
    }
    _by = _h(_bx, _bz);
    final sp = sqrt(_vx * _vx + _vz * _vz);
    _roll += sp * dt / _ballR;
    if (sp < .09) {
      _vx = 0;
      _vz = 0;
      _moving = false;
      if (_strokes >= _maxStrokes && !_sunk) {
        _lost = true;
        host.sfx(Sfx.aww);
        host.fx.pop(host.tr('oops', 'OOPS!'), const Offset(180, 250), color: Pal.red, size: 36);
        host.lose();
      }
    }
  }

  void _step(double dt) {
    // slope acceleration from the height field
    const e = .05;
    final gx = (_h(_bx + e, _bz) - _h(_bx - e, _bz)) / (2 * e);
    final gz = (_h(_bx, _bz + e) - _h(_bx, _bz - e)) / (2 * e);
    _vx -= gx * 30 * dt;
    _vz -= gz * 30 * dt;
    final sp = sqrt(_vx * _vx + _vz * _vz);
    if (sp > 0) {
      final ns = max(0.0, sp * exp(-.55 * dt) - .75 * dt);
      _vx *= ns / sp;
      _vz *= ns / sp;
    }
    final pz = _bz;
    _bx += _vx * dt;
    _bz += _vz * dt;
    // outer walls
    if (_bx.abs() > _hw - _ballR) {
      _bx = _bx.sign * (_hw - _ballR);
      _vx = -_vx * .72;
      _bonk(Sfx.clang, .3);
    }
    if (_bz < -.4 + _ballR) {
      _bz = -.4 + _ballR;
      _vz = -_vz * .72;
      _bonk(Sfx.clang, .3);
    }
    if (_bz > _len - _ballR) {
      _bz = _len - _ballR;
      _vz = -_vz * .72;
      _bonk(Sfx.clang, .3);
    }
    // windmill blocks
    for (final (x0, x1) in const [(-_millHalf, -_gap), (_gap, _millHalf)]) {
      _boxCollide(x0, x1, _millZ0, _millZ1);
    }
    // blades close the door
    if (_doorBlocked && _bx.abs() < _gap && _bz + _ballR > _millZ0 - .12 && pz + _ballR <= _millZ0 - .1 && _vz > 0) {
      _bz = _millZ0 - .12 - _ballR;
      _vz = -_vz * .6 - .5;
      _vx += rand(-.6, .6);
      _bonk(Sfx.boing, .8);
      host.shake(4);
      final sp = scene.cam.project(V3(_bx, .3, _bz));
      if (sp != null) {
        host.fx.pop(host.tr('blocked', 'BLOCKED!'), sp + const Offset(0, -40), color: Pal.orange, size: 22);
      }
    }
    // cup
    final dx = _hole.x - _bx, dz = _hole.z - _bz;
    final d = sqrt(dx * dx + dz * dz);
    if (d < _holeR) {
      final s = sqrt(_vx * _vx + _vz * _vz);
      if (s < 4.2) {
        _sink();
      } else if (_bonkCd <= 0) {
        // lip-out: deflect and slow
        final nx = -dx / max(d, 1e-4), nz = -dz / max(d, 1e-4);
        _vx = (_vx + nx * 1.5) * .6;
        _vz = (_vz + nz * 1.5) * .6;
        _bonk(Sfx.clang, .6);
        host.fx.pop(host.tr('lip_out', 'LIP OUT!'), const Offset(180, 200), color: Pal.orange, size: 28);
      }
    }
  }

  void _boxCollide(double x0, double x1, double z0, double z1) {
    final cx = _bx.clamp(x0, x1), cz = _bz.clamp(z0, z1);
    final dx = _bx - cx, dz = _bz - cz;
    final d2 = dx * dx + dz * dz;
    if (d2 >= _ballR * _ballR) return;
    final d = sqrt(d2);
    double nx, nz;
    if (d < 1e-5) {
      nx = 0;
      nz = -1;
    } else {
      nx = dx / d;
      nz = dz / d;
    }
    _bx = cx + nx * _ballR * 1.01;
    _bz = cz + nz * _ballR * 1.01;
    final vn = _vx * nx + _vz * nz;
    if (vn < 0) {
      _vx -= 1.72 * vn * nx;
      _vz -= 1.72 * vn * nz;
      _bonk(Sfx.thud, .5);
    }
  }

  void _bonk(String s, double vol) {
    if (_bonkCd > 0) return;
    _bonkCd = .08;
    host.sfx(s, volume: vol, rate: rand(1.1, 1.4));
  }

  void _sink() {
    _sunk = true;
    _moving = false;
    _bx = _hole.x;
    _bz = _hole.z;
    _celebrate = 2.5;
    final sp = scene.cam.project(_hole) ?? const Offset(180, 200);
    host.sfx(Sfx.drip, rate: .8);
    host.sfx(Sfx.fanfare);
    host.sfx(Sfx.cheer, volume: .7);
    host.fx.confetti();
    host.fx.ring(sp, Pal.white, size: 80);
    host.fx.coins(sp, count: 18);
    host.flash(Pal.white, .18);
    host.punch(.06);
    final word = _strokes == 1 ? host.tr('hole_in_one', 'HOLE IN ONE!') : (_strokes == 2 ? host.tr('birdie', 'BIRDIE!') : host.tr('par', 'PAR!'));
    host.fx.pop(word, const Offset(180, 230), color: Pal.yellow, size: _strokes == 1 ? 40 : 36, life: 1.5);
    host.addScore(_strokes == 1 ? 1000 : (_strokes == 2 ? 500 : 200), const Offset(180, 290));
    host.win(stars: _maxStrokes + 1 - _strokes);
  }

  @override
  void onTimeUp() {
    host.sfx(Sfx.aww);
    host.lose();
  }

  // -------------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    _sky(c);
    final follow = ((_bz - 1.2) * .3).clamp(0.0, 2.5);
    final cam = scene.cam
      ..center = const Offset(180, 300)
      ..focal = 560
      ..pos = V3(_bx * .15, 14.5, -3.2 + follow)
      ..lookAt(V3(_bx * .1, 0, 7.6 + follow * .5));
    // pass 1: lawn + course
    scene.clear();
    scene.add(_lawn, pos: const V3(0, -.05, 7));
    scene.render(c);
    scene.clear();
    scene.add(_course);
    scene.render(c);
    // painted slope arrows & cup
    for (var i = 0; i < 3; i++) {
      final z = 3.4 + i * .9;
      final p = cam.project(V3(0, _h(0, z) + .01, z));
      if (p != null) {
        final off = ((_t * 1.2) % 1) * 14;
        D.arrow(c, p + Offset(off - 7, 0), const Offset(1, 0), 60, const Color(0x55FFFFFF), width: 9);
      }
    }
    _groundCircle(c, _hole.x, _hole.z, _holeR + .06, const Color(0xFFEFFFF0));
    _groundCircle(c, _hole.x, _hole.z, _holeR, const Color(0xFF1B2A1A));
    // ball shadow
    if (!_sunk) _groundCircle(c, _bx + .05, _bz + .05, _ballR * 1.1, const Color(0x44203018));
    // aim guide on the ground
    if (_aiming) _aimGuide(c);
    // pass 2: objects
    scene.clear();
    scene.add(_trees);
    scene.add(_rails);
    scene.add(_house);
    scene.add(_roof, pos: const V3(0, 3.1, (_millZ0 + _millZ1) / 2), rotY: pi / 4);
    const hubPos = V3(0, 2.25, _millZ0 - .12);
    for (var k = 0; k < 4; k++) {
      scene.add(_blade, pos: hubPos, rotZ: _mill + k * pi / 2);
    }
    scene.add(_hub, pos: hubPos, rotX: pi / 2);
    // flag
    final hp = V3(_hole.x, _h(_hole.x, _hole.z), _hole.z);
    scene.add(_pole, pos: hp + const V3(0, .9, 0));
    scene.addSprite(hp + const V3(0, 1.62, 0), (cv, s, k) {
      final w = k * .7, hh = k * .4;
      final wave = sin(_t * 6) * hh * .15;
      final path = Path()
        ..moveTo(s.dx, s.dy)
        ..quadraticBezierTo(s.dx + w * .5, s.dy + wave, s.dx + w, s.dy + hh * .5)
        ..quadraticBezierTo(s.dx + w * .5, s.dy + hh + wave, s.dx, s.dy + hh)
        ..close();
      cv.drawPath(path, D.fill(Pal.red));
      cv.drawPath(path, D.stroke(Pal.ink, 1.5));
    });
    if (!_sunk || _sinkT < .25) {
      scene.add(_ball, pos: V3(_bx, _by + _ballR, _bz), rotX: _roll, flash: .15);
    }
    scene.render(c);
    _hud(c);
  }

  void _groundCircle(Canvas c, double x, double z, double r, Color col) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final a = i / 16 * pi * 2;
      final px = x + cos(a) * r, pz = z + sin(a) * r;
      final p = scene.cam.project(V3(px, _h(px, pz) + .005, pz));
      if (p == null) return;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path..close(), Paint()..color = col);
  }

  void _aimGuide(Canvas c) {
    final s = _shot();
    if (s == null) return;
    final (dx, dz, power) = s;
    final t = power / 11;
    final col = Color.lerp(Pal.lime, Pal.red, t)!;
    // dotted preview
    for (var i = 1; i <= 9; i++) {
      final d = i * .35 * (.5 + t * 1.2);
      final x = _bx + dx * d, z = _bz + dz * d;
      final p = scene.cam.project(V3(x, _h(x, z) + .02, z));
      if (p != null) c.drawCircle(p, 4.5 - i * .3, D.fill(Color.fromRGBO(255, 255, 255, 1 - i / 11)));
    }
    final a = scene.cam.project(V3(_bx, _by, _bz));
    final b = scene.cam.project(V3(_bx + dx * (.6 + t * 1.8), _by, _bz + dz * (.6 + t * 1.8)));
    if (a != null && b != null) {
      D.arrow(c, Offset.lerp(a, b, .5)!, b - a, (b - a).distance, col, width: 8 + t * 6);
    }
    // power ring around the ball
    if (a != null) {
      c.drawArc(Rect.fromCircle(center: a, radius: 26), -pi / 2, pi * 2 * t, false, D.stroke(col, 6));
    }
  }

  void _sky(Canvas c) {
    D.gradientBg(c, const [Color(0xFF9ED8F0), Color(0xFFFFE0C8), Color(0xFFFFC4A8)]);
    for (var i = 0; i < 4; i++) {
      D.cloud(c, Offset((i * 110 + _t * (6 + i * 2)) % 460 - 50, 60 + i * 28.0), 40 + i * 8.0,
          color: const Color(0xCCFFFFFF));
    }
  }

  void _hud(Canvas c) {
    // strokes left as golf balls
    D.rrect(c, const Rect.fromLTWH(12, 50, 136, 40), 20, const Color(0xCCFFFFFF), border: Pal.ink, borderWidth: 2.5);
    for (var i = 0; i < _maxStrokes; i++) {
      final used = i < _strokes;
      final o = Offset(36 + i * 30.0, 70);
      c.drawCircle(o, 11, D.fill(used ? const Color(0x33000000) : Pal.white));
      c.drawCircle(o, 11, D.stroke(Pal.ink, 2));
      if (!used) {
        for (var d = 0; d < 3; d++) {
          c.drawCircle(o + Offset(-4 + d * 4.0, -2 + (d % 2) * 4.0), 1.3, D.fill(const Color(0x55000000)));
        }
      }
    }
    D.text(c, 'PAR 3', const Offset(300, 70), size: 18, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
    if (_celebrate > 0 && _strokes == 1) {
      D.rays(c, const Offset(180, 230), 300, Color.fromRGBO(255, 230, 120, .25 * min(1, _celebrate)), t: _t, count: 16);
    }
    if (_strokes == 0 && !_aiming && host.time < 4) {
      final bp = scene.cam.project(V3(_bx, 0, _bz)) ?? const Offset(180, 520);
      final ph = (_t * 1.1) % 1;
      D.hand(c, bp + Offset(0, 20 + ph * 70), _t);
      D.arrow(c, bp + const Offset(0, -60), const Offset(0, -1), 50, Pal.yellow, width: 10);
      D.text(c, host.tr('pull', 'PULL'), bp + const Offset(56, 60), size: 22, color: Pal.white, stroke: Pal.ink,
          strokeWidth: 5);
    }
  }
}
