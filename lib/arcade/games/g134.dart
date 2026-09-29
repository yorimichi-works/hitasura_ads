import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.134 Block Blast — drag polyomino pieces onto an 8x8 board, clear rows
/// and columns, chain combos. Reach the score target before the ad ends.
class G134 extends MiniGame {
  static const _n = 8;
  static const _cs = 38.0;
  static const _x0 = 28.0, _y0 = 136.0;
  static const _target = 1200;
  static const _trayY = 530.0;
  static const _trayX = [64.0, 180.0, 296.0];
  static const _trayCs = 22.0;

  static const _colors = <Color>[
    Color(0xFFFF4D6D),
    Color(0xFFFF9F1C),
    Color(0xFFFFD23F),
    Color(0xFF3DDC84),
    Color(0xFF26C6DA),
    Color(0xFF4D7CFF),
    Color(0xFFB45CFF),
  ];

  static const _shapes = <List<(int, int)>>[
    [(0, 0)],
    [(0, 0), (0, 1)],
    [(0, 0), (1, 0)],
    [(0, 0), (0, 1), (0, 2)],
    [(0, 0), (1, 0), (2, 0)],
    [(0, 0), (0, 1), (0, 2), (0, 3)],
    [(0, 0), (1, 0), (2, 0), (3, 0)],
    [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)],
    [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)],
    [(0, 0), (0, 1), (1, 0), (1, 1)],
    [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (2, 0), (2, 1), (2, 2)],
    [(0, 0), (1, 0), (1, 1)],
    [(0, 1), (1, 0), (1, 1)],
    [(0, 0), (0, 1), (1, 0)],
    [(0, 0), (0, 1), (1, 1)],
    [(0, 0), (1, 0), (2, 0), (2, 1)],
    [(0, 0), (0, 1), (0, 2), (1, 1)],
    [(0, 1), (1, 0), (1, 1), (1, 2)],
    [(0, 0), (0, 1), (1, 1), (1, 2)],
    [(0, 1), (1, 1), (2, 1), (2, 0)],
  ];

  final List<int> _b = List<int>.filled(_n * _n, -1);
  final List<double> _pop = List<double>.filled(_n * _n, 0);
  final List<_Piece?> _tray = [null, null, null];
  final List<_Dying> _dying = [];
  int _drag = -1;
  Offset _dragPos = Offset.zero;
  int _ghostR = -99, _ghostC = -99;
  bool _ghostOk = false;
  Set<int> _ghostLines = {};
  int _streak = 0;
  int _score = 0;
  double _scoreShown = 0;
  double _scoreBump = 0;
  double _t = 0;
  String _word = '';
  double _wordT = 9;
  Color _wordCol = Pal.yellow;
  bool _over = false;
  double _refill = 0;

  // ------------------------------------------------------------ setup ---

  @override
  void init() {
    // pre-filled "almost there" board (the classic ad setup)
    for (var r = 5; r < _n; r++) {
      final holes = <int>{randInt(_n)};
      if (chance(.5)) holes.add(randInt(_n));
      for (var c = 0; c < _n; c++) {
        if (!holes.contains(c)) _b[r * _n + c] = randInt(_colors.length);
      }
    }
    for (var r = 1; r < 5; r++) {
      for (var c = 0; c < _n; c++) {
        if (chance(.18 + r * .06)) _b[r * _n + c] = randInt(_colors.length);
      }
    }
    // no full lines at start
    for (var r = 0; r < _n; r++) {
      if (List.generate(_n, (c) => _b[r * _n + c]).every((v) => v >= 0)) _b[r * _n + randInt(_n)] = -1;
    }
    for (var c = 0; c < _n; c++) {
      if (List.generate(_n, (r) => _b[r * _n + c]).every((v) => v >= 0)) _b[randInt(5) * _n + c] = -1;
    }
    _deal();
  }

  void _deal() {
    for (var i = 0; i < 3; i++) {
      _tray[i] = _Piece(_chooseShape(), randInt(_colors.length))..enter = 1 + i * .25;
    }
    _refill = 1;
    host.sfx(Sfx.whoosh, volume: .5, rate: 1.2);
  }

  int _chooseShape() {
    final fits = <int>[], clears = <int>[];
    for (var s = 0; s < _shapes.length; s++) {
      var fit = false, clr = false;
      for (var r = 0; r < _n && !clr; r++) {
        for (var c = 0; c < _n && !clr; c++) {
          if (_canPlace(_shapes[s], r, c)) {
            fit = true;
            if (_linesIf(_shapes[s], r, c).isNotEmpty) clr = true;
          }
        }
      }
      if (fit) fits.add(s);
      if (clr) clears.add(s);
    }
    if (clears.isNotEmpty && chance(.7)) return pick(clears);
    // avoid too many giant pieces
    final small = fits.where((s) => _shapes[s].length <= 4).toList();
    if (small.isNotEmpty && chance(.75)) return pick(small);
    if (fits.isNotEmpty) return pick(fits);
    return randInt(_shapes.length);
  }

  bool _canPlace(List<(int, int)> sh, int r, int c) {
    for (final (dr, dc) in sh) {
      final rr = r + dr, cc = c + dc;
      if (rr < 0 || cc < 0 || rr >= _n || cc >= _n) return false;
      if (_b[rr * _n + cc] >= 0) return false;
    }
    return true;
  }

  /// Lines completed if [sh] is placed at r,c. Encoded rows 0..7, cols 8..15.
  Set<int> _linesIf(List<(int, int)> sh, int r, int c) {
    final filled = <int>{for (final (dr, dc) in sh) (r + dr) * _n + c + dc};
    bool full(int i) => _b[i] >= 0 || filled.contains(i);
    final out = <int>{};
    for (final (dr, dc) in sh) {
      final rr = r + dr, cc = c + dc;
      if (List.generate(_n, (k) => rr * _n + k).every(full)) out.add(rr);
      if (List.generate(_n, (k) => k * _n + cc).every(full)) out.add(_n + cc);
    }
    return out;
  }

  bool _anyMove() {
    for (final p in _tray) {
      if (p == null) continue;
      for (var r = 0; r < _n; r++) {
        for (var c = 0; c < _n; c++) {
          if (_canPlace(_shapes[p.shape], r, c)) return true;
        }
      }
    }
    return false;
  }

  // ------------------------------------------------------------ input ---

  (int, int) _pieceSize(int shape) {
    var h = 0, w = 0;
    for (final (r, c) in _shapes[shape]) {
      h = max(h, r + 1);
      w = max(w, c + 1);
    }
    return (h, w);
  }

  @override
  void onDown(Offset p) {
    if (host.finished || _over) return;
    for (var i = 0; i < 3; i++) {
      if (_tray[i] == null) continue;
      if ((p - Offset(_trayX[i], _trayY)).distance < 60) {
        _drag = i;
        _dragPos = p;
        host.sfx(Sfx.pickup, volume: .5, rate: 1.2);
        _updateGhost();
        return;
      }
    }
  }

  @override
  void onMove(Offset p) {
    if (_drag < 0) return;
    _dragPos = p;
    final r0 = _ghostR, c0 = _ghostC;
    _updateGhost();
    if (_ghostOk && (r0 != _ghostR || c0 != _ghostC)) host.sfx(Sfx.tick, volume: .25, rate: 1.4);
  }

  Offset get _dragTopLeft {
    final (h, w) = _pieceSize(_tray[_drag]!.shape);
    final ctr = _dragPos + const Offset(0, -86);
    return ctr - Offset(w * _cs / 2, h * _cs / 2);
  }

  void _updateGhost() {
    final tl = _dragTopLeft;
    _ghostC = ((tl.dx - _x0) / _cs).round();
    _ghostR = ((tl.dy - _y0) / _cs).round();
    final sh = _shapes[_tray[_drag]!.shape];
    _ghostOk = _canPlace(sh, _ghostR, _ghostC);
    _ghostLines = _ghostOk ? _linesIf(sh, _ghostR, _ghostC) : {};
  }

  @override
  void onUp(Offset p) {
    if (_drag < 0) return;
    _dragPos = p;
    _updateGhost();
    final i = _drag;
    _drag = -1;
    if (_ghostOk) {
      _place(i, _ghostR, _ghostC);
    } else {
      _tray[i]!.back = 1;
      host.sfx(Sfx.boing, volume: .4, rate: 1.3);
    }
  }

  void _place(int ti, int r, int c) {
    final piece = _tray[ti]!;
    final sh = _shapes[piece.shape];
    final lines = _linesIf(sh, r, c);
    for (final (dr, dc) in sh) {
      final i = (r + dr) * _n + c + dc;
      _b[i] = piece.color;
      _pop[i] = 1;
    }
    _tray[ti] = null;
    _score += sh.length * 10;
    host.sfx(Sfx.thud, volume: .8, rate: 1.1);
    host.sfx(Sfx.pop, volume: .5, rate: .9 + sh.length * .05);
    final center = Offset(_x0 + (c + .5) * _cs, _y0 + (r + .5) * _cs);
    if (lines.isNotEmpty) {
      _streak++;
      final base = const [0, 100, 300, 600, 1000, 1500, 2100][min(lines.length, 6)];
      final mult = 1 + (_streak - 1) * .5;
      final pts = (base * mult).round();
      _score += pts;
      final cleared = <int>{};
      for (final l in lines) {
        for (var k = 0; k < _n; k++) {
          cleared.add(l < _n ? l * _n + k : k * _n + (l - _n));
        }
      }
      for (final i in cleared) {
        final cp = Offset(_x0 + (i % _n + .5) * _cs, _y0 + (i ~/ _n + .5) * _cs);
        _dying.add(_Dying(i, _b[i], -(cp - center).distance / 900));
        _b[i] = -1;
      }
      host.fx.pop('+$pts', center + const Offset(0, -30), color: Pal.yellow, size: 30);
      host.sfx(lines.length >= 2 ? Sfx.explode : Sfx.explodeSmall, volume: .8);
      host.sfx(Sfx.combo, rate: 1 + (_streak - 1) * .15);
      host.shake(4.0 + lines.length * 3 + _streak);
      host.hitStop(.05);
      if (lines.length >= 2) host.flash(const Color(0x55FFFFFF));
      final lvl = lines.length + (_streak - 1);
      _word = switch (lvl) {
        1 => host.tr('good', 'Good!'),
        2 => host.tr('great', 'Great!'),
        3 => host.tr('excellent', 'Excellent!'),
        _ => host.tr('unbelievable', 'Unbelievable!'),
      };
      _wordCol = [Pal.sky, Pal.lime, Pal.yellow, Pal.pink, Pal.orange][min(lvl, 4)];
      _wordT = 0;
      host.punch(.02 + lines.length * .01);
    } else {
      _streak = 0;
    }
    _scoreBump = 1;
    if (_score >= _target && !host.finished) {
      host.sfx(Sfx.fanfare);
      host.fx.confetti(count: 70);
      final left = host.timeLeft;
      host.win(stars: left > 9 ? 3 : (left > 4 ? 2 : 1));
      return;
    }
    if (_tray.every((p) => p == null)) _deal();
    if (!_anyMove()) {
      _over = true;
      host.sfx(Sfx.buzzer);
      host.fx.pop(host.tr('no_moves', 'No moves!'), const Offset(180, 300), color: Pal.red, size: 34, life: 1.2);
      host.shake(8);
      host.lose();
    }
  }

  // ----------------------------------------------------------- update ---

  @override
  void update(double dt) {
    _t += dt;
    _wordT += dt;
    for (var i = 0; i < _n * _n; i++) {
      _pop[i] = M.approach(_pop[i], 0, 7, dt);
    }
    for (final d in _dying) {
      final before = d.t;
      d.t += dt;
      if (before < 0 && d.t >= 0) {
        final cp = Offset(_x0 + (d.i % _n + .5) * _cs, _y0 + (d.i ~/ _n + .5) * _cs);
        host.fx.burst(cp, _colors[d.color], count: 5, speed: 220, size: 7, shape: PartShape.square, gravity: 700, life: .7);
      }
    }
    _dying.removeWhere((d) => d.t > .3);
    for (final p in _tray) {
      if (p == null) continue;
      p.enter = max(0, p.enter - dt * 5);
      p.back = M.approach(p.back, 0, 8, dt);
    }
    _refill = M.approach(_refill, 0, 4, dt);
    _scoreShown = M.approach(_scoreShown, _score.toDouble(), 9, dt);
    _scoreBump = M.approach(_scoreBump, 0, 6, dt);
  }

  // ----------------------------------------------------------- render ---

  static void _block(Canvas c, Rect r, Color col, {double alpha = 1}) {
    final a = alpha;
    final base = col.withValues(alpha: a);
    final light = Color.lerp(col, Pal.white, .45)!.withValues(alpha: a);
    final dark = Color.lerp(col, Pal.ink, .4)!.withValues(alpha: a);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * .16));
    c.drawRRect(rr, D.fill(dark));
    final inner = RRect.fromRectAndRadius(Rect.fromLTRB(r.left, r.top, r.right, r.bottom - r.height * .12),
        Radius.circular(r.width * .16));
    c.drawRRect(inner, D.fill(base));
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(r.left + r.width * .14, r.top + r.height * .1, r.width * .72, r.height * .22),
            Radius.circular(r.width * .1)),
        D.fill(light));
    c.drawRRect(rr, D.stroke(Color.fromRGBO(0, 0, 0, .35 * a), 1.2));
  }

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF1E2A78), Color(0xFF2B1B6B), Color(0xFF140E3A)]);
    c.drawCircle(const Offset(180, 290), 260, Paint()..shader = _glow);
    for (var i = 0; i < 18; i++) {
      final y = (i * 57 + _t * 25) % 680 - 20;
      final x = (i * 83.0) % 360;
      c.drawRect(Rect.fromCenter(center: Offset(x, 660 - y), width: 6, height: 6), D.fill(const Color(0x33FFFFFF)));
    }
    // score header
    D.rrect(c, const Rect.fromLTWH(70, 44, 220, 78), 20, const Color(0x55000000));
    _crown(c, const Offset(110, 66));
    D.text(c, '$_target', const Offset(142, 66), size: 16, color: Pal.gold, anchor: Alignment.centerLeft);
    D.text(c, '${_scoreShown.round()}', const Offset(180, 90),
        size: 34 * (1 + _scoreBump * .15), color: Pal.white, stroke: Pal.ink, strokeWidth: 6);
    D.bar(c, const Rect.fromLTWH(90, 110, 180, 7), _scoreShown / _target, Pal.gold);

    // board
    const br = Rect.fromLTWH(_x0 - 8, _y0 - 8, _cs * _n + 16, _cs * _n + 16);
    D.rrect(c, br, 16, const Color(0xFF0F1440), border: const Color(0xFF3C4BB0), borderWidth: 3);
    for (var i = 0; i < _n * _n; i++) {
      final r = Rect.fromLTWH(_x0 + (i % _n) * _cs + 1.5, _y0 + (i ~/ _n) * _cs + 1.5, _cs - 3, _cs - 3);
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(5)), D.fill(const Color(0xFF1C245E)));
    }
    // ghost-line highlight
    final dragPiece = _drag >= 0 ? _tray[_drag] : null;
    for (var i = 0; i < _n * _n; i++) {
      var col = _b[i];
      final r0 = i ~/ _n, c0 = i % _n;
      final inLine = _ghostLines.contains(r0) || _ghostLines.contains(_n + c0);
      final rect = Rect.fromLTWH(_x0 + c0 * _cs + 1.5, _y0 + r0 * _cs + 1.5, _cs - 3, _cs - 3);
      if (col < 0) continue;
      if (dragPiece != null && inLine) col = dragPiece.color;
      final s = 1 + _pop[i] * .25;
      _block(c, Rect.fromCenter(center: rect.center, width: rect.width * s, height: rect.height * s), _colors[col]);
      if (dragPiece != null && inLine) {
        c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)),
            D.fill(Color.fromRGBO(255, 255, 255, .25 + .2 * M.wave(_t, 4))));
      }
    }
    // ghost
    if (dragPiece != null && _ghostOk) {
      for (final (dr, dc) in _shapes[dragPiece.shape]) {
        final rect = Rect.fromLTWH(_x0 + (_ghostC + dc) * _cs + 1.5, _y0 + (_ghostR + dr) * _cs + 1.5, _cs - 3, _cs - 3);
        _block(c, rect, _colors[dragPiece.color], alpha: .4);
      }
    }
    // dying cells
    for (final d in _dying) {
      final rect = Rect.fromLTWH(_x0 + (d.i % _n) * _cs + 1.5, _y0 + (d.i ~/ _n) * _cs + 1.5, _cs - 3, _cs - 3);
      if (d.t < 0) {
        _block(c, rect, _colors[d.color]);
        continue;
      }
      final k = d.t / .3;
      final s = 1 + k * .4;
      _block(c, Rect.fromCenter(center: rect.center, width: rect.width * s, height: rect.height * s), Pal.white,
          alpha: (1 - k).clamp(0.0, 1.0));
    }

    // tray
    D.rrect(c, const Rect.fromLTWH(12, 466, 336, 128), 22, const Color(0x44000000));
    for (var i = 0; i < 3; i++) {
      final p = _tray[i];
      if (p == null || i == _drag) continue;
      final (h, w) = _pieceSize(p.shape);
      final off = Offset(p.enter * 300 + sin(p.back * 20) * 8 * p.back, 0);
      final tl = Offset(_trayX[i], _trayY) + off - Offset(w * _trayCs / 2, h * _trayCs / 2);
      for (final (dr, dc) in _shapes[p.shape]) {
        _block(c, Rect.fromLTWH(tl.dx + dc * _trayCs + 1, tl.dy + dr * _trayCs + 1, _trayCs - 2, _trayCs - 2),
            _colors[p.color]);
      }
    }
    // dragged piece
    if (dragPiece != null) {
      final tl = _dragTopLeft;
      for (final (dr, dc) in _shapes[dragPiece.shape]) {
        _block(c, Rect.fromLTWH(tl.dx + dc * _cs + 2, tl.dy + dr * _cs + 2, _cs - 4, _cs - 4), _colors[dragPiece.color]);
      }
    }

    // word
    if (_wordT < 1.0 && _word.isNotEmpty) {
      final k = _wordT;
      final sc = k < .2 ? M.easeOutBack(k / .2) : 1.0;
      final a = k > .75 ? (1 - k) / .25 : 1.0;
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a.clamp(0.0, 1.0)));
      D.title(c, _word, Offset(180, 290 - k * 26), size: 42, color: _wordCol, scale: sc, rotate: -.05);
      if (_streak >= 2) {
        D.text(c, '${host.tr('combo', 'COMBO')} x$_streak', Offset(180, 336 - k * 26),
            size: 24, color: Pal.white, stroke: Pal.ink, strokeWidth: 5);
      }
      c.restore();
    }
    if (host.time < 2.6 && _drag < 0 && _tray[1] != null) {
      final k = (host.time * .8) % 1.0;
      D.hand(c, Offset.lerp(Offset(_trayX[1], _trayY), const Offset(180, 380), M.easeInOut(k))!, 0);
    }
  }

  static final ui.Shader _glow = const RadialGradient(colors: [Color(0x553D6BFF), Color(0x003D6BFF)])
      .createShader(Rect.fromCircle(center: const Offset(180, 290), radius: 260));

  void _crown(Canvas c, Offset o) {
    final p = Path()
      ..moveTo(o.dx - 14, o.dy + 8)
      ..lineTo(o.dx - 16, o.dy - 8)
      ..lineTo(o.dx - 7, o.dy)
      ..lineTo(o.dx, o.dy - 11)
      ..lineTo(o.dx + 7, o.dy)
      ..lineTo(o.dx + 16, o.dy - 8)
      ..lineTo(o.dx + 14, o.dy + 8)
      ..close();
    c.drawPath(p, D.fill(Pal.gold));
    c.drawPath(p, D.stroke(Pal.ink, 2));
  }
}

class _Piece {
  _Piece(this.shape, this.color);
  final int shape;
  final int color;
  double enter = 0;
  double back = 0;
}

class _Dying {
  _Dying(this.i, this.color, this.t);
  final int i;
  final int color;
  double t;
}
