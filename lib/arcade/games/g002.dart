import '../engine/engine.dart';

/// No.002 Gate Runner x100 — 3D crowd runner. Steer through math gates,
/// crush red crowds and out-number the giant boss at the end.
class G002 extends MiniGame {
  static const _rowZ0 = 18.0, _rowGap = 17.0, _rows = 6;
  static const _halfW = 4.0;
  static const _maxShown = 64;

  final scene = Scene3();
  late final Mesh _body = Mesh.merge([
    (Mesh.box(.42, .46, .26, const Color(0xFF3D7BFF)), const V3(0, .62, 0)),
    (Mesh.box(.34, .32, .32, const Color(0xFF6FA8FF)), const V3(0, 1.04, 0)),
  ]);
  late final Mesh _bodyRed = Mesh.merge([
    (Mesh.box(.42, .46, .26, const Color(0xFFFF3B5C)), const V3(0, .62, 0)),
    (Mesh.box(.34, .32, .32, const Color(0xFFFF7A8E)), const V3(0, 1.04, 0)),
  ]);
  late final Mesh _leg = Mesh.merge([(Mesh.box(.14, .4, .14, const Color(0xFF22306B)), const V3(0, -.2, 0))]);
  late final Mesh _legRed = Mesh.merge([(Mesh.box(.14, .4, .14, const Color(0xFF7A1530)), const V3(0, -.2, 0))]);
  late final Mesh _post = Mesh.box(.3, 3.0, .3, const Color(0xFFFFFFFF));
  late final Mesh _beam = Mesh.box(8.3, .3, .3, const Color(0xFFFFFFFF));
  late final Mesh _panelGood = Mesh.box(3.7, 2.5, .08, const Color(0xFF3FB8FF));
  late final Mesh _panelBad = Mesh.box(3.7, 2.5, .08, const Color(0xFFFF3B5C));
  late final Mesh _pine = Models.pine();
  late final Mesh _rock = Mesh.sphere(.9, const Color(0xFFB9A7D9), lat: 3, lon: 6);
  late final Mesh _bossBody = Mesh.merge([
    (Mesh.box(.5, 1.0, .5, const Color(0xFF7A1530)), const V3(-.35, .5, 0)),
    (Mesh.box(.5, 1.0, .5, const Color(0xFF7A1530)), const V3(.35, .5, 0)),
    (Mesh.box(1.5, 1.3, .9, const Color(0xFFE02850)), const V3(0, 1.65, 0)),
    (Mesh.box(.4, 1.1, .4, const Color(0xFFFF5470)), const V3(-1.0, 1.6, 0)),
    (Mesh.box(.4, 1.1, .4, const Color(0xFFFF5470)), const V3(1.0, 1.6, 0)),
    (Mesh.box(1.0, .9, .9, const Color(0xFFFF7A8E)), const V3(0, 2.75, 0)),
    (Mesh.cone(.18, .5, const Color(0xFFFFD23F), seg: 5), const V3(-.35, 3.4, 0)),
    (Mesh.cone(.18, .5, const Color(0xFFFFD23F), seg: 5), const V3(.35, 3.4, 0)),
  ]);

  final List<_Row> _gates = [];
  final List<_Enemy> _enemies = [];
  final List<_Runner> _runners = [];
  int _count = 10;
  double _x = 0, _tx = 0;
  double _z = 0;
  double _t = 0;
  int _bossHp = 100;
  int _bossHp0 = 100;
  static const _bossZ = 124.0;
  // fight state
  _Enemy? _fight;
  bool _bossFight = false;
  double _fightAcc = 0;
  bool _bossDown = false;
  double _bossFall = 0;
  bool _lost = false;
  double _flagPop = 0;
  double _dragX0 = 0, _dragPx = 0;
  int _keyDir = 0;
  double _hint = 1;

  // ---------------------------------------------------------------- setup ---
  @override
  void init() {
    scene.ambient = .6;
    scene.diffuse = .5;
    scene.fogColor = const Color(0xFFBFE6FF);
    scene.fogNear = 40;
    scene.fogFar = 75;
    for (var i = 0; i < _rows; i++) {
      _gates.add(_makeRow(i, _rowZ0 + i * _rowGap));
    }
    // enemies between some rows
    for (final i in const [1, 3, 5]) {
      _enemies.add(_Enemy(_rowZ0 + i * _rowGap + _rowGap * .5, 0));
    }
    // size enemies & boss against the best achievable path
    var best = _bestPath();
    for (var k = 0; k < _enemies.length; k++) {
      _enemies[k].count = max(3, (_countBefore(_enemies[k].z, best) * rand(.25, .4)).round());
    }
    best = _bestPath();
    final fin = _simulate(best);
    _bossHp = max(20, (fin * rand(.5, .62)).round());
    _bossHp0 = _bossHp;
    _count = 10;
    _syncRunners(instant: true);
  }

  _Row _makeRow(int i, double z) {
    final type = i == 0 ? 0 : randInt(4);
    _Op good, bad;
    switch (type) {
      case 0:
        good = _Op('+', 10 + randInt(3) * 5);
        bad = _Op('-', 5 + randInt(3) * 5);
      case 1:
        good = _Op('x', 2);
        bad = _Op('+', 10 + randInt(3) * 5);
      case 2:
        good = _Op('x', chance(.3) ? 3 : 2);
        bad = _Op('/', 2);
      default:
        good = _Op('+', 20 + randInt(4) * 5);
        bad = _Op('/', 2);
    }
    final leftGood = chance(.5);
    return _Row(z, leftGood ? good : bad, leftGood ? bad : good);
  }

  int _apply(_Op op, int n) => switch (op.kind) {
        '+' => n + op.v,
        '-' => n - op.v,
        'x' => n * op.v,
        _ => (n / op.v).ceil(),
      };

  /// Returns bitmask of the best choice (bit i = choose right at row i).
  int _bestPath() {
    var bestMask = 0, bestN = -1;
    for (var m = 0; m < 1 << _rows; m++) {
      final n = _simulate(m);
      if (n > bestN) {
        bestN = n;
        bestMask = m;
      }
    }
    return bestMask;
  }

  int _simulate(int mask, {double untilZ = 1e9}) {
    var n = 10;
    final events = <(double, Object)>[
      for (var i = 0; i < _gates.length; i++) (_gates[i].z, i),
      for (final e in _enemies) (e.z, e),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (z, ev) in events) {
      if (z >= untilZ) break;
      if (ev is int) {
        final r = _gates[ev];
        n = _apply((mask >> ev) & 1 == 1 ? r.right : r.left, n);
      } else if (ev is _Enemy) {
        n -= ev.count;
      }
      if (n <= 0) return 0;
    }
    return n;
  }

  int _countBefore(double z, int mask) => _simulate(mask, untilZ: z);

  // ------------------------------------------------------------- runners ---
  void _syncRunners({bool instant = false}) {
    final want = min(_count, _maxShown);
    while (_runners.length < want) {
      final i = _runners.length;
      final r = _Runner(rand(0, 6.28));
      final a = i * 2.39996;
      final rad = .3 * sqrt(i.toDouble());
      r.tx = cos(a) * rad;
      r.tz = sin(a) * rad * .8;
      r.x = instant ? r.tx : 0;
      r.z = instant ? r.tz : -.5;
      r.scale = instant ? 1 : 0;
      _runners.add(r);
    }
    while (_runners.length > want && _runners.isNotEmpty) {
      final r = _runners.removeLast();
      final p = scene.cam.project(V3(_x + r.x, .7, _z + r.z));
      if (p != null) {
        host.fx.burst(p, Pal.sky, count: 3, speed: 140, size: 5, colors: const [Pal.sky, Pal.blue, Pal.white]);
      }
    }
  }

  void _changeCount(int n, Offset at) {
    final old = _count;
    _count = max(0, n);
    final diff = _count - old;
    _flagPop = 1;
    if (diff > 0) {
      host.sfx(Sfx.powerup, rate: 1 + min(diff, 60) / 120);
      host.fx.pop('+$diff', at, color: Pal.sky, size: 30);
      host.fx.burst(at, Pal.sky, count: 18, speed: 240, colors: const [Pal.sky, Pal.white, Pal.yellow]);
      host.addScore(diff);
    } else if (diff < 0) {
      host.sfx(Sfx.wrong, volume: .7);
      host.fx.pop('$diff', at, color: Pal.red, size: 30);
      host.shake(5);
    }
    _syncRunners();
  }

  // --------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    _flagPop = M.approach(_flagPop, 0, 6, dt);
    _hint = M.approach(_hint, host.time < 2.2 ? 1 : 0, 5, dt);
    if (_keyDir != 0) _tx = (_tx + _keyDir * 7 * dt).clamp(-3.1, 3.1);
    _x = M.approach(_x, _tx, 10, dt);
    final moving = _fight == null && !_bossFight && !host.finished;
    if (moving) {
      final prev = _z;
      _z += 10 * host.speed * dt;
      for (var i = 0; i < _gates.length; i++) {
        final g = _gates[i];
        if (!g.passed && prev < g.z && _z >= g.z) {
          g.passed = true;
          g.chosenRight = _x >= 0;
          final op = g.chosenRight ? g.right : g.left;
          final p = scene.cam.project(V3(g.chosenRight ? 2 : -2, 1.6, g.z)) ?? const Offset(180, 300);
          g.flash = 1;
          _changeCount(_apply(op, _count), p);
          if (op.good) {
            host.punch(.03);
            host.sfx(Sfx.whoosh, volume: .5, rate: 1.3);
          }
          if (_count <= 0) _defeat();
        }
      }
      for (final e in _enemies) {
        if (e.count > 0 && _z + 1.4 >= e.z - 1.2 && _fight == null) {
          _fight = e;
          _fightAcc = 0;
          host.sfx(Sfx.punch);
          host.shake(4);
        }
      }
      if (_z + 1.4 >= _bossZ - 2.2 && !_bossDown) {
        _bossFight = true;
        _fightAcc = 0;
        host.sfx(Sfx.hitHeavy);
        host.shake(6);
      }
    }
    // fights: both sides lose units at a steady rate
    final e = _fight;
    if (e != null && !host.finished) {
      final rate = max(12.0, e.count0 / .7);
      _fightAcc += rate * dt;
      while (_fightAcc >= 1 && e.count > 0 && _count > 0) {
        _fightAcc -= 1;
        e.count--;
        _count--;
      }
      e.shake = 1;
      _clash(V3(_x, .8, e.z - 1.3), Pal.red);
      _syncRunners();
      if (_count <= 0) {
        _defeat();
      } else if (e.count <= 0) {
        _fight = null;
        host.sfx(Sfx.explodeSmall);
        final p = scene.cam.project(V3(0, 1, e.z)) ?? const Offset(180, 300);
        host.fx.pop(host.tr('win', 'WIN!'), p, color: Pal.sky, size: 28);
        host.addScore(e.count0 * 2);
      }
    }
    if (_bossFight && !host.finished) {
      final rate = max(25.0, _bossHp0 / 1.4);
      _fightAcc += rate * dt;
      while (_fightAcc >= 1 && _bossHp > 0 && _count > 0) {
        _fightAcc -= 1;
        _bossHp--;
        _count--;
      }
      _clash(V3(_x * .5, 1.2 + rand(0, 2), _bossZ - 1.2), Pal.yellow);
      if ((_t * 12).floor() != ((_t - dt) * 12).floor()) host.sfx(Sfx.hit, volume: .5, rate: rand(.9, 1.4));
      _syncRunners();
      if (_bossHp <= 0) {
        _bossDown = true;
        _bossFight = false;
        host.sfx(Sfx.explode);
        host.sfx(Sfx.cheer);
        host.shake(12, .5);
        host.flash(Pal.white, .2);
        host.hitStop(.12);
        final p = scene.cam.project(V3(0, 3, _bossZ)) ?? const Offset(180, 250);
        host.fx.coins(p, count: 30);
        host.fx.confetti(at: p, count: 60);
        host.fx.pop('KO!', p, color: Pal.yellow, size: 56, life: 1.2);
        host.addScore(_count * 10);
        final ratio = _count / max(1, _bossHp0);
        host.win(stars: ratio > .5 ? 3 : (ratio > .15 ? 2 : 1));
      } else if (_count <= 0) {
        _defeat();
      }
    }
    if (_bossDown) _bossFall = min(1, _bossFall + dt * 1.8);
    for (final r in _runners) {
      r.phase += dt * 14;
      r.scale = M.approach(r.scale, 1, 10, dt);
      final tx = r.tx.clamp(-_halfW + .4 - _x, _halfW - .4 - _x);
      final target = (_fight != null || _bossFight) ? r.tz * .4 + .3 : r.tz;
      r.x = M.approach(r.x, tx, 8, dt);
      r.z = M.approach(r.z, target, 8, dt);
    }
    for (final g in _gates) {
      g.flash = M.approach(g.flash, 0, 4, dt);
    }
    for (final en in _enemies) {
      en.shake = M.approach(en.shake, 0, 6, dt);
    }
  }

  void _clash(V3 at, Color col) {
    if (chance(.5)) {
      final p = scene.cam.project(at);
      if (p != null) {
        host.fx.burst(p + Offset(rand(-30, 30), rand(-10, 10)), col,
            count: 3, speed: 160, size: 5, colors: [col, Pal.sky, Pal.white]);
      }
    }
  }

  void _defeat() {
    if (_lost) return;
    _lost = true;
    _count = 0;
    _syncRunners();
    host.sfx(Sfx.aww);
    host.shake(8);
    host.lose();
  }

  @override
  void onTimeUp() => _bossDown ? host.win(stars: 1) : host.lose();

  // ---------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    _dragPx = p.dx;
    _dragX0 = _tx;
  }

  @override
  void onMove(Offset p) {
    _tx = (_dragX0 + (p.dx - _dragPx) / 30).clamp(-3.1, 3.1);
  }

  @override
  void onKey(String key, bool down) {
    if (key == 'left') _keyDir = down ? -1 : (_keyDir == -1 ? 0 : _keyDir);
    if (key == 'right') _keyDir = down ? 1 : (_keyDir == 1 ? 0 : _keyDir);
  }

  // --------------------------------------------------------------- render ---
  @override
  void render(Canvas c) {
    final cam = scene.cam;
    final nearBoss = M.clamp01((_z - (_bossZ - 30)) / 20);
    cam
      ..center = const Offset(180, 300)
      ..focal = 330
      ..pos = V3(_x * .45, 6.5 + nearBoss * 1.5, _z - 8.5 - nearBoss * 2)
      ..lookAt(V3(_x * .45, .6, _z + 7));

    // sky
    D.gradientBg(c, const [Color(0xFF6CC8FF), Color(0xFFBFE6FF)], rect: const Rect.fromLTWH(0, 0, 360, 330));
    final hz = cam.project(V3(0, 0, _z + 400))?.dy ?? 200;
    for (var i = 0; i < 4; i++) {
      final x = (i * 120 - _t * 6) % 480 - 60;
      D.cloud(c, Offset(x, hz - 90 + (i % 2) * 30), 40 + (i % 3) * 10.0);
    }
    // distant mountains
    final mt = Path()..moveTo(0, hz);
    for (var i = 0; i <= 12; i++) {
      final x = i * 30.0;
      mt.lineTo(x, hz - 18 - (i.isEven ? 22 : 6) - (i % 3) * 8);
    }
    mt
      ..lineTo(360, hz)
      ..close();
    c.drawPath(mt, D.fill(const Color(0xFF9EC9F0)));
    // sea
    c.drawRect(Rect.fromLTRB(0, hz, 360, 640),
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF7FD8FF), Color(0xFF2C8BE0)]).createShader(Rect.fromLTRB(0, hz, 360, 640)));
    final wave = D.stroke(const Color(0x55FFFFFF), 2);
    for (var i = 0; i < 12; i++) {
      final y = hz + 10 + i * i * 3.2;
      final off = (_t * 20 + i * 37) % 60;
      for (var x = -60.0 + off; x < 360; x += 60) {
        c.drawLine(Offset(x, y), Offset(x + 16, y), wave);
      }
    }
    _drawTrack(c);

    scene.clear();
    // side props
    final base = (_z / 8).floor() * 8.0;
    for (var k = -1; k < 10; k++) {
      final z = base + k * 8.0;
      final s = ((z / 8).round() * 7919) % 5;
      scene.add(s < 3 ? _pine : _rock, pos: V3(-6.2 - s * .3, s < 3 ? -.2 : -.3, z), scale: s < 3 ? 1.1 : .9);
      scene.add(s != 1 ? _pine : _rock, pos: V3(6.2 + s * .2, s != 1 ? -.2 : -.3, z + 4), scale: 1.0);
    }
    // gates
    for (final g in _gates) {
      if (g.z < _z - .8 || g.z > _z + 70) continue;
      for (final x in const [-4.1, 0.0, 4.1]) {
        scene.add(_post, pos: V3(x, 1.5, g.z));
      }
      scene.add(_beam, pos: V3(0, 3.0, g.z));
      for (final right in const [false, true]) {
        final op = right ? g.right : g.left;
        final chosen = g.passed && g.chosenRight == right;
        if (chosen && g.flash < .05) continue;
        final cx = right ? 2.05 : -2.05;
        scene.add(op.good ? _panelGood : _panelBad,
            pos: V3(cx, 1.4, g.z), alpha: g.passed ? .35 : .62, flash: chosen ? g.flash : 0);
        scene.addSprite(V3(cx, 1.5, g.z - .1), (c, s, k) => _gateLabel(c, s, k, op));
      }
    }
    // enemies
    for (final e in _enemies) {
      if (e.count <= 0 || e.z > _z + 70) continue;
      final n = min(e.count, 36);
      for (var i = 0; i < n; i++) {
        final a = i * 2.39996;
        final rad = .3 * sqrt(i.toDouble());
        final jig = e.shake * sin(_t * 40 + i) * .08;
        final p = V3(cos(a) * rad * 1.3 + jig, 0, e.z + sin(a) * rad * .7);
        final hop = (sin(_t * 8 + i) * .5 + .5) * .15;
        _addPerson(p.withY(hop + .4), pi, 0, red: true);
      }
      final top = V3(0, 2.2, e.z);
      scene.addSprite(top, (c, s, k) => _flag(c, s, k * .02, '${e.count}', Pal.red));
    }
    // boss
    if (_z > _bossZ - 75) {
      final fall = M.easeOut(_bossFall);
      final bob = _bossDown ? 0.0 : sin(_t * 3) * .08;
      final hit = _bossFight ? (sin(_t * 30) * .5 + .5) * .5 : 0.0;
      scene.add(_bossBody,
          pos: V3(0, bob, _bossZ + fall * 1.5), rotX: fall * 1.45, rotY: pi, scale: 1.55, flash: hit);
      if (!_bossDown) {
        scene.addSprite(V3(0, 4.3, _bossZ - .75), (c, s, k) {
          D.face(c, s, k * .6, _bossFight ? Face.shocked : Face.angry, blush: false);
        });
        scene.addSprite(V3(0, 7.0, _bossZ), (c, s, k) => _bossBar(c, s, k));
      }
    }
    // crowd
    for (final r in _runners) {
      final bob = (sin(r.phase).abs()) * .14;
      _addPerson(V3(_x + r.x, bob + .4, _z + r.z), 0, r.phase, scale: r.scale);
    }
    scene.render(c);

    // crowd flag (always on top)
    if (_count > 0) {
      final fp = cam.project(V3(_x, 2.3, _z + .3));
      if (fp != null) _flag(c, fp, 1 + _flagPop * .35, '$_count', Pal.blue);
    }
    // tutorial
    if (_hint > .02) {
      final hx = 180 + sin(_t * 3) * 70;
      c.save();
      c.translate(0, 0);
      D.arrow(c, const Offset(110, 540), const Offset(-1, 0), 50, Color.fromRGBO(255, 255, 255, _hint), width: 12);
      D.arrow(c, const Offset(250, 540), const Offset(1, 0), 50, Color.fromRGBO(255, 255, 255, _hint), width: 12);
      D.hand(c, Offset(hx, 530), _t);
      c.restore();
    }
  }

  void _addPerson(V3 p, double yaw, double phase, {bool red = false, double scale = 1}) {
    if (scale < .05) return;
    final s = .9 * scale;
    final sw = sin(phase) * .8;
    final cy = cos(yaw), sy = sin(yaw);
    for (final side in const [-1.0, 1.0]) {
      final lx = side * .11 * s;
      scene.add(red ? _legRed : _leg,
          pos: V3(p.x + lx * cy, p.y, p.z - lx * sy), rotX: sw * side, rotY: yaw, scale: s);
    }
    scene.add(red ? _bodyRed : _body, pos: V3(p.x, p.y - .4 * s, p.z), rotY: yaw, scale: s);
  }

  void _gateLabel(Canvas c, Offset s, double k, _Op op) {
    final txt = switch (op.kind) { 'x' => '×${op.v}', '/' => '÷${op.v}', _ => '${op.kind}${op.v}' };
    final size = (k * .95).clamp(8.0, 70.0);
    // Operation-before-operand notation stays LTR inside an otherwise RTL game.
    D.text(c, txt, s, size: size, color: Pal.white, stroke: op.good ? const Color(0xFF0B4FA8) : const Color(0xFF8A0F2A), direction: TextDirection.ltr);
  }

  void _flag(Canvas c, Offset p, double scale, String txt, Color col) {
    if (scale < .15) return;
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    final w = 22.0 + txt.length * 13;
    D.rrect(c, Rect.fromCenter(center: const Offset(0, -16), width: w, height: 30), 12, col,
        border: Pal.ink, borderWidth: 3);
    c.drawPath(
        Path()
          ..moveTo(-7, -2)
          ..lineTo(0, 8)
          ..lineTo(7, -2)
          ..close(),
        D.fill(col));
    D.text(c, txt, const Offset(0, -16), size: 21, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
    c.restore();
  }

  void _bossBar(Canvas c, Offset s, double k) {
    final sc = (k / 30).clamp(.3, 1.4);
    c.save();
    c.translate(s.dx, s.dy);
    c.scale(sc);
    D.rrect(c, const Rect.fromLTWH(-70, -34, 140, 26), 13, const Color(0xFF1B1530), border: Pal.white, borderWidth: 3);
    D.bar(c, const Rect.fromLTWH(-64, -29, 128, 16), _bossHp / _bossHp0, Pal.red);
    D.text(c, 'BOSS $_bossHp', const Offset(0, -21), size: 16, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
    c.restore();
  }

  void _drawTrack(Canvas c) {
    final cam = scene.cam;
    final start = (_z - 7).floorToDouble();
    final end = min(_z + 72, _bossZ + 12);
    final pa = Paint();
    const step = 2.0;
    for (var z = end - ((end - start) % step); z >= start; z -= step) {
      final z0 = z, z1 = z + step;
      final a = cam.project(V3(-_halfW, 0, z0)), b = cam.project(V3(_halfW, 0, z0));
      final cc = cam.project(V3(_halfW, 0, z1)), d = cam.project(V3(-_halfW, 0, z1));
      if (a == null || b == null || cc == null || d == null) continue;
      final stripe = ((z / step).round()).isEven;
      final dist = ((z - _z) / 70).clamp(0.0, 1.0);
      pa.color = Color.lerp(stripe ? const Color(0xFFFFFFFF) : const Color(0xFFD5C6FF), const Color(0xFFBFE6FF), dist * .8)!;
      c.drawPath(Path()..addPolygon([a, b, cc, d], true), pa);
      // side rails
      for (final side in const [-1.0, 1.0]) {
        final r0 = cam.project(V3(side * _halfW, 0, z0)), r1 = cam.project(V3(side * _halfW, 0, z1));
        final q0 = cam.project(V3(side * (_halfW + .45), -.1, z0)), q1 = cam.project(V3(side * (_halfW + .45), -.1, z1));
        if (r0 == null || r1 == null || q0 == null || q1 == null) continue;
        pa.color = Color.lerp(stripe ? const Color(0xFFFF5FC8) : const Color(0xFFFFD23F), const Color(0xFFBFE6FF), dist * .8)!;
        c.drawPath(Path()..addPolygon([r0, r1, q1, q0], true), pa);
      }
    }
    // track side (thickness) below near edge for depth
    final boss = cam.project(V3(0, 0, _bossZ));
    if (boss != null) {
      c.drawOval(Rect.fromCenter(center: boss, width: 9 * cam.scaleAt(V3(0, 0, _bossZ)), height: 2.4 * cam.scaleAt(V3(0, 0, _bossZ))),
          D.fill(const Color(0x55FF3B5C)));
    }
  }
}

class _Op {
  _Op(this.kind, this.v);
  final String kind; // + - x /
  final int v;
  bool get good => kind == '+' || kind == 'x';
}

class _Row {
  _Row(this.z, this.left, this.right);
  final double z;
  final _Op left, right;
  bool passed = false;
  bool chosenRight = false;
  double flash = 0;
}

class _Enemy {
  _Enemy(this.z, this._count);
  final double z;
  int _count;
  int count0 = 0;
  double shake = 0;
  int get count => _count;
  set count(int v) {
    if (count0 == 0) count0 = v;
    _count = v;
  }
}

class _Runner {
  _Runner(this.phase);
  double phase;
  double x = 0, z = 0, tx = 0, tz = 0;
  double scale = 1;
}
