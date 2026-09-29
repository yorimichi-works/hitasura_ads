import '../engine/engine.dart';

/// No.148 Close This Ad — a screaming popup ad with giant FAKE close buttons
/// (they spawn more popups) and one tiny REAL x that scurries around, dodges
/// near-misses and hides behind the sticker. Tap the real one to escape.
class G148 extends MiniGame {
  static const _main = Rect.fromLTWH(22, 92, 316, 460);
  static const _sticker = Offset(262, 352);
  static const _spots = [
    Offset(252, 108), // header, next to the fake giant X
    Offset(40, 540), // bottom-left
    Offset(283, 334), // peeking from behind the sticker
    Offset(326, 470), // right edge
    Offset(34, 104), // top-left
    Offset(180, 546), // under the install button
  ];

  double _t = 0;
  Offset _x = const Offset(40, 540);
  int _spot = 1;
  double _hopT = 1.6;
  int _dodges = 0;
  double _giggle = 0;
  bool _won = false;
  double _winT = 0;
  final _pops = <_Pop>[];
  double _autoT = 3.2;
  final _fakes = <_Fake>[];
  double _installPress = 0;
  double _lol = 0;
  Offset _lolAt = Offset.zero;

  @override
  Color get backdrop => const Color(0xFF2A0A3A);

  @override
  void init() {
    _fakes.addAll([
      _Fake(const Offset(302, 128), 22),
      _Fake(const Offset(58, 210), 18),
      _Fake(const Offset(300, 520), 16),
    ]);
    _spot = pick([1, 3, 5]);
    _x = _spots[_spot];
  }

  bool get _tired => _dodges >= 3;

  @override
  void update(double dt) {
    _t += dt;
    _giggle = max(0, _giggle - dt);
    _installPress = M.approach(_installPress, 0, 10, dt);
    _lol = max(0, _lol - dt);
    for (final f in _fakes) {
      f.hit = max(0, f.hit - dt * 2);
    }
    for (final p in _pops) {
      p.age += dt;
    }
    if (_won) {
      _winT += dt;
      return;
    }
    if (host.finished) return;
    // real X wanders between spots
    _hopT -= dt * host.speed * (_tired ? .5 : 1);
    if (_hopT <= 0) {
      _hopT = rand(1.3, 2.0);
      _moveTo(_nextSpot(host.pointer));
    }
    final target = _spots[_spot] + (_tired ? Offset(0, sin(_t * 3) * 2) : Offset(sin(_t * 7) * 2, 0));
    _x = M.approachO(_x, target, _tired ? 4 : 9, dt);
    // flee from a hovering/dragging finger
    if (host.pointerDown && !_tired && (host.pointer - _x).distance < 56 && (host.pointer - _x).distance > 20) {
      _dodge();
    }
    // popups arrive on their own
    _autoT -= dt * host.speed;
    if (_autoT <= 0) {
      _autoT = rand(2.6, 3.6);
      _spawnPop();
    }
    if (_pops.length >= 7) {
      host.sfx(Sfx.crash);
      host.sfx(Sfx.glitch);
      host.shake(12, .6);
      host.flash(Pal.red, .3);
      host.lose();
    }
  }

  int _nextSpot(Offset away) {
    var best = _spot;
    var bestD = -1.0;
    for (var i = 0; i < _spots.length; i++) {
      if (i == _spot) continue;
      final d = (_spots[i] - away).distance + rand(0, 160);
      if (d > bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  void _moveTo(int i) => _spot = i;

  void _dodge() {
    _dodges++;
    _giggle = .8;
    _hopT = rand(1.4, 2.0);
    _moveTo(_nextSpot(host.pointer));
    host.sfx(Sfx.whoosh, rate: 1.6);
    host.sfx(Sfx.boing, volume: .4, rate: 1.8);
    if (_dodges == 3) {
      host.fx.pop(host.tr('tired', 'TIRED!'), _spots[_spot] + const Offset(0, -24), color: Pal.sky, size: 18);
    }
  }

  void _spawnPop() {
    final w = rand(170, 220), h = rand(120, 150);
    final pos = Offset(rand(w / 2 + 8, 352 - w / 2), rand(160, 560 - h / 2));
    _pops.add(_Pop(Rect.fromCenter(center: pos, width: w, height: h), randInt(3), pick([Pal.pink, Pal.sky, Pal.lime, Pal.orange, Pal.purple])));
    host.sfx(Sfx.notify, rate: rand(.9, 1.2));
    host.shake(2);
  }

  @override
  void onDown(Offset p) {
    if (_won) return;
    // topmost popups block everything beneath
    for (var i = _pops.length - 1; i >= 0; i--) {
      final pop = _pops[i];
      if ((p - pop.close).distance < 20) {
        _pops.removeAt(i);
        host.sfx(Sfx.pop, rate: rand(1, 1.3));
        host.fx.burst(pop.rect.center, pop.color, count: 16, speed: 240, shape: PartShape.square);
        host.addScore(20, pop.close);
        return;
      }
      if (pop.rect.contains(p)) {
        pop.shake = 1;
        host.sfx(Sfx.tap, volume: .5);
        return;
      }
    }
    // the real X
    final d = (p - _x).distance;
    if (d < 20) {
      _win();
      return;
    }
    // fakes
    for (final f in _fakes) {
      if ((p - f.pos).distance < f.r + 8) {
        f.hit = 1;
        _lol = .9;
        _lolAt = f.pos;
        host.sfx(Sfx.buzzer, volume: .6);
        host.sfx(Sfx.notify, rate: 1.3);
        host.shake(4);
        _spawnPop();
        if (chance(.5)) _spawnPop();
        if (!_tired && d < 90) _dodge();
        return;
      }
    }
    // install button (lol)
    if (Rect.fromCenter(center: const Offset(180, 482), width: 220, height: 64).contains(p)) {
      _installPress = 1;
      _lol = .9;
      _lolAt = const Offset(180, 450);
      host.sfx(Sfx.cash, volume: .6);
      _spawnPop();
      return;
    }
    if (!_tired && d < 70) _dodge();
  }

  void _win() {
    _won = true;
    _winT = 0;
    _pops.clear();
    host.sfx(Sfx.explode);
    host.sfx(Sfx.fanfare, volume: .8);
    host.flash(Pal.white, .3);
    host.shake(10, .5);
    host.hitStop(.12);
    for (var i = 0; i < 6; i++) {
      host.fx.burst(Offset(rand(40, 320), rand(110, 540)), pick(Pal.candy), count: 18, speed: 320, shape: PartShape.square,
          colors: Pal.candy);
    }
    host.fx.ring(_x, Pal.white, size: 140, life: .5);
    host.win(stars: host.time < 6 && _dodges <= 2 ? 3 : (host.time < 10 ? 2 : 1));
  }

  @override
  void onKey(String key, bool down) {}

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFFFF2E88), Color(0xFF8A2BE2), Color(0xFF2A0A3A)]);
    D.rays(c, const Offset(180, 300), 600, const Color(0x22FFFF66), count: 20, t: _t * .6);
    for (var i = 0; i < 12; i++) {
      final y = (i * 61 + _t * 90) % 700 - 30;
      D.coin(c, Offset((i * 131) % 360.0, y), 9, spin: _t + i * .3);
    }
    if (_won) {
      _renderWin(c);
    } else {
      _renderMain(c);
      for (final p in _pops) {
        _renderPop(c, p);
      }
    }
    // popup counter / overload meter
    if (!_won) {
      for (var i = 0; i < 7; i++) {
        D.rrect(c, Rect.fromLTWH(96 + i * 24.0, 568, 20, 14), 4, i < _pops.length ? (i >= 4 ? Pal.red : Pal.orange) : const Color(0x44FFFFFF),
            border: Pal.ink, borderWidth: 2);
      }
      D.text(c, host.tr('danger', 'DANGER'), const Offset(180, 600), size: 14,
          color: _pops.length >= 5 && M.wave(_t, 4) > .5 ? Pal.red : const Color(0x88FFFFFF), stroke: Pal.ink);
    }
  }

  void _renderMain(Canvas c) {
    final r = _main;
    D.rrect(c, r.shift(const Offset(0, 8)), 16, const Color(0x66000000));
    D.rrect(c, r, 16, const Color(0xFFFFF4DC), border: Pal.ink, borderWidth: 4);
    // header
    D.rrect(c, Rect.fromLTWH(r.left, r.top, r.width, 34), 16, Pal.red);
    c.drawRect(Rect.fromLTWH(r.left, r.top + 18, r.width, 16), D.fill(Pal.red));
    for (var i = 0; i < 12; i++) {
      final on = ((i + (_t * 8).floor()) % 3) == 0;
      D.circle(c, Offset(r.left + 20 + i * 25.0, r.top + 17), 4, on ? Pal.yellow : const Color(0xFF9A1028));
    }
    // title
    c.save();
    c.translate(180, 180);
    c.rotate(sin(_t * 4) * .04);
    D.title(c, host.tr('sale', 'SALE'), Offset.zero, size: 52, color: Pal.yellow, scale: 1 + M.wave(_t, 2) * .06);
    c.restore();
    D.text(c, '-99%', const Offset(180, 232), size: 34, color: Pal.red, stroke: Pal.white, strokeWidth: 6);
    // product: treasure chest
    const cc = Offset(150, 330);
    D.shadow(c, cc + const Offset(0, 50), 150, 18);
    D.rrect(c, Rect.fromCenter(center: cc + const Offset(0, 18), width: 130, height: 64), 10, const Color(0xFFA0643A),
        border: Pal.ink, borderWidth: 3);
    D.rrect(c, Rect.fromCenter(center: cc + const Offset(0, -26), width: 130, height: 34), 14, const Color(0xFFC07A3C),
        border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < 5; i++) {
      D.gem(c, cc + Offset(-44 + i * 22.0, -12 - (i.isEven ? 10 : 0) + sin(_t * 3 + i) * 2), 11, Pal.candy[(i * 2) % 8]);
    }
    D.rrect(c, Rect.fromCenter(center: cc + const Offset(0, 14), width: 22, height: 26), 5, Pal.gold, border: Pal.ink, borderWidth: 2);
    for (var i = 0; i < 3; i++) {
      final a = _t * 2 + i * 2.1;
      c.drawPath(D.starPath(cc + Offset(cos(a) * 80, sin(a) * 40 - 20), 9, 2.5, points: 4, rotation: 0), D.fill(Pal.white));
    }
    // install button
    final s = 1 - _installPress * .08 + sin(_t * 7) * .03;
    c.save();
    c.translate(180, 482);
    c.scale(s);
    D.button(c, Rect.fromCenter(center: Offset.zero, width: 220, height: 60), host.tr('install', 'INSTALL'), color: Pal.green, fontSize: 26);
    c.restore();
    // the REAL x (drawn before the sticker so it can hide behind it)
    _renderRealX(c);
    // FREE sticker
    c.save();
    c.translate(_sticker.dx, _sticker.dy);
    c.rotate(_t * .8);
    c.drawPath(D.starPath(Offset.zero, 46, 36, points: 14), D.fill(Pal.yellow));
    c.drawPath(D.starPath(Offset.zero, 46, 36, points: 14), D.stroke(Pal.ink, 3));
    c.restore();
    D.text(c, host.tr('free', 'FREE'), _sticker, size: 20, color: Pal.red, stroke: Pal.white, strokeWidth: 4);
    // fake X buttons
    for (final f in _fakes) {
      final wob = 1 + sin(_t * 6 + f.pos.dx) * .08 + f.hit * .3;
      c.save();
      c.translate(f.pos.dx, f.pos.dy);
      c.scale(wob);
      c.rotate(f.hit * sin(_t * 30) * .3);
      D.circle(c, const Offset(0, 3), f.r, const Color(0x55000000));
      D.circle(c, Offset.zero, f.r, f.hit > 0 ? Pal.yellow : Pal.red, border: Pal.ink, borderWidth: 3);
      if (f.hit > 0) {
        D.face(c, Offset.zero, f.r * .9, Face.smug, blush: false);
      } else {
        D.line(c, Offset(-f.r * .4, -f.r * .4), Offset(f.r * .4, f.r * .4), Pal.white, f.r * .28);
        D.line(c, Offset(f.r * .4, -f.r * .4), Offset(-f.r * .4, f.r * .4), Pal.white, f.r * .28);
      }
      c.restore();
    }
    if (_lol > 0) {
      D.text(c, 'LOL', _lolAt + Offset(0, -30 - (1 - _lol) * 30), size: 26, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _renderRealX(Canvas c) {
    final p = _x;
    if (host.time > .4 && host.time < 1.6) {
      final k = (host.time - .4) / 1.2;
      c.drawCircle(p, 30 - k * 16, D.stroke(Color.fromRGBO(255, 255, 255, 1 - k), 3));
    }
    D.circle(c, p, 7.5, const Color(0xFFB0ACC0), border: const Color(0xFF6A6680), borderWidth: 1.5);
    D.line(c, p + const Offset(-2.5, -2.5), p + const Offset(2.5, 2.5), Pal.white, 1.6);
    D.line(c, p + const Offset(2.5, -2.5), p + const Offset(-2.5, 2.5), Pal.white, 1.6);
    // tiny legs while running
    if ((_x - _spots[_spot]).distance > 4) {
      final ph = sin(_t * 40) * 3;
      D.line(c, p + const Offset(-3, 7), p + Offset(-4 + ph, 12), Pal.ink, 1.5);
      D.line(c, p + const Offset(3, 7), p + Offset(4 - ph, 12), Pal.ink, 1.5);
    }
    if (_giggle > 0) {
      D.text(c, 'hehe', p + Offset(0, -16 - (1 - _giggle) * 10), size: 11, color: Pal.ink, stroke: Pal.white, strokeWidth: 3);
    }
    if (_tired) {
      final ph = (_t * 1.5) % 1;
      D.circle(c, p + Offset(9, -6 + ph * 8), 2.5 * (1 - ph) + .5, const Color(0xFF7FD3FF));
    }
  }

  void _renderPop(Canvas c, _Pop p) {
    final k = M.easeOutBack((p.age / .25).clamp(0, 1));
    final shake = p.shake > 0 ? sin(_t * 60) * 4 * p.shake : 0.0;
    p.shake = max(0, p.shake - .05);
    final r = p.rect;
    c.save();
    c.translate(r.center.dx + shake, r.center.dy);
    c.scale(k);
    c.translate(-r.center.dx, -r.center.dy);
    D.rrect(c, r.shift(const Offset(4, 6)), 10, const Color(0x66000000));
    D.rrect(c, r, 10, Pal.white, border: Pal.ink, borderWidth: 3);
    D.rrect(c, Rect.fromLTWH(r.left, r.top, r.width, 24), 10, p.color);
    c.drawRect(Rect.fromLTWH(r.left, r.top + 12, r.width, 12), D.fill(p.color));
    c.drawRect(Rect.fromLTWH(r.left, r.top + 24, r.width, 2), D.fill(Pal.ink));
    final ctr = r.center + const Offset(0, 12);
    switch (p.kind) {
      case 0:
        D.coin(c, ctr + const Offset(-40, 0), 20, spin: _t);
        D.text(c, host.tr('free', 'FREE'), ctr + const Offset(26, -10), size: 22, color: Pal.orange, stroke: Pal.ink);
        D.text(c, '\$\$\$', ctr + const Offset(26, 18), size: 18, color: Pal.green, stroke: Pal.ink);
      case 1:
        D.blob(c, ctr + const Offset(-44, 4), 24, Pal.pink, face: Face.love);
        D.text(c, host.tr('win', 'WIN!'), ctr + const Offset(26, 0), size: 28, color: Pal.pink, stroke: Pal.ink);
      default:
        D.gem(c, ctr + const Offset(-44, 0), 22, Pal.sky);
        D.text(c, '-90%', ctr + const Offset(28, 0), size: 26, color: Pal.red, stroke: Pal.ink);
    }
    // its (real) close button
    D.circle(c, p.close, 10, Pal.red, border: Pal.ink, borderWidth: 2);
    D.line(c, p.close + const Offset(-4, -4), p.close + const Offset(4, 4), Pal.white, 2.5);
    D.line(c, p.close + const Offset(4, -4), p.close + const Offset(-4, 4), Pal.white, 2.5);
    c.restore();
  }

  void _renderWin(Canvas c) {
    final t = _winT;
    // main ad shatters into pieces flying away
    if (t < .8) {
      final k = t / .8;
      for (var i = 0; i < 8; i++) {
        final col = i % 2 == 0 ? const Color(0xFFFFF4DC) : Pal.red;
        final ox = (i % 4) * 79.0 + 22, oy = (i ~/ 4) * 230.0 + 92;
        final dir = Offset((i % 4 - 1.5) * 160, (i ~/ 4 - .5) * 200 - 100);
        c.save();
        c.translate(ox + 40 + dir.dx * k, oy + 115 + dir.dy * k + 400 * k * k);
        c.rotate(k * (i.isEven ? 3 : -3));
        D.rrect(c, const Rect.fromLTWH(-40, -115, 79, 230), 6, col.withValues(alpha: 1 - k), border: Pal.ink.withValues(alpha: 1 - k));
        c.restore();
      }
    }
    // "Next ad" joke slides in
    if (t > .75) {
      final k = M.easeOutBack(((t - .75) / .3).clamp(0, 1));
      c.save();
      c.translate(180, 500 + (1 - k) * 300);
      D.rrect(c, const Rect.fromLTWH(-140, -50, 280, 100), 14, Pal.white, border: Pal.ink, borderWidth: 3);
      D.rrect(c, const Rect.fromLTWH(-140, -50, 280, 26), 14, Pal.purple);
      c.drawRect(const Rect.fromLTWH(-140, -34, 280, 10), D.fill(Pal.purple));
      D.text(c, '${host.tr('next', 'NEXT')} AD  2/99', const Offset(0, -37), size: 14, color: Pal.white);
      for (var i = 0; i < 8; i++) {
        final a = i / 8 * pi * 2 + t * 6;
        D.circle(c, Offset(cos(a) * 16, 12 + sin(a) * 16), 3.5, Color.fromRGBO(60, 60, 90, (i + 1) / 8));
      }
      c.restore();
    }
  }
}

class _Pop {
  _Pop(this.rect, this.kind, this.color);
  final Rect rect;
  final int kind;
  final Color color;
  double age = 0;
  double shake = 0;
  Offset get close => Offset(rect.right - 14, rect.top + 12);
}

class _Fake {
  _Fake(this.pos, this.r);
  final Offset pos;
  final double r;
  double hit = 0;
}
