import '../engine/engine.dart';

/// No.026 Catapult Siege — pull back, release, smash the castle and knock the
/// king off his tower within 4 boulders. Mind the wind.
class G026 extends MiniGame {
  static const _groundY = 540.0;
  static const _grav = 520.0;
  static const _pivot = Offset(74, 500);
  static const _armLen = 54.0;
  static const _maxShots = 4;

  final List<_Block> _blocks = [];
  final List<_Guy> _guys = [];
  late _Guy _king;
  double _t = 0;
  double _wind = 0;
  int _shots = 0;

  // aim
  bool _aiming = false;
  Offset _aimStart = Offset.zero;
  Offset _aimCur = Offset.zero;
  double _arm = -2.4; // radians, arm angle (0 = pointing right)
  double _armTarget = -2.4;

  // boulder
  bool _flying = false;
  Offset _bPos = Offset.zero;
  Offset _bVel = Offset.zero;
  double _bSpin = 0;
  double _bLife = 0;
  bool _bGrounded = false;
  double _endWait = -1;
  final List<Offset> _trail = [];
  double _crewJoy = 0;
  bool _won = false;

  @override
  void init() {
    const x0 = 222.0, cw = 22.0, bh = 22.0;
    const heights = [3, 3, 6, 3, 3];
    for (var col = 0; col < heights.length; col++) {
      for (var r = 0; r < heights[col]; r++) {
        _blocks.add(_Block(Rect.fromLTWH(x0 + col * cw, _groundY - (r + 1) * bh, cw, bh), r == 1 && col != 2 ? 1 : 0));
      }
    }
    // wooden walkways and crenellations
    _blocks.add(_Block(Rect.fromLTWH(x0, _groundY - 3 * bh - 8, cw * 2, 8), 1));
    _blocks.add(_Block(Rect.fromLTWH(x0 + cw * 3, _groundY - 3 * bh - 8, cw * 2, 8), 1));
    for (final cx in const [0, 4]) {
      _blocks.add(_Block(Rect.fromLTWH(x0 + cx * cw + 6, _groundY - 3 * bh - 8 - 10, 10, 10), 0));
    }
    _blocks.add(_Block(Rect.fromLTWH(x0 + 2 * cw - 4, _groundY - 6 * bh - 8, cw + 8, 8), 1));
    _king = _Guy(Offset(x0 + 2.5 * cw, _groundY - 6 * bh - 8), true);
    _guys
      ..add(_king)
      ..add(_Guy(Offset(x0 + 1.4 * cw, _groundY - 3 * bh - 8), false))
      ..add(_Guy(Offset(x0 + 3.6 * cw, _groundY - 3 * bh - 8), false));
    _newWind();
  }

  void _newWind() {
    _wind = (rand(-1, 1) * 10).roundToDouble() / 10;
  }

  Offset get _armTip => _pivot + Offset(cos(_arm), sin(_arm)) * _armLen;

  Offset _launchVel() {
    var v = (_aimStart - _aimCur) * 4.6;
    final len = v.distance;
    if (len > 640) v = v / len * 640;
    var a = atan2(v.dy, v.dx);
    a = a.clamp(-1.45, -.05);
    final s = max(v.distance, 120.0);
    return Offset(cos(a), sin(a)) * s;
  }

  @override
  void update(double dt) {
    _t += dt;
    _crewJoy = max(0, _crewJoy - dt);
    // arm animation
    if (_aiming) {
      final pull = min(1.0, (_aimStart - _aimCur).distance / 140);
      _armTarget = -2.4 - pull * .55;
      _arm = M.approach(_arm, _armTarget, 20, dt);
    } else {
      _arm = M.approach(_arm, _armTarget, _armTarget > -2 ? 26 : 5, dt);
      if (_armTarget > -2 && (_arm - _armTarget).abs() < .05) _armTarget = -2.4;
    }

    if (_flying) _updateBoulder(dt);
    _settle(dt);
    _updateGuys(dt);

    if (_endWait > 0 && !host.finished) {
      _endWait -= dt;
      if (_endWait <= 0) {
        host.sfx(Sfx.aww);
        host.lose();
      }
    }
  }

  void _updateBoulder(double dt) {
    _bLife += dt;
    _bVel = Offset(_bVel.dx + _wind * 70 * dt, _bVel.dy + _grav * dt);
    _bPos += _bVel * dt;
    _bSpin += _bVel.dx * dt * .08;
    if ((_t * 60).floor().isEven) {
      _trail.add(_bPos);
      if (_trail.length > 14) _trail.removeAt(0);
    }
    const r = 11.0;
    for (final b in _blocks) {
      if (b.debris) continue;
      final cx = _bPos.dx.clamp(b.r.left, b.r.right), cy = _bPos.dy.clamp(b.r.top, b.r.bottom);
      final d = Offset(_bPos.dx - cx, _bPos.dy - cy);
      if (d.distanceSquared < r * r) {
        final speed = _bVel.distance;
        if (speed < 90) {
          _bVel = Offset(-_bVel.dx * .3, -_bVel.dy * .3);
          continue;
        }
        _knock(b, _bVel * .55 + Offset(0, -120));
        _bVel = _bVel * (b.mat == 1 ? .78 : .62);
        host.sfx(b.mat == 1 ? Sfx.crack : Sfx.hitHeavy, rate: rand(.9, 1.2));
        host.shake(6);
        host.hitStop(.04);
        host.fx.burst(Offset(cx, cy), b.mat == 1 ? const Color(0xFFC98B4F) : const Color(0xFFB9B8C8),
            count: 10, speed: 220, size: 6, shape: PartShape.square);
        host.fx.smoke(Offset(cx, cy), count: 3);
        host.addScore(50, Offset(cx, cy - 10));
      }
    }
    for (final g in _guys) {
      if (g.down) continue;
      if ((g.pos + const Offset(0, -14) - _bPos).distance < 22) {
        _launchGuy(g, _bVel * .7 + const Offset(0, -260));
        _bVel = _bVel * .8;
      }
    }
    if (_bPos.dy > _groundY - r) {
      _bPos = Offset(_bPos.dx, _groundY - r);
      if (!_bGrounded || _bVel.dy > 80) {
        host.sfx(Sfx.thud);
        host.shake(4);
        host.fx.smoke(_bPos + const Offset(0, 8), count: 5, color: const Color(0xCCC8B08A));
      }
      _bGrounded = true;
      _bVel = Offset(_bVel.dx * .7, -_bVel.dy * .25);
    }
    final off = _bPos.dx > 380 || _bPos.dx < -30 || _bPos.dy > 700;
    if (off || (_bGrounded && _bVel.distance < 30) || _bLife > 4) {
      _flying = false;
      _trail.clear();
      if (!_won) {
        if (_shots >= _maxShots) {
          _endWait = 1.6;
        } else {
          _newWind();
          host.sfx(Sfx.wind, volume: .5);
        }
      }
    }
  }

  void _knock(_Block b, Offset v) {
    b.debris = true;
    b.vel = v;
    b.spin = rand(-8, 8);
  }

  void _launchGuy(_Guy g, Offset v) {
    g.down = true;
    g.vel = v;
    g.spin = rand(6, 12) * (v.dx >= 0 ? 1 : -1);
    host.sfx(Sfx.boing);
    host.sfx(Sfx.punch, volume: .7);
    if (g.king) {
      _kingDown();
    } else {
      host.addScore(150, g.pos + const Offset(0, -30));
      host.fx.pop(host.tr('nice', 'NICE!'), g.pos + const Offset(0, -50), color: Pal.white, size: 20);
    }
  }

  void _kingDown() {
    if (_won || host.finished) return;
    _won = true;
    _crewJoy = 3;
    host.hitStop(.12);
    host.shake(10);
    host.flash(Pal.white);
    host.sfx(Sfx.explode);
    host.sfx(Sfx.cheer);
    host.fx.confetti();
    host.fx.coins(_king.pos, count: 18);
    host.fx.pop(host.tr('ko', 'K.O.!'), const Offset(180, 220), color: Pal.yellow, size: 48, life: 1.2);
    host.addScore(1000, _king.pos + const Offset(0, -40));
    host.win(stars: _shots <= 1 ? 3 : (_shots == 2 ? 2 : 1));
  }

  double _supportFor(double left, double right, double bottom, Object self) {
    var s = _groundY;
    for (final o in _blocks) {
      if (o == self || o.debris) continue;
      final ov = min(right, o.r.right) - max(left, o.r.left);
      if (ov < 3) continue;
      if (o.r.top >= bottom - 2 && o.r.top < s) s = o.r.top;
    }
    return s;
  }

  double _supportCover(_Block b) {
    var cover = 0.0;
    for (final o in _blocks) {
      if (o == b || o.debris) continue;
      if ((o.r.top - b.r.bottom).abs() > 1.5) continue;
      final ov = min(b.r.right, o.r.right) - max(b.r.left, o.r.left);
      if (ov > 0) cover += ov;
    }
    return cover / b.r.width;
  }

  void _settle(double dt) {
    _blocks.sort((a, b) => b.r.bottom.compareTo(a.r.bottom));
    for (final b in _blocks) {
      if (b.debris) {
        b.vel = Offset(b.vel.dx * (1 - dt * .3), b.vel.dy + _grav * dt);
        b.r = b.r.shift(b.vel * dt);
        b.rot += b.spin * dt;
        b.life -= dt;
        if (b.r.bottom > _groundY + 6) {
          b.r = b.r.shift(Offset(0, _groundY + 6 - b.r.bottom));
          b.vel = Offset(b.vel.dx * .5, -b.vel.dy * .3);
          b.spin *= .6;
        }
        // flying debris can clobber guys
        if (b.vel.distance > 170) {
          for (final g in _guys) {
            if (!g.down && (g.pos + const Offset(0, -14) - b.r.center).distance < 20) _launchGuy(g, b.vel * .6);
          }
        }
        continue;
      }
      final sup = _supportFor(b.r.left, b.r.right, b.r.bottom, b);
      if (b.r.bottom < sup - .5) {
        b.vy += _grav * dt;
        var ny = b.r.top + b.vy * dt;
        if (ny + b.r.height >= sup) {
          ny = sup - b.r.height;
          if (b.vy > 220) {
            host.sfx(Sfx.thud, volume: .5, rate: rand(.9, 1.3));
            host.fx.smoke(Offset(b.r.center.dx, sup), count: 2, size: 10);
          }
          b.vy = 0;
        }
        b.r = Rect.fromLTWH(b.r.left, ny, b.r.width, b.r.height);
      } else if (b.r.bottom < _groundY - 1 && _supportCover(b) < .35) {
        // barely supported → topple off
        _knock(b, Offset(rand(-60, 60), -20));
      }
    }
    _blocks.removeWhere((b) => b.debris && b.life <= 0);
  }

  void _updateGuys(double dt) {
    for (final g in _guys) {
      if (g.down) {
        g.vel = Offset(g.vel.dx, g.vel.dy + _grav * dt);
        g.pos += g.vel * dt;
        g.rot += g.spin * dt;
        if (g.pos.dy > _groundY) {
          g.pos = Offset(g.pos.dx, _groundY);
          g.vel = Offset(g.vel.dx * .5, -g.vel.dy * .3);
          g.spin *= .5;
          if (g.vel.dy.abs() < 40) g.vel = Offset(g.vel.dx * .9, 0);
        }
        continue;
      }
      final sup = _supportFor(g.pos.dx - 8, g.pos.dx + 8, g.pos.dy, g);
      if (g.pos.dy < sup - .5) {
        g.vy += _grav * dt;
        g.fall += g.vy * dt;
        var ny = g.pos.dy + g.vy * dt;
        if (ny >= sup) {
          ny = sup;
          if (g.fall > 30 || sup >= _groundY) {
            g.pos = Offset(g.pos.dx, ny);
            _launchGuy(g, Offset(rand(-40, 40), -120));
            continue;
          }
          g.vy = 0;
        }
        g.pos = Offset(g.pos.dx, ny);
      }
    }
  }

  @override
  void onDown(Offset p) {
    if (_flying || _shots >= _maxShots || _won) return;
    _aiming = true;
    _aimStart = p;
    _aimCur = p;
    host.sfx(Sfx.tick, volume: .5);
  }

  @override
  void onMove(Offset p) {
    if (_aiming) _aimCur = p;
  }

  @override
  void onUp(Offset p) {
    if (!_aiming) return;
    _aiming = false;
    _aimCur = p;
    if ((_aimStart - _aimCur).distance < 18) {
      _armTarget = -2.4;
      return;
    }
    final v = _launchVel();
    _shots++;
    _flying = true;
    _bGrounded = false;
    _bLife = 0;
    _armTarget = -1.2;
    _bPos = _pivot + Offset(cos(-1.3), sin(-1.3)) * _armLen;
    _bVel = v;
    host.sfx(Sfx.swing);
    host.sfx(Sfx.whoosh, rate: .8);
    host.shake(3);
    host.fx.smoke(_pivot + const Offset(0, 30), count: 4, color: const Color(0xCCC8B08A));
  }

  @override
  void onTimeUp() {
    if (_won) return;
    host.lose();
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF6EC6FF), Color(0xFFBDE6FF), Color(0xFFFFE3B8)]);
    c.drawCircle(const Offset(300, 110), 34, D.fill(const Color(0x66FFF6C8)));
    c.drawCircle(const Offset(300, 110), 24, D.fill(const Color(0xFFFFF1A0)));
    for (var i = 0; i < 4; i++) {
      final x = (i * 110 + _t * (8 + _wind * 30)) % 480 - 60;
      D.cloud(c, Offset(x, 110.0 + i * 38 % 90), 48.0 + i * 6, color: const Color(0xDDFFFFFF));
    }
    // distant hills
    final hill1 = Path()..moveTo(0, 470);
    for (var x = 0.0; x <= 360; x += 20) {
      hill1.lineTo(x, 450 - sin(x * .018 + 1) * 34);
    }
    hill1
      ..lineTo(360, _groundY)
      ..lineTo(0, _groundY)
      ..close();
    c.drawPath(hill1, D.fill(const Color(0xFF9FD48A)));
    final hill2 = Path()..moveTo(0, 500);
    for (var x = 0.0; x <= 360; x += 20) {
      hill2.lineTo(x, 494 - sin(x * .03 + 3) * 18);
    }
    hill2
      ..lineTo(360, _groundY)
      ..lineTo(0, _groundY)
      ..close();
    c.drawPath(hill2, D.fill(const Color(0xFF6DBE5C)));
    // ground
    c.drawRect(const Rect.fromLTWH(0, _groundY, 360, 100), D.fill(const Color(0xFF8A5A33)));
    c.drawRect(const Rect.fromLTWH(0, _groundY, 360, 12), D.fill(const Color(0xFF4FAE45)));
    for (var x = 0.0; x < 360; x += 14) {
      c.drawCircle(Offset(x + 7, _groundY + 12), 6, D.fill(const Color(0xFF4FAE45)));
    }
    for (var i = 0; i < 12; i++) {
      c.drawOval(Rect.fromLTWH((i * 67.0) % 350, 575.0 + (i * 23) % 50, 16, 7), D.fill(const Color(0xFF74482A)));
    }

    // castle blocks
    for (final b in _blocks) {
      _drawBlock(c, b);
    }
    // enemy flag on the tallest tower
    if (!_won) {
      final top = _king.pos + const Offset(18, 0);
      D.line(c, top, top + const Offset(0, -46), Pal.ink, 3);
      final fl = Path()
        ..moveTo(top.dx, top.dy - 46)
        ..quadraticBezierTo(top.dx + 12 + _wind * 6, top.dy - 50 + sin(_t * 9) * 3, top.dx + 24 * _wind.sign + (_wind == 0 ? 12 : 0),
            top.dy - 40)
        ..lineTo(top.dx, top.dy - 34)
        ..close();
      c.drawPath(fl, D.fill(Pal.red));
      c.drawPath(fl, D.stroke(Pal.ink, 2));
    }
    for (final g in _guys) {
      _drawGuy(c, g);
    }

    // catapult
    _drawCatapult(c);

    // trajectory preview
    if (_aiming && (_aimStart - _aimCur).distance >= 18) {
      final v = _launchVel();
      var p = _pivot + Offset(cos(-1.3), sin(-1.3)) * _armLen;
      var vel = v;
      final dp = Paint()..color = const Color(0xDDFFFFFF);
      for (var i = 0; i < 16; i++) {
        for (var k = 0; k < 4; k++) {
          vel = Offset(vel.dx, vel.dy + _grav / 60);
          p += vel / 60;
        }
        c.drawCircle(p, 5 - i * .22, dp);
        c.drawCircle(p, 5 - i * .22, D.stroke(const Color(0x66000000), 1.5));
      }
      // pull band
      D.line(c, _aimStart, _aimCur, const Color(0x88FFFFFF), 4);
      c.drawCircle(_aimCur, 10, D.stroke(Pal.white, 3));
      final pwr = min(1.0, (_aimStart - _aimCur).distance / 140);
      D.bar(c, const Rect.fromLTWH(24, 580, 120, 14), pwr, Color.lerp(Pal.lime, Pal.red, pwr)!, border: Pal.ink);
    }

    // boulder
    if (_flying) {
      for (var i = 0; i < _trail.length; i++) {
        c.drawCircle(_trail[i], 3 + i * .5, Paint()..color = Color.fromRGBO(255, 255, 255, i / _trail.length * .6));
      }
      _drawBoulder(c, _bPos, _bSpin);
    }

    // HUD — shots left
    for (var i = 0; i < _maxShots; i++) {
      final left = i >= _shots - (_flying ? 0 : 0);
      final o = Offset(30.0 + i * 30, 62);
      if (left) {
        _drawBoulder(c, o, i.toDouble());
      } else {
        c.drawCircle(o, 10, D.fill(const Color(0x44000000)));
      }
    }
    // wind
    D.rrect(c, const Rect.fromLTWH(236, 46, 110, 34), 17, const Color(0x99FFFFFF), border: Pal.ink, borderWidth: 2.5);
    final wlen = 18 + _wind.abs() * 34;
    if (_wind.abs() > .05) {
      D.arrow(c, Offset(274 + sin(_t * 6) * 2, 63), Offset(_wind.sign, 0), wlen, Pal.sky, width: 7);
    } else {
      c.drawCircle(const Offset(274, 63), 6, D.fill(Pal.sky));
    }
    D.text(c, _wind.abs().toStringAsFixed(1), const Offset(326, 63), size: 16, color: Pal.ink);
    // wind streaks
    final ws = D.stroke(const Color(0x55FFFFFF), 2);
    for (var i = 0; i < 6; i++) {
      final x = (i * 70 + _t * _wind * 160) % 380;
      final y = 160.0 + i * 50;
      c.drawLine(Offset(x < 0 ? x + 380 : x, y), Offset((x < 0 ? x + 380 : x) + 24 * _wind.sign, y), ws);
    }

    if (_shots == 0 && !_aiming && host.time < 4) {
      final k = (_t * .8) % 1;
      final from = const Offset(120, 420);
      D.hand(c, Offset.lerp(from, from + const Offset(-70, 60), M.easeInOut(M.clamp01(k * 1.4)))!, 0);
      D.text(c, host.tr('drag', 'DRAG!'), const Offset(120, 380), size: 24, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _drawBoulder(Canvas c, Offset o, double spin) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(spin);
    D.circle(c, Offset.zero, 11, const Color(0xFF8E8AA3), border: Pal.ink, borderWidth: 2.5);
    c.drawCircle(const Offset(-3, -3), 4, D.fill(const Color(0xFFB9B6C8)));
    c.drawCircle(const Offset(4, 3), 2.5, D.fill(const Color(0xFF6D6980)));
    c.restore();
  }

  void _drawBlock(Canvas c, _Block b) {
    c.save();
    c.translate(b.r.center.dx, b.r.center.dy);
    if (b.debris) c.rotate(b.rot);
    final r = Rect.fromCenter(center: Offset.zero, width: b.r.width, height: b.r.height);
    if (b.mat == 1) {
      D.rrect(c, r, 2, const Color(0xFFC98B4F), border: Pal.ink, borderWidth: 2);
      if (r.height > 10) {
        D.line(c, Offset(r.left + 4, 0), Offset(r.right - 4, 0), const Color(0xFF8A5A33), 1.5);
      } else {
        c.drawCircle(Offset(r.left + 4, 0), 1.3, D.fill(Pal.ink));
        c.drawCircle(Offset(r.right - 4, 0), 1.3, D.fill(Pal.ink));
      }
    } else {
      D.rrect(c, r, 2, const Color(0xFFB4B1C4), border: Pal.ink, borderWidth: 2);
      final m = D.stroke(const Color(0xFF7E7A94), 1.4);
      if (r.height > 12) {
        c.drawLine(Offset(r.left + 2, 0), Offset(r.right - 2, 0), m);
        c.drawLine(Offset(r.left + r.width * .5, r.top + 2), Offset(r.left + r.width * .5, 0), m);
        c.drawLine(Offset(r.left + r.width * .25, 0), Offset(r.left + r.width * .25, r.bottom - 2), m);
      }
      c.drawRect(Rect.fromLTWH(r.left + 2, r.top + 2, r.width - 4, 3), D.fill(const Color(0x55FFFFFF)));
    }
    c.restore();
  }

  void _drawGuy(Canvas c, _Guy g) {
    c.save();
    c.translate(g.pos.dx, g.pos.dy);
    if (g.down) c.rotate(g.rot);
    if (g.king) {
      final face = g.down ? (g.pos.dy >= _groundY - 1 ? Face.dead : Face.shocked) : (_flying ? Face.shocked : Face.smug);
      D.rrect(c, const Rect.fromLTWH(-10, -18, 20, 18), 6, const Color(0xFFB0203A), border: Pal.ink, borderWidth: 2);
      c.drawRect(const Rect.fromLTWH(-10, -6, 20, 4), D.fill(Pal.white));
      D.circle(c, const Offset(0, -27), 11, Pal.skin, border: Pal.ink, borderWidth: 2);
      D.face(c, const Offset(0, -26), 9, face);
      // beard
      c.drawArc(Rect.fromCenter(center: const Offset(0, -22), width: 16, height: 12), .2, pi - .4, false, D.stroke(Pal.white, 3));
      // crown
      final crown = Path()
        ..moveTo(-9, -35)
        ..lineTo(-9, -45)
        ..lineTo(-4.5, -40)
        ..lineTo(0, -47)
        ..lineTo(4.5, -40)
        ..lineTo(9, -45)
        ..lineTo(9, -35)
        ..close();
      c.drawPath(crown, D.fill(Pal.gold));
      c.drawPath(crown, D.stroke(Pal.ink, 2));
      c.drawCircle(const Offset(0, -39), 1.8, D.fill(Pal.red));
      if (!g.down && !_flying && !_aiming) {
        // taunting speech mark
        final n = Offset(18, -44 + sin(_t * 5) * 3);
        c.drawOval(Rect.fromCenter(center: n, width: 8, height: 6), D.fill(Pal.ink));
        D.line(c, n + const Offset(3.5, 0), n + const Offset(3.5, -13), Pal.ink, 2);
        D.line(c, n + const Offset(3.5, -13), n + const Offset(9, -9), Pal.ink, 2);
      }
    } else {
      D.person(c, Offset.zero, 28, const Color(0xFFD9404F),
          face: g.down ? Face.dead : (_flying ? Face.shocked : Face.angry), pants: const Color(0xFF4A3A30));
      c.drawArc(Rect.fromCenter(center: const Offset(0, -23), width: 12, height: 10), pi, pi, true, D.fill(const Color(0xFF9AA3B5)));
    }
    c.restore();
  }

  void _drawCatapult(Canvas c) {
    const wood = Color(0xFFA8683A), dark = Color(0xFF6E4020);
    // frame
    D.rrect(c, const Rect.fromLTWH(34, 512, 90, 14), 4, wood, border: Pal.ink, borderWidth: 2.5);
    final tri = Path()
      ..moveTo(60, 514)
      ..lineTo(_pivot.dx, _pivot.dy - 6)
      ..lineTo(92, 514)
      ..close();
    c.drawPath(tri, D.fill(dark));
    c.drawPath(tri, D.stroke(Pal.ink, 2.5));
    // stopper bar
    D.rrect(c, const Rect.fromLTWH(96, 470, 8, 44), 3, wood, border: Pal.ink, borderWidth: 2);
    // arm
    c.save();
    c.translate(_pivot.dx, _pivot.dy);
    c.rotate(_arm);
    D.rrect(c, const Rect.fromLTWH(-8, -5, _armLen + 10, 10), 4, wood, border: Pal.ink, borderWidth: 2.5);
    c.drawArc(Rect.fromCenter(center: const Offset(_armLen, -4), width: 26, height: 20), 0, pi, true, D.fill(dark));
    c.drawArc(Rect.fromCenter(center: const Offset(_armLen, -4), width: 26, height: 20), 0, pi, true, D.stroke(Pal.ink, 2));
    c.restore();
    if (!_flying && _shots < _maxShots && !_won) _drawBoulder(c, _armTip + const Offset(0, -6), 0);
    D.circle(c, _pivot, 5, Pal.gray, border: Pal.ink, borderWidth: 2);
    // wheels
    for (final wx in const [46.0, 112.0]) {
      final o = Offset(wx, 528);
      D.circle(c, o, 13, wood, border: Pal.ink, borderWidth: 2.5);
      for (var i = 0; i < 3; i++) {
        final a = i * pi / 3 + (_arm * .3);
        c.drawLine(o + Offset(cos(a), sin(a)) * 10, o - Offset(cos(a), sin(a)) * 10, D.stroke(dark, 2));
      }
      D.circle(c, o, 3, Pal.gray);
    }
    // crew guy
    final joy = _crewJoy > 0;
    D.person(c, Offset(20, _groundY + 2 - (joy ? (sin(_t * 16).abs() * 8) : 0)), 40, const Color(0xFF3D6BFF),
        face: joy ? Face.happy : (_aiming ? Face.angry : Face.neutral),
        hair: const Color(0xFF3A2A20),
        armsUp: joy ? 1 : 0);
  }
}

class _Block {
  _Block(this.r, this.mat);
  Rect r;
  final int mat; // 0 stone, 1 wood
  bool debris = false;
  Offset vel = Offset.zero;
  double vy = 0;
  double rot = 0;
  double spin = 0;
  double life = 2.4;
}

class _Guy {
  _Guy(this.pos, this.king);
  Offset pos;
  final bool king;
  bool down = false;
  Offset vel = Offset.zero;
  double vy = 0;
  double fall = 0;
  double rot = 0;
  double spin = 0;
}
