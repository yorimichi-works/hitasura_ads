import '../engine/engine.dart';

/// No.117 Coin Pusher — drop coins in front of the sliding shelf, shove the
/// overhanging pile off the edge. Time a drop into the moving CHANCE slot for
/// a coin rain.
class G117 extends MiniGame {
  static const _target = 25;
  static const _fw = 300.0; // field width (world units)
  static const _edge = 300.0; // front edge (world y)
  static const _r = 13.0;
  static const _auto = bool.fromEnvironment('AUTOPLAY');

  final List<_Coin> _coins = [];
  final List<_Drop> _drops = [];
  final List<_Fall> _falls = [];
  int _hand = 36;
  int _won = 0;
  double _shownWon = 0;
  double _t = 0;
  double _push = 72;
  double _cd = 0;
  double _slotX = 150;
  double _slotFlash = 0;
  double _lastFall = -10;
  int _streak = 0;
  double _idle = 0;
  double _trayBump = 0;
  double _aimX = 180;
  bool _done = false;

  @override
  void init() {
    // tightly packed pile that is JUST about to go over the edge
    var row = 0;
    for (var y = 124.0; y < _edge - 6; y += _r * 1.74, row++) {
      final odd = row.isOdd;
      for (var x = _r + (odd ? _r : 0); x <= _fw - _r; x += _r * 2.02) {
        _coins.add(_Coin(x + rand(-1.5, 1.5), y + rand(-1.5, 1.5), _r, _CoinKind.normal));
      }
    }
    // the tempting big gold coin + gems near the edge
    _coins.add(_Coin(rand(80, 220), _edge - 36, 21, _CoinKind.big));
    _coins.add(_Coin(rand(20, 120), _edge - 50, 12, _CoinKind.gem));
    _coins.add(_Coin(rand(180, 280), _edge - 58, 12, _CoinKind.gem));
    for (var i = 0; i < 6; i++) {
      _relax();
    }
  }

  // --------------------------------------------------------- projection ---
  static double _scale(double y) => .8 + .28 * (y / _edge);
  static Offset _proj(double x, double y) {
    final s = _scale(y);
    return Offset(180 + (x - _fw / 2) * s * 1.02, 238 + y * .98);
  }

  static double _unprojX(double sx, double y) => (sx - 180) / (_scale(y) * 1.02) + _fw / 2;

  // -------------------------------------------------------------- logic ---
  void _relax() {
    final n = _coins.length;
    for (var it = 0; it < 4; it++) {
      for (var i = 0; i < n; i++) {
        final a = _coins[i];
        for (var j = i + 1; j < n; j++) {
          final b = _coins[j];
          final dx = b.x - a.x, dy = b.y - a.y;
          final rr = a.r + b.r - 1;
          if (dx.abs() >= rr || dy.abs() >= rr) continue;
          final d2 = dx * dx + dy * dy;
          if (d2 >= rr * rr) continue;
          final d = sqrt(d2) + 1e-4;
          final ov = (rr - d) / 2;
          final nx = dx / d, ny = dy / d;
          // heavier big coin moves less
          final wa = b.r / (a.r + b.r), wb = a.r / (a.r + b.r);
          a.x -= nx * ov * 2 * wa;
          a.y -= ny * ov * 2 * wa;
          b.x += nx * ov * 2 * wb;
          b.y += ny * ov * 2 * wb;
        }
      }
      for (final c in _coins) {
        if (c.x < c.r) c.x = c.r;
        if (c.x > _fw - c.r) c.x = _fw - c.r;
        if (c.y < _push + c.r) c.y = _push + c.r;
      }
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _cd -= dt;
    _slotFlash = M.approach(_slotFlash, 0, 3, dt);
    _trayBump = M.approach(_trayBump, 0, 8, dt);
    _shownWon = M.approach(_shownWon, _won.toDouble(), 10, dt);
    _push = 70 + 36 * sin(_t * 2.5 * host.speed);
    _slotX = 150 + sin(_t * 1.9 * host.speed) * 105;
    if (_auto && !host.finished) _drop(_proj(150 + sin(_t * 3) * 100, 60).dx);

    // airborne drops
    for (final d in [..._drops]) {
      d.t += dt;
      if (!d.checkedSlot && d.t >= .18) {
        d.checkedSlot = true;
        if ((d.wx - _slotX).abs() < 16) {
          d.dead = true;
          _jackpot();
          continue;
        }
      }
      if (d.t >= .3) {
        d.dead = true;
        final c = _Coin(d.wx.clamp(_r, _fw - _r), _push + _r + 2, _r, _CoinKind.normal)..bounce = 1;
        _coins.add(c);
        host.sfx(Sfx.clang, volume: .35, rate: 1.6 + rand(0, .3));
      }
    }
    _drops.removeWhere((d) => d.dead);

    // pusher contact + relax
    _relax();
    for (final c in _coins) {
      c.bounce = M.approach(c.bounce, 0, 8, dt);
    }

    // coins over the edge
    for (var i = _coins.length - 1; i >= 0; i--) {
      final c = _coins[i];
      if (c.y > _edge) {
        _coins.removeAt(i);
        _fallOff(c);
      }
    }
    if (_t - _lastFall > .6) _streak = 0;

    for (final f in _falls) {
      f.vy += 1500 * dt;
      f.p += Offset(0, f.vy * dt);
      f.spin += dt * 8;
      if (f.p.dy > 590 && !f.landed) {
        f.landed = true;
        _trayBump = 1;
      }
    }
    _falls.removeWhere((f) => f.p.dy > 700);

    if (!host.finished && !_done) {
      if (_hand <= 0 && _drops.isEmpty) {
        _idle += dt;
        if (_idle > 2.2) {
          _done = true;
          host.fx.pop(host.tr('out_of_coins', 'NO COINS'), const Offset(180, 330), color: Pal.red, size: 32);
          host.lose();
        }
      }
    }
  }

  void _fallOff(_Coin c) {
    final v = switch (c.kind) { _CoinKind.big => 5, _CoinKind.gem => 3, _CoinKind.normal => 1 };
    _won += v;
    _streak++;
    _lastFall = _t;
    _idle = 0;
    final at = _proj(c.x, _edge);
    _falls.add(_Fall(at, c.kind, c.r * _scale(_edge)));
    if (c.kind == _CoinKind.big) {
      host.sfx(Sfx.jingleWin, volume: .6);
      host.sfx(Sfx.coins);
      host.shake(8, .35);
      host.flash(Pal.yellow, .18);
      host.fx.coins(at, count: 24, speed: 480);
      host.fx.pop(host.tr('big_coin', 'BIG COIN!'), at + const Offset(0, -40), color: Pal.yellow, size: 34, life: 1.1);
    } else if (c.kind == _CoinKind.gem) {
      host.sfx(Sfx.gem);
      host.fx.burst(at, Pal.sky, count: 14, shape: PartShape.star, speed: 260);
      host.fx.pop('+3', at + const Offset(0, -30), color: Pal.sky, size: 28);
    } else {
      host.sfx(Sfx.coin, rate: 1 + min(_streak, 12) * .06, volume: .8);
      host.fx.sparkle(at, count: 3, radius: 10, color: Pal.yellow);
      host.fx.pop('+1', at + const Offset(0, -24), color: Pal.yellow, size: 20, life: .6);
    }
    if (_streak >= 4 && _streak % 2 == 0) {
      host.fx.pop('${host.tr('combo', 'COMBO')} x$_streak', const Offset(180, 470), color: Pal.pink, size: 26 + min(_streak, 12).toDouble());
      host.sfx(Sfx.combo, rate: 1 + _streak * .04);
      host.punch(.02);
    }
    if (!host.finished && _won >= _target) {
      final left = host.timeLeft;
      host.fx.coins(const Offset(180, 560), count: 40, speed: 620);
      host.fx.pop(host.tr('jackpot', 'JACKPOT!'), const Offset(180, 300), color: Pal.yellow, size: 48, life: 1.4);
      host.win(stars: left > 6 ? 3 : (left > 2.5 ? 2 : 1));
    }
  }

  void _jackpot() {
    _slotFlash = 1;
    host.sfx(Sfx.ssr);
    host.sfx(Sfx.coins, volume: .8);
    host.shake(7, .3);
    host.flash(const Color(0xFFFFE066), .2);
    final sp = Offset(_proj(_slotX, 40).dx, 170);
    host.fx.ring(sp, Pal.yellow, size: 110, life: .5);
    host.fx.burst(sp, Pal.yellow, count: 26, shape: PartShape.star, speed: 300, colors: Pal.candy);
    host.fx.pop(host.tr('chance', 'CHANCE!'), sp + const Offset(0, -30), color: Pal.pink, size: 34, life: 1.2);
    // coin rain onto the field + refund
    for (var i = 0; i < 9; i++) {
      _drops.add(_Drop(rand(20, _fw - 20))
        ..t = -i * .05
        ..checkedSlot = true);
    }
    _hand += 4;
  }

  void _drop(double sx) {
    if (host.finished || _hand <= 0 || _cd > 0) return;
    _cd = .13;
    _hand--;
    _aimX = sx.clamp(40.0, 320.0);
    final wx = _unprojX(_aimX, 40).clamp(_r, _fw - _r);
    _drops.add(_Drop(wx));
    host.sfx(Sfx.click, rate: 1.4);
  }

  @override
  void onDown(Offset p) => _drop(p.dx);

  @override
  void onMove(Offset p) => _aimX = p.dx.clamp(40.0, 320.0);

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'left') _aimX = max(40, _aimX - 24);
    if (key == 'right') _aimX = min(320, _aimX + 24);
    if (key == 'action' || key == 'down') _drop(_aimX);
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    // arcade room
    D.gradientBg(c, const [Color(0xFF3B1466), Color(0xFF1A0B33)]);
    D.rays(c, const Offset(180, 150), 500, const Color(0x10FFFFFF), count: 14, t: _t * .2);

    // cabinet top: marquee + chance slot wall
    D.rrect(c, const Rect.fromLTRB(14, 42, 346, 240), 22, const Color(0xFFE23C8A),
        border: Pal.ink,
        borderWidth: 4,
        gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF5FA8), Color(0xFFB0206A)]));
    // bulbs
    for (var i = 0; i < 15; i++) {
      final on = (i + (_t * 7).floor()) % 3 == 0 || _slotFlash > .1;
      final p = Offset(28 + i * 21.7, 52);
      c.drawCircle(p, on ? 6.5 : 4.5, D.fill(on ? const Color(0x88FFE066) : const Color(0x00000000)));
      c.drawCircle(p, 4, D.fill(on ? const Color(0xFFFFF3B0) : const Color(0xFF8A2A5C)));
    }
    // coin launcher rail
    D.rrect(c, const Rect.fromLTRB(30, 64, 330, 84), 10, const Color(0xFF2A0F40), border: Pal.ink, borderWidth: 2.5);
    D.coin(c, Offset(_aimX, 74), 9, spin: _t);
    // back wall with chance slot
    const wall = Rect.fromLTRB(30, 92, 330, 232);
    D.rrect(c, wall, 14, const Color(0xFF1C0F38), border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * pi * 2 + _t * .6;
      c.drawCircle(Offset(180 + cos(a) * 110, 160 + sin(a) * 42), 3, D.fill(D.hsv(i * 30 + _t * 120, .7, 1, .6)));
    }
    D.text(c, host.tr('chance', 'CHANCE!'), const Offset(180, 118), size: 20, color: D.hsv(_t * 200, .5, 1), stroke: Pal.ink);
    final sp = _proj(_slotX, 40);
    final slotRect = Rect.fromCenter(center: Offset(sp.dx, 170), width: 40, height: 22);
    D.rrect(c, slotRect.inflate(6 + _slotFlash * 10), 12, Pal.yellow.withValues(alpha: .25 + _slotFlash * .5));
    D.rrect(c, slotRect, 10, const Color(0xFF05020C), border: Pal.yellow, borderWidth: 3);
    D.arrow(c, Offset(sp.dx, 140 + sin(_t * 8) * 3), const Offset(0, 1), 18, Pal.yellow, width: 6);

    // playfield
    final tl = _proj(0, 0), tr = _proj(_fw, 0), br = _proj(_fw, _edge), bl = _proj(0, _edge);
    final field = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();
    c.drawPath(
        field,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3D2A7A), Color(0xFF6B4BC9)])
              .createShader(Rect.fromPoints(tl, br)));
    // field lane stripes
    for (var i = 1; i < 6; i++) {
      final x = _fw * i / 6;
      c.drawLine(_proj(x, 0), _proj(x, _edge), D.stroke(const Color(0x22FFFFFF), 2));
    }
    // side walls (acrylic)
    for (final side in [0.0, _fw]) {
      final a = _proj(side, 0), b = _proj(side, _edge);
      final dir = side == 0 ? -1.0 : 1.0;
      final wallP = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx + dir * 12, b.dy - 4)
        ..lineTo(a.dx + dir * 8, a.dy - 4)
        ..close();
      c.drawPath(wallP, D.fill(const Color(0x8899DDFF)));
      c.drawPath(wallP, D.stroke(const Color(0xCCE6F6FF), 2));
    }

    // coins behind the pusher front never exist; draw pusher, then coins by depth
    _drawPusher(c);
    _coins.sort((a, b) => a.y.compareTo(b.y));
    for (final co in _coins) {
      _drawCoin(c, co);
    }
    // airborne drops (fall from rail to field)
    for (final d in _drops) {
      if (d.t < 0) continue;
      final land = _proj(d.wx, _push + _r);
      final k = (d.t / .3).clamp(0.0, 1.0);
      final y = M.lerp(80, land.dy, k * k);
      final x = M.lerp(_aimXFor(d.wx), land.dx, k);
      D.coin(c, Offset(x, y), 11 + k * 2, spin: d.t * 3);
    }

    // front edge lip with warning lights
    D.rrect(c, Rect.fromLTRB(bl.dx - 6, bl.dy - 2, br.dx + 6, bl.dy + 12), 5, const Color(0xFFFFC53D), border: Pal.ink, borderWidth: 2.5);
    for (var i = 0; i < 12; i++) {
      final x = bl.dx + 8 + i * (br.dx - bl.dx - 16) / 11;
      final on = (i + (_t * 10).floor()) % 2 == 0;
      c.drawCircle(Offset(x, bl.dy + 5), 3, D.fill(on ? Pal.red : const Color(0xFF7A3A10)));
    }

    // tray
    const tray = Rect.fromLTRB(14, 556, 346, 636);
    D.rrect(c, tray, 18, const Color(0xFF2A1250), border: Pal.ink, borderWidth: 4);
    D.rrect(c, Rect.fromLTRB(26, 566 + _trayBump * 3, 334, 626), 12, const Color(0xFF12071F));
    // pile of won coins inside tray
    for (var i = 0; i < min(_won, 40); i++) {
      final x = 50 + (i * 37 % 260).toDouble();
      final y = 616 - (i ~/ 7) * 5.0 + _trayBump * 2;
      c.drawOval(Rect.fromCenter(center: Offset(x, y + 2), width: 24, height: 10), D.fill(const Color(0xFFB8860B)));
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 24, height: 10), D.fill(Pal.gold));
    }
    for (final f in _falls) {
      switch (f.kind) {
        case _CoinKind.gem:
          D.gem(c, f.p, 11, Pal.sky);
        default:
          D.coin(c, f.p, f.r, spin: f.spin * .1);
      }
    }
    // counter
    final full = _won >= _target;
    D.text(c, '${min(_shownWon.round(), 99)}', const Offset(150, 590),
        size: 38 + _trayBump * 6, color: full ? Pal.lime : Pal.yellow, stroke: Pal.ink, strokeWidth: 7);
    D.text(c, '/$_target', const Offset(200, 598), size: 18, color: Pal.white, stroke: Pal.ink, anchor: Alignment.centerLeft);
    // coins in hand
    D.rrect(c, const Rect.fromLTRB(250, 568, 334, 598), 12, const Color(0xCC000000));
    D.coin(c, const Offset(266, 583), 9);
    D.text(c, 'x$_hand', const Offset(280, 583), size: 16, color: _hand <= 5 ? Pal.red : Pal.white, anchor: Alignment.centerLeft);

    if (host.time < 2.4 && _hand >= 34) {
      D.hand(c, Offset(_proj(_slotX, 0).dx, 200), _t);
      D.text(c, host.tr('tap', 'TAP!'), const Offset(180, 216), size: 24, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  double _aimXFor(double wx) => _proj(wx, 40).dx;

  void _drawPusher(Canvas c) {
    final a = _proj(0, 0), b = _proj(_fw, 0), cc = _proj(_fw, _push), d = _proj(0, _push);
    final top = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(cc.dx, cc.dy)
      ..lineTo(d.dx, d.dy)
      ..close();
    c.drawPath(
        top,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB9C2D6), Color(0xFFE8EEFA)])
              .createShader(Rect.fromPoints(a, cc)));
    // chrome stripes
    for (var i = 1; i < 8; i++) {
      final x = _fw * i / 8;
      c.drawLine(_proj(x, 2), _proj(x, _push - 2), D.stroke(const Color(0x33000000), 2));
    }
    // front face
    final face = Rect.fromLTRB(d.dx, d.dy, cc.dx, d.dy + 14);
    D.rrect(c, face, 3, const Color(0xFF7E88A3), border: Pal.ink, borderWidth: 2.5);
    for (var i = 0; i < 10; i++) {
      final x = face.left + 10 + i * (face.width - 20) / 9;
      c.drawCircle(Offset(x, face.center.dy), 2.5, D.fill(D.hsv(i * 36 + _t * 200, .7, 1)));
    }
  }

  void _drawCoin(Canvas c, _Coin co) {
    final s = _scale(co.y);
    var p = _proj(co.x, co.y);
    final danger = co.y > _edge - co.r * .7;
    if (danger) p += Offset(sin(_t * 50 + co.x) * 1.2, 0);
    p += Offset(0, -co.bounce * 8);
    final w = co.r * 2 * s * 1.02, h = co.r * 1.1 * s;
    switch (co.kind) {
      case _CoinKind.gem:
        c.drawOval(Rect.fromCenter(center: p + const Offset(0, 3), width: w, height: h), D.fill(const Color(0x55000000)));
        D.gem(c, p + Offset(0, -h * .4), co.r * s, Pal.sky);
        if ((_t * 2 + co.x * .01) % 1 < .5) D.star(c, p + Offset(w * .35, -h * 1.2), 3.5, Pal.white);
      case _CoinKind.big || _CoinKind.normal:
        final big = co.kind == _CoinKind.big;
        c.drawOval(Rect.fromCenter(center: p + Offset(0, 3.5 * s), width: w, height: h),
            D.fill(big ? const Color(0xFF9A6A00) : const Color(0xFFA87A12)));
        c.drawOval(Rect.fromCenter(center: p, width: w, height: h), D.fill(big ? const Color(0xFFFFD84A) : Pal.gold));
        c.drawOval(Rect.fromCenter(center: p, width: w * .72, height: h * .66), D.stroke(const Color(0xFFE0A019), 1.6 * s));
        c.drawOval(Rect.fromCenter(center: p + Offset(-w * .18, -h * .15), width: w * .25, height: h * .22),
            D.fill(const Color(0xAAFFFFFF)));
        if (big) {
          c.save();
          c.translate(p.dx, p.dy);
          c.scale(1, .52);
          D.star(c, Offset.zero, co.r * s * .5, const Color(0xFFFF9E1F), border: const Color(0xFF9A6A00));
          c.restore();
          if ((_t * 2) % 1 < .5) D.star(c, p + Offset(w * .4, -h * .7), 4, Pal.white);
        }
        if (danger) c.drawOval(Rect.fromCenter(center: p, width: w + 4, height: h + 3), D.stroke(const Color(0x88FFFFFF), 1.5));
    }
  }
}

enum _CoinKind { normal, big, gem }

class _Coin {
  _Coin(this.x, this.y, this.r, this.kind);
  double x, y;
  final double r;
  final _CoinKind kind;
  double bounce = 0;
}

class _Drop {
  _Drop(this.wx);
  final double wx;
  double t = 0;
  bool dead = false;
  bool checkedSlot = false;
}

class _Fall {
  _Fall(this.p, this.kind, this.r);
  Offset p;
  final _CoinKind kind;
  final double r;
  double vy = -60;
  double spin = 0;
  bool landed = false;
}
