import '../engine/engine.dart';

/// No.150 You Are Visitor 999,999! (SUPER RARE) — a screaming 90s web page.
/// The prize bounces around like the DVD logo while rival visitors' cursors
/// chase it. Tap it 3 times before the hit counter rolls over to 1,000,000.
/// Rivals that grab it — and your own missed clicks — bump the counter!
class G150 extends MiniGame {
  static const _box = Rect.fromLTWH(8, 160, 344, 388);
  static const _limit = 1000000;

  static final Sprite _cursor = Sprite(const [
    'K.........',
    'KK........',
    'KWK.......',
    'KWWK......',
    'KWWWK.....',
    'KWWWWK....',
    'KWWWWWK...',
    'KWWWWWWK..',
    'KWWWWWWWK.',
    'KWWWWKKKKK',
    'KWWKWWK...',
    'KWK.KWWK..',
    'KK..KWWK..',
    'K....KWWK.',
    '.....KKK..',
  ], {'K': Pal.ink, 'W': Pal.white});

  double _t = 0;
  int _count = 999948;
  double _tickT = 0;
  double _counterFlash = 0;
  int _caught = 0;
  Offset _pos = const Offset(180, 340);
  Offset _vel = const Offset(150, 120);
  double _hue = 0;
  double _spin = 0;
  double _prizeIn = 0; // spawn-in anim 0..1
  double _respawn = 0;
  double _corner = 0;
  double _bonk = 0;
  final _rivals = <_Rival>[];
  final _flyers = <_Flyer>[];
  double _clickHere = 0;
  double _endT = 0;
  bool _lost = false;
  double _stealFlash = 0;
  Offset _stealAt = Offset.zero;

  @override
  Color get backdrop => const Color(0xFF000033);

  @override
  void init() {
    _vel = Offset.fromDirection(rand(.5, 1.1) + (chance(.5) ? pi / 2 : 0), 150);
    for (var i = 0; i < 2; i++) {
      _addRival();
    }
  }

  void _addRival() {
    final names = ['xX_d00d_Xx', 'CoolGuy97', 'n00b', 'WebMstr'];
    final p = switch (randInt(3)) { 0 => Offset(-20, rand(200, 520)), 1 => Offset(380, rand(200, 520)), _ => Offset(rand(40, 320), 600) };
    _rivals.add(_Rival(p, names[_rivals.length % names.length], pick([Pal.pink, Pal.lime, Pal.orange, Pal.sky])));
  }

  double get _speed => (150 + _caught * 45) * host.speed;
  bool get _prizeLive => _respawn <= 0 && !host.finished;

  void _bump(int n, Offset at) {
    _count = min(_limit, _count + n);
    _counterFlash = 1;
    if (_count >= _limit && !host.finished) {
      _lost = true;
      host.sfx(Sfx.buzzer);
      host.sfx(Sfx.aww, volume: .8);
      host.shake(10, .5);
      host.flash(Pal.red, .3);
      host.lose();
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _counterFlash = M.approach(_counterFlash, 0, 6, dt);
    _corner = max(0, _corner - dt);
    _bonk = M.approach(_bonk, 0, 8, dt);
    _clickHere = M.approach(_clickHere, 0, 8, dt);
    _stealFlash = max(0, _stealFlash - dt);
    for (final f in _flyers) {
      f.t += dt;
    }
    if (host.finished) {
      _endT += dt;
      if (!_lost && (_endT * 8).floor() != ((_endT - dt) * 8).floor()) {
        host.fx.coins(Offset(rand(40, 320), 640), count: 4, speed: 700);
      }
      return;
    }
    // natural visitor ticks
    _tickT += dt * host.speed;
    if (_tickT >= .3) {
      _tickT -= .3;
      _bump(1, Offset.zero);
      if (_limit - _count <= 10) host.sfx(Sfx.tick, volume: .5, rate: 1.4);
    }
    if (host.finished) return;
    // prize
    if (_respawn > 0) {
      _respawn -= dt;
      if (_respawn <= 0) {
        _pos = _box.center;
        _vel = Offset.fromDirection(rand(0, pi * 2), _speed);
        if (_vel.dx.abs() < 60) _vel = Offset(90 * (_vel.dx >= 0 ? 1 : -1), _vel.dy);
        _prizeIn = 0;
        host.sfx(Sfx.magic, rate: 1.2);
      }
    } else {
      _prizeIn = min(1, _prizeIn + dt * 3);
      _spin += dt * 3;
      _pos += _vel * dt;
      final hw = _half.width, hh = _half.height;
      var hitX = false, hitY = false;
      if (_pos.dx - hw < _box.left || _pos.dx + hw > _box.right) {
        _vel = Offset(-_vel.dx, _vel.dy);
        _pos = Offset(_pos.dx.clamp(_box.left + hw, _box.right - hw), _pos.dy);
        hitX = true;
      }
      if (_pos.dy - hh < _box.top || _pos.dy + hh > _box.bottom) {
        _vel = Offset(_vel.dx, -_vel.dy);
        _pos = Offset(_pos.dx, _pos.dy.clamp(_box.top + hh, _box.bottom - hh));
        hitY = true;
      }
      if (hitX || hitY) {
        _hue = (_hue + 67) % 360;
        _bonk = 1;
        host.sfx(Sfx.bounce, volume: .35, rate: rand(1.1, 1.4));
      }
      if (hitX && hitY) {
        _corner = 1.4;
        host.sfx(Sfx.rarityUp);
        host.fx.confetti(at: _pos, count: 40);
        host.addScore(500, _pos + const Offset(0, -40));
      }
      _vel = _vel / _vel.distance * _speed;
    }
    // rival visitors chase the prize
    for (final r in _rivals) {
      final target = _prizeLive ? _pos + _vel * .35 : _box.center + Offset(sin(_t + r.name.length) * 80, cos(_t * 1.3) * 60);
      final d = target - r.pos;
      final sp = (70 + _caught * 22) * host.speed;
      if (d.distance > 1) r.pos += d / d.distance * min(sp * dt, d.distance);
      r.pos += Offset(sin(_t * 5 + r.name.length) * 20 * dt, cos(_t * 4) * 20 * dt);
      r.gloat = max(0, r.gloat - dt);
      if (_prizeLive && _prizeIn >= 1 && (r.pos - _pos).distance < 30) {
        r.gloat = 1;
        _stealFlash = 1;
        _stealAt = _pos;
        host.sfx(Sfx.wrong);
        host.sfx(Sfx.whoosh, rate: .8);
        host.shake(5);
        host.fx.burst(_pos, Pal.red, count: 14, speed: 200, shape: PartShape.star);
        _bump(6, _pos);
        // prize warps away
        _pos = Offset(rand(_box.left + 60, _box.right - 60), rand(_box.top + 60, _box.bottom - 60));
        while ((_pos - r.pos).distance < 140) {
          _pos = Offset(rand(_box.left + 60, _box.right - 60), rand(_box.top + 60, _box.bottom - 60));
        }
        _prizeIn = 0;
        r.pos += (r.pos - _box.center) / max(1, (r.pos - _box.center).distance) * 60;
      }
    }
  }

  Size get _half => switch (_caught % 3) { 0 => const Size(20, 32), 1 => const Size(44, 22), _ => const Size(34, 28) };

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    if (_prizeLive && (p - _pos).distance < 48) {
      _catch();
      return;
    }
    if (_clickRect.contains(p)) {
      _clickHere = 1;
      host.sfx(Sfx.cash, volume: .6);
      host.fx.pop('+3', p + const Offset(0, -20), color: Pal.red, size: 24);
      _bump(3, p);
      return;
    }
    // missed click = one more page view on the counter, lol
    host.sfx(Sfx.click, volume: .5);
    host.fx.pop('+1', p, color: const Color(0xFFFF8080), size: 18, life: .5);
    _bump(1, p);
  }

  static const _clickRect = Rect.fromLTWH(236, 562, 116, 34);

  void _catch() {
    _caught++;
    _flyers.add(_Flyer(_pos, _caught - 1));
    host.sfx(Sfx.cash);
    host.sfx(Sfx.ssr, volume: .7, rate: 1 + _caught * .1);
    host.hitStop(.08);
    host.shake(6);
    host.punch(.04);
    host.flash(Pal.yellow, .15);
    host.fx.coins(_pos, count: 18);
    host.fx.burst(_pos, Pal.yellow, count: 22, speed: 320, shape: PartShape.star, colors: Pal.candy);
    host.fx.pop(host.tr('winner', 'WINNER!'), _pos + const Offset(0, -50), color: Pal.yellow, size: 34, life: 1);
    host.addScore(1000 * _caught, _pos);
    if (_caught >= 3) {
      host.sfx(Sfx.fanfare);
      host.fx.confetti(count: 120);
      final margin = _limit - _count;
      host.win(stars: margin >= 18 ? 3 : (margin >= 8 ? 2 : 1));
    } else {
      _respawn = .55;
      _addRival();
    }
  }

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action' && _prizeLive) _catch();
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    // tiled starfield wallpaper
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), D.fill(const Color(0xFF000033)));
    for (var ty = 0; ty < 11; ty++) {
      for (var tx = 0; tx < 6; tx++) {
        final o = Offset(tx * 60.0, ty * 60.0);
        final tw = ((tx + ty + (_t * 3).floor()) % 3 == 0);
        c.drawRect(Rect.fromLTWH(o.dx + 10, o.dy + 14, 2, 2), D.fill(Pal.white));
        c.drawRect(Rect.fromLTWH(o.dx + 42, o.dy + 40, 2, 2), D.fill(const Color(0xFFAAAAFF)));
        if (tw) {
          c.drawPath(D.starPath(o + const Offset(30, 22), 5, 1.2, points: 4, rotation: 0), D.fill(Pal.yellow));
        } else {
          c.drawRect(Rect.fromLTWH(o.dx + 29, o.dy + 21, 2, 2), D.fill(Pal.yellow));
        }
      }
    }
    _renderMarquee(c);
    _renderTitle(c);
    _renderCounter(c);
    _renderBox(c);
    _renderFooter(c);
    if (host.time < 2.2 && _caught == 0 && _prizeLive) D.hand(c, _pos + const Offset(0, 20), _t, size: 38);
    if (host.finished) _renderEnd(c);
  }

  void _renderMarquee(Canvas c) {
    const r = Rect.fromLTWH(0, 40, 360, 24);
    c.drawRect(r, D.fill(const Color(0xFF800000)));
    c.drawRect(Rect.fromLTWH(0, r.top, 360, 2), D.fill(const Color(0xFFFF6060)));
    c.drawRect(Rect.fromLTWH(0, r.bottom - 2, 360, 2), D.fill(const Color(0xFF400000)));
    final msg = '*** ${host.tr('congratulations', 'CONGRATULATIONS!!!')} *** ${host.tr('you_are_visitor', 'YOU ARE VISITOR')} 999,999 *** '
        '${host.tr('claim_prize', 'CLAIM YOUR PRIZE')} *** ';
    c.save();
    c.clipRect(r);
    final w = D.text(c, msg, const Offset(-2000, -2000), size: 14, color: Pal.yellow).width;
    final x = 360 - (_t * 90) % (w + 360);
    D.text(c, msg, Offset(x, r.center.dy), size: 14, color: Pal.yellow, anchor: Alignment.centerLeft);
    c.restore();
  }

  void _renderTitle(Canvas c) {
    final blink = (_t * 4).floor() % 4 != 0;
    if (blink) {
      final col = D.hsv(_t * 300, .9, 1);
      c.save();
      c.translate(180, 90);
      c.rotate(sin(_t * 5) * .03);
      D.text(c, host.tr('congratulations', 'CONGRATULATIONS!!!'), const Offset(0, 3), size: 27, color: Pal.ink, stroke: Pal.ink,
          strokeWidth: 7, maxWidth: 350, italic: true);
      D.text(c, host.tr('congratulations', 'CONGRATULATIONS!!!'), Offset.zero, size: 27, color: col, stroke: Pal.white,
          strokeWidth: 5, maxWidth: 350, italic: true);
      c.restore();
    }
  }

  void _renderCounter(Canvas c) {
    D.text(c, host.tr('you_are_visitor', 'YOU ARE VISITOR'), const Offset(12, 132), size: 12, color: Pal.white,
        anchor: Alignment.centerLeft, maxWidth: 110, align: TextAlign.left);
    final s = _count.toString().padLeft(7, '0');
    const x0 = 130.0;
    for (var i = 0; i < 7; i++) {
      final r = Rect.fromLTWH(x0 + i * 30.0, 116, 26, 34);
      final hot = _limit - _count <= 10;
      c.drawRect(r.inflate(2), D.fill(const Color(0xFF808080)));
      c.drawRect(r, D.fill(const Color(0xFF101010)));
      c.drawRect(Rect.fromLTWH(r.left, r.center.dy - .5, r.width, 1), D.fill(const Color(0xFF303030)));
      final flash = i == 6 && _counterFlash > .3;
      PixelFont.draw(c, s[i], Offset(r.center.dx, r.top + 7), 3.3,
          flash ? Pal.white : (hot ? const Color(0xFFFF4040) : const Color(0xFF40FF60)), align: 0);
    }
    if (_limit - _count <= 10 && !host.finished && (_t * 6).floor().isEven) {
      c.drawRect(const Rect.fromLTWH(126, 112, 216, 42), D.stroke(Pal.red, 3));
    }
  }

  void _renderBox(Canvas c) {
    final r = _box;
    // animated rainbow dashed border
    c.drawRect(r, D.fill(const Color(0x33000000)));
    final per = 2 * (r.width + r.height);
    const seg = 16.0;
    final off = (_t * 60) % seg;
    for (var d = -off; d < per; d += seg) {
      final a = _perimPoint(d), b = _perimPoint(d + seg * .6);
      final col = D.hsv(d / per * 720 + _t * 200, .9, 1);
      c.drawLine(a, b, D.stroke(col, 4));
    }
    // starbursts in the corners
    _starburst(c, const Offset(60, 214), 34, host.tr('new', 'NEW!'), Pal.red, Pal.yellow, _t);
    _starburst(c, const Offset(300, 214), 34, host.tr('free', 'FREE!'), Pal.yellow, Pal.red, -_t * 1.3);
    _starburst(c, const Offset(60, 496), 30, host.tr('hot', 'HOT!'), Pal.orange, Pal.white, _t * .8);
    // under construction sign
    c.save();
    c.translate(292, 500);
    c.rotate(-.1);
    final sign = Path()
      ..moveTo(0, -28)
      ..lineTo(28, 0)
      ..lineTo(0, 28)
      ..lineTo(-28, 0)
      ..close();
    c.drawPath(sign, D.fill(Pal.yellow));
    c.drawPath(sign, D.stroke(Pal.ink, 3));
    D.person(c, const Offset(0, 16), 28, Pal.orange, running: true, run: _t * 10, face: Face.neutral);
    c.restore();
    // stolen flash
    if (_stealFlash > 0) {
      D.text(c, host.tr('stolen', 'STOLEN!'), _stealAt + Offset(0, -20 - (1 - _stealFlash) * 30), size: 24, color: Pal.red, stroke: Pal.white);
    }
    // prize
    if (_prizeLive) _renderPrize(c);
    // rivals
    for (final rv in _rivals) {
      _cursor.draw(c, rv.pos - const Offset(2, 2), scale: 2.6);
      D.rrect(c, Rect.fromLTWH(rv.pos.dx + 14, rv.pos.dy + 30, rv.name.length * 6.5 + 8, 14), 3, rv.color, border: Pal.ink, borderWidth: 1.5);
      D.text(c, rv.name, Offset(rv.pos.dx + 18, rv.pos.dy + 37), size: 10, color: Pal.ink, anchor: Alignment.centerLeft, weight: FontWeight.w700);
      if (rv.gloat > 0) {
        D.text(c, 'LOL', rv.pos + Offset(24, -12 - (1 - rv.gloat) * 16), size: 18, color: Pal.yellow, stroke: Pal.ink);
      }
    }
    if (_corner > 0) {
      final k = M.easeOutBack(((1.4 - _corner) / .3).clamp(0, 1));
      D.title(c, host.tr('corner', 'CORNER!!!'), const Offset(180, 360), size: 40, color: D.hsv(_t * 500, .8, 1), scale: k, rotate: -.1);
    }
  }

  Offset _perimPoint(double d) {
    final r = _box;
    final per = 2 * (r.width + r.height);
    d = d % per;
    if (d < r.width) return Offset(r.left + d, r.top);
    d -= r.width;
    if (d < r.height) return Offset(r.right, r.top + d);
    d -= r.height;
    if (d < r.width) return Offset(r.right - d, r.bottom);
    d -= r.width;
    return Offset(r.left, r.bottom - d);
  }

  void _starburst(Canvas c, Offset o, double r, String label, Color fill, Color text, double rot) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(rot);
    c.drawPath(D.starPath(Offset.zero, r, r * .72, points: 12), D.fill(fill));
    c.drawPath(D.starPath(Offset.zero, r, r * .72, points: 12), D.stroke(Pal.ink, 2.5));
    c.restore();
    final s = 1 + M.wave(_t, 2) * .12;
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s);
    c.rotate(-.2);
    D.text(c, label, Offset.zero, size: r * .42, color: text, stroke: Pal.ink, strokeWidth: 3, maxWidth: r * 1.5);
    c.restore();
  }

  void _renderPrize(Canvas c) {
    final k = M.easeOutBack(_prizeIn);
    final glow = D.hsv(_hue, .8, 1);
    c.save();
    c.translate(_pos.dx, _pos.dy);
    D.rays(c, Offset.zero, 70 * k, glow.withValues(alpha: .45), count: 10, t: _t * 2);
    c.drawCircle(Offset.zero, 40 * k, D.fill(glow.withValues(alpha: .25)));
    final sq = 1 + _bonk * .15;
    c.scale(k * sq, k * (2 - sq));
    _drawPrize(c, _caught % 3, _spin);
    c.restore();
    // price tag
    D.text(c, '\$0.00', _pos + Offset(0, _half.height + 14), size: 13, color: Pal.lime, stroke: Pal.ink);
  }

  void _drawPrize(Canvas c, int kind, double spin) {
    switch (kind) {
      case 0: // smartphone
        c.scale(cos(spin).abs().clamp(.25, 1.0), 1);
        D.rrect(c, const Rect.fromLTWH(-20, -32, 40, 64), 8, const Color(0xFF1B1B24), border: Pal.ink, borderWidth: 3);
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -26, 32, 50), const Radius.circular(4)),
            Paint()..shader = const LinearGradient(colors: [Color(0xFF7A5CFF), Color(0xFFFF5FC8), Color(0xFFFFD23F)],
                begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(const Rect.fromLTWH(-16, -26, 32, 50)));
        D.rrect(c, const Rect.fromLTWH(-6, -30, 12, 3), 1.5, Pal.ink);
        for (var i = 0; i < 6; i++) {
          D.rrect(c, Rect.fromLTWH(-12 + (i % 3) * 9.0, -18 + (i ~/ 3) * 10.0, 7, 7), 2, const Color(0xCCFFFFFF));
        }
        c.drawPath(Path()
          ..moveTo(-16, -26)
          ..lineTo(0, -26)
          ..lineTo(-16, 0)
          ..close(), D.fill(const Color(0x44FFFFFF)));
      case 1: // sports car
        c.scale(1, 1 + sin(spin * 4) * .03);
        final body = Path()
          ..moveTo(-44, 10)
          ..lineTo(-42, -2)
          ..lineTo(-18, -6)
          ..lineTo(-6, -18)
          ..lineTo(16, -18)
          ..lineTo(30, -6)
          ..lineTo(44, -2)
          ..lineTo(44, 10)
          ..close();
        c.drawPath(body, D.fill(Pal.red));
        c.drawPath(Path()
          ..moveTo(-4, -15)
          ..lineTo(14, -15)
          ..lineTo(24, -6)
          ..lineTo(-12, -6)
          ..close(), D.fill(const Color(0xFFBFE9FF)));
        c.drawPath(body, D.stroke(Pal.ink, 3));
        D.line(c, const Offset(-36, 0), const Offset(36, 0), const Color(0x88FFFFFF), 2);
        for (final x in const [-26.0, 28.0]) {
          D.circle(c, Offset(x, 12), 9, Pal.ink);
          D.circle(c, Offset(x, 12), 4, const Color(0xFFDDDDDD));
        }
        D.rrect(c, const Rect.fromLTWH(38, -2, 6, 5), 2, Pal.yellow);
      default: // cash stack
        c.scale(cos(spin * .7).abs().clamp(.35, 1.0), 1);
        for (var i = 0; i < 4; i++) {
          final r = Rect.fromLTWH(-32, 8 - i * 9.0, 64, 14);
          D.rrect(c, r, 3, const Color(0xFF3FAF5A), border: Pal.ink, borderWidth: 2);
          c.drawRect(Rect.fromLTWH(r.left + 26, r.top, 12, r.height), D.fill(const Color(0xFFE8F5E0)));
        }
        D.text(c, '\$', const Offset(0, -18), size: 34, color: Pal.gold, stroke: Pal.ink);
    }
  }

  void _renderFooter(Canvas c) {
    // trophy shelf
    for (var i = 0; i < 3; i++) {
      final r = Rect.fromLTWH(10 + i * 72.0, 556, 66, 42);
      c.drawRect(r, D.fill(const Color(0xFFC0C0C0)));
      c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 2), D.fill(Pal.white));
      c.drawRect(Rect.fromLTWH(r.left, r.bottom - 2, r.width, 2), D.fill(const Color(0xFF404040)));
      c.drawRect(r.deflate(4), D.fill(const Color(0xFF202040)));
      final have = _flyers.where((f) => f.kind == i && f.t > .5).isNotEmpty;
      if (have) {
        c.save();
        c.translate(r.center.dx, r.center.dy);
        c.scale(.42);
        _drawPrize(c, i, _t * 2);
        c.restore();
      } else {
        D.text(c, '?', r.center, size: 22, color: const Color(0x66FFFFFF));
      }
    }
    // flying prizes to the shelf
    for (final f in _flyers) {
      if (f.t > .5) continue;
      final k = M.easeInOut(f.t / .5);
      final to = Offset(43 + f.kind * 72.0, 577);
      final p = Offset.lerp(f.from, to, k)! + Offset(0, -sin(k * pi) * 80);
      c.save();
      c.translate(p.dx, p.dy);
      c.scale(1 - k * .58);
      c.rotate(k * pi * 2);
      _drawPrize(c, f.kind, 0);
      c.restore();
    }
    // CLICK HERE trap button (bevelled)
    final pr = _clickHere > .3;
    final b = _clickRect;
    c.drawRect(b, D.fill(const Color(0xFFC0C0C0)));
    c.drawRect(Rect.fromLTWH(b.left, b.top, b.width, 2), D.fill(pr ? const Color(0xFF404040) : Pal.white));
    c.drawRect(Rect.fromLTWH(b.left, b.top, 2, b.height), D.fill(pr ? const Color(0xFF404040) : Pal.white));
    c.drawRect(Rect.fromLTWH(b.left, b.bottom - 2, b.width, 2), D.fill(pr ? Pal.white : const Color(0xFF404040)));
    c.drawRect(Rect.fromLTWH(b.right - 2, b.top, 2, b.height), D.fill(pr ? Pal.white : const Color(0xFF404040)));
    final blink = (_t * 3).floor().isEven;
    D.text(c, host.tr('click_here', 'CLICK HERE'), b.center + (pr ? const Offset(1, 1) : Offset.zero), size: 14,
        color: blink ? const Color(0xFF0000EE) : Pal.red, maxWidth: b.width - 8, weight: FontWeight.w900);
    c.drawRect(Rect.fromLTWH(b.left + 10, b.center.dy + 9, b.width - 20, 1.5), D.fill(blink ? const Color(0xFF0000EE) : Pal.red));
    // fire strip
    for (var i = 0; i < 12; i++) {
      D.flame(c, Offset(15 + i * 30.0, 642), 34 + sin(_t * 7 + i) * 6, _t + i * .37);
    }
  }

  void _renderEnd(Canvas c) {
    if (_lost) {
      c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), D.fill(const Color(0x66000000)));
      c.save();
      c.translate(180, 430);
      c.rotate(-.06);
      c.drawRect(const Rect.fromLTWH(-150, -40, 300, 80), D.fill(const Color(0xFFC0C0C0)));
      c.drawRect(const Rect.fromLTWH(-150, -40, 300, 20), D.fill(const Color(0xFF000080)));
      D.text(c, host.tr('sorry', 'SORRY!'), const Offset(-140, -30), size: 12, color: Pal.white, anchor: Alignment.centerLeft);
      PixelFont.draw(c, '1,000,000', const Offset(0, -6), 3.5, const Color(0xFFB00000), align: 0);
      c.restore();
      for (final rv in _rivals) {
        final p = rv.pos + Offset(0, -((sin(_t * 12 + rv.name.length)).abs() * 12));
        _cursor.draw(c, p, scale: 2.6);
      }
    } else {
      // prizes rain down
      for (var i = 0; i < 9; i++) {
        final y = -60 + ((_endT * 320 + i * 97) % 760);
        c.save();
        c.translate(20 + i * 40.0, y);
        c.rotate(_endT * 3 + i);
        c.scale(.6);
        _drawPrize(c, i % 3, _endT * 4 + i);
        c.restore();
      }
    }
  }
}

class _Rival {
  _Rival(this.pos, this.name, this.color);
  Offset pos;
  final String name;
  final Color color;
  double gloat = 0;
}

class _Flyer {
  _Flyer(this.from, this.kind);
  final Offset from;
  final int kind;
  double t = 0;
}
