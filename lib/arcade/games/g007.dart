import '../engine/engine.dart';

/// No.007 Cut the Rope — swipe to cut the ropes (verlet sim) and feed the
/// candy to the hungry monster. Grab stars on the way.
class G007 extends MiniGame {
  static const _candyR = 17.0;
  static const _g = 980.0;

  // verlet particles
  final List<Offset> _pos = [];
  final List<Offset> _prev = [];
  final List<double> _inv = [];
  final List<_Link> _links = [];
  final List<Offset> _anchors = [];
  final List<List<int>> _ropes = []; // point indices from anchor → candy
  final List<_Star> _stars = [];
  late Offset _mouth;
  double _t = 0;
  double _spin = 0;
  bool _eaten = false;
  bool _lost = false;
  double _chomp = 0;
  double _open = 0;
  double _sad = 0;
  final List<(Offset, double)> _trail = [];
  Offset? _last;
  int _starsGot = 0;
  int _cuts = 0;
  double _blink = 0;

  Offset get _candy => _pos[0];

  // --------------------------------------------------------------- level ---
  @override
  void init() {
    _pos.add(Offset.zero);
    _prev.add(Offset.zero);
    _inv.add(.2);
    switch (randInt(3)) {
      case 0:
        _setCandy(const Offset(180, 250));
        _rope(const Offset(90, 120), 1.0);
        _rope(const Offset(270, 120), 1.0);
        _mouth = const Offset(264, 548);
        _stars.addAll([_Star(const Offset(222, 300)), _Star(const Offset(266, 380)), _Star(const Offset(266, 462))]);
      case 1:
        _setCandy(const Offset(180, 260));
        _rope(const Offset(60, 160), 1.0);
        _rope(const Offset(180, 96), 1.0);
        _rope(const Offset(300, 160), 1.0);
        _mouth = const Offset(80, 548);
        _stars.addAll([_Star(const Offset(122, 300)), _Star(const Offset(70, 390)), _Star(const Offset(78, 466))]);
      default:
        _setCandy(const Offset(58, 190));
        _rope(const Offset(180, 100), 1.0);
        _mouth = const Offset(292, 548);
        _stars.addAll([_Star(const Offset(180, 272)), _Star(const Offset(262, 250)), _Star(const Offset(294, 420))]);
    }
    if (chance(.5)) _mirror();
    // settle the ropes a bit (not the swinging level)
    for (var i = 0; i < 30; i++) {
      _sim(1 / 60, settle: _ropes.length > 1);
    }
  }

  void _setCandy(Offset p) {
    _pos[0] = p;
    _prev[0] = p;
  }

  void _rope(Offset anchor, double slack) {
    final len = (anchor - _candy).distance * slack;
    final n = max(8, (len / 16).round());
    final idx = <int>[];
    _anchors.add(anchor);
    for (var i = 0; i < n; i++) {
      final p = Offset.lerp(anchor, _candy, i / n)!;
      _pos.add(p);
      _prev.add(p);
      _inv.add(i == 0 ? 0 : 1);
      idx.add(_pos.length - 1);
    }
    idx.add(0);
    for (var i = 0; i + 1 < idx.length; i++) {
      _links.add(_Link(idx[i], idx[i + 1], len / n, _ropes.length));
    }
    _ropes.add(idx);
  }

  void _mirror() {
    Offset m(Offset p) => Offset(360 - p.dx, p.dy);
    for (var i = 0; i < _pos.length; i++) {
      _pos[i] = m(_pos[i]);
      _prev[i] = m(_prev[i]);
    }
    for (var i = 0; i < _anchors.length; i++) {
      _anchors[i] = m(_anchors[i]);
    }
    _mouth = m(_mouth);
    for (final s in _stars) {
      s.pos = m(s.pos);
    }
  }

  // ------------------------------------------------------------- physics ---
  void _sim(double dt, {bool settle = false}) {
    const sub = 2;
    final h = dt / sub;
    for (var s = 0; s < sub; s++) {
      for (var i = 0; i < _pos.length; i++) {
        if (_inv[i] == 0) continue;
        final v = (_pos[i] - _prev[i]) * (settle ? .8 : .995);
        _prev[i] = _pos[i];
        _pos[i] = _pos[i] + v + Offset(0, _g * h * h);
      }
      for (var it = 0; it < 10; it++) {
        for (final l in _links) {
          if (!l.alive) continue;
          final a = _pos[l.a], b = _pos[l.b];
          final d = b - a;
          final dist = d.distance;
          if (dist < 1e-6) continue;
          // ropes only pull (no push) so they can go slack
          if (dist <= l.rest) continue;
          final wa = _inv[l.a], wb = _inv[l.b];
          final wsum = wa + wb;
          if (wsum == 0) continue;
          final corr = d * ((dist - l.rest) / dist / wsum);
          _pos[l.a] = a + corr * wa;
          _pos[l.b] = b - corr * wb;
        }
      }
    }
  }

  // --------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    _blink -= dt;
    if (_blink < -3) _blink = rand(0, 1);
    if (!_eaten) {
      _sim(dt);
      final v = (_pos[0] - _prev[0]) / max(dt, 1e-4);
      _spin += v.dx * dt * .03;
      // magnet: monster slurps nearby candy
      final to = _mouth - _candy;
      final falling = !_attached;
      if (falling && to.dy > -10 && to.dy < 200 && to.dx.abs() < 95) {
        _pos[0] = _pos[0] + Offset(to.dx * dt * 3.2, 0);
      }
      _open = M.approach(_open, falling && to.distance < 230 ? 1 : 0, 8, dt);
      for (final s in _stars) {
        if (!s.got && (s.pos - _candy).distance < _candyR + 16) {
          s.got = true;
          _starsGot++;
          host.sfx(Sfx.star, rate: 1 + _starsGot * .15);
          host.fx.burst(s.pos, Pal.yellow, count: 16, speed: 220, shape: PartShape.star, size: 7);
          host.fx.ring(s.pos, Pal.yellow, size: 50);
          host.addScore(100 * _starsGot, s.pos - const Offset(0, 24));
        }
      }
      if (!_lost && to.distance < 34) _eat();
      if (!_lost && !_eaten && (_candy.dy > 690 || _candy.dx < -60 || _candy.dx > 420)) {
        _lost = true;
        host.sfx(Sfx.aww);
        host.lose();
      }
    }
    _chomp = max(0, _chomp - dt * 2.5);
    if (_lost) _sad = min(1, _sad + dt * 3);
    for (final s in _stars) {
      s.pop = s.got ? min(1, s.pop + dt * 4) : 0;
    }
    for (var i = _trail.length - 1; i >= 0; i--) {
      final (p, life) = _trail[i];
      if (life - dt <= 0) {
        _trail.removeAt(i);
      } else {
        _trail[i] = (p, life - dt);
      }
    }
  }

  bool get _attached => _links.any((l) => l.alive && (l.a == 0 || l.b == 0) && _ropeIntact(l.rope));

  bool _ropeIntact(int r) => _links.every((l) => l.rope != r || l.alive);

  void _eat() {
    _eaten = true;
    _chomp = 1;
    host.sfx(Sfx.chomp);
    host.sfx(Sfx.correct, rate: 1.2);
    host.shake(6);
    host.punch(.05);
    host.fx.burst(_mouth, Pal.pink, count: 24, speed: 260, colors: const [Pal.pink, Pal.red, Pal.white, Pal.yellow]);
    host.fx.pop(host.tr('yummy', 'YUMMY!'), _mouth - const Offset(0, 100), color: Pal.lime, size: 40, life: 1.2);
    host.addScore(300);
    host.win(stars: (1 + _starsGot).clamp(1, 3));
  }

  // ---------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    _last = p;
    _trail.add((p, .25));
  }

  @override
  void onMove(Offset p) {
    final a = _last;
    _last = p;
    _trail.add((p, .25));
    if (_trail.length > 24) _trail.removeAt(0);
    if (a == null || _eaten) return;
    for (final l in _links) {
      if (!l.alive) continue;
      if (_segHit(a, p, _pos[l.a], _pos[l.b])) {
        _cut(l, Offset.lerp(_pos[l.a], _pos[l.b], .5)!);
      }
    }
  }

  @override
  void onUp(Offset p) => _last = null;

  void _cut(_Link l, Offset at) {
    // cut the whole rope at this link
    l.alive = false;
    _cuts++;
    host.sfx(Sfx.slash, rate: 1 + _cuts * .08);
    host.sfx(Sfx.rip, volume: .5);
    host.fx.burst(at, const Color(0xFFB07A4F), count: 10, speed: 160, size: 5);
    host.fx.sparkle(at, count: 4, radius: 10);
    host.shake(2);
  }

  static bool _segHit(Offset p1, Offset p2, Offset p3, Offset p4) {
    double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
    final r = p2 - p1, s = p4 - p3;
    final den = cross(r, s);
    if (den.abs() < 1e-9) return false;
    final t = cross(p3 - p1, s) / den;
    final u = cross(p3 - p1, r) / den;
    return t >= 0 && t <= 1 && u >= -.1 && u <= 1.1;
  }

  @override
  void onKey(String key, bool down) {
    if (!down || key != 'action') return;
    for (final l in _links) {
      if (l.alive && l.b == 0) {
        _cut(l, _pos[l.a]);
        return;
      }
    }
  }

  // --------------------------------------------------------------- render ---
  @override
  void render(Canvas c) {
    // cardboard room
    D.gradientBg(c, const [Color(0xFFF6D7A7), Color(0xFFE2A96B)]);
    final stripe = Paint()..color = const Color(0x14FFFFFF);
    for (var x = -40.0; x < 400; x += 36) {
      c.drawPath(
          Path()
            ..moveTo(x, 40)
            ..lineTo(x + 18, 40)
            ..lineTo(x + 18 - 60, 640)
            ..lineTo(x - 60, 640)
            ..close(),
          stripe);
    }
    // doodles
    for (var i = 0; i < 7; i++) {
      final o = Offset((i * 131.0) % 330 + 15, 150 + (i * 89.0) % 330);
      D.star(c, o, 7, const Color(0x22FFFFFF), rotation: i * .7 + _t * .2);
    }
    // monster's box
    final box = Rect.fromCenter(center: _mouth + const Offset(0, 62), width: 110, height: 64);
    D.rrect(c, box, 6, const Color(0xFFC8874E), border: Pal.ink, borderWidth: 3);
    c.drawLine(Offset(box.left + 8, box.top + 16), Offset(box.right - 8, box.top + 16), D.stroke(const Color(0xFF9A6236), 3));
    D.rrect(c, Rect.fromCenter(center: box.center + const Offset(0, 10), width: 34, height: 14), 3,
        const Color(0xFFE8B070));
    // stars
    for (final s in _stars) {
      if (s.pop >= 1) continue;
      final k = s.got ? 1 + s.pop : 1.0 + sin(_t * 4 + s.pos.dx) * .08;
      c.drawCircle(s.pos, 22 * k, D.fill(Color.fromRGBO(255, 230, 120, .25 * (1 - s.pop))));
      D.star(c, s.pos, 16 * k, Pal.yellow, border: Pal.ink, rotation: -pi / 2 + sin(_t * 2 + s.pos.dy) * .2);
    }
    _drawMonster(c);
    // anchors & ropes
    for (var r = 0; r < _ropes.length; r++) {
      _drawRope(c, r);
    }
    for (final a in _anchors) {
      c.drawCircle(a, 11, D.fill(Pal.ink));
      c.drawCircle(a, 8, D.fill(const Color(0xFFB9B2CF)));
      c.drawCircle(a - const Offset(2, 2), 3, D.fill(Pal.white));
    }
    if (!_eaten) _drawCandy(c, _candy);
    // swipe trail
    if (_trail.length > 1) {
      for (var i = 1; i < _trail.length; i++) {
        final (a, la) = _trail[i - 1];
        final (b, _) = _trail[i];
        c.drawLine(a, b, D.stroke(Color.fromRGBO(255, 255, 255, (la / .25).clamp(0, 1)), 2 + i * .35));
      }
    }
    // hint: swipe across the first rope to cut
    if (_cuts == 0 && host.time < 3.5) {
      final l = _links.firstWhere((l) => l.rope == _hintRope && l.b != 0, orElse: () => _links.first);
      final mid = Offset.lerp(_pos[l.a], _pos[l.b], .5)!;
      final k = (_t * 1.2) % 1;
      final from = mid + const Offset(-50, -30), to = mid + const Offset(50, 30);
      c.drawLine(from, to, D.stroke(const Color(0x66FFFFFF), 6));
      D.hand(c, Offset.lerp(from, to, k)!, 0);
      D.text(c, host.tr('swipe', 'SWIPE!'), mid + const Offset(0, -60), size: 24, stroke: Pal.ink);
    }
    // stars HUD
    for (var i = 0; i < 3; i++) {
      final o = Offset(146 + i * 34.0, 64);
      D.star(c, o, 14, i < _starsGot ? Pal.yellow : const Color(0x55000000), border: Pal.ink);
    }
  }

  int get _hintRope {
    // hint the rope whose anchor is farthest from the monster
    var best = 0;
    var bd = -1.0;
    for (var r = 0; r < _anchors.length; r++) {
      final d = (_anchors[r].dx - _mouth.dx).abs();
      if (d > bd) {
        bd = d;
        best = r;
      }
    }
    return _anchors.length == 1 ? 0 : best;
  }

  void _drawRope(Canvas c, int r) {
    final idx = _ropes[r];
    // draw segments that are still connected
    final dark = D.stroke(const Color(0xFF5A3A1E), 6);
    final light = D.stroke(const Color(0xFFC98B55), 3.4);
    final twist = D.stroke(const Color(0xFF8A5A3C), 2);
    for (var i = 0; i + 1 < idx.length; i++) {
      final l = _links.firstWhere((l) => l.a == idx[i] && l.b == idx[i + 1] && l.rope == r);
      if (!l.alive) continue;
      final a = _pos[idx[i]], b = _pos[idx[i + 1]];
      if (idx[i + 1] == 0 && _eaten) continue;
      c.drawLine(a, b, dark);
      c.drawLine(a, b, light);
      if (i.isEven) c.drawLine(Offset.lerp(a, b, .3)!, Offset.lerp(a, b, .6)!, twist);
    }
  }

  void _drawCandy(Canvas c, Offset p) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(_spin);
    // wrapper tails
    for (final s in const [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(s * _candyR * .8, 0)
        ..lineTo(s * (_candyR + 14), -10)
        ..lineTo(s * (_candyR + 11), 0)
        ..lineTo(s * (_candyR + 14), 10)
        ..close();
      c.drawPath(path, D.fill(const Color(0xFFFFE066)));
      c.drawPath(path, D.stroke(Pal.ink, 2.5));
    }
    c.drawCircle(Offset.zero, _candyR, D.fill(Pal.white));
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: _candyR)));
    for (var i = 0; i < 4; i++) {
      c.save();
      c.rotate(i * pi / 2);
      c.drawPath(
          Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(_candyR * .9, -_candyR * .2, _candyR * 1.2, _candyR * .6)
            ..lineTo(_candyR * .5, _candyR * 1.1)
            ..quadraticBezierTo(_candyR * .5, _candyR * .2, 0, 0),
          D.fill(const Color(0xFFFF3B5C)));
      c.restore();
    }
    c.restore();
    c.drawCircle(Offset.zero, _candyR, D.stroke(Pal.ink, 3));
    c.restore();
    c.drawCircle(p + const Offset(-6, -7), 4, D.fill(const Color(0xAAFFFFFF)));
  }

  void _drawMonster(Canvas c) {
    final m = _mouth;
    final chew = _eaten ? (sin(_t * 18) * .5 + .5) * _chomp : 0.0;
    final bounce = _eaten ? sin(_t * 12) * 3 : sin(_t * 3) * 2;
    final squash = 1 + chew * .1;
    c.save();
    c.translate(m.dx, m.dy + 20 + bounce);
    c.scale(squash, 1 / squash);
    const green = Color(0xFF7ED957);
    const dark = Color(0xFF3E9A2E);
    // antenna
    c.drawLine(const Offset(0, -38), const Offset(-4, -56), D.stroke(Pal.ink, 5));
    c.drawLine(const Offset(0, -38), const Offset(-4, -56), D.stroke(dark, 2.5));
    c.drawCircle(const Offset(-4, -58), 6, D.fill(green));
    c.drawCircle(const Offset(-4, -58), 6, D.stroke(Pal.ink, 2.5));
    // body
    final body = Rect.fromCenter(center: Offset.zero, width: 96, height: 84);
    c.drawOval(body, D.fill(green));
    c.drawOval(Rect.fromCenter(center: const Offset(-18, -22), width: 30, height: 16), D.fill(const Color(0x55FFFFFF)));
    c.drawOval(body, D.stroke(Pal.ink, 3.5));
    // eyes follow candy
    final look = (_candy - m) / max((_candy - m).distance, 1.0);
    for (final s in const [-1.0, 1.0]) {
      final e = Offset(s * 20, -14);
      if (_sad > 0) {
        c.drawArc(Rect.fromCenter(center: e, width: 18, height: 12), 0, pi, false, D.stroke(Pal.ink, 3));
        c.drawOval(Rect.fromCenter(center: e + Offset(s * 2, 14 + _t * 20 % 10), width: 6, height: 10),
            D.fill(const Color(0xCC6ECBFF)));
      } else if (_blink > 0 && _blink < .12 && !_eaten) {
        c.drawLine(e - const Offset(9, 0), e + const Offset(9, 0), D.stroke(Pal.ink, 3));
      } else if (_eaten) {
        c.drawArc(Rect.fromCenter(center: e + const Offset(0, 3), width: 18, height: 16), pi, pi, false, D.stroke(Pal.ink, 3.5));
      } else {
        c.drawCircle(e, 12, D.fill(Pal.white));
        c.drawCircle(e, 12, D.stroke(Pal.ink, 2.5));
        c.drawCircle(e + look * 5, 5.5, D.fill(Pal.ink));
        c.drawCircle(e + look * 5 - const Offset(2, 2), 2, D.fill(Pal.white));
      }
    }
    // mouth
    final open = _eaten ? (1 - chew) * .2 : _open;
    final mw = 44.0 + open * 14, mh = 8.0 + open * 34;
    final mouth = Rect.fromCenter(center: Offset(0, 16 + open * 4), width: mw, height: mh);
    if (_sad > 0) {
      c.drawArc(Rect.fromCenter(center: const Offset(0, 26), width: 36, height: 18), pi, pi, false, D.stroke(Pal.ink, 4));
    } else {
      c.drawOval(mouth, D.fill(const Color(0xFF8B1E3F)));
      if (open > .2) {
        c.drawOval(Rect.fromCenter(center: mouth.center + Offset(0, mh * .25), width: mw * .5, height: mh * .35),
            D.fill(const Color(0xFFFF6F91)));
      }
      // teeth
      for (final s in const [-1.0, 1.0]) {
        c.drawPath(
            Path()
              ..moveTo(s * 10 - 5, mouth.top + 1)
              ..lineTo(s * 10 + 5, mouth.top + 1)
              ..lineTo(s * 10, mouth.top + 6 + open * 4)
              ..close(),
            D.fill(Pal.white));
      }
      c.drawOval(mouth, D.stroke(Pal.ink, 3));
    }
    // feet
    for (final s in const [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(s * 26, 40), width: 26, height: 12), D.fill(dark));
    }
    c.restore();
    if (!_eaten && !_lost && _open > .5) {
      D.text(c, '!!', m + const Offset(46, -44), size: 22, color: Pal.red, stroke: Pal.ink);
    }
  }
}

class _Link {
  _Link(this.a, this.b, this.rest, this.rope);
  final int a, b;
  final double rest;
  final int rope;
  bool alive = true;
}

class _Star {
  _Star(this.pos);
  Offset pos;
  bool got = false;
  double pop = 0;
}
