import '../engine/engine.dart';

/// No.071 Cut It in Half! — a roll cake slides under a knife; tap to slice it
/// exactly in half while two siblings watch VERY closely.
class G071 extends MiniGame {
  static const _knifeX = 180.0;
  static const _cakeY = 300.0; // cake center line
  double _t = 0;
  late bool _baguette;
  late double _w; // cake length
  double _cx = 0; // cake center x
  double _dir = 1;
  bool _cut = false;
  double _cutT = 0; // time since the cut
  double _knife = 0; // 0 up .. 1 down
  double _leftPct = 50;
  bool _good = false;
  int _winner = 0; // -1 left sibling got more, 1 right, 0 fair

  @override
  void init() {
    _baguette = chance(.35);
    _w = _baguette ? 280 : 240;
    _cx = chance(.5) ? 70 : 290;
    _dir = _cx < 180 ? 1 : -1;
  }

  double get _speed => (150 + 20 * (host.speed - 1)) * host.speed;

  @override
  void update(double dt) {
    _t += dt;
    if (!_cut) {
      _cx += _dir * _speed * dt;
      if (_cx > 180 + 115) {
        _cx = 180 + 115;
        _dir = -1;
      }
      if (_cx < 180 - 115) {
        _cx = 180 - 115;
        _dir = 1;
      }
    } else {
      _cutT += dt;
    }
    _knife = _cut ? M.approach(_knife, 1, 30, dt) : M.approach(_knife, 0, 12, dt);
  }

  @override
  void onDown(Offset p) {
    if (_cut) return;
    _cut = true;
    final left = _cx - _w / 2;
    _leftPct = ((_knifeX - left) / _w * 100).clamp(0, 100).toDouble();
    final off = (_leftPct - 50).abs();
    _good = off <= 5;
    _winner = off < 1.5 ? 0 : (_leftPct > 50 ? -1 : 1);
    host.sfx(Sfx.chop);
    host.shake(6);
    host.hitStop(.06);
    host.fx.burst(Offset(_knifeX, _cakeY), Pal.cream, count: 18, speed: 240, size: 6, gravity: 500);
    if (_good) {
      host.sfx(off < 1.5 ? Sfx.perfect : Sfx.correct);
      host.flash(const Color(0x88FFFFFF));
      host.fx.pop(
        off < 1.5 ? host.tr('perfect', 'PERFECT!') : host.tr('nice', 'NICE!'),
        const Offset(180, 175),
        color: Pal.lime,
        size: 36,
      );
      host.fx.sparkle(Offset(_knifeX, _cakeY), count: 14, radius: 60, color: Pal.yellow);
      host.win(stars: off < 1.5 ? 3 : (off < 3 ? 2 : 1));
    } else {
      host.sfx(Sfx.buzzer, volume: .7);
      host.flash(Pal.red, .12);
      host.lose();
    }
  }

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action') onDown(Offset.zero);
  }

  @override
  void render(Canvas c) {
    // Loud comic background
    D.gradientBg(c, const [Color(0xFF7FE0FF), Color(0xFFB08CFF)]);
    D.rays(c, const Offset(180, 300), 700, const Color(0x2EFFFFFF), count: 16, t: _t * .25);
    // polka dots
    final dot = D.fill(const Color(0x22FFFFFF));
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 6; x++) {
        c.drawCircle(Offset(x * 70.0 + (y.isOdd ? 35 : 0), 60 + y * 60.0), 8, dot);
      }
    }

    // Table
    c.drawRect(const Rect.fromLTWH(0, 350, 360, 290), D.fill(const Color(0xFFE39A55)));
    for (var i = 0; i < 6; i++) {
      D.line(c, Offset(-20 + i * 80.0, 360), Offset(-60 + i * 80.0, 640), const Color(0x22000000), 3);
    }
    c.drawRect(const Rect.fromLTWH(0, 342, 360, 16), D.fill(const Color(0xFFB86B2E)));
    D.line(c, const Offset(0, 342), const Offset(360, 342), Pal.ink, 4);

    // Cutting board
    final board = Rect.fromCenter(center: Offset(_cx, _cakeY + 44), width: _w + 50, height: 26);
    D.rrect(c, board.shift(const Offset(0, 6)), 12, const Color(0xFF7A4A22));
    D.rrect(c, board, 12, const Color(0xFFD9A066), border: Pal.ink, borderWidth: 4);

    // The cake (split after the cut)
    final sep = _cut ? M.easeOutBack((_cutT * 3).clamp(0, 1)) * 26 : 0.0;
    final left = _cx - _w / 2;
    final cutX = _cut ? _knifeX : _cx;
    final lw = cutX - left;
    if (!_cut) {
      _drawCake(c, left, lw, true);
    } else {
      c.save();
      c.clipRect(Rect.fromLTRB(-50, 0, cutX, 640));
      c.translate(-sep, 0);
      c.rotate(_cut ? -.03 * M.clamp01(_cutT * 3) : 0);
      _drawCake(c, left, lw, true);
      c.restore();
      c.save();
      c.clipRect(Rect.fromLTRB(cutX, 0, 410, 640));
      c.translate(sep, 0);
      _drawCake(c, left, lw, false);
      c.restore();
    }

    // The knife
    _drawKnife(c);

    // Percent split
    if (_cut) {
      final a = M.easeOutBack((_cutT * 4).clamp(0, 1));
      final lp = _leftPct.round();
      final rp = 100 - lp;
      final col = _good ? Pal.lime : Pal.red;
      c.save();
      c.translate(180, 395);
      c.scale(a);
      D.rrect(c, const Rect.fromLTWH(-150, -26, 300, 52), 26, Pal.ink);
      D.text(c, '$lp%', const Offset(-80, 0), size: 34, color: lp >= rp ? col : Pal.white, stroke: Pal.ink);
      D.text(c, ':', Offset.zero, size: 30, color: Pal.white);
      D.text(c, '$rp%', const Offset(80, 0), size: 34, color: rp >= lp ? col : Pal.white, stroke: Pal.ink);
      c.restore();
    } else if (host.time < 2) {
      D.hand(c, const Offset(180, 470), _t);
      D.text(c, host.tr('tap', 'TAP!'), const Offset(180, 560), size: 26, stroke: Pal.ink, color: Pal.yellow);
    }

    // Siblings (bottom), staring
    _sibling(c, const Offset(80, 560), -1, const Color(0xFFFF6B8B), const Color(0xFF3A2A20));
    _sibling(c, const Offset(280, 560), 1, const Color(0xFF4FA3FF), const Color(0xFF222244));
  }

  void _drawCake(Canvas c, double left, double lw, bool isLeft) {
    final r = Rect.fromLTWH(left, _cakeY - 38, _w, 76);
    if (_baguette) {
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(38));
      c.drawRRect(rr.shift(const Offset(0, 5)), D.fill(const Color(0xFF8A4B16)));
      c.drawRRect(rr, D.fill(const Color(0xFFDB9440)));
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 12, r.top + 8, r.width - 24, 18), const Radius.circular(9)),
        D.fill(const Color(0x55FFF1C0)),
      );
      for (var i = 0; i < 5; i++) {
        final x = r.left + 40 + i * (r.width - 80) / 4;
        D.line(c, Offset(x - 14, r.top + 22), Offset(x + 14, r.top + 10), const Color(0xFF9C5518), 6);
      }
      c.drawRRect(rr, D.stroke(Pal.ink, 5));
    } else {
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(16));
      c.drawRRect(rr, D.fill(const Color(0xFFF2C77E)));
      // cream stripe + strawberries on top
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(r.left, r.top - 14, r.width, 18), const Radius.circular(9)),
        D.fill(Pal.white),
      );
      for (var i = 0; i < 6; i++) {
        final x = r.left + 22 + i * (r.width - 44) / 5;
        c.drawCircle(Offset(x, r.top - 18), 10, D.fill(Pal.red));
        c.drawCircle(Offset(x, r.top - 18), 10, D.stroke(Pal.ink, 2.5));
        c.drawCircle(Offset(x - 3, r.top - 21), 2.5, D.fill(const Color(0xAAFFFFFF)));
      }
      // sponge texture
      for (var i = 0; i < 14; i++) {
        c.drawCircle(
          Offset(r.left + 14 + (i * 37) % (r.width - 20), r.top + 22 + (i * 23) % 40),
          3,
          D.fill(const Color(0x33A0602A)),
        );
      }
      c.drawRRect(rr, D.stroke(Pal.ink, 5));
    }
    // swirl end caps
    _swirl(c, Offset(r.left + 6, _cakeY));
    _swirl(c, Offset(r.right - 6, _cakeY));
    // exposed swirl at cut
    if (_cut) {
      _swirl(c, Offset(isLeft ? left + lw - 2 : left + lw + 2, _cakeY));
    }
  }

  void _swirl(Canvas c, Offset o) {
    if (_baguette) {
      c.drawOval(Rect.fromCenter(center: o, width: 22, height: 70), D.fill(const Color(0xFFFFF0C8)));
      c.drawOval(Rect.fromCenter(center: o, width: 22, height: 70), D.stroke(Pal.ink, 3));
      return;
    }
    c.drawOval(Rect.fromCenter(center: o, width: 26, height: 74), D.fill(const Color(0xFFF2C77E)));
    final p = Path();
    for (var i = 0; i < 40; i++) {
      final a = i * .5;
      final rr = 2 + i * .85;
      final pt = o + Offset(cos(a) * rr * .32, sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(p, D.stroke(Pal.white, 5));
    c.drawOval(Rect.fromCenter(center: o, width: 26, height: 74), D.stroke(Pal.ink, 3));
  }

  void _drawKnife(Canvas c) {
    final y = M.lerp(150, 268, _knife) + (_cut ? 0 : sin(_t * 9) * 3);
    // handle
    D.rrect(
      c,
      Rect.fromCenter(center: Offset(_knifeX, y - 110), width: 34, height: 80),
      12,
      const Color(0xFF3B2A4A),
      border: Pal.ink,
      borderWidth: 4,
    );
    for (var i = 0; i < 3; i++) {
      c.drawCircle(Offset(_knifeX, y - 132 + i * 22), 4, D.fill(Pal.gray));
    }
    // blade
    final blade = Path()
      ..moveTo(_knifeX - 20, y - 70)
      ..lineTo(_knifeX + 20, y - 70)
      ..lineTo(_knifeX + 20, y + 20)
      ..quadraticBezierTo(_knifeX + 10, y + 42, _knifeX - 20, y + 48)
      ..close();
    c.drawPath(blade, D.fill(const Color(0xFFE8EEF8)));
    c.drawPath(
      Path()
        ..moveTo(_knifeX - 20, y - 70)
        ..lineTo(_knifeX - 8, y - 70)
        ..lineTo(_knifeX - 8, y + 44)
        ..lineTo(_knifeX - 20, y + 48)
        ..close(),
      D.fill(const Color(0xFFB9C4D8)),
    );
    c.drawPath(blade, D.stroke(Pal.ink, 4));
    // glint
    final g = (_t * 1.5) % 1.0;
    c.drawCircle(Offset(_knifeX + 8, y - 60 + g * 90), 4, D.fill(Pal.white));
    if (!_cut) {
      // aim line
      final p = D.fill(const Color(0x88FFFFFF));
      for (var yy = y + 58; yy < _cakeY - 44; yy += 12) {
        c.drawCircle(Offset(_knifeX, yy), 2.5, p);
      }
    }
  }

  void _sibling(Canvas c, Offset o, int side, Color shirt, Color hair) {
    final bounce = _cut ? sin(_cutT * 18) * 4 * M.clamp01(1 - _cutT) : sin(_t * 3 + side) * 2;
    final head = o + Offset(0, -30 + bounce);
    // body
    D.rrect(
      c,
      Rect.fromCenter(center: o + const Offset(0, 70), width: 120, height: 100),
      40,
      shirt,
      border: Pal.ink,
      borderWidth: 4,
    );
    // head
    c.drawCircle(head, 62, D.fill(Pal.skin));
    c.drawArc(Rect.fromCircle(center: head, radius: 64), pi * 1.05, pi * .9, true, D.fill(hair));
    c.drawCircle(head, 62, D.stroke(Pal.ink, 4));
    Face f;
    if (!_cut) {
      f = Face.neutral;
    } else if (_winner == 0 || _good) {
      f = _winner == side ? Face.smug : Face.happy;
      if (_winner == 0) f = Face.love;
    } else {
      f = _winner == side ? Face.smug : Face.cry;
    }
    final look = _cut ? Offset(-side * .6, -1) : Offset(((_cx - o.dx) / 150).clamp(-1, 1), -1);
    D.face(c, head + const Offset(0, 8), 50, f, look: look);
    // hands gripping table edge
    for (final s in [-1.0, 1.0]) {
      c.drawCircle(o + Offset(s * 48, 20), 14, D.fill(Pal.skin));
      c.drawCircle(o + Offset(s * 48, 20), 14, D.stroke(Pal.ink, 3));
    }
    if (_cut && !_good && _winner != side && _winner != 0) {
      // angry vein
      final v = head + Offset(side * -36, -40);
      D.line(c, v + const Offset(-8, 0), v + const Offset(8, 0), Pal.red, 4);
      D.line(c, v + const Offset(0, -8), v + const Offset(0, 8), Pal.red, 4);
    }
  }
}
