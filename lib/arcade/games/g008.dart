import '../engine/engine.dart';

/// No.008 Fruit Merge Drop — Suika-like. Drag to aim, release to drop. Two
/// equal fruits merge into the next one. Make the MELON before time runs out.
class G008 extends MiniGame {
  static const _radii = <double>[11, 14, 18, 22, 27, 32, 37, 43, 50, 58];
  static const _colors = <Color>[
    Color(0xFFE8213B), // cherry
    Color(0xFFFF4D6D), // strawberry
    Color(0xFF9B4DFF), // grape
    Color(0xFFFF9F1C), // orange
    Color(0xFFFF3B3B), // apple
    Color(0xFFD7E36B), // pear
    Color(0xFFFFB3A7), // peach
    Color(0xFFFFD23F), // pineapple
    Color(0xFF9BE22D), // melon
    Color(0xFF2E9E57), // watermelon
  ];
  static const _goal = 8;
  static const _left = 22.0, _right = 338.0, _floor = 604.0, _line = 222.0;
  static const _dropY = 170.0;

  final List<_Fruit> _fruits = [];
  int _cur = 3;
  int _next = 2;
  double _aimX = 180;
  double _cool = 0;
  bool _aiming = false;
  double _t = 0;
  double _danger = 0;
  int _best = 7;
  double _combo = 0;
  int _chain = 0;
  bool _done = false;
  int _drops = 0;

  // ----------------------------------------------------------------- setup ---
  @override
  void init() {
    final flip = chance(.5);
    double fx(double x) => flip ? 360 - x : x;
    void put(int lv, double x, double y) => _fruits.add(_Fruit(Offset(fx(x), y), lv)..age = 5);
    put(7, 66, _floor - 43);
    put(6, 146, _floor - 37);
    put(5, 216, _floor - 32);
    put(3, 272, _floor - 22);
    put(1, 70, _floor - 110);
    for (var i = 0; i < 120; i++) {
      _step(1 / 60, allowMerge: false);
    }
    _cur = 3;
    _next = 3;
  }

  int _roll() {
    final r = host.rng.nextDouble();
    if (_drops < 1) return 3;
    if (r < .2) return 0;
    if (r < .45) return 1;
    if (r < .72) return 2;
    return 3;
  }

  // --------------------------------------------------------------- physics ---
  void _step(double dt, {bool allowMerge = true}) {
    const sub = 4;
    final h = dt / sub;
    for (var s = 0; s < sub; s++) {
      for (final f in _fruits) {
        f.vel = Offset(f.vel.dx * (1 - .4 * h), f.vel.dy + 1500 * h);
        f.pos += f.vel * h;
        final r = f.r;
        if (f.pos.dy > _floor - r) {
          f.pos = Offset(f.pos.dx, _floor - r);
          if (f.vel.dy > 0) f.vel = Offset(f.vel.dx * .96, -f.vel.dy * .15);
        }
        if (f.pos.dx < _left + r) {
          f.pos = Offset(_left + r, f.pos.dy);
          if (f.vel.dx < 0) f.vel = Offset(-f.vel.dx * .2, f.vel.dy);
        }
        if (f.pos.dx > _right - r) {
          f.pos = Offset(_right - r, f.pos.dy);
          if (f.vel.dx > 0) f.vel = Offset(-f.vel.dx * .2, f.vel.dy);
        }
      }
      for (var i = 0; i < _fruits.length; i++) {
        final a = _fruits[i];
        for (var j = i + 1; j < _fruits.length; j++) {
          final b = _fruits[j];
          final d = b.pos - a.pos;
          final dist = d.distance;
          final minD = a.r + b.r;
          // gentle attraction between twins so chains happen
          if (a.level == b.level && dist < minD + 24 && dist > 1e-4) {
            final pull = d / dist * 900 * h;
            a.vel += pull;
            b.vel -= pull;
            if (allowMerge && dist < minD + 6 && !a.dead && !b.dead && a.level < _radii.length - 1) {
              _merge(a, b);
              continue;
            }
          }
          if (dist >= minD || dist < 1e-6) continue;
          final n = d / dist;
          final ma = a.r * a.r, mb = b.r * b.r;
          final pen = minD - dist;
          a.pos -= n * (pen * mb / (ma + mb));
          b.pos += n * (pen * ma / (ma + mb));
          final rv = (b.vel - a.vel).dx * n.dx + (b.vel - a.vel).dy * n.dy;
          if (rv < 0) {
            final imp = -1.1 * rv / (1 / ma + 1 / mb);
            a.vel -= n * (imp / ma);
            b.vel += n * (imp / mb);
          }
          if (allowMerge && a.level == b.level && !a.dead && !b.dead && a.level < _radii.length - 1) {
            _merge(a, b);
          }
        }
      }
      _fruits.removeWhere((f) => f.dead);
    }
    for (final f in _fruits) {
      f.angle += f.vel.dx / f.r * dt;
    }
  }

  void _merge(_Fruit a, _Fruit b) {
    a.dead = true;
    b.dead = true;
    final lv = a.level + 1;
    // spawn next to an existing twin of the new fruit so chains can cascade
    var at = (a.pos + b.pos) / 2;
    var bestD = 1e9;
    for (final o in _fruits) {
      if (o.dead || o.level != lv) continue;
      for (final p in [a.pos, b.pos]) {
        final d = (o.pos - p).distance;
        if (d < bestD) {
          bestD = d;
          at = p;
        }
      }
    }
    final nf = _Fruit(at, lv)
      ..vel = Offset(0, -140)
      ..pop = 0
      ..age = 2;
    _fruits.add(nf);
    _chain = _combo > 0 ? _chain + 1 : 1;
    _combo = 1.0;
    final col = _colors[lv];
    host.sfx(lv >= 6 ? Sfx.levelup : Sfx.pop, rate: 1 + min(_chain, 8) * .09);
    host.sfx(Sfx.squish, volume: .5, rate: 1.3);
    host.fx.burst(at, col, count: 10 + lv * 3, speed: 150 + lv * 25.0, colors: [col, Pal.white, Pal.yellow]);
    host.fx.ring(at, Pal.white, size: nf.r * 2);
    final pts = 10 * (1 << lv);
    host.addScore(pts, at - Offset(0, nf.r + 10));
    if (_chain >= 2) {
      host.fx.pop('${host.tr('combo', 'COMBO')} x$_chain', at - Offset(0, nf.r + 44), color: Pal.pink, size: 24);
    }
    if (lv >= 5) {
      host.shake(2.0 + lv);
      host.punch(.02 + lv * .004);
    }
    if (lv > _best) _best = lv;
    if (lv >= _goal && !_done) {
      _done = true;
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.cheer);
      host.hitStop(.15);
      host.flash(Pal.white, .25);
      host.fx.confetti(count: 100);
      host.fx.coins(at, count: 26);
      host.fx.pop(host.tr('wow', 'WOW!'), const Offset(180, 260), color: Pal.lime, size: 56, life: 1.4);
      final t = host.time;
      host.win(stars: t < 12 ? 3 : (t < 19 ? 2 : 1));
    }
  }

  // ---------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    _cool -= dt;
    _combo = max(0, _combo - dt);
    if (_combo <= 0) _chain = 0;
    _step(dt);
    var over = false;
    for (final f in _fruits) {
      f.age += dt;
      f.pop = min(1, f.pop + dt * 5);
      if (f.age > 1.2 && f.pos.dy - f.r < _line && f.vel.distance < 120) over = true;
    }
    _danger = over ? _danger + dt : max(0, _danger - dt * 2);
    if (_danger > 1.8 && !_done && !host.finished) {
      host.sfx(Sfx.buzzer);
      host.shake(8);
      host.flash(Pal.red, .2);
      host.fx.pop(host.tr('oops', 'OOPS!'), const Offset(180, 300), color: Pal.red, size: 44);
      host.lose();
    }
  }

  @override
  void onTimeUp() => host.lose();

  // ----------------------------------------------------------------- input ---
  double _clampAim(double x) => x.clamp(_left + _radii[_cur] + 2, _right - _radii[_cur] - 2);

  @override
  void onDown(Offset p) {
    _aiming = true;
    _aimX = _clampAim(p.dx);
  }

  @override
  void onMove(Offset p) {
    if (_aiming) _aimX = _clampAim(p.dx);
  }

  @override
  void onUp(Offset p) {
    if (!_aiming) return;
    _aiming = false;
    _aimX = _clampAim(p.dx);
    _drop();
  }

  void _drop() {
    if (_cool > 0 || _done) return;
    _fruits.add(_Fruit(Offset(_aimX, _dropY), _cur)..vel = const Offset(0, 120));
    _drops++;
    host.sfx(Sfx.throwIt, volume: .6, rate: 1.3 - _cur * .05);
    _cur = _next;
    _next = _roll();
    _cool = .6;
    _aimX = _clampAim(_aimX);
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'left') _aimX = _clampAim(_aimX - 24);
    if (key == 'right') _aimX = _clampAim(_aimX + 24);
    if (key == 'action' || key == 'down') _drop();
  }

  // ---------------------------------------------------------------- render ---
  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFFFFE9B0), Color(0xFFFFC77D)]);
    // checkered picnic pattern
    final chk = D.fill(const Color(0x18FF5F7A));
    for (var y = 0; y < 17; y++) {
      for (var x = 0; x < 10; x++) {
        if ((x + y).isEven) c.drawRect(Rect.fromLTWH(x * 40.0, 36 + y * 40.0, 40, 40), chk);
      }
    }
    // evolution chain
    D.rrect(c, const Rect.fromLTWH(10, 44, 340, 44), 22, const Color(0xCCFFFFFF), border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < _radii.length; i++) {
      final o = Offset(30 + i * 33.5, 66);
      final isGoal = i == _goal;
      if (isGoal) {
        c.drawCircle(o, 18 + M.wave(_t, 2) * 3, D.fill(const Color(0x66FFD23F)));
      }
      _drawFruit(c, o, 7 + i * .9, i, 0, face: false, dim: i > _best);
      if (isGoal) D.star(c, o + const Offset(12, -12), 7, Pal.yellow, border: Pal.ink);
    }
    // box
    const box = Rect.fromLTRB(_left, _line - 30, _right, _floor);
    D.rrect(c, box.inflate(8), 14, const Color(0xFFB07A4F), border: Pal.ink, borderWidth: 4);
    D.rrect(c, box, 8, const Color(0xFFFFF4DC));
    for (var y = box.top + 20; y < box.bottom; y += 36) {
      c.drawLine(Offset(box.left, y), Offset(box.right, y), D.stroke(const Color(0x14B07A4F), 2));
    }
    // danger line
    final blink = _danger > 0 ? (sin(_t * 20) > 0 ? 1.0 : .3) : .5;
    final dl = D.stroke(Color.fromRGBO(255, 59, 92, blink), 3);
    for (var x = _left + 4; x < _right - 4; x += 16) {
      c.drawLine(Offset(x, _line), Offset(x + 9, _line), dl);
    }
    // next preview
    D.rrect(c, const Rect.fromLTWH(292, 100, 56, 56), 14, const Color(0xCCFFFFFF), border: Pal.ink, borderWidth: 3);
    D.text(c, host.tr('next', 'NEXT'), const Offset(320, 110), size: 11, color: Pal.ink);
    _drawFruit(c, const Offset(320, 134), min(18, _radii[_next]), _next, 0, face: false);
    // aim guide
    if (!_done) {
      final r = _radii[_cur];
      final g = D.stroke(const Color(0x66FFFFFF), 3);
      for (var y = _dropY + r + 6; y < _floor; y += 14) {
        c.drawLine(Offset(_aimX, y), Offset(_aimX, y + 6), g);
      }
      // cloud dropper
      D.cloud(c, Offset(_aimX, _dropY - r - 18), 36, color: Pal.white);
      if (_cool <= 0) {
        _drawFruit(c, Offset(_aimX, _dropY), r, _cur, sin(_t * 3) * .15);
      } else {
        final k = 1 - (_cool / .45).clamp(0.0, 1.0);
        _drawFruit(c, Offset(_aimX, _dropY), r * M.easeOutBack(k), _cur, 0);
      }
    }
    // fruits
    for (final f in _fruits) {
      final s = f.pop < 1 ? M.easeOutBack(f.pop) : 1.0;
      final worried = f.pos.dy - f.r < _line + 30;
      _drawFruit(c, f.pos, f.r * s, f.level, f.angle, worried: worried);
    }
    // hint
    if (_drops == 0 && host.time < 3.5) {
      final target = _fruits.where((f) => f.level == 3).firstOrNull;
      final tx = target?.pos.dx ?? 180;
      D.hand(c, Offset(tx, _dropY + 40), _t);
      D.arrow(c, Offset(tx, _dropY + 90), const Offset(0, 1), 40, Pal.white, width: 10);
    }
    if (_danger > .3) {
      D.text(c, host.tr('danger', 'DANGER!'), const Offset(180, _line - 14), size: 20, color: Pal.red, stroke: Pal.white);
    }
  }

  void _drawFruit(Canvas c, Offset o, double r, int lv, double angle,
      {bool face = true, bool worried = false, bool dim = false}) {
    if (r < 1) return;
    final col = _colors[lv];
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(angle);
    final body = Paint()..color = dim ? Color.lerp(col, const Color(0xFFBBBBBB), .7)! : col;
    final ink = D.stroke(Pal.ink, max(1.5, r * .08));
    switch (lv) {
      case 0: // cherry
        c.drawLine(Offset(0, -r * .7), Offset(r * .5, -r * 1.4), D.stroke(const Color(0xFF3E7A2E), r * .15));
        c.drawCircle(Offset.zero, r, body);
        c.drawCircle(Offset.zero, r, ink);
      case 1: // strawberry
        final p = Path()
          ..moveTo(0, r)
          ..quadraticBezierTo(-r * 1.2, r * .1, -r * .8, -r * .6)
          ..quadraticBezierTo(0, -r * 1.05, r * .8, -r * .6)
          ..quadraticBezierTo(r * 1.2, r * .1, 0, r)
          ..close();
        c.drawPath(p, body);
        c.drawPath(p, ink);
        for (var i = 0; i < 6; i++) {
          c.drawCircle(Offset(cos(i * 1.1) * r * .5, sin(i * 1.7) * r * .35 + r * .2), r * .06, D.fill(const Color(0xFFFFF1A8)));
        }
        c.drawPath(D.starPath(Offset(0, -r * .75), r * .45, r * .2, points: 5), D.fill(const Color(0xFF3FAE50)));
      case 2: // grape
        c.drawCircle(Offset.zero, r, body);
        for (final q in [Offset(-r * .4, -r * .35), Offset(r * .4, -r * .35), Offset(0, r * .35)]) {
          c.drawCircle(q, r * .42, D.stroke(Color.lerp(col, Pal.ink, .3)!, max(1, r * .06)));
        }
        c.drawCircle(Offset.zero, r, ink);
      case 7: // pineapple
        for (var i = -1; i <= 1; i++) {
          final leaf = Path()
            ..moveTo(i * r * .25 - r * .15, -r * .8)
            ..lineTo(i * r * .35, -r * 1.35 + i.abs() * r * .15)
            ..lineTo(i * r * .25 + r * .15, -r * .8)
            ..close();
          c.drawPath(leaf, D.fill(const Color(0xFF3FAE50)));
          c.drawPath(leaf, D.stroke(Pal.ink, max(1.5, r * .05)));
        }
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.9, height: r * 2), body);
        c.save();
        c.clipPath(Path()..addOval(Rect.fromCenter(center: Offset.zero, width: r * 1.9, height: r * 2)));
        final hatch = D.stroke(const Color(0x55B8860B), max(1, r * .05));
        for (var k = -3; k <= 3; k++) {
          c.drawLine(Offset(k * r * .4 - r, -r), Offset(k * r * .4 + r, r), hatch);
          c.drawLine(Offset(k * r * .4 + r, -r), Offset(k * r * .4 - r, r), hatch);
        }
        c.restore();
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.9, height: r * 2), ink);
      case 8 || 9: // melon / watermelon
        c.drawCircle(Offset.zero, r, body);
        c.save();
        c.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)));
        if (lv == 8) {
          final net = D.stroke(const Color(0x88F4FFE0), max(1, r * .04));
          for (var k = -3; k <= 3; k++) {
            c.drawLine(Offset(k * r * .35 - r * .3, -r), Offset(k * r * .35 + r * .3, r), net);
            c.drawLine(Offset(-r, k * r * .35 - r * .2), Offset(r, k * r * .35 + r * .2), net);
          }
        } else {
          for (var k = -2; k <= 2; k++) {
            final p = Path()..moveTo(k * r * .42, -r);
            for (var y = -r; y <= r; y += r * .25) {
              p.lineTo(k * r * .42 + sin(y / r * 6) * r * .08, y);
            }
            c.drawPath(p, D.stroke(const Color(0xFF14532D), r * .14));
          }
        }
        c.restore();
        c.drawCircle(Offset.zero, r, ink);
      default: // orange, apple, pear, peach
        c.drawCircle(Offset.zero, r, body);
        if (lv == 3) {
          for (var i = 0; i < 8; i++) {
            c.drawCircle(Offset(cos(i * 2.1) * r * .6, sin(i * 1.3) * r * .6), r * .04, D.fill(const Color(0x55B85A00)));
          }
        }
        if (lv == 6) {
          c.drawArc(Rect.fromCircle(center: Offset(r * .15, 0), radius: r * .85), -1.2, 1.4, false,
              D.stroke(const Color(0x55E0607A), r * .08));
        }
        c.drawCircle(Offset.zero, r, ink);
        if (lv == 4 || lv == 5) {
          c.drawLine(Offset(0, -r * .85), Offset(r * .1, -r * 1.2), D.stroke(const Color(0xFF6B4226), r * .1));
          c.drawOval(Rect.fromCenter(center: Offset(r * .32, -r * 1.05), width: r * .45, height: r * .22),
              D.fill(const Color(0xFF3FAE50)));
        }
    }
    // shine
    c.drawOval(Rect.fromCenter(center: Offset(-r * .4, -r * .45), width: r * .45, height: r * .28),
        D.fill(const Color(0x77FFFFFF)));
    c.restore();
    if (face && r > 9) {
      D.face(c, o + Offset(0, r * .12), r * .6, worried ? Face.shocked : (lv >= 6 ? Face.smug : Face.happy));
    }
  }
}

class _Fruit {
  _Fruit(this.pos, this.level);
  Offset pos;
  final int level;
  Offset vel = Offset.zero;
  double angle = 0;
  double age = 0;
  double pop = 1;
  bool dead = false;
  double get r => G008._radii[level];
}
