import '../engine/engine.dart';

/// No.141 Slalom Ski 3D — drag left/right to carve through every gate.
/// Miss 2 gates and you're out; cross the finish line to win.
class G141 extends MiniGame {
  static const _bot = bool.fromEnvironment('ARCADE_BOT');
  static const _gates = 12;
  static const _gap = 16.0;
  static const _gateHalf = 1.5;
  static const _slope = .2;
  static const _startZ = 14.0;

  final scene = Scene3();
  late final Mesh _ground;
  late final Mesh _tree;
  late final Mesh _skier;
  late final Mesh _pole;
  late final Mesh _poleBlue;
  late final Mesh _bannerRed;
  late final Mesh _bannerBlue;
  late final Mesh _fence;
  late final Mesh _archPost;
  late final Mesh _archBeam;
  late final Mesh _rock;

  final List<_Gate> _gateList = [];
  final List<V3> _trees = [];
  final List<V3> _rocks = [];
  final List<Offset> _tracks = []; // (x, z)
  double _finishZ = 0;

  double _x = 0, _z = 0, _vx = 0, _vz = 9;
  double _steer = 0, _steerTarget = 0;
  double? _anchorX;
  int _keyDir = 0;
  int _passed = 0;
  int _missed = 0;
  int _combo = 0;
  double _t = 0;
  double _race = 0;
  bool _done = false;
  bool _crashed = false;
  double _crashT = 0;
  double _banner = 0;
  String _bannerText = '';
  Color _bannerColor = Pal.yellow;
  double _sprayAcc = 0;
  double _camShake = 0;

  double _y(double z) => -z * _slope;

  @override
  void init() {
    scene.ambient = .62;
    scene.diffuse = .5;
    scene.light = const V3(-.5, 1, -.35).normalized;
    scene.fogColor = const Color(0xFFDDEBFA);
    scene.fogNear = 30;
    scene.fogFar = 70;
    _ground = Mesh.grid(44, 88, 11, 22, (i, j) {
      final k = (i * 7 + j * 13) % 5;
      return [const Color(0xFFF4F8FF), const Color(0xFFEAF2FC), const Color(0xFFF9FBFF), const Color(0xFFE3EDF9),
        const Color(0xFFF0F6FF)][k];
    });
    _tree = Mesh.merge([
      (Mesh.cylinder(.22, .8, const Color(0xFF7A4E2E), seg: 5), const V3(0, .4, 0)),
      (Mesh.cone(1.4, 2.0, const Color(0xFF1F7A4A), seg: 6), const V3(0, 1.6, 0)),
      (Mesh.cone(1.05, 1.7, const Color(0xFF2A9458), seg: 6), const V3(0, 2.5, 0)),
      (Mesh.cone(.55, .9, const Color(0xFFF6FAFF), seg: 6), const V3(0, 3.3, 0)),
    ]);
    _skier = _buildSkier();
    _pole = Mesh.cylinder(.08, 2.2, const Color(0xFFE8303A), seg: 5);
    _poleBlue = Mesh.cylinder(.08, 2.2, const Color(0xFF2E6BFF), seg: 5);
    _bannerRed = Mesh.box(3.6, .7, .06, const Color(0xFFFF3B5C));
    _bannerBlue = Mesh.box(3.6, .7, .06, const Color(0xFF3D6BFF));
    _fence = Mesh.box(.12, .9, 7.6, const Color(0xFFFF8A1F));
    _archPost = Mesh.box(.6, 5, .6, const Color(0xFF3D6BFF));
    _archBeam = Mesh.merge([
      for (var i = 0; i < 8; i++)
        (Mesh.box(1.6, 1.2, .4, i.isEven ? const Color(0xFF1B1530) : const Color(0xFFFFFFFF)), V3(-5.6 + i * 1.6, 0, 0)),
    ]);
    _rock = Mesh.sphere(.9, const Color(0xFF9AA7BD), lat: 3, lon: 6);

    var z = _startZ + 10;
    for (var i = 0; i < _gates; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final gx = side * rand(1.6, 3.4);
      _gateList.add(_Gate(z, gx, i.isEven));
      z += _gap;
    }
    _finishZ = z + 4;
    for (var tz = -10.0; tz < _finishZ + 60; tz += rand(3.5, 6.5)) {
      _trees.add(V3(-rand(11, 19), 0, tz));
      _trees.add(V3(rand(11, 19), 0, tz + rand(0, 3)));
      if (chance(.25)) _rocks.add(V3((chance(.5) ? -1 : 1) * rand(8, 10), 0, tz + 1));
    }
    _z = 0;
  }

  Mesh _buildSkier() {
    const suit = Color(0xFFFF3B5C);
    const suit2 = Color(0xFFFFD23F);
    const dark = Color(0xFF1B1530);
    return Mesh.merge([
      (Mesh.box(.16, .06, 1.9, const Color(0xFF3FB8FF)), const V3(-.2, .03, .1)),
      (Mesh.box(.16, .06, 1.9, const Color(0xFF3FB8FF)), const V3(.2, .03, .1)),
      (Mesh.box(.2, .22, .34, dark), const V3(-.2, .16, 0)),
      (Mesh.box(.2, .22, .34, dark), const V3(.2, .16, 0)),
      (Mesh.box(.2, .55, .22, suit), const V3(-.2, .5, .05)),
      (Mesh.box(.2, .55, .22, suit), const V3(.2, .5, .05)),
      (Mesh.box(.56, .6, .36, suit), const V3(0, 1.0, .12)),
      (Mesh.box(.58, .14, .38, suit2), const V3(0, .86, .12)),
      (Mesh.box(.14, .45, .14, suit), const V3(-.36, .95, .3)),
      (Mesh.box(.14, .45, .14, suit), const V3(.36, .95, .3)),
      (Mesh.sphere(.2, const Color(0xFFFFD23F), lat: 4, lon: 7), const V3(0, 1.48, .16)),
      (Mesh.box(.3, .1, .06, const Color(0xFF14C9C9)), const V3(0, 1.48, .36)),
      (Mesh.box(.04, .04, 1.1, const Color(0xFFCCCCDD)), const V3(-.45, .55, -.1)),
      (Mesh.box(.04, .04, 1.1, const Color(0xFFCCCCDD)), const V3(.45, .55, -.1)),
    ]);
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _banner = max(0, _banner - dt);
    _camShake = M.approach(_camShake, 0, 6, dt);
    for (final g in _gateList) {
      if (g.state != 0) g.anim = min(1, g.anim + dt * 2.5);
    }
    if (_crashed) {
      _crashT += dt;
      _vz = M.approach(_vz, 0, 2, dt);
      _z += _vz * dt;
      return;
    }
    if (_done) {
      _vz = M.approach(_vz, 3, 1.5, dt);
      _z += _vz * dt;
      _x += _vx * dt;
      _vx = M.approach(_vx, 0, 3, dt);
      return;
    }
    _race += dt;
    if (_bot) _botSteer();
    if (_keyDir != 0) _steerTarget = _keyDir.toDouble();
    _steer = M.approach(_steer, _steerTarget, 10, dt);
    final maxV = (17 + min(_race, 10) * .4) * sqrt(host.speed);
    final targetVz = min(maxV, 9 + _race * 2.4) - _steer.abs() * 2.2;
    _vz = M.approach(_vz, targetVz, 2.5, dt);
    _vx = M.approach(_vx, _steer * 9.5, 5.5, dt);
    _x = (_x + _vx * dt).clamp(-9.2, 9.2);
    final prevZ = _z;
    _z += _vz * dt;
    if (_tracks.isEmpty || _z - _tracks.last.dy > .8) {
      _tracks.add(Offset(_x, _z));
      if (_tracks.length > 60) _tracks.removeAt(0);
    }
    // spray when carving
    _sprayAcc += dt * (_steer.abs() * 60 + 4);
    while (_sprayAcc > 1) {
      _sprayAcc -= 1;
      _spray();
    }
    // gates
    for (final g in _gateList) {
      if (g.state == 0 && prevZ < g.z && _z >= g.z) _judge(g);
    }
    if (!_done && _z >= _finishZ) _finish();
  }

  void _botSteer() {
    _Gate? next;
    for (final g in _gateList) {
      if (g.state == 0) {
        next = g;
        break;
      }
    }
    final tx = next?.x ?? 0;
    _steerTarget = ((tx - _x) * .8 - _vx * .12).clamp(-1.0, 1.0);
  }

  void _spray() {
    final p = scene.cam.project(V3(_x, _y(_z) + .1, _z - .3));
    if (p == null) return;
    final side = _vx >= 0 ? -1.0 : 1.0;
    host.fx.add(Particle(
      pos: p + Offset(rand(-6, 6), rand(-4, 4)),
      vel: Offset(side * rand(60, 200) * (.3 + _steer.abs()), rand(-160, -40)),
      life: rand(.3, .6),
      color: chance(.5) ? Pal.white : const Color(0xFFCFE6FF),
      size: rand(4, 9) * (.5 + _steer.abs()),
      gravity: 420,
      drag: 1.5,
    ));
  }

  void _judge(_Gate g) {
    final d = (_x - g.x).abs();
    final at = scene.cam.project(V3(g.x, _y(g.z) + 1.4, g.z)) ?? const Offset(180, 300);
    if (d < _gateHalf) {
      g.state = 1;
      _passed++;
      _combo++;
      final perfect = d < .6;
      host.sfx(Sfx.ding, rate: 1 + min(_combo, 10) * .06);
      host.sfx(Sfx.whoosh, volume: .5);
      host.fx.ring(at, g.red ? Pal.red : Pal.sky, size: 80);
      host.fx.burst(at, Pal.white, count: 12, speed: 220, shape: PartShape.spark);
      if (perfect) {
        host.sfx(Sfx.perfect, volume: .6, rate: 1 + _combo * .03);
        _say(host.tr('perfect', 'PERFECT!'), Pal.yellow);
        host.addScore(200, at);
        host.punch(.03);
      } else {
        _say(host.tr('good', 'GOOD'), Pal.lime);
        host.addScore(100, at);
      }
    } else {
      g.state = 2;
      _missed++;
      _combo = 0;
      host.sfx(Sfx.buzzer);
      host.sfx(Sfx.aww, volume: .5);
      host.shake(8);
      host.flash(Pal.red, .15);
      _camShake = 1;
      _say(host.tr('miss', 'MISS'), Pal.red);
      if (_missed >= 2) {
        _crashed = true;
        _crashT = 0;
        host.sfx(Sfx.crash);
        host.fx.smoke(scene.cam.project(V3(_x, _y(_z), _z)) ?? const Offset(180, 460), count: 14, color: const Color(0xEEFFFFFF), size: 26);
        host.lose();
      }
    }
  }

  void _finish() {
    _done = true;
    host.sfx(Sfx.cheer);
    host.sfx(Sfx.fanfare, volume: .7);
    host.fx.confetti(count: 100);
    host.shake(6);
    _say(host.tr('goal', 'GOAL!'), Pal.yellow);
    host.win(stars: _missed == 0 ? (_race < 15.5 ? 3 : 2) : 1);
  }

  void _say(String s, Color c) {
    _bannerText = s;
    _bannerColor = c;
    _banner = .8;
  }

  // ------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    if (_bot) return;
    _anchorX = p.dx;
  }

  @override
  void onMove(Offset p) {
    if (_bot) return;
    final a = _anchorX;
    if (a == null) return;
    var d = (p.dx - a) / 60;
    if (d.abs() > 1) {
      // drag the anchor along so reversing direction reacts instantly
      _anchorX = p.dx - d.sign * 60;
      d = d.sign.toDouble();
    }
    _steerTarget = d;
  }

  @override
  void onUp(Offset p) {
    if (_bot) return;
    _anchorX = null;
    _steerTarget = 0;
  }

  @override
  void onKey(String key, bool down) {
    if (_bot) return;
    if (key == 'left') _keyDir = down ? -1 : (_keyDir == -1 ? 0 : _keyDir);
    if (key == 'right') _keyDir = down ? 1 : (_keyDir == 1 ? 0 : _keyDir);
    if (!down && _keyDir == 0) _steerTarget = 0;
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    final sy = _y(_z);
    final shake = _camShake * .25 * sin(_t * 60);
    scene.cam
      ..center = const Offset(180, 300)
      ..focal = 400
      ..pos = V3(_x * .55 + shake, sy + 4.6, _z - 7.8)
      ..lookAt(V3(_x * .75, sy - .6, _z + 9));

    // sky, mountains, distant snowfield
    final hz = scene.cam.project(V3(_x * .75, sy - 200 * _slope, _z + 200))?.dy ?? 200;
    D.gradientBg(c, const [Color(0xFF3E8EF0), Color(0xFF8CC6FF), Color(0xFFD4EBFF)], rect: Rect.fromLTWH(0, 0, 360, hz + 2));
    c.drawCircle(const Offset(290, 90), 24, D.fill(const Color(0xFFFFF7D0)));
    c.drawCircle(const Offset(290, 90), 40, D.fill(const Color(0x33FFF7D0)));
    final par = -_x * 3;
    _mountains(c, hz, par * .5, 90, const Color(0xFF9FB6D8), const Color(0xFFF4F8FF), 7);
    _mountains(c, hz, par, 55, const Color(0xFF7F9CC6), const Color(0xFFFFFFFF), 11);
    c.drawRect(Rect.fromLTWH(0, hz, 360, 640 - hz), D.fill(const Color(0xFFDDEBFA)));

    // pass 1: ground
    scene.clear();
    final gz = (_z / 4).floor() * 4.0 + 36;
    scene.add(_ground, pos: V3(_x.roundToDouble(), _y(gz), gz), rotX: atan(_slope));
    scene.render(c);
    // ski tracks + shadow on top of the ground
    if (_tracks.length > 1) {
      for (final off in [-.2, .2]) {
        final path = Path();
        var started = false;
        for (final tp in _tracks) {
          final p = scene.cam.project(V3(tp.dx + off, _y(tp.dy) + .02, tp.dy));
          if (p == null) continue;
          started ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
          started = true;
        }
        final cur = scene.cam.project(V3(_x + off, sy + .02, _z));
        if (cur != null && started) path.lineTo(cur.dx, cur.dy);
        c.drawPath(path, D.stroke(const Color(0x33587AA8), 2.5));
      }
    }
    final sp = scene.cam.project(V3(_x, sy, _z));
    if (sp != null) c.drawOval(Rect.fromCenter(center: sp + const Offset(0, 2), width: 46, height: 14), D.fill(const Color(0x33304870)));

    // pass 2: objects
    scene.clear();
    const view = 64.0;
    for (final t in _trees) {
      if (t.z < _z - 6 || t.z > _z + view) continue;
      scene.add(_tree, pos: V3(t.x, _y(t.z), t.z), scale: 1.2);
    }
    for (final r in _rocks) {
      if (r.z < _z - 6 || r.z > _z + view) continue;
      scene.add(_rock, pos: V3(r.x, _y(r.z), r.z), scale3: const V3(1, .5, 1));
    }
    // safety fences
    final fz0 = (_z / 8).floor() * 8.0;
    for (var i = -1; i < 8; i++) {
      final fz = fz0 + i * 8;
      for (final fx in [-10.0, 10.0]) {
        scene.add(_fence, pos: V3(fx, _y(fz) + .45, fz), rotX: atan(_slope));
      }
    }
    for (final g in _gateList) {
      if (g.z < _z - 6 || g.z > _z + view) continue;
      final base = _y(g.z);
      final fall = g.state == 2 ? M.easeOut(g.anim) * 1.3 : 0.0;
      final wob = g.state == 1 ? sin(g.anim * 20) * (1 - g.anim) * .25 : 0.0;
      final pole = g.red ? _pole : _poleBlue;
      for (final s in [-1.0, 1.0]) {
        scene.add(pole, pos: V3(g.x + s * _gateHalf, base + 1.1, g.z), rotZ: s * .05 + wob + fall * s);
      }
      scene.add(g.red ? _bannerRed : _bannerBlue,
          pos: V3(g.x, base + 1.85 - fall * .9, g.z), rotZ: wob * .5 + fall * .4, flash: g.state == 1 ? (1 - g.anim) * .8 : 0);
    }
    // finish arch
    if (_finishZ - _z < view + 10) {
      final fy = _y(_finishZ);
      scene.add(_archPost, pos: V3(-6.6, fy + 2.5, _finishZ));
      scene.add(_archPost, pos: V3(6.6, fy + 2.5, _finishZ));
      scene.add(_archBeam, pos: V3(0, fy + 4.6, _finishZ));
      for (var i = -3; i <= 3; i++) {
        if (i == 0) continue;
        final px = i * 2.8 + (i > 0 ? 7 : -7);
        final bounce = _done ? M.wave(_t + i * .3, 3) * .4 : 0.0;
        final col = Pal.candy[(i + 3) % 8];
        scene.addSprite(V3(px, fy + bounce, _finishZ - 2), (c, p, s) {
          D.person(c, p, s * 1.7, col, face: _done ? Face.happy : Face.neutral, armsUp: _done ? 1 : 0);
        });
      }
    }
    // skier
    final heading = atan2(_vx, max(_vz, 1));
    final lean = -_steer * .45;
    final crashRoll = _crashed ? min(_crashT * 6, 1.5) : 0.0;
    final crouch = 1 - _steer.abs() * .12;
    final bob = _done ? M.wave(_t, 2) * .3 : 0.0;
    scene.add(_skier,
        pos: V3(_x, sy + bob, _z), rotY: heading, rotZ: lean + crashRoll, rotX: atan(_slope) * .5, scale3: V3(1, crouch, 1));
    scene.render(c);

    // speed lines
    final speed = _vz / 20;
    if (speed > .6 && !_crashed) {
      final p = Paint()..color = Color.fromRGBO(255, 255, 255, (speed - .6) * .9);
      for (var i = 0; i < 10; i++) {
        final a = i * 2.39 + _t * 3;
        final y = 120 + (i * 53 + _t * 900) % 500;
        final x = i.isEven ? 10 + (a % 30) : 350 - (a % 30);
        c.drawRect(Rect.fromLTWH(x, y, 2.5, 40), p);
      }
    }

    _hud(c);
  }

  void _mountains(Canvas c, double base, double off, double h, Color col, Color snow, int seed) {
    final path = Path()..moveTo(-40, base);
    final peaks = <Offset>[];
    for (var i = 0; i <= 8; i++) {
      final x = -40 + i * 55.0 + off;
      final y = base - h * (.45 + .55 * ((i * seed) % 5) / 4);
      peaks.add(Offset(x, y));
      path.lineTo(x, y);
      path.lineTo(x + 27, base - h * .3);
    }
    path
      ..lineTo(460, base)
      ..close();
    c.drawPath(path, D.fill(col));
    for (final p in peaks) {
      final cap = Path()
        ..moveTo(p.dx, p.dy)
        ..lineTo(p.dx + 12, p.dy + 14)
        ..lineTo(p.dx + 4, p.dy + 11)
        ..lineTo(p.dx - 3, p.dy + 16)
        ..lineTo(p.dx - 10, p.dy + 12)
        ..close();
      c.drawPath(cap, D.fill(snow));
    }
  }

  void _hud(Canvas c) {
    // gate counter
    D.rrect(c, const Rect.fromLTWH(10, 40, 116, 36), 10, const Color(0xE6121530), border: Pal.white, borderWidth: 2);
    _flagIcon(c, const Offset(28, 58));
    D.text(c, '$_passed/$_gates', const Offset(80, 58), size: 20, color: Pal.white);
    // misses
    D.rrect(c, const Rect.fromLTWH(262, 40, 88, 36), 10, const Color(0xE6121530), border: Pal.white, borderWidth: 2);
    for (var i = 0; i < 2; i++) {
      final p = Offset(288 + i * 36.0, 58);
      final hit = i < _missed;
      D.circle(c, p, 12, hit ? Pal.red : const Color(0x33FFFFFF), border: const Color(0xAAFFFFFF), borderWidth: 1.5);
      D.line(c, p + const Offset(-5, -5), p + const Offset(5, 5), hit ? Pal.white : const Color(0x66FFFFFF), 3);
      D.line(c, p + const Offset(5, -5), p + const Offset(-5, 5), hit ? Pal.white : const Color(0x66FFFFFF), 3);
    }
    // race clock
    D.rrect(c, const Rect.fromLTWH(134, 42, 120, 32), 8, const Color(0xE6FFD23F), border: Pal.ink, borderWidth: 2);
    D.text(c, _race.toStringAsFixed(2), const Offset(194, 58), size: 20, color: Pal.ink);
    // speed
    final kmh = (_vz * 5.2).round();
    D.text(c, '$kmh', const Offset(40, 600), size: 30, color: Pal.white, stroke: Pal.ink);
    D.text(c, 'km/h', const Offset(40, 624), size: 11, color: Pal.white, stroke: Pal.ink);
    // next gate arrow
    _Gate? next;
    for (final g in _gateList) {
      if (g.state == 0) {
        next = g;
        break;
      }
    }
    if (next != null && !_crashed) {
      final p = scene.cam.project(V3(next.x, _y(next.z) + 3.1, next.z));
      if (p != null && next.z - _z < 30) {
        final k = M.wave(_t, 3);
        D.arrow(c, p + Offset(0, -10 - k * 6), const Offset(0, 1), 26, next.red ? Pal.red : Pal.sky, width: 9);
      }
    }
    if (host.time < 2.5) {
      D.arrow(c, const Offset(110, 520), const Offset(-1, 0), 60, Pal.yellow);
      D.arrow(c, const Offset(250, 520), const Offset(1, 0), 60, Pal.yellow);
      D.hand(c, Offset(180 + sin(_t * 4) * 50, 520), _t);
      D.text(c, host.tr('drag', 'DRAG'), const Offset(180, 470), size: 26, color: Pal.yellow, stroke: Pal.ink);
    }
    if (_banner > 0) {
      final a = .8 - _banner;
      final s = a < .15 ? M.easeOutBack(a / .15) : 1.0;
      c.save();
      c.translate(180, 170);
      c.scale(s);
      D.title(c, _bannerText, Offset.zero, size: 40, color: _bannerColor);
      c.restore();
    }
    if (_done) {
      final k = M.clamp01(_z - _finishZ);
      c.save();
      c.translate(180, 450);
      c.scale(M.easeOutBack(k));
      D.rrect(c, const Rect.fromLTWH(-110, -34, 220, 68), 16, const Color(0xE6121530), border: Pal.yellow, borderWidth: 3);
      D.text(c, _race.toStringAsFixed(2), Offset.zero, size: 44, color: Pal.yellow, stroke: Pal.ink);
      c.restore();
    }
  }

  void _flagIcon(Canvas c, Offset p) {
    D.line(c, p + const Offset(-6, 11), p + const Offset(-6, -11), Pal.white, 2.5);
    c.drawPath(
        Path()
          ..moveTo(p.dx - 5, p.dy - 11)
          ..lineTo(p.dx + 10, p.dy - 6)
          ..lineTo(p.dx - 5, p.dy)
          ..close(),
        D.fill(Pal.red));
  }
}

class _Gate {
  _Gate(this.z, this.x, this.red);
  final double z;
  final double x;
  final bool red;
  int state = 0; // 0 ahead, 1 passed, 2 missed
  double anim = 0;
}
