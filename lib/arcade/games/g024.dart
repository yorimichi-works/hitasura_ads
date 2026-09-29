import '../engine/engine.dart';

/// No.024 Raft Survival — hook floating debris, grow the raft to 9 tiles,
/// and spear the shark before it chews your floor away.
class G024 extends MiniGame {
  static const _ts = 40.0; // tile size
  static const _goal = 9;
  static const _origin = Offset(160, 390);

  final List<_Tile> _tiles = [];
  final List<_Debris> _debris = [];
  final List<_Debris> _hooked = [];
  double _t = 0;
  double _spawnT = 0;
  double _bob = 0;

  // hook
  int _hookState = 0; // 0 idle, 1 flying, 2 returning
  Offset _hookPos = Offset.zero;
  Offset _hookFrom = Offset.zero;
  Offset _hookTo = Offset.zero;
  double _hookK = 0;
  double _hookDur = 1;
  bool _aiming = false;
  Offset _aim = Offset.zero;
  int _throws = 0;

  // shark
  int _sharkState = 0; // 0 circle, 1 approach, 2 bite, 3 flee
  Offset _shark = const Offset(180, 600);
  double _sharkAng = 0;
  double _sharkHead = 0;
  double _sharkT = 4;
  _Tile? _sharkTarget;
  double _sharkHit = 0;
  double _spearT = 0;
  Offset _spearTo = Offset.zero;

  double _happy = 0;
  double _scared = 0;
  int _combo = 0;

  @override
  void init() {
    for (final g in const [(0, 0), (1, 0), (0, 1), (1, 1)]) {
      _tiles.add(_Tile(g.$1, g.$2)..pop = 1);
    }
    for (var i = 0; i < 7; i++) {
      _spawnDebris(y: rand(60, 560));
    }
    _sharkAng = rand(0, pi * 2);
  }

  Offset get _raftCenter {
    var s = Offset.zero;
    for (final t in _tiles) {
      s += _tilePos(t);
    }
    return s / _tiles.length.toDouble();
  }

  Offset _tilePos(_Tile t) => _origin + Offset(t.gx * _ts, t.gy * _ts + _bob);
  Offset get _hero => _tilePos(_tiles.first) + const Offset(0, -6);

  void _spawnDebris({double? y}) {
    final r = rng.nextDouble();
    final kind = r < .56 ? 0 : (r < .72 ? 1 : (r < .9 ? 2 : 3)); // plank, barrel, leaf, bottle
    var x = rand(24, 336);
    // keep new debris off the raft column a bit so it is hookable
    if ((x - 180).abs() < 50 && y != null) x += x < 180 ? -60 : 60;
    _debris.add(_Debris(kind, Offset(x, y ?? 30), rand(0, pi), rand(34, 50), rand(0, 6)));
  }

  @override
  void update(double dt) {
    _t += dt;
    _bob = sin(_t * 2.2) * 2;
    _happy = M.approach(_happy, 0, 2, dt);
    _scared = M.approach(_scared, _sharkState == 2 ? 1 : 0, 6, dt);
    _sharkHit = M.approach(_sharkHit, 0, 5, dt);
    _spearT = max(0, _spearT - dt);
    for (final t in _tiles) {
      t.pop = min(1, t.pop + dt * 2.5);
      t.shake = M.approach(t.shake, 0, 6, dt);
    }

    // debris drift with the current
    _spawnT -= dt;
    if (_spawnT <= 0) {
      _spawnT = rand(.45, .7);
      _spawnDebris();
    }
    for (final d in _debris) {
      if (d.hooked) continue;
      d.pos += Offset(sin(_t * .8 + d.phase) * 10, d.speed) * dt;
      d.rot += sin(d.phase + _t) * .2 * dt;
    }
    _debris.removeWhere((d) => !d.hooked && d.pos.dy > 680);

    _updateHook(dt);
    _updateShark(dt);
  }

  void _updateHook(double dt) {
    if (_hookState == 1) {
      _hookK += dt / _hookDur;
      final k = min(1.0, _hookK);
      _hookPos = Offset.lerp(_hookFrom, _hookTo, k)! + Offset(0, -sin(k * pi) * 60);
      if (k >= 1) {
        _hookState = 2;
        _hookPos = _hookTo;
        host.sfx(Sfx.splash, volume: .7);
        host.fx.burst(_hookPos, const Color(0xFFBFF4FF), count: 12, speed: 150, size: 5, gravity: 200);
        host.fx.ring(_hookPos, Pal.white, size: 36, life: .35);
        _grab(34);
        if (_hooked.isEmpty) {
          host.fx.pop(host.tr('miss', 'MISS'), _hookPos + const Offset(0, -24), color: Pal.white, size: 18);
          _combo = 0;
        }
      }
    } else if (_hookState == 2) {
      final home = _hero;
      final d = home - _hookPos;
      final dist = d.distance;
      final sp = 420.0 - _hooked.length * 40;
      if (dist < sp * dt + 6) {
        _hookState = 0;
        _collect();
      } else {
        _hookPos += d / dist * sp * dt;
        _grab(22);
      }
      for (var i = 0; i < _hooked.length; i++) {
        final h = _hooked[i];
        h.pos = M.approachO(h.pos, _hookPos + Offset((i - (_hooked.length - 1) / 2) * 14, 10.0 + i * 3), 18, dt);
      }
    }
  }

  void _grab(double radius) {
    for (final d in _debris) {
      if (d.hooked || _hooked.length >= 4) continue;
      if ((d.pos - _hookPos).distance < radius) {
        d.hooked = true;
        _hooked.add(d);
        host.sfx(Sfx.pickup, rate: 1 + _hooked.length * .1, volume: .7);
        host.fx.sparkle(d.pos, count: 5, radius: 14);
      }
    }
  }

  void _collect() {
    if (_hooked.isEmpty) return;
    var tiles = 0;
    for (final d in _hooked) {
      _debris.remove(d);
      switch (d.kind) {
        case 0:
          tiles += 1;
        case 1:
          tiles += 2;
          host.sfx(Sfx.crack, volume: .7);
          host.fx.burst(_hero, Pal.brown, count: 14, speed: 220, size: 7, shape: PartShape.square);
        case 2:
          host.addScore(40, _hero + const Offset(20, -40));
        default:
          host.addScore(150, _hero + const Offset(-10, -50));
          host.sfx(Sfx.gem);
          host.fx.pop(host.tr('bonus', 'BONUS!'), _hero + const Offset(0, -80), color: Pal.sky, size: 24);
      }
    }
    _combo += _hooked.length;
    if (_combo >= 3) {
      host.fx.pop('${host.tr('combo', 'COMBO')} $_combo', _hero + const Offset(-40, -90), color: Pal.pink, size: 20);
    }
    if (_hooked.length >= 2) {
      host.fx.pop('x${_hooked.length}', _hero + const Offset(30, -60), color: Pal.yellow, size: 28);
      host.sfx(Sfx.combo, rate: 1 + _hooked.length * .12);
    }
    _hooked.clear();
    _happy = 1;
    for (var i = 0; i < tiles; i++) {
      _addTile(i * .12);
    }
    if (tiles > 0) host.addScore(100 * tiles, _hero + const Offset(0, -40));
  }

  void _addTile(double delay) {
    if (_tiles.length >= _goal + 3) return;
    final taken = {for (final t in _tiles) t.gx * 100 + t.gy};
    (int, int)? best;
    var bd = 1e9;
    for (final t in _tiles) {
      for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final gx = t.gx + d.$1, gy = t.gy + d.$2;
        if (gx < -2 || gx > 3 || gy < -2 || gy > 3 || taken.contains(gx * 100 + gy)) continue;
        final score = (gx - .5).abs() + (gy - .5).abs() + rand(0, .6);
        if (score < bd) {
          bd = score;
          best = (gx, gy);
        }
      }
    }
    if (best == null) return;
    final tile = _Tile(best.$1, best.$2)..pop = -delay * 2.5;
    _tiles.add(tile);
    final p = _tilePos(tile);
    host.sfx(Sfx.hammer, rate: 1 + _tiles.length * .05);
    host.fx.burst(p, const Color(0xFFD9A066), count: 10, speed: 160, size: 5, shape: PartShape.square);
    host.fx.sparkle(p, count: 6, radius: 20, color: Pal.yellow);
    host.punch(.02);
    if (_tiles.length >= _goal && !host.finished) {
      host.fx.confetti();
      host.fx.pop(host.tr('clear', 'CLEAR!'), const Offset(180, 250), size: 40);
      host.sfx(Sfx.fanfare);
      host.win(stars: host.time < 13 ? 3 : (host.time < 18 ? 2 : 1));
    }
  }

  void _updateShark(double dt) {
    final center = _raftCenter;
    final sp = host.speed;
    switch (_sharkState) {
      case 0:
        _sharkAng += dt * .9 * sp;
        final target = center + Offset(cos(_sharkAng) * 125, sin(_sharkAng) * 150);
        _moveShark(target, 160 * sp, dt);
        _sharkT -= dt * sp;
        if (_sharkT <= 0 && !host.finished) {
          final edge = _tiles.skip(1).toList();
          if (edge.isNotEmpty) {
            edge.sort((a, b) => (_tilePos(b) - center).distance.compareTo((_tilePos(a) - center).distance));
            _sharkTarget = edge.first;
            _sharkState = 1;
            host.sfx(Sfx.heartbeat, volume: .8);
          } else {
            _sharkT = 2;
          }
        }
      case 1:
        final tt = _sharkTarget!;
        if (!_tiles.contains(tt)) {
          _sharkState = 0;
          _sharkT = 2;
          break;
        }
        final tp = _tilePos(tt);
        final out = (tp - center);
        final goal = tp + out / max(out.distance, 1) * 30;
        if (_moveShark(goal, 120 * sp, dt)) {
          _sharkState = 2;
          _sharkT = 1.7 / sp;
          host.sfx(Sfx.chomp);
        }
      case 2:
        final tt = _sharkTarget!;
        tt.shake = 1;
        _sharkT -= dt;
        if ((_t * 6).floor() != ((_t - dt) * 6).floor()) {
          host.sfx(Sfx.chomp, volume: .6, rate: rand(.9, 1.2));
          host.fx.burst(_tilePos(tt), const Color(0xFF8A5A33), count: 3, speed: 120, size: 5, shape: PartShape.square);
        }
        if (_sharkT <= 0) {
          _tiles.remove(tt);
          host.sfx(Sfx.crash);
          host.shake(8);
          host.flash(const Color(0x55FF2040));
          host.fx.burst(_tilePos(tt), Pal.brown, count: 20, speed: 260, size: 7, shape: PartShape.square);
          host.fx.pop(host.tr('oops', 'OOPS'), _tilePos(tt) + const Offset(0, -30), color: Pal.red);
          _sharkState = 0;
          _sharkT = rand(2.5, 4);
        }
      case 3:
        final away = _shark - center;
        _moveShark(_shark + away / max(away.distance, 1) * 100, 330, dt);
        _sharkT -= dt;
        if (_sharkT <= 0) {
          _sharkState = 0;
          _sharkAng = atan2(_shark.dy - center.dy, _shark.dx - center.dx);
          _sharkT = rand(2.5, 4) / sp;
        }
    }
  }

  bool _moveShark(Offset target, double speed, double dt) {
    final d = target - _shark;
    final dist = d.distance;
    if (dist > 1) {
      final want = atan2(d.dy, d.dx);
      var diff = want - _sharkHead;
      while (diff > pi) {
        diff -= pi * 2;
      }
      while (diff < -pi) {
        diff += pi * 2;
      }
      _sharkHead += diff * min(1, dt * 8);
    }
    if (dist < speed * dt + 2) {
      _shark = target;
      return true;
    }
    _shark += d / dist * speed * dt;
    return false;
  }

  bool _hitShark(Offset p) {
    if (_sharkState == 3) return false;
    if ((p - _shark).distance > 46) return false;
    _sharkState = 3;
    _sharkT = 2.8;
    _sharkHit = 1;
    _spearT = .25;
    _spearTo = _shark;
    host.sfx(Sfx.throwIt);
    host.sfx(Sfx.hitHeavy);
    host.hitStop(.06);
    host.shake(6);
    host.fx.burst(_shark, Pal.white, count: 16, speed: 240, size: 6, gravity: 150);
    host.fx.ring(_shark, Pal.yellow, size: 60);
    host.fx.pop(host.tr('strike', 'STRIKE!'), _shark + const Offset(0, -40), color: Pal.yellow, size: 28);
    host.addScore(200, _shark);
    return true;
  }

  @override
  void onDown(Offset p) {
    if (_hitShark(p)) return;
    if (_hookState != 0) return;
    _aiming = true;
    _aim = p;
  }

  @override
  void onMove(Offset p) {
    if (_aiming) _aim = p;
  }

  @override
  void onUp(Offset p) {
    if (!_aiming) return;
    _aiming = false;
    if (_hookState != 0) return;
    final to = Offset(p.dx.clamp(14, 346), p.dy.clamp(60, 630));
    if ((to - _hero).distance < 36) return;
    _hookState = 1;
    _hookFrom = _hero;
    _hookTo = to;
    _hookK = 0;
    _hookDur = .18 + (to - _hero).distance / 700;
    _hookPos = _hero;
    _throws++;
    host.sfx(Sfx.throwIt, rate: 1.1);
  }

  @override
  void onTimeUp() {
    if (_tiles.length >= 7) {
      host.win(stars: 1);
    } else {
      host.sfx(Sfx.aww);
      host.lose();
    }
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF3FD4E0), Color(0xFF1886C4), Color(0xFF0C4E93)]);
    // light caustics
    final cp = D.stroke(const Color(0x22FFFFFF), 2.5);
    for (var row = 0; row < 16; row++) {
      final y = 50.0 + row * 38 + (_t * 14) % 38;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= 360; x += 30) {
        path.lineTo(x, y + sin(x * .05 + _t * 1.6 + row) * 6);
      }
      c.drawPath(path, cp);
    }
    final sp = Paint()..color = const Color(0x55FFFFFF);
    for (var i = 0; i < 24; i++) {
      final x = (i * 71.0 + sin(_t + i) * 8) % 360;
      final y = (i * 113.0 + _t * 40) % 640;
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 10, height: 3), sp);
    }

    // shark shadow (under everything)
    _drawShark(c, under: true);

    // debris
    for (final d in _debris) {
      if (!d.hooked) _drawDebris(c, d);
    }

    // raft shadow + foam
    final foam = Paint()..color = Color.fromRGBO(255, 255, 255, .35 + .1 * sin(_t * 3));
    for (final t in _tiles) {
      final p = _tilePos(t);
      final s = _ts * M.clamp01(t.pop);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: s + 12, height: s + 12), const Radius.circular(10)), foam);
    }
    for (final t in _tiles) {
      final p = _tilePos(t);
      c.drawRect(Rect.fromCenter(center: p + const Offset(4, 7), width: _ts * M.clamp01(t.pop), height: _ts * M.clamp01(t.pop)),
          Paint()..color = const Color(0x44001030));
    }
    for (final t in _tiles) {
      _drawTile(c, t);
    }

    // shark on top when biting
    _drawShark(c, under: false);

    // aim guide
    if (_aiming && _hookState == 0) {
      final to = _aim;
      final dots = Paint()..color = const Color(0xCCFFFFFF);
      for (var k = 0.0; k <= 1; k += .07) {
        final p = Offset.lerp(_hero, to, k)! + Offset(0, -sin(k * pi) * 60);
        c.drawCircle(p, 3.2, dots);
      }
      c.drawCircle(to, 30, D.stroke(const Color(0xAAFFFFFF), 3));
      c.drawCircle(to, 30 * (.5 + .5 * M.wave(_t, 2)), D.stroke(const Color(0x66FFFFFF), 2));
    }

    // rope + hook
    if (_hookState != 0) {
      final mid = (_hero + _hookPos) / 2 + const Offset(0, 18);
      c.drawPath(
          Path()
            ..moveTo(_hero.dx, _hero.dy - 14)
            ..quadraticBezierTo(mid.dx, mid.dy, _hookPos.dx, _hookPos.dy),
          D.stroke(const Color(0xFFF1D9A7), 2.5));
      for (final d in _hooked) {
        _drawDebris(c, d);
      }
      _drawHook(c, _hookPos);
    }

    // survivor
    _drawHero(c);

    // spear
    if (_spearT > 0) {
      final k = _spearT / .25;
      final from = _hero + const Offset(0, -20);
      final tip = Offset.lerp(from, _spearTo, 1 - k * .3)!;
      D.line(c, from, tip, const Color(0xFF8A5A33), 4);
      c.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..addOval(Rect.fromCircle(center: tip, radius: 4)),
          D.fill(Pal.gray));
    }

    // HUD
    D.rrect(c, const Rect.fromLTWH(100, 46, 160, 40), 20, const Color(0xCC0B2E55), border: Pal.ink, borderWidth: 3);
    _drawPlankIcon(c, const Offset(128, 66));
    final n = min(_tiles.length, _goal);
    D.text(c, '$n / $_goal', const Offset(196, 66), size: 24, color: n >= 7 ? Pal.yellow : Pal.white, stroke: Pal.ink);
    for (var i = 0; i < _goal; i++) {
      final on = i < _tiles.length;
      D.rrect(c, Rect.fromLTWH(104 + i * 17.0, 90, 13, 8), 3, on ? Pal.gold : const Color(0x66000000));
    }

    if (_throws == 0 && host.time < 4) {
      Offset? target;
      for (final d in _debris) {
        if (d.kind == 0 && d.pos.dy > 120 && d.pos.dy < 300) target = d.pos;
      }
      target ??= const Offset(270, 220);
      final k = (_t * .9) % 1;
      D.hand(c, Offset.lerp(_hero, target, M.easeInOut(M.clamp01(k * 1.4)))!, 0);
      D.text(c, host.tr('drag', 'DRAG!'), const Offset(180, 560), size: 26, color: Pal.yellow, stroke: Pal.ink);
    }
    if (_sharkState == 1 || _sharkState == 2) {
      D.text(c, host.tr('tap', 'TAP!'), _shark + Offset(0, -44 - 4 * sin(_t * 12)), size: 22, color: Pal.red, stroke: Pal.white);
    }
  }

  void _drawPlankIcon(Canvas c, Offset o) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(-.3);
    D.rrect(c, const Rect.fromLTWH(-15, -6, 30, 12), 3, const Color(0xFFC98B4F), border: Pal.ink, borderWidth: 2);
    D.line(c, const Offset(-10, 0), const Offset(10, 0), const Color(0xFF8A5A33), 1.5);
    c.restore();
  }

  void _drawTile(Canvas c, _Tile t) {
    if (t.pop <= 0) return;
    final p = _tilePos(t) + Offset(sin(_t * 40) * 3 * t.shake, 0);
    final s = M.easeOutBack(M.clamp01(t.pop));
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(s);
    const r = Rect.fromLTWH(-_ts / 2, -_ts / 2, _ts, _ts);
    final vertical = (t.gx + t.gy).isEven;
    for (var i = 0; i < 3; i++) {
      final w = _ts / 3;
      final pr = vertical
          ? Rect.fromLTWH(r.left + i * w, r.top, w, _ts)
          : Rect.fromLTWH(r.left, r.top + i * w, _ts, w);
      final col = [const Color(0xFFD9A066), const Color(0xFFC98B4F), const Color(0xFFE2B077)][(i + t.gx + t.gy * 2) % 3];
      D.rrect(c, pr.deflate(.8), 3, t.shake > .1 ? Color.lerp(col, Pal.red, t.shake * .5)! : col,
          border: const Color(0xFF5A3418), borderWidth: 1.6);
      // grain
      final g = D.stroke(const Color(0x338A5A33), 1.2);
      if (vertical) {
        c.drawLine(Offset(pr.center.dx - 2, pr.top + 6), Offset(pr.center.dx - 2, pr.top + 18), g);
      } else {
        c.drawLine(Offset(pr.left + 8, pr.center.dy + 1), Offset(pr.left + 22, pr.center.dy + 1), g);
      }
    }
    // rope ties
    for (final o in const [Offset(-15, -15), Offset(15, 15)]) {
      c.drawCircle(o, 3, D.fill(const Color(0xFFF1D9A7)));
    }
    c.restore();
  }

  void _drawDebris(Canvas c, _Debris d) {
    c.save();
    c.translate(d.pos.dx, d.pos.dy + sin(_t * 3 + d.phase) * 1.5);
    c.rotate(d.rot);
    c.drawOval(const Rect.fromLTWH(-20, -8, 40, 22), Paint()..color = const Color(0x33FFFFFF));
    switch (d.kind) {
      case 0:
        D.rrect(c, const Rect.fromLTWH(-19, -6, 38, 12), 3, const Color(0xFFC98B4F), border: Pal.ink, borderWidth: 2);
        D.line(c, const Offset(-13, 0), const Offset(8, 0), const Color(0xFF8A5A33), 1.5);
        c.drawCircle(const Offset(13, 0), 1.6, D.fill(Pal.ink));
      case 1:
        D.circle(c, Offset.zero, 13, const Color(0xFFB0662F), border: Pal.ink, borderWidth: 2.5);
        c.drawCircle(Offset.zero, 9, D.stroke(const Color(0xFF6D6D7A), 3));
        c.drawCircle(Offset.zero, 4, D.fill(const Color(0xFF7A4422)));
      case 2:
        final leaf = Path()
          ..moveTo(-16, 0)
          ..quadraticBezierTo(0, -12, 16, 0)
          ..quadraticBezierTo(0, 12, -16, 0)
          ..close();
        c.drawPath(leaf, D.fill(const Color(0xFF4CC75E)));
        c.drawPath(leaf, D.stroke(Pal.ink, 2));
        D.line(c, const Offset(-14, 0), const Offset(14, 0), const Color(0xFF2B8C3A), 1.5);
      default:
        D.rrect(c, const Rect.fromLTWH(-12, -6, 20, 12), 5, const Color(0xCC8FE3B0), border: Pal.ink, borderWidth: 2);
        D.rrect(c, const Rect.fromLTWH(7, -3, 7, 6), 2, const Color(0xFF8A5A33), border: Pal.ink, borderWidth: 1.5);
        D.rrect(c, const Rect.fromLTWH(-8, -3, 11, 6), 1, Pal.cream);
    }
    c.restore();
  }

  void _drawHook(Canvas c, Offset p) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(_t * (_hookState == 1 ? 14 : 0));
    final hp = D.stroke(Pal.ink, 5.5);
    final hc = D.stroke(const Color(0xFFCFD6E6), 3);
    for (var i = 0; i < 3; i++) {
      final a = i * pi * 2 / 3;
      final e = Offset(cos(a) * 11, sin(a) * 11);
      final tip = Offset(cos(a + .8) * 9, sin(a + .8) * 9);
      c.drawLine(Offset.zero, e, hp);
      c.drawLine(e, tip, hp);
      c.drawLine(Offset.zero, e, hc);
      c.drawLine(e, tip, hc);
    }
    D.circle(c, Offset.zero, 4, const Color(0xFFCFD6E6), border: Pal.ink, borderWidth: 2);
    c.restore();
  }

  void _drawHero(Canvas c) {
    final p = _hero + const Offset(0, 12);
    final face = _scared > .3 ? Face.shocked : (_happy > .3 ? Face.happy : (_sharkState == 1 ? Face.sad : Face.neutral));
    D.shadow(c, p + const Offset(0, 1), 22, 8, .3);
    final aimDir = _aiming ? (_aim.dx < p.dx) : (_hookState != 0 && _hookPos.dx < p.dx);
    D.person(c, p, 36, const Color(0xFFFF7A3D),
        face: face, hair: const Color(0xFF6B4226), flip: aimDir, armsUp: _happy > .5 || _scared > .5 ? 1 : 0,
        pants: const Color(0xFF3657A8));
    // straw hat
    c.drawOval(Rect.fromCenter(center: p + const Offset(0, -35), width: 26, height: 7), D.fill(const Color(0xFFEBC56A)));
    c.drawOval(Rect.fromCenter(center: p + const Offset(0, -38), width: 14, height: 8), D.fill(const Color(0xFFEBC56A)));
    c.drawOval(Rect.fromCenter(center: p + const Offset(0, -35), width: 26, height: 7), D.stroke(Pal.ink, 1.5));
  }

  void _drawShark(Canvas c, {required bool under}) {
    final biting = _sharkState == 2;
    if (under == biting) return;
    c.save();
    c.translate(_shark.dx, _shark.dy);
    c.rotate(_sharkHead);
    final wig = sin(_t * 10) * .25;
    if (under) {
      // submerged silhouette
      final body = Paint()..color = const Color(0x552A3A55);
      c.drawOval(const Rect.fromLTWH(-34, -12, 64, 24), body);
      c.save();
      c.translate(-30, 0);
      c.rotate(wig);
      c.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(-20, -14)
            ..lineTo(-14, 0)
            ..lineTo(-20, 14)
            ..close(),
          body);
      c.restore();
      c.drawPath(
          Path()
            ..moveTo(-6, -10)
            ..lineTo(8, -26)
            ..lineTo(10, -10)
            ..close(),
          body);
      c.restore();
      // fin above water (drawn upright)
      final fp = _shark;
      final wake = Paint()..color = Color.fromRGBO(255, 255, 255, .5 + .2 * sin(_t * 8));
      c.drawOval(Rect.fromCenter(center: fp + const Offset(0, 4), width: 34, height: 9), wake);
      final fin = Path()
        ..moveTo(fp.dx - 12, fp.dy + 3)
        ..quadraticBezierTo(fp.dx - 2, fp.dy - 14, fp.dx + 6, fp.dy - 24)
        ..quadraticBezierTo(fp.dx + 6, fp.dy - 6, fp.dx + 12, fp.dy + 3)
        ..close();
      c.drawPath(fin, D.fill(_sharkHit > .1 ? Pal.white : const Color(0xFF5C6F8C)));
      c.drawPath(fin, D.stroke(Pal.ink, 2.5));
      return;
    }
    // biting: head out of the water facing the raft
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-40, -18, 70, 36), const Radius.circular(18));
    c.drawRRect(body, D.fill(const Color(0xFF6E83A3)));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-30, 2, 58, 14), const Radius.circular(8)), D.fill(const Color(0xFFE8EEF6)));
    c.drawRRect(body, D.stroke(Pal.ink, 3));
    final chomp = (sin(_t * 18) * .5 + .5) * 8;
    c.drawPath(
        Path()
          ..moveTo(18, -8 - chomp)
          ..lineTo(34, 0)
          ..lineTo(18, 8 + chomp)
          ..close(),
        D.fill(const Color(0xFF8B1E3F)));
    for (var i = 0; i < 3; i++) {
      c.drawPath(
          Path()
            ..moveTo(20.0 + i * 4, -6 - chomp * .9)
            ..lineTo(22.0 + i * 4, -1)
            ..lineTo(24.0 + i * 4, -6 - chomp * .9)
            ..close(),
          D.fill(Pal.white));
    }
    c.drawCircle(const Offset(12, -9), 3.5, D.fill(Pal.ink));
    c.drawCircle(const Offset(11, -10), 1.2, D.fill(Pal.white));
    c.restore();
  }
}

class _Tile {
  _Tile(this.gx, this.gy);
  final int gx, gy;
  double pop = 0;
  double shake = 0;
}

class _Debris {
  _Debris(this.kind, this.pos, this.rot, this.speed, this.phase);
  final int kind;
  Offset pos;
  double rot;
  final double speed;
  final double phase;
  bool hooked = false;
}
