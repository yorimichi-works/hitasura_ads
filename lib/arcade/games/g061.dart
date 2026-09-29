import '../engine/engine.dart';

/// No.061 Pick It! — WarioWare-style: thrust the finger into the nostril.
class G061 extends MiniGame {
  double _t = 0;
  double _fingerX = 180;
  double _fingerDir = 1;
  double _thrust = 0; // 0..1 extension
  bool _thrusting = false;
  bool _resolved = false;
  bool _success = false;
  double _noseX = 180;
  double _noseDrift = 0;
  double _react = 0;
  late final double _skinHue;
  late final Color _hair;

  @override
  void init() {
    _skinHue = rand(0, 1);
    _hair = pick(const [Color(0xFF3A2A20), Color(0xFFE0B040), Color(0xFFD9502B), Color(0xFF222244)]);
    _fingerX = rand(60, 300);
    _noseDrift = rand(0, 6);
  }

  Color get _skin => Color.lerp(Pal.skin, Pal.skinDark, _skinHue * .8)!;

  // nostril centers in screen space
  Offset get _leftNostril => Offset(_noseX - 17, 318);
  Offset get _rightNostril => Offset(_noseX + 17, 318);

  @override
  void update(double dt) {
    _t += dt;
    _noseX = 180 + sin(_t * 1.7 * host.speed + _noseDrift) * 40 * host.speed;
    if (!_thrusting && !_resolved) {
      _fingerX += _fingerDir * 190 * host.speed * dt;
      if (_fingerX > 320 || _fingerX < 40) _fingerDir = -_fingerDir;
    }
    if (_thrusting) {
      _thrust += dt * 5.5;
      final tipY = _tipY;
      if (!_resolved && tipY <= 330) {
        _resolved = true;
        final hit = (_fingerX - _leftNostril.dx).abs() < 11 || (_fingerX - _rightNostril.dx).abs() < 11;
        _success = hit;
        if (hit) {
          host.sfx(Sfx.squish);
          host.sfx(Sfx.correct, volume: .7);
          host.fx.burst(Offset(_fingerX, 315), Pal.lime, count: 12, speed: 160, gravity: 400);
          host.fx.pop(host.tr('bingo', 'BINGO!'), const Offset(180, 200), color: Pal.lime, size: 34);
          host.shake(5);
          host.win(stars: host.time < 2.5 ? 3 : 2);
        } else {
          host.sfx(Sfx.boing);
          host.sfx(Sfx.hurt, volume: .6);
          host.shake(8);
          host.flash(Pal.red, .12);
          host.lose();
        }
        _react = 1;
      }
      if (_resolved) _thrust = min(_thrust, _resolvedThrust);
    }
    _react = M.approach(_react, 0, 1.2, dt);
  }

  double get _resolvedThrust => 1.0;
  double get _tipY => 600 - _thrust * 290;

  @override
  void onDown(Offset p) {
    if (_thrusting) return;
    _thrusting = true;
    host.sfx(Sfx.whoosh, rate: 1.3);
  }

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action') onDown(Offset.zero);
  }

  @override
  void render(Canvas c) {
    // Loud comic background
    D.gradientBg(c, const [Color(0xFFFFE27A), Color(0xFFFF9E5E)]);
    D.rays(c, const Offset(180, 300), 600, const Color(0x22FFFFFF), count: 18, t: _t * .3);

    final skin = _skin;
    final dark = Color.lerp(skin, Pal.ink, .25)!;
    final hx = _noseX;

    // Head
    c.drawOval(Rect.fromCenter(center: Offset(hx, 250), width: 330, height: 400), D.fill(skin));
    c.drawOval(Rect.fromCenter(center: Offset(hx, 250), width: 330, height: 400), D.stroke(Pal.ink, 5));
    // Hair
    final hair = Path()
      ..moveTo(hx - 170, 180)
      ..quadraticBezierTo(hx - 150, 30, hx, 40)
      ..quadraticBezierTo(hx + 150, 30, hx + 170, 180)
      ..quadraticBezierTo(hx + 90, 110, hx - 20, 120)
      ..quadraticBezierTo(hx - 110, 120, hx - 170, 180)
      ..close();
    c.drawPath(hair, D.fill(_hair));
    c.drawPath(hair, D.stroke(Pal.ink, 5));

    // Eyes: nervous side-eye towards the finger, cross when success
    final look = Offset(((_fingerX - hx) / 150).clamp(-1, 1), 1);
    for (final s in [-1.0, 1.0]) {
      final e = Offset(hx + s * 70, 200);
      if (_resolved && _success) {
        D.line(c, e + const Offset(-14, -8), e + const Offset(0, 0), Pal.ink, 6);
        D.line(c, e + const Offset(0, 0), e + const Offset(-14, 8), Pal.ink, 6);
      } else {
        c.drawOval(Rect.fromCenter(center: e, width: 54, height: 44 + _react * 14), D.fill(Pal.white));
        c.drawOval(Rect.fromCenter(center: e, width: 54, height: 44 + _react * 14), D.stroke(Pal.ink, 4));
        c.drawCircle(e + look * 12, 11, D.fill(Pal.ink));
      }
      // eyebrows
      D.line(c, e + Offset(-24, -36 - _react * 12), e + Offset(24, -40 - _react * 10 + s * 4), Pal.ink, 7);
    }
    // sweat drop when finger is close
    if (_thrusting && !_resolved || host.time > 3) {
      final sd = Offset(hx + 130, 170 + (_t * 60) % 30);
      c.drawPath(
          Path()
            ..moveTo(sd.dx, sd.dy - 14)
            ..quadraticBezierTo(sd.dx + 10, sd.dy, sd.dx, sd.dy + 6)
            ..quadraticBezierTo(sd.dx - 10, sd.dy, sd.dx, sd.dy - 14),
          D.fill(const Color(0xFF7FD3FF)));
    }

    // Big nose
    final nose = Path()
      ..moveTo(hx - 18, 210)
      ..quadraticBezierTo(hx - 8, 270, hx - 48, 300)
      ..quadraticBezierTo(hx - 58, 332, hx - 20, 334)
      ..quadraticBezierTo(hx, 340, hx + 20, 334)
      ..quadraticBezierTo(hx + 58, 332, hx + 48, 300)
      ..quadraticBezierTo(hx + 8, 270, hx + 18, 210);
    c.drawPath(nose, D.fill(Color.lerp(skin, Pal.red, .08)!));
    c.drawPath(nose, D.stroke(Pal.ink, 5));
    // nostrils
    for (final n in [_leftNostril, _rightNostril]) {
      c.drawOval(Rect.fromCenter(center: n, width: 22, height: 14), D.fill(Color.lerp(dark, Pal.ink, .6)!));
    }
    // highlight
    c.drawOval(Rect.fromCenter(center: Offset(hx - 16, 285), width: 14, height: 24), D.fill(const Color(0x55FFFFFF)));

    // Mouth
    if (_resolved && _success) {
      D.face(c, Offset(hx, 360), 60, Face.happy, blush: true);
    } else if (_resolved) {
      c.drawOval(Rect.fromCenter(center: Offset(hx, 390), width: 60, height: 50), D.fill(const Color(0xFF7A1F2B)));
    } else {
      final w = 70 + _react * 20;
      c.drawArc(Rect.fromCenter(center: Offset(hx, 380), width: w, height: 30), .2, pi - .4, false, D.stroke(Pal.ink, 6));
    }

    // The FINGER
    final tip = Offset(_fingerX, _tipY);
    final finger = RRect.fromRectAndCorners(Rect.fromLTWH(tip.dx - 18, tip.dy, 36, 700 - tip.dy),
        topLeft: const Radius.circular(18), topRight: const Radius.circular(18));
    c.drawRRect(finger, D.fill(Pal.skin));
    c.drawRRect(finger, D.stroke(Pal.ink, 5));
    // nail
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(tip.dx - 11, tip.dy + 6, 22, 22), const Radius.circular(8)),
        D.fill(const Color(0xFFFFE9E0)));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(tip.dx - 11, tip.dy + 6, 22, 22), const Radius.circular(8)),
        D.stroke(Pal.ink, 2.5));
    // knuckle lines
    for (var i = 0; i < 2; i++) {
      final y = tip.dy + 70 + i * 10;
      c.drawArc(Rect.fromCenter(center: Offset(tip.dx, y), width: 20, height: 8), 0, pi, false, D.stroke(Pal.ink, 2));
    }

    // aim guide
    if (!_thrusting) {
      final p = Paint()..color = const Color(0x55FFFFFF);
      for (var y = 350.0; y < tip.dy - 10; y += 18) {
        c.drawCircle(Offset(_fingerX, y), 3, p);
      }
      if (host.time < 2) D.text(c, host.tr('tap', 'TAP!'), Offset(_fingerX, tip.dy + 110), size: 22, stroke: Pal.ink);
    }
  }
}
