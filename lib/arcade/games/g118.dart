import '../engine/engine.dart';

/// No.118 Daily Reward Wheel — tap today's gift, smash it open, stop the
/// bonus wheel on the biggest multiplier... and discover what Day 7 gives.
class G118 extends MiniGame {
  static const _auto = bool.fromEnvironment('AUTOPLAY');
  static const _segs = <int>[2, 5, 3, 10, 2, 100, 3, 5];
  static const _segCols = <Color>[
    Pal.sky, Pal.pink, Pal.teal, Pal.purple, Pal.sky, Pal.gold, Pal.teal, Pal.pink,
  ];
  static const _wheelC = Offset(180, 360);
  static const _wheelR = 120.0;
  static const _spinV = 11.0;
  static const _stopDist = pi * 2 * 1.35;

  _Ph _ph = _Ph.calendar;
  double _phT = 0;
  double _t = 0;
  double _idle = 0;
  int _hits = 0;
  double _boxShake = 0;
  double _boxSquash = 0;
  double _lid = 0; // 0 closed .. 1 flown
  int _gems = 0;
  double _shownGems = 0;
  double _angle = 0;
  double _angV = 0;
  double _decel = 0;
  bool _stopping = false;
  int _lastSeg = -1;
  int _mult = 1;
  double _zoom = 0;
  double _flip = 0;
  double _mascotBounce = 0;
  int _stars = 1;

  static const _gift = 300;

  @override
  void init() {
    _angle = rand(0, pi * 2);
  }

  Rect _dayRect(int i) {
    if (i < 4) return Rect.fromLTWH(22 + i * 81.0, 180, 72, 96);
    if (i < 6) return Rect.fromLTWH(22 + (i - 4) * 81.0, 290, 72, 96);
    return const Rect.fromLTWH(184, 290, 153, 96);
  }

  void _go(_Ph p) {
    _ph = p;
    _phT = 0;
    _idle = 0;
  }

  @override
  void update(double dt) {
    _t += dt;
    _phT += dt;
    _idle += dt;
    _boxShake = M.approach(_boxShake, 0, 8, dt);
    _boxSquash = M.approach(_boxSquash, 0, 10, dt);
    _mascotBounce = M.approach(_mascotBounce, 0, 6, dt);
    _shownGems = M.approach(_shownGems, _gems.toDouble(), 5, dt);
    if ((_shownGems - _gems).abs() < 1) _shownGems = _gems.toDouble();
    if ((_t * 20).floor() != ((_t - dt) * 20).floor() && (_shownGems - _gems).abs() > 2) {
      host.sfx(Sfx.count, volume: .25, rate: 1.8);
    }
    switch (_ph) {
      case _Ph.calendar:
        if (_idle > 2.6 || (_auto && _phT > .2)) _claim();
      case _Ph.zoom:
        _zoom = M.approach(_zoom, 1, 7, dt);
        if (_phT > .45) _go(_Ph.box);
      case _Ph.box:
        if (_idle > 1.2 || (_auto && _idle > .3)) _hitBox();
        if (_hits >= 3) {
          _lid = min(1, _lid + dt * 3);
          if (_phT > 1.1) {
            _go(_Ph.wheel);
            _angV = _spinV * host.speed;
            host.sfx(Sfx.spin);
            host.sfx(Sfx.drumroll, volume: .6);
          }
        }
      case _Ph.wheel:
        _angle += _angV * dt;
        if (_stopping) {
          _angV = max(0, _angV - _decel * dt);
          if (_angV <= 0) _landWheel();
        } else if (_idle > 2.8 || (_auto && _phT > 1.5 && _segAt(_angle + _stopDist) == 5)) {
          _stopWheel();
        }
        final s = _segAt(_angle);
        if (s != _lastSeg) {
          _lastSeg = s;
          host.sfx(Sfx.tick, volume: .4, rate: 1.2 + _angV * .04);
        }
      case _Ph.result:
        if (_phT > 1.3) {
          _go(_Ph.trap);
          _zoom = 1;
          host.sfx(Sfx.drumroll, volume: .7);
        }
      case _Ph.trap:
        _zoom = M.approach(_zoom, 0, 6, dt);
        if (_phT > .7) _flip = min(1, _flip + dt * 2.5);
        if (_phT > .7 && _phT - dt <= .7) host.sfx(Sfx.flip);
        if (_phT > 1.2 && _phT - dt <= 1.2) {
          host.sfx(Sfx.oops, volume: .8);
          host.fx.pop(host.tr('login_bonus', 'LOGIN BONUS'), const Offset(260, 250), color: Pal.pink, size: 22, life: 1.4);
          _mascotBounce = 1;
        }
        if (_phT > 1.9 && !host.finished) host.win(stars: _stars);
    }
  }

  // Segment index under the pointer (pointer at the top of the wheel).
  int _segAt(double ang) {
    const seg = pi * 2 / 8;
    // segment i spans [i*seg, (i+1)*seg) in wheel space starting at pointer
    final a = ((-ang - pi / 2 + pi / 2) % (pi * 2) + pi * 2) % (pi * 2);
    return (a / seg).floor() % 8;
  }

  void _claim() {
    if (_ph != _Ph.calendar) return;
    host.sfx(Sfx.open);
    host.sfx(Sfx.whoosh);
    host.fx.sparkle(_dayRect(5).center, count: 12, radius: 40, color: Pal.yellow);
    _go(_Ph.zoom);
  }

  void _hitBox() {
    if (_ph != _Ph.box || _hits >= 3) return;
    _hits++;
    _idle = 0;
    _boxShake = 1;
    _boxSquash = 1;
    const at = Offset(180, 380);
    if (_hits < 3) {
      host.sfx(Sfx.hit, rate: 1 + _hits * .15);
      host.shake(4 + _hits * 2.0);
      host.fx.burst(at, Pal.yellow, count: 10, speed: 220, shape: PartShape.spark);
      host.fx.pop('${3 - _hits}', at + const Offset(0, -110), color: Pal.white, size: 40);
    } else {
      _phT = 0;
      _gems = _gift;
      host.sfx(Sfx.explode, volume: .6);
      host.sfx(Sfx.ssr);
      host.sfx(Sfx.coins);
      host.hitStop(.08);
      host.shake(10, .4);
      host.flash(Pal.white, .25);
      host.punch(.06);
      host.fx.ring(at, Pal.yellow, size: 160, life: .5);
      host.fx.burst(at, Pal.sky, count: 40, speed: 520, size: 10, shape: PartShape.star, colors: const [Pal.sky, Pal.pink, Pal.purple, Pal.teal]);
      host.fx.coins(at, count: 20, speed: 520);
      host.fx.pop('+$_gift', at + const Offset(0, -80), color: Pal.sky, size: 44, life: 1.1);
    }
  }

  void _stopWheel() {
    if (_ph != _Ph.wheel || _stopping) return;
    _stopping = true;
    _idle = 0;
    _decel = _angV * _angV / (2 * _stopDist);
    host.sfx(Sfx.click);
    host.sfx(Sfx.heartbeat, volume: .5);
  }

  void _landWheel() {
    final seg = _segAt(_angle);
    _mult = _segs[seg];
    _stars = _mult >= 10 ? 3 : (_mult >= 5 ? 2 : 1);
    _gems = _gift * _mult;
    _go(_Ph.result);
    host.sfx(Sfx.reelStop);
    final big = _mult >= 10;
    host.sfx(big ? Sfx.fanfare : Sfx.levelup);
    host.sfx(Sfx.cash);
    host.shake(big ? 12 : 6, .4);
    host.flash(big ? Pal.yellow : Pal.white, .25);
    host.fx.confetti(count: big ? 90 : 40);
    host.fx.coins(_wheelC, count: big ? 40 : 18, speed: 600);
    host.fx.pop('x$_mult', _wheelC, color: _mult >= 100 ? Pal.yellow : Pal.white, size: big ? 70 : 54, life: 1.3);
    if (_mult >= 100) host.fx.pop(host.tr('jackpot', 'JACKPOT!'), _wheelC + const Offset(0, -80), color: Pal.pink, size: 38, life: 1.3);
    // near-miss tease
    final nb = [_segAt(_angle + pi / 4), _segAt(_angle - pi / 4)];
    if (_mult < 100 && nb.contains(5)) {
      host.fx.pop(host.tr('so_close', 'SO CLOSE!'), _wheelC + const Offset(0, 80), color: Pal.pink, size: 26, life: 1.2);
    }
  }

  @override
  void onDown(Offset p) {
    _idle = 0;
    switch (_ph) {
      case _Ph.calendar:
        if (_dayRect(5).inflate(20).contains(p)) {
          _claim();
        } else {
          // wrong day: the mascot is NOT amused
          _mascotBounce = 1;
          host.sfx(Sfx.buzzer, volume: .5);
          host.fx.pop(host.tr('today', 'TODAY!'), _dayRect(5).center + const Offset(0, -60), color: Pal.red, size: 24);
        }
      case _Ph.box:
        _hitBox();
      case _Ph.wheel:
        _stopWheel();
      default:
        break;
    }
  }

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action') {
      if (_ph == _Ph.calendar) {
        _claim();
      } else {
        onDown(const Offset(180, 380));
      }
    }
  }

  @override
  void onTimeUp() => host.win(stars: _ph.index >= _Ph.result.index ? _stars : 1);

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFFFFD1EC), Color(0xFFB9A6FF), Color(0xFF7C6CF2)]);
    D.rays(c, const Offset(180, 330), 600, const Color(0x22FFFFFF), count: 20, t: _t * .25);
    // floating background gems
    for (var i = 0; i < 10; i++) {
      final y = (i * 83 + _t * 25) % 700 - 30;
      final x = (i * 67 + 20) % 340 + 10.0;
      D.gem(c, Offset(x, 640 - y), 6 + (i % 3) * 3, Pal.candy[i % 8].withValues(alpha: .5));
    }

    _header(c);
    _mascot(c);

    final showCal = _ph == _Ph.calendar || _ph == _Ph.zoom || _ph == _Ph.trap;
    if (showCal) _calendar(c);

    if (_ph == _Ph.zoom || _ph == _Ph.box) _box(c);
    if (_ph == _Ph.wheel || _ph == _Ph.result) _wheel(c);

    if (_ph == _Ph.trap && _flip >= 1) {
      final k = M.easeOutBack(((_phT - 1.1) * 3).clamp(0, 1));
      c.save();
      c.translate(180, 590);
      c.scale(k);
      c.rotate(-.05);
      D.rrect(c, Rect.fromCenter(center: Offset.zero, width: 250, height: 58), 10, Pal.white, border: Pal.pink, borderWidth: 4);
      D.text(c, '${host.tr('day', 'Day')} 7:', const Offset(-78, 0), size: 18, color: Pal.ink);
      D.text(c, host.tr('login_bonus', 'LOGIN BONUS'), const Offset(38, 0), size: 20, color: Pal.pink, maxWidth: 160);
      c.restore();
    }
    if (_ph == _Ph.calendar && host.time < 3) {
      D.hand(c, _dayRect(5).center + const Offset(0, 10), _t);
    }
    if (_ph == _Ph.box && _hits < 3 && _phT > .1) {
      D.text(c, host.tr('tap', 'TAP!'), const Offset(180, 520), size: 30 + 4 * M.wave(_t, 3), color: Pal.yellow, stroke: Pal.ink);
    }
    if (_ph == _Ph.wheel && !_stopping) {
      D.button(c, const Rect.fromLTWH(110, 520, 140, 56), host.tr('stop', 'STOP!'), color: Pal.red, fontSize: 26,
          pressed: (_t * 3) % 1 < .15);
    }
  }

  void _header(Canvas c) {
    // gem counter
    D.rrect(c, const Rect.fromLTWH(16, 44, 190, 44), 22, const Color(0xCC1B1530), border: Pal.white, borderWidth: 2.5);
    D.gem(c, const Offset(40, 66), 13, Pal.sky);
    D.text(c, M.big(_shownGems.round()), const Offset(62, 66), size: 26, color: Pal.white, stroke: Pal.ink,
        anchor: Alignment.centerLeft);
    // streak flame
    final streak = _ph.index >= _Ph.zoom.index ? 6 : 5;
    D.rrect(c, const Rect.fromLTWH(216, 44, 80, 44), 22, const Color(0xCC1B1530), border: Pal.orange, borderWidth: 2.5);
    D.flame(c, const Offset(240, 80), 30 + 4 * M.wave(_t, 2), _t);
    D.text(c, '$streak', const Offset(272, 66), size: 28, color: Pal.orange, stroke: Pal.ink);
  }

  void _mascot(Canvas c) {
    if (_ph == _Ph.wheel || _ph == _Ph.result || _ph == _Ph.box) return;
    final angry = _ph == _Ph.calendar && (_idle > 1.3 || _mascotBounce > .3);
    final trap = _ph == _Ph.trap && _phT > 1.2;
    final o = Offset(84, 520 - _mascotBounce * 20 + sin(_t * 4) * 4);
    D.shadow(c, const Offset(84, 572), 80, 14);
    D.blob(c, o, 44, Pal.pink, face: trap ? Face.smug : (angry ? Face.angry : Face.happy), squash: 1 + _mascotBounce * .2);
    // tiny calendar held up
    final cal = o + const Offset(40, -30);
    D.rrect(c, Rect.fromCenter(center: cal, width: 30, height: 30), 5, Pal.white, border: Pal.ink, borderWidth: 2.5);
    c.drawRect(Rect.fromCenter(center: cal + const Offset(0, -10), width: 28, height: 8), D.fill(Pal.red));
    D.text(c, trap ? '7' : '6', cal + const Offset(0, 4), size: 14, color: Pal.ink);
    // speech bubble
    final r = Rect.fromLTWH(150, 460, 190, 60);
    D.bubble(c, r, color: Pal.white);
    c.drawPath(
        Path()
          ..moveTo(150, 500)
          ..lineTo(128, 512)
          ..lineTo(152, 486)
          ..close(),
        D.fill(Pal.white));
    final msg = trap
        ? host.tr('see_you_tomorrow', 'See you tomorrow!')
        : (angry ? '!!!' : host.tr('log_in_every_day', 'Log in every day!'));
    D.text(c, msg, r.center, size: angry && !trap ? 30 : 17, color: angry && !trap ? Pal.red : Pal.ink, maxWidth: 176);
  }

  void _calendar(Canvas c) {
    final out = _ph == _Ph.zoom ? _zoom : (_ph == _Ph.trap ? _zoom : 0.0);
    c.save();
    if (out > 0) {
      c.translate(180, 300);
      c.scale(1 + out * .3);
      c.translate(-180, -300);
    }
    // board
    D.rrect(c, const Rect.fromLTWH(12, 130, 336, 270), 20, const Color(0xEEFFFFFF), border: Pal.ink, borderWidth: 3);
    D.rrect(c, const Rect.fromLTWH(12, 130, 336, 40), 20, Pal.purple);
    c.drawRect(const Rect.fromLTWH(12, 150, 336, 20), D.fill(Pal.purple));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(12, 130, 336, 270), const Radius.circular(20)), D.stroke(Pal.ink, 3));
    // ring binders
    for (var i = 0; i < 6; i++) {
      final x = 50 + i * 52.0;
      D.rrect(c, Rect.fromCenter(center: Offset(x, 132), width: 8, height: 22), 4, const Color(0xFFDDDDEE), border: Pal.ink, borderWidth: 2);
    }
    D.text(c, host.tr('login_bonus', 'LOGIN BONUS'), const Offset(180, 152), size: 18, color: Pal.white, stroke: Pal.ink);
    for (var i = 0; i < 7; i++) {
      _day(c, i);
    }
    c.restore();
  }

  void _day(Canvas c, int i) {
    final r = _dayRect(i);
    final today = i == 5;
    final claimed = i < 5 || (today && _ph != _Ph.calendar);
    final pulse = today && _ph == _Ph.calendar ? 1 + .06 * sin(_t * 8) : 1.0;
    c.save();
    c.translate(r.center.dx, r.center.dy);
    c.scale(pulse);
    if (i == 6 && _flip > 0) c.scale((cos(_flip * pi)).abs().clamp(.05, 1.0), 1);
    final lr = Rect.fromCenter(center: Offset.zero, width: r.width, height: r.height);
    final col = i == 6 ? const Color(0xFFFFE9A8) : (today ? const Color(0xFFFFF4DC) : const Color(0xFFE9E4FA));
    if (today && _ph == _Ph.calendar) {
      D.rrect(c, lr.inflate(6), 16, Pal.yellow.withValues(alpha: .5 + .3 * M.wave(_t, 3)));
    }
    D.rrect(c, lr, 12, col, border: Pal.ink, borderWidth: 2.5);
    D.text(c, '${host.tr('day', 'Day')} ${i + 1}', Offset(0, -lr.height / 2 + 12), size: 12, color: Pal.ink);
    if (i < 5) {
      D.gem(c, const Offset(0, 4), 14, Pal.candy[(i * 2 + 4) % 8]);
      D.text(c, '${(i + 1) * 50}', Offset(0, lr.height / 2 - 12), size: 12, color: const Color(0xFF6A5A9A));
    } else if (today) {
      if (_ph == _Ph.calendar) _drawGift(c, const Offset(0, 6), 26, 0, 0);
      D.text(c, host.tr('today', 'TODAY!'), Offset(0, lr.height / 2 - 12), size: 12, color: Pal.red);
    } else {
      final back = _flip < .5;
      if (back) {
        _drawChest(c, const Offset(0, 8), 34);
        D.text(c, '???', const Offset(40, -22), size: 16, color: Pal.orange, stroke: Pal.ink, strokeWidth: 3);
      } else {
        // the trap: a ticket that says... login bonus
        c.save();
        c.rotate(-.08);
        D.rrect(c, Rect.fromCenter(center: const Offset(0, 8), width: 110, height: 46), 8, const Color(0xFFFFFFFF),
            border: Pal.pink, borderWidth: 3);
        for (final s in [-1.0, 1.0]) {
          c.drawCircle(Offset(s * 55, 8), 7, D.fill(col));
        }
        D.text(c, host.tr('login_bonus', 'LOGIN BONUS'), const Offset(0, 2), size: 13, color: Pal.pink, maxWidth: 96);
        D.text(c, 'x1', const Offset(0, 20), size: 12, color: Pal.ink);
        c.restore();
      }
    }
    c.restore();
    if (claimed) {
      // CLAIMED stamp (check mark)
      c.save();
      c.translate(r.center.dx + 16, r.center.dy + 8);
      c.rotate(-.3);
      c.drawCircle(Offset.zero, 17, D.stroke(const Color(0xCCFF3B5C), 3.5));
      final chk = Path()
        ..moveTo(-8, 0)
        ..lineTo(-2, 7)
        ..lineTo(9, -7);
      c.drawPath(chk, D.stroke(const Color(0xDDFF3B5C), 4.5));
      c.restore();
    }
    if (i < 6 && i > 0) {
      // streak fire between days
      D.flame(c, Offset(r.left - 4, r.top + 8), 12, _t + i);
    }
  }

  void _box(Canvas c) {
    final k = _ph == _Ph.zoom ? _zoom : 1.0;
    final from = _dayRect(5).center;
    const to = Offset(180, 380);
    final p = Offset.lerp(from, to, M.easeOut(k))!;
    final size = M.lerp(26, 88, M.easeOutBack(k.clamp(0, 1)));
    // dim + glow
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), D.fill(Color.fromRGBO(20, 10, 40, .45 * k)));
    D.rays(c, p, 300, Color.fromRGBO(255, 230, 120, .25 * k + _hits * .08), count: 14, t: _t * (1 + _hits));
    final shake = Offset(sin(_t * 60) * _boxShake * 8, 0);
    _drawGift(c, p + shake, size, _lid, _boxSquash);
    // cracks with light leaking
    for (var i = 0; i < _hits && _lid == 0; i++) {
      final a = -1.2 + i * 1.1;
      c.drawLine(p + Offset(cos(a) * 10, sin(a) * 10 + 20), p + Offset(cos(a) * size * .8, sin(a) * size * .5 + 20),
          D.stroke(const Color(0xFFFFF3B0), 5));
    }
  }

  void _drawGift(Canvas c, Offset o, double s, double lid, double squash) {
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(1 + squash * .12, 1 - squash * .12);
    final body = Rect.fromCenter(center: Offset(0, s * .25), width: s * 1.5, height: s * 1.1);
    D.rrect(c, body, s * .12, Pal.red, border: Pal.ink, borderWidth: max(2, s * .06));
    c.drawRect(Rect.fromCenter(center: body.center, width: s * .3, height: body.height - 2), D.fill(Pal.yellow));
    if (lid > 0) {
      // light beam from inside
      final beam = Path()
        ..moveTo(-s * .7, body.top)
        ..lineTo(s * .7, body.top)
        ..lineTo(s * 1.6, body.top - s * 3)
        ..lineTo(-s * 1.6, body.top - s * 3)
        ..close();
      c.drawPath(beam, D.fill(Color.fromRGBO(255, 240, 150, .45 * lid)));
    }
    c.save();
    c.translate(lid * s * 1.6, -lid * s * 3.2);
    c.rotate(lid * 1.8);
    final lidR = Rect.fromCenter(center: Offset(0, body.top - s * .12), width: s * 1.7, height: s * .38);
    D.rrect(c, lidR, s * .1, const Color(0xFFFF5A76), border: Pal.ink, borderWidth: max(2, s * .06));
    c.drawRect(Rect.fromCenter(center: lidR.center, width: s * .3, height: lidR.height - 2), D.fill(Pal.yellow));
    // bow
    for (final sx in [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(sx * s * .28, lidR.top - s * .12), width: s * .55, height: s * .32),
          D.fill(Pal.yellow));
      c.drawOval(Rect.fromCenter(center: Offset(sx * s * .28, lidR.top - s * .12), width: s * .55, height: s * .32),
          D.stroke(Pal.ink, max(1.5, s * .045)));
    }
    c.restore();
    c.restore();
  }

  void _drawChest(Canvas c, Offset o, double s) {
    final body = Rect.fromCenter(center: o + Offset(0, s * .2), width: s * 1.6, height: s * .8);
    D.rrect(c, body, 5, const Color(0xFFB0661F), border: Pal.ink, borderWidth: 2.5);
    final lid = Rect.fromCenter(center: o + Offset(0, -s * .3), width: s * 1.6, height: s * .45);
    D.rrect(c, lid, 10, const Color(0xFFD9822B), border: Pal.ink, borderWidth: 2.5);
    c.drawRect(Rect.fromCenter(center: o + Offset(0, s * .02), width: s * 1.6, height: 5), D.fill(Pal.gold));
    D.rrect(c, Rect.fromCenter(center: o + Offset(0, s * .05), width: 10, height: 13), 3, Pal.gold, border: Pal.ink, borderWidth: 2);
    D.star(c, o + Offset(s * .7, -s * .6), 4 + 3 * M.wave(_t, 1.5), Pal.white);
  }

  void _wheel(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), D.fill(const Color(0x33200A40)));
    final land = _ph == _Ph.result;
    if (land) D.rays(c, _wheelC, 400, Color.fromRGBO(255, 230, 120, _mult >= 10 ? .45 : .25), count: 18, t: _t * 1.2);
    final appear = M.easeOutBack((_phT * 3).clamp(0, 1));
    c.save();
    c.translate(_wheelC.dx, _wheelC.dy);
    c.scale(_ph == _Ph.wheel ? appear : 1);
    // outer ring with bulbs
    c.drawCircle(const Offset(0, 6), _wheelR + 18, D.fill(const Color(0x55000000)));
    c.drawCircle(Offset.zero, _wheelR + 18, D.fill(const Color(0xFFFFC53D)));
    c.drawCircle(Offset.zero, _wheelR + 18, D.stroke(Pal.ink, 4));
    for (var i = 0; i < 16; i++) {
      final a = i / 16 * pi * 2;
      final on = (i + (_t * 12).floor()) % 2 == 0;
      c.drawCircle(Offset(cos(a), sin(a)) * (_wheelR + 9), 4, D.fill(on ? Pal.white : const Color(0xFFB8860B)));
    }
    c.rotate(_angle);
    const seg = pi * 2 / 8;
    for (var i = 0; i < 8; i++) {
      // segment i is centered at wheel-local angle -pi/2 + (i + .5) * seg (pointer on top)
      final a0 = -pi / 2 + i * seg;
      final path = Path()
        ..moveTo(0, 0)
        ..arcTo(Rect.fromCircle(center: Offset.zero, radius: _wheelR), a0, seg, false)
        ..close();
      final hi = land && _segAt(_angle) == i && (_phT * 6).floor().isEven;
      c.drawPath(path, D.fill(hi ? Pal.white : _segCols[i]));
      c.drawPath(path, D.stroke(Pal.ink, 3));
      final mid = a0 + seg / 2;
      c.save();
      c.rotate(mid + pi / 2);
      final big = _segs[i] >= 100;
      D.text(c, 'x${_segs[i]}', Offset(0, -_wheelR * .66), size: big ? 26 : 22,
          color: big ? const Color(0xFFFF3B5C) : Pal.white, stroke: Pal.ink, strokeWidth: 5);
      if (big) D.star(c, Offset(0, -_wheelR * .38), 9, Pal.white, border: Pal.ink);
      c.restore();
    }
    c.restore();
    // hub
    D.circle(c, _wheelC, 22, Pal.gold, border: Pal.ink, borderWidth: 3.5);
    D.gem(c, _wheelC + const Offset(0, 2), 11, Pal.pink);
    // pointer at top
    final pt = Path()
      ..moveTo(_wheelC.dx - 16, _wheelC.dy - _wheelR - 34)
      ..lineTo(_wheelC.dx + 16, _wheelC.dy - _wheelR - 34)
      ..lineTo(_wheelC.dx, _wheelC.dy - _wheelR + 6)
      ..close();
    c.drawPath(pt, D.fill(Pal.red));
    c.drawPath(pt, D.stroke(Pal.ink, 3.5));
    D.text(c, host.tr('bonus', 'BONUS'), Offset(_wheelC.dx, _wheelC.dy - _wheelR - 56), size: 28, color: Pal.yellow, stroke: Pal.ink);
    if (land) {
      D.title(c, M.big(_gems), const Offset(180, 560), size: 40 + 6 * M.wave(_t, 2), color: Pal.sky);
    }
  }
}

enum _Ph { calendar, zoom, box, wheel, result, trap }
