import '../engine/engine.dart';

/// No.031 Ramen Rush — counter-view ramen shop. Build each bowl (broth ->
/// noodles with a boil-timing gauge -> toppings) and drag it to the customer
/// whose order bubble matches before their patience runs out. 5 served = win.
class G031 extends MiniGame {
  static const _goal = 5;
  static const _brothCols = [Color(0xFF9A4F1C), Color(0xFFE39A43), Color(0xFFF6E8CC)];
  static const _seatX = [66.0, 180.0, 294.0];
  static const _potPos = [Offset(50, 404), Offset(138, 404), Offset(226, 404)];
  static const _boilerPos = Offset(314, 404);
  static const _topPos = [Offset(70, 596), Offset(180, 596), Offset(290, 596)];
  static const _trashPos = Offset(40, 510);
  static const _bowlHome = Offset(180, 505);
  static const _moneyAt = Offset(252, 57);

  final List<_Cust?> _seats = [null, null, null];
  final List<double> _seatTimer = [0.25, 1.4, 3.6];
  int _customersMade = 0;

  // current bowl
  int _broth = -1;
  bool _noodles = false;
  bool _perfectNoodle = false;
  final Set<int> _tops = {};
  Offset _bowlPos = _bowlHome;
  bool _dragging = false;
  Offset _grab = Offset.zero;
  double _bowlSquash = 0;
  double _bowlIn = 1;

  double _boil = 0;
  double _t = 0;
  int _served = 0;
  int _angry = 0;
  int _combo = 0;
  double _money = 0;
  double _shown = 0;
  double _moneyBump = 0;
  final List<double> _press = List.filled(8, 0); // 0-2 pots, 3 boiler, 4-6 toppings, 7 trash
  final List<_Fly> _flies = [];
  double _ladleT = -1;
  int _ladleFrom = 0;
  double _tossT = -1;
  bool _won = false;

  @override
  void init() {}

  // ------------------------------------------------------------------ logic

  _Cust _newCustomer() {
    _customersMade++;
    final tops = <int>{randInt(3)};
    if (_customersMade > 2 && chance(.5)) tops.add(randInt(3));
    final pat = (15.0 - min(_customersMade, 6) * .5) / host.speed;
    return _Cust(
      broth: randInt(3),
      tops: tops,
      patience: pat,
      shirt: pick(const [Pal.sky, Pal.pink, Pal.lime, Pal.purple, Pal.orange, Pal.teal]),
      hair: pick(const [Color(0xFF2B1D16), Color(0xFF6B3B1E), Color(0xFFE8C04A), Color(0xFF3B3B5A), Color(0xFFB0B0B8)]),
    );
  }

  bool get _bowlEmpty => _broth < 0 && !_noodles && _tops.isEmpty;

  void _resetBowl() {
    _broth = -1;
    _noodles = false;
    _perfectNoodle = false;
    _tops.clear();
    _bowlPos = _bowlHome;
    _bowlIn = 0;
  }

  @override
  void update(double dt) {
    _t += dt;
    _boil = (_boil + dt * .72 * host.speed) % 1.0;
    _shown = M.approach(_shown, _money, 7, dt);
    if ((_money - _shown).abs() < 1) _shown = _money;
    _moneyBump = M.approach(_moneyBump, 0, 8, dt);
    _bowlSquash = M.approach(_bowlSquash, 0, 10, dt);
    _bowlIn = min(1, _bowlIn + dt * 3.5);
    for (var i = 0; i < _press.length; i++) {
      _press[i] = M.approach(_press[i], 0, 9, dt);
    }
    if (_ladleT >= 0) {
      _ladleT += dt * 3.2;
      if (_ladleT >= 1) _ladleT = -1;
    }
    if (_tossT >= 0) {
      _tossT += dt * 3.2;
      if (_tossT >= 1) _tossT = -1;
    }
    if (!_dragging) _bowlPos = M.approachO(_bowlPos, _bowlHome, 14, dt);

    for (var i = 0; i < 3; i++) {
      final cu = _seats[i];
      if (cu == null) {
        if (_won) continue;
        _seatTimer[i] -= dt;
        if (_seatTimer[i] <= 0) {
          _seats[i] = _newCustomer();
          host.sfx(Sfx.bell, volume: .35, rate: 1.2 + i * .1);
        }
        continue;
      }
      cu.stateT += dt;
      cu.bounce = M.approach(cu.bounce, 0, 7, dt);
      cu.arrive = min(1, cu.arrive + dt * 3);
      switch (cu.state) {
        case 0: // waiting
          if (!host.finished) cu.patience -= dt;
          if (cu.patience <= 0) {
            cu.state = 2;
            cu.stateT = 0;
            cu.mad = true;
            _angry++;
            _combo = 0;
            host.sfx(Sfx.buzzer, volume: .7);
            host.shake(6);
            host.fx.smoke(Offset(_seatX[i], 190), count: 8, color: const Color(0xCCFF6060));
            host.fx.pop(host.tr('angry', 'ANGRY!'), Offset(_seatX[i], 150), color: Pal.red, size: 24);
            if (_angry >= 3 && !host.finished) {
              host.sfx(Sfx.jingleLose, volume: .7);
              host.lose();
            }
          }
        case 1: // eating
          if (cu.stateT > 1.25) {
            cu.state = 2;
            cu.stateT = 0;
          }
        case 2: // leaving
          if (cu.stateT > .55) {
            _seats[i] = null;
            _seatTimer[i] = rand(.35, 1.1);
          }
      }
    }

    for (final f in _flies) {
      if (f.delay > 0) {
        f.delay -= dt;
        continue;
      }
      f.t += dt * 1.9;
      if (f.t >= 1 && !f.done) {
        f.done = true;
        _moneyBump = 1;
        host.sfx(Sfx.coin, volume: .35, rate: 1 + rand(0, .4));
        host.fx.sparkle(_moneyAt, count: 2, radius: 10, color: Pal.gold);
      }
    }
    _flies.removeWhere((f) => f.done);
  }

  void _serve(int seat) {
    final cu = _seats[seat];
    if (cu == null || cu.state != 0) {
      host.sfx(Sfx.boing, volume: .5);
      return;
    }
    final ok = cu.broth == _broth && _noodles && cu.tops.length == _tops.length && cu.tops.containsAll(_tops);
    final at = Offset(_seatX[seat], 250);
    if (ok) {
      _combo++;
      final ratio = (cu.patience / cu.maxPatience).clamp(0.0, 1.0);
      final pay = 800 + (ratio * 500).round() + (_perfectNoodle ? 300 : 0) + _combo * 100;
      _money += pay;
      host.addScore(pay);
      cu.state = 1;
      cu.stateT = 0;
      cu.bounce = 1;
      cu.bowl = _broth;
      _served++;
      host.sfx(Sfx.chomp);
      host.sfx(Sfx.cash, volume: .8, rate: 1 + _combo * .06);
      host.punch(.03);
      host.fx.burst(at, Pal.yellow, count: 14, speed: 240, shape: PartShape.star, colors: const [Pal.yellow, Pal.orange, Pal.white]);
      host.fx.pop('+$pay', at + const Offset(0, -40), color: Pal.gold, size: 28);
      if (ratio > .6 || _perfectNoodle) {
        host.fx.pop(host.tr(_perfectNoodle ? 'perfect' : 'great', _perfectNoodle ? 'PERFECT!' : 'GREAT!'),
            at + const Offset(0, -80), color: Pal.lime, size: 24, life: 1);
      }
      if (_combo >= 2) {
        host.fx.pop('${host.tr('combo', 'COMBO')} x$_combo', at + const Offset(0, -110), color: Pal.pink, size: 22, life: 1);
      }
      for (var i = 0; i < 7; i++) {
        _flies.add(_Fly(at + Offset(rand(-20, 20), rand(-10, 10)), i * .05));
      }
      if (_served >= _goal && !host.finished) {
        _won = true;
        host.fx.confetti();
        host.sfx(Sfx.fanfare);
        host.win(stars: _angry == 0 && host.time < 19 ? 3 : (_angry <= 1 ? 2 : 1));
      }
    } else {
      _combo = 0;
      cu.state = 2;
      cu.stateT = 0;
      cu.mad = true;
      _angry++;
      host.sfx(Sfx.splat);
      host.sfx(Sfx.wrong, volume: .8);
      host.shake(9);
      host.flash(const Color(0x55FF3B5C));
      host.fx.burst(at, _broth >= 0 ? _brothCols[_broth] : Pal.cream, count: 22, speed: 300, gravity: 700);
      host.fx.pop(host.tr('wrong', 'WRONG!'), at + const Offset(0, -60), color: Pal.red, size: 30);
      if (_angry >= 3 && !host.finished) host.lose();
    }
    _resetBowl();
  }

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    // bowl drag
    if (!_bowlEmpty && (p - _bowlPos).distance < 62) {
      _dragging = true;
      _grab = _bowlPos - p;
      host.sfx(Sfx.pickup, volume: .6);
      return;
    }
    for (var i = 0; i < 3; i++) {
      if ((p - _potPos[i]).distance < 44) {
        _press[i] = 1;
        if (_broth < 0) {
          _broth = i;
          _ladleT = 0;
          _ladleFrom = i;
          _bowlSquash = 1;
          host.sfx(Sfx.pour, rate: 1.1);
          host.fx.burst(_bowlHome + const Offset(0, -10), _brothCols[i], count: 10, speed: 140, gravity: 500);
        } else {
          host.sfx(Sfx.tap, volume: .5);
        }
        return;
      }
    }
    if ((p - _boilerPos).distance < 46) {
      _press[3] = 1;
      if (!_noodles) {
        _noodles = true;
        _tossT = 0;
        _bowlSquash = 1;
        _perfectNoodle = _boil > .58 && _boil < .86;
        host.sfx(Sfx.splash);
        host.fx.smoke(_boilerPos + const Offset(0, -20), count: 6);
        host.fx.pop(
            _perfectNoodle ? host.tr('perfect', 'PERFECT!') : host.tr('good', 'GOOD'), _boilerPos + const Offset(-20, -60),
            color: _perfectNoodle ? Pal.lime : Pal.white, size: _perfectNoodle ? 24 : 18);
        if (_perfectNoodle) host.sfx(Sfx.perfect, volume: .6);
      } else {
        host.sfx(Sfx.tap, volume: .5);
      }
      return;
    }
    for (var i = 0; i < 3; i++) {
      if ((p - _topPos[i]).distance < 50) {
        _press[4 + i] = 1;
        if (!_tops.contains(i)) {
          _tops.add(i);
          _bowlSquash = .8;
          host.sfx(Sfx.pop, rate: 1 + i * .15);
          host.fx.sparkle(_bowlHome + const Offset(0, -12), count: 5, radius: 22);
        } else {
          host.sfx(Sfx.tap, volume: .5);
        }
        return;
      }
    }
    if ((p - _trashPos).distance < 34) {
      _press[7] = 1;
      if (!_bowlEmpty) {
        host.sfx(Sfx.thud);
        host.fx.smoke(_trashPos, count: 5);
        _resetBowl();
      }
      return;
    }
    // tap a customer = serve the bowl
    if (p.dy < 340 && p.dy > 90 && !_bowlEmpty) {
      final seat = _nearestSeat(p.dx);
      _serve(seat);
    }
  }

  int _nearestSeat(double x) {
    var best = 0;
    for (var i = 1; i < 3; i++) {
      if ((x - _seatX[i]).abs() < (x - _seatX[best]).abs()) best = i;
    }
    return best;
  }

  @override
  void onMove(Offset p) {
    if (_dragging) _bowlPos = p + _grab;
  }

  @override
  void onUp(Offset p) {
    if (!_dragging) return;
    _dragging = false;
    if (_bowlPos.dy < 350 && !host.finished) {
      _serve(_nearestSeat(_bowlPos.dx));
    } else {
      host.sfx(Sfx.land, volume: .4);
    }
  }

  // ----------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    _drawShop(c);
    for (var i = 0; i < 3; i++) {
      final cu = _seats[i];
      if (cu != null) _drawCustomer(c, i, cu);
    }
    _drawCounter(c);
    for (var i = 0; i < 3; i++) {
      final cu = _seats[i];
      if (cu != null && cu.state == 1) _drawEating(c, i, cu);
    }
    _drawKitchen(c);
    for (var i = 0; i < 3; i++) {
      final cu = _seats[i];
      if (cu != null && cu.state == 0) _drawOrder(c, i, cu);
    }
    _drawBowlLayer(c);
    _drawHud(c);
    _drawHint(c);
  }

  void _drawShop(Canvas c) {
    // wooden wall planks
    D.gradientBg(c, const [Color(0xFFB8733E), Color(0xFF8A4B25)], rect: const Rect.fromLTWH(0, 0, 360, 340));
    for (var i = 0; i < 9; i++) {
      final x = i * 42.0;
      c.drawRect(Rect.fromLTWH(x, 36, 2, 300), D.fill(const Color(0x33000000)));
      c.drawRect(Rect.fromLTWH(x + 12, 60 + (i * 37) % 120, 10, 3), D.fill(const Color(0x22000000)));
    }
    // warm glow
    c.drawCircle(const Offset(180, 200), 220, Paint()..color = const Color(0x22FFE0A0));
    // noren curtain
    final sway = sin(_t * 1.6) * 3;
    for (var i = 0; i < 5; i++) {
      final x = 4 + i * 71.0;
      final r = Rect.fromLTWH(x + sway * (i.isEven ? 1 : -1), 34, 66, 44);
      D.rrect(c, r, 4, const Color(0xFF1F2A5C));
      c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 6), D.fill(const Color(0xFF141B3E)));
      c.drawCircle(r.center + const Offset(0, 4), 12, D.stroke(Pal.white, 3));
      c.drawLine(r.center + const Offset(-7, 4), r.center + const Offset(7, 4), D.stroke(Pal.white, 3));
    }
    // menu plates on wall
    for (var i = 0; i < 7; i++) {
      final x = 18 + i * 48.0;
      D.rrect(c, Rect.fromLTWH(x, 84, 34, 22), 3, const Color(0xFFF3E1B8), border: const Color(0xFF5A3014), borderWidth: 2);
      c.drawLine(Offset(x + 8, 91), Offset(x + 26, 91), D.stroke(const Color(0xFFC0392B), 2.5));
      c.drawLine(Offset(x + 8, 98), Offset(x + 20, 98), D.stroke(Pal.ink, 2));
    }
    // lanterns
    for (final lx in [22.0, 338.0]) {
      final sw = sin(_t * 2 + lx) * .08;
      c.save();
      c.translate(lx, 110);
      c.rotate(sw);
      c.drawCircle(const Offset(0, 50), 42, Paint()..color = const Color(0x33FFB060));
      c.drawLine(Offset.zero, const Offset(0, 22), D.stroke(Pal.ink, 2));
      c.drawOval(Rect.fromCenter(center: const Offset(0, 50), width: 34, height: 48), D.fill(const Color(0xFFE8322C)));
      for (var k = -1; k <= 1; k++) {
        c.drawLine(Offset(-15, 50 + k * 12.0), Offset(15, 50 + k * 12.0), D.stroke(const Color(0x44000000), 1.5));
      }
      c.drawRect(Rect.fromCenter(center: const Offset(0, 26), width: 18, height: 6), D.fill(Pal.ink));
      c.drawRect(Rect.fromCenter(center: const Offset(0, 74), width: 18, height: 6), D.fill(Pal.ink));
      c.drawOval(Rect.fromCenter(center: const Offset(-6, 42), width: 8, height: 16), D.fill(const Color(0x55FFFFFF)));
      c.restore();
    }
  }

  void _drawCustomer(Canvas c, int i, _Cust cu) {
    final x = _seatX[i];
    double off;
    if (cu.state == 2) {
      off = M.easeInOut((cu.stateT / .55).clamp(0.0, 1.0)) * 170;
    } else {
      off = (1 - M.easeOutBack(cu.arrive)) * 170;
    }
    final ratio = (cu.patience / cu.maxPatience).clamp(0.0, 1.0);
    Face f;
    if (cu.mad) {
      f = Face.angry;
    } else if (cu.state == 1) {
      f = Face.love;
    } else if (ratio > .6) {
      f = Face.happy;
    } else if (ratio > .3) {
      f = Face.neutral;
    } else {
      f = Face.angry;
    }
    final shakeX = (cu.state == 0 && ratio < .25) ? sin(_t * 40) * 2.5 : 0.0;
    final bob = cu.state == 1 ? sin(cu.stateT * 18).abs() * -6 : 0.0;
    D.person(c, Offset(x + shakeX, 348 + off + bob - cu.bounce * 8), 165, cu.shirt, hair: cu.hair, face: f,
        armsUp: cu.state == 1 ? .2 : 0);
    if (cu.mad && cu.state == 2) {
      // anger vein
      final h = Offset(x + 22, 196 + off);
      for (var k = 0; k < 4; k++) {
        final a = k * pi / 2 + pi / 4;
        c.drawLine(h + Offset(cos(a) * 3, sin(a) * 3), h + Offset(cos(a) * 9, sin(a) * 9), D.stroke(Pal.red, 3));
      }
    }
  }

  void _drawCounter(Canvas c) {
    D.rrect(c, const Rect.fromLTWH(-10, 300, 380, 30), 6, const Color(0xFFD9A066),
        gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE8B77C), Color(0xFFB9783F)]));
    c.drawRect(const Rect.fromLTWH(0, 302, 360, 3), D.fill(const Color(0x66FFFFFF)));
    c.drawRect(const Rect.fromLTWH(0, 330, 360, 16), D.fill(const Color(0xFF5E3317)));
    c.drawRect(const Rect.fromLTWH(0, 344, 360, 3), D.fill(const Color(0x55000000)));
    // condiment set
    for (final x in [123.0, 237.0]) {
      D.rrect(c, Rect.fromLTWH(x - 6, 284, 12, 20), 3, const Color(0xFFC0392B), border: Pal.ink, borderWidth: 1.5);
      D.rrect(c, Rect.fromLTWH(x + 7, 290, 9, 14), 3, const Color(0xFFFFF4DC), border: Pal.ink, borderWidth: 1.5);
    }
  }

  void _drawEating(Canvas c, int i, _Cust cu) {
    final x = _seatX[i];
    final o = Offset(x, 300);
    _bowl(c, o, .55, cu.bowl, true, const {});
    // chopsticks lifting noodles
    final lift = sin(cu.stateT * 14).abs() * 18;
    c.drawLine(o + Offset(-4, -10 - lift), o + Offset(8, -70 - lift), D.stroke(const Color(0xFFD9B27C), 3));
    c.drawLine(o + Offset(4, -10 - lift), o + Offset(16, -68 - lift), D.stroke(const Color(0xFFD9B27C), 3));
    for (var k = 0; k < 3; k++) {
      c.drawLine(o + Offset(-2 + k * 3.0, -10 - lift), o + Offset(-2 + k * 3.0, 8), D.stroke(const Color(0xFFFFE08A), 2));
    }
    if (((cu.stateT * 6).floor()).isEven) {
      D.text(c, 'ZuZu', o + const Offset(34, -70), size: 14, color: Pal.white, stroke: Pal.ink, italic: true);
    }
  }

  void _drawOrder(Canvas c, int i, _Cust cu) {
    final x = _seatX[i];
    final pop = M.easeOutBack(cu.arrive);
    final ratio = (cu.patience / cu.maxPatience).clamp(0.0, 1.0);
    c.save();
    c.translate(x, 130);
    c.scale(pop);
    final wob = ratio < .3 ? sin(_t * 30) * .05 : 0.0;
    c.rotate(wob);
    const r = Rect.fromLTWH(-48, -42, 96, 86);
    D.bubble(c, r, tail: const Offset(0, 50));
    _bowl(c, const Offset(0, -22), .42, cu.broth, true, const {});
    final n = cu.tops.length;
    var k = 0;
    for (final tp in cu.tops) {
      final tx = (k - (n - 1) / 2) * 28.0;
      c.drawCircle(Offset(tx, 12), 13, D.fill(const Color(0xFFF0EAF6)));
      _topIcon(c, Offset(tx, 12), tp, .8);
      k++;
    }
    final col = ratio > .6 ? Pal.green : (ratio > .3 ? Pal.yellow : Pal.red);
    D.bar(c, const Rect.fromLTWH(-38, 29, 76, 8), ratio, col);
    c.restore();
  }

  void _drawKitchen(Canvas c) {
    // tiles
    c.drawRect(const Rect.fromLTWH(0, 346, 360, 294), D.fill(const Color(0xFFD8E4EA)));
    final grout = D.stroke(const Color(0xFFB7C7D0), 1.5);
    for (var y = 346.0; y < 640; y += 26) {
      c.drawLine(Offset(0, y), Offset(360, y), grout);
    }
    for (var x = 0.0; x < 360; x += 26) {
      c.drawLine(Offset(x, 346), Offset(x, 640), grout);
    }
    // stove plate
    D.rrect(c, const Rect.fromLTWH(4, 362, 352, 86), 10, const Color(0xFF4A4F5C),
        gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5E6472), Color(0xFF3A3E49)]));
    // steel worktop
    D.rrect(c, const Rect.fromLTWH(4, 456, 352, 102), 10, const Color(0xFFB9C2CC),
        gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE3E8EE), Color(0xFFA7B0BB)]),
        border: const Color(0xFF6D7684), borderWidth: 2);
    // topping shelf
    D.rrect(c, const Rect.fromLTWH(4, 562, 352, 72), 10, const Color(0xFF8A5A33),
        gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFA36B3D), Color(0xFF6E4222)]));

    for (var i = 0; i < 3; i++) {
      _drawPot(c, i);
    }
    _drawBoiler(c);
    for (var i = 0; i < 3; i++) {
      _drawTray(c, i);
    }
    // trash
    final tp = _trashPos + Offset(0, _press[7] * 3);
    D.rrect(c, Rect.fromCenter(center: tp + const Offset(0, 6), width: 40, height: 44), 7, const Color(0xFF50606E),
        border: Pal.ink, borderWidth: 2.5);
    D.rrect(c, Rect.fromCenter(center: tp + Offset(0, -18 - _press[7] * 6), width: 48, height: 10), 4, const Color(0xFF6B7C8B),
        border: Pal.ink, borderWidth: 2.5);
    for (var k = -1; k <= 1; k++) {
      c.drawLine(tp + Offset(k * 10.0, -4), tp + Offset(k * 10.0, 20), D.stroke(const Color(0xFF34404A), 3));
    }
  }

  void _drawPot(Canvas c, int i) {
    final o = _potPos[i] + Offset(0, _press[i] * 4);
    final sq = 1 + _press[i] * .08;
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(sq, 2 - sq);
    // flame
    D.flame(c, const Offset(0, 36), 16, _t + i);
    // body
    D.rrect(c, const Rect.fromLTWH(-36, -14, 72, 46), 10, const Color(0xFF9AA4B0),
        gradient: const LinearGradient(colors: [Color(0xFF6F7985), Color(0xFFD6DDE4), Color(0xFF7D8793)]),
        border: Pal.ink, borderWidth: 2.5);
    // handles
    D.rrect(c, const Rect.fromLTWH(-44, -8, 10, 8), 3, const Color(0xFF3A3E49), border: Pal.ink, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(34, -8, 10, 8), 3, const Color(0xFF3A3E49), border: Pal.ink, borderWidth: 2);
    // soup
    c.drawOval(Rect.fromCenter(center: const Offset(0, -14), width: 72, height: 22), D.fill(const Color(0xFF3A3E49)));
    c.drawOval(Rect.fromCenter(center: const Offset(0, -13), width: 64, height: 16), D.fill(_brothCols[i]));
    // bubbles in soup
    for (var k = 0; k < 3; k++) {
      final ph = (_t * 1.4 + k * .33 + i * .2) % 1.0;
      c.drawCircle(Offset(-18 + k * 18.0, -13), 2 + ph * 3,
          D.stroke(Color.lerp(_brothCols[i], Pal.white, .5)!.withValues(alpha: 1 - ph), 1.5));
    }
    c.drawOval(Rect.fromCenter(center: const Offset(0, -14), width: 72, height: 22), D.stroke(Pal.ink, 2.5));
    // color tag
    c.drawCircle(const Offset(0, 12), 9, D.fill(_brothCols[i]));
    c.drawCircle(const Offset(0, 12), 9, D.stroke(Pal.ink, 2));
    c.restore();
    // steam
    _steam(c, o + const Offset(0, -24), i.toDouble());
  }

  void _steam(Canvas c, Offset base, double seed) {
    for (var k = 0; k < 2; k++) {
      final ph = (_t * .7 + k * .5 + seed * .17) % 1.0;
      final path = Path();
      for (var s = 0; s <= 8; s++) {
        final y = -s * 5.0 - ph * 20;
        final x = sin(s * .8 + _t * 3 + k * 2 + seed) * 5 + (k - .5) * 14;
        s == 0 ? path.moveTo(base.dx + x, base.dy + y) : path.lineTo(base.dx + x, base.dy + y);
      }
      c.drawPath(path, D.stroke(Color.fromRGBO(255, 255, 255, .55 * (1 - ph)), 4));
    }
  }

  void _drawBoiler(Canvas c) {
    final o = _boilerPos + Offset(0, _press[3] * 4);
    D.rrect(c, Rect.fromCenter(center: o + const Offset(0, 6), width: 70, height: 58), 8, const Color(0xFF9AA4B0),
        gradient: const LinearGradient(colors: [Color(0xFF6F7985), Color(0xFFD6DDE4), Color(0xFF7D8793)]),
        border: Pal.ink, borderWidth: 2.5);
    c.drawOval(Rect.fromCenter(center: o + const Offset(0, -20), width: 66, height: 20), D.fill(const Color(0xFF9FD8F0)));
    for (var k = 0; k < 5; k++) {
      final ph = (_t * 2 + k * .21) % 1.0;
      c.drawCircle(o + Offset(-22 + k * 11.0, -20 - ph * 4), 2 + ph * 2, D.fill(Color.fromRGBO(255, 255, 255, 1 - ph)));
    }
    c.drawOval(Rect.fromCenter(center: o + const Offset(0, -20), width: 66, height: 20), D.stroke(Pal.ink, 2.5));
    // tebo strainer w/ noodles
    if (!_noodles || _tossT >= 0) {
      final lift = _tossT >= 0 ? -sin(_tossT * pi) * 20 : sin(_t * 5) * 2;
      c.drawLine(o + Offset(8, -24 + lift), o + Offset(30, -56 + lift), D.stroke(const Color(0xFF7A4B26), 5));
      c.drawOval(Rect.fromCenter(center: o + Offset(0, -24 + lift), width: 30, height: 16), D.fill(const Color(0xFFFFE08A)));
      for (var k = 0; k < 4; k++) {
        c.drawArc(Rect.fromCenter(center: o + Offset(-8 + k * 5.0, -24 + lift), width: 8, height: 10), 0, pi, false,
            D.stroke(const Color(0xFFE0B040), 1.5));
      }
      c.drawOval(Rect.fromCenter(center: o + Offset(0, -24 + lift), width: 30, height: 16), D.stroke(Pal.ink, 2));
    }
    // timing gauge
    final gr = Rect.fromCircle(center: o + const Offset(0, 8), radius: 21);
    c.drawCircle(gr.center, 21, D.fill(const Color(0xFF22252E)));
    c.drawArc(gr, -pi / 2 + .58 * 2 * pi, .28 * 2 * pi, false, D.stroke(Pal.lime, 7));
    final a = -pi / 2 + _boil * 2 * pi;
    c.drawLine(gr.center, gr.center + Offset(cos(a) * 18, sin(a) * 18), D.stroke(Pal.white, 3.5));
    c.drawCircle(gr.center, 4, D.fill(Pal.red));
    final inZone = _boil > .58 && _boil < .86;
    if (inZone && !_noodles) c.drawCircle(gr.center, 24, D.stroke(Pal.lime.withValues(alpha: .7), 3));
    _steam(c, o + const Offset(0, -30), 7);
  }

  void _drawTray(Canvas c, int i) {
    final o = _topPos[i] + Offset(0, _press[4 + i] * 4);
    final used = _tops.contains(i);
    D.rrect(c, Rect.fromCenter(center: o, width: 96, height: 56), 12, used ? const Color(0xFFCFC7BA) : const Color(0xFFF4EFE6),
        border: Pal.ink, borderWidth: 2.5);
    D.rrect(c, Rect.fromCenter(center: o + const Offset(0, 2), width: 84, height: 42), 9, const Color(0xFFE2DACB));
    for (var k = 0; k < 3; k++) {
      _topIcon(c, o + Offset(-24 + k * 24.0, (k.isOdd ? -3 : 3) + sin(_t * 3 + k + i) * 1.5), i, 1);
    }
    if (used) {
      c.drawCircle(o + const Offset(38, -22), 11, D.fill(Pal.green));
      c.drawPath(
          Path()
            ..moveTo(o.dx + 32, o.dy - 22)
            ..lineTo(o.dx + 37, o.dy - 17)
            ..lineTo(o.dx + 45, o.dy - 27),
          D.stroke(Pal.white, 3));
    }
  }

  /// Topping icon: 0 egg, 1 chashu, 2 nori.
  void _topIcon(Canvas c, Offset o, int kind, double s) {
    switch (kind) {
      case 0:
        c.drawOval(Rect.fromCenter(center: o, width: 22 * s, height: 17 * s), D.fill(Pal.white));
        c.drawCircle(o + Offset(0, 1 * s), 6 * s, D.fill(const Color(0xFFFF9D1F)));
        c.drawCircle(o + Offset(-1.5 * s, 0), 2.5 * s, D.fill(const Color(0xFFFFC857)));
        c.drawOval(Rect.fromCenter(center: o, width: 22 * s, height: 17 * s), D.stroke(Pal.ink, 1.8 * s));
      case 1:
        c.drawCircle(o, 10 * s, D.fill(const Color(0xFFE59A84)));
        c.drawCircle(o, 10 * s, D.stroke(const Color(0xFF8C3B1F), 3 * s));
        c.drawArc(Rect.fromCircle(center: o, radius: 5 * s), 0, 4.5, false, D.stroke(const Color(0xFFFFE6DA), 2 * s));
        c.drawCircle(o, 11.5 * s, D.stroke(Pal.ink, 1.5 * s));
      default:
        c.save();
        c.translate(o.dx, o.dy);
        c.rotate(-.15);
        D.rrect(c, Rect.fromCenter(center: Offset.zero, width: 14 * s, height: 22 * s), 2 * s, const Color(0xFF1E3B24),
            border: Pal.ink, borderWidth: 1.5 * s);
        c.drawLine(Offset(-3 * s, -8 * s), Offset(-3 * s, 8 * s), D.stroke(const Color(0xFF34603C), 1.2 * s));
        c.drawLine(Offset(3 * s, -8 * s), Offset(3 * s, 8 * s), D.stroke(const Color(0xFF34603C), 1.2 * s));
        c.restore();
    }
  }

  void _bowl(Canvas c, Offset o, double s, int broth, bool noodles, Set<int> tops) {
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s);
    // body
    final body = Path()
      ..moveTo(-54, -6)
      ..quadraticBezierTo(-50, 46, 0, 48)
      ..quadraticBezierTo(50, 46, 54, -6)
      ..close();
    c.drawPath(body, D.fill(const Color(0xFFD9302C)));
    // raimon band
    c.save();
    c.clipPath(body);
    c.drawRect(const Rect.fromLTWH(-60, 8, 120, 14), D.fill(Pal.white));
    for (var x = -56.0; x < 56; x += 14) {
      c.drawPath(
          Path()
            ..moveTo(x, 20)
            ..lineTo(x, 11)
            ..lineTo(x + 9, 11)
            ..lineTo(x + 9, 17)
            ..lineTo(x + 4, 17),
          D.stroke(const Color(0xFFD9302C), 2.2));
    }
    c.drawRect(const Rect.fromLTWH(-60, -6, 120, 8), D.fill(const Color(0x33FFFFFF)));
    c.restore();
    c.drawPath(body, D.stroke(Pal.ink, 3.5));
    D.rrect(c, const Rect.fromLTWH(-20, 42, 40, 9), 3, const Color(0xFFB02420), border: Pal.ink, borderWidth: 3);
    // rim + inside
    c.drawOval(Rect.fromCenter(center: const Offset(0, -6), width: 110, height: 36), D.fill(const Color(0xFFFBF3E6)));
    final inner = Rect.fromCenter(center: const Offset(0, -5), width: 96, height: 28);
    c.drawOval(inner, D.fill(broth >= 0 ? _brothCols[broth] : const Color(0xFFE6DCCB)));
    if (broth >= 0) {
      c.drawOval(Rect.fromCenter(center: const Offset(-18, -9), width: 30, height: 7), D.fill(const Color(0x40FFFFFF)));
      // oil dots
      for (var k = 0; k < 5; k++) {
        c.drawCircle(Offset(-30 + k * 15.0, -3 + (k.isOdd ? -4 : 3)), 2.2, D.fill(const Color(0x55FFE9A0)));
      }
    }
    if (noodles) {
      c.save();
      c.clipPath(Path()..addOval(inner));
      final np = D.stroke(const Color(0xFFFFE08A), 3.2);
      final npd = D.stroke(const Color(0xFFD9A93A), 1);
      for (var k = 0; k < 6; k++) {
        final path = Path()..moveTo(-44, -12 + k * 4.0);
        for (var x = -44.0; x <= 44; x += 8) {
          path.lineTo(x, -12 + k * 4.0 + sin(x * .3 + k) * 2.2);
        }
        c.drawPath(path, np);
        c.drawPath(path, npd);
      }
      c.restore();
    }
    if (tops.contains(2)) {
      c.save();
      c.translate(30, -22);
      c.rotate(.2);
      D.rrect(c, const Rect.fromLTWH(-9, -16, 18, 28), 2, const Color(0xFF1E3B24), border: Pal.ink, borderWidth: 2);
      c.restore();
    }
    if (tops.contains(1)) {
      _topIcon(c, const Offset(12, -6), 1, 1.3);
    }
    if (tops.contains(0)) {
      _topIcon(c, const Offset(-22, -4), 0, 1.2);
    }
    c.drawOval(Rect.fromCenter(center: const Offset(0, -6), width: 110, height: 36), D.stroke(Pal.ink, 3.5));
    c.restore();
  }

  void _drawBowlLayer(Canvas c) {
    // ladle pour animation
    if (_ladleT >= 0) {
      final from = _potPos[_ladleFrom] + const Offset(0, -20);
      final to = _bowlHome + const Offset(0, -30);
      final p = Offset.lerp(from, to, M.easeInOut(min(1, _ladleT * 1.6)))! + Offset(0, -sin(_ladleT * pi) * 40);
      c.drawLine(p, p + const Offset(26, -30), D.stroke(const Color(0xFF6F7985), 4));
      c.drawCircle(p, 11, D.fill(const Color(0xFF9AA4B0)));
      c.drawCircle(p, 8, D.fill(_brothCols[_ladleFrom]));
      c.drawCircle(p, 11, D.stroke(Pal.ink, 2));
    }
    // flying noodles
    if (_tossT >= 0) {
      final p = Offset.lerp(_boilerPos + const Offset(0, -30), _bowlHome + const Offset(0, -10), _tossT)! +
          Offset(0, -sin(_tossT * pi) * 70);
      for (var k = 0; k < 4; k++) {
        c.drawArc(Rect.fromCenter(center: p + Offset(-9 + k * 6.0, 0), width: 10, height: 16), 0, pi, false,
            D.stroke(const Color(0xFFFFE08A), 3));
      }
    }
    final pos = _bowlPos + Offset(0, (1 - M.easeOutBack(_bowlIn)) * 140);
    D.shadow(c, _bowlHome + const Offset(0, 46), 110, 18, .25);
    final s = 1 + _bowlSquash * .12;
    c.save();
    c.translate(pos.dx, pos.dy);
    c.scale(s, 2 - s);
    if (_dragging) c.rotate(sin(_t * 10) * .04);
    _bowl(c, Offset.zero, _dragging ? .9 : 1, _broth, _noodles, _tops);
    c.restore();
    if (_broth >= 0) _steam(c, pos + const Offset(0, -26), 11);
    // drag hint arrow when complete
    if (!_dragging && _broth >= 0 && _noodles && _tops.isNotEmpty && !host.finished) {
      final bob = sin(_t * 8) * 5;
      D.arrow(c, _bowlHome + Offset(0, -80 + bob), const Offset(0, -1), 40, Pal.lime, width: 12);
    }
  }

  void _drawHud(Canvas c) {
    // served
    D.rrect(c, const Rect.fromLTWH(8, 44, 108, 32), 16, const Color(0xDD1B1530), border: Pal.white, borderWidth: 2);
    _bowl(c, const Offset(30, 60), .24, 2, true, const {});
    D.text(c, '$_served/$_goal', const Offset(76, 60), size: 20, color: Pal.white, stroke: Pal.ink);
    for (var i = 0; i < 3; i++) {
      D.heart(c, Offset(154 + i * 24.0, 60), 18, i < 3 - _angry ? Pal.red : const Color(0x66000000), border: Pal.ink);
    }
    // money
    final s = 1 + _moneyBump * .15;
    c.save();
    c.translate(298, 60);
    c.scale(s);
    D.rrect(c, const Rect.fromLTWH(-60, -16, 120, 32), 16, const Color(0xDD1B1530), border: Pal.gold, borderWidth: 2);
    D.coin(c, const Offset(-44, 0), 11, spin: _t * .5);
    D.text(c, M.big(_shown), const Offset(8, 0), size: 19, color: Pal.gold, stroke: Pal.ink);
    c.restore();
    // flying coins
    for (final f in _flies) {
      if (f.delay > 0) continue;
      final t = M.easeInOut(f.t.clamp(0.0, 1.0));
      final ctrl = Offset((f.from.dx + _moneyAt.dx) / 2 + 60, min(f.from.dy, _moneyAt.dy) - 60);
      final a = Offset.lerp(f.from, ctrl, t)!;
      final b = Offset.lerp(ctrl, _moneyAt, t)!;
      D.coin(c, Offset.lerp(a, b, t)!, 9, spin: f.t * 3);
    }
  }

  void _drawHint(Canvas c) {
    if (_served > 0 || host.finished || _t > 10) return;
    _Cust? target;
    for (final cu in _seats) {
      if (cu != null && cu.state == 0) {
        target = cu;
        break;
      }
    }
    if (target == null) return;
    Offset p;
    if (_broth < 0) {
      p = _potPos[target.broth];
    } else if (!_noodles) {
      p = _boilerPos;
    } else {
      final missing = target.tops.where((t) => !_tops.contains(t));
      if (missing.isNotEmpty) {
        p = _topPos[missing.first];
      } else {
        p = _bowlHome;
        D.text(c, host.tr('drag', 'DRAG'), _bowlHome + const Offset(70, -30), size: 20, color: Pal.lime, stroke: Pal.ink);
      }
    }
    D.hand(c, p + const Offset(4, 6), _t);
  }
}

class _Cust {
  _Cust({required this.broth, required this.tops, required this.patience, required this.shirt, required this.hair})
      : maxPatience = patience;
  final int broth;
  final Set<int> tops;
  double patience;
  final double maxPatience;
  final Color shirt;
  final Color hair;
  int state = 0; // 0 wait, 1 eating, 2 leaving
  double stateT = 0;
  double arrive = 0;
  double bounce = 0;
  bool mad = false;
  int bowl = 0;
}

class _Fly {
  _Fly(this.from, this.delay);
  final Offset from;
  double delay;
  double t = 0;
  bool done = false;
}
