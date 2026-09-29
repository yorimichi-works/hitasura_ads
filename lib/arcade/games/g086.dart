import '../engine/engine.dart';

/// No.086 Pixel Pinball — a tiny 8-bit table with an orange dot-matrix display.
///
/// Tap/hold the left or right half of the screen for the flippers. Pop
/// bumpers, slingshots, 3 rollover lanes (light all = multiplier up) and a
/// drop-target bank. Reach the target score. Swipe up to nudge... but not
/// too much: TILT!
bool _ascii(String s) {
  for (final u in s.codeUnits) {
    if (u > 126) return false;
  }
  return true;
}

void _px(Canvas c, String s, Offset pos, double scale, Color col, {int align = -1, Color? shadow}) {
  if (_ascii(s)) {
    PixelFont.draw(c, s.toUpperCase(), pos, scale, col, align: align, shadow: shadow);
  } else {
    D.text(c, s, Offset(pos.dx, pos.dy + 3.5 * scale), size: 8 * scale, color: col, stroke: shadow,
        strokeWidth: shadow == null ? 0 : scale * 1.4,
        anchor: align < 0 ? Alignment.centerLeft : (align == 0 ? Alignment.center : Alignment.centerRight));
  }
}

const _k = Color(0xFF000000);
const _white = Color(0xFFF8F8F8);
const _dmd = Color(0xFFFF8A1C);
const _pink = Color(0xFFF83CB8);
const _cyan = Color(0xFF3CE0F8);
const _yellow = Color(0xFFF8E040);

final _ballSprite = Sprite([
  '.WWW.',
  'WWLLG',
  'WLLGG',
  'LLGGD',
  '.GDD.',
], {
  'W': _white,
  'L': const Color(0xFFC8D0E0),
  'G': const Color(0xFF8890A8),
  'D': const Color(0xFF4C5068),
});

final _bumperSprite = Sprite([
  '....KKKKKK....',
  '..KKRRRRRRKK..',
  '.KRRWWWWWWRRK.',
  '.KRWWRRRRWWRK.',
  'KRWWRRRRRRWWRK',
  'KRWRRYYYYRRWRK',
  'KRWRRYYYYRRWRK',
  'KRWRRYYYYRRWRK',
  'KRWRRYYYYRRWRK',
  'KRWWRRRRRRWWRK',
  '.KRWWRRRRWWRK.',
  '.KRRWWWWWWRRK.',
  '..KKRRRRRRKK..',
  '....KKKKKK....',
], {'K': _k, 'R': const Color(0xFFD82060), 'W': _white, 'Y': _yellow});
final _bumperLit = Sprite([
  '....KKKKKK....',
  '..KKYYYYYYKK..',
  '.KYYWWWWWWYYK.',
  '.KYWWYYYYWWYK.',
  'KYWWYYYYYYWWYK',
  'KYWYYWWWWYYWYK',
  'KYWYYWWWWYYWYK',
  'KYWYYWWWWYYWYK',
  'KYWYYWWWWYYWYK',
  'KYWWYYYYYYWWYK',
  '.KYWWYYYYWWYK.',
  '.KYYWWWWWWYYK.',
  '..KKYYYYYYKK..',
  '....KKKKKK....',
], {'K': _k, 'Y': _yellow, 'W': _white});

final _flipperSprite = Sprite([
  '.KKKKKKKKKKKKKKKK..',
  'KWWWWWWWWWWWWWWWWK.',
  'KWRRRRRRRRRRRRRRRRK',
  'KWRRRRRRRRRRRRRRRDK',
  '.KDDDDDDDDDDDDDDDK.',
  '..KKKKKKKKKKKKKKK..',
], {'K': _k, 'W': _white, 'R': _cyan, 'D': const Color(0xFF1C7890)});

class _Seg {
  const _Seg(this.a, this.b, {this.kick = 0, this.id = 0});
  final Offset a, b;
  final double kick;
  final int id; // 1 left sling, 2 right sling
}

class _Bumper {
  _Bumper(this.p, this.r);
  final Offset p;
  final double r;
  double lit = 0;
}

class _Flipper {
  _Flipper(this.pivot, this.rest, this.up, this.sign);
  final Offset pivot;
  final double rest, up, sign;
  double angle = 0, omega = 0;
  bool held = false;
  static const len = 56.0;
  Offset get tip => pivot + Offset(cos(angle), sin(angle)) * len;
}

class _Pop {
  _Pop(this.s, this.x, this.y, this.col);
  final String s;
  final double x;
  double y;
  final Color col;
  double t = 0;
}

class G086 extends MiniGame {
  static const _target = 9000;
  static const _r = 7.5;
  final _segs = <_Seg>[];
  final _bumpers = [
    _Bumper(const Offset(118, 236), 21),
    _Bumper(const Offset(242, 236), 21),
    _Bumper(const Offset(180, 306), 21),
  ];
  late final _Flipper _lf = _Flipper(const Offset(104, 556), .5, -.45, 1);
  late final _Flipper _rf = _Flipper(const Offset(256, 556), pi - .5, pi + .45, -1);
  final _lanes = [false, false, false];
  final _targets = [true, true, true];
  double _targetsReset = 0;
  final _pops = <_Pop>[];
  final _trail = <Offset>[];
  Offset _bp = const Offset(326, 480);
  Offset _bv = Offset.zero;
  bool _ballLive = false;
  double _serveT = .4;
  int _balls = 2;
  double _saveT = 0;
  bool _saveUsed = false;
  bool _hot = false;
  double _heat = 0; // flipper coil heat: mashing overheats the flippers
  int _mult = 1;
  double _t = 0;
  String _dmdMsg = '';
  double _dmdT = 0;
  double _slingLit = 0, _slingLitR = 0;
  int _nudges = 0;
  double _nudgeDecay = 0;
  double _tilt = 0;
  Offset? _downAt;
  double _downTime = 0;
  bool _won = false;
  double _laneFlash = 0;

  @override
  void init() {
    _lf.angle = _lf.rest;
    _rf.angle = _rf.rest;
    // top arc (ellipse) from left wall to right wall
    const c = Offset(180, 212), rx = 164.0, ry = 112.0;
    Offset? prev;
    for (var i = 0; i <= 18; i++) {
      final a = pi + i / 18 * pi;
      final p = c + Offset(cos(a) * rx, sin(a) * ry);
      if (prev != null) _segs.add(_Seg(prev, p));
      prev = p;
    }
    _segs.addAll(const [
      _Seg(Offset(16, 212), Offset(16, 478)),
      _Seg(Offset(344, 212), Offset(344, 478)),
      // inlane guides down to the flipper pivots
      _Seg(Offset(16, 478), Offset(98, 548)),
      _Seg(Offset(344, 478), Offset(262, 548)),
      // slingshots
      _Seg(Offset(56, 408), Offset(56, 466)),
      _Seg(Offset(56, 466), Offset(88, 492)),
      _Seg(Offset(56, 408), Offset(88, 492), kick: 520, id: 1),
      _Seg(Offset(304, 408), Offset(304, 466)),
      _Seg(Offset(304, 466), Offset(272, 492)),
      _Seg(Offset(304, 408), Offset(272, 492), kick: 520, id: 2),
      // lane posts
      _Seg(Offset(105, 136), Offset(105, 160)),
      _Seg(Offset(155, 128), Offset(155, 160)),
      _Seg(Offset(205, 128), Offset(205, 160)),
      _Seg(Offset(255, 136), Offset(255, 160)),
    ]);
  }

  void _serve() {
    _bp = const Offset(326, 470);
    _bv = Offset(rand(-30, 0), -1050);
    _ballLive = true;
    // ball save only once per ball (a SAFE re-serve gets no second save)
    _saveT = _saveUsed ? 0 : 3;
    host.sfx(Sfx.pShoot, rate: .6);
    host.sfx(Sfx.whoosh, volume: .5);
    _trail.clear();
  }

  void _msg(String s) {
    _dmdMsg = s;
    _dmdT = 1.1;
  }

  void _score(int n, Offset at, [Color col = _white]) {
    final v = n * _mult;
    host.addScore(v);
    _pops.add(_Pop('$v', at.dx, at.dy - 10, col));
    if (!_won && host.score >= _target) {
      _won = true;
      _msg(host.tr('jackpot', 'JACKPOT'));
      host.sfx(Sfx.jingleWin);
      host.fx.confetti();
      host.flash(_yellow, .2);
      final left = host.timeLeft;
      host.win(stars: left > 8 ? 3 : (left > 3 ? 2 : 1));
    }
  }

  // ---------------------------------------------------------- physics ---

  void _collideSeg(Offset a, Offset b, double rad, double rest, {double kick = 0, int id = 0}) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    final ap = _bp - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / len2).clamp(0.0, 1.0);
    final q = a + ab * t;
    final d = _bp - q;
    final dist = d.distance;
    if (dist >= rad || dist < 1e-6) return;
    final n = d / dist;
    _bp = q + n * rad;
    final vn = _bv.dx * n.dx + _bv.dy * n.dy;
    if (vn < 0) {
      _bv -= n * (vn * (1 + rest));
      if (kick > 0 && vn < -40) {
        _bv += n * kick;
        host.sfx(Sfx.boing, volume: .6, rate: 1.3);
        host.shake(2);
        if (id == 1) _slingLit = 1;
        if (id == 2) _slingLitR = 1;
        _score(250, q);
      } else if (vn < -250) {
        host.sfx(Sfx.tick, volume: .3, rate: .8);
      }
    }
  }

  void _collideFlipper(_Flipper f) {
    final a = f.pivot, b = f.tip;
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    final ap = _bp - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / len2).clamp(0.0, 1.0);
    final q = a + ab * t;
    final d = _bp - q;
    final dist = d.distance;
    final rad = _r + 6 - t * 2;
    if (dist >= rad || dist < 1e-6) return;
    final n = d / dist;
    _bp = q + n * rad;
    final rq = q - a;
    final vs = Offset(-rq.dy, rq.dx) * f.omega;
    final rel = _bv - vs;
    final vn = rel.dx * n.dx + rel.dy * n.dy;
    if (vn < 0) {
      _bv -= n * (vn * 1.3);
      if (f.omega.abs() > 5 && -vn > 300) {
        host.sfx(Sfx.pHit, volume: .6, rate: .8);
      }
    }
  }

  void _collideBumper(_Bumper bm) {
    final d = _bp - bm.p;
    final dist = d.distance;
    final rad = bm.r + _r;
    if (dist >= rad || dist < 1e-6) return;
    final n = d / dist;
    _bp = bm.p + n * rad;
    final vn = _bv.dx * n.dx + _bv.dy * n.dy;
    _bv -= n * vn;
    _bv += n * 620;
    bm.lit = 1;
    host.sfx(Sfx.pHit, rate: 1.1 + rand(0, .3));
    host.shake(3);
    host.hitStop(.02);
    _score(800, bm.p, _yellow);
    host.fx.burst(bm.p + n * bm.r, _yellow, count: 6, speed: 180, size: 5, shape: PartShape.square, gravity: 0);
  }

  void _stepPhysics(double dt) {
    for (final f in [_lf, _rf]) {
      final target = (f.held && _tilt <= 0) ? f.up : f.rest;
      final old = f.angle;
      const sp = 24.0;
      if ((target - f.angle).abs() < sp * dt) {
        f.angle = target;
      } else {
        f.angle += (target - f.angle).sign * sp * dt;
      }
      f.omega = (f.angle - old) / dt;
    }
    if (!_ballLive) return;
    _bv = Offset(_bv.dx, _bv.dy + 820 * dt);
    final spd = _bv.distance;
    if (spd > 1300) _bv = _bv / spd * 1300;
    _bp += _bv * dt;
    for (final s in _segs) {
      _collideSeg(s.a, s.b, _r + 3, .45, kick: s.kick, id: s.id);
    }
    for (var i = 0; i < 3; i++) {
      if (_targets[i]) {
        final y = 282.0 + i * 24;
        final before = _bv;
        _collideSeg(Offset(24, y), Offset(24, y + 18), _r + 3, .3);
        if (before != _bv) _hitTarget(i);
      }
    }
    for (final b in _bumpers) {
      _collideBumper(b);
    }
    _collideFlipper(_lf);
    _collideFlipper(_rf);
    // rollover lanes
    if (_bp.dy > 132 && _bp.dy < 158) {
      for (var i = 0; i < 3; i++) {
        final lx = 180.0 + (i - 1) * 50;
        if ((_bp.dx - lx).abs() < 14) {
          if (!_lanes[i]) {
            _lanes[i] = true;
            host.sfx(Sfx.pCoin, rate: 1 + i * .15);
            _score(500, Offset(lx, 150), _cyan);
            if (_lanes.every((l) => l)) {
              _mult = min(5, _mult + 1);
              _laneFlash = 1.2;
              _lanes.fillRange(0, 3, false);
              _msg('${host.tr('bonus', 'BONUS')} x$_mult');
              host.sfx(Sfx.pPowerup);
              _score(2000, const Offset(180, 180), _pink);
            }
          }
        }
      }
    }
  }

  void _hitTarget(int i) {
    _targets[i] = false;
    host.sfx(Sfx.clang, volume: .6, rate: 1.2);
    _score(1500, Offset(40, 290.0 + i * 24), _pink);
    if (_targets.every((t) => !t)) {
      _msg(host.tr('jackpot', 'JACKPOT'));
      _score(3000, const Offset(80, 320), _yellow);
      host.sfx(Sfx.ssr, volume: .6);
      host.flash(_pink, .12);
      host.shake(6);
      _targetsReset = 2;
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _dmdT = max(0, _dmdT - dt);
    _slingLit = max(0, _slingLit - dt * 5);
    _slingLitR = max(0, _slingLitR - dt * 5);
    _laneFlash = max(0, _laneFlash - dt);
    _tilt = max(0, _tilt - dt);
    _heat = max(0, _heat - dt * .55);
    _saveT = max(0, _saveT - dt);
    _nudgeDecay += dt;
    if (_nudgeDecay > 2.5 && _nudges > 0) {
      _nudges--;
      _nudgeDecay = 0;
    }
    if (_targetsReset > 0) {
      _targetsReset -= dt;
      if (_targetsReset <= 0) _targets.fillRange(0, 3, true);
    }
    for (final b in _bumpers) {
      b.lit = max(0, b.lit - dt * 4);
    }
    for (var i = _pops.length - 1; i >= 0; i--) {
      final p = _pops[i];
      p.t += dt;
      p.y -= 40 * dt;
      if (p.t > .8) _pops.removeAt(i);
    }
    if (!_ballLive && !host.finished && _balls > 0) {
      _serveT -= dt;
      if (_serveT <= 0) _serve();
    }
    const steps = 8;
    for (var i = 0; i < steps; i++) {
      _stepPhysics(dt / steps);
    }
    if (_ballLive) {
      _trail.insert(0, _bp);
      if (_trail.length > 7) _trail.removeLast();
    }
    // drain
    if (_ballLive && _bp.dy > 660) {
      _ballLive = false;
      if (host.finished) return;
      if (_saveT > 0) {
        _saveUsed = true;
        _msg(host.tr('safe', 'SAFE'));
        host.sfx(Sfx.pPowerup, rate: .8);
        _serveT = .5;
      } else {
        _balls--;
        _saveUsed = false;
        host.sfx(Sfx.pDie);
        host.shake(8);
        host.flash(const Color(0xFFF83828), .15);
        _msg(host.tr('oops', 'OOPS'));
        if (_balls <= 0) {
          host.lose();
        } else {
          _serveT = 1.0;
        }
      }
    }
  }

  // ------------------------------------------------------------ input ---

  @override
  void onDown(Offset p) {
    _downAt = p;
    _downTime = _t;
    if (p.dx < 180) {
      _lf.held = true;
    } else {
      _rf.held = true;
    }
    if (_tilt <= 0) host.sfx(Sfx.flip, volume: .5);
    _heat += .3;
    if (_heat >= 1 && _tilt <= 0) {
      // coils overheat from mashing -> flippers go limp for a moment
      _heat = .4;
      _tilt = 1.4;
      _hot = true;
      _msg(host.tr('overheat', 'OVERHEAT'));
      host.sfx(Sfx.buzzer, volume: .7);
      host.fx.smoke(const Offset(180, 560), count: 6);
    }
  }

  @override
  void onMove(Offset p) {
    final d0 = _downAt;
    if (d0 == null) return;
    if (d0.dy - p.dy > 90 && _t - _downTime < .25) {
      _downAt = null;
      _nudge();
    }
  }

  @override
  void onUp(Offset p) {
    _lf.held = false;
    _rf.held = false;
    _downAt = null;
  }

  void _nudge() {
    _nudges++;
    _nudgeDecay = 0;
    host.shake(8, .3);
    host.sfx(Sfx.thud);
    if (_ballLive) _bv += Offset(rand(-120, 120), -170);
    if (_nudges >= 3) {
      // TILT: flippers die and the ball save is gone
      _tilt = 3;
      _hot = false;
      _saveT = 0;
      _nudges = 0;
      _msg('TILT');
      host.sfx(Sfx.buzzer);
      host.flash(const Color(0xFFF83828), .2);
    }
  }

  @override
  void onKey(String key, bool down) {
    if (key == 'left') _lf.held = down;
    if (key == 'right') _rf.held = down;
    if (key == 'action') {
      _lf.held = down;
      _rf.held = down;
    }
    if (key == 'up' && down) _nudge();
  }

  @override
  void onTimeUp() {
    if (host.score >= _target) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ----------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    // cabinet frame
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), Paint()..color = const Color(0xFF180C28));
    // playfield
    final field = Path()..moveTo(16, 640);
    field.lineTo(16, 212);
    const cc = Offset(180, 212), rx = 164.0, ry = 112.0;
    for (var i = 0; i <= 24; i++) {
      final a = pi + i / 24 * pi;
      field.lineTo(cc.dx + cos(a) * rx, cc.dy + sin(a) * ry);
    }
    field
      ..lineTo(344, 640)
      ..close();
    c.drawPath(
        field,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C1458), Color(0xFF1C1040), Color(0xFF301050)],
          ).createShader(const Rect.fromLTWH(0, 100, 360, 540)));
    c.save();
    c.clipPath(field);
    // pixel checker pattern
    final chk = Paint()..color = const Color(0x14FFFFFF);
    for (var y = 100.0; y < 640; y += 24) {
      for (var x = 16.0 + ((y / 24).floor().isEven ? 0 : 12); x < 344; x += 24) {
        c.drawRect(Rect.fromLTWH(x, y, 12, 12), chk);
      }
    }
    // inserts: arrows pointing to the lanes, light in sequence
    for (var i = 0; i < 5; i++) {
      final on = ((_t * 6).floor() % 5) == i;
      final y = 470.0 - i * 26;
      final p = Paint()..color = on ? _pink : const Color(0xFF4C2060);
      final tri = Path()
        ..moveTo(180, y - 10)
        ..lineTo(194, y + 6)
        ..lineTo(166, y + 6)
        ..close();
      c.drawPath(tri, p);
    }
    // multiplier lights
    for (var i = 0; i < 4; i++) {
      final lit = _mult >= i + 2;
      final r = Rect.fromLTWH(129 + i * 27.0, 380, 21, 15);
      c.drawRect(r, Paint()..color = lit ? _yellow : const Color(0xFF3C2450));
      _px(c, 'x${i + 2}', Offset(r.center.dx, r.top + 4), 1, lit ? _k : const Color(0xFF7C5C90), align: 0);
    }
    c.restore();

    // lanes lights
    for (var i = 0; i < 3; i++) {
      final lx = 180.0 + (i - 1) * 50;
      final lit = _lanes[i] || (_laneFlash > 0 && (_t * 10).floor().isEven);
      c.drawRect(Rect.fromCenter(center: Offset(lx, 172), width: 12, height: 12), Paint()..color = lit ? _cyan : const Color(0xFF1C4050));
      _px(c, const ['A', 'D', 'S'][i], Offset(lx, 138), 2, lit ? _cyan : const Color(0xFF3C6878), align: 0);
    }

    // walls
    final wallP = Paint()
      ..color = const Color(0xFF8C7CC8)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.square;
    final wallHi = Paint()
      ..color = const Color(0xFFD8D0F8)
      ..strokeWidth = 2;
    for (final s in _segs) {
      if (s.kick > 0) continue;
      c.drawLine(s.a, s.b, wallP);
      c.drawLine(s.a, s.b, wallHi);
    }
    // slingshots
    for (final side in [0, 1]) {
      final lit = side == 0 ? _slingLit : _slingLitR;
      final x0 = side == 0 ? 56.0 : 304.0, x1 = side == 0 ? 88.0 : 272.0;
      final tri = Path()
        ..moveTo(x0, 408)
        ..lineTo(x0, 466)
        ..lineTo(x1, 492)
        ..close();
      c.drawPath(tri, Paint()..color = Color.lerp(const Color(0xFF6C2C88), _white, lit)!);
      c.drawLine(Offset(x0, 408), Offset(x1, 492),
          Paint()
            ..color = lit > 0 ? _yellow : _pink
            ..strokeWidth = 5);
    }
    // drop targets
    for (var i = 0; i < 3; i++) {
      final y = 282.0 + i * 24;
      if (_targets[i]) {
        c.drawRect(Rect.fromLTWH(18, y, 9, 18), Paint()..color = _pink);
        c.drawRect(Rect.fromLTWH(18, y, 3, 18), Paint()..color = const Color(0xFFFCA8E0));
      } else {
        c.drawRect(Rect.fromLTWH(18, y + 6, 6, 6), Paint()..color = const Color(0xFF4C2060));
      }
    }
    // bumpers
    for (final b in _bumpers) {
      final s = b.lit > .3 ? _bumperLit : _bumperSprite;
      if (b.lit > 0) c.drawCircle(b.p, b.r + 10 * b.lit, Paint()..color = Color.fromRGBO(248, 224, 64, .35 * b.lit));
      s.drawCentered(c, b.p, scale: 3);
    }
    // flippers
    for (final f in [_lf, _rf]) {
      c.save();
      c.translate(f.pivot.dx, f.pivot.dy);
      c.rotate(f.angle);
      _flipperSprite.draw(c, const Offset(-6, -9), scale: 3, tint: _tilt > 0 ? const Color(0xFF605070) : null);
      c.restore();
      c.drawRect(Rect.fromCenter(center: f.pivot, width: 6, height: 6), Paint()..color = _white);
    }
    // ball save light
    if (_saveT > 0 && (_t * 6).floor().isEven) {
      _px(c, host.tr('safe', 'SAFE'), const Offset(180, 600), 2, _cyan, align: 0);
    }
    // ball
    if (_ballLive) {
      for (var i = 0; i < _trail.length; i++) {
        final a = (1 - i / _trail.length) * .3;
        c.drawRect(Rect.fromCenter(center: _trail[i], width: 12, height: 12), Paint()..color = Color.fromRGBO(200, 220, 255, a));
      }
      _ballSprite.drawCentered(c, Offset(_bp.dx.roundToDouble(), _bp.dy.roundToDouble()), scale: 3);
    }
    for (final p in _pops) {
      _px(c, p.s, Offset(p.x, p.y), 2, p.col, align: 0, shadow: _k);
    }
    // balls left
    for (var i = 0; i < _balls; i++) {
      _ballSprite.draw(c, Offset(330 - i * 18.0, 616), scale: 3);
    }

    _renderDmd(c);

    if (_heat > .35) {
      // coil heat gauge (mashing warning)
      final w = 60 * _heat.clamp(0.0, 1.0);
      c.drawRect(const Rect.fromLTWH(149, 603, 62, 8), D.fill(_k));
      c.drawRect(Rect.fromLTWH(150, 604, w, 6), D.fill(_heat > .7 ? const Color(0xFFF83828) : _dmd));
    }
    if (_tilt > 0 && (_t * 8).floor().isEven) {
      _px(c, _hot ? 'HOT!' : 'TILT', const Offset(180, 330), 7, const Color(0xFFF83828), align: 0, shadow: _k);
    }
    if (host.time < 2.4 && !host.finished) {
      D.hand(c, const Offset(80, 590), _t);
      D.hand(c, const Offset(280, 590), _t + .5);
      _px(c, host.tr('tap', 'TAP'), const Offset(70, 540), 2, _white, align: 0, shadow: _k);
      _px(c, host.tr('tap', 'TAP'), const Offset(290, 540), 2, _white, align: 0, shadow: _k);
    }
    Retro.scanlines(c, alpha: .12);
    Retro.vignette(c, strength: .35);
  }

  void _renderDmd(Canvas c) {
    const r = Rect.fromLTWH(8, 40, 344, 58);
    c.drawRect(r.inflate(3), Paint()..color = const Color(0xFF3C3C48));
    c.drawRect(r, Paint()..color = const Color(0xFF140800));
    // unlit dots
    final dim = Paint()..color = const Color(0xFF2A1404);
    for (var y = r.top + 1; y < r.bottom; y += 3) {
      c.drawRect(Rect.fromLTWH(r.left, y, r.width, 1), dim);
    }
    if (_dmdT > 0) {
      final flash = (_dmdT * 8).floor().isEven;
      _px(c, _dmdMsg, Offset(180, r.top + 11), 5, flash ? _dmd : const Color(0xFFFFC080), align: 0);
    } else {
      _px(c, M.big(host.score).padLeft(6, ' '), Offset(r.left + 14, r.top + 8), 4, _dmd);
      _px(c, '/${M.big(_target)}', Offset(r.right - 10, r.top + 8), 2, const Color(0xFFB85C10), align: 1);
      if (_mult > 1) _px(c, 'x$_mult', Offset(r.right - 10, r.top + 26), 2, _dmd, align: 1);
      // progress bar
      final prog = (host.score / _target).clamp(0.0, 1.0);
      for (var i = 0; i < 40; i++) {
        final on = i / 40 < prog;
        c.drawRect(Rect.fromLTWH(r.left + 14 + i * 8.0, r.top + 44, 6, 6),
            Paint()..color = on ? _dmd : const Color(0xFF3A1C06));
      }
    }
    // dot-matrix grid overlay
    final grid = Paint()..color = const Color(0x88140800);
    for (var x = r.left; x < r.right; x += 3) {
      c.drawRect(Rect.fromLTWH(x, r.top, 1, r.height), grid);
    }
    for (var y = r.top; y < r.bottom; y += 3) {
      c.drawRect(Rect.fromLTWH(r.left, y, r.width, 1), grid);
    }
  }
}
