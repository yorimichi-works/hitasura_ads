import '../engine/engine.dart';

/// No.082 Invader Panic — pixel invaders that crawled out of an ad banner.
///
/// Drag to move the cannon (it auto-fires). Pop-up windows, coin bugs and
/// cookie octopi march in formation and speed up as they thin out. Shields
/// erode pixel by pixel. Shoot the AD saucer for a spread-shot power-up.
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

const _k = Color(0xFF000000);
const _white = Color(0xFFF8F8F8);
const _green = Color(0xFF38F858);
const _cyan = Color(0xFF3CE8FC);
const _magenta = Color(0xFFF83CE8);
const _yellow = Color(0xFFF8D838);
const _red = Color(0xFFF83838);

// Pop-up window alien (30 pts)
final _popPal = <String, Color>{'T': const Color(0xFF3C7CFC), 'x': _red, 'W': _white, 'K': _k};
const _popTop = [
  'TTTTTTTTxTx',
  'TTTTTTTTTxT',
  'TTTTTTTTxTx',
  'WWWWWWWWWWW',
  'WWKKWWWKKWW',
  'WWKKWWWKKWW',
  'WWWWKKKWWWW',
];
final _popA = Sprite([..._popTop, '.W.W...W.W.', 'W...W.W...W'], _popPal);
final _popB = Sprite([..._popTop, '..W.W.W.W..', '.W..W.W..W.'], _popPal);

// Coin bug (20 pts)
final _bugPal = <String, Color>{'Y': _yellow, 'D': const Color(0xFFB87800), 'K': _k, 'A': _cyan};
const _bugTop = [
  'A.........A',
  '.A..YYY..A.',
  '..YYYYYYY..',
  '.YYKYYYKYY.',
  'YYYYYYYYYYY',
  'YYDYYYYYDYY',
  '.YYDDDDDYY.',
];
final _bugA = Sprite([..._bugTop, 'Y.Y.....Y.Y'], _bugPal);
final _bugB = Sprite([..._bugTop, '.Y.Y...Y.Y.'], _bugPal);

// Cookie octopus (10 pts)
final _cookPal = <String, Color>{'C': const Color(0xFFD89048), 'd': const Color(0xFF583010), 'K': _k, 'P': _magenta};
const _cookTop = [
  '....CCCC....',
  '..CCCCCCCC..',
  '.CCdCCCCdCC.',
  'CCCKKCCKKCCC',
  'CCCCCdCCCCCC',
  '.CCPCCCCdCC.',
];
final _cookA = Sprite([..._cookTop, '..C.C..C.C..', '.C.C....C.C.'], _cookPal);
final _cookB = Sprite([..._cookTop, '.C..C..C..C.', 'C..C....C..C'], _cookPal);

final _splat = Sprite([
  'W...W.W...W',
  '.W..W.W..W.',
  '..W.....W..',
  'WW...W...WW',
  '..W.....W..',
  '.W..W.W..W.',
  'W...W.W...W',
], {'W': _white});

final _ufo = Sprite([
  '......RRRRRRRR......',
  '....RRRRRRRRRRRR....',
  '..RRRRRWWRRWWWRRRR..',
  '.RRRRRWRRWRWRRWRRRR.',
  'RRRRRRWWWWRWRRWRRRRR',
  '.RRRRRWRRWRWRRWRRRR.',
  '..RRRRWRRWRWWWRRRR..',
  '....YY..YY..YY..YY..',
], {'R': _red, 'W': _white, 'Y': _yellow});

final _ship = Sprite([
  '......W......',
  '.....WWW.....',
  '.....WCW.....',
  '..G.GGGGG.G..',
  '.GGGGGGGGGGG.',
  'GGGGGGGGGGGGG',
  'GGKGGGKGGGKGG',
  'GGGGGGGGGGGGG',
], {'W': _white, 'C': _cyan, 'G': _green, 'K': const Color(0xFF106820)});

final _shipBoom = [
  Sprite([
    '...W...W.W...',
    '.W..G.W...W..',
    '....GG..G....',
    '.G.GGGGG..G..',
    '..GGGGGGGG...',
    'GGGG.GGGGGG.G',
    '.GGGGGGGGGGG.',
    'G.GGG.GGGG.GG',
  ], {'W': _white, 'G': _green}),
  Sprite([
    'W....G....W..',
    '..W.....W...G',
    '.G..G.W..G...',
    '...G.GGG.G.G.',
    'G..GGG.GG..G.',
    '.GG.GGGG.GGG.',
    'GGGGGGGGGGGGG',
    '.GGG.GGG.GGG.',
  ], {'W': _white, 'G': _green}),
];

final _zig = [
  Sprite(['W.', '.W', 'W.', '.W', 'W.', '.W', 'W.'], {'W': _white}),
  Sprite(['.W', 'W.', '.W', 'W.', '.W', 'W.', '.W'], {'W': _white}),
];

class _Alien {
  _Alien(this.col, this.row, this.type);
  final int col, row, type; // type 0 popup, 1 bug, 2 cookie
  bool alive = true;
  double hit = 0;
}

class _Shot {
  _Shot(this.x, this.y, this.vx, this.vy);
  double x, y, vx, vy;
  bool dead = false;
}

class _Boom {
  _Boom(this.x, this.y, this.col);
  final double x, y;
  final Color col;
  double t = 0;
}

class _Pop {
  _Pop(this.s, this.x, this.y, this.col);
  final String s;
  final double x;
  double y;
  final Color col;
  double t = 0;
}

class _Bunker {
  _Bunker(this.x, this.y) {
    for (var r = 0; r < h; r++) {
      final row = List<bool>.filled(w, false);
      for (var c = 0; c < w; c++) {
        var on = true;
        if (r < 4 && (c < 4 - r || c >= w - 4 + r)) on = false; // rounded top
        if (r >= 9) {
          final d = (c - (w - 1) / 2).abs();
          if (d < 5 - (r - 9) * .3 && r >= 9) on = false; // arch
        }
        row[c] = on;
      }
      cells.add(row);
    }
  }
  static const w = 22, h = 14;
  static const cs = 3.0;
  final double x, y;
  final cells = <List<bool>>[];
  Path? _path;

  Rect get rect => Rect.fromLTWH(x, y, w * cs, h * cs);

  bool hitAt(double px, double py, Random rng, {bool fromAbove = true}) {
    final c = ((px - x) / cs).floor();
    final r = ((py - y) / cs).floor();
    if (c < -1 || c > w || r < -2 || r > h + 1) return false;
    // scan along the travel direction for a solid cell
    for (var i = 0; i < 3; i++) {
      final rr = r + (fromAbove ? i : -i);
      for (final cc in [c, c - 1, c + 1]) {
        if (rr >= 0 && rr < h && cc >= 0 && cc < w && cells[rr][cc]) {
          _erode(cc, rr, rng);
          return true;
        }
      }
    }
    return false;
  }

  void _erode(int c, int r, Random rng) {
    for (var dy = -3; dy <= 3; dy++) {
      for (var dx = -3; dx <= 3; dx++) {
        final rr = r + dy, cc = c + dx;
        if (rr < 0 || rr >= h || cc < 0 || cc >= w) continue;
        final d = dx * dx + dy * dy;
        if (d <= 2 || (d <= 9 && rng.nextDouble() < .45)) cells[rr][cc] = false;
      }
    }
    _path = null;
  }

  Path get path {
    if (_path != null) return _path!;
    final p = Path();
    for (var r = 0; r < h; r++) {
      var c = 0;
      while (c < w) {
        if (!cells[r][c]) {
          c++;
          continue;
        }
        var run = 1;
        while (c + run < w && cells[r][c + run]) {
          run++;
        }
        p.addRect(Rect.fromLTWH(x + c * cs, y + r * cs, run * cs, cs));
        c += run;
      }
    }
    return _path = p;
  }
}

class G082 extends MiniGame {
  static const _cols = 8, _rowsN = 5;
  static const double _sx = 38, _sy = 32, _aw = 33, _ah = 27;
  static const double _shipY = 566;
  final _aliens = <_Alien>[];
  final _shots = <_Shot>[];
  final _bombs = <_Shot>[];
  final _booms = <_Boom>[];
  final _pops = <_Pop>[];
  final _bunkers = <_Bunker>[];
  final _stars = <(Offset, double)>[];
  double _t = 0;
  double _gx = 20, _gy = 112; // grid origin
  double _dir = 1;
  bool _dropNext = false;
  double _stepT = 0;
  int _frame = 0;
  int _stepNote = 0;
  double _shipX = 180;
  double _dragFrom = 0, _shipFrom = 180;
  double _fireT = 0;
  double _bombT = 1.2;
  int _lives = 3;
  double _invuln = 0;
  double _dieT = -1;
  double _ufoX = -100;
  double _ufoDir = 1;
  double _ufoT = 4;
  double _spread = 0;
  int _chain = 0;
  double _chainT = 0;
  double _enter = 0;
  bool _cleared = false;

  int get _alive => _aliens.where((a) => a.alive).length;

  @override
  void init() {
    for (var r = 0; r < _rowsN; r++) {
      for (var c = 0; c < _cols; c++) {
        _aliens.add(_Alien(c, r, r == 0 ? 0 : (r < 3 ? 1 : 2)));
      }
    }
    for (var i = 0; i < 4; i++) {
      _bunkers.add(_Bunker(24 + i * 84.0, 468));
    }
    for (var i = 0; i < 70; i++) {
      _stars.add((Offset((randInt(120) * 3).toDouble(), 40 + (randInt(186) * 3).toDouble()), rand(0, 6)));
    }
    _ufoDir = chance(.5) ? 1 : -1;
  }

  Offset _alienPos(_Alien a) {
    final drop = (1 - M.easeOutBack(M.clamp01(_enter * 1.6 - a.row * .12))) * -300;
    return Offset(_gx + a.col * _sx, _gy + a.row * _sy + drop);
  }

  Sprite _alienSprite(_Alien a) => switch (a.type) {
        0 => _frame.isEven ? _popA : _popB,
        1 => _frame.isEven ? _bugA : _bugB,
        _ => _frame.isEven ? _cookA : _cookB,
      };

  @override
  void update(double dt) {
    _t += dt;
    _enter += dt;
    _invuln = max(0, _invuln - dt);
    _spread = max(0, _spread - dt);
    _chainT -= dt;
    if (_chainT <= 0) _chain = 0;
    for (final a in _aliens) {
      a.hit = max(0, a.hit - dt);
    }
    for (var i = _booms.length - 1; i >= 0; i--) {
      _booms[i].t += dt;
      if (_booms[i].t > .3) _booms.removeAt(i);
    }
    for (var i = _pops.length - 1; i >= 0; i--) {
      final p = _pops[i];
      p.t += dt;
      p.y -= 40 * dt;
      if (p.t > .8) _pops.removeAt(i);
    }
    final playing = !host.finished && _dieT < 0 && _enter > 1.0;

    // --- formation march
    final alive = _alive;
    if (_enter > .9 && !_cleared && alive > 0) {
      _stepT -= dt;
      if (_stepT <= 0) {
        _stepT = (.045 + .42 * alive / 40) / host.speed;
        _frame++;
        _stepNote = (_stepNote + 1) % 4;
        host.sfx(Sfx.tick, volume: .35, rate: const [.62, .56, .5, .45][_stepNote]);
        if (_dropNext) {
          _gy += 15;
          _dir = -_dir;
          _dropNext = false;
        } else {
          _gx += _dir * 6;
          var minX = 999.0, maxX = -999.0;
          for (final a in _aliens) {
            if (!a.alive) continue;
            final x = _gx + a.col * _sx;
            minX = min(minX, x);
            maxX = max(maxX, x + _aw);
          }
          if ((_dir > 0 && maxX + 6 > 354) || (_dir < 0 && minX - 6 < 6)) _dropNext = true;
        }
      }
    }

    // --- ship & firing
    if (playing) {
      _fireT -= dt;
      if (_fireT <= 0) {
        _fireT = .17;
        _shots.add(_Shot(_shipX, _shipY - 10, 0, -820));
        if (_spread > 0) {
          _shots.add(_Shot(_shipX - 6, _shipY - 8, -200, -780));
          _shots.add(_Shot(_shipX + 6, _shipY - 8, 200, -780));
        }
        host.sfx(Sfx.pShoot, volume: .35, rate: 1 + rand(-.05, .05));
      }
    }
    for (final s in _shots) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      if (s.y < 40) s.dead = true;
      if (s.dead) continue;
      // bunkers
      for (final b in _bunkers) {
        if (b.rect.inflate(3).contains(Offset(s.x, s.y)) && b.hitAt(s.x, s.y, host.rng, fromAbove: false)) {
          s.dead = true;
          break;
        }
      }
      if (s.dead) continue;
      // aliens
      for (final a in _aliens) {
        if (!a.alive) continue;
        final p = _alienPos(a);
        if (Rect.fromLTWH(p.dx, p.dy, _aw, _ah).contains(Offset(s.x, s.y))) {
          s.dead = true;
          _killAlien(a, p);
          break;
        }
      }
      if (s.dead) continue;
      // ufo
      if (_ufoX > -80 && _ufoX < 440 && Rect.fromLTWH(_ufoX - 30, 70, 60, 24).contains(Offset(s.x, s.y))) {
        s.dead = true;
        _killUfo();
      }
      // enemy bombs can be shot down
      for (final bm in _bombs) {
        if (!bm.dead && (bm.x - s.x).abs() < 6 && (bm.y - s.y).abs() < 12) {
          bm.dead = true;
          s.dead = true;
          _booms.add(_Boom(bm.x, bm.y, _white));
          host.addScore(5);
          host.sfx(Sfx.pHit, volume: .4, rate: 1.6);
          break;
        }
      }
    }
    _shots.removeWhere((s) => s.dead);

    // --- enemy bombs
    if (playing && alive > 0) {
      _bombT -= dt;
      if (_bombT <= 0) {
        _bombT = rand(.45, .9) / host.speed * (alive < 10 ? 1.3 : 1);
        // bottom-most alien of a column, prefer the player's column
        final byCol = <int, _Alien>{};
        for (final a in _aliens) {
          if (!a.alive) continue;
          final cur = byCol[a.col];
          if (cur == null || a.row > cur.row) byCol[a.col] = a;
        }
        if (byCol.isNotEmpty) {
          var shooter = pick(byCol.values.toList());
          if (chance(.45)) {
            var best = 9999.0;
            for (final a in byCol.values) {
              final d = (_alienPos(a).dx + _aw / 2 - _shipX).abs();
              if (d < best) {
                best = d;
                shooter = a;
              }
            }
          }
          final p = _alienPos(shooter);
          _bombs.add(_Shot(p.dx + _aw / 2, p.dy + _ah, 0, rand(210, 260) * host.speed));
        }
      }
    }
    for (final b in _bombs) {
      b.y += b.vy * dt;
      if (b.y > 604) {
        b.dead = true;
        _booms.add(_Boom(b.x, 600, _green));
      }
      if (b.dead) continue;
      for (final bk in _bunkers) {
        if (bk.rect.inflate(3).contains(Offset(b.x, b.y + 10)) && bk.hitAt(b.x, b.y + 10, host.rng)) {
          b.dead = true;
          break;
        }
      }
      if (b.dead) continue;
      if (_dieT < 0 && _invuln <= 0 && !host.finished && (b.x - _shipX).abs() < 18 && (b.y + 10 - (_shipY + 4)).abs() < 12) {
        b.dead = true;
        _hitShip();
      }
    }
    _bombs.removeWhere((b) => b.dead);

    // --- UFO
    if (!host.finished && _enter > 1) {
      if (_ufoX <= -100 || _ufoX >= 460) {
        _ufoT -= dt;
        if (_ufoT <= 0) {
          _ufoT = rand(5, 7);
          _ufoDir = chance(.5) ? 1 : -1;
          _ufoX = _ufoDir > 0 ? -60 : 420;
          host.sfx(Sfx.pPowerup, volume: .4, rate: .6);
        }
      } else {
        _ufoX += _ufoDir * 95 * dt;
        if (_ufoX > 430 || _ufoX < -70) _ufoX = -200;
      }
    }

    // --- ship death sequence
    if (_dieT >= 0) {
      _dieT += dt;
      if (_dieT > 1.0) {
        _dieT = -1;
        if (_lives <= 0) {
          host.lose();
          _dieT = 99;
        } else {
          _invuln = 1.6;
        }
      }
    }

    // --- invasion reached the ground
    if (!host.finished) {
      for (final a in _aliens) {
        if (a.alive && _gy + a.row * _sy + _ah > 540) {
          for (final bk in _bunkers) {
            bk._erode(host.rng.nextInt(_Bunker.w), 5, host.rng);
          }
          _lives = 0;
          _dieT = 0;
          host.sfx(Sfx.pDie);
          host.shake(10);
          host.flash(_red);
          break;
        }
      }
    }
  }

  void _killAlien(_Alien a, Offset p) {
    a.alive = false;
    final pts = const [30, 20, 10][a.type];
    _chain++;
    _chainT = .7;
    final total = pts * (_chain >= 3 ? 2 : 1);
    host.addScore(total);
    _booms.add(_Boom(p.dx + _aw / 2, p.dy + _ah / 2, _white));
    final col = const [Color(0xFF3C7CFC), _yellow, Color(0xFFD89048)][a.type];
    host.fx.burst(Offset(p.dx + _aw / 2, p.dy + _ah / 2), col, count: 8, speed: 160, size: 5, shape: PartShape.square, gravity: 200);
    host.sfx(Sfx.pExplode, volume: .55, rate: 1 + min(_chain, 10) * .06);
    host.shake(2);
    if (_chain >= 3) {
      _pops.add(_Pop('x$_chain', p.dx + _aw / 2, p.dy - 4, _chain >= 6 ? _magenta : _yellow));
    } else {
      _pops.add(_Pop('$total', p.dx + _aw / 2, p.dy - 4, _white));
    }
    if (_alive == 0 && !_cleared) {
      _cleared = true;
      host.sfx(Sfx.pPowerup);
      host.flash(_white, .2);
      host.shake(6);
      host.fx.confetti();
      host.win(stars: _lives >= 3 ? 3 : (_lives == 2 ? 2 : 1));
    }
  }

  void _killUfo() {
    final pts = pick(const [100, 150, 300]);
    host.addScore(pts);
    _pops.add(_Pop('$pts', _ufoX, 60, _red));
    _pops.add(_Pop(host.tr('bonus', 'BONUS'), _ufoX, 100, _yellow));
    host.fx.burst(Offset(_ufoX, 82), _red, count: 24, speed: 260, size: 6, shape: PartShape.square, gravity: 300,
        colors: const [_red, _white, _yellow]);
    host.sfx(Sfx.pExplode);
    host.sfx(Sfx.pPowerup, volume: .7, rate: 1.3);
    host.shake(6);
    host.hitStop(.06);
    _spread = 4.5;
    _ufoX = -200;
  }

  void _hitShip() {
    _lives--;
    _dieT = 0;
    host.sfx(Sfx.pDie);
    host.shake(9);
    host.flash(_red, .15);
    host.hitStop(.08);
    for (final b in _bombs) {
      b.dead = true;
    }
  }

  // ------------------------------------------------------------ input ---

  @override
  void onDown(Offset p) {
    _dragFrom = p.dx;
    _shipFrom = _shipX;
  }

  @override
  void onMove(Offset p) {
    if (_dieT >= 0) return;
    _shipX = (_shipFrom + (p.dx - _dragFrom) * 1.25).clamp(22.0, 338.0);
  }

  @override
  void onKey(String key, bool down) {
    if (!down || _dieT >= 0) return;
    if (key == 'left') _shipX = max(22, _shipX - 30);
    if (key == 'right') _shipX = min(338, _shipX + 30);
  }

  @override
  void onTimeUp() {
    if (_alive <= 4) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ----------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), Paint()..color = const Color(0xFF05040E));
    // distant nebula bands
    c.drawRect(
        const Rect.fromLTWH(0, 36, 360, 604),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C0624), Color(0xFF05040E), Color(0xFF0A1830)],
          ).createShader(const Rect.fromLTWH(0, 36, 360, 604)));
    final sp = Paint();
    for (final (o, ph) in _stars) {
      final tw = M.wave(_t + ph, .7);
      sp.color = Color.fromRGBO(200, 220, 255, .25 + .6 * tw);
      c.drawRect(Rect.fromLTWH(o.dx, o.dy, 3, 3), sp);
    }
    // big pixel planet
    _renderPlanet(c);
    // the "AD banner" they came from
    final bannerA = M.clamp01(1.4 - _enter);
    if (bannerA > 0) {
      c.drawRect(Rect.fromLTWH(30, 66, 300, 36), Paint()..color = Color.fromRGBO(248, 216, 56, bannerA));
      c.drawRect(Rect.fromLTWH(33, 69, 294, 30), Paint()..color = Color.fromRGBO(0, 0, 0, bannerA));
      _px(c, 'AD', const Offset(180, 76), 3, Color.fromRGBO(248, 216, 56, bannerA), align: 0);
    }

    // UFO
    if (_ufoX > -90 && _ufoX < 450) {
      final f = (_t * 6).floor().isEven;
      _ufo.draw(c, Offset((_ufoX - 30).roundToDouble(), 70), scale: 3);
      if (!f) c.drawRect(Rect.fromLTWH(_ufoX - 30 + 12, 91, 36, 3), Paint()..color = _yellow);
    }

    // aliens
    for (final a in _aliens) {
      if (!a.alive) continue;
      final p = _alienPos(a);
      final s = _alienSprite(a);
      final w = s.w * 3.0;
      s.draw(c, Offset(p.dx + (_aw - w) / 2, p.dy), scale: 3);
    }
    for (final b in _booms) {
      _splat.drawCentered(c, Offset(b.x, b.y), scale: 3, tint: b.col);
    }

    // bunkers
    final bp = Paint()..color = _green;
    for (final b in _bunkers) {
      c.drawPath(b.path, bp);
    }

    // shots
    final shotP = Paint()..color = _spread > 0 ? _yellow : _white;
    for (final s in _shots) {
      c.drawRect(Rect.fromLTWH(s.x - 1.5, s.y - 6, 3, 12), shotP);
    }
    for (final b in _bombs) {
      _zig[((_t * 12).floor() + b.x.toInt()) % 2].draw(c, Offset(b.x - 3, b.y), scale: 3);
    }

    // ship
    if (_dieT >= 0 && _dieT < 5) {
      _shipBoom[(_dieT * 10).floor() % 2].drawCentered(c, Offset(_shipX, _shipY), scale: 3);
    } else if (_dieT < 0 && (_invuln <= 0 || (_t * 12).floor().isEven)) {
      _ship.drawCentered(c, Offset(_shipX, _shipY), scale: 3);
      if (_spread > 0) {
        c.drawRect(Rect.fromLTWH(_shipX - 21, _shipY + 16, 42 * _spread / 4.5, 3), Paint()..color = _yellow);
      }
    }

    // ground + lives
    c.drawRect(const Rect.fromLTWH(0, 600, 360, 3), Paint()..color = _green);
    _px(c, '$_lives', const Offset(14, 612), 2, _white);
    for (var i = 0; i < _lives - 1; i++) {
      _ship.draw(c, Offset(36 + i * 34.0, 612), scale: 2);
    }
    final left = _alive;
    _px(c, '$left', const Offset(346, 612), 2, left <= 5 ? _red : _white, align: 1);
    _cookA.draw(c, Offset(346 - PixelFont.width('$left', 2) - 30, 612), scale: 2);

    for (final p in _pops) {
      _px(c, p.s, Offset(p.x, p.y), 2, p.col, align: 0, shadow: _k);
    }

    // HUD
    _px(c, host.tr('score', 'SCORE'), const Offset(14, 44), 2, _white);
    _px(c, host.score.toString().padLeft(5, '0'), const Offset(14, 62), 2, _green);
    _px(c, 'HI', const Offset(346, 44), 2, _white, align: 1);
    _px(c, max(host.score, 1500).toString().padLeft(5, '0'), const Offset(346, 62), 2, _green, align: 1);
    if (_spread > 0 && (_t * 8).floor().isEven) {
      _px(c, host.tr('power', 'POWER'), const Offset(180, 52), 2, _yellow, align: 0);
    }

    if (_enter < 2.2 && !host.finished) {
      D.hand(c, Offset(180 + sin(_t * 3) * 60, 590), _t);
      _px(c, '< ${host.tr('drag', 'DRAG')} >', const Offset(180, 520), 3, _white, align: 0, shadow: _k);
    }

    Retro.scanlines(c, alpha: .2);
    Retro.vignette(c, strength: .55);
  }

  void _renderPlanet(Canvas c) {
    const cx = 300.0, cy = 700.0, r = 180.0;
    final p1 = Paint()..color = const Color(0xFF1C1848);
    final p2 = Paint()..color = const Color(0xFF282068);
    final p3 = Paint()..color = const Color(0xFF3C2C8C);
    for (var y = cy - r; y < 640; y += 6) {
      final dy = y - cy;
      final half = sqrt(max(0, r * r - dy * dy));
      final x0 = ((cx - half) / 6).round() * 6.0;
      final x1 = ((cx + half) / 6).round() * 6.0;
      c.drawRect(Rect.fromLTRB(x0, y, x1, y + 6), p1);
      c.drawRect(Rect.fromLTRB(x0 + (x1 - x0) * .1, y, x1 - (x1 - x0) * .35, y + 6), p2);
      if (((y - cy) / 6).round() % 5 == 0) c.drawRect(Rect.fromLTRB(x0 + (x1 - x0) * .2, y, x1 - (x1 - x0) * .5, y + 3), p3);
    }
  }
}

