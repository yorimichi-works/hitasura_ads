import '../engine/engine.dart';

/// No.151 THE AD KING — secret final boss. Three phases:
/// 1. POPUP STORM: close falling popups (tap their X, or shoot them).
/// 2. INSTALL BARRAGE: dodge bullet-hell "install buttons" while firing.
/// 3. SKIP!: the weak point appears — mash the SKIP button.
class G151 extends MiniGame {
  static const _u = 5.0; // pixel unit
  double _t = 0;
  double _hp = 1;
  double _shownHp = 1;
  int _phase = 1;
  double _phaseT = 0;
  int _hearts = 5;
  double _invuln = 0;
  Offset _ship = const Offset(180, 560);
  Offset? _dragFrom;
  Offset _shipFrom = Offset.zero;
  double _fireT = 0;
  double _bossX = 180;
  double _bossHit = 0;
  double _mouth = 0;
  bool _dead = false;
  double _deadT = 0;
  final List<_Popup> _popups = [];
  final List<_Bullet> _shots = [];
  final List<_Bullet> _enemy = [];
  double _spawnT = 0;
  double _patternT = 0;
  int _pattern = 0;
  Offset _skip = const Offset(180, 200);
  double _skipPulse = 0;
  double _banner = 0;
  String _bannerKey = '';

  static const _bossY = 200.0;

  @override
  Color get backdrop => const Color(0xFF0B0620);

  @override
  void init() {
    _showBanner('popup_storm');
  }

  void _showBanner(String key) {
    _banner = 1.6;
    _bannerKey = key;
  }

  String _bannerText() => switch (_bannerKey) {
        'popup_storm' => host.tr('popup_storm', 'POPUP STORM!'),
        'barrage' => host.tr('install_barrage', 'INSTALL BARRAGE!'),
        'skip' => host.tr('press_skip', 'PRESS SKIP!!'),
        _ => '',
      };

  void _damage(double amount, Offset at) {
    if (_dead) return;
    _hp = (_hp - amount).clamp(0, 1);
    _bossHit = max(_bossHit, amount >= .01 ? 1.0 : .3);
    if (_hp <= 0) _kill();
  }

  void _kill() {
    _dead = true;
    _deadT = 0;
    _enemy.clear();
    _popups.clear();
    host.sfx(Sfx.pExplode);
    host.sfx(Sfx.explode);
    host.shake(18, 1.2);
    host.flash(Pal.white, .4);
    host.hitStop(.25);
  }

  void _hurtPlayer() {
    if (_invuln > 0 || _dead) return;
    _hearts--;
    _invuln = 1.2;
    host.sfx(Sfx.pHit);
    host.shake(10);
    host.flash(Pal.red, .2);
    host.fx.burst(_ship, Pal.red, count: 14, shape: PartShape.square);
    if (_hearts <= 0) {
      host.sfx(Sfx.pDie);
      host.lose();
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _phaseT += dt;
    _banner = (_banner - dt).clamp(0, 2);
    _bossHit = M.approach(_bossHit, 0, 8, dt);
    _shownHp = M.approach(_shownHp, _hp, 6, dt);
    _invuln = (_invuln - dt).clamp(0, 5);
    _skipPulse = M.approach(_skipPulse, 0, 10, dt);

    if (_dead) {
      _deadT += dt;
      if (_deadT < 1.6 && (_deadT * 10).floor() != ((_deadT - dt) * 10).floor()) {
        final p = Offset(_bossX + rand(-110, 110), _bossY + rand(-70, 70));
        host.fx.burst(p, pick([Pal.yellow, Pal.orange, Pal.pink, Pal.white]), count: 18, speed: 300, shape: PartShape.square);
        host.sfx(Sfx.pExplode, rate: rand(.8, 1.3));
        host.shake(8);
      }
      if (_deadT > 1.7 && !host.finished) {
        host.fx.confetti(count: 120);
        host.fx.coins(const Offset(180, 200), count: 40, speed: 600);
        host.sfx(Sfx.fanfare);
        host.win(stars: _hearts >= 4 ? 3 : (_hearts >= 2 ? 2 : 1));
      }
      _updateShots(dt);
      return;
    }

    // boss sway
    final sway = _phase == 3 ? 90.0 : 50.0;
    _bossX = 180 + sin(_t * (_phase == 3 ? 1.6 : .9)) * sway;
    _mouth = M.approach(_mouth, _phase == 2 ? .5 + .5 * sin(_t * 8) : 0, 8, dt);

    // phase transitions
    if (_phase == 1 && _hp < .66) {
      _phase = 2;
      _phaseT = 0;
      _popups.clear();
      _showBanner('barrage');
      host.sfx(Sfx.horror);
      host.shake(10, .6);
    } else if (_phase == 2 && _hp < .28) {
      _phase = 3;
      _phaseT = 0;
      _showBanner('skip');
      host.sfx(Sfx.rarityUp);
      host.shake(12, .6);
    }

    // auto-fire
    _fireT -= dt;
    if (_fireT <= 0 && host.time > .3) {
      _fireT = .11;
      _shots.add(_Bullet(_ship + const Offset(-8, -16), const Offset(0, -620), 0));
      _shots.add(_Bullet(_ship + const Offset(8, -16), const Offset(0, -620), 0));
      if ((_t * 9).floor().isEven) host.sfx(Sfx.pShoot, volume: .25);
    }

    switch (_phase) {
      case 1:
        _spawnT -= dt;
        if (_spawnT <= 0) {
          _spawnT = max(.45, 1.1 - _phaseT * .04) / host.speed;
          final x = _bossX + rand(-100, 100);
          _popups.add(_Popup(Offset(x.clamp(50, 310), _bossY + 40), Offset(rand(-30, 30), rand(55, 85) * host.speed),
              rand(76, 108), rand(52, 70), pick([Pal.sky, Pal.pink, Pal.lime, Pal.orange, Pal.purple])));
          host.sfx(Sfx.notify, volume: .5);
        }
      case 2:
        _patternT -= dt;
        if (_patternT <= 0) {
          _pattern++;
          _patternT = 1.25 / host.speed;
          final origin = Offset(_bossX, _bossY + 40);
          host.sfx(Sfx.laser, volume: .4);
          switch (_pattern % 3) {
            case 0: // fan aimed at the player
              final aim = atan2(_ship.dy - origin.dy, _ship.dx - origin.dx);
              for (var i = -3; i <= 3; i++) {
                final a = aim + i * .18;
                _enemy.add(_Bullet(origin, Offset(cos(a), sin(a)) * 170 * host.speed, 1));
              }
            case 1: // ring
              for (var i = 0; i < 14; i++) {
                final a = i / 14 * pi * 2 + _t;
                _enemy.add(_Bullet(origin, Offset(cos(a), sin(a)) * 135 * host.speed, 1));
              }
            default: // rain
              for (var i = 0; i < 7; i++) {
                _enemy.add(_Bullet(Offset(30 + i * 50.0 + rand(-10, 10), 60), Offset(0, rand(150, 210) * host.speed), 1));
              }
          }
        }
      case 3:
        _skip = Offset(_bossX, _bossY + 18);
        _patternT -= dt;
        if (_patternT <= 0) {
          _patternT = .9 / host.speed;
          for (var i = 0; i < 5; i++) {
            _enemy.add(_Bullet(Offset(rand(20, 340), 50), Offset(rand(-20, 20), rand(160, 220) * host.speed), 1));
          }
        }
    }

    // popups
    for (final p in _popups) {
      p.pos += p.vel * dt;
      p.wob += dt;
      if (p.pos.dx < 40 || p.pos.dx > 320) p.vel = Offset(-p.vel.dx, p.vel.dy);
      if (p.pos.dy + p.h / 2 > 600) {
        p.dead = true;
        _hurtPlayer();
        host.fx.burst(p.pos, p.color, count: 10, shape: PartShape.square);
      }
    }
    _popups.removeWhere((p) => p.dead);

    // enemy bullets
    for (final b in _enemy) {
      b.pos += b.vel * dt;
      if ((b.pos - _ship).distance < 12) {
        b.dead = true;
        _hurtPlayer();
      }
    }
    _enemy.removeWhere((b) => b.dead || b.pos.dy > 680 || b.pos.dy < -40 || b.pos.dx < -40 || b.pos.dx > 400);
    _updateShots(dt);
  }

  void _updateShots(double dt) {
    for (final s in _shots) {
      s.pos += s.vel * dt;
      if (_dead) continue;
      // hit popups
      for (final p in _popups) {
        if (p.rect.contains(s.pos)) {
          s.dead = true;
          p.hp--;
          p.flash = 1;
          if (p.hp <= 0) _closePopup(p, shot: true);
          break;
        }
      }
      if (s.dead) continue;
      // hit boss body
      final body = Rect.fromCenter(center: Offset(_bossX, _bossY), width: 200, height: 130);
      if (body.contains(s.pos)) {
        s.dead = true;
        final dmg = _phase == 3 ? .0022 : .0035;
        _damage(dmg, s.pos);
        if (chance(.3)) host.fx.burst(s.pos, Pal.yellow, count: 3, speed: 120, shape: PartShape.square, life: .25);
      }
    }
    _shots.removeWhere((s) => s.dead || s.pos.dy < 20);
  }

  void _closePopup(_Popup p, {bool shot = false}) {
    p.dead = true;
    host.sfx(shot ? Sfx.pHit : Sfx.pCoin);
    host.fx.burst(p.pos, p.color, count: 16, speed: 260, shape: PartShape.square);
    host.addScore(shot ? 10 : 30, p.pos);
    _damage(shot ? .03 : .05, p.pos);
  }

  @override
  void onDown(Offset p) {
    // Close buttons first
    for (final pop in _popups.reversed) {
      if ((p - pop.closeCenter).distance < 20) {
        _closePopup(pop);
        return;
      }
    }
    if (_phase == 3 && !_dead && (p - _skip).distance < 46) {
      _skipPulse = 1;
      _damage(.03, _skip);
      host.sfx(Sfx.pHit);
      host.sfx(Sfx.punch, volume: .6);
      host.shake(6);
      host.punch(.02);
      host.fx.burst(_skip, Pal.lime, count: 10, speed: 200, shape: PartShape.star);
      return;
    }
    _dragFrom = p;
    _shipFrom = _ship;
  }

  @override
  void onMove(Offset p) {
    final from = _dragFrom;
    if (from == null) return;
    final d = p - from;
    _ship = Offset((_shipFrom.dx + d.dx * 1.3).clamp(16, 344), (_shipFrom.dy + d.dy * 1.3).clamp(300, 620));
  }

  @override
  void onUp(Offset p) => _dragFrom = null;

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    const step = 26.0;
    switch (key) {
      case 'left':
        _ship = Offset((_ship.dx - step).clamp(16, 344), _ship.dy);
      case 'right':
        _ship = Offset((_ship.dx + step).clamp(16, 344), _ship.dy);
      case 'up':
        _ship = Offset(_ship.dx, (_ship.dy - step).clamp(300, 620));
      case 'down':
        _ship = Offset(_ship.dx, (_ship.dy + step).clamp(300, 620));
      case 'action':
        if (_phase == 3) onDown(_skip);
    }
  }

  @override
  void onTimeUp() {
    if (_hp < .15) {
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ------------------------------------------------------------- render ---

  void _px(Canvas c, double x, double y, double w, double h, Color col) =>
      c.drawRect(Rect.fromLTWH((x / _u).roundToDouble() * _u, (y / _u).roundToDouble() * _u, w, h), Paint()..color = col);

  @override
  void render(Canvas c) {
    // Starfield "ad space"
    D.gradientBg(c, const [Color(0xFF0B0620), Color(0xFF2A0B45), Color(0xFF55104F)]);
    final sp = Paint()..color = const Color(0x88FFFFFF);
    for (var i = 0; i < 60; i++) {
      final y = (i * 83 + _t * (30 + i % 5 * 25)) % 640;
      c.drawRect(Rect.fromLTWH((i * 137) % 360.0, y, 2, 2 + (i % 3).toDouble()), sp);
    }
    // floor grid of "banner" tiles
    for (var i = 0; i < 8; i++) {
      final y = 480 + i * i * 3.0 + (_t * 30) % 20;
      c.drawRect(Rect.fromLTWH(0, y, 360, 1), Paint()..color = const Color(0x33FF4FA3));
    }

    _renderBoss(c);

    for (final p in _popups) {
      _renderPopup(c, p);
    }
    // player shots: pixel X marks (the only weapon that works on ads)
    for (final s in _shots) {
      _px(c, s.pos.dx - 3, s.pos.dy - 6, 5, 12, Pal.teal);
    }
    // install-button bullets
    for (final b in _enemy) {
      final r = Rect.fromCenter(center: b.pos, width: 22, height: 12);
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(5)), Paint()..color = const Color(0xFF1E9E5A));
      c.drawRRect(RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(4)), Paint()..color = Pal.lime);
      // down-arrow glyph
      c.drawRect(Rect.fromCenter(center: b.pos + const Offset(0, -1), width: 2, height: 5), Paint()..color = Pal.ink);
      c.drawPath(
          Path()
            ..moveTo(b.pos.dx - 3, b.pos.dy + 1)
            ..lineTo(b.pos.dx + 3, b.pos.dy + 1)
            ..lineTo(b.pos.dx, b.pos.dy + 4)
            ..close(),
          Paint()..color = Pal.ink);
    }
    _renderShip(c);

    // HUD: boss HP + hearts
    D.text(c, host.tr('ad_king', 'THE AD KING'), const Offset(20, 46), size: 14, anchor: Alignment.centerLeft, color: Pal.yellow, stroke: Pal.ink);
    const hpRect = Rect.fromLTWH(20, 56, 320, 12);
    c.drawRect(hpRect.inflate(2), Paint()..color = Pal.ink);
    c.drawRect(Rect.fromLTWH(hpRect.left, hpRect.top, hpRect.width * _shownHp, hpRect.height), Paint()..color = const Color(0xFFFFFFFF));
    c.drawRect(Rect.fromLTWH(hpRect.left, hpRect.top, hpRect.width * _hp, hpRect.height),
        Paint()..color = _phase == 3 ? Pal.red : (_phase == 2 ? Pal.orange : Pal.pink));
    for (var i = 0; i < 5; i++) {
      D.heart(c, Offset(24 + i * 22.0, 616), 16, i < _hearts ? Pal.red : const Color(0x44FFFFFF), border: Pal.ink);
    }

    if (_banner > 0) {
      final k = _banner > 1.3 ? M.easeOutBack((1.6 - _banner) / .3) : (_banner < .3 ? _banner / .3 : 1.0);
      c.save();
      c.translate(180, 330);
      c.rotate(-.08);
      c.scale(k);
      D.rrect(c, Rect.fromCenter(center: Offset.zero, width: 320, height: 58), 6, Pal.ink);
      D.rrect(c, Rect.fromCenter(center: Offset.zero, width: 312, height: 50), 4, _phase == 3 ? Pal.red : Pal.purple);
      D.text(c, _bannerText(), Offset.zero, size: 26, color: Pal.yellow, stroke: Pal.ink, maxWidth: 300);
      c.restore();
    }
    if (host.time < 2.5) D.hand(c, _ship + const Offset(0, 30), _t, size: 36);
    Retro.scanlines(c, alpha: .12);
  }

  void _renderBoss(Canvas c) {
    if (_dead && _deadT > 1.5) return;
    final x = _bossX, y = _bossY;
    final shake = _dead ? rand(-6, 6) : 0.0;
    c.save();
    c.translate(shake, _dead ? _deadT * 40 : 0);
    final flash = _bossHit > .5;
    // arms: two popup windows as hands
    for (final s in [-1.0, 1.0]) {
      final hx = x + s * (130 + sin(_t * 3 + s) * 8);
      final hy = y + 30 + cos(_t * 2.4 + s) * 10;
      _px(c, hx - 30, hy - 22, 60, 44, Pal.ink);
      _px(c, hx - 27, hy - 19, 54, 38, Pal.white);
      _px(c, hx - 27, hy - 19, 54, 9, Pal.blue);
      _px(c, hx + 17, hy - 18, 8, 7, Pal.red);
      _px(c, hx - 18, hy - 4, 36, 4, const Color(0xFFBBBBCC));
      _px(c, hx - 18, hy + 4, 24, 4, const Color(0xFFBBBBCC));
    }
    // crown
    const gold = Color(0xFFFFC53D);
    _px(c, x - 60, y - 105, 120, 22, Pal.ink);
    _px(c, x - 55, y - 100, 110, 15, gold);
    for (var i = 0; i < 5; i++) {
      final cx = x - 55 + i * 27.5;
      _px(c, cx - 2, y - 125, 14, 25, Pal.ink);
      _px(c, cx + 1, y - 120, 8, 20, gold);
      _px(c, cx + 1, y - 97, 8, 7, [Pal.red, Pal.sky, Pal.lime, Pal.pink, Pal.purple][i]);
    }
    // billboard frame
    _px(c, x - 110, y - 80, 220, 160, Pal.ink);
    _px(c, x - 105, y - 75, 210, 150, flash ? Pal.white : const Color(0xFF3B1D6E));
    // blinking bulbs
    for (var i = 0; i < 11; i++) {
      final on = ((i + (_t * 8).floor()) % 3) == 0;
      _px(c, x - 100 + i * 19.5, y - 73, 6, 6, on ? Pal.yellow : const Color(0xFF6B4A1A));
      _px(c, x - 100 + i * 19.5, y + 67, 6, 6, !on ? Pal.yellow : const Color(0xFF6B4A1A));
    }
    // screen with scrolling ad stripes
    final scr = Rect.fromLTWH(x - 95, y - 62, 190, 124);
    c.save();
    c.clipRect(scr);
    for (var i = 0; i < 8; i++) {
      final yy = scr.top + ((i * 20 + _t * 50) % 160) - 20;
      _px(c, scr.left, yy, scr.width, 20, flash ? Pal.white : (i.isEven ? const Color(0xFFFF4FA3) : const Color(0xFFE0359A)));
    }
    c.restore();
    // eyes tracking the player
    for (final s in [-1.0, 1.0]) {
      final ex = x + s * 42, ey = y - 20;
      _px(c, ex - 22, ey - 16, 44, 32, Pal.ink);
      _px(c, ex - 18, ey - 12, 36, 24, Pal.white);
      final look = (_ship - Offset(ex, ey));
      final l = look / max(1, look.distance) * 7;
      _px(c, ex - 7 + l.dx, ey - 6 + l.dy, 14, 14, _phase == 3 ? Pal.red : Pal.ink);
      // angry brow
      c.save();
      c.translate(ex, ey - 22);
      c.rotate(s * .35);
      c.drawRect(const Rect.fromLTWH(-24, -4, 48, 8), Paint()..color = Pal.ink);
      c.restore();
    }
    // mouth
    final mh = 10 + _mouth * 22;
    _px(c, x - 48, y + 20, 96, mh + 8, Pal.ink);
    _px(c, x - 44, y + 24, 88, mh, const Color(0xFF7A0F2E));
    for (var i = 0; i < 6; i++) {
      _px(c, x - 42 + i * 15, y + 24, 10, 6, Pal.white);
    }
    c.restore();

    // weak point
    if (_phase == 3 && !_dead) {
      final s = 1 + _skipPulse * .25 + sin(_t * 10) * .05;
      c.save();
      c.translate(_skip.dx, _skip.dy);
      c.scale(s);
      D.rrect(c, Rect.fromCenter(center: Offset.zero, width: 96, height: 44), 10, Pal.ink);
      D.rrect(c, Rect.fromCenter(center: Offset.zero, width: 88, height: 36), 8, Pal.lime);
      // ▶▶| glyph
      final p = Paint()..color = Pal.ink;
      for (var i = 0; i < 2; i++) {
        c.drawPath(
            Path()
              ..moveTo(-24.0 + i * 16, -10)
              ..lineTo(-10.0 + i * 16, 0)
              ..lineTo(-24.0 + i * 16, 10)
              ..close(),
            p);
      }
      c.drawRect(const Rect.fromLTWH(10, -10, 5, 20), p);
      c.restore();
      if (host.time % 1 < .6) D.hand(c, _skip + const Offset(10, 18), _t, size: 34);
    }
  }

  void _renderPopup(Canvas c, _Popup p) {
    final r = p.rect;
    final tilt = sin(p.wob * 3) * .05;
    c.save();
    c.translate(p.pos.dx, p.pos.dy);
    c.rotate(tilt);
    c.translate(-p.pos.dx, -p.pos.dy);
    _px(c, r.left - 3, r.top - 3, r.width + 6, r.height + 6, Pal.ink);
    _px(c, r.left, r.top, r.width, r.height, p.flash > 0 ? Pal.white : const Color(0xFFEDEBF7));
    _px(c, r.left, r.top, r.width, 12, p.color);
    // "!" warning icon
    _px(c, r.left + 8, r.top + 20, 14, 14, Pal.yellow);
    _px(c, r.left + 13, r.top + 22, 4, 7, Pal.ink);
    _px(c, r.left + 13, r.top + 30, 4, 3, Pal.ink);
    for (var i = 0; i < 3; i++) {
      _px(c, r.left + 28, r.top + 20 + i * 8, r.width - 36 - i * 10, 4, const Color(0xFFB0ACC8));
    }
    // close button
    final cc = p.closeCenter;
    _px(c, cc.dx - 8, cc.dy - 7, 16, 14, Pal.red);
    D.line(c, cc + const Offset(-4, -3), cc + const Offset(4, 3), Pal.white, 2.5);
    D.line(c, cc + const Offset(4, -3), cc + const Offset(-4, 3), Pal.white, 2.5);
    c.restore();
    p.flash = max(0, p.flash - .1);
  }

  void _renderShip(Canvas c) {
    if (_invuln > 0 && (_invuln * 12).floor().isEven) return;
    final s = _ship;
    // classic arrow cursor, pixel style
    const rows = [
      'K.........',
      'KK........',
      'KWK.......',
      'KWWK......',
      'KWWWK.....',
      'KWWWWK....',
      'KWWWWWK...',
      'KWWWWWWK..',
      'KWWWWWWWK.',
      'KWWWWKKKKK',
      'KWWKWWK...',
      'KWK.KWWK..',
      'KK..KWWK..',
      'K....KWWK.',
      '.....KKK..',
    ];
    _cursor ??= Sprite(rows, {'K': Pal.ink, 'W': Pal.white});
    // thruster
    final flick = (sin(_t * 40) * 3).abs();
    c.drawRect(Rect.fromLTWH(s.dx - 3, s.dy + 20, 6, 8 + flick), Paint()..color = Pal.orange);
    c.drawRect(Rect.fromLTWH(s.dx - 1.5, s.dy + 20, 3, 5 + flick), Paint()..color = Pal.yellow);
    _cursor!.draw(c, s - const Offset(9, 22), scale: 3);
    // hitbox dot
    c.drawCircle(s, 3, Paint()..color = Pal.red);
  }

  Sprite? _cursor;
}

class _Popup {
  _Popup(this.pos, this.vel, this.w, this.h, this.color);
  Offset pos;
  Offset vel;
  final double w, h;
  final Color color;
  int hp = 6;
  double wob = 0;
  double flash = 0;
  bool dead = false;
  Rect get rect => Rect.fromCenter(center: pos, width: w, height: h);
  Offset get closeCenter => Offset(pos.dx + w / 2 - 10, pos.dy - h / 2 + 6);
}

class _Bullet {
  _Bullet(this.pos, this.vel, this.kind);
  Offset pos;
  final Offset vel;
  final int kind;
  bool dead = false;
}
