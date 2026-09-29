import '../engine/engine.dart';

/// No.090 Pixel Kart GP — SNES-style pseudo-3D kart racer.
///
/// The road is rendered segment-by-segment (OutRun technique) into 4px
/// "scanline" rows so everything looks chunky and low-res. Hold / drag left
/// or right of center to steer, auto-accelerate, hit the chevron boost pads,
/// don't bump rivals from behind, stay off the grass. Finish the lap in the
/// top 3 => win (1st = 3 stars).
class G090 extends MiniGame {
  static const _segL = 100.0;
  static const _roadW = 520.0; // half width (world)
  static const _camH = 900.0;
  static const _f = 200.0; // focal (px)
  static const _hor = 236.0; // horizon screen y
  static const _drawN = 110;
  static const _pd = 560.0; // player distance in front of camera
  static const _px = 4.0; // chunky pixel size
  static const _maxV = 5000.0, _boostV = 7400.0, _offV = 2500.0;

  final List<_Seg> _segs = [];
  late double _len;
  double _t = 0;
  double _z = 0, _v = 0, _x = 0, _steer = 0;
  double _boost = 0, _bump = 0, _skyOff = 0, _offT = 0;
  bool _finished = false;
  int _place = 6, _lastPlace = 6;
  double _placePop = 0;
  final List<_Kart> _rivals = [];
  final List<(double, double)> _pads = []; // (segment index, lane x)
  final _pops = _Pops();
  bool _keyL = false, _keyR = false;
  double _sfxT = 0;
  // projection scratch
  final _pX1 = List<double>.filled(_drawN, 0), _pX2 = List<double>.filled(_drawN, 0);
  final _pY1 = List<double>.filled(_drawN, 0), _pY2 = List<double>.filled(_drawN, 0);
  final _pS1 = List<double>.filled(_drawN, 0), _pS2 = List<double>.filled(_drawN, 0);
  final _pClip = List<double>.filled(_drawN, 0);
  final _pVis = List<bool>.filled(_drawN, false);

  // ----------------------------------------------------------- track ---
  void _add(int enter, int hold, int leave, double curve, double hill) {
    final startY = _segs.isEmpty ? 0.0 : _segs.last.y;
    final endY = startY + hill;
    final total = enter + hold + leave;
    for (var i = 0; i < total; i++) {
      double c;
      if (i < enter) {
        c = M.easeInOut(i / enter) * curve;
      } else if (i < enter + hold) {
        c = curve;
      } else {
        c = (1 - M.easeInOut((i - enter - hold) / max(1, leave))) * curve;
      }
      final y = startY + (endY - startY) * M.easeInOut((i + 1) / total);
      _segs.add(_Seg(c, y));
    }
  }

  @override
  void init() {
    _add(0, 30, 0, 0, 0);
    _add(15, 40, 15, 2.0, 0);
    _add(10, 30, 10, 0, 1400);
    _add(15, 50, 15, -2.8, -1400);
    _add(0, 30, 0, 0, 0);
    _add(10, 30, 10, 2.4, 800);
    _add(10, 40, 10, -1.6, -800);
    _add(15, 60, 15, 3.0, 0);
    _add(10, 30, 10, 0, 1100);
    _add(10, 40, 10, -3.0, -1100);
    _add(10, 50, 10, 1.4, 0);
    _add(0, 110, 0, 0, 0);
    _len = (_segs.length - 12) * _segL; // finish line near the end
    // scenery
    for (var i = 12; i < _segs.length; i += 6) {
      final s = _segs[i];
      final side = (i ~/ 6).isEven ? -1.0 : 1.0;
      final r = (i * 37) % 10;
      s.props.add(_Prop(r < 5 ? _PK.palm : (r < 7 ? _PK.bush : (r < 9 ? _PK.sign : _PK.billboard)), side * (1.5 + (r % 3) * .35)));
      if (i % 12 == 0) s.props.add(_Prop(_PK.bush, -side * 1.45));
    }
    // curve arrow signs where curves start
    for (var i = 20; i < _segs.length - 20; i++) {
      final a = _segs[i - 1].curve, b = _segs[i].curve;
      if (a.abs() < .2 && b.abs() >= .2) {
        _segs[i].props.add(_Prop(b > 0 ? _PK.arrowR : _PK.arrowL, b > 0 ? -1.4 : 1.4));
      }
    }
    _segs[6].props.add(_Prop(_PK.gantry, 0));
    _segs[(_len / _segL).floor()].props.add(_Prop(_PK.finish, 0));
    // boost pads
    for (final p in const [(60.0, .45), (140.0, -.4), (250.0, 0.0), (360.0, .5), (470.0, -.5), (560.0, .3), (650.0, 0.0)]) {
      if (p.$1 < _segs.length - 20) _pads.add(p);
    }
    // rivals
    final hs = 1 + (host.speed - 1) * .15;
    const data = [(1500.0, 5150.0, -.45), (1200.0, 4950.0, .4), (900.0, 4700.0, -.1), (600.0, 4550.0, .5), (300.0, 4400.0, -.5)];
    for (var i = 0; i < data.length; i++) {
      _rivals.add(_Kart(data[i].$1, data[i].$2 * hs, data[i].$3, i));
    }
  }

  _Seg _seg(int i) => i < _segs.length ? _segs[i] : _segs.last;
  double _hillAt(double z) {
    final i = (z / _segL).floor();
    final k = (z % _segL) / _segL;
    final a = i <= 0 ? 0.0 : _seg(i - 1).y;
    return M.lerp(a, _seg(i).y, k);
  }

  // --------------------------------------------------------------- input ---
  double get _steerInput {
    var s = 0.0;
    if (host.pointerDown) {
      final dx = host.pointer.dx - 180;
      if (dx.abs() > 10) s = ((dx - dx.sign * 10) / 80).clamp(-1.0, 1.0);
    }
    if (_keyL) s -= 1;
    if (_keyR) s += 1;
    return s.clamp(-1.0, 1.0);
  }

  @override
  void onKey(String key, bool down) {
    if (key == 'left') _keyL = down;
    if (key == 'right') _keyR = down;
  }

  // -------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    _pops.update(dt);
    _placePop = max(0, _placePop - dt * 2);
    _boost = max(0, _boost - dt);
    _bump = max(0, _bump - dt);
    final input = _finished ? 0.0 : _steerInput;
    _steer = M.approach(_steer, input, 12, dt);
    final off = _x.abs() > 1.0;
    final target = _finished ? 1200.0 : (_boost > 0 ? _boostV : (off ? _offV : _maxV));
    if (_v < target) {
      _v = min(target, _v + (_boost > 0 ? 9000 : 2800) * dt);
    } else {
      _v = max(target, _v - (off ? 5000 : 2200) * dt);
    }
    final ratio = _v / _maxV;
    final seg = _seg((_z / _segL).floor());
    _x += _steer * dt * 2.3 * min(1, ratio + .25);
    _x -= seg.curve / 3 * 1.35 * ratio * ratio * dt;
    _x = _x.clamp(-2.2, 2.2);
    _skyOff += seg.curve * ratio * dt * 14;
    _z += _v * dt;
    if (off && _v > 1500) {
      _offT += dt;
      if (_offT > .12) {
        _offT = 0;
        host.shake(2, .1);
        host.fx.burst(const Offset(180, 620), const Color(0xFFB88A4A), count: 3, speed: 120, size: 6, shape: PartShape.square, gravity: 200, life: .4);
      }
    }
    // engine hum
    _sfxT -= dt;
    if (_sfxT <= 0 && !_finished) {
      _sfxT = .45;
      host.sfx(Sfx.engine, volume: .18, rate: .7 + ratio * .5);
    }
    // boost pads
    final si = (_z / _segL).floor();
    for (final p in _pads) {
      if (si >= p.$1 && si < p.$1 + 3 && (_x - p.$2).abs() < .32 && _boost < 1.0) {
        _boost = 1.3;
        host.sfx(Sfx.pPowerup, rate: 1.2);
        host.sfx(Sfx.whoosh, volume: .6);
        host.shake(4);
        host.punch(.03);
        _pops.add(host.tr('boost', 'BOOST!'), const Offset(180, 470), const Color(0xFFFFB02A), 4);
      }
    }
    // rivals
    for (final r in _rivals) {
      final rt = r.fin ? 2000.0 : r.top;
      r.v = r.v < rt ? min(rt, r.v + 2600 * dt) : max(rt, r.v - 2000 * dt);
      r.z += r.v * dt;
      r.x = r.lane + sin(_t * .55 + r.i * 1.7) * .22;
      if (r.z >= _len) r.fin = true;
      r.flash = max(0, r.flash - dt);
      // bump from behind
      final dz = r.z - _z;
      if (!_finished && dz > 0 && dz < 150 && (r.x - _x).abs() < .34 && _bump <= 0) {
        _bump = .6;
        _v = min(_v, r.v * .7);
        _x += (_x >= r.x ? 1 : -1) * .25;
        r.v += 400;
        r.flash = .3;
        host.sfx(Sfx.pHit);
        host.sfx(Sfx.thud, volume: .6);
        host.shake(7);
        host.hitStop(.05);
        _pops.add(host.tr('oops', 'OOPS'), const Offset(180, 470), Pal.red, 3);
      }
    }
    // place
    var place = 1;
    for (final r in _rivals) {
      if (r.z > _z) place++;
    }
    if (!_finished) {
      if (place < _lastPlace) {
        _placePop = 1;
        host.sfx(Sfx.pCoin, rate: 1 + (6 - place) * .08);
        _pops.add('+${_lastPlace - place}', const Offset(180, 440), Pal.lime, 4);
      } else if (place > _lastPlace) {
        _placePop = 1;
        host.sfx(Sfx.pSelect, rate: .7);
      }
      _lastPlace = place;
      _place = place;
    }
    if (!_finished && _z >= _len) {
      _finished = true;
      if (_place <= 3) {
        host.sfx(Sfx.fanfare);
        host.fx.confetti(count: 90);
        host.flash(Pal.white, .15);
        host.shake(6);
        host.win(stars: 4 - _place);
      } else {
        host.sfx(Sfx.jingleLose, volume: .8);
        host.lose();
      }
    }
  }

  // -------------------------------------------------------------- render ---
  static final Paint _pp = Paint()..isAntiAlias = false;
  void _rect(Canvas c, double l, double t, double r, double b, Color col) {
    _pp.color = col;
    c.drawRect(Rect.fromLTRB(l, t, r, b), _pp);
  }

  double _q(double v) => (v / _px).roundToDouble() * _px;

  @override
  void render(Canvas c) {
    final camZ = _z - _pd;
    final baseIdx = max(0, (camZ / _segL).floor());
    final basePct = (camZ / _segL) - baseIdx;
    final playerY = _hillAt(_z);
    final camY = playerY + _camH;
    // hill-dependent horizon tilt for sky
    _drawSky(c);
    // ground base color up to horizon
    _rect(c, 0, _hor - 8, 360, 640, const Color(0xFF3E9A3A));

    var x = 0.0;
    var dx = -_seg(baseIdx).curve * basePct;
    var maxy = 640.0;
    final camX = _x * _roadW;
    for (var n = 0; n < _drawN; n++) {
      final i = baseIdx + n;
      final seg = _seg(i);
      final prevY = i <= 0 ? 0.0 : _seg(i - 1).y;
      var z1 = i * _segL - camZ;
      final z2 = z1 + _segL;
      if (z2 <= 20) {
        _pVis[n] = false;
        continue;
      }
      z1 = max(z1, 20);
      final s1 = _f / z1, s2 = _f / z2;
      final x1 = 180 + (x - camX) * s1;
      final x2 = 180 + (x + dx - camX) * s2;
      final y1 = _hor + (camY - prevY) * s1;
      final y2 = _hor + (camY - seg.y) * s2;
      x += dx;
      dx += seg.curve;
      _pX1[n] = x1;
      _pX2[n] = x2;
      _pY1[n] = y1;
      _pY2[n] = y2;
      _pS1[n] = s1;
      _pS2[n] = s2;
      _pClip[n] = maxy;
      _pVis[n] = true;
      if (y2 >= maxy || y2 >= y1) continue;
      _drawSegRows(c, i, x1, y1, s1 * _roadW, x2, y2, s2 * _roadW, maxy);
      maxy = y2;
    }
    // sprites back to front
    for (var n = _drawN - 1; n >= 0; n--) {
      if (!_pVis[n]) continue;
      final i = baseIdx + n;
      final seg = _seg(i);
      if (seg.props.isNotEmpty && _pS1[n] < .32) {
        for (final p in seg.props) {
          _drawProp(c, p, _pX1[n], _pY1[n], _pS1[n], _pClip[n]);
        }
      }
      for (final r in _rivals) {
        final ri = (r.z / _segL).floor();
        if (ri != i) continue;
        final k = (r.z % _segL) / _segL;
        final s = M.lerp(_pS1[n], _pS2[n], k);
        final sx = M.lerp(_pX1[n], _pX2[n], k) + r.x * _roadW * s;
        final sy = M.lerp(_pY1[n], _pY2[n], k);
        _drawKart(c, r, sx, sy, s, _pClip[n]);
      }
    }
    _drawPlayer(c);
    _drawHud(c);
    _pops.render(c);
    Retro.scanlines(c, alpha: .12, gap: 4);
    Retro.vignette(c, strength: .3);
  }

  void _drawSegRows(Canvas c, int i, double x1, double y1, double w1, double x2, double y2, double w2, double maxy) {
    final light = (i ~/ 3).isEven;
    final grass = light ? const Color(0xFF4DB24A) : const Color(0xFF3E9A3A);
    final rumble = light ? const Color(0xFFF2F2F2) : const Color(0xFFE8453C);
    final road = light ? const Color(0xFF6B6B78) : const Color(0xFF63636F);
    final lane = light ? const Color(0xFFF2F2F2) : null;
    final bottom = min(y1, maxy);
    var yr = (y2 / _px).floor() * _px;
    // pad on this segment?
    double? padX;
    for (final p in _pads) {
      if (i >= p.$1 && i < p.$1 + 3) padX = p.$2;
    }
    final isFinish = i == (_len / _segL).floor() || i == 6;
    for (; yr < bottom; yr += _px) {
      final cy = yr + _px / 2;
      if (cy < y2 || cy >= bottom) continue;
      final t = ((y1 - cy) / (y1 - y2)).clamp(0.0, 1.0);
      final cx = M.lerp(x1, x2, t);
      final hw = M.lerp(w1, w2, t);
      _rect(c, 0, yr, 360, yr + _px, grass);
      final rw = hw * 1.14;
      _rect(c, _q(cx - rw), yr, _q(cx + rw), yr + _px, rumble);
      _rect(c, _q(cx - hw), yr, _q(cx + hw), yr + _px, road);
      if (isFinish) {
        final cell = max(_px, _q(hw / 6));
        var col = ((yr / _px).floor()).isEven;
        for (var xx = _q(cx - hw); xx < cx + hw; xx += cell) {
          if (col) _rect(c, xx, yr, min(xx + cell, _q(cx + hw)), yr + _px, const Color(0xFF15151C));
          col = !col;
        }
        continue;
      }
      if (lane != null) {
        final lw = max(_px, _q(hw * .04));
        for (final lx in const [-.33, .33]) {
          final px = _q(cx + hw * lx);
          _rect(c, px - lw / 2, yr, px + lw / 2, yr + _px, lane);
        }
      }
      if (padX != null) {
        final pc = cx + hw * padX;
        final pw = hw * .22;
        final blink = ((_t * 8).floor() + i).isEven;
        _rect(c, _q(pc - pw), yr, _q(pc + pw), yr + _px, blink ? const Color(0xFFFFB02A) : const Color(0xFFFF6A2A));
        // chevron stripe
        final ph = ((y1 - cy) / max(1, y1 - y2) * 2 + _t * 4) % 1;
        if (ph < .35) _rect(c, _q(pc - pw * .5), yr, _q(pc + pw * .5), yr + _px, const Color(0xFFFFF1A0));
      }
    }
  }

  void _drawSky(Canvas c) {
    const bands = [Color(0xFF2B2A7A), Color(0xFF4A3FA8), Color(0xFF7A5AD0), Color(0xFFD86AB0), Color(0xFFFF9A7A), Color(0xFFFFD08A)];
    const top = 36.0;
    final h = (_hor - top) / bands.length;
    for (var i = 0; i < bands.length; i++) {
      final y = _q(top + i * h);
      _rect(c, 0, y, 360, _q(top + (i + 1) * h) + 1, bands[i]);
      if (i + 1 < bands.length) {
        for (var x = 0.0; x < 360; x += 8) {
          _rect(c, x, _q(top + (i + 1) * h) - 4, x + 4, _q(top + (i + 1) * h), bands[i + 1]);
        }
      }
    }
    // sun (striped retro)
    const sc = Offset(180, 200);
    for (var y = -9; y <= 9; y++) {
      final yy = sc.dy + y * 4;
      if (y > 1 && (y % 3 == 0)) continue;
      final w = sqrt(max(0, 81 - y * y)) * 4;
      _rect(c, _q(sc.dx - w), yy, _q(sc.dx + w), yy + 4, Color.lerp(const Color(0xFFFFF1A0), const Color(0xFFFF6A8A), (y + 9) / 18)!);
    }
    // stars
    for (var i = 0; i < 14; i++) {
      final sx = (i * 71 + _skyOff * .2) % 360;
      if (((_t * 2 + i) % 3) < 2) _rect(c, _q(sx), 44.0 + (i * 13) % 50, _q(sx) + 4, 48.0 + (i * 13) % 50, const Color(0xFFFFFFFF));
    }
    // far mountains
    for (var x = 0.0; x < 360; x += _px) {
      final wx = x + _skyOff * .5;
      final hgt = 26 + sin(wx * .018) * 16 + sin(wx * .051) * 8;
      _rect(c, x, _q(_hor - hgt), x + _px, _hor, const Color(0xFF5A3F8C));
      final snow = hgt > 40;
      if (snow) _rect(c, x, _q(_hor - hgt), x + _px, _q(_hor - hgt) + 8, const Color(0xFFE8D8FF));
    }
    // near hills
    for (var x = 0.0; x < 360; x += _px) {
      final wx = x + _skyOff;
      final hgt = 10 + sin(wx * .03 + 1) * 6 + sin(wx * .09) * 3;
      _rect(c, x, _q(_hor - hgt), x + _px, _hor, const Color(0xFF2E6A4A));
    }
  }

  void _drawProp(Canvas c, _Prop p, double sx0, double sy, double s, double clip) {
    final sx = sx0 + p.x * _roadW * s;
    if (sy > clip + 4) return;
    c.save();
    c.clipRect(Rect.fromLTRB(0, 36, 360, clip));
    switch (p.kind) {
      case _PK.gantry || _PK.finish:
        final hw = _roadW * 1.25 * s;
        final ph = 900 * s;
        final post = max(_px, _q(40 * s));
        _rect(c, _q(sx - hw) - post, _q(sy - ph), _q(sx - hw), _q(sy), const Color(0xFFB0B8C8));
        _rect(c, _q(sx + hw), _q(sy - ph), _q(sx + hw) + post, _q(sy), const Color(0xFFB0B8C8));
        final bh = max(_px * 2, _q(120 * s));
        final cell = max(_px, _q(60 * s));
        var yy = _q(sy - ph);
        var row = 0;
        for (; yy < _q(sy - ph) + bh; yy += cell, row++) {
          var col = row.isEven;
          for (var xx = _q(sx - hw); xx < sx + hw; xx += cell) {
            _rect(c, xx, yy, min(xx + cell, _q(sx + hw)), yy + cell, col ? const Color(0xFF15151C) : const Color(0xFFF2F2F2));
            col = !col;
          }
        }
      default:
        final spr = switch (p.kind) {
          _PK.palm => _S.palm,
          _PK.bush => _S.bush,
          _PK.sign => _S.sign,
          _PK.billboard => _S.billboard,
          _PK.arrowL => _S.arrowL,
          _ => _S.arrowR,
        };
        final worldH = switch (p.kind) {
          _PK.palm => 1500.0,
          _PK.bush => 320.0,
          _PK.billboard => 900.0,
          _ => 620.0,
        };
        final sc = _qs(worldH * s / spr.h);
        if (sc * spr.h >= 2) {
          spr.draw(c, Offset(_q(sx - spr.w * sc / 2), _q(sy - spr.h * sc)), scale: sc);
        }
    }
    c.restore();
  }

  double _qs(double sc) => sc > 1 ? (sc * 2).roundToDouble() / 2 : sc;

  void _drawKart(Canvas c, _Kart r, double sx, double sy, double s, double clip) {
    if (sy > clip + 6) return;
    final sc = _qs(240 * s / _S.kartW);
    if (sc * _S.kartW < 3) return;
    c.save();
    c.clipRect(Rect.fromLTRB(0, 36, 360, clip));
    final spr = _S.rivalKarts[r.i];
    final bob = ((_t * 12 + r.i).floor().isEven ? 0 : 1) * sc;
    D.shadow(c, Offset(sx, sy), _S.kartW * sc, 6 * sc / 4, .35);
    spr.draw(c, Offset(_q(sx - _S.kartW * sc / 2), _q(sy - _S.kartH * sc - bob)), scale: sc,
        tint: r.flash > 0 && (_t * 20).floor().isEven ? Pal.white : null);
    c.restore();
  }

  void _drawPlayer(Canvas c) {
    final off = _x.abs() > 1.0;
    final jig = off ? ((_t * 30).floor().isEven ? _px : 0.0) : ((_t * 10).floor().isEven ? 0.0 : _px / 2);
    final spr = _steer < -.35 ? _S.playerL : (_steer > .35 ? _S.playerR : _S.player);
    const sc = 4.0;
    final x = _q(180 - _S.kartW * sc / 2 + _steer * 6);
    final y = 626 - _S.kartH * sc - jig;
    D.shadow(c, const Offset(180, 628), _S.kartW * sc * 1.05, 14, .4);
    // boost flames
    if (_boost > 0) {
      for (final ex in const [-22.0, 22.0]) {
        final fl = 10 + ((_t * 30).floor() % 3) * 6.0;
        _rect(c, 180 + ex - 6, y + _S.kartH * sc - 8, 180 + ex + 6, y + _S.kartH * sc - 8 + fl, const Color(0xFFFF6A2A));
        _rect(c, 180 + ex - 3, y + _S.kartH * sc - 8, 180 + ex + 3, y + _S.kartH * sc - 8 + fl * .6, const Color(0xFFFFF1A0));
      }
      // speed lines
      for (var i = 0; i < 8; i++) {
        final a = (i * 47 + _t * 900) % 360;
        final side = i.isEven ? 1 : -1;
        _rect(c, 180 + side * (60 + a * .4), 280 + (i * 53) % 300, 180 + side * (60 + a * .4) + 4, 300 + (i * 53) % 300 + a * .1,
            const Color(0x88FFFFFF));
      }
    } else if ((_t * 6).floor().isEven) {
      _rect(c, 180 - 24, y + _S.kartH * sc - 4, 180 - 16, y + _S.kartH * sc + 4, const Color(0x99D0D0D0));
    }
    spr.draw(c, Offset(x, y), scale: sc, tint: _bump > .3 && (_t * 20).floor().isEven ? Pal.white : null);
    // steering hint
    if (host.time < 2.4) {
      final hx = 180 + sin(_t * 3) * 80;
      D.hand(c, Offset(hx, 420), _t);
      D.arrow(c, const Offset(110, 380), const Offset(-1, 0), 40, Pal.yellow, width: 9);
      D.arrow(c, const Offset(250, 380), const Offset(1, 0), 40, Pal.yellow, width: 9);
      _pt(c, host.tr('drag', 'DRAG'), const Offset(180, 380), 3, Pal.white);
    }
  }

  void _drawHud(Canvas c) {
    // position box
    const box = Rect.fromLTWH(8, 42, 92, 52);
    _rect(c, box.left - 3, box.top - 3, box.right + 3, box.bottom + 3, const Color(0xFF10122A));
    _rect(c, box.left, box.top, box.right, box.bottom, const Color(0xCC2B2A7A));
    final pc = _place <= 3 ? const Color(0xFFFFD23F) : const Color(0xFFFF6A8A);
    final sc = 6.0 + (_placePop > 0 ? 2 : 0);
    PixelFont.draw(c, '$_place', Offset(14, 68 - 3.5 * sc), sc, pc, shadow: const Color(0xFF10122A));
    PixelFont.draw(c, '/6', const Offset(58, 72), 3, Pal.white, shadow: const Color(0xFF10122A));
    if (_place <= 3) _S.trophy.draw(c, const Offset(66, 46), scale: 2);
    // progress track
    const bar = Rect.fromLTWH(118, 50, 232, 10);
    _rect(c, bar.left - 2, bar.top - 2, bar.right + 2, bar.bottom + 2, const Color(0xFF10122A));
    _rect(c, bar.left, bar.top, bar.right, bar.bottom, const Color(0xFF3A3F70));
    for (var i = 0; i < 6; i++) {
      _rect(c, bar.right - 12 + (i.isEven ? 0 : 6), bar.top + (i ~/ 2) * 3.3, bar.right - 6 + (i.isEven ? 0 : 6),
          bar.top + (i ~/ 2) * 3.3 + 3.3, i % 4 == 0 || i % 4 == 3 ? const Color(0xFF15151C) : Pal.white);
    }
    for (final r in _rivals) {
      final k = (r.z / _len).clamp(0.0, 1.0);
      _rect(c, bar.left + k * (bar.width - 8), bar.top + 2, bar.left + k * (bar.width - 8) + 6, bar.bottom - 2,
          _S.rivalCols[r.i]);
    }
    final pk = (_z / _len).clamp(0.0, 1.0);
    _S.pin.draw(c, Offset(bar.left + pk * (bar.width - 8) - 4, bar.top - 8), scale: 2);
    // speed
    final kmh = (_v / 30).round();
    PixelFont.draw(c, '$kmh', const Offset(300, 72), 3, _boost > 0 ? const Color(0xFFFFB02A) : Pal.white, align: 1,
        shadow: const Color(0xFF10122A));
    PixelFont.draw(c, 'KM/H', const Offset(348, 76), 2, const Color(0xFFBFD0FF), align: 1);
  }
}

class _Seg {
  _Seg(this.curve, this.y);
  final double curve;
  final double y;
  final List<_Prop> props = [];
}

enum _PK { palm, bush, sign, billboard, arrowL, arrowR, gantry, finish }

class _Prop {
  _Prop(this.kind, this.x);
  final _PK kind;
  final double x;
}

class _Kart {
  _Kart(this.z, this.top, this.lane, this.i);
  double z;
  double v = 0;
  final double top;
  final double lane;
  final int i;
  double x = 0;
  bool fin = false;
  double flash = 0;
}

class _Pops {
  final List<(String, Offset, Color, double, double)> _l = [];
  void add(String s, Offset at, Color col, [double scale = 3]) {
    if (_l.length < 6) _l.add((s, at, col, scale, 0));
  }

  void update(double dt) {
    for (var i = _l.length - 1; i >= 0; i--) {
      final e = _l[i];
      if (e.$5 + dt > .9) {
        _l.removeAt(i);
      } else {
        _l[i] = (e.$1, e.$2 - Offset(0, 40 * dt), e.$3, e.$4, e.$5 + dt);
      }
    }
  }

  void render(Canvas c) {
    for (final e in _l) {
      if (e.$5 > .7 && ((e.$5 * 20).floor().isEven)) continue;
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
  static const _kart = [
    '.........KKKK.........',
    '.......KHHHHHHK.......',
    '......KHHWWHHHHK......',
    '......KHHHHHHHHK......',
    '......KVVVVVVVVK......',
    '.......KHHHHHHK.......',
    '.....KKCCCCCCCCKK.....',
    '....KCCCCCCCCCCCCK....',
    '..KKKBBBBBBBBBBBBKKK..',
    '.KTTKBBBBBBBBBBBBKTTK.',
    'KTTTKBBWWBBBBWWBBKTTTK',
    'KTtTKBBBBBBBBBBBBKTtTK',
    'KTTTKGGGGGGGGGGGGKTTTK',
    'KTtTKKGRRGGGGRRGKKTtTK',
    '.KTTK.KKKKKKKKKK.KTTK.',
    '..KK..............KK..',
  ];
  static const kartW = 22;
  static const kartH = 16;

  static List<String> _lean(int dir) => [
        for (var i = 0; i < _kart.length; i++)
          i < 8
              ? (dir < 0 ? '${_kart[i].substring(1)}.' : '.${_kart[i].substring(0, _kart[i].length - 1)}')
              : _kart[i],
      ];

  static Map<String, Color> _pal(Color body, Color helmet) => {
        'K': _k,
        'H': helmet,
        'W': const Color(0xFFFFFFFF),
        'V': const Color(0xFF2A3A6A),
        'C': Color.lerp(body, const Color(0xFF000000), .25)!,
        'B': body,
        'T': const Color(0xFF34343F),
        't': const Color(0xFF5A5A68),
        'G': const Color(0xFFB0B8C8),
        'R': const Color(0xFFFF3B3B),
      };

  static final player = Sprite(_kart, _pal(const Color(0xFFE8453C), const Color(0xFFFFFFFF)));
  static final playerL = Sprite(_lean(-1), _pal(const Color(0xFFE8453C), const Color(0xFFFFFFFF)));
  static final playerR = Sprite(_lean(1), _pal(const Color(0xFFE8453C), const Color(0xFFFFFFFF)));
  static const rivalCols = [Color(0xFF3F7FE8), Color(0xFF4CC43A), Color(0xFFFFD23F), Color(0xFFB05AE8), Color(0xFFFF8A1F)];
  static final rivalKarts = [
    for (final col in rivalCols) Sprite(_kart, _pal(col, Color.lerp(col, const Color(0xFFFFFFFF), .5)!)),
  ];

  static final palm = Sprite(const [
    '...GG....GG.....',
    '.GGGGG..GGGGG...',
    'GG...GGGG...GG..',
    'G..GGGgGGGG...G.',
    '..GG..gg..GGG...',
    '.G...gTg.....G..',
    '.....TTg........',
    '......TT........',
    '......TTg.......',
    '.......TT.......',
    '.......TTg......',
    '.......TT.......',
    '.......TTg......',
    '......gTT.......',
    '......TTg.......',
    '......TT........',
    '.....gTTg.......',
    '....ggTTgg......',
  ], const {'G': Color(0xFF2FB05A), 'g': Color(0xFF1E6A3A), 'T': Color(0xFFB07A3E)});
  static final bush = Sprite(const [
    '...GGG..GG..',
    '.GGgGGGGGGG.',
    'GGGGGgGGGgGG',
    'GgGGGGGGGGGG',
    '.GGGGGgGGGG.',
  ], const {'G': Color(0xFF2E8B3A), 'g': Color(0xFF4FBF4A)});
  static final sign = Sprite(const [
    'KKKKKKKKKKK',
    'KYYYYYYYYYK',
    'KYYYYKYYYYK',
    'KYYYKKKYYYK',
    'KYKKKKKKKYK',
    'KYYKKKKKYYK',
    'KYYKKYKKYYK',
    'KYYYYYYYYYK',
    'KKKKKKKKKKK',
    '....GGG....',
    '....GGG....',
    '....GGG....',
  ], const {'K': _k, 'Y': Color(0xFFFFD23F), 'G': Color(0xFFB0B8C8)});
  static final arrowL = Sprite(const [
    'KKKKKKKKKK',
    'KRRRRRRRRK',
    'KRRWRRRRRK',
    'KRWWWWWWRK',
    'KRRWRRRRRK',
    'KRRRRRRRRK',
    'KKKKKKKKKK',
    '....GG....',
    '....GG....',
    '....GG....',
  ], const {'K': _k, 'R': Color(0xFFE8453C), 'W': Color(0xFFFFFFFF), 'G': Color(0xFFB0B8C8)});
  static final arrowR = Sprite(const [
    'KKKKKKKKKK',
    'KRRRRRRRRK',
    'KRRRRRWRRK',
    'KRWWWWWWRK',
    'KRRRRRWRRK',
    'KRRRRRRRRK',
    'KKKKKKKKKK',
    '....GG....',
    '....GG....',
    '....GG....',
  ], const {'K': _k, 'R': Color(0xFFE8453C), 'W': Color(0xFFFFFFFF), 'G': Color(0xFFB0B8C8)});
  static final billboard = Sprite(const [
    'KKKKKKKKKKKKKKKKKK',
    'KPPPPPPPPPPPPPPPPK',
    'KPWWPWWWPWWWPPYYPK',
    'KPPWPWPPPPPWPYYYYK',
    'KPPWPWWWPPWWPYYYYK',
    'KPPWPPPWPPPWPPYYPK',
    'KPWWWPWWPWWWPPPPPK',
    'KPPPPPPPPPPPPPPPPK',
    'KKKKKKKKKKKKKKKKKK',
    '...GG........GG...',
    '...GG........GG...',
    '...GG........GG...',
  ], const {'K': _k, 'P': Color(0xFFFF5FC8), 'W': Color(0xFFFFFFFF), 'Y': Color(0xFFFFD23F), 'G': Color(0xFFB0B8C8)});
  static final trophy = Sprite(const [
    'YYYYYYY',
    'YWYYYYY',
    '.YYYYY.',
    '..YYY..',
    '...Y...',
    '.YYYYY.',
  ], const {'Y': Color(0xFFFFD23F), 'W': Color(0xFFFFFFFF)});
  static final pin = Sprite(const [
    'KKKKKKK',
    'KRRRRRK',
    'KRWRRRK',
    '.KRRRK.',
    '..KRK..',
    '...K...',
  ], const {'K': _k, 'R': Color(0xFFE8453C), 'W': Color(0xFFFFFFFF)});
}
