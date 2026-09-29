import '../engine/engine.dart';

/// No.023 Conquer the Map — State.io parody. Drag from your blue bases to
/// send half of their troops; capture every red base to paint the map blue.
class G023 extends MiniGame {
  static const _cell = 20.0;
  static const _blueC = Color(0xFF3D7BFF);
  static const _redC = Color(0xFFFF4060);
  static const _grayC = Color(0xFFB9B3A2);

  final List<_Base> _bases = [];
  final List<_Troop> _troops = [];
  final List<_Cell> _cells = [];
  final List<_Base> _sel = [];
  final Paint _paint = Paint();
  Offset? _drag;
  double _t = 0;
  double _aiT = 3.2;
  double _growBlue = 0, _growRed = 0;
  int _sends = 0;
  int _captures = 0;
  bool _ended = false;
  double _shareBlue = 0, _shareRed = 0;

  static Color _col(int owner) => owner == 1 ? _blueC : (owner == 2 ? _redC : _grayC);
  static Color _land(int owner) => owner == 1
      ? const Color(0xFF8DB8FF)
      : (owner == 2 ? const Color(0xFFFF9AA8) : const Color(0xFFE9DFC4));

  @override
  void init() {
    const layout = <(double, double, int, int)>[
      (180, 568, 1, 22),
      (86, 118, 2, 14),
      (276, 148, 2, 14),
      (70, 300, 0, 8),
      (192, 246, 0, 12),
      (300, 330, 0, 6),
      (104, 448, 0, 5),
      (272, 470, 0, 7),
      (182, 376, 0, 10),
    ];
    for (final l in layout) {
      _bases.add(_Base(Offset(l.$1 + rand(-6, 6), l.$2 + rand(-6, 6)), l.$3, l.$4));
    }
    // Build the land grid (a blobby continent) and assign each cell to its nearest base.
    for (var y = 62.0; y < 632; y += _cell) {
      for (var x = 8.0; x < 352; x += _cell) {
        final p = Offset(x + _cell / 2, y + _cell / 2);
        if (!_isLand(p)) continue;
        var best = 0;
        var bd = 1e9;
        for (var i = 0; i < _bases.length; i++) {
          final d = (_bases[i].pos - p).distance;
          if (d < bd) {
            bd = d;
            best = i;
          }
        }
        final cl = _Cell(Rect.fromLTWH(x, y, _cell, _cell), best, bd);
        if (bd > 44 && chance(.09)) cl.deco = chance(.6) ? 1 : 2;
        _cells.add(cl);
      }
    }
    // Border flags (neighbour belongs to a different base).
    final byKey = <int, _Cell>{};
    int key(Rect r) => (r.left / _cell).round() * 1000 + (r.top / _cell).round();
    for (final c in _cells) {
      byKey[key(c.r)] = c;
    }
    for (final c in _cells) {
      final k = key(c.r);
      for (final d in const [1, -1, 1000, -1000]) {
        final n = byKey[k + d];
        if (n == null) {
          c.coast = true;
        } else if (n.base != c.base) {
          c.border |= d == 1 ? 1 : (d == -1 ? 2 : (d == 1000 ? 4 : 8));
        }
      }
    }
  }

  void _drawDeco(Canvas c, _Cell cl) {
    final o = cl.r.center;
    if (cl.deco == 1) {
      c.drawCircle(o + const Offset(0, 4), 6, D.fill(const Color(0x33000000)));
      c.drawRect(Rect.fromCenter(center: o + const Offset(0, 3), width: 3, height: 7), D.fill(Pal.brown));
      c.drawCircle(o + const Offset(0, -2), 6, D.fill(const Color(0xFF3FAE5A)));
      c.drawCircle(o + const Offset(-2, -4), 2.5, D.fill(const Color(0xFF7BD68C)));
    } else {
      final m = Path()
        ..moveTo(o.dx - 9, o.dy + 7)
        ..lineTo(o.dx - 1, o.dy - 8)
        ..lineTo(o.dx + 9, o.dy + 7)
        ..close();
      c.drawPath(m, D.fill(const Color(0xFF9C8A6A)));
      c.drawPath(
          Path()
            ..moveTo(o.dx - 4, o.dy - 2)
            ..lineTo(o.dx - 1, o.dy - 8)
            ..lineTo(o.dx + 3, o.dy - 2)
            ..close(),
          D.fill(Pal.white));
      c.drawPath(m, D.stroke(const Color(0x66000000), 1.5));
    }
  }

  bool _isLand(Offset p) {
    final wob = sin(p.dx * .045) * 14 + cos(p.dy * .038) * 12;
    bool blob(double cx, double cy, double rx, double ry) {
      final dx = (p.dx - cx) / (rx + wob), dy = (p.dy - cy) / (ry + wob);
      return dx * dx + dy * dy < 1;
    }

    return blob(180, 345, 150, 215) || blob(92, 128, 78, 76) || blob(278, 158, 74, 80) || blob(180, 566, 104, 62);
  }

  _Base? _baseAt(Offset p, {double pad = 16}) {
    _Base? best;
    var bd = 1e9;
    for (final b in _bases) {
      final d = (b.pos - p).distance;
      if (d < b.radius + pad && d < bd) {
        bd = d;
        best = b;
      }
    }
    return best;
  }

  void _send(_Base from, _Base to, int owner) {
    final n = from.n ~/ 2;
    if (n <= 0) return;
    from.n -= n;
    from.bounce = 1;
    final dir = (to.pos - from.pos);
    final nrm = Offset(-dir.dy, dir.dx) / max(dir.distance, 1);
    for (var i = 0; i < n; i++) {
      final lane = ((i % 3) - 1) * 5.0;
      _troops.add(_Troop(from.pos + nrm * lane, to, owner, i * .035, nrm * lane));
    }
    if (owner == 1) {
      host.sfx(Sfx.whoosh, volume: .7, rate: 1.1);
      host.sfx(Sfx.pop, volume: .5);
    } else {
      host.sfx(Sfx.swipe, volume: .35, rate: .8);
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    for (final b in _bases) {
      b.bounce = M.approach(b.bounce, 0, 6, dt);
      b.hit = M.approach(b.hit, 0, 8, dt);
      b.anim = min(2, b.anim + dt * 1.2);
    }
    if (!_ended) {
      _growBlue += dt;
      _growRed += dt * .75 * host.speed;
      if (_growBlue > .5) {
        _growBlue -= .5;
        for (final b in _bases) {
          if (b.owner == 1 && b.n < 60) b.n++;
        }
      }
      if (_growRed > .5) {
        _growRed -= .5;
        for (final b in _bases) {
          if (b.owner == 2 && b.n < 60) b.n++;
        }
      }
      _ai(dt);
    }
    // troops
    for (final tr in _troops) {
      if (tr.delay > 0) {
        tr.delay -= dt;
        continue;
      }
      final target = tr.to.pos + tr.lane * (1 - tr.progress.clamp(0, 1));
      final d = target - tr.pos;
      final dist = d.distance;
      const sp = 125.0;
      if (dist < sp * dt + 4) {
        tr.dead = true;
        _arrive(tr);
      } else {
        tr.pos += d / dist * sp * dt;
        tr.progress += dt * .5;
      }
    }
    // head-on clashes between opposing dots
    for (var i = 0; i < _troops.length; i++) {
      final a = _troops[i];
      if (a.dead || a.delay > 0) continue;
      for (var j = i + 1; j < _troops.length; j++) {
        final b = _troops[j];
        if (b.dead || b.delay > 0 || b.owner == a.owner) continue;
        if ((a.pos - b.pos).distanceSquared < 49) {
          a.dead = b.dead = true;
          host.fx.burst((a.pos + b.pos) / 2, Pal.white, count: 4, speed: 90, size: 4, gravity: 0, life: .25);
          if (chance(.2)) host.sfx(Sfx.tick, volume: .4, rate: rand(1.2, 1.6));
          break;
        }
      }
    }
    _troops.removeWhere((t) => t.dead);

    // territory share
    var nb = 0, nr = 0;
    for (final c in _cells) {
      final o = _bases[c.base].owner;
      if (o == 1) nb++;
      if (o == 2) nr++;
    }
    _shareBlue = M.approach(_shareBlue, nb / max(1, _cells.length), 6, dt);
    _shareRed = M.approach(_shareRed, nr / max(1, _cells.length), 6, dt);

    if (!_ended) {
      final redAlive = _bases.any((b) => b.owner == 2) || _troops.any((t) => t.owner == 2);
      final blueAlive = _bases.any((b) => b.owner == 1) || _troops.any((t) => t.owner == 1);
      if (!redAlive) {
        _ended = true;
        host.fx.confetti(count: 90);
        host.sfx(Sfx.fanfare);
        host.flash(const Color(0x663D7BFF));
        host.win(stars: host.time < 14 ? 3 : (host.time < 19 ? 2 : 1));
      } else if (!blueAlive) {
        _ended = true;
        host.sfx(Sfx.jingleLose);
        host.lose();
      }
    }
  }

  void _ai(double dt) {
    _aiT -= dt * host.speed;
    if (_aiT > 0) return;
    _aiT = rand(1.4, 2.2);
    final reds = _bases.where((b) => b.owner == 2 && b.n >= 8).toList();
    if (reds.isEmpty) return;
    reds.sort((a, b) => b.n.compareTo(a.n));
    final src = reds.first;
    _Base? best;
    var bs = 1e9;
    for (final b in _bases) {
      if (b.owner == 2) continue;
      final score = b.n + (b.pos - src.pos).distance / 30 + (b.owner == 1 ? 4 : 0);
      if (score < bs) {
        bs = score;
        best = b;
      }
    }
    if (best == null) return;
    if (src.n ~/ 2 > best.n + 1 || chance(.25)) _send(src, best, 2);
  }

  void _arrive(_Troop tr) {
    final b = tr.to;
    if (b.owner == tr.owner) {
      b.n++;
      b.bounce = max(b.bounce, .35);
      return;
    }
    b.hit = 1;
    if (b.n > 0) {
      b.n--;
      if (tr.owner == 1 && chance(.3)) host.sfx(Sfx.hit, volume: .35, rate: rand(1.1, 1.5));
      return;
    }
    // capture!
    final prev = b.owner;
    b.prevOwner = prev;
    b.owner = tr.owner;
    b.n = 1;
    b.anim = 0;
    b.bounce = 1.3;
    host.fx.ring(b.pos, _col(tr.owner), size: 90);
    host.fx.burst(b.pos, _col(tr.owner), count: 22, speed: 260, size: 7, colors: [_col(tr.owner), Pal.white, Pal.yellow]);
    if (tr.owner == 1) {
      _captures++;
      host.sfx(Sfx.levelup, rate: 1 + _captures * .06);
      host.shake(prev == 2 ? 7 : 4);
      host.punch(.03);
      host.addScore(prev == 2 ? 300 : 100, b.pos + const Offset(0, -34));
      host.fx.pop(prev == 2 ? host.tr('ko', 'K.O.!') : host.tr('nice', 'NICE!'), b.pos + const Offset(0, -60),
          color: prev == 2 ? Pal.yellow : Pal.white, size: prev == 2 ? 32 : 24);
      if (prev == 2) host.fx.coins(b.pos, count: 12);
    } else {
      host.sfx(Sfx.wrong, volume: .6);
      host.shake(3);
      host.fx.pop(host.tr('oops', 'OOPS'), b.pos + const Offset(0, -50), color: _redC, size: 22);
    }
  }

  @override
  void onDown(Offset p) {
    if (_ended) return;
    final b = _baseAt(p);
    if (b != null && b.owner == 1) {
      _sel
        ..clear()
        ..add(b);
      _drag = p;
      host.sfx(Sfx.select, volume: .6);
    }
  }

  @override
  void onMove(Offset p) {
    if (_drag == null) return;
    _drag = p;
    final b = _baseAt(p, pad: 6);
    if (b != null && b.owner == 1 && !_sel.contains(b)) {
      _sel.add(b);
      b.bounce = .6;
      host.sfx(Sfx.select, rate: 1 + _sel.length * .1, volume: .6);
    }
  }

  @override
  void onUp(Offset p) {
    if (_drag == null) return;
    final target = _baseAt(p);
    if (target != null && !(_sel.length == 1 && _sel.first == target)) {
      for (final s in _sel) {
        if (s != target) _send(s, target, 1);
      }
      _sends++;
    }
    _sel.clear();
    _drag = null;
  }

  @override
  void onTimeUp() {
    final blue = _bases.where((b) => b.owner == 1).length;
    final red = _bases.where((b) => b.owner == 2).length;
    if (blue > red * 2) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    // ocean
    D.gradientBg(c, const [Color(0xFF1C5FA8), Color(0xFF0E3470)]);
    final wave = D.stroke(const Color(0x33FFFFFF), 2);
    for (var i = 0; i < 26; i++) {
      final x = (i * 83.0 + _t * 10) % 400 - 20;
      final y = 40.0 + (i * 137.0) % 600;
      c.drawArc(Rect.fromCenter(center: Offset(x, y), width: 18, height: 8), pi, pi, false, wave);
      c.drawArc(Rect.fromCenter(center: Offset(x + 14, y), width: 18, height: 8), pi, pi, false, wave);
    }
    // land cliff (shadow) then cells
    _paint.color = const Color(0xFF6B5A3A);
    for (final cl in _cells) {
      if (cl.coast) c.drawRect(cl.r.shift(const Offset(0, 5)).inflate(1), _paint);
    }
    for (final cl in _cells) {
      final b = _bases[cl.base];
      final k = M.clamp01((b.anim - cl.dist / 420) * 5);
      final base = Color.lerp(_land(b.prevOwner), _land(b.owner), k)!;
      final chk = ((cl.r.left / _cell).round() + (cl.r.top / _cell).round()).isEven ? .04 : 0.0;
      final wv = chk + .03 * sin(_t * 2 + cl.r.left * .05 + cl.r.top * .03);
      _paint.color = Color.lerp(base, Pal.white, .06 + wv)!;
      c.drawRect(cl.r, _paint);
      if (cl.deco > 0) _drawDeco(c, cl);
      if (cl.border != 0) {
        _paint.color = Color.lerp(base, Pal.ink, .35)!;
        final r = cl.r;
        if (cl.border & 1 != 0) c.drawRect(Rect.fromLTWH(r.left, r.bottom - 3, _cell, 3), _paint);
        if (cl.border & 2 != 0) c.drawRect(Rect.fromLTWH(r.left, r.top, _cell, 3), _paint);
        if (cl.border & 4 != 0) c.drawRect(Rect.fromLTWH(r.right - 3, r.top, 3, _cell), _paint);
        if (cl.border & 8 != 0) c.drawRect(Rect.fromLTWH(r.left, r.top, 3, _cell), _paint);
      }
      // capture ripple highlight
      if (k > 0 && k < 1) {
        _paint.color = Color.fromRGBO(255, 255, 255, .6 * (1 - k));
        c.drawRect(cl.r, _paint);
      }
    }
    // grid lines for the map look
    final gp = Paint()..color = const Color(0x14000000);
    for (final cl in _cells) {
      c.drawRect(Rect.fromLTWH(cl.r.left, cl.r.top, _cell, 1), gp);
      c.drawRect(Rect.fromLTWH(cl.r.left, cl.r.top, 1, _cell), gp);
    }

    // drag arrows
    if (_drag != null) {
      final tgt = _baseAt(_drag!);
      for (final s in _sel) {
        final end = tgt != null && tgt != s ? tgt.pos : _drag!;
        final d = end - s.pos;
        if (d.distance > 30) {
          final mid = s.pos + d / 2;
          D.arrow(c, mid, d, d.distance - s.radius - 6, const Color(0xDD7FB0FF), width: 9);
        }
      }
      if (tgt != null) {
        c.drawCircle(tgt.pos, tgt.radius + 10 + sin(_t * 12) * 3,
            D.stroke(tgt.owner == 1 ? Pal.white : Pal.yellow, 4));
      }
    }

    // troops
    final ink = Paint()..color = Pal.ink;
    for (final tr in _troops) {
      if (tr.delay > 0) continue;
      c.drawCircle(tr.pos, 4.6, ink);
      _paint.color = tr.owner == 1 ? const Color(0xFF7FB0FF) : const Color(0xFFFF8093);
      c.drawCircle(tr.pos, 3.2, _paint);
    }

    // bases
    for (final b in _bases) {
      _drawBase(c, b);
    }

    // HUD: territory share bar
    const bar = Rect.fromLTWH(20, 44, 320, 14);
    D.rrect(c, bar.inflate(3), 10, Pal.ink);
    D.rrect(c, bar, 7, _grayC);
    final bw = bar.width * _shareBlue, rw = bar.width * _shareRed;
    if (bw > 1) D.rrect(c, Rect.fromLTWH(bar.left, bar.top, bw, bar.height), 7, _blueC);
    if (rw > 1) D.rrect(c, Rect.fromLTWH(bar.right - rw, bar.top, rw, bar.height), 7, _redC);
    D.text(c, '${(_shareBlue * 100).round()}%', const Offset(26, 51), size: 12, anchor: Alignment.centerLeft, stroke: Pal.ink);
    D.text(c, '${(_shareRed * 100).round()}%', const Offset(334, 51), size: 12, anchor: Alignment.centerRight, stroke: Pal.ink);

    // tutorial hand
    if (_sends == 0 && host.time < 4 && !_ended) {
      final from = _bases[0].pos, to = _bases[6].pos;
      final k = (_t * .8) % 1;
      final pos = Offset.lerp(from, to, M.easeInOut(M.clamp01(k * 1.3)))!;
      final dots = Paint()..color = const Color(0xAAFFFFFF);
      for (var i = 0.0; i < 1; i += .1) {
        c.drawCircle(Offset.lerp(from, to, i)!, 3, dots);
      }
      D.hand(c, pos, 0);
      D.text(c, host.tr('drag', 'DRAG!'), from + const Offset(0, -58), size: 22, stroke: Pal.ink, color: Pal.yellow);
    }
  }

  void _drawBase(Canvas c, _Base b) {
    final col = _col(b.owner);
    final r = b.radius;
    final s = 1 + b.bounce * .18 * sin(b.bounce * 9) - b.hit * .06;
    final sel = _sel.contains(b);
    D.shadow(c, b.pos + Offset(0, r * .8), r * 2, r * .7, .3);
    c.save();
    c.translate(b.pos.dx, b.pos.dy);
    c.scale(s, 1 / s.clamp(.8, 1.3));
    if (sel) {
      c.drawCircle(Offset.zero, r + 9 + sin(_t * 14) * 2, Paint()..color = const Color(0x66FFFFFF));
    }
    // tower base
    D.circle(c, Offset.zero, r, Color.lerp(col, Pal.ink, .35)!, border: Pal.ink, borderWidth: 3);
    D.circle(c, const Offset(0, -4), r - 2, col, border: Pal.ink, borderWidth: 3);
    c.drawCircle(const Offset(0, -4), r - 8, D.stroke(const Color(0x55FFFFFF), 3));
    // battlements
    for (var i = -1; i <= 1; i++) {
      D.rrect(c, Rect.fromCenter(center: Offset(i * r * .5, -r - 2), width: 9, height: 10), 2,
          Color.lerp(col, Pal.white, .2)!, border: Pal.ink, borderWidth: 2);
    }
    // flag
    final fw = sin(_t * 8 + b.pos.dx) * 3;
    D.line(c, Offset(r * .55, -r - 4), Offset(r * .55, -r - 26), Pal.ink, 2.5);
    final flag = Path()
      ..moveTo(r * .55, -r - 26)
      ..quadraticBezierTo(r * .55 + 9, -r - 28 + fw, r * .55 + 17, -r - 21 + fw)
      ..lineTo(r * .55, -r - 16)
      ..close();
    c.drawPath(flag, D.fill(col));
    c.drawPath(flag, D.stroke(Pal.ink, 2));
    D.text(c, '${b.n}', const Offset(0, -3), size: 19 + min(8, b.n / 6), stroke: Pal.ink, strokeWidth: 4.5);
    c.restore();
    // commander face peeking
    if (b.owner != 0) {
      final f = b.hit > .3
          ? Face.shocked
          : (b.owner == 1 ? (sel ? Face.love : Face.happy) : Face.angry);
      final fp = b.pos + Offset(-r * .9, r * .55);
      D.blob(c, fp, 9, b.owner == 1 ? const Color(0xFFBFD6FF) : const Color(0xFFFFC1CB), face: f);
    }
  }
}

class _Base {
  _Base(this.pos, this.owner, this.n) : prevOwner = owner;
  final Offset pos;
  int owner;
  int prevOwner;
  int n;
  double bounce = 0;
  double hit = 0;
  double anim = 2;
  double get radius => 20 + min(8, n / 7);
}

class _Troop {
  _Troop(this.pos, this.to, this.owner, this.delay, this.lane);
  Offset pos;
  final _Base to;
  final int owner;
  double delay;
  final Offset lane;
  double progress = 0;
  bool dead = false;
}

class _Cell {
  _Cell(this.r, this.base, this.dist);
  final Rect r;
  final int base;
  final double dist;
  int border = 0;
  int deco = 0;
  bool coast = false;
}
