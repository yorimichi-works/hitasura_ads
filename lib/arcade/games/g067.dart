import '../engine/engine.dart';

/// No.067 Shave It! — drag the razor over the foamy stubble. Avoid the nose.
class G067 extends MiniGame {
  double _t = 0;
  final List<_Hair> _hairs = [];
  int _shaved = 0;
  Offset? _razor; // razor head when held
  Offset _restPos = const Offset(300, 590);
  bool _cut = false;
  bool _done = false;
  double _endT = 0;
  double _scrubCd = 0;
  double _nervous = 0;
  late final double _headR;
  late final Color _hairCol;

  static const _face = Offset(180, 330);
  static const _fw = 300.0, _fh = 390.0;
  static const _nose = Offset(180, 322);
  static const _noseRx = 30.0, _noseRy = 42.0;
  static const _mouth = Offset(180, 428);

  double get _progress => _hairs.isEmpty ? 0 : _shaved / _hairs.length;

  @override
  void init() {
    _headR = 27 / pow(host.speed, .3);
    _hairCol = pick(const [Color(0xFF3A2A20), Color(0xFF6A3A1A), Color(0xFF222244), Color(0xFFB04A20)]);
    for (var y = 356.0; y < 520; y += 17) {
      for (var x = 50.0; x < 320; x += 17) {
        final p = Offset(x + rand(-4, 4), y + rand(-4, 4));
        // inside face (slightly shrunk)
        final fx = (p.dx - _face.dx) / (_fw / 2 - 14), fy = (p.dy - _face.dy) / (_fh / 2 - 12);
        if (fx * fx + fy * fy > 1) continue;
        // not on nose / mouth
        final nx = (p.dx - _nose.dx) / (_noseRx + 10), ny = (p.dy - _nose.dy) / (_noseRy + 10);
        if (nx * nx + ny * ny < 1) continue;
        final mx = (p.dx - _mouth.dx) / 46, my = (p.dy - _mouth.dy) / 18;
        if (mx * mx + my * my < 1) continue;
        _hairs.add(_Hair(p, rand(0, pi), rand(9, 13)));
      }
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _scrubCd -= dt;
    _nervous = M.approach(_nervous, 0, 3, dt);
    if (_done || _cut) _endT += dt;
    for (final h in _hairs) {
      if (h.gone) h.fade = M.approach(h.fade, 0, 14, dt);
    }
  }

  void _shave(Offset a, Offset b) {
    if (host.finished) return;
    // nose check along the stroke
    for (var i = 0; i <= 4; i++) {
      final p = Offset.lerp(a, b, i / 4)!;
      final nx = (p.dx - _nose.dx) / _noseRx, ny = (p.dy - _nose.dy) / _noseRy;
      final d = nx * nx + ny * ny;
      if (d < .75) {
        _nick(p);
        return;
      }
      if (d < 2.2) _nervous = 1;
    }
    var n = 0;
    for (final h in _hairs) {
      if (h.gone) continue;
      if (M.distToSegment(h.pos, a, b) < _headR) {
        h.gone = true;
        n++;
        if (n <= 3) host.fx.burst(h.pos, Pal.white, count: 2, speed: 90, size: 5, gravity: 200);
      }
    }
    if (n > 0) {
      _shaved += n;
      if (_scrubCd <= 0) {
        _scrubCd = .09;
        host.sfx(Sfx.scrub, rate: .9 + _progress * .6, volume: .7);
      }
      if (_progress >= .9) _win();
    }
  }

  void _nick(Offset p) {
    _cut = true;
    _razor = p;
    host.sfx(Sfx.slash);
    host.sfx(Sfx.hurt, volume: .8);
    host.shake(10);
    host.flash(Pal.red, .15);
    host.hitStop(.1);
    host.fx.burst(p, Pal.red, count: 10, speed: 160, gravity: 500);
    host.fx.pop(host.tr('ouch', 'OUCH!'), const Offset(180, 200), color: Pal.red, size: 40);
    host.lose();
  }

  void _win() {
    _done = true;
    host.sfx(Sfx.sparkle);
    host.sfx(Sfx.correct, volume: .8);
    host.punch(.06);
    host.shake(4);
    for (final h in _hairs) {
      h.gone = true;
    }
    host.fx.sparkle(_face + const Offset(-60, 100), count: 10, radius: 50, color: Pal.white);
    host.fx.sparkle(_face + const Offset(60, 100), count: 10, radius: 50, color: Pal.white);
    host.fx.pop(host.tr('smooth', 'SMOOTH!'), const Offset(180, 190), color: Pal.sky, size: 40);
    host.win(stars: host.time < 3.2 ? 3 : (host.time < 4.2 ? 2 : 1));
  }

  @override
  void onDown(Offset p) {
    _razor = p;
    _shave(p, p);
  }

  @override
  void onMove(Offset p) {
    final last = _razor;
    if (last == null) return;
    _razor = p;
    _shave(last, p);
  }

  @override
  void onUp(Offset p) {
    if (_cut) return;
    _restPos = p;
    _razor = null;
  }

  @override
  void onTimeUp() {
    host.sfx(Sfx.aww);
    host.fx.pop('${(_progress * 100).round()}%', const Offset(180, 200), color: Pal.orange, size: 40);
    host.lose();
  }

  @override
  void render(Canvas c) {
    // bathroom tiles + rays
    D.gradientBg(c, const [Color(0xFF7FE6E0), Color(0xFF3FB8FF)]);
    final tp = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 3;
    for (var y = 40.0; y < 640; y += 44) {
      c.drawLine(Offset(0, y), Offset(360, y), tp);
    }
    for (var x = 0.0; x < 360; x += 44) {
      c.drawLine(Offset(x, 36), Offset(x, 640), tp);
    }
    D.rays(c, _face, 700, const Color(0x22FFFFFF), count: 18, t: _t * .3);

    // neck + shoulders (towel)
    D.rrect(c, const Rect.fromLTWH(125, 470, 110, 120), 20, Pal.skinDark);
    final towel = Path()
      ..moveTo(0, 640)
      ..lineTo(0, 590)
      ..quadraticBezierTo(180, 520, 360, 590)
      ..lineTo(360, 640)
      ..close();
    c.drawPath(towel, D.fill(Pal.white));
    c.drawPath(towel, D.stroke(Pal.ink, 5));
    for (var x = 20.0; x < 360; x += 30) {
      D.line(c, Offset(x, 600 - sin(x / 360 * pi) * 30), Offset(x, 640), const Color(0x22000000), 3);
    }

    // head
    final fr = Rect.fromCenter(center: _face, width: _fw, height: _fh);
    // ears
    for (final s in [-1.0, 1.0]) {
      final e = _face + Offset(s * (_fw / 2 - 4), -10);
      c.drawOval(Rect.fromCenter(center: e, width: 44, height: 70), D.fill(Pal.skin));
      c.drawOval(Rect.fromCenter(center: e, width: 44, height: 70), D.stroke(Pal.ink, 5));
    }
    c.drawOval(fr, D.fill(Pal.skin));
    // shaved skin looks a touch bluish-smooth
    c.save();
    c.clipPath(Path()..addOval(fr));
    c.drawRect(Rect.fromLTWH(0, 350, 360, 200), D.fill(const Color(0x0F3D6BFF)));
    c.restore();
    // hair
    final hair = Path()
      ..moveTo(_face.dx - _fw / 2, _face.dy - 40)
      ..quadraticBezierTo(_face.dx - _fw / 2 - 10, _face.dy - _fh / 2 - 30, _face.dx, _face.dy - _fh / 2 - 10)
      ..quadraticBezierTo(_face.dx + _fw / 2 + 10, _face.dy - _fh / 2 - 30, _face.dx + _fw / 2, _face.dy - 40)
      ..quadraticBezierTo(_face.dx + 100, _face.dy - 150, _face.dx + 20, _face.dy - 130)
      ..quadraticBezierTo(_face.dx - 60, _face.dy - 110, _face.dx - _fw / 2, _face.dy - 40)
      ..close();
    c.drawPath(hair, D.fill(_hairCol));
    c.drawPath(hair, D.stroke(Pal.ink, 5));
    c.drawOval(fr, D.stroke(Pal.ink, 5));

    // foam + stubble
    final foam = D.fill(const Color(0xFFFFFFFF));
    final foamShade = D.fill(const Color(0xFFDDEEFF));
    for (final h in _hairs) {
      if (h.fade < .02) continue;
      final r = h.r * h.fade;
      c.drawCircle(h.pos + const Offset(1.5, 2), r, foamShade);
      c.drawCircle(h.pos, r, foam);
    }
    final stub = D.stroke(_hairCol, 2.4);
    for (final h in _hairs) {
      if (h.gone) continue;
      final d = Offset(cos(h.a), sin(h.a)) * 3;
      c.drawLine(h.pos - d, h.pos + d, stub);
      c.drawLine(h.pos + const Offset(5, 3) - d, h.pos + const Offset(5, 3) + d, stub);
    }

    // eyes
    final razor = _razor ?? _restPos;
    final look = Offset(((razor.dx - 180) / 120).clamp(-1, 1), ((razor.dy - 270) / 120).clamp(-1, 1));
    for (final s in [-1.0, 1.0]) {
      final e = _face + Offset(s * 62, -58);
      if (_done) {
        c.drawArc(Rect.fromCenter(center: e + const Offset(0, 6), width: 40, height: 30), pi, pi, false, D.stroke(Pal.ink, 6));
      } else if (_cut) {
        c.drawOval(Rect.fromCenter(center: e, width: 46, height: 50), D.fill(Pal.white));
        c.drawOval(Rect.fromCenter(center: e, width: 46, height: 50), D.stroke(Pal.ink, 4));
        c.drawCircle(e, 6, D.fill(Pal.ink));
        c.drawOval(Rect.fromCenter(center: e + Offset(s * 4, 40 + (_endT * 60) % 30), width: 12, height: 22),
            D.fill(const Color(0xCC6ECBFF)));
      } else {
        final h = 40 + _nervous * 10;
        c.drawOval(Rect.fromCenter(center: e, width: 46, height: h), D.fill(Pal.white));
        c.drawOval(Rect.fromCenter(center: e, width: 46, height: h), D.stroke(Pal.ink, 4));
        c.drawCircle(e + look * 10, 10 - _nervous * 3, D.fill(Pal.ink));
      }
      // brows
      final by = -34 - _nervous * 8;
      D.line(c, e + Offset(-24, by + (s < 0 ? 4 : -2) * (_nervous + .3)), e + Offset(24, by + (s < 0 ? -2 : 4) * (_nervous + .3)),
          _hairCol, 8);
    }

    // big nose (danger zone)
    final nr = Rect.fromCenter(center: _nose, width: _noseRx * 2, height: _noseRy * 2);
    c.drawOval(nr, D.fill(Color.lerp(Pal.skin, Pal.red, _cut ? .35 : .12 + _nervous * .12)!));
    c.drawOval(nr, D.stroke(Pal.ink, 5));
    c.drawOval(Rect.fromCenter(center: _nose + const Offset(-10, -14), width: 12, height: 20), D.fill(const Color(0x66FFFFFF)));
    if (_cut) {
      // bandage cross
      for (final a in [.6, -.6]) {
        c.save();
        c.translate(_nose.dx, _nose.dy + 6);
        c.rotate(a);
        D.rrect(c, const Rect.fromLTWH(-34, -10, 68, 20), 8, const Color(0xFFF2D0A0), border: Pal.ink, borderWidth: 3);
        for (var i = 0; i < 3; i++) {
          c.drawCircle(Offset(-6 + i * 6.0, 0), 1.6, D.fill(const Color(0x88000000)));
        }
        c.restore();
      }
    }

    // mouth
    if (_done) {
      final m = Path()
        ..moveTo(_mouth.dx - 40, _mouth.dy - 8)
        ..quadraticBezierTo(_mouth.dx, _mouth.dy + 36, _mouth.dx + 40, _mouth.dy - 8)
        ..close();
      c.drawPath(m, D.fill(const Color(0xFF8B1E3F)));
      c.drawPath(m, D.stroke(Pal.ink, 5));
      c.drawRect(Rect.fromLTWH(_mouth.dx - 26, _mouth.dy - 6, 52, 8), D.fill(Pal.white));
    } else if (_cut) {
      c.drawOval(Rect.fromCenter(center: _mouth + const Offset(0, 4), width: 50, height: 40), D.fill(const Color(0xFF7A1F2B)));
      c.drawOval(Rect.fromCenter(center: _mouth + const Offset(0, 4), width: 50, height: 40), D.stroke(Pal.ink, 5));
    } else {
      final wob = sin(_t * 20) * _nervous * 4;
      final m = Path()
        ..moveTo(_mouth.dx - 34, _mouth.dy)
        ..quadraticBezierTo(_mouth.dx - 17, _mouth.dy - 8 + wob, _mouth.dx, _mouth.dy)
        ..quadraticBezierTo(_mouth.dx + 17, _mouth.dy + 8 - wob, _mouth.dx + 34, _mouth.dy);
      c.drawPath(m, D.stroke(Pal.ink, 6));
    }

    // shine when done
    if (_done) {
      for (var i = 0; i < 4; i++) {
        final p = _face + Offset(-90 + i * 60.0, 120 + (i.isEven ? -10 : 14));
        final s = 10 + 6 * M.wave(_t * 2 + i);
        D.star(c, p, s, Pal.white, border: Pal.sky);
      }
    }

    _drawRazor(c, razor, _razor != null);

    // HUD progress
    final pr = Rect.fromLTWH(60, 46, 240, 20);
    D.bar(c, pr, _progress / .9, _progress >= .9 ? Pal.lime : Pal.sky, border: Pal.ink);
    D.text(c, '${min(100, (_progress / .9 * 100).round())}%', pr.center, size: 14, stroke: Pal.ink);

    if (host.time < 1.8 && _razor == null && !host.finished) {
      D.hand(c, const Offset(100, 470), _t);
      D.arrow(c, const Offset(180, 500), const Offset(1, 0), 120, Pal.yellow, width: 12);
      D.text(c, host.tr('drag', 'DRAG!'), const Offset(180, 545), size: 24, stroke: Pal.ink);
    }
  }

  void _drawRazor(Canvas c, Offset head, bool held) {
    c.save();
    c.translate(head.dx, head.dy);
    if (!held) c.rotate(-.5);
    final w = _headR * 2 + 10;
    // handle
    final handle = RRect.fromRectAndRadius(const Rect.fromLTWH(-10, 12, 20, 120), const Radius.circular(10));
    c.drawRRect(handle.shift(const Offset(5, 6)), D.fill(const Color(0x33000000)));
    c.drawRRect(handle, D.fill(const Color(0xFF3D6BFF)));
    for (var i = 0; i < 5; i++) {
      c.drawLine(Offset(-7, 50 + i * 12.0), Offset(7, 50 + i * 12.0), D.stroke(const Color(0x55FFFFFF), 3));
    }
    c.drawRRect(handle, D.stroke(Pal.ink, 3.5));
    // head
    final hr = Rect.fromCenter(center: Offset.zero, width: w, height: 26);
    D.rrect(c, hr, 8, const Color(0xFF2A3E8C), border: Pal.ink, borderWidth: 3.5);
    D.rrect(c, Rect.fromLTWH(-w / 2 + 5, -9, w - 10, 7), 3, const Color(0xFFE6ECF5), border: Pal.ink, borderWidth: 2);
    D.rrect(c, Rect.fromLTWH(-w / 2 + 5, 1, w - 10, 5), 2, const Color(0xFFB8C0D4));
    c.drawRect(Rect.fromLTWH(-w / 2 + 8, -8, w * .4, 2), D.fill(Pal.white));
    c.restore();
  }
}

class _Hair {
  _Hair(this.pos, this.a, this.r);
  final Offset pos;
  final double a;
  final double r;
  bool gone = false;
  double fade = 1;
}
