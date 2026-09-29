import '../engine/engine.dart';

/// No.087 Bullet Heaven — vertical danmaku vs. a giant pop-up-window boss.
///
/// Drag anywhere (relative movement) to steer a tiny ship that auto-fires.
/// Only the 1-dot core is the hitbox; brushing past bullets = GRAZE bonus.
/// Three phases: spirals, rings, then everything. Kill it or survive.
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
const _pink = Color(0xFFF858B8);
const _cyan = Color(0xFF58E8F8);
const _yellow = Color(0xFFF8E048);
const _red = Color(0xFFF83838);
const _violet = Color(0xFFA070F8);

List<String> _bossRows() {
  const w = 36, h = 26;
  final rows = <String>[];
  for (var y = 0; y < h; y++) {
    final sb = StringBuffer();
    for (var x = 0; x < w; x++) {
      var ch = 'N';
      if (y == 0 || y == h - 1 || x == 0 || x == w - 1) {
        ch = 'K';
      } else if (y <= 4) {
        ch = 'T';
        if (y == 1) ch = 'L';
        // minimize box
        if (x >= 23 && x <= 27) ch = (y == 3 && x >= 24 && x <= 26) ? 'W' : 'Y';
        // close box with X
        if (x >= 29 && x <= 33) {
          final lx = x - 29, ly = y - 1;
          ch = (ly >= 0 && ly <= 3 && (lx == ly + 1 || lx == 3 - ly)) ? 'W' : 'R';
        }
      } else if (y == 5) {
        ch = 'K';
      } else {
        // screen with scanline-ish rows
        ch = y.isEven ? 'N' : 'n';
        // eye whites
        final e1 = (x - 10.5) * (x - 10.5) / 18 + (y - 11.5) * (y - 11.5) / 7;
        final e2 = (x - 25.5) * (x - 25.5) / 18 + (y - 11.5) * (y - 11.5) / 7;
        if (e1 < 1 || e2 < 1) ch = 'W';
        // angry brows
        if (y == 8 && ((x >= 6 && x <= 9) || (x >= 27 && x <= 30))) ch = 'R';
        if (y == 9 && ((x >= 9 && x <= 13) || (x >= 23 && x <= 27))) ch = 'R';
        // mouth
        if (y >= 17 && y <= 21 && x >= 9 && x <= 26) {
          ch = 'K';
          if (y == 17 && x.isEven) ch = 'W';
          if (y == 18 && x % 4 == 0) ch = 'W';
          if (y == 21 && x.isOdd) ch = 'W';
          if (y == 20 && x % 4 == 1) ch = 'W';
          if ((y == 19) && x >= 13 && x <= 22) ch = 'M';
        }
      }
      sb.write(ch);
    }
    rows.add(sb.toString());
  }
  return rows;
}

final _bossR = _bossRows();
Sprite _bossSprite(Color title, Color screen) => Sprite(_bossR, {
      'K': _k,
      'T': title,
      'L': Color.lerp(title, _white, .45)!,
      'Y': _yellow,
      'R': _red,
      'W': _white,
      'N': screen,
      'n': Color.lerp(screen, _k, .25)!,
      'M': const Color(0xFFB02050),
    });
final _boss1 = _bossSprite(const Color(0xFF7038D8), const Color(0xFF203880));
final _boss3 = _bossSprite(const Color(0xFFD82848), const Color(0xFF581830));

final _pod = Sprite([
  '..KKKK..',
  '.KGGGGK.',
  'KGLLGGDK',
  'KGLGGGDK',
  'KGGGGGDK',
  'KDDDDDDK',
  '.KRRRRK.',
  '..KRRK..',
  '...KK...',
], {'K': _k, 'G': const Color(0xFF8890B0), 'L': _white, 'D': const Color(0xFF484C68), 'R': _red});

const _shipTop = [
  '.....W.....',
  '....WCW....',
  '....WCW....',
  '...WWCWW...',
  '..BWWCWWB..',
  '.BBWWWWWBB.',
  'BBBWRRRWBBB',
  'BB.WRRRW.BB',
  'B..WWWWW..B',
];
final _shipPal = <String, Color>{
  'W': _white,
  'C': _cyan,
  'B': const Color(0xFF3C68E8),
  'R': _pink,
  'O': const Color(0xFFF88820),
  'Y': _yellow,
};
final _shipA = Sprite([..._shipTop, '...O.O.O...', '...Y.Y.Y...', '.....Y.....'], _shipPal);
final _shipB = Sprite([..._shipTop, '...Y.O.Y...', '....Y.Y....', '...........'], _shipPal);

class _B {
  _B(this.x, this.y, this.vx, this.vy, this.col, this.r);
  double x, y, vx, vy;
  final Color col;
  final double r;
  bool grazed = false;
  bool dead = false;
}

class _Shot {
  _Shot(this.x, this.y, this.vx);
  double x, y;
  final double vx;
  bool dead = false;
}

class _Star {
  _Star(this.x, this.y, this.z);
  double x, y;
  final double z;
}

class G087 extends MiniGame {
  static const _bossMax = 280;
  final _bullets = <_B>[];
  final _shots = <_Shot>[];
  final _stars = <_Star>[];
  double _t = 0;
  Offset _ship = const Offset(180, 540);
  Offset _dragP = Offset.zero, _dragS = Offset.zero;
  int _lives = 3;
  double _invuln = 0;
  int _hp = _bossMax;
  double _hpShown = _bossMax.toDouble();
  int _phase = 1;
  double _phaseBanner = 0;
  double _bossX = 180;
  double _bossHit = 0;
  double _fireT = 0;
  double _spiralA = 0;
  double _spiralT = 0, _ringT = 1.0, _aimT = 1.4;
  int _ringN = 0;
  int _grazes = 0;
  double _grazeGlow = 0;
  double _hitSfxT = 0;
  bool _dead = false;
  bool _bossDead = false;
  double _bossDeadT = 0;
  double _enter = 0;
  int _hitsTaken = 0;
  double _keyDx = 0, _keyDy = 0;

  static const _bossY = 128.0;

  @override
  void init() {
    for (var i = 0; i < 60; i++) {
      _stars.add(_Star(rand(0, 360), rand(36, 640), (i % 3 + 1).toDouble()));
    }
  }

  Offset get _bossC => Offset(_bossX, _bossY + (1 - M.easeOutBack(M.clamp01(_enter / 1.2))) * -220);

  void _spawn(double x, double y, double ang, double spd, Color col, [double r = 5]) {
    if (_bullets.length > 380) return;
    _bullets.add(_B(x, y, cos(ang) * spd, sin(ang) * spd, col, r));
  }

  @override
  void update(double dt) {
    _t += dt;
    _enter += dt;
    _invuln = max(0, _invuln - dt);
    _bossHit = max(0, _bossHit - dt * 6);
    _grazeGlow = max(0, _grazeGlow - dt * 3);
    _phaseBanner = max(0, _phaseBanner - dt);
    _hitSfxT -= dt;
    _hpShown = M.approach(_hpShown, _hp.toDouble(), 5, dt);
    for (final s in _stars) {
      s.y += 40 * s.z * dt * (1 + (_phase - 1) * .5);
      if (s.y > 640) {
        s.y = 36;
        s.x = rand(0, 360);
      }
    }
    if (_keyDx != 0 || _keyDy != 0) {
      _ship = Offset((_ship.dx + _keyDx * 220 * dt).clamp(12, 348), (_ship.dy + _keyDy * 220 * dt).clamp(70, 626));
    }

    // boss movement
    if (!_bossDead) {
      _bossX = 180 + sin(_t * (.6 + _phase * .15)) * (50 + _phase * 12);
    } else {
      _bossDeadT += dt;
      if (_bossDeadT < 1.4 && (_bossDeadT * 12).floor() != ((_bossDeadT - dt) * 12).floor()) {
        final p = _bossC + Offset(rand(-70, 70), rand(-45, 45));
        host.fx.burst(p, _yellow, count: 10, speed: 220, size: 8, shape: PartShape.square, gravity: 0,
            colors: const [_white, _yellow, Color(0xFFF88820), _red]);
        host.sfx(Sfx.pExplode, volume: .6, rate: rand(.7, 1.2));
        host.shake(5);
      }
    }

    final active = !host.finished && _enter > 1.2 && !_bossDead;
    // --- player fire
    if (active && !_dead) {
      _fireT -= dt;
      if (_fireT <= 0) {
        _fireT = .075;
        _shots.add(_Shot(_ship.dx - 7, _ship.dy - 14, -30));
        _shots.add(_Shot(_ship.dx + 7, _ship.dy - 14, 30));
        if (_grazeGlow > 0) _shots.add(_Shot(_ship.dx, _ship.dy - 18, 0));
      }
    }
    final bc = _bossC;
    final bossRect = Rect.fromCenter(center: bc, width: 144, height: 104);
    for (final s in _shots) {
      s.y -= 900 * dt;
      s.x += s.vx * dt;
      if (s.y < 30) s.dead = true;
      if (!s.dead && !_bossDead && _enter > 1.2 && bossRect.contains(Offset(s.x, s.y))) {
        s.dead = true;
        _damage(s.x, s.y);
      }
    }
    _shots.removeWhere((s) => s.dead);

    // --- boss patterns
    if (active) {
      final sp = host.speed;
      _spiralT -= dt;
      _ringT -= dt;
      _aimT -= dt;
      final origin = bc + const Offset(0, 30);
      _spiralA += dt * (_phase == 3 ? 2.6 : 2.0);
      if (_spiralT <= 0 && _phase != 2) {
        _spiralT = (_phase == 3 ? .11 : .09) / sp;
        final arms = _phase == 3 ? 3 : 2;
        for (var i = 0; i < arms; i++) {
          _spawn(origin.dx, origin.dy, _spiralA + i * pi * 2 / arms, 130 * sp, _pink);
          if (_phase == 3) _spawn(origin.dx, origin.dy, -_spiralA * 1.3 + i * pi * 2 / arms, 100 * sp, _violet, 4);
        }
      }
      if (_ringT <= 0 && _phase >= 2) {
        _ringT = (_phase == 3 ? 1.1 : .75) / sp;
        _ringN++;
        final n = _phase == 3 ? 16 : 20;
        final off = _ringN.isEven ? 0.0 : pi / n;
        for (var i = 0; i < n; i++) {
          _spawn(origin.dx, origin.dy, off + i * pi * 2 / n, 120 * sp, _cyan, 6);
        }
        host.sfx(Sfx.pShoot, volume: .35, rate: .6);
      }
      if (_aimT <= 0) {
        _aimT = (_phase == 1 ? 1.3 : .95) / sp;
        for (final pod in [-1.0, 1.0]) {
          final o = bc + Offset(pod * 88, 28);
          final a = atan2(_ship.dy - o.dy, _ship.dx - o.dx);
          for (final d in const [-.2, 0.0, .2]) {
            _spawn(o.dx, o.dy, a + d, 190 * sp, _yellow, 4.5);
          }
        }
        host.sfx(Sfx.laser, volume: .3, rate: 1.4);
      }
    }

    // --- bullets
    for (final b in _bullets) {
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      if (b.x < -20 || b.x > 380 || b.y < 20 || b.y > 660) b.dead = true;
      if (b.dead || _dead || host.finished) continue;
      final dx = b.x - _ship.dx, dy = b.y - _ship.dy;
      final d2 = dx * dx + dy * dy;
      if (_invuln <= 0 && d2 < (b.r + 1.5) * (b.r + 1.5)) {
        b.dead = true;
        _hitPlayer();
        continue;
      }
      if (!b.grazed && d2 < 20 * 20) {
        b.grazed = true;
        _grazes++;
        _grazeGlow = 1;
        host.addScore(10);
        if (_grazes % 3 == 0) host.sfx(Sfx.tick, volume: .4, rate: 2);
        host.fx.sparkle(Offset(b.x, b.y), count: 1, radius: 4, color: _white);
        if (_grazes % 25 == 0) host.fx.pop('${host.tr('graze', 'GRAZE')} $_grazes', _ship - const Offset(0, 40), color: _cyan, size: 18);
      }
    }
    _bullets.removeWhere((b) => b.dead);

  }

  void _damage(double x, double y) {
    _hp = max(0, _hp - 1);
    if (_bossHit <= 0) _bossHit = 1;
    host.addScore(5);
    if (_hitSfxT <= 0) {
      _hitSfxT = .07;
      host.sfx(Sfx.pHit, volume: .35, rate: 1.5 + rand(0, .3));
    }
    if (chance(.3)) host.fx.burst(Offset(x, y), _cyan, count: 2, speed: 120, size: 4, shape: PartShape.square, gravity: 0);
    final newPhase = _hp > _bossMax * .66 ? 1 : (_hp > _bossMax * .33 ? 2 : 3);
    if (newPhase != _phase && _hp > 0) {
      _phase = newPhase;
      _phaseBanner = 1.4;
      _cancelBullets();
      host.sfx(Sfx.glitch);
      host.sfx(Sfx.pExplode, rate: .7);
      host.shake(8, .4);
      host.flash(_white, .15);
      host.hitStop(.08);
    }
    if (_hp <= 0 && !_bossDead) {
      _bossDead = true;
      _bossDeadT = 0;
      _cancelBullets();
      host.sfx(Sfx.explode);
      host.flash(_white, .3);
      host.shake(14, .8);
      host.hitStop(.15);
      host.fx.confetti();
      host.addScore(5000);
      host.win(stars: _hitsTaken == 0 ? 3 : (_hitsTaken == 1 ? 2 : 1));
    }
  }

  void _cancelBullets() {
    var n = 0;
    for (final b in _bullets) {
      if (n++ % 3 == 0) host.fx.sparkle(Offset(b.x, b.y), count: 1, radius: 2, color: _yellow);
      host.addScore(2);
    }
    _bullets.clear();
  }

  void _hitPlayer() {
    _lives--;
    _hitsTaken++;
    host.sfx(Sfx.pDie);
    host.shake(10, .4);
    host.flash(_red, .2);
    host.hitStop(.12);
    host.fx.burst(_ship, _cyan, count: 20, speed: 260, size: 6, shape: PartShape.square, gravity: 0,
        colors: const [_white, _cyan, _pink]);
    for (final b in _bullets) {
      if ((Offset(b.x, b.y) - _ship).distance < 140) b.dead = true;
    }
    if (_lives <= 0) {
      _dead = true;
      host.sfx(Sfx.explode);
      host.lose();
    } else {
      _invuln = 2.0;
    }
  }

  // ------------------------------------------------------------ input ---

  @override
  void onDown(Offset p) {
    _dragP = p;
    _dragS = _ship;
  }

  @override
  void onMove(Offset p) {
    if (_dead) return;
    final d = (p - _dragP) * 1.3;
    _ship = Offset((_dragS.dx + d.dx).clamp(12, 348), (_dragS.dy + d.dy).clamp(70, 626));
  }

  @override
  void onKey(String key, bool down) {
    final v = down ? 1.0 : 0.0;
    if (key == 'left') _keyDx = -v;
    if (key == 'right') _keyDx = v;
    if (key == 'up') _keyDy = -v;
    if (key == 'down') _keyDy = v;
  }

  @override
  void onTimeUp() => host.win(stars: 1);

  // ----------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    // deep space gradient that reddens with the phase
    final top = [const Color(0xFF0A0620), const Color(0xFF140830), const Color(0xFF2A0618)][_phase - 1];
    c.drawRect(
        const Rect.fromLTWH(0, 0, 360, 640),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, const Color(0xFF04040C)],
          ).createShader(const Rect.fromLTWH(0, 0, 360, 640)));
    // pixel nebula bands
    final neb = Paint()..color = _phase == 3 ? const Color(0x18F83838) : const Color(0x147038D8);
    for (var i = 0; i < 12; i++) {
      final y = ((i * 97 + _t * 30) % 700) - 30;
      final w = 120 + (i * 53 % 140);
      final x = (i * 71 % 300) - 40.0;
      c.drawRect(Rect.fromLTWH(x, y, w.toDouble(), 12), neb);
      c.drawRect(Rect.fromLTWH(x + 24, y + 12, w - 48.0, 6), neb);
    }
    final sp = Paint();
    for (final s in _stars) {
      sp.color = Color.fromRGBO(200, 210, 255, .25 * s.z);
      c.drawRect(Rect.fromLTWH(s.x.roundToDouble(), s.y.roundToDouble(), s.z == 3 ? 3 : 2, s.z == 3 ? 6 : 2), sp);
    }

    _renderBoss(c);

    // player shots
    final shotP = Paint()..color = _cyan;
    final coreP = Paint()..color = _white;
    for (final s in _shots) {
      c.drawRect(Rect.fromLTWH(s.x - 2, s.y - 7, 4, 14), shotP);
      c.drawRect(Rect.fromLTWH(s.x - 1, s.y - 5, 2, 10), coreP);
    }

    // ship
    if (!_dead && (_invuln <= 0 || (_t * 14).floor().isEven)) {
      ((_t * 16).floor().isEven ? _shipA : _shipB).drawCentered(c, _ship + const Offset(0, 3), scale: 3);
      if (_grazeGlow > 0) {
        c.drawCircle(_ship, 22 + 4 * _grazeGlow,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Color.fromRGBO(88, 232, 248, .6 * _grazeGlow));
      }
    }

    // bullets (outlined pixel orbs)
    final outline = Paint()..color = const Color(0xCC000000);
    final fillP = Paint();
    for (final b in _bullets) {
      final r = b.r;
      c.drawRect(Rect.fromCenter(center: Offset(b.x, b.y), width: r * 2 + 2, height: r * 2 - 2), outline);
      c.drawRect(Rect.fromCenter(center: Offset(b.x, b.y), width: r * 2 - 2, height: r * 2 + 2), outline);
      fillP.color = b.col;
      c.drawRect(Rect.fromCenter(center: Offset(b.x, b.y), width: r * 2, height: r * 2 - 4), fillP);
      c.drawRect(Rect.fromCenter(center: Offset(b.x, b.y), width: r * 2 - 4, height: r * 2), fillP);
      c.drawRect(Rect.fromCenter(center: Offset(b.x, b.y), width: r - 1, height: r - 1), coreP);
    }

    // hitbox dot (drawn above bullets so you always see it)
    if (!_dead) {
      final pulse = M.wave(_t, 3);
      c.drawRect(Rect.fromCenter(center: _ship, width: 6, height: 6), Paint()..color = _pink);
      c.drawRect(Rect.fromCenter(center: _ship, width: 3, height: 3), coreP);
      c.drawCircle(_ship, 8 + pulse * 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0x88FFFFFF));
    }

    // HUD
    const hb = Rect.fromLTWH(58, 44, 244, 10);
    c.drawRect(hb.inflate(2), Paint()..color = _white);
    c.drawRect(hb, Paint()..color = const Color(0xFF200818));
    c.drawRect(Rect.fromLTWH(hb.left, hb.top, hb.width * _hpShown / _bossMax, hb.height), Paint()..color = _yellow);
    c.drawRect(Rect.fromLTWH(hb.left, hb.top, hb.width * _hp / _bossMax, hb.height),
        Paint()..color = _phase == 3 ? _red : _pink);
    for (final f in [.33, .66]) {
      c.drawRect(Rect.fromLTWH(hb.left + hb.width * f - 1, hb.top, 2, hb.height), Paint()..color = _white);
    }
    _px(c, host.tr('boss', 'BOSS'), const Offset(12, 45), 1.5, _white);
    _px(c, 'P$_phase', const Offset(348, 45), 1.5, _phase == 3 ? _red : _white, align: 1);
    for (var i = 0; i < _lives; i++) {
      _shipA.draw(c, Offset(12 + i * 26.0, 604), scale: 2);
    }
    _px(c, '${host.tr('graze', 'GRAZE')} $_grazes', const Offset(348, 612), 2, _grazeGlow > 0 ? _cyan : const Color(0xFF8890B0), align: 1);
    _px(c, host.score.toString().padLeft(7, '0'), const Offset(180, 62), 2, _white, align: 0);

    if (_phaseBanner > 0) {
      final a = (_t * 8).floor().isEven;
      c.drawRect(const Rect.fromLTWH(0, 300, 360, 44), Paint()..color = const Color(0xAA000000));
      c.drawRect(const Rect.fromLTWH(0, 300, 360, 3), Paint()..color = _red);
      c.drawRect(const Rect.fromLTWH(0, 341, 360, 3), Paint()..color = _red);
      _px(c, host.tr('danger', 'DANGER'), const Offset(180, 312), 3, a ? _red : _yellow, align: 0);
    }
    if (_enter < 2.4 && !host.finished) {
      D.hand(c, _ship + Offset(20 + sin(_t * 4) * 30, 40), _t);
      _px(c, host.tr('drag', 'DRAG'), Offset(_ship.dx.clamp(60.0, 300.0), min(_ship.dy + 80, 590)), 3, _white, align: 0, shadow: _k);
    }
    Retro.scanlines(c, alpha: .12);
  }

  void _renderBoss(Canvas c) {
    if (_bossDead && _bossDeadT > 1.4) return;
    final bc = _bossC + (_bossDead ? Offset(sin(_t * 80) * 5, _bossDeadT * 40) : Offset.zero);
    final s = _phase == 3 ? _boss3 : _boss1;
    const scale = 4.0;
    // pods
    for (final side in [-1.0, 1.0]) {
      final bob = sin(_t * 4 + side) * 4;
      _pod.drawCentered(c, bc + Offset(side * 88, 16 + bob), scale: 3, tint: _bossHit > .75 ? _white : null);
    }
    s.drawCentered(c, bc, scale: scale, tint: _bossHit > .75 ? _white : null, opacity: _bossDead ? max(0, 1 - _bossDeadT / 1.4) : 1);
    if (_bossHit <= .75 && !_bossDead) {
      // pupils track the player
      final look = (_ship - bc);
      final lx = (look.dx / 200).clamp(-1.0, 1.0) * 2, ly = (look.dy / 300).clamp(-1.0, 1.0) * 1.2;
      final tl = bc - Offset(s.w * scale / 2, s.h * scale / 2);
      final pp = Paint()..color = _k;
      for (final ex in [10.5, 25.5]) {
        final p = tl + Offset((ex + lx) * scale, (11.5 + ly) * scale);
        c.drawRect(Rect.fromCenter(center: p, width: 3 * scale, height: 3 * scale), pp);
        c.drawRect(Rect.fromCenter(center: p + Offset(-scale * .5, -scale * .5), width: scale, height: scale), Paint()..color = _white);
      }
      // AD label on the title bar
      _px(c, 'AD', tl + const Offset(8, 6), 1.5, _yellow);
    }
  }
}
