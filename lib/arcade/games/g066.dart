import 'dart:ui' show PathFillType;

import '../engine/engine.dart';

/// No.066 Thread It! — the thread creeps toward a trembling needle; drag
/// up/down to line the tip up with the eye.
class G066 extends MiniGame {
  double _t = 0;
  double _tipX = 40;
  double _tipY = 320;
  double _targetY = 320;
  double _downY = 0;
  double _downTip = 0;
  double _eyeY = 320;
  late final double _phase;
  late final double _eyeH;
  int _state = 0; // 0 moving, 1 threaded, 2 bonk
  double _endT = 0;
  double _hitOff = 0;
  late final Color _thread;

  static const _needleX = 262.0;

  @override
  void init() {
    _phase = rand(0, pi * 2);
    _eyeH = 46 / pow(host.speed, .45);
    _thread = pick(const [Pal.red, Pal.pink, Pal.purple, Pal.orange]);
    _tipY = rand(180, 480);
    _targetY = _tipY;
    _eyeY = _eyePos(0);
  }

  double _eyePos(double t) {
    final sp = host.speed;
    return 320 +
        sin(t * 1.25 * sp + _phase) * 95 * sqrt(sp) +
        sin(t * 3.7 * sp + _phase * 2) * 22 +
        sin(t * 23) * 2.5; // hand tremble
  }

  @override
  void update(double dt) {
    _t += dt;
    if (_state == 0) {
      _eyeY = _eyePos(host.time);
      _tipY = M.approach(_tipY, _targetY, 18, dt) + sin(_t * 9) * .3;
      _tipX = 40 + host.time * 74 * host.speed;
      if (_tipX >= _needleX - 12) {
        final off = _tipY - _eyeY;
        if (off.abs() <= _eyeH / 2 - 5) {
          _state = 1;
          _hitOff = off;
          host.sfx(Sfx.swipe, rate: 1.4);
          host.sfx(Sfx.perfect);
          host.shake(4);
          host.punch(.05);
          host.fx.sparkle(Offset(_needleX, _eyeY), count: 18, radius: 50, color: Pal.yellow);
          host.fx.ring(Offset(_needleX, _eyeY), Pal.white, size: 90);
          host.fx.burst(Offset(_needleX, _eyeY), Pal.gold, count: 14, speed: 240, shape: PartShape.star);
          final stars = off.abs() < 6 ? 3 : (off.abs() < _eyeH / 2 - 12 ? 2 : 1);
          host.fx.pop(stars == 3 ? host.tr('perfect', 'PERFECT!') : host.tr('nice', 'NICE!'),
              Offset(180, _eyeY - 90 < 120 ? _eyeY + 100 : _eyeY - 90), color: Pal.lime, size: 38);
          host.win(stars: stars);
        } else {
          _state = 2;
          _tipX = _needleX - 12;
          host.sfx(Sfx.clang, rate: 1.3);
          host.sfx(Sfx.boing, volume: .7);
          host.shake(7);
          host.flash(Pal.red, .12);
          host.fx.burst(Offset(_needleX - 12, _tipY), Pal.white, count: 10, speed: 200, shape: PartShape.star);
          host.fx.pop(host.tr('miss', 'MISS'), Offset(160, _tipY - 60), color: Pal.red, size: 36);
          host.lose();
        }
      }
    } else {
      _endT += dt;
      if (_state == 1) {
        _tipX = min(345, _tipX + dt * 260);
        _tipY = _eyeY + _hitOff;
      }
    }
  }

  @override
  void onDown(Offset p) {
    _downY = p.dy;
    _downTip = _targetY;
  }

  @override
  void onMove(Offset p) {
    _targetY = (_downTip + (p.dy - _downY) * 1.1).clamp(90, 590);
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'up') _targetY = (_targetY - 30).clamp(90, 590);
    if (key == 'down') _targetY = (_targetY + 30).clamp(90, 590);
  }

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF7B3FE4), Color(0xFFE85AB8), Color(0xFFFFA86B)]);
    D.rays(c, Offset(_needleX, _eyeY), 800, const Color(0x1CFFFFFF), count: 20, t: _t * .3);
    // polka dots like a sewing box lining
    final dp = D.fill(const Color(0x1AFFFFFF));
    for (var y = 60.0; y < 640; y += 46) {
      for (var x = ((y ~/ 46).isEven ? 12.0 : 35.0); x < 360; x += 46) {
        c.drawCircle(Offset(x, y), 7, dp);
      }
    }

    // target glow on the eye
    if (_state == 0) {
      final pulse = M.wave(_t, 2);
      c.drawOval(Rect.fromCenter(center: Offset(_needleX, _eyeY), width: 60 + pulse * 16, height: _eyeH + 40 + pulse * 16),
          D.fill(const Color(0x33FFF3A0)));
    }

    _drawNeedle(c);
    _drawThread(c);
    _drawGranny(c);

    // aim line from tip
    if (_state == 0) {
      final gp = Paint()..color = const Color(0x66FFFFFF);
      for (var x = _tipX + 20; x < _needleX - 14; x += 16) {
        c.drawCircle(Offset(x, _tipY), 2.5, gp);
      }
    }

    if (host.time < 1.8 && _state == 0) {
      D.arrow(c, Offset(_tipX + 20, _tipY - 60), const Offset(0, -1), 44, Pal.yellow);
      D.arrow(c, Offset(_tipX + 20, _tipY + 60), const Offset(0, 1), 44, Pal.yellow);
      D.hand(c, Offset(_tipX + 60, _tipY + 20), _t);
      D.text(c, host.tr('drag', 'DRAG!'), Offset(_tipX + 90, _tipY - 40), size: 22, stroke: Pal.ink);
    }
  }

  void _drawNeedle(Canvas c) {
    final ey = _eyeY;
    final shock = _state == 2 ? sin(_endT * 50) * 3 * max(0, 1 - _endT * 2) : 0.0;
    c.save();
    c.translate(shock, 0);
    const hw = 11.0;
    final eye = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(_needleX, ey), width: 10, height: _eyeH), const Radius.circular(5));
    final body = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(_needleX - hw, ey - _eyeH / 2 - 30)
      ..quadraticBezierTo(_needleX - hw, ey - _eyeH / 2 - 30 - hw * 1.6, _needleX, ey - _eyeH / 2 - 30 - hw * 1.6)
      ..quadraticBezierTo(_needleX + hw, ey - _eyeH / 2 - 30 - hw * 1.6, _needleX + hw, ey - _eyeH / 2 - 30)
      ..lineTo(_needleX + hw * .8, ey + 360)
      ..lineTo(_needleX, ey + 430)
      ..lineTo(_needleX - hw * .8, ey + 360)
      ..close()
      ..addRRect(eye);
    c.drawPath(body.shift(const Offset(6, 6)), D.fill(const Color(0x33000000)));
    final r = Rect.fromLTWH(_needleX - hw, ey - 200, hw * 2, 700);
    c.drawPath(
        body,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFF8E97AE), Color(0xFFFFFFFF), Color(0xFFB8C0D4), Color(0xFF6A728A)],
                  stops: [0, .35, .6, 1])
              .createShader(r));
    c.drawPath(body, D.stroke(Pal.ink, 4));
    c.restore();
    // pinching fingers from the top holding the needle
    final hy = ey - _eyeH / 2 - 60;
    for (final s in [-1.0, 1.0]) {
      final tip = Offset(_needleX + s * (hw + 8) + shock, hy - 20);
      final base = Offset(_needleX + s * 60, hy - 170);
      D.line(c, base, tip, Pal.ink, 36);
      D.line(c, base, tip, Pal.skin, 28);
      c.drawOval(Rect.fromCenter(center: tip + Offset(-s * 2, -8), width: 16, height: 20), D.fill(const Color(0xFFFFE9E0)));
      c.drawOval(Rect.fromCenter(center: tip + Offset(-s * 2, -8), width: 16, height: 20), D.stroke(Pal.ink, 2));
    }
    // tremble lines
    if (_state == 0) {
      for (final s in [-1.0, 1.0]) {
        final x = _needleX + s * 60;
        final y = hy - 30;
        D.line(c, Offset(x, y), Offset(x + s * 10, y - 6), Pal.white, 3);
        D.line(c, Offset(x + s * 2, y + 12), Offset(x + s * 12, y + 8), Pal.white, 3);
      }
    }
  }

  void _drawThread(Canvas c) {
    const spool = Offset(-10, 600);
    final tip = Offset(_tipX, _tipY);
    final ctrl = Offset((spool.dx + tip.dx) / 2, max(spool.dy, tip.dy) + 40);
    final path = Path()
      ..moveTo(spool.dx, spool.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx - 10, tip.dy);
    path.lineTo(tip.dx, tip.dy);
    c.drawPath(path, D.stroke(Pal.ink, 9));
    c.drawPath(path, D.stroke(_thread, 5));
    // tip: stiff waxed end, or frayed after bonk
    if (_state == 2) {
      for (var i = 0; i < 5; i++) {
        final a = pi + (i - 2) * .5 + sin(_endT * 20 + i) * .1;
        D.line(c, tip, tip + Offset(cos(a) * -14, sin(a) * 14), _thread, 3);
      }
      c.drawCircle(tip, 5, D.fill(_thread));
    } else {
      c.drawCircle(tip, 6, D.fill(Pal.ink));
      c.drawCircle(tip, 4, D.fill(Color.lerp(_thread, Pal.white, .3)!));
    }
    // spool
    D.rrect(c, const Rect.fromLTWH(-30, 560, 60, 80), 8, _thread, border: Pal.ink, borderWidth: 4);
    for (var y = 572.0; y < 640; y += 9) {
      D.line(c, Offset(-26, y), Offset(26, y), Color.lerp(_thread, Pal.ink, .3)!, 2);
    }
    D.rrect(c, const Rect.fromLTWH(-36, 552, 72, 14), 4, const Color(0xFFE0B070), border: Pal.ink, borderWidth: 3);
  }

  void _drawGranny(Canvas c) {
    // granny peeking from the bottom-right, squinting hard
    const o = Offset(300, 590);
    c.drawCircle(o, 64, D.fill(Pal.skin));
    // bun of white hair
    c.drawCircle(o + const Offset(10, -66), 26, D.fill(const Color(0xFFEDEDF5)));
    c.drawCircle(o + const Offset(10, -66), 26, D.stroke(Pal.ink, 4));
    final hair = Path()
      ..addArc(Rect.fromCircle(center: o, radius: 64), pi * 1.05, pi * .9)
      ..close();
    c.drawPath(hair, D.fill(const Color(0xFFEDEDF5)));
    c.drawCircle(o, 64, D.stroke(Pal.ink, 4));
    final won = _state == 1;
    final lost = _state == 2;
    for (final sx in [-1.0, 1.0]) {
      final e = o + Offset(sx * 24 - 8, 4);
      // big glasses
      c.drawCircle(e, 20, D.fill(const Color(0x55BFE8FF)));
      c.drawCircle(e, 20, D.stroke(Pal.ink, 4));
      if (won) {
        c.drawArc(Rect.fromCenter(center: e + const Offset(0, 3), width: 18, height: 14), pi, pi, false, D.stroke(Pal.ink, 3.5));
      } else if (lost) {
        D.line(c, e + const Offset(-7, -7), e + const Offset(7, 7), Pal.ink, 3.5);
        D.line(c, e + const Offset(7, -7), e + const Offset(-7, 7), Pal.ink, 3.5);
      } else {
        // squint: the closer the thread, the tighter
        final k = M.clamp01((_tipX - 40) / (_needleX - 40));
        D.line(c, e + Offset(-9, -2 + k * 2), e + Offset(9, 2 - k * 2), Pal.ink, 4);
      }
    }
    D.line(c, o + const Offset(-12, 4), o + const Offset(-4, 4), Pal.ink, 3);
    if (won) {
      final m = Path()
        ..moveTo(o.dx - 22, o.dy + 30)
        ..quadraticBezierTo(o.dx - 8, o.dy + 50, o.dx + 6, o.dy + 30)
        ..close();
      c.drawPath(m, D.fill(const Color(0xFF8B1E3F)));
      c.drawPath(m, D.stroke(Pal.ink, 3));
    } else {
      c.drawOval(Rect.fromCenter(center: o + const Offset(-8, 36), width: lost ? 24 : 14, height: lost ? 20 : 6),
          D.fill(const Color(0xFF7A1F2B)));
    }
    // tongue out in concentration
    if (_state == 0) {
      c.drawOval(Rect.fromCenter(center: o + const Offset(-2, 42), width: 10, height: 10), D.fill(const Color(0xFFFF7A9A)));
    }
    if (_state == 0 && host.time > 1.5) {
      final sd = o + Offset(-60, -40 + (_t * 40) % 20);
      c.drawCircle(sd, 5, D.fill(const Color(0xFF7FD3FF)));
    }
  }
}
