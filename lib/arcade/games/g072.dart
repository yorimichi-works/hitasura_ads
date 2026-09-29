import '../engine/engine.dart';

/// No.072 Plug It In! — phone at 1%; drag the charger plug into the outlet
/// that keeps sliding along the wall. Plugged: lightning + 100%. Too late:
/// the phone dies.
class G072 extends MiniGame {
  static const _outletY = 250.0;
  static const _home = Offset(262, 560);
  static const _phone = Offset(96, 548);
  double _t = 0;
  double _outletX = 180;
  late double _phase;
  Offset _plug = _home;
  bool _dragging = false;
  Offset _grab = Offset.zero;
  bool _plugged = false;
  double _plugT = 0;
  double _battery = 1;
  bool _dead = false;
  double _deadT = 0;
  double _wiggle = 0;
  int _misses = 0;

  @override
  void init() {
    _phase = rand(0, pi * 2);
  }

  @override
  void update(double dt) {
    _t += dt;
    if (!_plugged) {
      final sp = host.speed;
      _outletX = 180 + sin(_t * 1.6 * sp + _phase) * 95 + sin(_t * 3.1 * sp) * 18 * (sp - .6);
      if (!_dragging) _plug = M.approachO(_plug, _home, 10, dt);
    } else {
      _plugT += dt;
      _plug = M.approachO(_plug, _socket + const Offset(0, 22), 30, dt);
      final prev = _battery;
      _battery = M.approach(_battery, 100, 3.2, dt);
      if (_battery.floor() ~/ 10 > prev.floor() ~/ 10) host.sfx(Sfx.tick, rate: 1 + _battery / 100);
      if (_battery > 99 && !host.finished) {
        host.sfx(Sfx.levelup);
        host.fx.pop('100%', _phone + const Offset(0, -110), color: Pal.lime, size: 36);
        host.win(stars: host.time < 2.2 ? 3 : (_misses == 0 ? 2 : 1));
      }
    }
    if (_dead) _deadT += dt;
    _wiggle = M.approach(_wiggle, 0, 6, dt);
  }

  Offset get _socket => Offset(_outletX, _outletY);

  void _tryPlug() {
    if (_plugged || host.finished) return;
    final prong = _plug + const Offset(0, -22);
    if ((prong - _socket).distance < 24) {
      _plugged = true;
      _dragging = false;
      host.sfx(Sfx.click);
      host.sfx(Sfx.zap, volume: .8);
      host.sfx(Sfx.powerup, volume: .7);
      host.shake(7);
      host.hitStop(.07);
      host.flash(const Color(0xAAFFF27A));
      host.fx.burst(_socket, Pal.yellow, count: 22, speed: 320, shape: PartShape.spark, size: 10, gravity: 0);
      host.fx.ring(_socket, Pal.yellow, size: 80);
      host.fx.pop(host.tr('nice', 'NICE!'), _socket + const Offset(0, -70), color: Pal.yellow, size: 34);
    }
  }

  @override
  void onDown(Offset p) {
    if (_plugged) return;
    if ((p - _plug).distance < 70) {
      _dragging = true;
      _grab = _plug - p;
      host.sfx(Sfx.pickup, volume: .6);
    }
  }

  @override
  void onMove(Offset p) {
    if (!_dragging) return;
    _plug = Offset((p + _grab).dx.clamp(20, 340), (p + _grab).dy.clamp(80, 610));
    _tryPlug();
  }

  @override
  void onUp(Offset p) {
    if (!_dragging) return;
    _dragging = false;
    _tryPlug();
    if (!_plugged) {
      _misses++;
      _wiggle = 1;
      host.sfx(Sfx.boing, volume: .7);
      if ((_plug - _socket).distance < 120) host.fx.pop(host.tr('miss', 'MISS'), _plug, color: Pal.red, size: 24);
    }
  }

  @override
  void onTimeUp() {
    _dead = true;
    _battery = 0;
    host.sfx(Sfx.glitch);
    host.sfx(Sfx.aww, volume: .7);
    host.shake(5);
    host.lose();
  }

  @override
  void render(Canvas c) {
    // Wallpaper
    D.gradientBg(c, const [Color(0xFFFFB86B), Color(0xFFFF6F91)]);
    D.rays(c, Offset(_outletX, _outletY), 700, const Color(0x22FFFFFF), count: 18, t: _t * .3);
    final stripe = D.fill(const Color(0x14FFFFFF));
    for (var x = -20.0; x < 360; x += 48) {
      c.drawRect(Rect.fromLTWH(x, 0, 20, 470), stripe);
    }
    // rail the outlet slides on
    D.rrect(c, const Rect.fromLTWH(20, _outletY - 10, 320, 20), 10, const Color(0x44000000));
    // floor
    c.drawRect(const Rect.fromLTWH(0, 470, 360, 170), D.fill(const Color(0xFF8A5A3C)));
    for (var i = 0; i < 5; i++) {
      D.line(c, Offset(0, 500 + i * 34.0), Offset(360, 500 + i * 34.0), const Color(0x33000000), 3);
    }
    c.drawRect(const Rect.fromLTWH(0, 460, 360, 14), D.fill(Pal.white));
    D.line(c, const Offset(0, 474), const Offset(360, 474), Pal.ink, 3);

    _drawOutlet(c);

    // Cable phone -> plug
    final start = _phone + const Offset(0, 70);
    final end = _plug + const Offset(0, 26);
    final sag = max(40.0, 160 - (end - start).distance * .2);
    final cable = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(start.dx, start.dy + sag, end.dx, end.dy + sag + 40, end.dx, end.dy);
    c.drawPath(cable, D.stroke(Pal.ink, 11));
    c.drawPath(cable, D.stroke(Pal.white, 6));

    _drawPhone(c);
    _drawPlug(c);

    if (!_plugged && !_dragging && host.time < 2.2) {
      D.arrow(c, Offset(_plug.dx - 30, 380), Offset((_outletX - _plug.dx) * .2, -1), 90, Pal.yellow, width: 14);
      D.hand(c, _plug + const Offset(8, 10), _t);
    }
  }

  void _drawOutlet(Canvas c) {
    final o = _socket;
    final zap = _plugged ? M.clamp01(1 - _plugT * 2) : 0.0;
    final plate = Rect.fromCenter(center: o, width: 84, height: 104);
    D.rrect(c, plate.shift(const Offset(0, 6)), 16, const Color(0x55000000));
    D.rrect(c, plate, 16, const Color(0xFFF7F2E8), border: Pal.ink, borderWidth: 4);
    // the outlet is a scared little face
    final face = Rect.fromCenter(center: o, width: 58, height: 70);
    D.rrect(c, face, 22, const Color(0xFFEDE5D4), border: Pal.ink, borderWidth: 3);
    for (final s in [-1.0, 1.0]) {
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: o + Offset(s * 11, -8), width: 7, height: 20),
              const Radius.circular(3)),
          D.fill(Pal.ink));
    }
    // mouth (ground hole) — screams when chased
    final close = !_plugged && (_plug - o).distance < 110;
    if (close) {
      c.drawOval(Rect.fromCenter(center: o + const Offset(0, 18), width: 16, height: 16), D.fill(Pal.ink));
    } else {
      c.drawArc(Rect.fromCenter(center: o + const Offset(0, 16), width: 20, height: 12), 0, pi, false,
          D.stroke(Pal.ink, 3));
    }
    if (close) {
      // sweat
      c.drawCircle(o + const Offset(40, -44), 6, D.fill(const Color(0xFF7FD3FF)));
    }
    if (zap > 0) {
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3 + _t * 4;
        D.line(c, o + Offset(cos(a), sin(a)) * 56, o + Offset(cos(a), sin(a)) * (56 + 30 * zap), Pal.yellow, 6);
      }
    }
  }

  void _drawPlug(Canvas c) {
    final p = _plug + Offset(sin(_t * 40) * 6 * _wiggle, 0);
    // prongs
    if (!_plugged || _plugT < .05) {
      for (final s in [-1.0, 1.0]) {
        D.rrect(c, Rect.fromLTWH(p.dx + s * 11 - 4, p.dy - 44, 8, 26), 2, const Color(0xFFD7DCE6),
            border: Pal.ink, borderWidth: 3);
      }
    }
    final body = Rect.fromCenter(center: p, width: 50, height: 46);
    D.rrect(c, body, 12, _plugged ? const Color(0xFF444C66) : const Color(0xFF2C3148), border: Pal.ink, borderWidth: 4);
    D.rrect(c, Rect.fromLTWH(body.left + 6, body.top + 5, body.width - 12, 9), 4, const Color(0x44FFFFFF));
    // strain relief
    D.rrect(c, Rect.fromCenter(center: p + const Offset(0, 28), width: 20, height: 14), 5, const Color(0xFF2C3148),
        border: Pal.ink, borderWidth: 3);
    // bolt icon
    _bolt(c, p + const Offset(0, 2), 11, Pal.yellow);
  }

  void _bolt(Canvas c, Offset o, double s, Color col) {
    final path = Path()
      ..moveTo(o.dx + s * .2, o.dy - s)
      ..lineTo(o.dx - s * .6, o.dy + s * .15)
      ..lineTo(o.dx - s * .05, o.dy + s * .15)
      ..lineTo(o.dx - s * .25, o.dy + s)
      ..lineTo(o.dx + s * .6, o.dy - s * .2)
      ..lineTo(o.dx + s * .05, o.dy - s * .2)
      ..close();
    c.drawPath(path, D.fill(col));
    c.drawPath(path, D.stroke(Pal.ink, s * .18));
  }

  void _drawPhone(Canvas c) {
    final o = _phone;
    final shake = !_plugged && !_dead ? sin(_t * 50) * (host.time > 2.5 ? 2.5 : 1) : 0.0;
    c.save();
    c.translate(o.dx + shake, o.dy);
    c.rotate(-.12);
    final body = Rect.fromCenter(center: Offset.zero, width: 110, height: 150);
    D.rrect(c, body.shift(const Offset(5, 7)), 18, const Color(0x55000000));
    D.rrect(c, body, 18, const Color(0xFF22222E), border: Pal.ink, borderWidth: 4);
    final screen = body.deflate(8);
    if (_dead && _deadT > .15) {
      D.rrect(c, screen, 12, const Color(0xFF050508));
      D.face(c, const Offset(0, 0), 30, Face.dead, ink: const Color(0xFF444455), blush: false);
    } else {
      final low = _battery < 15;
      final blink = low && (_t * 3).floor().isEven;
      D.rrect(c, screen, 12,
          _plugged ? const Color(0xFF1E6B3A) : (blink ? const Color(0xFF5A1020) : const Color(0xFF2A1830)));
      // battery icon
      final bat = Rect.fromCenter(center: const Offset(0, -26), width: 62, height: 30);
      D.rrect(c, bat, 6, const Color(0x00000000), border: Pal.white, borderWidth: 3);
      D.rrect(c, Rect.fromLTWH(bat.right + 1, bat.center.dy - 6, 6, 12), 2, Pal.white);
      final fillW = (bat.width - 8) * M.clamp01(_battery / 100);
      final col = _battery < 15 ? Pal.red : (_battery < 60 ? Pal.yellow : Pal.lime);
      if (fillW > 1) D.rrect(c, Rect.fromLTWH(bat.left + 4, bat.top + 4, max(3, fillW), bat.height - 8), 3, col);
      if (_plugged) _bolt(c, const Offset(0, -26), 12, Pal.white);
      D.text(c, '${_battery.floor()}%', const Offset(0, 14), size: 26, color: col, stroke: Pal.ink);
      D.circle(c, const Offset(0, 48), 17, _plugged ? Pal.yellow : const Color(0xFFFFB0B0), border: Pal.ink);
      D.face(c, const Offset(0, 48), 16, _plugged ? Face.happy : (host.time > 2.5 ? Face.cry : Face.shocked),
          blush: false);
    }
    c.restore();
    if (!_plugged && !_dead) {
      final a = .5 + .5 * sin(_t * 12);
      D.text(c, '!', o + Offset(62, -80 - a * 6), size: 34, color: Pal.red, stroke: Pal.ink);
    }
  }
}
