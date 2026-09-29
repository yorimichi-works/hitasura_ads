import '../engine/engine.dart';

/// No.133 Pipe Connect — rotate pipe tiles to lead water from the tap to the
/// thirsty flower. The level is generated from a guaranteed path.
class G133 extends MiniGame {
  static const _n = 5;
  static const _cs = 60.0;
  static const _x0 = 30.0, _y0 = 176.0;
  // N=1 E=2 S=4 W=8
  static const _dirs = [(-1, 0), (0, 1), (1, 0), (0, -1)];

  final List<_Pipe> _p = [];
  int _c0 = 0, _c1 = 0;
  final Set<int> _path = {};
  Set<int> _wet = {};
  final Map<int, int> _parent = {};
  bool _connected = false;
  double _t = 0;
  double _bloom = 0;
  double _potWater = 0;
  bool _won = false;
  int _taps = 0;

  static int _rotMask(int m, int r) {
    var x = m;
    for (var i = 0; i < (r & 3); i++) {
      x = ((x << 1) | (x >> 3)) & 15;
    }
    return x;
  }

  @override
  void init() {
    List<int>? path;
    for (var tries = 0; tries < 200 && path == null; tries++) {
      _c0 = randInt(_n);
      _c1 = randInt(_n);
      path = _walk();
    }
    path ??= [for (var r = 0; r < _n; r++) r * _n + _c0];
    if (path.last % _n != _c1) _c1 = path.last % _n;
    _path.addAll(path);
    for (var i = 0; i < _n * _n; i++) {
      _p.add(_Pipe(0));
    }
    for (var k = 0; k < path.length; k++) {
      final i = path[k];
      final inDir = k == 0 ? 0 : _dirTo(i, path[k - 1]);
      final outDir = k == path.length - 1 ? 2 : _dirTo(i, path[k + 1]);
      _p[i].base = (1 << inDir) | (1 << outDir);
    }
    for (var i = 0; i < _n * _n; i++) {
      if (_path.contains(i)) continue;
      final r = rng.nextDouble();
      _p[i].base = r < .4 ? 5 : (r < .8 ? 3 : 7);
    }
    for (var i = 0; i < _n * _n; i++) {
      final pp = _p[i];
      pp.rot = randInt(4);
      if (_path.contains(i) && _rotMask(pp.base, pp.rot) == pp.base && chance(.8)) pp.rot = 1 + randInt(3);
      pp.angle = pp.rot * pi / 2;
    }
    _flow();
    if (_connected) {
      // never start solved
      final i = path[path.length ~/ 2];
      _p[i].rot += 1;
      _p[i].angle = _p[i].rot * pi / 2;
      _connected = false;
      _flow();
    }
  }

  int _dirTo(int a, int b) {
    final dr = b ~/ _n - a ~/ _n, dc = b % _n - a % _n;
    for (var d = 0; d < 4; d++) {
      if (_dirs[d].$1 == dr && _dirs[d].$2 == dc) return d;
    }
    return 0;
  }

  List<int>? _walk() {
    final start = _c0;
    final visited = <int>{start};
    final path = <int>[start];
    var budget = 3000;
    final minLen = 8, maxLen = 13;
    bool dfs(int cur) {
      if (--budget < 0) return false;
      if (cur ~/ _n == _n - 1 && cur % _n == _c1 && path.length >= minLen) return true;
      if (path.length >= maxLen) return false;
      final order = [0, 1, 2, 3]..shuffle(rng);
      for (final d in order) {
        final r = cur ~/ _n + _dirs[d].$1, c = cur % _n + _dirs[d].$2;
        if (r < 0 || c < 0 || r >= _n || c >= _n) continue;
        final nx = r * _n + c;
        if (visited.contains(nx)) continue;
        visited.add(nx);
        path.add(nx);
        if (dfs(nx)) return true;
        path.removeLast();
        visited.remove(nx);
      }
      return false;
    }

    return dfs(start) ? path : null;
  }

  int _mask(int i) => _rotMask(_p[i].base, _p[i].rot);

  void _flow() {
    final wet = <int>{};
    _parent.clear();
    final start = _c0;
    if (_mask(start) & 1 != 0) {
      wet.add(start);
      _parent[start] = -1;
      final q = [start];
      while (q.isNotEmpty) {
        final cur = q.removeAt(0);
        final m = _mask(cur);
        for (var d = 0; d < 4; d++) {
          if (m & (1 << d) == 0) continue;
          final r = cur ~/ _n + _dirs[d].$1, c = cur % _n + _dirs[d].$2;
          if (r < 0 || c < 0 || r >= _n || c >= _n) continue;
          final nx = r * _n + c;
          if (wet.contains(nx)) continue;
          if (_mask(nx) & (1 << ((d + 2) % 4)) == 0) continue;
          wet.add(nx);
          _parent[nx] = cur;
          q.add(nx);
        }
      }
    }
    _wet = wet;
    final end = (_n - 1) * _n + _c1;
    _connected = wet.contains(end) && (_mask(end) & 4) != 0;
  }

  // ------------------------------------------------------------ input ---

  @override
  void onDown(Offset p) {
    if (_connected || host.finished) return;
    final c = ((p.dx - _x0) / _cs).floor(), r = ((p.dy - _y0) / _cs).floor();
    if (c < 0 || r < 0 || c >= _n || r >= _n) return;
    final i = r * _n + c;
    final pp = _p[i];
    pp.rot++;
    pp.squash = 1;
    _taps++;
    host.sfx(Sfx.click, rate: 1 + rand(-.05, .1));
    host.sfx(Sfx.clang, volume: .25, rate: 1.6);
    final before = _wet.length;
    _flow();
    if (_wet.length > before) {
      host.sfx(Sfx.bubble, volume: .7, rate: 1 + min(_wet.length, 14) * .05);
      host.fx.sparkle(_center(i), count: 5, radius: 20, color: Pal.sky);
    }
    if (_connected) {
      host.sfx(Sfx.pour);
      host.sfx(Sfx.correct, volume: .7);
      host.fx.pop(host.tr('connect', 'CONNECT!'), const Offset(180, 150), color: Pal.sky, size: 32);
      host.punch(.03);
    }
  }

  Offset _center(int i) => Offset(_x0 + (i % _n + .5) * _cs, _y0 + (i ~/ _n + .5) * _cs);

  @override
  void onTimeUp() {
    if (_connected) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ----------------------------------------------------------- update ---

  @override
  void update(double dt) {
    _t += dt;
    for (var i = 0; i < _n * _n; i++) {
      final pp = _p[i];
      pp.angle = M.approach(pp.angle, pp.rot * pi / 2, 22, dt);
      pp.squash = M.approach(pp.squash, 0, 9, dt);
      if (_wet.contains(i)) {
        final par = _parent[i] ?? -1;
        final ready = par < 0 || _p[par].fill > .85;
        if (ready) pp.fill = min(1, pp.fill + dt * (_connected ? 7 : 9));
      } else {
        pp.fill = max(0, pp.fill - dt * 4);
      }
    }
    final end = (_n - 1) * _n + _c1;
    if (_connected && _p[end].fill >= 1) {
      _potWater = min(1, _potWater + dt * 3);
      if (_potWater >= 1 && !_won) {
        _won = true;
        final pot = Offset(_center(end).dx, 548);
        host.sfx(Sfx.magic);
        host.sfx(Sfx.fanfare, volume: .8);
        host.fx.burst(pot + const Offset(0, -60), Pal.pink, count: 30, shape: PartShape.heart, speed: 260);
        host.fx.confetti(count: 50);
        host.shake(5);
        final left = host.timeLeft;
        host.win(stars: left > 9 ? 3 : (left > 4 ? 2 : 1));
      }
    }
    if (_won) _bloom = min(1, _bloom + dt * 2.2);
  }

  // ----------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    // garden sky
    D.gradientBg(c, const [Color(0xFF8FD8FF), Color(0xFFD8F3FF), Color(0xFFBFE8A0)]);
    D.circle(c, const Offset(310, 70), 30, const Color(0xFFFFE066));
    D.cloud(c, Offset(60 + (_t * 8) % 420 - 60, 70), 40);
    D.cloud(c, Offset(250 - (_t * 5) % 420 + 120, 110), 30);
    // brick wall panel behind the grid
    const panel = Rect.fromLTWH(_x0 - 12, _y0 - 12, _cs * _n + 24, _cs * _n + 24);
    D.rrect(c, panel.shift(const Offset(0, 7)), 18, const Color(0x44000000));
    D.rrect(c, panel, 18, const Color(0xFF7B5A4A), border: Pal.ink, borderWidth: 4);
    // ground
    c.drawRect(const Rect.fromLTWH(0, 560, 360, 80), D.fill(const Color(0xFF6BBF4E)));
    c.drawRect(const Rect.fromLTWH(0, 560, 360, 6), D.fill(const Color(0xFF8ED66B)));
    for (var i = 0; i < 12; i++) {
      final x = i * 31.0 + 8;
      c.drawLine(Offset(x, 575), Offset(x - 4, 566), D.stroke(const Color(0xFF4E9A38), 3));
      c.drawLine(Offset(x + 6, 590 + (i % 3) * 12), Offset(x + 9, 580 + (i % 3) * 12), D.stroke(const Color(0xFF4E9A38), 3));
    }

    // tiles
    for (var i = 0; i < _n * _n; i++) {
      final ctr = _center(i);
      D.rrect(c, Rect.fromCenter(center: ctr, width: _cs - 4, height: _cs - 4), 9,
          ((i ~/ _n) + (i % _n)).isEven ? const Color(0xFFD9CBB8) : const Color(0xFFCBBBA5),
          border: const Color(0xFF6B4E3D), borderWidth: 2);
    }
    for (var i = 0; i < _n * _n; i++) {
      _drawPipe(c, i);
    }
    // faucet above column c0
    final top = Offset(_x0 + (_c0 + .5) * _cs, _y0);
    _faucet(c, top);
    // pot below column c1
    final bot = Offset(_x0 + (_c1 + .5) * _cs, _y0 + _cs * _n);
    _pot(c, bot);

    // hint
    if (host.time < 2.5 && _taps == 0) {
      for (final i in _path) {
        if (!_wet.contains(i)) {
          D.hand(c, _center(i), _t);
          break;
        }
      }
    }
    // path counter
    final pct = (_wet.length / _path.length * 100).clamp(0, 100).round();
    D.rrect(c, const Rect.fromLTWH(134, 42, 92, 34), 12, const Color(0xCC1B1530));
    c.drawPath(
        Path()
          ..moveTo(152, 47)
          ..quadraticBezierTo(162, 61, 152, 70)
          ..quadraticBezierTo(142, 61, 152, 47),
        D.fill(Pal.sky));
    D.text(c, '$pct%', const Offset(192, 59), size: 19, color: Pal.white);
  }

  static final _waterA = Paint()..color = const Color(0xFF2AA8FF);

  void _drawPipe(Canvas c, int i) {
    final pp = _p[i];
    final ctr = _center(i);
    final wet = pp.fill;
    c.save();
    c.translate(ctr.dx, ctr.dy);
    final s = 1 - pp.squash * .12;
    c.scale(s);
    c.rotate(pp.angle);
    const reach = _cs / 2 + 1;
    final ends = <Offset>[];
    for (var d = 0; d < 4; d++) {
      if (pp.base & (1 << d) == 0) continue;
      ends.add(Offset(_dirs[d].$2 * reach, _dirs[d].$1 * reach));
    }
    final body = wet > 0 ? const Color(0xFF9FD86A) : const Color(0xFFA8B4C4);
    final dark = wet > 0 ? const Color(0xFF3F7A2A) : const Color(0xFF4B5566);
    for (final e in ends) {
      c.drawLine(Offset.zero, e, D.stroke(Pal.ink, 24)..strokeCap = StrokeCap.butt);
    }
    c.drawCircle(Offset.zero, 13, D.fill(Pal.ink));
    for (final e in ends) {
      c.drawLine(Offset.zero, e, D.stroke(body, 17)..strokeCap = StrokeCap.butt);
    }
    c.drawCircle(Offset.zero, 9.5, D.fill(body));
    // channel
    for (final e in ends) {
      c.drawLine(Offset.zero, e, D.stroke(dark, 8)..strokeCap = StrokeCap.butt);
    }
    c.drawCircle(Offset.zero, 4.5, D.fill(dark));
    if (wet > 0) {
      for (final e in ends) {
        c.drawLine(Offset.zero, e * wet, D.stroke(_waterA.color, 8)..strokeCap = StrokeCap.butt);
        // shimmer dots
        for (var k = 0; k < 2; k++) {
          final f = ((_t * 2.2 + k * .5) % 1.0) * wet;
          c.drawCircle(e * f, 2, D.fill(const Color(0xCCFFFFFF)));
        }
      }
      c.drawCircle(Offset.zero, 4.5, _waterA);
    }
    // collars
    for (final e in ends) {
      final n = Offset(e.dy.sign.abs(), e.dx.sign.abs());
      final at = e * .86;
      c.drawLine(at - n * 12, at + n * 12, D.stroke(Pal.ink, 7)..strokeCap = StrokeCap.butt);
      c.drawLine(at - n * 10, at + n * 10, D.stroke(wet > 0 ? const Color(0xFFD7F2B8) : const Color(0xFFDDE3EA), 3.5)
        ..strokeCap = StrokeCap.butt);
    }
    // highlight
    c.drawCircle(const Offset(-3, -3), 2.5, D.fill(const Color(0x88FFFFFF)));
    c.restore();
  }

  void _faucet(Canvas c, Offset top) {
    // tank with a face
    final tank = Rect.fromCenter(center: top + const Offset(0, -62), width: 84, height: 60);
    D.rrect(c, tank.shift(const Offset(0, 4)), 16, const Color(0x44000000));
    D.rrect(c, tank, 16, const Color(0xFF3FB8FF), border: Pal.ink, borderWidth: 3.5);
    final lvl = 1 - (_connected ? min(1.0, _potWater * .5) : 0);
    D.rrect(c, Rect.fromLTWH(tank.left + 6, tank.top + 6 + (1 - lvl) * 20, tank.width - 12, 14), 7, const Color(0x55FFFFFF));
    D.face(c, tank.center + const Offset(0, 4), 20, _connected ? Face.happy : Face.neutral,
        look: Offset((_x0 + 150 - top.dx) / 150, 1));
    // pipe down into the grid
    c.drawRect(Rect.fromCenter(center: top + const Offset(0, -18), width: 26, height: 28), D.fill(Pal.ink));
    c.drawRect(Rect.fromCenter(center: top + const Offset(0, -18), width: 18, height: 28), D.fill(const Color(0xFFA8B4C4)));
    c.drawRect(Rect.fromCenter(center: top + const Offset(0, -18), width: 8, height: 28), D.fill(_waterA.color));
    // valve wheel
    c.save();
    c.translate(top.dx + 26, top.dy - 22);
    c.rotate(_connected ? _t * 6 : 0);
    D.circle(c, Offset.zero, 9, Pal.red, border: Pal.ink, borderWidth: 2.5);
    D.line(c, const Offset(-9, 0), const Offset(9, 0), Pal.ink, 2);
    D.line(c, const Offset(0, -9), const Offset(0, 9), Pal.ink, 2);
    c.restore();
  }

  void _pot(Canvas c, Offset bot) {
    // outlet pipe
    c.drawRect(Rect.fromCenter(center: bot + const Offset(0, 12), width: 26, height: 24), D.fill(Pal.ink));
    c.drawRect(Rect.fromCenter(center: bot + const Offset(0, 12), width: 18, height: 24), D.fill(const Color(0xFFA8B4C4)));
    if (_potWater > 0) {
      c.drawRect(Rect.fromCenter(center: bot + const Offset(0, 12), width: 8, height: 24), D.fill(_waterA.color));
      for (var i = 0; i < 3; i++) {
        final y = (_t * 90 + i * 12) % 30;
        c.drawCircle(bot + Offset(0, 26 + y), 3, _waterA);
      }
    }
    final base = Offset(bot.dx, 594);
    // flower
    final bloom = M.easeOutElastic(_bloom);
    final droop = (1 - _potWater) * .9;
    final stemTop = base + Offset(sin(droop) * 26, -48 - 10 * bloom - cos(droop) * 12);
    c.drawPath(
        Path()
          ..moveTo(base.dx, base.dy - 30)
          ..quadraticBezierTo(base.dx, stemTop.dy + 10, stemTop.dx, stemTop.dy),
        D.stroke(const Color(0xFF2E8C47), 5));
    c.drawOval(Rect.fromCenter(center: base + const Offset(-12, -40), width: 18, height: 9), D.fill(const Color(0xFF3FAF5A)));
    final pr = 13 + bloom * 10;
    final petal = _potWater > .5 ? Pal.pink : const Color(0xFFB49AA8);
    for (var k = 0; k < 7; k++) {
      final a = k * pi * 2 / 7 + _t * bloom * .6;
      c.drawCircle(stemTop + Offset(cos(a), sin(a)) * pr, pr * .62, D.fill(petal));
    }
    D.circle(c, stemTop, pr * .75, Pal.yellow, border: Pal.ink, borderWidth: 2);
    D.face(c, stemTop + const Offset(0, 1), pr * .7, _won ? Face.love : (_potWater > 0 ? Face.happy : Face.sad));
    // pot
    final pot = Path()
      ..moveTo(base.dx - 30, base.dy - 30)
      ..lineTo(base.dx + 30, base.dy - 30)
      ..lineTo(base.dx + 22, base.dy + 18)
      ..lineTo(base.dx - 22, base.dy + 18)
      ..close();
    c.drawPath(pot, D.fill(const Color(0xFFE07A4A)));
    c.drawPath(pot, D.stroke(Pal.ink, 3));
    D.rrect(c, Rect.fromCenter(center: base + const Offset(0, -30), width: 70, height: 12), 4, const Color(0xFFF08F5C),
        border: Pal.ink, borderWidth: 3);
  }
}

class _Pipe {
  _Pipe(this.base);
  int base;
  int rot = 0;
  double angle = 0;
  double squash = 0;
  double fill = 0;
}
