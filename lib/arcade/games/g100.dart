import 'dart:math' as math;
import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.100 Neon Highway 3D — SUPER RARE synthwave racer.
/// Swipe to switch lanes, dodge traffic, grab NITRO (smash through cars!),
/// reach the finish gate. Crash = glitch-out.
class G100 extends MiniGame {
  static const _goal = 1200.0;
  static const _laneW = 3.2;
  static const _roadHalf = _laneW * 2;
  static const _trafficSpeed = 24.0;

  final scene = Scene3();
  late final List<Mesh> _carMeshes; // 0 = player
  late final Mesh _truck;
  late final Mesh _nitroMesh;
  late final Mesh _gatePost;
  late final Mesh _gateBeam;

  double _t = 0;
  double _dist = 0;
  double _speed = 42;
  int _lane = 1;
  double _x = -_laneW / 2;
  double _vx = 0;
  double _nitro = 0; // seconds left
  double _nitroFx = 0; // 0..1 smoothed
  bool _crashed = false;
  double _crashT = 0;
  double _spin = 0;
  int _nearMiss = 0;
  int _smashed = 0;
  double _nextRow = 110;
  int _prevFree = 1;
  int _rows = 0;
  double _laneBump = 0;
  double _swapFlash = 0;
  bool _finished = false;
  final List<_Car> _cars = [];
  final List<_Nitro> _nitros = [];
  final List<double> _gates = [300, 600, 900, _goal];
  int _gatePassed = 0;

  // input
  Offset? _anchor;
  Offset? _downAt;
  double _downT = 0;
  bool _swiped = false;

  static double _laneX(int l) => (l - 1.5) * _laneW;

  @override
  void init() {
    scene
      ..ambient = .72
      ..diffuse = .45
      ..light = const V3(.3, 1, -.8).normalized
      ..fogColor = const Color(0xFF2A0845)
      ..fogNear = 60
      ..fogFar = 175;
    _carMeshes = [
      _buildCar(const Color(0xFFFF2E97), const Color(0xFF29F0FF)),
      _buildCar(const Color(0xFF7B2FFF), const Color(0xFFFF4FD8)),
      _buildCar(const Color(0xFF16C2C2), const Color(0xFFFFE14D)),
      _buildCar(const Color(0xFFFF8A1F), const Color(0xFF29F0FF)),
      _buildCar(const Color(0xFFE8E3FF), const Color(0xFFFF2E97)),
    ];
    _truck = Mesh.merge([
      (Mesh.box(2.4, 2.6, 6.2, const Color(0xFF3A2466),
          colors: const [Color(0xFF55358F), Color(0xFF221540), Color(0xFF4A2F7A), Color(0xFF2E1C55), Color(0xFF3A2466), Color(0xFF3A2466)]),
          const V3(0, 1.7, -.8)),
      (Mesh.box(2.3, 1.6, 1.8, const Color(0xFFFF2E97)), const V3(0, 1.2, 3.3)),
      (Mesh.box(2.0, .6, .1, const Color(0xFF29F0FF)), const V3(0, 1.75, 4.21)),
      (Mesh.box(2.2, .14, .06, const Color(0xFFFF1A4A)), const V3(0, .7, -3.93)),
      (Mesh.box(.45, .7, .7, const Color(0xFF0A0612)), const V3(-1.1, .35, 2.9)),
      (Mesh.box(.45, .7, .7, const Color(0xFF0A0612)), const V3(1.1, .35, 2.9)),
      (Mesh.box(.45, .7, .7, const Color(0xFF0A0612)), const V3(-1.1, .35, -2.9)),
      (Mesh.box(.45, .7, .7, const Color(0xFF0A0612)), const V3(1.1, .35, -2.9)),
    ]);
    _nitroMesh = Mesh.merge([
      (Mesh.cylinder(.42, 1.1, const Color(0xFF29F0FF), seg: 8, cap: const Color(0xFFE8FFFF)), V3.zero),
      (Mesh.cylinder(.2, .3, const Color(0xFFE8E3FF), seg: 6), const V3(0, .7, 0)),
      (Mesh.cylinder(.44, .14, const Color(0xFFFF2E97), seg: 8), const V3(0, .1, 0)),
    ]);
    _gatePost = Mesh.box(.5, 7, .5, const Color(0xFF1A0B33));
    _gateBeam = Mesh.box(_roadHalf * 2 + 2.6, .7, .5, const Color(0xFF1A0B33),
        colors: const [Color(0xFF3A1A66), Color(0xFFFF2E97), Color(0xFFFF2E97), Color(0xFFFF2E97), Color(0xFF1A0B33), Color(0xFF1A0B33)]);
  }

  /// Low-poly wedge sports car facing +z, wheels on y=0.
  static Mesh _buildCar(Color body, Color neon) {
    // side profile (z, y), convex, extruded along x
    const prof = [(-2.1, .28), (2.15, .28), (2.3, .5), (.7, .82), (-2.1, .9)];
    final v = <V3>[];
    for (final sx in [-.98, .98]) {
      for (final (z, y) in prof) {
        v.add(V3(sx, y, z));
      }
    }
    final f = <Face3>[
      Face3([0, 1, 2, 3, 4], body),
      Face3([5, 6, 7, 8, 9], body),
    ];
    for (var i = 0; i < 5; i++) {
      final j = (i + 1) % 5;
      f.add(Face3([i, j, j + 5, i + 5], i == 3 ? Color.lerp(body, Pal.white, .12)! : body));
    }
    final hull = Mesh(v, f, fixWinding: true);
    final cabin = Mesh([
      const V3(-.82, .8, -1.5), const V3(.82, .8, -1.5), const V3(.82, .84, .55), const V3(-.82, .84, .55),
      const V3(-.64, 1.32, -1.2), const V3(.64, 1.32, -1.2), const V3(.64, 1.32, -.25), const V3(-.64, 1.32, -.25),
    ], [
      Face3([0, 1, 2, 3], const Color(0xFF140A26)),
      Face3([4, 5, 6, 7], const Color(0xFF1C0F36)),
      Face3([3, 2, 6, 7], const Color(0xFF6FE8FF)), // windshield
      Face3([0, 1, 5, 4], const Color(0xFF2A1450)), // rear window
      Face3([0, 3, 7, 4], const Color(0xFF231244)),
      Face3([1, 2, 6, 5], const Color(0xFF231244)),
    ], fixWinding: true);
    const tire = Color(0xFF07040D);
    return Mesh.merge([
      (hull, V3.zero),
      (cabin, V3.zero),
      (Mesh.box(2.0, .08, .4, Color.lerp(body, Pal.ink, .3)!), const V3(0, 1.08, -1.95)),
      (Mesh.box(.1, .2, .2, Color.lerp(body, Pal.ink, .3)!), const V3(-.7, .97, -1.95)),
      (Mesh.box(.1, .2, .2, Color.lerp(body, Pal.ink, .3)!), const V3(.7, .97, -1.95)),
      (Mesh.box(1.8, .14, .06, const Color(0xFFFF1A4A)), const V3(0, .7, -2.13)),
      (Mesh.box(.06, .08, 3.8, neon), const V3(-1.0, .5, 0)),
      (Mesh.box(.06, .08, 3.8, neon), const V3(1.0, .5, 0)),
      (Mesh.box(.36, .56, .72, tire), const V3(-.9, .28, 1.3)),
      (Mesh.box(.36, .56, .72, tire), const V3(.9, .28, 1.3)),
      (Mesh.box(.38, .58, .76, tire), const V3(-.9, .29, -1.3)),
      (Mesh.box(.38, .58, .76, tire), const V3(.9, .29, -1.3)),
    ]);
  }

  // ------------------------------------------------------------ gameplay ---

  void _switch(int d) {
    if (_crashed || host.finished && !_finished) return;
    final nl = (_lane + d).clamp(0, 3);
    if (nl == _lane) {
      _laneBump = d.toDouble();
      host.sfx(Sfx.thud, volume: .4, rate: 1.4);
      return;
    }
    _lane = nl;
    _swapFlash = 1;
    host.sfx(Sfx.swipe, volume: .6, rate: 1.1 + _nitroFx * .3);
  }

  void _spawnRow(double z) {
    _rows++;
    final p = (z / _goal).clamp(0.0, 1.0);
    // free lane drifts at most 2 lanes from the previous one
    var free = (_prevFree + randInt(5) - 2).clamp(0, 3);
    if (chance(.3)) free = randInt(4);
    if ((free - _prevFree).abs() > 2) free = _prevFree;
    _prevFree = free;
    var blocked = 1;
    if (p > .15 && chance(.35 + p * .4)) blocked = 2;
    if (p > .55 && chance(.2)) blocked = 3;
    final lanes = [for (var l = 0; l < 4; l++) if (l != free) l]..shuffle(host.rng);
    for (var i = 0; i < blocked; i++) {
      final truck = chance(.18);
      _cars.add(_Car(lanes[i], _laneX(lanes[i]), z + rand(-2.5, 2.5), truck ? -1 : 1 + randInt(4),
          _trafficSpeed + rand(-1.5, 1.5)));
    }
    if (_rows % 4 == 2 || (_rows > 3 && chance(.12))) {
      _nitros.add(_Nitro(_laneX(free), z + rand(-4, 4)));
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _laneBump = M.approach(_laneBump, 0, 10, dt);
    _swapFlash = M.approach(_swapFlash, 0, 6, dt);
    if (_crashed) {
      _crashT += dt;
      _speed = M.approach(_speed, 0, 3, dt);
      _spin += dt * (6 - _crashT * 3).clamp(0, 6);
      _dist += _speed * dt;
      for (final c in _cars) {
        c.z += c.speed * dt;
      }
      if (_crashT < .8 && chance(.5)) host.sfx(Sfx.glitch, volume: .3, rate: rand(.7, 1.4));
      return;
    }
    // speed ramps up; nitro gives a big kick
    if (_nitro > 0) _nitro -= dt;
    _nitroFx = M.approach(_nitroFx, _nitro > 0 ? 1 : 0, 5, dt);
    final base = (42 + host.time * 1.6) * (.9 + .1 * host.speed);
    _speed = M.approach(_speed, base * (1 + _nitroFx * .55), 3, dt);
    _dist += _speed * dt;
    final nx = M.approach(_x, _laneX(_lane), 13, dt);
    _vx = (nx - _x) / max(dt, 1e-4);
    _x = nx;

    while (_nextRow < _dist + 190 && _nextRow < _goal - 40) {
      _spawnRow(_nextRow);
      final p = (_nextRow / _goal).clamp(0.0, 1.0);
      _nextRow += M.lerp(60, 36, p) * (1.05 - .05 * host.speed);
    }

    for (final c in _cars) {
      if (c.flying) {
        c.vy -= 22 * dt;
        c.y += c.vy * dt;
        c.x += c.vx * dt;
        c.z += (_speed * .85) * dt;
        c.rot += c.spinV * dt;
        continue;
      }
      c.z += c.speed * dt;
      final dz = c.z - _dist;
      final halfLen = c.mesh < 0 ? 4.0 : 2.3;
      final dx = (c.x - _x).abs();
      if (dz.abs() < halfLen + 2.1 && dx < (c.mesh < 0 ? 2.25 : 1.9)) {
        if (_nitro > 0 || _finished) {
          _smash(c);
        } else {
          _crash(c);
          return;
        }
      }
      // near miss: an adjacent-lane car slips past right beside us
      if (!c.passed && dz < -halfLen) {
        c.passed = true;
        if (dx < _laneW * 1.25 && dx > 1.9) {
          _nearMiss++;
          final s = scene.cam.project(V3(c.x, 1.5, c.z)) ?? const Offset(180, 380);
          host.fx.pop(host.tr('near_miss', 'NEAR MISS!'), Offset(s.dx.clamp(80.0, 280.0), 300), color: const Color(0xFF29F0FF), size: 22);
          host.addScore(50);
          host.sfx(Sfx.whoosh, volume: .8, rate: 1.4);
        }
      }
    }
    _cars.removeWhere((c) => c.z < _dist - 12 || c.y < -5);
    for (final n in _nitros) {
      if (n.got) continue;
      if ((n.z - _dist).abs() < 2.4 && (n.x - _x).abs() < 1.7) {
        n.got = true;
        _nitro = 2.6;
        final s = scene.cam.project(V3(n.x, 1, n.z)) ?? const Offset(180, 420);
        host.fx.pop(host.tr('nitro', 'NITRO!'), const Offset(180, 250), color: const Color(0xFF29F0FF), size: 40, life: 1);
        host.fx.ring(s, const Color(0xFF29F0FF), size: 160, life: .4);
        host.fx.burst(s, const Color(0xFF29F0FF), count: 24, speed: 340, colors: const [Color(0xFF29F0FF), Pal.white, Color(0xFFFF2E97)]);
        host.sfx(Sfx.powerup, volume: .9);
        host.sfx(Sfx.zap, volume: .7);
        host.punch(.05);
        host.shake(5);
        host.addScore(100);
      }
    }
    _nitros.removeWhere((n) => n.z < _dist - 10);
    // gates
    if (_gatePassed < _gates.length && _dist >= _gates[_gatePassed]) {
      final g = _gates[_gatePassed];
      _gatePassed++;
      if (g >= _goal) {
        _finished = true;
        host.sfx(Sfx.fanfare);
        host.fx.confetti(count: 90);
        host.fx.pop(host.tr('goal', 'GOAL!'), const Offset(180, 230), color: Pal.yellow, size: 48, life: 1.4);
        host.flash(const Color(0xFFFF2E97), .25);
        host.shake(8);
        final tm = host.time;
        host.win(stars: tm < 19.5 || _smashed >= 2 ? 3 : (tm < 21.5 ? 2 : 1));
      } else {
        host.sfx(Sfx.levelup, volume: .7);
        host.fx.pop('${(g / 1000).toStringAsFixed(1)} km', const Offset(180, 240), color: const Color(0xFFFF4FD8), size: 30);
      }
    }
    // speed streaks
    final streak = (_speed - 55) / 40 + _nitroFx;
    if (streak > 0 && chance(min(1, streak * .8))) {
      final side = chance(.5) ? -1.0 : 1.0;
      final p = Offset(180 + side * rand(70, 175), rand(260, 630));
      host.fx.add(Particle(
          pos: p,
          vel: (p - const Offset(180, 290)) * (3 + _nitroFx * 3),
          life: .22,
          color: _nitroFx > .3 ? const Color(0xDD29F0FF) : const Color(0x99FFFFFF),
          size: 3,
          shape: PartShape.spark));
    }
    // nitro exhaust flames
    if (_nitroFx > .1) {
      for (final sx in [-.55, .55]) {
        final s = scene.cam.project(V3(_x + sx, .5, _dist - 2.3));
        if (s == null) continue;
        host.fx.add(Particle(
            pos: s + Offset(rand(-3, 3), rand(-2, 2)),
            vel: Offset(rand(-30, 30), rand(40, 140)),
            life: rand(.1, .22),
            color: pick(const [Color(0xFF29F0FF), Color(0xFFFFFFFF), Color(0xFF7B2FFF)]),
            size: rand(5, 10),
            drag: 2));
      }
    }
  }

  void _smash(_Car c) {
    c.flying = true;
    c.vy = rand(9, 13);
    c.vx = (c.x - _x).sign * rand(6, 12) + rand(-2, 2);
    c.spinV = rand(-9, 9);
    _smashed++;
    final s = scene.cam.project(V3(c.x, 1, c.z)) ?? const Offset(180, 380);
    host.sfx(Sfx.explode, volume: .9);
    host.sfx(Sfx.crash, volume: .6, rate: 1.3);
    host.fx.burst(s, Pal.orange, count: 26, speed: 380, colors: const [Pal.orange, Pal.yellow, Color(0xFFFF2E97), Pal.white]);
    host.fx.pop(host.tr('smash', 'SMASH!'), s + const Offset(0, -40), color: Pal.orange, size: 30);
    host.addScore(200, s);
    host.shake(9);
    host.hitStop(.05);
  }

  void _crash(_Car c) {
    _crashed = true;
    _crashT = 0;
    c.speed = _speed * .7;
    final s = scene.cam.project(V3(_x, 1, _dist + 1.5)) ?? const Offset(180, 420);
    host.sfx(Sfx.crash);
    host.sfx(Sfx.glitch, volume: 1);
    host.sfx(Sfx.explode, volume: .8);
    host.fx.burst(s, Pal.white, count: 40, speed: 420, colors: const [Color(0xFFFF2E97), Color(0xFF29F0FF), Pal.white, Pal.yellow]);
    host.flash(const Color(0xFFFF2E97), .3);
    host.shake(16, .6);
    host.hitStop(.12);
    host.lose();
  }

  @override
  void onTimeUp() {
    if (!_crashed) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // --------------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    _anchor = p;
    _downAt = p;
    _downT = _t;
    _swiped = false;
  }

  @override
  void onMove(Offset p) {
    final a = _anchor;
    if (a == null) return;
    final dx = p.dx - a.dx;
    if (dx.abs() > 34) {
      _switch(dx.sign.toInt());
      _anchor = Offset(p.dx, p.dy);
      _swiped = true;
    }
  }

  @override
  void onUp(Offset p) {
    final d = _downAt;
    _anchor = null;
    _downAt = null;
    if (d == null || _swiped) return;
    if ((p - d).distance < 20 && _t - _downT < .35) _switch(p.dx < 180 ? -1 : 1);
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'left') _switch(-1);
    if (key == 'right') _switch(1);
  }

  // -------------------------------------------------------------- render ---

  double get _horizon => scene.cam.center.dy - math.tan(scene.cam.pitch) * scene.cam.focal;

  @override
  void render(Canvas c) {
    final speedK = ((_speed - 42) / 45).clamp(0.0, 1.5);
    final bob = sin(_t * 21) * .025 * (1 + speedK) + (_crashed ? sin(_t * 50) * .1 * (1 - _crashT).clamp(0, 1) : 0);
    scene.cam
      ..center = const Offset(180, 330)
      ..focal = 310 - speedK * 38 - _nitroFx * 55
      ..pos = V3(_x * .65, 3.4 + bob, _dist - 7.8 - _nitroFx * .9)
      ..lookAt(V3(_x * .45, .4, _dist + 14));

    if (_crashed && _crashT < 1.6) {
      final rec = ui.PictureRecorder();
      final pc = Canvas(rec);
      _renderWorld(pc);
      final pic = rec.endRecording();
      _glitch(c, pic);
      pic.dispose();
    } else {
      _renderWorld(c);
    }
    _renderHud(c);
  }

  void _renderWorld(Canvas c) {
    final hz = _horizon;
    _renderSky(c, hz);
    _renderGround(c, hz);

    scene.clear();
    // palms + neon posts
    const palmGap = 22.0;
    final p0 = ((_dist - 8) / palmGap).floor();
    for (var i = p0; i < p0 + 9; i++) {
      final z = i * palmGap;
      for (final side in [-1.0, 1.0]) {
        final x = side * (_roadHalf + 4.2 + ((i * 7) % 3) * 1.1);
        final lean = side * -.12 + sin(i * 1.3) * .08;
        final alt = (i + (side > 0 ? 1 : 0)).isEven;
        scene.addSprite(V3(x, 0, z), (c, s, k) => _palm(c, s, k, lean, alt, z - _dist));
      }
    }
    // gates
    for (final g in _gates) {
      if (g < _dist - 6 || g > _dist + 200) continue;
      for (final side in [-1.0, 1.0]) {
        scene.add(_gatePost, pos: V3(side * (_roadHalf + 1.1), 3.5, g));
      }
      scene.add(_gateBeam, pos: V3(0, 7.1, g));
      final isGoal = g >= _goal;
      scene.addSprite(V3(0, 7.1, g - .3), (c, s, k) {
        final label = isGoal ? host.tr('goal', 'GOAL') : '${(g / 1000).toStringAsFixed(1)} km';
        D.text(c, label, s, size: max(6, k * .55), color: isGoal ? Pal.yellow : Pal.white, stroke: const Color(0xFFFF2E97), strokeWidth: max(1, k * .08));
      });
    }
    for (final n in _nitros) {
      if (n.got || n.z > _dist + 190) continue;
      final pos = V3(n.x, 1.0 + sin(_t * 5 + n.z) * .2, n.z);
      scene.addSprite(pos + const V3(0, -.9, 0), (c, s, k) {
        c.drawOval(Rect.fromCenter(center: s, width: 2.4 * k, height: .8 * k),
            Paint()..color = Color.fromRGBO(41, 240, 255, .35 + .15 * sin(_t * 10)));
      });
      scene.add(_nitroMesh, pos: pos, rotY: _t * 4, rotZ: .35);
      scene.addSprite(pos + const V3(0, 1.2, 0), (c, s, k) {
        if (k < 6) return;
        D.text(c, 'N2O', s, size: max(7, k * .5), color: Pal.white, stroke: const Color(0xFF0E7A99), strokeWidth: max(1, k * .1));
      });
    }
    for (final car in _cars) {
      if (car.z > _dist + 190) continue;
      final m = car.mesh < 0 ? _truck : _carMeshes[car.mesh];
      final pos = V3(car.x, car.y, car.z);
      scene.add(m, pos: pos, rotY: car.flying ? car.rot * .6 : 0, rotZ: car.flying ? car.rot : 0, rotX: car.flying ? car.rot * .3 : 0);
      if (!car.flying) {
        final rear = car.mesh < 0 ? 3.95 : 2.2;
        final w = car.mesh < 0 ? 1.1 : .75;
        scene.addSprite(V3(car.x, .72, car.z - rear - .05), (c, s, k) => _tailGlow(c, s, k, w));
      }
    }
    // player
    final pp = V3(_x, 0, _dist);
    scene.addSprite(pp + const V3(0, 0, -1), (c, s, k) {
      final flick = .75 + .25 * sin(_t * 30);
      c.drawOval(Rect.fromCenter(center: s, width: 3.4 * k, height: 1.2 * k),
          Paint()
            ..shader = RadialGradient(colors: [
              Color.fromRGBO(41, 240, 255, .55 * flick),
              const Color(0x0029F0FF),
            ]).createShader(Rect.fromCenter(center: s, width: 3.4 * k, height: 1.2 * k)));
    });
    final bank = (-_vx * .02).clamp(-.18, .18);
    scene.add(_carMeshes[0], pos: pp + V3(0, sin(_t * 30) * .01, 0), rotZ: bank, rotY: _vx * .012 + _spin + _laneBump * .05);
    if (!_crashed) scene.addSprite(pp + const V3(0, .72, -2.3), (c, s, k) => _tailGlow(c, s, k, .75));
    scene.render(c);

    // retro overlay
    Retro.scanlines(c, alpha: .07);
    Retro.vignette(c, strength: .35 + _nitroFx * .2);
    if (_nitroFx > .05) {
      c.drawRect(const Rect.fromLTWH(0, 0, 360, 640),
          Paint()
            ..shader = RadialGradient(colors: [const Color(0x00000000), Color.fromRGBO(41, 240, 255, .25 * _nitroFx)], stops: const [.6, 1])
                .createShader(const Rect.fromLTWH(0, 0, 360, 640)));
    }
  }

  void _tailGlow(Canvas c, Offset s, double k, double w) {
    final gp = Paint()..color = const Color(0x66FF1A4A);
    c.drawOval(Rect.fromCenter(center: s, width: w * 3.2 * k, height: .6 * k), gp);
    c.drawOval(Rect.fromCenter(center: s + Offset(-w * k, 0), width: .3 * k, height: .12 * k), D.fill(const Color(0xFFFFD0DA)));
    c.drawOval(Rect.fromCenter(center: s + Offset(w * k, 0), width: .3 * k, height: .12 * k), D.fill(const Color(0xFFFFD0DA)));
  }

  void _renderSky(Canvas c, double hz) {
    D.gradientBg(c, const [Color(0xFF0B0221), Color(0xFF2A0845), Color(0xFF8A1A7A), Color(0xFFFF4F8B)],
        rect: Rect.fromLTRB(0, 0, 360, hz + 2));
    // stars
    for (var i = 0; i < 40; i++) {
      final x = (i * 97.3 + 13) % 360;
      final y = 40 + (i * 53.1) % max(20, hz - 150);
      final tw = .3 + .7 * M.wave(_t * .8 + i * .21, .6);
      c.drawCircle(Offset(x, y), i % 5 == 0 ? 1.6 : 1, Paint()..color = Color.fromRGBO(255, 230, 255, tw));
    }
    // sun with retro stripes
    final sx = 180 - _x * 3;
    final sc = Offset(sx, hz - 30);
    const r = 92.0;
    c.drawCircle(sc, r + 26, Paint()..color = const Color(0x33FF4F8B));
    c.drawCircle(sc, r + 12, Paint()..color = const Color(0x44FFB36B));
    c.save();
    final clip = Path()..addRect(Rect.fromLTRB(sx - r - 2, sc.dy - r - 2, sx + r + 2, sc.dy + 2));
    var y = sc.dy + 4;
    var gap = 2.0;
    while (y < sc.dy + r) {
      final h = 10.0 - gap * .9;
      clip.addRect(Rect.fromLTRB(sx - r - 2, y, sx + r + 2, y + max(2, h)));
      y += max(2, h) + gap;
      gap += 1.3;
    }
    clip.addRect(Rect.fromLTRB(sx - r - 2, sc.dy - 30 - r, sx + r + 2, sc.dy - 30));
    c.clipPath(clip);
    c.drawCircle(sc, r,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF36B), Color(0xFFFF9A3D), Color(0xFFFF2E97)]).createShader(Rect.fromCircle(center: sc, radius: r)));
    c.restore();
    // wireframe mountains
    for (var layer = 0; layer < 2; layer++) {
      final par = _x * (layer == 0 ? 1.5 : 4);
      final pts = <Offset>[Offset(-40, hz)];
      for (var i = -2; i <= 16; i++) {
        final x = i * 26.0 - par + (layer * 13);
        final hgt = (sin(i * 1.7 + layer * 3) * .5 + .5) * (layer == 0 ? 70 : 45) + (i % 3 == 0 ? 25 : 0) * (1 - layer * .5);
        pts.add(Offset(x, hz - hgt * (layer == 0 ? .8 : 1)));
      }
      pts.add(Offset(420, hz));
      final path = Path()..addPolygon(pts, true);
      c.drawPath(path, Paint()..color = layer == 0 ? const Color(0xFF2B0B4F) : const Color(0xFF1A0633));
      c.drawPath(path, D.stroke(layer == 0 ? const Color(0x99B04FFF) : const Color(0xFF29F0FF), layer == 0 ? 1.5 : 2));
      // inner wire lines
      for (var i = 1; i < pts.length - 1; i++) {
        c.drawLine(pts[i], Offset(pts[i].dx + (i.isEven ? 12 : -12), hz), D.stroke(layer == 0 ? const Color(0x44B04FFF) : const Color(0x5529F0FF), 1));
      }
    }
  }

  void _renderGround(Canvas c, double hz) {
    c.drawRect(Rect.fromLTRB(0, hz, 360, 640),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, hz), const Offset(0, 640), const [Color(0xFF3A0A5E), Color(0xFF12021F), Color(0xFF07010F)],
              const [0, .25, 1]));
    final cam = scene.cam;
    final nearZ = cam.pos.z + 1.2;
    const farZ = 230.0;
    // road surface
    final rl0 = cam.project(V3(-_roadHalf - .3, 0, nearZ)), rr0 = cam.project(V3(_roadHalf + .3, 0, nearZ));
    final rl1 = cam.project(V3(-_roadHalf - .3, 0, _dist + farZ)), rr1 = cam.project(V3(_roadHalf + .3, 0, _dist + farZ));
    if (rl0 != null && rr0 != null && rl1 != null && rr1 != null) {
      c.drawPath(Path()..addPolygon([rl0, rr0, rr1, rl1], true),
          Paint()
            ..shader = ui.Gradient.linear(Offset(0, hz), const Offset(0, 640), const [Color(0xFF3A1060), Color(0xFF0D0418)]));
    }
    // horizontal grid lines scrolling toward us
    const gz = 8.0;
    final z0 = (nearZ / gz).ceil() * gz;
    for (var z = z0; z < _dist + farZ; z += gz) {
      final a = cam.project(V3(-90, 0, z)), b = cam.project(V3(90, 0, z));
      if (a == null || b == null) continue;
      final fade = (1 - (z - _dist) / farZ).clamp(0.0, 1.0);
      c.drawLine(a, b, D.stroke(Color.fromRGBO(255, 46, 151, .15 + .6 * fade), .6 + fade * 1.6));
    }
    // longitudinal lines (off-road grid)
    for (var i = -12; i <= 12; i++) {
      final x = i * 6.4;
      if (x.abs() < _roadHalf) continue;
      final a = cam.project(V3(x, 0, nearZ)), b = cam.project(V3(x, 0, _dist + farZ));
      if (a == null || b == null) continue;
      c.drawLine(a, b, D.stroke(const Color(0x88FF2E97), 1.4));
    }
    // road edges (glowing cyan)
    for (final side in [-1.0, 1.0]) {
      final a = cam.project(V3(side * _roadHalf, 0, nearZ)), b = cam.project(V3(side * _roadHalf, 0, _dist + farZ));
      if (a == null || b == null) continue;
      c.drawLine(a, b, D.stroke(const Color(0x4429F0FF), 9));
      c.drawLine(a, b, D.stroke(const Color(0xFF29F0FF), 2.5));
    }
    // lane dashes
    const dash = 6.0, gap = 7.0;
    final dz0 = ((nearZ) / (dash + gap)).floor() * (dash + gap);
    for (var l = 1; l < 4; l++) {
      final x = (l - 2) * _laneW;
      for (var z = dz0; z < _dist + 150; z += dash + gap) {
        final z1 = max(z, nearZ);
        final a = cam.project(V3(x, 0, z1)), b = cam.project(V3(x, 0, z + dash));
        if (a == null || b == null || z + dash < nearZ) continue;
        final fade = (1 - (z - _dist) / 150).clamp(0.0, 1.0);
        c.drawLine(a, b, D.stroke(Color.fromRGBO(255, 240, 255, .25 + .6 * fade), 1 + fade * 3));
      }
    }
    // horizon glow line
    c.drawLine(Offset(0, hz), Offset(360, hz), D.stroke(const Color(0xAAFF4F8B), 2));
  }

  void _palm(Canvas c, Offset s, double k, double lean, bool pink, double dz) {
    if (k < .6) return;
    final fade = (1 - (dz - 80) / 110).clamp(0.0, 1.0);
    if (fade <= 0) return;
    final h = 8.5 * k;
    final top = s + Offset(lean * h * 1.4, -h);
    final ctrl = s + Offset(lean * h * .2, -h * .55);
    final trunk = Path()
      ..moveTo(s.dx - .3 * k, s.dy)
      ..quadraticBezierTo(ctrl.dx - .2 * k, ctrl.dy, top.dx - .12 * k, top.dy)
      ..lineTo(top.dx + .12 * k, top.dy)
      ..quadraticBezierTo(ctrl.dx + .2 * k, ctrl.dy, s.dx + .3 * k, s.dy)
      ..close();
    final neon = pink ? const Color(0xFFFF2E97) : const Color(0xFF29F0FF);
    c.drawPath(trunk, D.fill(Color.fromRGBO(10, 2, 24, fade)));
    c.drawPath(trunk, D.stroke(neon.withValues(alpha: .9 * fade), max(1, .07 * k)));
    // fronds
    for (var i = 0; i < 7; i++) {
      final a = -pi / 2 + (i - 3) * .52 + lean;
      final len = (3.6 + (i.isEven ? .6 : 0)) * k;
      final tip = top + Offset(cos(a) * len, sin(a) * len * .5 + len * .38);
      final mid = top + Offset(cos(a) * len * .5, sin(a) * len * .5 - .4 * k);
      final fr = Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy);
      c.drawPath(fr, D.stroke(neon.withValues(alpha: .28 * fade), max(2, .5 * k)));
      c.drawPath(fr, D.stroke(Color.lerp(neon, Pal.white, .35)!.withValues(alpha: fade), max(1, .14 * k)));
    }
  }

  void _glitch(Canvas c, ui.Picture pic) {
    final r = Random((_t * 30).floor());
    final k = (1 - _crashT / 1.6).clamp(0.0, 1.0);
    // chromatic split
    c.drawPicture(pic);
    c.saveLayer(const Rect.fromLTWH(0, 0, 360, 640), Paint()..blendMode = BlendMode.screen);
    c.translate(6 * k + 2, 0);
    c.drawPicture(pic);
    c.restore();
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), Paint()..color = Color.fromRGBO(255, 0, 90, .18 * k));
    // torn slices
    for (var i = 0; i < 7; i++) {
      final y = r.nextDouble() * 640;
      final h = 6 + r.nextDouble() * 40;
      c.save();
      c.clipRect(Rect.fromLTWH(0, y, 360, h));
      c.translate((r.nextDouble() - .5) * 80 * k, 0);
      c.drawPicture(pic);
      c.restore();
      if (r.nextDouble() < .5) {
        c.drawRect(Rect.fromLTWH(0, y, 360, 2 + r.nextDouble() * 4),
            Paint()..color = (r.nextBool() ? const Color(0xFF29F0FF) : const Color(0xFFFF2E97)).withValues(alpha: .6 * k + .2));
      }
    }
    // noise blocks
    for (var i = 0; i < 16; i++) {
      c.drawRect(Rect.fromLTWH(r.nextDouble() * 360, r.nextDouble() * 640, 4 + r.nextDouble() * 30, 2 + r.nextDouble() * 6),
          Paint()..color = Color.fromRGBO(255, 255, 255, r.nextDouble() * .5));
    }
    if (_crashT > .15) {
      final jx = (r.nextDouble() - .5) * 10;
      D.text(c, host.tr('crash', 'CRASH'), Offset(180 + jx - 3, 200), size: 54, color: const Color(0xAA29F0FF), italic: true);
      D.text(c, host.tr('crash', 'CRASH'), Offset(180 + jx + 3, 200), size: 54, color: const Color(0xAAFF2E97), italic: true);
      D.text(c, host.tr('crash', 'CRASH'), Offset(180 + jx, 200), size: 54, color: Pal.white, italic: true);
    }
  }

  void _renderHud(Canvas c) {
    // progress bar
    final p = (_dist / _goal).clamp(0.0, 1.0);
    const bar = Rect.fromLTWH(24, 48, 312, 12);
    D.rrect(c, bar, 6, const Color(0x88100020), border: const Color(0xFFB04FFF), borderWidth: 1.5);
    D.rrect(c, Rect.fromLTWH(bar.left, bar.top, max(12, bar.width * p), bar.height), 6, const Color(0xFFFF2E97));
    c.drawCircle(Offset(bar.left + bar.width * p, bar.center.dy), 8, D.fill(const Color(0xFF29F0FF)));
    c.drawCircle(Offset(bar.left + bar.width * p, bar.center.dy), 8, D.stroke(Pal.white, 2));
    // checkered goal flag
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 2; j++) {
        c.drawRect(Rect.fromLTWH(bar.right - 2 + i * 5.0, bar.top - 4 + j * 5.0 + (i.isEven ? 0 : 0), 5, 5),
            D.fill((i + j).isEven ? Pal.white : Pal.ink));
      }
    }
    final left = max(0, _goal - _dist);
    D.text(c, '${left.round()} m', const Offset(180, 78), size: 16, color: const Color(0xFFFFD6F0), stroke: const Color(0xFF2A0845), strokeWidth: 4);
    // speedometer
    final kmh = (_speed * 3.6).round();
    final col = _nitroFx > .3 ? const Color(0xFF29F0FF) : const Color(0xFFFF4FD8);
    D.text(c, '$kmh', const Offset(26, 606), size: 44, color: Pal.white, stroke: col, strokeWidth: 5, italic: true, anchor: Alignment.bottomLeft);
    D.text(c, 'km/h', const Offset(30, 624), size: 14, color: col, anchor: Alignment.bottomLeft, italic: true);
    // rpm-like arc
    final arcR = Rect.fromCircle(center: const Offset(310, 590), radius: 34);
    c.drawArc(arcR, pi * .75, pi * 1.5, false, D.stroke(const Color(0x55FFFFFF), 6));
    c.drawArc(arcR, pi * .75, pi * 1.5 * ((_speed - 30) / 90).clamp(0.0, 1.0), false, D.stroke(col, 6));
    D.text(c, _nitroFx > .3 ? 'N2O' : '${_nearMiss}x', const Offset(310, 592), size: 14, color: Pal.white);
    if (_nitro > 0) {
      D.text(c, host.tr('nitro', 'NITRO!'), Offset(180 + sin(_t * 40) * 2, 112), size: 26, color: const Color(0xFF29F0FF),
          stroke: const Color(0xFF0B0221), strokeWidth: 5, italic: true);
    }
    // tutorial
    if (host.time < 2.4 && !host.finished) {
      final k = M.wave(_t, .8);
      D.hand(c, Offset(130 + k * 100, 560), 0);
      D.arrow(c, const Offset(96, 540), const Offset(-1, 0), 44, const Color(0xCC29F0FF), width: 10);
      D.arrow(c, const Offset(264, 540), const Offset(1, 0), 44, const Color(0xCC29F0FF), width: 10);
      D.text(c, host.tr('swipe', 'SWIPE'), const Offset(180, 540), size: 20, color: Pal.white, stroke: const Color(0xFFFF2E97), strokeWidth: 4);
    }
  }
}

class _Car {
  _Car(this.lane, this.x, this.z, this.mesh, this.speed);
  final int lane;
  double x, z, speed;
  final int mesh; // -1 truck
  double y = 0, vy = 0, vx = 0, rot = 0, spinV = 0;
  bool flying = false;
  bool passed = false;
}

class _Nitro {
  _Nitro(this.x, this.z);
  final double x, z;
  bool got = false;
}
