import '../engine/engine.dart';

/// No.083 Brick Buster — pixel breakout with a heart-shaped wall.
///
/// Drag the paddle; where the ball hits the paddle sets its angle. Capsules:
/// M = multiball, W = wide paddle, F = fireball. Bomb bricks chain-explode.
/// Clear every brick to win; drop both balls and it's over.
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
const _white = Color(0xFFFCFCFC);
const _left = 24.0, _right = 336.0, _topY = 108.0;
const _paddleY = 572.0;

const _brickRows = [
  'HHHHHHHHHHHHK',
  'HMMMMMMMMMMDK',
  'HMMMMMMMMMMDK',
  'HDDDDDDDDDDDK',
  'KKKKKKKKKKKKK',
];
const _rowColors = [
  (Color(0xFFFC7C7C), Color(0xFFE82020), Color(0xFF981010)),
  (Color(0xFFFCB86C), Color(0xFFF87800), Color(0xFFA04800)),
  (Color(0xFFFCF09C), Color(0xFFF8D000), Color(0xFFA08000)),
  (Color(0xFFB8F8A0), Color(0xFF38C838), Color(0xFF187818)),
  (Color(0xFFA0D8FC), Color(0xFF2C88F8), Color(0xFF1848A0)),
  (Color(0xFFE0A8FC), Color(0xFFA03CF0), Color(0xFF581C90)),
];
final _bricks = [
  for (final (h, m, d) in _rowColors) Sprite(_brickRows, {'H': h, 'M': m, 'D': d, 'K': _k}),
];
final _bombBrick = Sprite([
  'HHHHHHHHHHHHK',
  'HMMMMKKKMMMDK',
  'HMMMKKKKKMMDK',
  'HDDDDKKKDDDDK',
  'KKKKKKKKKKKKK',
], {'H': const Color(0xFFD8D8D8), 'M': const Color(0xFF888888), 'D': const Color(0xFF484848), 'K': _k});
final _crackOverlay = Sprite([
  '.....K.......',
  '....K.KK.....',
  '...K....K....',
  '.............',
  '.............',
], {'K': _k});

final _ball = Sprite([
  '.WW.',
  'WWLW',
  'WLLG',
  '.GG.',
], {'W': _white, 'L': const Color(0xFFBCBCBC), 'G': const Color(0xFF787878)});
final _fireBall = Sprite([
  '.YY.',
  'YWWR',
  'YWRR',
  '.RR.',
], {'W': _white, 'Y': const Color(0xFFFCD800), 'R': const Color(0xFFF83800)});

Sprite _paddleSprite(int w) {
  final rows = <String>[];
  for (var y = 0; y < 6; y++) {
    final sb = StringBuffer();
    for (var x = 0; x < w; x++) {
      final edge = x < 4 || x >= w - 4;
      String ch;
      if ((x == 0 || x == w - 1) && (y == 0 || y == 5)) {
        ch = '.';
      } else if (edge) {
        ch = y == 0 ? 'r' : (y == 5 ? 'd' : 'R');
      } else {
        ch = y == 0 ? 'H' : (y >= 4 ? 'D' : 'S');
      }
      if (x == 4 || x == w - 5) ch = 'K';
      sb.write(ch);
    }
    rows.add(sb.toString());
  }
  return Sprite(rows, {
    'r': const Color(0xFFFC9C9C),
    'R': const Color(0xFFE82020),
    'd': const Color(0xFF881010),
    'H': const Color(0xFFF0F0F0),
    'S': const Color(0xFFA8B8C8),
    'D': const Color(0xFF586878),
    'K': const Color(0xFF202030),
  });
}

final _paddleN = _paddleSprite(24);
final _paddleW = _paddleSprite(36);

final _capsule = Sprite([
  '..KKKKKKKKKK..',
  '.KHHHHHHHHHHK.',
  'KHMMMMMMMMMMDK',
  'KMMMMMMMMMMMDK',
  'KMMMMMMMMMMMDK',
  '.KDDDDDDDDDDK.',
  '..KKKKKKKKKK..',
], {'K': _k, 'H': _white, 'M': const Color(0xFFBCBCBC), 'D': const Color(0xFF686868)});

final _wallSeg = Sprite([
  'KLLLLK',
  'KLMMDK',
  'KLMMDK',
  'KLMMDK',
  'KLMMDK',
  'KLMMDK',
  'KLMMDK',
  'KDDDDK',
], {'K': const Color(0xFF101828), 'L': const Color(0xFFD0D8E8), 'M': const Color(0xFF8898B0), 'D': const Color(0xFF4C5870)});

class _Brick {
  _Brick(this.col, this.row, this.kind);
  final int col, row;
  final int kind; // 0 normal, 1 bomb, 2 capsule
  bool alive = true;
  double flash = 0;
  Rect get rect => Rect.fromLTWH(_left + col * 39.0, 150 + row * 18.0, 39, 15);
}

class _Ball {
  _Ball(this.x, this.y, this.vx, this.vy);
  double x, y, vx, vy;
  bool dead = false;
  final trail = <Offset>[];
}

class _Cap {
  _Cap(this.x, this.y, this.type);
  double x, y;
  final int type; // 0 multi, 1 wide, 2 fire
  bool dead = false;
}

class _Pop {
  _Pop(this.s, this.x, this.y, this.col);
  final String s;
  final double x;
  double y;
  final Color col;
  double t = 0;
}

class G083 extends MiniGame {
  static const _shape = [
    '.##..##.',
    '########',
    '########',
    '.######.',
    '..####..',
    '...##...',
  ];
  final _bricksL = <_Brick>[];
  final _balls = <_Ball>[];
  final _caps = <_Cap>[];
  final _pops = <_Pop>[];
  double _t = 0;
  double _px0 = 180;
  double _paddleX = 180;
  double _squash = 0;
  int _lives = 2;
  bool _serving = true;
  double _serveT = .7;
  double _wide = 0;
  double _fire = 0;
  int _combo = 0;
  bool _done = false;
  double _heartBeat = 0;

  int get _remaining => _bricksL.where((b) => b.alive).length;

  @override
  void init() {
    const specials = {(2, 2): 1, (2, 5): 1, (4, 2): 2, (4, 5): 2, (1, 0): 2, (1, 7): 2, (5, 3): 2};
    for (var r = 0; r < _shape.length; r++) {
      for (var c = 0; c < 8; c++) {
        if (_shape[r][c] == '#') _bricksL.add(_Brick(c, r, specials[(r, c)] ?? 0));
      }
    }
  }

  double get _halfW => (_wide > 0 ? 36 : 24) * 1.5;
  double get _speed => (430 + min(_combo, 12) * 6.0) * (.85 + .15 * host.speed);

  void _launch() {
    _serving = false;
    final a = -pi / 2 + rand(-.45, .45);
    _balls.add(_Ball(_paddleX, _paddleY - 12, cos(a) * _speed, sin(a) * _speed));
    host.sfx(Sfx.pShoot, rate: .8);
  }

  @override
  void update(double dt) {
    _t += dt;
    _heartBeat += dt;
    _wide = max(0, _wide - dt);
    _fire = max(0, _fire - dt);
    _squash = M.approach(_squash, 0, 14, dt);
    _paddleX = M.approach(_paddleX, _px0, 30, dt).clamp(_left + _halfW, _right - _halfW);
    for (final b in _bricksL) {
      b.flash = max(0, b.flash - dt * 5);
    }
    for (var i = _pops.length - 1; i >= 0; i--) {
      final p = _pops[i];
      p.t += dt;
      p.y -= 40 * dt;
      if (p.t > .8) _pops.removeAt(i);
    }
    if (_done) {
      for (final b in _balls) {
        b.vy -= 400 * dt;
        b.y += b.vy * dt;
      }
      return;
    }
    if (_serving && !host.finished) {
      _serveT -= dt;
      if (_serveT <= 0) _launch();
    }

    // balls
    for (final b in _balls) {
      final steps = max(1, (sqrt(b.vx * b.vx + b.vy * b.vy) * dt / 4).ceil());
      final sdt = dt / steps;
      for (var s = 0; s < steps && !b.dead; s++) {
        _stepBall(b, sdt);
      }
      b.trail.insert(0, Offset(b.x, b.y));
      if (b.trail.length > 6) b.trail.removeLast();
    }
    final before = _balls.length;
    _balls.removeWhere((b) => b.dead);
    if (before > 0 && _balls.isEmpty && !host.finished) {
      _lives--;
      host.sfx(Sfx.pDie);
      host.shake(8);
      host.flash(const Color(0xFFF83838), .15);
      _combo = 0;
      _wide = 0;
      _fire = 0;
      if (_lives <= 0) {
        host.lose();
      } else {
        _serving = true;
        _serveT = .9;
        _pops.add(_Pop(host.tr('oops', 'OOPS'), 180, 480, const Color(0xFFF83838)));
      }
    }

    // capsules
    for (final cp in _caps) {
      cp.y += 150 * dt;
      if (cp.y > 660) cp.dead = true;
      if (!cp.dead && (cp.x - _paddleX).abs() < _halfW + 18 && (cp.y - _paddleY).abs() < 16) {
        cp.dead = true;
        _catch(cp.type);
      }
    }
    _caps.removeWhere((c) => c.dead);
  }

  void _stepBall(_Ball b, double dt) {
    // X axis
    b.x += b.vx * dt;
    if (b.x < _left + 6) {
      b.x = _left + 6;
      b.vx = b.vx.abs();
      _wallTick();
    } else if (b.x > _right - 6) {
      b.x = _right - 6;
      b.vx = -b.vx.abs();
      _wallTick();
    }
    var hit = _brickAt(b);
    if (hit != null) {
      _hitBrick(hit);
      if (_fire <= 0) {
        b.x -= b.vx * dt;
        b.vx = -b.vx;
      }
    }
    // Y axis
    b.y += b.vy * dt;
    if (b.y < _topY + 6) {
      b.y = _topY + 6;
      b.vy = b.vy.abs();
      _wallTick();
    }
    hit = _brickAt(b);
    if (hit != null) {
      _hitBrick(hit);
      if (_fire <= 0) {
        b.y -= b.vy * dt;
        b.vy = -b.vy;
      }
    }
    // paddle
    if (b.vy > 0 && b.y > _paddleY - 12 && b.y < _paddleY + 6 && (b.x - _paddleX).abs() < _halfW + 6) {
      final off = ((b.x - _paddleX) / (_halfW + 6)).clamp(-1.0, 1.0);
      final a = -pi / 2 + off * 1.05;
      final sp = _speed;
      b.vx = cos(a) * sp;
      b.vy = sin(a) * sp;
      b.y = _paddleY - 12;
      _squash = 1;
      if (_combo >= 4) {
        _pops.add(_Pop('${_combo}HIT', _paddleX, _paddleY - 40, const Color(0xFFFCD800)));
      }
      _combo = 0;
      host.sfx(Sfx.pHit, rate: .7 + off.abs() * .4, volume: .7);
    }
    if (b.y > 660) b.dead = true;
  }

  void _wallTick() => host.sfx(Sfx.tick, volume: .25, rate: 1.4);

  _Brick? _brickAt(_Ball b) {
    final r = Rect.fromCenter(center: Offset(b.x, b.y), width: 10, height: 10);
    for (final br in _bricksL) {
      if (br.alive && br.rect.overlaps(r)) return br;
    }
    return null;
  }

  void _hitBrick(_Brick br, {bool chained = false}) {
    if (!br.alive) return;
    br.alive = false;
    _combo++;
    final rc = br.rect.center;
    final pts = 10 * min(_combo, 10).toInt();
    host.addScore(pts);
    final (h, m, _) = _rowColors[br.row];
    host.fx.burst(rc, m, count: chained ? 6 : 10, speed: 200, size: 6, shape: PartShape.square, gravity: 700, colors: [h, m, _white]);
    host.sfx(Sfx.pCoin, volume: .5, rate: 1 + min(_combo, 14) * .07);
    if (_combo >= 3 && !chained) _pops.add(_Pop('x$_combo', rc.dx, rc.dy - 6, _combo >= 8 ? const Color(0xFFFC5CF8) : const Color(0xFFFCD800)));
    host.shake(chained ? 3 : 2);
    if (br.kind == 2 || (br.kind == 0 && chance(.12))) {
      final type = br.kind == 2 ? (rc.dy < 190 ? 0 : randInt(3)) : randInt(3);
      _caps.add(_Cap(rc.dx, rc.dy, type));
    }
    if (br.kind == 1) {
      host.sfx(Sfx.pExplode);
      host.shake(8);
      host.hitStop(.06);
      host.flash(const Color(0xFFFCD800), .1);
      host.fx.ring(rc, const Color(0xFFFCD800), size: 70);
      host.fx.burst(rc, const Color(0xFFF87800), count: 20, speed: 300, size: 8, shape: PartShape.square, gravity: 200,
          colors: const [Color(0xFFFCD800), Color(0xFFF87800), Color(0xFFF83800)]);
      _pops.add(_Pop(host.tr('boom', 'BOOM'), rc.dx, rc.dy - 20, const Color(0xFFF87800)));
      for (final o in _bricksL) {
        if (o.alive && (o.col - br.col).abs() <= 1 && (o.row - br.row).abs() <= 1) _hitBrick(o, chained: true);
      }
    }
    if (_remaining == 0 && !_done) {
      _done = true;
      host.sfx(Sfx.pPowerup);
      host.flash(_white, .2);
      host.fx.confetti();
      final stars = _lives >= 2 ? (host.timeLeft > 4 ? 3 : 2) : 1;
      host.win(stars: stars);
    }
  }

  void _catch(int type) {
    host.sfx(Sfx.pPowerup);
    host.punch(.03);
    host.fx.ring(Offset(_paddleX, _paddleY), const Color(0xFFFCD800), size: 50);
    switch (type) {
      case 0:
        final add = <_Ball>[];
        for (final b in _balls.take(4)) {
          final sp = sqrt(b.vx * b.vx + b.vy * b.vy);
          final a = atan2(b.vy, b.vx);
          for (final d in const [-.5, .5]) {
            add.add(_Ball(b.x, b.y, cos(a + d) * sp, sin(a + d) * sp));
          }
        }
        if (_balls.isEmpty && _serving) {
          _launch();
        }
        _balls.addAll(add);
        _pops.add(_Pop(host.tr('multi', 'MULTI'), _paddleX, _paddleY - 40, const Color(0xFF3CE8FC)));
      case 1:
        _wide = 9;
        _pops.add(_Pop(host.tr('wide', 'WIDE'), _paddleX, _paddleY - 40, const Color(0xFF38C838)));
      default:
        _fire = 5;
        _pops.add(_Pop(host.tr('fire', 'FIRE'), _paddleX, _paddleY - 40, const Color(0xFFF87800)));
    }
  }

  // ------------------------------------------------------------ input ---

  @override
  void onDown(Offset p) => _px0 = p.dx;

  @override
  void onMove(Offset p) => _px0 = p.dx;

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'left') _px0 = _paddleX - 50;
    if (key == 'right') _px0 = _paddleX + 50;
    if (key == 'action' && _serving) _launch();
  }

  @override
  void onTimeUp() {
    if (_remaining <= 3) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ----------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    // background: dark pixel tiles with a slow diagonal glow
    Retro.tiles(c, const Rect.fromLTWH(0, 36, 360, 604), 24, const Color(0xFF12103A), const Color(0xFF181548));
    final glow = Paint()..color = const Color(0x1450A0FF);
    for (var i = 0; i < 6; i++) {
      final x = ((_t * 30 + i * 120) % 720) - 360;
      c.drawPath(
          Path()
            ..moveTo(x, 640)
            ..lineTo(x + 60, 640)
            ..lineTo(x + 460, 36)
            ..lineTo(x + 400, 36)
            ..close(),
          glow);
    }
    // little pixel diamonds pattern
    final dp = Paint()..color = const Color(0xFF232060);
    for (var y = 132.0; y < 640; y += 48) {
      for (var x = 36.0; x < 336; x += 48) {
        c.drawRect(Rect.fromLTWH(x + 9, y + 6, 6, 6), dp);
      }
    }
    // walls
    for (var y = _topY - 12; y < 640; y += 24) {
      _wallSeg.draw(c, Offset(_left - 18, y), scale: 3);
      _wallSeg.draw(c, Offset(_right, y), scale: 3);
    }
    c.drawRect(const Rect.fromLTWH(_left - 18, _topY - 18, _right - _left + 36, 18), Paint()..color = const Color(0xFF8898B0));
    c.drawRect(const Rect.fromLTWH(_left - 18, _topY - 18, _right - _left + 36, 3), Paint()..color = const Color(0xFFD0D8E8));
    c.drawRect(const Rect.fromLTWH(_left - 18, _topY - 3, _right - _left + 36, 3), Paint()..color = const Color(0xFF4C5870));
    for (var x = _left; x < _right; x += 48) {
      c.drawRect(Rect.fromLTWH(x + 20, _topY - 12, 6, 6), Paint()..color = const Color(0xFF101828));
    }

    // bricks — heart beats gently
    final beat = 1 + .03 * pow(max(0, sin(_heartBeat * 5)), 8);
    c.save();
    c.translate(180, 200);
    c.scale(beat);
    c.translate(-180, -200);
    for (final b in _bricksL) {
      if (!b.alive) continue;
      final r = b.rect;
      final s = b.kind == 1 ? _bombBrick : _bricks[b.row];
      s.draw(c, r.topLeft, scale: 3);
      if (b.kind == 2) {
        final a = M.wave(_t, 2);
        c.drawRect(Rect.fromLTWH(r.left + 15, r.top + 5, 6, 3), Paint()..color = Color.fromRGBO(255, 255, 255, .4 + .6 * a));
      }
      if (b.kind == 1) {
        final a = (_t * 4).floor().isEven;
        c.drawRect(Rect.fromLTWH(r.left + 18, r.top, 3, 3), Paint()..color = a ? const Color(0xFFF83800) : const Color(0xFFFCD800));
      }
      if (b.row == 0 && b.kind == 0 && b.col.isEven) _crackOverlay.draw(c, r.topLeft, scale: 3, opacity: .25);
    }
    c.restore();

    // capsules
    for (final cp in _caps) {
      final col = const [Color(0xFF3CE8FC), Color(0xFF38C838), Color(0xFFF87800)][cp.type];
      final wob = sin(_t * 10 + cp.x) * 3;
      _capsule.drawCentered(c, Offset(cp.x, cp.y), scale: 3);
      c.drawRect(Rect.fromCenter(center: Offset(cp.x, cp.y), width: 30, height: 9), Paint()..color = col);
      _px(c, const ['M', 'W', 'F'][cp.type], Offset(cp.x + wob * .3, cp.y - 7), 2, _white, align: 0, shadow: _k);
    }

    // balls
    for (final b in _balls) {
      for (var i = 0; i < b.trail.length; i++) {
        final o = b.trail[i];
        final a = (1 - i / b.trail.length) * .35;
        c.drawRect(Rect.fromCenter(center: o, width: 9 - i.toDouble(), height: 9 - i.toDouble()),
            Paint()..color = (_fire > 0 ? const Color(0xFFF87800) : const Color(0xFF9CC8FC)).withValues(alpha: a));
      }
      (_fire > 0 ? _fireBall : _ball).drawCentered(c, Offset(b.x.roundToDouble(), b.y.roundToDouble()), scale: 3);
    }
    if (_serving && !host.finished) {
      _ball.drawCentered(c, Offset(_paddleX, _paddleY - 12), scale: 3);
    }

    // paddle
    final ps = _wide > 0 ? _paddleW : _paddleN;
    final sq = _squash;
    c.save();
    c.translate(_paddleX, _paddleY + 9);
    c.scale(1 + sq * .08, 1 - sq * .25);
    ps.drawCentered(c, Offset.zero, scale: 3);
    c.restore();
    if (_wide > 0 && _wide < 2 && (_t * 8).floor().isEven) {
      c.drawRect(Rect.fromCenter(center: Offset(_paddleX, _paddleY + 24), width: 20, height: 3), Paint()..color = _white);
    }

    for (final p in _pops) {
      _px(c, p.s, Offset(p.x, p.y), 2, p.col, align: 0, shadow: _k);
    }

    // HUD
    _px(c, host.tr('score', 'SCORE'), const Offset(14, 44), 2, const Color(0xFFF83838), shadow: _k);
    _px(c, host.score.toString().padLeft(5, '0'), const Offset(14, 62), 2, _white, shadow: _k);
    _px(c, '$_remaining', const Offset(180, 54), 3, _remaining <= 5 ? const Color(0xFFFCD800) : _white, align: 0, shadow: _k);
    for (var i = 0; i < _lives; i++) {
      _ball.draw(c, Offset(334 - i * 18.0, 60), scale: 3);
    }
    _px(c, host.tr('balls', 'BALLS'), const Offset(346, 44), 2, const Color(0xFF3CE8FC), align: 1, shadow: _k);
    if (_fire > 0) {
      c.drawRect(Rect.fromLTWH(_left, 100, (_right - _left) * _fire / 5, 3), Paint()..color = const Color(0xFFF87800));
    }

    if (host.time < 2.2 && !host.finished) {
      D.hand(c, Offset(180 + sin(_t * 3) * 70, 600), _t);
      _px(c, '< ${host.tr('drag', 'DRAG')} >', const Offset(180, 510), 3, _white, align: 0, shadow: _k);
    }
    Retro.scanlines(c, alpha: .12);
  }
}
