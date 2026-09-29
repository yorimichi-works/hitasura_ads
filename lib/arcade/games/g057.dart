import '../engine/engine.dart';

/// No.057 Bumper Sumo — 3D floating sumo ring. Drag to roll your bumper
/// ball (virtual joystick), quick-tap to DASH. Knock the 3 CPU balls off the
/// edge; the ring crumbles smaller over time. Last one on the ring wins.
class G057 extends MiniGame {
  static const _r = .62; // ball radius
  static const _bands = 5;
  static const _seg = 20;

  final _scene = Scene3();
  final _ballScene = Scene3();
  final List<_Tile> _tiles = [];
  late final List<Mesh> _skirts; // by edge radius index
  late final List<Mesh> _undersides;
  late final List<Mesh> _balls;
  final _b = List.generate(4, (i) => _Ball(i));
  double _edge = 5.0;
  int _shrinkStage = 0;
  double _warn = 0;
  double _t = 0;

  // input
  Offset? _anchor;
  Offset _stick = Offset.zero; // -1..1
  double _downAt = 0;
  bool _dragged = false;
  int _kx = 0, _ky = 0;
  double _dashCd = 0;

  static const _shrinkAt = [7.5, 13.5];

  @override
  void init() {
    for (final s in [_scene, _ballScene]) {
      s.light = const V3(-.5, 1, -.6).normalized;
      s.ambient = .55;
      s.diffuse = .55;
    }
    // ring tiles: concentric bands of quads (keeps painter's sort happy)
    for (var b = 0; b < _bands; b++) {
      final r0 = b.toDouble(), r1 = b + 1.0;
      for (var s = 0; s < _seg; s++) {
        final a0 = s * 2 * pi / _seg, a1 = (s + 1) * 2 * pi / _seg;
        Color col;
        if (b == _bands - 1) {
          col = s.isEven ? const Color(0xFFE8C07A) : const Color(0xFFDDB36A);
        } else if (b == 3) {
          col = const Color(0xFFF7F1E1); // rope ring
        } else {
          col = (b + s).isEven ? const Color(0xFFEFD39A) : const Color(0xFFE9CB8E);
        }
        if (b == 0 && s % 5 == 0) col = const Color(0xFFD9B878);
        final verts = <V3>[
          V3(cos(a0) * r0, 0, sin(a0) * r0),
          V3(cos(a1) * r0, 0, sin(a1) * r0),
          V3(cos(a1) * r1, 0, sin(a1) * r1),
          V3(cos(a0) * r1, 0, sin(a0) * r1),
        ];
        final mesh = b == 0
            ? Mesh([verts[0], verts[2], verts[3]], [Face3([0, 1, 2], col)], doubleSided: true)
            : Mesh(verts, [Face3([0, 1, 2, 3], col)], doubleSided: true);
        _tiles.add(_Tile(mesh, b, (a0 + a1) / 2));
      }
    }
    _skirts = [for (final r in [5.0, 4.0, 3.0]) _skirt(r)];
    _undersides = [for (final r in [5.0, 4.0, 3.0]) _cone(r)];
    _balls = [
      for (var i = 0; i < 4; i++)
        Mesh.sphere(_r, _Cast.col[i], lat: 6, lon: 10, stripe: Color.lerp(_Cast.col[i], Pal.white, .55)),
    ];
    const starts = [V3(0, 0, -2.6), V3(2.6, 0, 0), V3(0, 0, 2.6), V3(-2.6, 0, 0)];
    for (var i = 0; i < 4; i++) {
      _b[i].x = starts[i].x;
      _b[i].z = starts[i].z;
      _b[i].think = rand(.2, .6);
    }
  }

  Mesh _skirt(double r) {
    final v = <V3>[];
    final f = <Face3>[];
    for (var s = 0; s < _seg; s++) {
      final a = s * 2 * pi / _seg;
      v.add(V3(cos(a) * r, 0, sin(a) * r));
      v.add(V3(cos(a) * r * .96, -.9, sin(a) * r * .96));
    }
    for (var s = 0; s < _seg; s++) {
      final n = (s + 1) % _seg;
      f.add(Face3([s * 2, n * 2, n * 2 + 1, s * 2 + 1], s.isEven ? const Color(0xFFB5703A) : const Color(0xFFA8652F)));
    }
    return Mesh(v, f, fixWinding: true);
  }

  Mesh _cone(double r) {
    final v = <V3>[];
    final f = <Face3>[];
    for (var s = 0; s < _seg; s++) {
      final a = s * 2 * pi / _seg;
      v.add(V3(cos(a) * r * .96, -.9, sin(a) * r * .96));
      v.add(V3(cos(a) * r * .55, -2.2, sin(a) * r * .55));
    }
    final tip = v.length;
    v.add(const V3(0, -4.2, 0));
    for (var s = 0; s < _seg; s++) {
      final n = (s + 1) % _seg;
      f.add(Face3([s * 2, n * 2, n * 2 + 1, s * 2 + 1], s % 3 == 0 ? const Color(0xFF4FAE5A) : const Color(0xFF7A5A44)));
      f.add(Face3([s * 2 + 1, n * 2 + 1, tip], const Color(0xFF5E4636)));
    }
    return Mesh(v, f, fixWinding: true);
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _dashCd = max(0, _dashCd - dt);

    // ring shrink schedule
    if (_shrinkStage < _shrinkAt.length) {
      final at = _shrinkAt[_shrinkStage];
      _warn = host.time > at - 1.6 ? 1 : 0;
      if (host.time >= at) {
        final band = _bands - 1 - _shrinkStage;
        for (final t in _tiles) {
          if (t.band == band) {
            t.falling = true;
            t.vy = -rand(0, 2);
            t.spin = rand(-2, 2);
          }
        }
        _shrinkStage++;
        _edge = (_bands - _shrinkStage).toDouble();
        _warn = 0;
        host.sfx(Sfx.crack);
        host.sfx(Sfx.crash, volume: .6);
        host.shake(8);
        host.fx.pop(host.tr('danger', 'DANGER!'), const Offset(180, 150), color: Pal.red, size: 30);
      }
    }
    for (final t in _tiles) {
      if (t.falling) {
        t.vy -= 14 * dt;
        t.y += t.vy * dt;
        t.rot += t.spin * dt;
      }
    }

    // player control
    final me = _b[0];
    var sx = _stick.dx, sz = -_stick.dy;
    if (_kx != 0 || _ky != 0) {
      sx = _kx.toDouble();
      sz = _ky.toDouble();
    }
    if (!me.falling && !host.finished) {
      me.ax = sx * 15;
      me.az = sz * 15;
      if (sx * sx + sz * sz > .04) {
        final l = sqrt(sx * sx + sz * sz);
        me.fx = sx / l;
        me.fz = sz / l;
      }
    } else {
      me.ax = me.az = 0;
    }

    // CPU brains
    for (var i = 1; i < 4; i++) {
      final b = _b[i];
      if (b.out || b.falling) continue;
      b.think -= dt;
      if (b.think <= 0) {
        b.think = rand(.15, .35);
        _cpuPlan(b);
      }
      final acc = (i == 3 ? 8.5 : (i == 1 ? 11.0 : 10.0)) * sqrt(host.speed);
      b.ax = b.dx * acc;
      b.az = b.dz * acc;
      b.dashCd = max(0, b.dashCd - dt);
      // CPUs dash too, when lined up close to a target
      if (b.dashCd <= 0 && b.target >= 0) {
        final t = _b[b.target];
        final d = sqrt(pow(t.x - b.x, 2) + pow(t.z - b.z, 2));
        if (d < 2.2 && chance(dt * 1.5)) {
          b.vx += b.dx * 5;
          b.vz += b.dz * 5;
          b.dashCd = 2.2;
          b.dashFx = 1;
          host.sfx(Sfx.whoosh, volume: .4, rate: 1.2);
        }
      }
    }

    // integrate
    for (final b in _b) {
      if (b.out) continue;
      b.dashFx = max(0, b.dashFx - dt * 3);
      b.hit = max(0, b.hit - dt * 4);
      if (b.falling) {
        b.vy -= 22 * dt;
        b.y += b.vy * dt;
        b.x += b.vx * dt;
        b.z += b.vz * dt;
        if (b.y < -9) {
          b.out = true;
          if (b.id == 0) {
            host.lose();
          } else {
            _checkWin();
          }
        }
        continue;
      }
      b.vx += b.ax * dt;
      b.vz += b.az * dt;
      final drag = exp(-1.3 * dt);
      b.vx *= drag;
      b.vz *= drag;
      final sp = sqrt(b.vx * b.vx + b.vz * b.vz);
      const maxSp = 9.0;
      if (sp > maxSp) {
        b.vx *= maxSp / sp;
        b.vz *= maxSp / sp;
      }
      b.x += b.vx * dt;
      b.z += b.vz * dt;
      b.rollX += b.vz * dt / _r;
      b.rollZ -= b.vx * dt / _r;
      final dist = sqrt(b.x * b.x + b.z * b.z);
      if (dist > _edge + .15) {
        b.falling = true;
        b.vy = 1.5;
        host.sfx(Sfx.whoosh, rate: .7);
        if (b.id == 0) {
          host.shake(6);
          host.sfx(Sfx.aww, volume: .7);
        } else {
          host.sfx(Sfx.cheer, volume: .5);
          final p = _scene.cam.project(V3(b.x, 0, b.z)) ?? const Offset(180, 300);
          host.fx.pop(host.tr('out', 'OUT!'), p + const Offset(0, -40), color: Pal.yellow, size: 32);
          host.fx.burst(p, _Cast.col[b.id], count: 14, speed: 200);
          host.addScore(100, p);
        }
      }
    }

    // collisions (bouncy!)
    for (var i = 0; i < 4; i++) {
      for (var j = i + 1; j < 4; j++) {
        final a = _b[i], c = _b[j];
        if (a.out || c.out || a.falling || c.falling) continue;
        final dx = c.x - a.x, dz = c.z - a.z;
        final d = sqrt(dx * dx + dz * dz);
        if (d < _r * 2 && d > 1e-4) {
          final nx = dx / d, nz = dz / d;
          final overlap = _r * 2 - d;
          a.x -= nx * overlap / 2;
          a.z -= nz * overlap / 2;
          c.x += nx * overlap / 2;
          c.z += nz * overlap / 2;
          final rel = (a.vx - c.vx) * nx + (a.vz - c.vz) * nz;
          if (rel > 0) {
            const e = 1.45; // extra bouncy
            final imp = rel * (1 + e) / 2 + 1.2;
            a.vx -= nx * imp;
            a.vz -= nz * imp;
            c.vx += nx * imp;
            c.vz += nz * imp;
            a.hit = c.hit = 1;
            final strength = (rel / 8).clamp(.2, 1.0);
            host.sfx(strength > .6 ? Sfx.hitHeavy : Sfx.bounce, volume: .5 + strength * .5, rate: 1.1 - strength * .2);
            final mid = V3((a.x + c.x) / 2, _r, (a.z + c.z) / 2);
            final p = _scene.cam.project(mid);
            if (p != null) {
              host.fx.burst(p, Pal.white, count: (6 + strength * 12).round(), speed: 180 + strength * 200, size: 6,
                  shape: PartShape.star, colors: const [Pal.white, Pal.yellow]);
              host.fx.ring(p, Pal.white, size: 30 + strength * 40);
            }
            if (i == 0 || j == 0) {
              host.shake(3 + strength * 6);
              if (strength > .6) {
                host.hitStop(.05);
                host.punch(.03);
                if (p != null) host.fx.pop(host.tr('bump', 'BUMP!'), p + const Offset(0, -30), color: Pal.orange, size: 24);
              }
            }
          }
        }
      }
    }
  }

  void _cpuPlan(_Ball b) {
    // choose a target (red hates YOU, green hunts whoever is near the edge)
    var best = -1;
    var bestScore = -1e9;
    for (final o in _b) {
      if (o == b || o.out || o.falling) continue;
      final d = sqrt(pow(o.x - b.x, 2) + pow(o.z - b.z, 2));
      final edgeD = sqrt(o.x * o.x + o.z * o.z);
      var s = -d;
      if (b.id == 1 && o.id == 0) s += 3;
      if (b.id == 2) s += edgeD * 1.2;
      if (s > bestScore) {
        bestScore = s;
        best = o.id;
      }
    }
    b.target = best;
    var dx = 0.0, dz = 0.0;
    if (best >= 0) {
      final t = _b[best];
      // aim slightly behind the target (relative to ring centre) to push it OUT
      final te = sqrt(t.x * t.x + t.z * t.z);
      final ox = te > .1 ? t.x / te : 0.0, oz = te > .1 ? t.z / te : 0.0;
      dx = t.x - ox * .5 - b.x;
      dz = t.z - oz * .5 - b.z;
    }
    // edge fear
    final e = sqrt(b.x * b.x + b.z * b.z);
    if (e > _edge - 1.3) {
      final k = (e - (_edge - 1.3)) * (b.id == 1 ? 1.2 : 2.2);
      dx -= b.x / e * k * 2;
      dz -= b.z / e * k * 2;
    }
    if (b.id == 3 && chance(.25)) {
      dx += rand(-2, 2);
      dz += rand(-2, 2);
    }
    final l = sqrt(dx * dx + dz * dz);
    b.dx = l > 1e-3 ? dx / l : 0;
    b.dz = l > 1e-3 ? dz / l : 0;
  }

  void _checkWin() {
    if (host.finished) return;
    if (_b.skip(1).every((b) => b.out || b.falling)) {
      host.fx.confetti(count: 90);
      host.sfx(Sfx.fanfare);
      host.win(stars: host.time < 15 ? 3 : 2);
    }
  }

  @override
  void onTimeUp() {
    if (_b[0].falling || _b[0].out) {
      host.lose();
      return;
    }
    final outs = _b.skip(1).where((b) => b.out || b.falling).length;
    host.fx.confetti(count: 60);
    host.win(stars: outs >= 2 ? 2 : 1);
  }

  // ------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    _anchor = p;
    _stick = Offset.zero;
    _downAt = _t;
    _dragged = false;
  }

  @override
  void onMove(Offset p) {
    final a = _anchor;
    if (a == null) return;
    var d = p - a;
    if (d.distance > 12) _dragged = true;
    const maxR = 56.0;
    if (d.distance > maxR) d = d / d.distance * maxR;
    _stick = d / maxR;
  }

  @override
  void onUp(Offset p) {
    if (!_dragged && _t - _downAt < .25) _dash();
    _anchor = null;
    _stick = Offset.zero;
  }

  void _dash() {
    final me = _b[0];
    if (_dashCd > 0 || me.falling || me.out) return;
    _dashCd = .9;
    var fx = me.fx, fz = me.fz;
    // no direction yet? dash at the nearest rival
    if (fx == 0 && fz == 0) {
      fz = 1;
    }
    final l = sqrt(fx * fx + fz * fz);
    fx /= l;
    fz /= l;
    me.vx += fx * 7;
    me.vz += fz * 7;
    me.dashFx = 1;
    host.sfx(Sfx.whoosh, rate: 1.3);
    host.sfx(Sfx.jump, volume: .4, rate: 1.4);
    final p = _scene.cam.project(V3(me.x, _r, me.z));
    if (p != null) host.fx.smoke(p + const Offset(0, 10), count: 5);
  }

  @override
  void onKey(String key, bool down) {
    final v = down ? 1 : 0;
    switch (key) {
      case 'left':
        _kx = -v;
      case 'right':
        _kx = v;
      case 'up':
        _ky = v;
      case 'down':
        _ky = -v;
      case 'action':
        if (down) _dash();
    }
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    // sky
    D.gradientBg(c, const [Color(0xFF6EC6FF), Color(0xFFB8E6FF), Color(0xFFFFE3F1)]);
    for (var i = 0; i < 6; i++) {
      final x = (i * 83 + _t * (8 + i * 3)) % 460 - 50;
      D.cloud(c, Offset(x, 90 + (i * 71) % 380), 50 + (i % 3) * 18, color: const Color(0xAAFFFFFF));
    }
    // distant floating islands
    for (final o in const [Offset(40, 560), Offset(320, 600)]) {
      c.drawOval(Rect.fromCenter(center: o, width: 70, height: 20), D.fill(const Color(0xFF7FCB7A)));
      c.drawPath(
          Path()
            ..moveTo(o.dx - 34, o.dy)
            ..lineTo(o.dx + 34, o.dy)
            ..lineTo(o.dx, o.dy + 40)
            ..close(),
          D.fill(const Color(0xFF9C7A5C)));
    }

    final cam = _scene.cam;
    cam
      ..pos = const V3(0, 10.5, -10.2)
      ..focal = 400
      ..center = const Offset(180, 300)
      ..lookAt(const V3(0, -.4, .9));
    _ballScene.cam
      ..pos = cam.pos
      ..focal = cam.focal
      ..center = cam.center
      ..yaw = cam.yaw
      ..pitch = cam.pitch;

    _scene.clear();
    final ei = _shrinkStage.clamp(0, 2);
    _scene.add(_undersides[ei]);
    _scene.add(_skirts[ei]);
    final warnBand = _bands - 1 - _shrinkStage;
    final blink = _warn > 0 && (_t * 8).floor().isEven;
    for (final t in _tiles) {
      if (t.y < -12) continue;
      if (t.falling) {
        final r = t.band + .5;
        final cx = cos(t.ang) * r, cz = sin(t.ang) * r;
        // tumble around the tile's own centre
        _scene.add(t.mesh, pos: V3(cx * .02 * -t.y, t.y, cz * .02 * -t.y), rotX: t.rot * .3, rotZ: t.rot * .2);
      } else {
        _scene.add(t.mesh, tint: blink && t.band == warnBand ? const Color(0xFFFF8080) : null);
      }
    }
    // balls that fell behind the ring are hidden by it
    for (final b in _b) {
      if (!b.out && b.falling && b.z > 0) {
        _scene.add(_balls[b.id], pos: V3(b.x, b.y + _r, b.z), rotX: b.rollX, rotZ: b.rollZ);
      }
    }
    _scene.render(c);

    // shadows
    for (final b in _b) {
      if (b.out || b.falling) continue;
      final p = cam.project(V3(b.x, 0, b.z));
      if (p == null) continue;
      final s = cam.scaleAt(V3(b.x, 0, b.z));
      c.drawOval(Rect.fromCenter(center: p, width: s * _r * 2.1, height: s * _r * 1.1), D.fill(const Color(0x44000000)));
    }

    // balls back-to-front, each with its face
    final order = [for (final b in _b) if (!b.out && !(b.falling && b.z > 0)) b]
      ..sort((a, b) => cam.toView(V3(b.x, 0, b.z)).z.compareTo(cam.toView(V3(a.x, 0, a.z)).z));
    for (final b in order) {
      _ballScene.clear();
      final sq = 1 + b.hit * .12;
      _ballScene.add(_balls[b.id],
          pos: V3(b.x, b.y + _r, b.z),
          rotX: b.rollX,
          rotZ: b.rollZ,
          scale3: V3(sq, 1 / sq, sq),
          flash: b.hit * .5);
      _ballScene.render(c);
      final center = cam.project(V3(b.x, b.y + _r, b.z));
      if (center == null) continue;
      final px = cam.scaleAt(V3(b.x, b.y + _r, b.z)) * _r;
      final look = Offset(b.vx.clamp(-4, 4) / 4, -b.vz.clamp(-4, 4) / 4 * .6);
      var face = _Cast.face[b.id];
      if (b.falling) {
        face = Face.cry;
      } else if (b.hit > .3) {
        face = Face.shocked;
      } else if (b.dashFx > 0) {
        face = Face.angry;
      }
      final fc = center + Offset(look.dx * px * .25, -px * .15 + look.dy * px * .2);
      D.face(c, fc, px * .72, face, look: look);
      _Cast.decor(c, b.id, center, px, fc, px * .72);
      if (b.dashFx > 0) {
        c.drawCircle(center, px * (1.1 + (1 - b.dashFx) * .6),
            D.stroke(Color.fromRGBO(255, 255, 255, b.dashFx), 4));
      }
      if (b.id == 0 && !b.falling) {
        final ay = center.dy - px * 2.2 + sin(_t * 6) * 3;
        c.drawPath(
            Path()
              ..moveTo(center.dx - 9, ay)
              ..lineTo(center.dx + 9, ay)
              ..lineTo(center.dx, ay + 10)
              ..close(),
            D.fill(Pal.white));
        D.text(c, host.tr('you', 'YOU'), Offset(center.dx, ay - 10), size: 13, color: Pal.white, stroke: Pal.blue,
            strokeWidth: 4);
      }
    }

    // HUD: remaining rivals
    D.rrect(c, const Rect.fromLTWH(96, 44, 168, 38), 19, const Color(0xAA1B1530), border: Pal.white, borderWidth: 2);
    for (var i = 0; i < 4; i++) {
      final o = Offset(120 + i * 40.0, 63);
      final gone = _b[i].out || _b[i].falling;
      c.drawCircle(o, 13, D.fill(gone ? Pal.gray : _Cast.col[i]));
      c.drawCircle(o, 13, D.stroke(Pal.ink, 2));
      D.face(c, o, 10, gone ? Face.dead : _Cast.face[i], blush: false);
      if (gone) D.line(c, o + const Offset(-13, 13), o + const Offset(13, -13), Pal.red, 4);
    }
    if (_warn > 0 && (_t * 6).floor().isEven) {
      D.title(c, host.tr('danger', 'DANGER!'), const Offset(180, 118), size: 28, color: Pal.red);
    }

    // joystick
    final a = _anchor;
    if (a != null && _dragged) {
      c.drawCircle(a, 56, D.fill(const Color(0x33FFFFFF)));
      c.drawCircle(a, 56, D.stroke(const Color(0x88FFFFFF), 3));
      c.drawCircle(a + _stick * 56, 24, D.fill(const Color(0xCCFFFFFF)));
      c.drawCircle(a + _stick * 56, 24, D.stroke(Pal.blue, 4));
    }
    // dash cooldown chip
    final dc = 1 - _dashCd / .9;
    D.rrect(c, const Rect.fromLTWH(250, 590, 96, 32), 16, const Color(0xAA1B1530));
    D.bar(c, const Rect.fromLTWH(258, 610, 80, 6), dc, dc >= 1 ? Pal.lime : Pal.orange);
    D.text(c, host.tr('tap', 'TAP') == 'TAP' ? 'DASH' : host.tr('dash', 'DASH'), const Offset(298, 600), size: 12,
        color: Pal.white);
    if (host.time < 2.6) {
      final hp = Offset(180 + sin(_t * 3) * 50, 540 + cos(_t * 3) * 20);
      D.hand(c, hp, _t);
      D.text(c, host.tr('drag', 'DRAG'), const Offset(100, 600), size: 20, color: Pal.white, stroke: Pal.ink);
    }
  }
}

class _Tile {
  _Tile(this.mesh, this.band, this.ang);
  final Mesh mesh;
  final int band;
  final double ang;
  bool falling = false;
  double y = 0, vy = 0, rot = 0, spin = 0;
}

class _Ball {
  _Ball(this.id);
  final int id;
  double x = 0, z = 0, y = 0;
  double vx = 0, vz = 0, vy = 0;
  double ax = 0, az = 0;
  double fx = 0, fz = 0; // facing (player dash dir)
  double dx = 0, dz = 0; // cpu desired dir
  double rollX = 0, rollZ = 0;
  double think = 0;
  int target = -1;
  double dashCd = 1;
  double dashFx = 0;
  double hit = 0;
  bool falling = false;
  bool out = false;
}

/// Party cast colors / faces + 2D accessories drawn over a 3D ball.
abstract final class _Cast {
  static const col = [Color(0xFF3D6BFF), Color(0xFFFF3B5C), Color(0xFF2ECC71), Color(0xFFFFC21F)];
  static const face = [Face.happy, Face.angry, Face.smug, Face.sleepy];

  static void decor(Canvas c, int who, Offset center, double r, Offset fc, double fr) {
    final topY = center.dy - r * .98;
    if (who == 0) {
      D.line(c, Offset(center.dx, topY + 2), Offset(center.dx + r * .15, topY - r * .45), Pal.ink, max(1.5, r * .1));
      D.star(c, Offset(center.dx + r * .15, topY - r * .55), r * .32, Pal.yellow, border: Pal.ink);
    } else if (who == 1) {
      final tuft = Path();
      for (var k = -1; k <= 1; k++) {
        final bx = center.dx + k * r * .38;
        tuft
          ..moveTo(bx - r * .22, topY + r * .22)
          ..lineTo(bx + k * r * .12, topY - r * .4)
          ..lineTo(bx + r * .22, topY + r * .22)
          ..close();
      }
      c.drawPath(tuft, D.fill(const Color(0xFFB8173A)));
      c.drawPath(tuft, D.stroke(Pal.ink, max(1.2, r * .07)));
    } else if (who == 2) {
      final g = D.stroke(Pal.ink, max(1.2, fr * .08));
      for (final s in [-1.0, 1.0]) {
        c.drawCircle(fc + Offset(s * fr * .36, -fr * .12), fr * .28, g);
      }
      D.line(c, fc + Offset(-fr * .1, -fr * .14), fc + Offset(fr * .1, -fr * .14), Pal.ink, max(1.2, fr * .07));
    } else if (who == 3) {
      final b = Offset(center.dx + r * .55, topY + r * .28);
      final bow = Path()
        ..moveTo(b.dx, b.dy)
        ..lineTo(b.dx - r * .42, b.dy - r * .25)
        ..lineTo(b.dx - r * .42, b.dy + r * .25)
        ..close()
        ..moveTo(b.dx, b.dy)
        ..lineTo(b.dx + r * .42, b.dy - r * .25)
        ..lineTo(b.dx + r * .42, b.dy + r * .25)
        ..close();
      c.drawPath(bow, D.fill(Pal.pink));
      c.drawPath(bow, D.stroke(Pal.ink, max(1.2, r * .07)));
    }
  }
}
