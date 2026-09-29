import '../engine/engine.dart';

/// No.106 Warp Tunnel — a neon ring tunnel rushes at you. Drag sideways to
/// spin around the tunnel wall and slip through the gaps. Survive = win.
class G106 extends MiniGame {
  static const _n = 16; // sides
  static const _r = 5.0; // radius
  static const _segL = 2.6;
  static const _rings = 24;
  static const _shipZ = 4.2;
  static const _maxHp = 3;

  final scene = Scene3();
  late final Mesh _ship;
  final _obs = <_Block>[];
  final _gems = <_Gem>[];
  final _stars = <List<double>>[];

  double _d = 0; // distance travelled
  double _v = 15;
  double _theta = 0; // ship angle around tunnel (world)
  double _thetaVel = 0;
  double _bank = 0;
  double _nextSpawn = 62;
  int _hp = _maxHp;
  double _inv = 0;
  double _t = 0;
  double _downX = 0;
  bool _held = false;
  int _keyDir = 0;
  bool _touched = false;
  int _stage = 0;
  int _pattern = 0;
  bool _dead = false;
  double _deadT = 0;
  int _gemCount = 0;

  @override
  void init() {
    scene.ambient = .78;
    scene.diffuse = .35;
    scene.light = const V3(0, 1, -.4).normalized;
    scene.fogColor = const Color(0xFF12052A);
    scene.fogNear = 14;
    scene.fogFar = 58;
    const hull = Color(0xFFE8ECFF), dark = Color(0xFF5A5C9A), cyan = Color(0xFF3FF0FF), pink = Color(0xFFFF4FA8);
    _ship = Mesh.merge([
      (_rx(Mesh.cone(.42, 1.8, hull, seg: 6), pi / 2), const V3(0, 0, .3)),
      (Mesh.box(2.2, .1, .7, dark, colors: const [pink, dark, dark, dark, dark, dark]), const V3(0, -.05, -.25)),
      (Mesh.box(.12, .5, .6, pink), const V3(-1.05, .2, -.3)),
      (Mesh.box(.12, .5, .6, pink), const V3(1.05, .2, -.3)),
      (Mesh.box(.36, .22, .6, cyan), const V3(0, .28, .2)),
      (Mesh.box(.5, .4, .3, dark), const V3(0, 0, -.62)),
    ]);
    for (var i = 0; i < 60; i++) {
      _stars.add([rand(0, pi * 2), rand(0, 1), rand(.5, 1.5)]);
    }
  }

  // --------------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    _downX = p.dx;
    _held = true;
    _touched = true;
  }

  @override
  void onMove(Offset p) {
    if (!_held) return;
    final dx = p.dx - _downX;
    _downX = p.dx;
    _theta += dx * .013;
    _thetaVel = dx * .013 * 60;
  }

  @override
  void onUp(Offset p) => _held = false;

  @override
  void onKey(String key, bool down) {
    if (key == 'left') _keyDir = down ? -1 : (_keyDir == -1 ? 0 : _keyDir);
    if (key == 'right') _keyDir = down ? 1 : (_keyDir == 1 ? 0 : _keyDir);
    if (down) _touched = true;
  }

  static double _wrap(double a) {
    var x = (a + pi) % (pi * 2);
    if (x < 0) x += pi * 2;
    return x - pi;
  }

  static const _slot = pi * 2 / _n;

  // -------------------------------------------------------------- spawn ---

  void _spawnRow(double z) {
    // Gentle opening: two wide gap walls first, then the full rotation.
    final kind = _pattern < 2 ? 0 : (_pattern - 2) % 5;
    _pattern++;
    final h = rand(1.0, 1.8);
    final hue = rand(290, 360);
    switch (kind) {
      case 0: // wall with a gap near the ship
      case 3:
        final gap = _theta + (_pattern <= 2 ? rand(-1.0, 1.0) : rand(-2.0, 2.0));
        final gapSlots = host.time < 8 ? 6 : 5;
        final g0 = ((gap / _slot).round());
        for (var s = 0; s < _n; s++) {
          final rel = ((s - g0) % _n + _n) % _n;
          if (rel < gapSlots) continue;
          _obs.add(_Block(z, s * _slot, 1, h, hue));
        }
        for (var i = 0; i < 3; i++) {
          _gems.add(_Gem(z + (i - 1) * 3.0, (g0 + gapSlots / 2 - .5) * _slot));
        }
      case 1: // spiral of blocks
        final start = _theta + rand(-1, 1);
        final dir = chance(.5) ? 1 : -1;
        for (var i = 0; i < 6; i++) {
          _obs.add(_Block(z + i * 3.2, start + pi + dir * i * _slot * 1.5, 3, h, hue + i * 8));
        }
      case 2: // scattered big chunks
        for (var i = 0; i < 4; i++) {
          _obs.add(_Block(z + rand(0, 8), rand(0, pi * 2), 2 + randInt(2), h, hue));
        }
        _gems.add(_Gem(z + 4, _theta + pi));
      case 4: // twin walls (half tunnel each side)
        final a = _theta + rand(-.8, .8);
        for (var s = 0; s < _n ~/ 2 - 1; s++) {
          _obs.add(_Block(z, a + pi / 2 + (s + 1) * _slot, 1, h, hue));
        }
        for (var s = 0; s < _n ~/ 2 - 1; s++) {
          _obs.add(_Block(z + 18, a - pi / 2 + (s + 1) * _slot + pi, 1, h, hue + 30));
        }
    }
  }

  // ------------------------------------------------------------- update ---

  @override
  void update(double dt) {
    _t += dt;
    if (_dead) {
      _deadT += dt;
      _v = M.approach(_v, 0, 3, dt);
      _d += _v * dt;
      return;
    }
    final stage = host.time < 6 ? 0 : (host.time < 12 ? 1 : 2);
    if (stage != _stage) {
      _stage = stage;
      host.fx.pop(host.tr('speed_up', 'SPEED UP!'), const Offset(180, 200), color: const Color(0xFF3FF0FF), size: 34);
      host.sfx(Sfx.powerup);
      host.flash(const Color(0xFF8C4DFF), .2);
      host.punch(.05);
    }
    _v = (15 + host.time * 1.5 + _stage * 2.5) * host.speed;
    _d += _v * dt;
    if (_keyDir != 0) {
      _theta += _keyDir * 3.6 * dt;
      _thetaVel = _keyDir * 3.6;
    }
    if (!_held && _keyDir == 0) _thetaVel = M.approach(_thetaVel, 0, 8, dt);
    _bank = M.approach(_bank, (-_thetaVel * .12).clamp(-.7, .7), 10, dt);
    _inv = max(0, _inv - dt);
    // spawn ahead
    while (_nextSpawn < _d + _rings * _segL + 4) {
      _spawnRow(_nextSpawn);
      _nextSpawn += (_pattern % 5 == 2 ? 30 : 26) + _v * .35;
    }
    // collisions
    final shipZ = _d + _shipZ;
    for (final b in _obs) {
      if (b.hit || b.passed) continue;
      final dz = b.z - shipZ;
      if (dz < -1) {
        b.passed = true;
        final da = _wrap(b.a - _theta).abs();
        if (da < b.w * _slot / 2 + .35) {
          host.addScore(5);
          host.sfx(Sfx.whoosh, volume: .25, rate: 1.6);
        }
        continue;
      }
      if (dz.abs() < .75) {
        final da = _wrap(b.a - _theta).abs();
        if (da < b.w * _slot / 2 + .04 && _inv <= 0) _hitBlock(b);
      }
    }
    for (final g in _gems) {
      if (g.got) continue;
      if ((g.z - shipZ).abs() < 1 && _wrap(g.a - _theta).abs() < .3) {
        g.got = true;
        _gemCount++;
        host.sfx(Sfx.gem, rate: 1 + (_gemCount % 8) * .06);
        host.addScore(25, const Offset(180, 420));
        host.fx.sparkle(const Offset(180, 450), count: 8, radius: 26, color: const Color(0xFF7CFFF4));
      }
    }
    _obs.removeWhere((b) => b.z < _d - 4);
    _gems.removeWhere((g) => g.z < _d - 4);
  }

  void _hitBlock(_Block b) {
    b.hit = true;
    _hp--;
    _inv = 1.5;
    host.sfx(Sfx.explodeSmall);
    host.sfx(Sfx.hurt, volume: .6);
    host.shake(12, .35);
    host.hitStop(.07);
    host.flash(Pal.red, .2);
    host.fx.burst(const Offset(180, 450), Pal.orange, count: 22, speed: 320, size: 8,
        colors: const [Pal.orange, Pal.yellow, Pal.pink], gravity: 0);
    host.fx.ring(const Offset(180, 450), Pal.pink, size: 90);
    if (_hp <= 0) {
      _dead = true;
      host.sfx(Sfx.explode);
      host.fx.burst(const Offset(180, 450), Pal.white, count: 30, speed: 420, size: 10, gravity: 0);
      host.fx.pop(host.tr('ko', 'K.O.'), const Offset(180, 330), color: Pal.red, size: 44, life: 1.3);
      host.lose();
    } else {
      host.fx.pop(host.tr('oops', 'OOPS!'), const Offset(180, 360), color: Pal.red, size: 30);
    }
  }

  @override
  void onTimeUp() {
    host.sfx(Sfx.fanfare);
    host.fx.confetti();
    host.fx.pop(host.tr('clear', 'CLEAR!'), const Offset(180, 300), color: const Color(0xFF3FF0FF), size: 40, life: 1.4);
    host.win(stars: _hp);
  }

  // ------------------------------------------------------------- render ---

  double get _rot => -pi / 2 - _theta; // world angle -> display angle offset

  V3 _wall(double a, double rad, double z) {
    final da = a + _rot;
    return V3(cos(da) * rad, sin(da) * rad, z);
  }

  @override
  void render(Canvas c) {
    _space(c);
    final cam = scene.cam
      ..center = const Offset(180, 300)
      ..focal = 300
      ..pos = const V3(0, -2.0, -1.2)
      ..lookAt(const V3(0, -1.4, 20));
    scene.clear();
    scene.add(_tunnel());
    // blocks
    for (final b in _obs) {
      final z = b.z - _d;
      if (z < -1 || z > _rings * _segL) continue;
      final hue = b.hue;
      final col = D.hsv(hue, .75, 1);
      final top = D.hsv(hue + 20, .45, 1);
      final tw = 2 * _r * sin(b.w * _slot / 2) * .96;
      final m = Mesh.box(tw, b.h, 1.3, col, colors: [col, top, col, col, D.hsv(hue, .8, .7), D.hsv(hue, .8, .7)]);
      final da = b.a + _rot;
      scene.add(m,
          pos: V3(cos(da) * (_r - b.h / 2), sin(da) * (_r - b.h / 2), z),
          rotZ: da + pi / 2,
          flash: b.hit ? .8 : 0);
    }
    for (final g in _gems) {
      if (g.got) continue;
      final z = g.z - _d;
      if (z < 0 || z > _rings * _segL) continue;
      scene.addSprite(_wall(g.a, _r - .9, z), (cv, s, k) {
        final r = (k * .35).clamp(2.0, 30.0);
        cv.drawCircle(s, r * 1.6, Paint()..color = const Color(0x447CFFF4));
        D.gem(cv, s, r, const Color(0xFF7CFFF4));
      });
    }
    // ship
    if (!_dead || _deadT < .05) {
      final blink = _inv > 0 && (_t * 16).floor().isEven;
      if (!blink) {
        final sp = V3(0, -_r + 1.25, _shipZ);
        scene.add(_ship, pos: sp, rotZ: _bank, rotX: -.05);
      }
    }
    scene.render(c);
    // engine glow
    final sp = cam.project(V3(0, -_r + 1.25, _shipZ - 1.2));
    if (sp != null && !_dead) {
      final fl = 1 + sin(_t * 40) * .2;
      c.drawCircle(sp, 22 * fl, Paint()..color = const Color(0x44FF8A1F));
      c.drawCircle(sp, 12 * fl, Paint()..color = const Color(0xAAFFC53D));
      c.drawCircle(sp, 6 * fl, Paint()..color = const Color(0xFFFFFFFF));
    }
    _hud(c);
  }

  Mesh _tunnel() {
    final verts = <V3>[];
    final faces = <Face3>[];
    final off = _d % _segL;
    final k0 = (_d / _segL).floor();
    const band = .32;
    for (var i = 0; i < _rings; i++) {
      final z0 = i * _segL - off, zb = z0 + band, z1 = z0 + _segL;
      final base = verts.length;
      for (final z in [z0, zb, z1]) {
        for (var s = 0; s < _n; s++) {
          final a = (s - .5) * _slot + _rot;
          verts.add(V3(cos(a) * _r, sin(a) * _r, z));
        }
      }
      final k = k0 + i;
      final neon = D.hsv(180 + (k * 14) % 160, .8, 1);
      for (var s = 0; s < _n; s++) {
        final s1 = (s + 1) % _n;
        faces.add(Face3([base + s, base + s1, base + _n + s1, base + _n + s], neon));
        final dark = (s + k).isEven ? const Color(0xFF2A1560) : const Color(0xFF221050);
        faces.add(Face3([base + _n + s, base + _n + s1, base + 2 * _n + s1, base + 2 * _n + s],
            s % 4 == 0 ? const Color(0xFF3A2280) : dark));
      }
    }
    return Mesh(verts, faces, doubleSided: true);
  }

  void _space(Canvas c) {
    D.gradientBg(c, const [Color(0xFF12052A), Color(0xFF1C0838), Color(0xFF12052A)]);
    const vp = Offset(180, 290);
    c.drawCircle(vp, 120, Paint()..color = const Color(0x22B05CFF));
    c.drawCircle(vp, 60, Paint()..color = const Color(0x44FF7AE0));
    c.drawCircle(vp, 24, Paint()..color = const Color(0xAAFFFFFF));
    final sp = _v / 20;
    for (final s in _stars) {
      final u = (s[1] + _t * .35 * sp * s[2]) % 1;
      final r0 = 20 + u * u * 420;
      final a = s[0] + _theta * .0 + _rot * .0;
      final p0 = vp + Offset(cos(a), sin(a)) * r0;
      final p1 = vp + Offset(cos(a), sin(a)) * (r0 + 6 + u * 40 * sp);
      c.drawLine(p0, p1, D.stroke(Color.fromRGBO(220, 200, 255, .3 + u * .6), 1 + u * 2));
    }
  }

  void _hud(Canvas c) {
    for (var i = 0; i < _maxHp; i++) {
      D.heart(c, Offset(30 + i * 30.0, 62), 22, i < _hp ? Pal.pink : const Color(0x44FFFFFF), border: Pal.ink);
    }
    D.gem(c, const Offset(292, 62), 10, const Color(0xFF7CFFF4));
    D.text(c, '$_gemCount', const Offset(310, 62), size: 20, color: Pal.white, stroke: Pal.ink, strokeWidth: 4,
        anchor: Alignment.centerLeft);
    final kmh = (_v * 37).round();
    D.text(c, '$kmh km/s', const Offset(180, 620), size: 16, color: const Color(0xFF7CFFF4), stroke: Pal.ink,
        strokeWidth: 4);
    if (!_touched && host.time < 3) {
      D.hand(c, Offset(180 + sin(_t * 3) * 70, 540), _t);
      D.arrow(c, const Offset(100, 520), const Offset(-1, 0), 44, Pal.yellow, width: 8);
      D.arrow(c, const Offset(260, 520), const Offset(1, 0), 44, Pal.yellow, width: 8);
      D.text(c, host.tr('drag', 'DRAG'), const Offset(180, 588), size: 22, color: Pal.white, stroke: Pal.ink,
          strokeWidth: 5);
    }
  }
}

class _Block {
  _Block(this.z, this.a, this.w, this.h, this.hue);
  final double z, a, h, hue;
  final int w;
  bool hit = false;
  bool passed = false;
}

class _Gem {
  _Gem(this.z, this.a);
  final double z, a;
  bool got = false;
}

Mesh _rx(Mesh m, double a) {
  final c = cos(a), s = sin(a);
  return Mesh([for (final v in m.verts) V3(v.x, v.y * c - v.z * s, v.y * s + v.z * c)],
      [for (final f in m.faces) Face3(List.of(f.idx), f.color)],
      fixWinding: true);
}
