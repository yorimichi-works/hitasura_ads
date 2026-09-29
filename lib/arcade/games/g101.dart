import 'dart:typed_data';
import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.101 Dungeon Escape FPS — SUPER RARE. A hand-rolled Wolfenstein-style
/// raycaster: procedural brick/moss/stone textures, floor & ceiling casting,
/// torch flicker, z-buffered billboard sprites, minimap and a status bar face.
/// Find the key, reach the EXIT before HE gets you.
class G101 extends MiniGame {
  static const _map = [
    '###########',
    '#P..#....K#',
    '#.#.#.##.##',
    '#.#...#...#',
    '#.###.#.#.#',
    '#...#...#.#',
    '###.#####.#',
    '#K..#.....#',
    '#.#.#.###.#',
    '#.#...#G..E',
    '###########',
  ];
  static const _n = 11;

  // view
  static const _vt = 40.0; // view top
  static const _vh = 430.0; // view height
  static const _vw = 360.0;
  static const _cols = 120;
  static const _colW = _vw / _cols;
  static const _tex = 16;

  late final List<List<int>> _grid; // 0 floor, 1 brick, 2 moss, 3 blue stone, 4 exit
  late final List<Int32List> _textures; // index by wall type (4 = locked exit, 5 = open exit)
  final Float32List _pos = Float32List(12 * 6000);
  final Int32List _colsBuf = Int32List(6 * 6000);
  int _quads = 0;
  final Float64List _zbuf = Float64List(_cols);

  // player
  double _px = 1.5, _py = 1.5, _ang = 0;
  double _walk = 0; // bob phase
  double _moveAmt = 0;
  double _fov = .66;
  bool _hasKey = false;
  late Offset _keyPos;
  late Offset _exitCell;
  final List<Offset> _candles = [];

  // ghost
  double _gx = 7.5, _gy = 9.5;
  double _gSpeed = 1.0;
  double _pathT = 0;
  Offset? _gNext;
  Offset? _gPrev;
  bool _hunting = false;
  double _gSeen = 0;
  bool _caught = false;
  double _caughtT = 0;
  bool _escaped = false;
  double _escT = 0;

  // fx / timing
  double _t = 0;
  double _flicker = 1;
  double _heartT = 0;
  double _lockedCd = 0;
  double _keyFlash = 0;
  double _stepT = 0;

  // input
  Offset? _anchor;
  Offset _stick = Offset.zero;
  double _kTurn = 0, _kMove = 0;

  static final _faceNormal = _face(false, false);
  static final _faceScared = _face(true, false);
  static final _faceHappy = _face(false, true);

  @override
  void init() {
    _grid = List.generate(_n, (r) => List.filled(_n, 0));
    final keys = <Offset>[];
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        final ch = _map[r][c];
        switch (ch) {
          case '#':
            // mix wall materials by region for variety
            final h = (r * 7 + c * 13) % 11;
            _grid[r][c] = r >= 6 ? (h < 3 ? 2 : 3) : (h < 3 ? 2 : 1);
          case 'E':
            _grid[r][c] = 4;
            _exitCell = Offset(c + .5, r + .5);
          case 'P':
            _px = c + .5;
            _py = r + .5;
          case 'K':
            keys.add(Offset(c + .5, r + .5));
          case 'G':
            _gx = c + .5;
            _gy = r + .5;
        }
      }
    }
    _keyPos = pick(keys);
    _ang = 0; // facing +x (east)
    _candles.addAll(const [Offset(6.5, 1.5), Offset(7.5, 7.5), Offset(4.5, 9.5), Offset(9.5, 5.5), Offset(1.5, 4.5)]);
    _textures = [
      Int32List(0),
      _brickTex(),
      _mossTex(),
      _blueTex(),
      _doorTex(false),
      _doorTex(true),
    ];
  }

  // ------------------------------------------------------------ textures ---

  static int _rgb(int r, int g, int b) => (r.clamp(0, 255) << 16) | (g.clamp(0, 255) << 8) | b.clamp(0, 255);

  Int32List _brickTex() {
    final t = Int32List(_tex * _tex);
    final r = Random(11);
    for (var y = 0; y < _tex; y++) {
      for (var x = 0; x < _tex; x++) {
        final row = y ~/ 4;
        final off = row.isOdd ? 4 : 0;
        final mortar = y % 4 == 3 || (x + off) % 8 == 7;
        if (mortar) {
          t[y * _tex + x] = _rgb(70 + r.nextInt(12), 62, 58);
        } else {
          final brick = ((x + off) ~/ 8) * 3 + row;
          final base = 140 + (brick * 37 % 40);
          final n = r.nextInt(22) - 11;
          final hi = y % 4 == 0 ? 18 : 0;
          t[y * _tex + x] = _rgb(base + n + hi, 58 + n ~/ 2 + hi ~/ 2, 44 + n ~/ 2);
        }
      }
    }
    return t;
  }

  Int32List _mossTex() {
    final t = Int32List(_tex * _tex);
    final r = Random(23);
    for (var y = 0; y < _tex; y++) {
      for (var x = 0; x < _tex; x++) {
        final block = (y ~/ 8) * 2 + ((x + (y ~/ 8).isOdd.hashCode % 2 * 4) ~/ 8);
        final edge = y % 8 == 7 || x % 8 == 7;
        var g = 110 + (block * 23 % 30) + r.nextInt(16) - 8;
        if (edge) g = 55;
        final moss = (sin(x * .9 + y * .4) + sin(y * 1.3 - x * .2) + r.nextDouble()) > 1.4 || y >= 13 && r.nextDouble() < .6;
        t[y * _tex + x] = moss ? _rgb(60 + r.nextInt(20), 120 + r.nextInt(40), 50) : _rgb(g, g, g - 6);
      }
    }
    return t;
  }

  Int32List _blueTex() {
    final t = Int32List(_tex * _tex);
    final r = Random(37);
    for (var y = 0; y < _tex; y++) {
      for (var x = 0; x < _tex; x++) {
        final row = y ~/ 5;
        final off = row.isOdd ? 5 : 0;
        final edge = y % 5 == 4 || (x + off) % 10 == 9;
        final n = r.nextInt(18) - 9;
        t[y * _tex + x] = edge ? _rgb(24, 28, 70) : _rgb(58 + n, 70 + n, 150 + n + (y % 5 == 0 ? 25 : 0));
      }
    }
    return t;
  }

  Int32List _doorTex(bool open) {
    final t = Int32List(_tex * _tex);
    for (var y = 0; y < _tex; y++) {
      for (var x = 0; x < _tex; x++) {
        var c = _rgb(96 + (x % 4 == 0 ? -20 : 0), 98 + (x % 4 == 0 ? -20 : 0), 110);
        if (x == 0 || x == 15 || y == 15) c = _rgb(50, 50, 60);
        if ((x == 2 || x == 13) && y % 4 == 1) c = _rgb(200, 200, 210); // rivets
        if (y >= 1 && y <= 3 && x >= 3 && x <= 12) c = open ? _rgb(60, 255, 120) : _rgb(255, 60, 60); // sign
        if (y == 9 && x >= 10 && x <= 12) c = _rgb(230, 200, 60); // handle
        t[y * _tex + x] = c;
      }
    }
    return t;
  }

  static Sprite _face(bool scared, bool happy) {
    final rows = scared
        ? [
            '...HHHHHH...',
            '..HHHHHHHH..',
            '.HKKSSSSKKH.',
            '.HSSSSSSSSH.',
            'wSWWSSSSWWS.',
            'wSWKSSSSKWSw',
            '.SSSSssSSSSw',
            '.SSSSssSSSS.',
            '.SSSKKKKSSS.',
            '..SSKRRKSS..',
            '...SKKKKS...',
            '....SSSS....',
            '..BBBBBBBB..',
            '.BBBBBBBBBB.',
          ]
        : happy
            ? [
                '...HHHHHH...',
                '..HHHHHHHH..',
                '.HHSSSSSSHH.',
                '.HSSSSSSSSH.',
                '.SKKSSSSKKS.',
                '.SKSKSSKSKS.',
                '.SSSSssSSSS.',
                '.SPSSssSSPS.',
                '.SRTTTTTTRS.',
                '..SRRRRRRS..',
                '...SSSSSS...',
                '....SSSS....',
                '..BBBBBBBB..',
                '.BBBBBBBBBB.',
              ]
            : [
                '...HHHHHH...',
                '..HHHHHHHH..',
                '.HHSSSSSSHH.',
                '.HSSSSSSSSH.',
                '.SKKSSSSKKS.',
                '.SWKSSSSWKS.',
                '.SSSSssSSSS.',
                '.SSSSssSSSS.',
                '.SSSRRRRSSS.',
                '..SSSSSSSS..',
                '...SSSSSS...',
                '....SSSS....',
                '..BBBBBBBB..',
                '.BBBBBBBBBB.',
              ];
    return Sprite(rows, const {
      'H': Color(0xFF8A5A2B),
      'S': Color(0xFFF2C08F),
      's': Color(0xFFD29A6A),
      'K': Color(0xFF1A1020),
      'W': Color(0xFFFFFFFF),
      'R': Color(0xFFB0303A),
      'T': Color(0xFFFFFFFF),
      'B': Color(0xFF3D6BFF),
      'w': Color(0xFF9AD8FF),
      'P': Color(0xFFFF9AA8),
    });
  }

  // ------------------------------------------------------------ gameplay ---

  bool _solid(double x, double y) {
    final c = x.floor(), r = y.floor();
    if (r < 0 || c < 0 || r >= _n || c >= _n) return true;
    return _grid[r][c] != 0;
  }

  @override
  void update(double dt) {
    _t += dt;
    _lockedCd -= dt;
    _keyFlash = M.approach(_keyFlash, 0, 3, dt);
    _flicker = .9 + .07 * sin(_t * 13) * sin(_t * 7.3) + .03 * sin(_t * 31);

    if (_caught) {
      _caughtT += dt;
      return;
    }
    if (_escaped) {
      _escT += dt;
      _px += cos(_ang) * dt * 1.2;
      _py += sin(_ang) * dt * 1.2;
      return;
    }

    // --- player movement
    final turn = (_stick.dx * 2.7 + _kTurn * 2.4);
    final mv = (-_stick.dy + _kMove).clamp(-1.0, 1.0);
    _ang += turn * dt;
    final sprint = mv > .85;
    final sp = (sprint ? 3.1 : 2.7) * mv;
    _moveAmt = M.approach(_moveAmt, mv.abs(), 8, dt);
    _fov = M.approach(_fov, sprint ? .74 : .66, 4, dt);
    final dx = cos(_ang) * sp * dt, dy = sin(_ang) * sp * dt;
    const pr = .3;
    if (!_solid(_px + dx + pr * dx.sign, _py) && !_solid(_px + dx + pr * dx.sign, _py + pr) && !_solid(_px + dx + pr * dx.sign, _py - pr)) {
      _px += dx;
    }
    if (!_solid(_px, _py + dy + pr * dy.sign) && !_solid(_px + pr, _py + dy + pr * dy.sign) && !_solid(_px - pr, _py + dy + pr * dy.sign)) {
      _py += dy;
    }
    _walk += sp.abs() * dt * 3.2;
    _stepT += sp.abs() * dt;
    if (_stepT > .9) {
      _stepT = 0;
      host.sfx(Sfx.step, volume: .35, rate: rand(.8, 1.0));
    }

    // --- key
    if (!_hasKey) {
      final d = (Offset(_px, _py) - _keyPos).distance;
      if (d < .55) {
        _hasKey = true;
        _keyFlash = 1;
        host.sfx(Sfx.pickup, volume: 1);
        host.sfx(Sfx.magic, volume: .7);
        host.flash(const Color(0xFFFFE27A), .2);
        host.fx.sparkle(const Offset(180, 260), count: 16, radius: 70, color: Pal.yellow);
        host.fx.pop(host.tr('key', 'KEY!'), const Offset(180, 200), color: Pal.yellow, size: 40, life: 1.1);
        host.fx.pop(host.tr('run', 'RUN!'), const Offset(180, 250), color: Pal.red, size: 30, life: 1.3);
        host.addScore(100);
        host.sfx(Sfx.horror, volume: .7);
      }
    }
    // --- exit door
    final ed = (Offset(_px, _py) - _exitCell).distance;
    if (ed < 1.02) {
      if (_hasKey) {
        _escaped = true;
        _escT = 0;
        _ang = atan2(_exitCell.dy - _py, _exitCell.dx - _px);
        host.sfx(Sfx.open, volume: 1);
        host.sfx(Sfx.fanfare, volume: .8);
        host.flash(const Color(0xFFFFFFFF), .4);
        host.fx.pop(host.tr('escape', 'ESCAPED!'), const Offset(180, 220), color: Pal.lime, size: 40, life: 1.3);
        final left = host.timeLeft;
        host.addScore((left * 20).round());
        host.win(stars: left > 9 ? 3 : (left > 4 ? 2 : 1));
      } else if (_lockedCd <= 0) {
        _lockedCd = 1.2;
        host.sfx(Sfx.buzzer, volume: .6);
        host.fx.pop(host.tr('locked', 'LOCKED!'), const Offset(180, 230), color: Pal.red, size: 30);
      }
    }

    // --- ghost
    _updateGhost(dt);

    // heartbeat pacing by distance
    final gd = (Offset(_gx, _gy) - Offset(_px, _py)).distance;
    _heartT -= dt;
    if (_heartT <= 0 && gd < 6) {
      _heartT = .35 + gd * .15;
      host.sfx(Sfx.heartbeat, volume: (1.2 - gd / 6).clamp(.2, 1.0));
    }
  }

  void _updateGhost(double dt) {
    if (host.time < 2.2) return;
    final pd0 = (Offset(_gx, _gy) - Offset(_px, _py)).distance;
    // HE wanders the halls until you grab the key (or wander too close)
    _hunting = _hasKey || pd0 < 3.2;
    final base = _hunting ? (_hasKey ? 1.5 : 1.25) : .95;
    _gSpeed = base * (.85 + .15 * host.speed);
    _pathT -= dt;
    final gc = Offset(_gx.floorToDouble(), _gy.floorToDouble());
    final pc = Offset(_px.floorToDouble(), _py.floorToDouble());
    if (_pathT <= 0 || _gNext == null) {
      _pathT = _hunting ? .25 : 99;
      if (_hunting) {
        _gNext = _bfsNext(gc.dy.toInt(), gc.dx.toInt(), pc.dy.toInt(), pc.dx.toInt());
      } else {
        // pick a random neighbouring corridor cell, avoid turning back
        final r = gc.dy.toInt(), c = gc.dx.toInt();
        final opts = <Offset>[];
        for (final (dr, dc) in const [(0, 1), (1, 0), (0, -1), (-1, 0)]) {
          final nr = r + dr, nc = c + dc;
          if (nr < 0 || nc < 0 || nr >= _n || nc >= _n || _grid[nr][nc] != 0) continue;
          final o = Offset(nc + .5, nr + .5);
          if (_gPrev != null && o == _gPrev && opts.isNotEmpty) continue;
          opts.add(o);
        }
        if (opts.length > 1 && _gPrev != null) opts.remove(_gPrev);
        _gPrev = Offset(c + .5, r + .5);
        _gNext = opts.isEmpty ? null : pick(opts);
      }
    }
    final target = _hunting && gc == pc ? Offset(_px, _py) : (_gNext ?? Offset(_px, _py));
    final d = target - Offset(_gx, _gy);
    final len = d.distance;
    if (len > .01) {
      final step = min(len, _gSpeed * dt);
      _gx += d.dx / len * step;
      _gy += d.dy / len * step;
    }
    if (len < .05) _pathT = 0;
    final pd = (Offset(_gx, _gy) - Offset(_px, _py)).distance;
    if (pd < 3.5 && _gSeen <= 0) {
      _gSeen = 6;
      host.sfx(Sfx.horror, volume: .5, rate: 1.3);
    }
    _gSeen -= dt;
    if (pd < .5 && !host.finished) {
      _caught = true;
      _caughtT = 0;
      host.sfx(Sfx.horror, volume: 1);
      host.sfx(Sfx.glitch, volume: .8);
      host.sfx(Sfx.hitHeavy, volume: 1);
      host.shake(18, .8);
      host.flash(const Color(0xFFFF0000), .3);
      host.lose();
    }
  }

  /// Next cell center on the shortest path from (r0,c0) to (r1,c1).
  Offset? _bfsNext(int r0, int c0, int r1, int c1) {
    if (r0 == r1 && c0 == c1) return null;
    final prev = List.filled(_n * _n, -1);
    final q = <int>[r0 * _n + c0];
    prev[r0 * _n + c0] = r0 * _n + c0;
    var head = 0;
    const dirs = [(0, 1), (1, 0), (0, -1), (-1, 0)];
    while (head < q.length) {
      final cur = q[head++];
      if (cur == r1 * _n + c1) break;
      final r = cur ~/ _n, c = cur % _n;
      for (final (dr, dc) in dirs) {
        final nr = r + dr, nc = c + dc;
        if (nr < 0 || nc < 0 || nr >= _n || nc >= _n || _grid[nr][nc] != 0) continue;
        final id = nr * _n + nc;
        if (prev[id] != -1) continue;
        prev[id] = cur;
        q.add(id);
      }
    }
    var cur = r1 * _n + c1;
    if (prev[cur] == -1) return null;
    while (prev[cur] != r0 * _n + c0) {
      cur = prev[cur];
      if (cur == r0 * _n + c0) break;
    }
    return Offset(cur % _n + .5, cur ~/ _n + .5);
  }

  @override
  void onTimeUp() => host.lose();

  // --------------------------------------------------------------- input ---

  @override
  void onDown(Offset p) => _anchor = p;

  @override
  void onMove(Offset p) {
    final a = _anchor;
    if (a == null) return;
    var d = (p - a) / 60;
    if (d.distance > 1) d = d / d.distance;
    // small dead zone so pure turns don't drift
    _stick = Offset(d.dx.abs() < .12 ? 0 : d.dx, d.dy.abs() < .15 ? 0 : d.dy);
  }

  @override
  void onUp(Offset p) {
    _anchor = null;
    _stick = Offset.zero;
  }

  @override
  void onKey(String key, bool down) {
    final v = down ? 1.0 : 0.0;
    switch (key) {
      case 'left':
        _kTurn = -v;
      case 'right':
        _kTurn = v;
      case 'up':
        _kMove = v;
      case 'down':
        _kMove = -v;
    }
  }

  // -------------------------------------------------------------- render ---

  void _quad(double x0, double y0, double x1, double y1, int argb) {
    if (_quads >= 6000) return;
    final p = _quads * 12;
    _pos[p] = x0;
    _pos[p + 1] = y0;
    _pos[p + 2] = x1;
    _pos[p + 3] = y0;
    _pos[p + 4] = x1;
    _pos[p + 5] = y1;
    _pos[p + 6] = x0;
    _pos[p + 7] = y0;
    _pos[p + 8] = x1;
    _pos[p + 9] = y1;
    _pos[p + 10] = x0;
    _pos[p + 11] = y1;
    final ci = _quads * 6;
    for (var i = 0; i < 6; i++) {
      _colsBuf[ci + i] = argb;
    }
    _quads++;
  }

  static int _shade(int rgb, double k, [double warm = 1]) {
    final r = ((rgb >> 16) & 255) * k * 1.05;
    final g = ((rgb >> 8) & 255) * k * (.93 + .05 * warm);
    final b = (rgb & 255) * k * .8;
    return 0xFF000000 | (r.clamp(0, 255).toInt() << 16) | (g.clamp(0, 255).toInt() << 8) | b.clamp(0, 255).toInt();
  }

  double get _horizon => _vt + _vh / 2 + sin(_walk) * 5 * _moveAmt + (_caught ? sin(_t * 40) * 8 : 0);

  @override
  void render(Canvas c) {
    const view = Rect.fromLTWH(0, _vt, _vw, _vh);
    c.drawRect(const Rect.fromLTWH(0, 0, 360, _vt), D.fill(const Color(0xFF0B1A4A)));
    c.save();
    c.clipRect(view);
    c.drawRect(view, D.fill(const Color(0xFF0A0710)));
    final hz = _horizon;
    final dirX = cos(_ang), dirY = sin(_ang);
    final plX = -sin(_ang) * _fov, plY = cos(_ang) * _fov;
    _quads = 0;
    final light = _flicker * (_escaped ? 1 + _escT * 2 : 1);

    // ---- floor & ceiling casting (coarse cells)
    const cw = 8.0, ch = 10.0;
    for (var y = _vt; y < _vt + _vh; y += ch) {
      final ym = y + ch / 2;
      final dy = ym - hz;
      if (dy.abs() < 2) continue;
      final floor = dy > 0;
      final dist = _vh / (2 * dy.abs());
      if (dist > 14) continue;
      final shade = (1.25 / (1 + dist * dist * .09)).clamp(.05, 1.0) * light;
      for (var x = 0.0; x < _vw; x += cw) {
        final cam = 2 * (x + cw / 2) / _vw - 1;
        final wx = _px + (dirX + plX * cam) * dist;
        final wy = _py + (dirY + plY * cam) * dist;
        final fx = wx - wx.floorToDouble(), fy = wy - wy.floorToDouble();
        int base;
        if (floor) {
          final grout = fx < .07 || fy < .07 || (fx - .5).abs() < .03;
          final checker = (wx.floor() + wy.floor()).isEven;
          base = grout ? 0x2A2226 : (checker ? 0x5E5250 : 0x4F4546);
        } else {
          final beam = fx < .12 || (fy - .5).abs() < .05;
          base = beam ? 0x3A2616 : 0x241C28;
        }
        _quad(x, y, x + cw, y + ch, _shade(base, shade * (floor ? 1 : .8)));
      }
    }

    // ---- walls (DDA)
    const tex = _tex;
    for (var i = 0; i < _cols; i++) {
      final cam = 2 * (i + .5) / _cols - 1;
      final rdx = dirX + plX * cam, rdy = dirY + plY * cam;
      var mapX = _px.floor(), mapY = _py.floor();
      final ddx = rdx.abs() < 1e-9 ? 1e9 : (1 / rdx).abs();
      final ddy = rdy.abs() < 1e-9 ? 1e9 : (1 / rdy).abs();
      int stepX, stepY;
      double sdx, sdy;
      if (rdx < 0) {
        stepX = -1;
        sdx = (_px - mapX) * ddx;
      } else {
        stepX = 1;
        sdx = (mapX + 1 - _px) * ddx;
      }
      if (rdy < 0) {
        stepY = -1;
        sdy = (_py - mapY) * ddy;
      } else {
        stepY = 1;
        sdy = (mapY + 1 - _py) * ddy;
      }
      var side = 0;
      var type = 0;
      for (var guard = 0; guard < 40; guard++) {
        if (sdx < sdy) {
          sdx += ddx;
          mapX += stepX;
          side = 0;
        } else {
          sdy += ddy;
          mapY += stepY;
          side = 1;
        }
        if (mapX < 0 || mapY < 0 || mapX >= _n || mapY >= _n) {
          type = 1;
          break;
        }
        type = _grid[mapY][mapX];
        if (type != 0) break;
      }
      final perp = max(.05, side == 0 ? sdx - ddx : sdy - ddy);
      _zbuf[i] = perp;
      var wallX = side == 0 ? _py + perp * rdy : _px + perp * rdx;
      wallX -= wallX.floorToDouble();
      var u = (wallX * tex).floor().clamp(0, tex - 1);
      if ((side == 0 && rdx > 0) || (side == 1 && rdy < 0)) u = tex - 1 - u;
      final texData = _textures[type == 4 && _hasKey ? 5 : type];
      final lineH = _vh / perp;
      final top = hz - lineH / 2;
      final k = (1.3 / (1 + perp * perp * .07)).clamp(.07, 1.0) * light * (side == 1 ? .74 : 1);
      final x0 = i * _colW, x1 = x0 + _colW + .4;
      final th = lineH / tex;
      for (var ty = 0; ty < tex; ty++) {
        var y0 = top + ty * th, y1 = y0 + th + .5;
        if (y1 < _vt || y0 > _vt + _vh) continue;
        if (y0 < _vt) y0 = _vt;
        if (y1 > _vt + _vh) y1 = _vt + _vh;
        var col = texData[ty * tex + u];
        if (type == 4) {
          // exit sign glows regardless of distance
          final g = ty >= 1 && ty <= 3 && u >= 3 && u <= 12;
          if (g) {
            _quad(x0, y0, x1, y1, 0xFF000000 | col);
            continue;
          }
        }
        col = _shade(col, k);
        _quad(x0, y0, x1, y1, col);
      }
    }
    final v = ui.Vertices.raw(ui.VertexMode.triangles, Float32List.sublistView(_pos, 0, _quads * 12),
        colors: Int32List.sublistView(_colsBuf, 0, _quads * 6));
    c.drawVertices(v, BlendMode.dst, Paint());
    v.dispose();

    // ---- sprites
    final sprites = <_Spr>[];
    void addS(double x, double y, int kind) {
      final rx = x - _px, ry = y - _py;
      final inv = 1 / (plX * dirY - dirX * plY);
      final tx = inv * (dirY * rx - dirX * ry);
      final ty = inv * (-plY * rx + plX * ry);
      if (ty < .15) return;
      sprites.add(_Spr(kind, _vw / 2 * (1 + tx / ty), ty));
    }

    for (final cd in _candles) {
      addS(cd.dx, cd.dy, 0);
    }
    if (!_hasKey) addS(_keyPos.dx, _keyPos.dy, 1);
    addS(_exitCell.dx - .62, _exitCell.dy, 2);
    addS(_gx, _gy, 3);
    sprites.sort((a, b) => b.depth.compareTo(a.depth));
    for (final s in sprites) {
      _drawSprite(c, s, hz);
    }

    // ---- post: darkness vignette, ghost dread, escape light
    c.drawRect(view,
        Paint()
          ..shader = RadialGradient(colors: const [Color(0x00000000), Color(0xAA000000)], stops: const [.55, 1])
              .createShader(Rect.fromCircle(center: Offset(180, hz), radius: 300)));
    final gd = (Offset(_gx, _gy) - Offset(_px, _py)).distance;
    final dread = ((4.5 - gd) / 4.5).clamp(0.0, 1.0);
    if (dread > 0 && !_escaped) {
      c.drawRect(view,
          Paint()
            ..shader = RadialGradient(colors: [const Color(0x00FF0000), Color.fromRGBO(200, 0, 20, .55 * dread * (.8 + .2 * sin(_t * 9)))],
                stops: const [.45, 1]).createShader(Rect.fromCircle(center: Offset(180, hz), radius: 280)));
    }
    Retro.scanlines(c, rect: view, alpha: .1);
    if (_escaped) {
      c.drawRect(view, Paint()..color = Color.fromRGBO(255, 255, 240, (_escT * .9).clamp(0.0, .9)));
    }
    if (_caught) _jumpScare(c);
    c.restore();

    _renderStatus(c, dread);
    _renderOverlay(c);
  }

  void _drawSprite(Canvas c, _Spr s, double hz) {
    final h = _vh / s.depth;
    final w = h * (s.kind == 3 ? .9 : .6);
    final left = s.sx - w / 2, right = s.sx + w / 2;
    if (right < 0 || left > _vw) return;
    // visible column runs (z-buffer test)
    final clip = Path();
    var any = false;
    final i0 = max(0, (left / _colW).floor()), i1 = min(_cols - 1, (right / _colW).floor());
    var runStart = -1;
    for (var i = i0; i <= i1 + 1; i++) {
      final vis = i <= i1 && s.depth < _zbuf[i];
      if (vis && runStart < 0) runStart = i;
      if (!vis && runStart >= 0) {
        clip.addRect(Rect.fromLTRB(runStart * _colW, _vt, i * _colW, _vt + _vh));
        any = true;
        runStart = -1;
      }
    }
    if (!any) return;
    final shade = (1.3 / (1 + s.depth * s.depth * .07)).clamp(.1, 1.0);
    c.save();
    c.clipPath(clip);
    switch (s.kind) {
      case 0:
        _candle(c, Offset(s.sx, hz + h / 2), h, shade);
      case 1:
        _key(c, Offset(s.sx, hz + h * .12 + sin(_t * 3) * h * .04), h, shade);
      case 2:
        _exitSign(c, Offset(s.sx, hz - h * .38), h);
      case 3:
        _ghost(c, Offset(s.sx, hz + sin(_t * 2.6) * h * .05), h, shade);
    }
    c.restore();
  }

  void _candle(Canvas c, Offset feet, double h, double shade) {
    final s = h / 100;
    final metal = Color.lerp(const Color(0xFF000000), const Color(0xFFB08A3A), shade)!;
    c.drawRect(Rect.fromCenter(center: feet + Offset(0, -2 * s), width: 26 * s, height: 4 * s), D.fill(metal));
    c.drawRect(Rect.fromLTWH(feet.dx - 2 * s, feet.dy - 40 * s, 4 * s, 38 * s), D.fill(metal));
    c.drawLine(feet + Offset(-14 * s, -40 * s), feet + Offset(14 * s, -40 * s), D.stroke(metal, 3 * s));
    for (final dx in [-14.0, 0.0, 14.0]) {
      final base = feet + Offset(dx * s, -40 * s - (dx == 0 ? 6 * s : 0));
      c.drawRect(Rect.fromLTWH(base.dx - 2.5 * s, base.dy - 10 * s, 5 * s, 10 * s), D.fill(Color.lerp(Pal.ink, Pal.cream, shade)!));
      final fl = 1 + .15 * sin(_t * 20 + dx);
      c.drawCircle(base + Offset(0, -14 * s), 10 * s * fl, D.fill(const Color(0x33FFB040)));
      c.drawOval(Rect.fromCenter(center: base + Offset(0, -14 * s), width: 5 * s, height: 9 * s * fl), D.fill(const Color(0xFFFFD66B)));
      c.drawOval(Rect.fromCenter(center: base + Offset(0, -13 * s), width: 2.5 * s, height: 5 * s), D.fill(const Color(0xFFFFFFFF)));
    }
  }

  void _key(Canvas c, Offset o, double h, double shade) {
    final s = h / 100;
    c.drawCircle(o, 24 * s * (1 + .1 * sin(_t * 6)), D.fill(const Color(0x44FFE066)));
    final gold = Color.lerp(const Color(0xFF6B4A00), Pal.gold, .5 + .5 * shade)!;
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(cos(_t * 2.2), 1);
    c.drawCircle(Offset(0, -10 * s), 8 * s, D.stroke(gold, 4 * s));
    c.drawRect(Rect.fromLTWH(-2 * s, -3 * s, 4 * s, 20 * s), D.fill(gold));
    c.drawRect(Rect.fromLTWH(2 * s, 10 * s, 6 * s, 3 * s), D.fill(gold));
    c.drawRect(Rect.fromLTWH(2 * s, 15 * s, 4 * s, 3 * s), D.fill(gold));
    c.restore();
    if (chance(.05)) host.fx.sparkle(o, count: 1, radius: 14 * s, color: Pal.yellow);
  }

  void _exitSign(Canvas c, Offset o, double h) {
    final s = h / 100;
    final col = _hasKey ? const Color(0xFF3CFF7A) : const Color(0xFFFF4040);
    final r = Rect.fromCenter(center: o, width: 44 * s, height: 14 * s);
    c.drawRect(r.inflate(6 * s), D.fill(col.withValues(alpha: .18 + .06 * sin(_t * 8))));
    D.rrect(c, r, 2 * s, const Color(0xFF101410), border: col, borderWidth: max(1, 1.2 * s));
    D.text(c, host.tr('exit', 'EXIT'), o, size: max(5, 10 * s), color: col, maxWidth: r.width);
  }

  void _ghost(Canvas c, Offset o, double h, double shade) {
    final s = h / 100;
    final hunting = _hunting || _caught;
    c.save();
    c.translate(o.dx, o.dy);
    final jitter = hunting ? sin(_t * 47) * 1.2 * s : 0.0;
    c.translate(jitter, 0);
    // glow
    c.drawCircle(const Offset(0, -10) * s, 55 * s, D.fill(Color.fromRGBO(170, 255, 240, .12 * shade + .05)));
    final body = Path()..moveTo(-34 * s, 30 * s);
    body.lineTo(-34 * s, -12 * s);
    body.arcToPoint(Offset(34 * s, -12 * s), radius: Radius.circular(34 * s));
    body.lineTo(34 * s, 30 * s);
    for (var i = 0; i < 6; i++) {
      final x0 = 34 - (i + 1) * 68 / 6;
      final wv = sin(_t * 8 + i * 1.7) * 5;
      body.quadraticBezierTo((x0 + 68 / 12) * s, (44 + wv) * s, x0 * s, 30 * s);
    }
    body.close();
    final a = .78 + .12 * sin(_t * 4);
    c.drawPath(body,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
            Color.fromRGBO(240, 255, 252, a),
            Color.fromRGBO(150, 230, 225, a * .7),
          ]).createShader(Rect.fromLTWH(-34 * s, -46 * s, 68 * s, 90 * s)));
    // arms
    for (final sx in [-1.0, 1.0]) {
      final arm = Path()
        ..moveTo(sx * 30 * s, 0)
        ..quadraticBezierTo(sx * 48 * s, (-6 + sin(_t * 6 + sx) * 6) * s, sx * 50 * s, (-18 + sin(_t * 6 + sx) * 8) * s);
      c.drawPath(arm, D.stroke(Color.fromRGBO(220, 255, 250, a), 9 * s));
    }
    // face
    final eye = hunting ? const Color(0xFFFF2040) : const Color(0xFF14101E);
    for (final sx in [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(sx * 13 * s, -14 * s), width: 15 * s, height: 20 * s), D.fill(const Color(0xFF14101E)));
      if (hunting) c.drawCircle(Offset(sx * 12 * s, -12 * s), 4 * s, D.fill(eye));
    }
    final mo = hunting ? 1.0 + .3 * sin(_t * 12) : .5;
    c.drawOval(Rect.fromCenter(center: Offset(0, 10 * s), width: 16 * s, height: 20 * s * mo), D.fill(const Color(0xFF14101E)));
    c.restore();
  }

  void _jumpScare(Canvas c) {
    final k = M.easeOutBack((_caughtT / .25).clamp(0.0, 1.0));
    c.drawRect(const Rect.fromLTWH(0, _vt, _vw, _vh), D.fill(Color.fromRGBO(20, 0, 0, .6 * k)));
    final h = 300 + 900 * k;
    _ghost(c, Offset(180 + sin(_t * 60) * 10, 300 + h * .02), h, 1);
    c.drawRect(const Rect.fromLTWH(0, _vt, _vw, _vh), D.fill(Color.fromRGBO(255, 0, 30, .25 * (1 - (_caughtT * 2).clamp(0.0, 1.0)))));
  }

  void _renderStatus(Canvas c, double dread) {
    const bar = Rect.fromLTWH(0, 470, 360, 170);
    c.drawRect(bar,
        Paint()
          ..shader = ui.Gradient.linear(bar.topCenter, bar.bottomCenter, const [Color(0xFF16307A), Color(0xFF0B1A4A)]));
    c.drawLine(const Offset(0, 471), const Offset(360, 471), D.stroke(const Color(0xFF6D8BE8), 3));
    // --- minimap
    const mm = Rect.fromLTWH(10, 482, 118, 118);
    D.rrect(c, mm.inflate(4), 6, const Color(0xFF050A1C), border: const Color(0xFF6D8BE8), borderWidth: 2);
    const cs = 118 / _n;
    for (var r = 0; r < _n; r++) {
      for (var col = 0; col < _n; col++) {
        final t = _grid[r][col];
        final rect = Rect.fromLTWH(mm.left + col * cs, mm.top + r * cs, cs + .3, cs + .3);
        if (t == 0) {
          c.drawRect(rect, D.fill(const Color(0xFF2A2F48)));
        } else if (t == 4) {
          c.drawRect(rect, D.fill(_hasKey ? Color.lerp(const Color(0xFF3CFF7A), Pal.white, M.wave(_t, 2) * .4)! : const Color(0xFFFF4040)));
        } else {
          c.drawRect(rect, D.fill(t == 3 ? const Color(0xFF3A4A9A) : (t == 2 ? const Color(0xFF4A6A48) : const Color(0xFF8A4A38))));
        }
      }
    }
    Offset m(double x, double y) => Offset(mm.left + x * cs, mm.top + y * cs);
    if (!_hasKey) {
      c.drawCircle(m(_keyPos.dx, _keyPos.dy), 3.5 + M.wave(_t, 2) * 2, D.fill(Pal.yellow));
    }
    c.drawCircle(m(_gx, _gy), 4 + M.wave(_t, 3) * 1.5, D.fill(const Color(0xFFFF2040)));
    c.drawCircle(m(_gx, _gy), 2, D.fill(Pal.white));
    // player with view cone
    final pp = m(_px, _py);
    final cone = Path()
      ..moveTo(pp.dx, pp.dy)
      ..lineTo(pp.dx + cos(_ang - .55) * 22, pp.dy + sin(_ang - .55) * 22)
      ..lineTo(pp.dx + cos(_ang + .55) * 22, pp.dy + sin(_ang + .55) * 22)
      ..close();
    c.drawPath(cone, D.fill(const Color(0x44FFE066)));
    final tri = Path()
      ..moveTo(pp.dx + cos(_ang) * 6, pp.dy + sin(_ang) * 6)
      ..lineTo(pp.dx + cos(_ang + 2.4) * 5, pp.dy + sin(_ang + 2.4) * 5)
      ..lineTo(pp.dx + cos(_ang - 2.4) * 5, pp.dy + sin(_ang - 2.4) * 5)
      ..close();
    c.drawPath(tri, D.fill(Pal.orange));
    c.drawPath(tri, D.stroke(Pal.white, 1));

    // --- face portrait
    const fr = Rect.fromLTWH(144, 480, 72, 84);
    D.rrect(c, fr, 4, const Color(0xFF050A1C), border: const Color(0xFF6D8BE8), borderWidth: 2);
    final sprite = _hasKey && dread < .35 && _keyFlash > .05
        ? _faceHappy
        : (dread > .35 || _caught ? _faceScared : _faceNormal);
    final look = dread > .6 ? sin(_t * 30) * 2 : (_stick.dx * 3);
    sprite.drawCentered(c, fr.center + Offset(look, 2), scale: 5.2);
    // --- right panel: key slot + HE meter
    const ks = Rect.fromLTWH(232, 482, 56, 50);
    D.rrect(c, ks, 6, const Color(0xFF050A1C), border: _hasKey ? Pal.gold : const Color(0xFF6D8BE8), borderWidth: 2);
    if (_hasKey) {
      final kp = ks.center;
      c.drawCircle(kp + const Offset(-10, 0), 7, D.stroke(Pal.gold, 4));
      c.drawRect(Rect.fromLTWH(kp.dx - 3, kp.dy - 2, 20, 4), D.fill(Pal.gold));
      c.drawRect(Rect.fromLTWH(kp.dx + 11, kp.dy + 2, 3, 6), D.fill(Pal.gold));
    } else {
      D.text(c, '?', ks.center, size: 26, color: const Color(0x556D8BE8));
    }
    // dread meter (ghost icon + bar)
    const dm = Rect.fromLTWH(300, 482, 48, 118);
    D.rrect(c, dm, 6, const Color(0xFF050A1C), border: const Color(0xFF6D8BE8), borderWidth: 2);
    final fill = dread.clamp(0.0, 1.0);
    D.rrect(c, Rect.fromLTWH(dm.left + 12, dm.bottom - 8 - 76 * fill, 24, 76 * fill + .1), 4,
        Color.lerp(const Color(0xFF3CFF7A), const Color(0xFFFF2040), fill)!);
    // tiny ghost head
    final gh = Offset(dm.center.dx, dm.top + 16);
    c.drawCircle(gh, 10, D.fill(const Color(0xFFE8FFFC)));
    c.drawRect(Rect.fromLTWH(gh.dx - 10, gh.dy, 20, 8), D.fill(const Color(0xFFE8FFFC)));
    c.drawCircle(gh + const Offset(-4, -1), 2.2, D.fill(Pal.ink));
    c.drawCircle(gh + const Offset(4, -1), 2.2, D.fill(Pal.ink));
    // timer-ish objective text
    D.text(c, _hasKey ? host.tr('exit', 'EXIT') : host.tr('key', 'KEY'), const Offset(260, 560), size: 16,
        color: _hasKey ? const Color(0xFF3CFF7A) : Pal.yellow, stroke: Pal.ink, strokeWidth: 3);
    final target = _hasKey ? _exitCell : _keyPos;
    final dist = (target - Offset(_px, _py)).distance;
    D.text(c, '${dist.toStringAsFixed(1)}m', const Offset(260, 580), size: 13, color: const Color(0xFFB8C8FF));
  }

  void _renderOverlay(Canvas c) {
    if (host.finished) return;
    // objective compass at top of the view
    final target = _hasKey ? _exitCell : _keyPos;
    var rel = atan2(target.dy - _py, target.dx - _px) - _ang;
    while (rel > pi) {
      rel -= 2 * pi;
    }
    while (rel < -pi) {
      rel += 2 * pi;
    }
    const cc = Offset(180, 80);
    D.circle(c, cc, 20, const Color(0x88000000), border: _hasKey ? const Color(0xFF3CFF7A) : Pal.yellow, borderWidth: 2);
    final dir = Offset(sin(rel), -cos(rel));
    D.arrow(c, cc, dir, 30, _hasKey ? const Color(0xFF3CFF7A) : Pal.yellow, width: 7);
    // joystick
    final a = _anchor;
    if (a != null && host.pointerDown) {
      c.drawCircle(a, 60, D.stroke(const Color(0x66FFFFFF), 3));
      c.drawCircle(a, 60, D.fill(const Color(0x14FFFFFF)));
      D.circle(c, a + _stick * 60, 20, const Color(0x88FFFFFF), border: const Color(0xAA000000), borderWidth: 2);
    } else if (host.time < 3) {
      // drag hint: up = walk, sideways = turn
      const o = Offset(180, 380);
      c.drawCircle(o, 50, D.stroke(const Color(0x66FFFFFF), 3));
      final k = (_t * .8) % 1;
      final hp = k < .5 ? o + Offset(0, -40 * M.easeOut(k * 2)) : o + Offset(sin((k - .5) * 4 * pi) * 40, -30);
      D.hand(c, hp, 0);
      D.arrow(c, o + const Offset(0, -70), const Offset(0, -1), 28, const Color(0xCCFFFFFF), width: 7);
      D.text(c, host.tr('drag', 'DRAG'), o + const Offset(0, 70), size: 18, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
    }
  }
}

class _Spr {
  _Spr(this.kind, this.sx, this.depth);
  final int kind; // 0 candle, 1 key, 2 exit sign, 3 ghost
  final double sx;
  final double depth;
}
