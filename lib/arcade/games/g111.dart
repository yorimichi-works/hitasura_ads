import 'dart:math' as math;
import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.111 Scratch & Win — drag to scratch 6 silver panels; find 3 crowns.
///
/// The silver foil is a real erasable mask (clear-blended brush strokes) and
/// a coverage grid decides when a panel pops open. Symbols are rigged at the
/// moment you start scratching a panel so the 3rd crown always shows up by
/// the 4th or 5th panel — with a heartbeat "REACH" after the 2nd.

enum _Sym { crown, cherry, bell, diamond, clover, horseshoe, lemon }

class _Panel {
  _Panel(this.r);
  final Rect r;
  static const cols = 17, rows = 13;
  final cells = List<bool>.filled(cols * rows, false);
  int scratched = 0;
  _Sym? sym;
  bool revealed = false;
  double revealT = 0;
  final path = Path();
  double shake = 0;
  double get cover => scratched / (cols * rows);
}

class G111 extends MiniGame {
  static const _brush = 21.0;
  final _panels = <_Panel>[];
  late final List<bool> _plan; // true = crown, by order of first touch
  final _others = <_Sym>[];
  int _touched = 0;
  int _crowns = 0;
  double _t = 0;
  Offset? _last;
  bool _down = false;
  double _scrubCd = 0;
  double _dustCd = 0;
  bool _reach = false;
  double _beat = 0;
  double _winT = -1;
  double _prize = 0;
  double _lastScratch = 0;
  final _dots = <List<double>>[];

  @override
  Color get backdrop => const Color(0xFFFF9A3C);

  @override
  void init() {
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 2; col++) {
        _panels.add(_Panel(Rect.fromLTWH(36 + col * 152.0, 222 + row * 116.0, 136, 104)));
      }
    }
    _plan = pick(const [
      [true, false, true, false, true, false],
      [false, true, true, false, true, false],
      [true, true, false, true, false, false],
      [false, true, false, true, true, false],
      [true, false, false, true, true, false],
    ]);
    final pool = List<_Sym>.from(_Sym.values)..remove(_Sym.crown);
    pool.shuffle(rng);
    _others.addAll(pool.take(3));
    for (var i = 0; i < 40; i++) {
      _dots.add([rand(0, 360), rand(0, 640), rand(3, 7), rand(0, 360), rand(0, 6.28)]);
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _scrubCd -= dt;
    _dustCd -= dt;
    _lastScratch += dt;
    for (final p in _panels) {
      p.shake = M.approach(p.shake, 0, 8, dt);
      if (p.revealed) p.revealT += dt;
    }
    if (_reach && _winT < 0) {
      _beat += dt;
      if (_beat > .75) {
        _beat = 0;
        host.sfx(Sfx.heartbeat, volume: .9);
      }
    }
    if (_winT >= 0) {
      _winT += dt;
      _prize = M.approach(_prize, 1000000, 3.5, dt);
      if (_winT < 1.2 && chance(.5)) host.sfx(Sfx.tick, volume: .3, rate: 1.4 + _winT);
      if (_winT > .9 && !host.finished) {
        host.win(stars: host.time < 7 ? 3 : (host.time < 10 ? 2 : 1));
      }
      if (chance(.35)) host.fx.coins(Offset(rand(40, 320), 660), count: 2, speed: 800);
    }
  }

  // ---------------------------------------------------------------- input --

  @override
  void onDown(Offset p) {
    _down = true;
    _last = p;
    _scratch(p, p);
  }

  @override
  void onMove(Offset p) {
    if (!_down) return;
    _scratch(_last ?? p, p);
    _last = p;
  }

  @override
  void onUp(Offset p) {
    _down = false;
    _last = null;
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    // keyboard: scratch a zig-zag across the next unrevealed panel
    for (final pn in _panels) {
      if (pn.revealed) continue;
      final r = pn.r;
      for (var i = 0; i < 4; i++) {
        final y = r.top + 12 + i * 27.0;
        _scratch(Offset(r.left + 4, y), Offset(r.right - 4, y + 10));
      }
      return;
    }
  }

  void _scratch(Offset a, Offset b) {
    if (_winT >= 0 || host.finished) return;
    final d = (b - a).distance;
    final steps = math.max(1, (d / 5).ceil());
    var any = false;
    for (final pn in _panels) {
      if (pn.revealed) continue;
      final hitRect = pn.r.inflate(_brush);
      if (!hitRect.contains(a) && !hitRect.contains(b) && M.distToSegment(pn.r.center, a, b) > 90) continue;
      var changed = 0;
      for (var s = 0; s <= steps; s++) {
        final p = Offset.lerp(a, b, s / steps)!;
        if (!hitRect.contains(p)) continue;
        changed += _stamp(pn, p);
      }
      if (changed > 0 || hitRect.contains(b)) {
        if (d < 1) {
          pn.path.addOval(Rect.fromCircle(center: b, radius: _brush * .5));
        } else {
          pn.path
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy);
        }
      }
      if (changed > 0) {
        any = true;
        if (pn.sym == null) _assign(pn);
        pn.shake = math.min(1, pn.shake + .15);
        if (pn.cover > .5) _reveal(pn);
      }
    }
    if (any) {
      _lastScratch = 0;
      if (_scrubCd <= 0) {
        _scrubCd = .09;
        host.sfx(Sfx.scrub, volume: .45, rate: .9 + rng.nextDouble() * .3);
      }
      if (_dustCd <= 0) {
        _dustCd = .03;
        for (var i = 0; i < 3; i++) {
          host.fx.add(Particle(
            pos: b + Offset(rand(-12, 12), rand(-6, 6)),
            vel: Offset(rand(-90, 90), rand(-120, 0)),
            life: rand(.4, .8),
            color: pick(const [Color(0xFFD9DDE8), Color(0xFFA8AEC0), Color(0xFFF4F6FF)]),
            size: rand(2.5, 5),
            shape: PartShape.square,
            gravity: 700,
            spin: rand(-10, 10),
          ));
        }
      }
    }
  }

  int _stamp(_Panel pn, Offset p) {
    const cs = 8.0;
    final r = pn.r;
    final x0 = ((p.dx - _brush - r.left) / cs).floor().clamp(0, _Panel.cols - 1);
    final x1 = ((p.dx + _brush - r.left) / cs).floor().clamp(0, _Panel.cols - 1);
    final y0 = ((p.dy - _brush - r.top) / cs).floor().clamp(0, _Panel.rows - 1);
    final y1 = ((p.dy + _brush - r.top) / cs).floor().clamp(0, _Panel.rows - 1);
    var n = 0;
    for (var iy = y0; iy <= y1; iy++) {
      for (var ix = x0; ix <= x1; ix++) {
        final idx = iy * _Panel.cols + ix;
        if (pn.cells[idx]) continue;
        final cx = r.left + (ix + .5) * cs, cy = r.top + (iy + .5) * cs;
        final dx = cx - p.dx, dy = cy - p.dy;
        if (dx * dx + dy * dy < _brush * _brush) {
          pn.cells[idx] = true;
          pn.scratched++;
          n++;
        }
      }
    }
    return n;
  }

  void _assign(_Panel pn) {
    final isCrown = _plan[_touched.clamp(0, 5)];
    var others = 0;
    for (final p in _panels) {
      if (p.sym != null && p.sym != _Sym.crown) others++;
    }
    pn.sym = isCrown ? _Sym.crown : _others[others % 3];
    _touched++;
  }

  void _reveal(_Panel pn) {
    pn.revealed = true;
    pn.revealT = 0;
    final c = pn.r.center;
    host.fx.ring(c, Pal.white, size: 70);
    if (pn.sym == _Sym.crown) {
      _crowns++;
      if (_crowns == 1) {
        host.sfx(Sfx.ding);
        host.sfx(Sfx.sparkle, volume: .6);
        host.fx.burst(c, Pal.gold, count: 18, speed: 260, shape: PartShape.star, gravity: 200);
        host.fx.pop('1 / 3', c + const Offset(0, -50), color: Pal.yellow, size: 26);
      } else if (_crowns == 2) {
        _reach = true;
        _beat = .5;
        host.sfx(Sfx.rarityUp);
        host.sfx(Sfx.drumroll, volume: .7);
        host.setMusicVolume(.3);
        host.shake(6);
        host.flash(const Color(0x66FF3B5C), .15);
        host.fx.burst(c, Pal.gold, count: 26, speed: 320, shape: PartShape.star, gravity: 200);
        host.fx.pop(host.tr('reach', 'REACH!'), const Offset(180, 190), color: Pal.red, size: 40, life: 1.3);
      } else {
        _win(c);
      }
    } else {
      host.sfx(Sfx.pop, rate: .9);
      host.sfx(Sfx.oops, volume: .35, rate: 1.3);
      host.fx.burst(c, const Color(0xFFD9DDE8), count: 10, speed: 160);
    }
  }

  void _win(Offset at) {
    _winT = 0;
    _reach = false;
    host.setMusicVolume(1);
    host.sfx(Sfx.ssr);
    host.sfx(Sfx.fanfare);
    host.sfx(Sfx.coins);
    host.flash(Pal.white, .3);
    host.shake(14, .5);
    host.hitStop(.1);
    host.punch(.07);
    host.fx.burst(at, Pal.gold, count: 50, speed: 480, shape: PartShape.star, gravity: 250);
    host.fx.confetti(count: 100);
    host.fx.coins(at, count: 30, speed: 650);
    host.fx.pop(host.tr('jackpot', 'JACKPOT!'), const Offset(180, 330), color: Pal.yellow, size: 44, life: 1.4);
    // flip everything else open
    for (final p in _panels) {
      if (!p.revealed) {
        if (p.sym == null) _assign(p);
        p.revealed = true;
        p.revealT = -.2;
      }
    }
  }

  // --------------------------------------------------------------- render --

  @override
  void render(Canvas c) {
    // sunburst background
    D.gradientBg(c, const [Color(0xFFFFD54A), Color(0xFFFF8A3C), Color(0xFFFF4F7B)]);
    D.rays(c, const Offset(180, 380), 800, const Color(0x33FFFFFF), count: 18, t: _t * .25);
    for (final d in _dots) {
      final y = (d[1] + _t * 20) % 660 - 10;
      c.save();
      c.translate(d[0], y);
      c.rotate(d[4] + _t);
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: d[2] * 1.6, height: d[2]), D.fill(D.hsv(d[3], .6, 1, .55)));
      c.restore();
    }
    _header(c);
    _ticket(c);
    for (var i = 0; i < _panels.length; i++) {
      _panel(c, _panels[i]);
    }
    if (_reach) {
      final k = .5 + .5 * math.sin(_t * 8.4);
      c.drawRect(GameHost.bounds, D.fill(Color.fromRGBO(255, 20, 60, .07 * k)));
    }
    // coin scraper follows the finger
    if (_down && host.pointerDown && _winT < 0) {
      final p = host.pointer;
      c.save();
      c.translate(p.dx + 8, p.dy + 8);
      c.rotate(-.5 + math.sin(_t * 30) * .1);
      c.scale(.55, 1);
      D.coin(c, Offset.zero, 22);
      c.restore();
    }
    _hint(c);
  }

  void _header(Canvas c) {
    // prize banner
    const r = Rect.fromLTWH(16, 46, 328, 92);
    D.rrect(c, r.shift(const Offset(0, 6)), 20, const Color(0x55000000));
    D.rrect(c, r, 20, const Color(0xFF3A0F5C), border: Pal.ink, borderWidth: 4,
        gradient: const LinearGradient(colors: [Color(0xFF5A1A8C), Color(0xFF2A0A4A)], begin: Alignment.topCenter, end: Alignment.bottomCenter));
    for (var i = 0; i < 18; i++) {
      final on = ((_t * 6).floor() + i) % 3 == 0;
      c.drawCircle(Offset(28 + i * 18.0, 52), 3, D.fill(on ? Pal.yellow : const Color(0x66FFD23F)));
      c.drawCircle(Offset(28 + i * 18.0, 132), 3, D.fill(!on ? Pal.yellow : const Color(0x66FFD23F)));
    }
    _crown(c, const Offset(46, 88), 22, 0);
    _crown(c, const Offset(314, 88), 22, 0);
    final v = _winT >= 0 ? _prize.round() : 1000000;
    final s = _fmt(v);
    final pulse = _winT >= 0 ? 1 + .06 * math.sin(_t * 20) : 1 + .03 * math.sin(_t * 4);
    c.save();
    c.translate(180, 84);
    c.scale(pulse);
    D.text(c, s, const Offset(0, 3), size: 38, color: const Color(0xFF7A3A00), stroke: const Color(0xFF7A3A00), strokeWidth: 9);
    D.text(c, s, Offset.zero, size: 38, color: Pal.yellow, stroke: Pal.ink, strokeWidth: 7);
    c.restore();
    D.text(c, host.tr('match_3', 'MATCH 3 = WIN'), const Offset(180, 118), size: 14, color: const Color(0xFFFFD6F0));
    // crown progress
    for (var i = 0; i < 3; i++) {
      final o = Offset(140 + i * 40.0, 158);
      final got = i < _crowns;
      c.drawCircle(o, 15, D.fill(got ? const Color(0xFFFFF1B0) : const Color(0x55FFFFFF)));
      c.drawCircle(o, 15, D.stroke(Pal.ink, 2.5));
      if (got) {
        _crown(c, o, 10, 0);
      } else {
        D.text(c, '?', o, size: 16, color: const Color(0x99FFFFFF));
      }
    }
  }

  static String _fmt(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  void _ticket(Canvas c) {
    const r = Rect.fromLTWH(20, 180, 320, 400);
    D.rrect(c, r.shift(const Offset(4, 8)), 16, const Color(0x55000000));
    final path = Path()..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(16)));
    // perforation notches
    final notches = Path();
    for (var i = 0; i < 9; i++) {
      notches.addOval(Rect.fromCircle(center: Offset(r.left, r.top + 30 + i * 43.0), radius: 7));
      notches.addOval(Rect.fromCircle(center: Offset(r.right, r.top + 30 + i * 43.0), radius: 7));
    }
    final ticket = Path.combine(ui.PathOperation.difference, path, notches);
    c.drawPath(ticket, Paint()
      ..shader = ui.Gradient.linear(r.topLeft, r.bottomRight, const [Color(0xFFFFFBEA), Color(0xFFFFF0C8), Color(0xFFFFE3F2)], const [0, .5, 1]));
    // guilloche pattern
    c.save();
    c.clipPath(ticket);
    final gp = D.stroke(const Color(0x22FF5FC8), 1.2);
    for (var i = 0; i < 12; i++) {
      c.drawCircle(const Offset(180, 380), 30.0 + i * 22, gp);
    }
    c.restore();
    c.drawPath(ticket, D.stroke(Pal.ink, 4));
    // ticket title strip
    D.rrect(c, const Rect.fromLTWH(36, 190, 288, 24), 10, const Color(0xFFFF3B8C), border: Pal.ink, borderWidth: 2.5);
    D.text(c, '★ ${host.tr('lucky', 'LUCKY')} ★', const Offset(180, 202), size: 15, color: Pal.white, stroke: Pal.ink, strokeWidth: 3.5);
    D.text(c, 'No.0000151', const Offset(318, 572), size: 10, color: const Color(0xFF9A5B7A), anchor: Alignment.centerRight);
  }

  void _panel(Canvas c, _Panel pn) {
    final r = pn.r;
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
    c.drawRRect(rr, D.fill(Pal.white));
    final crownWin = _winT >= 0 && pn.sym == _Sym.crown;
    if (crownWin) {
      D.rays(c, r.center, 90, const Color(0x66FFC53D), count: 10, t: _t * 2);
      c.drawRRect(rr, D.fill(Color.fromRGBO(255, 225, 90, .25 + .2 * math.sin(_t * 10))));
    }
    // the prize symbol
    if (pn.sym != null) {
      final rt = pn.revealed ? pn.revealT : 0.0;
      final pop = pn.revealed && rt > 0 ? 1 + .35 * math.sin(M.clamp01(rt / .35) * math.pi) : 1.0;
      c.save();
      c.clipRRect(rr);
      c.translate(r.center.dx, r.center.dy);
      c.scale(pop * (crownWin ? 1 + .06 * math.sin(_t * 12) : 1));
      _symbol(c, pn.sym!, Offset.zero);
      c.restore();
    }
    // silver foil (with the scratched parts cleared)
    final foilA = pn.revealed ? 1 - M.clamp01(pn.revealT / .25) : 1.0;
    if (foilA > 0) {
      final sh = Offset(math.sin(_t * 70) * pn.shake * 1.5, 0);
      c.saveLayer(r.inflate(4), Paint()..color = Color.fromRGBO(0, 0, 0, foilA));
      c.translate(sh.dx, sh.dy);
      c.drawRRect(rr, Paint()
        ..shader = ui.Gradient.linear(r.topLeft, r.bottomRight,
            const [Color(0xFFF2F4FA), Color(0xFFB4BACB), Color(0xFFE6E9F2), Color(0xFF9097AB)], const [0, .35, .6, 1]));
      // printed coin pattern
      final pat = D.fill(const Color(0x33FFFFFF));
      for (var y = r.top + 14; y < r.bottom; y += 26) {
        for (var x = r.left + 14 + (((y - r.top) ~/ 26).isOdd ? 13 : 0); x < r.right; x += 26) {
          c.drawCircle(Offset(x, y), 7, pat);
        }
      }
      D.text(c, '?', r.center, size: 44, color: const Color(0x66FFFFFF), stroke: const Color(0x33000000), strokeWidth: 4);
      // moving glint
      final gx = r.left + ((_t * 140 + r.top) % (r.width + 120)) - 60;
      c.save();
      c.clipRRect(rr);
      c.drawPath(
          Path()
            ..moveTo(gx, r.top)
            ..lineTo(gx + 26, r.top)
            ..lineTo(gx - 14, r.bottom)
            ..lineTo(gx - 40, r.bottom)
            ..close(),
          D.fill(const Color(0x66FFFFFF)));
      c.restore();
      // reach shimmer on remaining panels
      if (_reach && !pn.revealed) {
        c.drawRRect(rr, D.fill(Color.fromRGBO(255, 210, 60, .18 + .15 * math.sin(_t * 8.4))));
      }
      c.drawPath(
          pn.path,
          Paint()
            ..blendMode = BlendMode.clear
            ..style = PaintingStyle.stroke
            ..strokeWidth = _brush * 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = ui.StrokeJoin.round);
      c.drawPath(
          pn.path,
          Paint()
            ..blendMode = BlendMode.clear
            ..style = PaintingStyle.fill);
      c.restore();
    }
    c.drawRRect(rr, D.stroke(Pal.ink, 3));
    if (_reach && !pn.revealed) {
      c.drawRRect(rr.inflate(3), D.stroke(Color.fromRGBO(255, 60, 90, .5 + .5 * math.sin(_t * 8.4)), 3));
    }
  }

  void _symbol(Canvas c, _Sym s, Offset o) {
    switch (s) {
      case _Sym.crown:
        _crown(c, o, 34, _t);
      case _Sym.cherry:
        c.drawPath(
            Path()
              ..moveTo(o.dx - 14, o.dy + 8)
              ..quadraticBezierTo(o.dx - 6, o.dy - 18, o.dx + 8, o.dy - 28)
              ..moveTo(o.dx + 16, o.dy + 10)
              ..quadraticBezierTo(o.dx + 14, o.dy - 12, o.dx + 8, o.dy - 28),
            D.stroke(const Color(0xFF3F7A1F), 4));
        c.drawOval(Rect.fromLTWH(o.dx + 8, o.dy - 38, 24, 13), D.fill(Pal.lime));
        for (final p in [o + const Offset(-14, 16), o + const Offset(16, 18)]) {
          c.drawCircle(p, 17, D.fill(const Color(0xFFE0102F)));
          c.drawCircle(p, 17, D.stroke(Pal.ink, 3));
          c.drawCircle(p + const Offset(-5, -6), 4.5, D.fill(const Color(0xCCFFFFFF)));
        }
      case _Sym.bell:
        final bell = Path()
          ..moveTo(o.dx - 32, o.dy + 20)
          ..quadraticBezierTo(o.dx - 24, o.dy + 10, o.dx - 22, o.dy - 6)
          ..quadraticBezierTo(o.dx - 20, o.dy - 32, o.dx, o.dy - 32)
          ..quadraticBezierTo(o.dx + 20, o.dy - 32, o.dx + 22, o.dy - 6)
          ..quadraticBezierTo(o.dx + 24, o.dy + 10, o.dx + 32, o.dy + 20)
          ..close();
        c.drawCircle(o + const Offset(0, 24), 8, D.fill(const Color(0xFFB07000)));
        c.drawPath(bell, D.fill(Pal.gold));
        c.drawPath(bell, D.stroke(Pal.ink, 3.5));
        c.drawLine(o + const Offset(-12, -18), o + const Offset(-14, 4), D.stroke(const Color(0xAAFFFFFF), 5));
      case _Sym.diamond:
        D.gem(c, o, 34, Pal.sky);
      case _Sym.clover:
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2 + math.pi / 4;
          final p = o + Offset(math.cos(a), math.sin(a)) * 15 + const Offset(0, -4);
          D.heart(c, p, 30, Pal.green, border: Pal.ink);
        }
        c.drawLine(o + const Offset(0, 6), o + const Offset(8, 32), D.stroke(const Color(0xFF1E8A4A), 5));
      case _Sym.horseshoe:
        c.drawArc(Rect.fromCircle(center: o + const Offset(0, 2), radius: 26), math.pi * .85, -math.pi * 1.7, false, D.stroke(Pal.ink, 18));
        c.drawArc(Rect.fromCircle(center: o + const Offset(0, 2), radius: 26), math.pi * .85, -math.pi * 1.7, false, D.stroke(const Color(0xFFB0B6C8), 12));
        for (var i = 0; i < 5; i++) {
          final a = math.pi * .85 - i * math.pi * 1.7 / 4;
          c.drawCircle(o + const Offset(0, 2) + Offset(math.cos(a), math.sin(a)) * 26, 2.5, D.fill(Pal.ink));
        }
      case _Sym.lemon:
        c.drawOval(Rect.fromCenter(center: o, width: 64, height: 46), D.fill(Pal.yellow));
        c.drawOval(Rect.fromCenter(center: o, width: 64, height: 46), D.stroke(Pal.ink, 3.5));
        c.drawOval(Rect.fromCenter(center: o + const Offset(-10, -8), width: 18, height: 8), D.fill(const Color(0xAAFFFFFF)));
    }
  }

  void _crown(Canvas c, Offset o, double r, double t) {
    final bob = t > 0 ? math.sin(t * 5) * r * .05 : 0.0;
    final p = Path()
      ..moveTo(o.dx - r, o.dy + r * .55 + bob)
      ..lineTo(o.dx - r * 1.05, o.dy - r * .55 + bob)
      ..lineTo(o.dx - r * .5, o.dy - r * .05 + bob)
      ..lineTo(o.dx, o.dy - r * .85 + bob)
      ..lineTo(o.dx + r * .5, o.dy - r * .05 + bob)
      ..lineTo(o.dx + r * 1.05, o.dy - r * .55 + bob)
      ..lineTo(o.dx + r, o.dy + r * .55 + bob)
      ..close();
    c.drawPath(p, Paint()
      ..shader = ui.Gradient.linear(o - Offset(r, r), o + Offset(r, r), const [Color(0xFFFFF4A0), Color(0xFFFFC53D), Color(0xFFD08A00)], const [0, .5, 1]));
    c.drawPath(p, D.stroke(Pal.ink, math.max(2, r * .1)));
    c.drawRect(Rect.fromLTRB(o.dx - r, o.dy + r * .3 + bob, o.dx + r, o.dy + r * .55 + bob), D.fill(const Color(0xFFD08A00)));
    c.drawCircle(o + Offset(0, r * .12 + bob), r * .16, D.fill(Pal.red));
    c.drawCircle(o + Offset(-r * .55, r * .2 + bob), r * .1, D.fill(Pal.sky));
    c.drawCircle(o + Offset(r * .55, r * .2 + bob), r * .1, D.fill(Pal.lime));
    for (final x in [-1.05, 0.0, 1.05]) {
      c.drawCircle(o + Offset(x * r, (x == 0 ? -.85 : -.55) * r + bob), r * .1, D.fill(Pal.white));
    }
  }

  void _hint(Canvas c) {
    if (_winT >= 0) return;
    if (_touched == 0 || (_lastScratch > 2.0 && host.time > 1)) {
      final pn = _panels.firstWhere((p) => !p.revealed, orElse: () => _panels.first);
      final k = (_t * 1.4) % 1;
      final p = Offset(pn.r.left + 20 + k * (pn.r.width - 40), pn.r.center.dy + math.sin(k * math.pi * 6) * 26);
      D.hand(c, p, _t);
      D.title(c, host.tr('scratch', 'SCRATCH!'), Offset(180, pn.r.top - 30), size: 30, scale: 1 + .05 * math.sin(_t * 8));
    }
  }
}
