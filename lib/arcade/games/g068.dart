import '../engine/engine.dart';

/// No.068 Hammer It! — the hammer swings like a pendulum; tap when it's over
/// the nail. 3 good hits drive it home. Too early = your thumb.
class G068 extends MiniGame {
  double _t = 0;
  double _swingT = 0;
  double _amp = .44;
  late final double _phase0;
  int _hits = 0;
  int _perfects = 0;
  // strike animation
  double _strike = -1; // <0 idle, else seconds since tap
  double _strikeX = 0;
  bool _resolvedStrike = false;
  bool _thumb = false;
  bool _done = false;
  double _endT = 0;
  double _nailBounce = 0;
  final List<Offset> _dents = [];

  static const _pivot = Offset(180, -150);
  static const _len = 350.0;
  static const _nailX = 180.0;
  static const _boardY = 478.0;
  static const _nailLen = 96.0;

  double get _nailTop => _boardY - _nailLen * (1 - _hits / 3) - 2;

  @override
  void init() {
    _phase0 = chance(.5) ? pi / 2 : -pi / 2; // start at an extreme
  }

  double get _omega => 2 * pi / 1.2 * pow(host.speed, .7);
  double get _angle => _amp * sin(_swingT * _omega + _phase0);
  Offset get _swingHead => _pivot + Offset(sin(_angle) * _len, cos(_angle) * _len);

  // Current head (face bottom center) position, including strike motion.
  Offset get _head {
    if (_strike < 0) return _swingHead;
    final sdx = _strikeX - _pivot.dx;
    final from = Offset(_strikeX, _pivot.dy + sqrt(max(0.0, _len * _len - sdx * sdx)));
    final dxs = _strikeX - _nailX;
    final target = Offset(dxs < -20 && dxs > -80 ? _nailX - 26 : _strikeX, _impactY);
    if (_strike < .07) return Offset.lerp(from, target, M.clamp01(_strike / .07))!;
    if (_strike < .2 || _thumb) return target;
    return Offset.lerp(target, from, M.clamp01((_strike - .2) / .15))!;
  }

  double get _impactY {
    final dx = _strikeX - _nailX;
    if (dx.abs() <= 20) return _nailTop;
    if (dx < 0 && dx > -80) return _boardY - 60; // thumb height
    return _boardY;
  }

  @override
  void update(double dt) {
    _t += dt;
    _nailBounce = M.approach(_nailBounce, 0, 10, dt);
    if (_done || _thumb) _endT += dt;
    if (_strike >= 0) {
      _strike += dt;
      if (!_resolvedStrike && _strike >= .07) {
        _resolvedStrike = true;
        _impact();
      }
      if (_strike > .35 && !_thumb) _strike = -1;
    } else if (!_done && !_thumb) {
      _swingT += dt;
    }
  }

  void _impact() {
    final dx = _strikeX - _nailX;
    final at = Offset(dx < -20 && dx > -80 ? _nailX - 26 : _strikeX, _impactY);
    if (dx.abs() <= 20) {
      _hits++;
      final perfect = dx.abs() <= 8;
      if (perfect) _perfects++;
      _nailBounce = 1;
      host.sfx(Sfx.hammer, rate: 1 + _hits * .1);
      host.sfx(Sfx.clang, volume: .5, rate: 1.2 + _hits * .1);
      host.shake(6 + _hits * 2.0);
      host.hitStop(.05);
      host.punch(.03 + _hits * .01);
      host.fx.burst(at, Pal.yellow, count: 10, speed: 260, shape: PartShape.star);
      host.fx.burst(Offset(_nailX, _boardY), const Color(0xFFD9954A), count: 6, speed: 160, shape: PartShape.square, gravity: 700);
      host.fx.ring(at, Pal.white, size: 60);
      host.fx.pop(perfect ? host.tr('perfect', 'PERFECT!') : host.tr('good', 'GOOD!'), at + const Offset(0, -80),
          color: perfect ? Pal.lime : Pal.yellow, size: 30);
      _amp = min(.62, _amp + .06);
      if (_hits >= 3) {
        _done = true;
        host.sfx(Sfx.ding);
        host.sfx(Sfx.correct, volume: .8);
        host.fx.sparkle(Offset(_nailX, _boardY - 6), count: 16, radius: 40, color: Pal.white);
        host.win(stars: _perfects >= 2 ? 3 : (_perfects == 1 ? 2 : 1));
      }
    } else if (dx < 0 && dx > -80) {
      _thumb = true;
      host.sfx(Sfx.punch);
      host.sfx(Sfx.hurt);
      host.shake(14);
      host.flash(Pal.red, .2);
      host.hitStop(.12);
      host.fx.burst(at, Pal.red, count: 10, speed: 220, shape: PartShape.star);
      host.fx.pop(host.tr('ouch', 'OUCH!'), const Offset(120, 300), color: Pal.red, size: 44);
      host.lose();
    } else {
      _dents.add(Offset(_strikeX, _boardY + 4));
      host.sfx(Sfx.thud);
      host.shake(5);
      host.fx.burst(Offset(_strikeX, _boardY), const Color(0xFFD9954A), count: 8, speed: 180, shape: PartShape.square, gravity: 700);
      host.fx.pop(host.tr('miss', 'MISS'), Offset(_strikeX, _boardY - 90), color: Pal.white, size: 26);
    }
  }

  @override
  void onDown(Offset p) {
    if (_strike >= 0 || _done || _thumb) return;
    _strike = 0;
    _resolvedStrike = false;
    _strikeX = _swingHead.dx;
    host.sfx(Sfx.swing, rate: 1.2);
  }

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action') onDown(Offset.zero);
  }

  @override
  void onTimeUp() {
    host.sfx(Sfx.aww);
    host.lose();
  }

  @override
  void render(Canvas c) {
    // workshop wall
    D.gradientBg(c, const [Color(0xFFFFC76B), Color(0xFFFF7A45)]);
    D.rays(c, Offset(_nailX, _boardY - 60), 700, const Color(0x22FFFFFF), count: 18, t: _t * .3);
    // pegboard holes
    final hp = D.fill(const Color(0x22000000));
    for (var y = 60.0; y < 440; y += 28) {
      for (var x = 14.0; x < 360; x += 28) {
        c.drawCircle(Offset(x, y), 3, hp);
      }
    }
    // tool silhouettes on the pegboard
    final sil = D.fill(const Color(0x33000000));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(24, 90, 14, 90), const Radius.circular(4)), sil);
    c.drawCircle(const Offset(31, 90), 16, sil);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(310, 110, 12, 100), const Radius.circular(4)), sil);
    c.drawRect(const Rect.fromLTWH(296, 100, 40, 18), sil);

    // swing arc guide
    if (!_done && !_thumb) {
      final gp = Paint()..color = const Color(0x55FFFFFF);
      for (var a = -_amp; a <= _amp; a += .05) {
        c.drawCircle(_pivot + Offset(sin(a) * _len, cos(a) * _len) + const Offset(0, 16), 3, gp);
      }
      // target zone marker
      final tz = _pivot + Offset(0, _len + 16);
      c.drawCircle(tz, 12, D.fill(Pal.lime.withValues(alpha: .5 + .4 * M.wave(_t, 3))));
      c.drawCircle(tz, 12, D.stroke(Pal.ink, 3));
    }

    // workbench
    c.drawRect(const Rect.fromLTWH(0, _boardY + 50, 360, 200), D.fill(const Color(0xFF6A3A1A)));
    D.line(c, const Offset(0, _boardY + 50), const Offset(360, _boardY + 50), Pal.ink, 4);
    for (var i = 0; i < 3; i++) {
      final y = _boardY + 84 + i * 34.0;
      D.line(c, Offset(0, y), Offset(360, y), const Color(0x55000000), 3);
      for (final x in [30.0, 330.0]) {
        c.drawCircle(Offset(x, y - 17), 4, D.fill(const Color(0xFF3A2010)));
      }
    }
    // cheering / wincing crowd of screws in a jar
    D.rrect(c, const Rect.fromLTWH(262, _boardY + 70, 70, 80), 12, const Color(0x88BFE8FF), border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < 6; i++) {
      c.drawCircle(Offset(278 + (i % 3) * 18.0, _boardY + 128 - (i ~/ 3) * 18.0), 7, D.fill(const Color(0xFFB0B6C8)));
    }
    D.face(c, const Offset(297, _boardY + 104), 22, _thumb ? Face.shocked : (_done ? Face.happy : Face.neutral), blush: false);
    // board
    final board = Rect.fromLTWH(20, _boardY, 320, 50);
    D.rrect(c, board, 6, const Color(0xFFE8B070), border: Pal.ink, borderWidth: 4);
    for (var i = 0; i < 3; i++) {
      final y = _boardY + 12 + i * 12.0;
      c.drawPath(
          Path()
            ..moveTo(30, y)
            ..quadraticBezierTo(120, y - 6, 200, y + 2)
            ..quadraticBezierTo(270, y + 8, 330, y),
          D.stroke(const Color(0x55A0602E), 2.5));
    }
    c.drawOval(const Rect.fromLTWH(250, _boardY + 14, 30, 16), D.stroke(const Color(0x77A0602E), 3));
    for (final d in _dents) {
      c.drawOval(Rect.fromCenter(center: d, width: 40, height: 10), D.fill(const Color(0x66704010)));
    }

    _drawNail(c);
    _drawHand(c);
    _drawHammer(c);

    // hit counter
    for (var i = 0; i < 3; i++) {
      final p = Offset(140 + i * 40.0, 70);
      D.circle(c, p, 14, i < _hits ? Pal.lime : const Color(0x55000000), border: Pal.ink, borderWidth: 3);
      if (i < _hits) D.star(c, p, 9, Pal.white);
    }

    if (host.time < 1.8 && !_done && !_thumb && _hits == 0) {
      D.hand(c, const Offset(250, 420), _t);
      D.text(c, host.tr('tap', 'TAP!'), const Offset(270, 360), size: 24, stroke: Pal.ink);
    }
  }

  void _drawNail(Canvas c) {
    final top = _nailTop + sin(_nailBounce * pi) * 3;
    // shaft
    final shaft = Path()
      ..moveTo(_nailX - 5, top + 6)
      ..lineTo(_nailX + 5, top + 6)
      ..lineTo(_nailX + 4, _boardY)
      ..lineTo(_nailX - 4, _boardY)
      ..close();
    c.drawPath(shaft, D.fill(const Color(0xFFC8CED8)));
    c.drawPath(shaft, D.stroke(Pal.ink, 3));
    c.drawLine(Offset(_nailX - 2, top + 8), Offset(_nailX - 2, _boardY - 2), D.stroke(const Color(0xAAFFFFFF), 2));
    // head
    D.rrect(c, Rect.fromCenter(center: Offset(_nailX, top + 3), width: 34, height: 10), 4, const Color(0xFFD9DEE8),
        border: Pal.ink, borderWidth: 3);
    if (_done) {
      final k = M.wave(_t, 3);
      D.star(c, Offset(_nailX + 22, top - 10), 10 + k * 5, Pal.white, border: Pal.yellow);
    }
  }

  void _drawHand(Canvas c) {
    // arm from the left holding the nail
    final swell = _thumb ? min(1.0, _endT * 5) : 0.0;
    final throb = _thumb ? 1 + sin(_endT * 16) * .06 : 1.0;
    const fist = Offset(_nailX - 58, _boardY - 26);
    D.line(c, const Offset(-30, _boardY + 30), fist + const Offset(-20, 6), Pal.ink, 46);
    D.line(c, const Offset(-30, _boardY + 30), fist + const Offset(-20, 6), const Color(0xFF3FB86B), 38);
    // plaid stripes on sleeve
    D.line(c, const Offset(-10, _boardY + 26), fist + const Offset(-40, 14), const Color(0x44FFFFFF), 6);
    c.drawOval(Rect.fromCenter(center: fist, width: 64, height: 52), D.fill(Pal.skin));
    c.drawOval(Rect.fromCenter(center: fist, width: 64, height: 52), D.stroke(Pal.ink, 4));
    for (var i = 0; i < 3; i++) {
      c.drawArc(Rect.fromCenter(center: fist + Offset(8, -10 + i * 12.0), width: 30, height: 12), -pi / 2, pi, false,
          D.stroke(Pal.ink, 2.5));
    }
    // thumb pinching the nail
    final tc = Offset(_nailX - 24, _boardY - 58);
    final tw = 34 * (1 + swell * 1.3) * throb;
    final th = 22 * (1 + swell * 1.3) * throb;
    c.save();
    c.translate(tc.dx, tc.dy);
    c.rotate(-.3);
    final col = Color.lerp(Pal.skin, const Color(0xFFFF3050), swell)!;
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: tw, height: th), D.fill(col));
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: tw, height: th), D.stroke(Pal.ink, 4));
    c.drawOval(Rect.fromCenter(center: Offset(tw * .28, 0), width: tw * .3, height: th * .6),
        D.fill(Color.lerp(const Color(0xFFFFE9E0), const Color(0xFFFF8090), swell)!));
    c.restore();
    if (_thumb) {
      // throb lines + orbiting stars
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3 + .3;
        final r0 = 40 + swell * 20 + sin(_endT * 16) * 4;
        D.line(c, tc + Offset(cos(a) * r0, sin(a) * r0), tc + Offset(cos(a) * (r0 + 16), sin(a) * (r0 + 16)), Pal.red, 5);
      }
      for (var i = 0; i < 3; i++) {
        final a = _endT * 6 + i * pi * 2 / 3;
        D.star(c, tc + Offset(cos(a) * 60, -50 + sin(a) * 14), 10, Pal.yellow, border: Pal.ink);
      }
    }
  }

  void _drawHammer(Canvas c) {
    final h = _head;
    final grip = _strike >= 0 ? Offset(h.dx, h.dy - 230) : _pivot + (h - _pivot) * .35;
    // handle
    final dir = (h - grip);
    final n = dir / max(dir.distance, 1);
    final neck = h - n * 60;
    D.line(c, grip, neck, Pal.ink, 22);
    D.line(c, grip, neck, const Color(0xFFD9954A), 15);
    D.line(c, grip + Offset(-n.dy, n.dx) * 3, neck + Offset(-n.dy, n.dx) * 3, const Color(0x55FFFFFF), 4);
    // rubber grip at top
    D.line(c, grip, grip + n * 70, Pal.ink, 26);
    D.line(c, grip, grip + n * 70, Pal.red, 19);
    // head: steel block with face at the bottom
    final ang = atan2(n.dx, n.dy);
    c.save();
    c.translate(h.dx, h.dy);
    c.rotate(-ang);
    const head = Rect.fromLTWH(-26, -66, 52, 66);
    D.rrect(c, head.shift(const Offset(4, 5)), 8, const Color(0x44000000));
    c.drawRRect(RRect.fromRectAndRadius(head, const Radius.circular(8)),
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFF6A728A), Color(0xFFE8ECF4), Color(0xFF8E97AE)],
                  stops: [0, .4, 1])
              .createShader(head));
    c.drawRRect(RRect.fromRectAndRadius(head, const Radius.circular(8)), D.stroke(Pal.ink, 4));
    D.rrect(c, const Rect.fromLTWH(-30, -12, 60, 12), 4, const Color(0xFF4A5064), border: Pal.ink, borderWidth: 3.5);
    // claw sticking up
    c.drawPath(
        Path()
          ..moveTo(-20, -66)
          ..quadraticBezierTo(-34, -86, -18, -100)
          ..lineTo(-10, -66)
          ..close(),
        D.fill(const Color(0xFF8E97AE)));
    c.restore();
    // motion lines while swinging fast
    if (_strike < 0 && !_done && !_thumb) {
      final v = cos(_swingT * _omega + _phase0);
      if (v.abs() > .6) {
        for (var i = 0; i < 3; i++) {
          final y = h.dy - 50 + i * 18.0;
          final x = h.dx - v.sign * 40;
          D.line(c, Offset(x, y), Offset(x - v.sign * 26, y), Pal.white, 4);
        }
      }
    }
  }
}
