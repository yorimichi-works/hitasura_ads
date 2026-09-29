import 'dart:math' as math;
import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.110 Triple 7 Slots — neon slot machine with STOP buttons.
///
/// Tap (or pull the lever) to spin, then tap each STOP button when the 7
/// comes around. Reels slow with an overshoot; two 7s trigger REACH! with
/// pachinko strobes and a slow-motion last reel (sometimes it "revives" one
/// notch into a 7). Reach the coin goal within 3 spins. 777 = JACKPOT.

const _rainbow = <Color>[
  Color(0xFFFF3B5C),
  Color(0xFFFF8A1F),
  Color(0xFFFFE23F),
  Color(0xFF52E05A),
  Color(0xFF2ED8FF),
  Color(0xFF6A5BFF),
  Color(0xFFE04DFF),
];

Paint _glow(Color c, double blur) => Paint()
  ..color = c
  ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur);

/// 0 = seven, 1 = cherry, 2 = bell, 3 = BAR, 4 = star
const _strip = <int>[0, 1, 2, 3, 4, 1, 2, 3];

int _symAt(int i) => _strip[((i % 8) + 8) % 8];

enum _RS { idle, spin, stop, revive, done }

class _Reel {
  double pos = 0, speed = 0;
  _RS st = _RS.idle;
  double from = 0, to = 0, dur = .35, u = 0;
  bool slow = false, willRevive = false;
  double wait = 0;
  double press = 0;
  double glow = 0;
  int get sym => _symAt(to.round());
}

enum _St { ready, spinning, payout, over }

class G110 extends MiniGame {
  static const _goal = 500;
  static const _payY = 286.0;
  static const _symH = 72.0;
  static const _reelX = <double>[77, 159, 241];
  static const _stopY = 440.0;

  final _reels = List<_Reel>.generate(3, (_) => _Reel());
  _St _st = _St.ready;
  double _t = 0, _stT = 0;
  int _spin = 0; // spins used
  int _coins = 0;
  double _coinsDisp = 0;
  double _lever = 0; // 0..1 pulled
  bool _leverDrag = false;
  double _leverY0 = 0;
  bool _reach = false;
  double _idle = 0;
  int _lastPay = 0;
  String _payLabel = '';
  bool _jackpot = false;
  double _winAt = -1;
  double _strobe = 0;
  double _lineFlash = 0;
  Face _mood = Face.smug;
  final _pile = <Offset>[];
  final _lights = <double>[];

  @override
  Color get backdrop => const Color(0xFF0B0218);

  @override
  void init() {
    for (final r in _reels) {
      r.pos = randInt(8).toDouble() + 2;
    }
    for (var i = 0; i < 70; i++) {
      // heap-shaped scatter for the coin pile
      final x = rand(-1, 1);
      final h = (1 - x * x) * rand(0, 1);
      _pile.add(Offset(180 + x * 120, 612 - h * 40));
    }
    _pile.sort((a, b) => b.dy.compareTo(a.dy));
    for (var i = 0; i < 12; i++) {
      _lights.add(rand(0, 6.28));
    }
  }

  // ---------------------------------------------------------------- logic --

  void _startSpin() {
    if (_st != _St.ready || host.finished) return;
    _st = _St.spinning;
    _stT = 0;
    _spin++;
    _reach = false;
    _idle = 0;
    _lever = 1;
    _mood = Face.smug;
    host.sfx(Sfx.clang, volume: .6);
    host.sfx(Sfx.spin);
    host.shake(3);
    for (var i = 0; i < 3; i++) {
      final r = _reels[i];
      r
        ..st = _RS.spin
        ..speed = -4 - i * 1.5
        ..slow = false
        ..willRevive = false
        ..glow = 0;
    }
  }

  void _stopReel(int i) {
    final r = _reels[i];
    if (r.st != _RS.spin || r.speed < 3) return;
    r.press = 1;
    _idle = 0;
    host.sfx(Sfx.click, rate: 1.2);
    final lastSpin = _spin >= 3;
    final stopped = _reels.where((e) => e.st != _RS.spin).toList();
    final reachStop = _reach && stopped.length == 2;
    final win = lastSpin ? 2 : 1; // assist window (symbols each side)
    final nat = (r.pos + 1.3).ceil();
    int? seven;
    for (final d in [0, 1, -1, 2, -2]) {
      if (d.abs() > win) continue;
      final t = nat + d;
      if (t < r.pos + .45) continue;
      if (_symAt(t) == 0) {
        seven = t;
        break;
      }
    }
    var target = seven ?? nat;
    if (reachStop) {
      final mercy = [.35, .55, 1.0][math.min(2, _spin - 1)];
      if (seven == null && chance(mercy)) {
        // stop one notch short of the 7... then REVIVE!
        var s = nat;
        while (_symAt(s) != 0) {
          s++;
        }
        target = s - 1;
        r.willRevive = true;
      }
      target += 8; // one extra agonising loop
      r
        ..slow = true
        ..dur = 2.1;
      host.sfx(Sfx.drumroll);
      host.sfx(Sfx.heartbeat, volume: .8);
    } else {
      r
        ..slow = false
        ..dur = .38;
    }
    r
      ..st = _RS.stop
      ..from = r.pos
      ..to = target.toDouble()
      ..u = 0;
  }

  void _reelLanded(int i) {
    final r = _reels[i];
    r.st = _RS.done;
    r.glow = 1;
    host.sfx(Sfx.reelStop, rate: .95 + i * .08);
    host.shake(r.slow ? 7 : 2.5);
    if (r.sym == 0) {
      host.sfx(Sfx.ding, rate: 1 + i * .12, volume: .7);
      host.fx.sparkle(Offset(_reelX[i], _payY), count: 8, radius: 30, color: Pal.yellow);
    }
    final done = _reels.where((e) => e.st == _RS.done).toList();
    if (done.length == 2 && !_reach && done.every((e) => e.sym == 0)) {
      _reach = true;

      _mood = Face.shocked;
      host.sfx(Sfx.rarityUp);
      host.sfx(Sfx.whistle, volume: .5);
      host.flash(const Color(0x88FF3B5C), .2);
      host.shake(8);
      host.punch(.05);
      host.fx.pop(host.tr('reach', 'REACH!'), const Offset(180, 230), color: Pal.red, size: 44, life: 1.2);
    }
    if (done.length == 3) _payout();
  }

  void _payout() {
    _st = _St.payout;
    _stT = 0;
    final s = _reels.map((e) => e.sym).toList();
    var pay = 0;
    var label = '';
    if (s[0] == s[1] && s[1] == s[2]) {
      pay = const [777, 100, 150, 200, 300][s[0]];
      label = s[0] == 0 ? host.tr('jackpot', 'JACKPOT!') : host.tr('bingo', 'BINGO!');
    } else {
      final sevens = s.where((e) => e == 0).length;
      if (sevens == 2) {
        pay = 77;
        label = host.tr('so_close', 'SO CLOSE!');
      } else if (s[0] == s[1] || s[1] == s[2] || s[0] == s[2]) {
        pay = 30;
      }
      pay += s.where((e) => e == 1).length * 15;
    }
    _jackpot = s.every((e) => e == 0);
    _lastPay = pay;
    _payLabel = label;
    _coins += pay;
    if (pay > 0) _lineFlash = 1;
    host.setMusicVolume(1);
    if (_jackpot) {
      _mood = Face.love;
      host.sfx(Sfx.ssr);
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.coins);
      host.flash(Pal.white, .3);
      host.shake(16, .6);
      host.hitStop(.12);
      host.punch(.08);
      host.fx.burst(const Offset(180, _payY), Pal.yellow, count: 60, speed: 520, colors: _rainbow, shape: PartShape.star, gravity: 200);
      host.fx.coins(const Offset(180, 470), count: 40, speed: 750);
      host.fx.confetti(count: 90);
    } else if (pay >= 100) {
      _mood = Face.happy;
      host.sfx(Sfx.jingleWin);
      host.sfx(Sfx.coins);
      host.shake(6);
      host.fx.coins(const Offset(180, 470), count: 22, speed: 600);
    } else if (pay > 0) {
      _mood = Face.happy;
      host.sfx(Sfx.coin);
      host.fx.coins(const Offset(180, 470), count: 6 + pay ~/ 10, speed: 420);
    } else {
      _mood = Face.sad;
      host.sfx(Sfx.buzzer, volume: .6);
    }
    if (_reach && !_jackpot) {
      _mood = Face.cry;
      host.sfx(Sfx.aww, volume: .7);
    }
    if (pay > 0) host.fx.pop('+$pay', const Offset(180, 350), color: Pal.yellow, size: _jackpot ? 46 : 32, life: 1.2);
    if (_coins >= _goal) _winAt = host.time + (_jackpot ? 1.3 : .8);
  }

  // --------------------------------------------------------------- update --

  @override
  void update(double dt) {
    _t += dt;
    _stT += dt;
    _strobe = M.approach(_strobe, _reach && _st == _St.spinning ? 1 : 0, 6, dt);
    _lineFlash = M.approach(_lineFlash, 0, 1.2, dt);
    if (!_leverDrag) _lever = M.approach(_lever, 0, 9, dt);

    final prevDisp = _coinsDisp.floor();
    _coinsDisp = M.approach(_coinsDisp, _coins.toDouble(), 3.2, dt);
    if ((_coins - _coinsDisp) < .6) _coinsDisp = _coins.toDouble();
    if (_coinsDisp.floor() ~/ 10 != prevDisp ~/ 10) host.sfx(Sfx.tick, volume: .35, rate: 1.5);

    for (var i = 0; i < 3; i++) {
      final r = _reels[i];
      r.press = M.approach(r.press, 0, 10, dt);
      r.glow = M.approach(r.glow, 0, 2.5, dt);
      switch (r.st) {
        case _RS.spin:
          if (_stT > i * .08) {
            r.speed = M.approach(r.speed, 15.0 * (.9 + .1 * host.speed), 5, dt);
            r.pos += r.speed * dt;
          }
        case _RS.stop:
          r.u = math.min(1, r.u + dt / r.dur);
          final e = r.slow ? _slowEase(r.u) : M.easeOutBack(r.u);
          final before = r.pos.floor();
          r.pos = r.from + (r.to - r.from) * e;
          if (r.slow && r.pos.floor() != before) host.sfx(Sfx.tick, rate: .8 + r.u * .6, volume: .8);
          if (r.u >= 1) {
            r.pos = r.to;
            if (r.willRevive) {
              r.st = _RS.revive;
              r.wait = 0;
              host.sfx(Sfx.reelStop, rate: .8);
              _mood = Face.sad;
              host.sfx(Sfx.aww, volume: .5);
            } else {
              _reelLanded(i);
            }
          }
        case _RS.revive:
          r.wait += dt;
          if (r.wait > .55) {
            r.willRevive = false;
            r
              ..st = _RS.stop
              ..slow = false
              ..from = r.pos
              ..to = r.pos + 1
              ..dur = .28
              ..u = 0;
            host.sfx(Sfx.powerup);
            host.sfx(Sfx.thud);
            host.flash(const Color(0xAAFFE23F), .2);
            host.fx.pop(host.tr('revive', 'REVIVE!!'), Offset(_reelX[i], 180), color: Pal.yellow, size: 30);
            _mood = Face.shocked;
          }
        default:
          break;
      }
    }

    switch (_st) {
      case _St.spinning:
        _idle += dt;
        if (_idle > 3.2) {
          // auto stop the next reel so the ad never stalls
          for (var i = 0; i < 3; i++) {
            if (_reels[i].st == _RS.spin) {
              _stopReel(i);
              break;
            }
          }
        }
      case _St.payout:
        if (_winAt < 0 && _stT > (_lastPay >= 100 ? 1.4 : 1.0)) {
          if (_spin >= 3) {
            _st = _St.over;
            _mood = Face.cry;
            host.sfx(Sfx.jingleLose);
            host.lose();
          } else {
            _st = _St.ready;
            _stT = 0;
            _mood = Face.smug;
          }
        }
      default:
        break;
    }
    if (_winAt > 0 && (host.time >= _winAt || host.timeLeft < .3) && !host.finished) {
      _st = _St.over;
      host.win(stars: _spin == 1 || _coins >= 900 ? 3 : (_spin == 2 ? 2 : 1));
    }
    if (_jackpot && _stT < 3) {
      // coin avalanche from the top
      if (chance(.7)) {
        host.fx.add(Particle(
          pos: Offset(rand(0, 360), -10),
          vel: Offset(rand(-40, 40), rand(100, 300)),
          life: 2.2,
          color: Pal.gold,
          size: rand(7, 11),
          shape: PartShape.coin,
          gravity: 700,
          spin: rand(2, 6),
        ));
      }
    }
  }

  static double _slowEase(double u) {
    // fast, then an agonising crawl with a tiny settle bounce
    if (u < .9) {
      final k = u / .9;
      return (1 - math.pow(1 - k, 3).toDouble()) * 1.02;
    }
    return 1.02 - .02 * M.easeOut((u - .9) / .1);
  }

  @override
  void onTimeUp() => _coins >= _goal ? host.win(stars: 1) : host.lose();

  // ---------------------------------------------------------------- input --

  @override
  void onDown(Offset p) {
    if (_st == _St.ready) {
      if (p.dx > 292 && p.dy > 120 && p.dy < 340) {
        _leverDrag = true;
        _leverY0 = p.dy;
        return;
      }
      _startSpin();
      return;
    }
    if (_st == _St.spinning) {
      for (var i = 0; i < 3; i++) {
        final bx = _reelX[i];
        final onBtn = (p - Offset(bx, _stopY)).distance < 40;
        final onReel = (p.dx - bx).abs() < 40 && p.dy > 176 && p.dy < 400;
        if (onBtn || onReel) {
          _stopReel(i);
          return;
        }
      }
    }
  }

  @override
  void onMove(Offset p) {
    if (_leverDrag) {
      _lever = M.clamp01((p.dy - _leverY0) / 120);
      if (_lever > .85) {
        _leverDrag = false;
        _startSpin();
      }
    }
  }

  @override
  void onUp(Offset p) {
    if (_leverDrag) {
      _leverDrag = false;
      if (_lever > .3) _startSpin();
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (_st == _St.ready) {
      _startSpin();
    } else if (_st == _St.spinning) {
      final idx = key == 'left' ? 0 : (key == 'down' || key == 'up' ? 1 : (key == 'right' ? 2 : -1));
      if (idx >= 0) {
        _stopReel(idx);
        return;
      }
      for (var i = 0; i < 3; i++) {
        if (_reels[i].st == _RS.spin) {
          _stopReel(i);
          return;
        }
      }
    }
  }

  // --------------------------------------------------------------- render --

  @override
  void render(Canvas c) {
    _bg(c);
    _cabinet(c);
    _reelsDraw(c);
    _buttons(c);
    _leverDraw(c);
    _tray(c);
    _topSign(c);
    _hints(c);
    if (_strobe > .01) {
      final col = _rainbow[(_t * 14).floor() % 7];
      c.drawRect(GameHost.bounds, D.fill(col.withValues(alpha: .12 * _strobe)));
      final k = _strobe;
      D.title(c, host.tr('reach', 'REACH!'), Offset(180, 150 + math.sin(_t * 10) * 3), size: 40,
          color: (_t * 8).floor().isEven ? Pal.red : Pal.yellow, scale: (1 + .08 * math.sin(_t * 16)) * k, rotate: -.06);
    }
    if (_st == _St.payout && _payLabel.isNotEmpty && _stT < 2.4) {
      final k = M.easeOutBack(M.clamp01(_stT / .3));
      if (_jackpot) {
        D.rays(c, const Offset(180, 230), 500, const Color(0xFFFFE27A).withValues(alpha: .3), count: 16, t: _t * 2);
      }
      D.title(c, _payLabel, const Offset(180, 232), size: _jackpot ? 50 : 34,
          color: _jackpot ? _rainbow[(_t * 12).floor() % 7] : Pal.yellow, scale: k, rotate: -.05);
    }
  }

  void _bg(Canvas c) {
    D.gradientBg(c, const [Color(0xFF2A0845), Color(0xFF12032A), Color(0xFF050010)]);
    // sweeping spotlights
    for (var i = 0; i < 2; i++) {
      final base = Offset(i == 0 ? -20 : 380, 640);
      final a = -math.pi / 2 + math.sin(_t * .9 + i * 2) * .55;
      final dir = Offset(math.cos(a), math.sin(a));
      final n = Offset(-dir.dy, dir.dx);
      final tip = base + dir * 760;
      c.drawPath(
          Path()
            ..moveTo(base.dx, base.dy)
            ..lineTo(tip.dx + n.dx * 120, tip.dy + n.dy * 120)
            ..lineTo(tip.dx - n.dx * 120, tip.dy - n.dy * 120)
            ..close(),
          D.fill(Color(i == 0 ? 0x16FF5FC8 : 0x1614C9FF)));
    }
    for (var i = 0; i < _lights.length; i++) {
      final x = (i * 67 + 20) % 360.0;
      final y = 60 + (i * 131) % 560.0;
      final a = .08 + .1 * M.wave(_t * .7 + _lights[i]);
      c.drawCircle(Offset(x, y), 10 + (i % 4) * 5, D.fill(D.hsv(i * 40.0, .7, 1, a)));
    }
  }

  void _cabinet(Canvas c) {
    const r = Rect.fromLTWH(16, 100, 286, 402);
    final rr = RRect.fromRectAndCorners(r,
        topLeft: const Radius.circular(60), topRight: const Radius.circular(60), bottomLeft: const Radius.circular(18), bottomRight: const Radius.circular(18));
    c.drawRRect(rr.shift(const Offset(0, 8)), D.fill(const Color(0x88000000)));
    c.drawRRect(rr, Paint()
      ..shader = ui.Gradient.linear(r.topLeft, r.topRight, const [Color(0xFF8C0F2E), Color(0xFFE0284F), Color(0xFFFF5F7E), Color(0xFFB0123A)], const [0, .4, .55, 1]));
    // chrome trim
    c.drawRRect(rr, D.stroke(const Color(0xFFFFD86B), 7));
    c.drawRRect(rr, D.stroke(Pal.ink, 3));
    // neon tube
    final hue = _reach ? (_t * 720) % 360 : 190.0 + math.sin(_t * 2) * 20;
    final inner = rr.deflate(12);
    c.drawRRect(inner, _glow(D.hsv(hue, .8, 1, .9), 7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7);
    c.drawRRect(inner, D.stroke(D.hsv(hue, .3, 1), 2.5));
    // chasing bulbs along the sides
    for (var i = 0; i < 14; i++) {
      for (final x in [26.0, 292.0]) {
        final y = 170 + i * 23.0;
        final on = ((_t * (_reach ? 24 : 9)).floor() + i + (x > 100 ? 7 : 0)) % 4 < 2;
        final col = _reach ? _rainbow[(i + (_t * 10).floor()) % 7] : Pal.yellow;
        if (on) c.drawCircle(Offset(x, y), 7, _glow(col.withValues(alpha: .8), 5));
        c.drawCircle(Offset(x, y), 3.6, D.fill(on ? col : const Color(0xFF6B2A10)));
      }
    }
  }

  void _topSign(Canvas c) {
    // jackpot marquee
    const r = Rect.fromLTWH(34, 44, 292, 50);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(14));
    c.drawRRect(rr, D.fill(const Color(0xF0180626)));
    final col = _jackpot ? _rainbow[(_t * 12).floor() % 7] : const Color(0xFFFF3BD2);
    c.drawRRect(rr, _glow(col, 8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6);
    c.drawRRect(rr, D.stroke(Pal.white, 2));
    final blink = (_t * 3).floor().isEven;
    D.text(c, host.tr('jackpot', 'JACKPOT'), const Offset(116, 69), size: 22, color: blink ? Pal.yellow : const Color(0xFFFF9EE0),
        stroke: const Color(0xFF7A0F4A), strokeWidth: 5, italic: true);
    D.text(c, '777', const Offset(262, 69), size: 30, color: Pal.red, stroke: Pal.yellow, strokeWidth: 5, italic: true);
    // mascot
    const mc = Offset(159, 138);
    c.drawCircle(mc, 36, _glow(const Color(0x88FFE23F), 12));
    c.drawCircle(mc, 30, Paint()..shader = ui.Gradient.radial(mc + const Offset(-8, -10), 40, const [Color(0xFFFFF6B0), Color(0xFFFFC53D), Color(0xFFD08A00)], const [0, .5, 1]));
    c.drawCircle(mc, 30, D.stroke(Pal.ink, 3.5));
    final bounce = _mood == Face.love ? math.sin(_t * 18).abs() * 4 : 0.0;
    D.face(c, mc + Offset(0, 2 - bounce), 26, _mood, look: Offset(math.sin(_t * 1.3) * .5, .3));
    // little 7 wings
    for (final sx in [-1.0, 1.0]) {
      D.text(c, '7', mc + Offset(sx * 70, 0), size: 34, color: Pal.red, stroke: Pal.yellow, strokeWidth: 5, italic: true);
      c.drawCircle(mc + Offset(sx * 105, 0), 5, D.fill((_t * 4).floor().isEven ? Pal.yellow : Pal.pink));
    }
  }

  void _reelsDraw(Canvas c) {
    const win = Rect.fromLTWH(32, 176, 254, 222);
    c.drawRRect(RRect.fromRectAndRadius(win.inflate(6), const Radius.circular(14)), D.fill(const Color(0xFF1A0A20)));
    c.drawRRect(RRect.fromRectAndRadius(win.inflate(6), const Radius.circular(14)), D.stroke(Pal.ink, 3));
    for (var i = 0; i < 3; i++) {
      final r = _reels[i];
      final x = _reelX[i];
      final rect = Rect.fromCenter(center: Offset(x, 287), width: 78, height: 222);
      c.save();
      c.clipRect(rect);
      c.drawRect(rect, Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter,
            const [Color(0xFF6E6A80), Color(0xFFF4F2FF), Color(0xFFFFFFFF), Color(0xFFF4F2FF), Color(0xFF6E6A80)], const [0, .3, .5, .7, 1]));
      final blur = r.st == _RS.spin ? M.clamp01((r.speed - 4) / 10) : (r.st == _RS.stop && !r.slow ? M.clamp01(1 - r.u * 2.5) * .8 : 0.0);
      final base = r.pos.floor();
      for (var k = -3; k <= 3; k++) {
        final idx = base + k;
        final off = (r.pos - idx) * _symH; // positive = below payline
        final th = off / 125;
        if (th.abs() > 1.45) continue;
        final y = _payY + math.sin(th) * 125;
        final sy = math.cos(th);
        _symbol(c, Offset(x, y), _symAt(idx), sy, blur, r.st == _RS.done && idx == r.to.round() && _lineFlash > 0 ? _lineFlash : 0);
      }
      if (blur > .3) {
        final p = D.stroke(Color.fromRGBO(255, 255, 255, .5 * blur), 2);
        for (var k = 0; k < 5; k++) {
          final lx = x - 30 + k * 15.0;
          final off = ((_t * 900 + k * 60) % 260) + 150;
          c.drawLine(Offset(lx, off), Offset(lx, off + 40), p);
        }
      }
      // shading for the cylinder look
      c.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, 50), Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.topCenter + const Offset(0, 50), const [Color(0xAA000000), Color(0x00000000)]));
      c.drawRect(Rect.fromLTWH(rect.left, rect.bottom - 50, rect.width, 50), Paint()
        ..shader = ui.Gradient.linear(rect.bottomCenter, rect.bottomCenter - const Offset(0, 50), const [Color(0xAA000000), Color(0x00000000)]));
      if (r.glow > .01) {
        c.drawRect(rect, D.fill(Color.fromRGBO(255, 240, 150, .35 * r.glow)));
      }
      // reach: last reel gets a fiery border
      if (_reach && r.st != _RS.done) {
        c.drawRect(rect.deflate(3), D.stroke(_rainbow[(_t * 16).floor() % 7], 6));
      }
      c.restore();
      c.drawRect(rect, D.stroke(Pal.ink, 3));
    }
    // payline
    final pk = _lineFlash > 0 && _lastPay > 0 ? (0.5 + 0.5 * math.sin(_t * 30)) : 0.0;
    final lc = Color.lerp(const Color(0xCCFF2040), Pal.yellow, pk)!;
    c.drawLine(const Offset(30, _payY), const Offset(288, _payY), _glow(lc, 4)..strokeWidth = 5);
    c.drawLine(const Offset(30, _payY), const Offset(288, _payY), D.stroke(lc, 2));
    for (final sx in [24.0, 294.0]) {
      final d = sx < 100 ? 1.0 : -1.0;
      c.drawPath(
          Path()
            ..moveTo(sx - d * 6, _payY - 10)
            ..lineTo(sx + d * 8, _payY)
            ..lineTo(sx - d * 6, _payY + 10)
            ..close(),
          D.fill(Pal.yellow));
    }
  }

  void _symbol(Canvas c, Offset o, int s, double sy, double blur, double flash) {
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(1 + flash * .15 * math.sin(_t * 20).abs(), sy * (1 + blur * .5));
    if (blur > 0) c.saveLayer(const Rect.fromLTWH(-40, -40, 80, 80), Paint()..color = Color.fromRGBO(0, 0, 0, 1 - blur * .45));
    switch (s) {
      case 0:
        D.text(c, '7', const Offset(0, 3), size: 60, color: Pal.ink, stroke: Pal.ink, strokeWidth: 14, italic: true);
        D.text(c, '7', Offset.zero, size: 60, color: const Color(0xFFFF2D3F), stroke: Pal.yellow, strokeWidth: 7, italic: true);
      case 1:
        c.drawPath(
            Path()
              ..moveTo(-10, 6)
              ..quadraticBezierTo(-4, -14, 6, -22)
              ..moveTo(12, 8)
              ..quadraticBezierTo(10, -10, 6, -22),
            D.stroke(const Color(0xFF3F7A1F), 3.5)..style = PaintingStyle.stroke);
        c.drawOval(const Rect.fromLTWH(6, -30, 20, 11), D.fill(Pal.lime));
        for (final p in const [Offset(-10, 12), Offset(12, 14)]) {
          c.drawCircle(p, 13, D.fill(const Color(0xFFE0102F)));
          c.drawCircle(p, 13, D.stroke(Pal.ink, 3));
          c.drawCircle(p + const Offset(-4, -5), 3.5, D.fill(const Color(0xCCFFFFFF)));
        }
      case 2:
        final bell = Path()
          ..moveTo(-24, 14)
          ..quadraticBezierTo(-18, 8, -17, -4)
          ..quadraticBezierTo(-16, -24, 0, -24)
          ..quadraticBezierTo(16, -24, 17, -4)
          ..quadraticBezierTo(18, 8, 24, 14)
          ..close();
        c.drawCircle(const Offset(0, 18), 6, D.fill(const Color(0xFFB07000)));
        c.drawPath(bell, Paint()..shader = ui.Gradient.linear(const Offset(-24, 0), const Offset(24, 0), const [Color(0xFFFFF09A), Color(0xFFFFC53D), Color(0xFFB07000)], const [0, .5, 1]));
        c.drawPath(bell, D.stroke(Pal.ink, 3));
        c.drawCircle(const Offset(0, -27), 4, D.fill(Pal.gold));
        c.drawLine(const Offset(-9, -14), const Offset(-11, 2), D.stroke(const Color(0xAAFFFFFF), 4));
      case 3:
        D.rrect(c, const Rect.fromLTWH(-30, -16, 60, 32), 6, Pal.ink, border: Pal.gold, borderWidth: 3);
        D.text(c, 'BAR', Offset.zero, size: 19, color: Pal.white, letterSpacing: 1);
      default:
        D.star(c, Offset.zero, 26, Pal.sky, border: Pal.ink);
        c.drawCircle(const Offset(-6, -8), 4, D.fill(const Color(0xAAFFFFFF)));
    }
    if (blur > 0) c.restore();
    c.restore();
  }

  void _buttons(Canvas c) {
    for (var i = 0; i < 3; i++) {
      final r = _reels[i];
      final active = r.st == _RS.spin && r.speed > 3;
      final o = Offset(_reelX[i], _stopY);
      final depth = 6 - r.press * 5;
      if (active) {
        final pulse = .5 + .5 * M.wave(_t, _reach ? 5 : 2.5);
        c.drawCircle(o, 38, _glow((_reach ? Pal.red : Pal.yellow).withValues(alpha: .7 * pulse), 10));
      }
      c.drawCircle(o + const Offset(0, 6), 29, D.fill(const Color(0xFF5A0A1E)));
      final col = active ? const Color(0xFFFF3B5C) : const Color(0xFF6E5A64);
      c.drawCircle(o + Offset(0, 6 - depth), 29, Paint()
        ..shader = ui.Gradient.radial(o + Offset(-8, -10 + 6 - depth), 34, [Color.lerp(col, Pal.white, .5)!, col, Color.lerp(col, Pal.ink, .4)!], const [0, .5, 1]));
      c.drawCircle(o + Offset(0, 6 - depth), 29, D.stroke(Pal.ink, 3));
      D.text(c, host.tr('stop', 'STOP'), o + Offset(0, 6 - depth), size: 14, color: active ? Pal.white : const Color(0xFFBBB0C0),
          stroke: Pal.ink, strokeWidth: 3, maxWidth: 54);
    }
    // spin lamps
    for (var i = 0; i < 3; i++) {
      final used = i < _spin;
      final o = Offset(130 + i * 29.0, 485);
      if (!used) c.drawCircle(o, 10, _glow(const Color(0x8852E05A), 5));
      c.drawCircle(o, 7, D.fill(used ? const Color(0xFF3A2A40) : Pal.lime));
      c.drawCircle(o, 7, D.stroke(Pal.ink, 2));
    }
  }

  void _leverDraw(Canvas c) {
    const base = Offset(316, 318);
    final a = -math.pi / 2 + .25 - _lever * 2.3;
    final len = 138.0;
    final knob = base + Offset(math.cos(a), math.sin(a)) * len * (0.75 + .25 * (1 - _lever).abs());
    D.rrect(c, Rect.fromCenter(center: base + const Offset(-6, 0), width: 22, height: 60), 8, const Color(0xFF8E93A8), border: Pal.ink, borderWidth: 3);
    c.drawLine(base, knob, D.stroke(Pal.ink, 11));
    c.drawLine(base, knob, D.stroke(const Color(0xFFE6E8F0), 6));
    c.drawCircle(knob, 21, _glow(const Color(0x88FF3B5C), 8));
    c.drawCircle(knob, 17, Paint()..shader = ui.Gradient.radial(knob + const Offset(-5, -6), 22, const [Color(0xFFFFB0BE), Color(0xFFFF2D3F), Color(0xFF8C0020)], const [0, .5, 1]));
    c.drawCircle(knob, 17, D.stroke(Pal.ink, 3));
    c.drawCircle(base, 8, D.fill(Pal.ink));
  }

  void _tray(Canvas c) {
    const r = Rect.fromLTWH(20, 508, 320, 126);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(20));
    c.drawRRect(rr, Paint()..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [Color(0xFF2B1238), Color(0xFF12061A)]));
    c.drawRRect(rr, D.stroke(const Color(0xFFFFD86B), 4));
    // coin pile
    final n = math.min(_pile.length, (_coinsDisp / 10).floor());
    for (var i = 0; i < n; i++) {
      final p = _pile[_pile.length - 1 - i];
      c.save();
      c.translate(p.dx, p.dy);
      c.scale(1, .5);
      c.drawCircle(Offset.zero, 12, D.fill(const Color(0xFFB8860B)));
      c.drawCircle(const Offset(0, -3), 12, D.fill(Pal.gold));
      c.drawCircle(const Offset(0, -3), 8, D.stroke(const Color(0xFFE0A019), 2));
      c.restore();
    }
    // counter
    const bar = Rect.fromLTWH(44, 522, 272, 16);
    D.bar(c, bar, _coinsDisp / _goal, _coins >= _goal ? _rainbow[(_t * 10).floor() % 7] : Pal.gold, border: Pal.ink);
    D.coin(c, const Offset(52, 562), 13, spin: _t * .8);
    D.text(c, '${_coinsDisp.round()}', const Offset(74, 562), size: 28, color: Pal.yellow, stroke: Pal.ink, anchor: Alignment.centerLeft);
    D.text(c, '/ $_goal', const Offset(304, 564), size: 18, color: const Color(0xFFFFD6F0), stroke: Pal.ink, anchor: Alignment.centerRight);
  }

  void _hints(Canvas c) {
    if (_st == _St.ready && !host.finished) {
      final k = .5 + .5 * M.wave(_t, 2);
      if (_spin == 0 || _stT > 1.0) {
        D.hand(c, Offset(328, 200 + k * 40), _t);
        D.title(c, host.tr('spin', 'SPIN!'), const Offset(159, 232), size: 38, scale: 1 + .06 * k);
      }
    }
    if (_st == _St.spinning && _spin == 1 && _stT < 2.5 && _stT > .5) {
      for (var i = 0; i < 3; i++) {
        if (_reels[i].st == _RS.spin) {
          D.hand(c, Offset(_reelX[i], _stopY + 6), _t);
          break;
        }
      }
    }
  }
}
