import '../engine/engine.dart';

/// No.084 Snake Byte — the old brick-phone snake on a ghosting green LCD.
///
/// Swipe anywhere (or tap the 2/4/6/8 keys, or tap the LCD beside the head)
/// to turn. Eat apples to grow to length 12. Walls and your own tail kill.
bool _ascii(String s) {
  for (final u in s.codeUnits) {
    if (u > 126) return false;
  }
  return true;
}

void _px(Canvas c, String s, Offset pos, double scale, Color col, {int align = -1, Color? shadow}) {
  if (_ascii(s)) {
    PixelFont.draw(c, s.toUpperCase(), pos, scale, col, align: align, shadow: shadow);
  } else {
    D.text(c, s, Offset(pos.dx, pos.dy + 3.5 * scale), size: 8 * scale, color: col, stroke: shadow,
        strokeWidth: shadow == null ? 0 : scale * 1.4,
        anchor: align < 0 ? Alignment.centerLeft : (align == 0 ? Alignment.center : Alignment.centerRight));
  }
}

const _lcdBg = Color(0xFFC7F0D8);
const _lcdInk = Color(0xFF43523D);
const _cols = 22, _rowsN = 19;
const double _cell = 12, _sub = 3;
const double _gx = 48, _gy = 132; // grid origin (inside LCD)

// 4x4 cell patterns
const _patBody = ['XXX.', 'XXXX', 'XXXX', '.XXX'];
const _patBody2 = ['.XXX', 'XXXX', 'XXXX', 'XXX.'];
const _patApple = ['.X..', 'X.X.', '.X.X', '..X.'];
const _patHeadR = ['XX..', 'X.XX', 'XXXX', 'XXX.'];
const _patHeadMouthR = ['XX.X', 'X.X.', 'XXX.', 'XXXX'];
const _patCritter = ['X..X....', 'XXXXXXX.', '.X.XXXXX', 'XX.X..X.'];

List<String> _rot(List<String> p, int times) {
  var r = p;
  for (var t = 0; t < times; t++) {
    final n = r.length;
    r = [
      for (var y = 0; y < n; y++) [for (var x = 0; x < n; x++) r[n - 1 - x][y]].join(),
    ];
  }
  return r;
}

Path _patPath(List<String> p) {
  final path = Path();
  for (var y = 0; y < p.length; y++) {
    for (var x = 0; x < p[y].length; x++) {
      if (p[y][x] == 'X') path.addRect(Rect.fromLTWH(x * _sub + .3, y * _sub + .3, _sub - .6, _sub - .6));
    }
  }
  return path;
}

final _pBody = _patPath(_patBody);
final _pBody2 = _patPath(_patBody2);
final _pApple = _patPath(_patApple);
final _pCritter = _patPath(_patCritter);
// dir index: 0 right, 1 down, 2 left, 3 up
final _pHead = [for (var i = 0; i < 4; i++) _patPath(_rot(_patHeadR, i))];
final _pHeadMouth = [for (var i = 0; i < 4; i++) _patPath(_rot(_patHeadMouthR, i))];

const _dirs = [(1, 0), (0, 1), (-1, 0), (0, -1)];

class _Ghost {
  _Ghost(this.x, this.y);
  final int x, y;
  double t = 0;
}

class G084 extends MiniGame {
  static const _goal = 12;
  final _snake = <(int, int)>[]; // head first
  final _queue = <int>[];
  final _ghosts = <_Ghost>[];
  int _dir = 0;
  double _stepT = 0;
  (int, int) _apple = (0, 0);
  (int, int)? _critter;
  double _critterT = 0;
  int _eaten = 0;
  int _grow = 0;
  double _t = 0;
  bool _dead = false;
  double _deadT = 0;
  bool _won = false;
  double _eatFlash = 0;
  Offset? _downAt;
  bool _swiped = false;
  int _keyFlash = -1;
  double _keyT = 0;

  @override
  void init() {
    for (var i = 0; i < 4; i++) {
      _snake.add((6 - i, 9));
    }
    _placeApple();
  }

  bool _occupied(int x, int y) => _snake.any((s) => s.$1 == x && s.$2 == y);

  void _placeApple() {
    final head = _snake.first;
    for (var tries = 0; tries < 200; tries++) {
      final x = 1 + randInt(_cols - 2), y = 1 + randInt(_rowsN - 2);
      final d = (x - head.$1).abs() + (y - head.$2).abs();
      if (_occupied(x, y) || d < 4 || d > 14) continue;
      if (_critter != null && (x == _critter!.$1 || x == _critter!.$1 + 1) && y == _critter!.$2) continue;
      _apple = (x, y);
      return;
    }
    _apple = (1 + randInt(_cols - 2), 1 + randInt(_rowsN - 2));
  }

  double get _interval => max(.075, (.135 - _eaten * .004) / host.speed);

  void _turn(int d) {
    if (_dead || _won || host.finished) return;
    final last = _queue.isNotEmpty ? _queue.last : _dir;
    if (d == last || (d + 2) % 4 == last) return;
    if (_queue.length < 2) {
      _queue.add(d);
      host.sfx(Sfx.pSelect, volume: .3, rate: 1.4);
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _eatFlash = max(0, _eatFlash - dt * 3);
    _keyT = max(0, _keyT - dt);
    for (final g in _ghosts) {
      g.t += dt;
    }
    _ghosts.removeWhere((g) => g.t > .35);
    if (_critter != null) {
      _critterT -= dt;
      if (_critterT <= 0) _critter = null;
    }
    if (_dead) {
      _deadT += dt;
      return;
    }
    if (_won) {
      _deadT += dt;
      return;
    }
    if (host.finished) return;
    _stepT += dt;
    if (_stepT < _interval) return;
    _stepT = 0;
    if (_queue.isNotEmpty) _dir = _queue.removeAt(0);
    final (dx, dy) = _dirs[_dir];
    final head = _snake.first;
    final nx = head.$1 + dx, ny = head.$2 + dy;
    final willGrow = _grow > 0 || (nx == _apple.$1 && ny == _apple.$2);
    // collisions
    var hitSelf = false;
    for (var i = 0; i < _snake.length - (willGrow ? 0 : 1); i++) {
      if (_snake[i].$1 == nx && _snake[i].$2 == ny) hitSelf = true;
    }
    if (nx < 0 || ny < 0 || nx >= _cols || ny >= _rowsN || hitSelf) {
      _dead = true;
      _deadT = 0;
      host.sfx(Sfx.pDie);
      host.shake(10, .5);
      host.lose();
      return;
    }
    _snake.insert(0, (nx, ny));
    if (_grow > 0) {
      _grow--;
    } else if (!(nx == _apple.$1 && ny == _apple.$2)) {
      final tail = _snake.removeLast();
      _ghosts.add(_Ghost(tail.$1, tail.$2));
    }
    host.sfx(Sfx.tick, volume: .12, rate: 1.8);
    if (nx == _apple.$1 && ny == _apple.$2) {
      _eaten++;
      _eatFlash = 1;
      host.addScore(10 * _eaten);
      host.sfx(Sfx.pCoin, rate: 1 + _eaten * .06);
      host.shake(3, .15); // phone buzz
      final sc = _cellCenter(nx, ny);
      host.fx.burst(sc, _lcdInk, count: 8, speed: 120, size: 4, shape: PartShape.square, gravity: 0);
      if (_snake.length >= _goal) {
        _won = true;
        _deadT = 0;
        host.sfx(Sfx.pPowerup);
        host.fx.confetti();
        final tt = host.time;
        host.win(stars: tt < 12 ? 3 : (tt < 16 ? 2 : 1));
        return;
      }
      _placeApple();
      if (_eaten == 3 || _eaten == 7) {
        _spawnCritter();
      }
    }
    if (_critter != null) {
      final cr = _critter!;
      if (ny == cr.$2 && (nx == cr.$1 || nx == cr.$1 + 1)) {
        _critter = null;
        host.addScore(150);
        _grow += 1;
        host.sfx(Sfx.pPowerup, rate: 1.4);
        host.fx.pop('+150', _cellCenter(nx, ny) - const Offset(0, 20), color: _lcdInk, size: 20);
      }
    }
  }

  void _spawnCritter() {
    for (var tries = 0; tries < 100; tries++) {
      final x = 1 + randInt(_cols - 3), y = 1 + randInt(_rowsN - 2);
      if (_occupied(x, y) || _occupied(x + 1, y) || (y == _apple.$2 && (x == _apple.$1 || x + 1 == _apple.$1))) continue;
      _critter = (x, y);
      _critterT = 5;
      return;
    }
  }

  Offset _cellCenter(int x, int y) => Offset(_gx + x * _cell + _cell / 2, _gy + y * _cell + _cell / 2);

  // ------------------------------------------------------------ input ---

  static const _keyRect = Rect.fromLTWH(46, 450, 268, 160);
  Rect _key(int i) {
    final col = i % 3, row = i ~/ 3;
    return Rect.fromLTWH(_keyRect.left + col * 92, _keyRect.top + row * 42, 84, 34);
  }

  @override
  void onDown(Offset p) {
    _downAt = p;
    _swiped = false;
  }

  @override
  void onMove(Offset p) {
    final d0 = _downAt;
    if (d0 == null || _swiped) return;
    final d = p - d0;
    if (d.distance > 18) {
      _swiped = true;
      _turn(d.dx.abs() > d.dy.abs() ? (d.dx > 0 ? 0 : 2) : (d.dy > 0 ? 1 : 3));
    }
  }

  @override
  void onUp(Offset p) {
    if (_swiped || _downAt == null) {
      _downAt = null;
      return;
    }
    _downAt = null;
    if (p.dy > 390) {
      // keypad: nearest of 2/4/6/8 (index 1,3,5,7) — or direction from key 5
      for (var i = 0; i < 12; i++) {
        if (_key(i).inflate(4).contains(p)) {
          _keyFlash = i;
          _keyT = .15;
          host.sfx(Sfx.click, volume: .5);
          break;
        }
      }
      final c5 = _key(4).center;
      final d = p - c5;
      if (d.distance < 12) return;
      _turn(d.dx.abs() > d.dy.abs() ? (d.dx > 0 ? 0 : 2) : (d.dy > 0 ? 1 : 3));
    } else {
      // tap on the screen: turn towards the tap, perpendicular to motion
      final h = _cellCenter(_snake.first.$1, _snake.first.$2);
      final d = p - h;
      if (_dir.isEven) {
        _turn(d.dy > 0 ? 1 : 3);
      } else {
        _turn(d.dx > 0 ? 0 : 2);
      }
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    switch (key) {
      case 'right':
        _turn(0);
      case 'down':
        _turn(1);
      case 'left':
        _turn(2);
      case 'up':
        _turn(3);
    }
  }

  // ----------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    // desk background: pixel wood planks
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), Paint()..color = const Color(0xFF6B3E26));
    final plank = Paint()..color = const Color(0xFF5A321E);
    final grain = Paint()..color = const Color(0xFF7C4A2E);
    for (var y = 36.0; y < 640; y += 48) {
      c.drawRect(Rect.fromLTWH(0, y, 360, 3), plank);
      for (var x = ((y / 48).floor().isEven ? 30.0 : 90.0); x < 360; x += 120) {
        c.drawRect(Rect.fromLTWH(x, y + 18, 36, 3), grain);
      }
    }

    _renderPhone(c);
    _renderLcd(c);
    _renderKeypad(c);

    if (host.time < 2.4 && !host.finished) {
      final a = M.wave(_t, 1.5);
      D.hand(c, Offset(150 + a * 70, 300), _t);
      D.arrow(c, const Offset(180, 262), const Offset(1, 0), 90, const Color(0xFFFCFCFC), width: 8);
      _px(c, host.tr('swipe', 'SWIPE'), const Offset(180, 222), 3, const Color(0xFFFCFCFC), align: 0, shadow: const Color(0xFF000000));
    }
  }

  void _stepRect(Canvas c, Rect r, double step, Paint p) {
    // rectangle with pixel-stepped corners
    c.drawRect(Rect.fromLTRB(r.left + step * 2, r.top, r.right - step * 2, r.bottom), p);
    c.drawRect(Rect.fromLTRB(r.left + step, r.top + step, r.right - step, r.bottom - step), p);
    c.drawRect(Rect.fromLTRB(r.left, r.top + step * 2, r.right, r.bottom - step * 2), p);
  }

  void _renderPhone(Canvas c) {
    final shake = _eatFlash > .6 ? sin(_t * 90) * 2 : 0.0;
    c.save();
    c.translate(shake, 0);
    _stepRect(c, const Rect.fromLTWH(22, 46, 316, 600), 6, Paint()..color = const Color(0xFF141A28));
    _stepRect(c, const Rect.fromLTWH(26, 50, 308, 596), 6, Paint()..color = const Color(0xFF2C3A5C));
    // body highlight band
    c.drawRect(const Rect.fromLTWH(40, 56, 280, 6), Paint()..color = const Color(0xFF45588A));
    // speaker slots
    final slot = Paint()..color = const Color(0xFF141A28);
    for (var i = 0; i < 5; i++) {
      c.drawRect(Rect.fromLTWH(150 + i * 12.0, 68, 6, 3), slot);
    }
    _px(c, 'ADKIA', const Offset(180, 80), 2, const Color(0xFF9CB0D8), align: 0);
    // LCD bezel
    _stepRect(c, const Rect.fromLTWH(36, 98, 288, 284), 6, Paint()..color = const Color(0xFF0E1320));
    _stepRect(c, const Rect.fromLTWH(40, 102, 280, 276), 3, Paint()..color = const Color(0xFF3B4A2E));
    c.restore();
  }

  void _renderLcd(Canvas c) {
    final inv = _won && (_deadT * 6).floor().isOdd;
    final bg = inv ? _lcdInk : _lcdBg;
    final ink = inv ? _lcdBg : _lcdInk;
    const lcd = Rect.fromLTWH(44, 106, 272, 268);
    c.drawRect(lcd, Paint()..color = bg);
    // backlight glow
    c.drawRect(
        lcd,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)])
              .createShader(Rect.fromCircle(center: lcd.center, radius: 220)));
    // faint unlit dot matrix
    final unlit = Paint()..color = inv ? const Color(0x22C7F0D8) : const Color(0x14000000);
    for (var y = 0; y < _rowsN * 4; y += 1) {
      c.drawRect(Rect.fromLTWH(_gx, _gy + y * _sub + _sub - .6, _cols * _cell, .6), unlit);
    }
    // status bar: signal, battery, score
    final ip = Paint()..color = ink;
    for (var i = 0; i < 4; i++) {
      c.drawRect(Rect.fromLTWH(52 + i * 5.0, 124 - i * 3.0 - 3, 3, i * 3.0 + 3), ip);
    }
    c.drawRect(const Rect.fromLTWH(290, 114, 18, 9), ip);
    c.drawRect(const Rect.fromLTWH(292, 116, 14, 5), Paint()..color = bg);
    c.drawRect(Rect.fromLTWH(292, 116, 14 * (1 - host.time / max(1, host.duration)), 5), ip);
    c.drawRect(const Rect.fromLTWH(308, 116, 2, 5), ip);
    _px(c, host.score.toString().padLeft(4, '0'), const Offset(82, 112), 2, ink);
    // length progress
    c.save();
    c.translate(206, 112);
    c.drawPath(_pApple, ip);
    c.restore();
    _px(c, '${_snake.length}/$_goal', const Offset(222, 112), 2, ink);
    // wall frame
    final frame = Rect.fromLTWH(_gx - 3, _gy - 3, _cols * _cell + 6, _rowsN * _cell + 6);
    c.drawRect(Rect.fromLTWH(frame.left, frame.top, frame.width, 2), ip);
    c.drawRect(Rect.fromLTWH(frame.left, frame.bottom - 2, frame.width, 2), ip);
    c.drawRect(Rect.fromLTWH(frame.left, frame.top, 2, frame.height), ip);
    c.drawRect(Rect.fromLTWH(frame.right - 2, frame.top, 2, frame.height), ip);

    // ghosting of vacated cells
    for (final g in _ghosts) {
      final a = (1 - g.t / .35) * .45;
      _drawPat(c, _pBody, g.x, g.y, ink.withValues(alpha: a));
    }
    // apple (blinks slowly)
    if (!(_won) && (_t * 3).floor() % 4 != 3) _drawPat(c, _pApple, _apple.$1, _apple.$2, ink);
    if (_critter != null && (_critterT > 1.5 || (_t * 8).floor().isEven)) {
      final cr = _critter!;
      c.save();
      c.translate(_gx + cr.$1 * _cell, _gy + cr.$2 * _cell);
      c.drawPath(_pCritter, ip);
      c.restore();
    }
    // snake
    final visible = !_dead || (_deadT * 5).floor().isEven || _deadT > 1.2;
    if (visible) {
      for (var i = _snake.length - 1; i >= 0; i--) {
        final s = _snake[i];
        if (i == 0) {
          final (dx, dy) = _dirs[_dir];
          final nearFood = (s.$1 + dx - _apple.$1).abs() + (s.$2 + dy - _apple.$2).abs() <= 1;
          _drawPat(c, nearFood ? _pHeadMouth[_dir] : _pHead[_dir], s.$1, s.$2, ink);
        } else {
          _drawPat(c, (i + _snake.length).isEven ? _pBody : _pBody2, s.$1, s.$2, ink);
        }
      }
    }
    if (_won) {
      _px(c, host.tr('win', 'WIN'), const Offset(180, 260), 5, ink, align: 0);
    }
    if (_dead && _deadT > .6) {
      _px(c, host.tr('game_over', 'GAME OVER'), const Offset(180, 270), 3, ink, align: 0);
    }
    // LCD glass reflection
    c.drawPath(
        Path()
          ..moveTo(44, 106)
          ..lineTo(150, 106)
          ..lineTo(44, 240)
          ..close(),
        Paint()..color = const Color(0x12FFFFFF));
  }

  void _drawPat(Canvas c, Path p, int x, int y, Color col) {
    c.save();
    c.translate(_gx + x * _cell, _gy + y * _cell);
    c.drawPath(p, Paint()..color = col);
    c.restore();
  }

  void _renderKeypad(Canvas c) {
    // navi key
    _stepRect(c, const Rect.fromLTWH(110, 400, 140, 30), 3, Paint()..color = const Color(0xFF141A28));
    _stepRect(c, const Rect.fromLTWH(112, 402, 136, 26), 3, Paint()..color = const Color(0xFF8C9CC0));
    c.drawRect(const Rect.fromLTWH(118, 405, 124, 3), Paint()..color = const Color(0xFFC0CCE8));
    _stepRect(c, const Rect.fromLTWH(56, 404, 44, 22), 3, Paint()..color = const Color(0xFF1C2438));
    _stepRect(c, const Rect.fromLTWH(260, 404, 44, 22), 3, Paint()..color = const Color(0xFF1C2438));
    const labels = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
    for (var i = 0; i < 12; i++) {
      final r = _key(i);
      final pressed = _keyFlash == i && _keyT > 0;
      final arrow = i == 1 || i == 3 || i == 5 || i == 7;
      final face = r.shift(Offset(0, pressed ? 3 : 0));
      _stepRect(c, r.shift(const Offset(0, 3)), 3, Paint()..color = const Color(0xFF0E1320));
      _stepRect(c, face, 3, Paint()..color = arrow ? const Color(0xFFD8E0F0) : const Color(0xFF7C8CB0));
      c.drawRect(Rect.fromLTWH(face.left + 6, face.top + 3, face.width - 12, 3),
          Paint()..color = arrow ? const Color(0xFFFFFFFF) : const Color(0xFF9CACD0));
      _px(c, labels[i], Offset(face.left + 14, face.top + 9), 2, const Color(0xFF1C2438));
      if (arrow) {
        final dir = switch (i) { 1 => const Offset(0, -1), 3 => const Offset(-1, 0), 5 => const Offset(1, 0), _ => const Offset(0, 1) };
        final ctr = face.center + const Offset(12, 0);
        final tri = Path()
          ..moveTo(ctr.dx + dir.dx * 8, ctr.dy + dir.dy * 8)
          ..lineTo(ctr.dx - dir.dx * 5 + dir.dy * 7, ctr.dy - dir.dy * 5 + dir.dx * 7)
          ..lineTo(ctr.dx - dir.dx * 5 - dir.dy * 7, ctr.dy - dir.dy * 5 - dir.dx * 7)
          ..close();
        c.drawPath(tri, Paint()..color = const Color(0xFF2C7C3C));
      }
    }
  }
}
