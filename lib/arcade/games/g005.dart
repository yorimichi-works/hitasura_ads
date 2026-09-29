import 'dart:collection';

import '../engine/engine.dart';

/// No.005 Parking Jam — slide cars along their axis and get the red car out.
class G005 extends MiniGame {
  static const _n = 6;
  static const _cell = 50.0;
  static const _ox = 24.0, _oy = 196.0;
  static const _exitRow = 2;
  static const _colors = <Color>[
    Color(0xFF3D8BFF),
    Color(0xFFFFD23F),
    Color(0xFF2ECC71),
    Color(0xFFB45CFF),
    Color(0xFFFF8A1F),
    Color(0xFF14C9C9),
    Color(0xFFFF5FC8),
    Color(0xFFEDEDF5),
  ];

  final List<_Car> _cars = [];
  _Car? _drag;
  double _grab = 0;
  double _lo = 0, _hi = 0;
  bool _bumped = false;
  double _t = 0;
  bool _exiting = false;
  double _exitV = 0;
  int _moves = 0;
  (int, int)? _hint; // car index, target pos
  double _dust = 0;

  _Car get _red => _cars[0];

  // ------------------------------------------------------------ generate ---
  @override
  void init() {
    List<_Car>? best;
    (int, int)? bestHint;
    var bestScore = -1;
    for (var attempt = 0; attempt < 60; attempt++) {
      final cars = _randomLot();
      if (cars == null) continue;
      final (moves, hint) = _solve(cars);
      if (moves < 0) continue;
      final score = moves >= 3 && moves <= 6 ? 100 - (moves - 4).abs() : moves;
      if (score > bestScore) {
        bestScore = score;
        best = cars;
        bestHint = hint;
      }
      if (moves >= 4 && moves <= 6) break;
    }
    best ??= _fallback();
    _cars.addAll(best);
    _hint = bestHint ?? _solve(_cars).$2;
    for (final c in _cars) {
      c.vis = c.pos.toDouble();
      c.face = randInt(3);
    }
  }

  List<_Car> _fallback() => [
        _Car(_exitRow, 0, 2, true, Pal.red),
        _Car(0, 2, 3, false, _colors[0]),
        _Car(1, 4, 2, false, _colors[1]),
        _Car(4, 0, 3, true, _colors[2]),
        _Car(3, 4, 2, true, _colors[3]),
        _Car(0, 5, 2, false, _colors[4]),
      ];

  List<_Car>? _randomLot() {
    final grid = List.filled(_n * _n, false);
    final cars = <_Car>[_Car(_exitRow, randInt(2), 2, true, Pal.red)];
    grid[_exitRow * _n + cars[0].col] = true;
    grid[_exitRow * _n + cars[0].col + 1] = true;
    final want = 7 + randInt(4);
    final cols = List.of(_colors)..shuffle(host.rng);
    var tries = 0;
    while (cars.length < want && tries < 200) {
      tries++;
      final horiz = chance(.45);
      final len = chance(.25) ? 3 : 2;
      final r = randInt(horiz ? _n : _n - len + 1);
      final c = randInt(horiz ? _n - len + 1 : _n);
      if (horiz && r == _exitRow) continue; // would block forever
      var ok = true;
      for (var k = 0; k < len; k++) {
        final rr = horiz ? r : r + k, cc = horiz ? c + k : c;
        if (grid[rr * _n + cc]) ok = false;
      }
      if (!ok) continue;
      for (var k = 0; k < len; k++) {
        final rr = horiz ? r : r + k, cc = horiz ? c + k : c;
        grid[rr * _n + cc] = true;
      }
      cars.add(_Car(r, c, len, horiz, cols[cars.length % cols.length]));
    }
    // the red car's lane must be blocked by at least two cars
    var blockers = 0;
    for (var cc = cars[0].col + 2; cc < _n; cc++) {
      if (grid[_exitRow * _n + cc]) blockers++;
    }
    return blockers >= 2 ? cars : null;
  }

  /// BFS over slide moves. Returns (moves, first move) or (-1, null).
  static (int, (int, int)?) _solve(List<_Car> cars) {
    final start = [for (final c in cars) c.pos];
    int enc(List<int> s) {
      var k = 0;
      for (final v in s) {
        k = k * 6 + v;
      }
      return k;
    }

    final seen = HashSet<int>()..add(enc(start));
    final q = Queue<(List<int>, int, (int, int)?)>()..add((start, 0, null));
    final grid = List.filled(36, -1);
    while (q.isNotEmpty) {
      final (s, d, first) = q.removeFirst();
      if (s[0] == _n - 2) return (d, first);
      if (seen.length > 40000) break;
      grid.fillRange(0, 36, -1);
      for (var i = 0; i < cars.length; i++) {
        final c = cars[i];
        for (var k = 0; k < c.len; k++) {
          final r = c.horiz ? c.row : s[i] + k;
          final cc = c.horiz ? s[i] + k : c.col;
          grid[r * _n + cc] = i;
        }
      }
      for (var i = 0; i < cars.length; i++) {
        final c = cars[i];
        for (final dir in const [-1, 1]) {
          var p = s[i];
          while (true) {
            final np = p + dir;
            if (np < 0 || np + c.len > _n) break;
            final cell = dir > 0 ? np + c.len - 1 : np;
            final idx = c.horiz ? c.row * _n + cell : cell * _n + c.col;
            if (grid[idx] != -1) break;
            p = np;
            final ns = List.of(s)..[i] = p;
            final k = enc(ns);
            if (seen.add(k)) q.add((ns, d + 1, first ?? (i, p)));
          }
        }
      }
    }
    return (-1, null);
  }

  // --------------------------------------------------------------- logic ---
  bool _occupied(int r, int c, _Car except) {
    for (final car in _cars) {
      if (identical(car, except)) continue;
      for (var k = 0; k < car.len; k++) {
        final rr = car.horiz ? car.row : car.pos + k;
        final cc = car.horiz ? car.pos + k : car.col;
        if (rr == r && cc == c) return true;
      }
    }
    return false;
  }

  _Car? _carAt(int r, int c, _Car except) {
    for (final car in _cars) {
      if (identical(car, except)) continue;
      for (var k = 0; k < car.len; k++) {
        final rr = car.horiz ? car.row : car.pos + k;
        final cc = car.horiz ? car.pos + k : car.col;
        if (rr == r && cc == c) return car;
      }
    }
    return null;
  }

  (int, int) _range(_Car car) {
    var lo = car.pos, hi = car.pos;
    bool free(int cell) => car.horiz ? !_occupied(car.row, cell, car) : !_occupied(cell, car.col, car);
    while (lo - 1 >= 0 && free(lo - 1)) {
      lo--;
    }
    while (hi + car.len < _n && free(hi + car.len)) {
      hi++;
    }
    return (lo, hi);
  }

  Rect _rectOf(_Car c, double pos) {
    const pad = 4.0;
    return c.horiz
        ? Rect.fromLTWH(_ox + pos * _cell + pad, _oy + c.row * _cell + pad, c.len * _cell - pad * 2, _cell - pad * 2)
        : Rect.fromLTWH(_ox + c.col * _cell + pad, _oy + pos * _cell + pad, _cell - pad * 2, c.len * _cell - pad * 2);
  }

  @override
  void onDown(Offset p) {
    if (_exiting) return;
    for (final c in _cars) {
      if (_rectOf(c, c.vis).inflate(4).contains(p)) {
        _drag = c;
        _grab = (c.horiz ? p.dx - _ox : p.dy - _oy) / _cell - c.vis;
        final (lo, hi) = _range(c);
        _lo = lo.toDouble();
        _hi = hi.toDouble();
        // red car can leave through the exit when its lane is clear
        if (identical(c, _red) && hi == _n - 2) _hi = _n + 3.0;
        _bumped = false;
        c.lift = 1;
        host.sfx(Sfx.tap, volume: .6, rate: 1.2);
        return;
      }
    }
  }

  @override
  void onMove(Offset p) {
    final c = _drag;
    if (c == null) return;
    final want = (c.horiz ? p.dx - _ox : p.dy - _oy) / _cell - _grab;
    final v = want.clamp(_lo, _hi);
    if (!_bumped && (want - v).abs() > .25) {
      _bumped = true;
      final dir = want > v ? 1 : -1;
      final cell = dir > 0 ? v.round() + c.len : v.round() - 1;
      final other = c.horiz ? _carAt(c.row, cell, c) : _carAt(cell, c.col, c);
      host.sfx(Sfx.beep, volume: .7, rate: .55);
      host.sfx(Sfx.thud, volume: .5);
      host.shake(3);
      c.bump = dir.toDouble();
      if (other != null) {
        other.shake = 1;
        other.angry = 1.2;
        final r = _rectOf(other, other.vis);
        host.fx.pop('!?', r.center - const Offset(0, 20), color: Pal.red, size: 22, life: .6);
      } else {
        final r = _rectOf(c, v);
        host.fx.burst(dir > 0 ? (c.horiz ? r.centerRight : r.bottomCenter) : (c.horiz ? r.centerLeft : r.topCenter),
            Pal.white, count: 6, speed: 120, size: 4);
      }
    }
    if ((want - v).abs() < .1) _bumped = false;
    c.vis = v;
    if (identical(c, _red) && v > _n - 2 + .6) _startExit();
  }

  @override
  void onUp(Offset p) {
    final c = _drag;
    if (c == null) return;
    _drag = null;
    c.lift = 0;
    if (identical(c, _red) && c.vis > _n - 2 + .3 && _hi > _n) {
      _startExit();
      return;
    }
    final np = c.vis.round().clamp(_lo.round(), min(_hi, (_n - c.len).toDouble()).round());
    if (np != c.pos) {
      _moves++;
      _hint = null;
      host.sfx(Sfx.click, rate: 1 + _moves * .04);
      host.addScore(5);
    }
    c.pos = np;
  }

  void _startExit() {
    if (_exiting) return;
    _exiting = true;
    _drag = null;
    _red.lift = 0;
    _exitV = 6;
    host.sfx(Sfx.engine);
    host.sfx(Sfx.beep, rate: 1.4);
    host.fx.pop(host.tr('goal', 'GOAL!'), const Offset(180, 150), color: Pal.yellow, size: 40, life: 1.2);
    host.punch(.04);
    final t = host.time;
    host.addScore(max(50, (200 - t * 8).round()), const Offset(290, 200));
    host.win(stars: t < 9 ? 3 : (t < 15 ? 2 : 1));
  }

  @override
  void onKey(String key, bool down) {
    if (!down || _exiting) return;
    if (key == 'right' || key == 'action') {
      final (_, hi) = _range(_red);
      if (hi == _n - 2) {
        _startExit();
      } else if (hi > _red.pos) {
        _red.pos = hi;
      }
    }
  }

  // -------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    for (final c in _cars) {
      if (!identical(c, _drag) && !(identical(c, _red) && _exiting)) {
        c.vis = M.approach(c.vis, c.pos.toDouble(), 18, dt);
      }
      c.shake = M.approach(c.shake, 0, 6, dt);
      c.bump = M.approach(c.bump, 0, 8, dt);
      c.liftV = M.approach(c.liftV, c.lift, 14, dt);
      c.angry = max(0, c.angry - dt);
    }
    if (_exiting) {
      _exitV += dt * 40;
      _red.vis += _exitV * dt;
      _dust -= dt;
      if (_dust <= 0 && _red.vis < _n + 4) {
        _dust = .04;
        final r = _rectOf(_red, _red.vis);
        host.fx.smoke(r.centerLeft, count: 2, color: const Color(0xCCE8E0D0), size: 18);
        if (chance(.4)) host.fx.sparkle(r.centerLeft, count: 1, radius: 6, color: Pal.yellow);
      }
    }
  }

  // -------------------------------------------------------------- render ---
  @override
  void render(Canvas c) {
    // grass
    D.gradientBg(c, const [Color(0xFF7ED957), Color(0xFF4CAF50)]);
    final tuft = D.stroke(const Color(0x3325662B), 2);
    for (var i = 0; i < 40; i++) {
      final x = (i * 97.0) % 360, y = 40 + (i * 53.0) % 600;
      c.drawLine(Offset(x, y), Offset(x - 3, y - 6), tuft);
      c.drawLine(Offset(x + 4, y), Offset(x + 5, y - 7), tuft);
    }
    // exit road
    final roadY = _oy + _exitRow * _cell;
    c.drawRect(Rect.fromLTWH(_ox + _n * _cell, roadY - 6, 60, _cell + 12), D.fill(const Color(0xFF5A5570)));
    for (var x = _ox + _n * _cell + 6; x < 360; x += 22) {
      c.drawRect(Rect.fromLTWH(x, roadY + _cell / 2 - 2, 12, 4), D.fill(const Color(0xFFFFD23F)));
    }
    // trees & bushes around
    for (final (o, s) in const [
      (Offset(40, 120), 26.0), (Offset(95, 100), 20.0), (Offset(300, 110), 28.0), (Offset(250, 150), 16.0),
      (Offset(50, 560), 26.0), (Offset(120, 590), 20.0), (Offset(290, 570), 30.0), (Offset(215, 600), 16.0),
    ]) {
      D.shadow(c, o + Offset(4, s * .6), s * 2, s * .8, .2);
      c.drawCircle(o, s, D.fill(const Color(0xFF2E8B3E)));
      c.drawCircle(o - Offset(s * .25, s * .25), s * .7, D.fill(const Color(0xFF3FAE50)));
      c.drawCircle(o - Offset(s * .4, s * .4), s * .3, D.fill(const Color(0x55FFFFFF)));
      c.drawCircle(o, s, D.stroke(Pal.ink, 2.5));
    }
    // lot
    const lot = Rect.fromLTWH(_ox, _oy, _cell * _n, _cell * _n);
    D.rrect(c, lot.inflate(12), 16, const Color(0xFFBDB6CC), border: Pal.ink, borderWidth: 4);
    D.rrect(c, lot.inflate(2), 6, const Color(0xFF4A4560));
    // exit gap in the curb
    c.drawRect(Rect.fromLTWH(_ox + _n * _cell - 1, roadY + 1, 16, _cell - 2), D.fill(const Color(0xFF4A4560)));
    // stall lines
    final line = D.stroke(const Color(0x55FFFFFF), 2);
    for (var i = 1; i < _n; i++) {
      for (var j = 0; j < _n; j++) {
        final x = _ox + i * _cell;
        final y = _oy + j * _cell;
        c.drawLine(Offset(x, y + 10), Offset(x, y + _cell - 10), line);
        c.drawLine(Offset(_ox + j * _cell + 10, _oy + i * _cell), Offset(_ox + j * _cell + _cell - 10, _oy + i * _cell), line);
      }
    }
    // exit lane glow & arrows
    final glow = .25 + .2 * M.wave(_t, 1.5);
    c.drawRect(Rect.fromLTWH(_ox, roadY + 2, _cell * _n, _cell - 4), D.fill(Color.fromRGBO(255, 80, 100, glow * .5)));
    for (var i = 0; i < 3; i++) {
      final x = _ox + _n * _cell + 16 + ((_t * 30 + i * 18) % 54);
      D.arrow(c, Offset(x, roadY + _cell / 2), const Offset(1, 0), 16, Pal.yellow, width: 6);
    }
    // cars (dragged one on top)
    for (final car in _cars) {
      if (!identical(car, _drag)) _drawCar(c, car);
    }
    if (_drag != null) _drawCar(c, _drag!);
    // barrier arm at exit
    final open = _exiting ? 1.0 : 0.0;
    c.save();
    c.translate(_ox + _n * _cell + 14, roadY - 4);
    c.rotate(-open * 1.3);
    D.rrect(c, const Rect.fromLTWH(0, -3, 6, _cell + 8), 3, Pal.white, border: Pal.ink, borderWidth: 2);
    for (var i = 0; i < 3; i++) {
      c.drawRect(Rect.fromLTWH(1, 6 + i * 18.0, 4, 8), D.fill(Pal.red));
    }
    c.restore();
    c.drawCircle(Offset(_ox + _n * _cell + 17, roadY - 6), 6, D.fill(Pal.ink));

    // HUD
    D.rrect(c, const Rect.fromLTWH(118, 52, 124, 34), 17, const Color(0xCC1B1530), border: Pal.white, borderWidth: 2.5);
    D.text(c, '${host.tr('move', 'MOVE')} $_moves', const Offset(180, 69), size: 17, color: Pal.white, stroke: Pal.ink);
    // hint
    final h = _hint;
    if (h != null && host.time < 5 && _drag == null && !_exiting) {
      final car = _cars[h.$1];
      final r = _rectOf(car, car.vis);
      final dir = h.$2 > car.pos ? 1.0 : -1.0;
      final d = car.horiz ? Offset(dir, 0) : Offset(0, dir);
      final bob = M.wave(_t, 1.2);
      D.arrow(c, r.center + d * (20 + bob * 14), d, 40, Pal.yellow, width: 12);
      D.hand(c, r.center + d * bob * 26, _t);
    }
  }

  void _drawCar(Canvas c, _Car car) {
    var r = _rectOf(car, car.vis);
    final sh = sin(_t * 50) * car.shake * 3;
    r = r.shift(car.horiz ? Offset(sh + car.bump * 3, 0) : Offset(0, sh + car.bump * 3));
    final lift = car.liftV;
    c.save();
    c.translate(r.center.dx, r.center.dy);
    if (!car.horiz) c.rotate(pi / 2);
    c.scale(1 + lift * .06);
    final len = car.horiz ? r.width : r.height;
    final wid = car.horiz ? r.height : r.width;
    final body = Rect.fromCenter(center: Offset.zero, width: len, height: wid);
    // shadow
    c.drawRRect(RRect.fromRectAndRadius(body.shift(Offset(3 + lift * 4, 4 + lift * 5)), const Radius.circular(12)),
        D.fill(Color.fromRGBO(0, 0, 0, .25 + lift * .1)));
    // wheels
    final wheel = D.fill(const Color(0xFF222230));
    for (final fx in [-len / 2 + 12, len / 2 - 14]) {
      for (final fy in [-wid / 2 - 2, wid / 2 - 4]) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(fx - 6, fy, 12, 6), const Radius.circular(2)), wheel);
      }
    }
    final col = car.color;
    final dark = Color.lerp(col, Pal.ink, .35)!;
    final truck = car.len == 3;
    D.rrect(c, body, 12, col, border: Pal.ink, borderWidth: 3);
    if (truck && !identical(car, _red)) {
      // cargo box + cab
      final cargo = Rect.fromLTWH(-len / 2 + 4, -wid / 2 + 4, len * .62, wid - 8);
      D.rrect(c, cargo, 6, Color.lerp(col, Pal.white, .55)!, border: dark, borderWidth: 2);
      for (var i = 1; i < 4; i++) {
        final x = cargo.left + cargo.width * i / 4;
        c.drawLine(Offset(x, cargo.top + 4), Offset(x, cargo.bottom - 4), D.stroke(dark, 1.5));
      }
      final cab = Rect.fromLTWH(len / 2 - len * .3, -wid / 2 + 5, len * .16, wid - 10);
      D.rrect(c, cab, 4, const Color(0xFF9AD8FF), border: Pal.ink, borderWidth: 2);
    } else {
      // roof + windows
      final roof = Rect.fromCenter(center: Offset(-len * .04, 0), width: len * .46, height: wid - 12);
      D.rrect(c, Rect.fromCenter(center: Offset(len * .2, 0), width: len * .14, height: wid - 14), 4,
          const Color(0xFF9AD8FF), border: Pal.ink, borderWidth: 2);
      D.rrect(c, Rect.fromCenter(center: Offset(-len * .32, 0), width: len * .1, height: wid - 16), 3,
          const Color(0xFF7FB8E0), border: Pal.ink, borderWidth: 2);
      D.rrect(c, roof, 8, Color.lerp(col, Pal.white, .22)!, border: dark, borderWidth: 2);
      c.drawLine(Offset(roof.left + 6, roof.top + 4), Offset(roof.right - 10, roof.top + 4),
          D.stroke(const Color(0x66FFFFFF), 3));
    }
    // headlights / taillights
    for (final s in const [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(len / 2 - 4, s * (wid / 2 - 8)), width: 6, height: 9),
          D.fill(const Color(0xFFFFF3A0)));
      c.drawRect(Rect.fromCenter(center: Offset(-len / 2 + 3, s * (wid / 2 - 8)), width: 4, height: 8),
          D.fill(const Color(0xFFFF4040)));
    }
    if (identical(car, _red) && _exiting) {
      // headlight beams
      c.drawPath(
          Path()
            ..moveTo(len / 2, -wid / 2 + 8)
            ..lineTo(len / 2 + 60, -wid / 2 - 10)
            ..lineTo(len / 2 + 60, wid / 2 + 10)
            ..lineTo(len / 2, wid / 2 - 8)
            ..close(),
          D.fill(const Color(0x44FFF3A0)));
    }
    // cute eyes on the windshield side (face toward front)
    final angry = car.angry > 0;
    final eyeX = truck && !identical(car, _red) ? len / 2 - len * .22 : len * .2;
    for (final s in const [-1.0, 1.0]) {
      final e = Offset(eyeX, s * 7);
      c.drawCircle(e, 5, D.fill(Pal.white));
      c.drawCircle(e, 5, D.stroke(Pal.ink, 1.5));
      c.drawCircle(e + const Offset(1.5, 0), 2.4, D.fill(Pal.ink));
      if (angry) {
        c.drawLine(e + Offset(-5, s * -7), e + Offset(4, s * -3), D.stroke(Pal.ink, 2));
      }
    }
    if (identical(car, _red)) {
      // racing stripe + star badge
      c.drawLine(Offset(-len / 2 + 6, 0), Offset(-len * .32 - 8, 0), D.stroke(Pal.white, 4));
    }
    c.restore();
  }
}

class _Car {
  _Car(this.row, this.col, this.len, this.horiz, this.color);
  final int row, col, len;
  final bool horiz;
  final Color color;
  int get pos0 => horiz ? col : row;
  late int pos = pos0;
  double vis = 0;
  double shake = 0;
  double bump = 0;
  double lift = 0, liftV = 0;
  double angry = 0;
  int face = 0;
}
