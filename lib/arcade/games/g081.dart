import '../engine/engine.dart';

/// No.081 Super Pixel Bros — auto-running 8-bit platformer.
///
/// Pip the pipe-fixer runs right on his own. Tap to jump (hold for higher),
/// stomp Shroomps, bonk ? blocks for coins, break bricks, clear the pits and
/// grab the flagpole as high as possible.
const double _ts = 48; // one 16px tile at 3x
const double _top = 64; // screen y of tile row 0
const int _rows = 12;
const double _groundY = _top + 10 * _ts; // 544

bool _ascii(String s) {
  for (final u in s.codeUnits) {
    if (u > 126) return false;
  }
  return true;
}

/// PixelFont for ASCII, rounded font fallback for translated words.
void _px(Canvas c, String s, Offset pos, double scale, Color col, {int align = -1, Color? shadow}) {
  if (_ascii(s)) {
    PixelFont.draw(c, s.toUpperCase(), pos, scale, col, align: align, shadow: shadow);
  } else {
    D.text(c, s, Offset(pos.dx, pos.dy + 3.5 * scale), size: 8 * scale, color: col, stroke: shadow,
        strokeWidth: shadow == null ? 0 : scale * 1.4,
        anchor: align < 0 ? Alignment.centerLeft : (align == 0 ? Alignment.center : Alignment.centerRight));
  }
}

// ------------------------------------------------------------------ art ---

const _k = Color(0xFF000000);

final _heroPal = <String, Color>{
  'C': const Color(0xFF00B8B8),
  'W': const Color(0xFFFCFCFC),
  'H': const Color(0xFF503000),
  'S': const Color(0xFFFCBCB0),
  'K': _k,
  'M': const Color(0xFF503000),
  'Y': const Color(0xFFF8B800),
  'O': const Color(0xFF6844FC),
  'N': const Color(0xFF881400),
};

const _heroHead = [
  '....CCCCCC....',
  '...CCCCCCCCC..',
  '..CCCWWCCCCCCC',
  '..HHSSSSSSS...',
  '.HHSSSKSSKS...',
  '.HSSSSKSSKSS..',
  '.HSSSSSSSSSSS.',
  '..SSMMMMMMMS..',
  '...SSMMMMSS...',
];

final _heroStand = Sprite([
  ..._heroHead,
  '..YYYOYYOYYY..',
  '.YYYYOYYOYYYY.',
  '.SSOOWOOWOOSS.',
  '..OOOOOOOOOO..',
  '..OOOO..OOOO..',
  '.NNNN....NNNN.',
  'NNNNN....NNNNN',
], _heroPal);

final _heroRunA = Sprite([
  ..._heroHead,
  '..YYYOYYOYYYSS',
  'SSYYYOYYOYYY..',
  'SSOOOWOOWOO...',
  '..OOOOOOOOOO..',
  '.OOOO...OOOO..',
  'NNNN.....NNNN.',
  'NNN.......NNN.',
], _heroPal);

final _heroRunB = Sprite([
  ..._heroHead,
  '..YYYOYYOYYY..',
  '..YYYOYYOYYY..',
  '..SOOWOOWOOS..',
  '...OOOOOOOO...',
  '....OOOOOO....',
  '....NNNNNN....',
  '...NNNNNNN....',
], _heroPal);

final _heroJump = Sprite([
  ..._heroHead,
  '..YYYOYYOYYYSS',
  '.YYYYOYYOYYYSS',
  'SSOOOWOOWOO...',
  'SS.OOOOOOOOO..',
  '...OOOO..OOONN',
  '..NNNN....NNNN',
  '..NNN.........',
], _heroPal);

final _heroDead = Sprite([
  '....CCCCCC....',
  '...CCCCCCCC...',
  '..CCCCWWCCCC..',
  '..HSSSSSSSSH..',
  '..HSKSSSSKSH..',
  'SS.SSKSSKSS.SS',
  'SS.SKSSSSKS.SS',
  'YY.SMMMMMMS.YY',
  '.YY.SMKKMS.YY.',
  '..YYYOYYOYYY..',
  '...YOYYYYOY...',
  '...OOWOOWOO...',
  '...OOOOOOOO...',
  '...OOOO.OOO...',
  '..NNNN..NNNN..',
  '..NNN....NNN..',
], _heroPal);

final _shPal = <String, Color>{
  'P': const Color(0xFFB53CBC),
  'W': const Color(0xFFFCFCFC),
  'S': const Color(0xFFFCE0A8),
  'K': _k,
  'N': const Color(0xFF503000),
};
const _shTop = [
  '.....PPPPPP.....',
  '...PPWWPPPPPP...',
  '..PPWWWPPPPWWP..',
  '.PPPPWPPPPWWWPP.',
  '.PPPPPPPPPPWPPP.',
  'PPWWPPPPPPPPPPPP',
  'PWWWWPPPPPPPWWPP',
  '.PPPPPPPPPPPPPP.',
  '...SSSSSSSSSS...',
  '..SKKSSSSSSKKS..',
  '..SSWKSSSSKWSS..',
  '..SSSSKKKKSSSS..',
];
final _shA = Sprite([..._shTop, '..NNNSSSSSSNN...', '.NNNN.....NNNN..'], _shPal);
final _shB = Sprite([..._shTop, '...NNSSSSSSNNN..', '..NNNN.....NNNN.'], _shPal);
final _shFlat = Sprite([
  '..PPPPPPPPPPPP..',
  '.PWWPPPPPPPWWPP.',
  'PPPPPPPPPPPPPPPP',
  '..SKKKSSSSKKKS..',
  '..SSSSSSSSSSSS..',
  '.NNNN......NNNN.',
], _shPal);

final _grass = Sprite([
  'LLGLLLLGLLLLLGLL',
  'GGGGGGGGGGGGGGGG',
  'GGgGGGGGGgGGGGGG',
  'gGggGGgGggGGgGgg',
  'DgDDgDDgDDgDDgDD',
  'DDDDDDDDDDDDDDDD',
  'DDdDDDDDDDDDeDDD',
  'DDDDDDDdDDDDDDDD',
  'DeDDDDDDDDDDDDDD',
  'DDDDDDDDDDdDDDDD',
  'DDDDDDDDDDDDDDDD',
  'DDDDDdDDDDDDDDeD',
  'DDDDDDDDDDDDDDDD',
  'DDdDDDDDDeDDDDDD',
  'DDDDDDDDdDDDDDDD',
  'DDDDDDDDDDDDDDDD',
], {
  'L': const Color(0xFFB8F818),
  'G': const Color(0xFF00A800),
  'g': const Color(0xFF005800),
  'D': const Color(0xFFAC7C00),
  'd': const Color(0xFF7C4C00),
  'e': const Color(0xFFE4A860),
});
final _dirt = Sprite([
  'DDDDDDDDDDDDDDDD',
  'DDdDDDDDDDDDeDDD',
  'DDDDDDDdDDDDDDDD',
  'DeDDDDDDDDDDDDDD',
  'DDDDDDDDDDdDDDDD',
  'DDDDDDDDDDDDDDDD',
  'DDDDDdDDDDDDDDeD',
  'DDDDDDDDDDDDDDDD',
  'DDdDDDDDDeDDDDDD',
  'DDDDDDDDdDDDDDDD',
  'DDDDDDDDDDDDDDDD',
  'DeDDDDDDDDDDdDDD',
  'DDDDDDdDDDDDDDDD',
  'DDDDDDDDDDDDeDDD',
  'DDdDDDDDDDDDDDDD',
  'DDDDDDDDDdDDDDDD',
], {
  'D': const Color(0xFF9C6C00),
  'd': const Color(0xFF6C3C00),
  'e': const Color(0xFFD49850),
});

const _qRows = [
  '.KKKKKKKKKKKKKK.',
  'KYYYYYYYYYYYYYYK',
  'KYoYYYYYYYYYYoYK',
  'KYYYYWWWWWYYYYYK',
  'KYYYWWKKKWWYYYYK',
  'KYYYWWKYYWWKYYYK',
  'KYYYYKKYYWWKYYYK',
  'KYYYYYYYWWKKYYYK',
  'KYYYYYYWWKKYYYYK',
  'KYYYYYYWWKYYYYYK',
  'KYYYYYYYKKYYYYYK',
  'KYYYYYYWWYYYYYYK',
  'KYYYYYYWWKYYYYYK',
  'KYoYYYYYKKYYYoYK',
  'KYYYYYYYYYYYYYYK',
  '.KKKKKKKKKKKKKK.',
];
final _qBlocks = [
  for (final y in const [Color(0xFFF8B800), Color(0xFFFCA044), Color(0xFFE45C10), Color(0xFFFCA044)])
    Sprite(_qRows, {'K': _k, 'Y': y, 'o': const Color(0xFF7C3000), 'W': const Color(0xFFFCFCFC)}),
];

List<String> _bevelRows(int n) => [
      for (var y = 0; y < n; y++)
        [
          for (var x = 0; x < n; x++)
            (x == n - 1 || y == n - 1)
                ? 'K'
                : (x == 0 || y == 0)
                    ? 'L'
                    : (x >= n - 3 || y >= n - 3)
                        ? 'D'
                        : ((x == 3 || x == n - 4) && (y == 3 || y == n - 4))
                            ? 'R'
                            : 'M'
        ].join(),
    ];
final _usedBlock = Sprite(_bevelRows(16), {
  'K': _k,
  'L': const Color(0xFFE4A860),
  'M': const Color(0xFF9C5820),
  'D': const Color(0xFF5C2C00),
  'R': const Color(0xFF3C1C00),
});
final _hardBlock = Sprite(_bevelRows(16), {
  'K': _k,
  'L': const Color(0xFFFCD8A8),
  'M': const Color(0xFFC88040),
  'D': const Color(0xFF7C3C0C),
  'R': const Color(0xFFFCD8A8),
});

final _brick = Sprite([
  'LLLLLLLMLLLLLLLM',
  'BBBBBBBMBBBBBBBM',
  'BBBBBBBMBBBBBBBM',
  'MMMMMMMMMMMMMMMM',
  'LLLMLLLLLLLMLLLL',
  'BBBMBBBBBBBMBBBB',
  'BBBMBBBBBBBMBBBB',
  'MMMMMMMMMMMMMMMM',
  'LLLLLLLMLLLLLLLM',
  'BBBBBBBMBBBBBBBM',
  'BBBBBBBMBBBBBBBM',
  'MMMMMMMMMMMMMMMM',
  'LLLMLLLLLLLMLLLL',
  'BBBMBBBBBBBMBBBB',
  'BBBMBBBBBBBMBBBB',
  'MMMMMMMMMMMMMMMM',
], {
  'L': const Color(0xFFFC9838),
  'B': const Color(0xFFC84C0C),
  'M': const Color(0xFF3C1000),
});

const _pipeShade = 'LLWLGGGGGGGGGGGGGGGGgGgGggDgDDDD';
final _pipePal = <String, Color>{
  'K': _k,
  'L': const Color(0xFF80D010),
  'W': const Color(0xFFD8F878),
  'G': const Color(0xFF00A800),
  'g': const Color(0xFF008800),
  'D': const Color(0xFF005800),
};
final _pipeTop = Sprite([
  'K' * 32,
  for (var i = 0; i < 14; i++) 'K${_pipeShade.substring(1, 31)}K',
  'K' * 32,
], _pipePal);
final _pipeBody = Sprite([
  for (var i = 0; i < 16; i++) '..K${_pipeShade.substring(3, 29)}K..',
], _pipePal);

final _coinPal = <String, Color>{
  'K': const Color(0xFF7C3000),
  'Y': const Color(0xFFF8B800),
  'W': const Color(0xFFFCFCFC),
  'O': const Color(0xFFE45C10),
};
final _coins = [
  Sprite([
    '..KKKK..',
    '.KYYYYK.',
    'KYWYYYOK',
    'KYWYOYOK',
    'KYWYOYOK',
    'KYWYOYOK',
    'KYWYOYOK',
    'KYWYOYOK',
    'KYWYOYOK',
    'KYWYOYOK',
    'KYWYYYOK',
    'KYYYYYOK',
    '.KOOOOK.',
    '..KKKK..',
  ], _coinPal),
  Sprite([
    '...KK...',
    '..KYYK..',
    '.KWYYOK.',
    '.KWYOOK.',
    '.KWYOOK.',
    '.KWYOOK.',
    '.KWYOOK.',
    '.KWYOOK.',
    '.KWYOOK.',
    '.KWYOOK.',
    '.KWYOOK.',
    '.KWYYOK.',
    '..KOOK..',
    '...KK...',
  ], _coinPal),
  Sprite([for (var i = 0; i < 14; i++) i == 0 || i == 13 ? '...KK...' : '...KW...'], _coinPal),
];

const _cloudRows = [
  '............KKKK................',
  '..........KKWWWWKK..............',
  '.........KWWWWWWWWK...KKKK......',
  '......KKKWWWWWWWWWWKKKWWWWK.....',
  '.....KWWWWWWWWWWWWWWWWWWWWWK....',
  '....KWWWWWWWWWWWWWWWWWWWWWWWKK..',
  '..KKWWWWWWWWWWWWWWWWWWWWWWWWWWK.',
  '.KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWK',
  'KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWK',
  'KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWBK',
  'KBWWWWWWWWWWWWWWWWWWWWWWWWWWWBBK',
  '.KBBWWWWBBWWWWWWBBWWWWWWBBWBBBK.',
  '..KKBBBBKKBBBBBBKKBBBBBBKKBBKK..',
  '....KKKK..KKKKKK..KKKKKK..KK....',
];
final _cloud = Sprite(_cloudRows, {'K': const Color(0xFF2038EC), 'W': const Color(0xFFFCFCFC), 'B': const Color(0xFFA4E4FC)});
final _bush = Sprite(_cloudRows, {'K': _k, 'W': const Color(0xFF80D010), 'B': const Color(0xFF00A800)});

List<String> _hillRows(int w, int h) {
  final rows = <String>[];
  for (var y = 0; y < h; y++) {
    final half = (w / 2 * sqrt((y + 1.5) / h)).clamp(2, w / 2).round();
    final a = w ~/ 2 - half, b = w ~/ 2 + half - 1;
    final sb = StringBuffer();
    for (var x = 0; x < w; x++) {
      if (x < a || x > b) {
        sb.write('.');
      } else if (x == a || x == b || y == 0) {
        sb.write('K');
      } else if (y > 4 && (x * 7 + y * 13) % 23 == 0) {
        sb.write('g');
      } else {
        sb.write('G');
      }
    }
    rows.add(sb.toString());
  }
  return rows;
}

final _hill = Sprite(_hillRows(48, 22), {'K': _k, 'G': const Color(0xFF00A844), 'g': const Color(0xFF005800)});
final _mount = Sprite(_hillRows(48, 22), {
  'K': const Color(0xFF6C88E8),
  'G': const Color(0xFF8CA8F8),
  'g': const Color(0xFFB4C8FC),
});

List<String> _castleRows() {
  const w = 40, h = 40;
  final rows = <String>[];
  for (var y = 0; y < h; y++) {
    final sb = StringBuffer();
    for (var x = 0; x < w; x++) {
      final inTower = x >= 12 && x < 28 && y < 18;
      final inBody = y >= 16;
      var ch = '.';
      if (inTower) {
        if (y < 4) {
          ch = ((x - 12) ~/ 4).isEven ? 'B' : '.';
        } else {
          ch = 'B';
        }
        if (y >= 7 && y <= 12 && (x == 15 || x == 16 || x == 23 || x == 24)) ch = 'K';
      }
      if (inBody) {
        if (y < 20) {
          ch = (x ~/ 5).isEven ? 'B' : '.';
        } else {
          ch = 'B';
        }
        final dx = x - 19.5, dy = y - 31.0;
        if (x >= 16 && x < 24 && y >= 31) ch = 'K';
        if (dy < 0 && dy > -4 && dx * dx + dy * dy * 1.2 < 16 && y >= 27) ch = 'K';
      }
      if (ch == 'B') {
        final row = y ~/ 4;
        final mortar = y % 4 == 3 || (x + (row.isOdd ? 4 : 0)) % 8 == 7;
        if (mortar) ch = 'M';
      }
      sb.write(ch);
    }
    rows.add(sb.toString());
  }
  return rows;
}

final _castle = Sprite(_castleRows(), {'B': const Color(0xFFC84C0C), 'M': const Color(0xFF3C1000), 'K': _k});

final _flag = Sprite([
  for (var y = 0; y < 12; y++)
    [
      for (var x = 0; x < 16; x++)
        () {
          final edge = 15 - ((y - 5.5).abs() * 2.6).round();
          if (x < 15 - edge) return '.';
          final dx = x - 9.5, dy = y - 5.5;
          if (dx * dx + dy * dy < 7) return 'C';
          return 'W';
        }()
    ].join(),
], {'W': const Color(0xFFFCFCFC), 'C': const Color(0xFF00B8B8)});

// ---------------------------------------------------------------- model ---

class _Body {
  _Body(this.x, this.y, this.w, this.h);
  double x, y, w, h;
  double vx = 0, vy = 0;
  Rect get rect => Rect.fromLTWH(x, y, w, h);
}

class _Enemy extends _Body {
  _Enemy(double x, double y) : super(x, y, 36, 36);
  int state = 0; // 0 walk, 1 squashed, 2 flipped
  double t = 0;
  bool active = false;
}

class _BlockCoin {
  _BlockCoin(this.x, this.y);
  double x, y, vy = -620, t = 0;
}

class _Bit {
  _Bit(this.x, this.y, this.vx, this.vy, this.col, this.size);
  double x, y, vx, vy, life = 1.2;
  final Color col;
  final double size;
}

class _Pop {
  _Pop(this.s, this.x, this.y, this.col);
  final String s;
  final double x;
  double y;
  final Color col;
  double t = 0;
}

class G081 extends MiniGame {
  static const _cols = 54;
  static const _flagCol = 49;
  late List<List<int>> _g; // 0 empty,1 grass,2 dirt,3 ?,4 used,5 brick,6 pipe top,7 pipe body,8 hard
  final _bump = <int, double>{};
  final _hero = _Body(2 * _ts, _groundY - 45, 30, 45);
  final _enemies = <_Enemy>[];
  final _floatCoins = <Offset>[];
  final _blockCoins = <_BlockCoin>[];
  final _bits = <_Bit>[];
  final _pops = <_Pop>[];
  double _t = 0;
  double _cam = 0;
  bool _grounded = true;
  double _coyote = 0;
  double _jumpBuf = 0;
  bool _holding = false;
  double _jumpHold = 0;
  double _runDist = 0;
  int _chain = 0;
  int _coinsGot = 0;
  bool _dead = false;
  double _deadT = 0;
  bool _onFlag = false;
  double _flagT = 0;
  double _flagY = 0; // flag offset slide
  double _walkIn = 0;

  // flag pole geometry (world)
  static const double _poleX = _flagCol * _ts + 22;
  static const double _poleTop = _top + 1 * _ts;
  static const double _poleBottom = _top + 9 * _ts;

  @override
  void init() {
    _g = List.generate(_rows, (_) => List<int>.filled(_cols, 0));
    void ground(int a, int b) {
      for (var c = a; c <= b; c++) {
        _g[10][c] = 1;
        _g[11][c] = 2;
      }
    }

    void pipe(int c, int h) {
      for (var i = 0; i < h; i++) {
        final r = 9 - i;
        final code = i == h - 1 ? 6 : 7;
        _g[r][c] = code;
        _g[r][c + 1] = code;
      }
    }

    void stair(int c, int h) {
      for (var i = 0; i < h; i++) {
        _g[9 - i][c] = 8;
      }
    }

    void enemy(int c) => _enemies.add(_Enemy(c * _ts + 6, _groundY - 36));
    void coin(double c, int r) => _floatCoins.add(Offset(c * _ts + _ts / 2, _top + r * _ts + _ts / 2));

    ground(0, 15);
    ground(18, 29);
    ground(32, _cols - 1);
    _g[6][5] = 3;
    _g[6][8] = 5;
    _g[6][9] = 3;
    _g[6][10] = 5;
    _g[6][11] = 3;
    _g[6][12] = 5;
    enemy(12);
    pipe(14, 2);
    coin(16, 6);
    coin(17, 6);
    coin(16.5, 5);
    _g[6][21] = 3;
    _g[6][22] = 5;
    enemy(22);
    enemy(24);
    pipe(26, 3);
    coin(28, 4);
    coin(29, 4);
    coin(30, 5);
    coin(31, 5);
    for (var c = 34; c <= 37; c++) {
      _g[6][c] = (c == 35 || c == 36) ? 3 : 5;
    }
    enemy(36);
    enemy(39);
    stair(42, 1);
    stair(43, 2);
    stair(44, 3);
    stair(45, 4);
    coin(44, 4);
    coin(45, 3);
    coin(46, 3);
    _g[9][_flagCol] = 8;
  }

  // ---------------------------------------------------------- physics ---

  bool _solid(int c, int r) {
    if (c < 0) return true;
    if (c >= _cols || r < 0 || r >= _rows) return false;
    return _g[r][c] != 0;
  }

  bool _moveX(_Body b, double dx) {
    b.x += dx;
    final r0 = ((b.y - _top) / _ts).floor(), r1 = ((b.y + b.h - 1 - _top) / _ts).floor();
    if (dx > 0) {
      final c = ((b.x + b.w) / _ts).floor();
      for (var r = r0; r <= r1; r++) {
        if (_solid(c, r)) {
          b.x = c * _ts - b.w - .01;
          return true;
        }
      }
    } else if (dx < 0) {
      final c = (b.x / _ts).floor();
      for (var r = r0; r <= r1; r++) {
        if (_solid(c, r)) {
          b.x = (c + 1) * _ts;
          return true;
        }
      }
    }
    return false;
  }

  /// Returns (landed, headCol, headRow).
  (bool, int, int) _moveY(_Body b, double dy) {
    b.y += dy;
    final c0 = (b.x / _ts).floor(), c1 = ((b.x + b.w - 1) / _ts).floor();
    if (dy > 0) {
      final r = ((b.y + b.h - _top) / _ts).floor();
      for (var c = c0; c <= c1; c++) {
        if (_solid(c, r)) {
          b.y = _top + r * _ts - b.h;
          b.vy = 0;
          return (true, -1, -1);
        }
      }
    } else if (dy < 0) {
      final r = ((b.y - _top) / _ts).floor();
      final mid = ((b.x + b.w / 2) / _ts).floor();
      var hit = -1;
      if (_solid(mid, r)) {
        hit = mid;
      } else {
        for (var c = c0; c <= c1; c++) {
          if (_solid(c, r)) hit = c;
        }
      }
      if (hit >= 0) {
        b.y = _top + (r + 1) * _ts;
        b.vy = 40;
        return (false, hit, r);
      }
    }
    return (false, -1, -1);
  }

  void _headBump(int c, int r) {
    final code = _g[r][c];
    final key = r * 1000 + c;
    final cx = c * _ts + _ts / 2, cy = _top + r * _ts;
    if (code == 3) {
      _g[r][c] = 4;
      _bump[key] = 0;
      _blockCoins.add(_BlockCoin(cx, cy - 10));
      _coinsGot++;
      host.addScore(200);
      host.sfx(Sfx.pCoin, rate: 1 + _coinsGot * .03);
      _pops.add(_Pop('200', cx, cy - 60, const Color(0xFFFCFCFC)));
    } else if (code == 5) {
      _g[r][c] = 0;
      host.addScore(50);
      host.sfx(Sfx.pExplode, volume: .7, rate: 1.3);
      host.shake(3);
      for (var i = 0; i < 4; i++) {
        final sx = i.isEven ? -1.0 : 1.0;
        final sy = i < 2 ? -1.0 : .2;
        _bits.add(_Bit(cx + sx * 10, cy + 20 + sy * 10, sx * rand(90, 160), -380 + sy * 180 - rand(0, 80),
            const Color(0xFFC84C0C), 15));
      }
    } else {
      _bump[key] = 0;
      host.sfx(Sfx.pHit, volume: .5, rate: .7);
    }
    // knock enemies standing on the block
    for (final e in _enemies) {
      if (e.state == 0 && (e.x + e.w / 2 - cx).abs() < _ts * .8 && (e.y + e.h - cy).abs() < 6) {
        e.state = 2;
        e.vy = -420;
        e.vx = e.vx.sign * 60;
        host.addScore(100);
        _pops.add(_Pop('100', e.x + 18, e.y - 10, const Color(0xFFFCFCFC)));
      }
    }
  }

  void _die() {
    if (_dead || _onFlag) return;
    _dead = true;
    _deadT = 0;
    _hero.vy = 0;
    host.sfx(Sfx.pDie);
    host.setMusicVolume(0);
    host.shake(6);
    host.flash(const Color(0xFFFC3C3C), .12);
    host.lose();
  }

  void _grabFlag() {
    _onFlag = true;
    _flagT = 0;
    _hero.x = _poleX - _hero.w + 4;
    final ratio = ((_poleBottom - (_hero.y + _hero.h)) / (_poleBottom - _poleTop)).clamp(0.0, 1.0);
    final pts = ratio > .8
        ? 5000
        : ratio > .55
            ? 2000
            : ratio > .3
                ? 800
                : ratio > .12
                    ? 400
                    : 100;
    host.addScore(pts);
    _pops.add(_Pop('$pts', _poleX + 30, _hero.y, pts >= 2000 ? const Color(0xFFF8B800) : const Color(0xFFFCFCFC)));
    var stars = ratio > .55 ? 3 : (ratio > .2 ? 2 : 1);
    if (_coinsGot >= 8 && stars < 3) stars++;
    host.sfx(Sfx.pPowerup);
    host.sfx(Sfx.fanfare, volume: .8);
    host.punch(.05);
    host.win(stars: stars);
  }

  @override
  void update(double dt) {
    _t += dt;
    for (final k in _bump.keys.toList()) {
      final v = _bump[k]! + dt;
      if (v > .25) {
        _bump.remove(k);
      } else {
        _bump[k] = v;
      }
    }
    for (var i = _blockCoins.length - 1; i >= 0; i--) {
      final bc = _blockCoins[i];
      bc.t += dt;
      bc.vy += 1800 * dt;
      bc.y += bc.vy * dt;
      if (bc.t > .6) _blockCoins.removeAt(i);
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.vy += 1500 * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.life <= 0 || b.y > 700) _bits.removeAt(i);
    }
    for (var i = _pops.length - 1; i >= 0; i--) {
      final p = _pops[i];
      p.t += dt;
      p.y -= 50 * dt;
      if (p.t > .9) _pops.removeAt(i);
    }

    _updateEnemies(dt);

    if (_dead) {
      _deadT += dt;
      if (_deadT > .45) {
        if (_hero.vy == 0 && _deadT < .5) _hero.vy = -780;
        _hero.vy += 2200 * dt;
        _hero.y += _hero.vy * dt;
      }
    } else if (_onFlag) {
      _flagT += dt;
      final bottom = _poleBottom - _hero.h;
      if (_hero.y < bottom) {
        _hero.y = min(bottom, _hero.y + 330 * dt);
      }
      _flagY = min(_poleBottom - _poleTop - 60, _flagY + 330 * dt);
      if (_flagT > .9) {
        _walkIn += dt;
        _hero.x += 150 * dt;
        _runDist += 150 * dt;
        if (_hero.y < _groundY - _hero.h) _hero.y = min(_groundY - _hero.h, _hero.y + 400 * dt);
        if ((_t * 6).floor() % 3 == 0 && _walkIn < 1.2 && chance(.3)) {
          final fx = _cam + rand(60, 300);
          host.fx.burst(Offset(fx, rand(100, 260)), Pal.yellow,
              count: 14, speed: 200, size: 5, shape: PartShape.square, gravity: 120,
              colors: const [Color(0xFFFCFCFC), Color(0xFFF8B800), Color(0xFF00B8B8), Color(0xFFFC3C3C)]);
          host.sfx(Sfx.pExplode, volume: .4, rate: 1.4);
        }
      }
    } else if (!host.finished) {
      _updateHero(dt);
    }

    final maxCam = _cols * _ts - 360;
    final target = (_hero.x - 110).clamp(0.0, maxCam);
    if (!_dead) _cam = target;
  }

  void _updateHero(double dt) {
    final h = _hero;
    _jumpBuf = max(0, _jumpBuf - dt);
    _coyote = max(0, _coyote - dt);
    final run = 190 * (.9 + .1 * host.speed);
    if (_jumpBuf > 0 && (_grounded || _coyote > 0)) {
      _jumpBuf = 0;
      _coyote = 0;
      _grounded = false;
      h.vy = -760;
      _jumpHold = .28;
      host.sfx(Sfx.pJump);
    }
    var g = 2400.0;
    if (h.vy < 0 && _holding && _jumpHold > 0) {
      g *= .42;
      _jumpHold -= dt;
    }
    if (!_holding) _jumpHold = 0;
    h.vy = min(900, h.vy + g * dt);
    final blocked = _moveX(h, run * dt);
    if (!blocked) _runDist += run * dt;
    final (landed, hc, hr) = _moveY(h, h.vy * dt);
    if (hc >= 0) _headBump(hc, hr);
    if (landed) {
      if (!_grounded) {
        host.sfx(Sfx.step, volume: .35);
      }
      _grounded = true;
      _coyote = .1;
      _chain = 0;
    } else {
      if (_grounded) _coyote = .1;
      _grounded = false;
    }
    // coins
    final hr2 = h.rect;
    for (var i = _floatCoins.length - 1; i >= 0; i--) {
      final c = _floatCoins[i];
      if (hr2.inflate(10).contains(c)) {
        _floatCoins.removeAt(i);
        _coinsGot++;
        host.addScore(100);
        host.sfx(Sfx.pCoin, rate: 1 + _coinsGot * .03);
        for (var k = 0; k < 6; k++) {
          _bits.add(_Bit(c.dx, c.dy, rand(-120, 120), rand(-300, -100), const Color(0xFFF8B800), 6)..life = .4);
        }
      }
    }
    // enemies
    for (final e in _enemies) {
      if (e.state != 0 || !e.active) continue;
      final er = Rect.fromLTWH(e.x + 3, e.y + 4, e.w - 6, e.h - 4);
      if (!hr2.overlaps(er)) continue;
      if (h.vy > 30 && (h.y + h.h) - e.y < 26) {
        e.state = 1;
        e.t = 0;
        _chain++;
        final pts = min(1600, 100 * (1 << (_chain - 1)));
        host.addScore(pts);
        h.vy = _holding ? -680 : -440;
        _jumpHold = _holding ? .15 : 0;
        host.sfx(Sfx.pHit, rate: 1 + _chain * .12);
        host.sfx(Sfx.squish, volume: .5);
        host.hitStop(.04);
        host.shake(3);
        _pops.add(_Pop(_chain > 1 ? '$pts x$_chain' : '$pts', e.x + 18, e.y - 10,
            _chain > 1 ? const Color(0xFFF8B800) : const Color(0xFFFCFCFC)));
        for (var k = 0; k < 6; k++) {
          _bits.add(_Bit(e.x + 18, e.y + 30, rand(-160, 160), rand(-260, -60), const Color(0xFFFCE0A8), 6)..life = .35);
        }
      } else {
        _die();
        return;
      }
    }
    if (h.y > 660) _die();
    if (h.x + h.w >= _poleX - 4) _grabFlag();
  }

  void _updateEnemies(double dt) {
    for (final e in _enemies) {
      if (!e.active) {
        if (e.x < _cam + 400) {
          e.active = true;
          e.vx = -48;
        } else {
          continue;
        }
      }
      e.t += dt;
      if (e.state == 1) continue;
      if (e.state == 2) {
        e.vy += 1800 * dt;
        e.y += e.vy * dt;
        e.x += e.vx * dt;
        continue;
      }
      e.vy = min(900, e.vy + 1800 * dt);
      if (_moveX(e, e.vx * dt)) e.vx = -e.vx;
      _moveY(e, e.vy * dt);
    }
    _enemies.removeWhere((e) => (e.state == 1 && e.t > .5) || e.y > 700 || e.x < _cam - 100);
  }

  // ------------------------------------------------------------ input ---

  @override
  void onDown(Offset p) {
    _holding = true;
    _jumpBuf = .12;
  }

  @override
  void onUp(Offset p) => _holding = false;

  @override
  void onKey(String key, bool down) {
    if (key == 'action' || key == 'up') {
      if (down) {
        onDown(Offset.zero);
      } else {
        onUp(Offset.zero);
      }
    }
  }

  // ----------------------------------------------------------- render ---

  static const _skyBands = [
    Color(0xFF3C5CE8),
    Color(0xFF4C74F8),
    Color(0xFF5C94FC),
    Color(0xFF7CACFC),
    Color(0xFF9CC4FC),
  ];

  @override
  void render(Canvas c) {
    final cam = (_cam / 3).round() * 3.0;
    _renderSky(c);
    // far mountains
    for (var i = -1; i < 6; i++) {
      final wx = i * 220.0 - (cam * .15) % 220;
      _mount.draw(c, Offset(wx - 20, _groundY - 22 * 6 + 6), scale: 6);
    }
    // clouds
    for (var i = -1; i < 5; i++) {
      final wx = i * 170.0 - (cam * .4) % 170;
      _cloud.draw(c, Offset(wx, 120.0 + (i % 3) * 42), scale: 3);
    }
    // near hills
    for (var i = -1; i < 4; i++) {
      final wx = i * 300.0 - (cam * .7) % 300;
      _hill.draw(c, Offset(wx + 40, _groundY - 22 * 3), scale: 3);
    }
    c.save();
    c.translate(-cam, 0);
    // bushes on the ground
    for (final bc in const [3, 11, 20, 24, 33, 38, 47]) {
      if (_g[10][bc] != 0) _bush.draw(c, Offset(bc * _ts, _groundY - 42), scale: 3);
    }
    // castle
    _castle.draw(c, Offset(51 * _ts - 12, _groundY - 120), scale: 3);
    // tiles
    final c0 = max(0, (cam / _ts).floor() - 1), c1 = min(_cols - 1, c0 + 10);
    for (var r = 0; r < _rows; r++) {
      for (var col = c0; col <= c1; col++) {
        final code = _g[r][col];
        if (code == 0) continue;
        final bt = _bump[r * 1000 + col];
        final off = bt == null ? 0.0 : -sin(bt / .25 * pi) * 15;
        final pos = Offset(col * _ts, _top + r * _ts + off);
        switch (code) {
          case 1:
            _grass.draw(c, pos, scale: 3);
          case 2:
            _dirt.draw(c, pos, scale: 3);
          case 3:
            _qBlocks[((_t * 5).floor()) % 4].draw(c, pos, scale: 3);
          case 4:
            _usedBlock.draw(c, pos, scale: 3);
          case 5:
            _brick.draw(c, pos, scale: 3);
          case 6:
            if (col == 0 || _g[r][col - 1] != 6) _pipeTop.draw(c, pos, scale: 3);
          case 7:
            if (col == 0 || _g[r][col - 1] != 7) _pipeBody.draw(c, pos, scale: 3);
          case 8:
            _hardBlock.draw(c, pos, scale: 3);
        }
      }
    }
    // flag pole
    const pole = Rect.fromLTWH(_poleX - 3, _poleTop, 6, _poleBottom - _poleTop);
    c.drawRect(pole, Paint()..color = const Color(0xFF80D010));
    c.drawRect(const Rect.fromLTWH(_poleX - 3, _poleTop, 3, _poleBottom - _poleTop), Paint()..color = const Color(0xFFB8F818));
    c.drawRect(const Rect.fromLTWH(_poleX - 9, _poleTop - 15, 18, 15), Paint()..color = const Color(0xFF005800));
    c.drawRect(const Rect.fromLTWH(_poleX - 6, _poleTop - 12, 6, 6), Paint()..color = const Color(0xFFB8F818));
    _flag.draw(c, Offset(_poleX - 3 - 48, _poleTop + 6 + _flagY), scale: 3);
    // coins
    final cf = ((_t * 8).floor()) % 4;
    final coinSprite = _coins[cf == 3 ? 1 : cf];
    for (final co in _floatCoins) {
      if (co.dx < cam - 40 || co.dx > cam + 400) continue;
      coinSprite.drawCentered(c, co, scale: 3);
    }
    for (final bc in _blockCoins) {
      _coins[((bc.t * 16).floor()) % 3].drawCentered(c, Offset(bc.x, bc.y), scale: 3);
    }
    // enemies
    for (final e in _enemies) {
      if (!e.active) continue;
      final pos = Offset(e.x - 6, e.y + e.h - 42);
      if (e.state == 1) {
        _shFlat.draw(c, Offset(e.x - 6, e.y + e.h - 18), scale: 3);
      } else if (e.state == 2) {
        _shA.draw(c, pos, scale: 3, flipY: true);
      } else {
        ((e.t * 5).floor().isEven ? _shA : _shB).draw(c, pos, scale: 3);
      }
    }
    // hero
    _renderHero(c);
    for (final b in _bits) {
      c.drawRect(Rect.fromCenter(center: Offset(b.x, b.y), width: b.size, height: b.size), Paint()..color = b.col);
      if (b.size > 10) {
        c.drawRect(Rect.fromLTWH(b.x - b.size / 2, b.y - b.size / 2, b.size, 3), Paint()..color = const Color(0xFF3C1000));
      }
    }
    for (final p in _pops) {
      _px(c, p.s, Offset(p.x, p.y), 2, p.col, align: 0, shadow: _k);
    }
    c.restore();

    _renderHud(c);
    if (host.time < 2.2 && !_dead) {
      D.hand(c, const Offset(250, 420), _t);
      _px(c, host.tr('tap', 'TAP'), const Offset(250, 380), 3, const Color(0xFFFCFCFC), align: 0, shadow: _k);
      _px(c, '= ${host.tr('jump', 'JUMP')}', const Offset(250, 408), 2, const Color(0xFFF8B800), align: 0, shadow: _k);
    }
    if (_onFlag && _flagT > .3) {
      final s = 1 + .1 * sin(_t * 12);
      c.save();
      c.translate(180, 250);
      c.scale(s);
      _px(c, host.tr('course_clear', 'COURSE CLEAR!'), Offset.zero, 3, const Color(0xFFF8B800), align: 0, shadow: _k);
      c.restore();
    }
    Retro.scanlines(c, alpha: .08);
  }

  void _renderSky(Canvas c) {
    const y0 = 36.0, y1 = _groundY;
    const bh = (y1 - y0) / 5;
    final paints = [for (final col in _skyBands) Paint()..color = col];
    for (var i = 0; i < 5; i++) {
      c.drawRect(Rect.fromLTWH(0, y0 + i * bh, 360, bh + 1), paints[i]);
    }
    // dithered seams
    for (var i = 1; i < 5; i++) {
      final y = y0 + i * bh;
      for (var row = 0; row < 2; row++) {
        for (var x = 0; x < 120; x++) {
          if ((x + row).isEven) c.drawRect(Rect.fromLTWH(x * 3.0, y - 6 + row * 3, 3, 3), paints[i]);
          if ((x + row).isOdd) c.drawRect(Rect.fromLTWH(x * 3.0, y + row * 3, 3, 3), paints[i - 1]);
        }
      }
    }
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 36), Paint()..color = const Color(0xFF2C3CC8));
  }

  void _renderHero(Canvas c) {
    final h = _hero;
    final pos = Offset(h.x + h.w / 2 - 21, h.y + h.h - 48);
    Sprite s;
    if (_dead) {
      s = _heroDead;
    } else if (_onFlag && _flagT < .9) {
      s = _heroJump;
    } else if (!_grounded && !_onFlag) {
      s = _heroJump;
    } else {
      final f = (_runDist / 26).floor() % 4;
      s = f == 0 ? _heroRunA : (f == 1 ? _heroRunB : (f == 2 ? _heroStand : _heroRunB));
    }
    s.draw(c, pos, scale: 3);
  }

  void _renderHud(Canvas c) {
    const white = Color(0xFFFCFCFC);
    _px(c, host.tr('score', 'SCORE'), const Offset(14, 44), 2, white, shadow: _k);
    _px(c, host.score.toString().padLeft(6, '0'), const Offset(14, 62), 2, white, shadow: _k);
    _coins[0].draw(c, const Offset(118, 58), scale: 1.5);
    _px(c, 'x${_coinsGot.toString().padLeft(2, '0')}', const Offset(134, 62), 2, white, shadow: _k);
    _px(c, host.tr('world', 'WORLD'), const Offset(200, 44), 2, white, shadow: _k);
    _px(c, '1-1', const Offset(212, 62), 2, white, shadow: _k);
    _px(c, host.tr('time', 'TIME'), const Offset(346, 44), 2, white, align: 1, shadow: _k);
    final tl = (host.timeLeft * 10).ceil();
    _px(c, tl.toString().padLeft(3, '0'), const Offset(346, 62), 2,
        host.timeLeft < 5 && (_t * 4).floor().isEven ? const Color(0xFFFC3C3C) : white,
        align: 1, shadow: _k);
    // progress to the flag
    final prog = ((_hero.x) / _poleX).clamp(0.0, 1.0);
    c.drawRect(const Rect.fromLTWH(60, 84, 240, 6), Paint()..color = const Color(0x88000000));
    c.drawRect(Rect.fromLTWH(60, 84, 240 * prog, 6), Paint()..color = const Color(0xFFF8B800));
    _flag.draw(c, const Offset(300, 78), scale: 1);
    _heroStand.draw(c, Offset(60 + 240 * prog - 7, 72), scale: 1);
  }
}
