import '../engine/engine.dart';

enum _S { wait, signal, result }

/// No.048 Samurai Quickdraw — sunset reaction duel, best of 3 vs Red.
class G048 extends MiniGame {
  static const _blue = Color(0xFF3D8BFF);
  static const _red = Color(0xFFFF4B5C);
  static const _groundY = 452.0;

  _S _st = _S.wait;
  double _stT = 0;
  double _t = 0;
  int _round = 0;
  int _pw = 0, _cw = 0;
  double _signalAt = 1;
  double _fakeAt = -1;
  int _fakeKind = 0;
  bool _fakeFired = false;
  double _fakeT = 0;
  double _cpuReact = .4;
  int _roundWinner = -1; // 0 = you, 1 = cpu
  bool _foul = false;
  double _react = 0;
  double _bestReact = 9;
  double _twitch = 0;
  double _bannerT = 0;
  final _leaves = <_Leaf>[];
  bool _over = false;

  static const _cpuTimes = [.42, .36, .31];

  @override
  void init() => _startRound();

  void _startRound() {
    _st = _S.wait;
    _stT = 0;
    _foul = false;
    _roundWinner = -1;
    _signalAt = rand(.9, 1.6) + (_round == 0 ? .35 : 0);
    _fakeFired = false;
    _fakeT = 0;
    _fakeAt = chance(.85) ? _signalAt * rand(.35, .7) : -1;
    _fakeKind = randInt(3);
    _cpuReact = _cpuTimes[min(_round, 2)] / sqrt(host.speed);
    _bannerT = 0;
    _leaves.clear();
  }

  @override
  void onDown(Offset p) {
    if (_over) return;
    if (_st == _S.wait) {
      if (_stT < .45) return; // grace: don't punish the tap that "starts" the round
      _foul = true;
      _decide(1);
    } else if (_st == _S.signal) {
      _react = _stT;
      _decide(0);
    }
  }

  @override
  void onKey(String key, bool down) {
    if (down) onDown(Offset.zero);
  }

  void _decide(int winner) {
    _roundWinner = winner;
    _st = _S.result;
    _stT = 0;
    if (_foul) {
      host.sfx(Sfx.buzzer);
      host.sfx(Sfx.oops, volume: .7);
      host.shake(5);
      host.flash(Pal.red, .15);
    } else {
      host.sfx(Sfx.slash);
      host.sfx(Sfx.hitHeavy, volume: .8);
      host.flash(Pal.white, .22);
      host.hitStop(.12);
      host.shake(10);
      host.punch(.05);
    }
    if (winner == 0) {
      _pw++;
      _bestReact = min(_bestReact, _react);
      host.fx.pop('${_react.toStringAsFixed(3)}s', const Offset(180, 200), color: Pal.yellow, size: 30);
      host.fx.burst(const Offset(270, 400), Pal.pink, count: 30, speed: 320, shape: PartShape.heart, size: 5,
          colors: const [Color(0xFFFFB7D5), Color(0xFFFF7FB0), Pal.white]);
      host.sfx(Sfx.cheer, volume: .5);
    } else {
      _cw++;
      host.fx.burst(const Offset(90, 400), Pal.pink, count: 22, speed: 260, shape: PartShape.heart, size: 5,
          colors: const [Color(0xFFFFB7D5), Color(0xFFFF7FB0)]);
      if (!_foul) host.sfx(Sfx.aww, volume: .5);
    }
    if (_pw >= 2) {
      _over = true;
      host.fx.confetti(count: 80);
      host.sfx(Sfx.fanfare, volume: .8);
      host.win(stars: _cw == 0 ? (_bestReact < .3 ? 3 : 2) : 1);
    } else if (_cw >= 2) {
      _over = true;
      host.sfx(Sfx.jingleLose, volume: .7);
      host.lose();
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _stT += dt;
    _bannerT += dt;
    _twitch = M.approach(_twitch, 0, 8, dt);
    switch (_st) {
      case _S.wait:
        if (!_fakeFired && _fakeAt > 0 && _stT >= _fakeAt) {
          _fakeFired = true;
          _fakeT = 0;
          switch (_fakeKind) {
            case 0:
              host.sfx(Sfx.wind, volume: .6);
            case 1:
              host.sfx(Sfx.swipe, volume: .5);
              for (var i = 0; i < 7; i++) {
                _leaves.add(_Leaf(Offset(rand(80, 300), rand(60, 160)), rand(0, 6), rand(.8, 1.3)));
              }
            default:
              host.sfx(Sfx.tick, volume: .9);
              _twitch = 1;
          }
        }
        if (_stT >= _signalAt) {
          _st = _S.signal;
          _stT = 0;
          host.sfx(Sfx.bell);
          host.sfx(Sfx.zap, volume: .6);
          host.flash(const Color(0x66FFFFFF), .08);
        }
      case _S.signal:
        if (_stT >= _cpuReact) {
          _react = _cpuReact;
          _decide(1);
        }
      case _S.result:
        if (!_over && _stT > .95) {
          _round++;
          _startRound();
          host.sfx(Sfx.whoosh, volume: .5);
        }
    }
    if (_fakeFired) _fakeT += dt;
    for (final l in _leaves) {
      l.pos += Offset(sin(_t * 3 + l.phase) * 40 * dt, 70 * l.speed * dt);
    }
  }

  @override
  void render(Canvas c) {
    // sunset sky
    D.gradientBg(c, const [Color(0xFF2A0F45), Color(0xFF8E2C5C), Color(0xFFF2644A), Color(0xFFFFC56B)],
        rect: const Rect.fromLTWH(0, 0, 360, 460));
    // retro striped sun
    const sun = Offset(180, 330);
    c.save();
    c.clipRect(const Rect.fromLTWH(0, 0, 360, 452));
    c.drawCircle(sun, 150, D.fill(const Color(0x33FFE08A)));
    c.drawCircle(sun, 128, D.fill(const Color(0xFFFFE08A)));
    for (var i = 0; i < 7; i++) {
      final y = 300 + i * 20.0 + (_t * 6) % 20;
      c.drawRect(Rect.fromLTWH(0, y, 360, 3 + i * 1.2), D.fill(const Color(0xFFF2644A)));
    }
    c.restore();
    // distant clouds bands
    for (var i = 0; i < 3; i++) {
      final x = (i * 150 + _t * 6) % 540 - 90;
      D.rrect(c, Rect.fromLTWH(x, 140 + i * 42.0, 120, 10), 5, const Color(0x55FFD6A0));
      D.rrect(c, Rect.fromLTWH(x + 30, 150 + i * 42.0, 90, 8), 4, const Color(0x44FFD6A0));
    }
    // mountains
    final m1 = Path()..moveTo(0, 400);
    for (var i = 0; i <= 12; i++) {
      m1.lineTo(i * 30.0, 380 - (i.isEven ? 50 : 18) - (i == 6 ? 40 : 0));
    }
    m1
      ..lineTo(360, 460)
      ..lineTo(0, 460)
      ..close();
    c.drawPath(m1, D.fill(const Color(0xFFB04A78)));
    final m2 = Path()..moveTo(0, 430);
    for (var i = 0; i <= 8; i++) {
      m2.lineTo(i * 45.0, 420 - (i.isOdd ? 30 : 8));
    }
    m2
      ..lineTo(360, 460)
      ..lineTo(0, 460)
      ..close();
    c.drawPath(m2, D.fill(const Color(0xFF7E2F62)));
    // spectators on hills: green & yellow with flags
    _spectator(c, const Offset(30, 402), const Color(0xFF37D67A), 0);
    _spectator(c, const Offset(330, 400), const Color(0xFFFFCF33), 1.3);
    // ground
    c.drawRect(const Rect.fromLTWH(0, _groundY, 360, 188), D.fill(const Color(0xFF1B0F24)));
    // dead tree
    _tree(c);
    // fake-out: bird
    if (_fakeFired && _fakeKind == 0 && _fakeT < 2) {
      final bx = -30 + _fakeT * 260;
      for (var b = 0; b < 3; b++) {
        final p = Offset(bx - b * 26, 120 + b * 14 + sin(_fakeT * 6 + b) * 6);
        final flap = sin(_t * 22 + b) * 8;
        D.line(c, p, p + Offset(-12, -6 - flap), Pal.ink, 3.5);
        D.line(c, p, p + Offset(12, -6 - flap), Pal.ink, 3.5);
      }
    }
    for (final l in _leaves) {
      c.save();
      c.translate(l.pos.dx, l.pos.dy);
      c.rotate(_t * 4 + l.phase);
      c.drawOval(const Rect.fromLTWH(-7, -3.5, 14, 7), D.fill(const Color(0xFFFF9B5E)));
      c.restore();
    }

    // duelists
    final res = _st == _S.result;
    final k = res ? M.clamp01(_stT / .12) : 0.0;
    var px = 90.0, cx = 270.0;
    var pFall = 0.0, cFall = 0.0;
    if (res && !_foul) {
      if (_roundWinner == 0) {
        px = M.lerp(90, 250, k);
        cFall = M.clamp01((_stT - .3) / .35);
      } else {
        cx = M.lerp(270, 110, k);
        pFall = M.clamp01((_stT - .3) / .35);
      }
    }
    if (res && _foul) pFall = M.clamp01((_stT - .15) / .3) * .5;
    // ghost trail
    if (res && !_foul && _stT < .4) {
      final a = (1 - _stT / .4) * .5;
      for (var g = 1; g <= 4; g++) {
        final gx = _roundWinner == 0 ? M.lerp(90, px, g / 5) : M.lerp(270, cx, g / 5);
        c.drawOval(Rect.fromCenter(center: Offset(gx, _groundY - 40), width: 60, height: 76),
            D.fill(Color.fromRGBO(255, 255, 255, a * .4)));
      }
    }
    _samurai(c, Offset(px, _groundY), 1, _blue, drawn: res && _roundWinner == 0 && !_foul, fall: pFall,
        dead: pFall > .5, twitch: 0);
    _samurai(c, Offset(cx, _groundY), -1, _red, drawn: res && _roundWinner == 1 && !_foul, fall: cFall,
        dead: cFall > .5, twitch: _twitch);

    // slash streak
    if (res && !_foul && _stT < .45) {
      final a = 1 - _stT / .45;
      final p = Path()
        ..moveTo(0, 470)
        ..lineTo(360, 330)
        ..lineTo(360, 338)
        ..lineTo(0, 482)
        ..close();
      c.drawPath(p, D.fill(Color.fromRGBO(255, 255, 255, a)));
      c.drawPath(p, D.stroke(Color.fromRGBO(255, 80, 120, a * .6), 3));
    }

    // grass foreground
    for (var i = 0; i < 40; i++) {
      final x = i * 9.0 + (i % 3) * 2;
      final h = 16 + (i * 7 % 11).toDouble();
      final sway = sin(_t * 2.5 + i * .5) * 5 + (_fakeFired && _fakeKind == 0 ? sin(_t * 9) * 6 : 0);
      D.line(c, Offset(x, _groundY + 6), Offset(x + sway, _groundY - h), const Color(0xFF1B0F24), 3);
    }
    // ground details
    D.gradientBg(c, const [Color(0xFF2A1636), Color(0xFF0E0715)], rect: const Rect.fromLTWH(0, 470, 360, 170));

    // signal "!"
    if (_st == _S.signal || (res && !_foul && _stT < .2)) {
      final a = _st == _S.signal ? M.easeOutBack(M.clamp01(_stT / .08)) : 1.0;
      c.save();
      c.translate(180, 230);
      c.scale(a);
      final star = D.starPath(Offset.zero, 70, 44, points: 12, rotation: _t);
      c.drawPath(star, D.fill(Pal.red));
      c.drawPath(star, D.stroke(Pal.ink, 5));
      D.title(c, '!', const Offset(0, -4), size: 96, color: Pal.white);
      c.restore();
    }
    // fake-out "?"
    if (_fakeFired && _fakeKind == 2 && _fakeT < .7 && _st == _S.wait) {
      D.bubble(c, const Rect.fromLTWH(238, 318, 50, 44), tail: const Offset(262, 380));
      D.text(c, '?', const Offset(263, 340), size: 30, color: Pal.ink);
    }
    // tension text
    if (_st == _S.wait && !_over) {
      final a = .5 + .5 * sin(_t * 4);
      D.text(c, host.tr('wait', 'WAIT...'), const Offset(180, 540), size: 26, color: Color.fromRGBO(255, 255, 255, .5 + a * .4),
          stroke: Pal.ink);
      if (_round == 0) {
        // mini legend: "!" -> tap
        final s = D.starPath(const Offset(140, 592), 18, 11, points: 10);
        c.drawPath(s, D.fill(Pal.red));
        c.drawPath(s, D.stroke(Pal.ink, 2.5));
        D.text(c, '!', const Offset(140, 592), size: 20, color: Pal.white, stroke: Pal.ink);
        D.arrow(c, const Offset(182, 592), const Offset(1, 0), 34, Pal.white, width: 7);
        D.hand(c, const Offset(222, 584), _t, size: 34);
      }
    }
    if (_st == _S.signal) {
      D.title(c, host.tr('tap', 'TAP!'), const Offset(180, 552), size: 44, color: Pal.yellow, scale: 1 + sin(_t * 30) * .05);
    }
    if (res) {
      final txt = _foul
          ? host.tr('foul', 'FOUL!')
          : (_roundWinner == 0 ? host.tr('win', 'WIN!') : host.tr('lose', 'LOSE'));
      D.title(c, txt, const Offset(180, 552), size: 44,
          color: _roundWinner == 0 ? Pal.yellow : Pal.red, scale: M.easeOutBack(M.clamp01(_stT / .25)));
      if (_roundWinner == 1 && !_foul) {
        D.text(c, '${_cpuReact.toStringAsFixed(3)}s', const Offset(180, 596), size: 18, color: Pal.white, stroke: Pal.ink);
      }
    }

    // round banner
    if (_bannerT < .8 && _st == _S.wait) {
      final a = _bannerT < .6 ? 1.0 : 1 - (_bannerT - .6) / .2;
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
      D.title(c, '${host.tr('round', 'ROUND')} ${_round + 1}', const Offset(180, 250), size: 36, color: Pal.white,
          scale: .8 + .2 * M.easeOutBack(M.clamp01(_bannerT / .3)));
      c.restore();
    }

    // score pips
    D.rrect(c, const Rect.fromLTWH(24, 50, 312, 44), 22, const Color(0xAA0E0715), border: const Color(0x66FFFFFF), borderWidth: 2);
    D.circle(c, const Offset(48, 72), 14, _blue, border: Pal.ink, borderWidth: 2.5);
    D.face(c, const Offset(48, 73), 12, _pw > _cw ? Face.happy : (_cw > _pw ? Face.shocked : Face.neutral));
    D.circle(c, const Offset(312, 72), 14, _red, border: Pal.ink, borderWidth: 2.5);
    D.face(c, const Offset(312, 73), 12, _cw > _pw ? Face.smug : Face.angry);
    for (var i = 0; i < 2; i++) {
      D.circle(c, Offset(82 + i * 26.0, 72), 9, i < _pw ? Pal.yellow : const Color(0x33FFFFFF), border: Pal.ink, borderWidth: 2);
      D.circle(c, Offset(278 - i * 26.0, 72), 9, i < _cw ? Pal.red : const Color(0x33FFFFFF), border: Pal.ink, borderWidth: 2);
    }
    D.text(c, 'VS', const Offset(180, 72), size: 22, color: Pal.white, stroke: Pal.ink);
  }

  void _spectator(Canvas c, Offset o, Color col, double ph) {
    final hop = -sin(_t * 8 + ph).abs() * (_st == _S.result ? 8 : 2);
    c.drawCircle(o + Offset(0, -10 + hop), 10, D.fill(const Color(0xFF1B0F24)));
    D.line(c, o + Offset(6, -12 + hop), o + Offset(12, -40 + hop), const Color(0xFF1B0F24), 2.5);
    final f = Path()
      ..moveTo(12, -40 + hop)
      ..lineTo(32 + sin(_t * 7 + ph) * 3, -35 + hop)
      ..lineTo(12, -28 + hop)
      ..close();
    c.drawPath(f.shift(o), D.fill(col));
  }

  void _tree(Canvas c) {
    final p = D.stroke(const Color(0xFF1B0F24), 9);
    c.drawLine(const Offset(338, _groundY), const Offset(326, 300), p);
    c.drawLine(const Offset(328, 330), const Offset(290, 290), D.stroke(const Color(0xFF1B0F24), 6));
    c.drawLine(const Offset(326, 300), const Offset(350, 262), D.stroke(const Color(0xFF1B0F24), 5));
    c.drawLine(const Offset(300, 300), const Offset(282, 302), D.stroke(const Color(0xFF1B0F24), 3));
  }

  /// Silhouette blob-samurai. [dir] 1 = facing right.
  void _samurai(Canvas c, Offset feet, double dir, Color accent,
      {bool drawn = false, double fall = 0, bool dead = false, double twitch = 0}) {
    const r = 36.0;
    const ink = Color(0xFF120A1A);
    c.save();
    c.translate(feet.dx + twitch * 4 * dir, feet.dy);
    if (fall > 0) {
      c.translate(-dir * 20 * fall, 0);
      c.rotate(-dir * fall * 1.45);
    }
    c.scale(dir, 1);
    final breathe = 1 + sin(_t * 3) * .015;
    c.scale(1 / breathe, breathe);
    // scarf tails
    final tail = Path()..moveTo(-r * .5, -r * 1.55);
    for (var i = 1; i <= 6; i++) {
      tail.lineTo(-r * .5 - i * 11, -r * 1.55 + sin(_t * 9 - i * .9) * 5 + i * 1.5);
    }
    c.drawPath(tail, D.stroke(accent, 7));
    // feet
    c.drawOval(const Rect.fromLTWH(-r * .8, -8, r * .7, 10), D.fill(ink));
    c.drawOval(const Rect.fromLTWH(r * .1, -8, r * .7, 10), D.fill(ink));
    // body
    final body = RRect.fromRectAndCorners(Rect.fromCenter(center: const Offset(0, -r * .95), width: r * 2, height: r * 1.9),
        topLeft: const Radius.circular(r), topRight: const Radius.circular(r),
        bottomLeft: const Radius.circular(r * .8), bottomRight: const Radius.circular(r * .8));
    c.drawRRect(body.shift(const Offset(3, 0)), D.fill(Color.lerp(accent, ink, .3)!)); // rim light
    c.drawRRect(body, D.fill(ink));
    c.drawRRect(body, D.stroke(Color.lerp(accent, Pal.white, .2)!.withValues(alpha: .8), 2.5));
    // topknot
    c.drawCircle(const Offset(-r * .35, -r * 1.95), r * .22, D.fill(ink));
    // headband
    c.drawRect(const Rect.fromLTWH(-r, -r * 1.65, r * 2, r * .22), D.fill(accent));
    // eyes
    if (dead) {
      for (final ex in [r * .15, r * .6]) {
        final e = Offset(ex, -r * 1.2);
        D.line(c, e + const Offset(-5, -5), e + const Offset(5, 5), Pal.white, 3);
        D.line(c, e + const Offset(5, -5), e + const Offset(-5, 5), Pal.white, 3);
      }
    } else {
      final narrow = _st == _S.signal ? 2.0 : 0.0;
      for (final ex in [r * .15, r * .6]) {
        c.drawOval(Rect.fromCenter(center: Offset(ex, -r * 1.22), width: 13, height: 5 + narrow), D.fill(Pal.white));
      }
      D.line(c, const Offset(r * .02, -r * 1.42), const Offset(r * .75, -r * 1.34), Pal.white, 2.5);
    }
    // katana
    if (drawn) {
      // blade held out behind after the slash
      D.line(c, const Offset(r * .2, -r * .8), const Offset(-r * 1.9, -r * .55), const Color(0xFFE8F0FF), 4);
      D.line(c, const Offset(r * .2, -r * .8), const Offset(r * .55, -r * .85), accent, 6);
    } else {
      D.line(c, const Offset(-r * 1.2, -r * .25), const Offset(r * .45, -r * .95), const Color(0xFF3B2A40), 7);
      D.line(c, const Offset(r * .45, -r * .95), const Offset(r * .95, -r * 1.18), accent, 6);
      c.drawCircle(const Offset(r * .8, -r * .85), 7, D.fill(ink)); // hand on hilt
    }
    c.restore();
  }
}

class _Leaf {
  _Leaf(this.pos, this.phase, this.speed);
  Offset pos;
  final double phase;
  final double speed;
}
