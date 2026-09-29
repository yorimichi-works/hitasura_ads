import 'dart:math' as math;

import '../engine/engine.dart';

/// No.137 Penalty Kick — World-Cup shootout. Swipe to shoot (angle = aim,
/// length = height, speed = power, bend = curve), then tap to dive as keeper.
class G137 extends MiniGame {
  static const _bot = bool.fromEnvironment('ARCADE_BOT');
  // true = you shoot, false = you keep goal
  static const _rounds = [true, false, true, false, true];
  static const _ballHome = Offset(180, 566);
  static const _keeperHome = Offset(180, 214); // keeper "reach" center (shooter view)

  int _round = 0;
  _Ph _ph = _Ph.aim;
  double _pt = 0; // time in phase
  double _t = 0;
  final List<bool> _you = [];
  final List<bool> _cpu = [];
  int _saves = 0;
  bool _decided = false;

  // swipe
  Offset? _sStart;
  double _sT0 = 0;
  final List<Offset> _trail = [];
  double _tapHint = 0;

  // ball (shooter view)
  Offset _ball = _ballHome;
  double _ballR = 22;
  Offset _bT = Offset.zero;
  double _curve = 0;
  double _loft = 0;
  double _flyDur = .6;
  double _bt = 0;
  double _spin = 0;
  Offset _bVel = Offset.zero;
  bool _free = false;
  bool _inNet = false;
  _Out _out = _Out.goal;
  double _kick = 0; // kicker lunge 0..1
  bool _shank = false;

  // keeper AI (shooter view)
  Offset _kTarget = _keeperHome;
  double _kDelay = .14;
  double _kDive = 0; // 0..1
  double _kDiveDur = .42;
  bool _kHappy = false;

  // keeper = you (save view)
  int _cpuZone = 1;
  Offset _cpuT = Offset.zero;
  double _cpuRun = .85;
  double _cpuFly = .55;
  int _myZone = -1;
  double _myDive = 0;
  double _cpuBt = 0;

  // presentation
  double _slow = 1;
  double _letter = 0;
  double _hype = 0; // crowd excitement 0..1
  double _sad = 0;
  double _netAmp = 0;
  Offset _netAt = const Offset(180, 200);
  double _banner = 0;
  String _bannerText = '';
  Color _bannerColor = Pal.yellow;
  double _wipe = -1; // -1 none; 0..1 transition
  final List<_Flash> _flashes = [];

  bool get _shooting => _rounds[_round];
  int get _g => _you.where((e) => e).length;
  int get _o => _cpu.where((e) => e).length;

  @override
  void init() {
    _resetShot();
  }

  void _resetShot() {
    _ball = _ballHome;
    _ballR = 22;
    _bt = 0;
    _free = false;
    _inNet = false;
    _kick = 0;
    _kDive = 0;
    _kTarget = _keeperHome;
    _kHappy = false;
    _sStart = null;
    _trail.clear();
    _shank = false;
  }

  void _resetSave() {
    _cpuZone = randInt(3);
    final zx = [72.0, 180.0, 288.0][_cpuZone];
    _cpuT = Offset(zx + rand(-24, 24), rand(190, 460));
    _cpuRun = .85 / host.speed;
    _cpuFly = .52 / host.speed;
    _myZone = -1;
    _myDive = 0;
    _cpuBt = 0;
    _kHappy = false;
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _pt += dt;
    _hype = M.approach(_hype, 0, 1.2, dt);
    _sad = M.approach(_sad, 0, 1.0, dt);
    _netAmp = M.approach(_netAmp, 0, 3.5, dt);
    _banner = max(0, _banner - dt);
    _tapHint = max(0, _tapHint - dt);
    _letter = M.approach(_letter, _slow < 1 ? 1 : 0, 10, dt);
    if (chance(dt * (2 + _hype * 25))) {
      _flashes.add(_Flash(Offset(rand(10, 350), rand(58, 140)), .12));
    }
    for (final f in _flashes) {
      f.life -= dt;
    }
    _flashes.removeWhere((f) => f.life <= 0);

    if (_wipe >= 0) {
      final before = _wipe;
      _wipe += dt / .45;
      if (before < .5 && _wipe >= .5) _nextRound();
      if (_wipe >= 1) _wipe = -1;
    }

    final sdt = dt * _slow;
    if (_bot && !host.finished && _wipe < 0) {
      if (_ph == _Ph.aim && _pt > .4) _launch(Offset(chance(.5) ? 86 : 274, 172), 0, .5, .44);
      if (!_shooting && _ph == _Ph.cpuFly && _pt > .1 && _myZone < 0) _dive(_cpuZone);
    }
    switch (_ph) {
      case _Ph.aim:
        if (_pt > 3.4 && _sStart == null && !host.finished) _autoShank();
      case _Ph.fly:
        _updateFly(sdt);
      case _Ph.result:
        _updateFree(sdt);
        _slow = _slow > .97 ? 1 : M.approach(_slow, 1, 6, dt);
        _kDive = min(1, _kDive + sdt / _kDiveDur);
        if (_pt > 1.05 && _wipe < 0 && !_decided) _startWipe();
      case _Ph.run:
        if (_pt >= _cpuRun) {
          _ph = _Ph.cpuFly;
          _pt = 0;
          host.sfx(Sfx.hitHeavy, volume: .8);
          host.sfx(Sfx.whoosh, rate: 1.2);
        }
        if (_myZone >= 0) _myDive = min(1, _myDive + dt / .28);
      case _Ph.cpuFly:
        if (_myZone >= 0) _myDive = min(1, _myDive + dt / .28);
        _cpuBt = min(1, _pt / _cpuFly);
        if (_cpuBt >= 1) _resolveCpu();
      case _Ph.cpuResult:
        _myDive = min(1, _myDive + dt / .28);
        _updateFree(dt);
        if (_pt > 1.0 && _wipe < 0 && !_decided) _startWipe();
    }
  }

  void _startWipe() {
    if (_round >= _rounds.length - 1) {
      _finish();
      return;
    }
    _wipe = 0;
    host.sfx(Sfx.swipe, volume: .6);
  }

  void _nextRound() {
    _round++;
    _slow = 1;
    _pt = 0;
    if (_shooting) {
      _ph = _Ph.aim;
      _resetShot();
    } else {
      _ph = _Ph.run;
      _resetSave();
    }
  }

  void _checkDecided() {
    var youLeft = 0, cpuLeft = 0;
    for (var i = _round + 1; i < _rounds.length; i++) {
      _rounds[i] ? youLeft++ : cpuLeft++;
    }
    if (_g > _o + cpuLeft || _g + youLeft <= _o) {
      _decided = true;
    }
  }

  void _finish() {
    if (host.finished) return;
    if (_g > _o) {
      host.fx.confetti(count: 90);
      host.sfx(Sfx.cheer);
      final diff = _g - _o;
      host.win(stars: (1 + (diff >= 2 ? 1 : 0) + (_saves >= 1 ? 1 : 0)).clamp(1, 3));
    } else {
      host.sfx(Sfx.aww);
      host.lose();
    }
  }

  @override
  void onTimeUp() => _finish();

  void _autoShank() {
    _shank = true;
    _launch(Offset(180 + rand(-20, 20), 246), 0, .1, .95);
    host.fx.pop(host.tr('oops', 'OOPS'), const Offset(180, 470), color: Pal.orange, size: 26);
  }

  void _launch(Offset target, double curve, double loft, double dur) {
    _bT = target;
    _curve = curve;
    _loft = loft;
    _flyDur = dur;
    _bt = 0;
    _ph = _Ph.fly;
    _pt = 0;
    _kick = 1;
    host.sfx(Sfx.hitHeavy);
    host.sfx(Sfx.whoosh, rate: 1.3, volume: .7);
    host.shake(4);
    host.fx.burst(_ballHome + const Offset(0, 14), const Color(0xFF6BBF4E), count: 10, speed: 160, size: 5);
    host.fx.ring(_ballHome, Pal.white, size: 50, life: .3);
    // keeper decision: 45% reads the right zone; the rest is a guess
    final zone = target.dx < 142 ? 0 : (target.dx > 218 ? 2 : 1);
    final guess = chance(_shank ? 1 : .35) ? zone : randInt(3);
    final ty = target.dy.clamp(172.0, 240.0);
    _kTarget = switch (guess) { 0 => Offset(104, ty), 2 => Offset(256, ty), _ => const Offset(180, 198) };
    _kDelay = .12 / host.speed;
    _kDiveDur = .42 / host.speed;
  }

  Offset _keeperReach() => Offset.lerp(_keeperHome, _kTarget, M.easeOut(M.clamp01(_kDive)))!;

  void _updateFly(double dt) {
    _bt += dt / _flyDur;
    _spin += dt * 20;
    if (_pt > _kDelay) _kDive = min(1, _kDive + dt / _kDiveDur);
    _kick = max(0, _kick - dt * 3);
    final t = M.clamp01(_bt);
    final e = 1 - pow(1 - t, 1.4).toDouble();
    final base = Offset.lerp(_ballHome, _bT, e)!;
    _ball = base + Offset(_curve * sin(pi * t), -_loft * 60 * sin(pi * t));
    _ballR = M.lerp(22, 8.5, e);
    // big moment → slow motion near the goal
    if (t > .55 && _slow == 1 && !_shank) {
      final predicted = _classify();
      final close = (_bT - _predictReach()).distance < 80;
      if (close || predicted == _Out.goal && _round == _rounds.length - 1) _slow = .33;
    }
    if (_bt >= 1) _resolveShot();
  }

  Offset _predictReach() {
    final remain = (1 - _bt) * _flyDur;
    final k = M.clamp01(_kDive + remain / _kDiveDur);
    return Offset.lerp(_keeperHome, _kTarget, M.easeOut(k))!;
  }

  _Out _classify() {
    final x = _bT.dx, y = _bT.dy;
    if (y < 144) return _Out.over;
    if (x < 62 || x > 298) return _Out.wide;
    if (x < 76 || x > 284 || y < 157) return _Out.post;
    final reach = _keeperReach();
    if ((_bT - reach).distance < (_shank ? 60 : 32)) return _Out.save;
    return _Out.goal;
  }

  void _resolveShot() {
    _out = _classify();
    _ph = _Ph.result;
    _pt = 0;
    _free = true;
    final at = _ball;
    switch (_out) {
      case _Out.goal:
        _you.add(true);
        _inNet = true;
        _bVel = Offset((_bT.dx - 180) * .3, -30);
        _netAt = at;
        _netAmp = 1;
        _hype = 1;
        host.sfx(Sfx.cheer);
        host.sfx(Sfx.explode, volume: .5);
        host.shake(9, .4);
        host.flash(Pal.white, .15);
        host.hitStop(.08);
        host.fx.confetti(count: 50);
        host.fx.burst(at, Pal.yellow, count: 24, speed: 300, shape: PartShape.star);
        _say(host.tr('goal', 'GOAL!!'), Pal.yellow);
        host.addScore(100, at + const Offset(0, -30));
      case _Out.save:
        _you.add(false);
        _kHappy = true;
        final away = (at - _keeperReach());
        _bVel = Offset(away.dx.sign * rand(160, 260), rand(120, 260));
        host.sfx(Sfx.punch);
        host.sfx(Sfx.aww, volume: .8);
        host.shake(6);
        host.hitStop(.1);
        host.fx.burst(at, Pal.white, count: 16, speed: 240);
        _say(host.tr('save', 'SAVED!'), Pal.red);
        _sad = 1;
      case _Out.post:
        _you.add(false);
        _bVel = Offset((_bT.dx - 180).sign * -80 + rand(-40, 40), 340);
        host.sfx(Sfx.clang);
        host.sfx(Sfx.aww, volume: .8);
        host.shake(7);
        host.fx.burst(at, Pal.white, count: 10, speed: 200, shape: PartShape.spark);
        _say(host.tr('post', 'POST!'), Pal.orange);
        _sad = 1;
      case _Out.over || _Out.wide:
        _you.add(false);
        _bVel = _out == _Out.over ? const Offset(0, -260) : Offset((_bT.dx - 180).sign * 220, -60);
        host.sfx(Sfx.oops);
        host.sfx(Sfx.aww, volume: .8);
        _say(host.tr('miss', 'MISS'), Pal.gray);
        _sad = 1;
    }
    _checkDecided();
  }

  void _updateFree(double dt) {
    if (_decided && _pt > 1.1) _finish();
    if (!_free) return;
    _spin += dt * 10;
    if (_shooting) {
      if (_inNet) {
        _bVel = _bVel * pow(.02, dt).toDouble();
        _ball += _bVel * dt;
        _ballR = M.approach(_ballR, 7.5, 3, dt);
        _ball = Offset(_ball.dx, M.approach(_ball.dy, 250, 2.5, dt));
      } else {
        _bVel = Offset(_bVel.dx, _bVel.dy + (_out == _Out.over ? 0 : 500 * dt));
        _ball += _bVel * dt;
        _ballR = _out == _Out.over ? max(2, _ballR - dt * 8) : _ballR + dt * (_bVel.dy > 0 ? 6 : 0);
      }
    } else {
      _bVel = Offset(_bVel.dx, _bVel.dy + 700 * dt);
      _ball += _bVel * dt;
    }
  }

  // ------------------------------------------------------- save phase ---
  Offset _cpuBallPos() {
    const spot = Offset(180, 362);
    final t = M.clamp01(_cpuBt);
    final e = t * t * (1.2 - .2 * t);
    return Offset.lerp(spot, _cpuT, e)! + Offset(0, -40 * sin(pi * t));
  }

  void _resolveCpu() {
    _ph = _Ph.cpuResult;
    _pt = 0;
    _free = true;
    _ball = _cpuBallPos();
    final saved = _myZone == _cpuZone;
    if (saved) {
      _cpu.add(false);
      _saves++;
      _kHappy = true;
      _hype = 1;
      _bVel = Offset(rand(-260, 260), -420);
      host.sfx(Sfx.punch);
      host.sfx(Sfx.cheer);
      host.shake(10, .35);
      host.hitStop(.1);
      host.flash(Pal.white, .12);
      host.fx.burst(_ball, Pal.yellow, count: 26, speed: 340, shape: PartShape.star);
      host.fx.ring(_ball, Pal.white, size: 90);
      _say(host.tr('save', 'SAVED!'), Pal.lime);
      host.addScore(100, _ball + const Offset(0, -40));
    } else {
      _cpu.add(true);
      _bVel = Offset((_cpuT.dx - 180) * .4, 60);
      host.sfx(Sfx.thud);
      host.sfx(Sfx.aww);
      host.shake(5);
      host.fx.burst(_ball, Pal.white, count: 12, speed: 200);
      _say(host.tr('goal', 'GOAL!!'), Pal.red);
      _sad = 1;
    }
    _checkDecided();
  }

  void _say(String s, Color c) {
    _bannerText = s;
    _bannerColor = c;
    _banner = 1.1;
  }

  // ------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    if (_bot) return;
    if (_wipe >= 0) return;
    if (_shooting && _ph == _Ph.aim) {
      _sStart = p;
      _sT0 = _t;
      _trail
        ..clear()
        ..add(p);
    } else if (!_shooting && (_ph == _Ph.run || _ph == _Ph.cpuFly) && _myZone < 0) {
      _dive(p.dx < 125 ? 0 : (p.dx > 235 ? 2 : 1));
    }
  }

  void _dive(int zone) {
    _myZone = zone;
    host.sfx(Sfx.swipe, rate: 1.2);
    host.sfx(Sfx.jump, volume: .5);
  }

  @override
  void onMove(Offset p) {
    if (_bot) return;
    if (_sStart != null && _ph == _Ph.aim) {
      if (_trail.length < 60) _trail.add(p);
    }
  }

  @override
  void onUp(Offset p) {
    if (_bot) return;
    final s = _sStart;
    if (s == null || _ph != _Ph.aim) return;
    _sStart = null;
    _trail.add(p);
    final v = p - s;
    if (v.dy > -40 || v.distance < 50) {
      _tapHint = 1;
      _trail.clear();
      return;
    }
    final dur = max(.05, _t - _sT0);
    final len = v.distance;
    final ax = v.dx / -v.dy;
    // curve: max signed deviation from the straight line
    final n = Offset(-v.dy, v.dx) / len;
    var dev = 0.0;
    for (final q in _trail) {
      final d = (q - s).dx * n.dx + (q - s).dy * n.dy;
      if (d.abs() > dev.abs()) dev = d;
    }
    final curve = (-dev * n.dx * 1.4).clamp(-70.0, 70.0);
    final h = (len - 120) / 320;
    final tx = 180 + ax * 380 + curve * .45;
    final ty = 252 - h.clamp(0.0, 1.4) * 100;
    final spd = len / dur;
    final pw = M.clamp01((spd - 500) / 1700);
    _launch(Offset(tx, ty), curve, h.clamp(0.0, 1.0) * .5, M.lerp(.8, .42, pw));
    if (pw > .75) host.fx.pop(host.tr('power', 'POWER!'), const Offset(180, 470), color: Pal.orange, size: 24);
  }

  @override
  void onKey(String key, bool down) {
    if (_bot) return;
    if (!down || _wipe >= 0) return;
    if (_shooting && _ph == _Ph.aim) {
      final tx = switch (key) { 'left' => 92.0, 'right' => 268.0, _ => 180.0 };
      _launch(Offset(tx, key == 'up' ? 165 : 200), 0, .3, .5);
    } else if (!_shooting && (_ph == _Ph.run || _ph == _Ph.cpuFly) && _myZone < 0) {
      _dive(switch (key) { 'left' => 0, 'right' => 2, _ => 1 });
    }
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    if (_shooting) {
      _renderShooter(c);
    } else {
      _renderKeeper(c);
    }
    _renderHud(c);
  }

  void _stadium(Canvas c, double horizon) {
    D.gradientBg(c, const [Color(0xFF070A24), Color(0xFF1A2358), Color(0xFF2E3C7A)],
        rect: Rect.fromLTWH(0, 0, 360, horizon));
    // light towers
    for (final x in [34.0, 326.0]) {
      final glow = Paint()
        ..shader = RadialGradient(colors: const [Color(0xAAFFFBE0), Color(0x00FFFBE0)])
            .createShader(Rect.fromCircle(center: Offset(x, 58), radius: 90));
      c.drawCircle(Offset(x, 58), 90, glow);
      D.rrect(c, Rect.fromCenter(center: Offset(x, 58), width: 46, height: 22), 4, const Color(0xFF2B2F4A));
      for (var i = 0; i < 4; i++) {
        for (var j = 0; j < 2; j++) {
          c.drawCircle(Offset(x - 15 + i * 10, 53 + j * 10), 3.6, D.fill(const Color(0xFFFFFDE8)));
        }
      }
    }
    // stands: tiers of bobbing fans
    final top = horizon - 110;
    for (var row = 0; row < 6; row++) {
      final y = top + 8 + row * 16.0;
      c.drawRect(Rect.fromLTWH(0, y - 6, 360, 16), D.fill(Color.lerp(const Color(0xFF232A5C), const Color(0xFF3A2F6E), row / 6)!));
      for (var i = 0; i < 26; i++) {
        final x = i * 14.0 + (row.isOdd ? 7 : 0);
        final ph = i * 1.7 + row * 2.3;
        final jump = (_hype * 9 + 1.5) * M.wave(_t + ph * .1, 2 + _hype * 2);
        final col = Pal.candy[(i * 7 + row * 3) % Pal.candy.length];
        c.drawCircle(Offset(x, y - jump), 5, D.fill(Color.lerp(col, const Color(0xFF1A1A40), .45)!));
        c.drawCircle(Offset(x, y - 6 - jump), 3.5, D.fill(const Color(0xFFE2B893)));
        if (_hype > .3 && (i + row) % 5 == 0) {
          D.line(c, Offset(x + 3, y - 6 - jump), Offset(x + 6, y - 16 - jump), const Color(0xFFE2B893), 2);
        }
      }
    }
    for (final f in _flashes) {
      D.star(c, f.p, 7 * (f.life / .12), const Color(0xEEFFFFFF));
    }
    // LED boards
    final by = horizon - 14;
    c.drawRect(Rect.fromLTWH(0, by, 360, 16), D.fill(const Color(0xFF101018)));
    for (var i = 0; i < 12; i++) {
      final x = ((i * 40 - _t * 60) % 480) - 60;
      final col = [Pal.pink, Pal.sky, Pal.yellow, Pal.lime][i % 4];
      c.drawRect(Rect.fromLTWH(x, by + 3, 32, 10), D.fill(col.withValues(alpha: .85)));
      c.drawRect(Rect.fromLTWH(x + 34, by + 6, 4, 4), D.fill(Pal.white));
    }
  }

  void _pitchStripes(Canvas c, double top) {
    for (var i = 0; i < 9; i++) {
      final a = top + (640 - top) * pow(i / 9, 1.6).toDouble();
      final b = top + (640 - top) * pow((i + 1) / 9, 1.6).toDouble();
      c.drawRect(Rect.fromLTRB(0, a, 360, b + 1), D.fill(i.isEven ? const Color(0xFF3FA34D) : const Color(0xFF4DB85A)));
    }
  }

  void _renderShooter(Canvas c) {
    const horizon = 252.0;
    _stadium(c, horizon);
    _pitchStripes(c, horizon);
    // lines
    final lp = D.stroke(const Color(0xDDFFFFFF), 3);
    c.drawLine(const Offset(0, 258), const Offset(360, 258), lp);
    c.drawPath(
        Path()
          ..moveTo(40, 258)
          ..lineTo(24, 296)
          ..lineTo(336, 296)
          ..lineTo(320, 258),
        lp);
    c.drawPath(
        Path()
          ..moveTo(-20, 258)
          ..lineTo(-90, 430)
          ..moveTo(380, 258)
          ..lineTo(450, 430)
          ..moveTo(-90, 430)
          ..lineTo(450, 430),
        lp);
    c.drawArc(const Rect.fromLTWH(110, 400, 140, 60), pi * .1, pi * .8, false, lp);
    c.drawOval(Rect.fromCenter(center: _ballHome + const Offset(0, 16), width: 20, height: 7), D.fill(const Color(0xEEFFFFFF)));

    _goal(c);
    _keeperSV(c);
    // ball shadow
    if (!(_ph == _Ph.result && _out == _Out.over)) {
      final groundY = _ph == _Ph.aim ? _ballHome.dy + 16 : M.lerp(_ballHome.dy + 16, 258, M.clamp01(_bt));
      D.shadow(c, Offset(_ball.dx, groundY), _ballR * 1.8, _ballR * .6, .3);
    }
    _drawBall(c, _ball, _ballR, _spin);
    _kicker(c);

    // swipe trail
    if (_trail.length > 1 && _ph == _Ph.aim) {
      final path = Path()..moveTo(_trail.first.dx, _trail.first.dy);
      for (final q in _trail.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      c.drawPath(path, D.stroke(const Color(0x88FFFFFF), 14));
      c.drawPath(path, D.stroke(Pal.yellow, 5));
    }
    // tutorial
    if (_ph == _Ph.aim && _sStart == null && (_round == 0 && _pt < 3 || _tapHint > 0)) {
      final k = (_t * .9) % 1;
      final from = const Offset(180, 540);
      final to = const Offset(110, 290);
      D.arrow(c, Offset.lerp(from, to, .5)!, to - from, 190, const Color(0x99FFD23F), width: 14);
      D.hand(c, Offset.lerp(from, to, M.easeInOut(k))!, _t);
      D.text(c, host.tr('swipe', 'SWIPE!'), const Offset(250, 470), size: 26, color: Pal.yellow, stroke: Pal.ink);
    }
    _letterbox(c);
  }

  void _goal(Canvas c) {
    // back net plane + sides with ripple
    const l = 70.0, r = 290.0, top = 150.0, gl = 258.0;
    const bl = 92.0, br = 268.0, btop = 136.0, bgl = 240.0;
    Offset disp(Offset p) {
      if (_netAmp < .01) return p;
      final d = (p - _netAt).distance;
      final k = _netAmp * math.exp(-d / 55) * 10 * sin(d * .12 - _t * 18);
      return p + Offset(0, -k) + (p - _netAt) * (-.08 * _netAmp * math.exp(-d / 60));
    }

    c.drawRect(const Rect.fromLTRB(bl, btop, br, bgl), D.fill(const Color(0x33000000)));
    final np = D.stroke(const Color(0x88FFFFFF), 1.2);
    for (var i = 0; i <= 14; i++) {
      final x = bl + (br - bl) * i / 14;
      final path = Path();
      for (var j = 0; j <= 8; j++) {
        final q = disp(Offset(x, btop + (bgl - btop) * j / 8));
        j == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
      }
      c.drawPath(path, np);
    }
    for (var j = 0; j <= 8; j++) {
      final y = btop + (bgl - btop) * j / 8;
      final path = Path();
      for (var i = 0; i <= 14; i++) {
        final q = disp(Offset(bl + (br - bl) * i / 14, y));
        i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
      }
      c.drawPath(path, np);
    }
    // side & roof nets
    for (var k = 0; k <= 5; k++) {
      final f = k / 5;
      c.drawLine(Offset(M.lerp(l, bl, f), M.lerp(top, btop, f)), Offset(M.lerp(l, bl, f), M.lerp(gl, bgl, f)), np);
      c.drawLine(Offset(M.lerp(r, br, f), M.lerp(top, btop, f)), Offset(M.lerp(r, br, f), M.lerp(gl, bgl, f)), np);
      c.drawLine(Offset(M.lerp(l, bl, f), M.lerp(top, btop, f)), Offset(M.lerp(r, br, f), M.lerp(top, btop, f)), np);
    }
    for (var k = 0; k <= 6; k++) {
      final y = top + (gl - top) * k / 6;
      c.drawLine(Offset(l, y), Offset(bl, btop + (bgl - btop) * k / 6), np);
      c.drawLine(Offset(r, y), Offset(br, btop + (bgl - btop) * k / 6), np);
    }
    // frame
    final shade = D.stroke(const Color(0xFF9AA3B8), 9);
    final post = D.stroke(Pal.white, 7);
    for (final p in [shade, post]) {
      c.drawLine(const Offset(l, gl), const Offset(l, top), p);
      c.drawLine(const Offset(r, gl), const Offset(r, top), p);
      c.drawLine(const Offset(l, top), const Offset(r, top), p);
    }
  }

  void _keeperSV(Canvas c) {
    // keeper from the front: hip follows the reach point
    final reach = _ph == _Ph.aim ? _keeperHome + Offset(sin(_t * 3) * 18, 0) : _keeperReach();
    final k = M.clamp01(_ph == _Ph.aim ? 0 : _kDive);
    final side = (_kTarget.dx - 180).sign;
    final ang = side * M.easeOut(k) * 1.25;
    final hip = Offset(reach.dx, M.lerp(234, reach.dy + 18, M.easeOut(k)));
    D.shadow(c, Offset(hip.dx, 258), 56, 10, .3);
    c.save();
    c.translate(hip.dx, hip.dy);
    c.rotate(ang);
    const jersey = Color(0xFFFFB800);
    // legs
    final spread = 8 + k * 6 + (_ph == _Ph.aim ? sin(_t * 6).abs() * 3 : 0);
    D.line(c, Offset(-5, 0), Offset(-spread, 24), const Color(0xFF222244), 8);
    D.line(c, Offset(5, 0), Offset(spread, 24), const Color(0xFF222244), 8);
    D.line(c, Offset(-spread, 24), Offset(-spread - 2, 26), Pal.ink, 9);
    D.line(c, Offset(spread, 24), Offset(spread + 2, 26), Pal.ink, 9);
    // arms reaching up/out
    final armUp = k > .1 ? 1.0 : .4;
    for (final s in [-1.0, 1.0]) {
      final hand = Offset(s * (22 + 6 * armUp), -28 - 18 * armUp);
      D.line(c, Offset(s * 9, -26), hand, jersey, 7);
      D.circle(c, hand, 7, const Color(0xFF3AE06A), border: Pal.ink, borderWidth: 2);
    }
    D.rrect(c, const Rect.fromLTWH(-12, -32, 24, 34), 7, jersey, border: Pal.ink, borderWidth: 2.2);
    D.text(c, '1', const Offset(0, -16), size: 13, color: Pal.ink);
    D.circle(c, const Offset(0, -41), 10, Pal.skin, border: Pal.ink, borderWidth: 2);
    c.drawArc(Rect.fromCircle(center: const Offset(0, -42), radius: 10.5), pi, pi, true, D.fill(const Color(0xFF3A2A20)));
    D.face(c, const Offset(0, -39), 8,
        _kHappy ? Face.smug : (_ph == _Ph.result && _out == _Out.goal ? Face.cry : Face.angry),
        blush: false);
    c.restore();
  }

  void _kicker(Canvas c) {
    // our striker, seen from behind
    final lunge = _kick;
    final base = Offset(126 + lunge * 26, 640);
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(lunge * .12);
    const shirt = Color(0xFF2F6BFF);
    // kicking leg
    D.line(c, const Offset(8, -64), Offset(22 + lunge * 20, -10 - lunge * 20), Pal.skin, 13);
    D.line(c, const Offset(-10, -64), const Offset(-16, 0), Pal.skin, 13);
    D.rrect(c, const Rect.fromLTWH(-24, -86, 46, 28), 8, Pal.white, border: Pal.ink, borderWidth: 2.5);
    D.rrect(c, const Rect.fromLTWH(-30, -150, 58, 70), 16, shirt, border: Pal.ink, borderWidth: 3);
    D.text(c, '10', const Offset(-1, -116), size: 26, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
    // arms
    D.line(c, const Offset(-26, -136), Offset(-44 - lunge * 8, -96), Pal.skin, 10);
    D.line(c, const Offset(24, -136), Offset(42 + lunge * 6, -100 - lunge * 20), Pal.skin, 10);
    D.circle(c, const Offset(-1, -166), 19, Pal.skin, border: Pal.ink, borderWidth: 3);
    c.drawCircle(const Offset(-1, -168), 19, D.fill(const Color(0xFFF2C230)));
    c.drawCircle(const Offset(-1, -168), 19, D.stroke(Pal.ink, 3));
    c.restore();
  }

  void _drawBall(Canvas c, Offset p, double r, double spin) {
    if (r < 1) return;
    D.circle(c, p, r, Pal.white, border: Pal.ink, borderWidth: max(1.2, r * .12));
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(spin);
    final pent = Path();
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + i * pi * 2 / 5;
      final q = Offset(cos(a), sin(a)) * r * .38;
      i == 0 ? pent.moveTo(q.dx, q.dy) : pent.lineTo(q.dx, q.dy);
    }
    c.drawPath(pent..close(), D.fill(Pal.ink));
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + i * pi * 2 / 5;
      c.drawCircle(Offset(cos(a), sin(a)) * r * .9, r * .2, D.fill(Pal.ink));
    }
    c.restore();
    c.drawCircle(p + Offset(-r * .35, -r * .4), r * .22, D.fill(const Color(0x88FFFFFF)));
  }

  void _renderKeeper(Canvas c) {
    const horizon = 214.0;
    _stadium(c, horizon);
    _pitchStripes(c, horizon);
    final lp = D.stroke(const Color(0xDDFFFFFF), 3);
    c.drawLine(const Offset(0, 292), const Offset(360, 292), lp);
    c.drawLine(const Offset(0, 292), const Offset(-120, 640), lp);
    c.drawLine(const Offset(360, 292), const Offset(480, 640), lp);
    c.drawLine(const Offset(-30, 470), const Offset(390, 470), lp);
    c.drawArc(const Rect.fromLTWH(130, 262, 100, 40), pi * 1.1, pi * .8, false, lp);
    c.drawOval(Rect.fromCenter(center: const Offset(180, 364), width: 12, height: 4), D.fill(Pal.white));

    // CPU striker (small, far)
    final runK = _ph == _Ph.run ? M.clamp01(_pt / _cpuRun) : 1.0;
    final zoneDir = (_cpuZone - 1).toDouble();
    final lean = _ph == _Ph.run && runK > .65 ? zoneDir * .3 * M.clamp01((runK - .65) / .35) : 0.0;
    final kpos = Offset.lerp(const Offset(126, 318), const Offset(168, 360), M.easeInOut(runK))!;
    c.save();
    c.translate(kpos.dx, kpos.dy);
    c.rotate(lean);
    D.person(c, Offset.zero, 58, const Color(0xFFE8303A),
        running: _ph == _Ph.run, run: _t * 16, face: _ph == _Ph.cpuResult && _cpu.isNotEmpty && _cpu.last ? Face.happy : Face.angry,
        hair: Pal.ink, pants: Pal.white);
    c.restore();

    // ball
    Offset bp;
    double br;
    if (_ph == _Ph.run) {
      bp = const Offset(180, 360);
      br = 6;
    } else if (_ph == _Ph.cpuFly) {
      bp = _cpuBallPos();
      br = M.lerp(6, 36, pow(M.clamp01(_cpuBt), 1.6).toDouble());
    } else {
      bp = _ball;
      br = 36;
    }
    final behind = _ph != _Ph.cpuResult || _cpu.isNotEmpty && _cpu.last;
    if (behind) {
      D.shadow(c, Offset(bp.dx, M.lerp(366, 600, M.clamp01(_cpuBt))), br * 1.6, br * .5, .25);
      _drawBall(c, bp, br, _t * 12);
    }

    // big goal frame (we stand inside it)
    final np = D.stroke(const Color(0x55FFFFFF), 1.4);
    for (var i = 0; i < 8; i++) {
      c.drawLine(Offset(i * 14.0, 80), Offset(0, 80 + i * 14.0 + 20), np);
      c.drawLine(Offset(360 - i * 14.0, 80), Offset(360, 80 + i * 14.0 + 20), np);
    }
    for (final p in [D.stroke(const Color(0xFF9AA3B8), 18), D.stroke(Pal.white, 13)]) {
      c.drawLine(const Offset(16, 660), const Offset(16, 100), p);
      c.drawLine(const Offset(344, 660), const Offset(344, 100), p);
      c.drawLine(const Offset(16, 100), const Offset(344, 100), p);
    }

    _meKeeper(c);
    if (!behind) _drawBall(c, _ball, br, _t * 14);

    // tutorial zones
    if (_ph == _Ph.run && _myZone < 0 && _round == 1) {
      for (var z = 0; z < 3; z++) {
        final r = Rect.fromLTWH(20 + z * 108.0, 400, 104, 150);
        D.rrect(c, r.deflate(4), 16, Color.fromRGBO(255, 255, 255, .12 + .08 * M.wave(_t, 2)),
            border: const Color(0x88FFFFFF), borderWidth: 2);
      }
      D.arrow(c, const Offset(70, 470), const Offset(-1, 0), 60, Pal.yellow);
      D.arrow(c, const Offset(290, 470), const Offset(1, 0), 60, Pal.yellow);
      D.arrow(c, const Offset(180, 470), const Offset(0, -1), 50, Pal.yellow);
      D.hand(c, const Offset(290, 500), _t);
      D.text(c, host.tr('tap', 'TAP!'), const Offset(180, 380), size: 26, color: Pal.yellow, stroke: Pal.ink);
    }
    _letterbox(c);
  }

  void _meKeeper(Canvas c) {
    final k = M.easeOut(_myDive);
    final dir = _myZone < 0 ? 0.0 : (_myZone - 1).toDouble();
    final hip = Offset(180 + dir * 118 * k, 540 - (dir == 0 && _myZone >= 0 ? 110 : 70) * k);
    final ang = dir * k * 1.2;
    c.save();
    c.translate(hip.dx, hip.dy + (_myZone < 0 ? sin(_t * 7).abs() * -4 : 0));
    c.rotate(ang);
    const jersey = Color(0xFF14C9C9);
    // legs
    D.line(c, const Offset(-18, 10), const Offset(-40, 110), const Color(0xFF1D2340), 24);
    D.line(c, const Offset(18, 10), const Offset(40, 110), const Color(0xFF1D2340), 24);
    // arms up and out
    final up = _myZone >= 0 ? 1.0 : .35;
    for (final s in [-1.0, 1.0]) {
      final hand = Offset(s * (62 + 18 * up), -70 - 60 * up);
      D.line(c, Offset(s * 30, -70), hand, jersey, 20);
      c.drawCircle(hand, 20, D.fill(const Color(0xFF3AE06A)));
      c.drawCircle(hand, 20, D.stroke(Pal.ink, 3.5));
      c.drawCircle(hand + const Offset(-5, -6), 6, D.fill(const Color(0x88FFFFFF)));
    }
    D.rrect(c, const Rect.fromLTWH(-38, -92, 76, 104), 22, jersey, border: Pal.ink, borderWidth: 4);
    D.text(c, '1', const Offset(0, -38), size: 44, color: Pal.white, stroke: Pal.ink, strokeWidth: 6);
    c.drawCircle(const Offset(0, -118), 28, D.fill(Pal.skin));
    c.drawCircle(const Offset(0, -122), 28, D.fill(const Color(0xFF3A2A20)));
    c.drawCircle(const Offset(0, -122), 28, D.stroke(Pal.ink, 4));
    D.circle(c, const Offset(-27, -114), 7, Pal.skin, border: Pal.ink, borderWidth: 3);
    D.circle(c, const Offset(27, -114), 7, Pal.skin, border: Pal.ink, borderWidth: 3);
    c.restore();
  }

  void _letterbox(Canvas c) {
    if (_letter < .01) return;
    final h = 46 * _letter;
    c.drawRect(Rect.fromLTWH(0, 0, 360, h + 36), D.fill(Pal.night));
    c.drawRect(Rect.fromLTWH(0, 640 - h, 360, h), D.fill(Pal.night));
    D.circle(c, Offset(24, 640 - h / 2), 6, Pal.red);
    D.text(c, 'x0.3', Offset(52, 640 - h / 2), size: 14, color: Pal.white);
  }

  void _renderHud(Canvas c) {
    // broadcast scoreboard
    const y = 50.0;
    D.rrect(c, const Rect.fromLTWH(26, y - 14, 308, 30), 8, const Color(0xE6121530), border: Pal.white, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(30, y - 11, 52, 24), 6, Pal.blue);
    D.text(c, host.tr('you', 'YOU'), const Offset(56, y + 1), size: 13, color: Pal.white, maxWidth: 50);
    D.rrect(c, const Rect.fromLTWH(278, y - 11, 52, 24), 6, Pal.red);
    D.text(c, host.tr('cpu', 'CPU'), const Offset(304, y + 1), size: 13, color: Pal.white, maxWidth: 50);
    D.rrect(c, const Rect.fromLTWH(154, y - 12, 52, 26), 6, Pal.yellow);
    D.text(c, '$_g - $_o', const Offset(180, y + 1), size: 17, color: Pal.ink);
    void dots(List<bool> r, int total, double x0, double dx) {
      for (var i = 0; i < total; i++) {
        final p = Offset(x0 + i * dx, y + 1);
        if (i < r.length) {
          if (r[i]) {
            D.circle(c, p, 7, Pal.lime, border: Pal.white, borderWidth: 1.5);
          } else {
            D.circle(c, p, 7, Pal.red, border: Pal.white, borderWidth: 1.5);
            D.line(c, p + const Offset(-3, -3), p + const Offset(3, 3), Pal.white, 2);
            D.line(c, p + const Offset(3, -3), p + const Offset(-3, 3), Pal.white, 2);
          }
        } else {
          D.circle(c, p, 6, const Color(0x33FFFFFF), border: const Color(0x88FFFFFF), borderWidth: 1.5);
        }
      }
    }

    dots(_you, 3, 96, 19);
    dots(_cpu, 2, 245, -19);

    // result banner
    if (_banner > 0) {
      final a = 1.1 - _banner;
      final s = a < .25 ? M.easeOutBack(a / .25) : 1.0;
      c.save();
      c.translate(180, 330);
      c.rotate(-.06);
      c.scale(s);
      D.rrect(c, const Rect.fromLTWH(-190, -36, 380, 72), 0, Color.lerp(_bannerColor, Pal.ink, .55)!.withValues(alpha: .85));
      D.title(c, _bannerText, Offset.zero, size: 52, color: _bannerColor);
      c.restore();
    }
    // wipe transition
    if (_wipe >= 0) {
      final x = M.lerp(-460, 460, _wipe);
      c.save();
      c.translate(x + 180, 320);
      c.rotate(-.35);
      c.drawRect(const Rect.fromLTWH(-160, -600, 320, 1200), D.fill(Pal.blue));
      c.drawRect(const Rect.fromLTWH(-160, -600, 30, 1200), D.fill(Pal.yellow));
      c.drawRect(const Rect.fromLTWH(130, -600, 30, 1200), D.fill(Pal.yellow));
      D.star(c, Offset.zero, 60, Pal.white);
      c.restore();
    }
  }
}

enum _Ph { aim, fly, result, run, cpuFly, cpuResult }

enum _Out { goal, save, post, over, wide }

class _Flash {
  _Flash(this.p, this.life);
  final Offset p;
  double life;
}
