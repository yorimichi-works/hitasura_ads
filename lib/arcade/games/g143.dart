import '../engine/engine.dart';

/// No.143 Deep Clean ASMR — top-down messy room. Rub stains away with the
/// sponge, vacuum the dust bunnies, fling trash into the bin. 95% clean wins
/// with a sparkle sweep and a BEFORE polaroid.
class G143 extends MiniGame {
  static const _room = Rect.fromLTWH(12, 80, 336, 524);
  static const _bin = Offset(300, 558);

  final _stains = <_Stain>[];
  final _motes = <_Mote>[];
  final _trash = <_Trash>[];
  _Trash? _held;
  Offset? _last;
  double _t = 0;
  double _pct = 0;
  double _shownPct = 0;
  double _scrubSfx = 0;
  double _vacSfx = 0;
  double _binBounce = 0;
  double _winT = -1;
  double _petJump = 0;
  int _chain = 0;
  double _chainT = 0;
  String _tool = '';

  @override
  Color get backdrop => const Color(0xFF3A2A22);

  @override
  void init() {
    const stainCols = [Color(0xFF6B3E1E), Color(0xFFB0202F), Color(0xFF5B2A7A), Color(0xFF4E5A1E), Color(0xFF7A4A12)];
    const spots = [Offset(90, 250), Offset(250, 225), Offset(175, 360), Offset(80, 470), Offset(245, 430)];
    for (var i = 0; i < spots.length; i++) {
      final p = spots[i] + Offset(rand(-12, 12), rand(-12, 12));
      _stains.add(_Stain(p, rand(28, 36), stainCols[i], _blob(rand(28, 36), 11), [
        for (var k = 0; k < 5; k++) Offset.fromDirection(rand(0, pi * 2), rand(38, 52)),
      ]));
    }
    const patches = [Offset(300, 320), Offset(60, 360), Offset(170, 520)];
    for (final c in patches) {
      for (var k = 0; k < 16; k++) {
        final p = c + Offset(rand(-34, 34), rand(-26, 26));
        _motes.add(_Mote(p, k < 3 ? rand(9, 12) : rand(2.5, 5), k < 3));
      }
    }
    const tp = [Offset(150, 180), Offset(300, 490), Offset(60, 560), Offset(210, 290)];
    for (var i = 0; i < 4; i++) {
      _trash.add(_Trash(tp[i], i, rand(-.6, .6)));
    }
  }

  Path _blob(double r, int n) {
    final pts = <Offset>[for (var i = 0; i < n; i++) Offset.fromDirection(i / n * pi * 2, r * rand(.7, 1.15))];
    final path = Path();
    for (var i = 0; i < n; i++) {
      final a = pts[i], b = pts[(i + 1) % n];
      final m = (a + b) / 2;
      if (i == 0) path.moveTo((pts[n - 1].dx + a.dx) / 2, (pts[n - 1].dy + a.dy) / 2);
      path.quadraticBezierTo(a.dx, a.dy, m.dx, m.dy);
    }
    return path..close();
  }

  double get _stainPart => _stains.fold(0.0, (s, e) => s + (1 - e.hp)) / _stains.length;
  double get _dustPart => _motes.where((m) => m.gone).length / _motes.length;
  double get _trashPart => _trash.where((t) => t.state == 3).length / _trash.length;

  @override
  void update(double dt) {
    _t += dt;
    _scrubSfx -= dt;
    _vacSfx -= dt;
    _binBounce = M.approach(_binBounce, 0, 7, dt);
    _petJump = M.approach(_petJump, 0, 5, dt);
    _chainT -= dt;
    if (_chainT <= 0) _chain = 0;
    if (_winT >= 0) _winT += dt;
    for (final s in _stains) {
      s.glint = max(0, s.glint - dt * 1.6);
      s.wob = M.approach(s.wob, 0, 8, dt);
    }

    // vacuum
    final down = host.pointerDown && _held == null && !host.finished;
    final p = host.pointer;
    var sucking = false;
    for (final m in _motes) {
      if (m.gone) continue;
      final d = p - m.pos;
      final dist = d.distance;
      if (down && dist < 50) {
        sucking = true;
        m.vel += d / max(dist, 1) * 1800 * dt;
        m.vel *= .9;
        m.pos += m.vel * dt;
        m.spin += dt * 12;
        if (dist < 10) {
          m.gone = true;
          if (m.bunny) {
            host.sfx(Sfx.pop, volume: .5, rate: rand(1.2, 1.5));
            host.fx.pop('+5', p + const Offset(0, -30), color: Pal.sky, size: 18);
            host.score += 5;
          }
          _checkWin();
        }
      } else {
        m.vel = Offset.zero;
      }
    }
    if (sucking && _vacSfx <= 0) {
      _vacSfx = .22;
      host.sfx(Sfx.wind, volume: .35, rate: rand(1.5, 1.8));
    }

    // trash flights
    for (final tr in _trash) {
      if (tr.state != 2) continue;
      tr.ft += dt / tr.fdur;
      tr.rot += dt * 12;
      if (tr.ft >= 1) {
        tr.state = 3;
        _binBounce = 1;
        _chain++;
        _chainT = 1.5;
        host.sfx(Sfx.thud, volume: .7);
        host.sfx(Sfx.correct, rate: 1 + _chain * .1);
        host.fx.burst(_bin + const Offset(0, -10), Pal.white, count: 10, speed: 160, shape: PartShape.star, gravity: 200);
        host.fx.pop(tr.far ? host.tr('nice_shot', 'NICE SHOT!') : host.tr('nice', 'NICE!'), _bin + const Offset(-40, -50),
            color: tr.far ? Pal.pink : Pal.lime, size: tr.far ? 26 : 22);
        host.addScore(tr.far ? 30 : 15);
        host.shake(3);
        _checkWin();
      }
    }
    _shownPct = M.approach(_shownPct, _pct, 8, dt);
  }

  void _checkWin() {
    _pct = _stainPart * .5 + _dustPart * .25 + _trashPart * .25;
    if (_pct >= .95 && !host.finished) {
      _pct = 1;
      _winT = 0;
      _petJump = 1;
      host.sfx(Sfx.sparkle);
      host.sfx(Sfx.fanfare, volume: .8);
      host.flash(Pal.white, .3);
      for (var i = 0; i < 12; i++) {
        host.fx.sparkle(Offset(rand(30, 330), rand(100, 580)), count: 3, radius: 20, color: i.isEven ? Pal.white : Pal.yellow);
      }
      host.win(stars: host.time < 11 ? 3 : (host.time < 15 ? 2 : 1));
    }
  }

  @override
  void onDown(Offset p) {
    _last = p;
    for (final tr in _trash.reversed) {
      if (tr.state == 0 && (tr.pos - p).distance < 32) {
        _held = tr;
        tr.state = 1;
        tr.grab = tr.pos - p;
        host.sfx(Sfx.pickup, rate: 1.1);
        return;
      }
    }
  }

  @override
  void onMove(Offset p) {
    final last = _last ?? p;
    _last = p;
    final held = _held;
    if (held != null) {
      held.pos = p + held.grab * .7;
      held.grab *= .7;
      _tool = 'hand';
      return;
    }
    final d = (p - last).distance;
    var scrubbing = false;
    for (final s in _stains) {
      if (s.hp <= 0) continue;
      if ((p - s.pos).distance < s.r + 14) {
        scrubbing = true;
        s.hp = max(0, s.hp - d / (400 * host.speed));
        s.wob = 1;
        if (chance(.35)) {
          host.fx.add(Particle(
              pos: p + Offset(rand(-16, 16), rand(-12, 12)),
              vel: Offset(rand(-30, 30), rand(-40, 0)),
              life: rand(.4, .8),
              color: const Color(0xDDFFFFFF),
              size: rand(5, 11),
              drag: 2,
              grow: 6));
        }
        if (s.hp <= 0) {
          s.glint = 1;
          _chain++;
          _chainT = 1.5;
          host.sfx(Sfx.sparkle, rate: 1 + _chain * .08);
          host.sfx(Sfx.ding, volume: .6, rate: 1 + _chain * .1);
          host.fx.sparkle(s.pos, count: 10, radius: 30);
          host.fx.ring(s.pos, Pal.white, size: 50);
          host.addScore(20, s.pos + const Offset(0, -20));
          host.punch(.02);
          _checkWin();
        }
      }
    }
    if (scrubbing) {
      _tool = 'sponge';
      if (_scrubSfx <= 0 && d > 2) {
        _scrubSfx = .11;
        host.sfx(Sfx.scrub, volume: .55, rate: rand(.9, 1.3));
      }
      _checkWin();
    } else {
      final nearDust = _motes.any((m) => !m.gone && (m.pos - p).distance < 60);
      _tool = nearDust ? 'vac' : 'sponge';
    }
  }

  @override
  void onUp(Offset p) {
    final held = _held;
    _held = null;
    _last = null;
    _tool = '';
    if (held == null) return;
    held
      ..state = 2
      ..from = held.pos
      ..ft = 0
      ..far = (held.pos - _bin).distance > 170;
    held.fdur = held.far ? .6 : .35;
    host.sfx(Sfx.whoosh, rate: 1.2);
  }

  @override
  void onTimeUp() {
    if (_pct >= .8) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    // wall / skirting
    D.gradientBg(c, const [Color(0xFFF7E3C6), Color(0xFFE7C9A0)]);
    for (var x = 0.0; x < 360; x += 24) {
      c.drawRect(Rect.fromLTWH(x, 36, 12, 44), D.fill(const Color(0x14A0522D)));
    }
    _renderRoom(c, before: false);
    _renderHud(c);
    _renderCursor(c);
    if (host.time < 2.4 && _stains.every((s) => s.hp > .9)) {
      final s = _stains[0];
      final hp = s.pos + Offset(sin(_t * 9) * 26, 0);
      D.hand(c, hp, _t);
      D.text(c, host.tr('scrub', 'SCRUB!'), s.pos + const Offset(0, -52), size: 22, color: Pal.yellow, stroke: Pal.ink);
    }
    if (_winT >= 0) _renderWin(c);
  }

  void _renderRoom(Canvas c, {required bool before}) {
    final r = _room;
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)));
    // wooden floor planks
    for (var i = 0; i < 17; i++) {
      final y = r.top + i * 32.0;
      final base = i.isEven ? const Color(0xFFC98A52) : const Color(0xFFBF7F48);
      c.drawRect(Rect.fromLTWH(r.left, y, r.width, 32), D.fill(base));
      c.drawRect(Rect.fromLTWH(r.left, y + 30, r.width, 2), D.fill(const Color(0xFF9A6034)));
      final off = (i * 97) % 160.0;
      for (var x = r.left + off - 160; x < r.right; x += 160) {
        c.drawRect(Rect.fromLTWH(x, y, 2, 30), D.fill(const Color(0xFF9A6034)));
        c.drawOval(Rect.fromLTWH(x + 60, y + 12, 18, 6), D.fill(const Color(0x22000000)));
      }
    }
    // window light
    final light = Path()
      ..moveTo(r.left, r.top + 40)
      ..lineTo(r.left + 150, r.top)
      ..lineTo(r.left + 330, r.top + 260)
      ..lineTo(r.left, r.top + 380)
      ..close();
    c.drawPath(light, D.fill(Color.fromRGBO(255, 245, 210, before ? .08 : .18)));
    // rug
    const rug = Rect.fromLTWH(56, 300, 250, 150);
    c.drawOval(rug.shift(const Offset(0, 5)), D.fill(const Color(0x33000000)));
    c.drawOval(rug, D.fill(const Color(0xFF3F7FB8)));
    c.drawOval(rug.deflate(12), D.fill(const Color(0xFFF2E6C9)));
    c.drawOval(rug.deflate(24), D.fill(const Color(0xFFE56B6F)));
    c.drawOval(rug.deflate(44), D.fill(const Color(0xFFF2E6C9)));
    c.drawOval(rug.deflate(58), D.fill(const Color(0xFF3F7FB8)));
    // sofa
    const sofa = Rect.fromLTWH(70, 92, 220, 64);
    D.rrect(c, sofa.shift(const Offset(0, 6)), 14, const Color(0x33000000));
    D.rrect(c, sofa, 14, const Color(0xFF5E9E8C), border: const Color(0xFF2F5E52), borderWidth: 3);
    D.rrect(c, Rect.fromLTWH(sofa.left + 16, sofa.top + 16, 92, 42), 10, const Color(0xFF7DBBA8));
    D.rrect(c, Rect.fromLTWH(sofa.left + 112, sofa.top + 16, 92, 42), 10, const Color(0xFF7DBBA8));
    // pet sleeping on the sofa
    final clean = before ? 0.0 : _pct;
    final face = before
        ? Face.sad
        : (_winT >= 0 ? Face.love : (clean > .75 ? Face.happy : (clean > .4 ? Face.neutral : Face.sad)));
    final petY = 118 - _petJump * 26 * (before ? 0 : 1) - (before ? 0 : M.wave(_t, 1.2) * 2);
    D.blob(c, Offset(240, petY), 22, const Color(0xFFF5F0E6), face: face, squash: 1 + (before ? 0 : M.wave(_t, .6) * .05));
    c.drawPath(
        Path()
          ..moveTo(224, petY - 16)
          ..lineTo(226, petY - 32)
          ..lineTo(236, petY - 20)
          ..moveTo(256, petY - 16)
          ..lineTo(254, petY - 32)
          ..lineTo(244, petY - 20),
        D.fill(const Color(0xFFF5F0E6)));
    if (!before && clean < .4 && _winT < 0) {
      D.text(c, 'z', Offset(268, petY - 30 - (_t * 14) % 16), size: 14, color: const Color(0xFF55606A));
    }
    // plant
    D.circle(c, const Offset(40, 116), 20, const Color(0xFFB0643A), border: const Color(0xFF6E3A1E));
    for (var i = 0; i < 7; i++) {
      final a = i / 7 * pi * 2 + sin(_t * 1.3 + i) * .05;
      c.drawOval(
          Rect.fromCenter(center: const Offset(40, 116) + Offset.fromDirection(a, 18), width: 30, height: 14),
          D.fill(i.isEven ? const Color(0xFF2E9E5A) : const Color(0xFF45B86E)));
    }
    // bin
    final bs = 1 + _binBounce * .18;
    c.save();
    c.translate(_bin.dx, _bin.dy);
    c.scale(bs, 2 - bs);
    D.circle(c, const Offset(0, 4), 30, const Color(0x33000000));
    D.circle(c, Offset.zero, 30, const Color(0xFF8E9AAF), border: const Color(0xFF444C5C), borderWidth: 3);
    D.circle(c, Offset.zero, 22, const Color(0xFF2B2F3A));
    for (final tr in _trash) {
      if (tr.state == 3 && !before) _drawTrash(c, Offset((tr.kind - 1.5) * 6, (tr.kind % 2) * 4 - 2), tr.kind, tr.rot, .45);
    }
    c.restore();

    // stains
    for (final s in _stains) {
      final hp = before ? 1.0 : s.hp;
      if (hp <= 0) continue;
      c.save();
      c.translate(s.pos.dx, s.pos.dy);
      final w = 1 + s.wob * .04 * sin(_t * 40);
      c.scale(w, 2 - w);
      final col = s.color.withValues(alpha: .85 * hp);
      c.drawPath(s.path, D.fill(col));
      c.drawPath(s.path, D.stroke(Color.lerp(s.color, Pal.ink, .4)!.withValues(alpha: .5 * hp), 3));
      c.scale(.55);
      c.drawPath(s.path, D.fill(Color.lerp(s.color, Pal.ink, .25)!.withValues(alpha: .5 * hp)));
      c.restore();
      for (final d in s.drops) {
        c.drawCircle(s.pos + d * (hp * .3 + .7), 4.5 * hp, D.fill(col));
      }
    }
    // glints
    if (!before) {
      for (final s in _stains) {
        if (s.glint > 0) {
          final k = sin(s.glint * pi);
          c.drawPath(D.starPath(s.pos, 30 * k, 5 * k, points: 4, rotation: 0), D.fill(Pal.white));
          D.circle(c, s.pos, 36 * (1 - s.glint), Pal.white.withValues(alpha: .2 * s.glint));
        }
      }
    }
    // dust
    for (final m in _motes) {
      if (!before && m.gone) continue;
      final p = before ? m.home : m.pos;
      if (m.bunny) {
        for (var k = 0; k < 6; k++) {
          c.drawCircle(p + Offset.fromDirection(k + m.spin, m.size * .55), m.size * .6, D.fill(const Color(0xFF9C9690)));
        }
        c.drawCircle(p, m.size * .7, D.fill(const Color(0xFFB8B2AA)));
        c.drawCircle(p + const Offset(-2, -2), 1.6, D.fill(Pal.ink));
        c.drawCircle(p + const Offset(3, -2), 1.6, D.fill(Pal.ink));
      } else {
        c.drawCircle(p, m.size, D.fill(const Color(0xAA8A847C)));
      }
    }
    // trash on the floor
    for (final tr in _trash) {
      if (before) {
        _drawTrash(c, tr.home, tr.kind, tr.home.dx * .01, 1);
        continue;
      }
      if (tr.state == 0) {
        _drawTrash(c, tr.pos, tr.kind, tr.rot, 1);
        // stink lines
        for (var k = -1; k <= 1; k++) {
          final base = tr.pos + Offset(k * 10.0, -20);
          final ph = (_t * 1.2 + k * .3 + tr.kind * .2) % 1;
          final path = Path()..moveTo(base.dx, base.dy - ph * 10);
          for (var j = 1; j <= 4; j++) {
            path.lineTo(base.dx + sin(j * 1.6 + _t * 5) * 4, base.dy - ph * 10 - j * 5);
          }
          c.drawPath(path, D.stroke(Color.fromRGBO(120, 200, 60, .7 * (1 - ph)), 2.5));
        }
      }
    }
    // fly buzzing around the first remaining trash
    if (!before) {
      final dirty = _trash.where((t) => t.state == 0).toList();
      if (dirty.isNotEmpty) {
        final f = dirty.first.pos + Offset(cos(_t * 7) * 26, sin(_t * 11) * 14 - 20);
        c.drawOval(Rect.fromCenter(center: f + const Offset(-4, -3), width: 7, height: 4), D.fill(const Color(0xAAFFFFFF)));
        c.drawOval(Rect.fromCenter(center: f + const Offset(4, -3), width: 7, height: 4), D.fill(const Color(0xAAFFFFFF)));
        D.circle(c, f, 3.5, Pal.ink);
      }
    } else {
      // grime overlay for the "before" photo
      c.drawRect(r, D.fill(const Color(0x2A4A3A10)));
    }
    c.restore();
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)), D.stroke(const Color(0xFF5A3A22), 5));

    // held / flying trash on top
    if (!before) {
      for (final tr in _trash) {
        if (tr.state == 1) {
          D.shadow(c, tr.pos + const Offset(8, 22), 40, 12);
          _drawTrash(c, tr.pos, tr.kind, tr.rot + sin(_t * 8) * .1, 1.25);
        } else if (tr.state == 2) {
          final k = tr.ft.clamp(0.0, 1.0);
          final pos = Offset.lerp(tr.from, _bin, k)! + Offset(0, -sin(k * pi) * (tr.far ? 150 : 50));
          tr.pos = pos;
          _drawTrash(c, pos, tr.kind, tr.rot, 1.2 - k * .5);
        }
      }
    }
  }

  void _drawTrash(Canvas c, Offset p, int kind, double rot, double s) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(rot);
    c.scale(s);
    switch (kind) {
      case 0: // banana peel
        for (var i = 0; i < 3; i++) {
          c.save();
          c.rotate(i * 2.1);
          final leaf = Path()
            ..moveTo(-5, 0)
            ..quadraticBezierTo(4, -12, 22, -14)
            ..quadraticBezierTo(20, -4, 5, 2)
            ..close();
          c.drawPath(leaf, D.fill(Pal.yellow));
          c.drawPath(leaf, D.stroke(const Color(0xFF8A6A10), 2));
          D.circle(c, const Offset(21, -13), 2.5, const Color(0xFF5A3A10));
          c.restore();
        }
        D.circle(c, Offset.zero, 5, const Color(0xFFE8C040), border: const Color(0xFF8A6A10), borderWidth: 2);
      case 1: // crumpled paper
        final path = Path()
          ..moveTo(-15, -6)
          ..lineTo(-6, -15)
          ..lineTo(5, -12)
          ..lineTo(15, -14)
          ..lineTo(14, -2)
          ..lineTo(17, 9)
          ..lineTo(5, 15)
          ..lineTo(-8, 13)
          ..lineTo(-16, 8)
          ..close();
        c.drawPath(path, D.fill(const Color(0xFFF4F4F0)));
        c.drawPath(path, D.stroke(const Color(0xFF55606A), 2));
        D.line(c, const Offset(-8, -6), const Offset(4, 2), const Color(0xFFAAB0B8), 1.5);
        D.line(c, const Offset(4, 2), const Offset(10, -6), const Color(0xFFAAB0B8), 1.5);
        D.line(c, const Offset(-4, 8), const Offset(4, 2), const Color(0xFFAAB0B8), 1.5);
      case 2: // soda can lying down
        D.rrect(c, const Rect.fromLTWH(-18, -9, 36, 18), 6, Pal.red, border: Pal.ink, borderWidth: 2);
        D.rrect(c, const Rect.fromLTWH(-18, -9, 6, 18), 3, const Color(0xFFC8CCD4));
        D.rrect(c, const Rect.fromLTWH(-6, -4, 16, 5), 2, Pal.white);
        c.drawRect(const Rect.fromLTWH(-10, -8, 26, 2), D.fill(const Color(0x55FFFFFF)));
      default: // pizza slice
        final slice = Path()
          ..moveTo(-16, -12)
          ..lineTo(16, -12)
          ..lineTo(0, 18)
          ..close();
        c.drawPath(slice, D.fill(const Color(0xFFFFC857)));
        c.drawPath(slice, D.stroke(const Color(0xFF8A5A10), 2));
        D.rrect(c, const Rect.fromLTWH(-18, -16, 36, 7), 3, const Color(0xFFC07A2C), border: const Color(0xFF8A5A10), borderWidth: 2);
        D.circle(c, const Offset(-4, -3), 3.5, const Color(0xFFC8302F));
        D.circle(c, const Offset(5, 2), 3, const Color(0xFFC8302F));
        D.circle(c, const Offset(0, 9), 2.5, const Color(0xFFC8302F));
    }
    c.restore();
  }

  void _renderHud(Canvas c) {
    const bar = Rect.fromLTWH(58, 46, 244, 20);
    D.rrect(c, bar.inflate(3), 13, Pal.ink);
    D.bar(c, bar, _shownPct, Color.lerp(const Color(0xFF9CC7FF), Pal.teal, _shownPct)!, back: const Color(0xFF3A3450));
    // 95% mark
    c.drawRect(Rect.fromLTWH(bar.left + bar.width * .95 - 1, bar.top - 2, 2, bar.height + 4), D.fill(Pal.yellow));
    D.text(c, '${(_shownPct * 100).floor()}%', bar.center, size: 15, color: Pal.white, stroke: Pal.ink);
    // sparkle icon
    c.drawPath(D.starPath(const Offset(38, 56), 13 + sin(_t * 5) * 2, 3, points: 4, rotation: 0), D.fill(Pal.yellow));
    c.drawPath(D.starPath(const Offset(38, 56), 13 + sin(_t * 5) * 2, 3, points: 4, rotation: 0), D.stroke(Pal.ink, 2));
    // remaining-task lights: stains / dust / trash
    final done = [
      _stains.every((s) => s.hp <= 0),
      _motes.every((m) => m.gone),
      _trash.every((t) => t.state >= 2),
    ];
    const cols = [Pal.brown, Pal.gray, Pal.red];
    for (var i = 0; i < 3; i++) {
      final o = Offset(318 + (i - 1) * 0.0 + i * 12.0 - 6, 56);
      D.circle(c, o, 5, done[i] ? Pal.lime : cols[i], border: Pal.ink, borderWidth: 1.5);
    }
  }

  void _renderCursor(Canvas c) {
    if (!host.pointerDown || host.finished) return;
    final p = host.pointer;
    switch (_tool) {
      case 'sponge':
        c.save();
        c.translate(p.dx, p.dy);
        c.rotate(sin(_t * 30) * .12);
        D.rrect(c, const Rect.fromLTWH(-24, -16, 48, 32), 9, Pal.yellow, border: Pal.ink, borderWidth: 3);
        D.rrect(c, const Rect.fromLTWH(-24, -16, 48, 11), 6, const Color(0xFF2ECC71), border: Pal.ink, borderWidth: 3);
        for (var i = 0; i < 5; i++) {
          D.circle(c, Offset(-15 + i * 7.5, 6 + (i % 2) * 3.0), 2, const Color(0xFFE0A800));
        }
        c.restore();
      case 'vac':
        c.save();
        c.translate(p.dx, p.dy);
        D.line(c, const Offset(0, 0), const Offset(60, 120), const Color(0xFF555C6E), 9);
        final head = Path()
          ..moveTo(-26, 10)
          ..lineTo(26, 10)
          ..lineTo(14, -10)
          ..lineTo(-14, -10)
          ..close();
        c.drawPath(head, D.fill(const Color(0xFFE04E6A)));
        c.drawPath(head, D.stroke(Pal.ink, 3));
        c.drawRect(const Rect.fromLTWH(-24, 6, 48, 5), D.fill(Pal.ink));
        c.restore();
        // suction rings
        for (var i = 0; i < 2; i++) {
          final k = (_t * 2 + i * .5) % 1;
          c.drawCircle(p, 50 * (1 - k), D.stroke(Color.fromRGBO(255, 255, 255, .5 * k), 2));
        }
    }
  }

  void _renderWin(Canvas c) {
    final t = _winT;
    // diagonal shine sweep
    final x = -120 + t * 500;
    c.save();
    c.clipRect(_room);
    final band = Path()
      ..moveTo(x, _room.top)
      ..lineTo(x + 60, _room.top)
      ..lineTo(x - 140, _room.bottom)
      ..lineTo(x - 200, _room.bottom)
      ..close();
    c.drawPath(band, D.fill(const Color(0x66FFFFFF)));
    c.restore();
    // BEFORE polaroid
    final k = M.easeOutBack((t / .45).clamp(0, 1));
    c.save();
    c.translate(76, 250 + (1 - k) * 300);
    c.rotate(-.14);
    D.rrect(c, const Rect.fromLTWH(-62, -86, 124, 206), 4, Pal.white, border: const Color(0x55000000), borderWidth: 1);
    c.save();
    c.translate(-56, -80);
    c.scale(.333);
    c.translate(-_room.left, -_room.top);
    c.clipRect(_room);
    _renderRoom(c, before: true);
    c.restore();
    D.text(c, host.tr('before', 'BEFORE'), const Offset(0, 106), size: 15, color: Pal.ink);
    c.restore();
    if (t > .3) {
      D.title(c, host.tr('after', 'AFTER'), const Offset(250, 470), size: 34, color: Pal.teal, rotate: .1,
          scale: M.easeOutBack(((t - .3) / .3).clamp(0, 1)));
    }
  }
}

class _Stain {
  _Stain(this.pos, this.r, this.color, this.path, this.drops);
  final Offset pos;
  final double r;
  final Color color;
  final Path path;
  final List<Offset> drops;
  double hp = 1;
  double glint = 0;
  double wob = 0;
}

class _Mote {
  _Mote(this.pos, this.size, this.bunny) : home = pos;
  Offset pos;
  final Offset home;
  final double size;
  final bool bunny;
  Offset vel = Offset.zero;
  double spin = 0;
  bool gone = false;
}

class _Trash {
  _Trash(this.pos, this.kind, this.rot) : home = pos;
  Offset pos;
  final Offset home;
  final int kind;
  double rot;
  int state = 0; // 0 floor, 1 held, 2 flying, 3 binned
  Offset grab = Offset.zero;
  Offset from = Offset.zero;
  double ft = 0;
  double fdur = .5;
  bool far = false;
}
