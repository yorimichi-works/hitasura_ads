import '../engine/engine.dart';

/// No.046 Mash Dash — party sprint: mash to outrun the 3 CPU rivals.
class G046 extends MiniGame {
  static const _len = 50.0; // meters to the goal
  static const _ppm = 26.0; // pixels per meter
  static const _screenX0 = 70.0;

  final _x = List<double>.filled(4, 0);
  final _v = List<double>.filled(4, 0);
  final _run = List<double>.filled(4, 0);
  final _squash = List<double>.filled(4, 1);
  final _fin = List<bool>.filled(4, false);
  final _base = List<double>.filled(4, 0);
  final _order = <int>[];
  double _cam = -1.5;
  double _t = 0;
  int _taps = 0;
  double _tapGlow = 0;
  double _dustT = 0;
  double _sweatT = 0;
  bool _done = false;
  double _doneT = 0;
  bool _won = false;
  double _napAt = 0, _tripAt = 0;
  double _cheer = 0;

  @override
  void init() {
    _base[1] = 5.9 + rand(-.2, .2);
    _base[2] = 6.0 + rand(-.2, .2);
    _base[3] = 5.6 + rand(-.2, .2);
    _napAt = rand(2.2, 4.5);
    _tripAt = rand(3.0, 5.5);
  }

  double _laneY(int i) => 538 - i * 55.0;
  double _sx(double x) => _screenX0 + (x - _cam) * _ppm;

  void _tap() {
    if (_done || _fin[0] || host.finished) return;
    _v[0] = min(12.5, _v[0] + 1.55);
    _taps++;
    _tapGlow = 1;
    _squash[0] = .72;
    host.sfx(Sfx.step, volume: .55, rate: .85 + min(_v[0], 12) / 12 * .7);
    if (_taps % 10 == 0) {
      host.sfx(Sfx.combo, rate: 1 + min(_taps, 80) / 80);
      host.fx.pop('$_taps!', Offset(_sx(_x[0]) + 10, _laneY(0) - 70), color: Pal.yellow, size: 24 + min(_taps, 60) / 6);
      host.punch(.015);
    }
    if (_v[0] > 9) host.shake(1.5, .08);
  }

  @override
  void onDown(Offset p) => _tap();

  @override
  void onKey(String key, bool down) {
    if (down) _tap();
  }

  List<int> _ranking() {
    final rest = [0, 1, 2, 3].where((i) => !_order.contains(i)).toList()..sort((a, b) => _x[b].compareTo(_x[a]));
    return [..._order, ...rest];
  }

  void _finish() {
    _done = true;
    _doneT = 0;
    final place = _ranking().indexOf(0) + 1;
    if (place == 1 && _fin[0]) {
      var lead = 99.0;
      for (var i = 1; i < 4; i++) {
        lead = min(lead, _x[0] - _x[i]);
      }
      _won = true;
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.cheer, volume: .8);
      host.fx.confetti(count: 90);
      host.fx.confetti(at: Offset(_sx(_len), 330), count: 40);
      host.flash(Pal.white, .15);
      host.win(stars: lead > 6 ? 3 : (lead > 2.5 ? 2 : 1));
    } else {
      host.sfx(Sfx.aww);
      host.sfx(Sfx.jingleLose, volume: .6);
      host.lose();
    }
  }

  @override
  void onTimeUp() {
    if (!_done) _finish();
  }

  @override
  void update(double dt) {
    _t += dt;
    _tapGlow = M.approach(_tapGlow, 0, 6, dt);
    _cheer = M.approach(_cheer, 0, 1.5, dt);
    if (_done) _doneT += dt;
    final sp = sqrt(host.speed);
    for (var i = 0; i < 4; i++) {
      if (i == 0) {
        _v[0] = _fin[0] ? M.approach(_v[0], 1.2, 2, dt) : M.approach(_v[0], 0, 1.4, dt);
      } else {
        var target = _base[i] * sp + ((_x[0] - _x[i]) * .14).clamp(-.9, 1.1);
        if (i == 2 && _t > _napAt && _t < _napAt + .7) target = 1.2; // green gets smug and coasts
        if (i == 3 && _t > _tripAt && _t < _tripAt + .45) target = .3; // yellow trips
        if (_t < .35) target = 0; // CPUs react late to the gun
        if (_fin[i]) target = 1.5;
        _v[i] = M.approach(_v[i], target, 2.2, dt);
      }
      _x[i] += _v[i] * dt;
      _run[i] += _v[i] * dt * 2.4;
      _squash[i] = M.approach(_squash[i], 1, 14, dt);
      if (!_fin[i] && _x[i] >= _len) {
        _fin[i] = true;
        _order.add(i);
        final at = Offset(_sx(_x[i]), _laneY(i) - 30);
        host.fx.burst(at, _Cast.col[i], count: 18, speed: 260, shape: PartShape.star, size: 7);
        host.fx.pop('#${_order.length}', at + const Offset(0, -30), color: _Cast.col[i], size: 30);
        _cheer = 1;
        if (i == 0) {
          host.hitStop(.08);
          host.shake(6);
          if (!_done) _finish();
        } else {
          host.sfx(Sfx.whistle, volume: .6);
          if (!_fin[0]) host.sfx(Sfx.oops, volume: .5);
        }
      }
    }
    _cam = M.approach(_cam, _x[0] - 1.5, 9, dt);

    // dust + sweat
    _dustT -= dt;
    if (_dustT <= 0) {
      _dustT = .07;
      for (var i = 0; i < 4; i++) {
        if (_v[i] < 2) continue;
        final at = Offset(_sx(_x[i]) - 14, _laneY(i) - 2);
        if (at.dx < -20 || at.dx > 380) continue;
        host.fx.add(Particle(
          pos: at,
          vel: Offset(-_v[i] * _ppm * .35 - rand(10, 40), rand(-30, -8)),
          life: rand(.3, .55),
          color: const Color(0xAAF3D6B0),
          size: 6 + _v[i] * .8,
          shape: PartShape.smoke,
          drag: 1.4,
          grow: 22,
        ));
      }
    }
    _sweatT -= dt;
    if (_sweatT <= 0) {
      _sweatT = .18;
      for (var i = 0; i < 4; i++) {
        final struggling = i == 0 ? _v[0] > 8 : (_x[0] > _x[i] + 1.5);
        if (!struggling || _fin[i]) continue;
        final at = Offset(_sx(_x[i]) + 6, _laneY(i) - 44);
        host.fx.add(Particle(
          pos: at,
          vel: Offset(rand(-120, -50), rand(-120, -60)),
          life: .45,
          color: const Color(0xDD7FD3FF),
          size: 5,
          gravity: 500,
        ));
      }
    }
  }

  @override
  void render(Canvas c) {
    // sky
    D.gradientBg(c, const [Color(0xFF6CC8FF), Color(0xFFBDE9FF), Color(0xFFFFF1C9)],
        rect: const Rect.fromLTWH(0, 0, 360, 170));
    D.circle(c, const Offset(300, 70), 26, const Color(0xFFFFF3A0));
    D.circle(c, const Offset(300, 70), 36, const Color(0x33FFF3A0));
    for (var i = 0; i < 4; i++) {
      final x = (i * 130 - _cam * 3 - _t * 8) % 520 - 80;
      D.cloud(c, Offset(x, 70 + (i % 2) * 36), 44 + (i % 3) * 8, color: const Color(0xEEFFFFFF));
    }
    _renderStands(c);
    _renderTrack(c);
    for (var i = 3; i >= 0; i--) {
      _renderRunner(c, i);
    }
    // foreground grass
    c.drawRect(const Rect.fromLTWH(0, 552, 360, 88), D.fill(const Color(0xFF53C24A)));
    for (var i = 0; i < 12; i++) {
      final x = (i * 40 - _cam * _ppm * 1.25) % 480 - 60;
      c.drawRect(Rect.fromLTWH(x, 552, 20, 88), D.fill(const Color(0xFF4AB443)));
    }
    for (var i = 0; i < 5; i++) {
      final x = (i * 110 - _cam * _ppm * 1.4) % 560 - 100;
      D.circle(c, Offset(x, 640), 34, const Color(0xFF2E9E3E));
      D.circle(c, Offset(x + 30, 646), 28, const Color(0xFF34AE46));
      D.circle(c, Offset(x + 10, 626), 5, Pal.pink);
      D.circle(c, Offset(x + 34, 630), 5, Pal.yellow);
    }
    _renderHud(c);
    if (_done) _renderPodium(c);
  }

  void _renderStands(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 150, 360, 180), D.fill(const Color(0xFF5B5F86)));
    // banner flags
    c.drawRect(const Rect.fromLTWH(0, 146, 360, 10), D.fill(const Color(0xFF2B2F52)));
    for (var i = 0; i < 20; i++) {
      final x = (i * 24 - _cam * _ppm * .3) % 480 - 30;
      final p = Path()
        ..moveTo(x, 156)
        ..lineTo(x + 20, 156)
        ..lineTo(x + 10, 172)
        ..close();
      c.drawPath(p, D.fill(Pal.candy[i % Pal.candy.length]));
    }
    // crowd
    final excite = .3 + _cheer * .7 + (_done ? .6 : 0);
    for (var row = 0; row < 6; row++) {
      final y = 190 + row * 24.0;
      c.drawRect(Rect.fromLTWH(0, y + 6, 360, 8), D.fill(const Color(0xFF474B70)));
      final off = (_cam * _ppm * .3 + row * 7) % 18;
      for (var k = 0; k < 22; k++) {
        final x = k * 18.0 - off;
        final seed = (k + (_cam * _ppm * .3 / 18).floor()) * 7 + row * 13;
        final col = Pal.candy[seed.abs() % Pal.candy.length];
        final bob = -(sin(_t * 12 + seed) .abs()) * 5 * excite;
        c.drawCircle(Offset(x, y + bob), 7, D.fill(Color.lerp(col, const Color(0xFF5B5F86), .25)!));
        if (excite > .5 && seed % 3 == 0) {
          D.line(c, Offset(x - 5, y + bob), Offset(x - 9, y - 10 + bob), Color.lerp(col, Pal.ink, .3)!, 3);
          D.line(c, Offset(x + 5, y + bob), Offset(x + 9, y - 10 + bob), Color.lerp(col, Pal.ink, .3)!, 3);
        }
      }
    }
    c.drawRect(const Rect.fromLTWH(0, 318, 360, 14), D.fill(const Color(0xFF2B2F52)));
    // ad boards on the wall
    for (var i = 0; i < 6; i++) {
      final x = (i * 120 - _cam * _ppm) % 720 - 120;
      D.rrect(c, Rect.fromLTWH(x, 318, 100, 14), 2, [Pal.yellow, Pal.pink, Pal.teal][i % 3]);
      D.text(c, 'AD', Offset(x + 50, 325), size: 10, color: Pal.ink);
    }
  }

  void _renderTrack(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 332, 360, 220), D.fill(const Color(0xFFD9653B)));
    for (var k = 0; k < 4; k++) {
      c.drawRect(Rect.fromLTWH(0, 332 + k * 55.0 + 30, 360, 25), D.fill(const Color(0x14000000)));
    }
    for (var k = 0; k <= 4; k++) {
      c.drawRect(Rect.fromLTWH(0, 330 + k * 55.0, 360, 3), D.fill(const Color(0xDDFFFFFF)));
    }
    // distance marks
    for (var m = 10; m < _len; m += 10) {
      final sx = _sx(m.toDouble());
      if (sx < -30 || sx > 390) continue;
      c.drawRect(Rect.fromLTWH(sx - 1.5, 332, 3, 218), D.fill(const Color(0x66FFFFFF)));
      D.text(c, '${m}m', Offset(sx, 342), size: 12, color: Pal.white, stroke: const Color(0xFF8A3A1E));
    }
    // start line
    final s0 = _sx(0);
    if (s0 > -20) c.drawRect(Rect.fromLTWH(s0 - 3, 332, 6, 218), D.fill(Pal.white));
    // goal
    final g = _sx(_len);
    if (g > -40 && g < 420) {
      for (var r = 0; r < 22; r++) {
        for (var k = 0; k < 2; k++) {
          c.drawRect(Rect.fromLTWH(g - 8 + k * 8, 332 + r * 10.0, 8, 10),
              D.fill((r + k).isEven ? Pal.white : Pal.ink));
        }
      }
      // arch
      D.rrect(c, Rect.fromLTWH(g - 8, 250, 10, 300), 3, Pal.gray, border: Pal.ink, borderWidth: 2);
      final wave = sin(_t * 6) * 3;
      D.rrect(c, Rect.fromCenter(center: Offset(g - 3, 262 + wave), width: 96, height: 34), 10, Pal.red,
          border: Pal.ink, borderWidth: 3);
      D.text(c, host.tr('goal', 'GOAL'), Offset(g - 3, 262 + wave), size: 20, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _renderRunner(Canvas c, int i) {
    final sx = _sx(_x[i]);
    final y = _laneY(i);
    final r = 19.0 + (3 - i) * 1.2 + (i == 0 ? 2 : 0);
    if (sx < -30) return;
    if (sx > 380) {
      // off-screen indicator
      D.circle(c, Offset(342, y - 22), 13, _Cast.col[i], border: Pal.ink, borderWidth: 2.5);
      D.arrow(c, Offset(342, y - 22), const Offset(1, 0), 20, Pal.white, width: 6);
      D.text(c, '+${(_x[i] - _x[0]).toStringAsFixed(0)}m', Offset(330, y + 2), size: 12, color: Pal.white, stroke: Pal.ink);
      return;
    }
    D.shadow(c, Offset(sx, y + 2), r * 2, 9, .3);
    final running = _v[i] > .6;
    final bob = running ? -sin(_run[i] * pi).abs() * min(_v[i], 10) * .9 : 0.0;
    final tripping = i == 3 && _t > _tripAt && _t < _tripAt + .45;
    final napping = i == 2 && _t > _napAt && _t < _napAt + .7;
    final behind = i != 0 && _x[0] > _x[i] + 1.5;
    Face face;
    if (_done) {
      final place = _ranking().indexOf(i);
      face = place == 0 ? Face.love : (place == 3 ? Face.cry : Face.sad);
    } else if (tripping) {
      face = Face.dead;
    } else if (napping) {
      face = Face.sleepy;
    } else if (i == 0) {
      face = _v[0] > 8 ? Face.angry : (_v[0] > 3 ? Face.happy : Face.neutral);
    } else {
      face = behind ? Face.shocked : _Cast.mood[i];
    }
    final tilt = tripping ? .9 : (running ? min(_v[i], 12) * .025 : 0.0);
    _Cast.draw(c, i, Offset(sx, y + bob), r, face: face, squash: _squash[i], tilt: tilt, run: running ? _run[i] : null);
    if (napping) D.text(c, 'z', Offset(sx + 18, y - r * 2.4 - (_t * 20) % 12), size: 16, color: Pal.white, stroke: Pal.ink);
    if (i == 0 && !_done) {
      // "YOU" marker
      final ty = y - r * 2.9 + sin(_t * 6) * 2;
      final p = Path()
        ..moveTo(sx - 6, ty + 9)
        ..lineTo(sx + 6, ty + 9)
        ..lineTo(sx, ty + 16)
        ..close();
      c.drawPath(p, D.fill(Pal.yellow));
      D.text(c, host.tr('you', 'YOU'), Offset(sx, ty), size: 13, color: Pal.yellow, stroke: Pal.ink);
    }
    // speed lines
    if (_v[i] > 7) {
      final k = (_v[i] - 7) / 5;
      for (var s = 0; s < 3; s++) {
        final yy = y - r * (.6 + s * .5);
        final len = 18 + 20 * k + (s == 1 ? 10 : 0);
        D.line(c, Offset(sx - r - 6 - len, yy), Offset(sx - r - 6, yy), Color.fromRGBO(255, 255, 255, .5 + k * .4), 2.5);
      }
    }
  }

  void _renderHud(Canvas c) {
    // progress track
    const l = 40.0, rr = 320.0, y = 58.0;
    D.rrect(c, const Rect.fromLTWH(l - 8, y - 9, rr - l + 16, 18), 9, const Color(0x88000000));
    D.rrect(c, Rect.fromLTWH(l - 4, y - 4, rr - l + 8, 8), 4, const Color(0x55FFFFFF));
    // checker flag
    for (var a = 0; a < 3; a++) {
      for (var b = 0; b < 2; b++) {
        c.drawRect(Rect.fromLTWH(rr + 6 + a * 5, y - 16 + b * 5, 5, 5), D.fill((a + b).isEven ? Pal.white : Pal.ink));
      }
    }
    D.line(c, Offset(rr + 6, y - 16), Offset(rr + 6, y + 6), Pal.ink, 2);
    for (final i in [3, 2, 1, 0]) {
      final px = l + (rr - l) * (_x[i] / _len).clamp(0.0, 1.0);
      D.circle(c, Offset(px, y), i == 0 ? 9 : 7, _Cast.col[i], border: Pal.ink, borderWidth: 2);
      if (i == 0) D.circle(c, Offset(px, y), 3, Pal.white);
    }
    // rank
    if (!_done) {
      final rank = _ranking().indexOf(0) + 1;
      final col = rank == 1 ? Pal.gold : (rank == 2 ? const Color(0xFFD7E3F0) : const Color(0xFFE08A4E));
      D.title(c, '#$rank', const Offset(46, 102), size: 34, color: col, scale: 1 + _tapGlow * .06);
    }
    // power gauge
    final pw = (_v[0] / 12).clamp(0.0, 1.0);
    final gcol = pw > .7 ? Color.lerp(Pal.orange, Pal.red, M.wave(_t, 8))! : (pw > .4 ? Pal.yellow : Pal.lime);
    D.rrect(c, const Rect.fromLTWH(46, 584, 268, 30), 15, const Color(0xAA1B1530), border: Pal.ink, borderWidth: 3);
    D.bar(c, const Rect.fromLTWH(52, 590, 256, 18), pw, gcol, back: const Color(0x44FFFFFF));
    D.text(c, host.tr('power', 'POWER'), const Offset(180, 575), size: 13, color: Pal.white, stroke: Pal.ink);
    if (pw > .7) {
      D.flame(c, Offset(52 + 256 * pw, 590), 20 + _tapGlow * 8, _t);
    }
    // tutorial
    if (_t < 2.2 && !_done) {
      final s = 1 + sin(_t * 14) * .08;
      D.rrect(c, const Rect.fromLTWH(70, 214, 220, 70), 20, const Color(0xCC1B1530), border: Pal.white, borderWidth: 3);
      D.title(c, host.tr('tap', 'TAP!'), const Offset(160, 246), size: 40, scale: s, color: Pal.yellow);
      D.hand(c, const Offset(250, 240), _t);
    }
  }

  void _renderPodium(Canvas c) {
    final k = M.easeOutBack(M.clamp01(_doneT / .45));
    final rank = _ranking();
    c.save();
    c.translate(0, (1 - k) * -300 - 40);
    D.rrect(c, const Rect.fromLTWH(20, 86, 320, 216), 22, const Color(0xE61B1530), border: Pal.white, borderWidth: 3);
    D.rays(c, const Offset(180, 200), 200, Color.fromRGBO(255, 210, 63, _won ? .18 : .06), t: _t * .6, count: 14);
    const podX = [180.0, 108.0, 252.0];
    const podH = [70.0, 48.0, 32.0];
    const podCol = [Pal.gold, Color(0xFFD7E3F0), Color(0xFFE08A4E)];
    const baseY = 286.0;
    for (var p = 0; p < 3; p++) {
      final rct = Rect.fromLTWH(podX[p] - 34, baseY - podH[p], 68, podH[p]);
      D.rrect(c, rct, 6, podCol[p], border: Pal.ink, borderWidth: 3);
      D.text(c, '${p + 1}', rct.center + const Offset(0, 4), size: 24, color: Pal.ink);
      final who = rank[p];
      final jump = p == 0 ? -sin(_doneT * 10).abs() * 10 : 0.0;
      _Cast.draw(c, who, Offset(podX[p], baseY - podH[p] + jump), 22,
          face: p == 0 ? Face.love : Face.sad);
      if (who == 0) {
        D.text(c, host.tr('you', 'YOU'), Offset(podX[p], baseY - podH[p] - 58), size: 14, color: Pal.yellow, stroke: Pal.ink);
      }
    }
    // 4th place sulks in the corner
    final last = rank[3];
    _Cast.draw(c, last, const Offset(314, 286), 14, face: Face.cry, tilt: -.3);
    D.text(c, '4', const Offset(314, 250), size: 14, color: Pal.gray, stroke: Pal.ink);
    if (last == 0) D.text(c, host.tr('you', 'YOU'), const Offset(314, 236), size: 12, color: Pal.yellow, stroke: Pal.ink);
    // crown
    D.star(c, Offset(180, baseY - podH[0] - 56 - sin(_doneT * 10).abs() * 10), 12, Pal.gold, border: Pal.ink);
    D.title(c, _won ? host.tr('win', 'WIN!') : host.tr('lose', 'LOSE'), const Offset(180, 116),
        size: 30, color: _won ? Pal.yellow : Pal.gray);
    c.restore();
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
