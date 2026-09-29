import '../engine/engine.dart';

/// No.120 Cell to Galaxy — tap the floating food / DNA to feed your creature,
/// fill the meter and EVOLVE: cell > fish > frog > monkey > human > robot >
/// planet > galaxy. Avoid the viruses.
class G120 extends MiniGame {
  static const _auto = bool.fromEnvironment('AUTOPLAY');
  static const _need = <int>[2, 3, 3, 4, 4, 4, 4];
  static const _home = Offset(180, 350);
  static const _names = <(String, String)>[
    ('cell', 'CELL'), ('fish', 'FISH'), ('frog', 'FROG'), ('monkey', 'MONKEY'),
    ('human', 'HUMAN'), ('robot', 'ROBOT'), ('planet', 'PLANET'), ('galaxy', 'GALAXY'),
  ];

  int _stage = 0;
  int _meter = 0;
  double _shownMeter = 0;
  final List<_Orb> _orbs = [];
  double _t = 0;
  double _evoT = -1; // >=0 while transforming
  double _reveal = 1; // 0..1 new world iris reveal
  int _prevStage = 0;
  double _pop = 0; // creature scale pop
  double _hurt = 0;
  double _chomp = 0;
  double _autoCd = 0;
  bool _won = false;
  final List<Offset> _stars = [];

  @override
  void init() {
    for (var i = 0; i < 70; i++) {
      _stars.add(Offset(rand(0, 360), rand(40, 640)));
    }
    for (var i = 0; i < 7; i++) {
      _spawn(initial: true);
    }
  }

  void _spawn({bool initial = false}) {
    final k = rng.nextDouble();
    final kind = k < .16 ? _OK.bad : (k < .4 ? _OK.dna : _OK.food);
    Offset p;
    var tries = 0;
    do {
      p = Offset(rand(40, 320), rand(130, 600));
      tries++;
    } while ((p - _home).distance < 110 && tries < 20);
    final a = rand(0, pi * 2);
    final sp = rand(30, 70) * host.speed;
    _orbs.add(_Orb(p, Offset(cos(a), sin(a)) * sp, kind)..age = initial ? rand(.3, 1) : 0);
  }

  @override
  void update(double dt) {
    _t += dt;
    _pop = M.approach(_pop, 0, 5, dt);
    _hurt = M.approach(_hurt, 0, 3, dt);
    _chomp = M.approach(_chomp, 0, 10, dt);
    _shownMeter = M.approach(_shownMeter, _meter.toDouble(), 12, dt);
    if (_auto && !host.finished) _autoPlay(dt);

    for (final o in _orbs) {
      o.age += dt;
      if (o.eaten >= 0) {
        o.eaten += dt / .22;
        if (o.eaten >= 1) {
          o.dead = true;
          _feed(o);
        }
        continue;
      }
      o.p += o.v * dt;
      if (o.p.dx < 26 || o.p.dx > 334) o.v = Offset(-o.v.dx, o.v.dy);
      if (o.p.dy < 120 || o.p.dy > 610) o.v = Offset(o.v.dx, -o.v.dy);
      o.p = Offset(o.p.dx.clamp(26, 334), o.p.dy.clamp(120, 610));
      // gentle avoidance of the creature so food doesn't hide behind it
      final d = o.p - _home;
      if (d.distance < 95) o.p = _home + d / max(d.distance, 1) * 95;
    }
    _orbs.removeWhere((o) => o.dead);

    if (_evoT >= 0) {
      _evoT += dt;
      if (_evoT >= .35 && _prevStage == _stage) {
        _stage++;
        _reveal = 0;
        host.flash(Pal.white, .3);
        host.shake(9, .35);
        host.sfx(Sfx.explode, volume: .5);
        host.sfx(Sfx.ssr);
        host.fx.ring(_home, Pal.white, size: 260, life: .6);
        host.fx.burst(_home, Pal.white, count: 40, speed: 460, shape: PartShape.star, colors: Pal.candy);
        final n = _names[_stage];
        host.fx.pop(host.tr(n.$1, n.$2), _home + const Offset(0, -150), color: Pal.yellow, size: 40, life: 1.1);
        _pop = 1;
        _orbs.clear();
        for (var i = 0; i < 7; i++) {
          _spawn(initial: true);
        }
        if (_stage == 7) {
          _won = true;
          host.sfx(Sfx.fanfare);
          host.fx.pop(host.tr('god', 'GOD!'), _home + const Offset(0, 150), color: Pal.pink, size: 56, life: 1.5);
          final left = host.timeLeft;
          host.win(stars: left > 5 ? 3 : (left > 2 ? 2 : 1));
        }
      }
      if (_evoT >= .75) _evoT = -1;
    }
    if (_reveal < 1) _reveal = min(1, _reveal + dt / .45);

    if (!host.finished && _evoT < 0) {
      final live = _orbs.where((o) => o.eaten < 0).length;
      if (live < 7) _spawn();
    }
  }

  void _autoPlay(double dt) {
    _autoCd -= dt;
    if (_autoCd > 0) return;
    _autoCd = .33;
    _Orb? best;
    for (final o in _orbs) {
      if (o.kind == _OK.bad || o.eaten >= 0) continue;
      if (best == null || o.kind == _OK.dna && best.kind != _OK.dna) best = o;
    }
    if (best != null) onDown(best.p);
  }

  void _feed(_Orb o) {
    if (host.finished || _evoT >= 0) return;
    if (o.kind == _OK.bad) {
      _meter = max(0, _meter - 1);
      _hurt = 1;
      host.sfx(Sfx.hurt);
      host.sfx(Sfx.glitch, volume: .5);
      host.shake(7);
      host.flash(const Color(0xFF8C4DFF), .15);
      host.fx.burst(_home, Pal.purple, count: 18, speed: 260);
      host.fx.pop(host.tr('virus', 'VIRUS!'), _home + const Offset(0, -110), color: Pal.purple, size: 28);
      return;
    }
    final v = o.kind == _OK.dna ? 2 : 1;
    _meter += v;
    _chomp = 1;
    host.sfx(o.kind == _OK.dna ? Sfx.powerup : Sfx.chomp, rate: 1 + _stage * .07);
    host.fx.sparkle(_home, count: 6, radius: 50, color: o.kind == _OK.dna ? Pal.yellow : Pal.lime);
    host.fx.pop('+$v', _home + Offset(rand(-40, 40), -90), color: o.kind == _OK.dna ? Pal.yellow : Pal.lime, size: 26);
    if (_meter >= _need[_stage]) {
      _meter = 0;
      _evoT = 0;
      _prevStage = _stage;
      host.sfx(Sfx.rarityUp);
      host.sfx(Sfx.magic, volume: .7);
      host.punch(.05);
      host.fx.pop(host.tr('evolve', 'EVOLVE!'), _home + const Offset(0, -150), color: Pal.white, size: 38, life: .6);
    }
  }

  @override
  void onDown(Offset p) {
    if (host.finished || _evoT >= 0) return;
    _Orb? hit;
    var bd = 1e9;
    for (final o in _orbs) {
      if (o.eaten >= 0) continue;
      final d = (o.p - p).distance;
      if (d < 44 && d < bd) {
        bd = d;
        hit = o;
      }
    }
    if (hit == null) {
      host.fx.ring(p, const Color(0x88FFFFFF), size: 30, life: .25);
      host.sfx(Sfx.tap, volume: .4);
      return;
    }
    hit.eaten = 0;
    hit.from = hit.p;
    host.sfx(Sfx.pop, rate: 1.2 + rand(0, .3));
    host.fx.burst(hit.p, hit.kind == _OK.bad ? Pal.purple : _foodCol(_stage), count: 8, speed: 140, gravity: 0);
  }

  @override
  void onKey(String key, bool down) {
    if (!down || key != 'action') return;
    // desktop helper: grab the nearest good orb
    _Orb? best;
    for (final o in _orbs) {
      if (o.kind == _OK.bad || o.eaten >= 0) continue;
      if (best == null || (o.p - _home).distance < (best.p - _home).distance) best = o;
    }
    if (best != null) onDown(best.p);
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    // old world, then new world revealed through an expanding iris
    if (_reveal < 1 && _stage > 0) {
      _bg(c, _stage - 1);
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCircle(center: _home, radius: 20 + M.easeInOut(_reveal) * 700)));
      _bg(c, _stage);
      c.restore();
      c.drawCircle(_home, 20 + M.easeInOut(_reveal) * 700, D.stroke(Color.fromRGBO(255, 255, 255, 1 - _reveal), 14));
    } else {
      _bg(c, _stage);
    }

    // evolution charge-up: rays and a white silhouette pulse
    if (_evoT >= 0) {
      final k = (_evoT / .35).clamp(0.0, 1.0);
      D.rays(c, _home, 400, Color.fromRGBO(255, 255, 255, .35 * k), count: 16, t: _t * 6);
    }
    if (_stage >= 5) {
      D.rays(c, _home, 300, Color.fromRGBO(255, 240, 180, .08 + (_stage == 7 ? .12 : 0)), count: 12, t: _t * .5);
    }

    if (_won) D.rays(c, _home, 500, D.hsv(_t * 120, .6, 1, .22), count: 20, t: _t * 2);

    // orbs
    for (final o in _orbs) {
      var p = o.p;
      var s = min(1.0, o.age * 4);
      if (o.eaten >= 0) {
        final e = M.easeInOut(o.eaten.clamp(0, 1));
        p = Offset.lerp(o.from, _home, e)!;
        s = 1 - e * .7;
      }
      _drawOrb(c, o, p, s);
    }

    // creature
    final charging = _evoT >= 0 && _evoT < .35;
    final sc = 1 + _pop * .35 * sin(_pop * 9) + _chomp * .08 + (charging ? (_evoT / .35) * .25 : 0);
    c.save();
    c.translate(_home.dx + sin(_t * 40) * _hurt * 6, _home.dy + sin(_t * 2) * 4);
    c.scale(sc, sc * (1 - _chomp * .06));
    _creature(c, _stage);
    if (charging) {
      c.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, (_evoT / .35) * .9)..blendMode = BlendMode.srcATop);
      c.drawRect(const Rect.fromLTWH(-200, -200, 400, 400), D.fill(Pal.white));
      c.restore();
    }
    c.restore();

    _hud(c);

    if (host.time < 2.4 && _stage == 0 && _meter == 0) {
      _Orb? near;
      for (final o in _orbs) {
        if (o.kind != _OK.bad && o.eaten < 0) near ??= o;
      }
      if (near != null) D.hand(c, near.p, _t);
    }
  }

  void _hud(Canvas c) {
    // evolution chain
    for (var i = 0; i < 8; i++) {
      final p = Offset(40 + i * 40.0, 64);
      final done = i < _stage, cur = i == _stage;
      if (i > 0) c.drawLine(p - const Offset(32, 0), p - const Offset(8, 0), D.stroke(done || cur ? Pal.yellow : const Color(0x55FFFFFF), 3));
      D.circle(c, p, cur ? 16 : 12, done ? Pal.yellow : (cur ? Pal.white : const Color(0x55000000)),
          border: Pal.ink, borderWidth: 2.5);
      c.save();
      c.translate(p.dx, p.dy);
      c.scale((cur ? 16 : 12) / 70);
      if (done || cur) {
        _creature(c, i, icon: true);
      } else {
        D.text(c, '?', Offset.zero, size: 70, color: const Color(0x88FFFFFF));
      }
      c.restore();
    }
    // meter
    if (_stage < 7) {
      final need = _need[_stage];
      const r = Rect.fromLTWH(90, 98, 180, 16);
      D.bar(c, r, _shownMeter / need, Pal.lime, border: Pal.white);
      for (var i = 1; i < need; i++) {
        final x = r.left + r.width * i / need;
        c.drawLine(Offset(x, r.top + 3), Offset(x, r.bottom - 3), D.stroke(const Color(0x88000000), 2));
      }
      D.text(c, 'DNA', const Offset(66, 106), size: 14, color: Pal.white, stroke: Pal.ink);
    }
  }

  // --------------------------------------------------------- backgrounds ---
  void _bg(Canvas c, int s) {
    switch (s) {
      case 0:
        D.gradientBg(c, const [Color(0xFFB8F5D0), Color(0xFF5CC8A8)]);
        for (var i = 0; i < 14; i++) {
          final p = Offset((i * 71 + sin(_t + i) * 10) % 360, (i * 113 + _t * 10) % 640);
          c.drawCircle(p, 8 + i % 4 * 6.0, D.stroke(const Color(0x44FFFFFF), 3));
        }
        // microscope vignette
        c.drawRect(
            const Rect.fromLTWH(0, 0, 360, 640),
            Paint()
              ..shader = const RadialGradient(colors: [Color(0x00000000), Color(0x00000000), Color(0xCC0A2A20)], stops: [0, .6, 1])
                  .createShader(Rect.fromCircle(center: _home, radius: 380)));
      case 1:
        D.gradientBg(c, const [Color(0xFF4FC3F7), Color(0xFF1565C0), Color(0xFF0B2C6B)]);
        for (var i = 0; i < 5; i++) {
          final x = 40 + i * 80.0 + sin(_t * .5 + i) * 20;
          c.drawPath(
              Path()
                ..moveTo(x, 40)
                ..lineTo(x + 30, 40)
                ..lineTo(x - 40, 640)
                ..lineTo(x - 90, 640)
                ..close(),
              D.fill(const Color(0x14FFFFFF)));
        }
        for (var i = 0; i < 6; i++) {
          final x = 20 + i * 64.0;
          final sw = sin(_t * 2 + i) * 12;
          c.drawPath(
              Path()
                ..moveTo(x, 640)
                ..quadraticBezierTo(x + sw, 590, x - sw * .5, 540 - i % 3 * 20),
              D.stroke(const Color(0xFF2E9E57), 9));
        }
        for (var i = 0; i < 10; i++) {
          c.drawCircle(Offset((i * 37) % 360.0, 640 - (i * 97 + _t * 60) % 600), 3 + i % 3 * 2.0, D.stroke(const Color(0x88FFFFFF), 2));
        }
      case 2:
        D.gradientBg(c, const [Color(0xFF9EE6FF), Color(0xFFD6F5FF)], rect: const Rect.fromLTWH(0, 0, 360, 230));
        D.cloud(c, Offset(80 + _t * 8 % 60, 120), 60);
        D.cloud(c, const Offset(280, 160), 44);
        D.gradientBg(c, const [Color(0xFF4CAF7A), Color(0xFF1F6E4A)], rect: const Rect.fromLTWH(0, 230, 360, 410));
        for (var i = 0; i < 7; i++) {
          final p = Offset((i * 97 + 30) % 340.0 + 10, 270 + (i * 71) % 350.0);
          c.drawOval(Rect.fromCenter(center: p, width: 70, height: 26), D.fill(const Color(0xFF6FD66F)));
          c.drawOval(Rect.fromCenter(center: p, width: 70, height: 26), D.stroke(const Color(0xFF2E8B57), 3));
        }
        for (var i = 0; i < 4; i++) {
          c.drawOval(
              Rect.fromCenter(center: Offset(60 + i * 90.0, 300 + i * 80.0), width: 40 + (_t * 30 + i * 20) % 60, height: 12 + (_t * 10 + i * 7) % 20),
              D.stroke(const Color(0x55FFFFFF), 2));
        }
      case 3:
        D.gradientBg(c, const [Color(0xFF7BD35B), Color(0xFF2E7D32), Color(0xFF1B4D22)]);
        for (var i = 0; i < 7; i++) {
          final x = i * 60.0 + 10;
          final sw = sin(_t * 1.5 + i) * 10;
          c.drawPath(
              Path()
                ..moveTo(x, 36)
                ..quadraticBezierTo(x + sw, 150, x + sw * 1.5, 190 + i % 3 * 50),
              D.stroke(const Color(0xFF3E6B1F), 6));
          for (var k = 0; k < 3; k++) {
            final lp = Offset(x + sw * (k / 3), 80 + k * 45.0 + i % 3 * 10);
            c.drawOval(Rect.fromCenter(center: lp + const Offset(8, 0), width: 22, height: 10), D.fill(const Color(0xFF66BB44)));
          }
        }
        for (var i = 0; i < 6; i++) {
          D.tree(c, Offset(i * 70.0 - 10, 660), 180 + i % 3 * 30.0, leaf: const Color(0xFF1E5E2A));
        }
      case 4:
        D.gradientBg(c, const [Color(0xFFFF9E5E), Color(0xFFFF5F8F), Color(0xFF6A3FA0)]);
        c.drawCircle(const Offset(180, 470), 90, D.fill(const Color(0x66FFE27A)));
        for (var i = 0; i < 10; i++) {
          final w = 30.0 + i % 3 * 12, h = 120.0 + (i * 53) % 160;
          final x = i * 38.0 - 10;
          final r = Rect.fromLTWH(x, 640 - h, w, h);
          c.drawRect(r, D.fill(const Color(0xFF2A1B45)));
          for (var wy = r.top + 10; wy < r.bottom - 10; wy += 16) {
            for (var wx = r.left + 6; wx < r.right - 6; wx += 10) {
              if (((wx * 7 + wy * 3) ~/ 1) % 5 != 0) c.drawRect(Rect.fromLTWH(wx, wy, 5, 7), D.fill(const Color(0xAAFFE27A)));
            }
          }
        }
      case 5:
        D.gradientBg(c, const [Color(0xFF0A0F2E), Color(0xFF1A1050), Color(0xFF3A0F5E)]);
        final g = D.stroke(const Color(0x6614C9C9), 2);
        for (var i = 0; i < 12; i++) {
          final y = 420 + pow(i / 12, 2) * 220 + (_t * 30 % 18) * (i / 12);
          c.drawLine(Offset(0, y.toDouble()), Offset(360, y.toDouble()), g);
        }
        for (var i = -8; i <= 8; i++) {
          c.drawLine(Offset(180 + i * 10.0, 420), Offset(180 + i * 60.0, 640), g);
        }
        c.drawLine(const Offset(0, 420), const Offset(360, 420), D.stroke(const Color(0xFFFF5FC8), 3));
        for (var i = 0; i < 20; i++) {
          c.drawCircle(_stars[i] - const Offset(0, 200), 1.5, D.fill(const Color(0x88FFFFFF)));
        }
      default:
        D.gradientBg(c, s == 6 ? const [Color(0xFF05061A), Color(0xFF0E1440)] : const [Color(0xFF12002A), Color(0xFF3A0A5E), Color(0xFF05010F)]);
        if (s == 7) {
          for (var i = 0; i < 5; i++) {
            c.drawCircle(Offset(60 + i * 70.0, 150 + (i * 97) % 400.0), 90,
                D.fill(D.hsv(280 + i * 30, .7, .8, .12)));
          }
        }
        for (var i = 0; i < _stars.length; i++) {
          final tw = .4 + .6 * M.wave(_t + i * .37, .8);
          c.drawCircle(_stars[i], 1 + (i % 3) * .7, D.fill(Color.fromRGBO(255, 255, 255, tw)));
        }
        if (s == 6) {
          c.drawCircle(const Offset(40, 120), 60, D.fill(const Color(0x33FFD23F)));
          c.drawCircle(const Offset(40, 120), 34, D.fill(const Color(0xFFFFD23F)));
        }
    }
  }

  Color _foodCol(int s) => const [Pal.lime, Pal.pink, Color(0xFF333333), Pal.yellow, Pal.orange, Pal.teal, Pal.gray, Pal.yellow][s];

  // ------------------------------------------------------------- orbs ---
  void _drawOrb(Canvas c, _Orb o, Offset p, double s) {
    final bob = sin(_t * 3 + o.v.dx) * 3;
    c.save();
    c.translate(p.dx, p.dy + bob);
    c.scale(s);
    switch (o.kind) {
      case _OK.bad:
        c.drawCircle(Offset.zero, 30, D.fill(const Color(0x338C4DFF)));
        for (var i = 0; i < 8; i++) {
          final a = i / 8 * pi * 2 + _t;
          c.drawLine(Offset(cos(a), sin(a)) * 12, Offset(cos(a), sin(a)) * 22, D.stroke(const Color(0xFF5B1FA8), 4));
          c.drawCircle(Offset(cos(a), sin(a)) * 22, 3.5, D.fill(const Color(0xFFB04DFF)));
        }
        D.circle(c, Offset.zero, 15, const Color(0xFF8C4DFF), border: Pal.ink, borderWidth: 2.5);
        D.face(c, Offset.zero, 12, Face.angry, blush: false);
      case _OK.dna:
        c.drawCircle(Offset.zero, 28, D.fill(const Color(0x44FFD23F)));
        D.circle(c, Offset.zero, 20, const Color(0xFFFFF3B0), border: Pal.gold, borderWidth: 3);
        for (var i = 0; i < 2; i++) {
          final path = Path();
          for (var k = 0; k <= 12; k++) {
            final y = -14 + k * 28 / 12;
            final x = sin(k / 12 * pi * 2 + i * pi + _t * 4) * 8;
            k == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
          }
          c.drawPath(path, D.stroke(i == 0 ? Pal.red : Pal.blue, 3));
        }
        for (var k = 1; k < 12; k += 2) {
          final y = -14 + k * 28 / 12;
          final x = sin(k / 12 * pi * 2 + _t * 4) * 8;
          c.drawLine(Offset(x, y), Offset(-x, y), D.stroke(const Color(0xFF8E8AA3), 1.5));
        }
      case _OK.food:
        c.drawCircle(Offset.zero, 26, D.fill(_foodCol(_stage).withValues(alpha: .25)));
        D.circle(c, Offset.zero, 19, const Color(0xEEFFFFFF), border: _foodCol(_stage), borderWidth: 3);
        _foodIcon(c, _stage);
    }
    c.restore();
  }

  void _foodIcon(Canvas c, int s) {
    switch (s) {
      case 0: // nutrient
        c.drawCircle(Offset.zero, 9, D.fill(Pal.lime));
        c.drawCircle(const Offset(-3, -3), 3, D.fill(Pal.white));
      case 1: // shrimp / plankton
        c.drawArc(Rect.fromCircle(center: Offset.zero, radius: 9), .5, 4.4, false, D.stroke(Pal.pink, 6));
        c.drawCircle(const Offset(6, -6), 1.8, D.fill(Pal.ink));
      case 2: // fly
        c.drawOval(const Rect.fromLTWH(-9, -12, 10, 8), D.fill(const Color(0xAA9AD8FF)));
        c.drawOval(const Rect.fromLTWH(-1, -12, 10, 8), D.fill(const Color(0xAA9AD8FF)));
        c.drawOval(const Rect.fromLTWH(-7, -5, 14, 11), D.fill(const Color(0xFF222222)));
        c.drawCircle(const Offset(5, -2), 2, D.fill(Pal.red));
      case 3: // banana
        c.drawArc(Rect.fromCircle(center: const Offset(-4, -4), radius: 12), .1, 1.9, false, D.stroke(Pal.ink, 9));
        c.drawArc(Rect.fromCircle(center: const Offset(-4, -4), radius: 12), .1, 1.9, false, D.stroke(Pal.yellow, 6));
      case 4: // burger
        c.drawArc(const Rect.fromLTWH(-11, -11, 22, 16), pi, pi, true, D.fill(const Color(0xFFE0A050)));
        c.drawRect(const Rect.fromLTWH(-11, -3, 22, 3), D.fill(Pal.green));
        c.drawRect(const Rect.fromLTWH(-11, 0, 22, 5), D.fill(const Color(0xFF6B3A1F)));
        D.rrect(c, const Rect.fromLTWH(-11, 5, 22, 5), 2, const Color(0xFFE0A050));
      case 5: // battery
        D.rrect(c, const Rect.fromLTWH(-7, -11, 14, 22), 3, Pal.ink);
        c.drawRect(const Rect.fromLTWH(-5, -2, 10, 11), D.fill(Pal.lime));
        c.drawRect(const Rect.fromLTWH(-3, -14, 6, 3), D.fill(Pal.ink));
      case 6: // asteroid
        c.drawCircle(Offset.zero, 11, D.fill(const Color(0xFF8E8AA3)));
        c.drawCircle(const Offset(-3, -3), 3, D.fill(const Color(0xFF6A667E)));
        c.drawCircle(const Offset(4, 4), 2.5, D.fill(const Color(0xFF6A667E)));
      default: // star
        D.star(c, Offset.zero, 12, Pal.yellow, border: Pal.ink);
    }
  }

  // --------------------------------------------------------- creatures ---
  void _creature(Canvas c, int s, {bool icon = false}) {
    final t = _t;
    final face = icon ? Face.happy : (_hurt > .3 ? Face.cry : (_chomp > .3 ? Face.love : (s >= 6 ? Face.smug : Face.happy)));
    switch (s) {
      case 0: // cell
        final path = Path();
        for (var i = 0; i <= 24; i++) {
          final a = i / 24 * pi * 2;
          final r = 56 + sin(a * 5 + t * 4) * 4 + sin(a * 3 - t * 3) * 3;
          final p = Offset(cos(a) * r, sin(a) * r);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
        for (var i = 0; i < 16; i++) {
          final a = i / 16 * pi * 2 + t;
          c.drawLine(Offset(cos(a), sin(a)) * 56, Offset(cos(a + .15), sin(a + .15)) * 68, D.stroke(const Color(0xAA2E9E57), 2.5));
        }
        c.drawPath(path, D.fill(const Color(0xCC9BE22D)));
        c.drawPath(path, D.stroke(const Color(0xFF2E7D32), 4));
        c.drawCircle(const Offset(18, 16), 16, D.fill(const Color(0xAA8C4DFF)));
        c.drawCircle(const Offset(-26, 22), 6, D.fill(const Color(0x8814C9C9)));
        c.drawCircle(const Offset(28, -24), 5, D.fill(const Color(0x88FF8A1F)));
        D.face(c, const Offset(-8, -6), 30, face);
      case 1: // fish
        final sw = sin(t * 10) * .25;
        c.save();
        c.translate(46, 0);
        c.rotate(sw);
        final tail = Path()
          ..moveTo(0, 0)
          ..lineTo(34, -30)
          ..lineTo(28, 0)
          ..lineTo(34, 30)
          ..close();
        c.drawPath(tail, D.fill(const Color(0xFFFF6A2A)));
        c.drawPath(tail, D.stroke(Pal.ink, 4));
        c.restore();
        c.drawOval(const Rect.fromLTWH(-62, -40, 116, 80), D.fill(Pal.orange));
        c.drawOval(const Rect.fromLTWH(-62, -40, 116, 80), D.stroke(Pal.ink, 4));
        for (var i = 0; i < 3; i++) {
          c.drawArc(Rect.fromCenter(center: Offset(-2.0 + i * 14, 0), width: 20, height: 50), -.8, 1.6, false, D.stroke(const Color(0x55FFFFFF), 3));
        }
        final fin = Path()
          ..moveTo(-10, -38)
          ..quadraticBezierTo(10, -66, 30, -34)
          ..close();
        c.drawPath(fin, D.fill(const Color(0xFFFF6A2A)));
        c.drawPath(fin, D.stroke(Pal.ink, 3));
        D.face(c, const Offset(-30, -4), 26, face);
      case 2: // frog
        for (final sx in [-1.0, 1.0]) {
          c.drawOval(Rect.fromCenter(center: Offset(sx * 44, 44), width: 44, height: 20), D.fill(const Color(0xFF3FAF4F)));
          c.drawOval(Rect.fromCenter(center: Offset(sx * 44, 44), width: 44, height: 20), D.stroke(Pal.ink, 3));
        }
        c.drawOval(const Rect.fromLTWH(-64, -34, 128, 88), D.fill(const Color(0xFF5ACF5A)));
        c.drawOval(const Rect.fromLTWH(-64, -34, 128, 88), D.stroke(Pal.ink, 4));
        c.drawOval(const Rect.fromLTWH(-34, 6, 68, 42), D.fill(const Color(0xFFD9F7A8)));
        for (final sx in [-1.0, 1.0]) {
          D.circle(c, Offset(sx * 30, -36), 20, const Color(0xFF5ACF5A), border: Pal.ink, borderWidth: 4);
          D.circle(c, Offset(sx * 30, -38), 12, Pal.white);
          c.drawCircle(Offset(sx * 30, -37), 6, D.fill(Pal.ink));
        }
        c.drawArc(const Rect.fromLTWH(-40, -12, 80, 30), .15, pi - .3, false, D.stroke(Pal.ink, 4));
        if (_chomp > .2) {
          c.drawLine(const Offset(0, 16), Offset(0, 16 + 60 * _chomp), D.stroke(Pal.pink, 7));
        }
      case 3: // monkey
        c.drawArc(const Rect.fromLTWH(20, 10, 60, 60), -1.2, 4, false, D.stroke(const Color(0xFF7A4A2A), 8));
        c.drawOval(const Rect.fromLTWH(-40, 30, 80, 60), D.fill(const Color(0xFF9A6034)));
        c.drawOval(const Rect.fromLTWH(-40, 30, 80, 60), D.stroke(Pal.ink, 4));
        for (final sx in [-1.0, 1.0]) {
          D.circle(c, Offset(sx * 52, -10), 18, const Color(0xFF9A6034), border: Pal.ink, borderWidth: 4);
          c.drawCircle(Offset(sx * 52, -10), 10, D.fill(const Color(0xFFF2C9A0)));
        }
        D.circle(c, const Offset(0, -10), 50, const Color(0xFF9A6034), border: Pal.ink, borderWidth: 4);
        c.drawOval(const Rect.fromLTWH(-36, -30, 72, 58), D.fill(const Color(0xFFF2C9A0)));
        D.face(c, const Offset(0, -4), 32, face);
      case 4: // human (victory pose)
        const skin = Pal.skin;
        c.drawOval(const Rect.fromLTWH(-50, 70, 100, 16), D.fill(const Color(0x33000000)));
        for (final sx in [-1.0, 1.0]) {
          c.drawLine(Offset(sx * 12, 20), Offset(sx * 26, 76), D.stroke(Pal.ink, 17));
          c.drawLine(Offset(sx * 12, 20), Offset(sx * 26, 76), D.stroke(const Color(0xFF34406B), 12));
          final wave = icon ? 0.0 : sin(t * 6 + sx) * 6;
          c.drawLine(Offset(sx * 22, -24), Offset(sx * 50, -64 + wave), D.stroke(Pal.ink, 14));
          c.drawLine(Offset(sx * 22, -24), Offset(sx * 50, -64 + wave), D.stroke(skin, 9));
          D.circle(c, Offset(sx * 52, -68 + wave), 8, skin, border: Pal.ink, borderWidth: 3);
        }
        D.rrect(c, const Rect.fromLTWH(-28, -32, 56, 60), 14, Pal.blue, border: Pal.ink, borderWidth: 4);
        D.star(c, const Offset(0, -4), 12, Pal.yellow, border: Pal.ink);
        D.circle(c, const Offset(0, -62), 30, skin, border: Pal.ink, borderWidth: 4);
        c.drawArc(Rect.fromCircle(center: const Offset(0, -64), radius: 31), pi, pi, true, D.fill(const Color(0xFF3A2A20)));
        c.drawCircle(const Offset(0, -62), 30, D.stroke(Pal.ink, 4));
        D.face(c, const Offset(0, -56), 24, face);
      case 5: // robot
        c.drawLine(const Offset(0, -64), const Offset(0, -86), D.stroke(Pal.ink, 4));
        c.drawCircle(const Offset(0, -88), 7, D.fill((t * 3).floor().isEven ? Pal.red : Pal.yellow));
        for (final sx in [-1.0, 1.0]) {
          c.drawLine(Offset(sx * 40, 20), Offset(sx * 66, 40 + sin(t * 6 + sx) * 10), D.stroke(const Color(0xFF6B6F86), 10));
          D.circle(c, Offset(sx * 66, 40 + sin(t * 6 + sx) * 10), 9, const Color(0xFFB8BED3), border: Pal.ink, borderWidth: 3);
        }
        D.rrect(c, const Rect.fromLTWH(-40, 4, 80, 64), 10, const Color(0xFF9AA0B8), border: Pal.ink, borderWidth: 4);
        D.rrect(c, const Rect.fromLTWH(-16, 18, 32, 20), 5, const Color(0xFF3D6BFF), border: Pal.ink, borderWidth: 2);
        D.rrect(c, const Rect.fromLTWH(-50, -64, 100, 70), 16, const Color(0xFFC9CEDF), border: Pal.ink, borderWidth: 4);
        D.rrect(c, const Rect.fromLTWH(-38, -48, 76, 30), 12, const Color(0xFF0B1030));
        final sx2 = sin(t * 3) * 18;
        c.drawCircle(Offset(sx2 - 10, -33), 6, D.fill(const Color(0xFF14E9E9)));
        c.drawCircle(Offset(sx2 + 10, -33), 6, D.fill(const Color(0xFF14E9E9)));
        c.drawLine(const Offset(-16, -8), const Offset(16, -8), D.stroke(Pal.ink, 3));
      case 6: // planet
        c.save();
        c.rotate(-.35);
        c.drawOval(const Rect.fromLTWH(-100, -20, 200, 40), D.stroke(const Color(0xFFE0B870), 10));
        c.restore();
        c.save();
        c.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 62)));
        c.drawCircle(Offset.zero, 62, D.fill(const Color(0xFF3D8BFF)));
        final off = (t * 18) % 140;
        for (var i = 0; i < 3; i++) {
          final x = -80 + ((i * 60 + off) % 140);
          c.drawOval(Rect.fromCenter(center: Offset(x, -20.0 + i * 22), width: 40, height: 26), D.fill(const Color(0xFF4CC46A)));
        }
        c.drawCircle(const Offset(22, 22), 60, D.fill(const Color(0x33000000)));
        c.restore();
        c.drawCircle(Offset.zero, 62, D.stroke(Pal.ink, 4));
        c.save();
        c.rotate(-.35);
        c.drawArc(const Rect.fromLTWH(-100, -20, 200, 40), 0, pi, false, D.stroke(const Color(0xFFE0B870), 10));
        c.restore();
        D.face(c, const Offset(0, -4), 34, face);
      default: // galaxy
        c.drawCircle(Offset.zero, 90, D.fill(const Color(0x338C4DFF)));
        for (var arm = 0; arm < 3; arm++) {
          for (var k = 0; k < 26; k++) {
            final r = 12 + k * 3.4;
            final a = arm * pi * 2 / 3 + k * .19 + t * 1.2;
            final col = D.hsv(260 + k * 6 + arm * 30, .6, 1, 1 - k / 30);
            c.drawCircle(Offset(cos(a) * r, sin(a) * r * .7), 4.5 - k * .12, D.fill(col));
          }
        }
        c.drawCircle(Offset.zero, 30, D.fill(const Color(0xAAFFF3B0)));
        c.drawCircle(Offset.zero, 20, D.fill(Pal.white));
        D.face(c, const Offset(0, 0), 20, icon ? Face.happy : Face.smug);
    }
  }
}

enum _OK { food, dna, bad }

class _Orb {
  _Orb(this.p, this.v, this.kind) : from = p;
  Offset p;
  Offset v;
  final _OK kind;
  double age = 0;
  double eaten = -1;
  Offset from;
  bool dead = false;
}
