import 'dart:typed_data';

import '../engine/engine.dart';

/// No.124 Survivor Horde — Vampire Survivors / Survivor.io parody.
///
/// Drag anywhere = virtual joystick. Weapons fire on their own. Hundreds of
/// monsters swarm in; they drop XP gems that get vacuumed up. Every level-up
/// pauses the action and offers 3 upgrade cards. A Demon King arrives near the
/// end — kill it for the big win (just surviving the timer is a 1-star win).
class G124 extends MiniGame {
  // ------------------------------------------------------------ world state
  double _t = 0; // render time
  double _st = 0; // simulation time (frozen while picking cards)
  double _hx = 0, _hy = 0; // hero world pos
  double _faceX = 1;
  double _walk = 0;
  double _hp = 100, _maxHp = 100;
  double _hurtT = 0;
  bool _dead = false;
  double _deadT = 0;

  final List<_En> _en = [];
  final List<_Gem> _gems = [];
  final List<_Shot> _shots = [];
  final List<_Num> _nums = [];
  final List<_Zap> _zaps = [];
  _Boss? _boss;
  bool _bossSpawned = false;
  double _bossWarn = 0;
  Offset? _magnetItem;
  bool _magnetSpawned = false;
  bool _ringDone = false;
  double _spawnAcc = 0;
  int _kills = 0;
  double _killPunch = 0;

  // ----------------------------------------------------------- progression
  int _level = 1;
  double _xp = 0;
  int _pending = 0;
  List<int>? _cards;
  double _cardT = 0;
  double _cardDelay = 0;
  int _picked = -1;
  double _pickedT = 0;
  final Map<int, int> _lv = {0: 1, 1: 0, 2: 1, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
  double _might = 1;
  double _speedMul = 1;
  double _magnet = 84;

  // weapon timers
  double _boltCd = 0;
  double _auraCd = 0;
  double _thunderCd = 1.2;
  double _bookAng = 0;

  // ----------------------------------------------------------------- input
  Offset? _joyBase;
  Offset _joyKnob = Offset.zero;
  final Set<String> _keys = {};

  // --------------------------------------------------------------- effects
  double _sndHit = 0, _sndGem = 0, _sndKill = 0;
  double _gemPitch = 1;
  double _gemPitchT = 0;
  double _danger = 0;

  // spatial grid for crowd separation
  static const _gc = 26.0;
  static const _gw = 24, _gh = 34;
  final Int32List _head = Int32List(_gw * _gh);
  final Int32List _next = Int32List(_maxEn);
  static const _maxEn = 460;

  static const _heroScreen = Offset(180, 372);

  // ---------------------------------------------------------------- stats
  int get _boltCount => min(2 + _lv[0]! ~/ 2, 5);
  double get _boltDmg => 120 * pow(1.3, _lv[0]! - 1) * _might;
  double get _boltRate => .5 - _lv[0]! * .05;
  int get _bookCount => _lv[1]! == 0 ? 0 : _lv[1]! + 1;
  double get _bookDmg => 90 * pow(1.3, max(0, _lv[1]! - 1)) * _might;
  double get _bookR => 62 + _lv[1]! * 4;
  double get _auraR => _lv[2]! == 0 ? 0 : 44 + _lv[2]! * 9;
  double get _auraDmg => 55 * pow(1.3, max(0, _lv[2]! - 1)) * _might;
  double get _thunderDmg => 260 * pow(1.3, max(0, _lv[3]! - 1)) * _might;
  double get _thunderRate => 1.15 - _lv[3]! * .12;
  double get _heroSpeed => 118 * _speedMul;
  double get _xpNeed => 3.0 + _level * 2.4;

  @override
  void init() {
    _spawnWave(14, 230);
  }

  // =================================================================== update
  @override
  void update(double dt) {
    _t += dt;
    _killPunch = M.approach(_killPunch, 0, 8, dt);
    _sndHit -= dt;
    _sndGem -= dt;
    _sndKill -= dt;
    _gemPitchT -= dt;
    if (_gemPitchT <= 0) _gemPitch = M.approach(_gemPitch, 1, 3, dt);
    _bossWarn = max(0, _bossWarn - dt);
    for (final n in _nums) {
      n.life -= dt;
      n.y -= 38 * dt;
    }
    _nums.removeWhere((n) => n.life <= 0);
    for (final z in _zaps) {
      z.life -= dt;
    }
    _zaps.removeWhere((z) => z.life <= 0);

    // ---- level-up card screen (simulation paused) ----
    if (_cards != null) {
      _cardT += dt;
      if (_picked >= 0) {
        _pickedT += dt;
        if (_pickedT > .45) {
          _cards = null;
          _picked = -1;
          _cardDelay = .25;
        }
      } else if (_cardT > 3.2 && !host.finished) {
        _choose(0); // auto-pick the (highlighted) first card
      }
      return;
    }
    if (_pending > 0 && !_dead && !host.finished) {
      _cardDelay -= dt;
      if (_cardDelay <= 0) {
        _openCards();
        return;
      }
    }

    _st += dt;
    _hurtT = max(0, _hurtT - dt);
    if (!_dead) _hp = min(_maxHp, _hp + 2.5 * dt);
    if (_dead) {
      _deadT += dt;
    }

    // ---- hero movement ----
    var mv = Offset.zero;
    if (_joyBase != null) {
      final d = _joyKnob - _joyBase!;
      final l = d.distance;
      if (l > 4) mv = d / l * min(1.0, l / 42);
    }
    if (_keys.isNotEmpty) {
      var k = Offset((_keys.contains('right') ? 1 : 0) - (_keys.contains('left') ? 1 : 0).toDouble(),
          (_keys.contains('down') ? 1 : 0) - (_keys.contains('up') ? 1 : 0).toDouble());
      if (k.distance > 0) {
        k = k / k.distance;
        mv = k;
      }
    }
    if (!_dead && !host.finished) {
      _hx += mv.dx * _heroSpeed * dt;
      _hy += mv.dy * _heroSpeed * dt;
      if (mv.dx.abs() > .1) _faceX = mv.dx.sign;
      _walk += mv.distance * dt * 14;
    }

    // ---- spawning ----
    if (!host.finished && !_dead) {
      final rate = (_st < 3
              ? 9.0
              : _st < 7
                  ? 20.0
                  : _st < 13
                      ? 32.0
                      : (_boss != null ? 22.0 : 42.0)) *
          host.speed;
      _spawnAcc += rate * dt;
      while (_spawnAcc >= 1) {
        _spawnAcc -= 1;
        _spawnOne();
      }
      if (!_ringDone && _st > 7.2) {
        _ringDone = true;
        _spawnRing(64);
        host.fx.pop(host.tr('danger', 'DANGER!'), const Offset(180, 200), color: Pal.red, size: 34, life: 1.2);
        host.sfx(Sfx.horror, volume: .8);
        host.shake(4);
      }
      if (!_magnetSpawned && _st > 8.5) {
        _magnetSpawned = true;
        final a = rand(0, pi * 2);
        _magnetItem = Offset(_hx + cos(a) * 95, _hy + sin(a) * 95);
      }
      if (!_bossSpawned && host.time > 13.5) {
        _bossSpawned = true;
        _bossWarn = 2.2;
        host.sfx(Sfx.horror);
        host.sfx(Sfx.heartbeat);
        host.flash(const Color(0x88FF0000), .3);
        _boss = _Boss(_hx, _hy - 420, _bossHp());
      }
    }

    _updateWeapons(dt);
    _updateEnemies(dt);
    _updateBoss(dt);
    _updateGems(dt);

    // ---- magnet pickup: vacuum ALL gems ----
    final mi = _magnetItem;
    if (mi != null && !_dead) {
      if ((mi - Offset(_hx, _hy)).distance < 22) {
        _magnetItem = null;
        for (final g in _gems) {
          g.pulled = true;
        }
        host.sfx(Sfx.magic);
        host.sfx(Sfx.whoosh, rate: .8);
        host.flash(const Color(0x553FB8FF));
        host.fx.ring(_heroScreen, Pal.sky, size: 260, life: .5);
        host.fx.pop(host.tr('magnet', 'Magnet'), _heroScreen - const Offset(0, 70), color: Pal.sky, size: 30);
      }
    }

    // danger vignette
    _danger = M.approach(_danger, _hp < _maxHp * .35 && !_dead ? 1 : 0, 4, dt);

    // death
    if (!_dead && _hp <= 0 && !host.finished) {
      _dead = true;
      _hp = 0;
      host.sfx(Sfx.jingleLose);
      host.sfx(Sfx.explode);
      host.shake(12);
      host.flash(Pal.red, .3);
      host.fx.burst(_heroScreen, Pal.red, count: 30, speed: 260);
      host.lose();
    }
  }

  double _bossHp() {
    // Single-target DPS estimate so the boss always takes ~5.5 s of focus.
    final bolt = _boltDmg * ((_boltCount + 1) ~/ 2) / _boltRate * 1.3;
    final book = _bookCount * _bookDmg * 1.2;
    final aura = _lv[2]! > 0 ? _auraDmg / .3 : 0;
    final thunder = _lv[3]! > 0 ? _thunderDmg / _thunderRate * .5 : 0;
    return max(3000.0, (bolt + .3 * (book + aura) + thunder) * 6.0);
  }

  void _spawnOne() {
    if (_en.length >= _maxEn) return;
    final a = rand(0, pi * 2);
    final x = _hx + cos(a) * rand(240, 280);
    final y = _hy + sin(a) * rand(390, 430);
    var type = 0;
    if (_st > 3 && chance(.28)) type = 1;
    if (_st > 6.5 && chance(.09)) type = 2;
    _addEnemy(x, y, type);
  }

  void _spawnRing(int n) {
    for (var i = 0; i < n; i++) {
      final a = i / n * pi * 2;
      _addEnemy(_hx + cos(a) * 250, _hy + sin(a) * 330, 0);
    }
  }

  void _spawnWave(int n, double r) {
    for (var i = 0; i < n; i++) {
      final a = rand(0, pi * 2);
      _addEnemy(_hx + cos(a) * r * 1.0, _hy + sin(a) * r * 1.5, 0);
    }
  }

  void _addEnemy(double x, double y, int type) {
    if (_en.length >= _maxEn) return;
    final hpMul = pow(1.075, _st).toDouble();
    const baseHp = [100.0, 70.0, 900.0];
    const spd = [40.0, 66.0, 30.0];
    const rad = [9.0, 7.5, 15.0];
    final e = _En()
      ..x = x
      ..y = y
      ..type = type
      ..hp = baseHp[type] * hpMul
      ..spd = spd[type] * rand(.85, 1.15) * (1 + _st * .012) * host.speed
      ..r = rad[type]
      ..phase = rand(0, 10);
    e.maxHp = e.hp;
    _en.add(e);
  }

  // ------------------------------------------------------------- weapons --
  void _updateWeapons(double dt) {
    if (_dead || host.finished) {
      // projectiles still fly for the ending
    } else {
      // magic bolts at nearest enemies
      _boltCd -= dt;
      if (_boltCd <= 0) {
        _boltCd = _boltRate;
        final targets = _nearest(_boltCount);
        final b = _boss;
        Offset? bossPos;
        if (b != null && !b.dead && (Offset(b.x, b.y) - Offset(_hx, _hy)).distance < 360) {
          bossPos = Offset(b.x, b.y);
          if (targets.isEmpty) targets.add(bossPos);
          for (var i = 0; i < targets.length; i += 2) {
            targets[i] = bossPos;
          }
        }
        for (final tg in targets) {
          final d = tg - Offset(_hx, _hy);
          final l = max(1.0, d.distance);
          _shots.add(_Shot()
            ..x = _hx
            ..y = _hy - 6
            ..vx = d.dx / l * 430
            ..vy = d.dy / l * 430
            ..life = 1.1
            ..pierce = tg == bossPos ? 999 : (_lv[0]! >= 3 ? 2 : 1));
        }
        if (targets.isNotEmpty) host.sfx(Sfx.laser, volume: .25, rate: rand(1.3, 1.6));
      }
      // aura
      if (_lv[2]! > 0) {
        _auraCd -= dt;
        if (_auraCd <= 0) {
          _auraCd = .3;
          final r = _auraR;
          for (final e in _en) {
            final dx = e.x - _hx, dy = e.y - _hy;
            if (dx * dx + dy * dy < (r + e.r) * (r + e.r)) {
              _damage(e, _auraDmg, show: chance(.35));
              final l = max(1.0, sqrt(dx * dx + dy * dy));
              e.kx += dx / l * 90;
              e.ky += dy / l * 90;
            }
          }
          final b = _boss;
          if (b != null && !b.dead && (Offset(b.x, b.y) - Offset(_hx, _hy)).distance < r + 40) _damageBoss(_auraDmg);
        }
      }
      // thunder
      if (_lv[3]! > 0) {
        _thunderCd -= dt;
        if (_thunderCd <= 0) {
          _thunderCd = _thunderRate;
          final strikes = _lv[3]!;
          for (var s = 0; s < strikes; s++) {
            Offset? tgt;
            final b = _boss;
            if (b != null && !b.dead && s == 0 && chance(.6)) {
              tgt = Offset(b.x, b.y);
            } else if (_en.isNotEmpty) {
              for (var tries = 0; tries < 6; tries++) {
                final e = _en[randInt(_en.length)];
                if ((e.x - _hx).abs() < 170 && (e.y - _hy).abs() < 300) {
                  tgt = Offset(e.x, e.y);
                  break;
                }
              }
            }
            if (tgt != null) _strike(tgt);
          }
        }
      }
    }
    // books orbit
    _bookAng += dt * 3.6;
    final nb = _bookCount;
    if (nb > 0 && !_dead) {
      final r = _bookR;
      for (var i = 0; i < nb; i++) {
        final a = _bookAng + i / nb * pi * 2;
        final bx = _hx + cos(a) * r, by = _hy + sin(a) * r;
        for (final e in _en) {
          if (e.bookCd > 0) continue;
          final dx = e.x - bx, dy = e.y - by;
          if (dx * dx + dy * dy < (e.r + 13) * (e.r + 13)) {
            e.bookCd = .45;
            _damage(e, _bookDmg);
            final l = max(1.0, sqrt(dx * dx + dy * dy));
            e.kx += dx / l * 160;
            e.ky += dy / l * 160;
          }
        }
        final b = _boss;
        if (b != null && !b.dead && b.bookCd <= 0 && (Offset(b.x, b.y) - Offset(bx, by)).distance < 48) {
          b.bookCd = .3;
          _damageBoss(_bookDmg);
        }
      }
    }
    // bolts travel
    for (final s in _shots) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
      if (s.life <= 0) continue;
      final b = _boss;
      if (b != null && !b.dead) {
        final dx = b.x - s.x, dy = b.y - s.y;
        if (dx * dx + dy * dy < 44 * 44) {
          _damageBoss(_boltDmg, crit: chance(.2));
          s.life = 0;
          continue;
        }
      }
      for (final e in _en) {
        if (e.hp <= 0) continue;
        final dx = e.x - s.x, dy = e.y - s.y;
        if (dx * dx + dy * dy < (e.r + 6) * (e.r + 6)) {
          final crit = chance(.18);
          _damage(e, _boltDmg * (crit ? 2.5 : 1), crit: crit);
          e.kx += s.vx * .15;
          e.ky += s.vy * .15;
          s.pierce--;
          if (s.pierce <= 0) {
            s.life = 0;
            break;
          }
        }
      }
    }
    _shots.removeWhere((s) => s.life <= 0);
  }

  void _strike(Offset tgt) {
    final pts = <Offset>[];
    var y = tgt.dy - 320;
    var x = tgt.dx + rand(-30, 30);
    while (y < tgt.dy) {
      pts.add(Offset(x, y));
      y += rand(24, 44);
      x += rand(-18, 18);
    }
    pts.add(tgt);
    _zaps.add(_Zap(pts, tgt));
    for (final e in _en) {
      final dx = e.x - tgt.dx, dy = e.y - tgt.dy;
      if (dx * dx + dy * dy < 46 * 46) _damage(e, _thunderDmg, show: dx * dx + dy * dy < 100);
    }
    final b = _boss;
    if (b != null && !b.dead && (Offset(b.x, b.y) - tgt).distance < 50) _damageBoss(_thunderDmg, crit: true);
    host.sfx(Sfx.zap, volume: .5, rate: rand(.9, 1.2));
    host.fx.burst(_toScreen(tgt), Pal.yellow, count: 8, speed: 180, gravity: 0, life: .3, shape: PartShape.spark);
  }

  List<Offset> _nearest(int n) {
    // n nearest living enemies inside the screen (simple partial selection).
    final best = <_En>[];
    final bd = <double>[];
    for (final e in _en) {
      if (e.hp <= 0) continue;
      final dx = e.x - _hx, dy = e.y - _hy;
      if (dx.abs() > 200 || dy.abs() > 330) continue;
      final d = dx * dx + dy * dy;
      if (best.length < n) {
        best.add(e);
        bd.add(d);
      } else {
        var wi = 0;
        for (var i = 1; i < bd.length; i++) {
          if (bd[i] > bd[wi]) wi = i;
        }
        if (d < bd[wi]) {
          best[wi] = e;
          bd[wi] = d;
        }
      }
    }
    return [for (final e in best) Offset(e.x, e.y)];
  }

  void _damage(_En e, double dmg, {bool crit = false, bool show = true}) {
    if (e.hp <= 0) return;
    e.hp -= dmg;
    e.flash = .09;
    if (show) _addNum(e.x, e.y - e.r, dmg, crit);
    if (_sndHit <= 0) {
      _sndHit = .045;
      host.sfx(Sfx.hit, volume: .3, rate: rand(1.1, 1.5));
    }
    if (e.hp <= 0) _kill(e);
  }

  void _kill(_En e) {
    _kills++;
    _killPunch = 1;
    const cols = [Color(0xFF7BD85A), Color(0xFFB57BFF), Color(0xFFFF6A4D)];
    if (_toScreenInside(e.x, e.y)) {
      host.fx.burst(_toScreen(Offset(e.x, e.y)), cols[e.type], count: e.type == 2 ? 12 : 4, speed: 130, gravity: 0, life: .35, size: 4);
    }
    if (_gems.length < 320) {
      _gems.add(_Gem()
        ..x = e.x
        ..y = e.y
        ..v = e.type == 2 ? 8 : 1
        ..pulled = _magnetItem == null && _magnetSpawned && _st < 11);
    }
    if (_sndKill <= 0) {
      _sndKill = .06;
      host.sfx(Sfx.pop, volume: .35, rate: rand(.8, 1.3));
    }
    if (e.type == 2) {
      host.shake(3);
      host.sfx(Sfx.explodeSmall, volume: .6);
    }
  }

  void _damageBoss(double dmg, {bool crit = false}) {
    final b = _boss;
    if (b == null || b.dead) return;
    final d = crit ? dmg * 2.5 : dmg;
    b.hp -= d;
    b.flash = .08;
    _addNum(b.x + rand(-20, 20), b.y - 40, d, crit || d > _boltDmg * 2);
    if (_sndHit <= 0) {
      _sndHit = .05;
      host.sfx(Sfx.hitHeavy, volume: .45, rate: rand(.9, 1.2));
    }
    if (b.hp <= 0 && !host.finished && !_dead) {
      b.dead = true;
      _bossDeath();
    }
  }

  void _bossDeath() {
    final b = _boss!;
    final sp = _toScreen(Offset(b.x, b.y));
    host.hitStop(.25);
    host.shake(16, .6);
    host.flash(Pal.white, .35);
    host.sfx(Sfx.explode);
    host.sfx(Sfx.fanfare);
    host.fx.burst(sp, Pal.purple, count: 50, speed: 420, size: 9, gravity: 100);
    host.fx.ring(sp, Pal.yellow, size: 300, life: .6);
    host.fx.coins(sp, count: 30, speed: 520);
    host.fx.confetti();
    // screen-clearing chain reaction: every monster pops
    final n = _en.length;
    for (final e in _en) {
      if (e.hp > 0) _kill(e);
      e.hp = 0;
    }
    host.fx.pop('x$n ${host.tr('ko', 'KO!')}', const Offset(180, 250), color: Pal.yellow, size: 38, life: 1.4);
    host.fx.pop(host.tr('win', 'WIN!'), const Offset(180, 300), color: Pal.white, size: 30, life: 1.4);
    host.win(stars: _hp > _maxHp * .5 ? 3 : 2);
  }

  void _addNum(double x, double y, double v, bool crit) {
    if (_nums.length >= 40) {
      if (!crit) return;
      _nums.removeAt(0);
    }
    _nums.add(_Num()
      ..x = x + rand(-6, 6)
      ..y = y
      ..s = M.big(v.round() < 10000 ? (v / 10).round() * 10 : v)
      ..crit = crit
      ..life = crit ? .75 : .5);
  }

  // ------------------------------------------------------------- enemies --
  void _updateEnemies(double dt) {
    // bucket into grid around the hero
    _head.fillRange(0, _head.length, -1);
    const ox = _gw * _gc / 2, oy = _gh * _gc / 2;
    for (var i = 0; i < _en.length; i++) {
      final e = _en[i];
      final cx = ((e.x - _hx + ox) / _gc).floor();
      final cy = ((e.y - _hy + oy) / _gc).floor();
      if (cx < 0 || cy < 0 || cx >= _gw || cy >= _gh) {
        e.cell = -1;
        continue;
      }
      final cell = cy * _gw + cx;
      e.cell = cell;
      _next[i] = _head[cell];
      _head[cell] = i;
    }
    // separation
    for (var i = 0; i < _en.length; i++) {
      final a = _en[i];
      if (a.cell < 0) continue;
      final cx = a.cell % _gw, cy = a.cell ~/ _gw;
      for (var yy = cy - 1; yy <= cy + 1; yy++) {
        if (yy < 0 || yy >= _gh) continue;
        for (var xx = cx - 1; xx <= cx + 1; xx++) {
          if (xx < 0 || xx >= _gw) continue;
          var j = _head[yy * _gw + xx];
          while (j >= 0) {
            if (j > i) {
              final b = _en[j];
              final dx = b.x - a.x, dy = b.y - a.y;
              final rr = (a.r + b.r) * .92;
              final d2 = dx * dx + dy * dy;
              if (d2 < rr * rr && d2 > .0001) {
                final d = sqrt(d2);
                final push = (rr - d) * .5 / d;
                a.x -= dx * push;
                a.y -= dy * push;
                b.x += dx * push;
                b.y += dy * push;
              }
            }
            j = _next[j];
          }
        }
      }
    }
    // chase + contact damage
    var contactDps = 0.0;
    const heroR = 13.0;
    for (final e in _en) {
      e.flash = max(0, e.flash - dt);
      e.bookCd = max(0, e.bookCd - dt);
      final dx = _hx - e.x, dy = _hy - e.y;
      final d = sqrt(dx * dx + dy * dy);
      if (d > 1) {
        final wob = e.type == 1 ? sin(_t * 7 + e.phase) * .6 : 0.0;
        final nx = dx / d, ny = dy / d;
        final sp = _dead ? e.spd * .4 : e.spd;
        e.x += (nx - ny * wob) * sp * dt + e.kx * dt;
        e.y += (ny + nx * wob) * sp * dt + e.ky * dt;
      }
      e.kx *= max(0, 1 - dt * 8);
      e.ky *= max(0, 1 - dt * 8);
      final minD = heroR + e.r;
      if (!_dead && d < minD && d > .01) {
        e.x = _hx - dx / d * minD;
        e.y = _hy - dy / d * minD;
        contactDps += const [4.0, 3.0, 10.0][e.type];
      }
      // far-away stragglers teleport back into the fight (the horde never ends)
      if (d > 520) {
        final a = rand(0, pi * 2);
        e.x = _hx + cos(a) * 260;
        e.y = _hy + sin(a) * 410;
      }
    }
    _en.removeWhere((e) => e.hp <= 0);
    if (!_dead && !host.finished && contactDps > 0) {
      _hp -= min(contactDps, 40) * dt;
      if (_hurtT <= 0) {
        _hurtT = .35;
        host.sfx(Sfx.hurt, volume: .4, rate: rand(.9, 1.1));
        host.shake(2.5, .12);
      }
    }
  }

  void _updateBoss(double dt) {
    final b = _boss;
    if (b == null) return;
    b.flash = max(0, b.flash - dt);
    b.bookCd = max(0, b.bookCd - dt);
    b.anim += dt;
    if (b.dead) return;
    final dx = _hx - b.x, dy = _hy - b.y;
    final d = max(1.0, sqrt(dx * dx + dy * dy));
    b.dashT -= dt;
    if (b.state == 0) {
      final sp = (d > 300 ? 150.0 : 48.0) * host.speed;
      b.x += dx / d * sp * dt;
      b.y += dy / d * sp * dt;
      if (b.dashT <= 0 && d < 260) {
        b.state = 1;
        b.dashT = .7;
        b.dir = Offset(dx / d, dy / d);
        host.sfx(Sfx.shake, volume: .6);
      }
    } else if (b.state == 1) {
      // telegraph
      if (b.dashT <= 0) {
        b.state = 2;
        b.dashT = .45;
        host.sfx(Sfx.whoosh);
      }
    } else {
      b.x += b.dir.dx * 360 * host.speed * dt;
      b.y += b.dir.dy * 360 * host.speed * dt;
      if (b.dashT <= 0) {
        b.state = 0;
        b.dashT = 2.6;
      }
    }
    if (!_dead && !host.finished && d < 13 + 36) {
      _hp -= 40 * dt;
      if (_hurtT <= 0) {
        _hurtT = .3;
        host.sfx(Sfx.hurt, volume: .6);
        host.shake(5);
      }
      _hx = b.x + dx / d * 49;
      _hy = b.y + dy / d * 49;
    }
  }

  void _updateGems(double dt) {
    for (final g in _gems) {
      final dx = _hx - g.x, dy = _hy - g.y;
      final d2 = dx * dx + dy * dy;
      if (!g.pulled && d2 < _magnet * _magnet) g.pulled = true;
      if (g.pulled && !_dead) {
        final d = max(1.0, sqrt(d2));
        g.sp = min(900, g.sp + 1400 * dt);
        g.x += dx / d * g.sp * dt;
        g.y += dy / d * g.sp * dt;
        if (d < 14) {
          g.v = -g.v; // collected marker
          _xp += -g.v;
          if (_sndGem <= 0) {
            _sndGem = .035;
            host.sfx(Sfx.gem, volume: .3, rate: _gemPitch);
            _gemPitch = min(2.2, _gemPitch + .04);
            _gemPitchT = .4;
          }
        }
      }
    }
    _gems.removeWhere((g) => g.v < 0);
    while (_xp >= _xpNeed) {
      _xp -= _xpNeed;
      _level++;
      _pending++;
      _cardDelay = .1;
    }
  }

  // -------------------------------------------------------------- cards --
  bool _canPick(int id) {
    if (id <= 3) return _lv[id]! < 5;
    return true;
  }

  void _openCards() {
    final pool = [for (var i = 0; i < 8; i++) if (_canPick(i)) i];
    // Weapons you don't own yet are more likely (they're the fun part).
    final weighted = <int>[];
    for (final id in pool) {
      final w = id <= 3 && _lv[id] == 0 ? 4 : (id <= 3 ? 2 : 1);
      for (var k = 0; k < w; k++) {
        weighted.add(id);
      }
    }
    final cards = <int>[];
    while (cards.length < 3 && weighted.isNotEmpty) {
      final id = pick(weighted);
      cards.add(id);
      weighted.removeWhere((x) => x == id);
    }
    if (_hp < _maxHp * .4 && !cards.contains(7)) cards[cards.length - 1] = 7;
    _cards = cards;
    _cardT = 0;
    _picked = -1;
    _joyBase = null;
    host.sfx(Sfx.levelup);
    host.flash(const Color(0x66FFD23F));
  }

  void _choose(int i) {
    final cards = _cards;
    if (cards == null || _picked >= 0 || i >= cards.length) return;
    _picked = i;
    _pickedT = 0;
    _pending--;
    final id = cards[i];
    switch (id) {
      case 0 || 1 || 2 || 3:
        _lv[id] = _lv[id]! + 1;
      case 4:
        _might *= 1.5;
        _lv[4] = _lv[4]! + 1;
      case 5:
        _speedMul += .18;
        _lv[5] = _lv[5]! + 1;
      case 6:
        _magnet += 45;
        _lv[6] = _lv[6]! + 1;
      case 7:
        _maxHp += 30;
        _hp = _maxHp;
        _lv[7] = _lv[7]! + 1;
    }
    host.sfx(Sfx.powerup);
    host.sfx(Sfx.sparkle, volume: .6);
    host.punch(.05);
    final r = _cardRect(i);
    host.fx.burst(r.center, Pal.yellow, count: 26, speed: 300, shape: PartShape.star, gravity: 200);
    host.fx.ring(r.center, Pal.white, size: 120);
  }

  Rect _cardRect(int i) => Rect.fromLTWH(14 + i * 114.0, 250, 104, 168);

  // ---------------------------------------------------------------- input --
  @override
  void onDown(Offset p) {
    if (_cards != null) {
      if (_cardT < .35) return;
      for (var i = 0; i < _cards!.length; i++) {
        if (_cardRect(i).inflate(6).contains(p)) {
          _choose(i);
          return;
        }
      }
      return;
    }
    _joyBase = p;
    _joyKnob = p;
  }

  @override
  void onMove(Offset p) {
    if (_joyBase == null) return;
    final d = p - _joyBase!;
    if (d.distance > 60) _joyBase = p - d / d.distance * 60; // base follows the thumb
    _joyKnob = p;
  }

  @override
  void onUp(Offset p) => _joyBase = null;

  @override
  void onKey(String key, bool down) {
    if (_cards != null) {
      if (down && key == 'action') _choose(0);
      if (down && key == 'left') _choose(0);
      if (down && key == 'up') _choose(1);
      if (down && key == 'right') _choose(2);
      return;
    }
    if (down) {
      _keys.add(key);
    } else {
      _keys.remove(key);
    }
  }

  @override
  void onTimeUp() {
    if (_dead) {
      host.lose();
    } else {
      host.fx.pop(host.tr('clear', 'CLEAR!'), const Offset(180, 260), color: Pal.yellow, size: 34);
      host.sfx(Sfx.cheer);
      host.win(stars: 1);
    }
  }

  // --------------------------------------------------------------- render --
  Offset _toScreen(Offset w) => Offset(w.dx - _hx + _heroScreen.dx, w.dy - _hy + _heroScreen.dy);
  bool _toScreenInside(double x, double y) => (x - _hx).abs() < 200 && (y - _hy).abs() < 390;

  @override
  void render(Canvas c) {
    _renderGround(c);
    c.save();
    c.translate(_heroScreen.dx - _hx, _heroScreen.dy - _hy);
    _renderAura(c);
    _renderGems(c);
    final mi = _magnetItem;
    if (mi != null) _drawMagnet(c, mi + Offset(0, sin(_t * 5) * 4), 14, glow: true);
    _renderEnemies(c);
    _renderBoss(c);
    _renderHero(c);
    _renderShots(c);
    _renderBooks(c);
    _renderZaps(c);
    _renderNums(c);
    c.restore();
    _renderHud(c);
    if (_cards != null) _renderCards(c);
  }

  void _renderGround(Canvas c) {
    D.gradientBg(c, const [Color(0xFF3E7D3A), Color(0xFF2C5F2E)]);
    const cell = 64.0;
    final ox = _hx - _heroScreen.dx, oy = _hy - _heroScreen.dy;
    final ix0 = (ox / cell).floor(), iy0 = (oy / cell).floor();
    final dark = Paint()..color = const Color(0x16000000);
    final tuft = Paint()..color = const Color(0xFF5FA24A);
    final flowerA = Paint()..color = const Color(0xFFFFE070);
    final flowerB = Paint()..color = const Color(0xFFFF8FB8);
    final rock = Paint()..color = const Color(0xFF7D8A76);
    final rockHi = Paint()..color = const Color(0xFFA9B5A0);
    for (var iy = iy0; iy <= iy0 + 11; iy++) {
      for (var ix = ix0; ix <= ix0 + 6; ix++) {
        final sx = ix * cell - ox, sy = iy * cell - oy;
        if ((ix + iy).isEven) c.drawRect(Rect.fromLTWH(sx, sy, cell, cell), dark);
        final h = ((ix * 73856093) ^ (iy * 19349663)) & 0x7fffffff;
        final kind = h % 9;
        final px = sx + (h >> 4) % 48 + 8, py = sy + (h >> 10) % 48 + 8;
        if (kind < 3) {
          for (var k = 0; k < 3; k++) {
            c.drawOval(Rect.fromCenter(center: Offset(px + k * 5 - 5, py - (k == 1 ? 3 : 0)), width: 3, height: 10), tuft);
          }
        } else if (kind == 3) {
          for (var k = 0; k < 5; k++) {
            final a = k / 5 * pi * 2;
            c.drawCircle(Offset(px + cos(a) * 4, py + sin(a) * 4), 3, (h & 1) == 0 ? flowerA : flowerB);
          }
          c.drawCircle(Offset(px, py), 2.5, D.fill(Pal.white));
        } else if (kind == 4) {
          c.drawOval(Rect.fromCenter(center: Offset(px, py), width: 22, height: 14), rock);
          c.drawOval(Rect.fromCenter(center: Offset(px - 3, py - 3), width: 11, height: 5), rockHi);
        } else if (kind == 5 && (h >> 20) % 3 == 0) {
          // bones: a battlefield
          c.drawLine(Offset(px - 7, py), Offset(px + 7, py + 2), D.stroke(const Color(0xFFE8E2CF), 3));
          c.drawCircle(Offset(px - 8, py), 2.5, D.fill(const Color(0xFFE8E2CF)));
          c.drawCircle(Offset(px + 8, py + 2), 2.5, D.fill(const Color(0xFFE8E2CF)));
        }
      }
    }
  }

  void _renderAura(Canvas c) {
    if (_lv[2]! == 0 || _dead) return;
    final r = _auraR * (1 + sin(_t * 8) * .03);
    c.drawCircle(Offset(_hx, _hy), r, D.fill(const Color(0x33B5FFB0)));
    c.drawCircle(Offset(_hx, _hy), r, D.stroke(const Color(0x88D8FFD0), 3));
    c.drawCircle(Offset(_hx, _hy), r * (.4 + (_t * 1.6 % 1) * .6),
        D.stroke(Color.fromRGBO(220, 255, 210, .5 * (1 - _t * 1.6 % 1)), 2));
  }

  void _renderGems(Canvas c) {
    final small = Path(), big = Path();
    for (final g in _gems) {
      if (!_toScreenInside(g.x, g.y)) continue;
      final s = g.v > 1 ? 7.0 : 4.5;
      final p = g.v > 1 ? big : small;
      p
        ..moveTo(g.x, g.y - s * 1.3)
        ..lineTo(g.x + s, g.y)
        ..lineTo(g.x, g.y + s * 1.3)
        ..lineTo(g.x - s, g.y)
        ..close();
    }
    c.drawPath(small, D.fill(const Color(0xFF52C8FF)));
    c.drawPath(small, D.stroke(const Color(0xFF14337A), 1.5));
    c.drawPath(big, D.fill(const Color(0xFF7CFF6B)));
    c.drawPath(big, D.stroke(const Color(0xFF1C5A18), 1.8));
  }

  void _renderEnemies(Canvas c) {
    final shadow = Path();
    final bodies = [Path(), Path(), Path()];
    final flash = Path();
    final whites = Path();
    final pupils = Path();
    final redEyes = Path();
    final horns = Path();
    final wing = sin(_t * 22);
    for (final e in _en) {
      if (!_toScreenInside(e.x, e.y)) continue;
      final r = e.r;
      shadow.addOval(Rect.fromCenter(center: Offset(e.x, e.y + r * .9), width: r * 1.9, height: r * .7));
      final body = e.flash > 0 ? flash : bodies[e.type];
      final bob = e.type == 1 ? -6.0 : sin(_t * 9 + e.phase).abs() * -2.5;
      final cx = e.x, cy = e.y + bob;
      final look = _hx > e.x ? 1.0 : -1.0;
      switch (e.type) {
        case 0: // zombie slime
          body.addRRect(RRect.fromRectAndCorners(Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2.1),
              topLeft: Radius.circular(r), topRight: Radius.circular(r), bottomLeft: Radius.circular(r * .5), bottomRight: Radius.circular(r * .5)));
          whites.addOval(Rect.fromCircle(center: Offset(cx - r * .38 + look, cy - r * .2), radius: r * .32));
          whites.addOval(Rect.fromCircle(center: Offset(cx + r * .38 + look, cy - r * .2), radius: r * .32));
          pupils.addOval(Rect.fromCircle(center: Offset(cx - r * .38 + look * 2.2, cy - r * .18), radius: r * .15));
          pupils.addOval(Rect.fromCircle(center: Offset(cx + r * .38 + look * 2.2, cy - r * .18), radius: r * .15));
        case 1: // bat
          body.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
          body
            ..moveTo(cx - r * .6, cy - 1)
            ..lineTo(cx - r * 2.3, cy - r * (.4 + wing))
            ..lineTo(cx - r * 1.5, cy + r * .5)
            ..close()
            ..moveTo(cx + r * .6, cy - 1)
            ..lineTo(cx + r * 2.3, cy - r * (.4 + wing))
            ..lineTo(cx + r * 1.5, cy + r * .5)
            ..close();
          redEyes.addOval(Rect.fromCircle(center: Offset(cx - r * .35 + look, cy - r * .1), radius: r * .22));
          redEyes.addOval(Rect.fromCircle(center: Offset(cx + r * .35 + look, cy - r * .1), radius: r * .22));
        default: // ogre demon
          body.addOval(Rect.fromCenter(center: Offset(cx, cy), width: r * 2.1, height: r * 2));
          horns
            ..moveTo(cx - r * .7, cy - r * .6)
            ..lineTo(cx - r * .95, cy - r * 1.45)
            ..lineTo(cx - r * .25, cy - r * .85)
            ..close()
            ..moveTo(cx + r * .7, cy - r * .6)
            ..lineTo(cx + r * .95, cy - r * 1.45)
            ..lineTo(cx + r * .25, cy - r * .85)
            ..close();
          whites.addOval(Rect.fromCircle(center: Offset(cx - r * .36 + look * 2, cy - r * .15), radius: r * .26));
          whites.addOval(Rect.fromCircle(center: Offset(cx + r * .36 + look * 2, cy - r * .15), radius: r * .26));
          pupils.addOval(Rect.fromCircle(center: Offset(cx - r * .36 + look * 4, cy - r * .12), radius: r * .12));
          pupils.addOval(Rect.fromCircle(center: Offset(cx + r * .36 + look * 4, cy - r * .12), radius: r * .12));
          pupils.addRect(Rect.fromCenter(center: Offset(cx, cy + r * .45), width: r * .9, height: r * .16));
      }
    }
    c.drawPath(shadow, D.fill(const Color(0x40000000)));
    const cols = [Color(0xFF8FE36A), Color(0xFF9A5CFF), Color(0xFFFF6045)];
    const ink = Color(0xFF1B1530);
    c.drawPath(horns, D.fill(const Color(0xFFFFF1C7)));
    c.drawPath(horns, D.stroke(ink, 1.6));
    for (var i = 0; i < 3; i++) {
      c.drawPath(bodies[i], D.fill(cols[i]));
      c.drawPath(bodies[i], D.stroke(ink, i == 2 ? 2.4 : 1.8));
    }
    c.drawPath(flash, D.fill(Pal.white));
    c.drawPath(flash, D.stroke(ink, 1.8));
    c.drawPath(whites, D.fill(Pal.white));
    c.drawPath(pupils, D.fill(ink));
    c.drawPath(redEyes, D.fill(Pal.yellow));
  }

  void _renderBoss(Canvas c) {
    final b = _boss;
    if (b == null || (b.dead && b.anim > 99)) return;
    if (b.dead) return;
    final o = Offset(b.x, b.y + sin(b.anim * 3) * 3);
    if (b.state == 1) {
      // dash telegraph
      final end = o + b.dir * 170;
      c.drawLine(o, end, D.stroke(Color.fromRGBO(255, 40, 40, .35 + .3 * sin(_t * 30)), 58));
    }
    D.shadow(c, Offset(b.x, b.y + 38), 90, 26, .35);
    final body = b.flash > 0 ? Pal.white : const Color(0xFF6B2FB8);
    // cape
    final cape = Path()
      ..moveTo(o.dx - 30, o.dy - 16)
      ..quadraticBezierTo(o.dx - 58, o.dy + 30, o.dx - 44 + sin(_t * 6) * 4, o.dy + 44)
      ..lineTo(o.dx + 44 + sin(_t * 6 + 1) * 4, o.dy + 44)
      ..quadraticBezierTo(o.dx + 58, o.dy + 30, o.dx + 30, o.dy - 16)
      ..close();
    c.drawPath(cape, D.fill(const Color(0xFFB0102E)));
    c.drawPath(cape, D.stroke(Pal.ink, 3));
    // horns
    for (final s in [-1.0, 1.0]) {
      final h = Path()
        ..moveTo(o.dx + s * 18, o.dy - 30)
        ..quadraticBezierTo(o.dx + s * 52, o.dy - 50, o.dx + s * 46, o.dy - 78)
        ..quadraticBezierTo(o.dx + s * 40, o.dy - 48, o.dx + s * 8, o.dy - 36)
        ..close();
      c.drawPath(h, D.fill(const Color(0xFFFFF1C7)));
      c.drawPath(h, D.stroke(Pal.ink, 3));
    }
    c.drawOval(Rect.fromCenter(center: o, width: 84, height: 78), D.fill(body));
    c.drawOval(Rect.fromCenter(center: o, width: 84, height: 78), D.stroke(Pal.ink, 4));
    c.drawOval(Rect.fromCenter(center: o + const Offset(-16, -20), width: 26, height: 12), D.fill(const Color(0x44FFFFFF)));
    // crown
    final cr = Path()
      ..moveTo(o.dx - 22, o.dy - 34)
      ..lineTo(o.dx - 24, o.dy - 58)
      ..lineTo(o.dx - 11, o.dy - 44)
      ..lineTo(o.dx, o.dy - 62)
      ..lineTo(o.dx + 11, o.dy - 44)
      ..lineTo(o.dx + 24, o.dy - 58)
      ..lineTo(o.dx + 22, o.dy - 34)
      ..close();
    c.drawPath(cr, D.fill(Pal.gold));
    c.drawPath(cr, D.stroke(Pal.ink, 3));
    c.drawCircle(o + const Offset(0, -44), 4, D.fill(Pal.red));
    // glowing eyes
    for (final s in [-1.0, 1.0]) {
      final e = o + Offset(s * 16, -6);
      c.drawCircle(e, 11, D.fill(const Color(0x66FFE14D)));
      final eye = Path()
        ..moveTo(e.dx - 10 * s, e.dy - 6)
        ..lineTo(e.dx + 10 * s, e.dy + 1)
        ..lineTo(e.dx - 8 * s, e.dy + 6)
        ..close();
      c.drawPath(eye, D.fill(Pal.yellow));
      c.drawPath(eye, D.stroke(Pal.ink, 2));
    }
    // fangs mouth
    final m = Path()
      ..moveTo(o.dx - 20, o.dy + 14)
      ..quadraticBezierTo(o.dx, o.dy + 30, o.dx + 20, o.dy + 14)
      ..close();
    c.drawPath(m, D.fill(const Color(0xFF3A0820)));
    for (final s in [-1.0, 1.0]) {
      c.drawPath(
          Path()
            ..moveTo(o.dx + s * 12, o.dy + 15)
            ..lineTo(o.dx + s * 8, o.dy + 24)
            ..lineTo(o.dx + s * 4, o.dy + 17)
            ..close(),
          D.fill(Pal.white));
    }
  }

  void _renderHero(Canvas c) {
    final o = Offset(_hx, _hy);
    if (_dead) {
      // funny tombstone
      final rise = M.clamp01(_deadT * 3);
      D.shadow(c, o + const Offset(0, 16), 34, 10);
      final r = Rect.fromCenter(center: o + Offset(0, 4 - 6 * rise), width: 28, height: 34 * rise + 2);
      c.drawRRect(RRect.fromRectAndCorners(r, topLeft: const Radius.circular(14), topRight: const Radius.circular(14)),
          D.fill(const Color(0xFFB9B4C8)));
      c.drawRRect(RRect.fromRectAndCorners(r, topLeft: const Radius.circular(14), topRight: const Radius.circular(14)),
          D.stroke(Pal.ink, 2.5));
      if (rise > .8) {
        D.line(c, o + const Offset(0, -12), o + const Offset(0, 4), Pal.ink, 3);
        D.line(c, o + const Offset(-6, -6), o + const Offset(6, -6), Pal.ink, 3);
      }
      final g = o + Offset(sin(_deadT * 3) * 8, -30 - _deadT * 30);
      c.drawCircle(g, 9, D.fill(const Color(0x99FFFFFF)));
      D.face(c, g, 8, Face.dead, blush: false);
      return;
    }
    final hurt = _hurtT > .2;
    final step = sin(_walk);
    D.shadow(c, o + const Offset(0, 15), 30, 9, .35);
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(_faceX, 1);
    // cape
    final cape = Path()
      ..moveTo(-8, -8)
      ..quadraticBezierTo(-22, 4, -18 + sin(_t * 10) * 2, 13)
      ..lineTo(4, 11)
      ..close();
    c.drawPath(cape, D.fill(const Color(0xFFE0304E)));
    c.drawPath(cape, D.stroke(Pal.ink, 2));
    // legs
    D.line(c, Offset(-4, 6), Offset(-4 + step * 4, 14), Pal.ink, 5);
    D.line(c, Offset(4, 6), Offset(4 - step * 4, 14), Pal.ink, 5);
    // body armor
    D.rrect(c, const Rect.fromLTWH(-10, -8, 20, 17), 6, hurt ? Pal.red : const Color(0xFF4F8DFF), border: Pal.ink, borderWidth: 2);
    // head
    c.drawCircle(const Offset(0, -16), 10, D.fill(hurt ? Pal.white : Pal.skin));
    c.drawCircle(const Offset(0, -16), 10, D.stroke(Pal.ink, 2));
    // hair
    c.drawArc(Rect.fromCircle(center: const Offset(0, -17), radius: 10.5), pi * 1.05, pi * .95, true, D.fill(const Color(0xFFFFC53D)));
    c.drawCircle(const Offset(3.5, -15), 1.8, D.fill(Pal.ink));
    c.drawCircle(const Offset(8, -15), 1.8, D.fill(Pal.ink));
    // wand
    D.line(c, const Offset(9, -2), const Offset(17, -14), const Color(0xFF7A4A22), 3);
    c.drawCircle(const Offset(17, -15), 4 + sin(_t * 12), D.fill(const Color(0xFF9FE8FF)));
    c.restore();
    // hp bar
    D.bar(c, Rect.fromCenter(center: o + const Offset(0, 24), width: 34, height: 6), _hp / _maxHp,
        _hp < _maxHp * .35 ? Pal.red : Pal.lime);
  }

  void _renderShots(Canvas c) {
    final glow = Paint()..color = const Color(0x5552C8FF);
    final core = Paint()..color = const Color(0xFFE8FBFF);
    for (final s in _shots) {
      final o = Offset(s.x, s.y);
      c.drawLine(o, o - Offset(s.vx, s.vy) * .05, D.stroke(const Color(0x8852C8FF), 6));
      c.drawCircle(o, 8, glow);
      c.drawCircle(o, 4.5, core);
    }
  }

  void _renderBooks(Canvas c) {
    final nb = _bookCount;
    if (nb == 0 || _dead) return;
    final r = _bookR;
    for (var i = 0; i < nb; i++) {
      final a = _bookAng + i / nb * pi * 2;
      final o = Offset(_hx + cos(a) * r, _hy + sin(a) * r);
      c.drawCircle(o, 15, D.fill(const Color(0x33C9A2FF)));
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(a + pi / 2);
      D.rrect(c, const Rect.fromLTWH(-9, -11, 18, 22), 3, const Color(0xFF7B3FE4), border: Pal.ink, borderWidth: 2);
      c.drawRect(const Rect.fromLTWH(5, -9, 3, 18), D.fill(const Color(0xFFFFF4DC)));
      D.star(c, const Offset(-1, 0), 5, Pal.gold);
      c.restore();
    }
  }

  void _renderZaps(Canvas c) {
    for (final z in _zaps) {
      final a = (z.life / .18).clamp(0.0, 1.0);
      final path = Path()..moveTo(z.pts.first.dx, z.pts.first.dy);
      for (final p in z.pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      c.drawPath(path, D.stroke(Color.fromRGBO(255, 240, 120, .5 * a), 10)..style = PaintingStyle.stroke);
      c.drawPath(path, D.stroke(Color.fromRGBO(255, 255, 255, a), 3)..style = PaintingStyle.stroke);
      c.drawCircle(z.at, 30 * (1.4 - a), D.fill(Color.fromRGBO(255, 245, 160, .45 * a)));
    }
  }

  void _renderNums(Canvas c) {
    for (final n in _nums) {
      final a = n.life > .2 ? 1.0 : n.life / .2;
      if (a < .5) continue;
      D.text(c, n.s, Offset(n.x, n.y), size: n.crit ? 17 : 12, color: n.crit ? Pal.yellow : Pal.white, stroke: Pal.ink, strokeWidth: 3);
    }
  }

  void _renderHud(Canvas c) {
    if (_danger > .02) {
      c.drawRect(
          const Rect.fromLTWH(0, 0, 360, 640),
          Paint()
            ..shader = const RadialGradient(radius: .8, colors: [Color(0x00FF0000), Color(0xAAFF0000)], stops: [.6, 1])
                .createShader(const Rect.fromLTWH(0, 0, 360, 640))
            ..color = Color.fromRGBO(0, 0, 0, _danger * (.6 + .4 * sin(_t * 8))));
    }
    // XP bar
    const xr = Rect.fromLTWH(8, 40, 344, 14);
    D.rrect(c, xr, 7, const Color(0xCC14102A), border: Pal.ink, borderWidth: 2);
    final f = M.clamp01(_xp / _xpNeed);
    if (f > 0) {
      D.rrect(c, Rect.fromLTWH(xr.left + 2, xr.top + 2, (xr.width - 4) * f, xr.height - 4), 5, const Color(0xFF52C8FF));
      D.rrect(c, Rect.fromLTWH(xr.left + 4, xr.top + 3, max(0, (xr.width - 8) * f), 3), 2, const Color(0x88FFFFFF));
    }
    D.text(c, '${host.tr('level', 'Lv')} $_level', const Offset(180, 47), size: 11, color: Pal.white, stroke: Pal.ink, strokeWidth: 3);
    // kills counter with skull
    final ks = 1 + _killPunch * .25;
    c.save();
    c.translate(28, 72);
    c.scale(ks);
    c.drawCircle(const Offset(0, -2), 9, D.fill(const Color(0xFFF3EEDF)));
    c.drawRect(const Rect.fromLTWH(-5, 4, 10, 6), D.fill(const Color(0xFFF3EEDF)));
    c.drawCircle(const Offset(-3.5, -2), 2.8, D.fill(Pal.ink));
    c.drawCircle(const Offset(3.5, -2), 2.8, D.fill(Pal.ink));
    c.restore();
    D.text(c, _fmt(_kills), Offset(42, 72), size: 20 * ks, color: Pal.white, stroke: Pal.ink, strokeWidth: 5, anchor: Alignment.centerLeft);
    // weapons row (owned)
    var x = 330.0;
    for (var id = 3; id >= 0; id--) {
      if (_lv[id]! == 0) continue;
      D.rrect(c, Rect.fromCenter(center: Offset(x, 74), width: 28, height: 28), 7, const Color(0xCC14102A), border: Pal.ink, borderWidth: 2);
      _drawIcon(c, id, Offset(x, 74), 10);
      D.text(c, '${_lv[id]}', Offset(x + 10, 84), size: 10, color: Pal.yellow, stroke: Pal.ink, strokeWidth: 3);
      x -= 32;
    }
    // boss hp bar
    final b = _boss;
    if (b != null && !b.dead) {
      const br = Rect.fromLTWH(40, 96, 280, 16);
      D.rrect(c, br.inflate(3), 10, const Color(0xDD14102A));
      D.bar(c, br, b.hp / b.maxHp, const Color(0xFFB02EFF), border: Pal.ink);
      D.text(c, host.tr('boss', 'BOSS'), Offset(br.left - 2, br.center.dy), size: 14, color: Pal.red, stroke: Pal.ink, strokeWidth: 4, anchor: Alignment.centerRight);
      // off-screen arrow pointing to boss
      final sp = _toScreen(Offset(b.x, b.y));
      if (sp.dy < 60 || sp.dy > 630 || sp.dx < 0 || sp.dx > 360) {
        final d = sp - _heroScreen;
        final dir = d / d.distance;
        D.arrow(c, _heroScreen + dir * 120, dir, 34, Pal.red, width: 10);
      }
    }
    if (_bossWarn > 0) {
      final a = (_bossWarn * 4).floor().isEven ? 1.0 : .55;
      c.drawRect(const Rect.fromLTWH(0, 250, 360, 70), D.fill(Color.fromRGBO(120, 0, 20, .75 * a)));
      for (var i = 0; i < 12; i++) {
        final xx = (i * 40 + _t * 160) % 400 - 20;
        c.drawPath(
            Path()
              ..moveTo(xx, 250)
              ..lineTo(xx + 14, 250)
              ..lineTo(xx - 6, 262)
              ..lineTo(xx - 20, 262)
              ..close(),
            D.fill(Pal.yellow));
        c.drawPath(
            Path()
              ..moveTo(xx, 308)
              ..lineTo(xx + 14, 308)
              ..lineTo(xx - 6, 320)
              ..lineTo(xx - 20, 320)
              ..close(),
            D.fill(Pal.yellow));
      }
      D.title(c, host.tr('boss', 'BOSS'), const Offset(180, 285), size: 40, color: Pal.red, scale: 1 + sin(_t * 20) * .04);
    }
    // joystick
    final jb = _joyBase;
    if (jb != null && _cards == null) {
      c.drawCircle(jb, 46, D.fill(const Color(0x33FFFFFF)));
      c.drawCircle(jb, 46, D.stroke(const Color(0x88FFFFFF), 3));
      final d = _joyKnob - jb;
      final k = d.distance > 40 ? jb + d / d.distance * 40 : _joyKnob;
      c.drawCircle(k, 22, D.fill(const Color(0xAAFFFFFF)));
      c.drawCircle(k, 22, D.stroke(Pal.ink, 2));
    } else if (host.time < 2.5 && !host.finished) {
      final p = Offset(180 + sin(_t * 3) * 50, 520);
      c.drawCircle(const Offset(180, 520), 46, D.stroke(const Color(0x88FFFFFF), 3));
      D.hand(c, p, _t);
      D.text(c, host.tr('drag', 'DRAG'), const Offset(180, 588), size: 20, stroke: Pal.ink);
    }
  }

  String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  void _renderCards(Canvas c) {
    final cards = _cards!;
    final appear = M.clamp01(_cardT * 4);
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), D.fill(Color.fromRGBO(10, 6, 30, .72 * appear)));
    D.rays(c, const Offset(180, 330), 520, Color.fromRGBO(255, 210, 60, .13 * appear), count: 16, t: _t * .4);
    D.title(c, host.tr('level_up', 'LEVEL UP!'), const Offset(180, 190),
        size: 40, scale: M.easeOutBack(appear) * (1 + sin(_t * 7) * .03));
    D.text(c, '${host.tr('level', 'Lv')} $_level', const Offset(180, 228), size: 16, color: Pal.white, stroke: Pal.ink);
    for (var i = 0; i < cards.length; i++) {
      final id = cards[i];
      final ct = M.clamp01((_cardT - .08 - i * .09) * 4);
      if (ct <= 0) continue;
      var r = _cardRect(i);
      final chosen = _picked == i;
      final faded = _picked >= 0 && !chosen;
      if (chosen) r = r.inflate(6 * sin(M.clamp01(_pickedT * 3) * pi) + 4);
      c.save();
      c.translate(r.center.dx, r.center.dy + (faded ? _pickedT * 300 : 0));
      c.scale(M.easeOutBack(ct), 1);
      final rr = Rect.fromCenter(center: Offset.zero, width: r.width, height: r.height);
      final isNew = id <= 3 && _lv[id] == 0;
      final col = id <= 3 ? const Color(0xFF8C4DFF) : (id == 7 ? Pal.red : Pal.teal);
      if (isNew || chosen) {
        c.drawRRect(RRect.fromRectAndRadius(rr.inflate(5), const Radius.circular(16)),
            D.fill(Color.fromRGBO(255, 210, 60, .5 + .4 * sin(_t * 10))));
      }
      D.rrect(c, rr, 12, const Color(0xFFFFF4DC), border: Pal.ink, borderWidth: 3);
      D.rrect(c, Rect.fromLTWH(rr.left + 5, rr.top + 5, rr.width - 10, 80), 9, col);
      D.rays(c, Offset(0, rr.top + 45), 60, const Color(0x33FFFFFF), count: 10, t: _t);
      _drawIcon(c, id, Offset(0, rr.top + 45), 24);
      D.text(c, _cardName(id), Offset(0, rr.top + 104), size: 13, color: Pal.ink, maxWidth: rr.width - 8);
      final lvText = isNew ? host.tr('new', 'NEW!') : _cardEffect(id);
      D.text(c, lvText, Offset(0, rr.top + 136), size: 17, color: isNew ? Pal.orange : const Color(0xFF3D6BFF), stroke: Pal.white, strokeWidth: 3);
      if (i == 0 && _picked < 0 && _cardT > 1.2) {
        // auto-pick countdown ring
        final k = M.clamp01((_cardT - 1.2) / 2);
        c.drawArc(Rect.fromCircle(center: Offset(0, rr.bottom - 2), radius: 10), -pi / 2, pi * 2 * (1 - k), false, D.stroke(Pal.orange, 4));
      }
      c.restore();
    }
    if (_cardT > .5 && _cardT < 3 && _picked < 0 && host.time < 12) D.hand(c, _cardRect(0).center + const Offset(0, 30), _t);
  }

  String _cardName(int id) => switch (id) {
        0 => host.tr('magic_bolt', 'Magic Bolt'),
        1 => host.tr('holy_book', 'Holy Book'),
        2 => host.tr('aura', 'Aura'),
        3 => host.tr('thunder', 'Thunder'),
        4 => host.tr('power', 'Power'),
        5 => host.tr('speed', 'Speed'),
        6 => host.tr('magnet', 'Magnet'),
        _ => host.tr('hp', 'HP'),
      };

  String _cardEffect(int id) => switch (id) {
        0 || 1 || 2 || 3 => '${host.tr('level', 'Lv')} ${_lv[id]! + 1}',
        4 => 'x1.5',
        5 => '+18%',
        6 => '+45',
        _ => '+30',
      };

  void _drawIcon(Canvas c, int id, Offset o, double s) {
    switch (id) {
      case 0:
        c.drawCircle(o, s, D.fill(const Color(0x5552C8FF)));
        c.drawCircle(o, s * .62, D.fill(const Color(0xFF52C8FF)));
        c.drawCircle(o, s * .32, D.fill(Pal.white));
        D.line(c, o + Offset(-s * 1.3, s * .9), o + Offset(-s * .5, s * .3), const Color(0xAA9FE8FF), s * .25);
      case 1:
        c.save();
        c.translate(o.dx, o.dy);
        c.rotate(-.15);
        D.rrect(c, Rect.fromCenter(center: Offset.zero, width: s * 1.5, height: s * 1.9), s * .15, const Color(0xFF7B3FE4),
            border: Pal.ink, borderWidth: 2);
        c.drawRect(Rect.fromLTWH(s * .45, -s * .8, s * .22, s * 1.6), D.fill(const Color(0xFFFFF4DC)));
        D.star(c, Offset(-s * .1, 0), s * .42, Pal.gold);
        c.restore();
      case 2:
        c.drawCircle(o, s, D.fill(const Color(0x66B5FFB0)));
        c.drawCircle(o, s, D.stroke(const Color(0xFFD8FFD0), 3));
        c.drawCircle(o, s * .55, D.stroke(Pal.white, 2));
        c.drawCircle(o, s * .2, D.fill(Pal.white));
      case 3:
        final p = Path()
          ..moveTo(o.dx + s * .2, o.dy - s)
          ..lineTo(o.dx - s * .6, o.dy + s * .1)
          ..lineTo(o.dx - s * .05, o.dy + s * .1)
          ..lineTo(o.dx - s * .3, o.dy + s)
          ..lineTo(o.dx + s * .6, o.dy - s * .2)
          ..lineTo(o.dx + s * .05, o.dy - s * .2)
          ..close();
        c.drawPath(p, D.fill(Pal.yellow));
        c.drawPath(p, D.stroke(Pal.ink, 2));
      case 4:
        c.save();
        c.translate(o.dx, o.dy);
        c.rotate(pi / 4);
        D.rrect(c, Rect.fromLTWH(-s * .16, -s, s * .32, s * 1.4), s * .1, const Color(0xFFE8EEF7), border: Pal.ink, borderWidth: 2);
        D.rrect(c, Rect.fromLTWH(-s * .55, s * .38, s * 1.1, s * .22), s * .1, Pal.gold, border: Pal.ink, borderWidth: 2);
        D.rrect(c, Rect.fromLTWH(-s * .12, s * .6, s * .24, s * .45), s * .1, Pal.brown, border: Pal.ink, borderWidth: 2);
        c.restore();
      case 5:
        for (var k = 0; k < 2; k++) {
          final x = o.dx - s * .5 + k * s * .7;
          c.drawPath(
              Path()
                ..moveTo(x - s * .3, o.dy - s * .7)
                ..lineTo(x + s * .35, o.dy)
                ..lineTo(x - s * .3, o.dy + s * .7),
              D.stroke(Pal.lime, s * .3));
        }
      case 6:
        _drawMagnet(c, o, s * .9);
      default:
        D.heart(c, o, s * 1.8, Pal.red, border: Pal.ink);
    }
  }

  void _drawMagnet(Canvas c, Offset o, double s, {bool glow = false}) {
    if (glow) {
      c.drawCircle(o, s * 2, D.fill(Color.fromRGBO(120, 200, 255, .25 + .15 * sin(_t * 8))));
      D.shadow(c, o + Offset(0, s * 1.4), s * 2, s * .6);
    }
    final p = Path()
      ..addArc(Rect.fromCircle(center: o, radius: s * .8), 0, pi);
    c.drawPath(p, D.stroke(Pal.ink, s * .7 + 3));
    c.drawPath(p, D.stroke(Pal.red, s * .7));
    for (final sx in [-1.0, 1.0]) {
      final r = Rect.fromCenter(center: o + Offset(sx * s * .8, -s * .35), width: s * .72, height: s * .75);
      c.drawRect(r, D.fill(Pal.red));
      c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, r.height * .45), D.fill(const Color(0xFFE0E6F0)));
      c.drawRect(r, D.stroke(Pal.ink, 2));
    }
  }
}

class _En {
  double x = 0, y = 0, hp = 1, maxHp = 1, spd = 40, r = 9, flash = 0, bookCd = 0, phase = 0;
  double kx = 0, ky = 0;
  int type = 0;
  int cell = -1;
}

class _Gem {
  double x = 0, y = 0, sp = 0;
  int v = 1;
  bool pulled = false;
}

class _Shot {
  double x = 0, y = 0, vx = 0, vy = 0, life = 1;
  int pierce = 1;
}

class _Num {
  double x = 0, y = 0, life = .5;
  String s = '';
  bool crit = false;
}

class _Zap {
  _Zap(this.pts, this.at);
  final List<Offset> pts;
  final Offset at;
  double life = .18;
}

class _Boss {
  _Boss(this.x, this.y, this.maxHp) : hp = maxHp;
  double x, y;
  final double maxHp;
  double hp;
  double flash = 0, bookCd = 0, anim = 0;
  int state = 0;
  double dashT = 2.5;
  Offset dir = Offset.zero;
  bool dead = false;
}

