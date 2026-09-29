import 'dart:math' as math;

import '../engine/engine.dart';

/// No.021 Hero Tower Absorb — "only fight WEAKER enemies" tower puzzle.
///
/// Drag the hero into a room of the enemy tower. If the hero's power is
/// higher than the monster's, he absorbs it and grows; otherwise he dies.
/// Potions add power, spike traps take it away. Beat the boss on the top floor
/// to clear the tower. Three towers; the last boss holds the princess.
class G021 extends MiniGame {
  static const _groundY = 596.0;
  static const _floorH = 76.0;
  static const _tL = 150.0, _tR = 342.0; // enemy tower
  static const _heroRoom = Rect.fromLTWH(22, _groundY - _floorH, 104, _floorH);

  double _t = 0;
  int _level = 0;
  double _power = 8;
  double _shownPower = 8;
  final List<_Room> _rooms = [];
  _Room? _heroIn; // null = hero's own tower
  bool _dragging = false;
  Offset _heroPos = _heroRoom.center + const Offset(0, 18);
  Offset _dragPos = Offset.zero;
  _Room? _downRoom;
  _Fight? _fight;
  double _slide = 1; // tower slide-in 1 → 0
  double _transition = -1;
  bool _dead = false;
  bool _won = false;
  bool _everDragged = false;
  double _bump = 0;

  @override
  void init() => _buildLevel();

  void _buildLevel() {
    _rooms.clear();
    final floors = 3 + _level;
    final p = _power;
    // Build an always-solvable sequence: each monster is beatable after the
    // previous ones, the boss needs everything except the trap.
    final contents = <(int, double)>[]; // (kind, value) kind 0 monster 1 potion 2 trap
    var acc = p;
    final lower = floors - 1;
    final hasTrap = _level >= 1;
    final hasPotion = _level >= 1;
    final monsters = lower - (hasTrap ? 1 : 0) - (hasPotion ? 1 : 0);
    for (var i = 0; i < monsters; i++) {
      // strictly smaller than current power, but bigger than the starting one
      final v = i == 0
          ? (acc * rand(.45, .8)).floorToDouble().clamp(1, acc - 1)
          : (acc * rand(.7, .92)).floorToDouble().clamp(1, acc - 1);
      contents.add((0, v.toDouble()));
      acc += v;
      if (hasPotion && i == 0) {
        final pv = (acc * rand(.25, .4)).roundToDouble();
        contents.add((1, pv));
        acc += pv;
      }
    }
    if (hasTrap) contents.add((2, (acc * rand(.35, .5)).roundToDouble()));
    final boss = (acc - math.max(1, acc * rand(.06, .14))).floorToDouble();
    contents.shuffle(rng);
    for (var i = 0; i < lower; i++) {
      final (k, v) = contents[i];
      _rooms.add(_Room(i, _RoomKind.values[k], v, randInt(4)));
    }
    _rooms.add(_Room(lower, _RoomKind.boss, boss, 0)..princess = _level == 2);
    _slide = 1;
    _heroIn = null;
    _heroPos = _heroRoom.center + const Offset(0, 18);
  }

  Rect _roomRect(_Room r) {
    final y = _groundY - (r.floor + 1) * _floorH;
    return Rect.fromLTWH(_tL + 8, y, _tR - _tL - 16, _floorH);
  }

  double get _slideX => M.easeInOut(_slide.clamp(0.0, 1.0)) * 240;

  Offset _roomSpot(_Room r) => _roomRect(r).center + Offset(_slideX - 30, 18);
  Offset _enemySpot(_Room r) => _roomRect(r).center + Offset(_slideX + 34, 18);

  // ------------------------------------------------------------ update ---

  @override
  void update(double dt) {
    _t += dt;
    if (!_busy && _t > 1 && _slide < .05 && chance(.05)) { final pots = _rooms.where((r) => !r.cleared && r.kind == _RoomKind.potion).toList(); if (pots.isNotEmpty) { _enter(pots.first); } else { onKey('action', true); } } // BOT
    _bump = M.approach(_bump, 0, 7, dt);
    _shownPower = M.approach(_shownPower, _power, 9, dt);
    if (_transition < 0) _slide = M.approach(_slide, 0, 6, dt);
    if (_slide < .01) _slide = 0;

    if (_transition >= 0) {
      _transition += dt;
      if (_transition > .5) _slide = math.min(1, (_transition - .5) / .35);
      if (_transition > 1.0) {
        _transition = -1;
        _level++;
        _buildLevel();
        host.sfx(Sfx.whoosh);
      }
    }

    for (final r in _rooms) {
      r.hover = M.approach(r.hover, 0, 8, dt);
      r.shrink = M.approach(r.shrink, r.cleared ? 1 : 0, 7, dt);
    }

    final f = _fight;
    if (f != null) {
      f.t += dt;
      if (!f.resolved && f.t > .45) {
        f.resolved = true;
        _resolve(f);
      }
      if (f.t > .9) _fight = null;
    }

    // hero follows
    if (!_dragging) {
      final home = _heroIn == null ? _heroRoom.center + const Offset(0, 18) : _roomSpot(_heroIn!);
      _heroPos = M.approachO(_heroPos, home, 14, dt);
    } else {
      _heroPos = M.approachO(_heroPos, _dragPos, 30, dt);
    }
  }

  void _resolve(_Fight f) {
    final r = f.room;
    switch (r.kind) {
      case _RoomKind.potion:
        _power += r.value;
        r.cleared = true;
        host.sfx(Sfx.powerup);
        host.fx.pop('+${r.value.round()}', _enemySpot(r) + const Offset(0, -40), color: Pal.lime, size: 30);
        host.fx.sparkle(_heroPos, count: 12, radius: 30, color: Pal.lime);
        _bump = 1;
      case _RoomKind.trap:
        _power = math.max(1, _power - r.value);
        r.cleared = true;
        host.sfx(Sfx.hurt);
        host.sfx(Sfx.oops, volume: .7);
        host.shake(6);
        host.flash(Pal.red, .12);
        host.fx.pop('-${r.value.round()}', _heroPos + const Offset(0, -50), color: Pal.red, size: 30);
        _bump = 1;
      case _RoomKind.monster || _RoomKind.boss:
        if (_power > r.value) {
          _power += r.value;
          r.cleared = true;
          _bump = 1;
          final boss = r.kind == _RoomKind.boss;
          host.sfx(boss ? Sfx.explode : Sfx.chomp);
          host.sfx(Sfx.levelup, volume: .6, rate: 1 + _rooms.where((x) => x.cleared).length * .06);
          host.shake(boss ? 12 : 5);
          host.hitStop(boss ? .12 : .05);
          host.punch(.03);
          host.fx.burst(_enemySpot(r), Pal.yellow, count: boss ? 36 : 18, speed: boss ? 380 : 240,
              shape: PartShape.star, colors: const [Pal.yellow, Pal.orange, Pal.white]);
          host.fx.pop('+${r.value.round()}', _heroPos + const Offset(0, -56), color: Pal.yellow, size: 34);
          host.addScore(r.value.round() * 10);
          if (boss) _bossBeaten(r);
        } else {
          _dead = true;
          host.sfx(Sfx.punch);
          host.sfx(Sfx.jingleLose);
          host.shake(10);
          host.flash(Pal.red, .2);
          host.fx.burst(_heroPos, Pal.red, count: 20, speed: 260, size: 7);
          host.fx.pop(host.tr('lose', 'LOSE'), _heroPos + const Offset(0, -60), color: Pal.red, size: 30);
          r.value += _power;
          host.lose();
        }
    }
  }

  void _bossBeaten(_Room r) {
    host.fx.coins(_enemySpot(r), count: 16);
    if (_level >= 2) {
      _won = true;
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.cheer);
      host.fx.confetti();
      for (var i = 0; i < 8; i++) {
        host.fx.add(Particle(
            pos: _enemySpot(r) + Offset(rand(-30, 30), rand(-20, 10)),
            vel: Offset(rand(-60, 60), rand(-160, -60)),
            life: rand(1, 1.6),
            color: Pal.pink,
            size: rand(5, 9),
            shape: PartShape.heart));
      }
      final left = host.timeLeft;
      host.win(stars: left > 5 ? 3 : (left > 2.5 ? 2 : 1));
    } else {
      host.sfx(Sfx.jingleWin, volume: .8);
      host.fx.pop(host.tr('clear', 'CLEAR!'), const Offset(180, 240), color: Pal.yellow, size: 40, life: 1);
      _transition = 0;
    }
  }

  // ------------------------------------------------------------- input ---

  _Room? _roomAt(Offset p) {
    if (_slide > .05) return null;
    for (final r in _rooms) {
      if (!r.cleared && _roomRect(r).inflate(4).contains(p)) return r;
    }
    return null;
  }

  bool get _busy => _fight != null || _transition >= 0 || host.finished || _dead;

  @override
  void onDown(Offset p) {
    if (_busy) return;
    return; // BOT
    if ((p - _heroPos).distance < 48) {
      _dragging = true;
      _everDragged = true;
      _dragPos = p;
      host.sfx(Sfx.pickup, volume: .6);
    } else {
      _downRoom = _roomAt(p);
    }
  }

  @override
  void onMove(Offset p) {
    if (!_dragging) return;
    _dragPos = p + const Offset(0, -10);
    final r = _roomAt(p);
    if (r != null) r.hover = 1;
  }

  @override
  void onUp(Offset p) {
    if (_busy) {
      _dragging = false;
      return;
    }
    if (_dragging) {
      _dragging = false;
      final r = _roomAt(p);
      if (r != null) {
        _enter(r);
      } else {
        host.sfx(Sfx.back, volume: .5);
      }
    } else if (_downRoom != null && _roomAt(p) == _downRoom) {
      _enter(_downRoom!);
    }
    _downRoom = null;
  }

  void _enter(_Room r) {
    _heroIn = r;
    _fight = _Fight(r);
    host.sfx(Sfx.whoosh, rate: 1.2);
    if (r.kind == _RoomKind.monster || r.kind == _RoomKind.boss) host.sfx(Sfx.slash, volume: .7);
  }

  @override
  void onKey(String key, bool down) {
    if (!down || key != 'action' || _busy) return;
    // pick the weakest beatable room (keyboard assist)
    _Room? best;
    for (final r in _rooms) {
      if (r.cleared || r.kind == _RoomKind.trap) continue;
      if (best == null || r.value < best.value) best = r;
    }
    if (best != null) _enter(best);
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    // sky
    D.gradientBg(c, const [Color(0xFF6FD3FF), Color(0xFFB7ECFF), Color(0xFFFFF1C9)]);
    D.rays(c, const Offset(60, 120), 500, const Color(0x18FFFFFF), count: 12, t: _t * .15);
    D.circle(c, const Offset(60, 120), 30, const Color(0xFFFFE27A));
    for (var i = 0; i < 4; i++) {
      final x = (i * 110 + _t * (8 + i * 3)) % 460 - 50;
      D.cloud(c, Offset(x, 140 + i * 36.0), 34 + i * 6.0, color: const Color(0xDDFFFFFF));
    }
    // hills
    c.drawOval(const Rect.fromLTWH(-80, 520, 300, 160), D.fill(const Color(0xFF7ACB5C)));
    c.drawOval(const Rect.fromLTWH(160, 530, 320, 150), D.fill(const Color(0xFF6BBE50)));
    c.drawRect(const Rect.fromLTWH(0, _groundY, 360, 60), D.fill(const Color(0xFF5BAE45)));
    c.drawRect(const Rect.fromLTWH(0, _groundY + 12, 360, 60), D.fill(const Color(0xFF8A5A3C)));

    _drawHeroTower(c);
    _drawEnemyTower(c);

    // hero
    final f = _fight;
    var hp = _heroPos;
    if (f != null && !f.resolved) {
      hp += Offset(math.sin(f.t * 40) * 6, 0);
    }
    if (!(_dead && (f == null || f.resolved))) {
      _drawHero(c, hp, _dragging ? 1.12 : 1.0);
    }

    // drag line
    if (_dragging) {
      final r = _roomAt(_dragPos);
      if (r != null) {
        final ok = r.kind == _RoomKind.potion || (r.kind != _RoomKind.trap && _power > r.value);
        c.drawRRect(RRect.fromRectAndRadius(_roomRect(r).deflate(2), const Radius.circular(8)),
            D.stroke(ok ? Pal.lime : Pal.red, 5));
      }
    }

    // HUD: level pips
    D.rrect(c, const Rect.fromLTWH(98, 44, 164, 34), 14, const Color(0xCC1B1530));
    D.text(c, host.tr('level', 'LEVEL'), const Offset(144, 61), size: 15, color: Pal.white);
    for (var i = 0; i < 3; i++) {
      final done = i < _level || (_won && i == 2);
      final cur = i == _level && !_won;
      D.star(c, Offset(200 + i * 22.0, 61), cur ? 10 + M.wave(_t, 2) * 2 : 9,
          done ? Pal.gold : (cur ? Pal.white : const Color(0x55FFFFFF)), border: Pal.ink);
    }

    // tutorial
    if (!_everDragged && _t < 5 && !host.finished && _slide < .05) {
      final target = _rooms.where((r) => r.kind == _RoomKind.monster && r.value < _power).fold<_Room?>(
          null, (a, b) => a == null || b.value < a.value ? b : a);
      if (target != null) {
        final k = (_t * .7) % 1;
        final from = _heroRoom.center + const Offset(0, 10);
        final to = _enemySpot(target);
        final p = Offset.lerp(from, to, M.easeInOut(k))!;
        c.drawLine(from, p, D.stroke(const Color(0x99FFFFFF), 4));
        D.hand(c, p, 0);
      }
    }
  }

  void _drawHeroTower(Canvas c) {
    final r = _heroRoom;
    // tower body
    D.rrect(c, Rect.fromLTRB(r.left - 8, r.top - 50, r.right + 8, _groundY + 4), 6, const Color(0xFF7FA3D6),
        border: Pal.ink, borderWidth: 3);
    _bricks(c, Rect.fromLTRB(r.left - 6, r.top - 48, r.right + 6, _groundY), const Color(0x333B5C8A));
    // roof
    final roof = Path()
      ..moveTo(r.left - 18, r.top - 48)
      ..lineTo(r.center.dx, r.top - 118)
      ..lineTo(r.right + 18, r.top - 48)
      ..close();
    c.drawPath(roof, D.fill(const Color(0xFF3D6BFF)));
    c.drawPath(roof, D.stroke(Pal.ink, 3));
    _flag(c, Offset(r.center.dx, r.top - 118), const Color(0xFF3D6BFF));
    // small window
    D.rrect(c, Rect.fromCenter(center: Offset(r.center.dx, r.top - 24), width: 22, height: 26), 11,
        const Color(0xFF263A5E), border: Pal.ink, borderWidth: 2.5);
    _roomInterior(c, r, const Color(0xFF3A4E7A));
  }

  void _drawEnemyTower(Canvas c) {
    if (_rooms.isEmpty) return;
    final floors = _rooms.length;
    final dx = _slideX;
    final top = _groundY - floors * _floorH;
    c.save();
    c.translate(dx, 0);
    D.rrect(c, Rect.fromLTRB(_tL, top - 10, _tR, _groundY + 4), 6, const Color(0xFFB08A7A), border: Pal.ink, borderWidth: 3);
    _bricks(c, Rect.fromLTRB(_tL + 2, top - 8, _tR - 2, _groundY), const Color(0x33603A2A));
    final roof = Path()
      ..moveTo(_tL - 12, top - 8)
      ..lineTo((_tL + _tR) / 2, top - 80)
      ..lineTo(_tR + 12, top - 8)
      ..close();
    c.drawPath(roof, D.fill(const Color(0xFFD23C4E)));
    c.drawPath(roof, D.stroke(Pal.ink, 3));
    _flag(c, Offset((_tL + _tR) / 2, top - 80), const Color(0xFF6A2A5A));
    c.restore();

    for (final r in _rooms) {
      final rect = _roomRect(r).shift(Offset(dx, 0));
      _roomInterior(c, rect, r.kind == _RoomKind.boss ? const Color(0xFF5A2A3A) : const Color(0xFF4A3A4A));
      if (r.hover > .05) {
        c.drawRRect(RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(8)),
            D.fill(Color.fromRGBO(255, 255, 255, .15 * r.hover)));
      }
      _drawContent(c, r);
    }
  }

  void _bricks(Canvas c, Rect r, Color col) {
    final p = D.stroke(col, 2);
    var row = 0;
    for (var y = r.top + 14; y < r.bottom; y += 14, row++) {
      c.drawLine(Offset(r.left, y), Offset(r.right, y), p);
      for (var x = r.left + (row.isEven ? 10 : 24); x < r.right; x += 28) {
        c.drawLine(Offset(x, y - 14), Offset(x, y), p);
      }
    }
  }

  void _flag(Canvas c, Offset tip, Color col) {
    D.line(c, tip, tip + const Offset(0, -26), Pal.ink, 3);
    c.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy - 26)
          ..quadraticBezierTo(tip.dx + 12, tip.dy - 30 + math.sin(_t * 6) * 3, tip.dx + 24, tip.dy - 24)
          ..lineTo(tip.dx, tip.dy - 14)
          ..close(),
        D.fill(col));
  }

  void _roomInterior(Canvas c, Rect r, Color wall) {
    final inner = r.deflate(5);
    D.rrect(c, inner, 6, wall, border: Pal.ink, borderWidth: 2.5);
    // back-wall stones
    final sp = D.stroke(const Color(0x22FFFFFF), 1.5);
    for (var i = 0; i < 3; i++) {
      c.drawLine(Offset(inner.left + 4, inner.top + 14 + i * 16.0), Offset(inner.right - 4, inner.top + 14 + i * 16.0), sp);
    }
    // floor planks
    D.rrect(c, Rect.fromLTWH(inner.left, inner.bottom - 10, inner.width, 10), 3, const Color(0xFF8A5A3C),
        border: Pal.ink, borderWidth: 2);
    // torch
    final tp = Offset(inner.left + 12, inner.top + 22);
    D.line(c, tp, tp + const Offset(0, 12), const Color(0xFF5A3A2A), 3);
    D.flame(c, tp, 12, _t + r.top);
    c.drawCircle(tp + const Offset(0, -4), 16, D.fill(const Color(0x22FFB040)));
  }

  void _drawContent(Canvas c, _Room r) {
    if (r.shrink > .98) return;
    final pos = _enemySpot(r);
    final s = 1 - r.shrink;
    c.save();
    c.translate(pos.dx, pos.dy);
    c.scale(s);
    final f = _fight;
    final fighting = f != null && f.room == r && !f.resolved;
    if (fighting) c.translate(-math.sin(f.t * 40) * 5, 0);
    final beatable = r.kind == _RoomKind.monster || r.kind == _RoomKind.boss ? _power > r.value : true;
    switch (r.kind) {
      case _RoomKind.monster:
        _monster(c, r.variant, beatable);
      case _RoomKind.boss:
        _boss(c, beatable);
        if (r.princess) _princess(c);
      case _RoomKind.potion:
        _potion(c);
      case _RoomKind.trap:
        _spikes(c);
    }
    c.restore();
    // power badge
    if (r.shrink < .5) {
      final bp = pos + Offset(0, r.kind == _RoomKind.boss ? -48 : -38);
      final Color col;
      String label;
      switch (r.kind) {
        case _RoomKind.potion:
          col = const Color(0xFF2ECC71);
          label = '+${r.value.round()}';
        case _RoomKind.trap:
          col = const Color(0xFFFF3B5C);
          label = '-${r.value.round()}';
        default:
          col = beatable ? const Color(0xFF2ECC71) : const Color(0xFFFF3B5C);
          label = '${r.value.round()}';
      }
      D.rrect(c, Rect.fromCenter(center: bp, width: 50, height: 22), 9, col, border: Pal.ink, borderWidth: 2.5);
      D.text(c, label, bp, size: 16, color: Pal.white, stroke: Pal.ink, strokeWidth: 3.5);
    }
  }

  void _monster(Canvas c, int v, bool beatable) {
    final bob = math.sin(_t * 5 + v) * 2;
    final face = beatable ? Face.shocked : Face.smug;
    switch (v) {
      case 0: // slime
        D.shadow(c, const Offset(0, 2), 40, 8);
        D.blob(c, Offset(0, -14 + bob), 18, const Color(0xFF6BD66B), face: face, squash: 1 + math.sin(_t * 6) * .06);
      case 1: // bat
        for (final s in [-1.0, 1.0]) {
          final flap = math.sin(_t * 14) * .5;
          c.drawPath(
              Path()
                ..moveTo(0, -22 + bob)
                ..lineTo(s * 30, -34 + bob + flap * 12)
                ..lineTo(s * 22, -18 + bob)
                ..lineTo(s * 14, -22 + bob)
                ..close(),
              D.fill(const Color(0xFF5A3A7A)));
        }
        D.blob(c, Offset(0, -22 + bob), 13, const Color(0xFF7A5AA0), face: face);
      case 2: // skeleton
        D.shadow(c, const Offset(0, 2), 30, 7);
        D.rrect(c, Rect.fromLTWH(-8, -20 + bob, 16, 20), 4, const Color(0xFFE8E4D8), border: Pal.ink, borderWidth: 2);
        for (var i = 0; i < 3; i++) {
          D.line(c, Offset(-6, -16 + i * 5 + bob), Offset(6, -16 + i * 5 + bob), Pal.ink, 1.5);
        }
        D.circle(c, Offset(0, -30 + bob), 11, const Color(0xFFF4F0E4), border: Pal.ink, borderWidth: 2);
        D.face(c, Offset(0, -30 + bob), 10, beatable ? Face.shocked : Face.angry, blush: false);
      default: // goblin w/ club
        D.shadow(c, const Offset(0, 2), 36, 8);
        D.blob(c, Offset(0, -16 + bob), 16, const Color(0xFFA0C040), face: beatable ? face : Face.angry);
        for (final s in [-1.0, 1.0]) {
          c.drawPath(
              Path()
                ..moveTo(s * 12, -24 + bob)
                ..lineTo(s * 24, -30 + bob)
                ..lineTo(s * 14, -18 + bob)
                ..close(),
              D.fill(const Color(0xFFA0C040)));
        }
        D.line(c, Offset(18, -10 + bob), Offset(26, -30 + bob), const Color(0xFF8A5530), 5);
    }
  }

  void _boss(Canvas c, bool beatable) {
    final bob = math.sin(_t * 3) * 2;
    D.shadow(c, const Offset(0, 2), 56, 10);
    // horns
    for (final s in [-1.0, 1.0]) {
      c.drawPath(
          Path()
            ..moveTo(s * 10, -40 + bob)
            ..quadraticBezierTo(s * 30, -50 + bob, s * 28, -62 + bob)
            ..lineTo(s * 18, -38 + bob)
            ..close(),
          D.fill(const Color(0xFFFFF1C9)));
    }
    D.blob(c, Offset(0, -22 + bob), 24, const Color(0xFFE0453A), face: beatable ? Face.shocked : Face.angry);
    // crown
    final crown = Path()
      ..moveTo(-12, -44 + bob)
      ..lineTo(-12, -54 + bob)
      ..lineTo(-6, -48 + bob)
      ..lineTo(0, -56 + bob)
      ..lineTo(6, -48 + bob)
      ..lineTo(12, -54 + bob)
      ..lineTo(12, -44 + bob)
      ..close();
    c.drawPath(crown, D.fill(Pal.gold));
    c.drawPath(crown, D.stroke(Pal.ink, 2));
  }

  void _princess(Canvas c) {
    const o = Offset(-58, 0);
    D.person(c, o, 44, Pal.pink, face: _won ? Face.love : Face.cry, hair: const Color(0xFFFFD23F), armsUp: _won ? 1 : 0);
    // cage
    if (!_won) {
      for (var i = 0; i < 5; i++) {
        D.line(c, o + Offset(-16 + i * 8.0, -50), o + Offset(-16 + i * 8.0, 0), const Color(0xFF6A6A7A), 2.5);
      }
      D.line(c, o + const Offset(-18, -50), o + const Offset(18, -50), const Color(0xFF6A6A7A), 3);
    }
  }

  void _potion(Canvas c) {
    final bob = math.sin(_t * 4) * 3;
    c.drawCircle(Offset(0, -18 + bob), 22, D.fill(const Color(0x332ECC71)));
    D.rrect(c, Rect.fromCenter(center: Offset(0, -34 + bob), width: 10, height: 10), 2, const Color(0xFFCDEFFF),
        border: Pal.ink, borderWidth: 2);
    D.circle(c, Offset(0, -16 + bob), 14, const Color(0xFFCDEFFF), border: Pal.ink, borderWidth: 2.5);
    c.drawArc(Rect.fromCircle(center: Offset(0, -16 + bob), radius: 12), 0, math.pi, true, D.fill(Pal.lime));
    D.circle(c, Offset(-5, -21 + bob), 3, const Color(0xCCFFFFFF));
  }

  void _spikes(Canvas c) {
    for (var i = 0; i < 5; i++) {
      final x = -40 + i * 20.0;
      c.drawPath(
          Path()
            ..moveTo(x - 8, 0)
            ..lineTo(x, -26)
            ..lineTo(x + 8, 0)
            ..close(),
          D.fill(const Color(0xFFB9C0D6)));
      c.drawPath(
          Path()
            ..moveTo(x - 8, 0)
            ..lineTo(x, -26)
            ..lineTo(x + 8, 0)
            ..close(),
          D.stroke(Pal.ink, 2));
      c.drawCircle(Offset(x, -22), 2, D.fill(Pal.red));
    }
  }

  void _drawHero(Canvas c, Offset feet, double s) {
    c.save();
    c.translate(feet.dx, feet.dy);
    c.scale(s * (1 + _bump * .15));
    final f = _fight;
    final attacking = f != null && !f.resolved;
    D.shadow(c, const Offset(0, 2), 34, 8);
    // cape
    c.drawPath(
        Path()
          ..moveTo(-9, -34)
          ..quadraticBezierTo(-20, -14, -16 + math.sin(_t * 6) * 2, 0)
          ..lineTo(8, -2)
          ..lineTo(9, -34)
          ..close(),
        D.fill(const Color(0xFFD23C4E)));
    D.person(c, Offset.zero, 50, const Color(0xFF3D6BFF),
        face: _dead ? Face.dead : (attacking ? Face.angry : (_won ? Face.love : Face.smug)),
        hair: const Color(0xFFFFB02E), armsUp: _won ? 1 : 0);
    // sword
    final swing = attacking ? math.sin(f.t * 30) * 1.2 : 0.0;
    c.save();
    c.translate(12, -30);
    c.rotate(-.6 + swing);
    D.line(c, Offset.zero, const Offset(0, -30), const Color(0xFFE8ECF8), 5);
    D.line(c, Offset.zero, const Offset(0, -30), Pal.ink, 1);
    D.line(c, const Offset(-6, 0), const Offset(6, 0), Pal.gold, 4);
    c.restore();
    c.restore();
    // power badge
    final bp = feet + Offset(0, -66 * s);
    final bs = 1 + _bump * .4;
    c.save();
    c.translate(bp.dx, bp.dy);
    c.scale(bs);
    D.rrect(c, const Rect.fromLTWH(-30, -14, 60, 28), 11, const Color(0xFF3D6BFF), border: Pal.ink, borderWidth: 3);
    D.text(c, '${_shownPower.round()}', Offset.zero, size: 19, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
    c.restore();
  }
}

enum _RoomKind { monster, potion, trap, boss }

class _Room {
  _Room(this.floor, this.kind, this.value, this.variant);
  final int floor;
  final _RoomKind kind;
  double value;
  final int variant;
  bool cleared = false;
  bool princess = false;
  double hover = 0;
  double shrink = 0;
}

class _Fight {
  _Fight(this.room);
  final _Room room;
  double t = 0;
  bool resolved = false;
}
