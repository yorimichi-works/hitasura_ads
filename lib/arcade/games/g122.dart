import 'dart:math' as math;

import '../engine/engine.dart';

/// No.122 Tap Titan — clicker RPG parody.
///
/// Tap anywhere above the shop to hit the monster. Coins rain out of every
/// kill; spend them on SWORD (x5 tap damage) and HERO (hired helpers with
/// auto DPS). 5 stages x 2 monsters, then the TITAN with its own boss timer.
/// Numbers go from 1 to millions within 20 seconds.
class G122 extends MiniGame {
  double _t = 0;
  double _coins = 12;
  double _shownCoins = 12;
  int _swordLv = 0;
  int _heroLv = 0;
  int _stage = 1; // 1..5, 6 = boss
  int _killsInStage = 0;
  static const _perStage = 2;

  double _hp = 1, _maxHp = 1;
  int _kind = 0;
  double _spawnT = 0; // drop-in animation
  double _deadT = -1; // >=0 while the corpse pops
  double _squash = 0;
  double _flash = 0;
  double _heroSwing = 0;
  double _slashT = 0;
  Offset _slashAt = Offset.zero;
  double _slashAng = 0;
  double _heroAtk = 0;
  final List<_Num> _nums = [];
  final List<_Arrow> _arrows = [];
  final List<_FlyCoin> _flyCoins = [];

  // boss
  bool get _boss => _stage == 6;
  double _bossT = 0;
  static const _bossTime = 7.5;
  double _bossRage = 0;

  double _btnPress0 = 0, _btnPress1 = 0;
  double _coinPunch = 0;
  int _taps = 0;
  bool _won = false;

  static const _monsterPos = Offset(180, 300);
  static const _btnSword = Rect.fromLTWH(12, 508, 164, 86);
  static const _btnHero = Rect.fromLTWH(184, 508, 164, 86);

  // --------------------------------------------------------------- numbers
  double get _tapDmg => pow(5, _swordLv).toDouble();
  double get _heroDps => _heroLv == 0 ? 0 : 6 * pow(5, _heroLv - 1).toDouble() * (1 + _swordLv * .2);
  double get _swordCost => (5 * pow(3.1, _swordLv)).roundToDouble();
  double get _heroCost => (14 * pow(3.4, _heroLv)).roundToDouble();
  double get _estDps => _tapDmg * 6.5 + _heroDps;

  @override
  void init() {
    _spawn();
  }

  void _spawn() {
    final m = (_stage - 1) * _perStage + _killsInStage;
    if (_boss) {
      _maxHp = max(4000.0, _estDps * 4.2);
      _kind = 99;
      _bossT = _bossTime;
    } else {
      final base = 6 * pow(2.4, m).toDouble();
      _maxHp = max(base, _estDps * .85);
      _kind = m % 5;
    }
    _maxHp = _roundNice(_maxHp);
    _hp = _maxHp;
    _spawnT = 0;
    _deadT = -1;
  }

  double _roundNice(double v) {
    if (v < 100) return v.roundToDouble();
    final p = pow(10, (math.log(v) / math.ln10).floor() - 1).toDouble();
    return (v / p).round() * p;
  }

  // ---------------------------------------------------------------- update
  @override
  void update(double dt) {
    _t += dt;
    _squash = M.approach(_squash, 0, 14, dt);
    _flash = max(0, _flash - dt);
    _heroSwing = max(0, _heroSwing - dt * 5);
    _slashT = max(0, _slashT - dt);
    _btnPress0 = max(0, _btnPress0 - dt * 5);
    _btnPress1 = max(0, _btnPress1 - dt * 5);
    _coinPunch = M.approach(_coinPunch, 0, 8, dt);
    _shownCoins = M.approach(_shownCoins, _coins, 10, dt);
    if ((_shownCoins - _coins).abs() < 1) _shownCoins = _coins;
    _spawnT += dt;
    for (final n in _nums) {
      n.life -= dt;
      n.pos += n.vel * dt;
      n.vel += Offset(0, 260 * dt);
    }
    _nums.removeWhere((n) => n.life <= 0);
    for (final f in _flyCoins) {
      f.t += dt * 1.8;
    }
    _flyCoins.removeWhere((f) => f.t >= 1);

    if (_won) {

      return;
    }
    if (_deadT >= 0) {
      _deadT += dt;
      if (_deadT > .45 && !host.finished) _next();
      return;
    }
    if (host.finished) return;

    // hired heroes shoot arrows
    if (_heroLv > 0 && _spawnT > .35) {
      _heroAtk -= dt;
      if (_heroAtk <= 0) {
        final n = min(_heroLv, 5);
        _heroAtk = .5 / n;
        final i = randInt(n);
        final from = _heroSeat(i) + const Offset(0, -26);
        _arrows.add(_Arrow(from, _monsterPos + Offset(rand(-40, 40), rand(-30, 30)), _heroDps * .5));
        host.sfx(Sfx.arrow, volume: .25, rate: rand(1, 1.4));
      }
    }
    for (final a in _arrows) {
      a.t += dt * 3.2;
      if (a.t >= 1 && !a.hit) {
        a.hit = true;
        _deal(a.dmg, a.to, crit: false, hero: true);
      }
    }
    _arrows.removeWhere((a) => a.t >= 1);

    if (_boss && _deadT < 0) {
      _bossT -= dt;
      _bossRage = M.approach(_bossRage, _bossT < 2.5 ? 1 : 0, 4, dt);
      if (_bossT <= 0) {
        // Titan heals up and laughs; try again (the real timer keeps ticking)
        _hp = _maxHp;
        _bossT = _bossTime;
        host.sfx(Sfx.buzzer);
        host.shake(8);
        host.flash(const Color(0x88FF0000));
        host.fx.pop(host.tr('retry', 'RETRY'), const Offset(180, 200), color: Pal.red, size: 34);
      }
    }
  }

  void _next() {
    if (_boss) return;
    _killsInStage++;
    if (_killsInStage >= _perStage) {
      _killsInStage = 0;
      _stage++;
      if (_boss) {
        host.sfx(Sfx.horror);
        host.shake(10, .5);
        host.flash(const Color(0x66FF0000));
      } else {
        host.sfx(Sfx.levelup, volume: .7);
        host.fx.pop('${host.tr('stage', 'STAGE')} $_stage', const Offset(180, 160), color: Pal.yellow, size: 30);
      }
    }
    _spawn();
  }

  // ------------------------------------------------------------------ hits
  void _tap(Offset p) {
    if (_deadT >= 0 || _won || _spawnT < .2) return;
    _taps++;
    final crit = chance(.09) || (_taps % 15 == 0);
    final dmg = _tapDmg * (crit ? 10 : 1);
    _heroSwing = 1;
    _slashT = .16;
    _slashAt = p;
    _slashAng = rand(-.9, .9);
    host.sfx(_taps.isEven ? Sfx.slash : Sfx.swing, volume: .6, rate: rand(.9, 1.3));
    _deal(dmg, p, crit: crit, hero: false);
  }

  void _deal(double dmg, Offset at, {required bool crit, required bool hero}) {
    if (_deadT >= 0 || _won) return;
    _hp -= dmg;
    _squash = hero ? max(_squash, .25) : 1;
    _flash = .06;
    _nums.add(_Num(M.big(dmg), at + Offset(rand(-10, 10), -10), Offset(rand(-70, 70), crit ? -330 : -250),
        crit ? Pal.yellow : (hero ? const Color(0xFF7FE9FF) : Pal.white), crit ? 34 : (hero ? 16 : 22), crit ? .9 : .6));
    if (_nums.length > 30) _nums.removeAt(0);
    if (!hero) {
      host.sfx(Sfx.hit, volume: .5, rate: rand(.9, 1.3));
      host.fx.burst(at, Pal.white, count: 5, speed: 180, gravity: 0, life: .25, shape: PartShape.spark);
    }
    if (crit) {
      host.sfx(Sfx.hitHeavy);
      host.shake(5);
      host.fx.pop(host.tr('critical', 'CRITICAL!'), at + const Offset(0, -60), color: Pal.orange, size: 22, life: .5);
      host.fx.burst(at, Pal.yellow, count: 12, speed: 300, shape: PartShape.star, gravity: 200);
    }
    if (_hp <= 0) _kill();
  }

  void _kill() {
    _hp = 0;
    _deadT = 0;
    final reward = _roundNice(_maxHp * (_boss ? 2 : .8) + 4);
    _coins += reward;
    _coinPunch = 1;
    host.sfx(Sfx.explode, volume: .7);
    host.sfx(Sfx.coins, rate: 1 + _stage * .05);
    host.shake(_boss ? 16 : 6, _boss ? .6 : .25);
    host.hitStop(_boss ? .25 : .06);
    host.fx.burst(_monsterPos, _monsterColor, count: 26, speed: 380, size: 9);
    host.fx.coins(_monsterPos, count: 18);
    host.fx.pop('+${M.big(reward)}', _monsterPos + const Offset(0, -110), color: Pal.gold, size: 30);
    for (var i = 0; i < 8; i++) {
      _flyCoins.add(_FlyCoin(_monsterPos + Offset(rand(-60, 60), rand(-40, 40)), -i * .08));
    }
    if (_boss) {
      _won = true;
      host.flash(Pal.white, .3);
      host.sfx(Sfx.fanfare);
      host.fx.confetti();
      host.fx.ring(_monsterPos, Pal.yellow, size: 300, life: .6);
      host.fx.pop(host.tr('ko', 'K.O.!'), const Offset(180, 250), color: Pal.yellow, size: 48, life: 1.4);
      host.win(stars: _bossT > 3.5 ? 3 : (_bossT > 1.5 ? 2 : 1));
    }
  }

  void _buy(int which) {
    if (_won || host.finished) return;
    final cost = which == 0 ? _swordCost : _heroCost;
    if (_coins < cost) {
      host.sfx(Sfx.wrong, volume: .5);
      if (which == 0) {
        _btnPress0 = .5;
      } else {
        _btnPress1 = .5;
      }
      return;
    }
    _coins -= cost;
    final r = which == 0 ? _btnSword : _btnHero;
    if (which == 0) {
      _swordLv++;
      _btnPress0 = 1;
      host.fx.pop('x5 ${host.tr('attack', 'ATK')}', r.center + const Offset(0, -60), color: Pal.orange, size: 24);
    } else {
      _heroLv++;
      _btnPress1 = 1;
      host.fx.pop('+DPS', r.center + const Offset(0, -60), color: const Color(0xFF7FE9FF), size: 24);
      host.fx.burst(_heroSeat(min(_heroLv, 5) - 1), Pal.sky, count: 16, speed: 200, shape: PartShape.star);
    }
    host.sfx(Sfx.powerup, rate: 1 + (_swordLv + _heroLv) * .04);
    host.fx.burst(r.center, Pal.yellow, count: 14, speed: 220, shape: PartShape.star, gravity: 300);
    host.punch(.03);
  }

  @override
  void onDown(Offset p) {
    if (_btnSword.inflate(4).contains(p)) {
      _buy(0);
    } else if (_btnHero.inflate(4).contains(p)) {
      _buy(1);
    } else if (p.dy < 500) {
      _tap(p.dy < 120 ? _monsterPos + Offset(rand(-50, 50), rand(-50, 50)) : p);
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'action' || key == 'up') _tap(_monsterPos + Offset(rand(-50, 50), rand(-50, 50)));
    if (key == 'left') _buy(0);
    if (key == 'right') _buy(1);
  }

  // ---------------------------------------------------------------- render
  Color get _monsterColor => _boss ? const Color(0xFF8A7F9E) : const [Pal.lime, Pal.purple, Pal.red, Color(0xFF55C46A), Color(0xFFBFD8FF)][_kind % 5];

  Offset _heroSeat(int i) => [
        const Offset(40, 470),
        const Offset(320, 470),
        const Offset(78, 440),
        const Offset(282, 440),
        const Offset(300, 405),
      ][i];

  @override
  void render(Canvas c) {
    _renderBg(c);
    // ground platform
    c.drawOval(Rect.fromCenter(center: const Offset(180, 420), width: 300, height: 70), D.fill(const Color(0x33000000)));
    c.drawOval(Rect.fromCenter(center: const Offset(180, 412), width: 280, height: 56), D.fill(const Color(0xFF6BBE4A)));
    c.drawOval(Rect.fromCenter(center: const Offset(180, 412), width: 280, height: 56), D.stroke(const Color(0xFF3C7A2A), 4));
    _renderMonster(c);
    // hired heroes
    for (var i = 0; i < min(_heroLv, 5); i++) {
      final s = _heroSeat(i);
      final bob = sin(_t * 6 + i) * 2;
      D.person(c, s + Offset(0, bob), 44, [Pal.sky, Pal.pink, Pal.orange, Pal.teal, Pal.purple][i],
          flip: s.dx > 180, face: Face.happy, hair: const Color(0xFF3A2A20), armsUp: _heroAtk < .05 ? .6 : 0);
    }
    for (final a in _arrows) {
      final p = Offset.lerp(a.from, a.to, a.t)! + Offset(0, -sin(a.t * pi) * 50);
      final d = a.to - a.from + Offset(0, -cos(a.t * pi) * 150);
      D.line(c, p, p - d / d.distance * 14, const Color(0xFF7A4A22), 3);
      c.drawCircle(p, 3.5, D.fill(const Color(0xFF7FE9FF)));
    }
    _renderPlayerHero(c);
    // slash arc
    if (_slashT > 0) {
      final k = _slashT / .16;
      c.save();
      c.translate(_slashAt.dx, _slashAt.dy);
      c.rotate(_slashAng);
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: 46), -pi * .9, pi * .9 * (1.4 - k), false,
          D.stroke(Color.fromRGBO(255, 255, 255, k), 9 * k + 2));
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: 46), -pi * .9, pi * .9 * (1.4 - k), false,
          D.stroke(Color.fromRGBO(255, 230, 120, k * .6), 18 * k));
      c.restore();
    }
    for (final n in _nums) {
      final a = M.clamp01(n.life / .25);
      if (a < .3) continue;
      D.text(c, n.text, n.pos, size: n.size * (.8 + .2 * a), color: n.color, stroke: Pal.ink, strokeWidth: n.size * .22);
    }
    _renderHud(c);
    _renderShop(c);
    for (final f in _flyCoins) {
      if (f.t < 0) continue;
      final e = M.easeInOut(M.clamp01(f.t));
      final p = Offset.lerp(f.from, const Offset(40, 58), e)! + Offset(0, -sin(e * pi) * 80);
      D.coin(c, p, 9, spin: _t * 2 + f.from.dx);
    }
    if (host.time < 2 && _taps < 3) D.hand(c, _monsterPos + const Offset(30, 20), _t);
    if (!_won && _coins >= _swordCost && _swordLv == 0 && host.time > 1.2 && host.time < 6) {
      D.hand(c, _btnSword.center + const Offset(10, 0), _t);
    }
  }

  void _renderBg(Canvas c) {
    final hue = _boss ? 350.0 : 190 + _stage * 28.0;
    D.gradientBg(c, [D.hsv(hue, .45, _boss ? .35 : .95), D.hsv(hue + 30, .35, _boss ? .55 : 1)]);
    if (_boss) {
      D.rays(c, const Offset(180, 300), 500, Color.fromRGBO(255, 60, 60, .12 + .1 * _bossRage), count: 14, t: _t * .5);
    } else {
      c.drawCircle(const Offset(290, 120), 34, D.fill(const Color(0x66FFFFFF)));
      for (var i = 0; i < 4; i++) {
        final x = (i * 120 + _t * (8 + i * 3)) % 480 - 60;
        D.cloud(c, Offset(x, 110 + i * 38.0), 40 + i * 6, color: const Color(0xCCFFFFFF));
      }
    }
    // mountains (two parallax layers)
    for (var layer = 0; layer < 2; layer++) {
      final col = D.hsv(hue + 40 + layer * 20, .35, _boss ? .25 + layer * .1 : .55 + layer * .12);
      final p = Path()..moveTo(0, 640);
      for (var x = 0.0; x <= 360; x += 40) {
        final h = 300 + layer * 60 + sin(x * .02 + layer * 2 + _stage) * 40 + cos(x * .05 + layer) * 20;
        p.lineTo(x, h);
      }
      p
        ..lineTo(360, 640)
        ..close();
      c.drawPath(p, D.fill(col));
    }
    c.drawRect(const Rect.fromLTWH(0, 400, 360, 240), D.fill(_boss ? const Color(0xFF3B2A3A) : const Color(0xFF4E9A3C)));
    // grass tufts
    final tuft = D.fill(_boss ? const Color(0xFF2A1D2A) : const Color(0xFF3D7F2E));
    for (var i = 0; i < 14; i++) {
      final x = (i * 53.0) % 360, y = 440 + (i * 37) % 60.0;
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 16, height: 6), tuft);
    }
  }

  void _renderMonster(Canvas c) {
    final drop = M.clamp01(_spawnT / .35);
    final y = M.lerp(-200, 0, M.easeOutBack(drop));
    var o = _monsterPos + Offset(0, y);
    var scale = 1.0;
    var alpha = 1.0;
    if (_deadT >= 0) {
      scale = 1 + _deadT * 1.5;
      alpha = M.clamp01(1 - _deadT / .3);
      if (alpha <= 0) return;
    }
    final sq = _squash;
    D.shadow(c, const Offset(180, 405), 170 * (.6 + .4 * drop), 30, .3);
    c.save();
    c.translate(o.dx, o.dy + 90);
    c.scale(scale * (1 + sq * .12), scale * (1 - sq * .12));
    c.translate(0, -90);
    if (alpha < 1) c.saveLayer(const Rect.fromLTWH(-200, -200, 400, 400), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    o = Offset.zero;
    final col = _flash > 0 ? Pal.white : _monsterColor;
    final face = _deadT >= 0 ? Face.dead : (sq > .5 ? Face.shocked : (_hp < _maxHp * .3 ? Face.cry : Face.angry));
    switch (_kind) {
      case 0: // slime
        D.blob(c, o + const Offset(0, 20), 80, col, face: face, squash: 1 + sin(_t * 5) * .05);
      case 1: // winged eyeball
        for (final s in [-1.0, 1.0]) {
          final w = Path()
            ..moveTo(s * 40, -10)
            ..quadraticBezierTo(s * 130, -90 - sin(_t * 12) * 30, s * 140, 10)
            ..quadraticBezierTo(s * 100, 0, s * 90, 30)
            ..quadraticBezierTo(s * 70, 10, s * 40, 25)
            ..close();
          c.drawPath(w, D.fill(const Color(0xFF5B2E8C)));
          c.drawPath(w, D.stroke(Pal.ink, 4));
        }
        c.drawCircle(o, 72, D.fill(_flash > 0 ? Pal.white : const Color(0xFFF7EEF5)));
        c.drawCircle(o, 72, D.stroke(Pal.ink, 5));
        for (var i = 0; i < 5; i++) {
          final a = i * 1.3;
          D.line(c, Offset(cos(a) * 70, sin(a) * 70), Offset(cos(a + .2) * 50, sin(a + .2) * 50), Pal.red, 2.5);
        }
        c.drawCircle(o + const Offset(0, 4), 36, D.fill(col));
        c.drawCircle(o + const Offset(0, 4), 18, D.fill(Pal.ink));
        c.drawCircle(o + const Offset(-10, -6), 7, D.fill(Pal.white));
        if (_deadT >= 0) {
          D.line(c, const Offset(-20, -16), const Offset(20, 24), Pal.white, 6);
          D.line(c, const Offset(20, -16), const Offset(-20, 24), Pal.white, 6);
        }
      case 2: // mushroom
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-44, -10, 88, 100), const Radius.circular(30)),
            D.fill(_flash > 0 ? Pal.white : const Color(0xFFFFE6C4)));
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-44, -10, 88, 100), const Radius.circular(30)), D.stroke(Pal.ink, 5));
        D.face(c, const Offset(0, 36), 40, face);
        final cap = Path()
          ..moveTo(-100, 0)
          ..quadraticBezierTo(-90, -110, 0, -112)
          ..quadraticBezierTo(90, -110, 100, 0)
          ..quadraticBezierTo(0, 20, -100, 0)
          ..close();
        c.drawPath(cap, D.fill(col));
        c.drawPath(cap, D.stroke(Pal.ink, 5));
        for (final s in const [Offset(-50, -40), Offset(10, -80), Offset(50, -30), Offset(-10, -30)]) {
          c.drawCircle(s, 14, D.fill(Pal.white));
        }
      case 3: // goblin with club
        for (final s in [-1.0, 1.0]) {
          final ear = Path()
            ..moveTo(s * 50, -30)
            ..lineTo(s * 120, -60)
            ..lineTo(s * 60, 10)
            ..close();
          c.drawPath(ear, D.fill(col));
          c.drawPath(ear, D.stroke(Pal.ink, 4));
        }
        c.save();
        c.translate(80, 20);
        c.rotate(-.6 + sin(_t * 4) * .15);
        D.rrect(c, const Rect.fromLTWH(-12, -110, 30, 120), 14, Pal.brown, border: Pal.ink, borderWidth: 4);
        c.restore();
        D.blob(c, o + const Offset(0, 16), 74, col, face: face);
        c.drawPath(
            Path()
              ..moveTo(-16, 40)
              ..lineTo(-8, 56)
              ..lineTo(0, 40)
              ..close(),
            D.fill(Pal.white));
      case 4: // ghost
        final g = Path()
          ..moveTo(-80, 80)
          ..lineTo(-80, -10)
          ..quadraticBezierTo(-80, -100, 0, -100)
          ..quadraticBezierTo(80, -100, 80, -10)
          ..lineTo(80, 80);
        for (var i = 0; i < 4; i++) {
          final x = 80 - i * 40.0;
          g.quadraticBezierTo(x - 20, 100 + sin(_t * 8 + i) * 10, x - 40, 80);
        }
        g.close();
        c.drawPath(g, D.fill(col.withValues(alpha: .92)));
        c.drawPath(g, D.stroke(Pal.ink, 5));
        D.face(c, const Offset(0, -10), 60, face);
      case 99: // TITAN
        _renderTitan(c, col, face);
    }
    if (alpha < 1) c.restore();
    c.restore();
    // HP bar
    if (_deadT < 0) {
      final top = _boss ? 110.0 : 150.0;
      final r = Rect.fromLTWH(50, top, 260, 20);
      D.rrect(c, r.inflate(4), 12, const Color(0xCC1B1530));
      D.bar(c, r, _hp / _maxHp, _boss ? Pal.red : Pal.lime, border: Pal.ink);
      D.text(c, '${M.big(max(0, _hp.ceilToDouble()))} / ${M.big(_maxHp)}', r.center, size: 13, color: Pal.white, stroke: Pal.ink, strokeWidth: 3);
    }
  }

  void _renderTitan(Canvas c, Color col, Face face) {
    final rage = _bossRage;
    final shake = Offset(sin(_t * 50) * 2 * rage, 0);
    c.translate(shake.dx, 0);
    // shoulders / arms
    for (final s in [-1.0, 1.0]) {
      c.drawCircle(Offset(s * 110, 10 + sin(_t * 3 + s) * 6), 46, D.fill(Color.lerp(col, Pal.ink, .15)!));
      c.drawCircle(Offset(s * 110, 10 + sin(_t * 3 + s) * 6), 46, D.stroke(Pal.ink, 5));
      c.drawCircle(Offset(s * 124, 70 + sin(_t * 3 + s) * 6), 34, D.fill(col));
      c.drawCircle(Offset(s * 124, 70 + sin(_t * 3 + s) * 6), 34, D.stroke(Pal.ink, 5));
    }
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-95, -120, 190, 210), const Radius.circular(50));
    c.drawRRect(body, D.fill(col));
    c.drawRRect(body, D.stroke(Pal.ink, 6));
    // glowing cracks
    final glow = Color.lerp(const Color(0xFFFF9A1F), Pal.red, rage)!;
    final crack = D.stroke(glow, 5);
    c.drawPath(
        Path()
          ..moveTo(-60, -100)
          ..lineTo(-40, -60)
          ..lineTo(-58, -30)
          ..lineTo(-30, 10),
        crack);
    c.drawPath(
        Path()
          ..moveTo(70, -40)
          ..lineTo(40, 0)
          ..lineTo(58, 40)
          ..lineTo(30, 80),
        crack);
    // brow + eyes
    c.drawRect(const Rect.fromLTWH(-80, -80, 160, 26), D.fill(Color.lerp(col, Pal.ink, .3)!));
    for (final s in [-1.0, 1.0]) {
      c.drawCircle(Offset(s * 38, -44), 20, D.fill(glow.withValues(alpha: .4)));
      c.drawCircle(Offset(s * 38, -44), 12, D.fill(face == Face.dead ? Pal.ink : Pal.yellow));
    }
    // jaw
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-50, 4, 100, 40), const Radius.circular(10)), D.fill(const Color(0xFF2B1A26)));
    for (var i = 0; i < 5; i++) {
      c.drawRect(Rect.fromLTWH(-46 + i * 19.0, 4, 14, 12), D.fill(Pal.white));
    }
    // crown of spikes
    for (var i = 0; i < 5; i++) {
      final x = -64 + i * 32.0;
      c.drawPath(
          Path()
            ..moveTo(x - 12, -118)
            ..lineTo(x, -150 - (i == 2 ? 16 : 0))
            ..lineTo(x + 12, -118)
            ..close(),
          D.fill(Pal.gold));
    }
  }

  void _renderPlayerHero(Canvas c) {
    // the player's knight, bottom-left, lunges on each tap
    final lunge = _heroSwing;
    final o = Offset(110 + lunge * 26, 468);
    D.shadow(c, o + const Offset(0, 4), 50, 12);
    D.person(c, o, 62, Pal.blue, face: lunge > .5 ? Face.angry : Face.smug, hair: const Color(0xFFFFC53D), armsUp: lunge * .3);
    c.save();
    c.translate(o.dx + 10, o.dy - 38);
    c.rotate(-1.2 + lunge * 2.2);
    final glow = _swordLv > 2;
    if (glow) c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -62, 16, 64), const Radius.circular(8)), D.fill(Color.fromRGBO(255, 200, 80, .4 + .2 * sin(_t * 10))));
    D.rrect(c, const Rect.fromLTWH(-4, -56, 8, 50), 3, _swordLv > 4 ? Pal.gold : const Color(0xFFE8EEF7), border: Pal.ink, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(-12, -8, 24, 6), 3, Pal.gold, border: Pal.ink, borderWidth: 2);
    c.restore();
  }

  void _renderHud(Canvas c) {
    // coin counter
    final s = 1 + _coinPunch * .3;
    D.rrect(c, const Rect.fromLTWH(10, 42, 150, 34), 17, const Color(0xCC1B1530), border: Pal.ink, borderWidth: 2);
    D.coin(c, const Offset(30, 59), 12 * s, spin: _t * .5);
    D.text(c, M.big(_shownCoins.floorToDouble()), const Offset(50, 59), size: 20 * s, color: Pal.gold, stroke: Pal.ink, strokeWidth: 4, anchor: Alignment.centerLeft);
    // stage + dots
    D.rrect(c, const Rect.fromLTWH(200, 42, 150, 34), 17, const Color(0xCC1B1530), border: Pal.ink, borderWidth: 2);
    if (_boss) {
      D.text(c, host.tr('boss', 'BOSS'), const Offset(275, 59), size: 18, color: Pal.red, stroke: Pal.ink, strokeWidth: 4);
    } else {
      D.text(c, '${host.tr('stage', 'STAGE')} $_stage/5', const Offset(262, 59), size: 15, color: Pal.white, stroke: Pal.ink, strokeWidth: 3);
      for (var i = 0; i < _perStage; i++) {
        D.circle(c, Offset(322 + i * 13.0, 59), 5, i < _killsInStage ? Pal.lime : const Color(0x55FFFFFF));
      }
    }
    // DPS line
    D.text(c, '${host.tr('attack', 'ATK')} ${M.big(_tapDmg)}   DPS ${M.big(_heroDps)}', const Offset(180, 90),
        size: 13, color: Pal.white, stroke: Pal.ink, strokeWidth: 3);
    // boss timer
    if (_boss && !_won) {
      final r = const Rect.fromLTWH(50, 136, 260, 12);
      D.bar(c, r, _bossT / _bossTime, Color.lerp(Pal.orange, Pal.red, _bossRage)!, border: Pal.ink);
      D.text(c, _bossT.toStringAsFixed(1), Offset(r.right + 22, r.center.dy), size: 14, color: Pal.white, stroke: Pal.ink);
    }
  }

  void _renderShop(Canvas c) {
    D.rrect(c, const Rect.fromLTWH(0, 496, 360, 144), 0, const Color(0xFF2B1D3F),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3D2A58), Color(0xFF1B1530)]));
    D.line(c, const Offset(0, 497), const Offset(360, 497), Pal.gold, 3);
    _shopBtn(c, _btnSword, 0, _swordCost, _swordLv, _btnPress0);
    _shopBtn(c, _btnHero, 1, _heroCost, _heroLv, _btnPress1);
    D.text(c, '${host.tr('upgrade', 'UPGRADE')}!', const Offset(180, 616), size: 14, color: const Color(0x99FFFFFF));
  }

  void _shopBtn(Canvas c, Rect r, int which, double cost, int lv, double press) {
    final can = _coins >= cost;
    final pulse = can ? 1 + sin(_t * 9) * .03 : 1.0;
    c.save();
    c.translate(r.center.dx, r.center.dy);
    c.scale(pulse * (1 - press * .08));
    final rr = Rect.fromCenter(center: Offset.zero, width: r.width, height: r.height);
    final col = can ? (which == 0 ? Pal.orange : Pal.sky) : const Color(0xFF6A6480);
    D.rrect(c, rr.shift(const Offset(0, 5)), 16, Color.lerp(col, Pal.ink, .5)!);
    D.rrect(c, rr, 16, col, border: Pal.ink, borderWidth: 3);
    D.rrect(c, Rect.fromLTWH(rr.left + 6, rr.top + 4, rr.width - 12, 18), 8, const Color(0x44FFFFFF));
    // icon
    final ic = Offset(rr.left + 34, rr.top + 40);
    c.drawCircle(ic, 25, D.fill(const Color(0x33000000)));
    if (which == 0) {
      c.save();
      c.translate(ic.dx, ic.dy);
      c.rotate(pi / 4);
      D.rrect(c, const Rect.fromLTWH(-4, -22, 8, 30), 3, const Color(0xFFE8EEF7), border: Pal.ink, borderWidth: 2);
      D.rrect(c, const Rect.fromLTWH(-11, 7, 22, 5), 2, Pal.gold, border: Pal.ink, borderWidth: 2);
      D.rrect(c, const Rect.fromLTWH(-3, 12, 6, 9), 2, Pal.brown);
      c.restore();
    } else {
      D.person(c, ic + const Offset(0, 20), 40, Pal.pink, face: Face.happy, hair: const Color(0xFF3A2A20));
    }
    D.text(c, which == 0 ? host.tr('sword', 'SWORD') : host.tr('hero', 'HERO'), Offset(rr.left + 108, rr.top + 22),
        size: 15, color: Pal.white, stroke: Pal.ink, strokeWidth: 3, maxWidth: 96);
    D.text(c, '${host.tr('level', 'Lv')}$lv', Offset(rr.left + 108, rr.top + 42), size: 12, color: const Color(0xFFFFF4DC), stroke: Pal.ink, strokeWidth: 3);
    D.coin(c, Offset(rr.left + 82, rr.top + 66), 8);
    D.text(c, M.big(cost), Offset(rr.left + 94, rr.top + 66), size: 16, color: can ? Pal.yellow : const Color(0xFFBBB5CC), stroke: Pal.ink, strokeWidth: 3, anchor: Alignment.centerLeft);
    c.restore();
  }
}

class _Num {
  _Num(this.text, this.pos, this.vel, this.color, this.size, this.life);
  final String text;
  Offset pos;
  Offset vel;
  final Color color;
  final double size;
  double life;
}

class _Arrow {
  _Arrow(this.from, this.to, this.dmg);
  final Offset from, to;
  final double dmg;
  double t = 0;
  bool hit = false;
}

class _FlyCoin {
  _FlyCoin(this.from, this.t);
  final Offset from;
  double t;
}
