import '../engine/engine.dart';

/// No.051 Tug of War — rhythm-pull the Red gang into the mud pit.
class G051 extends MiniGame {
  static const _groundY = 430.0;
  static const _ropeY = 396.0;
  static const _barL = 40.0, _barR = 320.0, _barY = 560.0;
  static const _zoneW = 46.0, _goodW = 20.0;

  double _t = 0;
  double _p = 0; // -1 (you lose) .. +1 (you win)
  double _pending = 0;
  double _marker = _barL;
  double _mDir = 1;
  double _zone = 180;
  double _cool = 0;
  int _streak = 0;
  double _heaveT = 1.6;
  double _heaveWarn = 0;
  double _heaving = 0;
  double _yourHeave = 0;
  double _enemyHeave = 0;
  double _hitFlash = 0;
  Color _hitCol = Pal.green;
  bool _over = false;
  bool _won = false;
  double _overT = 0;
  int _taps = 0;
  double _dustT = 0;

  @override
  void init() {
    _zone = rand(110, 250);
    _heaveT = rand(1.4, 2.0);
  }

  double get _shift => _p * 80;

  @override
  void onDown(Offset p) => _pull();

  @override
  void onKey(String key, bool down) {
    if (down) _pull();
  }

  void _pull() {
    if (_over || _cool > 0) return;
    _cool = .24;
    _taps++;
    final d = (_marker - _zone).abs();
    if (d <= _zoneW / 2) {
      _streak++;
      final amt = .16 * (1 + .25 * min(_streak - 1, 4));
      _pending += amt;
      _yourHeave = 1;
      _hitFlash = 1;
      _hitCol = Pal.green;
      host.sfx(Sfx.perfect, volume: .6, rate: 1 + min(_streak, 6) * .06);
      host.sfx(Sfx.swing, volume: .6);
      host.shake(4 + min(_streak, 5).toDouble());
      host.punch(.02);
      final label = _streak >= 2 ? '${host.tr('combo', 'COMBO')} x$_streak' : host.tr('perfect', 'PERFECT!');
      host.fx.pop(label, Offset(_zone, _barY - 44), color: Pal.lime, size: 22 + min(_streak, 5) * 2.0);
      host.fx.burst(Offset(_zone, _barY), Pal.lime, count: 12, speed: 200, shape: PartShape.star, size: 6);
      _zone = (_zone + rand(60, 140) * (chance(.5) ? 1 : -1)).clamp(_barL + 40, _barR - 40);
      if ((_zone - _marker).abs() < 40) _zone = _marker > 180 ? _barL + 60 : _barR - 60;
    } else if (d <= _zoneW / 2 + _goodW) {
      _pending += .06;
      _yourHeave = .6;
      _hitFlash = 1;
      _hitCol = Pal.yellow;
      host.sfx(Sfx.pop, rate: 1.1);
      host.fx.pop(host.tr('good', 'GOOD'), Offset(_marker, _barY - 40), color: Pal.yellow, size: 20);
    } else {
      _streak = 0;
      _pending += .012;
      _yourHeave = .25;
      _hitFlash = 1;
      _hitCol = Pal.red;
      host.sfx(Sfx.tap, volume: .6, rate: .8);
    }
  }

  List<Offset> get _yourFeet => [
        Offset(116 - _shift, _groundY),
        Offset(72 - _shift, _groundY),
        Offset(30 - _shift, _groundY),
      ];
  List<Offset> get _enemyFeet => [
        Offset(244 - _shift, _groundY),
        Offset(288 - _shift, _groundY),
        Offset(330 - _shift, _groundY),
      ];

  @override
  void update(double dt) {
    _t += dt;
    _cool = max(0, _cool - dt);
    _hitFlash = M.approach(_hitFlash, 0, 6, dt);
    _yourHeave = M.approach(_yourHeave, 0, 5, dt);
    _enemyHeave = M.approach(_enemyHeave, 0, 5, dt);
    if (_over) {
      _overT += dt;
      return;
    }
    // marker ping-pong
    final sp = (_barR - _barL) / .95 * host.speed;
    _marker += _mDir * sp * dt;
    if (_marker > _barR) {
      _marker = _barR;
      _mDir = -1;
    } else if (_marker < _barL) {
      _marker = _barL;
      _mDir = 1;
    }
    // apply your pulls smoothly
    final dp = _pending * min(1.0, dt * 9);
    _pending -= dp;
    _p += dp;
    // CPU team: steady pull + telegraphed heaves
    _p -= .075 * host.speed * dt;
    _heaveT -= dt;
    if (_heaveT < .45 && _heaveWarn == 0 && _heaving <= 0) {
      _heaveWarn = 1;
      host.sfx(Sfx.notify, volume: .5, rate: .8);
    }
    if (_heaveT <= 0) {
      _heaveT = rand(1.5, 2.2) / host.speed;
      _heaveWarn = 0;
      _heaving = .3;
      _enemyHeave = 1;
      host.sfx(Sfx.swing, volume: .7, rate: .7);
      host.shake(3);
    }
    if (_heaving > 0) {
      _heaving -= dt;
      _p -= .3 * host.speed * dt;
    }
    // dust at feet
    _dustT -= dt;
    if (_dustT <= 0) {
      _dustT = .12;
      final f = dp > .002 ? _enemyFeet : (_heaving > 0 ? _yourFeet : null);
      if (f != null) {
        host.fx.add(Particle(
          pos: f[0] + Offset(rand(-6, 6), -2),
          vel: Offset(dp > .002 ? -60 : 60, rand(-50, -20)),
          life: .45,
          color: const Color(0xAAC9A27A),
          size: 10,
          shape: PartShape.smoke,
          drag: 1.4,
          grow: 20,
        ));
      }
    }
    if (_p >= 1) {
      _p = 1;
      _end(true);
    } else if (_p <= -1) {
      _p = -1;
      _end(false);
    }
  }

  void _end(bool won) {
    _over = true;
    _won = won;
    final at = Offset(180, _groundY + 6);
    host.sfx(Sfx.splash);
    host.sfx(Sfx.splat, volume: .8);
    host.shake(12, .4);
    host.hitStop(.08);
    host.fx.burst(at, const Color(0xFF6B4226), count: 40, speed: 420, size: 10, gravity: 700,
        colors: const [Color(0xFF6B4226), Color(0xFF8A5A36), Color(0xFF4A2C18)]);
    if (won) {
      host.sfx(Sfx.cheer);
      host.sfx(Sfx.fanfare, volume: .7);
      host.fx.confetti(count: 80);
      host.win(stars: host.time < 7 ? 3 : (host.time < 9.5 ? 2 : 1));
    } else {
      host.sfx(Sfx.aww);
      host.lose();
    }
  }

  @override
  void onTimeUp() {
    if (!_over) {
      if (_p > 0) {
        _over = true;
        _won = true;
        host.sfx(Sfx.whistle);
        host.win(stars: 1);
      } else {
        _end(false);
      }
    }
  }

  @override
  void render(Canvas c) {
    // sky + hills
    D.gradientBg(c, const [Color(0xFF58B7FF), Color(0xFFA8E0FF), Color(0xFFFFF4D6)], rect: const Rect.fromLTWH(0, 0, 360, 440));
    D.circle(c, const Offset(60, 110), 30, const Color(0xFFFFF09A));
    for (var i = 0; i < 3; i++) {
      D.cloud(c, Offset((i * 140 + _t * 10) % 520 - 80, 90 + i * 30.0), 50, color: const Color(0xEEFFFFFF));
    }
    c.drawOval(const Rect.fromLTWH(-80, 300, 300, 200), D.fill(const Color(0xFF7ED36B)));
    c.drawOval(const Rect.fromLTWH(160, 290, 320, 220), D.fill(const Color(0xFF6CC45C)));
    // crowd fence banner
    D.rrect(c, const Rect.fromLTWH(-10, 346, 380, 40), 4, const Color(0xFFFFFFFF), border: Pal.ink, borderWidth: 2);
    for (var i = 0; i < 12; i++) {
      final x = i * 32.0;
      final col = i < 6 ? _Cast.col[i % 2 == 0 ? 0 : 3] : _Cast.col[1];
      final bob = -sin(_t * 10 + i).abs() * (_over ? 8 : 3);
      c.drawCircle(Offset(x + 10, 346 + bob), 9, D.fill(Color.lerp(col, Pal.white, .2)!));
    }
    // ground
    D.gradientBg(c, const [Color(0xFF8BD56A), Color(0xFF5DAE45)], rect: const Rect.fromLTWH(0, _groundY - 12, 360, 90));
    c.drawRect(const Rect.fromLTWH(0, _groundY + 70, 360, 150), D.fill(const Color(0xFF4A8F3A)));
    // mud pit
    c.drawOval(Rect.fromCenter(center: const Offset(180, _groundY + 6), width: 104, height: 34), D.fill(const Color(0xFF3E2414)));
    c.drawOval(Rect.fromCenter(center: const Offset(180, _groundY + 8), width: 94, height: 26), D.fill(const Color(0xFF6B4226)));
    for (var i = 0; i < 4; i++) {
      final ph = (_t * .9 + i * .27) % 1;
      c.drawCircle(Offset(150 + i * 20.0, _groundY + 8 - ph * 4), 3 + ph * 4, D.stroke(const Color(0xFF8A5A36), 2));
    }
    // center line markers
    for (final x in [128.0, 232.0]) {
      D.line(c, Offset(x, _groundY - 10), Offset(x, _groundY + 18), Pal.white, 3);
    }

    // rope
    final yf = _yourFeet, ef = _enemyFeet;
    final lean = .28 + _yourHeave * .2;
    final eLean = .28 + _enemyHeave * .2;
    final wob = sin(_t * 30) * 1.2;
    final rope = Path()
      ..moveTo(yf.last.dx - 30, _ropeY + 8)
      ..quadraticBezierTo(180 - _shift, _ropeY + 6 + wob, ef.last.dx + 30, _ropeY + 8);
    c.drawPath(rope, D.stroke(const Color(0xFF6B4A2A), 8));
    c.drawPath(rope, D.stroke(const Color(0xFFD9A55B), 5));
    // flag at the rope center
    final fx = 180 - _shift;
    D.line(c, Offset(fx, _ropeY + 6), Offset(fx, _ropeY + 30), Pal.ink, 2);
    final flag = Path()
      ..moveTo(fx, _ropeY + 12)
      ..lineTo(fx + 20 + sin(_t * 8) * 3, _ropeY + 20)
      ..lineTo(fx, _ropeY + 28)
      ..close();
    c.drawPath(flag, D.fill(Pal.red));
    c.drawPath(flag, D.stroke(Pal.ink, 2));

    // teams
    const yourIds = [0, 3, 2];
    for (var k = 2; k >= 0; k--) {
      _drawPuller(c, yourIds[k], yf[k], k == 0 ? 27.0 : 23.0, -lean, you: true, idx: k);
    }
    for (var k = 2; k >= 0; k--) {
      _drawPuller(c, 1, ef[k], k == 0 ? 27.0 : 22.0, eLean, you: false, idx: k);
    }
    if (_heaveWarn > 0 && !_over) {
      final p = ef[0] + const Offset(10, -80);
      D.bubble(c, Rect.fromCenter(center: p, width: 36, height: 32), tail: p + const Offset(-6, 26));
      D.text(c, '!', p, size: 22, color: Pal.red);
    }

    // tug meter
    D.rrect(c, const Rect.fromLTWH(40, 58, 280, 22), 11, const Color(0xAA1B1530), border: Pal.ink, borderWidth: 2.5);
    D.rrect(c, Rect.fromLTRB(44, 62, 180, 76), 7, const Color(0x333D8BFF));
    D.rrect(c, Rect.fromLTRB(180, 62, 316, 76), 7, const Color(0x33FF4B5C));
    final mx = 180 + _p * 134;
    D.circle(c, Offset(mx, 69), 12, _p >= 0 ? _Cast.col[0] : _Cast.col[1], border: Pal.ink, borderWidth: 2.5);
    D.circle(c, const Offset(30, 69), 13, _Cast.col[0], border: Pal.ink, borderWidth: 2.5);
    D.face(c, const Offset(30, 70), 11, _p > .3 ? Face.happy : (_p < -.3 ? Face.cry : Face.angry));
    D.circle(c, const Offset(330, 69), 13, _Cast.col[1], border: Pal.ink, borderWidth: 2.5);
    D.face(c, const Offset(330, 70), 11, _p < -.3 ? Face.smug : (_p > .3 ? Face.cry : Face.angry));

    _renderBar(c);

    if (_over && _won) {
      D.title(c, host.tr('win', 'WIN!'), Offset(180, 200 - M.easeOutBack(M.clamp01(_overT / .4)) * 20), size: 50,
          color: Pal.yellow);
    }
  }

  void _drawPuller(Canvas c, int id, Offset feet, double r, double lean, {required bool you, required int idx}) {
    var pos = feet;
    var tilt = lean;
    Face face;
    var mud = false;
    final loser = _over && (_won ? !you : you);
    if (loser) {
      // tumble forward into the mud
      final k = M.clamp01(_overT / .5);
      final dir = you ? 1.0 : -1.0;
      pos = Offset(M.lerp(feet.dx, 180 + (idx - 1) * 22.0, k), feet.dy + sin(k * pi) * -50 + k * 10);
      tilt = dir * k * 2.2;
      face = Face.dead;
      mud = k > .9;
    } else if (_over) {
      pos = feet + Offset(0, -sin(_overT * 11 + idx).abs() * 18);
      tilt = 0;
      face = Face.love;
    } else {
      final strain = you ? (_yourHeave > .5 ? Face.angry : (_p < -.4 ? Face.cry : Face.shocked)) : (_enemyHeave > .5 ? Face.angry : (_p > .4 ? Face.cry : Face.angry));
      face = idx == 0 && you ? strain : (you ? (_p < -.4 ? Face.cry : Face.angry) : strain);
      if (!you && idx > 0) face = Face.angry;
    }
    D.shadow(c, Offset(feet.dx, _groundY + 3), r * 2, 8, loser ? .1 : .3);
    // arms reaching to the rope
    if (!loser) {
      final hand = Offset(pos.dx + (you ? r * .9 : -r * .9), _ropeY + 8);
      final shoulder = pos + Offset(sin(tilt) * -r, -r * 1.1);
      D.line(c, shoulder, hand, Pal.ink, 7);
      D.line(c, shoulder, hand, you ? _Cast.col[id] : Color.lerp(_Cast.col[1], Pal.ink, idx == 0 ? 0 : .15)!, 4);
      c.drawCircle(hand, 5, D.fill(Pal.ink));
    }
    _Cast.draw(c, id, pos, r, face: face, tilt: tilt, squash: 1 - (you ? _yourHeave : _enemyHeave) * .08);
    if (mud) {
      final head = pos + Offset(0, -r);
      c.drawOval(Rect.fromCenter(center: head, width: r * 2.1, height: r * 1.2), D.fill(const Color(0xCC6B4226)));
      c.drawCircle(head + Offset(-r * .5, r * .5), r * .25, D.fill(const Color(0xCC6B4226)));
    }
    if (idx == 0 && you && !_over) {
      D.text(c, host.tr('you', 'YOU'), feet + Offset(0, -r * 2.9), size: 13, color: Pal.yellow, stroke: Pal.ink);
    }
    if (!you && idx == 0 && !_over) {
      D.circle(c, pos + Offset(r * .7, -r * 1.7 + (_t * 40) % 12), 3.5, const Color(0xDD7FD3FF));
    }
  }

  void _renderBar(Canvas c) {
    // panel
    D.rrect(c, const Rect.fromLTWH(16, 500, 328, 120), 22, const Color(0xE61B1530), border: Pal.white, borderWidth: 3);
    final bar = Rect.fromLTRB(_barL - 6, _barY - 16, _barR + 6, _barY + 16);
    D.rrect(c, bar, 14, const Color(0xFFB8243A), border: Pal.ink, borderWidth: 3);
    D.rrect(c, Rect.fromCenter(center: Offset(_zone, _barY), width: _zoneW + _goodW * 2, height: 26), 10, Pal.yellow);
    final pulse = .5 + .5 * sin(_t * 10);
    D.rrect(c, Rect.fromCenter(center: Offset(_zone, _barY), width: _zoneW + 8 * pulse, height: 30 + 4 * pulse), 10,
        Color.fromRGBO(155, 226, 45, .35));
    D.rrect(c, Rect.fromCenter(center: Offset(_zone, _barY), width: _zoneW, height: 26), 10, Pal.lime, border: Pal.ink, borderWidth: 2);
    if (_hitFlash > .05) {
      D.rrect(c, bar.inflate(4 * _hitFlash), 16, const Color(0x00000000), border: _hitCol.withValues(alpha: _hitFlash), borderWidth: 4);
    }
    // marker
    final m = Offset(_marker, _barY);
    final tri = Path()
      ..moveTo(m.dx - 10, m.dy - 30)
      ..lineTo(m.dx + 10, m.dy - 30)
      ..lineTo(m.dx, m.dy - 16)
      ..close();
    D.line(c, m + const Offset(0, -18), m + const Offset(0, 18), Pal.ink, 7);
    D.line(c, m + const Offset(0, -18), m + const Offset(0, 18), Pal.white, 3.5);
    c.drawPath(tri, D.fill(Pal.white));
    c.drawPath(tri, D.stroke(Pal.ink, 2.5));
    // label
    final label = _streak >= 2 ? '${host.tr('combo', 'COMBO')} x$_streak' : host.tr('pull', 'PULL!');
    D.text(c, label, const Offset(180, 596), size: 20, color: _streak >= 2 ? Pal.lime : Pal.white, stroke: Pal.ink);
    if (_taps < 2 && _t < 3) {
      D.hand(c, Offset(_zone, _barY + 8), _t, size: 38);
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
