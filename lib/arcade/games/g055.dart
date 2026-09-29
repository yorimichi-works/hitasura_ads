import '../engine/engine.dart';

/// No.055 Musical Chairs — walk while the music plays; when it STOPS, tap a
/// free chair and dash! Tapping too early trips you. 3 rounds, one player is
/// kicked out each round. Last one sitting wins.
class G055 extends MiniGame {
  static const _center = Offset(180, 382);
  static const _walkRx = 132.0, _walkRy = 88.0;
  static const _chairRx = 62.0, _chairRy = 40.0;

  final _pl = List.generate(4, (i) => _Runner(i));
  final List<_Chair> _chairs = [];
  final List<_Note> _notes = [];
  int _round = 0;
  _Ph _ph = _Ph.setup;
  double _pt = 0;
  double _t = 0;
  double _walkLen = 2;
  double _walkAngle = 0;
  double _fakeAt = -1;
  double _fake = 0; // fake-out dip 0..1
  bool _fakeDone = false;
  double _stopFlash = 0;
  int _trips = 0;
  double _discoT = 0;
  bool _ended = false;

  @override
  void init() {
    _setupRound();
  }

  void _setupRound() {
    _ph = _Ph.setup;
    _pt = 0;
    final alive = _pl.where((p) => !p.out).toList();
    final nChairs = alive.length - 1;
    _chairs.clear();
    for (var i = 0; i < nChairs; i++) {
      final a = nChairs == 1 ? pi / 2 : -pi / 2 + i * 2 * pi / nChairs + .3;
      final pos = nChairs == 1 ? _center : _center + Offset(cos(a) * _chairRx, sin(a) * _chairRy);
      _chairs.add(_Chair(pos));
    }
    for (final p in alive) {
      p.seat = -1;
      p.target = -1;
      p.state = _St.walk;
      p.stun = 0;
    }
    _walkLen = rand(1.3, 2.3) / sqrt(host.speed);
    _fakeDone = false;
    _fakeAt = _round >= 1 && chance(.6) ? rand(.5, _walkLen - .5) : -1;
    host.setMusicVolume(1);
  }

  @override
  void update(double dt) {
    _t += dt;
    _pt += dt;
    _discoT += dt;
    _stopFlash = max(0, _stopFlash - dt * 1.5);
    final musicOn = _ph == _Ph.walk && _fake <= 0;

    // notes
    if (musicOn && chance(dt * 6)) {
      _notes.add(_Note(Offset(rand(40, 320), 210), Offset(rand(-30, 30), rand(-90, -50)), pick(Pal.candy)));
    }
    for (final n in _notes) {
      if (musicOn || _ph == _Ph.walk) {
        n.pos += n.vel * dt;
        n.life -= dt * .7;
      } else {
        n.vel = Offset(n.vel.dx * .9, n.vel.dy + 600 * dt);
        n.pos += n.vel * dt;
        n.life -= dt * 1.5;
      }
    }
    _notes.removeWhere((n) => n.life <= 0 || n.pos.dy > 660);

    // runners animation
    final alive = _pl.where((p) => !p.out).toList();
    if (_ph == _Ph.walk || _ph == _Ph.setup) {
      _walkAngle += dt * (_fake > 0 ? .3 : 1.15) * host.speed;
    }
    for (var k = 0; k < alive.length; k++) {
      final p = alive[k];
      p.squash = M.approach(p.squash, 1, 10, dt);
      p.stun = max(0, p.stun - dt);
      p.react = max(0, p.react - dt);
      if (p.state == _St.walk) {
        final a = _walkAngle + k * 2 * pi / alive.length;
        p.pos = M.approachO(p.pos, _center + Offset(cos(a) * _walkRx, sin(a) * _walkRy), 10, dt);
        p.hop = (sin(_t * 12 + k) .abs()) * 6;
      } else if (p.state == _St.dash) {
        if (p.stun > 0) {
          p.hop = 0;
        } else {
          _dashStep(p, dt);
        }
      } else if (p.state == _St.seated) {
        p.pos = M.approachO(p.pos, _chairs[p.seat].pos + const Offset(0, -8), 20, dt);
        p.hop = 0;
      }
    }
    for (final p in _pl.where((p) => p.out)) {
      p.flyT += dt;
      p.pos += p.vel * dt;
      p.vel = Offset(p.vel.dx, p.vel.dy + 900 * dt);
      p.spin += dt * 10;
    }
    for (final ch in _chairs) {
      ch.pop = M.approach(ch.pop, 1, 9, dt);
      ch.bump = M.approach(ch.bump, 0, 8, dt);
    }

    if (host.finished) return;

    switch (_ph) {
      case _Ph.setup:
        if (_pt > .7) {
          _ph = _Ph.walk;
          _pt = 0;
        }
      case _Ph.walk:
        if (!_fakeDone && _fakeAt > 0 && _pt > _fakeAt) {
          _fakeDone = true;
          _fake = .45;
          host.setMusicVolume(.15);
          host.sfx(Sfx.glitch, volume: .5);
        }
        if (_fake > 0) {
          _fake -= dt;
          if (_fake <= 0) host.setMusicVolume(1);
        }
        if (_pt > _walkLen + (_fakeDone ? .45 : 0)) _stop();
      case _Ph.scramble:
        _cpuThink(dt);
        final free = _chairs.where((c) => c.owner < 0).length;
        if (free == 0 || _pt > 3.5) _resolve();
      case _Ph.resolve:
        if (_pt > 1.0) {
          if (_ended) return;
          _round++;
          _setupRound();
        }
    }
  }

  void _stop() {
    _ph = _Ph.scramble;
    _pt = 0;
    _stopFlash = 1;
    host.setMusicVolume(0);
    host.sfx(Sfx.buzzer, volume: .7);
    host.shake(5);
    host.punch(.05);
    for (final p in _pl.where((p) => !p.out)) {
      p.state = _St.dash;
      p.target = -1;
      p.react = 0;
      if (p.id != 0) p.think = rand(.28, .52) / sqrt(host.speed);
      p.squash = .8;
    }
  }

  void _cpuThink(double dt) {
    for (final p in _pl) {
      if (p.id == 0 || p.out || p.state != _St.dash) continue;
      p.think -= dt;
      if (p.think > 0) continue;
      if (p.target < 0 || _chairs[p.target].owner >= 0) {
        // nearest free chair
        var best = -1;
        var bd = 1e9;
        for (var i = 0; i < _chairs.length; i++) {
          if (_chairs[i].owner >= 0) continue;
          final d = (_chairs[i].pos - p.pos).distance + rand(0, 25);
          if (d < bd) {
            bd = d;
            best = i;
          }
        }
        p.target = best;
      }
    }
  }

  void _dashStep(_Runner p, double dt) {
    if (p.target < 0) return;
    final ch = _chairs[p.target];
    final goal = ch.pos + const Offset(0, -8);
    final d = goal - p.pos;
    final speed = p.id == 0 ? 460.0 : 330.0 * sqrt(host.speed);
    final dist = d.distance;
    if (dist < 12) {
      if (ch.owner < 0) {
        ch.owner = p.id;
        ch.bump = 1;
        p.state = _St.seated;
        p.seat = p.target;
        p.squash = 1.35;
        host.sfx(p.id == 0 ? Sfx.squish : Sfx.pop, rate: p.id == 0 ? 1 : 1.2);
        host.fx.burst(ch.pos, _Cast.col[p.id], count: 10, speed: 160, size: 6);
        if (p.id == 0) {
          final fast = _pt < .7;
          host.fx.pop(fast ? host.tr('perfect', 'PERFECT!') : host.tr('safe', 'SAFE!'), ch.pos + const Offset(0, -60),
              color: Pal.lime, size: 28);
          host.sfx(Sfx.correct, volume: .7);
          host.fx.ring(ch.pos, Pal.white, size: 50);
        } else {
          p.react = 1;
        }
      } else {
        // taken! bounce off
        host.sfx(Sfx.boing);
        p.pos -= d / max(dist, 1) * 26;
        p.target = -1;
        p.squash = .7;
        p.react = .8;
        if (p.id == 0) {
          host.shake(4);
          host.fx.pop(host.tr('oops', 'OOPS!'), p.pos + const Offset(0, -40), color: Pal.red, size: 22);
        }
      }
      return;
    }
    p.pos += d / dist * min(dist, speed * dt);
    p.hop = (sin(_t * 30)).abs() * 5;
    if (chance(dt * 20)) host.fx.smoke(p.pos + const Offset(0, 14), count: 1, size: 8);
  }

  void _resolve() {
    _ph = _Ph.resolve;
    _pt = 0;
    final losers = _pl.where((p) => !p.out && p.state != _St.seated).toList();
    for (final p in losers) {
      p.out = true;
      p.vel = Offset(p.pos.dx < 180 ? -220 : 220, -520);
      host.sfx(Sfx.boing, rate: .8);
      host.fx.pop(host.tr('out', 'OUT!'), p.pos + const Offset(0, -40), color: Pal.red, size: 30);
    }
    host.shake(6);
    final meOut = _pl[0].out;
    if (meOut) {
      _ended = true;
      host.sfx(Sfx.aww);
      host.setMusicVolume(1);
      host.lose();
      return;
    }
    host.sfx(Sfx.cheer, volume: .5);
    if (_pl.where((p) => !p.out).length == 1) {
      _ended = true;
      host.fx.confetti(count: 80);
      host.fx.coins(_pl[0].pos, count: 16);
      host.sfx(Sfx.fanfare);
      host.setMusicVolume(1);
      host.win(stars: _trips == 0 ? 3 : (_trips == 1 ? 2 : 1));
    }
  }

  @override
  void onTimeUp() {
    host.setMusicVolume(1);
    if (!_pl[0].out) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  @override
  void onDown(Offset p) {
    final pos = p;
    final me = _pl[0];
    if (me.out) return;
    if (_ph == _Ph.walk || _ph == _Ph.setup) {
      if (me.stun > 0) return;
      // jumped the gun!
      _trips++;
      me.stun = .9;
      me.react = .9;
      me.squash = .6;
      host.sfx(Sfx.slap);
      host.sfx(Sfx.oops, volume: .7);
      host.shake(4);
      host.fx.pop(host.tr('too_early', 'TOO EARLY!'), me.pos + const Offset(0, -44), color: Pal.red, size: 22);
      host.fx.sparkle(me.pos + const Offset(0, -24), count: 6, radius: 18, color: Pal.yellow);
      return;
    }
    if (_ph != _Ph.scramble || me.state != _St.dash) return;
    var best = -1;
    var bd = 1e9;
    for (var i = 0; i < _chairs.length; i++) {
      if (_chairs[i].owner >= 0) continue;
      final d = (_chairs[i].pos - pos).distance;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    if (best >= 0 && me.target != best) {
      me.target = best;
      host.sfx(Sfx.whoosh, rate: 1.2);
      // a tripped player keeps some stun into the scramble — that's the penalty
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down || key != 'action') return;
    final me = _pl[0];
    if (_ph == _Ph.scramble) {
      var best = 0;
      var bd = 1e9;
      for (var i = 0; i < _chairs.length; i++) {
        if (_chairs[i].owner >= 0) continue;
        final d = (_chairs[i].pos - me.pos).distance;
        if (d < bd) {
          bd = d;
          best = i;
        }
      }
      onDown(_chairs[best].pos);
    } else {
      onDown(me.pos);
    }
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    final musicOn = _ph == _Ph.walk && _fake <= 0;
    // wall
    D.gradientBg(c, const [Color(0xFF3B1E6E), Color(0xFF6A2C91)], rect: const Rect.fromLTWH(0, 0, 360, 250));
    for (var x = 0.0; x < 360; x += 30) {
      c.drawRect(Rect.fromLTWH(x, 0, 14, 250), D.fill(const Color(0x14FFFFFF)));
    }
    // bunting
    for (var row = 0; row < 2; row++) {
      final y0 = 58.0 + row * 34;
      final path = Path()..moveTo(0, y0);
      path.quadraticBezierTo(180, y0 + 30, 360, y0);
      c.drawPath(path, D.stroke(const Color(0xAAFFFFFF), 2));
      for (var i = 0; i < 12; i++) {
        final tx = 15.0 + i * 30 + row * 15;
        final ty = y0 + 30 * 4 * (tx / 360) * (1 - tx / 360) * .5 * 2 - 2;
        c.drawPath(
            Path()
              ..moveTo(tx - 9, ty)
              ..lineTo(tx + 9, ty)
              ..lineTo(tx, ty + 16 + sin(_t * 4 + i) * 2)
              ..close(),
            D.fill(Pal.candy[(i + row * 3) % Pal.candy.length]));
      }
    }
    // disco ball
    final swing = sin(_t * 1.4) * .12;
    final ball = Offset(180 + swing * 120, 150);
    D.line(c, const Offset(180, 36), ball, const Color(0xFF999999), 2);
    c.drawCircle(ball, 26, D.fill(const Color(0xFFB9C4D6)));
    for (var i = 0; i < 5; i++) {
      for (var j = 0; j < 5; j++) {
        final o = ball + Offset(-20 + i * 10.0, -20 + j * 10.0);
        if ((o - ball).distance < 23) {
          final lit = ((i + j + (_discoT * 8).floor()) % 4 == 0) && musicOn;
          c.drawRect(Rect.fromCenter(center: o, width: 8, height: 8),
              D.fill(lit ? Pal.white : D.hsv(200 + i * 20.0 + j * 10, .15, .75)));
        }
      }
    }
    c.drawCircle(ball, 26, D.stroke(Pal.ink, 3));
    // speakers
    for (final sx in const [34.0, 326.0]) {
      final pulse = musicOn ? M.wave(_t, 4) * 4 : 0.0;
      D.rrect(c, Rect.fromCenter(center: Offset(sx, 196), width: 50, height: 86), 8, const Color(0xFF2A2440),
          border: Pal.ink);
      c.drawCircle(Offset(sx, 180), 14 + pulse, D.fill(const Color(0xFF55507A)));
      c.drawCircle(Offset(sx, 180), 6, D.fill(Pal.ink));
      c.drawCircle(Offset(sx, 214), 9 + pulse * .5, D.fill(const Color(0xFF55507A)));
    }

    // floor
    D.gradientBg(c, const [Color(0xFFFFC7E0), Color(0xFFFF8FB8)], rect: const Rect.fromLTWH(0, 240, 360, 400));
    final tile = D.fill(const Color(0x22FFFFFF));
    for (var j = 0; j < 10; j++) {
      for (var i = 0; i < 9; i++) {
        if ((i + j).isEven) c.drawRect(Rect.fromLTWH(i * 40.0, 240 + j * 40.0, 40, 40), tile);
      }
    }
    c.drawRect(const Rect.fromLTWH(0, 236, 360, 8), D.fill(const Color(0xFF3B1E6E)));
    // disco light spots
    if (musicOn) {
      for (var i = 0; i < 5; i++) {
        final a = _discoT * (1 + i * .2) + i * 1.3;
        final o = Offset(180 + cos(a) * 140, 420 + sin(a * 1.3) * 150);
        c.drawOval(Rect.fromCenter(center: o, width: 60, height: 30),
            D.fill(D.hsv(i * 70.0 + _t * 60, .6, 1, .35)));
      }
    }
    // rug
    c.drawOval(Rect.fromCenter(center: _center + const Offset(0, 6), width: 330, height: 230), D.fill(const Color(0x33FFFFFF)));
    c.drawOval(Rect.fromCenter(center: _center + const Offset(0, 6), width: 330, height: 230), D.stroke(const Color(0x66FFFFFF), 3));

    // notes
    for (final n in _notes) {
      final a = n.life.clamp(0.0, 1.0);
      final col = n.col.withValues(alpha: a);
      c.drawOval(Rect.fromCenter(center: n.pos, width: 12, height: 9), D.fill(col));
      D.line(c, n.pos + const Offset(5, 0), n.pos + const Offset(5, -18), col, 2.5);
      D.line(c, n.pos + const Offset(5, -18), n.pos + const Offset(11, -13), col, 2.5);
    }

    // depth sorted: chairs + runners
    final items = <(double, void Function())>[];
    for (var i = 0; i < _chairs.length; i++) {
      final ch = _chairs[i];
      items.add((ch.pos.dy, () => _drawChair(c, ch)));
    }
    for (final p in _pl) {
      if (p.out && p.flyT > 2) continue;
      final y = p.state == _St.seated ? _chairs[p.seat].pos.dy + .5 : p.pos.dy + 10;
      items.add((p.out ? 999 : y, () => _drawRunner(c, p)));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final it in items) {
      it.$2();
    }

    // STOP banner
    if (_stopFlash > 0) {
      final k = M.easeOutBack(M.clamp01((1 - _stopFlash) / .25));
      D.title(c, host.tr('stop', 'STOP!'), const Offset(180, 120), size: 64 * k.clamp(.01, 2), color: Pal.red,
          rotate: -.08);
    }
    if (_ph == _Ph.walk && _fake > 0) {
      D.text(c, '...?', const Offset(180, 120), size: 34, color: Pal.white, stroke: Pal.ink);
    }

    // HUD: round + alive icons
    D.rrect(c, const Rect.fromLTWH(10, 44, 110, 30), 15, const Color(0xCC1B1530), border: Pal.white, borderWidth: 2);
    D.text(c, '${host.tr('round', 'ROUND')} ${min(_round + 1, 3)}/3', const Offset(65, 59), size: 15, color: Pal.yellow,
        maxWidth: 100);
    D.rrect(c, const Rect.fromLTWH(200, 42, 146, 34), 17, const Color(0xCC1B1530), border: Pal.white, borderWidth: 2);
    for (var i = 0; i < 4; i++) {
      final o = Offset(222 + i * 34.0, 60);
      _Cast.draw(c, i, o, 12, face: _pl[i].out ? Face.dead : _Cast.face[i]);
      if (_pl[i].out) {
        D.line(c, o + const Offset(-12, -12), o + const Offset(12, 12), Pal.red, 4);
        D.line(c, o + const Offset(12, -12), o + const Offset(-12, 12), Pal.red, 4);
      }
    }

    // hints
    final me = _pl[0];
    if (!me.out && !host.finished) {
      if (_ph == _Ph.scramble && me.state == _St.dash) {
        var best = -1;
        var bd = 1e9;
        for (var i = 0; i < _chairs.length; i++) {
          if (_chairs[i].owner >= 0) continue;
          final d = (_chairs[i].pos - me.pos).distance;
          if (d < bd) {
            bd = d;
            best = i;
          }
        }
        if (best >= 0 && me.target < 0) {
          D.hand(c, _chairs[best].pos + const Offset(0, 6), _t, size: 40);
          D.title(c, host.tr('tap', 'TAP!'), const Offset(180, 590), size: 34, color: Pal.white);
        }
      } else if (_ph == _Ph.walk || _ph == _Ph.setup) {
        final wait = host.tr('wait', 'WAIT...');
        D.text(c, wait, const Offset(180, 590), size: 24, color: Pal.white, stroke: Pal.ink,
            shadow: const Color(0x55000000));
        if (host.time < 3) {
          D.text(c, host.tr('stop', 'STOP!'), const Offset(120, 555), size: 16, color: Pal.red, stroke: Pal.white,
              strokeWidth: 3);
          D.arrow(c, const Offset(172, 555), const Offset(1, 0), 30, Pal.yellow, width: 7);
          D.text(c, host.tr('tap', 'TAP!'), const Offset(228, 555), size: 16, color: Pal.lime, stroke: Pal.ink,
              strokeWidth: 3);
        }
      }
    }
  }

  void _drawChair(Canvas c, _Chair ch) {
    final k = M.easeOutBack(ch.pop.clamp(0, 1));
    final o = ch.pos;
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(1.15 * k * (1 + ch.bump * .1), 1.15 * k * (1 - ch.bump * .1));
    D.shadow(c, const Offset(0, 18), 54, 14, .25);
    const wood = Color(0xFFE0703A);
    const dark = Color(0xFF9C4520);
    // legs
    for (final lx in const [-18.0, 18.0]) {
      D.rrect(c, Rect.fromLTWH(lx - 3, 0, 6, 20), 3, dark, border: Pal.ink, borderWidth: 2);
    }
    // back
    D.rrect(c, const Rect.fromLTWH(-20, -40, 40, 34), 8, wood, border: Pal.ink, borderWidth: 2.5);
    D.rrect(c, const Rect.fromLTWH(-13, -34, 26, 8), 4, const Color(0x55FFFFFF));
    // seat
    D.rrect(c, const Rect.fromLTWH(-24, -8, 48, 12), 6, const Color(0xFFFF9F5A), border: Pal.ink, borderWidth: 2.5);
    c.restore();
  }

  void _drawRunner(Canvas c, _Runner p) {
    var face = _Cast.face[p.id];
    if (p.out) {
      face = Face.cry;
    } else if (p.state == _St.seated) {
      face = p.id == 0 ? Face.happy : Face.smug;
    } else if (p.stun > 0) {
      face = Face.dead;
    } else if (_ph == _Ph.scramble) {
      face = p.react > 0 ? Face.angry : Face.shocked;
    } else if (p.id == 0) {
      face = Face.happy;
    }
    final o = p.pos + Offset(0, -p.hop);
    if (!p.out) D.shadow(c, p.pos + const Offset(0, 16), 34, 10, .3);
    c.save();
    if (p.out) {
      c.translate(o.dx, o.dy);
      c.rotate(p.spin);
      c.translate(-o.dx, -o.dy);
    }
    // little feet
    if (!p.out && p.state != _St.seated) {
      final st = sin(_t * (p.state == _St.dash ? 30 : 12) + p.id) * 4;
      c.drawOval(Rect.fromCenter(center: o + Offset(-7, 14 + st * .3), width: 11, height: 7), D.fill(Pal.ink));
      c.drawOval(Rect.fromCenter(center: o + Offset(7, 14 - st * .3), width: 11, height: 7), D.fill(Pal.ink));
    }
    _Cast.draw(c, p.id, o, 20, face: face, squash: p.squash);
    c.restore();
    if (p.stun > 0 && !p.out) {
      for (var i = 0; i < 3; i++) {
        final a = _t * 6 + i * 2.1;
        D.star(c, o + Offset(cos(a) * 16, -30 + sin(a) * 5), 5, Pal.yellow, border: Pal.ink);
      }
    }
    if (p.id == 0 && !p.out) {
      D.text(c, host.tr('you', 'YOU'), o + const Offset(0, -40), size: 12, color: Pal.white, stroke: Pal.blue,
          strokeWidth: 4);
    }
  }
}

enum _Ph { setup, walk, scramble, resolve }

enum _St { walk, dash, seated }

class _Chair {
  _Chair(this.pos);
  final Offset pos;
  int owner = -1;
  double pop = 0;
  double bump = 0;
}

class _Note {
  _Note(this.pos, this.vel, this.col);
  Offset pos;
  Offset vel;
  final Color col;
  double life = 1;
}

class _Runner {
  _Runner(this.id) : pos = Offset(180 + cos(id * pi / 2) * 132, 382 + sin(id * pi / 2) * 88);
  final int id;
  Offset pos;
  Offset vel = Offset.zero;
  _St state = _St.walk;
  int seat = -1;
  int target = -1;
  double think = 0;
  double stun = 0;
  double react = 0;
  double hop = 0;
  double squash = 1;
  bool out = false;
  double flyT = 0;
  double spin = 0;
}

/// The party cast: YOU (blue hero) and 3 CPU rivals.
abstract final class _Cast {
  static const col = [Color(0xFF3D6BFF), Color(0xFFFF3B5C), Color(0xFF2ECC71), Color(0xFFFFC21F)];
  static const face = [Face.happy, Face.angry, Face.smug, Face.sleepy];

  static void draw(Canvas c, int who, Offset o, double r,
      {Face? face, double squash = 1, Offset look = Offset.zero}) {
    final sq = squash;
    final topY = o.dy + r * (sq - 1) * .5 - r * .95 / sq;
    if (who == 0) {
      D.line(c, Offset(o.dx, topY + 2), Offset(o.dx + r * .15, topY - r * .45), Pal.ink, max(1.5, r * .1));
      D.star(c, Offset(o.dx + r * .15, topY - r * .55), r * .32, Pal.yellow, border: Pal.ink);
    } else if (who == 1) {
      final tuft = Path();
      for (var k = -1; k <= 1; k++) {
        final bx = o.dx + k * r * .38;
        tuft
          ..moveTo(bx - r * .22, topY + r * .2)
          ..lineTo(bx + k * r * .12, topY - r * .42)
          ..lineTo(bx + r * .22, topY + r * .2)
          ..close();
      }
      c.drawPath(tuft, D.fill(const Color(0xFFB8173A)));
      c.drawPath(tuft, D.stroke(Pal.ink, max(1.2, r * .07)));
    }
    D.blob(c, o, r, col[who], face: face ?? _Cast.face[who], look: look, squash: sq);
    final fy = o.dy + r * (sq - 1) * .5;
    if (who == 2) {
      final g = D.stroke(Pal.ink, max(1.2, r * .08));
      final sx = 1 / sqrt(sq);
      for (final s in [-1.0, 1.0]) {
        c.drawCircle(Offset(o.dx + s * r * .34 * sx, fy - r * .06 / sq), r * .26, g);
      }
      D.line(c, Offset(o.dx - r * .1 * sx, fy - r * .08 / sq), Offset(o.dx + r * .1 * sx, fy - r * .08 / sq), Pal.ink,
          max(1.2, r * .07));
    } else if (who == 3) {
      final b = Offset(o.dx + r * .55, topY + r * .28);
      final bow = Path()
        ..moveTo(b.dx, b.dy)
        ..lineTo(b.dx - r * .42, b.dy - r * .25)
        ..lineTo(b.dx - r * .42, b.dy + r * .25)
        ..close()
        ..moveTo(b.dx, b.dy)
        ..lineTo(b.dx + r * .42, b.dy - r * .25)
        ..lineTo(b.dx + r * .42, b.dy + r * .25)
        ..close();
      c.drawPath(bow, D.fill(Pal.pink));
      c.drawPath(bow, D.stroke(Pal.ink, max(1.2, r * .07)));
      c.drawCircle(b, r * .12, D.fill(Pal.pink));
    }
  }
}
