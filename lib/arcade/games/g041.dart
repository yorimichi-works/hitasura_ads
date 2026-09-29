import '../engine/engine.dart';

/// No.041 Pizza Slice Justice — swipe two straight cuts to split one pizza
/// between 4 hungry kids. The pieces are measured (area sampling) and the
/// kids judge you. Fair = cheers, unfair = a very loud table.
class G041 extends MiniGame {
  static const _c = Offset(180, 338);
  static const double _r = 116;
  static const _kidPos = [Offset(64, 128), Offset(296, 128), Offset(64, 556), Offset(296, 556)];
  static const _kidCol = [Pal.pink, Pal.sky, Pal.lime, Pal.orange];
  static const _hairCol = [Color(0xFF3A2A20), Color(0xFFE0B040), Color(0xFFD9502B), Color(0xFF222244)];

  final _cuts = <(Offset, Offset)>[]; // origin, unit direction
  Offset? _start;
  Offset? _cur;
  late Path _cheese;
  final _tops = <_Top>[];
  List<_Piece> _pieces = [];
  double _t = 0;
  double _sep = 0;
  double _sepTarget = 0;
  int _phase = 0; // 0 cutting, 1 judging, 2 verdict
  double _judgeT = 0;
  int _revealed = 0;
  double _cutFlash = 0;
  Offset _cutA = Offset.zero, _cutB = Offset.zero;
  bool _fair = false;
  final _face = List<Face>.filled(4, Face.love);
  final _share = List<double>.filled(4, -1);
  final _bounce = List<double>.filled(4, 0);
  late final List<double> _skin;

  @override
  void init() {
    _skin = List.generate(4, (_) => rand(0, .7));
    // wobbly cheese
    _cheese = Path();
    for (var i = 0; i <= 44; i++) {
      final a = i / 44 * pi * 2;
      final rr = _r - 17 + sin(a * 7) * 3 + sin(a * 3 + 1) * 2;
      final p = _c + Offset(cos(a), sin(a)) * rr;
      i == 0 ? _cheese.moveTo(p.dx, p.dy) : _cheese.lineTo(p.dx, p.dy);
    }
    _cheese.close();
    void place(int kind, int n, double size) {
      var tries = 0;
      var placed = 0;
      while (placed < n && tries++ < 400) {
        final a = rand(0, pi * 2), d = sqrt(rand(0, 1)) * (_r - 30);
        final p = _c + Offset(cos(a), sin(a)) * d;
        if (_tops.any((t) => (t.pos - p).distance < t.size + size + 3)) continue;
        _tops.add(_Top(kind, p, size, rand(0, pi * 2)));
        placed++;
      }
    }

    place(0, 9, 13);
    place(1, 5, 9);
    place(2, 6, 8);
    place(3, 7, 6);
  }

  double _side(int i, Offset p) {
    final (o, d) = _cuts[i];
    final v = p - o;
    return d.dx * v.dy - d.dy * v.dx;
  }

  List<_Piece> _compute() {
    final map = <int, _Piece>{};
    const step = 2.5;
    var total = 0;
    for (var y = -_r; y <= _r; y += step) {
      for (var x = -_r; x <= _r; x += step) {
        if (x * x + y * y > _r * _r) continue;
        final p = _c + Offset(x, y);
        var key = 0;
        for (var i = 0; i < _cuts.length; i++) {
          if (_side(i, p) > 0) key |= 1 << i;
        }
        final pc = map[key] ??= _Piece(key);
        pc.n++;
        pc.sx += x;
        pc.sy += y;
        total++;
      }
    }
    final out = <_Piece>[];
    for (final pc in map.values) {
      pc.share = pc.n / total;
      if (pc.share < .004) continue;
      pc.centroid = _c + Offset(pc.sx / pc.n, pc.sy / pc.n);
      out.add(pc);
    }
    return out;
  }

  Path _half(int i, bool positive) {
    final (o, d) = _cuts[i];
    final n = Offset(-d.dy, d.dx) * (positive ? 1000 : -1000);
    final a = o - d * 1000, b = o + d * 1000;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx + n.dx, b.dy + n.dy)
      ..lineTo(a.dx + n.dx, a.dy + n.dy)
      ..close();
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _sep = M.approach(_sep, _sepTarget, 7, dt);
    _cutFlash = max(0, _cutFlash - dt * 2.5);
    for (var i = 0; i < 4; i++) {
      _bounce[i] = M.approach(_bounce[i], 0, 5, dt);
    }
    if (_phase == 1) {
      _judgeT += dt;
      final want = ((_judgeT - .5) / .38).floor() + 1;
      while (_revealed < min(want, _pieces.length)) {
        final pc = _pieces[_revealed];
        _revealed++;
        if (pc.kid >= 0) {
          _share[pc.kid] = pc.share;
          _face[pc.kid] = _reaction(pc.share);
          _bounce[pc.kid] = 1;
        }
        host.sfx(Sfx.tick, rate: .9 + _revealed * .12);
        host.fx.ring(_offsetCentroid(pc), Pal.white, size: 40, life: .3);
      }
      if (_judgeT >= .5 + _pieces.length * .38 + .35) _verdict();
    }
    if (_phase == 2) {
      for (var i = 0; i < 4; i++) {
        if (_fair || _face[i] == Face.smug) {
          if ((_t * 3 + i).floor() % 2 == 0) _bounce[i] = max(_bounce[i], .6);
        }
      }
    }
  }

  Face _reaction(double s) {
    if (s >= .29) return Face.smug;
    if (s >= .215) return Face.love;
    if (s >= .16) return Face.sad;
    return Face.cry;
  }

  void _verdict() {
    if (_phase == 2) return;
    _phase = 2;
    final shares = _pieces.map((p) => p.share).toList();
    final ratio = _pieces.length < 4 ? 99.0 : shares.reduce(max) / shares.reduce(min);
    for (var i = 0; i < 4; i++) {
      if (_share[i] < 0) {
        _face[i] = Face.cry; // no slice at all!
        _share[i] = 0;
      }
    }
    _fair = ratio < 1.5;
    if (_fair) {
      for (var i = 0; i < 4; i++) {
        _face[i] = Face.happy;
        _bounce[i] = 1;
      }
      final stars = ratio < 1.15 ? 3 : (ratio < 1.3 ? 2 : 1);
      host.sfx(stars == 3 ? Sfx.perfect : Sfx.correct);
      host.sfx(Sfx.cheer, volume: .7);
      host.fx.confetti(count: stars * 30);
      host.fx.pop(stars == 3 ? host.tr('perfect', 'PERFECT!') : host.tr('fair', 'FAIR!'), _c, color: Pal.yellow, size: 44, life: 1.4);
      host.addScore(stars * 100, _c + const Offset(0, 50));
      host.win(stars: stars);
    } else {
      for (var i = 0; i < 4; i++) {
        if (_face[i] != Face.smug) _face[i] = _share[i] < .16 ? Face.cry : Face.angry;
      }
      host.sfx(Sfx.buzzer);
      host.sfx(Sfx.aww, volume: .8);
      host.shake(8);
      host.flash(Pal.red, .15);
      host.fx.pop(host.tr('unfair', 'UNFAIR!'), _c, color: Pal.red, size: 44, life: 1.4);
      host.lose();
    }
  }

  // ------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    if (_phase != 0) return;
    _start = p;
    _cur = p;
  }

  @override
  void onMove(Offset p) {
    if (_start != null) _cur = p;
  }

  @override
  void onUp(Offset p) {
    final s = _start;
    _start = null;
    _cur = null;
    if (s == null || _phase != 0) return;
    final v = p - s;
    if (v.distance < 70) return;
    final d = v / v.distance;
    // distance from pizza center to the line
    final w = _c - s;
    final dist = (d.dx * w.dy - d.dy * w.dx).abs();
    if (dist > _r - 12) {
      host.sfx(Sfx.whoosh, volume: .6);
      host.fx.pop(host.tr('miss', 'MISS'), p, color: Pal.white, size: 20);
      return;
    }
    _cuts.add((s, d));
    // chord end points for the flash
    final foot = s + d * ((w.dx * d.dx + w.dy * d.dy));
    final half = sqrt(max(0, _r * _r - dist * dist));
    _cutA = foot - d * half;
    _cutB = foot + d * half;
    _cutFlash = 1;
    host.sfx(Sfx.slash);
    host.sfx(Sfx.chop, volume: .6, rate: 1.2);
    host.shake(4);
    host.hitStop(.05);
    for (var k = 0; k < 6; k++) {
      final q = Offset.lerp(_cutA, _cutB, k / 5)!;
      host.fx.burst(q, Pal.yellow, count: 3, speed: 120, size: 5, gravity: 200,
          colors: const [Color(0xFFFFE27A), Color(0xFFE8453C), Color(0xFFFFF4DC)]);
    }
    _pieces = _compute();
    if (_cuts.length == 1) {
      _sepTarget = .45;
      for (final pc in _pieces) {
        final pct = (pc.share * 100).round();
        final ok = (pct - 50).abs() <= 4;
        host.fx.pop('$pct%', _offsetCentroid(pc), color: ok ? Pal.lime : Pal.orange, size: 24, life: 1.1, rise: 20);
      }
      final diff = (_pieces.isEmpty ? 1.0 : (_pieces.first.share - .5).abs());
      if (diff < .03) {
        host.fx.pop(host.tr('nice', 'NICE!'), _c + const Offset(0, -150), color: Pal.yellow, size: 28);
        host.sfx(Sfx.ding);
      }
      for (var i = 0; i < 4; i++) {
        _bounce[i] = .5;
      }
    } else {
      _phase = 1;
      _judgeT = 0;
      _sep = .3;
      _sepTarget = 1;
      _assignKids();
      host.sfx(Sfx.drumroll, volume: .6);
    }
  }

  void _assignKids() {
    // brute-force best angular match of pieces to kids
    final n = _pieces.length;
    final perms = <List<int>>[];
    void gen(List<int> cur, List<bool> used) {
      if (cur.length == 4) {
        perms.add(List.of(cur));
        return;
      }
      for (var i = 0; i < 4; i++) {
        if (used[i]) continue;
        used[i] = true;
        cur.add(i);
        gen(cur, used);
        cur.removeLast();
        used[i] = false;
      }
    }

    gen([], List.filled(4, false));
    var best = perms.first;
    var bestCost = double.infinity;
    for (final perm in perms) {
      var cost = 0.0;
      for (var i = 0; i < n && i < 4; i++) {
        final pc = _pieces[i];
        final a1 = atan2(pc.centroid.dy - _c.dy, pc.centroid.dx - _c.dx);
        final kp = _kidPos[perm[i]];
        final a2 = atan2(kp.dy - _c.dy, kp.dx - _c.dx);
        var da = (a1 - a2).abs() % (pi * 2);
        if (da > pi) da = pi * 2 - da;
        cost += da;
      }
      if (cost < bestCost) {
        bestCost = cost;
        best = perm;
      }
    }
    for (var i = 0; i < n; i++) {
      _pieces[i].kid = i < 4 ? best[i] : -1;
    }
  }

  @override
  void onTimeUp() {
    if (_phase == 1) {
      while (_revealed < _pieces.length) {
        final pc = _pieces[_revealed++];
        if (pc.kid >= 0) _share[pc.kid] = pc.share;
      }
      _verdict();
      return;
    }
    for (var i = 0; i < 4; i++) {
      _face[i] = Face.angry;
      _bounce[i] = 1;
    }
    host.sfx(Sfx.buzzer);
    host.fx.pop(host.tr('time', 'TIME!'), _c, color: Pal.red, size: 40);
    host.lose();
  }

  Offset _offsetCentroid(_Piece pc) {
    final v = pc.centroid - _c;
    final d = v.distance < 1 ? Offset.zero : v / v.distance;
    return pc.centroid + d * (_sep * 16);
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    // wooden table + gingham cloth
    D.gradientBg(c, const [Color(0xFFB9723E), Color(0xFF8A4E26)]);
    for (var y = 36.0; y < 640; y += 22) {
      c.drawRect(Rect.fromLTWH(0, y, 360, 2), Paint()..color = const Color(0x22000000));
    }
    final cloth = RRect.fromRectAndRadius(const Rect.fromLTWH(14, 192, 332, 296), const Radius.circular(18));
    c.drawRRect(cloth.shift(const Offset(0, 6)), Paint()..color = const Color(0x55000000));
    c.save();
    c.clipRRect(cloth);
    c.drawRect(cloth.outerRect, Paint()..color = const Color(0xFFFFF4EC));
    final stripe = Paint()..color = const Color(0x66E8303C);
    for (var x = 14.0; x < 346; x += 36) {
      c.drawRect(Rect.fromLTWH(x, 192, 18, 296), stripe);
    }
    for (var y = 192.0; y < 488; y += 36) {
      c.drawRect(Rect.fromLTWH(14, y, 332, 18), stripe);
    }
    c.restore();

    // plate
    c.drawCircle(_c + const Offset(0, 8), _r + 20, Paint()..color = const Color(0x44000000));
    c.drawCircle(_c, _r + 18, Paint()..color = const Color(0xFFF2F2F8));
    c.drawCircle(_c, _r + 18, D.stroke(const Color(0xFFC8C8D8), 3));
    c.drawCircle(_c, _r + 8, D.stroke(const Color(0xFFE0E0EA), 2));

    // pizza (pieces)
    if (_cuts.isEmpty) {
      _pizza(c);
    } else {
      for (final pc in _pieces) {
        final off = _offsetCentroid(pc) - pc.centroid;
        c.save();
        c.translate(off.dx, off.dy);
        for (var i = 0; i < _cuts.length; i++) {
          c.clipPath(_half(i, (pc.key >> i) & 1 == 1));
        }
        c.drawCircle(_c + const Offset(0, 4), _r, Paint()..color = const Color(0x33000000));
        _pizza(c);
        c.restore();
      }
    }
    // cut flash
    if (_cutFlash > 0) {
      c.drawLine(_cutA, _cutB, D.stroke(Color.fromRGBO(255, 255, 255, _cutFlash), 10 * _cutFlash + 2));
    }
    // percentage labels while judging
    if (_phase >= 1) {
      for (var i = 0; i < _revealed && i < _pieces.length; i++) {
        final pc = _pieces[i];
        final pct = (pc.share * 100).round();
        final col = (pct - 25).abs() <= 3 ? Pal.lime : ((pct - 25).abs() <= 7 ? Pal.yellow : Pal.red);
        D.text(c, '$pct%', _offsetCentroid(pc), size: 26, color: col, stroke: Pal.ink, strokeWidth: 6);
      }
    }

    // knife preview
    final s = _start, cur = _cur;
    if (s != null && cur != null && (cur - s).distance > 8 && _phase == 0) {
      final d = (cur - s) / (cur - s).distance;
      c.drawLine(s - d * 400, s + d * 400, D.stroke(const Color(0x55FFFFFF), 3));
      c.drawLine(s, cur, D.stroke(const Color(0xAAFFFFFF), 8));
      c.drawLine(s, cur, D.stroke(Pal.white, 3));
      _cutter(c, cur);
    }

    // kids
    final look = host.pointerDown ? host.pointer : _c;
    for (var i = 0; i < 4; i++) {
      _kid(c, i, look);
    }

    // cut counter
    for (var i = 0; i < 2; i++) {
      final done = i < _cuts.length;
      final p = Offset(160 + i * 40.0, 88);
      D.circle(c, p, 15, done ? Pal.yellow : const Color(0x55000000), border: Pal.ink, borderWidth: 3);
      _knifeIcon(c, p, done ? Pal.ink : const Color(0xAAFFFFFF));
    }

    // tutorial
    if (_phase == 0 && _start == null && host.time < 3.5) {
      final vertical = _cuts.length == 1;
      final k = (_t * .8) % 1;
      final from = vertical ? _c + const Offset(0, -150) : _c + const Offset(-150, 0);
      final to = vertical ? _c + const Offset(0, 150) : _c + const Offset(150, 0);
      final paint = Paint()..color = const Color(0x99FFFFFF);
      for (var j = 0; j < 16; j++) {
        c.drawCircle(Offset.lerp(from, to, j / 15)!, 3, paint);
      }
      D.hand(c, Offset.lerp(from, to, M.easeInOut(k))!, _t);
    }
  }

  void _pizza(Canvas c) {
    c.drawCircle(_c, _r, D.fill(const Color(0xFFD9923E)));
    c.drawCircle(_c, _r - 3, D.fill(const Color(0xFFEDB25C)));
    c.drawCircle(_c, _r - 13, D.fill(const Color(0xFFD8452A)));
    c.drawPath(_cheese, D.fill(const Color(0xFFFFD760)));
    // cheese highlights
    for (var i = 0; i < 6; i++) {
      final a = i * 1.1;
      c.drawOval(Rect.fromCenter(center: _c + Offset(cos(a), sin(a)) * (40 + i * 9), width: 22, height: 10),
          D.fill(const Color(0x66FFF4B0)));
    }
    // crust dots
    for (var i = 0; i < 28; i++) {
      final a = i / 28 * pi * 2;
      c.drawCircle(_c + Offset(cos(a), sin(a)) * (_r - 7), 1.6, D.fill(const Color(0xFFB8702A)));
    }
    for (final t in _tops) {
      switch (t.kind) {
        case 0: // pepperoni
          c.drawCircle(t.pos + const Offset(0, 1.5), t.size, D.fill(const Color(0xFF8A1C1C)));
          c.drawCircle(t.pos, t.size, D.fill(const Color(0xFFC8283A)));
          c.drawCircle(t.pos + const Offset(-4, -3), 2.2, D.fill(const Color(0xFF8A1C1C)));
          c.drawCircle(t.pos + const Offset(4, 2), 1.8, D.fill(const Color(0xFF8A1C1C)));
          c.drawCircle(t.pos + const Offset(-1, 5), 1.5, D.fill(const Color(0xFF8A1C1C)));
          c.drawCircle(t.pos + const Offset(-4, -5), 2.5, D.fill(const Color(0x55FFFFFF)));
        case 1: // mushroom
          c.save();
          c.translate(t.pos.dx, t.pos.dy);
          c.rotate(t.rot);
          c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-3, -1, 6, 10), const Radius.circular(2)),
              D.fill(const Color(0xFFEDE0C8)));
          c.drawArc(const Rect.fromLTWH(-9, -8, 18, 14), pi, pi, true, D.fill(const Color(0xFFBFA488)));
          c.drawArc(const Rect.fromLTWH(-9, -8, 18, 14), pi, pi, true, D.stroke(const Color(0xFF8A7058), 1.5));
          c.restore();
        case 2: // green pepper
          c.drawArc(Rect.fromCircle(center: t.pos, radius: t.size), t.rot, pi * 1.2, false,
              D.stroke(const Color(0xFF2E9E3A), 4));
        default: // olive
          c.drawCircle(t.pos, t.size, D.stroke(const Color(0xFF2A2230), 4));
      }
    }
    // basil
    for (var i = 0; i < 4; i++) {
      final p = _c + Offset(cos(i * 1.9 + .5), sin(i * 1.9 + .5)) * 62;
      c.drawOval(Rect.fromCenter(center: p, width: 14, height: 7), D.fill(const Color(0xFF3DBA4E)));
    }
  }

  void _cutter(Canvas c, Offset p) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(_t * 12);
    c.drawCircle(Offset.zero, 16, D.fill(const Color(0xFFD8DEE8)));
    c.drawCircle(Offset.zero, 16, D.stroke(Pal.ink, 3));
    for (var i = 0; i < 4; i++) {
      final a = i * pi / 2;
      c.drawLine(Offset.zero, Offset(cos(a), sin(a)) * 12, D.stroke(const Color(0xFF9AA4B8), 2));
    }
    c.drawCircle(Offset.zero, 4, D.fill(Pal.red));
    c.restore();
  }

  void _knifeIcon(Canvas c, Offset p, Color col) {
    c.drawLine(p + const Offset(-7, 7), p + const Offset(7, -7), D.stroke(col, 4));
    c.drawCircle(p + const Offset(-7, 7), 3, D.fill(col));
  }

  void _kid(Canvas c, int i, Offset look) {
    final pos = _kidPos[i] + Offset(0, -sin(_bounce[i] * pi) * 12);
    final skin = Color.lerp(Pal.skin, Pal.skinDark, _skin[i])!;
    final f = _phase == 0 ? (host.time > 9 ? Face.shocked : (i.isEven ? Face.love : Face.happy)) : _face[i];
    // body / shoulders
    D.rrect(c, Rect.fromCenter(center: pos + const Offset(0, 46), width: 96, height: 50), 24, _kidCol[i],
        border: Pal.ink, borderWidth: 3.5);
    // arms holding fork & knife
    final wave = f == Face.angry ? sin(_t * 20) * 8 : 0.0;
    for (final sx in [-1.0, 1.0]) {
      final hand = pos + Offset(sx * 52, 20 + (sx > 0 ? wave : -wave));
      c.drawLine(hand + const Offset(0, 4), hand + const Offset(0, -26), D.stroke(const Color(0xFFB8C0D0), 4));
      if (sx < 0) {
        for (var k = -1; k <= 1; k++) {
          c.drawLine(hand + Offset(k * 3.0, -26), hand + Offset(k * 3.0, -34), D.stroke(const Color(0xFFB8C0D0), 2));
        }
      } else {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(hand.dx - 3, hand.dy - 38, 6, 14), const Radius.circular(3)),
            D.fill(const Color(0xFFB8C0D0)));
      }
      D.circle(c, hand, 8, skin, border: Pal.ink, borderWidth: 2.5);
    }
    // head
    D.circle(c, pos, 34, skin, border: Pal.ink, borderWidth: 3.5);
    final hair = _hairCol[i];
    switch (i) {
      case 0: // pigtails
        D.circle(c, pos + const Offset(-36, -8), 11, hair, border: Pal.ink, borderWidth: 2.5);
        D.circle(c, pos + const Offset(36, -8), 11, hair, border: Pal.ink, borderWidth: 2.5);
        c.drawArc(Rect.fromCircle(center: pos, radius: 34), pi * 1.05, pi * .9, false, D.stroke(hair, 12));
      case 1: // spiky
        final path = Path()..moveTo(pos.dx - 32, pos.dy - 10);
        for (var k = 0; k < 6; k++) {
          path
            ..lineTo(pos.dx - 28 + k * 11, pos.dy - 46 + (k.isEven ? 0 : 8))
            ..lineTo(pos.dx - 22 + k * 11, pos.dy - 30);
        }
        path
          ..lineTo(pos.dx + 32, pos.dy - 10)
          ..close();
        c.drawPath(path, D.fill(hair));
        c.drawPath(path, D.stroke(Pal.ink, 2.5));
      case 2: // cap
        c.drawArc(Rect.fromCircle(center: pos + const Offset(0, -4), radius: 34), pi, pi, true, D.fill(Pal.blue));
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx - 6, pos.dy - 10, 46, 8), const Radius.circular(4)),
            D.fill(Pal.blue));
        c.drawArc(Rect.fromCircle(center: pos + const Offset(0, -4), radius: 34), pi, pi, true, D.stroke(Pal.ink, 2.5));
      default: // bowl cut
        c.drawArc(Rect.fromCircle(center: pos + const Offset(0, -2), radius: 36), pi * .95, pi * 1.1, true, D.fill(hair));
    }
    final lk = look - pos;
    D.face(c, pos + const Offset(0, 6), 28, f, look: lk.distance < 1 ? Offset.zero : lk / lk.distance);
    // drool while waiting
    if (_phase == 0 && f == Face.love) {
      final dy = (_t * 20 + i * 7) % 10;
      c.drawOval(Rect.fromCenter(center: pos + Offset(10, 22 + dy), width: 5, height: 8), D.fill(const Color(0xCC8FDBFF)));
    }
    // share label
    if (_share[i] >= 0) {
      final pct = (_share[i] * 100).round();
      final lp = pos + Offset(0, i < 2 ? 88 : -64);
      final col = _share[i] == 0 ? Pal.red : ((pct - 25).abs() <= 3 ? Pal.lime : ((pct - 25).abs() <= 7 ? Pal.yellow : Pal.red));
      D.rrect(c, Rect.fromCenter(center: lp, width: 70, height: 30), 15, Pal.white, border: Pal.ink, borderWidth: 3);
      D.text(c, '$pct%', lp, size: 18, color: Color.lerp(col, Pal.ink, .35)!);
    }
    if (_phase == 2 && !_fair && f == Face.angry) {
      // steam puffs
      final k = (_t * 2 + i * .3) % 1;
      c.drawCircle(pos + Offset(-30 - k * 10, -30 - k * 20), 6 + k * 6, D.fill(Color.fromRGBO(255, 255, 255, 1 - k)));
      c.drawCircle(pos + Offset(30 + k * 10, -30 - k * 20), 6 + k * 6, D.fill(Color.fromRGBO(255, 255, 255, 1 - k)));
    }
  }
}

class _Top {
  _Top(this.kind, this.pos, this.size, this.rot);
  final int kind;
  final Offset pos;
  final double size;
  final double rot;
}

class _Piece {
  _Piece(this.key);
  final int key;
  int n = 0;
  double sx = 0, sy = 0;
  double share = 0;
  Offset centroid = Offset.zero;
  int kid = -1;
}
