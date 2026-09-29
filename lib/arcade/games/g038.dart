import '../engine/engine.dart';

/// No.038 Sushi Conveyor — kaiten-zushi loop. Customers around the belt show
/// the sushi they want. Tap a plate on the belt: it flies to a customer who
/// ordered it. Nobody wants it? Someone gets it anyway and is NOT amused.
/// Serve 6 to win; 3 angry customers = fail. Gold uni plates pay extra.
class G038 extends MiniGame {
  static const _goal = 6;
  static const _l = 34.0, _r = 326.0, _tp = 262.0, _bt = 418.0, _cr = 50.0;
  static const _seats = [
    Offset(70, 176),
    Offset(180, 176),
    Offset(290, 176),
    Offset(70, 516),
    Offset(180, 516),
    Offset(290, 516),
  ];
  static const _plateCols = [Color(0xFFFF8FB0), Color(0xFF6FB7FF), Color(0xFFFFE27A), Color(0xFF9BE27A), Pal.gold, Color(0xFFD9D0FF)];

  late final double _len;
  final List<_Plate> _plates = [];
  final List<_Seat> _seatState = List.generate(6, (_) => _Seat());
  final List<_Flying> _flying = [];
  double _beltS = 0;
  double _spawnT = .1;
  double _t = 0;
  int _served = 0;
  int _angry = 0;
  int _combo = 0;
  double _money = 0;
  double _shown = 0;
  double _bump = 0;
  double _chefToss = 0;
  int _orders = 0;

  @override
  void init() {
    const sw = _r - _l - 2 * _cr, sh = _bt - _tp - 2 * _cr;
    _len = 2 * sw + 2 * sh + 2 * pi * _cr;
    final first = [0, 2, 4, 5, 1, 3]..shuffle(rng);
    for (var i = 0; i < 6; i++) {
      final s = _seatState[i];
      s.delay = i < 4 ? i * .25 : 2.5 + i * .6;
      s.color = pick(const [Pal.sky, Pal.pink, Pal.lime, Pal.purple, Pal.orange, Pal.teal, Color(0xFFFFB3D9)]);
      s.want = first[i] == 5 && chance(.5) ? 4 : first[i] % 6;
    }
    // pre-fill the belt
    for (var k = 0; k < 9; k++) {
      _plates.add(_Plate(_randomKind(), k * _len / 9));
    }
  }

  int _randomKind() {
    final wanted = <int>[];
    for (final s in _seatState) {
      if (s.state == 1 || s.delay < 3) wanted.add(s.want);
    }
    if (wanted.isNotEmpty && chance(.55)) return pick(wanted);
    return chance(.08) ? 4 : pick(const [0, 1, 2, 3, 5]);
  }

  Offset _posAt(double s) {
    const sw = _r - _l - 2 * _cr, sh = _bt - _tp - 2 * _cr;
    s %= _len;
    // start at top-left straight, clockwise
    if (s < sw) return Offset(_l + _cr + s, _tp);
    s -= sw;
    if (s < pi * _cr / 2) {
      final a = -pi / 2 + s / _cr;
      return Offset(_r - _cr + cos(a) * _cr, _tp + _cr + sin(a) * _cr);
    }
    s -= pi * _cr / 2;
    if (s < sh) return Offset(_r, _tp + _cr + s);
    s -= sh;
    if (s < pi * _cr / 2) {
      final a = s / _cr;
      return Offset(_r - _cr + cos(a) * _cr, _bt - _cr + sin(a) * _cr);
    }
    s -= pi * _cr / 2;
    if (s < sw) return Offset(_r - _cr - s, _bt);
    s -= sw;
    if (s < pi * _cr / 2) {
      final a = pi / 2 + s / _cr;
      return Offset(_l + _cr + cos(a) * _cr, _bt - _cr + sin(a) * _cr);
    }
    s -= pi * _cr / 2;
    if (s < sh) return Offset(_l, _bt - _cr - s);
    s -= sh;
    final a = pi + s / _cr;
    return Offset(_l + _cr + cos(a) * _cr, _tp + _cr + sin(a) * _cr);
  }

  @override
  void update(double dt) {
    _t += dt;
    _bump = M.approach(_bump, 0, 8, dt);
    _shown = M.approach(_shown, _money, 7, dt);
    _chefToss = M.approach(_chefToss, 0, 5, dt);
    final v = 78 * host.speed;
    _beltS += v * dt;
    for (final p in _plates) {
      p.s += v * dt;
      p.pop = min(1, p.pop + dt * 4);
    }
    // chef drops a new plate at the bottom-left corner when there's room
    _spawnT -= dt;
    if (_spawnT <= 0 && _plates.length < 12 && !host.finished) {
      final dropS = _len * .78; // left side
      final free = _plates.every((p) {
        final d = ((p.s - dropS) % _len + _len) % _len;
        return d > 48 && d < _len - 48;
      });
      if (free) {
        _plates.add(_Plate(_randomKind(), dropS)..pop = 0);
        _chefToss = 1;
        host.sfx(Sfx.pop, volume: .4, rate: 1.3);
        _spawnT = .55 / host.speed;
      } else {
        _spawnT = .1;
      }
    }
    for (var i = 0; i < 6; i++) {
      final s = _seatState[i];
      s.bounce = M.approach(s.bounce, 0, 7, dt);
      s.stateT += dt;
      switch (s.state) {
        case 0: // empty, waiting to arrive
          if (host.finished) break;
          s.delay -= dt;
          if (s.delay <= 0) {
            s.state = 1;
            s.stateT = 0;
            _orders++;
            s.patience = s.maxPatience = (12.0 - min(_orders, 8) * .25) / host.speed;
            s.bounce = 1;
          }
        case 1: // waiting for sushi
          if (!host.finished) s.patience -= dt;
          if (s.patience <= 0) _makeAngry(i, walkout: true);
        case 2: // eating
          if (s.stateT > .9) _leave(i);
        case 3: // leaving (angry or satisfied)
          if (s.stateT > .5) {
            s.state = 0;
            s.mad = false;
            s.delay = rand(.3, .9);
            s.color = pick(const [Pal.sky, Pal.pink, Pal.lime, Pal.purple, Pal.orange, Pal.teal, Color(0xFFFFB3D9)]);
            s.want = chance(.12) ? 4 : pick(const [0, 1, 2, 3, 5]);
          }
      }
    }
    for (final f in _flying) {
      f.t += dt * 3;
      if (f.t >= 1 && !f.done) {
        f.done = true;
        _deliver(f);
      }
    }
    _flying.removeWhere((f) => f.done);
  }

  void _leave(int i) {
    final s = _seatState[i];
    s.state = 3;
    s.stateT = 0;
  }

  void _makeAngry(int i, {bool walkout = false}) {
    final s = _seatState[i];
    _angry++;
    _combo = 0;
    s.mad = true;
    s.state = 3;
    s.stateT = 0;
    host.sfx(walkout ? Sfx.buzzer : Sfx.wrong, volume: .7);
    host.shake(7);
    host.fx.smoke(_seats[i] + const Offset(0, -30), count: 8, color: const Color(0xCCFF6060));
    host.fx.pop(host.tr('angry', 'ANGRY!'), _seats[i] + const Offset(0, -56), color: Pal.red, size: 24);
    if (_angry >= 3 && !host.finished) {
      host.sfx(Sfx.jingleLose, volume: .6);
      host.lose();
    }
  }

  void _deliver(_Flying f) {
    final s = _seatState[f.seat];
    final at = _seats[f.seat];
    if (s.state != 1) return;
    if (s.want == f.kind) {
      _served++;
      _combo++;
      s.state = 2;
      s.stateT = 0;
      s.bounce = 1;
      final gold = f.kind == 4;
      final ratio = (s.patience / s.maxPatience).clamp(0.0, 1.0);
      final pay = (gold ? 500 : 120) + (ratio * 60).round() + _combo * 20;
      _money += pay;
      _bump = 1;
      host.addScore(pay);
      host.sfx(Sfx.chomp);
      host.sfx(gold ? Sfx.ssr : Sfx.cash, volume: .7, rate: 1 + min(_combo, 8) * .05);
      host.punch(.03);
      host.fx.coins(at, count: gold ? 22 : 10);
      host.fx.burst(at, _plateCols[f.kind], count: 14, speed: 240, shape: PartShape.star, colors: const [Pal.yellow, Pal.white]);
      host.fx.pop('+$pay', at + const Offset(0, -50), color: Pal.gold, size: gold ? 32 : 24);
      if (gold) host.fx.pop(host.tr('jackpot', 'JACKPOT!'), at + const Offset(0, -86), color: Pal.yellow, size: 28, life: 1);
      if (_combo >= 2) {
        host.fx.pop('${host.tr('combo', 'COMBO')} x$_combo', at + Offset(0, f.seat < 3 ? 60 : -86), color: Pal.pink, size: 20);
      }
      if (_served >= _goal && !host.finished) {
        host.fx.confetti();
        host.sfx(Sfx.fanfare);
        host.win(stars: _angry == 0 && host.time < 15 ? 3 : (_angry <= 1 ? 2 : 1));
      }
    } else {
      host.fx.burst(at, _plateCols[f.kind], count: 12, speed: 260, gravity: 700);
      host.fx.pop(host.tr('wrong', 'WRONG!'), at + const Offset(0, -80), color: Pal.red, size: 24);
      _makeAngry(f.seat);
    }
  }

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    _Plate? best;
    var bd = 36.0;
    for (final pl in _plates) {
      final d = (_posAt(pl.s) - p).distance;
      if (d < bd) {
        bd = d;
        best = pl;
      }
    }
    if (best == null) return;
    // who wants it? (lowest patience first)
    var seat = -1;
    for (var i = 0; i < 6; i++) {
      final s = _seatState[i];
      if (s.state == 1 && s.want == best.kind && !_flying.any((f) => f.seat == i)) {
        if (seat < 0 || s.patience < _seatState[seat].patience) seat = i;
      }
    }
    final from = _posAt(best.s);
    if (seat < 0) {
      // nobody ordered it: nearest waiting customer gets it anyway...
      var nd = 1e9;
      for (var i = 0; i < 6; i++) {
        final s = _seatState[i];
        if (s.state != 1 || _flying.any((f) => f.seat == i)) continue;
        final d = (_seats[i] - from).distance;
        if (d < nd) {
          nd = d;
          seat = i;
        }
      }
      if (seat < 0) {
        host.sfx(Sfx.boing, volume: .5);
        return;
      }
    }
    _plates.remove(best);
    _flying.add(_Flying(best.kind, from, seat));
    host.sfx(Sfx.whoosh, rate: 1.3);
    host.fx.sparkle(from, count: 4, radius: 16);
  }

  // ----------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    _drawBg(c);
    for (var i = 0; i < 3; i++) {
      _drawCustomer(c, i);
    }
    _drawBelt(c);
    _drawChef(c);
    for (final pl in _plates) {
      final p = _posAt(pl.s);
      final wanted = _seatState.any((s) => s.state == 1 && s.want == pl.kind);
      _drawPlate(c, p, pl.kind, M.easeOutBack(pl.pop), glow: wanted);
    }
    for (var i = 3; i < 6; i++) {
      _drawCustomer(c, i);
    }
    for (var i = 0; i < 6; i++) {
      _drawOrder(c, i);
    }
    for (final f in _flying) {
      final to = _seats[f.seat] + Offset(0, f.seat < 3 ? 36 : -30);
      final t = M.easeInOut(f.t.clamp(0.0, 1.0));
      final p = Offset.lerp(f.from, to, t)! + Offset(0, -sin(t * pi) * 50);
      _drawPlate(c, p, f.kind, 1 + sin(t * pi) * .3);
    }
    _drawHud(c);
    if (host.time < 3 && _served == 0 && !host.finished) {
      // point at a wanted plate
      for (final pl in _plates) {
        if (_seatState.any((s) => s.state == 1 && s.want == pl.kind)) {
          final p = _posAt(pl.s);
          if (p.dx > 40 && p.dx < 320) {
            D.hand(c, p + const Offset(4, 8), _t);
            break;
          }
        }
      }
    }
  }

  void _drawBg(Canvas c) {
    D.gradientBg(c, const [Color(0xFFF7E3C0), Color(0xFFE8C898)]);
    // noren-ish top stripe with wave pattern
    c.drawRect(const Rect.fromLTWH(0, 36, 360, 40), D.fill(const Color(0xFF1F3B6E)));
    for (var x = -20.0; x < 380; x += 30) {
      c.drawArc(Rect.fromCircle(center: Offset(x + (_t * 6) % 30, 76), radius: 14), pi, pi, false, D.stroke(const Color(0xFF6FA8FF), 2.5));
      c.drawArc(Rect.fromCircle(center: Offset(x + (_t * 6) % 30, 76), radius: 8), pi, pi, false, D.stroke(const Color(0xFF6FA8FF), 2));
    }
    // wooden counters
    D.rrect(c, const Rect.fromLTWH(-10, 206, 380, 24), 4, const Color(0xFFD9A066),
        gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE8B77C), Color(0xFFB9783F)]));
    D.rrect(c, const Rect.fromLTWH(-10, 452, 380, 24), 4, const Color(0xFFD9A066),
        gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE8B77C), Color(0xFFB9783F)]));
    // tea cups
    for (final p in const [Offset(125, 214), Offset(235, 214), Offset(125, 460), Offset(235, 460)]) {
      D.rrect(c, Rect.fromCenter(center: p, width: 14, height: 14), 3, const Color(0xFF6E8B5A), border: Pal.ink, borderWidth: 1.5);
    }
    // floor tiles
    c.drawRect(const Rect.fromLTWH(0, 476, 360, 164), D.fill(const Color(0xFFCFA676)));
    for (var x = 0.0; x < 360; x += 40) {
      c.drawLine(Offset(x, 476), Offset(x, 640), D.stroke(const Color(0x22000000), 2));
    }
  }

  void _drawBelt(Canvas c) {
    final outer = RRect.fromRectAndRadius(Rect.fromLTRB(_l - 28, _tp - 28, _r + 28, _bt + 28), const Radius.circular(_cr + 28));
    final inner = RRect.fromRectAndRadius(Rect.fromLTRB(_l + 28, _tp + 28, _r - 28, _bt - 28), Radius.circular(max(1, _cr - 28)));
    c.drawRRect(outer.shift(const Offset(0, 6)), D.fill(const Color(0x44000000)));
    c.drawDRRect(outer, inner, D.fill(const Color(0xFFB8C2CC)));
    // moving slats
    final slat = D.stroke(const Color(0xFF8E99A6), 2);
    for (var s = _beltS % 20; s < _len; s += 20) {
      final p = _posAt(s);
      final q = _posAt(s + 1);
      final d = q - p;
      final n = Offset(-d.dy, d.dx) / max(d.distance, 1e-3);
      c.drawLine(p + n * 26, p - n * 26, slat);
    }
    c.drawRRect(outer, D.stroke(Pal.ink, 3));
    c.drawRRect(inner, D.stroke(Pal.ink, 3));
    // inner island (chef area)
    c.drawRRect(inner.deflate(2), D.fill(const Color(0xFF8A5A33)));
    c.drawRRect(inner.deflate(8), D.fill(const Color(0xFFA36B3D)));
  }

  void _drawChef(Canvas c) {
    const feet = Offset(180, 372);
    D.person(c, feet, 88, Pal.white, face: _chefToss > .3 ? Face.smug : Face.happy, hair: Pal.ink, armsUp: _chefToss * .8);
    // hachimaki
    c.drawRect(Rect.fromCenter(center: feet + const Offset(0, -80), width: 34, height: 6), D.fill(Pal.red));
    // cutting board & fish
    D.rrect(c, const Rect.fromLTWH(118, 346, 42, 22), 4, const Color(0xFFF4E3C8), border: Pal.ink, borderWidth: 2);
    c.drawOval(const Rect.fromLTWH(122, 350, 32, 12), D.fill(const Color(0xFFFF9D6B)));
    D.rrect(c, const Rect.fromLTWH(202, 346, 40, 22), 4, const Color(0xFF3A3E49), border: Pal.ink, borderWidth: 2);
    for (var k = 0; k < 3; k++) {
      c.drawCircle(Offset(210 + k * 12.0, 357), 5, D.fill(Pal.white));
    }
  }

  void _drawCustomer(Canvas c, int i) {
    final s = _seatState[i];
    if (s.state == 0) return;
    final top = i < 3;
    final base = _seats[i];
    double off = 0;
    if (s.state == 1 && s.stateT < .4) off = (1 - M.easeOutBack(s.stateT / .4)) * 60;
    if (s.state == 3) off = M.easeInOut(min(1, s.stateT / .5)) * 70;
    final pos = base + Offset(0, top ? -off : off) + Offset(0, -s.bounce * 10);
    final ratio = (s.patience / max(s.maxPatience, .01)).clamp(0.0, 1.0);
    Face f;
    if (s.mad) {
      f = Face.angry;
    } else if (s.state == 2) {
      f = Face.love;
    } else if (s.state == 3) {
      f = Face.happy;
    } else if (ratio > .55) {
      f = Face.happy;
    } else if (ratio > .28) {
      f = Face.neutral;
    } else {
      f = Face.angry;
    }
    final shake = s.state == 1 && ratio < .28 ? sin(_t * 40) * 2 : 0.0;
    D.blob(c, pos + Offset(shake, 0), 30, s.color, face: f, squash: 1 + s.bounce * .15);
    if (s.state == 2) {
      // chopsticks nom
      final k = sin(s.stateT * 20).abs();
      c.drawLine(pos + Offset(18, 14 - k * 6), pos + Offset(40, -10 - k * 6), D.stroke(const Color(0xFFD9B27C), 3));
    }
  }

  void _drawOrder(Canvas c, int i) {
    final s = _seatState[i];
    if (s.state != 1) return;
    final top = i < 3;
    final base = _seats[i];
    final pop = M.easeOutBack(min(1, s.stateT * 3));
    final center = base + Offset(0, top ? -64 : 72);
    final ratio = (s.patience / max(s.maxPatience, .01)).clamp(0.0, 1.0);
    c.save();
    c.translate(center.dx, center.dy);
    c.scale(pop);
    if (ratio < .28) c.rotate(sin(_t * 30) * .06);
    final r = Rect.fromCenter(center: Offset.zero, width: 70, height: 50);
    D.bubble(c, r, tail: top ? const Offset(0, 40) : null);
    _drawPlate(c, const Offset(0, -2), s.want, .9);
    final col = ratio > .55 ? Pal.green : (ratio > .28 ? Pal.yellow : Pal.red);
    D.bar(c, const Rect.fromLTWH(-28, 17, 56, 6), ratio, col);
    c.restore();
  }

  void _drawPlate(Canvas c, Offset p, int kind, double s, {bool glow = false}) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(s);
    if (glow) c.drawCircle(Offset.zero, 26 + M.wave(_t, 3) * 3, D.fill(const Color(0x55FFFFFF)));
    if (kind == 4) c.drawCircle(Offset.zero, 30, D.fill(Pal.gold.withValues(alpha: .25 + .2 * M.wave(_t, 4))));
    c.drawOval(const Rect.fromLTWH(-22, -10, 44, 26), D.fill(const Color(0x33000000)));
    c.drawOval(const Rect.fromLTWH(-22, -14, 44, 26), D.fill(_plateCols[kind]));
    c.drawOval(const Rect.fromLTWH(-16, -10, 32, 18), D.fill(Color.lerp(_plateCols[kind], Pal.white, .5)!));
    c.drawOval(const Rect.fromLTWH(-22, -14, 44, 26), D.stroke(Pal.ink, 2));
    _drawSushi(c, kind);
    c.restore();
  }

  void _drawSushi(Canvas c, int kind) {
    if (kind == 5) {
      // cucumber maki pair
      for (final x in [-8.0, 8.0]) {
        c.drawCircle(Offset(x, -6), 8, D.fill(const Color(0xFF1E3B24)));
        c.drawCircle(Offset(x, -6), 5.5, D.fill(Pal.white));
        c.drawCircle(Offset(x, -6), 2.5, D.fill(Pal.lime));
        c.drawCircle(Offset(x, -6), 8, D.stroke(Pal.ink, 1.5));
      }
      return;
    }
    if (kind == 4) {
      // uni gunkan
      D.rrect(c, const Rect.fromLTWH(-12, -12, 24, 14), 5, const Color(0xFF1E3B24), border: Pal.ink, borderWidth: 1.5);
      for (var k = 0; k < 4; k++) {
        c.drawOval(Rect.fromLTWH(-11 + k * 5.5, -18, 8, 9), D.fill(const Color(0xFFFFB02E)));
      }
      D.star(c, const Offset(12, -18), 4, Pal.white);
      return;
    }
    // nigiri: rice + topping
    D.rrect(c, const Rect.fromLTWH(-13, -10, 26, 11), 5, Pal.white, border: Pal.ink, borderWidth: 1.5);
    final topCol = switch (kind) {
      0 => const Color(0xFFFF8A4C),
      1 => const Color(0xFFD9283C),
      2 => const Color(0xFFFFD84A),
      _ => const Color(0xFFFF9E8A),
    };
    final top = Path()
      ..moveTo(-16, -8)
      ..quadraticBezierTo(0, -22, 16, -8)
      ..quadraticBezierTo(0, -12, -16, -8)
      ..close();
    c.drawPath(top, D.fill(topCol));
    if (kind == 0) {
      for (var k = 0; k < 3; k++) {
        c.drawLine(Offset(-8 + k * 7.0, -15), Offset(-5 + k * 7.0, -9), D.stroke(const Color(0xCCFFFFFF), 1.6));
      }
    }
    if (kind == 2) c.drawRect(const Rect.fromLTWH(-3, -17, 6, 17), D.fill(const Color(0xFF1E3B24)));
    if (kind == 3) {
      for (var k = 0; k < 3; k++) {
        c.drawLine(Offset(-9 + k * 7.0, -14), Offset(-6 + k * 7.0, -9), D.stroke(const Color(0xFFE85A3A), 1.8));
      }
      c.drawPath(
          Path()
            ..moveTo(14, -10)
            ..lineTo(22, -18)
            ..lineTo(22, -6)
            ..close(),
          D.fill(const Color(0xFFE8322C)));
    }
    c.drawPath(top, D.stroke(Pal.ink, 1.5));
  }

  void _drawHud(Canvas c) {
    D.rrect(c, const Rect.fromLTWH(8, 44, 110, 30), 15, const Color(0xDD1B1530), border: Pal.white, borderWidth: 2);
    D.text(c, '$_served/$_goal', const Offset(80, 59), size: 18, color: Pal.white, stroke: Pal.ink);
    _drawPlate(c, const Offset(30, 62), 0, .6);
    final s = 1 + _bump * .12;
    c.save();
    c.translate(296, 59);
    c.scale(s);
    D.rrect(c, const Rect.fromLTWH(-56, -15, 112, 30), 15, const Color(0xDD1B1530), border: Pal.gold, borderWidth: 2);
    D.coin(c, const Offset(-40, 0), 10, spin: _t * .4);
    D.text(c, M.big(_shown), const Offset(10, 0), size: 18, color: Pal.gold, stroke: Pal.ink);
    c.restore();
    for (var i = 0; i < 3; i++) {
      D.heart(c, Offset(156 + i * 24.0, 59), 18, i < 3 - _angry ? Pal.red : const Color(0x55000000), border: Pal.ink);
    }
  }
}

class _Plate {
  _Plate(this.kind, this.s);
  final int kind;
  double s;
  double pop = 1;
}

class _Seat {
  int state = 0; // 0 empty, 1 waiting, 2 eating, 3 leaving
  double stateT = 0;
  double delay = 0;
  double patience = 1;
  double maxPatience = 1;
  int want = 0;
  bool mad = false;
  double bounce = 0;
  Color color = Pal.sky;
}

class _Flying {
  _Flying(this.kind, this.from, this.seat);
  final int kind;
  final Offset from;
  final int seat;
  double t = 0;
  bool done = false;
}
