import '../engine/engine.dart';

/// No.079 Catch the Train! — mash to sprint down the platform, swipe up to
/// hop the stray suitcase, and squeeze through the doors before they shut.
class G079 extends MiniGame {
  static const _ground = 478.0;
  static const _doorX = 306.0; // door center
  static const _bagX = 168.0;
  double _t = 0;
  double _x = 34;
  double _vx = 0;
  double _y = 0; // height above ground (positive up)
  double _vy = 0;
  double _run = 0;
  double _stun = 0;
  bool _tripped = false;
  bool _inside = false;
  bool _smacked = false;
  double _endT = 0;
  double _trainX = 0; // departure offset
  double _bagSpin = 0;
  double _bagKick = 0;
  Offset? _swipeStart;
  bool _swipeUsed = false;
  bool _chimed = false;
  late double _closeStart;
  late double _closeEnd;
  int _taps = 0;

  @override
  void init() {
    final dur = host.duration;
    final k = (host.speed - 1) * .5;
    _closeEnd = dur - .8 - k * .8;
    _closeStart = _closeEnd - 1.6;
  }

  /// Door opening 1 = fully open, 0 = shut.
  double get _door {
    if (_inside) return 1 - M.clamp01(_endT * 5);
    final tm = host.time;
    if (tm < _closeStart) return 1;
    return 1 - M.clamp01((tm - _closeStart) / (_closeEnd - _closeStart));
  }

  bool get _air => _y > 0 || _vy > 0;

  @override
  void update(double dt) {
    _t += dt;
    if (!_chimed && host.time >= _closeStart && !host.finished) {
      _chimed = true;
      host.sfx(Sfx.bell, volume: .8);
      host.sfx(Sfx.whistle, volume: .6);
    }
    if (_stun > 0) _stun -= dt;
    // physics
    if (!_inside) {
      _vx = M.approach(_vx, 0, 1.7, dt);
      if (_air) {
        _vy -= 1500 * dt;
        _y += _vy * dt;
        if (_y <= 0) {
          _y = 0;
          _vy = 0;
          host.sfx(Sfx.land, volume: .6);
          host.fx.smoke(Offset(_x, _ground), count: 3);
        }
      }
      final prev = _x;
      _x += _vx * dt;
      _run += _vx * dt * .09;
      // suitcase collision
      if (!_tripped || _stun <= 0) {
        if (_y < 38 && (_x - _bagX).abs() < 30 && prev < _bagX) {
          _trip();
        }
      }
      // door
      final doorLeft = _doorX - 44;
      if (!host.finished) {
        if (_x >= doorLeft && _door > .35) {
          _board();
        } else if (_x > doorLeft - 18 && _door <= .35) {
          _x = doorLeft - 18;
          if (_vx > 60 && !_smacked) _smack();
          _vx = 0;
        }
        if (_door <= 0 && !_inside) {
          host.sfx(Sfx.aww);
          host.fx.pop(host.tr('miss', 'MISS'), const Offset(180, 190), color: Pal.red, size: 40);
          host.lose();
        }
      } else if (_x > doorLeft - 18) {
        _x = doorLeft - 18;
        _vx = 0;
      }
    } else {
      _x = M.approach(_x, _doorX + 8, 8, dt);
      _endT += dt;
    }
    if (host.finished) {
      _endT += _inside ? 0 : dt;
      if (_endT > .45) _trainX += (_endT - .45) * 900 * dt;
    }
    _bagKick = M.approach(_bagKick, 0, 5, dt);
    _bagSpin = M.approach(_bagSpin, 0, 4, dt);
  }

  void _trip() {
    _tripped = true;
    _stun = .65;
    _vx = -40;
    _x = _bagX - 31;
    _bagKick = 1;
    _bagSpin = 1;
    host.sfx(Sfx.thud);
    host.sfx(Sfx.hurt, volume: .7);
    host.shake(8);
    host.fx.burst(Offset(_bagX, _ground - 30), Pal.yellow, count: 10, speed: 200, shape: PartShape.star, size: 7);
    host.fx.pop(host.tr('oops', 'OOPS!'), Offset(_bagX, _ground - 150), color: Pal.red, size: 30);
  }

  void _board() {
    _inside = true;
    _endT = 0;
    host.sfx(Sfx.whoosh);
    host.sfx(Sfx.cheer, volume: .8);
    host.shake(6);
    host.hitStop(.06);
    host.fx.pop(host.tr('safe', 'SAFE!'), const Offset(200, 190), color: Pal.lime, size: 42);
    host.fx.burst(Offset(_doorX, _ground - 60), Pal.yellow, count: 20, speed: 280, shape: PartShape.star, size: 8);
    final left = host.timeLeft;
    host.win(stars: !_tripped && left > 1.4 ? 3 : (!_tripped || left > 1 ? 2 : 1));
  }

  void _smack() {
    _smacked = true;
    host.sfx(Sfx.slap);
    host.sfx(Sfx.glass, volume: .6);
    host.shake(12, .35);
    host.flash(Pal.red, .1);
  }

  @override
  void onDown(Offset p) {
    _swipeStart = p;
    _swipeUsed = false;
    _dash();
  }

  void _dash() {
    if (host.finished || _stun > 0) return;
    _taps++;
    _vx = min(_vx + 38, 240);
    if (!_air) {
      host.sfx(Sfx.step, rate: .9 + min(_vx, 240) / 400, volume: .7);
      if (_taps.isEven) host.fx.smoke(Offset(_x - 10, _ground), count: 2, size: 10);
    }
  }

  void _jump() {
    if (host.finished || _air || _stun > 0) return;
    _vy = 540;
    _y = .01;
    _vx = max(_vx, 150);
    host.sfx(Sfx.jump);
  }

  @override
  void onMove(Offset p) {
    final s = _swipeStart;
    if (s == null || _swipeUsed) return;
    if (s.dy - p.dy > 30) {
      _swipeUsed = true;
      _jump();
    }
  }

  @override
  void onUp(Offset p) => _swipeStart = null;

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'up') _jump();
    if (key == 'action' || key == 'right') _dash();
  }

  @override
  void onTimeUp() {
    host.sfx(Sfx.aww);
    host.lose();
  }

  @override
  void render(Canvas c) {
    // sky + rays
    D.gradientBg(c, const [Color(0xFF6FD3FF), Color(0xFFFFE9A8)]);
    D.rays(c, const Offset(300, 120), 700, const Color(0x2AFFFFFF), count: 16, t: _t * .3);
    // city silhouettes
    for (var i = 0; i < 7; i++) {
      final h = 80 + (i * 37 % 60).toDouble();
      c.drawRect(Rect.fromLTWH(i * 56.0 - 10, 250 - h, 48, h + 30), D.fill(const Color(0x33306090)));
    }
    // station roof
    c.drawRect(const Rect.fromLTWH(0, 40, 360, 34), D.fill(const Color(0xFF5A6078)));
    D.line(c, const Offset(0, 74), const Offset(360, 74), Pal.ink, 4);
    for (var i = 0; i < 3; i++) {
      c.drawRect(Rect.fromLTWH(20 + i * 120.0, 74, 14, 200), D.fill(const Color(0xFF7A8098)));
    }
    // station sign
    D.rrect(c, const Rect.fromLTWH(40, 96, 130, 44), 8, Pal.white, border: Pal.ink, borderWidth: 4);
    D.text(c, '>>>', const Offset(105, 118), size: 22, color: Pal.green, stroke: Pal.ink, strokeWidth: 4);

    _drawTrain(c);

    // platform
    c.drawRect(const Rect.fromLTWH(0, _ground, 360, 162), D.fill(const Color(0xFFBFC4D6)));
    c.drawRect(const Rect.fromLTWH(0, _ground, 360, 14), D.fill(Pal.yellow));
    for (var i = 0; i < 18; i++) {
      c.drawCircle(Offset(10 + i * 20.0, _ground + 7), 3, D.fill(const Color(0xFFE0B020)));
    }
    D.line(c, const Offset(0, _ground), const Offset(360, _ground), Pal.ink, 4);
    for (var i = 0; i < 5; i++) {
      D.line(c, Offset(i * 90.0, _ground + 30), Offset(i * 90.0 - 60, 640), const Color(0x22000000), 3);
    }

    _drawBag(c);
    if (!_inside || _endT < .2) _drawRunner(c);

    // tap counter / progress arrow
    final prog = M.clamp01((_x - 34) / (_doorX - 44 - 34));
    D.bar(c, const Rect.fromLTWH(40, 560, 280, 22), prog, Pal.lime, border: Pal.ink);
    D.circle(c, Offset(40 + 280 * prog, 571), 14, Pal.white, border: Pal.ink);

    // hints
    if (!host.finished) {
      if (host.time < 1.8) {
        D.hand(c, const Offset(180, 610), _t);
        D.text(c, host.tr('tap', 'TAP!'), const Offset(90, 612), size: 26, color: Pal.yellow, stroke: Pal.ink);
      }
      final dist = _bagX - _x;
      if (dist > 0 && dist < 140 && !_air) {
        final pulse = 1 + .15 * sin(_t * 20);
        c.save();
        c.translate(_x + 20, _ground - 170);
        c.scale(pulse);
        D.arrow(c, Offset.zero, const Offset(0, -1), 60, Pal.orange, width: 16);
        c.restore();
        D.text(c, host.tr('swipe', 'SWIPE!'), Offset(_x + 20, _ground - 230), size: 22, color: Pal.orange,
            stroke: Pal.ink);
      }
    }
  }

  void _drawTrain(Canvas c) {
    final ox = _trainX;
    final top = 200.0;
    final body = Rect.fromLTWH(242 + ox, top, 240, _ground - top + 8);
    D.rrect(c, body.shift(const Offset(0, 6)), 24, const Color(0x44000000));
    D.rrect(c, body, 24, const Color(0xFFEFF3FA), border: Pal.ink, borderWidth: 5);
    c.drawRect(Rect.fromLTWH(body.left, top + 150, body.width, 16), D.fill(Pal.green));
    c.drawRect(Rect.fromLTWH(body.left, top + 170, body.width, 6), D.fill(Pal.orange));
    // window with squished commuters (left of door)
    final win = Rect.fromLTWH(body.left + 14, top + 36, 12, 90);
    D.rrect(c, win, 4, const Color(0xFF7FC8FF), border: Pal.ink, borderWidth: 3);
    // door frame
    final dl = _doorX - 44 + ox, dr = _doorX + 44 + ox;
    final doorRect = Rect.fromLTRB(dl, top + 26, dr, _ground);
    // interior: packed people
    c.save();
    c.clipRect(doorRect);
    c.drawRect(doorRect, D.fill(const Color(0xFFFFE6A8)));
    for (var i = 0; i < 6; i++) {
      final px = dl + 8 + (i % 3) * 30.0;
      final py = top + 80 + (i ~/ 3) * 34.0 + sin(_t * 3 + i) * 2;
      c.drawCircle(Offset(px, py), 18, D.fill(i.isEven ? Pal.skin : Color.lerp(Pal.skin, Pal.skinDark, .5)!));
      c.drawCircle(Offset(px, py), 18, D.stroke(Pal.ink, 2.5));
      D.face(c, Offset(px, py), 15,
          _inside ? Face.shocked : (i % 3 == 1 ? Face.sleepy : Face.neutral), blush: false);
    }
    // the runner squeezed inside after boarding
    if (_inside && _endT >= .2) {
      final o = Offset(_doorX + ox, _ground - 60);
      c.drawCircle(o + const Offset(0, -24), 22, D.fill(Pal.skin));
      c.drawCircle(o + const Offset(0, -24), 22, D.stroke(Pal.ink, 3));
      D.face(c, o + const Offset(0, -22), 18, Face.happy);
      D.rrect(c, Rect.fromCenter(center: o + const Offset(0, 20), width: 40, height: 50), 12, Pal.white,
          border: Pal.ink, borderWidth: 3);
    }
    c.restore();
    // sliding doors
    final open = _door;
    final pw = 44 * (1 - open);
    for (final s in [-1.0, 1.0]) {
      final r = s < 0 ? Rect.fromLTWH(dl, doorRect.top, pw + 1, doorRect.height) : Rect.fromLTRB(dr - pw - 1, doorRect.top, dr, doorRect.bottom);
      if (pw > 1) {
        D.rrect(c, r, 4, const Color(0xFFD7DCE8), border: Pal.ink, borderWidth: 3);
        final wx = s < 0 ? r.right - 22 : r.left + 6;
        if (pw > 24) D.rrect(c, Rect.fromLTWH(wx, r.top + 14, 16, 70), 4, const Color(0xFF9FD8FF));
      }
    }
    c.drawRect(doorRect, D.stroke(Pal.ink, 4));
    // warning lamp
    final warn = host.time >= _closeStart && open > 0 && (_t * 6).floor().isEven;
    c.drawCircle(Offset(_doorX + ox, top + 14), 9, D.fill(warn ? Pal.red : const Color(0xFF884444)));
    c.drawCircle(Offset(_doorX + ox, top + 14), 9, D.stroke(Pal.ink, 3));
    if (warn) c.drawCircle(Offset(_doorX + ox, top + 14), 18, D.fill(const Color(0x55FF3B5C)));
    // wheels
    for (final wx in [270.0, 350.0, 440.0]) {
      c.drawCircle(Offset(wx + ox, _ground + 4), 14, D.fill(const Color(0xFF333344)));
    }
  }

  void _drawBag(Canvas c) {
    final o = Offset(_bagX + _bagKick * 8, _ground);
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(sin(_t * 30) * .15 * _bagSpin);
    D.rrect(c, const Rect.fromLTWH(-24, -44, 48, 40), 8, Pal.purple, border: Pal.ink, borderWidth: 4);
    D.line(c, const Offset(-10, -44), const Offset(-10, -62), Pal.ink, 4);
    D.line(c, const Offset(10, -44), const Offset(10, -62), Pal.ink, 4);
    D.line(c, const Offset(-12, -62), const Offset(12, -62), Pal.ink, 5);
    D.rrect(c, const Rect.fromLTWH(-24, -30, 48, 6), 2, const Color(0x55FFFFFF));
    D.star(c, const Offset(8, -20), 7, Pal.yellow);
    c.drawCircle(const Offset(-14, -2), 5, D.fill(Pal.ink));
    c.drawCircle(const Offset(14, -2), 5, D.fill(Pal.ink));
    c.restore();
  }

  void _drawRunner(Canvas c) {
    final feet = Offset(_x, _ground - _y);
    D.shadow(c, Offset(_x, _ground + 2), 50 - min(_y, 60) * .3, 12);
    final fast = _vx > 120;
    if (fast && !_air) {
      for (var i = 0; i < 3; i++) {
        D.line(c, feet + Offset(-40 - i * 10.0, -40 - i * 24.0), feet + Offset(-80 - i * 16.0, -40 - i * 24.0),
            const Color(0x88FFFFFF), 4);
      }
    }
    c.save();
    c.translate(feet.dx, feet.dy);
    if (_stun > 0) {
      c.rotate(-pi / 2 * M.clamp01((.65 - _stun) * 8));
    } else {
      c.rotate(min(_vx, 240) / 240 * .25);
    }
    if (_smacked) c.scale(.7, 1.1);
    final face = _smacked ? Face.dead : (_stun > 0 ? Face.dead : (_air ? Face.shocked : Face.angry));
    D.person(c, Offset.zero, 108, Pal.white,
        running: !_air && _stun <= 0, run: _run, face: face, hair: const Color(0xFF2E2238), pants: const Color(0xFF2C3148));
    // tie flapping
    final flap = sin(_t * 25) * 6;
    c.drawPath(
        Path()
          ..moveTo(0, -68)
          ..lineTo(-18 - _vx * .06, -58 + flap)
          ..lineTo(-14 - _vx * .06, -50 + flap)
          ..close(),
        D.fill(Pal.red));
    // briefcase
    D.rrect(c, const Rect.fromLTWH(10, -54, 26, 20), 4, const Color(0xFF6B3B1F), border: Pal.ink, borderWidth: 3);
    c.restore();
    if (!_air && _stun <= 0 && host.timeLeft < 2 && !host.finished) {
      c.drawCircle(feet + Offset(24, -96 + (_t * 80) % 16), 6, D.fill(const Color(0xFF7FD3FF)));
    }
    if (_stun > 0) {
      for (var i = 0; i < 3; i++) {
        final a = _t * 8 + i * 2.1;
        D.star(c, feet + Offset(-40 + cos(a) * 26, -30 + sin(a) * 8), 7, Pal.yellow, border: Pal.ink);
      }
    }
  }
}
