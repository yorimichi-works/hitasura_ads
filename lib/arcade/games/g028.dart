import '../engine/engine.dart';

/// No.028 Merge Turret Defense — buy guns, drag equal guns together to merge
/// them into bigger guns (pistol → rifle → cannon → laser → mega rail) and
/// hold the wall against the horde until the timer ends.
class G028 extends MiniGame {
  static const _cols = 4, _rows = 3;
  static const _gx0 = 12.0, _gy0 = 418.0, _cw = 84.0, _chh = 50.0;
  static const _wallY = 384.0;
  static const _maxLv = 5;
  static const _lvCol = [Color(0xFF3FB8FF), Color(0xFF2ECC71), Color(0xFFFF8A1F), Color(0xFF8C4DFF), Color(0xFFFFC53D)];
  static const _dmg = [1.0, 2.2, 7.0, 4.5, 32.0];
  static const _rate = [2.2, 3.4, 1.2, 7.0, 1.4];
  static const _laneX = [54.0, 138.0, 222.0, 306.0];

  final List<_Turret?> _grid = List.filled(12, null);
  final List<_Enemy> _enemies = [];
  final List<_Shot> _shots = [];
  final List<_Beam> _beams = [];
  double _t = 0;
  double _spawnT = 1.2;
  bool _bossSpawned = false;
  int _coins = 36;
  int _bought = 0;
  double _wall = 100;
  double _wallHit = 0;
  double _coinPop = 0;
  double _buyPress = 0;
  int _merges = 0;
  bool _dead = false;

  int? _dragFrom;
  Offset _dragPos = Offset.zero;

  int get _price => 10 + _bought * 2;
  static const Rect _buyRect = Rect.fromLTWH(118, 580, 190, 50);

  static Offset _cellC(int i) => Offset(_gx0 + (i % _cols) * _cw + _cw / 2, _gy0 + (i ~/ _cols) * _chh + _chh / 2);

  @override
  void init() {
    _grid[5] = _Turret(1);
    _grid[6] = _Turret(1);
  }

  int? _cellAt(Offset p) {
    final cx = ((p.dx - _gx0) / _cw).floor(), cy = ((p.dy - _gy0) / _chh).floor();
    if (cx < 0 || cx >= _cols || cy < 0 || cy >= _rows) return null;
    return cy * _cols + cx;
  }

  void _buy() {
    if (_dead) return;
    _buyPress = 1;
    final empty = [for (var i = 0; i < 12; i++) if (_grid[i] == null) i];
    if (_coins < _price || empty.isEmpty) {
      host.sfx(Sfx.wrong, volume: .6);
      host.fx.pop(empty.isEmpty ? host.tr('merge', 'MERGE!') : host.tr('money', 'MONEY'), _buyRect.center + const Offset(0, -40),
          color: Pal.red, size: 20);
      return;
    }
    _coins -= _price;
    _bought++;
    // fill front rows first
    final i = empty.first;
    _grid[i] = _Turret(1)..pop = 1;
    host.sfx(Sfx.cash);
    host.sfx(Sfx.pop, rate: 1.2);
    host.fx.burst(_cellC(i), _lvCol[0], count: 10, speed: 150, size: 5);
  }

  @override
  void update(double dt) {
    _t += dt;
    _wallHit = max(0, _wallHit - dt * 3);
    _coinPop = max(0, _coinPop - dt * 3);
    _buyPress = max(0, _buyPress - dt * 5);
    for (final tt in _grid) {
      if (tt == null) continue;
      tt.pop = max(0, tt.pop - dt * 2.5);
      tt.recoil = max(0, tt.recoil - dt * 8);
    }
    if (_dead) {
      for (final e in _enemies) {
        e.pos += Offset(0, 60 * dt);
        e.anim += dt;
      }
      return;
    }

    // spawning
    _spawnT -= dt * host.speed;
    if (_spawnT <= 0) {
      _spawnT = max(.42, 1.15 - host.time * .035) * rand(.75, 1.25);
      final r = rng.nextDouble();
      final kind = host.time < 4 ? 0 : (r < .6 ? 0 : (r < .85 ? 1 : 2));
      _spawn(kind);
    }
    if (!_bossSpawned && host.time > 13.5) {
      _bossSpawned = true;
      _spawn(3);
      host.sfx(Sfx.horror);
      host.shake(6);
    }

    // enemies
    for (final e in _enemies) {
      e.anim += dt;
      e.hit = max(0, e.hit - dt * 6);
      if (e.pos.dy < _wallY - e.size * .7) {
        e.pos += Offset(sin(e.anim * 3 + e.lane) * 6 * dt, e.speed * host.speed * dt);
      } else {
        e.biting += dt;
        final dps = [4.0, 3.0, 9.0, 18.0][e.kind];
        _wall -= dps * dt;
        _wallHit = 1;
        if (e.biting > .5) {
          e.biting = 0;
          host.sfx(Sfx.chomp, volume: .5, rate: rand(.8, 1.2));
          host.fx.burst(Offset(e.pos.dx, _wallY + 6), const Color(0xFFC8B08A), count: 3, speed: 90, size: 5);
        }
      }
    }
    if (_wall <= 0 && !_dead) {
      _wall = 0;
      _dead = true;
      host.sfx(Sfx.crash);
      host.sfx(Sfx.jingleLose);
      host.shake(12);
      host.flash(const Color(0x88FF2040));
      host.lose();
    }

    // turrets
    for (var i = 0; i < 12; i++) {
      final tt = _grid[i];
      if (tt == null || _dragFrom == i) continue;
      tt.cool -= dt;
      final target = _pickTarget(i % _cols);
      if (target == null) continue;
      final pos = _cellC(i);
      final d = target.pos - pos;
      tt.angle = M.approach(tt.angle, atan2(d.dy, d.dx), 16, dt);
      if (tt.cool <= 0) {
        tt.cool = 1 / _rate[tt.lv - 1];
        tt.recoil = 1;
        _fire(tt, pos, target);
      }
    }
    // bullets
    for (final s in _shots) {
      final tgt = s.target;
      final aim = tgt.dead ? s.last : tgt.pos;
      s.last = aim;
      final d = aim - s.pos;
      final dist = d.distance;
      final step = 620 * dt;
      if (dist <= step + 4) {
        s.dead = true;
        if (s.splash > 0) {
          host.fx.burst(aim, Pal.orange, count: 10, speed: 160, size: 6, colors: const [Pal.orange, Pal.yellow, Pal.white]);
          host.fx.ring(aim, Pal.orange, size: s.splash);
          host.sfx(Sfx.explodeSmall, volume: .5, rate: rand(1, 1.3));
          for (final e in _enemies) {
            if ((e.pos - aim).distance < s.splash) _damage(e, s.dmg);
          }
        } else if (!tgt.dead) {
          _damage(tgt, s.dmg);
        }
      } else {
        s.pos += d / dist * step;
      }
    }
    _shots.removeWhere((s) => s.dead);
    for (final b in _beams) {
      b.life -= dt;
    }
    _beams.removeWhere((b) => b.life <= 0);
    _enemies.removeWhere((e) => e.dead);
  }

  void _spawn(int kind) {
    final lane = randInt(4);
    const hpBase = [4.0, 2.2, 14.0, 150.0];
    const sp = [24.0, 44.0, 15.0, 11.0];
    const size = [15.0, 11.0, 21.0, 34.0];
    final hp = hpBase[kind] * (1 + host.time * .09);
    _enemies.add(_Enemy(kind, lane, Offset(kind == 3 ? 180 : _laneX[lane] + rand(-12, 12), 30), hp, sp[kind] * rand(.9, 1.1), size[kind]));
  }

  _Enemy? _pickTarget(int lane) {
    _Enemy? best;
    var by = -1e9;
    for (final e in _enemies) {
      if (e.dead || e.pos.dy < 44) continue;
      final score = e.pos.dy + (e.lane == lane || e.kind == 3 ? 200 : 0);
      if (score > by) {
        by = score;
        best = e;
      }
    }
    return best;
  }

  void _fire(_Turret tt, Offset pos, _Enemy target) {
    final lv = tt.lv;
    final muzzle = pos + Offset(cos(tt.angle), sin(tt.angle)) * 20;
    switch (lv) {
      case 4: // laser: instant beam
        _beams.add(_Beam(muzzle, target.pos, _lvCol[3], 4, .08));
        _damage(target, _dmg[3]);
        if (chance(.3)) host.sfx(Sfx.zap, volume: .35, rate: 1.4);
      case 5: // mega rail: pierces the whole line
        final dir = (target.pos - muzzle);
        final end = muzzle + dir / dir.distance * 700;
        _beams.add(_Beam(muzzle, end, _lvCol[4], 10, .22));
        for (final e in _enemies) {
          if (M.distToSegment(e.pos, muzzle, end) < e.size + 8) _damage(e, _dmg[4]);
        }
        host.sfx(Sfx.laser, rate: .7);
        host.shake(3);
        host.fx.burst(muzzle, Pal.yellow, count: 6, speed: 120, size: 4, gravity: 0);
      default:
        _shots.add(_Shot(muzzle, target, _dmg[lv - 1], lv == 3 ? 30 : 0, lv));
        host.sfx(lv == 3 ? Sfx.hitHeavy : Sfx.shoot, volume: lv == 3 ? .45 : .22, rate: lv == 1 ? 1.4 : 1.1);
    }
  }

  void _damage(_Enemy e, double d) {
    if (e.dead) return;
    e.hp -= d;
    e.hit = 1;
    e.pos -= Offset(0, e.kind == 3 ? .5 : 2.5);
    if (e.hp <= 0) {
      e.dead = true;
      final reward = [5, 4, 12, 60][e.kind];
      _coins += reward;
      _coinPop = 1;
      host.addScore(reward * 10);
      host.fx.burst(e.pos, const Color(0xFF7BD35B), count: e.kind == 3 ? 40 : 12, speed: 220, size: 6,
          colors: const [Color(0xFF7BD35B), Color(0xFF4E9E3A), Pal.white]);
      host.fx.pop('+$reward', e.pos + const Offset(0, -16), color: Pal.gold, size: 18);
      if (e.kind >= 2) host.fx.coins(e.pos, count: e.kind == 3 ? 20 : 6);
      host.sfx(e.kind == 3 ? Sfx.explode : Sfx.splat, volume: .55, rate: rand(.9, 1.2));
      if (e.kind == 3) {
        host.shake(10);
        host.hitStop(.1);
        host.flash(Pal.white);
        host.fx.pop(host.tr('ko', 'K.O.!'), e.pos + const Offset(0, -40), size: 40);
      }
    }
  }

  @override
  void onDown(Offset p) {
    if (_dead) return;
    if (_buyRect.inflate(6).contains(p)) {
      _buy();
      return;
    }
    final i = _cellAt(p);
    if (i != null && _grid[i] != null) {
      _dragFrom = i;
      _dragPos = p;
      host.sfx(Sfx.select, volume: .6);
    }
  }

  @override
  void onMove(Offset p) {
    if (_dragFrom != null) _dragPos = p;
  }

  @override
  void onUp(Offset p) {
    final from = _dragFrom;
    _dragFrom = null;
    if (from == null) return;
    final to = _cellAt(p);
    if (to == null || to == from) return;
    final a = _grid[from]!, b = _grid[to];
    if (b != null && b.lv == a.lv && a.lv < _maxLv) {
      _grid[from] = null;
      b
        ..lv += 1
        ..pop = 1;
      _merges++;
      final c = _cellC(to);
      host.sfx(Sfx.levelup, rate: .9 + b.lv * .12);
      host.sfx(Sfx.powerup, volume: .6);
      host.fx.ring(c, _lvCol[b.lv - 1], size: 60 + b.lv * 10);
      host.fx.burst(c, _lvCol[b.lv - 1], count: 14 + b.lv * 4, speed: 200 + b.lv * 30, size: 6, shape: PartShape.star,
          colors: [_lvCol[b.lv - 1], Pal.white, Pal.yellow]);
      host.fx.pop('Lv${b.lv}', c + const Offset(0, -30), color: _lvCol[b.lv - 1], size: 22 + b.lv * 3.0);
      host.punch(.01 + b.lv * .008);
      if (b.lv >= 4) {
        host.flash(D.withAlpha(_lvCol[b.lv - 1], .35));
        host.shake(4);
        host.fx.pop(host.tr('wow', 'WOW!'), const Offset(180, 330), color: Pal.yellow, size: 34);
      }
    } else {
      _grid[from] = b;
      _grid[to] = a..pop = .5;
      host.sfx(Sfx.swipe, volume: .6);
    }
  }

  @override
  void onTimeUp() {
    host.fx.confetti();
    host.sfx(Sfx.fanfare);
    host.win(stars: _wall > 70 ? 3 : (_wall > 35 ? 2 : 1));
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    // battlefield
    D.gradientBg(c, const [Color(0xFF5E8F3A), Color(0xFF7FB24A)], rect: const Rect.fromLTWH(0, 36, 360, 360));
    final tuft = D.fill(const Color(0x334A7A2A));
    for (var i = 0; i < 40; i++) {
      c.drawOval(Rect.fromLTWH((i * 53.0) % 350, 50.0 + (i * 71) % 320, 12, 5), tuft);
    }
    for (final x in _laneX) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 30, 36, 60, _wallY - 30), const Radius.circular(10)),
          D.fill(const Color(0xFFC9A36A)));
      final dash = D.fill(const Color(0x33FFFFFF));
      for (var y = 40.0 + (_t * 20) % 30; y < _wallY; y += 30) {
        c.drawRect(Rect.fromLTWH(x - 2, y, 4, 12), dash);
      }
    }
    // spawn portal glow
    c.drawRect(const Rect.fromLTWH(0, 36, 360, 22), D.fill(const Color(0x553A1060)));

    // enemies
    final sorted = [..._enemies]..sort((a, b) => a.pos.dy.compareTo(b.pos.dy));
    for (final e in sorted) {
      _drawEnemy(c, e);
    }

    // beams
    for (final b in _beams) {
      final k = b.life / b.max;
      c.drawLine(b.a, b.b, D.stroke(D.withAlpha(b.col, .5 * k), b.w * 2.2));
      c.drawLine(b.a, b.b, D.stroke(D.withAlpha(Pal.white, k), b.w * .6));
    }
    // bullets
    for (final s in _shots) {
      if (s.lv == 3) {
        D.circle(c, s.pos, 6, Pal.ink);
        c.drawCircle(s.pos + const Offset(-1.5, -1.5), 2, D.fill(Pal.white));
      } else {
        c.drawCircle(s.pos, s.lv == 1 ? 3 : 3.5, D.fill(s.lv == 1 ? Pal.yellow : Pal.lime));
        c.drawCircle(s.pos, s.lv == 1 ? 3 : 3.5, D.stroke(Pal.ink, 1.2));
      }
    }

    // wall of sandbags
    final shake = _wallHit > 0 ? sin(_t * 60) * 1.5 * _wallHit : 0.0;
    c.drawRect(const Rect.fromLTWH(0, _wallY - 2, 360, 30), D.fill(const Color(0xFF6B5A3A)));
    for (var row = 0; row < 2; row++) {
      for (var i = 0; i < 12; i++) {
        final x = i * 32.0 + (row.isOdd ? 16 : 0) - 6 + shake;
        final r = Rect.fromLTWH(x, _wallY - 6 + row * 12.0, 34, 16);
        final dmg = (1 - _wall / 100);
        final col = Color.lerp(const Color(0xFFD9C08A), const Color(0xFF8A7050), dmg)!;
        c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), D.fill(col));
        c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), D.stroke(Pal.ink, 2));
      }
    }
    // wall HP
    D.bar(c, const Rect.fromLTWH(60, 46, 240, 16), _wall / 100, _wall > 35 ? Pal.lime : Pal.red, border: Pal.ink);
    D.heart(c, const Offset(46, 54), 22, Pal.red, border: Pal.ink);
    D.text(c, '${_wall.ceil()}', const Offset(180, 54), size: 13, stroke: Pal.ink);

    // grid panel
    D.rrect(c, const Rect.fromLTWH(0, 410, 360, 230), 0, const Color(0xFF2B2F45));
    c.drawRect(const Rect.fromLTWH(0, 410, 360, 4), D.fill(const Color(0xFF1B1530)));
    for (var i = 0; i < 12; i++) {
      final cc = _cellC(i);
      final r = Rect.fromCenter(center: cc, width: _cw - 8, height: _chh - 6);
      final hover = _dragFrom != null && _cellAt(_dragPos) == i && i != _dragFrom;
      final mergeable = hover && _grid[i] != null && _grid[i]!.lv == _grid[_dragFrom!]!.lv && _grid[i]!.lv < _maxLv;
      D.rrect(c, r, 10, hover ? (mergeable ? const Color(0xFF4A7A3A) : const Color(0xFF4A4F70)) : const Color(0xFF3A3F5C),
          border: mergeable ? Pal.lime : const Color(0xFF1B1530), borderWidth: mergeable ? 3 : 2);
      // highlight same-level partners while dragging
      if (_dragFrom != null && i != _dragFrom && _grid[i]?.lv == _grid[_dragFrom!]!.lv && _grid[i]!.lv < _maxLv) {
        c.drawRRect(RRect.fromRectAndRadius(r.inflate(2 + 2 * sin(_t * 12)), const Radius.circular(12)), D.stroke(Pal.yellow, 2.5));
      }
    }
    for (var i = 0; i < 12; i++) {
      final tt = _grid[i];
      if (tt == null || i == _dragFrom) continue;
      _drawTurret(c, _cellC(i), tt, tt.angle);
    }
    if (_dragFrom != null) {
      final tt = _grid[_dragFrom!]!;
      _drawTurret(c, _dragPos + const Offset(0, -10), tt, -pi / 2, scale: 1.15);
    }

    // buy button + coins
    final canBuy = _coins >= _price && _grid.contains(null);
    final br = _buyRect.translate(0, _buyPress * 3);
    D.button(c, br, '', color: canBuy ? Pal.green : Pal.gray, pressed: _buyPress > .3);
    D.text(c, host.tr('buy', 'BUY'), br.center + const Offset(-36, -2), size: 20, stroke: Pal.ink, maxWidth: 80);
    D.coin(c, br.center + const Offset(34, -2), 11, spin: _t * .5);
    D.text(c, '$_price', br.center + const Offset(62, -2), size: 18, stroke: Pal.ink);
    // coin bank
    D.rrect(c, const Rect.fromLTWH(10, 584, 100, 40), 20, const Color(0xFF1B1530), border: Pal.gold, borderWidth: 2);
    D.coin(c, const Offset(32, 604), 12, spin: _t * .3);
    D.text(c, '$_coins', const Offset(72, 604), size: 20 + _coinPop * 6, color: Pal.gold, stroke: Pal.ink);

    // tutorial
    if (_merges == 0 && host.time < 5 && _dragFrom == null) {
      final a = _cellC(5), b = _cellC(6);
      final k = (_t * .8) % 1;
      D.hand(c, Offset.lerp(a, b, M.easeInOut(M.clamp01(k * 1.4)))!, 0);
      D.text(c, host.tr('merge', 'MERGE!'), Offset((a.dx + b.dx) / 2, a.dy - 44), size: 22, color: Pal.yellow, stroke: Pal.ink);
    } else if (_merges > 0 && _bought == 0 && host.time < 9 && canBuy) {
      D.hand(c, _buyRect.center, _t);
    }
  }

  void _drawTurret(Canvas c, Offset o, _Turret tt, double angle, {double scale = 1}) {
    final lv = tt.lv;
    final col = _lvCol[lv - 1];
    final s = scale * (1 + tt.pop * .35 * sin(tt.pop * 10));
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s);
    // base
    D.shadow(c, const Offset(0, 12), 44, 10, .35);
    if (lv >= 4) {
      c.drawCircle(Offset.zero, 22 + 2 * sin(_t * 8), D.fill(D.withAlpha(col, .25)));
    }
    D.rrect(c, const Rect.fromLTWH(-19, -6, 38, 20), 8, Color.lerp(col, Pal.ink, .35)!, border: Pal.ink, borderWidth: 2.5);
    D.circle(c, const Offset(0, 0), 14, col, border: Pal.ink, borderWidth: 2.5);
    // barrel
    c.save();
    c.rotate(angle);
    c.translate(-tt.recoil * 4, 0);
    const steel = Color(0xFF5B6275);
    switch (lv) {
      case 1:
        D.rrect(c, const Rect.fromLTWH(2, -3.5, 18, 7), 3, steel, border: Pal.ink, borderWidth: 2);
      case 2:
        D.rrect(c, const Rect.fromLTWH(2, -3, 28, 6), 3, steel, border: Pal.ink, borderWidth: 2);
        D.rrect(c, const Rect.fromLTWH(6, -9, 12, 5), 2, Pal.ink);
      case 3:
        D.rrect(c, const Rect.fromLTWH(0, -8, 26, 16), 6, const Color(0xFF3A3F5C), border: Pal.ink, borderWidth: 2.5);
        D.rrect(c, const Rect.fromLTWH(22, -9, 6, 18), 2, steel, border: Pal.ink, borderWidth: 2);
      case 4:
        D.rrect(c, const Rect.fromLTWH(0, -5, 24, 10), 4, const Color(0xFF3A2A60), border: Pal.ink, borderWidth: 2);
        D.gem(c, const Offset(28, 0), 7, const Color(0xFFD08CFF));
      default:
        for (final y in const [-6.0, 6.0]) {
          D.rrect(c, Rect.fromLTWH(-2, y - 3, 38, 6), 2, const Color(0xFFE8E8F0), border: Pal.ink, borderWidth: 2);
        }
        final zap = Path()..moveTo(4, 0);
        for (var i = 1; i < 6; i++) {
          zap.lineTo(4 + i * 6.0, (i.isEven ? -3 : 3) * sin(_t * 30 + i));
        }
        c.drawPath(zap, D.stroke(const Color(0xFF7FE8FF), 2));
    }
    c.restore();
    // level stars
    if (lv == _maxLv) D.star(c, const Offset(0, 0), 7, Pal.white, border: Pal.ink);
    // level badge
    D.circle(c, const Offset(16, 10), 8, Pal.white, border: Pal.ink, borderWidth: 2);
    D.text(c, '$lv', const Offset(16, 10), size: 11, color: Pal.ink);
    c.restore();
  }

  void _drawEnemy(Canvas c, _Enemy e) {
    final bob = sin(e.anim * 8) * 2;
    final col = [const Color(0xFF7BD35B), const Color(0xFFFF6A6A), const Color(0xFF8E9AAF), const Color(0xFF9B4DFF)][e.kind];
    final draw = e.hit > .5 ? Pal.white : col;
    final atWall = e.pos.dy >= _wallY - e.size * .7 - 1;
    D.shadow(c, e.pos + Offset(0, e.size * .9), e.size * 1.8, e.size * .5, .3);
    // arms reaching
    final arm = D.stroke(Color.lerp(col, Pal.ink, .2)!, e.size * .28);
    final reach = atWall ? sin(e.anim * 14) * 4 : 0.0;
    c.drawLine(e.pos + Offset(-e.size * .7, 0), e.pos + Offset(-e.size * .8, e.size * .9 + reach), arm);
    c.drawLine(e.pos + Offset(e.size * .7, 0), e.pos + Offset(e.size * .8, e.size * .9 - reach), arm);
    D.blob(c, e.pos + Offset(0, bob), e.size, draw,
        face: e.hit > .5 ? Face.shocked : (atWall ? Face.angry : (e.kind == 1 ? Face.smug : Face.angry)),
        look: const Offset(0, 1), squash: 1 + (atWall ? .06 * sin(e.anim * 14) : 0));
    if (e.kind == 2) {
      c.drawArc(Rect.fromCircle(center: e.pos + Offset(0, bob - e.size * .3), radius: e.size * .95), pi, pi, true,
          D.fill(const Color(0xFF5B6275)));
      c.drawArc(Rect.fromCircle(center: e.pos + Offset(0, bob - e.size * .3), radius: e.size * .95), pi, pi, true,
          D.stroke(Pal.ink, 2));
    }
    if (e.kind == 3) {
      final cp = e.pos + Offset(0, bob - e.size * 1.05);
      final crown = Path()
        ..moveTo(cp.dx - 14, cp.dy + 6)
        ..lineTo(cp.dx - 14, cp.dy - 8)
        ..lineTo(cp.dx - 7, cp.dy - 1)
        ..lineTo(cp.dx, cp.dy - 11)
        ..lineTo(cp.dx + 7, cp.dy - 1)
        ..lineTo(cp.dx + 14, cp.dy - 8)
        ..lineTo(cp.dx + 14, cp.dy + 6)
        ..close();
      c.drawPath(crown, D.fill(Pal.gold));
      c.drawPath(crown, D.stroke(Pal.ink, 2));
    }
    // hp bar
    if (e.hp < e.maxHp) {
      final w = e.size * 2;
      D.bar(c, Rect.fromLTWH(e.pos.dx - w / 2, e.pos.dy - e.size - 12, w, 5), e.hp / e.maxHp, Pal.red);
    }
  }
}

class _Turret {
  _Turret(this.lv);
  int lv;
  double cool = 0;
  double angle = -pi / 2;
  double pop = 0;
  double recoil = 0;
}

class _Enemy {
  _Enemy(this.kind, this.lane, this.pos, this.hp, this.speed, this.size) : maxHp = hp;
  final int kind; // 0 walker, 1 runner, 2 tank, 3 boss
  final int lane;
  Offset pos;
  double hp;
  final double maxHp;
  final double speed;
  final double size;
  double anim = 0;
  double hit = 0;
  double biting = 0;
  bool dead = false;
}

class _Shot {
  _Shot(this.pos, this.target, this.dmg, this.splash, this.lv) : last = target.pos;
  Offset pos;
  final _Enemy target;
  final double dmg;
  final double splash;
  final int lv;
  Offset last;
  bool dead = false;
}

class _Beam {
  _Beam(this.a, this.b, this.col, this.w, this.max) : life = max;
  final Offset a, b;
  final Color col;
  final double w;
  final double max;
  double life;
}
