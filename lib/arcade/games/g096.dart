import 'dart:math' as math;

import '../engine/engine.dart';

/// No.096 Strike Bowling 3D — cosmic-bowling lane, swipe (with curve!) to roll,
/// pins topple with impulse physics. 2 frames, knock >= 15 pins to win.
class G096 extends MiniGame {
  static const _laneW = 2.1;
  static const _half = _laneW / 2;
  static const _headZ = 12.0;
  static const _pitZ = 14.0;
  static const _ballR = .24;
  static const _pinR = .15;
  static const _target = 15;

  final scene = Scene3();
  final floor = Scene3();

  late final Mesh _pinMesh;
  late final Mesh _ballMesh;
  late final Mesh _laneMesh;
  late final Mesh _sideLane;
  late final Mesh _gutterSeg;
  late final Mesh _deckMesh;
  late final Mesh _backWall;
  late final Mesh _hood;
  late final Mesh _sweepBar;
  late final Mesh _divider;

  final List<_Pin> _pins = [];
  double _t = 0;

  // ball
  double _bx = 0, _bz = 0, _by = _ballR, _bvx = 0, _bvz = 0, _roll = 0;
  bool _gutter = false;
  bool _free = false; // after first pin contact physics takes over
  double _pathX0 = 0, _pathA = 0, _pathB = 0;
  bool _ballGone = false;

  // state
  _St _st = _St.aim;
  double _stT = 0;
  int _frame = 0; // 0,1
  int _roll2 = 0; // 0 = first roll of frame, 1 = second
  final List<List<int>> _marks = [[], []]; // per-frame roll counts
  int _total = 0;
  int _knockedBefore = 0;
  int _strikes = 0, _spares = 0;
  double _camZ = 0;
  double _camY = 0;
  double _bannerT = 0;
  String _banner = '';
  Color _bannerCol = Pal.yellow;
  double _sweepY = 3;
  double _hitSoundCd = 0;
  bool _firstContact = false;

  // input
  final List<Offset> _drag = [];
  double _dragStartT = 0;
  bool _dragging = false;
  double _aimX = 0; // ball placement before throw
  double _keyAim = 0;

  @override
  void init() {
    scene
      ..ambient = .52
      ..diffuse = .62
      ..light = const V3(-.3, 1, -.6).normalized
      ..fogColor = const Color(0xFF1A0F33)
      ..fogNear = 9
      ..fogFar = 30;
    floor
      ..ambient = .6
      ..diffuse = .5
      ..light = scene.light
      ..fogColor = scene.fogColor
      ..fogNear = 9
      ..fogFar = 30;
    const pinWhite = Color(0xFFF8F4EE);
    const stripe = Color(0xFFE8263F);
    _pinMesh = Mesh.merge([
      (Mesh.cylinder(.1, .3, pinWhite, seg: 8, topRadius: _pinR), const V3(0, .15, 0)),
      (Mesh.cylinder(_pinR, .3, pinWhite, seg: 8, topRadius: .068), const V3(0, .45, 0)),
      (Mesh.cylinder(.068, .07, stripe, seg: 8, topRadius: .072), const V3(0, .635, 0)),
      (Mesh.sphere(.095, pinWhite, lat: 4, lon: 8), const V3(0, .74, 0)),
    ]);
    _ballMesh = Mesh.sphere(_ballR, const Color(0xFF8C2BFF), lat: 7, lon: 12);
    for (var i = 0; i < _ballMesh.faces.length; i++) {
      final lat = i ~/ 12, lon = i % 12;
      final swirl = sin(lon * .9 + lat * 1.7) + sin(lon * 2.3 - lat * .8) * .6;
      _ballMesh.faces[i].color = swirl > .7
          ? const Color(0xFFFF4FD8)
          : swirl < -.8
              ? const Color(0xFF3A1B9E)
              : const Color(0xFF8C2BFF);
    }
    // finger holes
    for (final i in [2, 3, 15]) {
      _ballMesh.faces[i].color = const Color(0xFF12081F);
    }
    _laneMesh = Mesh.grid(_laneW, 16, 7, 16, (i, j) {
      final plank = i.isEven ? const Color(0xFFE2B075) : const Color(0xFFD29C60);
      return Color.lerp(plank, const Color(0xFFF2CC94), ((i * 7 + j * 3) % 5) / 12)!;
    });
    _sideLane = Mesh.grid(2.4, 16, 3, 16, (i, j) => i.isEven ? const Color(0xFFA9774A) : const Color(0xFF9C6B40));
    _gutterSeg = Mesh.box(.34, .06, 2, const Color(0xFF3B3552));
    _deckMesh = Mesh.grid(_laneW, 2, 4, 3, (i, j) => const Color(0xFFEDC48E));
    _backWall = Mesh.grid(14, 3.2, 8, 3, (i, j) => j == 2 ? const Color(0xFF27164A) : const Color(0xFF120A26));
    _hood = Mesh.box(3.0, .9, .3, const Color(0xFF2A1A55),
        colors: const [Color(0xFF3B2A70), Color(0xFF3B2A70), Color(0xFF2E1D5E), Color(0xFF2E1D5E), Color(0xFF221548), Color(0xFF221548)]);
    _sweepBar = Mesh.box(2.3, .12, .14, const Color(0xFFB8C0D8));
    _divider = Mesh.box(.18, .22, 2, const Color(0xFF2B2140));
    _rack();
  }

  void _rack() {
    _pins.clear();
    for (var r = 0; r < 4; r++) {
      for (var i = 0; i <= r; i++) {
        _pins.add(_Pin((i - r / 2) * .6, _headZ + r * .52));
      }
    }
  }

  // ------------------------------------------------------------ gameplay ---

  bool get _canThrow => _st == _St.aim && !host.finished;

  void _throw(Offset s, Offset e, double dt, double bulge) {
    final dy = s.dy - e.dy;
    final dx = e.dx - s.dx;
    final pxs = (e - s).distance / max(dt, .05);
    _bvz = (8.5 + pxs / 260).clamp(9.0, 15.0) * (.95 + .05 * host.speed);
    _pathX0 = _aimX;
    _pathA = (atan2(dx, max(dy, 1)) * .3).clamp(-.13, .13);
    _pathB = (bulge * 2.2).clamp(-.75, .75);
    _bz = 0;
    _bx = _pathX0;
    _bvx = 0;
    _free = false;
    _gutter = false;
    _ballGone = false;
    _firstContact = false;
    _st = _St.roll;
    _stT = 0;
    host.sfx(Sfx.whoosh, volume: .8);
    host.sfx(Sfx.thud, volume: .6, rate: .7);
    host.punch(.02);
  }

  double _pathXAt(double z) {
    const l = _headZ;
    final zz = z.clamp(0.0, l);
    // arc that follows the swipe bow, then hooks back the other way
    return _pathX0 + _pathA * zz + 4 * _pathB * zz * (l - zz) / (l * l) - _pathB * .6 * (zz / l) * (zz / l);
  }

  int get _downCount => _pins.where((p) => p.knocked).length;

  @override
  void update(double dt) {
    _t += dt;
    _stT += dt;
    _hitSoundCd -= dt;
    _bannerT = max(0, _bannerT - dt);

    // ball
    if (_st == _St.roll || _st == _St.settle) {
      if (!_ballGone) {
        _bz += _bvz * dt;
        if (!_free && !_gutter) {
          final nx = _pathXAt(_bz);
          _bvx = (nx - _bx) / max(dt, 1e-4);
          _bx = nx;
        } else {
          _bx += _bvx * dt;
        }
        _roll += _bvz * dt / _ballR;
        if (!_gutter && _bx.abs() > _half - _ballR * .35 && _bz < _headZ - .3) {
          _gutter = true;
          host.sfx(Sfx.thud, volume: .8, rate: .6);
          host.shake(3);
          _popBanner(host.tr('gutter', 'GUTTER…'), Pal.gray);
        }
        if (_gutter) {
          final gx = _bx.sign * (_half + .17);
          _bx = M.approach(_bx, gx, 18, dt);
          _bvx = 0;
          _by = M.approach(_by, _ballR - .12, 14, dt);
        }
        if (!_gutter) _ballPins();
        if (_bz > _pitZ + .6) {
          _ballGone = true;
          if (_st == _St.roll) {
            _st = _St.settle;
            _stT = 0;
          }
        }
      }
    }

    _updatePins(dt);

    if (_st == _St.settle) {
      final moving = _pins.any((p) => !p.pit && (p.vx.abs() + p.vz.abs() > .25 || (p.falling && p.tilt < 1.45)));
      if ((_stT > .7 && !moving) || _stT > 1.5) _resolveRoll();
    } else if (_st == _St.sweep) {
      _sweepY = M.approach(_sweepY, _stT < .45 ? .35 : 3, 10, dt);
      if (_stT > .9) _nextRoll();
    }

    // camera follow
    final targetZ = _st == _St.aim ? 0.0 : min(max(_bz - 3.5, 0.0), 6.2);
    final follow = _st == _St.aim ? 5.0 : 2.6;
    _camZ = M.approach(_camZ, _ballGone || _st == _St.sweep || _st == _St.done ? 6.2 : targetZ, follow, dt);
    _camY = M.approach(_camY, _st == _St.aim ? 0 : -.7, 2, dt);
    if (_st == _St.aim) {
      _aimX = M.approach(_aimX, _aimX + _keyAim, 1, dt).clamp(-_half + _ballR, _half - _ballR);
      _bx = _aimX;
      _bz = 0;
      _by = _ballR;
      _gutter = false;
    }
  }

  void _ballPins() {
    for (final p in _pins) {
      if (p.pit || p.y > .9) continue;
      final (cx, cz) = p.center;
      final dx = cx - _bx, dz = cz - _bz;
      final rr = _ballR + (p.falling ? .17 : _pinR);
      final d2 = dx * dx + dz * dz;
      if (d2 >= rr * rr || d2 < 1e-9) continue;
      final d = sqrt(d2);
      final nx = dx / d, nz = dz / d;
      final vrel = (_bvx - p.vx) * nx + (_bvz - p.vz) * nz;
      if (vrel <= 0) continue;
      const mb = 4.0, mp = 1.0;
      final j = (1.6) * vrel / (1 / mb + 1 / mp);
      if (!_free) _free = true;
      _bvx -= j / mb * nx;
      _bvz = max(_bvz - j / mb * nz, 4);
      // pins fly with a little random scatter
      final sc = rand(-.45, .45);
      final vx = j / mp * nx, vz = j / mp * nz;
      p.vx += vx * cos(sc) - vz * sin(sc);
      p.vz += vx * sin(sc) + vz * cos(sc);
      _knock(p, vrel);
      p.vy = max(p.vy, rand(.8, 2.4) * min(vrel / 10, 1.2));
      // separate
      final push = rr - d;
      p.x += nx * push;
      p.z += nz * push;
      if (!_firstContact) {
        _firstContact = true;
        host.sfx(Sfx.crash, volume: 1);
        host.sfx(Sfx.hitHeavy, volume: .8);
        host.shake(7);
        host.hitStop(.05);
        final sp = scene.cam.project(V3(cx, .5, cz));
        if (sp != null) host.fx.burst(sp, Pal.white, count: 14, speed: 260, size: 5, colors: const [Pal.white, Pal.yellow, Pal.pink]);
      }
    }
  }

  void _knock(_Pin p, double speed) {
    if (p.falling) return;
    p.falling = true;
    final sp = sqrt(p.vx * p.vx + p.vz * p.vz);
    p.dir = sp > .01 ? atan2(p.vx, p.vz) : rand(-pi, pi);
    p.tiltV = 4 + speed * .6;
    p.spinV = rand(-9, 9) * min(speed / 8, 1);
  }

  void _updatePins(double dt) {
    for (final p in _pins) {
      if (p.pit) {
        p.y -= 3 * dt;
        p.z += p.vz.abs() * .3 * dt + .4 * dt;
        continue;
      }
      p.x += p.vx * dt;
      p.z += p.vz * dt;
      if (p.y > 0 || p.vy != 0) {
        p.vy -= 14 * dt;
        p.y += p.vy * dt;
        if (p.y <= 0) {
          p.y = 0;
          p.vy = p.vy.abs() > 1.2 ? -p.vy * .3 : 0;
          if (_hitSoundCd <= 0 && p.falling) {
            _hitSoundCd = .06;
            host.sfx(Sfx.clang, volume: .25, rate: rand(1.4, 1.9));
          }
        }
      }
      final grounded = p.y <= .01;
      final fr = grounded ? (p.falling ? 2.6 : 9.0) : .3;
      final k = math.exp(-fr * dt);
      p.vx *= k;
      p.vz *= k;
      if (p.falling) {
        p.spin += p.spinV * dt;
        p.spinV *= math.exp(-2 * dt);
        if (p.tilt < pi / 2) {
          p.tiltV += 16 * dt;
          p.tilt += p.tiltV * dt;
          if (p.tilt >= pi / 2) {
            p.tilt = pi / 2;
            p.tiltV = 0;
          }
        }
      }
      // gutter / pit
      if (p.z > _pitZ) {
        p.pit = true;
      } else if (p.x.abs() > _half + .05) {
        if (!p.falling) _knock(p, 3);
        p.x = p.x.sign * min(p.x.abs(), _half + .25);
        p.vx *= .2;
      }
    }
    // pin-pin collisions
    for (var i = 0; i < _pins.length; i++) {
      final a = _pins[i];
      if (a.pit) continue;
      for (var j = i + 1; j < _pins.length; j++) {
        final b = _pins[j];
        if (b.pit) continue;
        if ((a.y - b.y).abs() > .7) continue;
        final (ax, az) = a.center;
        final (bx, bz) = b.center;
        final dx = bx - ax, dz = bz - az;
        final rr = (a.falling ? .17 : _pinR) + (b.falling ? .17 : _pinR);
        final d2 = dx * dx + dz * dz;
        if (d2 >= rr * rr || d2 < 1e-9) continue;
        final d = sqrt(d2);
        final nx = dx / d, nz = dz / d;
        final vrel = (a.vx - b.vx) * nx + (a.vz - b.vz) * nz;
        final push = (rr - d) / 2;
        a.x -= nx * push;
        a.z -= nz * push;
        b.x += nx * push;
        b.z += nz * push;
        if (vrel <= 0) continue;
        final jm = (1.5) * vrel / 2;
        a.vx -= jm * nx;
        a.vz -= jm * nz;
        // scatter the struck pin a bit: real pins deflect wildly
        final sc = rand(-.5, .5);
        final vx = jm * nx, vz = jm * nz;
        b.vx += vx * cos(sc) - vz * sin(sc);
        b.vz += vx * sin(sc) + vz * cos(sc);
        if (vrel > .55) {
          if (!b.falling) _knock(b, vrel);
          if (!a.falling && vrel > 1.4) _knock(a, vrel * .5);
          if (vrel > 3) b.vy = max(b.vy, rand(.3, 1.4));
          if (_hitSoundCd <= 0) {
            _hitSoundCd = .035;
            host.sfx(Sfx.hit, volume: .45, rate: rand(1.2, 1.7));
          }
        }
      }
    }
  }

  void _popBanner(String s, Color col) {
    _banner = s;
    _bannerCol = col;
    _bannerT = 1.1;
  }

  void _resolveRoll() {
    final down = _downCount;
    final n = down - _knockedBefore;
    _knockedBefore = down;
    _marks[_frame].add(n);
    _total += n;
    host.score = _total;
    final center = scene.cam.project(const V3(0, .6, _headZ + .6)) ?? const Offset(180, 260);
    if (down == 10 && _roll2 == 0) {
      _strikes++;
      _popBanner(host.tr('strike', 'STRIKE!'), Pal.yellow);
      host.sfx(Sfx.fanfare, volume: .8);
      host.sfx(Sfx.cheer, volume: .8);
      host.shake(12, .5);
      host.flash(const Color(0xFFFFFFFF), .2);
      host.punch(.06);
      host.fx.confetti(count: 90);
      host.fx.coins(center, count: 22);
      host.fx.ring(center, Pal.yellow, size: 200, life: .6);
    } else if (down == 10) {
      _spares++;
      _popBanner(host.tr('spare', 'SPARE!'), Pal.teal);
      host.sfx(Sfx.perfect, volume: .9);
      host.sfx(Sfx.cheer, volume: .6);
      host.shake(8);
      host.fx.confetti(count: 50);
      host.fx.ring(center, Pal.teal, size: 160);
    } else if (n == 0) {
      if (!_gutter) _popBanner(host.tr('miss', 'MISS'), Pal.gray);
      host.sfx(Sfx.aww, volume: .8);
    } else {
      _popBanner('$n', n >= 7 ? Pal.lime : Pal.white);
      host.sfx(n >= 7 ? Sfx.correct : Sfx.pop, volume: .8);
      host.fx.sparkle(center, count: 10, radius: 50);
    }
    if (n > 0) host.fx.pop('+$n', center + const Offset(0, -40), color: Pal.yellow, size: 30);
    if (_total >= _target) {
      _st = _St.done;
      _stT = 0;
      host.win(stars: _strikes > 0 ? 3 : (_spares > 0 ? 2 : (_total >= 17 ? 2 : 1)));
      return;
    }
    final frameOver = down == 10 || _roll2 == 1;
    if (frameOver && _frame == 1) {
      _st = _St.done;
      _stT = 0;
      host.lose();
      return;
    }
    _st = _St.sweep;
    _stT = 0;
    _sweepY = 3;
    host.sfx(Sfx.swipe, volume: .6, rate: .8);
  }

  void _nextRoll() {
    final down = _downCount;
    if (down == 10 || _roll2 == 1) {
      _frame++;
      _roll2 = 0;
      _knockedBefore = 0;
      _rack();
    } else {
      _roll2 = 1;
      _pins.removeWhere((p) => p.knocked);
      for (final p in _pins) {
        p
          ..vx = 0
          ..vz = 0
          ..x = p.hx
          ..z = p.hz;
      }
      _knockedBefore = 0;
      // standing pins were kept, knocked ones removed: count relative to 10
      _knockedBefore = 10 - _pins.length;
      _pins.insertAll(0, [for (var i = 0; i < _knockedBefore; i++) _Pin(0, 0)..pit = true..y = -9]);
    }
    _st = _St.aim;
    _stT = 0;
    _camZ = 0;
    _bz = 0;
    _ballGone = false;
    _gutter = false;
    _by = _ballR;
    _aimX = 0;
    host.sfx(Sfx.ding, volume: .5);
  }

  @override
  void onTimeUp() {
    final total = _total + (_st == _St.roll || _st == _St.settle ? _downCount - _knockedBefore : 0);
    if (total >= _target) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // --------------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    if (!_canThrow) return;
    _dragging = true;
    _drag
      ..clear()
      ..add(p);
    _dragStartT = _t;
    _aimX = _screenToLaneX(p.dx);
  }

  double _screenToLaneX(double sx) {
    final s = scene.cam.scaleAt(V3(0, _ballR, 0));
    return ((sx - 180) / max(s, 1)).clamp(-_half + _ballR, _half - _ballR);
  }

  @override
  void onMove(Offset p) {
    if (!_dragging || !_canThrow) return;
    _drag.add(p);
    if (_drag.length > 60) _drag.removeAt(1);
    // before flicking up, sliding sideways re-positions the ball
    if ((_drag.first.dy - p.dy) < 25) {
      _aimX = _screenToLaneX(p.dx);
    }
  }

  @override
  void onUp(Offset p) {
    if (!_dragging) return;
    _dragging = false;
    if (!_canThrow) return;
    _drag.add(p);
    // find where the upward flick started (lowest point)
    var si = 0;
    for (var i = 0; i < _drag.length; i++) {
      if (_drag[i].dy >= _drag[si].dy) si = i;
    }
    final s = _drag[si];
    final e = _drag.last;
    if (s.dy - e.dy < 45) return; // not a flick; ball was just repositioned
    _aimX = _screenToLaneX(s.dx);
    // bulge: signed max perpendicular deviation from the straight line
    final dir = (e - s) / max((e - s).distance, 1);
    final nrm = Offset(-dir.dy, dir.dx);
    var bulge = 0.0;
    for (var i = si; i < _drag.length; i++) {
      final dev = (_drag[i] - s).dx * nrm.dx + (_drag[i] - s).dy * nrm.dy;
      if (dev.abs() > bulge.abs()) bulge = dev;
    }
    // nrm points left of an upward swipe; positive bulge = bows to the left
    final b = -bulge / max((e - s).distance, 1);
    _throw(s, e, (_t - _dragStartT) * (_drag.length - si) / max(_drag.length, 1), b.abs() < .06 ? 0 : b);
  }

  @override
  void onKey(String key, bool down) {
    if (key == 'left') _keyAim = down ? -2 : 0;
    if (key == 'right') _keyAim = down ? 2 : 0;
    if (down && key == 'action' && _canThrow) {
      _pathX0 = _aimX;
      _throw(const Offset(180, 560), const Offset(180, 300), .2, 0);
    }
  }

  // -------------------------------------------------------------- render ---

  void _setCam(Scene3 s) {
    s.cam
      ..center = const Offset(180, 330)
      ..focal = 520
      ..pos = V3(0, 2.4 + _camY, -3.5 + _camZ)
      ..lookAt(V3(0, 0, 7 + _camZ * .7));
  }

  Offset? _pr(V3 p) => scene.cam.project(p);

  @override
  void render(Canvas c) {
    _setCam(scene);
    _setCam(floor);
    _renderBackdrop(c);

    // ----- pass A: floor
    floor.clear();
    floor.add(_laneMesh, pos: const V3(0, 0, 6));
    for (final sx in [-1.0, 1.0]) {
      floor.add(_sideLane, pos: V3(sx * (_half + .36 + .09 + 1.2), 0, 6));
      for (var z = -1.0; z < _pitZ; z += 2) {
        floor.add(_gutterSeg, pos: V3(sx * (_half + .17), -.1, z + 1));
      }
    }
    floor.add(_deckMesh, pos: const V3(0, .001, _headZ + .9));
    floor.render(c);
    _renderDecals(c);

    // ----- pass B: objects
    scene.clear();
    scene.add(_backWall, pos: const V3(0, -.4, _pitZ + 1.4), rotX: -pi / 2);
    for (final sx in [-1.0, 1.0]) {
      for (var z = -1.0; z < _pitZ; z += 2) {
        scene.add(_divider, pos: V3(sx * (_half + .36 + .09), .11, z + 1));
      }
    }
    scene.add(_hood, pos: const V3(0, 1.75, _headZ - .2));
    if (_st == _St.sweep) scene.add(_sweepBar, pos: V3(0, _sweepY, _headZ + .1));
    for (final p in _pins) {
      if (p.y < -1.5) continue;
      scene.add(_pinMesh, pos: V3(p.x, p.y, p.z), rotX: p.tilt, rotY: p.dir + p.spin, flash: 0);
    }
    if (!_ballGone || _st == _St.aim) {
      final bp = V3(_bx, _by, _bz);
      scene.add(_ballMesh, pos: bp, rotX: _roll, rotY: _st == _St.aim ? _t * .6 : 0);
      final toCam = (scene.cam.pos - bp).normalized;
      scene.addSprite(bp + toCam * (_ballR * 1.02), (c, s, k) {
        c.drawOval(Rect.fromCenter(center: s + Offset(-_ballR * .35 * k, -_ballR * .4 * k), width: _ballR * .55 * k, height: _ballR * .35 * k),
            Paint()..color = const Color(0xAAFFFFFF));
        c.drawCircle(s + Offset(-_ballR * .45 * k, -_ballR * .45 * k), _ballR * .1 * k, Paint()..color = const Color(0xFFFFFFFF));
      });
    }
    scene.render(c);

    // neon sign on the hood
    final hs = _pr(const V3(0, 1.75, _headZ - .36));
    if (hs != null) {
      final k = scene.cam.scaleAt(const V3(0, 1.75, _headZ - .36));
      final flick = .8 + .2 * sin(_t * 23) * sin(_t * 7);
      D.text(c, '151', hs, size: max(8, .5 * k), color: Color.fromRGBO(255, 95, 200, flick), stroke: const Color(0x66FF5FC8), strokeWidth: .12 * k);
    }
    _renderAim(c);
    _renderHud(c);
  }

  void _renderBackdrop(Canvas c) {
    D.gradientBg(c, const [Color(0xFF0B0620), Color(0xFF2A0F4F), Color(0xFF1A0F33)]);
    // ceiling neon strips converging in perspective
    for (var i = 0; i < 9; i++) {
      final z = i * 2.0 + (_camZ % 2 == 0 ? 0 : 0);
      final a = _pr(V3(-3.6, 3.4, z)), b = _pr(V3(3.6, 3.4, z));
      if (a == null || b == null) continue;
      final col = i.isEven ? const Color(0xFFFF4FD8) : const Color(0xFF3FE0FF);
      final w = min(3.0, scene.cam.scaleAt(V3(0, 3.4, z)) * .05);
      c.drawLine(a, b, D.stroke(col.withValues(alpha: .2), w * 4));
      c.drawLine(a, b, D.stroke(col, max(1, w)));
    }
    // twinkling "cosmic" dots on the back wall
    for (var i = 0; i < 26; i++) {
      final x = (i * 53.7) % 360;
      final y = 60 + (i * 31.3) % 150;
      final tw = .3 + .7 * M.wave(_t + i * .37, .7);
      c.drawCircle(Offset(x, y), 1.2 + (i % 3), Paint()..color = D.hsv(280 + i * 9.0, .6, 1, tw * .8));
    }
  }

  void _renderDecals(Canvas c) {
    // spotlight on the pin deck
    final deck = _pr(const V3(0, 0, _headZ + .8));
    if (deck != null) {
      final k = scene.cam.scaleAt(const V3(0, 0, _headZ + .8));
      final r = Rect.fromCenter(center: deck, width: 3.4 * k, height: 1.6 * k);
      c.drawOval(r, Paint()..shader = const RadialGradient(colors: [Color(0x88FFF3D6), Color(0x00FFF3D6)]).createShader(r));
    }
    // lane sheen
    final a = _pr(V3(-_half, 0, 0)), b = _pr(V3(_half, 0, 0));
    final f = _pr(V3(0, 0, _headZ));
    if (a != null && b != null && f != null) {
      final path = Path()
        ..moveTo(a.dx + (b.dx - a.dx) * .35, a.dy)
        ..lineTo(a.dx + (b.dx - a.dx) * .65, a.dy)
        ..lineTo(f.dx + 3, f.dy)
        ..lineTo(f.dx - 3, f.dy)
        ..close();
      c.drawPath(path, Paint()..color = const Color(0x22FFFFFF));
    }
    // arrows & dots
    for (var i = -2; i <= 2; i++) {
      final x = i * .35;
      final z = 4.6 + i.abs() * .35;
      final t1 = _pr(V3(x, 0, z + .25)), l = _pr(V3(x - .07, 0, z)), r = _pr(V3(x + .07, 0, z));
      if (t1 != null && l != null && r != null) {
        c.drawPath(Path()..addPolygon([t1, l, r], true), Paint()..color = const Color(0xFF6A3A1C));
      }
      final d = _pr(V3(x, 0, 1.6));
      if (d != null) c.drawCircle(d, max(1.5, scene.cam.scaleAt(V3(x, 0, 1.6)) * .03), Paint()..color = const Color(0xFF6A3A1C));
    }
    // foul line
    final f1 = _pr(V3(-_half, 0, -.35)), f2 = _pr(V3(_half, 0, -.35));
    if (f1 != null && f2 != null) c.drawLine(f1, f2, D.stroke(const Color(0xFFE8263F), 3));
    // shadows
    for (final p in _pins) {
      if (p.pit) continue;
      final (cx, cz) = p.center;
      final s = _pr(V3(cx, 0, cz));
      if (s == null) continue;
      final k = scene.cam.scaleAt(V3(cx, 0, cz));
      D.shadow(c, s, (p.falling ? .5 : .34) * k, .18 * k, .28);
    }
    if (!_ballGone || _st == _St.aim) {
      final s = _pr(V3(_bx, _by - _ballR, _bz));
      if (s != null) {
        final k = scene.cam.scaleAt(V3(_bx, 0, _bz));
        D.shadow(c, s, _ballR * 2.2 * k, _ballR * .8 * k, .35);
      }
    }
  }

  void _renderAim(Canvas c) {
    if (_st != _St.aim || host.finished) return;
    // predicted path while swiping
    if (_dragging && _drag.length > 2) {
      var si = 0;
      for (var i = 0; i < _drag.length; i++) {
        if (_drag[i].dy >= _drag[si].dy) si = i;
      }
      final s = _drag[si], e = _drag.last;
      if (s.dy - e.dy > 20) {
        final dir = (e - s) / max((e - s).distance, 1);
        final nrm = Offset(-dir.dy, dir.dx);
        var bulge = 0.0;
        for (var i = si; i < _drag.length; i++) {
          final dev = (_drag[i] - s).dx * nrm.dx + (_drag[i] - s).dy * nrm.dy;
          if (dev.abs() > bulge.abs()) bulge = dev;
        }
        final b = -bulge / max((e - s).distance, 1);
        final a0 = _pathA, b0 = _pathB, x0 = _pathX0;
        _pathX0 = _aimX;
        _pathA = (atan2(e.dx - s.dx, max(s.dy - e.dy, 1)) * .3).clamp(-.13, .13);
        _pathB = ((b.abs() < .06 ? 0 : b) * 2.2).clamp(-.75, .75);
        for (var z = .6; z < _headZ; z += .55) {
          final pp = _pr(V3(_pathXAt(z), .02, z));
          if (pp == null) continue;
          final k = scene.cam.scaleAt(V3(0, 0, z));
          c.drawCircle(pp, max(1.5, k * .05), Paint()..color = Color.fromRGBO(255, 240, 120, .9 - z / 16));
        }
        _pathA = a0;
        _pathB = b0;
        _pathX0 = x0;
      }
    } else if (_stT > .3) {
      // idle guide: pulsing arrows up the lane
      for (var i = 0; i < 4; i++) {
        final z = 1.5 + i * 1.6 + (_t * 2.5 % 1.6);
        final pp = _pr(V3(_aimX, .02, z));
        if (pp == null) continue;
        final k = scene.cam.scaleAt(V3(0, 0, z));
        D.arrow(c, pp, const Offset(0, -1), k * .5, Color.fromRGBO(255, 230, 90, .7 - i * .15), width: k * .12);
      }
    }
    if (_frame == 0 && _roll2 == 0 && host.time < 2.6 && !_dragging) {
      final y = 560 - ((_t * 1.2) % 1) * 190;
      D.hand(c, Offset(180 + sin(_t * 3) * 10, y), 0);
    }
  }

  void _renderHud(Canvas c) {
    // score sheet
    const top = 46.0;
    for (var f = 0; f < 2; f++) {
      final r = Rect.fromLTWH(14 + f * 92.0, top, 86, 52);
      D.rrect(c, r, 10, f == _frame && !host.finished ? const Color(0xEE2B1B5C) : const Color(0xCC1B1238),
          border: f == _frame ? const Color(0xFFFF4FD8) : const Color(0xFF55448A), borderWidth: 2.5);
      D.text(c, '${f + 1}', r.topLeft + const Offset(12, 14), size: 14, color: const Color(0xFFB9A8FF));
      final m = _marks[f];
      for (var k = 0; k < 2; k++) {
        final box = Rect.fromLTWH(r.left + 30 + k * 27.0, r.top + 5, 24, 22);
        D.rrect(c, box, 5, const Color(0x66000000));
        String s = '';
        Color col = Pal.white;
        if (k < m.length) {
          if (k == 0 && m[0] == 10) {
            s = 'X';
            col = Pal.yellow;
          } else if (k == 1 && m[0] + m[1] == 10) {
            s = '/';
            col = Pal.teal;
          } else {
            s = m[k] == 0 ? '-' : '${m[k]}';
          }
        }
        D.text(c, s, box.center, size: 16, color: col);
      }
      final sum = m.fold(0, (a, b) => a + b);
      if (m.isNotEmpty) D.text(c, '$sum', Offset(r.center.dx + 10, r.bottom - 12), size: 16, color: Pal.white);
    }
    // total vs target
    final tr = Rect.fromLTWH(206, top, 140, 52);
    D.rrect(c, tr, 10, const Color(0xCC1B1238), border: const Color(0xFF3FE0FF), borderWidth: 2.5);
    _miniPin(c, Offset(tr.left + 20, tr.center.dy + 2), 1);
    final live = _total + ((_st == _St.roll || _st == _St.settle) ? _downCount - _knockedBefore : 0);
    D.text(c, '$live', Offset(tr.left + 62, tr.center.dy - 2), size: 30,
        color: live >= _target ? Pal.lime : Pal.white, stroke: Pal.ink, strokeWidth: 5);
    D.text(c, '/$_target', Offset(tr.left + 108, tr.center.dy + 4), size: 18, color: const Color(0xFFB9A8FF));

    // banner
    if (_bannerT > 0) {
      final t = 1.1 - _bannerT;
      final s = t < .25 ? M.easeOutBack(t / .25) : 1.0;
      final alpha = _bannerT < .25 ? _bannerT / .25 : 1.0;
      c.save();
      c.translate(180, 230);
      if (_bannerCol == Pal.yellow || _bannerCol == Pal.teal) {
        D.rays(c, Offset.zero, 170 * s, _bannerCol.withValues(alpha: .35 * alpha), t: _t);
      }
      c.restore();
      D.title(c, _banner, const Offset(180, 230), size: _banner.length <= 2 ? 72 : 52, scale: s * (1 + .04 * sin(_t * 20)),
          color: _bannerCol, rotate: -.06);
    }
  }

  void _miniPin(Canvas c, Offset o, double k) {
    final p = Path()
      ..moveTo(o.dx, o.dy - 16 * k)
      ..cubicTo(o.dx + 7 * k, o.dy - 16 * k, o.dx + 5 * k, o.dy - 7 * k, o.dx + 3 * k, o.dy - 5 * k)
      ..cubicTo(o.dx + 11 * k, o.dy + 2 * k, o.dx + 7 * k, o.dy + 14 * k, o.dx + 4 * k, o.dy + 16 * k)
      ..lineTo(o.dx - 4 * k, o.dy + 16 * k)
      ..cubicTo(o.dx - 7 * k, o.dy + 14 * k, o.dx - 11 * k, o.dy + 2 * k, o.dx - 3 * k, o.dy - 5 * k)
      ..cubicTo(o.dx - 5 * k, o.dy - 7 * k, o.dx - 7 * k, o.dy - 16 * k, o.dx, o.dy - 16 * k)
      ..close();
    c.drawPath(p, D.fill(Pal.white));
    c.drawRect(Rect.fromLTWH(o.dx - 3.5 * k, o.dy - 6 * k, 7 * k, 2.5 * k), D.fill(Pal.red));
    c.drawPath(p, D.stroke(Pal.ink, 1.5));
  }
}

enum _St { aim, roll, settle, sweep, done }

class _Pin {
  _Pin(this.x, this.z)
      : hx = x,
        hz = z;
  double x, z, y = 0;
  final double hx, hz;
  double vx = 0, vz = 0, vy = 0;
  bool falling = false;
  bool pit = false;
  double tilt = 0, tiltV = 0, dir = 0, spin = 0, spinV = 0;

  bool get knocked => falling || pit;

  /// Collision center: a toppled pin lies along its fall direction.
  (double, double) get center {
    if (!falling) return (x, z);
    final o = sin(tilt) * .36;
    return (x + sin(dir + spin) * o, z + cos(dir + spin) * o);
  }
}
