import '../engine/engine.dart';

/// No.053 Count the Chicks — how many chicks are in the barn? (ducks don't count)
class G053 extends MiniGame {
  static const _doorX = 236.0;
  static const _laneY = 440.0;
  static const _btnY = 574.0;
  static const _btnX = [54.0, 138.0, 222.0, 306.0];

  final _animals = <_Animal>[];
  final _choices = <int>[];
  final _cpuGuess = List<int>.filled(4, 0);
  int _answer = 0;
  double _t = 0;
  double _askAt = 9.4;
  bool _asking = false;
  double _askT = 0;
  int _picked = -1;
  bool _correct = false;
  double _revT = 0;
  int _revShown = 0;
  double _speed = 1;
  double _barnBump = 0;
  final _btnPress = List<double>.filled(4, 0);

  @override
  void init() {
    _speed = host.speed;
    for (var attempt = 0; attempt < 60; attempt++) {
      _animals.clear();
      var chicks = 0, ducks = 0;
      for (var k = 0; k < 7; k++) {
        final start = (.45 + k * 1.12) / _speed;
        final duck = k > 0 && chance(.3);
        final n = 1 + randInt(3);
        bool inward;
        if (duck) {
          inward = ducks < n || chance(.5);
          ducks += inward ? n : -n;
        } else {
          inward = !(chicks >= n && k > 0 && chance(.42));
          chicks += inward ? n : -n;
        }
        for (var j = 0; j < n; j++) {
          _animals.add(_Animal(duck, inward, start + j * .2 / _speed, rand(-7, 7), rand(0, 6)));
        }
      }
      _answer = chicks;
      if (chicks >= 2 && chicks <= 8) break;
    }
    // choices: answer + near misses
    final opts = <int>{_answer};
    final deltas = [-2, -1, 1, 2, 3]..shuffle(rng);
    for (final d in deltas) {
      if (opts.length >= 4) break;
      if (_answer + d >= 0) opts.add(_answer + d);
    }
    _choices.addAll(opts.toList()..sort());
    // CPU guesses: Red overcounts ducks, Green is smug but off by one, Yellow is random-ish
    _cpuGuess[1] = _answer + (chance(.5) ? 2 : 1);
    _cpuGuess[2] = _answer + (chance(.6) ? -1 : 0);
    _cpuGuess[3] = max(0, _answer + randInt(5) - 2);
    _askAt = 9.4 / _speed;
  }

  double get _v => 170 * _speed;

  /// x position of an animal, or null when not visible.
  double? _ax(_Animal a) {
    final dt = _t - a.start;
    if (dt < 0) return null;
    if (a.inward) {
      final x = -24 + dt * _v;
      return x >= _doorX ? null : x;
    }
    final x = _doorX + dt * _v;
    return x > 390 ? null : x;
  }

  @override
  void onDown(Offset p) {
    if (!_asking || _picked >= 0) return;
    for (var i = 0; i < 4; i++) {
      if ((p - Offset(_btnX[i], _btnY)).distance < 40) {
        _pick(i);
        return;
      }
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down || !_asking || _picked >= 0) return;
    const map = {'left': 0, 'down': 1, 'up': 2, 'right': 3};
    final i = map[key];
    if (i != null) _pick(i);
  }

  void _pick(int i) {
    _picked = i;
    _btnPress[i] = 1;
    _correct = _choices[i] == _answer;
    host.sfx(Sfx.select);
    if (_correct) {
      host.sfx(Sfx.correct);
      host.sfx(Sfx.cheer, volume: .7);
      host.fx.confetti(count: 80);
      host.fx.burst(Offset(_btnX[i], _btnY), Pal.yellow, count: 20, speed: 280, shape: PartShape.star);
      host.win(stars: _askT < 2 ? 3 : (_askT < 3.5 ? 2 : 1));
    } else {
      host.sfx(Sfx.wrong);
      host.sfx(Sfx.aww, volume: .6);
      host.shake(6);
      host.lose();
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _barnBump = M.approach(_barnBump, 0, 8, dt);
    for (var i = 0; i < 4; i++) {
      _btnPress[i] = M.approach(_btnPress[i], 0, 8, dt);
    }
    for (final a in _animals) {
      final dtA = _t - a.start;
      if (!a.cued && dtA >= 0) {
        a.cued = true;
        if (!a.inward) {
          _barnBump = 1;
          host.sfx(a.duck ? Sfx.squish : Sfx.bubble, volume: .5, rate: a.duck ? .6 : 1.8);
        }
      }
      if (a.inward && !a.gone && _ax(a) == null && dtA > 0) {
        a.gone = true;
        _barnBump = 1;
        host.sfx(a.duck ? Sfx.squish : Sfx.pop, volume: .45, rate: a.duck ? .6 : 1.7);
      }
    }
    if (!_asking && _t >= _askAt) {
      _asking = true;
      host.sfx(Sfx.notify);
      host.sfx(Sfx.drumroll, volume: .4);
    }
    if (_asking && _picked < 0) _askT += dt;
    if (host.finished) {
      _revT += dt;
      final want = min(_answer, (_revT / .11).floor());
      while (_revShown < want) {
        _revShown++;
        host.sfx(Sfx.pop, rate: 1 + _revShown * .08, volume: .6);
        host.fx.pop('$_revShown', _revPos(_revShown - 1) + const Offset(0, -26), color: Pal.white, size: 18, life: .5);
      }
    }
  }

  Offset _revPos(int k) => Offset(36 + k * 30.0, 458);

  @override
  void onTimeUp() {
    if (_picked < 0) {
      host.sfx(Sfx.buzzer);
      host.lose();
    }
  }

  @override
  void render(Canvas c) {
    // sky & hills
    D.gradientBg(c, const [Color(0xFF7FD4FF), Color(0xFFCDEFFF), Color(0xFFFFF6D8)], rect: const Rect.fromLTWH(0, 0, 360, 360));
    D.circle(c, const Offset(300, 82), 28, const Color(0xFFFFE680));
    for (var i = 0; i < 3; i++) {
      D.cloud(c, Offset((i * 150 + _t * 9) % 520 - 80, 70 + i * 26.0), 46);
    }
    c.drawOval(const Rect.fromLTWH(-120, 250, 360, 200), D.fill(const Color(0xFF8ED66B)));
    c.drawOval(const Rect.fromLTWH(140, 260, 360, 200), D.fill(const Color(0xFF7CC95C)));
    // grass
    D.gradientBg(c, const [Color(0xFF79C85A), Color(0xFF55A83E)], rect: const Rect.fromLTWH(0, 340, 360, 300));
    // dirt path
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, 418, 380, 44), const Radius.circular(22)),
        D.fill(const Color(0xFFD9B27A)));
    for (var i = 0; i < 14; i++) {
      c.drawCircle(Offset(i * 28.0 + 8, 430 + (i * 7 % 20)), 2.5, D.fill(const Color(0xFFB88E58)));
    }
    // flowers
    for (var i = 0; i < 9; i++) {
      final p = Offset(20 + i * 40.0, 380 + (i * 13 % 26));
      D.circle(c, p, 4, i.isEven ? Pal.pink : Pal.white);
      D.circle(c, p, 1.6, Pal.yellow);
    }
    _renderFence(c);
    _renderBarn(c);
    // animals (sorted by lane so lower ones overlap)
    for (final a in _animals) {
      final x = _ax(a);
      if (x == null) continue;
      final hop = -sin((_t - a.start) * 18 + a.phase).abs() * 5;
      final pos = Offset(x, _laneY + a.lane + hop);
      if (a.duck) {
        _duck(c, pos, a.inward);
      } else {
        _chick(c, pos, a.inward, 1);
      }
    }
    // hay bale foreground
    D.rrect(c, const Rect.fromLTWH(300, 470, 70, 40), 10, const Color(0xFFF2C14E), border: const Color(0xFFB88A2A), borderWidth: 3);
    for (var i = 0; i < 3; i++) {
      D.line(c, Offset(308 + i * 18.0, 476), Offset(304 + i * 18.0, 504), const Color(0xFFD9A63A), 2);
    }

    if (!_asking) {
      // hint: count chicks, not ducks
      D.rrect(c, const Rect.fromLTWH(60, 500, 240, 56), 18, const Color(0xCC1B1530), border: Pal.white, borderWidth: 2.5);
      _chick(c, const Offset(106, 540), true, 1.3);
      D.text(c, '+1', const Offset(142, 526), size: 18, color: Pal.lime, stroke: Pal.ink);
      _duck(c, const Offset(214, 540), true, scale: .9);
      D.text(c, '=0', const Offset(256, 526), size: 18, color: Pal.red, stroke: Pal.ink);
      if (_t < 3) D.text(c, host.tr('count', 'COUNT!'), const Offset(180, 588), size: 24, color: Pal.yellow, stroke: Pal.ink);
    } else {
      _renderQuestion(c);
    }
    if (host.finished) _renderReveal(c);
  }

  void _renderFence(Canvas c) {
    // fence with the 3 rivals perched on it
    for (var i = 0; i < 6; i++) {
      D.rrect(c, Rect.fromLTWH(8 + i * 26.0, 322, 10, 52), 3, Pal.white, border: const Color(0xFFBBA88E), borderWidth: 2);
    }
    D.rrect(c, const Rect.fromLTWH(0, 332, 150, 9), 3, Pal.white, border: const Color(0xFFBBA88E), borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(0, 354, 150, 9), 3, Pal.white, border: const Color(0xFFBBA88E), borderWidth: 2);
    // watchers: eyes follow the newest visible animal
    var lookX = 180.0;
    for (final a in _animals) {
      final x = _ax(a);
      if (x != null) lookX = x;
    }
    for (var k = 1; k < 4; k++) {
      final p = Offset(k * 40.0 - 6, 334);
      final look = Offset(((lookX - p.dx) / 120).clamp(-1.0, 1.0), .6);
      Face face;
      if (host.finished) {
        face = _cpuGuess[k] == _answer ? Face.love : Face.cry;
      } else if (_asking) {
        face = k == 2 ? Face.smug : Face.shocked;
      } else {
        face = Face.neutral;
      }
      _Cast.draw(c, k, p, 16, face: face, look: look);
    }
  }

  void _renderBarn(Canvas c) {
    final bump = _barnBump * .03;
    c.save();
    c.translate(_doorX, 432);
    c.scale(1 + bump, 1 - bump);
    c.translate(-_doorX, -432);
    const l = 166.0, r = 306.0, top = 290.0, bot = 432.0;
    // roof
    final roof = Path()
      ..moveTo(l - 14, top + 4)
      ..lineTo(_doorX, 214)
      ..lineTo(r + 14, top + 4)
      ..close();
    c.drawPath(roof, D.fill(const Color(0xFF7A3B2E)));
    c.drawPath(roof, D.stroke(Pal.ink, 3.5));
    // wall
    D.rrect(c, const Rect.fromLTRB(l, top, r, bot), 4, const Color(0xFFD9423A), border: Pal.ink, borderWidth: 3.5);
    final gable = Path()
      ..moveTo(l, top)
      ..lineTo(_doorX, 228)
      ..lineTo(r, top)
      ..close();
    c.drawPath(gable, D.fill(const Color(0xFFD9423A)));
    for (var i = 0; i < 7; i++) {
      c.drawLine(Offset(l + 10 + i * 20.0, top + 4), Offset(l + 10 + i * 20.0, bot - 2), D.stroke(const Color(0x33000000), 2));
    }
    // loft window with a "?"
    D.circle(c, const Offset(_doorX, 264), 16, const Color(0xFF3A1A14), border: Pal.white, borderWidth: 4);
    D.text(c, '?', const Offset(_doorX, 264), size: 20, color: Pal.yellow);
    // door opening
    const door = Rect.fromLTRB(_doorX - 32, 352, _doorX + 32, bot);
    D.rrect(c, door, 4, const Color(0xFF2A120E), border: Pal.white, borderWidth: 4);
    // open door panels with X trim
    for (final s in [-1.0, 1.0]) {
      final panel = Rect.fromLTWH(s < 0 ? door.left - 30 : door.right, 352, 30, 80);
      D.rrect(c, panel, 3, const Color(0xFFC0342D), border: Pal.white, borderWidth: 3);
      D.line(c, panel.topLeft, panel.bottomRight, Pal.white, 3);
      D.line(c, panel.topRight, panel.bottomLeft, Pal.white, 3);
    }
    c.restore();
  }

  void _chick(Canvas c, Offset feet, bool right, double s) {
    final t = _t * 20 + feet.dx * .1;
    c.save();
    c.translate(feet.dx, feet.dy);
    c.scale((right ? 1 : -1) * s, s);
    // legs
    for (final k in [-1.0, 1.0]) {
      final sw = sin(t + (k > 0 ? 0 : pi)) * 3;
      D.line(c, Offset(k * 3, -5), Offset(k * 3 + sw, 0), const Color(0xFFFF8A1F), 2.2);
    }
    c.drawCircle(const Offset(0, -12), 10, D.fill(const Color(0xFFFFE14D)));
    c.drawCircle(const Offset(0, -12), 10, D.stroke(Pal.ink, 2));
    // wing
    c.drawOval(Rect.fromCenter(center: Offset(-2, -11 + sin(t) * 1.2), width: 9, height: 6), D.fill(const Color(0xFFF5C518)));
    // tuft
    D.line(c, const Offset(-1, -22), const Offset(1, -26), Pal.ink, 1.8);
    // eye & beak
    c.drawCircle(const Offset(4, -15), 1.8, D.fill(Pal.ink));
    final beak = Path()
      ..moveTo(8, -14)
      ..lineTo(14, -12)
      ..lineTo(8, -10)
      ..close();
    c.drawPath(beak, D.fill(const Color(0xFFFF8A1F)));
    c.restore();
  }

  void _duck(Canvas c, Offset feet, bool right, {double scale = 1}) {
    final t = _t * 16 + feet.dx * .1;
    c.save();
    c.translate(feet.dx, feet.dy);
    c.scale((right ? 1 : -1) * scale, scale);
    for (final k in [-1.0, 1.0]) {
      final sw = sin(t + (k > 0 ? 0 : pi)) * 3;
      D.line(c, Offset(k * 4, -5), Offset(k * 4 + sw, 0), const Color(0xFFFF8A1F), 3);
    }
    c.drawOval(const Rect.fromLTWH(-15, -20, 28, 17), D.fill(Pal.white));
    c.drawOval(const Rect.fromLTWH(-15, -20, 28, 17), D.stroke(Pal.ink, 2));
    c.drawCircle(const Offset(8, -26), 8, D.fill(Pal.white));
    c.drawCircle(const Offset(8, -26), 8, D.stroke(Pal.ink, 2));
    c.drawRect(const Rect.fromLTWH(2, -22, 10, 5), D.fill(Pal.white));
    c.drawCircle(const Offset(10, -28), 1.8, D.fill(Pal.ink));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(13, -26, 12, 5), const Radius.circular(3)),
        D.fill(const Color(0xFFFF8A1F)));
    c.drawOval(Rect.fromCenter(center: Offset(-3, -12 + sin(t) * 1.2), width: 12, height: 7), D.fill(const Color(0xFFE6E6F0)));
    c.restore();
  }

  void _renderQuestion(Canvas c) {
    final k = M.easeOutBack(M.clamp01((_t - _askAt) / .35));
    c.save();
    c.translate(0, (1 - k) * 200);
    D.rrect(c, const Rect.fromLTWH(14, 474, 332, 150), 24, const Color(0xE61B1530), border: Pal.white, borderWidth: 3);
    // "chicks in barn = ?"
    _chick(c, const Offset(118, 520), true, 1.4);
    D.arrow(c, const Offset(158, 506), const Offset(1, 0), 30, Pal.white, width: 7);
    D.rrect(c, const Rect.fromLTWH(184, 488, 34, 30), 4, const Color(0xFFD9423A), border: Pal.ink, borderWidth: 2);
    D.text(c, '= ?', const Offset(250, 504), size: 26, color: Pal.yellow, stroke: Pal.ink);
    for (var i = 0; i < 4; i++) {
      final picked = _picked == i;
      final right = host.finished && _choices[i] == _answer;
      Color col = Pal.sky;
      if (host.finished) {
        col = right ? Pal.green : (picked ? Pal.red : Pal.gray);
      }
      final r = Rect.fromCenter(center: Offset(_btnX[i], _btnY), width: 72, height: 62);
      D.button(c, r, '${_choices[i]}', color: col, pressed: picked, fontSize: 34);
      // CPU guesses marked as little heads over the buttons
      if (host.finished) {
        var n = 0;
        for (var cpu = 1; cpu < 4; cpu++) {
          if (_cpuGuess[cpu] == _choices[i]) {
            D.circle(c, Offset(_btnX[i] - 22 + n * 15.0, _btnY - 36), 7, _Cast.col[cpu], border: Pal.ink, borderWidth: 2);
            n++;
          }
        }
      }
    }
    if (_askT < 2.5 && _picked < 0) {
      D.hand(c, Offset(_btnX[1] + 10, _btnY + 10), _t, size: 36);
    }
    c.restore();
  }

  void _renderReveal(Canvas c) {
    // the chicks parade out of the barn to be counted
    for (var k = 0; k < _revShown; k++) {
      final p = _revPos(k);
      final hop = -sin(_revT * 14 + k).abs() * 5;
      _chick(c, p + Offset(0, hop), true, 1.1);
    }
    if (_revShown >= _answer) {
      D.title(c, '$_answer', const Offset(236, 392), size: 60, color: _correct ? Pal.yellow : Pal.white,
          scale: 1 + sin(_revT * 10) * .05);
    }
  }
}

class _Animal {
  _Animal(this.duck, this.inward, this.start, this.lane, this.phase);
  final bool duck;
  final bool inward;
  final double start;
  final double lane;
  final double phase;
  bool cued = false;
  bool gone = false;
}

/// Party cast shared by No.046–053: you (blue hero) vs Red, Green, Yellow.
abstract final class _Cast {
  static const col = [Color(0xFF3D8BFF), Color(0xFFFF4B5C), Color(0xFF37D67A), Color(0xFFFFCF33)];
  static const dark = [Color(0xFF1F4FB8), Color(0xFFB8243A), Color(0xFF1C8F4E), Color(0xFFC79A10)];
  static const mood = [Face.happy, Face.angry, Face.smug, Face.happy];

  /// Draws party member [i] standing with feet at [feet]. [run] animates feet.
  static void draw(Canvas c, int i, Offset feet, double r,
      {Face? face, double squash = 1, double tilt = 0, double? run, Offset look = Offset.zero, bool soot = false}) {
    c.save();
    c.translate(feet.dx, feet.dy);
    if (tilt != 0) c.rotate(tilt);
    if (squash != 1) c.scale(1 / sqrt(squash), squash);
    final body = soot ? const Color(0xFF3A3340) : col[i];
    final dk = soot ? const Color(0xFF221D28) : dark[i];
    // feet
    final ph = run ?? 0;
    for (final s in [-1.0, 1.0]) {
      final sw = run == null ? 0.0 : sin(ph * pi + (s > 0 ? 0 : pi));
      final lift = run == null ? 0.0 : max(0.0, sw) * r * .35;
      c.drawOval(Rect.fromCenter(center: Offset(s * r * .42 + sw * r * .38, -r * .08 - lift), width: r * .62, height: r * .36),
          D.fill(dk));
    }
    // accessories behind the body
    if (i == 1) {
      for (final s in [-1.0, 1.0]) {
        final p = Path()
          ..moveTo(s * r * .72, -r * 1.45)
          ..lineTo(s * r * .78, -r * 2.2)
          ..lineTo(s * r * .3, -r * 1.7)
          ..close();
        c.drawPath(p, D.fill(soot ? dk : const Color(0xFFFFF4DC)));
        c.drawPath(p, D.stroke(Pal.ink, max(1.5, r * .08)));
      }
    }
    D.blob(c, Offset(0, -r * .95), r, body, face: face ?? mood[i], look: look);
    final sw = max(1.5, r * .08);
    switch (i) {
      case 0: // hero cowlick + headband
        final p = Path()
          ..moveTo(-r * .2, -r * 1.82)
          ..quadraticBezierTo(-r * .15, -r * 2.5, r * .45, -r * 2.35)
          ..quadraticBezierTo(r * .05, -r * 2.2, r * .2, -r * 1.84)
          ..close();
        c.drawPath(p, D.fill(body));
        c.drawPath(p, D.stroke(Pal.ink, sw));
        c.drawRect(Rect.fromLTWH(-r * .92, -r * 1.52, r * 1.84, r * .2), D.fill(soot ? dk : Pal.white));
        final tail = Path()
          ..moveTo(r * .85, -r * 1.45)
          ..lineTo(r * 1.35, -r * 1.7 + sin(ph * 2) * r * .1)
          ..lineTo(r * 1.3, -r * 1.3)
          ..close();
        c.drawPath(tail, D.fill(soot ? dk : Pal.white));
        c.drawPath(tail, D.stroke(Pal.ink, sw * .7));
      case 2: // sprout
        c.drawLine(Offset(0, -r * 1.85), Offset(0, -r * 2.3), D.stroke(Pal.ink, sw));
        for (final s in [-1.0, 1.0]) {
          c.save();
          c.translate(s * r * .22, -r * 2.3);
          c.rotate(s * .6);
          final leaf = Rect.fromCenter(center: Offset.zero, width: r * .5, height: r * .26);
          c.drawOval(leaf, D.fill(soot ? dk : const Color(0xFF9BE22D)));
          c.drawOval(leaf, D.stroke(Pal.ink, sw * .8));
          c.restore();
        }
      case 3: // bow
        final o = Offset(r * .45, -r * 1.72);
        for (final s in [-1.0, 1.0]) {
          final p = Path()
            ..moveTo(o.dx, o.dy)
            ..lineTo(o.dx + s * r * .42, o.dy - r * .24)
            ..lineTo(o.dx + s * r * .42, o.dy + r * .24)
            ..close();
          c.drawPath(p, D.fill(soot ? dk : Pal.pink));
          c.drawPath(p, D.stroke(Pal.ink, sw * .8));
        }
        c.drawCircle(o, r * .12, D.fill(soot ? dk : Pal.pink));
        c.drawCircle(o, r * .12, D.stroke(Pal.ink, sw * .8));
    }
    c.restore();
  }
}
