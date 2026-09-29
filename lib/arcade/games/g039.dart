import '../engine/engine.dart';

/// No.039 Tiny Theme Park — pixel park tycoon. Build stalls and rides next to
/// the paths; guests walk over following their need bubbles, pay, and SCREAM
/// (with joy). Reach the cash goal while keeping the park happy.
class G039 extends MiniGame {
  static const _cols = 6, _rows = 7;
  static const double _ts = 52, _ox = 24, _oy = 128;
  static const _map = ['......', '.PPPP.', '.P..P.', '.PPPP.', '.P..P.', '.PPPP.', '..P...'];
  static const _gateC = 2, _gateR = 6;
  static const _target = 370;
  static const _needHappy = 70.0;
  static const _dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];

  // cost, pay, satisfies want, joy, ride seconds
  static const _kinds = <_Kind>[
    _Kind(30, 8, 0, 5, .8),
    _Kind(20, 5, 1, 6, .7),
    _Kind(50, 12, 2, 7, 1.1),
    _Kind(80, 22, 2, 11, 1.3),
  ];

  final _blds = <int, _Bld>{};
  final _guests = <_Guest>[];
  double _t = 0;
  double _cash = 100;
  double _shownCash = 100;
  double _happy = 60;
  double _shownHappy = 60;
  int _sel = -1;
  double _spawnT = .25;
  final _cardErr = List<double>.filled(4, 0);
  double _selBob = 0;
  int _chain = 0;
  double _chainT = 0;
  (int, int)? _bad;
  double _badT = 0;
  double _endT = 0;
  bool _won = false;
  double _nudge = 0;

  static final Paint _pp = Paint()..isAntiAlias = false;
  static void _px(Canvas c, double x, double y, double w, double h, Color col) {
    _pp.color = col;
    c.drawRect(Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), w, h), _pp);
  }

  // ------------------------------------------------------------ sprites ---
  static const _shirts = [Color(0xFFE8453C), Color(0xFF3FB8FF), Color(0xFFFFD23F), Color(0xFF7BD34A), Color(0xFFFF6FC8), Color(0xFF9B6BFF)];
  static const _hairs = [Color(0xFF6B3A1E), Color(0xFF221A2E), Color(0xFFF2C14E), Color(0xFFE0632A), Color(0xFF6B3A1E), Color(0xFF221A2E)];
  static final List<Sprite> _gs = [
    for (var i = 0; i < 6; i++)
      for (var f = 0; f < 2; f++)
        Sprite([
          '.HHH.',
          'HHHHH',
          'SKSKS',
          'SSSSS',
          '.TTT.',
          'TTTTT',
          'STTTS',
          '.PPP.',
          f == 0 ? '.P.P.' : 'P...P',
        ], {
          'H': _hairs[i],
          'S': const Color(0xFFFFCC99),
          'K': const Color(0xFF1B1530),
          'T': _shirts[i],
          'P': const Color(0xFF2E3A6B),
        }),
  ];
  static final _burger = Sprite([
    '.BBBBB.',
    'BBWBBWB',
    'GGGGGGG',
    'MMMMMMM',
    '.BBBBB.',
  ], {'B': const Color(0xFFE8A040), 'W': const Color(0xFFFFF4DC), 'G': const Color(0xFF5BC13A), 'M': const Color(0xFF7A3B1C)});
  static final _star = Sprite([
    '...Y...',
    '..YYY..',
    'YYYYYYY',
    '.YYYYY.',
    '.YY.YY.',
    'Y.....Y',
  ], {'Y': const Color(0xFFFFC53D)});
  static final _heart = Sprite([
    '.RR.RR.',
    'RRRRRRR',
    'RRRRRRR',
    '.RRRRR.',
    '..RRR..',
    '...R...',
  ], {'R': const Color(0xFFFF3B5C)});
  static final _storm = Sprite([
    '..DDD...',
    '.DDDDDD.',
    'DDDDDDDD',
    '.DDDDDD.',
    '..Y..Y..',
    '.Y..Y...',
  ], {'D': const Color(0xFF4A4560), 'Y': const Color(0xFFFFD23F)});
  static Sprite _smile(int mood) => Sprite([
        '..YYYYY..',
        '.YYYYYYY.',
        'YYKYYYKYY',
        'YYKYYYKYY',
        'YYYYYYYYY',
        mood == 2 ? 'YKYYYYYKY' : (mood == 1 ? 'YYYYYYYYY' : 'YYYKKKYYY'),
        mood == 2 ? 'YYKKKKKYY' : (mood == 1 ? 'YYKKKKKYY' : 'YYKYYYKYY'),
        '.YYYYYYY.',
        '..YYYYY..',
      ], {
        'Y': mood == 2 ? const Color(0xFFFFD23F) : (mood == 1 ? const Color(0xFFFFB03F) : const Color(0xFFFF6A4A)),
        'K': const Color(0xFF1B1530),
      });
  static final _smiles = [_smile(0), _smile(1), _smile(2)];

  // -------------------------------------------------------------- grid ---
  bool _isPath(int c, int r) => c >= 0 && r >= 0 && c < _cols && r < _rows && _map[r][c] == 'P';
  Offset _center(int c, int r) => Offset(_ox + c * _ts + _ts / 2, _oy + r * _ts + _ts / 2);
  bool _adjPath(int c, int r) => _dirs.any((d) => _isPath(c + d.$1, r + d.$2));
  bool _buildable(int c, int r) =>
      c >= 0 && r >= 0 && c < _cols && r < _rows && !_isPath(c, r) && !_blds.containsKey(r * _cols + c) && _adjPath(c, r);
  Rect _card(int i) => Rect.fromLTWH(8 + i * 88.0, 510, 80, 104);

  _Bld? _bldFor(int c, int r, int want) {
    _Bld? best;
    for (final d in _dirs) {
      final b = _blds[(r + d.$2) * _cols + c + d.$1];
      if (b == null || c + d.$1 < 0 || c + d.$1 >= _cols) continue;
      if (_kinds[b.kind].want != want) continue;
      if (best == null || b.kind > best.kind) best = b;
    }
    return best;
  }

  List<(int, int)>? _bfs(int sc, int sr, bool Function(int c, int r) goal) {
    final prev = List<int>.filled(_cols * _rows, -2);
    final q = <int>[sr * _cols + sc];
    prev[q.first] = -1;
    var head = 0;
    while (head < q.length) {
      final k = q[head++];
      final c = k % _cols, r = k ~/ _cols;
      if (goal(c, r)) {
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
        if (!_isPath(nc, nr)) continue;
        final nk = nr * _cols + nc;
        if (prev[nk] != -2) continue;
        prev[nk] = k;
        q.add(nk);
      }
    }
    return null;
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _selBob += dt;
    _shownCash = M.approach(_shownCash, _cash, 10, dt);
    _shownHappy = M.approach(_shownHappy, _happy, 6, dt);
    for (var i = 0; i < 4; i++) {
      _cardErr[i] = M.approach(_cardErr[i], 0, 5, dt);
    }
    _badT = max(0, _badT - dt);
    _nudge = M.approach(_nudge, 0, 4, dt);
    _chainT -= dt;
    if (_chainT <= 0) _chain = 0;
    for (final b in _blds.values) {
      b.pop = M.approach(b.pop, 0, 4, dt);
      b.busy = max(0, b.busy - dt);
      b.spin += dt * (b.busy > 0 ? 5.0 : 1.0);
    }
    if (host.finished) {
      _endT += dt;
      for (final g in _guests) {
        g.hop = _won ? (sin(_endT * 12 + g.pos.dx) * .5 + .5) : 0;
        if (!_won) g.angry = true;
      }
      return;
    }

    _spawnT -= dt;
    if (_spawnT <= 0 && _guests.length < 16) {
      _spawnT = M.lerp(1.6, .6, _happy / 100) / host.speed;
      final g = _Guest(_center(_gateC, _gateR) + const Offset(0, 40), _gateC, _gateR, randInt(6))
        ..wantDelay = rand(.2, 1.4)
        ..maxDone = 2 + randInt(2)
        ..spd = rand(.9, 1.15)
        ..jitter = Offset(rand(-9, 9), rand(-7, 5));
      g.route.add((_gateC, _gateR));
      _guests.add(g);
      _cash += 5;
      host.fx.pop('+5', _center(_gateC, _gateR) + const Offset(22, 10), color: Pal.gold, size: 14, life: .6, rise: 30);
      host.sfx(Sfx.pCoin, volume: .25, rate: 1.4);
    }

    for (final g in _guests) {
      _updateGuest(g, dt);
    }
    _guests.removeWhere((g) => g.gone);
    _happy = _happy.clamp(0, 100);

    if (_cash >= _target && _happy >= _needHappy) {
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.pPowerup, volume: .7);
      host.fx.confetti(count: 90);
      host.fx.pop(host.tr('jackpot', 'JACKPOT!'), const Offset(180, 300), color: Pal.yellow, size: 40, life: 1.4);
      host.flash(Pal.white, .15);
      _won = true;
      host.win(stars: host.time < 19 ? 3 : (host.time < 22 ? 2 : 1));
    }
  }

  int _rollWant() {
    final r = rand(0, 1);
    return r < .38 ? 2 : (r < .7 ? 0 : 1);
  }

  void _updateGuest(_Guest g, double dt) {
    g.hop = M.approach(g.hop, 0, 5, dt);
    g.heart = max(0, g.heart - dt);
    g.pop = M.approach(g.pop, 0, 6, dt);
    if (g.inside != null) {
      g.insideT -= dt;
      if (g.insideT <= 0) _exitRide(g);
      return;
    }
    if (g.exiting) {
      g.pos += Offset(0, 55 * dt);
      g.walk += dt * 9;
      if (g.pos.dy > _center(_gateC, _gateR).dy + 44) g.gone = true;
      return;
    }
    if (!g.leaving) {
      if (g.want < 0) {
        g.wantDelay -= dt;
        if (g.wantDelay <= 0) {
          g.want = _rollWant();
          g.maxPat = 8.5 / host.speed;
          g.patience = g.maxPat;
          g.pop = 1;
          g.route.clear();
        }
      } else {
        g.patience -= dt;
        if (g.patience <= 0) {
          _rage(g);
        }
      }
    }
    if (g.route.isEmpty) _plan(g);
    if (g.route.isNotEmpty && g.inside == null) {
      final (tc, tr) = g.route.first;
      final target = _center(tc, tr) + g.jitter;
      final d = target - g.pos;
      final step = 64 * host.speed * g.spd * dt;
      if (d.distance <= step) {
        g.pos = target;
        g.pc = g.c;
        g.pr = g.r;
        g.c = tc;
        g.r = tr;
        g.route.removeAt(0);
        if (g.route.isEmpty) _arrive(g);
      } else {
        g.pos += d / d.distance * step;
        if (d.dx.abs() > 1) g.flip = d.dx < 0;
      }
      g.walk += dt * 9;
    }
  }

  void _plan(_Guest g) {
    if (g.leaving) {
      if (g.c == _gateC && g.r == _gateR) {
        g.exiting = true;
      } else {
        g.route.addAll(_bfs(g.c, g.r, (c, r) => c == _gateC && r == _gateR) ?? const []);
      }
      return;
    }
    if (g.want >= 0) {
      final w = g.want;
      final route = _bfs(g.c, g.r, (c, r) => _bldFor(c, r, w) != null);
      if (route != null) {
        if (route.isEmpty) {
          _arrive(g);
        } else {
          g.route.addAll(route);
        }
        return;
      }
    }
    // wander
    final opts = <(int, int)>[];
    for (final d in _dirs) {
      final nc = g.c + d.$1, nr = g.r + d.$2;
      if (!_isPath(nc, nr) || (nc == _gateC && nr == _gateR && g.r != _gateR)) continue;
      if (nc == g.pc && nr == g.pr) continue;
      opts.add((nc, nr));
    }
    if (opts.isEmpty) opts.add((g.pc, g.pr));
    g.route.add(pick(opts));
  }

  void _arrive(_Guest g) {
    if (g.leaving || g.want < 0) return;
    final b = _bldFor(g.c, g.r, g.want);
    if (b == null) return;
    final k = _kinds[b.kind];
    g.inside = b;
    g.insideT = k.dur;
    b.busy = max(b.busy, k.dur);
    b.pop = .5;
    host.sfx(const [Sfx.chomp, Sfx.pour, Sfx.pSelect, Sfx.pJump][b.kind], volume: .5, rate: 1.1);
  }

  void _exitRide(_Guest g) {
    final b = g.inside!;
    final k = _kinds[b.kind];
    g.inside = null;
    g.want = -1;
    g.wantDelay = rand(.5, 1.4);
    g.done++;
    g.hop = 1;
    g.heart = 1;
    _cash += k.pay;
    _happy += k.joy;
    _chain++;
    _chainT = 1.2;
    final at = _center(b.c, b.r) + const Offset(0, -30);
    host.addScore(k.pay, at);
    host.fx.pop('+\$${k.pay}', at + const Offset(0, -16), color: Pal.gold, size: 18 + min(_chain, 6) * 1.5, rise: 44);
    host.fx.burst(at, Pal.gold, count: 8 + _chain, speed: 170, size: 5, shape: PartShape.square, gravity: 500,
        colors: const [Pal.gold, Color(0xFFFFF1A8), Pal.orange]);
    host.sfx(Sfx.pCoin, volume: .7, rate: 1 + min(_chain, 8) * .06);
    if (b.kind == 3) {
      host.fx.pop(host.tr('scream', 'SCREAM!'), at + const Offset(0, -46), color: Pal.pink, size: 24, life: 1);
      host.shake(3);
      host.sfx(Sfx.cheer, volume: .4, rate: 1.2);
    } else if (_chain >= 4 && _chain % 2 == 0) {
      host.fx.pop('COMBO x$_chain', const Offset(180, 150), color: Pal.lime, size: 22);
    }
    if (g.done >= g.maxDone) {
      g.leaving = true;
      g.route.clear();
    }
  }

  void _rage(_Guest g) {
    g.want = -1;
    g.leaving = true;
    g.angry = true;
    g.route.clear();
    _happy -= 10;
    host.sfx(Sfx.pHit, volume: .7, rate: .8);
    host.fx.pop('-10', g.pos + const Offset(0, -34), color: Pal.red, size: 18);
    host.fx.burst(g.pos + const Offset(0, -20), Pal.red, count: 8, speed: 120, size: 5, shape: PartShape.square, gravity: 200);
    host.shake(2);
  }

  // ------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    if (host.finished) return;
    for (var i = 0; i < 4; i++) {
      if (_card(i).inflate(4).contains(p)) {
        if (_cash < _kinds[i].cost) {
          _cardErr[i] = 1;
          host.sfx(Sfx.buzzer, volume: .4);
          return;
        }
        _sel = _sel == i ? -1 : i;
        _selBob = 0;
        host.sfx(Sfx.pSelect);
        return;
      }
    }
    final c = ((p.dx - _ox) / _ts).floor();
    final r = ((p.dy - _oy) / _ts).floor();
    if (c < 0 || r < 0 || c >= _cols || r >= _rows) return;
    _tapTile(c, r);
  }

  void _tapTile(int c, int r) {
    if (_sel < 0) {
      if (_buildable(c, r)) {
        // nothing selected: nudge the build menu
        _nudge = 1;
        host.sfx(Sfx.tap, volume: .4);
      }
      return;
    }
    if (!_buildable(c, r)) {
      _bad = (c, r);
      _badT = .4;
      host.sfx(Sfx.wrong, volume: .4);
      return;
    }
    final k = _kinds[_sel];
    if (_cash < k.cost) {
      _cardErr[_sel] = 1;
      host.sfx(Sfx.buzzer, volume: .4);
      _sel = -1;
      return;
    }
    _cash -= k.cost;
    _blds[r * _cols + c] = _Bld(_sel, c, r)..pop = 1;
    final at = _center(c, r);
    host.fx.smoke(at + const Offset(0, 14), count: 8, color: const Color(0xCCF4E8C8), size: 16);
    host.fx.burst(at, Pal.yellow, count: 14, speed: 200, size: 6, shape: PartShape.square, gravity: 400,
        colors: const [Pal.yellow, Pal.white, Pal.orange]);
    host.fx.pop('-\$${k.cost}', at + const Offset(0, -20), color: const Color(0xFFFF9C9C), size: 16, rise: 36);
    host.sfx(Sfx.hammer, volume: .6);
    host.sfx(Sfx.pPowerup, volume: .5);
    host.shake(3);
    host.punch(.02);
    if (_cash < k.cost) _sel = -1;
    // guests with matching wants re-plan
    for (final g in _guests) {
      if (g.want == k.want && g.inside == null && !g.leaving && g.route.length <= 1) g.route.clear();
    }
  }

  @override
  void onTimeUp() {
    if (_cash >= _target && _happy >= _needHappy) {
      _won = true;
      host.fx.confetti();
      host.win(stars: 1);
    } else {
      host.sfx(Sfx.aww);
      host.lose();
    }
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    // outer grass + hedges
    Retro.tiles(c, const Rect.fromLTWH(0, 0, 360, 640), 8, const Color(0xFF2F7A3A), const Color(0xFF2B7236));
    for (var y = 132.0; y < 500; y += 26) {
      _bush(c, 10, y + (y % 52 == 0 ? 6 : 0));
      _bush(c, 350, y + 13);
    }
    // park tiles
    for (var r = 0; r < _rows; r++) {
      for (var col = 0; col < _cols; col++) {
        _tile(c, col, r);
      }
    }
    // fence
    const fence = Color(0xFF8A5530);
    for (var x = _ox; x <= _ox + _cols * _ts; x += 13) {
      _px(c, x - 2, _oy - 6, 4, 8, fence);
    }
    _px(c, _ox, _oy - 4, _cols * _ts, 3, const Color(0xFFB0773F));
    _gate(c);

    // valid build spots
    if (_sel >= 0 && !host.finished) {
      final blink = .45 + .35 * sin(_t * 10);
      for (var r = 0; r < _rows; r++) {
        for (var col = 0; col < _cols; col++) {
          if (!_buildable(col, r)) continue;
          final rr = Rect.fromLTWH(_ox + col * _ts + 3, _oy + r * _ts + 3, _ts - 6, _ts - 6);
          c.drawRect(rr, Paint()..color = Color.fromRGBO(255, 230, 80, blink * .35));
          c.drawRect(rr, Paint()
            ..isAntiAlias = false
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Color.fromRGBO(255, 240, 120, blink));
        }
      }
    }
    if (_badT > 0 && _bad != null) {
      final ctr = _center(_bad!.$1, _bad!.$2);
      final a = _badT / .4;
      D.line(c, ctr + const Offset(-14, -14), ctr + const Offset(14, 14), Color.fromRGBO(255, 60, 60, a), 6);
      D.line(c, ctr + const Offset(14, -14), ctr + const Offset(-14, 14), Color.fromRGBO(255, 60, 60, a), 6);
    }

    // y-sorted buildings & guests
    final items = <(double, int, Object)>[];
    for (final b in _blds.values) {
      items.add((_center(b.c, b.r).dy + _ts / 2 - 4, 0, b));
    }
    for (final g in _guests) {
      if (g.inside == null) items.add((g.pos.dy + 10, 1, g));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final it in items) {
      if (it.$2 == 0) {
        final b = it.$3 as _Bld;
        final base = Offset(_center(b.c, b.r).dx, it.$1);
        _drawBld(c, b.kind, base, b.spin, b.busy, b.pop);
      } else {
        _drawGuest(c, it.$3 as _Guest);
      }
    }
    for (final g in _guests) {
      if (g.inside == null) _drawBubble(c, g);
    }

    _hud(c);
    _menu(c);

    // tutorial
    if (!host.finished && _blds.isEmpty && host.time < 4) {
      if (_sel < 0) {
        D.hand(c, _card(0).center + const Offset(0, -10), _t);
      } else {
        D.hand(c, _center(2, 2), _t);
      }
    }
    Retro.scanlines(c, alpha: .1);
    Retro.vignette(c, strength: .3);
  }

  void _bush(Canvas c, double x, double y) {
    _px(c, x - 10, y - 6, 20, 12, const Color(0xFF1F5E2C));
    _px(c, x - 8, y - 10, 16, 6, const Color(0xFF2E8B3E));
    _px(c, x - 4, y - 8, 4, 4, const Color(0xFF5DBB4A));
  }

  void _tile(Canvas c, int col, int r) {
    final x = _ox + col * _ts, y = _oy + r * _ts;
    final h = (col * 7 + r * 13) % 11;
    if (_isPath(col, r)) {
      _px(c, x, y, _ts, _ts, const Color(0xFF7FC24E));
      // sandy path, inset where it doesn't connect
      final l = _isPath(col - 1, r) ? 0.0 : 8.0, rt = _isPath(col + 1, r) ? 0.0 : 8.0;
      final t = _isPath(col, r - 1) ? 0.0 : 8.0, b = (_isPath(col, r + 1) || (col == _gateC && r == _gateR)) ? 0.0 : 8.0;
      _px(c, x + l, y + t, _ts - l - rt, _ts - t - b, const Color(0xFFC99A5B));
      _px(c, x + l + 3, y + t + 3, _ts - l - rt - 6, _ts - t - b - 6, const Color(0xFFEBCB8B));
      _px(c, x + 10 + h, y + 14, 4, 4, const Color(0xFFD1AE6E));
      _px(c, x + 30 - h, y + 34, 4, 4, const Color(0xFFD1AE6E));
      _px(c, x + 22, y + 8 + h * 2, 3, 3, const Color(0xFFF6DDA6));
    } else {
      _px(c, x, y, _ts, _ts, (col + r).isEven ? const Color(0xFF7FC24E) : const Color(0xFF76B947));
      _px(c, x + 6 + h * 2, y + 10, 4, 4, const Color(0xFF5EA23A));
      _px(c, x + 8 + h * 2, y + 6, 2, 4, const Color(0xFF5EA23A));
      _px(c, x + 36 - h, y + 32, 4, 4, const Color(0xFF5EA23A));
      if (h % 3 == 0) {
        _px(c, x + 14 + h, y + 36, 4, 4, h.isEven ? const Color(0xFFFFFFFF) : const Color(0xFFFFE066));
        _px(c, x + 15 + h, y + 40, 2, 4, const Color(0xFF3F8A2C));
      }
    }
  }

  void _gate(Canvas c) {
    final ctr = _center(_gateC, _gateR);
    final by = ctr.dy + _ts / 2;
    const post = Color(0xFFB03A48);
    _px(c, ctr.dx - 28, by - 44, 8, 44, post);
    _px(c, ctr.dx + 20, by - 44, 8, 44, post);
    _px(c, ctr.dx - 32, by - 54, 64, 12, const Color(0xFFFFC53D));
    _px(c, ctr.dx - 32, by - 44, 64, 3, const Color(0xFFB8860B));
    for (var i = 0; i < 5; i++) {
      _px(c, ctr.dx - 26 + i * 12, by - 50, 6, 4, Pal.candy[(i + (_t * 4).floor()) % Pal.candy.length]);
    }
    // flags
    final wav = (_t * 6).floor().isEven ? 0.0 : 2.0;
    _px(c, ctr.dx - 26, by - 66, 2, 12, Pal.ink);
    _px(c, ctr.dx - 24, by - 66 + wav, 8, 5, Pal.red);
    _px(c, ctr.dx + 24, by - 66, 2, 12, Pal.ink);
    _px(c, ctr.dx + 26, by - 66 + 2 - wav, 8, 5, Pal.sky);
  }

  void _drawBld(Canvas c, int kind, Offset base, double spin, double busy, double pop) {
    c.save();
    if (pop > .01) {
      final s = 1 + sin(pop * pi * 3) * pop * .25;
      c.translate(base.dx, base.dy);
      c.scale(1 / s, s);
      c.translate(-base.dx, -base.dy);
    }
    _px(c, base.dx - 22, base.dy - 3, 44, 5, const Color(0x44000000));
    switch (kind) {
      case 0: // food stand
        _px(c, base.dx - 20, base.dy - 24, 40, 24, const Color(0xFFB86B3A));
        _px(c, base.dx - 20, base.dy - 6, 40, 6, const Color(0xFF8A4A24));
        _px(c, base.dx - 14, base.dy - 20, 28, 9, const Color(0xFF3A2440));
        if (busy > 0) _px(c, base.dx - 6, base.dy - 19, 12, 8, const Color(0xFFFFCC99));
        for (var i = 0; i < 6; i++) {
          _px(c, base.dx - 24 + i * 8, base.dy - 36, 8, 12, i.isEven ? const Color(0xFFE8453C) : const Color(0xFFFFF4DC));
          _px(c, base.dx - 22 + i * 8, base.dy - 24, 4, 3, i.isEven ? const Color(0xFFE8453C) : const Color(0xFFFFF4DC));
        }
        final bob = busy > 0 ? ((_t * 12).floor().isEven ? -3.0 : 0.0) : 0.0;
        _burger.draw(c, Offset(base.dx - 10.5, base.dy - 54 + bob), scale: 3);
        if (busy > 0) _px(c, base.dx + 10, base.dy - 46 + bob * 2, 3, 3, const Color(0xCCFFFFFF));
      case 1: // restroom
        _px(c, base.dx - 17, base.dy - 42, 34, 42, const Color(0xFF3D6BFF));
        _px(c, base.dx - 19, base.dy - 46, 38, 6, const Color(0xFF2A48B0));
        _px(c, base.dx - 9, base.dy - 26, 18, 26, busy > 0 ? const Color(0xFF1C2E73) : const Color(0xFF9CC8FF));
        _px(c, base.dx + 4, base.dy - 14, 3, 3, Pal.gold);
        PixelFont.draw(c, 'WC', Offset(base.dx, base.dy - 38), 1.6, Pal.white, align: 0);
        if (busy > 0) {
          final wob = (_t * 16).floor().isEven ? 1.0 : -1.0;
          _px(c, base.dx - 17 + wob, base.dy - 56, 6, 6, const Color(0xCC9CE6FF));
          _px(c, base.dx + 12 - wob, base.dy - 60, 4, 4, const Color(0xCC9CE6FF));
        }
      case 2: // ferris wheel
        final hub = base + const Offset(0, -34);
        const steel = Color(0xFF8E8AA3);
        for (var i = 0; i < 9; i++) {
          _px(c, hub.dx - 4 - i * 2, hub.dy + i * 4 - 2, 4, 4, steel);
          _px(c, hub.dx + i * 2, hub.dy + i * 4 - 2, 4, 4, steel);
        }
        for (var i = 0; i < 6; i++) {
          final a = spin + i * pi / 3;
          D.line(c, hub, hub + Offset(cos(a), sin(a)) * 22, const Color(0xFFDDD8F0), 2);
        }
        for (var i = 0; i < 18; i++) {
          final a = spin + i * pi * 2 / 18;
          final p = hub + Offset(cos(a), sin(a)) * 22;
          _px(c, p.dx - 2, p.dy - 2, 4, 4, i.isEven ? Pal.white : const Color(0xFFFF8FD8));
        }
        for (var i = 0; i < 6; i++) {
          final a = spin + i * pi / 3;
          final p = hub + Offset(cos(a), sin(a)) * 22;
          _px(c, p.dx - 4, p.dy + 1, 8, 7, Pal.candy[i + 1]);
          _px(c, p.dx - 3, p.dy + 2, 6, 3, const Color(0xFF3A2440));
        }
        _px(c, hub.dx - 3, hub.dy - 3, 6, 6, Pal.red);
        _px(c, base.dx - 14, base.dy - 5, 28, 5, const Color(0xFF6E6A85));
      case 3: // coaster
        final loop = base + const Offset(6, -32);
        const track = Color(0xFFD83A4A);
        _px(c, loop.dx - 2, loop.dy + 16, 4, base.dy - loop.dy - 16, const Color(0xFF8E8AA3));
        _px(c, base.dx - 18, base.dy - 18, 3, 16, const Color(0xFF8E8AA3));
        for (var i = 0; i < 26; i++) {
          final a = i * pi * 2 / 26;
          final p = loop + Offset(cos(a), sin(a)) * 16;
          _px(c, p.dx - 2, p.dy - 2, 4, 4, track);
        }
        for (var i = 0; i < 6; i++) {
          _px(c, base.dx - 24 + i * 4, base.dy - 10 - i * 1.5, 4, 3, track);
        }
        final cars = [Pal.yellow, Pal.sky, Pal.lime];
        for (var i = 0; i < 3; i++) {
          final a = spin * 2.2 - i * .42;
          final p = loop + Offset(cos(a), sin(a)) * 16;
          _px(c, p.dx - 3, p.dy - 3, 7, 6, cars[i]);
          _px(c, p.dx - 1, p.dy - 5, 3, 2, const Color(0xFFFFCC99));
        }
        _px(c, base.dx - 24, base.dy - 5, 48, 5, const Color(0xFF6E6A85));
        if (busy > 0) {
          PixelFont.draw(c, '!!', Offset(loop.dx + 16, loop.dy - 30), 2, (_t * 10).floor().isEven ? Pal.yellow : Pal.white);
        }
    }
    c.restore();
  }

  void _drawGuest(Canvas c, _Guest g) {
    final feet = g.pos + const Offset(0, 10);
    _px(c, feet.dx - 7, feet.dy - 1, 14, 3, const Color(0x44000000));
    final frame = g.walk.floor() % 2;
    final spr = _gs[g.look * 2 + frame];
    final lift = g.hop * 8;
    final blink = g.angry && (_t * 8).floor().isEven;
    spr.draw(c, Offset((feet.dx - 7.5).roundToDouble(), (feet.dy - 27 - lift).roundToDouble()),
        scale: 3, flipX: g.flip, tint: blink ? const Color(0xFFFF4A4A) : null);
  }

  void _drawBubble(Canvas c, _Guest g) {
    final head = g.pos + Offset(0, -26 - g.hop * 8);
    if (g.angry) {
      _storm.draw(c, head + Offset(-12, -14 + ((_t * 6).floor().isEven ? 0 : 1)), scale: 3);
      return;
    }
    if (g.heart > 0 && g.want < 0) {
      _heart.draw(c, head + Offset(-7, -10 - (1 - g.heart) * 10), scale: 2, opacity: g.heart.clamp(0, 1));
      return;
    }
    if (g.want < 0) return;
    final low = g.patience / g.maxPat < .35;
    final shakeX = low ? ((_t * 30).floor().isEven ? 1.0 : -1.0) : 0.0;
    final s = 1 + g.pop * .5;
    final w = 22 * s, h = 18 * s;
    final r = Rect.fromLTWH((head.dx - w / 2 + shakeX).roundToDouble(), (head.dy - h - 4).roundToDouble(), w, h);
    final border = low ? Pal.red : Pal.ink;
    _px(c, r.left - 2, r.top - 2, r.width + 4, r.height + 4, border);
    _px(c, r.left, r.top, r.width, r.height, Pal.white);
    _px(c, head.dx - 2, r.bottom + 2, 4, 3, border);
    // patience strip
    final pt = (g.patience / g.maxPat).clamp(0.0, 1.0);
    _px(c, r.left, r.bottom - 3, r.width * pt, 3, low ? Pal.red : Pal.lime);
    final ic = r.center + const Offset(0, -1);
    switch (g.want) {
      case 0:
        _burger.drawCentered(c, ic, scale: 2 * s);
      case 1:
        PixelFont.draw(c, 'WC', ic + Offset(0, -3.5 * s), s, Pal.blue, align: 0);
      default:
        _star.drawCentered(c, ic, scale: 2 * s);
    }
  }

  void _hud(Canvas c) {
    _px(c, 0, 38, 360, 84, const Color(0xFF1B1530));
    _px(c, 0, 118, 360, 4, const Color(0xFF3A2F66));
    _px(c, 4, 42, 352, 2, const Color(0xFF3A2F66));
    // cash
    final cash = _shownCash.round();
    final cashOk = _cash >= _target;
    PixelFont.draw(c, '\$$cash', const Offset(16, 52), 4, cashOk ? Pal.lime : Pal.gold, shadow: const Color(0xFF6B3A00));
    PixelFont.draw(c, '/\$$_target', Offset(20 + PixelFont.width('\$$cash', 4), 66), 2, const Color(0xFFB8B0D8));
    final ct = (_shownCash / _target).clamp(0.0, 1.0);
    for (var i = 0; i < 16; i++) {
      final on = i < (ct * 16).floor();
      _px(c, 16 + i * 10, 92, 8, 12, on ? (cashOk ? Pal.lime : Pal.gold) : const Color(0xFF3A2F66));
    }
    // happiness
    final hv = _shownHappy;
    final mood = hv >= _needHappy ? 2 : (hv >= 40 ? 1 : 0);
    final bounce = mood == 2 && (_t * 4).floor().isEven ? -2.0 : 0.0;
    _smiles[mood].draw(c, Offset(192, 50 + bounce), scale: 4);
    PixelFont.draw(c, '${hv.round()}%', const Offset(236, 56), 3, mood == 2 ? Pal.lime : (mood == 1 ? Pal.orange : Pal.red));
    for (var i = 0; i < 10; i++) {
      final on = i < (hv / 10).floor();
      _px(c, 192 + i * 16, 92, 13, 12,
          on ? D.hsv(10 + i * 11.0, .75, 1) : const Color(0xFF3A2F66));
    }
    final tx = 192 + (_needHappy / 10) * 16 - 2;
    _px(c, tx, 86, 3, 24, Pal.white);
    if (cashOk) PixelFont.draw(c, '*', const Offset(160, 50), 3, Pal.lime);
  }

  void _menu(Canvas c) {
    _px(c, 0, 500, 360, 140, const Color(0xFF1B1530));
    _px(c, 0, 500, 360, 4, const Color(0xFF3A2F66));
    for (var i = 0; i < 4; i++) {
      final k = _kinds[i];
      final sel = _sel == i;
      final can = _cash >= k.cost;
      var r = _card(i);
      if (sel) r = r.shift(Offset(0, -6 - 2 * sin(_selBob * 8)));
      final err = _cardErr[i];
      if (err > .01) r = r.shift(Offset(sin(err * 40) * 5 * err, 0));
      if (_nudge > .01 && can) r = r.shift(Offset(0, -sin(_nudge * pi * 3 + i) * 8 * _nudge));
      _px(c, r.left, r.top + 5, r.width, r.height, const Color(0xFF0B0818));
      _px(c, r.left, r.top, r.width, r.height, sel ? Pal.yellow : (err > .1 ? Pal.red : const Color(0xFF5B4E99)));
      _px(c, r.left + 4, r.top + 4, r.width - 8, r.height - 8, can ? const Color(0xFF8FD0FF) : const Color(0xFF4A4560));
      _px(c, r.left + 4, r.top + 60, r.width - 8, r.height - 64, can ? const Color(0xFF7FC24E) : const Color(0xFF3F4A40));
      c.save();
      c.clipRect(r.deflate(4));
      _drawBld(c, i, Offset(r.center.dx, r.top + 70), _t, 0, 0);
      c.restore();
      _px(c, r.left + 4, r.bottom - 26, r.width - 8, 22, const Color(0xFF1B1530));
      PixelFont.draw(c, '\$${k.cost}', Offset(r.center.dx, r.bottom - 21), 2, can ? Pal.gold : const Color(0xFFFF6A6A),
          align: 0);
      // what it satisfies
      final ic = Offset(r.left + 15, r.top + 14);
      _px(c, ic.dx - 10, ic.dy - 9, 20, 18, Pal.white);
      switch (k.want) {
        case 0:
          _burger.drawCentered(c, ic, scale: 2);
        case 1:
          PixelFont.draw(c, 'WC', ic + const Offset(0, -3.5), 1, Pal.blue, align: 0);
        default:
          _star.drawCentered(c, ic, scale: 2);
      }
      if (i == 3) PixelFont.draw(c, 'x2', Offset(r.right - 8, r.top + 8), 1.4, Pal.red, align: 1);
      if (!can) c.drawRect(r, Paint()..color = const Color(0x55000000));
    }
  }
}

class _Kind {
  const _Kind(this.cost, this.pay, this.want, this.joy, this.dur);
  final int cost;
  final int pay;
  final int want;
  final double joy;
  final double dur;
}

class _Bld {
  _Bld(this.kind, this.c, this.r);
  final int kind, c, r;
  double pop = 0;
  double busy = 0;
  double spin = 0;
}

class _Guest {
  _Guest(this.pos, this.c, this.r, this.look)
      : pc = c,
        pr = r;
  Offset pos;
  int c, r, pc, pr;
  final int look;
  final List<(int, int)> route = [];
  int want = -1;
  double wantDelay = 1;
  double patience = 8;
  double maxPat = 8;
  _Bld? inside;
  double insideT = 0;
  int done = 0;
  int maxDone = 2;
  bool leaving = false, exiting = false, angry = false, gone = false, flip = false;
  double walk = 0, hop = 0, heart = 0, pop = 0, spd = 1;
  Offset jitter = Offset.zero;
}
