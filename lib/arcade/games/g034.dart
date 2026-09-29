import '../engine/engine.dart';

/// No.034 Idle Gold Mine — Idle-Miner-Tycoon cross-section. Tap a shaft to
/// send its miner (or hurry him), buy upgrades (x12 output per level), hire
/// managers to automate, unlock deeper shafts. Reach 1B before time is up.
class G034 extends MiniGame {
  static const _target = 1e9;
  static const _rowTop = [172.0, 324.0, 476.0];
  static const _base = [10.0, 150.0, 3000.0];
  static const _unlockCost = [0.0, 300.0, 8000.0];
  static const _mgrCost = [30.0, 500.0, 10000.0];
  static const _growth = 12.0;
  static const _costK = 1.8;
  static const _trip = .7;
  static const _oreCols = [Pal.gold, Color(0xFFFF4D7A), Color(0xFF6FE3FF)];
  static const _moneyAt = Offset(180, 70);

  final List<_Shaft> _shafts = List.generate(3, (_) => _Shaft());
  double _money = 0;
  double _shown = 0;
  double _bump = 0;
  double _t = 0;
  final List<_Fly> _flies = [];
  double _elevY = 0;
  double _cartX = 0;
  bool _won = false;
  double _winT = 0;
  int _purchases = 0;
  double _lastTapSfx = 0;

  @override
  void init() {
    _shafts[0]
      ..unlocked = true
      ..level = 1;
  }

  double _value(int i) => _base[i] * pow(_growth, _shafts[i].level - 1);
  double _upCost(int i) => _value(i) * _costK;

  Rect _upRect(int i) => Rect.fromLTWH(232, _rowTop[i] + 104, 120, 36);
  Rect _mgrRect(int i) => Rect.fromLTWH(78, _rowTop[i] + 104, 116, 36);
  Rect _unlockRect(int i) => Rect.fromCenter(center: Offset(216, _rowTop[i] + 66), width: 200, height: 58);
  Rect _rowRect(int i) => Rect.fromLTWH(0, _rowTop[i], 360, 104);

  @override
  void update(double dt) {
    _t += dt;
    _bump = M.approach(_bump, 0, 8, dt);
    _shown = _shown < _money ? M.approach(_shown, _money, 9, dt) : _money;
    if (_money - _shown < 1) _shown = _money;
    if (_won) _winT += dt;

    var deepest = 0;
    for (var i = 0; i < 3; i++) {
      final s = _shafts[i];
      s.press = M.approach(s.press, 0, 10, dt);
      s.flash = M.approach(s.flash, 0, 5, dt);
      s.crateBump = M.approach(s.crateBump, 0, 8, dt);
      if (!s.unlocked) continue;
      deepest = i;
      if (s.manager || s.busy) {
        s.busy = true;
        final before = s.prog;
        s.prog += dt / _trip * (s.manager ? 1.0 : 1.15);
        // pickaxe hits
        for (final hit in const [.38, .5, .62]) {
          if (before < hit && s.prog >= hit) {
            s.spark = 1;
            if (_t - _lastTapSfx > .09) {
              host.sfx(Sfx.dig, volume: .25, rate: 1 + i * .15 + rand(0, .1));
              _lastTapSfx = _t;
            }
          }
        }
        if (s.prog >= 1) {
          s.prog -= 1;
          if (s.prog > .9) s.prog = 0;
          _deposit(i);
          s.busy = s.manager;
        }
      }
      s.spark = M.approach(s.spark, 0, 12, dt);
    }
    // elevator & cart ambience
    final bottom = _rowTop[deepest] + 70;
    _elevY = 150 + (bottom - 150) * M.wave(_t, .35 + deepest * .05);
    _cartX = M.wave(_t, .45);

    for (final f in _flies) {
      if (f.delay > 0) {
        f.delay -= dt;
        continue;
      }
      f.t += dt * 1.8;
      if (f.t >= 1 && !f.done) {
        f.done = true;
        _bump = 1;
      }
    }
    _flies.removeWhere((f) => f.done);
    if (_flies.length > 40) _flies.removeRange(0, _flies.length - 40);
  }

  void _deposit(int i) {
    final v = _value(i);
    _money += v;
    host.addScore(max(1, (v / 1e3).round()));
    final s = _shafts[i];
    s.crateBump = 1;
    final at = Offset(96, _rowTop[i] + 80);
    host.fx.pop('+${M.big(v)}', at + const Offset(20, -40), color: _oreCols[i], size: 18 + i * 2.0, life: .7, rise: 40);
    host.sfx(Sfx.coin, volume: .3, rate: 1 + i * .2);
    for (var k = 0; k < 2 + i; k++) {
      _flies.add(_Fly(at, k * .06));
    }
    if (_money >= _target && !_won && !host.finished) {
      _won = true;
      _money = max(_money, _target);
      host.fx.confetti(count: 120);
      host.fx.coins(const Offset(180, 330), count: 40, speed: 600);
      host.sfx(Sfx.ssr);
      host.sfx(Sfx.fanfare);
      host.shake(10, .5);
      host.flash(const Color(0x88FFE27A), .3);
      host.win(stars: host.time < 14 ? 3 : (host.time < 18 ? 2 : 1));
    }
  }

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    for (var i = 0; i < 3; i++) {
      final s = _shafts[i];
      if (!s.unlocked) {
        final prevOk = _shafts[i - 1].unlocked;
        if (prevOk && _unlockRect(i).inflate(6).contains(p)) {
          if (_money >= _unlockCost[i]) {
            _spend(_unlockCost[i], _unlockRect(i).center);
            s.unlocked = true;
            s.level = 1;
            s.flash = 1;
            host.sfx(Sfx.explode, volume: .6);
            host.sfx(Sfx.levelup);
            host.shake(8);
            host.fx.burst(_unlockRect(i).center, const Color(0xFF8A6A50), count: 30, speed: 380, shape: PartShape.square);
            host.fx.pop(host.tr('new', 'NEW!'), _unlockRect(i).center + const Offset(0, -30), color: Pal.lime, size: 30);
          } else {
            _cant(_unlockRect(i).center);
          }
          return;
        }
        continue;
      }
      if (_upRect(i).inflate(4).contains(p)) {
        s.press = 1;
        final cost = _upCost(i);
        if (_money >= cost) {
          _spend(cost, _upRect(i).center);
          s.level++;
          s.flash = 1;
          host.sfx(Sfx.levelup, rate: 1 + min(s.level, 12) * .04);
          host.punch(.025);
          host.fx.burst(Offset(250, _rowTop[i] + 55), _oreCols[i], count: 14, speed: 240, shape: PartShape.star);
          host.fx.pop('x$_growth'.replaceAll('.0', ''), _upRect(i).center + const Offset(0, -34), color: Pal.lime, size: 24);
        } else {
          _cant(_upRect(i).center);
        }
        return;
      }
      if (!s.manager && _mgrRect(i).inflate(4).contains(p)) {
        if (_money >= _mgrCost[i]) {
          _spend(_mgrCost[i], _mgrRect(i).center);
          s.manager = true;
          s.busy = true;
          s.flash = 1;
          host.sfx(Sfx.powerup);
          host.fx.sparkle(_mgrRect(i).center, count: 14, radius: 40, color: Pal.yellow);
          host.fx.pop(host.tr('auto', 'AUTO!'), _mgrRect(i).center + const Offset(0, -36), color: Pal.yellow, size: 26);
        } else {
          _cant(_mgrRect(i).center);
        }
        return;
      }
      if (_rowRect(i).contains(p)) {
        s.press = .6;
        if (!s.busy) {
          s.busy = true;
          host.sfx(Sfx.tap, rate: 1.2);
        } else {
          s.prog = min(.999, s.prog + .3);
          s.spark = 1;
          host.sfx(Sfx.dig, volume: .5, rate: 1.2 + rand(0, .3));
          host.fx.burst(Offset(300, _rowTop[i] + 60), _oreCols[i], count: 5, speed: 180, size: 4);
        }
        return;
      }
    }
  }

  void _spend(double cost, Offset at) {
    _money -= cost;
    _shown = _money;
    _purchases++;
    host.sfx(Sfx.cash, volume: .6, rate: 1 + (_purchases % 8) * .05);
    host.fx.ring(at, Pal.lime, size: 70);
  }

  void _cant(Offset at) {
    host.sfx(Sfx.buzzer, volume: .35);
    host.fx.pop('\$?', at + const Offset(0, -30), color: Pal.red, size: 22, life: .5);
  }

  // ----------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    _drawSurface(c);
    _drawUnderground(c);
    for (var i = 0; i < 3; i++) {
      _drawRow(c, i);
    }
    _drawElevator(c);
    _drawMoney(c);
    for (final f in _flies) {
      if (f.delay > 0) continue;
      final t = M.easeInOut(f.t.clamp(0.0, 1.0));
      final ctrl = Offset(f.from.dx - 40, (f.from.dy + _moneyAt.dy) / 2);
      final a = Offset.lerp(f.from, ctrl, t)!;
      final b = Offset.lerp(ctrl, _moneyAt, t)!;
      D.coin(c, Offset.lerp(a, b, t)!, 8, spin: f.t * 3);
    }
    _drawHint(c);
    if (_won) {
      final k = min(1.0, _winT * 3);
      D.rays(c, const Offset(180, 330), 500, Color.fromRGBO(255, 230, 120, .25 * k), count: 18, t: _t);
      D.title(c, host.tr('billionaire', 'BILLIONAIRE!'), const Offset(180, 330), size: 36,
          scale: M.easeOutBack(k), rotate: -.06, color: Pal.gold);
    }
  }

  void _drawSurface(Canvas c) {
    D.gradientBg(c, const [Color(0xFF6EC8FF), Color(0xFFBDE8FF)], rect: const Rect.fromLTWH(0, 0, 360, 156));
    c.drawCircle(const Offset(316, 60), 20, D.fill(const Color(0xFFFFE27A)));
    c.drawCircle(const Offset(316, 60), 28, Paint()..color = const Color(0x44FFE27A));
    D.cloud(c, Offset(60 + (_t * 8) % 400 - 40, 58), 40);
    D.cloud(c, Offset(250 - (_t * 5) % 400 + 100, 98), 30, color: const Color(0xDDFFFFFF));
    // hills
    c.drawOval(const Rect.fromLTWH(-60, 116, 260, 80), D.fill(const Color(0xFF7BCB5A)));
    c.drawOval(const Rect.fromLTWH(160, 122, 260, 70), D.fill(const Color(0xFF69B84B)));
    c.drawRect(const Rect.fromLTWH(0, 146, 360, 12), D.fill(const Color(0xFF5DA83E)));
    // headframe tower
    final tp = D.stroke(const Color(0xFF6B3A1E), 5);
    c.drawLine(const Offset(18, 150), const Offset(44, 96), tp);
    c.drawLine(const Offset(70, 150), const Offset(44, 96), tp);
    c.drawLine(const Offset(26, 128), const Offset(62, 128), tp);
    c.drawCircle(const Offset(44, 98), 10, D.fill(const Color(0xFF3A3E49)));
    c.drawCircle(const Offset(44, 98), 10, D.stroke(Pal.ink, 2));
    c.save();
    c.translate(44, 98);
    c.rotate(_t * 4);
    c.drawLine(const Offset(-8, 0), const Offset(8, 0), D.stroke(Pal.gray, 2));
    c.restore();
    // warehouse
    D.rrect(c, const Rect.fromLTWH(262, 100, 90, 50), 4, const Color(0xFFE8322C), border: Pal.ink, borderWidth: 2.5);
    c.drawPath(
        Path()
          ..moveTo(256, 102)
          ..lineTo(307, 78)
          ..lineTo(358, 102)
          ..close(),
        D.fill(const Color(0xFF8A2A22)));
    c.drawPath(
        Path()
          ..moveTo(256, 102)
          ..lineTo(307, 78)
          ..lineTo(358, 102)
          ..close(),
        D.stroke(Pal.ink, 2.5));
    D.rrect(c, const Rect.fromLTWH(290, 118, 34, 32), 2, const Color(0xFF5E2A1E), border: Pal.ink, borderWidth: 2);
    D.coin(c, const Offset(307, 92), 7);
    // cart on rails
    c.drawLine(const Offset(70, 150), const Offset(262, 150), D.stroke(const Color(0xFF4A4F5C), 3));
    final cx = 84 + _cartX * 160;
    D.rrect(c, Rect.fromLTWH(cx - 16, 132, 32, 16), 3, const Color(0xFF6F7985), border: Pal.ink, borderWidth: 2);
    if (_cartX > .05) {
      for (var k = 0; k < 3; k++) {
        c.drawCircle(Offset(cx - 8 + k * 8.0, 131), 5, D.fill(Pal.gold));
      }
    }
    c.drawCircle(Offset(cx - 9, 149), 4, D.fill(Pal.ink));
    c.drawCircle(Offset(cx + 9, 149), 4, D.fill(Pal.ink));
  }

  void _drawUnderground(Canvas c) {
    D.gradientBg(c, const [Color(0xFF8A5A36), Color(0xFF5A3620), Color(0xFF2E1B12)], rect: const Rect.fromLTWH(0, 156, 360, 484));
    // rock speckles
    final sp = D.fill(const Color(0x22000000));
    final sp2 = D.fill(const Color(0x18FFFFFF));
    for (var k = 0; k < 40; k++) {
      final x = (k * 97) % 360.0;
      final y = 160 + (k * 53) % 470.0;
      c.drawCircle(Offset(x, y), 3 + (k % 4).toDouble(), k.isEven ? sp : sp2);
    }
    // elevator shaft
    c.drawRect(const Rect.fromLTWH(18, 156, 52, 470), D.fill(const Color(0xFF24160E)));
    c.drawLine(const Offset(18, 156), const Offset(18, 626), D.stroke(const Color(0xFF6B3A1E), 4));
    c.drawLine(const Offset(70, 156), const Offset(70, 626), D.stroke(const Color(0xFF6B3A1E), 4));
    for (var y = 170.0; y < 626; y += 40) {
      c.drawLine(Offset(18, y), Offset(70, y + 20), D.stroke(const Color(0x556B3A1E), 3));
    }
  }

  void _drawElevator(Canvas c) {
    c.drawLine(Offset(44, 108), Offset(44, _elevY - 22), D.stroke(const Color(0xFF9AA4B0), 2));
    D.rrect(c, Rect.fromCenter(center: Offset(44, _elevY), width: 42, height: 44), 4, const Color(0xFFC0392B),
        border: Pal.ink, borderWidth: 2.5);
    D.rrect(c, Rect.fromCenter(center: Offset(44, _elevY + 4), width: 30, height: 26), 3, const Color(0xFF3A1E14));
    for (var k = 0; k < 3; k++) {
      c.drawCircle(Offset(36 + k * 8.0, _elevY + 12), 4, D.fill(_oreCols[k % 3]));
    }
  }

  void _drawRow(Canvas c, int i) {
    final s = _shafts[i];
    final top = _rowTop[i];
    final tunnel = RRect.fromRectAndRadius(Rect.fromLTWH(74, top + 8, 280, 92), const Radius.circular(18));
    if (!s.unlocked) {
      c.drawRRect(tunnel, D.fill(const Color(0xFF3B2618)));
      // boulders
      for (var k = 0; k < 7; k++) {
        final x = 96 + k * 38.0;
        final y = top + 40 + (k.isEven ? 10 : 30);
        c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 48, height: 36), D.fill(const Color(0xFF6E5645)));
        c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 48, height: 36), D.stroke(Pal.ink, 2));
      }
      final prevOk = _shafts[i - 1].unlocked;
      if (prevOk) {
        final can = _money >= _unlockCost[i];
        final r = _unlockRect(i);
        final pulse = can ? 1 + .05 * sin(_t * 10) : 1.0;
        c.save();
        c.translate(r.center.dx, r.center.dy);
        c.scale(pulse);
        D.button(c, Rect.fromCenter(center: Offset.zero, width: r.width, height: r.height), '', color: can ? Pal.orange : Pal.gray);
        D.text(c, host.tr('unlock', 'UNLOCK'), const Offset(0, -12), size: 18, color: Pal.white, stroke: Pal.ink, maxWidth: 180);
        D.coin(c, const Offset(-30, 12), 8);
        D.text(c, M.big(_unlockCost[i]), const Offset(10, 12), size: 16, color: Pal.yellow, stroke: Pal.ink);
        c.restore();
      } else {
        D.text(c, '?', Offset(216, top + 56), size: 40, color: const Color(0x66FFFFFF));
      }
      return;
    }
    c.drawRRect(tunnel, D.fill(const Color(0xFF1E120B)));
    // support beams
    for (final x in [130.0, 210.0]) {
      c.drawRect(Rect.fromLTWH(x, top + 10, 8, 90), D.fill(const Color(0xFF6B3A1E)));
    }
    c.drawRect(Rect.fromLTWH(74, top + 10, 280, 7), D.fill(const Color(0xFF6B3A1E)));
    // lamp glow
    c.drawCircle(Offset(170, top + 24), 34, Paint()..color = const Color(0x22FFD27A));
    c.drawCircle(Offset(170, top + 20), 4, D.fill(Pal.yellow));
    // floor
    c.drawRect(Rect.fromLTWH(74, top + 92, 280, 8), D.fill(const Color(0xFF4A2E1C)));
    // ore wall
    final wall = Path()
      ..moveTo(354, top + 8)
      ..lineTo(308, top + 14)
      ..lineTo(296, top + 40)
      ..lineTo(306, top + 66)
      ..lineTo(294, top + 100)
      ..lineTo(354, top + 100)
      ..close();
    c.drawPath(wall, D.fill(const Color(0xFF4E3A2E)));
    for (var k = 0; k < 6; k++) {
      final o = Offset(318 + (k % 2) * 18.0, top + 24 + k * 12.0);
      D.gem(c, o + Offset(sin(_t * 2 + k) * .5, 0), 6 + (k % 3).toDouble(), _oreCols[i]);
    }
    if (s.spark > 0) {
      for (var k = 0; k < 5; k++) {
        final a = k * 1.25 + _t * 5;
        c.drawLine(Offset(296, top + 58), Offset(296 + cos(a) * 16 * s.spark, top + 58 + sin(a) * 16 * s.spark),
            D.stroke(Pal.yellow, 2.5));
      }
    }
    // crate
    final cb = 1 + s.crateBump * .15;
    c.save();
    c.translate(96, top + 84);
    c.scale(cb, 2 - cb);
    D.rrect(c, const Rect.fromLTWH(-18, -16, 36, 22), 3, const Color(0xFF9A5B34), border: Pal.ink, borderWidth: 2);
    for (var k = 0; k < 3; k++) {
      c.drawCircle(Offset(-9 + k * 9.0, -17), 5, D.fill(_oreCols[i]));
    }
    c.restore();

    // miners: more miners appear as the level grows
    final miners = min(3, 1 + (s.level - 1) ~/ 3);
    for (var m = miners - 1; m >= 0; m--) {
      final ph = (s.prog + m * .23) % 1.0;
      final active = s.busy || s.manager;
      _drawMiner(c, i, active ? ph : 0, top + 96 - m * 3.0, m, active);
    }
    // manager
    if (s.manager) {
      final mp = Offset(156, top + 98);
      D.person(c, mp, 50, const Color(0xFF2B2B3A), face: Face.smug, hair: Pal.ink, pants: const Color(0xFF2B2B3A));
      c.drawRect(Rect.fromCenter(center: mp + const Offset(0, -42), width: 20, height: 5), D.fill(Pal.ink));
      c.drawLine(mp + const Offset(0, -33), mp + const Offset(0, -22), D.stroke(Pal.red, 3));
    }
    // level badge
    D.rrect(c, Rect.fromLTWH(78, top + 12, 58, 22), 11, const Color(0xCC000000));
    D.star(c, Offset(90, top + 23), 8, _oreCols[i]);
    D.text(c, '${s.level}', Offset(116, top + 23), size: 15, color: Pal.white);
    D.text(c, '+${M.big(_value(i))}', Offset(246, top + 24), size: 14, color: _oreCols[i], stroke: Pal.ink);
    if (s.flash > 0) {
      c.drawRRect(tunnel, Paint()..color = Pal.white.withValues(alpha: s.flash * .35));
    }
    // idle prompt
    if (!s.busy && !s.manager) {
      final b = M.wave(_t, 2);
      D.text(c, host.tr('tap', 'TAP!'), Offset(216, top + 52), size: 22 + b * 4, color: Pal.yellow, stroke: Pal.ink);
    }
    // buttons
    final cost = _upCost(i);
    final can = _money >= cost;
    final ur = _upRect(i);
    final uscale = 1 - s.press * .06 + (can ? .03 * sin(_t * 9) : 0);
    c.save();
    c.translate(ur.center.dx, ur.center.dy);
    c.scale(uscale);
    D.button(c, Rect.fromCenter(center: Offset.zero, width: ur.width, height: ur.height), '',
        color: can ? Pal.green : const Color(0xFF6D6A7C), pressed: s.press > .3);
    D.arrow(c, const Offset(-44, 0), const Offset(0, -1), 18, can ? Pal.yellow : Pal.gray, width: 6);
    D.coin(c, const Offset(-24, 0), 7);
    D.text(c, M.big(cost), const Offset(16, 0), size: 16, color: Pal.white, stroke: Pal.ink, maxWidth: 70);
    c.restore();
    if (!s.manager) {
      final mr = _mgrRect(i);
      final mc = _money >= _mgrCost[i];
      D.button(c, mr, '', color: mc ? Pal.purple : const Color(0xFF6D6A7C));
      D.text(c, host.tr('hire', 'HIRE'), mr.center + const Offset(-22, 0), size: 14, color: Pal.white, stroke: Pal.ink,
          maxWidth: 58);
      D.coin(c, mr.center + const Offset(16, 0), 6);
      D.text(c, M.big(_mgrCost[i]), mr.center + const Offset(38, 0), size: 13, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _drawMiner(Canvas c, int i, double ph, double floorY, int idx, bool active) {
    double x;
    bool carry = false;
    bool mining = false;
    const x0 = 118.0, x1 = 278.0;
    if (ph < .3) {
      x = M.lerp(x0, x1, ph / .3);
    } else if (ph < .7) {
      x = x1;
      mining = true;
    } else {
      x = M.lerp(x1, x0, (ph - .7) / .3);
      carry = true;
    }
    x -= idx * 10;
    final walking = !mining && active;
    final flip = carry;
    final f = mining ? Face.angry : (carry ? Face.happy : Face.neutral);
    D.person(c, Offset(x, floorY), 56, const Color(0xFF3D6BFF),
        run: _t * 14 + idx, running: walking, face: f, flip: flip, pants: const Color(0xFF2B3A70));
    // helmet
    final head = Offset(x, floorY - 56 * .82);
    c.drawArc(Rect.fromCircle(center: head + const Offset(0, -2), radius: 11), pi, pi, true, D.fill(Pal.yellow));
    c.drawArc(Rect.fromCircle(center: head + const Offset(0, -2), radius: 11), pi, pi, true, D.stroke(Pal.ink, 1.5));
    c.drawCircle(head + Offset(flip ? -7 : 7, -8), 3, D.fill(Pal.white));
    // pickaxe / sack
    if (mining) {
      final a = -1.2 + sin(ph * 40) * .9;
      final hand = Offset(x + 6, floorY - 34);
      final tip = hand + Offset(cos(a) * 22, sin(a) * 22);
      c.drawLine(hand, tip, D.stroke(const Color(0xFF8A5A33), 3));
      c.drawLine(tip + Offset(-sin(a) * 9, cos(a) * 9), tip - Offset(-sin(a) * 9, cos(a) * 9), D.stroke(const Color(0xFFB8C4CC), 3.5));
    } else if (carry) {
      c.drawCircle(Offset(x + 12, floorY - 44), 10, D.fill(const Color(0xFFC8A070)));
      c.drawCircle(Offset(x + 12, floorY - 44), 10, D.stroke(Pal.ink, 1.8));
      c.drawCircle(Offset(x + 12, floorY - 50), 4, D.fill(_oreCols[i]));
    }
  }

  void _drawMoney(Canvas c) {
    final s = 1 + _bump * .1;
    c.save();
    c.translate(_moneyAt.dx, _moneyAt.dy);
    c.scale(s);
    D.rrect(c, const Rect.fromLTWH(-92, -24, 184, 48), 24, const Color(0xE61B1530), border: Pal.gold, borderWidth: 3);
    D.coin(c, const Offset(-68, 0), 16, spin: _t * .6);
    final digits = M.big(_shown);
    D.text(c, digits, const Offset(14, 0), size: 30, color: Pal.gold, stroke: Pal.ink, maxWidth: 140);
    c.restore();
    // log progress to 1B
    final prog = (_money <= 1 ? 0.0 : (log10(_money) / 9)).clamp(0.0, 1.0);
    D.bar(c, const Rect.fromLTWH(96, 100, 168, 12), prog, Color.lerp(Pal.orange, Pal.lime, prog)!, border: Pal.ink);
    D.text(c, '1B', const Offset(284, 106), size: 16, color: Pal.white, stroke: Pal.ink);
  }

  static double log10(double v) => log(v) / 2.302585092994046;

  void _drawHint(Canvas c) {
    if (host.finished) return;
    final s0 = _shafts[0];
    if (_purchases == 0 && host.time < 6) {
      if (_money >= _mgrCost[0]) {
        D.hand(c, _mgrRect(0).center + const Offset(0, 8), _t);
      } else if (_money >= _upCost(0)) {
        D.hand(c, _upRect(0).center + const Offset(0, 8), _t);
      } else if (!s0.busy) {
        D.hand(c, Offset(216, _rowTop[0] + 66), _t);
      }
    }
  }
}

class _Shaft {
  bool unlocked = false;
  bool manager = false;
  bool busy = false;
  int level = 0;
  double prog = 0;
  double press = 0;
  double flash = 0;
  double spark = 0;
  double crateBump = 0;
}

class _Fly {
  _Fly(this.from, this.delay);
  final Offset from;
  double delay;
  double t = 0;
  bool done = false;
}
