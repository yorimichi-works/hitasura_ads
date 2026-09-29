import '../engine/engine.dart';

/// No.144 Glow Up Makeover — pop the pimples, slap on a mask and PEEL it,
/// then pick hair / lipstick / accessory to match the client's GOAL card.
/// Ends with a before/after split reveal and a cheering crowd.
class G144 extends MiniGame {
  static const _o = Offset(180, 285);
  static const _r = 92.0;
  static const _hairCols = [Color(0xFF2A2340), Color(0xFFF2C14E), Color(0xFFFF8FC8)];
  static const _lipCols = [Color(0xFFE0245E), Color(0xFFFF7FA8), Color(0xFF9B2A7A), Color(0xFFFF8A4C)];
  static const _pimpleSpots = [
    Offset(-52, 22), Offset(48, 32), Offset(-18, 58), Offset(58, -4), Offset(-60, -12), Offset(20, 8),
  ];

  double _t = 0;
  int _step = 0; // 0 pimples, 1 mask, 2 hair, 3 lips, 4 item, 5 reveal
  double _stepT = 0;
  final _popped = List<bool>.filled(6, false);
  final _popAnim = List<double>.filled(6, 0);
  bool _maskOn = false;
  bool _dragMask = false;
  Offset _maskPos = const Offset(180, 560);
  double _peel = 0;
  double? _peelY;
  int _hair = -1, _lip = -1, _acc = -1;
  late int _gHair, _gLip, _gAcc;
  double _poof = 0;
  double _revealT = -1;
  int _matches = 0;
  double _face = 0; // wobble on actions

  @override
  Color get backdrop => const Color(0xFF3A1030);

  @override
  void init() {
    _gHair = randInt(3);
    _gLip = randInt(4);
    _gAcc = randInt(3);
  }

  bool get _glow => _maskOn && _peel >= 1;

  void _next() {
    _step++;
    _stepT = 0;
    host.sfx(Sfx.levelup, volume: .6, rate: 1 + _step * .06);
    if (_step == 5) _startReveal();
  }

  void _startReveal() {
    _revealT = 0;
    _matches = (_hair == _gHair ? 1 : 0) + (_lip == _gLip ? 1 : 0) + (_acc == _gAcc ? 1 : 0);
    host.sfx(Sfx.drumroll, volume: .8);
  }

  @override
  void update(double dt) {
    _t += dt;
    _stepT += dt;
    _poof = M.approach(_poof, 0, 5, dt);
    _face = M.approach(_face, 0, 6, dt);
    for (var i = 0; i < 6; i++) {
      if (_popped[i]) _popAnim[i] = min(1, _popAnim[i] + dt * 2.5);
    }
    if (_step == 1 && _maskOn && _peel >= 1 && _stepT > .1) {
      // wait for peel to finish animating
    }
    if (_revealT >= 0) {
      final prev = _revealT;
      _revealT += dt;
      if (prev < .9 && _revealT >= .9) {
        host.sfx(Sfx.cheer);
        host.sfx(Sfx.ssr, volume: .7);
        host.flash(Pal.white, .25);
        host.fx.confetti(count: 90);
        host.addScore(1000 + _matches * 1000);
        if (_matches == 3) {
          host.fx.pop(host.tr('perfect', 'PERFECT!'), const Offset(180, 130), color: Pal.yellow, size: 40, life: 1.4);
        }
      }
      if (_revealT > .9 && (_revealT * 5).floor() != (prev * 5).floor()) {
        host.fx.pop(host.tr('wow', 'WOW!'), Offset(rand(40, 320), rand(480, 540)), color: pick(Pal.candy), size: 22);
        host.fx.sparkle(Offset(rand(190, 340), rand(160, 400)), count: 4, color: Pal.yellow);
      }
      if (_revealT > 2.1 && !host.finished) {
        host.win(stars: _matches == 3 ? 3 : (_matches == 2 ? 2 : 1));
      }
    }
  }

  List<Offset> get _choiceCenters {
    final n = _step == 3 ? 4 : 3;
    return [for (var i = 0; i < n; i++) Offset(180 + (i - (n - 1) / 2) * 80, 562)];
  }

  @override
  void onDown(Offset p) {
    if (_revealT >= 0) return;
    switch (_step) {
      case 0:
        for (var i = 0; i < 6; i++) {
          if (_popped[i]) continue;
          if ((p - (_o + _pimpleSpots[i])).distance < 24) {
            _popped[i] = true;
            _face = 1;
            final n = _popped.where((b) => b).length;
            host.sfx(Sfx.squish, rate: .9 + n * .08);
            host.sfx(Sfx.pop, volume: .6, rate: 1 + n * .1);
            host.fx.burst(_o + _pimpleSpots[i], const Color(0xFFFFF6D8), count: 10, speed: 170, size: 5, gravity: 500);
            host.fx.ring(_o + _pimpleSpots[i], Pal.white, size: 30, life: .3);
            host.addScore(50, _o + _pimpleSpots[i] + const Offset(0, -24));
            if (n == 6) _next();
            return;
          }
        }
      case 1:
        if (!_maskOn && (p - const Offset(180, 562)).distance < 50) {
          _dragMask = true;
          _maskPos = p;
          host.sfx(Sfx.squish, volume: .6, rate: .8);
        } else if (_maskOn && _peel < 1) {
          _peelY = p.dy;
        }
      default:
        if (_step >= 2 && _step <= 4) {
          final cs = _choiceCenters;
          for (var i = 0; i < cs.length; i++) {
            if ((p - cs[i]).distance < 36) {
              _choose(i);
              return;
            }
          }
        }
    }
  }

  void _choose(int i) {
    _poof = 1;
    _face = 1;
    final match = switch (_step) { 2 => i == _gHair, 3 => i == _gLip, _ => i == _gAcc };
    switch (_step) {
      case 2:
        _hair = i;
        host.fx.smoke(_o + const Offset(0, -80), count: 10, color: const Color(0xDDFFFFFF), size: 26);
      case 3:
        _lip = i;
      case 4:
        _acc = i;
    }
    host.sfx(Sfx.magic, rate: 1 + _step * .05);
    host.fx.sparkle(_o, count: 14, radius: 90, color: Pal.yellow);
    if (match) {
      host.sfx(Sfx.correct, volume: .7);
      host.fx.pop(host.tr('nice', 'NICE!'), _o + const Offset(0, -130), color: Pal.lime, size: 26);
      host.addScore(300);
    } else {
      host.fx.pop(host.tr('good', 'GOOD'), _o + const Offset(0, -130), color: Pal.sky, size: 22);
      host.addScore(100);
    }
    _next();
  }

  @override
  void onMove(Offset p) {
    if (_dragMask) {
      _maskPos = p;
    } else if (_peelY != null && _step == 1) {
      final d = (_peelY! - p.dy) / 170;
      if (d > 0) {
        final before = _peel;
        _peel = min(1, _peel + d);
        _peelY = p.dy;
        if ((before * 8).floor() != (_peel * 8).floor()) host.sfx(Sfx.rip, volume: .5, rate: 1 + _peel * .5);
        if (_peel >= 1) {
          _peelY = null;
          host.sfx(Sfx.sparkle);
          host.flash(const Color(0xFFFFF4FA), .2);
          host.fx.sparkle(_o, count: 20, radius: 90);
          host.fx.burst(_o + const Offset(0, -110), const Color(0xFF8FE39A), count: 14, speed: 240, shape: PartShape.square);
          host.addScore(200, _o + const Offset(0, -40));
          host.punch(.03);
          _next();
        }
      }
    }
  }

  @override
  void onUp(Offset p) {
    if (_dragMask) {
      _dragMask = false;
      if ((p - _o).distance < 100) {
        _maskOn = true;
        _face = 1;
        host.sfx(Sfx.splat);
        host.shake(3);
        host.fx.burst(_o, const Color(0xFF7ED68A), count: 14, speed: 200, size: 7);
      } else {
        host.sfx(Sfx.boing, volume: .5);
      }
      _maskPos = const Offset(180, 562);
    }
    _peelY = null;
  }

  @override
  void onTimeUp() {
    if (_revealT >= 0) {
      host.win(stars: _matches == 3 ? 3 : (_matches == 2 ? 2 : 1));
    } else if (_step >= 3) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFFFFC6E0), Color(0xFFFF8FC0), Color(0xFFB44D9A)]);
    // wallpaper dots
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 9; x++) {
        c.drawCircle(Offset(x * 44.0 + (y.isEven ? 0 : 22), y * 44.0), 4, D.fill(const Color(0x22FFFFFF)));
      }
    }
    // vanity mirror with bulbs
    const mirror = Rect.fromLTWH(34, 120, 292, 340);
    D.rrect(c, mirror.inflate(14), 150, const Color(0xFFFFE6A8), border: Pal.ink, borderWidth: 4);
    D.rrect(c, mirror, 140, const Color(0xFFBFE8F4));
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(mirror, const Radius.circular(140)));
    c.drawPath(
        Path()
          ..moveTo(40, 300)
          ..lineTo(140, 120)
          ..lineTo(180, 120)
          ..lineTo(80, 330)
          ..close(),
        D.fill(const Color(0x55FFFFFF)));
    c.restore();
    for (var i = 0; i < 12; i++) {
      final a = pi + i / 11 * pi;
      final b = const Offset(180, 290) + Offset(cos(a) * 172, sin(a) * 186);
      final on = _revealT >= 0 ? ((i + (_t * 10).floor()) % 2 == 0) : true;
      D.circle(c, b, 9, on ? const Color(0xFFFFF7C2) : const Color(0xFFC9A96A), border: Pal.ink, borderWidth: 2);
      if (on) D.circle(c, b, 14, const Color(0x33FFF7C2));
    }

    if (_revealT >= 0) {
      _renderReveal(c);
    } else {
      _drawPerson(c, _o, _r, after: true);
      _renderTray(c);
    }
    _renderGoal(c);
  }

  void _renderGoal(Canvas c) {
    const card = Rect.fromLTWH(92, 44, 176, 58);
    D.rrect(c, card.shift(const Offset(0, 4)), 14, const Color(0x44000000));
    D.rrect(c, card, 14, Pal.white, border: Pal.ink, borderWidth: 3);
    D.rrect(c, const Rect.fromLTWH(92, 44, 50, 58), 14, Pal.pink);
    D.text(c, host.tr('goal', 'GOAL'), const Offset(117, 73), size: 13, color: Pal.white, stroke: Pal.ink, maxWidth: 46);
    // hair icon
    _hairIcon(c, const Offset(166, 74), _gHair, 17);
    // lipstick swatch
    _lipIcon(c, const Offset(208, 73), _gLip, .9);
    _accIcon(c, const Offset(246, 73), _gAcc, .55);
    final done = [_hair == _gHair, _lip == _gLip, _acc == _gAcc];
    final set = [_hair >= 0, _lip >= 0, _acc >= 0];
    for (var i = 0; i < 3; i++) {
      if (!set[i]) continue;
      final p = Offset(178 + i * 40.0, 92);
      D.circle(c, p, 7, done[i] ? Pal.lime : Pal.gray, border: Pal.ink, borderWidth: 2);
    }
  }

  void _renderTray(Canvas c) {
    const tray = Rect.fromLTWH(14, 506, 332, 112);
    D.rrect(c, tray.shift(const Offset(0, 5)), 22, const Color(0x55000000));
    D.rrect(c, tray, 22, const Color(0xFFFFF1F7), border: Pal.ink, borderWidth: 3);
    final label = switch (_step) {
      0 => host.tr('tap', 'TAP!'),
      1 => _maskOn ? host.tr('peel', 'PEEL!') : host.tr('drag', 'DRAG!'),
      2 => host.tr('hair', 'HAIR'),
      3 => host.tr('lips', 'LIPS'),
      _ => host.tr('item', 'ITEM'),
    };
    D.rrect(c, const Rect.fromLTWH(118, 492, 124, 28), 14, Pal.purple, border: Pal.ink, borderWidth: 3);
    D.text(c, label, const Offset(180, 506), size: 16, color: Pal.white, stroke: Pal.ink, maxWidth: 116);
    // step dots
    for (var i = 0; i < 5; i++) {
      D.circle(c, Offset(36 + i * 14.0, 604), 4.5, i < _step ? Pal.pink : (i == _step ? Pal.yellow : const Color(0x33000000)));
    }
    switch (_step) {
      case 0:
        final left = _popped.where((b) => !b).length;
        for (var i = 0; i < 6; i++) {
          D.circle(c, Offset(115 + i * 26.0, 565), 9, i < 6 - left ? Pal.lime : const Color(0xFFE85A6A),
              border: Pal.ink, borderWidth: 2);
        }
        if (_stepT < 2.5) {
          final i = _popped.indexOf(false);
          if (i >= 0) D.hand(c, _o + _pimpleSpots[i], _t);
        }
      case 1:
        if (!_maskOn) {
          // jar
          D.rrect(c, const Rect.fromLTWH(146, 540, 68, 50), 12, const Color(0xFFEAF7EA), border: Pal.ink, borderWidth: 3);
          D.rrect(c, const Rect.fromLTWH(142, 530, 76, 16), 6, const Color(0xFF3FAF6A), border: Pal.ink, borderWidth: 3);
          D.circle(c, const Offset(180, 568), 12, const Color(0xFF7ED68A));
          if (!_dragMask) {
            final k = (_stepT * .8) % 1;
            D.hand(c, Offset.lerp(const Offset(180, 560), _o, M.easeInOut(k))!, _t, size: 38);
          }
        } else {
          D.arrow(c, Offset(300, 570 - (_t * 40) % 20), const Offset(0, -1), 50, Pal.lime, width: 12);
          D.arrow(c, Offset(60, 570 - (_t * 40) % 20), const Offset(0, -1), 50, Pal.lime, width: 12);
          D.bar(c, const Rect.fromLTWH(110, 556, 140, 16), _peel, Pal.lime, border: Pal.ink);
        }
      default:
        final cs = _choiceCenters;
        for (var i = 0; i < cs.length; i++) {
          final bob = sin(_t * 5 + i) * 2;
          final ctr = cs[i] + Offset(0, bob);
          D.circle(c, ctr + const Offset(0, 4), 32, const Color(0x44000000));
          D.circle(c, ctr, 32, Pal.white, border: Pal.ink, borderWidth: 3);
          switch (_step) {
            case 2:
              _hairIcon(c, ctr + const Offset(0, 2), i, 20);
            case 3:
              _lipIcon(c, ctr, i, 1.3);
            default:
              _accIcon(c, ctr, i, .8);
          }
        }
    }
    if (_dragMask) {
      c.save();
      c.translate(_maskPos.dx, _maskPos.dy);
      c.scale(.8);
      _maskSheet(c, 1);
      c.restore();
    }
  }

  void _maskSheet(Canvas c, double alpha) {
    final r = Rect.fromCenter(center: Offset.zero, width: _r * 1.7, height: _r * 1.9);
    c.drawOval(r, D.fill(const Color(0xFF8FE39A).withValues(alpha: .95 * alpha)));
    c.drawOval(r, D.stroke(const Color(0xFF3FAF6A), 3));
    for (final s in [-1.0, 1.0]) {
      D.circle(c, Offset(s * 34, -14), 17, const Color(0xFFD8F5C0), border: const Color(0xFF3FAF6A), borderWidth: 3);
      for (var k = 0; k < 6; k++) {
        D.circle(c, Offset(s * 34, -14) + Offset.fromDirection(k * pi / 3, 9), 2, const Color(0xFFA8D890));
      }
    }
  }

  void _renderReveal(Canvas c) {
    final k = M.easeInOut((_revealT / .8).clamp(0, 1));
    final split = 360 - k * 180;
    // BEFORE (left)
    c.save();
    c.clipRect(Rect.fromLTWH(0, 100, split, 440));
    _drawPerson(c, _o, _r, after: false);
    c.drawRect(const Rect.fromLTWH(0, 100, 360, 440), D.fill(const Color(0x33203040)));
    c.restore();
    // AFTER (right)
    c.save();
    c.clipRect(Rect.fromLTWH(split, 100, 360 - split, 440));
    D.rays(c, _o, 400, const Color(0x44FFFFFF), count: 14, t: _t);
    _drawPerson(c, _o, _r, after: true);
    c.restore();
    D.line(c, Offset(split, 104), Offset(split, 536), Pal.white, 6);
    D.circle(c, Offset(split, 320), 16, Pal.white, border: Pal.ink, borderWidth: 3);
    D.text(c, '< >', Offset(split, 320), size: 12, color: Pal.ink);
    if (k > .5) {
      D.title(c, host.tr('before', 'BEFORE'), const Offset(90, 140), size: 22, color: const Color(0xFFB8B3D6), rotate: -.08);
      D.title(c, host.tr('after', 'AFTER'), const Offset(272, 140), size: 26, color: Pal.yellow, rotate: .08);
    }
    // crowd
    for (var i = 0; i < 6; i++) {
      final x = 30 + i * 60.0;
      final jump = _revealT > .9 ? (sin(_t * 12 + i * 1.7)).abs() * 14 : 0.0;
      final col = [Pal.sky, Pal.orange, Pal.lime, Pal.purple, Pal.teal, Pal.red][i];
      c.drawOval(Rect.fromCenter(center: Offset(x, 640 - jump), width: 70, height: 80), D.fill(col));
      D.circle(c, Offset(x, 580 - jump), 26, Pal.skin, border: Pal.ink, borderWidth: 3);
      D.face(c, Offset(x, 582 - jump), 22, _revealT > .9 ? (i.isEven ? Face.love : Face.shocked) : Face.neutral);
    }
  }

  // ---------------------------------------------------------------- person

  void _drawPerson(Canvas c, Offset o, double r, {required bool after}) {
    final hair = after ? _hair : -1;
    final glow = after && _glow;
    final wob = after ? _face : 0.0;
    final skin = glow ? const Color(0xFFFFD9BE) : const Color(0xFFD7B196);
    c.save();
    c.translate(o.dx, o.dy);
    final s = 1 + wob * .04 * sin(_t * 30) + (after ? _poof * .05 : 0);
    c.scale(s, 2 - s);
    // shoulders
    c.drawOval(Rect.fromCenter(center: Offset(0, r * 2.2), width: r * 2.6, height: r * 1.6),
        D.fill(glow ? const Color(0xFF7A4DFF) : const Color(0xFF7B7486)));
    c.drawRect(Rect.fromCenter(center: Offset(0, r * 1.05), width: r * .5, height: r * .6), D.fill(skin));
    _hairBack(c, r, hair);
    // head
    final head = Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 2.05);
    c.drawOval(head, D.fill(skin));
    if (glow) {
      c.drawOval(Rect.fromCenter(center: Offset(-r * .35, -r * .45), width: r * .5, height: r * .3), D.fill(const Color(0x66FFFFFF)));
    }
    c.drawOval(head, D.stroke(Pal.ink, 4));
    // ears
    for (final sx in [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(sx * r * .9, r * .05), width: r * .28, height: r * .42), D.fill(skin));
      c.drawOval(Rect.fromCenter(center: Offset(sx * r * .9, r * .05), width: r * .28, height: r * .42), D.stroke(Pal.ink, 3));
    }
    // eyes
    for (final sx in [-1.0, 1.0]) {
      final e = Offset(sx * r * .36, -r * .1);
      if (glow) {
        c.drawOval(Rect.fromCenter(center: e, width: r * .34, height: r * .4), D.fill(Pal.white));
        c.drawOval(Rect.fromCenter(center: e, width: r * .34, height: r * .4), D.stroke(Pal.ink, 3));
        D.circle(c, e + const Offset(0, 2), r * .12, const Color(0xFF6B3AB0));
        D.circle(c, e + const Offset(0, 2), r * .06, Pal.ink);
        D.circle(c, e + Offset(-r * .04, -r * .04), r * .045, Pal.white);
        D.circle(c, e + Offset(r * .05, r * .06), r * .025, Pal.white);
        for (var k = 0; k < 3; k++) {
          final a = -pi / 2 + sx * (.2 + k * .35);
          D.line(c, e + Offset(cos(a) * r * .18, sin(a) * r * .22), e + Offset(cos(a) * r * .28, sin(a) * r * .3), Pal.ink, 3);
        }
        c.drawArc(Rect.fromCenter(center: e + Offset(0, -r * .28), width: r * .34, height: r * .12), pi, pi, false,
            D.stroke(const Color(0xFF3A2A30), 4));
      } else {
        // tired: bags + droopy lids
        c.drawArc(Rect.fromCenter(center: e + Offset(0, r * .14), width: r * .34, height: r * .16), 0, pi, false,
            D.stroke(const Color(0xFF7A5A8A), 4));
        c.drawOval(Rect.fromCenter(center: e, width: r * .3, height: r * .26), D.fill(Pal.white));
        D.circle(c, e + const Offset(0, 3), r * .08, Pal.ink);
        c.drawRect(Rect.fromCenter(center: e + Offset(0, -r * .07), width: r * .34, height: r * .14), D.fill(skin));
        D.line(c, e + Offset(-r * .17, 0), e + Offset(r * .17, 0), Pal.ink, 3);
      }
    }
    // nose
    c.drawArc(Rect.fromCenter(center: Offset(0, r * .2), width: r * .18, height: r * .14), 0, pi, false, D.stroke(Pal.ink, 3));
    // blush
    if (glow) {
      for (final sx in [-1.0, 1.0]) {
        c.drawOval(Rect.fromCenter(center: Offset(sx * r * .55, r * .3), width: r * .3, height: r * .16), D.fill(const Color(0x66FF5F7A)));
      }
    }
    // pimples
    for (var i = 0; i < 6; i++) {
      final popped = after && _popped[i];
      final p = _pimpleSpots[i];
      if (popped) {
        final a = 1 - _popAnim[i];
        if (a > 0) D.circle(c, p, 9 * a, Color.fromRGBO(255, 180, 190, a));
        continue;
      }
      D.circle(c, p, 13, const Color(0x55D0303F));
      D.circle(c, p, 8.5, const Color(0xFFE85A6A), border: const Color(0xFF9A2030), borderWidth: 1.5);
      D.circle(c, p + const Offset(-2, -2.5), 3.2, const Color(0xFFFFF0C0));
    }
    // lips
    final lip = after ? _lip : -1;
    final m = Offset(0, r * .52);
    if (lip >= 0) {
      final col = _lipCols[lip];
      final path = Path()
        ..moveTo(m.dx - r * .26, m.dy)
        ..quadraticBezierTo(m.dx - r * .12, m.dy - r * .14, m.dx, m.dy - r * .05)
        ..quadraticBezierTo(m.dx + r * .12, m.dy - r * .14, m.dx + r * .26, m.dy)
        ..quadraticBezierTo(m.dx, m.dy + r * .22, m.dx - r * .26, m.dy)
        ..close();
      c.drawPath(path, D.fill(col));
      c.drawPath(path, D.stroke(Pal.ink, 3));
      D.line(c, m + Offset(-r * .22, 0), m + Offset(r * .22, 0), Color.lerp(col, Pal.ink, .5)!, 2);
      c.drawOval(Rect.fromCenter(center: m + Offset(-r * .06, r * .07), width: r * .1, height: r * .04), D.fill(const Color(0x88FFFFFF)));
    } else if (glow) {
      c.drawArc(Rect.fromCenter(center: m, width: r * .4, height: r * .22), .1, pi - .2, false, D.stroke(Pal.ink, 4));
    } else {
      c.drawArc(Rect.fromCenter(center: m + Offset(0, r * .08), width: r * .36, height: r * .16), pi + .2, pi - .4, false,
          D.stroke(Pal.ink, 4));
    }
    // mask layer
    if (after && _maskOn && _peel < 1) {
      c.save();
      final top = -r * 1.0 + _peel * r * 2.0;
      c.clipRect(Rect.fromLTRB(-r * 1.2, top, r * 1.2, r * 1.2));
      _maskSheet(c, 1);
      c.restore();
      if (_peel > 0) {
        // curling flap
        final flap = Rect.fromCenter(center: Offset(0, top - 6), width: r * 1.5, height: 16);
        D.rrect(c, flap, 8, const Color(0xFFB8F0BE), border: const Color(0xFF3FAF6A), borderWidth: 2);
      }
    }
    _hairFront(c, r, hair);
    // accessory
    final acc = after ? _acc : -1;
    if (acc >= 0) {
      c.save();
      switch (acc) {
        case 0:
          c.translate(0, -r * 1.12);
          _accIcon(c, Offset.zero, 0, 1.3);
        case 1:
          c.translate(0, -r * .1);
          _accIcon(c, Offset.zero, 1, 1.25);
        default:
          c.translate(r * .72, -r * .78);
          _accIcon(c, Offset.zero, 2, 1.2);
      }
      c.restore();
    }
    c.restore();
    if (!after || (!_glow && _step < 2)) {
      // stink / gloom lines
      for (var i = 0; i < 3; i++) {
        final x = o.dx - r * 1.2 + i * 12;
        final y = o.dy - r * .3 + sin(_t * 3 + i) * 5;
        D.line(c, Offset(x, y), Offset(x + 4, y - 16), const Color(0x886A5A8A), 3);
      }
    }
    if (glow && after) {
      for (var i = 0; i < 4; i++) {
        final a = _t * 1.5 + i * pi / 2;
        final p = o + Offset(cos(a) * r * 1.25, sin(a) * r * 1.1);
        final k = M.wave(_t * 1.3 + i * .25);
        c.drawPath(D.starPath(p, 6 + k * 8, 2, points: 4, rotation: 0), D.fill(Pal.white));
      }
    }
  }

  void _hairBack(Canvas c, double r, int style) {
    switch (style) {
      case 1: // long waves
        final col = _hairCols[1];
        final path = Path()..moveTo(-r * 1.0, -r * .3);
        for (var i = 0; i <= 6; i++) {
          path.lineTo(-r * 1.05 - sin(i * 1.3 + _t * 2) * 6, -r * .3 + i * r * .28);
        }
        path
          ..quadraticBezierTo(0, r * 1.9, r * 1.05, r * 1.4)
          ..lineTo(r * 1.0, -r * .3)
          ..close();
        c.drawPath(path, D.fill(col));
        c.drawPath(path, D.stroke(Pal.ink, 4));
      case 0: // bob
        final rr = RRect.fromRectAndRadius(Rect.fromLTRB(-r * 1.08, -r * .9, r * 1.08, r * .75), Radius.circular(r * .6));
        c.drawRRect(rr, D.fill(_hairCols[0]));
        c.drawRRect(rr, D.stroke(Pal.ink, 4));
      default:
    }
  }

  void _hairFront(Canvas c, double r, int style) {
    switch (style) {
      case -1: // messy spikes
        final path = Path()..moveTo(-r * .95, -r * .1);
        for (var i = 0; i <= 12; i++) {
          final a = pi + i / 12 * pi;
          final len = i.isEven ? 1.25 : .95;
          path.lineTo(cos(a) * r * .95 * len, -r * .1 + sin(a) * r * 1.02 * len);
        }
        path
          ..quadraticBezierTo(r * .3, -r * .5, -r * .95, -r * .1)
          ..close();
        c.drawPath(path, D.fill(const Color(0xFF6A4A3A)));
        c.drawPath(path, D.stroke(Pal.ink, 4));
        // flyaways
        D.line(c, Offset(-r * .2, -r * 1.2), Offset(-r * .4, -r * 1.45), Pal.ink, 3);
        D.line(c, Offset(r * .3, -r * 1.15), Offset(r * .45, -r * 1.4), Pal.ink, 3);
      case 0: // sleek bob bangs
        final col = _hairCols[0];
        final path = Path()
          ..moveTo(-r * .98, r * .1)
          ..quadraticBezierTo(-r * 1.0, -r * 1.15, 0, -r * 1.1)
          ..quadraticBezierTo(r * 1.0, -r * 1.15, r * .98, r * .1)
          ..lineTo(r * .8, -r * .35)
          ..lineTo(-r * .8, -r * .4)
          ..close();
        c.drawPath(path, D.fill(col));
        c.drawPath(path, D.stroke(Pal.ink, 4));
        c.drawArc(Rect.fromCenter(center: Offset(-r * .2, -r * .75), width: r * .9, height: r * .5), pi * 1.1, .8, false,
            D.stroke(const Color(0x88FFFFFF), 5));
      case 1: // side-swept blonde fringe
        final col = _hairCols[1];
        final path = Path()
          ..moveTo(-r * 1.0, -r * .1)
          ..quadraticBezierTo(-r * .9, -r * 1.2, r * .2, -r * 1.08)
          ..quadraticBezierTo(r * 1.05, -r * .95, r * .98, -r * .05)
          ..quadraticBezierTo(r * .5, -r * .7, -r * .3, -r * .45)
          ..quadraticBezierTo(-r * .7, -r * .35, -r * 1.0, -r * .1)
          ..close();
        c.drawPath(path, D.fill(col));
        c.drawPath(path, D.stroke(Pal.ink, 4));
        c.drawArc(Rect.fromCenter(center: Offset(r * .1, -r * .8), width: r * .9, height: r * .4), pi * 1.1, .9, false,
            D.stroke(const Color(0x99FFFFFF), 5));
      case 2: // pink high bun
        final col = _hairCols[2];
        c.drawCircle(Offset(0, -r * 1.25), r * .42, D.fill(col));
        c.drawCircle(Offset(0, -r * 1.25), r * .42, D.stroke(Pal.ink, 4));
        c.drawArc(Rect.fromCircle(center: Offset(0, -r * 1.25), radius: r * .28), pi * 1.1, 1.2, false, D.stroke(const Color(0x88FFFFFF), 4));
        final path = Path()
          ..moveTo(-r * .92, -r * .05)
          ..quadraticBezierTo(-r * .95, -r * 1.1, 0, -r * 1.05)
          ..quadraticBezierTo(r * .95, -r * 1.1, r * .92, -r * .05)
          ..quadraticBezierTo(r * .6, -r * .75, 0, -r * .72)
          ..quadraticBezierTo(-r * .6, -r * .75, -r * .92, -r * .05)
          ..close();
        c.drawPath(path, D.fill(col));
        c.drawPath(path, D.stroke(Pal.ink, 4));
    }
  }

  void _hairIcon(Canvas c, Offset o, int style, double r) {
    c.save();
    c.translate(o.dx, o.dy + r * .1);
    c.scale(.9);
    _hairBack(c, r, style);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 2.05), D.fill(Pal.skin));
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 2.05), D.stroke(Pal.ink, 2));
    _hairFront(c, r, style);
    c.restore();
  }

  void _lipIcon(Canvas c, Offset o, int i, double s) {
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s);
    D.rrect(c, const Rect.fromLTWH(-8, -2, 16, 18), 3, const Color(0xFFD4A340), border: Pal.ink, borderWidth: 2);
    final tip = Path()
      ..moveTo(-6, -2)
      ..lineTo(-6, -12)
      ..lineTo(6, -18)
      ..lineTo(6, -2)
      ..close();
    c.drawPath(tip, D.fill(_lipCols[i]));
    c.drawPath(tip, D.stroke(Pal.ink, 2));
    c.restore();
  }

  void _accIcon(Canvas c, Offset o, int i, double s) {
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s);
    switch (i) {
      case 0: // crown
        final path = Path()
          ..moveTo(-30, 12)
          ..lineTo(-32, -14)
          ..lineTo(-16, 0)
          ..lineTo(0, -20)
          ..lineTo(16, 0)
          ..lineTo(32, -14)
          ..lineTo(30, 12)
          ..close();
        c.drawPath(path, D.fill(Pal.gold));
        c.drawPath(path, D.stroke(Pal.ink, 3));
        D.gem(c, const Offset(0, 4), 6, Pal.red);
        D.circle(c, const Offset(-32, -14), 4, Pal.sky, border: Pal.ink, borderWidth: 1.5);
        D.circle(c, const Offset(32, -14), 4, Pal.sky, border: Pal.ink, borderWidth: 1.5);
      case 1: // heart sunglasses
        D.line(c, const Offset(-10, -2), const Offset(10, -2), Pal.ink, 4);
        for (final sx in [-1.0, 1.0]) {
          D.heart(c, Offset(sx * 22, 0), 30, const Color(0xFFFF3B8A), border: Pal.ink);
          c.drawOval(Rect.fromCenter(center: Offset(sx * 22 - 5, -5), width: 7, height: 4), D.fill(const Color(0x99FFFFFF)));
        }
      default: // bow
        for (final sx in [-1.0, 1.0]) {
          final w = Path()
            ..moveTo(0, 0)
            ..lineTo(sx * 26, -16)
            ..quadraticBezierTo(sx * 32, 0, sx * 26, 16)
            ..close();
          c.drawPath(w, D.fill(Pal.red));
          c.drawPath(w, D.stroke(Pal.ink, 3));
        }
        D.circle(c, Offset.zero, 7, const Color(0xFFFF6B88), border: Pal.ink, borderWidth: 3);
        for (var k = 0; k < 3; k++) {
          D.circle(c, Offset(-18 + k * 6.0, -4 + k * 3.0), 1.8, Pal.white);
        }
    }
    c.restore();
  }
}
