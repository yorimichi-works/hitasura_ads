import '../engine/engine.dart';

/// No.095 Mimic Chest — 16-bit dungeon "spot the fake".
///
/// Each round shows 3 chests. Mimics give themselves away with subtle tells
/// (breathing lid, twitch, drool drop, tongue tip, eye in the keyhole,
/// teeth peeking). Real chests only glint. Tap a chest: treasure = gold
/// fountain, mimic = CHOMP and you lose a heart (2 hearts). Loot 4 treasure
/// chests => win. Later rounds hide 2 mimics.
class G095 extends MiniGame {
  static const _goal = 4;
  static const _xs = [66.0, 180.0, 294.0];
  static const _cy = 392.0; // chest bottom y
  static const _sc = 5.0;

  double _t = 0;
  final List<_Chest> _chests = [];
  int _loot = 0, _hearts = 2, _round = 0, _mistakes = 0;
  // phases: 0 drop-in, 1 choose, 2 reveal
  int _phase = 0;
  double _pt0 = 0;
  double _heroShock = 0, _heroCheer = 0;
  final _pops = _Pops();
  final List<Offset> _dust = [];

  @override
  void init() {
    for (var i = 0; i < 16; i++) {
      _dust.add(Offset(rand(0, 360), rand(60, 520)));
    }
    _newRound();
  }

  void _newRound() {
    _round++;
    _chests.clear();
    final mimics = _loot >= 2 ? 2 : 1;
    final order = [0, 1, 2]..shuffle(rng);
    const allTells = [_Tell.breathe, _Tell.twitch, _Tell.drool, _Tell.tongue, _Tell.eye, _Tell.teeth];
    for (var i = 0; i < 3; i++) {
      final mimic = order.indexOf(i) < mimics;
      final tells = <_Tell>[];
      if (mimic) {
        final pool = List.of(allTells)..shuffle(rng);
        tells.addAll(pool.take(mimics == 1 ? 2 : 2));
      }
      _chests.add(_Chest(i, mimic, tells)
        ..phase = rand(0, 1)
        ..period = rand(1.0, 1.35) / sqrt(host.speed)
        ..drop = i * .08);
    }
    _phase = 0;
    _pt0 = 0;
  }

  // --------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    if (_phase != 1 || host.finished) return;
    for (final ch in _chests) {
      final r = Rect.fromLTRB(_xs[ch.i] - 48, _cy - 84, _xs[ch.i] + 48, _cy + 14);
      if (r.contains(p)) {
        _open(ch);
        return;
      }
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down || _phase != 1) return;
    const m = {'left': 0, 'up': 1, 'action': 1, 'right': 2, 'down': 1};
    final i = m[key];
    if (i != null) _open(_chests[i]);
  }

  void _open(_Chest ch) {
    _phase = 2;
    _pt0 = 0;
    ch.opened = true;
    final at = Offset(_xs[ch.i], _cy - 40);
    if (ch.mimic) {
      _hearts--;
      _mistakes++;
      _heroShock = 1.4;
      host.sfx(Sfx.chomp);
      host.sfx(Sfx.pHit);
      host.sfx(Sfx.horror, volume: .5);
      host.shake(12);
      host.flash(Pal.red, .18);
      host.hitStop(.1);
      _pops.add(host.tr('chomp', 'CHOMP!'), at - const Offset(0, 70), Pal.red, 5);
      host.fx.burst(at, Pal.red, count: 14, speed: 240, shape: PartShape.square, size: 6);
      if (_hearts <= 0) host.lose();
    } else {
      _loot++;
      _heroCheer = 1.3;
      host.sfx(Sfx.open);
      host.sfx(Sfx.pCoin);
      host.sfx(Sfx.coins, volume: .8);
      host.shake(4);
      host.punch(.03);
      host.addScore(100 * _loot, at - const Offset(0, 40));
      host.fx.coins(at, count: 18, speed: 420);
      host.fx.burst(at, Pal.gold, count: 16, speed: 260, shape: PartShape.star, size: 6);
      _pops.add(_loot >= _goal ? host.tr('jackpot', 'JACKPOT!') : host.tr('treasure', 'TREASURE!'), at - const Offset(0, 80),
          Pal.gold, 4);
      if (_loot >= _goal) {
        host.sfx(Sfx.fanfare);
        host.fx.confetti(count: 90);
        host.win(stars: _mistakes == 0 ? 3 : 2);
      }
    }
  }

  // -------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    _pt0 += dt;
    _pops.update(dt);
    _heroShock = max(0, _heroShock - dt);
    _heroCheer = max(0, _heroCheer - dt);
    for (var i = 0; i < _dust.length; i++) {
      var d = _dust[i] + Offset(sin(_t + i) * 6 * dt, -8 * dt);
      if (d.dy < 50) d = Offset(rand(0, 360), 520);
      _dust[i] = d;
    }
    for (final ch in _chests) {
      ch.drop = max(0, ch.drop - dt);
      ch.lt += dt;
      // audible tell: tiny creak on twitch
      if (_phase == 1 && ch.mimic && ch.tells.contains(_Tell.twitch)) {
        final ph = _tellPhase(ch);
        if (ph < ch.lastPh) host.sfx(Sfx.tick, volume: .15, rate: .6);
        ch.lastPh = ph;
      }
    }
    if (_phase == 0 && _pt0 > .45) {
      _phase = 1;
      _pt0 = 0;
    }
    if (_phase == 2 && _pt0 > 1.25 && !host.finished) _newRound();
  }

  double _tellPhase(_Chest ch) => ((_t / ch.period) + ch.phase) % 1;

  // -------------------------------------------------------------- render ---
  static final Paint _pp = Paint()..isAntiAlias = false;
  void _r(Canvas c, double l, double t, double w, double h, Color col) {
    _pp.color = col;
    c.drawRect(Rect.fromLTWH(l, t, w, h), _pp);
  }

  @override
  void render(Canvas c) {
    _drawRoom(c);
    // chests
    for (final ch in _chests) {
      _drawChest(c, ch);
    }
    _drawHero(c);
    for (final d in _dust) {
      _r(c, d.dx.roundToDouble(), d.dy.roundToDouble(), 2, 2, const Color(0x55FFE8B0));
    }
    _drawHud(c);
    _pops.render(c);
    if (_phase == 1 && _round == 1 && _pt0 < 2.5) {
      _pt(c, host.tr('which', 'WHICH?'), const Offset(180, 230 + 0), 4, Pal.white);
      D.hand(c, Offset(_xs[((_t * .8).floor()) % 3], _cy - 30), _t);
    }
    Retro.scanlines(c, alpha: .12);
    Retro.vignette(c, strength: .55);
  }

  void _drawRoom(Canvas c) {
    // back wall bricks
    _r(c, 0, 0, 360, 640, const Color(0xFF1A1426));
    const b1 = Color(0xFF3A3050), b2 = Color(0xFF2E2642), bl = Color(0xFF4A3E66);
    for (var y = 36.0, row = 0; y < 300; y += 24, row++) {
      for (var x = row.isEven ? 0.0 : -24.0; x < 360; x += 48) {
        final col = ((x ~/ 48 + row) % 3 == 0) ? b2 : b1;
        _r(c, x + 2, y + 2, 44, 20, col);
        _r(c, x + 2, y + 2, 44, 3, bl);
      }
    }
    // floor
    _r(c, 0, 300, 360, 340, const Color(0xFF2A2236));
    for (var y = 300.0, row = 0; y < 640; y += 30 + row * 4, row++) {
      _r(c, 0, y, 360, 3, const Color(0xFF1A1426));
      final w = 60.0 + row * 12;
      for (var x = (row.isEven ? 0.0 : w / 2); x < 360; x += w) {
        _r(c, x, y, 3, 30 + row * 4.0, const Color(0xFF1A1426));
      }
    }
    _r(c, 0, 296, 360, 6, const Color(0xFF4A3E66));
    // banners
    for (final bx in const [110.0, 250.0]) {
      _r(c, bx - 20, 60, 40, 4, const Color(0xFFB08A3A));
      _r(c, bx - 16, 64, 32, 70, const Color(0xFF8C1E3A));
      _r(c, bx - 16, 64, 32, 6, const Color(0xFFB02A4A));
      _S.skullEmblem.drawCentered(c, Offset(bx, 96), scale: 3);
      _r(c, bx - 16, 134, 10, 8, const Color(0xFF8C1E3A));
      _r(c, bx + 6, 134, 10, 8, const Color(0xFF8C1E3A));
    }
    // torches with glow
    for (final tx in const [30.0, 180.0, 330.0]) {
      final fl = .8 + sin(_t * 13 + tx) * .1 + sin(_t * 23 + tx * 2) * .06;
      c.drawCircle(Offset(tx, 120), 90 * fl,
          Paint()
            ..shader = RadialGradient(colors: const [Color(0x44FFB040), Color(0x00FFB040)])
                .createShader(Rect.fromCircle(center: Offset(tx, 120), radius: 90 * fl)));
      _r(c, tx - 6, 124, 12, 26, const Color(0xFF5E3A18));
      _r(c, tx - 10, 120, 20, 6, const Color(0xFF7A7F9A));
      final f = (_t * 10 + tx).floor() % 3;
      (f == 0 ? _S.flame1 : (f == 1 ? _S.flame2 : _S.flame3)).drawCentered(c, Offset(tx, 108), scale: 3);
    }
    // cobweb & skull props
    _S.web.draw(c, const Offset(0, 36), scale: 3);
    _S.web.draw(c, const Offset(360 - 30, 36), scale: 3, flipX: true);
    _S.skull.draw(c, const Offset(20, 560), scale: 3);
    _S.bones.draw(c, const Offset(300, 590), scale: 3);
    // light pool on floor
    c.drawOval(const Rect.fromLTWH(10, 330, 340, 120),
        Paint()
          ..shader = RadialGradient(colors: const [Color(0x22FFD080), Color(0x00FFD080)])
              .createShader(const Rect.fromLTWH(10, 330, 340, 120)));
  }

  void _drawChest(Canvas c, _Chest ch) {
    final x = _xs[ch.i];
    final dropOff = _phase == 0 ? -M.clamp01(1 - (_pt0 - ch.drop) / .35) * 300 : 0.0;
    final bounce = _phase == 0 && _pt0 - ch.drop > .3 ? -sin(M.clamp01((_pt0 - ch.drop - .3) / .15) * pi) * 6 : 0.0;
    final by = _cy + dropOff + bounce;
    const bw = 16 * _sc;
    final left = (x - bw / 2).roundToDouble();
    D.shadow(c, Offset(x, _cy + 2), bw * 1.1, 14, .45);
    final revealed = ch.opened && _phase == 2;
    final dim = _phase == 2 && !ch.opened;
    if (revealed && ch.mimic) {
      _drawMimicAttack(c, x, by);
      return;
    }
    if (revealed) {
      // treasure: lid flips open, glow
      final k = M.clamp01(_pt0 / .2);
      D.rays(c, Offset(x, by - 40), 110, const Color(0x55FFE14A), count: 12, t: _t * 1.5);
      _S.body.draw(c, Offset(left, by - _S.body.h * _sc), scale: _sc);
      _r(c, left + _sc, by - _S.body.h * _sc, bw - 2 * _sc, 3 * _sc, const Color(0xFFFFE14A));
      _r(c, left + _sc * 3, by - _S.body.h * _sc - _sc, bw - 6 * _sc, _sc * 2, const Color(0xFFFFF3B0));
      _S.gemIcon.drawCentered(c, Offset(x, by - _S.body.h * _sc - 14 - k * 20), scale: 3);
      final lidY = by - _S.body.h * _sc - _S.lid.h * _sc - k * 30;
      _S.lidOpen.draw(c, Offset(left, lidY), scale: _sc);
      return;
    }
    // ----- idle / tells
    final ph = _tellPhase(ch);
    var lidLift = 0.0;
    var bodySquash = 0.0;
    final tells = _phase == 1 || _phase == 0 ? ch.tells : const <_Tell>[];
    if (tells.contains(_Tell.breathe)) {
      final b = sin(_t * 2 * pi / (ch.period * 1.1));
      lidLift += max(0, b) * _sc * .8;
      bodySquash = b * .03;
    }
    if (tells.contains(_Tell.twitch) && ph > .82 && ph < .9) {
      lidLift += _sc * 1.6 * (((_t * 40).floor().isEven) ? 1 : .3);
    }
    final bodyH = _S.body.h * _sc * (1 + bodySquash);
    final bodyTop = by - bodyH;
    c.save();
    c.translate(left, bodyTop);
    c.scale(1, 1 + bodySquash);
    _S.body.draw(c, Offset.zero, scale: _sc, opacity: dim ? .5 : 1);
    c.restore();
    // gap under the lid (dark mouth line)
    final lidTop = bodyTop - _S.lid.h * _sc - lidLift;
    if (lidLift > 0.5) {
      _r(c, left + _sc, bodyTop - lidLift, bw - 2 * _sc, lidLift, const Color(0xFF3A0A14));
      if (tells.contains(_Tell.teeth) || lidLift > _sc) {
        for (var k = 0; k < 6; k++) {
          _r(c, left + _sc * 2 + k * _sc * 2, bodyTop - lidLift, _sc, min(lidLift, _sc), const Color(0xFFF2F2E8));
        }
      }
    }
    _S.lid.draw(c, Offset(left, lidTop), scale: _sc, opacity: dim ? .5 : 1);
    if (dim) return;
    final seamY = bodyTop;
    // teeth peeking
    if (tells.contains(_Tell.teeth) && ph > .3 && ph < .55) {
      for (final k in const [3, 6, 9, 12]) {
        _r(c, left + k * _sc, seamY - _sc * .2, _sc, _sc * 1.2, const Color(0xFFF2F2E8));
      }
    }
    // tongue tip
    if (tells.contains(_Tell.tongue) && ph > .1 && ph < .35) {
      final k = sin((ph - .1) / .25 * pi);
      _r(c, x + _sc * 2, seamY - _sc * .5, _sc * 2, _sc * (1 + k * 2), const Color(0xFFFF6F8F));
      _r(c, x + _sc * 2.5, seamY + _sc * (k * 2), _sc, _sc * .8, const Color(0xFFD84A6A));
    }
    // drool drop
    if (tells.contains(_Tell.drool)) {
      final k = (ph * 1.5) % 1;
      final dx = left + _sc * 4;
      if (k < .5) {
        _r(c, dx, seamY, _sc, _sc * (k * 2) + 1, const Color(0xCCAEE8FF));
      } else {
        final fy = seamY + (k - .5) * 2 * (bodyH + 6);
        _r(c, dx, fy, _sc, _sc * 1.4, const Color(0xCCAEE8FF));
        if (k > .92) _r(c, dx - _sc, by - 2, _sc * 3, 3, const Color(0x99AEE8FF));
      }
    }
    // eye in keyhole
    final kh = Offset(x, bodyTop + 3 * _sc * (1 + bodySquash));
    if (tells.contains(_Tell.eye) && ph > .45 && ph < .75) {
      final blink = ph > .7;
      _r(c, kh.dx - _sc * 1.5, kh.dy - _sc * .2, _sc * 3, blink ? _sc * .4 : _sc * 1.6, const Color(0xFFFFF1B8));
      if (!blink) _r(c, kh.dx - _sc * .5 + sin(_t * 3) * _sc * .6, kh.dy + _sc * .2, _sc, _sc, const Color(0xFFE8202A));
    }
    // real chests glint
    if (!ch.mimic) {
      final g = ((_t * .9 + ch.phase) % 1.6);
      if (g < .25) {
        final gx = left + _sc * (2 + g * 40);
        _S.glint.drawCentered(c, Offset(gx.clamp(left + _sc, left + bw - _sc), lidTop + _sc * 2), scale: 2);
      }
    }
  }

  void _drawMimicAttack(Canvas c, double x, double by) {
    const bw = 16 * _sc;
    final left = x - bw / 2;
    final k = _pt0;
    final jump = k < .5 ? -sin(k / .5 * pi) * 50 : 0.0;
    final chompOpen = (sin(k * 22) * .5 + .5);
    final open = k < .15 ? k / .15 : chompOpen;
    final bodyTop = by - _S.mimicBody.h * _sc + jump;
    _S.mimicBody.draw(c, Offset(left, bodyTop), scale: _sc);
    final lidY = bodyTop - _S.mimicLid.h * _sc - open * 34;
    // mouth interior
    _r(c, left + _sc, lidY + _S.mimicLid.h * _sc - _sc, bw - 2 * _sc, bodyTop - lidY - _S.mimicLid.h * _sc + 2 * _sc,
        const Color(0xFF3A0A14));
    // tongue flailing
    final tx = x + sin(_t * 20) * 12;
    _r(c, tx - _sc * 1.5, bodyTop - open * 26, _sc * 3, open * 26 + _sc, const Color(0xFFFF6F8F));
    _S.mimicLid.draw(c, Offset(left, lidY), scale: _sc);
    // legs
    if (k < .8) {
      for (final lx in const [-30.0, -10.0, 10.0, 30.0]) {
        _r(c, x + lx - 3, by + jump - 2, 6, 10 + sin(_t * 30 + lx) * 4, const Color(0xFF6B3F1E));
      }
    }
  }

  void _drawHero(Canvas c) {
    const p = Offset(180, 552);
    final spr = _heroShock > 0 ? _S.heroShock : (_heroCheer > 0 || (host.finished && _loot >= _goal) ? _S.heroCheer : _S.hero);
    final bob = _heroCheer > 0 ? -(sin(_t * 14).abs() * 8) : ((_t * 2).floor().isEven ? 0.0 : 2.0);
    final shake = _heroShock > 0 ? sin(_t * 60) * 3 : 0.0;
    D.shadow(c, const Offset(180, 600), 60, 12, .4);
    spr.drawCentered(c, p + Offset(shake, bob), scale: 4, tint: _heroShock > 1.2 && (_t * 20).floor().isEven ? Pal.white : null);
    if (_heroCheer > 0) {
      D.coin(c, p + Offset(0, -46 + bob), 9, spin: _t * 2);
    }
    if (_heroShock > 0) {
      _pt(c, '!!', p + const Offset(34, -40), 3, Pal.red);
    }
  }

  void _drawHud(Canvas c) {
    for (var i = 0; i < 2; i++) {
      _S.heart.draw(c, Offset(12.0 + i * 30, 48), scale: 3, tint: i < _hearts ? null : const Color(0xFF3A2A40));
    }
    // loot counter
    _r(c, 238, 44, 112, 34, const Color(0xFF10122A));
    _r(c, 241, 47, 106, 28, const Color(0xFF3A2A50));
    _S.gemIcon.draw(c, const Offset(248, 51), scale: 2);
    PixelFont.draw(c, '$_loot/$_goal', const Offset(334, 52), 3, _loot > 0 ? Pal.gold : Pal.white, align: 1,
        shadow: const Color(0xFF10122A));
    // round pips
    for (var i = 0; i < _goal; i++) {
      _r(c, 250.0 + i * 24, 84, 18, 6, i < _loot ? Pal.gold : const Color(0xFF3A2A50));
    }
    // mimic count warning
    if (_phase == 1) {
      final m = _chests.where((c) => c.mimic).length;
      for (var i = 0; i < m; i++) {
        _S.mimicIcon.draw(c, Offset(12.0 + i * 36, 80), scale: 2);
      }
    }
  }
}

enum _Tell { breathe, twitch, drool, tongue, eye, teeth }

class _Chest {
  _Chest(this.i, this.mimic, this.tells);
  final int i;
  final bool mimic;
  final List<_Tell> tells;
  double phase = 0, period = 1.2, drop = 0, lt = 0, lastPh = 0;
  bool opened = false;
}

class _Pops {
  final List<(String, Offset, Color, double, double)> _l = [];
  void add(String s, Offset at, Color col, [double scale = 3]) {
    if (_l.length < 6) _l.add((s, at, col, scale, 0));
  }

  void update(double dt) {
    for (var i = _l.length - 1; i >= 0; i--) {
      final e = _l[i];
      if (e.$5 + dt > 1.1) {
        _l.removeAt(i);
      } else {
        _l[i] = (e.$1, e.$2 - Offset(0, 26 * dt), e.$3, e.$4, e.$5 + dt);
      }
    }
  }

  void render(Canvas c) {
    for (final e in _l) {
      if (e.$5 > .85 && ((e.$5 * 20).floor().isEven)) continue;
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
  static const _cp = <String, Color>{
    'K': Color(0xFF1A1020),
    'B': Color(0xFF9A5B2A),
    'b': Color(0xFF7A4420),
    'W': Color(0xFFC07A3E),
    'G': Color(0xFFFFC53D),
    'g': Color(0xFFC08A10),
    'Y': Color(0xFFFFE14A),
    'D': Color(0xFF5E3418),
    'M': Color(0xFF3A0A14),
    'T': Color(0xFFFF6F8F),
    'E': Color(0xFFF2F2E8),
    'R': Color(0xFFFF2A3A),
  };
  static final lid = Sprite(const [
    '..KKKKKKKKKKKK..',
    '.KWWWWWWWWWWWWK.',
    'KBGBBbBBBBbBBGBK',
    'KBGBBBBBBBBBBGBK',
    'KBGBBBBYYBBBBGBK',
    'KKgKKKKYYKKKKgKK',
  ], _cp);
  static final lidOpen = Sprite(const [
    '..KKKKKKKKKKKK..',
    '.KbbbbbbbbbbbbK.',
    'KDDDDDDDDDDDDDDK',
    'KDgDDDDDDDDDDgDK',
    'KBGBBBBBBBBBBGBK',
    'KWWWWWWWWWWWWWWK',
  ], _cp);
  static final body = Sprite(const [
    'KBGBBBBYYBBBBGBK',
    'KBGBBBYYYYBBBGBK',
    'KBGBBBYKKYBBBGBK',
    'KBGBbBYYYYBbBGBK',
    'KBGBBBBBBBBBBGBK',
    'KBGBBbBBBBbBBGBK',
    'KDgDDDDDDDDDDgDK',
    '.KKKKKKKKKKKKKK.',
  ], _cp);
  static final mimicBody = Sprite(const [
    'KEKEKEKEKEKEKEEK',
    'KMMMMMTTTTMMMMMK',
    'KBGMMTTTTTTMMGBK',
    'KBGBMMMMMMMMBGBK',
    'KBGBBBBBBBBBBGBK',
    'KBGBBbBBBBbBBGBK',
    'KDgDDDDDDDDDDgDK',
    '.KKKKKKKKKKKKKK.',
  ], _cp);
  static final mimicLid = Sprite(const [
    '..KKKKKKKKKKKK..',
    '.KWWWWWWWWWWWWK.',
    'KBGEEBBBBBBEEGBK',
    'KBGERBBBBBBREGBK',
    'KMMMMMMMMMMMMMMK',
    'KEKEKEKEKEKEKEKK',
  ], _cp);
  static final mimicIcon = Sprite(const [
    '.KKKKKKKKKK.',
    'KBBRBBBBRBBK',
    'KMMMMMMMMMMK',
    'KEKEKEKEKEKK',
    'KBBBBBBBBBBK',
    '.KKKKKKKKKK.',
  ], _cp);

  static const _hp = <String, Color>{
    'K': Color(0xFF1A1020),
    'A': Color(0xFFB0B8C8),
    'a': Color(0xFF7A809A),
    'W': Color(0xFFFFFFFF),
    'S': Color(0xFFFFC99A),
    'R': Color(0xFFE8453C),
    'B': Color(0xFF3F6FE8),
    'b': Color(0xFF274F9C),
    'Y': Color(0xFFFFD23F),
  };
  // hero seen from behind-ish (looking at chests)
  static final hero = Sprite(const [
    '.....RR.......',
    '....RRR.......',
    '...KAAAAK.....',
    '..KAAAAAAK....',
    '..KAWAAAAK....',
    '..KAAAAAAK....',
    '..KaAAAAaK....',
    '.KBBBBBBBBK...',
    'KSBBBYYBBBBSK.',
    'KSBbBBBBBbBSKA',
    '.KBBBBBBBBBK.A',
    '..KbbbbbbbK..A',
    '..KBBK.KBBK..A',
    '..KaaK.KaaK...',
    '.KKKK...KKKK..',
  ], _hp);
  static final heroCheer = Sprite(const [
    'S....RR.....S.',
    'S...RRR.....S.',
    'B..KAAAAK...B.',
    'B.KAAAAAAK..B.',
    'BBKAWAAAAKBBB.',
    '.BKAAAAAAKB...',
    '..KaAAAAaK....',
    '.KBBBBBBBBK...',
    '.KBBBYYBBBBK..',
    '.KBbBBBBBbBK..',
    '.KBBBBBBBBBK..',
    '..KbbbbbbbK...',
    '..KBBK.KBBK...',
    '..KaaK.KaaK...',
    '.KKKK...KKKK..',
  ], _hp);
  static final heroShock = Sprite(const [
    '...R...R......',
    '....RRR.......',
    '...KAAAAK.....',
    '..KAAAAAAK....',
    '..KAKAAKAK....',
    '..KAAKKAAK....',
    '..KaAAAAaK....',
    'SKBBBBBBBBKS..',
    'SBBBBYYBBBBBS.',
    '.KBbBBBBBbBK..',
    '.KBBBBBBBBBK..',
    '..KbbbbbbbK...',
    '.KBBK...KBBK..',
    '.KaaK...KaaK..',
    'KKKK.....KKKK.',
  ], _hp);

  static final heart = Sprite(const [
    '.KK.KK.',
    'KRRKRRK',
    'KRWRRRK',
    'KRRRRRK',
    '.KRRRK.',
    '..KRK..',
    '...K...',
  ], const {'K': Color(0xFF10122A), 'R': Color(0xFFFF3B5C), 'W': Color(0xFFFFFFFF)});
  static final gemIcon = Sprite(const [
    '..CCCCC..',
    '.CWCCCCC.',
    'CCCCCCCCC',
    '.CCCCCCC.',
    '..CCCCC..',
    '...CCC...',
    '....C....',
  ], const {'C': Color(0xFF3FE0F0), 'W': Color(0xFFFFFFFF)});
  static final glint = Sprite(const [
    '..W..',
    '..W..',
    'WWWWW',
    '..W..',
    '..W..',
  ], const {'W': Color(0xFFFFFFFF)});
  static const _fl = {'R': Color(0xFFE8453C), 'O': Color(0xFFFF9A2A), 'Y': Color(0xFFFFE14A)};
  static final flame1 = Sprite(const [
    '..R...',
    '..RR..',
    '.ROR..',
    '.ROOR.',
    'ROYYOR',
    'ROYYOR',
    '.RYYR.',
  ], _fl);
  static final flame2 = Sprite(const [
    '...R..',
    '..RR..',
    '..ROR.',
    '.ROOR.',
    'ROYOOR',
    'ROYYOR',
    '.RYYR.',
  ], _fl);
  static final flame3 = Sprite(const [
    '......',
    '..R...',
    '.RRR..',
    '.ROOR.',
    'ROOYOR',
    'ROYYOR',
    '.RYYR.',
  ], _fl);
  static final web = Sprite(const [
    'WWWWWWWWWW',
    'W.W...W...',
    'WW.W.W....',
    'W.WWW.....',
    'W.W.W.....',
    'WW..W.....',
    'W.........',
  ], const {'W': Color(0x88D8D8E8)});
  static final skull = Sprite(const [
    '.WWWW.',
    'WWWWWW',
    'WKWWKW',
    'WWWWWW',
    '.WKKW.',
  ], const {'W': Color(0xFFE8E0D0), 'K': Color(0xFF1A1020)});
  static final bones = Sprite(const [
    'W......W',
    '.W....W.',
    '..WWWW..',
    '.W....W.',
    'W......W',
  ], const {'W': Color(0xFFE8E0D0)});
  static final skullEmblem = Sprite(const [
    '.YYYY.',
    'YYYYYY',
    'YKYYKY',
    'YYYYYY',
    '.YKKY.',
  ], const {'Y': Color(0xFFFFC53D), 'K': Color(0xFF8C1E3A)});
}
