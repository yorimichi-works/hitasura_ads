import 'dart:math' as math;

import '../engine/engine.dart';

/// No.102 Lucky Dice 3D — hold to shake, release in the LUCKY zone, roll a 7.
///
/// Two real 3D dice (custom-projected rounded cubes with pips) tumble across
/// a casino felt table. Releasing the shake meter in the gold zone "loads"
/// the dice (it's an ad — of course it's rigged). 3 throws, hit 7 once.
class G102 extends MiniGame {
  static const _target = 7;
  static const _maxThrows = 3;
  static const _rollTime = 1.45;

  final scene = Scene3();
  late final Mesh _felt, _rails, _chipsA, _chipsB, _base;
  final _dice = <_Die>[];

  _Ph _ph = _Ph.ready;
  double _phT = 0;
  double _t = 0;
  int _throws = 0;
  double _charge = 0; // needle 0..1
  double _chargeT = 0;
  Offset _prev = Offset.zero;
  double _swipeVx = 0;
  int _sum = 0;
  bool _lucky = false;
  double _celebrate = 0;
  double _winDelay = -1;
  final _history = <int>[];
  double _camX = 0, _camZ = 0;
  double _sumPop = 0;

  // value -> list of (zQuarter, xQuarter) that put that value on top
  static final Map<int, List<(int, int)>> _orient = _buildOrient();

  static Map<int, List<(int, int)>> _buildOrient() {
    final m = <int, List<(int, int)>>{};
    for (var a = 0; a < 4; a++) {
      for (var b = 0; b < 4; b++) {
        for (final f in _Die.faces) {
          final n = _rot(f.$1, b * pi / 2, 0, a * pi / 2);
          if (n.y > .9) m.putIfAbsent(f.$4, () => []).add((a, b));
        }
      }
    }
    return m;
  }

  @override
  void init() {
    scene.ambient = .5;
    scene.diffuse = .6;
    scene.light = const V3(-.35, 1, -.5).normalized;
    const feltA = Color(0xFF138A4E), feltB = Color(0xFF17975A);
    _felt = Mesh.grid(9.2, 9.0, 12, 12, (i, j) {
      final d = ((i - 5.5).abs() + (j - 5.5).abs());
      return d < 4 ? feltB : ((i + j).isOdd ? feltA : const Color(0xFF12824A));
    });
    _base = Mesh.box(11.4, 1.2, 11.0, const Color(0xFF4A1E14));
    const wood = Color(0xFF8A3B1E), gold = Color(0xFFFFC53D);
    final parts = <(Mesh, V3)>[];
    Mesh seg(double w, double d) =>
        Mesh.box(w, .55, d, wood, colors: [gold, wood, wood, wood, wood, wood]);
    for (var i = 0; i < 7; i++) {
      final x = -4.8 + i * 1.6;
      parts.add((seg(1.6, .8), V3(x, .27, -4.9)));
      parts.add((seg(1.6, .8), V3(x, .27, 4.9)));
    }
    for (var i = 0; i < 6; i++) {
      final z = -4.1 + i * 1.64;
      parts.add((seg(.8, 1.64), V3(-5.0, .27, z)));
      parts.add((seg(.8, 1.64), V3(5.0, .27, z)));
    }
    _rails = Mesh.merge(parts);
    Mesh chips(List<Color> cols) => Mesh.merge([
          for (var i = 0; i < cols.length; i++)
            (Mesh.cylinder(.42, .16, cols[i], seg: 10, cap: Color.lerp(cols[i], Pal.white, .35)), V3(0, .08 + i * .17, 0)),
        ]);
    _chipsA = chips(const [Pal.red, Pal.white, Pal.red, Pal.ink, Pal.red, Pal.gold]);
    _chipsB = chips(const [Pal.blue, Pal.gold, Pal.blue, Pal.white]);
    _dice
      ..add(_Die(const Color(0xFFE8304A), Pal.white, Pal.white))
      ..add(_Die(const Color(0xFFFFF4E4), Pal.ink, Pal.red));
    _toHand();
  }

  void _toHand() {
    for (var i = 0; i < 2; i++) {
      final d = _dice[i];
      d
        ..pos = V3(i == 0 ? -.7 : .7, 2.4, -3.3)
        ..vx = 0
        ..vy = 0
        ..vz = 0
        ..rx = rand(0, 6)
        ..ry = rand(0, 6)
        ..rz = rand(0, 6);
    }
  }

  static V3 _rot(V3 p, double rx, double ry, double rz) {
    final cz = cos(rz), sz = sin(rz), cx = cos(rx), sx = sin(rx), cy = cos(ry), sy = sin(ry);
    final x = p.x * cz - p.y * sz;
    var y = p.x * sz + p.y * cz;
    var z = p.z;
    final y2 = y * cx - z * sx;
    final z2 = y * sx + z * cx;
    y = y2;
    z = z2;
    return V3(x * cy + z * sy, y, -x * sy + z * cy);
  }

  // ------------------------------------------------------------ input ---

  @override
  void onDown(Offset p) {
    if (_ph != _Ph.ready) return;
    _ph = _Ph.charging;
    _phT = 0;
    _chargeT = 0;
    _prev = p;
    _swipeVx = 0;
    host.sfx(Sfx.dice, volume: .7);
  }

  @override
  void onMove(Offset p) {
    if (_ph != _Ph.charging) return;
    _swipeVx = M.lerp(_swipeVx, (p.dx - _prev.dx) * 60, .5);
    _prev = p;
  }

  @override
  void onUp(Offset p) {
    if (_ph == _Ph.charging) _throw();
  }

  @override
  void onKey(String key, bool down) {
    if (key != 'action') return;
    if (down) {
      onDown(const Offset(180, 500));
    } else {
      onUp(const Offset(180, 500));
    }
  }

  // Needle ping-pong 0..1..0
  double get _needle {
    final u = (_chargeT * 1.25 * host.speed) % 2;
    return u < 1 ? u : 2 - u;
  }

  static const _goldA = .70, _goldB = .84, _greenA = .58, _greenB = .94;

  void _throw() {
    _throws++;
    _ph = _Ph.rolling;
    _phT = 0;
    final n = _charge;
    final gold = n >= _goldA && n <= _goldB;
    final green = !gold && n >= _greenA && n <= _greenB;
    int v1, v2;
    if (gold || (green && chance(.5))) {
      v1 = 1 + randInt(6);
      v2 = _target - v1;
      _lucky = true;
    } else {
      v1 = 1 + randInt(6);
      v2 = 1 + randInt(6);
      // an honest near-miss is funnier than a random blowout
      if (v1 + v2 != _target && chance(.45)) v2 = (_target - v1 + (chance(.5) ? 1 : -1)).clamp(1, 6);
      _lucky = false;
    }
    if (gold) {
      host.fx.pop(host.tr('lucky', 'LUCKY!'), const Offset(180, 470), color: Pal.gold, size: 34);
      host.sfx(Sfx.sparkle);
      host.fx.sparkle(const Offset(180, 560), count: 14, radius: 60, color: Pal.gold);
    } else if (green) {
      host.fx.pop(host.tr('good', 'GOOD'), const Offset(180, 480), color: Pal.lime, size: 26);
    }
    host.sfx(Sfx.throwIt);
    host.sfx(Sfx.dice, rate: 1.1);
    final side = (_swipeVx / 260).clamp(-2.5, 2.5);
    for (var i = 0; i < 2; i++) {
      final d = _dice[i];
      final v = i == 0 ? v1 : v2;
      d
        ..value = v
        ..vx = side + (i == 0 ? -1 : 1) * rand(.2, 1.3)
        ..vy = rand(3.5, 5.5)
        ..vz = rand(7.5, 10.5)
        ..settled = false;
      final opts = _orient[v]!;
      final o = opts[randInt(opts.length)];
      d
        ..x0 = d.rx
        ..z0 = d.rz
        ..y0 = d.ry;
      final spinX = (chance(.5) ? 1 : -1) * rand(3, 5) * pi * 2;
      final spinZ = (chance(.5) ? 1 : -1) * rand(2, 4) * pi * 2;
      d.x1 = ((d.rx + spinX) / (2 * pi)).roundToDouble() * 2 * pi + o.$2 * pi / 2;
      d.z1 = ((d.rz + spinZ) / (2 * pi)).roundToDouble() * 2 * pi + o.$1 * pi / 2;
      d.y1 = d.ry + rand(-3, 3);
    }
  }

  // ----------------------------------------------------------- update ---

  @override
  void update(double dt) {
    _t += dt;
    _phT += dt;
    _celebrate = max(0, _celebrate - dt);
    _sumPop = M.approach(_sumPop, 0, 5, dt);
    if (_winDelay > 0) {
      _winDelay -= dt;
      if (_winDelay <= 0) {
        host.win(stars: _throws == 1 ? 3 : (_throws == 2 ? 2 : 1));
      }
    }
    switch (_ph) {
      case _Ph.ready:
        for (var i = 0; i < 2; i++) {
          final d = _dice[i];
          d.pos = V3(d.pos.x, 2.4 + sin(_t * 3 + i) * .12, d.pos.z);
          d.ry += dt * .8;
          d.rx += dt * .5;
        }
      case _Ph.charging:
        _chargeT += dt;
        _charge = _needle;
        for (var i = 0; i < 2; i++) {
          final d = _dice[i];
          final j = 8 + _chargeT * 4;
          d.pos = V3((i == 0 ? -.7 : .7) + sin(_t * 41 + i) * .12, 2.5 + sin(_t * 37 + i * 2) * .18, -3.3);
          d.rx += dt * j;
          d.rz += dt * j * .7;
          d.ry += dt * j * .4;
        }
        if ((_chargeT * 9).floor() != ((_chargeT - dt) * 9).floor()) {
          host.sfx(Sfx.shake, volume: .35, rate: .9 + _charge * .5);
        }
        if (_chargeT > 3.0) _throw();
      case _Ph.rolling:
        _simDice(dt);
        if (_lucky && (_t * 14).floor() != ((_t - dt) * 14).floor()) {
          for (final d in _dice) {
            final sp = scene.cam.project(d.pos);
            if (sp != null) host.fx.sparkle(sp, count: 2, radius: 22, color: Pal.gold);
          }
        }
        if (_phT > _rollTime + .25) _result();
      case _Ph.result:
        _simDice(dt);
        if (_phT > 1.15 && !host.finished && _winDelay < 0) {
          if (_throws >= _maxThrows) {
            _ph = _Ph.done;
            host.sfx(Sfx.jingleLose);
            host.lose();
          } else {
            _ph = _Ph.ready;
            _phT = 0;
            _toHand();
            host.sfx(Sfx.whoosh, volume: .6);
          }
        }
      case _Ph.done:
        _simDice(dt);
    }
    // camera drift toward the dice
    var ax = 0.0, az = 0.0;
    for (final d in _dice) {
      ax += d.pos.x / 2;
      az += d.pos.z / 2;
    }
    final follow = _ph == _Ph.rolling || _ph == _Ph.result || _ph == _Ph.done;
    _camX = M.approach(_camX, follow ? ax * .35 : 0, 2.5, dt);
    _camZ = M.approach(_camZ, follow ? az * .25 : 0, 2.5, dt);
  }

  void _simDice(double dt) {
    final u = M.clamp01(_phT / _rollTime);
    final e = 1 - pow(1 - u, 3).toDouble();
    for (final d in _dice) {
      if (_ph == _Ph.rolling || !d.settled) {
        d
          ..rx = d.x0 + (d.x1 - d.x0) * e
          ..rz = d.z0 + (d.z1 - d.z0) * e
          ..ry = d.y0 + (d.y1 - d.y0) * e;
      }
      var x = d.pos.x, y = d.pos.y, z = d.pos.z;
      d.vy -= 28 * dt;
      x += d.vx * dt;
      y += d.vy * dt;
      z += d.vz * dt;
      final ext = d.extent;
      if (y < ext) {
        y = ext;
        if (d.vy < -2.5) {
          host.sfx(Sfx.dice, volume: M.clamp01(-d.vy / 10), rate: rand(.9, 1.2));
          final sp = scene.cam.project(V3(x, 0, z));
          if (sp != null) host.fx.burst(sp, const Color(0x88B8FFD0), count: 5, speed: 90, size: 4, gravity: 0, life: .3);
        }
        d.vy = d.vy < -1.2 ? -d.vy * .42 : 0;
        final f = u >= 1 ? 7.0 : 1.6;
        d.vx *= math.exp(-f * dt);
        d.vz *= math.exp(-f * dt);
      }
      if (x.abs() > 4.05) {
        x = x.sign * 4.05;
        d.vx = -d.vx * .55;
        host.sfx(Sfx.clang, volume: .25, rate: 1.6);
      }
      if (z > 3.95) {
        z = 3.95;
        d.vz = -d.vz * .5;
        host.sfx(Sfx.thud, volume: .5, rate: 1.4);
        host.shake(2);
      }
      if (z < -4.0) {
        z = -4.0;
        d.vz = -d.vz * .5;
      }
      d.pos = V3(x, y, z);
      if (u >= 1) d.settled = true;
    }
    // dice vs dice
    final a = _dice[0], b = _dice[1];
    final dx = b.pos.x - a.pos.x, dz = b.pos.z - a.pos.z;
    final dist = sqrt(dx * dx + dz * dz);
    if (dist < 1.1 && (a.pos.y - b.pos.y).abs() < 1 && dist > 1e-4) {
      final nx = dx / dist, nz = dz / dist, push = (1.1 - dist) / 2;
      a.pos = V3(a.pos.x - nx * push, a.pos.y, a.pos.z - nz * push);
      b.pos = V3(b.pos.x + nx * push, b.pos.y, b.pos.z + nz * push);
      final rel = (b.vx - a.vx) * nx + (b.vz - a.vz) * nz;
      if (rel < 0) {
        a
          ..vx += nx * rel * .8
          ..vz += nz * rel * .8;
        b
          ..vx -= nx * rel * .8
          ..vz -= nz * rel * .8;
        host.sfx(Sfx.dice, volume: .5, rate: 1.3);
      }
    }
  }

  void _result() {
    _ph = _Ph.result;
    _phT = 0;
    _sum = _dice[0].value + _dice[1].value;
    _history.add(_sum);
    _sumPop = 1;
    final at = const Offset(180, 200);
    if (_sum == _target) {
      _ph = _Ph.done;
      _celebrate = 3;
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.coins);
      host.sfx(Sfx.cheer, volume: .7);
      host.shake(10, .4);
      host.flash(Pal.gold, .25);
      host.punch(.08);
      host.fx.coins(at, count: 30, speed: 520);
      host.fx.confetti();
      host.fx.ring(at, Pal.gold, size: 160, life: .6);
      host.fx.pop(host.tr('jackpot', 'JACKPOT!'), const Offset(180, 290), color: Pal.gold, size: 42, life: 1.4);
      host.addScore(_throws == 1 ? 7777 : 777, const Offset(180, 330));
      _winDelay = .55;
    } else {
      final off = (_sum - _target).abs();
      if (off == 1) {
        host.fx.pop(host.tr('so_close', 'SO CLOSE!'), const Offset(180, 290), color: Pal.orange, size: 30);
        host.sfx(Sfx.aww);
      } else {
        host.fx.pop(host.tr('miss', 'MISS'), const Offset(180, 290), color: Pal.gray, size: 30);
        host.sfx(Sfx.wrong);
      }
      host.shake(3);
    }
  }

  @override
  void onTimeUp() {
    if (_winDelay > 0) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ----------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    _background(c);
    final cam = scene.cam
      ..center = const Offset(180, 330)
      ..focal = 410
      ..pos = V3(_camX, 8.6 - (_celebrate > 0 ? .6 : 0), -10.2 + _camZ)
      ..lookAt(V3(_camX * .6, 0, .9 + _camZ));
    // pass 1: table + felt art + shadows
    scene.clear();
    scene.add(_base, pos: const V3(0, -.62, 0));
    scene.add(_felt, pos: const V3(0, .001, 0));
    scene.render(c);
    _feltArt(c, cam);
    for (final d in _dice) {
      final h = max(0.0, d.pos.y - .5);
      _groundPoly(c, cam, d.pos.x + h * .25, d.pos.z + h * .3, .62 + h * .12,
          Color.fromRGBO(0, 20, 5, (.45 - h * .08).clamp(.08, .45)));
    }
    // pass 2: rails, chips, dice
    scene.clear();
    scene.add(_rails);
    scene.add(_chipsA, pos: const V3(-5.0, .55, 3.9));
    scene.add(_chipsB, pos: const V3(-5.0, .55, 2.9), rotY: .4);
    scene.add(_chipsB, pos: const V3(5.0, .55, 3.7), rotY: 1.1);
    scene.add(_chipsA, pos: V3(5.0, .55, 2.6), rotY: _t);
    for (final d in _dice) {
      scene.addSprite(d.pos, (cv, s, k) => _drawDie(cv, d));
    }
    scene.render(c);
    _hud(c);
  }

  void _background(Canvas c) {
    D.gradientBg(c, const [Color(0xFF3A0A2A), Color(0xFF6A1238), Color(0xFF200818)]);
    // casino bokeh
    for (var i = 0; i < 14; i++) {
      final x = (i * 71.3 + _t * (8 + i % 4 * 3)) % 400 - 20;
      final y = 60 + (i * 37 % 150).toDouble();
      final col = [Pal.gold, Pal.pink, Pal.orange, Pal.purple][i % 4];
      c.drawCircle(Offset(x, y), 10 + (i % 5) * 5.0,
          Paint()..color = col.withValues(alpha: .12 + .08 * sin(_t * 2 + i)));
    }
    // marquee bulbs arc
    for (var i = 0; i < 19; i++) {
      final a = pi + i / 18 * pi;
      final p = Offset(180 + cos(a) * 170, 225 + sin(a) * 140);
      final on = ((i + (_t * 8).floor()) % 3 == 0) || _celebrate > 0 && (i + (_t * 20).floor()).isEven;
      c.drawCircle(p, on ? 7 : 5, Paint()..color = on ? const Color(0x55FFE08A) : const Color(0x00000000));
      c.drawCircle(p, 4, Paint()..color = on ? const Color(0xFFFFF1B0) : const Color(0xFF7A4A30));
    }
  }

  void _groundPoly(Canvas c, Camera3 cam, double x, double z, double r, Color col, {double y = .01}) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final a = i / 16 * pi * 2;
      final p = cam.project(V3(x + cos(a) * r, y, z + sin(a) * r));
      if (p == null) return;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    c.drawPath(path, Paint()..color = col);
  }

  void _feltArt(Canvas c, Camera3 cam) {
    // painted target ring + "7"
    final glow = _celebrate > 0 ? .5 + .5 * sin(_t * 20) : .0;
    _ringOutline(c, cam, 0, 1.2, 1.7, Color.lerp(const Color(0xAAFFD23F), Pal.white, glow)!, 4);
    _ringOutline(c, cam, 0, 1.2, 1.45, const Color(0x66FFD23F), 2);
    final p = cam.project(const V3(0, 0, 1.2));
    if (p != null) {
      c.save();
      c.translate(p.dx, p.dy);
      c.scale(1, .5);
      D.text(c, '$_target', Offset.zero, size: 90, color: const Color(0x55FFE9A0));
      c.restore();
    }
    // pass line
    _ringOutline(c, cam, 0, 0.8, 3.7, const Color(0x33FFFFFF), 2);
  }

  void _ringOutline(Canvas c, Camera3 cam, double x, double z, double r, Color col, double w) {
    final path = Path();
    for (var i = 0; i <= 28; i++) {
      final a = i / 28 * pi * 2;
      final p = cam.project(V3(x + cos(a) * r, .01, z + sin(a) * r * .8));
      if (p == null) return;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    c.drawPath(path, D.stroke(col, w));
  }

  static final List<Offset> _round = () {
    final pts = <Offset>[];
    const h = .5, r = .15;
    const cs = [(1.0, 1.0), (-1.0, 1.0), (-1.0, -1.0), (1.0, -1.0)];
    for (var k = 0; k < 4; k++) {
      final (sx, sy) = cs[k];
      for (var i = 0; i <= 3; i++) {
        final a = k * pi / 2 + i / 3 * pi / 2;
        pts.add(Offset(sx * (h - r) + cos(a) * r, sy * (h - r) + sin(a) * r));
      }
    }
    return pts;
  }();

  void _drawDie(Canvas c, _Die d) {
    final cam = scene.cam;
    final light = scene.light;
    for (final f in _Die.faces) {
      final n = _rot(f.$1, d.rx, d.ry, d.rz);
      final u = _rot(f.$2, d.rx, d.ry, d.rz);
      final v = _rot(f.$3, d.rx, d.ry, d.rz);
      final fc = d.pos + n * .5;
      if (n.dot(cam.pos - fc) <= 0) continue;
      final k = .5 + .62 * max(0.0, n.dot(light));
      Color shade(Color b, double m) => Color.from(
          alpha: 1, red: (b.r * m).clamp(0, 1), green: (b.g * m).clamp(0, 1), blue: (b.b * m).clamp(0, 1));
      // outer square (bevel) then rounded face
      final outer = Path();
      final inner = Path();
      var ok = true;
      for (var i = 0; i < 4; i++) {
        final su = (i == 0 || i == 3) ? .5 : -.5, sv = i < 2 ? .5 : -.5;
        final p = cam.project(fc + u * su + v * sv);
        if (p == null) {
          ok = false;
          break;
        }
        i == 0 ? outer.moveTo(p.dx, p.dy) : outer.lineTo(p.dx, p.dy);
      }
      if (!ok) return;
      outer.close();
      for (var i = 0; i < _round.length; i++) {
        final o = _round[i] * .93;
        final p = cam.project(fc + u * o.dx + v * o.dy)!;
        i == 0 ? inner.moveTo(p.dx, p.dy) : inner.lineTo(p.dx, p.dy);
      }
      inner.close();
      c.drawPath(outer, Paint()..color = shade(d.body, k * .72));
      c.drawPath(inner, Paint()..color = shade(d.body, k));
      // pips
      final pr = f.$4 == 1 ? .15 : .095;
      final pipCol = shade(f.$4 == 1 ? d.pip1 : d.pip, .75 + k * .3);
      for (final pp in _Die.pips[f.$4]!) {
        final pc = fc + u * (pp.$1 * .26) + v * (pp.$2 * .26) + n * .005;
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final a = i / 10 * pi * 2;
          final p = cam.project(pc + u * (cos(a) * pr) + v * (sin(a) * pr))!;
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
        c.drawPath(path, Paint()..color = pipCol);
      }
    }
  }

  void _hud(Canvas c) {
    // target badge
    final pulse = 1 + .06 * sin(_t * 5);
    c.save();
    c.translate(180, 92);
    c.scale(pulse);
    D.rrect(c, const Rect.fromLTWH(-74, -34, 148, 68), 22, const Color(0xFF2A0A1E), border: Pal.gold, borderWidth: 4);
    D.text(c, host.tr('goal', 'GOAL'), const Offset(-36, 0), size: 16, color: Pal.cream);
    D.text(c, '$_target', const Offset(34, -2), size: 50, color: Pal.gold, stroke: Pal.ink, strokeWidth: 8);
    c.restore();
    // throws left
    for (var i = 0; i < _maxThrows; i++) {
      final used = i < _throws;
      final o = Offset(292 + i * 22.0, 150);
      D.rrect(c, Rect.fromCenter(center: o, width: 17, height: 17), 4, used ? const Color(0x55FFFFFF) : Pal.cream,
          border: Pal.ink, borderWidth: 2);
      if (!used) c.drawCircle(o, 2.4, D.fill(Pal.red));
    }
    // history
    for (var i = 0; i < _history.length; i++) {
      final hit = _history[i] == _target;
      D.text(c, '${_history[i]}', Offset(34 + i * 30.0, 150), size: 18,
          color: hit ? Pal.gold : const Color(0xAAFFFFFF), stroke: Pal.ink, strokeWidth: 4);
    }
    // result sum
    if (_ph == _Ph.result || _ph == _Ph.done) {
      final win = _sum == _target;
      final s = 1 + _sumPop * .5;
      if (win) D.rays(c, const Offset(180, 222), 170, const Color(0x33FFE070), t: _t, count: 14);
      c.save();
      c.translate(180, 222);
      c.scale(s);
      D.text(c, '${_dice[0].value} + ${_dice[1].value} = $_sum', Offset.zero, size: 30,
          color: win ? Pal.gold : Pal.white, stroke: Pal.ink, strokeWidth: 7);
      c.restore();
    }
    // shake meter
    if (_ph == _Ph.ready || _ph == _Ph.charging) {
      const r = Rect.fromLTWH(40, 560, 280, 26);
      D.rrect(c, r.inflate(5), 16, const Color(0xCC1B0A14), border: Pal.gold, borderWidth: 2.5);
      D.rrect(c, r, 13, const Color(0xFF3B1830));
      Rect zone(double a, double b) => Rect.fromLTRB(r.left + r.width * a, r.top, r.left + r.width * b, r.bottom);
      D.rrect(c, zone(_greenA, _greenB), 6, const Color(0xFF3BAA55));
      D.rrect(c, zone(_goldA, _goldB), 6, Color.lerp(Pal.gold, Pal.white, .3 * M.wave(_t, 3))!);
      D.text(c, host.tr('lucky', 'LUCKY'), Offset(r.left + r.width * (_goldA + _goldB) / 2, r.top - 16), size: 14,
          color: Pal.gold, stroke: Pal.ink, strokeWidth: 4);
      final nx = r.left + r.width * (_ph == _Ph.charging ? _charge : 0);
      final tri = Path()
        ..moveTo(nx, r.bottom + 2)
        ..lineTo(nx - 9, r.bottom + 16)
        ..lineTo(nx + 9, r.bottom + 16)
        ..close();
      c.drawRect(Rect.fromCenter(center: Offset(nx, r.center.dy), width: 5, height: r.height + 8), D.fill(Pal.white));
      c.drawPath(tri, D.fill(Pal.white));
      c.drawPath(tri, D.stroke(Pal.ink, 2));
      if (_ph == _Ph.ready) {
        D.text(c, host.tr('hold', 'HOLD'), const Offset(180, 530), size: 22, color: Pal.cream, stroke: Pal.ink,
            strokeWidth: 5);
        if (_throws == 0) D.hand(c, const Offset(180, 470), _t);
      }
    }
  }
}

enum _Ph { ready, charging, rolling, result, done }

class _Die {
  _Die(this.body, this.pip, this.pip1);
  final Color body, pip, pip1;
  V3 pos = V3.zero;
  double vx = 0, vy = 0, vz = 0;
  double rx = 0, ry = 0, rz = 0;
  double x0 = 0, x1 = 0, y0 = 0, y1 = 0, z0 = 0, z1 = 0;
  int value = 1;
  bool settled = false;

  /// Half-height of the rotated cube (so tumbling dice stand on corners).
  double get extent {
    double ay(V3 a) => G102._rot(a, rx, ry, rz).y.abs();
    return .5 * (ay(const V3(1, 0, 0)) + ay(const V3(0, 1, 0)) + ay(const V3(0, 0, 1)));
  }

  // normal, u, v, value (opposite faces sum to 7)
  static const faces = <(V3, V3, V3, int)>[
    (V3(0, 1, 0), V3(1, 0, 0), V3(0, 0, 1), 1),
    (V3(0, -1, 0), V3(1, 0, 0), V3(0, 0, -1), 6),
    (V3(1, 0, 0), V3(0, 0, 1), V3(0, 1, 0), 3),
    (V3(-1, 0, 0), V3(0, 0, -1), V3(0, 1, 0), 4),
    (V3(0, 0, 1), V3(-1, 0, 0), V3(0, 1, 0), 2),
    (V3(0, 0, -1), V3(1, 0, 0), V3(0, 1, 0), 5),
  ];

  static const pips = <int, List<(double, double)>>{
    1: [(0, 0)],
    2: [(-1, -1), (1, 1)],
    3: [(-1, -1), (0, 0), (1, 1)],
    4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
    5: [(-1, -1), (1, -1), (-1, 1), (1, 1), (0, 0)],
    6: [(-1, -1), (-1, 0), (-1, 1), (1, -1), (1, 0), (1, 1)],
  };
}
