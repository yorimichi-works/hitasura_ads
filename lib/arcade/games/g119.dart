import '../engine/engine.dart';

/// No.119 Lv.1 vs Boss Lv.999 — pick one of two doors per floor (math gates
/// or monsters). Out-level the Demon Lord after 5 floors and slash him.
class G119 extends MiniGame {
  static const _auto = bool.fromEnvironment('AUTOPLAY');

  late final List<List<_Opt>> _floors;
  int _floor = 0;
  int _level = 1;
  double _shownLv = 1;
  int _best = 1;
  _Ph _ph = _Ph.choose;
  double _phT = 0;
  int _pick = 0; // 0 left, 1 right
  double _t = 0;
  Offset _hero = const Offset(180, 560);
  double _heroFlash = 0;
  double _heroHurt = 0;
  double _scroll = 0; // floor transition 0..1
  double _bossY = 0; // 0 top .. 1 down in the arena
  double _slash = 0;
  bool _heroWins = false;
  double _lvPunch = 0;

  static List<List<_Opt>> _template(int k) => switch (k) {
        0 => [
            [_Opt.add(9), _Opt.mul(2)],
            [_Opt.mul(3), _Opt.mon(_Mon.slime, 5)],
            [_Opt.mon(_Mon.orc, 20), _Opt.mul(2)],
            [_Opt.mul(5), _Opt.mon(_Mon.dragon, 99)],
            [_Opt.mul(4), _Opt.mon(_Mon.golem, 250)],
          ],
        1 => [
            [_Opt.mul(3), _Opt.add(4)],
            [_Opt.mon(_Mon.bat, 3), _Opt.mul(4)],
            [_Opt.add(30), _Opt.mul(2)],
            [_Opt.mul(5), _Opt.mon(_Mon.wolf, 60)],
            [_Opt.mul(5), _Opt.add(-100)],
          ],
        _ => [
            [_Opt.add(2), _Opt.mul(2)],
            [_Opt.mul(5), _Opt.add(10)],
            [_Opt.mon(_Mon.skeleton, 12), _Opt.mul(3)],
            [_Opt.mul(4), _Opt.add(100)],
            [_Opt.mul(7), _Opt.mon(_Mon.golem, 150)],
          ],
      };

  @override
  void init() {
    _floors = _template(randInt(3));
    for (final f in _floors) {
      if (chance(.5)) f.insert(0, f.removeAt(1));
    }
    // best reachable level (for star rating)
    void dfs(int i, int lv) {
      if (i == _floors.length) {
        _best = max(_best, lv);
        return;
      }
      for (final o in _floors[i]) {
        dfs(i + 1, o.apply(lv));
      }
    }

    dfs(0, 1);
  }

  void _go(_Ph p) {
    _ph = p;
    _phT = 0;
  }

  Offset _doorC(int i) => Offset(i == 0 ? 100 : 260, 330);

  @override
  void update(double dt) {
    _t += dt;
    _phT += dt;
    _heroFlash = M.approach(_heroFlash, 0, 4, dt);
    _heroHurt = M.approach(_heroHurt, 0, 3, dt);
    _lvPunch = M.approach(_lvPunch, 0, 6, dt);
    _shownLv = M.approach(_shownLv, _level.toDouble(), 9, dt);
    if ((_shownLv - _level).abs() < .6) _shownLv = _level.toDouble();
    switch (_ph) {
      case _Ph.choose:
        _hero = M.approachO(_hero, const Offset(180, 560), 10, dt);
        if (_auto && _phT > .3) {
          final o = _floors[_floor];
          _choose(o[0].apply(_level) >= o[1].apply(_level) ? 0 : 1);
        }
      case _Ph.walk:
        _hero = M.approachO(_hero, _doorC(_pick) + const Offset(0, 120), 14, dt);
        if (_phT > .32) {
          _go(_Ph.open);
          host.sfx(Sfx.open);
        }
      case _Ph.open:
        if (_phT > .22 && _phT - dt <= .22) _resolve();
        if (_phT > .9) {
          _go(_Ph.scroll);
          host.sfx(Sfx.whoosh, rate: .8);
        }
      case _Ph.scroll:
        _scroll = min(1, _phT / .38);
        _hero = M.approachO(_hero, const Offset(180, 560), 10, dt);
        if (_phT > .38) {
          _scroll = 0;
          _floor++;
          if (_floor >= _floors.length) {
            _go(_Ph.boss);
            host.sfx(Sfx.horror);
            host.sfx(Sfx.heartbeat);
            host.shake(6, .6);
          } else {
            _go(_Ph.choose);
          }
        }
      case _Ph.boss:
        _bossY = min(1, _phT / .9);
        if (_phT > 1.1 && _phT - dt <= 1.1) _bossFight();
        if (_heroWins) {
          if (_phT > 1.1) {
            _hero = M.approachO(_hero, const Offset(180, 330), 18, dt);
            _slash = min(1, (_phT - 1.25) / .25);
          }
          if (_phT > 1.55 && _phT - dt <= 1.55) {
            host.sfx(Sfx.slash);
            host.sfx(Sfx.explode);
            host.hitStop(.15);
            host.flash(Pal.white, .35);
            host.shake(16, .6);
            host.fx.burst(const Offset(180, 260), Pal.purple, count: 50, speed: 520, colors: const [Pal.purple, Pal.red, Pal.yellow]);
            host.fx.ring(const Offset(180, 260), Pal.yellow, size: 220, life: .6);
            host.fx.pop('K.O.!!', const Offset(180, 200), color: Pal.yellow, size: 64, life: 1.5);
            final stars = _level >= _best ? 3 : (_level >= _best * .85 ? 2 : 1);
            host.win(stars: stars);
          }
        } else if (_phT > 1.1) {
          _hero += Offset(160 * dt, -700 * dt);
        }
    }
  }

  void _choose(int i) {
    if (_ph != _Ph.choose || host.finished) return;
    _pick = i;
    _go(_Ph.walk);
    host.sfx(Sfx.step, rate: 1.2);
    host.sfx(Sfx.select);
  }

  void _resolve() {
    final o = _floors[_floor][_pick];
    final before = _level;
    final at = _hero + const Offset(0, -110);
    if (o.mon != null) {
      if (_level > o.value) {
        _level += o.value;
        host.sfx(Sfx.slash);
        host.sfx(Sfx.hitHeavy);
        host.hitStop(.06);
        host.shake(6);
        host.fx.burst(_doorC(_pick), Pal.red, count: 24, speed: 300, colors: const [Pal.red, Pal.orange, Pal.white]);
        host.fx.pop('+${o.value}', at, color: Pal.lime, size: 34);
      } else {
        _level = max(1, _level ~/ 2);
        _heroHurt = 1;
        host.sfx(Sfx.hurt);
        host.sfx(Sfx.punch);
        host.shake(10, .35);
        host.flash(Pal.red, .2);
        host.fx.pop(host.tr('too_strong', 'TOO STRONG!'), _doorC(_pick) + const Offset(0, -130), color: Pal.red, size: 26);
        host.fx.pop('÷2', at, color: Pal.red, size: 34);
      }
    } else {
      _level = max(1, o.apply(_level));
      final good = _level > before;
      if (good) {
        host.sfx(o.mul ? Sfx.levelup : Sfx.powerup, rate: 1 + _floor * .08);
        host.fx.burst(_hero + const Offset(0, -40), o.mul ? Pal.sky : Pal.lime, count: 20, speed: 260, shape: PartShape.star);
        host.fx.ring(_hero + const Offset(0, -40), o.mul ? Pal.sky : Pal.lime, size: 80);
        host.fx.pop(o.label, at, color: o.mul ? Pal.yellow : Pal.lime, size: 38);
        if (o.mul && o.value >= 4) host.shake(5);
      } else {
        host.sfx(Sfx.oops);
        host.fx.pop(o.label, at, color: Pal.red, size: 34);
        _heroHurt = 1;
      }
    }
    _heroFlash = 1;
    _lvPunch = 1;
  }

  void _bossFight() {
    _heroWins = _level > 999;
    if (_heroWins) {
      host.sfx(Sfx.powerup);
      host.sfx(Sfx.swing);
      host.fx.pop(host.tr('attack', 'ATTACK!'), const Offset(180, 470), color: Pal.yellow, size: 34);
    } else {
      host.sfx(Sfx.slap);
      host.sfx(Sfx.boing);
      host.shake(8);
      host.fx.pop(host.tr('weak', 'WEAK...'), const Offset(180, 470), color: Pal.gray, size: 34, life: 1.3);
      host.lose();
    }
  }

  @override
  void onDown(Offset p) => _choose(p.dx < 180 ? 0 : 1);

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'left') _choose(0);
    if (key == 'right') _choose(1);
  }

  // ------------------------------------------------------------ render ---

  Color _auraCol(int lv) => lv > 999
      ? D.hsv(_t * 300, .7, 1)
      : lv >= 300
          ? Pal.purple
          : lv >= 60
              ? Pal.sky
              : lv >= 10
                  ? Pal.lime
                  : Pal.white;

  @override
  void render(Canvas c) {
    // tower interior: dark stone with torch light
    D.gradientBg(c, const [Color(0xFF2A1B45), Color(0xFF3D2A5C), Color(0xFF1E1433)]);
    final sc = _scroll * 300;
    final brick = D.stroke(const Color(0x33000000), 2);
    final hl = D.fill(const Color(0x0DFFFFFF));
    for (var row = -2; row < 24; row++) {
      final y = row * 30.0 + (sc % 60);
      c.drawLine(Offset(0, y), Offset(360, y), brick);
      for (var x = (row.isEven ? 0.0 : 30.0); x < 360; x += 60) {
        c.drawLine(Offset(x, y), Offset(x, y + 30), brick);
        if ((row + x ~/ 60) % 3 == 0) c.drawRect(Rect.fromLTWH(x + 2, y + 2, 56, 10), hl);
      }
    }
    // torches
    for (final x in [20.0, 340.0]) {
      final y = 420.0 + (sc % 300);
      c.drawCircle(Offset(x, y - 20), 50, D.fill(const Color(0x22FF8A1F)));
      D.rrect(c, Rect.fromCenter(center: Offset(x, y), width: 10, height: 26), 3, const Color(0xFF6B4A2B), border: Pal.ink, borderWidth: 2);
      D.flame(c, Offset(x, y - 12), 26, _t + x);
    }
    // floor
    c.drawRect(const Rect.fromLTWH(0, 470, 360, 170), D.fill(const Color(0xFF2B2140)));
    for (var i = 0; i < 8; i++) {
      c.drawLine(Offset(i * 52.0 - 20, 470), Offset(i * 60.0 - 60, 640), D.stroke(const Color(0x22FFFFFF), 2));
    }
    c.drawLine(const Offset(0, 470), const Offset(360, 470), D.stroke(const Color(0x55FFFFFF), 3));
    // royal red carpet to the boss
    final carpet = Path()
      ..moveTo(130, 470)
      ..lineTo(230, 470)
      ..lineTo(290, 640)
      ..lineTo(70, 640)
      ..close();
    c.drawPath(carpet, D.fill(const Color(0xFF8A1030)));
    c.drawPath(carpet, D.stroke(const Color(0xFFFFC53D), 3));
    for (var i = 0; i < 4; i++) {
      final y = 490.0 + i * 40 + (sc * .5 % 40);
      c.drawLine(Offset(180 - (y - 470) * .35 - 40, y), Offset(180 + (y - 470) * .35 + 40, y), D.stroke(const Color(0x33FFC53D), 2));
    }

    // floor tracker (left)
    for (var i = 0; i < 5; i++) {
      final p = Offset(22, 200 - i * 22.0 + 60);
      final done = i < _floor;
      final cur = i == _floor && _ph != _Ph.boss;
      D.circle(c, p, cur ? 8 : 6, done ? Pal.yellow : (cur ? Pal.white : const Color(0xFF55476F)), border: Pal.ink, borderWidth: 2);
    }

    // boss looming
    _boss(c);

    // doors
    if (_ph != _Ph.boss) {
      c.save();
      c.translate(0, sc * 1.3);
      for (var i = 0; i < 2; i++) {
        _door(c, i, _floors[_floor][i]);
      }
      c.restore();
      if (_ph == _Ph.scroll && _floor + 1 < _floors.length) {
        c.save();
        c.translate(0, -400 + sc * 1.33);
        for (var i = 0; i < 2; i++) {
          _door(c, i, _floors[_floor + 1][i], fresh: true);
        }
        c.restore();
      }
    }

    // slash effect
    if (_slash > 0 && _slash < 1) {
      final p = Path()
        ..moveTo(40, 120)
        ..quadraticBezierTo(180, 180 + 200 * _slash, 330, 420 * _slash);
      c.drawPath(p, D.stroke(Color.fromRGBO(255, 255, 255, 1 - _slash), 22 * (1 - _slash) + 4));
      c.drawPath(p, D.stroke(Color.fromRGBO(255, 230, 120, 1 - _slash), 8));
    }

    _heroDraw(c);

    if (_ph == _Ph.choose && _floor == 0 && host.time < 2.5) {
      D.hand(c, _doorC(0) + const Offset(0, 40), _t);
      D.hand(c, _doorC(1) + const Offset(0, 40), _t + .5);
    }
  }

  void _door(Canvas c, int i, _Opt o, {bool fresh = false}) {
    final cc = _doorC(i);
    final r = Rect.fromCenter(center: cc + const Offset(0, 20), width: 130, height: 190);
    final opened = !fresh && i == _pick && (_ph == _Ph.open || _ph == _Ph.scroll);
    final openK = opened ? (_ph == _Ph.scroll ? 1.0 : min(1.0, _phT / .2)) : 0.0;
    final hover = !fresh && _ph == _Ph.choose ? M.wave(_t + i * .5, 1.5) * 3 : 0.0;
    // frame arch
    final arch = Path()
      ..moveTo(r.left - 10, r.bottom)
      ..lineTo(r.left - 10, r.top + 40)
      ..arcToPoint(Offset(r.right + 10, r.top + 40), radius: const Radius.circular(75))
      ..lineTo(r.right + 10, r.bottom)
      ..close();
    c.drawPath(arch, D.fill(const Color(0xFF6E6388)));
    c.drawPath(arch, D.stroke(Pal.ink, 4));
    final inner = Path()
      ..moveTo(r.left, r.bottom)
      ..lineTo(r.left, r.top + 45)
      ..arcToPoint(Offset(r.right, r.top + 45), radius: const Radius.circular(65))
      ..lineTo(r.right, r.bottom)
      ..close();
    // inside (what's behind)
    final isMon = o.mon != null;
    final good = isMon ? false : o.value > 0;
    final insideCol = isMon ? const Color(0xFF3A0A1A) : (good ? const Color(0xFFFFF3B0) : const Color(0xFF400A0A));
    c.drawPath(inner, D.fill(insideCol));
    if (isMon) {
      _monster(c, o, cc + Offset(0, 40 + hover), 42, dead: opened && _level > o.value && _phT > .25 || _ph == _Ph.scroll && opened);
    } else if (opened) {
      D.rays(c, cc + const Offset(0, 30), 120, Color.fromRGBO(255, 255, 255, .3 * openK), count: 10, t: _t);
    }
    // door panel swinging open
    if (openK < 1) {
      c.save();
      c.clipPath(inner);
      final w = r.width * (1 - openK);
      final panel = Rect.fromLTWH(r.left, r.top, w, r.height);
      D.rrect(c, panel, 0, isMon ? const Color(0xFF7A3B2B) : const Color(0xFF9A5B34));
      for (var k = 1; k < 4; k++) {
        c.drawLine(Offset(r.left + w * k / 4, r.top), Offset(r.left + w * k / 4, r.bottom), D.stroke(const Color(0x44000000), 3));
      }
      if (isMon) {
        // barred window with glowing eyes
        final win = Rect.fromCenter(center: Offset(r.left + w / 2, cc.dy + 20), width: w * .55, height: 50);
        D.rrect(c, win, 8, const Color(0xFF15060C), border: Pal.ink, borderWidth: 2.5);
        for (final s in [-1.0, 1.0]) {
          c.drawCircle(win.center + Offset(s * 10 * (1 - openK), -4), 4, D.fill(Pal.red));
        }
        for (var k = 1; k < 4; k++) {
          final x = win.left + win.width * k / 4;
          c.drawLine(Offset(x, win.top), Offset(x, win.bottom), D.stroke(const Color(0xFF6B6F86), 3));
        }
      }
      c.drawCircle(Offset(r.left + w - 14, cc.dy + 60), 6, D.fill(Pal.gold));
      c.restore();
    }
    c.drawPath(inner, D.stroke(Pal.ink, 3));

    // sign plaque above
    final plaque = Rect.fromCenter(center: Offset(cc.dx, r.top - 6 + hover), width: 116, height: 50);
    final pc = isMon ? const Color(0xFF8A1030) : (o.mul ? const Color(0xFF1F5FD9) : (good ? const Color(0xFF1FA35A) : const Color(0xFFD92B2B)));
    D.rrect(c, plaque.shift(const Offset(0, 4)), 12, Color.lerp(pc, Pal.ink, .5)!);
    D.rrect(c, plaque, 12, pc, border: Pal.ink, borderWidth: 3);
    if (isMon) {
      D.text(c, 'Lv.${o.value}', plaque.center, size: 26, color: Pal.white, stroke: Pal.ink, strokeWidth: 5);
      // danger skull if stronger than you
      if (!fresh && o.value >= _level) {
        D.circle(c, plaque.topRight + const Offset(-6, 4), 11, Pal.red, border: Pal.ink, borderWidth: 2);
        D.text(c, '!', plaque.topRight + const Offset(-6, 4), size: 16, color: Pal.white);
      }
    } else {
      D.text(c, o.label, plaque.center, size: 32, color: o.mul ? Pal.yellow : Pal.white, stroke: Pal.ink, strokeWidth: 6);
    }
  }

  void _monster(Canvas c, _Opt o, Offset p, double r, {bool dead = false}) {
    final m = o.mon!;
    final col = switch (m) {
      _Mon.slime => Pal.lime,
      _Mon.bat => const Color(0xFF7B4DBB),
      _Mon.orc => const Color(0xFF5EA04A),
      _Mon.dragon => const Color(0xFFE0452B),
      _Mon.golem => const Color(0xFF8E8AA3),
      _Mon.wolf => const Color(0xFF6D7A99),
      _Mon.skeleton => const Color(0xFFEDE6D6),
    };
    final s = r * (.7 + (o.value.clamp(1, 250) / 250) * .45);
    if (m == _Mon.bat || m == _Mon.dragon) {
      for (final sx in [-1.0, 1.0]) {
        final wing = Path()
          ..moveTo(p.dx + sx * s * .5, p.dy - s * .2)
          ..lineTo(p.dx + sx * s * 1.5, p.dy - s * .9 + sin(_t * 12) * 6)
          ..lineTo(p.dx + sx * s * 1.2, p.dy + s * .1)
          ..close();
        c.drawPath(wing, D.fill(Color.lerp(col, Pal.ink, .3)!));
        c.drawPath(wing, D.stroke(Pal.ink, 2.5));
      }
    }
    if (m == _Mon.dragon || m == _Mon.orc || m == _Mon.golem) {
      for (final sx in [-1.0, 1.0]) {
        final horn = Path()
          ..moveTo(p.dx + sx * s * .35, p.dy - s * .75)
          ..lineTo(p.dx + sx * s * .65, p.dy - s * 1.35)
          ..lineTo(p.dx + sx * s * .7, p.dy - s * .55)
          ..close();
        c.drawPath(horn, D.fill(const Color(0xFFFFF4DC)));
        c.drawPath(horn, D.stroke(Pal.ink, 2));
      }
    }
    if (m == _Mon.wolf) {
      for (final sx in [-1.0, 1.0]) {
        final ear = Path()
          ..moveTo(p.dx + sx * s * .25, p.dy - s * .7)
          ..lineTo(p.dx + sx * s * .6, p.dy - s * 1.3)
          ..lineTo(p.dx + sx * s * .85, p.dy - s * .45)
          ..close();
        c.drawPath(ear, D.fill(col));
        c.drawPath(ear, D.stroke(Pal.ink, 2));
      }
    }
    D.blob(c, p, s, col, face: dead ? Face.dead : (o.value >= _level ? Face.smug : Face.angry));
    if (m == _Mon.orc || m == _Mon.wolf) {
      for (final sx in [-1.0, 1.0]) {
        c.drawPath(
            Path()
              ..moveTo(p.dx + sx * s * .22, p.dy + s * .35)
              ..lineTo(p.dx + sx * s * .3, p.dy + s * .08)
              ..lineTo(p.dx + sx * s * .12, p.dy + s * .3)
              ..close(),
            D.fill(Pal.white));
      }
    }
  }

  void _boss(Canvas c) {
    final k = M.easeInOut(_bossY);
    final p = Offset(180, M.lerp(110, 250, k));
    final s = M.lerp(.55, 1.15, k);
    final dead = host.finished && _heroWins && _phT > 1.55;
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(s);
    if (dead) {
      final sp = (_phT - 1.55) * 120;
      c.translate(0, sp * .3);
      c.rotate((_phT - 1.55) * .6);
    }
    // aura
    c.drawCircle(Offset.zero, 110, D.fill(Color.fromRGBO(200, 30, 60, .15 + .08 * sin(_t * 4))));
    // cape
    final cape = Path()
      ..moveTo(-60, -20)
      ..lineTo(-110, 110)
      ..quadraticBezierTo(0, 80 + sin(_t * 3) * 10, 110, 110)
      ..lineTo(60, -20)
      ..close();
    c.drawPath(cape, D.fill(const Color(0xFF5A0E2A)));
    c.drawPath(cape, D.stroke(Pal.ink, 4));
    // body
    D.rrect(c, const Rect.fromLTRB(-50, -10, 50, 90), 20, const Color(0xFF2C1B4A), border: Pal.ink, borderWidth: 4);
    D.rrect(c, const Rect.fromLTRB(-20, 10, 20, 50), 8, const Color(0xFFB0102A), border: Pal.ink, borderWidth: 3);
    // head
    for (final sx in [-1.0, 1.0]) {
      final horn = Path()
        ..moveTo(sx * 22, -50)
        ..quadraticBezierTo(sx * 70, -70, sx * 58, -120)
        ..quadraticBezierTo(sx * 50, -80, sx * 10, -64)
        ..close();
      c.drawPath(horn, D.fill(const Color(0xFFEDE6D6)));
      c.drawPath(horn, D.stroke(Pal.ink, 3.5));
    }
    c.drawCircle(const Offset(0, -40), 38, D.fill(const Color(0xFF7B3FA8)));
    c.drawCircle(const Offset(0, -40), 38, D.stroke(Pal.ink, 4));
    // eyes
    for (final sx in [-1.0, 1.0]) {
      final eye = Path()
        ..moveTo(sx * 6, -48)
        ..lineTo(sx * 26, -56)
        ..lineTo(sx * 22, -42)
        ..close();
      c.drawPath(eye, D.fill(dead ? Pal.white : const Color(0xFFFF2040)));
      c.drawPath(eye, D.stroke(Pal.ink, 2));
    }
    // grin
    c.drawArc(Rect.fromCenter(center: const Offset(0, -26), width: 36, height: 18), .1, pi - .2, false, D.stroke(Pal.ink, 4));
    for (var i = -1; i <= 1; i += 2) {
      c.drawPath(
          Path()
            ..moveTo(i * 10.0, -19)
            ..lineTo(i * 6.0, -11)
            ..lineTo(i * 2.0, -19)
            ..close(),
          D.fill(Pal.white));
    }
    c.restore();
    // level plate
    final plate = Offset(180, p.dy + 100 * s + 8);
    D.rrect(c, Rect.fromCenter(center: plate, width: 120, height: 34), 10, const Color(0xFF8A1030), border: Pal.ink, borderWidth: 3);
    D.text(c, 'Lv.999', plate, size: 24, color: const Color(0xFFFFE066), stroke: Pal.ink, strokeWidth: 5);
    D.text(c, host.tr('boss', 'BOSS'), plate + const Offset(-74, -12), size: 14, color: Pal.red, stroke: Pal.ink);
  }

  void _heroDraw(Canvas c) {
    final lv = _shownLv.round();
    final grow = 1 + (log(max(1, lv)) / 2.302585) * .12;
    final col = _auraCol(lv);
    final p = _hero + Offset(sin(_t * 30) * _heroHurt * 5, 0);
    // aura
    final ar = 34 * grow + 6 * sin(_t * 6);
    c.drawCircle(p + const Offset(0, -34), ar + 10, D.fill(col.withValues(alpha: .12 + _heroFlash * .25)));
    c.drawCircle(p + const Offset(0, -34), ar, D.fill(col.withValues(alpha: .15 + _heroFlash * .3)));
    if (lv > 999) D.rays(c, p + const Offset(0, -34), 80, col.withValues(alpha: .35), count: 10, t: _t * 2);
    D.shadow(c, p + const Offset(0, 2), 50, 12);
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(grow);
    // cape
    final cape = Path()
      ..moveTo(-14, -52)
      ..lineTo(-24, -8 + sin(_t * 8) * 2)
      ..lineTo(24, -8 - sin(_t * 8) * 2)
      ..lineTo(14, -52)
      ..close();
    c.drawPath(cape, D.fill(Pal.red));
    c.drawPath(cape, D.stroke(Pal.ink, 2.5));
    final moving = _ph == _Ph.walk || _ph == _Ph.scroll;
    D.person(c, Offset.zero, 76, Pal.blue,
        running: moving, run: _t * 18, face: _heroHurt > .3 ? Face.cry : (lv > 999 ? Face.smug : Face.happy),
        hair: const Color(0xFF6B3A1F), armsUp: host.finished && _heroWins ? 1 : 0);
    // sword
    c.save();
    c.translate(19, -45);
    c.rotate(host.finished && _heroWins ? -2.4 : -.5 + sin(_t * 3) * .05);
    c.drawRect(const Rect.fromLTWH(-2.5, -34, 5, 34), D.fill(lv > 999 ? D.hsv(_t * 300, .4, 1) : const Color(0xFFDDE4F0)));
    c.drawRect(const Rect.fromLTWH(-2.5, -34, 5, 34), D.stroke(Pal.ink, 1.5));
    c.drawRect(const Rect.fromLTWH(-8, -2, 16, 4), D.fill(Pal.gold));
    c.restore();
    // helmet
    c.drawArc(Rect.fromCenter(center: const Offset(0, -63), width: 31, height: 26), pi, pi, true, D.fill(const Color(0xFFB9C2D6)));
    c.restore();
    // level badge
    final badge = p + Offset(0, -98 * grow - 14);
    final sc = 1 + _lvPunch * .35;
    c.save();
    c.translate(badge.dx, badge.dy);
    c.scale(sc);
    final txt = 'Lv.$lv';
    D.rrect(c, Rect.fromCenter(center: Offset.zero, width: 26.0 + txt.length * 14, height: 36), 18,
        const Color(0xDD1B1530), border: col, borderWidth: 3);
    D.text(c, txt, Offset.zero, size: 24, color: lv > 999 ? D.hsv(_t * 300, .5, 1) : Pal.white, stroke: Pal.ink, strokeWidth: 5);
    c.restore();
  }
}

enum _Ph { choose, walk, open, scroll, boss }

enum _Mon { slime, bat, orc, dragon, golem, wolf, skeleton }

class _Opt {
  _Opt.add(this.value)
      : mul = false,
        mon = null;
  _Opt.mul(this.value)
      : mul = true,
        mon = null;
  _Opt.mon(this.mon, this.value) : mul = false;
  final int value;
  final bool mul;
  final _Mon? mon;

  String get label => mul ? 'x$value' : (value >= 0 ? '+$value' : '$value');

  int apply(int lv) {
    if (mon != null) return lv > value ? lv + value : max(1, lv ~/ 2);
    return max(1, mul ? lv * value : lv + value);
  }
}
