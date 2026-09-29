import '../engine/engine.dart';

/// No.080 Feed the Cat! — drag the fish from the plate into the wandering
/// cat's mouth. The greedy dog tries to intercept it.
class G080 extends MiniGame {
  static const _plate = Offset(180, 574);
  double _t = 0;
  Offset _fish = _plate;
  bool _held = false;
  Offset _grab = Offset.zero;
  Offset _cat = const Offset(240, 300);
  Offset _catV = Offset.zero;
  double _catTurn = 0;
  Offset _dog = const Offset(70, 420);
  double _dogFace = 1;
  int _state = 0; // 0 play, 1 fed, 2 stolen
  double _endT = 0;
  double _purr = 0;
  double _catFace = -1;

  @override
  void init() {
    _cat = Offset(rand(200, 290), rand(240, 330));
    _dog = Offset(rand(60, 120), rand(380, 440));
    _newCatDir();
  }

  void _newCatDir() {
    final a = rand(0, pi * 2);
    _catV = Offset(cos(a), sin(a) * .6) * 60 * host.speed;
    _catTurn = rand(.7, 1.3);
  }

  Offset get _catMouth => _cat + Offset(_catFace * 40, -18);
  Offset get _dogMouth => _dog + Offset(_dogFace * 56, -18);

  @override
  void update(double dt) {
    _t += dt;
    if (_state == 0) {
      // cat wanders
      _catTurn -= dt;
      if (_catTurn <= 0) _newCatDir();
      _cat += _catV * dt;
      if (_cat.dx < 70 || _cat.dx > 290) _catV = Offset(-_catV.dx, _catV.dy);
      if (_cat.dy < 190 || _cat.dy > 400) _catV = Offset(_catV.dx, -_catV.dy);
      _cat = Offset(_cat.dx.clamp(70, 290), _cat.dy.clamp(190, 400));
      if (_catV.dx.abs() > 5) _catFace = _catV.dx.sign;
      // dog: intercept the fish when it's airborne, else sniff toward the plate
      final target = _held ? Offset.lerp(_fish, _catMouth, .3)! : Offset.lerp(_plate, _cat, .5)!;
      final sp = (_held ? 135.0 : 55.0) * host.speed;
      final d = target - _dogMouth;
      final len = d.distance;
      if (len > 2) {
        _dog += d / len * min(sp * dt, len);
        if (d.dx.abs() > 4) _dogFace = d.dx.sign;
      }
      _dog = Offset(_dog.dx.clamp(40, 320), _dog.dy.clamp(170, 500));
      if (!_held) _fish = M.approachO(_fish, _plate, 12, dt);
      // resolve
      if (_held) {
        if ((_fish - _catMouth).distance < 46) {
          _feed();
        } else if ((_fish - _dogMouth).distance < 34) {
          _steal();
        }
      }
    } else {
      _endT += dt;
      if (_state == 1) {
        _fish = _catMouth;
        _purr += dt;
        if ((_purr * 6).floor() != ((_purr - dt) * 6).floor()) {
          host.fx.add(Particle(
            pos: _cat + Offset(rand(-30, 30), -70),
            vel: Offset(rand(-40, 40), rand(-120, -60)),
            life: 1,
            color: Pal.pink,
            size: rand(6, 10),
            shape: PartShape.heart,
          ));
        }
      } else {
        _dog += Offset(_dogFace * 220 * dt, -30 * dt);
        _fish = _dogMouth;
      }
    }
  }

  void _feed() {
    _state = 1;
    _held = false;
    host.sfx(Sfx.chomp);
    host.sfx(Sfx.correct, volume: .8);
    host.shake(5);
    host.hitStop(.06);
    host.fx.burst(_catMouth, Pal.pink, count: 14, speed: 240, shape: PartShape.heart, size: 7, gravity: 100);
    host.fx.pop(host.tr('yum', 'YUM!'), _cat + const Offset(0, -110), color: Pal.pink, size: 40);
    host.win(stars: host.time < 2.2 ? 3 : (host.time < 3.6 ? 2 : 1));
  }

  void _steal() {
    _state = 2;
    _held = false;
    host.sfx(Sfx.chomp, rate: .8);
    host.sfx(Sfx.boing);
    host.shake(10);
    host.flash(Pal.red, .12);
    host.fx.pop(host.tr('oops', 'OOPS!'), _dog + const Offset(0, -80), color: Pal.red, size: 36);
    host.lose();
  }

  @override
  void onDown(Offset p) {
    if (_state != 0) return;
    if ((p - _fish).distance < 60) {
      _held = true;
      _grab = _fish - p;
      host.sfx(Sfx.pickup);
    }
  }

  @override
  void onMove(Offset p) {
    if (_held) _fish = p + _grab;
  }

  @override
  void onUp(Offset p) {
    if (!_held) return;
    _held = false;
    host.sfx(Sfx.whoosh, volume: .5);
  }

  @override
  void onTimeUp() {
    host.sfx(Sfx.aww);
    host.lose();
  }

  @override
  void render(Canvas c) {
    // kitchen floor, checker tiles + rays
    D.gradientBg(c, const [Color(0xFFFFD6E8), Color(0xFFFF9EC4)]);
    D.rays(c, _cat, 700, const Color(0x26FFFFFF), count: 18, t: _t * .3);
    final tile = D.fill(const Color(0x18FFFFFF));
    for (var y = 0; y < 12; y++) {
      for (var x = 0; x < 8; x++) {
        if ((x + y).isEven) c.drawRect(Rect.fromLTWH(x * 48.0, 60 + y * 48.0, 48, 48), tile);
      }
    }
    // wall strip
    c.drawRect(const Rect.fromLTWH(0, 40, 360, 110), D.fill(const Color(0xFFFFF4DC)));
    for (var i = 0; i < 8; i++) {
      c.drawRect(Rect.fromLTWH(i * 48.0, 40, 24, 110), D.fill(const Color(0x22FF8A1F)));
    }
    D.line(c, const Offset(0, 150), const Offset(360, 150), Pal.ink, 4);
    // fish bowl on the wall shelf
    D.rrect(c, const Rect.fromLTWH(250, 110, 90, 12), 4, const Color(0xFF9A5B34), border: Pal.ink, borderWidth: 3);
    c.drawCircle(const Offset(295, 86), 26, D.fill(const Color(0x887FD3FF)));
    c.drawCircle(const Offset(295, 86), 26, D.stroke(Pal.ink, 3));

    // plate
    D.shadow(c, _plate + const Offset(0, 14), 150, 30);
    c.drawOval(Rect.fromCenter(center: _plate, width: 140, height: 44), D.fill(Pal.white));
    c.drawOval(Rect.fromCenter(center: _plate, width: 140, height: 44), D.stroke(Pal.ink, 4));
    c.drawOval(Rect.fromCenter(center: _plate, width: 96, height: 26), D.stroke(const Color(0xFF8EC9FF), 3));

    // draw back-to-front by y
    if (_dog.dy < _cat.dy) {
      _drawDog(c);
      _drawCat(c);
    } else {
      _drawCat(c);
      _drawDog(c);
    }
    if (_state != 1 || _endT < .1) _drawFish(c);

    if (_state == 0 && !_held && host.time < 2.2) {
      D.hand(c, _fish + const Offset(4, 6), _t);
      D.arrow(c, Offset.lerp(_plate, _cat, .5)!, _cat - _plate, 80, Pal.yellow, width: 12);
      D.text(c, host.tr('drag', 'DRAG!'), const Offset(80, 580), size: 26, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _drawFish(Canvas c) {
    final wig = _held ? sin(_t * 30) * .3 : sin(_t * 4) * .08;
    c.save();
    c.translate(_fish.dx, _fish.dy);
    c.rotate(wig);
    if (_held) c.scale(1.15);
    final body = Path()
      ..moveTo(-34, 0)
      ..quadraticBezierTo(-6, -24, 24, 0)
      ..quadraticBezierTo(-6, 24, -34, 0)
      ..close();
    final tail = Path()
      ..moveTo(20, 0)
      ..lineTo(40, -16)
      ..lineTo(36, 0)
      ..lineTo(40, 16)
      ..close();
    c.drawPath(tail, D.fill(const Color(0xFF3D6BFF)));
    c.drawPath(tail, D.stroke(Pal.ink, 3));
    c.drawPath(body, D.fill(const Color(0xFF6FA8FF)));
    c.drawPath(body, D.stroke(Pal.ink, 3.5));
    c.drawCircle(const Offset(-20, -3), 4, D.fill(Pal.white));
    c.drawCircle(const Offset(-20, -3), 2, D.fill(Pal.ink));
    D.line(c, const Offset(-6, -8), const Offset(-2, 8), const Color(0x663D6BFF), 3);
    D.line(c, const Offset(4, -8), const Offset(8, 8), const Color(0x663D6BFF), 3);
    c.restore();
  }

  void _drawCat(Canvas c) {
    final o = _cat;
    final fed = _state == 1;
    final robbed = _state == 2;
    final bob = fed ? sin(_t * 20) * 3 : sin(_t * 8) * 2;
    D.shadow(c, o + const Offset(0, 36), 130, 24);
    c.save();
    c.translate(o.dx, o.dy + bob);
    c.scale(_catFace, 1);
    // tail
    final tail = Path()
      ..moveTo(-44, 10)
      ..quadraticBezierTo(-90, -10 + sin(_t * 5) * 20, -70, -60 + sin(_t * 5 + 1) * 10);
    c.drawPath(tail, D.stroke(Pal.ink, 16));
    c.drawPath(tail, D.stroke(const Color(0xFFFFA64D), 10));
    // body
    c.drawOval(const Rect.fromLTWH(-56, -20, 104, 56), D.fill(const Color(0xFFFFA64D)));
    for (var i = 0; i < 3; i++) {
      D.line(c, Offset(-30 + i * 18.0, -16), Offset(-24 + i * 18.0, 2), const Color(0xFFE07A20), 5);
    }
    c.drawOval(const Rect.fromLTWH(-56, -20, 104, 56), D.stroke(Pal.ink, 4));
    // legs
    for (var i = 0; i < 4; i++) {
      final lx = -40 + i * 26.0;
      final step = _state == 0 ? sin(_t * 12 + i * pi / 2) * 4 : 0.0;
      D.rrect(c, Rect.fromLTWH(lx, 22 + step, 14, 16), 6, const Color(0xFFFFA64D), border: Pal.ink, borderWidth: 3);
    }
    // head
    const h = Offset(40, -34);
    for (final s in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(h.dx + s * 30, h.dy - 12)
        ..lineTo(h.dx + s * 26, h.dy - 48)
        ..lineTo(h.dx + s * 4, h.dy - 30)
        ..close();
      c.drawPath(ear, D.fill(const Color(0xFFFFA64D)));
      c.drawPath(ear, D.stroke(Pal.ink, 4));
    }
    c.drawCircle(h, 38, D.fill(const Color(0xFFFFB866)));
    c.drawCircle(h, 38, D.stroke(Pal.ink, 4));
    c.restore();
    // face (not mirrored so it stays readable)
    final hf = o + Offset(_catFace * 40, -34 + bob);
    final face = fed ? Face.love : (robbed ? Face.cry : (host.timeLeft < 1.5 ? Face.angry : Face.happy));
    D.face(c, hf, 34, face, look: _held ? Offset(((_fish.dx - hf.dx) / 80).clamp(-1, 1), ((_fish.dy - hf.dy) / 80).clamp(-1, 1)) : Offset.zero);
    for (final s in [-1.0, 1.0]) {
      D.line(c, hf + Offset(s * 20, 10), hf + Offset(s * 46, 6), Pal.ink, 2);
      D.line(c, hf + Offset(s * 20, 15), hf + Offset(s * 46, 18), Pal.ink, 2);
    }
    // open mouth when fish is near
    if (_state == 0 && _held && (_fish - _catMouth).distance < 140) {
      c.drawOval(Rect.fromCenter(center: hf + const Offset(0, 16), width: 24, height: 20), D.fill(const Color(0xFF8B1E3F)));
      c.drawOval(Rect.fromCenter(center: hf + const Offset(0, 16), width: 24, height: 20), D.stroke(Pal.ink, 3));
    }
    if (fed) {
      D.text(c, '~', hf + const Offset(50, 30), size: 30, color: Pal.pink, stroke: Pal.ink);
    }
  }

  void _drawDog(Canvas c) {
    final o = _dog;
    final won = _state == 2;
    final sad = _state == 1;
    D.shadow(c, o + const Offset(0, 36), 120, 22);
    final bob = sin(_t * (won ? 20 : 10)) * 2;
    c.save();
    c.translate(o.dx, o.dy + bob);
    c.scale(_dogFace, 1);
    // tail wag
    final wag = sin(_t * (won ? 30 : 14)) * 14;
    D.line(c, const Offset(-44, -4), Offset(-66, -26 + wag), Pal.ink, 12);
    D.line(c, const Offset(-44, -4), Offset(-66, -26 + wag), const Color(0xFFC08A5A), 7);
    // body
    c.drawOval(const Rect.fromLTWH(-54, -18, 100, 52), D.fill(const Color(0xFFC08A5A)));
    c.drawOval(const Rect.fromLTWH(-30, -10, 34, 26), D.fill(const Color(0xFFFFF4DC)));
    c.drawOval(const Rect.fromLTWH(-54, -18, 100, 52), D.stroke(Pal.ink, 4));
    for (var i = 0; i < 4; i++) {
      final lx = -40 + i * 24.0;
      final step = _state != 1 ? sin(_t * 14 + i * pi / 2) * 4 : 0.0;
      D.rrect(c, Rect.fromLTWH(lx, 20 + step, 14, 16), 6, const Color(0xFFC08A5A), border: Pal.ink, borderWidth: 3);
    }
    // head
    const h = Offset(36, -28);
    c.drawCircle(h, 34, D.fill(const Color(0xFFC08A5A)));
    c.drawCircle(h, 34, D.stroke(Pal.ink, 4));
    // snout
    c.drawOval(Rect.fromCenter(center: h + const Offset(22, 8), width: 36, height: 26), D.fill(const Color(0xFFFFF4DC)));
    c.drawOval(Rect.fromCenter(center: h + const Offset(22, 8), width: 36, height: 26), D.stroke(Pal.ink, 3));
    c.drawCircle(h + const Offset(36, 2), 6, D.fill(Pal.ink));
    // floppy ear
    c.drawOval(Rect.fromCenter(center: h + const Offset(-20, 4), width: 22, height: 44), D.fill(const Color(0xFF7A4A2A)));
    c.drawOval(Rect.fromCenter(center: h + const Offset(-20, 4), width: 22, height: 44), D.stroke(Pal.ink, 3));
    // eyes
    c.drawCircle(h + const Offset(6, -10), 6, D.fill(Pal.ink));
    c.drawCircle(h + const Offset(4, -12), 2, D.fill(Pal.white));
    if (!sad) {
      // tongue + drool
      c.drawOval(Rect.fromCenter(center: h + const Offset(24, 26), width: 14, height: 20), D.fill(Pal.pink));
      c.drawOval(Rect.fromCenter(center: h + const Offset(24, 26), width: 14, height: 20), D.stroke(Pal.ink, 2.5));
      c.drawCircle(h + Offset(30, 34 + (_t * 30) % 12), 4, D.fill(const Color(0xCC8ED8FF)));
    } else {
      c.drawArc(Rect.fromCenter(center: h + const Offset(24, 22), width: 16, height: 10), pi, pi, false,
          D.stroke(Pal.ink, 3));
    }
    c.restore();
    if (_held && _state == 0) {
      D.text(c, '!', o + Offset(0, -80 + sin(_t * 20) * 3), size: 32, color: Pal.red, stroke: Pal.ink);
    }
  }
}
