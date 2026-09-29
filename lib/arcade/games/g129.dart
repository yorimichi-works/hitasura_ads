import '../engine/engine.dart';

/// No.129 Candy Match 3 — 7x7 match-3 with cascades, striped / wrapped /
/// color-bomb specials. Goal: collect the red candies before the ad ends.
class G129 extends MiniGame {
  static const _n = 7;
  static const _cell = 46.0;
  static const _bx = 19.0;
  static const _by = 172.0;
  static const _target = 16;
  static const _goalPos = Offset(128, 98);

  static const _cols = <Color>[
    Color(0xFFFF3552), // red (goal)
    Color(0xFFFF9A1F), // orange
    Color(0xFF3CCB4C), // green
    Color(0xFF3D8BFF), // blue
    Color(0xFFB04DFF), // purple
  ];
  static final _shapes = <Path>[
    Path()..addOval(const Rect.fromLTWH(-1, -1, 2, 2)),
    Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-.86, -.86, 1.72, 1.72), const Radius.circular(.42))),
    Path()
      ..moveTo(0, -1.08)
      ..quadraticBezierTo(.25, -.3, 1.02, 0)
      ..quadraticBezierTo(.25, .3, 0, 1.08)
      ..quadraticBezierTo(-.25, .3, -1.02, 0)
      ..quadraticBezierTo(-.25, -.3, 0, -1.08)
      ..close(),
    Path()
      ..moveTo(0, -1.1)
      ..cubicTo(.35, -.55, .95, -.05, .9, .35)
      ..cubicTo(.85, .85, .45, 1.0, 0, 1.0)
      ..cubicTo(-.45, 1.0, -.85, .85, -.9, .35)
      ..cubicTo(-.95, -.05, -.35, -.55, 0, -1.1)
      ..close(),
    _hexPath(),
  ];

  static Path _hexPath() {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3 + pi / 6;
      final o = Offset(cos(a) * 1.02, sin(a) * 1.02);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  final List<_Candy?> _g = List<_Candy?>.filled(_n * _n, null);
  _Ph _ph = _Ph.idle;
  double _phT = 0;
  double _t = 0;
  int _swapA = -1, _swapB = -1;
  int _sel = -1;
  int _downCell = -1;
  Offset _downPos = Offset.zero;
  bool _swiped = false;
  int _cascade = 0;
  int _collected = 0;
  int _shown = 0;
  double _goalBump = 0;
  double _idle = 0;
  (int, int)? _hint;
  String _word = '';
  Color _wordCol = Pal.yellow;
  double _wordT = 9;
  double _mascotSquash = 1;
  Face _mascotFace = Face.happy;
  double _faceT = 0;
  final List<_Beam> _beams = [];
  final List<_Zap> _zaps = [];
  final List<_Fly> _flies = [];
  Set<int> _clearing = {};
  Map<int, int> _creating = {};

  // ------------------------------------------------------------ setup ---

  int _randColor() {
    // red is slightly more common so the goal feels reachable
    final r = rng.nextDouble() * 5.25;
    if (r < 1.25) return 0;
    return 1 + ((r - 1.25) ~/ 1.0).clamp(0, 3);
  }

  @override
  void init() {
    host.showScore = true;
    for (var tries = 0; tries < 40; tries++) {
      for (var i = 0; i < _n * _n; i++) {
        _g[i] = null;
      }
      for (var i = 0; i < _n * _n; i++) {
        final r = i ~/ _n;
        var col = _randColor();
        var guard = 0;
        while (_wouldRun(i, col) && guard++ < 20) {
          col = _randColor();
        }
        _g[i] = _Candy(col)
          ..x = (i % _n).toDouble()
          ..y = r - _n - 1.0 + r * .15;
      }
      if (_findHint() != null) break;
    }
    _ph = _Ph.fall;
  }

  bool _wouldRun(int i, int col) {
    final r = i ~/ _n, c = i % _n;
    if (c >= 2 && _colorAt(i - 1) == col && _colorAt(i - 2) == col) return true;
    if (r >= 2 && _colorAt(i - _n) == col && _colorAt(i - 2 * _n) == col) return true;
    return false;
  }

  int _colorAt(int i) {
    final cd = _g[i];
    if (cd == null || cd.die >= 0) return -1;
    return cd.color;
  }

  // ------------------------------------------------------------ input ---

  int _cellAt(Offset p) {
    final c = ((p.dx - _bx) / _cell).floor();
    final r = ((p.dy - _by) / _cell).floor();
    if (c < 0 || r < 0 || c >= _n || r >= _n) return -1;
    return r * _n + c;
  }

  bool _adj(int a, int b) {
    final ra = a ~/ _n, ca = a % _n, rb = b ~/ _n, cb = b % _n;
    return (ra - rb).abs() + (ca - cb).abs() == 1;
  }

  @override
  void onDown(Offset p) {
    _downCell = _cellAt(p);
    _downPos = p;
    _swiped = false;
    if (_downCell >= 0 && _ph == _Ph.idle) {
      _g[_downCell]?.wob = 1;
      host.sfx(Sfx.tap, volume: .35, rate: 1.3);
    }
  }

  @override
  void onMove(Offset p) {
    if (_downCell < 0 || _swiped) return;
    final d = p - _downPos;
    if (d.distance < 16) return;
    _swiped = true;
    final r = _downCell ~/ _n, c = _downCell % _n;
    int tr = r, tc = c;
    if (d.dx.abs() > d.dy.abs()) {
      tc += d.dx > 0 ? 1 : -1;
    } else {
      tr += d.dy > 0 ? 1 : -1;
    }
    if (tr < 0 || tc < 0 || tr >= _n || tc >= _n) return;
    _trySwap(_downCell, tr * _n + tc);
  }

  @override
  void onUp(Offset p) {
    if (!_swiped && _downCell >= 0 && _ph == _Ph.idle) {
      if (_sel >= 0 && _adj(_sel, _downCell)) {
        _trySwap(_sel, _downCell);
      } else {
        _sel = _sel == _downCell ? -1 : _downCell;
      }
    }
    _downCell = -1;
  }

  void _trySwap(int a, int b) {
    if (_ph != _Ph.idle || host.finished) return;
    if (_g[a] == null || _g[b] == null) return;
    _sel = -1;
    _swapA = a;
    _swapB = b;
    _swapCells(a, b);
    _ph = _Ph.swap;
    _phT = 0;
    _idle = 0;
    host.sfx(Sfx.swipe, volume: .6, rate: 1.2);
  }

  void _swapCells(int a, int b) {
    final t = _g[a];
    _g[a] = _g[b];
    _g[b] = t;
    _g[a]!.slide = true;
    _g[b]!.slide = true;
  }

  // ----------------------------------------------------------- matching ---

  void _afterSwap() {
    final a = _swapA, b = _swapB;
    final ca = _g[a]!, cb = _g[b]!;
    _cascade = 1;
    if (ca.special == 4 || cb.special == 4) {
      _bombSwap(ca.special == 4 ? a : b, ca.special == 4 ? b : a);
      return;
    }
    if (ca.special > 0 && cb.special > 0) {
      _comboSwap(a, b);
      return;
    }
    final f = _find({a, b});
    if (f.$1.isEmpty && f.$2.isEmpty) {
      _swapCells(a, b);
      _ph = _Ph.unswap;
      _phT = 0;
      host.sfx(Sfx.boing, volume: .5, rate: 1.4);
      _g[a]?.wob = 1;
      _g[b]?.wob = 1;
      _react(Face.sad, .6);
      return;
    }
    _startClear(f.$1, f.$2);
  }

  /// Returns (cells to clear, special creations idx->special).
  (Set<int>, Map<int, int>) _find(Set<int> pivots) {
    final clear = <int>{};
    final create = <int, int>{};
    final runs = <List<int>>[];
    final horiz = <bool>[];
    for (var r = 0; r < _n; r++) {
      var c = 0;
      while (c < _n) {
        final col = _colorAt(r * _n + c);
        var e = c + 1;
        if (col >= 0 && col <= 4) {
          while (e < _n && _colorAt(r * _n + e) == col) {
            e++;
          }
          if (e - c >= 3) {
            runs.add([for (var k = c; k < e; k++) r * _n + k]);
            horiz.add(true);
          }
        }
        c = e;
      }
    }
    for (var c = 0; c < _n; c++) {
      var r = 0;
      while (r < _n) {
        final col = _colorAt(r * _n + c);
        var e = r + 1;
        if (col >= 0 && col <= 4) {
          while (e < _n && _colorAt(e * _n + c) == col) {
            e++;
          }
          if (e - r >= 3) {
            runs.add([for (var k = r; k < e; k++) k * _n + c]);
            horiz.add(false);
          }
        }
        r = e;
      }
    }
    final count = <int, int>{};
    for (final run in runs) {
      clear.addAll(run);
      for (final i in run) {
        count[i] = (count[i] ?? 0) + 1;
      }
    }
    count.forEach((i, k) {
      if (k >= 2) create[i] = 3;
    });
    for (var ri = 0; ri < runs.length; ri++) {
      final run = runs[ri];
      final pivot = run.firstWhere(pivots.contains, orElse: () => run[run.length ~/ 2]);
      if (run.length >= 5) {
        run.forEach(create.remove);
        create[pivot] = 4;
      } else if (run.length == 4 && !run.any(create.containsKey)) {
        create[pivot] = horiz[ri] ? 2 : 1;
      }
    }
    clear.removeAll(create.keys);
    return (clear, create);
  }

  void _bombSwap(int bomb, int other) {
    final ob = _g[other]!;
    final set = <int>{bomb, other};
    final bc = _center(bomb);
    if (ob.special == 4) {
      for (var i = 0; i < _n * _n; i++) {
        if (_g[i] != null) set.add(i);
      }
      host.flash(Pal.white, .3);
    } else {
      final k = ob.color;
      for (var i = 0; i < _n * _n; i++) {
        final cd = _g[i];
        if (cd != null && cd.color == k) {
          set.add(i);
          if (ob.special > 0 && i != other) cd.special = ob.special == 3 ? 3 : (chance(.5) ? 1 : 2);
          _zaps.add(_Zap(bc, _center(i), _cols[k]));
        }
      }
    }
    host.sfx(Sfx.zap);
    host.sfx(Sfx.magic, volume: .8);
    host.hitStop(.08);
    _startClear(set, {}, skip: {bomb});
  }

  void _comboSwap(int a, int b) {
    final ca = _g[a]!, cb = _g[b]!;
    final r = b ~/ _n, c = b % _n;
    final set = <int>{a, b};
    final wrappedA = ca.special == 3, wrappedB = cb.special == 3;
    int rad;
    if (wrappedA && wrappedB) {
      rad = 2;
      for (var i = 0; i < _n * _n; i++) {
        if (((i ~/ _n) - r).abs() <= rad && ((i % _n) - c).abs() <= rad) set.add(i);
      }
      host.fx.ring(_center(b), Pal.yellow, size: 160, life: .5);
    } else {
      rad = (wrappedA || wrappedB) ? 1 : 0;
      for (var d = -rad; d <= rad; d++) {
        final rr = r + d, cc = c + d;
        if (rr >= 0 && rr < _n) {
          _beams.add(_Beam(true, rr, _cols[cb.color]));
          for (var k = 0; k < _n; k++) {
            set.add(rr * _n + k);
          }
        }
        if (cc >= 0 && cc < _n) {
          _beams.add(_Beam(false, cc, _cols[ca.color]));
          for (var k = 0; k < _n; k++) {
            set.add(k * _n + cc);
          }
        }
      }
    }
    host.sfx(Sfx.laser);
    host.sfx(Sfx.explode, volume: .8);
    _startClear(set, {}, skip: {a, b});
  }

  Offset _center(int i) => Offset(_bx + (i % _n + .5) * _cell, _by + (i ~/ _n + .5) * _cell);

  void _startClear(Set<int> clear, Map<int, int> create, {Set<int> skip = const {}}) {
    // chain-trigger specials
    final triggered = <int>{...skip};
    final queue = clear.toList();
    while (queue.isNotEmpty) {
      final i = queue.removeLast();
      final cd = _g[i];
      if (cd == null || cd.special == 0 || triggered.contains(i)) continue;
      triggered.add(i);
      final r = i ~/ _n, c = i % _n;
      final targets = <int>[];
      switch (cd.special) {
        case 1:
          for (var k = 0; k < _n; k++) {
            targets.add(r * _n + k);
          }
          _beams.add(_Beam(true, r, _cols[cd.color]));
          host.sfx(Sfx.laser, volume: .8, rate: 1.1);
        case 2:
          for (var k = 0; k < _n; k++) {
            targets.add(k * _n + c);
          }
          _beams.add(_Beam(false, c, _cols[cd.color]));
          host.sfx(Sfx.laser, volume: .8, rate: .95);
        case 3:
          for (var j = 0; j < _n * _n; j++) {
            if (((j ~/ _n) - r).abs() + ((j % _n) - c).abs() <= 2) targets.add(j);
          }
          host.fx.ring(_center(i), Pal.white, size: 110, life: .4);
          host.fx.burst(_center(i), _cols[cd.color], count: 20, speed: 320, gravity: 200);
          host.sfx(Sfx.explode, volume: .8);
          host.shake(8);
        case 4:
          final k = randInt(5);
          for (var j = 0; j < _n * _n; j++) {
            if (_colorAt(j) == k) {
              targets.add(j);
              _zaps.add(_Zap(_center(i), _center(j), _cols[k]));
            }
          }
          host.sfx(Sfx.zap);
      }
      for (final t in targets) {
        if (!create.containsKey(t) && _g[t] != null && clear.add(t)) queue.add(t);
      }
    }
    _clearing = clear;
    _creating = create;
    var reds = 0;
    var i0 = 0;
    for (final i in clear) {
      final cd = _g[i]!;
      cd.die = 0;
      final p = _center(i);
      if (cd.color <= 4) {
        host.fx.burst(p, _cols[cd.color], count: 5, speed: 190, size: 5, gravity: 500, life: .5);
      }
      if (cd.color == 0) {
        reds++;
        if (_collected + reds <= _target + 4) _flies.add(_Fly(p, -i0 * .04));
      }
      i0++;
    }
    for (final i in create.keys) {
      host.fx.sparkle(_center(i), count: 10, radius: 26, color: Pal.yellow);
    }
    // score
    final pts = (clear.length * 20 + create.length * 60) * _cascade;
    Offset mid = Offset.zero;
    for (final i in clear) {
      mid += _center(i);
    }
    if (clear.isNotEmpty) mid = mid / clear.length.toDouble();
    host.addScore(pts, mid);
    _collected += reds;
    // sounds & words
    host.sfx(Sfx.pop, rate: 1 + (_cascade - 1) * .1);
    if (_cascade >= 2) host.sfx(Sfx.combo, rate: 1 + (_cascade - 2) * .14);
    if (create.isNotEmpty) host.sfx(Sfx.powerup, volume: .7);
    final big = clear.length >= 10;
    if (_cascade >= 2 || big || create.isNotEmpty) {
      final lvl = max(_cascade, big ? 3 : 2);
      _setWord(switch (lvl) {
        2 => host.tr('sweet', 'Sweet!'),
        3 => host.tr('tasty', 'Tasty!'),
        4 => host.tr('delicious', 'Delicious!'),
        _ => host.tr('divine', 'Divine!'),
      }, [Pal.pink, Pal.orange, Pal.lime, Pal.sky, Pal.yellow][lvl % 5]);
      if (lvl >= 4) host.flash(const Color(0x66FFFFFF));
    }
    host.shake(min(12, 2.0 + clear.length * .25 + _cascade));
    if (clear.length >= 9) host.punch(.03);
    _mascotSquash = .7;
    _react(_cascade >= 3 || big ? Face.love : Face.happy, 1.2);
    _ph = _Ph.clear;
    _phT = 0;
    if (_collected >= _target && !host.finished) {
      final left = host.timeLeft;
      host.sfx(Sfx.fanfare);
      host.fx.confetti(count: 50);
      _setWord(host.tr('divine', 'Divine!'), Pal.yellow);
      host.win(stars: left > 9 ? 3 : (left > 4 ? 2 : 1));
    }
  }

  void _setWord(String s, Color c) {
    _word = s;
    _wordCol = c;
    _wordT = 0;
  }

  void _react(Face f, double sec) {
    _mascotFace = f;
    _faceT = sec;
  }

  void _finishClear() {
    for (final i in _clearing) {
      _g[i] = null;
    }
    _creating.forEach((i, s) {
      final cd = _g[i];
      if (cd == null) return;
      cd.special = s;
      if (s == 4) cd.color = 5;
      cd.pop = 1;
      host.fx.ring(_center(i), Pal.white, size: 40, life: .3);
    });
    _clearing = {};
    _creating = {};
    // gravity + refill
    for (var c = 0; c < _n; c++) {
      var w = _n - 1;
      for (var r = _n - 1; r >= 0; r--) {
        final cd = _g[r * _n + c];
        if (cd != null) {
          if (w != r) {
            _g[w * _n + c] = cd;
            _g[r * _n + c] = null;
          }
          w--;
        }
      }
      final missing = w + 1;
      for (var r = 0; r <= w; r++) {
        _g[r * _n + c] = _Candy(_randColor())
          ..x = c.toDouble()
          ..y = r - missing - .4;
      }
    }
    _ph = _Ph.fall;
    _phT = 0;
  }

  void _afterFall() {
    final f = _find({});
    if (f.$1.isNotEmpty || f.$2.isNotEmpty) {
      _cascade++;
      _startClear(f.$1, f.$2);
      return;
    }
    _cascade = 0;
    _ph = _Ph.idle;
    _hint = _findHint();
    if (_hint == null) _reshuffle();
  }

  void _reshuffle() {
    for (var tries = 0; tries < 30; tries++) {
      for (var i = 0; i < _n * _n; i++) {
        final cd = _g[i]!;
        if (cd.special != 0) continue;
        var col = _randColor();
        var guard = 0;
        while (_wouldRun(i, col) && guard++ < 20) {
          col = _randColor();
        }
        cd
          ..color = col
          ..pop = 1;
      }
      _hint = _findHint();
      if (_hint != null) break;
    }
    host.sfx(Sfx.shake);
    host.fx.pop(host.tr('shuffle', 'Shuffle!'), const Offset(180, 330), color: Pal.sky, size: 30);
  }

  (int, int)? _findHint() {
    final cols = List<int>.generate(_n * _n, _colorAt);
    for (var i = 0; i < _n * _n; i++) {
      for (final j in [if (i % _n < _n - 1) i + 1, if (i ~/ _n < _n - 1) i + _n]) {
        if (cols[i] == 5 || cols[j] == 5) return (i, j);
        final a = cols[i];
        cols[i] = cols[j];
        cols[j] = a;
        final ok = _lineAt(cols, i) || _lineAt(cols, j);
        cols[j] = cols[i];
        cols[i] = a;
        if (ok) return (i, j);
      }
    }
    return null;
  }

  bool _lineAt(List<int> cols, int i) {
    final col = cols[i];
    if (col < 0 || col > 4) return false;
    final r = i ~/ _n, c = i % _n;
    var h = 1;
    for (var k = c - 1; k >= 0 && cols[r * _n + k] == col; k--) {
      h++;
    }
    for (var k = c + 1; k < _n && cols[r * _n + k] == col; k++) {
      h++;
    }
    if (h >= 3) return true;
    var v = 1;
    for (var k = r - 1; k >= 0 && cols[k * _n + c] == col; k--) {
      v++;
    }
    for (var k = r + 1; k < _n && cols[k * _n + c] == col; k++) {
      v++;
    }
    return v >= 3;
  }

  // ------------------------------------------------------------ update ---

  static double _toward(double v, double t, double step) =>
      (t - v).abs() <= step ? t : v + (t > v ? step : -step);

  @override
  void update(double dt) {
    _t += dt;
    _phT += dt;
    _wordT += dt;
    _goalBump = M.approach(_goalBump, 0, 8, dt);
    _mascotSquash = M.approach(_mascotSquash, 1, 7, dt);
    _faceT -= dt;
    if (_faceT <= 0) _mascotFace = host.timeLeft < 5 && !host.finished ? Face.shocked : Face.happy;
    var settled = true;
    for (var i = 0; i < _n * _n; i++) {
      final cd = _g[i];
      if (cd == null) continue;
      final r = (i ~/ _n).toDouble(), c = (i % _n).toDouble();
      if (cd.slide) {
        cd.x = _toward(cd.x, c, 7.5 * dt);
        cd.y = _toward(cd.y, r, 7.5 * dt);
        if (cd.x == c && cd.y == r) cd.slide = false;
      } else {
        cd.x = _toward(cd.x, c, 8 * dt);
        if (cd.y < r) {
          cd.vy += 60 * dt;
          cd.y += cd.vy * dt;
          if (cd.y >= r) {
            cd.y = r;
            if (cd.vy > 4) cd.land = 1;
            cd.vy = 0;
          }
        } else {
          cd.y = r;
          cd.vy = 0;
        }
      }
      if (cd.x != c || cd.y != r) settled = false;
      cd.pop = M.approach(cd.pop, 0, 6, dt);
      cd.land = M.approach(cd.land, 0, 9, dt);
      cd.wob = M.approach(cd.wob, 0, 6, dt);
      if (cd.die >= 0) cd.die += dt / .22;
    }
    switch (_ph) {
      case _Ph.swap:
        if (_phT >= .14 && settled) _afterSwap();
      case _Ph.unswap:
        if (_phT >= .14 && settled) _ph = _Ph.idle;
      case _Ph.clear:
        if (_phT >= .22) _finishClear();
      case _Ph.fall:
        if (settled) {
          if (_phT > .05) host.sfx(Sfx.thud, volume: .25, rate: 1.6);
          _afterFall();
        }
      case _Ph.idle:
        _idle += dt;
    }
    for (final b in _beams) {
      b.t += dt;
    }
    _beams.removeWhere((b) => b.t > .4);
    for (final z in _zaps) {
      z.t += dt;
    }
    _zaps.removeWhere((z) => z.t > .35);
    for (final f in _flies) {
      f.t += dt / .55;
      if (f.t >= 1 && !f.done) {
        f.done = true;
        _shown++;
        _goalBump = 1;
        host.sfx(Sfx.pickup, volume: .35, rate: 1 + min(_shown, 14) * .04);
        if (_shown == _target) host.fx.burst(_goalPos, Pal.yellow, count: 24, shape: PartShape.star, speed: 260);
      }
    }
    _flies.removeWhere((f) => f.done);
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    // candy-land background
    D.gradientBg(c, const [Color(0xFFFF9FD2), Color(0xFFC77DFF), Color(0xFF7A4BD8)]);
    final stripe = D.fill(const Color(0x14FFFFFF));
    for (var i = -4; i < 14; i++) {
      final x = i * 48.0 + (_t * 14) % 48;
      c.drawPath(
          Path()
            ..moveTo(x, 0)
            ..lineTo(x + 22, 0)
            ..lineTo(x + 22 - 300, 640)
            ..lineTo(x - 300, 640)
            ..close(),
          stripe);
    }
    for (var i = 0; i < 14; i++) {
      final y = (i * 83 + _t * 20) % 700 - 30;
      final x = (i * 67.0) % 360;
      D.star(c, Offset(x, 640 - y), 3 + i % 3 * 1.5, const Color(0x55FFFFFF), rotation: _t + i);
    }
    // lollipops & hills
    _lolly(c, const Offset(30, 560), 22, Pal.sky);
    _lolly(c, const Offset(332, 548), 26, Pal.yellow);
    c.drawOval(const Rect.fromLTWH(-60, 575, 260, 140), D.fill(const Color(0xFFFFC2E2)));
    c.drawOval(const Rect.fromLTWH(160, 590, 280, 120), D.fill(const Color(0xFFFFB0D8)));

    _renderGoal(c);

    // board
    const boardR = Rect.fromLTWH(_bx - 8, _by - 8, _cell * _n + 16, _cell * _n + 16);
    D.rrect(c, boardR.shift(const Offset(0, 6)), 22, const Color(0x55301060));
    D.rrect(c, boardR, 22, const Color(0xCC3A1A6E), border: const Color(0xFFFFFFFF), borderWidth: 4);
    for (var i = 0; i < _n * _n; i++) {
      final r = i ~/ _n, cc = i % _n;
      if ((r + cc).isEven) {
        c.drawRect(Rect.fromLTWH(_bx + cc * _cell, _by + r * _cell, _cell, _cell), D.fill(const Color(0x22FFFFFF)));
      }
    }
    c.save();
    c.clipRect(const Rect.fromLTWH(_bx, _by, _cell * _n, _cell * _n));
    for (var i = 0; i < _n * _n; i++) {
      final cd = _g[i];
      if (cd == null) continue;
      final p = Offset(_bx + (cd.x + .5) * _cell, _by + (cd.y + .5) * _cell);
      if (p.dy < _by - _cell) continue;
      var s = 1.0;
      var sx = 1.0, sy = 1.0;
      if (cd.die >= 0) {
        final d = cd.die.clamp(0.0, 1.0);
        s = d < .35 ? 1 + d / .35 * .3 : 1.3 * (1 - (d - .35) / .65);
      }
      s *= 1 + cd.pop * .35 * sin(cd.pop * pi);
      sx = 1 + cd.land * .18 + cd.wob * .12 * sin(_t * 30);
      sy = 1 - cd.land * .18;
      final sel = i == _sel;
      final bob = sel ? sin(_t * 10) * 3 : 0.0;
      if (sel) {
        c.drawCircle(p, 23, D.fill(const Color(0x55FFFFFF)));
        c.drawCircle(p, 21 + sin(_t * 10), D.stroke(Pal.white, 3));
      }
      _drawCandy(c, p + Offset(0, bob + (1 - sy) * 10), 19 * s, cd, sx, sy, flashDie: cd.die >= 0 ? cd.die : -1);
    }
    for (final b in _beams) {
      final a = (1 - b.t / .4).clamp(0.0, 1.0);
      final w = 30 * a + 4;
      final Rect r = b.row
          ? Rect.fromLTWH(_bx - 10, _by + (b.idx + .5) * _cell - w / 2, _cell * _n + 20, w)
          : Rect.fromLTWH(_bx + (b.idx + .5) * _cell - w / 2, _by - 10, w, _cell * _n + 20);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(w / 2)), D.fill(b.col.withValues(alpha: .6 * a)));
      c.drawRRect(RRect.fromRectAndRadius(r.deflate(w * .3), Radius.circular(w / 4)), D.fill(Color.fromRGBO(255, 255, 255, a)));
    }
    for (final z in _zaps) {
      final a = (1 - z.t / .35).clamp(0.0, 1.0);
      final path = Path()..moveTo(z.a.dx, z.a.dy);
      for (var k = 1; k < 6; k++) {
        final q = Offset.lerp(z.a, z.b, k / 6)!;
        path.lineTo(q.dx + sin(k * 7.3 + _t * 60) * 7, q.dy + cos(k * 5.1 + _t * 50) * 7);
      }
      path.lineTo(z.b.dx, z.b.dy);
      c.drawPath(path, D.stroke(z.col.withValues(alpha: a), 6));
      c.drawPath(path, D.stroke(Color.fromRGBO(255, 255, 255, a), 2.5));
    }
    c.restore();

    // hint hand
    final h = _hint;
    if (h != null && _ph == _Ph.idle && !host.finished && (_idle > 3.5 || host.time < 2.2)) {
      final a = _center(h.$1), b = _center(h.$2);
      final k = M.easeInOut((_t * 1.2) % 1.0);
      c.drawCircle(a, 22, D.stroke(Color.fromRGBO(255, 255, 255, .5 + .5 * M.wave(_t, 3)), 3));
      D.hand(c, Offset.lerp(a, b, k)!, 0, size: 40);
    }

    // combo word
    if (_wordT < 1.1 && _word.isNotEmpty) {
      final k = _wordT;
      final sc = k < .25 ? M.easeOutBack(k / .25) : 1.0;
      final a = k > .85 ? (1.1 - k) / .25 : 1.0;
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a.clamp(0.0, 1.0)));
      D.title(c, _word, Offset(180, 330 - k * 30), size: 46, color: _wordCol, scale: sc, rotate: -.06);
      c.restore();
    }

    // mascot: a jelly bear-ish blob that cheers
    final mp = Offset(180, 588 + sin(_t * 3) * 3);
    D.shadow(c, const Offset(180, 628), 90, 14);
    c.drawCircle(mp + const Offset(-26, -34), 11, D.fill(const Color(0xFFFF6FB5)));
    c.drawCircle(mp + const Offset(26, -34), 11, D.fill(const Color(0xFFFF6FB5)));
    D.blob(c, mp, 38, const Color(0xFFFF6FB5), face: _mascotFace, squash: _mascotSquash, look: Offset(sin(_t) * .5, -.6));

    // flying red candies
    for (final f in _flies) {
      if (f.t < 0) continue;
      final k = M.easeInOut(f.t.clamp(0.0, 1.0));
      final ctrl = Offset(f.from.dx + (f.from.dx < 180 ? -60 : 60), f.from.dy - 160);
      final p1 = Offset.lerp(f.from, ctrl, k)!;
      final p2 = Offset.lerp(ctrl, _goalPos, k)!;
      final p = Offset.lerp(p1, p2, k)!;
      _drawCandy(c, p, 13 - k * 3, _flyCandy, 1, 1);
    }
  }

  static final _flyCandy = _Candy(0);

  void _renderGoal(Canvas c) {
    const panel = Rect.fromLTWH(60, 50, 240, 96);
    D.rrect(c, panel.shift(const Offset(0, 5)), 24, const Color(0x55301060));
    D.rrect(c, panel, 24, Pal.cream, border: Pal.ink, borderWidth: 3.5);
    // candy-cane top edge
    for (var i = 0; i < 9; i++) {
      c.drawRect(Rect.fromLTWH(78 + i * 23.0, 50, 11, 8), D.fill(i.isEven ? Pal.red : Pal.white));
    }
    final bump = 1 + _goalBump * .35;
    D.circle(c, _goalPos, 34, const Color(0xFFFFE3EF));
    _drawCandy(c, _goalPos, 22 * bump, _flyCandy, 1, 1);
    final left = max(0, _target - _shown);
    if (left == 0) {
      D.circle(c, _goalPos + const Offset(22, 20), 13, Pal.green, border: Pal.ink, borderWidth: 2.5);
      D.line(c, _goalPos + const Offset(15, 20), _goalPos + const Offset(20, 25), Pal.white, 3.5);
      D.line(c, _goalPos + const Offset(20, 25), _goalPos + const Offset(29, 14), Pal.white, 3.5);
    }
    D.text(c, 'x', const Offset(180, 100), size: 24, color: Pal.ink);
    D.text(c, '$left', const Offset(236, 96),
        size: 48 * (1 + _goalBump * .2), color: left == 0 ? Pal.green : Pal.red, stroke: Pal.ink, strokeWidth: 8);
    D.bar(c, const Rect.fromLTWH(84, 128, 192, 10), _shown / _target, Pal.pink, back: const Color(0x33301060));
  }

  void _lolly(Canvas c, Offset o, double r, Color col) {
    c.drawLine(o, o + const Offset(0, 90), D.stroke(Pal.white, 6));
    c.drawCircle(o, r, D.fill(col));
    final sp = Path();
    for (var k = 0; k < 40; k++) {
      final a = k * .45 + _t;
      final rr = r * k / 40;
      final q = o + Offset(cos(a) * rr, sin(a) * rr);
      k == 0 ? sp.moveTo(q.dx, q.dy) : sp.lineTo(q.dx, q.dy);
    }
    c.drawPath(sp, D.stroke(const Color(0xCCFFFFFF), 4));
    c.drawCircle(o, r, D.stroke(Pal.ink, 2.5));
  }

  static final Paint _shadowP = Paint()..color = const Color(0x44200030);
  static final Paint _hiP = Paint()..color = const Color(0xCCFFFFFF);
  static final List<Paint> _bodyP = [for (final col in _cols) Paint()..color = col];
  static final List<Paint> _lightP = [for (final col in _cols) Paint()..color = Color.lerp(col, Pal.white, .35)!];
  static final List<Paint> _edgeP = [
    for (final col in _cols)
      Paint()
        ..color = Color.lerp(col, Pal.ink, .55)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = .12
  ];

  void _drawCandy(Canvas c, Offset p, double r, _Candy cd, double sx, double sy, {double flashDie = -1}) {
    if (r <= .5) return;
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(r * sx, r * sy);
    if (cd.special == 4) {
      // color bomb: chocolate truffle with rainbow sprinkles
      c.drawCircle(const Offset(.05, .12), 1.02, _shadowP);
      c.drawCircle(Offset.zero, 1, D.fill(const Color(0xFF5A3020)));
      c.drawCircle(const Offset(-.15, -.15), .75, D.fill(const Color(0xFF7A4530)));
      for (var k = 0; k < 9; k++) {
        final a = k * 2.4 + _t * 2;
        final rr = .3 + (k % 3) * .22;
        final q = Offset(cos(a) * rr, sin(a) * rr);
        c.save();
        c.translate(q.dx, q.dy);
        c.rotate(a);
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-.16, -.05, .32, .1), const Radius.circular(.05)),
            D.fill(Pal.candy[k % Pal.candy.length]));
        c.restore();
      }
      c.drawOval(const Rect.fromLTWH(-.6, -.75, .5, .3), _hiP);
      c.drawCircle(Offset.zero, 1, D.stroke(Pal.ink, .1));
    } else {
      final k = cd.color;
      final path = _shapes[k];
      if (cd.special == 3) {
        // wrapper wings
        final wing = Path()
          ..moveTo(-.7, 0)
          ..lineTo(-1.35, -.55)
          ..lineTo(-1.35, .55)
          ..close()
          ..moveTo(.7, 0)
          ..lineTo(1.35, -.55)
          ..lineTo(1.35, .55)
          ..close();
        c.drawPath(wing, _lightP[k]);
        c.drawPath(wing, _edgeP[k]);
        c.drawCircle(Offset.zero, 1.2 + .1 * sin(_t * 8), D.fill(Color.fromRGBO(255, 255, 255, .25 + .15 * sin(_t * 8))));
      }
      c.save();
      c.translate(.04, .12);
      c.drawPath(path, _shadowP);
      c.restore();
      c.drawPath(path, _bodyP[k]);
      c.save();
      c.translate(-.12, -.14);
      c.scale(.7);
      c.drawPath(path, _lightP[k]);
      c.restore();
      if (cd.special == 1 || cd.special == 2) {
        c.save();
        c.clipPath(path);
        if (cd.special == 2) c.rotate(pi / 2);
        final sp = D.stroke(const Color(0xEEFFFFFF), .2);
        for (var s = -1; s <= 1; s++) {
          c.drawLine(Offset(-1.2, s * .5), Offset(1.2, s * .5), sp);
        }
        c.restore();
      }
      c.drawPath(path, _edgeP[k]);
      c.drawOval(const Rect.fromLTWH(-.62, -.72, .45, .28), _hiP);
      c.drawCircle(const Offset(.45, .42), .08, D.fill(const Color(0x88FFFFFF)));
    }
    if (flashDie >= 0) {
      final a = (1 - flashDie * 1.5).clamp(0.0, 1.0);
      if (a > 0) c.drawCircle(Offset.zero, 1.05, D.fill(Color.fromRGBO(255, 255, 255, a * .85)));
    }
    c.restore();
  }
}

enum _Ph { idle, swap, unswap, clear, fall }

class _Candy {
  _Candy(this.color);
  int color; // 0..4, 5 = bomb
  int special = 0; // 1 row-striped, 2 col-striped, 3 wrapped, 4 bomb
  double x = 0, y = 0, vy = 0;
  double pop = 0, land = 0, wob = 0;
  double die = -1;
  bool slide = false;
}

class _Beam {
  _Beam(this.row, this.idx, this.col);
  final bool row;
  final int idx;
  final Color col;
  double t = 0;
}

class _Zap {
  _Zap(this.a, this.b, this.col);
  final Offset a, b;
  final Color col;
  double t = 0;
}

class _Fly {
  _Fly(this.from, this.t);
  final Offset from;
  double t;
  bool done = false;
}
