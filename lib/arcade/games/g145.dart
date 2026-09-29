import '../engine/engine.dart';

/// No.145 Power Wash — drag the pressure washer over a mud-caked car. The jet
/// cuts crisp clean lines through the dirt layer; 90% clean => mirror shine.
class G145 extends MiniGame {
  static const _cell = 10.0;
  static const _jetW = 28.0;
  static const _bounds = Rect.fromLTRB(18, 240, 342, 460);

  late final Path _car;
  late final Path _body;
  late final Path _cabin;
  final Path _wash = Path();
  late final List<bool?> _grid; // null = outside the car
  late final int _gw, _gh;
  int _total = 0;
  int _clean = 0;
  double _t = 0;
  double _pct = 0;
  double _shown = 0;
  Offset? _lastJet;
  double _sprayT = 0;
  int _milestone = 0;
  double _winT = -1;
  double _puddle = 0;
  double _bounce = 0;
  late final List<(Offset, double, int)> _mudBlots;
  late final List<(double, double)> _drips;

  @override
  Color get backdrop => const Color(0xFF1B3A4A);

  @override
  void init() {
    _body = Path()
      ..addRRect(RRect.fromRectAndCorners(const Rect.fromLTRB(22, 318, 338, 418),
          topLeft: const Radius.circular(40), topRight: const Radius.circular(26),
          bottomLeft: const Radius.circular(14), bottomRight: const Radius.circular(14)));
    _cabin = Path()
      ..moveTo(78, 322)
      ..lineTo(118, 252)
      ..quadraticBezierTo(124, 244, 138, 244)
      ..lineTo(236, 244)
      ..quadraticBezierTo(248, 244, 256, 254)
      ..lineTo(300, 322)
      ..close();
    _car = Path()
      ..addPath(_body, Offset.zero)
      ..addPath(_cabin, Offset.zero)
      ..addOval(Rect.fromCircle(center: const Offset(92, 418), radius: 38))
      ..addOval(Rect.fromCircle(center: const Offset(270, 418), radius: 38));
    _gw = (_bounds.width / _cell).ceil();
    _gh = (_bounds.height / _cell).ceil();
    _grid = List<bool?>.generate(_gw * _gh, (i) {
      final p = Offset(_bounds.left + (i % _gw + .5) * _cell, _bounds.top + (i ~/ _gw + .5) * _cell);
      final inside = _body.contains(p) ||
          _cabin.contains(p) ||
          (p - const Offset(92, 418)).distance < 38 ||
          (p - const Offset(270, 418)).distance < 38;
      if (inside) _total++;
      return inside ? false : null;
    });
    _mudBlots = [
      for (var i = 0; i < 70; i++) (Offset(rand(20, 340), rand(240, 460)), rand(5, 16), randInt(3)),
    ];
    _drips = [for (var i = 0; i < 14; i++) (rand(30, 330), rand(10, 26))];
  }

  Offset get _jet => host.pointer + const Offset(0, -78);

  @override
  void update(double dt) {
    _t += dt;
    _sprayT -= dt;
    _bounce = M.approach(_bounce, 0, 5, dt);
    if (_winT >= 0) _winT += dt;
    final spraying = host.pointerDown && !host.finished;
    if (spraying) {
      final j = _jet;
      final last = _lastJet;
      if (last == null) {
        _wash
          ..moveTo(j.dx, j.dy)
          ..lineTo(j.dx + .1, j.dy);
        _cleanAround(j);
        _lastJet = j;
      } else if ((j - last).distance > 3) {
        _wash.lineTo(j.dx, j.dy);
        final n = ((j - last).distance / 5).ceil();
        for (var i = 1; i <= n; i++) {
          _cleanAround(Offset.lerp(last, j, i / n)!);
        }
        _lastJet = j;
      }
      _puddle = min(1, _puddle + dt * .08);
      // water mist
      if (chance(.8)) {
        host.fx.add(Particle(
            pos: j + Offset(rand(-8, 8), rand(-8, 8)),
            vel: Offset(rand(-160, 160), rand(-200, 40)),
            life: rand(.2, .45),
            color: const Color(0xCCBFEFFF),
            size: rand(3, 7),
            gravity: 700));
      }
      if (_sprayT <= 0) {
        _sprayT = .16;
        host.sfx(Sfx.spray, volume: .45, rate: rand(.95, 1.1));
      }
    } else {
      _lastJet = null;
    }
    _pct = _winT >= 0 ? 1 : (_total == 0 ? 0 : _clean / _total);
    _shown = M.approach(_shown, _pct, 8, dt);
    final ms = (_pct * 10).floor();
    if (ms > _milestone && _winT < 0) {
      _milestone = ms;
      host.sfx(Sfx.ding, volume: .5, rate: 1 + ms * .06);
      host.fx.pop('${ms * 10}%', const Offset(180, 200), color: Pal.sky, size: 24);
    }
    if (_pct >= .9 && _winT < 0 && !host.finished) _win();
  }

  void _cleanAround(Offset p) {
    const rad = _jetW / 2 + 2;
    final x0 = ((p.dx - rad - _bounds.left) / _cell).floor().clamp(0, _gw - 1);
    final x1 = ((p.dx + rad - _bounds.left) / _cell).floor().clamp(0, _gw - 1);
    final y0 = ((p.dy - rad - _bounds.top) / _cell).floor().clamp(0, _gh - 1);
    final y1 = ((p.dy + rad - _bounds.top) / _cell).floor().clamp(0, _gh - 1);
    var got = 0;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final i = y * _gw + x;
        if (_grid[i] != false) continue;
        final cc = Offset(_bounds.left + (x + .5) * _cell, _bounds.top + (y + .5) * _cell);
        if ((cc - p).distance <= rad) {
          _grid[i] = true;
          _clean++;
          got++;
        }
      }
    }
    if (got > 0 && chance(.5)) {
      host.fx.add(Particle(
          pos: p,
          vel: Offset(rand(-220, 220), rand(-260, -40)),
          life: rand(.4, .7),
          color: pick(const [Color(0xFF6B4A2B), Color(0xFF8A6238), Color(0xFF4E351E)]),
          size: rand(4, 8),
          gravity: 900,
          shape: PartShape.square,
          spin: rand(-8, 8)));
      host.score += got;
    }
  }

  void _win() {
    _winT = 0;
    _bounce = 1;
    host.sfx(Sfx.sparkle);
    host.sfx(Sfx.fanfare, volume: .8);
    host.flash(Pal.white, .3);
    host.shake(4);
    host.fx.sparkle(const Offset(180, 330), count: 30, radius: 150);
    host.win(stars: host.time < 10 ? 3 : (host.time < 14 ? 2 : 1));
  }

  @override
  void onTimeUp() {
    if (_pct >= .8) {
      _win();
    } else {
      host.lose();
    }
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    // sky + house wall
    D.gradientBg(c, const [Color(0xFF7FD6FF), Color(0xFFD8F4FF)], rect: const Rect.fromLTWH(0, 0, 360, 200));
    D.circle(c, const Offset(300, 90), 30, const Color(0xFFFFE680));
    D.circle(c, const Offset(300, 90), 42, const Color(0x33FFE680));
    D.cloud(c, Offset(80 + (_t * 6) % 60, 100), 50);
    c.drawRect(const Rect.fromLTWH(0, 150, 360, 320), D.fill(const Color(0xFFF1E3C8)));
    for (var y = 150.0; y < 470; y += 16) {
      c.drawRect(Rect.fromLTWH(0, y + 14, 360, 2), D.fill(const Color(0xFFD9C6A2)));
    }
    // garage door
    D.rrect(c, const Rect.fromLTWH(40, 170, 280, 280), 6, const Color(0xFFE9EEF3), border: const Color(0xFF8A96A6), borderWidth: 4);
    for (var i = 1; i < 7; i++) {
      c.drawRect(Rect.fromLTWH(44, 170 + i * 40.0, 272, 3), D.fill(const Color(0xFFBCC6D2)));
    }
    c.drawRect(const Rect.fromLTWH(0, 146, 360, 10), D.fill(const Color(0xFF8A5A3A)));
    // driveway
    D.gradientBg(c, const [Color(0xFFB9BCC4), Color(0xFF8E929C)], rect: const Rect.fromLTWH(0, 450, 360, 190));
    for (var x = -40.0; x < 400; x += 90) {
      D.line(c, Offset(x, 450), Offset(x - 60, 640), const Color(0x33000000), 2);
    }
    // puddle
    if (_puddle > 0) {
      c.drawOval(Rect.fromCenter(center: const Offset(180, 470), width: 300 * _puddle + 40, height: 30 * _puddle + 6),
          D.fill(Color.lerp(const Color(0x886B4A2B), const Color(0x887FC8FF), _pct)!));
    }
    // car shadow
    D.shadow(c, const Offset(180, 458), 330, 26, .3);

    final bob = _bounce > 0 ? -sin(_bounce * pi * 3) * 10 * _bounce : 0.0;
    c.save();
    c.translate(0, bob);
    _drawCar(c);
    _drawMud(c);
    c.restore();

    // win shine
    if (_winT >= 0) {
      final x = -80 + _winT * 480;
      c.save();
      c.clipPath(_car.shift(Offset(0, bob)));
      final band = Path()
        ..moveTo(x, 230)
        ..lineTo(x + 40, 230)
        ..lineTo(x - 60, 470)
        ..lineTo(x - 100, 470)
        ..close();
      c.drawPath(band, D.fill(const Color(0xAAFFFFFF)));
      c.restore();
      for (var i = 0; i < 5; i++) {
        final p = [const Offset(120, 270), const Offset(240, 300), const Offset(60, 350), const Offset(300, 360), const Offset(200, 380)][i];
        final k = M.wave(_winT * 2 + i * .2);
        c.drawPath(D.starPath(p, 8 + k * 14, 3, points: 4, rotation: 0), D.fill(Pal.white));
      }
    }

    _drawGun(c);
    _renderHud(c);
    if (host.time < 2.2 && _clean == 0) {
      final hp = Offset(120 + sin(_t * 3) * 70, 470);
      D.hand(c, hp, _t);
      D.text(c, host.tr('drag', 'DRAG!'), const Offset(180, 560), size: 26, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _drawCar(Canvas c) {
    // wheels
    for (final w in const [Offset(92, 418), Offset(270, 418)]) {
      D.circle(c, w, 38, const Color(0xFF26222E));
      D.circle(c, w, 22, const Color(0xFFDDE3EA), border: const Color(0xFF7A8494), borderWidth: 3);
      for (var k = 0; k < 5; k++) {
        final a = k / 5 * pi * 2 + _t * (_winT >= 0 ? 6 : 0);
        D.line(c, w, w + Offset.fromDirection(a, 16), const Color(0xFF9AA4B4), 4);
      }
      D.circle(c, w, 6, const Color(0xFF7A8494));
    }
    // body
    c.drawPath(
        _body,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF6A7E), Color(0xFFE0203E), Color(0xFF9A1028)],
          ).createShader(const Rect.fromLTRB(22, 318, 338, 418)));
    c.drawPath(
        _cabin,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF7A8C), Color(0xFFE0203E)],
          ).createShader(const Rect.fromLTRB(78, 244, 300, 322)));
    // windows (with eyes!)
    final back = Path()
      ..moveTo(98, 318)
      ..lineTo(128, 262)
      ..lineTo(180, 262)
      ..lineTo(180, 318)
      ..close();
    final front = Path()
      ..moveTo(192, 318)
      ..lineTo(192, 262)
      ..lineTo(240, 262)
      ..lineTo(276, 318)
      ..close();
    for (final w in [back, front]) {
      c.drawPath(w, D.fill(const Color(0xFFBFE9FF)));
      c.drawPath(w, D.stroke(const Color(0xFF6A1020), 4));
    }
    c.drawPath(
        Path()
          ..moveTo(140, 266)
          ..lineTo(160, 266)
          ..lineTo(130, 314)
          ..lineTo(112, 314)
          ..close(),
        D.fill(const Color(0x88FFFFFF)));
    // eyes in the front window
    final happy = _winT >= 0;
    for (final ex in const [214.0, 244.0]) {
      final e = Offset(ex, 292);
      if (happy) {
        c.drawArc(Rect.fromCenter(center: e + const Offset(0, 4), width: 20, height: 18), pi, pi, false, D.stroke(Pal.ink, 4));
      } else {
        c.drawOval(Rect.fromCenter(center: e, width: 20, height: 24), D.fill(Pal.white));
        c.drawOval(Rect.fromCenter(center: e, width: 20, height: 24), D.stroke(Pal.ink, 2.5));
        D.circle(c, e + Offset(sin(_t) * 2, 3), 5, Pal.ink);
        D.line(c, e + const Offset(-10, -12), e + const Offset(10, -8), Pal.ink, 3);
      }
    }
    // body lines, handles, lights
    D.line(c, const Offset(186, 324), const Offset(186, 400), const Color(0x886A1020), 3);
    D.line(c, const Offset(100, 324), const Offset(100, 386), const Color(0x886A1020), 3);
    D.rrect(c, const Rect.fromLTWH(150, 336, 22, 7), 3, const Color(0xFFDDE3EA));
    D.rrect(c, const Rect.fromLTWH(234, 336, 22, 7), 3, const Color(0xFFDDE3EA));
    c.drawRect(const Rect.fromLTWH(30, 354, 300, 6), D.fill(const Color(0x55FFFFFF)));
    D.rrect(c, const Rect.fromLTWH(318, 334, 22, 18), 6, const Color(0xFFFFF4A8), border: Pal.ink, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(20, 334, 14, 18), 5, const Color(0xFFFF5040), border: Pal.ink, borderWidth: 2);
    // grin bumper
    D.rrect(c, const Rect.fromLTWH(292, 396, 52, 14), 7, const Color(0xFFDDE3EA), border: Pal.ink, borderWidth: 2);
    c.drawArc(Rect.fromCenter(center: const Offset(316, 378), width: 30, height: happy ? 22 : 10), .2, pi - .4, false,
        D.stroke(Pal.ink, 3));
    // plate
    D.rrect(c, const Rect.fromLTWH(150, 388, 60, 20), 4, Pal.white, border: Pal.ink, borderWidth: 2);
    PixelFont.draw(c, 'AD 151', const Offset(180, 394), 1.3, Pal.ink, align: 0);
    c.drawPath(_body, D.stroke(const Color(0xFF6A1020), 4));
    c.drawPath(_cabin, D.stroke(const Color(0xFF6A1020), 4));
    // gloss highlight
    c.drawPath(
        Path()
          ..moveTo(40, 330)
          ..quadraticBezierTo(120, 320, 200, 326)
          ..lineTo(200, 332)
          ..quadraticBezierTo(120, 326, 44, 338)
          ..close(),
        D.fill(const Color(0x88FFFFFF)));
  }

  void _drawMud(Canvas c) {
    final fade = _winT < 0 ? 1.0 : (1 - _winT / .5).clamp(0.0, 1.0);
    if (fade <= 0) return;
    c.saveLayer(_bounds.inflate(4), Paint()..color = Color.fromRGBO(0, 0, 0, fade));
    c.save();
    c.clipPath(_car);
    c.drawRect(_bounds.inflate(4), D.fill(const Color(0xFF7A5634)));
    for (final (p, r, k) in _mudBlots) {
      c.drawCircle(p, r, D.fill(const [Color(0xFF6A482A), Color(0xFF86623C), Color(0xFF5A3C22)][k]));
    }
    for (final (x, len) in _drips) {
      D.line(c, Offset(x, 320), Offset(x, 320 + len), const Color(0xFF4A3220), 6);
    }
    // grime text scrawl
    D.line(c, const Offset(120, 360), const Offset(150, 350), const Color(0xFFB08A60), 4);
    D.line(c, const Offset(150, 350), const Offset(170, 370), const Color(0xFFB08A60), 4);
    c.restore();
    c.drawPath(
        _wash,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..style = PaintingStyle.stroke
          ..strokeWidth = _jetW
          ..strokeCap = StrokeCap.round);
    c.restore();
  }

  void _drawGun(Canvas c) {
    final down = host.pointerDown && !host.finished;
    final hand = down ? host.pointer : const Offset(300, 590);
    final jet = hand + const Offset(0, -78);
    // hose
    final hose = Path()
      ..moveTo(hand.dx + 4, hand.dy + 30)
      ..quadraticBezierTo(hand.dx + 10, 660, 370, 610);
    c.drawPath(hose, D.stroke(const Color(0xFF2B2F3A), 9));
    c.drawPath(hose, D.stroke(const Color(0xFFFFC53D), 4));
    if (down) {
      // water jet
      final wob = sin(_t * 60) * 1.5;
      D.line(c, hand + const Offset(0, -34), jet, const Color(0x88BFEFFF), 12 + wob);
      D.line(c, hand + const Offset(0, -34), jet, Pal.white, 4);
      D.circle(c, jet, 14 + sin(_t * 40) * 3, const Color(0xAAE6FAFF));
    }
    // gun
    c.save();
    c.translate(hand.dx, hand.dy);
    D.rrect(c, const Rect.fromLTWH(-5, -36, 10, 40), 4, const Color(0xFF3A3F4E), border: Pal.ink, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(-7, -40, 14, 8), 3, Pal.yellow, border: Pal.ink, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(-12, 0, 24, 36), 7, Pal.yellow, border: Pal.ink, borderWidth: 3);
    D.rrect(c, const Rect.fromLTWH(-8, 6, 16, 8), 3, const Color(0xFF3A3F4E));
    c.restore();
    if (!down && !host.finished) {
      // aim reticle hint
      c.drawCircle(jet, 12, D.stroke(const Color(0x88FFFFFF), 2));
    }
  }

  void _renderHud(Canvas c) {
    const bar = Rect.fromLTWH(60, 50, 240, 22);
    D.rrect(c, bar.inflate(3), 14, Pal.ink);
    D.bar(c, bar, _shown, Color.lerp(const Color(0xFF8E6A42), Pal.sky, _shown)!, back: const Color(0xFF4A3A30));
    c.drawRect(Rect.fromLTWH(bar.left + bar.width * .9 - 1, bar.top - 3, 3, bar.height + 6), D.fill(Pal.yellow));
    D.text(c, '${(_shown * 100).floor()}%', bar.center, size: 16, color: Pal.white, stroke: Pal.ink);
    // droplet icon
    final drop = Path()
      ..moveTo(36, 46)
      ..quadraticBezierTo(48, 62, 36, 72)
      ..quadraticBezierTo(24, 62, 36, 46)
      ..close();
    c.drawPath(drop, D.fill(Pal.sky));
    c.drawPath(drop, D.stroke(Pal.ink, 2.5));
    D.star(c, const Offset(324, 61), 13 + sin(_t * 5) * 2, _pct >= .9 ? Pal.yellow : const Color(0xFF8E8AA3), border: Pal.ink);
  }
}
