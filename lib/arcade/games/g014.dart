import '../engine/engine.dart';

/// No.014 Hair Challenge — 3D runner. Drag to steer, grab hair bundles to grow
/// a ridiculously long braid, dodge the saws that chop it. At the finish the
/// hair is rolled out over a x1..x10 ladder.
class G014 extends MiniGame {
  static const _finishZ = 108.0;
  static const _tileLen = 1.5;
  static const _ladderZ = _finishZ + 3;
  static const _winMult = 3;

  final scene = Scene3();
  late final Mesh _road, _water, _finish, _bundle, _saw, _sawHub, _post, _archPost, _archTop;
  late final Mesh _leg, _arm, _body, _dress, _head, _hairCap, _bow;
  late final List<Mesh> _ladder;
  final List<_Item> _items = [];
  final List<double> _histZ = [], _histX = [];

  double _t = 0;
  double _x = 0, _z = 0;
  double _tx = 0; // steering target
  double _hair = 1.0; // length (world units)
  double _hairShown = 1.0;
  double _run = 0;
  int _phase = 0; // 0 run, 1 ladder
  double _phaseT = 0;
  double _cutFlash = 0;
  double _joy = 0;
  double _lastPX = 0;
  bool _dragging = false;
  bool _steered = false;
  int _ladderLit = 0;
  int _finalMult = 1;
  bool _decided = false;

  static const _hairA = Color(0xFFFFC94D);
  static const _hairB = Color(0xFFFFA92E);

  int get _mult => (1 + ((_hair - 1) / 1.2).floor()).clamp(1, 10);

  @override
  void init() {
    scene.ambient = .62;
    scene.diffuse = .48;
    scene.light = const V3(-.4, 1, -.5).normalized;
    _road = Mesh.grid(6, 12, 2, 6, (i, j) => (i + j).isEven ? const Color(0xFFFFB8E0) : const Color(0xFFFFA3D6));
    _water = Mesh.grid(40, 12, 4, 2, (i, j) => (i + j).isEven ? const Color(0xFF6FD3FF) : const Color(0xFF5CC6F5));
    _finish = Mesh.grid(6, 1, 8, 2, (i, j) => (i + j).isEven ? Pal.white : Pal.ink);
    _ladder = [
      for (var i = 0; i < 10; i++)
        Mesh.box(6, .4, _tileLen - .08, D.hsv(i * 30.0, .55, 1),
            colors: [D.hsv(i * 30.0, .55, 1), D.hsv(i * 30.0, .55, .6), D.hsv(i * 30.0, .65, .8), D.hsv(i * 30.0, .65, .8),
              D.hsv(i * 30.0, .6, .7), D.hsv(i * 30.0, .6, .7)])
    ];
    _bundle = Mesh.merge([
      (Mesh.sphere(.32, _hairA, lat: 4, lon: 7), const V3(0, 0, 0)),
      (Mesh.sphere(.26, _hairB, lat: 3, lon: 6), const V3(.2, -.18, .05)),
      (Mesh.sphere(.26, _hairB, lat: 3, lon: 6), const V3(-.2, -.18, -.05)),
      (Mesh.box(.28, .16, .16, Pal.pink), const V3(0, .3, 0)),
    ]);
    _saw = Mesh.cylinder(.72, .1, const Color(0xFFC9D3E0), seg: 12, cap: const Color(0xFFE6ECF4));
    _sawHub = Mesh.cylinder(.22, .16, Pal.red, seg: 8);
    _post = Mesh.box(.14, 1.0, .14, const Color(0xFF6E7890));
    _archPost = Mesh.box(.3, 3, .3, Pal.pink);
    _archTop = Mesh.box(6.5, .5, .3, Pal.yellow);
    _leg = Mesh.merge([(Mesh.box(.16, .62, .18, Pal.skin), const V3(0, -.31, 0)), (Mesh.box(.2, .14, .28, Pal.purple), const V3(0, -.64, .04))]);
    _arm = Mesh.merge([(Mesh.box(.12, .5, .12, Pal.skin), const V3(0, -.25, 0))]);
    _body = Mesh.box(.42, .42, .26, const Color(0xFFFF5FA8));
    _dress = Mesh.cone(.42, .5, const Color(0xFFFF4F9A), seg: 8);
    _head = Mesh.sphere(.27, Pal.skin, lat: 5, lon: 8);
    _hairCap = Mesh.sphere(.3, _hairA, lat: 5, lon: 8);
    _bow = Mesh.merge([(Mesh.box(.22, .14, .08, Pal.red), const V3(-.12, 0, 0)), (Mesh.box(.22, .14, .08, Pal.red), const V3(.12, 0, 0))]);

    // course
    var z = 10.0;
    var row = 0;
    while (z < _finishZ - 6) {
      final lane = (randInt(3) - 1) * 1.6;
      final roll = rng.nextDouble();
      final bladeChance = row < 2 ? 0 : (.35 + row * .02);
      if (roll < bladeChance) {
        // a saw in one lane, a hair line in another (risk vs reward)
        final other = lane + (chance(.5) ? 1.6 : -1.6);
        final o = other.abs() > 1.7 ? -other.sign * 1.6 : other;
        final moving = row > 6 && chance(.4);
        _items.add(_Item(1, moving ? 0 : lane, z, moving ? 1.6 : 0, rand(0, 6)));
        for (var k = 0; k < 2; k++) {
          _items.add(_Item(0, o, z - .6 + k * 1.3, 0, rand(0, 6)));
        }
        if (row > 3 && chance(.5)) {
          // bait: bundle right behind the saw
          _items.add(_Item(0, moving ? 0 : lane, z + 1.6, 0, rand(0, 6)));
        }
      } else {
        for (var k = 0; k < 3; k++) {
          _items.add(_Item(0, lane, z + k * 1.3, 0, rand(0, 6)));
        }
      }
      z += rand(6.2, 7.6);
      row++;
    }
  }

  double _speed() => 8.6 * host.speed;

  @override
  void update(double dt) {
    _t += dt;
    _cutFlash = max(0, _cutFlash - dt * 3);
    _joy = max(0, _joy - dt * 2);
    _hairShown = M.approach(_hairShown, _hair, 8, dt);
    if (_phase == 0) {
      _z += _speed() * dt;
      _run += dt * 14;
      _x = M.approach(_x, _tx, 14, dt);
      _histZ.add(_z);
      _histX.add(_x);
      if (_histZ.length > 600) {
        _histZ.removeRange(0, 100);
        _histX.removeRange(0, 100);
      }
      for (final it in _items) {
        if (it.taken) continue;
        final ix = it.xAt(_t);
        if ((it.z - _z).abs() > 1.2) continue;
        if (it.type == 0) {
          if ((ix - _x).abs() < .75 && (it.z - _z).abs() < .7) _collect(it);
        } else if ((ix - _x).abs() < .9 && (it.z - _z).abs() < .35) {
          _cut(it);
        }
      }
      if (_z >= _finishZ) {
        _phase = 1;
        _phaseT = 0;
        _finalMult = _mult;
        host.sfx(Sfx.whistle);
        host.sfx(Sfx.drumroll, volume: .7);
      }
    } else {
      _phaseT += dt;
      // walk to the start of the ladder, centered
      _z = M.approach(_z, _ladderZ - 1.2, 5, dt);
      _x = M.approach(_x, 0, 5, dt);
      _run += dt * 8 * M.clamp01(1 - _phaseT);
      final extend = max(0.0, (_phaseT - .5) * 9);
      final lit = min(_finalMult, (extend / _tileLen).floor() + (extend > .2 ? 1 : 0)).clamp(0, 10);
      while (_ladderLit < lit) {
        _ladderLit++;
        host.sfx(Sfx.coin, rate: .8 + _ladderLit * .09);
        host.fx.pop('x$_ladderLit', const Offset(180, 200), color: D.hsv(_ladderLit * 30.0, .6, 1), size: 30 + _ladderLit * 2.0, life: .5);
      }
      if (!_decided && _ladderLit >= _finalMult && _phaseT > .6 + _finalMult * _tileLen / 9) {
        _decided = true;
        if (_finalMult >= _winMult) {
          _joy = 1;
          host.sfx(Sfx.fanfare);
          host.fx.confetti(count: 120);
          host.flash(Pal.white, .15);
          host.fx.pop('x$_finalMult!', const Offset(180, 250), color: Pal.yellow, size: 56, life: 1.5);
          host.addScore(_finalMult * 100);
          host.win(stars: _finalMult >= 8 ? 3 : (_finalMult >= 5 ? 2 : 1));
        } else {
          host.sfx(Sfx.aww);
          host.fx.pop(host.tr('oops', 'OOPS!'), const Offset(180, 250), color: Pal.red, size: 44);
          host.lose();
        }
      }
    }
  }

  void _collect(_Item it) {
    it.taken = true;
    _hair += .72;
    _joy = 1;
    host.sfx(Sfx.pickup, rate: .9 + min(_hair, 14) * .04);
    final p = scene.cam.project(V3(it.xAt(_t), .8, it.z)) ?? const Offset(180, 400);
    host.fx.burst(p, _hairA, colors: const [_hairA, _hairB, Pal.pink], count: 10, speed: 180, size: 6, shape: PartShape.star, gravity: 0);
    host.fx.pop('+1', p + const Offset(0, -20), color: Pal.yellow, size: 22, life: .5);
    host.addScore(10);
  }

  void _cut(_Item it) {
    it.taken = true;
    final lost = _hair - max(.5, _hair * .45);
    _hair -= lost;
    _cutFlash = 1;
    host.sfx(Sfx.slash);
    host.sfx(Sfx.rip, volume: .7);
    host.shake(8);
    host.flash(Pal.red, .1);
    host.hitStop(.06);
    final p = scene.cam.project(V3(_x, .3, _z - 1)) ?? const Offset(180, 460);
    host.fx.burst(p, _hairA, colors: const [_hairA, _hairB], count: 16 + (lost * 3).round(), speed: 320, size: 8, shape: PartShape.confetti, gravity: 700);
    host.fx.pop(host.tr('oops', 'OOPS!'), p + const Offset(0, -80), color: Pal.red, size: 30);
  }

  double _xAtZ(double z) {
    if (_histZ.isEmpty) return _x;
    for (var i = _histZ.length - 1; i >= 0; i--) {
      if (_histZ[i] <= z) return _histX[i];
    }
    return _histX.first;
  }

  @override
  void onDown(Offset p) {
    _dragging = true;
    _lastPX = p.dx;
  }

  @override
  void onMove(Offset p) {
    if (!_dragging || _phase != 0) return;
    _tx = (_tx + (p.dx - _lastPX) * .022).clamp(-2.2, 2.2);
    _lastPX = p.dx;
    _steered = true;
  }

  @override
  void onUp(Offset p) => _dragging = false;

  @override
  void onKey(String key, bool down) {
    if (!down || _phase != 0) return;
    if (key == 'left') _tx = max(-1.6, _tx - 1.6);
    if (key == 'right') _tx = min(1.6, _tx + 1.6);
  }

  @override
  void onTimeUp() {
    if (_phase == 1 && _mult >= _winMult) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF7FD8FF), Color(0xFFC9F0FF), Color(0xFFFFE3F3)]);
    for (var i = 0; i < 4; i++) {
      final x = (i * 120 - _z * 2 + 400) % 480 - 60;
      D.cloud(c, Offset(x, 70 + i * 22.0), 40 + i * 6.0);
    }

    final ladder = _phase == 1;
    final camK = ladder ? M.easeInOut(M.clamp01(_phaseT / 1.0)) : 0.0;
    scene.cam
      ..center = const Offset(180, 300)
      ..focal = 400
      ..pos = V3(_x * .6 * (1 - camK), 4.2 + camK * 4.5, _z - 6.2 + camK * 2)
      ..lookAt(V3(_x * .4 * (1 - camK), 1.0 - camK * .8, _z + 4 + camK * 4));
    scene.fogColor = const Color(0xFFFFE3F3);
    scene.fogNear = 30;
    scene.fogFar = 55;

    // pass 1: ground
    scene.clear();
    final tile0 = ((_z - 12) / 12).floor();
    for (var i = tile0; i < tile0 + 6; i++) {
      final tz = i * 12.0 + 6;
      scene.add(_water, pos: V3(0, -.35, tz));
      if (tz - 6 < _finishZ + 1) scene.add(_road, pos: V3(0, 0, tz));
    }
    scene.add(_finish, pos: const V3(0, .02, _finishZ));
    scene.render(c);

    // pass 2: things on top
    scene.clear();
    for (var i = 0; i < 10; i++) {
      final lit = i < _ladderLit;
      scene.add(_ladder[i], pos: V3(0, -.18, _ladderZ + i * _tileLen + _tileLen / 2), flash: lit ? .25 + .1 * sin(_t * 10 + i) : 0);
      final lp = V3(0, .05, _ladderZ + i * _tileLen + _tileLen / 2);
      scene.addSprite(lp + const V3(0, 0, -.6), (cv, s, k) {
        D.text(cv, 'x${i + 1}', s, size: (k * .55).clamp(8, 40), color: Pal.white, stroke: Pal.ink);
      });
    }
    // side rails: finish arch posts
    for (final sx in [-3.1, 3.1]) {
      scene.add(_archPost, pos: V3(sx, 1.5, _finishZ));
    }
    scene.add(_archTop, pos: const V3(0, 3.1, _finishZ));

    for (final it in _items) {
      if (it.taken || it.z < _z - 3 || it.z > _z + 40) continue;
      final ix = it.xAt(_t);
      if (it.type == 0) {
        scene.add(_bundle, pos: V3(ix, .7 + sin(_t * 4 + it.phase) * .15, it.z), rotY: _t * 3 + it.phase);
        scene.addSprite(V3(ix, .02, it.z), (cv, s, k) => D.shadow(cv, s, k * .8, k * .25, .18));
      } else {
        scene.add(_post, pos: V3(ix, .5, it.z + .15));
        scene.add(_saw, pos: V3(ix, 1.0, it.z), rotX: pi / 2, rotZ: _t * 12);
        scene.add(_sawHub, pos: V3(ix, 1.0, it.z - .05), rotX: pi / 2, rotZ: _t * 12);
        // teeth as sprites for a crisp silhouette
        scene.addSprite(V3(ix, 1.0, it.z - .08), (cv, s, k) {
          final r = k * .78;
          final path = Path();
          for (var j = 0; j < 12; j++) {
            final a = _t * 12 + j * pi / 6;
            final a2 = a + pi / 12;
            final p1 = s + Offset(cos(a) * r * .88, sin(a) * r * .88);
            final p2 = s + Offset(cos(a2) * r * 1.12, sin(a2) * r * 1.12);
            j == 0 ? path.moveTo(p1.dx, p1.dy) : path.lineTo(p1.dx, p1.dy);
            path.lineTo(p2.dx, p2.dy);
          }
          path.close();
          cv.drawPath(path, D.fill(const Color(0xFFE6ECF4)));
          cv.drawPath(path, D.stroke(Pal.ink, max(1.5, k * .05)));
          cv.drawCircle(s, r * .3, D.fill(Pal.red));
          cv.drawCircle(s, r * .3, D.stroke(Pal.ink, max(1.5, k * .05)));
          cv.drawCircle(s, r * .1, D.fill(Pal.white));
        });
      }
    }

    _addGirl();
    _addHair();
    scene.render(c);

    _renderHud(c);
    if (!_steered && host.time < 2.6) {
      final x = 180 + sin(_t * 3) * 60;
      D.hand(c, Offset(x, 540), _t);
      D.arrow(c, const Offset(110, 600), const Offset(-1, 0), 44, Pal.white, width: 8);
      D.arrow(c, const Offset(250, 600), const Offset(1, 0), 44, Pal.white, width: 8);
    }
  }

  void _addGirl() {
    final turn = _phase == 1 ? M.easeInOut(M.clamp01((_phaseT - .2) / .5)) * pi : 0.0;
    final bob = _phase == 0 ? sin(_run * 2).abs() * .1 : (_joy > 0 ? sin(_t * 18).abs() * .3 : 0.0);
    final base = V3(_x, bob, _z);
    final sw = sin(_run) * .8 * (_phase == 0 ? 1.0 : M.clamp01(1 - _phaseT));
    final lean = (_tx - _x) * .12;
    V3 rel(double x, double y, double z) {
      final c = cos(turn), s = sin(turn);
      return base + V3(x * c + z * s, y, -x * s + z * c);
    }

    scene.add(_leg, pos: rel(-.12, .72, 0), rotX: sw, rotY: turn);
    scene.add(_leg, pos: rel(.12, .72, 0), rotX: -sw, rotY: turn);
    scene.add(_dress, pos: rel(0, .78, 0), rotY: turn, rotZ: lean);
    scene.add(_body, pos: rel(0, 1.1, 0), rotY: turn, rotZ: lean);
    final armUp = _decided && _finalMult >= _winMult ? pi * .9 : 0.0;
    scene.add(_arm, pos: rel(-.28, 1.28, 0), rotX: -sw * .8, rotZ: -armUp, rotY: turn);
    scene.add(_arm, pos: rel(.28, 1.28, 0), rotX: sw * .8, rotZ: armUp, rotY: turn);
    final hp = rel(0, 1.55, 0);
    scene.add(_head, pos: hp, rotY: turn, flash: _cutFlash * .5);
    scene.add(_hairCap, pos: rel(0, 1.6, .06), rotY: turn, scale3: const V3(1, .9, 1));
    scene.add(_bow, pos: rel(0, 1.86, .05), rotY: turn);
    if (turn > 1.5) {
      // she faces the camera at the end: draw a face
      final fp = rel(0, 1.53, -.26);
      scene.addSprite(fp + const V3(0, 0, -.3), (cv, s, k) {
        final sp = scene.cam.project(fp) ?? s;
        final f = !_decided ? Face.shocked : (_finalMult >= _winMult ? (_finalMult >= 8 ? Face.love : Face.happy) : Face.cry);
        D.face(cv, sp, k * .24, f);
      });
    }
  }

  void _addHair() {
    final len = _phase == 0 ? _hairShown : 0.0;
    final verts = <V3>[];
    final faces = <Face3>[];
    void strip(List<V3> pts, List<double> widths) {
      for (var i = 0; i < pts.length; i++) {
        final w = widths[i] / 2;
        verts.add(pts[i] + V3(-w, 0, 0));
        verts.add(pts[i] + V3(w, 0, 0));
        if (i > 0) {
          final b = verts.length - 4;
          faces.add(Face3([b, b + 1, b + 3, b + 2], i.isEven ? _hairA : _hairB));
        }
      }
    }

    if (_phase == 0) {
      // braid: from the back of the head down to the ground, then trailing on the road
      final pts = <V3>[];
      final ws = <double>[];
      const hang = 1.3;
      final n = min(70, (len / .3).ceil() + 5);
      for (var i = 0; i <= n; i++) {
        final s = len * i / n;
        final taper = .55 - .3 * (i / n);
        if (s < hang) {
          final k = s / hang;
          final z = _z - .25 - k * .9;
          pts.add(V3(M.lerp(_x, _xAtZ(z), k), 1.55 - (1.45 * k * k) + sin(_run + k * 3) * .04 * k, z));
        } else {
          final z = _z - 1.15 - (s - hang);
          pts.add(V3(_xAtZ(z) + sin(s * 2 - _t * 8) * .05, .1 + sin(s * 3 - _t * 10).abs() * .06, z));
        }
        ws.add(taper);
      }
      strip(pts, ws);
    } else {
      // ending: the hair rolls out over the ladder like a measuring tape
      final extend = min(_hair, max(0.0, (_phaseT - .5) * 9)).toDouble();
      final roll = min(_finalMult * _tileLen, extend);
      final pts = <V3>[V3(_x, 1.4, _z - .1), V3(_x, .6, _z + .5), V3(_x, .25, _ladderZ - .2)];
      final ws = <double>[.5, .55, .6];
      final n = max(1, (roll / .4).ceil());
      for (var i = 1; i <= n; i++) {
        pts.add(V3(sin(i * .8 + _t * 6) * .08, .25, _ladderZ + roll * i / n));
        ws.add(.6 - .25 * i / n);
      }
      strip(pts, ws);
    }
    if (faces.isNotEmpty) scene.add(Mesh(verts, faces, doubleSided: true), flash: _joy * .15);
  }

  void _renderHud(Canvas c) {
    final m = _phase == 0 ? _mult : _finalMult;
    final ok = m >= _winMult;
    final box = const Rect.fromLTWH(118, 48, 124, 56);
    D.rrect(c, box.shift(const Offset(0, 5)), 18, const Color(0x55000000));
    D.rrect(c, box, 18, ok ? Pal.yellow : Pal.white, border: Pal.ink, borderWidth: 3);
    // tiny braid icon
    for (var i = 0; i < 4; i++) {
      c.drawOval(Rect.fromCenter(center: Offset(142, 60 + i * 9.0), width: 14, height: 11), D.fill(i.isEven ? _hairA : _hairB));
      c.drawOval(Rect.fromCenter(center: Offset(142, 60 + i * 9.0), width: 14, height: 11), D.stroke(Pal.ink, 1.5));
    }
    D.text(c, 'x$m', const Offset(196, 76), size: 34 + (_joy * 6), color: ok ? Pal.red : Pal.ink);
    // progress along the course
    final prog = M.clamp01(_z / _finishZ);
    D.bar(c, const Rect.fromLTWH(60, 116, 240, 10), prog, Pal.pink, back: const Color(0x55FFFFFF), border: Pal.ink);
    // goal marker on the ladder threshold
    D.text(c, '${host.tr('goal', 'GOAL')} x$_winMult', const Offset(300, 140), size: 13, color: Pal.ink, anchor: Alignment.centerRight);
  }
}

class _Item {
  _Item(this.type, this.x, this.z, this.amp, this.phase);
  final int type; // 0 hair bundle, 1 saw
  final double x, z, amp, phase;
  bool taken = false;
  double xAt(double t) => amp == 0 ? x : sin(t * 1.8 + phase) * amp;
}
