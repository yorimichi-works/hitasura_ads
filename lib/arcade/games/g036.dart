import '../engine/engine.dart';

/// No.036 Hotel Rush — hotel cross-section. Guests arrive in the lobby asking
/// for a room type (single / family / VIP). Drag each guest to a FREE room of
/// the matching color. After checkout the room is a mess: tap it to clean.
/// Reach the money goal before the timer ends; 3 walkouts = fail.
class G036 extends MiniGame {
  static const _goal = 1200;
  static const _roomW = 98.0;
  static const _roomH = 96.0;
  static const _roomX = [32.0, 131.0, 230.0];
  static const _floorY = [128.0, 232.0, 336.0];
  static const _types = [
    [1, 2, 1],
    [0, 1, 0],
    [0, 0, 1],
  ];
  static const _typeCol = [Color(0xFF3FA9FF), Color(0xFF3DCB6C), Color(0xFFFFC53D)];
  static const _wallCol = [Color(0xFFD9ECFF), Color(0xFFDDF6E4), Color(0xFFFFF1CC)];
  static const _price = [100, 150, 300];
  static const _queueX = [58.0, 122.0, 186.0];
  static const _lobbyFeet = 548.0;

  final List<_Room> _rooms = [];
  final List<_Guest> _queue = [];
  _Guest? _held;
  double _spawnT = .2;
  double _t = 0;
  double _money = 0;
  double _shown = 0;
  double _bump = 0;
  int _walkouts = 0;
  int _checkins = 0;
  int _combo = 0;
  bool _won = false;

  @override
  void init() {
    for (var f = 0; f < 3; f++) {
      for (var k = 0; k < 3; k++) {
        _rooms.add(_Room(_types[f][k], Rect.fromLTWH(_roomX[k], _floorY[f], _roomW, _roomH)));
      }
    }
  }

  _Guest _newGuest() {
    final r = rng.nextDouble();
    final type = r < .45 ? 0 : (r < .85 ? 1 : 2);
    return _Guest(
      type,
      (9.5 - min(_checkins, 5) * .3) / host.speed,
      pick(const [Pal.sky, Pal.pink, Pal.lime, Pal.purple, Pal.orange, Pal.teal, Pal.red]),
      pick(const [Color(0xFF2B1D16), Color(0xFF6B3B1E), Color(0xFFE8C04A), Color(0xFF3B3B5A), Color(0xFFB0B0B8)]),
    )..pos = const Offset(-30, _lobbyFeet);
  }

  @override
  void update(double dt) {
    _t += dt;
    _bump = M.approach(_bump, 0, 8, dt);
    _shown = M.approach(_shown, _money, 7, dt);
    if (!host.finished) {
      _spawnT -= dt;
      if (_spawnT <= 0 && _queue.length < 3) {
        _queue.add(_newGuest());
        _spawnT = rand(1.3, 2.1) / host.speed;
        host.sfx(Sfx.bell, volume: .3, rate: 1.3);
      }
    }
    for (var i = 0; i < _queue.length; i++) {
      final g = _queue[i];
      g.bounce = M.approach(g.bounce, 0, 8, dt);
      if (!identical(g, _held)) {
        g.pos = M.approachO(g.pos, Offset(_queueX[i], _lobbyFeet), 7, dt);
      }
      if (!host.finished) g.patience -= dt;
      if (g.patience <= 0) {
        _walkouts++;
        _combo = 0;
        if (identical(g, _held)) _held = null;
        host.sfx(Sfx.buzzer, volume: .6);
        host.shake(6);
        host.fx.smoke(g.pos + const Offset(0, -40), count: 8, color: const Color(0xCCFF6060));
        host.fx.pop(host.tr('angry', 'ANGRY!'), g.pos + const Offset(0, -80), color: Pal.red, size: 24);
        _queue.removeAt(i);
        i--;
        if (_walkouts >= 3 && !host.finished) {
          host.sfx(Sfx.jingleLose, volume: .6);
          host.lose();
        }
      }
    }
    for (final r in _rooms) {
      r.flash = M.approach(r.flash, 0, 5, dt);
      switch (r.state) {
        case 1:
          r.stay -= dt;
          if (r.stay <= 0) {
            r.state = 2;
            r.flash = 1;
            host.sfx(Sfx.open, volume: .5);
            final tip = 20 + randInt(3) * 10;
            _earn(tip, r.rect.center, small: true);
            host.fx.smoke(r.rect.center, count: 5, color: const Color(0xAA9A7A5A));
          }
        case 3:
          r.clean += dt / .6;
          if (chance(dt * 20)) host.fx.sparkle(r.rect.center, count: 2, radius: 36, color: Pal.white);
          if (r.clean >= 1) {
            r.state = 0;
            r.flash = 1;
            host.sfx(Sfx.sparkle, volume: .6);
            host.fx.sparkle(r.rect.center, count: 10, radius: 40, color: Pal.yellow);
          }
      }
    }
  }

  void _earn(int v, Offset at, {bool small = false}) {
    _money += v;
    _bump = 1;
    host.addScore(v);
    host.fx.pop('+$v', at + const Offset(0, -20), color: Pal.gold, size: small ? 18 : 26);
    if (!small) host.fx.coins(at, count: 10, speed: 300);
    if (_money >= _goal && !_won && !host.finished) {
      _won = true;
      host.fx.confetti();
      host.sfx(Sfx.fanfare);
      host.win(stars: _walkouts == 0 && host.time < 17 ? 3 : (_walkouts <= 1 ? 2 : 1));
    }
  }

  _Room? _roomAt(Offset p) {
    for (final r in _rooms) {
      if (r.rect.inflate(4).contains(p)) return r;
    }
    return null;
  }

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    for (final g in _queue.reversed) {
      if ((p - (g.pos + const Offset(0, -34))).distance < 38) {
        _held = g;
        g.grab = g.pos - p;
        host.sfx(Sfx.pickup, volume: .6);
        return;
      }
    }
    final r = _roomAt(p);
    if (r != null) {
      if (r.state == 2) {
        r.state = 3;
        r.clean = 0;
        host.sfx(Sfx.scrub);
        host.fx.burst(r.rect.center, Pal.sky, count: 10, speed: 160, shape: PartShape.circle, size: 5);
      } else {
        r.flash = .4;
        host.sfx(Sfx.tap, volume: .4);
      }
    }
  }

  @override
  void onMove(Offset p) {
    final g = _held;
    if (g != null) g.pos = p + g.grab;
  }

  @override
  void onUp(Offset p) {
    final g = _held;
    if (g == null) return;
    _held = null;
    final r = _roomAt(g.pos + const Offset(0, -30));
    if (r == null) {
      host.sfx(Sfx.land, volume: .3);
      return;
    }
    if (r.state != 0) {
      g.bounce = 1;
      host.sfx(Sfx.boing, volume: .6);
      host.fx.pop(r.state == 1 ? host.tr('full', 'FULL!') : host.tr('dirty', 'DIRTY!'), r.rect.center,
          color: Pal.orange, size: 22);
      return;
    }
    if (r.type != g.type) {
      g.bounce = 1;
      g.patience -= 1.5;
      _combo = 0;
      host.sfx(Sfx.wrong);
      host.shake(5);
      host.fx.pop(host.tr('wrong', 'WRONG!'), r.rect.center, color: Pal.red, size: 26);
      return;
    }
    // check in!
    _queue.remove(g);
    _checkins++;
    _combo++;
    r
      ..state = 1
      ..stay = rand(3.8, 5.5)
      ..guest = g
      ..flash = 1;
    final ratio = (g.patience / g.maxPatience).clamp(0.0, 1.0);
    final pay = _price[g.type] + (ratio * 50).round() + (_combo >= 2 ? _combo * 10 : 0);
    host.sfx(Sfx.cash, rate: 1 + min(_combo, 8) * .05);
    host.sfx(Sfx.correct, volume: .5);
    host.punch(.03);
    host.fx.burst(r.rect.center, _typeCol[r.type], count: 16, speed: 240, shape: PartShape.star);
    if (ratio > .6) host.fx.pop(host.tr('great', 'GREAT!'), r.rect.center + const Offset(0, -50), color: Pal.lime, size: 22);
    if (_combo >= 3) {
      host.fx.pop('${host.tr('combo', 'COMBO')} x$_combo', r.rect.center + const Offset(0, 30), color: Pal.pink, size: 20);
    }
    _earn(pay, r.rect.center);
  }

  // ----------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    _drawSky(c);
    _drawBuilding(c);
    for (final r in _rooms) {
      _drawRoom(c, r);
    }
    _drawLobby(c);
    for (final g in _queue) {
      if (!identical(g, _held)) _drawGuest(c, g, false);
    }
    // drop target highlight
    final h = _held;
    if (h != null) {
      for (final r in _rooms) {
        if (r.state == 0 && r.type == h.type) {
          c.drawRect(r.rect.inflate(2), D.stroke(Pal.lime.withValues(alpha: .5 + .5 * M.wave(_t, 4)), 4));
        }
      }
      _drawGuest(c, h, true);
    }
    _drawHud(c);
    _drawHint(c);
  }

  void _drawSky(Canvas c) {
    D.gradientBg(c, const [Color(0xFF3B2F7A), Color(0xFFFF7E8A), Color(0xFFFFC27A)]);
    for (var k = 0; k < 12; k++) {
      c.drawCircle(Offset((k * 71) % 360.0, 50 + (k * 29) % 60.0), 1.5, D.fill(const Color(0x88FFFFFF)));
    }
    // skyline
    final sil = D.fill(const Color(0x553B2F7A));
    for (var k = 0; k < 9; k++) {
      final w = 30 + (k * 13) % 24.0;
      final hh = 120 + (k * 47) % 140.0;
      c.drawRect(Rect.fromLTWH(k * 42.0 - 10, 560 - hh, w, hh), sil);
    }
  }

  void _drawBuilding(Canvas c) {
    // roof sign
    D.rrect(c, const Rect.fromLTWH(22, 112, 316, 16), 3, const Color(0xFF8A2A3C), border: Pal.ink, borderWidth: 2.5);
    D.rrect(c, const Rect.fromLTWH(120, 78, 120, 34), 8, const Color(0xFF2B1E3A), border: Pal.ink, borderWidth: 2.5);
    for (var k = 0; k < 5; k++) {
      final on = ((_t * 3).floor() + k) % 5 != 0;
      D.star(c, Offset(140 + k * 20.0, 95), 8, on ? Pal.gold : const Color(0xFF6B5A30));
    }
    // body
    D.rrect(c, const Rect.fromLTWH(22, 126, 316, 438), 4, const Color(0xFFE8D2B8),
        gradient: const LinearGradient(colors: [Color(0xFFE9D6BE), Color(0xFFCFB394)]), border: Pal.ink, borderWidth: 3);
    for (final y in [230.0, 334.0, 438.0]) {
      c.drawRect(Rect.fromLTWH(22, y - 2, 316, 6), D.fill(const Color(0xFF8A6A50)));
    }
  }

  void _drawRoom(Canvas c, _Room r) {
    final rc = r.rect;
    c.drawRect(rc, D.fill(_wallCol[r.type]));
    // wallpaper stripes
    for (var x = rc.left + 8; x < rc.right; x += 16) {
      c.drawRect(Rect.fromLTWH(x, rc.top, 5, rc.height - 20), D.fill(const Color(0x14000000)));
    }
    // floor
    c.drawRect(Rect.fromLTWH(rc.left, rc.bottom - 16, rc.width, 16), D.fill(const Color(0xFFB07A4E)));
    // window
    final win = Rect.fromLTWH(rc.left + 58, rc.top + 12, 30, 26);
    D.rrect(c, win, 3, r.state == 1 ? const Color(0xFF2B2B5A) : const Color(0xFF9FD8F0), border: Pal.ink, borderWidth: 2);
    if (r.state == 1) c.drawCircle(win.center + const Offset(5, -3), 5, D.fill(Pal.cream));
    // beds
    final beds = r.type == 1 ? 2 : 1;
    for (var b = 0; b < beds; b++) {
      final bx = rc.left + 10 + b * 30.0;
      final bw = r.type == 2 ? 58.0 : (beds == 2 ? 28.0 : 42.0);
      D.rrect(c, Rect.fromLTWH(bx, rc.bottom - 38, bw, 22), 4, r.type == 2 ? const Color(0xFFB0224A) : Pal.white,
          border: Pal.ink, borderWidth: 2);
      D.rrect(c, Rect.fromLTWH(bx + 3, rc.bottom - 44, 14, 9), 3, Pal.white, border: Pal.ink, borderWidth: 1.5);
    }
    if (r.type == 2) {
      // chandelier
      c.drawLine(Offset(rc.center.dx - 10, rc.top), Offset(rc.center.dx - 10, rc.top + 10), D.stroke(Pal.ink, 1.5));
      D.gem(c, Offset(rc.center.dx - 10, rc.top + 16), 7, Pal.gold);
    }
    // door with type color
    final door = Rect.fromLTWH(rc.right - 24, rc.bottom - 56, 20, 40);
    D.rrect(c, door, 3, _typeCol[r.type], border: Pal.ink, borderWidth: 2);
    c.drawCircle(Offset(door.left + 5, door.center.dy), 2, D.fill(Pal.ink));
    if (r.type == 2) D.star(c, Offset(door.center.dx, door.top + 9), 6, Pal.white);

    switch (r.state) {
      case 0:
        // "vacant" glow lamp
        c.drawCircle(Offset(rc.left + 10, rc.top + 10), 5, D.fill(Pal.lime));
      case 1:
        final g = r.guest;
        if (g != null) {
          // guest sleeping in bed
          final hb = Offset(rc.left + 20, rc.bottom - 44);
          c.drawCircle(hb, 10, D.fill(Pal.skin));
          c.drawArc(Rect.fromCircle(center: hb, radius: 10.5), pi, pi, true, D.fill(g.hair));
          c.drawCircle(hb, 10, D.stroke(Pal.ink, 2));
          D.face(c, hb + const Offset(0, 1), 8, Face.sleepy, blush: false);
          D.rrect(c, Rect.fromLTWH(rc.left + 14, rc.bottom - 38, r.type == 2 ? 50 : 36, 16), 5, g.shirt,
              border: Pal.ink, borderWidth: 1.5);
          final zz = (_t * .8 + rc.left * .01) % 1.0;
          D.text(c, 'z', Offset(rc.left + 36 + zz * 14, rc.top + 30 - zz * 18), size: 12 + zz * 8,
              color: Color.fromRGBO(60, 60, 120, 1 - zz));
        }
        c.drawRect(rc, D.fill(const Color(0x33101040)));
        c.drawCircle(Offset(rc.left + 10, rc.top + 10), 5, D.fill(Pal.red));
      case 2:
        // mess
        for (var k = 0; k < 4; k++) {
          c.drawOval(Rect.fromCenter(center: Offset(rc.left + 16 + k * 18.0, rc.bottom - 10 - (k % 2) * 6), width: 18, height: 8),
              D.fill(const Color(0xAA7A5230)));
        }
        D.rrect(c, Rect.fromLTWH(rc.left + 50, rc.bottom - 30, 16, 10), 2, Pal.pink); // sock
        c.drawLine(Offset(rc.left + 22, rc.top + 50), Offset(rc.left + 40, rc.top + 58), D.stroke(Pal.white, 4));
        for (var k = 0; k < 2; k++) {
          final a = _t * 6 + k * 3;
          c.drawCircle(Offset(rc.center.dx + cos(a) * 18, rc.top + 40 + sin(a * 1.3) * 10), 2.5, D.fill(Pal.ink));
        }
        c.drawCircle(Offset(rc.left + 10, rc.top + 10), 5, D.fill(Pal.orange));
        final bob = sin(_t * 8) * 3;
        D.rrect(c, Rect.fromCenter(center: rc.center + Offset(0, -6 + bob), width: 40, height: 26), 8, const Color(0xEEFFFFFF),
            border: Pal.ink, borderWidth: 2);
        _broom(c, rc.center + Offset(0, -6 + bob), 1);
      case 3:
        // maid cleaning
        final mx = rc.left + 20 + M.wave(_t, 2) * 50;
        D.person(c, Offset(mx, rc.bottom - 14), 46, const Color(0xFF2B2B3A), face: Face.happy, hair: Pal.ink,
            running: true, run: _t * 16);
        c.drawRect(Rect.fromCenter(center: Offset(mx, rc.bottom - 38), width: 12, height: 10), D.fill(Pal.white));
        _broom(c, Offset(mx + 14, rc.bottom - 30), .8);
        D.bar(c, Rect.fromLTWH(rc.left + 10, rc.top + 4, rc.width - 20, 7), r.clean, Pal.sky);
    }
    if (r.flash > 0) c.drawRect(rc, D.fill(Pal.white.withValues(alpha: r.flash * .5)));
    c.drawRect(rc, D.stroke(Pal.ink, 2.5));
  }

  void _broom(Canvas c, Offset o, double s) {
    c.drawLine(o + Offset(-8 * s, -10 * s), o + Offset(6 * s, 6 * s), D.stroke(const Color(0xFF8A5A33), 3 * s));
    c.drawPath(
        Path()
          ..moveTo(o.dx + 3 * s, o.dy + 3 * s)
          ..lineTo(o.dx + 14 * s, o.dy + 4 * s)
          ..lineTo(o.dx + 8 * s, o.dy + 14 * s)
          ..close(),
        D.fill(Pal.yellow));
  }

  void _drawLobby(Canvas c) {
    final lobby = const Rect.fromLTWH(32, 440, 296, 118);
    c.drawRect(lobby, D.fill(const Color(0xFFFFE9C8)));
    // checker floor
    for (var k = 0; k < 15; k++) {
      c.drawRect(Rect.fromLTWH(32 + k * 20.0, 540, 20, 18), D.fill(k.isEven ? const Color(0xFF8A2A3C) : const Color(0xFFF4E3C8)));
    }
    // red carpet
    c.drawRect(const Rect.fromLTWH(32, 548, 200, 10), D.fill(const Color(0xAAE8322C)));
    // reception desk
    D.rrect(c, const Rect.fromLTWH(240, 494, 84, 50), 6, const Color(0xFF8A5A33), border: Pal.ink, borderWidth: 2.5);
    c.drawRect(const Rect.fromLTWH(240, 494, 84, 8), D.fill(const Color(0xFFD9A066)));
    D.person(c, const Offset(282, 520), 64, const Color(0xFF8A2A3C), face: Face.happy, hair: const Color(0xFF2B1D16));
    D.rrect(c, const Rect.fromLTWH(240, 504, 84, 40), 6, const Color(0xFF8A5A33), border: Pal.ink, borderWidth: 2.5);
    D.circle(c, const Offset(304, 490), 6, Pal.gold, border: Pal.ink, borderWidth: 1.5);
    // plant
    c.drawRect(const Rect.fromLTWH(38, 520, 16, 20), D.fill(const Color(0xFF9A5B34)));
    for (var k = 0; k < 4; k++) {
      c.drawOval(Rect.fromCenter(center: Offset(46 + (k - 1.5) * 6, 510 - (k % 2) * 6), width: 10, height: 24), D.fill(Pal.green));
    }
    c.drawRect(lobby, D.stroke(Pal.ink, 2.5));
    // street
    c.drawRect(const Rect.fromLTWH(0, 564, 360, 76), D.fill(const Color(0xFF4A4F5C)));
    for (var k = 0; k < 6; k++) {
      c.drawRect(Rect.fromLTWH(((k * 70 - _t * 40) % 420) - 30, 606, 34, 5), D.fill(const Color(0xAAFFFFFF)));
    }
    c.drawRect(const Rect.fromLTWH(0, 560, 360, 8), D.fill(const Color(0xFF9AA4B0)));
  }

  void _drawGuest(Canvas c, _Guest g, bool held) {
    final ratio = (g.patience / g.maxPatience).clamp(0.0, 1.0);
    final f = held ? Face.shocked : (ratio > .55 ? Face.happy : (ratio > .28 ? Face.neutral : Face.angry));
    final sw = held ? sin(_t * 12) * .15 : 0.0;
    final shake = ratio < .28 ? sin(_t * 40) * 2 : 0.0;
    final p = g.pos + Offset(shake, -g.bounce * 10);
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(sw);
    if (!held) D.shadow(c, Offset.zero, 40, 8, .3);
    // suitcase
    D.rrect(c, const Rect.fromLTWH(10, -24, 16, 20), 3, _typeCol[g.type], border: Pal.ink, borderWidth: 2);
    D.person(c, Offset.zero, 66, g.type == 2 ? Pal.gold : g.shirt, hair: g.hair, face: f, armsUp: held ? .7 : 0);
    if (g.type == 1) {
      D.person(c, const Offset(-18, 0), 38, g.shirt, hair: g.hair, face: f);
    }
    if (g.type == 2) {
      // top hat
      c.drawRect(const Rect.fromLTWH(-9, -80, 18, 14), D.fill(Pal.ink));
      c.drawRect(const Rect.fromLTWH(-14, -67, 28, 4), D.fill(Pal.ink));
      c.drawRect(const Rect.fromLTWH(-9, -71, 18, 3), D.fill(Pal.red));
    }
    c.restore();
    if (!held) {
      // request bubble
      final b = Rect.fromCenter(center: p + const Offset(0, -104), width: 46, height: 36);
      D.bubble(c, b, tail: p + const Offset(0, -80));
      final dr = Rect.fromCenter(center: b.center, width: 16, height: 26);
      D.rrect(c, dr, 3, _typeCol[g.type], border: Pal.ink, borderWidth: 2);
      if (g.type == 2) D.star(c, dr.center + const Offset(0, -4), 6, Pal.white);
      if (g.type == 1) D.text(c, '2', dr.center, size: 12, color: Pal.white, stroke: Pal.ink);
      final col = ratio > .55 ? Pal.green : (ratio > .28 ? Pal.yellow : Pal.red);
      D.bar(c, Rect.fromLTWH(b.left, b.top - 10, b.width, 6), ratio, col);
    }
  }

  void _drawHud(Canvas c) {
    final s = 1 + _bump * .12;
    c.save();
    c.translate(254, 60);
    c.scale(s);
    D.rrect(c, const Rect.fromLTWH(-96, -16, 192, 32), 16, const Color(0xDD1B1530), border: Pal.gold, borderWidth: 2);
    D.coin(c, const Offset(-78, 0), 10, spin: _t * .4);
    D.bar(c, const Rect.fromLTWH(-62, -6, 76, 12), _shown / _goal, Pal.gold);
    D.text(c, '${_shown.round()}/$_goal', const Offset(52, 0), size: 14, color: Pal.white, stroke: Pal.ink);
    c.restore();
    for (var i = 0; i < 3; i++) {
      D.heart(c, Offset(22 + i * 24.0, 60), 18, i < 3 - _walkouts ? Pal.red : const Color(0x55000000), border: Pal.ink);
    }
  }

  void _drawHint(Canvas c) {
    if (host.finished || _checkins > 0 || host.time > 8 || _held != null || _queue.isEmpty) return;
    final g = _queue.first;
    _Room? target;
    for (final r in _rooms) {
      if (r.state == 0 && r.type == g.type) {
        target = r;
        break;
      }
    }
    if (target == null) return;
    final k = (_t * .7) % 1.0;
    final from = g.pos + const Offset(0, -34);
    final p = Offset.lerp(from, target.rect.center, M.easeInOut(k))!;
    c.drawLine(from, target.rect.center, D.stroke(const Color(0x88FFFFFF), 4));
    D.hand(c, p, 0);
  }
}

class _Room {
  _Room(this.type, this.rect);
  final int type;
  final Rect rect;
  int state = 0; // 0 free, 1 occupied, 2 dirty, 3 cleaning
  double stay = 0;
  double clean = 0;
  double flash = 0;
  _Guest? guest;
}

class _Guest {
  _Guest(this.type, this.patience, this.shirt, this.hair) : maxPatience = patience;
  final int type;
  double patience;
  final double maxPatience;
  final Color shirt;
  final Color hair;
  Offset pos = Offset.zero;
  Offset grab = Offset.zero;
  double bounce = 0;
}
