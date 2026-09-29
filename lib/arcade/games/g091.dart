import '../engine/engine.dart';

/// No.091 Maze Muncher — 8-bit maze chomper.
///
/// Swipe (or tap beside the muncher / arrow keys) to steer. Eat every dot.
/// Two ghosts chase (one hunts you, one ambushes ahead of you). Power
/// pellets turn them blue & edible for a few seconds. 2 lives.
class G091 extends MiniGame {
  static const _map = [
    '###########',
    '#o...#...o#',
    '#.##.#.##.#',
    '#.........#',
    '#.##.#.##.#',
    '#....#....#',
    '#### # ####',
    '     G     ',
    '#### # ####',
    '#....#....#',
    '#.##   ##.#',
    '#o.#.#.#.o#',
    '##.#.#.#.##',
    '#....P....#',
    '###########',
  ];
  static const _cols = 11, _rows = 15;
  static const _cell = 28.0;
  static const _ox = 26.0, _oy = 112.0;
  static const _dirs = [Offset(1, 0), Offset(0, 1), Offset(-1, 0), Offset(0, -1)]; // R D L U

  late List<List<int>> _dots; // 0 none, 1 dot, 2 power
  int _left = 0;
  int _total = 1;
  late _Ent _pac;
  final List<_Ghost> _ghosts = [];
  int _want = 2;
  double _t = 0;
  double _fright = 0;
  int _ghostChain = 0;
  int _lives = 2;
  double _dieT = 0;
  double _chompT = 0;
  int _chompN = 0;
  double _hint = 2.4;
  Offset? _down;
  final _pops = _Pops();
  double _winT = 0;

  @override
  void init() {
    _dots = List.generate(_rows, (r) => List.generate(_cols, (c) {
          final ch = _map[r][c];
          return ch == '.' ? 1 : (ch == 'o' ? 2 : 0);
        }));
    for (final row in _dots) {
      for (final v in row) {
        if (v > 0) _left++;
      }
    }
    _total = _left;
    _reset();
  }

  void _reset() {
    _pac = _Ent(5, 13, 2);
    _want = 2;
    _ghosts
      ..clear()
      ..add(_Ghost(5, 7, 2, 0, .6))
      ..add(_Ghost(5, 7, 0, 1, 3.2));
    _fright = 0;
  }

  bool _open(int c, int r) {
    if (r < 0 || r >= _rows) return false;
    if (c < 0 || c >= _cols) return r == 7; // tunnel
    return _map[r][c] != '#';
  }

  bool _canGo(_Ent e, int d) => _open(e.c + _dirs[d].dx.toInt(), e.r + _dirs[d].dy.toInt());

  Offset _pos(_Ent e) {
    final d = _dirs[e.d];
    var x = e.c + (e.moving ? d.dx * e.t : 0);
    final y = e.r + (e.moving ? d.dy * e.t : 0);
    if (x < -.5) x += _cols;
    if (x > _cols - .5) x -= _cols;
    return Offset(_ox + (x + .5) * _cell, _oy + (y + .5) * _cell);
  }

  // --------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) => _down = p;

  @override
  void onMove(Offset p) {
    final a = _down;
    if (a == null) return;
    final d = p - a;
    if (d.distance > 24) {
      _setWant(d);
      _down = p;
    }
  }

  @override
  void onUp(Offset p) {
    final a = _down;
    _down = null;
    if (a == null) return;
    if ((p - a).distance < 12) {
      final rel = p - _pos(_pac);
      if (rel.distance > 20) _setWant(rel);
    }
  }

  void _setWant(Offset d) {
    _want = d.dx.abs() > d.dy.abs() ? (d.dx > 0 ? 0 : 2) : (d.dy > 0 ? 1 : 3);
    _hint = 0;
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    const m = {'right': 0, 'down': 1, 'left': 2, 'up': 3};
    final d = m[key];
    if (d != null) {
      _want = d;
      _hint = 0;
    }
  }

  // -------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    _hint = max(0, _hint - dt);
    _pops.update(dt);
    if (host.finished) {
      _winT += dt;
      return;
    }
    if (_dieT > 0) {
      _dieT -= dt;
      if (_dieT <= 0) {
        if (_lives <= 0) {
          host.lose();
        } else {
          _reset();
        }
      }
      return;
    }
    _fright = max(0, _fright - dt);
    if (_fright <= 0) _ghostChain = 0;
    // player
    _movePac(dt);
    // ghosts
    final gs = 4.7 * sqrt(host.speed);
    for (final g in _ghosts) {
      if (g.wait > 0) {
        g.wait -= dt;
        continue;
      }
      final sp = g.eaten ? 13.0 : (_fright > 0 ? 3.8 : gs + (g.kind == 0 ? .3 : 0));
      _moveGhost(g, sp * dt);
      // collide
      if (!g.eaten && (_pos(g) - _pos(_pac)).distance < _cell * .52) {
        if (_fright > 0 && g.scared) {
          g.eaten = true;
          g.scared = false;
          _ghostChain++;
          final pts = 200 * _ghostChain;
          host.addScore(pts);
          host.sfx(Sfx.pExplode, volume: .6);
          host.sfx(Sfx.chomp, rate: 1.3);
          host.hitStop(.12);
          host.shake(5);
          _pops.add('$pts', _pos(g), const Color(0xFF6FF0FF), 3);
          host.fx.burst(_pos(g), const Color(0xFF3D6BFF), count: 14, speed: 200, shape: PartShape.square, size: 5);
        } else {
          _die();
          return;
        }
      }
    }
  }

  void _movePac(double dt) {
    final e = _pac;
    // instant reverse
    if (e.moving && _want == (e.d + 2) % 4) {
      e.c += _dirs[e.d].dx.toInt();
      e.r += _dirs[e.d].dy.toInt();
      e.d = _want;
      e.t = 1 - e.t;
    }
    if (!e.moving) {
      if (_canGo(e, _want)) {
        e.d = _want;
        e.moving = true;
        e.t = 0;
      } else if (_canGo(e, e.d)) {
        e.moving = true;
        e.t = 0;
      } else {
        return;
      }
    }
    e.t += 10.5 * dt;
    while (e.t >= 1 && e.moving) {
      e.t -= 1;
      e.c += _dirs[e.d].dx.toInt();
      e.r += _dirs[e.d].dy.toInt();
      if (e.c < 0) e.c += _cols;
      if (e.c >= _cols) e.c -= _cols;
      _eat(e.c, e.r);
      if (_canGo(e, _want)) {
        e.d = _want;
      } else if (!_canGo(e, e.d)) {
        e.moving = false;
        e.t = 0;
      }
    }
    if (e.moving) {
      _chompT += dt;
    }
  }

  void _eat(int c, int r) {
    if (c < 0 || c >= _cols) return;
    final v = _dots[r][c];
    if (v == 0) return;
    _dots[r][c] = 0;
    _left--;
    final at = Offset(_ox + (c + .5) * _cell, _oy + (r + .5) * _cell);
    if (v == 2) {
      _fright = 4.2;
      _ghostChain = 0;
      for (final g in _ghosts) {
        if (!g.eaten) {
          g.scared = true;
          g.d = (g.d + 2) % 4;
        }
      }
      host.sfx(Sfx.pPowerup);
      host.flash(const Color(0xFF3D6BFF), .12);
      host.shake(4);
      host.addScore(50, at);
      _pops.add(host.tr('power', 'POWER!'), at - const Offset(0, 20), Pal.yellow, 3);
      host.fx.ring(at, Pal.yellow, size: 60);
    } else {
      _chompN++;
      host.sfx(Sfx.pCoin, volume: .35, rate: _chompN.isEven ? 1.0 : 1.18);
      host.addScore(10);
      host.fx.burst(at, const Color(0xFFFFE8B0), count: 3, speed: 80, shape: PartShape.square, size: 3, gravity: 0, life: .25);
    }
    if (_left == 0) {
      host.sfx(Sfx.jingleWin);
      host.fx.confetti();
      host.flash(Pal.white, .15);
      host.win(stars: _lives >= 2 ? (host.timeLeft > 3 ? 3 : 2) : 1);
      _pops.add(host.tr('clear', 'CLEAR!'), const Offset(180, 320), Pal.yellow, 5);
    }
  }

  void _moveGhost(_Ghost g, double step) {
    if (!g.moving) {
      g.moving = true;
      g.t = 0;
      g.d = _chooseDir(g);
    }
    g.t += step;
    while (g.t >= 1) {
      g.t -= 1;
      g.c += _dirs[g.d].dx.toInt();
      g.r += _dirs[g.d].dy.toInt();
      if (g.c < 0) g.c += _cols;
      if (g.c >= _cols) g.c -= _cols;
      if (g.eaten && g.c == 5 && g.r == 7) {
        g.eaten = false;
        g.scared = false;
        host.sfx(Sfx.pSelect, volume: .4);
      }
      g.d = _chooseDir(g);
    }
  }

  int _chooseDir(_Ghost g) {
    final opts = <int>[];
    for (var d = 0; d < 4; d++) {
      if (d == (g.d + 2) % 4) continue;
      if (_canGo(g, d)) opts.add(d);
    }
    if (opts.isEmpty) return (g.d + 2) % 4;
    if (g.scared && _fright > 0 && !g.eaten) return pick(opts);
    Offset target;
    if (g.eaten) {
      target = const Offset(5, 7);
    } else if (g.kind == 0) {
      target = Offset(_pac.c.toDouble(), _pac.r.toDouble());
    } else {
      final pd = _dirs[_pac.d];
      target = Offset(_pac.c + pd.dx * 3, _pac.r + pd.dy * 3);
    }
    if (!g.eaten && chance(.18)) return pick(opts);
    var best = opts.first;
    var bd = double.infinity;
    for (final d in opts) {
      final n = Offset(g.c + _dirs[d].dx, g.r + _dirs[d].dy);
      final dd = (n - target).distanceSquared;
      if (dd < bd) {
        bd = dd;
        best = d;
      }
    }
    return best;
  }

  void _die() {
    _lives--;
    _dieT = 1.3;
    host.sfx(Sfx.pDie);
    host.shake(8);
    host.flash(Pal.red, .12);
    host.hitStop(.15);
    _pops.add(host.tr('oops', 'OOPS!'), _pos(_pac) - const Offset(0, 24), Pal.red, 3);
  }

  // -------------------------------------------------------------- render ---
  static final Paint _pp = Paint()..isAntiAlias = false;
  void _r(Canvas c, double l, double t, double w, double h, Color col) {
    _pp.color = col;
    c.drawRect(Rect.fromLTWH(l, t, w, h), _pp);
  }

  @override
  void render(Canvas c) {
    _r(c, 0, 0, 360, 640, const Color(0xFF07071A));
    // starfield backdrop
    for (var i = 0; i < 40; i++) {
      final x = (i * 83) % 360.0;
      final y = 40 + (i * 131) % 600.0;
      if (((_t * 1.5 + i * .3) % 2) < 1.6) _r(c, x, y, 2, 2, const Color(0xFF30305A));
    }
    _drawMaze(c);
    // dots
    for (var r = 0; r < _rows; r++) {
      for (var col = 0; col < _cols; col++) {
        final v = _dots[r][col];
        if (v == 0) continue;
        final cx = _ox + (col + .5) * _cell, cy = _oy + (r + .5) * _cell;
        if (v == 1) {
          _r(c, cx - 3, cy - 3, 6, 6, const Color(0xFFFFD8B0));
        } else if ((_t * 4).floor().isEven) {
          _S.pellet.drawCentered(c, Offset(cx, cy), scale: 2);
        }
      }
    }
    // ghosts
    for (final g in _ghosts) {
      final p = _pos(g) + Offset(0, g.wait > 0 ? sin(_t * 8) * 3 : 0);
      final frame = (_t * 8).floor().isEven;
      if (g.eaten) {
        _drawEyes(c, p, g.d);
        continue;
      }
      if (g.scared && _fright > 0) {
        final blink = _fright < 1.2 && (_t * 8).floor().isEven;
        (frame ? _S.scared1 : _S.scared2).drawCentered(c, p, scale: 2, tint: blink ? const Color(0xFFF2F2FF) : null);
        if (blink) (frame ? _S.scaredFace : _S.scaredFace).drawCentered(c, p, scale: 2);
      } else {
        final spr = g.kind == 0 ? (frame ? _S.ghostA1 : _S.ghostA2) : (frame ? _S.ghostB1 : _S.ghostB2);
        spr.drawCentered(c, p, scale: 2);
        _drawEyes(c, p, g.d);
      }
    }
    _drawPac(c);
    _drawHud(c);
    _pops.render(c);
    if (_hint > 0 && host.time < 2.4) {
      final p = _pos(_pac);
      D.hand(c, p + Offset(-30 + sin(_t * 3) * 30, 40), _t);
      D.arrow(c, p + const Offset(-50, 0), const Offset(-1, 0), 28, Pal.yellow, width: 8);
      D.arrow(c, p + const Offset(50, 0), const Offset(1, 0), 28, Pal.yellow, width: 8);
      D.arrow(c, p + const Offset(0, -46), const Offset(0, -1), 28, Pal.yellow, width: 8);
      _pt(c, host.tr('swipe', 'SWIPE'), p + const Offset(0, 90), 3, Pal.white);
    }
    Retro.scanlines(c, alpha: .16);
    Retro.vignette(c, strength: .4);
  }

  void _drawMaze(Canvas c) {
    const fill = Color(0xFF12124A);
    final edge = host.finished && (_winT * 8).floor().isEven ? const Color(0xFFFFFFFF) : const Color(0xFF3D6BFF);
    const edgeHi = Color(0xFF8FB0FF);
    for (var r = 0; r < _rows; r++) {
      for (var col = 0; col < _cols; col++) {
        if (_map[r][col] != '#') continue;
        final x = _ox + col * _cell, y = _oy + r * _cell;
        _r(c, x, y, _cell, _cell, fill);
        bool wall(int cc, int rr) => rr < 0 || rr >= _rows || cc < 0 || cc >= _cols || _map[rr][cc] == '#';
        const e = 4.0;
        if (!wall(col, r - 1)) _r(c, x, y, _cell, e, edge);
        if (!wall(col, r + 1)) _r(c, x, y + _cell - e, _cell, e, edge);
        if (!wall(col - 1, r)) _r(c, x, y, e, _cell, edge);
        if (!wall(col + 1, r)) _r(c, x + _cell - e, y, e, _cell, edge);
        // inner highlight pixel
        if (!wall(col, r - 1)) _r(c, x + 6, y + 6, 4, 2, edgeHi);
      }
    }
    // tunnel mouths
    _r(c, 0, _oy + 7 * _cell - 4, _ox, 4, edge);
    _r(c, 0, _oy + 8 * _cell, _ox, 4, edge);
    _r(c, _ox + _cols * _cell, _oy + 7 * _cell - 4, _ox, 4, edge);
    _r(c, _ox + _cols * _cell, _oy + 8 * _cell, _ox, 4, edge);
  }

  void _drawEyes(Canvas c, Offset p, int d) {
    final look = _dirs[d] * 2;
    for (final sx in const [-6.0, 6.0]) {
      final e = p + Offset(sx, -3);
      _r(c, e.dx - 4, e.dy - 5, 8, 10, Pal.white);
      _r(c, e.dx - 2 + look.dx, e.dy - 2 + look.dy, 4, 4, const Color(0xFF1B2A8C));
    }
  }

  void _drawPac(Canvas c) {
    final p = _pos(_pac);
    if (_dieT > 0) {
      final k = 1 - _dieT / 1.3;
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(k * pi * 4);
      c.scale(max(0.0, 1 - k * 1.1));
      _S.pac0.drawCentered(c, Offset.zero, scale: 2);
      c.restore();
      if (k > .6) {
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4;
          final rr = (k - .6) * 60;
          _r(c, p.dx + cos(a) * rr - 2, p.dy + sin(a) * rr - 2, 4, 4, Pal.yellow);
        }
      }
      return;
    }
    final phase = _pac.moving ? ((_chompT * 14).floor() % 4) : 1;
    final spr = switch (phase) { 0 => _S.pac0, 1 => _S.pac1, 2 => _S.pac2, _ => _S.pac1 };
    c.save();
    c.translate(p.dx, p.dy);
    final d = _pac.d;
    if (d == 1) c.rotate(pi / 2);
    if (d == 3) c.rotate(-pi / 2);
    spr.drawCentered(c, Offset.zero, scale: 2, flipX: d == 2);
    c.restore();
    if (host.finished) {
      D.rays(c, p, 80, const Color(0x44FFE14A), count: 10, t: _t * 2);
    }
  }

  void _drawHud(Canvas c) {
    // dots left
    const y = 48.0;
    _S.pellet.draw(c, const Offset(14, y + 2), scale: 2);
    PixelFont.draw(c, '$_left', const Offset(38, y + 2), 3, Pal.white, shadow: const Color(0xFF3D6BFF));
    // score
    PixelFont.draw(c, '${host.score}'.padLeft(5, '0'), const Offset(180, y + 2), 3, Pal.yellow, align: 0, shadow: const Color(0xFF7A3A00));
    // lives
    for (var i = 0; i < 2; i++) {
      _S.pac1.draw(c, Offset(300.0 + i * 28, y), scale: 2, tint: i < _lives ? null : const Color(0xFF30305A));
    }
    // progress bar under the maze
    {
      const bar = Rect.fromLTWH(26, 546, 308, 10);
      _r(c, bar.left - 2, bar.top - 2, bar.width + 4, bar.height + 4, const Color(0xFF3D6BFF));
      _r(c, bar.left, bar.top, bar.width, bar.height, const Color(0xFF12124A));
      final k = 1 - _left / _total;
      _r(c, bar.left, bar.top, bar.width * k.clamp(0.0, 1.0), bar.height, Pal.yellow);
      for (var x = bar.left; x < bar.left + bar.width * k.clamp(0.0, 1.0); x += 8) {
        _r(c, x, bar.top, 4, 3, const Color(0xFFFFF3B0));
      }
    }
    if (_fright > 0) {
      _pt(c, '${_fright.ceil()}', const Offset(180, 580), 4, (_t * 6).floor().isEven ? const Color(0xFF6FF0FF) : Pal.white);
    }
  }
}

class _Ent {
  _Ent(this.c, this.r, this.d);
  int c, r, d;
  double t = 0;
  bool moving = false;
}

class _Ghost extends _Ent {
  _Ghost(super.c, super.r, super.d, this.kind, this.wait);
  final int kind;
  double wait;
  bool scared = false;
  bool eaten = false;
}

class _Pops {
  final List<(String, Offset, Color, double, double)> _l = [];
  void add(String s, Offset at, Color col, [double scale = 3]) {
    if (_l.length < 6) _l.add((s, at, col, scale, 0));
  }

  void update(double dt) {
    for (var i = _l.length - 1; i >= 0; i--) {
      final e = _l[i];
      if (e.$5 + dt > 1.0) {
        _l.removeAt(i);
      } else {
        _l[i] = (e.$1, e.$2 - Offset(0, 24 * dt), e.$3, e.$4, e.$5 + dt);
      }
    }
  }

  void render(Canvas c) {
    for (final e in _l) {
      if (e.$5 > .75 && ((e.$5 * 20).floor().isEven)) continue;
      _pt(c, e.$1, e.$2, e.$5 < .08 ? e.$4 + 1 : e.$4, e.$3);
    }
  }
}

final _asciiRe = RegExp(r"^[A-Za-z0-9 !?.,:\-+/%$*<>=#'()]*$");

void _pt(Canvas c, String s, Offset center, double scale, Color col) {
  if (_asciiRe.hasMatch(s)) {
    PixelFont.draw(c, s, center - Offset(0, 3.5 * scale), scale, col, align: 0, shadow: const Color(0xFF10122A));
  } else {
    D.text(c, s, center, size: 8 * scale, color: col, stroke: const Color(0xFF10122A), strokeWidth: scale * 1.5);
  }
}

abstract final class _S {
  static const _pp = <String, Color>{
    'Y': Color(0xFFFFE14A),
    'y': Color(0xFFE8A81A),
    'W': Color(0xFFFFFFFF),
    'K': Color(0xFF10122A),
    'R': Color(0xFFFF3B5C),
  };
  // facing right; R = little red cap
  static final pac0 = Sprite(const [
    '....RRRRR....',
    '..RRRRRRRRR..',
    '.RYYYYYYYYYR.',
    '.YYYYYYKYYYY.',
    'YYYYYYYKYYYYY',
    'YYYYYYYYYYYYY',
    'YYYYYYYYYYYYY',
    'YYYYYYYYYYYYY',
    'YYYYYYYYYYYYY',
    '.YYYYYYYYYYy.',
    '.yYYYYYYYYYy.',
    '..yyYYYYYyy..',
    '....yyyyy....',
  ], _pp);
  static final pac1 = Sprite(const [
    '....RRRRR....',
    '..RRRRRRRRR..',
    '.RYYYYYYYYYR.',
    '.YYYYYYKYYYY.',
    'YYYYYYYKYYYYY',
    'YYYYYYYYYYY..',
    'YYYYYYYY.....',
    'YYYYYYYYYYY..',
    'YYYYYYYYYYYYY',
    '.YYYYYYYYYYy.',
    '.yYYYYYYYYYy.',
    '..yyYYYYYyy..',
    '....yyyyy....',
  ], _pp);
  static final pac2 = Sprite(const [
    '....RRRRR....',
    '..RRRRRRRRR..',
    '.RYYYYYYYYYR.',
    '.YYYYYYKYYY..',
    'YYYYYYYKYY...',
    'YYYYYYYYY....',
    'YYYYYYY......',
    'YYYYYYYYY....',
    'YYYYYYYYYY...',
    '.YYYYYYYYYY..',
    '.yYYYYYYYYYy.',
    '..yyYYYYYyy..',
    '....yyyyy....',
  ], _pp);

  static List<String> _ghost(bool alt) => [
        '.....GGGG.....',
        '...GGGGGGGG...',
        '..GGGGGGGGGG..',
        '.GGGGGGGGGGGG.',
        '.GGGGGGGGGGGG.',
        'GGGGGGGGGGGGGG',
        'GGGGGGGGGGGGGG',
        'GGGGGGGGGGGGGG',
        'GGGGGGGGGGGGGG',
        'GGGGGGGGGGGGGG',
        'GGGGGGGGGGGGGG',
        'GGGGGGGGGGGGGG',
        alt ? 'GG.GGG..GGG.GG' : 'GGGG.GGGG.GGGG',
        alt ? 'G...GG..GG...G' : '.GG...GG...GG.',
      ];
  static final ghostA1 = Sprite(_ghost(false), const {'G': Color(0xFFFF5FC8)});
  static final ghostA2 = Sprite(_ghost(true), const {'G': Color(0xFFFF5FC8)});
  static final ghostB1 = Sprite(_ghost(false), const {'G': Color(0xFF3FE0D0)});
  static final ghostB2 = Sprite(_ghost(true), const {'G': Color(0xFF3FE0D0)});
  static const _sp = {'G': Color(0xFF2A3AE8), 'W': Color(0xFFFFD8B0)};
  static List<String> _scared(bool alt) => [
        '.....GGGG.....',
        '...GGGGGGGG...',
        '..GGGGGGGGGG..',
        '.GGGGGGGGGGGG.',
        '.GGGWWGGWWGGG.',
        'GGGGWWGGWWGGGG',
        'GGGGGGGGGGGGGG',
        'GGGGGGGGGGGGGG',
        'GGWWGGWWGGWWGG',
        'GWGGWWGGWWGGWG',
        'GGGGGGGGGGGGGG',
        'GGGGGGGGGGGGGG',
        alt ? 'GG.GGG..GGG.GG' : 'GGGG.GGGG.GGGG',
        alt ? 'G...GG..GG...G' : '.GG...GG...GG.',
      ];
  static final scared1 = Sprite(_scared(false), _sp);
  static final scared2 = Sprite(_scared(true), _sp);
  static final scaredFace = Sprite(const [
    '..............',
    '..............',
    '..............',
    '..............',
    '....RR..RR....',
    '....RR..RR....',
    '..............',
    '..............',
    '..RR..RR..RR..',
    '.R..RR..RR..R.',
  ], const {'R': Color(0xFFFF3B5C)});
  static final pellet = Sprite(const [
    '..WWW..',
    '.WWWWW.',
    'WWWWWWW',
    'WWWWWWW',
    'WWWWWWW',
    '.WWWWW.',
    '..WWW..',
  ], const {'W': Color(0xFFFFD8B0)});
}
