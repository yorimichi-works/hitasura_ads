import '../engine/engine.dart';

/// No.062 Swat! — WarioWare-style: slap the mosquito buzzing over a sleeper.
///
/// Tap the mosquito to slap it with a giant palm. Slapping the sleeping face
/// when no mosquito is there = you slapped yourself (red handprint, lose).
class G062 extends MiniGame {
  double _t = 0;
  final List<_Mosquito> _bugs = [];
  final List<_Slap> _slaps = [];
  final List<_Splat> _splats = [];
  final List<Offset> _missPrints = [];
  bool _resolved = false;
  bool _selfSlap = false;
  double _react = 0;
  int _misses = 0;
  Offset _handprint = Offset.zero;
  late final Color _hair;
  late final Color _blanket;

  static const _faceC = Offset(180, 545);
  static const _faceR = 112.0;

  @override
  void init() {
    _hair = pick(const [Color(0xFF3A2A20), Color(0xFFE0B040), Color(0xFFD9502B), Color(0xFF222244)]);
    _blanket = pick(const [Color(0xFF3D6BFF), Color(0xFFFF5FC8), Color(0xFF2ECC71), Color(0xFFFF8A1F)]);
    final n = host.speed >= 1.3 ? 2 : 1;
    for (var i = 0; i < n; i++) {
      final m = _Mosquito(Offset(i == 0 ? rand(60, 130) : rand(230, 300), rand(140, 300)));
      m.target = _newTarget(m);
      m.phase = rand(0, 10);
      _bugs.add(m);
    }
  }

  Offset _newTarget(_Mosquito m) {
    // Sometimes dive toward the sleeper's face to suck blood.
    if (chance(.22)) return Offset(rand(120, 240), rand(500, 540));
    return Offset(rand(50, 310), rand(110, 420));
  }

  @override
  void update(double dt) {
    _t += dt;
    final sp = host.speed;
    for (final m in _bugs) {
      if (m.dead) continue;
      m.retarget -= dt;
      if (m.retarget <= 0 || (m.pos - m.target).distance < 12) {
        m.target = _newTarget(m);
        m.retarget = rand(.35, .75) / sp;
      }
      final to = m.target - m.pos;
      final d = to.distance;
      final want = d < 1 ? Offset.zero : to / d * (170 + 90 * sp) * (m.dodge > 0 ? 2.2 : 1);
      m.vel = M.approachO(m.vel, want, 5, dt);
      m.dodge = max(0, m.dodge - dt);
      // erratic jitter
      final j = Offset(sin(_t * 13 + m.phase) * 60, cos(_t * 17 + m.phase * 2) * 50) * sp;
      m.pos += (m.vel + j) * dt;
      m.pos = Offset(m.pos.dx.clamp(28, 332), m.pos.dy.clamp(80, 545));
      m.face = m.vel.dx >= 0 ? 1 : -1;
    }
    for (final s in _slaps) {
      s.t += dt;
    }
    _slaps.removeWhere((s) => s.t > .6);
    _react = M.approach(_react, 0, 2, dt);
  }

  void _slap(Offset p) {
    if (_resolved) return;
    _slaps.add(_Slap(p));
    host.sfx(Sfx.slap);
    _Mosquito? hit;
    var best = 999.0;
    for (final m in _bugs) {
      if (m.dead) continue;
      final d = (m.pos - p).distance;
      if (d < 46 && d < best) {
        best = d;
        hit = m;
      }
    }
    if (hit != null) {
      hit.dead = true;
      _splats.add(_Splat(hit.pos, rand(0, pi * 2)));
      host.sfx(Sfx.splat);
      host.shake(7);
      host.hitStop(.06);
      host.punch(.05);
      host.fx.burst(hit.pos, Pal.red, count: 14, speed: 220, gravity: 500, colors: const [Pal.red, Color(0xFF8B1E3F)]);
      host.fx.ring(hit.pos, Pal.white, size: 70);
      final left = _bugs.where((b) => !b.dead).length;
      if (left == 0) {
        _resolved = true;
        host.sfx(Sfx.correct, volume: .8);
        host.fx.pop(host.tr('ko', 'K.O.!'), p + const Offset(0, -60), color: Pal.yellow, size: 40);
        host.win(stars: _misses == 0 ? (host.time < 2.5 ? 3 : 2) : 1);
      } else {
        host.fx.pop(host.tr('nice', 'NICE!'), p + const Offset(0, -50), color: Pal.lime, size: 30);
      }
      return;
    }
    // Missed. On the face = slapped yourself.
    final fd = Offset((p.dx - _faceC.dx) / _faceR, (p.dy - _faceC.dy) / (_faceR * .95));
    if (fd.distance < 1 && p.dy > 440) {
      _resolved = true;
      _selfSlap = true;
      _handprint = p;
      host.sfx(Sfx.punch);
      host.sfx(Sfx.hurt, volume: .7);
      host.shake(12);
      host.flash(Pal.red, .15);
      host.hitStop(.08);
      host.fx.pop(host.tr('ouch', 'OUCH!'), p + const Offset(0, -70), color: Pal.red, size: 38);
      host.lose();
      return;
    }
    _misses++;
    if (p.dy < 440) _missPrints.add(p);
    _react = 1;
    host.shake(3);
    host.fx.pop(host.tr('miss', 'MISS'), p + const Offset(0, -46), color: Pal.white, size: 22);
    // Mosquitoes near the slap dart away (they are smug about it).
    for (final m in _bugs) {
      if (m.dead) continue;
      final away = m.pos - p;
      if (away.distance < 140) {
        final d = max(away.distance, 1.0);
        m.target = Offset((m.pos.dx + away.dx / d * 150).clamp(40, 320), (m.pos.dy + away.dy / d * 120).clamp(100, 420));
        m.dodge = .35;
        m.retarget = .4;
      }
    }
  }

  @override
  void onDown(Offset p) => _slap(p);

  @override
  void onTimeUp() {
    host.sfx(Sfx.aww);
    host.lose();
  }

  @override
  void render(Canvas c) {
    // Night bedroom wall with a comic sunburst from the window
    D.gradientBg(c, const [Color(0xFF2B2A6B), Color(0xFF5A3A8C), Color(0xFF8C4DA0)]);
    D.rays(c, const Offset(270, 140), 700, const Color(0x14FFFFFF), count: 16, t: _t * .25);
    // wallpaper polka pattern
    final dotP = Paint()..color = const Color(0x18FFFFFF);
    for (var y = 60.0; y < 520; y += 40) {
      for (var x = ((y ~/ 40).isEven ? 20.0 : 40.0); x < 360; x += 40) {
        c.drawCircle(Offset(x, y), 4, dotP);
      }
    }
    // window with moon
    final win = Rect.fromCenter(center: const Offset(270, 150), width: 130, height: 150);
    D.rrect(c, win.inflate(8), 10, const Color(0xFFE8C9A0), border: Pal.ink, borderWidth: 4);
    c.drawRect(win, Paint()..shader = const LinearGradient(colors: [Color(0xFF0B1840), Color(0xFF26407A)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(win));
    c.drawCircle(const Offset(295, 120), 26, D.fill(const Color(0xFFFFF3B0)));
    c.drawCircle(const Offset(305, 112), 22, D.fill(const Color(0xFF0E1C48)));
    for (var i = 0; i < 6; i++) {
      final sp = Offset(win.left + 15 + (i * 37) % 100, win.top + 20 + (i * 53) % 110);
      D.star(c, sp, 3 + M.wave(_t + i, .7) * 2, const Color(0xFFFFF3B0));
    }
    D.line(c, Offset(win.center.dx, win.top), Offset(win.center.dx, win.bottom), Pal.ink, 5);
    D.line(c, Offset(win.left, win.center.dy), Offset(win.right, win.center.dy), Pal.ink, 5);
    c.drawRect(win, D.stroke(Pal.ink, 4));
    // bedside lamp glow
    c.drawCircle(const Offset(40, 420), 110, Paint()..color = const Color(0x22FFD23F));
    D.rrect(c, const Rect.fromLTWH(20, 390, 42, 40), 6, Pal.yellow, border: Pal.ink, borderWidth: 3);
    D.rrect(c, const Rect.fromLTWH(36, 430, 10, 40), 3, const Color(0xFF9A5B34), border: Pal.ink, borderWidth: 3);

    // wall handprints from misses
    for (final p in _missPrints) {
      _drawPrint(c, p, const Color(0x33FFFFFF));
    }

    // splats on wall
    for (final s in _splats) {
      _drawSplat(c, s.pos, s.rot);
    }

    // Bed: headboard + pillow
    D.rrect(c, const Rect.fromLTWH(-20, 470, 400, 200), 30, const Color(0xFF8A5634), border: Pal.ink, borderWidth: 5);
    D.rrect(c, const Rect.fromLTWH(20, 492, 320, 120), 50, Pal.white, border: Pal.ink, borderWidth: 5);
    c.drawArc(const Rect.fromLTWH(60, 520, 240, 40), pi * .1, pi * .8, false, D.stroke(const Color(0x33000000), 3));

    _drawSleeper(c);

    // blanket
    final bl = Path()
      ..moveTo(-10, 640)
      ..lineTo(-10, 618)
      ..quadraticBezierTo(180, 596, 370, 618)
      ..lineTo(370, 640)
      ..close();
    c.drawPath(bl, D.fill(_blanket));
    c.drawPath(bl, D.stroke(Pal.ink, 5));

    // Zzz while nobody is slapping
    if (!_selfSlap) {
      for (var i = 0; i < 3; i++) {
        final k = ((_t * .8 + i / 3) % 1);
        final zp = Offset(270 + k * 50 + i * 4, 450 - k * 80);
        _zee(c, zp, 10 + k * 10, 1 - k);
      }
    }

    // mosquitoes
    for (final m in _bugs) {
      if (m.dead) continue;
      _drawMosquito(c, m);
    }

    // slapping palms
    for (final s in _slaps) {
      _drawPalm(c, s);
    }

    // tutorial hint
    if (host.time < 1.6 && !_resolved && _bugs.isNotEmpty) {
      final m = _bugs.first;
      D.hand(c, m.pos + const Offset(10, 18), _t);
      D.text(c, host.tr('tap', 'TAP!'), m.pos + const Offset(40, 90), size: 22, stroke: Pal.ink);
    }
  }

  void _zee(Canvas c, Offset o, double s, double a) {
    final p = Path()
      ..moveTo(o.dx - s / 2, o.dy - s / 2)
      ..lineTo(o.dx + s / 2, o.dy - s / 2)
      ..lineTo(o.dx - s / 2, o.dy + s / 2)
      ..lineTo(o.dx + s / 2, o.dy + s / 2);
    c.drawPath(p, D.stroke(Pal.ink.withValues(alpha: a), s * .45));
    c.drawPath(p, D.stroke(Pal.white.withValues(alpha: a), s * .22));
  }

  void _drawSleeper(Canvas c) {
    const f = _faceC;
    const skin = Pal.skin;
    // head
    c.drawOval(Rect.fromCenter(center: f, width: _faceR * 2, height: _faceR * 1.9), D.fill(skin));
    // hair cap
    final hair = Path()
      ..moveTo(f.dx - _faceR, f.dy - 36)
      ..quadraticBezierTo(f.dx - _faceR, f.dy - _faceR * 1.05, f.dx, f.dy - _faceR * .98)
      ..quadraticBezierTo(f.dx + _faceR, f.dy - _faceR * 1.05, f.dx + _faceR, f.dy - 36)
      ..quadraticBezierTo(f.dx + 60, f.dy - 70, f.dx + 10, f.dy - 62)
      ..quadraticBezierTo(f.dx - 60, f.dy - 70, f.dx - _faceR, f.dy - 36)
      ..close();
    c.drawPath(hair, D.fill(_hair));
    c.drawOval(Rect.fromCenter(center: f, width: _faceR * 2, height: _faceR * 1.9), D.stroke(Pal.ink, 5));
    c.drawPath(hair, D.stroke(Pal.ink, 4));
    // mosquito bites on cheeks (it has been a long night)
    c.drawCircle(f + const Offset(-78, -8), 7, D.fill(const Color(0xFFFF8FA0)));
    c.drawCircle(f + const Offset(84, 4), 5, D.fill(const Color(0xFFFF8FA0)));
    final ey = f.dy - 28;
    if (_selfSlap) {
      // shocked open eyes w/ spirals
      for (final s in [-1.0, 1.0]) {
        final e = Offset(f.dx + s * 44, ey);
        c.drawOval(Rect.fromCenter(center: e, width: 40, height: 44), D.fill(Pal.white));
        c.drawOval(Rect.fromCenter(center: e, width: 40, height: 44), D.stroke(Pal.ink, 4));
        c.drawCircle(e, 5, D.fill(Pal.ink));
        c.drawArc(Rect.fromCenter(center: e, width: 20, height: 20), _t * 10, 4.5, false, D.stroke(Pal.ink, 2.5));
      }
      c.drawOval(Rect.fromCenter(center: f + const Offset(0, 36), width: 44, height: 34), D.fill(const Color(0xFF7A1F2B)));
      c.drawOval(Rect.fromCenter(center: f + const Offset(0, 36), width: 44, height: 34), D.stroke(Pal.ink, 4));
      // red handprint
      _drawPrint(c, _handprint, const Color(0xCCFF3B5C));
      // orbiting stars
      for (var i = 0; i < 4; i++) {
        final a = _t * 5 + i * pi / 2;
        D.star(c, f + Offset(cos(a) * 90, -100 + sin(a) * 20), 11, Pal.yellow, border: Pal.ink);
      }
    } else {
      final won = host.finished;
      for (final s in [-1.0, 1.0]) {
        final e = Offset(f.dx + s * 44, ey);
        final twitch = _react * 6;
        c.drawArc(Rect.fromCenter(center: e + Offset(0, -twitch), width: 38, height: 22), won ? pi : 0, pi, false,
            D.stroke(Pal.ink, 5));
      }
      // nose
      c.drawArc(Rect.fromCenter(center: f + const Offset(0, 4), width: 26, height: 22), -.3, pi * .9, false, D.stroke(Pal.ink, 4));
      if (won) {
        final mouth = Path()
          ..moveTo(f.dx - 28, f.dy + 32)
          ..quadraticBezierTo(f.dx, f.dy + 62, f.dx + 28, f.dy + 32)
          ..close();
        c.drawPath(mouth, D.fill(const Color(0xFF8B1E3F)));
        c.drawPath(mouth, D.stroke(Pal.ink, 4));
      } else {
        // drooly snoring mouth
        final open = 12 + M.wave(_t, .8) * 10;
        c.drawOval(Rect.fromCenter(center: f + const Offset(0, 40), width: 30, height: open), D.fill(const Color(0xFF7A1F2B)));
        c.drawOval(Rect.fromCenter(center: f + const Offset(0, 40), width: 30, height: open), D.stroke(Pal.ink, 4));
        c.drawCircle(f + const Offset(22, 52 + 4), 5 + M.wave(_t, .8) * 3, D.fill(const Color(0xAA9FE0FF)));
      }
      final bp = D.fill(const Color(0x55FF5F7A));
      c.drawOval(Rect.fromCenter(center: f + const Offset(-70, 18), width: 36, height: 18), bp);
      c.drawOval(Rect.fromCenter(center: f + const Offset(70, 18), width: 36, height: 18), bp);
    }
  }

  void _drawMosquito(Canvas c, _Mosquito m) {
    final o = m.pos;
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(m.face * 1.45, 1.45);
    final bob = sin(_t * 30 + m.phase) * 2;
    c.translate(0, bob);
    // motion trail
    c.drawCircle(const Offset(-26, 4), 8, D.fill(const Color(0x22FFFFFF)));
    c.drawCircle(const Offset(-40, 6), 5, D.fill(const Color(0x18FFFFFF)));
    // legs
    final legP = D.stroke(Pal.ink, 2);
    for (var i = 0; i < 3; i++) {
      final x = -6.0 + i * 7;
      c.drawLine(Offset(x, 6), Offset(x - 8, 22 + i * 2.0), legP);
      c.drawLine(Offset(x - 8, 22 + i * 2.0), Offset(x - 14, 30 + i * 2.0), legP);
    }
    // wings (flapping blur)
    final flap = sin(_t * 70 + m.phase);
    final wingP = D.fill(const Color(0x88DDF4FF));
    for (final k in [flap, -flap * .6]) {
      c.save();
      c.translate(-2, -6);
      c.rotate(-.9 + k * .5);
      c.drawOval(const Rect.fromLTWH(-6, -30, 14, 30), wingP);
      c.drawOval(const Rect.fromLTWH(-6, -30, 14, 30), D.stroke(const Color(0xAA1B1530), 1.5));
      c.restore();
    }
    // abdomen (striped, full of blood)
    final abd = Rect.fromCenter(center: const Offset(-14, 2), width: 28, height: 16);
    c.save();
    c.translate(abd.center.dx, abd.center.dy);
    c.rotate(.25);
    c.translate(-abd.center.dx, -abd.center.dy);
    c.drawOval(abd, D.fill(const Color(0xFFB0343F)));
    for (var i = 0; i < 3; i++) {
      c.drawLine(Offset(-22 + i * 7.0, -5), Offset(-22 + i * 7.0, 9), D.stroke(const Color(0xFF3A1F2A), 3));
    }
    c.drawOval(abd, D.stroke(Pal.ink, 2.5));
    c.restore();
    // thorax + head
    c.drawCircle(const Offset(4, -2), 9, D.fill(const Color(0xFF5A4A5E)));
    c.drawCircle(const Offset(4, -2), 9, D.stroke(Pal.ink, 2.5));
    c.drawCircle(const Offset(15, -6), 7, D.fill(const Color(0xFF5A4A5E)));
    c.drawCircle(const Offset(15, -6), 7, D.stroke(Pal.ink, 2.5));
    // huge smug eye
    c.drawCircle(const Offset(17, -8), 5, D.fill(Pal.white));
    c.drawCircle(const Offset(18.5, -8), 2.5, D.fill(Pal.red));
    c.drawLine(const Offset(12, -14), const Offset(22, -12), D.stroke(Pal.ink, 2));
    // proboscis
    c.drawLine(const Offset(20, -3), const Offset(38, 6), D.stroke(Pal.ink, 2.5));
    c.restore();
  }

  void _drawSplat(Canvas c, Offset o, double rot) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(rot);
    final p = D.fill(const Color(0xFFD02040));
    c.drawCircle(Offset.zero, 16, p);
    for (var i = 0; i < 7; i++) {
      final a = i * pi * 2 / 7;
      final r = 20.0 + (i * 13 % 11);
      c.drawCircle(Offset(cos(a) * r, sin(a) * r), 4 + (i % 3) * 2.0, p);
      c.drawLine(Offset.zero, Offset(cos(a) * r, sin(a) * r), D.stroke(const Color(0xFFD02040), 5));
    }
    // flattened bug
    c.drawOval(const Rect.fromLTWH(-14, -5, 28, 10), D.fill(const Color(0xFF3A2A3E)));
    D.line(c, const Offset(-10, -8), const Offset(-4, -2), Pal.ink, 2);
    D.line(c, const Offset(-10, -2), const Offset(-4, -8), Pal.ink, 2);
    D.line(c, const Offset(-12, 6), const Offset(-20, 16), Pal.ink, 2);
    D.line(c, const Offset(8, 6), const Offset(18, 16), Pal.ink, 2);
    c.restore();
  }

  Path _palmPath() {
    final p = Path()
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-36, -20, 72, 66), const Radius.circular(26)));
    const fingers = [
      Rect.fromLTWH(-36, -64, 16, 54),
      Rect.fromLTWH(-18, -76, 17, 64),
      Rect.fromLTWH(1, -72, 17, 60),
      Rect.fromLTWH(20, -58, 15, 46),
    ];
    for (final f in fingers) {
      p.addRRect(RRect.fromRectAndRadius(f, const Radius.circular(9)));
    }
    p.addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, -6, 40, 17), const Radius.circular(9)));
    return p;
  }

  void _drawPrint(Canvas c, Offset o, Color col) {
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(.7);
    c.drawPath(_palmPath(), D.fill(col));
    c.restore();
  }

  void _drawPalm(Canvas c, _Slap s) {
    final t = s.t;
    final a = t < .35 ? 1.0 : 1 - (t - .35) / .25;
    if (a <= 0) return;
    final k = M.clamp01(t / .07);
    final scale = M.lerp(1.9, 1.0, k);
    // impact burst
    if (t > .05 && t < .3) {
      final bp = D.starPath(s.pos, 70 + t * 80, 40 + t * 40, points: 10);
      c.drawPath(bp, D.fill(Pal.yellow.withValues(alpha: .8 * a)));
      c.drawPath(bp, D.stroke(Pal.ink.withValues(alpha: a), 3));
    }
    c.save();
    c.translate(s.pos.dx, s.pos.dy + 10);
    c.scale(scale);
    c.rotate(-.15);
    final path = _palmPath();
    c.drawPath(path.shift(const Offset(6, 8)), D.fill(Color.fromRGBO(0, 0, 0, .25 * a)));
    c.drawPath(path, D.fill(Pal.skin.withValues(alpha: a)));
    c.drawPath(path, D.stroke(Pal.ink.withValues(alpha: a), 4));
    // palm lines
    c.drawArc(const Rect.fromLTWH(-24, 0, 40, 30), .3, 2, false, D.stroke(const Color(0x66B9784F), 3));
    c.restore();
    // speed lines
    if (t < .12) {
      for (var i = 0; i < 5; i++) {
        final x = s.pos.dx - 50 + i * 25;
        D.line(c, Offset(x, s.pos.dy - 130), Offset(x, s.pos.dy - 90), Pal.white, 4);
      }
    }
  }
}

class _Mosquito {
  _Mosquito(this.pos);
  Offset pos;
  Offset vel = Offset.zero;
  Offset target = Offset.zero;
  double retarget = 0;
  double phase = 0;
  double dodge = 0;
  double face = 1;
  bool dead = false;
}

class _Slap {
  _Slap(this.pos);
  final Offset pos;
  double t = 0;
}

class _Splat {
  _Splat(this.pos, this.rot);
  final Offset pos;
  final double rot;
}
