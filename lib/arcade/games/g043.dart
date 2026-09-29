import '../engine/engine.dart';

/// No.043 Lemonade Mogul — 4 fast days. Read the forecast, set price & ice,
/// watch the crowd decide. The stand upgrades every day, from a cardboard box
/// to a neon lemon EMPIRE.
class G043 extends MiniGame {
  static const _target = 90;
  // sunny, cloudy, rain, heatwave
  static const _base = [4.0, 3.0, 2.0, 7.0];
  static const _idealIce = [2, 1, 0, 3];
  static const _crowd = [8, 6, 5, 10];
  static const _temp = [28, 20, 14, 38];
  static const _shirts = [Pal.red, Pal.sky, Pal.purple, Pal.lime, Pal.pink, Pal.orange, Pal.teal, Pal.blue];

  late final List<int> _weather;
  final _cust = <_Cust>[];
  final _coinFly = <_CoinFly>[];
  double _t = 0;
  int _day = -1;
  double _dayT = 0;
  double _spawnT = 0;
  int _toSpawn = 0;
  double _price = 3;
  int _ice = 1;
  double _money = 0;
  double _shownMoney = 0;
  bool _dragSlider = false;
  double _banner = 0;
  double _upgrade = 0;
  double _pour = 0;
  double _sky = 0; // lerp helper for weather colors
  int _prevWeather = 0;
  double _moneyBump = 0;
  double _iceBump = 0;
  int _streak = 0;

  double get _dayLen => host.duration / 4;
  int get _w => _weather[max(0, _day)];

  @override
  void init() {
    final mid = [1, 2, 0]..shuffle(host.rng);
    _weather = [0, mid[0], mid[1], 3];
  }

  void _startDay() {
    _day++;
    _dayT = 0;
    _prevWeather = _day == 0 ? _weather[0] : _weather[_day - 1];
    _sky = 0;
    _toSpawn = (_crowd[_w] * (1 + .2 * _day)).round();
    _spawnT = .15;
    _banner = 1;
    if (_day > 0) {
      _upgrade = 1;
      host.sfx(Sfx.levelup);
      host.fx.smoke(const Offset(180, 420), count: 12, color: const Color(0xCCFFFFFF), size: 24);
      host.fx.sparkle(const Offset(180, 380), count: 14, radius: 60, color: Pal.yellow);
      host.fx.pop(host.tr('upgrade', 'UPGRADE!'), const Offset(180, 300), color: Pal.lime, size: 28);
    }
    if (_w == 3) {
      host.sfx(Sfx.fire, volume: .6);
      host.shake(4);
    } else {
      host.sfx(Sfx.whoosh, volume: .6);
    }
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _banner = max(0, _banner - dt / 1.3);
    _upgrade = M.approach(_upgrade, 0, 3, dt);
    _pour = max(0, _pour - dt * 2);
    _sky = M.approach(_sky, 1, 3, dt);
    _moneyBump = M.approach(_moneyBump, 0, 8, dt);
    _iceBump = M.approach(_iceBump, 0, 8, dt);
    _shownMoney = M.approach(_shownMoney, _money, 9, dt);
    if (!host.finished) {
      final dayIdx = min(3, (host.time / _dayLen).floor());
      while (_day < dayIdx) {
        _startDay();
      }
      _dayT += dt;
      _spawnT -= dt;
      if (_spawnT <= 0 && _toSpawn > 0 && _dayT < _dayLen - 1.7) {
        _toSpawn--;
        final left = chance(.55);
        final wtp = _base[_w] * rand(.7, 1.3);
        _cust.add(_Cust(left, Offset(left ? -10 : 370, rand(452, 468)), pick(_shirts), wtp, rand(95, 125) * host.speed));
        final remaining = _dayLen - 1.7 - _dayT;
        _spawnT = _toSpawn > 0 ? max(.12, remaining / (_toSpawn + 1)) * rand(.6, 1.0) : 99;
      }
    }
    for (final cu in _cust) {
      cu.anim += dt;
      cu.bubble = max(0, cu.bubble - dt / 1.6);
      if (cu.state == 1) {
        cu.stopT -= dt;
        if (cu.stopT <= 0) cu.state = 2;
        continue;
      }
      final dir = cu.fromLeft ? 1.0 : -1.0;
      cu.pos += Offset(dir * cu.speed * (cu.state == 2 && cu.bought ? 1.3 : 1) * dt, 0);
      if (cu.state == 0 && (cu.fromLeft ? cu.pos.dx >= 150 : cu.pos.dx <= 210)) _decide(cu);
      if (cu.pos.dx < -40 || cu.pos.dx > 400) cu.gone = true;
    }
    _cust.removeWhere((c) => c.gone);
    for (final f in _coinFly) {
      f.t += dt / .5;
    }
    _coinFly.removeWhere((f) {
      if (f.t >= 1) {
        _moneyBump = 1;
        return true;
      }
      return false;
    });
  }

  void _decide(_Cust cu) {
    final ideal = _idealIce[_w];
    final off = (_ice - ideal).abs();
    final factor = off == 0 ? 1.0 : (off == 1 ? .75 : .45);
    final price = _price.roundToDouble();
    if (price <= cu.wtp * factor) {
      cu.state = 1;
      cu.bought = true;
      cu.stopT = .35;
      cu.face = Face.love;
      _money += price;
      _streak++;
      _pour = 1;
      host.addScore(price.round() * 10);
      host.sfx(Sfx.cash, volume: .6, rate: 1 + min(_streak, 10) * .04);
      host.sfx(Sfx.pour, volume: .3, rate: 1.4);
      _coinFly.add(_CoinFly(cu.pos + const Offset(0, -40)));
      host.fx.pop('+\$${price.round()}', cu.pos + const Offset(0, -80), color: Pal.gold, size: 20 + min(_streak, 8).toDouble());
      if (_streak > 0 && _streak % 5 == 0) {
        host.fx.pop('x$_streak ${host.tr('combo', 'COMBO')}', const Offset(180, 250), color: Pal.pink, size: 24);
        host.fx.coins(const Offset(180, 400), count: 10);
      }
    } else {
      cu.state = 2;
      _streak = 0;
      cu.bubble = 1;
      if (price <= cu.wtp) {
        cu.reason = _ice < ideal ? 1 : 2; // wants more / less ice
        cu.face = _ice < ideal ? Face.dead : Face.shocked;
      } else {
        cu.reason = 0; // too pricey
        cu.face = Face.angry;
      }
      host.sfx(Sfx.wrong, volume: .25, rate: 1.2);
    }
  }

  // ------------------------------------------------------------- input ---
  static const _sx0 = 40.0, _sx1 = 214.0, _sy = 578.0;
  static const _minus = Offset(254, 580), _plus = Offset(336, 580);

  void _setPrice(double x) {
    final t = ((x - _sx0) / (_sx1 - _sx0)).clamp(0.0, 1.0);
    final np = 1 + t * 8;
    if (np.round() != _price.round()) host.sfx(Sfx.tick, volume: .5, rate: .8 + np.round() * .08);
    _price = np;
  }

  @override
  void onDown(Offset p) {
    if ((p - _minus).distance < 28) {
      if (_ice > 0) {
        _ice--;
        _iceBump = 1;
        host.sfx(Sfx.clang, volume: .4, rate: 1.6);
      }
      return;
    }
    if ((p - _plus).distance < 28) {
      if (_ice < 3) {
        _ice++;
        _iceBump = 1;
        host.sfx(Sfx.glass, volume: .35, rate: 1.4);
        host.fx.burst(const Offset(295, 560), Pal.sky, count: 6, speed: 90, size: 5, shape: PartShape.square);
      }
      return;
    }
    if (p.dy > 540 && p.dy < 620 && p.dx < 236) {
      _dragSlider = true;
      _setPrice(p.dx);
    }
  }

  @override
  void onMove(Offset p) {
    if (_dragSlider) _setPrice(p.dx);
  }

  @override
  void onUp(Offset p) {
    if (_dragSlider) _price = _price.roundToDouble();
    _dragSlider = false;
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'left') _price = max(1, _price.roundToDouble() - 1);
    if (key == 'right') _price = min(9, _price.roundToDouble() + 1);
    if (key == 'up') _ice = min(3, _ice + 1);
    if (key == 'down') _ice = max(0, _ice - 1);
  }

  @override
  void onTimeUp() {
    if (_money >= _target) {
      host.sfx(Sfx.fanfare);
      host.fx.confetti(count: 90);
      host.fx.coins(const Offset(180, 420), count: 30, speed: 500);
      host.fx.pop(host.tr('empire', 'EMPIRE!'), const Offset(180, 260), color: Pal.yellow, size: 44, life: 1.4);
      host.win(stars: _money >= 115 ? 3 : (_money >= 100 ? 2 : 1));
    } else {
      host.sfx(Sfx.jingleLose);
      host.fx.pop(host.tr('bankrupt', 'BANKRUPT'), const Offset(180, 260), color: Pal.red, size: 36, life: 1.4);
      host.lose();
    }
  }

  // ------------------------------------------------------------ render ---
  static const _skyTop = [Color(0xFF52B8FF), Color(0xFF8A9AB0), Color(0xFF4A5A78), Color(0xFFFF8A3A)];
  static const _skyBot = [Color(0xFFBFE8FF), Color(0xFFCAD2DC), Color(0xFF8A98B0), Color(0xFFFFE08A)];

  @override
  void render(Canvas c) {
    final w = _day < 0 ? 0 : _w;
    final top = Color.lerp(_skyTop[_prevWeather], _skyTop[w], _sky)!;
    final bot = Color.lerp(_skyBot[_prevWeather], _skyBot[w], _sky)!;
    D.gradientBg(c, [top, bot], rect: const Rect.fromLTWH(0, 0, 360, 470));
    // weather layer
    if (w == 0 || w == 3) {
      final sunR = w == 3 ? 46.0 : 30.0;
      final sp = Offset(290, w == 3 ? 150 : 140);
      D.rays(c, sp, w == 3 ? 260 : 160, Color.fromRGBO(255, 255, 255, w == 3 ? .22 : .16), count: 14, t: _t * .3);
      D.circle(c, sp, sunR + 6, const Color(0x55FFF4B0));
      D.circle(c, sp, sunR, w == 3 ? const Color(0xFFFF6A2A) : Pal.yellow, border: Pal.ink, borderWidth: 3);
      D.face(c, sp, sunR * .8, w == 3 ? Face.dead : Face.happy);
    }
    if (w == 1 || w == 2) {
      for (var i = 0; i < 4; i++) {
        final x = (i * 110 + _t * 14) % 480 - 60;
        D.cloud(c, Offset(x, 130 + (i % 2) * 34.0), 70, color: w == 2 ? const Color(0xFF7A8098) : const Color(0xFFE8ECF4));
      }
    } else {
      D.cloud(c, Offset((_t * 10) % 460 - 50, 128), 50, color: const Color(0xCCFFFFFF));
    }
    // skyline
    for (var i = 0; i < 8; i++) {
      final bw = 40.0 + (i * 13) % 20, bh = 90.0 + (i * 37) % 70;
      final x = i * 46.0 - 6;
      final col = Color.lerp(const Color(0xFF7C8CC8), top, .35)!;
      c.drawRect(Rect.fromLTWH(x, 400 - bh, bw, bh + 20), D.fill(col));
      for (var k = 0; k < 4; k++) {
        c.drawRect(Rect.fromLTWH(x + 8 + (k % 2) * 16, 410 - bh + (k ~/ 2) * 22, 8, 10),
            D.fill(const Color(0x66FFF4B0)));
      }
    }
    // sidewalk
    c.drawRect(const Rect.fromLTWH(0, 400, 360, 90), D.fill(const Color(0xFFC9C3B8)));
    for (var x = 0.0; x < 360; x += 40) {
      c.drawRect(Rect.fromLTWH(x, 400, 2, 90), D.fill(const Color(0x33000000)));
    }
    c.drawRect(const Rect.fromLTWH(0, 398, 360, 4), D.fill(const Color(0xFF9A948A)));
    if (w == 3) {
      // heat shimmer
      for (var i = 0; i < 6; i++) {
        final y = 390 + sin(_t * 3 + i) * 4;
        c.drawLine(Offset(i * 64.0 + (_t * 20) % 64, y), Offset(i * 64.0 + 30 + (_t * 20) % 64, y - 6),
            D.stroke(const Color(0x44FFFFFF), 3));
      }
    }

    // coin stack next to stand
    final stacks = min(36, (_shownMoney / 4).floor());
    for (var i = 0; i < stacks; i++) {
      final col = i ~/ 12, row = i % 12;
      D.coin(c, Offset(252 + col * 22.0, 448 - row * 5.0), 10);
    }

    // customers behind stand (the ones already past) & stand & in front
    for (final cu in _cust) {
      if (cu.pos.dy < 458) _drawCust(c, cu);
    }
    _stand(c);
    for (final cu in _cust) {
      if (cu.pos.dy >= 458) _drawCust(c, cu);
    }
    for (final f in _coinFly) {
      final t = M.easeInOut(f.t.clamp(0.0, 1.0));
      final pos = Offset.lerp(f.from, const Offset(300, 70), t)! + Offset(0, -sin(t * pi) * 60);
      D.coin(c, pos, 9, spin: f.t * 3);
    }
    if (w == 2) {
      final rp = D.stroke(const Color(0x889FC8FF), 2);
      for (var i = 0; i < 40; i++) {
        final x = (i * 53.0 + _t * 60) % 380 - 10;
        final y = (i * 97.0 + _t * 520) % 470;
        c.drawLine(Offset(x, y), Offset(x - 4, y + 12), rp);
      }
    }

    _hud(c);
    _panel(c);

    // day banner
    if (_banner > 0 && _day >= 0) {
      final k = 1 - _banner;
      final s = k < .2 ? M.easeOutBack(k / .2) : 1.0;
      final a = _banner < .25 ? _banner / .25 : 1.0;
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
      c.save();
      c.translate(180, 250);
      c.scale(s);
      D.rrect(c, const Rect.fromLTWH(-120, -56, 240, 112), 22, Pal.white, border: Pal.ink, borderWidth: 4);
      D.text(c, '${host.tr('day', 'DAY')} ${_day + 1}', const Offset(0, -30), size: 26, color: Pal.ink);
      _weatherIcon(c, const Offset(-44, 18), _w, 26);
      D.text(c, '${_temp[_w]}°', const Offset(36, 18), size: 36, color: _w == 3 ? Pal.red : (_w == 2 ? Pal.blue : Pal.orange),
          stroke: Pal.ink, strokeWidth: 5);
      c.restore();
      c.restore();
    }
    // tutorial
    if (!host.finished && host.time < 3.2) {
      final kx = _sx0 + (_price - 1) / 8 * (_sx1 - _sx0);
      D.hand(c, Offset(kx + 20 * sin(_t * 3), _sy + 4), _t);
    } else if (!host.finished && host.time < 5.5 && _day == 0) {
      D.hand(c, _plus + const Offset(0, 4), _t, size: 36);
    }
  }

  void _hud(Canvas c) {
    // forecast chip
    D.rrect(c, const Rect.fromLTWH(10, 44, 150, 50), 16, const Color(0xEEFFFFFF), border: Pal.ink, borderWidth: 3);
    if (_day >= 0) {
      _weatherIcon(c, const Offset(36, 69), _w, 15);
      D.text(c, '${_temp[_w]}°', const Offset(80, 69), size: 22, color: _w == 3 ? Pal.red : Pal.ink);
      for (var i = 0; i < 4; i++) {
        D.circle(c, Offset(118 + i * 11.0, 69), 4, i <= _day ? Pal.orange : const Color(0xFFD0D0DC));
      }
    }
    // money
    final s = 1 + _moneyBump * .2;
    D.rrect(c, const Rect.fromLTWH(172, 44, 178, 50), 16, const Color(0xEE1B1530), border: Pal.ink, borderWidth: 3);
    D.coin(c, const Offset(196, 69), 13, spin: _t * .5);
    c.save();
    c.translate(262, 62);
    c.scale(s);
    D.text(c, '\$${_shownMoney.round()}', Offset.zero, size: 26, color: _money >= _target ? Pal.lime : Pal.gold,
        stroke: Pal.ink, strokeWidth: 5);
    c.restore();
    D.bar(c, const Rect.fromLTWH(214, 80, 124, 8), _shownMoney / _target, _money >= _target ? Pal.lime : Pal.gold);
    D.text(c, '/\$$_target', const Offset(334, 60), size: 12, color: const Color(0xFFB8B0D8), anchor: Alignment.centerRight);
  }

  void _panel(Canvas c) {
    D.rrect(c, const Rect.fromLTWH(8, 494, 344, 138), 22, const Color(0xFFFFF4DC), border: Pal.ink, borderWidth: 4);
    // price
    final price = _price.round();
    final tone = price <= 2 ? Pal.green : (price <= 5 ? Pal.orange : Pal.red);
    D.text(c, '\$$price', const Offset(126, 530), size: 38, color: tone, stroke: Pal.ink, strokeWidth: 6);
    _lemon(c, const Offset(40, 530), 16);
    D.rrect(c, Rect.fromLTWH(_sx0 - 6, _sy - 8, _sx1 - _sx0 + 12, 16), 8, const Color(0xFFE0D2B0), border: Pal.ink, borderWidth: 3);
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(_sx0 - 6, _sy - 8, 12 + (_price - 1) / 8 * (_sx1 - _sx0), 16), const Radius.circular(8)),
        Paint()
          ..shader = const LinearGradient(colors: [Pal.green, Pal.yellow, Pal.red])
              .createShader(Rect.fromLTWH(_sx0, _sy - 8, _sx1 - _sx0, 16)));
    for (var i = 0; i < 9; i++) {
      final x = _sx0 + i / 8 * (_sx1 - _sx0);
      c.drawLine(Offset(x, _sy + 12), Offset(x, _sy + 18), D.stroke(Pal.ink, 2));
    }
    final kx = _sx0 + (_price - 1) / 8 * (_sx1 - _sx0);
    D.circle(c, Offset(kx, _sy), _dragSlider ? 17 : 15, Pal.white, border: Pal.ink, borderWidth: 3.5);
    D.coin(c, Offset(kx, _sy), 9);
    D.text(c, '\$1', const Offset(_sx0, 610), size: 13, color: Pal.ink);
    D.text(c, '\$9', const Offset(_sx1, 610), size: 13, color: Pal.ink);
    // ice
    final gs = 1 + _iceBump * .15;
    c.save();
    c.translate(295, 562);
    c.scale(gs);
    final glass = Path()
      ..moveTo(-22, -34)
      ..lineTo(22, -34)
      ..lineTo(17, 32)
      ..lineTo(-17, 32)
      ..close();
    c.drawPath(glass, D.fill(const Color(0xFFFFF27A)));
    for (var i = 0; i < _ice; i++) {
      final p = Offset(-8.0 + (i % 2) * 14, 18 - i * 15.0);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(.2 * (i.isEven ? 1 : -1));
      D.rrect(c, const Rect.fromLTWH(-8, -8, 16, 16), 4, const Color(0xDDE8FAFF), border: const Color(0xFF7FC8E8), borderWidth: 2);
      c.restore();
    }
    c.drawPath(glass, D.stroke(Pal.ink, 3));
    D.line(c, const Offset(8, -44), const Offset(2, 10), Pal.red, 4);
    c.restore();
    D.text(c, '$_ice', const Offset(295, 614), size: 16, color: Pal.ink);
    for (final (o, lbl) in [(_minus, '-'), (_plus, '+')]) {
      D.circle(c, o + const Offset(0, 3), 19, const Color(0xFF2A6A9A));
      D.circle(c, o, 19, Pal.sky, border: Pal.ink, borderWidth: 3);
      D.text(c, lbl, o + const Offset(0, -1), size: 26, color: Pal.white, stroke: Pal.ink, strokeWidth: 5);
    }
  }

  void _weatherIcon(Canvas c, Offset o, int w, double s) {
    switch (w) {
      case 0:
        D.circle(c, o, s * .8, Pal.yellow, border: Pal.ink, borderWidth: 2.5);
      case 1:
        D.circle(c, o + Offset(s * .3, -s * .3), s * .6, Pal.yellow, border: Pal.ink, borderWidth: 2);
        D.cloud(c, o + Offset(0, s * .2), s * 1.2, color: const Color(0xFFB8C0D0));
      case 2:
        D.cloud(c, o, s * 1.3, color: const Color(0xFF7A8098));
        for (var i = 0; i < 3; i++) {
          D.line(c, o + Offset(-s * .5 + i * s * .5, s * .5), o + Offset(-s * .6 + i * s * .5, s * .9), Pal.sky, 3);
        }
      default:
        D.circle(c, o, s * .9, const Color(0xFFFF6A2A), border: Pal.ink, borderWidth: 2.5);
        D.flame(c, o + Offset(0, s * .5), s * 1.1, _t);
    }
  }

  void _stand(Canvas c) {
    final lvl = max(0, _day);
    final up = _upgrade;
    final s = 1 + sin(up * pi * 3) * up * .12;
    c.save();
    c.translate(180, 452);
    c.scale(1 / s, s);
    D.shadow(c, const Offset(0, 4), 160, 18, .3);
    // owner kid
    D.person(c, const Offset(0, -52), 66, Pal.yellow, face: _pour > 0 ? Face.happy : (lvl >= 3 ? Face.smug : Face.neutral),
        hair: const Color(0xFF6B3A1E), armsUp: _pour);
    switch (lvl) {
      case 0: // cardboard box
        D.rrect(c, const Rect.fromLTWH(-56, -56, 112, 58), 4, const Color(0xFFC8965A), border: Pal.ink, borderWidth: 3);
        c.drawLine(const Offset(-56, -44), const Offset(56, -44), D.stroke(const Color(0xFF9A6A38), 2));
        D.rrect(c, const Rect.fromLTWH(-30, -34, 60, 26), 3, Pal.white, border: Pal.ink, borderWidth: 2);
        _lemon(c, const Offset(0, -21), 10);
      case 1: // wooden stand + awning
        _counter(c, 124, const Color(0xFFB0703A));
        _awning(c, 136, -130, Pal.yellow, Pal.white);
      case 2: // cart with umbrella
        _counter(c, 140, const Color(0xFF3D8BFF));
        D.line(c, const Offset(60, -60), const Offset(60, -140), Pal.ink, 4);
        c.drawArc(const Rect.fromLTWH(10, -170, 100, 60), pi, pi, true, D.fill(Pal.pink));
        c.drawArc(const Rect.fromLTWH(10, -170, 100, 60), pi, pi, true, D.stroke(Pal.ink, 3));
        for (var i = 0; i < 2; i++) {
          D.circle(c, Offset(-50 + i * 100.0, 4), 12, const Color(0xFF444444), border: Pal.ink, borderWidth: 3);
        }
        _awning(c, 110, -120, Pal.lime, Pal.white);
      default: // neon kiosk EMPIRE
        D.rrect(c, const Rect.fromLTWH(-86, -170, 172, 110), 10, const Color(0xFF2A1F4A), border: Pal.ink, borderWidth: 3);
        _counter(c, 172, const Color(0xFFFFC53D));
        final on = (_t * 4).floor() % 3 != 0;
        _lemon(c, const Offset(0, -128), on ? 30 : 28);
        if (on) c.drawCircle(const Offset(0, -128), 44, D.stroke(const Color(0x88FFF27A), 6));
        // crown
        final crown = Path()
          ..moveTo(-22, -84)
          ..lineTo(-22, -104)
          ..lineTo(-11, -94)
          ..lineTo(0, -108)
          ..lineTo(11, -94)
          ..lineTo(22, -104)
          ..lineTo(22, -84)
          ..close();
        c.drawPath(crown, D.fill(Pal.gold));
        c.drawPath(crown, D.stroke(Pal.ink, 2.5));
        for (var i = 0; i < 7; i++) {
          D.circle(c, Offset(-78 + i * 26.0, -164), 4, Pal.candy[(i + (_t * 6).floor()) % 8]);
        }
    }
    // pitcher
    final pour = _pour;
    c.save();
    c.translate(-36, -66);
    c.rotate(-pour * .6);
    D.rrect(c, const Rect.fromLTWH(-12, -24, 24, 28), 6, const Color(0xCCFFF27A), border: Pal.ink, borderWidth: 2.5);
    c.restore();
    if (pour > .3) D.line(c, const Offset(-50, -80), const Offset(-54, -60), const Color(0xFFFFE040), 4);
    c.restore();
  }

  void _counter(Canvas c, double w, Color col) {
    D.rrect(c, Rect.fromLTWH(-w / 2, -62, w, 64), 6, col, border: Pal.ink, borderWidth: 3);
    D.rrect(c, Rect.fromLTWH(-w / 2 - 6, -68, w + 12, 12), 5, Color.lerp(col, Pal.white, .3)!, border: Pal.ink, borderWidth: 3);
    _lemon(c, const Offset(0, -28), 16);
  }

  void _awning(Canvas c, double w, double y, Color a, Color b) {
    D.line(c, Offset(-w / 2 + 6, -60), Offset(-w / 2 + 6, y + 20), Pal.ink, 4);
    D.line(c, Offset(w / 2 - 6, -60), Offset(w / 2 - 6, y + 20), Pal.ink, 4);
    const n = 6;
    final sw = w / n;
    for (var i = 0; i < n; i++) {
      final r = Rect.fromLTWH(-w / 2 + i * sw, y, sw, 26);
      c.drawRect(r, D.fill(i.isEven ? a : b));
      c.drawArc(Rect.fromLTWH(r.left, r.bottom - 8, sw, 16), 0, pi, true, D.fill(i.isEven ? a : b));
    }
    c.drawRect(Rect.fromLTWH(-w / 2, y, w, 26), D.stroke(Pal.ink, 3));
  }

  void _drawCust(Canvas c, _Cust cu) {
    final walking = cu.state != 1;
    D.shadow(c, cu.pos + const Offset(0, 2), 28, 7);
    D.person(c, cu.pos, 62, cu.shirt, running: walking, run: cu.anim * 11, face: cu.face, flip: !cu.fromLeft,
        hair: cu.hair, skin: cu.reason == 1 && cu.bubble > 0 ? const Color(0xFFFFA080) : Pal.skin);
    if (cu.bought) {
      final hand = cu.pos + Offset(cu.fromLeft ? 14 : -14, -40);
      D.rrect(c, Rect.fromCenter(center: hand, width: 12, height: 16), 3, const Color(0xFFFFF27A), border: Pal.ink, borderWidth: 2);
      D.line(c, hand + const Offset(2, -8), hand + const Offset(5, -16), Pal.red, 2);
    }
    if (cu.bubble > 0) {
      final bc = cu.pos + Offset(0, -92 - (1 - cu.bubble) * 10);
      D.bubble(c, Rect.fromCenter(center: bc, width: 46, height: 32), tail: bc + const Offset(0, 24));
      switch (cu.reason) {
        case 0:
          D.text(c, '\$\$!', bc, size: 16, color: Pal.red);
        default:
          D.rrect(c, Rect.fromCenter(center: bc + const Offset(-8, 0), width: 14, height: 14), 3, const Color(0xFFE8FAFF),
              border: const Color(0xFF3FA0D8), borderWidth: 2);
          D.text(c, cu.reason == 1 ? '+' : '-', bc + const Offset(11, -1), size: 20, color: cu.reason == 1 ? Pal.red : Pal.blue);
      }
    }
  }
}

/// Lemon icon (local helper; the engine has none).
void _lemon(Canvas c, Offset o, double s) {
  final body = Path()
    ..moveTo(o.dx - s * 1.25, o.dy)
    ..quadraticBezierTo(o.dx - s, o.dy - s * .95, o.dx, o.dy - s * .85)
    ..quadraticBezierTo(o.dx + s, o.dy - s * .95, o.dx + s * 1.25, o.dy)
    ..quadraticBezierTo(o.dx + s, o.dy + s * .95, o.dx, o.dy + s * .85)
    ..quadraticBezierTo(o.dx - s, o.dy + s * .95, o.dx - s * 1.25, o.dy)
    ..close();
  c.drawPath(body, D.fill(const Color(0xFFFFE03A)));
  c.drawOval(Rect.fromCenter(center: o + Offset(-s * .35, -s * .35), width: s * .7, height: s * .3), D.fill(const Color(0x88FFFFFF)));
  c.drawPath(body, D.stroke(Pal.ink, max(1.5, s * .14)));
  c.drawOval(Rect.fromCenter(center: o + Offset(s * .5, -s * .9), width: s * .9, height: s * .4), D.fill(Pal.green));
}

class _Cust {
  _Cust(this.fromLeft, this.pos, this.shirt, this.wtp, this.speed)
      : hair = const [Color(0xFF3A2A20), Color(0xFFE0B040), Color(0xFFD9502B), Color(0xFF222244)][(wtp * 100).floor() % 4];
  final bool fromLeft;
  Offset pos;
  final Color shirt;
  final Color hair;
  final double wtp;
  final double speed;
  int state = 0; // 0 approaching, 1 buying, 2 leaving
  bool bought = false;
  double stopT = 0;
  double anim = 0;
  double bubble = 0;
  int reason = 0;
  Face face = Face.neutral;
  bool gone = false;
}

class _CoinFly {
  _CoinFly(this.from);
  final Offset from;
  double t = 0;
}
