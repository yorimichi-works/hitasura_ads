import '../engine/engine.dart';

/// No.065 Flip It! — swipe up to flip the pancake, then slide the pan under it.
class G065 extends MiniGame {
  double _t = 0;
  double _panX = 180;
  double _targetX = 180;
  double _panBounce = 0;
  int _state = 0; // 0 in pan, 1 airborne, 2 caught, 3 on floor, 4 burnt
  Offset _pos = const Offset(180, _panY - 8);
  Offset _vel = Offset.zero;
  double _ang = 0;
  double _spin = 0;
  double _gravity = 0;
  Offset? _swipeStart;
  double _endT = 0;
  double _dogX = 330;
  double _dogJump = 0;
  double _steam = 0;
  double _cookAtFlip = 0;

  static const _panY = 470.0;
  static const _floorY = 600.0;

  // How cooked the bottom side is: 0 raw → 1 golden → 2 burnt.
  double get _cook => _state == 0 ? min(2.2, host.time / 1.4 * host.speed) : _cookAtFlip;

  @override
  void init() {
    _panX = rand(130, 230);
    _targetX = _panX;
    _pos = Offset(_panX, _panY - 8);
  }

  @override
  void update(double dt) {
    _t += dt;
    _panBounce = M.approach(_panBounce, 0, 7, dt);
    if (_state <= 1) _panX = M.approach(_panX, _targetX, 14, dt);
    _steam += dt;
    switch (_state) {
      case 0:
        _pos = Offset(_panX, _panY - 8 - (M.wave(_t, 3) * 2));
        if (_steam > .18) {
          _steam = 0;
          host.fx.smoke(Offset(_panX + rand(-40, 40), _panY - 16),
              count: 1, size: 10, color: _cook > 1.6 ? const Color(0xAA444444) : const Color(0x99FFFFFF));
        }
      case 1:
        _vel += Offset(0, _gravity * dt);
        _pos += _vel * dt;
        _ang += _spin * dt;
        if (_vel.dy > 0 && _pos.dy >= _panY - 8 && _pos.dy - _vel.dy * dt < _panY - 8) {
          final off = _pos.dx - _panX;
          if (off.abs() < 62) {
            _catch(off);
            return;
          }
          host.sfx(Sfx.whoosh, rate: .7);
        }
        if (_pos.dy > _floorY - 10) _floor();
        if (_pos.dx < -60 || _pos.dx > 420) _floor();
      case 2:
        _pos = Offset(_panX + (_pos.dx - _panX) * .9, _panY - 8);
        _endT += dt;
      case 3:
        _endT += dt;
        _dogX = M.approach(_dogX, _pos.dx + 30, 9, dt);
        _dogJump = max(0, 1 - (_endT - .15) * 2.5);
      case 4:
        _endT += dt;
        if (_steam > .08) {
          _steam = 0;
          host.fx.smoke(Offset(_panX + rand(-40, 40), _panY - 16), count: 2, size: 18, color: const Color(0xCC333333));
        }
    }
  }

  void _flip() {
    if (_state != 0 || host.finished) return;
    final sp = host.speed;
    _state = 1;
    _cookAtFlip = _cook;
    final vy = 820 * sqrt(sp);
    _gravity = 1300 * sp;
    final air = 2 * vy / _gravity;
    _spin = 3 * pi / air; // lands golden side up after 1.5 turns
    var vx = rand(80, 150) * sqrt(sp) * (chance(.5) ? 1 : -1);
    final land = _pos.dx + vx * air;
    if (land < 60 || land > 300) vx = -vx;
    _vel = Offset(vx, -vy);
    _panBounce = 1;
    host.sfx(Sfx.flip);
    host.sfx(Sfx.whoosh, rate: 1.2, volume: .6);
    host.fx.burst(Offset(_panX, _panY - 10), const Color(0xFFFFF4DC), count: 8, speed: 180, gravity: 600);
  }

  void _catch(double off) {
    _state = 2;
    _ang = pi;
    _pos = Offset(_pos.dx, _panY - 8);
    _panBounce = 1;
    host.sfx(Sfx.sizzle);
    host.sfx(Sfx.correct, volume: .8);
    host.shake(4);
    host.punch(.05);
    host.fx.sparkle(Offset(_panX, _panY - 30), count: 14, radius: 60, color: Pal.yellow);
    host.fx.burst(Offset(_panX, _panY - 16), Pal.gold, count: 12, speed: 220);
    final cook = _cookAtFlip;
    final golden = cook > .6 && cook < 1.7;
    final stars = golden ? (off.abs() < 30 ? 3 : 2) : 1;
    host.fx.pop(
        golden
            ? host.tr('perfect', 'PERFECT!')
            : (cook >= 1.7 ? host.tr('crispy', 'CRISPY...') : host.tr('good', 'GOOD')),
        Offset(_panX.clamp(90, 270), 330),
        color: golden ? Pal.lime : Pal.orange,
        size: 36);
    host.win(stars: stars);
  }

  void _floor() {
    if (_state != 1) return;
    _state = 3;
    _pos = Offset(_pos.dx.clamp(40, 320), _floorY - 10);
    _dogX = _pos.dx > 180 ? -40 : 400;
    _ang = pi;
    host.sfx(Sfx.splat);
    host.sfx(Sfx.chomp, rate: .9);
    host.shake(6);
    host.fx.pop(host.tr('oops', 'OOPS!'), Offset(_pos.dx, 520), color: Pal.red, size: 36);
    host.lose();
  }

  @override
  void onDown(Offset p) {
    _swipeStart = p;
    _targetX = p.dx.clamp(70, 290);
  }

  @override
  void onMove(Offset p) {
    _targetX = p.dx.clamp(70, 290);
    final s = _swipeStart;
    if (s != null && p.dy - s.dy < -40) {
      _swipeStart = null;
      _flip();
    }
  }

  @override
  void onUp(Offset p) => _swipeStart = null;

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'up' || key == 'action') _flip();
    if (key == 'left') _targetX = (_targetX - 50).clamp(70, 290);
    if (key == 'right') _targetX = (_targetX + 50).clamp(70, 290);
  }

  @override
  void onTimeUp() {
    if (_state == 0) {
      _state = 4;
      _cookAtFlip = 2.2;
      host.sfx(Sfx.fire);
      host.fx.pop(host.tr('burnt', 'BURNT!'), Offset(_panX.clamp(90, 270), 360), color: Pal.red, size: 38);
    }
    host.lose();
  }

  Color _sideColor(double cook) {
    if (cook < 1) return Color.lerp(const Color(0xFFFFF0C8), const Color(0xFFE8A040), cook)!;
    return Color.lerp(const Color(0xFFE8A040), const Color(0xFF3A2414), M.clamp01((cook - 1) / 1.1))!;
  }

  @override
  void render(Canvas c) {
    // kitchen tiles + comic rays
    D.gradientBg(c, const [Color(0xFFFFE9A8), Color(0xFFFFB86B)]);
    final tile = D.fill(const Color(0x22FFFFFF));
    for (var y = 40.0; y < 600; y += 40) {
      for (var x = ((y ~/ 40).isEven ? 0.0 : 40.0); x < 360; x += 80) {
        c.drawRect(Rect.fromLTWH(x, y, 40, 40), tile);
      }
    }
    D.rays(c, Offset(_state == 1 ? _pos.dx : _panX, _state == 1 ? _pos.dy : 360), 700, const Color(0x22FFFFFF),
        count: 18, t: _t * .4);
    // shelf with hanging utensils
    D.rrect(c, const Rect.fromLTWH(20, 70, 320, 14), 4, const Color(0xFF9A5B34), border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < 4; i++) {
      final x = 60.0 + i * 80;
      final sw = sin(_t * 2 + i) * .05;
      c.save();
      c.translate(x, 84);
      c.rotate(sw);
      D.line(c, Offset.zero, const Offset(0, 50), Pal.ink, 5);
      if (i.isEven) {
        c.drawOval(const Rect.fromLTWH(-12, 44, 24, 32), D.fill(const Color(0xFFB0B6C8)));
        c.drawOval(const Rect.fromLTWH(-12, 44, 24, 32), D.stroke(Pal.ink, 3));
      } else {
        D.rrect(c, const Rect.fromLTWH(-14, 44, 28, 30), 4, const Color(0xFFB0B6C8), border: Pal.ink, borderWidth: 3);
        for (var k = 0; k < 3; k++) {
          D.line(c, Offset(-7 + k * 7.0, 50), Offset(-7 + k * 7.0, 68), Pal.ink, 2);
        }
      }
      c.restore();
    }
    // floor
    c.drawRect(const Rect.fromLTWH(0, _floorY, 360, 40), D.fill(const Color(0xFFB9784F)));
    for (var x = 0.0; x < 360; x += 60) {
      D.line(c, Offset(x, _floorY), Offset(x, 640), const Color(0x55000000), 2);
    }
    D.line(c, const Offset(0, _floorY), const Offset(360, _floorY), Pal.ink, 4);

    _drawDog(c);

    // landing shadow while airborne
    if (_state == 1) {
      D.shadow(c, Offset(_pos.dx, _panY + 30), 90, 14, .18);
    }

    _drawPan(c, back: true);
    if (_state != 3) _drawPancake(c);
    _drawPan(c, back: false);
    if (_state == 3 && _endT < .35) _drawPancake(c);

    if (host.time < 2 && _state == 0) {
      D.arrow(c, Offset(_panX, _panY - 110), const Offset(0, -1), 80, Pal.yellow, width: 14);
      D.hand(c, Offset(_panX + 30, _panY - 40), _t);
      D.text(c, host.tr('swipe', 'SWIPE!'), Offset(_panX, _panY - 180), size: 24, stroke: Pal.ink);
    }
    if (_state == 1 && _vel.dy > 0) {
      D.text(c, host.tr('catch', 'CATCH!'), Offset(_pos.dx.clamp(70, 290), _pos.dy - 60), size: 22,
          color: Pal.white, stroke: Pal.ink);
    }
  }

  void _drawPan(Canvas c, {required bool back}) {
    final bounce = sin(_panBounce * pi) * 10;
    final o = Offset(_panX, _panY + bounce);
    if (back) {
      // arm + handle coming from bottom-left
      final grip = o + const Offset(-150, 70);
      D.line(c, o + const Offset(-70, 8), grip, Pal.ink, 18);
      D.line(c, o + const Offset(-70, 8), grip, const Color(0xFF3A3040), 11);
      D.line(c, grip, grip + const Offset(-60, 90), Pal.ink, 38);
      D.line(c, grip, grip + const Offset(-60, 90), Pal.sky, 30);
      c.drawCircle(grip, 20, D.fill(Pal.skin));
      c.drawCircle(grip, 20, D.stroke(Pal.ink, 4));
      // pan body (outer rim + inner)
      final outer = Rect.fromCenter(center: o, width: 180, height: 56);
      c.drawOval(outer.shift(const Offset(0, 12)), D.fill(const Color(0xFF1E1A2C)));
      c.drawOval(outer.shift(const Offset(0, 12)), D.stroke(Pal.ink, 4));
      c.drawOval(outer, D.fill(const Color(0xFF3B3650)));
      c.drawOval(outer, D.stroke(Pal.ink, 4));
      c.drawOval(outer.deflate(10), D.fill(const Color(0xFF2A2640)));
      c.drawArc(outer.deflate(16), pi * 1.1, .8, false, D.stroke(const Color(0x55FFFFFF), 3));
      if (_state == 4) {
        D.flame(c, o + const Offset(-40, 36), 26, _t);
        D.flame(c, o + const Offset(30, 38), 32, _t + 1);
      }
    }
  }

  void _drawPancake(Canvas c) {
    final a = _ang;
    const tilt = .38;
    final s = sin(tilt + a);
    final ry = max(3.0, 54 * s.abs());
    final showTop = s >= 0; // top = the side that was up in the pan (raw)
    final col = showTop ? _sideColor(_state == 0 ? 0.05 : .1) : _sideColor(_cook);
    final squash = _state == 2 ? 1 + .25 * max(0.0, 1 - _endT * 4) : 1.0;
    final flat = _state == 3 ? 1.6 : 1.0;
    c.save();
    c.translate(_pos.dx, _pos.dy);
    c.rotate(_state == 1 ? sin(a) * .25 : 0);
    c.scale(squash * flat, 1 / squash / flat);
    final r = Rect.fromCenter(center: Offset.zero, width: 116, height: ry * 2);
    // thickness
    c.drawOval(r.shift(Offset(0, s >= 0 ? 7 : -7)), D.fill(const Color(0xFFD9954A)));
    c.drawOval(r.shift(Offset(0, s >= 0 ? 7 : -7)), D.stroke(Pal.ink, 3.5));
    c.drawOval(r, D.fill(col));
    c.drawOval(r, D.stroke(Pal.ink, 3.5));
    if (!showTop && ry > 8) {
      // golden mottling / bubbles
      final dp = D.fill(Color.lerp(col, Pal.ink, .18)!);
      for (var i = 0; i < 6; i++) {
        c.drawCircle(Offset(-34 + i * 13.0, (i.isEven ? -.3 : .3) * ry), 4, dp);
      }
    } else if (ry > 8) {
      final bp = D.fill(const Color(0x33B9784F));
      for (var i = 0; i < 5; i++) {
        c.drawCircle(Offset(-30 + i * 15.0, (i.isEven ? -.35 : .25) * ry), 3, bp);
      }
    }
    c.restore();
    if (_state == 2) {
      // butter + syrup + happy face
      final t = M.clamp01(_endT * 3);
      final bo = _pos + Offset(0, -18 - (1 - t) * 90);
      D.rrect(c, Rect.fromCenter(center: bo, width: 26, height: 16), 4, const Color(0xFFFFF1A0), border: Pal.ink, borderWidth: 2.5);
      if (_endT > .3) {
        final sy = M.clamp01((_endT - .3) * 2);
        c.drawOval(Rect.fromCenter(center: _pos + const Offset(8, -4), width: 70 * sy, height: 22 * sy),
            D.fill(const Color(0xCC8A4A10)));
      }
      D.face(c, _pos + const Offset(0, -2), 22, Face.happy, blush: true);
    } else if (_state == 1 || _state == 0) {
      if (ry > 14) {
        D.face(c, _pos + const Offset(0, -2), 18, _state == 1 ? Face.shocked : (_cook > 1.4 ? Face.cry : Face.sleepy),
            blush: false);
      }
    }
  }

  void _drawDog(Canvas c) {
    // dog waiting in the corner, drooling
    final eating = _state == 3;
    final baseX = eating ? _dogX : 318.0;
    final hop = eating ? -sin(M.clamp01(_endT * 2.2) * pi) * 60 * _dogJump : 0.0;
    final o = Offset(baseX, 588 + hop);
    final flip = eating && _dogX > _pos.dx ? -1.0 : 1.0;
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(-flip, 1);
    // body
    c.drawOval(const Rect.fromLTWH(-10, -10, 70, 36), D.fill(const Color(0xFFE0A860)));
    c.drawOval(const Rect.fromLTWH(-10, -10, 70, 36), D.stroke(Pal.ink, 4));
    // tail wag
    final wag = sin(_t * 18) * .5;
    D.line(c, const Offset(56, 0), Offset(56 + cos(-1 + wag) * 22, sin(-1 + wag) * 22), Pal.ink, 9);
    D.line(c, const Offset(56, 0), Offset(56 + cos(-1 + wag) * 22, sin(-1 + wag) * 22), const Color(0xFFE0A860), 5);
    // head
    c.drawCircle(const Offset(-10, -24), 28, D.fill(const Color(0xFFE0A860)));
    c.drawCircle(const Offset(-10, -24), 28, D.stroke(Pal.ink, 4));
    c.drawOval(const Rect.fromLTWH(-2, -52, 22, 34), D.fill(const Color(0xFF8A5634)));
    c.drawOval(const Rect.fromLTWH(-2, -52, 22, 34), D.stroke(Pal.ink, 3));
    c.drawOval(const Rect.fromLTWH(-44, -26, 24, 16), D.fill(const Color(0xFFF2C890)));
    c.drawCircle(const Offset(-42, -22), 5, D.fill(Pal.ink));
    final look = eating ? Face.love : (_state == 1 ? Face.shocked : Face.happy);
    D.face(c, const Offset(-16, -30), 20, look, blush: false);
    // tongue
    if (!eating) {
      c.drawOval(Rect.fromLTWH(-34, -12, 10, 12 + M.wave(_t, 3) * 5), D.fill(const Color(0xFFFF7A9A)));
    }
    c.restore();
    if (eating && _endT > .35) {
      // chomping crumbs
      if ((_endT * 10).floor().isEven) {
        c.drawCircle(o + Offset(-30 * flip, -20), 5, D.fill(const Color(0xFFE8A040)));
      }
    }
  }
}
