import '../engine/engine.dart';

/// No.125 Spinning Blades — .io parody. Drag = joystick. Swords orbit your
/// hero; walk over loose swords to add blades. Blade vs blade = CLANG (both
/// break). Blade vs body = KO. Enemies drop their swords. KO 3 to win.
class G125 extends MiniGame {
  double _t = 0;
  late _Fighter _me;
  final List<_Fighter> _foes = [];
  final List<_Pickup> _items = [];
  final List<_Shard> _shards = [];
  int _kills = 0;
  double _killPunch = 0;
  double _clangCd = 0;
  bool _dead = false;

  Offset? _joyBase;
  Offset _joyKnob = Offset.zero;
  final Set<String> _keys = {};
  Offset _cam = Offset.zero;

  static const _world = Rect.fromLTWH(0, 0, 720, 1100);
  static const _screenC = Offset(180, 360);
  static const _goal = 3;
  static const _foeCols = [Color(0xFFFF5A5A), Color(0xFFB45CFF), Color(0xFFFF9F2E), Color(0xFF2EC4B6), Color(0xFFFF5FC8)];
  int _foeColIdx = 0;

  @override
  void init() {
    _me = _Fighter(const Offset(360, 560), const Color(0xFF3FB8FF), true)
      ..blades = 4
      ..hp = 3;
    _cam = _me.pos;
    for (var i = 0; i < 4; i++) {
      _spawnFoe(initial: true);
    }
    for (var i = 0; i < 26; i++) {
      _items.add(_Pickup(Offset(rand(40, 680), rand(40, 1060))));
    }
    // a few right next to the player so growth starts instantly
    for (var i = 0; i < 4; i++) {
      final a = i / 4 * pi * 2 + .4;
      _items.add(_Pickup(_me.pos + Offset(cos(a), sin(a)) * rand(90, 130)));
    }
  }

  void _spawnFoe({bool initial = false}) {
    Offset p;
    var tries = 0;
    do {
      p = Offset(rand(60, 660), rand(60, 1040));
      tries++;
    } while ((p - _me.pos).distance < (initial ? 260 : 380) && tries < 30);
    final f = _Fighter(p, _foeCols[_foeColIdx++ % _foeCols.length], false)
      ..blades = initial ? 2 + randInt(3) : 2 + min(_kills, 3).toInt() + randInt(2)
      ..hp = 1
      ..spinDir = chance(.5) ? 1 : -1
      ..speed = rand(62, 82) * host.speed
      ..think = rand(0, 1);
    _foes.add(f);
  }

  double _bladeR(_Fighter f) => 34 + min(f.blades, 14) * 1.6;
  Offset _bladePos(_Fighter f, int i) {
    final a = f.spin + i / max(1, f.blades) * pi * 2;
    final r = _bladeR(f);
    return f.pos + Offset(cos(a), sin(a)) * r;
  }

  // ---------------------------------------------------------------- update
  @override
  void update(double dt) {
    _t += dt;
    _killPunch = M.approach(_killPunch, 0, 6, dt);
    _clangCd -= dt;
    for (final s in _shards) {
      s.life -= dt;
      s.pos += s.vel * dt;
      s.vel *= .96;
      s.rot += s.spin * dt;
    }
    _shards.removeWhere((s) => s.life <= 0);
    for (final it in _items) {
      it.bob += dt;
    }

    // player movement
    var mv = Offset.zero;
    if (_joyBase != null) {
      final d = _joyKnob - _joyBase!;
      final l = d.distance;
      if (l > 4) mv = d / l * min(1.0, l / 40);
    }
    if (_keys.isNotEmpty) {
      final k = Offset((_keys.contains('right') ? 1.0 : 0) - (_keys.contains('left') ? 1.0 : 0),
          (_keys.contains('down') ? 1.0 : 0) - (_keys.contains('up') ? 1.0 : 0));
      if (k.distance > 0) mv = k / k.distance;
    }
    if (!_dead && !host.finished) _me.vel = mv * 132;
    final all = [_me, ..._foes];
    for (final f in all) {
      f.spin += dt * (4.2 - min(f.blades, 12) * .12) * f.spinDir;
      f.invuln = max(0, f.invuln - dt);
      f.flash = max(0, f.flash - dt);
      f.kb *= max(0, 1 - dt * 6);
      if (f.dead) continue;
      f.pos += (f.vel + f.kb) * dt;
      f.pos = Offset(f.pos.dx.clamp(_world.left + 20, _world.right - 20), f.pos.dy.clamp(_world.top + 20, _world.bottom - 20));
      if (f.vel.distance > 5) f.walk += dt * 12;
    }
    _cam = M.approachO(_cam, _me.pos, 8, dt);

    if (!host.finished) {
      for (final f in _foes) {
        _ai(f, dt);
      }
    }
    // pickups
    for (final f in all) {
      if (f.dead) continue;
      for (final it in _items) {
        if (it.taken) continue;
        if ((it.pos - f.pos).distance < 30) {
          it.taken = true;
          f.blades++;
          f.pop = 1;
          if (f.isMe) {
            host.sfx(Sfx.pickup, rate: 1 + min(f.blades, 14) * .04);
            host.fx.pop('+1', _toScreen(f.pos) + const Offset(0, -40), color: Pal.yellow, size: 20, life: .5);
            host.fx.sparkle(_toScreen(it.pos), count: 5, radius: 20, color: Pal.yellow);
          }
        }
      }
    }
    _items.removeWhere((i) => i.taken);
    if (_items.length < 18 && chance(dt * 3)) {
      _items.add(_Pickup(Offset(rand(40, 680), rand(40, 1060))));
    }
    for (final f in all) {
      f.pop = max(0, f.pop - dt * 3);
    }
    if (!host.finished) _combat();
  }

  void _ai(_Fighter f, double dt) {
    if (f.dead) return;
    f.think -= dt;
    final toMe = _me.pos - f.pos;
    final dMe = toMe.distance;
    if (f.think <= 0) {
      f.think = rand(.3, .7);
      Offset? goal;
      if (!_dead && dMe < 330 && f.blades >= _me.blades - 1) {
        goal = _me.pos + Offset(rand(-30, 30), rand(-30, 30)); // aggressive
      } else if (!_dead && dMe < 200 && f.blades < _me.blades - 1) {
        goal = f.pos - toMe; // flee
      } else {
        var bd = 1e9;
        for (final it in _items) {
          final d = (it.pos - f.pos).distance;
          if (d < bd) {
            bd = d;
            goal = it.pos;
          }
        }
      }
      f.goal = goal ?? Offset(rand(60, 660), rand(60, 1040));
    }
    final d = f.goal - f.pos;
    f.vel = d.distance > 6 ? d / d.distance * f.speed : Offset.zero;
  }

  void _combat() {
    final all = [_me, ..._foes];
    for (var i = 0; i < all.length; i++) {
      final a = all[i];
      if (a.dead) continue;
      for (var j = i + 1; j < all.length; j++) {
        final b = all[j];
        if (b.dead) continue;
        if (!a.isMe && !b.isMe) continue; // foes ignore each other (keeps it about you)
        final dist = (a.pos - b.pos).distance;
        if (dist > _bladeR(a) + _bladeR(b) + 30) continue;
        // blade vs blade clash
        var clashed = false;
        for (var ia = 0; ia < a.blades && !clashed; ia++) {
          final pa = _bladePos(a, ia);
          for (var ib = 0; ib < b.blades; ib++) {
            final pb = _bladePos(b, ib);
            if ((pa - pb).distance < 17) {
              _clash(a, b, (pa + pb) / 2);
              clashed = true;
              break;
            }
          }
        }
        // blade vs body
        _bodyCheck(a, b);
        _bodyCheck(b, a);
        // bodies bump
        if (dist < 34 && dist > .1) {
          final n = (a.pos - b.pos) / dist;
          a.kb += n * 120;
          b.kb -= n * 120;
        }
      }
    }
  }

  void _clash(_Fighter a, _Fighter b, Offset at) {
    if (a.blades > 0) a.blades--;
    if (b.blades > 0) b.blades--;
    final n = (a.pos - b.pos);
    final nn = n.distance > .1 ? n / n.distance : const Offset(1, 0);
    a.kb += nn * 170;
    b.kb -= nn * 170;
    for (var k = 0; k < 2; k++) {
      _shards.add(_Shard(at, Offset(rand(-160, 160), rand(-160, 160)), rand(-12, 12)));
    }
    final sp = _toScreen(at);
    host.fx.burst(sp, Pal.yellow, count: 10, speed: 280, gravity: 0, shape: PartShape.spark, life: .3);
    host.fx.ring(sp, Pal.white, size: 40, life: .2);
    if (_clangCd <= 0) {
      _clangCd = .06;
      host.sfx(Sfx.clang, volume: .6, rate: rand(.9, 1.4));
    }
    host.shake(2);
  }

  void _bodyCheck(_Fighter att, _Fighter vic) {
    if (vic.invuln > 0 || vic.dead) return;
    for (var i = 0; i < att.blades; i++) {
      if ((_bladePos(att, i) - vic.pos).distance < 24) {
        _hit(att, vic);
        return;
      }
    }
  }

  void _hit(_Fighter att, _Fighter vic) {
    vic.hp--;
    vic.invuln = vic.isMe ? 1.1 : .2;
    vic.flash = .15;
    final n = vic.pos - att.pos;
    vic.kb += (n.distance > .1 ? n / n.distance : const Offset(1, 0)) * 360;
    final sp = _toScreen(vic.pos);
    if (vic.isMe) {
      host.sfx(Sfx.hurt);
      host.shake(8);
      host.flash(const Color(0x88FF0000));
      host.fx.burst(sp, Pal.red, count: 14, speed: 240);
      if (vic.hp <= 0) {
        _dead = true;
        vic.dead = true;
        _drop(vic);
        host.sfx(Sfx.explode);
        host.sfx(Sfx.jingleLose, volume: .7);
        host.lose();
      }
      return;
    }
    if (vic.hp <= 0) {
      vic.dead = true;
      _kills++;
      _killPunch = 1;
      _drop(vic);
      host.hitStop(.09);
      host.sfx(Sfx.explode, volume: .8);
      host.sfx(Sfx.combo, rate: 1 + _kills * .15);
      host.shake(9);
      host.fx.burst(sp, vic.color, count: 26, speed: 340, size: 8);
      host.fx.ring(sp, Pal.white, size: 90);
      host.fx.pop(_kills >= _goal ? host.tr('win', 'WIN!') : '${host.tr('ko', 'KO!')} $_kills/$_goal', sp + const Offset(0, -50),
          color: Pal.yellow, size: 30);
      host.addScore(100 * _kills, sp);
      if (_kills >= _goal) {
        host.fx.confetti();
        host.sfx(Sfx.fanfare);
        host.win(stars: _me.hp >= 3 ? 3 : (_me.hp == 2 ? 2 : 1));
      } else {
        _spawnFoe();
      }
    }
  }

  void _drop(_Fighter f) {
    final n = f.blades + 2;
    for (var i = 0; i < n; i++) {
      final a = i / n * pi * 2;
      final p = f.pos + Offset(cos(a), sin(a)) * rand(30, 70);
      _items.add(_Pickup(Offset(p.dx.clamp(30, 690), p.dy.clamp(30, 1070))));
    }
    f.blades = 0;
  }

  // ----------------------------------------------------------------- input
  @override
  void onDown(Offset p) {
    _joyBase = p;
    _joyKnob = p;
  }

  @override
  void onMove(Offset p) {
    if (_joyBase == null) return;
    final d = p - _joyBase!;
    if (d.distance > 56) _joyBase = p - d / d.distance * 56;
    _joyKnob = p;
  }

  @override
  void onUp(Offset p) => _joyBase = null;

  @override
  void onKey(String key, bool down) => down ? _keys.add(key) : _keys.remove(key);

  // ---------------------------------------------------------------- render
  Offset _toScreen(Offset w) => w - _cam + _screenC;

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF2A2440), Color(0xFF151024)]);
    c.save();
    c.translate(_screenC.dx - _cam.dx, _screenC.dy - _cam.dy);
    _renderArena(c);
    for (final it in _items) {
      if (!_visible(it.pos)) continue;
      final p = it.pos + Offset(0, sin(it.bob * 3) * 3);
      c.drawCircle(p, 16, D.fill(Color.fromRGBO(255, 230, 120, .18 + .1 * sin(it.bob * 6))));
      _sword(c, p, -pi / 4 + sin(it.bob * 2) * .2, .8);
    }
    for (final f in [..._foes, _me]) {
      if (!_visible(f.pos)) continue;
      _renderFighter(c, f);
    }
    for (final s in _shards) {
      c.save();
      c.translate(s.pos.dx, s.pos.dy);
      c.rotate(s.rot);
      c.drawRect(const Rect.fromLTWH(-6, -2, 12, 4), D.fill(Color.fromRGBO(220, 230, 245, M.clamp01(s.life * 2))));
      c.restore();
    }
    c.restore();
    _renderHud(c);
  }

  bool _visible(Offset w) => (w.dx - _cam.dx).abs() < 250 && (w.dy - _cam.dy).abs() < 400;

  void _renderArena(Canvas c) {
    // stone tiles only in view
    const cell = 60.0;
    final x0 = ((_cam.dx - 200) / cell).floor(), y0 = ((_cam.dy - 380) / cell).floor();
    final a = D.fill(const Color(0xFF5E7F4A)), b = D.fill(const Color(0xFF557545));
    final line = D.stroke(const Color(0x22000000), 2);
    for (var iy = y0; iy <= y0 + 13; iy++) {
      for (var ix = x0; ix <= x0 + 7; ix++) {
        final r = Rect.fromLTWH(ix * cell, iy * cell, cell, cell);
        if (!_world.overlaps(r)) continue;
        c.drawRect(r, (ix + iy).isEven ? a : b);
        c.drawRect(r, line);
        final h = ((ix * 92837111) ^ (iy * 689287499)) & 0xffff;
        if (h % 7 == 0) {
          c.drawCircle(r.center + Offset((h % 20) - 10, ((h >> 5) % 20) - 10), 3, D.fill(const Color(0xFF7FA35E)));
        }
      }
    }
    // walls
    c.drawRect(_world.inflate(12), D.stroke(const Color(0xFF8A6A4A), 24));
    c.drawRect(_world.inflate(12), D.stroke(Pal.ink, 3));
    for (var x = 0.0; x <= 720; x += 45) {
      c.drawCircle(Offset(x, -12), 7, D.fill(const Color(0xFFB08A5A)));
      c.drawCircle(Offset(x, 1112), 7, D.fill(const Color(0xFFB08A5A)));
    }
  }

  void _sword(Canvas c, Offset p, double ang, double s) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(ang);
    c.scale(s);
    final blade = Path()
      ..moveTo(-3.5, 6)
      ..lineTo(-3.5, -18)
      ..lineTo(0, -25)
      ..lineTo(3.5, -18)
      ..lineTo(3.5, 6)
      ..close();
    c.drawPath(blade, D.fill(const Color(0xFFE8EEF7)));
    c.drawLine(const Offset(0, 4), const Offset(0, -20), D.stroke(const Color(0xFFB0BCD0), 1.5));
    c.drawPath(blade, D.stroke(Pal.ink, 1.8));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-8, 5, 16, 4), const Radius.circular(2)), D.fill(Pal.gold));
    c.drawRect(const Rect.fromLTWH(-2, 9, 4, 7), D.fill(const Color(0xFF7A4A22)));
    c.restore();
  }

  void _renderFighter(Canvas c, _Fighter f) {
    if (f.dead) {
      c.drawCircle(f.pos, 14, D.fill(const Color(0x55000000)));
      return;
    }
    final r = _bladeR(f);
    c.drawCircle(f.pos, r, D.stroke(Color.fromRGBO(255, 255, 255, f.isMe ? .15 : .08), 2));
    D.shadow(c, f.pos + const Offset(0, 16), 34, 10, .3);
    final blink = f.invuln > 0 && f.isMe && (f.invuln * 12).floor().isEven;
    if (!blink) {
      final bob = sin(f.walk) * 2;
      final body = f.flash > 0 ? Pal.white : f.color;
      final s = 1 + f.pop * .2;
      c.save();
      c.translate(f.pos.dx, f.pos.dy + bob);
      c.scale(s);
      c.drawCircle(Offset.zero, 17, D.fill(body));
      c.drawCircle(Offset.zero, 17, D.stroke(Pal.ink, 3));
      c.drawOval(const Rect.fromLTWH(-10, -13, 9, 6), D.fill(const Color(0x66FFFFFF)));
      final look = f.vel.distance > 1 ? f.vel / f.vel.distance : Offset.zero;
      final face = f.isMe
          ? (f.invuln > 0 ? Face.shocked : Face.smug)
          : (f.blades < _me.blades ? Face.shocked : Face.angry);
      D.face(c, look * 3, 14, face, look: look);
      if (f.isMe) {
        // little crown for the hero
        c.drawPath(
            Path()
              ..moveTo(-8, -15)
              ..lineTo(-10, -25)
              ..lineTo(-4, -19)
              ..lineTo(0, -27)
              ..lineTo(4, -19)
              ..lineTo(10, -25)
              ..lineTo(8, -15)
              ..close(),
            D.fill(Pal.gold));
      }
      c.restore();
    }
    for (var i = 0; i < f.blades; i++) {
      final a = f.spin + i / f.blades * pi * 2;
      final p = f.pos + Offset(cos(a), sin(a)) * r;
      _sword(c, p, a + pi / 2 + (f.spinDir > 0 ? .5 : -.5), 1);
    }
    // blade count badge
    final bp = f.pos + const Offset(0, -34);
    D.rrect(c, Rect.fromCenter(center: bp, width: 30, height: 16), 8, f.isMe ? Pal.blue : const Color(0xCC1B1530), border: Pal.ink, borderWidth: 2);
    D.text(c, '${f.blades}', bp, size: 11, color: Pal.white);
  }

  void _renderHud(Canvas c) {
    // offscreen foe arrows
    for (final f in _foes) {
      if (f.dead) continue;
      final sp = _toScreen(f.pos);
      if (sp.dx > 10 && sp.dx < 350 && sp.dy > 90 && sp.dy < 630) continue;
      final d = sp - _screenC;
      final dir = d / d.distance;
      final edge = Offset((_screenC.dx + dir.dx * 400).clamp(22, 338), (_screenC.dy + dir.dy * 400).clamp(104, 618));
      D.arrow(c, edge, dir, 26, f.color, width: 8);
      D.text(c, '${f.blades}', edge - dir * 22, size: 11, color: Pal.white, stroke: Pal.ink, strokeWidth: 3);
    }
    // KO counter
    D.rrect(c, const Rect.fromLTWH(10, 42, 160, 40), 20, const Color(0xCC1B1530), border: Pal.ink, borderWidth: 2);
    for (var i = 0; i < _goal; i++) {
      final on = i < _kills;
      final p = Offset(34 + i * 36.0, 62);
      final s = on && i == _kills - 1 ? 1 + _killPunch * .5 : 1.0;
      c.drawCircle(p, 13 * s, D.fill(on ? Pal.red : const Color(0x33FFFFFF)));
      c.drawCircle(p, 13 * s, D.stroke(Pal.ink, 2));
      if (on) {
        D.line(c, p + Offset(-6 * s, -6 * s), p + Offset(6 * s, 6 * s), Pal.white, 3);
        D.line(c, p + Offset(6 * s, -6 * s), p + Offset(-6 * s, 6 * s), Pal.white, 3);
      }
    }
    D.text(c, host.tr('ko', 'KO'), const Offset(148, 62), size: 16, color: Pal.yellow, stroke: Pal.ink);
    // hearts + my blades
    for (var i = 0; i < 3; i++) {
      D.heart(c, Offset(252 + i * 30.0, 62), 24, i < _me.hp ? Pal.red : const Color(0x44FFFFFF), border: Pal.ink);
    }
    // joystick
    final jb = _joyBase;
    if (jb != null) {
      c.drawCircle(jb, 44, D.fill(const Color(0x33FFFFFF)));
      c.drawCircle(jb, 44, D.stroke(const Color(0x88FFFFFF), 3));
      final d = _joyKnob - jb;
      final k = d.distance > 40 ? jb + d / d.distance * 40 : _joyKnob;
      c.drawCircle(k, 20, D.fill(const Color(0xAAFFFFFF)));
      c.drawCircle(k, 20, D.stroke(Pal.ink, 2));
    } else if (host.time < 2.5 && !host.finished) {
      c.drawCircle(const Offset(180, 530), 44, D.stroke(const Color(0x88FFFFFF), 3));
      D.hand(c, Offset(180 + sin(_t * 3) * 44, 530), _t);
      D.text(c, host.tr('drag', 'DRAG'), const Offset(180, 596), size: 20, stroke: Pal.ink);
    }
  }
}

class _Fighter {
  _Fighter(this.pos, this.color, this.isMe);
  Offset pos;
  final Color color;
  final bool isMe;
  Offset vel = Offset.zero, kb = Offset.zero, goal = Offset.zero;
  int blades = 3, hp = 1;
  double spin = 0, spinDir = 1, invuln = 0, flash = 0, speed = 70, think = 0, walk = 0, pop = 0;
  bool dead = false;
}

class _Pickup {
  _Pickup(this.pos);
  final Offset pos;
  double bob = 0;
  bool taken = false;
}

class _Shard {
  _Shard(this.pos, this.vel, this.spin);
  Offset pos, vel;
  final double spin;
  double rot = 0;
  double life = .6;
}
