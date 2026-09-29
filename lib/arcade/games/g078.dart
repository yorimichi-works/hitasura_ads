import '../engine/engine.dart';

/// No.078 Stamp It! — documents slide past; tap to slam the hanko on the
/// approved ones (green check) and never on the skull ones. The boss watches.
class G078 extends MiniGame {
  static const _stampX = 180.0;
  static const _docY = 400.0;
  static const _need = 4;
  double _t = 0;
  final _docs = <_Doc>[];
  double _stamp = 0; // 0 up .. 1 down (visual)
  double _stampAnim = -1; // time since tap, -1 idle
  bool _impactDone = false;
  int _ok = 0;
  int _missed = 0;
  int _mood = 0; // 0 watching, 1 pleased, 2 furious
  double _moodT = 0;
  double _steam = 0;

  double get _v => 185 * host.speed;

  @override
  void init() {
    var x = 420.0;
    var goods = 0;
    for (var i = 0; i < 16; i++) {
      final forceGood = i < 7 && goods < 5 && (7 - i) <= (5 - goods);
      final good = forceGood || (i > 0 && !_docs[i - 1].good) || chance(.6);
      if (good) goods++;
      _docs.add(_Doc(x, good, rand(-.06, .06), randInt(3)));
      x += 150 + rand(0, 40);
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    final moving = !host.finished || _mood == 1;
    for (final d in _docs) {
      if (moving) d.x -= _v * dt;
      if (d.fly > 0) {
        d.fly += dt;
      }
      if (!d.counted && d.x < -70) {
        d.counted = true;
        if (d.good && !d.stamped && !host.finished) {
          _missed++;
          host.sfx(Sfx.oops, volume: .6);
          _setMood(0, .1);
        }
      }
    }
    if (_stampAnim >= 0) {
      _stampAnim += dt;
      final down = .07 / host.speed.clamp(1, 1.4);
      if (_stampAnim < down) {
        _stamp = _stampAnim / down;
      } else {
        if (!_impactDone) {
          _impactDone = true;
          _impact();
        }
        _stamp = 1 - M.clamp01((_stampAnim - down - .06) / .12);
        if (_stampAnim > down + .2) _stampAnim = -1;
      }
    }
    _moodT -= dt;
    if (_moodT <= 0 && _mood == 1 && !host.finished) _mood = 0;
    if (_mood == 2) _steam += dt;
  }

  void _setMood(int m, double t) {
    _mood = m;
    _moodT = t;
  }

  void _impact() {
    _Doc? hit;
    for (final d in _docs) {
      if (!d.stamped && (d.x - _stampX).abs() < 60) {
        hit = d;
        break;
      }
    }
    final at = Offset(_stampX, _docY);
    host.shake(5);
    host.fx.ring(at, const Color(0x88FFFFFF), size: 60, life: .25);
    if (hit == null) {
      host.sfx(Sfx.thud, rate: .9);
      host.fx.smoke(at + const Offset(0, 60), count: 4);
      return;
    }
    hit.stamped = true;
    hit.stampOff = _stampX - hit.x;
    host.sfx(Sfx.stamp);
    host.hitStop(.05);
    if (hit.good) {
      _ok++;
      host.sfx(Sfx.correct, rate: 1 + _ok * .08, volume: .8);
      host.fx.burst(at, Pal.red, count: 10, speed: 180, size: 5, gravity: 300);
      host.fx.pop('$_ok/$_need', at + const Offset(0, -80), color: Pal.lime, size: 30);
      host.addScore(100);
      _setMood(1, .6);
      if (_ok >= _need) {
        _setMood(1, 99);
        host.sfx(Sfx.fanfare, volume: .7);
        host.fx.coins(const Offset(180, 160), count: 18);
        host.fx.pop(host.tr('perfect', 'PERFECT!'), const Offset(180, 250), color: Pal.yellow, size: 38);
        host.win(stars: _missed == 0 ? 3 : (_missed == 1 ? 2 : 1));
      }
    } else {
      _setMood(2, 99);
      hit.fly = .001;
      host.sfx(Sfx.buzzer);
      host.sfx(Sfx.explode, volume: .7);
      host.shake(14, .4);
      host.flash(Pal.red, .2);
      host.fx.burst(const Offset(180, 150), Pal.red, count: 24, speed: 340, size: 8);
      host.lose();
    }
  }

  @override
  void onDown(Offset p) {
    if (_stampAnim >= 0 || host.finished) return;
    _stampAnim = 0;
    _impactDone = false;
    host.sfx(Sfx.whoosh, volume: .5, rate: 1.5);
  }

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action') onDown(Offset.zero);
  }

  @override
  void onTimeUp() {
    _setMood(2, 99);
    host.sfx(Sfx.buzzer);
    host.lose();
  }

  @override
  void render(Canvas c) {
    // office
    D.gradientBg(c, const [Color(0xFFFFE08A), Color(0xFFFFB347)]);
    D.rays(c, const Offset(180, 150), 700, const Color(0x22FFFFFF), count: 18, t: _t * .3);
    // window blinds behind boss
    D.rrect(c, const Rect.fromLTWH(30, 50, 300, 190), 10, const Color(0xFF9FD8FF), border: Pal.ink, borderWidth: 4);
    for (var i = 0; i < 9; i++) {
      D.line(c, Offset(34, 62 + i * 20.0), Offset(326, 62 + i * 20.0), const Color(0x88FFFFFF), 6);
    }

    _drawBoss(c);

    // desk
    c.drawRect(const Rect.fromLTWH(0, 280, 360, 360), D.fill(const Color(0xFF8A5A3C)));
    c.drawRect(const Rect.fromLTWH(0, 272, 360, 16), D.fill(const Color(0xFFB07446)));
    D.line(c, const Offset(0, 272), const Offset(360, 272), Pal.ink, 4);
    // conveyor belt
    D.rrect(c, const Rect.fromLTWH(-10, 318, 380, 164), 0, const Color(0xFF3A3F55));
    for (var i = 0; i < 14; i++) {
      final x = ((i * 30.0 - _t * _v * (host.finished && _mood != 1 ? 0 : 1)) % 420) - 30;
      D.line(c, Offset(x, 322), Offset(x, 478), const Color(0xFF4C536E), 4);
    }
    D.line(c, const Offset(0, 318), const Offset(360, 318), Pal.ink, 4);
    D.line(c, const Offset(0, 482), const Offset(360, 482), Pal.ink, 4);
    // target zone
    D.rrect(c, const Rect.fromLTWH(_stampX - 62, 326, 124, 148), 12, const Color(0x22FFFFFF),
        border: const Color(0x88FFD23F), borderWidth: 3);

    for (final d in _docs) {
      if (d.x < -100 || d.x > 460) continue;
      _drawDoc(c, d);
    }

    _drawStamp(c);

    // progress tray
    D.rrect(c, const Rect.fromLTWH(20, 520, 320, 90), 20, const Color(0x55000000));
    for (var i = 0; i < _need; i++) {
      final o = Offset(70 + i * 73.0, 565);
      final done = i < _ok;
      c.drawCircle(o, 28, D.fill(done ? Pal.white : const Color(0x33FFFFFF)));
      c.drawCircle(o, 28, D.stroke(done ? Pal.red : const Color(0x55FFFFFF), 5));
      if (done) _hankoMark(c, o, 20);
    }

    if (host.time < 2 && _ok == 0) {
      D.hand(c, const Offset(300, 400), _t);
      D.text(c, host.tr('tap', 'TAP!'), const Offset(300, 370), size: 22, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _drawDoc(Canvas c, _Doc d) {
    var o = Offset(d.x, _docY);
    var rot = d.rot;
    if (d.fly > 0) {
      o += Offset(d.fly * 300, -d.fly * 700 + d.fly * d.fly * 900);
      rot += d.fly * 12;
    }
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(rot);
    const r = Rect.fromLTWH(-52, -68, 104, 136);
    D.rrect(c, r.shift(const Offset(4, 6)), 6, const Color(0x55000000));
    D.rrect(c, r, 6, Pal.white, border: Pal.ink, borderWidth: 3);
    // dog-ear
    c.drawPath(
        Path()
          ..moveTo(52, -68)
          ..lineTo(52, -50)
          ..lineTo(34, -68)
          ..close(),
        D.fill(const Color(0xFFDDDDDD)));
    // fake text lines
    for (var i = 0; i < 4; i++) {
      D.rrect(c, Rect.fromLTWH(-40, -56 + i * 11.0, i == d.lines ? 50 : 76, 5), 2, const Color(0xFFB8B8C8));
    }
    // verdict icon
    const ic = Offset(0, 22);
    if (d.good) {
      c.drawCircle(ic, 26, D.fill(Pal.green));
      c.drawCircle(ic, 26, D.stroke(Pal.ink, 3.5));
      D.line(c, ic + const Offset(-12, 0), ic + const Offset(-3, 10), Pal.white, 7);
      D.line(c, ic + const Offset(-3, 10), ic + const Offset(13, -10), Pal.white, 7);
    } else {
      _skull(c, ic);
    }
    if (d.stamped) _hankoMark(c, Offset(d.stampOff, 0), 34);
    c.restore();
  }

  void _skull(Canvas c, Offset o) {
    c.drawCircle(o, 26, D.fill(Pal.red));
    c.drawCircle(o, 26, D.stroke(Pal.ink, 3.5));
    c.drawCircle(o + const Offset(0, -3), 14, D.fill(Pal.white));
    D.rrect(c, Rect.fromCenter(center: o + const Offset(0, 10), width: 16, height: 10), 3, Pal.white);
    c.drawCircle(o + const Offset(-5, -4), 4, D.fill(Pal.ink));
    c.drawCircle(o + const Offset(5, -4), 4, D.fill(Pal.ink));
    D.line(c, o + const Offset(-3, 10), o + const Offset(-3, 14), Pal.ink, 2);
    D.line(c, o + const Offset(3, 10), o + const Offset(3, 14), Pal.ink, 2);
  }

  /// Red hanko imprint (circle + stylized mark).
  void _hankoMark(Canvas c, Offset o, double r) {
    const red = Color(0xDDE0203A);
    c.drawCircle(o, r, D.stroke(red, r * .14));
    c.drawCircle(o, r * .78, D.stroke(red, r * .05));
    D.star(c, o, r * .5, red);
  }

  void _drawStamp(Canvas c) {
    final y = M.lerp(236, _docY - 18, M.easeInOut(_stamp.clamp(0, 1)));
    final bob = _stampAnim < 0 ? sin(_t * 5) * 4 : 0.0;
    final o = Offset(_stampX, y + bob);
    D.shadow(c, const Offset(_stampX, _docY + 20), 80 - _stamp * 20, 16, .15 + _stamp * .2);
    // handle
    D.rrect(c, Rect.fromCenter(center: o + const Offset(0, -86), width: 40, height: 80), 20, const Color(0xFFC98B4E),
        border: Pal.ink, borderWidth: 4);
    c.drawCircle(o + const Offset(0, -128), 22, D.fill(const Color(0xFFC98B4E)));
    c.drawCircle(o + const Offset(0, -128), 22, D.stroke(Pal.ink, 4));
    // base
    D.rrect(c, Rect.fromCenter(center: o + const Offset(0, -30), width: 76, height: 40), 10, const Color(0xFF6B3B1F),
        border: Pal.ink, borderWidth: 4);
    D.rrect(c, Rect.fromCenter(center: o + const Offset(0, -6), width: 70, height: 14), 5, const Color(0xFFE0203A),
        border: Pal.ink, borderWidth: 3);
  }

  void _drawBoss(Canvas c) {
    const o = Offset(180, 170);
    final furious = _mood == 2;
    final pleased = _mood == 1;
    final shake = furious ? sin(_t * 60) * 4 : 0.0;
    // suit
    D.rrect(c, const Rect.fromLTWH(80, 200, 200, 90), 40, const Color(0xFF2C3148), border: Pal.ink, borderWidth: 5);
    c.drawPath(
        Path()
          ..moveTo(160, 205)
          ..lineTo(200, 205)
          ..lineTo(180, 240)
          ..close(),
        D.fill(Pal.white));
    c.drawPath(
        Path()
          ..moveTo(174, 212)
          ..lineTo(186, 212)
          ..lineTo(192, 268)
          ..lineTo(180, 280)
          ..lineTo(168, 268)
          ..close(),
        D.fill(Pal.red));
    // head
    final h = o + Offset(shake, 0);
    final skin = furious ? Color.lerp(Pal.skin, Pal.red, M.clamp01(_steam * 3) * .8)! : Pal.skin;
    c.drawOval(Rect.fromCenter(center: h, width: 130, height: 120), D.fill(skin));
    // side hair
    for (final s in [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: h + Offset(s * 58, 6), width: 26, height: 44), D.fill(const Color(0xFF888899)));
    }
    c.drawOval(Rect.fromCenter(center: h, width: 130, height: 120), D.stroke(Pal.ink, 5));
    // shine on bald head
    c.drawOval(Rect.fromCenter(center: h + const Offset(-24, -38), width: 30, height: 14), D.fill(const Color(0x88FFFFFF)));
    final f = furious ? Face.angry : (pleased ? Face.happy : Face.neutral);
    D.face(c, h + const Offset(0, -4), 48, f, look: const Offset(0, 1), blush: pleased);
    // mustache
    for (final s in [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: h + Offset(s * 14, 20), width: 30, height: 12), D.fill(const Color(0xFF555566)));
    }
    if (furious) {
      for (var i = 0; i < 3; i++) {
        final k = (_steam * 1.5 + i / 3) % 1.0;
        c.drawCircle(h + Offset(-70 + i * 70.0, -60 - k * 50), 10 + k * 12, D.fill(D.withAlpha(Pal.white, .8 * (1 - k))));
      }
      // vein
      final v = h + const Offset(34, -34);
      D.line(c, v + const Offset(-8, -3), v + const Offset(8, 3), Pal.red, 4);
      D.line(c, v + const Offset(-3, 8), v + const Offset(3, -8), Pal.red, 4);
    }
    if (pleased) {
      D.star(c, h + Offset(-80, -30 + sin(_t * 10) * 4), 12, Pal.yellow, border: Pal.ink);
      D.star(c, h + Offset(80, -30 + cos(_t * 10) * 4), 12, Pal.yellow, border: Pal.ink);
    }
  }
}

class _Doc {
  _Doc(this.x, this.good, this.rot, this.lines);
  double x;
  final bool good;
  final double rot;
  final int lines;
  bool stamped = false;
  double stampOff = 0;
  bool counted = false;
  double fly = 0;
}
