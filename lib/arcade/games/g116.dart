import '../engine/engine.dart';

/// No.116 Claw Crane — hold to slide the claw, release to drop. Grip depends
/// on how centered you are (and on the machine's "payout mood"). 3 tries.
class G116 extends MiniGame {
  static const _floor = 500.0;
  static const _railY = 112.0;
  static const _homeX = 58.0;
  static const _chuteRight = 98.0;
  static const _chuteTop = 424.0;

  static const _auto = bool.fromEnvironment('AUTOPLAY');

  final List<_Toy> _toys = [];
  _St _st = _St.aim;
  double _stT = 0;
  double _cx = _homeX; // claw x
  double _cy = 150; // claw hub y
  double _open = .6; // 0 closed, 1 open
  double _dir = 1;
  double _stopY = 0;
  int _tries = 3;
  int _tryNo = 0;
  _Toy? _held;
  double _gripQ = 0; // 0 perfect .. 1 edge
  double _slipAt = -1; // lift progress at which the toy slips (-1 never)
  double _t = 0;
  double _holdMoved = 0;
  double _wob = 0;
  bool _holding = false;
  bool _won = false;
  double _lightBoost = 0;
  bool _autoHeld = false;

  @override
  void init() {
    final kinds = [_Kind.bear, _Kind.bunny, _Kind.cat, _Kind.chick, _Kind.slime, _Kind.bear, _Kind.cat, _Kind.bunny];
    kinds.shuffle(rng);
    // bottom row
    var x = 146.0;
    for (var i = 0; i < 5; i++) {
      final r = rand(20, 24);
      _toys.add(_Toy(kinds[i], x, _floor - r, r, _toyColor(kinds[i])));
      x += r * 2 - 4 + rand(-2, 2);
    }
    // top row
    x = 168;
    for (var i = 5; i < 8; i++) {
      final r = rand(19, 22);
      _toys.add(_Toy(kinds[i], x + rand(-4, 4), 300, r, _toyColor(kinds[i])));
      x += 48;
    }
    // THE prize: golden crown bear on top of the pile
    _toys.add(_Toy(_Kind.prize, rand(200, 280), 250, 25, Pal.gold));
    for (var k = 0; k < 4; k++) {
      for (final t in _toys) {
        if (t.y < _floor - t.r - 1) t.y = _restY(t);
      }
    }
  }

  Color _toyColor(_Kind k) => switch (k) {
        _Kind.bear => const Color(0xFFC98A5A),
        _Kind.bunny => const Color(0xFFFFB3D9),
        _Kind.cat => const Color(0xFF9FD8FF),
        _Kind.chick => Pal.yellow,
        _Kind.slime => Pal.lime,
        _Kind.prize => Pal.gold,
      };

  double _restY(_Toy t) {
    var y = _floor - t.r;
    for (final o in _toys) {
      if (identical(o, t) || o.falling || identical(o, _held) || o.inChute) continue;
      final dx = (t.x - o.x).abs();
      final rr = t.r + o.r - 3;
      if (dx < rr && o.y > t.y - 2) {
        final sy = o.y - sqrt(rr * rr - dx * dx);
        if (sy < y) y = sy;
      }
    }
    return y;
  }

  void _set(_St s) {
    _st = s;
    _stT = 0;
  }

  @override
  void update(double dt) {
    _t += dt;
    _stT += dt;
    _lightBoost = M.approach(_lightBoost, 0, 2, dt);
    _wob = M.approach(_wob, 0, 3, dt);
    if (_auto && !host.finished) _autoPlay();
    switch (_st) {
      case _St.aim:
        _cy = M.approach(_cy, 150, 8, dt);
        _open = M.approach(_open, .6, 8, dt);
        if (_holding) {
          _cx += _dir * 150 * host.speed * dt;
          _holdMoved += dt;
          if (_cx > 322) {
            _cx = 322;
            _dir = -1;
          } else if (_cx < _homeX + 10 && _dir < 0) {
            _cx = _homeX + 10;
            _dir = 1;
          }
          if ((_t * 8).floor() != ((_t - dt) * 8).floor()) host.sfx(Sfx.tick, volume: .25, rate: 1.6);
        }
      case _St.drop:
        _open = M.approach(_open, 1, 10, dt);
        _cy += 430 * dt;
        if (_cy >= _stopY) {
          _cy = _stopY;
          _set(_St.close);
          host.sfx(Sfx.clang, volume: .6, rate: 1.3);
          host.sfx(Sfx.shake, volume: .4);
        }
      case _St.close:
        _open = M.approach(_open, _grabTarget(), 14, dt);
        if (_stT > .32) {
          _decideGrab();
          _set(_St.lift);
        }
      case _St.lift:
        _cy -= 280 * dt;
        final prog = 1 - (_cy - 150) / max(1, _stopY - 150);
        if (_held != null) _wob = max(_wob, _gripQ * .8);
        if (_held != null && _slipAt >= 0 && prog >= _slipAt) _slip();
        if (_cy <= 150) {
          _cy = 150;
          _set(_St.carry);
          if (_held != null) {
            host.sfx(Sfx.heartbeat, volume: .6);
          }
        }
      case _St.carry:
        _cx -= 175 * dt;
        if (_held != null && _slipAt >= 1 && _cx < 150 + (_slipAt - 1) * 120) _slip();
        if (_cx <= _homeX) {
          _cx = _homeX;
          _set(_St.release);
          host.sfx(Sfx.click);
        }
      case _St.release:
        _open = M.approach(_open, 1, 10, dt);
        if (_held != null && _stT > .12) {
          final h = _held!;
          _held = null;
          h.falling = true;
          h.vy = 60;
        }
        if (_stT > .7 && !host.finished) _nextTry();
    }
    if (_held != null) {
      final h = _held!;
      final sway = sin(_t * 14) * _wob * 7;
      h.x = _cx + sway + (h.gripOff * .6);
      h.y = _cy + 42 + h.r * .5;
      h.face = Face.shocked;
    }
    // toys falling / settling
    for (final t in _toys) {
      if (!t.falling) continue;
      t.vy += 1400 * dt;
      t.y += t.vy * dt;
      t.x += t.vx * dt;
      t.spin += t.vx * dt * .02;
      if (t.x < _chuteRight - 4 && t.y > _chuteTop - t.r && !t.inChute) {
        t.inChute = true;
      }
      if (t.inChute) {
        t.x = M.approach(t.x, 58, 6, dt);
        if (t.y > 640 + t.r) {
          t.falling = false;
          if (!_won) _winNow(t);
        }
        continue;
      }
      final ry = _restY(t);
      if (t.y >= ry) {
        t.y = ry;
        if (t.vy > 260) {
          t.vy = -t.vy * .3;
          host.sfx(Sfx.boing, volume: .5, rate: 1.2);
          host.fx.smoke(Offset(t.x, t.y + t.r), count: 3, size: 10);
        } else {
          t.vy = 0;
          t.vx = 0;
          t.falling = false;
          t.face = Face.cry;
        }
      }
    }
  }

  void _autoPlay() {
    if (_st != _St.aim) return;
    final target = _toys.where((t) => !t.inChute && !t.falling).fold<_Toy?>(null, (b, t) => b == null || t.y < b.y ? t : b);
    if (target == null) return;
    if (!_autoHeld && _stT > .3) {
      _autoHeld = true;
      _startHold();
    } else if (_autoHeld && _holding && (_cx - target.x).abs() < 5) {
      _autoHeld = false;
      _releaseHold();
    }
  }

  double _grabTarget() => _grabToy == null ? 0 : .25;
  _Toy? _grabToy;

  void _decideGrab() {
    final t = _grabToy;
    if (t == null) {
      host.sfx(Sfx.oops, volume: .7);
      host.fx.pop(host.tr('miss', 'MISS'), Offset(_cx, _cy - 30), color: Pal.gray, size: 24);
      return;
    }
    final a = (t.x - _cx).abs() / t.r;
    final pity = _tryNo >= 3 && a < .7; // last credit: the machine feels a bit sorry
    if (a > .95) {
      // prongs just shove it
      t.x += (t.x - _cx).sign * 12;
      t.falling = true;
      t.vy = -120;
      t.face = Face.angry;
      host.sfx(Sfx.boing);
      host.fx.pop(host.tr('oops', 'OOPS!'), Offset(_cx, _cy - 30), color: Pal.red, size: 26);
      return;
    }
    _held = t;
    t.gripOff = (t.x - _cx);
    _gripQ = (a / .95).clamp(0.0, 1.0);
    final heavy = t.kind == _Kind.prize ? .2 : 0.0;
    final slipChance = pity ? .3 : (a < .35 ? .04 + heavy : (a < .7 ? .7 + heavy : .95));
    if (chance(slipChance)) {
      // slips during lift (near the top = maximum pain) or during carry
      _slipAt = chance(.55) ? rand(.55, .95) : rand(1.0, 1.9);
    } else {
      _slipAt = -1;
    }
    host.sfx(Sfx.squish, rate: 1.1);
    host.fx.sparkle(Offset(t.x, t.y), count: 6, radius: 20);
    if (a < .35) {
      host.fx.pop(host.tr('perfect', 'PERFECT!'), Offset(_cx, _cy - 40), color: Pal.yellow, size: 26);
      host.sfx(Sfx.correct, volume: .6);
    } else {
      host.fx.pop(host.tr('good', 'GOOD'), Offset(_cx, _cy - 40), color: Pal.sky, size: 22);
    }
  }

  void _slip() {
    final h = _held;
    if (h == null) return;
    _held = null;
    _slipAt = -1;
    h.falling = true;
    h.vy = 0;
    h.vx = rand(-40, 40);
    h.face = Face.shocked;
    _open = .7;
    host.sfx(Sfx.aww, volume: .8);
    host.sfx(Sfx.whoosh, rate: .8);
    host.shake(3);
    host.fx.pop(host.tr('noooo', 'NOOOO!'), Offset(h.x, h.y - 40), color: Pal.pink, size: 30, life: 1);
  }

  void _winNow(_Toy t) {
    _won = true;
    _lightBoost = 1;
    host.sfx(Sfx.fanfare);
    host.sfx(Sfx.coins);
    host.shake(8, .4);
    host.flash(Pal.yellow, .2);
    host.fx.confetti(at: const Offset(58, 560), count: 60);
    host.fx.coins(const Offset(58, 560), count: 20, speed: 480);
    host.fx.pop(host.tr('get', 'GET!!'), const Offset(180, 300), color: Pal.yellow, size: 56, life: 1.5);
    final stars = t.kind == _Kind.prize || _tryNo == 1 ? 3 : (_tryNo == 2 ? 2 : 1);
    host.win(stars: stars);
  }

  void _nextTry() {
    if (_won) return;
    if (_tries <= 0) {
      host.sfx(Sfx.buzzer);
      host.lose();
      return;
    }
    _set(_St.aim);
    _dir = 1;
    _holdMoved = 0;
    if (_tries == 1) {
      host.fx.pop(host.tr('last', 'LAST!'), const Offset(180, 260), color: Pal.red, size: 34);
    }
  }

  void _startHold() {
    if (host.finished || _st != _St.aim || _tries <= 0 || _holding) return;
    _holding = true;
    _holdMoved = 0;
    host.sfx(Sfx.engine, volume: .4, rate: 1.4);
  }

  void _releaseHold() {
    if (!_holding) return;
    _holding = false;
    if (_st != _St.aim) return;
    if (_cx < _chuteRight + 12) return; // barely moved: don't waste a credit
    _tries--;
    _tryNo++;
    // find what's below
    _grabToy = null;
    var best = double.infinity;
    var stop = _floor - 40;
    for (final t in _toys) {
      if (t.falling || t.inChute) continue;
      final dx = (t.x - _cx).abs();
      if (dx < t.r + 10) {
        final top = t.y - t.r;
        if (top - 40 < stop) stop = top - 40;
      }
    }
    for (final t in _toys) {
      if (t.falling || t.inChute) continue;
      final dx = (t.x - _cx).abs();
      if (dx < t.r + 8 && (t.y - t.r - 40 - stop).abs() < 16 && dx < best) {
        best = dx;
        _grabToy = t;
      }
    }
    _stopY = stop + 4;
    _set(_St.drop);
    host.sfx(Sfx.whoosh);
  }

  @override
  void onDown(Offset p) => _startHold();

  @override
  void onUp(Offset p) => _releaseHold();

  @override
  void onKey(String key, bool down) {
    if (key == 'right' || key == 'action') down ? _startHold() : _releaseHold();
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    // arcade room backdrop
    D.gradientBg(c, const [Color(0xFF2B1B5E), Color(0xFF14103A)]);
    for (var i = 0; i < 9; i++) {
      final x = (i * 53 + 20) % 360.0;
      c.drawCircle(Offset(x, 80 + (i * 71) % 520.0), 30 + (i % 3) * 12,
          D.fill(D.hsv(i * 47 + _t * 20, .6, 1, .07)));
    }

    // cabinet body
    const cab = Rect.fromLTRB(10, 40, 350, 636);
    D.rrect(c, cab.shift(const Offset(0, 6)), 26, const Color(0xFF8A1F5C));
    D.rrect(c, cab, 26, const Color(0xFFFF6FB5),
        border: Pal.ink,
        borderWidth: 4,
        gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF8CC6), Color(0xFFFF4FA3), Color(0xFFE23C8A)]));
    // marquee
    const marq = Rect.fromLTRB(26, 48, 334, 96);
    D.rrect(c, marq, 16, const Color(0xFFFFF4DC), border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < 14; i++) {
      final on = ((i + (_t * 8).floor()) % 3 == 0) || _lightBoost > .1;
      final p = Offset(40 + i * 21.5, 52);
      c.drawCircle(p, 4.2, D.fill(on ? D.hsv(i * 26 + _t * 90, .8, 1) : const Color(0xFFD8C9B0)));
      final q = Offset(40 + i * 21.5, 92);
      c.drawCircle(q, 4.2, D.fill(!on ? D.hsv(i * 26 + _t * 90, .8, 1) : const Color(0xFFD8C9B0)));
    }
    // marquee emblem: heart + big claw icon + stars
    D.heart(c, const Offset(92, 74), 30 + 3 * M.wave(_t, 2), Pal.red, border: Pal.ink);
    D.heart(c, const Offset(268, 74), 30 + 3 * M.wave(_t + .5, 2), Pal.red, border: Pal.ink);
    for (var i = 0; i < 3; i++) {
      final used = i >= _tries;
      final p = Offset(152 + i * 28.0, 73);
      if (used) {
        c.drawCircle(p, 11, D.fill(const Color(0xFFBDB2A0)));
        c.drawCircle(p, 11, D.stroke(Pal.ink, 2));
      } else {
        D.coin(c, p, 11, spin: _t * .5 + i * .2);
      }
    }

    // glass pit
    const pit = Rect.fromLTRB(22, 102, 338, 540);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(pit, const Radius.circular(14)));
    D.gradientBg(c, const [Color(0xFFFFE3F1), Color(0xFFD6F1FF)], rect: pit);
    // polka dots + stars on the back wall
    for (var y = 0; y < 9; y++) {
      for (var x = 0; x < 7; x++) {
        final o = Offset(40 + x * 48.0 + (y.isOdd ? 24 : 0), 120 + y * 46.0);
        if ((x + y) % 3 == 0) {
          D.star(c, o, 7, const Color(0x55FFC53D));
        } else {
          c.drawCircle(o, 5, D.fill(const Color(0x33FF5FC8)));
        }
      }
    }
    // floor
    D.rrect(c, const Rect.fromLTRB(22, _floor, 338, 540), 0, const Color(0xFF7B5CD6));
    for (var x = 22.0; x < 338; x += 24) {
      c.drawRect(Rect.fromLTWH(x, _floor, 12, 40), D.fill(const Color(0xFF8E73E6)));
    }
    // chute (prize hole)
    const chute = Rect.fromLTRB(22, _chuteTop, _chuteRight, 540);
    D.rrect(c, chute, 0, const Color(0xFF231A44));
    for (var i = 0; i < 6; i++) {
      final y = _chuteTop + i * 20.0;
      c.drawLine(Offset(22, y + 8), Offset(_chuteRight, y + 18), D.stroke(const Color(0x22FFFFFF), 6));
    }
    // chute walls (acrylic)
    D.rrect(c, Rect.fromLTRB(_chuteRight - 4, _chuteTop - 6, _chuteRight + 6, _floor + 2), 3, const Color(0xAAE6F6FF),
        border: const Color(0xFF6FB6E0), borderWidth: 2);
    final arrowBob = sin(_t * 6) * 4;
    D.arrow(c, Offset(58, _chuteTop - 26 + arrowBob), const Offset(0, 1), 26, Pal.yellow, width: 9);
    if (_won) D.rays(c, const Offset(58, 480), 300, const Color(0x55FFE066), count: 14, t: _t);

    // rail + trolley + cable
    c.drawRect(const Rect.fromLTRB(22, _railY - 8, 338, _railY + 4), D.fill(const Color(0xFF6B6F86)));
    c.drawRect(const Rect.fromLTRB(22, _railY - 8, 338, _railY - 4), D.fill(const Color(0xFFA8ADC6)));
    D.rrect(c, Rect.fromCenter(center: Offset(_cx, _railY), width: 38, height: 18), 5, const Color(0xFF4A4E66),
        border: Pal.ink, borderWidth: 2.5);

    // toys (background ones first)
    final order = [..._toys]..sort((a, b) => a.y.compareTo(b.y));
    for (final t in order) {
      if (identical(t, _held)) continue;
      _drawToy(c, t);
    }
    // cable
    final cableX = _cx + sin(_t * 9) * _wob * 3;
    c.drawLine(Offset(_cx, _railY + 6), Offset(cableX, _cy - 10), D.stroke(const Color(0xFF3A3A48), 3));
    if (_held != null) _drawToy(c, _held!);
    _drawClaw(c, Offset(cableX, _cy));

    // aim line
    if (_st == _St.aim && !host.finished) {
      final p = Paint()..color = const Color(0x66FF3B5C);
      for (var y = _cy + 36; y < _floor; y += 14) {
        c.drawCircle(Offset(_cx, y), 2.5, p);
      }
    }
    // glass reflections
    final glare = Paint()..color = const Color(0x2EFFFFFF);
    for (final off in [0.0, 60.0]) {
      final x0 = 60 + off + ((_t * 12) % 40);
      c.drawPath(
          Path()
            ..moveTo(x0, 102)
            ..lineTo(x0 + 26 - off * .2, 102)
            ..lineTo(x0 - 140 - off * .2, 540)
            ..lineTo(x0 - 166, 540)
            ..close(),
          glare);
    }
    c.restore();
    c.drawRRect(RRect.fromRectAndRadius(pit, const Radius.circular(14)), D.stroke(Pal.ink, 4));

    // control panel
    const panel = Rect.fromLTRB(26, 552, 334, 628);
    D.rrect(c, panel, 16, const Color(0xFF2D2450), border: Pal.ink, borderWidth: 3);
    // prize door
    D.rrect(c, const Rect.fromLTRB(36, 560, 110, 620), 10, const Color(0xFF15102A), border: const Color(0xFFFFC53D), borderWidth: 2.5);
    // joystick
    final tilt = _holding ? 10.0 : 0.0;
    c.drawLine(const Offset(170, 606), Offset(170 + tilt, 580), D.stroke(const Color(0xFF9AA0B8), 6));
    D.circle(c, const Offset(170, 608), 14, const Color(0xFF15102A), border: Pal.ink, borderWidth: 2);
    D.circle(c, Offset(170 + tilt, 578), 12, Pal.red, border: Pal.ink, borderWidth: 2.5);
    c.drawCircle(Offset(166 + tilt, 574), 4, D.fill(const Color(0x88FFFFFF)));
    // big button
    final pressed = _holding;
    D.circle(c, const Offset(270, 596), 28, const Color(0xFF8A1030));
    D.circle(c, Offset(270, pressed ? 594 : 588), 26, _st == _St.aim ? Pal.red : const Color(0xFFB04060),
        border: Pal.ink, borderWidth: 3);
    c.drawOval(Rect.fromCenter(center: Offset(262, pressed ? 586 : 580), width: 18, height: 10), D.fill(const Color(0x77FFFFFF)));
    D.arrow(c, Offset(270, pressed ? 592 : 586), const Offset(1, 0), 24, Pal.white, width: 7);

    // tutorial
    if (_st == _St.aim && _tryNo == 0 && host.time < 3 && !_holding) {
      D.hand(c, const Offset(270, 590), _t);
      D.text(c, host.tr('hold', 'HOLD'), const Offset(270, 540), size: 22, color: Pal.yellow, stroke: Pal.ink);
    } else if (_st == _St.aim && _holding && _tryNo == 0 && _holdMoved < 1.2) {
      D.text(c, host.tr('release', 'RELEASE!'), Offset(_cx, 200), size: 18, color: Pal.white, stroke: Pal.ink);
    }
  }

  void _drawClaw(Canvas c, Offset at) {
    final o = _open;
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(1.4);
    const hub = Offset.zero;
    // hub
    D.rrect(c, Rect.fromCenter(center: hub + const Offset(0, -4), width: 30, height: 20), 6, const Color(0xFFC9CEDF),
        border: Pal.ink, borderWidth: 2.5);
    c.drawCircle(hub + const Offset(0, -4), 4, D.fill(_st == _St.aim ? Pal.lime : Pal.red));
    for (final s in [-1.0, 1.0]) {
      final a = s * (.25 + o * .75);
      final elbow = hub + Offset(sin(a) * 26, 8 + cos(a) * 18);
      final tipA = a - s * (1.1 + (1 - o) * .6);
      final tip = elbow + Offset(sin(tipA) * 22, cos(tipA) * 22);
      c.drawLine(hub + Offset(s * 8, 4), elbow, D.stroke(Pal.ink, 8));
      c.drawLine(elbow, tip, D.stroke(Pal.ink, 8));
      c.drawLine(hub + Offset(s * 8, 4), elbow, D.stroke(const Color(0xFFB8BED3), 5));
      c.drawLine(elbow, tip, D.stroke(const Color(0xFFB8BED3), 5));
      c.drawCircle(elbow, 4, D.fill(const Color(0xFF6B6F86)));
      c.drawCircle(tip, 3.5, D.fill(const Color(0xFFE8ECF8)));
    }
    // center prong
    c.drawLine(hub + const Offset(0, 6), hub + const Offset(0, 24), D.stroke(Pal.ink, 7));
    c.drawLine(hub + const Offset(0, 6), hub + const Offset(0, 24), D.stroke(const Color(0xFFB8BED3), 4));
    c.restore();
  }

  void _drawToy(Canvas c, _Toy t) {
    final p = Offset(t.x, t.y);
    final r = t.r;
    final col = t.color;
    final dark = Color.lerp(col, Pal.ink, .3)!;
    if (!t.falling && !identical(t, _held) && !t.inChute) {
      D.shadow(c, Offset(t.x, min(_floor + 2, t.y + r)), r * 1.6, 6, .15);
    }
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(t.spin + (identical(t, _held) ? sin(_t * 14) * _wob * .3 : 0));
    switch (t.kind) {
      case _Kind.bear || _Kind.prize:
        for (final s in [-1.0, 1.0]) {
          D.circle(c, Offset(s * r * .72, -r * .72), r * .36, col, border: Pal.ink, borderWidth: 2.5);
          c.drawCircle(Offset(s * r * .72, -r * .72), r * .18, D.fill(dark));
        }
      case _Kind.bunny:
        for (final s in [-1.0, 1.0]) {
          final ear = RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(s * r * .4, -r * 1.2), width: r * .5, height: r * 1.2), Radius.circular(r * .25));
          c.drawRRect(ear, D.fill(col));
          c.drawRRect(ear, D.stroke(Pal.ink, 2.5));
          c.drawRRect(ear.deflate(r * .1), D.fill(const Color(0xFFFF7FB0)));
        }
      case _Kind.cat:
        for (final s in [-1.0, 1.0]) {
          final ear = Path()
            ..moveTo(s * r * .9, -r * .2)
            ..lineTo(s * r * .75, -r * 1.25)
            ..lineTo(s * r * .15, -r * .75)
            ..close();
          c.drawPath(ear, D.fill(col));
          c.drawPath(ear, D.stroke(Pal.ink, 2.5));
        }
      case _Kind.chick:
        final tuft = Path()
          ..moveTo(-4, -r * .9)
          ..quadraticBezierTo(0, -r * 1.5, 6, -r * .95)
          ..close();
        c.drawPath(tuft, D.fill(Pal.orange));
      case _Kind.slime:
        break;
    }
    if (t.kind == _Kind.slime) {
      D.blob(c, Offset.zero, r, col, face: t.face);
    } else {
      c.drawCircle(Offset.zero, r, D.fill(col));
      c.drawOval(Rect.fromCenter(center: Offset(-r * .35, -r * .45), width: r * .6, height: r * .35), D.fill(const Color(0x55FFFFFF)));
      c.drawCircle(Offset.zero, r, D.stroke(Pal.ink, 3));
      if (t.kind == _Kind.bear || t.kind == _Kind.prize) {
        c.drawOval(Rect.fromCenter(center: Offset(0, r * .3), width: r * .8, height: r * .55), D.fill(const Color(0xFFFFE6C8)));
      }
      D.face(c, const Offset(0, 0), r * .9, t.face);
      if (t.kind == _Kind.chick) {
        final beak = Path()
          ..moveTo(-5, r * .2)
          ..lineTo(5, r * .2)
          ..lineTo(0, r * .42)
          ..close();
        c.drawPath(beak, D.fill(Pal.orange));
      }
    }
    if (t.kind == _Kind.prize) {
      final crown = Path()
        ..moveTo(-r * .6, -r * .85)
        ..lineTo(-r * .6, -r * 1.45)
        ..lineTo(-r * .3, -r * 1.15)
        ..lineTo(0, -r * 1.6)
        ..lineTo(r * .3, -r * 1.15)
        ..lineTo(r * .6, -r * 1.45)
        ..lineTo(r * .6, -r * .85)
        ..close();
      c.drawPath(crown, D.fill(Pal.yellow));
      c.drawPath(crown, D.stroke(Pal.ink, 2.5));
      c.drawCircle(Offset(0, -r * 1.1), 3.5, D.fill(Pal.red));
    }
    c.restore();
    if (t.kind == _Kind.prize && !t.inChute) {
      final s = M.wave(_t, 1.3);
      D.star(c, p + Offset(r * 1.1, -r * 1.2), 4 + s * 4, Pal.white);
    }
  }
}

enum _St { aim, drop, close, lift, carry, release }

enum _Kind { bear, bunny, cat, chick, slime, prize }

class _Toy {
  _Toy(this.kind, this.x, this.y, this.r, this.color);
  final _Kind kind;
  double x, y;
  final double r;
  final Color color;
  double vy = 0;
  double vx = 0;
  double spin = 0;
  double gripOff = 0;
  bool falling = false;
  bool inChute = false;
  Face face = Face.happy;
}
