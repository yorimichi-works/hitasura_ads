import '../engine/engine.dart';

/// No.059 Coin Rain Scramble — money falls from the sky! Drag left/right to
/// grab coins (1), gems (5) and gold bars (10) before the 3 CPU blobs do.
/// Bombs stun you and knock coins loose. Have the most money at the end.
class G059 extends MiniGame {
  static const _groundY = 566.0;
  static const _bodyY = 536.0;

  final _pl = List.generate(4, (i) => _Runner(i));
  final List<_Item> _items = [];
  final List<_Loose> _loose = [];
  double _t = 0;
  double _spawn = 0;
  double _targetX = 90;
  int _keyDir = 0;
  bool _fever = false;
  double _feverT = 0;
  double _cloudShake = 0;

  @override
  void init() {
    const xs = [90.0, 170.0, 240.0, 300.0];
    for (var i = 0; i < 4; i++) {
      _pl[i].x = xs[i];
    }
    _targetX = xs[0];
    // an opening handful
    for (var i = 0; i < 4; i++) {
      _items.add(_Item(0, Offset(rand(30, 330), rand(120, 250)), rand(150, 200)));
    }
  }

  static const _value = [1, 5, 10, 0]; // coin, gem, bar, bomb

  void _spawnItem() {
    final r = host.rng.nextDouble();
    int kind;
    if (_fever) {
      kind = r < .45 ? 2 : (r < .85 ? 0 : 1);
    } else {
      kind = r < .56 ? 0 : (r < .72 ? 1 : (r < .8 ? 2 : 3));
    }
    _items.add(_Item(kind, Offset(rand(22, 338), 172), rand(170, 240) * host.speed * (kind == 3 ? 1.1 : 1)));
  }

  @override
  void update(double dt) {
    _t += dt;
    _cloudShake = max(0, _cloudShake - dt);
    // fever mid-game
    if (!_fever && host.time > 5.0 && host.time < 5.2) {
      _fever = true;
      _feverT = 1.8;
      host.sfx(Sfx.rarityUp);
      host.flash(const Color(0x66FFE680));
      host.fx.pop(host.tr('fever', 'FEVER!'), const Offset(180, 270), color: Pal.yellow, size: 44, life: 1.2);
      host.shake(5);
    }
    if (_fever) {
      _feverT -= dt;
      if (_feverT <= 0) _fever = false;
    }
    _spawn -= dt;
    if (_spawn <= 0 && !host.finished) {
      _spawn = (_fever ? .09 : .2) / host.speed;
      _spawnItem();
      _cloudShake = .15;
    }

    // player movement
    final me = _pl[0];
    if (_keyDir != 0) _targetX = (me.x + _keyDir * 80).clamp(20, 340);
    if (host.pointerDown) _targetX = host.pointer.dx.clamp(20, 340);
    _move(me, _targetX, 520, dt);

    // CPUs
    for (var i = 1; i < 4; i++) {
      final p = _pl[i];
      p.think -= dt;
      if (p.think <= 0) {
        p.think = (i == 3 ? .45 : .25) * rand(.8, 1.3);
        p.goal = _cpuGoal(p);
      }
      final sp = (i == 1 ? 285.0 : (i == 2 ? 265.0 : 215.0)) * sqrt(host.speed);
      _move(p, p.goal, sp, dt);
    }

    // items
    for (final it in _items) {
      it.vy += 260 * dt;
      it.pos += Offset(0, it.vy * dt);
      it.spin += dt;
      if (it.dead) continue;
      for (final p in _pl) {
        if (p.stun > 0 && it.kind != 3) continue;
        final d = Offset(it.pos.dx - p.x, (it.pos.dy - _bodyY) * 1.2).distance;
        if (d < 30) {
          it.dead = true;
          _collect(p, it);
          break;
        }
      }
      if (!it.dead && it.pos.dy > _groundY - 6) {
        it.dead = true;
        if (it.kind == 3) {
          _explode(it.pos, null);
        } else {
          host.fx.burst(Offset(it.pos.dx, _groundY), Pal.white, count: 4, speed: 80, size: 4, gravity: 200);
          // it lies on the ground briefly as loose coins
          _loose.add(_Loose(it.kind, Offset(it.pos.dx, _groundY - 6)));
        }
      }
    }
    _items.removeWhere((it) => it.dead);
    for (final l in _loose) {
      l.life -= dt;
      l.vel = Offset(l.vel.dx * .96, l.vel.dy + 900 * dt);
      l.pos += l.vel * dt;
      if (l.pos.dy > _groundY - 6) {
        l.pos = Offset(l.pos.dx.clamp(10, 350), _groundY - 6);
        l.vel = Offset(l.vel.dx, -l.vel.dy * .35);
      }
      if (l.life > 0 && l.life < 1.9) {
        for (final p in _pl) {
          if (p.stun > 0) continue;
          if ((l.pos.dx - p.x).abs() < 24) {
            l.life = 0;
            p.money += _value[l.kind];
            p.pop = 1;
            if (p.id == 0) host.sfx(Sfx.coin, volume: .6, rate: 1.3);
            break;
          }
        }
      }
    }
    _loose.removeWhere((l) => l.life <= 0);

    for (final p in _pl) {
      p.stun = max(0, p.stun - dt);
      p.pop = M.approach(p.pop, 0, 8, dt);
      p.shown = M.approach(p.shown, p.money.toDouble(), 12, dt);
      p.combo = p.comboT > 0 ? p.combo : 0;
      p.comboT = max(0, p.comboT - dt);
    }
  }

  double _cpuGoal(_Runner p) {
    var bestX = p.x;
    var bestScore = -1e9;
    for (final it in _items) {
      final dx = (it.pos.dx - p.x).abs();
      final tFall = max(.05, (_bodyY - it.pos.dy) / max(it.vy + 60, 60));
      if (it.pos.dy > _bodyY) continue;
      final reach = dx / 260;
      if (it.kind == 3) continue;
      final v = _value[it.kind].toDouble();
      final score = reach < tFall ? v * 3 - dx * .02 : v - dx * .05 - 3;
      if (score > bestScore) {
        bestScore = score;
        bestX = it.pos.dx;
      }
    }
    // dodge bombs overhead (green is careful, red is reckless)
    for (final it in _items) {
      if (it.kind != 3) continue;
      if ((it.pos.dx - bestX).abs() < 30 && it.pos.dy > 300 && chance(p.id == 2 ? .9 : (p.id == 1 ? .3 : .5))) {
        bestX += it.pos.dx > bestX ? -50 : 50;
      }
    }
    return bestX.clamp(20, 340);
  }

  void _move(_Runner p, double target, double speed, double dt) {
    if (p.stun > 0) {
      p.vx = 0;
      return;
    }
    final d = target - p.x;
    final step = d.sign * min(d.abs(), speed * dt);
    p.x += step;
    p.vx = step / dt;
    p.x = p.x.clamp(20, 340);
    p.run += dt * (p.vx.abs() > 20 ? 18 : 0);
  }

  void _collect(_Runner p, _Item it) {
    if (it.kind == 3) {
      _explode(it.pos, p);
      return;
    }
    final v = _value[it.kind];
    p.money += v;
    p.pop = 1;
    p.combo++;
    p.comboT = .7;
    final at = Offset(p.x, _bodyY - 30);
    if (p.id == 0) {
      host.sfx(it.kind == 0 ? Sfx.coin : (it.kind == 1 ? Sfx.gem : Sfx.cash), rate: 1 + min(p.combo, 10) * .05);
      host.fx.pop('+$v', at, color: it.kind == 2 ? Pal.orange : (it.kind == 1 ? Pal.sky : Pal.yellow), size: it.kind == 2 ? 30 : 22);
      if (it.kind == 2) {
        host.shake(3);
        host.fx.burst(at, Pal.yellow, count: 14, speed: 220, shape: PartShape.star, size: 6);
      } else {
        host.fx.sparkle(at, count: 4, radius: 14, color: Pal.yellow);
      }
      if (p.combo > 0 && p.combo % 5 == 0) {
        host.fx.pop('${host.tr('combo', 'COMBO')} x${p.combo}', const Offset(180, 300), color: Pal.pink, size: 28);
        host.sfx(Sfx.combo, rate: 1 + p.combo * .03);
      }
    } else {
      host.fx.pop('+$v', at, color: const Color(0xCCFFFFFF), size: 14, life: .5);
    }
  }

  void _explode(Offset at, _Runner? victim) {
    host.sfx(Sfx.explode, volume: victim == null ? .5 : .9);
    host.fx.burst(at, Pal.orange, count: 18, speed: 260, size: 9, colors: const [Pal.orange, Pal.yellow, Pal.red]);
    host.fx.smoke(at, count: 6, color: const Color(0xCC555555));
    host.fx.ring(at, Pal.white, size: 50);
    final victims = victim == null ? _pl.where((p) => (p.x - at.dx).abs() < 34).toList() : [victim];
    for (final p in victims) {
      if (p.stun > 0) continue;
      p.stun = 1.0;
      final lost = min(p.money, 4);
      p.money -= lost;
      p.combo = 0;
      for (var k = 0; k < lost; k++) {
        _loose.add(_Loose(0, Offset(p.x, _bodyY - 10))
          ..vel = Offset(rand(-220, 220), rand(-380, -200))
          ..life = 2.4);
      }
      if (p.id == 0) {
        host.shake(9);
        host.flash(const Color(0x88FF3B5C));
        host.hitStop(.06);
        if (lost > 0) host.fx.pop('-$lost', Offset(p.x, _bodyY - 50), color: Pal.red, size: 26);
      }
    }
  }

  @override
  void onTimeUp() {
    final me = _pl[0].money;
    var best = 0;
    for (var i = 1; i < 4; i++) {
      best = max(best, _pl[i].money);
    }
    if (me >= best) {
      host.fx.coins(Offset(_pl[0].x, _bodyY), count: 24);
      host.sfx(Sfx.cheer);
      host.win(stars: me >= best * 1.5 ? 3 : (me > best + 5 ? 2 : 1));
    } else {
      host.lose();
    }
  }

  @override
  void onDown(Offset p) => _targetX = p.dx.clamp(20, 340);

  @override
  void onMove(Offset p) => _targetX = p.dx.clamp(20, 340);

  @override
  void onKey(String key, bool down) {
    if (key == 'left') _keyDir = down ? -1 : (_keyDir == -1 ? 0 : _keyDir);
    if (key == 'right') _keyDir = down ? 1 : (_keyDir == 1 ? 0 : _keyDir);
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    D.gradientBg(c, _fever
        ? [D.hsv(_t * 200, .5, 1), const Color(0xFFFFB347), const Color(0xFFFF6FA8)]
        : const [Color(0xFF6B4CD6), Color(0xFFE66BB0), Color(0xFFFFB27A)]);
    if (_fever) D.rays(c, const Offset(180, 170), 700, const Color(0x33FFFFFF), count: 18, t: _t);
    // skyline
    final far = D.fill(const Color(0x553A1F6E));
    for (var i = 0; i < 9; i++) {
      final h = 90.0 + (i * 53) % 110;
      c.drawRect(Rect.fromLTWH(i * 42.0 - 6, _groundY - h - 40, 38, h + 40), far);
    }
    // bank building
    const bank = Rect.fromLTWH(110, 330, 140, 200);
    c.drawRect(bank, D.fill(const Color(0xFFF3E6FF)));
    c.drawPath(
        Path()
          ..moveTo(98, 334)
          ..lineTo(180, 290)
          ..lineTo(262, 334)
          ..close(),
        D.fill(const Color(0xFFE2D0F5)));
    c.drawPath(
        Path()
          ..moveTo(98, 334)
          ..lineTo(180, 290)
          ..lineTo(262, 334)
          ..close(),
        D.stroke(const Color(0x663A1F6E), 3));
    D.coin(c, const Offset(180, 318), 10, spin: _t * .3);
    for (var i = 0; i < 5; i++) {
      c.drawRect(Rect.fromLTWH(122 + i * 26.0, 350, 12, 170), D.fill(const Color(0xFFD9C4F0)));
    }
    c.drawRect(bank, D.stroke(const Color(0x663A1F6E), 3));

    // money clouds
    for (var i = 0; i < 3; i++) {
      final sx = _cloudShake > 0 ? rand(-2, 2) : 0.0;
      final o = Offset(60 + i * 120.0 + sin(_t * .7 + i) * 10 + sx, 164 + (i % 2) * 8);
      D.cloud(c, o + const Offset(0, 6), 70, color: const Color(0x33000000));
      D.cloud(c, o, 70, color: const Color(0xFFFFF4DC));
      D.face(c, o + const Offset(0, 4), 16, _fever ? Face.love : Face.happy, blush: true);
    }

    // ground
    c.drawRect(const Rect.fromLTWH(0, _groundY, 360, 80), D.fill(const Color(0xFF5B3A8A)));
    c.drawRect(const Rect.fromLTWH(0, _groundY, 360, 10), D.fill(const Color(0xFF8C5BD0)));
    for (var x = 0.0; x < 360; x += 36) {
      c.drawRect(Rect.fromLTWH(x + 4, _groundY + 22, 26, 6), D.fill(const Color(0x33FFFFFF)));
    }

    // loose coins
    for (final l in _loose) {
      final a = l.life < .3 ? l.life / .3 : 1.0;
      if (a < 1 && (l.life * 20).floor().isEven) continue;
      _drawItem(c, l.kind, l.pos, 0, .8);
    }
    // falling items
    for (final it in _items) {
      _drawItem(c, it.kind, it.pos, it.spin, 1);
    }

    // players (you in front)
    for (final i in const [3, 2, 1, 0]) {
      final p = _pl[i];
      final bob = p.vx.abs() > 20 ? (sin(p.run)).abs() * 5 : 0.0;
      final o = Offset(p.x, _bodyY - bob);
      D.shadow(c, Offset(p.x, _groundY + 2), 44, 10, .3);
      // basket held overhead
      final face = p.stun > 0 ? Face.dead : (p.pop > .3 ? Face.love : _Cast.face[i]);
      final look = Offset((p.vx / 300).clamp(-1, 1), -1);
      if (!(p.stun > 0)) {
        final st = sin(p.run) * 5;
        c.drawOval(Rect.fromCenter(center: Offset(p.x - 8 + st, _groundY - 3), width: 13, height: 8), D.fill(Pal.ink));
        c.drawOval(Rect.fromCenter(center: Offset(p.x + 8 - st, _groundY - 3), width: 13, height: 8), D.fill(Pal.ink));
      }
      _Cast.draw(c, i, o, i == 0 ? 25 : 22, face: face, look: look, squash: 1 + p.pop * .15);
      if (p.stun > 0) {
        for (var k = 0; k < 3; k++) {
          final a = _t * 7 + k * 2.1;
          D.star(c, o + Offset(cos(a) * 20, -34 + sin(a) * 5), 6, Pal.yellow, border: Pal.ink);
        }
      }
      if (i == 0) {
        D.text(c, host.tr('you', 'YOU'), Offset(p.x, _groundY + 34), size: 14, color: Pal.white, stroke: Pal.blue,
            strokeWidth: 4);
      }
    }

    _drawBars(c);

    if (host.time < 2.2) {
      final hx = 180 + sin(_t * 4) * 90;
      D.hand(c, Offset(hx, 600), _t, size: 40);
      D.arrow(c, const Offset(110, 606), const Offset(-1, 0), 40, Pal.yellow, width: 8);
      D.arrow(c, const Offset(250, 606), const Offset(1, 0), 40, Pal.yellow, width: 8);
    }
  }

  void _drawItem(Canvas c, int kind, Offset o, double spin, double s) {
    switch (kind) {
      case 0:
        D.coin(c, o, 11 * s, spin: spin * 1.5);
      case 1:
        D.gem(c, o, 13 * s, Pal.sky);
        c.drawCircle(o + const Offset(-4, -5), 2.5 * s, D.fill(Pal.white));
      case 2:
        c.save();
        c.translate(o.dx, o.dy);
        c.rotate(sin(spin * 3) * .3);
        c.scale(s);
        final bar = Path()
          ..moveTo(-18, 9)
          ..lineTo(18, 9)
          ..lineTo(12, -9)
          ..lineTo(-12, -9)
          ..close();
        c.drawPath(bar, D.fill(const Color(0xFFFFB800)));
        c.drawPath(
            Path()
              ..moveTo(-12, -9)
              ..lineTo(12, -9)
              ..lineTo(9, -3)
              ..lineTo(-9, -3)
              ..close(),
            D.fill(const Color(0xFFFFE680)));
        c.drawPath(bar, D.stroke(Pal.ink, 2.5));
        D.text(c, '10', const Offset(0, 3), size: 9, color: const Color(0xFF8A5A00));
        c.restore();
      case 3:
        c.drawCircle(o, 14, D.fill(const Color(0xFF2A2440)));
        c.drawCircle(o + const Offset(-4, -5), 4, D.fill(const Color(0x66FFFFFF)));
        c.drawCircle(o, 14, D.stroke(Pal.ink, 2.5));
        D.rrect(c, Rect.fromCenter(center: o + const Offset(0, -15), width: 10, height: 6), 2, const Color(0xFF777777));
        final sp = o + Offset(4 + sin(_t * 30) * 2, -22);
        c.drawCircle(sp, 4 + sin(_t * 40) * 1.5, D.fill(Pal.orange));
        c.drawCircle(sp, 2, D.fill(Pal.yellow));
        D.face(c, o + const Offset(0, 2), 9, Face.angry, ink: Pal.white, blush: false);
    }
  }

  void _drawBars(Canvas c) {
    var top = 1;
    for (final p in _pl) {
      top = max(top, p.money);
    }
    final scaleMax = max(20, top).toDouble();
    D.rrect(c, const Rect.fromLTWH(8, 42, 344, 96), 16, const Color(0xAA1B1530));
    for (var i = 0; i < 4; i++) {
      final p = _pl[i];
      final y = 56.0 + i * 22;
      _Cast.draw(c, i, Offset(28, y + 2), 10, face: _Cast.face[i]);
      final w = 250 * (p.shown / scaleMax);
      final r = Rect.fromLTWH(44, y - 8, 250, 18);
      D.rrect(c, r, 9, const Color(0x33FFFFFF));
      if (w > 1) {
        D.rrect(c, Rect.fromLTWH(44, y - 8, max(w, 18.0), 18), 9, _Cast.col[i], border: i == 0 ? Pal.white : null, borderWidth: 2);
      }
      D.text(c, '${p.shown.round()}', Offset(322, y + 1), size: 16, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
      if (p.money == top && top > 0) {
        final cx = 44 + max(w, 18.0) - 4;
        c.drawPath(
            Path()
              ..moveTo(cx - 8, y - 6)
              ..lineTo(cx - 9, y - 16)
              ..lineTo(cx - 4, y - 11)
              ..lineTo(cx, y - 18)
              ..lineTo(cx + 4, y - 11)
              ..lineTo(cx + 9, y - 16)
              ..lineTo(cx + 8, y - 6)
              ..close(),
            D.fill(Pal.gold));
      }
    }
  }
}

class _Runner {
  _Runner(this.id);
  final int id;
  double x = 180;
  double vx = 0;
  double run = 0;
  double stun = 0;
  int money = 0;
  double shown = 0;
  double pop = 0;
  double goal = 180;
  double think = 0;
  int combo = 0;
  double comboT = 0;
}

class _Item {
  _Item(this.kind, this.pos, this.vy);
  final int kind;
  Offset pos;
  double vy;
  double spin = 0;
  bool dead = false;
}

class _Loose {
  _Loose(this.kind, this.pos);
  final int kind;
  Offset pos;
  Offset vel = Offset.zero;
  double life = 2.0;
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
