import '../engine/engine.dart';

/// No.107 Wrecking Ball — drag the crane's wrecking ball back, let go, and
/// smash the voxel "boss block". Knock 80% of the cubes off the platform.
class G107 extends MiniGame {
  static const _nx = 4, _nz = 3, _ny = 8;
  static const _cs = .9; // cube size
  static const _platX = 2.15, _platZ = 1.75;
  static const _groundY = -8.0;
  static const _need = .8;
  static const _ballR = 1.35;
  static const _pivot = V3(-3.3, 12.5, 0);

  final scene = Scene3();
  late final Mesh _ballMesh, _platform, _pillar, _ground, _crane;
  final _cubes = <_Cube>[];
  late List<_Cube?> _grid;
  final _meshCache = <int, Mesh>{};

  double _phi = -1.0, _omega = 0, _len = 9.2;
  bool _holding = false, _primed = true;
  double _phi0 = 0, _len0 = 0;
  Offset _down = Offset.zero;
  double _t = 0;
  int _off = 0;
  double _hitSfxCd = 0;
  bool _won = false;
  double _celebrate = 0;
  double _pctPop = 0;
  bool _touched = false;

  int _gi(int i, int j, int k) => (k * _nz + j) * _nx + i;
  V3 _cellPos(int i, int j, int k) => V3((i - (_nx - 1) / 2) * _cs, _cs / 2 + k * _cs, (j - (_nz - 1) / 2) * _cs);

  @override
  void init() {
    scene.ambient = .55;
    scene.diffuse = .6;
    scene.light = const V3(.45, 1, -.6).normalized;
    _ballMesh = Mesh.sphere(_ballR, const Color(0xFF3A3A4A), lat: 6, lon: 10, stripe: const Color(0xFF5A5A70));
    _platform = Mesh.box(_platX * 2, .6, _platZ * 2, const Color(0xFF8C8FA8), colors: const [
      Color(0xFFB8BCD6), Color(0xFF5A5C70), Color(0xFF8C8FA8), Color(0xFF8C8FA8), Color(0xFF7A7D96), Color(0xFF7A7D96)
    ]);
    _pillar = Mesh.cylinder(1.3, 8, const Color(0xFF6A6D86), seg: 8);
    _ground = Mesh.grid(60, 60, 10, 10, (i, j) => (i + j).isEven ? const Color(0xFF5A3A3A) : const Color(0xFF643F3E));
    const yel = Color(0xFFFFC53D), dk = Color(0xFF3A3040);
    _crane = Mesh.merge([
      (Mesh.box(.8, 22, .8, yel, colors: const [yel, dk, yel, yel, Color(0xFFE0A020), Color(0xFFE0A020)]), const V3(-9, 3, 3)),
      (Mesh.box(7.4, .6, .6, yel), const V3(-5.6, 13.4, 3)),
      (Mesh.box(.5, .5, 3.4, yel), const V3(-3.3, 13.1, 1.5)),
      (Mesh.box(1.8, 1.4, 1.6, const Color(0xFFE8304A)), const V3(-9, 13.3, 3)),
      (Mesh.box(1.6, 1.2, 1.2, dk), const V3(-10.6, 13.2, 3)),
    ]);
    _grid = List.filled(_nx * _ny * _nz, null);
    for (var k = 0; k < _ny; k++) {
      for (var j = 0; j < _nz; j++) {
        for (var i = 0; i < _nx; i++) {
          final col = _colorOf(i, j, k);
          final cube = _Cube(_cellPos(i, j, k), col)
            ..gi = i
            ..gj = j
            ..gk = k;
          _grid[_gi(i, j, k)] = cube;
          _cubes.add(cube);
        }
      }
    }
  }

  Color _colorOf(int i, int j, int k) {
    // voxel boss: angry face on the front (j == 0)
    if (j == 0) {
      if (k == 5 && (i == 1 || i == 2)) return Pal.white;
      if (k == 6 && (i == 0 || i == 3)) return const Color(0xFF2A1A30); // brows
      if (k == 2 && (i == 1 || i == 2)) return const Color(0xFF2A1A30);
      if (k == 3 && (i == 0 || i == 3)) return const Color(0xFF2A1A30);
    }
    if (k == _ny - 1) return (i + j).isEven ? Pal.gold : const Color(0xFFFFE08A); // crown
    return D.hsv(345 - k * 9.0 + (i + j) % 2 * 6, .72, .95 - (i + j + k) % 2 * .06);
  }

  Mesh _meshFor(Color c) => _meshCache.putIfAbsent(c.toARGB32(), () {
        final side = Color.lerp(c, Pal.ink, .12)!;
        return Mesh.box(_cs * .97, _cs * .97, _cs * .97, c, colors: [Color.lerp(c, Pal.white, .15)!, side, c, c, side, side]);
      });

  V3 get _ballPos => _pivot + V3(sin(_phi) * _len, -cos(_phi) * _len, 0);
  V3 get _ballVel => V3(cos(_phi) * _omega * _len, sin(_phi) * _omega * _len, 0);

  // -------------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    _holding = true;
    _touched = true;
    _down = p;
    _phi0 = _phi;
    _len0 = _len;
    _omega = 0;
    host.sfx(Sfx.click, volume: .5);
  }

  @override
  void onMove(Offset p) {
    if (!_holding) return;
    _phi = (_phi0 + (p.dx - _down.dx) * .0085).clamp(-1.45, .25);
    _len = (_len0 + (p.dy - _down.dy) * .02).clamp(7.0, 11.2);
  }

  @override
  void onUp(Offset p) {
    if (!_holding) return;
    _holding = false;
    _primed = false;
    if (_phi < -.35) {
      host.sfx(Sfx.swing, rate: .8);
      host.sfx(Sfx.whoosh, volume: .6, rate: .7);
    }
  }

  @override
  void onKey(String key, bool down) {
    if (key == 'action') {
      if (down) {
        _phi = -1.3;
        _omega = 0;
        _holding = true;
      } else {
        onUp(Offset.zero);
      }
    }
  }

  // ------------------------------------------------------------- update ---

  @override
  void update(double dt) {
    _t += dt;
    _hitSfxCd -= dt;
    _pctPop = M.approach(_pctPop, 0, 6, dt);
    _celebrate = max(0, _celebrate - dt);
    if (!_holding && !_primed) {
      final g = 30.0;
      _omega += (-(g / _len) * sin(_phi) - .12 * _omega) * dt;
      _phi += _omega * dt;
    } else if (_primed) {
      _phi = -1.0 + sin(_t * 2) * .03;
    }
    _ballHits();
    _physics(dt);
  }

  void _ballHits() {
    final bp = _ballPos, bv = _ballVel;
    final speed = bv.length;
    var hits = 0;
    for (final cube in _cubes) {
      if (cube.state == _St.off) continue;
      final d = cube.pos - bp;
      final dist = d.length;
      if (dist >= _ballR + _cs * .5) continue;
      final n = dist < 1e-4 ? const V3(1, 0, 0) : d / dist;
      cube.pos = bp + n * (_ballR + _cs * .5 + .01);
      if (speed < 1.5 && cube.state == _St.rest) continue;
      _activate(cube);
      cube.vel = bv * 1.05 + n * (3.5 + speed * .3) + V3(rand(-1, 1), rand(1, 3), rand(-1.5, 1.5));
      cube.av = V3(rand(-9, 9), rand(-6, 6), rand(-9, 9));
      cube.flash = 1;
      hits++;
    }
    if (hits > 0) {
      _omega *= .95;
      if (_hitSfxCd <= 0) {
        _hitSfxCd = .12;
        host.sfx(hits > 3 ? Sfx.hitHeavy : Sfx.hit, rate: rand(.85, 1.1));
        host.sfx(Sfx.crash, volume: M.clamp01(hits / 6));
        final sp = scene.cam.project(bp);
        if (sp != null) {
          host.fx.burst(sp, const Color(0xFFD8C8B0), count: 6 + hits * 2, speed: 260, size: 7, shape: PartShape.square);
          host.fx.smoke(sp, count: 4, color: const Color(0xAAE0D0C0), size: 22);
        }
        if (hits > 3) {
          host.shake(10, .35);
          host.hitStop(.06);
          host.punch(.05);
          host.fx.pop(host.tr('smash', 'SMASH!'), const Offset(180, 200), color: Pal.orange, size: 38);
        } else {
          host.shake(4);
        }
      }
    }
  }

  void _activate(_Cube c) {
    if (c.state == _St.rest) _grid[_gi(c.gi, c.gj, c.gk)] = null;
    c.state = _St.fly;
  }

  double _floorAt(double x, double z) => (x.abs() < _platX && z.abs() < _platZ) ? 0 : _groundY;

  void _physics(double dt) {
    // unsupported grid cubes start to fall
    for (final c in _cubes) {
      if (c.state != _St.rest || c.gk == 0) continue;
      if (_grid[_gi(c.gi, c.gj, c.gk - 1)] == null) {
        _activate(c);
        c.vel = V3(rand(-1.8, 1.8), 0, rand(-1.8, 1.8));
        c.av = V3(rand(-3, 3), 0, rand(-3, 3));
      }
    }
    for (final c in _cubes) {
      if (c.state == _St.rest) continue;
      c.flash = max(0, c.flash - dt * 4);
      if (c.state == _St.settled || c.state == _St.off && c.resting) {
        // lost support?
        final floor = _floorAt(c.pos.x, c.pos.z);
        final edge = c.state == _St.settled && c.pos.y < .6 &&
            (c.pos.x.abs() > _platX - .12 || c.pos.z.abs() > _platZ - .12);
        if (edge) {
          // teetering on the edge: tip over
          c.state = _St.fly;
          c.vel = V3(c.pos.x.abs() > _platX - .12 ? c.pos.x.sign * 1.5 : 0, 1,
              c.pos.z.abs() > _platZ - .12 ? c.pos.z.sign * 1.5 : 0);
          c.av = V3(rand(-4, 4), 0, rand(-4, 4));
        } else if (c.pos.y - _cs / 2 > floor + .05 && _gridSupport(c) == null) {
          c.state = c.state == _St.off ? _St.off : _St.fly;
          c.resting = false;
        } else {
          continue;
        }
      }
      c.vel = V3(c.vel.x, c.vel.y - 26 * dt, c.vel.z);
      c.pos = c.pos + c.vel * dt;
      c.rx += c.av.x * dt;
      c.ry += c.av.y * dt;
      c.rz += c.av.z * dt;
      // collide with standing grid cubes
      final hitCell = _gridAt(c.pos);
      if (hitCell != null && hitCell != c) {
        final sp = c.vel.length;
        if (sp > 3) {
          _activate(hitCell);
          hitCell.vel = c.vel * .75 + V3(rand(-1.5, 1.5), rand(0, 2), rand(-1.5, 1.5));
          hitCell.av = V3(rand(-6, 6), rand(-4, 4), rand(-6, 6));
          c.vel = c.vel * .4;
        } else {
          c.pos = V3(c.pos.x, hitCell.pos.y + _cs, c.pos.z);
          c.vel = V3(c.vel.x * .5, 0, c.vel.z * .5);
          if (c.vel.length < 1) _settle(c);
        }
      }
      final floor = _floorAt(c.pos.x, c.pos.z);
      if (c.pos.y - _cs / 2 < floor) {
        // platform side wall: falling past the edge
        if (floor == 0 && c.pos.y < -.4) {
          // it is below the top already: push outward instead of up
          final ox = c.pos.x.abs() / _platX, oz = c.pos.z.abs() / _platZ;
          c.pos = ox > oz
              ? V3(c.pos.x.sign * (_platX + .46), c.pos.y, c.pos.z)
              : V3(c.pos.x, c.pos.y, c.pos.z.sign * (_platZ + .46));
        } else {
          c.pos = V3(c.pos.x, floor + _cs / 2, c.pos.z);
          if (c.vel.y < -3) {
            host.sfx(Sfx.thud, volume: M.clamp01(-c.vel.y / 20) * .6, rate: rand(.9, 1.3));
          }
          c.vel = V3(c.vel.x * .7, -c.vel.y * .28, c.vel.z * .7);
          c.av = c.av * .6;
          if (c.vel.length < 1.2) _settle(c);
        }
      }
      if (c.state != _St.off && (c.pos.y < -.6 || c.pos.x.abs() > _platX + .2 || c.pos.z.abs() > _platZ + .2)) {
        c.state = _St.off;
        _off++;
        _pctPop = 1;
        host.addScore(10);
        if (_off % 6 == 0) host.sfx(Sfx.coin, volume: .5, rate: 1 + min(_off, 80) / 80);
        _checkWin();
      }
      if (c.pos.y < _groundY - 2) c.pos = V3(c.pos.x, _groundY + _cs / 2, c.pos.z);
    }
  }

  void _settle(_Cube c) {
    c.vel = V3.zero;
    c.av = V3.zero;
    double q(double a) => (a / (pi / 2)).roundToDouble() * pi / 2;
    c.rx = q(c.rx);
    c.rz = q(c.rz);
    if (c.state == _St.off) {
      c.resting = true;
    } else {
      c.state = _St.settled;
    }
  }

  _Cube? _gridAt(V3 p) {
    final i = (p.x / _cs + (_nx - 1) / 2).round(), j = (p.z / _cs + (_nz - 1) / 2).round();
    final k = ((p.y - _cs / 2) / _cs).round();
    if (i < 0 || j < 0 || k < 0 || i >= _nx || j >= _nz || k >= _ny) return null;
    final c = _grid[_gi(i, j, k)];
    if (c == null) return null;
    return (c.pos - p).length < _cs * .95 ? c : null;
  }

  _Cube? _gridSupport(_Cube c) => _gridAt(c.pos - const V3(0, _cs, 0));

  void _checkWin() {
    if (_won || host.finished) return;
    if (_off >= (_cubes.length * _need).ceil()) {
      _won = true;
      _celebrate = 2;
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.explode, volume: .7);
      host.sfx(Sfx.cheer, volume: .7);
      host.fx.confetti();
      host.flash(Pal.white, .2);
      host.shake(8);
      host.fx.pop(host.tr('ko', 'K.O.!'), const Offset(180, 250), color: Pal.yellow, size: 52, life: 1.4);
      final tm = host.time;
      host.win(stars: tm < 8 ? 3 : (tm < 13 ? 2 : 1));
    }
  }

  @override
  void onTimeUp() {
    host.sfx(Sfx.aww);
    host.lose();
  }

  // ------------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    _sky(c);
    final cam = scene.cam
      ..center = const Offset(180, 330)
      ..focal = 330
      ..pos = V3(3.0 + sin(_t * .4) * .6, 7.0, -17.5)
      ..lookAt(const V3(-3.2, 4.2, 0));
    // pass A: far ground + cubes fallen behind/side of the pedestal
    scene.clear();
    scene.add(_ground, pos: const V3(0, _groundY, 0));
    scene.render(c);
    scene.clear();
    for (final cb in _cubes) {
      if (cb.pos.y < -.7 && cb.pos.z > -_platZ) _addCube(cb);
    }
    scene.add(_pillar, pos: const V3(0, -4.3, 0));
    scene.render(c);
    // pass B: platform
    scene.clear();
    scene.add(_platform, pos: const V3(0, -.3, 0));
    scene.render(c);
    // shadows on the platform
    final bp = _ballPos;
    if (bp.x.abs() < _platX + 1) {
      final sp = cam.project(V3(bp.x.clamp(-_platX, _platX), .01, bp.z));
      final k = cam.scaleAt(V3(bp.x, 0, bp.z));
      if (sp != null) {
        final a = (.35 - bp.y * .03).clamp(.08, .35);
        c.drawOval(Rect.fromCenter(center: sp, width: k * 2.2, height: k * .9), Paint()..color = Color.fromRGBO(30, 10, 30, a));
      }
    }
    // pass C: the rest
    scene.clear();
    scene.add(_crane);
    for (final cb in _cubes) {
      if (!(cb.pos.y < -.7 && cb.pos.z > -_platZ)) _addCube(cb);
    }
    scene.add(_ballMesh, pos: bp, rotZ: _phi, rotY: _t * .3);
    scene.addSprite(bp + const V3(0, 0, -1.25), (cv, s, k) {
      // rope from pivot to ball
      final pv = cam.project(_pivot + const V3(0, .5, 0));
      final top = cam.project(bp + V3(-sin(_phi) * _ballR, cos(_phi) * _ballR, 0));
      if (pv != null && top != null) {
        cv.drawLine(pv, top, D.stroke(const Color(0xFF2A2230), 4));
        for (var i = 1; i < 12; i++) {
          final p = Offset.lerp(pv, top, i / 12)!;
          cv.drawCircle(p, 2.6, D.fill(const Color(0xFF5A5060)));
        }
      }
      cv.drawCircle(s + Offset(-k * .35, -k * .35), k * .25, Paint()..color = const Color(0x44FFFFFF));
    });
    scene.render(c);
    _hud(c);
  }

  void _addCube(_Cube cb) {
    scene.add(_meshFor(cb.color),
        pos: cb.pos, rotX: cb.rx, rotY: cb.ry, rotZ: cb.rz, flash: cb.flash * .7);
  }

  void _sky(Canvas c) {
    D.gradientBg(c, const [Color(0xFF2A0E3A), Color(0xFF8A2A4A), Color(0xFFFF7A4A)]);
    // skyline silhouettes
    final p = Path()..moveTo(0, 640);
    var x = 0.0;
    var i = 0;
    while (x < 380) {
      final h = 380 + (i * 53 % 90).toDouble();
      final w = 24 + (i * 31 % 30).toDouble();
      p
        ..lineTo(x, h)
        ..lineTo(x + w, h);
      x += w;
      i++;
    }
    p
      ..lineTo(380, 640)
      ..close();
    c.drawPath(p, Paint()..color = const Color(0x552A0E3A));
    D.rays(c, const Offset(180, 470), 420, const Color(0x14FFD08A), count: 14, t: _t * .1);
    if (_celebrate > 0) D.rays(c, const Offset(180, 320), 420, Color.fromRGBO(255, 230, 120, .25 * _celebrate), count: 16, t: _t);
  }

  void _hud(Canvas c) {
    final pct = _off / _cubes.length;
    const r = Rect.fromLTWH(50, 58, 200, 22);
    D.rrect(c, r.inflate(6), 17, const Color(0xCC1B1530), border: Pal.white, borderWidth: 2.5);
    D.bar(c, r, pct, pct >= _need ? Pal.lime : Pal.orange, back: const Color(0x55FFFFFF));
    final mx = r.left + r.width * _need;
    c.drawLine(Offset(mx, r.top - 5), Offset(mx, r.bottom + 5), D.stroke(Pal.yellow, 3));
    c.save();
    c.translate(296, 69);
    c.scale(1 + _pctPop * .25);
    D.text(c, '${(pct * 100).round()}%', Offset.zero, size: 28, color: Pal.white, stroke: Pal.ink, strokeWidth: 6);
    c.restore();
    if (!_touched && host.time < 3.5) {
      final bp = scene.cam.project(_ballPos) ?? const Offset(120, 350);
      final ph = (_t * 1.2) % 1;
      D.hand(c, bp + Offset(-ph * 70, 10), _t);
      D.arrow(c, bp + const Offset(-40, 80), const Offset(-1, 0), 60, Pal.yellow, width: 10);
      D.arrow(c, bp + const Offset(40, 70), const Offset(0, 1), 44, Pal.lime, width: 8);
      D.text(c, '${host.tr('drag', 'DRAG')} + ${host.tr('release', 'RELEASE')}', const Offset(180, 600), size: 20,
          color: Pal.white, stroke: Pal.ink, strokeWidth: 5);
    }
  }
}

enum _St { rest, fly, settled, off }

class _Cube {
  _Cube(this.pos, this.color);
  V3 pos;
  final Color color;
  V3 vel = V3.zero;
  V3 av = V3.zero;
  double rx = 0, ry = 0, rz = 0;
  _St state = _St.rest;
  bool resting = false;
  double flash = 0;
  int gi = 0, gj = 0, gk = 0;
}
