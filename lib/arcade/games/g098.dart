import 'dart:math' as math;

import '../engine/engine.dart';

/// No.098 Marble Tilt 3D — a wooden labyrinth board. Drag to tilt it, roll
/// the glass marble around the holes, grab coins, drop it in the goal cup.
class G098 extends MiniGame {
  static const _bw = 3.0; // half width
  static const _bd = 4.5; // half depth
  static const _mr = .28; // marble radius
  static const _maxTilt = .2;
  static const _accel = 7.5;

  final scene = Scene3();
  final floor = Scene3();

  late final Mesh _boardTop;
  late final Mesh _boardBody;
  late final Mesh _walls;
  late final Mesh _marble;
  late final Mesh _coin;
  late final Mesh _flagPole;
  late final Mesh _flag;
  late final Mesh _mug;
  late final Mesh _pencil;

  final List<Rect> _wallRects = []; // board-local x/z rects
  final List<_Hole> _holes = [];
  final List<_Coin> _coins = [];
  static const _goal = Offset(-2.25, 3.65);
  static const _respawn = [Offset(-2.25, -3.7), Offset(2.25, -1.3), Offset(-2.25, 1.0), Offset(2.3, 3.3)];

  double _t = 0;
  double _tx = 0, _tz = 0; // tilt -1..1
  double _ttx = 0, _ttz = 0; // target tilt
  double _kx = 0, _kz = 0; // keyboard
  double _mx = -2.25, _mz = -3.7, _vx = 0, _vz = 0;
  double _rollA = 0, _rollB = 0;
  int _lives = 3;
  int _coinsGot = 0;
  int _lane = 0;
  _MS _ms = _MS.roll;
  double _msT = 0;
  _Hole? _fallHole;
  double _bumpCd = 0;
  double _goalSpin = 0;
  Offset? _anchor;
  double _wobble = 0;

  @override
  void init() {
    for (final s in [scene, floor]) {
      s
        ..ambient = .5
        ..diffuse = .62
        ..light = const V3(-.45, 1, -.35).normalized;
    }
    _boardTop = Mesh.grid(_bw * 2, _bd * 2, 12, 18, (i, j) {
      final grain = sin(i * 1.7 + j * .3) * .5 + sin(j * 2.9) * .3;
      return Color.lerp(const Color(0xFFE6B679), const Color(0xFFD29A5A), (grain * .5 + .5) * .7)!;
    });
    final body = Mesh.box(_bw * 2 + .8, .5, _bd * 2 + .8, const Color(0xFF8A5530));
    _boardBody = Mesh(body.verts, [for (final f in body.faces.skip(1)) Face3(List.of(f.idx), f.color)]);

    // frame + inner walls (board-local rects in x/z)
    const t = .3;
    _wallRects.addAll(const [
      Rect.fromLTRB(-_bw - t, -_bd - t, _bw + t, -_bd), // near
      Rect.fromLTRB(-_bw - t, _bd, _bw + t, _bd + t), // far
      Rect.fromLTRB(-_bw - t, -_bd, -_bw, _bd), // left
      Rect.fromLTRB(_bw, -_bd, _bw + t, _bd), // right
      Rect.fromLTRB(-_bw, -2.35, 1.5, -2.05),
      Rect.fromLTRB(-1.5, .05, _bw, .35),
      Rect.fromLTRB(-_bw, 2.35, 1.5, 2.65),
      Rect.fromLTRB(-.25, 3.35, -.0, _bd), // little divider near the goal
    ]);
    const wallCol = Color(0xFFA0643A);
    const wallTop = Color(0xFFC98A52);
    final parts = <(Mesh, V3)>[];
    for (final r in _wallRects) {
      parts.add((
        Mesh.box(r.width, .42, r.height, wallCol, colors: const [wallTop, wallCol, wallCol, wallCol, Color(0xFF8C5530), Color(0xFF8C5530)]),
        V3(r.center.dx, .21, r.center.dy)
      ));
    }
    _walls = Mesh.merge(parts);

    _holes.addAll(const [
      _Hole(0.1, -3.0, .44),
      _Hole(2.62, -4.1, .36),
      _Hole(.55, -1.35, .42),
      _Hole(-1.0, -.55, .4),
      _Hole(-.4, 1.55, .42),
      _Hole(1.05, .8, .38),
      _Hole(.9, 3.55, .42),
      _Hole(-1.2, 3.0, .34),
    ]);
    for (final c in const [Offset(-1.2, -3.8), Offset(1.4, -3.6), Offset(2.25, -.2), Offset(-2.2, -1.2), Offset(.4, 1.8),
      Offset(2.3, 1.4), Offset(.0, 2.95), Offset(-1.7, 4.0)]) {
      _coins.add(_Coin(c.dx, c.dy));
    }

    _marble = Mesh.sphere(_mr, const Color(0xFF3FD2FF), lat: 6, lon: 10);
    for (var i = 0; i < _marble.faces.length; i++) {
      final lat = i ~/ 10, lon = i % 10;
      final s = sin(lon * 1.26 + lat * 1.1);
      _marble.faces[i].color = s > .55
          ? const Color(0xFFFFFFFF)
          : s < -.6
              ? const Color(0xFF1C6BFF)
              : const Color(0xFF3FD2FF);
    }
    _coin = Mesh.cylinder(.26, .07, Pal.gold, seg: 10, cap: const Color(0xFFFFE27A));
    _flagPole = Mesh.cylinder(.03, 1.1, const Color(0xFFEEEEEE), seg: 5);
    _flag = Mesh([const V3(0, 0, 0), const V3(0, -.34, 0), const V3(.55, -.17, 0)], [Face3([0, 1, 2], const Color(0xFFFF3B5C))],
        doubleSided: true);
    _mug = Mesh.merge([
      (Mesh.cylinder(.55, 1.1, const Color(0xFFFF6F91), seg: 10, cap: const Color(0xFF4A2A1A)), const V3(0, .55, 0)),
      (Mesh.box(.14, .5, .4, const Color(0xFFFF6F91)), const V3(.62, .6, 0)),
    ]);
    _pencil = Mesh.merge([
      (Mesh.box(3.2, .18, .18, const Color(0xFFFFC53D)), const V3(0, .09, 0)),
      (Mesh.box(.3, .19, .19, const Color(0xFFFF7FA0)), const V3(-1.7, .09, 0)),
    ]);
  }

  // ------------------------------------------------------ board transform ---

  double get _rz => -_tx * _maxTilt;
  double get _rx => _tz * _maxTilt;

  /// Board-local → world, same rotation order as Scene3.add (z, then x).
  V3 _w(double x, double y, double z) {
    final cz = cos(_rz), sz = sin(_rz), cx = cos(_rx), sx = sin(_rx);
    final x1 = x * cz - y * sz;
    final y1 = x * sz + y * cz;
    final y2 = y1 * cx - z * sx;
    final z2 = y1 * sx + z * cx;
    return V3(x1, y2, z2);
  }

  // ------------------------------------------------------------ gameplay ---

  @override
  void update(double dt) {
    _t += dt;
    _msT += dt;
    _bumpCd -= dt;
    _goalSpin += dt * 3;
    _wobble = M.approach(_wobble, 0, 6, dt);
    final tx = (_ttx + _kx).clamp(-1.0, 1.0), tz = (_ttz + _kz).clamp(-1.0, 1.0);
    _tx = M.approach(_tx, host.finished ? 0 : tx, 10, dt);
    _tz = M.approach(_tz, host.finished ? 0 : tz, 10, dt);
    for (final c in _coins) {
      c.pop = c.got ? c.pop + dt : 0;
    }

    switch (_ms) {
      case _MS.roll:
        _roll(dt);
      case _MS.fall:
        if (_msT > .9) {
          if (_lives <= 0) {
            _ms = _MS.over;
            host.lose();
          } else {
            final r = _respawn[_lane];
            _mx = r.dx;
            _mz = r.dy;
            _vx = _vz = 0;
            _ms = _MS.roll;
            _msT = 0;
            host.sfx(Sfx.pop, volume: .7);
            final s = scene.cam.project(_w(_mx, _mr, _mz));
            if (s != null) host.fx.ring(s, Pal.sky, size: 50);
          }
        }
      case _MS.goal:
        final d = Offset(_goal.dx - _mx, _goal.dy - _mz);
        _mx += d.dx * min(1, dt * 6) + cos(_msT * 14) * .01;
        _mz += d.dy * min(1, dt * 6) + sin(_msT * 14) * .01;
      case _MS.over:
        break;
    }
  }

  void _roll(double dt) {
    const steps = 3;
    final h = dt / steps;
    for (var s = 0; s < steps; s++) {
      _vx += _tx * _accel * h;
      _vz += _tz * _accel * h;
      // holes pull the marble in when it's on the lip
      for (final ho in _holes) {
        final dx = ho.x - _mx, dz = ho.z - _mz;
        final d = sqrt(dx * dx + dz * dz);
        if (d < ho.r + .08 && d > 1e-4) {
          final k = (1 - d / (ho.r + .08)) * 9;
          _vx += dx / d * k * h;
          _vz += dz / d * k * h;
        }
        if (d < ho.r - .1) {
          _fall(ho);
          return;
        }
      }
      final damp = math.exp(-.9 * h);
      _vx *= damp;
      _vz *= damp;
      final sp = sqrt(_vx * _vx + _vz * _vz);
      if (sp > 5.5) {
        _vx *= 5.5 / sp;
        _vz *= 5.5 / sp;
      }
      _mx += _vx * h;
      _mz += _vz * h;
      _rollA += _vz * h / _mr;
      _rollB -= _vx * h / _mr;
      for (final r in _wallRects) {
        final cx = _mx.clamp(r.left, r.right), cz = _mz.clamp(r.top, r.bottom);
        final dx = _mx - cx, dz = _mz - cz;
        final d2 = dx * dx + dz * dz;
        if (d2 >= _mr * _mr) continue;
        double nx, nz, d;
        if (d2 < 1e-9) {
          nx = 0;
          nz = _mz > r.center.dy ? 1 : -1;
          d = 0;
        } else {
          d = sqrt(d2);
          nx = dx / d;
          nz = dz / d;
        }
        _mx += nx * (_mr - d);
        _mz += nz * (_mr - d);
        final vn = _vx * nx + _vz * nz;
        if (vn < 0) {
          _vx -= 1.4 * vn * nx;
          _vz -= 1.4 * vn * nz;
          if (-vn > 1.2 && _bumpCd <= 0) {
            _bumpCd = .12;
            host.sfx(Sfx.clang, volume: min(.8, -vn * .15), rate: 1.6);
            _wobble = min(1, -vn * .2);
            if (-vn > 3) host.shake(3);
          }
        }
      }
    }
    // lane checkpoints
    final lane = _mz < -2.2 ? 0 : (_mz < .2 ? 1 : (_mz < 2.5 ? 2 : 3));
    if (lane > _lane) {
      _lane = lane;
      host.sfx(Sfx.ding, volume: .6, rate: 1 + lane * .12);
      final s = scene.cam.project(_w(_mx, _mr * 2, _mz));
      if (s != null) host.fx.pop(host.tr('safe', 'SAFE!'), s + const Offset(0, -30), color: Pal.lime, size: 22);
    }
    // coins
    for (final c in _coins) {
      if (c.got) continue;
      final dx = c.x - _mx, dz = c.z - _mz;
      if (dx * dx + dz * dz < .45 * .45) {
        c.got = true;
        _coinsGot++;
        final s = scene.cam.project(_w(c.x, .3, c.z)) ?? const Offset(180, 300);
        host.addScore(10, s + const Offset(0, -20));
        host.sfx(Sfx.coin, rate: 1 + _coinsGot * .06);
        host.fx.sparkle(s, count: 6, radius: 20, color: Pal.yellow);
      }
    }
    // goal
    final gx = _goal.dx - _mx, gz = _goal.dy - _mz;
    if (gx * gx + gz * gz < .4 * .4) {
      _ms = _MS.goal;
      _msT = 0;
      final s = scene.cam.project(_w(_goal.dx, .2, _goal.dy)) ?? const Offset(180, 200);
      host.sfx(Sfx.fanfare, volume: .8);
      host.fx.burst(s, Pal.yellow, count: 30, speed: 300, colors: Pal.candy);
      host.fx.ring(s, Pal.yellow, size: 140, life: .5);
      host.fx.coins(s, count: 20);
      host.fx.pop(host.tr('goal', 'GOAL!'), s + const Offset(0, -50), color: Pal.yellow, size: 40, life: 1.2);
      host.shake(8);
      host.addScore(100);
      host.win(stars: _lives == 3 ? 3 : (_lives == 2 || _coinsGot >= 4 ? 2 : 1));
    }
  }

  void _fall(_Hole h) {
    _ms = _MS.fall;
    _msT = 0;
    _fallHole = h;
    _lives--;
    _vx = _vz = 0;
    host.sfx(Sfx.drip, volume: .9, rate: .6);
    host.sfx(Sfx.oops, volume: .7);
    host.shake(5);
    final s = scene.cam.project(_w(h.x, 0, h.z)) ?? const Offset(180, 300);
    host.fx.pop(host.tr('oops', 'OOPS!'), s + const Offset(0, -40), color: Pal.red, size: 30);
    host.fx.smoke(s, count: 5, color: const Color(0x88000000));
  }

  @override
  void onTimeUp() => host.lose();

  // --------------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    _anchor = p;
  }

  @override
  void onMove(Offset p) {
    final a = _anchor;
    if (a == null) return;
    var d = (p - a) / 70;
    if (d.distance > 1) d = d / d.distance;
    _ttx = d.dx;
    _ttz = -d.dy;
    // lazy anchor: follow the finger if it drags far away
    if ((p - a).distance > 110) _anchor = p - (p - a) / (p - a).distance * 110;
  }

  @override
  void onUp(Offset p) {
    _anchor = null;
    _ttx = 0;
    _ttz = 0;
  }

  @override
  void onKey(String key, bool down) {
    final v = down ? 1.0 : 0.0;
    switch (key) {
      case 'left':
        _kx = -v;
      case 'right':
        _kx = v;
      case 'up':
        _kz = v;
      case 'down':
        _kz = -v;
    }
  }

  // -------------------------------------------------------------- render ---

  void _setCam(Scene3 s) {
    s.cam
      ..center = const Offset(180, 352)
      ..focal = 560
      ..pos = V3(0, 14.5, -6.2)
      ..lookAt(const V3(0, 0, .35));
  }

  @override
  void render(Canvas c) {
    _setCam(scene);
    _setCam(floor);
    _renderTable(c);

    floor.clear();
    floor.add(_boardBody, pos: const V3(0, -.26, 0), rotZ: _rz, rotX: _rx);
    floor.add(_boardTop, rotZ: _rz, rotX: _rx);
    floor.render(c);
    _renderHoles(c);

    scene.clear();
    final wob = sin(_t * 40) * .004 * _wobble;
    scene.add(_walls, rotZ: _rz + wob, rotX: _rx);
    for (final co in _coins) {
      if (co.got && co.pop > .5) continue;
      final lift = co.got ? co.pop * 3 : .32 + sin(_t * 3 + co.x) * .05;
      scene.add(_coin, pos: _w(co.x, lift, co.z), rotX: .5 + sin(_t * 4 + co.z) * .45, rotZ: sin(_t * 3 + co.x) * .3, scale: co.got ? 1 - co.pop * 1.6 : 1);
    }
    // goal flag
    final fp = _w(_goal.dx + .42, .55, _goal.dy + .2);
    scene.add(_flagPole, pos: fp, rotZ: _rz, rotX: _rx);
    scene.add(_flag, pos: fp + const V3(0, .55, 0), rotY: sin(_t * 4) * .35 - .3, scale3: V3(1 + sin(_t * 9) * .08, 1, 1));
    // marble
    if (_ms != _MS.over) {
      double y = _mr;
      double sc = 1;
      if (_ms == _MS.fall) {
        final k = min(1.0, _msT / .45);
        y = _mr - k * .6;
        sc = 1 - k * .75;
        final h = _fallHole!;
        _mx = M.lerp(_mx, h.x, .2);
        _mz = M.lerp(_mz, h.z, .2);
      } else if (_ms == _MS.goal) {
        final k = min(1.0, _msT / .6);
        y = _mr - k * .45;
        sc = 1 - k * .3;
      } else if (_msT < .3 && _lane >= 0) {
        y = _mr + (1 - _msT / .3) * 1.5;
      }
      if (sc > .05) {
        final mp = _w(_mx, y, _mz);
        scene.add(_marble, pos: mp, rotX: _rollA, rotZ: _rollB, scale: sc);
        final toCam = (scene.cam.pos - mp).normalized;
        scene.addSprite(mp + toCam * (_mr * sc * 1.05), (c, s, k) {
          c.drawOval(Rect.fromCenter(center: s + Offset(-_mr * .3 * k * sc, -_mr * .38 * k * sc), width: _mr * .6 * k * sc, height: _mr * .4 * k * sc),
              Paint()..color = const Color(0xCCFFFFFF));
        });
      }
    }
    scene.render(c);
    _renderHud(c);
  }

  void _renderTable(Canvas c) {
    // cozy desk: wood planks + soft lamp light
    D.gradientBg(c, const [Color(0xFF3B2A4F), Color(0xFF5B3B4A), Color(0xFF4A2F2A)]);
    final plank = Paint();
    for (var i = 0; i < 9; i++) {
      final y0 = 120.0 + i * 62;
      plank.color = i.isEven ? const Color(0x22FFD9A0) : const Color(0x14000000);
      c.drawRect(Rect.fromLTWH(0, y0, 360, 62), plank);
      c.drawLine(Offset(0, y0), Offset(360, y0), D.stroke(const Color(0x33000000), 2));
    }
    c.drawCircle(const Offset(200, 300), 330,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x55FFE3A8), Color(0x00FFE3A8)])
              .createShader(Rect.fromCircle(center: const Offset(200, 300), radius: 330)));
    // props on the desk (static, not tilted)
    floor.clear();
    _setCam(floor);
    floor.add(_mug, pos: const V3(-4.5, -.5, 5.6));
    floor.add(_pencil, pos: const V3(4.3, -.5, -6.2), rotY: .5);
    floor.render(c);
    // board drop shadow
    final pts = [
      _w(-_bw - .4, -.5, -_bd - .4),
      _w(_bw + .4, -.5, -_bd - .4),
      _w(_bw + .4, -.5, _bd + .4),
      _w(-_bw - .4, -.5, _bd + .4)
    ].map((p) => scene.cam.project(p + const V3(.35, -.25, -.2))).toList();
    if (!pts.contains(null)) {
      c.drawPath(Path()..addPolygon([for (final p in pts) p!], true), Paint()..color = const Color(0x44000000));
    }
  }

  List<Offset>? _circle(double x, double z, double r, [double y = .002, int n = 20]) {
    final out = <Offset>[];
    for (var i = 0; i < n; i++) {
      final a = i / n * pi * 2;
      final p = scene.cam.project(_w(x + cos(a) * r, y, z + sin(a) * r));
      if (p == null) return null;
      out.add(p);
    }
    return out;
  }

  void _renderHoles(Canvas c) {
    for (final h in _holes) {
      final rim = _circle(h.x, h.z, h.r + .06);
      final pts = _circle(h.x, h.z, h.r);
      final inner = _circle(h.x + .06, h.z - .08, h.r * .82);
      if (rim == null || pts == null || inner == null) continue;
      c.drawPath(Path()..addPolygon(rim, true), Paint()..color = const Color(0xFF7A4526));
      c.drawPath(Path()..addPolygon(pts, true), Paint()..color = const Color(0xFF1A0E08));
      c.drawPath(Path()..addPolygon(inner, true), Paint()..color = const Color(0xFF000000));
    }
    // goal cup with pulsing glow
    final glow = _circle(_goal.dx, _goal.dy, .6 + .06 * sin(_t * 6));
    final cup = _circle(_goal.dx, _goal.dy, .42);
    final ring = _circle(_goal.dx, _goal.dy, .5);
    if (glow != null && cup != null && ring != null) {
      c.drawPath(Path()..addPolygon(glow, true), Paint()..color = Color.fromRGBO(255, 230, 90, .35 + .15 * sin(_t * 6)));
      c.drawPath(Path()..addPolygon(ring, true), Paint()..color = const Color(0xFFFFFFFF));
      c.drawPath(Path()..addPolygon(cup, true), Paint()..color = const Color(0xFF2A1A08));
      // checker on the ring
      for (var i = 0; i < 8; i += 2) {
        final a0 = i / 8 * pi * 2 + _goalSpin * .2, a1 = (i + 1) / 8 * pi * 2 + _goalSpin * .2;
        final q = [
          _w(_goal.dx + cos(a0) * .42, .003, _goal.dy + sin(a0) * .42),
          _w(_goal.dx + cos(a0) * .5, .003, _goal.dy + sin(a0) * .5),
          _w(_goal.dx + cos(a1) * .5, .003, _goal.dy + sin(a1) * .5),
          _w(_goal.dx + cos(a1) * .42, .003, _goal.dy + sin(a1) * .42),
        ].map(scene.cam.project).toList();
        if (!q.contains(null)) c.drawPath(Path()..addPolygon([for (final p in q) p!], true), D.fill(Pal.ink));
      }
    }
    // start pad arrow hints along the route
    if (host.time < 4 && !host.finished) {
      const route = [Offset(-1.2, -3.75), Offset(1.4, -3.75), Offset(2.25, -2.9), Offset(2.25, -1.6)];
      for (var i = 0; i < route.length - 1; i++) {
        final a = scene.cam.project(_w(route[i].dx, .01, route[i].dy));
        final b = scene.cam.project(_w(route[i + 1].dx, .01, route[i + 1].dy));
        if (a == null || b == null) continue;
        final k = M.wave(_t * 2 - i * .3, 1);
        D.arrow(c, Offset.lerp(a, b, .5)!, b - a, (b - a).distance * .6, Color.fromRGBO(255, 255, 255, .25 + .35 * k), width: 7);
      }
    }
    // marble shadow
    if (_ms == _MS.roll || (_ms == _MS.fall && _msT < .2)) {
      final s = scene.cam.project(_w(_mx + .12, .003, _mz - .1));
      if (s != null) {
        final k = scene.cam.scaleAt(_w(_mx, 0, _mz));
        D.shadow(c, s, _mr * 2.2 * k, _mr * 1.5 * k, .35);
      }
    }
  }

  void _renderHud(Canvas c) {
    // lives
    for (var i = 0; i < 3; i++) {
      final o = Offset(30 + i * 30.0, 62);
      final alive = i < _lives;
      D.circle(c, o, 11, alive ? const Color(0xFF3FD2FF) : const Color(0x33FFFFFF), border: Pal.ink, borderWidth: 2);
      if (alive) c.drawCircle(o + const Offset(-3.5, -3.5), 3.5, D.fill(const Color(0xCCFFFFFF)));
    }
    // coins
    D.rrect(c, const Rect.fromLTWH(250, 48, 96, 30), 15, const Color(0xAA1B1238));
    D.coin(c, const Offset(268, 63), 10, spin: _t * 3);
    D.text(c, '$_coinsGot/${_coins.length}', const Offset(310, 63), size: 18, color: Pal.white);
    // tilt stick
    final a = _anchor;
    if (a != null && host.pointerDown) {
      c.drawCircle(a, 70, D.stroke(const Color(0x66FFFFFF), 3));
      c.drawCircle(a, 70, D.fill(const Color(0x14FFFFFF)));
      final knob = a + Offset(_ttx, -_ttz) * 70;
      D.circle(c, knob, 22, const Color(0x99FFFFFF), border: const Color(0xCC1B1530), borderWidth: 2.5);
    } else if (host.time < 2.8 && !host.finished) {
      final o = Offset(180 + sin(_t * 2.4) * 40, 560);
      c.drawCircle(const Offset(180, 560), 50, D.stroke(const Color(0x55FFFFFF), 3));
      D.hand(c, o, _t);
      D.text(c, host.tr('drag', 'DRAG'), const Offset(180, 620), size: 18, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
    }
  }
}

enum _MS { roll, fall, goal, over }

class _Hole {
  const _Hole(this.x, this.z, this.r);
  final double x, z, r;
}

class _Coin {
  _Coin(this.x, this.z);
  final double x, z;
  bool got = false;
  double pop = 0;
}
