import 'dart:math' as math;
import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.019 Castle Archers — slingshot-style archery from the castle wall.
///
/// Drag anywhere and pull back (like a slingshot) to aim; a dotted arc
/// previews the shot, release to fire. Knights, ladder carriers and a big
/// ogre march on the wall. Headshots kill instantly. Keep the wall standing.
class G019 extends MiniGame {
  static const _groundY = 566.0;
  static const _wallX = 96.0; // wall front face
  static const _wallTop = 338.0;
  static const _bow = Offset(70, 300);
  static const _ladderBot = Offset(_wallX + 40, _groundY);
  static const _ladderTop = Offset(_wallX - 6, _wallTop - 10);
  static const _g = 620.0;
  static const _maxPull = 150.0;
  static const _maxSpeed = 980.0;

  double _t = 0;
  double _wall = 100;
  double _wallShown = 100;
  double _wallHit = 0;
  Offset? _dragStart;
  Offset _drag = Offset.zero;
  double _cool = 0;
  double _aimAngle = -.35;
  double _keyAngle = -.35;
  int _combo = 0;
  double _spawnClock = .4;
  int _spawned = 0;
  bool _shot = false;
  double _recoil = 0;

  final List<_Arrow> _arrows = [];
  final List<_Foe> _foes = [];
  final List<_Cloud> _clouds = [];

  @override
  void init() {
    for (var i = 0; i < 5; i++) {
      _clouds.add(_Cloud(rand(0, 360), rand(70, 230), rand(40, 80), rand(6, 16)));
    }
  }

  // ------------------------------------------------------------ update ---

  @override
  double _botT = 0; // BOT
  void update(double dt) {
    _t += dt;
    _botT += dt; if (_botT > .45 && !host.finished) { _botT = 0; final live = _foes.where((f) => !f.dead && f.x < 360).toList()..sort((a, b) => a.x.compareTo(b.x)); if (live.isNotEmpty) { final f = live.first; final tgt = _headOf(f) + Offset(-f.speed * .5, 0); Offset? bestV; var bd = 1e9; for (var a = -1.2; a < .3; a += .02) { for (var sp = 300.0; sp < 980; sp += 20) { var p = _bow; var v = Offset(cos(a), sin(a)) * sp; for (var k = 0; k < 90; k++) { v = Offset(v.dx, v.dy + _g / 60); p += v / 60; if (p.dx >= tgt.dx) break; } final d = (p - tgt).distance; if (d < bd) { bd = d; bestV = Offset(cos(a), sin(a)) * sp; } } } if (bestV != null) _fire(bestV); } } // BOT
    final sp = host.speed;
    _cool = math.max(0, _cool - dt);
    _wallHit = M.approach(_wallHit, 0, 6, dt);
    _wallShown = M.approach(_wallShown, _wall, 6, dt);
    _recoil = M.approach(_recoil, 0, 10, dt);
    for (final cl in _clouds) {
      cl.x -= cl.v * dt;
      if (cl.x < -80) cl.x += 460;
    }

    // spawning
    if (!host.finished) {
      _spawnClock -= dt * sp;
      if (_spawnClock <= 0 && host.timeLeft > 2.5) {
        _spawn();
        _spawnClock = math.max(.85, 1.55 - _t * .03);
      }
    }

    // enemies
    for (var i = _foes.length - 1; i >= 0; i--) {
      final f = _foes[i];
      f.flash = math.max(0, f.flash - dt);
      if (f.dead) {
        f.deadT += dt;
        f.vy += 900 * dt;
        f.x += f.vx * dt;
        f.fallY = math.min(0, f.fallY + f.vy * dt);
        if (f.deadT > 1.3) _foes.removeAt(i);
        continue;
      }
      f.anim += dt * 9;
      f.knock = M.approach(f.knock, 0, 10, dt);
      if (host.finished) continue;
      switch (f.state) {
        case _FState.walk:
          f.x -= f.speed * sp * dt;
          final stop = _wallX + (f.kind == 2 ? 44 : 16);
          if (f.x <= stop) {
            f.x = stop;
            f.state = f.kind == 1 ? _FState.climb : _FState.attack;
            if (f.kind == 1) host.sfx(Sfx.clang, volume: .5, rate: .8);
          }
        case _FState.attack:
          final dps = f.kind == 2 ? 11.0 : 3.8;
          _hurtWall(dps * sp * dt, f);
        case _FState.climb:
          f.climb += dt * sp / 2.4;
          final p = Offset.lerp(_ladderBot, _ladderTop, math.min(1, f.climb) * .92)! + const Offset(6, 0);
          f.x = p.dx;
          f.y = p.dy;
          if (f.climb >= 1) {
            f.dead = true;
            f.vx = -60;
            f.vy = -200;
            _hurtWall(16, f, burst: true);
            host.fx.pop('-16', Offset(_wallX - 20, _wallTop - 30), color: Pal.red, size: 28);
          }
      }
    }

    // arrows
    for (var i = _arrows.length - 1; i >= 0; i--) {
      final a = _arrows[i];
      if (a.stuck) {
        a.life -= dt;
        if (a.life <= 0) _arrows.removeAt(i);
        continue;
      }
      var hit = false;
      const steps = 4;
      for (var s = 0; s < steps && !hit; s++) {
        final h = dt / steps;
        a.vel = Offset(a.vel.dx, a.vel.dy + _g * h);
        a.pos += a.vel * h;
        hit = _checkHit(a);
      }
      if (hit) {
        _arrows.removeAt(i);
        continue;
      }
      if (a.pos.dy >= _groundY - 2) {
        a.stuck = true;
        a.pos = Offset(a.pos.dx, _groundY - 2);
        a.life = 1.6;
        host.fx.burst(a.pos, const Color(0xFFB08A55), count: 4, speed: 80, size: 3, gravity: 300);
        host.sfx(Sfx.thud, volume: .25, rate: 1.5);
        if (_combo > 0) _combo = 0;
      } else if (a.pos.dx > 400 || a.pos.dy > 700) {
        _arrows.removeAt(i);
        _combo = 0;
      }
    }

    if (!host.finished && _wall <= 0) {
      _wall = 0;
      host.sfx(Sfx.crash);
      host.sfx(Sfx.jingleLose, volume: .8);
      host.shake(14, .6);
      host.fx.burst(const Offset(50, 420), const Color(0xFF9EA3B8), count: 36, speed: 320, size: 10,
          shape: PartShape.square, colors: const [Color(0xFF9EA3B8), Color(0xFF6E738A), Color(0xFFC9CDDA)]);
      host.lose();
    }
  }

  void _spawn() {
    _spawned++;
    int kind;
    if (_spawned == 7 || _spawned == 14) {
      kind = 2;
    } else if (_spawned > 2 && chance(.33)) {
      kind = 1;
    } else {
      kind = 0;
    }
    final f = _Foe(kind, 390 + rand(0, 20));
    f.speed = switch (kind) { 0 => rand(34, 42), 1 => rand(44, 52), _ => 24 };
    f.hp = switch (kind) { 0 => 2, 1 => 1, _ => 9 };
    f.maxHp = f.hp;
    _foes.add(f);
    if (kind == 2) {
      host.sfx(Sfx.horror, volume: .5);
      host.fx.pop(host.tr('boss', 'BOSS'), const Offset(300, 470), color: Pal.red, size: 26);
      host.shake(4);
    }
  }

  void _hurtWall(double dmg, _Foe f, {bool burst = false}) {
    _wall = math.max(0, _wall - dmg);
    _wallHit = 1;
    if (burst || chance(.08)) {
      host.sfx(f.kind == 2 ? Sfx.hitHeavy : Sfx.hit, volume: .5, rate: rand(.8, 1.1));
      host.fx.burst(Offset(_wallX, burst ? _wallTop : _groundY - rand(10, 60)), const Color(0xFF9EA3B8),
          count: burst ? 16 : 3, speed: 150, size: 5, shape: PartShape.square);
      host.shake(burst ? 8 : 2);
    }
  }

  Offset _headOf(_Foe f) => f.kind == 2 ? Offset(f.x - 4, f.y - 84) : Offset(f.x, f.y - 50);
  double _headR(_Foe f) => f.kind == 2 ? 17 : 10;
  Rect _bodyOf(_Foe f) =>
      f.kind == 2 ? Rect.fromLTRB(f.x - 34, f.y - 76, f.x + 30, f.y) : Rect.fromLTRB(f.x - 11, f.y - 42, f.x + 11, f.y);

  bool _checkHit(_Arrow a) {
    for (final f in _foes) {
      if (f.dead) continue;
      final head = (a.pos - _headOf(f)).distance <= _headR(f);
      final body = _bodyOf(f).contains(a.pos);
      if (!head && !body) continue;
      _combo++;
      final dmg = head ? (f.kind == 2 ? 3 : 99) : 1;
      f.hp -= dmg;
      f.flash = .1;
      f.knock = 1;
      final at = head ? _headOf(f) : a.pos;
      if (head) {
        host.sfx(Sfx.clang, rate: 1.3);
        host.sfx(Sfx.perfect, volume: .6, rate: 1 + math.min(_combo, 8) * .05);
        host.fx.pop(host.tr('headshot', 'HEADSHOT!'), at + const Offset(0, -30), color: Pal.yellow, size: 24);
        host.fx.burst(at, Pal.yellow, count: 14, speed: 220, shape: PartShape.star, size: 6);
        host.hitStop(.05);
        host.addScore(30, at);
      } else {
        host.sfx(Sfx.hit, volume: .7, rate: rand(1, 1.3));
        host.fx.burst(at, Pal.white, count: 6, speed: 140, size: 4);
        host.addScore(10);
      }
      if (_combo >= 3) {
        host.fx.pop('${host.tr('combo', 'COMBO')} x$_combo', Offset(at.dx, at.dy - 56), color: Pal.pink, size: 18);
      }
      if (f.hp <= 0) _kill(f, head);
      return true;
    }
    return false;
  }

  void _kill(_Foe f, bool head) {
    f.dead = true;
    f.headOff = head && f.kind != 2;
    f.vx = 120;
    f.vy = f.state == _FState.climb ? -80 : -260;
    host.sfx(f.kind == 2 ? Sfx.explode : Sfx.punch, volume: .8);
    if (f.kind == 1) host.sfx(Sfx.boing, volume: .5);
    host.shake(f.kind == 2 ? 10 : 3);
    final p = _headOf(f);
    host.fx.coins(p, count: f.kind == 2 ? 14 : 4, speed: 280);
    if (f.kind == 2) {
      host.fx.pop('KO!', p + const Offset(0, -40), color: Pal.orange, size: 40, life: 1.1);
      host.flash(Pal.white, .12);
      host.addScore(150, p);
    }
  }

  // ------------------------------------------------------------- input ---

  Offset get _launchVel {
    final pull = _drag;
    final len = math.min(pull.distance, _maxPull);
    if (len < 1) return Offset.zero;
    final dir = -pull / pull.distance;
    return dir * (len / _maxPull * _maxSpeed);
  }

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    _dragStart = p;
    _drag = Offset.zero;
    host.sfx(Sfx.tap, volume: .3);
  }

  @override
  void onMove(Offset p) {
    if (_dragStart == null) return;
    _drag = p - _dragStart!;
    if (_drag.distance > 20) {
      final v = _launchVel;
      _aimAngle = math.atan2(v.dy, v.dx);
    }
  }

  @override
  void onUp(Offset p) {
    if (_dragStart == null) return;
    _drag = p - _dragStart!;
    _dragStart = null;
    if (_drag.distance < 24) {
      _drag = Offset.zero;
      return;
    }
    final v = _launchVel;
    _drag = Offset.zero;
    _fire(v);
  }

  void _fire(Offset v) {
    if (_cool > 0 || host.finished) return;
    if (v.dx < 60) return; // must shoot forward
    _cool = .22;
    _shot = true;
    _recoil = 1;
    _aimAngle = math.atan2(v.dy, v.dx);
    _arrows.add(_Arrow(_bow, v));
    host.sfx(Sfx.arrow, rate: rand(.95, 1.1));
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'up') _keyAngle = math.max(-1.3, _keyAngle - .08);
    if (key == 'down') _keyAngle = math.min(.4, _keyAngle + .08);
    _aimAngle = _keyAngle;
    if (key == 'action') _fire(Offset(math.cos(_keyAngle), math.sin(_keyAngle)) * 720);
  }

  @override
  void onTimeUp() {
    if (_wall > 0) {
      host.sfx(Sfx.fanfare);
      host.fx.confetti();
      host.win(stars: _wall > 70 ? 3 : (_wall > 35 ? 2 : 1));
    } else {
      host.lose();
    }
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    // dusk sky
    D.gradientBg(c, const [Color(0xFF3B2A6E), Color(0xFFB5527A), Color(0xFFFFA25C), Color(0xFFFFD08A)],
        rect: const Rect.fromLTWH(0, 0, 360, 580));
    // sun
    const sun = Offset(270, 360);
    c.drawCircle(sun, 90, Paint()
      ..shader = ui.Gradient.radial(sun, 90, [const Color(0x88FFE9A8), const Color(0x00FFE9A8)]));
    c.drawCircle(sun, 38, D.fill(const Color(0xFFFFE2A0)));
    for (final cl in _clouds) {
      D.cloud(c, Offset(cl.x, cl.y), cl.s, color: const Color(0x66FFE4F0));
    }
    // far mountains
    final far = Path()..moveTo(0, 470);
    for (var i = 0; i <= 12; i++) {
      far.lineTo(i * 30.0, 470 - (i.isEven ? 70 : 30) - (i * 37 % 40));
    }
    far
      ..lineTo(360, 580)
      ..lineTo(0, 580)
      ..close();
    c.drawPath(far, D.fill(const Color(0xFF7A4A7E)));
    final near = Path()..moveTo(0, 520);
    for (var i = 0; i <= 9; i++) {
      near.lineTo(i * 40.0, 505 - (i * 53 % 50));
    }
    near
      ..lineTo(360, 580)
      ..lineTo(0, 580)
      ..close();
    c.drawPath(near, D.fill(const Color(0xFF5A3A66)));
    // enemy camp banners far right
    for (var i = 0; i < 3; i++) {
      final x = 300.0 + i * 22;
      D.line(c, Offset(x, 520), Offset(x, 488), const Color(0xFF2A1A30), 2);
      c.drawPath(
          Path()
            ..moveTo(x, 488)
            ..lineTo(x + 12, 492 + math.sin(_t * 5 + i) * 2)
            ..lineTo(x, 498)
            ..close(),
          D.fill(const Color(0xFFD23C4E)));
    }
    // ground
    c.drawRect(const Rect.fromLTWH(0, _groundY, 360, 80), D.fill(const Color(0xFF6B4A33)));
    c.drawRect(const Rect.fromLTWH(0, _groundY - 8, 360, 14), D.fill(const Color(0xFF4FA04A)));
    for (var i = 0; i < 30; i++) {
      final x = i * 12.0 + (i * 7 % 5);
      c.drawPath(
          Path()
            ..moveTo(x, _groundY - 6)
            ..lineTo(x + 3, _groundY - 14 - (i % 3) * 3)
            ..lineTo(x + 6, _groundY - 6)
            ..close(),
          D.fill(const Color(0xFF3F8A3C)));
    }
    for (var i = 0; i < 12; i++) {
      c.drawCircle(Offset(20 + i * 31.0, 600 + (i % 3) * 10), 3 + i % 2 * 2, D.fill(const Color(0xFF55382A)));
    }

    // stuck arrows
    for (final a in _arrows.where((a) => a.stuck)) {
      _drawArrow(c, a.pos, a.vel, alpha: (a.life / .4).clamp(0, 1));
    }

    // enemies (far to near by x: draw right to left)
    for (final f in _foes) {
      _drawFoe(c, f);
    }

    _drawWall(c);
    _drawArcher(c);

    // flying arrows
    for (final a in _arrows.where((a) => !a.stuck)) {
      final back = a.pos - a.vel / a.vel.distance * 26;
      c.drawLine(back, a.pos, D.stroke(const Color(0x44FFFFFF), 4));
      _drawArrow(c, a.pos, a.vel);
    }

    // aim preview
    if (_dragStart != null && _drag.distance > 20) {
      final v = _launchVel;
      var p = _bow;
      var vv = v;
      final dotP = Paint();
      for (var i = 0; i < 26; i++) {
        for (var k = 0; k < 3; k++) {
          vv = Offset(vv.dx, vv.dy + _g * .02);
          p += vv * .02;
        }
        if (p.dy > _groundY) break;
        final a = 1 - i / 26;
        dotP.color = Color.fromRGBO(255, 255, 255, .9 * a);
        c.drawCircle(p, 4.2 - i * .1, dotP);
      }
      // pull indicator
      final s = _dragStart!;
      final e = s + Offset(_drag.dx, _drag.dy) * (math.min(_drag.distance, _maxPull) / _drag.distance);
      c.drawLine(s, e, D.stroke(const Color(0x88FFFFFF), 3));
      D.circle(c, s, 8, const Color(0x55FFFFFF), border: Pal.white, borderWidth: 2);
      final power = math.min(_drag.distance, _maxPull) / _maxPull;
      D.circle(c, e, 12, Color.lerp(Pal.yellow, Pal.red, power)!, border: Pal.ink, borderWidth: 2.5);
    }

    // HUD: wall hp
    const bar = Rect.fromLTWH(60, 50, 240, 20);
    D.rrect(c, const Rect.fromLTWH(12, 42, 336, 36), 14, const Color(0xAA1B1530));
    _miniCastle(c, const Offset(34, 60));
    final k = _wallShown / 100;
    D.bar(c, bar, k, Color.lerp(Pal.red, Pal.lime, k)!, border: Pal.ink);
    if (_wallHit > .1) {
      D.rrect(c, bar, 10, Color.fromRGBO(255, 80, 80, _wallHit * .5));
    }
    D.text(c, '${_wall.ceil()}', const Offset(322, 60), size: 18, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);

    // tutorial
    if (!_shot && _t < 5 && !host.finished) {
      final k2 = (_t * .8) % 1;
      final from = const Offset(230, 400);
      final to = from + Offset(-80 * M.easeOut(k2), 50 * M.easeOut(k2));
      c.drawLine(from, to, D.stroke(const Color(0x99FFFFFF), 4));
      D.hand(c, to, 0);
      D.text(c, host.tr('drag', 'DRAG!'), const Offset(230, 360), size: 26, color: Pal.white, stroke: Pal.ink);
    }
  }

  void _miniCastle(Canvas c, Offset o) {
    D.rrect(c, Rect.fromCenter(center: o + const Offset(0, 3), width: 26, height: 18), 2, const Color(0xFF9EA3B8),
        border: Pal.ink, borderWidth: 2);
    for (var i = 0; i < 3; i++) {
      D.rrect(c, Rect.fromLTWH(o.dx - 13 + i * 9.5, o.dy - 11, 7, 6), 1, const Color(0xFF9EA3B8),
          border: Pal.ink, borderWidth: 1.5);
    }
  }

  void _drawArrow(Canvas c, Offset tip, Offset vel, {double alpha = 1}) {
    final d = vel / math.max(1, vel.distance);
    final n = Offset(-d.dy, d.dx);
    final tail = tip - d * 30;
    c.drawLine(tail, tip - d * 4, D.stroke(Color.fromRGBO(120, 72, 40, alpha), 3));
    c.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - d.dx * 8 + n.dx * 4, tip.dy - d.dy * 8 + n.dy * 4)
          ..lineTo(tip.dx - d.dx * 8 - n.dx * 4, tip.dy - d.dy * 8 - n.dy * 4)
          ..close(),
        D.fill(Color.fromRGBO(210, 215, 230, alpha)));
    for (final s in [1.0, -1.0]) {
      c.drawLine(tail + d * 6, tail + n * 5 * s, D.stroke(Color.fromRGBO(255, 80, 100, alpha), 2.5));
    }
  }

  void _drawWall(Canvas c) {
    final dmg = 1 - _wall / 100;
    final sh = _wallHit * math.sin(_t * 70) * 2;
    c.save();
    c.translate(sh, 0);
    const stone = Color(0xFF9EA3B8), stoneDark = Color(0xFF6E738A);
    final body = Rect.fromLTRB(-10, _wallTop, _wallX, _groundY + 10);
    D.rrect(c, body, 4, stone, border: Pal.ink, borderWidth: 3.5);
    // bricks
    final bp = D.stroke(stoneDark, 2);
    for (var row = 0; row < 10; row++) {
      final y = _wallTop + 12 + row * 22.0;
      if (y > _groundY) break;
      c.drawLine(Offset(0, y), Offset(_wallX - 2, y), bp);
      for (var k = 0; k < 3; k++) {
        final x = (row.isEven ? 16.0 : 36.0) + k * 36;
        if (x < _wallX - 4) c.drawLine(Offset(x, y - 22), Offset(x, y), bp);
      }
    }
    // cracks with damage
    if (dmg > .2) {
      final cp = D.stroke(Pal.ink, 2.5);
      c.drawPath(
          Path()
            ..moveTo(_wallX - 4, 400)
            ..lineTo(_wallX - 20, 420)
            ..lineTo(_wallX - 12, 440)
            ..lineTo(_wallX - 34, 470),
          cp);
      if (dmg > .5) {
        c.drawPath(
            Path()
              ..moveTo(_wallX - 2, 500)
              ..lineTo(_wallX - 26, 510)
              ..lineTo(_wallX - 20, 530)
              ..lineTo(_wallX - 50, 548),
            cp);
      }
      if (dmg > .75) {
        c.drawPath(
            Path()
              ..moveTo(20, _wallTop + 4)
              ..lineTo(30, 380)
              ..lineTo(18, 410),
            cp);
      }
    }
    // crenellations
    for (var i = 0; i < 3; i++) {
      final r = Rect.fromLTWH(-6 + i * 36.0, _wallTop - 22, 24, 24);
      if (i == 1) continue; // archer's gap
      D.rrect(c, r, 3, stone, border: Pal.ink, borderWidth: 3);
    }
    // banner on the wall
    final bx = 40.0;
    c.drawPath(
        Path()
          ..moveTo(bx, _wallTop + 20)
          ..lineTo(bx + 26, _wallTop + 20)
          ..lineTo(bx + 26, _wallTop + 80)
          ..lineTo(bx + 13, _wallTop + 70 + math.sin(_t * 3) * 2)
          ..lineTo(bx, _wallTop + 80)
          ..close(),
        D.fill(const Color(0xFF3D6BFF)));
    D.star(c, Offset(bx + 13, _wallTop + 42), 8, Pal.yellow);
    c.restore();
  }

  void _drawArcher(Canvas c) {
    final feet = Offset(52, _wallTop - 2);
    final lost = _wall <= 0;
    final pulling = _dragStart != null && _drag.distance > 20;
    final power = pulling ? math.min(_drag.distance, _maxPull) / _maxPull : 0.0;
    final face = lost ? Face.dead : (host.finished ? Face.happy : (pulling ? Face.angry : (_wallHit > .3 ? Face.shocked : Face.smug)));
    D.person(c, feet, 58, const Color(0xFF2F9E5A), face: face, hair: const Color(0xFF7A4A2A),
        armsUp: host.finished && !lost ? 1 : 0);
    // hood / feather hat
    final head = feet + const Offset(0, -48);
    c.drawArc(Rect.fromCircle(center: head + const Offset(0, -2), radius: 12), math.pi, math.pi, true,
        D.fill(const Color(0xFF237A45)));
    c.drawLine(head + const Offset(6, -12), head + const Offset(22, -22), D.stroke(Pal.red, 3));
    // bow
    final a = _aimAngle;
    final hand = feet + const Offset(12, -38);
    final d = Offset(math.cos(a), math.sin(a));
    final n = Offset(-d.dy, d.dx);
    final bowC = hand + d * (14 - _recoil * 3);
    final top = bowC + n * 22 - d * 6;
    final bot = bowC - n * 22 - d * 6;
    c.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(bowC.dx + d.dx * 16, bowC.dy + d.dy * 16, bot.dx, bot.dy),
        D.stroke(const Color(0xFF8A5530), 4.5));
    final string = bowC - d * (8 + power * 22);
    c.drawLine(top, string, D.stroke(const Color(0xDDFFFFFF), 1.5));
    c.drawLine(bot, string, D.stroke(const Color(0xDDFFFFFF), 1.5));
    D.line(c, hand, string, Pal.skin, 4);
    if (_cool <= 0 && !host.finished) {
      _drawArrow(c, string + d * 34, d);
    }
  }

  void _drawFoe(Canvas c, _Foe f) {
    final alpha = f.dead ? (1 - (f.deadT - .8) / .5).clamp(0.0, 1.0) : 1.0;
    if (alpha <= 0) return;
    if (alpha < 1) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    var feet = Offset(f.x, f.y + f.fallY);
    if (f.state == _FState.climb && !f.dead) {
      // ladder against the wall
      const lb = _ladderBot;
      const lt = _ladderTop;
      final dd = lt - lb;
      final nn = Offset(-dd.dy, dd.dx) / dd.distance * 9;
      c.drawLine(lb + nn, lt + nn, D.stroke(const Color(0xFF8A5530), 4));
      c.drawLine(lb - nn, lt - nn, D.stroke(const Color(0xFF8A5530), 4));
      for (var i = 1; i < 9; i++) {
        final p = Offset.lerp(lb, lt, i / 9)!;
        c.drawLine(p + nn, p - nn, D.stroke(const Color(0xFF8A5530), 3));
      }
    }
    c.save();
    c.translate(feet.dx, feet.dy);
    if (f.dead) c.rotate(math.min(1.4, f.deadT * 5));
    c.translate(f.knock * 5, 0);
    final walking = f.state == _FState.walk && !f.dead;
    if (f.kind == 2) {
      _drawOgre(c, f, walking);
    } else {
      final shirt = f.kind == 0 ? const Color(0xFFB9C0D6) : const Color(0xFFB0643A);
      final fc = f.dead ? Face.dead : (f.state == _FState.attack ? Face.angry : Face.angry);
      D.shadow(c, const Offset(0, 2), 30, 8, .25);
      D.person(c, Offset.zero, 60, shirt, run: f.anim, running: walking || f.state == _FState.climb, flip: true,
          face: fc, pants: const Color(0xFF4A4A60), skin: const Color(0xFFF2C29B));
      final head = const Offset(0, -49);
      if (f.kind == 0 && !f.headOff) {
        // knight helmet with visor + plume
        c.drawArc(Rect.fromCircle(center: head + const Offset(0, -1), radius: 12), math.pi * .95, math.pi * 1.1, true,
            D.fill(const Color(0xFF8C93AA)));
        c.drawArc(Rect.fromCircle(center: head + const Offset(0, -1), radius: 12), math.pi * .95, math.pi * 1.1, true,
            D.stroke(Pal.ink, 2));
        c.drawLine(head + const Offset(0, -12), head + const Offset(8, -22), D.stroke(Pal.red, 4));
        // sword
        if (!f.dead) {
          final sw = f.state == _FState.attack ? math.sin(f.anim * 1.2) * .9 : .3;
          c.save();
          c.translate(-12, -36);
          c.rotate(-1.2 + sw);
          D.line(c, Offset.zero, const Offset(0, -26), const Color(0xFFE0E6F5), 4);
          D.line(c, const Offset(-5, 0), const Offset(5, 0), const Color(0xFF8A5530), 3);
          c.restore();
        }
      } else if (f.kind == 0 && f.headOff) {
        c.drawArc(Rect.fromCircle(center: head + Offset(-f.deadT * 60, -20 - f.deadT * 80), radius: 12), math.pi * .95,
            math.pi * 1.1, true, D.fill(const Color(0xFF8C93AA)));
      }
      if (f.kind == 1 && f.state == _FState.walk && !f.dead) {
        // ladder carried overhead
        final y = -66.0 + math.sin(f.anim) * 1.5;
        c.drawLine(Offset(-40, y), Offset(40, y), D.stroke(const Color(0xFF8A5530), 4));
        c.drawLine(Offset(-40, y - 10), Offset(40, y - 10), D.stroke(const Color(0xFF8A5530), 4));
        for (var i = 0; i < 8; i++) {
          c.drawLine(Offset(-36 + i * 10.0, y), Offset(-36 + i * 10.0, y - 10), D.stroke(const Color(0xFF8A5530), 3));
        }
      }
      if (f.kind == 1) {
        // bandana
        c.drawArc(Rect.fromCircle(center: head, radius: 11), math.pi, math.pi, true, D.fill(const Color(0xFFD23C4E)));
      }
    }
    c.restore();
    // hp pips for tougher enemies
    if (!f.dead && f.maxHp > 1 && f.hp < f.maxHp) {
      final w = f.kind == 2 ? 50.0 : 26.0;
      final top = f.kind == 2 ? f.y - 112 : f.y - 70;
      D.bar(c, Rect.fromLTWH(f.x - w / 2, top, w, 6), f.hp / f.maxHp, Pal.red, border: Pal.ink);
    }
    if (f.flash > 0) {
      c.drawCircle(_headOf(f), _headR(f) + 4, D.fill(const Color(0x88FFFFFF)));
    }
    if (alpha < 1) c.restore();
  }

  void _drawOgre(Canvas c, _Foe f, bool walking) {
    final bob = walking ? math.sin(f.anim * .7).abs() * 4 : 0.0;
    D.shadow(c, const Offset(0, 2), 80, 14, .3);
    // legs
    for (final s in [-1.0, 1.0]) {
      final sw = walking ? math.sin(f.anim * .7) * s * 6 : 0.0;
      D.rrect(c, Rect.fromLTWH(-18 + (s > 0 ? 18 : 0) + sw, -26, 16, 26), 6, const Color(0xFF4F7A3A),
          border: Pal.ink, borderWidth: 2.5);
    }
    final body = Offset(0, -52 - bob);
    D.blob(c, body, 36, const Color(0xFF6DAA4A), face: f.dead ? Face.dead : Face.angry, outline: true);
    // loincloth
    D.rrect(c, Rect.fromLTWH(-24, -34 - bob, 48, 12), 4, const Color(0xFF8A5530), border: Pal.ink, borderWidth: 2);
    // tusks
    for (final s in [-1.0, 1.0]) {
      c.drawPath(
          Path()
            ..moveTo(s * 10 - 3, -40 - bob)
            ..lineTo(s * 10 + 3, -40 - bob)
            ..lineTo(s * 10, -50 - bob)
            ..close(),
          D.fill(Pal.white));
    }
    // club
    if (!f.dead) {
      final sw = f.state == _FState.attack ? math.sin(f.anim * .9) * 1.1 : .2;
      c.save();
      c.translate(-30, -60 - bob);
      c.rotate(-1.0 + sw);
      D.rrect(c, const Rect.fromLTWH(-5, -44, 10, 44), 5, const Color(0xFF8A5530), border: Pal.ink, borderWidth: 2.5);
      D.circle(c, const Offset(0, -46), 11, const Color(0xFF6A4128), border: Pal.ink, borderWidth: 2.5);
      c.restore();
    }
  }
}

enum _FState { walk, attack, climb }

class _Foe {
  _Foe(this.kind, this.x);
  final int kind; // 0 knight, 1 ladder, 2 ogre
  double x;
  double y = G019._groundY;
  double speed = 40;
  int hp = 2;
  int maxHp = 2;
  _FState state = _FState.walk;
  double anim = 0;
  double climb = 0;
  double flash = 0;
  double knock = 0;
  bool dead = false;
  bool headOff = false;
  double deadT = 0;
  double vx = 0, vy = 0, fallY = 0;
}

class _Arrow {
  _Arrow(this.pos, this.vel);
  Offset pos;
  Offset vel;
  bool stuck = false;
  double life = 0;
}

class _Cloud {
  _Cloud(this.x, this.y, this.s, this.v);
  double x;
  final double y, s, v;
}
