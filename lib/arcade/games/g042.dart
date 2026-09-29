import '../engine/engine.dart';

/// No.042 Emergency Room — patients arrive with a symptom bubble; drag each
/// one to the matching department. Rooms treat one patient at a time; waiting
/// patients turn green and pass out. Cure 8 before 3 faint.
class G042 extends MiniGame {
  static const _goal = 8;
  static const _typeCol = [Color(0xFF3D6BFF), Color(0xFFFF8A1F), Color(0xFF14C9C9), Color(0xFFFF3B5C)];
  static const _shirts = [Pal.yellow, Pal.purple, Pal.lime, Pal.pink, Pal.sky, Pal.orange];
  static const double _treat = 1.5;

  final _rooms = <_Room>[];
  final _pats = <_Pat>[];
  final _seatTaken = List<_Pat?>.filled(5, null);
  double _t = 0;
  double _spawnT = .15;
  int _cured = 0;
  int _ko = 0;
  _Pat? _drag;
  Offset _dragOff = Offset.zero;
  double _bump = 0;
  double _koFlash = 0;
  int _spawned = 0;
  int _combo = 0;
  double _comboT = 0;

  Offset _seat(int i) => Offset(52 + i * 64.0, 560);

  @override
  void init() {
    for (var i = 0; i < 4; i++) {
      _rooms.add(_Room(i, Rect.fromLTWH(i.isEven ? 12 : 184, i < 2 ? 112 : 244, 164, 120)));
    }
    _rooms.shuffle(host.rng);
    for (var i = 0; i < 4; i++) {
      _rooms[i].rect = Rect.fromLTWH(i.isEven ? 12 : 184, i < 2 ? 112 : 244, 164, 120);
    }
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _bump = M.approach(_bump, 0, 7, dt);
    _koFlash = max(0, _koFlash - dt);
    _comboT -= dt;
    if (_comboT <= 0) _combo = 0;
    if (!host.finished) {
      _spawnT -= dt;
      final free = _seatTaken.indexWhere((s) => s == null);
      if (_spawnT <= 0 && free >= 0) {
        _spawnT = (_spawned < 2 ? .9 : rand(1.35, 1.9)) / host.speed;
        var type = randInt(4);
        // avoid 3 of the same in a row being unfair
        if (_pats.where((p) => p.state <= 3 && p.type == type).length >= 2) type = (type + 1 + randInt(3)) % 4;
        final p = _Pat(type, pick(_shirts), free, const Offset(-24, 612))..patience = 9.5 / host.speed;
        _seatTaken[free] = p;
        _pats.add(p);
        _spawned++;
        host.sfx(Sfx.notify, volume: .35);
      }
    }
    for (final r in _rooms) {
      r.flash = max(0, r.flash - dt * 2);
      r.shakeT = max(0, r.shakeT - dt);
      final pt = r.pat;
      if (pt != null) {
        r.prog += dt / _treat;
        if (r.prog >= 1) _cure(r);
      }
    }
    for (final p in _pats) {
      p.anim += dt;
      p.bounce = M.approach(p.bounce, 0, 6, dt);
      switch (p.state) {
        case 0: // walking in
          final to = _seat(p.seat);
          final d = to - p.pos;
          final step = 260 * dt;
          if (d.distance <= step) {
            p.pos = to;
            p.state = 1;
            p.bounce = 1;
          } else {
            p.pos += d / d.distance * step;
          }
          _sicken(p, dt * .5);
        case 1:
          _sicken(p, dt);
        case 2:
          _sicken(p, dt * .6);
        case 3:
          p.pos = M.approachO(p.pos, _seat(p.seat), 14, dt);
          if ((p.pos - _seat(p.seat)).distance < 2) p.state = 1;
          _sicken(p, dt);
        case 5: // cured, dancing out
          p.pos += Offset(p.pos.dy < 470 ? 0 : 150, p.pos.dy < 470 ? 200 : 0) * dt;
          if (p.pos.dx > 400) p.gone = true;
        case 6: // fainted
          p.koT += dt;
          if (p.koT > 1.6) p.gone = true;
      }
    }
    _pats.removeWhere((p) => p.gone);
  }

  void _sicken(_Pat p, double dt) {
    if (host.finished) return;
    p.sick += dt / p.patience;
    if (p.sick >= 1) {
      p.state = 6;
      p.koT = 0;
      if (_drag == p) _drag = null;
      _seatTaken[p.seat] = null;
      _ko++;
      _koFlash = 1;
      host.sfx(Sfx.thud);
      host.sfx(Sfx.heartbeat, volume: .6, rate: .8);
      host.shake(7);
      host.flash(Pal.lime, .15);
      host.fx.pop(host.tr('ko', 'K.O.'), p.pos + const Offset(0, -60), color: Pal.lime, size: 30);
      host.fx.smoke(p.pos + const Offset(0, -10), count: 8, color: const Color(0xAA9BE22D));
      if (_ko >= 3) {
        host.sfx(Sfx.jingleLose);
        host.lose();
      }
    }
  }

  void _cure(_Room r) {
    final p = r.pat!;
    r.pat = null;
    r.prog = 0;
    p.state = 5;
    p.pos = Offset(r.rect.center.dx, r.rect.bottom + 20);
    _cured++;
    _combo++;
    _comboT = 2.5;
    _bump = 1;
    final at = Offset(r.rect.center.dx, r.rect.bottom);
    host.addScore(100 + (1 - p.sick) * 100 ~/ 1, at + const Offset(0, -40));
    host.sfx(Sfx.correct, rate: 1 + min(_combo, 6) * .06);
    host.sfx(Sfx.cheer, volume: .4);
    host.fx.burst(at, Pal.white, count: 16, speed: 240, size: 7, shape: PartShape.star,
        colors: const [Pal.yellow, Pal.white, Pal.lime, Pal.pink]);
    host.fx.pop(_combo >= 3 ? 'COMBO x$_combo' : host.tr('cured', 'CURED!'), at + const Offset(0, -70),
        color: _combo >= 3 ? Pal.pink : Pal.lime, size: 24);
    if (_cured >= _goal) {
      host.sfx(Sfx.fanfare);
      host.fx.confetti(count: 90);
      host.flash(Pal.white, .15);
      host.win(stars: _ko == 0 ? 3 : (_ko == 1 ? 2 : 1));
    }
  }

  // ------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    _Pat? best;
    var bd = 44.0;
    for (final pt in _pats) {
      if (pt.state != 1 && pt.state != 3 && pt.state != 0) continue;
      final d = (pt.pos + const Offset(0, -28) - p).distance;
      if (d < bd) {
        bd = d;
        best = pt;
      }
    }
    if (best == null) return;
    _drag = best;
    best.state = 2;
    best.bounce = 1;
    _dragOff = best.pos - p;
    host.sfx(Sfx.pickup, volume: .6);
  }

  @override
  void onMove(Offset p) {
    final d = _drag;
    if (d == null) return;
    d.pos = p + _dragOff * .5 + const Offset(0, 30);
  }

  @override
  void onUp(Offset p) {
    final d = _drag;
    _drag = null;
    if (d == null || d.state != 2) return;
    _Room? room;
    for (final r in _rooms) {
      if (r.rect.inflate(8).contains(p)) room = r;
    }
    if (room == null) {
      d.state = 3;
      return;
    }
    if (room.type != d.type) {
      d.state = 3;
      d.sick = min(.97, d.sick + .12);
      room.shakeT = .4;
      room.flash = 1;
      room.flashCol = Pal.red;
      host.sfx(Sfx.wrong);
      host.fx.pop('?!', Offset(room.rect.center.dx, room.rect.top + 30), color: Pal.red, size: 30);
      host.shake(3);
      return;
    }
    if (room.pat != null) {
      d.state = 3;
      room.shakeT = .3;
      room.flash = 1;
      room.flashCol = Pal.orange;
      host.sfx(Sfx.buzzer, volume: .5);
      host.fx.pop(host.tr('busy', 'BUSY!'), Offset(room.rect.center.dx, room.rect.top + 30), color: Pal.orange, size: 22);
      return;
    }
    room.pat = d;
    room.prog = 0;
    room.flash = 1;
    room.flashCol = Pal.white;
    d.state = 4;
    _seatTaken[d.seat] = null;
    host.sfx(const [Sfx.scan, Sfx.pour, Sfx.zap, Sfx.zap][d.type], volume: .7, rate: d.type == 2 ? 1.6 : 1);
    host.sfx(Sfx.stamp, volume: .5);
    host.fx.ring(room.rect.center, _typeCol[d.type], size: 70);
    host.punch(.02);
  }

  @override
  void onTimeUp() {
    if (_cured >= _goal - 1) {
      host.win(stars: 1);
    } else {
      host.sfx(Sfx.jingleLose);
      host.lose();
    }
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    // hospital wall
    D.gradientBg(c, const [Color(0xFFDDF4F2), Color(0xFFBFE6E6)]);
    // lobby floor tiles
    const floor = Rect.fromLTWH(0, 372, 360, 268);
    Retro.tiles(c, floor, 30, const Color(0xFFEAF2F5), const Color(0xFFD6E4EA));
    c.drawRect(const Rect.fromLTWH(0, 368, 360, 6), D.fill(const Color(0xFF7FB8C0)));
    // green line guide on floor
    c.drawRect(const Rect.fromLTWH(0, 600, 360, 6), D.fill(const Color(0x5532C882)));
    // hud
    _hud(c);
    // rooms
    for (final r in _rooms) {
      _room(c, r);
    }
    // lobby props: entrance, exit, bench, plant
    D.rrect(c, const Rect.fromLTWH(-10, 566, 34, 70), 6, const Color(0xFF9FD8FF), border: Pal.ink, borderWidth: 3);
    D.rrect(c, const Rect.fromLTWH(336, 566, 34, 70), 6, const Color(0xFFB8F0B8), border: Pal.ink, borderWidth: 3);
    D.arrow(c, const Offset(330, 552), const Offset(1, 0), 30, Pal.green, width: 8);
    // reception desk
    D.rrect(c, const Rect.fromLTWH(118, 392, 124, 34), 10, const Color(0xFFFFFFFF), border: Pal.ink, borderWidth: 3);
    D.rrect(c, const Rect.fromLTWH(118, 392, 124, 10), 5, const Color(0xFF7FB8C0));
    _cross(c, const Offset(180, 414), 8, Pal.red);
    // plant
    D.rrect(c, const Rect.fromLTWH(24, 418, 26, 28), 5, const Color(0xFFC86A3A), border: Pal.ink, borderWidth: 2.5);
    D.circle(c, const Offset(37, 404), 18, Pal.green, border: Pal.ink, borderWidth: 2.5);
    D.circle(c, const Offset(28, 396), 9, const Color(0xFF5FE08F));
    // bench
    D.rrect(c, const Rect.fromLTWH(18, 520, 324, 18), 8, const Color(0xFF7A8AB8), border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < 5; i++) {
      final s = _seat(i);
      D.rrect(c, Rect.fromCenter(center: s + const Offset(0, -6), width: 54, height: 16), 6,
          _seatTaken[i] == null ? const Color(0xFFA8B8E8) : const Color(0xFF93A3D8),
          border: Pal.ink, borderWidth: 2.5);
    }
    // patients (non-dragged, non-room)
    for (final p in _pats) {
      if (p.state == 4 || p == _drag) continue;
      _patient(c, p);
    }
    // KO counter flash
    if (_koFlash > 0) {
      c.drawRect(const Rect.fromLTWH(0, 0, 360, 640),
          Paint()..color = Color.fromRGBO(155, 226, 45, _koFlash * .15));
    }
    // dragged on top with drop target highlight
    final d = _drag;
    if (d != null) {
      for (final r in _rooms) {
        if (r.type != d.type) continue;
        final pulse = .5 + .5 * sin(_t * 12);
        c.drawRRect(RRect.fromRectAndRadius(r.rect.inflate(4 + pulse * 3), const Radius.circular(16)),
            D.stroke(_typeCol[d.type].withValues(alpha: .6 + pulse * .4), 5));
      }
      _patient(c, d);
    }
    // tutorial
    if (!host.finished && _cured == 0 && _drag == null && host.time < 4.5) {
      final first = _pats.where((p) => p.state == 1).firstOrNull;
      if (first != null) {
        final room = _rooms.firstWhere((r) => r.type == first.type);
        final k = (_t * .7) % 1;
        final from = first.pos + const Offset(0, -30);
        final to = room.rect.center;
        final dir = to - from;
        D.arrow(c, Offset.lerp(from, to, .5)!, dir, dir.distance * .7, const Color(0xCCFFFFFF), width: 9);
        D.hand(c, Offset.lerp(from, to, M.easeInOut(k))!, _t);
      }
    }
  }

  void _hud(Canvas c) {
    D.rrect(c, const Rect.fromLTWH(10, 44, 340, 58), 16, const Color(0xFF1B3A4A), border: Pal.ink, borderWidth: 3);
    // cured counter
    final s = 1 + _bump * .3;
    c.save();
    c.translate(70, 73);
    c.scale(s);
    D.circle(c, Offset.zero, 20, Pal.white, border: Pal.ink, borderWidth: 3);
    _cross(c, Offset.zero, 11, Pal.red);
    c.restore();
    D.text(c, '$_cured/$_goal', const Offset(140, 73), size: 32, color: _cured >= _goal ? Pal.lime : Pal.white,
        stroke: Pal.ink, strokeWidth: 6);
    // ECG strip with strikes
    final ecg = Path();
    for (var x = 0.0; x <= 110; x += 2) {
      final ph = ((x + _t * 90) % 55) / 55;
      final y = ph > .4 && ph < .5 ? -14.0 * sin((ph - .4) / .1 * pi) : (ph > .5 && ph < .55 ? 8.0 : 0.0);
      x == 0 ? ecg.moveTo(212 + x, 73 + y) : ecg.lineTo(212 + x, 73 + y);
    }
    c.drawPath(ecg, D.stroke(_ko >= 2 ? Pal.red : Pal.lime, 2.5));
    for (var i = 0; i < 3; i++) {
      final p = Offset(234 + i * 36.0, 90);
      D.circle(c, p, 7, i < _ko ? Pal.red : const Color(0xFF2C5A6A), border: Pal.ink, borderWidth: 2);
      if (i < _ko) {
        D.line(c, p + const Offset(-3, -3), p + const Offset(3, 3), Pal.white, 2);
        D.line(c, p + const Offset(3, -3), p + const Offset(-3, 3), Pal.white, 2);
      }
    }
  }

  void _cross(Canvas c, Offset o, double s, Color col) {
    c.drawRect(Rect.fromCenter(center: o, width: s * 2, height: s * .7), D.fill(col));
    c.drawRect(Rect.fromCenter(center: o, width: s * .7, height: s * 2), D.fill(col));
  }

  void _room(Canvas c, _Room r) {
    final shx = r.shakeT > 0 ? sin(r.shakeT * 60) * 4 : 0.0;
    final rect = r.rect.shift(Offset(shx, 0));
    final col = _typeCol[r.type];
    c.drawRRect(RRect.fromRectAndRadius(rect.shift(const Offset(0, 5)), const Radius.circular(14)), D.fill(const Color(0x33000000)));
    D.rrect(c, rect, 14, Color.lerp(col, Pal.white, .78)!, border: Pal.ink, borderWidth: 3.5);
    // floor strip
    D.rrect(c, Rect.fromLTWH(rect.left + 4, rect.bottom - 34, rect.width - 8, 30), 10, Color.lerp(col, Pal.white, .55)!);
    // sign
    final sign = Rect.fromLTWH(rect.left + 8, rect.top + 8, 44, 40);
    D.rrect(c, sign, 10, col, border: Pal.ink, borderWidth: 3);
    _icon(c, r.type, sign.center, 15);
    D.text(c, _roomName(r.type), Offset(rect.left + 58, rect.top + 20), size: 13, color: Color.lerp(col, Pal.ink, .5)!,
        anchor: Alignment.centerLeft, maxWidth: 100);
    final busy = r.pat != null;
    final treating = busy ? r.pat! : null;
    // equipment
    final eq = Offset(rect.right - 40, rect.top + 64);
    switch (r.type) {
      case 0: // x-ray screen
        D.rrect(c, Rect.fromCenter(center: eq, width: 58, height: 64), 6, const Color(0xFF16213A), border: Pal.ink, borderWidth: 3);
        if (busy) {
          final g = (_t * 8).floor().isEven ? const Color(0xFF9BFFB0) : const Color(0xFFCFFFF0);
          D.circle(c, eq + const Offset(0, -18), 8, const Color(0x00000000), border: g, borderWidth: 2);
          D.line(c, eq + const Offset(0, -10), eq + const Offset(0, 12), g, 2.5);
          for (var k = 0; k < 3; k++) {
            D.line(c, eq + Offset(-9, -5 + k * 5.0), eq + Offset(9, -5 + k * 5.0), g, 1.5);
          }
          D.line(c, eq + const Offset(0, 12), eq + const Offset(-8, 26), g, 2);
          D.line(c, eq + const Offset(0, 12), eq + const Offset(8, 26), g, 2);
          D.line(c, eq + const Offset(0, -6), eq + const Offset(-14, 6), g, 2);
          D.line(c, eq + const Offset(0, -6), eq + const Offset(14, 2), g, 2);
        }
      case 1: // IV stand + bed
        D.line(c, eq + const Offset(14, -30), eq + const Offset(14, 34), const Color(0xFF8E8AA3), 3);
        D.rrect(c, Rect.fromCenter(center: eq + const Offset(14, -22), width: 16, height: 20), 5, const Color(0xCCBDEBFF),
            border: Pal.ink, borderWidth: 2);
        D.rrect(c, Rect.fromLTWH(rect.left + 50, rect.bottom - 46, 70, 16), 6, Pal.white, border: Pal.ink, borderWidth: 2.5);
      case 2: // dental lamp
        D.line(c, eq + const Offset(20, 34), eq + const Offset(20, -24), const Color(0xFF8E8AA3), 3);
        D.line(c, eq + const Offset(20, -24), eq + const Offset(-6, -24), const Color(0xFF8E8AA3), 3);
        D.circle(c, eq + const Offset(-8, -20), 9, busy && (_t * 10).floor().isEven ? Pal.yellow : const Color(0xFFFFF4B0),
            border: Pal.ink, borderWidth: 2);
      default: // cardio monitor
        D.rrect(c, Rect.fromCenter(center: eq, width: 58, height: 44), 6, const Color(0xFF102018), border: Pal.ink, borderWidth: 3);
        final path = Path();
        for (var x = 0.0; x <= 48; x += 2) {
          final ph = ((x + _t * (busy ? 160 : 60)) % 24) / 24;
          final y = ph > .4 && ph < .55 ? -12.0 * sin((ph - .4) / .15 * pi) : 0.0;
          x == 0 ? path.moveTo(eq.dx - 24 + x, eq.dy + 6 + y) : path.lineTo(eq.dx - 24 + x, eq.dy + 6 + y);
        }
        c.drawPath(path, D.stroke(Pal.lime, 2));
    }
    // doctor
    final docX = rect.left + 30;
    final docFeet = Offset(docX, rect.bottom - 8);
    final docFace = r.shakeT > 0 ? Face.angry : (busy ? Face.smug : Face.happy);
    D.person(c, docFeet, 72, Pal.white, pants: const Color(0xFF6FA8DC), face: docFace, hair: const Color(0xFF3A2A20),
        armsUp: busy ? (sin(_t * 14) * .5 + .5) * .4 : 0);
    D.circle(c, docFeet + const Offset(-1, -70), 5, const Color(0xFFDDE6F0), border: Pal.ink, borderWidth: 1.5);
    // patient being treated
    if (treating != null) {
      final jit = r.type == 2 || r.type == 3 ? Offset(sin(_t * 70) * 1.5, 0) : Offset.zero;
      final pf = Offset(rect.left + 86, rect.bottom - 10) + jit;
      D.person(c, pf, 66, treating.shirt, face: r.prog > .6 ? Face.happy : Face.shocked,
          skin: Color.lerp(Pal.skin, const Color(0xFF9BE22D), treating.sick * .7)!);
      if (r.type == 3 && (_t * 6).floor().isEven) {
        // zap!
        D.line(c, pf + const Offset(-14, -36), pf + const Offset(-4, -30), Pal.yellow, 3);
        D.line(c, pf + const Offset(-4, -30), pf + const Offset(-12, -22), Pal.yellow, 3);
      }
      if (r.type == 2) {
        D.line(c, pf + const Offset(12, -44), pf + const Offset(24, -60), const Color(0xFF8E8AA3), 3);
      }
      D.bar(c, Rect.fromLTWH(rect.left + 12, rect.top + 52, rect.width - 80, 12), r.prog, col, border: Pal.ink);
    } else {
      D.text(c, host.tr('free', 'FREE'), Offset(rect.left + 88, rect.bottom - 52), size: 12,
          color: Color.lerp(col, Pal.ink, .3)!.withValues(alpha: .7));
    }
    if (r.flash > 0) {
      c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)),
          Paint()..color = r.flashCol.withValues(alpha: r.flash * .45));
    }
  }

  String _roomName(int t) => switch (t) {
        0 => host.tr('xray', 'X-RAY'),
        1 => host.tr('clinic', 'CLINIC'),
        2 => host.tr('dental', 'DENTAL'),
        _ => host.tr('cardio', 'CARDIO'),
      };

  void _icon(Canvas c, int type, Offset o, double s) {
    switch (type) {
      case 0: // bone
        c.save();
        c.translate(o.dx, o.dy);
        c.rotate(-.6);
        final p = Paint()..color = Pal.white;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s * 1.5, height: s * .5), Radius.circular(s * .2)), p);
        for (final dx in [-1.0, 1.0]) {
          for (final dy in [-1.0, 1.0]) {
            c.drawCircle(Offset(dx * s * .75, dy * s * .25), s * .3, p);
          }
        }
        c.restore();
      case 1: // thermometer
        c.save();
        c.translate(o.dx, o.dy);
        c.rotate(.5);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -s * .2), width: s * .5, height: s * 1.5), Radius.circular(s * .25)),
            D.fill(Pal.white));
        c.drawCircle(Offset(0, s * .6), s * .38, D.fill(Pal.red));
        c.drawRect(Rect.fromLTWH(-s * .1, -s * .5, s * .2, s * 1.1), D.fill(Pal.red));
        c.restore();
      case 2: // tooth
        final p = Path()
          ..moveTo(o.dx - s * .8, o.dy - s * .4)
          ..quadraticBezierTo(o.dx - s * .8, o.dy - s * .95, o.dx - s * .3, o.dy - s * .85)
          ..quadraticBezierTo(o.dx, o.dy - s * .7, o.dx + s * .3, o.dy - s * .85)
          ..quadraticBezierTo(o.dx + s * .8, o.dy - s * .95, o.dx + s * .8, o.dy - s * .4)
          ..quadraticBezierTo(o.dx + s * .7, o.dy + s * .2, o.dx + s * .5, o.dy + s * .9)
          ..quadraticBezierTo(o.dx + s * .3, o.dy + s * .9, o.dx + s * .15, o.dy + s * .2)
          ..quadraticBezierTo(o.dx, o.dy + s * .05, o.dx - s * .15, o.dy + s * .2)
          ..quadraticBezierTo(o.dx - s * .3, o.dy + s * .9, o.dx - s * .5, o.dy + s * .9)
          ..quadraticBezierTo(o.dx - s * .7, o.dy + s * .2, o.dx - s * .8, o.dy - s * .4)
          ..close();
        c.drawPath(p, D.fill(Pal.white));
        c.drawPath(p, D.stroke(Pal.ink, 1.5));
      default:
        final beat = 1 + max(0.0, sin(_t * 9)) * .15;
        D.heart(c, o + Offset(0, s * .1), s * 1.6 * beat, Pal.red, border: Pal.white);
    }
  }

  void _patient(Canvas c, _Pat p) {
    final sick = p.sick.clamp(0.0, 1.0);
    final skin = Color.lerp(Pal.skin, const Color(0xFF8FD14F), sick)!;
    if (p.state == 6) {
      // fainted flat on the floor
      final k = (p.koT / .25).clamp(0.0, 1.0);
      c.save();
      c.translate(p.pos.dx, p.pos.dy);
      c.rotate(-pi / 2 * k);
      final fade = p.koT > 1.1 ? (1 - (p.koT - 1.1) / .5).clamp(0.0, 1.0) : 1.0;
      if (fade < 1) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, fade));
      D.person(c, Offset.zero, 58, p.shirt, skin: skin, face: Face.dead);
      if (fade < 1) c.restore();
      c.restore();
      for (var i = 0; i < 3; i++) {
        final a = _t * 5 + i * pi * 2 / 3;
        D.star(c, p.pos + Offset(-40 + cos(a) * 16, -14 + sin(a) * 6), 5, Pal.yellow);
      }
      return;
    }
    final dancing = p.state == 5;
    final dragged = p.state == 2;
    final lift = sin(p.bounce * pi) * 8 + (dancing ? (sin(p.anim * 14).abs() * 10) : 0);
    final wob = dragged ? sin(p.anim * 16) * .15 : (dancing ? sin(p.anim * 10) * .2 : 0.0);
    final feet = p.pos + Offset(0, -lift);
    if (!dragged) D.shadow(c, p.pos + const Offset(0, 2), 30, 8);
    c.save();
    c.translate(feet.dx, feet.dy);
    c.rotate(wob);
    c.scale(1.17);
    final face = dancing ? Face.happy : (dragged ? Face.shocked : (sick > .7 ? Face.cry : (sick > .4 ? Face.sad : Face.neutral)));
    D.person(c, Offset.zero, 58, p.shirt, skin: skin, face: face, running: p.state == 0 || dancing, run: p.anim * 12,
        hair: const Color(0xFF3A2A20), armsUp: dancing ? .9 : 0);
    // symptom props
    if (!dancing) {
      switch (p.type) {
        case 0:
          D.rrect(c, const Rect.fromLTWH(10, -40, 10, 20), 4, Pal.white, border: Pal.ink, borderWidth: 2);
        case 1:
          D.line(c, const Offset(2, -44), const Offset(14, -40), Pal.white, 2.5);
          D.circle(c, const Offset(15, -40), 2.5, Pal.red);
        case 2:
          c.drawOval(Rect.fromCenter(center: const Offset(9, -45), width: 12, height: 12), D.fill(skin));
          D.line(c, const Offset(0, -58), const Offset(0, -38), Pal.white, 3);
        default:
          D.circle(c, const Offset(-4, -32), 5, skin, border: Pal.ink, borderWidth: 2);
      }
    }
    c.restore();
    if (dancing) {
      if ((p.anim * 6).floor() % 3 == 0) D.heart(c, feet + Offset(sin(p.anim * 7) * 20, -76), 12, Pal.pink);
      return;
    }
    // symptom bubble + sickness bar
    final bc = feet + const Offset(0, -98);
    final col = _typeCol[p.type];
    final pulse = sick > .7 ? 1 + sin(_t * 18) * .08 : 1.0;
    c.save();
    c.translate(bc.dx, bc.dy);
    c.scale(pulse);
    D.bubble(c, Rect.fromCenter(center: Offset.zero, width: 38, height: 32), color: col, tail: const Offset(0, 22));
    _icon(c, p.type, Offset.zero, 12);
    c.restore();
    D.bar(c, Rect.fromCenter(center: feet + const Offset(0, -76), width: 40, height: 6), sick,
        sick > .7 ? Pal.red : Color.lerp(Pal.yellow, Pal.lime, sick)!, border: Pal.ink);
    if (sick > .55) {
      final dy = (p.anim * 30) % 14;
      c.drawOval(Rect.fromCenter(center: feet + Offset(-16, -58 + dy), width: 5, height: 8), D.fill(const Color(0xCC6ECBFF)));
    }
  }
}

class _Room {
  _Room(this.type, this.rect);
  final int type;
  Rect rect;
  _Pat? pat;
  double prog = 0;
  double flash = 0;
  Color flashCol = Pal.white;
  double shakeT = 0;
}

class _Pat {
  _Pat(this.type, this.shirt, this.seat, this.pos);
  final int type;
  final Color shirt;
  final int seat;
  Offset pos;
  int state = 0; // 0 walk in, 1 wait, 2 dragged, 3 return, 4 in room, 5 cured, 6 fainted
  double sick = 0;
  double patience = 9;
  double anim = 0;
  double bounce = 0;
  double koT = 0;
  bool gone = false;
}
