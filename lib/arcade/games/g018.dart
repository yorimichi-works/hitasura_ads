import 'dart:math' as math;

import '../engine/engine.dart';

/// No.018 Army Count Clash — "pick the right gate" army-math runner.
///
/// The blue blob army marches up the road. Steer it (tap / drag left-right)
/// through math gates (+15, x3, -30, ÷2), smash enemy squads in between and
/// finally storm the enemy castle: you need more soldiers than its defenders.
class G018 extends MiniGame {
  static const _armyY = 520.0;
  static const _roadL = 34.0, _roadR = 326.0;
  static const _castleD = 1460.0;

  double _t = 0;
  double _d = 0; // distance marched
  double _army = 12;
  double _shownArmy = 12;
  double _armyX = 180;
  double _targetX = 180;
  double _bump = 0;
  double _pause = 0;
  bool _touched = false;
  int _phase = 0; // 0 marching, 1 castle battle, 2 done
  double _castleHp = 0;
  double _castleMax = 0;
  double _castleShake = 0;
  bool _castleDown = false;
  double _battleClock = 0;

  final List<_Gate> _gates = [];
  final List<_Squad> _squads = [];
  final List<_Deco> _decos = [];
  final List<_Flyer> _flyers = [];

  static const _laneX2 = [108.0, 252.0];
  static const _laneX3 = [83.0, 180.0, 277.0];

  @override
  void init() {
    // Build the level: 4 gate rows (the 3rd has 3 lanes) + 3 enemy squads.
    final gateD = [300.0, 600.0, 900.0, 1200.0];
    final squadD = [450.0, 750.0, 1050.0];
    for (var i = 0; i < 4; i++) {
      final lanes = i == 2 ? 3 : 2;
      final ops = _makeOps(i, lanes);
      _gates.add(_Gate(gateD[i], ops));
    }
    // Squad sizes: based on the "best" running count so they always matter.
    var best = 12.0;
    var worst = 12.0;
    for (var i = 0; i < 4; i++) {
      final g = _gates[i];
      best = g.ops.map((o) => o.apply(best)).reduce(math.max);
      worst = g.ops.map((o) => o.apply(worst)).reduce(math.min);
      if (i < 3) {
        final s = math.max(4, (best * rand(.18, .28)).round());
        _squads.add(_Squad(squadD[i], s.toDouble()));
        best -= s;
        worst -= s;
      }
    }
    _castleMax = math.max(worst + 5, best * rand(.52, .64)).roundToDouble();
    if (_castleMax >= best) _castleMax = (best * .8).roundToDouble();
    _castleHp = _castleMax;
    for (var i = 0; i < 26; i++) {
      _decos.add(_Deco(chance(.5), i * 70.0 + rand(0, 40), randInt(4), rand(.8, 1.25)));
    }
  }

  List<_Op> _makeOps(int stage, int lanes) {
    // one strong good option, one trap, (one mediocre)
    final good = <_Op>[
      _Op('+', [15, 20, 25, 30][randInt(4)] + stage * 5),
      _Op('x', stage >= 2 ? 3 : 2),
      _Op('x', 2),
    ];
    final bad = <_Op>[
      _Op('-', [10, 15, 20][randInt(3)] + stage * 5),
      _Op('÷', 2),
      _Op('-', 30),
    ];
    final ops = <_Op>[pick(good), pick(bad)];
    if (lanes == 3) ops.add(chance(.5) ? _Op('+', 5 + randInt(3) * 5) : _Op('x', 2));
    ops.shuffle(rng);
    return ops;
  }

  // ------------------------------------------------------------ update ---

  @override
  void update(double dt) {
    _t += dt;
    _bump = M.approach(_bump, 0, 8, dt);
    _castleShake = M.approach(_castleShake, 0, 8, dt);
    _shownArmy = M.approach(_shownArmy, _army, 14, dt);
    _armyX = M.approach(_armyX, _targetX, 10, dt);
    for (final g in _gates) {
      g.flash = M.approach(g.flash, 0, 4, dt);
    }
    for (var i = _flyers.length - 1; i >= 0; i--) {
      final f = _flyers[i];
      f.t += dt / f.dur;
      if (f.t >= 1) _flyers.removeAt(i);
    }

    if (host.finished) return;

    if (_phase == 0) {
      if (_pause > 0) {
        _pause -= dt;
        _fightTick(dt);
        return;
      }
      final prev = _d;
      _d += 118 * host.speed * dt;
      for (final g in _gates) {
        if (!g.done && prev < g.d && _d >= g.d) _passGate(g);
      }
      for (final s in _squads) {
        if (!s.done && _d >= s.d - _armyR * .8 - 26) {
          s.done = true;
          s.fighting = true;
          _pause = .75;
          host.sfx(Sfx.whistle, volume: .6);
          host.shake(4);
        }
      }
      if (_d >= _castleD - 150) {
        _d = _castleD - 150;
        _phase = 1;
        _battleClock = 0;
        host.sfx(Sfx.drumroll, volume: .7);
        _targetX = 180;
      }
    } else if (_phase == 1) {
      _battleClock += dt;
      if (_battleClock < .35) return;
      // soldiers charge into the castle; both sides tick down
      final rate = math.max(_castleMax, 20) / 1.4;
      final hit = math.min(rate * dt, math.min(_army, _castleHp));
      _army -= hit;
      _castleHp -= hit;
      if (chance(dt * 30)) {
        _flyers.add(_Flyer(Offset(_armyX + rand(-40, 40), _armyY - 20 + rand(-20, 20)),
            Offset(180 + rand(-40, 40), 190 + rand(-10, 30)), rand(.25, .4), true));
        _castleShake = .6;
        if (chance(.5)) host.sfx(Sfx.punch, volume: .35, rate: rand(.9, 1.4));
        host.fx.burst(Offset(180 + rand(-50, 50), 230 + rand(-30, 20)), Pal.white, count: 3, speed: 120, size: 4);
      }
      if (_castleHp <= .5) {
        _castleHp = 0;
        _castleDown = true;
        _phase = 2;
        host.sfx(Sfx.explode);
        host.sfx(Sfx.fanfare);
        host.shake(16, .6);
        host.hitStop(.1);
        host.flash(Pal.white, .2);
        host.fx.burst(const Offset(180, 200), Pal.red, count: 40, speed: 420, size: 10, shape: PartShape.square,
            colors: const [Color(0xFF8C8FA8), Color(0xFFB54848), Color(0xFF5E6478), Pal.orange]);
        host.fx.confetti();
        host.fx.coins(const Offset(180, 220), count: 20);
        final left = _army.round();
        host.addScore(left * 10 + 100, const Offset(180, 300));
        final ratio = _army / math.max(1, _castleMax);
        host.win(stars: ratio > .6 ? 3 : (ratio > .2 ? 2 : 1));
      } else if (_army < .5) {
        _army = 0;
        _phase = 2;
        host.sfx(Sfx.jingleLose);
        host.sfx(Sfx.aww, volume: .7);
        host.shake(6);
        host.lose();
      }
    }
  }

  void _fightTick(double dt) {
    final s = _squads.firstWhere((s) => s.fighting, orElse: () => _squads.first);
    if (!s.fighting) return;
    final rate = math.max(s.count, 8) / .55;
    final hit = math.min(rate * dt, math.min(_army, s.count));
    _army -= hit;
    s.count -= hit;
    if (chance(dt * 26)) {
      final x = _armyX + rand(-60, 60);
      host.fx.burst(Offset(x, _armyY - 62), chance(.5) ? Pal.sky : Pal.red, count: 4, speed: 140, size: 5);
      host.sfx(Sfx.pop, volume: .4, rate: rand(.9, 1.5));
    }
    if (s.count <= .5 || _pause <= 0) {
      _army -= s.count.clamp(0, _army);
      s.count = 0;
      s.fighting = false;
      _pause = 0;
      _bump = 1;
      host.sfx(Sfx.correct, volume: .6);
      host.fx.pop(host.tr('win', 'WIN!'), Offset(_armyX, _armyY - 120), color: Pal.sky, size: 26);
    }
    if (_army < .5) {
      _army = 0;
      _phase = 2;
      host.sfx(Sfx.jingleLose);
      host.lose();
    }
  }

  void _passGate(_Gate g) {
    g.done = true;
    final lanes = g.ops.length;
    final xs = lanes == 3 ? _laneX3 : _laneX2;
    var best = 0;
    for (var i = 1; i < lanes; i++) {
      if ((xs[i] - _armyX).abs() < (xs[best] - _armyX).abs()) best = i;
    }
    g.chosen = best;
    g.flash = 1;
    final op = g.ops[best];
    final before = _army;
    _army = math.max(0, op.apply(_army));
    final gain = _army - before;
    _bump = 1;
    final at = Offset(xs[best], _armyY - 90);
    if (gain >= 0) {
      host.sfx(op.sym == 'x' ? Sfx.levelup : Sfx.powerup, rate: 1 + _gates.indexOf(g) * .06);
      host.fx.pop('+${gain.round()}', at, color: Pal.lime, size: 34, life: 1);
      host.fx.burst(at, Pal.sky, count: 20, speed: 260, shape: PartShape.star, colors: const [Pal.sky, Pal.white, Pal.yellow]);
      host.punch(.03);
      host.addScore(gain.round());
    } else {
      host.sfx(Sfx.wrong);
      host.sfx(Sfx.aww, volume: .4);
      host.fx.pop('${gain.round()}', at, color: Pal.red, size: 34, life: 1);
      host.fx.burst(at, Pal.red, count: 14, speed: 200, size: 6);
      host.shake(6);
    }
    // spawn new-soldier sparkles
    if (gain > 0) {
      for (var i = 0; i < math.min(12, gain.round()); i++) {
        _flyers.add(_Flyer(Offset(xs[best] + rand(-40, 40), _armyY - 70), Offset(_armyX + rand(-30, 30), _armyY),
            rand(.25, .45), false));
      }
    }
    if (_army < .5) {
      _phase = 2;
      host.sfx(Sfx.jingleLose);
      host.lose();
    }
  }

  // ------------------------------------------------------------- input ---

  void _steer(Offset p) {
    if (host.finished || _phase != 0) return;
    _touched = true;
    _targetX = p.dx.clamp(_roadL + 40, _roadR - 40);
  }

  @override
  void onDown(Offset p) {
    _steer(p);
    host.sfx(Sfx.tap, volume: .4);
  }

  @override
  void onMove(Offset p) => _steer(p);

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'left') _steer(Offset(_targetX - 97, 0));
    if (key == 'right') _steer(Offset(_targetX + 97, 0));
  }

  // ------------------------------------------------------------ render ---

  double get _armyR => 7.2 * math.sqrt(math.min(_shownArmy.round(), 110) + .5);

  double _sy(double worldD) => _armyY - (worldD - _d);

  @override
  void render(Canvas c) {
    // grass
    D.gradientBg(c, const [Color(0xFF5DBE5A), Color(0xFF7BD66A)]);
    final stripe = Paint()..color = const Color(0x14000000);
    for (var i = -1; i < 12; i++) {
      final y = (i * 70 + _d % 140).toDouble();
      c.drawRect(Rect.fromLTWH(0, y, 360, 35), stripe);
    }
    // road
    final road = RRect.fromRectAndRadius(const Rect.fromLTRB(_roadL, -20, _roadR, 700), const Radius.circular(0));
    c.drawRRect(road, D.fill(const Color(0xFFE8C98E)));
    c.drawRect(const Rect.fromLTRB(_roadL - 6, -20, _roadL, 700), D.fill(const Color(0xFFB08A55)));
    c.drawRect(const Rect.fromLTRB(_roadR, -20, _roadR + 6, 700), D.fill(const Color(0xFFB08A55)));
    final dash = Paint()..color = const Color(0x55FFFFFF);
    for (var i = -1; i < 14; i++) {
      final y = i * 60 + _d % 60;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(177, y, 6, 30), const Radius.circular(3)), dash);
    }
    // pebbles on road
    final peb = Paint()..color = const Color(0x33A07840);
    for (var i = 0; i < 18; i++) {
      final y = (i * 53 + _d) % 700 - 30;
      c.drawCircle(Offset(_roadL + 20 + (i * 97 % 250), y), 3 + i % 3, peb);
    }
    // side decorations
    for (final d in _decos) {
      final y = _sy(d.d) + 200;
      final yy = (y % 1820 + 1820) % 1820 - 100;
      if (yy < -60 || yy > 700) continue;
      final x = d.left ? 16.0 : 344.0;
      switch (d.kind) {
        case 0 || 1:
          D.tree(c, Offset(x, yy), 46 * d.s, leaf: d.kind == 0 ? const Color(0xFF2E9E57) : const Color(0xFF4CB86A));
        case 2:
          D.circle(c, Offset(x, yy), 10 * d.s, const Color(0xFF9AA3B5), border: Pal.ink, borderWidth: 2);
        default:
          for (var k = 0; k < 3; k++) {
            D.circle(c, Offset(x - 6 + k * 6.0, yy - (k.isOdd ? 4 : 0)), 3.5, [Pal.pink, Pal.yellow, Pal.white][k]);
          }
      }
    }

    // castle
    final cy = _sy(_castleD);
    if (cy > -200) _drawCastle(c, Offset(180, cy));

    // squads
    for (final s in _squads) {
      final y = _sy(s.d);
      if (y < -80 || y > 720 || (s.done && !s.fighting && s.count <= 0)) continue;
      _drawSquad(c, s, y);
    }
    // gates
    for (final g in _gates) {
      final y = _sy(g.d);
      if (y < -80 || y > 700) continue;
      _drawGate(c, g, y);
    }

    // flyers
    for (final f in _flyers) {
      final p = Offset.lerp(f.from, f.to, f.t)! + Offset(0, -math.sin(f.t * math.pi) * 40);
      _soldier(c, p, 6, Pal.sky, f.t * 2);
    }

    // army
    _drawArmy(c);

    // tutorial
    if (!_touched && _t < 3.5 && !host.finished) {
      final x = 180 + math.sin(_t * 3) * 80;
      D.hand(c, Offset(x, 590), _t);
      D.arrow(c, const Offset(90, 600), const Offset(-1, 0), 50, Pal.white, width: 10);
      D.arrow(c, const Offset(270, 600), const Offset(1, 0), 50, Pal.white, width: 10);
    }
  }

  void _drawArmy(Canvas c) {
    final n = _shownArmy.round();
    final visible = math.min(n, 110);
    final spread = 7.2;
    final marching = _phase == 0 && _pause <= 0;
    for (var i = visible - 1; i >= 0; i--) {
      final a = i * 2.39996;
      final r = spread * math.sqrt(i + .5);
      final p = Offset(_armyX + math.cos(a) * r * 1.15, _armyY + math.sin(a) * r * .8);
      final bob = marching ? math.sin(_t * 14 + i * 1.7).abs() * 3 : math.sin(_t * 30 + i) * 1.5;
      var q = p + Offset(0, -bob);
      if (_phase == 1 && _battleClock > .2) q += Offset(0, -math.min(1, _battleClock - .2) * 40);
      _soldier(c, q, 7.5, Pal.sky, _t * 3 + i);
    }
    // count badge
    final s = 1 + _bump * .35;
    final r = spread * math.sqrt(visible + .5);
    final top = Offset(_armyX, _armyY - r * .8 - 38);
    c.save();
    c.translate(top.dx, top.dy);
    c.scale(s);
    D.rrect(c, const Rect.fromLTWH(-38, -18, 76, 36), 14, const Color(0xFF2E6BFF), border: Pal.ink, borderWidth: 3);
    D.text(c, '${math.max(0, n)}', Offset.zero, size: 26, color: Pal.white, stroke: Pal.ink, strokeWidth: 5);
    c.restore();
  }

  void _soldier(Canvas c, Offset p, double r, Color col, double ph) {
    D.shadow(c, p + Offset(0, r * .9), r * 1.9, r * .7, .22);
    c.drawCircle(p, r, D.fill(col));
    c.drawCircle(p, r, D.stroke(Pal.ink, 1.6));
    // helmet
    c.drawArc(Rect.fromCircle(center: p + Offset(0, -r * .1), radius: r * .95), math.pi, math.pi, true,
        D.fill(Color.lerp(col, Pal.ink, .45)!));
    // eyes
    c.drawCircle(p + Offset(-r * .32, r * .15), r * .16, D.fill(Pal.ink));
    c.drawCircle(p + Offset(r * .32, r * .15), r * .16, D.fill(Pal.ink));
  }

  void _drawSquad(Canvas c, _Squad s, double y) {
    final n = s.count.round();
    final visible = math.min(n, 60);
    for (var i = visible - 1; i >= 0; i--) {
      final a = i * 2.39996;
      final r = 7.0 * math.sqrt(i + .5);
      final p = Offset(180 + math.cos(a) * r * 2.3, y + math.sin(a) * r * .55);
      final jig = s.fighting ? math.sin(_t * 40 + i) * 2 : math.sin(_t * 5 + i) * 1.2;
      _soldier(c, p + Offset(jig, 0), 7, const Color(0xFFFF4B5C), i.toDouble());
      // angry brows
      c.drawLine(p + Offset(jig - 4, -1), p + Offset(jig - 1, 1), D.stroke(Pal.ink, 1.4));
      c.drawLine(p + Offset(jig + 4, -1), p + Offset(jig + 1, 1), D.stroke(Pal.ink, 1.4));
    }
    if (n > 0) {
      final r = 7.0 * math.sqrt(visible + .5);
      D.rrect(c, Rect.fromCenter(center: Offset(180, y - r * .55 - 30), width: 66, height: 30), 12, const Color(0xFFE23A4E),
          border: Pal.ink, borderWidth: 3);
      D.text(c, '$n', Offset(180, y - r * .55 - 30), size: 20, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
    }
  }

  void _drawGate(Canvas c, _Gate g, double y) {
    final lanes = g.ops.length;
    final w = (_roadR - _roadL) / lanes;
    for (var i = 0; i < lanes; i++) {
      final op = g.ops[i];
      final good = op.good;
      final r = Rect.fromLTWH(_roadL + i * w + 5, y - 30, w - 10, 50);
      final chosen = g.done && g.chosen == i;
      final dim = g.done && !chosen;
      final col = good ? const Color(0xFF2FA8FF) : const Color(0xFFFF3B5C);
      final alpha = dim ? .25 : (.62 + (chosen ? g.flash * .38 : 0));
      D.rrect(c, r, 10, col.withValues(alpha: alpha), border: Pal.ink.withValues(alpha: dim ? .3 : 1), borderWidth: 3);
      // glossy top
      D.rrect(c, Rect.fromLTWH(r.left + 5, r.top + 4, r.width - 10, 10), 5, Color.fromRGBO(255, 255, 255, dim ? .1 : .35));
      final label = op.label;
      D.text(c, label, r.center + const Offset(0, 2), size: lanes == 3 ? 26 : 32,
          color: Color.fromRGBO(255, 255, 255, dim ? .4 : 1), stroke: Pal.ink.withValues(alpha: dim ? .3 : 1), strokeWidth: 6);
      // posts
      for (final x in [r.left, r.right]) {
        D.rrect(c, Rect.fromCenter(center: Offset(x, y - 5), width: 8, height: 62), 4, const Color(0xFFDDE3F0),
            border: Pal.ink, borderWidth: 2);
      }
      if (chosen && g.flash > 0) {
        c.drawRRect(RRect.fromRectAndRadius(r.inflate(10 * g.flash), const Radius.circular(14)),
            D.stroke(Color.fromRGBO(255, 255, 255, g.flash), 4));
      }
    }
    // lane guide: highlight the lane the army is heading to
    if (!g.done && _sy(g.d) > 150) {
      final xs = lanes == 3 ? _laneX3 : _laneX2;
      var best = 0;
      for (var i = 1; i < lanes; i++) {
        if ((xs[i] - _targetX).abs() < (xs[best] - _targetX).abs()) best = i;
      }
      final p = Paint()..color = const Color(0x33FFFFFF);
      final top = y + 22;
      c.drawPath(
          Path()
            ..moveTo(xs[best] - w * .35, top)
            ..lineTo(xs[best] + w * .35, top)
            ..lineTo(_armyX + 30, _armyY - 40)
            ..lineTo(_armyX - 30, _armyY - 40)
            ..close(),
          p);
    }
  }

  void _drawCastle(Canvas c, Offset o) {
    final sh = _castleShake * math.sin(_t * 70) * 4;
    final base = o + Offset(sh, 0);
    if (_castleDown) {
      // rubble + white flag
      for (var i = 0; i < 9; i++) {
        D.rrect(c, Rect.fromCenter(center: base + Offset(-80 + i * 20.0, 30 - (i % 3) * 8.0), width: 26, height: 18), 3,
            const Color(0xFF8C8FA8), border: Pal.ink, borderWidth: 2);
      }
      D.line(c, base + const Offset(0, 20), base + const Offset(0, -40), Pal.ink, 3);
      final wave = math.sin(_t * 8) * 4;
      c.drawPath(
          Path()
            ..moveTo(base.dx, base.dy - 40)
            ..quadraticBezierTo(base.dx + 14, base.dy - 44 + wave, base.dx + 28, base.dy - 38)
            ..lineTo(base.dx + 28, base.dy - 20)
            ..quadraticBezierTo(base.dx + 14, base.dy - 26 + wave, base.dx, base.dy - 22)
            ..close(),
          D.fill(Pal.white));
      D.face(c, base + const Offset(50, 0), 20, Face.cry);
      return;
    }
    D.shadow(c, base + const Offset(0, 60), 260, 30, .25);
    // walls
    const wall = Color(0xFF8C8FA8), dark = Color(0xFF5E6478);
    D.rrect(c, Rect.fromCenter(center: base + const Offset(0, 20), width: 200, height: 80), 4, wall,
        border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < 8; i++) {
      D.rrect(c, Rect.fromLTWH(base.dx - 100 + i * 26.0, base.dy - 34, 16, 14), 2, wall, border: Pal.ink, borderWidth: 2.5);
    }
    // towers
    for (final s in [-1.0, 1.0]) {
      final tx = base.dx + s * 100;
      D.rrect(c, Rect.fromLTWH(tx - 26, base.dy - 60, 52, 120), 4, wall, border: Pal.ink, borderWidth: 3);
      final roof = Path()
        ..moveTo(tx - 34, base.dy - 58)
        ..lineTo(tx, base.dy - 110)
        ..lineTo(tx + 34, base.dy - 58)
        ..close();
      c.drawPath(roof, D.fill(const Color(0xFFD23C4E)));
      c.drawPath(roof, D.stroke(Pal.ink, 3));
      D.rrect(c, Rect.fromLTWH(tx - 8, base.dy - 36, 16, 22), 8, dark, border: Pal.ink, borderWidth: 2);
      // flag
      D.line(c, Offset(tx, base.dy - 110), Offset(tx, base.dy - 132), Pal.ink, 2.5);
      c.drawPath(
          Path()
            ..moveTo(tx, base.dy - 132)
            ..lineTo(tx + 20, base.dy - 126 + math.sin(_t * 8) * 2)
            ..lineTo(tx, base.dy - 120)
            ..close(),
          D.fill(Pal.red));
    }
    // gate
    D.rrect(c, Rect.fromCenter(center: base + const Offset(0, 38), width: 50, height: 46), 20, const Color(0xFF3B2A20),
        border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < 3; i++) {
      D.line(c, base + Offset(-12 + i * 12.0, 18), base + Offset(-12 + i * 12.0, 60), const Color(0xFF6A4A30), 3);
    }
    // defenders badge
    final n = _castleHp.round();
    final pulse = 1.0 + (_phase == 1 ? M.wave(_t, 4) * .1 : 0.0);
    c.save();
    c.translate(base.dx, base.dy - 70);
    c.scale(pulse);
    D.rrect(c, const Rect.fromLTWH(-52, -22, 104, 44), 16, const Color(0xFFE23A4E), border: Pal.ink, borderWidth: 3.5);
    D.text(c, '$n', Offset.zero, size: 30, color: Pal.white, stroke: Pal.ink, strokeWidth: 6);
    c.restore();
    // angry face on the gate
    D.face(c, base + const Offset(0, 0), 22, _phase == 1 ? Face.shocked : Face.angry);
  }
}

class _Op {
  _Op(this.sym, this.n);
  final String sym;
  final int n;
  bool get good => sym == '+' || sym == 'x';
  String get label => sym == 'x' ? '×$n' : '$sym$n';
  double apply(double v) => switch (sym) {
        '+' => v + n,
        '-' => v - n,
        'x' => v * n,
        _ => (v / n).floorToDouble(),
      };
}

class _Gate {
  _Gate(this.d, this.ops);
  final double d;
  final List<_Op> ops;
  bool done = false;
  int chosen = -1;
  double flash = 0;
}

class _Squad {
  _Squad(this.d, this.count);
  final double d;
  double count;
  bool done = false;
  bool fighting = false;
}

class _Deco {
  _Deco(this.left, this.d, this.kind, this.s);
  final bool left;
  final double d;
  final int kind;
  final double s;
}

class _Flyer {
  _Flyer(this.from, this.to, this.dur, this.attack);
  final Offset from, to;
  final double dur;
  final bool attack;
  double t = 0;
}
