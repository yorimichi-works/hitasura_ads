import '../engine/engine.dart';

/// No.011 Knife Hit — tap to throw knives into a spinning log. Don't hit the
/// knives already stuck in it! 8 knives → the log explodes.
class G011 extends MiniGame {
  static const _center = Offset(180, 250);
  static const _r = 80.0;
  static const _embed = 18.0;
  static const _need = 8;
  static const _readyTipY = 505.0;
  static const _hitAngle = .2;

  double _t = 0;
  double _rot = 0;
  double _omega = 2.4;
  final List<_Stuck> _knives = [];
  final List<_Apple> _apples = [];
  final List<_Debris> _debris = [];
  int _thrown = 0;
  int _apple = 0;
  double _tipY = _readyTipY; // flying knife tip
  bool _flying = false;
  double _reload = 0; // slide-in animation 1 → 0
  double _logKick = 0;
  double _logFlash = 0;
  bool _broken = false;
  bool _clanged = false;
  double _angry = 0;

  @override
  void init() {
    final taken = <double>[];
    bool free(double a, double gap) => taken.every((b) => _angDiff(a, b) > gap);
    for (var i = 0; i < 2; i++) {
      var a = rand(0, pi * 2);
      for (var k = 0; k < 30 && !free(a, 1.0); k++) {
        a = rand(0, pi * 2);
      }
      taken.add(a);
      _knives.add(_Stuck(a, old: true));
    }
    for (var i = 0; i < 2; i++) {
      var a = rand(0, pi * 2);
      for (var k = 0; k < 30 && !free(a, .8); k++) {
        a = rand(0, pi * 2);
      }
      taken.add(a);
      _apples.add(_Apple(a));
    }
    _rot = rand(0, pi * 2);
  }

  static double _angDiff(double a, double b) {
    var d = (a - b) % (pi * 2);
    if (d < 0) d += pi * 2;
    return d > pi ? pi * 2 - d : d;
  }

  double _targetOmega(double t) {
    const seg = 2.3;
    final phase = (t / seg).floor() % 4;
    final local = t % seg;
    switch (phase) {
      case 0:
        return 2.3;
      case 1:
        return 1.0 + 3.0 * M.wave(local, .7);
      case 2:
        return -2.7;
      default:
        return local < .7 ? .25 : 3.8;
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    if (!_broken) {
      _omega = M.approach(_omega, _targetOmega(host.time) * host.speed, 3.5, dt);
      _rot += _omega * dt;
    }
    _logKick = M.approach(_logKick, 0, 14, dt);
    _logFlash = max(0, _logFlash - dt * 6);
    _reload = max(0, _reload - dt * 8);
    _angry = max(0, _angry - dt);

    if (_flying) {
      _tipY -= 2900 * dt;
      if (_tipY <= _center.dy + _r - _embed + 6) _resolve();
    }

    for (final d in _debris) {
      d.vel = d.vel + Offset(0, 1500 * dt);
      d.pos += d.vel * dt;
      d.angle += d.spin * dt;
    }
    _debris.removeWhere((d) => d.pos.dy > 800);
    for (final a in _apples) {
      if (a.cut > 0) a.cut += dt;
    }
  }

  void _resolve() {
    _flying = false;
    final local = pi / 2 - _rot;
    final hitPt = Offset(_center.dx, _center.dy + _r);
    final blocked = _knives.any((k) => _angDiff(k.a, local) < _hitAngle);
    if (blocked) {
      _clanged = true;
      _tipY = _readyTipY;
      _debris.add(_Debris.knife(hitPt + const Offset(0, 30), Offset(rand(-260, 260), 420), rand(10, 16) * (chance(.5) ? 1 : -1)));
      host.sfx(Sfx.clang);
      host.sfx(Sfx.buzzer, volume: .6);
      host.shake(10);
      host.flash(Pal.white, .1);
      host.hitStop(.08);
      host.fx.burst(hitPt, Pal.yellow, count: 18, speed: 320, shape: PartShape.spark, size: 10, gravity: 0);
      host.fx.pop(host.tr('oops', 'OOPS!'), hitPt + const Offset(0, 60), color: Pal.red, size: 34);
      _angry = 2;
      host.lose();
      return;
    }
    _knives.add(_Stuck(local));
    _thrown++;
    _logKick = 1;
    _logFlash = 1;
    host.sfx(Sfx.chop, rate: .9 + _thrown * .05);
    host.sfx(Sfx.thud, volume: .6);
    host.shake(3);
    host.fx.burst(hitPt, const Color(0xFFD9A066),
        colors: const [Color(0xFFD9A066), Color(0xFFA86B3C), Color(0xFFF2D0A0)],
        count: 12, speed: 260, shape: PartShape.square, size: 6, gravity: 900);
    host.addScore(10, hitPt + const Offset(40, 10));
    for (final ap in _apples) {
      if (ap.cut == 0 && _angDiff(ap.a, local) < .26) {
        ap.cut = .001;
        _apple++;
        host.sfx(Sfx.squish);
        host.sfx(Sfx.coin, rate: 1.2);
        final p = hitPt + const Offset(0, 14);
        host.fx.burst(p, Pal.red, colors: const [Pal.red, Color(0xFFFFF0C8), Pal.lime], count: 16, speed: 260, gravity: 800);
        host.fx.pop('+50', p + const Offset(-40, 0), color: Pal.lime, size: 28);
        host.addScore(50);
      }
    }
    if (_thrown >= _need) _shatter();
  }

  void _shatter() {
    _broken = true;
    host.sfx(Sfx.explode);
    host.sfx(Sfx.fanfare, volume: .8);
    host.shake(14, .4);
    host.flash(Pal.white, .2);
    host.hitStop(.1);
    host.punch(.06);
    for (var i = 0; i < 6; i++) {
      final a = _rot + i * pi / 3 + pi / 6;
      _debris.add(_Debris.wedge(_center + Offset(cos(a), sin(a)) * 20, Offset(cos(a), sin(a)) * rand(250, 420) + const Offset(0, -300),
          rand(-8, 8), i * pi / 3 + _rot));
    }
    for (final k in _knives) {
      final a = k.a + _rot;
      _debris.add(_Debris.knife(_center + Offset(cos(a), sin(a)) * _r, Offset(cos(a), sin(a)) * rand(300, 500) + const Offset(0, -250),
          rand(-14, 14), a - pi / 2));
    }
    _knives.clear();
    host.fx.burst(_center, const Color(0xFFD9A066),
        colors: const [Color(0xFFD9A066), Color(0xFFA86B3C), Pal.yellow], count: 40, speed: 520, shape: PartShape.square, size: 9, gravity: 900);
    host.fx.ring(_center, Pal.white, size: 180, life: .5);
    host.fx.confetti(count: 100);
    host.fx.pop(host.tr('clear', 'CLEAR!'), const Offset(180, 330), size: 46, life: 1.4);
    final t = host.time;
    host.win(stars: _apple >= 1 && t < 12 ? 3 : (t < 13 ? 2 : 1));
  }

  void _throw() {
    if (_flying || _broken || _clanged || host.finished || _reload > .3) return;
    _flying = true;
    _tipY = _readyTipY;
    host.sfx(Sfx.throwIt, rate: 1.2);
  }

  @override
  void onDown(Offset p) {
    _throw();
  }

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action') _throw();
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF12082A), Color(0xFF3A1250), Color(0xFF7A1F3C)]);
    // spotlight cone
    c.drawPath(
        Path()
          ..moveTo(130, 0)
          ..lineTo(230, 0)
          ..lineTo(330, 640)
          ..lineTo(30, 640)
          ..close(),
        Paint()
          ..shader = const LinearGradient(colors: [Color(0x33FFE9B0), Color(0x00FFE9B0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
              .createShader(const Rect.fromLTWH(0, 0, 360, 640)));
    // floating embers
    for (var i = 0; i < 14; i++) {
      final y = 660 - ((_t * (26 + i * 3) + i * 57) % 700);
      final x = (i * 67 + sin(_t + i) * 18) % 360;
      c.drawCircle(Offset(x, y), 1.5 + i % 3, D.fill(Color.fromRGBO(255, 160, 80, .25 + (i % 4) * .1)));
    }
    // target glow ring behind the log
    final pulse = M.wave(_t, 1.2);
    c.drawCircle(_center, _r + 40 + pulse * 6, D.fill(const Color(0x22FF7AA8)));
    c.drawCircle(_center, _r + 22, D.fill(const Color(0x33FFB36B)));
    // floor
    D.rrect(c, const Rect.fromLTWH(-10, 600, 380, 60), 0, const Color(0xFF1A0C24));

    // knives stuck (drawn under the log so they look embedded)
    final logC = _center + Offset(0, -_logKick * 10);
    for (final k in _knives) {
      _drawStuck(c, logC, k);
    }
    if (!_broken) _drawLog(c, logC);

    for (final d in _debris) {
      c.save();
      c.translate(d.pos.dx, d.pos.dy);
      c.rotate(d.angle);
      if (d.isKnife) {
        _knife(c, old: false);
      } else {
        _wedge(c);
      }
      c.restore();
    }

    // ready / flying knife
    if (!_clanged && !_broken && !host.finished || (_flying)) {
      final y = _flying ? _tipY : _readyTipY + _reload * 140;
      c.save();
      c.translate(180, y);
      _knife(c, old: false);
      c.restore();
      if (_flying) {
        for (var i = 0; i < 3; i++) {
          c.drawLine(Offset(172 + i * 8.0, y + 120), Offset(172 + i * 8.0, y + 190), D.stroke(const Color(0x55FFFFFF), 3));
        }
      }
    }

    _renderHud(c);

    if (host.time < 2 && _thrown == 0) {
      D.hand(c, const Offset(250, 560), _t);
      D.text(c, host.tr('tap', 'TAP!'), const Offset(270, 620), size: 22, stroke: Pal.ink);
    }
  }

  void _renderHud(Canvas c) {
    // knife counter column
    for (var i = 0; i < _need; i++) {
      final used = i < _thrown;
      final o = Offset(26, 590 - i * 34.0);
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(-pi / 4);
      final col = used ? const Color(0x44FFFFFF) : Pal.white;
      D.rrect(c, const Rect.fromLTWH(-3, -14, 6, 16), 3, col);
      D.rrect(c, const Rect.fromLTWH(-4, 2, 8, 10), 2, used ? const Color(0x44FF3B5C) : Pal.red);
      c.restore();
    }
    // apples collected
    final ao = const Offset(312, 70);
    _drawApple(c, ao, 14);
    D.text(c, '$_apple', ao + const Offset(26, 0), size: 22, stroke: Pal.ink);
    // stage progress
    D.text(c, '$_thrown/$_need', const Offset(180, 76), size: 30, color: Pal.white, stroke: Pal.ink);
  }

  void _drawLog(Canvas c, Offset o) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(_rot);
    // bark ring
    c.drawCircle(const Offset(0, 6), _r + 2, D.fill(const Color(0x66000000)));
    final bark = Path();
    for (var i = 0; i < 36; i++) {
      final a = i * pi * 2 / 36;
      final rr = _r + (i.isEven ? 2 : -1.5);
      final p = Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? bark.moveTo(p.dx, p.dy) : bark.lineTo(p.dx, p.dy);
    }
    bark.close();
    c.drawPath(bark, D.fill(const Color(0xFF6B3A1E)));
    c.drawPath(bark, D.stroke(Pal.ink, 4));
    // wood face
    c.drawCircle(Offset.zero, _r - 11, D.fill(const Color(0xFFE8B777)));
    for (var i = 1; i <= 4; i++) {
      c.drawCircle(const Offset(3, 2), (_r - 11) * i / 5, D.stroke(const Color(0x55A0662F), 3));
    }
    c.drawLine(const Offset(10, 0), Offset(_r - 16, 10), D.stroke(const Color(0x88A0662F), 3));
    c.drawLine(const Offset(-8, 6), Offset(-_r + 22, 30), D.stroke(const Color(0x88A0662F), 3));
    // apples on the rim
    for (final ap in _apples) {
      if (ap.cut > 0) continue;
      final p = Offset(cos(ap.a), sin(ap.a)) * (_r + 12);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(ap.a + pi / 2);
      _drawApple(c, Offset.zero, 13);
      c.restore();
    }
    // grumpy face on the log (it spins with it — funny)
    final f = _angry > 0 ? Face.smug : (_logKick > .3 ? Face.shocked : (_thrown >= 6 ? Face.sad : Face.angry));
    D.face(c, const Offset(0, 4), 44, f, blush: false, ink: const Color(0xFF4A2410));
    c.restore();
    if (_logFlash > 0) {
      c.drawCircle(o, _r - 10, D.fill(Color.fromRGBO(255, 255, 255, .45 * _logFlash)));
    }
  }

  void _drawStuck(Canvas c, Offset logC, _Stuck k) {
    final a = k.a + _rot;
    final dir = Offset(cos(a), sin(a));
    final tip = logC + dir * (_r - _embed);
    c.save();
    c.translate(tip.dx, tip.dy);
    c.rotate(a - pi / 2);
    _knife(c, old: k.old);
    c.restore();
  }

  /// Knife with its tip at the origin, extending along +y.
  void _knife(Canvas c, {required bool old}) {
    final blade = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(8, 14, 7, 58)
      ..lineTo(-7, 58)
      ..quadraticBezierTo(-8, 18, 0, 0)
      ..close();
    c.drawPath(blade, D.stroke(Pal.ink, 4));
    c.drawPath(
        blade,
        Paint()
          ..shader = LinearGradient(colors: old ? const [Color(0xFF9A8F80), Color(0xFF6E6458)] : const [Color(0xFFFFFFFF), Color(0xFFA9B6C8)])
              .createShader(const Rect.fromLTWH(-8, 0, 16, 58)));
    c.drawLine(const Offset(-1.5, 12), const Offset(-2.5, 54), D.stroke(const Color(0x88FFFFFF), 2));
    // guard
    D.rrect(c, const Rect.fromLTWH(-12, 56, 24, 8), 4, old ? const Color(0xFF7A6A40) : Pal.gold, border: Pal.ink, borderWidth: 2.5);
    // handle
    D.rrect(c, const Rect.fromLTWH(-6.5, 63, 13, 44), 6, old ? const Color(0xFF4A3A30) : const Color(0xFF8C1F3C),
        border: Pal.ink, borderWidth: 2.5);
    for (var i = 0; i < 3; i++) {
      c.drawCircle(Offset(0, 73 + i * 12.0), 2, D.fill(old ? const Color(0xFF8A7A60) : Pal.yellow));
    }
  }

  void _wedge(Canvas c) {
    final p = Path()
      ..moveTo(0, 0)
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: _r), -pi / 6, pi / 3, false)
      ..close();
    c.drawPath(p, D.fill(const Color(0xFFE8B777)));
    c.drawPath(p, D.stroke(const Color(0xFF6B3A1E), 8));
    c.drawPath(p, D.stroke(Pal.ink, 2.5));
  }

  void _drawApple(Canvas c, Offset o, double r) {
    c.drawCircle(o + Offset(-r * .35, 0), r * .75, D.fill(Pal.red));
    c.drawCircle(o + Offset(r * .35, 0), r * .75, D.fill(Pal.red));
    c.drawOval(Rect.fromCenter(center: o, width: r * 2.1, height: r * 1.7), D.stroke(Pal.ink, 2.5));
    c.drawCircle(o + Offset(-r * .45, -r * .3), r * .22, D.fill(const Color(0xAAFFFFFF)));
    c.drawLine(o + Offset(0, -r * .7), o + Offset(r * .15, -r * 1.2), D.stroke(const Color(0xFF6B3A1E), 3));
    c.drawOval(Rect.fromCenter(center: o + Offset(r * .45, -r * 1.05), width: r * .7, height: r * .35), D.fill(Pal.lime));
  }
}

class _Stuck {
  _Stuck(this.a, {this.old = false});
  final double a; // local log angle
  final bool old;
}

class _Apple {
  _Apple(this.a);
  final double a;
  double cut = 0;
}

class _Debris {
  _Debris.knife(this.pos, this.vel, this.spin, [this.angle = 0]) : isKnife = true;
  _Debris.wedge(this.pos, this.vel, this.spin, this.angle) : isKnife = false;
  Offset pos;
  Offset vel;
  final double spin;
  double angle;
  final bool isKnife;
}
