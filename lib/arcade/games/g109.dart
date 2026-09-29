import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.109 10x Mega Gacha — the flagship over-the-top gacha parody.
///
/// Crank the giant capsule machine (drag in circles around the handle), ten
/// capsules pour into the tray with rarity color hints (silver / gold /
/// RAINBOW), then tap each capsule to open it. Rainbow capsules trigger the
/// full SSR cutscene; one gold capsule secretly "upgrades" to rainbow.
/// Open all ten before time runs out to complete the collection.

const _rainbow = <Color>[
  Color(0xFFFF3B5C),
  Color(0xFFFF8A1F),
  Color(0xFFFFE23F),
  Color(0xFF52E05A),
  Color(0xFF2ED8FF),
  Color(0xFF6A5BFF),
  Color(0xFFE04DFF),
  Color(0xFFFF3B5C),
];
final _rainbowStops = List<double>.generate(8, (i) => i / 7);

Paint _glow(Color c, double blur) => Paint()
  ..color = c
  ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur);

ui.Shader _rainbowSweep(Offset center, double rot) => ui.Gradient.sweep(
    center, _rainbow, _rainbowStops, ui.TileMode.clamp, 0, math.pi * 2, _rotMatrix(center, rot));

Float64List _rotMatrix(Offset o, double a) {
  final cs = math.cos(a), sn = math.sin(a);
  // translate(o) * rotate(a) * translate(-o), column-major 4x4
  return Float64List.fromList([
    cs, sn, 0, 0, //
    -sn, cs, 0, 0, //
    0, 0, 1, 0, //
    o.dx - cs * o.dx + sn * o.dy, o.dy - sn * o.dx - cs * o.dy, 0, 1,
  ]);
}

/// Draws [s] with a rainbow gradient fill and a thick ink outline.
void _rainbowText(Canvas c, String s, Offset pos, double size, double shift, {double sw = 0}) {
  final w = sw > 0 ? sw : size * .3;
  D.text(c, s, pos + Offset(0, size * .1), size: size, color: Pal.ink, stroke: Pal.ink, strokeWidth: w * 1.2, italic: true);
  D.text(c, s, pos, size: size, color: Pal.white, stroke: Pal.ink, strokeWidth: w, italic: true);
  final r = Rect.fromCenter(center: pos, width: size * s.length * 1.1 + 40, height: size * 1.6);
  c.saveLayer(r, Paint());
  D.text(c, s, pos, size: size, color: Pal.white, italic: true);
  c.drawRect(
      r,
      Paint()
        ..blendMode = BlendMode.srcIn
        ..shader = ui.Gradient.linear(r.centerLeft + Offset(shift, -20), r.centerRight + Offset(shift, 20),
            _rainbow, _rainbowStops, ui.TileMode.mirror));
  // glossy highlight on the upper half
  c.drawRect(Rect.fromLTRB(r.left, r.top, r.right, pos.dy - size * .05),
      Paint()
        ..blendMode = BlendMode.srcATop
        ..color = const Color(0x55FFFFFF));
  c.restore();
}

enum _Ph { crank, burst, pour, open, done }

class _Cap {
  _Cap(this.rarity, this.promo, this.charIdx);
  int rarity; // 0 R silver, 1 SR gold, 2 SSR rainbow
  final bool promo;
  final int charIdx;
  Offset pos = Offset.zero;
  Offset vel = Offset.zero;
  double rot = 0;
  bool out = false;
  bool opened = false;
  double openT = -1;
  double promoT = -1;
  double squash = 0;
}

class _Card {
  _Card(this.rarity, this.charIdx, this.from, this.slot, this.fromW);
  final int rarity, charIdx, slot;
  final Offset from;
  final double fromW;
  double t = 0;
  double bounce = 0;
}

class G109 extends MiniGame {
  static const _goal = math.pi * 4; // two full turns of the handle
  static const _floor = 604.0;
  static const _capR = 23.0;
  static const _cardW = 58.0;

  _Ph _ph = _Ph.crank;
  double _t = 0, _phT = 0;

  // crank
  double _crank = 0, _crankAcc = 0, _clickAcc = 0;
  double? _lastAng;
  bool _dragging = false;
  double _machShake = 0;
  int _tier = 0; // hint glow tier during the burst
  double _machK = 0; // 0 big, 1 small at top, 2 gone

  final _caps = <_Cap>[];
  final _cards = <_Card>[];
  final _domeCaps = <Offset>[];
  final _domeCols = <Color>[];
  final _bokeh = <List<double>>[];
  int _poured = 0;
  double _pourTimer = 0;
  int _nextSlot = 0;

  _Cap? _ssr;
  double _ssrT = 0;
  int _ssrEvent = 0;
  double _ovl = 0;
  int _combo = 0;
  double _lastOpen = -9;

  int _ssrCount = 0;

  @override
  Color get backdrop => const Color(0xFF12051F);

  @override
  void init() {
    final rar = <int>[2, 1, 1, 1, 0, 0, 0, 0, 0, 0]..shuffle(rng);
    final chars = List<int>.generate(10, (i) => i)..shuffle(rng);
    var promoGiven = false;
    for (var i = 0; i < 10; i++) {
      final promo = rar[i] == 1 && !promoGiven;
      if (promo) promoGiven = true;
      _caps.add(_Cap(rar[i], promo, chars[i]));
    }
    for (var i = 0; i < 26; i++) {
      final a = rand(0, math.pi * 2);
      final d = math.sqrt(rng.nextDouble()) * 80;
      var p = Offset(math.cos(a) * d, math.sin(a) * d * .8 + 18);
      if (p.dy < -40) p = Offset(p.dx, -p.dy * .5);
      _domeCaps.add(p);
      _domeCols.add(pick(const [Pal.red, Pal.sky, Pal.yellow, Pal.lime, Pal.pink, Pal.purple, Pal.orange, Pal.teal]));
    }
    for (var i = 0; i < 26; i++) {
      _bokeh.add([rand(0, 360), rand(40, 640), rand(4, 22), rand(0, 6.28), rand(0, 360)]);
    }
  }

  // ------------------------------------------------------------ geometry --

  Offset get _machCenter {
    if (_machK <= 1) return Offset.lerp(const Offset(180, 382), const Offset(180, 172), M.easeInOut(_machK))!;
    return Offset.lerp(const Offset(180, 172), const Offset(180, -190), M.easeInOut(_machK - 1))!;
  }

  double get _machScale => M.lerp(1, .5, M.easeInOut(M.clamp01(_machK)));
  Offset get _handle => _machCenter + const Offset(0, 55) * _machScale;
  Offset get _chute => _machCenter + const Offset(0, 128) * _machScale;

  static Offset _slotPos(int i) => Offset(19 + 29 + (i % 5) * 66.0, 145 + (i ~/ 5) * 92.0);

  // --------------------------------------------------------------- update --

  static const _auto = true;
  double _autoT = 0;

  @override
  void update(double dt) {
    _t += dt;
    _phT += dt;
    if (_auto && !host.finished) {
      _autoT += dt;
      if (_ph == _Ph.crank) _turn(dt * 9);
      if (_autoT > .45) {
        _autoT = 0;
        onKey('action', true);
      }
    }
    _machShake = M.approach(_machShake, 0, 5, dt);
    switch (_ph) {
      case _Ph.crank:
        if (_crankAcc >= _goal) {
          _ph = _Ph.burst;
          _phT = 0;
          host.sfx(Sfx.drumroll);
          host.sfx(Sfx.shake);
          _tier = 0;
        }
      case _Ph.burst:
        _machShake = 1;
        if (_tier == 0 && _phT > .45) {
          _tier = 1;
          host.sfx(Sfx.rarityUp);
          host.flash(const Color(0x88FFC53D), .15);
          host.shake(6);
          host.fx.pop(host.tr('gold', 'GOLD!'), _machCenter + const Offset(0, -150), color: Pal.gold, size: 30);
        }
        if (_tier == 1 && _phT > 1.0) {
          _tier = 2;
          host.sfx(Sfx.rarityUp, rate: 1.35);
          host.sfx(Sfx.magic);
          host.flash(const Color(0xCCFFFFFF), .25);
          host.shake(12, .4);
          host.punch(.06);
          host.fx.burst(_machCenter + const Offset(0, -120), Pal.white, count: 40, speed: 420, colors: _rainbow, shape: PartShape.star, gravity: 200);
          host.fx.ring(_machCenter + const Offset(0, -120), Pal.white, size: 200, life: .5);
        }
        if (_phT > 1.55) {
          _ph = _Ph.pour;
          _phT = 0;
          host.sfx(Sfx.whoosh);
        }
      case _Ph.pour:
        _machK = math.min(1, _machK + dt * 2.4);
        if (_machK >= 1 && _poured < 10) {
          _pourTimer -= dt;
          if (_pourTimer <= 0) {
            _pourTimer = .12;
            final cp = _caps[_poured];
            cp
              ..out = true
              ..pos = _chute + const Offset(0, 10)
              ..vel = Offset(rand(-230, 230), rand(-120, 60));
            host.sfx(Sfx.pop, rate: .9 + _poured * .06, volume: .8);
            host.fx.sparkle(_chute, count: 4, color: _capColor(cp.rarity));
            _machShake = .6;
            _poured++;
          }
        }
        if (_poured >= 10 && _phT > 2.2) {
          _ph = _Ph.open;
          _phT = 0;
          host.sfx(Sfx.whoosh, rate: .8);
        }
      case _Ph.open:
        _machK = math.min(2, _machK + dt * 2);
        if (_ssr == null && _caps.every((c) => c.opened) && _cards.every((c) => c.t >= 1)) {
          _ph = _Ph.done;
          _phT = 0;

          host.sfx(Sfx.fanfare);
          host.sfx(Sfx.cheer, volume: .6);
          host.fx.confetti(count: 110);
          host.shake(6);
          host.win(stars: host.time < 13.5 ? 3 : (host.time < 17 ? 2 : 1));
        }
      case _Ph.done:
        if ((_phT * 3).floor() != ((_phT - dt) * 3).floor()) {
          host.fx.coins(Offset(rand(40, 320), 640), count: 8, speed: 700);
        }
    }

    _physics(dt);
    _updatePromo(dt);
    _updateSsr(dt);
    _ovl = M.approach(_ovl, _ssr != null ? 1 : 0, _ssr != null ? 8 : 5, dt);

    for (final cd in _cards) {
      if (cd.t < 1) {
        cd.t = math.min(1, cd.t + dt / .45);
        if (cd.t >= 1) {
          cd.bounce = 1;
          host.sfx(Sfx.land, volume: .5, rate: 1.3);
          host.fx.sparkle(_slotPos(cd.slot), count: cd.rarity == 2 ? 14 : 5, radius: 30, color: _capColor(cd.rarity));
        }
      }
      cd.bounce = M.approach(cd.bounce, 0, 6, dt);
    }
  }

  void _physics(double dt) {
    for (final cp in _caps) {
      if (!cp.out) continue;
      if (cp.openT >= 0) cp.openT += dt;
      if (cp.opened) continue;
      cp.vel = Offset(cp.vel.dx, cp.vel.dy + 1500 * dt);
      cp.pos += cp.vel * dt;
      cp.rot += cp.vel.dx / _capR * dt;
      cp.squash = M.approach(cp.squash, 0, 10, dt);
      if (cp.pos.dy > _floor - _capR) {
        cp.pos = Offset(cp.pos.dx, _floor - _capR);
        if (cp.vel.dy > 160) {
          cp.squash = math.min(1, cp.vel.dy / 900);
          host.sfx(Sfx.bounce, volume: .25, rate: 1.4);
        }
        cp.vel = Offset(cp.vel.dx * .86, -cp.vel.dy * .42);
        if (cp.vel.dy.abs() < 40) cp.vel = Offset(cp.vel.dx, 0);
      }
      if (cp.pos.dx < 22 + _capR) {
        cp.pos = Offset(22 + _capR, cp.pos.dy);
        cp.vel = Offset(cp.vel.dx.abs() * .6, cp.vel.dy);
      }
      if (cp.pos.dx > 338 - _capR) {
        cp.pos = Offset(338 - _capR, cp.pos.dy);
        cp.vel = Offset(-cp.vel.dx.abs() * .6, cp.vel.dy);
      }
    }
    for (var i = 0; i < _caps.length; i++) {
      final a = _caps[i];
      if (!a.out || a.opened) continue;
      for (var j = i + 1; j < _caps.length; j++) {
        final b = _caps[j];
        if (!b.out || b.opened) continue;
        final d = b.pos - a.pos;
        final dist = d.distance;
        if (dist < _capR * 2 && dist > .01) {
          final n = d / dist;
          final push = (_capR * 2 - dist) / 2;
          a.pos -= n * push;
          b.pos += n * push;
          final rel = (b.vel - a.vel).dx * n.dx + (b.vel - a.vel).dy * n.dy;
          if (rel < 0) {
            a.vel += n * rel * .6;
            b.vel -= n * rel * .6;
          }
        }
      }
    }
  }

  void _updatePromo(double dt) {
    for (final cp in _caps) {
      if (cp.promoT < 0) continue;
      final before = cp.promoT;
      cp.promoT += dt;
      _machShake = 0;
      if (before < .25 && cp.promoT >= .25) host.sfx(Sfx.shake, rate: 1.2);
      if (before < .8 && cp.promoT >= .8) {
        cp.rarity = 2;
        host.sfx(Sfx.rarityUp, rate: 1.5);
        host.sfx(Sfx.glass, volume: .5, rate: 1.4);
        host.flash(const Color(0xDDFFFFFF), .22);
        host.shake(10);
        host.hitStop(.08);
        host.fx.burst(cp.pos, Pal.white, count: 30, speed: 300, colors: _rainbow, shape: PartShape.star, gravity: 0);
        host.fx.pop(host.tr('upgrade', 'UPGRADE!?'), cp.pos + const Offset(0, -60), color: Pal.yellow, size: 30, life: 1.1);
      }
      if (cp.promoT >= 1.35) {
        cp.promoT = -1;
        _startSsr(cp);
      }
    }
  }

  void _startSsr(_Cap cp) {
    _ssr = cp;
    _ssrT = 0;
    _ssrEvent = 0;
    cp.opened = true;
    host.sfx(Sfx.drumroll);
    host.setMusicVolume(.25);
  }

  void _updateSsr(double dt) {
    final s = _ssr;
    if (s == null) return;
    final before = _ssrT;
    _ssrT += dt;
    bool cross(double at) => before < at && _ssrT >= at;
    for (var i = 0; i < 3; i++) {
      final at = .15 + i * .28;
      if (cross(at)) {
        host.sfx(Sfx.thud, rate: .8 + i * .15);
        host.sfx(Sfx.rarityUp, volume: .5, rate: 1 + i * .2);
        host.shake(3.0 + i * 3);
        host.fx.ring(const Offset(180, 330), _rainbow[i * 2], size: 120 + i * 40.0, life: .35);
      }
    }
    if (cross(1.0)) {
      _ssrCount++;
      host.flash(Pal.white, .35);
      host.shake(16, .6);
      host.hitStop(.12);
      host.punch(.08);
      host.sfx(Sfx.ssr);
      host.sfx(Sfx.explode, volume: .7);
      host.fx.burst(const Offset(180, 330), Pal.white, count: 70, speed: 620, size: 8, colors: _rainbow, gravity: 250, life: 1.1);
      host.fx.burst(const Offset(180, 330), Pal.white, count: 24, speed: 380, size: 9, shape: PartShape.star, colors: _rainbow, gravity: 0, life: 1.0);
      host.fx.ring(const Offset(180, 330), Pal.white, size: 320, life: .6);
      host.fx.coins(const Offset(180, 420), count: 30, speed: 700);
    }
    if (cross(1.25)) {
      host.sfx(Sfx.stamp, rate: .8);
      host.shake(8);
      host.fx.confetti(count: 60);
    }
    for (var i = 0; i < 5; i++) {
      if (cross(1.45 + i * .11)) {
        host.sfx(Sfx.star, rate: 1 + i * .12);
        host.fx.sparkle(Offset(100 + i * 40.0, 506), count: 5, radius: 14, color: Pal.yellow);
      }
    }
    if (_ssrT >= 2.75 && _ssrEvent == 0) {
      _ssrEvent = 1;
      final cd = _Card(2, s.charIdx, const Offset(180, 340), _nextSlot++, 190);
      _cards.add(cd);
      host.sfx(Sfx.whoosh, rate: 1.2);
      _ssr = null;
      host.setMusicVolume(1);
    }
  }

  // ---------------------------------------------------------------- input --

  double _angTo(Offset p) => math.atan2(p.dy - _handle.dy, p.dx - _handle.dx);

  @override
  void onDown(Offset p) {
    switch (_ph) {
      case _Ph.crank:
        _dragging = true;
        _lastAng = _angTo(p);
        if ((p - _handle).distance < 70) _turn(math.pi / 5); // taps nudge the handle too
      case _Ph.open:
        if (_ssr != null) {
          if (_ssrT > 1.9 && _ssrT < 2.7) _ssrT = 2.7;
          return;
        }
        if (_caps.any((c) => c.promoT >= 0)) return;
        _Cap? best;
        var bd = _capR + 16;
        for (final cp in _caps) {
          if (!cp.out || cp.opened) continue;
          final d = (cp.pos - p).distance;
          if (d < bd) {
            bd = d;
            best = cp;
          }
        }
        if (best != null) _open(best);
      default:
        break;
    }
  }

  @override
  void onMove(Offset p) {
    if (_ph != _Ph.crank || !_dragging) return;
    final a = _angTo(p);
    if ((p - _handle).distance > 14 && _lastAng != null) {
      var d = a - _lastAng!;
      while (d > math.pi) {
        d -= math.pi * 2;
      }
      while (d < -math.pi) {
        d += math.pi * 2;
      }
      if (d.abs() < 1.4) _turn(d);
    }
    _lastAng = a;
  }

  @override
  void onUp(Offset p) {
    _dragging = false;
    _lastAng = null;
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (_ph == _Ph.crank) {
      _turn(math.pi / 4);
    } else if (_ph == _Ph.open) {
      if (_ssr != null) {
        if (_ssrT > 1.9 && _ssrT < 2.7) _ssrT = 2.7;
        return;
      }
      for (final cp in _caps) {
        if (cp.out && !cp.opened && cp.promoT < 0) {
          if (_caps.any((c) => c.promoT >= 0)) return;
          _open(cp);
          return;
        }
      }
    }
  }

  void _turn(double d) {
    if (_ph != _Ph.crank) return;
    _crank += d;
    _crankAcc += d.abs();
    _clickAcc += d.abs();
    _machShake = math.max(_machShake, .35);
    if (_clickAcc > math.pi / 3) {
      _clickAcc = 0;
      final k = _crankAcc / _goal;
      host.sfx(Sfx.click, rate: .8 + k * .8);
      host.fx.sparkle(_handle, count: 3, radius: 40, color: Pal.yellow);
      if (k > .5) host.shake(1.5 + k * 2);
    }
  }

  void _open(_Cap cp) {
    final now = host.time;
    _combo = now - _lastOpen < 1.0 ? _combo + 1 : 1;
    _lastOpen = now;
    if (cp.promo) {
      cp.promoT = 0;
      host.sfx(Sfx.rarityUp, rate: 1.0);
      host.shake(4);
      return;
    }
    if (cp.rarity == 2) {
      _startSsr(cp);
      return;
    }
    cp
      ..opened = true
      ..openT = 0;
    _cards.add(_Card(cp.rarity, cp.charIdx, cp.pos, _nextSlot++, 34));
    final rate = 1 + math.min(_combo, 8) * .07;
    host.sfx(Sfx.pop, rate: rate);
    if (cp.rarity == 1) {
      host.sfx(Sfx.rarityUp, rate: 1.1);
      host.sfx(Sfx.coins, volume: .6);
      host.shake(5);
      host.flash(const Color(0x55FFC53D), .12);
      host.fx.burst(cp.pos, Pal.gold, count: 26, speed: 320, shape: PartShape.star, gravity: 300);
      host.fx.coins(cp.pos, count: 10);
      host.fx.pop('SR!', cp.pos + const Offset(0, -40), color: Pal.gold, size: 34);
    } else {
      host.sfx(Sfx.sparkle, volume: .5, rate: rate);
      host.fx.burst(cp.pos, const Color(0xFFDDE6FF), count: 14, speed: 220, gravity: 300);
      host.fx.pop('R', cp.pos + const Offset(0, -36), color: const Color(0xFFDDE6FF), size: 26);
    }
    host.fx.ring(cp.pos, Pal.white, size: 50);
    if (_combo >= 3) {
      host.fx.pop('${host.tr('combo', 'COMBO')} x$_combo', const Offset(180, 330), color: Pal.pink, size: 24);
    }
  }

  static Color _capColor(int r) => r == 2 ? Pal.pink : (r == 1 ? Pal.gold : const Color(0xFFDDE6FF));

  // --------------------------------------------------------------- render --

  @override
  void render(Canvas c) {
    _background(c);
    if (_machK < 2) _drawMachine(c);
    if (_ph == _Ph.open || _ph == _Ph.done) _drawSlots(c);
    if (_ph.index >= _Ph.pour.index) _drawTray(c);
    for (final cp in _caps) {
      if (!cp.out) continue;
      if (cp.opened) {
        if (cp.openT >= 0 && cp.openT < .5) _drawCap(c, cp.pos, _capR, cp.rarity, cp.rot, open: cp.openT / .5);
        continue;
      }
      var pos = cp.pos;
      var r = _capR;
      if (cp.promoT >= 0) {
        final k = cp.promoT;
        pos += Offset(math.sin(k * 70) * (2 + k * 7), math.cos(k * 53) * k * 3);
        r *= 1 + k * .25;
        final beams = M.clamp01(k / .8);
        D.rays(c, pos, 90 * beams + 20, (cp.rarity == 2 ? Pal.white : Pal.gold).withValues(alpha: .35), count: 10, t: _t * 3);
      }
      _drawCap(c, pos, r, cp.rarity, cp.rot, squash: cp.squash);
    }
    _drawCards(c);
    if (_ovl > .01 || _ssr != null) _drawSsr(c);
    _banner(c);
    _hints(c);
    if (_ph == _Ph.done) _drawDone(c);
  }

  void _background(Canvas c) {
    D.gradientBg(c, const [Color(0xFF1A0633), Color(0xFF3A0A5C), Color(0xFF14041F)]);
    D.rays(c, const Offset(180, 330), 700, const Color(0x10FF5FC8), count: 16, t: _t * .15);
    for (final b in _bokeh) {
      final a = .10 + .12 * M.wave(_t * .6 + b[3]);
      c.drawCircle(Offset(b[0], b[1] + math.sin(_t * .4 + b[3]) * 8), b[2], D.fill(D.hsv(b[4], .6, 1, a)));
    }
    // neon floor grid
    final gp = D.stroke(const Color(0x55FF5FC8), 1.5);
    for (var i = 0; i < 7; i++) {
      final y = 560 + i * i * 3.0 + ((_t * 12) % 6);
      c.drawLine(Offset(0, y), Offset(360, y), gp);
    }
    for (var i = -6; i <= 6; i++) {
      c.drawLine(Offset(180 + i * 20.0, 556), Offset(180 + i * 70.0, 640), gp);
    }
  }

  void _banner(Canvas c) {
    const r = Rect.fromLTWH(10, 44, 340, 38);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(19));
    c.drawRRect(rr, D.fill(const Color(0xEE1B0630)));
    final hue = (_t * 90) % 360;
    c.drawRRect(rr, _glow(D.hsv(hue, .8, 1, .9), 6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6);
    c.drawRRect(rr, D.stroke(D.hsv(hue, .35, 1), 2.5));
    c.save();
    c.clipRRect(rr);
    final s = '★ ${host.tr('limited', 'LIMITED')} ★  SSR 0.0001%  ${host.tr('rate_up', 'RATE UP!!')}  ';
    const gap = 30.0;
    final size = D.text(c, s, const Offset(-2000, -2000), size: 17, anchor: Alignment.centerLeft);
    final w = size.width + gap;
    var x = 14 - (_t * 70) % w;
    while (x < 350) {
      D.text(c, s, Offset(x, 63), size: 17, color: Pal.yellow, stroke: const Color(0xFFB0115A), strokeWidth: 4,
          anchor: Alignment.centerLeft);
      x += w;
    }
    c.restore();
    // blinking bulbs
    for (var i = 0; i < 16; i++) {
      final on = ((_t * 8).floor() + i) % 3 == 0;
      c.drawCircle(Offset(24 + i * 20.8, 84.5), 2.2, D.fill(on ? Pal.yellow : const Color(0x55FFD23F)));
    }
  }

  // ---- machine ----

  void _drawMachine(Canvas c) {
    final ctr = _machCenter;
    final s = _machScale;
    final sh = _machShake;
    c.save();
    c.translate(ctr.dx + math.sin(_t * 71) * sh * 5, ctr.dy + math.cos(_t * 63) * sh * 3);
    c.scale(s);
    c.rotate(math.sin(_t * 37) * sh * .03);

    // hint glow / light beams (burst phase)
    if (_ph == _Ph.burst || (_ph == _Ph.pour && _machK < 1)) {
      final k = _ph == _Ph.burst ? M.clamp01(_phT / .4) : 1 - _machK;
      final col = _tier == 2 ? D.hsv(_t * 360, .7, 1) : (_tier == 1 ? Pal.gold : const Color(0xFFDDE6FF));
      c.drawCircle(const Offset(0, -120), 160 * k + 40, _glow(col.withValues(alpha: .55 * k), 40));
      if (_tier == 2) {
        for (var i = 0; i < 3; i++) {
          D.rays(c, const Offset(0, -120), 520, _rainbow[i * 2].withValues(alpha: .28 * k), count: 12, t: _t * (1.4 + i * .3) + i, width: .35);
        }
      } else {
        D.rays(c, const Offset(0, -120), 460, col.withValues(alpha: .3 * k), count: 12, t: _t * 1.5, width: .4);
      }
    }

    // legs + shadow
    D.shadow(c, const Offset(0, 178), 250, 26, .4);
    for (final x in [-80.0, 80.0]) {
      D.rrect(c, Rect.fromCenter(center: Offset(x, 162), width: 34, height: 30), 8, const Color(0xFF7A0F3A), border: Pal.ink, borderWidth: 4);
    }
    // body
    final body = Path()
      ..moveTo(-118, -26)
      ..lineTo(118, -26)
      ..quadraticBezierTo(124, -26, 122, -16)
      ..lineTo(104, 146)
      ..quadraticBezierTo(102, 156, 92, 156)
      ..lineTo(-92, 156)
      ..quadraticBezierTo(-102, 156, -104, 146)
      ..lineTo(-122, -16)
      ..quadraticBezierTo(-124, -26, -118, -26)
      ..close();
    c.drawPath(
        body,
        Paint()
          ..shader = ui.Gradient.linear(const Offset(-120, 0), const Offset(120, 0),
              const [Color(0xFFB0124E), Color(0xFFFF4F8B), Color(0xFFFF7FAA), Color(0xFFD01A5C)], const [0, .35, .55, 1]));
    c.drawPath(body, D.stroke(Pal.ink, 5));
    // neon trim bulbs around body
    for (var i = 0; i < 11; i++) {
      final on = ((_t * 10).floor() + i) % 2 == 0 || _ph == _Ph.burst;
      final col = _ph == _Ph.burst && _tier == 2 ? _rainbow[i % 7] : (on ? Pal.yellow : const Color(0xFF7A3A10));
      final p = Offset(-100 + i * 20.0, 0);
      if (on) c.drawCircle(p, 7, _glow(col.withValues(alpha: .7), 5));
      c.drawCircle(p, 4.2, D.fill(col));
    }
    // "10x" panel
    D.rrect(c, const Rect.fromLTWH(-98, 12, 58, 30), 8, const Color(0xFF240A38), border: Pal.ink, borderWidth: 3);
    D.text(c, '10x', const Offset(-69, 27), size: 20, color: Pal.yellow, stroke: const Color(0xFFB0115A), strokeWidth: 4);
    D.rrect(c, const Rect.fromLTWH(40, 12, 58, 30), 8, const Color(0xFF240A38), border: Pal.ink, borderWidth: 3);
    D.text(c, 'SSR', const Offset(69, 27), size: 18, color: D.hsv(_t * 200, .6, 1), stroke: Pal.ink, strokeWidth: 4);
    // coin slot
    D.rrect(c, const Rect.fromLTWH(58, 64, 34, 40), 6, const Color(0xFFD9DCE8), border: Pal.ink, borderWidth: 3);
    D.rrect(c, const Rect.fromLTWH(72, 70, 6, 26), 3, Pal.ink);
    // chute
    D.rrect(c, const Rect.fromLTWH(-44, 104, 88, 42), 12, const Color(0xFF3A0A22), border: Pal.ink, borderWidth: 4);
    D.rrect(c, const Rect.fromLTWH(-36, 110, 72, 16), 6, const Color(0xFF1A0410));
    c.drawRect(const Rect.fromLTWH(-40, 128, 80, 5), D.fill(const Color(0x55FFFFFF)));
    // handle
    const hc = Offset(0, 55);
    c.drawCircle(hc, 44, D.fill(const Color(0xFF8C1A44)));
    c.drawCircle(hc, 40, Paint()
      ..shader = ui.Gradient.radial(hc + const Offset(-12, -14), 50, const [Pal.white, Color(0xFFC9CEDD), Color(0xFF8E93A8)], const [0, .5, 1]));
    c.drawCircle(hc, 40, D.stroke(Pal.ink, 4));
    c.save();
    c.translate(hc.dx, hc.dy);
    c.rotate(_crank);
    D.rrect(c, const Rect.fromLTWH(-48, -11, 96, 22), 11, const Color(0xFFFF3B5C), border: Pal.ink, borderWidth: 4);
    D.rrect(c, const Rect.fromLTWH(-42, -8, 84, 6), 3, const Color(0x66FFFFFF));
    c.drawCircle(const Offset(40, 0), 12, D.fill(Pal.yellow));
    c.drawCircle(const Offset(40, 0), 12, D.stroke(Pal.ink, 3.5));
    c.drawCircle(const Offset(37, -4), 4, D.fill(const Color(0xAAFFFFFF)));
    c.restore();
    c.drawCircle(hc, 9, D.fill(Pal.ink));
    c.drawCircle(hc + const Offset(-2, -2), 3, D.fill(const Color(0x88FFFFFF)));
    // crank progress ring
    if (_ph == _Ph.crank) {
      final k = M.clamp01(_crankAcc / _goal);
      final rect = Rect.fromCircle(center: hc, radius: 54);
      c.drawArc(rect, 0, math.pi * 2, false, D.stroke(const Color(0x55000000), 9));
      if (k > 0) {
        c.drawArc(rect, -math.pi / 2, math.pi * 2 * k, false, _glow(D.hsv(180 + k * 140, .8, 1, .8), 6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12);
        c.drawArc(rect, -math.pi / 2, math.pi * 2 * k, false, D.stroke(D.hsv(180 + k * 140, .5, 1), 6));
      }
    }

    // dome collar
    D.rrect(c, const Rect.fromLTWH(-126, -46, 252, 26), 12, const Color(0xFFFFC53D), border: Pal.ink, borderWidth: 4);
    c.drawRect(const Rect.fromLTWH(-116, -42, 232, 5), D.fill(const Color(0x88FFFFFF)));
    // dome
    const dc = Offset(0, -130);
    const dr = 110.0;
    c.drawCircle(dc, dr, D.fill(const Color(0x445FD3FF)));
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: dc, radius: dr - 3)));
    for (var i = 0; i < _domeCaps.length; i++) {
      if (_ph.index >= _Ph.pour.index && i >= _domeCaps.length - _poured * 2) continue;
      final jig = Offset(math.sin(_t * 40 + i) * _machShake * 6, math.cos(_t * 33 + i * 2) * _machShake * 8 - _machShake * 6);
      final p = dc + _domeCaps[i] + const Offset(0, 16) + jig;
      _miniCap(c, p, 17, _domeCols[i], i * .7 + _machShake * math.sin(_t * 20 + i));
    }
    c.restore();
    c.drawCircle(dc, dr, D.fill(const Color(0x22FFFFFF)));
    c.drawArc(Rect.fromCircle(center: dc, radius: dr - 14), math.pi * 1.05, math.pi * .45, false, D.stroke(const Color(0xAAFFFFFF), 9));
    c.drawCircle(dc + const Offset(58, -58), 8, D.fill(const Color(0x99FFFFFF)));
    c.drawCircle(dc, dr, D.stroke(Pal.ink, 5));
    // top cap
    c.drawArc(Rect.fromCircle(center: const Offset(0, -236), radius: 30), math.pi, math.pi, true, D.fill(const Color(0xFFFF3B5C)));
    c.drawArc(Rect.fromCircle(center: const Offset(0, -236), radius: 30), math.pi, math.pi, true, D.stroke(Pal.ink, 4));
    D.gem(c, const Offset(0, -262), 14, _tier == 2 ? D.hsv(_t * 300, .7, 1) : Pal.sky);
    c.restore();
  }

  void _miniCap(Canvas c, Offset p, double r, Color col, double rot) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(rot);
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    c.drawArc(rect, 0, math.pi, true, D.fill(const Color(0xFFF2F2FA)));
    c.drawArc(rect, math.pi, math.pi, true, D.fill(col));
    c.drawCircle(Offset.zero, r, D.stroke(Pal.ink, 2.5));
    c.drawCircle(Offset(-r * .4, -r * .45), r * .2, D.fill(const Color(0x99FFFFFF)));
    c.restore();
  }

  void _drawCap(Canvas c, Offset p, double r, int rarity, double rot, {double open = 0, double squash = 0}) {
    if (rarity >= 1 && open == 0) {
      final col = rarity == 2 ? D.hsv(_t * 300, .6, 1) : Pal.gold;
      final pulse = .7 + .3 * M.wave(_t, 2.2);
      c.drawCircle(p, r * 1.7, _glow(col.withValues(alpha: .5 * pulse), 14));
      if (rarity == 2) {
        D.rays(c, p, r * 2.6, Pal.white.withValues(alpha: .35), count: 8, t: _t * 2, width: .3);
      }
    }
    c.save();
    c.translate(p.dx, p.dy + squash * r * .15);
    c.scale(1 + squash * .18, 1 - squash * .18);
    c.rotate(rot);
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    final alpha = 1 - M.clamp01((open - .6) / .4);
    // bottom half
    c.save();
    c.translate(0, open * r * .8);
    c.rotate(open * .6);
    c.drawArc(rect, 0, math.pi, true, D.fill(Color.fromRGBO(244, 244, 255, alpha)));
    c.drawArc(rect, 0, math.pi, true, D.stroke(Pal.ink.withValues(alpha: alpha), 3));
    c.restore();
    // top half
    c.save();
    c.translate(-open * r * .6, -open * r * 1.6);
    c.rotate(-open * 1.4);
    final top = Paint();
    if (rarity == 2) {
      top.shader = _rainbowSweep(Offset.zero, _t * 4);
    } else if (rarity == 1) {
      top.shader = ui.Gradient.linear(Offset(-r, -r), Offset(r, 0), const [Color(0xFFFFF3A0), Color(0xFFFFC53D), Color(0xFFC77A00)], const [0, .5, 1]);
    } else {
      top.shader = ui.Gradient.linear(Offset(-r, -r), Offset(r, 0), const [Color(0xFFFFFFFF), Color(0xFFC3CAD9), Color(0xFF8A93A8)], const [0, .5, 1]);
    }
    if (alpha < 1) {
      c.saveLayer(rect.inflate(4), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }
    c.drawArc(rect, math.pi, math.pi, true, top);
    c.drawArc(rect, math.pi, math.pi, true, D.stroke(Pal.ink, 3));
    c.drawOval(Rect.fromCenter(center: Offset(-r * .35, -r * .5), width: r * .55, height: r * .3), D.fill(const Color(0xAAFFFFFF)));
    if (alpha < 1) c.restore();
    c.restore();
    if (open == 0) {
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 2, height: 4), D.fill(const Color(0x55000000)));
      c.drawCircle(Offset.zero, r, D.stroke(Pal.ink, 3));
    }
    c.restore();
  }

  void _drawTray(Canvas c) {
    const r = Rect.fromLTWH(14, 318, 332, 296);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(22));
    c.drawRRect(rr, Paint()..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [Color(0x66230A40), Color(0xCC3B0C55)]));
    final hue = 300 + math.sin(_t * 2) * 30;
    c.drawRRect(rr, _glow(D.hsv(hue, .8, 1, .8), 8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6);
    c.drawRRect(rr, D.stroke(D.hsv(hue, .4, 1), 2.5));
    // floor stripes
    for (var i = 0; i < 8; i++) {
      c.drawLine(Offset(30 + i * 43.0, _floor + 2), Offset(22 + i * 43.0, 612), D.stroke(const Color(0x33FFFFFF), 2));
    }
  }

  void _drawSlots(Canvas c) {
    final k = M.clamp01(_ph == _Ph.done ? 1 : _phT / .4);
    for (var i = 0; i < 10; i++) {
      final p = _slotPos(i);
      final r = Rect.fromCenter(center: p, width: _cardW * k, height: _cardW * 1.4 * k);
      D.rrect(c, r, 8, const Color(0x44000000), border: const Color(0x66FF9EE0), borderWidth: 2);
      if (k > .5) D.text(c, '?', p, size: 22, color: const Color(0x55FFFFFF));
    }
  }

  void _drawCards(Canvas c) {
    for (final cd in _cards) {
      final target = _slotPos(cd.slot);
      final e = M.easeInOut(cd.t);
      var pos = Offset.lerp(cd.from, target, e)!;
      pos = pos.translate(0, -math.sin(cd.t * math.pi) * 70);
      var w = M.lerp(cd.fromW, _cardW, e);
      if (cd.t < 1 && cd.fromW < _cardW) w *= .4 + .6 * e;
      w *= 1 + cd.bounce * .25;
      if (_ph == _Ph.done) {
        final wave = math.sin(_phT * 8 - cd.slot * .6);
        pos = pos.translate(0, -math.max(0, wave) * 8 * math.max(0, 1 - _phT * .3));
      }
      if (cd.rarity == 2 && cd.t >= 1) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: w + 16, height: w * 1.4 + 16), const Radius.circular(12)),
            _glow(D.hsv(_t * 200 + cd.slot * 30, .7, 1, .8), 10));
      }
      _card(c, pos, w, cd.rarity, cd.charIdx, flip: cd.t < 1 ? math.cos(cd.t * math.pi * 2).abs().clamp(.15, 1) : 1);
    }
  }

  /// A collectible character card of width [w] centered at [o].
  void _card(Canvas c, Offset o, double w, int rarity, int ch, {double flip = 1}) {
    final s = w / 100;
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s * flip, s);
    const r = Rect.fromLTWH(-50, -70, 100, 140);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
    final frame = Paint();
    if (rarity == 2) {
      frame.shader = _rainbowSweep(Offset.zero, _t * 2);
    } else if (rarity == 1) {
      frame.shader = ui.Gradient.linear(r.topLeft, r.bottomRight, const [Color(0xFFFFF3A0), Color(0xFFFFB81F), Color(0xFFFFF0A0), Color(0xFFC77A00)], const [0, .4, .6, 1]);
    } else {
      frame.shader = ui.Gradient.linear(r.topLeft, r.bottomRight, const [Color(0xFFF4F6FF), Color(0xFFA8B2C8), Color(0xFFE8ECF6), Color(0xFF7C869C)], const [0, .4, .6, 1]);
    }
    c.drawRRect(rr, frame);
    c.drawRRect(rr, D.stroke(Pal.ink, 4));
    // art window
    const art = Rect.fromLTWH(-42, -62, 84, 84);
    final bgCols = rarity == 2
        ? const [Color(0xFFFFF1FF), Color(0xFF7A2BD9), Color(0xFF240A50)]
        : (rarity == 1 ? const [Color(0xFFFFF4C0), Color(0xFFFF8A1F), Color(0xFF8C2A00)] : const [Color(0xFFE6F2FF), Color(0xFF5E8BD9), Color(0xFF263A70)]);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(art, const Radius.circular(6)));
    c.drawRect(art, Paint()..shader = ui.Gradient.radial(const Offset(0, -24), 70, bgCols, const [0, .5, 1]));
    if (rarity >= 1) {
      D.rays(c, const Offset(0, -24), 90, Color(rarity == 2 ? 0x55FFFFFF : 0x44FFF4C0), count: 12, t: _t * (rarity == 2 ? 1.5 : .6));
    }
    _chr(c, const Offset(0, -12), 25, ch, rarity);
    c.restore();
    c.drawRRect(RRect.fromRectAndRadius(art, const Radius.circular(6)), D.stroke(Pal.ink, 3));
    // plate
    D.rrect(c, const Rect.fromLTWH(-42, 28, 84, 36), 6, const Color(0xFF1B1530), border: Pal.ink, borderWidth: 2);
    final label = rarity == 2 ? 'SSR' : (rarity == 1 ? 'SR' : 'R');
    D.text(c, label, const Offset(0, 38), size: 14, color: rarity == 2 ? Pal.pink : (rarity == 1 ? Pal.gold : const Color(0xFFCFD8EE)), stroke: Pal.ink, strokeWidth: 3);
    final n = 3 + rarity;
    for (var i = 0; i < n; i++) {
      D.star(c, Offset((i - (n - 1) / 2) * 13, 54), 6, Pal.yellow, border: const Color(0xFF8C5A00));
    }
    // foil sheen
    if (rarity >= 1) {
      final x = ((_t * (rarity == 2 ? 120 : 70)) % 320) - 160;
      c.save();
      c.clipRRect(rr);
      c.drawPath(
          Path()
            ..moveTo(x - 20, -80)
            ..lineTo(x + 10, -80)
            ..lineTo(x - 40, 80)
            ..lineTo(x - 70, 80)
            ..close(),
          D.fill(const Color(0x55FFFFFF)));
      c.restore();
    }
    c.restore();
  }

  static const _chCols = <Color>[
    Pal.sky, Pal.pink, Pal.lime, Pal.orange, Pal.purple, Pal.teal, Pal.red, Pal.yellow, Color(0xFF7F8CFF), Color(0xFFFFA8D8),
  ];
  static const _chFaces = <Face>[
    Face.happy, Face.smug, Face.love, Face.neutral, Face.happy, Face.sleepy, Face.angry, Face.smug, Face.love, Face.happy,
  ];

  void _chr(Canvas c, Offset o, double r, int idx, int rarity) {
    final col = rarity == 2 ? const Color(0xFFFFE27A) : _chCols[idx % 10];
    if (rarity == 2) {
      // angel wings
      for (final sx in [-1.0, 1.0]) {
        final flap = math.sin(_t * 8) * .15;
        c.save();
        c.translate(o.dx + sx * r * .7, o.dy - r * .1);
        c.scale(sx, 1);
        c.rotate(-.3 + flap);
        final wing = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(r * 1.2, -r * 1.2, r * 1.6, -r * .6)
          ..quadraticBezierTo(r * 1.3, -r * .3, r * 1.4, 0)
          ..quadraticBezierTo(r * 1.0, 0, r * 1.1, r * .35)
          ..quadraticBezierTo(r * .6, r * .3, 0, r * .3)
          ..close();
        c.drawPath(wing, D.fill(Pal.white));
        c.drawPath(wing, D.stroke(Pal.ink, 2.5));
        c.restore();
      }
    }
    D.blob(c, o, r, col, face: rarity == 2 ? Face.love : _chFaces[idx % 10]);
    final top = o + Offset(0, -r * .95);
    final acc = rarity == 2 ? 0 : idx % 10;
    switch (acc) {
      case 0: // crown
        final cr = Path()
          ..moveTo(top.dx - r * .55, top.dy + r * .1)
          ..lineTo(top.dx - r * .6, top.dy - r * .45)
          ..lineTo(top.dx - r * .3, top.dy - r * .15)
          ..lineTo(top.dx, top.dy - r * .6)
          ..lineTo(top.dx + r * .3, top.dy - r * .15)
          ..lineTo(top.dx + r * .6, top.dy - r * .45)
          ..lineTo(top.dx + r * .55, top.dy + r * .1)
          ..close();
        c.drawPath(cr, D.fill(Pal.gold));
        c.drawPath(cr, D.stroke(Pal.ink, 2.5));
        c.drawCircle(top + Offset(0, -r * .1), r * .1, D.fill(Pal.red));
      case 1: // party hat
        final h = Path()
          ..moveTo(top.dx - r * .35, top.dy + r * .1)
          ..lineTo(top.dx + r * .1, top.dy - r * .8)
          ..lineTo(top.dx + r * .45, top.dy + r * .05)
          ..close();
        c.drawPath(h, D.fill(Pal.purple));
        c.drawPath(h, D.stroke(Pal.ink, 2.5));
        c.drawCircle(top + Offset(r * .1, -r * .85), r * .14, D.fill(Pal.yellow));
      case 2: // horns
        for (final sx in [-1.0, 1.0]) {
          final h = Path()
            ..moveTo(top.dx + sx * r * .3, top.dy + r * .15)
            ..lineTo(top.dx + sx * r * .55, top.dy - r * .45)
            ..lineTo(top.dx + sx * r * .7, top.dy + r * .3)
            ..close();
          c.drawPath(h, D.fill(const Color(0xFFF2EAD8)));
          c.drawPath(h, D.stroke(Pal.ink, 2.5));
        }
      case 3: // halo
        c.drawOval(Rect.fromCenter(center: top + Offset(0, -r * .35), width: r * 1.1, height: r * .35), D.stroke(Pal.yellow, 4));
      case 4: // cat ears
        for (final sx in [-1.0, 1.0]) {
          final h = Path()
            ..moveTo(top.dx + sx * r * .15, top.dy + r * .15)
            ..lineTo(top.dx + sx * r * .6, top.dy - r * .5)
            ..lineTo(top.dx + sx * r * .85, top.dy + r * .4)
            ..close();
          c.drawPath(h, D.fill(col));
          c.drawPath(h, D.stroke(Pal.ink, 2.5));
        }
      case 5: // sprout
        c.drawLine(top + Offset(0, r * .1), top + Offset(0, -r * .45), D.stroke(const Color(0xFF2E8B3E), 3));
        for (final sx in [-1.0, 1.0]) {
          c.drawOval(Rect.fromCenter(center: top + Offset(sx * r * .25, -r * .5), width: r * .5, height: r * .26), D.fill(Pal.lime));
        }
      case 6: // wizard hat
        final h = Path()
          ..moveTo(top.dx - r * .7, top.dy + r * .15)
          ..lineTo(top.dx + r * .7, top.dy + r * .15)
          ..lineTo(top.dx + r * .25, top.dy)
          ..lineTo(top.dx + r * .5, top.dy - r * .9)
          ..lineTo(top.dx - r * .25, top.dy)
          ..close();
        c.drawPath(h, D.fill(const Color(0xFF3D2A8C)));
        c.drawPath(h, D.stroke(Pal.ink, 2.5));
        D.star(c, top + Offset(r * .05, -r * .25), r * .15, Pal.yellow);
      case 7: // shades
        for (final sx in [-1.0, 1.0]) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o + Offset(sx * r * .36, -r * .1), width: r * .6, height: r * .36), Radius.circular(r * .12)),
              D.fill(Pal.ink));
        }
        c.drawLine(o + Offset(-r * .1, -r * .12), o + Offset(r * .1, -r * .12), D.stroke(Pal.ink, 3));
      case 8: // bow
        final b = top + Offset(r * .45, r * .1);
        for (final sx in [-1.0, 1.0]) {
          final h = Path()
            ..moveTo(b.dx, b.dy)
            ..lineTo(b.dx + sx * r * .4, b.dy - r * .25)
            ..lineTo(b.dx + sx * r * .4, b.dy + r * .25)
            ..close();
          c.drawPath(h, D.fill(Pal.red));
          c.drawPath(h, D.stroke(Pal.ink, 2));
        }
        c.drawCircle(b, r * .1, D.fill(Pal.red));
      default: // ninja band
        c.drawRect(Rect.fromCenter(center: o + Offset(0, -r * .5), width: r * 1.9, height: r * .22), D.fill(Pal.red));
        c.drawLine(o + Offset(r * .9, -r * .5), o + Offset(r * 1.3, -r * .2), D.stroke(Pal.red, 4));
    }
    if (rarity == 2) {
      final cr = Path()
        ..moveTo(top.dx - r * .6, top.dy + r * .1)
        ..lineTo(top.dx - r * .7, top.dy - r * .55)
        ..lineTo(top.dx - r * .35, top.dy - r * .2)
        ..lineTo(top.dx, top.dy - r * .75)
        ..lineTo(top.dx + r * .35, top.dy - r * .2)
        ..lineTo(top.dx + r * .7, top.dy - r * .55)
        ..lineTo(top.dx + r * .6, top.dy + r * .1)
        ..close();
      c.drawPath(cr, D.fill(Pal.gold));
      c.drawPath(cr, D.stroke(Pal.ink, 2.5));
      c.drawCircle(top + Offset(0, -r * .15), r * .13, D.fill(Pal.pink));
      final sp = o + Offset(math.cos(_t * 3) * r * 1.3, math.sin(_t * 3) * r * .8 - r * .3);
      c.drawPath(D.starPath(sp, r * .3, r * .07, points: 4, rotation: 0), D.fill(Pal.white));
    }
  }

  // ---- SSR cutscene ----

  void _drawSsr(Canvas c) {
    c.drawRect(GameHost.bounds, D.fill(Color.fromRGBO(10, 2, 20, .86 * _ovl)));
    final s = _ssr;
    if (s == null) return;
    final t = _ssrT;
    const center = Offset(180, 340);
    if (t < 1.0) {
      final e = M.easeOut(M.clamp01(t / .35));
      final pos = Offset.lerp(s.pos, center, e)!;
      final k = t;
      final shake = Offset(math.sin(t * 90) * k * k * 9, math.cos(t * 77) * k * k * 6);
      // light beams leaking
      for (var i = 0; i < 3; i++) {
        D.rays(c, pos, 600, _rainbow[i * 2 + 1].withValues(alpha: .15 + .3 * k), count: 10 + i * 2, t: t * (2 + i) + i, width: .12 + .2 * k);
      }
      c.drawCircle(pos, 60 + 60 * k, _glow(D.hsv(t * 500, .6, 1, .5 + .4 * k), 30));
      _drawCap(c, pos + shake, _capR * (1 + 2.3 * e + math.sin(t * 30) * .08 * k), 2, math.sin(t * 40) * .2 * k);
      // cracks of light
      if (t > .45) {
        final ck = M.clamp01((t - .45) / .55);
        for (var i = 0; i < 6; i++) {
          final a = i * 1.047 + .3;
          final l = 40 + 160 * ck;
          c.drawLine(pos, pos + Offset(math.cos(a), math.sin(a)) * l, _glow(Pal.white.withValues(alpha: ck), 4)..strokeWidth = 6);
        }
      }
      return;
    }
    // after the explosion
    final k = t - 1.0;
    c.drawCircle(center, 260, Paint()
      ..shader = ui.Gradient.radial(center, 260, const [Color(0xAAFFFFFF), Color(0x55FF5FC8), Color(0x00000000)], const [0, .45, 1]));
    for (var i = 0; i < 3; i++) {
      D.rays(c, center, 700, _rainbow[(i * 2 + (t * 6).floor()) % 7].withValues(alpha: .35), count: 12, t: t * (.8 + i * .25) + i * .4, width: .3);
    }
    // capsule halves flying away
    if (k < .6) {
      final a = 1 - k / .6;
      c.save();
      c.translate(center.dx - k * 300, center.dy - k * 260 + k * k * 400);
      c.rotate(-k * 8);
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: 60 * a + 10), math.pi, math.pi, true, Paint()..shader = _rainbowSweep(Offset.zero, t * 4));
      c.restore();
      c.save();
      c.translate(center.dx + k * 300, center.dy + k * 200 + k * k * 400);
      c.rotate(k * 7);
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: 60 * a + 10), 0, math.pi, true, D.fill(const Color(0xFFF4F4FF)));
      c.restore();
    }
    // the card
    final ce = M.easeOutElastic(M.clamp01(k / .7));
    final bob = math.sin(t * 3) * 4;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center + Offset(0, bob), width: 210 * ce, height: 290 * ce), const Radius.circular(20)),
        _glow(D.hsv(t * 220, .7, 1, .9), 22));
    if (ce > .02) _card(c, center + Offset(0, bob), 190 * ce, 2, s.charIdx, flip: 1);
    // calligraphy "SSR!!!"
    if (t > 1.2) {
      final tk = M.clamp01((t - 1.2) / .18);
      final sc = M.lerp(2.8, 1, M.easeOut(tk)) * (1 + .04 * math.sin(t * 12));
      c.save();
      c.translate(180, 132);
      c.rotate(-.12);
      c.scale(sc);
      // ink brush splash
      final bp = D.stroke(const Color(0xFF12060F), 42);
      c.drawLine(const Offset(-140, 8), const Offset(140, -4), bp);
      c.drawLine(const Offset(-120, -14), const Offset(150, -18), D.stroke(const Color(0xFF12060F), 16));
      c.drawLine(const Offset(-150, 26), const Offset(100, 24), D.stroke(const Color(0xFF12060F), 10));
      for (var i = 0; i < 7; i++) {
        c.drawCircle(Offset(-150 + i * 50.0, 38 + (i % 3) * 7.0), 3.0 + (i % 3) * 2, D.fill(const Color(0xFF12060F)));
      }
      _rainbowText(c, 'SSR!!!', Offset.zero, 64, t * 120);
      c.restore();
    }
    // five stars
    for (var i = 0; i < 5; i++) {
      final at = 1.45 + i * .11;
      if (t < at) continue;
      final sk = M.easeOutBack(M.clamp01((t - at) / .2));
      final p = Offset(100 + i * 40.0, 530 + math.sin(t * 6 + i) * 3);
      c.drawCircle(p, 20 * sk, _glow(const Color(0xAAFFE23F), 10));
      D.star(c, p, 17 * sk, Pal.yellow, border: const Color(0xFF8C5A00), rotation: -math.pi / 2 + (1 - sk) * 2);
    }
    if (t > 1.9) {
      D.text(c, host.tr('tap', 'TAP!'), Offset(180, 590), size: 16, color: Color.fromRGBO(255, 255, 255, .5 + .5 * M.wave(t, 2)), stroke: Pal.ink);
    }
  }

  // ---- hints / ending ----

  void _hints(Canvas c) {
    if (_ph == _Ph.crank && _crankAcc < math.pi * 1.2) {
      final hc = _handle;
      final dots = D.fill(const Color(0xCCFFFFFF));
      for (var i = 0; i < 14; i++) {
        final a = i / 14 * math.pi * 2 + _t * 3;
        c.drawCircle(hc + Offset(math.cos(a), math.sin(a)) * 80, 3 + (i / 14) * 3, dots);
      }
      final a = _t * 4;
      D.arrow(c, hc + Offset(math.cos(a), math.sin(a)) * 80, Offset(-math.sin(a), math.cos(a)), 34, Pal.yellow, width: 9);
      D.hand(c, hc + Offset(math.cos(a - .5), math.sin(a - .5)) * 80, _t);
      D.title(c, host.tr('turn', 'TURN!'), hc + const Offset(0, 150), size: 30, scale: 1 + .06 * math.sin(_t * 8));
    } else if (_ph == _Ph.crank) {
      final pct = (M.clamp01(_crankAcc / _goal) * 100).round();
      D.text(c, '$pct%', _handle + const Offset(0, 150), size: 30, color: D.hsv(180 + pct * 1.4, .6, 1), stroke: Pal.ink);
    }
    if (_ph == _Ph.open && _ssr == null && !_caps.any((c) => c.promoT >= 0) && host.time - _lastOpen > 1.6) {
      for (final cp in _caps) {
        if (cp.out && !cp.opened && cp.vel.distance < 50) {
          D.hand(c, cp.pos + const Offset(4, 8), _t);
          D.text(c, host.tr('tap', 'TAP!'), cp.pos + const Offset(0, -44), size: 20, color: Pal.yellow, stroke: Pal.ink);
          break;
        }
      }
    }
    // remaining counter
    if (_ph == _Ph.open) {
      final left = _caps.where((c) => !c.opened).length;
      if (left > 0) {
        D.text(c, '$left / 10', const Offset(300, 334), size: 16, color: Pal.white, stroke: Pal.ink);
      }
    }
  }

  void _drawDone(Canvas c) {
    final k = M.easeOutBack(M.clamp01(_phT / .45));
    D.rays(c, const Offset(180, 430), 420, const Color(0x33FFE23F), count: 14, t: _t);
    c.save();
    c.translate(180, 430);
    c.scale(k);
    _rainbowText(c, host.tr('complete', 'COMPLETE!'), Offset.zero, 40, _t * 150);
    c.restore();
    if (_phT > .3) {
      D.text(c, 'SSR x$_ssrCount', Offset(180, 490), size: 28, color: Pal.yellow, stroke: Pal.ink, italic: true);
    }
  }
}
