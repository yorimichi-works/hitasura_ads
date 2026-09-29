import '../engine/engine.dart';

/// No.004 Stack to the Sky — 3D slab stacking with slicing & perfect combos.
class G004 extends MiniGame {
  static const _target = 12;
  final scene = Scene3();
  final List<_Slab> _stack = [];
  final List<_Chunk> _chunks = [];
  late _Slab _moving;
  double _dir = 1;
  double _camY = 0;
  int _combo = 0;
  double _t = 0;
  double _perfectRing = 0;
  bool _dead = false;

  static Color _col(int i) => D.hsv(200 + i * 13.0, .55, .98);

  @override
  void init() {
    scene.ambient = .55;
    scene.diffuse = .55;
    scene.light = const V3(-.6, 1, -.3).normalized;
    _stack.add(_Slab(0, 0, 3, 3, 0, _col(0))); // base
    _spawn();
  }

  void _spawn() {
    final top = _stack.last;
    final level = _stack.length;
    final alongX = level.isOdd;
    _moving = _Slab(alongX ? -4.2 : top.x, alongX ? top.z : -4.2, top.w, top.d, level, _col(level))..alongX = alongX;
    _dir = 1;
  }

  @override
  void update(double dt) {
    _t += dt;
    if (!host.finished && !_dead) {
      final sp = (3.6 + _stack.length * .18) * host.speed;
      if (_moving.alongX) {
        _moving.x += _dir * sp * dt;
        if (_moving.x.abs() > 4.2) _dir = -_moving.x.sign;
      } else {
        _moving.z += _dir * sp * dt;
        if (_moving.z.abs() > 4.2) _dir = -_moving.z.sign;
      }
    }
    _camY = M.approach(_camY, _stack.length * .5, 5, dt);
    for (final c in _chunks) {
      c.vy -= 22 * dt;
      c.y += c.vy * dt;
      c.x += c.vx * dt;
      c.z += c.vz * dt;
      c.rot += c.spin * dt;
    }
    _chunks.removeWhere((c) => c.y < _camY - 14);
    _perfectRing = M.approach(_perfectRing, 0, 4, dt);
    for (final s in _stack) {
      s.bounce = M.approach(s.bounce, 0, 10, dt);
    }
  }

  void _drop() {
    final top = _stack.last;
    final m = _moving;
    final delta = m.alongX ? m.x - top.x : m.z - top.z;
    final size = m.alongX ? top.w : top.d;
    final overlap = size - delta.abs();
    if (overlap <= 0) {
      // total miss — the slab tumbles
      _chunks.add(_Chunk.fromSlab(m, delta.sign * 2));
      _dead = true;
      host.sfx(Sfx.crash);
      host.shake(8);
      host.lose();
      return;
    }
    final perfect = delta.abs() < .12;
    if (perfect) {
      _combo++;
      m.x = top.x;
      m.z = top.z;
      host.sfx(Sfx.perfect, rate: 1 + _combo * .08);
      host.fx.pop(host.tr('perfect', 'PERFECT!'), const Offset(180, 250), color: Pal.yellow, size: 30);
      if (_combo >= 3) {
        // combo growth: slab regains a little size
        if (m.alongX) {
          m.w = min(3, m.w + .25);
        } else {
          m.d = min(3, m.d + .25);
        }
        host.fx.pop('COMBO x$_combo', const Offset(180, 290), color: Pal.pink, size: 24);
      }
      _perfectRing = 1;
      host.punch(.03);
    } else {
      _combo = 0;
      final cutSize = delta.abs();
      if (m.alongX) {
        final newX = top.x + delta / 2;
        final chunkX = newX + delta.sign * (overlap / 2 + cutSize / 2);
        _chunks.add(_Chunk(chunkX, m.level * _Slab.h, m.z, cutSize, m.d, m.color, delta.sign * 1.5, 0));
        m
          ..w = overlap
          ..x = newX;
      } else {
        final newZ = top.z + delta / 2;
        final chunkZ = newZ + delta.sign * (overlap / 2 + cutSize / 2);
        _chunks.add(_Chunk(m.x, m.level * _Slab.h, chunkZ, m.w, cutSize, m.color, 0, delta.sign * 1.5));
        m
          ..d = overlap
          ..z = newZ;
      }
      host.sfx(Sfx.chop, rate: 1.1);
    }
    host.sfx(Sfx.thud, volume: .6, rate: 1 + _stack.length * .03);
    m.bounce = 1;
    _stack.add(m);
    final p = scene.cam.project(V3(m.x, m.level * _Slab.h, m.z));
    host.addScore(perfect ? 20 : 10, p ?? const Offset(180, 300));
    if (_stack.length - 1 >= _target) {
      host.fx.confetti();
      host.win(stars: _combo >= 2 ? 3 : 2);
    } else {
      _spawn();
    }
  }

  @override
  void onDown(Offset p) => _drop();

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action') _drop();
  }

  @override
  void onTimeUp() {
    if (_stack.length - 1 >= 8) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  @override
  void render(Canvas c) {
    final hue = 200 + _stack.length * 9.0;
    D.gradientBg(c, [D.hsv(hue, .45, 1), D.hsv(hue + 40, .55, .75)]);
    // soft floating shapes in the background
    for (var i = 0; i < 8; i++) {
      final y = (i * 97 + _t * 12) % 700 - 30;
      c.drawCircle(Offset(30 + i * 45.0, 640 - y), 10 + i % 3 * 6, Paint()..color = const Color(0x22FFFFFF));
    }
    scene.clear();
    scene.cam
      ..center = const Offset(180, 330)
      ..focal = 380
      ..pos = V3(7.5, 7.2 + _camY, -7.5)
      ..lookAt(V3(0, _camY - .8, 0));
    // draw only the top ~14 slabs
    final from = max(0, _stack.length - 14);
    for (var i = from; i < _stack.length; i++) {
      final s = _stack[i];
      final sq = 1 + s.bounce * .08;
      scene.add(Mesh.box(s.w, _Slab.h, s.d, s.color),
          pos: V3(s.x, s.level * _Slab.h - (i == 0 ? 3 : 0), s.z), scale3: V3(sq, i == 0 ? 7 : 1, sq));
    }
    if (!_dead && !host.finished) {
      final m = _moving;
      scene.add(Mesh.box(m.w, _Slab.h, m.d, m.color), pos: V3(m.x, m.level * _Slab.h, m.z));
    }
    for (final ch in _chunks) {
      scene.add(Mesh.box(ch.w, _Slab.h, ch.d, ch.color), pos: V3(ch.x, ch.y, ch.z), rotZ: ch.rot * ch.vx.sign, rotX: ch.rot * ch.vz.sign);
    }
    scene.render(c);
    if (_perfectRing > .02) {
      final top = _stack.last;
      final p = scene.cam.project(V3(top.x, top.level * _Slab.h + .3, top.z));
      if (p != null) {
        c.drawCircle(p, 60 + (1 - _perfectRing) * 90,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8 * _perfectRing
              ..color = Color.fromRGBO(255, 255, 255, _perfectRing));
      }
    }
    // height counter
    final n = _stack.length - 1;
    D.text(c, '$n', const Offset(180, 90), size: 64, color: Pal.white, stroke: const Color(0x55000000), strokeWidth: 10);
    D.text(c, '/ $_target', const Offset(180, 135), size: 18, color: const Color(0xCCFFFFFF));
    if (host.time < 2.2 && n == 0) D.hand(c, const Offset(180, 470), _t);
  }
}

class _Slab {
  _Slab(this.x, this.z, this.w, this.d, this.level, this.color);
  static const h = .5;
  double x, z, w, d;
  final int level;
  final Color color;
  bool alongX = true;
  double bounce = 0;
}

class _Chunk {
  _Chunk(this.x, this.y, this.z, this.w, this.d, this.color, this.vx, this.vz);
  factory _Chunk.fromSlab(_Slab s, double vx) => _Chunk(s.x, s.level * _Slab.h, s.z, s.w, s.d, s.color, vx, 0);
  double x, y, z;
  final double w, d;
  final Color color;
  double vx, vz;
  double vy = 0;
  double rot = 0;
  double spin = 2.5;
}
