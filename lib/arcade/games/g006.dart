import '../engine/engine.dart';

/// No.006 Draw to Save the Doge — draw ONE line; it becomes a wall that
/// must hold off the angry bee swarm for 6 seconds.
class G006 extends MiniGame {
  static const _groundY = 522.0;
  static const _dog = Offset(180, 482);
  static const _dogR = 34.0;
  static const _inkMax = 560.0;
  static const _surviveTime = 6.0;

  final List<Offset> _line = [];
  final List<_Bee> _bees = [];
  double _ink = 0;
  bool _drawing = false;
  int _phase = 0; // 0 draw, 1 bees, 2 over
  double _phaseT = 0;
  double _t = 0;
  late Offset _hive;
  int _spawned = 0;
  bool _stung = false;
  double _stungT = 0;
  double _tinkCd = 0;
  double _hiveShake = 0;
  double _solid = 0;

  @override
  void init() {
    _hive = Offset(chance(.5) ? rand(70, 130) : rand(230, 290), 190);
  }

  // ---------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    if (_phase != 0 || _line.isNotEmpty) return;
    _drawing = true;
    _line.add(p);
    host.sfx(Sfx.tap, volume: .5);
  }

  @override
  void onMove(Offset p) {
    if (!_drawing) return;
    final last = _line.last;
    final d = (p - last).distance;
    if (d < 5) return;
    final use = min(d, _inkMax - _ink);
    final np = last + (p - last) / d * use;
    _line.add(Offset(np.dx, min(np.dy, _groundY + 2)));
    _ink += use;
    if ((_line.length % 4) == 0) host.sfx(Sfx.scrub, volume: .25, rate: 1.4);
    if (_ink >= _inkMax - .5) _finishLine();
  }

  @override
  void onUp(Offset p) {
    if (_drawing) _finishLine();
  }

  void _finishLine() {
    _drawing = false;
    if (_phase != 0) return;
    _phase = 1;
    _phaseT = 0;
    _hiveShake = 1;
    host.sfx(Sfx.magic, rate: 1.2);
    host.sfx(Sfx.buzzer, volume: .5, rate: 1.6);
    for (var i = 0; i < _line.length; i += 3) {
      host.fx.sparkle(_line[i], count: 1, radius: 4, color: Pal.yellow);
    }
    _solid = 1;
  }

  // --------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    _phaseT += dt;
    _tinkCd -= dt;
    _hiveShake = M.approach(_hiveShake, _phase == 1 ? .3 : 0, 3, dt);
    _solid = M.approach(_solid, 0, 3, dt);
    if (_phase == 0 && !_drawing && host.time > 6) {
      host.fx.pop(host.tr('go', 'GO!'), _hive + const Offset(0, 60), color: Pal.red);
      _finishLine();
    }
    if (_phase == 1) {
      final want = min(16, (_phaseT * 18).floor() + 1);
      while (_spawned < want) {
        _spawned++;
        final b = _Bee(_hive + Offset(rand(-10, 10), rand(8, 20)), rand(0, 6.28));
        b.vel = Offset(rand(-120, 120), rand(20, 120));
        _bees.add(b);
        if (_spawned % 4 == 1) host.sfx(Sfx.buzzer, volume: .25, rate: rand(1.8, 2.2));
      }
      if (_phaseT >= _surviveTime && !_stung) _survived();
    }
    for (final b in _bees) {
      _moveBee(b, dt);
    }
    // swarm separation so bees spread out along the wall
    for (var i = 0; i < _bees.length; i++) {
      for (var j = i + 1; j < _bees.length; j++) {
        final d = _bees[j].pos - _bees[i].pos;
        final dist = d.distance;
        if (dist < 16 && dist > 1e-4) {
          final push = d / dist * ((16 - dist) * .5);
          _bees[i].pos -= push;
          _bees[j].pos += push;
          _bees[i].vel -= push * 6;
          _bees[j].vel += push * 6;
        }
      }
    }
    if (_stung) _stungT += dt;
  }

  void _moveBee(_Bee b, double dt) {
    b.flap += dt * 50;
    b.wobble += dt * rand(2, 5);
    if (b.calm) {
      // after the win bees fly home dizzy
      final to = _hive - b.pos;
      b.vel = Offset.lerp(b.vel, to / max(to.distance, 1.0) * 90, dt * 2)!;
    } else if (_phase == 1) {
      final to = (_dog - const Offset(0, 6)) - b.pos;
      final d = max(to.distance, 1.0);
      final sp = 185.0 * host.speed;
      final wander = Offset(cos(b.wobble * 1.7 + b.seed) * 90, sin(b.wobble * 2.3 + b.seed) * 90);
      final desired = to / d * sp + wander;
      b.vel += (desired - b.vel) * min(1, dt * 2.6);
    }
    final spd = b.vel.distance;
    final maxS = 260.0 * host.speed;
    if (spd > maxS) b.vel = b.vel / spd * maxS;
    const sub = 3;
    for (var s = 0; s < sub; s++) {
      b.pos += b.vel * (dt / sub);
      if (!b.calm) _collideLine(b);
      if (b.pos.dy > _groundY - 6) {
        b.pos = Offset(b.pos.dx, _groundY - 6);
        if (b.vel.dy > 0) b.vel = Offset(b.vel.dx, -b.vel.dy * .5);
      }
      if (b.pos.dx < 8 || b.pos.dx > 352) {
        b.pos = Offset(b.pos.dx.clamp(8, 352), b.pos.dy);
        b.vel = Offset(-b.vel.dx * .6, b.vel.dy);
      }
      if (b.pos.dy < 44) {
        b.pos = Offset(b.pos.dx, 44);
        b.vel = Offset(b.vel.dx, b.vel.dy.abs());
      }
    }
    b.face = b.vel.dx >= 0 ? 1 : -1;
    // sting
    if (!b.calm && _phase == 1 && !_stung && (b.pos - _dog).distance < _dogR + 4) _sting(b);
  }

  void _collideLine(_Bee b) {
    const rad = 10.0;
    for (var i = 0; i + 1 < _line.length; i++) {
      final a = _line[i], c = _line[i + 1];
      final ab = c - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      if (len2 < 1e-6) continue;
      final t = (((b.pos - a).dx * ab.dx + (b.pos - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
      final q = a + ab * t;
      final d = b.pos - q;
      final dist = d.distance;
      if (dist < rad) {
        final n = dist < 1e-4 ? Offset(-ab.dy, ab.dx) / sqrt(len2) : d / dist;
        b.pos = q + n * rad;
        final vn = b.vel.dx * n.dx + b.vel.dy * n.dy;
        if (vn < 0) {
          b.vel -= n * vn * 1.6;
          if (vn < -60) {
            b.bonk = 1;
            if (_tinkCd <= 0) {
              _tinkCd = .09;
              host.sfx(Sfx.tick, volume: .5, rate: rand(1.2, 1.8));
              host.fx.burst(q, Pal.white, count: 3, speed: 90, size: 3, life: .25, gravity: 0);
            }
          }
        }
      }
    }
  }

  void _sting(_Bee b) {
    _stung = true;
    _phase = 2;
    b.pos = _dog + (b.pos - _dog) / max((b.pos - _dog).distance, 1.0) * (_dogR - 2);
    b.vel = Offset.zero;
    host.sfx(Sfx.hurt, rate: 1.3);
    host.sfx(Sfx.boing, rate: .8);
    host.shake(10, .35);
    host.flash(Pal.red, .2);
    host.hitStop(.15);
    host.fx.pop(host.tr('ouch', 'OUCH!'), _dog - const Offset(0, 80), color: Pal.red, size: 40);
    host.fx.burst(b.pos, Pal.red, count: 14, speed: 200, shape: PartShape.star, size: 6);
    host.lose();
  }

  void _survived() {
    _phase = 2;
    for (final b in _bees) {
      b.calm = true;
    }
    host.sfx(Sfx.cheer);
    host.sfx(Sfx.correct, rate: 1.2);
    for (var i = 0; i < 6; i++) {
      host.fx.add(Particle(
          pos: _dog + Offset(rand(-30, 30), -40),
          vel: Offset(rand(-40, 40), rand(-120, -60)),
          life: 1.2,
          color: Pal.pink,
          size: 7,
          shape: PartShape.heart));
    }
    host.fx.pop(host.tr('safe', 'SAFE!'), _dog - const Offset(0, 100), color: Pal.lime, size: 44, life: 1.2);
    final inkLeft = 1 - _ink / _inkMax;
    host.addScore(100 + (inkLeft * 200).round(), _dog - const Offset(0, 60));
    host.win(stars: inkLeft > .45 ? 3 : (inkLeft > .15 ? 2 : 1));
  }

  @override
  void onTimeUp() => _stung ? host.lose() : host.win(stars: 1);

  // --------------------------------------------------------------- render ---
  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF7FD6FF), Color(0xFFD8F4FF)], rect: const Rect.fromLTWH(0, 0, 360, 540));
    // sun + clouds
    c.drawCircle(const Offset(300, 90), 36, D.fill(const Color(0x55FFF3A0)));
    c.drawCircle(const Offset(300, 90), 24, D.fill(const Color(0xFFFFE066)));
    for (var i = 0; i < 3; i++) {
      final x = (i * 150 + _t * 8) % 520 - 80;
      D.cloud(c, Offset(x, 110 + i * 40.0), 34 + i * 8.0, color: const Color(0xDDFFFFFF));
    }
    // far hills
    c.drawOval(const Rect.fromLTWH(-120, 420, 360, 200), D.fill(const Color(0xFF9BDB7A)));
    c.drawOval(const Rect.fromLTWH(150, 440, 360, 200), D.fill(const Color(0xFF8ACF6A)));
    // tree holding the hive
    _drawTree(c);
    // ground
    c.drawRect(const Rect.fromLTWH(0, _groundY, 360, 130),
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF6CC24A), Color(0xFF3E8E3A)]).createShader(const Rect.fromLTWH(0, _groundY, 360, 130)));
    c.drawLine(const Offset(0, _groundY), const Offset(360, _groundY), D.stroke(const Color(0xFF2F6E2C), 4));
    for (var i = 0; i < 18; i++) {
      final x = i * 21.0 + 6;
      c.drawCircle(Offset(x, _groundY + 18 + (i % 3) * 22), 3, D.fill(i % 4 == 0 ? Pal.yellow : const Color(0x55FFFFFF)));
    }
    _drawDoge(c);
    // hint path
    if (_phase == 0 && _line.isEmpty && host.time < 3.5) {
      final dots = D.fill(const Color(0xAAFFFFFF));
      for (var i = 0; i <= 20; i++) {
        final a = pi + i / 20 * pi;
        c.drawCircle(_dog + Offset(cos(a) * 78, sin(a) * 90 + 34), 3.5, dots);
      }
      final k = (_t * .6) % 1;
      final a = pi + k * pi;
      D.hand(c, _dog + Offset(cos(a) * 78, sin(a) * 90 + 34), _t);
    }
    // the line
    if (_line.length >= 2) {
      final path = Path()..moveTo(_line[0].dx, _line[0].dy);
      for (var i = 1; i < _line.length; i++) {
        path.lineTo(_line[i].dx, _line[i].dy);
      }
      final solidCol = _phase == 0 ? const Color(0xFF3A2A5A) : const Color(0xFF1B1530);
      c.drawPath(path, D.stroke(solidCol, 11)..style = PaintingStyle.stroke);
      c.drawPath(path, D.stroke(_phase == 0 ? const Color(0xFF8C6BFF) : const Color(0xFF5A4AA0), 5)..style = PaintingStyle.stroke);
      if (_solid > .02) {
        c.drawPath(path, D.stroke(Color.fromRGBO(255, 255, 255, _solid), 13)..style = PaintingStyle.stroke);
      }
    } else if (_line.length == 1) {
      c.drawCircle(_line[0], 5.5, D.fill(const Color(0xFF3A2A5A)));
    }
    if (_drawing) {
      final tip = _line.last;
      c.save();
      c.translate(tip.dx, tip.dy);
      c.rotate(-.6);
      D.rrect(c, const Rect.fromLTWH(-5, -44, 10, 36), 3, Pal.yellow, border: Pal.ink, borderWidth: 2);
      c.drawPath(Path()..moveTo(-5, -8)..lineTo(5, -8)..lineTo(0, 0)..close(), D.fill(const Color(0xFFFFD1A6)));
      c.restore();
    }
    // bees
    for (final b in _bees) {
      _drawBee(c, b);
    }
    // HUD: ink bar or survive countdown
    if (_phase == 0) {
      D.rrect(c, const Rect.fromLTWH(70, 50, 220, 30), 15, const Color(0xCC1B1530), border: Pal.white, borderWidth: 2.5);
      D.bar(c, const Rect.fromLTWH(104, 58, 176, 14), 1 - _ink / _inkMax, const Color(0xFF8C6BFF));
      c.save();
      c.translate(88, 65);
      c.rotate(-.6);
      D.rrect(c, const Rect.fromLTWH(-3, -10, 6, 18), 2, Pal.yellow, border: Pal.ink, borderWidth: 1.5);
      c.restore();
    } else if (_phase == 1) {
      final left = (_surviveTime - _phaseT).clamp(0.0, _surviveTime);
      final n = left.ceil();
      final frac = left - left.floor();
      final s = 1.0 + (frac > .8 ? (frac - .8) * 2 : 0.0);
      c.drawCircle(const Offset(180, 100), 36, D.fill(const Color(0xCC1B1530)));
      c.drawArc(Rect.fromCircle(center: const Offset(180, 100), radius: 36), -pi / 2, 2 * pi * left / _surviveTime, false,
          D.stroke(Pal.yellow, 6));
      D.title(c, '$n', const Offset(180, 98), size: 40 * s, color: Pal.white);
    }
    if (_phase == 0 && _line.isEmpty) {
      D.text(c, host.tr('draw', 'DRAW!'), const Offset(180, 110), size: 30, color: Pal.white, stroke: Pal.ink);
    }
  }

  void _drawTree(Canvas c) {
    final left = _hive.dx < 180;
    final tx = left ? 30.0 : 330.0;
    final dir = left ? 1.0 : -1.0;
    // trunk
    c.drawPath(
        Path()
          ..moveTo(tx - 22, _groundY + 4)
          ..lineTo(tx - 14, 150)
          ..lineTo(tx + 14, 150)
          ..lineTo(tx + 22, _groundY + 4)
          ..close(),
        D.fill(const Color(0xFF8A5A3C)));
    c.drawLine(Offset(tx - 4, 200), Offset(tx - 2, 480), D.stroke(const Color(0xFF6B4226), 3));
    // branch to the hive
    c.drawLine(Offset(tx, 160), Offset(_hive.dx + dir * 10, 150), D.stroke(Pal.ink, 16));
    c.drawLine(Offset(tx, 160), Offset(_hive.dx + dir * 10, 150), D.stroke(const Color(0xFF8A5A3C), 11));
    // foliage
    for (final (o, r) in [
      (Offset(tx, 120), 60.0), (Offset(tx + dir * 60, 100), 44.0), (Offset(tx - dir * 20, 70), 40.0),
    ]) {
      c.drawCircle(o, r + 3, D.fill(Pal.ink));
      c.drawCircle(o, r, D.fill(const Color(0xFF3FAE50)));
      c.drawCircle(o - Offset(r * .3, r * .3), r * .5, D.fill(const Color(0xFF5CCB6A)));
    }
    // hive
    final sh = sin(_t * 30) * 3 * _hiveShake;
    c.save();
    c.translate(_hive.dx + sh, _hive.dy);
    c.drawLine(const Offset(0, -40), const Offset(0, -24), D.stroke(Pal.ink, 3));
    for (var i = 0; i < 4; i++) {
      final w = 58.0 - (i - 1.5).abs() * 12;
      final y = -24.0 + i * 13;
      D.rrect(c, Rect.fromCenter(center: Offset(0, y + 6), width: w, height: 16), 8, const Color(0xFFFFC53D),
          border: Pal.ink, borderWidth: 2.5);
    }
    c.drawOval(const Rect.fromLTWH(-8, 14, 16, 12), D.fill(const Color(0xFF3A2A20)));
    c.restore();
  }

  void _drawDoge(Canvas c) {
    final happy = _phase == 2 && !_stung;
    final scared = _phase == 1 && !_stung;
    final shiver = scared ? sin(_t * 45) * 1.2 : 0.0;
    final hop = happy ? -sin(_t * 12).abs() * 10 : 0.0;
    c.save();
    c.translate(_dog.dx + shiver, _dog.dy + hop);
    D.shadow(c, Offset(0, 38 - hop), 90, 14, .25);
    const fur = Color(0xFFF0A040);
    const cream = Color(0xFFFFF1DC);
    // tail
    final wag = happy ? sin(_t * 20) * .5 : .1;
    c.save();
    c.translate(34, 14);
    c.rotate(wag);
    c.drawCircle(const Offset(10, -10), 11, D.fill(fur));
    c.drawCircle(const Offset(10, -10), 11, D.stroke(Pal.ink, 3));
    c.drawCircle(const Offset(10, -10), 5, D.fill(cream));
    c.restore();
    // body
    c.drawOval(const Rect.fromLTWH(-38, 0, 76, 40), D.fill(fur));
    c.drawOval(const Rect.fromLTWH(-38, 0, 76, 40), D.stroke(Pal.ink, 3));
    c.drawOval(const Rect.fromLTWH(-20, 14, 40, 24), D.fill(cream));
    for (final x in const [-24.0, 14.0]) {
      D.rrect(c, Rect.fromLTWH(x, 30, 12, 12), 5, cream, border: Pal.ink, borderWidth: 2.5);
    }
    // head
    const hr = 32.0;
    const head = Offset(0, -12);
    final swell = _stung ? M.clamp01(_stungT * 3) : 0.0;
    final hs = 1 + swell * .35;
    c.save();
    c.translate(head.dx, head.dy);
    c.scale(hs, hs * .95);
    for (final s in const [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(s * 12, -24)
        ..lineTo(s * 30, -44)
        ..lineTo(s * 30, -12)
        ..close();
      c.drawPath(ear, D.fill(fur));
      c.drawPath(ear, D.stroke(Pal.ink, 3));
      c.drawPath(
          Path()
            ..moveTo(s * 18, -24)
            ..lineTo(s * 27, -36)
            ..lineTo(s * 27, -18)
            ..close(),
          D.fill(const Color(0xFFFFB9A6)));
    }
    final skin = Color.lerp(fur, const Color(0xFFFF6B6B), swell)!;
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: hr * 2.1, height: hr * 1.8), D.fill(skin));
    c.drawOval(Rect.fromCenter(center: const Offset(0, 8), width: hr * 1.4, height: hr * .95), D.fill(cream));
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: hr * 2.1, height: hr * 1.8), D.stroke(Pal.ink, 3));
    // eyebrows dots (shiba!)
    for (final s in const [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(s * 12, -17), width: 8, height: 5), D.fill(cream));
    }
    final face = _stung ? Face.cry : (happy ? Face.happy : (scared ? Face.shocked : Face.neutral));
    final look = _bees.isEmpty ? Offset.zero : Offset(((_bees.first.pos.dx - _dog.dx) / 150).clamp(-1, 1), -1);
    D.face(c, const Offset(0, -2), 22, face, look: look);
    // nose
    c.drawOval(Rect.fromCenter(center: const Offset(0, 4), width: 10, height: 7), D.fill(Pal.ink));
    if (_stung) {
      c.drawCircle(const Offset(14, -18), 8 * swell, D.fill(const Color(0xFFFF4B4B)));
      c.drawCircle(const Offset(14, -18), 8 * swell, D.stroke(Pal.ink, 2));
    }
    c.restore();
    if (scared) {
      final y = -40 + (_t * 50) % 16;
      c.drawCircle(Offset(38, y), 4, D.fill(const Color(0xFF7FD3FF)));
    }
    c.restore();
  }

  void _drawBee(Canvas c, _Bee b) {
    c.save();
    c.translate(b.pos.dx, b.pos.dy);
    if (b.face < 0) c.scale(-1, 1);
    final squash = 1 - b.bonk * .25;
    b.bonk = max(0, b.bonk - .08);
    // wings
    final flap = sin(b.flap) * .5 + .5;
    final wing = D.fill(const Color(0xBBFFFFFF));
    c.drawOval(Rect.fromCenter(center: Offset(-2, -9 - flap * 3), width: 11, height: 7 + flap * 5), wing);
    c.drawOval(Rect.fromCenter(center: Offset(4, -9 - flap * 2), width: 9, height: 6 + flap * 4), wing);
    // body
    c.scale(1 / squash, squash);
    final body = Rect.fromCenter(center: Offset.zero, width: 20, height: 15);
    c.drawOval(body, D.fill(Pal.yellow));
    c.save();
    c.clipPath(Path()..addOval(body));
    for (final x in const [-5.0, 1.0]) {
      c.drawRect(Rect.fromLTWH(x, -8, 3.5, 16), D.fill(Pal.ink));
    }
    c.restore();
    c.drawOval(body, D.stroke(Pal.ink, 2));
    c.drawPath(Path()..moveTo(-10, -2)..lineTo(-15, 0)..lineTo(-10, 2)..close(), D.fill(Pal.ink));
    // angry eye
    c.drawCircle(const Offset(6, -2), 2.6, D.fill(Pal.white));
    c.drawCircle(const Offset(6.8, -2), 1.4, D.fill(Pal.ink));
    if (!b.calm) c.drawLine(const Offset(3, -6.5), const Offset(9, -4), D.stroke(Pal.ink, 1.6));
    c.restore();
  }
}

class _Bee {
  _Bee(this.pos, this.seed);
  Offset pos;
  Offset vel = Offset.zero;
  final double seed;
  double flap = 0;
  double wobble = 0;
  double bonk = 0;
  double face = 1;
  bool calm = false;
}
