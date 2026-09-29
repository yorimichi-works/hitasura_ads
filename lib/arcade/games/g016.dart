import 'dart:math' as math;
import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.016 Whiteout Furnace — Whiteout-Survival parody.
///
/// A tiny town huddles around a giant furnace at -60°C. Tap forests / coal
/// piles to dispatch workers, tap the furnace to burn the fuel they bring
/// back. Heat keeps dropping (much faster during the BLIZZARD); when it is
/// too cold, citizens freeze into ice statues one by one. Keep at least half
/// of the town alive until the timer runs out.
class G016 extends MiniGame {
  static const _c = Offset(180, 352); // furnace / town center
  static const _pop = 20;
  static const _freezeLine = 30.0;
  static const _woodHeat = 10.0;
  static const _coalHeat = 17.0;

  double _t = 0;
  double _heat = 72; // 0..100
  double _heatShown = 72;
  double _boost = 0; // flame boost after feeding
  double _tapPulse = 0;
  double _freezeClock = 0;
  double _feedCombo = 0;
  int _comboN = 0;
  int _wood = 2;
  int _coal = 1;
  bool _dispatched = false;
  bool _fed = false;
  double _blizzAnnounce = -1;
  double _noFuelShake = 0;
  double _windClock = 0;
  double _heartClock = 0;
  double _warned = 0;

  final List<_Citizen> _people = [];
  final List<_Worker> _workers = [];
  final List<_Node> _nodes = [];
  final List<int> _orders = [];
  final List<_Flying> _flying = [];
  final List<_Flake> _flakes = [];
  final List<_Drift> _drifts = [];
  final List<(Offset, bool)> _houses = [];

  // blizzard window (seconds of play time)
  static const _bzStart = 9.0;
  static const _bzEnd = 15.5;
  bool get _blizzard => _t >= _bzStart && _t < _bzEnd;
  double get _bzAmount {
    if (_t < _bzStart - .6 || _t > _bzEnd + .8) return 0;
    if (_t < _bzStart) return (_t - (_bzStart - .6)) / .6;
    if (_t > _bzEnd) return 1 - (_t - _bzEnd) / .8;
    return 1;
  }

  int get _alive => _people.where((p) => !p.frozen).length;
  double get _tempC => -60 + _heatShown * .8;

  @override
  void init() {
    // citizens: crescent around the furnace, leaving the front free
    for (var i = 0; i < _pop; i++) {
      final row = i.isEven ? 0 : 1;
      final k = i ~/ 2;
      final a = (150 + k * 24.0 + row * 12) * math.pi / 180;
      final rx = row == 0 ? 74.0 : 100.0, ry = row == 0 ? 50.0 : 70.0;
      _people.add(_Citizen(
          Offset(_c.dx + math.cos(a) * rx, _c.dy + 10 + math.sin(a) * ry),
          pick(const [Color(0xFF6E8CCB), Color(0xFFB84A62), Color(0xFF5E9E7A), Color(0xFF9C6FD0), Color(0xFFC98A3C)]),
          rand(0, 6),
          chance(.5) ? const Color(0xFF5B3A26) : const Color(0xFF2B2B3A)));
    }
    // cabins in a ring (gaps on the diagonals for the worker paths)
    for (final deg in [-104.0, -76.0, 180.0, 0.0, 76.0, 104.0]) {
      final a = deg * math.pi / 180;
      _houses.add((Offset(_c.dx + math.cos(a) * 148, _c.dy + math.sin(a) * 128), deg > 0 && deg < 180));
    }
    _nodes
      ..add(_Node(const Offset(52, 190), false))
      ..add(_Node(const Offset(52, 548), false))
      ..add(_Node(const Offset(308, 190), true))
      ..add(_Node(const Offset(308, 548), true));
    const homes = [Offset(152, 438), Offset(208, 438), Offset(132, 452), Offset(228, 452)];
    for (var i = 0; i < 4; i++) {
      _workers.add(_Worker(homes[i]));
    }
    for (var i = 0; i < 150; i++) {
      _flakes.add(_Flake(rand(0, 360), rand(0, 640), rand(.4, 1.0), rand(0, 6)));
    }
    for (var i = 0; i < 22; i++) {
      _drifts.add(_Drift(Offset(rand(0, 360), rand(60, 640)), rand(40, 110), rand(10, 26)));
    }
  }

  // ------------------------------------------------------------ update ---

  @override
  double _botT = 0;
  void update(double dt) {
    _t += dt;
    _botT += dt;
    if (_botT > .3 && !host.finished) { _botT = 0;
      final idle = _workers.where((w) => w.state == _WState.idle).length;
      if (_orders.length < idle) onDown(_nodes[randInt(4)].pos);
      if (_heat < 80 && _coal + _wood > 0) _feed();
    }
    final sp = host.speed;
    final bz = _bzAmount;

    if (!host.finished) {
      // heat decay
      final decay = (4.4 + 6.8 * bz) * sp;
      _heat = math.max(0, _heat - decay * dt);

      // blizzard announcement
      if (_blizzAnnounce < 0 && _t >= _bzStart - .6) {
        _blizzAnnounce = 0;
        host.sfx(Sfx.wind, volume: 1);
        host.sfx(Sfx.horror, volume: .5);
        host.shake(6, .5);
        host.flash(const Color(0xFFFFFFFF), .3);
      }
      if (_warned == 0 && _t > _bzStart - 2.4) {
        _warned = 1;
        host.sfx(Sfx.beep, rate: .8);
      }

      // freezing
      if (_heat < _freezeLine) {
        final rate = _heat < 12 ? .5 : .85;
        _freezeClock += dt * sp;
        if (_freezeClock >= rate) {
          _freezeClock = 0;
          _freezeOne();
        }
        _heartClock -= dt;
        if (_heartClock <= 0) {
          _heartClock = .8;
          host.sfx(Sfx.heartbeat, volume: .7);
        }
      } else {
        _freezeClock = math.max(0, _freezeClock - dt);
      }
      if (_alive < _pop / 2) {
        host.sfx(Sfx.jingleLose);
        host.sfx(Sfx.glass, rate: .7);
        host.shake(10, .5);
        host.lose();
      }
    }
    if (_blizzAnnounce >= 0) _blizzAnnounce += dt;

    if (bz > .5) {
      _windClock -= dt;
      if (_windClock <= 0) {
        _windClock = 1.6;
        host.sfx(Sfx.wind, volume: .6, rate: rand(.85, 1.15));
      }
    }

    _heatShown = M.approach(_heatShown, _heat, 8, dt);
    _boost = M.approach(_boost, 0, 3, dt);
    _tapPulse = M.approach(_tapPulse, 0, 6, dt);
    _noFuelShake = M.approach(_noFuelShake, 0, 6, dt);
    _feedCombo = math.max(0, _feedCombo - dt);
    if (_feedCombo == 0) _comboN = 0;

    // workers
    for (final w in _workers) {
      _updateWorker(w, dt);
    }
    for (final n in _nodes) {
      n.wobble = M.approach(n.wobble, 0, 5, dt);
      n.tapPulse = M.approach(n.tapPulse, 0, 5, dt);
    }

    // flying fuel
    for (var i = _flying.length - 1; i >= 0; i--) {
      final f = _flying[i];
      f.t += dt / .34;
      if (f.t >= 1) {
        _flying.removeAt(i);
        _burn(f.coal);
      }
    }

    // citizens
    for (final p in _people) {
      p.freezeAnim = M.approach(p.freezeAnim, p.frozen ? 1 : 0, 6, dt);
      p.cheer = M.approach(p.cheer, host.finished && !p.frozen && _heat > 0 && _alive >= _pop / 2 ? 1 : 0, 4, dt);
    }

    // snow
    final wind = 30 + bz * 420;
    for (final f in _flakes) {
      f.y += (40 + 60 * f.z + bz * 160) * dt;
      f.x += (wind * f.z + math.sin(_t * 2 + f.ph) * 14) * dt;
      if (f.y > 650) f.y -= 670;
      if (f.x > 370) f.x -= 390;
      if (f.x < -10) f.x += 380;
    }

    // chimney smoke
    if (chance(dt * (2 + _heat / 25))) {
      host.fx.smoke(Offset(_c.dx + 2, _c.dy - 132), count: 1,
          color: _heat > _freezeLine ? const Color(0xAAE8E4F0) : const Color(0xAA5A5A6A), size: 16);
    }
    if (_heat > 55 && chance(dt * 5)) {
      host.fx.add(Particle(
          pos: Offset(_c.dx + rand(-6, 6), _c.dy - 132),
          vel: Offset(rand(-30, 30) + bz * 120, rand(-120, -60)),
          life: rand(.4, .9),
          color: pick(const [Pal.yellow, Pal.orange]),
          size: rand(2, 4)));
    }
  }

  void _freezeOne() {
    final warm = _people.where((p) => !p.frozen).toList();
    if (warm.isEmpty) return;
    // the ones furthest from the furnace freeze first
    warm.sort((a, b) => (b.pos - _c).distance.compareTo((a.pos - _c).distance));
    final victim = warm[math.min(warm.length - 1, randInt(3))];
    victim.frozen = true;
    host.sfx(Sfx.glass, volume: .8, rate: rand(1.1, 1.4));
    host.sfx(Sfx.crack, volume: .6);
    host.fx.burst(victim.pos + const Offset(0, -12), const Color(0xFFBFF2FF),
        count: 14, speed: 150, size: 5, shape: PartShape.square, gravity: 200);
    host.fx.pop('-1', victim.pos + const Offset(0, -34), color: const Color(0xFF9FE6FF), size: 22);
    host.shake(3);
  }

  void _updateWorker(_Worker w, double dt) {
    final sp = host.speed;
    const speed = 165.0;
    switch (w.state) {
      case _WState.idle:
        w.pos = M.approachO(w.pos, w.home, 8, dt);
        if (_orders.isNotEmpty && !host.finished) {
          final n = _orders.removeAt(0);
          w
            ..node = n
            ..state = _WState.going;
          _nodes[n].pending--;
          host.sfx(Sfx.step, volume: .5);
        }
      case _WState.going:
        final target = _nodes[w.node].pos + const Offset(0, 18);
        final d = target - w.pos;
        final step = speed * sp * dt;
        w.run += dt * 16;
        w.flip = d.dx < 0;
        if (d.distance <= step) {
          w.pos = target;
          w.state = _WState.gather;
          w.timer = 0;
        } else {
          w.pos += d / d.distance * step;
        }
      case _WState.gather:
        w.timer += dt * sp;
        final swing = (w.timer * 5).floor();
        if (swing != w.lastSwing) {
          w.lastSwing = swing;
          final n = _nodes[w.node];
          n.wobble = 1;
          host.sfx(n.coal ? Sfx.dig : Sfx.chop, volume: .45, rate: rand(.9, 1.2));
          host.fx.burst(n.pos + Offset(rand(-8, 8), -6), n.coal ? const Color(0xFF2A2A33) : const Color(0xFFC89A62),
              count: 4, speed: 120, size: 4, shape: PartShape.square, gravity: 500, life: .4);
        }
        if (w.timer >= .75) {
          w.state = _WState.back;
          w.carry = _nodes[w.node].coal ? 2 : 3;
          w.carryCoal = _nodes[w.node].coal;
          host.sfx(Sfx.pickup, volume: .6);
        }
      case _WState.back:
        final target = w.carryCoal ? const Offset(232, 404) : const Offset(128, 404);
        final d = target - w.pos;
        final step = speed * sp * dt;
        w.run += dt * 16;
        w.flip = d.dx < 0;
        if (d.distance <= step) {
          if (w.carryCoal) {
            _coal += w.carry;
          } else {
            _wood += w.carry;
          }
          host.sfx(Sfx.thud, volume: .6);
          host.sfx(Sfx.coin, volume: .5, rate: 1.2);
          host.fx.pop('+${w.carry}', target + const Offset(0, -26), color: w.carryCoal ? const Color(0xFFDADDF0) : Pal.orange, size: 20);
          host.fx.burst(target, Pal.white, count: 6, speed: 90, size: 4, gravity: 200);
          w.carry = 0;
          w.state = _WState.idle;
        } else {
          w.pos += d / d.distance * step;
        }
    }
  }

  void _burn(bool coal) {
    final gain = coal ? _coalHeat : _woodHeat;
    final wasted = _heat + gain > 100;
    _heat = math.min(100, _heat + gain);
    _boost = 1;
    _comboN++;
    _feedCombo = .7;
    host.sfx(Sfx.fire, volume: .9, rate: 1 + math.min(_comboN, 8) * .06);
    host.sfx(coal ? Sfx.hitHeavy : Sfx.thud, volume: .5);
    host.punch(.02);
    host.shake(2.5);
    const mouth = Offset(180, 342);
    host.fx.burst(mouth, Pal.orange, count: 18, speed: 260, size: 5, gravity: -120,
        colors: const [Pal.yellow, Pal.orange, Pal.red, Pal.white]);
    host.fx.ring(mouth, const Color(0xFFFFC266), size: 70);
    host.fx.pop(wasted ? host.tr('max', 'MAX') : '+${(gain * .8).round()}°', mouth + const Offset(0, -64),
        color: wasted ? Pal.white : Pal.yellow, size: 26);
    host.addScore(coal ? 30 : 15);
    if (_comboN >= 3 && _comboN % 3 == 0) {
      host.fx.pop('${host.tr('combo', 'COMBO')} x$_comboN', const Offset(180, 200), color: Pal.pink, size: 24);
      host.sfx(Sfx.combo, rate: 1 + _comboN * .05);
    }
  }

  // ------------------------------------------------------------- input ---

  void _feed() {
    if (host.finished) return;
    _tapPulse = 1;
    if (_coal + _wood == 0) {
      _noFuelShake = 1;
      host.sfx(Sfx.wrong, volume: .7);
      host.fx.pop(host.tr('no_fuel', 'No fuel!'), _c + const Offset(0, -80), color: const Color(0xFFBFE8FF), size: 22);
      for (final n in _nodes) {
        n.tapPulse = 1;
      }
      return;
    }
    final coal = _coal > 0;
    if (coal) {
      _coal--;
    } else {
      _wood--;
    }
    _fed = true;
    _flying.add(_Flying(coal ? const Offset(232, 398) : const Offset(128, 398), coal));
    host.sfx(Sfx.throwIt, volume: .6, rate: 1.1);
  }

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    // furnace
    if ((p - (_c + const Offset(0, -18))).distance < 58 ||
        Rect.fromLTRB(_c.dx - 20, _c.dy - 140, _c.dx + 20, _c.dy - 40).contains(p) ||
        Rect.fromLTRB(100, 380, 260, 420).contains(p)) {
      _feed();
      return;
    }
    // resource nodes
    for (var i = 0; i < _nodes.length; i++) {
      final n = _nodes[i];
      if ((p - n.pos).distance < 58) {
        final busy = _workers.where((w) => w.state != _WState.idle).length;
        if (_orders.length + busy >= 8) {
          host.sfx(Sfx.tick);
          return;
        }
        _orders.add(i);
        n.pending++;
        n.tapPulse = 1;
        n.wobble = .6;
        _dispatched = true;
        host.sfx(Sfx.select, rate: n.coal ? .9 : 1.1);
        host.fx.ring(n.pos, Pal.white, size: 40, life: .3);
        return;
      }
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'action' || key == 'up') _feed();
    if (key == 'left') onDown(_nodes[(_t * 10).floor() % 2].pos);
    if (key == 'right') onDown(_nodes[2 + (_t * 10).floor() % 2].pos);
  }

  @override
  void onTimeUp() {
    final a = _alive;
    if (a >= _pop / 2) {
      host.fx.confetti();
      host.sfx(Sfx.cheer);
      host.win(stars: a >= _pop ? 3 : (a >= 15 ? 2 : 1));
    } else {
      host.lose();
    }
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    final heatK = (_heatShown / 100).clamp(0.0, 1.0);
    final bz = _bzAmount;
    final cold = 1 - heatK;

    // --- snow ground
    D.gradientBg(c, [
      Color.lerp(const Color(0xFF6F8FC4), const Color(0xFF4A5E97), cold)!,
      Color.lerp(const Color(0xFFBFD6EE), const Color(0xFF9FB5DA), cold)!,
      Color.lerp(const Color(0xFFD9E7F5), const Color(0xFFB6C8E6), cold)!,
    ]);
    for (final d in _drifts) {
      c.drawOval(Rect.fromCenter(center: d.pos + const Offset(0, 4), width: d.w, height: d.h),
          Paint()..color = const Color(0x2A2B4A86));
      c.drawOval(Rect.fromCenter(center: d.pos, width: d.w, height: d.h), Paint()..color = const Color(0x55FFFFFF));
    }

    // --- warm glow of the furnace
    final glowR = 90 + heatK * 150 + _boost * 30;
    c.drawCircle(
        _c,
        glowR,
        Paint()
          ..shader = ui.Gradient.radial(_c, glowR, [
            Color.fromRGBO(255, 170, 80, .62 * heatK + .08),
            Color.fromRGBO(255, 140, 60, .25 * heatK),
            const Color(0x00FF8040),
          ], [0, .55, 1]));
    // trampled paths to resource nodes
    final pathP = D.stroke(const Color(0x3D2E4C85), 16);
    for (final n in _nodes) {
      c.drawLine(_c + const Offset(0, 60), n.pos + const Offset(0, 18), pathP);
    }
    // town plaza ring
    c.drawOval(Rect.fromCenter(center: _c + const Offset(0, 14), width: 250, height: 180),
        D.stroke(const Color(0x33FFFFFF), 6));

    // --- depth-sorted drawables
    final items = <(double, void Function())>[];
    for (final (pos, front) in _houses) {
      items.add((pos.dy, () => _drawHouse(c, pos, heatK, front)));
    }
    for (var i = 0; i < _nodes.length; i++) {
      final n = _nodes[i];
      items.add((n.pos.dy, () => _drawNode(c, n)));
    }
    for (final p in _people) {
      items.add((p.pos.dy, () => _drawCitizen(c, p, heatK)));
    }
    for (final w in _workers) {
      items.add((w.pos.dy, () => _drawWorker(c, w)));
    }
    items.add((_c.dy + 20, () => _drawFurnace(c, heatK)));
    items.add((404, () => _drawPiles(c)));
    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final it in items) {
      it.$2();
    }

    // flying fuel
    for (final f in _flying) {
      const to = Offset(180, 342);
      final p = Offset.lerp(f.from, to, f.t)! + Offset(0, -math.sin(f.t * math.pi) * 60);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(f.t * 8);
      if (f.coal) {
        _coalLump(c, Offset.zero, 7);
      } else {
        _log(c, Offset.zero, 18);
      }
      c.restore();
    }

    // --- snow + blizzard
    final flakeP = Paint()..color = const Color(0xEEFFFFFF);
    final streakP = Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeCap = StrokeCap.round;
    for (final f in _flakes) {
      final r = 1 + f.z * 2.2;
      if (bz > .3) {
        streakP.strokeWidth = r * 1.2;
        c.drawLine(Offset(f.x, f.y), Offset(f.x - 18 * bz * f.z - 2, f.y - 6 * bz), streakP);
      } else {
        c.drawCircle(Offset(f.x, f.y), r, flakeP);
      }
    }
    if (bz > 0) {
      final pulse = .28 + .1 * math.sin(_t * 7);
      c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), Paint()..color = Color.fromRGBO(235, 244, 255, pulse * bz));
      // horizontal wind bands
      for (var i = 0; i < 6; i++) {
        final y = 80.0 + i * 95 + math.sin(_t * 1.3 + i) * 20;
        final x = ((_t * 700 + i * 170) % 700) - 200;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 180, 6), const Radius.circular(3)),
            Paint()..color = Color.fromRGBO(255, 255, 255, .6 * bz));
      }
    }

    // --- frost creeping from the edges
    final frost = ((.62 - heatK) / .62).clamp(0.0, 1.0) * .9 + bz * .25;
    if (frost > 0.02) {
      c.drawRect(
          const Rect.fromLTWH(0, 0, 360, 640),
          Paint()
            ..shader = ui.Gradient.radial(const Offset(180, 340), 420, [
              const Color(0x00CFEFFF),
              Color.fromRGBO(210, 240, 255, math.min(.9, frost)),
            ], [.45 + (1 - frost) * .4, 1]));
      final crystalP = D.stroke(Color.fromRGBO(255, 255, 255, math.min(1, frost * 1.2)), 2);
      for (var i = 0; i < 10; i++) {
        final corner = i % 4;
        final base = Offset(corner.isEven ? 0 : 360, corner < 2 ? 40 : 640);
        final dir = Offset(corner.isEven ? 1 : -1, corner < 2 ? 1 : -1);
        final len = 30 + (i * 17 % 40) * frost;
        final a = (i * 0.37) % 1.2 + .2;
        final tip = base + Offset(dir.dx * math.cos(a), dir.dy * math.sin(a)) * len * 1.5;
        c.drawLine(base, tip, crystalP);
        final mid = Offset.lerp(base, tip, .6)!;
        c.drawLine(mid, mid + Offset(dir.dx * 10, 0), crystalP);
        c.drawLine(mid, mid + Offset(0, dir.dy * 10), crystalP);
      }
    }
    if (_heat < _freezeLine && !host.finished) {
      final a = .25 + .25 * math.sin(_t * 10);
      c.drawRect(const Rect.fromLTWH(0, 0, 360, 640),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..color = Color.fromRGBO(80, 170, 255, a));
      D.text(c, host.tr('freezing', 'FREEZING!'), const Offset(180, 132),
          size: 26, color: const Color(0xFFBFF0FF), stroke: const Color(0xFF123A6B), strokeWidth: 6,
          letterSpacing: 1);
    }

    _drawHud(c, heatK);

    // blizzard banner
    if (_blizzAnnounce >= 0 && _blizzAnnounce < 2.2) {
      final a = _blizzAnnounce;
      final s = a < .3 ? M.easeOutBack(a / .3) : 1.0;
      final fade = a > 1.8 ? 1 - (a - 1.8) / .4 : 1.0;
      c.save();
      c.translate(0, 0);
      c.drawRect(Rect.fromLTWH(0, 250, 360, 70), Paint()..color = Color.fromRGBO(20, 50, 110, .75 * fade));
      c.restore();
      D.title(c, host.tr('blizzard', 'BLIZZARD!'), const Offset(180, 285),
          size: 42, color: Color.fromRGBO(220, 245, 255, fade), stroke: Color.fromRGBO(18, 40, 90, fade),
          scale: s, rotate: math.sin(_t * 30) * .02);
    }

    // tutorial
    if (!host.finished) {
      if (!_dispatched && _t < 6) {
        final n = _nodes[2];
        D.hand(c, n.pos + const Offset(-6, 6), _t);
        c.drawCircle(n.pos, 40 + M.wave(_t, 2) * 8, D.stroke(const Color(0xCCFFFFFF), 3));
      } else if (!_fed && _t < 8 && _coal + _wood > 0) {
        D.hand(c, _c + const Offset(0, -12), _t);
      } else if (_coal + _wood > 0 && _heat < 45) {
        c.drawCircle(_c + const Offset(0, -12), 60 + M.wave(_t, 2.5) * 10,
            D.stroke(Color.fromRGBO(255, 210, 90, .5 + .4 * M.wave(_t, 2.5)), 4));
      }
    }
  }

  // --------------------------------------------------------- art pieces ---

  void _drawHud(Canvas c, double heatK) {
    const panel = Rect.fromLTWH(8, 40, 344, 58);
    D.rrect(c, panel.shift(const Offset(0, 3)), 16, const Color(0x55000000));
    D.rrect(c, panel, 16, const Color(0xE0132446), border: const Color(0xFF8FC3FF), borderWidth: 2);

    // thermometer
    const tube = Rect.fromLTWH(22, 48, 12, 34);
    final hot = Color.lerp(const Color(0xFF5CC8FF), const Color(0xFFFF6A2B), heatK)!;
    D.rrect(c, tube, 6, const Color(0xFF0A1428), border: Pal.white, borderWidth: 2);
    final fillH = 30 * heatK;
    D.rrect(c, Rect.fromLTWH(25, 81 - fillH, 6, fillH + 2), 3, hot);
    // freeze threshold tick
    D.line(c, Offset(16, 81 - 30 * _freezeLine / 100), Offset(40, 81 - 30 * _freezeLine / 100),
        const Color(0xFF9FE6FF), 2);
    D.circle(c, const Offset(28, 86), 8, hot, border: Pal.white, borderWidth: 2);
    final t = _tempC.round();
    final wob = _heat < _freezeLine ? math.sin(_t * 30) * 1.5 : 0.0;
    D.text(c, '${t > 0 ? '+' : ''}$t°C', Offset(48 + wob, 69), size: 26, color: hot, stroke: Pal.ink, strokeWidth: 6,
        anchor: Alignment.centerLeft);

    // survivors
    final alive = _alive;
    final danger = alive < _pop * .65;
    D.circle(c, const Offset(172, 60), 7, Pal.skin, border: Pal.ink, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(163, 67, 18, 16), 6, const Color(0xFFB84A62), border: Pal.ink, borderWidth: 2);
    D.text(c, '$alive', const Offset(188, 70), size: 24,
        color: danger ? Color.lerp(Pal.red, Pal.white, M.wave(_t, 3))! : Pal.white,
        stroke: Pal.ink, strokeWidth: 6, anchor: Alignment.centerLeft);
    D.text(c, '/$_pop', Offset(188 + (alive >= 10 ? 28 : 15), 74), size: 13, color: const Color(0xFFAFC6E8),
        anchor: Alignment.centerLeft);

    // stock
    c.save();
    c.translate(262, 70);
    c.rotate(-.3);
    _log(c, Offset.zero, 22);
    c.restore();
    D.text(c, '$_wood', const Offset(276, 72), size: 22, color: Pal.orange, stroke: Pal.ink, strokeWidth: 5,
        anchor: Alignment.centerLeft);
    _coalLump(c, const Offset(316, 70), 9);
    D.text(c, '$_coal', const Offset(328, 72), size: 22, color: const Color(0xFFDADDF0), stroke: Pal.ink,
        strokeWidth: 5, anchor: Alignment.centerLeft);

    // heat bar
    const bar = Rect.fromLTWH(22, 102, 316, 10);
    D.rrect(c, bar.shift(const Offset(0, 2)), 5, const Color(0x66000000));
    D.rrect(
        c,
        bar,
        5,
        Pal.white,
        gradient: const LinearGradient(colors: [Color(0xFF3F7BFF), Color(0xFF8FDFFF), Color(0xFFFFB24A), Color(0xFFFF4A2B)],
            stops: [0, .3, .55, 1]));
    D.rrect(c, Rect.fromLTWH(bar.left + bar.width * heatK, bar.top, bar.width * (1 - heatK), bar.height), 5,
        const Color(0xCC0A1428));
    final mx = bar.left + bar.width * heatK;
    D.circle(c, Offset(mx, bar.center.dy), 8, Pal.white, border: Pal.ink, borderWidth: 2.5);
    final lx = bar.left + bar.width * _freezeLine / 100;
    D.line(c, Offset(lx, bar.top - 3), Offset(lx, bar.bottom + 3), Pal.white, 2);
    _snowflake(c, Offset(lx, bar.bottom + 12), 6, Pal.white);
    if (_blizzard) {
      final a = .6 + .4 * math.sin(_t * 12);
      for (var i = 0; i < 2; i++) {
        final tp = Offset(mx - 7 + i * 14.0, bar.top - 7);
        c.drawPath(
            Path()
              ..moveTo(tp.dx - 5, tp.dy - 6)
              ..lineTo(tp.dx + 5, tp.dy - 6)
              ..lineTo(tp.dx, tp.dy)
              ..close(),
            D.fill(Color.fromRGBO(120, 200, 255, a)));
      }
    }
  }

  void _snowflake(Canvas c, Offset o, double r, Color col) {
    final p = D.stroke(col, 1.8);
    for (var i = 0; i < 3; i++) {
      final a = i * math.pi / 3;
      final d = Offset(math.cos(a), math.sin(a)) * r;
      c.drawLine(o - d, o + d, p);
    }
  }

  void _drawFurnace(Canvas c, double heatK) {
    final shake = _noFuelShake * math.sin(_t * 60) * 4;
    final squash = 1 + _tapPulse * .06 + _boost * .04;
    c.save();
    c.translate(_c.dx + shake, _c.dy + 26);
    c.scale(1 / squash * 1.02, squash);
    c.translate(-_c.dx, -(_c.dy + 26));

    final core = Color.lerp(const Color(0xFF3A3F66), const Color(0xFFFFA23A), heatK)!;
    // stone platform
    c.drawOval(Rect.fromCenter(center: _c + const Offset(0, 30), width: 150, height: 46), D.fill(const Color(0x55000000)));
    c.drawOval(Rect.fromCenter(center: _c + const Offset(0, 22), width: 140, height: 44), D.fill(const Color(0xFF5E6478)));
    c.drawOval(Rect.fromCenter(center: _c + const Offset(0, 16), width: 140, height: 40), D.fill(const Color(0xFF8A90A6)));
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final p = _c + Offset(math.cos(a) * 62, 16 + math.sin(a) * 17);
      c.drawOval(Rect.fromCenter(center: p, width: 20, height: 9), D.fill(const Color(0xFF7A8096)));
      c.drawOval(Rect.fromCenter(center: p, width: 20, height: 9), D.stroke(const Color(0xFF4E5366), 1.5));
    }
    // snow on platform rim
    c.drawArc(Rect.fromCenter(center: _c + const Offset(0, 16), width: 140, height: 40), math.pi * 1.05, math.pi * .9,
        false, D.stroke(const Color(0xDDFFFFFF), 4));

    // chimney
    const chim = Rect.fromLTRB(166, 214, 194, 300);
    D.rrect(c, chim, 4, const Color(0xFF2F3342), border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < 3; i++) {
      final y = 230.0 + i * 22;
      D.rrect(c, Rect.fromLTWH(163, y, 34, 7), 3, Color.lerp(const Color(0xFF454A5E), core, .7)!,
          border: Pal.ink, borderWidth: 2);
    }
    D.rrect(c, const Rect.fromLTRB(158, 206, 202, 220), 4, const Color(0xFF454A5E), border: Pal.ink, borderWidth: 3);
    c.drawOval(Rect.fromCenter(center: const Offset(180, 207), width: 40, height: 8), D.fill(Pal.white));
    if (heatK > .35) {
      D.flame(c, const Offset(180, 208), 14 + heatK * 26 + _boost * 18, _t);
    }

    // main body (iron drum)
    const body = Rect.fromLTRB(132, 282, 228, 372);
    final bodyGrad = ui.Gradient.linear(body.centerLeft, body.centerRight, const [
      Color(0xFF232634),
      Color(0xFF4F566E),
      Color(0xFF2E3242),
      Color(0xFF1B1D28),
    ], const [0, .35, .7, 1]);
    c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(20)), Paint()..shader = bodyGrad);
    c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(20)), D.stroke(Pal.ink, 3.5));
    // bands + rivets
    for (final y in [298.0, 360.0]) {
      D.rrect(c, Rect.fromLTRB(130, y - 5, 230, y + 5), 4, const Color(0xFF3B4052), border: Pal.ink, borderWidth: 2);
      for (var i = 0; i < 6; i++) {
        c.drawCircle(Offset(140 + i * 16.0, y), 2, D.fill(const Color(0xFFB9C0D6)));
      }
    }
    // dome
    c.drawOval(Rect.fromCenter(center: const Offset(180, 284), width: 100, height: 26), D.fill(const Color(0xFF3B4052)));
    c.drawOval(Rect.fromCenter(center: const Offset(180, 284), width: 100, height: 26), D.stroke(Pal.ink, 3));
    c.drawArc(Rect.fromCenter(center: const Offset(180, 282), width: 96, height: 22), math.pi, math.pi, false,
        D.stroke(const Color(0xEEFFFFFF), 5));

    // glowing core window
    const mouth = Offset(180, 330);
    final glow = 18 + heatK * 16 + _boost * 12;
    c.drawCircle(
        mouth,
        glow + 20,
        Paint()
          ..shader = ui.Gradient.radial(mouth, glow + 20, [
            Color.fromRGBO(255, 200, 90, .7 * heatK + .1),
            const Color(0x00FF7A20),
          ]));
    c.drawCircle(mouth, 24, D.fill(const Color(0xFF15161E)));
    c.drawCircle(
        mouth,
        21,
        Paint()
          ..shader = ui.Gradient.radial(mouth + const Offset(0, 6), 24, [
            Color.lerp(const Color(0xFF4A5070), const Color(0xFFFFF2B0), heatK)!,
            core,
            Color.lerp(const Color(0xFF20222E), const Color(0xFFD83A1A), heatK)!,
          ], [0, .5, 1]));
    if (heatK > .08) {
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCircle(center: mouth, radius: 21)));
      D.flame(c, mouth + const Offset(0, 20), 18 + heatK * 22 + _boost * 10, _t);
      c.restore();
    }
    // grate bars
    for (var i = -2; i <= 2; i++) {
      final x = mouth.dx + i * 8.0;
      final hh = math.sqrt(math.max(0, 21 * 21 - (i * 8.0) * (i * 8.0)));
      D.line(c, Offset(x, mouth.dy - hh), Offset(x, mouth.dy + hh), const Color(0xFF2A2C38), 3);
    }
    c.drawCircle(mouth, 24, D.stroke(Pal.ink, 3.5));
    c.drawCircle(mouth, 24, D.stroke(Color.lerp(const Color(0xFF6A7090), Pal.yellow, heatK)!, 1.5));
    // side pipes
    for (final s in [-1.0, 1.0]) {
      final x = 180 + s * 50;
      D.rrect(c, Rect.fromCenter(center: Offset(x, 322), width: 14, height: 44), 5,
          Color.lerp(const Color(0xFF454A5E), core, .45)!,
          border: Pal.ink, borderWidth: 2.5);
    }
    // gauge needle on the body
    const g = Offset(180, 367);
    c.restore();
    // heat readout tag on the furnace
    D.rrect(c, Rect.fromCenter(center: g + const Offset(0, 22), width: 58, height: 20), 8, const Color(0xEE1B1530),
        border: Color.lerp(const Color(0xFF6ECBFF), Pal.orange, heatK)!, borderWidth: 2);
    D.text(c, '${_heatShown.round()}%', g + const Offset(0, 22), size: 13,
        color: Color.lerp(const Color(0xFF9FE6FF), Pal.yellow, heatK)!);
  }

  void _drawPiles(Canvas c) {
    // wood pile (left)
    const wp = Offset(128, 404);
    D.shadow(c, wp + const Offset(0, 8), 58, 14, .22);
    final wn = math.min(_wood, 9);
    for (var i = 0; i < wn; i++) {
      final row = i < 4 ? 0 : (i < 7 ? 1 : 2);
      final idx = i < 4 ? i : (i < 7 ? i - 4 : i - 7);
      final count = row == 0 ? 4 : (row == 1 ? 3 : 2);
      final x = wp.dx + (idx - (count - 1) / 2) * 11;
      final y = wp.dy - row * 8;
      c.save();
      c.translate(x, y);
      c.rotate(math.pi / 2);
      _logEnd(c);
      c.restore();
    }
    if (_wood > 9) {
      D.text(c, '+${_wood - 9}', wp + const Offset(0, -34), size: 12, color: Pal.orange, stroke: Pal.ink);
    }
    // coal pile (right)
    const cp = Offset(232, 404);
    D.shadow(c, cp + const Offset(0, 8), 52, 14, .22);
    final cn = math.min(_coal, 10);
    for (var i = 0; i < cn; i++) {
      final row = i < 4 ? 0 : (i < 7 ? 1 : (i < 9 ? 2 : 3));
      final idx = i < 4 ? i : (i < 7 ? i - 4 : (i < 9 ? i - 7 : 0));
      final count = [4, 3, 2, 1][row];
      _coalLump(c, cp + Offset((idx - (count - 1) / 2) * 11, -row * 8.0), 7);
    }
    if (_coal > 10) {
      D.text(c, '+${_coal - 10}', cp + const Offset(0, -38), size: 12, color: const Color(0xFFDADDF0), stroke: Pal.ink);
    }
    if (_wood + _coal == 0) {
      final a = .5 + .5 * math.sin(_t * 8);
      D.text(c, '0', const Offset(180, 412), size: 18, color: Color.fromRGBO(255, 120, 120, a), stroke: Pal.ink);
    }
  }

  void _logEnd(Canvas c) {
    // a log seen from the side, drawn along x
    D.rrect(c, const Rect.fromLTWH(-6, -5, 12, 10), 4, const Color(0xFF8A5530), border: Pal.ink, borderWidth: 1.5);
    c.drawCircle(const Offset(0, 0), 4.5, D.fill(const Color(0xFFE2B47A)));
    c.drawCircle(const Offset(0, 0), 4.5, D.stroke(Pal.ink, 1.3));
    c.drawCircle(const Offset(0, 0), 2, D.stroke(const Color(0xFFB07A48), 1));
  }

  void _log(Canvas c, Offset o, double len) {
    final r = Rect.fromCenter(center: o, width: len, height: len * .38);
    D.rrect(c, r, len * .18, const Color(0xFF8A5530), border: Pal.ink, borderWidth: 2);
    c.drawOval(Rect.fromCenter(center: Offset(r.right - len * .08, o.dy), width: len * .2, height: len * .34),
        D.fill(const Color(0xFFE2B47A)));
    D.line(c, Offset(r.left + len * .15, o.dy - 1), Offset(r.right - len * .3, o.dy - 1), const Color(0xFF5E3A20), 1.4);
  }

  void _coalLump(Canvas c, Offset o, double r) {
    final path = Path()
      ..moveTo(o.dx - r, o.dy + r * .4)
      ..lineTo(o.dx - r * .7, o.dy - r * .6)
      ..lineTo(o.dx + r * .1, o.dy - r)
      ..lineTo(o.dx + r, o.dy - r * .3)
      ..lineTo(o.dx + r * .8, o.dy + r * .7)
      ..lineTo(o.dx - r * .2, o.dy + r * .9)
      ..close();
    c.drawPath(path, D.fill(const Color(0xFF26262E)));
    c.drawPath(path, D.stroke(Pal.ink, 1.5));
    c.drawLine(o + Offset(-r * .4, -r * .4), o + Offset(r * .2, -r * .6), D.stroke(const Color(0xFF8C8FA8), 1.5));
  }

  void _drawHouse(Canvas c, Offset o, double heatK, bool front) {
    final lit = _heat >= _freezeLine;
    final bzShake = _bzAmount * math.sin(_t * 40 + o.dx) * 1.2;
    c.save();
    c.translate(o.dx + bzShake, o.dy);
    D.shadow(c, const Offset(0, 4), 60, 16, .25);
    // walls
    D.rrect(c, const Rect.fromLTWH(-24, -26, 48, 30), 3, const Color(0xFF8B5A3C), border: Pal.ink, borderWidth: 2.5);
    for (var i = 0; i < 3; i++) {
      D.line(c, Offset(-22, -18 + i * 8.0), Offset(22, -18 + i * 8.0), const Color(0xFF6A4128), 1.5);
    }
    // door
    D.rrect(c, const Rect.fromLTWH(4, -15, 12, 19), 3, const Color(0xFF4A2C1A), border: Pal.ink, borderWidth: 2);
    // window
    final win = lit ? Color.lerp(const Color(0xFFFFC96A), const Color(0xFFFFF2B0), M.wave(_t + o.dx, .6) * .5)! : const Color(0xFF2B3B63);
    if (lit) {
      c.drawCircle(const Offset(-10, -12), 16, Paint()..color = Color.fromRGBO(255, 200, 100, .28 * heatK));
    }
    D.rrect(c, const Rect.fromLTWH(-18, -18, 14, 12), 2, win, border: Pal.ink, borderWidth: 2);
    D.line(c, const Offset(-11, -18), const Offset(-11, -6), Pal.ink, 1.5);
    if (!lit) {
      D.line(c, const Offset(-17, -8), const Offset(-12, -17), const Color(0xAAFFFFFF), 1.5);
    }
    // snowy roof
    final roof = Path()
      ..moveTo(-30, -24)
      ..lineTo(0, -48)
      ..lineTo(30, -24)
      ..close();
    c.drawPath(roof, D.fill(const Color(0xFF5B3A2C)));
    final snow = Path()
      ..moveTo(-32, -22)
      ..quadraticBezierTo(-20, -30, 0, -50)
      ..quadraticBezierTo(20, -30, 32, -22)
      ..quadraticBezierTo(24, -17, 18, -22)
      ..quadraticBezierTo(8, -16, 0, -22)
      ..quadraticBezierTo(-10, -16, -18, -22)
      ..quadraticBezierTo(-26, -16, -32, -22)
      ..close();
    c.drawPath(snow, D.fill(const Color(0xFFF4FAFF)));
    c.drawPath(snow, D.stroke(Pal.ink, 2.5));
    // chimney
    D.rrect(c, const Rect.fromLTWH(12, -50, 8, 14), 1, const Color(0xFF6E6E80), border: Pal.ink, borderWidth: 2);
    // icicles
    for (var i = 0; i < 5; i++) {
      final x = -22 + i * 11.0;
      final len = 4 + (i * 7 % 5) + (1 - heatK) * 6;
      c.drawPath(
          Path()
            ..moveTo(x - 2, -21)
            ..lineTo(x + 2, -21)
            ..lineTo(x, -21 + len)
            ..close(),
          D.fill(const Color(0xDDCFF4FF)));
    }
    c.restore();
  }

  void _drawNode(Canvas c, _Node n) {
    final w = math.sin(_t * 40) * n.wobble * 3;
    final pulse = n.tapPulse;
    c.save();
    c.translate(n.pos.dx + w, n.pos.dy);
    c.scale(1 + pulse * .12);
    D.shadow(c, const Offset(0, 16), 84, 22, .22);
    if (n.coal) {
      // coal pile with a pickaxe
      final heap = Path()
        ..moveTo(-38, 16)
        ..quadraticBezierTo(-30, -18, 0, -24)
        ..quadraticBezierTo(30, -18, 38, 16)
        ..close();
      c.drawPath(heap, D.fill(const Color(0xFF2B2B35)));
      c.drawPath(heap, D.stroke(Pal.ink, 3));
      for (var i = 0; i < 7; i++) {
        _coalLump(c, Offset(-24 + (i * 8.0) + (i.isEven ? 0 : 3), 4 - (i % 3) * 8.0), 6);
      }
      final cap = Path()
        ..moveTo(-20, -14)
        ..quadraticBezierTo(0, -30, 20, -14)
        ..quadraticBezierTo(8, -10, 0, -14)
        ..quadraticBezierTo(-10, -9, -20, -14)
        ..close();
      c.drawPath(cap, D.fill(Pal.white));
      // pickaxe
      D.line(c, const Offset(22, -30), const Offset(34, 10), const Color(0xFF8A5530), 4);
      c.drawArc(Rect.fromCenter(center: const Offset(24, -26), width: 28, height: 14), math.pi * 1.05, math.pi * .9,
          false, D.stroke(const Color(0xFFB9C0D6), 4));
      // sparkle
      final sp = M.wave(_t + n.pos.dy, .8);
      D.star(c, const Offset(-12, -8), 3 + sp * 3, const Color(0xFFE8ECFF));
    } else {
      // snowy pines
      for (final (dx, dy, s) in const [(-22.0, 4.0, .8), (20.0, 6.0, .85), (0.0, -2.0, 1.0)]) {
        _pine(c, Offset(dx, dy + 14), 48 * s);
      }
      // stump + axe
      D.rrect(c, const Rect.fromLTWH(-10, 12, 20, 10), 3, const Color(0xFF8A5530), border: Pal.ink, borderWidth: 2);
      c.drawOval(Rect.fromCenter(center: const Offset(0, 12), width: 20, height: 7), D.fill(const Color(0xFFE2B47A)));
    }
    c.restore();
    // badge: queued orders
    final active = _workers.where((wk) => wk.node == _nodes.indexOf(n) && wk.state != _WState.idle).length;
    final q = n.pending + active;
    if (q > 0) {
      final b = n.pos + const Offset(30, -34);
      D.circle(c, b, 11, Pal.orange, border: Pal.ink, borderWidth: 2.5);
      D.text(c, '$q', b, size: 13, color: Pal.white);
    }
  }

  void _pine(Canvas c, Offset base, double h) {
    D.rrect(c, Rect.fromCenter(center: base + Offset(0, -h * .08), width: h * .14, height: h * .2), 2,
        const Color(0xFF6A4128));
    for (var i = 0; i < 3; i++) {
      final y = base.dy - h * (.15 + i * .25);
      final w = h * (.5 - i * .12);
      final tri = Path()
        ..moveTo(base.dx - w, y)
        ..lineTo(base.dx, y - h * .4)
        ..lineTo(base.dx + w, y)
        ..close();
      c.drawPath(tri, D.fill(Color.lerp(const Color(0xFF1F6B4E), const Color(0xFF2F8A62), i / 2)!));
      c.drawPath(tri, D.stroke(Pal.ink, 2));
      final snow = Path()
        ..moveTo(base.dx - w * .55, y - h * .18)
        ..lineTo(base.dx, y - h * .4)
        ..lineTo(base.dx + w * .55, y - h * .18)
        ..quadraticBezierTo(base.dx, y - h * .12, base.dx - w * .55, y - h * .18)
        ..close();
      c.drawPath(snow, D.fill(const Color(0xF0FFFFFF)));
    }
  }

  void _drawCitizen(Canvas c, _Citizen p, double heatK) {
    final shiver = !p.frozen && _heat < 50 ? math.sin(_t * 50 + p.ph) * (50 - _heat) / 50 * 1.8 : 0.0;
    final bob = p.cheer > 0 ? -((_t * 6 + p.ph) % math.pi).abs() * 3 * p.cheer : 0.0;
    final pos = p.pos + Offset(shiver, bob);
    if (p.freezeAnim > .5) {
      // ice statue
      final k = p.freezeAnim;
      D.shadow(c, pos + const Offset(0, 2), 22, 7, .25);
      D.person(c, pos, 26, const Color(0xFF9FD8F0),
          skin: const Color(0xFFCDEFFF), pants: const Color(0xFF7FB8D8), face: Face.shocked, hair: const Color(0xFFBDE6FA));
      final r = Rect.fromLTWH(pos.dx - 11, pos.dy - 30 * k, 22, 31 * k);
      D.rrect(c, r, 4, const Color(0x88D8F6FF), border: const Color(0xFFFFFFFF), borderWidth: 1.5);
      D.line(c, r.topLeft + const Offset(4, 4), r.topLeft + const Offset(4, 14), const Color(0xCCFFFFFF), 2);
      return;
    }
    final cold = !p.frozen && _heat < _freezeLine;
    final f = p.cheer > .3
        ? Face.happy
        : (cold ? Face.cry : (_heat < 50 ? Face.sad : (_boost > .4 ? Face.love : Face.happy)));
    D.shadow(c, pos + const Offset(0, 2), 20, 6, .22);
    final skin = Color.lerp(Pal.skin, const Color(0xFFA9D4F0), (1 - heatK) * .7)!;
    D.person(c, pos, 26, p.coat, skin: skin, face: f, hair: p.hat, armsUp: p.cheer);
    // fur hat
    c.drawOval(Rect.fromCenter(center: pos + const Offset(0, -26), width: 12, height: 6), D.fill(p.hat));
    if (cold && (_t * 3 + p.ph) % 2 < .5) {
      c.drawCircle(pos + const Offset(8, -26), 2.5, D.fill(const Color(0xCCFFFFFF)));
    }
  }

  void _drawWorker(Canvas c, _Worker w) {
    final moving = w.state == _WState.going || w.state == _WState.back;
    D.shadow(c, w.pos + const Offset(0, 2), 22, 7, .25);
    if (w.state == _WState.gather) {
      // swinging tool
      final a = math.sin(w.timer * 5 * math.pi * 2) * 1.2;
      final hand = w.pos + const Offset(0, -18);
      final tip = hand + Offset(math.sin(a) * 18, -math.cos(a) * 18);
      D.line(c, hand, tip, const Color(0xFF8A5530), 3);
      D.circle(c, tip, 3.5, const Color(0xFFB9C0D6), border: Pal.ink, borderWidth: 1.2);
    }
    D.person(c, w.pos, 30, const Color(0xFFFF7A1F),
        run: w.run, running: moving, flip: w.flip, face: w.carry > 0 ? Face.smug : Face.happy,
        hair: const Color(0xFFFFD23F), pants: const Color(0xFF3A3F5A));
    // helmet
    c.drawArc(Rect.fromCenter(center: w.pos + const Offset(0, -26), width: 14, height: 12), math.pi, math.pi, true,
        D.fill(Pal.yellow));
    c.drawArc(Rect.fromCenter(center: w.pos + const Offset(0, -26), width: 14, height: 12), math.pi, math.pi, true,
        D.stroke(Pal.ink, 1.5));
    if (w.carry > 0) {
      final bob = math.sin(w.run) * 1.5;
      final top = w.pos + Offset(0, -40 + bob);
      if (w.carryCoal) {
        D.rrect(c, Rect.fromCenter(center: top, width: 18, height: 14), 6, const Color(0xFF8C7A5A),
            border: Pal.ink, borderWidth: 2);
        _coalLump(c, top + const Offset(-3, -7), 5);
        _coalLump(c, top + const Offset(4, -6), 4);
      } else {
        for (var i = 0; i < 3; i++) {
          _log(c, top + Offset(0, -i * 5.0), 22);
        }
      }
    }
  }
}

enum _WState { idle, going, gather, back }

class _Worker {
  _Worker(this.home) : pos = home;
  final Offset home;
  Offset pos;
  _WState state = _WState.idle;
  int node = -1;
  double timer = 0;
  int lastSwing = -1;
  int carry = 0;
  bool carryCoal = false;
  double run = 0;
  bool flip = false;
}

class _Node {
  _Node(this.pos, this.coal);
  final Offset pos;
  final bool coal;
  int pending = 0;
  double wobble = 0;
  double tapPulse = 0;
}

class _Citizen {
  _Citizen(this.pos, this.coat, this.ph, this.hat);
  final Offset pos;
  final Color coat;
  final double ph;
  final Color hat;
  bool frozen = false;
  double freezeAnim = 0;
  double cheer = 0;
}

class _Flying {
  _Flying(this.from, this.coal);
  final Offset from;
  final bool coal;
  double t = 0;
}

class _Flake {
  _Flake(this.x, this.y, this.z, this.ph);
  double x, y;
  final double z, ph;
}

class _Drift {
  _Drift(this.pos, this.w, this.h);
  final Offset pos;
  final double w, h;
}
