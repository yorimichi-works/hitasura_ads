import '../engine/engine.dart';

/// No.012 Helix Drop — 3D helix tower. The ball bounces in place; drag
/// sideways to spin the tower so the ball drops through the gaps. Red = death.
/// Drop 3 rings without bouncing → FIREBALL smashes the next platform.
class G012 extends MiniGame {
  static const _rings = 10;
  static const _seg = 12;
  static const _segA = pi * 2 / _seg;
  static const _gapY = 3.0;
  static const _thick = .45;
  static const _ri = .62, _ro = 2.65;
  static const _ballR = .36;
  static const _ballZ = -1.72;
  static const _gravity = -34.0;
  static const _bounceV = 11.5;

  final scene = Scene3();
  final List<List<int>> _types = []; // 0 solid, 1 gap, 2 red
  final List<Mesh> _ringMesh = [];
  final List<List<double>> _splats = [];
  final List<double> _passT = []; // <0 still there, >=0 flying away
  final List<bool> _smashed = [];
  final List<_Piece> _pieces = [];
  late final Mesh _pole;
  late final Mesh _poleAlt;
  late final Mesh _goal;
  late final Mesh _goalRing;
  late final Mesh _chunk;

  double _t = 0;
  double _theta = 0;
  double _by = 0, _vy = 0;
  int _next = 0;
  int _passed = 0;
  double _squash = 0;
  double _camY = 0;
  double _camTarget = 0;
  bool _dead = false;
  bool _won = false;
  double _lastX = 0;
  bool _dragging = false;
  int _keyDir = 0;
  double _dragHint = 1;

  static Color _ringCol(int i) => D.hsv(190 + i * 17.0, .5, 1);

  @override
  void init() {
    scene.ambient = .6;
    scene.diffuse = .5;
    scene.light = const V3(-.3, 1, -.6).normalized;
    var prevGap = -1, prevGapW = 0;
    const startSeg = 9; // ball sits over local angle -pi/2 → segment 9
    for (var i = 0; i < _rings; i++) {
      final t = List<int>.filled(_seg, 0);
      final gw = i < 3 ? 3 : 2;
      int gs;
      if (i == 0) {
        gs = (startSeg + 3 + randInt(5)) % _seg; // never under the ball at start
      } else {
        gs = (prevGap + 3 + randInt(7)) % _seg;
      }
      for (var k = 0; k < gw; k++) {
        t[(gs + k) % _seg] = 1;
      }
      // safe landing zone = under the previous gap (or the start position)
      final safe = <int>{};
      if (i == 0) {
        safe.addAll([startSeg - 1, startSeg, startSeg + 1].map((e) => e % _seg));
      } else {
        for (var k = -1; k <= prevGapW; k++) {
          safe.add((prevGap + k + _seg) % _seg);
        }
      }
      final reds = i == 0 ? 1 : min(1 + i ~/ 3, 3);
      var placed = 0;
      for (var tries = 0; tries < 40 && placed < reds; tries++) {
        final s = randInt(_seg);
        if (t[s] != 0 || safe.contains(s)) continue;
        t[s] = 2;
        placed++;
        if (i >= 5 && placed < reds && t[(s + 1) % _seg] == 0 && !safe.contains((s + 1) % _seg)) {
          t[(s + 1) % _seg] = 2;
          placed++;
        }
      }
      _types.add(t);
      _ringMesh.add(_buildRing(t, _ringCol(i)));
      _splats.add([]);
      _passT.add(-1);
      _smashed.add(false);
      prevGap = gs;
      prevGapW = gw;
    }
    _pole = Mesh.cylinder(.5, _gapY, const Color(0xFFFFF4E8), seg: 12);
    _poleAlt = Mesh.cylinder(.5, _gapY, const Color(0xFFFFD6E6), seg: 12);
    _goal = Mesh.cylinder(2.9, .5, const Color(0xFFFFC53D), seg: 16, cap: const Color(0xFFFFD84D));
    _goalRing = Mesh.cylinder(1.6, .52, Pal.pink, seg: 16, cap: const Color(0xFFFF7AD0));
    _chunk = Mesh.box(.9, _thick, .9, Pal.white);
    _by = 1.6;
    _vy = 0;
  }

  Mesh _buildRing(List<int> types, Color col) {
    final v = <V3>[];
    final f = <Face3>[];
    final side = Color.lerp(col, Pal.ink, .25)!;
    const red = Color(0xFFFF2D4B);
    const redSide = Color(0xFFB3122C);
    const sub = 2;
    const yt = 0.0, yb = -_thick;
    for (var s = 0; s < _seg; s++) {
      final ty = types[s];
      if (ty == 1) continue;
      final top = ty == 2 ? red : col;
      final sd = ty == 2 ? redSide : side;
      for (var k = 0; k < sub; k++) {
        final a0 = (s + k / sub) * _segA, a1 = (s + (k + 1) / sub) * _segA;
        final c0 = cos(a0), s0 = sin(a0), c1 = cos(a1), s1 = sin(a1);
        final b = v.length;
        v.addAll([
          V3(_ri * c0, yt, _ri * s0), V3(_ri * c1, yt, _ri * s1), V3(_ro * c1, yt, _ro * s1), V3(_ro * c0, yt, _ro * s0),
          V3(_ro * c0, yb, _ro * s0), V3(_ro * c1, yb, _ro * s1),
        ]);
        f.add(Face3([b, b + 1, b + 2, b + 3], top));
        f.add(Face3([b + 3, b + 2, b + 5, b + 4], sd));
      }
      // end caps next to gaps
      for (final edge in [s, s + 1]) {
        final nb = edge == s ? (s - 1 + _seg) % _seg : (s + 1) % _seg;
        if (types[nb] != 1) continue;
        final a = edge * _segA;
        final b = v.length;
        v.addAll([
          V3(_ri * cos(a), yt, _ri * sin(a)), V3(_ro * cos(a), yt, _ro * sin(a)),
          V3(_ro * cos(a), yb, _ro * sin(a)), V3(_ri * cos(a), yb, _ri * sin(a)),
        ]);
        f.add(Face3([b, b + 1, b + 2, b + 3], sd));
      }
    }
    return Mesh(v, f, doubleSided: true);
  }

  double _ringTop(int i) => -i * _gapY;

  int _segUnderBall(int ring) {
    var a = (-pi / 2 + _theta) % (pi * 2);
    if (a < 0) a += pi * 2;
    return (a / _segA).floor() % _seg;
  }

  @override
  void update(double dt) {
    _t += dt;
    _squash = M.approach(_squash, 0, 9, dt);
    if (_keyDir != 0 && !_dead) _theta -= _keyDir * 3.2 * dt;
    for (var i = 0; i < _passT.length; i++) {
      if (_passT[i] >= 0) _passT[i] += dt;
    }
    for (final p in _pieces) {
      p.vel = p.vel + V3(0, -20 * dt, 0);
      p.pos = p.pos + p.vel * dt;
      p.rot += p.spin * dt;
    }
    _pieces.removeWhere((p) => p.pos.y < _camY - 14);

    if (!_dead) {
      _vy += _gravity * dt;
      _by += _vy * dt;
      if (_next < _rings) {
        final top = _ringTop(_next);
        if (_by - _ballR <= top && _vy < 0 && _by - _ballR > top - _thick - .6) {
          final ty = _types[_next][_segUnderBall(_next)];
          if (ty == 1) {
            if (_by + _ballR < top) _passRing(false);
          } else if (_passed >= 3) {
            _smash();
          } else if (ty == 2) {
            _die();
          } else {
            _bounce(top);
          }
        }
      } else {
        final top = _ringTop(_rings);
        if (_by - _ballR <= top && _vy < 0) {
          _by = top + _ballR;
          _vy = _bounceV * .8;
          _squash = 1;
          if (!_won) _win();
          host.sfx(Sfx.bounce, volume: .6);
        }
      }
    } else {
      _vy = 0;
    }
    _camTarget = min(_camTarget, _by - 1.0);
    _camY = M.approach(_camY, _camTarget, 7, dt);
    if (_passed >= 3 && !_dead) {
      final sp = scene.cam.project(V3(0, _by, _ballZ));
      if (sp != null && chance(.8)) {
        host.fx.add(Particle(
            pos: sp + Offset(rand(-6, 6), rand(-6, 6)), vel: Offset(rand(-30, 30), rand(-80, -20)), life: .35,
            color: pick(const [Pal.orange, Pal.yellow, Pal.red]), size: 12, grow: -20));
      }
    }
  }

  void _bounce(double top) {
    _by = top + _ballR;
    _vy = _bounceV;
    _squash = 1;
    _passed = 0;
    final seg = _segUnderBall(_next);
    if (_splats[_next].length < 8) _splats[_next].add((seg + .5) * _segA + rand(-.15, .15));
    host.sfx(Sfx.bounce, volume: .7, rate: 1 + rand(-.05, .05));
    final sp = scene.cam.project(V3(0, top, _ballZ));
    if (sp != null) {
      host.fx.burst(sp, Pal.orange, count: 6, speed: 120, size: 5, gravity: 500);
    }
  }

  void _passRing(bool smashed) {
    _passT[_next] = 0;
    _next++;
    _passed++;
    final sp = scene.cam.project(V3(0, _by, _ballZ)) ?? const Offset(180, 330);
    host.addScore(10 * _passed, sp + const Offset(40, 0));
    host.sfx(Sfx.whoosh, volume: .6, rate: 1 + _passed * .12);
    if (_passed == 3 && !smashed) {
      host.sfx(Sfx.fire);
      host.fx.pop(host.tr('fever', 'FEVER!'), const Offset(180, 200), color: Pal.orange, size: 34);
    } else if (_passed >= 2) {
      host.fx.pop('x$_passed', sp + const Offset(-50, -20), color: Pal.yellow, size: 26);
    }
    if (_next >= _rings) {
      host.sfx(Sfx.drumroll, volume: .6);
    }
  }

  void _smash() {
    final i = _next;
    _smashed[i] = true;
    final top = _ringTop(i);
    for (var s = 0; s < _seg; s++) {
      if (_types[i][s] == 1) continue;
      final a = (s + .5) * _segA - _theta; // world angle
      final dir = V3(cos(a), 0, sin(a));
      _pieces.add(_Piece(V3(0, top - _thick / 2, 0) + dir * 1.7, dir * rand(5, 9) + V3(0, rand(3, 8), 0), rand(-8, 8),
          _types[i][s] == 2 ? const Color(0xFFFF2D4B) : _ringCol(i)));
    }
    host.sfx(Sfx.explode);
    host.sfx(Sfx.crash, volume: .6);
    host.shake(9);
    host.flash(Pal.orange, .12);
    host.hitStop(.05);
    host.punch(.05);
    final sp = scene.cam.project(V3(0, top, _ballZ)) ?? const Offset(180, 330);
    host.fx.burst(sp, Pal.orange, colors: const [Pal.orange, Pal.yellow, Pal.red], count: 26, speed: 380, shape: PartShape.star);
    host.fx.pop(host.tr('wow', 'WOW!'), sp + const Offset(0, -60), color: Pal.yellow, size: 34);
    host.addScore(50, sp);
    _passT[i] = 99; // hidden immediately
    _next++;
    _passed = 0;
    _vy = _bounceV * .55;
    if (_next >= _rings) host.sfx(Sfx.drumroll, volume: .6);
  }

  void _die() {
    _dead = true;
    final top = _ringTop(_next);
    _by = top + _ballR * .4;
    host.sfx(Sfx.splat);
    host.sfx(Sfx.jingleLose, volume: .8);
    host.shake(10);
    host.flash(Pal.red, .15);
    final sp = scene.cam.project(V3(0, top, _ballZ)) ?? const Offset(180, 330);
    host.fx.burst(sp, Pal.orange, colors: const [Pal.orange, Pal.yellow], count: 24, speed: 300, gravity: 700);
    host.fx.pop(host.tr('oops', 'OOPS!'), sp + const Offset(0, -60), color: Pal.red, size: 34);
    host.lose();
  }

  void _win() {
    _won = true;
    host.sfx(Sfx.splash);
    host.sfx(Sfx.fanfare);
    host.fx.confetti(count: 120);
    host.flash(Pal.white, .2);
    host.punch(.06);
    final sp = scene.cam.project(V3(0, _ringTop(_rings), _ballZ)) ?? const Offset(180, 400);
    host.fx.burst(sp, Pal.yellow, colors: Pal.candy, count: 40, speed: 460, shape: PartShape.star, gravity: 400);
    host.fx.ring(sp, Pal.white, size: 160, life: .5);
    host.fx.pop(host.tr('clear', 'CLEAR!'), const Offset(180, 220), size: 48, life: 1.4);
    final tl = host.timeLeft;
    host.win(stars: tl > 7 ? 3 : (tl > 3 ? 2 : 1));
  }

  @override
  void onDown(Offset p) {
    _dragging = true;
    _lastX = p.dx;
  }

  @override
  void onMove(Offset p) {
    if (!_dragging || _dead) return;
    final dx = p.dx - _lastX;
    _lastX = p.dx;
    _theta -= dx * .0115;
    if (dx.abs() > 1) _dragHint = 0;
  }

  @override
  void onUp(Offset p) => _dragging = false;

  @override
  void onKey(String key, bool down) {
    if (key == 'left') _keyDir = down ? -1 : (_keyDir == -1 ? 0 : _keyDir);
    if (key == 'right') _keyDir = down ? 1 : (_keyDir == 1 ? 0 : _keyDir);
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    final depth = _next / _rings;
    final hue = 250 + depth * 80;
    D.gradientBg(c, [D.hsv(hue, .35, 1), D.hsv(hue + 30, .55, .9), D.hsv(hue + 60, .7, .65)]);
    for (var i = 0; i < 16; i++) {
      final y = ((i * 83 - _camY * 40 + _t * 10) % 700 + 700) % 700 - 30;
      final x = (i * 97.0) % 360;
      c.drawCircle(Offset(x, y), 4 + (i % 4) * 3, D.fill(const Color(0x1FFFFFFF)));
    }

    scene.clear();
    scene.cam
      ..center = const Offset(180, 320)
      ..focal = 400
      ..pos = V3(0, _camY + 6.2, -8.2)
      ..lookAt(V3(0, _camY - 1.6, 0));
    scene.fogColor = D.hsv(hue + 60, .6, .7);
    scene.fogNear = 12;
    scene.fogFar = 26;

    final from = max(0, _next - 2), to = min(_rings - 1, _next + 4);
    // pole
    for (var i = max(0, from - 1); i <= to + 1; i++) {
      scene.add(i.isEven ? _pole : _poleAlt, pos: V3(0, _ringTop(i) - _gapY / 2 + .02, 0), rotY: _theta);
    }
    for (var i = from; i <= to; i++) {
      final pt = _passT[i];
      if (pt > .6) continue;
      if (pt >= 0) {
        final k = pt / .6;
        scene.add(_ringMesh[i], pos: V3(0, _ringTop(i) + k * 1.5, 0), rotY: _theta, scale3: V3(1 + k * 1.2, 1, 1 + k * 1.2), alpha: 1 - k);
        continue;
      }
      scene.add(_ringMesh[i], pos: V3(0, _ringTop(i), 0), rotY: _theta);
      for (final a in _splats[i]) {
        final wa = a - _theta;
        final wp = V3(cos(wa) * 1.72, _ringTop(i) + .02, sin(wa) * 1.72);
        final sp = scene.cam.project(wp);
        if (sp == null) continue;
        final lift = wp + (scene.cam.pos - wp).normalized * .5;
        scene.addSprite(lift, (cv, _, s) {
          final r = scene.cam.scaleAt(wp);
          cv.drawOval(Rect.fromCenter(center: sp, width: r * .75, height: r * .3), D.fill(const Color(0xCCFF8A1F)));
          cv.drawCircle(sp + Offset(r * .3, -r * .06), r * .07, D.fill(const Color(0xCCFF8A1F)));
        });
      }
    }
    if (_next >= _rings - 3) {
      scene.add(_goal, pos: V3(0, _ringTop(_rings) - .25, 0), rotY: _theta);
      scene.add(_goalRing, pos: V3(0, _ringTop(_rings) - .24, 0), rotY: _theta);
    }
    for (final p in _pieces) {
      scene.add(_chunk, pos: p.pos, rotX: p.rot, rotZ: p.rot * .7, tint: p.color);
    }
    // ball as a shaded billboard with a depth bias toward the camera
    final bp = V3(0, _by, _ballZ);
    final bpScreen = scene.cam.project(bp);
    if (bpScreen != null) {
      final lift = bp + (scene.cam.pos - bp).normalized * .7;
      scene.addSprite(lift, (cv, _, s) => _drawBall(cv, bpScreen, scene.cam.scaleAt(bp) * _ballR));
    }
    scene.render(c);

    _renderHud(c);
    if (_dragHint > 0 && host.time < 2.6) {
      final x = 180 + sin(_t * 3) * 70;
      D.hand(c, Offset(x, 520), _t);
      D.arrow(c, const Offset(120, 590), const Offset(-1, 0), 50, Pal.white, width: 9);
      D.arrow(c, const Offset(240, 590), const Offset(1, 0), 50, Pal.white, width: 9);
    }
  }

  void _drawBall(Canvas c, Offset o, double r) {
    if (_dead) {
      c.drawOval(Rect.fromCenter(center: o + Offset(0, r * .5), width: r * 3.4, height: r * 1.1), D.fill(Pal.orange));
      c.drawOval(Rect.fromCenter(center: o + Offset(-r * .4, r * .4), width: r * 1.2, height: r * .4), D.fill(const Color(0x66FFFFFF)));
      D.face(c, o + Offset(0, r * .45), r * .7, Face.dead, blush: false);
      return;
    }
    final sq = 1 + _squash * .35;
    final fire = _passed >= 3;
    if (fire) {
      for (var i = 0; i < 3; i++) {
        c.drawCircle(o, r * (1.9 - i * .3) + sin(_t * 30 + i) * 2,
            D.fill([const Color(0x55FF3B00), const Color(0x88FF8A1F), const Color(0xAAFFD23F)][i]));
      }
    }
    c.save();
    c.translate(o.dx, o.dy + r * (sq - 1) * .6);
    c.scale(sq, 1 / sq);
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    c.drawCircle(Offset.zero, r,
        Paint()
          ..shader = RadialGradient(
                  center: const Alignment(-.35, -.4),
                  colors: fire ? const [Color(0xFFFFF3B0), Color(0xFFFF6A00)] : const [Color(0xFFFFE0A0), Color(0xFFFF7A1F)])
              .createShader(rect));
    c.drawCircle(Offset.zero, r, D.stroke(const Color(0xFF7A2E00), max(1.5, r * .08)));
    c.drawCircle(Offset(-r * .35, -r * .4), r * .22, D.fill(const Color(0xCCFFFFFF)));
    D.face(c, Offset(0, r * .1), r * .75, fire ? Face.angry : (_squash > .4 ? Face.happy : Face.neutral), blush: true);
    c.restore();
  }

  void _renderHud(Canvas c) {
    const y = 66.0;
    final prog = M.clamp01(_next / _rings);
    D.bar(c, const Rect.fromLTWH(78, y - 8, 204, 16), prog, Pal.orange, back: const Color(0x55FFFFFF), border: Pal.ink);
    for (final (x, n, on) in [(58.0, 1, true), (302.0, 2, prog >= 1)]) {
      c.drawCircle(Offset(x, y), 18, D.fill(on ? Pal.orange : Pal.white));
      c.drawCircle(Offset(x, y), 18, D.stroke(Pal.ink, 3));
      if (n == 1) {
        D.text(c, '${min(_next, _rings)}', Offset(x, y), size: 16, color: on ? Pal.white : Pal.ink, stroke: on ? Pal.ink : null);
      } else {
        D.star(c, Offset(x, y), 10, on ? Pal.yellow : Pal.gray, border: Pal.ink);
      }
    }
    if (_passed >= 2 && !_dead) {
      D.text(c, 'x$_passed', const Offset(180, 104), size: 30 + _passed * 3.0, color: _passed >= 3 ? Pal.orange : Pal.yellow, stroke: Pal.ink);
    }
  }
}

class _Piece {
  _Piece(this.pos, this.vel, this.spin, this.color);
  V3 pos;
  V3 vel;
  final double spin;
  double rot = 0;
  final Color color;
}
