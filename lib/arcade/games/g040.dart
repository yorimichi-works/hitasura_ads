import '../engine/engine.dart';

/// No.040 Pixel Farm Harvest — plant, water, water again, harvest! Crows land
/// on growing crops: tap them away. Swipe across plots to work several at once.
class G040 extends MiniGame {
  static const _goal = 12;
  static const double _pw = 76, _gap = 8, _x0 = 16, _y0 = 222;
  static const _grow = 2.5;

  final _plots = List.generate(12, (_) => _Plot());
  final _crows = <_Crow>[];
  final _flies = <_Fly>[];
  double _t = 0;
  int _got = 0;
  double _shownGot = 0;
  double _bump = 0;
  double _crowT = 3.2;
  int _lastPlot = -1;
  int _combo = 0;
  double _comboT = 0;
  double _farmerJoy = 0;
  double _farmerMad = 0;
  int _basketN = 0;
  bool _won = false;
  bool _usedWater = false;

  static final Paint _pp = Paint()..isAntiAlias = false;
  static void _px(Canvas c, double x, double y, double w, double h, Color col) {
    _pp.color = col;
    c.drawRect(Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), w, h), _pp);
  }

  // ------------------------------------------------------------ sprites ---
  static const _g = Color(0xFF3FA535), _gl = Color(0xFF7BD34A), _k = Color(0xFF1B1530);
  static final _sprout = Sprite(['.G.G.', '.GLG.', '..G..', '..G..'], {'G': _g, 'L': _gl});
  static final _leafy = Sprite([
    'G.....G',
    'GL...LG',
    '.GL.LG.',
    '..GGG..',
    'G..G..G',
    'GL.G.LG',
    '.GGGGG.',
    '...G...',
  ], {'G': _g, 'L': _gl});
  static final _crops = <Sprite>[
    Sprite([
      '.G.G.G.',
      '.GLGLG.',
      '..GGG..',
      '.OOOOO.',
      'OOWOOOO',
      'OOOOOOO',
      '.OOOOD.',
      '.OOOO..',
      '..OOD..',
      '..OO...',
      '...O...',
    ], {'G': _g, 'L': _gl, 'O': const Color(0xFFFF8A1F), 'W': const Color(0xFFFFD0A0), 'D': const Color(0xFFC85A10)}),
    Sprite([
      '...GG...',
      '.GGLGGG.',
      '.RRGGRR.',
      'RRWRRRRR',
      'RWRRRRRR',
      'RRRRRRRD',
      'RRRRRRRD',
      '.RRRRRD.',
      '..RRDD..',
    ], {'G': _g, 'L': _gl, 'R': const Color(0xFFE8303C), 'W': const Color(0xFFFFB0B0), 'D': const Color(0xFFA81C28)}),
    Sprite([
      '...GL..',
      '..YYY.G',
      '.YWYYGG',
      'GYYYYG.',
      'GYWYYG.',
      'GYYYYG.',
      'GGYYYG.',
      '.GYYGG.',
      '.GGGG..',
      '..GG...',
      '...G...',
    ], {'G': _g, 'L': _gl, 'Y': const Color(0xFFFFD23F), 'W': const Color(0xFFFFF4B0)}),
    Sprite([
      '....G....',
      '...GL....',
      '..OOOOO..',
      '.OOWDOOO.',
      'OOWODOODO',
      'OOOODOODO',
      'OOOODOODO',
      '.OOODOOO.',
      '..OOOOO..',
    ], {'G': _g, 'L': _gl, 'O': const Color(0xFFFFA12E), 'W': const Color(0xFFFFE0A0), 'D': const Color(0xFFD4701A)}),
  ];
  static final _rotten = Sprite([
    '..B.B..',
    '.BBBBB.',
    'BBDBBDB',
    'BBBBBBB',
    '.BBBBB.',
  ], {'B': const Color(0xFF6B5A3A), 'D': const Color(0xFF3A2E1E)});
  static final _crowA = Sprite([
    '...KKK....',
    '..KKWKK...',
    '.YYKKKKK..',
    '...KKKKKKK',
    '...KKKKKKK',
    '....KKKKK.',
    '.....Y.Y..',
    '....YY.YY.',
  ], {'K': const Color(0xFF221A33), 'W': Pal.white, 'Y': const Color(0xFFFFA12E)});
  static final _crowPeck = Sprite([
    '..........',
    '...KKK....',
    '..KKWKK...',
    '.YYKKKKKKK',
    '.Y.KKKKKKK',
    '....KKKKK.',
    '.....Y.Y..',
    '....YY.YY.',
  ], {'K': const Color(0xFF221A33), 'W': Pal.white, 'Y': const Color(0xFFFFA12E)});
  static final _crowFly1 = Sprite([
    '.K......K.',
    '.KK....KK.',
    '..KKKKKK..',
    'YKWKKKKKKK',
    '..KKKKKK..',
  ], {'K': const Color(0xFF221A33), 'W': Pal.white, 'Y': const Color(0xFFFFA12E)});
  static final _crowFly2 = Sprite([
    '..........',
    '..........',
    '..KKKKKK..',
    'YKWKKKKKKK',
    '.KKKKKKKK.',
    'KK......KK',
  ], {'K': const Color(0xFF221A33), 'W': Pal.white, 'Y': const Color(0xFFFFA12E)});
  static final _drop = Sprite(['..B..', '.BBB.', 'BBWBB', 'BBBBB', '.BBB.'],
      {'B': const Color(0xFF3FB8FF), 'W': Pal.white});
  static final _seed = Sprite(['.S.S.', 'S.S.S', '.S.S.'], {'S': const Color(0xFFFFE08A)});
  static Sprite _farmerS(int mood) => Sprite([
        '...HHHH...',
        '..HHHHHH..',
        'HHHHHHHHHH',
        '..SSSSSS..',
        '..SKSSKS..',
        '..SSSSSS..',
        mood == 0 ? '..SSKKSS..' : (mood == 1 ? '..SKKKKS..' : '..SSSSSS..'),
        mood == 2 ? '..SKKKKS..' : '...SSSS...',
        '.BBRRRRBB.',
        'SBBRRRRBBS',
        'S.BBBBBB.S',
        '..BBBBBB..',
        '..BB..BB..',
        '..BB..BB..',
        '.KKK..KKK.',
      ], {
        'H': const Color(0xFFE8C45A),
        'S': const Color(0xFFFFCC99),
        'K': _k,
        'B': const Color(0xFF3D6BFF),
        'R': const Color(0xFFE8453C),
      });
  static final _farmer = [_farmerS(0), _farmerS(1), _farmerS(2)];

  Rect _plotRect(int i) => Rect.fromLTWH(_x0 + (i % 4) * (_pw + _gap), _y0 + (i ~/ 4) * (_pw + _gap), _pw, _pw);
  int _plotAt(Offset p) {
    for (var i = 0; i < 12; i++) {
      if (_plotRect(i).contains(p)) return i;
    }
    return -1;
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _bump = M.approach(_bump, 0, 8, dt);
    _shownGot = M.approach(_shownGot, _got.toDouble(), 10, dt);
    _farmerJoy = max(0, _farmerJoy - dt);
    _farmerMad = max(0, _farmerMad - dt);
    _comboT -= dt;
    if (_comboT <= 0) _combo = 0;
    for (var i = 0; i < 12; i++) {
      final p = _plots[i];
      p.bump = M.approach(p.bump, 0, 7, dt);
      p.wet = max(0, p.wet - dt * .12);
      if (host.finished) continue;
      final crowOn = _crows.any((cr) => cr.plot == i && cr.state == 1);
      if (p.state == 2 && !crowOn) {
        final before = p.g;
        p.g += dt / _grow;
        if (before < .34 && p.g >= .34 || before < .67 && p.g >= .67) {
          p.bump = 1;
          host.sfx(Sfx.pop, volume: .25, rate: 1.4);
        }
        if (!p.twice && p.g >= .5) {
          p.state = 3;
          p.bump = 1;
          host.sfx(Sfx.drip, volume: .3);
        }
        if (p.g >= 1) {
          p.state = 4;
          p.ripeT = 0;
          p.bump = 1;
          host.sfx(Sfx.pCoin, volume: .35, rate: 1.6);
          host.fx.sparkle(_plotRect(i).center, count: 5, radius: 26, color: Pal.yellow);
        }
      } else if (p.state == 4) {
        p.ripeT += dt;
        if (p.ripeT > 7) {
          p.state = 5;
          p.bump = 1;
          host.sfx(Sfx.squish, volume: .4);
          host.fx.smoke(_plotRect(i).center, count: 5, color: const Color(0xAA7A8A40));
        }
      }
    }
    for (final f in _flies) {
      f.t += dt / .55;
    }
    _flies.removeWhere((f) {
      if (f.t >= 1) {
        _basketN++;
        host.sfx(Sfx.pCoin, volume: .5, rate: 1.2);
        host.fx.burst(const Offset(262, 560), Pal.gold, count: 6, speed: 120, size: 5, shape: PartShape.square, gravity: 300);
        return true;
      }
      return false;
    });
    _updateCrows(dt);
  }

  void _updateCrows(double dt) {
    if (!host.finished) {
      _crowT -= dt;
      if (_crowT <= 0) {
        final free = <int>[];
        for (var i = 0; i < 12; i++) {
          final s = _plots[i].state;
          if ((s == 2 || s == 3 || s == 4) && !_crows.any((c) => c.plot == i && c.state <= 1)) free.add(i);
        }
        if (free.isEmpty || _crows.where((c) => c.state <= 1).length >= 3) {
          _crowT = .6;
        } else {
          _crowT = rand(2.0, 3.0) / host.speed;
          final i = pick(free);
          final left = chance(.5);
          final tgt = _plotRect(i).center + const Offset(8, 4);
          _crows.add(_Crow(Offset(left ? -30 : 390, rand(120, 200)), tgt, i, !left));
          host.sfx(Sfx.pHit, volume: .35, rate: .6);
        }
      }
    }
    for (final cr in _crows) {
      cr.flap += dt * 14;
      cr.t += dt;
      switch (cr.state) {
        case 0:
          final d = cr.target - cr.pos;
          final step = 230 * host.speed * dt;
          if (d.distance <= step) {
            cr.pos = cr.target;
            cr.state = 1;
            cr.t = 0;
            cr.flipX = false;
            host.sfx(Sfx.land, volume: .3);
          } else {
            cr.pos += d / d.distance * step;
            cr.flipX = d.dx > 0;
          }
          if (host.finished) cr.state = 2;
        case 1:
          final p = _plots[cr.plot];
          if (p.state < 2 || p.state == 5) {
            cr.state = 2; // nothing left to eat
            cr.vel = const Offset(80, -160);
          } else if (cr.t >= 2.1 / host.speed && !host.finished) {
            // om nom — crop stolen
            p
              ..state = 0
              ..g = 0
              ..twice = false
              ..bump = 1;
            cr.state = 3;
            cr.carry = p.crop;
            cr.vel = Offset(cr.pos.dx < 180 ? -120 : 120, -170);
            _farmerMad = 1.2;
            host.sfx(Sfx.oops, volume: .7);
            host.sfx(Sfx.chomp, volume: .5);
            host.fx.pop(host.tr('oops', 'OOPS!'), cr.pos + const Offset(0, -30), color: Pal.red, size: 20);
            host.fx.burst(cr.pos, const Color(0xFF8A5A30), count: 10, speed: 150, size: 5, shape: PartShape.square);
            host.shake(3);
          }
        default:
          cr.vel = cr.vel + Offset(0, -80 * dt);
          cr.pos += cr.vel * dt;
          cr.flipX = cr.vel.dx > 0;
      }
    }
    _crows.removeWhere((c) => c.state >= 2 && (c.pos.dy < -40 || c.pos.dx < -60 || c.pos.dx > 420));
  }

  // ------------------------------------------------------------- input ---
  bool _scare(Offset p) {
    for (final cr in _crows) {
      if (cr.state > 1) continue;
      if ((cr.pos - p).distance < 34) {
        cr.state = 2;
        cr.vel = Offset(p.dx < cr.pos.dx ? 200 : -200, -260);
        host.sfx(Sfx.pHit, volume: .8, rate: 1.3);
        host.sfx(Sfx.slap, volume: .5);
        host.fx.burst(cr.pos, const Color(0xFF221A33), count: 12, speed: 220, size: 6, shape: PartShape.square, gravity: 260);
        host.fx.pop('!!', cr.pos + const Offset(0, -24), color: Pal.white, size: 20, life: .5);
        host.addScore(5, cr.pos + const Offset(0, -8));
        host.shake(2);
        return true;
      }
    }
    return false;
  }

  void _act(int i) {
    final p = _plots[i];
    final r = _plotRect(i);
    switch (p.state) {
      case 0:
        p
          ..state = 1
          ..crop = randInt(4)
          ..g = 0
          ..twice = false
          ..bump = 1;
        host.sfx(Sfx.dig, volume: .5, rate: 1.2);
        host.fx.burst(r.center, const Color(0xFF7A4A24), count: 8, speed: 140, size: 5, shape: PartShape.square, gravity: 500);
      case 1 || 3:
        if (p.state == 3) p.twice = true;
        p
          ..state = 2
          ..wet = 1
          ..bump = 1;
        _usedWater = true;
        host.sfx(Sfx.splash, volume: .5, rate: 1.2);
        host.fx.burst(r.center + const Offset(0, -10), Pal.sky, count: 12, speed: 170, size: 5, shape: PartShape.square,
            gravity: 600, colors: const [Pal.sky, Pal.white, Color(0xFF3D8BFF)]);
      case 4:
        _harvest(i);
      case 5:
        p
          ..state = 0
          ..bump = 1;
        host.sfx(Sfx.squish, volume: .5);
        host.fx.smoke(r.center, count: 6, color: const Color(0xAA8A7A50));
      default:
        p.bump = .4;
        host.sfx(Sfx.tap, volume: .2);
    }
  }

  void _harvest(int i) {
    final p = _plots[i];
    final r = _plotRect(i);
    p
      ..state = 0
      ..g = 0
      ..bump = 1;
    _got++;
    _combo++;
    _comboT = 1.1;
    _bump = 1;
    _farmerJoy = .8;
    _flies.add(_Fly(p.crop, r.center + const Offset(0, -10)));
    host.addScore(10 * min(_combo, 5), r.center + const Offset(0, -26));
    host.sfx(Sfx.pPowerup, volume: .5, rate: 1 + min(_combo, 8) * .07);
    host.fx.burst(r.center, Pal.gold, count: 10 + _combo * 2, speed: 220, size: 6, shape: PartShape.square, gravity: 500,
        colors: const [Pal.gold, Pal.white, Pal.lime]);
    if (_combo >= 3) {
      host.fx.pop('COMBO x$_combo', r.center + const Offset(0, -50), color: Pal.pink, size: 20);
      host.punch(.02);
    }
    if (_got >= _goal && !host.finished) {
      _won = true;
      host.sfx(Sfx.fanfare);
      host.fx.confetti(count: 90);
      host.fx.pop(host.tr('harvest', 'HARVEST!'), const Offset(180, 300), color: Pal.yellow, size: 40, life: 1.4);
      host.flash(Pal.white, .15);
      host.win(stars: host.time < 15 ? 3 : (host.time < 19 ? 2 : 1));
    }
  }

  @override
  void onDown(Offset p) {
    if (_scare(p)) {
      _lastPlot = -2;
      return;
    }
    _lastPlot = _plotAt(p);
    if (_lastPlot >= 0) _act(_lastPlot);
  }

  @override
  void onMove(Offset p) {
    if (!host.pointerDown) return;
    if (_scare(p)) return;
    final i = _plotAt(p);
    if (i >= 0 && i != _lastPlot) {
      _lastPlot = i;
      _act(i);
    } else if (i < 0) {
      _lastPlot = -1;
    }
  }

  @override
  void onUp(Offset p) => _lastPlot = -1;

  @override
  void onTimeUp() {
    if (_got >= _goal - 1) {
      _won = true;
      host.win(stars: 1);
    } else {
      host.sfx(Sfx.pDie);
      host.lose();
    }
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    // pixel sky bands
    const bands = [Color(0xFF6EC6FF), Color(0xFF82D0FF), Color(0xFF98DAFF), Color(0xFFB0E4FF)];
    for (var i = 0; i < 4; i++) {
      _px(c, 0, 36 + i * 32.0, 360, 32, bands[i]);
    }
    // sun
    final sunY = 70 + sin(_t * 2) * 2;
    _px(c, 290, sunY, 36, 36, const Color(0xFFFFE066));
    _px(c, 286, sunY + 4, 44, 28, const Color(0xFFFFE066));
    _px(c, 296, sunY + 8, 10, 8, const Color(0xFFFFF7C0));
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + _t * .5;
      final p = Offset(308 + cos(a) * 34, sunY + 18 + sin(a) * 34);
      _px(c, p.dx - 3, p.dy - 3, 6, 6, const Color(0xFFFFD23F));
    }
    // clouds
    for (var i = 0; i < 3; i++) {
      final x = (i * 140 + _t * (10 + i * 4)) % 460 - 80;
      final y = 60.0 + i * 28;
      _px(c, x, y, 56, 12, Pal.white);
      _px(c, x + 10, y - 8, 28, 10, Pal.white);
      _px(c, x + 4, y + 10, 48, 4, const Color(0xFFD8EEFF));
    }
    // hills
    for (var x = 0.0; x < 360; x += 8) {
      final h = 20 + sin(x * .025) * 12 + sin(x * .07) * 5;
      _px(c, x, 164 - h, 8, h + 4, const Color(0xFF5BAE4A));
    }
    // barn
    _barn(c, 40, 196);
    // silo
    _px(c, 118, 120, 26, 76, const Color(0xFFB8B8C8));
    _px(c, 116, 112, 30, 10, const Color(0xFF8E8AA3));
    _px(c, 122, 106, 18, 8, const Color(0xFF8E8AA3));
    for (var y = 128.0; y < 196; y += 12) {
      _px(c, 118, y, 26, 2, const Color(0xFF9A9AAE));
    }
    // field grass
    Retro.tiles(c, const Rect.fromLTWH(0, 196, 360, 290), 8, const Color(0xFF6DBB45), const Color(0xFF66B340));
    // fence
    for (var x = 4.0; x < 360; x += 22) {
      _px(c, x, 186, 6, 22, const Color(0xFFF4E8C8));
      _px(c, x + 1, 184, 4, 2, const Color(0xFFF4E8C8));
    }
    _px(c, 0, 192, 360, 4, const Color(0xFFE0D0A8));
    _px(c, 0, 200, 360, 4, const Color(0xFFE0D0A8));

    // HUD counter
    _hud(c);

    // plots
    for (var i = 0; i < 12; i++) {
      _drawPlot(c, i);
    }
    // crows
    for (final cr in _crows) {
      _drawCrow(c, cr);
    }

    // bottom: dirt road, basket, farmer
    Retro.tiles(c, const Rect.fromLTWH(0, 480, 360, 160), 8, const Color(0xFFB5834A), const Color(0xFFAD7C44));
    for (var i = 0; i < 12; i++) {
      _px(c, (i * 37 % 350).toDouble(), 500 + (i * 53 % 120).toDouble(), 6, 4, const Color(0xFF946438));
    }
    _px(c, 0, 478, 360, 4, const Color(0xFF7A5230));
    _basket(c);
    final fm = _farmerMad > 0 ? 2 : (_farmerJoy > 0 || _won ? 0 : 1);
    final hop = (_farmerJoy > 0 || _won) ? ((_t * 10).floor().isEven ? -6.0 : 0.0) : 0.0;
    final shakeX = _farmerMad > 0 ? ((_t * 30).floor().isEven ? 2.0 : -2.0) : 0.0;
    _farmer[fm].draw(c, Offset(46 + shakeX, 520 + hop), scale: 5);
    if (_farmerMad > 0) {
      // shaking fist + angry marks
      _px(c, 102 + shakeX, 526 + hop, 10, 10, const Color(0xFFFFCC99));
      PixelFont.draw(c, '#!', Offset(100, 506 + hop), 3, Pal.red);
    }
    // flying crops
    for (final f in _flies) {
      final t = f.t.clamp(0.0, 1.0);
      final to = const Offset(262, 548);
      final pos = Offset.lerp(f.from, to, t)! + Offset(0, -sin(t * pi) * 90);
      _crops[f.crop].drawCentered(c, pos, scale: 4 - t * 1.5);
    }

    // tutorial hints
    if (!host.finished && host.time < 3 && _plots.every((p) => p.state == 0)) {
      D.hand(c, _plotRect(5).center, _t);
    } else if (!host.finished && host.time < 7 && !_usedWater) {
      for (var i = 0; i < 12; i++) {
        if (_plots[i].state == 1) {
          D.hand(c, _plotRect(i).center + const Offset(0, 8), _t);
          break;
        }
      }
    }
    Retro.scanlines(c, alpha: .1);
    Retro.vignette(c, strength: .3);
  }

  void _barn(Canvas c, double x, double by) {
    const red = Color(0xFFC8363C), dark = Color(0xFF8A1E28), wh = Color(0xFFFFF4DC);
    _px(c, x, by - 52, 72, 52, red);
    for (var i = 0; i < 9; i++) {
      _px(c, x - 4 + i * 4, by - 52 - i * 4, 80 - i * 8, 4, dark);
    }
    _px(c, x + 20, by - 34, 32, 34, dark);
    _px(c, x + 20, by - 34, 32, 3, wh);
    _px(c, x + 20, by - 34, 3, 34, wh);
    _px(c, x + 49, by - 34, 3, 34, wh);
    for (var i = 0; i < 8; i++) {
      _px(c, x + 22 + i * 4, by - 32 + i * 4, 4, 4, wh);
      _px(c, x + 46 - i * 4, by - 32 + i * 4, 4, 4, wh);
    }
    _px(c, x + 28, by - 76, 16, 12, wh);
    _px(c, x + 31, by - 73, 10, 8, const Color(0xFF3A2440));
  }

  void _hud(Canvas c) {
    _px(c, 96, 44, 168, 52, const Color(0xCC1B1530));
    _px(c, 96, 44, 168, 3, const Color(0xFF3A2F66));
    final s = 1 + _bump * .25;
    c.save();
    c.translate(180, 70);
    c.scale(s);
    _crops[0].drawCentered(c, const Offset(-54, 0), scale: 3);
    final txt = '${_shownGot.round()}/$_goal';
    PixelFont.draw(c, txt, const Offset(14, -14), 4, _got >= _goal ? Pal.lime : Pal.white, align: 0, shadow: const Color(0xFF3A2F66));
    c.restore();
    for (var i = 0; i < _goal; i++) {
      _px(c, 106 + i * 12.8, 88, 10, 5, i < _got ? Pal.lime : const Color(0xFF3A2F66));
    }
  }

  void _drawPlot(Canvas c, int i) {
    final p = _plots[i];
    final r = _plotRect(i);
    // soil
    final wet = p.state == 2 || p.wet > .3;
    final soil = wet ? const Color(0xFF5A3A22) : (p.state == 1 || p.state == 3 ? const Color(0xFFB08452) : const Color(0xFF8A5A34));
    _px(c, r.left, r.top + 4, r.width, r.height, const Color(0xFF4A2E18));
    _px(c, r.left, r.top, r.width, r.height, soil);
    for (var k = 0; k < 4; k++) {
      _px(c, r.left + 6, r.top + 10 + k * 17.0, r.width - 12, 4,
          Color.lerp(soil, Pal.ink, .25)!);
    }
    if (p.state == 1 || p.state == 3) {
      // dry cracks
      _px(c, r.left + 14, r.top + 20, 8, 2, const Color(0xFF8A6238));
      _px(c, r.left + 50, r.top + 50, 10, 2, const Color(0xFF8A6238));
    }
    final base = Offset(r.center.dx, r.bottom - 14);
    final sq = 1 + sin(p.bump * pi * 2) * p.bump * .25;
    c.save();
    c.translate(base.dx, base.dy);
    c.scale(1 / sq, sq);
    switch (p.state) {
      case 1:
        _seed.drawCentered(c, const Offset(0, -6), scale: 4);
      case 2 || 3:
        if (p.g < .34) {
          _sprout.draw(c, Offset(-10, -16), scale: 4);
        } else if (p.g < .67) {
          _leafy.draw(c, Offset(-14, -32), scale: 4);
        } else {
          _leafy.draw(c, Offset(-14, -32), scale: 4);
          _crops[p.crop].draw(c, Offset(-_crops[p.crop].w * 1.5, -_crops[p.crop].h * 3.0 - 2), scale: 3, opacity: .75);
        }
      case 4:
        final wob = sin(_t * 10 + i) * 2;
        final sp = _crops[p.crop];
        sp.draw(c, Offset(-sp.w * 2.5, -sp.h * 5.0 + wob), scale: 5);
      case 5:
        _rotten.draw(c, const Offset(-14, -20), scale: 4);
    }
    c.restore();
    // need icons
    if (p.state == 1 || p.state == 3) {
      final bob = (_t * 4).floor().isEven ? 0.0 : -3.0;
      final ic = Offset(r.right - 14, r.top + 12 + bob);
      _px(c, ic.dx - 12, ic.dy - 12, 24, 24, Pal.white);
      _px(c, ic.dx - 12, ic.dy + 10, 24, 3, Pal.ink);
      _drop.drawCentered(c, ic, scale: 3.4);
    } else if (p.state == 4) {
      if ((_t * 6).floor() % 3 != 0) {
        _px(c, r.left + 6, r.top + 6, 6, 6, Pal.white);
        _px(c, r.right - 12, r.top + 16, 4, 4, Pal.yellow);
      }
      // rot timer
      final left = (1 - p.ripeT / 7).clamp(0.0, 1.0);
      _px(c, r.left + 4, r.bottom - 6, (r.width - 8) * left, 3, left < .35 ? Pal.red : Pal.lime);
    } else if (p.state == 0 && host.time < 6) {
      PixelFont.draw(c, '+', r.center + const Offset(0, -8), 3, const Color(0x88FFFFFF), align: 0);
    }
    if (p.state == 2 || p.state == 3) {
      _px(c, r.left + 4, r.bottom - 6, (r.width - 8) * p.g.clamp(0.0, 1.0), 3, Pal.sky);
    }
  }

  void _drawCrow(Canvas c, _Crow cr) {
    final Sprite spr;
    if (cr.state == 1) {
      spr = (cr.t * 6).floor().isEven ? _crowA : _crowPeck;
    } else {
      spr = cr.flap.floor().isEven ? _crowFly1 : _crowFly2;
    }
    if (cr.state == 1) _px(c, cr.pos.dx - 16, cr.pos.dy + 14, 32, 4, const Color(0x44000000));
    spr.drawCentered(c, cr.pos, scale: 4, flipX: cr.flipX);
    if (cr.state == 3) {
      _crops[cr.carry].drawCentered(c, cr.pos + const Offset(0, 22), scale: 2);
    }
    if (cr.state == 1) {
      // danger timer ring
      final k = (cr.t / (2.1 / host.speed)).clamp(0.0, 1.0);
      final blink = k > .6 && (_t * 12).floor().isEven;
      c.drawArc(Rect.fromCircle(center: cr.pos, radius: 28), -pi / 2, pi * 2 * k, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = blink ? Pal.white : Pal.red);
      if (cr.t < .6 || blink) PixelFont.draw(c, '!', cr.pos + const Offset(18, -34), 3, Pal.red);
    }
  }

  void _basket(Canvas c) {
    const x = 222.0, y = 540.0;
    // pile
    final n = min(_basketN, 14);
    for (var k = 0; k < n; k++) {
      final col = k % 5, row = k ~/ 5;
      _crops[(k * 7) % 4].drawCentered(c, Offset(x + 14 + col * 17.0 + (row.isOdd ? 8 : 0), y + 2 - row * 12.0), scale: 2);
    }
    const wood = Color(0xFFC88A48), dk = Color(0xFF8A5A2A);
    _px(c, x, y + 4, 100, 52, wood);
    _px(c, x, y + 4, 100, 5, dk);
    _px(c, x, y + 26, 100, 4, dk);
    _px(c, x, y + 50, 100, 6, dk);
    for (var k = 0; k < 5; k++) {
      _px(c, x + 4 + k * 22.0, y + 9, 3, 41, const Color(0xFFB07838));
    }
    _px(c, x + 30, y + 32, 40, 14, const Color(0xFFFFF4DC));
    PixelFont.draw(c, '$_basketN', Offset(x + 50, y + 35), 1.4, Pal.ink, align: 0);
  }
}

class _Plot {
  int state = 0; // 0 empty, 1 seeded dry, 2 growing, 3 thirsty, 4 ripe, 5 rotten
  int crop = 0;
  double g = 0;
  double ripeT = 0;
  double bump = 0;
  double wet = 0;
  bool twice = false;
}

class _Crow {
  _Crow(this.pos, this.target, this.plot, this.flipX);
  Offset pos;
  final Offset target;
  final int plot;
  bool flipX;
  int state = 0; // 0 flying in, 1 pecking, 2 scared off, 3 leaving with loot
  double t = 0, flap = 0;
  Offset vel = Offset.zero;
  int carry = 0;
}

class _Fly {
  _Fly(this.crop, this.from);
  final int crop;
  final Offset from;
  double t = 0;
}
