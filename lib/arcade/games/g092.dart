import '../engine/engine.dart';

/// No.092 Block Drop — falling tetromino puzzle on a pre-filled 10x16 well.
///
/// Controls: drag sideways to slide, tap the piece to rotate, tap left/right
/// of it to nudge, swipe down to hard drop (plus the 4 pixel buttons and
/// arrow keys). The well is pre-filled with a "hole" column — clear 3 lines
/// => win. Topping out => lose.
class G092 extends MiniGame {
  static const _w = 10, _h = 16;
  static const _cs = 24.0;
  static const _bx = 16.0, _by = 96.0;
  static const _goal = 3;

  // 0 empty, 1..7 piece colors, 8 garbage
  final List<List<int>> _grid = List.generate(_h, (_) => List.filled(_w, 0));
  final List<int> _queue = [];
  late _Piece _cur;
  double _t = 0, _fall = 0, _lock = 0;
  int _lines = 0;
  // clear animation
  List<int> _clearing = [];
  double _clearT = 0;
  double _land = 0;
  int _combo = 0;
  double _bigText = 0;
  String _bigWord = '';
  Color _bigCol = Pal.yellow;
  double _mood = 0; // >0 happy flash
  // input
  Offset? _down;
  double _anchorX = 0;
  bool _moved = false;
  bool _dropped = false;
  int _btn = -1;
  double _btnFlash = 0;
  bool _dead = false;

  static const _shapes = <List<List<int>>>[
    // I
    [[0, 1], [1, 1], [2, 1], [3, 1]],
    // O
    [[1, 0], [2, 0], [1, 1], [2, 1]],
    // T
    [[1, 0], [0, 1], [1, 1], [2, 1]],
    // S
    [[1, 0], [2, 0], [0, 1], [1, 1]],
    // Z
    [[0, 0], [1, 0], [1, 1], [2, 1]],
    // J
    [[0, 0], [0, 1], [1, 1], [2, 1]],
    // L
    [[2, 0], [0, 1], [1, 1], [2, 1]],
  ];
  static const _cols = <Color>[
    Color(0xFF000000),
    Color(0xFF3FE0F0), // I cyan
    Color(0xFFFFD23F), // O yellow
    Color(0xFFB05AE8), // T purple
    Color(0xFF4CC43A), // S green
    Color(0xFFE8453C), // Z red
    Color(0xFF3F6FE8), // J blue
    Color(0xFFFF8A1F), // L orange
    Color(0xFF7A7F9A), // garbage
  ];

  @override
  void init() {
    const pre = [
      '.......##.',
      '###...###.',
      '####.####.',
      '#########.',
      '#########.',
    ];
    for (var i = 0; i < pre.length; i++) {
      final r = _h - pre.length + i;
      for (var c = 0; c < _w; c++) {
        if (pre[i][c] == '#') _grid[r][c] = chance(.35) ? 8 : 1 + randInt(7);
      }
    }
    final first = [0, 2, 6]..shuffle(rng);
    final rest = [1, 3, 4, 5]..shuffle(rng);
    _queue
      ..addAll(first)
      ..addAll(rest);
    _spawn();
  }

  void _refill() {
    if (_queue.length < 3) {
      final bag = List.generate(7, (i) => i)..shuffle(rng);
      _queue.addAll(bag);
    }
  }

  void _spawn() {
    _refill();
    final k = _queue.removeAt(0);
    _refill();
    _cur = _Piece(k, 3, k == 0 ? -1 : 0, 0);
    _fall = 0;
    _lock = 0;
    if (_collides(_cur)) {
      _dead = true;
      host.sfx(Sfx.pDie);
      host.sfx(Sfx.crash, volume: .6);
      host.shake(10);
      host.flash(Pal.red, .2);
      host.lose();
    }
  }

  List<List<int>> _cells(_Piece p) {
    final base = _shapes[p.k];
    final size = p.k == 0 ? 4 : 3;
    final out = <List<int>>[];
    for (final b in base) {
      var x = b[0], y = b[1];
      if (p.k != 1) {
        for (var r = 0; r < p.rot; r++) {
          final nx = size - 1 - y;
          final ny = x;
          x = nx;
          y = ny;
        }
      }
      out.add([p.x + x, p.y + y]);
    }
    return out;
  }

  bool _collides(_Piece p) {
    for (final c in _cells(p)) {
      if (c[0] < 0 || c[0] >= _w || c[1] >= _h) return true;
      if (c[1] >= 0 && _grid[c[1]][c[0]] != 0) return true;
    }
    return false;
  }

  bool _busy() => _clearing.isNotEmpty || _dead || host.finished;

  void _move(int dx) {
    if (_busy()) return;
    final n = _cur.copy()..x += dx;
    if (!_collides(n)) {
      _cur = n;
      _lock = 0;
      host.sfx(Sfx.pSelect, volume: .35, rate: 1.6);
    } else {
      host.sfx(Sfx.tick, volume: .4, rate: .7);
    }
  }

  void _rotate() {
    if (_busy()) return;
    for (final kick in const [[0, 0], [-1, 0], [1, 0], [-2, 0], [2, 0], [0, -1]]) {
      final n = _cur.copy()
        ..rot = (_cur.rot + 1) % 4
        ..x += kick[0]
        ..y += kick[1];
      if (!_collides(n)) {
        _cur = n;
        _lock = 0;
        host.sfx(Sfx.pJump, volume: .4, rate: 1.5);
        return;
      }
    }
    host.sfx(Sfx.tick, volume: .4, rate: .6);
  }

  void _hardDrop() {
    if (_busy()) return;
    var n = 0;
    while (true) {
      final d = _cur.copy()..y += 1;
      if (_collides(d)) break;
      _cur = d;
      n++;
    }
    host.addScore(n * 2);
    host.sfx(Sfx.pHit);
    host.shake(3 + n * .3);
    // trail
    for (final c in _cells(_cur)) {
      host.fx.burst(_cellCenter(c[0], c[1]), _cols[_cur.k + 1], count: 2, speed: 90, shape: PartShape.square, size: 5, gravity: -200, life: .35);
    }
    _lockPiece();
  }

  Offset _cellCenter(int x, int y) => Offset(_bx + (x + .5) * _cs, _by + (y + .5) * _cs);

  void _lockPiece() {
    for (final c in _cells(_cur)) {
      if (c[1] < 0) {
        _dead = true;
        host.sfx(Sfx.pDie);
        host.shake(10);
        host.lose();
        return;
      }
      _grid[c[1]][c[0]] = _cur.k + 1;
    }
    _land = 1;
    host.sfx(Sfx.thud, volume: .5, rate: 1.4);
    final full = <int>[];
    for (var r = 0; r < _h; r++) {
      if (_grid[r].every((v) => v != 0)) full.add(r);
    }
    if (full.isNotEmpty) {
      _clearing = full;
      _clearT = 0;
      _combo++;
      final n = full.length;
      _lines += n;
      host.addScore(const [0, 100, 300, 600, 1000][n]);
      host.sfx(n >= 3 ? Sfx.pExplode : Sfx.pCoin, rate: 1 + n * .1);
      host.sfx(Sfx.combo, rate: 1 + n * .15, volume: .7);
      host.shake(4.0 + n * 3);
      host.flash(n >= 3 ? Pal.yellow : Pal.white, .12);
      host.hitStop(.05 * n);
      host.punch(.02 * n);
      _bigWord = switch (n) {
        1 => host.tr('nice', 'NICE!'),
        2 => host.tr('great', 'GREAT!'),
        3 => host.tr('wow', 'WOW!'),
        _ => host.tr('perfect', 'PERFECT!'),
      };
      _bigCol = [Pal.white, Pal.lime, Pal.yellow, Pal.pink][min(3, n - 1)];
      _bigText = 1.2;
      _mood = 1.5;
      if (_combo >= 2) {
        host.fx.pop('${host.tr('combo', 'COMBO')} x$_combo', const Offset(136, 300), color: Pal.pink, size: 22);
      }
      for (final r in full) {
        for (var x = 0; x < _w; x++) {
          host.fx.burst(_cellCenter(x, r), _cols[_grid[r][x]], count: 3, speed: 260, shape: PartShape.square, size: 7, gravity: 500);
        }
      }
    } else {
      _combo = 0;
      _spawn();
    }
  }

  // --------------------------------------------------------------- input ---
  static const _btnY = 492.0, _btnH = 64.0;
  int _btnAt(Offset p) {
    if (p.dy < _btnY || p.dy > _btnY + _btnH) return -1;
    return (p.dx / 90).floor().clamp(0, 3);
  }

  void _press(int b) {
    _btn = b;
    _btnFlash = .15;
    switch (b) {
      case 0:
        _move(-1);
      case 1:
        _rotate();
      case 2:
        _move(1);
      case 3:
        _hardDrop();
    }
  }

  @override
  void onDown(Offset p) {
    final b = _btnAt(p);
    if (b >= 0) {
      _press(b);
      _down = null;
      return;
    }
    _down = p;
    _anchorX = p.dx;
    _moved = false;
    _dropped = false;
  }

  @override
  void onMove(Offset p) {
    final a = _down;
    if (a == null) return;
    while (p.dx - _anchorX > _cs) {
      _anchorX += _cs;
      _move(1);
      _moved = true;
    }
    while (_anchorX - p.dx > _cs) {
      _anchorX -= _cs;
      _move(-1);
      _moved = true;
    }
    if (!_dropped && p.dy - a.dy > 70 && (p.dy - a.dy) > (p.dx - a.dx).abs() * 1.5) {
      _dropped = true;
      _moved = true;
      _hardDrop();
    }
  }

  @override
  void onUp(Offset p) {
    final a = _down;
    _down = null;
    if (a == null || _moved) return;
    if ((p - a).distance > 14) return;
    // tap: on piece => rotate, else nudge toward tap
    final cells = _cells(_cur);
    var minX = 99.0, maxX = -99.0, minY = 99.0, maxY = -99.0;
    for (final c in cells) {
      final o = _cellCenter(c[0], c[1]);
      minX = min(minX, o.dx);
      maxX = max(maxX, o.dx);
      minY = min(minY, o.dy);
      maxY = max(maxY, o.dy);
    }
    final box = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(_cs * .9);
    if (box.contains(p)) {
      _rotate();
    } else {
      _move(p.dx < (minX + maxX) / 2 ? -1 : 1);
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    switch (key) {
      case 'left':
        _press(0);
      case 'right':
        _press(2);
      case 'up':
        _press(1);
      case 'down':
        if (!_busy()) {
          final d = _cur.copy()..y += 1;
          if (!_collides(d)) _cur = d;
        }
      case 'action':
        _press(3);
    }
  }

  // -------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    _land = max(0, _land - dt * 5);
    _bigText = max(0, _bigText - dt);
    _mood = max(0, _mood - dt);
    _btnFlash = max(0, _btnFlash - dt);
    if (_clearing.isNotEmpty) {
      _clearT += dt;
      if (_clearT > .32) {
        final rows = _clearing.toSet();
        final kept = <List<int>>[];
        for (var r = 0; r < _h; r++) {
          if (!rows.contains(r)) kept.add(_grid[r]);
        }
        while (kept.length < _h) {
          kept.insert(0, List.filled(_w, 0));
        }
        for (var r = 0; r < _h; r++) {
          _grid[r] = kept[r];
        }
        _clearing = [];
        _land = 1;
        if (_lines >= _goal && !host.finished) {
          host.sfx(Sfx.fanfare);
          host.fx.confetti(count: 90);
          host.win(stars: _lines >= 4 || host.timeLeft > 12 ? 3 : (host.timeLeft > 5 ? 2 : 1));
        } else {
          _spawn();
        }
      }
      return;
    }
    if (_busy()) return;
    final interval = .6 / host.speed;
    _fall += dt;
    final below = _cur.copy()..y += 1;
    if (_collides(below)) {
      _lock += dt;
      if (_lock > .45) _lockPiece();
    } else if (_fall >= interval) {
      _fall = 0;
      _cur = below;
    }
  }

  // -------------------------------------------------------------- render ---
  static final Paint _pp = Paint()..isAntiAlias = false;
  void _r(Canvas c, double l, double t, double w, double h, Color col) {
    _pp.color = col;
    c.drawRect(Rect.fromLTWH(l, t, w, h), _pp);
  }

  void _block(Canvas c, double x, double y, Color col, {double s = _cs, double alpha = 1}) {
    final a = alpha;
    Color al(Color k) => a >= 1 ? k : k.withValues(alpha: a);
    final p = s / 8;
    _r(c, x, y, s, s, al(Color.lerp(col, Pal.ink, .45)!));
    _r(c, x, y, s - p, s - p, al(Color.lerp(col, Pal.white, .45)!));
    _r(c, x + p, y + p, s - p * 2, s - p * 2, al(col));
    _r(c, x + p * 2, y + p * 2, p, p, al(Color.lerp(col, Pal.white, .7)!));
  }

  @override
  void render(Canvas c) {
    // backdrop: purple brick wall + twinkles
    _r(c, 0, 0, 360, 640, const Color(0xFF1C1238));
    for (var y = 36.0, row = 0; y < 640; y += 16, row++) {
      for (var x = (row.isEven ? 0.0 : -16.0); x < 360; x += 32) {
        _r(c, x + 1, y + 1, 30, 14, const Color(0xFF261A4A));
        _r(c, x + 1, y + 1, 30, 2, const Color(0xFF2E2258));
      }
    }
    // well frame
    const frame = Rect.fromLTWH(_bx - 8, _by - 8, _w * _cs + 16, _h * _cs + 16);
    _r(c, frame.left, frame.top, frame.width, frame.height, const Color(0xFF8C7AD8));
    _r(c, frame.left + 4, frame.top + 4, frame.width - 8, frame.height - 8, const Color(0xFF4A3A8C));
    for (var y = frame.top; y < frame.bottom; y += 12) {
      _r(c, frame.left, y, 8, 2, const Color(0xFF5E4AA8));
      _r(c, frame.right - 8, y + 6, 8, 2, const Color(0xFF5E4AA8));
    }
    // danger glow when high
    var top = _h;
    for (var r = 0; r < _h; r++) {
      if (_grid[r].any((v) => v != 0)) {
        top = r;
        break;
      }
    }
    final danger = top < 5;
    _r(c, _bx, _by, _w * _cs, _h * _cs, danger && (_t * 4).floor().isEven ? const Color(0xFF2A0E22) : const Color(0xFF0C0A1E));
    for (var x = 1; x < _w; x++) {
      _r(c, _bx + x * _cs, _by, 1, _h * _cs, const Color(0xFF171432));
    }
    for (var y = 1; y < _h; y++) {
      _r(c, _bx, _by + y * _cs, _w * _cs, 1, const Color(0xFF171432));
    }
    // settled blocks
    final landOff = (_land * 3).roundToDouble();
    for (var r = 0; r < _h; r++) {
      final clearing = _clearing.contains(r);
      for (var x = 0; x < _w; x++) {
        final v = _grid[r][x];
        if (v == 0) continue;
        final px = _bx + x * _cs, py = _by + r * _cs + landOff * (r / _h);
        if (clearing) {
          final blink = (_clearT * 24).floor().isEven;
          _block(c, px, py, blink ? Pal.white : _cols[v]);
        } else {
          _block(c, px, py, _cols[v]);
        }
      }
    }
    if (_clearing.isNotEmpty) {
      for (final r in _clearing) {
        final k = (_clearT / .32).clamp(0.0, 1.0);
        final w = _w * _cs * k;
        _r(c, _bx + (_w * _cs - w) / 2, _by + r * _cs + 4, w, _cs - 8, const Color(0xCCFFFFFF));
      }
    }
    if (!_busy()) {
      // ghost
      var g = _cur.copy();
      while (true) {
        final d = g.copy()..y += 1;
        if (_collides(d)) break;
        g = d;
      }
      for (final cell in _cells(g)) {
        if (cell[1] < 0) continue;
        final px = _bx + cell[0] * _cs, py = _by + cell[1] * _cs;
        final col = _cols[_cur.k + 1];
        _r(c, px + 2, py + 2, _cs - 4, 3, col.withValues(alpha: .6));
        _r(c, px + 2, py + _cs - 5, _cs - 4, 3, col.withValues(alpha: .6));
        _r(c, px + 2, py + 2, 3, _cs - 4, col.withValues(alpha: .6));
        _r(c, px + _cs - 5, py + 2, 3, _cs - 4, col.withValues(alpha: .6));
      }
      for (final cell in _cells(_cur)) {
        if (cell[1] < 0) continue;
        _block(c, _bx + cell[0] * _cs, _by + cell[1] * _cs, _cols[_cur.k + 1]);
      }
    }
    _drawPanel(c, top);
    _drawButtons(c);
    if (_bigText > 0) {
      final k = 1.2 - _bigText;
      final sc = k < .12 ? 3 + k / .12 * 3 : 5.0;
      _pt(c, _bigWord, Offset(_bx + _w * _cs / 2, 250 - k * 20), sc.roundToDouble(), _bigCol);
    }
    if (host.time < 2.6 && !_busy()) {
      final cells = _cells(_cur);
      final p = _cellCenter(cells[0][0], max(0, cells[0][1]));
      D.hand(c, p + Offset(8 + sin(_t * 3) * 30, 20), _t);
      _pt(c, host.tr('drag', 'DRAG'), p + const Offset(20, 100), 3, Pal.white);
    }
    Retro.scanlines(c, alpha: .12);
    Retro.vignette(c, strength: .35);
  }

  void _drawPanel(Canvas c, int top) {
    const x = 268.0;
    // NEXT
    _r(c, x - 4, 92, 88, 88, const Color(0xFF8C7AD8));
    _r(c, x, 96, 80, 80, const Color(0xFF0C0A1E));
    _pt(c, host.tr('next', 'NEXT'), const Offset(x + 40, 108), 2, Pal.white);
    final nk = _queue.first;
    final cells = _cells(_Piece(nk, 0, 0, 0));
    var minX = 9, maxX = -9, minY = 9, maxY = -9;
    for (final cc in cells) {
      minX = min(minX, cc[0]);
      maxX = max(maxX, cc[0]);
      minY = min(minY, cc[1]);
      maxY = max(maxY, cc[1]);
    }
    const s = 16.0;
    final ox = x + 40 - (maxX - minX + 1) * s / 2, oy = 146 - (maxY - minY + 1) * s / 2;
    for (final cc in cells) {
      _block(c, ox + (cc[0] - minX) * s, oy + (cc[1] - minY) * s, _cols[nk + 1], s: s);
    }
    // LINES
    _r(c, x - 4, 192, 88, 92, const Color(0xFF8C7AD8));
    _r(c, x, 196, 80, 84, const Color(0xFF0C0A1E));
    _pt(c, host.tr('lines', 'LINES'), const Offset(x + 40, 208), 2, Pal.white);
    PixelFont.draw(c, '${min(_lines, _goal)}', const Offset(x + 30, 236), 5, _lines > 0 ? Pal.yellow : Pal.white,
        align: 0, shadow: const Color(0xFF7A3A00));
    PixelFont.draw(c, '/$_goal', const Offset(x + 62, 250), 2, Pal.white, align: 0);
    for (var i = 0; i < _goal; i++) {
      _r(c, x + 10 + i * 22.0, 268, 16, 6, i < _lines ? Pal.lime : const Color(0xFF30305A));
    }
    // mascot: pixel robot reacting
    final face = host.finished && _lines >= _goal
        ? _S.botHappy
        : (_dead ? _S.botDead : (_mood > 0 ? _S.botHappy : (top < 6 ? _S.botScared : _S.bot)));
    final bob = _mood > 0 || (host.finished && !_dead) ? -(sin(_t * 14).abs() * 8).roundToDouble() : ((_t * 2).floor().isEven ? 0.0 : 2.0);
    face.draw(c, Offset(x + 4, 316 + bob), scale: 4);
    if (top < 6 && !_dead && (_t * 5).floor().isEven) {
      _r(c, x + 70, 318, 4, 8, const Color(0xFF8FD8FF));
    }
    // score
    PixelFont.draw(c, '${host.score}'.padLeft(5, '0'), Offset(x + 40, 420), 2, Pal.yellow, align: 0, shadow: const Color(0xFF7A3A00));
  }

  void _drawButtons(Canvas c) {
    for (var i = 0; i < 4; i++) {
      final pressed = _btnFlash > 0 && _btn == i;
      final l = i * 90.0 + 6, t = _btnY + (pressed ? 4 : 0);
      _r(c, l, _btnY + 4, 78, _btnH - 4, const Color(0xFF2A1E5A));
      _r(c, l, t, 78, _btnH - 8, pressed ? const Color(0xFFB0A0FF) : const Color(0xFF6A58C8));
      _r(c, l + 3, t + 3, 72, 4, const Color(0xFF9A88F0));
      final icon = [_S.icoL, _S.icoRot, _S.icoR, _S.icoDrop][i];
      icon.drawCentered(c, Offset(l + 39, t + (_btnH - 8) / 2), scale: 4);
    }
  }
}

class _Piece {
  _Piece(this.k, this.x, this.y, this.rot);
  final int k;
  int x, y, rot;
  _Piece copy() => _Piece(k, x, y, rot);
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
  static const _bp = <String, Color>{
    'K': Color(0xFF10122A),
    'G': Color(0xFFB0B8C8),
    'g': Color(0xFF6A7088),
    'S': Color(0xFF6FF0FF),
    'R': Color(0xFFFF3B5C),
    'P': Color(0xFFFF8FC0),
    'Y': Color(0xFFFFE14A),
  };
  static final bot = Sprite(const [
    '.......Y.......',
    '.......K.......',
    '..KKKKKKKKKKK..',
    '.KGGGGGGGGGGGK.',
    '.KGKKKKKKKKKGK.',
    '.KGKSSKKKSSKGK.',
    '.KGKSSKKKSSKGK.',
    '.KGKKKKKKKKKGK.',
    '.KGGGGGGGGGGGK.',
    '.KGGGKKKKKGGGK.',
    '.KgGGGGGGGGGgK.',
    '..KKKKKKKKKKK..',
    '....KgGGGgK....',
    '...KGGGGGGGK...',
  ], _bp);
  static final botHappy = Sprite(const [
    '.......Y.......',
    '.......K.......',
    '..KKKKKKKKKKK..',
    '.KGGGGGGGGGGGK.',
    '.KGKKKKKKKKKGK.',
    '.KGKSKSKSKSKGK.',
    '.KGKKKKKKKKKGK.',
    '.KGKKKKKKKKKGK.',
    '.KGPGGGGGGGPGK.',
    '.KGGKGGGGGKGGK.',
    '.KgGGKKKKKGGgK.',
    '..KKKKKKKKKKK..',
    '....KgGGGgK....',
    '...KGGGGGGGK...',
  ], _bp);
  static final botScared = Sprite(const [
    '.......R.......',
    '.......K.......',
    '..KKKKKKKKKKK..',
    '.KGGGGGGGGGGGK.',
    '.KGKKKKKKKKKGK.',
    '.KGKSSSKSSSKGK.',
    '.KGKSKSKSKSKGK.',
    '.KGKKKKKKKKKGK.',
    '.KGGGGGGGGGGGK.',
    '.KGGGGKKKGGGGK.',
    '.KgGGGKKKGGGgK.',
    '..KKKKKKKKKKK..',
    '....KgGGGgK....',
    '...KGGGGGGGK...',
  ], _bp);
  static final botDead = Sprite(const [
    '.......R.......',
    '.......K.......',
    '..KKKKKKKKKKK..',
    '.KGGGGGGGGGGGK.',
    '.KGKKKKKKKKKGK.',
    '.KGKRKRKRKRKGK.',
    '.KGKKRKKKRKKGK.',
    '.KGKRKRKRKRKGK.',
    '.KGGGGGGGGGGGK.',
    '.KGGKKKKKKKGGK.',
    '.KgGGGGGGGGGgK.',
    '..KKKKKKKKKKK..',
    '....KgGGGgK....',
    '...KGGGGGGGK...',
  ], _bp);
  static const _ip = {'W': Color(0xFFFFFFFF)};
  static final icoL = Sprite(const [
    '...W....',
    '..WW....',
    '.WWWWWWW',
    'WWWWWWWW',
    '.WWWWWWW',
    '..WW....',
    '...W....',
  ], _ip);
  static final icoR = Sprite(const [
    '....W...',
    '....WW..',
    'WWWWWWW.',
    'WWWWWWWW',
    'WWWWWWW.',
    '....WW..',
    '....W...',
  ], _ip);
  static final icoRot = Sprite(const [
    '..WWWW.W',
    '.W....WW',
    'W....WWW',
    'W.......',
    'W......W',
    '.W....W.',
    '..WWWW..',
  ], _ip);
  static final icoDrop = Sprite(const [
    '..WWW..',
    '..WWW..',
    '..WWW..',
    'WWWWWWW',
    '.WWWWW.',
    '..WWW..',
    '...W...',
    'WWWWWWW',
  ], _ip);
}
