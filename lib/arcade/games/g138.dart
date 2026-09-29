import 'dart:math' as math;

import '../engine/engine.dart';

/// No.138 Home Run Derby — tap to swing as the timing ring closes.
/// Fastballs, curves and change-ups; 3 home runs out of 8 pitches wins.
class G138 extends MiniGame {
  static const _bot = bool.fromEnvironment('ARCADE_BOT');
  static const _pitches = 8;
  static const _need = 3;
  static const _release = Offset(188, 292);

  _Ph _ph = _Ph.windup;
  double _pt = 0;
  double _t = 0;
  int _pitchNo = 0; // pitches thrown so far (current one included once released)
  int _hr = 0;
  final List<int> _log = []; // 0 strike, 1 foul, 2 hit, 3 hr

  // current pitch
  int _type = 0; // 0 fast, 1 curve, 2 change
  double _dur = .6;
  double _windup = .6;
  Offset _target = const Offset(180, 492);
  double _break = 0;
  int _kmh = 150;
  double _bt = 0;
  bool _swung = false;
  double _swing = -1; // swing anim time, -1 idle
  bool _whiff = false;

  // hit flight
  bool _flightView = false;
  double _dist = 0;
  double _ang = 0;
  double _peak = 0;
  double _ft = 0;
  double _fDur = 1.4;
  int _quality = 0; // 1 foul, 2 hit, 3 hr
  bool _perfect = false;
  bool _landed = false;
  final List<Offset> _trailPts = [];

  // presentation
  double _hype = 0;
  double _banner = 0;
  String _bannerText = '';
  Color _bannerColor = Pal.yellow;
  double _slow = 1;
  double _mitt = 0;
  double _ringFlash = 0;
  final List<_Firework> _fw = [];

  @override
  void init() {
    host.showScore = false;
    _setupPitch();
  }

  void _setupPitch() {
    _type = _pitchNo == 0 ? 0 : randInt(3);
    final sp = host.speed;
    switch (_type) {
      case 0:
        _dur = .62 / sp;
        _kmh = 148 + randInt(14);
        _break = 0;
      case 1:
        _dur = .78 / sp;
        _kmh = 118 + randInt(12);
        _break = (chance(.5) ? -1 : 1) * rand(40, 60);
      default:
        _dur = .95 / sp;
        _kmh = 124 + randInt(10);
        _break = rand(-10, 10);
    }
    _windup = rand(.5, .8) / sqrt(sp);
    _target = Offset(180 + rand(-28, 28), 488 + rand(-22, 22));
    _bt = 0;
    _swung = false;
    _swing = -1;
    _whiff = false;
    _ph = _Ph.windup;
    _pt = 0;
  }

  // ----------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    _pt += dt;
    _hype = M.approach(_hype, 0, .8, dt);
    _banner = max(0, _banner - dt);
    _mitt = M.approach(_mitt, 0, 8, dt);
    _ringFlash = M.approach(_ringFlash, 0, 6, dt);
    if (_swing >= 0) _swing += dt;
    for (final f in _fw) {
      f.t += dt;
    }
    _fw.removeWhere((f) => f.t > 1.2);
    if (_hype > .3 && chance(dt * 6) && _fw.length < 8) {
      _fw.add(_Firework(Offset(rand(40, 320), rand(70, 180)), pick(Pal.candy)));
      if (chance(.5)) host.sfx(Sfx.explodeSmall, volume: .35, rate: rand(.9, 1.3));
    }

    switch (_ph) {
      case _Ph.windup:
        if (_pt >= _windup) {
          _ph = _Ph.pitch;
          _pt = 0;
          _pitchNo++;
          host.sfx(Sfx.throwIt);
          host.fx.pop('${[
            host.tr('fastball', 'FASTBALL'),
            host.tr('curve', 'CURVE'),
            host.tr('changeup', 'CHANGE-UP')
          ][_type]} ${_kmh}km/h', const Offset(180, 250), color: [Pal.red, Pal.sky, Pal.lime][_type], size: 18, life: 1);
        }
      case _Ph.pitch:
        _bt = _pt / _dur;
        if (_bot && !_swung && (1 - _bt) * _dur < .03) _swingNow();
        if (_bt >= 1.18 && !_swung) {
          _strike(looking: true);
        } else if (_bt >= 1.18 && _whiff) {
          _strike(looking: false);
        }
      case _Ph.result:
        final sdt = dt * _slow;
        if (_flightView) {
          _ft += sdt / _fDur;
          if (_quality == 3 && _ft > .55 && _slow == 1 && !_landed) _slow = .45;
          final p = _flightScreen(M.clamp01(_ft));
          if (_trailPts.isEmpty || (_trailPts.last - p).distance > 6) {
            _trailPts.add(p);
            if (_trailPts.length > 40) _trailPts.removeAt(0);
          }
          if (_ft >= 1 && !_landed) _land();
          if (_landed && _pt > .9) _next();
        } else if (_pt > .75) {
          _next();
        }
    }
  }

  void _next() {
    _slow = 1;
    if (host.finished) return;
    final left = _pitches - _pitchNo;
    if (_hr >= _need) return;
    if (_hr + left < _need) {
      host.sfx(Sfx.aww);
      host.lose();
      return;
    }
    _flightView = false;
    _setupPitch();
  }

  void _strike({required bool looking}) {
    _ph = _Ph.result;
    _pt = 0;
    _log.add(0);
    _mitt = 1;
    host.sfx(Sfx.thud, rate: 1.2);
    host.sfx(Sfx.whistle, volume: .5);
    host.shake(3);
    _say(host.tr('strike', 'STRIKE!'), Pal.red);
    if (!looking) host.sfx(Sfx.aww, volume: .5);
  }

  void _say(String s, Color c) {
    _bannerText = s;
    _bannerColor = c;
    _banner = 1;
  }

  void _swingNow() {
    if (_ph == _Ph.result || _swung) return;
    _swung = true;
    _swing = 0;
    host.sfx(Sfx.swing);
    if (_ph != _Ph.pitch) {
      _whiff = true;
      _bt = 0;
      // swung during wind-up: laughable whiff, the pitch still comes
      host.fx.pop(host.tr('oops', 'OOPS'), const Offset(120, 420), color: Pal.orange, size: 22);
      return;
    }
    final d = (1 - _bt) * _dur; // seconds until arrival (+ early, - late)
    final ad = d.abs() * sqrt(host.speed);
    if (ad < .045) {
      _hit(3, d, perfect: true);
    } else if (ad < .085) {
      _hit(3, d);
    } else if (ad < .13) {
      _hit(2, d);
    } else if (ad < .18) {
      _hit(1, d);
    } else {
      _whiff = true;
      host.fx.pop(host.tr('miss', 'MISS'), const Offset(120, 430), color: Pal.gray, size: 22);
    }
  }

  void _hit(int q, double early, {bool perfect = false}) {
    _quality = q;
    _perfect = perfect;
    _ph = _Ph.result;
    _pt = 0;
    _ft = 0;
    _landed = false;
    _trailPts.clear();
    final pull = (early / .18).clamp(-1.0, 1.0); // early = pull to left field
    host.hitStop(perfect ? .16 : .08);
    host.shake(perfect ? 12 : 7, .3);
    host.flash(Pal.white, perfect ? .2 : .1);
    final at = _ballPos(1);
    host.fx.burst(at, Pal.yellow, count: perfect ? 30 : 16, speed: 360, shape: PartShape.spark);
    host.fx.ring(at, Pal.white, size: 90);
    switch (q) {
      case 3:
        host.sfx(Sfx.hitHeavy);
        host.sfx(Sfx.crack, volume: .8);
        _dist = perfect ? rand(138, 168) : rand(117, 136);
        _ang = -pull * .45 + rand(-.1, .1);
        _peak = _dist * .32;
        _fDur = 1.35;
        if (perfect) host.fx.pop(host.tr('perfect', 'PERFECT!'), const Offset(180, 400), color: Pal.yellow, size: 34);
      case 2:
        host.sfx(Sfx.hit);
        _dist = rand(55, 98);
        _ang = -pull * .5 + rand(-.15, .15);
        _peak = _dist * .22;
        _fDur = 1.0;
      default:
        host.sfx(Sfx.hit, rate: 1.3);
        _dist = rand(40, 80);
        _ang = (pull >= 0 ? -1 : 1) * rand(.9, 1.1);
        _peak = _dist * .35;
        _fDur = .9;
    }
    _flightView = true;
    host.sfx(Sfx.whoosh, volume: .6);
    if (q == 3) _hype = .6;
  }

  void _land() {
    _landed = true;
    _pt = 0;
    _slow = 1;
    final p = _flightScreen(1);
    switch (_quality) {
      case 3:
        _hr++;
        _log.add(3);
        _hype = 1;
        host.sfx(Sfx.cheer);
        host.sfx(Sfx.fanfare, volume: .7);
        host.shake(8, .4);
        host.fx.confetti(count: 60);
        host.fx.burst(p, Pal.gold, count: 20, speed: 260, shape: PartShape.star);
        host.fx.coins(p, count: 12);
        _say(host.tr('home_run', 'HOME RUN!!'), Pal.yellow);
        host.addScore(_dist.round(), p + const Offset(0, -30));
        if (_hr >= _need) {
          final used = _pitchNo;
          host.win(stars: used <= 4 ? 3 : (used <= 6 ? 2 : 1));
        }
      case 2:
        _log.add(2);
        host.sfx(Sfx.thud);
        host.fx.smoke(p, count: 5, color: const Color(0xCCC89A6A));
        _say(host.tr('out', 'OUT'), Pal.orange);
        host.sfx(Sfx.aww, volume: .6);
      default:
        _log.add(1);
        host.sfx(Sfx.thud);
        _say(host.tr('foul', 'FOUL'), Pal.gray);
    }
  }

  @override
  void onTimeUp() {
    if (_hr >= _need) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  @override
  void onDown(Offset p) => _swingNow();

  @override
  void onKey(String key, bool down) {
    if (down && (key == 'action' || key == 'up')) _swingNow();
  }

  // ---------------------------------------------------------- geometry ---
  Offset _ballPos(double t) {
    final e = pow(M.clamp01(t), 1.9).toDouble();
    final p = Offset.lerp(_release, _target, e)!;
    final brk = _break * pow(M.clamp01(t), 3).toDouble();
    final drop = _type == 2 ? 14 * pow(M.clamp01(t), 3).toDouble() : 0.0;
    if (t > 1) {
      // past the plate: into the mitt
      return _target + Offset(brk * .1, (t - 1) * 260);
    }
    return p + Offset(brk, drop - 26 * sin(pi * t) * (1 - t));
  }

  double _g(double d) => d / (d + 70);

  Offset _field(double d, double a, [double h = 0]) {
    final g = _g(d);
    return Offset(180 + math.sin(a) * d * 2.4 * (1 - .6 * g), 612 - 560 * g - h * 2.4 * (1 - .55 * g));
  }

  Offset _flightScreen(double t) {
    final d = _dist * t;
    final h = 4 * _peak * t * (1 - t) + 1.2 * (1 - t);
    return _field(d, _ang, h);
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    if (_flightView) {
      _renderFlight(c);
    } else {
      _renderBatter(c);
    }
    _renderHud(c);
  }

  void _sky(Canvas c, double bottom) {
    D.gradientBg(c, const [Color(0xFF05071C), Color(0xFF14195A), Color(0xFF3B2A78)], rect: Rect.fromLTWH(0, 0, 360, bottom));
    for (var i = 0; i < 24; i++) {
      final x = (i * 73.0) % 360, y = 60 + (i * 41.0) % 90;
      c.drawCircle(Offset(x, y), 1 + (i % 3) * .5, D.fill(Color.fromRGBO(255, 255, 255, .3 + .5 * M.wave(_t + i, .5))));
    }
    for (final f in _fw) {
      final k = f.t / 1.2;
      for (var i = 0; i < 12; i++) {
        final a = i * pi / 6;
        final p = f.p + Offset(cos(a), sin(a)) * (10 + 50 * M.easeOut(k)) + Offset(0, 20 * k * k);
        c.drawCircle(p, 3 * (1 - k) + 1, D.fill(f.col.withValues(alpha: 1 - k)));
      }
    }
  }

  void _lights(Canvas c, List<Offset> at) {
    for (final p in at) {
      c.drawCircle(
          p,
          80,
          Paint()
            ..shader = const RadialGradient(colors: [Color(0x99FFFBE0), Color(0x00FFFBE0)])
                .createShader(Rect.fromCircle(center: p, radius: 80)));
      D.rrect(c, Rect.fromCenter(center: p, width: 40, height: 18), 3, const Color(0xFF2A2D48));
      for (var i = 0; i < 4; i++) {
        c.drawCircle(p + Offset(-13.5 + i * 9, 0), 3.4, D.fill(const Color(0xFFFFFDE8)));
      }
    }
  }

  void _crowd(Canvas c, double top, double rows, double w0) {
    for (var row = 0; row < rows; row++) {
      final y = top + row * 13.0;
      for (var i = 0; i < 30; i++) {
        final x = i * 12.5 + (row.isOdd ? 6 : 0);
        final j = (1.5 + _hype * 8) * M.wave(_t + i * .13 + row * .31, 2 + _hype * 2);
        final col = Pal.candy[(i * 5 + row * 3) % 8];
        c.drawCircle(Offset(x, y - j), 4.5, D.fill(Color.lerp(col, const Color(0xFF151535), .5)!));
        c.drawCircle(Offset(x, y - 5 - j), 3, D.fill(const Color(0xFFD9AE8A)));
      }
    }
  }

  void _renderBatter(Canvas c) {
    _sky(c, 250);
    _lights(c, const [Offset(40, 70), Offset(320, 70)]);
    // stands
    c.drawRect(const Rect.fromLTWH(0, 150, 360, 80), D.fill(const Color(0xFF26204E)));
    _crowd(c, 160, 5, 0);
    // big screen
    D.rrect(c, const Rect.fromLTWH(130, 92, 100, 52), 4, const Color(0xFF101018), border: const Color(0xFF444466), borderWidth: 3);
    D.text(c, 'HR $_hr', const Offset(180, 110), size: 18, color: Pal.yellow);
    D.text(c, '$_kmh', const Offset(180, 131), size: 13, color: Pal.lime);
    // outfield wall
    c.drawRect(const Rect.fromLTWH(0, 224, 360, 22), D.fill(const Color(0xFF1C6B3A)));
    c.drawRect(const Rect.fromLTWH(0, 224, 360, 3), D.fill(Pal.yellow));
    for (final (x, n) in [(40.0, '100'), (180.0, '122'), (320.0, '100')]) {
      D.text(c, n, Offset(x, 236), size: 11, color: Pal.white);
    }
    // grass with mowing pattern
    D.gradientBg(c, const [Color(0xFF2E8A3E), Color(0xFF47B155)], rect: const Rect.fromLTWH(0, 246, 360, 394));
    for (var i = 0; i < 7; i++) {
      final y = 246 + 394 * pow(i / 7, 1.7).toDouble();
      final y2 = 246 + 394 * pow((i + .5) / 7, 1.7).toDouble();
      c.drawRect(Rect.fromLTRB(0, y, 360, y2), D.fill(const Color(0x14FFFFFF)));
    }
    // infield dirt
    final dirt = Path()
      ..moveTo(180, 262)
      ..quadraticBezierTo(360, 300, 420, 470)
      ..lineTo(-60, 470)
      ..quadraticBezierTo(0, 300, 180, 262)
      ..close();
    c.drawPath(dirt, D.fill(const Color(0xFFC98C58)));
    final grass = Path()
      ..moveTo(180, 290)
      ..lineTo(290, 352)
      ..lineTo(180, 430)
      ..lineTo(70, 352)
      ..close();
    c.drawPath(grass, D.fill(const Color(0xFF3A9C4A)));
    for (final b in const [Offset(290, 352), Offset(180, 290), Offset(70, 352)]) {
      c.drawRect(Rect.fromCenter(center: b, width: 10, height: 6), D.fill(Pal.white));
    }
    // foul lines
    D.line(c, const Offset(180, 610), const Offset(-40, 330), const Color(0xCCFFFFFF), 3);
    D.line(c, const Offset(180, 610), const Offset(400, 330), const Color(0xCCFFFFFF), 3);
    // home area dirt
    c.drawOval(Rect.fromCenter(center: const Offset(180, 600), width: 330, height: 120), D.fill(const Color(0xFFC98C58)));
    // mound
    c.drawOval(Rect.fromCenter(center: const Offset(180, 312), width: 70, height: 20), D.fill(const Color(0xFFB77C4B)));
    c.drawRect(Rect.fromCenter(center: const Offset(180, 310), width: 14, height: 3), D.fill(Pal.white));

    _pitcher(c);

    // plate & batter's boxes
    final plate = Path()
      ..moveTo(160, 578)
      ..lineTo(200, 578)
      ..lineTo(204, 590)
      ..lineTo(180, 602)
      ..lineTo(156, 590)
      ..close();
    c.drawPath(plate, D.fill(Pal.white));
    c.drawPath(plate, D.stroke(const Color(0x66000000), 2));
    final box = D.stroke(const Color(0xCCFFFFFF), 2.5);
    c.drawRect(const Rect.fromLTWH(70, 555, 70, 70), box);
    c.drawRect(const Rect.fromLTWH(220, 555, 70, 70), box);

    // strike zone + timing ring
    final zone = Rect.fromCenter(center: const Offset(180, 488), width: 96, height: 104);
    c.drawRect(zone, D.stroke(const Color(0x44FFFFFF), 2));
    if (_ph == _Ph.pitch && !_swung) {
      final k = M.clamp01(_bt);
      final r = 16 + (1 - k) * 70;
      final good = (1 - _bt) * _dur < .085;
      c.drawCircle(_target + Offset(_break, 0), r,
          D.stroke((good ? Pal.lime : Pal.yellow).withValues(alpha: .35 + .6 * k), 3 + k * 3));
      c.drawCircle(_target + Offset(_break, 0), 16, D.stroke(const Color(0x88FFFFFF), 2));
    }

    // ball
    if (_ph == _Ph.pitch || (_ph == _Ph.result && !_flightView && _log.isNotEmpty && _log.last == 0 && _pt < .3)) {
      final t = _ph == _Ph.pitch ? _bt : 1.18;
      final p = _ballPos(t);
      final r = M.lerp(3, 15, pow(M.clamp01(t), 1.9).toDouble());
      if (t > .15) {
        for (var i = 1; i <= 4; i++) {
          final q = _ballPos(t - i * .04);
          c.drawCircle(q, r * (1 - i * .18), D.fill(Color.fromRGBO(255, 255, 255, .18 - i * .035)));
        }
      }
      if (t <= 1.12) _baseball(c, p, r, _t * 30);
    }

    // catcher's mitt
    final mp = const Offset(186, 548) + Offset(0, _mitt * 8);
    c.drawOval(Rect.fromCenter(center: mp, width: 70, height: 58), D.fill(const Color(0xFF8A4B25)));
    c.drawOval(Rect.fromCenter(center: mp, width: 70, height: 58), D.stroke(Pal.ink, 3));
    c.drawOval(Rect.fromCenter(center: mp + const Offset(0, -3), width: 40, height: 30), D.fill(const Color(0xFF6B3518)));
    if (_mitt > .3) {
      _baseball(c, mp + const Offset(0, -3), 12, 0);
    }

    _batter(c);

    if (_pitchNo == 0 && _ph != _Ph.result) {
      D.hand(c, const Offset(280, 520), _t);
      D.text(c, host.tr('tap', 'TAP!'), const Offset(290, 470), size: 24, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _baseball(Canvas c, Offset p, double r, double spin) {
    D.circle(c, p, r, Pal.white, border: const Color(0xFF333344), borderWidth: max(1, r * .1));
    if (r > 5) {
      final seam = D.stroke(Pal.red, max(1, r * .12));
      final s = sin(spin) * r * .3;
      c.drawArc(Rect.fromCircle(center: p + Offset(-r * 1.1 + s, 0), radius: r * .8), -.9, 1.8, false, seam);
      c.drawArc(Rect.fromCircle(center: p + Offset(r * 1.1 + s, 0), radius: r * .8), pi - .9, 1.8, false, seam);
    }
  }

  void _pitcher(Canvas c) {
    const base = Offset(180, 312);
    final w = _ph == _Ph.windup ? M.clamp01(_pt / _windup) : 1.0;
    final throwK = _ph == _Ph.pitch ? M.clamp01(_pt / .15) : (_ph == _Ph.windup ? 0.0 : 1.0);
    final legLift = sin(pi * M.clamp01(w * 1.2)) * 14;
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(-throwK * .2);
    // legs
    D.line(c, const Offset(-3, -18), const Offset(-5, 0), Pal.white, 5);
    D.line(c, const Offset(3, -18), Offset(8 + legLift * .3, -legLift), Pal.white, 5);
    D.rrect(c, const Rect.fromLTWH(-9, -38, 18, 22), 5, const Color(0xFFE23B3B), border: Pal.ink, borderWidth: 1.5);
    // throwing arm swings from back to front
    final armA = M.lerp(-2.4, .9, throwK) + (w < 1 ? -w * .3 : 0);
    D.line(c, const Offset(6, -34), Offset(6 + cos(armA) * 16, -34 + sin(armA) * 16), Pal.skin, 4);
    D.line(c, const Offset(-6, -34), const Offset(-13, -24), Pal.skin, 4);
    D.circle(c, const Offset(-14, -23), 4, const Color(0xFF8A4B25));
    D.circle(c, const Offset(0, -45), 7.5, Pal.skin, border: Pal.ink, borderWidth: 1.5);
    c.drawArc(Rect.fromCircle(center: const Offset(0, -47), radius: 8), pi, pi, true, D.fill(const Color(0xFFE23B3B)));
    D.line(c, const Offset(-2, -47), const Offset(-12, -46), const Color(0xFFE23B3B), 3);
    c.restore();
  }

  void _batter(Canvas c) {
    // right-handed batter from behind, left of the plate
    const base = Offset(96, 650);
    final s = _swing < 0 ? 0.0 : M.clamp01(_swing / .16);
    final back = _swing > .5 ? M.clamp01((_swing - .5) / .4) : 0.0;
    final k = s * (1 - back);
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(k * .15);
    // legs
    D.line(c, const Offset(-16, -120), const Offset(-30, 0), const Color(0xFFEEEEF5), 22);
    D.line(c, const Offset(16, -120), Offset(34 + k * 10, 0), const Color(0xFFEEEEF5), 22);
    // torso
    D.rrect(c, const Rect.fromLTWH(-40, -236, 80, 124), 26, const Color(0xFFF4F4FA), border: Pal.ink, borderWidth: 3.5);
    for (var i = 0; i < 4; i++) {
      c.drawLine(Offset(-22 + i * 15.0, -232), Offset(-22 + i * 15.0, -114), D.stroke(const Color(0x333D6BFF), 3));
    }
    D.text(c, '55', const Offset(0, -176), size: 40, color: Pal.blue, stroke: Pal.ink, strokeWidth: 5);
    // bat + hands
    final hands = Offset.lerp(const Offset(30, -218), const Offset(80, -170), k)!;
    final batA = M.lerp(-2.2, .2, M.easeOut(k)) + (_swing < 0 ? sin(_t * 4) * .08 : 0);
    final tip = hands + Offset(cos(batA), sin(batA)) * 130;
    if (_swing >= 0 && _swing < .3) {
      // swing blur
      final blur = Path()..moveTo(hands.dx, hands.dy);
      for (var i = 0; i <= 8; i++) {
        final a = M.lerp(-2.2, batA, i / 8);
        final q = hands + Offset(cos(a), sin(a)) * 130;
        blur.lineTo(q.dx, q.dy);
      }
      blur.close();
      c.drawPath(blur, D.fill(const Color(0x55FFFFFF)));
    }
    D.line(c, hands, tip, Pal.ink, 17);
    D.line(c, hands, tip, const Color(0xFFD9A066), 12);
    D.line(c, hands + (tip - hands) * .55, tip, const Color(0xFFE8B57A), 15);
    D.line(c, const Offset(-30, -216), hands, const Color(0xFFF4F4FA), 16);
    D.line(c, const Offset(30, -216), hands, const Color(0xFFF4F4FA), 16);
    D.circle(c, hands, 11, Pal.ink);
    // helmet
    D.circle(c, const Offset(0, -262), 32, const Color(0xFF1E3FA8), border: Pal.ink, borderWidth: 4);
    c.drawCircle(const Offset(-12, -276), 8, D.fill(const Color(0x55FFFFFF)));
    D.rrect(c, const Rect.fromLTWH(-6, -252, 50, 12), 6, const Color(0xFF1E3FA8), border: Pal.ink, borderWidth: 3);
    c.restore();
  }

  void _renderFlight(Canvas c) {
    // camera follows the ball with a slow push-in
    final t = M.clamp01(_ft);
    final ball = _flightScreen(t);
    final zoom = 1 + .35 * M.easeInOut(t);
    final focus = Offset.lerp(const Offset(180, 380), ball, .55 * t)!;
    c.save();
    c.translate(180, 330);
    c.scale(zoom);
    c.translate(-focus.dx, -focus.dy + 30 * t);
    _sky(c, 640);
    _lights(c, const [Offset(10, 60), Offset(350, 60)]);
    // stands behind fence
    final fence = <Offset>[];
    final stands = <Offset>[];
    for (var i = 0; i <= 20; i++) {
      final a = -.8 + 1.6 * i / 20;
      fence.add(_field(115, a));
      stands.add(_field(175, a, 20));
    }
    final standsPath = Path()..moveTo(fence.first.dx, fence.first.dy);
    for (final p in stands) {
      standsPath.lineTo(p.dx, p.dy);
    }
    for (final p in fence.reversed) {
      standsPath.lineTo(p.dx, p.dy);
    }
    c.drawPath(standsPath..close(), D.fill(const Color(0xFF2A2255)));
    for (var i = 0; i < 20; i++) {
      for (var r = 0; r < 4; r++) {
        final a = -.78 + 1.56 * i / 19;
        final p = _field(122 + r * 13.0, a, 4 + r * 4.0);
        final j = (1 + _hype * 7) * M.wave(_t + i * .2 + r, 2 + _hype * 2);
        c.drawCircle(p + Offset(0, -j), 3.2, D.fill(Color.lerp(Pal.candy[(i + r * 3) % 8], const Color(0xFF151535), .4)!));
      }
    }
    // field grass
    final grass = Path()..moveTo(180, 640);
    grass.lineTo(_field(115, -.8).dx - 60, 640);
    for (final p in fence) {
      grass.lineTo(p.dx, p.dy);
    }
    grass.lineTo(_field(115, .8).dx + 60, 640);
    c.drawPath(grass..close(), D.fill(const Color(0xFF3FA34D)));
    for (var i = 1; i < 6; i++) {
      final band = Path();
      for (var k = 0; k <= 12; k++) {
        final p = _field(i * 20.0, -.8 + 1.6 * k / 12);
        k == 0 ? band.moveTo(p.dx, p.dy) : band.lineTo(p.dx, p.dy);
      }
      c.drawPath(band, D.stroke(const Color(0x22FFFFFF), 6));
    }
    // wall
    final wallTop = Path()..moveTo(fence.first.dx, fence.first.dy);
    for (var i = 0; i <= 20; i++) {
      final p = _field(115, -.8 + 1.6 * i / 20, 5);
      wallTop.lineTo(p.dx, p.dy);
    }
    for (final p in fence.reversed) {
      wallTop.lineTo(p.dx, p.dy);
    }
    c.drawPath(wallTop..close(), D.fill(const Color(0xFF1C6B3A)));
    final yl = Path();
    for (var i = 0; i <= 20; i++) {
      final p = _field(115, -.8 + 1.6 * i / 20, 5);
      i == 0 ? yl.moveTo(p.dx, p.dy) : yl.lineTo(p.dx, p.dy);
    }
    c.drawPath(yl, D.stroke(Pal.yellow, 2));
    // infield
    final home = _field(0, 0);
    final b1 = _field(27, .78), b2 = _field(38, 0), b3 = _field(27, -.78);
    c.drawPath(
        Path()
          ..moveTo(home.dx, home.dy + 14)
          ..lineTo(b1.dx + 26, b1.dy)
          ..lineTo(b2.dx, b2.dy - 14)
          ..lineTo(b3.dx - 26, b3.dy)
          ..close(),
        D.fill(const Color(0xFFC98C58)));
    c.drawPath(
        Path()
          ..moveTo(home.dx, home.dy)
          ..lineTo(b1.dx, b1.dy)
          ..lineTo(b2.dx, b2.dy)
          ..lineTo(b3.dx, b3.dy)
          ..close(),
        D.fill(const Color(0xFF3A9C4A)));
    for (final b in [b1, b2, b3, home]) {
      c.drawRect(Rect.fromCenter(center: b, width: 8, height: 5), D.fill(Pal.white));
    }
    D.line(c, home, _field(118, .8), const Color(0xCCFFFFFF), 2);
    D.line(c, home, _field(118, -.8), const Color(0xCCFFFFFF), 2);
    // fielders chasing
    for (final (d, a) in [(28.0, .45), (28.0, -.45), (70.0, 0.0), (72.0, .5), (72.0, -.5)]) {
      final chase = _field(d, a);
      final tgt = _field(min(_dist, 110), _ang);
      final p = Offset.lerp(chase, tgt, M.clamp01(_ft * .35))!;
      D.person(c, p, 16, const Color(0xFFE23B3B), running: true, run: _t * 18, face: Face.shocked, pants: Pal.white);
    }
    // distance marker on fence
    for (final (a, n) in [(-.55, '110'), (0.0, '122'), (.55, '110')]) {
      D.text(c, n, _field(115, a, 2.5), size: 8, color: Pal.white);
    }
    // ball shadow + trail
    final ground = _field(_dist * t, _ang);
    if (!_landed) D.shadow(c, ground, 10, 4, .35);
    if (_trailPts.length > 1) {
      for (var i = 1; i < _trailPts.length; i++) {
        final a = i / _trailPts.length;
        D.line(c, _trailPts[i - 1], _trailPts[i],
            _perfect ? Color.fromRGBO(255, (120 + 120 * a).round(), 40, a) : Color.fromRGBO(255, 240, 160, a * .8),
            (_perfect ? 3 : 1) + a * (_perfect ? 9 : 5));
      }
    }
    _baseball(c, ball, 6, _t * 20);
    if (_quality == 3 && !_landed) {
      c.drawCircle(ball, 10 + 3 * M.wave(_t, 6), D.stroke(const Color(0x88FFE066), 2));
    }
    c.restore();

    // distance counter (broadcast lower-third)
    final shown = (_dist * t).round();
    D.rrect(c, const Rect.fromLTWH(96, 560, 168, 50), 10, const Color(0xE6121530), border: Pal.yellow, borderWidth: 2.5);
    D.text(c, '${shown}m', const Offset(180, 585), size: 32, color: _dist * t >= 115 ? Pal.yellow : Pal.white);
    if (_slow < 1) {
      D.circle(c, const Offset(30, 590), 6, Pal.red);
      D.text(c, 'x0.5', const Offset(58, 590), size: 14, color: Pal.white, stroke: Pal.ink);
    }
  }

  void _renderHud(Canvas c) {
    // HR counter
    D.rrect(c, const Rect.fromLTWH(10, 40, 150, 34), 9, const Color(0xE6121530), border: Pal.white, borderWidth: 2);
    D.text(c, 'HR', const Offset(30, 57), size: 16, color: Pal.yellow);
    for (var i = 0; i < _need; i++) {
      final p = Offset(62 + i * 32.0, 57);
      if (i < _hr) {
        D.star(c, p, 13, Pal.yellow, border: Pal.ink);
      } else {
        D.star(c, p, 11, const Color(0x33FFFFFF), border: const Color(0x88FFFFFF));
      }
    }
    // pitch counter
    D.rrect(c, const Rect.fromLTWH(170, 40, 180, 34), 9, const Color(0xE6121530), border: Pal.white, borderWidth: 2);
    for (var i = 0; i < _pitches; i++) {
      final p = Offset(186 + i * 21.0, 57);
      final used = i < _log.length;
      final col = !used
          ? const Color(0x44FFFFFF)
          : switch (_log[i]) { 3 => Pal.yellow, 2 => Pal.orange, 1 => Pal.gray, _ => Pal.red };
      D.circle(c, p, 7.5, col, border: const Color(0xAAFFFFFF), borderWidth: 1.5);
    }
    if (_banner > 0) {
      final a = 1 - _banner;
      final s = a < .2 ? M.easeOutBack(a / .2) : 1.0;
      c.save();
      c.translate(180, _flightView ? 300 : 380);
      c.rotate(-.07);
      c.scale(s);
      D.title(c, _bannerText, Offset.zero, size: _bannerText.length > 8 ? 46 : 54, color: _bannerColor);
      c.restore();
    }
  }
}

enum _Ph { windup, pitch, result }

class _Firework {
  _Firework(this.p, this.col);
  final Offset p;
  final Color col;
  double t = 0;
}
