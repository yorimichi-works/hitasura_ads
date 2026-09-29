import '../engine/engine.dart';

/// No.013 Black Hole City — drag a black hole around a low-poly city.
/// Anything smaller than the hole falls in and the hole grows.
/// Grow big enough to swallow the skyscraper!
class G013 extends MiniGame {
  static const _half = 20.0;
  static const _k = .45; // growth factor (r² gain per size²)
  static const _levels = [.76, 1.09, 1.74, 2.5, 3.5];

  final scene = Scene3();
  final List<_Obj> _objs = [];
  final List<_Obj> _behind = [], _front = [], _falling = [];
  late final Mesh _ground;
  late final List<Mesh> _people, _cars, _houses, _buildings;
  late final Mesh _tree, _bench, _hydrant, _tower;

  double _hx = 0, _hz = -14;
  double _r = .75; // displayed radius
  double _r2 = .75 * .75; // target radius²
  int _level = 1;
  double _t = 0;
  Offset? _last;
  double _combo = 0;
  int _comboN = 0;
  double _pulse = 0;
  bool _won = false;
  int _eaten = 0;
  bool _moved = false;
  final Path _holePath = Path();

  static const _roadCol = Color(0xFF4B4F5E);
  static const _roadCol2 = Color(0xFF555a6a);
  static const _walk = Color(0xFFE4DDCF);
  static const _walk2 = Color(0xFFD6CFBF);
  static const _park = Color(0xFF7BD66B);
  static const _park2 = Color(0xFF6CC75E);

  @override
  void init() {
    scene.ambient = .62;
    scene.diffuse = .5;
    scene.light = const V3(-.5, 1, -.35).normalized;
    _ground = Mesh.grid(40, 40, 20, 20, (i, j) {
      final x = -19 + 2.0 * i, z = -19 + 2.0 * j;
      final roadX = x.abs() == 7, roadZ = z.abs() == 7;
      if (roadX && roadZ) return const Color(0xFF6A6F80);
      if (roadX || roadZ) return (i + j).isEven ? _roadCol : _roadCol2;
      if (x.abs() < 6 && z.abs() < 6) return (i + j).isEven ? _park : _park2;
      return (i + j).isEven ? _walk : _walk2;
    });
    _people = [
      for (final c in [Pal.red, Pal.sky, Pal.yellow, Pal.purple, Pal.lime])
        Mesh.merge([
          (Mesh.box(.34, .5, .24, const Color(0xFF34406B)), const V3(0, .25, 0)),
          (Mesh.box(.44, .44, .3, c), const V3(0, .7, 0)),
          (Mesh.box(.32, .32, .32, Pal.skin), const V3(0, 1.1, 0)),
        ])
    ];
    _cars = [for (final c in [Pal.red, Pal.blue, Pal.yellow, Pal.teal, Pal.pink]) Models.car(c)];
    _houses = [
      Models.house(const Color(0xFFFFE6C4), const Color(0xFFE0524A)),
      Models.house(const Color(0xFFD9F0FF), const Color(0xFF3D6BFF)),
      Models.house(const Color(0xFFFFF4A8), const Color(0xFF2ECC71)),
    ];
    _buildings = [
      for (final (c, top) in [
        (const Color(0xFF9FB4FF), const Color(0xFF6E86E0)),
        (const Color(0xFFFFB3C7), const Color(0xFFE07A96)),
        (const Color(0xFFB8F0D8), const Color(0xFF6CC7A0)),
      ])
        Mesh.merge([
          (Mesh.box(3.2, 5, 3.2, c, colors: [top, c, c, c, c, c]), const V3(0, 2.5, 0)),
          (Mesh.box(3.3, .3, 3.3, Color.lerp(c, Pal.white, .5)!), const V3(0, 1.8, 0)),
          (Mesh.box(3.3, .3, 3.3, Color.lerp(c, Pal.white, .5)!), const V3(0, 3.4, 0)),
          (Mesh.box(1, .8, 1, const Color(0xFF8E8AA3)), const V3(.6, 5.4, .4)),
        ])
    ];
    _tree = Mesh.merge([
      (Mesh.box(.2, .7, .2, const Color(0xFF8A5A3C)), const V3(0, .35, 0)),
      (Mesh.sphere(.62, const Color(0xFF3FBF5A), lat: 3, lon: 6), const V3(0, 1.15, 0)),
    ]);
    _bench = Mesh.merge([
      (Mesh.box(1.0, .12, .36, const Color(0xFFB06A34)), const V3(0, .42, 0)),
      (Mesh.box(1.0, .36, .1, const Color(0xFFB06A34)), const V3(0, .7, .16)),
      (Mesh.box(.08, .42, .3, const Color(0xFF444444)), const V3(-.4, .21, 0)),
      (Mesh.box(.08, .42, .3, const Color(0xFF444444)), const V3(.4, .21, 0)),
    ]);
    _hydrant = Mesh.merge([
      (Mesh.cylinder(.18, .5, Pal.red, seg: 6), const V3(0, .25, 0)),
      (Mesh.cone(.2, .2, Pal.red, seg: 6), const V3(0, .6, 0)),
    ]);
    _tower = Mesh.merge([
      (Mesh.box(4.4, 9, 4.4, const Color(0xFF5B6CFF), colors: const [
        Color(0xFF3A48C8), Color(0xFF5B6CFF), Color(0xFF7F8CFF), Color(0xFF7F8CFF), Color(0xFF6C7BFF), Color(0xFF6C7BFF)
      ]), const V3(0, 4.5, 0)),
      (Mesh.box(3.2, 3, 3.2, const Color(0xFF9FB0FF)), const V3(0, 10.5, 0)),
      (Mesh.box(4.6, .35, 4.6, Pal.gold), const V3(0, 9.1, 0)),
      (Mesh.box(4.6, .35, 4.6, Pal.gold), const V3(0, 3.5, 0)),
      (Mesh.pyramid(2.6, 2, Pal.gold), const V3(0, 13, 0)),
      (Mesh.cylinder(.1, 2.2, Pal.white, seg: 4), const V3(0, 15, 0)),
    ]);
    _buildCity();
  }

  void _add(int type, double x, double z) {
    final (size, mesh) = switch (type) {
      0 => (.3, pick(_people)),
      1 => (.3, _hydrant),
      2 => (.55, _bench),
      3 => (.72, _tree),
      4 => (1.0, pick(_cars)),
      5 => (1.55, pick(_houses)),
      6 => (2.3, pick(_buildings)),
      _ => (3.2, _tower),
    };
    _objs.add(_Obj(type, x, z, size, mesh, type == 7 ? 0 : (type == 4 ? 0 : randInt(4) * pi / 2)));
  }

  void _scatter(int type, int n, double x0, double x1, double z0, double z1) {
    final size = const [.3, .3, .55, .72, 1.0, 1.55, 2.3, 3.2][type];
    for (var i = 0; i < n; i++) {
      for (var tries = 0; tries < 25; tries++) {
        final x = rand(x0 + size, x1 - size), z = rand(z0 + size, z1 - size);
        if (_objs.every((o) => (Offset(o.x - x, o.z - z)).distance > o.size + size + .15)) {
          _add(type, x, z);
          break;
        }
      }
    }
  }

  void _buildCity() {
    _add(7, 0, 0);
    // central park ring
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + pi / 8;
      _add(3, cos(a) * 4.6, sin(a) * 4.6);
    }
    _scatter(2, 3, -6, 6, -6, 6);
    _scatter(0, 6, -6, 6, -6, 6);
    // starter block (south-center): lots of tiny snacks
    _scatter(0, 14, -6, 6, -20, -8);
    _scatter(1, 5, -6, 6, -20, -8);
    _scatter(2, 4, -6, 6, -20, -8);
    _scatter(3, 5, -6, 6, -20, -8);
    // other blocks
    const blocks = [
      (-20.0, -8.0, -20.0, -8.0), (8.0, 20.0, -20.0, -8.0),
      (-20.0, -8.0, -6.0, 6.0), (8.0, 20.0, -6.0, 6.0),
      (-20.0, -8.0, 8.0, 20.0), (-6.0, 6.0, 8.0, 20.0), (8.0, 20.0, 8.0, 20.0),
    ];
    for (var b = 0; b < blocks.length; b++) {
      final (x0, x1, z0, z1) = blocks[b];
      if (b >= 2) _scatter(6, b.isEven ? 1 : 2, x0, x1, z0, z1);
      _scatter(5, b < 2 ? 3 : 1, x0, x1, z0, z1);
      _scatter(3, 3, x0, x1, z0, z1);
      _scatter(0, 4, x0, x1, z0, z1);
      _scatter(1, 1, x0, x1, z0, z1);
    }
    // cars cruising on the roads
    for (var i = 0; i < 12; i++) {
      final vertical = i.isEven;
      final lane = (i % 4 < 2 ? -7.0 : 7.0) + (i % 3 == 0 ? .6 : -.6);
      final along = rand(-18, 18);
      final o = _Obj(4, vertical ? lane : along, vertical ? along : lane, 1.0, pick(_cars), vertical ? 0 : pi / 2);
      final sp = rand(2.2, 3.8) * (chance(.5) ? 1 : -1);
      o.vx = vertical ? 0 : sp;
      o.vz = vertical ? sp : 0;
      o.rotY = vertical ? (sp > 0 ? 0 : pi) : (sp > 0 ? pi / 2 : -pi / 2);
      _objs.add(o);
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _combo = max(0, _combo - dt);
    _pulse = M.approach(_pulse, 0, 5, dt);
    _r = M.approach(_r, sqrt(_r2), 6, dt);
    final r = _r;
    for (final o in _objs) {
      if (o.state == 2) continue;
      if (o.state == 1) {
        o.fallT += dt / .7;
        if (o.fallT >= 1) {
          o.state = 2;
          _swallowed(o);
        }
        continue;
      }
      // movement
      if (o.type == 4 && (o.vx != 0 || o.vz != 0)) {
        o.x += o.vx * dt;
        o.z += o.vz * dt;
        if (o.x > 19) o.x = -19;
        if (o.x < -19) o.x = 19;
        if (o.z > 19) o.z = -19;
        if (o.z < -19) o.z = 19;
      } else if (o.type == 0) {
        final dx = o.x - _hx, dz = o.z - _hz;
        final d = sqrt(dx * dx + dz * dz);
        if (d < r + 2.5 && d > .01) {
          // panic: run away (slowly — they have short legs)
          o.x += dx / d * 1.1 * dt;
          o.z += dz / d * 1.1 * dt;
          o.rotY = atan2(dx, dz);
          o.panic = true;
        } else {
          o.panic = false;
        }
      }
      final dx = o.x - _hx, dz = o.z - _hz;
      final d = sqrt(dx * dx + dz * dz);
      if (!host.finished || _won) {
        if (o.size < r * .92 && d < r - o.size * .25) {
          o.state = 1;
          o.fallT = 0;
          o.sx = o.x;
          o.sz = o.z;
          o.spin = rand(-8, 8);
          if (o.type >= 5) host.sfx(Sfx.crash, volume: .5, rate: 1.2);
        } else if (d < r + o.size * .6) {
          o.wobble = 1;
        }
      }
      o.wobble = M.approach(o.wobble, 0, 5, dt);
    }
  }

  void _swallowed(_Obj o) {
    _eaten++;
    final gain = o.size * o.size * _k;
    _r2 += gain;
    _comboN = _combo > 0 ? _comboN + 1 : 1;
    _combo = .7;
    final pts = const [5, 5, 10, 15, 30, 60, 120, 1000][o.type];
    final sp = scene.cam.project(V3(_hx, 0, _hz)) ?? const Offset(180, 380);
    host.addScore(pts * (1 + _comboN ~/ 5));
    host.fx.pop('+$pts', sp + Offset(rand(-30, 30), -30 - o.size * 10), color: Pal.yellow, size: 18 + o.size * 6, life: .6);
    host.sfx(o.type <= 1 ? Sfx.pop : (o.type <= 3 ? Sfx.chomp : Sfx.hitHeavy),
        volume: .6, rate: 1 + min(_comboN, 12) * .04 - o.size * .08);
    if (_comboN >= 5 && _comboN % 5 == 0) {
      host.sfx(Sfx.combo, rate: 1 + _comboN * .02);
    }
    _pulse = min(1, _pulse + .3 + o.size * .2);
    if (o.type >= 5) {
      host.shake(3 + o.size * 2);
      host.fx.smoke(sp, count: 8, size: 22);
    }
    while (_level <= _levels.length && sqrt(_r2) >= _levels[_level - 1]) {
      _level++;
      host.sfx(Sfx.levelup);
      host.fx.pop('${host.tr('level', 'LEVEL')} $_level', const Offset(180, 210), color: Pal.lime, size: 32, life: 1);
      host.fx.ring(sp, Pal.purple, size: 120);
      host.punch(.03);
    }
    if (o.type == 7) {
      _won = true;
      host.sfx(Sfx.explode);
      host.sfx(Sfx.fanfare);
      host.shake(16, .5);
      host.flash(Pal.white, .25);
      host.fx.confetti(count: 140);
      host.fx.pop(host.tr('wow', 'WOW!'), const Offset(180, 260), color: Pal.yellow, size: 52, life: 1.4);
      final tl = host.timeLeft;
      host.win(stars: tl > 6 ? 3 : (tl > 2.5 ? 2 : 1));
    }
  }

  V3? _ground0(Offset p) => scene.cam.screenToGround(p);

  @override
  void onDown(Offset p) => _last = p;

  @override
  void onMove(Offset p) {
    final l = _last;
    _last = p;
    if (l == null) return;
    final a = _ground0(l), b = _ground0(p);
    if (a == null || b == null) return;
    _hx = (_hx + (b.x - a.x) * 1.25).clamp(-_half + 1, _half - 1);
    _hz = (_hz + (b.z - a.z) * 1.25).clamp(-_half + 1, _half - 1);
    _moved = true;
  }

  @override
  void onUp(Offset p) => _last = null;

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    const step = 1.2;
    if (key == 'left') _hx = max(-_half + 1, _hx - step);
    if (key == 'right') _hx = min(_half - 1, _hx + step);
    if (key == 'up') _hz = min(_half - 1, _hz + step);
    if (key == 'down') _hz = max(-_half + 1, _hz - step);
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF9EDBFF), Color(0xFFBFEFD0), Color(0xFF9AD98A)]);
    final r = _r;
    final camH = 11.0 + r * 4.2;
    scene.cam
      ..center = const Offset(180, 330)
      ..focal = 440
      ..pos = V3(_hx, camH, _hz - camH * .48)
      ..lookAt(V3(_hx, 0, _hz + 1.2));
    scene.fogColor = const Color(0xFFBFEFD0);
    scene.fogNear = camH * 1.8 + 8;
    scene.fogFar = camH * 1.8 + 30;

    // 1) ground
    scene.clear();
    scene.add(_ground, pos: const V3(0, 0, 0));
    scene.render(c);

    // 2) hole
    _holePath.reset();
    const n = 32;
    Offset? hc;
    for (var i = 0; i < n; i++) {
      final a = i * pi * 2 / n;
      final p = scene.cam.project(V3(_hx + cos(a) * r, .02, _hz + sin(a) * r));
      if (p == null) continue;
      i == 0 ? _holePath.moveTo(p.dx, p.dy) : _holePath.lineTo(p.dx, p.dy);
    }
    _holePath.close();
    hc = scene.cam.project(V3(_hx, .02, _hz)) ?? const Offset(180, 330);
    final hb = _holePath.getBounds();
    c.drawPath(_holePath.shift(const Offset(0, 3)), D.fill(const Color(0x33000000)));
    c.drawPath(
        _holePath,
        Paint()
          ..shader = RadialGradient(colors: const [Color(0xFF000000), Color(0xFF000000), Color(0xFF2A0F4F)], stops: const [0, .6, 1])
              .createShader(hb));
    // swirl
    c.save();
    c.clipPath(_holePath);
    final sw = D.stroke(const Color(0x33B28CFF), 2.5);
    for (var i = 0; i < 4; i++) {
      final a0 = _t * 3 + i * pi / 2;
      c.drawArc(Rect.fromCenter(center: hc, width: hb.width * .7, height: hb.height * .7), a0, 1.2, false, sw);
      c.drawArc(Rect.fromCenter(center: hc, width: hb.width * .4, height: hb.height * .4), -a0 * 1.3, 1.0, false, sw);
    }
    c.restore();

    // 3) classify objects by depth relative to the hole
    _behind.clear();
    _front.clear();
    _falling.clear();
    final holeZ = scene.cam.toView(V3(_hx, 0, _hz)).z;
    final camDist = camH * 2.4 + 14;
    for (final o in _objs) {
      if (o.state == 2) continue;
      if (o.state == 1) {
        _falling.add(o);
        continue;
      }
      if ((o.x - _hx).abs() > camDist * .75 || (o.z - _hz) > camDist || (o.z - _hz) < -camH * .42) continue;
      final vz = scene.cam.toView(V3(o.x, 0, o.z)).z;
      (vz > holeZ ? _behind : _front).add(o);
    }
    scene.clear();
    for (final o in _behind) {
      _addObj(o);
    }
    scene.render(c);

    // falling objects: clipped so they vanish below the front rim
    if (_falling.isNotEmpty) {
      scene.clear();
      for (final o in _falling) {
        final k = o.fallT;
        final e = k * k;
        final px = M.lerp(o.sx, _hx, M.clamp01(k * 1.4)), pz = M.lerp(o.sz, _hz, M.clamp01(k * 1.4));
        final tilt = k * 1.4;
        scene.add(o.mesh,
            pos: V3(px, -e * (2 + o.size * 3), pz),
            rotY: o.rotY + o.spin * k,
            rotX: tilt * (pz > _hz ? -1 : 1),
            rotZ: tilt * (px > _hx ? 1 : -1) * .7,
            scale: 1 - k * .45);
      }
      c.save();
      final clip = Path()
        ..addRect(Rect.fromLTRB(-50, -50, 410, hc.dy))
        ..addPath(_holePath, Offset.zero);
      c.clipPath(clip);
      scene.render(c);
      c.restore();
    }

    // rim glow (over falling objects so the edge stays crisp)
    final glow = .6 + .4 * sin(_t * 5) + _pulse * .5;
    c.drawPath(_holePath, D.stroke(Color.fromRGBO(140, 80, 255, .35 * glow), 10 + _pulse * 8));
    c.drawPath(_holePath, D.stroke(Color.fromRGBO(200, 170, 255, min(1, .9 * glow)), 3));

    scene.clear();
    for (final o in _front) {
      _addObj(o);
    }
    scene.render(c);

    // panicked people get "!" marks
    for (final o in _front.followedBy(_behind)) {
      if (o.type == 0 && o.panic && o.state == 0) {
        final p = scene.cam.project(V3(o.x, 1.7, o.z));
        if (p != null && (o.x * 7 + o.z * 3 + _t * 4).floor().isEven) {
          D.text(c, '!', p, size: 16, color: Pal.red, stroke: Pal.white, strokeWidth: 4);
        }
      }
    }

    _renderHud(c);
    if (!_moved && host.time < 3) {
      final p = hc + Offset(40 + sin(_t * 2.5) * 50, 40 + cos(_t * 2.5) * 20);
      D.hand(c, p, _t);
      D.text(c, host.tr('drag', 'DRAG'), hc + const Offset(0, 110), size: 24, stroke: Pal.ink);
    }
  }

  void _addObj(_Obj o) {
    final wob = o.wobble > .01 ? sin(_t * 30 + o.x) * .12 * o.wobble : 0.0;
    if (o.type == 6) {
      scene.add(o.mesh, pos: V3(o.x, 0, o.z), rotY: o.rotY, rotZ: wob, scale3: V3(.72, .8 + (o.x.abs() % 1) * .5, .72));
    } else {
      scene.add(o.mesh, pos: V3(o.x, 0, o.z), rotY: o.rotY, rotZ: wob, rotX: wob * .7, scale: o.type == 4 ? .5 : 1);
    }
  }

  void _renderHud(Canvas c) {
    // size meter toward the tower
    final goal = _levels.last;
    final prog = M.clamp01((sqrt(_r2) - .75) / (goal - .75));
    const bar = Rect.fromLTWH(70, 56, 220, 20);
    D.bar(c, bar, prog, Pal.purple, back: const Color(0x66000000), border: Pal.ink);
    for (var i = 0; i < _levels.length - 1; i++) {
      final x = bar.left + bar.width * ((_levels[i] - .75) / (goal - .75));
      c.drawLine(Offset(x, bar.top + 3), Offset(x, bar.bottom - 3), D.stroke(const Color(0x88FFFFFF), 2));
    }
    // hole icon
    c.drawCircle(const Offset(48, 66), 18, D.fill(Pal.ink));
    c.drawCircle(const Offset(48, 66), 18, D.stroke(const Color(0xFFB28CFF), 3));
    D.text(c, '$_level', const Offset(48, 66), size: 16, color: Pal.white);
    // tower icon
    D.rrect(c, const Rect.fromLTWH(302, 44, 22, 36), 3, const Color(0xFF5B6CFF), border: Pal.ink, borderWidth: 2.5);
    for (var i = 0; i < 3; i++) {
      c.drawRect(Rect.fromLTWH(307, 50 + i * 9.0, 12, 4), D.fill(const Color(0xAAFFFFFF)));
    }
    c.drawPath(
        Path()
          ..moveTo(302, 44)
          ..lineTo(313, 34)
          ..lineTo(324, 44)
          ..close(),
        D.fill(Pal.gold));
    if (_combo > 0 && _comboN >= 3) {
      D.text(c, 'x$_comboN', const Offset(180, 104), size: 24 + min(_comboN, 20).toDouble(), color: Pal.yellow, stroke: Pal.ink);
    }
    D.text(c, '$_eaten', const Offset(330, 104), size: 18, color: Pal.white, stroke: Pal.ink, anchor: Alignment.centerRight);
  }
}

class _Obj {
  _Obj(this.type, this.x, this.z, this.size, this.mesh, this.rotY);
  final int type; // 0 person,1 hydrant,2 bench,3 tree,4 car,5 house,6 building,7 tower
  double x, z;
  final double size;
  final Mesh mesh;
  double rotY;
  int state = 0; // 0 standing, 1 falling, 2 gone
  double fallT = 0;
  double sx = 0, sz = 0;
  double spin = 0;
  double vx = 0, vz = 0;
  double wobble = 0;
  bool panic = false;
}
