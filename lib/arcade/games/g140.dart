import '../engine/engine.dart';

/// No.140 Sumo Slam — nail the tachiai timing, then mash LEFT/RIGHT
/// alternately to push. Tap the "!" to resist counter-attacks.
class G140 extends MiniGame {
  static const _ringL = 44.0; // tawara (straw bale) edges
  static const _ringR = 316.0;

  _Ph _ph = _Ph.tachiai;
  double _pt = 0;
  double _t = 0;

  // tachiai gauge
  double _needle = 0; // 0..1
  double _needleDir = 1;
  double _zoneC = .5;
  static const _zoneW = .16;

  // bout
  double _pos = 0; // -1 = you are out, +1 = cpu is out
  double _posShow = 0;
  int _lastSide = -1; // 0 left, 1 right
  int _combo = 0;
  double _pushAnim = 0;
  double _press = 0; // cpu pressure multiplier
  double _counterIn = 2.2;
  double _counterT = -1; // >=0 while a counter prompt is open
  Offset _counterAt = const Offset(180, 330);
  double _counterWin = .75;
  double _stagger = 0;
  int _pressedBtn = -1;
  double _pressedT = 0;
  double _clash = 0;
  bool _won = false;
  bool _lost = false;
  double _endT = 0;
  double _banner = 0;
  String _bannerText = '';
  Color _bannerColor = Pal.yellow;
  double _hype = 0;
  final List<Offset> _salt = [];

  static const _btnL = Rect.fromLTWH(18, 520, 150, 96);
  static const _btnR = Rect.fromLTWH(192, 520, 150, 96);

  @override
  void init() {
    _zoneC = rand(.55, .8);
    _needle = 0;
    for (var i = 0; i < 30; i++) {
      _salt.add(Offset(rand(80, 280), rand(300, 420)));
    }
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _pt += dt;
    _banner = max(0, _banner - dt);
    _pushAnim = M.approach(_pushAnim, 0, 10, dt);
    _clash = M.approach(_clash, 0, 6, dt);
    _stagger = M.approach(_stagger, 0, 4, dt);
    _hype = M.approach(_hype, 0, 1, dt);
    _pressedT = max(0, _pressedT - dt);
    _posShow = M.approach(_posShow, _pos, 12, dt);

    switch (_ph) {
      case _Ph.tachiai:
        _needle += _needleDir * dt * 1.25 * host.speed;
        if (_needle > 1) {
          _needle = 2 - _needle;
          _needleDir = -1;
        } else if (_needle < 0) {
          _needle = -_needle;
          _needleDir = 1;
        }
        if ((_pt * 1.5).floor() != ((_pt - dt) * 1.5).floor()) {
          // salt throw ambience
          host.fx.burst(Offset(chance(.5) ? 96 : 264, 250), Pal.white, count: 10, speed: 150, size: 3, gravity: 500);
          host.sfx(Sfx.spray, volume: .3);
        }
        if (_pt > 3.2) _tachiai(auto: true);
      case _Ph.clash:
        if (_pt > .5) {
          _ph = _Ph.push;
          _pt = 0;
        }
      case _Ph.push:
        _updatePush(dt);
      case _Ph.end:
        _endT += dt;
    }
  }

  void _updatePush(double dt) {
    // CPU pushes back constantly, harder over time
    _press = 1 + _pt * .06;
    _pos -= dt * .1 * host.speed * _press;
    if (_counterT >= 0) {
      _counterT += dt;
      if (_counterT > _counterWin) {
        // failed to resist: big shove
        _counterT = -1;
        _pos -= .3;
        _stagger = 1;
        _combo = 0;
        host.sfx(Sfx.hitHeavy);
        host.sfx(Sfx.aww, volume: .6);
        host.shake(10, .3);
        host.flash(Pal.red, .12);
        _say(host.tr('oops', 'OOPS'), Pal.red);
        _counterIn = rand(1.6, 2.4) / host.speed;
      }
    } else {
      _counterIn -= dt;
      if (_counterIn <= 0) {
        _counterT = 0;
        _counterWin = .8 / host.speed;
        _counterAt = Offset(rand(90, 270), rand(250, 420));
        host.sfx(Sfx.notify, rate: 1.3);
      }
    }
    _check();
  }

  void _check() {
    if (_pos >= 1 && !_won) {
      _won = true;
      _ph = _Ph.end;
      _endT = 0;
      _hype = 1;
      host.sfx(Sfx.crash);
      host.sfx(Sfx.cheer);
      host.shake(14, .5);
      host.flash(Pal.white, .2);
      host.hitStop(.12);
      host.fx.confetti(count: 90);
      host.fx.smoke(const Offset(330, 440), count: 12, color: const Color(0xCCD9B98A), size: 24);
      _say(host.tr('win', 'WIN!'), Pal.yellow);
      final t = host.time;
      host.win(stars: t < 8 ? 3 : (t < 11 ? 2 : 1));
    } else if (_pos <= -1 && !_lost) {
      _lost = true;
      _ph = _Ph.end;
      _endT = 0;
      host.sfx(Sfx.crash);
      host.sfx(Sfx.aww);
      host.shake(12, .5);
      host.fx.smoke(const Offset(30, 440), count: 12, color: const Color(0xCCD9B98A), size: 24);
      _say(host.tr('lose', 'LOSE'), Pal.gray);
      host.lose();
    }
  }

  void _tachiai({bool auto = false}) {
    final off = (_needle - _zoneC).abs();
    _ph = _Ph.clash;
    _pt = 0;
    _clash = 1;
    host.sfx(Sfx.hitHeavy);
    host.sfx(Sfx.punch, rate: .7);
    host.shake(12, .35);
    host.hitStop(.1);
    final at = const Offset(180, 360);
    host.fx.burst(at, Pal.white, count: 20, speed: 320, shape: PartShape.spark);
    host.fx.ring(at, Pal.yellow, size: 110);
    if (!auto && off < _zoneW * .25) {
      _pos = .35;
      _hype = 1;
      host.sfx(Sfx.perfect);
      host.sfx(Sfx.cheer, volume: .8);
      _say(host.tr('perfect', 'PERFECT!'), Pal.yellow);
    } else if (!auto && off < _zoneW / 2) {
      _pos = .2;
      host.sfx(Sfx.correct);
      _say(host.tr('great', 'GREAT!'), Pal.lime);
    } else if (!auto && off < _zoneW) {
      _pos = .05;
      _say(host.tr('good', 'GOOD'), Pal.sky);
    } else {
      _pos = -.25;
      _stagger = 1;
      host.sfx(Sfx.oops);
      _say(host.tr('miss', 'MISS'), Pal.gray);
    }
    _counterIn = rand(1.8, 2.4) / host.speed;
  }

  void _say(String s, Color c) {
    _bannerText = s;
    _bannerColor = c;
    _banner = .9;
  }

  void _mash(int side) {
    if (_ph != _Ph.push) return;
    _pressedBtn = side;
    _pressedT = .08;
    if (_counterT >= 0) {
      // bracing is required during a counter — mashing does little
      _pos += .008;
      host.sfx(Sfx.tap, volume: .4);
      return;
    }
    if (side == _lastSide) {
      _combo = 0;
      _pos -= .01;
      host.sfx(Sfx.squish, volume: .6);
      host.fx.pop('!?', side == 0 ? const Offset(90, 500) : const Offset(270, 500), color: Pal.orange, size: 22);
      _lastSide = side;
      return;
    }
    _lastSide = side;
    _combo++;
    final k = 1 + min(_combo, 20) * .03;
    _pos += .052 * k;
    _pushAnim = 1;
    host.sfx(Sfx.slap, rate: 1 + min(_combo, 16) * .04, volume: .8);
    if (_combo % 3 == 0) host.sfx(Sfx.step, volume: .6);
    host.shake(2.5);
    final at = Offset(180 + _posShow * 60 + (side == 0 ? -12 : 12), 330 + rand(-30, 30));
    host.fx.burst(at, Pal.white, count: 5, speed: 150, size: 4, gravity: 0);
    if (_combo % 10 == 0) {
      host.fx.pop('${host.tr('combo', 'COMBO')} $_combo', const Offset(180, 200), color: Pal.pink, size: 26);
      host.sfx(Sfx.combo, rate: 1 + _combo * .02);
    }
    // sweat
    if (chance(.3)) {
      host.fx.add(Particle(
          pos: Offset(180 + _posShow * 60 + rand(-40, 40), 260),
          vel: Offset(rand(-90, 90), rand(-160, -60)),
          life: .6,
          color: const Color(0xCC8FD8FF),
          size: 6,
          gravity: 600));
    }
    _check();
  }

  void _resist() {
    _counterT = -1;
    _pos += .08;
    _hype = .7;
    host.sfx(Sfx.clang);
    host.sfx(Sfx.correct, rate: 1.2);
    host.shake(6);
    host.fx.burst(_counterAt, Pal.yellow, count: 18, speed: 260, shape: PartShape.star);
    host.fx.ring(_counterAt, Pal.white, size: 70);
    _say(host.tr('nice', 'NICE!'), Pal.lime);
    _counterIn = rand(1.6, 2.4) / host.speed;
    _check();
  }

  @override
  void onTimeUp() {
    // gyoji decision: whoever is further ahead
    if (_pos > .35) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    switch (_ph) {
      case _Ph.tachiai:
        _tachiai();
      case _Ph.push:
        if (_counterT >= 0 && (p - _counterAt).distance < 70) {
          _resist();
        } else {
          _mash(p.dx < 180 ? 0 : 1);
        }
      default:
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (_ph == _Ph.tachiai && (key == 'action' || key == 'up')) {
      _tachiai();
    } else if (_ph == _Ph.push) {
      if ((key == 'action' || key == 'up') && _counterT >= 0) {
        _resist();
      } else if (key == 'left') {
        _mash(0);
      } else if (key == 'right') {
        _mash(1);
      }
    }
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    _arena(c);
    _wrestlers(c);
    _ui(c);
  }

  void _arena(Canvas c) {
    D.gradientBg(c, const [Color(0xFF2A1208), Color(0xFF5A2A12), Color(0xFF8A4A20)]);
    // crowd tiers (masu-seki boxes)
    for (var row = 0; row < 7; row++) {
      final y = 150.0 + row * 20;
      c.drawRect(Rect.fromLTWH(0, y, 360, 2), D.fill(const Color(0x44000000)));
      for (var i = 0; i < 24; i++) {
        final x = i * 15.0 + (row.isOdd ? 7 : 0);
        final j = (1 + _hype * 7) * M.wave(_t + i * .17 + row * .4, 1.5 + _hype * 2);
        final col = [const Color(0xFF3B4C8C), const Color(0xFF8C3B3B), const Color(0xFF3B7C5C), const Color(0xFF6C5B8C)][(i + row) % 4];
        c.drawCircle(Offset(x, y + 10 - j), 5.5, D.fill(Color.lerp(col, Pal.ink, .35)!));
        c.drawCircle(Offset(x, y + 3 - j), 3.6, D.fill(const Color(0xFFC99A76)));
      }
    }
    // roof (tsuriyane) with tassels
    final roof = Path()
      ..moveTo(10, 118)
      ..quadraticBezierTo(180, 60, 350, 118)
      ..lineTo(330, 138)
      ..lineTo(30, 138)
      ..close();
    c.drawPath(roof, D.fill(const Color(0xFF3B2A20)));
    c.drawPath(roof, D.stroke(Pal.ink, 3));
    c.drawRect(const Rect.fromLTWH(30, 132, 300, 10), D.fill(const Color(0xFF6E1E28)));
    for (var i = 0; i < 10; i++) {
      c.drawCircle(Offset(45 + i * 30.0, 138), 3, D.fill(Pal.gold));
    }
    final tassels = [(28.0, Pal.green), (332.0, Pal.red)];
    for (final (x, col) in tassels) {
      D.line(c, Offset(x, 140), Offset(x, 186), col, 6);
      c.drawPath(
          Path()
            ..moveTo(x - 9, 186)
            ..lineTo(x + 9, 186)
            ..lineTo(x + 4, 222)
            ..lineTo(x - 4, 222)
            ..close(),
          D.fill(col));
    }
    // stage lights
    for (final x in [90.0, 270.0]) {
      final path = Path()
        ..moveTo(x - 10, 60)
        ..lineTo(x + 10, 60)
        ..lineTo(x + 90, 460)
        ..lineTo(x - 90, 460)
        ..close();
      c.drawPath(path, D.fill(const Color(0x14FFF3C0)));
    }
    // dohyo (raised clay platform)
    final top = Path()
      ..moveTo(-10, 420)
      ..lineTo(370, 420)
      ..lineTo(390, 470)
      ..lineTo(-30, 470)
      ..close();
    c.drawPath(
        Path()
          ..moveTo(-30, 470)
          ..lineTo(390, 470)
          ..lineTo(420, 640)
          ..lineTo(-60, 640)
          ..close(),
        D.fill(const Color(0xFF9A6B42)));
    for (var i = 0; i < 6; i++) {
      c.drawLine(Offset(-40, 490 + i * 26.0), Offset(400, 490 + i * 26.0), D.stroke(const Color(0x22000000), 2));
    }
    c.drawPath(top, D.fill(const Color(0xFFD9B98A)));
    // straw bales (tawara)
    for (final x in [_ringL, _ringR]) {
      D.rrect(c, Rect.fromCenter(center: Offset(x, 432), width: 18, height: 12), 5, const Color(0xFFC9A55A),
          border: const Color(0xFF8A6A2A), borderWidth: 2);
    }
    c.drawLine(const Offset(_ringL, 440), const Offset(_ringR, 440), D.stroke(const Color(0x33FFFFFF), 2));
    // shikiri lines
    c.drawLine(const Offset(160, 425), const Offset(160, 440), D.stroke(Pal.white, 4));
    c.drawLine(const Offset(200, 425), const Offset(200, 440), D.stroke(Pal.white, 4));
    for (final s in _salt) {
      c.drawCircle(Offset(s.dx, 420 + (s.dy - 300) * .15), 1.5, D.fill(const Color(0xAAFFFFFF)));
    }
    // gyoji (referee) with gunbai fan
    final lean = _ph == _Ph.end ? (_won ? .3 : -.3) : sin(_t * 3) * .05;
    c.save();
    c.translate(180, 330);
    c.scale(1.25);
    D.line(c, const Offset(-7, 28), const Offset(-8, 56), Pal.ink, 6);
    D.line(c, const Offset(7, 28), const Offset(8, 56), Pal.ink, 6);
    D.rrect(c, const Rect.fromLTWH(-16, -10, 32, 40), 10, const Color(0xFF6C3B9C), border: Pal.ink, borderWidth: 2);
    c.drawCircle(const Offset(0, -20), 11, D.fill(Pal.skin));
    c.drawCircle(const Offset(0, -20), 11, D.stroke(Pal.ink, 2));
    c.drawPath(
        Path()
          ..moveTo(-10, -28)
          ..quadraticBezierTo(0, -46, 10, -28)
          ..close(),
        D.fill(Pal.ink));
    D.face(c, const Offset(0, -19), 9, _ph == _Ph.end ? Face.shocked : Face.neutral, blush: false);
    c.rotate(lean);
    D.line(c, const Offset(10, -2), const Offset(28, -24), Pal.skin, 4);
    c.drawOval(Rect.fromCenter(center: const Offset(32, -36), width: 22, height: 26), D.fill(const Color(0xFF2A2A2A)));
    c.drawOval(Rect.fromCenter(center: const Offset(32, -36), width: 22, height: 26), D.stroke(Pal.gold, 2));
    c.restore();
  }

  void _rikishi(Canvas c, Offset feet, bool facingRight, Color mawashi, Face face, double lean, {double squash = 0, double spin = 0}) {
    c.save();
    c.translate(feet.dx, feet.dy);
    if (!facingRight) c.scale(-1, 1);
    c.rotate(lean + spin);
    final sq = 1 + squash * .06;
    c.scale(sq * .86, .86 / sq);
    const skin = Color(0xFFF2C09A);
    const skinD = Color(0xFFD99A70);
    // legs
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-50, -52, 32, 52), const Radius.circular(12)), D.fill(skinD));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(10, -52, 32, 52), const Radius.circular(12)), D.fill(skin));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-50, -52, 32, 52), const Radius.circular(12)), D.stroke(Pal.ink, 3));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(10, -52, 32, 52), const Radius.circular(12)), D.stroke(Pal.ink, 3));
    // belly
    final body = Rect.fromCenter(center: const Offset(0, -118), width: 124, height: 132);
    c.drawOval(body, D.fill(skin));
    c.drawOval(Rect.fromCenter(center: const Offset(14, -104), width: 80, height: 90), D.fill(const Color(0x22FFFFFF)));
    c.drawOval(body, D.stroke(Pal.ink, 3.5));
    c.drawCircle(const Offset(18, -110), 3, D.fill(skinD));
    // mawashi
    final mw = Path()
      ..moveTo(-60, -76)
      ..quadraticBezierTo(0, -60, 60, -76)
      ..lineTo(56, -48)
      ..quadraticBezierTo(0, -36, -56, -48)
      ..close();
    c.drawPath(mw, D.fill(mawashi));
    c.drawPath(mw, D.stroke(Pal.ink, 3));
    for (var i = 0; i < 4; i++) {
      D.line(c, Offset(-8 + i * 7.0, -44), Offset(-10 + i * 7.0, -24), Color.lerp(mawashi, Pal.ink, .3)!, 4);
    }
    // arm pushing forward
    final reach = 60 + _pushAnim * (facingRight ? 10 : 0);
    D.line(c, const Offset(30, -150), Offset(reach, -126), Pal.ink, 26);
    D.line(c, const Offset(30, -150), Offset(reach, -126), skin, 20);
    c.drawCircle(Offset(reach + 6, -126), 14, D.fill(skin));
    c.drawCircle(Offset(reach + 6, -126), 14, D.stroke(Pal.ink, 3));
    // head with topknot
    const hp = Offset(40, -190);
    c.drawCircle(hp, 30, D.fill(skin));
    c.drawCircle(hp, 30, D.stroke(Pal.ink, 3.5));
    c.drawArc(Rect.fromCircle(center: hp, radius: 31), pi * 1.05, pi * .9, true, D.fill(Pal.ink));
    c.drawOval(Rect.fromCenter(center: hp + const Offset(-6, -34), width: 24, height: 12), D.fill(Pal.ink));
    D.face(c, hp + const Offset(10, 4), 22, face, look: const Offset(1, 0));
    c.restore();
  }

  void _wrestlers(Canvas c) {
    final x = 180 + _posShow * 112;
    var you = Offset(x - 70, 432);
    var cpu = Offset(x + 70, 432);
    var youLean = .35 + _pushAnim * .06 - _stagger * .2;
    var cpuLean = .35 + (_counterT >= 0 ? .1 : 0);
    var cpuSpin = 0.0, youSpin = 0.0;
    if (_ph == _Ph.tachiai) {
      // crouched at the shikiri lines, bobbing
      final b = sin(_t * 5) * 3;
      you = Offset(88, 432 + b);
      cpu = Offset(272, 432 - b);
      youLean = .55;
      cpuLean = .55;
    } else if (_ph == _Ph.clash) {
      final k = M.easeOut(M.clamp01(_pt / .15));
      you = Offset.lerp(const Offset(88, 432), you, k)!;
      cpu = Offset.lerp(const Offset(272, 432), cpu, k)!;
    } else if (_ph == _Ph.end) {
      final k = _endT;
      if (_won) {
        cpu = cpu + Offset(k * 260, -sin(min(k * 3, pi)) * 120 + max(0, k - 1) * 200);
        cpuSpin = k * 5;
        youLean = -.1;
      } else {
        you = you + Offset(-k * 260, -sin(min(k * 3, pi)) * 120 + max(0, k - 1) * 200);
        youSpin = -k * 5;
        cpuLean = -.1;
      }
    }
    D.shadow(c, Offset(you.dx, 440), 120, 16, .3);
    D.shadow(c, Offset(cpu.dx, 440), 120, 16, .3);
    final youFace = _ph == _Ph.end
        ? (_won ? Face.happy : Face.dead)
        : (_stagger > .3 ? Face.shocked : (_combo > 8 ? Face.angry : Face.neutral));
    final cpuFace = _ph == _Ph.end
        ? (_won ? Face.cry : Face.smug)
        : (_counterT >= 0 ? Face.angry : (_pos > .5 ? Face.shocked : Face.angry));
    _rikishi(c, cpu, false, const Color(0xFF8C1E2E), cpuFace, cpuLean, spin: -cpuSpin);
    _rikishi(c, you, true, const Color(0xFF1E3F8C), youFace, youLean, squash: _pushAnim, spin: youSpin);
    if (_clash > .1) {
      final p = Offset((you.dx + cpu.dx) / 2, 320);
      D.star(c, p, 40 * _clash + 10, Pal.yellow, border: Pal.ink);
    }
    // sweat drops when struggling
    if (_ph == _Ph.push && (_t * 3).floor().isEven) {
      final p = Offset(you.dx + 40, 240 + (_t * 50) % 20);
      c.drawCircle(p, 4, D.fill(const Color(0xCC8FD8FF)));
      c.drawCircle(Offset(cpu.dx - 40, 240 + (_t * 45) % 20), 4, D.fill(const Color(0xCC8FD8FF)));
    }
  }

  void _ui(Canvas c) {
    // push meter (who is closer to the edge)
    D.rrect(c, const Rect.fromLTWH(20, 44, 320, 28), 14, const Color(0xE6121530), border: Pal.white, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(26, 50, 60, 16), 8, const Color(0xFF1E3F8C));
    D.rrect(c, const Rect.fromLTWH(274, 50, 60, 16), 8, const Color(0xFF8C1E2E));
    D.text(c, host.tr('you', 'YOU'), const Offset(56, 58), size: 11, color: Pal.white, maxWidth: 56);
    D.text(c, host.tr('cpu', 'CPU'), const Offset(304, 58), size: 11, color: Pal.white, maxWidth: 56);
    final mx = 180 + _posShow.clamp(-1.0, 1.0) * 86;
    c.drawRect(const Rect.fromLTWH(94, 55, 172, 6), D.fill(const Color(0x55FFFFFF)));
    D.circle(c, Offset(mx, 58), 9, Pal.yellow, border: Pal.ink, borderWidth: 2);

    switch (_ph) {
      case _Ph.tachiai:
        _gauge(c);
      case _Ph.push || _Ph.clash:
        final pr = _pressedT > 0 ? _pressedBtn : -1;
        final next = _lastSide == 0 ? 1 : 0;
        for (var side = 0; side < 2; side++) {
          final r = side == 0 ? _btnL : _btnR;
          final hot = side == next && _counterT < 0;
          D.button(c, r, '', color: hot ? Pal.orange : const Color(0xFF7A5A40), pressed: pr == side);
          final ctr = r.center + Offset(0, pr == side ? 2 : -2);
          // palm icon (tsuppari hand)
          c.save();
          c.translate(ctr.dx, ctr.dy);
          if (side == 0) c.scale(-1, 1);
          D.rrect(c, const Rect.fromLTWH(-18, -16, 30, 34), 10, Pal.skin, border: Pal.ink, borderWidth: 2.5);
          for (var i = 0; i < 4; i++) {
            D.rrect(c, Rect.fromLTWH(-17 + i * 7.5, -30, 7, 18), 3.5, Pal.skin, border: Pal.ink, borderWidth: 2);
          }
          D.rrect(c, const Rect.fromLTWH(10, -6, 16, 8), 4, Pal.skin, border: Pal.ink, borderWidth: 2);
          c.restore();
          D.text(c, side == 0 ? 'L' : 'R', r.topLeft + const Offset(18, 16), size: 16, color: Pal.white, stroke: Pal.ink);
        }
        if (_ph == _Ph.push && _pt < 2.2 && _combo < 4) {
          D.hand(c, next == 0 ? _btnL.center : _btnR.center, _t);
          D.text(c, host.tr('tap', 'TAP!'), const Offset(180, 494), size: 22, color: Pal.yellow, stroke: Pal.ink);
        }
        if (_combo >= 5) {
          D.text(c, '$_combo', const Offset(180, 492), size: 30 + min(_combo, 30) * .4, color: Pal.yellow, stroke: Pal.ink);
        }
        if (_counterT >= 0) {
          final k = _counterT / _counterWin;
          final p = _counterAt;
          D.rays(c, p, 80, const Color(0x44FF3B5C), count: 10, t: _t * 3);
          c.drawCircle(p, 44, D.fill(Pal.red));
          c.drawCircle(p, 44, D.stroke(Pal.ink, 4));
          c.drawArc(Rect.fromCircle(center: p, radius: 52), -pi / 2, pi * 2 * (1 - k), false, D.stroke(Pal.yellow, 7));
          D.title(c, '!', p + const Offset(0, -4), size: 44, color: Pal.white, scale: 1 + .12 * M.wave(_t, 6));
          D.text(c, host.tr('tap', 'TAP!'), p + const Offset(0, 64), size: 18, color: Pal.white, stroke: Pal.ink);
        }
      case _Ph.end:
    }
    if (_banner > 0) {
      final a = .9 - _banner;
      final s = a < .2 ? M.easeOutBack(a / .2) : 1.0;
      c.save();
      c.translate(180, 170);
      c.scale(s);
      D.title(c, _bannerText, Offset.zero, size: 44, color: _bannerColor);
      c.restore();
    }
  }

  void _gauge(Canvas c) {
    const r = Rect.fromLTWH(30, 520, 300, 40);
    D.rrect(c, r.inflate(6), 14, const Color(0xE6121530), border: Pal.white, borderWidth: 2);
    D.rrect(c, r, 10, const Color(0xFF3A3050));
    final zl = r.left + r.width * (_zoneC - _zoneW);
    final zw = r.width * _zoneW * 2;
    D.rrect(c, Rect.fromLTWH(zl, r.top, zw, r.height), 6, Pal.green);
    D.rrect(c, Rect.fromLTWH(zl + zw * .25, r.top, zw * .5, r.height), 6, Pal.lime);
    D.rrect(c, Rect.fromLTWH(zl + zw * .375, r.top, zw * .25, r.height), 4, Pal.yellow);
    final nx = r.left + r.width * _needle;
    c.drawPath(
        Path()
          ..moveTo(nx, r.bottom + 4)
          ..lineTo(nx - 10, r.bottom + 18)
          ..lineTo(nx + 10, r.bottom + 18)
          ..close(),
        D.fill(Pal.white));
    D.line(c, Offset(nx, r.top - 6), Offset(nx, r.bottom + 4), Pal.ink, 7);
    D.line(c, Offset(nx, r.top - 6), Offset(nx, r.bottom + 4), Pal.white, 4);
    D.hand(c, const Offset(280, 590), _t, size: 38);
    D.text(c, host.tr('tap', 'TAP!'), const Offset(180, 500), size: 24, color: Pal.yellow, stroke: Pal.ink);
  }
}

enum _Ph { tachiai, clash, push, end }
