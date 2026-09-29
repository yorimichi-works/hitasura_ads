import '../engine/engine.dart';

/// No.025 Bunker Builder — Fallout Shelter parody in pixel art.
/// Tap dirt to dig rooms, drag dwellers into them, squash radroaches, and keep
/// POWER / WATER / FOOD above zero until the timer runs out.
class G025 extends MiniGame {
  static const _cols = 4, _rows = 4;
  static const _x0 = 66.0, _y0 = 164.0, _cw = 70.0, _ch = 94.0;
  static const _ground = 150.0;

  static const _resCol = [Color(0xFFFFD23F), Color(0xFF3FB8FF), Color(0xFF6BE05A)];

  final List<_Room> _cells = [];
  final List<_Dweller> _dw = [];
  final List<_Roach> _roaches = [];
  final List<double> _res = [.72, .72, .72];
  final List<double> _resFlash = [0, 0, 0];
  final Paint _p = Paint()..isAntiAlias = false;
  double _t = 0;
  double _nextArrival = 2.5;
  int _arrivals = 0;
  final List<double> _raids = [8.5, 15.5];
  int _raid = 0;
  double _raidBanner = 0;
  _Dweller? _drag;
  Offset _dragPos = Offset.zero;
  bool _dead = false;
  int _digs = 0;
  int _assigned = 0;

  // sprites
  late final List<List<Sprite>> _dwSprites;
  late final Sprite _dwFlail;
  late final List<Sprite> _roachSp;
  late final List<Sprite> _icons;
  late final Sprite _gear;
  late final Path _speck;
  late final Path _speck2;

  @override
  void init() {
    const hair = [Color(0xFF6B3A1E), Color(0xFFE8C04A), Color(0xFF1E1E2A), Color(0xFFD9502B)];
    List<String> dweller(int frame) => [
          '..hhh..',
          '.hhhhh.',
          '.hssss.',
          '.skssk.',
          '..sss..',
          '.bbybb.',
          'sbbybbs',
          'sbbybbs',
          '.bbybb.',
          frame == 0 ? '.bb.bb.' : '..bbb..',
          frame == 0 ? '.bb.bb.' : '.bb..b.',
          frame == 0 ? '.kk.kk.' : '.kk..k.',
        ];
    Map<String, Color> pal(Color h) => {
          'h': h,
          's': const Color(0xFFFFC996),
          'k': const Color(0xFF14101E),
          'b': const Color(0xFF2E5BD8),
          'y': const Color(0xFFFFD23F),
        };
    _dwSprites = [
      for (final h in hair) [Sprite(dweller(0), pal(h)), Sprite(dweller(1), pal(h))]
    ];
    _dwFlail = Sprite(const [
      's.hhh.s',
      's.hhh.s',
      'shssssh',
      '.skssk.',
      '..sKs..',
      '.bbybb.',
      '.bbybb.',
      '.bbybb.',
      '.bbybb.',
      'bb...bb',
      'b.....b',
      'k.....k',
    ], {
      ...pal(hair[0]),
      'K': const Color(0xFF8B1E3F),
    });
    final roachPal = {
      'r': const Color(0xFF8A4B22),
      'R': const Color(0xFFB8733A),
      'k': const Color(0xFF14101E),
      'g': const Color(0xFF9BE22D),
    };
    _roachSp = [
      Sprite(const ['k.......k', '.k.....k.', '..RRrrr..', '.gRRRrrrk', '..rrrrr..', '.k.k.k.k.'], roachPal),
      Sprite(const ['.k.....k.', 'k.......k', '..RRrrr..', '.gRRRrrrk', '..rrrrr..', 'k.k.k.k..'], roachPal),
    ];
    _icons = [
      Sprite(const ['...yy', '..yy.', '.yyyy', 'yyyy.', '..yy.', '.yy..', 'yy...'], {'y': _resCol[0]}),
      Sprite(const ['..b..', '..b..', '.bbb.', 'bbwbb', 'bwbbb', 'bbbbb', '.bbb.'],
          {'b': _resCol[1], 'w': const Color(0xFFDDF4FF)}),
      Sprite(const ['..g..', '.gg..', '.rrr.', 'rrwrr', 'rwrrr', 'rrrrr', '.rrr.'],
          {'g': _resCol[2], 'r': const Color(0xFFE8413C), 'w': const Color(0xFFFFB0A0)}),
    ];
    // vault gear from a circle equation
    final gearRows = <String>[];
    for (var y = 0; y < 15; y++) {
      final sb = StringBuffer();
      for (var x = 0; x < 15; x++) {
        final dx = x - 7, dy = y - 7;
        final d = sqrt((dx * dx + dy * dy).toDouble());
        final a = atan2(dy.toDouble(), dx.toDouble());
        final tooth = cos(a * 8) > .3 ? 7.5 : 6.4;
        if (d < 2.2) {
          sb.write('d');
        } else if (d < 4.6) {
          sb.write('y');
        } else if (d < 5.4) {
          sb.write('d');
        } else if (d < tooth) {
          sb.write('g');
        } else {
          sb.write('.');
        }
      }
      gearRows.add(sb.toString());
    }
    _gear = Sprite(gearRows, {'g': const Color(0xFF9AA3B5), 'd': const Color(0xFF4A5165), 'y': const Color(0xFFFFD23F)});

    // dirt speckles (two shades), local to a cell
    _speck = Path();
    _speck2 = Path();
    final r = Random(7);
    for (var i = 0; i < 26; i++) {
      final x = (r.nextInt(33) * 2).toDouble(), y = (r.nextInt(45) * 2).toDouble();
      (i.isEven ? _speck : _speck2).addRect(Rect.fromLTWH(x, y, i % 3 == 0 ? 4 : 2, 2));
    }

    // cells: blueprints guarantee 4 of each type + 2 bedrock boulders
    final types = <int>[0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 0, 1, 2, -1];
    types.shuffle(rng);
    for (var i = 0; i < _cols * _rows; i++) {
      final col = i % _cols, row = i ~/ _cols;
      _cells.add(_Room(Rect.fromLTWH(_x0 + col * _cw, _y0 + row * _ch, _cw, _ch), types[i]));
    }
    // two dwellers already waiting at the door
    _spawnDweller(x: 110);
    _spawnDweller(x: 150);
  }

  void _spawnDweller({double? x}) {
    final d = _Dweller(Offset(x ?? 380, _ground), _arrivals % 4);
    _dw.add(d);
    _arrivals++;
    if (x == null) host.sfx(Sfx.pSelect, volume: .6);
  }

  @override
  void update(double dt) {
    _t += dt;
    _raidBanner = max(0, _raidBanner - dt);
    for (var i = 0; i < 3; i++) {
      _resFlash[i] = max(0, _resFlash[i] - dt * 3);
    }
    if (_dead) return;

    // arrivals
    if (_arrivals < 7 && host.time >= _nextArrival) {
      _nextArrival += 3.6;
      _spawnDweller();
    }
    // raids
    if (_raid < _raids.length && host.time >= _raids[_raid]) {
      _raid++;
      _startRaid();
    }

    // digging
    for (final r in _cells) {
      if (r.dig > 0 && !r.built) {
        r.dig += dt / .45;
        if ((_t * 12).floor() != ((_t - dt) * 12).floor()) {
          host.fx.burst(r.rect.center + Offset(rand(-20, 20), rand(-20, 20)), const Color(0xFF8A5A33),
              count: 3, speed: 120, size: 5, shape: PartShape.square, gravity: 500);
        }
        if (r.dig >= 1) {
          r.built = true;
          r.pop = 1;
          host.sfx(Sfx.pPowerup, rate: 1 + r.type * .1);
          host.fx.burst(r.rect.center, _resCol[r.type], count: 16, speed: 200, size: 6, shape: PartShape.square);
          host.addScore(50, r.rect.center);
        }
      }
      r.pop = max(0, r.pop - dt * 2);
    }

    // waiting dwellers line up on the surface
    var wi = 0;
    for (final d in _dw) {
      if (d == _drag) continue;
      d.happy = max(0, d.happy - dt);
      d.anim += dt;
      if (d.room == null) {
        final tx = 104.0 + wi * 26;
        wi++;
        d.pos = Offset(M.approach(d.pos.dx, tx, 3, dt), M.approach(d.pos.dy, _ground, 14, dt));
        d.walking = (d.pos.dx - tx).abs() > 2;
        d.face = d.pos.dx > tx ? -1 : 1;
      } else {
        final rr = d.room!.rect;
        final y = rr.bottom - 8;
        if ((d.pos.dy - y).abs() > 1) {
          d.pos = Offset(d.pos.dx, M.approach(d.pos.dy, y, 12, dt));
        }
        final lo = rr.left + 12, hi = rr.right - 12;
        d.pos = Offset((d.pos.dx + d.face * 16 * dt).clamp(lo, hi), d.pos.dy);
        if (d.pos.dx <= lo || d.pos.dx >= hi || chance(dt * .3)) d.face = -d.face;
        d.walking = true;
      }
    }

    // roaches
    for (final r in _roaches) {
      r.anim += dt;
      final rr = r.room.rect;
      r.pos += Offset(r.dir * 34 * dt, 0);
      if (r.pos.dx < rr.left + 10 || r.pos.dx > rr.right - 10) r.dir = -r.dir;
    }

    // economy
    final pop = _dw.length;
    const drain = [.036, .032, .03];
    for (var i = 0; i < 3; i++) {
      var d = -(drain[i] + (i == 2 ? pop * .003 : 0)) * host.speed;
      for (final room in _cells) {
        if (!room.built || room.type != i) continue;
        final staff = _dw.where((w) => w.room == room && w != _drag).length;
        final bugged = _roaches.any((r) => r.room == room);
        if (bugged) {
          d -= .02;
        } else {
          d += staff * .068;
        }
        room.working = staff > 0 && !bugged;
      }
      _res[i] = (_res[i] + d * dt).clamp(0, 1);
      if (_res[i] <= 0 && !_dead) {
        _dead = true;
        _resFlash[i] = 3;
        host.sfx(Sfx.pDie);
        host.shake(10);
        host.flash(const Color(0x88000000), .5);
        host.fx.pop(host.tr('oops', 'OOPS'), const Offset(180, 330), color: Pal.red, size: 40);
        host.lose();
      }
    }
  }

  void _startRaid() {
    final rooms = _cells.where((r) => r.built).toList();
    final pool = rooms.isEmpty ? _cells.where((r) => r.type >= 0).toList() : rooms;
    final n = 2 + _raid;
    for (var i = 0; i < n; i++) {
      final room = pick(pool);
      _roaches.add(_Roach(room, Offset(room.rect.left + rand(14, room.rect.width - 14), room.rect.bottom - 8), chance(.5) ? 1 : -1));
    }
    _raidBanner = 2;
    host.sfx(Sfx.horror, volume: .7);
    host.shake(4);
    host.flash(const Color(0x55FF2020));
  }

  _Dweller? _dwellerAt(Offset p) {
    for (final d in _dw.reversed) {
      final r = Rect.fromLTWH(d.pos.dx - 14, d.pos.dy - 42, 28, 46);
      if (r.contains(p)) return d;
    }
    return null;
  }

  _Room? _cellAt(Offset p) {
    for (final r in _cells) {
      if (r.rect.contains(p)) return r;
    }
    return null;
  }

  @override
  void onDown(Offset p) {
    if (_dead) return;
    // squash roaches first
    for (final r in _roaches) {
      if ((r.pos + const Offset(0, -6) - p).distance < 26) {
        _roaches.remove(r);
        host.sfx(Sfx.pHit);
        host.sfx(Sfx.squish, volume: .6);
        host.fx.burst(r.pos, const Color(0xFF9BE22D), count: 14, speed: 180, size: 6, shape: PartShape.square);
        host.addScore(80, r.pos + const Offset(0, -20));
        host.shake(3);
        if (_roaches.isEmpty) {
          host.fx.pop(host.tr('clear', 'CLEAR!'), const Offset(180, 300), color: Pal.lime, size: 30);
          host.sfx(Sfx.pCoin);
        }
        return;
      }
    }
    final d = _dwellerAt(p);
    if (d != null) {
      _drag = d;
      _dragPos = p;
      host.sfx(Sfx.pJump, volume: .6);
      return;
    }
    final cell = _cellAt(p);
    if (cell != null && !cell.built && cell.dig == 0) {
      if (cell.type < 0) {
        host.sfx(Sfx.clang);
        cell.pop = .6;
        host.fx.pop('!', p, color: Pal.white, size: 20);
        return;
      }
      cell.dig = .01;
      _digs++;
      host.sfx(Sfx.dig);
      host.shake(2);
    }
  }

  @override
  void onMove(Offset p) {
    if (_drag != null) _dragPos = p;
  }

  @override
  void onUp(Offset p) {
    final d = _drag;
    if (d == null) return;
    _drag = null;
    final cell = _cellAt(p);
    if (cell != null && cell.built && _dw.where((w) => w.room == cell).length < 2) {
      d.room = cell;
      d.pos = Offset(p.dx.clamp(cell.rect.left + 12, cell.rect.right - 12), p.dy);
      d.happy = 1.2;
      _assigned++;
      host.sfx(Sfx.pCoin, rate: 1 + cell.type * .12);
      host.fx.sparkle(Offset(d.pos.dx, cell.rect.bottom - 30), count: 8, radius: 20, color: _resCol[cell.type]);
      host.fx.pop('+1', Offset(d.pos.dx, cell.rect.top + 20), color: _resCol[cell.type], size: 22);
    } else {
      host.sfx(Sfx.boing, volume: .6);
      d.pos = p;
    }
  }

  @override
  void onTimeUp() {
    final m = _res.reduce(min);
    host.fx.confetti();
    host.sfx(Sfx.pPowerup);
    host.win(stars: m > .5 ? 3 : (m > .25 ? 2 : 1));
  }

  // ---------------------------------------------------------------- render

  void _rect(Canvas c, double x, double y, double w, double h, Color col) {
    _p.color = col;
    c.drawRect(Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), w, h), _p);
  }

  @override
  void render(Canvas c) {
    final blackout = _dead ? .6 : 0.0;
    // --- surface sky: banded wasteland dusk
    const bands = [Color(0xFF3B1F4A), Color(0xFF6A2C4E), Color(0xFFA8433E), Color(0xFFE07A3C), Color(0xFFF2B35A)];
    for (var i = 0; i < bands.length; i++) {
      _rect(c, 0, 36 + i * 23, 360, 23, bands[i]);
    }
    // dithered band edges
    for (var i = 1; i < bands.length; i++) {
      for (var x = 0.0; x < 360; x += 8) {
        _rect(c, x + (i.isEven ? 4 : 0), 36 + i * 23 - 2, 4, 2, bands[i - 1]);
      }
    }
    // sun
    _rect(c, 262, 96, 32, 20, const Color(0xFFFFE9A0));
    _rect(c, 266, 92, 24, 4, const Color(0xFFFFE9A0));
    // ruined skyline
    const sky = Color(0xFF2A1A2E);
    const bld = [(150.0, 30.0, 28.0), (182.0, 18.0, 44.0), (230.0, 26.0, 22.0), (300.0, 20.0, 36.0), (330.0, 30.0, 16.0)];
    for (final b in bld) {
      _rect(c, b.$1, _ground - b.$3, b.$2, b.$3, sky);
      for (var wy = _ground - b.$3 + 6; wy < _ground - 6; wy += 8) {
        if (((wy + b.$1) ~/ 8).isEven) _rect(c, b.$1 + 6, wy, 4, 4, const Color(0xFFFF9A4A));
      }
    }
    // ground strip
    _rect(c, 0, _ground, 360, 8, const Color(0xFF7A5A3A));
    _rect(c, 0, _ground + 8, 360, 6, const Color(0xFF5C4128));

    // --- underground
    _rect(c, 0, _ground + 14, 360, 640 - _ground - 14, const Color(0xFF4A2F1C));
    // bedrock bottom
    _rect(c, 0, _y0 + _rows * _ch, 360, 640, const Color(0xFF2B2230));
    for (var x = 0.0; x < 360; x += 24) {
      _rect(c, x + 6, _y0 + _rows * _ch + 14 + (x % 48 == 0 ? 8 : 0), 12, 8, const Color(0xFF3D3345));
    }
    // fossil easter egg
    _rect(c, 40, 590, 30, 4, const Color(0xFFD9CFC0));
    for (var i = 0; i < 4; i++) {
      _rect(c, 44.0 + i * 7, 584, 3, 16, const Color(0xFFD9CFC0));
    }
    _rect(c, 70, 586, 10, 10, const Color(0xFFD9CFC0));

    // elevator shaft
    _rect(c, 12, _ground + 14, 50, _rows * _ch + (_y0 - _ground - 14), const Color(0xFF1E1826));
    for (var y = _ground + 16; y < _y0 + _rows * _ch; y += 12) {
      _rect(c, 16, y, 42, 2, const Color(0xFF3A3346));
    }
    _rect(c, 14, _ground + 14, 3, _rows * _ch + 10, const Color(0xFF6D6D7A));
    _rect(c, 57, _ground + 14, 3, _rows * _ch + 10, const Color(0xFF6D6D7A));
    final ey = _y0 + (_rows - 1) * _ch * M.wave(_t, .12);
    _rect(c, 18, ey + 30, 38, 56, const Color(0xFF9AA3B5));
    _rect(c, 22, ey + 36, 30, 44, const Color(0xFF5B6275));
    _rect(c, 36, ey + 36, 2, 44, const Color(0xFF9AA3B5));
    // vault door
    final gs = 4.0;
    c.save();
    c.translate(37, _ground - 16);
    c.rotate(_t * .6);
    _gear.draw(c, Offset(-7.5 * gs, -7.5 * gs), scale: gs);
    c.restore();

    for (final r in _cells) {
      _drawCell(c, r);
    }

    // roaches
    for (final r in _roaches) {
      _roachSp[(r.anim * 10).floor() % 2].drawCentered(c, r.pos + const Offset(0, -8), scale: 3, flipX: r.dir < 0);
    }

    // dwellers
    for (final d in _dw) {
      if (d == _drag) continue;
      final sp = _dwSprites[d.hair][d.walking ? ((d.anim * 6).floor() % 2) : 0];
      final hop = d.happy > 0 ? -((d.happy * 8).floor() % 2) * 4.0 : 0.0;
      sp.draw(c, Offset((d.pos.dx - 10.5).roundToDouble(), (d.pos.dy - 36 + hop).roundToDouble()), scale: 3, flipX: d.face < 0);
      if (d.room == null && host.time < 5 && _assigned == 0) {
        // blinking arrow over first waiting dweller
        if ((_t * 3).floor().isEven && d == _dw.firstWhere((w) => w.room == null)) {
          _rect(c, d.pos.dx - 3, d.pos.dy - 52, 6, 6, Pal.yellow);
          _rect(c, d.pos.dx - 1, d.pos.dy - 46, 2, 2, Pal.yellow);
        }
      }
    }
    if (_drag != null) {
      final p = _dragPos + Offset(0, sin(_t * 30) * 2);
      _dwFlail.draw(c, Offset((p.dx - 10.5).roundToDouble(), (p.dy - 24).roundToDouble()), scale: 3);
      final cell = _cellAt(_dragPos);
      if (cell != null) {
        final ok = cell.built && _dw.where((w) => w.room == cell).length < 2;
        final col = ok ? Pal.lime : Pal.red;
        _p.color = col;
        final r = cell.rect.deflate(3);
        for (final e in [
          Rect.fromLTWH(r.left, r.top, r.width, 3),
          Rect.fromLTWH(r.left, r.bottom - 3, r.width, 3),
          Rect.fromLTWH(r.left, r.top, 3, r.height),
          Rect.fromLTWH(r.right - 3, r.top, 3, r.height),
        ]) {
          c.drawRect(e, _p);
        }
      }
    }

    if (blackout > 0) {
      _rect(c, 0, 36, 360, 604, Color.fromRGBO(0, 0, 0, blackout));
    }

    _drawHud(c);
    Retro.scanlines(c, alpha: .12);
    Retro.vignette(c, strength: .35);

    // tutorial
    if (host.time < 3.5 && _digs == 0) {
      final target = _cells.firstWhere((r) => r.type >= 0);
      D.hand(c, target.rect.center, _t);
      D.text(c, host.tr('tap', 'TAP!'), target.rect.center + const Offset(0, -60), size: 20, color: Pal.yellow, stroke: Pal.ink);
    } else if (_digs > 0 && _assigned == 0 && host.time < 9 && _cells.any((r) => r.built)) {
      final room = _cells.firstWhere((r) => r.built);
      final w = _dw.where((d) => d.room == null).toList();
      if (w.isNotEmpty) {
        final from = w.first.pos + const Offset(0, -20);
        final k = (_t * .8) % 1;
        D.hand(c, Offset.lerp(from, room.rect.center, M.easeInOut(M.clamp01(k * 1.3)))!, 0);
        D.text(c, host.tr('drag', 'DRAG!'), const Offset(250, 128), size: 20, color: Pal.yellow, stroke: Pal.ink);
      }
    }
    if (_raidBanner > 0) {
      final s = 1 + .08 * sin(_t * 20);
      D.rrect(c, const Rect.fromLTWH(0, 290, 360, 56), 0, const Color(0xCC5A0010));
      D.title(c, host.tr('danger', 'DANGER!'), const Offset(180, 316), size: 36, color: Pal.red, stroke: Pal.white, scale: s);
    }
  }

  void _drawHud(Canvas c) {
    _rect(c, 0, 36, 360, 56, const Color(0xE0141020));
    _rect(c, 0, 90, 360, 2, const Color(0xFF3A3346));
    for (var i = 0; i < 3; i++) {
      final x = 10.0 + i * 118;
      final low = _res[i] < .25;
      final blink = low && (_t * 6).floor().isEven;
      _icons[i].draw(c, Offset(x, 46), scale: 3);
      _rect(c, x + 20, 48, 88, 16, const Color(0xFF000000));
      _rect(c, x + 22, 50, 84, 12, const Color(0xFF2A2436));
      final w = (84 * _res[i] / 4).floor() * 4.0;
      _rect(c, x + 22, 50, w, 12, blink ? Pal.red : _resCol[i]);
      _rect(c, x + 22, 50, w, 3, const Color(0x55FFFFFF));
      for (var k = 1; k < 7; k++) {
        _rect(c, x + 22 + k * 12, 50, 1, 12, const Color(0x44000000));
      }
      PixelFont.draw(c, '${(_res[i] * 100).round()}', Offset(x + 64, 70), 2, blink ? Pal.red : Pal.white,
          align: 0, shadow: const Color(0xFF000000));
    }
    // dweller count
    _dwSprites[0][0].draw(c, const Offset(304, 96), scale: 2);
    PixelFont.draw(c, 'x${_dw.length}', const Offset(322, 104), 2, Pal.white, shadow: const Color(0xFF000000));
  }

  void _drawCell(Canvas c, _Room r) {
    final rr = r.rect;
    final sh = r.pop > 0 ? sin(_t * 60) * 2 * r.pop : 0.0;
    final x = rr.left + sh, y = rr.top;
    if (!r.built) {
      final shake = r.dig > 0 ? sin(_t * 70) * 2 : 0.0;
      if (r.type < 0) {
        _rect(c, x, y, rr.width, rr.height, const Color(0xFF3A2A22));
        _rect(c, x + 8, y + 14, 44, 30, const Color(0xFF6D6D7A));
        _rect(c, x + 14, y + 10, 30, 4, const Color(0xFF8E8AA3));
        _rect(c, x + 24, y + 50, 36, 28, const Color(0xFF5B5B68));
        _rect(c, x + 28, y + 46, 20, 4, const Color(0xFF7A7A88));
        return;
      }
      _rect(c, x + shake, y, rr.width, rr.height, const Color(0xFF6B4527));
      c.save();
      c.translate(x + shake + 2, y + 2);
      _p.color = const Color(0xFF55361E);
      c.drawPath(_speck, _p);
      _p.color = const Color(0xFF8A5E36);
      c.drawPath(_speck2, _p);
      c.restore();
      // cell edge
      _rect(c, x, y, rr.width, 2, const Color(0xFF7E5632));
      _rect(c, x, y, 2, rr.height, const Color(0xFF7E5632));
      // blueprint icon (blinking hint)
      final blink = .35 + .25 * M.wave(_t + rr.left * .01, 1.2);
      _icons[r.type].drawCentered(c, rr.center + Offset(shake, 0), scale: 4, opacity: blink);
      if (r.dig > 0) {
        final h = rr.height * r.dig;
        _rect(c, x, y + rr.height - h, rr.width, h, const Color(0xFF1E1826));
        _rect(c, x, y + rr.height - h, rr.width, 3, const Color(0xFFFFD23F));
      }
      return;
    }
    // built room
    final col = _resCol[r.type];
    final on = r.working || (_t * 8).floor() % 7 != 0;
    _rect(c, x, y, rr.width, rr.height, const Color(0xFF1E1826));
    _rect(c, x + 3, y + 3, rr.width - 6, rr.height - 6, Color.lerp(const Color(0xFF2D2A3A), col, r.working ? .18 : .05)!);
    // floor + ceiling light
    _rect(c, x + 3, y + rr.height - 8, rr.width - 6, 5, const Color(0xFF6D6D7A));
    _rect(c, x + rr.width / 2 - 8, y + 3, 16, 4, on ? const Color(0xFFFFF4C0) : const Color(0xFF55505E));
    if (r.working) {
      _p.color = const Color(0x22FFF4C0);
      c.drawPath(
          Path()
            ..moveTo(x + rr.width / 2 - 8, y + 7)
            ..lineTo(x + rr.width / 2 + 8, y + 7)
            ..lineTo(x + rr.width - 6, y + rr.height - 8)
            ..lineTo(x + 6, y + rr.height - 8)
            ..close(),
          _p);
    }
    final bx = x + 8, by = y + 16;
    switch (r.type) {
      case 0: // generator
        _rect(c, bx, by + 18, 30, 40, const Color(0xFF9AA3B5));
        _rect(c, bx + 4, by + 22, 22, 10, const Color(0xFF3A3346));
        for (var i = 0; i < 3; i++) {
          final lit = r.working && ((_t * 6).floor() + i) % 3 == 0;
          _rect(c, bx + 6.0 + i * 7, by + 25, 4, 4, lit ? col : const Color(0xFF55505E));
        }
        _rect(c, bx + 4, by + 38, 22, 3, const Color(0xFF6D6D7A));
        _rect(c, bx + 4, by + 44, 22, 3, const Color(0xFF6D6D7A));
        if (r.working && (_t * 10).floor().isEven) _icons[0].draw(c, Offset(bx + 36, by + 4), scale: 2);
      case 1: // water tank
        _rect(c, bx + 2, by + 8, 26, 50, const Color(0xFF6D6D7A));
        final lvl = 20 + 20 * M.wave(_t, .5);
        _rect(c, bx + 5, by + 55 - lvl, 20, lvl, col);
        _rect(c, bx + 5, by + 55 - lvl, 20, 2, const Color(0xFFDDF4FF));
        if (r.working) {
          final by2 = by + 50 - ((_t * 30) % 30);
          _rect(c, bx + 10, by2, 2, 2, const Color(0xFFDDF4FF));
          _rect(c, bx + 18, by2 + 12, 2, 2, const Color(0xFFDDF4FF));
        }
        _rect(c, bx + 28, by + 16, 14, 3, const Color(0xFF9AA3B5));
      default: // hydroponics
        for (var i = 0; i < 3; i++) {
          final px = bx + i * 16.0;
          _rect(c, px, by + 50, 12, 8, const Color(0xFF8A5A33));
          final gh = 8.0 + (r.working ? 6 * M.wave(_t + i * .3, .8) : 0.0);
          _rect(c, px + 5, by + 50 - gh, 2, gh, col);
          _rect(c, px + 1, by + 46 - gh, 10, 5, col);
          if (i == 1) _rect(c, px + 4, by + 44 - gh, 4, 4, const Color(0xFFE8413C));
        }
    }
    // occupancy pips
    final n = _dw.where((w) => w.room == r).length;
    for (var i = 0; i < 2; i++) {
      _rect(c, x + rr.width - 20 + i * 8, y + 8, 6, 6, i < n ? col : const Color(0xFF3A3346));
    }
    if (r.pop > 0) {
      _p.color = Color.fromRGBO(255, 255, 255, r.pop * .5);
      c.drawRect(rr, _p);
    }
  }
}

class _Room {
  _Room(this.rect, this.type);
  final Rect rect;
  final int type; // 0 power, 1 water, 2 food, -1 rock
  bool built = false;
  bool working = false;
  double dig = 0;
  double pop = 0;
}

class _Dweller {
  _Dweller(this.pos, this.hair);
  Offset pos;
  final int hair;
  _Room? room;
  double anim = 0;
  double face = -1;
  bool walking = true;
  double happy = 0;
}

class _Roach {
  _Roach(this.room, this.pos, this.dir);
  final _Room room;
  Offset pos;
  double dir;
  double anim = 0;
}
