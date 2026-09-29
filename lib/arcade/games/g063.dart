import '../engine/engine.dart';

/// No.063 Catch the Phone! — the phone slips, pinballs off stuff, catch it.
class G063 extends MiniGame {
  double _t = 0;
  double _handsX = 180;
  double _targetX = 180;
  double _handsSquash = 0;
  Offset _pos = const Offset(0, 0);
  Offset _vel = Offset.zero;
  double _rot = 0;
  double _spin = 0;
  bool _falling = false;
  double _slipT = 0; // wobble before slipping
  bool _resolved = false;
  bool _caught = false;
  double _endT = 0;
  double _catchOffset = 0;
  final List<_Bumper> _bumpers = [];
  late final double _dropX;
  late final Color _case;

  static const _catchY = 548.0;
  static const _floorY = 598.0;

  @override
  void init() {
    _dropX = rand(100, 260);
    _pos = Offset(_dropX, 108);
    _case = pick(const [Pal.pink, Pal.teal, Pal.purple, Pal.orange, Pal.lime]);
    _slipT = rand(.25, .45);
    // Three bumpers in staggered rows; one sits roughly under the drop.
    const kinds = [0, 1, 2];
    final order = [...kinds]..shuffle(host.rng);
    final rows = [250.0, 350.0, 450.0];
    for (var i = 0; i < 3; i++) {
      double x;
      if (i == 0) {
        x = _dropX + rand(-30, 30);
      } else {
        x = rand(60, 300);
        final prev = _bumpers[i - 1].pos.dx;
        if ((x - prev).abs() < 70) x = prev + (x < prev ? -90 : 90);
      }
      _bumpers.add(_Bumper(Offset(x.clamp(55, 305), rows[i]), order[i]));
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    final sp = host.speed;
    if (!_resolved) {
      _handsX = M.approach(_handsX, _targetX, 16, dt);
    }
    _handsSquash = M.approach(_handsSquash, 0, 8, dt);
    for (final b in _bumpers) {
      b.hit = M.approach(b.hit, 0, 6, dt);
    }
    if (!_falling && !_resolved) {
      if (host.time > _slipT / sp) {
        _falling = true;
        _vel = Offset(rand(-40, 40), -60);
        _spin = rand(4, 7) * (chance(.5) ? 1 : -1);
        host.sfx(Sfx.whoosh, rate: .8);
      }
      return;
    }
    if (_resolved) {
      _endT += dt;
      if (_caught) {
        _pos = Offset(_handsX + _catchOffset, _catchY - 20);
        _rot = M.approach(_rot, 0, 12, dt);
      }
      return;
    }
    final g = 520.0 * sp;
    _vel += Offset(0, g * dt);
    _pos += _vel * dt;
    _rot += _spin * dt;
    // walls
    if (_pos.dx < 26 || _pos.dx > 334) {
      _vel = Offset(-_vel.dx * .8, _vel.dy);
      _pos = Offset(_pos.dx.clamp(26, 334), _pos.dy);
      host.sfx(Sfx.bounce, volume: .6);
    }
    // bumpers
    for (final b in _bumpers) {
      final d = _pos - b.pos;
      final dist = d.distance;
      const rr = 54.0;
      if (dist < rr && dist > 0) {
        final n = d / dist;
        final vn = _vel.dx * n.dx + _vel.dy * n.dy;
        if (vn < 0) {
          _vel = _vel - n * (vn * 1.75);
          // kick so it always travels sideways a bit
          final side = n.dx.abs() < .25 ? (chance(.5) ? 1.0 : -1.0) : n.dx.sign;
          _vel = Offset(_vel.dx + side * rand(60, 130) * sp, min(_vel.dy, -120.0 * sqrt(sp)));
          _spin = -_spin * 1.2 + rand(-3, 3);
          b.hit = 1;
          host.sfx(b.kind == 1 ? Sfx.squish : Sfx.boing, rate: rand(.9, 1.2));
          host.fx.ring(b.pos, Pal.white, size: 50);
          host.fx.burst(b.pos + n * 30, Pal.yellow, count: 6, speed: 160);
        }
        _pos = b.pos + n * rr;
      }
    }
    // catch?
    if (_vel.dy > 0 && _pos.dy >= _catchY - 24 && _pos.dy - _vel.dy * dt < _catchY - 24) {
      final off = _pos.dx - _handsX;
      if (off.abs() < 58) {
        _resolved = true;
        _caught = true;
        _catchOffset = off * .4;
        _handsSquash = 1;
        host.sfx(Sfx.pickup);
        host.sfx(Sfx.correct, volume: .8);
        host.shake(4);
        host.punch(.05);
        host.fx.sparkle(Offset(_handsX, _catchY - 30), count: 14, radius: 50, color: Pal.yellow);
        host.fx.burst(Offset(_handsX, _catchY - 30), Pal.pink, count: 10, speed: 200);
        final stars = off.abs() < 20 ? 3 : (off.abs() < 40 ? 2 : 1);
        host.fx.pop(stars == 3 ? host.tr('perfect', 'PERFECT!') : host.tr('safe', 'SAFE!'),
            Offset(_handsX, 400), color: Pal.lime, size: 36);
        host.win(stars: stars);
        return;
      }
    }
    if (_pos.dy >= _floorY - 44) {
      _pos = Offset(_pos.dx, _floorY - 44);
      _resolved = true;
      _caught = false;
      _rot = pi / 2 * (chance(.5) ? 1 : -1) + rand(-.08, .08); // lies on its side
      host.sfx(Sfx.glass);
      host.sfx(Sfx.crack, volume: .9);
      host.shake(10);
      host.flash(Pal.white, .12);
      host.hitStop(.1);
      host.fx.burst(_pos, const Color(0xFFBFE8FF), count: 18, speed: 260, shape: PartShape.square, size: 5);
      host.fx.pop(host.tr('oops', 'OOPS!'), Offset(_pos.dx.clamp(70, 290), 470), color: Pal.red, size: 36);
      host.lose();
    }
  }

  @override
  void onDown(Offset p) => _targetX = p.dx.clamp(50, 310);
  @override
  void onMove(Offset p) => _targetX = p.dx.clamp(50, 310);

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'left') _targetX = (_targetX - 60).clamp(50, 310);
    if (key == 'right') _targetX = (_targetX + 60).clamp(50, 310);
  }

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF6FD6FF), Color(0xFFB98CFF), Color(0xFFFF8CC6)]);
    D.rays(c, const Offset(180, 330), 700, const Color(0x1FFFFFFF), count: 20, t: _t * .3);
    // floor
    c.drawRect(const Rect.fromLTWH(0, 598, 360, 42), D.fill(const Color(0xFFE7B07A)));
    for (var x = -20.0; x < 380; x += 48) {
      D.line(c, Offset(x, 598), Offset(x - 20, 640), const Color(0x55A0602E), 3);
    }
    D.line(c, const Offset(0, 598), const Offset(360, 598), Pal.ink, 4);

    // owner at the top: arm + shocked face
    _drawOwner(c);

    // bumpers
    for (final b in _bumpers) {
      _drawBumper(c, b);
    }

    // landing shadow
    if (_falling && !_resolved) {
      final k = M.clamp01((_pos.dy - 150) / 400);
      D.shadow(c, Offset(_pos.dx, 604), 30 + k * 30, 8, .15 + k * .2);
      // predicted drop dotted guide
      final gp = Paint()..color = const Color(0x55FFFFFF);
      for (var y = _pos.dy + 50; y < 590; y += 18) {
        c.drawCircle(Offset(_pos.dx, y), 2.5, gp);
      }
    }

    _drawHands(c, back: true);
    _drawPhone(c);
    _drawHands(c, back: false);

    if (host.time < 1.8 && !_resolved) {
      D.hand(c, Offset(_handsX + 40, 590), _t, size: 38);
      D.arrow(c, Offset(_handsX - 70, 590), const Offset(-1, 0), 40, Pal.yellow);
      D.arrow(c, Offset(_handsX + 110, 590), const Offset(1, 0), 40, Pal.yellow);
      D.text(c, host.tr('drag', 'DRAG!'), Offset(_handsX, 500), size: 22, stroke: Pal.ink);
    }
  }

  void _drawOwner(Canvas c) {
    // face peeking top-left
    final fo = Offset(_dropX < 180 ? 300 : 60, 92);
    final shocked = _falling || _resolved;
    final f = _resolved ? (_caught ? Face.love : Face.cry) : (shocked ? Face.shocked : Face.happy);
    D.blob(c, fo, 34, const Color(0xFFFFD1A6), face: f, look: Offset(((_pos.dx - fo.dx) / 120).clamp(-1, 1), 1));
    if (shocked && !_resolved) {
      for (var i = 0; i < 3; i++) {
        final a = -pi / 2 + (i - 1) * .5;
        D.line(c, fo + Offset(cos(a) * 44, sin(a) * 44), fo + Offset(cos(a) * 58, sin(a) * 58), Pal.ink, 4);
      }
    }
    // arm reaching from top with the hand that dropped it
    final hand = Offset(_dropX, 92);
    D.line(c, Offset(_dropX - 30, 20), hand, Pal.ink, 30);
    D.line(c, Offset(_dropX - 30, 20), hand, const Color(0xFF3D6BFF), 22);
    final open = _falling ? 1.0 : M.clamp01(host.time / max(.01, _slipT / host.speed));
    c.drawCircle(hand + const Offset(0, 6), 18, D.fill(Pal.skin));
    c.drawCircle(hand + const Offset(0, 6), 18, D.stroke(Pal.ink, 4));
    for (var i = 0; i < 4; i++) {
      final a = pi / 2 + (i - 1.5) * .35 + (i < 2 ? -1 : 1) * open * .4;
      final from = hand + const Offset(0, 10);
      final to = from + Offset(cos(a) * 24, sin(a) * 24);
      D.line(c, from, to, Pal.ink, 11);
      D.line(c, from, to, Pal.skin, 6);
    }
    // butter fingers sweat
    if (!_falling) {
      final dy = (_t * 50) % 20;
      c.drawCircle(hand + Offset(26, 4 + dy), 4, D.fill(const Color(0xFF7FD3FF)));
    }
  }

  void _drawBumper(Canvas c, _Bumper b) {
    final s = 1 + b.hit * .25;
    c.save();
    c.translate(b.pos.dx, b.pos.dy);
    c.scale(s * (1 + b.hit * .1), s * (1 - b.hit * .15));
    switch (b.kind) {
      case 0: // basketball
        c.drawCircle(Offset.zero, 30, D.fill(Pal.orange));
        c.drawCircle(Offset.zero, 30, D.stroke(Pal.ink, 4));
        D.line(c, const Offset(-30, 0), const Offset(30, 0), Pal.ink, 2.5);
        D.line(c, const Offset(0, -30), const Offset(0, 30), Pal.ink, 2.5);
        c.drawArc(const Rect.fromLTWH(-50, -24, 40, 48), -.9, 1.8, false, D.stroke(Pal.ink, 2.5));
        c.drawArc(const Rect.fromLTWH(10, -24, 40, 48), pi - .9, 1.8, false, D.stroke(Pal.ink, 2.5));
        c.drawCircle(const Offset(-10, -12), 6, D.fill(const Color(0x55FFFFFF)));
      case 1: // cat
        final ear = Path()
          ..moveTo(-26, -12)
          ..lineTo(-20, -38)
          ..lineTo(-4, -26)
          ..moveTo(26, -12)
          ..lineTo(20, -38)
          ..lineTo(4, -26);
        c.drawPath(ear, D.fill(const Color(0xFFFFB347)));
        c.drawPath(ear, D.stroke(Pal.ink, 4));
        D.blob(c, Offset.zero, 30, const Color(0xFFFFB347),
            face: b.hit > .3 ? Face.angry : Face.smug, look: const Offset(0, -1));
        for (final sx in [-1.0, 1.0]) {
          D.line(c, Offset(sx * 16, 8), Offset(sx * 38, 4), Pal.ink, 2);
          D.line(c, Offset(sx * 16, 12), Offset(sx * 38, 14), Pal.ink, 2);
        }
      default: // donut
        c.drawCircle(Offset.zero, 30, D.fill(const Color(0xFFD9954A)));
        c.drawCircle(const Offset(0, -2), 26, D.fill(Pal.pink));
        const sprinkles = [Pal.yellow, Pal.sky, Pal.white, Pal.lime];
        for (var i = 0; i < 10; i++) {
          final a = i * .63;
          final r = 17 + (i % 2) * 4.0;
          final p = Offset(cos(a) * r, sin(a) * r - 2);
          D.line(c, p, p + Offset(cos(a + 1) * 5, sin(a + 1) * 5), sprinkles[i % 4], 3);
        }
        c.drawCircle(Offset.zero, 30, D.stroke(Pal.ink, 4));
        c.drawCircle(Offset.zero, 9, D.fill(const Color(0xFF9B7BE0)));
        c.drawCircle(Offset.zero, 9, D.stroke(Pal.ink, 3.5));
    }
    c.restore();
  }

  void _drawHands(Canvas c, {required bool back}) {
    final x = _handsX;
    final sq = _handsSquash;
    const y = _catchY;
    if (back) {
      // sleeves / arms from the bottom
      for (final s in [-1.0, 1.0]) {
        final from = Offset(x + s * 70, 660);
        final to = Offset(x + s * 42, y + 14);
        D.line(c, from, to, Pal.ink, 38);
        D.line(c, from, to, const Color(0xFFFFD23F), 30);
      }
      return;
    }
    // cupped palms
    final w = 128 * (1 + sq * .12);
    final h = 44 * (1 - sq * .25);
    final r = Rect.fromCenter(center: Offset(x, y + 10 + sq * 6), width: w, height: h);
    final cup = Path()
      ..moveTo(r.left, r.top)
      ..quadraticBezierTo(r.left - 4, r.bottom, r.center.dx, r.bottom)
      ..quadraticBezierTo(r.right + 4, r.bottom, r.right, r.top)
      ..quadraticBezierTo(r.center.dx, r.top + 16, r.left, r.top)
      ..close();
    c.drawPath(cup, D.fill(Pal.skin));
    c.drawPath(cup, D.stroke(Pal.ink, 4));
    // finger tips
    for (final s in [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        c.drawCircle(Offset(x + s * (w / 2 - 6), r.top + 2 + i * 9), 7, D.fill(Pal.skin));
        c.drawCircle(Offset(x + s * (w / 2 - 6), r.top + 2 + i * 9), 7, D.stroke(Pal.ink, 3));
      }
    }
    D.line(c, Offset(x, r.top + 14), Offset(x, r.bottom - 6), const Color(0x66B9784F), 3);
  }

  void _drawPhone(Canvas c) {
    c.save();
    c.translate(_pos.dx, _pos.dy);
    c.rotate(_rot);
    final double squash = _resolved && !_caught ? 1 + max(0.0, .4 - _endT) : 1.0;
    c.scale(squash, 1 / squash);
    const body = Rect.fromLTWH(-24, -42, 48, 84);
    D.rrect(c, body.shift(const Offset(3, 4)), 10, const Color(0x44000000));
    D.rrect(c, body, 10, _case, border: Pal.ink, borderWidth: 4);
    const screen = Rect.fromLTWH(-19, -36, 38, 70);
    {
      c.drawRRect(RRect.fromRectAndRadius(screen, const Radius.circular(6)),
          Paint()
            ..shader = const LinearGradient(
                    colors: [Color(0xFF2B2A6B), Color(0xFF3D6BFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                .createShader(screen));
      if (_caught) {
        final beat = 1 + .15 * sin(_endT * 14);
        D.heart(c, const Offset(0, 0), 26 * beat, Pal.red, border: Pal.white);
      } else if (_resolved) {
        _cracks(c, screen);
      } else {
        // app icons grid
        for (var i = 0; i < 6; i++) {
          final ip = Offset(-10 + (i % 2) * 20, -22 + (i ~/ 2) * 18);
          D.rrect(c, Rect.fromCenter(center: ip, width: 12, height: 12), 3, Pal.candy[(i * 3) % 8]);
        }
      }
      c.drawRect(const Rect.fromLTWH(-6, -40, 12, 3), D.fill(Pal.ink));
      // glare
      final gl = Path()
        ..moveTo(-19, -10)
        ..lineTo(-5, -36)
        ..lineTo(3, -36)
        ..lineTo(-19, 4)
        ..close();
      c.drawPath(gl, D.fill(const Color(0x33FFFFFF)));
    }
    c.restore();
  }

  void _cracks(Canvas c, Rect s) {
    const o = Offset(4, 6);
    final p = D.stroke(const Color(0xEEFFFFFF), 1.6);
    for (var i = 0; i < 9; i++) {
      final a = i * pi * 2 / 9 + .3;
      final e1 = o + Offset(cos(a) * 14, sin(a) * 14);
      final e2 = e1 + Offset(cos(a + .4) * 16, sin(a + .4) * 20);
      final e3 = e2 + Offset(cos(a - .3) * 20, sin(a - .3) * 26);
      c.drawLine(o, e1, p);
      c.drawLine(e1, e2, p);
      c.drawLine(e2, e3, p);
    }
    c.drawCircle(o, 8, p);
    c.drawCircle(o, 17, D.stroke(const Color(0x99FFFFFF), 1.2));
    c.drawCircle(o, 3, D.fill(Pal.white));
  }
}

class _Bumper {
  _Bumper(this.pos, this.kind);
  final Offset pos;
  final int kind;
  double hit = 0;
}
