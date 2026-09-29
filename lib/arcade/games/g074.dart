import '../engine/engine.dart';

/// No.074 Pop the Wrap! — bubble wrap ASMR. Tap or swipe across the sheet
/// to pop every single bubble before time runs out.
class G074 extends MiniGame {
  static const _cols = 5;
  late int _rows;
  late double _top;
  static const _cell = 64.0;
  static const _left = 20.0;
  final _bubbles = <_Bubble>[];
  double _t = 0;
  int _popped = 0;
  double _lastPop = -9;
  int _chain = 0;
  Offset? _last;
  double _bliss = 0; // mascot reaction pulse
  double _allT = -1;

  @override
  void init() {
    _rows = host.speed > 1.35 ? 7 : 6;
    _top = _rows == 7 ? 138 : 160;
    final gold = randInt(_cols * _rows);
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        _bubbles.add(_Bubble(
          Offset(_left + _cell * (c + .5), _top + _cell * (r + .5)),
          rand(0, pi * 2),
          _bubbles.length == gold,
        ));
      }
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    for (final b in _bubbles) {
      if (b.popped) b.popT += dt;
    }
    _bliss = M.approach(_bliss, 0, 5, dt);
    if (_allT >= 0) _allT += dt;
  }

  void _popAt(Offset p) {
    if (host.finished) return;
    for (final b in _bubbles) {
      if (b.popped) continue;
      if ((b.pos - p).distance < 30) _pop(b);
    }
  }

  void _pop(_Bubble b) {
    b.popped = true;
    _popped++;
    final now = host.time;
    _chain = now - _lastPop < .35 ? _chain + 1 : 0;
    _lastPop = now;
    host.sfx(Sfx.pop, rate: .85 + rand(0, .35) + min(_chain, 12) * .04, volume: .9);
    host.fx.burst(b.pos, const Color(0xCCFFFFFF), count: 6, speed: 120, size: 5, gravity: 0, life: .35);
    host.fx.ring(b.pos, const Color(0xAAFFFFFF), size: 26, life: .25);
    host.punch(.012);
    _bliss = 1;
    if (b.gold) {
      host.sfx(Sfx.coin);
      host.fx.coins(b.pos, count: 8);
      host.fx.pop(host.tr('bonus', 'BONUS!'), b.pos + const Offset(0, -30), color: Pal.gold, size: 24);
      host.addScore(50);
    } else {
      host.addScore(10);
    }
    if (_chain > 0 && _chain % 6 == 0) {
      host.sfx(Sfx.combo, rate: 1 + _chain * .03);
      host.fx.pop('${host.tr('combo', 'COMBO')} x$_chain', b.pos + const Offset(0, -34), color: Pal.pink, size: 22);
    }
    if (_popped == _bubbles.length) {
      _allT = 0;
      host.sfx(Sfx.perfect);
      host.shake(6);
      host.flash(const Color(0x88FFFFFF));
      host.fx.pop(host.tr('perfect', 'PERFECT!'), const Offset(180, 300), color: Pal.lime, size: 40);
      final left = host.timeLeft;
      host.win(stars: left > 1.5 ? 3 : (left > .6 ? 2 : 1));
    }
  }

  @override
  void onDown(Offset p) {
    _last = p;
    _popAt(p);
  }

  @override
  void onMove(Offset p) {
    final a = _last ?? p;
    final d = (p - a).distance;
    final steps = max(1, (d / 10).ceil());
    for (var i = 1; i <= steps; i++) {
      _popAt(Offset.lerp(a, p, i / steps)!);
    }
    _last = p;
  }

  @override
  void onUp(Offset p) => _last = null;

  @override
  void onTimeUp() {
    host.sfx(Sfx.aww);
    host.lose();
  }

  @override
  void render(Canvas c) {
    // cardboard desk
    D.gradientBg(c, const [Color(0xFFFFD27A), Color(0xFFE09A4E)]);
    D.rays(c, const Offset(180, 360), 700, const Color(0x26FFFFFF), count: 16, t: _t * .25);
    // tape strips
    D.rrect(c, const Rect.fromLTWH(-10, 590, 380, 30), 0, const Color(0x99D9B26A));

    // HUD-ish counter + mascot
    final left = _bubbles.length - _popped;
    D.rrect(c, const Rect.fromLTWH(16, 48, 150, 64), 20, Pal.ink);
    D.text(c, '$left', const Offset(62, 80), size: 38, color: left == 0 ? Pal.lime : Pal.white, stroke: Pal.ink);
    // mini bubble icon
    _drawBubble(c, const Offset(130, 80), 18, 0, false, false);

    final mood = _allT >= 0
        ? Face.love
        : (host.timeLeft < 1.5 ? Face.shocked : (_bliss > .3 ? Face.happy : Face.smug));
    final bob = _bliss * 6;
    D.blob(c, Offset(290, 82 - bob), 36, Pal.sky, face: mood, squash: 1 + _bliss * .12);
    if (_bliss > .3) {
      D.heart(c, Offset(330, 50 - _bliss * 10), 18 * _bliss, Pal.pink, border: Pal.ink);
    }

    // the wrap sheet
    final sheet = Rect.fromLTWH(_left - 8, _top - 8, _cell * _cols + 16, _cell * _rows + 16);
    D.rrect(c, sheet.shift(const Offset(6, 8)), 18, const Color(0x44000000));
    D.rrect(c, sheet, 18, const Color(0x66FFFFFF), border: const Color(0xAAFFFFFF), borderWidth: 3);
    D.rrect(c, sheet, 18, const Color(0x00000000), border: Pal.ink, borderWidth: 4);

    for (final b in _bubbles) {
      final wob = sin(_t * 3 + b.phase) * 1.2;
      _drawBubble(c, b.pos, 27 + wob, b.popT, b.popped, b.gold);
    }

    // sheet shine sweep
    final sx = ((_t * .6) % 1.6 - .3) * 400;
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(sheet, const Radius.circular(18)));
    c.drawPath(
        Path()
          ..moveTo(sx, sheet.top)
          ..lineTo(sx + 40, sheet.top)
          ..lineTo(sx - 60, sheet.bottom)
          ..lineTo(sx - 100, sheet.bottom)
          ..close(),
        D.fill(const Color(0x22FFFFFF)));
    c.restore();

    if (host.time < 2 && _popped < 3) {
      final hp = Offset(60 + M.wave(_t, .6) * 240, _top + _cell * 1.5);
      D.hand(c, hp, _t);
      D.text(c, host.tr('swipe', 'SWIPE!'), Offset(180, _top + _cell * _rows + 34), size: 26, color: Pal.yellow,
          stroke: Pal.ink);
    }
  }

  void _drawBubble(Canvas c, Offset o, double r, double popT, bool popped, bool gold) {
    if (!popped) {
      final base = gold ? const Color(0xAAFFD23F) : const Color(0x88E8F6FF);
      c.drawCircle(o + const Offset(3, 5), r, D.fill(const Color(0x22000000)));
      c.drawCircle(o, r, D.fill(base));
      c.drawCircle(o, r, D.stroke(gold ? const Color(0xFFB8860B) : const Color(0xFF6FA8D8), 3));
      c.drawOval(Rect.fromCenter(center: o + Offset(-r * .35, -r * .38), width: r * .7, height: r * .45),
          D.fill(const Color(0xDDFFFFFF)));
      c.drawCircle(o + Offset(r * .4, r * .38), r * .12, D.fill(const Color(0x99FFFFFF)));
      if (gold) D.star(c, o + const Offset(0, 3), r * .42, Pal.gold, border: Pal.ink);
      return;
    }
    // popped: squashed plastic
    final k = M.clamp01(popT * 8);
    final s = k < 1 ? 1.25 - .25 * k : 1.0;
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s, s * .9);
    c.drawCircle(Offset.zero, r * .85, D.fill(const Color(0x33FFFFFF)));
    c.drawCircle(Offset.zero, r * .85, D.stroke(const Color(0x668FB8DA), 2));
    final crease = D.stroke(const Color(0x88FFFFFF), 2);
    c.drawLine(Offset(-r * .45, -r * .2), Offset(r * .1, r * .1), crease);
    c.drawLine(Offset(r * .1, r * .1), Offset(r * .4, -r * .3), crease);
    c.drawLine(Offset(-r * .2, r * .4), Offset(r * .15, r * .1), crease);
    c.restore();
  }
}

class _Bubble {
  _Bubble(this.pos, this.phase, this.gold);
  final Offset pos;
  final double phase;
  final bool gold;
  bool popped = false;
  double popT = 0;
}
