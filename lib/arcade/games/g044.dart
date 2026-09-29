import '../engine/engine.dart';

/// No.044 Laundry Panic — clothes tumble out of the basket onto the table.
/// Drag (or flick) each one into the right machine: WHITE / COLOR / DARK.
/// Put a red sock in the whites and the whole machine foams PINK.
class G044 extends MiniGame {
  static const _goal = 12;
  static const _whites = [Color(0xFFFFFFFF), Color(0xFFFFF4DC), Color(0xFFF0F4FF)];
  static const _colors = [Color(0xFFFF3B5C), Color(0xFFFFD23F), Color(0xFF9BE22D), Color(0xFF3FB8FF), Color(0xFFFF5FC8), Color(0xFFFF8A1F)];
  static const _darks = [Color(0xFF22305A), Color(0xFF26242E), Color(0xFF4A3020), Color(0xFF3A2258)];
  static const _machCol = [Color(0xFFE8F0FF), Color(0xFFFF8A1F), Color(0xFF34406B)];

  final _items = <_Cloth>[];
  final _mach = List.generate(3, (i) => _Machine(i, Rect.fromLTWH(10 + i * 116.0, 440, 108, 170)));
  final _foam = <_Foam>[];
  double _t = 0;
  double _spawnT = .1;
  int _spawned = 0;
  int _sorted = 0;
  int _miss = 0;
  _Cloth? _drag;
  Offset _lastP = Offset.zero;
  Offset _vel = Offset.zero;
  double _bump = 0;
  double _basketJig = 0;
  int _combo = 0;

  @override
  void update(double dt) {
    _t += dt;
    _bump = M.approach(_bump, 0, 8, dt);
    _basketJig = M.approach(_basketJig, 0, 6, dt);
    _vel = Offset.lerp(_vel, Offset.zero, min(1, dt * 6))!;
    if (!host.finished) {
      _spawnT -= dt;
      final onTable = _items.where((i) => i.state <= 1).length;
      if (_spawnT <= 0 && onTable < 7) {
        _spawnT = (_spawned < 3 ? .45 : rand(.75, 1.0)) / host.speed;
        _spawn();
      }
    }
    for (final it in _items) {
      it.squash = M.approach(it.squash, 0, 9, dt);
      switch (it.state) {
        case 0: // falling from basket
          it.vel += Offset(0, 1400 * dt);
          it.pos += it.vel * dt;
          it.rot += it.spin * dt;
          if (it.pos.dy >= it.rest.dy) {
            it.pos = it.rest;
            it.state = 1;
            it.squash = 1;
            it.rot *= .3;
            host.sfx(Sfx.thud, volume: .25, rate: 1.3);
          }
        case 1:
          it.rot = M.approach(it.rot, it.restRot, 6, dt);
        case 3: // sucked into machine
          it.suck += dt / .35;
          final m = _mach[it.target];
          it.pos = Offset.lerp(it.pos, m.window, min(1, dt * 14))!;
          it.rot += dt * 14;
          if (it.suck >= 1) it.gone = true;
        case 4: // bounced back after wrong
          it.pos = Offset.lerp(it.pos, it.rest, min(1, dt * 10))!;
          if ((it.pos - it.rest).distance < 2) it.state = 1;
      }
    }
    _items.removeWhere((i) => i.gone);
    for (final m in _mach) {
      m.spin += dt * (m.fast > 0 ? 16 : 3);
      m.fast = max(0, m.fast - dt);
      m.pink = max(0, m.pink - dt * .25);
      m.jolt = M.approach(m.jolt, 0, 6, dt);
    }
    for (final f in _foam) {
      f.life -= dt;
      f.pos += f.vel * dt;
      f.vel = Offset(f.vel.dx * .96, f.vel.dy + 60 * dt);
    }
    _foam.removeWhere((f) => f.life <= 0);
  }

  void _spawn() {
    _spawned++;
    final cat = randInt(3);
    // make sure no category is starved
    final color = switch (cat) { 0 => pick(_whites), 1 => pick(_colors), _ => pick(_darks) };
    final kind = randInt(5);
    final rest = Offset(rand(50, 310), rand(210, 360));
    final it = _Cloth(kind, cat, color, const Offset(180, 104), rest)
      ..vel = Offset((rest.dx - 180) * 1.6, -380)
      ..spin = rand(-8, 8)
      ..restRot = rand(-.35, .35)
      ..stripes = cat == 1 && chance(.3);
    _items.add(it);
    _basketJig = 1;
    host.sfx(Sfx.whoosh, volume: .3, rate: 1.4);
  }

  @override
  void onDown(Offset p) {
    _Cloth? best;
    var bd = 46.0;
    for (final it in _items.reversed) {
      if (it.state > 1 && it.state != 4) continue;
      final d = (it.pos - p).distance;
      if (d < bd) {
        bd = d;
        best = it;
      }
    }
    if (best == null) return;
    _drag = best;
    best.state = 2;
    best.squash = 1;
    _items
      ..remove(best)
      ..add(best);
    _lastP = p;
    _vel = Offset.zero;
    host.sfx(Sfx.pickup, volume: .4, rate: 1.2);
  }

  @override
  void onMove(Offset p) {
    final d = _drag;
    if (d == null) return;
    _vel = Offset.lerp(_vel, (p - _lastP) * 60, .5)!;
    _lastP = p;
    d.pos = p;
    d.rot = (_vel.dx / 2000).clamp(-.6, .6);
  }

  @override
  void onUp(Offset p) {
    final d = _drag;
    _drag = null;
    if (d == null) return;
    int? target;
    for (final m in _mach) {
      if (m.rect.inflate(6).contains(p)) target = m.type;
    }
    if (target == null && _vel.dy > 500) {
      // flick: project to the machine row
      final tt = (440 - p.dy) / _vel.dy;
      final x = p.dx + _vel.dx * tt;
      target = (((x - 10) / 116).floor()).clamp(0, 2);
    }
    if (target == null) {
      d.state = 1;
      d.rest = Offset(p.dx.clamp(40, 320), p.dy.clamp(200, 380));
      d.squash = 1;
      return;
    }
    final m = _mach[target];
    if (target == d.cat) {
      d.state = 3;
      d.target = target;
      _sorted++;
      _combo++;
      _bump = 1;
      m.fast = 1.2;
      m.jolt = 1;
      m.load.add(d.color);
      if (m.load.length > 5) m.load.removeAt(0);
      host.addScore(10 * min(_combo, 6), m.window + const Offset(0, -70));
      host.sfx(Sfx.bubble, volume: .7, rate: 1 + min(_combo, 8) * .06);
      host.sfx(Sfx.correct, volume: .5, rate: 1 + min(_combo, 8) * .05);
      host.fx.burst(m.window, Pal.white, count: 10, speed: 160, size: 8, gravity: -80,
          colors: const [Pal.white, Color(0xFFBFE8FF), Color(0xFF9FD8FF)]);
      if (_combo >= 3) host.fx.pop('COMBO x$_combo', m.window + const Offset(0, -100), color: Pal.lime, size: 20);
      if (_sorted >= _goal && !host.finished) {
        host.sfx(Sfx.fanfare);
        host.fx.confetti(count: 90);
        for (final mm in _mach) {
          mm.fast = 3;
        }
        host.fx.pop(host.tr('clean', 'SPARKLING!'), const Offset(180, 300), color: Pal.sky, size: 36, life: 1.3);
        host.win(stars: _miss == 0 ? 3 : (_miss == 1 ? 2 : 1));
      }
    } else {
      // WRONG: the machine foams pink
      d.state = 3;
      d.target = target;
      _miss++;
      _combo = 0;
      m.pink = 1;
      m.jolt = 1;
      m.fast = 1.5;
      m.load.add(d.color);
      for (var i = 0; i < m.load.length; i++) {
        m.load[i] = Color.lerp(m.load[i], Pal.pink, .7)!;
      }
      for (var i = 0; i < 26; i++) {
        final a = rand(-pi, 0);
        _foam.add(_Foam(m.window + Offset(rand(-20, 20), rand(-20, 10)), Offset(cos(a), sin(a)) * rand(40, 170), rand(8, 18),
            rand(1.2, 2.2)));
      }
      host.sfx(Sfx.splat);
      host.sfx(Sfx.buzzer, volume: .6);
      host.shake(8);
      host.flash(Pal.pink, .2);
      host.fx.pop(host.tr('oops', 'OOPS!'), m.window + const Offset(0, -90), color: Pal.pink, size: 30);
      if (_miss >= 3) {
        host.sfx(Sfx.jingleLose);
        host.lose();
      }
    }
  }

  @override
  void onTimeUp() {
    if (_sorted >= _goal - 2) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    // laundromat wall: pastel tiles
    D.gradientBg(c, const [Color(0xFFBDE9F7), Color(0xFF9ED8EE)]);
    final tile = D.stroke(const Color(0x33FFFFFF), 2);
    for (var y = 36.0; y < 440; y += 28) {
      c.drawLine(Offset(0, y), Offset(360, y), tile);
    }
    for (var x = 0.0; x < 360; x += 28) {
      c.drawLine(Offset(x, 36), Offset(x, 440), tile);
    }
    // floating soap bubbles
    for (var i = 0; i < 7; i++) {
      final y = 440 - ((_t * 20 + i * 67) % 400);
      final x = 20 + i * 52 + sin(_t + i) * 8;
      c.drawCircle(Offset(x, y), 6 + i % 3 * 3.0, D.stroke(const Color(0x88FFFFFF), 2));
    }
    // table
    D.rrect(c, const Rect.fromLTWH(14, 176, 332, 222), 20, const Color(0xFFE9C79A), border: Pal.ink, borderWidth: 4);
    D.rrect(c, const Rect.fromLTWH(24, 186, 312, 202), 14, const Color(0xFFF4DDB8));
    c.drawRect(const Rect.fromLTWH(14, 398, 332, 12), D.fill(const Color(0xFFB8905E)));
    // floor
    c.drawRect(const Rect.fromLTWH(0, 424, 360, 216), D.fill(const Color(0xFF8FA8C8)));
    Retro.tiles(c, const Rect.fromLTWH(0, 612, 360, 28), 14, const Color(0xFF7A92B4), const Color(0xFF8FA8C8));

    // basket + HUD
    _basket(c);
    final s = 1 + _bump * .3;
    c.save();
    c.translate(64, 104);
    c.scale(s);
    D.text(c, '$_sorted/$_goal', Offset.zero, size: 30, color: _sorted >= _goal ? Pal.lime : Pal.white, stroke: Pal.ink, strokeWidth: 6);
    c.restore();
    for (var i = 0; i < 3; i++) {
      final p = Offset(262 + i * 30.0, 104);
      D.circle(c, p, 11, i < _miss ? Pal.pink : const Color(0x66FFFFFF), border: Pal.ink, borderWidth: 2.5);
      if (i < _miss) {
        D.line(c, p + const Offset(-4, -4), p + const Offset(4, 4), Pal.white, 2.5);
        D.line(c, p + const Offset(4, -4), p + const Offset(-4, 4), Pal.white, 2.5);
      }
    }

    // machines
    final d = _drag;
    for (final m in _mach) {
      _machine(c, m, d != null && d.cat == m.type);
    }
    for (final f in _foam) {
      final a = (f.life / .5).clamp(0.0, 1.0);
      D.circle(c, f.pos, f.r, Color.fromRGBO(255, 150, 210, a), border: Color.fromRGBO(255, 255, 255, a * .8), borderWidth: 2);
    }

    // clothes
    for (final it in _items) {
      if (it.state == 0 || it.state == 2) continue;
      _cloth(c, it);
    }
    for (final it in _items) {
      if (it.state == 0) _cloth(c, it);
    }
    if (d != null) {
      D.shadow(c, d.pos + const Offset(8, 30), 60, 14, .2);
      _cloth(c, d);
    }

    // tutorial
    if (!host.finished && _sorted == 0 && d == null && host.time < 4 && _miss == 0) {
      final first = _items.where((i) => i.state == 1).firstOrNull;
      if (first != null) {
        final to = _mach[first.cat].window;
        final k = (_t * .8) % 1;
        D.hand(c, Offset.lerp(first.pos, to, M.easeInOut(k))!, _t);
      }
    }
  }

  void _basket(Canvas c) {
    final j = sin(_basketJig * pi * 3) * _basketJig * .15;
    c.save();
    c.translate(180, 96);
    c.rotate(j);
    // pile
    const pile = [Pal.red, Pal.white, Color(0xFF22305A), Pal.yellow, Pal.sky];
    for (var i = 0; i < 5; i++) {
      D.circle(c, Offset(-34 + i * 17.0, -16 - (i % 2) * 6.0), 14, pile[i], border: Pal.ink, borderWidth: 2);
    }
    final b = Path()
      ..moveTo(-52, -14)
      ..lineTo(52, -14)
      ..lineTo(42, 28)
      ..lineTo(-42, 28)
      ..close();
    c.drawPath(b, D.fill(const Color(0xFFD9A55A)));
    for (var i = 0; i < 4; i++) {
      c.drawLine(Offset(-50 + i * 2.0, -4 + i * 9.0), Offset(50 - i * 2.0, -4 + i * 9.0), D.stroke(const Color(0xFFB07E3A), 2.5));
    }
    c.drawPath(b, D.stroke(Pal.ink, 3.5));
    c.restore();
  }

  void _machine(Canvas c, _Machine m, bool hint) {
    final jx = sin(_t * 70) * (m.fast > 0 ? 1.5 : 0) + sin(m.jolt * 20) * m.jolt * 4;
    final r = m.rect.shift(Offset(jx, 0));
    final col = _machCol[m.type];
    if (hint) {
      final pulse = .5 + .5 * sin(_t * 12);
      c.drawRRect(RRect.fromRectAndRadius(r.inflate(5 + pulse * 3), const Radius.circular(20)), D.stroke(Pal.yellow, 5));
    }
    D.rrect(c, r.shift(const Offset(0, 5)), 16, const Color(0x44000000));
    D.rrect(c, r, 16, Color.lerp(Pal.white, m.pink > 0 ? Pal.pink : Pal.white, m.pink * .5)!, border: Pal.ink, borderWidth: 3.5);
    // control panel
    D.rrect(c, Rect.fromLTWH(r.left + 6, r.top + 6, r.width - 12, 34), 10, col, border: Pal.ink, borderWidth: 2.5);
    if (m.type == 1) {
      for (var i = 0; i < 5; i++) {
        c.drawRect(Rect.fromLTWH(r.left + 10 + i * 18.0, r.top + 10, 18, 26), D.fill(Pal.candy[i + 1].withValues(alpha: .7)));
      }
    }
    final name = switch (m.type) {
      0 => host.tr('white', 'WHITE'),
      1 => host.tr('color', 'COLOR'),
      _ => host.tr('dark', 'DARK'),
    };
    D.text(c, name, Offset(r.center.dx, r.top + 23), size: 16, color: m.type == 0 ? Pal.ink : Pal.white,
        stroke: m.type == 0 ? null : Pal.ink, strokeWidth: 4, maxWidth: r.width - 16);
    // porthole
    final w = m.window.translate(jx, 0);
    D.circle(c, w, 40, const Color(0xFFB8C0D0), border: Pal.ink, borderWidth: 3.5);
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: w, radius: 32)));
    c.drawCircle(w, 32, D.fill(m.pink > .1 ? const Color(0xFFFFB8E0) : const Color(0xFF2A4A7A)));
    c.drawRect(Rect.fromLTWH(w.dx - 40, w.dy + 4 + sin(m.spin * .5) * 3, 80, 40),
        D.fill(m.pink > .1 ? const Color(0xCCFF7AC8) : const Color(0xAA3FB8FF)));
    for (var i = 0; i < m.load.length; i++) {
      final a = m.spin + i * pi * 2 / max(1, m.load.length);
      D.circle(c, w + Offset(cos(a), sin(a)) * 16, 10, m.load[i], border: Pal.ink, borderWidth: 1.5);
    }
    if (m.fast > 0) {
      for (var i = 0; i < 5; i++) {
        final a = -m.spin * 1.3 + i * 1.3;
        c.drawCircle(w + Offset(cos(a), sin(a)) * 24, 3, D.fill(const Color(0xCCFFFFFF)));
      }
    }
    c.restore();
    c.drawArc(Rect.fromCircle(center: w, radius: 26), pi * 1.1, .8, false, D.stroke(const Color(0x99FFFFFF), 4));
    // category swatch
    final sw = Offset(r.center.dx, r.bottom - 16);
    final sc = switch (m.type) { 0 => _whites, 1 => _colors, _ => _darks };
    for (var i = 0; i < 3; i++) {
      D.circle(c, sw + Offset(-20 + i * 20.0, 0), 7, sc[i], border: Pal.ink, borderWidth: 2);
    }
    if (m.pink > 0) D.face(c, w + const Offset(0, -2), 22, Face.dead, blush: false);
  }

  void _cloth(Canvas c, _Cloth it) {
    final sq = 1 + sin(it.squash * pi) * .18;
    final sc = it.state == 3 ? (1 - it.suck).clamp(0.05, 1.0) : (it.state == 2 ? 1.12 : 1.0);
    c.save();
    c.translate(it.pos.dx, it.pos.dy);
    c.rotate(it.rot);
    c.scale(sc * sq, sc / sq);
    final fill = D.fill(it.color);
    final line = D.stroke(Pal.ink, 3);
    final dark = it.cat == 2;
    final seam = D.stroke(dark ? const Color(0x66FFFFFF) : const Color(0x33000000), 2);
    Path p;
    switch (it.kind) {
      case 0: // t-shirt
        p = Path()
          ..moveTo(-12, -26)
          ..quadraticBezierTo(0, -18, 12, -26)
          ..lineTo(34, -14)
          ..lineTo(26, 0)
          ..lineTo(18, -4)
          ..lineTo(18, 28)
          ..lineTo(-18, 28)
          ..lineTo(-18, -4)
          ..lineTo(-26, 0)
          ..lineTo(-34, -14)
          ..close();
      case 1: // sock
        p = Path()
          ..moveTo(-10, -30)
          ..lineTo(10, -30)
          ..lineTo(10, 8)
          ..quadraticBezierTo(30, 8, 30, 20)
          ..quadraticBezierTo(30, 30, 16, 30)
          ..lineTo(-4, 30)
          ..quadraticBezierTo(-10, 30, -10, 20)
          ..close();
      case 2: // jeans
        p = Path()
          ..moveTo(-22, -30)
          ..lineTo(22, -30)
          ..lineTo(26, 32)
          ..lineTo(6, 32)
          ..lineTo(0, -4)
          ..lineTo(-6, 32)
          ..lineTo(-26, 32)
          ..close();
      case 3: // towel
        p = Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-30, -22, 60, 44), const Radius.circular(6)));
      default: // dress
        p = Path()
          ..moveTo(-10, -30)
          ..lineTo(10, -30)
          ..lineTo(14, -10)
          ..lineTo(32, 30)
          ..lineTo(-32, 30)
          ..lineTo(-14, -10)
          ..close();
    }
    c.drawPath(p, fill);
    if (it.stripes) {
      c.save();
      c.clipPath(p);
      for (var y = -30.0; y < 34; y += 12) {
        c.drawRect(Rect.fromLTWH(-40, y, 80, 5), D.fill(const Color(0xCCFFFFFF)));
      }
      c.restore();
    }
    switch (it.kind) {
      case 0:
        c.drawLine(const Offset(-18, 18), const Offset(18, 18), seam);
      case 1:
        c.drawLine(const Offset(-10, -20), const Offset(10, -20), seam);
      case 2:
        c.drawLine(const Offset(-22, -22), const Offset(22, -22), seam);
        c.drawCircle(const Offset(0, -26), 2, D.fill(Pal.gold));
      case 3:
        c.drawLine(const Offset(-30, 14), const Offset(30, 14), seam);
        c.drawLine(const Offset(-30, -14), const Offset(30, -14), seam);
      default:
        c.drawLine(const Offset(-14, -10), const Offset(14, -10), seam);
    }
    c.drawPath(p, line);
    c.restore();
  }
}

class _Cloth {
  _Cloth(this.kind, this.cat, this.color, this.pos, this.rest);
  final int kind, cat;
  final Color color;
  Offset pos, rest;
  Offset vel = Offset.zero;
  double rot = 0, restRot = 0, spin = 0, squash = 0, suck = 0;
  int state = 0; // 0 falling, 1 resting, 2 dragged, 3 into machine, 4 bouncing back
  int target = 0;
  bool stripes = false;
  bool gone = false;
}

class _Machine {
  _Machine(this.type, this.rect);
  final int type;
  final Rect rect;
  double spin = 0, fast = 0, pink = 0, jolt = 0;
  final List<Color> load = [];
  Offset get window => Offset(rect.center.dx, rect.top + 96);
}

class _Foam {
  _Foam(this.pos, this.vel, this.r, this.life);
  Offset pos, vel;
  final double r;
  double life;
}
