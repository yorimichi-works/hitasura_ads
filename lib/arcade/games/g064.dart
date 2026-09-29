import '../engine/engine.dart';

/// No.064 Zip It! — drag the jeans zipper to the top before anyone notices.
class G064 extends MiniGame {
  double _t = 0;
  double _pullY = _bottom;
  double _snagY = 0;
  bool _snagged = false; // currently stuck on the snag
  bool _snagDone = false;
  double _snagForce = 0;
  double _wiggle = 0;
  bool _grab = false;
  Offset _last = Offset.zero;
  bool _resolved = false;
  bool _zipped = false;
  double _endT = 0;
  double _tick = 0;
  int _eyesShown = 0;
  late final List<_Peeker> _peekers;
  late final Color _boxer;

  static const _top = 168.0;
  static const _bottom = 560.0;
  static const _x = 180.0;

  @override
  void init() {
    _snagY = rand(300, 420);
    _boxer = pick(const [Pal.pink, Pal.yellow, Pal.lime, Pal.sky]);
    _peekers = [
      _Peeker(const Offset(34, 150), 1),
      _Peeker(const Offset(330, 250), -1),
      _Peeker(const Offset(30, 470), 1),
      _Peeker(const Offset(330, 560), -1),
      _Peeker(const Offset(326, 90), -1),
      _Peeker(const Offset(34, 610), 1),
    ]..shuffle(host.rng);
  }

  double get _progress => M.clamp01((_bottom - _pullY) / (_bottom - _top));

  @override
  void update(double dt) {
    _t += dt;
    _wiggle = M.approach(_wiggle, 0, 10, dt);
    if (_resolved) {
      _endT += dt;
      return;
    }
    // people start to notice
    final want = min(_peekers.length, 1 + (host.time / host.duration * (_peekers.length + .5)).floor());
    while (_eyesShown < want) {
      _peekers[_eyesShown].shown = true;
      _eyesShown++;
      host.sfx(Sfx.pop, rate: 1 + _eyesShown * .1, volume: .6);
    }
    for (final p in _peekers) {
      if (p.shown) p.appear = M.approach(p.appear, 1, 10, dt);
    }
  }

  void _drag(double dy) {
    if (_resolved) return;
    final resist = .6 / pow(host.speed, .35);
    if (dy < 0) {
      var move = min(18.0, -dy * resist);
      if (!_snagDone && _pullY - move <= _snagY) {
        // hit the snag: extra effort needed to rip through
        if (!_snagged) {
          _snagged = true;
          host.sfx(Sfx.clang, volume: .6, rate: 1.4);
          host.shake(3);
          host.fx.pop('!?', Offset(_x + 60, _snagY), color: Pal.yellow, size: 30);
        }
        final over = move - (_pullY - _snagY);
        _pullY = _snagY;
        _snagForce += over;
        _wiggle = 1;
        if (_snagForce > 70) {
          _snagDone = true;
          _snagged = false;
          host.sfx(Sfx.rip);
          host.shake(6);
          host.punch(.04);
          host.fx.burst(Offset(_x, _snagY), const Color(0xFF3D6BFF), count: 10, speed: 180, shape: PartShape.square);
          _pullY -= 20;
        }
        move = 0;
      }
      final before = _pullY;
      _pullY = max(_top, _pullY - move);
      _tick += before - _pullY;
      if (_tick > 26) {
        _tick = 0;
        host.sfx(Sfx.tick, rate: 1 + _progress * .8, volume: .5);
      }
      if (_pullY <= _top) _win();
    } else if (!_snagged) {
      _pullY = min(_bottom, _pullY + dy * .25);
    }
  }

  void _win() {
    _resolved = true;
    _zipped = true;
    host.sfx(Sfx.swipe, rate: 1.3);
    host.sfx(Sfx.stamp);
    host.sfx(Sfx.correct, volume: .8);
    host.shake(6);
    host.punch(.06);
    host.hitStop(.06);
    host.fx.sparkle(const Offset(_x, 130), count: 16, radius: 60, color: Pal.yellow);
    host.fx.ring(const Offset(_x, 120), Pal.white, size: 90);
    host.fx.pop(host.tr('safe', 'SAFE!'), const Offset(180, 260), color: Pal.lime, size: 42);
    host.win(stars: host.time < 2.6 ? 3 : (host.time < 3.8 ? 2 : 1));
  }

  @override
  void onDown(Offset p) {
    _grab = true;
    _last = p;
  }

  @override
  void onMove(Offset p) {
    if (!_grab) return;
    _drag(p.dy - _last.dy);
    _last = p;
  }

  @override
  void onUp(Offset p) => _grab = false;

  @override
  void onKey(String key, bool down) {
    if (down && (key == 'up' || key == 'action')) _drag(-45);
  }

  @override
  void onTimeUp() {
    _resolved = true;
    host.sfx(Sfx.shake);
    host.flash(Pal.white, .3);
    host.fx.pop(host.tr('oops', 'OOPS!'), const Offset(180, 300), color: Pal.red, size: 44);
    for (final p in _peekers) {
      p.shown = true;
      p.appear = 1;
    }
    host.lose();
  }

  // x offset of each tooth row at height y (0 when closed)
  double _gap(double y) {
    if (y >= _pullY) return 6;
    return 6 + min(46.0, (_pullY - y) * .22);
  }

  @override
  void render(Canvas c) {
    // denim
    D.gradientBg(c, const [Color(0xFF2E5AA8), Color(0xFF3D6BC8), Color(0xFF24488E)]);
    final tw = Paint()
      ..color = const Color(0x16FFFFFF)
      ..strokeWidth = 2;
    for (var x = -640.0; x < 360; x += 7) {
      c.drawLine(Offset(x, 640), Offset(x + 640, 0), tw);
    }
    D.rays(c, Offset(_x, _pullY), 700, const Color(0x10FFFFFF), count: 16, t: _t * .3);
    // fly placket (overlapping flap on the left)
    final flap = Path()
      ..moveTo(_x - 70, 110)
      ..lineTo(_x - 70, 500)
      ..quadraticBezierTo(_x - 66, 590, _x + 4, 600)
      ..lineTo(_x + 4, 640)
      ..lineTo(_x - 90, 640)
      ..lineTo(_x - 90, 110)
      ..close();
    c.drawPath(flap, D.fill(const Color(0x22000000)));
    // J stitching
    final stitch = Path()
      ..moveTo(_x - 58, 110)
      ..lineTo(_x - 58, 500)
      ..quadraticBezierTo(_x - 54, 578, _x + 6, 588);
    _dashed(c, stitch, const Color(0xFFF2A640), 3);
    for (final sx in [-110.0, 110.0]) {
      _dashed(c, Path()
        ..moveTo(_x + sx, 110)
        ..lineTo(_x + sx * 1.2, 640), const Color(0xFFF2A640), 3);
    }
    // waistband
    c.drawRect(const Rect.fromLTWH(0, 40, 360, 72), D.fill(const Color(0xFF2A4F98)));
    _dashed(c, Path()
      ..moveTo(0, 50)
      ..lineTo(360, 50), const Color(0xFFF2A640), 3);
    _dashed(c, Path()
      ..moveTo(0, 104)
      ..lineTo(360, 104), const Color(0xFFF2A640), 3);
    D.line(c, const Offset(0, 112), const Offset(360, 112), const Color(0x55000000), 4);
    for (final bx in [60.0, 300.0]) {
      D.rrect(c, Rect.fromLTWH(bx - 12, 34, 24, 86), 6, const Color(0xFF3563B8), border: const Color(0xFF1B3A78), borderWidth: 3);
    }
    // rivets
    for (final rp in [const Offset(24, 150), const Offset(336, 150)]) {
      D.circle(c, rp, 9, const Color(0xFFC77B30), border: Pal.ink, borderWidth: 3);
      c.drawCircle(rp + const Offset(-3, -3), 3, D.fill(const Color(0x99FFFFFF)));
    }

    // open V showing heart boxers
    final gapPath = Path()..moveTo(_x - _gap(_pullY - 1), _pullY);
    for (var y = _pullY; y >= 112; y -= 8) {
      gapPath.lineTo(_x - _gap(y) + 4, y);
    }
    gapPath.lineTo(_x - _gap(112) + 4, 112);
    gapPath.lineTo(_x + _gap(112) - 4, 112);
    for (var y = 112.0; y <= _pullY; y += 8) {
      gapPath.lineTo(_x + _gap(y) - 4, y);
    }
    gapPath.close();
    if (_pullY > 120) {
      c.save();
      c.clipPath(gapPath);
      c.drawRect(const Rect.fromLTWH(100, 100, 160, 480), D.fill(_boxer));
      for (var y = 110.0; y < _pullY + 20; y += 26) {
        for (var x = 120.0 + ((y ~/ 26).isEven ? 0 : 13); x < 250; x += 26) {
          D.heart(c, Offset(x, y), 14, Pal.red);
        }
      }
      c.restore();
      c.drawPath(gapPath, D.stroke(const Color(0x66000000), 3));
    }

    // teeth
    final tooth = D.fill(const Color(0xFFD9DEE8));
    final toothDark = D.fill(const Color(0xFF8A93A8));
    for (var y = 116.0; y < 590; y += 9) {
      final g = _gap(y);
      final closed = y >= _pullY;
      final lx = _x - g + (closed ? 1 : 0);
      final rx = _x + g - (closed ? 1 : 0);
      final li = ((y - 116) / 9).round().isEven;
      // tape
      c.drawRect(Rect.fromLTWH(lx - 14, y - 1, 10, 10), D.fill(const Color(0xFF1F3F80)));
      c.drawRect(Rect.fromLTWH(rx + 4, y - 1, 10, 10), D.fill(const Color(0xFF1F3F80)));
      if (closed) {
        final r = Rect.fromLTWH(li ? _x - 9 : _x - 3, y, 12, 6);
        c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), tooth);
        c.drawRect(Rect.fromLTWH(r.left, r.bottom - 2, r.width, 2), toothDark);
      } else {
        if (li) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(lx - 6, y, 12, 6), const Radius.circular(2)), tooth);
        } else {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(rx - 6, y, 12, 6), const Radius.circular(2)), tooth);
        }
      }
    }
    // bottom stop
    D.rrect(c, const Rect.fromLTWH(_x - 12, 588, 24, 12), 3, const Color(0xFFB0B6C8), border: Pal.ink, borderWidth: 2.5);

    // snag: a tangled thread
    if (!_snagDone) {
      final sp = Offset(_x, _snagY - 8);
      final th = Path()
        ..moveTo(sp.dx - 22, sp.dy)
        ..cubicTo(sp.dx - 5, sp.dy - 24, sp.dx + 20, sp.dy + 16, sp.dx + 4, sp.dy - 6)
        ..cubicTo(sp.dx - 10, sp.dy - 18, sp.dx + 30, sp.dy - 14, sp.dx + 24, sp.dy + 6);
      c.drawPath(th, D.stroke(Pal.ink, 6));
      c.drawPath(th, D.stroke(Pal.red, 3));
    }

    // button (open until zipped)
    final bc = _zipped ? const Offset(_x, 76) : Offset(_x - 48, 76);
    if (!_zipped) {
      c.drawOval(Rect.fromCenter(center: Offset(_x + 40, 76), width: 12, height: 30), D.fill(const Color(0xFF14264F)));
    }
    final bs = _zipped ? 1 + .3 * max(0.0, 1 - _endT * 4) : 1.0;
    D.circle(c, bc, 22 * bs, const Color(0xFFC98A3A), border: Pal.ink, borderWidth: 4);
    c.drawCircle(bc, 14 * bs, D.stroke(const Color(0xFF8A5620), 3));
    c.drawCircle(bc + const Offset(-7, -7), 5, D.fill(const Color(0x99FFFFFF)));

    _drawPull(c);

    // peeping people
    for (final p in _peekers) {
      if (p.shown) _drawPeeker(c, p);
    }

    // progress meter on the right edge
    final mr = Rect.fromLTWH(344, _top, 8, _bottom - _top);
    D.rrect(c, mr, 4, const Color(0x44000000));
    D.rrect(c, Rect.fromLTRB(mr.left, _pullY, mr.right, mr.bottom), 4, Pal.lime);

    if (host.time < 1.8 && !_resolved) {
      D.arrow(c, Offset(_x + 75, _pullY - 70), const Offset(0, -1), 90, Pal.yellow, width: 14);
      D.hand(c, Offset(_x + 20, _pullY + 40), _t);
      D.text(c, host.tr('swipe', 'SWIPE!'), Offset(_x + 80, _pullY + 60), size: 22, stroke: Pal.ink);
    }
  }

  void _drawPull(Canvas c) {
    final wig = sin(_t * 60) * 4 * _wiggle;
    final o = Offset(_x + wig, _pullY);
    // slider body
    final body = Path()
      ..moveTo(o.dx - 20, o.dy - 18)
      ..lineTo(o.dx + 20, o.dy - 18)
      ..lineTo(o.dx + 14, o.dy + 16)
      ..lineTo(o.dx - 14, o.dy + 16)
      ..close();
    c.drawPath(body.shift(const Offset(3, 4)), D.fill(const Color(0x55000000)));
    c.drawPath(body, D.fill(const Color(0xFFCFD5E2)));
    c.drawPath(body, D.stroke(Pal.ink, 3.5));
    // hanging tab
    final swing = sin(_t * 5) * .08 + (_grab ? -.05 : 0);
    c.save();
    c.translate(o.dx, o.dy + 6);
    c.rotate(swing);
    final tab = RRect.fromRectAndRadius(const Rect.fromLTWH(-15, 0, 30, 66), const Radius.circular(12));
    c.drawRRect(tab.shift(const Offset(3, 4)), D.fill(const Color(0x55000000)));
    c.drawRRect(tab, Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFF5F7FB), Color(0xFF9AA3B8)])
          .createShader(const Rect.fromLTWH(-15, 0, 30, 66)));
    c.drawRRect(tab, D.stroke(Pal.ink, 3.5));
    D.rrect(c, const Rect.fromLTWH(-6, 38, 12, 20), 6, const Color(0xFF2E5AA8), border: Pal.ink, borderWidth: 2.5);
    c.drawRect(const Rect.fromLTWH(-9, 6, 4, 26), D.fill(const Color(0x88FFFFFF)));
    c.restore();
    if (!_resolved && _snagged) {
      D.text(c, '!!', o + const Offset(-44, -20), size: 30, color: Pal.red, stroke: Pal.ink);
    }
  }

  void _drawPeeker(Canvas c, _Peeker p) {
    final a = p.appear;
    final o = p.pos + Offset(p.side * -40 * (1 - a), 0);
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(a, a);
    D.rrect(c, const Rect.fromLTWH(-40, -24, 80, 48), 24, const Color(0xEE0E0B1F));
    final lost = _resolved && !_zipped;
    final bored = _zipped;
    for (final sx in [-15.0, 15.0]) {
      final e = Offset(sx, 0);
      if (bored) {
        D.line(c, e + const Offset(-9, 0), e + const Offset(9, 0), Pal.white, 3.5);
      } else {
        final h = lost ? 24.0 : 18.0;
        c.drawOval(Rect.fromCenter(center: e, width: lost ? 22 : 18, height: h), D.fill(Pal.white));
        final look = Offset(_x - p.pos.dx, _pullY - p.pos.dy);
        final d = max(look.distance, 1.0);
        c.drawCircle(e + look / d * 3.5, lost ? 4 : 5.5, D.fill(Pal.ink));
      }
    }
    c.restore();
    if (_resolved && !_zipped) {
      // they are laughing
      D.text(c, host.tr('haha', 'HAHA'), o + Offset(0, 32), size: 14, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _dashed(Canvas c, Path path, Color color, double w) {
    final p = D.stroke(color, w);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 14) {
        c.drawPath(m.extractPath(d, min(d + 8, m.length)), p);
      }
    }
  }
}

class _Peeker {
  _Peeker(this.pos, this.side);
  final Offset pos;
  final double side;
  bool shown = false;
  double appear = 0;
}
