import '../engine/engine.dart';

/// No.075 Wake Up! — the alarm clock hops around the bed; smack it again and
/// again. Each hit pries the sleeper's eyelids open a bit more.
class G075 extends MiniGame {
  static const _head = Offset(180, 186);
  double _t = 0;
  Offset _from = const Offset(250, 420);
  Offset _to = const Offset(250, 420);
  double _hop = 1; // 0..1 progress of current hop
  double _rest = 0;
  double _bonk = 0;
  double _eyes = 0; // 0 closed .. 1 wide open
  late int _need;
  int _hits = 0;
  bool _awake = false;
  double _awakeT = 0;
  double _snot = 0;
  int _misses = 0;

  @override
  void init() {
    _need = 7 + ((host.speed - 1) * 5).round();
    _from = _to = Offset(rand(90, 270), rand(330, 520));
    _rest = .4;
  }

  Offset get _clock {
    if (_hop >= 1) return _to;
    final k = M.easeInOut(_hop);
    final p = Offset.lerp(_from, _to, k)!;
    return p - Offset(0, sin(_hop * pi) * 70);
  }

  double get _hopDur => .3 / host.speed;

  void _newTarget() {
    _from = _clock;
    Offset n;
    do {
      n = Offset(rand(70, 290), rand(290, 560));
    } while ((n - _from).distance < 110);
    _to = n;
    _hop = 0;
    host.sfx(Sfx.boing, volume: .5, rate: 1.3);
  }

  @override
  void update(double dt) {
    _t += dt;
    if (_awake) {
      _awakeT += dt;
      _eyes = 1;
    } else {
      if (_hop < 1) {
        _hop = min(1, _hop + dt / _hopDur);
        if (_hop >= 1) {
          _rest = rand(.45, .75) / host.speed;
          host.sfx(Sfx.land, volume: .5);
        }
      } else if (!host.finished) {
        _rest -= dt;
        if (_rest <= 0) _newTarget();
        if ((_t * 14).floor() != ((_t - dt) * 14).floor()) host.sfx(Sfx.bell, volume: .25, rate: 1.6);
      }
      _eyes = max(0, _eyes - dt * .09 * host.speed);
    }
    _bonk = M.approach(_bonk, 0, 7, dt);
    _snot = .5 + .5 * sin(_t * 2.2);
  }

  @override
  void onDown(Offset p) {
    if (_awake || host.finished) return;
    if ((p - _clock).distance < 52) {
      _hits++;
      _eyes = min(1, _eyes + 1 / _need + .02);
      _bonk = 1;
      host.sfx(Sfx.hit, rate: .9 + _hits * .05);
      host.sfx(Sfx.clang, volume: .5, rate: 1.4);
      host.shake(4);
      host.hitStop(.035);
      host.fx.burst(_clock, Pal.yellow, count: 8, speed: 200, shape: PartShape.star, size: 7, gravity: 200);
      host.fx.ring(_clock, Pal.white, size: 50);
      if (_hits % 3 == 0) {
        host.fx.pop('x$_hits', _clock + const Offset(0, -50), color: Pal.orange, size: 26);
      }
      if (_eyes >= .999) {
        _wake();
      } else {
        _newTarget();
      }
    } else {
      _misses++;
      host.sfx(Sfx.swing, volume: .5, rate: 1.5);
    }
  }

  void _wake() {
    _awake = true;
    host.sfx(Sfx.horror, volume: .5, rate: 1.4);
    host.sfx(Sfx.jump);
    host.shake(10, .35);
    host.flash(const Color(0xAAFFFFFF));
    host.fx.pop(host.tr('late', 'LATE!'), const Offset(180, 90), color: Pal.red, size: 44, life: 1.2);
    host.fx.burst(_head, Pal.sky, count: 16, speed: 260, size: 8, gravity: 500);
    host.win(stars: host.timeLeft > 1.6 ? 3 : (_misses < 4 ? 2 : 1));
  }

  @override
  void onTimeUp() {
    host.sfx(Sfx.aww, volume: .8);
    host.lose();
  }

  @override
  void render(Canvas c) {
    // morning sunlight room
    D.gradientBg(c, const [Color(0xFFFFE58A), Color(0xFFFFA24D)]);
    D.rays(c, const Offset(360, 0), 800, const Color(0x33FFFFFF), count: 14, t: _t * .2);
    // floor planks
    for (var i = 0; i < 9; i++) {
      D.line(c, Offset(i * 45.0, 40), Offset(i * 45.0, 640), const Color(0x22A0602A), 3);
    }

    // bed frame
    const frame = Rect.fromLTWH(26, 84, 308, 546);
    D.rrect(c, frame.shift(const Offset(8, 10)), 30, const Color(0x44000000));
    D.rrect(c, frame, 30, const Color(0xFF8A4B2A), border: Pal.ink, borderWidth: 5);
    D.rrect(c, frame.deflate(14), 22, Pal.white);

    // pillow
    D.rrect(c, const Rect.fromLTWH(70, 110, 220, 120), 40, const Color(0xFFE8F0FF), border: Pal.ink, borderWidth: 4);

    _drawHead(c);

    // blanket
    final lift = _awake ? M.easeOutBack(M.clamp01(_awakeT * 3)) * 60 : 0.0;
    final blanket = Rect.fromLTWH(40, 250 + lift, 280, 366 - lift);
    final bump = Path()..addRRect(RRect.fromRectAndRadius(blanket, const Radius.circular(26)));
    c.drawPath(bump, D.fill(const Color(0xFF5B8CFF)));
    c.save();
    c.clipPath(bump);
    for (var y = 0; y < 7; y++) {
      for (var x = 0; x < 5; x++) {
        final o = Offset(70 + x * 56.0 + (y.isOdd ? 28 : 0), 290 + lift + y * 52.0);
        D.star(c, o, 10, const Color(0x55FFFFFF));
      }
    }
    // body bump shading (breathing)
    final breathe = _awake ? 0.0 : sin(_t * 2.2) * 6;
    c.drawOval(Rect.fromCenter(center: Offset(180, 400 + lift), width: 170 + breathe, height: 260),
        D.fill(const Color(0x22FFFFFF)));
    c.restore();
    c.drawPath(bump, D.stroke(Pal.ink, 5));
    D.rrect(c, Rect.fromLTWH(40, 250 + lift, 280, 30), 14, Pal.white, border: Pal.ink, borderWidth: 4);

    // Zzz
    if (!_awake) {
      for (var i = 0; i < 3; i++) {
        final k = ((_t * .7 + i / 3) % 1.0);
        D.text(c, 'Z', Offset(270 + k * 50, 150 - k * 90), size: 18 + k * 18,
            color: D.withAlpha(Pal.white, 1 - k), stroke: D.withAlpha(Pal.ink, 1 - k));
      }
    }

    _drawClock(c);

    // wake meter
    D.bar(c, const Rect.fromLTWH(60, 50, 240, 20), _eyes, _eyes > .7 ? Pal.lime : Pal.orange, border: Pal.ink);
    D.circle(c, const Offset(52, 60), 16, Pal.white, border: Pal.ink);
    D.face(c, const Offset(52, 60), 14, _eyes > .5 ? Face.shocked : Face.sleepy, blush: false);

    if (host.time < 1.8 && _hits == 0) {
      D.hand(c, _clock + const Offset(10, 20), _t);
    }
  }

  void _drawHead(Canvas c) {
    final jump = _awake ? M.easeOutBack(M.clamp01(_awakeT * 3)) : 0.0;
    final h = _head + Offset(0, -jump * 26);
    final r = 74 + jump * 16;
    c.save();
    c.translate(h.dx, h.dy);
    if (_awake) c.rotate(sin(_awakeT * 30) * .05 * (1 - M.clamp01(_awakeT)));
    // hair (bed head)
    for (var i = 0; i < 7; i++) {
      final a = -pi + i * pi / 6;
      c.drawCircle(Offset(cos(a) * r * .8, sin(a) * r * .8 - 6), r * .34, D.fill(const Color(0xFF2E2238)));
    }
    c.drawCircle(Offset.zero, r, D.fill(Pal.skin));
    c.drawCircle(Offset.zero, r, D.stroke(Pal.ink, 5));
    // sleep mask pushed up? no — eyelids!
    for (final s in [-1.0, 1.0]) {
      final e = Offset(s * r * .38, -r * .08);
      final ew = r * .5, eh = r * .42 * (_awake ? 1.3 : 1);
      final eyeRect = Rect.fromCenter(center: e, width: ew, height: eh);
      final open = _awake ? 1.0 : _eyes;
      if (open < .06) {
        c.drawArc(Rect.fromCenter(center: e, width: ew, height: eh * .6), .1, pi - .2, false, D.stroke(Pal.ink, 5));
        continue;
      }
      c.drawOval(eyeRect, D.fill(Pal.white));
      final pr = _awake ? r * .07 : r * .11;
      c.drawCircle(e + Offset(_awake ? 0 : sin(_t * 1.3) * 3, 3), pr, D.fill(Pal.ink));
      // eyelid (skin) coming down from the top
      c.save();
      c.clipPath(Path()..addOval(eyeRect));
      final lidH = eh * (1 - open) + 1;
      c.drawRect(Rect.fromLTWH(eyeRect.left - 2, eyeRect.top - 2, ew + 4, lidH + 2),
          D.fill(Color.lerp(Pal.skin, Pal.skinDark, .25)!));
      c.restore();
      D.line(c, Offset(eyeRect.left + 2, eyeRect.top + lidH), Offset(eyeRect.right - 2, eyeRect.top + lidH), Pal.ink, 4);
      c.drawOval(eyeRect, D.stroke(Pal.ink, 4));
      // red veins when half-awake
      if (!_awake && open > .4) {
        D.line(c, e + Offset(-ew * .4, eh * .1), e + Offset(-ew * .2, eh * .2), Pal.red, 1.5);
      }
    }
    // mouth
    if (_awake) {
      c.drawOval(Rect.fromCenter(center: Offset(0, r * .5), width: r * .5, height: r * .45), D.fill(const Color(0xFF7A1F2B)));
      c.drawOval(Rect.fromCenter(center: Offset(0, r * .5), width: r * .5, height: r * .45), D.stroke(Pal.ink, 4));
      // sweat
      for (final s in [-1.0, 1.0]) {
        c.drawCircle(Offset(s * (r + 12), -r * .3 + (_awakeT * 60) % 20), 7, D.fill(const Color(0xFF7FD3FF)));
      }
    } else {
      c.drawOval(Rect.fromCenter(center: Offset(0, r * .45), width: r * .24, height: r * .16 + _eyes * 8),
          D.fill(const Color(0xFF7A1F2B)));
      // drool
      D.line(c, Offset(r * .1, r * .5), Offset(r * .18, r * .72), const Color(0xCC8ED8FF), 5);
      // snot bubble
      final sb = (8 + _snot * 22) * (1 - _eyes * .6);
      c.drawCircle(Offset(-r * .2 - sb * .6, r * .2), sb, D.fill(const Color(0x668ED8FF)));
      c.drawCircle(Offset(-r * .2 - sb * .6, r * .2), sb, D.stroke(const Color(0xFF6FA8D8), 2));
      c.drawCircle(Offset(-r * .2 - sb * .9, r * .2 - sb * .4), sb * .22, D.fill(const Color(0xAAFFFFFF)));
    }
    c.restore();
  }

  void _drawClock(Canvas c) {
    final o = _clock;
    final ring = !host.finished && _hop >= 1;
    final shake = ring ? sin(_t * 60) * 4 : 0.0;
    final airborne = _hop < 1;
    D.shadow(c, airborne ? Offset.lerp(_from, _to, M.easeInOut(_hop))! + const Offset(0, 40) : o + const Offset(0, 40),
        70, 18);
    c.save();
    c.translate(o.dx + shake, o.dy);
    final sq = 1 + _bonk * .35;
    c.scale(sq, 1 / sq);
    c.rotate(ring ? sin(_t * 50) * .12 : (airborne ? _hop * pi * 2 * .15 : 0));
    if (_awake) c.rotate(pi / 2 * M.clamp01(_awakeT * 4));
    // legs
    for (final s in [-1.0, 1.0]) {
      D.line(c, Offset(s * 20, 28), Offset(s * 30, 44), Pal.ink, 6);
    }
    // bells
    for (final s in [-1.0, 1.0]) {
      final b = Offset(s * 26, -36);
      c.drawArc(Rect.fromCenter(center: b, width: 34, height: 34), pi, pi, true, D.fill(Pal.gold));
      c.drawArc(Rect.fromCenter(center: b, width: 34, height: 34), pi, pi, true, D.stroke(Pal.ink, 4));
    }
    D.line(c, const Offset(0, -46), const Offset(0, -36), Pal.ink, 6);
    c.drawCircle(const Offset(0, -48), 6, D.fill(Pal.ink));
    // body
    c.drawCircle(Offset.zero, 38, D.fill(Pal.red));
    c.drawCircle(Offset.zero, 38, D.stroke(Pal.ink, 5));
    c.drawCircle(Offset.zero, 29, D.fill(Pal.white));
    c.drawCircle(Offset.zero, 29, D.stroke(Pal.ink, 3));
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      c.drawCircle(Offset(cos(a), sin(a)) * 23, i % 3 == 0 ? 3 : 1.5, D.fill(Pal.ink));
    }
    // angry little face instead of hands
    D.face(c, const Offset(0, 2), 20, _bonk > .3 ? Face.dead : (ring ? Face.angry : Face.shocked), blush: false);
    c.restore();
    if (ring) {
      // ring lines
      for (final s in [-1.0, 1.0]) {
        for (var i = 0; i < 3; i++) {
          final a = -pi / 2 + s * (.6 + i * .3);
          final k = (_t * 6 + i * .3) % 1.0;
          D.line(c, o + Offset(cos(a), sin(a)) * (54 + k * 10), o + Offset(cos(a), sin(a)) * (66 + k * 10),
              D.withAlpha(Pal.ink, 1 - k), 4);
        }
      }
    }
  }
}
