import '../engine/engine.dart';

/// No.121 Sword Forge Merge — tap the chest for blades, drag equal swords onto
/// each other to forge them up. Reach the Lv.7 LEGENDARY flaming sword.
class G121 extends MiniGame {
  static const _auto = bool.fromEnvironment('AUTOPLAY');
  static const _goal = 7;
  static const _gx = 30.0, _gy = 196.0, _cs = 75.0;
  static const _chest = Offset(180, 575);

  final List<int?> _cells = List.filled(16, null);
  final List<double> _bump = List.filled(16, 0);
  int? _drag; // cell index being dragged
  Offset _dragPos = Offset.zero;
  Offset _downPos = Offset.zero;
  double _t = 0;
  double _chestCd = 0;
  double _chestBump = 0;
  double _fullWarn = 0;
  int _maxLv = 1;
  double _hammerT = -1;
  int _hammerCell = 0;
  double _autoCd = 0;
  bool _won = false;
  final List<_Ember> _embers = [];

  @override
  void init() {
    _cells[5] = 1;
    _cells[10] = 1;
    for (var i = 0; i < 18; i++) {
      _embers.add(_Ember(Offset(rand(0, 360), rand(40, 640)), rand(20, 60), rand(1.5, 3.5)));
    }
  }

  Rect _cellRect(int i) => Rect.fromLTWH(_gx + (i % 4) * _cs, _gy + (i ~/ 4) * _cs, _cs, _cs);
  int? _cellAt(Offset p) {
    final cx = ((p.dx - _gx) / _cs).floor(), cy = ((p.dy - _gy) / _cs).floor();
    if (cx < 0 || cx > 3 || cy < 0 || cy > 3) return null;
    return cy * 4 + cx;
  }

  @override
  void update(double dt) {
    _t += dt;
    _chestCd -= dt;
    _chestBump = M.approach(_chestBump, 0, 8, dt);
    _fullWarn = M.approach(_fullWarn, 0, 3, dt);
    for (var i = 0; i < 16; i++) {
      _bump[i] = M.approach(_bump[i], 0, 7, dt);
    }
    if (_hammerT >= 0) {
      _hammerT += dt / .28;
      if (_hammerT >= 1) _hammerT = -1;
    }
    for (final e in _embers) {
      e.p += Offset(sin(_t * e.wob + e.p.dy * .02) * 10 * dt, -e.speed * dt);
      if (e.p.dy < 30) e.p = Offset(rand(0, 360), 650);
    }
    if (_auto && !host.finished) _autoPlay(dt);
  }

  void _autoPlay(double dt) {
    _autoCd -= dt;
    if (_autoCd > 0) return;
    _autoCd = .45;
    for (var a = 0; a < 16; a++) {
      for (var b = a + 1; b < 16; b++) {
        if (_cells[a] != null && _cells[a] == _cells[b]) {
          onDown(_cellRect(a).center);
          onMove(_cellRect(b).center);
          onUp(_cellRect(b).center);
          return;
        }
      }
    }
    _openChest();
  }

  void _openChest() {
    if (host.finished || _chestCd > 0) return;
    final empty = [for (var i = 0; i < 16; i++) if (_cells[i] == null) i];
    if (empty.isEmpty) {
      _fullWarn = 1;
      host.sfx(Sfx.buzzer, volume: .5);
      host.fx.pop(host.tr('full', 'FULL!'), _chest + const Offset(0, -60), color: Pal.red, size: 26);
      return;
    }
    _chestCd = .3;
    _chestBump = 1;
    host.sfx(Sfx.open, rate: 1.1);
    host.sfx(Sfx.pop, rate: 1.3);
    empty.shuffle(rng);
    for (var k = 0; k < min(2, empty.length); k++) {
      final i = empty[k];
      int lv;
      if (chance(.1)) {
        lv = 0; // rusty spoon. Thanks, chest.
      } else {
        final base = max(1, _maxLv - 2);
        lv = min(max(1, _maxLv - 1), base + (chance(.5) ? 1 : 0));
      }
      _cells[i] = lv;
      _bump[i] = 1;
      host.fx.burst(_cellRect(i).center, Pal.yellow, count: 8, speed: 160, shape: PartShape.spark, gravity: 0);
      if (lv == 0) host.fx.pop(host.tr('spoon', 'SPOON?!'), _cellRect(i).center + const Offset(0, -30), color: Pal.gray, size: 20);
    }
  }

  void _merge(int from, int to) {
    final lv = _cells[to]!;
    var nl = lv + 1;
    final crit = nl >= 2 && nl < _goal && chance(.1);
    if (crit) nl++;
    _cells[from] = null;
    _cells[to] = nl;
    _bump[to] = 1;
    _hammerT = 0;
    _hammerCell = to;
    final at = _cellRect(to).center;
    host.sfx(Sfx.hammer);
    host.sfx(Sfx.clang, rate: .9 + nl * .08);
    host.hitStop(.04);
    host.shake(3.0 + nl);
    host.fx.burst(at, Pal.orange, count: 12 + nl * 3, speed: 240 + nl * 20, shape: PartShape.spark,
        colors: const [Pal.orange, Pal.yellow, Pal.white]);
    host.fx.ring(at, _lvCol(nl), size: 50 + nl * 8);
    host.fx.pop('Lv.$nl', at + const Offset(0, -34), color: _lvCol(nl), size: 22 + nl * 2.0);
    if (crit) {
      host.sfx(Sfx.perfect);
      host.fx.pop(host.tr('critical', 'CRITICAL!'), at + const Offset(0, -64), color: Pal.pink, size: 26);
    }
    if (nl > _maxLv) {
      _maxLv = nl;
      if (nl >= 3) {
        host.sfx(nl >= 5 ? Sfx.ssr : Sfx.rarityUp);
        host.flash(_lvCol(nl), .15);
        host.fx.pop(_rarity(nl), const Offset(180, 160), color: _lvCol(nl), size: 30, life: 1);
      }
    }
    if (nl >= _goal && !_won) {
      _won = true;
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.fire);
      host.shake(14, .5);
      host.flash(Pal.orange, .3);
      host.fx.burst(at, Pal.orange, count: 60, speed: 520, shape: PartShape.star, colors: const [Pal.red, Pal.orange, Pal.yellow]);
      host.fx.pop(host.tr('legendary', 'LEGENDARY!'), const Offset(180, 150), color: Pal.yellow, size: 40, life: 1.6);
      final left = host.timeLeft;
      host.win(stars: left > 6 ? 3 : (left > 2 ? 2 : 1));
    }
  }

  String _rarity(int lv) => lv >= 7
      ? host.tr('legendary', 'LEGENDARY!')
      : lv >= 5
          ? host.tr('epic', 'EPIC!')
          : host.tr('rare', 'RARE!');

  Color _lvCol(int lv) => switch (lv) {
        0 => Pal.gray,
        1 => const Color(0xFFB0B4C0),
        2 => const Color(0xFFE0E6F0),
        3 => const Color(0xFFE08A3C),
        4 => Pal.sky,
        5 => Pal.gold,
        6 => Pal.purple,
        _ => Pal.orange,
      };

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    _downPos = p;
    if ((p - _chest).distance < 60) {
      _openChest();
      return;
    }
    final i = _cellAt(p);
    if (i != null && _cells[i] != null) {
      _drag = i;
      _dragPos = p;
      host.sfx(Sfx.pickup, volume: .5, rate: 1.2);
    }
  }

  @override
  void onMove(Offset p) {
    if (_drag != null) _dragPos = p;
  }

  @override
  void onUp(Offset p) {
    final from = _drag;
    _drag = null;
    if (from == null || host.finished) return;
    final to = _cellAt(p);
    if (to == null || to == from) {
      if ((p - _downPos).distance < 8) _bump[from] = .6;
      return;
    }
    final a = _cells[from], b = _cells[to];
    if (b == null) {
      _cells[to] = a;
      _cells[from] = null;
      _bump[to] = .6;
      host.sfx(Sfx.tap);
    } else if (a == b && a! < _goal) {
      _merge(from, to);
    } else {
      _cells[to] = a;
      _cells[from] = b;
      _bump[to] = .6;
      _bump[from] = .6;
      host.sfx(Sfx.swipe, volume: .6);
    }
  }

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action') _openChest();
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    // forge: warm bricks and furnace glow
    D.gradientBg(c, const [Color(0xFF3A1A12), Color(0xFF1E0E0A)]);
    final mortar = D.stroke(const Color(0x33000000), 2);
    for (var row = 0; row < 22; row++) {
      final y = 40 + row * 28.0;
      c.drawLine(Offset(0, y), Offset(360, y), mortar);
      for (var x = row.isEven ? 0.0 : 36.0; x < 360; x += 72) {
        c.drawLine(Offset(x, y), Offset(x, y + 28), mortar);
        if ((row * 3 + x ~/ 72) % 4 == 0) c.drawRect(Rect.fromLTWH(x + 3, y + 3, 66, 8), D.fill(const Color(0x10FFB070)));
      }
    }
    // furnace mouth
    final glow = .6 + .2 * sin(_t * 5) + (_won ? .4 : 0);
    c.drawCircle(const Offset(180, 110), 150, D.fill(Color.fromRGBO(255, 120, 30, .12 * glow)));
    D.rrect(c, const Rect.fromLTRB(80, 60, 280, 150), 40, const Color(0xFF2A1510), border: Pal.ink, borderWidth: 4);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(92, 72, 268, 150), const Radius.circular(32)));
    D.rrect(c, const Rect.fromLTRB(92, 72, 268, 150), 32, Color.lerp(const Color(0xFF8A2A0A), const Color(0xFFFF7A1A), glow * .6)!);
    for (var i = 0; i < 6; i++) {
      D.flame(c, Offset(105 + i * 30.0, 152), 40 + 14 * sin(_t * 3 + i), _t + i);
    }
    c.restore();
    // embers
    for (final e in _embers) {
      c.drawCircle(e.p, 2, D.fill(Color.fromRGBO(255, 170, 60, .7)));
    }

    // goal panel: silhouette of the legendary sword + current best
    D.rrect(c, const Rect.fromLTRB(16, 44, 76, 150), 14, const Color(0xCC1B1015), border: const Color(0xFF6B4A2B), borderWidth: 3);
    D.text(c, 'MAX', const Offset(46, 58), size: 12, color: const Color(0xFFFFC080));
    c.save();
    c.translate(46, 104);
    c.scale(.8);
    _sword(c, _maxLv, Offset.zero);
    c.restore();
    D.text(c, 'Lv.$_maxLv', const Offset(46, 138), size: 14, color: _lvCol(_maxLv), stroke: Pal.ink, strokeWidth: 3);
    D.rrect(c, const Rect.fromLTRB(284, 44, 344, 150), 14, const Color(0xCC1B1015), border: Pal.orange, borderWidth: 3);
    D.text(c, 'GOAL', const Offset(314, 58), size: 12, color: Pal.orange);
    c.save();
    c.translate(314, 104);
    c.scale(.8);
    _sword(c, _goal, Offset.zero, silhouette: !_won);
    c.restore();
    D.text(c, 'Lv.$_goal', const Offset(314, 138), size: 14, color: Pal.orange, stroke: Pal.ink, strokeWidth: 3);
    // progress pips
    for (var i = 1; i <= _goal; i++) {
      final p = Offset(98 + (i - 1) * 27.5, 172);
      D.circle(c, p, 8, i <= _maxLv ? _lvCol(i) : const Color(0xFF3A2A25), border: Pal.ink, borderWidth: 2);
    }

    // wooden table + anvil board
    D.rrect(c, const Rect.fromLTRB(14, 184, 346, 508), 18, const Color(0xFF6B4226), border: Pal.ink, borderWidth: 4);
    for (var y = 196.0; y < 500; y += 22) {
      c.drawLine(Offset(22, y), Offset(338, y + 4), D.stroke(const Color(0x22000000), 2));
    }
    final dragLv = _drag == null ? null : _cells[_drag!];
    for (var i = 0; i < 16; i++) {
      final r = _cellRect(i).deflate(4);
      final match = dragLv != null && i != _drag && _cells[i] == dragLv && dragLv < _goal;
      D.rrect(c, r.shift(const Offset(0, 4)), 12, const Color(0xFF2A2A34));
      D.rrect(c, r, 12, match ? const Color(0xFF6A7A9A) : const Color(0xFF4A4E5E), border: Pal.ink, borderWidth: 2.5,
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: match ? const [Color(0xFF9FB4E0), Color(0xFF5A6A8A)] : const [Color(0xFF6A6F82), Color(0xFF3E4150)]));
      for (final o in [r.topLeft + const Offset(7, 7), r.topRight + const Offset(-7, 7), r.bottomLeft + const Offset(7, -7), r.bottomRight + const Offset(-7, -7)]) {
        c.drawCircle(o, 2.5, D.fill(const Color(0xFF8E93A8)));
      }
      if (match) {
        c.drawRRect(RRect.fromRectAndRadius(r.inflate(2), const Radius.circular(13)),
            D.stroke(Color.fromRGBO(255, 230, 120, .5 + .5 * M.wave(_t, 3)), 4));
      }
      final lv = _cells[i];
      if (lv != null && i != _drag) {
        final b = _bump[i];
        c.save();
        c.translate(r.center.dx, r.center.dy);
        c.scale(1.3 * (1 + b * .25 * sin(b * 8)));
        if (lv >= 6) D.rays(c, Offset.zero, 34, (lv == 7 ? Pal.orange : Pal.purple).withValues(alpha: .35), count: 8, t: _t * 2);
        _sword(c, lv, Offset.zero);
        c.restore();
        _badge(c, r.bottomRight + const Offset(-12, -11), lv);
      }
    }

    // hammer strike
    if (_hammerT >= 0) {
      final r = _cellRect(_hammerCell);
      final k = _hammerT < .5 ? _hammerT * 2 : 1.0;
      final ang = -1.4 + k * 1.4;
      c.save();
      c.translate(r.right + 6, r.center.dy - 6);
      c.rotate(ang);
      c.drawLine(Offset.zero, const Offset(-44, 0), D.stroke(Pal.ink, 9));
      c.drawLine(Offset.zero, const Offset(-44, 0), D.stroke(const Color(0xFF9A5B34), 6));
      D.rrect(c, const Rect.fromLTWH(-60, -14, 20, 28), 4, const Color(0xFF8E93A8), border: Pal.ink, borderWidth: 3);
      c.restore();
    }

    // chest
    _drawChest(c);

    // dragged sword on top
    if (_drag != null && _cells[_drag!] != null) {
      final lv = _cells[_drag!]!;
      D.shadow(c, _dragPos + const Offset(6, 26), 50, 12, .35);
      c.save();
      c.translate(_dragPos.dx, _dragPos.dy - 8);
      c.scale(1.55);
      c.rotate(sin(_t * 10) * .06);
      _sword(c, lv, Offset.zero);
      c.restore();
    }

    if (host.time < 2.6 && _maxLv == 1 && _drag == null) {
      // tutorial: drag the two starting daggers together
      final a = _cellRect(5).center, b = _cellRect(10).center;
      final k = (_t * .8) % 1;
      D.hand(c, Offset.lerp(a, b, M.easeInOut(k))!, 0);
      D.text(c, host.tr('merge', 'MERGE!'), const Offset(180, 320), size: 24, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _badge(Canvas c, Offset p, int lv) {
    D.circle(c, p, 10, _lvCol(lv), border: Pal.ink, borderWidth: 2);
    D.text(c, '$lv', p, size: 12, color: Pal.ink);
  }

  void _drawChest(Canvas c) {
    final b = _chestBump;
    final full = _cells.every((e) => e != null);
    c.save();
    c.translate(_chest.dx + sin(_t * 50) * _fullWarn * 5, _chest.dy);
    c.scale(1 + b * .15, 1 - b * .1);
    c.drawCircle(const Offset(0, -6), 64, D.fill(Color.fromRGBO(255, 200, 80, .15 + .1 * M.wave(_t, 2))));
    // body
    D.rrect(c, const Rect.fromLTRB(-58, -10, 58, 40), 8, const Color(0xFF9A5B34), border: Pal.ink, borderWidth: 4);
    for (final x in [-40.0, 40.0]) {
      c.drawRect(Rect.fromLTWH(x - 5, -10, 10, 50), D.fill(Pal.gold));
    }
    // lid (pops open on bump)
    c.save();
    c.translate(0, -10);
    c.rotate(-b * .5);
    final lid = RRect.fromRectAndCorners(const Rect.fromLTRB(-60, -34, 60, 0),
        topLeft: const Radius.circular(26), topRight: const Radius.circular(26));
    c.drawRRect(lid, D.fill(const Color(0xFFB8733F)));
    c.drawRRect(lid, D.stroke(Pal.ink, 4));
    for (final x in [-40.0, 40.0]) {
      c.drawRect(Rect.fromLTWH(x - 5, -32, 10, 32), D.fill(Pal.gold));
    }
    c.restore();
    D.rrect(c, const Rect.fromLTRB(-10, -18, 10, 6), 4, Pal.gold, border: Pal.ink, borderWidth: 2.5);
    c.restore();
    D.text(c, full ? host.tr('full', 'FULL!') : host.tr('tap', 'TAP!'), _chest + const Offset(0, 54),
        size: 16, color: full ? Pal.red : Pal.yellow, stroke: Pal.ink);
  }

  /// Draws a sword of [lv] centered at [o], diagonal. Level 0 is a spoon.
  void _sword(Canvas c, int lv, Offset o, {bool silhouette = false}) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(-pi / 4);
    final ink = silhouette ? const Color(0xFF120A08) : Pal.ink;
    if (lv == 0) {
      // rusty spoon
      final col = silhouette ? ink : const Color(0xFFA08070);
      c.drawLine(const Offset(0, 22), const Offset(0, -6), D.stroke(ink, 8));
      c.drawLine(const Offset(0, 22), const Offset(0, -6), D.stroke(col, 5));
      c.drawOval(const Rect.fromLTWH(-9, -26, 18, 24), D.fill(col));
      c.drawOval(const Rect.fromLTWH(-9, -26, 18, 24), D.stroke(ink, 3));
      if (!silhouette) {
        c.drawCircle(const Offset(-3, -16), 3, D.fill(const Color(0xFF7A4A2A)));
        c.drawCircle(const Offset(4, 10), 2, D.fill(const Color(0xFF7A4A2A)));
      }
      c.restore();
      return;
    }
    final len = 22.0 + lv * 3.4; // blade length
    final w = lv == 1 ? 7.0 : (lv == 3 ? 10.0 : 6.0 + lv * .5);
    if (lv >= 6 && !silhouette) {
      // aura
      c.drawOval(Rect.fromCenter(center: Offset(0, -len / 2 + 4), width: w * 4, height: len * 1.6),
          D.fill((lv == 7 ? Pal.orange : Pal.purple).withValues(alpha: .25 + .1 * sin(_t * 6))));
    }
    if (lv == 7 && !silhouette) {
      for (var i = 0; i < 4; i++) {
        D.flame(c, Offset(sin(_t * 9 + i) * 3 + (i.isEven ? -4 : 4), -len * (.05 + i * .24) + 8), 18 + i * 2.0, _t * 1.3 + i);
      }
    }
    final bladeCol = silhouette
        ? ink
        : switch (lv) {
            1 => const Color(0xFF9CA0AC),
            2 => const Color(0xFFDDE4F0),
            3 => const Color(0xFFE6A060),
            4 => const Color(0xFFCFE8FF),
            5 => const Color(0xFFFFE27A),
            6 => const Color(0xFFD8B8FF),
            _ => const Color(0xFFFFF6D8),
          };
    final blade = Path()
      ..moveTo(-w / 2, 4)
      ..lineTo(-w / 2, -len + w * .8)
      ..lineTo(0, -len - (lv >= 4 ? 6 : 2))
      ..lineTo(w / 2, -len + w * .8)
      ..lineTo(w / 2, 4)
      ..close();
    c.drawPath(blade, D.fill(bladeCol));
    if (!silhouette) {
      c.drawLine(const Offset(0, 2), Offset(0, -len + 2), D.stroke(Color.lerp(bladeCol, Pal.white, .6)!, 1.6));
      if (lv == 1) {
        c.drawCircle(Offset(-w * .2, -len * .5), 1.5, D.fill(const Color(0xFF7A5A40)));
      }
    }
    c.drawPath(blade, D.stroke(ink, 2.5));
    // guard
    final gw = 12.0 + lv * 2.4;
    final guardCol = silhouette
        ? ink
        : switch (lv) { 1 || 2 => const Color(0xFF6B6F86), 3 => const Color(0xFF8A5A2A), 4 => const Color(0xFF3D6BFF), 5 => Pal.gold, 6 => const Color(0xFF6A2FBF), _ => Pal.red };
    if (lv >= 5) {
      final g = Path()
        ..moveTo(-gw / 2, 2)
        ..quadraticBezierTo(-gw / 2 - 4, -6, -gw / 2 + 2, -4)
        ..lineTo(gw / 2 - 2, -4)
        ..quadraticBezierTo(gw / 2 + 4, -6, gw / 2, 2)
        ..lineTo(gw / 2, 7)
        ..lineTo(-gw / 2, 7)
        ..close();
      c.drawPath(g, D.fill(guardCol));
      c.drawPath(g, D.stroke(ink, 2.2));
    } else {
      D.rrect(c, Rect.fromCenter(center: const Offset(0, 5), width: gw, height: 6), 3, guardCol, border: ink, borderWidth: 2.2);
    }
    // hilt + pommel
    D.rrect(c, const Rect.fromLTWH(-3, 8, 6, 14), 2, silhouette ? ink : const Color(0xFF5A3420), border: ink, borderWidth: 1.8);
    D.circle(c, const Offset(0, 24), 4, silhouette ? ink : guardCol, border: ink, borderWidth: 1.8);
    if (lv >= 4 && !silhouette) {
      final gemCol = switch (lv) { 4 => Pal.sky, 5 => Pal.red, 6 => Pal.pink, _ => Pal.yellow };
      D.circle(c, const Offset(0, 5), 3.5, gemCol, border: ink, borderWidth: 1.5);
    }
    c.restore();
    if (lv >= 5 && !silhouette && (_t * 2 + lv) % 1.5 < .3) {
      D.star(c, o + const Offset(12, -14), 4, Pal.white);
    }
  }
}

class _Ember {
  _Ember(this.p, this.speed, this.wob);
  Offset p;
  final double speed;
  final double wob;
}
