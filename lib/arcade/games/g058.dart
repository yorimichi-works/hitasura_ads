import '../engine/engine.dart';

/// No.058 Hexa Fall — 2 layers of 3D hex tiles. Any tile someone stands on
/// shakes and drops 0.6 s later. Drag to run (virtual joystick). Fall through
/// the top layer onto the bottom one; fall off the bottom and you're OUT.
/// Outlast the 3 CPU blobs (or survive the timer) to win.
class G058 extends MiniGame {
  static const _s = .8; // hex circumradius
  static const _rad = 4; // grid radius
  static const _layerY = [0.0, -3.4];
  static const _h = .34;
  static const _delay = .7;

  final _scene = Scene3();
  final List<_Hex> _tiles = [];
  final Map<int, _Hex> _lookup = {};
  late final List<List<Mesh>> _meshes; // [layer][variant]
  final _pl = List.generate(4, (i) => _Guy(i));
  double _t = 0;

  Offset? _anchor;
  Offset _stick = Offset.zero;
  int _kx = 0, _ky = 0;

  static int _key(int q, int r, int layer) => (layer * 100 + q + 50) * 1000 + r + 50;

  @override
  void init() {
    _scene
      ..light = const V3(-.4, 1, -.5).normalized
      ..ambient = .55
      ..diffuse = .55;
    const topCols = [Color(0xFFFF8FB8), Color(0xFFFFD23F), Color(0xFFFFB0D0)];
    const botCols = [Color(0xFF3FD0E0), Color(0xFF4F9BFF), Color(0xFF7FE8F0)];
    _meshes = [
      [for (final c in topCols) _hexMesh(c, const Color(0xFFD9507F))],
      [for (final c in botCols) _hexMesh(c, const Color(0xFF2A6FB8))],
    ];
    for (var layer = 0; layer < 2; layer++) {
      for (var q = -_rad; q <= _rad; q++) {
        for (var r = -_rad; r <= _rad; r++) {
          final ring = max(q.abs(), max(r.abs(), (q + r).abs()));
          if (ring > _rad) continue;
          final x = _s * 1.5 * q;
          final z = _s * sqrt(3) * (r + q / 2);
          final variant = ring == 0 ? 1 : ((q - r) % 3 + 3) % 3;
          final h = _Hex(q, r, layer, x, z, variant);
          _tiles.add(h);
          _lookup[_key(q, r, layer)] = h;
        }
      }
    }
    const starts = [Offset(0, -2.6), Offset(2.4, 1.2), Offset(-2.4, 1.2), Offset(0, 3.0)];
    for (var i = 0; i < 4; i++) {
      _pl[i]
        ..x = starts[i].dx
        ..z = starts[i].dy
        ..think = rand(0, .3);
    }
  }

  Mesh _hexMesh(Color top, Color side) {
    final v = <V3>[];
    const k = .93; // small gap between tiles
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3;
      v.add(V3(cos(a) * _s * k, 0, sin(a) * _s * k));
    }
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3;
      v.add(V3(cos(a) * _s * k * .9, -_h, sin(a) * _s * k * .9));
    }
    final f = <Face3>[Face3([0, 1, 2, 3, 4, 5], top)];
    for (var i = 0; i < 6; i++) {
      final n = (i + 1) % 6;
      f.add(Face3([i, n, n + 6, i + 6], i.isEven ? side : Color.lerp(side, Pal.ink, .15)!));
    }
    return Mesh(v, f, fixWinding: true);
  }

  _Hex? _tileAt(double x, double z, int layer) {
    final qf = (2 / 3 * x) / _s;
    final rf = (-1 / 3 * x + sqrt(3) / 3 * z) / _s;
    final sf = -qf - rf;
    var q = qf.round(), r = rf.round();
    final s = sf.round();
    final dq = (q - qf).abs(), dr = (r - rf).abs(), ds = (s - sf).abs();
    if (dq > dr && dq > ds) {
      q = -r - s;
    } else if (dr > ds) {
      r = -q - s;
    }
    final h = _lookup[_key(q, r, layer)];
    if (h == null || h.state >= 2) return null;
    return h;
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    for (final h in _tiles) {
      if (h.state == 1) {
        h.timer -= dt;
        if (h.timer <= 0) {
          h.state = 2;
          h.vy = 0;
          if (h.layer == 0 || chance(.5)) host.sfx(Sfx.crack, volume: .25, rate: rand(.9, 1.3));
        }
      } else if (h.state == 2) {
        h.vy -= 18 * dt;
        h.fall += h.vy * dt;
      }
    }

    // input → player
    final me = _pl[0];
    var sx = _stick.dx, sz = -_stick.dy;
    if (_kx != 0 || _ky != 0) {
      sx = _kx.toDouble();
      sz = _ky.toDouble();
    }
    final l = sqrt(sx * sx + sz * sz);
    if (l > 1) {
      sx /= l;
      sz /= l;
    }
    me.dx = sx;
    me.dz = sz;

    for (var i = 1; i < 4; i++) {
      final g = _pl[i];
      if (g.out || g.airborne) continue;
      g.think -= dt;
      g.nap = max(0, g.nap - dt);
      final goal = g.goal;
      final reached = goal != null && sqrt(pow(goal.x - g.x, 2) + pow(goal.z - g.z, 2)) < .3;
      if (g.think <= 0 || goal == null || goal.state != 0 || reached) {
        g.think = rand(.6, 1.0);
        _cpuPlan(g);
      } else {
        final dx = goal.x - g.x, dz = goal.z - g.z;
        final l = sqrt(dx * dx + dz * dz);
        g.dx = dx / l;
        g.dz = dz / l;
      }
      if (g.nap > 0) {
        g.dx = g.dz = 0;
      }
    }

    for (final g in _pl) {
      if (g.out) continue;
      g.squash = M.approach(g.squash, 1, 10, dt);
      if (g.airborne) {
        g.vy -= 20 * dt;
        g.y += g.vy * dt;
        g.x += g.vx * dt * .5;
        g.z += g.vz * dt * .5;
        // land on the lower layer?
        if (g.layer == 0 && g.y <= _layerY[1] && g.vy < 0) {
          final t = _tileAt(g.x, g.z, 1);
          if (t != null) {
            g.layer = 1;
            g.y = _layerY[1];
            g.airborne = false;
            g.squash = 1.5;
            _touch(t);
            host.sfx(Sfx.land, volume: g.id == 0 ? 1 : .4);
            if (g.id == 0) {
              host.shake(5);
              final p = _scene.cam.project(V3(g.x, g.y, g.z));
              if (p != null) {
                host.fx.smoke(p, count: 6);
                host.fx.pop(host.tr('safe', 'SAFE!'), p + const Offset(0, -50), color: Pal.lime, size: 22);
              }
            }
          } else {
            g.layer = 1; // keep falling past it
          }
        }
        if (g.y < -12) {
          g.out = true;
          if (g.id == 0) {
            host.sfx(Sfx.aww);
            host.lose();
          } else {
            _checkWin();
          }
        }
        continue;
      }
      final sp = (g.id == 0 ? 3.6 : (g.id == 1 ? 3.1 : (g.id == 2 ? 2.9 : 2.5))) * (g.id == 0 ? 1 : sqrt(host.speed));
      g.vx = M.approach(g.vx, g.dx * sp, 14, dt);
      g.vz = M.approach(g.vz, g.dz * sp, 14, dt);
      g.x += g.vx * dt;
      g.z += g.vz * dt;
      if (g.vx.abs() + g.vz.abs() > .3) {
        g.run += dt * 14;
        g.faceLeft = g.vx < -.2 ? true : (g.vx > .2 ? false : g.faceLeft);
      }
      final t = _tileAt(g.x, g.z, g.layer);
      if (t == null) {
        g.airborne = true;
        g.vy = 1.2;
        host.sfx(Sfx.whoosh, volume: g.id == 0 ? .9 : .35, rate: .8);
        if (g.id == 0) host.shake(3);
        if (g.layer == 1 && g.id != 0) {
          final p = _scene.cam.project(V3(g.x, g.y, g.z));
          if (p != null) {
            host.fx.pop(host.tr('out', 'OUT!'), p + const Offset(0, -40), color: Pal.yellow, size: 28);
            host.addScore(100, p);
          }
          host.sfx(Sfx.cheer, volume: .4);
        }
      } else {
        _touch(t);
      }
    }

    // gentle body bumps
    for (var i = 0; i < 4; i++) {
      for (var j = i + 1; j < 4; j++) {
        final a = _pl[i], b = _pl[j];
        if (a.out || b.out || a.airborne || b.airborne || a.layer != b.layer) continue;
        final dx = b.x - a.x, dz = b.z - a.z;
        final d = sqrt(dx * dx + dz * dz);
        if (d < .6 && d > 1e-4) {
          final push = (.6 - d) / 2;
          a.x -= dx / d * push;
          a.z -= dz / d * push;
          b.x += dx / d * push;
          b.z += dz / d * push;
          if (d < .45 && (i == 0 || j == 0) && chance(.2)) host.sfx(Sfx.bounce, volume: .4);
        }
      }
    }
  }

  void _touch(_Hex t) {
    if (host.time < 1.0) return; // grace period to read the scene
    if (t.state == 0) {
      t.state = 1;
      t.timer = _delay / sqrt(host.speed);
    }
  }

  void _cpuPlan(_Guy g) {
    if (g.id == 3 && g.nap <= 0 && chance(.08)) {
      g.nap = .7; // yellow dozes off. Bad idea.
      return;
    }
    _Hex? best;
    var bs = -1e9;
    for (final h in _tiles) {
      if (h.layer != g.layer || h.state != 0) continue;
      final d = sqrt(pow(h.x - g.x, 2) + pow(h.z - g.z, 2));
      if (d > 4.5) continue;
      var s = -(d - 1.5).abs() + rand(0, g.id == 1 ? .8 : .4);
      // keep heading the same way (no dithering)
      final vl = sqrt(g.vx * g.vx + g.vz * g.vz);
      if (vl > .3 && d > .1) s += ((h.x - g.x) * g.vx + (h.z - g.z) * g.vz) / (d * vl) * .6;
      // avoid tiles whose neighbours are already gone (dead ends)
      if (_tileAt(h.x, h.z, h.layer) == null) s -= 5;
      // crowd avoidance + prefer the ring centre a bit
      for (final o in _pl) {
        if (o == g || o.out || o.layer != g.layer) continue;
        final od = sqrt(pow(h.x - o.x, 2) + pow(h.z - o.z, 2));
        if (od < 1.2) s -= 1.2;
      }
      s -= sqrt(h.x * h.x + h.z * h.z) * .12;
      if (s > bs) {
        bs = s;
        best = h;
      }
    }
    g.goal = best;
    if (best == null) {
      g.dx = rand(-1, 1);
      g.dz = rand(-1, 1);
      return;
    }
    final dx = best.x - g.x, dz = best.z - g.z;
    final l = sqrt(dx * dx + dz * dz);
    g.dx = l > .05 ? dx / l : 0;
    g.dz = l > .05 ? dz / l : 0;
  }

  void _checkWin() {
    if (host.finished) return;
    if (_pl.skip(1).every((g) => g.out || (g.airborne && g.layer == 1))) {
      host.fx.confetti(count: 90);
      host.sfx(Sfx.fanfare);
      host.win(stars: 3);
    }
  }

  @override
  void onTimeUp() {
    final me = _pl[0];
    if (me.out || (me.airborne && me.layer == 1)) {
      host.lose();
      return;
    }
    final outs = _pl.skip(1).where((g) => g.out || g.airborne).length;
    host.fx.confetti(count: 60);
    host.win(stars: me.layer == 0 || outs >= 3 ? 3 : (outs >= 2 ? 2 : 1));
  }

  // ------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    _anchor = p;
    _stick = Offset.zero;
  }

  @override
  void onMove(Offset p) {
    final a = _anchor;
    if (a == null) return;
    var d = p - a;
    const maxR = 50.0;
    if (d.distance > maxR) d = d / d.distance * maxR;
    _stick = d / maxR;
  }

  @override
  void onUp(Offset p) {
    _anchor = null;
    _stick = Offset.zero;
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
    }
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF8A5CFF), Color(0xFFFF7EB6), Color(0xFFFFC37A)]);
    // void below: swirling stripes
    for (var i = 0; i < 10; i++) {
      final y = 380 + i * 30.0 + (_t * 40) % 30;
      c.drawRect(Rect.fromLTWH(0, y, 360, 10), D.fill(Color.fromRGBO(255, 255, 255, .04 + i * .008)));
    }
    for (var i = 0; i < 12; i++) {
      final x = (i * 71 + _t * 30 * (1 + i % 3)) % 400 - 20;
      final y = (i * 131) % 600 + 40.0;
      D.star(c, Offset(x, y), 4 + (i % 3) * 2, const Color(0x55FFFFFF));
    }

    final cam = _scene.cam
      ..pos = const V3(0, 12.5, -10.5)
      ..focal = 470
      ..center = const Offset(180, 322)
      ..lookAt(const V3(0, -1.9, .7));
    _scene.clear();
    for (final h in _tiles) {
      if (h.fall < -14) continue;
      var y = _layerY[h.layer] + h.fall;
      var ox = 0.0, oz = 0.0;
      Color? tint;
      double flash = 0;
      if (h.state == 1) {
        final k = 1 - h.timer / _delay;
        ox = sin(_t * 70 + h.q) * .05 * (1 + k);
        oz = cos(_t * 63 + h.r) * .05 * (1 + k);
        y -= k * .06;
        flash = (sin(_t * 30) * .5 + .5) * .45 * k;
        tint = Color.lerp(Pal.white, const Color(0xFFFF7070), k);
      }
      _scene.add(_meshes[h.layer][h.variant], pos: V3(h.x + ox, y, h.z + oz), tint: tint, flash: flash,
          rotX: h.state == 2 ? h.fall * .05 * (h.q.isEven ? 1 : -1) : 0);
    }
    for (final g in _pl) {
      if (g.out) continue;
      final base = V3(g.x, g.y, g.z);
      // anchor nudged toward the camera so the guy draws over his own tile
      _scene.addSprite(V3(g.x, g.y + .5, g.z - .45), (cv, _, _) => _drawGuy(cv, g, base));
    }
    _scene.render(c);

    // YOU marker always on top
    final me = _pl[0];
    if (!me.out) {
      final p = cam.project(V3(me.x, me.y + 1.5, me.z));
      if (p != null) {
        final ay = p.dy - 12 + sin(_t * 6) * 3;
        c.drawPath(
            Path()
              ..moveTo(p.dx - 9, ay)
              ..lineTo(p.dx + 9, ay)
              ..lineTo(p.dx, ay + 11)
              ..close(),
            D.fill(Pal.white));
        c.drawPath(
            Path()
              ..moveTo(p.dx - 9, ay)
              ..lineTo(p.dx + 9, ay)
              ..lineTo(p.dx, ay + 11)
              ..close(),
            D.stroke(Pal.blue, 2.5));
        D.text(c, host.tr('you', 'YOU'), Offset(p.dx, ay - 11), size: 13, color: Pal.white, stroke: Pal.blue,
            strokeWidth: 4);
      }
    }

    // HUD
    D.rrect(c, const Rect.fromLTWH(96, 44, 168, 38), 19, const Color(0xAA1B1530), border: Pal.white, borderWidth: 2);
    for (var i = 0; i < 4; i++) {
      final o = Offset(120 + i * 40.0, 63);
      final g = _pl[i];
      final gone = g.out || (g.airborne && g.layer == 1 && g.y < _layerY[1] - .5);
      c.drawCircle(o, 13, D.fill(gone ? Pal.gray : _Cast.col[i]));
      c.drawCircle(o, 13, D.stroke(Pal.ink, 2));
      D.face(c, o, 10, gone ? Face.dead : _Cast.face[i], blush: false);
      if (gone) D.line(c, o + const Offset(-13, 13), o + const Offset(13, -13), Pal.red, 4);
      // layer pip
      if (!gone) {
        c.drawCircle(o + const Offset(10, 10), 4.5, D.fill(g.layer == 0 ? const Color(0xFFFF8FB8) : const Color(0xFF3FD0E0)));
        c.drawCircle(o + const Offset(10, 10), 4.5, D.stroke(Pal.ink, 1.5));
      }
    }

    final a = _anchor;
    if (a != null) {
      c.drawCircle(a, 50, D.fill(const Color(0x33FFFFFF)));
      c.drawCircle(a, 50, D.stroke(const Color(0x88FFFFFF), 3));
      c.drawCircle(a + _stick * 50, 22, D.fill(const Color(0xCCFFFFFF)));
      c.drawCircle(a + _stick * 50, 22, D.stroke(Pal.blue, 4));
    }
    if (host.time < 2.6) {
      final hp = Offset(180 + sin(_t * 3) * 50, 560 + cos(_t * 3) * 18);
      D.hand(c, hp, _t);
      D.title(c, host.tr('run', 'RUN!'), const Offset(180, 150), size: 34, color: Pal.white);
    }
  }

  void _drawGuy(Canvas c, _Guy g, V3 base) {
    final cam = _scene.cam;
    final p = cam.project(base);
    if (p == null) return;
    final s = cam.scaleAt(base);
    final r = s * .38;
    if (!g.airborne) {
      c.drawOval(Rect.fromCenter(center: p, width: r * 2, height: r * .7), D.fill(const Color(0x44000000)));
    }
    final running = !g.airborne && (g.vx.abs() + g.vz.abs() > .3);
    final bob = running ? sin(g.run).abs() * r * .25 : 0.0;
    if (!g.airborne) {
      final st = running ? sin(g.run) * r * .3 : 0.0;
      c.drawOval(Rect.fromCenter(center: p + Offset(-r * .4 + st, -r * .1), width: r * .6, height: r * .35), D.fill(Pal.ink));
      c.drawOval(Rect.fromCenter(center: p + Offset(r * .4 - st, -r * .1), width: r * .6, height: r * .35), D.fill(Pal.ink));
    }
    var face = _Cast.face[g.id];
    if (g.airborne) {
      face = Face.shocked;
    } else if (g.nap > 0) {
      face = Face.sleepy;
    } else {
      final t = _tileAt(g.x, g.z, g.layer);
      if (t != null && t.state == 1 && t.timer < .3) face = g.id == 0 ? Face.shocked : Face.cry;
    }
    final look = Offset(g.vx.clamp(-3, 3) / 3, -g.vz.clamp(-3, 3) / 3 * .5);
    _Cast.draw(c, g.id, p + Offset(0, -r * .95 - bob), r, face: face, squash: g.squash, look: look);
    if (g.nap > 0) {
      D.text(c, 'z', p + Offset(r, -r * 2.4 - (_t * 20) % 10), size: r * .9, color: Pal.white, stroke: Pal.ink, strokeWidth: 3);
    }
  }
}

class _Hex {
  _Hex(this.q, this.r, this.layer, this.x, this.z, this.variant);
  final int q, r, layer, variant;
  final double x, z;
  int state = 0; // 0 solid, 1 shaking, 2 falling
  double timer = 0;
  double fall = 0;
  double vy = 0;
}

class _Guy {
  _Guy(this.id);
  final int id;
  double x = 0, y = 0, z = 0;
  double vx = 0, vy = 0, vz = 0;
  double dx = 0, dz = 0;
  int layer = 0;
  bool airborne = false;
  bool out = false;
  double think = 0;
  double nap = 0;
  double run = 0;
  double squash = 1;
  bool faceLeft = false;
  _Hex? goal;
}

/// The party cast: YOU (blue hero) and 3 CPU rivals.
abstract final class _Cast {
  static const col = [Color(0xFF3D6BFF), Color(0xFFFF3B5C), Color(0xFF2ECC71), Color(0xFFFFC21F)];
  static const face = [Face.happy, Face.angry, Face.smug, Face.sleepy];

  static void draw(Canvas c, int who, Offset o, double r,
      {Face? face, double squash = 1, Offset look = Offset.zero}) {
    final sq = squash;
    final topY = o.dy + r * (sq - 1) * .5 - r * .95 / sq;
    if (who == 0) {
      D.line(c, Offset(o.dx, topY + 2), Offset(o.dx + r * .15, topY - r * .45), Pal.ink, max(1.5, r * .1));
      D.star(c, Offset(o.dx + r * .15, topY - r * .55), r * .32, Pal.yellow, border: Pal.ink);
    } else if (who == 1) {
      final tuft = Path();
      for (var k = -1; k <= 1; k++) {
        final bx = o.dx + k * r * .38;
        tuft
          ..moveTo(bx - r * .22, topY + r * .2)
          ..lineTo(bx + k * r * .12, topY - r * .42)
          ..lineTo(bx + r * .22, topY + r * .2)
          ..close();
      }
      c.drawPath(tuft, D.fill(const Color(0xFFB8173A)));
      c.drawPath(tuft, D.stroke(Pal.ink, max(1.2, r * .07)));
    }
    D.blob(c, o, r, col[who], face: face ?? _Cast.face[who], look: look, squash: sq);
    final fy = o.dy + r * (sq - 1) * .5;
    if (who == 2) {
      final g = D.stroke(Pal.ink, max(1.2, r * .08));
      final sx = 1 / sqrt(sq);
      for (final s in [-1.0, 1.0]) {
        c.drawCircle(Offset(o.dx + s * r * .34 * sx, fy - r * .06 / sq), r * .26, g);
      }
      D.line(c, Offset(o.dx - r * .1 * sx, fy - r * .08 / sq), Offset(o.dx + r * .1 * sx, fy - r * .08 / sq), Pal.ink,
          max(1.2, r * .07));
    } else if (who == 3) {
      final b = Offset(o.dx + r * .55, topY + r * .28);
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
      c.drawCircle(b, r * .12, D.fill(Pal.pink));
    }
  }
}
