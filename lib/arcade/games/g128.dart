import '../engine/engine.dart';

/// No.128 Dragon Egg — rub the egg (drag back and forth) to keep its
/// temperature inside the moving green band. Cracks grow while it's cozy;
/// too hot = it starts frying. Hatch it: the baby dragon's color depends on
/// how perfect the care was (common → rare → epic → RAINBOW legendary).
class G128 extends MiniGame {
  double _t = 0;
  double _temp = .44;
  double _progress = 0;
  double _perfectTime = 0, _goodTime = 0;
  double _burn = 0;
  double _wobble = 0;
  double _rubFx = 0;
  Offset? _last;
  double _gust = 0;
  final List<double> _gustAt = [5.5, 10.5];
  int _crackStage = 0;
  final List<List<Offset>> _cracks = [];

  // ending
  double _hatchT = -1;
  int _rarity = 0; // 0 common 1 rare 2 epic 3 legendary
  bool _fried = false;
  double _friedT = 0;
  bool _chick = false;

  static const _egg = Offset(180, 360);
  static const _thermo = Rect.fromLTWH(318, 150, 22, 300);

  double get _bandC => .6 + sin(_t * .65) * .08;
  static const _bandW = .14;

  @override
  void init() {
    // precomputed crack polylines, revealed progressively
    for (var k = 0; k < 6; k++) {
      final pts = <Offset>[];
      var p = Offset(rand(-40, 40), rand(-50, 40));
      pts.add(p);
      for (var i = 0; i < 5; i++) {
        p += Offset(rand(-16, 16), rand(-14, 14));
        pts.add(p);
      }
      _cracks.add(pts);
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _rubFx = max(0, _rubFx - dt * 3);
    _wobble = M.approach(_wobble, 0, 5, dt);
    if (_hatchT >= 0) {
      _hatchT += dt;
      if (_hatchT > .9 && _hatchT - dt <= .9) {
        // sneeze!
        host.sfx(Sfx.fire);
        host.sfx(Sfx.boing, volume: .6, rate: 1.6);
        host.fx.burst(_egg + const Offset(60, -30), Pal.orange, count: 24, speed: 320, gravity: -100, shape: PartShape.spark);
        host.shake(5);
      }
      return;
    }
    if (_fried) {
      _friedT += dt;
      return;
    }
    if (host.finished) return;

    // cooling (+ cold wind gusts)
    var cool = (.11 + host.time * .006) * host.speed;
    if (_gustAt.isNotEmpty && host.time > _gustAt.first) {
      _gustAt.removeAt(0);
      _gust = 1.2;
      host.sfx(Sfx.wind);
      host.fx.pop(host.tr('cold', 'COLD!'), const Offset(180, 170), color: Pal.sky, size: 28);
    }
    if (_gust > 0) {
      _gust -= dt;
      cool += .22;
      if (chance(.6)) {
        host.fx.add(Particle(pos: Offset(-10, rand(100, 560)), vel: Offset(rand(300, 460), rand(-30, 60)), life: 1.1, color: Pal.white, size: rand(2, 4)));
      }
    }
    _temp = max(0, _temp - cool * dt);

    final lo = _bandC - _bandW, hi = _bandC + _bandW;
    if (_temp > .88) {
      _burn += dt;
      if (chance(.3)) host.fx.smoke(_egg + Offset(rand(-40, 40), -60), count: 1, color: const Color(0xAA555555));
      if (_burn > 2.0) _fry();
    } else if (_temp >= lo && _temp <= hi) {
      final perfect = (_temp - _bandC).abs() < .05;
      _progress += dt / (perfect ? 4.6 : 5.8);
      _goodTime += dt;
      if (perfect) _perfectTime += dt;
      _wobble = max(_wobble, .2 + _progress * .4);
      final stage = (_progress * 6).floor();
      if (stage > _crackStage) {
        _crackStage = stage;
        host.sfx(Sfx.crack, rate: 1 + stage * .06);
        host.shake(2 + stage * .6);
        host.fx.burst(_egg + Offset(rand(-30, 30), rand(-40, 20)), Pal.white, count: 6, speed: 140);
        _wobble = 1;
      }
      if (_progress >= 1) _hatch();
    }
  }

  void _hatch() {
    _hatchT = 0;
    final q = _goodTime <= 0 ? 0 : _perfectTime / _goodTime;
    final score = q - _burn * .25;
    _rarity = score > .5 ? 3 : (score > .32 ? 2 : (score > .15 ? 1 : 0));
    host.sfx(Sfx.explodeSmall);
    host.sfx(_rarity >= 2 ? Sfx.ssr : Sfx.rarityUp);
    host.flash(Pal.white, .3);
    host.shake(8);
    host.fx.burst(_egg, const Color(0xFFFFF4DC), count: 30, speed: 380, size: 9, gravity: 700);
    host.fx.confetti();
    final names = [
      host.tr('common', 'COMMON'),
      host.tr('rare', 'RARE'),
      host.tr('epic', 'EPIC'),
      host.tr('legendary', 'LEGENDARY!'),
    ];
    host.fx.pop(names[_rarity], const Offset(180, 190), color: const [Pal.lime, Pal.sky, Pal.gold, Pal.pink][_rarity], size: _rarity == 3 ? 40 : 32, life: 1.6);
    host.win(stars: _rarity >= 2 ? 3 : (_rarity == 1 ? 2 : 1));
  }

  void _fry() {
    _fried = true;
    host.sfx(Sfx.sizzle);
    host.sfx(Sfx.crack);
    host.sfx(Sfx.jingleLose, volume: .7);
    host.shake(8);
    host.fx.smoke(_egg, count: 14, color: const Color(0xCC444444), size: 26);
    host.fx.pop(host.tr('fried', 'FRIED...'), const Offset(180, 200), color: Pal.orange, size: 34, life: 1.4);
    host.lose();
  }

  @override
  void onTimeUp() {
    _chick = true;
    _hatchT = 0;
    host.sfx(Sfx.pop);
    host.fx.pop(host.tr('chick', 'CHICK?!'), const Offset(180, 200), color: Pal.yellow, size: 34, life: 1.4);
    host.lose();
  }

  // ----------------------------------------------------------------- input
  @override
  void onDown(Offset p) => _last = p;

  @override
  void onMove(Offset p) {
    final l = _last;
    _last = p;
    if (l == null || _hatchT >= 0 || _fried || host.finished) return;
    if ((p - _egg).distance > 150) return;
    final d = (p - l).distance;
    _temp = min(1, _temp + d * .0011);
    _wobble = max(_wobble, min(1, d * .02));
    _rubFx = 1;
    if (chance(min(1, d * .03))) {
      host.fx.add(Particle(
          pos: p, vel: Offset(rand(-60, 60), rand(-160, -60)), life: .5, color: _temp > .8 ? Pal.red : Pal.orange, size: rand(3, 6), shape: PartShape.spark, drag: 1));
    }
    if (chance(d * .006)) host.sfx(Sfx.scrub, volume: .45, rate: .8 + _temp * .8);
  }

  @override
  void onUp(Offset p) => _last = null;

  @override
  void onKey(String key, bool down) {
    if (down && (key == 'left' || key == 'right' || key == 'action')) {
      _temp = min(1, _temp + .06);
      _wobble = .6;
      host.sfx(Sfx.scrub, volume: .4);
    }
  }

  // ---------------------------------------------------------------- render
  Color get _dragonColor => switch (_rarity) {
        3 => D.hsv(_t * 240, .6, 1),
        2 => Pal.gold,
        1 => Pal.sky,
        _ => const Color(0xFF7BD35A),
      };

  @override
  void render(Canvas c) {
    // cozy volcano cave at sunset
    D.gradientBg(c, const [Color(0xFFFF9E6B), Color(0xFF8C3B6E), Color(0xFF2B1640)]);
    if (_hatchT >= 0 && !_chick) {
      D.rays(c, _egg, 520, _rarity == 3 ? D.hsv(_t * 200, .5, 1, .3) : const Color(0x44FFF2A0), count: 18, t: _t * .6);
    }
    final volcano = Path()
      ..moveTo(40, 330)
      ..lineTo(140, 180)
      ..lineTo(210, 180)
      ..lineTo(320, 330)
      ..close();
    c.drawPath(volcano, D.fill(const Color(0xFF4A2A4A)));
    c.drawPath(
        Path()
          ..moveTo(140, 180)
          ..lineTo(210, 180)
          ..lineTo(196, 200)
          ..lineTo(175, 190)
          ..lineTo(152, 204)
          ..close(),
        D.fill(Pal.orange));
    for (var i = 0; i < 3; i++) {
      final tt = (_t * .4 + i * .33) % 1.0;
      c.drawCircle(Offset(175 + sin(tt * 5 + i) * 14, 170 - tt * 90), 10 + tt * 14, D.fill(Color.fromRGBO(90, 60, 90, .5 * (1 - tt))));
    }
    // rocky ground
    c.drawRect(const Rect.fromLTWH(0, 440, 360, 200), D.fill(const Color(0xFF3A2238)));
    for (var i = 0; i < 9; i++) {
      c.drawOval(Rect.fromCenter(center: Offset(i * 45.0 + 10, 450 + (i % 3) * 30.0), width: 60, height: 22), D.fill(const Color(0xFF4B2E48)));
    }
    // heat glow behind egg
    final warm = M.clamp01(_temp);
    c.drawCircle(_egg, 150, Paint()..shader = RadialGradient(colors: [Color.lerp(const Color(0x006BB8FF), const Color(0xAAFF8A1F), warm)!, const Color(0x00FF8A1F)]).createShader(Rect.fromCircle(center: _egg, radius: 150)));

    _renderNest(c, back: true);
    if (_fried) {
      _renderFried(c);
    } else if (_hatchT >= 0) {
      _renderHatch(c);
    } else {
      _renderEgg(c);
    }
    _renderNest(c, back: false);
    _renderThermo(c);
    // progress bar
    final pr = const Rect.fromLTWH(40, 540, 240, 18);
    D.bar(c, pr, _progress, Pal.lime, border: Pal.ink);
    D.text(c, host.tr('hatch', 'HATCH'), pr.centerLeft + const Offset(-4, 0), size: 12, color: Pal.white, stroke: Pal.ink, anchor: Alignment.centerRight);
    D.text(c, '${(_progress * 100).clamp(0, 100).round()}%', pr.center, size: 13, color: Pal.white, stroke: Pal.ink, strokeWidth: 3);
    // status bubble
    if (_hatchT < 0 && !_fried) {
      final lo = _bandC - _bandW, hi = _bandC + _bandW;
      final String s;
      final Color col;
      if (_temp > .88) {
        s = host.tr('too_hot', 'TOO HOT!');
        col = Pal.red;
      } else if (_temp > hi) {
        s = host.tr('hot', 'HOT');
        col = Pal.orange;
      } else if (_temp < lo) {
        s = host.tr('cold', 'COLD!');
        col = Pal.sky;
      } else {
        s = host.tr('cozy', 'COZY');
        col = Pal.lime;
      }
      D.text(c, s, const Offset(180, 590), size: 26, color: col, stroke: Pal.ink, strokeWidth: 5);
    }
    if (host.time < 2.5 && _hatchT < 0) {
      final x = 180 + sin(_t * 9) * 60;
      D.hand(c, Offset(x, 380), _t);
      D.arrow(c, const Offset(180, 450), const Offset(1, 0), 120, const Color(0xCCFFFFFF), width: 8);
      D.arrow(c, const Offset(180, 450), const Offset(-1, 0), 120, const Color(0xCCFFFFFF), width: 8);
      D.text(c, host.tr('rub', 'RUB!'), const Offset(180, 245), size: 28, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _renderNest(Canvas c, {required bool back}) {
    final twig = D.stroke(const Color(0xFF8A5A2E), 6);
    final twig2 = D.stroke(const Color(0xFFB07A42), 4);
    if (back) {
      c.drawOval(Rect.fromCenter(center: _egg + const Offset(0, 90), width: 250, height: 70), D.fill(const Color(0xFF5A3A1E)));
      return;
    }
    final base = _egg + const Offset(0, 100);
    final path = Path()
      ..moveTo(base.dx - 125, base.dy - 20)
      ..quadraticBezierTo(base.dx, base.dy + 60, base.dx + 125, base.dy - 20)
      ..lineTo(base.dx + 110, base.dy + 10)
      ..quadraticBezierTo(base.dx, base.dy + 70, base.dx - 110, base.dy + 10)
      ..close();
    c.drawPath(path, D.fill(const Color(0xFF7A4A24)));
    for (var i = 0; i < 12; i++) {
      final x = base.dx - 120 + i * 21.0;
      final y = base.dy - 14 + sin(i * 1.7) * 6 + (1 - ((x - base.dx) / 125).abs()) * 26;
      c.drawLine(Offset(x - 16, y - 4), Offset(x + 20, y + 6 * (i.isEven ? 1 : -1)), i.isEven ? twig : twig2);
    }
    c.drawPath(path, D.stroke(Pal.ink, 3));
  }

  void _eggPath(Path p, double w, double h) {
    p
      ..moveTo(0, -h / 2)
      ..cubicTo(w * .45, -h / 2, w / 2, h * .1, w / 2, h * .18)
      ..cubicTo(w / 2, h * .45, w * .28, h / 2, 0, h / 2)
      ..cubicTo(-w * .28, h / 2, -w / 2, h * .45, -w / 2, h * .18)
      ..cubicTo(-w / 2, h * .1, -w * .45, -h / 2, 0, -h / 2)
      ..close();
  }

  void _renderEgg(Canvas c) {
    final warm = M.clamp01(_temp);
    final wob = sin(_t * 30) * _wobble * .08 + sin(_t * 2) * .02;
    c.save();
    c.translate(_egg.dx, _egg.dy + 80);
    c.rotate(wob);
    c.translate(0, -80);
    final egg = Path();
    _eggPath(egg, 140, 180);
    final base = warm < .5
        ? Color.lerp(const Color(0xFFCFE6FF), const Color(0xFFFFF0D6), warm * 2)!
        : Color.lerp(const Color(0xFFFFF0D6), const Color(0xFFFF7A4A), (warm - .5) * 2)!;
    c.drawPath(
        egg,
        Paint()
          ..shader = RadialGradient(center: const Alignment(-.35, -.4), radius: .9, colors: [Color.lerp(base, Pal.white, .6)!, base, Color.lerp(base, const Color(0xFF6A3A5A), .35)!])
              .createShader(const Rect.fromLTWH(-70, -90, 140, 180)));
    // spots
    c.save();
    c.clipPath(egg);
    final spot = D.fill(Color.lerp(const Color(0xFF7B5CD6), const Color(0xFFD04A2A), warm)!.withValues(alpha: .75));
    for (final s in const [Offset(-30, -40), Offset(25, -10), Offset(-10, 30), Offset(40, 45), Offset(-45, 20), Offset(10, -65)]) {
      c.drawOval(Rect.fromCenter(center: s, width: 26, height: 20), spot);
    }
    // burn marks
    if (_burn > 0) c.drawRect(const Rect.fromLTWH(-80, -100, 160, 200), D.fill(Color.fromRGBO(40, 20, 10, M.clamp01(_burn / 1.6) * .6)));
    c.restore();
    c.drawPath(egg, D.stroke(Pal.ink, 4));
    // cracks
    final shown = (_progress * 6).clamp(0, 6).toDouble();
    for (var k = 0; k < 6; k++) {
      if (k >= shown) break;
      final pts = _cracks[k];
      final frac = M.clamp01(shown - k);
      final n = (pts.length * frac).ceil().clamp(2, pts.length);
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < n; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      c.drawPath(path, D.stroke(Pal.ink, 3)..style = PaintingStyle.stroke);
      if (_progress > .5) c.drawPath(path, D.stroke(Color.fromRGBO(255, 230, 120, .7 * M.wave(_t, 3)), 1.5)..style = PaintingStyle.stroke);
    }
    // eyes peeking through a crack near the end
    if (_progress > .75) {
      final a = M.clamp01((_progress - .75) * 4);
      c.drawOval(const Rect.fromLTWH(-24, -18, 48, 20), D.fill(Color.fromRGBO(20, 10, 30, a)));
      for (final s in [-1.0, 1.0]) {
        c.drawCircle(Offset(s * 10, -8), 4, D.fill(Color.fromRGBO(255, 230, 80, a)));
      }
    }
    // face of the egg reacting to heat
    if (_temp > .88) {
      D.face(c, const Offset(0, 40), 22, Face.shocked, blush: false);
    } else if (_temp < _bandC - _bandW) {
      D.face(c, const Offset(0, 40), 22, Face.cry, blush: false);
    } else {
      D.face(c, const Offset(0, 40), 22, Face.sleepy, blush: true);
    }
    c.restore();
    if (_temp < .25) {
      // shivering frost
      for (var i = 0; i < 5; i++) {
        D.star(c, _egg + Offset(cos(i * 1.3) * 80, sin(i * 1.3) * 90), 5, const Color(0xCCDDF2FF), rotation: _t + i);
      }
    }
  }

  void _renderHatch(Canvas c) {
    final k = M.clamp01(_hatchT / .4);
    // shell halves flying apart
    for (final s in [-1.0, 1.0]) {
      c.save();
      c.translate(_egg.dx + s * k * 90, _egg.dy + 40 + (s < 0 ? -k * 60 : k * 30));
      c.rotate(s * k * 1.2);
      final half = Path()
        ..moveTo(-60 * s.sign, 0)
        ..cubicTo(-60, -80 * (s < 0 ? 1 : -.3), 60, -80 * (s < 0 ? 1 : -.3), 60, 0)
        ..lineTo(40, 10)
        ..lineTo(20, -6)
        ..lineTo(0, 10)
        ..lineTo(-20, -6)
        ..lineTo(-40, 10)
        ..close();
      c.drawPath(half, D.fill(const Color(0xFFFFF0D6)));
      c.drawPath(half, D.stroke(Pal.ink, 3));
      c.restore();
    }
    if (_chick) {
      final s = M.easeOutBack(k);
      D.blob(c, _egg + const Offset(0, 30), 50 * s, Pal.yellow, face: Face.shocked);
      c.drawPath(
          Path()
            ..moveTo(_egg.dx - 8, _egg.dy + 40)
            ..lineTo(_egg.dx + 8, _egg.dy + 40)
            ..lineTo(_egg.dx, _egg.dy + 52)
            ..close(),
          D.fill(Pal.orange));
      return;
    }
    _renderDragon(c, _egg + Offset(0, 10 - sin(_t * 4) * 5), M.easeOutElastic(M.clamp01(_hatchT / .6)));
  }

  void _renderDragon(Canvas c, Offset o, double s) {
    final col = _dragonColor;
    final dark = Color.lerp(col, Pal.ink, .3)!;
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s);
    // wings
    for (final sd in [-1.0, 1.0]) {
      final flap = sin(_t * 12) * .3;
      c.save();
      c.translate(sd * 40, -10);
      c.rotate(sd * (.3 + flap));
      final w = Path()
        ..moveTo(0, 0)
        ..lineTo(sd * 60, -50)
        ..lineTo(sd * 50, -10)
        ..lineTo(sd * 62, 0)
        ..lineTo(sd * 40, 12)
        ..close();
      c.drawPath(w, D.fill(dark));
      c.drawPath(w, D.stroke(Pal.ink, 3));
      c.restore();
    }
    // tail
    c.drawPath(
        Path()
          ..moveTo(30, 50)
          ..quadraticBezierTo(90, 70, 84 + sin(_t * 5) * 6, 20),
        D.stroke(Pal.ink, 16));
    c.drawPath(
        Path()
          ..moveTo(30, 50)
          ..quadraticBezierTo(90, 70, 84 + sin(_t * 5) * 6, 20),
        D.stroke(col, 11));
    // body + head
    c.drawOval(const Rect.fromLTWH(-44, 0, 88, 76), D.fill(col));
    c.drawOval(const Rect.fromLTWH(-44, 0, 88, 76), D.stroke(Pal.ink, 3.5));
    c.drawOval(const Rect.fromLTWH(-26, 22, 52, 48), D.fill(const Color(0xFFFFF0C0)));
    for (final sd in [-1.0, 1.0]) {
      final h = Path()
        ..moveTo(sd * 22, -50)
        ..lineTo(sd * 34, -84)
        ..lineTo(sd * 38, -46)
        ..close();
      c.drawPath(h, D.fill(const Color(0xFFFFF1C7)));
      c.drawPath(h, D.stroke(Pal.ink, 3));
    }
    c.drawCircle(const Offset(0, -26), 46, D.fill(col));
    c.drawCircle(const Offset(0, -26), 46, D.stroke(Pal.ink, 3.5));
    c.drawOval(const Rect.fromLTWH(-30, -62, 26, 14), D.fill(const Color(0x66FFFFFF)));
    final sneeze = _hatchT > .75 && _hatchT < 1.3;
    D.face(c, const Offset(0, -22), 36, sneeze ? Face.shocked : Face.happy);
    // nostrils + sneeze fire
    c.drawCircle(const Offset(-6, -8), 2.5, D.fill(Pal.ink));
    c.drawCircle(const Offset(6, -8), 2.5, D.fill(Pal.ink));
    if (sneeze) {
      c.save();
      c.translate(26, -4);
      c.rotate(pi / 2 + .3);
      D.flame(c, Offset.zero, 70, _t);
      c.restore();
    }
    if (_rarity == 3) {
      for (var i = 0; i < 5; i++) {
        final a = _t * 2 + i * pi * 2 / 5;
        D.star(c, Offset(cos(a) * 90, sin(a) * 70 - 10), 7, D.hsv(i * 70 + _t * 200, .5, 1), border: Pal.ink);
      }
    }
    c.restore();
  }

  void _renderFried(Canvas c) {
    final k = M.easeOutBack(M.clamp01(_friedT * 3));
    c.save();
    c.translate(_egg.dx, _egg.dy + 60);
    c.scale(k, k * .6);
    final white = Path();
    for (var i = 0; i <= 12; i++) {
      final a = i / 12 * pi * 2;
      final r = 110 + sin(i * 2.7) * 18;
      final p = Offset(cos(a) * r, sin(a) * r);
      i == 0 ? white.moveTo(p.dx, p.dy) : white.lineTo(p.dx, p.dy);
    }
    white.close();
    c.drawPath(white, D.fill(const Color(0xFFFFFAF0)));
    c.drawPath(white, D.stroke(const Color(0xFFB07A42), 6));
    c.drawCircle(Offset.zero, 44, D.fill(Pal.orange));
    c.drawCircle(Offset.zero, 44, D.stroke(Pal.ink, 3));
    c.restore();
    D.face(c, _egg + const Offset(0, 58), 30, Face.dead, blush: false);
  }

  void _renderThermo(Canvas c) {
    final r = _thermo;
    D.rrect(c, r.inflate(4), 14, Pal.white, border: Pal.ink, borderWidth: 3);
    // zones
    double y(double v) => r.bottom - v * r.height;
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)),
        Paint()..shader = const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF6BB8FF), Color(0xFFFFE070), Color(0xFFFF3B3B)]).createShader(r));
    c.drawRect(Rect.fromLTRB(r.left, y(1), r.right, y(.88)), D.fill(const Color(0x88FF0000)));
    // band
    final band = Rect.fromLTRB(r.left - 6, y(_bandC + _bandW), r.right + 6, y(_bandC - _bandW));
    D.rrect(c, band, 6, const Color(0x9950E060), border: Pal.lime, borderWidth: 3);
    // needle
    final ny = y(M.clamp01(_temp));
    D.arrow(c, Offset(r.left - 22, ny), const Offset(1, 0), 26, _temp > .88 ? Pal.red : Pal.white, width: 9);
    c.drawCircle(Offset(r.center.dx, r.bottom + 16), 17, D.fill(Color.lerp(Pal.sky, Pal.red, M.clamp01(_temp))!));
    c.drawCircle(Offset(r.center.dx, r.bottom + 16), 17, D.stroke(Pal.ink, 3));
  }
}
