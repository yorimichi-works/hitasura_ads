import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.088 Pixel Fishing — 16-bit lake cross-section.
///
/// Tap the water to cast. Fish shadows sniff the hook; when the bobber
/// plunges and "!" appears, tap to hook. Then HOLD to reel / RELEASE to ease:
/// keep the tension needle in the green (too high = line snaps, too slack =
/// fish slips off). Catch a regular fish, then the golden LEGEND => win.
class G088 extends MiniGame {
  static const _waterY = 212.0;
  static const _px = 3.0;

  _St _s = _St.aim;
  double _t = 0, _st = 0;
  double _castX = 250;
  Offset _bob = const Offset(140, 150);
  double _bobDip = 0; // 0 floating .. 1 fully under
  int _caught = 0;
  final List<_Fish> _fish = [];
  _Fish? _target;
  double _delay = 0;
  int _nibbles = 0;
  double _nibbleT = 0;
  // fight
  double _tension = .35, _prog = 0, _pull = .3, _pullT = 0, _slack = 0, _tick = 0, _beep = 0;
  bool _keyHold = false;
  double _thrash = 0;
  // show
  bool _showBig = false;
  double _happy = 0, _sad = 0;
  final _pops = _Pops();
  ui.Picture? _bg;
  final List<Offset> _bubbles = [];

  bool get _bigTurn => _caught >= 1;
  Offset get _rodTip {
    final bend = _s == _St.fight ? _tension * 26 : 0.0;
    final cast = _s == _St.cast ? (1 - (_st / .45).clamp(0.0, 1.0)) * -30 : 0.0;
    return Offset(142 + cast * .4, 118 + bend + cast);
  }

  double get _hookY => _waterY + (_bigTurn ? 150 : 95);

  @override
  void init() {
    for (var i = 0; i < 5; i++) {
      _fish.add(_Fish(rand(150, 340), rand(_waterY + 60, 540), rand(-1, 1) < 0 ? -1 : 1, false)..speed = rand(18, 34));
    }
    _fish.add(_Fish(300, 520, -1, true)..speed = 16);
    for (var i = 0; i < 10; i++) {
      _bubbles.add(Offset(rand(120, 360), rand(_waterY, 620)));
    }
  }

  // --------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    switch (_s) {
      case _St.aim:
        _castX = p.dx.clamp(170.0, 330.0);
        if (p.dy < _waterY) _castX = max(_castX, 220);
        _s = _St.cast;
        _st = 0;
        host.sfx(Sfx.whoosh, rate: 1.3);
        host.sfx(Sfx.pJump, volume: .6);
      case _St.wait:
        final f = _target;
        if (f != null && (Offset(f.x, f.y) - Offset(_castX, _hookY)).distance < 70) {
          // too early — spooked
          host.sfx(Sfx.oops);
          _pops.add(host.tr('too_early', 'TOO EARLY'), Offset(_castX, _waterY - 50), Pal.orange);
          _spook();
        } else {
          _bobDip = .4;
          host.sfx(Sfx.bubble, volume: .5);
        }
      case _St.bite:
        _hook();
      default:
        break;
    }
  }

  @override
  void onKey(String key, bool down) {
    if (key != 'action' && key != 'down' && key != 'up') return;
    _keyHold = down;
    if (down && _s != _St.fight) onDown(Offset(_castX, _waterY + 40));
  }

  void _hook() {
    _s = _St.fight;
    _st = 0;
    _tension = .35;
    _prog = 0;
    _slack = 0;
    _pull = .4;
    _pullT = 0;
    host.sfx(Sfx.pHit);
    host.sfx(Sfx.splash, volume: .7);
    host.flash(Pal.white, .1);
    host.shake(7);
    host.hitStop(.06);
    _pops.add(host.tr('hit', 'HIT!'), Offset(_castX, _waterY - 60), Pal.yellow, 4);
    host.fx.burst(Offset(_castX, _waterY), const Color(0xFFBFEFFF), count: 18, speed: 240, shape: PartShape.square, size: 6);
  }

  void _spook() {
    final f = _target;
    if (f != null) {
      f.flee = 1.4;
      f.dir = f.x < _castX ? -1 : 1;
    }
    _pickTarget(delay: .7);
  }

  void _pickTarget({double delay = .5}) {
    _s = _St.wait;
    _st = 0;
    _delay = delay + rand(.1, .5);
    _nibbles = randInt(2) + 1;
    _nibbleT = 0;
    if (_bigTurn) {
      _target = _fish.firstWhere((f) => f.big);
    } else {
      final cand = _fish.where((f) => !f.big && f.flee <= 0).toList();
      if (cand.isEmpty) {
        _target = _fish.firstWhere((f) => !f.big);
      } else {
        cand.sort((a, b) => (a.x - _castX).abs().compareTo((b.x - _castX).abs()));
        _target = cand.first;
      }
    }
  }

  void _escape(String word) {
    host.sfx(Sfx.pDie, volume: .8);
    host.shake(5);
    _pops.add(word, Offset(_castX, _waterY - 40), Pal.red, 4);
    final f = _target;
    if (f != null) {
      f.flee = 1.6;
      f.dir = f.x < _castX ? -1 : 1;
      f.y = max(f.y, _waterY + 60);
    }
    _target = null;
    _sad = 1.2;
    _s = _St.aim;
    _st = 0;
  }

  // -------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    _st += dt;
    _happy = max(0, _happy - dt);
    _sad = max(0, _sad - dt);
    _pops.update(dt);
    for (var i = 0; i < _bubbles.length; i++) {
      var b = _bubbles[i] - Offset(sin(_t * 2 + i) * .3, 22 * dt);
      if (b.dy < _waterY + 4) b = Offset(rand(120, 360), 620);
      _bubbles[i] = b;
    }
    // ambient swimmers
    for (final f in _fish) {
      if (identical(f, _target) && (_s == _St.wait || _s == _St.bite || _s == _St.fight || _s == _St.show)) continue;
      if (f.caught) continue;
      final sp = f.speed * (f.flee > 0 ? 6 : 1);
      f.flee = max(0, f.flee - dt);
      f.x += f.dir * sp * dt;
      f.y += sin(_t * 1.3 + f.phase) * 6 * dt;
      if (f.x < 125) f.dir = 1;
      if (f.x > 345) f.dir = -1;
      f.y = f.y.clamp(_waterY + 40, 560);
    }
    switch (_s) {
      case _St.aim:
        _bobDip = 0;
        _bob = _rodTip + Offset(4, 30 + sin(_t * 3) * 3);
      case _St.cast:
        final k = (_st / .45).clamp(0.0, 1.0);
        final a = _rodTip;
        final b = Offset(_castX, _waterY);
        _bob = Offset(M.lerp(a.dx, b.dx, k), M.lerp(a.dy, b.dy, k) - sin(k * pi) * 90);
        if (k >= 1) {
          host.sfx(Sfx.splash, volume: .6, rate: 1.2);
          host.fx.burst(b, const Color(0xFFCFF4FF), count: 10, speed: 150, shape: PartShape.square, size: 5);
          _pickTarget();
        }
      case _St.wait:
        _bob = Offset(_castX, _waterY - 2 + sin(_t * 2.4) * 1.5 + _bobDip * 8);
        _bobDip = max(0, _bobDip - dt * 3);
        final f = _target!;
        if (_delay > 0) {
          _delay -= dt;
        } else {
          final goal = Offset(_castX + (f.big ? 26 : 14) * f.dir * -1, _hookY + 4);
          final d = goal - Offset(f.x, f.y);
          if (d.distance > 3) {
            f.dir = d.dx >= 0 ? 1 : -1;
            final v = d / d.distance * min(d.distance, (f.big ? 70 : 95) * dt * host.speed);
            f.x += v.dx;
            f.y += v.dy;
          } else {
            _nibbleT += dt;
            final period = .42 / host.speed;
            if (_nibbleT > period) {
              _nibbleT = 0;
              if (_nibbles > 0) {
                _nibbles--;
                _bobDip = .5;
                f.x -= f.dir * 5;
                host.sfx(Sfx.tick, rate: 1.4);
              } else {
                _s = _St.bite;
                _st = 0;
                host.sfx(Sfx.pSelect, rate: 1.2);
                host.sfx(Sfx.splash, volume: .5, rate: 1.5);
                host.punch(.03);
              }
            }
          }
        }
      case _St.bite:
        _bobDip = 1;
        _bob = Offset(_castX + sin(_t * 40) * 2, _waterY + 10);
        final win = (_bigTurn ? .8 : .75) / sqrt(host.speed);
        if (_st > win) _escape(host.tr('miss', 'MISS'));
      case _St.fight:
        _updateFight(dt);
      case _St.show:
        break;
    }
  }

  void _updateFight(double dt) {
    final hold = host.pointerDown || _keyHold;
    final big = _bigTurn;
    _pullT -= dt;
    if (_pullT <= 0) {
      _pullT = rand(.45, 1.0);
      _pull = big ? (chance(.35) ? rand(.7, 1.0) : rand(.15, .55)) : rand(.1, .6);
      if (_pull > .7) {
        _thrash = .5;
        host.sfx(Sfx.splash, volume: .4, rate: 1.4);
      }
    }
    _thrash = max(0, _thrash - dt);
    final sp = sqrt(host.speed);
    if (hold) {
      _tension += (.36 + _pull * .5) * dt * sp;
      _prog += (big ? .2 : .36) * dt * (_tension > .12 ? 1 : .4);
      _tick -= dt;
      if (_tick <= 0) {
        _tick = .09;
        host.sfx(Sfx.tick, volume: .35, rate: .8 + _prog * .8);
      }
    } else {
      _tension -= (.7 - _pull * .3) * dt;
      _prog -= .05 * _pull * dt;
    }
    _tension = max(0, _tension);
    _prog = _prog.clamp(0.0, 1.0);
    if (_tension > .8) {
      _beep -= dt;
      if (_beep <= 0) {
        _beep = .16;
        host.sfx(Sfx.beep, volume: .5, rate: 1.5);
      }
    }
    if (_tension >= 1) {
      host.sfx(Sfx.pExplode, volume: .7);
      host.flash(Pal.red, .12);
      _escape(host.tr('snap', 'SNAP!'));
      return;
    }
    _slack = _tension < .08 ? _slack + dt : 0;
    if (_slack > 1.2) {
      _escape(host.tr('slack', 'SLACK'));
      return;
    }
    final f = _target!;
    final deep = _hookY + 10;
    f.x = _castX + sin(_t * (3 + _pull * 6)) * (8 + _pull * 22) + (_thrash > 0 ? sin(_t * 50) * 6 : 0);
    f.y = M.lerp(deep, _waterY + 16, _prog);
    f.dir = sin(_t * 2) > 0 ? 1 : -1;
    if (_prog >= 1) _land();
  }

  void _land() {
    final f = _target!;
    f.caught = true;
    _showBig = f.big;
    _s = _St.show;
    _st = 0;
    _caught++;
    _happy = 2;
    host.sfx(Sfx.splash);
    host.sfx(f.big ? Sfx.fanfare : Sfx.pPowerup);
    host.shake(f.big ? 10 : 5);
    host.flash(Pal.white, .15);
    host.fx.burst(Offset(_castX, _waterY), const Color(0xFFCFF4FF), count: 26, speed: 320, shape: PartShape.square, size: 7);
    host.addScore(f.big ? 1510 : 300, const Offset(180, 250));
    if (f.big) {
      host.fx.confetti();
      host.fx.coins(const Offset(180, 300), count: 20);
      host.win(stars: host.timeLeft > 5 ? 3 : (host.timeLeft > 2 ? 2 : 1));
    } else {
      host.fx.sparkle(const Offset(180, 290), color: Pal.yellow, count: 14, radius: 60);
    }
    _target = null;
  }

  // -------------------------------------------------------------- render ---
  @override
  void render(Canvas c) {
    c.drawPicture(_bg ??= _buildBg());
    _drawAmbient(c);
    // fish (shadows) — below surface
    c.save();
    c.clipRect(const Rect.fromLTWH(0, _waterY + 2, 360, 640));
    for (final f in _fish) {
      if (f.caught) continue;
      final spr = f.big ? _S.bigFish : _S.fish;
      final lit = identical(f, _target) && _s == _St.fight && _prog > .45;
      final wob = (_t * (f.flee > 0 ? 14 : 5) + f.phase).floor().isEven;
      final pos = Offset(f.x.roundToDouble(), f.y.roundToDouble());
      if (lit) {
        spr.drawCentered(c, pos, scale: _px, flipX: f.dir > 0);
      } else {
        spr.drawCentered(c, pos, scale: _px, flipX: f.dir > 0, tint: const Color(0xFF0B2448), opacity: f.big ? .8 : .6);
      }
      if (f.big && !lit) {
        // legendary shimmer on the shadow
        if ((_t * 3).floor() % 3 == 0) _px4(c, pos + Offset(wob ? -12 : 12, -9), const Color(0xFFFFE27A));
      }
    }
    for (final b in _bubbles) {
      _px4(c, Offset(b.dx.roundToDouble(), b.dy.roundToDouble()), const Color(0x88CFF4FF), 3);
    }
    c.restore();
    _drawSurface(c);
    _drawFisher(c);
    _drawLine(c);
    if (_s == _St.fight) _drawFightHud(c);
    if (_s == _St.show) _drawShow(c);
    _drawHud(c);
    _pops.render(c, host);
    Retro.scanlines(c, alpha: .1);
    Retro.vignette(c, strength: .35);
  }

  void _px4(Canvas c, Offset p, Color col, [double s = 3]) =>
      c.drawRect(Rect.fromLTWH(p.dx, p.dy, s, s), Paint()..color = col);

  void _drawAmbient(Canvas c) {
    // clouds drifting
    for (var i = 0; i < 3; i++) {
      final x = ((i * 140 + _t * (6 + i * 3)) % 460) - 60;
      _S.cloud.draw(c, Offset(x.roundToDouble(), 56.0 + i * 22), scale: 3, opacity: .9);
    }
    // light rays under water
    final p = Paint()..color = const Color(0x14FFFFFF);
    for (var i = 0; i < 4; i++) {
      final x = 150 + i * 60 + sin(_t * .6 + i) * 10;
      c.drawPath(
          Path()
            ..moveTo(x, _waterY)
            ..lineTo(x + 18, _waterY)
            ..lineTo(x - 30, 560)
            ..lineTo(x - 60, 560)
            ..close(),
          p);
    }
    // swaying weeds
    final wp = Paint()..color = const Color(0xFF2F8F4E);
    final wp2 = Paint()..color = const Color(0xFF4FBF6A);
    for (var i = 0; i < 7; i++) {
      final bx = 130.0 + i * 34 + (i.isEven ? 6 : 0);
      final h = 10 + (i * 7) % 12;
      for (var k = 0; k < h; k++) {
        final sway = (sin(_t * 1.6 + i + k * .25) * k * .5).roundToDouble();
        final y = 580.0 - k * 4;
        c.drawRect(Rect.fromLTWH(bx + sway * 1, y, 4, 4), k.isEven ? wp : wp2);
      }
    }
  }

  void _drawSurface(Canvas c) {
    final hi = Paint()..color = const Color(0xFFBFEFFF);
    final mid = Paint()..color = const Color(0xFF6CCBF2);
    for (var x = 0.0; x < 360; x += 6) {
      final w = sin(x * .07 + _t * 3) > .55;
      c.drawRect(Rect.fromLTWH(x, _waterY - (w ? 3 : 0), 6, 3), w ? hi : mid);
    }
    // sparkles on surface
    for (var i = 0; i < 6; i++) {
      final ph = (_t * .8 + i * .37) % 1;
      if (ph < .25) {
        _px4(c, Offset(130.0 + i * 38 + (i * 13) % 20, _waterY + 6 + (i % 3) * 5), const Color(0xFFFFFFFF), 3);
      }
    }
  }

  void _drawFisher(Canvas c) {
    final frame = switch (_s) {
      _St.fight => (_t * 8).floor().isEven ? _S.kidPull : _S.kidPull2,
      _St.show => _S.kidCheer,
      _ => _happy > 0 ? _S.kidCheer : (_sad > 0 ? _S.kidSad : _S.kid),
    };
    final bounce = (_s == _St.show || _happy > 0) ? -(sin(_t * 16).abs() * 6).roundToDouble() : 0.0;
    frame.draw(c, Offset(66, 138 + bounce), scale: _px);
    // rod
    final hand = Offset(99, 168 + bounce);
    final tip = _rodTip;
    c.drawLine(hand, tip, Paint()
      ..color = const Color(0xFF5A3418)
      ..strokeWidth = 4
      ..isAntiAlias = false);
    c.drawLine(hand + (tip - hand) * .55, tip, Paint()
      ..color = const Color(0xFFE8C07A)
      ..strokeWidth = 2
      ..isAntiAlias = false);
    // reel
    c.drawRect(Rect.fromCenter(center: hand + const Offset(6, -4), width: 8, height: 8), Paint()..color = const Color(0xFFB0B8C8));
    if (_sad > 0 && (_t * 6).floor().isEven) {
      // sweat drop
      _px4(c, const Offset(106, 142), const Color(0xFF8FD8FF), 3);
      _px4(c, const Offset(106, 145), const Color(0xFF8FD8FF), 3);
    }
  }

  void _drawLine(Canvas c) {
    final tip = _rodTip;
    final lp = Paint()
      ..color = const Color(0xDDFFFFFF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    if (_s == _St.fight) {
      final f = _target!;
      final mouth = Offset(f.x + (f.big ? 30 : 16) * (f.dir > 0 ? 1 : -1), f.y);
      final taut = _tension.clamp(0.0, 1.0);
      final mid = Offset((tip.dx + mouth.dx) / 2, (tip.dy + mouth.dy) / 2 + (1 - taut) * 30);
      lp.color = Color.lerp(const Color(0xDDFFFFFF), Pal.red, ((_tension - .75) * 4).clamp(0.0, 1.0))!;
      c.drawPath(Path()
        ..moveTo(tip.dx, tip.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, mouth.dx, mouth.dy), lp);
      // splash at the line entry
      if ((_t * 10).floor().isEven) {
        _px4(c, Offset(f.x - 6, _waterY - 6), const Color(0xFFE0F8FF), 4);
        _px4(c, Offset(f.x + 6, _waterY - 8), const Color(0xFFE0F8FF), 4);
      }
      return;
    }
    if (_s == _St.show) return;
    final b = _bob;
    c.drawPath(Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo((tip.dx + b.dx) / 2, max(tip.dy, b.dy) + 10, b.dx, b.dy), lp);
    if (_s == _St.wait || _s == _St.bite) {
      c.drawLine(b, Offset(b.dx, _hookY), Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 1);
      _S.hook.drawCentered(c, Offset(b.dx + 2, _hookY + 3), scale: 2);
    }
    final under = _s == _St.bite;
    _S.bobber.draw(c, Offset((b.dx - 6).roundToDouble(), (b.dy - 12 + (under ? 6 : 0)).roundToDouble()), scale: 2);
    if (under) {
      // "!" alert + splash rings
      final s = 1 + sin(_st * 30) * .1;
      c.save();
      c.translate(b.dx, b.dy - 46);
      c.scale(s);
      _S.alert.drawCentered(c, Offset.zero, scale: 4);
      c.restore();
      c.drawOval(Rect.fromCenter(center: Offset(b.dx, _waterY + 1), width: 30 + _st * 60, height: 8 + _st * 10),
          Paint()
            ..color = const Color(0xAAFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    if (_s == _St.aim && host.time < 3 && _caught == 0) {
      D.hand(c, const Offset(260, 250), _t);
      _ptext(c, host.tr('tap', 'TAP'), const Offset(262, 330), 3, Pal.white);
    }
    if (_s == _St.aim && _caught == 1) {
      _ptext(c, host.tr('cast', 'CAST!'), Offset(250, 280 + sin(_t * 6) * 3), 3, Pal.yellow);
    }
  }

  void _drawFightHud(Canvas c) {
    // panel
    const r = Rect.fromLTWH(24, 572, 312, 48);
    c.drawRect(r.inflate(3), Paint()..color = const Color(0xFF10122A));
    c.drawRect(r, Paint()..color = const Color(0xFF2A2D5A));
    c.drawRect(r.deflate(3), Paint()..color = const Color(0xFF151836));
    // tension bar
    const bar = Rect.fromLTWH(60, 582, 264, 14);
    c.drawRect(bar, Paint()..color = const Color(0xFF0A0A18));
    final zones = <(double, double, Color)>[
      (0, .12, const Color(0xFF3A6FD8)),
      (.12, .8, const Color(0xFF3FCB5A)),
      (.8, 1, const Color(0xFFE8453C)),
    ];
    for (final z in zones) {
      c.drawRect(Rect.fromLTRB(bar.left + bar.width * z.$1, bar.top + 2, bar.left + bar.width * z.$2, bar.bottom - 2),
          Paint()..color = z.$3);
    }
    final nx = bar.left + bar.width * _tension.clamp(0.0, 1.0);
    final shake = _tension > .8 ? sin(_t * 60) * 2 : 0.0;
    _S.needle.drawCentered(c, Offset(nx + shake, bar.top - 4), scale: 2);
    _S.fishIcon.draw(c, const Offset(32, 580), scale: 2);
    // progress (distance to surface)
    const pb = Rect.fromLTWH(60, 602, 264, 8);
    c.drawRect(pb, Paint()..color = const Color(0xFF0A0A18));
    c.drawRect(Rect.fromLTWH(pb.left, pb.top, pb.width * _prog, pb.height), Paint()..color = Pal.yellow);
    for (var x = pb.left; x < pb.left + pb.width * _prog; x += 8) {
      c.drawRect(Rect.fromLTWH(x, pb.top, 4, 2), Paint()..color = const Color(0xFFFFF3B0));
    }
    // hints
    if (_st < 2.2) {
      _ptext(c, host.tr('hold', 'HOLD'), Offset(180, 540 + sin(_t * 8) * 2), 3, Pal.white);
    } else if (_tension > .8) {
      _ptext(c, host.tr('let_go', 'LET GO!'), Offset(180 + sin(_t * 40) * 2, 540), 3, Pal.red);
    } else if (_tension < .12) {
      _ptext(c, host.tr('reel', 'REEL!'), Offset(180, 540), 3, const Color(0xFF8FD8FF));
    }
  }

  void _drawShow(Canvas c) {
    final k = (_st / .6).clamp(0.0, 1.0);
    final start = Offset(_castX, _waterY);
    const end = Offset(180, 330);
    final pos = Offset(M.lerp(start.dx, end.dx, k), M.lerp(start.dy, end.dy, k) - sin(k * pi) * 120);
    if (k >= 1) {
      D.rays(c, end, 260, _showBig ? const Color(0x33FFE27A) : const Color(0x22FFFFFF), count: 14, t: _t);
    }
    final spr = _showBig ? _S.bigFish : _S.fish;
    final sc = (_showBig ? 5.0 : 5.0) * (k < 1 ? .6 + .4 * k : 1 + sin(_t * 10) * .05);
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate(k < 1 ? k * pi * 2 : sin(_t * 6) * .12);
    spr.drawCentered(c, Offset.zero, scale: sc.roundToDouble());
    c.restore();
    if (k >= 1 && _st < 2.6) {
      final label = _showBig ? host.tr('legendary', 'LEGENDARY!') : host.tr('nice', 'NICE!');
      _ptext(c, label, const Offset(180, 400), 4, _showBig ? Pal.gold : Pal.white);
      final cm = _showBig ? '151CM' : '32CM';
      PixelFont.draw(c, cm, const Offset(180, 424), 3, const Color(0xFFBFEFFF), align: 0, shadow: Pal.ink);
    }
    if (!_showBig && _st > 1.3) {
      _s = _St.aim;
      _st = 0;
    }
  }

  void _drawHud(Canvas c) {
    // catch slots
    const r = Rect.fromLTWH(234, 44, 118, 38);
    c.drawRect(r.inflate(2), Paint()..color = const Color(0xFF10122A));
    c.drawRect(r, Paint()..color = const Color(0xCC1C2050));
    final small = _caught >= 1;
    final big = _caught >= 2;
    _S.fish.drawCentered(c, const Offset(262, 63), scale: 2, tint: small ? null : const Color(0xFF3A3F70));
    _S.bigFish.drawCentered(c, const Offset(318, 63), scale: 2, tint: big ? null : const Color(0xFF3A3F70));
    if (!big) PixelFont.draw(c, '?', const Offset(318, 57), 2, Pal.gold, align: 0);
    if (small) PixelFont.draw(c, 'OK', const Offset(262, 72), 1, Pal.lime, align: 0);
  }

  void _ptext(Canvas c, String s, Offset center, double scale, Color col) => _pt(c, s, center, scale, col);

  ui.Picture _buildBg() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    // sky bands (dithered)
    const sky = [Color(0xFF2B3F9E), Color(0xFF3F63CF), Color(0xFF5E8EEA), Color(0xFF8CB6F6), Color(0xFFF6C58A), Color(0xFFFFE0A8)];
    _bands(c, 0, 180, sky);
    // sun
    final sun = Paint()..color = const Color(0xFFFFF1B8);
    for (var y = -5; y <= 5; y++) {
      final w = sqrt(max(0, 25 - y * y)).round();
      c.drawRect(Rect.fromLTWH(290.0 - w * 4, 150.0 + y * 4, w * 8.0, 4), sun);
    }
    // far hills
    final hill = Paint()..color = const Color(0xFF3E6FA8);
    final hill2 = Paint()..color = const Color(0xFF2F5A43);
    for (var x = 0.0; x < 360; x += 4) {
      final h = 20 + sin(x * .025) * 10 + sin(x * .07) * 5;
      c.drawRect(Rect.fromLTWH(x, 196 - h, 4, h + 16), hill);
    }
    for (var x = 0.0; x < 360; x += 4) {
      final h = 8 + (sin(x * .11) * 5).abs() + ((x ~/ 4) % 3) * 2;
      c.drawRect(Rect.fromLTWH(x, 212 - h, 4, h), hill2);
    }
    // water bands
    const water = [Color(0xFF3BA7E0), Color(0xFF2A88C8), Color(0xFF226FAE), Color(0xFF1B5892), Color(0xFF154476), Color(0xFF10345E)];
    _bands(c, _waterY, 600, water);
    // lake floor
    final sand = Paint()..color = const Color(0xFF8E6C43);
    final sand2 = Paint()..color = const Color(0xFF6B4F30);
    for (var x = 0.0; x < 360; x += 4) {
      final h = 30 + sin(x * .04) * 8 + ((x ~/ 4) % 5 == 0 ? 4 : 0);
      c.drawRect(Rect.fromLTWH(x, 640 - h, 4, h), sand);
      c.drawRect(Rect.fromLTWH(x, 640 - h, 4, 4), sand2);
    }
    for (final r in const [Offset(150, 606), Offset(262, 612), Offset(330, 600)]) {
      _S.rock.draw(c, r, scale: 3);
    }
    // pier
    final wood = Paint()..color = const Color(0xFF8A5A2B);
    final woodD = Paint()..color = const Color(0xFF5E3A18);
    final woodL = Paint()..color = const Color(0xFFB07A3E);
    for (final px in const [20.0, 70.0, 110.0]) {
      c.drawRect(Rect.fromLTWH(px, 192, 10, 170), woodD);
      c.drawRect(Rect.fromLTWH(px, 192, 4, 170), wood);
    }
    c.drawRect(const Rect.fromLTWH(0, 186, 126, 12), wood);
    c.drawRect(const Rect.fromLTWH(0, 186, 126, 3), woodL);
    for (var x = 0.0; x < 126; x += 18) {
      c.drawRect(Rect.fromLTWH(x, 186, 2, 12), woodD);
    }
    // reeds on the pier edge
    final reed = Paint()..color = const Color(0xFF6FAF3A);
    for (var i = 0; i < 6; i++) {
      c.drawRect(Rect.fromLTWH(342.0 - i * 5, 176.0 + (i % 3) * 6, 3, 40 - (i % 3) * 6.0), reed);
    }
    // bucket
    _S.bucket.draw(c, const Offset(14, 162), scale: 3);
    return rec.endRecording();
  }

  static void _bands(Canvas c, double top, double bottom, List<Color> cols) {
    final h = (bottom - top) / cols.length;
    for (var i = 0; i < cols.length; i++) {
      final y = top + i * h;
      c.drawRect(Rect.fromLTWH(0, y, 360, h + 1), Paint()..color = cols[i]);
      if (i + 1 < cols.length) {
        // checker dither into the next band
        final p = Paint()..color = cols[i + 1];
        for (var x = 0.0; x < 360; x += 8) {
          c.drawRect(Rect.fromLTWH(x, y + h - 8, 4, 4), p);
          c.drawRect(Rect.fromLTWH(x + 4, y + h - 4, 4, 4), p);
        }
      }
    }
  }
}

enum _St { aim, cast, wait, bite, fight, show }

class _Fish {
  _Fish(this.x, this.y, this.dir, this.big) : phase = x * .1;
  double x, y, dir;
  final bool big;
  double speed = 20;
  double flee = 0;
  final double phase;
  bool caught = false;
}

/// Small floating pixel-text popups.
class _Pops {
  final List<(String, Offset, Color, double, double)> _l = [];
  void add(String s, Offset at, Color col, [double scale = 3]) {
    if (_l.length < 8) _l.add((s, at, col, scale, 0));
  }

  void update(double dt) {
    for (var i = _l.length - 1; i >= 0; i--) {
      final e = _l[i];
      if (e.$5 + dt > 1.1) {
        _l.removeAt(i);
      } else {
        _l[i] = (e.$1, e.$2 - Offset(0, 30 * dt), e.$3, e.$4, e.$5 + dt);
      }
    }
  }

  void render(Canvas c, GameHost host) {
    for (final e in _l) {
      if (e.$5 > .8 && ((e.$5 * 20).floor().isEven)) continue;
      final s = e.$5 < .1 ? e.$4 + 1 : e.$4;
      _pt(c, e.$1, e.$2, s, e.$3);
    }
  }
}

final _asciiRe = RegExp(r"^[A-Za-z0-9 !?.,:\-+/%$*<>=#'()]*$");

/// Pixel-font text when the (translated) string is plain ASCII, otherwise a
/// chunky outlined system font so every language still reads.
void _pt(Canvas c, String s, Offset center, double scale, Color col) {
  if (_asciiRe.hasMatch(s)) {
    PixelFont.draw(c, s, center - Offset(0, 3.5 * scale), scale, col, align: 0, shadow: const Color(0xFF10122A));
  } else {
    D.text(c, s, center, size: 8 * scale, color: col, stroke: const Color(0xFF10122A), strokeWidth: scale * 1.5);
  }
}

// ------------------------------------------------------------- sprites ---
abstract final class _S {
  static const _k = Color(0xFF1A1426);
  static const _pal = <String, Color>{
    'K': _k,
    'S': Color(0xFFFFC99A),
    's': Color(0xFFE09A6A),
    'H': Color(0xFFF2CF4A),
    'h': Color(0xFFC0392B),
    'R': Color(0xFFE84A3C),
    'r': Color(0xFFA82E26),
    'B': Color(0xFF3656B8),
    'b': Color(0xFF223A80),
    'W': Color(0xFFFFFFFF),
    'P': Color(0xFFFF8FA0),
  };

  static final kid = Sprite(const [
    '....HHHHH.....',
    '...HHHHHHH....',
    '.HHhhhhhhhHH..',
    'HHHHHHHHHHHHH.',
    '...SSSSSSS....',
    '...SKSSSKS....',
    '...SSSSSSS....',
    '...SPSKKSP....',
    '....SSSSS.....',
    '...RRRRRRR....',
    '..RRRRRRRRSS..',
    '..SrRRRRRR....',
    '...RRRRRRR....',
    '...BBBBBBB....',
    '...BBB.BBB....',
    '...BBB.BBB....',
    '..KKKK.KKKK...',
  ], _pal);
  static final kidSad = Sprite(const [
    '....HHHHH.....',
    '...HHHHHHH....',
    '.HHhhhhhhhHH..',
    'HHHHHHHHHHHHH.',
    '...SSSSSSS....',
    '...KKSSSKK....',
    '...SSSSSSS....',
    '...SSKKKSS....',
    '....SKSKS.....',
    '...RRRRRRR....',
    '..RRRRRRRRSS..',
    '..SrRRRRRR....',
    '...RRRRRRR....',
    '...BBBBBBB....',
    '...BBB.BBB....',
    '...BBB.BBB....',
    '..KKKK.KKKK...',
  ], _pal);
  static final kidPull = Sprite(const [
    '....HHHHH.....',
    '...HHHHHHH....',
    '.HHhhhhhhhHH..',
    'HHHHHHHHHHHHH.',
    '...SSSSSSS....',
    '...SKKSKKS....',
    '...SSSSSSS....',
    '...SKKKKKS....',
    '....SWWWS.....',
    '..RRRRRRRR....',
    '.RRRRRRRRRSS..',
    '.SrRRRRRRR....',
    '..RRRRRRR.....',
    '..BBBBBBB.....',
    '.BBB...BBB....',
    '.BBB....BBB...',
    'KKKK....KKKK..',
  ], _pal);
  static final kidPull2 = Sprite(const [
    '..............',
    '....HHHHH.....',
    '...HHHHHHH....',
    '.HHhhhhhhhHH..',
    'HHHHHHHHHHHHH.',
    '...SSSSSSS....',
    '...SKKSKKS....',
    '...SSSSSSS....',
    '...SKKKKKS....',
    '..RRRRRRRR....',
    '.RRRRRRRRRSS..',
    '.SrRRRRRRR....',
    '..RRRRRRR.....',
    '..BBBBBBB.....',
    '.BBB...BBB....',
    '.BBB....BBB...',
    'KKKK....KKKK..',
  ], _pal);
  static final kidCheer = Sprite(const [
    '....HHHHH.....',
    '...HHHHHHH....',
    '.HHhhhhhhhHH..',
    'HHHHHHHHHHHHH.',
    'S..SSSSSSS..S.',
    'S..SKSSSKS..S.',
    'S..SSSSSSS..S.',
    'R..SKKKKKS..R.',
    'RR..SPPPS..RR.',
    '.RRRRRRRRRRR..',
    '...RRRRRRR....',
    '...RRRRRRR....',
    '...RRRRRRR....',
    '...BBBBBBB....',
    '...BBB.BBB....',
    '...BBB.BBB....',
    '..KKKK.KKKK...',
  ], _pal);

  static const _fp = <String, Color>{
    'O': Color(0xFFFF8A3D),
    'o': Color(0xFFD35A1E),
    'Y': Color(0xFFFFD08A),
    'W': Color(0xFFFFFFFF),
    'K': _k,
    'F': Color(0xFFFFB070),
  };
  static final fish = Sprite(const [
    '.....oooo......',
    '...oOOOOOoo...o',
    '..OOOOOOOOOo.oo',
    '.OWKOOoOOoOOOOo',
    'OOOOOOOoOOoOOO.',
    '.YYYYYYYYYYOOOo',
    '..YYYYYYYYO.oo.',
    '....FFF......o.',
  ], _fp);

  static const _gp = <String, Color>{
    'G': Color(0xFFFFC53D),
    'g': Color(0xFFD08A10),
    'L': Color(0xFFFFF0A0),
    'R': Color(0xFFE8453C),
    'W': Color(0xFFFFFFFF),
    'K': _k,
    'T': Color(0xFF3FCBB0),
  };
  static final bigFish = Sprite(const [
    '.........gggggg............',
    '......ggGGGGGGGGgg.......gg',
    '....gGGGGgGGgGGgGGGg....gTg',
    '...GGGGGGGGGGGGGGGGGGg.gTTg',
    '..GWWGGGgGGgGGgGGgGGGGgTTg.',
    '.GGWKGGGGGGGGGGGGGGGGGGTTg.',
    'RGGGGGGgGGgGGgGGgGGgGGGTTTg',
    '.RRGGGGGGGGGGGGGGGGGGGgTTg.',
    '..LLLLLLLLLLLLLLLLLLGGgTTTg',
    '...LLLLLLLLLLLLLLLLGGg.gTTg',
    '.....LLLLLLLLLLLLGGg....gTg',
    '.......TTT..TTTT.........gg',
  ], _gp);

  static final bobber = Sprite(const [
    '..K...',
    '..K...',
    '.RRRR.',
    'RRWRRR',
    'WWWWWW',
    '.WWWW.',
  ], const {'K': _k, 'R': Color(0xFFE8453C), 'W': Color(0xFFFFFFFF)});

  static final hook = Sprite(const [
    '.W.',
    '.W.',
    'W.W',
    'WWW',
  ], const {'W': Color(0xFFD8DDE8)});

  static final alert = Sprite(const [
    '.KKKK.',
    'KYYYYK',
    'KYYYYK',
    'KYYYYK',
    '.KYYK.',
    '.KYYK.',
    '..KK..',
    '.KKKK.',
    '.KYYK.',
    '.KKKK.',
  ], const {'K': _k, 'Y': Color(0xFFFFE14A)});

  static final needle = Sprite(const [
    'KKKKKKK',
    'KWWWWWK',
    '.KWWWK.',
    '..KWK..',
    '...K...',
  ], const {'K': _k, 'W': Color(0xFFFFFFFF)});

  static final fishIcon = Sprite(const [
    '..OOOO..O',
    '.OOOOOOOO',
    'OWOOOOOO.',
    '.OOOOOOOO',
    '..OOOO..O',
  ], const {'O': Color(0xFFFF8A3D), 'W': Color(0xFFFFFFFF)});

  static final cloud = Sprite(const [
    '.....WWWW.......',
    '...WWWWWWWW.WW..',
    '.WWWWWWWWWWWWWWW',
    'WWWWWWWWWWWWWWWW',
    '.LLLLLLLLLLLLLL.',
  ], const {'W': Color(0xFFFFFFFF), 'L': Color(0xFFD6E4FF)});

  static final rock = Sprite(const [
    '...GGGG...',
    '.GGGgGGGG.',
    'GGgGGGGgGG',
    'gGGGGgGGGg',
  ], const {'G': Color(0xFF5C6478), 'g': Color(0xFF3C4254)});

  static final bucket = Sprite(const [
    '.KKKKKK.',
    'KWWWWWWK',
    'KBBBBBBK',
    '.KBBBBK.',
    '.KBBBBK.',
    '..KKKK..',
  ], const {'K': _k, 'W': Color(0xFF8FD8FF), 'B': Color(0xFF8E98B0)});
}
