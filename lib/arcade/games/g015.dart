import '../engine/engine.dart';

/// No.015 Screw Jam — tap uncovered screws to unscrew them. Each lands in the
/// matching color box (3 per box) or in the 5-slot tray. Plates drop when all
/// their screws are out. Tray overflow = game over.
class G015 extends MiniGame {
  static const _screwCols = [Color(0xFFFF3B5C), Color(0xFF3D8BFF), Color(0xFFFFC61A), Color(0xFF2ECC71)];
  static const _plateCols = [
    Color(0xFFB9A4FF), Color(0xFF8FE3C8), Color(0xFFFFB38A), Color(0xFF8CCBFF), Color(0xFFFFE27A), Color(0xFFFF9EC7),
  ];
  static const _plateW = 44.0;
  static const _sr = 14.0; // screw radius
  static const _traySlots = 5;
  static const _boxY = 82.0;
  static const _trayY = 150.0;

  final List<_Plate> _plates = [];
  final List<_Screw> _screws = [];
  final List<_Box?> _boxes = [null, null, null];
  final List<int> _queue = [];
  final List<_Screw> _tray = [];
  double _t = 0;
  double _trayShake = 0;
  int _combo = 0;
  double _comboT = 0;
  bool _done = false;
  double _winT = -1;

  static double _boxX(int i) => 66 + i * 114.0;
  static Offset _slotPos(int i) => Offset(60 + i * 60.0, _trayY);

  @override
  void init() {
    List<int>? boxes;
    for (var attempt = 0; attempt < 80; attempt++) {
      boxes = _generate();
      if (boxes != null && _simulate(boxes)) break;
    }
    boxes ??= _generate() ?? [0, 1, 2];
    for (var i = 0; i < 3 && i < boxes.length; i++) {
      _boxes[i] = _Box(boxes[i])..slide = 1 + i * .25;
    }
    _queue.addAll(boxes.skip(3));
  }

  /// Builds plates/screws. Returns the box color order (null when layout failed).
  List<int>? _generate() {
    _plates.clear();
    _screws.clear();
    const nPlates = 6;
    final positions = <Offset>[];
    for (var p = 0; p < nPlates; p++) {
      _Plate? made;
      for (var tries = 0; tries < 60 && made == null; tries++) {
        final len = rand(130, 220);
        final ang = pick(const [0.0, .35, -.35, pi / 2, .8, -.8, 1.2, -1.2]);
        final c = Offset(rand(80, 280), rand(250, 560));
        final pl = _Plate(c, ang, len, _plateCols[p % _plateCols.length], p);
        final n = len > 185 ? 3 : 2;
        final offs = n == 3 ? [-(len / 2 - 22), 0.0, len / 2 - 22] : [-(len / 2 - 22), len / 2 - 22];
        var ok = true;
        final pts = <Offset>[];
        for (final o in offs) {
          final sp = pl.worldOf(o);
          if (sp.dx < 34 || sp.dx > 326 || sp.dy < 222 || sp.dy > 606) ok = false;
          if (positions.any((q) => (q - sp).distance < 38)) ok = false;
          pts.add(sp);
        }
        if (!ok) continue;
        positions.addAll(pts);
        pl.screwOffsets.addAll(offs);
        made = pl;
      }
      if (made == null) return null;
      _plates.add(made);
    }
    final total = _plates.fold<int>(0, (a, p) => a + p.screwOffsets.length);
    final nBoxes = (total / 3).floor();
    // trim extra screws so total is a multiple of 3
    var extra = total - nBoxes * 3;
    for (final p in _plates) {
      if (extra > 0 && p.screwOffsets.length == 3) {
        p.screwOffsets.removeAt(1);
        extra--;
      }
    }
    if (extra > 0) return null;
    final boxes = [for (var i = 0; i < nBoxes; i++) i < 4 ? i : randInt(4)]..shuffle(rng);
    final colors = <int>[for (final b in boxes) ...[b, b, b]]..shuffle(rng);
    var k = 0;
    for (final p in _plates) {
      for (final o in p.screwOffsets) {
        _screws.add(_Screw(p, o, colors[k++]));
      }
      p.remaining = p.screwOffsets.length;
    }
    return boxes;
  }

  /// Greedy play-through to make sure the layout is solvable with the tray.
  bool _simulate(List<int> boxes) {
    final removed = <_Screw>{};
    final plateLeft = {for (final p in _plates) p: p.screwOffsets.length};
    final active = <List<int>>[for (var i = 0; i < 3 && i < boxes.length; i++) [boxes[i], 0]];
    var qi = min(3, boxes.length);
    final tray = <int>[];
    bool covered(_Screw s) {
      final pos = s.plate.worldOf(s.off);
      for (final p in _plates) {
        if (p.layer <= s.plate.layer || plateLeft[p]! <= 0) continue;
        if (p.covers(pos, _sr * .4)) return true;
      }
      return false;
    }

    void settle() {
      var changed = true;
      while (changed) {
        changed = false;
        for (var i = 0; i < active.length; i++) {
          if (active[i][1] >= 3) {
            active.removeAt(i);
            if (qi < boxes.length) active.add([boxes[qi++], 0]);
            changed = true;
            break;
          }
        }
        for (final b in active) {
          while (b[1] < 3 && tray.contains(b[0])) {
            tray.remove(b[0]);
            b[1]++;
            changed = true;
          }
        }
      }
    }

    while (removed.length < _screws.length) {
      final vis = _screws.where((s) => !removed.contains(s) && !covered(s)).toList();
      if (vis.isEmpty) return false;
      _Screw? choice;
      for (final s in vis) {
        if (active.any((b) => b[0] == s.color && b[1] < 3)) {
          choice = s;
          break;
        }
      }
      if (choice == null) {
        // prefer screws on nearly-free plates
        vis.sort((a, b) => plateLeft[a.plate]!.compareTo(plateLeft[b.plate]!));
        choice = vis.first;
        tray.add(choice.color);
        if (tray.length > _traySlots) return false;
      } else {
        active.firstWhere((b) => b[0] == choice!.color && b[1] < 3)[1]++;
      }
      removed.add(choice);
      plateLeft[choice.plate] = plateLeft[choice.plate]! - 1;
      settle();
    }
    return true;
  }

  bool _isCovered(_Screw s) {
    final pos = s.plate.worldOf(s.off);
    for (final p in _plates) {
      if (p.layer <= s.plate.layer || p.falling) continue;
      if (p.covers(pos, _sr * .4)) return true;
    }
    return false;
  }

  _Plate? _coverer(_Screw s) {
    final pos = s.plate.worldOf(s.off);
    _Plate? top;
    for (final p in _plates) {
      if (p.layer <= s.plate.layer || p.falling) continue;
      if (p.covers(pos, _sr * .4)) top = p;
    }
    return top;
  }

  Offset _targetPos(_Screw s) {
    if (s.box >= 0) {
      final b = _boxes[s.box];
      final bx = _boxX(s.box) + (b?.slide ?? 0) * 300;
      return Offset(bx - 26 + s.boxSlot * 26.0, _boxY + 8);
    }
    final i = _tray.indexOf(s);
    return _slotPos(max(0, i));
  }

  @override
  void update(double dt) {
    _t += dt;
    _trayShake = max(0, _trayShake - dt * 2.5);
    _comboT = max(0, _comboT - dt);
    if (_comboT <= 0) _combo = 0;

    for (final p in _plates) {
      if (p.falling) {
        p.vy += 1400 * dt;
        p.fallY += p.vy * dt;
        p.fallRot += p.spin * dt;
        continue;
      }
      p.wiggle = M.approach(p.wiggle, 0, 8, dt);
      // one screw left → the plate swings on it
      if (p.remaining == 1) {
        final pin = _screws.firstWhere((s) => s.plate == p && s.state == 0);
        p.pivot = pin.off;
        final tgt = p.hangTarget();
        p.swingV += ((tgt - p.swing) * 26 - p.swingV * 2.4) * dt;
        p.swing += p.swingV * dt;
      }
    }
    _plates.removeWhere((p) => p.falling && p.fallY > 800);

    for (final s in _screws) {
      switch (s.state) {
        case 1:
          s.t += dt / .2;
          s.spin += dt * 40;
          if (s.t >= 1) {
            s.state = 2;
            s.t = 0;
            s.from = s.pos;
          }
        case 2:
          s.t += dt / .32;
          final to = _targetPos(s);
          final k = M.easeInOut(M.clamp01(s.t));
          final mid = Offset((s.from.dx + to.dx) / 2, min(s.from.dy, to.dy) - 90);
          // quadratic bezier arc
          final a = Offset.lerp(s.from, mid, k)!, b = Offset.lerp(mid, to, k)!;
          s.pos = Offset.lerp(a, b, k)!;
          s.spin += dt * 20;
          if (s.t >= 1) _arrive(s);
        case 3:
          s.pos = M.approachO(s.pos, _targetPos(s), 16, dt);
        default:
          break;
      }
      s.pulse = M.approach(s.pulse, 0, 6, dt);
    }
    if (_overflowScrew != null) {
      final s = _overflowScrew!;
      s.vy += 1400 * dt;
      s.pos += Offset(s.vx * dt, s.vy * dt);
      s.spin += dt * 10;
    }

    for (var i = 0; i < 3; i++) {
      final b = _boxes[i];
      if (b == null) continue;
      b.slide = M.approach(b.slide, 0, 9, dt);
      b.bounce = M.approach(b.bounce, 0, 8, dt);
      if (b.slide < .02 && !b.arrived) {
        b.arrived = true;
        _pullFromTray(i);
      }
      if (b.closing >= 0) {
        b.closing += dt;
        if (b.closing > .55) {
          _boxes[i] = _queue.isNotEmpty ? (_Box(_queue.removeAt(0))..slide = 1) : null;
        }
      }
    }

    if (_winT >= 0) {
      _winT += dt;
    }
  }

  _Screw? _overflowScrew;

  void _pullFromTray(int bi) {
    final b = _boxes[bi]!;
    for (final s in List.of(_tray)) {
      if (b.reserved >= 3) break;
      if (s.color != b.color || s.state != 3) continue;
      _tray.remove(s);
      s.box = bi;
      s.boxSlot = b.reserved++;
      s.state = 2;
      s.t = 0;
      s.from = s.pos;
      host.sfx(Sfx.whoosh, volume: .5, rate: 1.3);
    }
  }

  void _arrive(_Screw s) {
    s.state = 3;
    s.pos = _targetPos(s);
    if (s.box >= 0) {
      final b = _boxes[s.box]!;
      b.count++;
      b.bounce = 1;
      host.sfx(Sfx.click, rate: 1 + b.count * .1);
      host.fx.sparkle(s.pos, count: 4, radius: 10, color: _screwCols[s.color]);
      if (b.count >= 3) {
        b.closing = 0;
        host.sfx(Sfx.correct);
        host.sfx(Sfx.coin, volume: .7, rate: 1.2);
        final at = Offset(_boxX(s.box), _boxY);
        host.fx.burst(at, _screwCols[b.color], count: 16, speed: 240, shape: PartShape.star, gravity: 300);
        host.fx.pop(host.tr('nice', 'NICE!'), at + const Offset(0, 40), color: Pal.yellow, size: 22);
        host.addScore(30, at);
        for (final sc in _screws) {
          if (sc.box == s.box && sc.state == 3) sc.state = 4; // leaves with the box
        }
      }
    } else {
      host.sfx(Sfx.tick, rate: .9);
    }
  }

  void _tap(Offset p) {
    if (_done || host.finished) return;
    _Screw? best;
    var bd = 26.0;
    for (final s in _screws) {
      if (s.state != 0 || s.plate.falling) continue;
      final d = (s.plate.worldOf(s.off) - p).distance;
      // prefer visible screws when several overlap
      final dd = d + (_isCovered(s) ? 12 : 0);
      if (dd < bd) {
        bd = dd;
        best = s;
      }
    }
    if (best == null) return;
    final s = best;
    if (_isCovered(s)) {
      final cp = _coverer(s);
      cp?.wiggle = 1;
      s.pulse = 1;
      host.sfx(Sfx.wrong, volume: .6);
      host.fx.pop('X', s.plate.worldOf(s.off), color: Pal.red, size: 24, life: .4);
      return;
    }
    // find a box
    var bi = -1;
    for (var i = 0; i < 3; i++) {
      final b = _boxes[i];
      if (b != null && b.closing < 0 && b.color == s.color && b.reserved < 3) {
        bi = i;
        break;
      }
    }
    s.pos = s.plate.worldOf(s.off);
    s.state = 1;
    s.t = 0;
    host.sfx(Sfx.spin, volume: .6, rate: 1.4);
    if (bi >= 0) {
      s.box = bi;
      s.boxSlot = _boxes[bi]!.reserved++;
      _combo++;
      _comboT = 1.2;
      if (_combo >= 3) {
        host.fx.pop('${host.tr('combo', 'COMBO')} x$_combo', s.pos + const Offset(0, -40), color: Pal.pink, size: 20);
      }
      host.addScore(10 * max(1, _combo));
    } else if (_tray.length < _traySlots) {
      s.box = -1;
      _tray.add(s);
      _combo = 0;
      if (_tray.length >= _traySlots - 1) {
        host.sfx(Sfx.heartbeat, volume: .7);
        _trayShake = .6;
      }
    } else {
      // tray overflow → game over
      s.state = 5;
      _overflowScrew = s
        ..vx = rand(-120, 120)
        ..vy = -500;
      _done = true;
      _trayShake = 1.5;
      host.sfx(Sfx.buzzer);
      host.sfx(Sfx.jingleLose, volume: .8);
      host.shake(10);
      host.flash(Pal.red, .2);
      host.fx.pop(host.tr('full', 'FULL!'), const Offset(180, 200), color: Pal.red, size: 36);
      host.lose();
    }
    // plate bookkeeping
    final pl = s.plate;
    pl.remaining--;
    pl.wiggle = .6;
    host.fx.burst(s.pos, const Color(0xFFD9D9E6), count: 6, speed: 120, size: 4, shape: PartShape.square, gravity: 500);
    if (pl.remaining <= 0 && !pl.falling) {
      pl.falling = true;
      pl.vy = -120;
      pl.spin = rand(-3, 3);
      host.sfx(Sfx.whoosh, rate: .8);
      host.sfx(Sfx.thud, volume: .6, rate: 1.2);
      host.addScore(20, pl.worldOf(0));
      if (_plates.every((q) => q.falling)) {
        _done = true;
        _winT = 0;
        host.sfx(Sfx.fanfare);
        host.fx.confetti(count: 120);
        host.fx.pop(host.tr('clear', 'CLEAR!'), const Offset(180, 380), size: 48, life: 1.4);
        host.flash(Pal.white, .15);
        final tl = host.timeLeft;
        host.win(stars: tl > 7 ? 3 : (tl > 3 ? 2 : 1));
      }
    }
  }

  @override
  void onDown(Offset p) => _tap(p);

  @override
  void onKey(String key, bool down) {
    if (!down || key != 'action') return;
    // desktop bonus: unscrew the first visible screw that fits a box
    for (final s in _screws) {
      if (s.state == 0 && !s.plate.falling && !_isCovered(s) && _boxes.any((b) => b != null && b.color == s.color && b.reserved < 3)) {
        _tap(s.plate.worldOf(s.off));
        return;
      }
    }
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFFFFE6C7), Color(0xFFFFC7D9), Color(0xFFC9B8FF)]);
    // workbench board
    const board = Rect.fromLTWH(14, 200, 332, 424);
    D.rrect(c, board.shift(const Offset(0, 8)), 24, const Color(0x44000000));
    D.rrect(c, board, 24, const Color(0xFFE9C38F),
        border: const Color(0xFF7A4A24), borderWidth: 5,
        gradient: const LinearGradient(colors: [Color(0xFFF3D3A2), Color(0xFFD9A868)], begin: Alignment.topCenter, end: Alignment.bottomCenter));
    final grain = D.stroke(const Color(0x22A0662F), 2);
    for (var i = 0; i < 12; i++) {
      final y = 215 + i * 34.0;
      c.drawLine(Offset(26, y + sin(i * 1.3) * 6), Offset(334, y + cos(i * .7) * 6), grain);
    }
    // pegboard holes
    final hole = D.fill(const Color(0x33703A10));
    for (var y = 226.0; y < 610; y += 32) {
      for (var x = 36.0; x < 330; x += 32) {
        c.drawCircle(Offset(x, y), 3, hole);
      }
    }

    for (final p in _plates) {
      _drawPlate(c, p);
    }

    _renderBoxes(c);
    _renderTray(c);

    // screws flying / in boxes / tray on top
    for (final s in _screws) {
      if (s.state == 1 || s.state == 2 || s.state == 3) {
        final lift = s.state == 1 ? 1 + .35 * M.easeOut(s.t) : (s.state == 2 ? 1.25 - .25 * s.t : .82);
        _drawScrew(c, s.pos, s.color, s.spin, scale: lift, shadow: s.state != 3);
      }
    }
    if (_overflowScrew != null) {
      _drawScrew(c, _overflowScrew!.pos, _overflowScrew!.color, _overflowScrew!.spin, scale: 1);
    }

    if (host.time < 2.4 && !_done && _screws.every((s) => s.state == 0)) {
      final s = _screws.firstWhere((s) => !_isCovered(s) && _boxes.any((b) => b?.color == s.color),
          orElse: () => _screws.firstWhere((s) => !_isCovered(s), orElse: () => _screws.first));
      final p = s.plate.worldOf(s.off);
      c.drawCircle(p, 22 + M.wave(_t, 2) * 6, D.stroke(const Color(0xCCFFFFFF), 4));
      D.hand(c, p + const Offset(2, 6), _t);
    }
  }

  void _drawPlate(Canvas c, _Plate p) {
    final center = p.worldOf(0) + Offset(0, p.fallY);
    final ang = p.angle + p.swing + p.fallRot;
    final wig = p.wiggle > 0 ? sin(_t * 60) * 3 * p.wiggle : 0.0;
    c.save();
    c.translate(center.dx + wig, center.dy);
    c.rotate(ang);
    final r = Rect.fromCenter(center: Offset.zero, width: p.len, height: _plateW);
    D.rrect(c, r.shift(const Offset(3, 7)), _plateW / 2, const Color(0x40000000));
    D.rrect(c, r, _plateW / 2, p.color.withValues(alpha: .9), border: Color.lerp(p.color, Pal.ink, .55)!, borderWidth: 3.5);
    D.rrect(c, Rect.fromLTWH(r.left + 14, r.top + 5, r.width - 28, 8), 4, const Color(0x66FFFFFF));
    // holes for every screw position
    for (final o in p.screwOffsets) {
      c.drawCircle(Offset(o, 0), _sr + 2, D.fill(Color.lerp(p.color, Pal.ink, .45)!));
      c.drawCircle(Offset(o, 0), _sr - 3, D.fill(const Color(0xFF3A2A40)));
    }
    c.restore();
    // screws still in this plate
    for (final s in _screws) {
      if (s.plate != p || s.state != 0) continue;
      final sp = p.worldOf(s.off) + Offset(wig, p.fallY);
      final jig = s.pulse > 0 ? Offset(sin(_t * 70) * 3 * s.pulse, 0) : Offset.zero;
      _drawScrew(c, sp + jig, s.color, s.idle + p.angle, scale: 1);
    }
  }

  void _drawScrew(Canvas c, Offset o, int col, double rot, {double scale = 1, bool shadow = true}) {
    final r = _sr * scale;
    final base = _screwCols[col];
    if (shadow) c.drawCircle(o + Offset(2, 3 * scale), r, D.fill(const Color(0x55000000)));
    c.drawCircle(o, r, D.fill(Color.lerp(base, Pal.ink, .35)!));
    c.drawCircle(o + Offset(0, -1.5 * scale), r * .86, D.fill(base));
    c.drawCircle(o + Offset(-r * .3, -r * .38), r * .26, D.fill(const Color(0x88FFFFFF)));
    c.drawCircle(o, r, D.stroke(Pal.ink, 2.2));
    c.save();
    c.translate(o.dx, o.dy - 1.5 * scale);
    c.rotate(rot);
    final slot = D.stroke(Color.lerp(base, Pal.ink, .6)!, 3.2 * scale);
    c.drawLine(Offset(-r * .5, 0), Offset(r * .5, 0), slot);
    c.drawLine(Offset(0, -r * .5), Offset(0, r * .5), slot);
    c.restore();
  }

  void _renderBoxes(Canvas c) {
    for (var i = 0; i < 3; i++) {
      final b = _boxes[i];
      final x = _boxX(i);
      // empty slot outline
      D.rrect(c, Rect.fromCenter(center: Offset(x, _boxY), width: 100, height: 58), 14, const Color(0x33FFFFFF),
          border: const Color(0x55FFFFFF), borderWidth: 2);
      if (b == null) continue;
      final leave = b.closing > .3 ? M.easeInOut(M.clamp01((b.closing - .3) / .25)) : 0.0;
      final bx = x + b.slide * 300;
      final by = _boxY - leave * 120;
      final sc = 1 + b.bounce * .08;
      final col = _screwCols[b.color];
      c.save();
      c.translate(bx, by);
      c.scale(sc, 2 - sc);
      final rr = Rect.fromCenter(center: Offset.zero, width: 100, height: 58);
      D.rrect(c, rr.shift(const Offset(0, 5)), 14, Color.lerp(col, Pal.ink, .5)!);
      D.rrect(c, rr, 14, Color.lerp(col, Pal.white, .25)!, border: Pal.ink, borderWidth: 3);
      D.rrect(c, Rect.fromLTWH(rr.left + 6, rr.top + 4, rr.width - 12, 10), 5, const Color(0x55FFFFFF));
      for (var j = 0; j < 3; j++) {
        c.drawCircle(Offset(-26 + j * 26.0, 8), 10, D.fill(Color.lerp(col, Pal.ink, .45)!));
      }
      c.restore();
      // screws inside this box
      for (final s in _screws) {
        if (s.box == i && (s.state == 3 || s.state == 4) && _boxes[i] == b) {
          _drawScrew(c, Offset(bx - 26 + s.boxSlot * 26.0, by + 8), s.color, 0, scale: .82, shadow: false);
        }
      }
      if (b.closing >= 0) {
        // lid slams shut
        final k = M.clamp01(b.closing / .18);
        final lid = Rect.fromCenter(center: Offset(bx, by - 29 + 29 * M.easeOutBack(k) - 29 * (1 - k)), width: 106, height: 22);
        D.rrect(c, lid.translate(0, 0), 10, Color.lerp(col, Pal.ink, .15)!, border: Pal.ink, borderWidth: 3);
        if (k >= 1) D.star(c, Offset(bx, by - 2), 13, Pal.yellow, border: Pal.ink);
      }
    }
    // queue indicator (upcoming boxes)
    for (var i = 0; i < min(4, _queue.length); i++) {
      final o = Offset(344 - i * 14.0, 124);
      D.rrect(c, Rect.fromCenter(center: o, width: 10, height: 10), 3, _screwCols[_queue[i]], border: Pal.ink, borderWidth: 1.5);
    }
  }

  void _renderTray(Canvas c) {
    final danger = _tray.length >= _traySlots - 1;
    final sh = _trayShake > 0 ? sin(_t * 50) * 4 * _trayShake : 0.0;
    final r = Rect.fromLTWH(26 + sh, _trayY - 24, 308, 48);
    D.rrect(c, r.shift(const Offset(0, 4)), 20, const Color(0x44000000));
    D.rrect(c, r, 20, danger ? Color.lerp(const Color(0xFF3A2F55), Pal.red, .35 + .25 * sin(_t * 12))! : const Color(0xFF3A2F55),
        border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < _traySlots; i++) {
      final o = _slotPos(i) + Offset(sh, 0);
      c.drawCircle(o, 16, D.fill(const Color(0xFF241C3A)));
      c.drawCircle(o, 16, D.stroke(const Color(0x55FFFFFF), 2));
    }
  }
}

class _Plate {
  _Plate(this.center, this.angle, this.len, this.color, this.layer);
  final Offset center;
  final double angle;
  final double len;
  final Color color;
  final int layer;
  final List<double> screwOffsets = [];
  int remaining = 0;
  bool falling = false;
  double vy = 0, fallY = 0, fallRot = 0, spin = 0;
  double wiggle = 0;
  double swing = 0, swingV = 0;
  double pivot = 0;

  /// World position of a point [o] along the plate's axis (includes swing).
  Offset worldOf(double o) {
    final pv = center + Offset(cos(angle), sin(angle)) * pivot;
    final a = angle + swing;
    return pv + Offset(cos(a), sin(a)) * (o - pivot);
  }

  bool covers(Offset p, double margin) {
    final c = worldOf(0);
    final a = angle + swing;
    final d = p - c;
    final lx = d.dx * cos(a) + d.dy * sin(a);
    final ly = -d.dx * sin(a) + d.dy * cos(a);
    return lx.abs() <= len / 2 + margin && ly.abs() <= G015._plateW / 2 + margin;
  }

  /// Swing target: rotate toward hanging down from the pivot (limited).
  double hangTarget() {
    final dirSign = pivot > 0 ? -1.0 : 1.0; // direction from pivot to center along the axis
    final phi = angle + (dirSign < 0 ? pi : 0);
    var want = pi / 2 - phi;
    while (want > pi) {
      want -= pi * 2;
    }
    while (want < -pi) {
      want += pi * 2;
    }
    return want.clamp(-.7, .7);
  }
}

class _Box {
  _Box(this.color);
  final int color;
  int count = 0;
  int reserved = 0;
  double slide = 0;
  double bounce = 0;
  double closing = -1;
  bool arrived = false;
}

class _Screw {
  _Screw(this.plate, this.off, this.color) : idle = (off * 7) % 3;
  final _Plate plate;
  final double off;
  final int color;
  final double idle;
  int state = 0; // 0 in plate, 1 unscrewing, 2 flying, 3 placed, 4 leaving with box, 5 dropped
  double t = 0;
  double spin = 0;
  Offset pos = Offset.zero;
  Offset from = Offset.zero;
  int box = -1;
  int boxSlot = 0;
  double pulse = 0;
  double vx = 0, vy = 0;
}
