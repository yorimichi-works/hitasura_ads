import '../engine/engine.dart';

/// No.139 Wind Archery — hold to draw, drag to aim, release to shoot.
/// Your breath sways the sight; the wind pushes the arrow. 3 arrows, 24+ wins.
class G139 extends MiniGame {
  static const _bot = bool.fromEnvironment('ARCADE_BOT');
  static const _tc = Offset(180, 300); // target center (world space)
  static const _tr = 84.0; // target radius (10 rings)
  static const _ring = _tr / 10;
  static const _windPx = 9.0; // drift per m/s (= one ring)
  static const _arrows = 3;
  static const _need = 24;

  _Ph _ph = _Ph.ready;
  double _pt = 0;
  double _t = 0;
  Offset _aim = _tc;
  Offset? _last;
  double _draw = 0; // 0..1 bow tension
  double _hold = 0; // seconds held
  double _wind = 0;
  double _windShow = 0;
  final List<int> _scores = [];
  final List<Offset> _hits = [];
  // flight
  Offset _from = const Offset(200, 640);
  Offset _impact = _tc;
  Offset _aimAtRelease = _tc;
  double _ft = 0;
  double _fDur = .55;
  bool _weak = false;
  double _slow = 1;
  double _zoom = 1;
  double _wobble = 0;
  double _banner = 0;
  String _bannerText = '';
  Color _bannerColor = Pal.yellow;
  double _cheer = 0;
  Offset _fc = _tc;
  final List<_Cloud> _clouds = [];

  int get _total => _scores.fold(0, (a, b) => a + b);

  @override
  void init() {
    for (var i = 0; i < 5; i++) {
      _clouds.add(_Cloud(rand(0, 360), rand(56, 150), rand(.6, 1.2)));
    }
    _newWind();
  }

  void _newWind() {
    final s = rand(1.0, 3.4) * (.8 + .2 * host.speed);
    _wind = (chance(.5) ? -1 : 1) * (s * 2).round() / 2;
  }

  Offset get _sway {
    // breathing Lissajous; steadies while you hold the draw, then fatigue
    double amp;
    if (_ph != _Ph.draw) {
      amp = 16;
    } else if (_hold < .9) {
      amp = M.lerp(16, 3, _hold / .9);
    } else if (_hold < 2.4) {
      amp = 3;
    } else {
      amp = 3 + (_hold - 2.4) * 16;
    }
    amp *= host.speed;
    final tt = _t;
    return Offset(sin(tt * 1.7) * cos(tt * .63), sin(tt * 2.3 + 1) * .8) * amp +
        (amp > 14 ? Offset(sin(tt * 37), cos(tt * 41)) * (amp - 14) * .15 : Offset.zero);
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _pt += dt;
    _windShow = M.approach(_windShow, _wind, 4, dt);
    _wobble = M.approach(_wobble, 0, 5, dt);
    _banner = max(0, _banner - dt);
    _cheer = M.approach(_cheer, 0, 1.2, dt);
    _fc = M.approachO(_fc, _ph == _Ph.fly || _ph == _Ph.result ? Offset.lerp(_tc, _impact, .6)! : _tc, 5, dt);
    for (final cl in _clouds) {
      cl.x += _windShow * 7 * cl.s * dt;
      if (cl.x > 420) cl.x -= 480;
      if (cl.x < -60) cl.x += 480;
    }
    switch (_ph) {
      case _Ph.ready:
        if (_bot && _pt > .3) {
          _ph = _Ph.draw;
          _hold = 0;
          _draw = 0;
          _aim = _tc - Offset(_wind * _windPx, 0);
        }
        _zoom = M.approach(_zoom, 1, 5, dt);
      case _Ph.draw:
        _hold += dt;
        _draw = min(1, _draw + dt / .45);
        _zoom = M.approach(_zoom, 1.3, 4, dt);
        if (_hold > 2.4 && (_hold * 4).floor() != ((_hold - dt) * 4).floor()) host.sfx(Sfx.heartbeat, volume: .5);
        if (_bot && _hold > 1.4) _release();
        if (_hold > 5) {
          host.fx.pop(host.tr('oops', 'OOPS'), const Offset(180, 470), color: Pal.orange);
          _release();
        }
      case _Ph.fly:
        final sdt = dt * _slow;
        _ft += sdt / _fDur;
        if (_ft > .6 && _slow == 1 && !_weak && (_impact - _tc).distance < _ring * 2) _slow = .3;
        _zoom = M.approach(_zoom, _weak ? 1 : 1.7, 3, dt);
        if (_ft >= 1) _hit();
      case _Ph.result:
        _zoom = M.approach(_zoom, 1.75, 2, dt);
        _slow = 1;
        if (_pt > 1.1) _nextArrow();
    }
  }

  void _release() {
    final sway = _sway;
    _ph = _Ph.fly;
    _pt = 0;
    _ft = 0;
    _last = null;
    _weak = _draw < .6;
    _aimAtRelease = _aim + sway;
    final drift = Offset(_wind * _windPx, 0);
    _impact = _weak
        ? Offset(_aimAtRelease.dx + drift.dx * .5, 470)
        : _aimAtRelease + drift + Offset(rand(-1.5, 1.5), rand(-1.5, 1.5));
    _fDur = _weak ? .45 : .55;
    _from = const Offset(196, 600);
    host.sfx(Sfx.arrow);
    host.sfx(Sfx.whoosh, volume: .5, rate: 1.4);
    host.shake(2);
    _draw = 0;
    _hold = 0;
  }

  void _hit() {
    _ph = _Ph.result;
    _pt = 0;
    final d = (_impact - _tc).distance;
    var s = _weak ? 0 : (d < _tr ? 10 - (d / _ring).floor() : 0);
    s = s.clamp(0, 10);
    _scores.add(s);
    if (s > 0) _hits.add(_impact);
    if (_weak) {
      host.sfx(Sfx.thud, volume: .6);
      host.sfx(Sfx.oops);
      host.fx.smoke(_screen(_impact), count: 5, color: const Color(0xCC9C7B4B));
      _say(host.tr('oops', 'OOPS'), Pal.orange);
      return;
    }
    final at = _screen(_impact);
    if (s == 0) {
      host.sfx(Sfx.thud);
      host.sfx(Sfx.aww, volume: .7);
      _say(host.tr('miss', 'MISS'), Pal.gray);
    } else {
      _wobble = 1;
      host.sfx(Sfx.thud);
      host.sfx(Sfx.stamp, volume: .6);
      host.shake(s >= 9 ? 8 : 4);
      host.fx.burst(at, s >= 9 ? Pal.gold : Pal.white, count: 8 + s * 2, speed: 160 + s * 20, size: 5);
      host.fx.ring(at, Pal.white, size: 40 + s * 4);
      if (s == 10) {
        host.hitStop(.12);
        host.flash(Pal.yellow, .15);
        host.sfx(Sfx.perfect);
        host.sfx(Sfx.cheer);
        _cheer = 1;
        host.fx.burst(at, Pal.gold, count: 20, speed: 320, shape: PartShape.star);
        _say(d < _ring * .5 ? 'X  10' : host.tr('perfect', 'PERFECT!'), Pal.yellow);
      } else if (s >= 8) {
        host.sfx(Sfx.correct);
        _cheer = .6;
        _say(host.tr('great', 'GREAT!'), Pal.lime);
      } else {
        host.sfx(Sfx.pop);
        _say(host.tr('good', 'GOOD'), Pal.sky);
      }
      host.addScore(s * 10);
    }
    host.fx.pop('$s', at + const Offset(0, -26), color: s >= 9 ? Pal.yellow : Pal.white, size: 34, life: 1);
  }

  void _say(String s, Color c) {
    _bannerText = s;
    _bannerColor = c;
    _banner = 1.1;
  }

  void _nextArrow() {
    if (host.finished) return;
    final left = _arrows - _scores.length;
    if (left == 0) {
      _finish();
      return;
    }
    if (_total + left * 10 < _need) {
      _finish();
      return;
    }
    _ph = _Ph.ready;
    _pt = 0;
    _newWind();
    host.sfx(Sfx.wind, volume: .5);
  }

  void _finish() {
    if (host.finished) return;
    if (_total >= _need) {
      host.fx.confetti(count: 80);
      host.sfx(Sfx.cheer);
      host.win(stars: _total >= 28 ? 3 : (_total >= 26 ? 2 : 1));
    } else {
      host.sfx(Sfx.aww);
      host.lose();
    }
  }

  @override
  void onTimeUp() => _finish();

  // ------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    if (_bot) return;
    if (_ph != _Ph.ready) return;
    _ph = _Ph.draw;
    _pt = 0;
    _hold = 0;
    _draw = 0;
    _last = p;
    host.sfx(Sfx.rip, volume: .35, rate: .7);
  }

  @override
  void onMove(Offset p) {
    if (_bot) return;
    final l = _last;
    if (_ph != _Ph.draw || l == null) return;
    _aim += (p - l) * (.7 / _zoom);
    _aim = Offset(_aim.dx.clamp(40, 320), _aim.dy.clamp(150, 460));
    _last = p;
  }

  @override
  void onUp(Offset p) {
    if (_bot) return;
    if (_ph == _Ph.draw) _release();
  }

  @override
  void onKey(String key, bool down) {
    if (_bot) return;
    if (!down) {
      if (key == 'action' && _ph == _Ph.draw) _release();
      return;
    }
    if (key == 'action' && _ph == _Ph.ready) {
      onDown(Offset.zero);
      _last = null;
      return;
    }
    const step = 4.0;
    final d = switch (key) {
      'left' => const Offset(-step, 0),
      'right' => const Offset(step, 0),
      'up' => const Offset(0, -step),
      'down' => const Offset(0, step),
      _ => Offset.zero,
    };
    _aim += d;
  }

  // ------------------------------------------------------------ render ---
  Offset _screen(Offset w) {
    final f = _focus;
    return f + (w - f) * _zoom;
  }

  Offset get _focus => _fc;

  @override
  void render(Canvas c) {
    // world (zoomable)
    final f = _focus;
    c.save();
    c.translate(f.dx, f.dy);
    c.scale(_zoom);
    c.translate(-f.dx, -f.dy);
    _world(c);
    c.restore();

    // bow + hands (screen space, foreground)
    if (_ph == _Ph.draw || _ph == _Ph.ready) _bow(c);
    if (_ph == _Ph.fly) _flyingArrow(c);

    _hud(c);
    if (_ph == _Ph.draw || _ph == _Ph.ready) _reticle(c);
    if (_scores.isEmpty && (_ph == _Ph.ready || _ph == _Ph.draw && _hold < 1.2)) {
      if (_ph == _Ph.ready) {
        D.hand(c, const Offset(180, 520), _t);
        D.text(c, host.tr('hold', 'HOLD'), const Offset(180, 470), size: 26, color: Pal.yellow, stroke: Pal.ink);
      } else {
        D.text(c, host.tr('drag', 'DRAG'), const Offset(180, 470), size: 22, color: Pal.white, stroke: Pal.ink);
      }
    }
    if (_slow < 1) {
      c.drawRect(const Rect.fromLTWH(0, 600, 360, 40), D.fill(Pal.night));
      D.circle(c, const Offset(24, 620), 6, Pal.red);
      D.text(c, 'x0.3', const Offset(52, 620), size: 14, color: Pal.white);
    }
  }

  void _world(Canvas c) {
    // sky & scenery (drawn a bit beyond the screen so zoom never shows edges)
    D.gradientBg(c, const [Color(0xFF58B7FF), Color(0xFFA9DEFF), Color(0xFFE6F6FF)],
        rect: const Rect.fromLTWH(-100, -100, 560, 380));
    c.drawCircle(const Offset(300, 90), 26, D.fill(const Color(0xFFFFF3B0)));
    c.drawCircle(const Offset(300, 90), 38, D.fill(const Color(0x33FFF3B0)));
    for (final cl in _clouds) {
      D.cloud(c, Offset(cl.x, cl.y), 46 * cl.s, color: const Color(0xEEFFFFFF));
    }
    // mountains
    final m = Path()..moveTo(-100, 260);
    for (var i = 0; i <= 12; i++) {
      final x = -100 + i * 50.0;
      m.lineTo(x, 200 + (i.isEven ? 0 : 38) + (i % 3) * 8);
    }
    m
      ..lineTo(460, 280)
      ..lineTo(-100, 280)
      ..close();
    c.drawPath(m, D.fill(const Color(0xFF8FB5D9)));
    // tree line
    for (var i = 0; i < 22; i++) {
      final x = -100 + i * 26.0;
      c.drawCircle(Offset(x, 252 + (i % 3) * 3), 18, D.fill(i.isEven ? const Color(0xFF2F8F52) : const Color(0xFF3AA35E)));
    }
    // grass field with lanes
    D.gradientBg(c, const [Color(0xFF6CCB5F), Color(0xFF3E9E48)], rect: const Rect.fromLTWH(-100, 262, 560, 480));
    for (var i = -6; i <= 6; i++) {
      c.drawLine(Offset(180 + i * 22.0, 262), Offset(180 + i * 150.0, 700), D.stroke(const Color(0x22FFFFFF), 3));
    }
    for (var i = 0; i < 6; i++) {
      final y = 262 + 400 * pow(i / 6, 1.8).toDouble();
      c.drawLine(Offset(-100, y), Offset(460, y), D.stroke(const Color(0x14FFFFFF), 2));
    }
    // windsocks
    _flag(c, const Offset(46, 380), 1.0);
    _flag(c, const Offset(316, 346), .8);
    // spectators behind rope
    for (var i = 0; i < 9; i++) {
      final x = -10.0 + i * 16 + (i > 4 ? 250 : 0);
      final j = _cheer * 8 * M.wave(_t + i * .3, 3);
      D.person(c, Offset(x, 300 - j), 26, Pal.candy[i % 8], face: _cheer > .3 ? Face.happy : Face.neutral, armsUp: _cheer);
    }
    // target stand
    final stand = D.stroke(const Color(0xFF8A5A3C), 7);
    c.drawLine(const Offset(140, 390), const Offset(160, 300), stand);
    c.drawLine(const Offset(220, 390), const Offset(200, 300), stand);
    D.shadow(c, const Offset(180, 392), 130, 14, .25);
    // target face (with wobble)
    c.save();
    c.translate(_tc.dx, _tc.dy);
    c.rotate(sin(_t * 40) * _wobble * .04);
    c.drawCircle(const Offset(0, 4), _tr + 8, D.fill(const Color(0xFFD9C08A)));
    c.drawCircle(Offset.zero, _tr + 8, D.fill(const Color(0xFFF1DDAA)));
    const cols = [
      Color(0xFFF7F7F7), Color(0xFFF7F7F7), Color(0xFF26262E), Color(0xFF26262E), Color(0xFF3FA9F5),
      Color(0xFF3FA9F5), Color(0xFFEF3B45), Color(0xFFEF3B45), Color(0xFFFFD23F), Color(0xFFFFD23F),
    ];
    for (var i = 0; i < 10; i++) {
      final r = _tr - i * _ring;
      c.drawCircle(Offset.zero, r, D.fill(cols[i]));
      c.drawCircle(Offset.zero, r, D.stroke(i == 2 || i == 3 ? const Color(0x55FFFFFF) : const Color(0x55000000), 1));
    }
    c.drawLine(const Offset(-3, 0), const Offset(3, 0), D.stroke(Pal.ink, 1));
    c.drawLine(const Offset(0, -3), const Offset(0, 3), D.stroke(Pal.ink, 1));
    c.restore();
    // stuck arrows
    for (final h in _hits) {
      final n = h + const Offset(5, 7);
      D.line(c, h, n, const Color(0xFF6B4A2A), 2.5);
      c.drawPath(
          Path()
            ..moveTo(n.dx, n.dy)
            ..lineTo(n.dx + 6, n.dy - 1)
            ..lineTo(n.dx + 2, n.dy + 5)
            ..close(),
          D.fill(Pal.pink));
      c.drawCircle(h, 1.8, D.fill(Pal.ink));
    }
  }

  void _flag(Canvas c, Offset base, double s) {
    final top = base + Offset(0, -110 * s);
    D.line(c, base, top, const Color(0xFFDDDDDD), 4 * s);
    final w = _windShow / 3.5;
    final dir = w.sign == 0 ? 1.0 : w.sign;
    final lift = w.abs().clamp(0.0, 1.0); // 0 = hanging, 1 = horizontal
    final len = 44 * s;
    final path = Path()..moveTo(top.dx, top.dy);
    for (var i = 0; i <= 6; i++) {
      final k = i / 6;
      final ang = (pi / 2) * (1 - lift) * .9;
      final x = top.dx + dir * cos(ang) * len * k;
      final y = top.dy + sin(ang) * len * k + sin(_t * (6 + lift * 10) - k * 5) * 4 * k * s;
      path.lineTo(x, y);
    }
    for (var i = 6; i >= 0; i--) {
      final k = i / 6;
      final ang = (pi / 2) * (1 - lift) * .9;
      final x = top.dx + dir * cos(ang) * len * k;
      final y = top.dy + sin(ang) * len * k + 16 * s * (1 - k * .7) + sin(_t * (6 + lift * 10) - k * 5) * 4 * k * s;
      path.lineTo(x, y);
    }
    c.drawPath(path..close(), D.fill(Pal.orange));
    c.drawPath(path, D.stroke(Pal.ink, 1.5));
  }

  void _reticle(Canvas c) {
    final p = _screen(_aim + _sway);
    final col = _ph == _Ph.draw && _hold > .9 && _hold < 2.4 ? Pal.lime : Pal.white;
    final st = D.stroke(Pal.ink, 5);
    final sw = D.stroke(col, 2.5);
    for (final paint in [st, sw]) {
      c.drawCircle(p, 18, paint);
      c.drawLine(p + const Offset(-30, 0), p + const Offset(-8, 0), paint);
      c.drawLine(p + const Offset(8, 0), p + const Offset(30, 0), paint);
      c.drawLine(p + const Offset(0, -30), p + const Offset(0, -8), paint);
      c.drawLine(p + const Offset(0, 8), p + const Offset(0, 30), paint);
    }
    // wind ticks: one tick = 1 m/s of drift
    final tick = _windPx * _zoom;
    for (var i = -4; i <= 4; i++) {
      if (i == 0) continue;
      c.drawLine(p + Offset(i * tick, -3), p + Offset(i * tick, 3), D.stroke(col.withValues(alpha: .8), 1.5));
    }
    c.drawCircle(p, 2.5, D.fill(Pal.red));
    // first arrow: show where the wind will carry it
    if (_scores.isEmpty && _ph == _Ph.draw) {
      final q = p + Offset(_wind * tick, 0);
      c.drawCircle(q, 4 + M.wave(_t, 3) * 2, D.stroke(Pal.yellow, 2));
      D.line(c, p, q, const Color(0x88FFD23F), 2);
    }
    // draw strength meter
    if (_ph == _Ph.draw) {
      D.bar(c, Rect.fromLTWH(p.dx - 28, p.dy + 40, 56, 8), _draw, _draw >= .6 ? Pal.lime : Pal.orange);
    }
  }

  void _bow(Canvas c) {
    final k = _ph == _Ph.draw ? M.easeOut(_draw) : 0.0;
    final sway = _sway * .6;
    final cx = 196 + sway.dx;
    final cy = 560 + sway.dy;
    // limbs
    final limb = Path()
      ..moveTo(cx - 6, cy - 150)
      ..quadraticBezierTo(cx + 34 + k * 8, cy - 40, cx + 6, cy + 20)
      ..quadraticBezierTo(cx + 34 + k * 8, cy + 100, cx - 6, cy + 190);
    c.drawPath(limb, D.stroke(Pal.ink, 13));
    c.drawPath(limb, D.stroke(const Color(0xFF3B3F58), 8));
    c.drawPath(limb, D.stroke(const Color(0xFF7C84B8), 2));
    // string pulled back toward the viewer (down-left)
    final nock = Offset(cx - 10 - k * 40, cy + 20 + k * 70);
    D.line(c, Offset(cx - 6, cy - 150), nock, const Color(0xEEFFFFFF), 2);
    D.line(c, Offset(cx - 6, cy + 190), nock, const Color(0xEEFFFFFF), 2);
    // arrow shaft
    D.line(c, nock, Offset(cx + 14, cy - 10), const Color(0xFF6B4A2A), 5);
    c.drawPath(
        Path()
          ..moveTo(cx + 14, cy - 22)
          ..lineTo(cx + 22, cy - 6)
          ..lineTo(cx + 8, cy - 6)
          ..close(),
        D.fill(const Color(0xFFB0B8C8)));
    c.drawPath(
        Path()
          ..moveTo(nock.dx, nock.dy)
          ..lineTo(nock.dx - 12, nock.dy - 14)
          ..lineTo(nock.dx + 6, nock.dy - 8)
          ..close(),
        D.fill(Pal.pink));
    // grip hand
    D.circle(c, Offset(cx + 10, cy + 20), 16, Pal.skin, border: Pal.ink, borderWidth: 3);
    // draw hand
    D.circle(c, nock + const Offset(-6, 6), 15, Pal.skin, border: Pal.ink, borderWidth: 3);
    if (_ph == _Ph.draw && _hold > 2.4) {
      D.text(c, host.tr('shaky', 'SHAKY!'), Offset(cx - 60, cy - 60), size: 16, color: Pal.red, stroke: Pal.ink);
    }
  }

  void _flyingArrow(Canvas c) {
    final t = M.clamp01(_ft);
    final e = 1 - pow(1 - t, 1.6).toDouble();
    final drift = Offset(_wind * _windPx * t * t, 0);
    final straight = _impact - Offset(_wind * _windPx, 0);
    final wp = Offset.lerp(_from, straight, e)! + drift - Offset(0, 50 * sin(pi * t) * (1 - t));
    final p = _screen(wp);
    final s = M.lerp(1.4, .25, e) * _zoom;
    final e2 = 1 - pow(1 - M.clamp01(t + .05), 1.6).toDouble();
    final ahead = _screen(Offset.lerp(_from, straight, e2)! + Offset(_wind * _windPx * (t + .05) * (t + .05), 0));
    var dir = ahead - p;
    if (dir.distance < .01) dir = const Offset(0, -1);
    final u = dir / dir.distance;
    final tail = p - u * 60 * s;
    D.line(c, p, tail, const Color(0xFF6B4A2A), 5 * s + 1);
    c.drawCircle(p, 3 * s + 1, D.fill(const Color(0xFFB0B8C8)));
    final n = Offset(-u.dy, u.dx);
    c.drawPath(
        Path()
          ..moveTo(tail.dx, tail.dy)
          ..lineTo(tail.dx - u.dx * 14 * s + n.dx * 8 * s, tail.dy - u.dy * 14 * s + n.dy * 8 * s)
          ..lineTo(tail.dx + u.dx * 6 * s, tail.dy + u.dy * 6 * s)
          ..lineTo(tail.dx - u.dx * 14 * s - n.dx * 8 * s, tail.dy - u.dy * 14 * s - n.dy * 8 * s)
          ..close(),
        D.fill(Pal.pink));
    // speed lines
    for (var i = 0; i < 3; i++) {
      final q = tail - u * (10 + i * 16) * s + n * (i - 1) * 6 * s;
      D.line(c, q, q - u * 20 * s, const Color(0x66FFFFFF), 2);
    }
  }

  void _hud(Canvas c) {
    // score slots
    D.rrect(c, const Rect.fromLTWH(10, 40, 200, 40), 10, const Color(0xE6121530), border: Pal.white, borderWidth: 2);
    for (var i = 0; i < _arrows; i++) {
      final r = Rect.fromLTWH(18 + i * 44.0, 46, 38, 28);
      final has = i < _scores.length;
      D.rrect(c, r, 7, has ? (_scores[i] >= 9 ? Pal.gold : Pal.white) : const Color(0x22FFFFFF));
      if (has) D.text(c, '${_scores[i]}', r.center, size: 18, color: Pal.ink);
    }
    D.text(c, '$_total', const Offset(172, 56), size: 22, color: _total >= _need ? Pal.lime : Pal.yellow);
    D.text(c, '/$_need', const Offset(174, 72), size: 11, color: const Color(0xCCFFFFFF));
    // wind indicator
    D.rrect(c, const Rect.fromLTWH(220, 40, 130, 40), 10, const Color(0xE6121530), border: Pal.white, borderWidth: 2);
    final w = _windShow;
    final dir = Offset(w.sign == 0 ? 1 : w.sign, 0);
    D.arrow(c, const Offset(254, 60), dir, 18 + w.abs() * 9, Pal.sky, width: 8);
    D.text(c, w.abs().toStringAsFixed(1), const Offset(314, 56), size: 18, color: Pal.white);
    D.text(c, 'm/s', const Offset(314, 72), size: 10, color: const Color(0xCCFFFFFF));
    if (_banner > 0) {
      final a = 1.1 - _banner;
      final s = a < .2 ? M.easeOutBack(a / .2) : 1.0;
      c.save();
      c.translate(180, 520);
      c.rotate(-.06);
      c.scale(s);
      D.title(c, _bannerText, Offset.zero, size: 46, color: _bannerColor);
      c.restore();
    }
  }
}

enum _Ph { ready, draw, fly, result }

class _Cloud {
  _Cloud(this.x, this.y, this.s);
  double x;
  final double y;
  final double s;
}
