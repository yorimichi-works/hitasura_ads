import '../engine/engine.dart';

/// No.093 Ninja Wall Climb — 8-bit wall-kick climber.
///
/// The ninja auto-climbs between two stone walls. Tap to wall-jump to the
/// other side: dodge spike strips, crows and falling shuriken, grab scrolls
/// (+score and a dash boost). Reach the rooftop (300 m) => win. 2 hearts.
class G093 extends MiniGame {
  static const _ny = 470.0; // ninja screen y
  static const _lx = 70.0, _rx = 290.0; // cling x
  static const _goalH = 3000.0; // px (=300 m)

  double _t = 0;
  double _h = 0; // climbed height (px)
  double _dash = 0;
  int _side = 0; // 0 left, 1 right
  bool _jumping = false;
  double _jt = 0;
  bool _queued = false;
  int _hp = 2;
  double _inv = 0;
  bool _dead = false;
  double _deadT = 0;
  Offset _deadV = Offset.zero;
  Offset _deadP = Offset.zero;
  bool _won = false;
  double _wonT = 0;
  int _scrolls = 0;
  int _hits = 0;
  double _nextSpawn = 520;
  int _lastSpikeSide = -1;
  final List<_Ob> _obs = [];
  final List<Offset> _petals = [];
  final _pops = _Pops();

  @override
  void init() {
    for (var i = 0; i < 14; i++) {
      _petals.add(Offset(rand(0, 360), rand(40, 640)));
    }
  }

  double get _speed => (230 + (_dash > 0 ? 260 : 0)) * sqrt(host.speed);

  double get _nx {
    if (!_jumping) return _side == 0 ? _lx : _rx;
    final from = _side == 0 ? _lx : _rx, to = _side == 0 ? _rx : _lx;
    return M.lerp(from, to, M.easeInOut(_jt));
  }

  double _sy(double wy) => _ny - (wy - _h);

  // --------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) => _jump();

  @override
  void onKey(String key, bool down) {
    if (down && (key == 'action' || key == 'up' || key == 'left' || key == 'right')) _jump();
  }

  void _jump() {
    if (_dead || _won || host.finished) return;
    if (_jumping) {
      if (_jt > .55) _queued = true;
      return;
    }
    _jumping = true;
    _jt = 0;
    host.sfx(Sfx.pJump, rate: 1.1 + (_side == 0 ? 0 : .08));
    host.fx.burst(Offset(_nx + (_side == 0 ? -14 : 14), _ny), const Color(0xFFB0B8C8), count: 5, speed: 90, shape: PartShape.square, size: 4, gravity: 200, life: .3);
  }

  // -------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    _pops.update(dt);
    _inv = max(0, _inv - dt);
    _dash = max(0, _dash - dt);
    for (var i = 0; i < _petals.length; i++) {
      var p = _petals[i] + Offset(sin(_t * 2 + i) * 20 * dt - 12 * dt, (40 + (_dead ? 0 : _speed * .35)) * dt);
      if (p.dy > 650) p = Offset(rand(0, 380), 30);
      if (p.dx < -10) p = Offset(370, p.dy);
      _petals[i] = p;
    }
    if (_dead) {
      _deadT += dt;
      _deadV += Offset(0, 900 * dt);
      _deadP += _deadV * dt;
      return;
    }
    if (_won) {
      _wonT += dt;
      return;
    }
    _h += _speed * dt;
    if (_jumping) {
      _jt += dt / .3;
      if (_jt >= 1) {
        _jumping = false;
        _side = 1 - _side;
        host.sfx(Sfx.land, volume: .4, rate: 1.4);
        host.fx.burst(Offset(_nx + (_side == 0 ? -14 : 14), _ny), const Color(0xFFD0D8E8), count: 4, speed: 70, shape: PartShape.square, size: 4, gravity: 100, life: .25);
        if (_queued) {
          _queued = false;
          _jump();
        }
      }
    }
    // spawn
    while (_nextSpawn < _h + 700 && _nextSpawn < _goalH - 120) {
      _spawnAt(_nextSpawn);
      _nextSpawn += rand(185, 240) / sqrt(host.speed);
    }
    // obstacles
    final nx = _nx;
    for (final o in _obs) {
      switch (o.kind) {
        case _OK.bird:
          o.x += o.vx * dt;
          if (o.x < 90 || o.x > 270) o.vx = -o.vx;
        case _OK.star:
          if (_sy(o.y) > -40) {
            o.y -= 180 * dt;
            o.x += o.vx * dt;
          }
        default:
          break;
      }
      if (o.done) continue;
      final dy = (o.y - _h).abs();
      switch (o.kind) {
        case _OK.spike:
          final onSide = (o.side == 0 && nx < _lx + 26) || (o.side == 1 && nx > _rx - 26);
          if (onSide && _h > o.y - 10 && _h < o.y + o.len + 6) _hit(o);
        case _OK.bird:
          if ((o.x - nx).abs() < 26 && dy < 22) _hit(o);
        case _OK.star:
          if ((o.x - nx).abs() < 20 && dy < 20) _hit(o);
        case _OK.scroll:
          if ((o.x - nx).abs() < 30 && dy < 30) {
            o.done = true;
            _scrolls++;
            _dash = .7;
            host.addScore(100);
            host.sfx(Sfx.pCoin, rate: 1 + _scrolls * .06);
            host.sfx(Sfx.whoosh, volume: .5);
            host.fx.burst(Offset(o.x, _sy(o.y)), Pal.yellow, count: 12, speed: 200, shape: PartShape.square, size: 5);
            _pops.add('+10M', Offset(o.x, _sy(o.y) - 20), Pal.yellow, 3);
            _h += 100;
          }
      }
    }
    _obs.removeWhere((o) => _sy(o.y) > 720);
    if (_h >= _goalH) {
      _won = true;
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.pPowerup);
      host.fx.confetti(count: 90);
      host.flash(Pal.white, .15);
      host.win(stars: _hits == 0 ? 3 : 2);
    }
  }

  void _spawnAt(double y) {
    final r = rng.nextDouble();
    if (r < .55) {
      var side = randInt(2);
      if (side == _lastSpikeSide && chance(.5)) side = 1 - side;
      _lastSpikeSide = side;
      _obs.add(_Ob(_OK.spike, y, side: side, len: rand(60, 95)));
      if (chance(.6)) _obs.add(_Ob(_OK.scroll, y + 30, x: side == 0 ? _rx : _lx));
    } else if (r < .8) {
      _obs.add(_Ob(_OK.bird, y, x: rand(110, 250), vx: (chance(.5) ? 1 : -1) * rand(60, 110)));
      if (chance(.5)) _obs.add(_Ob(_OK.scroll, y + 110, x: 180));
    } else {
      final fromLeft = chance(.5);
      _obs.add(_Ob(_OK.star, y + 380, x: fromLeft ? 110 : 250, vx: fromLeft ? 40 : -40));
      _obs.add(_Ob(_OK.scroll, y, x: 180));
    }
  }

  void _hit(_Ob o) {
    if (_inv > 0) return;
    o.done = true;
    _hp--;
    _hits++;
    host.shake(9);
    host.hitStop(.08);
    host.flash(Pal.red, .12);
    host.sfx(Sfx.pHit);
    host.sfx(o.kind == _OK.bird ? Sfx.slap : Sfx.hurt, volume: .7);
    host.fx.burst(Offset(_nx, _ny), Pal.red, count: 12, speed: 220, shape: PartShape.square, size: 5);
    if (_hp <= 0) {
      _dead = true;
      _deadP = Offset(_nx, _ny);
      _deadV = Offset(_side == 0 ? 120 : -120, -380);
      _pops.add(host.tr('ko', 'K.O.'), Offset(180, 300), Pal.red, 5);
      host.sfx(Sfx.pDie);
      host.lose();
    } else {
      _inv = 1.3;
      _pops.add(host.tr('ouch', 'OUCH!'), Offset(_nx, _ny - 40), Pal.orange, 3);
    }
  }

  @override
  void onTimeUp() {
    if (!_dead) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // -------------------------------------------------------------- render ---
  static final Paint _pp = Paint()..isAntiAlias = false;
  void _r(Canvas c, double l, double t, double w, double h, Color col) {
    _pp.color = col;
    c.drawRect(Rect.fromLTWH(l, t, w, h), _pp);
  }

  @override
  void render(Canvas c) {
    _drawSky(c);
    _drawWalls(c);
    // roof at goal
    final roofY = _sy(_goalH + 30);
    if (roofY > -80) _drawRoof(c, roofY);
    // obstacles
    for (final o in _obs) {
      final y = _sy(o.y);
      if (y < -60 || y > 700) continue;
      switch (o.kind) {
        case _OK.spike:
          _drawSpikes(c, o.side, y, o.len);
        case _OK.bird:
          final f = (_t * 8 + o.x).floor().isEven;
          (f ? _S.crow1 : _S.crow2).drawCentered(c, Offset(o.x, y), scale: 3, flipX: o.vx > 0);
        case _OK.star:
          if (y < 50) {
            // incoming warning
            if ((_t * 8).floor().isEven) _S.warn.drawCentered(c, Offset(o.x, 58), scale: 3);
          } else {
            c.save();
            c.translate(o.x, y);
            c.rotate(_t * 14);
            _S.shuriken.drawCentered(c, Offset.zero, scale: 3);
            c.restore();
          }
        case _OK.scroll:
          if (o.done) continue;
          final b = sin(_t * 5 + o.y) * 3;
          _S.scroll.drawCentered(c, Offset(o.x, y + b), scale: 3);
          if (((_t * 3 + o.y) % 1) < .2) _r(c, o.x + 10, y + b - 12, 3, 3, Pal.white);
      }
    }
    _drawNinja(c);
    // speed streaks when dashing
    if (_dash > 0) {
      for (var i = 0; i < 6; i++) {
        final x = 80.0 + i * 40;
        final y = (i * 97 + _t * 1400) % 640;
        _r(c, x, y, 2, 30, const Color(0x66FFFFFF));
      }
    }
    _drawHud(c);
    _pops.render(c);
    if (host.time < 2.2) {
      D.hand(c, const Offset(190, 520), _t);
      _pt(c, host.tr('tap', 'TAP'), const Offset(190, 600), 3, Pal.white);
      D.arrow(c, const Offset(180, 430), const Offset(1, -.3), 70, Pal.yellow, width: 8);
    }
    Retro.scanlines(c, alpha: .12);
    Retro.vignette(c, strength: .4);
  }

  void _drawSky(Canvas c) {
    const bands = [Color(0xFF0B0B2A), Color(0xFF15134A), Color(0xFF231A62), Color(0xFF34207A), Color(0xFF4A2A8A)];
    for (var i = 0; i < bands.length; i++) {
      final y = 36.0 + i * 121;
      _r(c, 0, y, 360, 122, bands[i]);
      if (i > 0) {
        for (var x = 0.0; x < 360; x += 8) {
          _r(c, x, y, 4, 4, bands[i - 1]);
        }
      }
    }
    // stars (slow parallax)
    for (var i = 0; i < 30; i++) {
      final x = (i * 67) % 300 + 30.0;
      final y = ((i * 131) + _h * .05) % 600 + 40;
      if (((_t + i * .37) % 2) < 1.7) _r(c, x, y, 2, 2, const Color(0xFFE8E0FF));
    }
    // moon
    const mc = Offset(200, 170);
    for (var y = -8; y <= 8; y++) {
      final w = sqrt(max(0, 64 - y * y)) * 5;
      _r(c, mc.dx - w, mc.dy + y * 5, w * 2, 5, const Color(0xFFFFF1C8));
    }
    _r(c, mc.dx - 15, mc.dy - 10, 10, 10, const Color(0xFFE8D8A8));
    _r(c, mc.dx + 10, mc.dy + 5, 15, 10, const Color(0xFFE8D8A8));
    _r(c, mc.dx - 5, mc.dy + 20, 8, 6, const Color(0xFFE8D8A8));
    // distant pagoda silhouettes (parallax)
    final off = (_h * .12) % 640;
    for (var k = 0; k < 2; k++) {
      final base = 640 + off - k * 640;
      _drawPagoda(c, 120, base - 60, const Color(0xFF1A1440));
      _drawPagoda(c, 240, base - 260, const Color(0xFF1A1440));
    }
    // petals
    for (final p in _petals) {
      _r(c, p.dx.roundToDouble(), p.dy.roundToDouble(), 4, 3, const Color(0xFFFF9AC8));
    }
  }

  void _drawPagoda(Canvas c, double cx, double base, Color col) {
    for (var i = 0; i < 4; i++) {
      final y = base - i * 40;
      final w = 70.0 - i * 12;
      _r(c, cx - w / 2, y - 8, w, 8, col);
      _r(c, cx - w / 2 + 12, y - 36, w - 24, 28, col);
    }
    _r(c, cx - 2, base - 190, 4, 30, col);
  }

  void _drawWalls(Canvas c) {
    const brick = Color(0xFF5A6078), brickD = Color(0xFF3C4058), brickL = Color(0xFF7A809A), moss = Color(0xFF4A8A4A);
    final off = _h % 32;
    for (final side in [0, 1]) {
      final x0 = side == 0 ? 0.0 : 304.0;
      _r(c, x0, 36, 56, 604, brickD);
      var row = ((_h / 32).floor()) % 2;
      for (var y = 640.0 + off - 32; y > 4; y -= 32, row++) {
        for (var bx = (row.isEven ? 0.0 : -14.0); bx < 56; bx += 28) {
          final l = max(x0, x0 + bx + 1), r = min(x0 + 56, x0 + bx + 27);
          if (r <= l) continue;
          _r(c, l, y + 1, r - l, 30, brick);
          _r(c, l, y + 1, r - l, 4, brickL);
        }
      }
      // inner edge
      final ex = side == 0 ? 52.0 : 304.0;
      _r(c, ex, 36, 4, 604, const Color(0xFF2A2C40));
      // moss & lanterns
      for (var k = 0; k < 6; k++) {
        final wy = ((k * 173 + side * 90) - _h * 1.0) % 900;
        final y = 640 - wy;
        if (y < 40 || y > 640) continue;
        if (k % 3 == 0) {
          _S.lantern.draw(c, Offset(side == 0 ? 8 : 318, y), scale: 3);
          if ((_t * 6 + k).floor() % 4 != 0) {
            _r(c, side == 0 ? 14 : 324, y + 12, 18, 3, const Color(0x55FFB02A));
          }
        } else {
          _r(c, side == 0 ? 40 : 308, y, 12, 6, moss);
          _r(c, side == 0 ? 44 : 312, y + 6, 4, 8, moss);
        }
      }
    }
  }

  void _drawSpikes(Canvas c, int side, double y, double len) {
    // y is the bottom of the strip (world y increases upward => screen top = y - len)
    final top = y - len;
    final x = side == 0 ? 56.0 : 304.0;
    _r(c, side == 0 ? x - 6 : x, top - 4, 6, len + 8, const Color(0xFF2A2C40));
    for (var sy = top; sy < y; sy += 12) {
      for (var k = 0; k < 4; k++) {
        final w = (4 - k) * 4.0;
        final xx = side == 0 ? x + k * 4 : x - (k + 1) * 4;
        _r(c, xx, sy + 6 - w / 2, 4, w, k == 0 ? const Color(0xFF9AA0B8) : const Color(0xFFD8DCE8));
      }
      _r(c, side == 0 ? x + 12 : x - 16, sy + 5, 4, 2, const Color(0xFFFF6A6A));
    }
  }

  void _drawRoof(Canvas c, double y) {
    const red = Color(0xFFC0392B), redL = Color(0xFFE8604A), gold = Color(0xFFFFD23F);
    _r(c, 20, y, 320, 16, red);
    _r(c, 20, y, 320, 4, redL);
    _r(c, 0, y + 12, 40, 8, red);
    _r(c, 320, y + 12, 40, 8, red);
    _r(c, 60, y - 40, 240, 40, const Color(0xFF3A2A40));
    for (var x = 70.0; x < 300; x += 30) {
      _r(c, x, y - 34, 14, 22, const Color(0xFFFFE8A0));
    }
    _r(c, 40, y - 52, 280, 12, red);
    _r(c, 174, y - 90, 12, 40, gold);
    _r(c, 168, y - 96, 24, 8, gold);
  }

  void _drawNinja(Canvas c) {
    if (_dead) {
      c.save();
      c.translate(_deadP.dx, _deadP.dy);
      c.rotate(_deadT * 10);
      _S.ninjaHurt.drawCentered(c, Offset.zero, scale: 3);
      c.restore();
      return;
    }
    final x = _nx;
    var y = _ny;
    if (_won) {
      // leap onto the roof & cheer
      final k = (_wonT / .5).clamp(0.0, 1.0);
      final roofY = _sy(_goalH + 30);
      final tx = 180.0, ty = roofY - 26;
      final px = M.lerp(x, tx, k), py = M.lerp(y, ty, k) - sin(k * pi) * 80;
      final spr = k < 1 ? _S.ninjaJump : ((_t * 6).floor().isEven ? _S.ninjaWin : _S.ninjaCling1);
      spr.drawCentered(c, Offset(px, py), scale: 3);
      if (k >= 1) D.rays(c, Offset(px, py), 120, const Color(0x33FFE14A), count: 12, t: _t);
      return;
    }
    if (_inv > 0 && (_t * 16).floor().isEven) return;
    if (_jumping) {
      y -= sin(_jt * pi) * 24;
      c.save();
      c.translate(x, y);
      c.rotate((_side == 0 ? 1 : -1) * _jt * pi * 2);
      _S.ninjaJump.drawCentered(c, Offset.zero, scale: 3);
      c.restore();
      // afterimages
      for (var k = 1; k <= 2; k++) {
        final jt = max(0.0, _jt - k * .12);
        final from = _side == 0 ? _lx : _rx, to = _side == 0 ? _rx : _lx;
        final ax = M.lerp(from, to, M.easeInOut(jt));
        _S.ninjaJump.drawCentered(c, Offset(ax, _ny - sin(jt * pi) * 24), scale: 3, tint: const Color(0xFF6A5AE8), opacity: .35 / k);
      }
      return;
    }
    final climb = (_t * 8).floor().isEven;
    final spr = climb ? _S.ninjaCling1 : _S.ninjaCling2;
    spr.drawCentered(c, Offset(x + (_side == 0 ? -4 : 4), y), scale: 3, flipX: _side == 1);
    // scarf flutter
    final sx = _side == 0 ? x + 6 : x - 6;
    for (var k = 0; k < 4; k++) {
      final wob = ((_t * 12 + k).floor().isEven ? 3.0 : 0.0);
      _r(c, sx + (_side == 0 ? k * 5 : -k * 5 - 5), y - 12 + k * 3 + wob, 5, 4, const Color(0xFFE8453C));
    }
  }

  void _drawHud(Canvas c) {
    for (var i = 0; i < 2; i++) {
      _S.heart.draw(c, Offset(66.0 + i * 26, 46), scale: 3, tint: i < _hp ? null : const Color(0xFF3A2A40));
    }
    final m = min(300, (_h / 10).floor());
    PixelFont.draw(c, '${m}M', const Offset(180, 46), 4, Pal.white, align: 0, shadow: const Color(0xFF10122A));
    // vertical progress on the right wall
    const bx = 330.0, top = 90.0, bot = 420.0;
    _r(c, bx - 2, top - 2, 12, bot - top + 4, const Color(0xFF10122A));
    _r(c, bx, top, 8, bot - top, const Color(0xFF3A3F70));
    final k = (_h / _goalH).clamp(0.0, 1.0);
    _r(c, bx, bot - (bot - top) * k, 8, (bot - top) * k, const Color(0xFFE8453C));
    _S.flag.draw(c, const Offset(bx - 4, top - 22), scale: 2);
    _S.head.draw(c, Offset(bx - 4, bot - (bot - top) * k - 6), scale: 2);
    // scrolls
    _S.scroll.draw(c, const Offset(16, 72), scale: 2);
    PixelFont.draw(c, 'x$_scrolls', const Offset(42, 76), 2, Pal.yellow, shadow: const Color(0xFF10122A));
  }
}

enum _OK { spike, bird, star, scroll }

class _Ob {
  _Ob(this.kind, this.y, {this.side = 0, this.len = 0, this.x = 0, this.vx = 0});
  final _OK kind;
  double y;
  final int side;
  final double len;
  double x;
  double vx;
  bool done = false;
}

class _Pops {
  final List<(String, Offset, Color, double, double)> _l = [];
  void add(String s, Offset at, Color col, [double scale = 3]) {
    if (_l.length < 6) _l.add((s, at, col, scale, 0));
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
  static const _np = <String, Color>{
    'K': Color(0xFF10122A),
    'N': Color(0xFF2A2F5A),
    'n': Color(0xFF3E4680),
    'S': Color(0xFFFFC99A),
    'W': Color(0xFFFFFFFF),
    'R': Color(0xFFE8453C),
    'G': Color(0xFFB0B8C8),
  };
  // clinging to a wall on the LEFT (hands toward left)
  static final ninjaCling1 = Sprite(const [
    '...NNNNN....',
    '..NNNNNNN...',
    '..NSWSSWN...',
    '..NNNNNNNR..',
    'SNNNNNNNRR..',
    '.NNnNNNN.R..',
    '..NnNNNN....',
    '..NNNNNN....',
    'SNNNKNNN....',
    '.N.NNNNN....',
    '...NN.NN....',
    '..NN...NN...',
    '.KK.....NN..',
    '........KK..',
  ], _np);
  static final ninjaCling2 = Sprite(const [
    '...NNNNN....',
    '..NNNNNNN...',
    '..NSWSSWN...',
    '.SNNNNNNR...',
    '.NNNNNNNRR..',
    '..NnNNNN.R..',
    '..NnNNNN....',
    'SNNNNNNN....',
    '.NNNKNNN....',
    '...NNNNN....',
    '...NN.NN....',
    '....NN.NN...',
    '....KK..NN..',
    '.........KK.',
  ], _np);
  static final ninjaJump = Sprite(const [
    '....NNNN....',
    '..NNNNNNNN..',
    '.NNSWSSWNNN.',
    '.NNNNNNNNNR.',
    'NNnNNNNNNNRR',
    'NNnNNKNNNN.R',
    'NNNNNNNNNN..',
    '.NNNNNNNNN..',
    '..NNNNNNN...',
    '...KK.KK....',
  ], _np);
  static final ninjaWin = Sprite(const [
    'S..NNNNN..S.',
    'N.NNNNNNN.N.',
    'N.NSWSSWN.N.',
    'NNNNNNNNNNN.',
    '..NNNNNNNR..',
    '..NnNNNNRR..',
    '..NnNNNN.R..',
    '..NNNKNN....',
    '..NNNNNN....',
    '...NN.NN....',
    '..NN...NN...',
    '..KK...KK...',
  ], _np);
  static final ninjaHurt = Sprite(const [
    '...NNNNN....',
    '..NNNNNNN...',
    '..NKNSKNN...',
    '..NSKSSKN...',
    '.SNNNNNNR...',
    '.NNNNNNNRR..',
    '..NNNNNN....',
    '..NN..NN....',
    '.KK....KK...',
  ], _np);
  static final crow1 = Sprite(const [
    'KK............',
    '.KKK......KK..',
    '..KKKK..KKKKK.',
    '...KKKKKKKWKYY',
    '....KKKKKKKKY.',
    '.....KKKKKK...',
    '......K..K....',
  ], const {'K': Color(0xFF15152A), 'W': Color(0xFFFF3B3B), 'Y': Color(0xFFFFB02A)});
  static final crow2 = Sprite(const [
    '..............',
    '..........KK..',
    '.....KKKKKKKK.',
    '...KKKKKKKWKYY',
    '.KKKKKKKKKKKY.',
    'KKK..KKKKKK...',
    'K.....K..K....',
  ], const {'K': Color(0xFF15152A), 'W': Color(0xFFFF3B3B), 'Y': Color(0xFFFFB02A)});
  static final shuriken = Sprite(const [
    '...G...',
    '...GG..',
    'GG.K.GG',
    '.GKKKG.',
    'GG.K.GG',
    '..GG...',
    '...G...',
  ], const {'G': Color(0xFFD8DCE8), 'K': Color(0xFF3C4058)});
  static final scroll = Sprite(const [
    'BBYYYYYYBB',
    'BYWWWWWWYB',
    '.YWKKWKWY.',
    '.YWWWWWWY.',
    '.YRRRRRRY.',
    '.YWKWKKWY.',
    'BYWWWWWWYB',
    'BBYYYYYYBB',
  ], const {
    'B': Color(0xFF8A5A2B),
    'Y': Color(0xFFFFE8A0),
    'W': Color(0xFFFFF8E0),
    'K': Color(0xFF3A2A40),
    'R': Color(0xFFE8453C),
  });
  static final warn = Sprite(const [
    '..RR..',
    '..RR..',
    '..RR..',
    '..RR..',
    '......',
    '..RR..',
  ], const {'R': Color(0xFFFF3B3B)});
  static final heart = Sprite(const [
    '.KK.KK.',
    'KRRKRRK',
    'KRWRRRK',
    'KRRRRRK',
    '.KRRRK.',
    '..KRK..',
    '...K...',
  ], const {'K': Color(0xFF10122A), 'R': Color(0xFFFF3B5C), 'W': Color(0xFFFFFFFF)});
  static final lantern = Sprite(const [
    '..KK..',
    '.RRRR.',
    'RYRRYR',
    'RRRRRR',
    'RYRRYR',
    '.RRRR.',
    '..KK..',
  ], const {'K': Color(0xFF10122A), 'R': Color(0xFFE8453C), 'Y': Color(0xFFFFD23F)});
  static final flag = Sprite(const [
    'KRRRR',
    'KRWRR',
    'KRRRR',
    'K....',
    'K....',
  ], const {'K': Color(0xFFD8DCE8), 'R': Color(0xFFE8453C), 'W': Color(0xFFFFFFFF)});
  static final head = Sprite(const [
    '.NNNN.',
    'NSWSWN',
    'NNNNNN',
    '.NNNN.',
  ], _np);
}
