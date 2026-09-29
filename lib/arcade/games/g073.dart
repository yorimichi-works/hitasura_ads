import '../engine/engine.dart';

/// No.073 Cover the Sneeze! — "ah... ahh..." fake-outs, then the real ACHOO.
/// Tap to raise the elbow at the right moment and save the birthday cake.
class G073 extends MiniGame {
  static const _head = Offset(180, 235);
  double _t = 0;

  // sneeze state machine
  int _state = 0; // 0 idle, 1 build, 2 relax (fake), 3 tell, 4 sneezed
  double _st = 0; // time in state
  double _idleFor = .35;
  int _fakesLeft = 1;
  double _ah = 0; // 0..1 build level (head back, mouth open)
  double _relaxFrom = 0;

  // cover
  double _cover = 0; // seconds of cover left
  double _cooldown = 0;
  double _arm = 0; // 0 down .. 1 up (visual)
  bool _tappedInTell = false;

  bool _saved = false;
  double _endT = 0;
  final _spots = <Offset>[];

  @override
  void init() {
    _fakesLeft = host.speed > 1.3 ? (chance(.5) ? 1 : 2) : (chance(.4) ? 2 : 1);
    _idleFor = rand(.25, .45);
  }

  double get _buildDur => .75 / host.speed;
  double get _tellDur => max(.26, .42 / host.speed);

  @override
  void update(double dt) {
    _t += dt;
    _st += dt;
    switch (_state) {
      case 0:
        _ah = M.approach(_ah, 0, 8, dt);
        if (_st >= _idleFor) _go(1);
      case 1:
        _ah = M.clamp01(_st / _buildDur);
        if (_st >= _buildDur) {
          if (_fakesLeft > 0) {
            _fakesLeft--;
            _relaxFrom = _ah;
            host.sfx(Sfx.whoosh, volume: .4, rate: .7);
            _go(2);
          } else {
            host.sfx(Sfx.heartbeat, volume: .8, rate: 1.4);
            _go(3);
          }
        } else if ((_st * 6).floor() != ((_st - dt) * 6).floor()) {
          host.sfx(Sfx.tick, volume: .35, rate: .8 + _ah * .8);
        }
      case 2:
        _ah = _relaxFrom * (1 - M.clamp01(_st / .4));
        if (_st >= .45) {
          _idleFor = rand(.2, .4);
          _go(0);
        }
      case 3:
        _ah = 1;
        if (_st >= _tellDur) _sneeze();
      case 4:
        _endT += dt;
    }
    if (_cover > 0) {
      _cover -= dt;
      if (_cover <= 0 && _state != 4) _cooldown = .22;
    }
    if (_cooldown > 0) _cooldown -= dt;
    final wantUp = _cover > 0 || (_state == 4 && _saved);
    _arm = M.approach(_arm, wantUp ? 1 : 0, wantUp ? 28 : 10, dt);
  }

  void _go(int s) {
    _state = s;
    _st = 0;
  }

  void _sneeze() {
    _go(4);
    final mouth = _head + const Offset(0, 70);
    host.sfx(Sfx.explodeSmall, rate: 1.2);
    if (_cover > 0) {
      _saved = true;
      host.sfx(Sfx.squish);
      host.sfx(Sfx.correct, volume: .7);
      host.shake(5);
      host.fx.burst(mouth + const Offset(20, -10), const Color(0xCCB6F0FF), count: 14, speed: 150, gravity: 200);
      host.fx.pop(host.tr('safe', 'SAFE!'), const Offset(180, 420), color: Pal.lime, size: 38);
      host.fx.sparkle(const Offset(180, 540), count: 12, radius: 60, color: Pal.yellow);
      host.win(stars: _tappedInTell ? 3 : 2);
    } else {
      host.sfx(Sfx.splat);
      host.sfx(Sfx.aww, volume: .8);
      host.shake(14, .4);
      host.flash(const Color(0x8897E07A), .2);
      for (var i = 0; i < 40; i++) {
        final a = rand(pi * .25, pi * .75);
        final s = rand(250, 620);
        host.fx.add(Particle(
          pos: mouth,
          vel: Offset(cos(a) * s, sin(a) * s),
          life: rand(.5, .9),
          color: pick(const [Color(0xDDB6F0FF), Color(0xDD9BE22D), Color(0xDDFFFFFF)]),
          size: rand(5, 11),
          gravity: 600,
          drag: .5,
        ));
      }
      for (var i = 0; i < 9; i++) {
        _spots.add(Offset(rand(-80, 80), rand(-30, 10)));
      }
      host.lose();
    }
  }

  @override
  void onDown(Offset p) {
    if (_state == 4 || _cover > 0 || _cooldown > 0) return;
    _cover = .55;
    if (_state == 3) _tappedInTell = true;
    host.sfx(Sfx.swing, rate: 1.2);
  }

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action') onDown(Offset.zero);
  }

  @override
  void render(Canvas c) {
    final tense = _state == 3;
    D.gradientBg(c, tense ? const [Color(0xFFFF7A7A), Color(0xFFFFC04D)] : const [Color(0xFFB6F3A5), Color(0xFF4FD1C5)]);
    D.rays(c, _head, 700, const Color(0x2AFFFFFF), count: 20, t: _t * (tense ? 2 : .3));
    // party bunting
    for (var i = 0; i < 9; i++) {
      final x = i * 45.0;
      final y = 60 + sin(i * 1.3) * 6;
      c.drawPath(
          Path()
            ..moveTo(x, y)
            ..lineTo(x + 40, y + 4)
            ..lineTo(x + 20, y + 30)
            ..close(),
          D.fill(Pal.candy[i % Pal.candy.length]));
    }
    D.line(c, const Offset(0, 60), const Offset(360, 64), Pal.ink, 3);

    _drawPerson(c);
    _drawTable(c);
    _drawArm(c);
    _drawBubble(c);

    if (host.time < 1.6 && _state != 4) {
      D.hand(c, const Offset(300, 470), _t);
      D.text(c, host.tr('tap', 'TAP!'), const Offset(300, 440), size: 22, stroke: Pal.ink, color: Pal.yellow);
    }
  }

  void _drawPerson(Canvas c) {
    // body
    D.rrect(c, const Rect.fromLTWH(60, 360, 240, 200), 70, const Color(0xFF6A5ACD), border: Pal.ink, borderWidth: 5);
    // party hat collar
    D.rrect(c, const Rect.fromLTWH(140, 360, 80, 24), 12, Pal.white, border: Pal.ink, borderWidth: 3);

    final tremble = _state == 3 ? sin(_t * 70) * 4 : (_state == 1 ? sin(_t * 30) * _ah * 1.5 : 0.0);
    final back = _state == 4 ? -1.2 * (1 - M.clamp01((_endT - .15) * 3)) : _ah;
    final h = _head + Offset(tremble, -back * 20);
    c.save();
    c.translate(h.dx, h.dy);
    c.rotate(_state == 4 && !_saved ? .12 * sin(_endT * 20) * M.clamp01(1 - _endT) : -back * .08);
    // ears
    for (final s in [-1.0, 1.0]) {
      c.drawCircle(Offset(s * 120, 10), 24, D.fill(Pal.skin));
      c.drawCircle(Offset(s * 120, 10), 24, D.stroke(Pal.ink, 4));
    }
    final head = Rect.fromCenter(center: Offset.zero, width: 245, height: 265);
    c.drawOval(head, D.fill(Pal.skin));
    // hair tuft
    final hair = Path()
      ..moveTo(-110, -40)
      ..quadraticBezierTo(-100, -140, 0, -135)
      ..quadraticBezierTo(100, -140, 110, -40)
      ..quadraticBezierTo(60, -90, 0, -80)
      ..quadraticBezierTo(-60, -90, -110, -40)
      ..close();
    c.drawPath(hair, D.fill(const Color(0xFF4A2F22)));
    c.drawOval(head, D.stroke(Pal.ink, 5));
    // party hat
    final hat = Path()
      ..moveTo(-38, -118)
      ..lineTo(18, -210)
      ..lineTo(56, -108)
      ..close();
    c.drawPath(hat, D.fill(Pal.pink));
    for (var i = 0; i < 3; i++) {
      D.line(c, Offset(-22 + i * 14.0, -140 - i * 22.0), Offset(46 - i * 8.0, -130 - i * 20.0), Pal.yellow, 5);
    }
    c.drawPath(hat, D.stroke(Pal.ink, 4));
    c.drawCircle(const Offset(18, -212), 12, D.fill(Pal.yellow));
    c.drawCircle(const Offset(18, -212), 12, D.stroke(Pal.ink, 3));

    // eyes
    final squeeze = _state == 3 || (_state == 4 && _endT < .3);
    for (final s in [-1.0, 1.0]) {
      final e = Offset(s * 50, -18 - _ah * 6);
      if (squeeze) {
        D.line(c, e + Offset(-16 * s, -10), e + Offset(10 * s, 0), Pal.ink, 6);
        D.line(c, e + Offset(10 * s, 0), e + Offset(-16 * s, 10), Pal.ink, 6);
      } else if (_state == 4) {
        if (_saved) {
          c.drawArc(Rect.fromCenter(center: e + const Offset(0, 8), width: 40, height: 30), pi, pi, false,
              D.stroke(Pal.ink, 6));
        } else {
          c.drawCircle(e, 26, D.fill(Pal.white));
          c.drawCircle(e, 26, D.stroke(Pal.ink, 4));
          c.drawCircle(e, 6, D.fill(Pal.ink));
        }
      } else {
        final open = 1 - _ah * .75;
        c.drawOval(Rect.fromCenter(center: e, width: 44, height: 40 * open + 4), D.fill(Pal.white));
        c.drawOval(Rect.fromCenter(center: e, width: 44, height: 40 * open + 4), D.stroke(Pal.ink, 4));
        if (open > .3) c.drawCircle(e + Offset(0, -4 * _ah), 9 * open + 2, D.fill(Pal.ink));
      }
      // brows go up with the build
      D.line(c, e + Offset(-20, -30 - _ah * 14), e + Offset(20, -34 - _ah * 16 + (squeeze ? 8 * s : 0)), Pal.ink, 7);
    }
    // nose (flares)
    final flare = 1 + _ah * .45 + (_state == 3 ? .15 * sin(_t * 40) : 0);
    c.drawOval(Rect.fromCenter(center: const Offset(0, 28), width: 54 * flare, height: 44), D.fill(const Color(0xFFFFB38A)));
    c.drawOval(Rect.fromCenter(center: const Offset(0, 28), width: 54 * flare, height: 44), D.stroke(Pal.ink, 4));
    for (final s in [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(s * 11 * flare, 38), width: 10 * flare, height: 8 + _ah * 4),
          D.fill(const Color(0xFF7A3B2A)));
    }
    // mouth
    if (_state == 4 && !_saved) {
      c.drawOval(Rect.fromCenter(center: const Offset(0, 84), width: 90, height: 70), D.fill(const Color(0xFF7A1F2B)));
      c.drawOval(Rect.fromCenter(center: const Offset(0, 84), width: 90, height: 70), D.stroke(Pal.ink, 4));
    } else {
      final mw = 34 + _ah * 26, mh = 10 + _ah * 34;
      c.drawOval(Rect.fromCenter(center: Offset(0, 80 + _ah * 4), width: mw, height: mh), D.fill(const Color(0xFF7A1F2B)));
      c.drawOval(Rect.fromCenter(center: Offset(0, 80 + _ah * 4), width: mw, height: mh), D.stroke(Pal.ink, 4));
    }
    c.restore();
  }

  void _drawTable(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 520, 360, 120), D.fill(const Color(0xFFFFF4DC)));
    for (var i = 0; i < 9; i++) {
      c.drawRect(Rect.fromLTWH(i * 44.0, 520, 22, 120), D.fill(const Color(0x33FF5F7A)));
    }
    D.line(c, const Offset(0, 520), const Offset(360, 520), Pal.ink, 4);
    // cake
    const cake = Offset(180, 560);
    D.shadow(c, cake + const Offset(0, 40), 200, 26);
    D.rrect(c, Rect.fromCenter(center: cake + const Offset(0, 36), width: 200, height: 18), 9, Pal.white,
        border: Pal.ink, borderWidth: 3);
    final body = Rect.fromCenter(center: cake, width: 170, height: 70);
    D.rrect(c, body, 16, const Color(0xFFFFB3D1), border: Pal.ink, borderWidth: 4);
    D.rrect(c, Rect.fromLTWH(body.left, body.top, body.width, 22), 12, Pal.white, border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < 5; i++) {
      c.drawCircle(Offset(body.left + 22 + i * 31.5, body.top + 40), 7, D.fill(Pal.red));
    }
    // candles
    for (var i = 0; i < 3; i++) {
      final x = cake.dx - 40 + i * 40.0;
      D.rrect(c, Rect.fromLTWH(x - 5, body.top - 36, 10, 38), 3, Pal.candy[i * 2 + 1], border: Pal.ink, borderWidth: 2.5);
      final out = _state == 4 && !_saved;
      if (!out) {
        D.flame(c, Offset(x, body.top - 36), 22, _t + i);
      } else if (_endT < 1.2) {
        c.drawCircle(Offset(x + _endT * 20, body.top - 44 - _endT * 40), 6 + _endT * 6,
            D.fill(D.withAlpha(Pal.gray, .6 * (1 - _endT / 1.2))));
      }
    }
    // gross spots
    for (final s in _spots) {
      c.drawOval(Rect.fromCenter(center: cake + s, width: 16, height: 11), D.fill(const Color(0xCC9BE22D)));
    }
    // birthday kid watching the cake
    final kidFace = _state == 4 ? (_saved ? Face.love : Face.cry) : (_state == 3 ? Face.shocked : Face.happy);
    D.blob(c, const Offset(318, 590), 30, Pal.yellow, face: kidFace, look: const Offset(-1, -1));
  }

  void _drawArm(Canvas c) {
    final a = M.easeOutBack(_arm.clamp(0, 1));
    const shoulder = Offset(84, 410);
    final elbow = Offset.lerp(const Offset(30, 540), const Offset(200, 318), a)!;
    final hand = Offset.lerp(const Offset(40, 660), const Offset(330, 252), a)!;
    final path = Path()
      ..moveTo(shoulder.dx, shoulder.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(hand.dx, hand.dy);
    c.drawPath(path, D.stroke(Pal.ink, 62));
    c.drawPath(path, D.stroke(const Color(0xFF7B6BDD), 52));
    // sleeve stripes
    c.drawCircle(elbow, 22, D.fill(const Color(0xFF6A5ACD)));
    c.drawCircle(hand, 22, D.fill(Pal.skin));
    c.drawCircle(hand, 22, D.stroke(Pal.ink, 4));
    if (_state == 4 && _saved && _endT < 1) {
      // wet sleeve blotch
      c.drawOval(Rect.fromCenter(center: elbow + const Offset(10, -4), width: 40, height: 24),
          D.fill(const Color(0x668ED8FF)));
    }
  }

  void _drawBubble(Canvas c) {
    String? txt;
    double size = 24;
    if (_state == 1 || _state == 3) {
      txt = host.tr('ah', 'AH...');
      size = 20 + _ah * 14 + (_state == 3 ? 6 : 0);
    } else if (_state == 2 && _st < .4) {
      txt = '...';
      size = 26;
    } else if (_state == 4 && _endT < 1.3) {
      txt = _saved ? host.tr('mph', 'MPH!') : host.tr('achoo', 'ACHOO!');
      size = _saved ? 30 : 46;
    }
    if (txt == null) return;
    if (_state == 4 && !_saved) {
      D.title(c, txt, const Offset(180, 140), size: size, color: Pal.lime, rotate: -.1,
          scale: M.easeOutBack(M.clamp01(_endT * 5)));
      return;
    }
    final r = Rect.fromCenter(center: const Offset(290, 118), width: 120, height: 60);
    D.bubble(c, r, tail: const Offset(250, 175));
    D.text(c, txt, r.center, size: min(size, 30), color: _state == 3 ? Pal.red : Pal.ink, maxWidth: 112);
    if (_state == 3) {
      D.title(c, '!', const Offset(62, 140), size: 60, color: Pal.red, scale: 1 + .2 * sin(_t * 30));
    }
  }
}
