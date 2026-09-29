import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.112 Holo Pack Rip — swipe across the top edge to tear the foil pack,
/// flick through the cards, flip the glowing last one and RUB the holo card
/// to appraise it until the market value rolls up to ¥1,000,000!?

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
final _stops = List<double>.generate(8, (i) => i / 7);

Paint _glow(Color c, double blur) => Paint()
  ..color = c
  ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur);

enum _Ph { tear, rise, cards, flip, rub, done }

class _Flying {
  _Flying(this.idx, this.dir);
  final int idx;
  final double dir;
  double t = 0;
}

class G112 extends MiniGame {
  static const _pack = Rect.fromLTWH(78, 196, 204, 318);
  static const _tearY = 246.0;
  static const _cardC = Offset(180, 330);
  static const _cw = 176.0;

  _Ph _ph = _Ph.tear;
  double _t = 0, _phT = 0;

  // tear
  double _tear = 0; // 0..1
  double _tearDir = 1; // 1 = from left
  bool _tearing = false;
  double? _tearX0;
  double _minX = 999, _maxX = -999;
  double _stripT = -1;
  double _ripCd = 0;

  // cards
  late final List<int> _types; // creature types for the commons
  int _top = 0; // index of the current top card (0..4)
  final _flying = <_Flying>[];
  Offset? _swipeStart;
  double _flipT = 0;
  bool _flipped = false;

  // rub
  double _value = 0; // 0..1 appraisal
  double _valueDisp = 0;
  Offset _tilt = Offset.zero;
  Offset? _lastRub;
  double _rubSfx = 0;
  double _doneT = 0;

  @override
  Color get backdrop => const Color(0xFF0A0420);

  @override
  void init() {
    _types = List<int>.generate(4, (_) => randInt(4));
  }

  // ---------------------------------------------------------------- update --

  @override
  void update(double dt) {
    _t += dt;
    _phT += dt;
    _ripCd -= dt;
    _rubSfx -= dt;
    for (final f in _flying) {
      f.t += dt;
    }
    if (_stripT >= 0) _stripT += dt;
    switch (_ph) {
      case _Ph.tear:
        break;
      case _Ph.rise:
        if (_phT > .7) _setPh(_Ph.cards);
      case _Ph.cards:
        break;
      case _Ph.flip:
        _flipT += dt;
        if (!_flipped && _flipT > .45) {
          _flipped = true;
          host.flash(Pal.white, .3);
          host.shake(14, .5);
          host.hitStop(.1);
          host.punch(.08);
          host.sfx(Sfx.ssr);
          host.sfx(Sfx.glass, volume: .5);
          host.fx.burst(_cardC, Pal.white, count: 60, speed: 560, colors: _rainbow, shape: PartShape.star, gravity: 150, life: 1);
          host.fx.ring(_cardC, Pal.white, size: 260, life: .5);
          host.fx.pop(host.tr('legendary', 'LEGENDARY!'), const Offset(180, 110), color: Pal.yellow, size: 36, life: 1.2);
        }
        if (_flipT > 1.1) _setPh(_Ph.rub);
      case _Ph.rub:
        if (!host.pointerDown) _tilt = M.approachO(_tilt, Offset(math.sin(_t * 1.3) * .3, math.cos(_t * 1.1) * .2), 3, dt);
        if (_value >= 1) {
          _setPh(_Ph.done);
          host.sfx(Sfx.ssr);
          host.sfx(Sfx.fanfare);
          host.sfx(Sfx.cash);
          host.shake(12, .5);
          host.flash(const Color(0xCCFFE23F), .25);
          host.fx.confetti(count: 110);
          host.fx.coins(const Offset(180, 560), count: 40, speed: 800);
          host.win(stars: host.time < 11 ? 3 : (host.time < 14.5 ? 2 : 1));
        }
      case _Ph.done:
        _doneT += dt;
        if (chance(.4)) host.fx.coins(Offset(rand(20, 340), 660), count: 2, speed: 850);
    }
    final prev = (_valueDisp * 20).floor();
    _valueDisp = _ph == _Ph.done ? 1 : M.approach(_valueDisp, _value, 6, dt);
    if ((_valueDisp * 20).floor() != prev && _ph == _Ph.rub) host.sfx(Sfx.tick, volume: .4, rate: 1 + _valueDisp);
  }

  void _setPh(_Ph p) {
    _ph = p;
    _phT = 0;
  }

  // ---------------------------------------------------------------- input --

  @override
  void onDown(Offset p) {
    switch (_ph) {
      case _Ph.tear:
        if ((p.dy - _tearY).abs() < 60 && p.dx > 40 && p.dx < 320) {
          _tearing = true;
          if (_tear == 0) _tearDir = p.dx < 180 ? 1 : -1;
          _tearX0 = p.dx;
          _minX = math.min(_minX, p.dx);
          _maxX = math.max(_maxX, p.dx);
          _addTear(.08);
        }
      case _Ph.cards:
        _swipeStart = p;
      case _Ph.rub:
        _lastRub = p;
        _rub(p, 30);
      default:
        break;
    }
  }

  @override
  void onMove(Offset p) {
    switch (_ph) {
      case _Ph.tear:
        if (!_tearing || _tearX0 == null) return;
        if ((p.dy - _tearY).abs() > 70) return; // left the tear line
        final before = _maxX - _minX;
        _minX = math.min(_minX, p.dx);
        _maxX = math.max(_maxX, p.dx);
        final gain = (_maxX - _minX) - before;
        if (gain > 0) _addTear(gain / 175);
      case _Ph.cards:
        final s = _swipeStart;
        if (s != null && (p.dx - s.dx).abs() > 40) {
          _next((p.dx - s.dx).sign);
          _swipeStart = null;
        }
      case _Ph.rub:
        final l = _lastRub;
        if (l != null) _rub(p, (p - l).distance);
        _lastRub = p;
      default:
        break;
    }
  }

  @override
  void onUp(Offset p) {
    if (_ph == _Ph.cards && _swipeStart != null) {
      _next(p.dx < 180 ? -1 : 1); // a plain tap also flicks
    }
    _swipeStart = null;
    _tearing = false;
    _lastRub = null;
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    switch (_ph) {
      case _Ph.tear:
        _addTear(.3);
      case _Ph.cards:
        _next(key == 'left' ? -1 : 1);
      case _Ph.rub:
        _rub(Offset(180 + rand(-60, 60), 330 + rand(-80, 80)), 160);
      default:
        break;
    }
  }

  void _addTear(double d) {
    if (_ph != _Ph.tear) return;
    _tear = math.min(1, _tear + d);
    if (_ripCd <= 0) {
      _ripCd = .07;
      host.sfx(Sfx.rip, volume: .5, rate: .8 + _tear * .6);
      final x = _tearDir > 0 ? _pack.left + _tear * _pack.width : _pack.right - _tear * _pack.width;
      host.fx.burst(Offset(x, _tearY), Pal.white, count: 5, speed: 160, size: 4, colors: const [Color(0xFFDDE6FF), Color(0xFFFFE27A), Color(0xFFFF9EE0)], shape: PartShape.square);
    }
    if (_tear >= .92) {
      _tear = 1;
      _stripT = 0;
      _setPh(_Ph.rise);
      host.sfx(Sfx.rip, rate: 1.1);
      host.sfx(Sfx.whoosh);
      host.shake(8);
      host.punch(.05);
      host.fx.burst(Offset(180, _tearY), Pal.white, count: 40, speed: 380, colors: _rainbow, shape: PartShape.confetti, gravity: 400);
      host.fx.pop(host.tr('rip', 'RIP!'), const Offset(180, 170), color: Pal.yellow, size: 40);
    }
  }

  void _next(double dir) {
    if (_ph != _Ph.cards) return;
    if (_top < 4) {
      _flying.add(_Flying(_top, dir == 0 ? 1 : dir));
      _top++;
      host.sfx(Sfx.swipe, rate: .9 + _top * .08);
      host.sfx(Sfx.flip, volume: .6);
      host.fx.sparkle(_cardC, count: 6, radius: 70, color: const Color(0xFFBFE8FF));
      if (_top == 4) {
        host.sfx(Sfx.rarityUp);
        host.sfx(Sfx.heartbeat);
        host.shake(4);
        host.setMusicVolume(.3);
      }
    } else {
      _setPh(_Ph.flip);
      _flipT = 0;
      host.sfx(Sfx.flip);
      host.sfx(Sfx.drumroll, volume: .6);
      host.setMusicVolume(1);
    }
  }

  void _rub(Offset p, double dist) {
    if (_ph != _Ph.rub) return;
    _tilt = Offset(((p.dx - _cardC.dx) / 110).clamp(-1.0, 1.0), ((p.dy - _cardC.dy) / 150).clamp(-1.0, 1.0));
    final before = _value;
    _value = math.min(1, _value + dist / 1250);
    if (_rubSfx <= 0) {
      _rubSfx = .08;
      host.sfx(Sfx.sparkle, volume: .35, rate: 1 + _value * .8);
      host.fx.sparkle(p, count: 3, radius: 18, color: _rainbow[randInt(7)]);
    }
    for (final m in const [.25, .5, .75]) {
      if (before < m && _value >= m) {
        host.sfx(Sfx.coins, volume: .6, rate: 1 + m);
        host.shake(3 + m * 6);
        host.fx.coins(const Offset(180, 560), count: 8, speed: 500);
      }
    }
  }

  // --------------------------------------------------------------- render --

  @override
  void render(Canvas c) {
    _bg(c);
    switch (_ph) {
      case _Ph.tear:
        _drawPack(c, 0);
        _hint(c);
      case _Ph.rise:
        _drawPack(c, _phT / .7);
        _stack(c, M.easeOutBack(M.clamp01(_phT / .7)));
      case _Ph.cards:
        _drawPack(c, 1);
        _stack(c, 1);
        if (_top == 0 && _phT > .6 || _phT > 2.5) {
          final k = (_t * 1.2) % 1;
          D.hand(c, Offset(120 + k * 120, 470), _t);
          D.arrow(c, const Offset(180, 530), const Offset(1, 0), 90, Pal.yellow, width: 9);
        }
      case _Ph.flip:
        _flipCard(c);
      case _Ph.rub:
      case _Ph.done:
        _holo(c, _cardC, _cw * 1.08, _tilt);
        _appraisal(c);
    }
    _drawFlying(c);
    _strip(c);
  }

  void _bg(Canvas c) {
    D.gradientBg(c, const [Color(0xFF1B0A45), Color(0xFF0C0626), Color(0xFF200A3A)]);
    // neon grid floor
    final gp = D.stroke(const Color(0x4433D6FF), 1.5);
    for (var i = 0; i < 8; i++) {
      final y = 520 + i * i * 2.2 + ((_t * 14) % 8);
      c.drawLine(Offset(0, y), Offset(360, y), gp);
    }
    for (var i = -7; i <= 7; i++) {
      c.drawLine(Offset(180 + i * 16.0, 518), Offset(180 + i * 60.0, 640), gp);
    }
    // spotlight
    c.drawCircle(const Offset(180, 330), 230, Paint()
      ..shader = ui.Gradient.radial(const Offset(180, 330), 230, const [Color(0x55A060FF), Color(0x00000000)], const [0, 1]));
    final lvl = _ph.index >= _Ph.flip.index || (_ph == _Ph.cards && _top == 4) ? 1.0 : .35;
    D.rays(c, const Offset(180, 330), 600, Color.fromRGBO(255, 255, 255, .05 * lvl + .02), count: 14, t: _t * .3);
    for (var i = 0; i < 18; i++) {
      final x = (i * 97 + 13) % 360.0;
      final y = 50 + ((i * 173) % 560) + math.sin(_t + i) * 6;
      c.drawCircle(Offset(x, y), 2 + (i % 3).toDouble(), D.fill(D.hsv(i * 30.0 + _t * 40, .5, 1, .35 + .3 * M.wave(_t + i * .3))));
    }
  }

  // ---- pack ----

  Path _packPath(double top) {
    final r = _pack;
    final p = Path()..moveTo(r.left, top);
    // crimped zig-zag top
    const teeth = 17;
    for (var i = 0; i <= teeth; i++) {
      final x = r.left + r.width * i / teeth;
      p.lineTo(x, top + (i.isEven ? 0 : 6));
    }
    p
      ..lineTo(r.right, r.bottom - 6)
      ..lineTo(r.left, r.bottom - 6)
      ..close();
    return p;
  }

  void _foil(Canvas c, Path path, Rect r) {
    c.drawPath(path, Paint()
      ..shader = ui.Gradient.linear(r.topLeft, r.bottomRight,
          const [Color(0xFF3A1A8C), Color(0xFF7A3AE0), Color(0xFF2A5AD9), Color(0xFF9A2AB0), Color(0xFF3A1A8C)], const [0, .3, .5, .75, 1]));
    c.save();
    c.clipPath(path);
    // holographic diagonal rainbow
    final sx = math.sin(_t * 1.4) * 60;
    c.drawRect(r, Paint()
      ..shader = ui.Gradient.linear(r.topLeft + Offset(sx, 0), r.bottomRight + Offset(sx, 0), _rainbow.map((e) => e.withValues(alpha: .28)).toList(), _stops, ui.TileMode.mirror)
      ..blendMode = BlendMode.plus);
    // moving sheen band
    final bx = r.left - 80 + ((_t * 160) % (r.width + 200));
    c.drawPath(
        Path()
          ..moveTo(bx, r.top)
          ..lineTo(bx + 40, r.top)
          ..lineTo(bx - 60, r.bottom)
          ..lineTo(bx - 100, r.bottom)
          ..close(),
        D.fill(const Color(0x55FFFFFF)));
    c.restore();
  }

  void _drawPack(Canvas c, double out) {
    final k = M.clamp01(out);
    final dy = M.easeInOut(k) * 180;
    final alpha = _ph.index >= _Ph.cards.index ? .9 : 1.0;
    c.save();
    c.translate(0, dy);
    if (alpha < 1) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    final r = _pack;
    c.drawRRect(RRect.fromRectAndRadius(r.inflate(10), const Radius.circular(20)), _glow(const Color(0x887A5CFF), 18));
    final body = _packPath(_tearY);
    _foil(c, body, r);
    // pack art
    final ac = Offset(180, 350 + math.sin(_t * 2) * 3);
    c.drawCircle(ac, 62, _glow(const Color(0x99FFE23F), 16));
    D.rays(c, ac, 90, const Color(0x44FFFFFF), count: 12, t: _t);
    D.star(c, ac, 52, const Color(0xFFFFD23F), border: Pal.ink);
    D.star(c, ac, 30, const Color(0xFFFF5FC8));
    D.text(c, 'EX', ac + const Offset(0, 4), size: 26, color: Pal.white, stroke: Pal.ink, strokeWidth: 5, italic: true);
    D.rrect(c, Rect.fromLTWH(r.left + 18, r.bottom - 76, r.width - 36, 44), 12, const Color(0xCC12062A), border: const Color(0xFFFFE27A), borderWidth: 2.5);
    D.text(c, '★★★★★', Offset(180, r.bottom - 54), size: 20, color: Pal.yellow, stroke: Pal.ink, strokeWidth: 4);
    c.drawPath(body, D.stroke(Pal.ink, 4));
    // the unripped strip
    if (_stripT < 0) _drawStripInPlace(c);
    if (alpha < 1) c.restore();
    c.restore();
  }

  Path _stripPath() {
    final r = _pack;
    final p = Path()..moveTo(r.left, r.top);
    const teeth = 17;
    for (var i = 0; i <= teeth; i++) {
      p.lineTo(r.left + r.width * i / teeth, r.top + (i.isEven ? 0 : 6));
    }
    p.lineTo(r.right, _tearY);
    for (var i = 24; i >= 0; i--) {
      p.lineTo(r.left + r.width * i / 24, _tearY + (i.isEven ? 3 : -3));
    }
    return p..close();
  }

  void _drawStripInPlace(Canvas c) {
    final r = _pack;
    final strip = _stripPath();
    final sr = Rect.fromLTRB(r.left, r.top, r.right, _tearY + 4);
    final tx = _tearDir > 0 ? r.left + _tear * r.width : r.right - _tear * r.width;
    // intact part
    c.save();
    c.clipRect(_tearDir > 0 ? Rect.fromLTRB(tx, 0, 400, 640) : Rect.fromLTRB(-40, 0, tx, 640));
    _foil(c, strip, sr);
    c.drawPath(strip, D.stroke(Pal.ink, 4));
    c.restore();
    // peeled part, lifting up around the tear point
    if (_tear > 0) {
      c.save();
      c.translate(tx, _tearY);
      c.rotate(-_tearDir * _tear * .5);
      c.translate(-tx, -_tearY - _tear * 10);
      c.clipRect(_tearDir > 0 ? Rect.fromLTRB(-40, 0, tx, 640) : Rect.fromLTRB(tx, 0, 400, 640));
      _foil(c, strip, sr);
      c.drawPath(strip, D.fill(const Color(0x33FFFFFF)));
      c.drawPath(strip, D.stroke(Pal.ink, 4));
      c.restore();
      // white torn edge glow
      c.drawLine(Offset(_tearDir > 0 ? r.left : tx, _tearY), Offset(_tearDir > 0 ? tx : r.right, _tearY), _glow(const Color(0xCCFFFFFF), 4)..strokeWidth = 4);
    } else {
      // dashed "tear here" line
      final dp = D.stroke(Color.fromRGBO(255, 255, 255, .5 + .5 * M.wave(_t, 2)), 3);
      for (var x = r.left + 6; x < r.right - 6; x += 16) {
        c.drawLine(Offset(x, _tearY), Offset(x + 8, _tearY), dp);
      }
    }
  }

  void _strip(Canvas c) {
    if (_stripT < 0 || _stripT > 1.4) return;
    final t = _stripT;
    c.save();
    c.translate(180 + _tearDir * t * 260, 222 - t * 420 + t * t * 500);
    c.rotate(_tearDir * t * 6);
    c.translate(-180, -222);
    final r = _pack;
    _foil(c, _stripPath(), Rect.fromLTRB(r.left, r.top, r.right, _tearY));
    c.drawPath(_stripPath(), D.stroke(Pal.ink, 4));
    c.restore();
  }

  // ---- cards ----

  void _stack(Canvas c, double k) {
    // cards under the top one
    final rise = (1 - k) * 200;
    for (var i = 4; i >= _top; i--) {
      final depth = (i - _top).toDouble();
      final o = _cardC + Offset(depth * 3, depth * 5 + rise);
      if (i == 4) {
        _back(c, o, _cw, glow: _top == 4 ? 1 : .25 + depth * 0);
      } else {
        _common(c, o, _cw, i);
      }
    }
  }

  void _drawFlying(Canvas c) {
    for (final f in _flying) {
      if (f.t > .9) {
        // thumbnail row at the bottom
        final o = Offset(66 + f.idx * 30.0, 604);
        c.save();
        c.translate(o.dx, o.dy);
        c.rotate((f.idx - 1.5) * .12);
        c.translate(-o.dx, -o.dy);
        _common(c, o, 34, f.idx);
        c.restore();
        continue;
      }
      final u = f.t / .9;
      final a = Offset.lerp(_cardC, Offset(66 + f.idx * 30.0, 604), M.easeInOut(u))!;
      final o = a + Offset(f.dir * math.sin(u * math.pi) * 160, -math.sin(u * math.pi) * 60);
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(f.dir * u * math.pi * 2 + (f.idx - 1.5) * .12 * u);
      c.translate(-o.dx, -o.dy);
      _common(c, o, M.lerp(_cw, 34, M.easeInOut(u)), f.idx);
      c.restore();
    }
  }

  static const _typeCols = <Color>[Color(0xFFFF6A3D), Color(0xFF3DA5FF), Color(0xFF4CD964), Color(0xFFFFD23F)];

  void _common(Canvas c, Offset o, double w, int i) {
    final s = w / 100;
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s);
    final type = _types[i % 4];
    final col = _typeCols[type];
    const r = Rect.fromLTWH(-50, -70, 100, 140);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(7));
    c.drawRRect(rr, D.fill(const Color(0xFFFFE27A)));
    c.drawRRect(RRect.fromRectAndRadius(r.deflate(5), const Radius.circular(4)), D.fill(Color.lerp(col, Pal.white, .55)!));
    c.drawRRect(rr, D.stroke(Pal.ink, 3));
    // header: name bar + HP
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-42, -64, 50, 7), const Radius.circular(3)), D.fill(const Color(0x66000000)));
    D.text(c, '${host.tr('hp', 'HP')} ${30 + (i * 17 + type * 10) % 50}', const Offset(40, -60), size: 9, color: const Color(0xFFD01A2A), anchor: Alignment.centerRight);
    // art
    const art = Rect.fromLTWH(-42, -52, 84, 58);
    c.drawRect(art, Paint()..shader = ui.Gradient.linear(art.topCenter, art.bottomCenter, [Color.lerp(col, Pal.white, .7)!, col], const [0, 1]));
    c.save();
    c.clipRect(art);
    D.blob(c, const Offset(0, -18), 19, Color.lerp(col, Pal.white, .15)!, face: const [Face.angry, Face.happy, Face.sleepy, Face.smug][i % 4]);
    _typeIcon(c, const Offset(30, -42), type, 7);
    c.restore();
    c.drawRect(art, D.stroke(Pal.ink, 2));
    // attacks
    for (var k = 0; k < 2; k++) {
      final y = 20.0 + k * 22;
      _typeIcon(c, Offset(-36, y), type, 5);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-26, y - 3, 40, 6), const Radius.circular(3)), D.fill(const Color(0x55000000)));
      D.text(c, '${(k + 1) * 10 + i * 10}', Offset(38, y), size: 11, color: Pal.ink, anchor: Alignment.centerRight);
    }
    c.restore();
  }

  void _typeIcon(Canvas c, Offset o, int type, double r) {
    c.drawCircle(o, r, D.fill(_typeCols[type]));
    c.drawCircle(o, r, D.stroke(Pal.ink, 1.5));
    final p = D.fill(Pal.white);
    switch (type) {
      case 0:
        c.drawPath(
            Path()
              ..moveTo(o.dx, o.dy - r * .6)
              ..quadraticBezierTo(o.dx + r * .5, o.dy, o.dx, o.dy + r * .5)
              ..quadraticBezierTo(o.dx - r * .5, o.dy, o.dx, o.dy - r * .6),
            p);
      case 1:
        c.drawCircle(o + Offset(0, r * .15), r * .35, p);
      case 2:
        c.drawOval(Rect.fromCenter(center: o, width: r * .8, height: r * 1.2), p);
      default:
        c.drawPath(
            Path()
              ..moveTo(o.dx + r * .2, o.dy - r * .6)
              ..lineTo(o.dx - r * .3, o.dy + r * .1)
              ..lineTo(o.dx + r * .1, o.dy + r * .1)
              ..lineTo(o.dx - r * .2, o.dy + r * .6)
              ..lineTo(o.dx + r * .35, o.dy - r * .1)
              ..lineTo(o.dx, o.dy - r * .1)
              ..close(),
            p);
    }
  }

  void _back(Canvas c, Offset o, double w, {double glow = 0}) {
    final h = w * 1.4;
    final r = Rect.fromCenter(center: o, width: w, height: h);
    if (glow > .5) {
      final pulse = .6 + .4 * M.wave(_t, 3);
      for (var i = 0; i < 3; i++) {
        D.rays(c, o, 420, _rainbow[i * 2 + 1].withValues(alpha: .22 * pulse), count: 10, t: _t * (1 + i * .4) + i, width: .25);
      }
      c.drawRRect(RRect.fromRectAndRadius(r.inflate(14), const Radius.circular(18)), _glow(D.hsv(_t * 240, .7, 1, .9 * pulse), 18));
    }
    final shake = glow > .5 ? Offset(math.sin(_t * 60) * 1.5, 0) : Offset.zero;
    final rr = RRect.fromRectAndRadius(r.shift(shake), Radius.circular(w * .07));
    c.drawRRect(rr, Paint()..shader = ui.Gradient.radial(o, h * .6, const [Color(0xFF5A8CFF), Color(0xFF2A2A9C), Color(0xFF12125A)], const [0, .55, 1]));
    c.drawRRect(rr, D.stroke(const Color(0xFFFFE27A), w * .05));
    c.drawRRect(rr, D.stroke(Pal.ink, 3));
    c.drawCircle(o + shake, w * .26, D.fill(const Color(0xFFFF3B5C)));
    c.drawArc(Rect.fromCircle(center: o + shake, radius: w * .26), 0, math.pi, true, D.fill(Pal.white));
    c.drawLine(o + shake - Offset(w * .26, 0), o + shake + Offset(w * .26, 0), D.stroke(Pal.ink, w * .04));
    c.drawCircle(o + shake, w * .08, D.fill(Pal.white));
    c.drawCircle(o + shake, w * .26, D.stroke(Pal.ink, 3));
    c.drawCircle(o + shake, w * .08, D.stroke(Pal.ink, 3));
    if (glow > .5) {
      // light leaking from the edges
      c.drawRRect(rr, D.stroke(Color.fromRGBO(255, 255, 255, .5 + .5 * M.wave(_t, 4)), 3));
      D.text(c, host.tr('tap', 'TAP!'), o + Offset(0, h / 2 + 26), size: 22, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _flipCard(Canvas c) {
    final u = M.clamp01(_flipT / .9);
    final sx = math.cos(u * math.pi).abs();
    final grow = 1 + .08 * math.sin(u * math.pi);
    c.save();
    c.translate(_cardC.dx, _cardC.dy);
    c.scale(math.max(.02, sx) * grow, grow);
    c.translate(-_cardC.dx, -_cardC.dy);
    if (u < .5) {
      _back(c, _cardC, _cw, glow: 1);
    } else {
      _holo(c, _cardC, _cw, Offset.zero);
    }
    c.restore();
    if (_flipped) {
      final k = M.clamp01((_flipT - .45) / .6);
      for (var i = 0; i < 3; i++) {
        D.rays(c, _cardC, 700, _rainbow[i * 2].withValues(alpha: .3 * (1 - k)), count: 12, t: _t * (1 + i * .3), width: .35);
      }
    }
  }

  /// The legendary holo card. [tilt] (-1..1) drives the parallax sheen.
  void _holo(Canvas c, Offset o, double w, Offset tilt) {
    final s = w / 100;
    // back glow
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: w + 24, height: w * 1.4 + 24), const Radius.circular(18)),
        _glow(D.hsv(_t * 200, .7, 1, .8), 20));
    c.save();
    c.translate(o.dx, o.dy);
    // fake 3D tilt: skew + squash toward the finger
    c.transform(_Skew.skew(tilt.dx * .12, tilt.dy * .08));
    c.scale(s * (1 - tilt.dx.abs() * .06), s * (1 - tilt.dy.abs() * .04));
    const r = Rect.fromLTWH(-50, -70, 100, 140);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(7));
    // gold frame
    c.drawRRect(rr, Paint()..shader = ui.Gradient.linear(r.topLeft, r.bottomRight, const [Color(0xFFFFF4B0), Color(0xFFFFC53D), Color(0xFFFFF4B0), Color(0xFFC77A00)], const [0, .35, .6, 1]));
    c.drawRRect(RRect.fromRectAndRadius(r.deflate(5), const Radius.circular(4)), D.fill(const Color(0xFF2A0F5C)));
    // art
    const art = Rect.fromLTWH(-42, -58, 84, 72);
    c.save();
    c.clipRect(art);
    c.drawRect(art, Paint()..shader = ui.Gradient.radial(const Offset(0, -24), 60, const [Color(0xFFFFF4C0), Color(0xFFFF5FC8), Color(0xFF3A0F7C)], const [0, .45, 1]));
    D.rays(c, const Offset(0, -24), 80, const Color(0x55FFFFFF), count: 12, t: _t * 1.2);
    _dragon(c, const Offset(0, -18));
    c.restore();
    c.drawRect(art, D.stroke(Pal.ink, 2));
    // text area
    D.text(c, '${host.tr('hp', 'HP')} 999', const Offset(40, -64), size: 8, color: Pal.yellow, anchor: Alignment.centerRight);
    for (var k = 0; k < 2; k++) {
      final y = 26.0 + k * 20;
      c.drawCircle(Offset(-36, y), 5, D.fill(Pal.yellow));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-26, y - 3, 34, 6), const Radius.circular(3)), D.fill(const Color(0x66FFFFFF)));
      D.text(c, k == 0 ? '999' : '777', Offset(40, y), size: 12, color: Pal.yellow, anchor: Alignment.centerRight);
    }
    // HOLO rainbow sheen following the tilt (additive)
    c.save();
    c.clipRRect(rr);
    final shift = Offset(tilt.dx * 80 + math.sin(_t * .8) * 10, tilt.dy * 80);
    c.drawRect(r, Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.linear(r.topLeft + shift, r.bottomRight * .6 + shift, _rainbow.map((e) => e.withValues(alpha: .28)).toList(), _stops, ui.TileMode.mirror));
    // specular band
    final bx = tilt.dx * 70 - tilt.dy * 30;
    c.drawPath(
        Path()
          ..moveTo(bx - 30, -80)
          ..lineTo(bx + 5, -80)
          ..lineTo(bx - 25, 80)
          ..lineTo(bx - 60, 80)
          ..close(),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = const Color(0x88FFFFFF));
    // glitter
    for (var i = 0; i < 16; i++) {
      final gx = -44 + (i * 37 % 88).toDouble();
      final gy = -64 + (i * 53 % 128).toDouble();
      final tw = math.sin(_t * 5 + i * 1.7 + tilt.dx * 4);
      if (tw > .5) c.drawPath(D.starPath(Offset(gx, gy), 4 * tw, 1, points: 4, rotation: 0), D.fill(Pal.white));
    }
    c.restore();
    c.drawRRect(rr, D.stroke(Pal.ink, 3));
    // rarity badge
    D.star(c, const Offset(-40, -62), 9, Pal.yellow, border: Pal.ink);
    c.restore();
  }

  void _dragon(Canvas c, Offset o) {
    final flap = math.sin(_t * 6) * .2;
    // flames behind
    D.flame(c, o + const Offset(-26, 34), 30, _t);
    D.flame(c, o + const Offset(26, 34), 30, _t + 1);
    // wings
    for (final sx in [-1.0, 1.0]) {
      c.save();
      c.translate(o.dx + sx * 12, o.dy - 2);
      c.scale(sx, 1);
      c.rotate(-.2 + flap);
      final wing = Path()
        ..moveTo(0, 0)
        ..lineTo(34, -26)
        ..lineTo(30, -8)
        ..lineTo(40, -4)
        ..lineTo(30, 6)
        ..lineTo(36, 14)
        ..lineTo(8, 12)
        ..close();
      c.drawPath(wing, D.fill(const Color(0xFFFF8A1F)));
      c.drawPath(wing, D.stroke(Pal.ink, 2));
      c.restore();
    }
    // horns
    for (final sx in [-1.0, 1.0]) {
      final h = Path()
        ..moveTo(o.dx + sx * 8, o.dy - 16)
        ..quadraticBezierTo(o.dx + sx * 16, o.dy - 34, o.dx + sx * 22, o.dy - 30)
        ..lineTo(o.dx + sx * 15, o.dy - 12)
        ..close();
      c.drawPath(h, D.fill(const Color(0xFFFFF4C0)));
      c.drawPath(h, D.stroke(Pal.ink, 2));
    }
    D.blob(c, o, 19, const Color(0xFFFFB020), face: Face.smug);
    // crown
    D.star(c, o + const Offset(0, -24), 7, Pal.white);
  }

  void _appraisal(Canvas c) {
    // value panel
    const r = Rect.fromLTWH(22, 500, 316, 84);
    D.rrect(c, r, 18, const Color(0xEE14072E), border: const Color(0xFFFFE27A), borderWidth: 3);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(18)), _glow(const Color(0x66FFE23F), 10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5);
    D.text(c, host.tr('value', 'VALUE'), const Offset(40, 516), size: 13, color: const Color(0xFFFFD6F0), anchor: Alignment.centerLeft);
    final v = (_ease(_valueDisp) * 1000000).round();
    final done = _ph == _Ph.done;
    final digits = _fmt(v);
    final sc = done ? 1 + .08 * math.sin(_doneT * 18) * math.max(0, 1 - _doneT) : 1.0;
    c.save();
    c.translate(180, 550);
    c.scale(sc);
    D.coin(c, Offset(-D.text(c, '$digits${done ? '!?' : ''}', const Offset(-9999, -9999), size: 34, italic: true).width / 2 - 22, 0), 15, spin: _t);
    D.text(c, '$digits${done ? '!?' : ''}', const Offset(12, 0), size: 34, color: done ? _rainbow[(_t * 12).floor() % 7] : Pal.yellow, stroke: Pal.ink, strokeWidth: 7, italic: true);
    c.restore();
    D.bar(c, const Rect.fromLTWH(40, 572, 280, 6), _valueDisp, Pal.pink);
    if (_ph == _Ph.rub && (_phT < 3 || !host.pointerDown && _phT > 1.5)) {
      final k = _t * 3;
      final p = _cardC + Offset(math.sin(k) * 60, math.cos(k * 2) * 40);
      D.hand(c, p, _t);
      D.title(c, host.tr('rub', 'RUB!'), const Offset(180, 110), size: 36, scale: 1 + .06 * math.sin(_t * 8));
    }
    if (_ph == _Ph.done) {
      D.title(c, host.tr('jackpot', 'JACKPOT!'), const Offset(180, 108), size: 40, color: _rainbow[(_t * 10).floor() % 7], scale: M.easeOutBack(M.clamp01(_doneT / .4)));
    }
  }

  static double _ease(double v) => v * v * (3 - 2 * v) * .7 + v * v * v * .3;

  static String _fmt(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  void _hint(Canvas c) {
    if (_tear > .3) return;
    final k = (_t * 1.1) % 1;
    final x = _tearDir > 0 || _tear == 0 ? _pack.left + k * _pack.width : _pack.right - k * _pack.width;
    D.hand(c, Offset(x, _tearY + 4), _t);
    D.arrow(c, const Offset(180, _tearY - 34), const Offset(1, 0), 150, Pal.yellow, width: 9);
    D.title(c, host.tr('swipe', 'SWIPE!'), const Offset(180, 150), size: 34, scale: 1 + .05 * math.sin(_t * 8));
  }
}

/// Tiny helper for a 2D skew matrix (column-major 4x4).
abstract final class _Skew {
  static Float64List skew(double sx, double sy) => Float64List.fromList([
        1, sy, 0, 0, //
        sx, 1, 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 1,
      ]);
}
