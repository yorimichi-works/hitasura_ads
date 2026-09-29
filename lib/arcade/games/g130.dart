import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.130 Slide Puzzle — 3x3 picture sliding puzzle (8 tiles, 1 gap).
/// Shuffled by a short random walk so it is always solvable in 5–7 moves.
class G130 extends MiniGame {
  static const _x0 = 30.0, _y0 = 200.0, _step = 100.0;

  final List<int> _board = List<int>.generate(9, (i) => i); // cell -> tile, 8 = gap
  final List<Offset> _vis = List<Offset>.filled(9, Offset.zero);
  final List<double> _bump = List<double>.filled(9, 0);
  final List<bool> _wasRight = List<bool>.filled(9, true);
  final Map<int, int> _dist = {};
  late ui.Picture _pic;
  double _t = 0;
  double _idle = 0;
  int _moves = 0;
  bool _solved = false;
  double _solveT = 0;
  bool _failed = false;
  final List<_FallTile> _falls = [];
  int _optimal = 0;

  static int _enc(List<int> b) {
    var e = 0;
    for (var i = 8; i >= 0; i--) {
      e = e * 9 + b[i];
    }
    return e;
  }

  static List<int> _nbrs(int cell) {
    final r = cell ~/ 3, c = cell % 3;
    return [if (r > 0) cell - 3, if (r < 2) cell + 3, if (c > 0) cell - 1, if (c < 2) cell + 1];
  }

  @override
  void init() {
    // BFS distances from solved (depth <= 9)
    var frontier = <List<int>>[List<int>.generate(9, (i) => i)];
    _dist[_enc(frontier.first)] = 0;
    for (var d = 1; d <= 9; d++) {
      final next = <List<int>>[];
      for (final s in frontier) {
        final gap = s.indexOf(8);
        for (final nb in _nbrs(gap)) {
          final t = List<int>.of(s);
          t[gap] = t[nb];
          t[nb] = 8;
          final e = _enc(t);
          if (!_dist.containsKey(e)) {
            _dist[e] = d;
            next.add(t);
          }
        }
      }
      frontier = next;
    }
    // random walk; pick a state 5..7 moves from solved
    List<int>? chosen;
    var last = List<int>.generate(9, (i) => i);
    for (var tries = 0; tries < 50 && chosen == null; tries++) {
      final b = List<int>.generate(9, (i) => i);
      last = b;
      var gap = 8, prev = -1;
      for (var k = 0; k < 18; k++) {
        final opts = _nbrs(gap).where((x) => x != prev).toList();
        final nb = pick(opts);
        b[gap] = b[nb];
        b[nb] = 8;
        prev = gap;
        gap = nb;
        final d = _dist[_enc(b)];
        if (k > 8 && d != null && d >= 5 && d <= 7 && chance(.5)) {
          chosen = List<int>.of(b);
          break;
        }
      }
    }
    chosen ??= last;
    _board.setAll(0, chosen);
    _optimal = _dist[_enc(_board)] ?? 7;
    for (var i = 0; i < 9; i++) {
      final tile = _board[i];
      _vis[tile] = _cellPos(i) + Offset(rand(-200, 200), rand(-500, -300));
      _wasRight[tile] = tile == i;
    }
    _pic = _recordPicture();
  }

  Offset _cellPos(int cell) => Offset(_x0 + (cell % 3) * _step, _y0 + (cell ~/ 3) * _step);

  int _cellAt(Offset p) {
    final c = ((p.dx - _x0) / _step).floor();
    final r = ((p.dy - _y0) / _step).floor();
    if (c < 0 || r < 0 || c > 2 || r > 2) return -1;
    return r * 3 + c;
  }

  bool get _isSolved {
    for (var i = 0; i < 9; i++) {
      if (_board[i] != i) return false;
    }
    return true;
  }

  // ----------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    if (_solved || host.finished) return;
    final cell = _cellAt(p);
    if (cell < 0) return;
    _slideFrom(cell);
  }

  @override
  void onKey(String key, bool down) {
    if (!down || _solved) return;
    final gap = _board.indexOf(8);
    final r = gap ~/ 3, c = gap % 3;
    switch (key) {
      case 'left':
        if (c < 2) _slideFrom(gap + 1);
      case 'right':
        if (c > 0) _slideFrom(gap - 1);
      case 'up':
        if (r < 2) _slideFrom(gap + 3);
      case 'down':
        if (r > 0) _slideFrom(gap - 3);
    }
  }

  void _slideFrom(int cell) {
    var gap = _board.indexOf(8);
    if (cell == gap) return;
    final sameRow = cell ~/ 3 == gap ~/ 3, sameCol = cell % 3 == gap % 3;
    if (!sameRow && !sameCol) {
      _bump[_board[cell]] = -1;
      host.sfx(Sfx.boing, volume: .4, rate: 1.5);
      return;
    }
    final dir = sameRow ? ((cell > gap) ? 1 : -1) : ((cell > gap) ? 3 : -3);
    var n = 0;
    while (gap != cell) {
      final nx = gap + dir;
      _board[gap] = _board[nx];
      _board[nx] = 8;
      _bump[_board[gap]] = 1;
      gap = nx;
      n++;
    }
    _moves += n;
    _idle = 0;
    host.sfx(Sfx.swipe, volume: .6, rate: 1.1 + rand(0, .2));
    host.sfx(Sfx.click, volume: .7);
    // newly correct tiles
    var right = 0;
    for (var i = 0; i < 9; i++) {
      final tile = _board[i];
      if (tile == 8) continue;
      final ok = tile == i;
      if (ok) right++;
      if (ok && !_wasRight[tile]) {
        host.fx.sparkle(_cellPos(i) + const Offset(48, 48), count: 6, radius: 40, color: Pal.yellow);
        host.sfx(Sfx.ding, volume: .5, rate: 1 + right * .07);
      }
      _wasRight[tile] = ok;
    }
    if (_isSolved) _solve();
  }

  void _solve() {
    _solved = true;
    _solveT = 0;
    _vis[8] = _cellPos(8) + const Offset(0, -420);
    host.sfx(Sfx.fanfare);
    host.sfx(Sfx.sparkle, volume: .8);
    host.shake(6);
    host.fx.confetti(count: 60);
    host.fx.pop(host.tr('perfect', 'PERFECT!'), const Offset(180, 160), color: Pal.yellow, size: 38, life: 1.2);
    final extra = _moves - _optimal;
    host.win(stars: extra <= 4 && host.time < 14 ? 3 : (host.time < 20 ? 2 : 1));
  }

  @override
  void onTimeUp() {
    _failed = true;
    for (var i = 0; i < 9; i++) {
      final tile = _board[i];
      if (tile == 8) continue;
      _falls.add(_FallTile(tile, _vis[tile], Offset(rand(-120, 120), rand(-420, -200)), rand(-5, 5)));
    }
    host.sfx(Sfx.crash);
    host.shake(12);
    host.lose();
  }

  // ---------------------------------------------------------- update ---

  @override
  void update(double dt) {
    _t += dt;
    _idle += dt;
    for (var i = 0; i < 9; i++) {
      final tile = _board[i];
      if (tile == 8 && !_solved) continue;
      final target = _cellPos(i);
      final before = _vis[tile];
      _vis[tile] = M.approachO(before, target, _t < .6 ? 9 : 26, dt);
      _bump[tile] = M.approach(_bump[tile], 0, 8, dt);
    }
    if (_solved) _solveT += dt;
    for (final f in _falls) {
      f.vel = f.vel + Offset(0, 1400 * dt);
      f.pos += f.vel * dt;
      f.rot += f.spin * dt;
    }
  }

  // ---------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    // lo-fi dusk room
    D.gradientBg(c, const [Color(0xFF3B2A5C), Color(0xFF8E5C8A), Color(0xFFF2A07B)]);
    // window with city lights
    D.rrect(c, const Rect.fromLTWH(208, 52, 126, 118), 8, const Color(0xFF2A1F46), border: const Color(0xFF1A1230), borderWidth: 6);
    for (var i = 0; i < 6; i++) {
      final h = 30.0 + (i * 37) % 50;
      c.drawRect(Rect.fromLTWH(214 + i * 20.0, 164 - h, 16, h), D.fill(const Color(0xFF1C1535)));
      for (var k = 0; k < 3; k++) {
        if ((i + k + (_t * .5).floor()) % 3 != 0) {
          c.drawRect(Rect.fromLTWH(218 + i * 20.0, 168 - h + k * 9, 4, 4), D.fill(const Color(0xFFFFD27A)));
        }
      }
    }
    c.drawCircle(const Offset(305, 78), 12, D.fill(const Color(0xFFFFF1C7)));
    c.drawLine(const Offset(271, 52), const Offset(271, 170), D.stroke(const Color(0xFF1A1230), 5));
    // tiny "only 3% solve" sticker (numbers only)
    c.save();
    c.translate(70, 108);
    c.rotate(-.18 + sin(_t * 3) * .04);
    D.star(c, Offset.zero, 50, Pal.red, border: Pal.ink);
    D.text(c, '3%', const Offset(0, 2), size: 24, color: Pal.white, stroke: Pal.ink, strokeWidth: 5);
    c.restore();
    // move counter
    D.rrect(c, const Rect.fromLTWH(122, 70, 76, 58), 14, const Color(0x55000000));
    D.text(c, '$_moves', const Offset(160, 92), size: 28, color: Pal.white);
    D.text(c, host.tr('moves', 'Moves'), const Offset(160, 117), size: 12, color: const Color(0xCCFFFFFF));

    // desk
    c.drawRect(const Rect.fromLTWH(0, 530, 360, 110), D.fill(const Color(0xFF6B3F2A)));
    c.drawRect(const Rect.fromLTWH(0, 530, 360, 8), D.fill(const Color(0xFF8B5638)));
    _mug(c, const Offset(300, 580));
    _plant(c, const Offset(52, 590));

    // board frame
    const frame = Rect.fromLTWH(_x0 - 14, _y0 - 14, 300 + 24, 300 + 24);
    D.rrect(c, frame.shift(const Offset(0, 8)), 22, const Color(0x66000000));
    D.rrect(c, frame, 22, const Color(0xFFC98A55), border: Pal.ink, borderWidth: 4);
    D.rrect(c, frame.deflate(10), 12, const Color(0xFF5A3522));
    // gap hint: faint picture in the empty slot
    final gap = _board.indexOf(8);
    if (!_solved) {
      final gp = _cellPos(gap);
      D.rrect(c, Rect.fromLTWH(gp.dx + 2, gp.dy + 2, 92, 92), 10, const Color(0x33000000));
    }
    // hint arrow after being idle
    final hintCell = _hintCell();
    // tiles
    if (!_failed) {
      for (var tile = 0; tile < 9; tile++) {
        if (tile == 8 && !_solved) continue;
        _drawTile(c, tile, _vis[tile], 0, hint: tile == (hintCell >= 0 ? _board[hintCell] : -1));
      }
    } else {
      for (final f in _falls) {
        _drawTile(c, f.tile, f.pos, f.rot);
      }
    }
    if (_solved) {
      // shine sweep
      final k = ((_solveT - .45) / .6).clamp(0.0, 1.0);
      if (k > 0 && k < 1) {
        c.save();
        c.clipRect(const Rect.fromLTWH(_x0, _y0, 296, 296));
        final x = _x0 - 100 + k * 500;
        c.drawPath(
            Path()
              ..moveTo(x, _y0)
              ..lineTo(x + 50, _y0)
              ..lineTo(x - 50, _y0 + 300)
              ..lineTo(x - 100, _y0 + 300)
              ..close(),
            D.fill(const Color(0x88FFFFFF)));
        c.restore();
      }
      if (_solveT > .5) D.rays(c, const Offset(180, 350), 300, const Color(0x18FFFFFF), count: 14, t: _t);
    }
    if (hintCell >= 0 && !host.finished) {
      final p = _cellPos(hintCell) + const Offset(48, 48);
      D.hand(c, p, _t, size: 40);
    }
    // preview thumbnail
    c.save();
    c.translate(16, 546);
    D.rrect(c, const Rect.fromLTWH(-4, -4, 74, 74), 8, Pal.white, border: Pal.ink, borderWidth: 3);
    c.scale(66 / 300);
    c.drawPicture(_pic);
    c.restore();

    // rage face
    final rage = (host.time / host.duration).clamp(0.0, 1.0);
    final face = _solved
        ? Face.love
        : _failed
            ? Face.cry
            : rage < .35
                ? Face.smug
                : rage < .7
                    ? Face.neutral
                    : Face.angry;
    final fc = Color.lerp(Pal.yellow, Pal.red, _solved ? 0 : rage)!;
    final fp = Offset(180 + (rage > .7 && !_solved ? sin(_t * 40) * 2 : 0), 580);
    D.blob(c, fp, 30, fc, face: face, squash: 1 + sin(_t * 5) * .04);
    if (rage > .7 && !_solved && !_failed) {
      for (var i = 0; i < 3; i++) {
        final a = -pi / 2 + (i - 1) * .6;
        final q = fp + Offset(cos(a), sin(a)) * (42 + M.wave(_t, 3) * 6);
        D.line(c, q, q + Offset(cos(a), sin(a)) * 8, Pal.red, 4);
      }
    }
  }

  int _hintCell() {
    if (_solved || host.finished) return -1;
    if (!(_idle > 3.5 || (host.time < 2.4 && _moves == 0))) return -1;
    final gap = _board.indexOf(8);
    final cur = _dist[_enc(_board)];
    if (cur == null) return -1;
    for (final nb in _nbrs(gap)) {
      final t = List<int>.of(_board);
      t[gap] = t[nb];
      t[nb] = 8;
      final d = _dist[_enc(t)];
      if (d != null && d < cur) return nb;
    }
    return -1;
  }

  void _drawTile(Canvas c, int tile, Offset pos, double rot, {bool hint = false}) {
    final k = _solved ? M.easeInOut((_solveT / .4).clamp(0.0, 1.0)) : 0.0;
    final size = 96 + 4 * k;
    final b = _bump[tile];
    final s = 1 + (b > 0 ? sin(b * pi) * .06 : b * .04 * sin(_t * 50));
    c.save();
    c.translate(pos.dx + 48, pos.dy + 48);
    if (rot != 0) c.rotate(rot);
    c.scale(s);
    c.translate(-48, -48);
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size, size), Radius.circular(10 * (1 - k)));
    if (k < 1) c.drawRRect(r.shift(const Offset(0, 5)), D.fill(Color.fromRGBO(0, 0, 0, .35 * (1 - k))));
    c.save();
    c.clipRRect(r);
    c.translate(-(tile % 3) * 100.0, -(tile ~/ 3) * 100.0);
    c.drawPicture(_pic);
    c.restore();
    if (k < 1) {
      final a = 1 - k;
      c.drawRRect(r, D.stroke(Color.fromRGBO(255, 255, 255, .85 * a), 3));
      c.drawRRect(r.deflate(1), D.stroke(Color.fromRGBO(27, 21, 48, .7 * a), 1.5));
      if (tile < 8) {
        final right = _board.indexOf(tile) == tile;
        D.circle(c, const Offset(15, 15), 11, (right ? Pal.green : Pal.ink).withValues(alpha: .9 * a),
            border: Color.fromRGBO(255, 255, 255, a), borderWidth: 2);
        D.text(c, '${tile + 1}', const Offset(15, 15.5), size: 14, color: Color.fromRGBO(255, 255, 255, a));
      }
    }
    if (hint) {
      c.drawRRect(r, D.stroke(Color.fromRGBO(255, 230, 80, M.wave(_t, 3)), 5));
    }
    c.restore();
  }

  void _mug(Canvas c, Offset o) {
    for (var i = 0; i < 3; i++) {
      final y = (_t * 18 + i * 14) % 42;
      final a = (1 - y / 42) * .5;
      c.drawCircle(o + Offset(-6 + i * 6 + sin(_t * 2 + i) * 4, -36 - y), 6 + y * .12, D.fill(Color.fromRGBO(255, 255, 255, a)));
    }
    c.drawCircle(o + const Offset(22, 2), 11, D.stroke(Pal.ink, 9));
    c.drawCircle(o + const Offset(22, 2), 11, D.stroke(const Color(0xFFEFE6D8), 5));
    D.rrect(c, Rect.fromCenter(center: o, width: 44, height: 50), 10, const Color(0xFFEFE6D8), border: Pal.ink, borderWidth: 3);
    D.heart(c, o + const Offset(0, 2), 16, Pal.pink);
  }

  void _plant(Canvas c, Offset o) {
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + (i - 2) * .45 + sin(_t * 1.5 + i) * .05;
      final tip = o + Offset(cos(a) * 44, sin(a) * 44);
      c.drawPath(
          Path()
            ..moveTo(o.dx, o.dy - 14)
            ..quadraticBezierTo(o.dx + cos(a + .5) * 30, o.dy - 14 + sin(a + .5) * 30, tip.dx, tip.dy)
            ..quadraticBezierTo(o.dx + cos(a - .5) * 30, o.dy - 14 + sin(a - .5) * 30, o.dx, o.dy - 14),
          D.fill(i.isEven ? const Color(0xFF3FAF5A) : const Color(0xFF2E8C47)));
    }
    c.drawPath(
        Path()
          ..moveTo(o.dx - 24, o.dy - 16)
          ..lineTo(o.dx + 24, o.dy - 16)
          ..lineTo(o.dx + 17, o.dy + 22)
          ..lineTo(o.dx - 17, o.dy + 22)
          ..close(),
        D.fill(const Color(0xFFE07A4A)));
  }

  // ------------------------------------------------------- the picture ---

  ui.Picture _recordPicture() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const r = Rect.fromLTWH(0, 0, 300, 300);
    c.clipRect(r);
    D.gradientBg(c, const [Color(0xFF6EC6FF), Color(0xFFBFE6FF), Color(0xFFFFE0EE)], rect: r);
    // sun (top-left)
    D.rays(c, const Offset(52, 50), 70, const Color(0x55FFE066), count: 12, width: .45);
    D.circle(c, const Offset(52, 50), 30, Pal.yellow, border: Pal.ink, borderWidth: 3);
    D.face(c, const Offset(52, 52), 26, Face.happy);
    // rainbow (top-middle)
    const bands = [Pal.red, Pal.orange, Pal.yellow, Pal.green, Pal.sky, Pal.purple];
    for (var i = 0; i < bands.length; i++) {
      c.drawArc(Rect.fromCircle(center: const Offset(170, 150), radius: 118.0 - i * 9), pi, pi, false,
          Paint()
            ..color = bands[i]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9);
    }
    D.cloud(c, const Offset(252, 128), 50);
    D.cloud(c, const Offset(250, 44), 40);
    // bird (top-right)
    c.drawPath(
        Path()
          ..moveTo(236, 72)
          ..quadraticBezierTo(246, 62, 256, 72)
          ..quadraticBezierTo(266, 62, 276, 72),
        D.stroke(Pal.ink, 3));
    // hills
    c.drawOval(const Rect.fromLTWH(-80, 190, 280, 180), D.fill(const Color(0xFF7ED957)));
    c.drawOval(const Rect.fromLTWH(120, 200, 260, 170), D.fill(const Color(0xFF5CC24A)));
    // tree (middle-left)
    D.tree(c, const Offset(40, 232), 110, leaf: const Color(0xFF2FA84F));
    c.drawCircle(const Offset(28, 150), 6, D.fill(Pal.red));
    c.drawCircle(const Offset(52, 136), 6, D.fill(Pal.red));
    // balloon (middle-right)
    c.drawLine(const Offset(262, 170), const Offset(250, 240), D.stroke(Pal.ink, 2));
    c.drawOval(Rect.fromCenter(center: const Offset(262, 150), width: 42, height: 50), D.fill(Pal.pink));
    c.drawOval(Rect.fromCenter(center: const Offset(262, 150), width: 42, height: 50), D.stroke(Pal.ink, 3));
    c.drawOval(Rect.fromCenter(center: const Offset(254, 140), width: 10, height: 16), D.fill(const Color(0x88FFFFFF)));
    // cat (center)
    const cat = Color(0xFFFFA64D);
    c.drawOval(Rect.fromCenter(center: const Offset(150, 255), width: 110, height: 90), D.fill(cat));
    c.drawOval(Rect.fromCenter(center: const Offset(150, 255), width: 110, height: 90), D.stroke(Pal.ink, 3.5));
    c.drawOval(Rect.fromCenter(center: const Offset(150, 262), width: 60, height: 60), D.fill(const Color(0xFFFFE3C2)));
    for (final s in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(150 + s * 58, 128)
        ..lineTo(150 + s * 50, 88)
        ..lineTo(150 + s * 20, 116)
        ..close();
      c.drawPath(ear, D.fill(cat));
      c.drawPath(ear, D.stroke(Pal.ink, 3.5));
    }
    c.drawCircle(const Offset(150, 160), 62, D.fill(cat));
    c.drawCircle(const Offset(150, 160), 62, D.stroke(Pal.ink, 3.5));
    for (final s in [-1.0, 1.0]) {
      c.drawLine(Offset(150 + s * 10, 108), Offset(150 + s * 14, 124), D.stroke(const Color(0xFFD9772A), 5));
      for (var k = -1; k <= 1; k++) {
        c.drawLine(Offset(150 + s * 30, 176 + k * 7.0), Offset(150 + s * 64, 172 + k * 10.0), D.stroke(Pal.ink, 2));
      }
    }
    D.face(c, const Offset(150, 162), 50, Face.happy);
    c.drawPath(
        Path()
          ..moveTo(143, 168)
          ..lineTo(157, 168)
          ..lineTo(150, 175)
          ..close(),
        D.fill(Pal.pink));
    // flowers (bottom-left)
    for (var i = 0; i < 4; i++) {
      final p = Offset(20 + i * 22.0, 262 + (i % 2) * 18.0);
      c.drawLine(p, p + const Offset(0, 30), D.stroke(const Color(0xFF2E8C47), 3));
      for (var k = 0; k < 5; k++) {
        final a = k * pi * 2 / 5;
        c.drawCircle(p + Offset(cos(a), sin(a)) * 6, 5, D.fill([Pal.pink, Pal.yellow, Pal.white, Pal.purple][i]));
      }
      c.drawCircle(p, 4, D.fill(Pal.orange));
    }
    // mushroom house (bottom-right, the missing piece)
    D.rrect(c, const Rect.fromLTWH(236, 250, 40, 40), 8, Pal.cream, border: Pal.ink, borderWidth: 3);
    c.drawArc(const Rect.fromLTWH(222, 220, 68, 60), pi, pi, true, D.fill(Pal.red));
    c.drawArc(const Rect.fromLTWH(222, 220, 68, 60), pi, pi, true, D.stroke(Pal.ink, 3));
    for (final q in const [Offset(240, 236), Offset(262, 228), Offset(276, 242)]) {
      c.drawCircle(q, 5, D.fill(Pal.white));
    }
    D.rrect(c, const Rect.fromLTWH(250, 266, 14, 24), 6, Pal.brown);
    return rec.endRecording();
  }
}

class _FallTile {
  _FallTile(this.tile, this.pos, this.vel, this.spin);
  final int tile;
  Offset pos;
  Offset vel;
  double spin;
  double rot = 0;
}
