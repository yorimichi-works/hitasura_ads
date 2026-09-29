import 'dart:math' as math;

import '../engine/engine.dart';

/// No.104 Penguin Slide — belly-slide down an icy 3D slope, steer by dragging,
/// grab fish, dodge rocks & seals, launch off ramps. >= 10 fish at the GOAL.
class G104 extends MiniGame {
  static const _need = 10;
  static const _len = 330.0;
  static const _halfW = 4.4;
  static const _slope = .32;

  final scene = Scene3();
  late final Mesh _penguin, _rock, _sealBody, _ramp, _pine, _post, _banner, _flag;
  final _objs = <_Obj>[];
  final _flakes = <List<double>>[];

  double _s = 2; // distance
  double _v = 13;
  double _lx = 0, _lxTarget = 0, _lxAtDown = 0, _downX = 0;
  double _py = 0, _vy = 0;
  double _stun = 0;
  double _spin = 0;
  double _t = 0;
  int _fish = 0;
  bool _done = false;
  double _endT = 0;
  bool _won = false;
  double _lean = 0;
  double _flap = 0;
  int _keyDir = 0;
  bool _touched = false;
  double _fishPop = 0;

  static double _cx(double z) => 3.0 * sin(z * .045) + 1.4 * sin(z * .11 + 1);
  static double _y(double z) => -_slope * z;

  @override
  void init() {
    scene.ambient = .62;
    scene.diffuse = .5;
    scene.light = const V3(-.5, 1, -.35).normalized;
    scene.fogColor = const Color(0xFFE4F4FF);
    scene.fogNear = 22;
    scene.fogFar = 62;
    const black = Color(0xFF232A3D), white = Color(0xFFF7FBFF), orange = Color(0xFFFF9A1F);
    _penguin = Mesh.merge([
      (_sc(Mesh.sphere(.55, black, lat: 5, lon: 8), .85, .62, 1.25), const V3(0, .38, 0)),
      (_sc(Mesh.sphere(.5, white, lat: 4, lon: 8), .75, .45, 1.1), const V3(0, .22, .05)),
      (Mesh.sphere(.36, black, lat: 4, lon: 8), const V3(0, .55, .78)),
      (_rx(Mesh.cone(.1, .28, orange, seg: 5), pi / 2), const V3(0, .52, 1.14)),
      (_rx(Mesh.cylinder(.33, .14, const Color(0xFFE8304A), seg: 8), pi / 2), const V3(0, .5, .5)),
      (Mesh.box(.22, .06, .5, const Color(0xFFFF5470)), const V3(.2, .72, .3)),
      (Mesh.box(.55, .08, .26, black), const V3(-.62, .32, .15)),
      (Mesh.box(.55, .08, .26, black), const V3(.62, .32, .15)),
      (Mesh.box(.18, .08, .3, orange), const V3(-.2, .25, -.78)),
      (Mesh.box(.18, .08, .3, orange), const V3(.2, .25, -.78)),
    ]);
    _rock = Mesh.sphere(.9, const Color(0xFF9CC9E8), lat: 3, lon: 6);
    _sealBody = Mesh.merge([
      (_sc(Mesh.sphere(.6, const Color(0xFF8C95A8), lat: 4, lon: 8), 1, .75, 1.5), const V3(0, .45, .3)),
      (Mesh.sphere(.42, const Color(0xFF9AA3B6), lat: 4, lon: 8), const V3(0, .85, -.45)),
      (Mesh.box(.7, .08, .3, const Color(0xFF6E778A)), const V3(0, .12, 1.25)),
    ]);
    _ramp = Mesh([
      const V3(-1.4, 0, 0), const V3(1.4, 0, 0), const V3(1.4, 0, 2.6), const V3(-1.4, 0, 2.6),
      const V3(-1.4, 1.0, 2.6), const V3(1.4, 1.0, 2.6),
    ], [
      Face3([0, 1, 5, 4], const Color(0xFF4FC3FF)),
      Face3([2, 3, 4, 5], const Color(0xFF2A7FC0)),
      Face3([0, 4, 3], const Color(0xFF3399DD)),
      Face3([1, 2, 5], const Color(0xFF3399DD)),
      Face3([0, 3, 2, 1], const Color(0xFF2A7FC0)),
    ], fixWinding: true);
    _pine = Mesh.merge([
      (Mesh.cylinder(.2, .8, const Color(0xFF7A5238), seg: 5), const V3(0, .4, 0)),
      (Mesh.cone(1.2, 1.8, const Color(0xFF2E8B67), seg: 6), const V3(0, 1.6, 0)),
      (Mesh.cone(.9, 1.4, const Color(0xFF3AA178), seg: 6), const V3(0, 2.4, 0)),
      (Mesh.cone(.5, .9, const Color(0xFFF2FAFF), seg: 6), const V3(0, 3.05, 0)),
    ]);
    _post = Mesh.cylinder(.28, 5, const Color(0xFFE8304A), seg: 6);
    _banner = Mesh.box(11, 1.4, .3, const Color(0xFF1B1530),
        colors: const [Pal.yellow, Pal.yellow, Color(0xFF1B1530), Color(0xFF1B1530), Pal.yellow, Pal.yellow]);
    _flag = Mesh.box(.8, .5, .05, Pal.yellow);
    _buildCourse();
    for (var i = 0; i < 40; i++) {
      _flakes.add([rand(0, 360), rand(0, 640), rand(1.5, 3.5), rand(20, 60)]);
    }
  }

  void _buildCourse() {
    var z = 16.0;
    var k = 0;
    while (z < _len - 14) {
      final pattern = k % 4;
      final lane = rand(-2.6, 2.6);
      if (pattern == 3 && z > 40) {
        // ramp with airborne fish arc
        _objs.add(_Obj(_Kind.ramp, z, lane));
        for (var i = 0; i < 5; i++) {
          final u = (i + 1) / 6;
          _objs.add(_Obj(_Kind.fish, z + 4 + i * 2.2, lane, h: 1.2 + sin(u * pi) * 2.6));
        }
        z += 18;
      } else {
        // a line / wiggle of fish
        final wig = rand(1.2, 2.4) * (chance(.5) ? 1 : -1);
        for (var i = 0; i < 5; i++) {
          _objs.add(_Obj(_Kind.fish, z + i * 2.2, (lane + sin(i * .8) * wig).clamp(-3.4, 3.4)));
        }
        z += 13;
      }
      // obstacles: dodge-able, never on the fish line center
      final nObs = z < 60 ? 1 : 2;
      for (var i = 0; i < nObs; i++) {
        var ox = rand(-3.4, 3.4);
        if ((ox - lane).abs() < 1.6) ox = lane + (ox >= lane ? 1.8 : -1.8);
        _objs.add(_Obj(chance(.5) ? _Kind.seal : _Kind.rock, z + rand(-2, 3), ox.clamp(-3.6, 3.6),
            rot: rand(0, 6), size: rand(.8, 1.15)));
      }
      z += rand(6, 10);
      k++;
    }
    // decor trees
    for (var tz = 0.0; tz < _len + 60; tz += rand(3, 6)) {
      _objs.add(_Obj(_Kind.tree, tz, (chance(.5) ? 1 : -1) * rand(6.2, 10), size: rand(.8, 1.4)));
    }
  }

  // ------------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    _downX = p.dx;
    _lxAtDown = _lxTarget;
    _touched = true;
  }

  @override
  void onMove(Offset p) {
    _lxTarget = (_lxAtDown + (p.dx - _downX) * .04).clamp(-_halfW + .6, _halfW - .6);
  }

  @override
  void onKey(String key, bool down) {
    if (key == 'left') _keyDir = down ? -1 : (_keyDir == -1 ? 0 : _keyDir);
    if (key == 'right') _keyDir = down ? 1 : (_keyDir == 1 ? 0 : _keyDir);
    if (down) _touched = true;
  }

  // ------------------------------------------------------------ update ---

  @override
  void update(double dt) {
    _t += dt;
    _fishPop = M.approach(_fishPop, 0, 6, dt);
    for (final f in _flakes) {
      f[1] += f[3] * dt;
      f[0] += sin(_t + f[2]) * 10 * dt;
      if (f[1] > 650) {
        f[1] = -10;
        f[0] = rand(0, 360);
      }
    }
    if (_done) {
      _endT += dt;
      _v = M.approach(_v, 0, 1.2, dt);
      _s += _v * dt;
      if (_won) _py = (sin(_endT * 9).abs()) * 1.2;
      return;
    }
    if (_keyDir != 0) _lxTarget = (_lxTarget + _keyDir * 9 * dt).clamp(-_halfW + .6, _halfW - .6);
    final target = (13 + host.time * 1.35).clamp(0, 31) * host.speed;
    _v = M.approach(_v, _stun > 0 ? target * .45 : target, 2, dt);
    _stun = max(0, _stun - dt);
    _spin = M.approach(_spin, 0, 5, dt);
    _s += _v * dt;
    final prev = _lx;
    _lx = M.approach(_lx, _lxTarget, 9, dt);
    _lean = M.approach(_lean, ((_lx - prev) / max(dt, 1e-4)) * -.06, 10, dt).clamp(-.5, .5);
    _flap += dt * (8 + _v * .4);
    // jump physics
    if (_py > 0 || _vy > 0) {
      _vy -= 24 * dt;
      _py += _vy * dt;
      if (_py <= 0) {
        _py = 0;
        _vy = 0;
        host.sfx(Sfx.land, volume: .7);
        host.shake(3);
        final sp = _screenOfPenguin();
        if (sp != null) host.fx.smoke(sp, count: 8, color: const Color(0xDDFFFFFF), size: 18);
      }
    }
    for (final o in _objs) {
      if (o.gone || o.kind == _Kind.tree) continue;
      final dz = o.z - _s;
      if (dz < -2 || dz > 2) continue;
      final dx = o.x - _lx;
      switch (o.kind) {
        case _Kind.fish:
          if (dz.abs() < 1.1 && dx.abs() < 1.15 && (o.h - _py).abs() < 1.4) {
            o.gone = true;
            _fish++;
            _fishPop = 1;
            final sp = scene.cam.project(_world(o.z, o.x, o.h + .5));
            host.sfx(Sfx.coin, rate: 1 + min(_fish, 20) * .03);
            if (sp != null) {
              host.fx.sparkle(sp, count: 5, radius: 18, color: Pal.yellow);
              host.fx.pop('+1', sp, color: Pal.orange, size: 22, life: .5);
            }
            host.addScore(10);
            if (_fish == _need) {
              host.fx.pop(host.tr('nice', 'NICE!'), const Offset(180, 200), color: Pal.lime, size: 34);
              host.sfx(Sfx.levelup);
            }
          }
        case _Kind.ramp:
          if (dz > -.3 && dz < 1.2 && dx.abs() < 1.5 && _py < .3) {
            _vy = 10.5;
            _py = .05;
            host.sfx(Sfx.jump);
            host.sfx(Sfx.whoosh, volume: .6);
            host.fx.pop(host.tr('wow', 'WOW!'), const Offset(180, 230), color: Pal.sky, size: 30);
            host.punch(.04);
          }
        case _Kind.rock:
        case _Kind.seal:
          if (dz.abs() < .9 && dx.abs() < (o.kind == _Kind.seal ? 1.1 : 1.0) * o.size && _py < .9 && _stun <= 0) {
            _hit(o);
          }
        case _Kind.tree:
          break;
      }
    }
    if (_s >= _len) _finish();
  }

  void _hit(_Obj o) {
    _stun = .9;
    _spin = pi * 4;
    o.bonk = 1;
    final lost = min(_fish, 3);
    _fish -= lost;
    host.sfx(o.kind == _Kind.seal ? Sfx.boing : Sfx.hitHeavy);
    host.sfx(Sfx.hurt, volume: .6);
    host.shake(9);
    host.hitStop(.06);
    host.flash(const Color(0xFFBFE8FF), .15);
    final sp = _screenOfPenguin() ?? const Offset(180, 470);
    host.fx.pop(host.tr('oops', 'OOPS!'), sp + const Offset(0, -70), color: Pal.red, size: 30);
    if (lost > 0) {
      host.fx.pop('-$lost', sp + const Offset(40, -30), color: Pal.orange, size: 24);
      host.fx.burst(sp, Pal.orange, count: lost * 4, speed: 300, size: 8, gravity: 700, colors: const [Pal.orange, Pal.sky]);
    }
    host.fx.burst(sp, Pal.white, count: 12, speed: 200, size: 6);
    _lxTarget = (_lxTarget + (o.x > _lx ? -1.2 : 1.2)).clamp(-_halfW + .6, _halfW - .6);
  }

  void _finish() {
    _done = true;
    final sp = const Offset(180, 260);
    if (_fish >= _need) {
      _won = true;
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.cheer, volume: .7);
      host.fx.confetti();
      host.fx.coins(sp, count: 20);
      host.fx.pop(host.tr('goal', 'GOAL!'), sp, color: Pal.yellow, size: 44, life: 1.4);
      host.win(stars: _fish >= 22 ? 3 : (_fish >= 15 ? 2 : 1));
    } else {
      host.sfx(Sfx.aww);
      host.fx.pop('$_fish / $_need', sp, color: Pal.red, size: 40, life: 1.4);
      host.lose();
    }
  }

  @override
  void onTimeUp() {
    if (!_done) {
      _finish();
    }
  }

  V3 _world(double z, double lx, [double h = 0]) => V3(_cx(z) + lx, _y(z) + h, z);

  Offset? _screenOfPenguin() => scene.cam.project(_world(_s, _lx, _py + .4));

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    _sky(c);
    final cam = scene.cam
      ..center = const Offset(180, 300)
      ..focal = 400;
    final cz = _s - 6.5;
    cam.pos = V3(_cx(cz) + _lx * .55, _y(cz) + 4.0 + _py * .35, cz);
    final lz = _s + 7;
    cam.lookAt(V3(_cx(lz) + _lx * .35, _y(lz) + .3, lz));
    // pass 1: track
    scene.clear();
    scene.add(_trackMesh());
    scene.render(c);
    // shadows
    for (final o in _objs) {
      if (o.gone || o.kind == _Kind.tree || o.kind == _Kind.ramp) continue;
      final dz = o.z - _s;
      if (dz < -3 || dz > 45) continue;
      _shadow(c, o.z, o.x, o.kind == _Kind.fish ? .35 : .9 * o.size, o.kind == _Kind.fish ? .12 : .22);
    }
    _shadow(c, _s, _lx, .75 - min(_py, 3) * .08, .3);
    // pass 2: objects
    scene.clear();
    final z0 = _s - 3, z1 = _s + 58;
    for (final o in _objs) {
      if (o.gone || o.z < z0 || o.z > z1) continue;
      final p = _world(o.z, o.x, o.h);
      switch (o.kind) {
        case _Kind.fish:
          final ph = _t * 5 + o.z;
          scene.addSprite(p + V3(0, .55 + sin(ph) * .15, 0), (cv, s, k) => _drawFish(cv, s, k, ph));
        case _Kind.rock:
          o.bonk = max(0, o.bonk - .03);
          scene.add(_rock, pos: p + const V3(0, .3, 0), rotY: o.rot, scale3: V3(o.size, o.size * .8, o.size), flash: o.bonk);
        case _Kind.seal:
          o.bonk = max(0, o.bonk - .03);
          final bob = sin(_t * 3 + o.z) * .05;
          final bp = p + V3(0, bob, 0);
          scene.add(_sealBody, pos: bp, rotY: sin(_t * 1.5 + o.z) * .3, scale: o.size, flash: o.bonk);
          scene.addSprite(bp + V3(0, .88 * o.size, -.82 * o.size), (cv, s, k) => _sealFace(cv, s, k, o.bonk > .1));
        case _Kind.ramp:
          scene.add(_ramp, pos: p, rotX: math.atan(_slope));
          scene.addSprite(p + const V3(0, .55, 1.0), (cv, s, k) {
            D.arrow(cv, s, const Offset(0, -1), k * 1.3, Pal.yellow, width: k * .35);
          });
        case _Kind.tree:
          scene.add(_pine, pos: p + V3(0, (o.x.abs() - _halfW) * .45, 0), scale: o.size, rotY: o.z);
      }
    }
    // goal arch
    if (_len - _s < 70) {
      final gp = _world(_len, 0);
      scene.add(_post, pos: gp + const V3(-5.6, 2.5, 0));
      scene.add(_post, pos: gp + const V3(5.6, 2.5, 0));
      scene.add(_banner, pos: gp + const V3(0, 4.6, 0));
      for (var i = 0; i < 6; i++) {
        scene.add(_flag, pos: gp + V3(-4.5 + i * 1.8, 3.6 + sin(_t * 6 + i) * .05, 0), rotY: sin(_t * 5 + i) * .4);
      }
      scene.addSprite(gp + const V3(0, 4.6, -.3), (cv, s, k) {
        D.text(cv, host.tr('goal', 'GOAL'), s, size: (k * 1.1).clamp(6, 60), color: Pal.ink);
      });
    }
    // penguin
    final pp = _world(_s, _lx, _py);
    scene.add(_penguin,
        pos: pp,
        rotX: math.atan(_slope) * .5 - (_vy * .03).clamp(-.3, .3),
        rotZ: _lean + sin(_flap) * .06,
        rotY: _spin + (_done && _won ? _endT * 5 : 0),
        flash: _stun > .6 ? .6 : 0);
    // flapping feet splash
    if (_py <= 0 && !_done && ((_t * 20).floor() != ((_t - .016) * 20).floor())) {
      final sp = cam.project(pp + const V3(0, .1, -.9));
      if (sp != null) {
        host.fx.add(Particle(pos: sp + Offset(rand(-8, 8), 0), vel: Offset(rand(-60, 60), rand(-40, 10)), life: .4,
            color: const Color(0xCCFFFFFF), size: rand(3, 6), drag: 2));
      }
    }
    scene.render(c);
    // speed lines
    if (_v > 22 && !_done) {
      final a = ((_v - 22) / 10).clamp(0.0, 1.0);
      for (var i = 0; i < 10; i++) {
        final ang = i * 2.39 + (_t * 3).floor();
        final r0 = 170 + (i * 37 % 60).toDouble();
        final o = Offset(180 + cos(ang) * r0, 330 + sin(ang) * r0 * 1.5);
        final o2 = Offset(180 + cos(ang) * (r0 + 80), 330 + sin(ang) * (r0 + 80) * 1.5);
        c.drawLine(o, o2, D.stroke(Color.fromRGBO(255, 255, 255, .35 * a), 3));
      }
    }
    for (final f in _flakes) {
      c.drawCircle(Offset(f[0], f[1]), f[2], Paint()..color = const Color(0xCCFFFFFF));
    }
    _hud(c);
  }

  void _shadow(Canvas c, double z, double lx, double r, double a) {
    final cam = scene.cam;
    final p = cam.project(_world(z, lx, .02));
    if (p == null) return;
    final k = cam.scaleAt(_world(z, lx));
    c.drawOval(Rect.fromCenter(center: p, width: r * 2 * k, height: r * .8 * k), Paint()..color = Color.fromRGBO(40, 90, 140, a));
  }

  Mesh _trackMesh() {
    final verts = <V3>[];
    final faces = <Face3>[];
    const xs = [-11.0, -7.0, -_halfW, -1.5, 1.5, _halfW, 7.0, 11.0];
    const hs = [4.2, 1.6, 0.0, 0.0, 0.0, 0.0, 1.6, 4.2];
    final zStart = (_s / 2).floor() * 2.0 - 6;
    const rows = 34;
    for (var r = 0; r <= rows; r++) {
      final z = zStart + r * 2;
      final cx = _cx(z), y = _y(z);
      for (var i = 0; i < xs.length; i++) {
        verts.add(V3(cx + xs[i], y + hs[i], z));
      }
    }
    const n = 8;
    for (var r = 0; r < rows; r++) {
      final zi = ((zStart / 2).round() + r);
      final stripe = zi.isEven;
      for (var i = 0; i < n - 1; i++) {
        final a = r * n + i;
        Color col;
        if (i == 0 || i == 6) {
          col = stripe ? const Color(0xFFF4FAFF) : const Color(0xFFEAF4FC);
        } else if (i == 1 || i == 5) {
          col = stripe ? const Color(0xFFDDEFFC) : const Color(0xFFD2E8F8);
        } else {
          final edge = i == 2 || i == 4;
          col = edge
              ? (stripe ? const Color(0xFFA6DDF7) : const Color(0xFF94D2F0))
              : (stripe ? const Color(0xFFBDE8FA) : const Color(0xFFB0E0F5));
          if (zi % 12 == 0) col = const Color(0xFF7CC6EA);
        }
        faces.add(Face3([a, a + 1, a + n + 1, a + n], col));
      }
    }
    return Mesh(verts, faces, doubleSided: true);
  }

  void _sky(Canvas c) {
    D.gradientBg(c, const [Color(0xFF7CC4F5), Color(0xFFBFE4FA), Color(0xFFE8F6FF)]);
    c.drawCircle(const Offset(290, 110), 34, Paint()..color = const Color(0xFFFFF3C4));
    c.drawCircle(const Offset(290, 110), 50, Paint()..color = const Color(0x33FFF3C4));
    final sway = _lx * 4;
    void mountains(double base, double h, Color col, Color cap, double seed) {
      final p = Path()..moveTo(-10, 400);
      final caps = Path();
      for (var i = 0; i <= 6; i++) {
        final x = -20 + i * 70.0 - sway * (seed * .5) + (seed * 30) % 70;
        final peak = base - h * (.6 + .4 * sin(i * 2.1 + seed));
        p
          ..lineTo(x - 35, base)
          ..lineTo(x, peak);
        caps
          ..moveTo(x - 12, peak + 18)
          ..lineTo(x, peak)
          ..lineTo(x + 12, peak + 18)
          ..lineTo(x + 4, peak + 13)
          ..lineTo(x - 3, peak + 19)
          ..close();
      }
      p
        ..lineTo(400, base)
        ..lineTo(400, 400)
        ..close();
      c.drawPath(p, Paint()..color = col);
      c.drawPath(caps, Paint()..color = cap);
    }

    mountains(210, 90, const Color(0xFFA9CBE8), const Color(0xFFF4FAFF), 1);
    mountains(236, 60, const Color(0xFF8FB8DC), const Color(0xFFEAF4FF), 2.7);
    c.drawRect(const Rect.fromLTWH(0, 234, 360, 200), Paint()..color = const Color(0xFFE4F4FF));
  }

  void _drawFish(Canvas c, Offset s, double k, double ph) {
    final sz = (k * .55).clamp(3.0, 40.0);
    c.save();
    c.translate(s.dx, s.dy);
    c.scale(cos(ph * .6).abs() * .7 + .3, 1);
    final body = Path()
      ..moveTo(-sz, 0)
      ..quadraticBezierTo(0, -sz * .75, sz * .9, 0)
      ..quadraticBezierTo(0, sz * .75, -sz, 0)
      ..close();
    final tail = Path()
      ..moveTo(-sz * .8, 0)
      ..lineTo(-sz * 1.45, -sz * .5)
      ..lineTo(-sz * 1.45, sz * .5)
      ..close();
    c.drawCircle(Offset.zero, sz * 1.3, Paint()..color = const Color(0x33FFE070));
    c.drawPath(tail, D.fill(const Color(0xFFFF7A1F)));
    c.drawPath(body, D.fill(const Color(0xFFFF9A3D)));
    c.drawPath(Path()
      ..moveTo(-sz * .5, sz * .1)
      ..quadraticBezierTo(0, sz * .5, sz * .7, sz * .1), D.fill(const Color(0xFFFFD27A)));
    c.drawPath(body, D.stroke(Pal.ink, max(1, sz * .1)));
    c.drawCircle(Offset(sz * .45, -sz * .12), sz * .14, D.fill(Pal.ink));
    c.restore();
  }

  void _sealFace(Canvas c, Offset s, double k, bool hurt) {
    final r = k * .38;
    if (r < 2) return;
    D.face(c, s, r, hurt ? Face.dead : Face.smug, blush: true);
    final p = D.stroke(const Color(0xAA1B1530), max(1, r * .05));
    for (final sx in const [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        final o = s + Offset(sx * r * .25, r * .3);
        c.drawLine(o, o + Offset(sx * r * .7, (i - 1) * r * .18), p);
      }
    }
    c.drawCircle(s + Offset(0, r * .22), r * .12, D.fill(Pal.ink));
  }

  void _hud(Canvas c) {
    // fish counter
    final ok = _fish >= _need;
    D.rrect(c, const Rect.fromLTWH(14, 50, 150, 46), 23, const Color(0xDDFFFFFF), border: Pal.ink, borderWidth: 3);
    _drawFish(c, const Offset(46, 73), 34, 0);
    c.save();
    c.translate(112, 73);
    c.scale(1 + _fishPop * .35);
    D.text(c, '$_fish/$_need', Offset.zero, size: 26, color: ok ? const Color(0xFF1FA85A) : Pal.ink);
    c.restore();
    // progress
    final prog = (_s / _len).clamp(0.0, 1.0);
    const r = Rect.fromLTWH(186, 64, 150, 16);
    D.bar(c, r, prog, Pal.sky, back: const Color(0x55305070), border: Pal.ink);
    c.drawCircle(Offset(r.left + r.width * prog, r.center.dy), 9, D.fill(const Color(0xFF232A3D)));
    c.drawCircle(Offset(r.left + r.width * prog, r.center.dy + 2), 5, D.fill(Pal.white));
    D.text(c, host.tr('goal', 'GOAL'), Offset(r.right - 2, r.bottom + 12), size: 11, color: Pal.ink, anchor: Alignment.topRight);
    if (!_touched && host.time < 3) {
      final x = 180 + sin(_t * 3) * 70;
      D.hand(c, Offset(x, 540), _t);
      D.arrow(c, const Offset(110, 520), const Offset(-1, 0), 50, Pal.yellow, width: 9);
      D.arrow(c, const Offset(250, 520), const Offset(1, 0), 50, Pal.yellow, width: 9);
      D.text(c, host.tr('drag', 'DRAG'), const Offset(180, 600), size: 22, color: Pal.white, stroke: Pal.ink, strokeWidth: 5);
    }
  }
}

enum _Kind { fish, rock, seal, ramp, tree }

class _Obj {
  _Obj(this.kind, this.z, this.x, {this.h = 0, this.rot = 0, this.size = 1});
  final _Kind kind;
  final double z, x, h, rot, size;
  bool gone = false;
  double bonk = 0;
}

Mesh _sc(Mesh m, double sx, double sy, double sz) =>
    Mesh([for (final v in m.verts) V3(v.x * sx, v.y * sy, v.z * sz)], [for (final f in m.faces) Face3(List.of(f.idx), f.color)],
        fixWinding: true);

Mesh _rx(Mesh m, double a) {
  final c = math.cos(a), s = math.sin(a);
  return Mesh([for (final v in m.verts) V3(v.x, v.y * c - v.z * s, v.y * s + v.z * c)],
      [for (final f in m.faces) Face3(List.of(f.idx), f.color)],
      fixWinding: true);
}
