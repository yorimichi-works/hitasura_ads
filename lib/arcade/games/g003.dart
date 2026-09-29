import 'dart:collection';

import '../engine/engine.dart';

/// No.003 Liquid Sort — tap a tube, tap another to pour. Sort every color.
class G003 extends MiniGame {
  static const _cap = 4;
  static const _nT = 5;
  static const _layerH = 38.0;
  static const _tubeW = 46.0;
  static const _bottomY = 510.0;
  static const _palette = <Color>[
    Color(0xFFFF3B5C), // red
    Color(0xFF3D8BFF), // blue
    Color(0xFFFFD23F), // yellow
    Color(0xFF2ECC71), // green
    Color(0xFFB45CFF), // purple
    Color(0xFFFF8A1F), // orange
  ];

  late List<List<int>> _tubes;
  late List<Color> _cols;
  final List<double> _lift = List.filled(_nT, 0);
  final List<double> _shake = List.filled(_nT, 0);
  final List<double> _cork = List.filled(_nT, 0); // 0 none, grows to 1
  final List<double> _jump = List.filled(_nT, 0);
  int _sel = -1;
  int _cursor = 0;
  _Pour? _pour;
  double _t = 0;
  int _moves = 0;
  (int, int)? _hint;
  bool _done = false;
  int _combo = 0;
  bool _keyUsed = false;

  double _tubeX(int i) => 180 + (i - 2) * 68.0;
  double get _tubeH => _cap * _layerH + 16;

  // ------------------------------------------------------------- puzzle ---
  @override
  void init() {
    final ids = List<int>.generate(_palette.length, (i) => i)..shuffle(host.rng);
    _cols = [for (final i in ids.take(3)) _palette[i]];
    List<List<int>>? best;
    (int, int)? bestHint;
    for (var attempt = 0; attempt < 120; attempt++) {
      final layers = [for (var c = 0; c < 3; c++) ...List.filled(_cap, c)]..shuffle(host.rng);
      final tubes = [
        for (var t = 0; t < 3; t++) layers.sublist(t * _cap, t * _cap + _cap),
        <int>[],
        <int>[],
      ];
      if (tubes.any((t) => t.length == _cap && t.every((x) => x == t[0]))) continue;
      final (moves, first) = _solve(tubes);
      if (moves < 0) continue;
      best = tubes;
      bestHint = first;
      if (moves >= 4 && moves <= 7) break;
    }
    _tubes = best ?? [
      [0, 1, 0, 2],
      [1, 2, 1, 0],
      [2, 0, 2, 1],
      <int>[],
      <int>[],
    ];
    _hint = best == null ? _solve(_tubes).$2 : bestHint;
  }

  static String _key(List<List<int>> s) => s.map((t) => t.join()).join('|');

  static bool _solved(List<List<int>> s) =>
      s.every((t) => t.isEmpty || (t.length == _cap && t.every((x) => x == t[0])));

  static int _run(List<int> t) {
    var n = 1;
    while (n < t.length && t[t.length - 1 - n] == t.last) {
      n++;
    }
    return n;
  }

  static bool _canPour(List<List<int>> s, int a, int b) {
    if (a == b || s[a].isEmpty || s[b].length >= _cap) return false;
    return s[b].isEmpty || s[b].last == s[a].last;
  }

  static List<List<int>> _apply(List<List<int>> s, int a, int b) {
    final n = [for (final t in s) List.of(t)];
    final amt = min(_run(n[a]), _cap - n[b].length);
    for (var i = 0; i < amt; i++) {
      n[b].add(n[a].removeLast());
    }
    return n;
  }

  /// BFS: returns (min moves, first move) or (-1, null).
  static (int, (int, int)?) _solve(List<List<int>> start) {
    final seen = HashMap<String, (int, int)?>();
    final q = Queue<(List<List<int>>, int, (int, int)?)>();
    q.add((start, 0, null));
    seen[_key(start)] = null;
    while (q.isNotEmpty) {
      final (s, d, first) = q.removeFirst();
      if (_solved(s)) return (d, first);
      if (seen.length > 20000) break;
      for (var a = 0; a < s.length; a++) {
        for (var b = 0; b < s.length; b++) {
          if (!_canPour(s, a, b)) continue;
          if (s[b].isEmpty && _run(s[a]) == s[a].length) continue; // pointless
          final n = _apply(s, a, b);
          final k = _key(n);
          if (seen.containsKey(k)) continue;
          seen[k] = null;
          q.add((n, d + 1, first ?? (a, b)));
        }
      }
    }
    return (-1, null);
  }

  bool _complete(int i) => _tubes[i].length == _cap && _tubes[i].every((x) => x == _tubes[i][0]);

  // ------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    for (var i = 0; i < _nT; i++) {
      final target = (i == _sel && _pour == null) ? 1.0 : 0.0;
      _lift[i] = M.approach(_lift[i], target, 16, dt);
      _shake[i] = M.approach(_shake[i], 0, 7, dt);
      if (_cork[i] > 0 && _cork[i] < 1) _cork[i] = min(1, _cork[i] + dt * 4);
      _jump[i] = max(0, _jump[i] - dt * 2.2);
    }
    final p = _pour;
    if (p != null) {
      final before = p.t;
      p.t += dt / p.dur;
      if (before < .3 && p.t >= .3) host.sfx(Sfx.pour, volume: .8, rate: rand(.95, 1.1));
      if (p.t >= 1) {
        _pour = null;
        _afterPour(p);
      }
    }
    if (_done) {
      for (var i = 0; i < _nT; i++) {
        if (_jump[i] <= 0 && chance(dt * 3)) _jump[i] = 1;
      }
    }
  }

  void _afterPour(_Pour p) {
    if (_complete(p.to)) {
      _combo++;
      _cork[p.to] = .01;
      final top = Offset(_tubeX(p.to), _bottomY - _tubeH - 6);
      host.sfx(Sfx.pop, rate: 1.1);
      host.sfx(Sfx.correct, rate: 1 + _combo * .12);
      host.fx.burst(top, _cols[_tubes[p.to][0]], count: 22, speed: 260, shape: PartShape.star, size: 7,
          colors: [_cols[_tubes[p.to][0]], Pal.white, Pal.yellow]);
      host.fx.ring(top, Pal.white, size: 70);
      host.fx.sparkle(Offset(_tubeX(p.to), _bottomY - _tubeH / 2), count: 12, radius: 30);
      host.fx.pop(_combo >= 2 ? host.tr('great', 'GREAT!') : host.tr('nice', 'NICE!'), top - const Offset(0, 40),
          color: _cols[_tubes[p.to][0]], size: 30);
      host.addScore(100 * _combo, top - const Offset(0, 80));
      host.punch(.03);
      _jump[p.to] = 1;
    } else {
      host.addScore(10);
    }
    if (_solved(_tubes) && !_done) {
      _done = true;
      host.sfx(Sfx.fanfare);
      host.flash(Pal.white, .15);
      host.fx.confetti(count: 90);
      host.fx.pop(host.tr('perfect', 'PERFECT!'), const Offset(180, 200), color: Pal.yellow, size: 44, life: 1.3);
      final t = host.time;
      host.win(stars: t < 10 ? 3 : (t < 15 ? 2 : 1));
    }
  }

  // -------------------------------------------------------------- input ---
  int _hit(Offset p) {
    for (var i = 0; i < _nT; i++) {
      if ((p.dx - _tubeX(i)).abs() < 34 && p.dy > _bottomY - _tubeH - 70 && p.dy < _bottomY + 40) return i;
    }
    return -1;
  }

  @override
  void onDown(Offset p) => _tapTube(_hit(p));

  void _tapTube(int i) {
    if (i < 0 || _pour != null || _done) return;
    if (_sel < 0) {
      if (_tubes[i].isEmpty || _complete(i)) {
        _shake[i] = 1;
        host.sfx(Sfx.tap, volume: .5, rate: .8);
        return;
      }
      _sel = i;
      host.sfx(Sfx.select, rate: 1.1);
      return;
    }
    if (i == _sel) {
      _sel = -1;
      host.sfx(Sfx.back, volume: .6);
      return;
    }
    if (!_canPour(_tubes, _sel, i)) {
      _shake[i] = 1;
      _shake[_sel] = .6;
      host.sfx(Sfx.wrong, volume: .7);
      _sel = -1;
      return;
    }
    final color = _tubes[_sel].last;
    final amt = min(_run(_tubes[_sel]), _cap - _tubes[i].length);
    final fromLen = _tubes[_sel].length;
    final toLen = _tubes[i].length;
    _tubes = _apply(_tubes, _sel, i);
    _pour = _Pour(_sel, i, color, amt, fromLen, toLen);
    _moves++;
    _hint = null;
    _sel = -1;
    host.sfx(Sfx.whoosh, volume: .5, rate: 1.4);
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    _keyUsed = true;
    if (key == 'left') _cursor = (_cursor + _nT - 1) % _nT;
    if (key == 'right') _cursor = (_cursor + 1) % _nT;
    if (key == 'action') _tapTube(_cursor);
  }

  // ------------------------------------------------------------- render ---
  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFFFFD6EC), Color(0xFFC8B6FF), Color(0xFF8E7BFF)]);
    // bokeh bubbles
    for (var i = 0; i < 14; i++) {
      final y = 640 - ((i * 83 + _t * (14 + i % 4 * 6)) % 700);
      final x = (i * 67.0 + sin(_t + i) * 12) % 360;
      c.drawCircle(Offset(x, y), 6.0 + (i % 5) * 5, D.fill(const Color(0x22FFFFFF)));
      c.drawCircle(Offset(x, y), 6.0 + (i % 5) * 5, D.stroke(const Color(0x44FFFFFF), 1.5));
    }
    // soft spotlight
    c.drawCircle(const Offset(180, 380), 220, Paint()..color = const Color(0x22FFFFFF));
    // shelf
    D.rrect(c, const Rect.fromLTWH(14, _bottomY + 12, 332, 22), 8, const Color(0xFFB07A4F),
        border: Pal.ink, borderWidth: 3);
    D.rrect(c, const Rect.fromLTWH(20, _bottomY + 14, 320, 6), 3, const Color(0xFFD9A273));
    for (final x in const [40.0, 320.0]) {
      D.rrect(c, Rect.fromLTWH(x - 7, _bottomY + 32, 14, 36), 3, const Color(0xFF8A5A3C), border: Pal.ink, borderWidth: 3);
    }
    // wallpaper dots
    final dot = D.fill(const Color(0x1FFFFFFF));
    for (var yy = 0; yy < 12; yy++) {
      for (var xx = 0; xx < 9; xx++) {
        c.drawCircle(Offset(xx * 44.0 + (yy.isOdd ? 22 : 0), 110 + yy * 34.0), 4, dot);
      }
    }

    // tubes (pouring source last so it's on top)
    final p = _pour;
    for (var i = 0; i < _nT; i++) {
      if (p != null && p.from == i) continue;
      _drawTube(c, i, Offset(_tubeX(i), _bottomY - _lift[i] * 30 - sin(_jump[i] * pi) * 28), 0);
    }
    if (p != null) {
      final k = p.t;
      final ease = M.easeInOut(M.clamp01(k / .3));
      final back = M.easeInOut(M.clamp01((k - .8) / .2));
      final side = p.to <= 1 ? -1.0 : 1.0;
      final home = Offset(_tubeX(p.from), _bottomY - 30);
      final dest = Offset(_tubeX(p.to) - side * 40, _bottomY - _tubeH + 10);
      final pos = Offset.lerp(Offset.lerp(home, dest, ease)!, home, back)!;
      final ang = side * 1.15 * (ease - back);
      _drawTube(c, p.from, pos, ang);
      // stream
      if (k > .28 && k < .86) {
        final lip = pos + _rot(Offset(side * _tubeW / 2, -_tubeH), ang);
        final tgtTop = _bottomY - p.toLen * _layerH - M.clamp01((k - .3) / .5) * p.amt * _layerH;
        final col = _cols[p.color];
        final wob = sin(_t * 40) * 1.5;
        c.drawLine(lip, Offset(_tubeX(p.to) + wob, tgtTop), D.stroke(col, 8));
        c.drawLine(lip + const Offset(-1.5, 0), Offset(_tubeX(p.to) - 1.5 + wob, tgtTop), D.stroke(const Color(0x55FFFFFF), 2));
        if (chance(.5)) {
          host.fx.burst(Offset(_tubeX(p.to), tgtTop), col, count: 1, speed: 80, size: 4, life: .3, gravity: 500);
        }
      }
    }

    // HUD: sorted count
    var doneN = 0;
    for (var i = 0; i < _nT; i++) {
      if (_complete(i)) doneN++;
    }
    D.rrect(c, const Rect.fromLTWH(110, 52, 140, 40), 20, const Color(0xCCFFFFFF), border: Pal.ink, borderWidth: 3);
    for (var k = 0; k < 3; k++) {
      final o = Offset(146 + k * 34.0, 72);
      final got = k < doneN;
      c.drawCircle(o, 12, D.fill(got ? _cols[k] : const Color(0x33000000)));
      c.drawCircle(o, 12, D.stroke(Pal.ink, 2.5));
      if (got) D.star(c, o, 7, Pal.white);
    }

    // hint
    final h = _hint;
    if (h != null && host.time < 4 && _moves == 0) {
      final src = h.$1, dst = h.$2;
      final target = _sel == src ? dst : src;
      final tip = Offset(_tubeX(target), _bottomY - _tubeH - 40);
      D.hand(c, tip + const Offset(0, 30), _t);
      D.arrow(c, tip - const Offset(0, 30), const Offset(0, 1), 34, Pal.white, width: 11);
    }
    if (_sel < 0 && _pour == null && host.time > 4 && _moves == 0) {
      D.text(c, host.tr('tap', 'TAP!'), const Offset(180, 140), size: 26, stroke: Pal.ink);
    }
  }

  Offset _rot(Offset v, double a) => Offset(v.dx * cos(a) - v.dy * sin(a), v.dx * sin(a) + v.dy * cos(a));

  void _drawTube(Canvas c, int i, Offset bottom, double ang) {
    final w = _tubeW, h = _tubeH;
    final shake = sin(_t * 60) * _shake[i] * 6;
    c.save();
    c.translate(bottom.dx + shake, bottom.dy);
    c.rotate(ang);
    final body = RRect.fromRectAndCorners(Rect.fromLTWH(-w / 2, -h, w, h),
        bottomLeft: Radius.circular(w / 2), bottomRight: Radius.circular(w / 2), topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4));
    // shadow
    if (ang == 0) D.shadow(c, const Offset(0, 4), w + 10, 10, .18);
    c.drawRRect(body, D.fill(const Color(0x55FFFFFF)));
    // liquid layers (clipped by glass)
    c.save();
    c.clipRRect(body.deflate(4));
    final layers = _tubes[i];
    final p = _pour;
    var levels = <(int, double)>[for (final l in layers) (l, 1.0)];
    if (p != null) {
      final k = M.clamp01((p.t - .3) / .5);
      if (p.to == i) {
        // new layers appear progressively
        levels = [
          for (var j = 0; j < layers.length; j++) (layers[j], j < p.toLen ? 1.0 : k),
        ];
      } else if (p.from == i) {
        levels = [
          ...levels,
          for (var j = 0; j < p.amt; j++) (p.color, 1 - k),
        ];
      }
    }
    var y = -4.0;
    for (var j = 0; j < levels.length; j++) {
      final (col, f) = levels[j];
      if (f <= 0) continue;
      final lh = _layerH * f;
      final r = Rect.fromLTWH(-w / 2, y - lh - (j == 0 ? 0 : 0), w, lh + 1);
      final cc = _cols[col];
      c.drawRect(r, Paint()
        ..shader = LinearGradient(colors: [Color.lerp(cc, Pal.white, .25)!, cc, Color.lerp(cc, Pal.ink, .25)!],
            stops: const [0, .45, 1]).createShader(r));
      y -= lh;
    }
    if (levels.isNotEmpty) {
      // surface meniscus + bubbles
      final wob = sin(_t * 5 + i) * 1.5;
      c.drawOval(Rect.fromCenter(center: Offset(0, y + 1 + wob * .3), width: w - 8, height: 6),
          D.fill(const Color(0x66FFFFFF)));
      for (var b = 0; b < 3; b++) {
        final by = -4 - ((_t * 30 + b * 37 + i * 13) % max(1, -y - 8));
        c.drawCircle(Offset(-8 + b * 8.0, by), 2.2, D.fill(const Color(0x66FFFFFF)));
      }
    }
    c.restore();
    // glass highlights & outline
    c.drawRRect(body, D.stroke(Pal.ink, 3.5));
    c.drawLine(Offset(-w / 2 + 9, -h + 12), Offset(-w / 2 + 9, -22), D.stroke(const Color(0x99FFFFFF), 4));
    c.drawLine(Offset(w / 2 - 9, -h + 20), Offset(w / 2 - 9, -h + 40), D.stroke(const Color(0x66FFFFFF), 3));
    // lip
    D.rrect(c, Rect.fromLTWH(-w / 2 - 5, -h - 6, w + 10, 10), 5, const Color(0xCCFFFFFF), border: Pal.ink, borderWidth: 3);
    // cork + happy face when complete
    if (_cork[i] > 0) {
      final s = M.easeOutBack(_cork[i]);
      c.save();
      c.translate(0, -h - 10 - (1 - _cork[i]) * 40);
      c.scale(s);
      D.rrect(c, const Rect.fromLTWH(-17, -16, 34, 20), 6, const Color(0xFFC98B55), border: Pal.ink, borderWidth: 3);
      c.drawLine(const Offset(-10, -8), const Offset(10, -8), D.stroke(const Color(0xFF9A6236), 2));
      c.restore();
      D.face(c, Offset(0, -h * .38), 15, Face.happy, ink: Pal.ink);
    }
    if (_sel == i) {
      c.drawRRect(body.inflate(5), D.stroke(Color.fromRGBO(255, 255, 255, .6 + .4 * M.wave(_t, 3)), 3));
    }
    c.restore();
    if (_cursor == i && ang == 0 && _keyUsed) {
      D.arrow(c, Offset(bottom.dx, bottom.dy + 52), const Offset(0, -1), 26, Pal.yellow, width: 8);
    }
  }
}

class _Pour {
  _Pour(this.from, this.to, this.color, this.amt, this.fromLen, this.toLen);
  final int from, to, color, amt, fromLen, toLen;
  double t = 0;
  double get dur => .6;
}
