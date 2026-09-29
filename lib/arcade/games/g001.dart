import '../engine/engine.dart';

/// No.001 Pull the Pin! — particle puzzle: gold, lava and water held by pins.
///
/// Tap a pin to slide it out. Gold must reach the knight; lava must not.
/// Water touching lava turns it into harmless stone (with a steamy hiss).
class G001 extends MiniGame {
  static const _r = 6.0; // particle radius
  static const _gold = 0, _lava = 1, _water = 2, _stone = 3;
  static const _heroC = Offset(180, 562);
  static const _heroR = 24.0;

  final List<_P> _ps = [];
  final List<_Seg> _walls = [];
  final List<_Pin> _pins = [];
  int _goldTotal = 0;
  int _collected = 0;
  int _need = 0;
  bool _dead = false;
  bool _won = false;
  double _t = 0;
  double _cheer = 0;
  double _deadT = 0;
  double _sizzleCd = 0;
  double _coinCd = 0;
  int _hintPin = 0;
  bool _mirror = false;
  int _pulls = 0;
  double _fear = 0;

  // ------------------------------------------------------------ level ---
  Offset _m(double x, double y) => Offset(_mirror ? 360 - x : x, y);

  void _wall(double ax, double ay, double bx, double by, [double th = 5]) =>
      _walls.add(_Seg(_m(ax, ay), _m(bx, by), th));

  void _pin(double ax, double ay, double bx, double by, double dx, double dy) {
    final dir = Offset(_mirror ? -dx : dx, dy);
    var a = _m(ax, ay), b = _m(bx, by);
    if ((b - a).dx * dir.dx + (b - a).dy * dir.dy < 0) (a, b) = (b, a);
    _pins.add(_Pin(a, b, dir));
  }

  void _fill(int kind, Rect rr, int n) {
    final r = Rect.fromLTRB(_mirror ? 360 - rr.right : rr.left, rr.top, _mirror ? 360 - rr.left : rr.right, rr.bottom);
    const sp = _r * 2 + .6;
    var placed = 0;
    for (var y = r.bottom - _r - 1; y > r.top && placed < n; y -= sp) {
      for (var x = r.left + _r + 1; x < r.right - _r && placed < n; x += sp) {
        _ps.add(_P(x + rand(-.8, .8), y, kind));
        placed++;
      }
    }
    if (kind == _gold) _goldTotal += placed;
  }

  @override
  void init() {
    _mirror = chance(.5);
    // outer tower + funnel floor
    _wall(50, 96, 50, 540);
    _wall(310, 96, 310, 540);
    _wall(50, 540, 150, 594);
    _wall(150, 594, 210, 594);
    _wall(210, 594, 310, 540);
    final level = randInt(3);
    switch (level) {
      case 0: // choice: water over lava on one side, gold on the other
        _wall(180, 96, 180, 300);
        _pin(55, 200, 175, 200, -1, 0); // water floor
        _pin(55, 300, 175, 300, -1, 0); // lava floor
        _pin(185, 300, 305, 300, 1, 0); // gold floor
        _fill(_water, const Rect.fromLTRB(55, 110, 175, 196), 24);
        _fill(_lava, const Rect.fromLTRB(55, 205, 175, 296), 22);
        _fill(_gold, const Rect.fromLTRB(185, 150, 305, 296), 30);
        _hintPin = 2;
      case 1: // order: gold above lava, water column on the side
        _wall(245, 96, 245, 300);
        _pin(55, 220, 240, 220, -1, 0); // gold floor
        _pin(55, 384, 305, 384, -1, 0); // lava floor
        _pin(250, 300, 305, 300, 1, 0); // water floor
        _fill(_gold, const Rect.fromLTRB(55, 120, 240, 216), 30);
        _fill(_lava, const Rect.fromLTRB(55, 330, 305, 380), 26);
        _fill(_water, const Rect.fromLTRB(250, 150, 305, 296), 30);
        _hintPin = 2;
      default: // lava above gold, water column on the side
        _wall(245, 96, 245, 300);
        _pin(55, 220, 240, 220, -1, 0); // lava floor
        _pin(55, 384, 305, 384, -1, 0); // gold floor
        _pin(250, 300, 305, 300, 1, 0); // water floor
        _fill(_lava, const Rect.fromLTRB(55, 130, 240, 216), 28);
        _fill(_gold, const Rect.fromLTRB(55, 320, 305, 380), 30);
        _fill(_water, const Rect.fromLTRB(250, 150, 305, 296), 30);
        _hintPin = 1;
    }
    _need = (_goldTotal * .7).ceil();
    for (var i = 0; i < 90; i++) {
      _step(1 / 60, settle: true);
    }
    for (final p in _ps) {
      p.vx = 0;
      p.vy = 0;
    }
  }

  // ---------------------------------------------------------- physics ---
  void _collideSeg(_P p, Offset a, Offset b, double th) {
    final abx = b.dx - a.dx, aby = b.dy - a.dy;
    final len2 = abx * abx + aby * aby;
    var t = len2 == 0 ? 0.0 : ((p.x - a.dx) * abx + (p.y - a.dy) * aby) / len2;
    t = t.clamp(0.0, 1.0);
    final dx = p.x - (a.dx + abx * t), dy = p.y - (a.dy + aby * t);
    final minD = th + _r;
    final d2 = dx * dx + dy * dy;
    if (d2 >= minD * minD) return;
    var d = sqrt(d2);
    double nx, ny;
    if (d < 1e-5) {
      final l = sqrt(len2);
      nx = -aby / l;
      ny = abx / l;
      d = 0;
    } else {
      nx = dx / d;
      ny = dy / d;
    }
    p.x += nx * (minD - d);
    p.y += ny * (minD - d);
    final vn = p.vx * nx + p.vy * ny;
    if (vn < 0) {
      p.vx -= vn * nx * 1.1;
      p.vy -= vn * ny * 1.1;
      final fr = p.kind == _gold || p.kind == _stone ? .08 : .01;
      p.vx *= 1 - fr;
    }
  }

  void _step(double dt, {bool settle = false}) {
    const g = 900.0;
    for (final p in _ps) {
      p.vy += g * dt;
      if (p.kind == _lava || p.kind == _water) p.vx += (host.rng.nextDouble() - .5) * 60 * dt * 10;
      p.vx *= 1 - .6 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
    // particle pairs
    const d0 = _r * 2;
    for (var i = 0; i < _ps.length; i++) {
      final a = _ps[i];
      for (var j = i + 1; j < _ps.length; j++) {
        final b = _ps[j];
        final dx = b.x - a.x;
        if (dx > d0 || dx < -d0) continue;
        final dy = b.y - a.y;
        if (dy > d0 || dy < -d0) continue;
        final d2 = dx * dx + dy * dy;
        if (d2 >= d0 * d0) continue;
        final d = sqrt(d2) + 1e-6;
        final nx = dx / d, ny = dy / d;
        final push = (d0 - d) * .5;
        a.x -= nx * push;
        a.y -= ny * push;
        b.x += nx * push;
        b.y += ny * push;
        final rv = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
        if (rv < 0) {
          final imp = rv * .5;
          a.vx += imp * nx;
          a.vy += imp * ny;
          b.vx -= imp * nx;
          b.vy -= imp * ny;
        }
        if (!settle) _react(a, b);
      }
    }
    for (final p in _ps) {
      for (final w in _walls) {
        _collideSeg(p, w.a, w.b, w.th);
      }
      for (final pin in _pins) {
        if (!pin.out) _collideSeg(p, pin.a, pin.b, 4.5);
      }
      if (!settle && !_dead) {
        final dx = p.x - _heroC.dx, dy = p.y - _heroC.dy;
        final d = sqrt(dx * dx + dy * dy);
        if (d < _heroR + _r + 2 && p.kind != _gold) {
          if (p.kind == _lava) {
            _die();
          } else if (d > 1e-4) {
            final push = _heroR + _r + 2 - d;
            p.x += dx / d * push;
            p.y += dy / d * push;
          }
        }
      }
      p.x = p.x.clamp(20, 340);
    }
  }

  void _react(_P a, _P b) {
    if ((a.kind == _lava && b.kind == _water) || (a.kind == _water && b.kind == _lava)) {
      final lava = a.kind == _lava ? a : b;
      lava.kind = _stone;
      lava.flash = 1;
      host.fx.smoke(Offset(lava.x, lava.y - 4), count: 2, color: const Color(0xCCEFF6FF), size: 16);
      if (_sizzleCd <= 0) {
        host.sfx(Sfx.sizzle, volume: .6, rate: rand(.9, 1.2));
        _sizzleCd = .18;
      }
      host.addScore(5);
    }
  }

  void _die() {
    if (_dead || _won) return;
    _dead = true;
    host.sfx(Sfx.fire);
    host.sfx(Sfx.hurt, rate: .8);
    host.shake(10, .4);
    host.flash(Pal.orange, .25);
    host.hitStop(.12);
    host.fx.burst(_heroC, Pal.orange, count: 28, speed: 260, colors: const [Pal.orange, Pal.yellow, Pal.red]);
    host.fx.pop(host.tr('oops', 'OOPS!'), const Offset(180, 470), color: Pal.orange, size: 34);
    host.lose();
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _sizzleCd -= dt;
    _coinCd -= dt;
    _cheer = M.approach(_cheer, 0, 3, dt);
    for (final pin in _pins) {
      if (pin.out) pin.pulled = min(1, pin.pulled + dt * 3.2);
      pin.wiggle = M.approach(pin.wiggle, 0, 8, dt);
    }
    const sub = 3;
    for (var i = 0; i < sub; i++) {
      _step(dt / sub);
    }
    // collect gold / fear of lava
    var nearLava = 999.0;
    for (var i = _ps.length - 1; i >= 0; i--) {
      final p = _ps[i];
      p.flash = max(0, p.flash - dt * 3);
      final d = (Offset(p.x, p.y) - _heroC).distance;
      if (p.kind == _lava) nearLava = min(nearLava, d);
      if (p.kind == _gold && d < _heroR + _r + 6 && !_dead) {
        _ps.removeAt(i);
        _collected++;
        _cheer = 1;
        host.fx.sparkle(Offset(p.x, p.y), count: 2, radius: 8, color: Pal.yellow);
        if (_coinCd <= 0) {
          host.sfx(Sfx.coin, volume: .7, rate: 1 + min(_collected, 30) * .025);
          _coinCd = .06;
        }
        host.addScore(10);
        if (_collected == _need && !_won) _winNow();
      }
      if (p.y > 700) _ps.removeAt(i);
    }
    _fear = M.approach(_fear, nearLava < 150 ? 1 : 0, 6, dt);
    if (_dead) _deadT += dt;
  }

  void _winNow() {
    _won = true;
    host.sfx(Sfx.cash);
    host.sfx(Sfx.cheer, volume: .7);
    host.fx.coins(_heroC - const Offset(0, 30), count: 22);
    host.fx.pop(host.tr('win', 'WIN!'), const Offset(180, 450), color: Pal.yellow, size: 40);
    host.punch(.05);
    final t = host.time;
    host.win(stars: t < 7 ? 3 : (t < 11 ? 2 : 1));
  }

  @override
  void onTimeUp() {
    if (_collected >= _goldTotal * .4) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ------------------------------------------------------------- input ---
  Offset _handle(_Pin p) => p.b + p.dir * 24;

  @override
  void onDown(Offset p) {
    final pos = p;
    _Pin? best;
    var bd = 30.0;
    for (final pin in _pins) {
      if (pin.out) continue;
      final d = min(M.distToSegment(pos, pin.a, pin.b + pin.dir * 10), (pos - _handle(pin)).distance - 6);
      if (d < bd) {
        bd = d;
        best = pin;
      }
    }
    if (best == null) return;
    best.out = true;
    _pulls++;
    host.sfx(Sfx.swipe, rate: 1.2);
    host.sfx(Sfx.click, volume: .7);
    host.fx.sparkle(_handle(best), count: 6, radius: 14, color: Pal.yellow);
    host.shake(2);
    for (final q in _ps) {
      if ((Offset(q.x, q.y) - (best.a + best.b) / 2).distance < 120) q.vy -= 20;
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down || key != 'action') return;
    for (final p in _pins) {
      if (!p.out) {
        onDown(_handle(p));
        return;
      }
    }
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    _bg(c);
    // tower interior
    final inner = Rect.fromLTRB(50, 96, 310, 594);
    c.drawRect(
        inner,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2B3B66), Color(0xFF1C2446)],
          ).createShader(inner));
    final brick = D.stroke(const Color(0x22FFFFFF), 1.5);
    for (var row = 0; row < 21; row++) {
      final y = 96.0 + row * 24;
      c.drawLine(Offset(50, y), Offset(310, y), brick);
      for (var x = 50.0 + (row.isOdd ? 20 : 0); x < 310; x += 40) {
        c.drawLine(Offset(x, y), Offset(x, y + 24), brick);
      }
    }
    // lava glow behind particles
    final glow = Paint()..color = const Color(0x33FF7A1F);
    for (final p in _ps) {
      if (p.kind == _lava) c.drawCircle(Offset(p.x, p.y), 16, glow);
    }
    _drawParticles(c);
    _drawHero(c);
    // walls
    for (final w in _walls) {
      c.drawLine(w.a, w.b, D.stroke(Pal.ink, w.th * 2 + 5));
    }
    for (final w in _walls) {
      c.drawLine(w.a, w.b, D.stroke(const Color(0xFFB9B2CF), w.th * 2));
      c.drawLine(w.a - const Offset(1, 1.5), w.b - const Offset(1, 1.5), D.stroke(const Color(0xFFE6E1F5), 2));
    }
    // pins
    for (var i = 0; i < _pins.length; i++) {
      _drawPin(c, _pins[i], i);
    }
    // HUD: coins collected
    final pr = _collected / _need;
    D.rrect(c, const Rect.fromLTWH(92, 46, 176, 36), 18, const Color(0xCC1B1530), border: Pal.gold, borderWidth: 3);
    D.coin(c, const Offset(116, 64), 12, spin: _t * .8);
    D.bar(c, const Rect.fromLTWH(134, 57, 90, 14), pr, Pal.gold);
    D.text(c, '${min(_collected, _need)}/$_need', const Offset(246, 64), size: 15, color: Pal.white, stroke: Pal.ink);
    // hint
    if (_pulls == 0 && host.time < 3 && _hintPin < _pins.length) {
      final h = _handle(_pins[_hintPin]);
      final pulse = M.wave(_t, 2);
      c.drawCircle(h, 18 + pulse * 8, D.stroke(const Color(0xAAFFFFFF), 3));
      D.hand(c, h + const Offset(4, 6), _t);
      D.text(c, host.tr('tap', 'TAP!'), h + Offset(_pins[_hintPin].dir.dx * -10, -34), size: 20, stroke: Pal.ink);
    }
  }

  void _bg(Canvas c) {
    D.gradientBg(c, const [Color(0xFF3A2463), Color(0xFF1A1033)]);
    final b = Paint()..color = const Color(0x18FFFFFF);
    for (var row = 0; row < 28; row++) {
      final y = 36.0 + row * 22;
      for (var x = (row.isOdd ? -18.0 : 0.0); x < 360; x += 36) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, y + 2, 32, 18), const Radius.circular(3)), b);
      }
    }
    // torches
    for (final x in const [24.0, 336.0]) {
      final base = Offset(x, 300);
      c.drawCircle(base - const Offset(0, 14), 34 + sin(_t * 9 + x) * 3, Paint()..color = const Color(0x33FFB02E));
      D.rrect(c, Rect.fromCenter(center: base + const Offset(0, 14), width: 10, height: 30), 3, const Color(0xFF6B4226),
          border: Pal.ink, borderWidth: 2);
      D.flame(c, base, 26, _t + x);
    }
    // treasure room floor
    D.rrect(c, const Rect.fromLTWH(-10, 598, 380, 60), 0, const Color(0xFF2A1B45));
  }

  void _drawParticles(Canvas c) {
    final lavaD = Paint()..color = const Color(0xFFD9381E);
    final lavaL = Paint()..color = const Color(0xFFFF8A1F);
    final lavaH = Paint()..color = const Color(0xFFFFD23F);
    final waterD = Paint()..color = const Color(0xFF1F6FE0);
    final waterL = Paint()..color = const Color(0xFF4FB4FF);
    final waterH = Paint()..color = const Color(0xCCDFF4FF);
    final stone = Paint()..color = const Color(0xFF7A7488);
    final stoneL = Paint()..color = const Color(0xFFA7A1B6);
    // liquids as merged blobs: dark rim pass, then body, then highlight
    for (final p in _ps) {
      final o = Offset(p.x, p.y);
      if (p.kind == _lava) c.drawCircle(o, _r * 1.6, lavaD);
      if (p.kind == _water) c.drawCircle(o, _r * 1.6, waterD);
    }
    for (final p in _ps) {
      final o = Offset(p.x, p.y);
      if (p.kind == _lava) c.drawCircle(o, _r * 1.3, lavaL);
      if (p.kind == _water) c.drawCircle(o, _r * 1.3, waterL);
    }
    for (final p in _ps) {
      final o = Offset(p.x, p.y);
      if (p.kind == _lava) {
        c.drawCircle(o + Offset(sin(_t * 5 + p.x) * 1.5, -1), _r * .55, lavaH);
      } else if (p.kind == _water) {
        c.drawCircle(o + const Offset(-2, -3), _r * .4, waterH);
      } else if (p.kind == _stone) {
        c.drawCircle(o, _r + 1, D.fill(Pal.ink));
        c.drawCircle(o, _r, stone);
        c.drawCircle(o + const Offset(-1.5, -1.5), _r * .5, stoneL);
        if (p.flash > 0) c.drawCircle(o, _r + 1, Paint()..color = Color.fromRGBO(255, 255, 255, p.flash * .8));
      }
    }
    for (final p in _ps) {
      if (p.kind == _gold) D.coin(c, Offset(p.x, p.y), _r + .8, spin: (p.x * .02 + _t * .3) % 1 * .3);
    }
  }

  void _drawPin(Canvas c, _Pin p, int i) {
    final len = (p.b - p.a).distance;
    final off = p.dir * (M.easeInOut(p.pulled) * (len + 80));
    if (p.pulled >= 1) return;
    final a = p.a - p.dir * 4 + off;
    final b = p.b + p.dir * 12 + off;
    final h = _handle(p) + off;
    c.drawLine(a, b, D.stroke(Pal.ink, 13));
    c.drawLine(a, b, D.stroke(const Color(0xFFE0A019), 8));
    c.drawLine(a + const Offset(0, -1.5), b + const Offset(0, -1.5), D.stroke(const Color(0xFFFFE98A), 3));
    // ring handle
    c.drawCircle(h, 14, D.stroke(Pal.ink, 11));
    c.drawCircle(h, 14, D.stroke(const Color(0xFFE0A019), 7));
    c.drawArc(Rect.fromCircle(center: h, radius: 14), pi * 1.1, pi * .6, false, D.stroke(const Color(0xFFFFF1A8), 2.5));
    // shine sweep
    final s = ((_t * .7 + i * .33) % 1.6);
    if (s < 1 && !p.out) {
      final q = Offset.lerp(a, b, s)!;
      c.drawCircle(q, 4, Paint()..color = const Color(0xAAFFFFFF));
    }
  }

  void _drawHero(Canvas c) {
    final feet = const Offset(180, 590);
    // coin pile grows with collected gold
    final pile = min(_collected, 40);
    for (var i = 0; i < pile; i++) {
      final row = i ~/ 10;
      final side = i.isEven ? 1 : -1;
      final x = 180 + side * (30 + ((i ~/ 2) % 5) * 7.0 - row * 3);
      D.coin(c, Offset(x, 588 - row * 6.0), 6);
    }
    if (_dead) {
      _drawSkeleton(c, feet);
      return;
    }
    final jump = _cheer > .05 ? -sin(_t * 18).abs() * 8 * _cheer : 0.0;
    final shiver = _fear * sin(_t * 50) * 1.5;
    c.save();
    c.translate(feet.dx + shiver, feet.dy + jump);
    D.shadow(c, Offset(0, -jump + 2), 44, 10);
    // legs
    D.rrect(c, const Rect.fromLTWH(-12, -16, 9, 16), 3, const Color(0xFF8E97B8), border: Pal.ink, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(3, -16, 9, 16), 3, const Color(0xFF8E97B8), border: Pal.ink, borderWidth: 2);
    // cape
    c.drawPath(
        Path()
          ..moveTo(-14, -40)
          ..lineTo(-22, -10)
          ..lineTo(22, -10)
          ..lineTo(14, -40)
          ..close(),
        D.fill(const Color(0xFFD7263D)));
    // body armor
    D.rrect(c, const Rect.fromLTWH(-16, -42, 32, 28), 8, const Color(0xFFC9D2EA), border: Pal.ink, borderWidth: 2.5);
    c.drawLine(const Offset(0, -40), const Offset(0, -16), D.stroke(const Color(0xFF8E97B8), 2));
    // sword arm up when cheering
    final up = _won || _cheer > .3;
    c.save();
    c.translate(16, -34);
    c.rotate(up ? -2.4 : -.3);
    D.rrect(c, const Rect.fromLTWH(-3, 0, 6, 12), 3, Pal.skin, border: Pal.ink, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(-2.5, 12, 5, 26), 2, const Color(0xFFE8EEFF), border: Pal.ink, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(-8, 10, 16, 4), 2, Pal.gold, border: Pal.ink, borderWidth: 1.5);
    c.restore();
    // head
    const head = Offset(0, -56);
    c.drawCircle(head, 17, D.fill(Pal.skin));
    c.drawCircle(head, 17, D.stroke(Pal.ink, 2.5));
    final face = _won || _cheer > .3 ? Face.happy : (_fear > .5 ? Face.shocked : Face.neutral);
    D.face(c, head + const Offset(0, 3), 13, face, look: Offset(0, -.6));
    // helmet
    c.drawArc(Rect.fromCircle(center: head + const Offset(0, -2), radius: 18), pi * 1.02, pi * .96, true,
        D.fill(const Color(0xFFC9D2EA)));
    c.drawArc(Rect.fromCircle(center: head + const Offset(0, -2), radius: 18), pi * 1.02, pi * .96, true,
        D.stroke(Pal.ink, 2.5));
    // plume
    c.drawPath(
        Path()
          ..moveTo(-2, -74)
          ..quadraticBezierTo(8, -92 + sin(_t * 6) * 2, 20, -84)
          ..quadraticBezierTo(10, -80, 4, -73)
          ..close(),
        D.fill(const Color(0xFFD7263D)));
    if (_fear > .5 && !_won) {
      final sd = Offset(22, -66 + (_t * 40) % 12);
      c.drawCircle(sd, 3.5, D.fill(const Color(0xFF7FD3FF)));
    }
    c.restore();
  }

  void _drawSkeleton(Canvas c, Offset feet) {
    final k = M.clamp01(_deadT * 3);
    c.save();
    c.translate(feet.dx, feet.dy);
    // charred smoke
    if ((_t * 20).floor().isEven && _deadT < 1.2) host.fx.smoke(const Offset(180, 530), count: 1, color: const Color(0x88444444));
    final bone = Color.lerp(const Color(0xFFC9D2EA), const Color(0xFFF5F0E6), k)!;
    D.rrect(c, const Rect.fromLTWH(-11, -16, 5, 16), 2, bone, border: Pal.ink, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(6, -16, 5, 16), 2, bone, border: Pal.ink, borderWidth: 2);
    for (var i = 0; i < 4; i++) {
      c.drawLine(Offset(-12, -38 + i * 6.0), Offset(12, -38 + i * 6.0), D.stroke(Pal.ink, 5));
      c.drawLine(Offset(-11, -38 + i * 6.0), Offset(11, -38 + i * 6.0), D.stroke(bone, 3));
    }
    c.drawLine(const Offset(0, -42), const Offset(0, -16), D.stroke(bone, 3));
    const head = Offset(0, -58);
    c.drawCircle(head, 16, D.fill(bone));
    c.drawCircle(head, 16, D.stroke(Pal.ink, 2.5));
    c.drawCircle(head + const Offset(-6, -2), 5, D.fill(Pal.ink));
    c.drawCircle(head + const Offset(6, -2), 5, D.fill(Pal.ink));
    c.drawPath(
        Path()
          ..moveTo(0, -56)
          ..lineTo(-2.5, -51)
          ..lineTo(2.5, -51)
          ..close(),
        D.fill(Pal.ink));
    for (var i = -2; i <= 2; i++) {
      c.drawLine(Offset(i * 3.0, -47), Offset(i * 3.0, -44), D.stroke(Pal.ink, 1.5));
    }
    c.restore();
    D.flame(c, feet + const Offset(-20, 2), 26 * (1 - k * .5), _t);
    D.flame(c, feet + const Offset(22, 2), 20 * (1 - k * .5), _t + 1);
  }
}

class _P {
  _P(this.x, this.y, this.kind);
  double x, y;
  double vx = 0, vy = 0;
  int kind;
  double flash = 0;
}

class _Seg {
  _Seg(this.a, this.b, this.th);
  final Offset a, b;
  final double th;
}

class _Pin {
  _Pin(this.a, this.b, this.dir);
  final Offset a, b;
  final Offset dir; // pull direction (toward the handle)
  bool out = false;
  double pulled = 0;
  double wiggle = 0;
}
