import '../engine/engine.dart';

/// No.105 Paper Plane City — glide a paper plane down a sunset street.
/// Drag to steer (left/right) and pitch (up/down). The plane keeps sinking:
/// ride the wind vents, dodge ad billboards, buses and bridges, grab stars.
class G105 extends MiniGame {
  static const _goal = 330.0;
  static const _street = 4.6;

  final scene = Scene3();
  late final Mesh _plane, _ball, _grate, _bus, _billboardPost;
  final _blds = <_Bld>[];
  final _obs = <_Ob>[];
  final _stars = <_Star>[];
  final _vents = <V3>[];

  double _z = 0, _x = 0, _y = 7;
  double _vy = 0, _v = 18;
  double _pitch = 0; // -1..1 (drag)
  double _xTarget = 0;
  Offset _down = Offset.zero;
  double _xAtDown = 0;
  bool _held = false;
  double _roll = 0;
  double _t = 0;
  bool _crashed = false;
  double _crashT = 0;
  V3 _crashPos = V3.zero;
  double _crashVy = 0;
  int _starCount = 0;
  bool _won = false;
  double _inVent = 0;
  bool _touched = false;
  int _keyX = 0, _keyY = 0;

  @override
  void init() {
    scene.ambient = .6;
    scene.diffuse = .5;
    scene.light = const V3(.5, .8, -.6).normalized;
    scene.fogColor = const Color(0xFFE89AB0);
    scene.fogNear = 30;
    scene.fogFar = 80;
    const w1 = Color(0xFFFFFFFF), w2 = Color(0xFFFFD6E8), w3 = Color(0xFFFF8AB8);
    _plane = Mesh([
      const V3(0, 0, 1.3), // 0 nose
      const V3(-1.05, .18, -.9), // 1 left tip
      const V3(1.05, .18, -.9), // 2 right tip
      const V3(0, 0, -.9), // 3 tail center
      const V3(0, -.38, -.9), // 4 keel bottom
      const V3(-.18, .02, -.9), // 5 left fold
      const V3(.18, .02, -.9), // 6 right fold
    ], [
      Face3([0, 5, 1], w1),
      Face3([0, 2, 6], w1),
      Face3([0, 3, 5], w2),
      Face3([0, 6, 3], w2),
      Face3([0, 4, 3], w3),
      Face3([0, 3, 4], w3),
    ], doubleSided: true);
    _ball = Mesh.sphere(.55, const Color(0xFFF4F6FF), lat: 3, lon: 5);
    _grate = Mesh.box(2.6, .08, 2.6, const Color(0xFF3A3450),
        colors: const [Color(0xFF6BFFB8), Color(0xFF3A3450), Color(0xFF3A3450), Color(0xFF3A3450), Color(0xFF3A3450), Color(0xFF3A3450)]);
    _bus = Mesh.merge([
      (Mesh.box(2.8, 2.4, 7, const Color(0xFFFFC53D), colors: const [
        Color(0xFFFFE08A), Color(0xFF7A5A20), Color(0xFF6FC8FF), Color(0xFFFFC53D), Color(0xFFFFB020), Color(0xFFFFB020)
      ]), const V3(0, 1.6, 0)),
      (Mesh.box(2.84, .7, 6.2, const Color(0xFF6FC8FF)), const V3(0, 2.1, .2)),
      (Mesh.box(2.9, .3, 7.05, const Color(0xFFE8304A)), const V3(0, .9, 0)),
      (Mesh.cylinder(.45, 3.0, const Color(0xFF222233), seg: 6), const V3(0, .45, -2.2)),
      (Mesh.cylinder(.45, 3.0, const Color(0xFF222233), seg: 6), const V3(0, .45, 2.2)),
    ]);
    _billboardPost = Mesh.box(.25, 1, .25, const Color(0xFF5A5470));
    _buildCity();
  }

  static const _bldCols = [
    Color(0xFF8C6AD8), Color(0xFF6A7FE0), Color(0xFFE08AB8), Color(0xFFF2A488), Color(0xFF5DB5C8), Color(0xFFB07AE0),
  ];

  void _buildCity() {
    for (final side in const [-1, 1]) {
      var z = -10.0;
      while (z < _goal + 90) {
        final d = rand(5, 10), w = rand(5, 9), h = rand(8, 24);
        final col = pick(_bldCols);
        _blds.add(_Bld(side, z + d / 2, w, h, d, _buildingMesh(w, h, d, col)));
        z += d + (chance(.22) ? rand(4, 7) : rand(.3, 1.2));
      }
    }
    var z = 38.0;
    var k = 0;
    while (z < _goal - 10) {
      final type = k < 1 ? 0 : randInt(3);
      switch (type) {
        case 0: // billboard hanging over one half, high
          final side = chance(.5) ? -1.0 : 1.0;
          final bottom = rand(3.6, 5.0);
          _obs.add(_Ob(_ObT.billboard, V3(side * 2.4, bottom, z), 2.6, bottom + 3.2, pick(Pal.candy)));
          // stars guide to the free half, low
          for (var i = 0; i < 4; i++) {
            _stars.add(_Star(V3(-side * 2.3, bottom - 1.4, z - 8 + i * 3.0)));
          }
          _vents.add(V3(-side * 2.3, 0, z + 12));
        case 1: // bus in a lane
          final lx = (chance(.5) ? -1.0 : 1.0) * rand(1.4, 2.6);
          _obs.add(_Ob(_ObT.bus, V3(lx, 0, z), 1.6, 3.0, Pal.yellow));
          _vents.add(V3(-lx * .9, 0, z - 14));
          for (var i = 0; i < 4; i++) {
            _stars.add(_Star(V3(-lx * .9, 4 + i * .8, z - 12 + i * 2.5)));
          }
        default: // pedestrian bridge full width
          final b = rand(3.4, 4.8);
          _obs.add(_Ob(_ObT.bridge, V3(0, b, z), 6, b + 1.1, const Color(0xFF6E6A9A)));
          final vx = rand(-2.5, 2.5);
          _vents.add(V3(vx, 0, z - 16));
          for (var i = 0; i < 3; i++) {
            _stars.add(_Star(V3(vx * .5, b - 1.3, z - 3 + i * 3.0)));
          }
      }
      z += rand(24, 30) / (1 + k * .02);
      k++;
    }
    _vents.insert(0, const V3(0, 0, 22));
  }

  Mesh _buildingMesh(double w, double h, double d, Color col) {
    final v = <V3>[];
    final f = <Face3>[];
    final dark = Color.lerp(col, const Color(0xFF2A1840), .35)!;
    final top = Color.lerp(col, Pal.white, .25)!;
    int add(V3 p) {
      v.add(p);
      return v.length - 1;
    }

    final x0 = -w / 2, x1 = w / 2, z0 = -d / 2, z1 = d / 2;
    // box without the facade (x0 side)
    final a = add(V3(x0, 0, z0)), b = add(V3(x1, 0, z0)), c = add(V3(x1, h, z0)), dd = add(V3(x0, h, z0));
    final e = add(V3(x0, 0, z1)), ff = add(V3(x1, 0, z1)), g = add(V3(x1, h, z1)), hh = add(V3(x0, h, z1));
    f
      ..add(Face3([dd, c, g, hh], top))
      ..add(Face3([a, b, c, dd], col))
      ..add(Face3([ff, e, hh, g], col))
      ..add(Face3([b, ff, g, c], dark));
    // facade (faces -x): per floor a wall band + a row of windows between piers
    final nw = max(2, (d / 2.2).round());
    final floorH = 1.9;
    final floors = max(3, (h / floorH).floor());
    final fh = h / floors;
    void quad(double ya, double yb, double za, double zb, Color cc) {
      final q0 = add(V3(x0, ya, za)), q1 = add(V3(x0, yb, za)), q2 = add(V3(x0, yb, zb)), q3 = add(V3(x0, ya, zb));
      f.add(Face3([q0, q1, q2, q3], cc));
    }

    final lit = [const Color(0xFFFFD27A), const Color(0xFFFFE7A8), const Color(0xFF7AE8FF), const Color(0xFFFF9AD0)];
    final wall = Color.lerp(col, const Color(0xFF3A2A60), .1)!;
    final pier = d / (nw * 3 + 1);
    for (var j = 0; j < floors; j++) {
      final fy = j * fh;
      if (j == 0) {
        quad(fy, fy + fh, z0, z1, Color.lerp(col, Pal.ink, .45)!);
        continue;
      }
      final wy0 = fy + fh * .28, wy1 = fy + fh * .9;
      quad(fy, wy0, z0, z1, wall);
      quad(wy1, fy + fh, z0, z1, wall);
      var z = z0;
      for (var i = 0; i < nw; i++) {
        quad(wy0, wy1, z, z + pier, wall);
        z += pier;
        quad(wy0, wy1, z, z + pier * 2, chance(.6) ? pick(lit) : const Color(0xFF3B3566));
        z += pier * 2;
      }
      quad(wy0, wy1, z, z1, wall);
    }
    final m = Mesh(v, f);
    // fix normals: all faces should point outward from the center
    for (final face in m.faces) {
      var cxx = 0.0, cyy = 0.0, czz = 0.0;
      for (final i in face.idx) {
        cxx += v[i].x;
        cyy += v[i].y;
        czz += v[i].z;
      }
      final n = face.idx.length.toDouble();
      final out = V3(cxx / n, cyy / n - h / 2, czz / n);
      if (face.normal.dot(out) < 0) {
        face.idx.setAll(0, face.idx.reversed.toList());
        face.normal = -face.normal;
      }
    }
    return m;
  }

  // ------------------------------------------------------------ input ---

  @override
  void onDown(Offset p) {
    _down = p;
    _xAtDown = _xTarget;
    _held = true;
    _touched = true;
  }

  @override
  void onMove(Offset p) {
    _xTarget = (_xAtDown + (p.dx - _down.dx) * .04).clamp(-_street, _street);
    _pitch = (-(p.dy - _down.dy) / 70).clamp(-1.0, 1.0);
  }

  @override
  void onUp(Offset p) {
    _held = false;
  }

  @override
  void onKey(String key, bool down) {
    final v = down ? 1 : 0;
    switch (key) {
      case 'left':
        _keyX = -v;
      case 'right':
        _keyX = v;
      case 'up':
        _keyY = v;
      case 'down':
        _keyY = -v;
    }
    if (down) _touched = true;
  }

  // ----------------------------------------------------------- update ---

  @override
  void update(double dt) {
    _t += dt;
    if (_crashed) {
      _crashT += dt;
      _crashVy -= 18 * dt;
      _crashPos = V3(_crashPos.x, max(.55, _crashPos.y + _crashVy * dt), _crashPos.z + max(0, 3 - _crashT * 6) * dt);
      if (_crashPos.y <= .56 && _crashVy < -2) {
        _crashVy = -_crashVy * .35;
        host.sfx(Sfx.bounce, volume: .4);
      }
      return;
    }
    if (_won) {
      _z += _v * dt;
      _y += 3 * dt;
      _roll = sin(_t * 6) * .5;
      return;
    }
    if (_keyX != 0) _xTarget = (_xTarget + _keyX * 8 * dt).clamp(-_street, _street);
    if (_keyY != 0) _pitch = _keyY.toDouble();
    if (!_held && _keyY == 0) _pitch = M.approach(_pitch, 0, 3, dt);
    _v = (18 + host.time * .35) * host.speed;
    _z += _v * dt;
    final px = _x;
    _x = M.approach(_x, _xTarget, 5, dt);
    _roll = M.approach(_roll, -(_x - px) / max(dt, 1e-4) * .09, 8, dt).clamp(-.8, .8);
    // vents
    var lift = false;
    for (final vp in _vents) {
      if ((vp.z - _z).abs() < 2.4 && (vp.x - _x).abs() < 1.7 && _y < 15) lift = true;
    }
    if (lift && _inVent <= 0) {
      host.sfx(Sfx.wind, volume: .8);
      host.fx.pop(host.tr('up', 'UP!'), const Offset(180, 250), color: const Color(0xFF6BFFB8), size: 26, life: .5);
    }
    _inVent = lift ? .25 : _inVent - dt;
    final target = lift ? 7.5 : -1.15 + _pitch * .95;
    _vy = M.approach(_vy, target, lift ? 4 : 2.2, dt);
    _y = (_y + _vy * dt).clamp(-1.0, 14.0);
    if (_y < .45) {
      _crash(host.tr('oops', 'OOPS!'));
      return;
    }
    // obstacles
    for (final o in _obs) {
      final dz = o.pos.z - _z;
      if (dz.abs() > (o.type == _ObT.bus ? 3.6 : .5)) {
        if (!o.passed && dz < -3.6) {
          o.passed = true;
          host.addScore(20);
          host.sfx(Sfx.swipe, volume: .5, rate: 1.3);
        }
        continue;
      }
      var hit = false;
      switch (o.type) {
        case _ObT.billboard:
          hit = (_x - o.pos.x).abs() < o.halfW + .45 && _y > o.pos.y - .35 && _y < o.top + .3;
        case _ObT.bus:
          hit = (_x - o.pos.x).abs() < o.halfW + .4 && _y < o.top + .25;
        case _ObT.bridge:
          hit = _y > o.pos.y - .35 && _y < o.top + .3;
      }
      if (hit) {
        _crash(host.tr('crash', 'CRASH!'));
        return;
      }
    }
    for (final s in _stars) {
      if (s.got) continue;
      final d = s.p - V3(_x, _y, _z);
      if (d.z.abs() < 1.2 && d.x.abs() < 1.3 && d.y.abs() < 1.3) {
        s.got = true;
        _starCount++;
        host.sfx(Sfx.star, rate: 1 + _starCount * .04);
        final sp = scene.cam.project(s.p);
        if (sp != null) {
          host.fx.sparkle(sp, count: 7, radius: 20, color: Pal.yellow);
          host.addScore(50, sp);
        }
      }
    }
    if (_z >= _goal) {
      _won = true;
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.cheer, volume: .6);
      host.fx.confetti();
      host.fx.pop(host.tr('goal', 'GOAL!'), const Offset(180, 240), color: Pal.yellow, size: 44, life: 1.4);
      host.win(stars: _starCount >= 10 ? 3 : (_starCount >= 5 ? 2 : 1));
    }
  }

  void _crash(String word) {
    _crashed = true;
    _crashPos = V3(_x, max(.6, _y), _z);
    _crashVy = 2;
    host.sfx(Sfx.rip);
    host.sfx(Sfx.squish, rate: .7);
    host.shake(10, .35);
    host.hitStop(.08);
    host.flash(Pal.white, .15);
    final sp = scene.cam.project(_crashPos) ?? const Offset(180, 380);
    host.fx.burst(sp, Pal.white, count: 18, speed: 260, shape: PartShape.square, size: 8, gravity: 400);
    host.fx.pop(word, sp + const Offset(0, -60), color: Pal.red, size: 34, life: 1.2);
    host.lose();
  }

  @override
  void onTimeUp() {
    if (_crashed) return;
    host.win(stars: 1);
  }

  // ----------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    _sky(c);
    final cam = scene.cam
      ..center = const Offset(180, 330)
      ..focal = 380;
    final fx = _crashed ? _crashPos.x : _x, fy = _crashed ? _crashPos.y : _y;
    final fz = _crashed ? _crashPos.z : _z;
    final back = _crashed ? 5.5 + min(_crashT, 1.2) * 2 : 5.8;
    cam.pos = V3(fx * .7, fy + 1.7, fz - back);
    cam.lookAt(V3(fx * .75, fy + .2, fz + 8));
    // pass 1: street
    scene.clear();
    scene.add(_streetMesh(fz));
    for (final vp in _vents) {
      final dz = vp.z - fz;
      if (dz > -4 && dz < 70) scene.add(_grate, pos: vp + const V3(0, .05, 0));
    }
    scene.render(c);
    // pass 2: city
    scene.clear();
    for (final b in _blds) {
      final dz = b.z - fz;
      if (dz < -8 || dz > 85) continue;
      final x = b.side * (_street + 1.1 + b.w / 2);
      scene.add(b.mesh, pos: V3(x, 0, b.z), rotY: b.side > 0 ? 0 : pi);
    }
    for (final o in _obs) {
      final dz = o.pos.z - fz;
      if (dz < -6 || dz > 80) continue;
      switch (o.type) {
        case _ObT.billboard:
          final h = o.top - o.pos.y;
          scene.add(Mesh.box(o.halfW * 2, h, .35, o.color, colors: [
            o.color, o.color, Color.lerp(o.color, Pal.white, .55)!, o.color, Color.lerp(o.color, Pal.ink, .3)!, Color.lerp(o.color, Pal.ink, .3)!
          ]), pos: o.pos + V3(0, h / 2, 0));
          final postH = 14 - o.top;
          final sideX = o.pos.x.sign * (_street + 1.1);
          scene.add(Mesh.box((sideX - o.pos.x).abs(), .25, .25, const Color(0xFF5A5470)),
              pos: V3((sideX + o.pos.x) / 2, o.top + .5, o.pos.z));
          scene.add(_billboardPost, pos: V3(o.pos.x, o.top + .25, o.pos.z), scale3: V3(1, max(.1, postH * 0 + .5), 1));
          scene.addSprite(o.pos + V3(0, h / 2, -.3), (cv, s, k) => _adText(cv, s, k, o));
        case _ObT.bus:
          scene.add(_bus, pos: o.pos);
          scene.addSprite(o.pos + const V3(0, 1.7, -3.6), (cv, s, k) {
            final r = (k * .35).clamp(2.0, 40.0);
            D.text(cv, 'AD', s, size: r, color: Pal.red);
          });
        case _ObT.bridge:
          final h = o.top - o.pos.y;
          scene.add(Mesh.box(_street * 2 + 2.2, h, 1.6, o.color, colors: [
            const Color(0xFF9A96C8), const Color(0xFF4A4670), o.color, o.color, o.color, o.color
          ]), pos: o.pos + V3(0, h / 2, 0));
          scene.add(Mesh.box(_street * 2 + 2.2, .6, .12, const Color(0xFFFF8AC0)), pos: o.pos + V3(0, h + .3, -.74));
          for (var i = 0; i < 5; i++) {
            final px = -_street + i * _street / 2;
            scene.addSprite(o.pos + V3(px, h + .05, 0), (cv, s, k) => D.person(cv, s, k * 1.5, pick(Pal.candy)));
          }
      }
    }
    for (final vp in _vents) {
      final dz = vp.z - fz;
      if (dz < -4 || dz > 60) continue;
      for (var i = 0; i < 5; i++) {
        final h = ((_t * 3 + i * 2.2) % 11);
        scene.addSprite(vp + V3(sin(_t * 4 + i) * .5, h + .5, 0), (cv, s, k) {
          final a = (1 - h / 11) * .55;
          cv.drawArc(Rect.fromCenter(center: s, width: k * 1.8, height: k * .6), 0, pi * 1.4, false,
              D.stroke(Color.fromRGBO(120, 255, 190, a), max(1.5, k * .12)));
        });
      }
    }
    for (final s in _stars) {
      if (s.got) continue;
      final dz = s.p.z - fz;
      if (dz < -2 || dz > 60) continue;
      scene.addSprite(s.p, (cv, sp, k) {
        final r = (k * .5).clamp(2.0, 40.0);
        cv.drawCircle(sp, r * 1.5, Paint()..color = const Color(0x44FFE070));
        D.star(cv, sp, r, Pal.yellow, border: Pal.orange, rotation: -pi / 2 + sin(_t * 3 + s.p.z) * .3);
      });
    }
    // goal ribbon
    if (_goal - fz < 80) {
      scene.add(Mesh.box(_street * 2 + 2, .5, .1, Pal.yellow), pos: V3(0, 12, _goal));
      scene.addSprite(const V3(0, 12, _goal - .2), (cv, s, k) {
        D.text(cv, host.tr('goal', 'GOAL'), s, size: (k * .45).clamp(4, 50), color: Pal.ink);
      });
    }
    // plane / crumpled ball
    if (_crashed) {
      scene.add(_ball, pos: _crashPos, rotX: _crashT * 7, rotY: _crashT * 5, scale3: const V3(1, .85, 1.1));
    } else {
      scene.add(_plane, pos: V3(_x, _y, _z), rotZ: _roll, rotX: -_vy * .06 - _pitch * .12, rotY: _roll * -.15);
    }
    scene.render(c);
    if (!_crashed && _inVent > 0) {
      final sp = cam.project(V3(_x, _y, _z));
      if (sp != null && (_t * 30).floor().isEven) {
        host.fx.add(Particle(pos: sp + Offset(rand(-20, 20), 20), vel: Offset(0, rand(-160, -80)), life: .35,
            color: const Color(0xAA7CFFC4), size: 4, shape: PartShape.spark));
      }
    }
    _hud(c);
  }

  void _adText(Canvas c, Offset s, double k, _Ob o) {
    final size = (k * .9).clamp(3.0, 70.0);
    D.text(c, host.tr('sale', 'SALE'), s, size: size, color: Pal.white, stroke: Pal.red, strokeWidth: size * .18);
  }

  Mesh _streetMesh(double fz) {
    final verts = <V3>[];
    final faces = <Face3>[];
    const xs = [-_street - 1.1, -_street, -.15, .15, _street, _street + 1.1];
    const ys = [.2, .2, 0.0, 0.0, 0.0, .2];
    final z0 = (fz / 3).floor() * 3.0 - 9;
    const rows = 32;
    for (var r = 0; r <= rows; r++) {
      for (var i = 0; i < xs.length; i++) {
        verts.add(V3(xs[i], ys[i], z0 + r * 3));
      }
    }
    const n = 6;
    for (var r = 0; r < rows; r++) {
      final zi = (z0 / 3).round() + r;
      for (var i = 0; i < n - 1; i++) {
        final a = r * n + i;
        Color col;
        if (i == 0 || i == 4) {
          col = zi.isEven ? const Color(0xFFB9A3C8) : const Color(0xFFAE97BF);
        } else if (i == 2) {
          col = zi % 2 == 0 ? const Color(0xFFFFE08A) : const Color(0xFF4A4262);
        } else {
          col = zi.isEven ? const Color(0xFF4A4262) : const Color(0xFF463E5E);
        }
        faces.add(Face3([a, a + 1, a + n + 1, a + n], col));
      }
    }
    return Mesh(verts, faces, doubleSided: true);
  }

  void _sky(Canvas c) {
    D.gradientBg(c, const [Color(0xFF3A2A7A), Color(0xFFB45AA8), Color(0xFFFF9A8A), Color(0xFFFFD29A)]);
    // vaporwave sun
    const sc = Offset(180, 250);
    c.save();
    c.clipRect(const Rect.fromLTWH(0, 0, 360, 300));
    c.drawCircle(sc, 95, Paint()..color = const Color(0x33FFE0A0));
    c.drawCircle(sc, 72, Paint()..color = const Color(0xFFFFD27A));
    for (var i = 0; i < 5; i++) {
      c.drawRect(Rect.fromLTWH(100, 262 + i * 10.0 + (_t * 6) % 10, 160, 3 + i * .8), Paint()..color = const Color(0xFFFF9A8A));
    }
    c.restore();
    for (var i = 0; i < 5; i++) {
      final x = (i * 97.0 - _z * .3) % 480 - 60;
      D.cloud(c, Offset(x, 90 + (i * 41 % 90).toDouble()), 44 + i * 6.0, color: const Color(0x55FFE0F0));
    }
  }

  void _hud(Canvas c) {
    final prog = (_z / _goal).clamp(0.0, 1.0);
    const r = Rect.fromLTWH(40, 56, 230, 16);
    D.bar(c, r, prog, Pal.pink, back: const Color(0x55301850), border: Pal.ink);
    final px = r.left + r.width * prog;
    final tri = Path()
      ..moveTo(px + 10, r.center.dy)
      ..lineTo(px - 8, r.center.dy - 8)
      ..lineTo(px - 4, r.center.dy)
      ..lineTo(px - 8, r.center.dy + 8)
      ..close();
    c.drawPath(tri, D.fill(Pal.white));
    c.drawPath(tri, D.stroke(Pal.ink, 2));
    D.text(c, '${(_z).clamp(0, _goal).round()}m', const Offset(312, 64), size: 16, color: Pal.white, stroke: Pal.ink,
        strokeWidth: 4);
    D.star(c, const Offset(42, 98), 12, Pal.yellow, border: Pal.ink);
    D.text(c, '$_starCount', const Offset(62, 98), size: 20, color: Pal.white, stroke: Pal.ink, strokeWidth: 5,
        anchor: Alignment.centerLeft);
    // altimeter
    const ar = Rect.fromLTWH(330, 180, 12, 220);
    D.rrect(c, ar, 6, const Color(0x55301850), border: const Color(0xAAFFFFFF), borderWidth: 2);
    final ay = ar.bottom - ar.height * (_y / 14).clamp(0.0, 1.0);
    final danger = _y < 2.5 && !_crashed;
    c.drawCircle(Offset(ar.center.dx, ay), 8, D.fill(danger ? Pal.red : Pal.white));
    c.drawCircle(Offset(ar.center.dx, ay), 8, D.stroke(Pal.ink, 2));
    if (danger && (_t * 6).floor().isEven) {
      D.text(c, host.tr('danger', 'DANGER'), const Offset(180, 140), size: 24, color: Pal.red, stroke: Pal.white,
          strokeWidth: 5);
    }
    if (!_touched && host.time < 3.2) {
      final ph = (_t * 1.1) % 1;
      D.hand(c, Offset(180 + sin(_t * 2.5) * 60, 560 - ph * 40), _t);
      D.text(c, host.tr('drag', 'DRAG'), const Offset(180, 612), size: 22, color: Pal.white, stroke: Pal.ink,
          strokeWidth: 5);
    }
  }
}

class _Bld {
  _Bld(this.side, this.z, this.w, this.h, this.d, this.mesh);
  final int side;
  final double z, w, h, d;
  final Mesh mesh;
}

enum _ObT { billboard, bus, bridge }

class _Ob {
  _Ob(this.type, this.pos, this.halfW, this.top, this.color);
  final _ObT type;
  final V3 pos;
  final double halfW, top;
  final Color color;
  bool passed = false;
}

class _Star {
  _Star(this.p);
  final V3 p;
  bool got = false;
}
