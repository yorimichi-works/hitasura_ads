import '../engine/engine.dart';

/// No.142 Punch Out Champ — read the wind-up, SWIPE away from the punch,
/// then TAP to counter-punch while the champ is open. KO him!
class G142 extends MiniGame {
  static const _bot = bool.fromEnvironment('ARCADE_BOT');
  static const _maxHp = 100.0;

  _Op _op = _Op.idle;
  double _ot = 0; // time in opponent state
  double _idleDur = .9;
  double _teleDur = .7;
  int _side = 1; // punching glove: -1 screen-left, 1 screen-right
  bool _double = false;
  double _hp = _maxHp;
  double _hpShow = _maxHp;
  int _hearts = 3;
  double _t = 0;

  // player
  double _dodge = 0; // -1..1 current offset
  int _dodgeDir = 0;
  double _dodgeT = 0;
  int _punchSide = 0;
  double _punchT = -1;
  int _lastPunch = 1;
  bool _counterReady = false;
  int _combo = 0;
  double _hurt = 0; // player got hit
  Offset? _downAt;

  // opponent reactions
  double _flinch = 0;
  int _flinchDir = 1;
  double _block = 0;
  double _koT = 0;
  bool _ko = false;
  bool _down = false;
  double _banner = 0;
  String _bannerText = '';
  Color _bannerColor = Pal.yellow;
  double _hype = 0;
  final List<_Flash> _flashes = [];
  bool _taughtSwipe = false;
  bool _taughtTap = false;

  bool get _rage => _hp < 45;

  @override
  void init() {
    _idleDur = 1.0;
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _ot += dt;
    _banner = max(0, _banner - dt);
    _flinch = M.approach(_flinch, 0, 7, dt);
    _block = M.approach(_block, 0, 8, dt);
    _hurt = M.approach(_hurt, 0, 3, dt);
    _hype = M.approach(_hype, 0, 1, dt);
    _hpShow = M.approach(_hpShow, _hp, 6, dt);
    if (chance(dt * (3 + _hype * 20)) && _flashes.length < 10) {
      _flashes.add(_Flash(Offset(rand(10, 350), rand(90, 250)), .1));
    }
    for (final f in _flashes) {
      f.life -= dt;
    }
    _flashes.removeWhere((f) => f.life <= 0);

    // player dodge motion
    if (_dodgeT > 0) {
      _dodgeT -= dt;
      _dodge = M.approach(_dodge, _dodgeDir.toDouble(), 22, dt);
    } else {
      _dodge = M.approach(_dodge, 0, 9, dt);
      _dodgeDir = 0;
    }
    if (_punchT >= 0) {
      _punchT += dt;
      if (_punchT > .16) _punchT = -1;
    }

    if (_ko) {
      _koT += dt;
      return;
    }
    if (_hearts <= 0) return;
    if (_bot) _botStep();

    final sp = host.speed * (_rage ? 1.25 : 1);
    switch (_op) {
      case _Op.idle:
        if (_ot > _idleDur) {
          if (chance(_rage ? .12 : .22)) {
            _setOp(_Op.taunt);
            host.sfx(Sfx.boing, rate: .8);
            _say(host.tr('open', 'OPEN!'), Pal.lime);
          } else {
            _startTele(double: _rage && chance(.5));
          }
        }
      case _Op.tele:
        if (_ot > _teleDur / sp) {
          _setOp(_Op.strike);
          host.sfx(Sfx.whoosh, rate: .8);
        }
      case _Op.strike:
        if (_ot > .14) _resolveStrike();
      case _Op.open:
        if (_ot > 1.05 / sqrt(host.speed)) {
          _counterReady = false;
          _backToIdle();
        }
      case _Op.taunt:
        if (_ot > .95) _backToIdle();
      case _Op.recover:
        if (_ot > .45) _backToIdle();
    }
  }

  void _botStep() {
    if (_op == _Op.tele && _ot > .3 && _dodgeT <= 0) _doDodge(-_side);
    if ((_op == _Op.open || _op == _Op.taunt) && (_t * 7).floor() != ((_t - 1 / 60) * 7).floor()) _doPunch(_lastPunch == 1 ? -1 : 1);
  }

  void _setOp(_Op o) {
    _op = o;
    _ot = 0;
  }

  void _backToIdle() {
    _setOp(_Op.idle);
    _idleDur = rand(.45, .9) / host.speed * (_rage ? .7 : 1);
  }

  void _startTele({bool double = false}) {
    _setOp(_Op.tele);
    _side = chance(.5) ? -1 : 1;
    _double = double;
    _teleDur = (_rage ? .55 : .72);
    host.sfx(Sfx.sparkle, rate: 1.4);
    host.sfx(Sfx.swing, volume: .4, rate: .6);
  }

  void _resolveStrike() {
    final dodged = _dodgeDir == -_side && _dodgeT > -.05 && _dodge.abs() > .3;
    if (dodged) {
      host.sfx(Sfx.whoosh, rate: 1.4);
      host.fx.pop(host.tr('dodge', 'DODGE!'), Offset(180 + _dodgeDir * 90.0, 420), color: Pal.sky, size: 26);
      if (_double) {
        _double = false;
        _setOp(_Op.tele);
        _side = -_side;
        _teleDur = .42;
        host.sfx(Sfx.sparkle, rate: 1.6);
        return;
      }
      _setOp(_Op.open);
      _counterReady = true;
      _hype = .5;
      host.sfx(Sfx.correct, rate: 1.2);
      _say(host.tr('counter', 'COUNTER!'), Pal.yellow);
    } else {
      _hearts--;
      _hurt = 1;
      _combo = 0;
      host.sfx(Sfx.hitHeavy);
      host.sfx(Sfx.hurt);
      host.shake(16, .4);
      host.flash(Pal.red, .25);
      host.hitStop(.12);
      host.fx.burst(const Offset(180, 470), Pal.yellow, count: 22, speed: 380, shape: PartShape.star);
      _say(_dodgeDir == _side ? host.tr('wrong_way', 'WRONG WAY!') : host.tr('ouch', 'OUCH!'), Pal.red);
      if (_hearts <= 0) {
        host.sfx(Sfx.aww);
        host.sfx(Sfx.bell);
        host.lose();
        return;
      }
      _setOp(_Op.recover);
    }
  }

  void _say(String s, Color c) {
    _bannerText = s;
    _bannerColor = c;
    _banner = .8;
  }

  void _doDodge(int dir) {
    if (_hearts <= 0 || _ko) return;
    _dodgeDir = dir;
    _dodgeT = .42;
    _taughtSwipe = true;
    host.sfx(Sfx.swipe, rate: 1.2);
  }

  void _doPunch(int side) {
    if (_hearts <= 0 || _ko || _dodgeT > .1) return;
    _punchSide = side;
    _punchT = 0;
    _lastPunch = side;
    final at = Offset(180 + side * 40.0 + _dodge * 20, 200);
    if (_op == _Op.open || _op == _Op.taunt) {
      final counter = _counterReady;
      _counterReady = false;
      final dmg = counter ? 12.0 : 5.0;
      _hp = max(0, _hp - dmg);
      _combo++;
      _flinch = 1;
      _flinchDir = side;
      _taughtTap = true;
      host.sfx(counter ? Sfx.hitHeavy : Sfx.punch, rate: 1 + min(_combo, 12) * .03);
      host.shake(counter ? 10 : 5);
      host.hitStop(counter ? .09 : .04);
      host.punch(counter ? .05 : .02);
      host.fx.burst(at, counter ? Pal.yellow : Pal.white, count: counter ? 22 : 10, speed: 300, shape: PartShape.star);
      host.fx.ring(at, Pal.white, size: counter ? 70 : 40);
      host.addScore(counter ? 50 : 10, at + const Offset(0, -30));
      if (_combo >= 3) host.fx.pop('$_combo ${host.tr('combo', 'COMBO')}', const Offset(180, 330), color: Pal.pink, size: 22);
      if (chance(.3)) {
        host.fx.add(Particle(
            pos: at,
            vel: Offset(side * rand(100, 240), rand(-300, -120)),
            life: .8,
            color: const Color(0xCC8FD8FF),
            size: 7,
            gravity: 900));
      }
      if (_hp <= 0) _knockout();
    } else {
      // blocked by the guard
      _hp = max(1, _hp - 1);
      _block = 1;
      _combo = 0;
      host.sfx(Sfx.clang, volume: .7);
      host.fx.burst(at + const Offset(0, 90), Pal.white, count: 6, speed: 180, shape: PartShape.spark);
      host.fx.pop(host.tr('block', 'BLOCK'), at + const Offset(0, 60), color: Pal.gray, size: 18);
    }
  }

  void _knockout() {
    _ko = true;
    _koT = 0;
    _hype = 1;
    host.sfx(Sfx.explode);
    host.sfx(Sfx.bell);
    host.sfx(Sfx.cheer);
    host.shake(20, .6);
    host.flash(Pal.white, .3);
    host.hitStop(.25);
    host.fx.confetti(count: 100);
    host.fx.burst(const Offset(180, 200), Pal.gold, count: 30, speed: 420, shape: PartShape.star);
    _say('K.O.!', Pal.yellow);
    host.win(stars: _hearts);
  }

  // ------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    _downAt = p;
  }

  @override
  void onMove(Offset p) {
    final d = _downAt;
    if (d == null) return;
    if ((p.dx - d.dx).abs() > 45) {
      _doDodge((p.dx - d.dx).sign.toInt());
      _downAt = null;
    }
  }

  @override
  void onUp(Offset p) {
    final d = _downAt;
    _downAt = null;
    if (d == null) return;
    if ((p.dx - d.dx).abs() > 30) {
      _doDodge((p.dx - d.dx).sign.toInt());
    } else {
      _doPunch(p.dx < 180 ? -1 : 1);
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    switch (key) {
      case 'left':
        _doDodge(-1);
      case 'right':
        _doDodge(1);
      case 'up' || 'action':
        _doPunch(_lastPunch == 1 ? -1 : 1);
    }
  }

  @override
  void onTimeUp() {
    host.sfx(Sfx.bell);
    host.lose();
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    // camera sway with dodge
    c.save();
    final roll = _hearts <= 0 ? min(1.0, _t * 0) : 0.0;
    c.translate(180, 320);
    c.rotate(-_dodge * .06 + roll);
    c.translate(-180 - _dodge * 30, -320);
    _arena(c);
    _champ(c);
    c.restore();
    _player(c);
    _hud(c);
    if (_hurt > .05) {
      c.drawRect(const Rect.fromLTWH(0, 0, 360, 640),
          Paint()
            ..shader = RadialGradient(colors: [const Color(0x00FF0000), Color.fromRGBO(255, 0, 40, .55 * _hurt)])
                .createShader(const Rect.fromLTWH(0, 0, 360, 640)));
    }
  }

  void _arena(Canvas c) {
    D.gradientBg(c, const [Color(0xFF07040F), Color(0xFF1C0F33), Color(0xFF2E1745)], rect: const Rect.fromLTWH(-60, -20, 480, 680));
    // crowd silhouettes
    for (var row = 0; row < 5; row++) {
      final y = 150.0 + row * 34;
      for (var i = 0; i < 14; i++) {
        final x = -40 + i * 34.0 + (row.isOdd ? 17 : 0);
        final j = (2 + _hype * 10) * M.wave(_t + i * .21 + row * .5, 1.5 + _hype * 3);
        final col = Color.lerp(const Color(0xFF120A22), const Color(0xFF3A2860), row / 5)!;
        c.drawCircle(Offset(x, y - j), 13, D.fill(col));
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y + 22 - j), width: 30, height: 30), const Radius.circular(10)),
            D.fill(col));
      }
    }
    for (final f in _flashes) {
      c.drawCircle(f.p, 16, D.fill(const Color(0x55FFFFFF)));
      D.star(c, f.p, 9, Pal.white);
    }
    // spotlight
    final spot = Path()
      ..moveTo(150, -20)
      ..lineTo(210, -20)
      ..lineTo(360, 470)
      ..lineTo(0, 470)
      ..close();
    c.drawPath(
        spot,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x33FFF3C0), Color(0x10FFF3C0)])
              .createShader(const Rect.fromLTWH(0, 0, 360, 470)));
    // ring floor
    final floor = Path()
      ..moveTo(40, 360)
      ..lineTo(320, 360)
      ..lineTo(460, 660)
      ..lineTo(-100, 660)
      ..close();
    c.drawPath(floor, D.fill(const Color(0xFF3C6FD1)));
    c.drawPath(
        Path()
          ..moveTo(60, 372)
          ..lineTo(300, 372)
          ..lineTo(400, 660)
          ..lineTo(-40, 660)
          ..close(),
        D.fill(const Color(0xFF4E86EA)));
    c.drawOval(Rect.fromCenter(center: const Offset(180, 470), width: 160, height: 50), D.fill(const Color(0x22FFFFFF)));
    // far ropes & posts
    for (final x in [40.0, 320.0]) {
      D.rrect(c, Rect.fromLTWH(x - 6, 250, 12, 115), 4, const Color(0xFFCCCCDD), border: Pal.ink, borderWidth: 2);
      D.rrect(c, Rect.fromLTWH(x - 9, 250, 18, 18), 4, Pal.red);
    }
    final ropes = [Pal.red, Pal.white, Pal.blue];
    for (var i = 0; i < 3; i++) {
      final y = 262.0 + i * 30;
      c.drawLine(Offset(40, y), Offset(320, y), D.stroke(Pal.ink, 6));
      c.drawLine(Offset(40, y), Offset(320, y), D.stroke(ropes[i], 4));
    }
    // side ropes coming toward the camera
    for (var i = 0; i < 3; i++) {
      final y = 262.0 + i * 30;
      c.drawLine(Offset(40, y), Offset(-80, y + 240), D.stroke(ropes[i], 5));
      c.drawLine(Offset(320, y), Offset(440, y + 240), D.stroke(ropes[i], 5));
    }
  }

  void _champ(Canvas c) {
    const skin = Color(0xFFC98A5A);
    const skinD = Color(0xFFA06A40);
    final breathe = sin(_t * 3) * 3;
    var bodyX = 180.0 + sin(_t * 1.7) * 8;
    var bodyY = 0.0;
    var tilt = 0.0;
    if (_op == _Op.tele) tilt = -_side * .08 * M.clamp01(_ot / .3);
    if (_op == _Op.strike) tilt = _side * .12;
    if (_op == _Op.open) tilt = sin(_ot * 9) * .08;
    tilt += _flinch * _flinchDir * .18;
    if (_ko) {
      final k = M.clamp01(_koT / .9);
      tilt = -.5 * M.easeOut(k);
      bodyY = 60 * M.easeOut(k);
      bodyX += 30 * k;
    }
    c.save();
    c.translate(bodyX, 400 + bodyY);
    c.rotate(tilt);
    // legs & trunks
    D.rrect(c, const Rect.fromLTWH(-70, -40, 140, 70), 20, const Color(0xFF7B2FBF), border: Pal.ink, borderWidth: 4);
    D.rrect(c, const Rect.fromLTWH(-72, -48, 144, 18), 8, Pal.gold, border: Pal.ink, borderWidth: 3);
    D.star(c, const Offset(0, -39), 11, Pal.red, border: Pal.ink);
    // torso (V shape)
    final torso = Path()
      ..moveTo(-110, -190 + breathe)
      ..quadraticBezierTo(-120, -110, -68, -44)
      ..lineTo(68, -44)
      ..quadraticBezierTo(120, -110, 110, -190 + breathe)
      ..quadraticBezierTo(0, -226 + breathe, -110, -190 + breathe)
      ..close();
    c.drawPath(torso, D.fill(skin));
    c.drawPath(torso, D.stroke(Pal.ink, 4));
    // pecs / abs
    final mus = D.stroke(skinD, 4);
    c.drawArc(Rect.fromLTWH(-80, -176 + breathe, 76, 50), .2, pi - .4, false, mus);
    c.drawArc(Rect.fromLTWH(4, -176 + breathe, 76, 50), .2, pi - .4, false, mus);
    for (var i = 0; i < 3; i++) {
      c.drawLine(Offset(-22, -112 + i * 22.0), Offset(-4, -112 + i * 22.0), mus);
      c.drawLine(Offset(4, -112 + i * 22.0), Offset(22, -112 + i * 22.0), mus);
    }
    c.drawLine(const Offset(0, -120), const Offset(0, -56), mus);
    // head
    final headOff = Offset(_flinch * _flinchDir * 26, -250 + breathe);
    c.save();
    c.translate(headOff.dx, headOff.dy);
    c.rotate(_flinch * _flinchDir * .35);
    final squash = 1 + _flinch * .15;
    c.scale(1 / squash, squash);
    D.rrect(c, const Rect.fromLTWH(-24, 10, 48, 40), 10, skin);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 104, height: 112), D.fill(skin));
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 104, height: 112), D.stroke(Pal.ink, 4));
    // mohawk
    final mh = Path()..moveTo(-16, -46);
    for (var i = 0; i < 5; i++) {
      mh
        ..lineTo(-14 + i * 7.0, -80 - (i == 2 ? 10 : 0))
        ..lineTo(-10 + i * 7.0, -52);
    }
    mh
      ..lineTo(16, -46)
      ..close();
    c.drawPath(mh, D.fill(Pal.red));
    c.drawPath(mh, D.stroke(Pal.ink, 3));
    // face
    final f = _ko
        ? Face.dead
        : switch (_op) {
            _Op.open => Face.shocked,
            _Op.taunt => Face.smug,
            _Op.tele || _Op.strike => Face.angry,
            _Op.recover => Face.smug,
            _ => _flinch > .3 ? Face.cry : Face.angry,
          };
    D.face(c, const Offset(0, 6), 46, f, blush: false);
    // unibrow scar
    c.drawLine(const Offset(18, -26), const Offset(30, -10), D.stroke(const Color(0xFF8A3A2A), 3));
    if (_op == _Op.taunt) {
      // tongue out
      c.drawOval(Rect.fromCenter(center: const Offset(4, 36), width: 18, height: 22), D.fill(Pal.pink));
    }
    c.restore();
    // dizzy stars
    if (_op == _Op.open || _ko) {
      for (var i = 0; i < 4; i++) {
        final a = _t * 5 + i * pi / 2;
        D.star(c, headOff + Offset(cos(a) * 64, -60 + sin(a) * 16), 10, Pal.yellow, border: Pal.ink);
      }
    }
    c.restore();

    // gloves (drawn in screen space so strikes can fly at the camera)
    final base = Offset(bodyX, 400 + bodyY);
    for (final s in [-1, 1]) {
      var p = base + Offset(s * 70.0, -236 + breathe);
      var r = 46.0;
      var glint = false;
      if (_ko) {
        p = base + Offset(s * 120.0, -120);
      } else if (_op == _Op.open || _op == _Op.taunt) {
        p = base + Offset(s * 118.0, -110 + sin(_t * 8 + s) * 8);
      } else if (s == _side && _op == _Op.tele) {
        final k = M.easeOut(M.clamp01(_ot / (_teleDur * .6)));
        p = base + Offset(s * (70 + 50 * k), -236 - 50 * k + sin(_t * 30) * 3 * k);
        r = 46 + 8 * k;
        glint = true;
      } else if (s == _side && _op == _Op.strike) {
        final k = M.clamp01(_ot / .14);
        final dodged = _dodgeDir == -_side && _dodge.abs() > .3;
        final target = dodged ? Offset(180 + s * 40 - _dodgeDir * 60, 520) : const Offset(180, 470);
        p = Offset.lerp(base + Offset(s * 120.0, -286), target, k)!;
        r = M.lerp(54, 120, k);
      } else if (_block > .1) {
        p = base + Offset(s * 40.0, -250 + breathe);
      } else {
        p = base + Offset(s * 46.0, -260 + breathe);
      }
      _glove(c, p, r, s);
      if (glint) {
        final g = p + Offset(-s * 14.0, -18);
        D.rays(c, g, 50, const Color(0x55FFFFFF), count: 8, t: _t * 4);
        D.star(c, g, 16 + 6 * M.wave(_t, 8), Pal.white, rotation: _t * 6);
        D.title(c, '!', p + const Offset(0, -80), size: 42, color: Pal.yellow, scale: 1 + .15 * M.wave(_t, 6));
      }
    }
  }

  void _glove(Canvas c, Offset p, double r, int s) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(s.toDouble(), 1);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 2), D.fill(const Color(0xFFE02A3A)));
    c.drawOval(Rect.fromCenter(center: Offset(-r * .7, r * .1), width: r * .8, height: r), D.fill(const Color(0xFFC01E2E)));
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 2), D.stroke(Pal.ink, 4));
    c.drawOval(Rect.fromCenter(center: Offset(r * .3, -r * .45), width: r * .6, height: r * .5), D.fill(const Color(0x66FFFFFF)));
    D.rrect(c, Rect.fromCenter(center: Offset(0, r * .95), width: r * 1.1, height: r * .5), r * .15, Pal.white,
        border: Pal.ink, borderWidth: 3);
    c.restore();
  }

  void _player(Canvas c) {
    final dx = _dodge * 110;
    final base = Offset(180 + dx, 640 + _hurt * 20);
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(_dodge * .25);
    // shoulders / back
    D.rrect(c, const Rect.fromLTWH(-110, -70, 220, 120), 50, const Color(0xFF2FAE66), border: Pal.ink, borderWidth: 4);
    // head (back view)
    c.drawCircle(const Offset(0, -92), 50, D.fill(const Color(0xFFE8B48A)));
    c.drawCircle(const Offset(0, -98), 50, D.fill(const Color(0xFF2B1B10)));
    c.drawCircle(const Offset(0, -98), 50, D.stroke(Pal.ink, 4));
    D.circle(c, const Offset(-48, -86), 11, const Color(0xFFE8B48A), border: Pal.ink, borderWidth: 3);
    D.circle(c, const Offset(48, -86), 11, const Color(0xFFE8B48A), border: Pal.ink, borderWidth: 3);
    c.restore();
    // gloves
    for (final s in [-1, 1]) {
      var p = Offset(180 + dx + s * 100.0, 520 + sin(_t * 5 + s) * 4);
      var r = 44.0;
      if (_punchT >= 0 && _punchSide == s) {
        final k = sin(pi * M.clamp01(_punchT / .16));
        p = Offset.lerp(p, Offset(180 + s * 40.0 + _dodge * 20, 240), k)!;
        r = M.lerp(44, 26, k);
      }
      c.save();
      c.translate(p.dx, p.dy);
      c.scale(-s.toDouble(), 1);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 2), D.fill(const Color(0xFF14C98A)));
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 2), D.stroke(Pal.ink, 4));
      c.drawOval(Rect.fromCenter(center: Offset(-r * .3, -r * .5), width: r * .6, height: r * .5), D.fill(const Color(0x66FFFFFF)));
      c.restore();
    }
  }

  void _hud(Canvas c) {
    // champ HP bar
    D.rrect(c, const Rect.fromLTWH(12, 40, 336, 42), 10, const Color(0xE6121530), border: Pal.white, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(18, 46, 72, 30), 7, Pal.red);
    D.text(c, host.tr('boss', 'BOSS'), const Offset(54, 61), size: 14, color: Pal.white, maxWidth: 66);
    final bar = const Rect.fromLTWH(98, 50, 240, 22);
    D.rrect(c, bar, 8, const Color(0xFF3A1020));
    final hpK = _hpShow / _maxHp;
    D.rrect(c, Rect.fromLTWH(bar.left, bar.top, bar.width * (hpK + (_hpShow - _hp) / _maxHp).clamp(0, 1), bar.height), 8,
        Pal.white);
    D.rrect(c, Rect.fromLTWH(bar.left, bar.top, bar.width * (_hp / _maxHp), bar.height), 8, _rage ? Pal.orange : Pal.yellow);
    D.text(c, '${_hp.ceil()}', bar.center, size: 14, color: Pal.ink);
    // hearts
    for (var i = 0; i < 3; i++) {
      D.heart(c, Offset(28 + i * 30.0, 102), 22, i < _hearts ? Pal.red : const Color(0x44FFFFFF), border: Pal.ink);
    }
    if (_rage && !_ko) {
      D.text(c, host.tr('danger', 'DANGER'), const Offset(300, 102), size: 16, color: Pal.orange, stroke: Pal.ink);
    }
    // tutorials
    if (_op == _Op.tele && !_taughtSwipe) {
      final dir = Offset(-_side.toDouble(), 0);
      D.arrow(c, Offset(180 - _side * 40.0, 440), dir, 110, Pal.yellow, width: 16);
      D.text(c, host.tr('swipe', 'SWIPE!'), const Offset(180, 390), size: 26, color: Pal.yellow, stroke: Pal.ink);
    }
    if ((_op == _Op.open || _op == _Op.taunt) && !_taughtTap) {
      D.hand(c, const Offset(180, 330), _t);
      D.text(c, host.tr('tap', 'TAP!'), const Offset(180, 300), size: 28, color: Pal.yellow, stroke: Pal.ink);
    }
    if (_banner > 0) {
      final a = .8 - _banner;
      final s = a < .15 ? M.easeOutBack(a / .15) : 1.0;
      c.save();
      c.translate(180, 150);
      c.rotate(-.05);
      c.scale(s * (_ko ? 1.5 : 1));
      D.title(c, _bannerText, Offset.zero, size: 44, color: _bannerColor);
      c.restore();
    }
  }
}

enum _Op { idle, tele, strike, open, taunt, recover }

class _Flash {
  _Flash(this.p, this.life);
  final Offset p;
  double life;
}
