import '../engine/engine.dart';

/// No.077 Brush It! — germ monsters squat on the teeth. Drag the toothbrush
/// back and forth over them to scrub them away. All clean = sparkling smile.
class G077 extends MiniGame {
  static const _rest = Offset(292, 600);
  double _t = 0;
  final _teeth = <Rect>[];
  final _germs = <_Germ>[];
  Offset _brush = _rest;
  bool _holding = false;
  double _scrubSfx = 0;
  double _foam = 0;
  double _brushTilt = 0;
  double _cleanT = -1;
  int _killed = 0;
  late double _hpDist;

  @override
  void init() {
    // upper row (arched) and lower row
    for (var i = 0; i < 6; i++) {
      final x = 50 + i * 43.0;
      final arch = (i - 2.5).abs() * 6;
      _teeth.add(Rect.fromLTWH(x, 196 + arch, 40, 64 - arch * .6));
    }
    for (var i = 0; i < 6; i++) {
      final x = 50 + i * 43.0;
      final arch = (i - 2.5).abs() * 6;
      _teeth.add(Rect.fromLTWH(x, 412 - arch * .4, 40, 60 - arch * .6));
    }
    final n = host.speed > 1.4 ? 6 : 5;
    final up = List<int>.generate(6, (i) => i)..shuffle(rng);
    final low = List<int>.generate(6, (i) => i + 6)..shuffle(rng);
    final chosen = [...up.take((n + 1) ~/ 2), ...low.take(n ~/ 2)];
    for (final i in chosen) {
      final r = _teeth[i];
      _germs.add(_Germ(r.center + Offset(0, i < 6 ? 6 : -6), rand(0, pi * 2), randInt(3)));
    }
    _hpDist = 230 * (1 + (host.speed - 1) * .35);
  }

  @override
  void update(double dt) {
    _t += dt;
    if (!_holding) _brush = M.approachO(_brush, _rest, 10, dt);
    _scrubSfx -= dt;
    _foam = M.approach(_foam, 0, 3, dt);
    _brushTilt = M.approach(_brushTilt, 0, 8, dt);
    for (final g in _germs) {
      g.hurt = M.approach(g.hurt, 0, 8, dt);
      if (g.dead) g.deadT += dt;
    }
    if (_cleanT >= 0) _cleanT += dt;
  }

  @override
  void onDown(Offset p) {
    _holding = true;
    _brush = p;
  }

  @override
  void onMove(Offset p) {
    if (!_holding) return;
    final d = (p - _brush).distance;
    _brushTilt = ((p.dx - _brush.dx) * .02).clamp(-.4, .4);
    _brush = p;
    if (d <= 0 || host.finished) return;
    var scrubbing = false;
    for (final g in _germs) {
      if (g.dead) continue;
      if ((g.pos - p).distance < 44) {
        scrubbing = true;
        g.hp -= d / _hpDist;
        g.hurt = 1;
        if (g.hp <= 0) _kill(g);
      }
    }
    if (scrubbing) {
      _foam = min(1, _foam + d / 200);
      if (chance(.5)) {
        host.fx.add(Particle(
          pos: p + Offset(rand(-20, 20), rand(-12, 12)),
          vel: Offset(rand(-60, 60), rand(-80, -10)),
          life: rand(.4, .8),
          color: const Color(0xEEFFFFFF),
          size: rand(6, 14),
          drag: 2,
        ));
      }
      if (_scrubSfx <= 0) {
        _scrubSfx = .13;
        host.sfx(Sfx.scrub, volume: .7, rate: rand(.9, 1.2));
      }
    }
  }

  void _kill(_Germ g) {
    g.dead = true;
    _killed++;
    host.sfx(Sfx.pop, rate: 1.1);
    host.sfx(Sfx.ding, rate: 1 + _killed * .1, volume: .8);
    host.shake(4);
    host.fx.burst(g.pos, const Color(0xFF8A5A2B), count: 12, speed: 240, size: 7, gravity: 400,
        colors: const [Color(0xFF8A5A2B), Color(0xFF6B8E23), Pal.white]);
    host.fx.sparkle(g.pos, count: 6, radius: 24, color: Pal.white);
    final remain = _germs.where((e) => !e.dead).length;
    if (remain > 0) host.fx.pop('$remain', g.pos + const Offset(0, -34), color: Pal.sky, size: 22);
    if (_germs.every((e) => e.dead)) {
      _cleanT = 0;
      host.sfx(Sfx.sparkle);
      host.sfx(Sfx.perfect, volume: .8);
      host.flash(const Color(0xAAFFFFFF));
      for (final t in _teeth) {
        host.fx.sparkle(t.center, count: 2, radius: 16, color: Pal.white);
      }
      host.fx.pop(host.tr('clear', 'CLEAR!'), const Offset(180, 330), color: Pal.sky, size: 40);
      final left = host.timeLeft;
      host.win(stars: left > 1.5 ? 3 : (left > .6 ? 2 : 1));
    }
  }

  @override
  void onUp(Offset p) => _holding = false;

  @override
  void onTimeUp() {
    host.sfx(Sfx.aww);
    host.lose();
  }

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF8BF0D9), Color(0xFF39B8E6)]);
    D.rays(c, const Offset(180, 330), 700, const Color(0x26FFFFFF), count: 18, t: _t * .3);

    // face skin around the mouth
    c.drawOval(const Rect.fromLTWH(-60, 90, 480, 520), D.fill(Pal.skin));
    c.drawOval(const Rect.fromLTWH(-60, 90, 480, 520), D.stroke(Pal.ink, 5));
    // lips
    const mouth = Rect.fromLTWH(22, 160, 316, 350);
    c.drawOval(mouth.inflate(18), D.fill(const Color(0xFFE85A71)));
    c.drawOval(mouth.inflate(18), D.stroke(Pal.ink, 5));
    // cavity
    c.drawOval(mouth, D.fill(const Color(0xFF5A1426)));
    c.save();
    c.clipPath(Path()..addOval(mouth));
    // throat + uvula
    c.drawOval(const Rect.fromLTWH(120, 270, 120, 110), D.fill(const Color(0xFF3A0A18)));
    c.drawOval(const Rect.fromLTWH(168, 262, 24, 40), D.fill(const Color(0xFFD9506A)));
    // tongue
    c.drawOval(const Rect.fromLTWH(70, 330, 220, 140), D.fill(const Color(0xFFFF7A95)));
    D.line(c, const Offset(180, 350), const Offset(180, 420), const Color(0xFFE0586F), 4);
    // gums
    c.drawRect(const Rect.fromLTWH(0, 160, 360, 52), D.fill(const Color(0xFFFF9AAE)));
    c.drawRect(const Rect.fromLTWH(0, 458, 360, 60), D.fill(const Color(0xFFFF9AAE)));
    // teeth
    for (var i = 0; i < _teeth.length; i++) {
      final r = _teeth[i];
      final top = i < 6;
      final rr = RRect.fromRectAndCorners(r,
          topLeft: Radius.circular(top ? 6 : 16),
          topRight: Radius.circular(top ? 6 : 16),
          bottomLeft: Radius.circular(top ? 16 : 6),
          bottomRight: Radius.circular(top ? 16 : 6));
      final dirty = _germs.any((g) => !g.dead && (g.pos - r.center).distance < 20);
      c.drawRRect(rr, D.fill(dirty ? const Color(0xFFF2E6B8) : Pal.white));
      c.drawRRect(rr, D.stroke(Pal.ink, 3.5));
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 6, r.top + 8, 8, r.height - 20), const Radius.circular(4)),
          D.fill(const Color(0x66D8ECFF)));
      if (_cleanT >= 0) {
        final k = (_cleanT * 2 + i * .13) % 1.0;
        D.star(c, r.center + const Offset(8, -8), 10 * sin(k * pi), Pal.white);
      }
    }
    c.restore();
    // corners of mouth
    for (final s in [-1.0, 1.0]) {
      D.line(c, Offset(180 + s * 172, 335), Offset(180 + s * 186, 318), Pal.ink, 5);
    }

    // germs
    for (final g in _germs) {
      _drawGerm(c, g);
    }

    // mirror-y HUD: germ counter icons
    for (var i = 0; i < _germs.length; i++) {
      final o = Offset(30 + i * 34.0, 58);
      final dead = _germs[i].dead;
      c.drawCircle(o, 13, D.fill(dead ? const Color(0x55FFFFFF) : const Color(0xFF8A5A2B)));
      c.drawCircle(o, 13, D.stroke(Pal.ink, 3));
      if (dead) {
        D.line(c, o + const Offset(-6, 0), o + const Offset(-1, 6), Pal.lime, 4);
        D.line(c, o + const Offset(-1, 6), o + const Offset(8, -6), Pal.lime, 4);
      } else {
        D.face(c, o, 11, Face.angry, blush: false);
      }
    }

    _drawBrush(c);

    if (host.time < 2 && _killed == 0) {
      final g = _germs.firstWhere((e) => !e.dead, orElse: () => _germs.first);
      final sweep = sin(_t * 9) * 26;
      D.arrow(c, g.pos + Offset(0, g.pos.dy < 330 ? 56 : -56), const Offset(1, 0), 70 + sweep.abs() * .3, Pal.yellow,
          width: 10);
      D.text(c, host.tr('scrub', 'SCRUB!'), const Offset(180, 598), size: 26, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _drawGerm(Canvas c, _Germ g) {
    if (g.dead && g.deadT > .35) return;
    final k = g.dead ? 1 - g.deadT / .35 : 1.0;
    final r = (11 + 13 * max(0, g.hp)) * k + 4;
    final jig = g.hurt * sin(_t * 60) * 4;
    final bob = sin(_t * 5 + g.phase) * 3;
    final o = g.pos + Offset(jig, bob);
    final col = [const Color(0xFF8A5A2B), const Color(0xFF6B8E23), const Color(0xFF7D4E9E)][g.kind];
    // spiky body
    final path = Path();
    const spikes = 9;
    for (var i = 0; i < spikes * 2; i++) {
      final a = i * pi / spikes + _t * .8;
      final rr = i.isEven ? r * 1.25 : r;
      final p = o + Offset(cos(a), sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    c.drawPath(path, D.fill(col));
    c.drawPath(path, D.stroke(Pal.ink, 3));
    D.face(c, o, r * .9, g.hurt > .3 ? Face.cry : (host.timeLeft < 1.2 ? Face.smug : Face.angry), blush: false);
    // health ring
    if (!g.dead && g.hp < 1) {
      c.drawArc(Rect.fromCircle(center: o, radius: r * 1.5), -pi / 2, pi * 2 * g.hp, false, D.stroke(Pal.red, 4));
    }
  }

  void _drawBrush(Canvas c) {
    final p = _brush;
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(-.5 + _brushTilt);
    // handle goes down-right
    D.rrect(c, const Rect.fromLTWH(-14, 16, 28, 180), 14, const Color(0xFF3D6BFF), border: Pal.ink, borderWidth: 4);
    D.rrect(c, const Rect.fromLTWH(-6, 60, 8, 110), 4, const Color(0x55FFFFFF));
    // head
    D.rrect(c, const Rect.fromLTWH(-22, -22, 44, 44), 10, Pal.white, border: Pal.ink, borderWidth: 4);
    // bristles
    for (var i = 0; i < 5; i++) {
      D.rrect(c, Rect.fromLTWH(-19 + i * 8.0, -30, 6, 14), 2, i.isEven ? Pal.sky : Pal.white, border: Pal.ink,
          borderWidth: 1.5);
    }
    // toothpaste blob / foam
    final foam = 10 + _foam * 12;
    c.drawCircle(Offset(-6, -32 - foam * .2), foam * .7, D.fill(Pal.white));
    c.drawCircle(Offset(6, -34 - foam * .3), foam * .6, D.fill(const Color(0xFFBFF3FF)));
    c.drawCircle(Offset(0, -38 - foam * .4), foam * .5, D.fill(Pal.white));
    c.restore();
  }
}

class _Germ {
  _Germ(this.pos, this.phase, this.kind);
  final Offset pos;
  final double phase;
  final int kind;
  double hp = 1;
  double hurt = 0;
  bool dead = false;
  double deadT = 0;
}
