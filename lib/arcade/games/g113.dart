import 'dart:math' as math;
import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.113 Loot Box Frenzy — mash to crack open loot boxes. While you mash,
/// the glow escalates through the rarity colors up to the box's hidden tier
/// (common → rare → epic → LEGENDARY). The box fights back (progress decays
/// if you stop). Pull a Legendary before time runs out.

const _tierCols = <Color>[Color(0xFFB8C0D0), Color(0xFF3FA0FF), Color(0xFFB45CFF), Color(0xFFFFB020)];

Paint _glow(Color c, double blur) => Paint()
  ..color = c
  ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur);

class _Item {
  _Item(this.kind, this.tier);
  final int kind, tier;
  double t = 0; // flight 0..1 from box to shelf
}

enum _Ph { drop, mash, open, done }

class G113 extends MiniGame {
  static const _tiers = <int>[0, 1, 0, 2, 3];
  static const _need = <int>[6, 6, 5, 6, 9];
  static const _boxC = Offset(180, 352);

  _Ph _ph = _Ph.drop;
  double _t = 0, _phT = 0;
  int _box = 0;
  double _prog = 0; // taps accumulated
  int _shown = 0; // glow tier currently revealed
  double _idle = 9;
  double _squash = 0;
  double _shake = 0;
  double _lid = 0; // lid blast 0..1
  final _items = <_Item>[];
  int _taps = 0;
  double _blink = 0;

  @override
  Color get backdrop => const Color(0xFF0A0418);

  int get _tier => _tiers[_box];
  double get _k => M.clamp01(_prog / _need[_box]);

  @override
  void update(double dt) {
    _t += dt;
    _phT += dt;
    _idle += dt;
    _squash = M.approach(_squash, 0, 12, dt);
    _shake = M.approach(_shake, 0, 6, dt);
    _blink -= dt;
    if (_blink < -3) _blink = .15;
    for (final it in _items) {
      if (it.t < 1) {
        it.t = math.min(1, it.t + dt / .7);
        if (it.t >= 1) {
          host.sfx(Sfx.pickup, rate: 1 + it.tier * .1, volume: .6);
          host.fx.sparkle(_shelf(_items.indexOf(it)), count: 6, radius: 20, color: _tierCols[it.tier]);
        }
      }
    }
    switch (_ph) {
      case _Ph.drop:
        if (_phT > .38) {
          _ph = _Ph.mash;
          _phT = 0;
          host.sfx(Sfx.thud);
          host.shake(5);
          _squash = 1;
          host.fx.smoke(_boxC + const Offset(-70, 70), count: 4);
          host.fx.smoke(_boxC + const Offset(70, 70), count: 4);
        }
      case _Ph.mash:
        if (_idle > .35 && _prog > 0) {
          _prog = math.max(0, _prog - dt * 2.2);
        }
      case _Ph.open:
        _lid = math.min(1, _lid + dt * 3);
        final hold = _tier == 3 ? 1.6 : .5;
        if (_phT > hold) {
          if (_tier == 3) {
            _ph = _Ph.done;
            _phT = 0;
            host.win(stars: host.time < 8.5 ? 3 : (host.time < 11.5 ? 2 : 1));
          } else {
            _box++;
            _prog = 0;
            _shown = 0;
            _lid = 0;
            _ph = _Ph.drop;
            _phT = 0;
            host.sfx(Sfx.whoosh, rate: 1.2);
          }
        }
      case _Ph.done:
        if (chance(.35)) host.fx.coins(Offset(rand(20, 340), 660), count: 2, speed: 850);
    }
  }

  Offset _shelf(int i) => Offset(52 + i * 64.0, 578);

  @override
  void onDown(Offset p) => _mash();

  @override
  void onKey(String key, bool down) {
    if (down) _mash();
  }

  void _mash() {
    if (_ph != _Ph.mash) return;
    _idle = 0;
    _taps++;
    _prog += 1;
    _squash = 1;
    _shake = 1;
    final k = _k;
    host.sfx(Sfx.hit, volume: .6, rate: .9 + k * .7);
    if (_taps % 2 == 0) host.sfx(Sfx.shake, volume: .4, rate: 1 + k * .5);
    host.shake(1.5 + k * 3);
    host.fx.burst(_boxC + Offset(rand(-60, 60), rand(-30, 20)), _tierCols[_shown], count: 5, speed: 260, size: 5, shape: PartShape.spark, gravity: 200);
    // tier escalation while mashing
    final next = math.min(_tier, (k * (_tier + 1) * .999).floor());
    if (next > _shown) {
      _shown = next;
      host.sfx(Sfx.rarityUp, rate: 1 + _shown * .15);
      host.flash(_tierCols[_shown].withValues(alpha: .5), .15);
      host.shake(6 + _shown * 2);
      host.punch(.04);
      host.fx.ring(_boxC, _tierCols[_shown], size: 150, life: .45);
      host.fx.pop(_tierName(_shown), _boxC + const Offset(0, -140), color: _tierCols[_shown], size: 26 + _shown * 4.0);
    }
    if (_prog >= _need[_box]) _open();
  }

  String _tierName(int t) => switch (t) {
        0 => host.tr('common', 'COMMON'),
        1 => host.tr('rare', 'RARE'),
        2 => host.tr('epic', 'EPIC'),
        _ => host.tr('legendary', 'LEGENDARY'),
      };

  void _open() {
    _ph = _Ph.open;
    _phT = 0;
    _lid = 0;
    final t = _tier;
    final col = _tierCols[t];
    _items.add(_Item(_box, t));
    host.sfx(Sfx.open);
    host.sfx(Sfx.explodeSmall, volume: .6);
    host.fx.burst(_boxC + const Offset(0, -40), col, count: 30 + t * 15, speed: 380 + t * 80, shape: PartShape.star, gravity: 300);
    host.fx.ring(_boxC, col, size: 180 + t * 40, life: .5);
    if (t == 3) {
      host.sfx(Sfx.ssr);
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.coins);
      host.flash(Pal.white, .35);
      host.shake(16, .6);
      host.hitStop(.14);
      host.punch(.09);
      host.fx.confetti(count: 110);
      host.fx.coins(_boxC, count: 40, speed: 750);
    } else if (t == 2) {
      host.sfx(Sfx.magic);
      host.shake(8);
      host.flash(col.withValues(alpha: .5), .15);
    } else if (t == 1) {
      host.sfx(Sfx.gem);
      host.shake(5);
    } else {
      host.sfx(Sfx.pop);
      host.sfx(Sfx.oops, volume: .4);
    }
  }

  // --------------------------------------------------------------- render --

  @override
  void render(Canvas c) {
    final col = _tierCols[_ph == _Ph.open || _ph == _Ph.done ? _tier : _shown];
    D.gradientBg(c, [const Color(0xFF14062E), Color.lerp(const Color(0xFF2A0A4A), col, .25)!, const Color(0xFF07020F)]);
    // escalating rays
    final intensity = _ph == _Ph.mash ? _k : (_ph == _Ph.drop ? 0.0 : 1.0);
    final tierBoost = (_ph == _Ph.mash ? _shown : _tier) / 3;
    D.rays(c, _boxC, 700, col.withValues(alpha: .06 + .2 * intensity * (.4 + .6 * tierBoost)), count: 10 + (tierBoost * 8).round(), t: _t * (.4 + intensity * 1.5));
    // neon floor
    final gp = D.stroke(col.withValues(alpha: .35), 1.5);
    for (var i = 0; i < 7; i++) {
      final y = 470 + i * i * 2.4 + ((_t * 10) % 6);
      c.drawLine(Offset(0, y), Offset(360, y), gp);
    }
    for (var i = -6; i <= 6; i++) {
      c.drawLine(Offset(180 + i * 18.0, 466), Offset(180 + i * 64.0, 560), gp);
    }
    _hud(c);
    if (_ph != _Ph.done || _phT < 5) _drawBox(c);
    _shelfDraw(c);
    _flyingItems(c);
    if (_ph == _Ph.open || _ph == _Ph.done) _reveal(c);
    if (_ph == _Ph.mash && _taps == 0) {
      D.hand(c, _boxC + const Offset(10, 10), _t);
      D.title(c, host.tr('tap', 'TAP!'), _boxC + const Offset(0, 130), size: 34, scale: 1 + .08 * math.sin(_t * 12));
    }
  }

  void _hud(Canvas c) {
    // box counter pips
    for (var i = 0; i < _tiers.length; i++) {
      final o = Offset(120 + i * 30.0, 62);
      final done = i < _items.length;
      final cur = i == _box && !done;
      c.drawCircle(o, cur ? 11 : 9, D.fill(done ? _tierCols[_items[i].tier] : const Color(0x44FFFFFF)));
      c.drawCircle(o, cur ? 11 : 9, D.stroke(cur ? Pal.white : Pal.ink, 2.5));
      if (cur) D.text(c, '?', o, size: 12, color: Pal.white);
    }
    D.text(c, '${host.tr('legendary', 'LEGENDARY')} 0.01%', const Offset(180, 90), size: 13, color: const Color(0xFFFFD27A));
  }

  void _drawBox(Canvas c) {
    var o = _boxC;
    if (_ph == _Ph.drop) {
      final u = M.clamp01(_phT / .38);
      o = Offset.lerp(const Offset(180, -140), _boxC, u * u)!;
    }
    final k = _ph == _Ph.mash ? _k : (_ph == _Ph.open || _ph == _Ph.done ? 1.0 : 0.0);
    final col = _tierCols[_ph == _Ph.open || _ph == _Ph.done ? _tier : _shown];
    final rumble = _ph == _Ph.mash ? (k * 3 + _shake * 5) : 0.0;
    o += Offset(math.sin(_t * 67) * rumble, math.cos(_t * 51) * rumble * .5);
    final sq = _squash * .12;
    // glow + shadow
    D.shadow(c, _boxC + const Offset(0, 86), 220, 34, .5);
    c.drawCircle(o, 110 + k * 50, _glow(col.withValues(alpha: .25 + .5 * k), 36));
    c.save();
    c.translate(o.dx, o.dy + 80);
    c.scale(1 + sq, 1 - sq);
    c.rotate(math.sin(_t * 40) * _shake * .04);
    c.translate(0, -80);
    // dimensions: front face 170x110, top depth 44
    const fw = 170.0, fh = 110.0, dp = 40.0;
    const fl = -fw / 2 + -12, ft = -10.0;
    final front = Rect.fromLTWH(fl, ft, fw, fh);
    // side face
    final side = Path()
      ..moveTo(front.right, front.top)
      ..lineTo(front.right + dp * .6, front.top - dp * .6)
      ..lineTo(front.right + dp * .6, front.bottom - dp * .6)
      ..lineTo(front.right, front.bottom)
      ..close();
    c.drawPath(side, D.fill(const Color(0xFF3A1470)));
    c.drawPath(side, D.stroke(Pal.ink, 4));
    c.drawRect(front, Paint()
      ..shader = ui.Gradient.linear(front.topLeft, front.bottomRight, const [Color(0xFF7A3AE0), Color(0xFF4A1A9C)], const [0, 1]));
    // metal bands
    for (final x in [front.left + 26, front.right - 26]) {
      c.drawRect(Rect.fromLTWH(x - 9, front.top, 18, fh), D.fill(const Color(0xFFFFC53D)));
      c.drawRect(Rect.fromLTWH(x - 9, front.top, 18, fh), D.stroke(Pal.ink, 3));
      c.drawCircle(Offset(x, front.top + 20), 3, D.fill(const Color(0xFF8C5A00)));
      c.drawCircle(Offset(x, front.bottom - 20), 3, D.fill(const Color(0xFF8C5A00)));
    }
    c.drawRect(front, D.stroke(Pal.ink, 4));
    // emblem
    final em = front.center + const Offset(0, 8);
    c.drawCircle(em, 26, D.fill(const Color(0xFF1E0A40)));
    c.drawCircle(em, 26, D.stroke(col, 4));
    D.text(c, '?', em, size: 32, color: col, stroke: Pal.ink, strokeWidth: 4);
    // cracks of light growing with progress
    if (k > .15 && _ph != _Ph.open) {
      final cp = _glow(col.withValues(alpha: .9), 3)..strokeWidth = 3 + k * 3;
      final cracks = (k * 6).floor();
      for (var i = 0; i < cracks; i++) {
        final sx = front.left + 20 + (i * 53 % 130).toDouble();
        final path = Path()
          ..moveTo(sx, front.top)
          ..lineTo(sx + 8, front.top + 20 + i * 3)
          ..lineTo(sx - 4, front.top + 36 + i * 4)
          ..lineTo(sx + 6, front.top + 50 + i * 5);
        c.drawPath(path, cp..style = PaintingStyle.stroke);
        c.drawPath(path, D.stroke(Pal.white, 1.5));
      }
    }
    // lid (blasts off when opened)
    final lidUp = _lid;
    c.save();
    c.translate(0, -lidUp * 260);
    c.rotate(-lidUp * 1.4);
    final lidTop = front.top - 34;
    final lid = Path()
      ..moveTo(front.left - 6, front.top + 2)
      ..lineTo(front.left - 6, lidTop + 10)
      ..quadraticBezierTo(front.center.dx, lidTop - 26, front.right + 6, lidTop + 10)
      ..lineTo(front.right + 6, front.top + 2)
      ..close();
    final lidSide = Path()
      ..moveTo(front.right + 6, front.top + 2)
      ..lineTo(front.right + 6, lidTop + 10)
      ..lineTo(front.right + 6 + dp * .6, lidTop + 10 - dp * .6)
      ..lineTo(front.right + 6 + dp * .6, front.top + 2 - dp * .6)
      ..close();
    c.drawPath(lidSide, D.fill(const Color(0xFF4A1A8C)));
    c.drawPath(lidSide, D.stroke(Pal.ink, 4));
    c.drawPath(lid, Paint()..shader = ui.Gradient.linear(Offset(0, lidTop - 20), Offset(0, front.top), const [Color(0xFFA070FF), Color(0xFF6A2AD0)], const [0, 1]));
    c.drawRect(Rect.fromLTWH(front.left - 6, front.top - 6, fw + 12, 8), D.fill(const Color(0xFFFFC53D)));
    c.drawPath(lid, D.stroke(Pal.ink, 4));
    // lock
    D.rrect(c, Rect.fromCenter(center: Offset(front.center.dx, front.top - 2), width: 26, height: 22), 5, const Color(0xFFFFC53D), border: Pal.ink, borderWidth: 3);
    c.drawCircle(Offset(front.center.dx, front.top - 4), 3.5, D.fill(Pal.ink));
    c.restore();
    // gap between lid and box: light + peeking eyes (mimic!)
    if (_ph == _Ph.mash || _ph == _Ph.drop) {
      final gapH = 2 + k * 8 + _shake * 4;
      c.drawRect(Rect.fromLTWH(front.left, front.top - gapH / 2, fw, gapH), _glow(col.withValues(alpha: .6 + .4 * k), 4 + k * 8));
      if (k < .3 && _blink <= 0) {
        for (final ex in [-22.0, 22.0]) {
          c.drawOval(Rect.fromCenter(center: Offset(front.center.dx + ex, front.top + 1), width: 12, height: 6), D.fill(Pal.white));
          c.drawCircle(Offset(front.center.dx + ex + math.sin(_t) * 2, front.top + 1), 2, D.fill(Pal.ink));
        }
      }
    }
    c.restore();
    // progress bar
    if (_ph == _Ph.mash) {
      const r = Rect.fromLTWH(70, 470, 220, 18);
      D.bar(c, r, k, col, border: Pal.ink);
      for (var i = 1; i <= _tier; i++) {
        final x = r.left + r.width * i / (_tier + 1);
        c.drawLine(Offset(x, r.top), Offset(x, r.bottom), D.stroke(const Color(0x88FFFFFF), 2));
      }
    }
  }

  void _reveal(Canvas c) {
    final t = _tier;
    final col = _tierCols[t];
    final k = _ph == _Ph.done ? 1.0 : M.clamp01(_phT / .25);
    // light pillar
    final w = 70.0 + t * 30;
    c.drawRect(Rect.fromCenter(center: const Offset(180, 200), width: w * k, height: 560), Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 420), const Offset(0, -20), [col.withValues(alpha: .85), col.withValues(alpha: 0)], const [0, 1]));
    c.drawRect(Rect.fromCenter(center: const Offset(180, 200), width: w * .3 * k, height: 560), Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 420), const Offset(0, -20), const [Color(0xDDFFFFFF), Color(0x00FFFFFF)], const [0, 1]));
    if (t == 3) {
      for (var i = 0; i < 3; i++) {
        D.rays(c, const Offset(180, 230), 600, [Pal.yellow, Pal.orange, Pal.white][i].withValues(alpha: .22), count: 14, t: _t * (1 + i * .4), width: .3);
      }
    }
    // item floating above the box before it flies to the shelf
    final it = _items.last;
    if (_ph == _Ph.open && it.t < .02 || (_ph == _Ph.open && _phT < .5)) {
      final u = M.easeOutBack(M.clamp01(_phT / .35));
      final p = Offset(180, 330 - u * 110 + math.sin(_t * 4) * 4);
      _itemIcon(c, p, 30 + 18 * u + t * 4, it.kind);
    }
    final ts = M.easeOutBack(M.clamp01(_phT / .3));
    if (_ph == _Ph.open || _ph == _Ph.done) {
      D.title(c, _tierName(t), const Offset(180, 138), size: t == 3 ? 42 : 30, color: col, scale: ts, rotate: -.04);
    }
    if (_ph == _Ph.done) {
      _itemIcon(c, Offset(180, 250 + math.sin(_t * 3) * 6), 70, it.kind);
    }
  }

  void _flyingItems(Canvas c) {
    for (var i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (it.t >= 1 || (_ph == _Ph.open && i == _items.length - 1 && _phT < .5)) continue;
      if (_ph == _Ph.done && i == _items.length - 1) continue;
      final u = M.easeInOut(it.t);
      final p = Offset.lerp(const Offset(180, 220), _shelf(i), u)! + Offset(0, -math.sin(u * math.pi) * 80);
      _itemIcon(c, p, M.lerp(50, 22, u), it.kind);
    }
  }

  void _shelfDraw(Canvas c) {
    const r = Rect.fromLTWH(14, 540, 332, 78);
    D.rrect(c, r, 16, const Color(0xCC12062A), border: const Color(0xFF7A5CFF), borderWidth: 3);
    for (var i = 0; i < 5; i++) {
      final o = _shelf(i);
      final has = i < _items.length && _items[i].t >= 1;
      final col = has ? _tierCols[_items[i].tier] : const Color(0x33FFFFFF);
      D.rrect(c, Rect.fromCenter(center: o, width: 54, height: 54), 10, has ? col.withValues(alpha: .25) : const Color(0x22000000), border: col, borderWidth: 2.5);
      if (has) {
        if (_items[i].tier == 3) c.drawCircle(o, 30, _glow(col.withValues(alpha: .6 + .3 * M.wave(_t, 2)), 10));
        _itemIcon(c, o, 22, _items[i].kind);
      }
    }
  }

  void _itemIcon(Canvas c, Offset o, double r, int kind) {
    switch (kind) {
      case 0: // wooden sword
        c.save();
        c.translate(o.dx, o.dy);
        c.rotate(-.8);
        D.rrect(c, Rect.fromLTWH(-r * .12, -r, r * .24, r * 1.4), r * .1, const Color(0xFFC68A4E), border: Pal.ink, borderWidth: 2);
        D.rrect(c, Rect.fromLTWH(-r * .4, r * .38, r * .8, r * .16), 3, const Color(0xFF8A5A2E), border: Pal.ink, borderWidth: 2);
        D.rrect(c, Rect.fromLTWH(-r * .1, r * .54, r * .2, r * .4), 3, const Color(0xFF6A3A1E), border: Pal.ink, borderWidth: 2);
        c.restore();
      case 1: // blue shield
        final p = Path()
          ..moveTo(o.dx - r * .75, o.dy - r * .7)
          ..lineTo(o.dx + r * .75, o.dy - r * .7)
          ..quadraticBezierTo(o.dx + r * .8, o.dy + r * .3, o.dx, o.dy + r)
          ..quadraticBezierTo(o.dx - r * .8, o.dy + r * .3, o.dx - r * .75, o.dy - r * .7)
          ..close();
        c.drawPath(p, D.fill(const Color(0xFF3FA0FF)));
        c.drawPath(p, D.stroke(Pal.ink, math.max(2, r * .08)));
        D.star(c, o + Offset(0, -r * .05), r * .38, Pal.white);
      case 2: // potion
        c.drawCircle(o + Offset(0, r * .25), r * .6, D.fill(const Color(0xFF52E05A)));
        c.drawCircle(o + Offset(0, r * .25), r * .6, D.stroke(Pal.ink, math.max(2, r * .08)));
        D.rrect(c, Rect.fromLTWH(o.dx - r * .2, o.dy - r * .7, r * .4, r * .45), 3, const Color(0xFFDDEEFF), border: Pal.ink, borderWidth: 2);
        D.rrect(c, Rect.fromLTWH(o.dx - r * .25, o.dy - r * .9, r * .5, r * .22), 3, const Color(0xFF9A5B34), border: Pal.ink, borderWidth: 2);
        c.drawCircle(o + Offset(-r * .2, r * .08), r * .12, D.fill(const Color(0xAAFFFFFF)));
      case 3: // epic staff
        c.drawLine(o + Offset(-r * .5, r), o + Offset(r * .2, -r * .4), D.stroke(Pal.ink, r * .22));
        c.drawLine(o + Offset(-r * .5, r), o + Offset(r * .2, -r * .4), D.stroke(const Color(0xFF8A5A2E), r * .14));
        c.drawCircle(o + Offset(r * .3, -r * .6), r * .5, _glow(const Color(0xAAB45CFF), 8));
        D.gem(c, o + Offset(r * .3, -r * .6), r * .42, const Color(0xFFB45CFF));
      default: // LEGENDARY golden dragon blade
        c.drawCircle(o, r * 1.1, _glow(const Color(0x99FFB020), r * .4));
        c.save();
        c.translate(o.dx, o.dy);
        c.rotate(-.75 + math.sin(_t * 2) * .05);
        final blade = Path()
          ..moveTo(0, -r * 1.2)
          ..lineTo(r * .22, -r * .9)
          ..lineTo(r * .18, r * .35)
          ..lineTo(-r * .18, r * .35)
          ..lineTo(-r * .22, -r * .9)
          ..close();
        c.drawPath(blade, Paint()..shader = ui.Gradient.linear(Offset(-r * .2, 0), Offset(r * .2, 0), const [Color(0xFFFFFFFF), Color(0xFFBFE8FF), Color(0xFF8AB8E0)], const [0, .5, 1]));
        c.drawPath(blade, D.stroke(Pal.ink, math.max(2, r * .06)));
        final guard = Path()
          ..moveTo(-r * .6, r * .3)
          ..quadraticBezierTo(0, r * .15, r * .6, r * .3)
          ..lineTo(r * .45, r * .5)
          ..quadraticBezierTo(0, r * .4, -r * .45, r * .5)
          ..close();
        c.drawPath(guard, D.fill(Pal.gold));
        c.drawPath(guard, D.stroke(Pal.ink, math.max(2, r * .06)));
        D.rrect(c, Rect.fromLTWH(-r * .1, r * .45, r * .2, r * .55), 3, const Color(0xFFD01A5C), border: Pal.ink, borderWidth: 2);
        c.drawCircle(Offset(0, r * 1.05), r * .13, D.fill(Pal.gold));
        c.drawCircle(Offset(0, r * .36), r * .1, D.fill(Pal.red));
        c.restore();
        final sp = o + Offset(math.cos(_t * 4) * r, math.sin(_t * 4) * r * .7);
        c.drawPath(D.starPath(sp, r * .25, r * .06, points: 4, rotation: 0), D.fill(Pal.white));
    }
  }
}
