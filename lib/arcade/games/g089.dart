import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.089 Hop Across — 8-bit frog crossing.
///
/// Tap to hop forward, swipe (or tap beside / below the frog) to hop
/// sideways or back. Dodge cars & trucks, ride logs and turtles (they dive!),
/// and land on an empty lily pad. Two frogs home => win. 3 lives.
class G089 extends MiniGame {
  static const _cols = 9;
  static const _cw = 40.0;
  static const _rh = 56.0;
  static const _y0 = 108.0;
  static const _homeXs = [60.0, 180.0, 300.0];

  final List<_Lane> _lanes = [];
  double _t = 0;
  // frog
  double _fx = 180;
  int _row = 0;
  int _dir = 0; // 0 up 1 right 2 down 3 left
  bool _hopping = false;
  double _hopT = 0, _hx0 = 180, _hx1 = 180;
  int _hr0 = 0, _hr1 = 0;
  int? _queued;
  int _maxRow = 0;
  // death
  double _deadT = 0;
  String _deadKind = '';
  Offset _deadAt = Offset.zero;
  int _lives = 3;
  final List<bool> _filled = [false, false, false];
  int _homes = 0;
  double _homeFlash = 0;
  // input
  Offset? _downAt;
  final _pops = _Pops();
  ui.Picture? _bg;

  static double rowY(int r) => _y0 + (8 - r) * _rh + _rh / 2;

  @override
  void init() {
    final s = host.speed;
    _lanes
      ..add(_Lane(1, -70 * s, _K.car, 48, [0, 190, 390]))
      ..add(_Lane(2, 52 * s, _K.truck, 90, [40, 330]))
      ..add(_Lane(3, -125 * s, _K.racer, 45, [80, 380]))
      ..add(_Lane(5, 42 * s, _K.log, 126, [0, 210, 410]))
      ..add(_Lane(6, -58 * s, _K.turtle, 108, [30, 230, 430]))
      ..add(_Lane(7, 64 * s, _K.log, 150, [60, 330]));
    _lanes[4].diveGroup = 1;
    _respawn();
  }

  void _respawn() {
    _fx = 180;
    _row = 0;
    _dir = 0;
    _hopping = false;
    _queued = null;
    _maxRow = 0;
  }

  // --------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) => _downAt = p;

  @override
  void onUp(Offset p) {
    final a = _downAt;
    _downAt = null;
    if (a == null) return;
    final d = p - a;
    int dir;
    if (d.distance > 22) {
      dir = d.dx.abs() > d.dy.abs() ? (d.dx > 0 ? 1 : 3) : (d.dy > 0 ? 2 : 0);
    } else {
      final fy = rowY(_row);
      final rel = p - Offset(_fx, fy);
      if (rel.dy > 44 && rel.dy.abs() > rel.dx.abs()) {
        dir = 2;
      } else if (rel.dy.abs() < 44 && rel.dx.abs() > 34) {
        dir = rel.dx > 0 ? 1 : 3;
      } else {
        dir = 0;
      }
    }
    _request(dir);
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    const m = {'up': 0, 'action': 0, 'right': 1, 'down': 2, 'left': 3};
    final d = m[key];
    if (d != null) _request(d);
  }

  void _request(int dir) {
    if (_deadT > 0 || host.finished) return;
    if (_hopping) {
      _queued = dir;
      return;
    }
    _hop(dir);
  }

  void _hop(int dir) {
    var nr = _row, nx = _fx;
    switch (dir) {
      case 0:
        nr++;
      case 2:
        nr--;
      case 1:
        nx += _cw;
      case 3:
        nx -= _cw;
    }
    _dir = dir;
    if (nr < 0 || nr > 8) return;
    nx = nx.clamp(20.0, 340.0);
    // snap to column grid on solid rows
    if (dir == 0 || dir == 2) {
      if (!_isRiver(nr)) nx = ((nx - 20) / _cw).roundToDouble() * _cw + 20;
    }
    _hopping = true;
    _hopT = 0;
    _hx0 = _fx;
    _hx1 = nx;
    _hr0 = _row;
    _hr1 = nr;
    host.sfx(Sfx.pJump, volume: .55, rate: 1 + nr * .03);
  }

  bool _isRiver(int r) => r >= 5 && r <= 7;

  // -------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    _pops.update(dt);
    _homeFlash = max(0, _homeFlash - dt);
    for (final l in _lanes) {
      l.update(dt, _t);
    }
    if (_deadT > 0) {
      _deadT -= dt;
      if (_deadT <= 0 && !host.finished) {
        if (_lives <= 0) {
          host.lose();
        } else {
          _respawn();
        }
      }
      return;
    }
    if (host.finished && _homes < 2) return;
    if (_hopping) {
      _hopT += dt / .13;
      // ride while hopping from a river row
      if (_isRiver(_hr0) && _hr0 == _hr1) {
        final l = _laneAt(_hr0);
        if (l != null) {
          _hx0 += l.v * dt;
          _hx1 += l.v * dt;
        }
      }
      if (_hopT >= 1) {
        _hopping = false;
        _fx = _hx1;
        _row = _hr1;
        _land();
        if (_queued != null && _deadT <= 0 && !host.finished) {
          final q = _queued!;
          _queued = null;
          _hop(q);
        }
      } else {
        _fx = M.lerp(_hx0, _hx1, _hopT);
      }
      return;
    }
    _checkStanding(dt);
  }

  _Lane? _laneAt(int r) {
    for (final l in _lanes) {
      if (l.row == r) return l;
    }
    return null;
  }

  void _land() {
    if (_row == 8) {
      var best = -1;
      for (var i = 0; i < 3; i++) {
        if ((_homeXs[i] - _fx).abs() < 36 && !_filled[i]) best = i;
      }
      if (best < 0) {
        _die('bonk');
        return;
      }
      _filled[best] = true;
      _homes++;
      _fx = _homeXs[best];
      _homeFlash = .6;
      final at = Offset(_fx, rowY(8));
      host.sfx(Sfx.pPowerup);
      host.sfx(Sfx.pCoin, rate: 1.2);
      host.addScore(500, at);
      host.fx.burst(at, Pal.lime, count: 24, speed: 260, shape: PartShape.square, size: 6, colors: const [Pal.lime, Pal.yellow, Pal.white]);
      host.fx.ring(at, Pal.yellow, size: 70);
      host.shake(4);
      _pops.add(host.tr('goal', 'GOAL!'), at - const Offset(0, 40), Pal.yellow, 4);
      if (_homes >= 2) {
        host.fx.confetti();
        host.sfx(Sfx.jingleWin, volume: .8);
        host.win(stars: _lives >= 3 ? 3 : (_lives == 2 ? 2 : 1));
      } else {
        _respawnSoon();
      }
      return;
    }
    if (_row > _maxRow) {
      _maxRow = _row;
      host.addScore(10);
    }
    _checkStanding(0);
  }

  void _respawnSoon() {
    // brief pause at home then new frog
    _deadT = .55;
    _deadKind = 'home';
  }

  void _checkStanding(double dt) {
    final l = _laneAt(_row);
    if (l == null) return;
    if (_isRiver(_row)) {
      final o = l.objectUnder(_fx, 8, _t);
      if (o == null) {
        _die('splash');
        return;
      }
      _fx += l.v * dt;
      if (_fx < 6 || _fx > 354) _die('splash');
    } else {
      if (l.objectUnder(_fx, -8, _t) != null) _die('squash');
    }
  }

  void _die(String kind) {
    if (_deadT > 0 || host.finished) return;
    _deadKind = kind;
    _deadT = .95;
    _lives--;
    _hopping = false;
    _deadAt = Offset(_fx, rowY(_row));
    host.shake(kind == 'squash' ? 9 : 5);
    host.hitStop(.08);
    switch (kind) {
      case 'squash':
        host.sfx(Sfx.squish);
        host.sfx(Sfx.pDie, volume: .8);
        host.flash(Pal.red, .1);
        _pops.add(host.tr('splat', 'SPLAT!'), _deadAt - const Offset(0, 36), Pal.red, 4);
        host.fx.burst(_deadAt, const Color(0xFF4CC43A), count: 14, speed: 200, shape: PartShape.square, size: 5);
      case 'splash':
        host.sfx(Sfx.splash);
        host.sfx(Sfx.pDie, volume: .7);
        _pops.add(host.tr('splash', 'SPLASH!'), _deadAt - const Offset(0, 36), const Color(0xFF8FD8FF), 4);
        host.fx.burst(_deadAt, const Color(0xFFCFF4FF), count: 16, speed: 180, shape: PartShape.square, size: 5);
      default:
        host.sfx(Sfx.boing);
        host.sfx(Sfx.pDie, volume: .7);
        _pops.add(host.tr('bonk', 'BONK!'), _deadAt - const Offset(0, 36), Pal.orange, 4);
    }
  }

  // -------------------------------------------------------------- render ---
  @override
  void render(Canvas c) {
    c.drawPicture(_bg ??= _buildBg());
    _drawWater(c);
    // lily pads
    for (var i = 0; i < 3; i++) {
      final p = Offset(_homeXs[i], rowY(8) + 4);
      _S.pad.drawCentered(c, p, scale: 3);
      if (_filled[i]) {
        final b = (_homeFlash > 0 && i == _filled.lastIndexOf(true)) ? -sin(_homeFlash * 20).abs() * 6 : 0.0;
        _S.frogHome.drawCentered(c, p + Offset(0, -4 + b), scale: 3);
      } else if ((_t * 2).floor().isEven) {
        // blinking target arrow
        _S.chev.drawCentered(c, p + const Offset(0, -2), scale: 2, opacity: .7);
      }
    }
    for (final l in _lanes) {
      _drawLane(c, l);
    }
    _drawFrog(c);
    _drawHud(c);
    _pops.render(c);
    Retro.scanlines(c, alpha: .1);
  }

  void _drawWater(Canvas c) {
    final top = rowY(7) - _rh / 2;
    final hi = Paint()..color = const Color(0xFF4FA8F0);
    for (var r = 0; r < 3; r++) {
      final y = top + r * _rh;
      for (var i = 0; i < 9; i++) {
        final x = ((i * 47 + r * 23 + _t * (r.isEven ? 14 : -18)) % 380) - 10;
        c.drawRect(Rect.fromLTWH(x.roundToDouble(), y + 14 + (i % 3) * 13, 12, 3), hi);
      }
    }
    // home inlets shimmer
    for (final hx in _homeXs) {
      c.drawRect(Rect.fromLTWH(hx - 26 + ((_t * 10).floor() % 4) * 3, rowY(8) + 18, 8, 3), hi);
    }
  }

  void _drawLane(Canvas c, _Lane l) {
    final y = rowY(l.row);
    for (var i = 0; i < l.xs.length; i++) {
      final x = l.xs[i].roundToDouble();
      switch (l.kind) {
        case _K.car:
          _S.car.draw(c, Offset(x, y - 12), scale: 3, flipX: l.v > 0);
          if ((_t * 8).floor().isEven) c.drawRect(Rect.fromLTWH(l.v < 0 ? x + 48 : x - 6, y - 3, 6, 6), Paint()..color = const Color(0x55CCCCCC));
        case _K.truck:
          _S.truck.draw(c, Offset(x, y - 15), scale: 3, flipX: l.v < 0);
        case _K.racer:
          _S.racer.draw(c, Offset(x, y - 11), scale: 3, flipX: l.v > 0);
          // speed lines
          final sl = Paint()..color = const Color(0x88FFFFFF);
          for (var k = 0; k < 3; k++) {
            c.drawRect(Rect.fromLTWH(x + 50 + k * 10.0 + ((_t * 40) % 6), y - 8 + k * 7, 8, 2), sl);
          }
        case _K.log:
          _drawLog(c, x, y, l.w);
        case _K.turtle:
          final dive = l.diveGroup == i ? l.diveAmount(_t) : 0.0;
          for (var k = 0; k < 3; k++) {
            final tx = x + k * 36 + 18;
            final spr = dive > .66 ? null : (dive > .2 ? _S.turtleDive : ((_t * 4 + k).floor().isEven ? _S.turtle : _S.turtle2));
            if (spr != null) spr.drawCentered(c, Offset(tx, y), scale: 3, flipX: l.v > 0);
            if (dive > .5) {
              c.drawOval(Rect.fromCenter(center: Offset(tx, y), width: 30, height: 10),
                  Paint()
                    ..color = const Color(0x99CFF4FF)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2);
            }
          }
      }
    }
  }

  void _drawLog(Canvas c, double x, double y, double w) {
    final bark = Paint()..color = const Color(0xFF8A5A2B);
    final dark = Paint()..color = const Color(0xFF5E3A18);
    final light = Paint()..color = const Color(0xFFB27C44);
    final ring = Paint()..color = const Color(0xFFE2B77A);
    c.drawRect(Rect.fromLTWH(x + 6, y - 15, w - 12, 30), bark);
    c.drawRect(Rect.fromLTWH(x + 6, y - 15, w - 12, 5), light);
    c.drawRect(Rect.fromLTWH(x + 6, y + 10, w - 12, 5), dark);
    for (var k = x + 18; k < x + w - 20; k += 24) {
      c.drawRect(Rect.fromLTWH(k, y - 6, 12, 3), dark);
      c.drawRect(Rect.fromLTWH(k + 8, y + 3, 9, 3), dark);
    }
    // end caps
    c.drawRect(Rect.fromLTWH(x, y - 12, 9, 24), ring);
    c.drawRect(Rect.fromLTWH(x + 3, y - 3, 3, 6), dark);
    c.drawRect(Rect.fromLTWH(x + w - 9, y - 12, 9, 24), ring);
    c.drawRect(Rect.fromLTWH(x + w - 6, y - 3, 3, 6), dark);
  }

  void _drawFrog(Canvas c) {
    if (_deadT > 0) {
      final p = _deadAt;
      switch (_deadKind) {
        case 'squash':
          _S.splat.drawCentered(c, p, scale: 3);
        case 'splash':
          final k = 1 - _deadT / .95;
          for (var i = 0; i < 3; i++) {
            final r = (k * 40 + i * 10) % 40;
            c.drawOval(Rect.fromCenter(center: p, width: r * 2, height: r),
                Paint()
                  ..color = const Color(0xCCFFFFFF)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3);
          }
          if (k < .35) _S.frog.drawCentered(c, p + Offset(0, k * 30), scale: 3, tint: const Color(0xFF3F7FCF), opacity: 1 - k * 2);
        case 'bonk':
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(_t * 12);
          _S.frog.drawCentered(c, Offset.zero, scale: 3, tint: (_t * 10).floor().isEven ? Pal.white : null);
          c.restore();
          for (var i = 0; i < 3; i++) {
            final a = _t * 5 + i * 2.1;
            _S.star.drawCentered(c, p + Offset(cos(a) * 20, sin(a) * 8 - 22), scale: 2);
          }
        default:
          break;
      }
      return;
    }
    if (host.finished && _homes >= 2) return;
    double y;
    double lift = 0;
    if (_hopping) {
      y = M.lerp(rowY(_hr0), rowY(_hr1), _hopT);
      lift = sin(_hopT * pi) * 10;
    } else {
      y = rowY(_row);
    }
    final p = Offset(_fx, y - lift);
    D.shadow(c, Offset(_fx, y + 12), 26, 8, .3);
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(_dir * pi / 2);
    final spr = _hopping ? _S.frogJump : _S.frog;
    final s = _hopping ? 3.0 + sin(_hopT * pi) * .4 : 3.0;
    spr.drawCentered(c, Offset.zero, scale: s);
    c.restore();
    // tutorial
    if (host.time < 2.2 && _row == 0 && _homes == 0) {
      D.hand(c, Offset(_fx + 40, y - 110), _t);
      D.arrow(c, Offset(_fx, y - 58), const Offset(0, -1), 34, Pal.yellow, width: 9);
    }
  }

  void _drawHud(Canvas c) {
    // lives
    for (var i = 0; i < 3; i++) {
      final alive = i < _lives;
      _S.heart.draw(c, Offset(12.0 + i * 30, 50), scale: 3, tint: alive ? null : const Color(0xFF3A2A40));
    }
    // homes goal 0/2
    PixelFont.draw(c, '$_homes/2', const Offset(348, 54), 3, _homes > 0 ? Pal.lime : Pal.white,
        align: 1, shadow: const Color(0xFF10122A));
    _S.frogHome.draw(c, const Offset(250, 48), scale: 2);
  }

  ui.Picture _buildBg() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    Paint p(int col) => Paint()..color = Color(col);
    // top hedge / sky strip
    c.drawRect(const Rect.fromLTWH(0, 0, 360, _y0), p(0xFF1B2A4A));
    for (var x = 0.0; x < 360; x += 4) {
      final h = 16 + sin(x * .08) * 6 + ((x ~/ 4) % 3) * 2;
      c.drawRect(Rect.fromLTWH(x, _y0 - h, 4, h), p(0xFF1E5A30));
    }
    for (var x = 0.0; x < 360; x += 24) {
      c.drawRect(Rect.fromLTWH(x + 6, _y0 - 14, 4, 4), p(0xFF3FA84A));
    }
    // home row: grass bank with inlets
    final hy = _y0;
    c.drawRect(const Rect.fromLTWH(0, _y0, 360, _rh), p(0xFF2E8B3A));
    for (var x = 0.0; x < 360; x += 8) {
      c.drawRect(Rect.fromLTWH(x, hy + ((x ~/ 8) % 3) * 12 + 4, 4, 4), p(0xFF3FAF4A));
    }
    for (final hx in _homeXs) {
      c.drawRect(Rect.fromLTWH(hx - 30, hy + 6, 60, _rh - 6), p(0xFF1F5FB8));
      c.drawRect(Rect.fromLTWH(hx - 30, hy + 6, 60, 4), p(0xFF17488C));
    }
    // river
    final riverTop = rowY(7) - _rh / 2;
    c.drawRect(Rect.fromLTWH(0, riverTop, 360, _rh * 3), p(0xFF1F5FB8));
    for (var r = 0; r < 3; r++) {
      c.drawRect(Rect.fromLTWH(0, riverTop + r * _rh, 360, 3), p(0xFF2A70CC));
    }
    // median
    final medTop = rowY(4) - _rh / 2;
    c.drawRect(Rect.fromLTWH(0, medTop, 360, _rh), p(0xFF7B4FB8));
    for (var x = 0.0; x < 360; x += 8) {
      c.drawRect(Rect.fromLTWH(x, medTop + ((x ~/ 8) % 4) * 12 + 5, 4, 4), p(0xFF9A6FD8));
    }
    for (var x = 12.0; x < 360; x += 56) {
      _S.flower.draw(c, Offset(x, medTop + 16 + (x % 3) * 6), scale: 3);
    }
    c.drawRect(Rect.fromLTWH(0, medTop, 360, 4), p(0xFF5A3A8C));
    c.drawRect(Rect.fromLTWH(0, medTop + _rh - 4, 360, 4), p(0xFF5A3A8C));
    // road
    final roadTop = rowY(3) - _rh / 2;
    c.drawRect(Rect.fromLTWH(0, roadTop, 360, _rh * 3), p(0xFF2A2A36));
    for (var x = 0.0; x < 360; x += 8) {
      for (var r = 0; r < 3; r++) {
        if (((x ~/ 8) * 7 + r * 5) % 11 == 0) c.drawRect(Rect.fromLTWH(x, roadTop + r * _rh + 20, 4, 4), p(0xFF34343F));
      }
    }
    for (var r = 1; r < 3; r++) {
      for (var x = 0.0; x < 360; x += 32) {
        c.drawRect(Rect.fromLTWH(x + 4, roadTop + r * _rh - 2, 18, 4), p(0xFFE8D24A));
      }
    }
    // start sidewalk
    final stTop = rowY(0) - _rh / 2;
    c.drawRect(Rect.fromLTWH(0, stTop, 360, 640 - stTop), p(0xFF7B4FB8));
    for (var x = 0.0; x < 360; x += 20) {
      c.drawRect(Rect.fromLTWH(x, stTop, 18, _rh - 2), p(0xFF8E62C8));
      c.drawRect(Rect.fromLTWH(x, stTop, 18, 3), p(0xFFA37ADA));
    }
    c.drawRect(Rect.fromLTWH(0, stTop + _rh, 360, 640 - stTop - _rh), p(0xFF1E5A30));
    // column guides (subtle)
    for (var i = 0; i <= _cols; i++) {
      c.drawRect(Rect.fromLTWH(i * _cw, stTop + _rh - 3, 2, 3), p(0xFF5A3A8C));
    }
    return rec.endRecording();
  }
}

enum _K { car, truck, racer, log, turtle }

class _Lane {
  _Lane(this.row, this.v, this.kind, this.w, List<double> xs) : xs = List.of(xs);
  final int row;
  final double v;
  final _K kind;
  final double w;
  final List<double> xs;
  int diveGroup = -1;
  static const _period = 600.0;

  void update(double dt, double t) {
    for (var i = 0; i < xs.length; i++) {
      var x = xs[i] + v * dt;
      if (x > 420) x -= _period;
      if (x < 420 - _period) x += _period;
      xs[i] = x;
    }
  }

  /// 0 = surfaced, 1 = fully under water. Cycle ~3.2 s.
  double diveAmount(double t) {
    final ph = (t / 3.2) % 1;
    if (ph < .55) return 0;
    if (ph < .68) return (ph - .55) / .13;
    if (ph < .85) return 1;
    return 1 - (ph - .85) / .15;
  }

  /// Object index under x (with [pad] tolerance; negative shrinks the box).
  int? objectUnder(double x, double pad, double t) {
    for (var i = 0; i < xs.length; i++) {
      if (i == diveGroup && diveAmount(t) > .66) continue;
      if (x >= xs[i] - pad && x <= xs[i] + w + pad) return i;
    }
    return null;
  }
}

class _Pops {
  final List<(String, Offset, Color, double, double)> _l = [];
  void add(String s, Offset at, Color col, [double scale = 3]) {
    if (_l.length < 8) _l.add((s, at, col, scale, 0));
  }

  void update(double dt) {
    for (var i = _l.length - 1; i >= 0; i--) {
      final e = _l[i];
      if (e.$5 + dt > 1.0) {
        _l.removeAt(i);
      } else {
        _l[i] = (e.$1, e.$2 - Offset(0, 30 * dt), e.$3, e.$4, e.$5 + dt);
      }
    }
  }

  void render(Canvas c) {
    for (final e in _l) {
      if (e.$5 > .75 && ((e.$5 * 20).floor().isEven)) continue;
      _pt(c, e.$1, e.$2, e.$5 < .08 ? e.$4 + 1 : e.$4, e.$3);
    }
  }
}

final _asciiRe = RegExp(r"^[A-Za-z0-9 !?.,:\-+/%$*<>=#'()]*$");

void _pt(Canvas c, String s, Offset center, double scale, Color col) {
  if (_asciiRe.hasMatch(s)) {
    PixelFont.draw(c, s, center - Offset(0, 3.5 * scale), scale, col, align: 0, shadow: const Color(0xFF10122A));
  } else {
    D.text(c, s, center, size: 8 * scale, color: col, stroke: const Color(0xFF10122A), strokeWidth: scale * 1.5);
  }
}

abstract final class _S {
  static const _k = Color(0xFF10122A);
  static const _fp = <String, Color>{
    'G': Color(0xFF4CC43A),
    'g': Color(0xFF257A2A),
    'Y': Color(0xFFB8F04A),
    'W': Color(0xFFFFFFFF),
    'K': _k,
    'P': Color(0xFFFF6FA0),
  };
  static final frog = Sprite(const [
    '..ggg...ggg..',
    '.gWWKg.gKWWg.',
    '.gWKKgGgKKWg.',
    '..gGGGGGGGg..',
    '.gGGYGGGYGGg.',
    'gGGGGGGGGGGGg',
    'Gg.GGYYYGG.gG',
    'g..gGGGGGg..g',
    '...gGGGGGg...',
    '..gGg...gGg..',
    '.gGg.....gGg.',
    'gg.........gg',
  ], _fp);
  static final frogJump = Sprite(const [
    'g...ggg.ggg...g',
    'Gg.gWWKgKWWg.gG',
    '.GggWKKGKKWggG.',
    '...gGGGGGGGg...',
    '..gGGYGGGYGGg..',
    '..GGGGGGGGGGG..',
    '...GGYYYYYGG...',
    '...gGGGGGGGg...',
    '....gGGGGGg....',
    '....gG...Gg....',
    '....gG...Gg....',
    '....gG...Gg....',
    '...gGg...gGg...',
    '...gg.....gg...',
  ], _fp);
  static final frogHome = Sprite(const [
    '.ggg...ggg.',
    'gWWKg.gKWWg',
    'gWKKgggKKWg',
    '.gGGGGGGGg.',
    'gGGPGGGPGGg',
    'gGGGKKKGGGg',
    '.gGGGGGGGg.',
  ], _fp);
  static final splat = Sprite(const [
    '..G.....g....G',
    'G.gGG.GGGG.gG.',
    '.GGGGGGGGGGGGg',
    'gGKGGGGGGGKGG.',
    '.GGGGGYYGGGGGG',
    'G.gGGGGGGGGg.G',
    '..G..gGGg...G.',
  ], _fp);

  static const _cp = <String, Color>{
    'K': _k,
    'R': Color(0xFFE8453C),
    'r': Color(0xFFA02A24),
    'C': Color(0xFF8FD8FF),
    'Y': Color(0xFFFFE14A),
    'W': Color(0xFFFFFFFF),
    'B': Color(0xFF3F7FE8),
    'b': Color(0xFF274F9C),
    'O': Color(0xFFFF9A2A),
    'G': Color(0xFFB0B8C8),
    'g': Color(0xFF6A7088),
  };
  // car facing LEFT
  static final car = Sprite(const [
    '..KK.......KK...',
    '.KrrRRRRRRRRrrK.',
    'KYRRCCRRRRRCRRrK',
    'KRRRCCRWWRRCRRRK',
    'KRRRCCRWWRRCRRRK',
    'KYRRCCRRRRRCRRrK',
    '.KrrRRRRRRRRrrK.',
    '..KK.......KK...',
  ], _cp);
  // truck facing RIGHT
  static final truck = Sprite(const [
    '..KKK......KKK.......KKK...',
    '.GGGGGGGGGGGGGGGGGGG.bBBBK.',
    '.GgGgGgGgGgGgGgGgGgG.BBCBBK',
    '.GGGGGGGGGGGGGGGGGGGKBBCCBY',
    '.GGGGGGGGGGGGGGGGGGGKBBCCBK',
    '.GGGGGGGGGGGGGGGGGGGKBBCCBK',
    '.GgGgGgGgGgGgGgGgGgG.BBCBBY',
    '.GGGGGGGGGGGGGGGGGGG.bBBBK.',
    '..KKK......KKK.......KKK...',
  ], _cp);
  // racer facing LEFT
  static final racer = Sprite(const [
    '.KK.......KK...',
    'KKK.OOOOO.KKK..',
    '.YOOOOCCOOOOOOK',
    'OOOWWOCCOWWWOOK',
    '.YOOOOCCOOOOOOK',
    'KKK.OOOOO.KKK..',
    '.KK.......KK...',
  ], _cp);

  static const _tp = <String, Color>{
    'S': Color(0xFFD84A3A),
    's': Color(0xFF8C2A20),
    'H': Color(0xFF6FCB4A),
    'F': Color(0xFF4A9A3A),
    'K': _k,
  };
  static final turtle = Sprite(const [
    '..F.....F...',
    '...SSSSS....',
    '..SsSSsSS...',
    'HKSsSSsSSs..',
    'HHSSsSSsSSST',
    '..SsSSsSS...',
    '...SSSSS....',
    '..F.....F...',
  ], _tp);
  static final turtle2 = Sprite(const [
    '.F.......F..',
    '...SSSSS....',
    '..SsSSsSS...',
    'HKSsSSsSSs..',
    'HHSSsSSsSSST',
    '..SsSSsSS...',
    '...SSSSS....',
    '.F.......F..',
  ], _tp);
  static final turtleDive = Sprite(const [
    '............',
    '...sssss....',
    '..sSssSss...',
    '..ssSSssSs..',
    '..sSssSsss..',
    '..ssSSsss...',
    '...sssss....',
    '............',
  ], _tp);

  static final pad = Sprite(const [
    '...GGGG..GGG...',
    '.GGGGGGG.GGGGG.',
    'GGGgGGGG.GGgGGG',
    'GGGGgGGGGGgGGGG',
    'GGGGGgGGGgGGGGG',
    'GGGGGGgGgGGGGGG',
    '.GGGGGGGGGGGGG.',
    '...GGGGGGGGG...',
  ], const {'G': Color(0xFF4FBF4A), 'g': Color(0xFF2E8B3A)});
  static final chev = Sprite(const [
    'Y.....Y',
    'YY...YY',
    '.YY.YY.',
    '..YYY..',
    '...Y...',
  ], const {'Y': Color(0xFFFFE14A)});
  static final heart = Sprite(const [
    '.KK.KK.',
    'KRRKRRK',
    'KRWRRRK',
    'KRRRRRK',
    '.KRRRK.',
    '..KRK..',
    '...K...',
  ], const {'K': _k, 'R': Color(0xFFFF3B5C), 'W': Color(0xFFFFFFFF)});
  static final star = Sprite(const [
    '..Y..',
    '.YYY.',
    'YYYYY',
    '.Y.Y.',
  ], const {'Y': Color(0xFFFFE14A)});
  static final flower = Sprite(const [
    '.P.',
    'PYP',
    '.P.',
  ], const {'P': Color(0xFFFF8FD0), 'Y': Color(0xFFFFE14A)});
}
