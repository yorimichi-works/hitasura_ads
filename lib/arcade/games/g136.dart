import '../engine/engine.dart';

/// No.136 Box Pusher — pixel sokoban, 2 small hand-made levels (verified
/// solvable by BFS: 7–8 and 11–17 steps). Swipe / D-pad / arrows, undo.
class G136 extends MiniGame {
  static const _ts = 36.0;
  static const _l1 = [
    ['#######', '#     #', '# @\$ .#', '#  \$  #', '#   . #', '#######'],
    ['######', '#@   #', '# \$\$ #', '#  . #', '# .  #', '######'],
    ['#######', '#..   #', '# \$#  #', '# \$ @ #', '#     #', '#######'],
  ];
  static const _l2 = [
    ['########', '#   #  #', '# \$   .#', '# #\$## #', '# @ .  #', '########'],
    ['#######', '#.  ..#', '# \$\$\$ #', '#  @  #', '#######'],
    ['########', '#.     #', '#.\$\$#  #', '#  @   #', '########'],
  ];

  static const _k = Color(0xFF1A1426);
  static final _pal = <String, Color>{
    'K': _k,
    'Y': const Color(0xFFFFC928),
    'y': const Color(0xFFD99A10),
    'S': const Color(0xFFFFC9A0),
    'B': const Color(0xFF2F6BDB),
    'b': const Color(0xFF1F4BA0),
    'R': const Color(0xFFE8484A),
    'N': const Color(0xFF6B3B1F),
    'W': const Color(0xFFFFFFFF),
  };
  static final _heroDown = [
    Sprite(['....YYYY....', '...YYYYYY...', '..yYYYYYYy..', '...SSSSSS...', '...SKSSKS...', '...SSSSSS...',
      '..RRBBBBRR..', '.SRRBBBBRRS.', '.S.BBBBBB.S.', '...BBBBBB...', '...bb..bb...', '..NNN..NNN..'], _pal),
    Sprite(['....YYYY....', '...YYYYYY...', '..yYYYYYYy..', '...SSSSSS...', '...SKSSKS...', '...SSSSSS...',
      '..RRBBBBRR..', '.SRRBBBBRRS.', '.S.BBBBBB.S.', '...BBBBBB...', '..bb....bb..', '.NNN....NNN.'], _pal),
  ];
  static final _heroUp = [
    Sprite(['....YYYY....', '...YYYYYY...', '..yYYYYYYy..', '...yyyyyy...', '...SSSSSS...', '...SSSSSS...',
      '..RRRRRRRR..', '.SRRRRRRRRS.', '.S.BBBBBB.S.', '...BBBBBB...', '...bb..bb...', '..NNN..NNN..'], _pal),
    Sprite(['....YYYY....', '...YYYYYY...', '..yYYYYYYy..', '...yyyyyy...', '...SSSSSS...', '...SSSSSS...',
      '..RRRRRRRR..', '.SRRRRRRRRS.', '.S.BBBBBB.S.', '...BBBBBB...', '..bb....bb..', '.NNN....NNN.'], _pal),
  ];
  static final _heroSide = [
    Sprite(['....YYYY....', '...YYYYYYY..', '..yYYYYYYYY.', '...SSSSSS...', '...SSSSKS...', '...SSSSSSS..',
      '...RRBBRR...', '...RRBBSSS..', '...BBBBBB...', '...BBBBBB...', '....bbbb....', '...NNNNNN...'], _pal),
    Sprite(['....YYYY....', '...YYYYYYY..', '..yYYYYYYYY.', '...SSSSSS...', '...SSSSKS...', '...SSSSSSS..',
      '...RRBBRR...', '...RRBBSSS..', '...BBBBBB...', '...BBBBBB...', '..bb....bb..', '.NNN....NNN.'], _pal),
  ];
  static final _crateRows = ['KKKKKKKKKKKK', 'KLLLLLLLLLLK', 'KLNOOOOOONLK', 'KLONOOOONOLK', 'KLOONOONOOLK',
    'KLOOONNOOOLK', 'KLOOONNOOOLK', 'KLOONOONOOLK', 'KLONOOOONOLK', 'KLNOOOOOONLK', 'KLLLLLLLLLLK', 'KKKKKKKKKKKK'];
  static final _crate = Sprite(_crateRows,
      {'K': _k, 'L': const Color(0xFFE0A15A), 'O': const Color(0xFFB8733A), 'N': const Color(0xFF7A4520)});
  static final _crateOk = Sprite(_crateRows,
      {'K': _k, 'L': const Color(0xFFB8F27A), 'O': const Color(0xFF4FBF4A), 'N': const Color(0xFF237A2E)});
  static final _wall = Sprite(['KKKKKKKKKKKK', 'RRRRRKRRRRRK', 'RrrrrKRrrrrK', 'KKKKKKKKKKKK', 'RRKRRRRRKRRR',
    'rrKRrrrrKRrr', 'KKKKKKKKKKKK', 'RRRRRKRRRRRK', 'RrrrrKRrrrrK', 'KKKKKKKKKKKK', 'RRKRRRRRKRRR', 'rrKRrrrrKRrr'],
      {'K': const Color(0xFF3A2438), 'R': const Color(0xFFB0524A), 'r': const Color(0xFF8A3A38)});
  static final _floor = Sprite(['GGGGGGGGGGGg', 'GGGGGGGGGGGg', 'GGgGGGGGGGGg', 'GGGGGGGGGGGg', 'GGGGGGGgGGGg',
    'GGGGGGGGGGGg', 'GGGGGGGGGGGg', 'GGGGgGGGGGGg', 'GGGGGGGGGGGg', 'GGGGGGGGGgGg', 'GGGGGGGGGGGg', 'gggggggggggg'],
      {'G': const Color(0xFF5E5A78), 'g': const Color(0xFF4A4662)});
  static final _goal = Sprite(['............', '............', '....RRRR....', '...RWWWWR...', '..RWRRRRWR..',
    '..RWRWWRWR..', '..RWRWWRWR..', '..RWRRRRWR..', '...RWWWWR...', '....RRRR....', '............', '............'],
      {'R': const Color(0xFFFF4D6D), 'W': const Color(0xFFFFE0E6)});

  late List<String> _map;
  int _w = 0, _h = 0;
  final Set<int> _goals = {};
  List<(int, int)> _boxes = [];
  List<Offset> _boxVis = [];
  (int, int) _p = (0, 0);
  Offset _pVis = Offset.zero;
  int _face = 2; // 0 up 1 right 2 down 3 left
  double _walk = 0;
  final List<((int, int), List<(int, int)>)> _hist = [];
  int _level = 0;
  late List<String> _next;
  int _moves = 0;
  double _t = 0;
  double _clearT = -1;
  double _bump = 0;
  int _heldDir = -1;
  double _holdT = 0;
  Offset? _swipeStart;
  bool _swiped = false;
  int _pressedBtn = -1;
  double _undoFlash = 0;
  bool _stuck = false;
  final List<double> _boxPulse = [0, 0, 0, 0];
  final List<bool> _onGoal = [false, false, false, false];

  static const _dirs = [(0, -1), (1, 0), (0, 1), (-1, 0)];
  static const _btn = [Offset(96, 478), Offset(150, 532), Offset(96, 586), Offset(42, 532)];
  static const _undoR = Rect.fromLTWH(222, 488, 110, 44);
  static const _resetR = Rect.fromLTWH(222, 548, 110, 44);

  @override
  void init() {
    _next = pick(_l2);
    _load(pick(_l1));
  }

  void _load(List<String> rows) {
    _map = rows;
    _h = rows.length;
    _w = rows.fold(0, (m, r) => max(m, r.length));
    _goals.clear();
    _boxes = [];
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final ch = rows[y][x];
        if (ch == '.' || ch == '*' || ch == '+') _goals.add(y * 16 + x);
        if (ch == '\$' || ch == '*') _boxes.add((x, y));
        if (ch == '@' || ch == '+') _p = (x, y);
      }
    }
    _boxVis = [for (final b in _boxes) _tilePos(b.$1, b.$2)];
    _pVis = _tilePos(_p.$1, _p.$2);
    _hist.clear();
    for (var i = 0; i < 4; i++) {
      _onGoal[i] = i < _boxes.length && _goals.contains(_boxes[i].$2 * 16 + _boxes[i].$1);
    }
    _stuck = false;
    _face = 2;
  }

  Offset get _origin => Offset(180 - _w * _ts / 2, 272 - _h * _ts / 2);
  Offset _tilePos(int x, int y) => _origin + Offset(x * _ts, y * _ts);
  bool _wallAt(int x, int y) => y < 0 || y >= _h || x < 0 || x >= _map[y].length || _map[y][x] == '#';
  int _boxAt(int x, int y) => _boxes.indexWhere((b) => b.$1 == x && b.$2 == y);

  // ------------------------------------------------------------ moves ---

  void _move(int d) {
    if (host.finished || _clearT >= 0) return;
    _face = d;
    final (dx, dy) = _dirs[d];
    final nx = _p.$1 + dx, ny = _p.$2 + dy;
    if (_wallAt(nx, ny)) {
      _bumpFx();
      return;
    }
    final bi = _boxAt(nx, ny);
    if (bi >= 0) {
      final bx = nx + dx, by = ny + dy;
      if (_wallAt(bx, by) || _boxAt(bx, by) >= 0) {
        _bumpFx();
        return;
      }
      _hist.add((_p, List.of(_boxes)));
      _boxes[bi] = (bx, by);
      host.sfx(Sfx.thud, volume: .5, rate: 1.3);
      host.fx.smoke(_tilePos(nx, ny) + Offset(_ts / 2 - dx * 14, _ts - 4), count: 3, color: const Color(0xAAB8B0A0), size: 10);
      final on = _goals.contains(by * 16 + bx);
      if (on && !_onGoal[bi]) {
        _boxPulse[bi] = 1;
        host.sfx(Sfx.pCoin);
        host.fx.sparkle(_tilePos(bx, by) + const Offset(_ts / 2, _ts / 2), count: 8, radius: 22, color: Pal.lime);
        host.fx.pop(host.tr('nice', 'NICE!'), _tilePos(bx, by) + const Offset(_ts / 2, -6), color: Pal.lime, size: 20);
      }
      _onGoal[bi] = on;
    } else {
      _hist.add((_p, List.of(_boxes)));
      host.sfx(Sfx.step, volume: .35, rate: 1.2 + (_moves % 2) * .15);
    }
    _p = (nx, ny);
    _moves++;
    _walk += 1;
    _checkStuck();
    if (_boxes.every((b) => _goals.contains(b.$2 * 16 + b.$1))) _levelClear();
  }

  void _bumpFx() {
    _bump = 1;
    host.sfx(Sfx.pHit, volume: .5);
  }

  void _checkStuck() {
    _stuck = false;
    for (final b in _boxes) {
      if (_goals.contains(b.$2 * 16 + b.$1)) continue;
      final u = _wallAt(b.$1, b.$2 - 1), dn = _wallAt(b.$1, b.$2 + 1);
      final l = _wallAt(b.$1 - 1, b.$2), r = _wallAt(b.$1 + 1, b.$2);
      if ((u || dn) && (l || r)) _stuck = true;
    }
    if (_stuck) {
      _undoFlash = 1;
      host.sfx(Sfx.oops, volume: .6);
    }
  }

  void _undo() {
    if (_hist.isEmpty || host.finished || _clearT >= 0) return;
    final (p, boxes) = _hist.removeLast();
    _p = p;
    _boxes = boxes;
    for (var i = 0; i < _boxes.length; i++) {
      _onGoal[i] = _goals.contains(_boxes[i].$2 * 16 + _boxes[i].$1);
    }
    _moves++;
    _checkStuck();
    host.sfx(Sfx.pSelect, rate: .8);
    host.fx.sparkle(_pVis + const Offset(_ts / 2, _ts / 2), count: 5, radius: 18, color: Pal.sky);
  }

  void _reset() {
    if (_hist.isEmpty || host.finished || _clearT >= 0) return;
    final first = _hist.first;
    _hist.clear();
    _p = first.$1;
    _boxes = List.of(first.$2);
    for (var i = 0; i < _boxes.length; i++) {
      _onGoal[i] = _goals.contains(_boxes[i].$2 * 16 + _boxes[i].$1);
    }
    _checkStuck();
    host.sfx(Sfx.whoosh);
  }

  void _levelClear() {
    _clearT = 0;
    host.sfx(Sfx.pPowerup);
    host.shake(5);
    host.fx.confetti(at: _origin + Offset(_w * _ts / 2, _h * _ts / 2), count: 40);
    if (_level == 1) {
      final left = host.timeLeft;
      host.win(stars: left > 8 ? 3 : (left > 3 ? 2 : 1));
    }
  }

  // ------------------------------------------------------------ input ---

  int _btnAt(Offset p) {
    for (var i = 0; i < 4; i++) {
      if ((p - _btn[i]).distance < 30) return i;
    }
    if (_undoR.inflate(4).contains(p)) return 4;
    if (_resetR.inflate(4).contains(p)) return 5;
    return -1;
  }

  @override
  void onDown(Offset p) {
    final b = _btnAt(p);
    _pressedBtn = b;
    if (b >= 0 && b < 4) {
      _heldDir = b;
      _holdT = -.22;
      _move(b);
    } else if (b == 4) {
      _undo();
    } else if (b == 5) {
      _reset();
    } else {
      _swipeStart = p;
      _swiped = false;
    }
  }

  @override
  void onMove(Offset p) {
    final s = _swipeStart;
    if (s == null || _swiped) return;
    final d = p - s;
    if (d.distance < 22) return;
    _swiped = true;
    _move(d.dx.abs() > d.dy.abs() ? (d.dx > 0 ? 1 : 3) : (d.dy > 0 ? 2 : 0));
  }

  @override
  void onUp(Offset p) {
    final s = _swipeStart;
    if (s != null && !_swiped) {
      // tap next to the worker = step toward it
      final c = _pVis + const Offset(_ts / 2, _ts / 2);
      final d = p - c;
      if (d.distance > 10 && d.distance < _ts * 2.2) {
        _move(d.dx.abs() > d.dy.abs() ? (d.dx > 0 ? 1 : 3) : (d.dy > 0 ? 2 : 0));
      }
    }
    _swipeStart = null;
    _heldDir = -1;
    _pressedBtn = -1;
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    switch (key) {
      case 'up':
        _move(0);
      case 'right':
        _move(1);
      case 'down':
        _move(2);
      case 'left':
        _move(3);
      case 'action':
        _undo();
    }
  }

  // ----------------------------------------------------------- update ---

  @override
  void update(double dt) {
    _t += dt;
    _bump = M.approach(_bump, 0, 12, dt);
    _undoFlash = _stuck ? 1 : M.approach(_undoFlash, 0, 4, dt);
    for (var i = 0; i < 4; i++) {
      _boxPulse[i] = M.approach(_boxPulse[i], 0, 5, dt);
    }
    if (_heldDir >= 0 && host.pointerDown) {
      _holdT += dt;
      if (_holdT > .16) {
        _holdT = 0;
        _move(_heldDir);
      }
    }
    _pVis = M.approachO(_pVis, _tilePos(_p.$1, _p.$2), 26, dt);
    for (var i = 0; i < _boxes.length; i++) {
      _boxVis[i] = M.approachO(_boxVis[i], _tilePos(_boxes[i].$1, _boxes[i].$2), 26, dt);
    }
    if (_clearT >= 0) {
      _clearT += dt;
      if (_clearT > 1.0 && _level == 0) {
        _level = 1;
        _clearT = -1;
        _load(_next);
        host.sfx(Sfx.pSelect);
      }
    }
  }

  // ----------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    // warehouse backdrop
    Retro.tiles(c, const Rect.fromLTWH(0, 0, 360, 640), 24, const Color(0xFF231B35), const Color(0xFF281F3C));
    for (var i = 0; i < 4; i++) {
      // shelves silhouettes
      final x = i * 96.0 - 10;
      c.drawRect(Rect.fromLTWH(x, 60, 70, 6), D.fill(const Color(0xFF3A2E52)));
      c.drawRect(Rect.fromLTWH(x, 100, 70, 6), D.fill(const Color(0xFF3A2E52)));
      for (var k = 0; k < 3; k++) {
        c.drawRect(Rect.fromLTWH(x + 6 + k * 22, 78, 16, 22), D.fill(const Color(0xFF4A3A2A)));
      }
    }
    // swinging lamp light
    final lx = 180 + sin(_t * 1.4) * 40;
    c.drawPath(
        Path()
          ..moveTo(lx - 10, 110)
          ..lineTo(lx + 10, 110)
          ..lineTo(lx + 150, 460)
          ..lineTo(lx - 150, 460)
          ..close(),
        D.fill(const Color(0x14FFE9A0)));
    c.drawLine(Offset(180, 36), Offset(lx, 106), D.stroke(const Color(0xFF111111), 2));
    c.drawRect(Rect.fromLTWH(lx - 12, 104, 24, 8), D.fill(const Color(0xFFFFD966)));

    // HUD
    for (var i = 0; i < 2; i++) {
      final done = i < _level || (i == _level && _clearT >= 0) || (host.finished && i <= _level && _clearT >= 0);
      final cur = i == _level;
      final r = Rect.fromLTWH(20 + i * 34.0, 46, 26, 26);
      c.drawRect(r, D.fill(done ? const Color(0xFF4FBF4A) : (cur ? const Color(0xFFFFC928) : const Color(0xFF3A2E52))));
      c.drawRect(r, D.stroke(_k, 3)..strokeCap = StrokeCap.butt);
      PixelFont.draw(c, '${i + 1}', r.center + const Offset(0, -7), 2, _k, align: 0);
    }
    final okCount = List.generate(_boxes.length, (i) => _onGoal[i]).where((e) => e).length;
    _crate.draw(c, const Offset(250, 46), scale: 2);
    PixelFont.draw(c, '$okCount/${_boxes.length}', const Offset(280, 51), 3, Pal.white, shadow: _k);

    // board
    final o = _origin;
    c.drawRect(Rect.fromLTWH(o.dx - 6, o.dy - 6 + 8, _w * _ts + 12, _h * _ts + 12), D.fill(const Color(0x66000000)));
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _map[y].length; x++) {
        final p = _tilePos(x, y);
        if (_map[y][x] == '#') {
          _wall.draw(c, p, scale: 3);
        } else {
          _floor.draw(c, p, scale: 3);
          if (_goals.contains(y * 16 + x)) {
            final pulse = .8 + .2 * M.wave(_t, 2);
            _goal.draw(c, p + Offset(_ts * (1 - pulse) / 2, _ts * (1 - pulse) / 2), scale: 3 * pulse);
          }
        }
      }
    }
    // boxes
    for (var i = 0; i < _boxes.length; i++) {
      final on = _onGoal[i];
      final pulse = _boxPulse[i];
      final sc = 3 * (1 + pulse * .2);
      final pos = _boxVis[i] + Offset(_ts / 2, _ts / 2);
      c.drawRect(Rect.fromCenter(center: pos + const Offset(0, 17), width: 30, height: 5), D.fill(const Color(0x55000000)));
      (on ? _crateOk : _crate).drawCentered(c, pos + Offset(0, -pulse * 6), scale: sc);
      if (on) {
        final a = .5 + .5 * M.wave(_t + i * .3, 2);
        c.drawRect(Rect.fromCenter(center: pos, width: 38, height: 38), D.stroke(Color.fromRGBO(180, 255, 120, a * .7), 2)..strokeCap = StrokeCap.butt);
      }
    }
    // worker
    final frame = (_walk.floor() % 2);
    final moving = (_pVis - _tilePos(_p.$1, _p.$2)).distance > 2;
    final spr = switch (_face) {
      0 => _heroUp[moving ? frame : 0],
      2 => _heroDown[moving ? frame : 0],
      _ => _heroSide[moving ? frame : 0],
    };
    final bumpOff = Offset(_dirs[_face].$1 * _bump * 4, _dirs[_face].$2 * _bump * 4);
    final hp = _pVis + Offset(_ts / 2, _ts / 2) + bumpOff + Offset(0, moving ? -2 : 0);
    c.drawRect(Rect.fromCenter(center: hp + const Offset(0, 17), width: 24, height: 5), D.fill(const Color(0x55000000)));
    final lost = host.finished && _clearT < 0;
    spr.drawCentered(c, hp, scale: 3, flipX: _face == 3, tint: lost && (_t * 6).floor().isEven ? const Color(0xFF7FA0FF) : null);
    if (_stuck && !host.finished) {
      // sweat + "!" : that box is stuck, hit undo
      PixelFont.draw(c, '!', hp + const Offset(10, -34), 3, Pal.red, shadow: _k);
      c.drawRect(Rect.fromLTWH(hp.dx - 16, hp.dy - 14 + (_t * 30) % 8, 4, 6), D.fill(Pal.sky));
    }
    if (_clearT >= 0 && _level == 0) {
      final s = M.easeOutBack((_clearT / .3).clamp(0.0, 1.0));
      c.save();
      c.translate(180, 272);
      c.scale(s);
      c.drawRect(const Rect.fromLTWH(-110, -26, 220, 52), D.fill(_k));
      c.drawRect(const Rect.fromLTWH(-104, -20, 208, 40), D.fill(const Color(0xFF4FBF4A)));
      PixelFont.draw(c, '1/2', const Offset(-24, -14), 4, Pal.white, align: 0, shadow: _k);
      final w = D.fill(Pal.white);
      for (final q in const [Offset(40, 0), Offset(46, 6), Offset(52, 0), Offset(58, -6), Offset(64, -12)]) {
        c.drawRect(Rect.fromCenter(center: q, width: 7, height: 7), w);
      }
      c.restore();
    }

    // controls
    for (var i = 0; i < 4; i++) {
      final pressed = _pressedBtn == i && host.pointerDown;
      final p = _btn[i] + Offset(0, pressed ? 3 : 0);
      c.drawRect(Rect.fromCenter(center: _btn[i] + const Offset(0, 5), width: 50, height: 50), D.fill(_k));
      c.drawRect(Rect.fromCenter(center: p, width: 50, height: 50), D.fill(const Color(0xFF4A4468)));
      c.drawRect(Rect.fromCenter(center: p, width: 50, height: 50), D.stroke(_k, 3)..strokeCap = StrokeCap.butt);
      c.drawRect(Rect.fromCenter(center: p + const Offset(0, -18), width: 42, height: 4), D.fill(const Color(0x33FFFFFF)));
      _pixArrow(c, p, i);
    }
    c.drawRect(Rect.fromCenter(center: const Offset(96, 532), width: 26, height: 26), D.fill(const Color(0xFF3A3452)));
    _pixButton(c, _undoR, const Color(0xFFFF8A1F), _undoFlash > 0 ? M.wave(_t, 4) : 0, 0);
    _pixButton(c, _resetR, const Color(0xFF8C4DFF), 0, 1);

    Retro.scanlines(c, alpha: .10);
    Retro.vignette(c, strength: .4);
    if (host.time < 2.5 && _moves == 0) {
      D.hand(c, _btn[_hintDir()], _t, size: 38);
    }
  }

  int _hintDir() {
    // point at a direction that actually moves the worker
    for (final d in [1, 2, 3, 0]) {
      final (dx, dy) = _dirs[d];
      if (!_wallAt(_p.$1 + dx, _p.$2 + dy)) return d;
    }
    return 1;
  }

  void _pixArrow(Canvas c, Offset o, int d) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(d * pi / 2);
    final p = D.fill(Pal.white);
    for (var row = 0; row < 4; row++) {
      c.drawRect(Rect.fromLTWH(-3.0 * (row * 2 + 1), -10 + row * 4.0, 6.0 * (row * 2 + 1), 4), p);
    }
    c.drawRect(const Rect.fromLTWH(-4, 6, 8, 8), p);
    c.restore();
  }

  void _pixButton(Canvas c, Rect r, Color col, double glow, int icon) {
    final pressed = _pressedBtn == 4 + icon && host.pointerDown;
    final rr = r.shift(Offset(0, pressed ? 3 : 0));
    c.drawRect(r.shift(const Offset(0, 5)), D.fill(_k));
    c.drawRect(rr, D.fill(Color.lerp(col, Pal.white, glow * .5)!));
    c.drawRect(rr, D.stroke(_k, 3)..strokeCap = StrokeCap.butt);
    final ctr = rr.center;
    final w = D.fill(Pal.white);
    if (icon == 0) {
      // undo: pixel curved arrow
      for (final q in const [
        Offset(-6, -8), Offset(-2, -8), Offset(2, -8), Offset(6, -4), Offset(6, 0), Offset(2, 4), Offset(-2, 4),
      ]) {
        c.drawRect(Rect.fromCenter(center: ctr + q, width: 5, height: 5), w);
      }
      for (final q in const [Offset(-10, -8), Offset(-6, -12), Offset(-6, -4)]) {
        c.drawRect(Rect.fromCenter(center: ctr + q, width: 5, height: 5), w);
      }
    } else {
      // reset: pixel ring
      for (var k = 0; k < 10; k++) {
        if (k == 2) continue;
        final a = k * pi / 5;
        c.drawRect(Rect.fromCenter(center: ctr + Offset(cos(a) * 10, sin(a) * 10), width: 5, height: 5), w);
      }
      c.drawRect(Rect.fromCenter(center: ctr + const Offset(10, 6), width: 5, height: 5), w);
    }
    if (glow > 0) {
      c.drawRect(rr.inflate(4), D.stroke(Color.fromRGBO(255, 230, 80, glow), 3)..strokeCap = StrokeCap.butt);
    }
  }
}
