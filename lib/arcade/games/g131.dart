import '../engine/engine.dart';

/// No.131 Spot 3 Differences — two procedural scenes, find the 3 changes.
/// Misclicks stun you for a moment (the time penalty).
class G131 extends MiniGame {
  static const _w = 330.0, _h = 214.0;
  static const _tops = [52.0, 290.0];
  static const _left = 15.0;

  final List<_Diff> _diffs = [];
  bool _flip = false;
  late Color _roof, _roofAlt, _wall, _car, _carAlt, _cat, _catAlt, _door, _doorAlt;
  double _t = 0;
  double _stun = 0;
  final List<_Miss> _misses = [];
  int _found = 0;
  double _eyeBump = 0;
  Face _eyeFace = Face.neutral;
  double _faceT = 0;

  // kind -> (center, radius) in unflipped scene coords
  static const _spots = <int, (Offset, double)>{
    0: (Offset(90, 80), 36), // roof color
    1: (Offset(126, 126), 18), // window missing
    2: (Offset(126, 68), 18), // chimney missing
    3: (Offset(284, 42), 30), // sun size
    4: (Offset(190, 38), 32), // cloud missing
    5: (Offset(232, 98), 38), // tree autumn
    6: (Offset(292, 160), 24), // cat color
    7: (Offset(128, 192), 34), // car color
    8: (Offset(24, 182), 18), // flower missing
    9: (Offset(96, 22), 18), // bird missing
    10: (Offset(89, 147), 18), // door color
    11: (Offset(292, 126), 20), // party hat on cat
  };

  @override
  void init() {
    _flip = chance(.5);
    final roofs = [Pal.red, const Color(0xFF3D6BFF), const Color(0xFF8C4DFF)]..shuffle(rng);
    _roof = roofs[0];
    _roofAlt = roofs[1];
    _wall = pick(const [Color(0xFFFFF1C9), Color(0xFFFFD9E6), Color(0xFFE2F2FF)]);
    final cars = [Pal.yellow, Pal.sky, Pal.lime, Pal.pink]..shuffle(rng);
    _car = cars[0];
    _carAlt = cars[1] == Pal.yellow || _car == Pal.yellow ? Pal.red : cars[1];
    final cats = [const Color(0xFFFFA64D), const Color(0xFF6E6A80), Pal.white]..shuffle(rng);
    _cat = cats[0];
    _catAlt = cats[1];
    final doors = [Pal.brown, Pal.green, Pal.purple]..shuffle(rng);
    _door = doors[0];
    _doorAlt = doors[1];
    final kinds = _spots.keys.toList()..shuffle(rng);
    for (final k in kinds) {
      if (_diffs.length == 3) break;
      final cen = _fl(_spots[k]!.$1);
      if (_diffs.any((d) => (d.center - cen).distance < 58)) continue;
      _diffs.add(_Diff(k, cen, _spots[k]!.$2, randInt(2)));
    }
  }

  Offset _fl(Offset o) => _flip ? Offset(_w - o.dx, o.dy) : o;

  bool _mod(int kind, int side) {
    for (final d in _diffs) {
      if (d.kind == kind && d.side == side) return true;
    }
    return false;
  }

  // ---------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    if (host.finished || _stun > 0) return;
    for (var side = 0; side < 2; side++) {
      final r = Rect.fromLTWH(_left, _tops[side], _w, _h);
      if (!r.contains(p)) continue;
      final local = p - r.topLeft;
      _Diff? best;
      var bd = 1e9;
      for (final d in _diffs) {
        if (d.found) continue;
        final dist = (local - d.center).distance;
        if (dist < d.radius + 12 && dist < bd) {
          bd = dist;
          best = d;
        }
      }
      if (best != null) {
        _hit(best);
      } else {
        _miss(p);
      }
      return;
    }
  }

  void _hit(_Diff d) {
    d.found = true;
    _found++;
    host.sfx(Sfx.correct, rate: 1 + _found * .12);
    host.sfx(Sfx.pop, volume: .6);
    for (var s = 0; s < 2; s++) {
      final at = Offset(_left, _tops[s]) + d.center;
      host.fx.burst(at, Pal.yellow, count: 12, shape: PartShape.star, speed: 200, gravity: 100);
      host.fx.ring(at, Pal.red, size: 50);
    }
    host.fx.pop(
        [host.tr('nice', 'NICE!'), host.tr('great', 'GREAT!'), host.tr('wow', 'WOW!')][_found - 1],
        Offset(_left, _tops[d.side]) + d.center + const Offset(0, -30),
        color: Pal.yellow,
        size: 28);
    host.punch(.03);
    _eyeBump = 1;
    _eyeFace = Face.happy;
    _faceT = 1;
    if (_found == 3) {
      host.sfx(Sfx.fanfare, volume: .8);
      final left = host.timeLeft;
      host.win(stars: left > 9 ? 3 : (left > 4 ? 2 : 1));
    }
  }

  void _miss(Offset p) {
    _stun = .8;
    _misses.add(_Miss(p));
    host.sfx(Sfx.buzzer, volume: .7);
    host.shake(6);
    host.flash(const Color(0x55FF3B5C), .15);
    host.fx.pop(host.tr('miss', 'MISS'), p + const Offset(0, -26), color: Pal.red, size: 24);
    _eyeFace = Face.dead;
    _faceT = .8;
  }

  // --------------------------------------------------------- update ---

  @override
  void update(double dt) {
    _t += dt;
    _stun = max(0, _stun - dt);
    _eyeBump = M.approach(_eyeBump, 0, 6, dt);
    _faceT -= dt;
    if (_faceT <= 0) _eyeFace = host.finished ? (_found == 3 ? Face.love : Face.cry) : Face.neutral;
    for (final d in _diffs) {
      if (d.found || host.finished) d.foundT += dt;
    }
    for (final m in _misses) {
      m.t += dt;
    }
    _misses.removeWhere((m) => m.t > .9);
  }

  // --------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF2B2463), Color(0xFF4B2E83), Color(0xFF1C1640)]);
    // checker pattern
    final pat = D.fill(const Color(0x10FFFFFF));
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 9; x++) {
        if ((x + y).isEven) c.drawRect(Rect.fromLTWH(x * 40.0, y * 40.0 + (_t * 10) % 80 - 40, 40, 40), pat);
      }
    }
    for (var s = 0; s < 2; s++) {
      final r = Rect.fromLTWH(_left, _tops[s], _w, _h);
      D.rrect(c, r.inflate(5).shift(const Offset(0, 5)), 16, const Color(0x66000000));
      D.rrect(c, r.inflate(5), 16, Pal.white);
      c.save();
      c.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)));
      c.translate(r.left, r.top);
      if (_flip) {
        c.translate(_w, 0);
        c.scale(-1, 1);
      }
      _scene(c, s);
      c.restore();
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)), D.stroke(Pal.ink, 3));
      // marks
      for (final d in _diffs) {
        final cen = r.topLeft + d.center;
        if (d.found) {
          final k = (d.foundT / .3).clamp(0.0, 1.0);
          c.drawArc(Rect.fromCircle(center: cen, radius: d.radius + 6), -pi / 2, pi * 2 * k, false, D.stroke(Pal.ink, 7));
          c.drawArc(Rect.fromCircle(center: cen, radius: d.radius + 6), -pi / 2, pi * 2 * k, false, D.stroke(Pal.red, 4.5));
        } else if (host.finished) {
          final a = M.wave(_t, 3);
          c.drawCircle(cen, d.radius + 6, D.stroke(Color.fromRGBO(255, 210, 63, .5 + .5 * a), 4));
        } else if (host.time > 11) {
          // hint glow
          final hint = _diffs.firstWhere((e) => !e.found);
          if (identical(hint, d)) {
            c.drawCircle(cen, d.radius + 10 + 6 * M.wave(_t, 1.5),
                D.stroke(Color.fromRGBO(255, 255, 160, .25 + .2 * M.wave(_t, 3)), 3));
          }
        }
      }
    }
    // divider badge
    D.circle(c, const Offset(180, 284), 16, Pal.yellow, border: Pal.ink, borderWidth: 3);
    D.text(c, '3', const Offset(180, 284.5), size: 18, color: Pal.ink);

    for (final m in _misses) {
      final k = 1 - m.t / .9;
      final s = 12 * M.easeOutBack((m.t / .2).clamp(0.0, 1.0));
      final col = Color.fromRGBO(255, 59, 92, k);
      D.line(c, m.p + Offset(-s, -s), m.p + Offset(s, s), col, 6);
      D.line(c, m.p + Offset(s, -s), m.p + Offset(-s, s), col, 6);
    }

    // HUD: 3 slots + the "genius eye"
    D.rrect(c, const Rect.fromLTWH(14, 522, 332, 104), 22, const Color(0x44000000));
    for (var i = 0; i < 3; i++) {
      final p = Offset(46 + i * 56.0, 574);
      final on = i < _found;
      D.circle(c, p, 22, on ? Pal.gold : const Color(0x33FFFFFF), border: Pal.ink, borderWidth: 3);
      if (on) {
        D.star(c, p, 14, Pal.white);
      } else {
        D.text(c, '?', p, size: 22, color: const Color(0x88FFFFFF));
      }
    }
    _eye(c, Offset(276, 574 + sin(_t * 2) * 3), 40 * (1 + _eyeBump * .15));
    if (_stun > 0) {
      for (var i = 0; i < 3; i++) {
        final a = _t * 6 + i * pi * 2 / 3;
        D.star(c, Offset(276 + cos(a) * 44, 540 + sin(a) * 10), 7, Pal.yellow);
      }
    }
    if (host.time < 2.2 && _found == 0) {
      D.hand(c, const Offset(180, 300 + 107), _t);
    }
  }

  void _eye(Canvas c, Offset o, double r) {
    // a big googly "genius" eye with a monocle
    D.circle(c, o, r, Pal.white, border: Pal.ink, borderWidth: 4);
    if (_eyeFace == Face.dead) {
      D.line(c, o + Offset(-r * .4, -r * .4), o + Offset(r * .4, r * .4), Pal.ink, 6);
      D.line(c, o + Offset(r * .4, -r * .4), o + Offset(-r * .4, r * .4), Pal.ink, 6);
    } else if (_eyeFace == Face.happy || _eyeFace == Face.love) {
      c.drawArc(Rect.fromCircle(center: o + Offset(0, r * .2), radius: r * .5), pi, pi, false, D.stroke(Pal.ink, 7));
      if (_eyeFace == Face.love) D.heart(c, o + Offset(0, -r * .1), r * .7, Pal.red);
    } else {
      final look = Offset(sin(_t * 1.3) * r * .3, cos(_t * .9) * r * .2);
      D.circle(c, o + look, r * .45, const Color(0xFF3DA5FF));
      D.circle(c, o + look, r * .24, Pal.ink);
      D.circle(c, o + look + Offset(-r * .1, -r * .12), r * .08, Pal.white);
      if (_eyeFace == Face.cry) {
        c.drawOval(Rect.fromCenter(center: o + Offset(r * .5, r * .95), width: 10, height: 18), D.fill(Pal.sky));
      }
    }
    c.drawCircle(o, r + 6, D.stroke(Pal.gold, 5));
    c.drawLine(o + Offset(r * .7, r * .75), o + Offset(r * .95, r * 1.3), D.stroke(Pal.gold, 3));
  }

  // -------------------------------------------------------- the scene ---

  void _scene(Canvas c, int s) {
    bool m(int k) => _mod(k, s);
    D.gradientBg(c, const [Color(0xFF7CCBFF), Color(0xFFD5F0FF)], rect: const Rect.fromLTWH(0, 0, _w, 170));
    // sun
    final sr = m(3) ? 13.0 : 25.0;
    D.rays(c, const Offset(284, 42), sr * 2.1, const Color(0x55FFE066), count: 10, t: _t * .4);
    D.circle(c, const Offset(284, 42), sr, Pal.yellow, border: const Color(0xFFE0A019), borderWidth: 3);
    // clouds
    if (!m(4)) D.cloud(c, Offset(190 + sin(_t * .6) * 3, 38), 44);
    D.cloud(c, Offset(40 + sin(_t * .5 + 1) * 3, 34), 34);
    // bird
    if (!m(9)) {
      final f = sin(_t * 9) * 5;
      c.drawPath(
          Path()
            ..moveTo(84, 22 + f)
            ..quadraticBezierTo(90, 16, 96, 24)
            ..quadraticBezierTo(102, 16, 108, 22 + f),
          D.stroke(Pal.ink, 3));
    }
    // ground
    c.drawRect(const Rect.fromLTWH(0, 165, _w, 60), D.fill(const Color(0xFF6FD25A)));
    c.drawRect(const Rect.fromLTWH(0, 178, _w, 32), D.fill(const Color(0xFF8C8FA3)));
    for (var i = 0; i < 7; i++) {
      c.drawRect(Rect.fromLTWH(8 + i * 50.0, 192, 26, 4), D.fill(Pal.white));
    }
    // fence
    for (var i = 0; i < 5; i++) {
      D.rrect(c, Rect.fromLTWH(160 + i * 12.0, 146, 7, 22), 2, Pal.white, border: const Color(0xFFB0A89A), borderWidth: 1.5);
    }
    c.drawRect(const Rect.fromLTWH(158, 152, 60, 4), D.fill(Pal.white));
    // house
    if (!m(2)) {
      c.drawRect(const Rect.fromLTWH(118, 56, 16, 30), D.fill(const Color(0xFF9A5B34)));
      c.drawRect(const Rect.fromLTWH(118, 56, 16, 30), D.stroke(Pal.ink, 2.5));
      for (var i = 0; i < 2; i++) {
        final y = (_t * 14 + i * 12) % 24;
        c.drawCircle(Offset(126 + sin(_t + i) * 3, 50 - y), 5 + y * .2, D.fill(Color.fromRGBO(240, 240, 240, .8 - y / 30)));
      }
    }
    D.rrect(c, const Rect.fromLTWH(40, 98, 100, 68), 3, _wall, border: Pal.ink, borderWidth: 3);
    final roof = Path()
      ..moveTo(28, 102)
      ..lineTo(90, 52)
      ..lineTo(152, 102)
      ..close();
    c.drawPath(roof, D.fill(m(0) ? _roofAlt : _roof));
    c.drawPath(roof, D.stroke(Pal.ink, 3));
    D.rrect(c, const Rect.fromLTWH(78, 128, 22, 38), 4, m(10) ? _doorAlt : _door, border: Pal.ink, borderWidth: 2.5);
    c.drawCircle(const Offset(95, 148), 2.5, D.fill(Pal.gold));
    _window(c, const Offset(58, 126));
    if (!m(1)) _window(c, const Offset(126, 126));
    // tree
    final autumn = m(5);
    D.tree(c, const Offset(232, 168), 118, leaf: autumn ? const Color(0xFFFF8A1F) : const Color(0xFF2FA84F));
    // cat
    _catDraw(c, const Offset(292, 168), m(6) ? _catAlt : _cat, m(11));
    // car
    _carDraw(c, const Offset(128, 196), m(7) ? _carAlt : _car);
    // flowers
    for (var i = 0; i < 3; i++) {
      if (i == 0 && m(8)) continue;
      final p = Offset(const [24.0, 64.0, 178.0][i], 176);
      final col = [Pal.pink, Pal.yellow, Pal.purple][i];
      c.drawLine(p, p + const Offset(0, 10), D.stroke(const Color(0xFF2E8C47), 2.5));
      for (var k = 0; k < 5; k++) {
        final a = k * pi * 2 / 5 + _t * .3;
        c.drawCircle(p + Offset(cos(a), sin(a)) * 5, 4.5, D.fill(col));
      }
      c.drawCircle(p, 3.5, D.fill(Pal.orange));
    }
  }

  void _window(Canvas c, Offset o) {
    D.rrect(c, Rect.fromCenter(center: o, width: 22, height: 22), 3, const Color(0xFF9EDCFF), border: Pal.ink, borderWidth: 2.5);
    c.drawLine(o + const Offset(0, -10), o + const Offset(0, 10), D.stroke(Pal.ink, 2));
    c.drawLine(o + const Offset(-10, 0), o + const Offset(10, 0), D.stroke(Pal.ink, 2));
  }

  void _catDraw(Canvas c, Offset feet, Color col, bool hat) {
    final tail = sin(_t * 4) * .4;
    c.drawPath(
        Path()
          ..moveTo(feet.dx + 10, feet.dy - 6)
          ..quadraticBezierTo(feet.dx + 26, feet.dy - 10, feet.dx + 22 + tail * 10, feet.dy - 28),
        D.stroke(Pal.ink, 7));
    c.drawPath(
        Path()
          ..moveTo(feet.dx + 10, feet.dy - 6)
          ..quadraticBezierTo(feet.dx + 26, feet.dy - 10, feet.dx + 22 + tail * 10, feet.dy - 28),
        D.stroke(col, 4));
    c.drawOval(Rect.fromCenter(center: feet + const Offset(0, -10), width: 26, height: 22), D.fill(col));
    c.drawOval(Rect.fromCenter(center: feet + const Offset(0, -10), width: 26, height: 22), D.stroke(Pal.ink, 2.5));
    final head = feet + const Offset(0, -28);
    for (final s in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(head.dx + s * 11, head.dy - 3)
        ..lineTo(head.dx + s * 9, head.dy - 16)
        ..lineTo(head.dx + s * 2, head.dy - 9)
        ..close();
      c.drawPath(ear, D.fill(col));
      c.drawPath(ear, D.stroke(Pal.ink, 2.5));
    }
    D.circle(c, head, 12, col, border: Pal.ink, borderWidth: 2.5);
    D.face(c, head + const Offset(0, 1), 10, Face.happy, blush: true);
    if (hat) {
      final h = Path()
        ..moveTo(head.dx - 8, head.dy - 9)
        ..lineTo(head.dx + 2, head.dy - 32)
        ..lineTo(head.dx + 9, head.dy - 7)
        ..close();
      c.drawPath(h, D.fill(Pal.pink));
      c.drawPath(h, D.stroke(Pal.ink, 2.5));
      c.drawCircle(Offset(head.dx + 2, head.dy - 33), 4, D.fill(Pal.yellow));
    }
  }

  void _carDraw(Canvas c, Offset o, Color col) {
    final bob = sin(_t * 12) * .8;
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: o + Offset(0, -6 + bob), width: 70, height: 20), const Radius.circular(8));
    final top = RRect.fromRectAndRadius(Rect.fromCenter(center: o + Offset(-4, -20 + bob), width: 40, height: 18), const Radius.circular(8));
    c.drawRRect(top, D.fill(col));
    c.drawRRect(top, D.stroke(Pal.ink, 2.5));
    c.drawRect(Rect.fromCenter(center: o + Offset(2, -20 + bob), width: 14, height: 10), D.fill(const Color(0xFFBFEAFF)));
    c.drawRRect(body, D.fill(col));
    c.drawRRect(body, D.stroke(Pal.ink, 2.5));
    for (final x in [-20.0, 20.0]) {
      D.circle(c, o + Offset(x, 4), 8, Pal.ink);
      D.circle(c, o + Offset(x, 4), 3.5, Pal.gray);
    }
    c.drawCircle(o + Offset(33, -8 + bob), 3, D.fill(Pal.yellow));
  }
}

class _Diff {
  _Diff(this.kind, this.center, this.radius, this.side);
  final int kind;
  final Offset center;
  final double radius;
  final int side;
  bool found = false;
  double foundT = 0;
}

class _Miss {
  _Miss(this.p);
  final Offset p;
  double t = 0;
}
