import 'dart:math' as math;

import '../engine/engine.dart';

/// No.099 Sky Rings — chase-cam stunt plane over a low-poly valley.
/// Drag to steer, thread the golden rings (each one boosts you). Hit 8.
class G099 extends MiniGame {
  static const _need = 8;
  static const _ringR = 2.4;
  static const _step = 8.0;

  final scene = Scene3();
  late final Mesh _plane;
  late final Mesh _prop;
  late final Mesh _ring;
  late final Mesh _ringNext;
  late final Mesh _tree;
  late final Mesh _rock;

  double _t = 0;
  double _px = 0, _py = 6, _pz = 0;
  double _tx = 0, _ty = 6;
  double _vx = 0, _vy = 0;
  double _speed = 24;
  double _boost = 0;
  double _bank = 0, _pitch = 0;
  double _roll = 0; // victory barrel roll
  int _hits = 0;
  int _combo = 0;
  double _hudBump = 0;
  final List<_Ring> _rings = [];
  final List<_Cloud> _clouds = [];
  final List<V3> _trailL = [], _trailR = [];
  double _trailT = 0;
  Offset? _anchor;
  double _ax = 0, _ay = 0;
  double _kx = 0, _ky = 0;

  @override
  void init() {
    scene
      ..ambient = .55
      ..diffuse = .6
      ..light = const V3(.4, 1, -.5).normalized
      ..fogColor = const Color(0xFFBFE6FF)
      ..fogNear = 45
      ..fogFar = 125;
    const red = Color(0xFFFF3B5C);
    const white = Color(0xFFF4F7FF);
    _plane = Mesh.merge([
      (Mesh.box(.6, .6, 2.3, red, colors: const [red, Color(0xFFCC2244), red, red, red, red]), const V3(0, 0, 0)),
      (_rotX(Mesh.cone(.3, .5, white, seg: 6), pi / 2), const V3(0, 0, 1.4)),
      (Mesh.box(.42, .32, .7, const Color(0xFF7FD8FF)), const V3(0, .42, .15)),
      (Mesh.box(3.4, .08, .75, white), const V3(0, -.08, .25)),
      (Mesh.box(.4, .1, .77, red), const V3(-1.55, -.08, .25)),
      (Mesh.box(.4, .1, .77, red), const V3(1.55, -.08, .25)),
      (Mesh.box(.08, .65, .5, red), const V3(0, .5, -1.0)),
      (Mesh.box(1.4, .06, .42, white), const V3(0, .12, -1.0)),
      (Mesh.box(.3, .5, .2, const Color(0xFF333344)), const V3(0, -.45, .5)),
    ]);
    _prop = Mesh.merge([
      (Mesh.box(1.5, .14, .04, const Color(0xFF2B2B3A)), V3.zero),
      (Mesh.box(.18, .18, .12, Pal.yellow), V3.zero),
    ]);
    _ring = Mesh.torus(_ringR, .3, Pal.gold, seg: 16, side: 5);
    for (var i = 0; i < _ring.faces.length; i++) {
      if ((i ~/ 5).isEven) _ring.faces[i].color = const Color(0xFFFF9F1C);
    }
    _ringNext = _ring.recolor(Pal.gold);
    for (var i = 0; i < _ringNext.faces.length; i++) {
      _ringNext.faces[i].color = (i ~/ 5).isEven ? const Color(0xFFFFF27A) : const Color(0xFFFFC53D);
    }
    _tree = Mesh.merge([
      (Mesh.cone(1.3, 3.2, const Color(0xFF2E9E57), seg: 5), const V3(0, 2.4, 0)),
      (Mesh.box(.35, .9, .35, const Color(0xFF7A4A2C)), const V3(0, .45, 0)),
    ]);
    _rock = Mesh.cone(1.6, 2.2, const Color(0xFF8C8FA8), seg: 4);
    var x = 0.0, y = 6.0;
    for (var i = 0; i < 26; i++) {
      x = (x + rand(-5, 5)).clamp(-7.0, 7.0);
      y = (y + rand(-2.8, 2.8)).clamp(3.8, 10.5);
      _rings.add(_Ring(i == 0 ? 0 : x, i == 0 ? 6 : y, 42 + i * 32.0));
    }
    for (var i = 0; i < 16; i++) {
      _clouds.add(_Cloud(rand(-30, 30), rand(6, 22), rand(10, 400), rand(.8, 1.6)));
    }
  }

  static Mesh _rotX(Mesh m, double a) {
    final c = cos(a), s = sin(a);
    return Mesh([for (final v in m.verts) V3(v.x, v.y * c - v.z * s, v.y * s + v.z * c)],
        [for (final f in m.faces) Face3(List.of(f.idx), f.color)]);
  }

  // ------------------------------------------------------------- terrain ---

  static double _h(double x, double z) {
    final side = math.pow((x.abs() / 34), 2) * 26;
    final n = sin(x * .11 + z * .045) * 3 + sin(z * .09 + 1.3) * 2.5 + sin(x * .27 - z * .06) * 1.6 + sin(z * .031) * 2;
    return side + n - 2.5;
  }

  static Color _terrainColor(double h, int i, int j) {
    final checker = (i + j).isEven ? 0.0 : .06;
    if (h <= .05) return Color.lerp(const Color(0xFF3FA9F5), const Color(0xFF2E86DE), checker * 8)!;
    if (h < 1.2) return const Color(0xFFF2DC9B);
    if (h < 7) return Color.lerp(const Color(0xFF7ED957), const Color(0xFF5CC046), checker * 8)!;
    if (h < 13) return Color.lerp(const Color(0xFF3FAE5A), const Color(0xFF2F9A4E), checker * 8)!;
    if (h < 19) return const Color(0xFF9A8F8A);
    return const Color(0xFFF7FBFF);
  }

  Mesh _buildTerrain() {
    const nx = 16, nz = 18;
    final z0 = (_pz / _step).floor() * _step - _step;
    const x0 = -nx / 2 * _step;
    final verts = <V3>[];
    for (var j = 0; j <= nz; j++) {
      for (var i = 0; i <= nx; i++) {
        final wx = x0 + i * _step, wz = z0 + j * _step;
        verts.add(V3(wx, max(0.0, _h(wx, wz)), wz));
      }
    }
    final faces = <Face3>[];
    for (var j = 0; j < nz; j++) {
      for (var i = 0; i < nx; i++) {
        final a = j * (nx + 1) + i;
        final hAvg = (verts[a].y + verts[a + 1].y + verts[a + nx + 1].y + verts[a + nx + 2].y) / 4;
        final gi = ((x0 + i * _step) / _step).round(), gj = ((z0 + j * _step) / _step).round();
        faces.add(Face3([a, a + nx + 1, a + nx + 2, a + 1], _terrainColor(hAvg, gi, gj)));
      }
    }
    return Mesh(verts, faces, doubleSided: true);
  }

  static double _hash(int a, int b) {
    var h = a * 374761393 + b * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0;
  }

  // ------------------------------------------------------------ gameplay ---

  _Ring? get _nextRing {
    for (final r in _rings) {
      if (!r.passed) return r;
    }
    return null;
  }

  @override
  void update(double dt) {
    _t += dt;
    _hudBump = M.approach(_hudBump, 0, 6, dt);
    _boost = M.approach(_boost, 0, 1.4, dt);
    final base = 23.0 * (.85 + .15 * host.speed);
    _speed = base * (1 + _boost * .55);
    _pz += _speed * dt;

    final tx = (_tx + _kx * 9).clamp(-9.0, 9.0);
    final ty = (_ty + _ky * 5).clamp(2.8, 12.0);
    if (host.finished) {
      _py += dt * (host.finished && _hits >= _need ? 5 : -2);
      _roll += dt * (_hits >= _need ? 7 : 2);
    } else {
      final nx = M.approach(_px, tx, 3.2, dt), ny = M.approach(_py, ty, 3.2, dt);
      _vx = (nx - _px) / max(dt, 1e-4);
      _vy = (ny - _py) / max(dt, 1e-4);
      _px = nx;
      _py = ny;
    }
    _bank = M.approach(_bank, (-_vx * .09).clamp(-.9, .9), 8, dt);
    _pitch = M.approach(_pitch, (-_vy * .06).clamp(-.5, .5), 8, dt);

    // rings
    for (final r in _rings) {
      if (r.passed) {
        r.anim += dt;
        continue;
      }
      if (_pz >= r.z) {
        r.passed = true;
        final d = sqrt((_px - r.x) * (_px - r.x) + (_py - r.y) * (_py - r.y));
        if (d < _ringR - .15 && !host.finished) {
          r.hit = true;
          _hits++;
          _combo++;
          _hudBump = 1;
          _boost = 1;
          final s = scene.cam.project(V3(r.x, r.y, r.z + 2)) ?? const Offset(180, 300);
          host.addScore(10 * _combo, s + const Offset(0, -40));
          host.sfx(Sfx.ding, volume: .9, rate: 1 + min(_combo, 8) * .08);
          host.sfx(Sfx.whoosh, volume: .7, rate: 1.3);
          host.fx.ring(s, Pal.yellow, size: 170, life: .45);
          host.fx.burst(s, Pal.gold, count: 22, speed: 380, gravity: 0, colors: const [Pal.gold, Pal.white, Pal.yellow]);
          host.punch(.04);
          host.shake(3);
          if (d < .8) {
            host.fx.pop(host.tr('perfect', 'PERFECT!'), const Offset(180, 200), color: Pal.yellow, size: 30);
            host.addScore(20);
          } else if (_combo >= 3) {
            host.fx.pop('${host.tr('combo', 'COMBO')} x$_combo', const Offset(180, 200), color: Pal.pink, size: 28);
          }
          if (_hits >= _need) {
            host.fx.confetti(count: 80);
            host.sfx(Sfx.fanfare);
            host.win(stars: _hits >= _need && host.time < 13 ? 3 : (_combo >= 5 ? 3 : 2));
          }
        } else if (!host.finished) {
          _combo = 0;
          host.sfx(Sfx.wrong, volume: .5);
          host.fx.pop(host.tr('miss', 'MISS'), const Offset(180, 230), color: Pal.red, size: 26);
        }
      }
    }
    // clouds recycle
    for (final cl in _clouds) {
      if (cl.z < _pz - 10) {
        cl.z += 420;
        cl.x = rand(-34, 34);
        cl.y = rand(6, 22);
      }
      final dx = cl.x - _px, dy = cl.y - _py, dz = cl.z - _pz;
      if (!cl.poofed && dz.abs() < 1.2 && dx.abs() < 3.5 * cl.s && dy.abs() < 2 * cl.s) {
        cl.poofed = true;
        host.sfx(Sfx.wind, volume: .5);
        host.flash(const Color(0x88FFFFFF), .15);
      }
    }
    // contrails
    _trailT += dt;
    if (_trailT > .03) {
      _trailT = 0;
      final ca = cos(_bank + _roll), sa = sin(_bank + _roll);
      _trailL.add(V3(_px - 1.7 * ca, _py - 1.7 * sa, _pz + .2));
      _trailR.add(V3(_px + 1.7 * ca, _py + 1.7 * sa, _pz + .2));
      if (_trailL.length > 18) {
        _trailL.removeAt(0);
        _trailR.removeAt(0);
      }
    }
    // speed streaks while boosted
    if (_boost > .3 && chance(_boost * .9)) {
      final side = chance(.5) ? -1.0 : 1.0;
      final p = Offset(180 + side * rand(90, 180), rand(80, 600));
      host.fx.add(Particle(
          pos: p,
          vel: (p - const Offset(180, 330)) * 4,
          life: .25,
          color: const Color(0xCCFFFFFF),
          size: 3,
          shape: PartShape.spark));
    }
  }

  @override
  void onTimeUp() => host.lose();

  // --------------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    _anchor = p;
    _ax = _tx;
    _ay = _ty;
  }

  @override
  void onMove(Offset p) {
    final a = _anchor;
    if (a == null) return;
    _tx = (_ax + (p.dx - a.dx) / 17).clamp(-9.0, 9.0);
    _ty = (_ay - (p.dy - a.dy) / 20).clamp(2.8, 12.0);
  }

  @override
  void onUp(Offset p) => _anchor = null;

  @override
  void onKey(String key, bool down) {
    final v = down ? 1.0 : 0.0;
    switch (key) {
      case 'left':
        _kx = -v;
      case 'right':
        _kx = v;
      case 'up':
        _ky = v;
      case 'down':
        _ky = -v;
    }
  }

  // -------------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    final cam = scene.cam;
    cam
      ..center = const Offset(180, 300)
      ..focal = 300 - _boost * 70
      ..pos = V3(_px * .8, _py + 2.0, _pz - 7.8)
      ..lookAt(V3(_px * .9, _py + .5, _pz + 12));

    c.save();
    // camera roll with the bank
    c.translate(180, 300);
    c.rotate(-_bank * .35);
    c.translate(-180, -300);
    _renderSky(c);

    scene.clear();
    scene.add(_buildTerrain());
    // scenery on hash grid
    final zc = (_pz / 16).floor();
    for (var gz = zc; gz < zc + 8; gz++) {
      for (var gx = -4; gx <= 4; gx++) {
        final hv = _hash(gx, gz);
        if (hv > .5) continue;
        final wx = gx * 16 + (_hash(gz, gx) - .5) * 10, wz = gz * 16.0 + hv * 12;
        final h = _h(wx, wz);
        if (h < 1.3) continue;
        if (h > 14) {
          scene.add(_rock, pos: V3(wx, h + .6, wz), rotY: hv * 6, scale: 1.2 + hv);
        } else {
          scene.add(_tree, pos: V3(wx, h - .2, wz), rotY: hv * 6, scale: 1.1 + hv * 1.4);
        }
      }
    }
    // rings
    final next = _nextRing;
    for (final r in _rings) {
      if (r.z < _pz - 8 || r.z > _pz + 140) continue;
      if (r.passed && !r.hit && r.z < _pz) continue;
      if (r.hit) {
        final k = r.anim / .4;
        if (k >= 1) continue;
        scene.add(_ringNext, pos: V3(r.x, r.y, r.z), scale: 1 + k * .9, alpha: 1 - k, rotZ: k * 2);
      } else {
        final isNext = identical(r, next);
        scene.add(isNext ? _ringNext : _ring,
            pos: V3(r.x, r.y, r.z), rotZ: _t * (isNext ? 1.2 : .4), scale: isNext ? 1 + .05 * sin(_t * 8) : 1);
        if (isNext) {
          scene.addSprite(V3(r.x, r.y, r.z + .5), (c, s, k) {
            c.drawCircle(s, _ringR * k * 1.05,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = max(2, .5 * k)
                  ..color = Color.fromRGBO(255, 250, 200, .25 + .2 * sin(_t * 8)));
          });
        }
      }
    }
    // clouds (billboards)
    for (final cl in _clouds) {
      if (cl.z < _pz - 6 || cl.z > _pz + 160) continue;
      scene.addSprite(V3(cl.x, cl.y, cl.z), (c, s, k) {
        final dist = cl.z - _pz;
        final a = (1 - ((dist - 60) / 100).clamp(0.0, 1.0)) * (dist < 4 ? (dist / 4).clamp(.2, 1.0) : 1);
        c.save();
        c.translate(s.dx, s.dy);
        c.scale(k * cl.s * .05);
        D.cloud(c, Offset.zero, 60, color: Color.fromRGBO(255, 255, 255, .92 * a));
        c.restore();
      });
    }
    // contrails as sprites anchored at the plane
    final pp = V3(_px, _py, _pz);
    scene.addSprite(pp - const V3(0, 0, 2.5), (c, s, k) => _trails(c));
    scene.add(_plane, pos: pp, rotZ: _bank + _roll, rotX: _pitch, rotY: _vx * .012);
    scene.add(_prop, pos: _nose(), rotZ: _t * 40, rotX: _pitch, rotY: _vx * .012);
    scene.render(c);
    c.restore();
    _renderHud(c, next);
  }

  V3 _nose() {
    // propeller position (rotated with pitch roughly)
    return V3(_px, _py - sin(_pitch) * 1.7, _pz + 1.7);
  }

  void _trails(Canvas c) {
    for (final tr in [_trailL, _trailR]) {
      Offset? prev;
      for (var i = 0; i < tr.length; i++) {
        final p = scene.cam.project(tr[i]);
        if (p != null && prev != null) {
          c.drawLine(prev, p, D.stroke(Color.fromRGBO(255, 255, 255, i / tr.length * .7), 1 + i / tr.length * 3));
        }
        prev = p;
      }
    }
  }

  void _renderSky(Canvas c) {
    const r = Rect.fromLTWH(-120, -120, 600, 880);
    D.gradientBg(c, const [Color(0xFF3F8CFF), Color(0xFF7CC4FF), Color(0xFFBFE6FF), Color(0xFFBFE6FF)], rect: r);
    // horizon position from the camera pitch
    final hz = scene.cam.center.dy - math.tan(-scene.cam.pitch) * scene.cam.focal;
    // sun
    c.drawCircle(Offset(260 - _px * 2, hz - 170), 70, Paint()..color = const Color(0x44FFFFFF));
    c.drawCircle(Offset(260 - _px * 2, hz - 170), 36, Paint()..color = const Color(0xFFFFF6D0));
    // distant mountain bands
    for (var layer = 0; layer < 2; layer++) {
      final col = layer == 0 ? const Color(0xFFA5C8EE) : const Color(0xFF8DB6E0);
      final path = Path()..moveTo(-120, hz + 10);
      for (var x = -120.0; x <= 480; x += 30) {
        final off = _px * (layer + 1) * 1.5;
        final y = hz - 20 - layer * 8 - (sin((x + off) * .021 + layer * 2) * .5 + .5) * (40 - layer * 12) - sin((x + off) * .07) * 8;
        path.lineTo(x, y);
      }
      path
        ..lineTo(480, hz + 30)
        ..lineTo(-120, hz + 30)
        ..close();
      c.drawPath(path, Paint()..color = col);
    }
    c.drawRect(Rect.fromLTWH(-120, hz + 5, 600, 60), Paint()..color = const Color(0xFFBFE6FF));
    // fallback ground under the camera (terrain rows behind the near plane get culled)
    c.drawRect(Rect.fromLTWH(-160, hz + 40, 680, 900), Paint()..color = const Color(0xFF6CCB4E));
  }

  void _renderHud(Canvas c, _Ring? next) {
    // ring counter
    final s = 1 + _hudBump * .3;
    c.save();
    c.translate(70, 72);
    c.scale(s);
    D.rrect(c, const Rect.fromLTWH(-54, -22, 108, 44), 22, const Color(0xAA0E2A55), border: Pal.white, borderWidth: 2.5);
    c.drawCircle(const Offset(-30, 0), 12, D.stroke(Pal.gold, 5));
    D.text(c, '$_hits/$_need', const Offset(14, 0), size: 22, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
    c.restore();
    if (_combo >= 2) {
      D.text(c, 'x$_combo', const Offset(150, 72), size: 22, color: Pal.pink, stroke: Pal.ink, strokeWidth: 4);
    }
    // speed
    D.text(c, '${(_speed * 12).round()}', const Offset(318, 66), size: 24, color: Pal.white, stroke: Pal.ink, strokeWidth: 4, italic: true);
    D.text(c, 'km/h', const Offset(318, 88), size: 12, color: const Color(0xCCFFFFFF));
    // off-screen next ring arrow
    if (next != null && !host.finished) {
      final p = scene.cam.project(V3(next.x, next.y, next.z));
      if (p != null && (p.dx < 20 || p.dx > 340 || p.dy < 60 || p.dy > 620)) {
        final d = p - const Offset(180, 300);
        final e = Offset(180 + (d.dx).clamp(-150.0, 150.0), 300 + d.dy.clamp(-220.0, 300.0));
        D.arrow(c, e, d, 30, Pal.yellow, width: 8);
      }
    }
    if (host.time < 2.5 && !host.finished) {
      final o = Offset(180 + sin(_t * 2.5) * 50, 540 + cos(_t * 2.5) * 20);
      D.hand(c, o, _t);
      D.text(c, host.tr('drag', 'DRAG'), const Offset(180, 610), size: 18, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
    }
  }
}

class _Ring {
  _Ring(this.x, this.y, this.z);
  final double x, y, z;
  bool passed = false;
  bool hit = false;
  double anim = 0;
}

class _Cloud {
  _Cloud(this.x, this.y, this.z, this.s);
  double x, y, z;
  final double s;
  bool poofed = false;
}
