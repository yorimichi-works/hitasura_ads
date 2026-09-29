import '../engine/engine.dart';

/// No.050 Balloon Chicken — pump bigger than the rivals, bank before it pops.
class G050 extends MiniGame {
  static const _step = .038;
  static final _bankRect = Rect.fromCenter(center: const Offset(290, 590), width: 112, height: 60);
  // CPU columns (top row)
  static const _cpuX = [0.0, 66.0, 180.0, 294.0];
  static const _cpuFeetY = 262.0;
  static const _pNozzle = Offset(180, 500);

  final _s = List<double>.filled(4, 0); // target size 0..1
  final _vis = List<double>.filled(4, 0); // animated size
  final _popped = List<bool>.filled(4, false);
  final _banked = List<bool>.filled(4, false);
  final _bankAt = List<double>.filled(4, 0);
  final _nextPump = List<double>.filled(4, 0);
  final _pumpAnim = List<double>.filled(4, 0);
  final _popT = List<double>.filled(4, 0);
  double _burst = .8; // shared hidden burst size (same balloon brand!)
  double _t = 0;
  bool _resolved = false;
  bool _won = false;
  double _resT = 0;
  int _winner = -1;
  double _bankPress = 0;
  int _pumps = 0;

  @override
  void init() {
    _burst = rand(.62, .98);
    _bankAt[1] = chance(.5) ? _burst + .05 : _burst - rand(.03, .1); // Red: greedy
    _bankAt[2] = _burst - rand(.14, .26); // Green: coward
    _bankAt[3] = chance(.3) ? _burst + .05 : _burst - rand(.05, .16); // Yellow: chaos
    for (var i = 1; i < 4; i++) {
      _nextPump[i] = rand(.2, .6);
    }
  }

  double _danger(int i) => M.clamp01((_s[i] - (_burst - .16)) / .16);

  bool get _done0 => _popped[0] || _banked[0];

  void _pump(int i) {
    if (_popped[i] || _banked[i]) return;
    _s[i] += _step;
    _pumpAnim[i] = 1;
    if (i == 0) {
      _pumps++;
      host.sfx(Sfx.squish, volume: .7, rate: .7 + _s[0] * 1.1);
      if (_danger(0) > .3) host.sfx(Sfx.crack, volume: .15 + _danger(0) * .3, rate: 1.6);
      host.fx.smoke(const Offset(150, 598), count: 1, color: const Color(0x88FFFFFF), size: 10);
    } else {
      host.sfx(Sfx.squish, volume: .25, rate: .9 + _s[i]);
    }
    if (_s[i] >= _burst) _pop(i);
  }

  void _pop(int i) {
    _popped[i] = true;
    _popT[i] = 0;
    final c = _balloonCenter(i);
    final r = _radius(i, _s[i]);
    host.sfx(Sfx.pop);
    host.sfx(Sfx.explodeSmall, volume: .7);
    host.fx.burst(c, _Cast.col[i], count: i == 0 ? 36 : 20, speed: i == 0 ? 520 : 320, shape: PartShape.confetti, size: 9,
        colors: [_Cast.col[i], _Cast.dark[i], Pal.white]);
    host.fx.ring(c, Pal.white, size: r * 1.6);
    host.fx.pop(host.tr('pop', 'POP!'), c, color: Pal.white, size: i == 0 ? 48 : 26);
    if (i == 0) {
      host.shake(14, .4);
      host.flash(Pal.white, .2);
      host.hitStop(.1);
      host.sfx(Sfx.aww, volume: .7);
      _resolved = true;
      _winner = -1;
      host.lose();
    } else {
      host.shake(4);
      if (!_done0) host.sfx(Sfx.oops, volume: .4);
    }
  }

  void _bank() {
    if (_done0 || _s[0] < .15) return;
    _banked[0] = true;
    _bankPress = 1;
    host.sfx(Sfx.stamp);
    host.sfx(Sfx.cash, volume: .6);
    host.fx.sparkle(_balloonCenter(0), count: 12, radius: _radius(0, _s[0]), color: Pal.yellow);
    host.fx.pop('${(_s[0] * 100).round()}', _balloonCenter(0), color: Pal.yellow, size: 40);
  }

  @override
  void onDown(Offset p) {
    if (_resolved) return;
    if (_bankRect.inflate(6).contains(p)) {
      _bank();
    } else {
      _pump(0);
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'action' || key == 'up') {
      _pump(0);
    } else if (key == 'down' || key == 'right') {
      _bank();
    }
  }

  double _radius(int i, double s) => i == 0 ? 20 + s * 88 : 9 + s * 36;

  Offset _balloonCenter(int i) {
    final r = _radius(i, _vis[i]);
    final wob = _danger(i) * sin(_t * 60 + i) * 2.5;
    if (i == 0) return _pNozzle + Offset(wob, -r * 1.05 - 8);
    return Offset(_cpuX[i] + wob, _cpuFeetY - 70 - r * 1.05);
  }

  @override
  void update(double dt) {
    _t += dt;
    _bankPress = M.approach(_bankPress, 0, 8, dt);
    for (var i = 0; i < 4; i++) {
      _vis[i] = M.approach(_vis[i], _s[i], 16, dt);
      _pumpAnim[i] = M.approach(_pumpAnim[i], 0, 10, dt);
      if (_popped[i]) _popT[i] += dt;
      if (i > 0 && !_popped[i] && !_banked[i] && !_resolved) {
        _nextPump[i] -= dt;
        if (_nextPump[i] <= 0) {
          _nextPump[i] = rand(.17, .27) / host.speed;
          if (_s[i] + _step > _bankAt[i] && _s[i] > .2) {
            _banked[i] = true;
            host.sfx(Sfx.ding, volume: .5, rate: 1 + i * .1);
            host.fx.pop('${(_s[i] * 100).round()}', _balloonCenter(i) + const Offset(0, -10), color: _Cast.col[i], size: 22);
          } else {
            _pump(i);
          }
        }
      }
    }
    if (!_resolved && !_done0 && host.time >= host.duration - 2.0) {
      host.fx.pop(host.tr('time', 'TIME!'), const Offset(180, 330), color: Pal.red, size: 36);
      if (_s[0] >= .15) {
        _bank();
      } else {
        _resolved = true;
        host.lose();
      }
    }
    if (!_resolved && _banked[0]) {
      final allDone = [1, 2, 3].every((i) => _popped[i] || _banked[i]);
      if (allDone) _resolve();
    }
    if (_resolved) _resT += dt;
  }

  void _resolve() {
    _resolved = true;
    var best = -1;
    var bestS = -1.0;
    for (final i in [1, 2, 3, 0]) {
      if (!_popped[i] && _s[i] >= bestS) {
        bestS = _s[i];
        best = i;
      }
    }
    _winner = best;
    _won = best == 0;
    if (_won) {
      final ratio = _s[0] / _burst;
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.cheer, volume: .8);
      host.fx.confetti(count: 90);
      host.fx.coins(_balloonCenter(0), count: 16);
      host.win(stars: ratio > .93 ? 3 : (ratio > .84 ? 2 : 1));
    } else {
      host.sfx(Sfx.buzzer, volume: .7);
      host.sfx(Sfx.aww, volume: .6);
      host.lose();
    }
  }

  @override
  void onTimeUp() {
    if (!_resolved) {
      for (var i = 1; i < 4; i++) {
        if (!_popped[i]) _banked[i] = true;
      }
      if (!_popped[0]) _banked[0] = true;
      _resolve();
    }
  }

  @override
  void render(Canvas c) {
    // circus tent backdrop
    D.gradientBg(c, const [Color(0xFF3B1E6E), Color(0xFF9B3FA8), Color(0xFFFF8FB1)]);
    for (var i = 0; i < 10; i++) {
      final x = i * 40.0 - 10;
      final p = Path()
        ..moveTo(x, 36)
        ..lineTo(x + 20, 36)
        ..lineTo(x + 30, 290)
        ..lineTo(x + 10, 290)
        ..close();
      c.drawPath(p, D.fill(i.isEven ? const Color(0x33FFFFFF) : const Color(0x22FF2D55)));
    }
    // scallop valance
    for (var i = 0; i < 10; i++) {
      c.drawArc(Rect.fromLTWH(i * 36.0, 26, 36, 32), 0, pi, true, D.fill(i.isEven ? Pal.red : Pal.white));
    }
    c.drawRect(const Rect.fromLTWH(0, 36, 360, 6), D.fill(Pal.gold));
    // string lights
    for (var i = 0; i < 16; i++) {
      final on = ((_t * 5).floor() + i) % 2 == 0;
      D.circle(c, Offset(12 + i * 22.0, 70 + sin(i * .8) * 6), 4, on ? Pal.yellow : const Color(0x88FFD23F));
    }
    // CPU shelf
    D.rrect(c, const Rect.fromLTWH(-10, _cpuFeetY - 2, 380, 22), 6, const Color(0xFF6B3A2A), border: Pal.ink, borderWidth: 3);
    for (var i = 1; i < 4; i++) {
      _renderPumpStation(c, i);
    }
    // floor
    D.gradientBg(c, const [Color(0xFFB9784F), Color(0xFF7A4A2E)], rect: const Rect.fromLTWH(0, 520, 360, 120));
    for (var i = 0; i < 8; i++) {
      c.drawRect(Rect.fromLTWH(0, 530 + i * 14.0, 360, 2), D.fill(const Color(0x33000000)));
    }
    // spotlight on player
    c.drawOval(Rect.fromCenter(center: const Offset(180, 560), width: 300, height: 70), D.fill(const Color(0x22FFFFFF)));
    _renderRuler(c);
    _renderPumpStation(c, 0);
    // bank button
    final down = _banked[0];
    final r = _bankRect.shift(Offset(0, _bankPress * 4));
    D.button(c, r, host.tr('bank', 'BANK'),
        color: down || _s[0] < .15 ? Pal.gray : (_danger(0) > .2 ? Color.lerp(Pal.green, Pal.yellow, M.wave(_t, 3))! : Pal.green),
        pressed: down, fontSize: 22);
    // size readout
    D.rrect(c, const Rect.fromLTWH(18, 566, 78, 48), 12, const Color(0xCC1B1530), border: Pal.white, borderWidth: 2);
    D.text(c, '${(_vis[0] * 100).round()}', const Offset(57, 590), size: 28,
        color: _danger(0) > .5 ? Pal.red : Pal.yellow, stroke: Pal.ink);
    // hint
    if (_pumps < 3 && !_resolved) {
      D.title(c, host.tr('tap', 'TAP!'), const Offset(180, 330), size: 40, color: Pal.white, scale: 1 + sin(_t * 12) * .06);
      D.hand(c, const Offset(222, 400), _t);
    } else if (_pumps >= 8 && !_done0 && _danger(0) > 0 && _t < 9) {
      D.arrow(c, Offset(290, 540 + sin(_t * 10) * 5), const Offset(0, 1), 34, Pal.yellow, width: 10);
    }
    if (_danger(0) > .35 && !_done0) {
      D.text(c, host.tr('danger', 'DANGER'), Offset(180 + sin(_t * 40) * 2, 170 + 90), size: 22, color: Pal.red, stroke: Pal.white);
    }
    // result
    if (_resolved && _resT > .1) {
      final k = M.easeOutBack(M.clamp01(_resT / .35));
      if (_winner >= 0) {
        final wc = _balloonCenter(_winner);
        D.star(c, wc + Offset(0, -_radius(_winner, _vis[_winner]) - 20), 16 * k, Pal.gold, border: Pal.ink);
      }
    }
  }

  double _topY(double s) => _pNozzle.dy - 8 - 2.125 * _radius(0, s);

  void _renderRuler(Canvas c) {
    const x = 30.0;
    final y0 = _topY(0), y1 = _topY(1);
    D.rrect(c, Rect.fromLTRB(x - 10, y1 - 8, x + 10, y0 + 8), 6, const Color(0xFFFFE9A8), border: Pal.ink, borderWidth: 2.5);
    for (var k = 0; k <= 20; k++) {
      final y = M.lerp(y0, y1, k / 20);
      D.line(c, Offset(x - 9, y), Offset(x + (k.isEven ? 3 : -3), y), Pal.ink, k % 10 == 0 ? 2.5 : 1.5);
      if (k % 4 == 0 && k > 0) D.text(c, '${k * 5}', Offset(x + 20, y), size: 10, color: Pal.white, stroke: Pal.ink);
    }
    // rival marks: the lines you have to beat
    for (var i = 1; i < 4; i++) {
      if (!_banked[i] || _popped[i]) continue;
      final y = _topY(_s[i]);
      for (var dx = x + 12; dx < 300; dx += 14) {
        D.line(c, Offset(dx, y), Offset(dx + 7, y), _Cast.col[i].withValues(alpha: .8), 2.5);
      }
      D.circle(c, Offset(x, y), 7, _Cast.col[i], border: Pal.ink, borderWidth: 2);
    }
    // your level
    final yy = _topY(_vis[0]);
    final p = Path()
      ..moveTo(x + 10, yy)
      ..lineTo(x + 22, yy - 7)
      ..lineTo(x + 22, yy + 7)
      ..close();
    c.drawPath(p, D.fill(_Cast.col[0]));
    c.drawPath(p, D.stroke(Pal.ink, 2));
  }

  void _renderPumpStation(Canvas c, int i) {
    final big = i == 0;
    final feetY = big ? 600.0 : _cpuFeetY;
    final charX = big ? 110.0 : _cpuX[i] - 26;
    final pumpX = big ? 150.0 : _cpuX[i] - 26;
    final r = _radius(i, _vis[i]);
    final bc = _balloonCenter(i);
    final nozzle = big ? _pNozzle : Offset(_cpuX[i], _cpuFeetY - 66);
    final pa = _pumpAnim[i];
    // pump body
    final ps = big ? 1.0 : .55;
    final pumpBase = Offset(pumpX + (big ? 40 : 26), feetY);
    D.rrect(c, Rect.fromCenter(center: pumpBase + Offset(0, -24 * ps), width: 30 * ps, height: 48 * ps), 5 * ps, Pal.red,
        border: Pal.ink, borderWidth: 2.5);
    final handleY = pumpBase.dy - 48 * ps - (1 - pa) * 22 * ps;
    D.line(c, Offset(pumpBase.dx, pumpBase.dy - 48 * ps), Offset(pumpBase.dx, handleY), Pal.gray, 4 * ps);
    D.rrect(c, Rect.fromCenter(center: Offset(pumpBase.dx, handleY), width: 40 * ps, height: 9 * ps), 4, Pal.ink);
    // hose
    final hose = Path()
      ..moveTo(pumpBase.dx + 10 * ps, pumpBase.dy - 6)
      ..quadraticBezierTo(nozzle.dx + 30 * ps, pumpBase.dy + 4, nozzle.dx, nozzle.dy);
    c.drawPath(hose, D.stroke(Pal.ink, 6 * ps));
    c.drawPath(hose, D.stroke(const Color(0xFF55C0A0), 3.5 * ps));
    // character hopping on the pump
    final hop = -pa * 10 * ps;
    Face face;
    if (_popped[i]) {
      face = Face.shocked;
    } else if (_resolved && _winner == i) {
      face = Face.love;
    } else if (_resolved) {
      face = Face.sad;
    } else if (_banked[i]) {
      face = Face.smug;
    } else if (_danger(i) > .3) {
      face = Face.shocked;
    } else {
      face = i == 0 ? Face.happy : _Cast.mood[i];
    }
    final cr = big ? 30.0 : 17.0;
    final cp = Offset(charX, feetY + hop);
    D.shadow(c, Offset(charX, feetY + 2), cr * 2, 8, .25);
    _Cast.draw(c, i, cp, cr, face: face, squash: 1 - pa * .15, look: const Offset(1, -1));
    if (_popped[i]) {
      // shredded rubber stuck on the face
      final k = M.clamp01(_popT[i] / .1);
      final head = cp + Offset(0, -cr * .95);
      for (var s = 0; s < 4; s++) {
        final a = s * 1.7;
        c.save();
        c.translate(head.dx + cos(a) * cr * .45 * k, head.dy + sin(a) * cr * .35 * k);
        c.rotate(a);
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: cr * .9, height: cr * .45), D.fill(_Cast.dark[i]));
        c.restore();
      }
    }
    // name tag
    if (!big) {
      D.text(c, '${host.tr('cpu', 'CPU')}$i', Offset(_cpuX[i], _cpuFeetY + 9), size: 11, color: Pal.white);
    }
    // balloon
    if (!_popped[i]) {
      final col = _Cast.col[i];
      final thin = M.clamp01(_vis[i] / _burst) * .35;
      final bcol = Color.lerp(col, Pal.white, thin * .6)!;
      final d = _danger(i);
      final jit = d > 0 ? Offset(sin(_t * 70 + i) * d * 2.5, cos(_t * 63) * d * 2) : Offset.zero;
      final centre = bc + jit + Offset(0, _banked[i] ? sin(_t * 3 + i) * 3 : 0);
      // string to nozzle
      D.line(c, centre + Offset(0, r * 1.05), nozzle, Pal.ink, 2);
      c.save();
      c.translate(centre.dx, centre.dy);
      final breathe = 1 + _pumpAnim[i] * .06;
      c.scale(breathe, 1 / breathe);
      final shape = Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2.15);
      c.drawOval(shape, D.fill(bcol));
      c.drawOval(
          shape,
          Paint()
            ..shader = RadialGradient(
                    center: const Alignment(-.4, -.5), colors: [const Color(0x66FFFFFF), const Color(0x00FFFFFF), Color.lerp(col, Pal.ink, .35)!],
                    stops: const [0, .45, 1])
                .createShader(shape));
      c.drawOval(shape, D.stroke(Pal.ink, big ? 3.5 : 2.5));
      c.drawOval(Rect.fromCenter(center: Offset(-r * .4, -r * .5), width: r * .35, height: r * .5), D.fill(const Color(0x88FFFFFF)));
      // stress lines
      if (d > .2) {
        for (var k = 0; k < 3; k++) {
          final a = -1.2 + k * .5;
          D.line(c, Offset(cos(a) * r * .55, sin(a) * r * .6), Offset(cos(a) * r * .8, sin(a) * r * .85),
              Color.fromRGBO(255, 255, 255, .4 + d * .5), 2);
        }
      }
      // knot
      final knot = Path()
        ..moveTo(-5, r * 1.07 + 6)
        ..lineTo(5, r * 1.07 + 6)
        ..lineTo(0, r * 1.07 - 2)
        ..close();
      c.drawPath(knot, D.fill(Color.lerp(col, Pal.ink, .3)!));
      c.restore();
      if (_banked[i]) {
        final tag = Rect.fromCenter(center: centre, width: big ? 64 : 34, height: big ? 34 : 20);
        D.rrect(c, tag, 8, const Color(0xEEFFFFFF), border: Pal.ink, borderWidth: 2);
        D.text(c, '${(_s[i] * 100).round()}', tag.center, size: big ? 22 : 13, color: Pal.ink);
      }
    }
    // sweat for danger
    if (_danger(i) > .4 && !_popped[i] && !_banked[i]) {
      D.circle(c, cp + Offset(cr, -cr * 1.7 + (_t * 40) % 10), big ? 4 : 2.5, const Color(0xDD7FD3FF));
    }
  }
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
