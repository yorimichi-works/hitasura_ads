import '../engine/engine.dart';

/// No.149 VIRUS DETECTED!!! — a 90s pixel desktop gets swarmed by bugs that
/// munch your icons. Tap bugs to zap them; close the fake "DOWNLOAD" cleaner
/// popups (clicking DOWNLOAD — or ignoring them — releases MORE bugs).
/// Wipe out every bug to win; lose all icons and it's the blue screen.
class G149 extends MiniGame {
  static const _u = 3.0;
  static const _teal = Color(0xFF008080);
  static const _grey = Color(0xFFC0C0C0);
  static const _dark = Color(0xFF808080);
  static const _navy = Color(0xFF000080);
  static const _k = Color(0xFF000000);
  static const _w = Color(0xFFFFFFFF);

  static final List<List<Sprite>> _bugSprites = [
    for (final pal in const [
      {'G': Color(0xFF39D353), 'D': Color(0xFF1E8A30)},
      {'G': Color(0xFFFF4D6D), 'D': Color(0xFFA0203A)},
      {'G': Color(0xFFB266FF), 'D': Color(0xFF6A2AB0)},
    ])
      [
        for (final legs in const [
          ['.K.K...K.K.', 'K...K.K...K'],
          ['..K.K.K.K..', '.K..K.K..K.'],
        ])
          Sprite([
            '..K.....K..',
            '...K...K...',
            '..DGGGGGD..',
            '.GGWKGWKGG.',
            '.GDGGGGGDG.',
            'KGGGDGDGGGK',
            legs[0],
            legs[1],
          ], {...pal, 'K': _k, 'W': _w}),
      ],
  ];

  static final List<Sprite> _icons = [
    Sprite([
      'KKKKKKKKKKKK',
      'KWWWWWWWWWWK',
      'KWBBBBBBBBWK',
      'KWBCBBBBBBWK',
      'KWBBCBBBBBWK',
      'KWBBBBBBBBWK',
      'KWWWWWWWWWWK',
      'KKKKKKKKKKKK',
      '....KWWK....',
      '..KKKKKKKK..',
      '..KWWWWWWK..',
      '..KKKKKKKK..',
    ], {'K': _k, 'W': _grey, 'B': Color(0xFF1060C0), 'C': Color(0xFF80D0FF)}),
    Sprite([
      '............',
      '.KKKK.......',
      'KYYYYK......',
      'KYYYYYKKKKK.',
      'KYYYYYYYYYYK',
      'KOOOOOOOOOOK',
      'KYYYYYYYYYYK',
      'KYYYYYYYYYYK',
      'KYYYYYYYYYYK',
      'KYYYYYYYYYYK',
      'KKKKKKKKKKKK',
      '............',
    ], {'K': _k, 'Y': Color(0xFFFFD84A), 'O': Color(0xFFC89A20)}),
    Sprite([
      '...KKKKKK...',
      '.KKWWWWWWKK.',
      'KWWWWWWWWWWK',
      '.KKKKKKKKKK.',
      '.KWDWDWDWDK.',
      '.KWDWDWDWDK.',
      '.KWDWDWDWDK.',
      '.KWDWDWDWDK.',
      '.KWDWDWDWDK.',
      '.KWDWDWDWDK.',
      '..KWWWWWWK..',
      '..KKKKKKKK..',
    ], {'K': _k, 'W': Color(0xFFE0E0E0), 'D': _dark}),
    Sprite([
      '.KKKKKKKK...',
      '.KWWWWWWKK..',
      '.KWKKKKWWKK.',
      '.KWWWWWWWWK.',
      '.KWKKKKKKWK.',
      '.KWWWWWWWWK.',
      '.KWKKKKKWWK.',
      '.KWWWWWWWWK.',
      '.KWKKKKKKWK.',
      '.KWWWWWWWWK.',
      '.KKKKKKKKKK.',
      '............',
    ], {'K': _k, 'W': _w}),
    Sprite([
      '....KKKK....',
      '..KKBBGGKK..',
      '.KBBBGGGGBK.',
      '.KBGGGGGBBK.',
      'KBBBGGGBBBBK',
      'KBBBBGBBBGGK',
      'KBBBBBBBGGGK',
      'KBGGBBBBBGGK',
      '.KGGGBBBBBK.',
      '.KBGGBBBBBK.',
      '..KKBBBBKK..',
      '....KKKK....',
    ], {'K': _k, 'B': Color(0xFF2080FF), 'G': Color(0xFF30C040)}),
    Sprite([
      '.....KK.....',
      '....KRRK....',
      '....KRRK....',
      '.....KK.....',
      '.....KK.....',
      '.....KK.....',
      '..KKKKKKKK..',
      '.KDDDDDDDDK.',
      'KDDRDDDDYDDK',
      'KDRRRDDYDYDK',
      'KDDRDDDDYDDK',
      '.KKKKKKKKKK.',
    ], {'K': _k, 'R': Color(0xFFFF3030), 'D': Color(0xFF505060), 'Y': Color(0xFFFFD84A)}),
  ];

  static final Sprite _skull = Sprite([
    '..KKKKKKKK..',
    '.KWWWWWWWWK.',
    'KWWWWWWWWWWK',
    'KWKKWWWWKKWK',
    'KWKKWWWWKKWK',
    'KWWWWKKWWWWK',
    '.KWWWWWWWWK.',
    '..KWKWKWKK..',
    '..KWKWKWK...',
    '...KKKKK....',
  ], {'K': _k, 'W': Color(0xFFD0D0D0)});

  static final Sprite _shield = Sprite([
    'KKKKKKKKKK',
    'KBBBBWWWWK',
    'KBBBBWWWWK',
    'KBBBBWWWWK',
    'KWWWWBBBBK',
    'KWWWWBBBBK',
    '.KWWWBBBK.',
    '..KWWBBK..',
    '...KKKK...',
  ], {'K': _k, 'B': Color(0xFFFF3030), 'W': Color(0xFFFFD84A)});

  static const _iconPos = [
    Offset(46, 196), Offset(46, 290), Offset(46, 384), Offset(46, 478), Offset(310, 250), Offset(310, 370),
  ];

  double _t = 0;
  final _bugs = <_Bug>[];
  final _iconHp = List<double>.filled(6, 1);
  final _iconHit = List<double>.filled(6, 0);
  final _pops = <_Pop>[];
  final _zaps = <_Zap>[];
  int _total = 22;
  int _spawned = 0;
  int _killed = 0;
  double _spawnT = .3;
  double _popT = 3;
  bool _bsod = false;
  double _endT = 0;
  bool _won = false;
  Offset? _click;
  double _clickT = 0;

  @override
  Color get backdrop => const Color(0xFF002020);

  int get _iconsLeft => _iconHp.where((h) => h > 0).length;
  int get _remaining => _total - _killed;

  void _px(Canvas c, double x, double y, double w, double h, Color col) =>
      c.drawRect(Rect.fromLTWH((x / _u).roundToDouble() * _u, (y / _u).roundToDouble() * _u, w, h), Paint()..color = col);

  void _bevel(Canvas c, Rect r, {bool pressed = false}) {
    _px(c, r.left, r.top, r.width, r.height, _grey);
    _px(c, r.left, r.top, r.width, _u, pressed ? _dark : _w);
    _px(c, r.left, r.top, _u, r.height, pressed ? _dark : _w);
    _px(c, r.left, r.bottom - _u, r.width, _u, pressed ? _w : _k);
    _px(c, r.right - _u, r.top, _u, r.height, pressed ? _w : _k);
  }

  void _spawnBug(Offset at) {
    _spawned++;
    _bugs.add(_Bug(at, randInt(3), rand(38, 55) * host.speed, chance(.2) ? 2 : 1));
  }

  Offset _edgePoint() {
    switch (randInt(3)) {
      case 0:
        return Offset(-10, rand(180, 560));
      case 1:
        return Offset(370, rand(180, 560));
      default:
        return Offset(rand(100, 260), 610);
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _clickT = max(0, _clickT - dt);
    for (var i = 0; i < 6; i++) {
      _iconHit[i] = max(0, _iconHit[i] - dt * 4);
    }
    for (final z in _zaps) {
      z.life -= dt;
    }
    _zaps.removeWhere((z) => z.life <= 0);
    if (host.finished) {
      _endT += dt;
      return;
    }
    // spawn waves
    _spawnT -= dt * host.speed;
    if (_spawned < _total && _spawnT <= 0) {
      _spawnT = _spawned < 6 ? .55 : rand(.45, .8);
      final n = _spawned > 10 && chance(.35) ? 2 : 1;
      for (var i = 0; i < n && _spawned < _total; i++) {
        _spawnBug(_edgePoint());
      }
      host.sfx(Sfx.pSelect, volume: .25, rate: .7);
    }
    // fake cleaner popups
    _popT -= dt * host.speed;
    if (_popT <= 0 && _pops.length < 2 && host.timeLeft > 4) {
      _popT = rand(3.5, 4.5);
      _pops.add(_Pop(Offset(rand(110, 250), rand(250, 440))));
      host.sfx(Sfx.notify);
    }
    for (final p in _pops) {
      p.age += dt;
      if (p.age > 4.2 && !p.dead) {
        // auto-installs itself
        p.dead = true;
        _release(p.pos, 2);
      }
    }
    _pops.removeWhere((p) => p.dead);
    // bugs
    for (final b in _bugs) {
      b.anim += dt * 10;
      b.hurt = max(0, b.hurt - dt * 5);
      // target nearest living icon
      var best = -1;
      var bd = 1e9;
      for (var i = 0; i < 6; i++) {
        if (_iconHp[i] <= 0) continue;
        final d = (_iconPos[i] - b.pos).distance;
        if (d < bd) {
          bd = d;
          best = i;
        }
      }
      if (best < 0) continue;
      final to = _iconPos[best] - b.pos;
      if (bd > 14) {
        final wig = Offset(-to.dy, to.dx) / max(bd, 1) * sin(b.anim * .7) * 30;
        final v = to / bd * b.speed + wig;
        b.pos += v * dt;
        b.flip = v.dx < 0;
      } else {
        // munch!
        _iconHp[best] -= dt * .5;
        _iconHit[best] = 1;
        if ((b.anim * .5).floor() != ((b.anim - dt * 10) * .5).floor()) host.sfx(Sfx.chomp, volume: .35, rate: rand(1.2, 1.6));
        if (_iconHp[best] <= 0) {
          _iconHp[best] = 0;
          host.sfx(Sfx.pDie, volume: .7);
          host.sfx(Sfx.glitch, volume: .6);
          host.shake(6);
          host.fx.burst(_iconPos[best], _w, count: 14, speed: 200, shape: PartShape.square);
          if (_iconsLeft == 0) {
            _bsod = true;
            host.lose();
            return;
          }
        }
      }
    }
    if (_spawned >= _total && _bugs.isEmpty && !_won) {
      _won = true;
      _pops.clear();
      host.sfx(Sfx.pPowerup);
      host.sfx(Sfx.fanfare, volume: .8);
      host.fx.confetti(count: 80);
      final lost = 6 - _iconsLeft;
      host.win(stars: lost == 0 ? 3 : (lost <= 2 ? 2 : 1));
    }
  }

  void _release(Offset at, int n) {
    _total += n;
    for (var i = 0; i < n; i++) {
      _spawnBug(at + Offset(rand(-20, 20), rand(-10, 10)));
    }
    host.sfx(Sfx.glitch);
    host.sfx(Sfx.horror, volume: .4);
    host.shake(5);
    host.flash(const Color(0xFFFF0000), .12);
    host.fx.pop('+$n', at + const Offset(0, -30), color: Pal.red, size: 26);
  }

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    _click = p;
    _clickT = .15;
    // bugs crawl on top of everything: check them first
    _Bug? hit;
    var hd = 26.0;
    for (final b in _bugs) {
      final d = (b.pos - p).distance;
      if (d < hd) {
        hd = d;
        hit = b;
      }
    }
    if (hit != null) {
      hit.hp--;
      hit.hurt = 1;
      _zaps.add(_Zap(const Offset(36, 100), hit.pos));
      host.sfx(Sfx.zap, volume: .6, rate: rand(1.1, 1.4));
      if (hit.hp <= 0) {
        _bugs.remove(hit);
        _killed++;
        host.sfx(Sfx.pExplode, rate: rand(.9, 1.3));
        host.fx.burst(hit.pos, const Color(0xFF39D353), count: 14, speed: 220, shape: PartShape.square, size: 6,
            colors: const [Color(0xFF39D353), Color(0xFFFFD84A), _w]);
        host.addScore(10, hit.pos + const Offset(0, -16));
        host.shake(2);
      } else {
        host.sfx(Sfx.pHit);
      }
      return;
    }
    for (var i = _pops.length - 1; i >= 0; i--) {
      final pop = _pops[i];
      if ((p - pop.close).distance < 16) {
        pop.dead = true;
        host.sfx(Sfx.pCoin);
        host.fx.burst(pop.pos, _grey, count: 10, speed: 160, shape: PartShape.square);
        host.addScore(15);
        return;
      }
      if (pop.button.contains(p)) {
        pop.dead = true;
        _release(pop.pos, 3);
        return;
      }
      if (pop.rect.contains(p)) return;
    }
    host.sfx(Sfx.click, volume: .3);
  }

  @override
  void onTimeUp() {
    if (_remaining <= 2 && _iconsLeft > 0) {
      host.win(stars: 1);
    } else {
      _bsod = true;
      host.lose();
    }
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    if (_bsod && _endT > .25) {
      _renderBsod(c);
      return;
    }
    // desktop with dither
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), Paint()..color = _teal);
    final dp = Paint()..color = const Color(0xFF007070);
    for (var y = 0.0; y < 640; y += 6) {
      for (var x = (y / 6).floor().isEven ? 0.0 : 3.0; x < 360; x += 12) {
        c.drawRect(Rect.fromLTWH(x, y, 3, 3), dp);
      }
    }
    // icons
    for (var i = 0; i < 6; i++) {
      final p = _iconPos[i];
      final jig = _iconHit[i] > 0 ? (sin(_t * 60) * 2).roundToDouble() : 0.0;
      if (_iconHp[i] <= 0) {
        _skull.drawCentered(c, p + Offset(0, sin(_t * 4 + i) * 2), scale: _u);
        continue;
      }
      _icons[i].drawCentered(c, p + Offset(jig, 0), scale: _u, tint: _iconHit[i] > .5 && (_t * 20).floor().isEven ? Pal.red : null);
      // bite marks
      final bites = ((1 - _iconHp[i]) * 5).floor();
      for (var k = 0; k < bites; k++) {
        _px(c, p.dx + 12 - k * 6, p.dy - 18 + (k % 2) * 6, 6, 6, _teal);
      }
      // hp pips
      _px(c, p.dx - 18, p.dy + 24, 36, 5, _k);
      _px(c, p.dx - 17, p.dy + 25, 34 * _iconHp[i], 3, _iconHp[i] > .5 ? const Color(0xFF39D353) : Pal.red);
    }
    // antivirus window
    _renderAv(c);
    for (final p in _pops) {
      _renderPop(c, p);
    }
    // zaps
    for (final z in _zaps) {
      final path = Path()..moveTo(z.from.dx, z.from.dy);
      const n = 6;
      for (var i = 1; i <= n; i++) {
        final q = Offset.lerp(z.from, z.to, i / n)!;
        path.lineTo(q.dx + (i < n ? rand(-10, 10) : 0), q.dy + (i < n ? rand(-10, 10) : 0));
      }
      c.drawPath(path, Paint()
        ..color = const Color(0xFFFFFF60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * z.life / .15 + 1);
      c.drawPath(path, Paint()
        ..color = _w
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }
    // bugs
    for (final b in _bugs) {
      final spr = _bugSprites[b.kind][b.anim.floor() % 2];
      final sc = b.hp > 1 ? _u * 1.4 : _u;
      spr.drawCentered(c, b.pos, scale: sc, flipX: b.flip, tint: b.hurt > .3 ? _w : null);
    }
    // taskbar
    _px(c, 0, 606, 360, 34, _grey);
    _px(c, 0, 606, 360, 3, _w);
    _bevel(c, const Rect.fromLTWH(3, 612, 69, 24));
    _px(c, 9, 618, 12, 12, Pal.red);
    _px(c, 15, 618, 6, 6, const Color(0xFF39D353));
    _px(c, 9, 624, 6, 6, Pal.sky);
    _px(c, 15, 624, 6, 6, Pal.yellow);
    D.text(c, host.tr('start', 'START'), const Offset(25, 624), size: 12, color: _k, anchor: Alignment.centerLeft, weight: FontWeight.w900, maxWidth: 46);
    _bevel(c, const Rect.fromLTWH(282, 612, 75, 24), pressed: true);
    final secs = host.timeLeft.ceil();
    PixelFont.draw(c, '0:${secs.toString().padLeft(2, '0')}', const Offset(320, 620), 1.5, _k, align: 0);
    // click cursor
    if (_clickT > 0 && _click != null) {
      final cp = _click!;
      c.drawRect(Rect.fromCenter(center: cp, width: 20, height: 20), Paint()
        ..color = _w
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
    if (host.time < 2.2 && _killed == 0 && _bugs.isNotEmpty) {
      D.hand(c, _bugs.first.pos, _t, size: 36);
    }
    if (_won) _renderWin(c);
    Retro.scanlines(c, alpha: .1);
  }

  void _renderAv(Canvas c) {
    const r = Rect.fromLTWH(9, 42, 342, 108);
    _px(c, r.left + 6, r.top + 6, r.width, r.height, const Color(0x66000000));
    _bevel(c, r);
    final alarm = !_won && (_t * 3).floor().isEven;
    _px(c, r.left + 3, r.top + 3, r.width - 6, 21, alarm ? const Color(0xFFB00000) : _navy);
    D.text(c, host.tr('antivirus', 'ANTIVIRUS'), Offset(r.left + 10, r.top + 14), size: 12, color: _w, weight: FontWeight.w700,
        anchor: Alignment.centerLeft);
    PixelFont.draw(c, '!!!', Offset(r.left + 130, r.top + 9), 1.5, Pal.yellow);
    for (var i = 0; i < 2; i++) {
      _bevel(c, Rect.fromLTWH(r.right - 45 + i * 21.0, r.top + 6, 18, 15));
    }
    PixelFont.draw(c, '_', Offset(r.right - 39, r.top + 7), 1.5, _k);
    PixelFont.draw(c, 'x', Offset(r.right - 18, r.top + 9), 1.5, _k);
    _shield.draw(c, Offset(r.left + 12, r.top + 32), scale: 5);
    // count
    D.text(c, host.tr('virus', 'VIRUS'), Offset(r.left + 72, r.top + 42), size: 13, color: _k, anchor: Alignment.centerLeft,
        weight: FontWeight.w700);
    final big = _remaining.toString();
    PixelFont.draw(c, big, Offset(r.left + 200, r.top + 32), 4, alarm ? const Color(0xFFB00000) : _k);
    // segmented scan bar
    const bar = Rect.fromLTWH(81, 108, 258, 27);
    _bevel(c, bar, pressed: true);
    final prog = _total == 0 ? 0.0 : _killed / _total;
    final segs = (prog * 20).floor();
    for (var i = 0; i < segs; i++) {
      _px(c, bar.left + 6 + i * 12.6, bar.top + 6, 9, 15, _navy);
    }
    PixelFont.draw(c, '${(prog * 100).floor()}%', Offset(r.left + 300, r.top + 34), 2, _k, align: 0);
  }

  void _renderPop(Canvas c, _Pop p) {
    final r = p.rect;
    final k = M.easeOutBack((p.age / .2).clamp(0, 1));
    c.save();
    c.translate(r.center.dx, r.center.dy);
    c.scale(k);
    c.translate(-r.center.dx, -r.center.dy);
    _px(c, r.left + 6, r.top + 6, r.width, r.height, const Color(0x66000000));
    _bevel(c, r);
    _px(c, r.left + 3, r.top + 3, r.width - 6, 18, const Color(0xFF008000));
    D.text(c, host.tr('cleaner', 'CLEANER'), Offset(r.left + 8, r.top + 12), size: 11, color: _w, anchor: Alignment.centerLeft, weight: FontWeight.w700);
    _bevel(c, Rect.fromCenter(center: p.close, width: 18, height: 15));
    PixelFont.draw(c, 'x', p.close + const Offset(-3, -4), 1.2, _k);
    // warning glyph
    _px(c, r.left + 12, r.top + 30, 24, 24, Pal.yellow);
    _px(c, r.left + 12, r.top + 30, 24, 3, _k);
    _px(c, r.left + 22, r.top + 36, 4, 10, _k);
    _px(c, r.left + 22, r.top + 48, 4, 3, _k);
    PixelFont.draw(c, '100%', Offset(r.left + 44, r.top + 36), 2, Pal.red);
    D.text(c, host.tr('free', 'FREE!'), Offset(r.left + 150, r.top + 43), size: 16, color: Pal.red, weight: FontWeight.w900);
    // big download button
    final b = p.button;
    final pulse = (_t * 6).floor().isEven;
    _bevel(c, b);
    _px(c, b.left + 3, b.top + 3, b.width - 6, b.height - 6, pulse ? const Color(0xFF39D353) : const Color(0xFF2AAF40));
    D.text(c, host.tr('download', 'DOWNLOAD'), b.center, size: 13, color: _w, stroke: _k, strokeWidth: 3, maxWidth: b.width - 8);
    // self-install timer
    final tl = (1 - p.age / 4.2).clamp(0.0, 1.0);
    _px(c, r.left + 6, r.bottom - 9, (r.width - 12) * tl, 4, Pal.red);
    c.restore();
  }

  void _renderWin(Canvas c) {
    final k = M.easeOutBack((_endT / .3).clamp(0, 1));
    c.save();
    c.translate(180, 330);
    c.scale(k);
    _bevel(c, const Rect.fromLTWH(-120, -40, 240, 80));
    _px(c, -117, -37, 234, 18, _navy);
    PixelFont.draw(c, 'OK', const Offset(0, 0), 4, const Color(0xFF008000), align: 0);
    c.restore();
  }

  void _renderBsod(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), Paint()..color = const Color(0xFF0000AA));
    PixelFont.draw(c, ':(', const Offset(40, 150), 10, _w);
    for (var i = 0; i < 6; i++) {
      _px(c, 40, 260 + i * 24.0, 120 + (i * 53) % 160.0, 9, const Color(0xAAFFFFFF));
    }
    PixelFont.draw(c, '0x0000AD', const Offset(40, 440), 3, _w);
    PixelFont.draw(c, '${(min(100.0, _endT * 60)).floor()}%', const Offset(40, 490), 3, _w);
    Retro.scanlines(c, alpha: .15);
  }
}

class _Bug {
  _Bug(this.pos, this.kind, this.speed, this.hp);
  Offset pos;
  final int kind;
  final double speed;
  int hp;
  double anim = 0;
  double hurt = 0;
  bool flip = false;
}

class _Pop {
  _Pop(this.pos);
  final Offset pos;
  double age = 0;
  bool dead = false;
  Rect get rect => Rect.fromCenter(center: pos, width: 204, height: 126);
  Offset get close => Offset(rect.right - 15, rect.top + 12);
  Rect get button => Rect.fromCenter(center: pos + const Offset(0, 30), width: 150, height: 36);
}

class _Zap {
  _Zap(this.from, this.to);
  final Offset from, to;
  double life = .15;
}
