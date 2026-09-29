import '../engine/engine.dart';

/// No.035 Latte Art Master — top view of an espresso cup with a faint target
/// pattern (heart / leaf / bear). Hold & drag to pour steamed milk: foam
/// blobs spread where you pour. Match % = coverage of the pattern minus
/// spill outside it. 55%+ = win; the customer reacts to your art.
class G035 extends MiniGame {
  static const _cup = Offset(180, 330);
  static const _cupR = 128.0;
  static const _n = 48; // grid resolution
  static const _cell = _cupR * 2 / _n;
  static const _winPct = 55;

  late final int _shape; // 0 heart, 1 leaf, 2 bear
  late final Path _target;
  final List<bool> _mask = List.filled(_n * _n, false);
  final List<bool> _inCup = List.filled(_n * _n, false);
  final List<bool> _foam = List.filled(_n * _n, false);
  int _targetCount = 1;
  int _hit = 0;
  int _spill = 0;

  final List<_Blob> _blobs = [];
  double _milk = 1;
  bool _pouring = false;
  Offset _pp = _cup;
  Offset _lastBlobAt = const Offset(-999, -999);
  double _t = 0;
  double _pourSfxT = 0;
  bool _done = false;
  double _doneT = 0;
  int _finalPct = 0;
  double _shownPct = 0;
  double _serveBtnPress = 0;
  double _jugTilt = 0;

  static const _serveRect = Rect.fromLTWH(110, 560, 140, 50);

  @override
  void init() {
    _shape = randInt(3);
    _target = _buildTarget(_shape);
    var cnt = 0;
    for (var gy = 0; gy < _n; gy++) {
      for (var gx = 0; gx < _n; gx++) {
        final p = _cellCenter(gx, gy);
        final i = gy * _n + gx;
        _inCup[i] = (p - _cup).distance < _cupR - 8;
        if (_inCup[i] && _target.contains(p - _cup)) {
          _mask[i] = true;
          cnt++;
        }
      }
    }
    _targetCount = max(1, cnt);
  }

  Offset _cellCenter(int gx, int gy) =>
      Offset(_cup.dx - _cupR + (gx + .5) * _cell, _cup.dy - _cupR + (gy + .5) * _cell);

  Path _buildTarget(int s) {
    switch (s) {
      case 0:
        const k = 92.0;
        return Path()
          ..moveTo(0, k * .95)
          ..cubicTo(-k * 1.45, -k * .05, -k * .72, -k * 1.2, 0, -k * .42)
          ..cubicTo(k * .72, -k * 1.2, k * 1.45, -k * .05, 0, k * .95)
          ..close();
      case 1:
        return Path()
          ..moveTo(0, -100)
          ..quadraticBezierTo(105, -10, 0, 100)
          ..quadraticBezierTo(-105, -10, 0, -100)
          ..close();
      default:
        return Path()
          ..addOval(Rect.fromCircle(center: const Offset(0, 16), radius: 62))
          ..addOval(Rect.fromCircle(center: const Offset(-50, -40), radius: 24))
          ..addOval(Rect.fromCircle(center: const Offset(50, -40), radius: 24));
    }
  }

  int get _pct {
    final v = (_hit - _spill * .6) / _targetCount;
    return (v.clamp(0.0, 1.0) * 100).round();
  }

  void _addBlob(Offset p, double r) {
    if (_blobs.length >= 900) {
      // grow nearest recent blob instead
      _blobs.last.target = min(34, _blobs.last.target + .6);
    } else {
      _blobs.add(_Blob(p, r));
    }
    _mark(p, r);
  }

  void _mark(Offset p, double r) {
    final gx0 = ((p.dx - r - (_cup.dx - _cupR)) / _cell).floor().clamp(0, _n - 1);
    final gx1 = ((p.dx + r - (_cup.dx - _cupR)) / _cell).ceil().clamp(0, _n - 1);
    final gy0 = ((p.dy - r - (_cup.dy - _cupR)) / _cell).floor().clamp(0, _n - 1);
    final gy1 = ((p.dy + r - (_cup.dy - _cupR)) / _cell).ceil().clamp(0, _n - 1);
    for (var gy = gy0; gy <= gy1; gy++) {
      for (var gx = gx0; gx <= gx1; gx++) {
        final i = gy * _n + gx;
        if (_foam[i] || !_inCup[i]) continue;
        if ((_cellCenter(gx, gy) - p).distance <= r) {
          _foam[i] = true;
          if (_mask[i]) {
            _hit++;
          } else {
            _spill++;
          }
        }
      }
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _serveBtnPress = M.approach(_serveBtnPress, 0, 10, dt);
    _jugTilt = M.approach(_jugTilt, _pouring ? 1 : 0, 10, dt);
    for (final b in _blobs) {
      if (b.r < b.target) {
        b.r = min(b.target, b.r + dt * 30);
        _mark(b.p, b.r);
      }
    }
    if (_done) {
      _doneT += dt;
      _shownPct = M.approach(_shownPct, _finalPct.toDouble(), 5, dt);
      return;
    }
    if (_pouring && _milk > 0) {
      final inCup = (_pp - _cup).distance < _cupR - 4;
      _milk -= dt * .15;
      _pourSfxT -= dt;
      if (_pourSfxT <= 0) {
        _pourSfxT = .35;
        host.sfx(Sfx.pour, volume: .45, rate: .9 + rand(0, .2));
      }
      if (inCup) {
        final d = (_pp - _lastBlobAt).distance;
        if (d > 7) {
          _addBlob(_pp, 13);
          _lastBlobAt = _pp;
        } else {
          if (_blobs.isNotEmpty) {
            final b = _blobs.last;
            b.target = min(40, b.target + dt * 34);
          }
        }
      } else {
        // pouring on the table: splash!
        if (chance(dt * 12)) host.fx.burst(_pp, Pal.white, count: 3, speed: 80, size: 4, gravity: 200);
      }
      if (_milk <= 0) {
        _milk = 0;
        _pouring = false;
        host.sfx(Sfx.drip);
        host.fx.pop(host.tr('empty', 'EMPTY!'), _pp + const Offset(0, -60), color: Pal.white, size: 22);
      }
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _pouring = false;
    _finalPct = _pct;
    final ok = _finalPct >= _winPct;
    if (ok) {
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.cheer, volume: .6);
      host.fx.confetti();
      host.fx.burst(const Offset(180, 140), Pal.pink, count: 24, speed: 300, shape: PartShape.heart);
      host.addScore(_finalPct * 10);
      host.win(stars: _finalPct >= 80 ? 3 : (_finalPct >= 68 ? 2 : 1));
    } else {
      host.sfx(Sfx.aww);
      host.sfx(Sfx.jingleLose, volume: .6);
      host.lose();
    }
  }

  @override
  void onTimeUp() => _finish();

  @override
  void onDown(Offset p) {
    if (_done) return;
    if (_serveRect.inflate(6).contains(p) && _hit > _targetCount * .25) {
      _serveBtnPress = 1;
      host.sfx(Sfx.bell);
      _finish();
      return;
    }
    if (_milk <= 0) {
      host.sfx(Sfx.tap, volume: .4);
      return;
    }
    _pouring = true;
    _pp = p;
    _lastBlobAt = const Offset(-999, -999);
    host.sfx(Sfx.pour, volume: .6);
  }

  @override
  void onMove(Offset p) => _pp = p;

  @override
  void onUp(Offset p) {
    if (_pouring) host.sfx(Sfx.drip, volume: .4);
    _pouring = false;
  }

  // ----------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    _drawTable(c);
    _drawCup(c);
    _drawFoam(c);
    _drawTargetGuide(c);
    _drawHud(c);
    if (!_done) _drawJug(c);
    if (_done) _drawResult(c);
    if (!_done && host.time < 2.2 && _blobs.isEmpty) {
      // trace the pattern with the hand
      final k = (_t * .6) % 1.0;
      final metrics = _target.computeMetrics().first;
      final tan = metrics.getTangentForOffset(metrics.length * k);
      if (tan != null) D.hand(c, _cup + tan.position, 0);
      D.text(c, host.tr('hold', 'HOLD') , const Offset(180, 520), size: 22, color: Pal.white, stroke: Pal.ink);
    }
  }

  void _drawTable(Canvas c) {
    D.gradientBg(c, const [Color(0xFF8A5530), Color(0xFF6A3C20)]);
    final grain = D.stroke(const Color(0x22000000), 2);
    for (var i = 0; i < 16; i++) {
      final y = 20 + i * 42.0;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= 360; x += 30) {
        path.lineTo(x, y + sin(x * .02 + i) * 6);
      }
      c.drawPath(path, grain);
    }
    // plank seams
    for (var i = 1; i < 4; i++) {
      c.drawLine(Offset(i * 90.0, 0), Offset(i * 90.0, 640), D.stroke(const Color(0x33000000), 2));
    }
    // soft window light
    c.drawCircle(const Offset(80, 120), 200, Paint()..color = const Color(0x14FFF4DC));
    // little plant + sugar
    D.circle(c, const Offset(40, 570), 30, const Color(0xFFD9C4A0), border: Pal.ink);
    for (var k = 0; k < 5; k++) {
      final a = k * 1.25 + sin(_t) * .05;
      c.drawOval(Rect.fromCenter(center: Offset(40 + cos(a) * 18, 570 + sin(a) * 18), width: 22, height: 12), D.fill(Pal.green));
    }
    D.rrect(c, const Rect.fromLTWH(304, 540, 26, 40), 4, Pal.white, border: Pal.ink, borderWidth: 2);
    c.drawRect(const Rect.fromLTWH(304, 552, 26, 8), D.fill(Pal.pink));
  }

  void _drawCup(Canvas c) {
    // saucer
    D.shadow(c, _cup + const Offset(8, 14), 330, 330, .3);
    c.drawCircle(_cup, 160, D.fill(const Color(0xFFF1ECE4)));
    c.drawCircle(_cup, 160, D.stroke(Pal.ink, 3));
    c.drawCircle(_cup, 146, D.stroke(const Color(0xFFD9D0C2), 3));
    // handle
    D.rrect(c, Rect.fromCenter(center: _cup + const Offset(150, 0), width: 56, height: 36), 18, Pal.white,
        border: Pal.ink, borderWidth: 3);
    // cup rim
    c.drawCircle(_cup, _cupR + 12, D.fill(Pal.white));
    c.drawCircle(_cup, _cupR + 12, D.stroke(Pal.ink, 3));
    // espresso crema
    final rect = Rect.fromCircle(center: _cup, radius: _cupR);
    c.drawCircle(
        _cup,
        _cupR,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0xFFC98A4B), Color(0xFF8A4F22), Color(0xFF4A2410)], stops: [0, .7, 1])
              .createShader(rect));
    // crema speckles
    for (var k = 0; k < 26; k++) {
      final a = k * 2.4;
      final r = 20 + (k * 37) % 100.0;
      c.drawCircle(_cup + Offset(cos(a) * r, sin(a) * r), 2 + (k % 3).toDouble(), D.fill(const Color(0x33FFE0B0)));
    }
    c.drawCircle(_cup, _cupR, D.stroke(const Color(0xFF3A1A0A), 3));
  }

  void _drawTargetGuide(Canvas c) {
    if (_done) return;
    c.save();
    c.translate(_cup.dx, _cup.dy);
    final a = .35 + .2 * M.wave(_t, 1.2);
    c.drawPath(_target, D.fill(Color.fromRGBO(255, 255, 255, a * .25)));
    // dashed outline
    final dash = D.stroke(Color.fromRGBO(255, 255, 255, a + .2), 3);
    for (final m in _target.computeMetrics()) {
      var d = (_t * 20) % 16;
      while (d < m.length) {
        c.drawPath(m.extractPath(d, min(m.length, d + 9)), dash);
        d += 16;
      }
    }
    c.restore();
  }

  void _drawFoam(Canvas c) {
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: _cup, radius: _cupR)));
    final edge = D.fill(const Color(0xFFE9CFA8));
    for (final b in _blobs) {
      c.drawCircle(b.p, b.r + 2.5, edge);
    }
    final white = D.fill(const Color(0xFFFFFBF2));
    for (final b in _blobs) {
      c.drawCircle(b.p, b.r, white);
    }
    c.restore();
  }

  void _drawJug(Canvas c) {
    final p = _pouring ? _pp : const Offset(236, 618);
    // milk stream
    if (_pouring && _milk > 0) {
      final spout = p + const Offset(30, -64);
      final path = Path()
        ..moveTo(spout.dx - 3, spout.dy)
        ..quadraticBezierTo(spout.dx - 16, spout.dy + 30, p.dx - 2, p.dy)
        ..lineTo(p.dx + 4, p.dy)
        ..quadraticBezierTo(spout.dx - 8, spout.dy + 30, spout.dx + 3, spout.dy)
        ..close();
      c.drawPath(path, D.fill(const Color(0xFFFFFBF2)));
      c.drawCircle(p, 5 + sin(_t * 30) * 1.5, D.fill(const Color(0xFFFFFBF2)));
    }
    c.save();
    c.translate(p.dx + 52, p.dy - 90);
    c.rotate(-.5 * _jugTilt - .1);
    // steel pitcher
    final body = Path()
      ..moveTo(-26, -40)
      ..lineTo(26, -40)
      ..lineTo(32, 40)
      ..lineTo(-32, 40)
      ..close();
    c.drawPath(
        body,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFF8F99A6), Color(0xFFF0F4F8), Color(0xFF9AA4B0)])
              .createShader(const Rect.fromLTWH(-32, -40, 64, 80)));
    // milk level window
    c.drawRect(Rect.fromLTWH(-20, 36 - 70 * _milk, 8, 70 * _milk), D.fill(const Color(0xAAFFFFFF)));
    c.drawPath(body, D.stroke(Pal.ink, 3));
    c.drawPath(
        Path()
          ..moveTo(-26, -40)
          ..lineTo(-40, -52)
          ..lineTo(-22, -46),
        D.stroke(Pal.ink, 3));
    c.drawArc(const Rect.fromLTWH(22, -24, 30, 44), -pi / 2, pi, false, D.stroke(const Color(0xFF9AA4B0), 7));
    c.drawArc(const Rect.fromLTWH(22, -24, 30, 44), -pi / 2, pi, false, D.stroke(Pal.ink, 2));
    c.restore();
  }

  void _drawHud(Canvas c) {
    // target card
    D.rrect(c, const Rect.fromLTWH(10, 46, 84, 84), 14, const Color(0xE6FFF4DC), border: Pal.ink, borderWidth: 2.5);
    c.save();
    c.translate(52, 90);
    c.scale(.3);
    c.drawCircle(Offset.zero, 130, D.fill(const Color(0xFF8A4F22)));
    c.drawPath(_target, D.fill(const Color(0xFFFFFBF2)));
    c.restore();
    // live match meter
    final pct = _done ? _shownPct.round() : _pct;
    D.rrect(c, const Rect.fromLTWH(110, 52, 240, 40), 20, const Color(0xDD1B1530), border: Pal.white, borderWidth: 2);
    D.bar(c, const Rect.fromLTWH(122, 66, 150, 14), pct / 100, pct >= _winPct ? Pal.lime : Pal.orange);
    // threshold tick
    c.drawLine(const Offset(122 + 150 * _winPct / 100, 60), const Offset(122 + 150 * _winPct / 100, 86), D.stroke(Pal.white, 2.5));
    D.text(c, '$pct%', const Offset(312, 72), size: 20, color: pct >= _winPct ? Pal.lime : Pal.white, stroke: Pal.ink);
    // milk meter
    D.text(c, host.tr('milk', 'MILK'), const Offset(138, 108), size: 13, color: Pal.white, stroke: Pal.ink);
    D.bar(c, const Rect.fromLTWH(168, 101, 120, 12), _milk, Pal.white, border: Pal.ink);
    // serve button
    if (!_done && _hit > _targetCount * .25) {
      final s = 1 + .04 * sin(_t * 8) - _serveBtnPress * .08;
      c.save();
      c.translate(_serveRect.center.dx, _serveRect.center.dy);
      c.scale(s);
      D.button(c, Rect.fromCenter(center: Offset.zero, width: _serveRect.width, height: _serveRect.height),
          host.tr('serve', 'SERVE'), color: Pal.pink);
      c.restore();
    }
  }

  void _drawResult(Canvas c) {
    final k = M.easeOutBack(min(1.0, _doneT * 2.5));
    final ok = _finalPct >= _winPct;
    final face = !ok ? (_finalPct < 25 ? Face.dead : Face.shocked) : (_finalPct >= 80 ? Face.love : Face.happy);
    c.save();
    c.translate(180, 170);
    c.scale(k);
    if (ok) D.rays(c, Offset.zero, 160, const Color(0x33FFE27A), count: 14, t: _t);
    D.blob(c, Offset.zero, 44, ok ? const Color(0xFFFFB3D9) : const Color(0xFFB0C4DE), face: face,
        squash: 1 + sin(_doneT * 10) * .05);
    D.text(c, '${_shownPct.round()}%', const Offset(0, 62), size: 34, color: ok ? Pal.lime : Pal.red, stroke: Pal.ink);
    c.restore();
    if (ok && _finalPct >= 80) {
      D.heart(c, Offset(120 + sin(_t * 3) * 6, 130 - (_doneT * 40) % 60), 22, Pal.red, border: Pal.ink);
      D.heart(c, Offset(242 + cos(_t * 3) * 6, 120 - (_doneT * 50) % 60), 18, Pal.pink, border: Pal.ink);
    }
    final word = ok
        ? (_finalPct >= 80 ? host.tr('wow', 'WOW!') : host.tr('nice', 'NICE!'))
        : host.tr('oops', 'OOPS...');
    D.title(c, word, const Offset(180, 520), size: 40, scale: k, rotate: -.05, color: ok ? Pal.yellow : Pal.red);
  }
}

class _Blob {
  _Blob(this.p, this.target) : r = 3;
  final Offset p;
  double r;
  double target;
}
