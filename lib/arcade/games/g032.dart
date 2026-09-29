import '../engine/engine.dart';

/// No.032 Konbini Cashier — drag each item across the scanner laser (BEEP!),
/// then tap coins from the cash drawer to count out the exact change.
/// Serve 3 customers from the queue of 4 before they lose patience.
class G032 extends MiniGame {
  static const _goal = 3;
  static const _laserX = 252.0;
  static const _beltY = 318.0;
  static const _prices = [130, 150, 480, 180, 210, 240];
  static const _coinVals = [500, 100, 50, 10];
  static const _drawerX = [52.0, 138.0, 222.0, 308.0];
  static const _drawerY = 580.0;
  static const _bagPos = Offset(322, 318);

  int _phase = 0; // 0 arrive, 1 scan, 2 pay anim, 3 change, 4 leave
  double _phaseT = 0;
  int _served = 0;
  int _strikes = 0;
  int _queueLeft = 4;
  int _custIndex = 0;
  late _Shopper _cust;
  final List<_Shopper> _queue = [];
  final List<_Item> _items = [];
  _Item? _held;
  Offset _grab = Offset.zero;
  Offset _lastHeld = Offset.zero;
  int _total = 0;
  int _paid = 0;
  int _need = 0;
  int _given = 0;
  final List<_GivenCoin> _givenCoins = [];
  double _patience = 1;
  double _patienceMax = 1;
  double _laserFlash = 0;
  double _drawerOpen = 0;
  double _lcdBump = 0;
  final List<double> _press = List.filled(4, 0);
  double _t = 0;
  int _combo = 0;
  double _money = 0;
  double _shown = 0;
  double _bagBump = 0;
  bool _mad = false;
  bool _happy = false;

  @override
  void init() {
    for (var i = 0; i < 4; i++) {
      _queue.add(_Shopper(
        pick(const [Pal.sky, Pal.pink, Pal.lime, Pal.purple, Pal.orange, Pal.teal, Pal.red]),
        pick(const [Color(0xFF2B1D16), Color(0xFF6B3B1E), Color(0xFFE8C04A), Color(0xFF3B3B5A), Color(0xFFB0B0B8)]),
      ));
    }
    _nextCustomer();
  }

  void _nextCustomer() {
    if (_queue.isEmpty) return;
    _cust = _queue.removeAt(0);
    _queueLeft = _queue.length;
    _custIndex++;
    _phase = 0;
    _phaseT = 0;
    _mad = false;
    _happy = false;
    _total = 0;
    _given = 0;
    _givenCoins.clear();
    _items.clear();
    final n = _custIndex == 1 ? 2 : (chance(.5) ? 2 : 3);
    for (var i = 0; i < n; i++) {
      _items.add(_Item(randInt(_prices.length), Offset(-60.0 - i * 64, _beltY)));
    }
    _patienceMax = (11.5 + n * 1.2) / host.speed;
    _patience = _patienceMax;
  }

  int _coinCount(int v) {
    var n = 0;
    for (final d in _coinVals) {
      n += v ~/ d;
      v %= d;
    }
    return n;
  }

  void _startPay() {
    _phase = 2;
    _phaseT = 0;
    final t = _total;
    final opts = <int>[
      ((t + 99) ~/ 100) * 100,
      ((t + 499) ~/ 500) * 500,
      ((t + 999) ~/ 1000) * 1000,
    ].where((b) => b > t && _coinCount(b - t) <= 5).toList();
    _paid = opts.isEmpty ? ((t ~/ 1000) + 1) * 1000 : pick(opts);
    _need = _paid - t;
    host.sfx(Sfx.cash);
    host.sfx(Sfx.open, volume: .6);
  }

  @override
  void update(double dt) {
    _t += dt;
    _phaseT += dt;
    _laserFlash = M.approach(_laserFlash, 0, 8, dt);
    _lcdBump = M.approach(_lcdBump, 0, 9, dt);
    _bagBump = M.approach(_bagBump, 0, 8, dt);
    _shown = M.approach(_shown, _money, 7, dt);
    for (var i = 0; i < 4; i++) {
      _press[i] = M.approach(_press[i], 0, 10, dt);
    }
    _drawerOpen = M.approach(_drawerOpen, _phase == 3 ? 1 : 0, 10, dt);

    if ((_phase == 1 || _phase == 3) && !host.finished) {
      _patience -= dt;
      if (_patience <= 0) {
        _mad = true;
        _strikes++;
        _combo = 0;
        _held = null;
        host.sfx(Sfx.buzzer);
        host.shake(8);
        host.fx.smoke(const Offset(160, 90), count: 8, color: const Color(0xCCFF6060));
        host.fx.pop(host.tr('angry', 'ANGRY!'), const Offset(160, 70), color: Pal.red, size: 30);
        _phase = 4;
        _phaseT = 0;
        if (_strikes >= 2 || _queue.isEmpty) host.lose();
      }
    }

    switch (_phase) {
      case 0:
        if (_phaseT > .55) {
          _phase = 1;
          _phaseT = 0;
        }
      case 2:
        if (_phaseT > .6) {
          _phase = 3;
          _phaseT = 0;
          host.sfx(Sfx.clang, volume: .5);
        }
      case 4:
        if (_phaseT > .7 && !host.finished) {
          if (_queue.isEmpty) {
            host.lose();
          } else {
            _nextCustomer();
          }
        }
    }

    // belt: unscanned items slide to their slot
    var slot = 0;
    for (final it in _items) {
      if (it.scanned) {
        it.bagT += dt * 2.6;
        if (it.bagT >= 1 && !it.bagged) {
          it.bagged = true;
          _bagBump = 1;
          host.sfx(Sfx.rip, volume: .35, rate: 1.4);
        }
        continue;
      }
      if (identical(it, _held)) continue;
      final tx = 196.0 - slot * 62;
      slot++;
      final nx = min(tx, it.pos.dx + 260 * dt);
      it.pos = Offset(nx, M.approach(it.pos.dy, _beltY, 12, dt));
    }
    for (final g in _givenCoins) {
      g.t = min(1, g.t + dt * 4);
    }
  }

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    if (_phase == 1) {
      for (final it in _items.reversed) {
        if (it.scanned) continue;
        if ((p - it.pos).distance < 40) {
          _held = it;
          _grab = it.pos - p;
          _lastHeld = it.pos;
          it.wob = 1;
          host.sfx(Sfx.pickup, volume: .5);
          return;
        }
      }
    } else if (_phase == 3) {
      for (var i = 0; i < 4; i++) {
        if ((p - Offset(_drawerX[i], _drawerY)).distance < 44) {
          _press[i] = 1;
          _giveCoin(i);
          return;
        }
      }
    }
  }

  void _giveCoin(int i) {
    final v = _coinVals[i];
    final from = Offset(_drawerX[i], _drawerY);
    if (_given + v > _need) {
      host.sfx(Sfx.wrong);
      host.sfx(Sfx.coins, volume: .4, rate: .8);
      host.shake(6);
      host.fx.pop(host.tr('too_much', 'TOO MUCH!'), const Offset(180, 450), color: Pal.red, size: 26);
      for (final g in _givenCoins) {
        host.fx.burst(g.target, const Color(0xFFD0D4DA), count: 3, speed: 200, gravity: 800);
      }
      _givenCoins.clear();
      _given = 0;
      _combo = 0;
      _patience -= 1.2;
      return;
    }
    _given += v;
    final idx = _givenCoins.length;
    _givenCoins.add(_GivenCoin(v, from, Offset(42 + (idx % 8) * 38.0, 486)));
    host.sfx(Sfx.coin, rate: 1 + idx * .08);
    _lcdBump = 1;
    if (_given == _need) {
      _complete();
    }
  }

  void _complete() {
    _served++;
    _combo++;
    _happy = true;
    final pay = _total;
    _money += pay;
    host.addScore(pay);
    final speedBonus = _patience / _patienceMax;
    host.sfx(Sfx.cash, rate: 1.05);
    host.sfx(Sfx.correct, volume: .6);
    host.punch(.04);
    host.fx.coins(const Offset(180, 470), count: 16);
    host.fx.burst(const Offset(180, 160), Pal.yellow, count: 16, speed: 260, shape: PartShape.star,
        colors: const [Pal.yellow, Pal.white, Pal.lime]);
    host.fx.pop(host.tr(speedBonus > .5 ? 'perfect' : 'nice', speedBonus > .5 ? 'PERFECT!' : 'NICE!'),
        const Offset(180, 140), color: Pal.lime, size: 32, life: 1);
    if (_combo >= 2) host.fx.pop('${host.tr('combo', 'COMBO')} x$_combo', const Offset(180, 105), color: Pal.pink, size: 22);
    _phase = 4;
    _phaseT = 0;
    if (_served >= _goal && !host.finished) {
      host.fx.confetti();
      host.sfx(Sfx.fanfare);
      final tm = host.time;
      host.win(stars: _strikes == 0 && tm < 15 ? 3 : (tm < 18 && _strikes == 0 ? 2 : 1));
    }
  }

  @override
  void onMove(Offset p) {
    final it = _held;
    if (it == null) return;
    final np = Offset((p + _grab).dx.clamp(10.0, 350.0), (p + _grab).dy.clamp(240.0, 400.0));
    if (_lastHeld.dx < _laserX && np.dx >= _laserX && (np.dy - _beltY).abs() < 70) {
      _scan(it);
      return;
    }
    it.pos = np;
    _lastHeld = np;
  }

  void _scan(_Item it) {
    it.scanned = true;
    it.from = Offset(_laserX, it.pos.dy);
    it.pos = it.from;
    _held = null;
    _total += _prices[it.kind];
    _laserFlash = 1;
    _lcdBump = 1;
    host.sfx(Sfx.scan, rate: 1 + _items.where((e) => e.scanned).length * .1);
    host.sfx(Sfx.beep, volume: .6);
    host.fx.sparkle(it.from, count: 6, radius: 20, color: Pal.lime);
    host.fx.pop('${_prices[it.kind]}', it.from + const Offset(0, -46), color: Pal.white, size: 22);
    host.addScore(10);
    if (_items.every((e) => e.scanned)) {
      _startPay();
    }
  }

  @override
  void onUp(Offset p) {
    if (_held != null) {
      host.sfx(Sfx.land, volume: .3);
      _held = null;
    }
  }

  // ----------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    _drawStore(c);
    _drawQueue(c);
    _drawCustomer(c);
    _drawRegister(c);
    _drawCounter(c);
    _drawDrawer(c);
    for (final it in _items) {
      if (it.scanned) {
        if (it.bagT < 1) {
          final t = M.easeInOut(it.bagT);
          final p = Offset.lerp(it.from, _bagPos + const Offset(0, -10), t)! + Offset(0, -sin(t * pi) * 60);
          _drawItem(c, it.kind, p, 1 - t * .5, t * 4);
        }
        continue;
      }
      final held = identical(it, _held);
      if (!held) D.shadow(c, Offset(it.pos.dx, _beltY + 28), 50, 10, .3);
      _drawItem(c, it.kind, it.pos, held ? 1.12 : 1, held ? sin(_t * 12) * .08 : 0);
      if (held) {
        // price tag preview + barcode glow
        D.text(c, '${_prices[it.kind]}', it.pos + const Offset(0, -44), size: 16, color: Pal.yellow, stroke: Pal.ink);
      }
    }
    _drawHud(c);
    _drawHint(c);
  }

  void _drawStore(Canvas c) {
    D.gradientBg(c, const [Color(0xFFF7F4EA), Color(0xFFE0E8EE)], rect: const Rect.fromLTWH(0, 0, 360, 262));
    // ceiling lights
    for (var i = 0; i < 3; i++) {
      final x = 30 + i * 120.0;
      D.rrect(c, Rect.fromLTWH(x, 40, 90, 8), 4, const Color(0xFFFFFFFF), border: const Color(0xFFB8C4CC), borderWidth: 1.5);
      c.drawRect(Rect.fromLTWH(x - 10, 48, 110, 20), Paint()..color = const Color(0x22FFFFFF));
    }
    // brand stripe
    c.drawRect(const Rect.fromLTWH(0, 70, 360, 8), D.fill(const Color(0xFF2EA84F)));
    c.drawRect(const Rect.fromLTWH(0, 78, 360, 6), D.fill(const Color(0xFFFF8A1F)));
    c.drawRect(const Rect.fromLTWH(0, 84, 360, 5), D.fill(const Color(0xFFE8322C)));
    // shelves with goods
    const cols = [Pal.red, Pal.yellow, Pal.sky, Pal.lime, Pal.pink, Pal.orange, Pal.purple, Pal.teal];
    for (var r = 0; r < 3; r++) {
      final y = 104 + r * 50.0;
      c.drawRect(Rect.fromLTWH(0, y + 36, 360, 7), D.fill(const Color(0xFF9DA8B3)));
      for (var k = 0; k < 14; k++) {
        final x = 4 + k * 26.0;
        final col = cols[(k * 3 + r * 5) % cols.length];
        final h = 22.0 + ((k * 7 + r * 3) % 4) * 4;
        D.rrect(c, Rect.fromLTWH(x, y + 36 - h, 20, h), 3, Color.lerp(col, Pal.white, .25)!);
        c.drawRect(Rect.fromLTWH(x + 3, y + 36 - h + 5, 14, 4), D.fill(const Color(0x88FFFFFF)));
      }
    }
    // floor
    c.drawRect(const Rect.fromLTWH(0, 250, 360, 14), D.fill(const Color(0xFFC9D3DA)));
  }

  void _drawQueue(Canvas c) {
    for (var i = min(_queue.length, 3) - 1; i >= 0; i--) {
      final s = _queue[i];
      final x = 36.0 + i * 34;
      final h = 128.0 - i * 12;
      final impatient = _phase == 1 || _phase == 3 ? sin(_t * (6 + i) + i) * 2 : 0.0;
      D.person(c, Offset(x + impatient, 262), h, Color.lerp(s.shirt, const Color(0xFFE0E8EE), .35)!,
          hair: s.hair, face: _patience / _patienceMax < .35 ? Face.angry : Face.neutral, flip: true);
    }
  }

  void _drawCustomer(Canvas c) {
    double x = 168;
    if (_phase == 0) x = M.lerp(40, 168, M.easeOutBack((_phaseT / .55).clamp(0.0, 1.0)));
    if (_phase == 4) x = M.lerp(168, 420, M.easeInOut((_phaseT / .7).clamp(0.0, 1.0)));
    final ratio = (_patience / _patienceMax).clamp(0.0, 1.0);
    Face f;
    if (_mad) {
      f = Face.angry;
    } else if (_happy) {
      f = Face.love;
    } else if (ratio > .55) {
      f = Face.happy;
    } else if (ratio > .28) {
      f = Face.neutral;
    } else {
      f = Face.shocked;
    }
    final tap = ratio < .3 && (_phase == 1 || _phase == 3) ? sin(_t * 30) * 2 : 0.0;
    D.person(c, Offset(x + tap, 330), 230, _cust.shirt, hair: _cust.hair, face: f, armsUp: _happy ? .6 : 0);
    if (_phase == 1 || _phase == 3) {
      final col = ratio > .55 ? Pal.green : (ratio > .28 ? Pal.yellow : Pal.red);
      D.bar(c, Rect.fromLTWH(x - 44, 100, 88, 10), ratio, col, border: Pal.ink);
    }
    if (_phase == 2 || _phase == 3) {
      // handed banknote
      final p = _phase == 2 ? Offset.lerp(Offset(x - 60, 200), const Offset(90, 150), M.easeOutBack(min(1, _phaseT * 2)))! : const Offset(90, 150);
      _note(c, p, _paid);
    }
    if (_mad && _phase == 4) {
      D.text(c, '#', Offset(x + 30, 120), size: 30, color: Pal.red, stroke: Pal.ink);
    }
  }

  void _note(Canvas c, Offset p, int v) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(-.12 + sin(_t * 3) * .03);
    D.rrect(c, const Rect.fromLTWH(-48, -24, 96, 48), 5, const Color(0xFFD7E8C8),
        gradient: const LinearGradient(colors: [Color(0xFFE6F1D6), Color(0xFFC7DDB3)]), border: Pal.ink, borderWidth: 2.5);
    c.drawOval(Rect.fromCenter(center: const Offset(22, 0), width: 26, height: 32), D.fill(const Color(0x55809070)));
    D.text(c, '$v', const Offset(-12, 0), size: 20, color: const Color(0xFF2F4A2A));
    c.restore();
  }

  void _drawRegister(Canvas c) {
    // pole + LCD
    D.rrect(c, const Rect.fromLTWH(286, 150, 14, 100), 4, const Color(0xFF3A3E49));
    final s = 1 + _lcdBump * .08;
    c.save();
    c.translate(293, 150);
    c.scale(s);
    D.rrect(c, const Rect.fromLTWH(-62, -36, 124, 64), 10, const Color(0xFF3A3E49), border: Pal.ink, borderWidth: 3);
    D.rrect(c, const Rect.fromLTWH(-54, -28, 108, 48), 6, const Color(0xFF123524));
    final showChange = _phase == 3;
    final label = showChange ? host.tr('change', 'CHANGE') : host.tr('total', 'TOTAL');
    D.text(c, label, const Offset(0, -17), size: 11, color: const Color(0xFF7CFFB0), maxWidth: 100);
    final v = showChange ? _need - _given : _total;
    D.text(c, '$v', const Offset(0, 6), size: 24, color: const Color(0xFF9DFFC8), family: null);
    c.restore();
  }

  void _drawCounter(Canvas c) {
    // counter body
    D.rrect(c, const Rect.fromLTWH(-10, 256, 380, 142), 0, const Color(0xFF6A7380),
        gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD6DCE2), Color(0xFFA9B2BC)]));
    c.drawRect(const Rect.fromLTWH(0, 256, 360, 5), D.fill(const Color(0xFFFFFFFF)));
    // belt
    final belt = RRect.fromRectAndRadius(const Rect.fromLTWH(-20, 284, 248, 74), const Radius.circular(12));
    c.drawRRect(belt, D.fill(const Color(0xFF2C2F38)));
    c.save();
    c.clipRRect(belt);
    final off = (_t * 90) % 24;
    for (var x = -30.0 + off; x < 240; x += 24) {
      c.drawLine(Offset(x, 288), Offset(x, 354), D.stroke(const Color(0xFF3E424D), 5));
    }
    c.restore();
    c.drawRRect(belt, D.stroke(Pal.ink, 3));
    // scanner glass
    D.rrect(c, const Rect.fromLTWH(228, 282, 50, 78), 8, const Color(0xFF1B2230), border: Pal.ink, borderWidth: 3);
    D.rrect(c, const Rect.fromLTWH(234, 290, 38, 62), 5, const Color(0xFF2B3A50));
    final glow = .5 + .5 * sin(_t * 20);
    final lcol = Color.lerp(const Color(0xFFFF2040), Pal.lime, _laserFlash)!;
    c.drawRect(Rect.fromLTWH(_laserX - 7, 262, 14, 110), Paint()..color = lcol.withValues(alpha: .18 + _laserFlash * .3));
    c.drawLine(const Offset(_laserX, 266), const Offset(_laserX, 370), D.stroke(lcol.withValues(alpha: .6 + glow * .4), 3));
    for (var k = 0; k < 4; k++) {
      c.drawLine(Offset(_laserX - 12, 296 + k * 16.0), Offset(_laserX + 12, 300 + k * 16.0),
          D.stroke(lcol.withValues(alpha: .35), 1.5));
    }
    // bag area
    D.rrect(c, const Rect.fromLTWH(284, 280, 72, 84), 8, const Color(0xFFBFC7D0), border: const Color(0xFF7D8793), borderWidth: 2);
    final bs = 1 + _bagBump * .1;
    c.save();
    c.translate(_bagPos.dx, _bagPos.dy + 10);
    c.scale(bs, 2 - bs);
    final bag = Path()
      ..moveTo(-26, -24)
      ..lineTo(26, -24)
      ..lineTo(30, 30)
      ..lineTo(-30, 30)
      ..close();
    c.drawPath(bag, D.fill(const Color(0xFFF8F8FF)));
    c.drawPath(bag, D.stroke(Pal.ink, 2.5));
    c.drawArc(const Rect.fromLTWH(-20, -40, 14, 26), pi, pi, false, D.stroke(Pal.ink, 2.5));
    c.drawArc(const Rect.fromLTWH(6, -40, 14, 26), pi, pi, false, D.stroke(Pal.ink, 2.5));
    c.drawRect(const Rect.fromLTWH(-30, 4, 60, 5), D.fill(const Color(0xFF2EA84F)));
    c.drawRect(const Rect.fromLTWH(-30, 9, 60, 4), D.fill(const Color(0xFFFF8A1F)));
    c.restore();
    // progress chips on the counter edge
    for (var i = 0; i < _items.length; i++) {
      final done = _items[i].scanned;
      c.drawCircle(Offset(16 + i * 18.0, 270), 6, D.fill(done ? Pal.lime : const Color(0x55000000)));
    }
  }

  void _drawDrawer(Canvas c) {
    // lower counter panel
    c.drawRect(const Rect.fromLTWH(0, 398, 360, 242), D.fill(const Color(0xFF394150)));
    for (var y = 410.0; y < 640; y += 30) {
      c.drawLine(Offset(0, y), Offset(360, y), D.stroke(const Color(0xFF424B5C), 2));
    }
    // change tray / display
    D.rrect(c, const Rect.fromLTWH(12, 406, 336, 104), 14, const Color(0xFF232833), border: Pal.ink, borderWidth: 3);
    if (_phase == 3) {
      D.text(c, host.tr('change', 'CHANGE'), const Offset(60, 428), size: 14, color: Pal.gold, maxWidth: 100);
      D.text(c, '${_need - _given}', const Offset(60, 452), size: 30, color: Pal.white, stroke: Pal.ink);
      D.text(c, '$_paid - $_total', const Offset(250, 432), size: 15, color: const Color(0xFF9AA4B0));
    } else if (_phase == 1) {
      D.text(c, host.tr('scan', 'SCAN!'), const Offset(180, 438), size: 22, color: const Color(0x88FFFFFF));
    }
    for (final g in _givenCoins) {
      final t = M.easeOutBack(g.t);
      final p = Offset.lerp(g.from, g.target, t)! + Offset(0, -sin(g.t * pi) * 40);
      _coin(c, p, g.v, _coinR(g.v) * .8);
    }
    // drawer
    final dy = (1 - _drawerOpen) * 20;
    D.rrect(c, Rect.fromLTWH(8, 526 + dy, 344, 110), 12, const Color(0xFF1B1E26), border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < 4; i++) {
      final x = _drawerX[i];
      final r = Rect.fromCenter(center: Offset(x, _drawerY + dy + 2), width: 78, height: 92);
      D.rrect(c, r, 10, const Color(0xFF2E3440), border: const Color(0xFF4A5264), borderWidth: 2);
      final pr = _press[i];
      for (var k = 0; k < 3; k++) {
        _coin(c, Offset(x + (k - 1) * 8.0, _drawerY + dy + 18 - k * 5.0 + pr * 4), _coinVals[i], _coinR(_coinVals[i]) * (1 - pr * .1));
      }
      if (_phase != 3) {
        c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)), D.fill(const Color(0x88000000)));
      }
    }
    if (_phase != 3) {
      // closed drawer front
      final front = Rect.fromLTWH(8, 526 + dy - 2 + _drawerOpen * 80, 344, 20);
      D.rrect(c, front, 6, const Color(0xFF4A5264), border: Pal.ink, borderWidth: 2);
      D.rrect(c, Rect.fromCenter(center: front.center, width: 60, height: 8), 4, const Color(0xFF9AA4B0));
    }
  }

  double _coinR(int v) => switch (v) { 500 => 30, 100 => 27, 50 => 25, _ => 26 };

  void _coin(Canvas c, Offset o, int v, double r) {
    final base = switch (v) {
      500 => const Color(0xFFE2BE55),
      100 => const Color(0xFFD5D9DF),
      50 => const Color(0xFFE6E9EE),
      _ => const Color(0xFFCB7B45),
    };
    final dark = Color.lerp(base, Pal.ink, .4)!;
    c.drawCircle(o + const Offset(0, 3), r, D.fill(dark));
    c.drawCircle(o, r, D.fill(base));
    c.drawCircle(o, r * .82, D.stroke(Color.lerp(base, Pal.white, .45)!, 2));
    c.drawCircle(o, r, D.stroke(Pal.ink, 2.2));
    if (v == 50) {
      c.drawCircle(o, r * .22, D.fill(const Color(0xFF232833)));
      c.drawCircle(o, r * .22, D.stroke(Pal.ink, 1.5));
      D.text(c, '50', o + Offset(0, -r * .52), size: r * .42, color: Color.lerp(base, Pal.ink, .6)!);
    } else {
      D.text(c, '$v', o, size: r * (v >= 100 ? .62 : .7), color: Color.lerp(base, Pal.ink, .6)!);
    }
    c.drawOval(Rect.fromCenter(center: o + Offset(-r * .4, -r * .45), width: r * .4, height: r * .22),
        D.fill(const Color(0x88FFFFFF)));
  }

  void _drawItem(Canvas c, int kind, Offset o, double s, double rot) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(rot);
    c.scale(s);
    switch (kind) {
      case 0: // onigiri
        final tri = Path()
          ..moveTo(0, -28)
          ..quadraticBezierTo(6, -30, 28, 16)
          ..quadraticBezierTo(30, 24, 20, 24)
          ..lineTo(-20, 24)
          ..quadraticBezierTo(-30, 24, -28, 16)
          ..quadraticBezierTo(-6, -30, 0, -28)
          ..close();
        c.drawPath(tri, D.fill(Pal.white));
        c.drawRect(const Rect.fromLTWH(-13, 4, 26, 20), D.fill(const Color(0xFF1E3B24)));
        c.drawPath(tri, D.stroke(Pal.ink, 2.5));
        c.drawRect(const Rect.fromLTWH(-28, -4, 56, 5), D.fill(const Color(0xAAE8322C)));
      case 1: // can
        D.rrect(c, const Rect.fromLTWH(-17, -28, 34, 56), 7, const Color(0xFFE8322C),
            gradient: const LinearGradient(colors: [Color(0xFFB81E22), Color(0xFFFF6A5C), Color(0xFFC0242A)]),
            border: Pal.ink, borderWidth: 2.5);
        c.drawRect(const Rect.fromLTWH(-17, -6, 34, 12), D.fill(Pal.white));
        c.drawCircle(Offset.zero, 4, D.fill(const Color(0xFFE8322C)));
        c.drawOval(const Rect.fromLTWH(-15, -32, 30, 8), D.fill(const Color(0xFFCFD5DC)));
        c.drawOval(const Rect.fromLTWH(-15, -32, 30, 8), D.stroke(Pal.ink, 2));
      case 2: // bento
        D.rrect(c, const Rect.fromLTWH(-30, -18, 60, 38), 6, const Color(0xFF1B1530), border: Pal.ink, borderWidth: 2.5);
        D.rrect(c, const Rect.fromLTWH(-26, -14, 26, 30), 3, Pal.white);
        c.drawCircle(const Offset(-13, 0), 4, D.fill(const Color(0xFFE8322C)));
        D.rrect(c, const Rect.fromLTWH(2, -14, 24, 14), 3, const Color(0xFFB0662C));
        D.rrect(c, const Rect.fromLTWH(2, 2, 24, 14), 3, Pal.lime);
        c.drawRect(const Rect.fromLTWH(-32, -20, 64, 42), D.fill(const Color(0x33FFFFFF)));
        D.rrect(c, const Rect.fromLTWH(-8, -22, 16, 46), 2, const Color(0xCCFF8A1F));
      case 3: // chips
        final bag = Path()
          ..moveTo(-24, -28)
          ..quadraticBezierTo(0, -22, 24, -28)
          ..quadraticBezierTo(30, 0, 24, 28)
          ..quadraticBezierTo(0, 22, -24, 28)
          ..quadraticBezierTo(-30, 0, -24, -28)
          ..close();
        c.drawPath(bag, D.fill(Pal.yellow));
        c.drawCircle(const Offset(0, 2), 12, D.fill(Pal.orange));
        D.star(c, const Offset(0, 2), 8, Pal.red);
        c.drawPath(bag, D.stroke(Pal.ink, 2.5));
      case 4: // milk carton
        final box = Path()
          ..moveTo(-16, -14)
          ..lineTo(0, -30)
          ..lineTo(16, -14)
          ..lineTo(16, 28)
          ..lineTo(-16, 28)
          ..close();
        c.drawPath(box, D.fill(Pal.white));
        c.drawRect(const Rect.fromLTWH(-16, 0, 32, 16), D.fill(Pal.sky));
        c.drawPath(box, D.stroke(Pal.ink, 2.5));
        c.drawLine(const Offset(-16, -14), const Offset(16, -14), D.stroke(Pal.ink, 2));
      default: // pudding
        final cup = Path()
          ..moveTo(-20, -12)
          ..lineTo(20, -12)
          ..lineTo(14, 22)
          ..lineTo(-14, 22)
          ..close();
        c.drawPath(cup, D.fill(const Color(0xFFFFE08A)));
        c.drawRect(const Rect.fromLTWH(-20, -16, 40, 8), D.fill(const Color(0xFF8A4B25)));
        c.drawPath(cup, D.stroke(Pal.ink, 2.5));
        c.drawOval(const Rect.fromLTWH(-22, -20, 44, 10), D.fill(const Color(0xDDFFFFFF)));
        c.drawOval(const Rect.fromLTWH(-22, -20, 44, 10), D.stroke(Pal.ink, 2));
    }
    // barcode sticker
    D.rrect(c, const Rect.fromLTWH(8, 14, 18, 11), 2, Pal.white, border: Pal.ink, borderWidth: 1);
    for (var k = 0; k < 6; k++) {
      c.drawLine(Offset(10.5 + k * 2.6, 16), Offset(10.5 + k * 2.6, 23), D.stroke(Pal.ink, k.isEven ? 1.4 : .8));
    }
    c.restore();
  }

  void _drawHud(Canvas c) {
    D.rrect(c, const Rect.fromLTWH(8, 44, 100, 30), 15, const Color(0xDD1B1530), border: Pal.white, borderWidth: 2);
    for (var i = 0; i < _goal; i++) {
      final done = i < _served;
      c.drawCircle(Offset(28 + i * 26.0, 59), 9, D.fill(done ? Pal.lime : const Color(0x44FFFFFF)));
      if (done) c.drawCircle(Offset(28 + i * 26.0, 59), 9, D.stroke(Pal.ink, 2));
    }
    D.rrect(c, const Rect.fromLTWH(240, 44, 112, 30), 15, const Color(0xDD1B1530), border: Pal.gold, borderWidth: 2);
    D.coin(c, const Offset(258, 59), 10, spin: _t * .4);
    D.text(c, M.big(_shown), const Offset(306, 59), size: 18, color: Pal.gold, stroke: Pal.ink);
    for (var i = 0; i < 2; i++) {
      D.heart(c, Offset(140 + i * 22.0, 59), 16, i < 2 - _strikes ? Pal.red : const Color(0x55000000), border: Pal.ink);
    }
    if (_queueLeft > 0) {
      D.text(c, '+$_queueLeft', const Offset(206, 59), size: 14, color: Pal.ink);
    }
  }

  void _drawHint(Canvas c) {
    if (host.finished) return;
    if (_custIndex == 1 && _phase == 1 && _items.any((e) => !e.scanned) && _held == null) {
      final it = _items.firstWhere((e) => !e.scanned);
      final k = (_t * .9) % 1.0;
      final p = Offset.lerp(it.pos, Offset(_laserX + 30, it.pos.dy), M.easeInOut(k))!;
      D.arrow(c, Offset((it.pos.dx + _laserX + 30) / 2, _beltY - 52), const Offset(1, 0), 90, Pal.lime, width: 10);
      D.hand(c, p + const Offset(0, 6), 0);
    }
    if (_served == 0 && _phase == 3) {
      final rem = _need - _given;
      for (var i = 0; i < 4; i++) {
        if (_coinVals[i] <= rem) {
          D.hand(c, Offset(_drawerX[i], _drawerY + 10), _t);
          break;
        }
      }
    }
  }
}

class _Shopper {
  _Shopper(this.shirt, this.hair);
  final Color shirt;
  final Color hair;
}

class _Item {
  _Item(this.kind, this.pos) : from = pos;
  final int kind;
  Offset pos;
  Offset from;
  bool scanned = false;
  bool bagged = false;
  double bagT = 0;
  double wob = 0;
}

class _GivenCoin {
  _GivenCoin(this.v, this.from, this.target);
  final int v;
  final Offset from;
  final Offset target;
  double t = 0;
}
