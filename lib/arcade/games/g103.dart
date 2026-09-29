import '../engine/engine.dart';

/// No.103 Paint Roller Cube — a googly-eyed paint cube rolls tile by tile.
/// The face that lands on the floor stamps its color. Paint every tile!
class G103 extends MiniGame {
  static const _cols = 5, _rows = 7;
  static const _rollDur = .13;
  static const _faceCols = <Color>[
    Color(0xFFFF4F7B), // +x
    Color(0xFF3FB8FF), // -x
    Color(0xFFFFD23F), // +y
    Color(0xFF9BE22D), // -y
    Color(0xFFB266FF), // +z
    Color(0xFFFF8A1F), // -z
  ];
  static const _localN = <V3>[V3(1, 0, 0), V3(-1, 0, 0), V3(0, 1, 0), V3(0, -1, 0), V3(0, 0, 1), V3(0, 0, -1)];

  final scene = Scene3();
  late List<bool> _wall;
  late List<int> _paint; // -1 unpainted, else face color index
  late List<double> _pop;
  final Map<int, Mesh> _tileMeshes = {};
  late final Mesh _wallMesh, _base;

  int _ci = 2, _cj = 0;
  // orientation (row-major 3x3): world = R * local
  List<double> _r = [1, 0, 0, 0, 1, 0, 0, 0, 1];
  int _di = 0, _dj = 0; // active roll direction
  double _rollT = -1; // <0 idle
  bool _bonk = false;
  (int, int)? _queued;
  (int, int)? _holdDir;
  Offset _anchor = Offset.zero;
  bool _down = false;
  int _combo = 0;
  double _comboT = 0;
  double _t = 0;
  double _celebrate = 0;
  double _squash = 0;
  double _blink = 0;
  double _lookX = 0, _lookY = 0;
  int _total = 0, _done = 0;
  bool _moved = false;

  int _idx(int i, int j) => j * _cols + i;
  bool _in(int i, int j) => i >= 0 && j >= 0 && i < _cols && j < _rows;
  V3 _cellPos(int i, int j) => V3(i - (_cols - 1) / 2, 0, j - (_rows - 1) / 2);

  @override
  void init() {
    scene.ambient = .58;
    scene.diffuse = .52;
    scene.light = const V3(-.45, 1, -.6).normalized;
    _wallMesh = Mesh.merge([
      (Mesh.box(.86, .7, .86, const Color(0xFF7A6CF0), colors: const [
        Color(0xFFA99BFF), Color(0xFF5A4CC0), Color(0xFF7A6CF0), Color(0xFF7A6CF0), Color(0xFF6A5CE0), Color(0xFF6A5CE0)
      ]), const V3(0, .35, 0)),
      (Mesh.box(.6, .3, .6, const Color(0xFFFFB8E0), colors: const [
        Color(0xFFFFD6EE), Color(0xFFE08ABF), Color(0xFFFFB8E0), Color(0xFFFFB8E0), Color(0xFFF0A0D0), Color(0xFFF0A0D0)
      ]), const V3(0, .85, 0)),
    ]);
    _base = Mesh.box(_cols + .7, .8, _rows + .7, const Color(0xFFFFF0F6), colors: const [
      Color(0xFFFFF7FB), Color(0xFFD9B8D0), Color(0xFFF4D4E6), Color(0xFFF4D4E6), Color(0xFFEAC6DC), Color(0xFFEAC6DC)
    ]);
    for (var tries = 0; tries < 80; tries++) {
      _wall = List.filled(_cols * _rows, false);
      var placed = 0;
      while (placed < 5) {
        final i = randInt(_cols), j = 1 + randInt(_rows - 1);
        if (_wall[_idx(i, j)] || (i == _ci && j <= 1)) continue;
        _wall[_idx(i, j)] = true;
        placed++;
      }
      if (_connected()) break;
    }
    _paint = List.filled(_cols * _rows, -1);
    _pop = List.filled(_cols * _rows, 0);
    _total = _wall.where((w) => !w).length;
    _stamp(first: true);
  }

  bool _connected() {
    final seen = List.filled(_cols * _rows, false);
    final q = <(int, int)>[(_ci, _cj)];
    seen[_idx(_ci, _cj)] = true;
    var n = 0;
    while (q.isNotEmpty) {
      final (i, j) = q.removeLast();
      n++;
      for (final (a, b) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final x = i + a, y = j + b;
        if (_in(x, y) && !_wall[_idx(x, y)] && !seen[_idx(x, y)]) {
          seen[_idx(x, y)] = true;
          q.add((x, y));
        }
      }
    }
    return n == _wall.where((w) => !w).length;
  }

  // --------------------------------------------------------- orientation ---

  V3 _apply(List<double> m, V3 v) =>
      V3(m[0] * v.x + m[1] * v.y + m[2] * v.z, m[3] * v.x + m[4] * v.y + m[5] * v.z, m[6] * v.x + m[7] * v.y + m[8] * v.z);

  /// Rotation of vector [v] around the roll axis for direction (di,dj) by [a].
  V3 _rollRot(V3 v, int di, int dj, double a) {
    if (di != 0) {
      // about z; +x roll moves top (+y) toward +x → angle -a*di
      final aa = -a * di;
      final cc = cos(aa), ss = sin(aa);
      return V3(v.x * cc - v.y * ss, v.x * ss + v.y * cc, v.z);
    }
    // about x; +z roll moves +y toward +z
    final aa = a * dj;
    final cc = cos(aa), ss = sin(aa);
    return V3(v.x, v.y * cc - v.z * ss, v.y * ss + v.z * cc);
  }

  int _bottomFace() {
    var best = 0;
    var by = 9.0;
    for (var k = 0; k < 6; k++) {
      final w = _apply(_r, _localN[k]);
      if (w.y < by) {
        by = w.y;
        best = k;
      }
    }
    return best;
  }

  void _stamp({bool first = false}) {
    final k = _idx(_ci, _cj);
    final face = _bottomFace();
    final fresh = _paint[k] < 0;
    _paint[k] = face;
    _pop[k] = 1;
    _done = _paint.where((p) => p >= 0).length;
    if (first) return;
    final sp = scene.cam.project(_cellPos(_ci, _cj));
    final at = sp ?? const Offset(180, 380);
    final col = _faceCols[face];
    host.fx.burst(at, col, count: fresh ? 14 : 5, speed: fresh ? 240 : 120, size: 7, shape: PartShape.square, gravity: 500);
    if (fresh) {
      _combo++;
      _comboT = .6;
      host.sfx(Sfx.splat, volume: .8, rate: 1 + min(_combo, 14) * .05);
      host.sfx(Sfx.pop, volume: .4, rate: 1 + min(_combo, 14) * .06);
      host.fx.ring(at, col, size: 34, life: .3);
      host.addScore(10 * min(_combo, 10), at + const Offset(0, -24));
      if (_combo > 0 && _combo % 5 == 0) {
        host.fx.pop('${host.tr('combo', 'COMBO')} x$_combo', const Offset(180, 170), color: Pal.pink, size: 28);
        host.sfx(Sfx.combo, rate: 1 + _combo * .03);
        host.punch(.03);
      }
      if (_done == _total) _win();
    } else {
      host.sfx(Sfx.squish, volume: .35, rate: 1.3);
    }
  }

  void _win() {
    _celebrate = 3;
    host.sfx(Sfx.fanfare);
    host.sfx(Sfx.cheer, volume: .6);
    host.fx.confetti();
    host.flash(Pal.white, .2);
    host.shake(6);
    host.fx.pop(host.tr('perfect', 'PERFECT!'), const Offset(180, 170), color: Pal.yellow, size: 40, life: 1.4);
    final left = host.timeLeft;
    host.win(stars: left > 7 ? 3 : (left > 3 ? 2 : 1));
  }

  // --------------------------------------------------------------- input ---

  void _tryRoll(int di, int dj) {
    if (host.finished) return;
    if (_rollT >= 0) {
      _queued = (di, dj);
      return;
    }
    final ni = _ci + di, nj = _cj + dj;
    _di = di;
    _dj = dj;
    _rollT = 0;
    _bonk = !_in(ni, nj) || _wall[_idx(ni, nj)];
    _moved = true;
    if (_bonk) {
      host.sfx(Sfx.thud, volume: .6, rate: 1.4);
      _combo = 0;
    } else {
      host.sfx(Sfx.flip, volume: .45, rate: rand(.95, 1.15));
    }
  }

  (int, int)? _dirOf(Offset d) {
    if (d.distance < 20) return null;
    return d.dx.abs() > d.dy.abs() ? (d.dx > 0 ? 1 : -1, 0) : (0, d.dy < 0 ? 1 : -1);
  }

  @override
  void onDown(Offset p) {
    _down = true;
    _anchor = p;
    _holdDir = null;
  }

  @override
  void onMove(Offset p) {
    if (!_down) return;
    final d = _dirOf(p - _anchor);
    if (d != null) {
      if (d != _holdDir) _tryRoll(d.$1, d.$2);
      _holdDir = d;
      _anchor = p;
    }
  }

  @override
  void onUp(Offset p) {
    if (_down && _holdDir == null) {
      final d = _dirOf(p - _anchor);
      if (d != null) _tryRoll(d.$1, d.$2);
    }
    _down = false;
    _holdDir = null;
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    switch (key) {
      case 'left':
        _tryRoll(-1, 0);
      case 'right':
        _tryRoll(1, 0);
      case 'up':
        _tryRoll(0, 1);
      case 'down':
        _tryRoll(0, -1);
    }
  }

  // -------------------------------------------------------------- update ---

  @override
  void update(double dt) {
    _t += dt;
    _celebrate = max(0, _celebrate - dt);
    _squash = M.approach(_squash, 0, 14, dt);
    _comboT -= dt;
    if (_comboT < -1.2) _combo = 0;
    for (var k = 0; k < _pop.length; k++) {
      _pop[k] = M.approach(_pop[k], 0, 9, dt);
    }
    _blink -= dt;
    if (_blink < -3) _blink = rand(.12, .15);
    _lookX = M.approach(_lookX, _di.toDouble(), 8, dt);
    _lookY = M.approach(_lookY, -_dj.toDouble() * .6, 8, dt);
    if (_rollT >= 0) {
      _rollT += dt / _rollDur;
      final end = _bonk ? 1.6 : 1.0;
      if (_rollT >= end) {
        _rollT = -1;
        if (!_bonk) {
          // commit rotation
          final cols = [
            _rollRot(V3(_r[0], _r[3], _r[6]), _di, _dj, pi / 2),
            _rollRot(V3(_r[1], _r[4], _r[7]), _di, _dj, pi / 2),
            _rollRot(V3(_r[2], _r[5], _r[8]), _di, _dj, pi / 2),
          ];
          double rd(double v) => v.roundToDouble();
          _r = [
            rd(cols[0].x), rd(cols[1].x), rd(cols[2].x),
            rd(cols[0].y), rd(cols[1].y), rd(cols[2].y),
            rd(cols[0].z), rd(cols[1].z), rd(cols[2].z),
          ];
          _ci += _di;
          _cj += _dj;
          _squash = 1;
          _stamp();
        } else {
          final sp = scene.cam.project(_cellPos(_ci, _cj) + V3(_di * .5, .5, _dj * .5));
          if (sp != null) host.fx.sparkle(sp, count: 5, radius: 16, color: Pal.white);
          host.shake(2.5);
        }
        if (!host.finished) {
          final q = _queued ?? (_down ? _holdDir : null);
          _queued = null;
          if (q != null) _tryRoll(q.$1, q.$2);
        }
      }
    }
  }

  @override
  void onTimeUp() {
    host.sfx(Sfx.aww);
    host.lose();
  }

  // -------------------------------------------------------------- render ---

  Mesh _tileMesh(int paint) => _tileMeshes.putIfAbsent(paint, () {
        final top = paint < 0 ? const Color(0xFFF3EEFF) : _faceCols[paint];
        final side = paint < 0 ? const Color(0xFFD6CCF0) : Color.lerp(_faceCols[paint], Pal.ink, .25)!;
        return Mesh.box(.94, .3, .94, top, colors: [top, side, side, side, side, side]);
      });

  static final _uncheck = Mesh.box(.94, .3, .94, const Color(0xFFE6DEFA),
      colors: const [Color(0xFFE6DEFA), Color(0xFFCFC3EC), Color(0xFFCFC3EC), Color(0xFFCFC3EC), Color(0xFFCFC3EC), Color(0xFFCFC3EC)]);

  @override
  void render(Canvas c) {
    _background(c);
    final cam = scene.cam
      ..center = const Offset(180, 350)
      ..focal = 540
      ..pos = V3(0, 10.2, -7.6 + sin(_t * .6) * .15)
      ..lookAt(const V3(0, 0, .35));
    final prog = _celebrate > 0 ? 3 - _celebrate : 0.0;
    // pass 1: board
    scene.clear();
    scene.add(_base, pos: const V3(0, -.55, 0));
    scene.render(c);
    scene.clear();
    for (var j = 0; j < _rows; j++) {
      for (var i = 0; i < _cols; i++) {
        final k = _idx(i, j);
        if (_wall[k]) {
          scene.add(_uncheck, pos: _cellPos(i, j) + const V3(0, -.15, 0));
          continue;
        }
        final p = _paint[k];
        final wave = _celebrate > 0 ? sin(prog * 9 - (i + j) * .7) * .22 * M.clamp01(_celebrate) : 0.0;
        final m = p < 0 && (i + j).isOdd ? _uncheck : _tileMesh(p);
        scene.add(m, pos: _cellPos(i, j) + V3(0, -.15 - _pop[k] * .12 + wave, 0), flash: _pop[k] * .5);
      }
    }
    scene.render(c);
    // cube shadow
    final cp = _cubeCenter();
    final sp = cam.project(V3(cp.x, .02, cp.z));
    if (sp != null) {
      final k = cam.scaleAt(V3(cp.x, 0, cp.z));
      c.drawOval(Rect.fromCenter(center: sp, width: k * 1.15, height: k * .55), Paint()..color = const Color(0x33301860));
    }
    // pass 2: walls + cube
    scene.clear();
    for (var j = 0; j < _rows; j++) {
      for (var i = 0; i < _cols; i++) {
        if (_wall[_idx(i, j)]) scene.add(_wallMesh, pos: _cellPos(i, j), rotY: sin(_t * 2 + i + j) * .05);
      }
    }
    scene.addSprite(cp, (cv, s, k) => _drawCube(cv));
    scene.render(c);
    _hud(c);
  }

  void _background(Canvas c) {
    D.gradientBg(c, const [Color(0xFFFFD9EC), Color(0xFFC7E3FF), Color(0xFFB7F0E6)]);
    // drifting polka dots
    for (var i = 0; i < 22; i++) {
      final x = (i * 53.0 + _t * 10 * (1 + i % 3)) % 400 - 20;
      final y = (i * 131.0) % 640;
      c.drawCircle(Offset(x, y), 6 + i % 4 * 4.0, Paint()..color = const Color(0x40FFFFFF));
    }
    D.cloud(c, Offset((_t * 12) % 460 - 50, 560), 70, color: const Color(0x88FFFFFF));
    D.cloud(c, Offset((200 + _t * 8) % 460 - 50, 610), 50, color: const Color(0x66FFFFFF));
  }

  double get _rollAngle {
    if (_rollT < 0) return 0;
    if (_bonk) {
      final u = _rollT / 1.6;
      return sin(u * pi) * .22;
    }
    final u = M.clamp01(_rollT);
    return (u * u * (3 - 2 * u)) * pi / 2;
  }

  V3 _pivot() => _cellPos(_ci, _cj) + V3(_di * .5, 0, _dj * .5);

  V3 _cubeCenter() {
    final rest = _cellPos(_ci, _cj) + const V3(0, .5, 0);
    final hop = _celebrate > 0 ? (sin((3 - _celebrate) * 10).abs() * .8) : 0.0;
    if (_rollT < 0) return rest + V3(0, hop, 0);
    final pv = _pivot();
    return pv + _rollRot(rest - pv, _di, _dj, _rollAngle);
  }

  V3 _xf(V3 local) {
    final w = _apply(_r, local);
    var v = _rollT < 0 ? w : _rollRot(w, _di, _dj, _rollAngle);
    if (_celebrate > 0) {
      final a = (3 - _celebrate) * 6;
      v = V3(v.x * cos(a) + v.z * sin(a), v.y, -v.x * sin(a) + v.z * cos(a));
    }
    // squash on landing
    final sq = _squash * .18;
    return V3(v.x * (1 + sq), v.y * (1 - sq), v.z * (1 + sq));
  }

  static final List<Offset> _round = () {
    final pts = <Offset>[];
    const h = .5, r = .16;
    const cs = [(1.0, 1.0), (-1.0, 1.0), (-1.0, -1.0), (1.0, -1.0)];
    for (var k = 0; k < 4; k++) {
      final (sx, sy) = cs[k];
      for (var i = 0; i <= 3; i++) {
        final a = k * pi / 2 + i / 3 * pi / 2;
        pts.add(Offset(sx * (h - r) + cos(a) * r, sy * (h - r) + sin(a) * r));
      }
    }
    return pts;
  }();

  void _drawCube(Canvas c) {
    final cam = scene.cam;
    final center = _cubeCenter();
    var eyeFace = -1;
    var bestDot = -9.0;
    final ns = List<V3>.generate(6, (k) => _xf(_localN[k]).normalized);
    for (var k = 0; k < 6; k++) {
      final d = ns[k].dot((cam.pos - center).normalized);
      if (d > bestDot && ns[k].y > -.2) {
        bestDot = d;
        eyeFace = k;
      }
    }
    for (var k = 0; k < 6; k++) {
      final n = _localN[k];
      final u = n.x != 0 ? const V3(0, 0, 1) : const V3(1, 0, 0);
      final v = n.cross(u);
      final wn = ns[k];
      final fc = center + _xf(n * .5);
      if (wn.dot(cam.pos - fc) <= 0) continue;
      final wu = _xf(u), wv = _xf(v);
      final kLight = .55 + .55 * max(0.0, wn.dot(scene.light));
      final base = _faceCols[k];
      Color sh(Color b, double m) =>
          Color.from(alpha: 1, red: (b.r * m).clamp(0, 1), green: (b.g * m).clamp(0, 1), blue: (b.b * m).clamp(0, 1));
      final outer = Path(), inner = Path();
      for (var i = 0; i < 4; i++) {
        final su = (i == 0 || i == 3) ? .5 : -.5, sv = i < 2 ? .5 : -.5;
        final p = cam.project(fc + wu * su + wv * sv);
        if (p == null) return;
        i == 0 ? outer.moveTo(p.dx, p.dy) : outer.lineTo(p.dx, p.dy);
      }
      outer.close();
      for (var i = 0; i < _round.length; i++) {
        final o = _round[i] * .9;
        final p = cam.project(fc + wu * o.dx + wv * o.dy)!;
        i == 0 ? inner.moveTo(p.dx, p.dy) : inner.lineTo(p.dx, p.dy);
      }
      inner.close();
      c.drawPath(outer, Paint()..color = sh(Color.lerp(base, Pal.white, .55)!, kLight));
      c.drawPath(inner, Paint()..color = sh(base, kLight));
      // glossy highlight
      final hl = Path();
      for (var i = 0; i < 8; i++) {
        final a = i / 8 * pi * 2;
        final p = cam.project(fc + wu * (-.2 + cos(a) * .13) + wv * (.22 + sin(a) * .07))!;
        i == 0 ? hl.moveTo(p.dx, p.dy) : hl.lineTo(p.dx, p.dy);
      }
      c.drawPath(hl, Paint()..color = const Color(0x55FFFFFF));
      if (k == eyeFace) _eyes(c, fc, wu, wv, wn);
    }
  }

  void _eyes(Canvas c, V3 fc, V3 wu, V3 wv, V3 wn) {
    final cam = scene.cam;
    // orient eyes so "up" on the face is as close to world-up / away from camera as possible
    var up = wv;
    var right = wu;
    final camUp = wn.y > .7 ? const V3(0, 0, 1) : const V3(0, 1, 0);
    final cands = [(wv, wu), (-wv, -wu), (wu, -wv), (-wu, wv)];
    var best = -9.0;
    for (final (uu, rr) in cands) {
      final d = uu.dot(camUp);
      if (d > best) {
        best = d;
        up = uu;
        right = rr;
      }
    }
    // make sure right points to screen-right
    final a = cam.project(fc)!, b = cam.project(fc + right * .2)!;
    if (b.dx < a.dx) right = -right;
    Path circ(V3 ctr, double rx, double ry) {
      final p = Path();
      for (var i = 0; i < 12; i++) {
        final t = i / 12 * pi * 2;
        final s = cam.project(ctr + right * (cos(t) * rx) + up * (sin(t) * ry))!;
        i == 0 ? p.moveTo(s.dx, s.dy) : p.lineTo(s.dx, s.dy);
      }
      return p..close();
    }

    final blinking = _blink > 0;
    final happy = _celebrate > 0 || (_comboT > 0 && _combo >= 3);
    for (final sx in const [-1.0, 1.0]) {
      final e = fc + right * (sx * .17) + up * .06 + wn * .01;
      if (blinking || happy) {
        final l = cam.project(e + right * -.09)!, m = cam.project(e + up * (happy ? .06 : 0))!, r = cam.project(e + right * .09)!;
        final path = Path()
          ..moveTo(l.dx, l.dy)
          ..lineTo(m.dx, m.dy)
          ..lineTo(r.dx, r.dy);
        c.drawPath(path, D.stroke(Pal.ink, 3));
      } else {
        c.drawPath(circ(e, .1, .12), D.fill(Pal.white));
        c.drawPath(circ(e, .1, .12), D.stroke(Pal.ink, 1.6));
        c.drawPath(circ(e + right * (_lookX * .04) + up * (_lookY * .05), .05, .06), D.fill(Pal.ink));
      }
    }
    // mouth
    final m0 = cam.project(fc + up * -.14 + right * -.07 + wn * .01)!;
    final m1 = cam.project(fc + up * (_bonk && _rollT >= 0 ? -.12 : -.2) + wn * .01)!;
    final m2 = cam.project(fc + up * -.14 + right * .07 + wn * .01)!;
    c.drawPath(Path()
      ..moveTo(m0.dx, m0.dy)
      ..quadraticBezierTo(m1.dx, m1.dy, m2.dx, m2.dy), D.stroke(Pal.ink, 2.5));
    // blush
    for (final sx in const [-1.0, 1.0]) {
      c.drawPath(circ(fc + right * (sx * .3) + up * -.1 + wn * .01, .06, .035), D.fill(const Color(0x66FF6FA0)));
    }
  }

  void _hud(Canvas c) {
    final t = _total == 0 ? 0.0 : _done / _total;
    D.rrect(c, const Rect.fromLTWH(40, 58, 280, 34), 17, const Color(0xCCFFFFFF), border: Pal.ink, borderWidth: 3);
    D.bar(c, const Rect.fromLTWH(48, 65, 206, 20), t, Color.lerp(Pal.pink, Pal.lime, t)!,
        back: const Color(0x33301860));
    D.text(c, '${(t * 100).round()}%', const Offset(288, 75), size: 18, color: Pal.ink);
    // swatches of cube colors
    for (var k = 0; k < 6; k++) {
      c.drawCircle(Offset(120 + k * 24.0, 112), 8, D.fill(_faceCols[k]));
      c.drawCircle(Offset(120 + k * 24.0, 112), 8, D.stroke(Pal.ink, 2));
    }
    if (_combo >= 2 && _comboT > -1) {
      D.text(c, '${host.tr('combo', 'COMBO')} $_combo', const Offset(180, 142), size: 20, color: Pal.pink,
          stroke: Pal.white, strokeWidth: 5);
    }
    if (!_moved && host.time < 3.5) {
      final sp = scene.cam.project(_cellPos(_ci, _cj) + const V3(0, .5, 0)) ?? const Offset(180, 500);
      final ph = (_t * 1.2) % 1;
      D.hand(c, sp + Offset(0, 60 - ph * 90), _t, size: 40);
      D.arrow(c, sp + const Offset(56, -40), const Offset(0, -1), 50, Pal.yellow, width: 10);
      D.text(c, host.tr('swipe', 'SWIPE'), sp + const Offset(0, 118), size: 22, color: Pal.white, stroke: Pal.ink,
          strokeWidth: 5);
    }
  }
}
