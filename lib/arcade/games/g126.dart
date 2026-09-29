import '../engine/engine.dart';

/// No.126 Slime Merge Tamer — drag a slime onto an identical one (same color,
/// same level) to merge it into a bigger one. Rainbow slimes merge with
/// anything. Level 5 = KING SLIME (crown!) = win.
class G126 extends MiniGame {
  double _t = 0;
  final List<_Slime> _sl = [];
  _Slime? _drag;
  Offset _dragOff = Offset.zero;
  Offset _dragPrev = Offset.zero;
  Offset _dragVel = Offset.zero;
  double _spawnT = 1.2;
  int _best = 3;
  int _chain = 0;
  double _rainbowAt = 5.5;
  _Slime? _king;
  double _kingT = 0;
  final List<_Merge> _merging = [];
  _Slime? _hintA, _hintB;

  static const _fieldTop = 170.0, _fieldBot = 610.0;
  static const _cols = [Color(0xFF7BE05A), Color(0xFF4FB4FF), Color(0xFFFF7EC8), Color(0xFFFFFFFF)];

  double _rad(int lv) => const [18.0, 18.0, 23.0, 29.0, 36.0, 46.0][lv];

  @override
  void init() {
    void add(int col, int lv, double x, double y) => _sl.add(_Slime(Offset(x, y), col, lv)..hopT = rand(.2, 1.5));
    add(0, 3, 90, 300);
    add(0, 3, 270, 520);
    add(0, 2, 250, 300);
    add(1, 2, 90, 470);
    add(1, 1, 180, 560);
    add(2, 1, 300, 400);
    add(2, 2, 60, 580);
    add(0, 1, 140, 400);
    add(0, 1, 225, 410);
    _hintA = _sl[7];
    _hintB = _sl[8];
  }

  // ---------------------------------------------------------------- update
  @override
  void update(double dt) {
    _t += dt;
    if (_king != null) {
      _kingT += dt;
    }
    // spawning from the sky
    if (!host.finished) {
      _spawnT -= dt * host.speed.clamp(1.0, 1.3);
      if (_spawnT <= 0 && _sl.length < 15) {
        _spawnT = .85;
        final bestCol = _bestColor();
        final col = chance(.62) ? bestCol : randInt(3);
        final lv = chance(.4) ? 2 : 1;
        final s = _Slime(Offset(rand(40, 320), rand(_fieldTop + 30, _fieldBot - 30)), col, lv)
          ..z = 420
          ..vz = 0
          ..falling = true;
        _sl.add(s);
        host.sfx(Sfx.whoosh, volume: .3, rate: 1.4);
      }
      if (host.time > _rainbowAt) {
        _rainbowAt += 6.5;
        _sl.add(_Slime(Offset(rand(60, 300), rand(_fieldTop + 60, _fieldBot - 60)), 3, 1)
          ..z = 460
          ..falling = true);
        host.sfx(Sfx.sparkle);
      }
    }

    for (final s in _sl) {
      s.squash = M.approach(s.squash, 0, 10, dt);
      s.pop = max(0, s.pop - dt * 2.5);
      s.angry = max(0, s.angry - dt);
      if (s == _drag) continue;
      if (s.falling) {
        s.vz -= 1400 * dt;
        s.z += s.vz * dt;
        if (s.z <= 0) {
          s.z = 0;
          s.vz = 0;
          s.falling = false;
          s.squash = 1;
          host.sfx(Sfx.squish, volume: .5, rate: 1.3 - s.level * .08);
        }
        continue;
      }
      // idle hopping
      s.hopT -= dt;
      if (s.hopping) {
        s.hopP += dt / .45;
        s.pos = Offset.lerp(s.hopFrom, s.hopTo, M.clamp01(s.hopP))!;
        s.z = sin(M.clamp01(s.hopP) * pi) * (22 - s.level * 2);
        if (s.hopP >= 1) {
          s.hopping = false;
          s.z = 0;
          s.squash = .7;
          s.hopT = rand(.8, 2.2);
        }
      } else if (s.hopT <= 0 && _king == null) {
        s.hopping = true;
        s.hopP = 0;
        s.hopFrom = s.pos;
        final a = rand(0, pi * 2);
        final to = s.pos + Offset(cos(a), sin(a)) * rand(18, 40);
        s.hopTo = Offset(to.dx.clamp(30, 330), to.dy.clamp(_fieldTop + 10, _fieldBot - 10));
        s.squash = -.4;
      }
    }
    // soft separation
    for (var i = 0; i < _sl.length; i++) {
      final a = _sl[i];
      if (a == _drag || a.falling) continue;
      for (var j = i + 1; j < _sl.length; j++) {
        final b = _sl[j];
        if (b == _drag || b.falling) continue;
        final d = b.pos - a.pos;
        final rr = (_rad(a.level) + _rad(b.level)) * .85;
        final l = d.distance;
        if (l < rr && l > .01) {
          final push = d / l * (rr - l) * .5 * min(1, dt * 10);
          a.pos -= push;
          b.pos += push;
          if (a.hopping) a.hopTo -= push;
          if (b.hopping) b.hopTo += push;
        }
      }
      a.pos = Offset(a.pos.dx.clamp(24, 336), a.pos.dy.clamp(_fieldTop, _fieldBot));
    }
    // merge animations
    for (final m in _merging) {
      m.t += dt / .22;
      if (m.t >= 1 && !m.done) {
        m.done = true;
        _finishMerge(m);
      }
    }
    _merging.removeWhere((m) => m.done);
  }

  int _bestColor() {
    var best = 0, bl = 0;
    for (final s in _sl) {
      if (s.col < 3 && s.level > bl) {
        bl = s.level;
        best = s.col;
      }
    }
    return best;
  }

  bool _canMerge(_Slime a, _Slime b) {
    if (a.level >= 5 || b.level >= 5) return false;
    if (a.col == 3 && b.col == 3) return false;
    if (a.col == 3 || b.col == 3) return true;
    return a.col == b.col && a.level == b.level;
  }

  void _startMerge(_Slime a, _Slime into) {
    final col = into.col == 3 ? a.col : into.col;
    final lv = (into.col == 3 ? a.level : into.level) + 1;
    a.merging = true;
    into.merging = true;
    _merging.add(_Merge(a, into, col, lv));
    host.sfx(Sfx.bubble, rate: 1.2);
  }

  void _finishMerge(_Merge m) {
    _sl
      ..remove(m.a)
      ..remove(m.b);
    final s = _Slime(m.b.pos, m.col, m.lv)
      ..pop = 1
      ..squash = 1
      ..hopT = 1.5;
    _sl.add(s);
    _chain++;
    final c = _cols[m.col];
    host.sfx(Sfx.pop, rate: 1 + m.lv * .1);
    host.sfx(Sfx.magic, volume: .6, rate: .9 + m.lv * .12);
    host.fx.burst(s.pos, c, count: 12 + m.lv * 4, speed: 200 + m.lv * 40, size: 7);
    host.fx.burst(s.pos, Pal.white, count: 6 + m.lv * 2, speed: 260, shape: PartShape.star, gravity: 200);
    host.fx.ring(s.pos, c, size: 50 + m.lv * 20);
    host.shake(2.0 + m.lv);
    host.punch(.02 + m.lv * .01);
    host.addScore(10 * (1 << m.lv), s.pos + Offset(0, -_rad(m.lv) - 20));
    if (m.lv > _best) {
      _best = m.lv;
      host.sfx(Sfx.rarityUp, volume: .7);
    }
    if (_chain >= 2) {
      host.fx.pop('${host.tr('combo', 'COMBO')} x$_chain', s.pos + const Offset(0, -70), color: Pal.pink, size: 22);
      host.sfx(Sfx.combo, rate: 1 + _chain * .1);
    } else {
      host.fx.pop('${host.tr('level', 'Lv')}${m.lv}!', s.pos + Offset(0, -_rad(m.lv) - 34), color: Pal.yellow, size: 20 + m.lv * 2.0);
    }
    if (m.lv >= 5) {
      _king = s;
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.cheer, volume: .7);
      host.flash(Pal.white, .3);
      host.fx.confetti();
      host.fx.coins(s.pos, count: 24);
      host.fx.pop(host.tr('king', 'KING!'), const Offset(180, 230), color: Pal.gold, size: 46, life: 1.5);
      host.hitStop(.12);
      host.win(stars: host.time < 13 ? 3 : (host.time < 17 ? 2 : 1));
      return;
    }
    // chain: landed on another identical slime -> auto merge
    for (final o in _sl) {
      if (o == s || o.merging || o.falling) continue;
      if (o.col == s.col && o.level == s.level && (o.pos - s.pos).distance < _rad(s.level) * 1.6) {
        _startMerge(o, s);
        return;
      }
    }
  }

  // ----------------------------------------------------------------- input
  @override
  void onDown(Offset p) {
    if (_king != null) return;
    _Slime? best;
    var bd = 1e9;
    for (final s in _sl) {
      if (s.merging || s.falling) continue;
      final d = (s.pos - Offset(0, s.z + _rad(s.level) * .6) - p).distance;
      if (d < _rad(s.level) + 16 && d < bd) {
        bd = d;
        best = s;
      }
    }
    if (best == null) return;
    _drag = best;
    _dragOff = best.pos - p;
    _dragPrev = p;
    _dragVel = Offset.zero;
    best.hopping = false;
    best.z = 14;
    best.squash = -.5;
    _chain = 0;
    _hintA = null;
    host.sfx(Sfx.squish, volume: .6, rate: 1.4);
  }

  @override
  void onMove(Offset p) {
    final d = _drag;
    if (d == null) return;
    _dragVel = (p - _dragPrev);
    _dragPrev = p;
    d.pos = Offset((p + _dragOff).dx.clamp(20, 340), (p + _dragOff).dy.clamp(_fieldTop - 20, _fieldBot + 10));
  }

  @override
  void onUp(Offset p) {
    final d = _drag;
    if (d == null) return;
    _drag = null;
    d.z = 0;
    d.squash = .8;
    // find best overlapping target
    _Slime? target;
    var bd = 1e9;
    for (final s in _sl) {
      if (s == d || s.merging || s.falling) continue;
      final dist = (s.pos - d.pos).distance;
      if (dist < _rad(s.level) + _rad(d.level) * .8 && dist < bd) {
        bd = dist;
        target = s;
      }
    }
    if (target == null) {
      host.sfx(Sfx.squish, volume: .4);
      return;
    }
    if (_canMerge(d, target)) {
      _startMerge(d, target);
    } else {
      // rejection: bonk away
      final away = d.pos - target.pos;
      final dir = away.distance > .1 ? away / away.distance : const Offset(1, 0);
      d.hopping = true;
      d.hopP = 0;
      d.hopFrom = d.pos;
      final to = d.pos + dir * 60;
      d.hopTo = Offset(to.dx.clamp(30, 330), to.dy.clamp(_fieldTop, _fieldBot));
      d.angry = 1;
      target.angry = 1;
      target.squash = 1;
      host.sfx(Sfx.boing);
      host.fx.burst((d.pos + target.pos) / 2, Pal.white, count: 6, speed: 160, shape: PartShape.star, gravity: 0, life: .3);
      host.fx.pop(host.tr('oops', 'OOPS'), target.pos + const Offset(0, -50), color: Pal.red, size: 18, life: .5);
    }
  }

  // ---------------------------------------------------------------- render
  @override
  void render(Canvas c) {
    _renderBg(c);
    // sort by y for depth
    final list = [..._sl]..sort((a, b) => a.pos.dy.compareTo(b.pos.dy));
    for (final s in list) {
      final r = _rad(s.level);
      D.shadow(c, s.pos + Offset(0, r * .7), r * 2 * (1 - M.clamp01(s.z / 500) * .6), r * .55, .22);
    }
    if (_king != null) {
      D.rays(c, _king!.pos + const Offset(0, -30), 460, const Color(0x33FFE070), count: 16, t: _t * .8);
    }
    for (final s in list) {
      if (s == _drag) continue;
      var pos = s.pos;
      var scale = 1.0;
      for (final m in _merging) {
        if (m.a == s || m.b == s) {
          final o = m.a == s ? m.b : m.a;
          pos = Offset.lerp(s.pos, (s.pos + o.pos) / 2, M.easeInOut(M.clamp01(m.t)))!;
          scale = 1 - m.t * .3;
        }
      }
      _drawSlime(c, s, pos, scale);
    }
    final d = _drag;
    if (d != null) {
      // valid-target glow
      for (final s in _sl) {
        if (s != d && !s.merging && !s.falling && _canMerge(d, s)) {
          c.drawCircle(s.pos - Offset(0, _rad(s.level) * .6), _rad(s.level) + 8 + sin(_t * 10) * 3,
              D.stroke(Color.fromRGBO(255, 240, 120, .8), 4));
        }
      }
      _drawSlime(c, d, d.pos, 1.08, stretch: _dragVel);
    }
    _renderHud(c);
    // hint: drag one green slime onto the other
    final ha = _hintA, hb = _hintB;
    if (ha != null && hb != null && host.time < 3.5 && _sl.contains(ha) && _sl.contains(hb)) {
      final k = (_t * .8) % 1.0;
      final from = ha.pos - const Offset(0, 10), to = hb.pos - const Offset(0, 10);
      D.arrow(c, Offset.lerp(from, to, .5)! + const Offset(0, -30), to - from, (to - from).distance * .6, const Color(0xCCFFFFFF), width: 8);
      D.hand(c, Offset.lerp(from, to, M.easeInOut(k))!, _t);
    }
  }

  void _renderBg(Canvas c) {
    D.gradientBg(c, const [Color(0xFF8FD8FF), Color(0xFFD9F4FF)], rect: const Rect.fromLTWH(0, 0, 360, 170));
    // hills
    c.drawOval(const Rect.fromLTWH(-80, 110, 300, 120), D.fill(const Color(0xFF9EDB6B)));
    c.drawOval(const Rect.fromLTWH(150, 100, 320, 130), D.fill(const Color(0xFF8BCF5C)));
    for (var i = 0; i < 3; i++) {
      final x = (i * 150 + _t * 10) % 520 - 80;
      D.cloud(c, Offset(x, 70 + i * 22.0), 34, color: const Color(0xEEFFFFFF));
    }
    // meadow with mowing stripes
    D.gradientBg(c, const [Color(0xFF7ACB52), Color(0xFF5DB041)], rect: const Rect.fromLTWH(0, 150, 360, 490));
    for (var i = 0; i < 9; i++) {
      if (i.isEven) c.drawRect(Rect.fromLTWH(i * 40.0, 150, 40, 490), D.fill(const Color(0x10FFFFFF)));
    }
    // fence
    final fence = D.fill(const Color(0xFFF2E3C2));
    c.drawRect(const Rect.fromLTWH(0, 146, 360, 5), fence);
    c.drawRect(const Rect.fromLTWH(0, 160, 360, 5), fence);
    for (var x = 8.0; x < 360; x += 28) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 136, 9, 34), const Radius.circular(3)), fence);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 136, 9, 34), const Radius.circular(3)), D.stroke(const Color(0x55000000), 1.5));
    }
    // flowers
    for (var i = 0; i < 16; i++) {
      final x = (i * 97.0) % 340 + 10, y = 190 + (i * 61.0) % 430;
      final col = const [Color(0xFFFFFFFF), Color(0xFFFFE070), Color(0xFFFF9EC8)][i % 3];
      for (var k = 0; k < 5; k++) {
        final a = k / 5 * pi * 2 + i;
        c.drawCircle(Offset(x + cos(a) * 3.5, y + sin(a) * 3.5), 2.8, D.fill(col));
      }
      c.drawCircle(Offset(x, y), 2, D.fill(Pal.orange));
    }
  }

  void _drawSlime(Canvas c, _Slime s, Offset pos, double scale, {Offset stretch = Offset.zero}) {
    final r = _rad(s.level) * scale * (1 + (s.pop > 0 ? sin(s.pop * pi) * .25 : 0));
    final sq = s.squash;
    final breathe = sin(_t * 3 + s.pos.dx) * .04;
    final sx = 1 + sq * .22 + breathe + stretch.dx.abs() * .006;
    final sy = 1 - sq * .22 - breathe + stretch.dy.abs() * .006;
    final base = pos - Offset(0, s.z);
    final rainbow = s.col == 3;
    final col = rainbow ? D.hsv(_t * 200 + s.pos.dx, .55, 1) : _cols[s.col];
    c.save();
    c.translate(base.dx, base.dy + r * .7);
    c.scale(sx, sy);
    // body
    final body = Path()
      ..moveTo(-r * 1.05, 0)
      ..quadraticBezierTo(-r * 1.1, -r * 1.4, 0, -r * 1.55)
      ..quadraticBezierTo(r * 1.1, -r * 1.4, r * 1.05, 0)
      ..quadraticBezierTo(0, r * .25, -r * 1.05, 0)
      ..close();
    // cape for lv4+
    if (s.level >= 4) {
      final cape = Path()
        ..moveTo(-r * .8, -r * .8)
        ..quadraticBezierTo(-r * 1.4, -r * .1, -r * 1.2, r * .15)
        ..lineTo(r * 1.2, r * .15)
        ..quadraticBezierTo(r * 1.4, -r * .1, r * .8, -r * .8)
        ..close();
      c.drawPath(cape, D.fill(s.level >= 5 ? const Color(0xFFD0203A) : const Color(0xFF6A3FD0)));
      c.drawPath(cape, D.stroke(Pal.ink, 2.5));
    }
    c.drawPath(
        body,
        Paint()
          ..shader = RadialGradient(center: const Alignment(-.3, -.5), radius: .9, colors: [
            Color.lerp(col, Pal.white, .45)!,
            col,
            Color.lerp(col, Pal.ink, .25)!,
          ]).createShader(Rect.fromLTWH(-r * 1.1, -r * 1.55, r * 2.2, r * 1.8)));
    c.drawPath(body, D.stroke(Pal.ink, max(2.5, r * .1)));
    // gloss
    c.drawOval(Rect.fromCenter(center: Offset(-r * .45, -r * 1.05), width: r * .5, height: r * .3), D.fill(const Color(0xAAFFFFFF)));
    c.drawCircle(Offset(-r * .15, -r * 1.2), r * .08, D.fill(const Color(0xCCFFFFFF)));
    // face
    final face = _king == s
        ? Face.happy
        : (s.angry > 0
            ? Face.angry
            : (s == _drag
                ? Face.shocked
                : (_king != null
                    ? Face.love
                    : (host.finished && _king == null ? Face.smug : (s.level >= 4 ? Face.smug : Face.happy)))));
    D.face(c, Offset(0, -r * .55), r * .75, face);
    // adornments
    if (s.level == 2) {
      D.line(c, Offset(0, -r * 1.5), Offset(r * .2, -r * 1.9), Pal.ink, 2);
      c.drawCircle(Offset(r * .22, -r * 1.95), r * .16, D.fill(col));
      c.drawCircle(Offset(r * .22, -r * 1.95), r * .16, D.stroke(Pal.ink, 2));
    } else if (s.level == 3) {
      for (final sd in [-1.0, 1.0]) {
        final h = Path()
          ..moveTo(sd * r * .35, -r * 1.45)
          ..lineTo(sd * r * .55, -r * 1.95)
          ..lineTo(sd * r * .7, -r * 1.3)
          ..close();
        c.drawPath(h, D.fill(const Color(0xFFFFF1C7)));
        c.drawPath(h, D.stroke(Pal.ink, 2));
      }
    } else if (s.level == 4) {
      // silver tiara
      final t = Path()
        ..moveTo(-r * .5, -r * 1.42)
        ..lineTo(-r * .3, -r * 1.75)
        ..lineTo(0, -r * 1.5)
        ..lineTo(r * .3, -r * 1.75)
        ..lineTo(r * .5, -r * 1.42)
        ..close();
      c.drawPath(t, D.fill(const Color(0xFFDDE6F2)));
      c.drawPath(t, D.stroke(Pal.ink, 2));
    } else if (s.level >= 5) {
      final drop = _king == s ? M.easeOutBack(M.clamp01(_kingT * 2.5)) : 1.0;
      final cy = -r * 1.45 - (1 - drop) * 120;
      final crown = Path()
        ..moveTo(-r * .6, cy)
        ..lineTo(-r * .7, cy - r * .6)
        ..lineTo(-r * .35, cy - r * .3)
        ..lineTo(0, cy - r * .75)
        ..lineTo(r * .35, cy - r * .3)
        ..lineTo(r * .7, cy - r * .6)
        ..lineTo(r * .6, cy)
        ..close();
      c.drawPath(crown, D.fill(Pal.gold));
      c.drawPath(crown, D.stroke(Pal.ink, 3));
      c.drawCircle(Offset(0, cy - r * .2), r * .1, D.fill(Pal.red));
      c.drawCircle(Offset(-r * .4, cy - r * .12), r * .07, D.fill(Pal.sky));
      c.drawCircle(Offset(r * .4, cy - r * .12), r * .07, D.fill(Pal.lime));
      final tw = (_t * 3) % 1.0;
      D.star(c, Offset(r * .9, -r * 1.6), 6 * sin(tw * pi), Pal.white);
    }
    if (rainbow) {
      D.star(c, Offset(r * .9, -r * 1.3), 5 + sin(_t * 8) * 2, Pal.white);
    }
    c.restore();
    // level badge
    if (!rainbow) {
      final bp = base + Offset(r * .95, r * .55);
      D.circle(c, bp, 9, Pal.ink);
      D.circle(c, bp, 7.5, s.level >= 5 ? Pal.gold : Pal.white);
      D.text(c, '${s.level}', bp, size: 11, color: Pal.ink);
    }
  }

  void _renderHud(Canvas c) {
    D.rrect(c, const Rect.fromLTWH(10, 42, 340, 48), 18, const Color(0xDDFFFFFF), border: Pal.ink, borderWidth: 3);
    for (var i = 1; i <= 5; i++) {
      final x = 30.0 + (i - 1) * 58;
      final on = i <= _best;
      final r = 6.0 + i * 2.4;
      final col = on ? _cols[_bestColor()] : const Color(0xFFCFCBDB);
      c.drawCircle(Offset(x + 12, 72), r, D.fill(col));
      c.drawCircle(Offset(x + 12, 72), r, D.stroke(Pal.ink, 2));
      if (i == 5) {
        final crown = Path()
          ..moveTo(x + 4, 60)
          ..lineTo(x + 2, 50)
          ..lineTo(x + 8, 55)
          ..lineTo(x + 12, 47)
          ..lineTo(x + 16, 55)
          ..lineTo(x + 22, 50)
          ..lineTo(x + 20, 60)
          ..close();
        c.drawPath(crown, D.fill(on ? Pal.gold : const Color(0xFFCFCBDB)));
        c.drawPath(crown, D.stroke(Pal.ink, 2));
      }
      if (i < 5) D.arrow(c, Offset(x + 41, 72), const Offset(1, 0), 14, on ? Pal.orange : const Color(0xFFCFCBDB), width: 5);
    }
    if (_best == 4 && _king == null) {
      D.text(c, host.tr('king', 'KING!'), const Offset(286, 103), size: 14, color: Pal.gold, stroke: Pal.ink, strokeWidth: 3);
    }
  }
}

class _Slime {
  _Slime(this.pos, this.col, this.level);
  Offset pos;
  int col;
  int level;
  double z = 0, vz = 0;
  bool falling = false;
  bool hopping = false;
  double hopT = 1, hopP = 0;
  Offset hopFrom = Offset.zero, hopTo = Offset.zero;
  double squash = 0;
  double pop = 0;
  double angry = 0;
  bool merging = false;
}

class _Merge {
  _Merge(this.a, this.b, this.col, this.lv);
  final _Slime a, b;
  final int col, lv;
  double t = 0;
  bool done = false;
}
