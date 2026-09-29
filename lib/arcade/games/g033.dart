import '../engine/engine.dart';

/// No.033 Burger Tower — ingredients rain down; slide the plate to catch
/// them in EXACTLY the order on the ticket. Wrong stuff (or a boot!) makes a
/// mess, catching off-center makes the tower lean. 2 orders = win.
class G033 extends MiniGame {
  static const _goal = 2;
  static const _plateY = 596.0;
  // kinds: 0 bottom bun, 1 patty, 2 cheese, 3 lettuce, 4 tomato, 5 top bun, 6 boot, 7 fish
  static const _heights = [18.0, 17.0, 7.0, 10.0, 9.0, 30.0, 0.0, 0.0];
  static const _orders1 = [
    [1, 2, 3, 5],
    [1, 3, 2, 5],
    [1, 4, 2, 5],
  ];
  static const _orders2 = [
    [1, 2, 4, 1, 5],
    [1, 3, 1, 2, 5],
    [1, 2, 3, 4, 5],
  ];

  double _plateX = 180;
  double _targetX = 180;
  double _plateVel = 0;
  double _lean = 0;
  double _leanV = 0;
  final List<_Layer> _stack = [];
  List<int> _order = const [];
  int _next = 0;
  int _done = 0;
  int _mess = 0;
  final List<_Fall> _falls = [];
  final List<_Fall> _junk = [];
  final List<_Splat> _splats = [];
  double _spawnT = .3;
  double _lastSpawnX = 180;
  int _sinceNeeded = 0;
  double _t = 0;
  double _deliverT = -1;
  List<_Layer> _delivering = [];
  double _custBounce = 0;
  Face _custFace = Face.happy;
  double _faceT = 0;
  bool _toppled = false;
  double _money = 0;
  double _shown = 0;
  int _combo = 0;
  bool _keyL = false, _keyR = false;

  @override
  void init() {
    _newOrder();
  }

  void _newOrder() {
    _order = _done == 0 ? pick(_orders1) : pick(_orders2);
    _next = 0;
    _stack
      ..clear()
      ..add(_Layer(0, 0));
  }

  int get _needKind => _next < _order.length ? _order[_next] : -1;

  double get _stackTopY {
    var y = _plateY - 6;
    for (final l in _stack) {
      y -= _heights[l.kind];
    }
    return y;
  }

  double _layerX(int i) => _plateX + _stack[i].off + _lean * i * 2.2;

  double get _com {
    if (_stack.length < 2) return 0;
    var s = 0.0;
    for (final l in _stack) {
      s += l.off;
    }
    return s / _stack.length;
  }

  @override
  void update(double dt) {
    _t += dt;
    _shown = M.approach(_shown, _money, 7, dt);
    _custBounce = M.approach(_custBounce, 0, 6, dt);
    if (_faceT > 0) {
      _faceT -= dt;
      if (_faceT <= 0) _custFace = Face.happy;
    }
    if (_keyL) _targetX -= 420 * dt;
    if (_keyR) _targetX += 420 * dt;
    _targetX = _targetX.clamp(50.0, 310.0);
    final prev = _plateX;
    if (!_toppled) _plateX = M.approach(_plateX, _targetX, 16, dt);
    _plateVel = (_plateX - prev) / max(dt, 1e-4);
    // lean spring: inertia from plate movement + COM
    final force = -_plateVel * .0045 - _lean * 38 + _com * .25;
    _leanV += force * dt * 10;
    _leanV /= 1 + 4.5 * dt;
    _lean += _leanV * dt;
    _lean = _lean.clamp(-9.0, 9.0);
    for (final l in _stack) {
      l.squash = M.approach(l.squash, 0, 9, dt);
    }

    if (_toppled) {
      for (final j in _junk) {
        j.vy += 900 * dt;
        j.y += j.vy * dt;
        j.x += j.vx * dt;
        j.rot += j.spin * dt;
      }
      return;
    }

    // spawn
    if (!host.finished && _deliverT < 0) {
      _spawnT -= dt;
      if (_spawnT <= 0) {
        _spawnT = (.62 + rand(-.08, .1)) / host.speed;
        _spawn();
      }
    }
    final fallSpeed = 235 * host.speed;
    final topY = _stackTopY;
    for (final f in _falls) {
      f.vy = min(fallSpeed + f.extra, f.vy + 900 * dt);
      f.y += f.vy * dt;
      f.rot += f.spin * dt;
      f.x += sin(_t * 3 + f.seed) * 14 * dt;
      if (!f.dead && !host.finished && f.y + 8 >= topY && f.y - f.vy * dt + 8 < topY + 4) {
        final topX = _layerX(_stack.length - 1);
        final dx = f.x - topX;
        if (dx.abs() < 50) {
          f.dead = true;
          _catch(f, dx);
        }
      }
    }
    _falls.removeWhere((f) => f.dead || f.y > 700);
    for (final j in _junk) {
      j.vy += 900 * dt;
      j.y += j.vy * dt;
      j.x += j.vx * dt;
      j.rot += j.spin * dt;
    }
    _junk.removeWhere((j) => j.y > 720);
    for (final s in _splats) {
      s.t += dt;
    }
    _splats.removeWhere((s) => s.t > 2.5);

    if (_deliverT >= 0) {
      _deliverT += dt * 1.6;
      if (_deliverT >= 1) {
        _deliverT = -1;
        _delivering = [];
        _custBounce = 1;
        _custFace = Face.love;
        _faceT = 1.2;
        host.sfx(Sfx.chomp);
        host.sfx(Sfx.cash);
        host.fx.coins(const Offset(296, 150), count: 18);
        host.fx.burst(const Offset(296, 150), Pal.yellow, count: 18, speed: 280, shape: PartShape.star,
            colors: const [Pal.yellow, Pal.white, Pal.orange]);
        final pay = 1200 + (_mess == 0 ? 600 : 0);
        _money += pay;
        host.addScore(pay);
        host.fx.pop('+$pay', const Offset(296, 90), color: Pal.gold, size: 28);
        if (_done >= _goal && !host.finished) {
          host.fx.confetti();
          host.sfx(Sfx.fanfare);
          host.win(stars: _mess == 0 && host.time < 15 ? 3 : (_mess <= 1 ? 2 : 1));
        } else {
          _newOrder();
        }
      }
    }
  }

  void _spawn() {
    final need = _needKind;
    int kind;
    final forceNeed = _sinceNeeded >= 2;
    if (need >= 0 && (forceNeed || chance(.5))) {
      kind = need;
      _sinceNeeded = 0;
    } else {
      _sinceNeeded++;
      final pool = <int>[1, 2, 3, 4, 5, 6, 7, 1, 2, 3, 4]..removeWhere((k) => k == need);
      kind = pick(pool);
    }
    var x = rand(40, 320);
    var guard = 0;
    while ((x - _lastSpawnX).abs() < 70 && guard++ < 6) {
      x = rand(40, 320);
    }
    _lastSpawnX = x;
    _falls.add(_Fall(kind, x, 30)
      ..vy = 60
      ..extra = rand(-20, 40)
      ..spin = rand(-2, 2)
      ..seed = rand(0, 6));
  }

  void _catch(_Fall f, double dx) {
    final need = _needKind;
    if (f.kind == need) {
      final off = dx.clamp(-22.0, 22.0);
      final prevOff = _stack.last.off;
      _stack.add(_Layer(f.kind, prevOff + off * .7)..squash = 1);
      _next++;
      _combo++;
      _leanV += off * .15;
      final perfect = dx.abs() < 9;
      final at = Offset(f.x, _stackTopY);
      host.sfx(f.kind == 1 ? Sfx.sizzle : Sfx.squish, volume: .8);
      host.sfx(Sfx.pop, rate: 1 + _next * .12);
      host.punch(.02);
      host.fx.burst(at, _col(f.kind), count: 10, speed: 160, gravity: 500);
      host.addScore(perfect ? 150 : 100);
      host.fx.pop(perfect ? host.tr('perfect', 'PERFECT!') : host.tr('nice', 'NICE!'), at + const Offset(0, -30),
          color: perfect ? Pal.lime : Pal.white, size: perfect ? 24 : 20);
      _custFace = Face.happy;
      if (_combo >= 3) {
        host.fx.pop('${host.tr('combo', 'COMBO')} x$_combo', at + const Offset(0, -58), color: Pal.pink, size: 20);
      }
      if (_com.abs() > 34) {
        _topple();
        return;
      }
      if (_next >= _order.length) {
        _done++;
        _deliverT = 0;
        _delivering = List.of(_stack);
        host.sfx(Sfx.bell);
        host.sfx(Sfx.jingleWin, volume: .5);
        host.fx.pop(host.tr('order_up', 'ORDER UP!'), Offset(_plateX, _stackTopY - 50), color: Pal.yellow, size: 32, life: 1);
        host.fx.sparkle(Offset(_plateX, _stackTopY + 40), count: 14, radius: 50, color: Pal.yellow);
        _falls.clear();
      }
    } else {
      _mess++;
      _combo = 0;
      final at = Offset(f.x, _stackTopY);
      host.sfx(f.kind >= 6 ? Sfx.boing : Sfx.splat);
      host.sfx(Sfx.wrong, volume: .6);
      host.shake(8);
      host.flash(const Color(0x44FF3B5C));
      _leanV += dx.sign * 30 + (dx == 0 ? 20 : 0);
      _junk.add(_Fall(f.kind, f.x, f.y)
        ..vx = (dx >= 0 ? 1 : -1) * rand(160, 260)
        ..vy = -rand(300, 420)
        ..spin = rand(-10, 10));
      _splats.add(_Splat(at + Offset(rand(-30, 30), rand(-10, 20)), _col(f.kind)));
      host.fx.burst(at, _col(f.kind), count: 16, speed: 260, gravity: 700);
      host.fx.pop(host.tr('yuck', 'YUCK!'), at + const Offset(0, -40), color: Pal.red, size: 28);
      _custFace = Face.shocked;
      _faceT = .9;
      if (_mess >= 3) _topple();
    }
  }

  void _topple() {
    if (host.finished) return;
    _toppled = true;
    host.sfx(Sfx.crash);
    host.shake(14, .5);
    for (var i = 1; i < _stack.length; i++) {
      final l = _stack[i];
      _junk.add(_Fall(l.kind, _layerX(i), _plateY - 20 - i * 14)
        ..vx = (_com >= 0 ? 1 : -1) * rand(80, 260) + rand(-60, 60)
        ..vy = -rand(200, 500)
        ..spin = rand(-8, 8));
    }
    _stack.removeRange(1, _stack.length);
    _custFace = Face.cry;
    _faceT = 99;
    host.fx.pop(host.tr('oops', 'OOPS!'), const Offset(180, 330), color: Pal.red, size: 40, life: 1.2);
    host.lose();
  }

  Color _col(int k) => switch (k) {
        0 || 5 => const Color(0xFFE8A350),
        1 => const Color(0xFF6B3A1E),
        2 => Pal.yellow,
        3 => Pal.lime,
        4 => Pal.red,
        6 => const Color(0xFF7A5230),
        _ => Pal.sky,
      };

  @override
  void onDown(Offset p) => _targetX = p.dx;
  @override
  void onMove(Offset p) => _targetX = p.dx;

  @override
  void onKey(String key, bool down) {
    if (key == 'left') _keyL = down;
    if (key == 'right') _keyR = down;
  }

  // ----------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    _drawBg(c);
    _drawCustomer(c);
    _drawTicket(c);
    for (final s in _splats) {
      final a = (1 - (s.t - 1.8).clamp(0.0, .7) / .7);
      c.drawCircle(s.pos, 18 * min(1, s.t * 8), D.fill(s.col.withValues(alpha: .7 * a)));
      for (var k = 0; k < 5; k++) {
        final ang = k * 1.3 + s.pos.dx;
        c.drawCircle(s.pos + Offset(cos(ang) * 22, sin(ang) * 16), 6, D.fill(s.col.withValues(alpha: .7 * a)));
      }
    }
    // falling guides
    for (final f in _falls) {
      if (f.kind == _needKind) {
        c.drawLine(Offset(f.x, f.y + 20), Offset(f.x, f.y + 60), D.stroke(const Color(0x33FFFFFF), 10));
      }
      _drawIng(c, f.kind, Offset(f.x, f.y), sin(f.rot) * .25, 1, glow: f.kind == _needKind);
    }
    _drawPlateStack(c);
    for (final j in _junk) {
      _drawIng(c, j.kind, Offset(j.x, j.y), j.rot, 1);
    }
    // deliver animation
    if (_deliverT >= 0) {
      final t = M.easeInOut(_deliverT);
      final base = Offset.lerp(Offset(_plateX, _plateY - 8), const Offset(296, 186), t)! + Offset(0, -sin(t * pi) * 120);
      final s = 1 - t * .55;
      var y = 0.0;
      for (final l in _delivering) {
        y += _heights[l.kind] * s;
        _drawIng(c, l.kind, base + Offset(l.off * s, -y + _heights[l.kind] * s / 2), 0, s);
      }
    }
    _drawHud(c);
    if (host.time < 2.5 && !host.finished) {
      final k = sin(_t * 4);
      D.arrow(c, Offset(_plateX - 70 + k * 6, _plateY + 10), const Offset(-1, 0), 40, Pal.white, width: 9);
      D.arrow(c, Offset(_plateX + 70 + k * 6, _plateY + 10), const Offset(1, 0), 40, Pal.white, width: 9);
      D.hand(c, Offset(_plateX + k * 40, _plateY + 20), _t);
    }
  }

  void _drawBg(Canvas c) {
    D.gradientBg(c, const [Color(0xFFFF9E6B), Color(0xFFFFD27A), Color(0xFFFFE9B0)]);
    D.rays(c, const Offset(180, 330), 520, const Color(0x18FFFFFF), count: 16, t: _t * .15);
    // checker wall strip
    for (var i = 0; i < 18; i++) {
      for (var r = 0; r < 2; r++) {
        if ((i + r).isEven) {
          c.drawRect(Rect.fromLTWH(i * 20.0, 470 + r * 20.0, 20, 20), D.fill(const Color(0x33E8322C)));
        }
      }
    }
    // neon burger sign
    final on = (sin(_t * 7) > -.85) ? 1.0 : .4;
    c.save();
    c.translate(180, 250);
    final glow = Paint()..color = Pal.pink.withValues(alpha: .18 * on);
    c.drawCircle(Offset.zero, 70, glow);
    c.drawArc(const Rect.fromLTWH(-48, -44, 96, 70), pi, pi, false, D.stroke(Pal.pink.withValues(alpha: on), 6));
    c.drawLine(const Offset(-50, -6), const Offset(50, -6), D.stroke(Pal.lime.withValues(alpha: on), 6));
    c.drawLine(const Offset(-46, 8), const Offset(46, 8), D.stroke(Pal.orange.withValues(alpha: on), 7));
    c.drawLine(const Offset(-46, 22), const Offset(46, 22), D.stroke(Pal.pink.withValues(alpha: on), 6));
    c.restore();
    // counter at bottom
    D.rrect(c, const Rect.fromLTWH(-10, 606, 380, 50), 0, const Color(0xFFB9783F),
        gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD8995A), Color(0xFF8A5028)]));
    c.drawRect(const Rect.fromLTWH(0, 606, 360, 4), D.fill(const Color(0x66FFFFFF)));
  }

  void _drawCustomer(Canvas c) {
    final b = _custBounce;
    D.blob(c, Offset(296, 150 - b * 16), 40, const Color(0xFF7FD3FF), face: _custFace, squash: 1 + b * .2,
        look: Offset(((_plateX - 296) / 200).clamp(-1, 1), .6));
    // napkin
    final nap = Path()
      ..moveTo(276, 180 - b * 16)
      ..lineTo(316, 180 - b * 16)
      ..lineTo(296, 204 - b * 16)
      ..close();
    c.drawPath(nap, D.fill(Pal.white));
    c.drawPath(nap, D.stroke(Pal.ink, 2));
    // fork & knife
    c.drawLine(Offset(246, 140 - b * 10), Offset(250, 196 - b * 10), D.stroke(const Color(0xFFCFD5DC), 4));
    c.drawLine(Offset(346, 140 - b * 10), Offset(342, 196 - b * 10), D.stroke(const Color(0xFFCFD5DC), 4));
    if (_custFace == Face.happy && host.time > 5 && !host.finished) {
      final dots = ((_t * 3).floor() % 4);
      D.text(c, '.' * dots, const Offset(296, 94), size: 20, color: Pal.ink);
    }
  }

  void _drawTicket(Canvas c) {
    final n = _order.length + 1;
    final h = 36.0 + n * 26;
    c.save();
    c.translate(14, 48);
    c.rotate(-.03 + sin(_t * 2) * .01);
    D.rrect(c, Rect.fromLTWH(3, 4, 96, h), 6, const Color(0x33000000));
    D.rrect(c, Rect.fromLTWH(0, 0, 96, h), 6, const Color(0xFFFFFDF2), border: Pal.ink, borderWidth: 2.5);
    c.drawCircle(const Offset(48, 8), 5, D.fill(Pal.red));
    D.text(c, '#${_done + 1}', const Offset(48, 24), size: 16, color: Pal.ink);
    for (var i = 0; i < n; i++) {
      final kind = i == 0 ? 0 : _order[i - 1];
      final y = h - 18 - i * 26.0;
      final done = i == 0 || i - 1 < _next;
      final cur = i - 1 == _next;
      if (cur) {
        D.rrect(c, Rect.fromLTWH(4, y - 12, 88, 24), 6, Pal.yellow.withValues(alpha: .6 + .4 * M.wave(_t, 3)));
      }
      _drawIng(c, kind, Offset(40, y + (kind == 5 ? 4 : 0)), 0, .52);
      if (done) {
        c.drawPath(
            Path()
              ..moveTo(72, y)
              ..lineTo(78, y + 6)
              ..lineTo(88, y - 6),
            D.stroke(Pal.green, 3.5));
      } else if (cur) {
        D.arrow(c, Offset(82, y), const Offset(-1, 0), 18, Pal.red, width: 5);
      }
    }
    c.restore();
  }

  void _drawPlateStack(Canvas c) {
    // plate
    final px = _plateX;
    D.shadow(c, Offset(px, _plateY + 16), 140, 16, .3);
    c.drawOval(Rect.fromCenter(center: Offset(px, _plateY + 6), width: 136, height: 26), D.fill(const Color(0xFFE6ECF2)));
    c.drawOval(Rect.fromCenter(center: Offset(px, _plateY + 3), width: 110, height: 16), D.fill(Pal.white));
    c.drawOval(Rect.fromCenter(center: Offset(px, _plateY + 6), width: 136, height: 26), D.stroke(Pal.ink, 3));
    var y = _plateY - 6;
    for (var i = 0; i < _stack.length; i++) {
      final l = _stack[i];
      final h = _heights[l.kind];
      y -= h;
      final sq = l.squash;
      c.save();
      c.translate(_layerX(i), y + h / 2);
      c.rotate(_lean * .006 * i);
      c.scale(1 + sq * .15, 1 - sq * .25);
      _drawIng(c, l.kind, Offset.zero, 0, 1);
      c.restore();
    }
    // danger indicator when leaning a lot
    if (_com.abs() > 20 && !_toppled) {
      D.text(c, '!', Offset(_plateX + _com.sign * 70, _stackTopY), size: 34, color: Pal.red, stroke: Pal.ink);
    }
  }

  void _drawIng(Canvas c, int kind, Offset o, double rot, double s, {bool glow = false}) {
    c.save();
    c.translate(o.dx, o.dy);
    if (rot != 0) c.rotate(rot);
    if (s != 1) c.scale(s);
    if (glow) c.drawOval(Rect.fromCenter(center: Offset.zero, width: 120, height: 50), D.fill(const Color(0x55FFFFFF)));
    switch (kind) {
      case 0:
        D.rrect(c, const Rect.fromLTWH(-46, -9, 92, 18), 9, const Color(0xFFE8A350),
            gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF5C27A), Color(0xFFC77F35)]),
            border: Pal.ink, borderWidth: 2.5);
      case 1:
        D.rrect(c, const Rect.fromLTWH(-48, -8.5, 96, 17), 8, const Color(0xFF6B3A1E), border: Pal.ink, borderWidth: 2.5);
        for (var k = -2; k <= 2; k++) {
          c.drawLine(Offset(k * 16.0 - 4, -3), Offset(k * 16.0 + 4, 3), D.stroke(const Color(0xFF3E1F0E), 2.5));
        }
        c.drawRect(const Rect.fromLTWH(-40, -6, 80, 2), D.fill(const Color(0x33FFFFFF)));
      case 2:
        final p = Path()
          ..moveTo(-46, -3.5)
          ..lineTo(46, -3.5)
          ..lineTo(46, 3.5)
          ..lineTo(26, 3.5)
          ..lineTo(20, 12)
          ..lineTo(14, 3.5)
          ..lineTo(-16, 3.5)
          ..lineTo(-22, 11)
          ..lineTo(-28, 3.5)
          ..lineTo(-46, 3.5)
          ..close();
        c.drawPath(p, D.fill(Pal.yellow));
        c.drawPath(p, D.stroke(Pal.ink, 2.2));
      case 3:
        final p = Path()..moveTo(-50, 0);
        for (var k = 0; k <= 10; k++) {
          final x = -50 + k * 10.0;
          p.quadraticBezierTo(x + 5, k.isEven ? -9 : 9, x + 10, 0);
        }
        p
          ..lineTo(50, 4)
          ..lineTo(-50, 4)
          ..close();
        c.drawPath(p, D.fill(Pal.lime));
        c.drawPath(p, D.stroke(const Color(0xFF2E7D32), 2.2));
      case 4:
        for (final x in [-22.0, 22.0]) {
          c.drawOval(Rect.fromCenter(center: Offset(x, 0), width: 46, height: 11), D.fill(const Color(0xFFE8322C)));
          c.drawOval(Rect.fromCenter(center: Offset(x, 0), width: 30, height: 5), D.fill(const Color(0xFFFF8A80)));
          c.drawOval(Rect.fromCenter(center: Offset(x, 0), width: 46, height: 11), D.stroke(Pal.ink, 2));
        }
      case 5:
        final p = Path()
          ..moveTo(-47, 13)
          ..quadraticBezierTo(-50, -17, 0, -17)
          ..quadraticBezierTo(50, -17, 47, 13)
          ..close();
        c.drawPath(p, D.fill(const Color(0xFFE8A350)));
        c.drawOval(const Rect.fromLTWH(-34, -13, 34, 10), D.fill(const Color(0x55FFFFFF)));
        for (var k = 0; k < 7; k++) {
          final sx = -30 + k * 10.0;
          final sy = -8.0 + (k.isEven ? -3.0 : 3.0);
          c.drawOval(Rect.fromCenter(center: Offset(sx, sy), width: 5, height: 3), D.fill(const Color(0xFFFFF4DC)));
        }
        c.drawPath(p, D.stroke(Pal.ink, 2.5));
      case 6: // boot
        final p = Path()
          ..moveTo(-12, -24)
          ..lineTo(8, -24)
          ..lineTo(8, 4)
          ..lineTo(28, 8)
          ..quadraticBezierTo(34, 12, 30, 18)
          ..lineTo(-12, 18)
          ..close();
        c.drawPath(p, D.fill(const Color(0xFF7A5230)));
        c.drawRect(const Rect.fromLTWH(-12, 14, 44, 4), D.fill(Pal.ink));
        c.drawPath(p, D.stroke(Pal.ink, 2.5));
        c.drawLine(const Offset(-8, -16), const Offset(4, -16), D.stroke(Pal.white, 2));
        c.drawLine(const Offset(-8, -8), const Offset(4, -8), D.stroke(Pal.white, 2));
      default: // fish
        final body = Path()
          ..moveTo(-26, 0)
          ..quadraticBezierTo(0, -16, 22, 0)
          ..quadraticBezierTo(0, 16, -26, 0)
          ..close();
        c.drawPath(body, D.fill(Pal.sky));
        c.drawPath(
            Path()
              ..moveTo(20, 0)
              ..lineTo(34, -10)
              ..lineTo(34, 10)
              ..close(),
            D.fill(Pal.sky));
        c.drawPath(body, D.stroke(Pal.ink, 2.2));
        c.drawCircle(const Offset(-14, -3), 3, D.fill(Pal.ink));
    }
    c.restore();
  }

  void _drawHud(Canvas c) {
    D.rrect(c, const Rect.fromLTWH(240, 44, 112, 30), 15, const Color(0xDD1B1530), border: Pal.gold, borderWidth: 2);
    D.coin(c, const Offset(258, 59), 10, spin: _t * .4);
    D.text(c, M.big(_shown), const Offset(306, 59), size: 18, color: Pal.gold, stroke: Pal.ink);
    for (var i = 0; i < 3; i++) {
      final ok = i < 3 - _mess;
      D.heart(c, Offset(150 + i * 24.0, 59), 18, ok ? Pal.red : const Color(0x55000000), border: Pal.ink);
    }
    // order progress
    for (var i = 0; i < _goal; i++) {
      final x = 150 + i * 30.0;
      final done = i < _done;
      D.circle(c, Offset(x + 6, 90), 11, done ? Pal.lime : const Color(0x55FFFFFF), border: Pal.ink, borderWidth: 2);
      if (done) D.text(c, '✓', Offset(x + 6, 90), size: 14, color: Pal.ink);
    }
  }
}

class _Layer {
  _Layer(this.kind, this.off);
  final int kind;
  final double off;
  double squash = 0;
}

class _Fall {
  _Fall(this.kind, this.x, this.y);
  final int kind;
  double x, y;
  double vx = 0, vy = 0;
  double rot = 0, spin = 0;
  double extra = 0;
  double seed = 0;
  bool dead = false;
}

class _Splat {
  _Splat(this.pos, this.col);
  final Offset pos;
  final Color col;
  double t = 0;
}
