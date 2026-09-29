import '../engine/engine.dart';

/// No.009 Arrow Escape — tap arrow tiles in the right order so each one can
/// slide off the board. A blocked arrow bonks into its neighbour (-1 heart).
class G009 extends MiniGame {
  static const _cols = 5, _rows = 6;
  static const _cell = 60.0;
  static const _ox = 30.0, _oy = 176.0;
  static const _target = 16;
  static const _dx = [0, 1, 0, -1];
  static const _dy = [-1, 0, 1, 0];
  static const _dirCol = [Pal.sky, Pal.pink, Pal.lime, Pal.orange];

  final List<_Arrow> _arrows = [];
  final List<int> _grid = List.filled(_cols * _rows, -1);
  int _hearts = 3;
  int _left = 0;
  int _combo = 0;
  double _t = 0;
  double _hurt = 0; // mascot shocked timer
  double _joy = 0;
  double _heartShake = 0;
  bool _won = false;
  int _hintIdx = -1;

  @override
  void init() {
    for (var attempt = 0; attempt < 40; attempt++) {
      if (_generate()) break;
    }
    _left = _arrows.length;
    _hintIdx = _arrows.indexWhere((a) => _pathLen(a) < 0);
  }

  bool _generate() {
    _arrows.clear();
    _grid.fillRange(0, _grid.length, -1);
    final cells = List<int>.generate(_cols * _rows, (i) => i)..shuffle(rng);
    for (final cell in cells) {
      if (_arrows.length >= _target) break;
      final c = cell % _cols, r = cell ~/ _cols;
      final dirs = [0, 1, 2, 3]..shuffle(rng);
      for (final d in dirs) {
        // In reverse-removal order, a new arrow only needs its exit ray to be
        // clear of the arrows placed before it → always solvable, no deadlocks.
        var x = c + _dx[d], y = r + _dy[d];
        var clear = true;
        while (x >= 0 && y >= 0 && x < _cols && y < _rows) {
          if (_grid[y * _cols + x] >= 0) {
            clear = false;
            break;
          }
          x += _dx[d];
          y += _dy[d];
        }
        // avoid too many trivially-free edge arrows pointing straight out
        if (clear) {
          _grid[cell] = _arrows.length;
          _arrows.add(_Arrow(c, r, d, rand(0, 6)));
          break;
        }
      }
    }
    return _arrows.length >= _target - 2;
  }

  /// -1 = free to exit, otherwise number of empty cells before the blocker.
  int _pathLen(_Arrow a) {
    var x = a.c + _dx[a.dir], y = a.r + _dy[a.dir];
    var n = 0;
    while (x >= 0 && y >= 0 && x < _cols && y < _rows) {
      if (_grid[y * _cols + x] >= 0) return n;
      n++;
      x += _dx[a.dir];
      y += _dy[a.dir];
    }
    return -1;
  }

  Offset _cellCenter(int c, int r) => Offset(_ox + (c + .5) * _cell, _oy + (r + .5) * _cell);

  @override
  void update(double dt) {
    _t += dt;
    _hurt = max(0, _hurt - dt);
    _joy = max(0, _joy - dt);
    _heartShake = max(0, _heartShake - dt);
    for (final a in _arrows) {
      a.pulse = M.approach(a.pulse, 0, 8, dt);
      a.jiggle = M.approach(a.jiggle, 0, 7, dt);
      if (a.state == 1) {
        a.speed += 2600 * dt;
        a.dist += a.speed * dt;
        if (a.dist > 700) a.state = 3;
        if ((a.dist ~/ 24) != a.trailTick) {
          a.trailTick = a.dist ~/ 24;
          final p = _cellCenter(a.c, a.r) + Offset(_dx[a.dir] * a.dist, _dy[a.dir] * a.dist);
          if (p.dx > -20 && p.dx < 380 && p.dy > 30 && p.dy < 660) {
            host.fx.add(Particle(
                pos: p, vel: Offset(-_dx[a.dir] * 60.0, -_dy[a.dir] * 60.0), life: .3,
                color: _dirCol[a.dir], size: 10, shape: PartShape.square, spin: 6));
          }
        }
      } else if (a.state == 2) {
        a.bumpT += dt;
        const out = .16, back = .34;
        final maxD = a.bumpCells * _cell + 14;
        if (a.bumpT < out) {
          a.dist = maxD * M.easeOut(a.bumpT / out);
        } else if (a.bumpT < out + back) {
          final k = (a.bumpT - out) / back;
          a.dist = maxD * (1 - M.easeOutBack(k));
        } else {
          a.dist = 0;
          a.state = 0;
        }
      }
    }
  }

  void _tap(Offset p) {
    if (_won || host.finished) return;
    final c = ((p.dx - _ox) / _cell).floor(), r = ((p.dy - _oy) / _cell).floor();
    if (c < 0 || r < 0 || c >= _cols || r >= _rows) return;
    final idx = _grid[r * _cols + c];
    if (idx < 0) return;
    final a = _arrows[idx];
    if (a.state != 0) return;
    _hintIdx = -2;
    final len = _pathLen(a);
    final center = _cellCenter(c, r);
    if (len < 0) {
      // escape!
      _grid[r * _cols + c] = -1;
      a.state = 1;
      a.speed = 500;
      _left--;
      _combo++;
      _joy = .5;
      host.sfx(Sfx.whoosh, rate: 1 + min(_combo, 10) * .06);
      host.sfx(Sfx.pop, volume: .6, rate: 1 + min(_combo, 10) * .08);
      host.fx.burst(center, _dirCol[a.dir], count: 12, speed: 200, size: 7, shape: PartShape.star, gravity: 0);
      host.fx.ring(center, Pal.white, size: 50);
      host.addScore(10 * _combo, center);
      if (_combo >= 3) {
        host.fx.pop('${host.tr('combo', 'COMBO')} x$_combo', const Offset(180, 150),
            color: Color.lerp(Pal.yellow, Pal.pink, min(1.0, (_combo - 3) / 6))!, size: 24 + min(_combo, 10).toDouble());
      }
      host.punch(.012);
      if (_left <= 0) {
        _won = true;
        host.sfx(Sfx.fanfare);
        host.fx.confetti(count: 110);
        host.fx.pop(host.tr('clear', 'CLEAR!'), const Offset(180, 330), color: Pal.yellow, size: 44, life: 1.4);
        host.flash(Pal.white, .15);
        host.win(stars: _hearts >= 3 ? 3 : (_hearts == 2 ? 2 : 1));
      }
    } else {
      // BONK
      a.state = 2;
      a.bumpT = 0;
      a.bumpCells = len;
      _combo = 0;
      _hearts--;
      _hurt = .8;
      _heartShake = .4;
      final bx = a.c + _dx[a.dir] * (len + 1), by = a.r + _dy[a.dir] * (len + 1);
      final blocker = _arrows[_grid[by * _cols + bx]];
      blocker.jiggle = 1;
      final hitPt = _cellCenter(a.c, a.r) +
          Offset(_dx[a.dir] * (len + .5) * _cell, _dy[a.dir] * (len + .5) * _cell);
      host.sfx(Sfx.boing);
      host.sfx(Sfx.hurt, volume: .7);
      host.shake(9);
      host.flash(Pal.red, .12);
      host.hitStop(.05);
      host.fx.burst(hitPt, Pal.white, count: 10, speed: 180, shape: PartShape.star, size: 7, gravity: 0);
      host.fx.pop(host.tr('oops', 'OOPS!'), hitPt + const Offset(0, -30), color: Pal.red, size: 26);
      if (_hearts <= 0) {
        host.sfx(Sfx.jingleLose);
        host.lose();
      }
    }
  }

  @override
  void onDown(Offset p) => _tap(p);

  @override
  void onKey(String key, bool down) {
    // Keyboard bonus: action taps the first free arrow (a small cheat for desktop).
    if (!down || key != 'action') return;
    for (final a in _arrows) {
      if (a.state == 0 && _grid[a.r * _cols + a.c] >= 0 && _pathLen(a) < 0) {
        _tap(_cellCenter(a.c, a.r));
        return;
      }
    }
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF2B1B6B), Color(0xFF6A2FA8), Color(0xFFE0548E)]);
    // drifting diagonal stripes
    final stripe = Paint()..color = const Color(0x12FFFFFF);
    final off = (_t * 30) % 80;
    for (var i = -10; i < 14; i++) {
      final x = i * 80.0 + off;
      c.drawPath(
          Path()
            ..moveTo(x, 0)
            ..lineTo(x + 36, 0)
            ..lineTo(x + 36 - 400, 640)
            ..lineTo(x - 400, 640)
            ..close(),
          stripe);
    }
    // faint floating arrows
    for (var i = 0; i < 7; i++) {
      final y = 660 - ((_t * (20 + i * 4) + i * 110) % 720);
      final dir = i % 4;
      c.save();
      c.translate(20 + i * 52.0, y);
      c.rotate(dir * pi / 2);
      _arrowGlyph(c, 12, const Color(0x22FFFFFF), null);
      c.restore();
    }

    _renderHeader(c);

    // board panel
    final board = Rect.fromLTWH(_ox - 12, _oy - 12, _cols * _cell + 24, _rows * _cell + 24);
    D.rrect(c, board.shift(const Offset(0, 8)), 22, const Color(0x55000000));
    D.rrect(c, board, 22, const Color(0xFF1E1440), border: const Color(0xFF0B0720), borderWidth: 4);
    for (var r = 0; r < _rows; r++) {
      for (var col = 0; col < _cols; col++) {
        final o = _cellCenter(col, r);
        D.rrect(c, Rect.fromCenter(center: o, width: _cell - 10, height: _cell - 10), 12, const Color(0xFF2A1F55));
        c.drawCircle(o, 3, D.fill(const Color(0xFF3B2F70)));
      }
    }
    // exit glow on the rim
    final glow = .25 + .15 * sin(_t * 4);
    D.rrect(c, board.deflate(2), 20, const Color(0x00000000),
        border: Color.fromRGBO(255, 230, 120, glow), borderWidth: 3);

    // idle / bumping arrows first, flying ones on top
    for (var i = 0; i < _arrows.length; i++) {
      final a = _arrows[i];
      if (a.state == 0 || a.state == 2) _drawTile(c, a);
    }
    for (final a in _arrows) {
      if (a.state == 1) _drawTile(c, a);
    }

    // tutorial
    if (_hintIdx >= 0 && host.time < 2.6 && !host.finished) {
      final a = _arrows[_hintIdx];
      final o = _cellCenter(a.c, a.r);
      final k = M.wave(_t, 2);
      c.drawCircle(o, 30 + k * 8, D.stroke(Color.fromRGBO(255, 255, 255, .8 - k * .5), 4));
      D.hand(c, o + const Offset(4, 8), _t);
    }

    if (host.finished && _won) {
      final k = M.clamp01(_t * 2 % 1);
      c.drawCircle(const Offset(180, 356), 60 + k * 160, D.stroke(Color.fromRGBO(255, 240, 150, 1 - k), 6));
    }
  }

  void _renderHeader(Canvas c) {
    // hearts
    for (var i = 0; i < 3; i++) {
      final alive = i < _hearts;
      final sh = (_heartShake > 0 && i == _hearts) ? sin(_t * 60) * 5 : 0.0;
      final o = Offset(36 + i * 36.0 + sh, 70);
      D.heart(c, o + const Offset(0, 3), 30, const Color(0x55000000));
      D.heart(c, o, 30, alive ? Pal.red : const Color(0xFF4A3B6B), border: Pal.ink);
      if (alive) c.drawCircle(o + const Offset(-6, -5), 3.5, D.fill(const Color(0x99FFFFFF)));
    }
    // remaining counter
    final rc = const Rect.fromLTWH(262, 50, 82, 42);
    D.rrect(c, rc.shift(const Offset(0, 4)), 14, const Color(0x55000000));
    D.rrect(c, rc, 14, Pal.cream, border: Pal.ink, borderWidth: 3);
    c.save();
    c.translate(282, 71);
    _arrowGlyph(c, 11, Pal.purple, Pal.ink);
    c.restore();
    D.text(c, '$_left', const Offset(318, 71), size: 26, color: Pal.ink);

    // mascot: a little tile-guy on the board rim reacting to everything
    final face = host.finished && !_won
        ? Face.cry
        : (_hurt > 0 ? Face.shocked : (_won ? Face.love : (_joy > 0 && _combo >= 3 ? Face.love : Face.happy)));
    final bob = sin(_t * 5) * 3 - (_joy > 0 ? 6 * sin(_joy / .5 * pi) : 0);
    final sq = _hurt > 0 ? 1.15 : 1.0;
    D.shadow(c, const Offset(180, 160), 54, 10, .35);
    D.blob(c, Offset(180 + (_hurt > 0 ? sin(_t * 50) * 3 : 0), 128 + bob), 30, Pal.yellow, face: face, squash: sq);
    if (_hurt > 0) {
      for (var i = 0; i < 3; i++) {
        final a = _t * 6 + i * 2.1;
        D.star(c, Offset(180 + cos(a) * 34, 96 + sin(a) * 8), 6, Pal.yellow, border: Pal.ink);
      }
    }
  }

  void _drawTile(Canvas c, _Arrow a) {
    final base = _cellCenter(a.c, a.r);
    var o = base + Offset(_dx[a.dir] * a.dist, _dy[a.dir] * a.dist);
    if (a.jiggle > 0) o += Offset(sin(_t * 70) * 4 * a.jiggle, cos(_t * 55) * 3 * a.jiggle);
    final col = _dirCol[a.dir];
    const s = _cell - 8;
    c.save();
    c.translate(o.dx, o.dy);
    // stretch along travel direction when flying
    if (a.state == 1) {
      final double st = 1 + min(.6, a.speed / 4000).toDouble();
      if (a.dir.isEven) {
        c.scale(1 / sqrt(st), st);
      } else {
        c.scale(st, 1 / sqrt(st));
      }
    }
    // idle breathing
    final br = a.state == 0 ? 1 + .025 * sin(_t * 3 + a.phase) : 1.0;
    c.scale(br);
    final dark = Color.lerp(col, Pal.ink, .45)!;
    D.rrect(c, Rect.fromCenter(center: const Offset(0, 5), width: s, height: s), 14, dark);
    D.rrect(c, Rect.fromCenter(center: Offset.zero, width: s, height: s), 14, col, border: Pal.ink, borderWidth: 3);
    D.rrect(c, Rect.fromLTWH(-s / 2 + 6, -s / 2 + 4, s - 12, s * .3), 8, const Color(0x55FFFFFF));
    c.rotate(a.dir * pi / 2);
    _arrowGlyph(c, 17, Pal.white, Pal.ink);
    c.restore();
    if (a.state == 1) {
      // speed lines
      final p = D.stroke(const Color(0x88FFFFFF), 3);
      for (var i = -1; i <= 1; i++) {
        final n = Offset(-_dy[a.dir] * i * 14.0, _dx[a.dir] * i * 14.0);
        final back = Offset(-_dx[a.dir].toDouble(), -_dy[a.dir].toDouble());
        c.drawLine(o + n + back * 36, o + n + back * (60 + a.speed * .03), p);
      }
    }
  }

  /// Arrow glyph pointing up, centered at origin.
  void _arrowGlyph(Canvas c, double r, Color fillC, Color? outline) {
    final path = Path()
      ..moveTo(0, -r * 1.15)
      ..lineTo(r * .95, -r * .1)
      ..lineTo(r * .38, -r * .1)
      ..lineTo(r * .38, r * 1.05)
      ..lineTo(-r * .38, r * 1.05)
      ..lineTo(-r * .38, -r * .1)
      ..lineTo(-r * .95, -r * .1)
      ..close();
    if (outline != null) c.drawPath(path, D.stroke(outline, r * .28));
    c.drawPath(path, D.fill(fillC));
  }
}

class _Arrow {
  _Arrow(this.c, this.r, this.dir, this.phase);
  final int c, r, dir;
  final double phase;
  int state = 0; // 0 idle, 1 flying, 2 bumping, 3 gone
  double dist = 0;
  double speed = 0;
  double bumpT = 0;
  int bumpCells = 0;
  double pulse = 0;
  double jiggle = 0;
  int trailTick = 0;
}
