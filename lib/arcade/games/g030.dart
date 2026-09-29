import '../engine/engine.dart';

/// No.030 Noah's Last Boat — drag animals from the dock onto the ark. Keep the
/// boat balanced (heavy ones in the middle!) and under capacity, then sail
/// away with 6+ animals before the flood swallows the dock.
class G030 extends MiniGame {
  static const _cx = 128.0; // boat center x
  static const _deckHalf = 100.0;
  static const _dockTop = 438.0;
  static const _dockLeft = 252.0;
  static const _slots = [270.0, 302.0, 333.0];
  static const _cap = 26;
  static const _need = 6;
  static const _capsize = .30;

  // name, weight, body w, body h, leg h, color
  static const _spec = <(int, double, double, double, Color)>[
    (1, 18, 11, 4, Color(0xFFA9A6B8)), // mouse
    (1, 18, 14, 5, Color(0xFFF4F0EA)), // rabbit
    (2, 18, 26, 3, Color(0xFF2B2B3A)), // penguin
    (2, 32, 20, 7, Color(0xFFF7F3E8)), // sheep
    (3, 34, 21, 7, Color(0xFFFFA3B8)), // pig
    (4, 42, 24, 11, Color(0xFFFFFFFF)), // cow
    (4, 34, 20, 14, Color(0xFFF5C542)), // giraffe
    (6, 50, 32, 12, Color(0xFF9AA0B5)), // elephant
  ];

  final List<_Animal> _queue = [];
  final List<_Animal> _aboard = [];
  final List<_Flyer> _flying = [];
  double _t = 0;
  double _water = 474;
  double _ang = 0, _angVel = 0;
  double _deckBob = 0;
  _Animal? _drag;
  Offset _dragPos = Offset.zero;
  int _state = 0; // 0 loading, 1 sailing, 2 capsized, 3 sunk
  double _sail = 0;
  double _lightning = 0;
  double _nextBolt = 3;
  int _loads = 0;
  final List<Offset> _rain = [];

  int get _load => _aboard.fold(0, (s, a) => s + _spec[a.type].$1);
  double get _deckY => _water - 36 + min(_load, 34) * .75 + _deckBob;
  double get _torque => _aboard.fold(0.0, (s, a) => s + _spec[a.type].$1 * a.lx / 100);
  Rect get _goBtn => const Rect.fromLTWH(16, 96, 108, 50);

  @override
  void init() {
    final types = <int>[0, 1, 2, 3, 4, 5, 6]..shuffle(rng);
    final chosen = [7, ...types.take(5)]..shuffle(rng);
    for (final ty in chosen) {
      _queue
        ..add(_Animal(ty))
        ..add(_Animal(ty));
    }
    for (var i = 0; i < _queue.length; i++) {
      _queue[i].x = i < 3 ? _slots[i] : 400.0 + i * 30;
    }
    for (var i = 0; i < 70; i++) {
      _rain.add(Offset(rand(0, 360), rand(36, 640)));
    }
  }

  // ------------------------------------------------------------------ logic

  @override
  void update(double dt) {
    _t += dt;
    _lightning = max(0, _lightning - dt * 3);
    _nextBolt -= dt;
    if (_nextBolt <= 0) {
      _nextBolt = rand(2.5, 4.5);
      _lightning = 1;
      host.sfx(Sfx.crack, volume: .5, rate: .6);
    }
    if (_state == 0) {
      _water = M.lerp(474, 404, M.clamp01(host.time / host.duration));
    }
    _deckBob = sin(_t * 2.1) * 2.5;

    // tilt spring
    final target = (_state == 2) ? _ang.sign * 2.6 : _torque * .045;
    _angVel += (target - _ang) * (_state == 2 ? 10 : 34) * dt;
    _angVel *= 1 - min(1, 4.2 * dt);
    _ang += _angVel * dt;

    // animals on deck: drop in, slide when steep
    for (final a in _aboard) {
      a.anim += dt;
      a.joy = max(0, a.joy - dt);
      if (a.ly < 0 || a.vy != 0) {
        a.vy += 900 * dt;
        a.ly += a.vy * dt;
        if (a.ly >= 0) {
          a.ly = 0;
          if (a.vy > 120) {
            _angVel += _spec[a.type].$1 * a.lx * .0009;
            host.sfx(Sfx.thud, volume: .6, rate: 1.3 - _spec[a.type].$1 * .08);
            host.fx.smoke(_toWorld(a.lx, 0), count: 3, size: 8);
          }
          a.vy = 0;
        }
      }
      if (_state == 0 && _ang.abs() > .17) {
        a.lx = (a.lx + _ang * 40 * dt).clamp(-_deckHalf + 10, _deckHalf - 10);
      }
    }
    if (_state == 0 && !host.finished) {
      final tq = _torque * .045;
      if (tq.abs() > _capsize) {
        _capsizeNow();
      } else if (_load > _cap) {
        _sink();
      }
    }

    // queue walks forward
    for (var i = 0; i < _queue.length; i++) {
      final a = _queue[i];
      if (a == _drag) continue;
      a.anim += dt;
      final tx = i < 3 ? _slots[i] : 380.0 + (i - 3) * 30;
      a.walking = (a.x - tx).abs() > 1.5;
      a.x = M.approach(a.x, tx, 3.5, dt);
      a.swimT = max(0, a.swimT - dt);
    }

    // flying animals (capsize / missed drops)
    for (final f in _flying) {
      f.vel = Offset(f.vel.dx, f.vel.dy + 700 * dt);
      f.pos += f.vel * dt;
      f.spin += dt * 8;
      if (f.pos.dy > _water + 6 && !f.splashed) {
        f.splashed = true;
        f.vel = Offset(f.vel.dx * .3, 40);
        host.sfx(Sfx.splash, volume: .6, rate: rand(.9, 1.3));
        host.fx.burst(Offset(f.pos.dx, _water), const Color(0xFFBFE8FF), count: 10, speed: 180, size: 5);
      }
      if (f.splashed) f.vel = Offset(f.vel.dx, min(f.vel.dy, 40));
    }
    _flying.removeWhere((f) => f.pos.dy > 700);

    if (_state == 1) {
      _sail += dt;
    }
    if (_state == 3) {
      _sinkT += dt;
    }
  }

  Offset _toWorld(double lx, double ly) {
    final c = cos(_ang), s = sin(_ang);
    final base = Offset(_cx - _sail * _sail * 120, _deckY + (_state == 3 ? _sinkY : 0));
    return base + Offset(lx * c - ly * s, lx * s + ly * c);
  }

  double _sinkT = 0;
  double get _sinkY => _sinkT * _sinkT * 90;

  void _capsizeNow() {
    _state = 2;
    host.sfx(Sfx.crash);
    host.sfx(Sfx.splash);
    host.sfx(Sfx.aww);
    host.shake(10);
    host.flash(const Color(0x66FF2040));
    for (final a in _aboard) {
      final p = _toWorld(a.lx, -10);
      _flying.add(_Flyer(a.type, p, Offset(_ang.sign * rand(80, 220), rand(-420, -200))));
    }
    _aboard.clear();
    host.fx.pop(host.tr('oops', 'OOPS'), const Offset(150, 300), color: Pal.red, size: 44);
    host.lose();
  }

  void _sink() {
    _state = 3;
    host.sfx(Sfx.bubble);
    host.sfx(Sfx.aww);
    host.shake(6);
    host.fx.pop(host.tr('oops', 'OOPS'), const Offset(150, 300), color: Pal.red, size: 44);
    host.lose();
  }

  void _depart() {
    if (_state != 0 || _aboard.length < _need) return;
    _state = 1;
    host.sfx(Sfx.fanfare);
    host.sfx(Sfx.cheer);
    host.fx.confetti();
    for (final a in _aboard) {
      a.joy = 5;
    }
    final n = _aboard.length;
    final pairs = _pairs;
    host.addScore(n * 100 + pairs * 200, const Offset(128, 330));
    if (pairs > 0) host.fx.pop('${host.tr('bonus', 'BONUS!')} x$pairs', const Offset(150, 260), color: Pal.pink, size: 30);
    host.win(stars: n >= 10 ? 3 : (n >= 8 || pairs >= 4 ? 2 : 1));
  }

  int get _pairs {
    final counts = <int, int>{};
    for (final a in _aboard) {
      counts[a.type] = (counts[a.type] ?? 0) + 1;
    }
    return counts.values.where((v) => v >= 2).length;
  }

  Rect _animalRect(_Animal a) {
    final sp = _spec[a.type];
    final h = (sp.$3 + sp.$4 + (a.type == 6 ? 34 : 12)) * 1.25;
    final w = sp.$2 * 1.25;
    return Rect.fromLTWH(a.x - w / 2 - 6, _dockTop - h - 6, w + 12, h + 10);
  }

  @override
  void onDown(Offset p) {
    if (_state != 0) return;
    if (_aboard.length >= _need && _goBtn.inflate(6).contains(p)) {
      _depart();
      return;
    }
    for (var i = 0; i < min(3, _queue.length); i++) {
      final a = _queue[i];
      if (_animalRect(a).contains(p)) {
        _drag = a;
        _dragPos = p;
        host.sfx(Sfx.pickup, rate: 1.4 - _spec[a.type].$1 * .1);
        return;
      }
    }
  }

  @override
  void onMove(Offset p) {
    if (_drag != null) _dragPos = p;
  }

  @override
  void onUp(Offset p) {
    final a = _drag;
    _drag = null;
    if (a == null || _state != 0) return;
    final lx = p.dx - _cx;
    if (lx.abs() < _deckHalf - 6 && p.dy < _deckY + 20) {
      _queue.remove(a);
      a
        ..lx = lx
        ..ly = min(-4, p.dy - _deckY)
        ..vy = 1
        ..joy = 1.2;
      _aboard.add(a);
      _loads++;
      final w = _spec[a.type].$1;
      host.sfx(Sfx.boing, rate: 1.4 - w * .1);
      host.addScore(50 * w, p + const Offset(0, -30));
      final partner = _aboard.where((o) => o.type == a.type).length == 2;
      if (partner) {
        host.sfx(Sfx.correct);
        host.fx.pop(host.tr('nice', 'NICE!'), p + const Offset(0, -60), color: Pal.pink, size: 26);
        for (final o in _aboard.where((o) => o.type == a.type)) {
          host.fx.burst(_toWorld(o.lx, -30), Pal.pink, count: 6, speed: 90, size: 7, shape: PartShape.heart, gravity: -40);
        }
      }
      if (_aboard.length == _need) {
        host.sfx(Sfx.levelup);
        host.fx.pop(host.tr('go', 'GO!'), _goBtn.center + const Offset(0, 50), color: Pal.yellow, size: 30);
      }
    } else if (p.dx < _dockLeft - 4) {
      // missed the boat: splash, swim back to the end of the line
      _queue
        ..remove(a)
        ..add(a);
      a
        ..x = 400
        ..swimT = 2;
      _flying.add(_Flyer(a.type, p, Offset(rand(-40, 40), -120)));
      host.sfx(Sfx.splash);
      host.fx.pop(host.tr('oops', 'OOPS'), p + const Offset(0, -30), color: Pal.sky, size: 22);
    }
  }

  @override
  void onTimeUp() {
    if (_state == 0 && _aboard.length >= _need) {
      _depart();
    } else {
      host.sfx(Sfx.aww);
      host.lose();
    }
  }

  // ----------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    // stormy sky
    D.gradientBg(c, const [Color(0xFF2E3A5C), Color(0xFF4F6A8F), Color(0xFF8AA6C0)]);
    if (_lightning > 0) {
      c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), D.fill(Color.fromRGBO(255, 255, 240, _lightning * .35)));
      if (_lightning > .6) {
        final bolt = Path()..moveTo(250, 40);
        var x = 250.0;
        for (var y = 60.0; y < 300; y += 30) {
          x += (y * 7 % 23) - 11;
          bolt.lineTo(x, y);
        }
        c.drawPath(bolt, D.stroke(const Color(0xFFFFF6B0), 4));
      }
    }
    for (var i = 0; i < 6; i++) {
      final x = (i * 80 + _t * 14) % 480 - 60;
      D.cloud(c, Offset(x, 70.0 + (i % 3) * 30), 70, color: Color.lerp(const Color(0xFF3A4668), const Color(0xFF55648A), (i % 3) / 2)!);
    }
    // distant mountain almost gone
    final m = Path()
      ..moveTo(0, 420)
      ..lineTo(60, 360)
      ..lineTo(110, 400)
      ..lineTo(170, 340)
      ..lineTo(240, 410)
      ..lineTo(0, 420)
      ..close();
    c.drawPath(m, D.fill(const Color(0xFF5E7390)));

    // dock
    for (final px in const [262.0, 306.0, 350.0]) {
      c.drawRect(Rect.fromLTWH(px - 5, _dockTop, 10, 200), D.fill(const Color(0xFF6E4020)));
    }
    D.rrect(c, const Rect.fromLTWH(_dockLeft, _dockTop, 120, 12), 3, const Color(0xFFB27A45), border: Pal.ink, borderWidth: 2.5);
    for (var i = 0; i < 5; i++) {
      c.drawLine(Offset(_dockLeft + 20 + i * 22.0, _dockTop + 1), Offset(_dockLeft + 20 + i * 22.0, _dockTop + 11), D.stroke(const Color(0xFF7A4A22), 1.5));
    }

    // queue
    final panic = _water < _dockTop + 18;
    for (var i = _queue.length - 1; i >= 0; i--) {
      final a = _queue[i];
      if (a == _drag || a.x > 380) continue;
      final face = panic ? Face.shocked : (a.type == 7 && i < 3 ? Face.sad : Face.neutral);
      final hop = panic ? -(sin(_t * 14 + i).abs() * 4) : 0.0;
      _drawAnimal(c, a.type, Offset(a.x, _dockTop + hop), face, a.walking ? a.anim : 0, true);
      if (i < 3) {
        final r = _animalRect(a);
        final bp = Offset(a.x, r.top - 8);
        D.circle(c, bp, 10, _spec[a.type].$1 >= 4 ? Pal.orange : Pal.white, border: Pal.ink, borderWidth: 2);
        D.text(c, '${_spec[a.type].$1}', bp + const Offset(0, 1), size: 13, color: Pal.ink);
      }
    }

    // ark
    _drawBoat(c);

    // flying animals
    for (final f in _flying) {
      c.save();
      c.translate(f.pos.dx, f.pos.dy);
      c.rotate(f.splashed ? sin(_t * 6) * .3 : f.spin);
      _drawAnimal(c, f.type, Offset.zero, Face.shocked, _t * 3, false);
      c.restore();
    }

    // water (drawn over the hull)
    final wp = Path()..moveTo(0, 640);
    for (var x = 0.0; x <= 360; x += 12) {
      wp.lineTo(x, _water + sin(x * .05 + _t * 3) * 4 + sin(x * .13 - _t * 2) * 2);
    }
    wp
      ..lineTo(360, 640)
      ..close();
    c.drawPath(wp, D.fill(const Color(0xCC2F74B5)));
    final foam = D.stroke(const Color(0x99FFFFFF), 2.5);
    for (var i = 0; i < 10; i++) {
      final x = (i * 41 + _t * 40) % 380 - 10;
      final y = _water + 18 + (i % 4) * 26;
      c.drawArc(Rect.fromCenter(center: Offset(x, y), width: 22, height: 8), pi, pi, false, foam);
    }

    // rain
    final rp = D.stroke(const Color(0x66DDEEFF), 1.5);
    for (var i = 0; i < _rain.length; i++) {
      final r = _rain[i];
      final y = (r.dy + _t * 520) % 620 + 30;
      final x = (r.dx - _t * 90) % 360;
      c.drawLine(Offset(x, y), Offset(x - 4, y + 12), rp);
    }

    // dragged animal
    if (_drag != null) {
      final lx = _dragPos.dx - _cx;
      final onBoat = lx.abs() < _deckHalf - 6 && _dragPos.dy < _deckY + 20;
      if (onBoat) {
        // landing marker + predicted tilt
        final w = _spec[_drag!.type].$1;
        final tq = (_torque + w * lx / 100) * .045;
        final danger = tq.abs() > _capsize * .8;
        final mk = _toWorld(lx, 0);
        c.drawOval(Rect.fromCenter(center: mk, width: 40, height: 10), D.fill(danger ? const Color(0x88FF2040) : const Color(0x8839FF8A)));
        D.line(c, _dragPos, mk, danger ? const Color(0x88FF2040) : const Color(0x88FFFFFF), 2);
      }
      c.save();
      c.translate(_dragPos.dx, _dragPos.dy + 10);
      c.rotate(sin(_t * 12) * .12);
      _drawAnimal(c, _drag!.type, Offset.zero, Face.shocked, _t * 4, false);
      c.restore();
    }

    _drawHud(c);

    if (_loads == 0 && host.time < 4.5 && _queue.isNotEmpty) {
      final from = _animalRect(_queue.first).center;
      const to = Offset(_cx, 380);
      final k = (_t * .75) % 1;
      D.hand(c, Offset.lerp(from, to, M.easeInOut(M.clamp01(k * 1.4)))!, 0);
      D.text(c, host.tr('drag', 'DRAG!'), const Offset(180, 250), size: 28, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _drawHud(Canvas c) {
    // capacity meter
    const r = Rect.fromLTWH(140, 48, 206, 18);
    final load = _load;
    final f = load / _cap;
    D.bar(c, r, f, f > .85 ? Pal.red : (f > .6 ? Pal.orange : Pal.lime), border: Pal.ink);
    D.text(c, '$load / $_cap', r.center, size: 13, stroke: Pal.ink);
    // anchor-ish weight icon
    D.rrect(c, const Rect.fromLTWH(116, 47, 20, 20), 5, Pal.gray, border: Pal.ink, borderWidth: 2);
    D.text(c, 'kg', const Offset(126, 58), size: 9, color: Pal.ink);
    // tilt gauge
    const g = Offset(243, 88);
    c.drawArc(Rect.fromCircle(center: g, radius: 16), pi + .4, pi - .8, false, D.stroke(const Color(0x66FFFFFF), 5));
    final a = -pi / 2 + (_torque * .045 / _capsize).clamp(-1.2, 1.2) * (pi / 2 - .4);
    final col = (_torque * .045).abs() > _capsize * .7 ? Pal.red : Pal.white;
    D.line(c, g, g + Offset(cos(a), sin(a)) * 16, col, 3);
    // saved counter
    D.rrect(c, const Rect.fromLTWH(270, 74, 76, 30), 15, const Color(0xAA1B1530));
    D.heart(c, const Offset(288, 89), 16, Pal.pink, border: Pal.ink);
    D.text(c, '${_aboard.length}/$_need', const Offset(322, 89), size: 16, color: _aboard.length >= _need ? Pal.yellow : Pal.white, stroke: Pal.ink);
    // GO button
    if (_state == 0 && _aboard.length >= _need) {
      final s = 1 + .06 * sin(_t * 10);
      c.save();
      c.translate(_goBtn.center.dx, _goBtn.center.dy);
      c.scale(s);
      c.translate(-_goBtn.center.dx, -_goBtn.center.dy);
      D.button(c, _goBtn, host.tr('go', 'GO!'), color: Pal.orange, fontSize: 24);
      c.restore();
    }
  }

  void _drawBoat(Canvas c) {
    c.save();
    final base = _toWorld(0, 0);
    c.translate(base.dx, base.dy);
    c.rotate(_ang);
    // mast + flag
    D.line(c, const Offset(-80, 0), const Offset(-80, -92), const Color(0xFF6E4020), 5);
    final flag = Path()
      ..moveTo(-80, -92)
      ..quadraticBezierTo(-60, -96 + sin(_t * 8) * 4, -44, -84 + sin(_t * 8 + 1) * 3)
      ..lineTo(-80, -72)
      ..close();
    c.drawPath(flag, D.fill(Pal.yellow));
    c.drawPath(flag, D.stroke(Pal.ink, 2));
    // hull
    final hull = Path()
      ..moveTo(-_deckHalf - 18, -14)
      ..lineTo(-_deckHalf, 2)
      ..lineTo(_deckHalf, 2)
      ..lineTo(_deckHalf + 18, -14)
      ..quadraticBezierTo(_deckHalf + 6, 60, 60, 62)
      ..lineTo(-60, 62)
      ..quadraticBezierTo(-_deckHalf - 6, 60, -_deckHalf - 18, -14)
      ..close();
    c.drawPath(hull, D.fill(const Color(0xFFA8683A)));
    for (var k = 1; k < 4; k++) {
      c.drawLine(Offset(-_deckHalf + 2, k * 14.0), Offset(_deckHalf - 2, k * 14.0), D.stroke(const Color(0xFF7A4A22), 2));
    }
    c.drawPath(hull, D.stroke(Pal.ink, 3));
    // portholes
    for (final x in const [-50.0, 0.0, 50.0]) {
      D.circle(c, Offset(x, 22), 6, const Color(0xFFFFE9A0), border: Pal.ink, borderWidth: 2);
    }
    // deck rail
    D.rrect(c, const Rect.fromLTWH(-_deckHalf, -2, _deckHalf * 2, 6), 3, const Color(0xFFD9A066), border: Pal.ink, borderWidth: 2);
    // center mark (the sweet spot)
    c.drawPath(
        Path()
          ..moveTo(-6, 10)
          ..lineTo(6, 10)
          ..lineTo(0, 3)
          ..close(),
        D.fill(Pal.yellow));
    c.restore();
    // animals aboard
    final sorted = [..._aboard]..sort((a, b) => _spec[b.type].$3.compareTo(_spec[a.type].$3));
    for (final a in sorted) {
      final p = _toWorld(a.lx, a.ly - 2);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(_ang);
      final tilt = _ang.abs() > .15;
      final face = _state == 1 || a.joy > 0 ? Face.happy : (tilt ? Face.shocked : Face.smug);
      final hop = _state == 1 ? -(sin(_t * 12 + a.lx).abs() * 5) : 0.0;
      _drawAnimal(c, a.type, Offset(0, hop), face, 0, a.lx > 0);
      c.restore();
    }
  }

  /// Draws an animal with its feet at [feet]; faces left unless [faceRight].
  void _drawAnimal(Canvas c, int type, Offset feet, Face face, double walk, bool faceLeft) {
    final sp = _spec[type];
    final bw = sp.$2, bh = sp.$3, lh = sp.$4;
    final col = sp.$5;
    c.save();
    c.translate(feet.dx, feet.dy);
    c.scale(1.25);
    if (!faceLeft) c.scale(-1, 1);
    final ink = D.stroke(Pal.ink, 2);
    final legP = D.stroke(type == 2 ? Pal.orange : Color.lerp(col, Pal.ink, type == 3 ? .8 : .35)!, max(3, bw * .12));
    if (type == 2) {
      // penguin: upright
      c.drawOval(Rect.fromCenter(center: Offset(0, -bh / 2 - 2), width: bw, height: bh), D.fill(col));
      c.drawOval(Rect.fromCenter(center: Offset(-2, -bh / 2), width: bw * .6, height: bh * .7), D.fill(Pal.white));
      c.drawOval(Rect.fromCenter(center: Offset(0, -bh / 2 - 2), width: bw, height: bh), ink);
      c.drawOval(const Rect.fromLTWH(-9, -3, 8, 4), D.fill(Pal.orange));
      c.drawOval(const Rect.fromLTWH(1, -3, 8, 4), D.fill(Pal.orange));
      D.face(c, Offset(-1, -bh + 7), 7, face, blush: false, ink: Pal.ink);
      c.drawPath(
          Path()
            ..moveTo(-bw / 2 - 5, -bh + 9)
            ..lineTo(-bw / 2 + 1, -bh + 6)
            ..lineTo(-bw / 2 + 1, -bh + 12)
            ..close(),
          D.fill(Pal.orange));
      c.restore();
      return;
    }
    final bodyC = Offset(0, -lh - bh / 2);
    // legs
    for (var i = 0; i < 4; i++) {
      final lx = -bw * .32 + (i ~/ 2) * bw * .64 + (i.isOdd ? 4 : -2);
      final sw = sin(walk * 12 + i * pi / 2) * 4;
      c.drawLine(Offset(lx, -lh - 2), Offset(lx + sw, 0), legP);
    }
    // tail
    if (type == 4) {
      c.drawArc(Rect.fromCircle(center: Offset(bw / 2 + 3, bodyC.dy - 2), radius: 4), 0, pi * 1.5, false, D.stroke(col, 2.5));
    } else if (type == 0) {
      c.drawPath(Path()
        ..moveTo(bw / 2, bodyC.dy)
        ..quadraticBezierTo(bw / 2 + 12, bodyC.dy - 10, bw / 2 + 16, bodyC.dy + 2), D.stroke(const Color(0xFFFFA3B8), 2));
    }
    // body
    final body = Rect.fromCenter(center: bodyC, width: bw, height: bh);
    if (type == 3) {
      for (var i = 0; i < 6; i++) {
        final o = bodyC + Offset(-bw * .35 + (i % 3) * bw * .35, (i < 3 ? -bh * .22 : bh * .2));
        c.drawCircle(o, bh * .38, D.fill(col));
        c.drawCircle(o, bh * .38, ink);
      }
      for (var i = 0; i < 6; i++) {
        final o = bodyC + Offset(-bw * .35 + (i % 3) * bw * .35, (i < 3 ? -bh * .22 : bh * .2));
        c.drawCircle(o, bh * .3, D.fill(col));
      }
    } else {
      c.drawOval(body, D.fill(col));
      if (type == 5) {
        c.drawOval(Rect.fromCenter(center: bodyC + Offset(4, -3), width: 14, height: 10), D.fill(Pal.ink));
        c.drawOval(Rect.fromCenter(center: bodyC + Offset(-10, 5), width: 10, height: 7), D.fill(Pal.ink));
      }
      if (type == 6) {
        for (final o in const [Offset(-8, -3), Offset(6, 2), Offset(-2, 6), Offset(10, -5)]) {
          c.drawCircle(bodyC + o, 3.5, D.fill(const Color(0xFFB0702A)));
        }
      }
      c.drawOval(body, ink);
    }
    // head
    var head = Offset(-bw / 2 - 2, bodyC.dy - bh * .35);
    var hr = bh * .48;
    switch (type) {
      case 0:
        hr = 8;
        head = Offset(-bw / 2 - 2, bodyC.dy - 2);
      case 1:
        hr = 9;
        head = Offset(-bw / 2, bodyC.dy - 8);
      case 6:
        hr = 8;
        head = Offset(-bw / 2 - 4, bodyC.dy - 40);
        final neck = Path()
          ..moveTo(-bw / 2 + 2, bodyC.dy - 4)
          ..lineTo(-bw / 2 - 8, bodyC.dy - 38)
          ..lineTo(-bw / 2, bodyC.dy - 40)
          ..lineTo(-bw / 2 + 12, bodyC.dy - 6)
          ..close();
        c.drawPath(neck, D.fill(col));
        c.drawPath(neck, ink);
        c.drawCircle(Offset(-bw / 2 - 1, bodyC.dy - 22), 3, D.fill(const Color(0xFFB0702A)));
      case 7:
        hr = 15;
        head = Offset(-bw / 2 - 2, bodyC.dy - 6);
      default:
        break;
    }
    // ears behind head
    final headC = type == 3 ? const Color(0xFF3A3346) : col;
    if (type == 0) {
      D.circle(c, head + const Offset(3, -8), 6, const Color(0xFFFFB8C8), border: Pal.ink, borderWidth: 2);
    } else if (type == 1) {
      for (final dx in const [-3.0, 3.0]) {
        c.drawOval(Rect.fromCenter(center: head + Offset(dx + 2, -16), width: 6, height: 18), D.fill(col));
        c.drawOval(Rect.fromCenter(center: head + Offset(dx + 2, -16), width: 6, height: 18), ink);
      }
    } else if (type == 7) {
      c.drawOval(Rect.fromCenter(center: head + const Offset(10, 0), width: 20, height: 26), D.fill(Color.lerp(col, Pal.ink, .12)!));
      c.drawOval(Rect.fromCenter(center: head + const Offset(10, 0), width: 20, height: 26), ink);
    } else if (type == 6) {
      D.line(c, head + const Offset(-2, -6), head + const Offset(-3, -13), Pal.ink, 2.5);
      D.line(c, head + const Offset(3, -6), head + const Offset(4, -13), Pal.ink, 2.5);
    } else if (type == 5) {
      D.line(c, head + const Offset(-5, -9), head + const Offset(-9, -16), const Color(0xFFE8E0C8), 3);
      D.line(c, head + const Offset(5, -9), head + const Offset(9, -16), const Color(0xFFE8E0C8), 3);
    }
    c.drawCircle(head, hr, D.fill(headC));
    c.drawCircle(head, hr, ink);
    // snouts & trunks
    if (type == 4) {
      c.drawOval(Rect.fromCenter(center: head + Offset(-hr * .6, hr * .3), width: 9, height: 7), D.fill(const Color(0xFFFF7A9A)));
      c.drawOval(Rect.fromCenter(center: head + Offset(-hr * .6, hr * .3), width: 9, height: 7), ink);
    } else if (type == 5) {
      c.drawOval(Rect.fromCenter(center: head + Offset(-hr * .4, hr * .45), width: 14, height: 8), D.fill(const Color(0xFFFFB8C8)));
    } else if (type == 7) {
      final trunk = Path()
        ..moveTo(head.dx - 8, head.dy + 2)
        ..quadraticBezierTo(head.dx - 20, head.dy + 10, head.dx - 16, head.dy + 26)
        ..lineTo(head.dx - 10, head.dy + 25)
        ..quadraticBezierTo(head.dx - 12, head.dy + 12, head.dx - 2, head.dy + 8)
        ..close();
      c.drawPath(trunk, D.fill(col));
      c.drawPath(trunk, ink);
    }
    D.face(c, head + Offset(-hr * .15, -1), hr * .85, face, ink: type == 3 ? Pal.white : Pal.ink);
    c.restore();
  }
}

class _Animal {
  _Animal(this.type);
  final int type;
  double x = 0;
  double anim = 0;
  bool walking = false;
  double swimT = 0;
  // on deck
  double lx = 0, ly = 0, vy = 0;
  double joy = 0;
}

class _Flyer {
  _Flyer(this.type, this.pos, this.vel);
  final int type;
  Offset pos;
  Offset vel;
  double spin = 0;
  bool splashed = false;
}
