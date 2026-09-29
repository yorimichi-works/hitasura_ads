import 'dart:math' as math;
import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.017 Pixel Tower Defense — 8-bit kingdom defense.
///
/// Tap stone pads to build an archer tower (tap again to upgrade it into a
/// cannon). Slimes, goblins and a boss orc march down the dirt road; towers
/// shoot automatically. Keep the castle's 10 hearts until all 3 waves fall.
class G017 extends MiniGame {
  static const _tile = 24.0;
  static const _top = 112.0;
  static const _archerCost = 40;
  static const _cannonCost = 60;

  // Sweetie-16 palette
  static const _k = Color(0xFF1A1C2C);
  static const _purple = Color(0xFF5D275D);
  static const _red = Color(0xFFB13E53);
  static const _orange = Color(0xFFEF7D57);
  static const _yellow = Color(0xFFFFCD75);
  static const _lime = Color(0xFFA7F070);
  static const _green = Color(0xFF38B764);
  static const _teal = Color(0xFF257179);
  static const _navy = Color(0xFF29366F);
  static const _blue = Color(0xFF3B5DC9);
  static const _sky = Color(0xFF41A6F6);
  static const _cyan = Color(0xFF73EFF7);
  static const _white = Color(0xFFF4F4F4);
  static const _silver = Color(0xFF94B0C2);
  static const _slate = Color(0xFF566C86);
  static const _dark = Color(0xFF333C57);

  static Offset _cell(int col, int row) => Offset(col * _tile + _tile / 2, _top + row * _tile + _tile / 2);

  static final _pathCells = <(int, int)>[(2, -2), (2, 6), (12, 6), (12, 14), (7, 14), (7, 19)];
  static const _padCells = <(int, int)>[(4, 4), (8, 4), (4, 8), (10, 8), (14, 10), (10, 12), (9, 17), (5, 16)];

  late final List<Offset> _way = [for (final (c, r) in _pathCells) _cell(c, r)];
  late final List<double> _segLen;
  late final double _pathLen;
  ui.Picture? _bg;

  final List<_Pad> _pads = [];
  final List<_Enemy> _enemies = [];
  final List<_Shot> _shots = [];
  final List<(double, int)> _spawnQueue = []; // (time, kind)
  double _t = 0;
  int _coins = 100;
  double _coinAcc = 0;
  int _lives = 10;
  int _wave = 0;
  double _waveBanner = -1;
  double _castleHit = 0;
  double _coinBump = 0;
  bool _built = false;
  int _kills = 0;

  // ----------------------------------------------------------- sprites ---
  static final _pal = <String, Color>{
    'K': _k, 'P': _purple, 'R': _red, 'O': _orange, 'Y': _yellow, 'L': _lime, 'G': _green, 'T': _teal,
    'N': _navy, 'B': _blue, 'S': _sky, 'C': _cyan, 'W': _white, 'V': _silver, 'M': _slate, 'D': _dark,
    'b': const Color(0xFF8B5A3C), 'n': const Color(0xFFC2885A),
  };

  static final _slime = [
    Sprite(['..KKKK..', '.KLLGGK.', 'KGLGGGGK', 'KGWKGWKK', 'KGKKGKKK', 'KGGGGGGK', '.KKKKKK.'], _pal),
    Sprite(['........', '..KKKK..', '.KLLGGK.', 'KGWKGWKK', 'KGKKGKKK', 'KGGGGGGK', 'KKKKKKKK'], _pal),
  ];
  static final _goblin = [
    Sprite([
      'K......K', 'LK.KK.KL', 'KLKLLKLK', '.KLLLLK.', '.KRLLRK.', '.KLKKLK.', '..KbbK..', '.KbbbbK.', '.KbKKbK.',
      '.KK..KK.'
    ], _pal),
    Sprite([
      'K......K', 'LK.KK.KL', 'KLKLLKLK', '.KLLLLK.', '.KRLLRK.', '.KLKKLK.', '..KbbK..', '.KbbbbK.', '..KbbK..',
      '..KKKK..'
    ], _pal),
  ];
  static final _orc = [
    Sprite([
      '..KKKKKKKK..',
      '.KVVVVVVVVK.',
      'KVWVVVVVVVVK',
      'KGGGGGGGGGGK',
      'KGRRGGGGRRGK',
      'KGGGGGGGGGGK',
      'KGWGWGGWGWGK',
      '.KGGKKKKGGK.',
      'KMMMMMMMMMMK',
      'KMGMMYYMMGMK',
      '.KMMKKKKMMK.',
      '.KKK....KKK.',
    ], _pal),
    Sprite([
      '............',
      '..KKKKKKKK..',
      '.KVVVVVVVVK.',
      'KVWVVVVVVVVK',
      'KGGGGGGGGGGK',
      'KGRRGGGGRRGK',
      'KGWGWGGWGWGK',
      '.KGGKKKKGGK.',
      'KMMMMMMMMMMK',
      'KMGMMYYMMGMK',
      '.KMMKKKKMMK.',
      '..KKK..KKK..',
    ], _pal),
  ];
  static final _archerTower = [
    Sprite([
      '....K.....', '....KRR...', '....KRRR..', '...BBBB...', '..BBBBBB..', '.BBSSBBBB.', 'BBBBBBBBBB',
      '.KVVVVVVK.', '.KVDVVDVK.', '.KVVVVVVK.', '.KMVVDVVK.', '.KVVVDVMK.', '.KVMVVVVK.', 'KKKKKKKKKK'
    ], _pal),
    Sprite([
      '....K.....', '....KRRR..', '....KRR...', '...BBBB...', '..BBBBBB..', '.BBSSBBBB.', 'BBBBBBBBBB',
      '.KVVVVVVK.', '.KVDVVDVK.', '.KVVVVVVK.', '.KMVVDVVK.', '.KVVVDVMK.', '.KVMVVVVK.', 'KKKKKKKKKK'
    ], _pal),
  ];
  static final _cannonTower = Sprite([
    'KMKMKKMKMK', 'KMMMMMMMMK', 'KMMMMMMMMK', '.KDDDDDDK.', '.KDMDDMDK.', '.KDDDDDDK.', '.KDMDDDMK.',
    '.KDDDMDDK.', '.KMDDDDMK.', 'KKKKKKKKKK'
  ], _pal);
  static final _castle = Sprite([
    '..K..........K..',
    '..KRR........KRR',
    '..KR.........KR.',
    '..K..........K..',
    'K.K.K......K.K.K',
    'KVKVK......KVKVK',
    'KVVVKK.K.K.KVVVK',
    'KVDVKVKVKVKKVDVK',
    'KVDVKVVVVVVKVDVK',
    'KVVVKVVKKVVKVVVK',
    'KVVVKVKnnKVKVVVK',
    'KVMVKVKnnKVKVMVK',
    'KVVVKVKnnKVKVVVK',
    'KKKKKKKKKKKKKKKK',
  ], _pal);
  static final _heart = Sprite(['.RR.RR.', 'RWRRRRR', 'RRRRRRR', '.RRRRR.', '..RRR..', '...R...'], _pal);
  static final _coin = Sprite(['.KKKK.', 'KYYYYK', 'KYWYOK', 'KYYYOK', 'KYOOOK', '.KKKK.'], _pal);
  static final _tree = Sprite([
    '...KK...', '..KGGK..', '.KGLGGK.', '.KGGGGK.', 'KGLGGGGK', 'KGGGGTGK', '.KKTTKK.', '...bb...', '...bb...'
  ], _pal);
  static final _rock = Sprite(['.KKK.', 'KVVMK', 'KVMMK', '.KKK.'], _pal);

  // -------------------------------------------------------------- init ---

  @override
  void init() {
    _segLen = [for (var i = 0; i < _way.length - 1; i++) (_way[i + 1] - _way[i]).distance];
    _pathLen = _segLen.fold(0.0, (a, b) => a + b);
    for (final (c, r) in _padCells) {
      _pads.add(_Pad(_cell(c, r)));
    }
    // waves: 0 slime, 1 goblin, 2 orc boss
    for (var i = 0; i < 8; i++) {
      _spawnQueue.add((.8 + i * .75, 0));
    }
    for (var i = 0; i < 10; i++) {
      _spawnQueue.add((6.8 + i * .5, 1));
    }
    _spawnQueue.add((10.4, 2));
    for (var i = 0; i < 8; i++) {
      _spawnQueue.add((11.2 + i * .55, i.isEven ? 0 : 1));
    }
    _bg = _buildBackground();
  }

  bool _isPath(int col, int row) {
    for (var i = 0; i < _pathCells.length - 1; i++) {
      final (c0, r0) = _pathCells[i];
      final (c1, r1) = _pathCells[i + 1];
      if (col >= math.min(c0, c1) && col <= math.max(c0, c1) && row >= math.min(r0, r1) && row <= math.max(r0, r1)) {
        return true;
      }
    }
    return false;
  }

  ui.Picture _buildBackground() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final r = math.Random(17);
    final pg = Paint()..isAntiAlias = false;
    for (var row = -1; row < 22; row++) {
      for (var col = 0; col < 15; col++) {
        final rect = Rect.fromLTWH(col * _tile, _top + row * _tile, _tile, _tile);
        if (_isPath(col, row)) {
          pg.color = const Color(0xFFC2885A);
          c.drawRect(rect, pg);
          pg.color = const Color(0xFFA86F46);
          for (var k = 0; k < 3; k++) {
            c.drawRect(Rect.fromLTWH(rect.left + r.nextInt(7) * 3, rect.top + r.nextInt(7) * 3, 3, 3), pg);
          }
          pg.color = const Color(0xFFD9A276);
          c.drawRect(Rect.fromLTWH(rect.left + r.nextInt(7) * 3, rect.top + r.nextInt(7) * 3, 3, 3), pg);
        } else {
          pg.color = (row + col).isEven ? const Color(0xFF3E9E4F) : const Color(0xFF44A855);
          c.drawRect(rect, pg);
          pg.color = const Color(0xFF2F8443);
          for (var k = 0; k < 2; k++) {
            final x = rect.left + r.nextInt(7) * 3, y = rect.top + r.nextInt(7) * 3;
            c.drawRect(Rect.fromLTWH(x, y, 3, 3), pg);
            c.drawRect(Rect.fromLTWH(x + 3, y - 3, 3, 3), pg);
          }
          if (r.nextDouble() < .12) {
            pg.color = r.nextBool() ? _yellow : _white;
            final x = rect.left + 3 + r.nextInt(5) * 3, y = rect.top + 3 + r.nextInt(5) * 3;
            c.drawRect(Rect.fromLTWH(x, y, 3, 3), pg);
            pg.color = _red;
            c.drawRect(Rect.fromLTWH(x, y + 3, 3, 3), pg);
          }
        }
      }
    }
    // path borders (darker dirt edge pixels)
    pg.color = const Color(0xFF8E5A38);
    for (var row = -1; row < 22; row++) {
      for (var col = 0; col < 15; col++) {
        if (!_isPath(col, row)) continue;
        final x = col * _tile, y = _top + row * _tile;
        if (col == 0 || !_isPath(col - 1, row)) c.drawRect(Rect.fromLTWH(x, y, 3, _tile), pg);
        if (col == 14 || !_isPath(col + 1, row)) c.drawRect(Rect.fromLTWH(x + _tile - 3, y, 3, _tile), pg);
        if (!_isPath(col, row - 1) && row > -1) c.drawRect(Rect.fromLTWH(x, y, _tile, 3), pg);
        if (!_isPath(col, row + 1)) c.drawRect(Rect.fromLTWH(x, y + _tile - 3, _tile, 3), pg);
      }
    }
    // decorations: trees & rocks on free tiles
    for (var i = 0; i < 26; i++) {
      final col = r.nextInt(15), row = r.nextInt(21);
      if (_isPath(col, row) || _padCells.any((p) => (p.$1 - col).abs() <= 1 && (p.$2 - row).abs() <= 1)) continue;
      if (row >= 18 && col >= 5 && col <= 9) continue;
      final o = _cell(col, row);
      if (r.nextDouble() < .7) {
        c.drawOval(Rect.fromCenter(center: o + const Offset(0, 12), width: 22, height: 6), Paint()..color = const Color(0x33000000));
        _tree.drawCentered(c, o, scale: 3);
      } else {
        _rock.drawCentered(c, o + const Offset(0, 4), scale: 3);
      }
    }
    // pond
    pg.color = _navy;
    c.drawRect(const Rect.fromLTWH(264, 520, 72, 42), pg);
    pg.color = _blue;
    c.drawRect(const Rect.fromLTWH(267, 523, 66, 36), pg);
    pg.color = _sky;
    c.drawRect(const Rect.fromLTWH(276, 530, 18, 3), pg);
    c.drawRect(const Rect.fromLTWH(303, 544, 12, 3), pg);
    return rec.endRecording();
  }

  // ------------------------------------------------------------ update ---

  Offset _posAt(double s) {
    if (s <= 0) return _way.first;
    var acc = 0.0;
    for (var i = 0; i < _segLen.length; i++) {
      if (s <= acc + _segLen[i]) return Offset.lerp(_way[i], _way[i + 1], (s - acc) / _segLen[i])!;
      acc += _segLen[i];
    }
    return _way.last;
  }

  Offset _dirAt(double s) {
    var acc = 0.0;
    for (var i = 0; i < _segLen.length; i++) {
      if (s <= acc + _segLen[i]) return (_way[i + 1] - _way[i]) / _segLen[i];
      acc += _segLen[i];
    }
    return const Offset(0, 1);
  }

  @override
  void update(double dt) {
    _t += dt;
    final sp = host.speed;
    _castleHit = M.approach(_castleHit, 0, 5, dt);
    _coinBump = M.approach(_coinBump, 0, 8, dt);
    if (_waveBanner >= 0) _waveBanner += dt;

    if (!host.finished) {
      _coinAcc += dt * 8;
      while (_coinAcc >= 1) {
        _coinAcc -= 1;
        _coins++;
      }
      // spawns
      while (_spawnQueue.isNotEmpty && _spawnQueue.first.$1 <= _t) {
        final kind = _spawnQueue.removeAt(0).$2;
        final wave = kind == 2 || _t > 10.3 ? 3 : (kind == 1 ? 2 : 1);
        if (wave != _wave) {
          _wave = wave;
          _waveBanner = 0;
          host.sfx(wave == 3 ? Sfx.horror : Sfx.pPowerup, volume: .8);
          if (wave == 3) host.shake(6, .4);
        }
        _enemies.add(_Enemy(kind,
            hp: const [3, 5, 34][kind].toDouble(), speed: const [72.0, 100.0, 66.0][kind] * (.92 + sp * .08)));
      }
    }

    // enemies
    for (var i = _enemies.length - 1; i >= 0; i--) {
      final e = _enemies[i];
      e.flash = math.max(0, e.flash - dt);
      if (e.dead) {
        e.deadT += dt;
        if (e.deadT > .35) _enemies.removeAt(i);
        continue;
      }
      e.s += e.speed * dt * (e.slow > 0 ? .55 : 1) * (host.finished ? 0 : 1);
      e.slow = math.max(0, e.slow - dt);
      e.anim += dt * (e.kind == 2 ? 5 : 8);
      if (e.s >= _pathLen && !host.finished) {
        _enemies.removeAt(i);
        final dmg = e.kind == 2 ? 10 : 1;
        _lives = math.max(0, _lives - dmg);
        _castleHit = 1;
        host.sfx(e.kind == 2 ? Sfx.pExplode : Sfx.pHit);
        host.shake(e.kind == 2 ? 14 : 5);
        host.flash(const Color(0xFFB13E53), .15);
        host.fx.pop('-$dmg', _way.last + const Offset(0, -30), color: _red, size: 28);
        host.fx.burst(_way.last, _red, count: 12, speed: 200, shape: PartShape.square, size: 6);
        if (_lives <= 0) {
          host.sfx(Sfx.pDie);
          host.lose();
        }
      }
    }

    // towers
    for (final p in _pads) {
      p.pop = M.approach(p.pop, 0, 7, dt);
      p.recoil = M.approach(p.recoil, 0, 12, dt);
      if (p.level == 0 || host.finished) continue;
      p.cool -= dt;
      final range = p.level == 1 ? 82.0 : 90.0;
      _Enemy? best;
      for (final e in _enemies) {
        if (e.dead) continue;
        final ep = _posAt(e.s);
        if ((ep - p.pos).distance <= range && (best == null || e.s > best.s)) best = e;
      }
      if (best != null) {
        final ep = _posAt(best.s);
        p.aim = math.atan2(ep.dy - p.pos.dy, ep.dx - p.pos.dx);
        if (p.cool <= 0) {
          p.recoil = 1;
          if (p.level == 1) {
            p.cool = .5;
            _shots.add(_Shot(p.pos + const Offset(0, -26), best, false, ep));
            host.sfx(Sfx.pShoot, volume: .35, rate: rand(1.3, 1.6));
          } else {
            p.cool = .95;
            final lead = _posAt(best.s + best.speed * .32);
            _shots.add(_Shot(p.pos + const Offset(0, -18), best, true, lead));
            host.sfx(Sfx.pExplode, volume: .35, rate: 1.6);
            host.fx.smoke(p.pos + Offset(math.cos(p.aim) * 14, -18 + math.sin(p.aim) * 14), count: 2, size: 8,
                color: const Color(0xAAF4F4F4));
          }
        }
      }
    }

    // projectiles
    for (var i = _shots.length - 1; i >= 0; i--) {
      final s = _shots[i];
      s.t += dt;
      if (s.cannon) {
        final k = (s.t / .34).clamp(0.0, 1.0);
        s.pos = Offset.lerp(s.from, s.to, k)! + Offset(0, -math.sin(k * math.pi) * 34);
        if (k >= 1) {
          _shots.removeAt(i);
          _explode(s.to);
        }
      } else {
        final target = s.target.dead ? s.to : _posAt(s.target.s) + const Offset(0, -6);
        s.to = target;
        final d = target - s.pos;
        final step = 430 * dt;
        s.angle = math.atan2(d.dy, d.dx);
        if (d.distance <= step) {
          _shots.removeAt(i);
          if (!s.target.dead) _damage(s.target, 1);
        } else {
          s.pos += d / d.distance * step;
        }
      }
    }

    // wave cleared?
    if (!host.finished && _spawnQueue.isEmpty && _enemies.every((e) => e.dead)) {
      host.sfx(Sfx.fanfare);
      host.fx.confetti();
      host.win(stars: _lives >= 10 ? 3 : (_lives >= 6 ? 2 : 1));
    }
  }

  void _explode(Offset at) {
    host.fx.burst(at, _orange, count: 14, speed: 180, size: 6, shape: PartShape.square, gravity: 120,
        colors: const [_yellow, _orange, _red, _white]);
    host.fx.ring(at, _yellow, size: 34, life: .25);
    host.shake(2);
    for (final e in _enemies) {
      if (e.dead) continue;
      if ((_posAt(e.s) - at).distance < 36) _damage(e, 3);
    }
  }

  void _damage(_Enemy e, double dmg) {
    e.hp -= dmg;
    e.flash = .08;
    final p = _posAt(e.s);
    if (e.hp <= 0) {
      e.dead = true;
      _kills++;
      final bounty = const [3, 4, 30][e.kind];
      _coins += bounty;
      _coinBump = 1;
      host.addScore(bounty * 10);
      host.sfx(e.kind == 2 ? Sfx.pExplode : Sfx.pCoin, volume: .7, rate: 1 + (_kills % 6) * .05);
      host.fx.pop('+$bounty', p + const Offset(0, -18), color: _yellow, size: e.kind == 2 ? 30 : 18);
      host.fx.burst(p, e.kind == 0 ? _green : (e.kind == 1 ? _lime : _green), count: e.kind == 2 ? 30 : 10,
          speed: e.kind == 2 ? 260 : 150, size: 5, shape: PartShape.square, gravity: 300);
      if (e.kind == 2) {
        host.fx.coins(p, count: 16);
        host.fx.pop('${host.tr('boss', 'BOSS')} KO!', const Offset(180, 300), color: _orange, size: 34, life: 1.2);
        host.shake(10);
        host.hitStop(.12);
        host.flash(_white, .12);
      }
    } else {
      host.sfx(Sfx.pHit, volume: .35, rate: rand(1.2, 1.5));
    }
  }

  // ------------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    _Pad? hit;
    var bestD = 30.0;
    for (final pad in _pads) {
      final d = (pad.pos - p).distance;
      if (d < bestD) {
        bestD = d;
        hit = pad;
      }
    }
    if (hit == null) return;
    _tapPad(hit);
  }

  void _tapPad(_Pad pad) {
    if (pad.level >= 2) {
      pad.pop = .5;
      host.sfx(Sfx.pSelect, volume: .5);
      return;
    }
    final cost = pad.level == 0 ? _archerCost : _cannonCost;
    if (_coins < cost) {
      pad.shake = _t;
      host.sfx(Sfx.wrong, volume: .5);
      host.fx.pop('$cost', pad.pos + const Offset(0, -30), color: _red, size: 18);
      return;
    }
    _coins -= cost;
    pad.level++;
    pad.pop = 1;
    pad.cool = .2;
    _built = true;
    host.sfx(pad.level == 1 ? Sfx.hammer : Sfx.pPowerup);
    host.sfx(Sfx.pCoin, volume: .5, rate: .8);
    host.fx.burst(pad.pos, _white, count: 12, speed: 160, shape: PartShape.square, size: 5, colors: const [_white, _yellow, _silver]);
    host.fx.smoke(pad.pos + const Offset(0, 6), count: 5, size: 14);
    host.fx.pop(pad.level == 1 ? host.tr('build', 'BUILD!') : host.tr('upgrade', 'UPGRADE!'),
        pad.pos + const Offset(0, -44), color: pad.level == 1 ? _cyan : _orange, size: 18);
    host.punch(.015);
  }

  @override
  void onKey(String key, bool down) {
    if (!down || key != 'action') return;
    for (final lvl in [0, 1]) {
      for (final p in _pads) {
        if (p.level == lvl && _coins >= (lvl == 0 ? _archerCost : _cannonCost)) {
          _tapPad(p);
          return;
        }
      }
    }
  }

  @override
  void onTimeUp() {
    if (_lives > 0) {
      host.sfx(Sfx.fanfare);
      host.fx.confetti();
      host.win(stars: _lives >= 10 ? 3 : (_lives >= 6 ? 2 : 1));
    } else {
      host.lose();
    }
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), Paint()..color = const Color(0xFF3E9E4F));
    if (_bg != null) c.drawPicture(_bg!);

    // castle
    final cp = _way.last + const Offset(0, 28);
    final ch = _castleHit;
    c.drawRect(Rect.fromCenter(center: cp + const Offset(0, 26), width: 70, height: 8), Paint()..color = const Color(0x44000000));
    _castle.drawCentered(c, cp + Offset(math.sin(_t * 50) * 3 * ch, 0), scale: 4,
        tint: ch > .6 ? _white : null);
    // castle banner flutter
    final flagOn = (_t * 4).floor().isEven;
    if (flagOn) {
      c.drawRect(Rect.fromLTWH(cp.dx + 24, cp.dy - 22, 4, 4), Paint()..color = _red);
    }

    // pads + towers (sorted by y along with enemies)
    final items = <(double, void Function())>[];
    for (final p in _pads) {
      items.add((p.pos.dy + 8, () => _drawPad(c, p)));
    }
    for (final e in _enemies) {
      final p = _posAt(e.s);
      items.add((p.dy, () => _drawEnemy(c, e, p)));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final it in items) {
      it.$2();
    }

    // projectiles
    final pp = Paint()..isAntiAlias = false;
    for (final s in _shots) {
      if (s.cannon) {
        pp.color = _k;
        c.drawRect(Rect.fromCenter(center: s.pos, width: 8, height: 8), pp);
        pp.color = _slate;
        c.drawRect(Rect.fromLTWH(s.pos.dx - 3, s.pos.dy - 3, 3, 3), pp);
      } else {
        final d = Offset(math.cos(s.angle), math.sin(s.angle));
        c.drawLine(s.pos - d * 9, s.pos, Paint()
          ..color = const Color(0xFF8B5A3C)
          ..strokeWidth = 3);
        c.drawLine(s.pos - d * 3, s.pos + d * 2, Paint()
          ..color = _white
          ..strokeWidth = 3);
        c.drawLine(s.pos - d * 10, s.pos - d * 7, Paint()
          ..color = _red
          ..strokeWidth = 4);
      }
    }

    _drawHud(c);

    // wave banner
    if (_waveBanner >= 0 && _waveBanner < 1.6) {
      final a = _waveBanner;
      final x = a < .25 ? 360 - 180 * M.easeOut(a / .25) : (a > 1.3 ? 180 - 540 * ((a - 1.3) / .3) : 180.0);
      c.drawRect(Rect.fromLTWH(0, 280, 360, 56), Paint()..color = const Color(0xCC1A1C2C));
      c.drawRect(const Rect.fromLTWH(0, 280, 360, 3), Paint()..color = _yellow);
      c.drawRect(const Rect.fromLTWH(0, 333, 360, 3), Paint()..color = _yellow);
      if (_wave == 3) {
        D.text(c, host.tr('boss', 'BOSS'), Offset(x - 50, 308), size: 30, color: _red, stroke: _k, strokeWidth: 6);
        PixelFont.draw(c, 'WAVE 3', Offset(x + 50, 298), 3.4, _yellow, align: 0, shadow: _k);
      } else {
        D.text(c, host.tr('wave', 'WAVE'), Offset(x - 26, 308), size: 30, color: _yellow, stroke: _k, strokeWidth: 6);
        PixelFont.draw(c, '$_wave/3', Offset(x + 56, 294), 4, _white, align: 0, shadow: _k);
      }
    }

    // tutorial
    if (!_built && _t < 7 && !host.finished) {
      final p = _pads[0].pos;
      final blink = (_t * 3).floor().isEven;
      c.drawRect(Rect.fromCenter(center: p, width: 34, height: 34),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = blink ? _yellow : _white);
      D.hand(c, p + const Offset(2, 4), _t, size: 38);
    }

    Retro.scanlines(c, alpha: .08);
    Retro.vignette(c, strength: .35);
  }

  void _drawHud(Canvas c) {
    final p = Paint()..isAntiAlias = false;
    p.color = _k;
    c.drawRect(const Rect.fromLTWH(0, 38, 360, 70), p);
    p.color = _dark;
    c.drawRect(const Rect.fromLTWH(0, 38, 360, 3), p);
    c.drawRect(const Rect.fromLTWH(0, 104, 360, 4), p);
    p.color = _slate;
    c.drawRect(const Rect.fromLTWH(0, 41, 360, 2), p);

    // hearts
    final hitShake = _castleHit > 0 ? math.sin(_t * 60) * 2 * _castleHit : 0.0;
    for (var i = 0; i < 10; i++) {
      final x = 10.0 + (i % 5) * 22 + hitShake;
      final y = 50.0 + (i ~/ 5) * 24;
      if (i < _lives) {
        _heart.draw(c, Offset(x, y), scale: 3);
      } else {
        _heart.draw(c, Offset(x, y), scale: 3, tint: _dark);
      }
    }
    // coins
    final bump = 1 + _coinBump * .25;
    _coin.draw(c, const Offset(130, 56), scale: 4);
    c.save();
    c.translate(162, 60);
    c.scale(bump);
    PixelFont.draw(c, '$_coins', Offset.zero, 3.4, _yellow, shadow: _purple);
    c.restore();
    PixelFont.draw(c, '+8/S', const Offset(164, 88), 1.6, _silver);
    // wave
    final label = host.tr('wave', 'WAVE');
    D.text(c, label, const Offset(306, 58), size: 14, color: _cyan, stroke: _k, strokeWidth: 3);
    PixelFont.draw(c, '${math.max(1, _wave)}/3', const Offset(306, 72), 3, _white, align: 0, shadow: _blue);
  }

  void _drawPad(Canvas c, _Pad pad) {
    final shake = (_t - pad.shake) < .3 ? math.sin(_t * 70) * 3 : 0.0;
    final o = pad.pos + Offset(shake, 0);
    final pp = Paint()..isAntiAlias = false;
    // stone slab
    pp.color = _k;
    c.drawRect(Rect.fromCenter(center: o + const Offset(0, 2), width: 30, height: 26), pp);
    pp.color = _slate;
    c.drawRect(Rect.fromCenter(center: o, width: 27, height: 22), pp);
    pp.color = _silver;
    c.drawRect(Rect.fromLTWH(o.dx - 13.5, o.dy - 11, 27, 3), pp);
    c.drawRect(Rect.fromLTWH(o.dx - 13.5, o.dy - 11, 3, 12), pp);
    if (pad.level == 0) {
      final afford = _coins >= _archerCost;
      final blink = afford && (_t * 2.5 + pad.pos.dx * .01).floor().isEven;
      pp.color = blink ? _yellow : _silver;
      c.drawRect(Rect.fromCenter(center: o, width: 12, height: 3), pp);
      c.drawRect(Rect.fromCenter(center: o, width: 3, height: 12), pp);
      if (afford) {
        _coin.draw(c, o + const Offset(-14, -24), scale: 1.5);
        PixelFont.draw(c, '$_archerCost', o + const Offset(-4, -23), 1.4, _yellow, shadow: _k);
      }
      return;
    }
    final s = 3.0 * (1 + pad.pop * .3);
    final base = o + const Offset(0, 8);
    if (pad.level == 1) {
      final frame = (_t * 3).floor() % 2;
      final spr = _archerTower[frame];
      spr.draw(c, base - Offset(spr.w * s / 2, spr.h * s), scale: s);
      // tiny archer head bobbing on top
      pp.color = _yellow;
      c.drawRect(Rect.fromLTWH(o.dx - 3 - pad.recoil * 2, o.dy - 30, 6, 6), pp);
      if (_coins >= _cannonCost) {
        final up = (_t * 4).floor().isEven;
        pp.color = up ? _lime : _green;
        final a = o + const Offset(14, -38);
        c.drawRect(Rect.fromLTWH(a.dx - 1.5, a.dy, 3, 8), pp);
        c.drawRect(Rect.fromLTWH(a.dx - 4.5, a.dy + 3, 9, 3), pp);
        c.drawRect(Rect.fromLTWH(a.dx - 3, a.dy + 1.5, 6, 3), pp);
      }
    } else {
      final spr = _cannonTower;
      spr.draw(c, base - Offset(spr.w * s / 2, spr.h * s), scale: s);
      // rotating barrel
      final top = base - Offset(0, spr.h * s + 2);
      final d = Offset(math.cos(pad.aim), math.sin(pad.aim));
      final len = 16 - pad.recoil * 5;
      c.drawLine(top, top + d * len, Paint()
        ..color = _k
        ..strokeWidth = 10);
      c.drawLine(top, top + d * (len - 2), Paint()
        ..color = _dark
        ..strokeWidth = 6);
      pp.color = _k;
      c.drawRect(Rect.fromCenter(center: top, width: 12, height: 12), pp);
      pp.color = _slate;
      c.drawRect(Rect.fromCenter(center: top, width: 6, height: 6), pp);
    }
  }

  void _drawEnemy(Canvas c, _Enemy e, Offset p) {
    final dir = _dirAt(e.s);
    final flip = dir.dx < -.1;
    final frame = (e.anim).floor() % 2;
    final spr = switch (e.kind) { 0 => _slime[frame], 1 => _goblin[frame], _ => _orc[frame] };
    final scale = e.kind == 2 ? 4.0 : 3.0;
    if (e.dead) {
      final k = 1 - e.deadT / .35;
      spr.drawCentered(c, p + Offset(0, -6 - e.deadT * 20), scale: scale * (1 + e.deadT), tint: _white, opacity: k);
      return;
    }
    final hop = e.kind == 0 ? -((e.anim * .5 % 1) * math.pi).abs() : 0.0;
    c.drawOval(Rect.fromCenter(center: p + const Offset(0, 8), width: spr.w * scale * .8, height: 6),
        Paint()..color = const Color(0x44000000));
    spr.drawCentered(c, p + Offset(0, -spr.h * scale * .35 + math.sin(hop) * 4), scale: scale, flipX: flip,
        tint: e.flash > 0 ? _white : null);
    // hp bar
    if (e.hp < e.maxHp) {
      final w = e.kind == 2 ? 44.0 : 20.0;
      final y = p.dy - spr.h * scale * .9 - 4;
      final bp = Paint()..isAntiAlias = false;
      bp.color = _k;
      c.drawRect(Rect.fromLTWH(p.dx - w / 2 - 1, y - 1, w + 2, 5), bp);
      bp.color = _red;
      c.drawRect(Rect.fromLTWH(p.dx - w / 2, y, w, 3), bp);
      bp.color = _lime;
      c.drawRect(Rect.fromLTWH(p.dx - w / 2, y, w * (e.hp / e.maxHp).clamp(0, 1), 3), bp);
    }
    if (e.kind == 2) {
      // crown for the boss
      final top = p + Offset(0, -spr.h * scale * .85 - 10);
      final cp = Paint()..color = _yellow;
      c.drawRect(Rect.fromLTWH(top.dx - 9, top.dy + 3, 18, 5), cp);
      for (var i = 0; i < 3; i++) {
        c.drawRect(Rect.fromLTWH(top.dx - 9 + i * 7.5, top.dy - 2, 3, 5), cp);
      }
    }
  }
}

class _Pad {
  _Pad(this.pos);
  final Offset pos;
  int level = 0; // 0 empty, 1 archer, 2 cannon
  double cool = 0;
  double aim = -math.pi / 2;
  double pop = 0;
  double recoil = 0;
  double shake = -9;
}

class _Enemy {
  _Enemy(this.kind, {required this.hp, required this.speed}) : maxHp = hp;
  final int kind;
  double hp;
  final double maxHp;
  final double speed;
  double s = 0;
  double anim = 0;
  double flash = 0;
  double slow = 0;
  bool dead = false;
  double deadT = 0;
}

class _Shot {
  _Shot(this.from, this.target, this.cannon, this.to) : pos = from;
  final Offset from;
  final _Enemy target;
  final bool cannon;
  Offset to;
  Offset pos;
  double t = 0;
  double angle = 0;
}
