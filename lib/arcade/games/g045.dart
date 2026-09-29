import '../engine/engine.dart';

/// No.045 Delivery Dash — top-down mini city. Orders pop up with timers; tap
/// pins to queue deliveries, the scooter pathfinds along the streets (and
/// waits at red lights). The bag holds 3 meals: it auto-refills at the shop.
class G045 extends MiniGame {
  static const _goal = 5;
  static const _cols = 11, _rows = 15;
  static const double _cs = 30, _x0 = 15, _y0 = 110;
  static const _roadCols = {0, 5, 10};
  static const _roadRows = {0, 4, 9, 14};
  static const _shop = (7, 4); // pickup road cell
  static const _lights = [(5, 4), (5, 9), (10, 9)];
  static const _dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];
  static const _roofs = [Color(0xFFFF6B6B), Color(0xFF5B8CFF), Color(0xFFFFB84D), Color(0xFF6BD06B), Color(0xFFB57BFF), Color(0xFF4DD0D0)];

  final _dests = <_Dest>[];
  final _orders = <_Order>[];
  final _queue = <Object>[]; // _Order or 'shop'
  final _route = <(int, int)>[];
  final _ratings = <_Rating>[];
  double _t = 0;
  int _sc = _shop.$1, _sr = _shop.$2;
  late Offset _pos;
  double _heading = 0;
  int _bag = 3;
  int _delivered = 0;
  int _fails = 0;
  final _starsGot = <int>[];
  double _orderT = 0;
  double _bump = 0;
  double _wait = 0;
  double _refill = 0;
  int _served = 0;

  bool _road(int c, int r) =>
      c >= 0 && r >= 0 && c < _cols && r < _rows && (_roadCols.contains(c) || _roadRows.contains(r));
  Offset _cc(int c, int r) => Offset(_x0 + c * _cs + _cs / 2, _y0 + r * _cs + _cs / 2);
  bool _isShopCell(int c, int r) => c >= 6 && c <= 9 && r >= 5 && r <= 6;

  @override
  void init() {
    _pos = _cc(_sc, _sr);
    const blocksC = [(1, 4), (6, 9)];
    const blocksR = [(1, 3), (5, 8), (10, 13)];
    var n = 0;
    for (final bc in blocksC) {
      for (final br in blocksR) {
        for (var c = bc.$1; c <= bc.$2; c++) {
          for (var r = br.$1; r <= br.$2; r++) {
            final edge = c == bc.$1 || c == bc.$2 || r == br.$1 || r == br.$2;
            if (!edge || _isShopCell(c, r)) continue;
            for (final d in _dirs) {
              if (_road(c + d.$1, r + d.$2)) {
                _dests.add(_Dest(c, r, c + d.$1, r + d.$2, _roofs[n++ % _roofs.length]));
                break;
              }
            }
          }
        }
      }
    }
    _newOrder();
    _newOrder();
    _orderT = 2.2;
  }

  void _newOrder() {
    final used = _orders.map((o) => o.dest).toSet();
    final opts = _dests
        .where((d) => !used.contains(d) && (d.rc - _shop.$1).abs() + (d.rr - _shop.$2).abs() >= 4)
        .toList();
    if (opts.isEmpty) return;
    final d = pick(opts);
    final life = rand(10.5, 12.5) / host.speed;
    _orders.add(_Order(d, life));
    host.sfx(Sfx.notify, volume: .6);
    host.fx.ring(_pin(d), Pal.red, size: 36);
  }

  Offset _pin(_Dest d) => _cc(d.hc, d.hr) + const Offset(0, -22);

  List<(int, int)>? _bfs(int sc, int sr, int tc, int tr) {
    final prev = List<int>.filled(_cols * _rows, -2);
    final q = <int>[sr * _cols + sc];
    prev[q.first] = -1;
    var head = 0;
    while (head < q.length) {
      final k = q[head++];
      final c = k % _cols, r = k ~/ _cols;
      if (c == tc && r == tr) {
        final out = <(int, int)>[];
        var cur = k;
        while (prev[cur] != -1) {
          out.add((cur % _cols, cur ~/ _cols));
          cur = prev[cur];
        }
        return out.reversed.toList();
      }
      for (final d in _dirs) {
        final nc = c + d.$1, nr = r + d.$2;
        if (!_road(nc, nr)) continue;
        final nk = nr * _cols + nc;
        if (prev[nk] != -2) continue;
        prev[nk] = k;
        q.add(nk);
      }
    }
    return null;
  }

  bool _red(int i) => ((_t + i * 1.1) % 3.2) < 1.2;

  (int, int) _targetCell(Object t) => t is _Order ? (t.dest.rc, t.dest.rr) : _shop;

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _bump = M.approach(_bump, 0, 8, dt);
    _refill = max(0, _refill - dt);
    for (final r in _ratings) {
      r.t += dt;
    }
    _ratings.removeWhere((r) => r.t > 1.4);
    if (host.finished) return;

    _orderT -= dt;
    if (_orderT <= 0) {
      _orderT = rand(2.4, 3.2) / host.speed;
      if (_orders.length < 3) _newOrder();
    }
    for (final o in _orders) {
      o.left -= dt;
      if (o.left <= 0) {
        o.dead = true;
        _fails++;
        _queue.remove(o);
        _ratings.add(_Rating(_pin(o.dest), 1));
        host.sfx(Sfx.wrong);
        host.sfx(Sfx.aww, volume: .5);
        host.shake(5);
        host.fx.pop(host.tr('late', 'LATE!'), _pin(o.dest) + const Offset(0, -26), color: Pal.red, size: 22);
        if (_fails >= 3) {
          host.sfx(Sfx.jingleLose);
          host.lose();
        }
      }
    }
    _orders.removeWhere((o) => o.dead);
    _drive(dt);
  }

  void _drive(double dt) {
    if (_route.isEmpty) {
      if (_queue.isEmpty) return;
      var next = _queue.first;
      if (next is _Order && _bag == 0) {
        _queue.insert(0, 'shop');
        next = 'shop';
      }
      final (tc, tr) = _targetCell(next);
      if (tc == _sc && tr == _sr) {
        _arrive(next);
        return;
      }
      _route.addAll(_bfs(_sc, _sr, tc, tr) ?? const []);
      if (_route.isEmpty) _queue.removeAt(0);
      return;
    }
    final (nc, nr) = _route.first;
    // red light: wait before entering an intersection
    final li = _lights.indexOf((nc, nr));
    final atCell = (_pos - _cc(_sc, _sr)).distance < 1;
    if (li >= 0 && atCell && _red(li)) {
      _wait += dt;
      return;
    }
    _wait = 0;
    final target = _cc(nc, nr);
    final d = target - _pos;
    final step = 175 * host.speed * dt;
    if (d.distance > .01) _heading = atan2(d.dy, d.dx);
    if (d.distance <= step) {
      _pos = target;
      _sc = nc;
      _sr = nr;
      _route.removeAt(0);
      if (_route.isEmpty && _queue.isNotEmpty) {
        final t = _queue.first;
        final (tc, tr) = _targetCell(t);
        if (tc == _sc && tr == _sr) _arrive(t);
      }
    } else {
      _pos += d / d.distance * step;
    }
  }

  void _arrive(Object t) {
    _queue.remove(t);
    if (t is _Order) {
      if (_bag <= 0) {
        _queue.insert(0, t);
        _queue.insert(0, 'shop');
        return;
      }
      _bag--;
      _orders.remove(t);
      _delivered++;
      _served++;
      _bump = 1;
      final frac = t.left / t.life;
      final stars = frac > .45 ? 5 : (frac > .2 ? 4 : 3);
      _starsGot.add(stars);
      final at = _pin(t.dest);
      _ratings.add(_Rating(at, stars));
      host.addScore(stars * 20, at + const Offset(0, 20));
      host.sfx(Sfx.cash);
      host.sfx(stars == 5 ? Sfx.perfect : Sfx.correct, volume: .6, rate: 1 + _served * .05);
      host.fx.burst(at, Pal.yellow, count: 16, speed: 220, size: 7, shape: PartShape.star, colors: const [Pal.yellow, Pal.gold, Pal.white]);
      host.fx.coins(at, count: 8, speed: 260);
      host.punch(.02);
      if (_delivered >= _goal) {
        final avg = _starsGot.reduce((a, b) => a + b) / _starsGot.length;
        host.sfx(Sfx.fanfare);
        host.fx.confetti(count: 90);
        host.fx.pop(host.tr('delivered', 'DELIVERED!'), const Offset(180, 300), color: Pal.yellow, size: 36, life: 1.3);
        host.win(stars: _fails == 0 && avg >= 4.5 ? 3 : (_fails <= 1 ? 2 : 1));
      }
    } else {
      if (_bag < 3) {
        _bag = 3;
        _refill = .8;
        host.sfx(Sfx.pickup);
        host.sfx(Sfx.bell, volume: .5);
        host.fx.pop('+3', _cc(_shop.$1, _shop.$2) + const Offset(0, -24), color: Pal.lime, size: 22);
      }
    }
  }

  // ------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    _Order? best;
    var bd = 26.0;
    for (final o in _orders) {
      final d = min((_pin(o.dest) - p).distance, (_cc(o.dest.hc, o.dest.hr) - p).distance);
      if (d < bd) {
        bd = d;
        best = o;
      }
    }
    if (best != null) {
      if (!_queue.contains(best)) {
        _queue.add(best);
        best.bump = 1;
        host.sfx(Sfx.select, rate: 1 + _queue.length * .1);
        host.fx.ring(_pin(best.dest), Pal.white, size: 30, life: .3);
      }
      return;
    }
    final shopC = Offset(_x0 + 8 * _cs, _y0 + 6 * _cs);
    if ((p - shopC).distance < 60 && !_queue.contains('shop') && _bag < 3) {
      _queue.add('shop');
      host.sfx(Sfx.select);
    }
  }

  @override
  void onTimeUp() {
    if (_delivered >= _goal) {
      host.win(stars: 1);
    } else {
      host.sfx(Sfx.jingleLose);
      host.lose();
    }
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF7BCB5A), Color(0xFF5DAE48)]);
    // blocks: sidewalks
    const blocksC = [(1, 4), (6, 9)];
    const blocksR = [(1, 3), (5, 8), (10, 13)];
    for (final bc in blocksC) {
      for (final br in blocksR) {
        final r = Rect.fromLTRB(_x0 + bc.$1 * _cs, _y0 + br.$1 * _cs, _x0 + (bc.$2 + 1) * _cs, _y0 + (br.$2 + 1) * _cs);
        D.rrect(c, r.inflate(2), 8, const Color(0xFFE2DCCD));
        D.rrect(c, r.deflate(3), 6, const Color(0xFF86D06A));
      }
    }
    // roads
    final roadP = D.fill(const Color(0xFF4A4E5E));
    for (var r = 0; r < _rows; r++) {
      for (var col = 0; col < _cols; col++) {
        if (_road(col, r)) c.drawRect(Rect.fromLTWH(_x0 + col * _cs, _y0 + r * _cs, _cs + .5, _cs + .5), roadP);
      }
    }
    final dash = D.stroke(const Color(0xAAFFE27A), 2);
    for (final rr in _roadRows) {
      final y = _y0 + rr * _cs + _cs / 2;
      for (var x = _x0; x < _x0 + _cols * _cs; x += 16) {
        if (!_roadCols.any((cc) => (x - (_x0 + cc * _cs)).abs() < _cs && x >= _x0 + cc * _cs)) {
          c.drawLine(Offset(x, y), Offset(x + 7, y), dash);
        }
      }
    }
    for (final cc in _roadCols) {
      final x = _x0 + cc * _cs + _cs / 2;
      for (var y = _y0; y < _y0 + _rows * _cs; y += 16) {
        if (!_roadRows.any((rr) => y >= _y0 + rr * _cs - 2 && y < _y0 + (rr + 1) * _cs)) {
          c.drawLine(Offset(x, y), Offset(x, y + 7), dash);
        }
      }
    }
    // interior decoration: trees & pools
    for (final bc in blocksC) {
      for (final br in blocksR) {
        for (var col = bc.$1 + 1; col < bc.$2; col++) {
          for (var r = br.$1 + 1; r < br.$2; r++) {
            if (_isShopCell(col, r)) continue;
            final ctr = _cc(col, r);
            if ((col + r) % 3 == 0) {
              D.rrect(c, Rect.fromCenter(center: ctr, width: 24, height: 18), 7, const Color(0xFF4FC8F0), border: Pal.ink, borderWidth: 2);
            } else {
              D.circle(c, ctr + const Offset(1, 3), 11, const Color(0x33000000));
              D.circle(c, ctr, 11, const Color(0xFF2E9E4A), border: Pal.ink, borderWidth: 2);
              D.circle(c, ctr + const Offset(-3, -3), 4, const Color(0xFF6BD06B));
            }
          }
        }
      }
    }
    // houses
    for (final d in _dests) {
      final ctr = _cc(d.hc, d.hr);
      final ordered = _orders.any((o) => o.dest == d);
      D.rrect(c, Rect.fromCenter(center: ctr + const Offset(2, 3), width: 26, height: 24), 4, const Color(0x44000000));
      D.rrect(c, Rect.fromCenter(center: ctr, width: 26, height: 24), 4, ordered ? Pal.yellow : d.roof, border: Pal.ink, borderWidth: 2);
      c.drawLine(ctr + const Offset(-11, 0), ctr + const Offset(11, 0), D.stroke(const Color(0x55000000), 2));
      final door = ctr + Offset((d.rc - d.hc) * 12.0, (d.rr - d.hr) * 11.0);
      c.drawCircle(door, 3, D.fill(const Color(0xFF7A4A24)));
    }
    _restaurant(c);
    // traffic lights
    for (var i = 0; i < _lights.length; i++) {
      final (lc, lr) = _lights[i];
      final p = Offset(_x0 + lc * _cs - 4, _y0 + lr * _cs - 4);
      D.rrect(c, Rect.fromCenter(center: p, width: 12, height: 22), 4, Pal.ink);
      final red = _red(i);
      D.circle(c, p + const Offset(0, -5), 4, red ? Pal.red : const Color(0xFF552222));
      D.circle(c, p + const Offset(0, 5), 4, red ? const Color(0xFF225522) : Pal.lime);
    }
    // ambient cars
    for (var i = 0; i < 3; i++) {
      final len = _cols * _cs;
      final x = _x0 + ((_t * (70 + i * 25) + i * 110) % (len + 40)) - 20;
      final y = _y0 + [0, 9, 14][i] * _cs + _cs / 2 + (i.isEven ? -6 : 6);
      _car(c, Offset(i.isEven ? x : _x0 + len - (x - _x0), y), i.isEven ? 0 : pi, Pal.candy[i * 2 + 1]);
    }
    // route
    if (_route.isNotEmpty) {
      final pts = [_pos, for (final (rc, rr) in _route) _cc(rc, rr)];
      final dp = D.fill(const Color(0xDDFFFFFF));
      for (var i = 0; i < pts.length - 1; i++) {
        final a = pts[i], b = pts[i + 1];
        final n = max(1, ((b - a).distance / 10).floor());
        for (var k = 0; k < n; k++) {
          final ph = (k / n + _t * 2) % 1;
          c.drawCircle(Offset.lerp(a, b, (k + ph) / n)!, 2.5, dp);
        }
      }
    }
    // pins
    for (final o in _orders) {
      _pinDraw(c, o);
    }
    // scooter
    _scooter(c);
    // ratings
    for (final r in _ratings) {
      final k = r.t / 1.4;
      final pos = r.at + Offset(0, -30 - k * 40);
      final a = k > .7 ? (1 - k) / .3 : 1.0;
      for (var i = 0; i < 5; i++) {
        final on = i < r.n;
        D.star(c, pos + Offset(-32 + i * 16.0, 0), 8 * (k < .15 ? k / .15 : 1),
            on ? Color.fromRGBO(255, 200, 60, a) : Color.fromRGBO(120, 120, 140, a * .7), border: Color.fromRGBO(27, 21, 48, a));
      }
    }
    _hud(c);
    // tutorial
    if (!host.finished && _queue.isEmpty && _delivered == 0 && host.time < 4 && _orders.isNotEmpty) {
      D.hand(c, _pin(_orders.first.dest) + const Offset(0, 6), _t);
    }
  }

  void _restaurant(Canvas c) {
    final r = Rect.fromLTRB(_x0 + 6 * _cs + 2, _y0 + 5 * _cs + 2, _x0 + 10 * _cs - 2, _y0 + 7 * _cs - 2);
    D.rrect(c, r.shift(const Offset(3, 4)), 8, const Color(0x44000000));
    D.rrect(c, r, 8, const Color(0xFFFFF4DC), border: Pal.ink, borderWidth: 3);
    // awning stripes (top side faces the road)
    for (var i = 0; i < 8; i++) {
      c.drawRect(Rect.fromLTWH(r.left + i * r.width / 8, r.top, r.width / 8, 12), D.fill(i.isEven ? Pal.red : Pal.white));
    }
    c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 12), D.stroke(Pal.ink, 2));
    // pizza sign
    final s = 1 + (_refill > 0 ? sin(_refill * 20) * .1 : 0.0);
    c.save();
    c.translate(r.center.dx, r.center.dy + 6);
    c.scale(s);
    final slice = Path()
      ..moveTo(-16, -14)
      ..quadraticBezierTo(0, -22, 16, -14)
      ..lineTo(0, 18)
      ..close();
    c.drawPath(slice, D.fill(const Color(0xFFFFD760)));
    c.drawPath(slice, D.stroke(Pal.ink, 2.5));
    for (final o in const [Offset(-6, -8), Offset(5, -6), Offset(0, 4)]) {
      c.drawCircle(o, 3.2, D.fill(Pal.red));
    }
    c.restore();
    // pickup marker
    final pc = _cc(_shop.$1, _shop.$2);
    c.drawCircle(pc, 12 + sin(_t * 5) * 2, D.stroke(const Color(0x88FFFFFF), 3));
  }

  void _pinDraw(Canvas c, _Order o) {
    final base = _pin(o.dest);
    o.bump = max(0, o.bump - .05);
    final frac = (o.left / o.life).clamp(0.0, 1.0);
    final urgent = frac < .3;
    final bob = sin(_t * 5 + o.dest.hc) * 3 - sin(o.bump * pi) * 8;
    final p = base + Offset(0, bob);
    final path = Path()
      ..moveTo(p.dx - 7, p.dy + 10)
      ..lineTo(p.dx, p.dy + 22)
      ..lineTo(p.dx + 7, p.dy + 10)
      ..close();
    final col = urgent && (_t * 8).floor().isEven ? Pal.red : (urgent ? Pal.orange : Pal.white);
    c.drawPath(path, D.fill(col));
    c.drawPath(path, D.stroke(Pal.ink, 2));
    D.circle(c, p, 16, col, border: Pal.ink, borderWidth: 2.5);
    c.drawArc(Rect.fromCircle(center: p, radius: 12), -pi / 2, pi * 2 * frac, false,
        D.stroke(frac > .5 ? Pal.green : (frac > .25 ? Pal.orange : Pal.red), 4));
    // meal box icon
    D.rrect(c, Rect.fromCenter(center: p, width: 11, height: 9), 2, const Color(0xFFC8864A), border: Pal.ink, borderWidth: 1.5);
    final qi = _queue.indexOf(o);
    if (qi >= 0) {
      D.circle(c, p + const Offset(14, -13), 9, Pal.blue, border: Pal.ink, borderWidth: 2);
      D.text(c, '${_queue.whereType<_Order>().toList().indexOf(o) + 1}', p + const Offset(14, -13), size: 12);
    }
  }

  void _car(Canvas c, Offset p, double a, Color col) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(a);
    D.rrect(c, const Rect.fromLTWH(-12, -7, 24, 14), 5, col, border: Pal.ink, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(-2, -5, 8, 10), 2, const Color(0xFFBFE8FF));
    c.restore();
  }

  void _scooter(Canvas c) {
    final moving = _route.isNotEmpty && _wait == 0;
    final wob = moving ? sin(_t * 30) * 1 : 0.0;
    c.save();
    c.translate(_pos.dx, _pos.dy + wob);
    c.rotate(_heading);
    D.shadow(c, const Offset(2, 4), 34, 18, .3);
    // exhaust
    if (moving && (_t * 10).floor().isEven) {
      c.drawCircle(const Offset(-22, 0), 4, D.fill(const Color(0x88FFFFFF)));
    }
    D.rrect(c, const Rect.fromLTWH(-15, -6, 30, 12), 6, Pal.red, border: Pal.ink, borderWidth: 2.5);
    // delivery box on back
    D.rrect(c, const Rect.fromLTWH(-16, -9, 13, 18), 3, const Color(0xFFFFC53D), border: Pal.ink, borderWidth: 2);
    // rider helmet
    D.circle(c, const Offset(3, 0), 7, Pal.white, border: Pal.ink, borderWidth: 2);
    c.drawArc(Rect.fromCircle(center: const Offset(3, 0), radius: 5), -pi / 2, pi, false, D.stroke(Pal.sky, 3));
    // handlebar
    c.drawLine(const Offset(12, -8), const Offset(12, 8), D.stroke(Pal.ink, 3));
    c.restore();
    if (_wait > .05) {
      D.text(c, '...', _pos + const Offset(0, -22), size: 16, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
    }
  }

  void _hud(Canvas c) {
    D.rrect(c, const Rect.fromLTWH(10, 44, 340, 56), 18, const Color(0xEE1B1530), border: Pal.ink, borderWidth: 3);
    final s = 1 + _bump * .3;
    c.save();
    c.translate(40, 72);
    c.scale(s);
    D.rrect(c, const Rect.fromLTWH(-13, -11, 26, 22), 4, const Color(0xFFC8864A), border: Pal.ink, borderWidth: 2.5);
    c.restore();
    D.text(c, '$_delivered/$_goal', const Offset(98, 72), size: 28, color: _delivered >= _goal ? Pal.lime : Pal.white,
        stroke: Pal.ink, strokeWidth: 5);
    // bag
    for (var i = 0; i < 3; i++) {
      final on = i < _bag;
      final p = Offset(178 + i * 26.0, 72);
      D.rrect(c, Rect.fromCenter(center: p, width: 20, height: 18), 4, on ? const Color(0xFFFFC53D) : const Color(0xFF3A3450),
          border: Pal.ink, borderWidth: 2);
    }
    // fails
    for (var i = 0; i < 3; i++) {
      final p = Offset(276 + i * 24.0, 72);
      D.circle(c, p, 9, i < _fails ? Pal.red : const Color(0xFF3A3450), border: Pal.ink, borderWidth: 2);
      if (i < _fails) D.face(c, p, 8, Face.angry, blush: false);
    }
    // bottom strip
    D.rrect(c, const Rect.fromLTWH(10, 574, 340, 52), 18, const Color(0xCC1B1530));
    if (_bag == 0) {
      D.text(c, host.tr('refill', 'REFILL!'), const Offset(180, 600), size: 22, color: Pal.orange, stroke: Pal.ink, strokeWidth: 5);
    } else {
      for (var i = 0; i < _starsGot.length && i < 5; i++) {
        D.text(c, '${_starsGot[i]}', Offset(62 + i * 60.0, 600), size: 20, color: Pal.gold, stroke: Pal.ink, strokeWidth: 4);
        D.star(c, Offset(84 + i * 60.0, 600), 10, Pal.gold, border: Pal.ink);
      }
    }
  }
}

class _Dest {
  _Dest(this.hc, this.hr, this.rc, this.rr, this.roof);
  final int hc, hr, rc, rr;
  final Color roof;
}

class _Order {
  _Order(this.dest, this.life) : left = life;
  final _Dest dest;
  final double life;
  double left;
  bool dead = false;
  double bump = 0;
}

class _Rating {
  _Rating(this.at, this.n);
  final Offset at;
  final int n;
  double t = 0;
}
