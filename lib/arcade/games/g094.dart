import '../engine/engine.dart';

/// No.094 Duck Blaster — 8-bit light-gun parody.
///
/// Ducks burst out of the tall grass and zig-zag. Tap them to shoot (the
/// screen does the classic black "zapper" flash). 3 shells per wave of 2
/// ducks. Miss and the dog snickers at you. Hit 6 ducks => win.
/// Shoot the dog => very funny, very instant loss.
class G094 extends MiniGame {
  static const _goal = 6;
  static const _grassY = 452.0;

  double _t = 0;
  final List<_Duck> _ducks = [];
  int _shells = 3;
  int _hits = 0, _misses = 0;
  int _wave = 0;
  int _waveHits = 0;
  // dog: 0 hidden, 1 show between waves, 2 peek-laugh on miss, 3 angry (shot)
  int _dog = 0;
  double _dogT = 0;
  double _dogX = 180;
  bool _dogHappy = false;
  double _zap = 0;
  Offset? _aim;
  double _aimT = 0;
  double _skyPink = 0;
  bool _over = false;
  final _pops = _Pops();

  @override
  void init() {
    _startWave();
  }

  void _startWave() {
    _wave++;
    _shells = 3;
    _waveHits = 0;
    final n = 2;
    for (var i = 0; i < n; i++) {
      final x = rand(90, 270);
      final ang = -pi / 2 + rand(-.9, .9);
      final sp = (135 + _wave * 8) * sqrt(host.speed);
      _ducks.add(_Duck(Offset(x, _grassY + 10), Offset(cos(ang), sin(ang)) * sp, randInt(3))
        ..delay = i * .35
        ..turn = rand(.4, .9));
    }
    host.sfx(Sfx.pSelect, volume: .5, rate: 1.4);
  }

  bool get _dogUp => _dog != 0;

  Rect get _dogRect {
    final y = _dogY;
    return Rect.fromLTWH(_dogX - 30, y - 6, 60, _grassY - y + 10);
  }

  double get _dogY {
    switch (_dog) {
      case 1:
        final k = _dogT < .25 ? _dogT / .25 : (_dogT > 1.05 ? 1 - (_dogT - 1.05) / .25 : 1.0);
        return _grassY - 70 * M.clamp01(k);
      case 2:
        final k = _dogT < .15 ? _dogT / .15 : (_dogT > .75 ? 1 - (_dogT - .75) / .15 : 1.0);
        return _grassY - 52 * M.clamp01(k);
      case 3:
        return _grassY - 90 - sin(min(_dogT, .5) / .5 * pi) * 40;
      default:
        return _grassY + 20;
    }
  }

  // --------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) => _shoot(p);

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action') {
      // aim-assist: shoot the nearest flying duck (keyboard fallback)
      final f = _ducks.where((d) => d.state == _DS.fly && d.delay <= 0).toList();
      if (f.isNotEmpty) _shoot(f.first.p);
    }
  }

  void _shoot(Offset p) {
    if (_over || host.finished) return;
    _aim = p;
    _aimT = .35;
    final between = _dog == 1;
    if (!between && _shells <= 0) {
      host.sfx(Sfx.click, rate: .8);
      _pops.add(host.tr('empty', 'EMPTY'), p, Pal.gray, 2);
      return;
    }
    host.sfx(Sfx.pShoot);
    host.shake(3);
    _zap = .07;
    // ducks first
    _Duck? hit;
    var best = 34.0;
    for (final d in _ducks) {
      if (d.state != _DS.fly || d.delay > 0) continue;
      final dist = (d.p - p).distance;
      if (dist < best) {
        best = dist;
        hit = d;
      }
    }
    if (!between) _shells--;
    if (hit != null) {
      hit.state = _DS.hit;
      hit.timer = 0;
      _hits++;
      _waveHits++;
      host.hitStop(.06);
      host.sfx(Sfx.pHit);
      host.sfx(Sfx.squish, volume: .5, rate: 1.4);
      host.addScore(_waveHits > 1 ? 1000 : 500, hit.p - const Offset(0, 26));
      host.fx.burst(hit.p, Pal.white, count: 12, speed: 200, shape: PartShape.square, size: 5, gravity: 250,
          colors: const [Color(0xFFFFFFFF), Color(0xFFB88A4A), Color(0xFF2E9A4A)]);
      if (_waveHits == 2) _pops.add(host.tr('double', 'DOUBLE!'), hit.p - const Offset(0, 50), Pal.yellow, 3);
      return;
    }
    // the dog?
    if (_dogUp && _dog != 3 && _dogRect.contains(p)) {
      _shootDog();
      return;
    }
    _misses++;
    host.sfx(Sfx.pSelect, volume: .4, rate: .6);
    _pops.add(host.tr('miss', 'MISS'), p, Pal.white, 2);
    if (!between && _dog == 0) {
      _dog = 2;
      _dogT = 0;
      _dogX = rand(90, 270);
      host.sfx(Sfx.boing, volume: .4, rate: 1.6);
    }
  }

  void _shootDog() {
    _dog = 3;
    _dogT = 0;
    _over = true;
    host.sfx(Sfx.hurt);
    host.sfx(Sfx.pDie);
    host.flash(Pal.red, .2);
    host.shake(12);
    host.hitStop(.12);
    _pops.add(host.tr('why', 'WHY?!'), Offset(_dogX, _dogY - 60), Pal.red, 5);
    host.lose();
  }

  // -------------------------------------------------------------- update ---
  @override
  void update(double dt) {
    _t += dt;
    _pops.update(dt);
    _zap = max(0, _zap - dt);
    _aimT = max(0, _aimT - dt);
    _skyPink = max(0, _skyPink - dt);
    if (_dog != 0) {
      _dogT += dt;
      if (_dog == 2 && _dogT > .9) _dog = 0;
      if (_dog == 1 && _dogT > 1.3) {
        _dog = 0;
        if (!host.finished) _startWave();
      }
    }
    for (final d in _ducks) {
      d.anim += dt;
      switch (d.state) {
        case _DS.fly:
          if (d.delay > 0) {
            d.delay -= dt;
            if (d.delay <= 0) host.sfx(Sfx.pJump, volume: .4, rate: 1.3);
            continue;
          }
          d.timer += dt;
          d.p += d.v * dt;
          d.turn -= dt;
          if (d.turn <= 0) {
            d.turn = rand(.35, .8);
            final sp = d.v.distance;
            final ang = atan2(d.v.dy, d.v.dx) + rand(-1.2, 1.2);
            d.v = Offset(cos(ang), sin(ang)) * sp;
            if (d.v.dy > 60 && d.p.dy > 330) d.v = Offset(d.v.dx, -d.v.dy);
          }
          if (d.p.dx < 30 && d.v.dx < 0 || d.p.dx > 330 && d.v.dx > 0) d.v = Offset(-d.v.dx, d.v.dy);
          if (d.p.dy < 90 && d.v.dy < 0 || d.p.dy > _grassY - 40 && d.v.dy > 0 && d.timer > .6) d.v = Offset(d.v.dx, -d.v.dy);
          final flyTime = 3.6 / pow(host.speed, .3);
          if (d.timer > flyTime || (_shells <= 0 && d.timer > .4 && _zap <= 0)) {
            d.state = _DS.escape;
            _skyPink = 1.2;
            host.sfx(Sfx.whoosh, volume: .6, rate: 1.3);
            _pops.add(host.tr('fly_away', 'FLY AWAY'), const Offset(180, 200), const Color(0xFFFFB0D0), 3);
          }
        case _DS.hit:
          d.timer += dt;
          if (d.timer > .35) {
            d.state = _DS.fall;
            host.sfx(Sfx.whoosh, volume: .5, rate: .7);
          }
        case _DS.fall:
          d.p += Offset(0, 330 * dt);
          if (d.p.dy > _grassY + 10) {
            d.state = _DS.gone;
            host.sfx(Sfx.thud, volume: .6);
            host.fx.burst(Offset(d.p.dx, _grassY), const Color(0xFF6FCB4A), count: 8, speed: 150, shape: PartShape.square, size: 5);
            _dogX = d.p.dx.clamp(70.0, 290.0);
          }
        case _DS.escape:
          d.p += Offset(d.v.dx.sign * 40, -280) * dt;
          if (d.p.dy < 20) d.state = _DS.gone;
        case _DS.gone:
          break;
      }
    }
    // wave resolution
    if (_ducks.isNotEmpty && _ducks.every((d) => d.state == _DS.gone) && _dog != 1 && !_over) {
      _ducks.clear();
      _dog = 1;
      _dogT = 0;
      _dogHappy = _waveHits > 0;
      if (_dogHappy) {
        host.sfx(Sfx.pCoin);
      } else {
        _dogX = 180;
        host.sfx(Sfx.boing, rate: 1.5);
      }
      if (_hits >= _goal && !host.finished) {
        _over = true;
        _dogHappy = true;
        host.sfx(Sfx.fanfare);
        host.fx.confetti(count: 80);
        host.win(stars: _misses == 0 ? 3 : (_misses <= 3 ? 2 : 1));
      }
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
    // sky (classic light blue, pinkish when a duck escapes)
    final sky = Color.lerp(const Color(0xFF5CC4FC), const Color(0xFFFCA8C8), M.clamp01(_skyPink))!;
    _r(c, 0, 0, 360, 640, sky);
    for (var i = 0; i < 3; i++) {
      final x = ((i * 150 + _t * (5 + i * 2)) % 480) - 80;
      _S.cloud.draw(c, Offset(x.roundToDouble(), 70.0 + i * 46), scale: 4);
    }
    _drawTree(c);
    // ducks behind the grass
    for (final d in _ducks) {
      if (d.state == _DS.gone || d.delay > 0) continue;
      _drawDuck(c, d);
    }
    _drawDog(c);
    _drawGrass(c);
    _drawHud(c);
    // zapper flash: black screen + white target boxes
    if (_zap > 0) {
      _r(c, 0, 36, 360, 604, const Color(0xFF000000));
      for (final d in _ducks) {
        if (d.state == _DS.fly && d.delay <= 0) _r(c, d.p.dx - 20, d.p.dy - 18, 40, 36, Pal.white);
      }
    }
    // crosshair
    final a = _aim ?? (host.pointerDown ? host.pointer : null);
    if (a != null && (_aimT > 0 || host.pointerDown)) {
      _S.cross.drawCentered(c, a, scale: 3);
    }
    if (host.time < 2.2) {
      final f = _ducks.where((d) => d.state == _DS.fly && d.delay <= 0).toList();
      if (f.isNotEmpty) {
        D.hand(c, f.first.p + const Offset(4, 18), _t);
        _pt(c, host.tr('tap', 'TAP'), f.first.p + const Offset(0, -42), 3, Pal.white);
      }
    }
    _pops.render(c);
    Retro.scanlines(c, alpha: .1);
  }

  void _drawTree(Canvas c) {
    // trunk
    _r(c, 36, 200, 40, 260, const Color(0xFF6B3F1E));
    _r(c, 36, 200, 10, 260, const Color(0xFF8A5A2B));
    _r(c, 60, 260, 8, 8, const Color(0xFF3F2410));
    _r(c, 44, 320, 8, 12, const Color(0xFF3F2410));
    // canopy (chunky blobs)
    const leaf = Color(0xFF2E9A4A), leafD = Color(0xFF1E6A3A), leafL = Color(0xFF6FCB4A);
    for (final b in const [(56.0, 170.0, 70.0), (14.0, 200.0, 50.0), (100.0, 200.0, 48.0), (60.0, 120.0, 52.0)]) {
      for (var y = -b.$3; y <= b.$3; y += 8) {
        final w = sqrt(max(0, b.$3 * b.$3 - y * y));
        _r(c, (b.$1 - w).roundToDouble(), b.$2 + y, w * 2, 8, y > b.$3 * .4 ? leafD : leaf);
      }
      _r(c, b.$1 - b.$3 * .4, b.$2 - b.$3 * .6, 12, 8, leafL);
    }
    // bush on the right
    for (var y = -30.0; y <= 30; y += 6) {
      final w = sqrt(max(0, 900 - y * y)) * 1.4;
      _r(c, 300 - w, 430 + y, w * 2, 6, y > 10 ? leafD : leaf);
    }
  }

  void _drawGrass(Canvas c) {
    const g1 = Color(0xFF3FAF3A), g2 = Color(0xFF2A8A2A), g3 = Color(0xFF7ADB4A);
    // tall blades
    for (var x = 0.0; x < 360; x += 6) {
      final h = 26 + ((x * 7) % 23) + sin(x * .3 + _t * 2) * 2;
      _r(c, x, _grassY - h + 20, 6, h, ((x ~/ 6) % 3 == 0) ? g2 : g1);
      _r(c, x + 2, _grassY - h + 20, 2, 4, g3);
    }
    _r(c, 0, _grassY + 16, 360, 56, g1);
    for (var x = 0.0; x < 360; x += 12) {
      _r(c, x + ((x ~/ 12) % 2) * 6, _grassY + 24 + ((x ~/ 12) % 3) * 10, 4, 4, g2);
    }
    // dirt
    _r(c, 0, _grassY + 72, 360, 40, const Color(0xFF9A6A3A));
    for (var x = 0.0; x < 360; x += 16) {
      _r(c, x + 4, _grassY + 80 + ((x ~/ 16) % 3) * 8, 6, 4, const Color(0xFF7A4F28));
    }
  }

  void _drawDuck(Canvas c, _Duck d) {
    final spr = _S.ducks[d.color];
    switch (d.state) {
      case _DS.fly || _DS.escape:
        final f = (d.anim * 10).floor() % 4;
        final frame = [spr.$1, spr.$2, spr.$3, spr.$2][f];
        frame.drawCentered(c, d.p, scale: 3, flipX: d.v.dx < 0);
      case _DS.hit:
        spr.$4.drawCentered(c, d.p, scale: 3);
      case _DS.fall:
        c.save();
        c.translate(d.p.dx, d.p.dy);
        c.scale((d.anim * 12).floor().isEven ? 1 : -1, -1);
        spr.$4.drawCentered(c, Offset.zero, scale: 3);
        c.restore();
      case _DS.gone:
        break;
    }
  }

  void _drawDog(Canvas c) {
    if (_dog == 0) return;
    final y = _dogY;
    final x = _dogX;
    switch (_dog) {
      case 1:
        if (_dogHappy) {
          _S.dogHappy.drawCentered(c, Offset(x, y + 30), scale: 3);
          // holding caught ducks
          for (var i = 0; i < min(2, _waveHits); i++) {
            final hx = x + (i == 0 ? -30 : 30);
            _S.ducks[0].$4.drawCentered(c, Offset(hx, y - 4), scale: 2);
          }
        } else {
          final f = (_dogT * 8).floor().isEven;
          (f ? _S.dogLaugh1 : _S.dogLaugh2).drawCentered(c, Offset(x, y + 30 + (f ? 0 : 3)), scale: 3);
          if (f) _pt(c, 'HEH', Offset(x + 50, y - 10), 2, Pal.white);
        }
      case 2:
        final f = (_dogT * 10).floor().isEven;
        (f ? _S.dogLaugh1 : _S.dogLaugh2).drawCentered(c, Offset(x, y + 30), scale: 3);
      case 3:
        c.save();
        c.translate(x, y + 30);
        c.rotate(sin(_dogT * 30) * .1);
        _S.dogAngry.drawCentered(c, Offset.zero, scale: 3 + min(1.0, _dogT * 2));
        c.restore();
        _pt(c, 'GRR!', Offset(x, y - 40 + sin(_t * 40) * 2), 4, Pal.red);
    }
  }

  void _drawHud(Canvas c) {
    const top = 548.0;
    _r(c, 0, top, 360, 92, const Color(0xFF10122A));
    _r(c, 8, top + 8, 96, 50, const Color(0xFF2A8A2A));
    _r(c, 11, top + 11, 90, 44, const Color(0xFF10122A));
    _r(c, 112, top + 8, 240, 50, const Color(0xFF2A8A2A));
    _r(c, 115, top + 11, 234, 44, const Color(0xFF10122A));
    // shells
    for (var i = 0; i < 3; i++) {
      _S.shell.draw(c, Offset(20.0 + i * 24, top + 18), scale: 3, tint: i < _shells ? null : const Color(0xFF30305A));
    }
    _pt(c, host.tr('shot', 'SHOT'), const Offset(56, top + 48), 2, const Color(0xFF6FCB4A));
    // hit counter row
    _pt(c, host.tr('hit', 'HIT'), const Offset(142, top + 22), 2, const Color(0xFF6FCB4A));
    for (var i = 0; i < _goal; i++) {
      final got = i < _hits;
      final blink = got && i == _hits - 1 && (_t * 6).floor().isEven;
      _S.duckIcon.draw(c, Offset(170.0 + i * 28, top + 16), scale: 3,
          tint: blink ? Pal.white : (got ? const Color(0xFFFF4A4A) : const Color(0xFFE8E8F0)));
    }
    PixelFont.draw(c, '${host.score}'.padLeft(6, '0'), const Offset(232, top + 40), 2, Pal.white, align: 0);
    PixelFont.draw(c, 'R=$_wave', const Offset(8, top + 68), 2, const Color(0xFF6FCB4A));
  }
}

enum _DS { fly, hit, fall, escape, gone }

class _Duck {
  _Duck(this.p, this.v, this.color);
  Offset p;
  Offset v;
  final int color;
  _DS state = _DS.fly;
  double timer = 0;
  double anim = 0;
  double delay = 0;
  double turn = .6;
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
        _l[i] = (e.$1, e.$2 - Offset(0, 30 * dt), e.$3, e.$4, e.$5 + dt);
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
  static const _up = [
    '.ww...............',
    '.www..............',
    '..www.......GGG...',
    '..wwww.....GGEKG..',
    '...wwww...GGGGGYYY',
    '....wwww..GGGG....',
    '..BBBBwwwWWG......',
    'BBBBBBBBBBBB......',
    '.BBBbbbbbbBBB.....',
    '..BBBbbbbBBB......',
    '....BBBBBB........',
    '.....YY.YY........',
  ];
  static const _mid = [
    '..................',
    '..................',
    '............GGG...',
    '...........GGEKG..',
    '..........GGGGGYYY',
    '..........GGGG....',
    '..BBBBBBBWWG......',
    'BBwwwwwwwBBB......',
    '.BBBwwwwwbBBB.....',
    '..BBBbbbbBBB......',
    '....BBBBBB........',
    '.....YY.YY........',
  ];
  static const _down = [
    '..................',
    '..................',
    '............GGG...',
    '...........GGEKG..',
    '..........GGGGGYYY',
    '..........GGGG....',
    '..BBBBBBBWWG......',
    'BBBBBBBBBBBB......',
    '.BBBwwwwbbBBB.....',
    '..BBwwwwwBB.......',
    '...wwwwww.........',
    '...wwww...........',
  ];
  static const _shot = [
    '.....GGGGG.....',
    '....GEEGEEG....',
    '....GKEGKEG....',
    '....GGYYYGG....',
    '.w...GYYYG...w.',
    '.ww.WWWWWWW.ww.',
    '..wwBBBBBBBww..',
    '...BBBbbbBBB...',
    '....BBbbbBB....',
    '.....BBBBB.....',
    '.....Y...Y.....',
  ];
  static Map<String, Color> _pal(Color head, Color body) => {
        'G': head,
        'E': const Color(0xFFFFFFFF),
        'K': const Color(0xFF10122A),
        'Y': const Color(0xFFFFB02A),
        'W': const Color(0xFFFFFFFF),
        'B': body,
        'b': Color.lerp(body, const Color(0xFFFFFFFF), .45)!,
        'w': const Color(0xFFE8D0A0),
      };
  static final ducks = [
    for (final p in [
      _pal(const Color(0xFF2E9A4A), const Color(0xFF8A5A2B)),
      _pal(const Color(0xFF3F6FE8), const Color(0xFF3A3F70)),
      _pal(const Color(0xFFB05AE8), const Color(0xFFC0392B)),
    ])
      (Sprite(_up, p), Sprite(_mid, p), Sprite(_down, p), Sprite(_shot, p)),
  ];

  static const _dp = <String, Color>{
    'E': Color(0xFF8A5A2B),
    'F': Color(0xFFF2D2A0),
    'f': Color(0xFFD8B078),
    'K': Color(0xFF10122A),
    'N': Color(0xFF3A2A20),
    'M': Color(0xFF7A1F2B),
    'T': Color(0xFFFF6F8F),
    'W': Color(0xFFFFFFFF),
    'R': Color(0xFFE8453C),
    'C': Color(0xFFE8453C),
  };
  static final dogLaugh1 = Sprite(const [
    '..EE..........EE..',
    '.EEEE........EEEE.',
    '.EEEEFFFFFFFFEEEE.',
    '.EEEFFFFFFFFFFEEE.',
    '..EFFKKFFFFKKFFE..',
    '..EFKFFKFFKFFKFE..',
    '...FFFFFFFFFFFF...',
    '...FFFFFNNFFFFF...',
    '...FFFMMMMMMFFF...',
    '...FFMMMMMMMMFF...',
    '...FFMMTTTTMMFF...',
    '....FFMMTTMMFF....',
    '.....FFFFFFFF.....',
    '....CCCCCCCCCC....',
    '...FFFFFFFFFFFF...',
    '..FFFFFfFFfFFFFF..',
    '..FFFFFFFFFFFFFF..',
  ], _dp);
  static final dogLaugh2 = Sprite(const [
    '..EE..........EE..',
    '.EEEE........EEEE.',
    '.EEEEFFFFFFFFEEEE.',
    '.EEEFFFFFFFFFFEEE.',
    '..EFFFFFFFFFFFFE..',
    '..EFKKKFFFFKKKFE..',
    '...FFFFFFFFFFFF...',
    '...FFFFFNNFFFFF...',
    '...FFFFMMMMFFFF...',
    '...FFFMMTTMMFFF...',
    '....FFFMMMMFFF....',
    '.....FFFFFFFF.....',
    '.....FFFFFFFF.....',
    '....CCCCCCCCCC....',
    '...FFFFFFFFFFFF...',
    '..FFFFFfFFfFFFFF..',
    '..FFFFFFFFFFFFFF..',
  ], _dp);
  static final dogHappy = Sprite(const [
    'FF.EE........EE.FF',
    'FFEEEE......EEEEFF',
    '.FEEEEFFFFFFEEEEF.',
    '.FEEFFFFFFFFFFEEF.',
    '..FFFWKFFFFWKFFF..',
    '..FFFKKFFFFKKFFF..',
    '...FFFFFFFFFFFF...',
    '...FFFFFNNFFFFF...',
    '...FFFFFFFFFFFF...',
    '...FFMFFFFFFMFF...',
    '....FFMMMMMMFF....',
    '.....FFFFFFFF.....',
    '....CCCCCCCCCC....',
    '...FFFFFFFFFFFF...',
    '..FFFFFfFFfFFFFF..',
    '..FFFFFFFFFFFFFF..',
  ], _dp);
  static final dogAngry = Sprite(const [
    '..EE..........EE..',
    '.EEEE........EEEE.',
    '.EEEEFFFFFFFFEEEE.',
    '.EEEKKFFFFFFKKEEE.',
    '..EFFKKFFFFKKFFE..',
    '..EFFRKFFFFKRFFE..',
    '...FFFFFFFFFFFF...',
    '...FFFFFNNFFFFF...',
    '...FFMMMMMMMMFF...',
    '...FFMWMWMWMMFF...',
    '...FFMMMMMMMMFF...',
    '....FFFFFFFFFF....',
    '...WWWWWFFFFFFF...',
    '....CCCCCCCCCC....',
    '...FFFFFFFFFFFF...',
    '..FFFFFfFFfFFFFF..',
  ], _dp);

  static final cloud = Sprite(const [
    '......WWWW......',
    '...WWWWWWWWW....',
    '.WWWWWWWWWWWWWW.',
    'WWWWWWWWWWWWWWWW',
    '.LLLLLLLLLLLLLL.',
  ], const {'W': Color(0xFFFFFFFF), 'L': Color(0xFFD6EEFF)});
  static final cross = Sprite(const [
    '......R......',
    '......R......',
    '....RRRRR....',
    '...R..R..R...',
    '..R.......R..',
    '..R.......R..',
    'RRRR..R..RRRR',
    '..R.......R..',
    '..R.......R..',
    '...R..R..R...',
    '....RRRRR....',
    '......R......',
    '......R......',
  ], const {'R': Color(0xFFFF3B3B)});
  static final shell = Sprite(const [
    '.RR.',
    'RRRR',
    'RWRR',
    'RRRR',
    'RRRR',
    'YYYY',
    'YYYY',
  ], const {'R': Color(0xFFE8453C), 'W': Color(0xFFFFFFFF), 'Y': Color(0xFFFFD23F)});
  static final duckIcon = Sprite(const [
    '.....WW.',
    '....WWWW',
    'W...WWW.',
    'WWWWWWW.',
    '.WWWWWW.',
    '..WWWW..',
  ], const {'W': Color(0xFFFFFFFF)});
}
